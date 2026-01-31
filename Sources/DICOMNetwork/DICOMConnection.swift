import Foundation
#if canImport(Network)
import Network

/// Thread-safe wrapper for continuation to handle one-shot resumption
private final class ContinuationResumeOnce<T: Sendable, E: Error>: @unchecked Sendable {
    private var resumed = false
    private var continuation: CheckedContinuation<T, E>?
    private let lock = NSLock()
    
    init(_ continuation: CheckedContinuation<T, E>) {
        self.continuation = continuation
    }
    
    var hasResumed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return resumed
    }
    
    func resume(with result: Result<T, E>) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        guard let continuation = continuation else {
            lock.unlock()
            return
        }
        resumed = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

/// DICOM network connection for managing TCP connections to DICOM services
///
/// Provides a high-level abstraction for TCP socket communication using
/// the DICOM Upper Layer Protocol.
///
/// Reference: PS3.8 Section 9 - DICOM Upper Layer Protocol
///
/// ## Usage
///
/// ```swift
/// let connection = DICOMConnection(host: "pacs.hospital.com", port: 11112)
/// try await connection.connect()
/// try await connection.send(pdu: associateRequestPDU)
/// let response = try await connection.receivePDU()
/// try await connection.disconnect()
/// ```
public final class DICOMConnection: @unchecked Sendable {
    
    /// Connection states
    public enum State: Sendable, Hashable {
        /// Connection has not been established
        case idle
        /// Connection is being established
        case connecting
        /// Connection is established and ready for communication
        case connected
        /// Connection is being closed gracefully
        case disconnecting
        /// Connection has been closed
        case disconnected
        /// Connection failed with an error
        case failed(String)
    }
    
    /// The remote host address
    public let host: String
    
    /// The remote port number (default DICOM port is 104)
    public let port: UInt16
    
    /// Maximum PDU size for receiving data
    public let maxPDUSize: UInt32
    
    /// Connection timeout in seconds
    public let timeout: TimeInterval
    
    /// The TLS configuration (nil if TLS is not enabled)
    public let tlsConfiguration: TLSConfiguration?
    
    /// The underlying network connection
    private let connection: NWConnection
    
    /// Current state of the connection
    public private(set) var state: State = .idle
    
    /// State change continuation for async state monitoring
    private var stateHandler: ((State) -> Void)?
    
    /// Creates a new DICOM connection
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - maxPDUSize: Maximum PDU size for receiving (default: 16KB)
    ///   - timeout: Connection timeout in seconds (default: 30)
    ///   - tlsEnabled: Whether to use TLS encryption (default: false)
    @available(*, deprecated, message: "Use init(host:port:maxPDUSize:timeout:tlsConfiguration:) instead")
    public init(
        host: String,
        port: UInt16 = dicomDefaultPort,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        timeout: TimeInterval = 30,
        tlsEnabled: Bool = false
    ) {
        self.host = host
        self.port = port
        self.maxPDUSize = maxPDUSize
        self.timeout = timeout
        self.tlsConfiguration = tlsEnabled ? .default : nil
        
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        let parameters: NWParameters
        if tlsEnabled {
            parameters = NWParameters(tls: .init(), tcp: .init())
        } else {
            parameters = NWParameters.tcp
        }
        
        self.connection = NWConnection(host: nwHost, port: nwPort, using: parameters)
    }
    
    /// Creates a new DICOM connection with TLS configuration
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - maxPDUSize: Maximum PDU size for receiving (default: 16KB)
    ///   - timeout: Connection timeout in seconds (default: 30)
    ///   - tlsConfiguration: TLS configuration for secure connections (nil for plain TCP)
    /// - Throws: `TLSConfigurationError` if TLS configuration is invalid
    public init(
        host: String,
        port: UInt16 = dicomDefaultPort,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        timeout: TimeInterval = 30,
        tlsConfiguration: TLSConfiguration?
    ) throws {
        self.host = host
        self.port = port
        self.maxPDUSize = maxPDUSize
        self.timeout = timeout
        self.tlsConfiguration = tlsConfiguration
        
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        
        let parameters: NWParameters
        if let tlsConfig = tlsConfiguration {
            let tlsOptions = try tlsConfig.makeNWProtocolTLSOptions()
            parameters = NWParameters(tls: tlsOptions, tcp: .init())
        } else {
            parameters = NWParameters.tcp
        }
        
        self.connection = NWConnection(host: nwHost, port: nwPort, using: parameters)
    }
    
    /// Establishes the TCP connection
    ///
    /// - Throws: `DICOMNetworkError.connectionFailed` if connection cannot be established
    /// - Throws: `DICOMNetworkError.timeout` if connection times out
    public func connect() async throws {
        guard state == .idle || state == .disconnected else {
            throw DICOMNetworkError.invalidState("Cannot connect: current state is \(state)")
        }
        
        state = .connecting
        
        return try await withCheckedThrowingContinuation { continuation in
            let resumeOnce = ContinuationResumeOnce(continuation)
            
            // Set up state handler
            connection.stateUpdateHandler = { [weak self] newState in
                guard let self = self else { return }
                
                switch newState {
                case .ready:
                    self.state = .connected
                    resumeOnce.resume(with: .success(()))
                    
                case .failed(let error):
                    self.state = .failed(error.localizedDescription)
                    resumeOnce.resume(with: .failure(DICOMNetworkError.connectionFailed(error.localizedDescription)))
                    
                case .cancelled:
                    self.state = .disconnected
                    resumeOnce.resume(with: .failure(DICOMNetworkError.connectionClosed))
                    
                case .waiting(let error):
                    // Connection is waiting, possibly due to network unavailability
                    self.state = .failed(error.localizedDescription)
                    resumeOnce.resume(with: .failure(DICOMNetworkError.connectionFailed("Network unavailable: \(error.localizedDescription)")))
                    
                default:
                    break
                }
            }
            
            // Start the connection
            connection.start(queue: .global(qos: .userInitiated))
            
            // Set up timeout
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                if !resumeOnce.hasResumed {
                    self.connection.cancel()
                    self.state = .failed("Connection timed out")
                    resumeOnce.resume(with: .failure(DICOMNetworkError.timeout))
                }
            }
        }
    }
    
    /// Sends a PDU over the connection
    ///
    /// - Parameter pdu: The PDU to send
    /// - Throws: `DICOMNetworkError.connectionClosed` if connection is not established
    /// - Throws: `DICOMNetworkError.encodingFailed` if PDU encoding fails
    public func send(pdu: any PDU) async throws {
        guard state == .connected else {
            throw DICOMNetworkError.invalidState("Cannot send: connection not established")
        }
        
        let data = try pdu.encode()
        try await send(data: data)
    }
    
    /// Sends raw data over the connection
    ///
    /// - Parameter data: The data to send
    /// - Throws: `DICOMNetworkError.connectionClosed` if connection is closed
    public func send(data: Data) async throws {
        guard state == .connected else {
            throw DICOMNetworkError.invalidState("Cannot send: connection not established")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: DICOMNetworkError.connectionFailed("Send failed: \(error.localizedDescription)"))
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
    
    /// Receives a PDU from the connection
    ///
    /// - Returns: The received PDU
    /// - Throws: `DICOMNetworkError.connectionClosed` if connection is closed
    /// - Throws: `DICOMNetworkError.decodingFailed` if PDU decoding fails
    public func receivePDU() async throws -> any PDU {
        guard state == .connected else {
            throw DICOMNetworkError.invalidState("Cannot receive: connection not established")
        }
        
        // First, read the PDU header (6 bytes)
        let headerData = try await receive(length: 6)
        let (_, pduLength) = try PDUDecoder.readHeader(from: headerData)
        
        // Validate PDU length
        guard pduLength <= maxPDUSize else {
            throw DICOMNetworkError.pduTooLarge(received: pduLength, maximum: maxPDUSize)
        }
        
        // Read the remaining PDU data
        let bodyData = try await receive(length: Int(pduLength))
        
        // Combine header and body for decoding
        var fullPDU = headerData
        fullPDU.append(bodyData)
        
        return try PDUDecoder.decode(from: fullPDU)
    }
    
    /// Receives a specific number of bytes from the connection
    ///
    /// - Parameter length: The number of bytes to receive
    /// - Returns: The received data
    /// - Throws: `DICOMNetworkError.connectionClosed` if connection is closed
    public func receive(length: Int) async throws -> Data {
        guard state == .connected else {
            throw DICOMNetworkError.invalidState("Cannot receive: connection not established")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: DICOMNetworkError.connectionFailed("Receive failed: \(error.localizedDescription)"))
                } else if let data = data, data.count >= length {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: DICOMNetworkError.connectionClosed)
                } else {
                    continuation.resume(throwing: DICOMNetworkError.decodingFailed("Incomplete data received"))
                }
            }
        }
    }
    
    /// Disconnects gracefully
    ///
    /// Sends any pending data before closing the connection.
    public func disconnect() async {
        guard state == .connected else {
            return
        }
        
        state = .disconnecting
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { [weak self] newState in
                if case .cancelled = newState {
                    self?.state = .disconnected
                    continuation.resume()
                }
            }
            connection.cancel()
        }
    }
    
    /// Forcefully aborts the connection
    ///
    /// Immediately closes the connection without waiting for pending data.
    public func abort() {
        connection.forceCancel()
        state = .disconnected
    }
}

// MARK: - CustomStringConvertible
extension DICOMConnection: CustomStringConvertible {
    public var description: String {
        "DICOMConnection(host: \(host), port: \(port), state: \(state))"
    }
}

#endif
