import Foundation
import DICOMCore

// MARK: - Storage SCP Configuration

/// Configuration for the DICOM Storage SCP (Service Class Provider)
///
/// Defines the settings for a Storage SCP that can receive DICOM files from remote sources.
///
/// Reference: PS3.4 Annex B - Storage Service Class
public struct StorageSCPConfiguration: Sendable, Hashable {
    /// The local Application Entity title
    public let aeTitle: AETitle
    
    /// The port to listen on
    public let port: UInt16
    
    /// Maximum PDU size to accept
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID for this DICOM implementation
    public let implementationClassUID: String
    
    /// Implementation Version Name (optional)
    public let implementationVersionName: String?
    
    /// Maximum number of concurrent associations
    public let maxConcurrentAssociations: Int
    
    /// Accepted SOP Classes for storage
    /// If nil, all common storage SOP Classes are accepted
    public let acceptedSOPClasses: Set<String>?
    
    /// Accepted Transfer Syntaxes
    /// If nil, common transfer syntaxes are accepted
    public let acceptedTransferSyntaxes: Set<String>?
    
    /// Calling AE Title whitelist
    /// If nil, all calling AE titles are accepted
    public let callingAEWhitelist: Set<String>?
    
    /// Calling AE Title blacklist
    /// Takes precedence over whitelist
    public let callingAEBlacklist: Set<String>?
    
    /// Default Implementation Class UID for DICOMKit SCP
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.2"
    
    /// Default Implementation Version Name for DICOMKit SCP
    public static let defaultImplementationVersionName = "DICOMKIT_SCP"
    
    /// Common Storage SOP Classes accepted by default
    public static let commonStorageSOPClasses: Set<String> = [
        // CT Image Storage
        "1.2.840.10008.5.1.4.1.1.2",
        // Enhanced CT Image Storage
        "1.2.840.10008.5.1.4.1.1.2.1",
        // MR Image Storage
        "1.2.840.10008.5.1.4.1.1.4",
        // Enhanced MR Image Storage
        "1.2.840.10008.5.1.4.1.1.4.1",
        // CR Image Storage
        "1.2.840.10008.5.1.4.1.1.1",
        // DX Image Storage
        "1.2.840.10008.5.1.4.1.1.1.1",
        // Digital Mammography X-Ray Image Storage
        "1.2.840.10008.5.1.4.1.1.1.2",
        // US Image Storage
        "1.2.840.10008.5.1.4.1.1.6.1",
        // US Multi-frame Image Storage
        "1.2.840.10008.5.1.4.1.1.3.1",
        // Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.7",
        // Multi-frame Single Bit Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.7.1",
        // Multi-frame Grayscale Byte Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.7.2",
        // Multi-frame Grayscale Word Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.7.3",
        // Multi-frame True Color Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.7.4",
        // NM Image Storage
        "1.2.840.10008.5.1.4.1.1.20",
        // PET Image Storage
        "1.2.840.10008.5.1.4.1.1.128",
        // Enhanced PET Image Storage
        "1.2.840.10008.5.1.4.1.1.130",
        // RT Image Storage
        "1.2.840.10008.5.1.4.1.1.481.1",
        // RT Dose Storage
        "1.2.840.10008.5.1.4.1.1.481.2",
        // RT Structure Set Storage
        "1.2.840.10008.5.1.4.1.1.481.3",
        // RT Plan Storage
        "1.2.840.10008.5.1.4.1.1.481.5",
        // Verification SOP Class
        "1.2.840.10008.1.1"
    ]
    
    /// Common Transfer Syntaxes accepted by default
    public static let commonTransferSyntaxes: Set<String> = [
        // Implicit VR Little Endian
        "1.2.840.10008.1.2",
        // Explicit VR Little Endian
        "1.2.840.10008.1.2.1",
        // Explicit VR Big Endian (Retired)
        "1.2.840.10008.1.2.2",
        // Deflated Explicit VR Little Endian
        "1.2.840.10008.1.2.1.99",
        // JPEG Baseline (Process 1)
        "1.2.840.10008.1.2.4.50",
        // JPEG Extended (Process 2 & 4)
        "1.2.840.10008.1.2.4.51",
        // JPEG Lossless (Process 14)
        "1.2.840.10008.1.2.4.57",
        // JPEG Lossless SV1 (Process 14, Selection Value 1)
        "1.2.840.10008.1.2.4.70",
        // JPEG 2000 Lossless
        "1.2.840.10008.1.2.4.90",
        // JPEG 2000 Lossy
        "1.2.840.10008.1.2.4.91",
        // RLE Lossless
        "1.2.840.10008.1.2.5"
    ]
    
    /// Creates a Storage SCP configuration
    ///
    /// - Parameters:
    ///   - aeTitle: The local AE title
    ///   - port: The port to listen on (default: 11112)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - maxConcurrentAssociations: Maximum concurrent associations (default: 10)
    ///   - acceptedSOPClasses: Accepted SOP Classes (nil for common classes)
    ///   - acceptedTransferSyntaxes: Accepted Transfer Syntaxes (nil for common syntaxes)
    ///   - callingAEWhitelist: Whitelist of calling AE titles
    ///   - callingAEBlacklist: Blacklist of calling AE titles
    public init(
        aeTitle: AETitle,
        port: UInt16 = dicomAlternativePort,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        maxConcurrentAssociations: Int = 10,
        acceptedSOPClasses: Set<String>? = nil,
        acceptedTransferSyntaxes: Set<String>? = nil,
        callingAEWhitelist: Set<String>? = nil,
        callingAEBlacklist: Set<String>? = nil
    ) {
        self.aeTitle = aeTitle
        self.port = port
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.maxConcurrentAssociations = max(1, maxConcurrentAssociations)
        self.acceptedSOPClasses = acceptedSOPClasses
        self.acceptedTransferSyntaxes = acceptedTransferSyntaxes
        self.callingAEWhitelist = callingAEWhitelist
        self.callingAEBlacklist = callingAEBlacklist
    }
    
    /// Gets the effective set of accepted SOP Classes
    public var effectiveSOPClasses: Set<String> {
        acceptedSOPClasses ?? Self.commonStorageSOPClasses
    }
    
    /// Gets the effective set of accepted Transfer Syntaxes
    public var effectiveTransferSyntaxes: Set<String> {
        acceptedTransferSyntaxes ?? Self.commonTransferSyntaxes
    }
    
    /// Checks if a calling AE title is allowed
    ///
    /// - Parameter callingAE: The calling AE title to check
    /// - Returns: True if the calling AE is allowed
    public func isCallingAEAllowed(_ callingAE: String) -> Bool {
        // Blacklist takes precedence
        if let blacklist = callingAEBlacklist, blacklist.contains(callingAE) {
            return false
        }
        
        // If whitelist exists, calling AE must be in it
        if let whitelist = callingAEWhitelist {
            return whitelist.contains(callingAE)
        }
        
        // No whitelist means all are allowed
        return true
    }
}

// MARK: - Received File

/// Information about a received DICOM file
///
/// Contains details about a DICOM instance received via C-STORE.
public struct ReceivedFile: Sendable {
    /// The SOP Class UID of the received instance
    public let sopClassUID: String
    
    /// The SOP Instance UID of the received instance
    public let sopInstanceUID: String
    
    /// The raw data set bytes
    public let dataSetData: Data
    
    /// The transfer syntax used for encoding
    public let transferSyntaxUID: String
    
    /// The calling AE title that sent the file
    public let callingAETitle: String
    
    /// The timestamp when the file was received
    public let timestamp: Date
    
    /// The file path if stored to disk (nil if not stored)
    public var filePath: URL?
    
    /// Creates a received file record
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        dataSetData: Data,
        transferSyntaxUID: String,
        callingAETitle: String,
        timestamp: Date = Date(),
        filePath: URL? = nil
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.dataSetData = dataSetData
        self.transferSyntaxUID = transferSyntaxUID
        self.callingAETitle = callingAETitle
        self.timestamp = timestamp
        self.filePath = filePath
    }
    
    /// The size of the received data in bytes
    public var dataSize: Int {
        dataSetData.count
    }
}

extension ReceivedFile: CustomStringConvertible {
    public var description: String {
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(dataSize), countStyle: .file)
        return "ReceivedFile(sop=\(sopInstanceUID), class=\(sopClassUID), size=\(sizeStr), from=\(callingAETitle))"
    }
}

// MARK: - Storage Delegate Protocol

/// Protocol for handling received DICOM files
///
/// Implement this protocol to customize how received files are processed.
public protocol StorageDelegate: Sendable {
    /// Called when an association request is received
    ///
    /// - Parameter info: Information about the requesting association
    /// - Returns: True to accept the association, false to reject
    func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool
    
    /// Called before receiving a DICOM instance
    ///
    /// - Parameters:
    ///   - sopClassUID: The SOP Class UID of the incoming instance
    ///   - sopInstanceUID: The SOP Instance UID of the incoming instance
    /// - Returns: True to accept the instance, false to reject
    func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool
    
    /// Called when a DICOM instance has been received
    ///
    /// - Parameter file: The received file information
    /// - Throws: Error if processing fails
    func didReceive(file: ReceivedFile) async throws
    
    /// Called when receiving a file fails
    ///
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - sopInstanceUID: The SOP Instance UID (if known)
    func didFail(error: Error, for sopInstanceUID: String?) async
}

/// Default implementation of StorageDelegate
extension StorageDelegate {
    public func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool {
        true
    }
    
    public func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool {
        true
    }
    
    public func didFail(error: Error, for sopInstanceUID: String?) async {
        // Default: do nothing
    }
}

// MARK: - Association Info

/// Information about an incoming association
public struct AssociationInfo: Sendable {
    /// The calling AE title
    public let callingAETitle: String
    
    /// The called AE title (should match our AE)
    public let calledAETitle: String
    
    /// The remote host address
    public let remoteHost: String
    
    /// The remote port
    public let remotePort: UInt16
    
    /// The proposed SOP Classes
    public let proposedSOPClasses: [String]
    
    /// The proposed Transfer Syntaxes
    public let proposedTransferSyntaxes: [String]
    
    /// Creates association info
    public init(
        callingAETitle: String,
        calledAETitle: String,
        remoteHost: String,
        remotePort: UInt16,
        proposedSOPClasses: [String],
        proposedTransferSyntaxes: [String]
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.proposedSOPClasses = proposedSOPClasses
        self.proposedTransferSyntaxes = proposedTransferSyntaxes
    }
}

// MARK: - Storage Event

/// Events emitted by the Storage SCP
public enum StorageServerEvent: Sendable {
    /// Server started listening
    case started(port: UInt16)
    
    /// Server stopped
    case stopped
    
    /// A new association was established
    case associationEstablished(AssociationInfo)
    
    /// An association was released
    case associationReleased(callingAE: String)
    
    /// An association was rejected
    case associationRejected(callingAE: String, reason: String)
    
    /// A file was received
    case fileReceived(ReceivedFile)
    
    /// An error occurred
    case error(Error)
}

// MARK: - Default Storage Handler

/// Default storage handler that stores files to disk
public actor DefaultStorageHandler: StorageDelegate {
    /// The directory to store received files
    public let storageDirectory: URL
    
    /// Whether to organize files by patient/study/series
    public let organizeByHierarchy: Bool
    
    /// Creates a default storage handler
    ///
    /// - Parameters:
    ///   - storageDirectory: Directory to store files
    ///   - organizeByHierarchy: Whether to organize by Patient/Study/Series hierarchy
    public init(storageDirectory: URL, organizeByHierarchy: Bool = false) {
        self.storageDirectory = storageDirectory
        self.organizeByHierarchy = organizeByHierarchy
    }
    
    public func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool {
        true
    }
    
    public func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool {
        true
    }
    
    public func didReceive(file: ReceivedFile) async throws {
        // Create filename from SOP Instance UID
        let filename = "\(file.sopInstanceUID).dcm"
        let fileURL = storageDirectory.appendingPathComponent(filename)
        
        // Ensure directory exists
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Write the file
        try file.dataSetData.write(to: fileURL)
    }
    
    public func didFail(error: Error, for sopInstanceUID: String?) async {
        // Log the error
    }
}

#if canImport(Network)
import Network

// MARK: - DICOM Storage Server

/// DICOM Storage Server (SCP)
///
/// Implements the DICOM Storage Service Class as a Service Class Provider (SCP).
/// This enables receiving DICOM files from remote Service Class Users (SCUs)
/// such as modalities, workstations, or PACS systems.
///
/// Reference: PS3.4 Annex B - Storage Service Class
/// Reference: PS3.7 Section 9.1.1 - C-STORE SCP behavior
///
/// ## Usage
///
/// ```swift
/// // Create configuration
/// let config = StorageSCPConfiguration(
///     aeTitle: try AETitle("MY_SCP"),
///     port: 11112
/// )
///
/// // Create handler
/// let handler = DefaultStorageHandler(storageDirectory: URL(fileURLWithPath: "/data/dicom"))
///
/// // Create and start server
/// let server = DICOMStorageServer(configuration: config, delegate: handler)
/// try await server.start()
///
/// // Listen for received files
/// for await event in server.events {
///     switch event {
///     case .fileReceived(let file):
///         print("Received: \(file.sopInstanceUID)")
///     case .error(let error):
///         print("Error: \(error)")
///     default:
///         break
///     }
/// }
///
/// // Stop server
/// await server.stop()
/// ```
public actor DICOMStorageServer {
    
    /// Server configuration
    public let configuration: StorageSCPConfiguration
    
    /// Storage delegate for handling received files
    private let delegate: any StorageDelegate
    
    /// The network listener
    private var listener: NWListener?
    
    /// Active associations
    private var activeAssociations: [ObjectIdentifier: SCPAssociation] = [:]
    
    /// Event stream continuation
    private var eventContinuation: AsyncStream<StorageServerEvent>.Continuation?
    
    /// Whether the server is running
    public private(set) var isRunning: Bool = false
    
    /// Creates a Storage SCP server
    ///
    /// - Parameters:
    ///   - configuration: Server configuration
    ///   - delegate: Storage delegate for handling received files
    public init(configuration: StorageSCPConfiguration, delegate: any StorageDelegate) {
        self.configuration = configuration
        self.delegate = delegate
    }
    
    /// Event stream for monitoring server activity
    public var events: AsyncStream<StorageServerEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.handleStreamTermination() }
            }
        }
    }
    
    /// Starts the server
    ///
    /// - Throws: `DICOMNetworkError.connectionFailed` if server fails to start
    public func start() async throws {
        guard !isRunning else {
            throw DICOMNetworkError.invalidState("Server is already running")
        }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw DICOMNetworkError.invalidPDU("Invalid port: \(configuration.port)")
        }
        
        let listener = try NWListener(using: parameters, on: port)
        self.listener = listener
        
        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleListenerState(state) }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleNewConnection(connection) }
        }
        
        listener.start(queue: .global(qos: .userInitiated))
        isRunning = true
        
        eventContinuation?.yield(.started(port: configuration.port))
    }
    
    /// Stops the server
    public func stop() async {
        guard isRunning else { return }
        
        listener?.cancel()
        listener = nil
        
        // Close all active associations
        for association in activeAssociations.values {
            await association.abort()
        }
        activeAssociations.removeAll()
        
        isRunning = false
        eventContinuation?.yield(.stopped)
        eventContinuation?.finish()
    }
    
    /// Number of active associations
    public var activeAssociationCount: Int {
        activeAssociations.count
    }
    
    // MARK: - Private Methods
    
    private func handleStreamTermination() {
        eventContinuation = nil
    }
    
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .failed(let error):
            eventContinuation?.yield(.error(DICOMNetworkError.connectionFailed(error.localizedDescription)))
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) async {
        // Check if we've reached the maximum number of associations
        guard activeAssociations.count < configuration.maxConcurrentAssociations else {
            connection.cancel()
            return
        }
        
        // Create a new SCP association handler
        let association = SCPAssociation(
            connection: connection,
            configuration: configuration,
            delegate: delegate,
            eventHandler: { [weak self] event in
                await self?.handleAssociationEvent(event)
            },
            completionHandler: { [weak self] completedAssociation in
                await self?.removeAssociationAsync(completedAssociation)
            }
        )
        
        let id = ObjectIdentifier(association)
        activeAssociations[id] = association
        
        // Start handling the association
        await association.start()
    }
    
    private func handleAssociationEvent(_ event: StorageServerEvent) {
        eventContinuation?.yield(event)
    }
    
    nonisolated func removeAssociation(_ association: SCPAssociation) {
        Task {
            await self.removeAssociationAsync(association)
        }
    }
    
    private func removeAssociationAsync(_ association: SCPAssociation) {
        let id = ObjectIdentifier(association)
        activeAssociations.removeValue(forKey: id)
    }
}

// MARK: - SCP Association Handler

/// Handles a single SCP association
actor SCPAssociation {
    /// The network connection
    private let connection: NWConnection
    
    /// Server configuration
    private let configuration: StorageSCPConfiguration
    
    /// Storage delegate
    private let delegate: any StorageDelegate
    
    /// Event handler callback
    private let eventHandler: @Sendable (StorageServerEvent) async -> Void
    
    /// Completion handler called when association ends
    private let completionHandler: @Sendable (SCPAssociation) async -> Void
    
    /// Negotiated presentation contexts (context ID -> transfer syntax)
    private var acceptedContexts: [UInt8: (abstractSyntax: String, transferSyntax: String)] = [:]
    
    /// Calling AE title
    private var callingAETitle: String = ""
    
    /// Maximum PDU size for sending
    private var maxPDUSize: UInt32 = defaultMaxPDUSize
    
    /// Message assembler
    private let messageAssembler = MessageAssembler()
    
    /// Whether the association is established
    private var isEstablished: Bool = false
    
    /// Creates an SCP association handler
    init(
        connection: NWConnection,
        configuration: StorageSCPConfiguration,
        delegate: any StorageDelegate,
        eventHandler: @escaping @Sendable (StorageServerEvent) async -> Void,
        completionHandler: @escaping @Sendable (SCPAssociation) async -> Void
    ) {
        self.connection = connection
        self.configuration = configuration
        self.delegate = delegate
        self.eventHandler = eventHandler
        self.completionHandler = completionHandler
    }
    
    /// Starts handling the association
    func start() async {
        connection.start(queue: .global(qos: .userInitiated))
        
        // Wait for connection to be ready
        await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    continuation.resume()
                } else if case .failed = state {
                    continuation.resume()
                } else if case .cancelled = state {
                    continuation.resume()
                }
            }
        }
        
        // Reset state handler
        connection.stateUpdateHandler = nil
        
        guard connection.state == .ready else {
            await completionHandler(self)
            return
        }
        
        // Process the association
        do {
            try await handleAssociation()
        } catch {
            await eventHandler(.error(error))
        }
        
        // Notify server that this association is complete
        await completionHandler(self)
    }
    
    /// Aborts the association
    func abort() async {
        let abortPDU = AbortPDU(source: .serviceProvider, reason: AbortReason.notSpecified.rawValue)
        try? await send(pdu: abortPDU)
        connection.cancel()
    }
    
    // MARK: - Private Methods
    
    private func handleAssociation() async throws {
        // Wait for A-ASSOCIATE-RQ
        let requestPDU = try await receivePDU()
        
        guard let associateRequest = requestPDU as? AssociateRequestPDU else {
            // Send abort - unexpected PDU
            try await sendAbort(reason: .unexpectedPDU)
            return
        }
        
        callingAETitle = associateRequest.callingAETitle.value
        
        // Check if calling AE is allowed
        guard configuration.isCallingAEAllowed(callingAETitle) else {
            try await sendAssociateReject(
                result: .permanentRejected,
                source: .serviceUserACSERelated,
                reason: 2 // Calling AE Title not recognized
            )
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "Calling AE not allowed"))
            return
        }
        
        // Check if called AE matches
        let calledAE = associateRequest.calledAETitle.value
        guard calledAE == configuration.aeTitle.value else {
            try await sendAssociateReject(
                result: .permanentRejected,
                source: .serviceUserACSERelated,
                reason: 7 // Called AE Title not recognized
            )
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "Called AE mismatch"))
            return
        }
        
        // Build association info
        // Note: Remote port extraction from NWConnection.endpoint is not directly available
        // as endpoints may be various types (hostPort, service, etc.)
        let info = AssociationInfo(
            callingAETitle: callingAETitle,
            calledAETitle: calledAE,
            remoteHost: connection.endpoint.debugDescription,
            remotePort: 0, // Port not directly available from NWConnection endpoint
            proposedSOPClasses: associateRequest.presentationContexts.map { $0.abstractSyntax },
            proposedTransferSyntaxes: associateRequest.presentationContexts.flatMap { $0.transferSyntaxes }
        )
        
        // Ask delegate if we should accept
        guard await delegate.shouldAcceptAssociation(from: info) else {
            try await sendAssociateReject(
                result: .permanentRejected,
                source: .serviceUserACSERelated,
                reason: 1 // No reason given
            )
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "Rejected by delegate"))
            return
        }
        
        // Negotiate presentation contexts
        let acceptedPresentationContexts = negotiatePresentationContexts(associateRequest.presentationContexts)
        
        // Store negotiated maximum PDU size
        maxPDUSize = min(configuration.maxPDUSize, associateRequest.maxPDUSize)
        
        // Send A-ASSOCIATE-AC
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: configuration.aeTitle,
            callingAETitle: associateRequest.callingAETitle,
            presentationContexts: acceptedPresentationContexts,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName
        )
        
        try await send(pdu: acceptPDU)
        isEstablished = true
        
        await eventHandler(.associationEstablished(info))
        
        // Process DIMSE messages until release or abort
        try await processMessages()
    }
    
    private func negotiatePresentationContexts(_ proposed: [PresentationContext]) -> [AcceptedPresentationContext] {
        var accepted: [AcceptedPresentationContext] = []
        let effectiveSOPClasses = configuration.effectiveSOPClasses
        let effectiveTransferSyntaxes = configuration.effectiveTransferSyntaxes
        
        for context in proposed {
            // Check if we support this SOP Class
            guard effectiveSOPClasses.contains(context.abstractSyntax) else {
                accepted.append(AcceptedPresentationContext(
                    id: context.id,
                    result: .abstractSyntaxNotSupported
                ))
                continue
            }
            
            // Find first supported transfer syntax
            var selectedTransferSyntax: String? = nil
            for ts in context.transferSyntaxes {
                if effectiveTransferSyntaxes.contains(ts) {
                    selectedTransferSyntax = ts
                    break
                }
            }
            
            if let ts = selectedTransferSyntax {
                accepted.append(AcceptedPresentationContext(
                    id: context.id,
                    result: .acceptance,
                    transferSyntax: ts
                ))
                acceptedContexts[context.id] = (context.abstractSyntax, ts)
            } else {
                accepted.append(AcceptedPresentationContext(
                    id: context.id,
                    result: .transferSyntaxesNotSupported
                ))
            }
        }
        
        return accepted
    }
    
    private func processMessages() async throws {
        while isEstablished {
            let pdu = try await receivePDU()
            
            switch pdu {
            case let dataPDU as DataTransferPDU:
                try await handleDataTransfer(dataPDU)
                
            case _ as ReleaseRequestPDU:
                // Send A-RELEASE-RP
                let releaseResponse = ReleaseResponsePDU()
                try await send(pdu: releaseResponse)
                isEstablished = false
                connection.cancel()
                await eventHandler(.associationReleased(callingAE: callingAETitle))
                
            case let abortPDU as AbortPDU:
                isEstablished = false
                connection.cancel()
                await eventHandler(.error(DICOMNetworkError.associationAborted(
                    source: abortPDU.source,
                    reason: abortPDU.reason
                )))
                
            default:
                try await sendAbort(reason: .unexpectedPDU)
                isEstablished = false
            }
        }
    }
    
    private func handleDataTransfer(_ dataPDU: DataTransferPDU) async throws {
        // Assemble message
        guard let message = try messageAssembler.addPDVs(from: dataPDU) else {
            // Message not yet complete
            return
        }
        
        // Handle based on command type
        switch message.command {
        case .cEchoRequest:
            try await handleCEcho(message)
            
        case .cStoreRequest:
            try await handleCStore(message)
            
        default:
            // Unsupported command - send error response
            break
        }
    }
    
    private func handleCEcho(_ message: AssembledMessage) async throws {
        guard let request = message.asCEchoRequest() else { return }
        
        // Send C-ECHO-RSP
        let response = CEchoResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            status: .success,
            presentationContextID: message.presentationContextID
        )
        
        try await sendDIMSEResponse(response)
    }
    
    private func handleCStore(_ message: AssembledMessage) async throws {
        guard let request = message.asCStoreRequest() else { return }
        
        let sopClassUID = request.affectedSOPClassUID
        let sopInstanceUID = request.affectedSOPInstanceUID
        
        // Ask delegate if we should receive
        let shouldReceive = await delegate.willReceive(sopClassUID: sopClassUID, sopInstanceUID: sopInstanceUID)
        
        if !shouldReceive {
            // Send rejection
            let response = CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .refusedOutOfResources,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            return
        }
        
        // Get transfer syntax for this context
        let transferSyntax = acceptedContexts[message.presentationContextID]?.transferSyntax ?? "1.2.840.10008.1.2"
        
        // Create received file record
        let receivedFile = ReceivedFile(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            dataSetData: message.dataSet ?? Data(),
            transferSyntaxUID: transferSyntax,
            callingAETitle: callingAETitle
        )
        
        // Notify delegate
        do {
            try await delegate.didReceive(file: receivedFile)
            
            // Send success response
            let response = CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .success,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            
            await eventHandler(.fileReceived(receivedFile))
            
        } catch {
            // Send failure response
            let response = CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .processingFailure,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            
            await delegate.didFail(error: error, for: sopInstanceUID)
        }
    }
    
    private func sendDIMSEResponse(_ response: DIMSEResponse) async throws {
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: response.commandSet,
            dataSet: nil,
            presentationContextID: response.presentationContextID
        )
        
        for pdu in pdus {
            try await send(pdu: pdu)
        }
    }
    
    private func sendAssociateReject(result: AssociateRejectResult, source: AssociateRejectSource, reason: UInt8) async throws {
        let rejectPDU = AssociateRejectPDU(result: result, source: source, reason: reason)
        try await send(pdu: rejectPDU)
        connection.cancel()
    }
    
    private func sendAbort(reason: AbortReason) async throws {
        let abortPDU = AbortPDU(source: .serviceProvider, reason: reason.rawValue)
        try await send(pdu: abortPDU)
        connection.cancel()
        isEstablished = false
    }
    
    private func send(pdu: any PDU) async throws {
        let data = try pdu.encode()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: DICOMNetworkError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    private func receivePDU() async throws -> any PDU {
        // Read PDU header (6 bytes)
        let headerData = try await receive(length: 6)
        let (_, pduLength) = try PDUDecoder.readHeader(from: headerData)
        
        // Validate PDU length
        guard pduLength <= configuration.maxPDUSize else {
            throw DICOMNetworkError.pduTooLarge(received: pduLength, maximum: configuration.maxPDUSize)
        }
        
        // Read PDU body
        let bodyData = try await receive(length: Int(pduLength))
        
        // Combine and decode
        var fullPDU = headerData
        fullPDU.append(bodyData)
        
        return try PDUDecoder.decode(from: fullPDU)
    }
    
    private func receive(length: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: DICOMNetworkError.connectionFailed(error.localizedDescription))
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
}

#endif
