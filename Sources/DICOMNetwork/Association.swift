import Foundation

/// Default DICOM port number
public let dicomDefaultPort: UInt16 = 104

/// Alternative DICOM port (commonly used in testing)
public let dicomAlternativePort: UInt16 = 11112

/// Configuration for a DICOM Association
///
/// Contains all the parameters needed to establish and maintain a DICOM association.
public struct AssociationConfiguration: Sendable, Hashable {
    /// The local Application Entity title (calling AE)
    public let callingAETitle: AETitle
    
    /// The remote Application Entity title (called AE)
    public let calledAETitle: AETitle
    
    /// The remote host address
    public let host: String
    
    /// The remote port number
    public let port: UInt16
    
    /// Maximum PDU size to propose
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID
    public let implementationClassUID: String
    
    /// Implementation Version Name (optional)
    public let implementationVersionName: String?
    
    /// Connection timeout in seconds
    public let timeout: TimeInterval
    
    /// ARTIM (Association Request/Release Timer) timeout in seconds
    ///
    /// This timer is started when an A-ASSOCIATE-RQ or A-RELEASE-RQ is sent
    /// and should be stopped when the response is received. If the timer expires,
    /// the association is aborted.
    ///
    /// Reference: PS3.8 Section 9.1.1 - ARTIM Timer
    ///
    /// Set to `nil` to disable the ARTIM timer (not recommended for production).
    /// Default is 30 seconds.
    public let artimTimeout: TimeInterval?
    
    /// Whether to use TLS encryption
    public let tlsEnabled: Bool
    
    /// User identity for authentication (optional)
    ///
    /// When set, user identity information will be included in the A-ASSOCIATE-RQ PDU
    /// for authentication with the remote SCP.
    ///
    /// Reference: PS3.7 Section D.3.3.7 - User Identity Negotiation
    public let userIdentity: UserIdentity?
    
    /// Creates association configuration
    ///
    /// - Parameters:
    ///   - callingAETitle: Local AE title
    ///   - calledAETitle: Remote AE title
    ///   - host: Remote host address
    ///   - port: Remote port (default: 104)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - timeout: Connection timeout (default: 30 seconds)
    ///   - artimTimeout: ARTIM timer timeout in seconds (default: 30 seconds, nil to disable)
    ///   - tlsEnabled: Use TLS (default: false)
    ///   - userIdentity: User identity for authentication (optional)
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        host: String,
        port: UInt16 = dicomDefaultPort,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String,
        implementationVersionName: String? = nil,
        timeout: TimeInterval = 30,
        artimTimeout: TimeInterval? = 30,
        tlsEnabled: Bool = false,
        userIdentity: UserIdentity? = nil
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.host = host
        self.port = port
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.timeout = timeout
        self.artimTimeout = artimTimeout
        self.tlsEnabled = tlsEnabled
        self.userIdentity = userIdentity
    }
}

/// Negotiated association parameters after successful association establishment
public struct NegotiatedAssociation: Sendable {
    /// The accepted presentation contexts
    public let acceptedPresentationContexts: [AcceptedPresentationContext]
    
    /// The negotiated maximum PDU size (minimum of local and remote)
    public let maxPDUSize: UInt32
    
    /// Remote implementation class UID
    public let remoteImplementationClassUID: String
    
    /// Remote implementation version name
    public let remoteImplementationVersionName: String?
    
    /// User identity server response (if user identity was requested and accepted)
    ///
    /// Reference: PS3.7 Section D.3.3.7.2 - Server Response
    public let userIdentityServerResponse: UserIdentityServerResponse?
    
    /// The raw A-ASSOCIATE-AC PDU
    public let acceptPDU: AssociateAcceptPDU
    
    /// Creates negotiated association info
    init(acceptPDU: AssociateAcceptPDU, localMaxPDUSize: UInt32) {
        self.acceptPDU = acceptPDU
        self.acceptedPresentationContexts = acceptPDU.presentationContexts
        self.maxPDUSize = min(localMaxPDUSize, acceptPDU.maxPDUSize)
        self.remoteImplementationClassUID = acceptPDU.implementationClassUID
        self.remoteImplementationVersionName = acceptPDU.implementationVersionName
        self.userIdentityServerResponse = acceptPDU.userIdentityServerResponse
    }
    
    /// Gets the accepted transfer syntax for a presentation context ID
    ///
    /// - Parameter contextID: The presentation context ID
    /// - Returns: The accepted transfer syntax, or nil if not accepted
    public func acceptedTransferSyntax(forContextID contextID: UInt8) -> String? {
        acceptedPresentationContexts.first {
            $0.id == contextID && $0.isAccepted
        }?.transferSyntax
    }
    
    /// Whether a specific presentation context was accepted
    ///
    /// - Parameter contextID: The presentation context ID
    /// - Returns: True if the context was accepted
    public func isContextAccepted(_ contextID: UInt8) -> Bool {
        acceptedPresentationContexts.contains { $0.id == contextID && $0.isAccepted }
    }
}

#if canImport(Network)
import Network

/// DICOM Association for Service Class User (SCU) operations
///
/// Manages the lifecycle of a DICOM association including establishment,
/// data transfer, and release.
///
/// Reference: PS3.8 Section 7 - DICOM Upper Layer Service
///
/// ## Usage
///
/// ```swift
/// let config = AssociationConfiguration(
///     callingAETitle: try AETitle("MY_SCU"),
///     calledAETitle: try AETitle("PACS"),
///     host: "pacs.hospital.com",
///     port: 11112,
///     implementationClassUID: "1.2.3.4.5.6.7.8.9"
/// )
///
/// let association = Association(configuration: config)
///
/// // Request presentation contexts
/// let context = try PresentationContext(
///     id: 1,
///     abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
///     transferSyntaxes: ["1.2.840.10008.1.2.1"]
/// )
///
/// // Establish association
/// let negotiated = try await association.request(presentationContexts: [context])
///
/// // Send data
/// let pdv = PresentationDataValue(
///     presentationContextID: 1,
///     isCommand: true,
///     isLastFragment: true,
///     data: commandData
/// )
/// try await association.send(pdv: pdv)
///
/// // Receive response
/// let response = try await association.receive()
///
/// // Release association
/// try await association.release()
/// ```
public final class Association: @unchecked Sendable {
    
    /// The association configuration
    public let configuration: AssociationConfiguration
    
    /// The current association state
    public var state: AssociationState {
        stateMachine.state
    }
    
    /// The negotiated association parameters (available after successful establishment)
    public private(set) var negotiated: NegotiatedAssociation?
    
    /// The underlying TCP connection
    private var connection: DICOMConnection?
    
    /// The association state machine
    private let stateMachine = AssociationStateMachine()
    
    /// Lock for thread-safe operations
    private let lock = NSLock()
    
    /// Creates a new association
    ///
    /// - Parameter configuration: The association configuration
    public init(configuration: AssociationConfiguration) {
        self.configuration = configuration
    }
    
    /// Requests an association with the remote peer
    ///
    /// - Parameter presentationContexts: The presentation contexts to propose
    /// - Returns: The negotiated association parameters
    /// - Throws: `DICOMNetworkError.connectionFailed` if connection fails
    /// - Throws: `DICOMNetworkError.associationRejected` if association is rejected
    /// - Throws: `DICOMNetworkError.artimTimerExpired` if ARTIM timer expires
    public func request(presentationContexts: [PresentationContext]) async throws -> NegotiatedAssociation {
        // Ensure we're in idle state
        guard state == .idle else {
            throw DICOMNetworkError.invalidState("Cannot request association: current state is \(state)")
        }
        
        // Create and establish TCP connection
        let conn = try DICOMConnection(
            host: configuration.host,
            port: configuration.port,
            maxPDUSize: configuration.maxPDUSize,
            timeout: configuration.timeout,
            tlsConfiguration: configuration.tlsEnabled ? .default : nil
        )
        connection = conn
        
        try await conn.connect()
        _ = stateMachine.handleEvent(.transportConnected)
        
        // Build and send A-ASSOCIATE-RQ
        let associateRequest = AssociateRequestPDU(
            calledAETitle: configuration.calledAETitle,
            callingAETitle: configuration.callingAETitle,
            presentationContexts: presentationContexts,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName,
            userIdentity: configuration.userIdentity
        )
        
        try await conn.send(pdu: associateRequest)
        _ = stateMachine.handleEvent(.associateRequestSent)
        
        // Wait for response with ARTIM timer
        let responsePDU: any PDU
        do {
            responsePDU = try await receiveWithARTIMTimer(conn: conn)
        } catch let error as DICOMNetworkError where error.isARTIMExpired {
            _ = stateMachine.handleEvent(.artimTimerExpired)
            // Send abort and close connection
            let abortPDU = AbortPDU(source: .serviceProvider, reason: AbortReason.notSpecified.rawValue)
            try? await conn.send(pdu: abortPDU)
            conn.abort()
            _ = stateMachine.handleEvent(.transportConnectionClosed)
            throw error
        }
        
        switch responsePDU {
        case let acceptPDU as AssociateAcceptPDU:
            _ = stateMachine.handleEvent(.associateAcceptReceived(acceptPDU))
            
            // Check if any presentation context was accepted
            guard acceptPDU.acceptedContextIDs.count > 0 else {
                try await performAbort(reason: .notSpecified)
                throw DICOMNetworkError.noPresentationContextAccepted
            }
            
            let negotiatedAssoc = NegotiatedAssociation(
                acceptPDU: acceptPDU,
                localMaxPDUSize: configuration.maxPDUSize
            )
            self.negotiated = negotiatedAssoc
            return negotiatedAssoc
            
        case let rejectPDU as AssociateRejectPDU:
            _ = stateMachine.handleEvent(.associateRejectReceived(rejectPDU))
            await conn.disconnect()
            throw DICOMNetworkError.associationRejected(
                result: rejectPDU.result,
                source: rejectPDU.source,
                reason: rejectPDU.reason
            )
            
        case let abortPDU as AbortPDU:
            _ = stateMachine.handleEvent(.abortReceived(abortPDU))
            await conn.disconnect()
            throw DICOMNetworkError.associationAborted(
                source: abortPDU.source,
                reason: abortPDU.reason
            )
            
        default:
            try await performAbort(reason: .unexpectedPDU)
            throw DICOMNetworkError.unexpectedPDUType(
                expected: .associateAccept,
                received: responsePDU.pduType
            )
        }
    }
    
    /// Sends a Presentation Data Value (PDV) to the remote peer
    ///
    /// - Parameter pdv: The PDV to send
    /// - Throws: `DICOMNetworkError.invalidState` if not in established state
    public func send(pdv: PresentationDataValue) async throws {
        guard state == .established else {
            throw DICOMNetworkError.invalidState("Cannot send data: association not established")
        }
        
        guard let conn = connection else {
            throw DICOMNetworkError.connectionClosed
        }
        
        // Verify the presentation context is accepted
        guard negotiated?.isContextAccepted(pdv.presentationContextID) == true else {
            throw DICOMNetworkError.noPresentationContextAccepted
        }
        
        let dataPDU = DataTransferPDU(pdv: pdv)
        try await conn.send(pdu: dataPDU)
        _ = stateMachine.handleEvent(.dataTransferSent)
    }
    
    /// Sends multiple PDVs in a single P-DATA-TF PDU
    ///
    /// - Parameter pdvs: The PDVs to send
    /// - Throws: `DICOMNetworkError.invalidState` if not in established state
    public func send(pdvs: [PresentationDataValue]) async throws {
        guard state == .established else {
            throw DICOMNetworkError.invalidState("Cannot send data: association not established")
        }
        
        guard let conn = connection else {
            throw DICOMNetworkError.connectionClosed
        }
        
        let dataPDU = DataTransferPDU(presentationDataValues: pdvs)
        try await conn.send(pdu: dataPDU)
        _ = stateMachine.handleEvent(.dataTransferSent)
    }
    
    /// Receives data from the remote peer
    ///
    /// - Returns: The received P-DATA-TF PDU
    /// - Throws: `DICOMNetworkError.invalidState` if not in established state
    /// - Throws: `DICOMNetworkError.associationAborted` if abort is received
    /// - Throws: `DICOMNetworkError.connectionClosed` if release is received
    public func receive() async throws -> DataTransferPDU {
        guard state == .established else {
            throw DICOMNetworkError.invalidState("Cannot receive data: association not established")
        }
        
        guard let conn = connection else {
            throw DICOMNetworkError.connectionClosed
        }
        
        let pdu = try await conn.receivePDU()
        
        switch pdu {
        case let dataPDU as DataTransferPDU:
            _ = stateMachine.handleEvent(.dataTransferReceived(dataPDU))
            return dataPDU
            
        case _ as ReleaseRequestPDU:
            _ = stateMachine.handleEvent(.releaseRequestReceived)
            throw DICOMNetworkError.connectionClosed
            
        case let abortPDU as AbortPDU:
            _ = stateMachine.handleEvent(.abortReceived(abortPDU))
            await conn.disconnect()
            throw DICOMNetworkError.associationAborted(
                source: abortPDU.source,
                reason: abortPDU.reason
            )
            
        default:
            try await performAbort(reason: .unexpectedPDU)
            throw DICOMNetworkError.unexpectedPDUType(
                expected: .dataTransfer,
                received: pdu.pduType
            )
        }
    }
    
    /// Releases the association gracefully
    ///
    /// Sends an A-RELEASE-RQ and waits for A-RELEASE-RP.
    ///
    /// - Throws: `DICOMNetworkError.invalidState` if not in established state
    /// - Throws: `DICOMNetworkError.artimTimerExpired` if ARTIM timer expires
    public func release() async throws {
        guard state == .established else {
            throw DICOMNetworkError.invalidState("Cannot release: association not established")
        }
        
        guard let conn = connection else {
            throw DICOMNetworkError.connectionClosed
        }
        
        // Send A-RELEASE-RQ
        let releaseRequest = ReleaseRequestPDU()
        try await conn.send(pdu: releaseRequest)
        _ = stateMachine.handleEvent(.localReleaseRequest)
        
        // Wait for A-RELEASE-RP with ARTIM timer
        let responsePDU: any PDU
        do {
            responsePDU = try await receiveWithARTIMTimer(conn: conn)
        } catch let error as DICOMNetworkError where error.isARTIMExpired {
            _ = stateMachine.handleEvent(.artimTimerExpired)
            // Send abort and close connection
            let abortPDU = AbortPDU(source: .serviceProvider, reason: AbortReason.notSpecified.rawValue)
            try? await conn.send(pdu: abortPDU)
            conn.abort()
            _ = stateMachine.handleEvent(.transportConnectionClosed)
            throw error
        }
        
        switch responsePDU {
        case _ as ReleaseResponsePDU:
            _ = stateMachine.handleEvent(.releaseResponseReceived)
            await conn.disconnect()
            
        case let abortPDU as AbortPDU:
            _ = stateMachine.handleEvent(.abortReceived(abortPDU))
            await conn.disconnect()
            throw DICOMNetworkError.associationAborted(
                source: abortPDU.source,
                reason: abortPDU.reason
            )
            
        case _ as ReleaseRequestPDU:
            // Release collision - both sides requested release simultaneously
            _ = stateMachine.handleEvent(.releaseRequestReceived)
            // As the requestor, we send our response and close
            let releaseResponse = ReleaseResponsePDU()
            try? await conn.send(pdu: releaseResponse)
            await conn.disconnect()
            
        default:
            try await performAbort(reason: .unexpectedPDU)
            throw DICOMNetworkError.unexpectedPDUType(
                expected: .releaseResponse,
                received: responsePDU.pduType
            )
        }
    }
    
    /// Aborts the association
    ///
    /// Sends an A-ABORT PDU and closes the connection immediately.
    ///
    /// - Parameter reason: The abort reason (default: not specified)
    public func abort(reason: AbortReason = .notSpecified) async throws {
        try await performAbort(reason: reason)
    }
    
    // MARK: - Private Methods
    
    private func performAbort(reason: AbortReason) async throws {
        guard let conn = connection else {
            return
        }
        
        let abortPDU = AbortPDU(source: .serviceUser, reason: reason)
        try? await conn.send(pdu: abortPDU)
        _ = stateMachine.handleEvent(.abortSent)
        
        conn.abort()
        _ = stateMachine.handleEvent(.transportConnectionClosed)
    }
    
    /// Receives a PDU with ARTIM timer protection
    ///
    /// If artimTimeout is configured and the timer expires before receiving a PDU,
    /// throws `DICOMNetworkError.artimTimerExpired`.
    ///
    /// - Parameter conn: The connection to receive from
    /// - Returns: The received PDU
    /// - Throws: `DICOMNetworkError.artimTimerExpired` if timer expires
    private func receiveWithARTIMTimer(conn: DICOMConnection) async throws -> any PDU {
        guard let artimTimeout = configuration.artimTimeout else {
            // ARTIM timer disabled, just receive normally
            return try await conn.receivePDU()
        }
        
        // Use task group to race between receive and timeout
        return try await withThrowingTaskGroup(of: ARTIMResult.self) { group in
            // Task 1: Receive PDU
            group.addTask {
                let pdu = try await conn.receivePDU()
                return .pdu(pdu)
            }
            
            // Task 2: ARTIM timer
            group.addTask {
                try await Task.sleep(for: .seconds(artimTimeout))
                return .timerExpired
            }
            
            // Wait for first result
            guard let result = try await group.next() else {
                throw DICOMNetworkError.artimTimerExpired
            }
            
            // Cancel the other task
            group.cancelAll()
            
            switch result {
            case .pdu(let pdu):
                return pdu
            case .timerExpired:
                throw DICOMNetworkError.artimTimerExpired
            }
        }
    }
}

/// Internal enum for ARTIM timer race result
private enum ARTIMResult: Sendable {
    case pdu(any PDU)
    case timerExpired
}

// MARK: - CustomStringConvertible
extension Association: CustomStringConvertible {
    public var description: String {
        """
        Association:
          Local AE: \(configuration.callingAETitle)
          Remote AE: \(configuration.calledAETitle)
          Host: \(configuration.host):\(configuration.port)
          State: \(state)
        """
    }
}

#endif
