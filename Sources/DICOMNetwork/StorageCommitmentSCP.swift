import Foundation
import DICOMCore

// MARK: - Storage Commitment SCP Configuration

/// Configuration for the DICOM Storage Commitment SCP (Service Class Provider)
///
/// Defines the settings for a Storage Commitment SCP that can receive commitment requests
/// and send commitment results.
///
/// Reference: PS3.4 Annex J - Storage Commitment Service Class
public struct StorageCommitmentSCPConfiguration: Sendable, Hashable {
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
    
    /// Calling AE Title whitelist
    /// If nil, all calling AE titles are accepted
    public let callingAEWhitelist: Set<String>?
    
    /// Calling AE Title blacklist
    /// Takes precedence over whitelist
    public let callingAEBlacklist: Set<String>?
    
    /// Default Implementation Class UID for DICOMKit Storage Commitment SCP
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.3"
    
    /// Default Implementation Version Name for DICOMKit Storage Commitment SCP
    public static let defaultImplementationVersionName = "DICOMKIT_SCSCP"
    
    /// Creates a Storage Commitment SCP configuration
    ///
    /// - Parameters:
    ///   - aeTitle: The local AE title
    ///   - port: The port to listen on (default: 11112)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - maxConcurrentAssociations: Maximum concurrent associations (default: 10)
    ///   - callingAEWhitelist: Whitelist of calling AE titles
    ///   - callingAEBlacklist: Blacklist of calling AE titles
    public init(
        aeTitle: AETitle,
        port: UInt16 = dicomAlternativePort,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        maxConcurrentAssociations: Int = 10,
        callingAEWhitelist: Set<String>? = nil,
        callingAEBlacklist: Set<String>? = nil
    ) {
        self.aeTitle = aeTitle
        self.port = port
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.maxConcurrentAssociations = max(1, maxConcurrentAssociations)
        self.callingAEWhitelist = callingAEWhitelist
        self.callingAEBlacklist = callingAEBlacklist
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

// MARK: - Commitment Request Info

/// Information about a received storage commitment request
public struct CommitmentRequestInfo: Sendable {
    /// The Transaction UID for this commitment request
    public let transactionUID: String
    
    /// The SOP references requested for commitment
    public let references: [SOPReference]
    
    /// The calling AE title that made the request
    public let callingAETitle: String
    
    /// The timestamp when the request was received
    public let timestamp: Date
    
    /// Creates a commitment request info
    public init(
        transactionUID: String,
        references: [SOPReference],
        callingAETitle: String,
        timestamp: Date = Date()
    ) {
        self.transactionUID = transactionUID
        self.references = references
        self.callingAETitle = callingAETitle
        self.timestamp = timestamp
    }
}

extension CommitmentRequestInfo: CustomStringConvertible {
    public var description: String {
        "CommitmentRequestInfo(txn: \(transactionUID), count: \(references.count), from: \(callingAETitle))"
    }
}

// MARK: - Storage Commitment Delegate Protocol

/// Protocol for handling storage commitment requests
///
/// Implement this protocol to customize how commitment requests are processed.
public protocol StorageCommitmentDelegate: Sendable {
    /// Called when an association request is received
    ///
    /// - Parameter info: Information about the requesting association
    /// - Returns: True to accept the association, false to reject
    func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool
    
    /// Called when a storage commitment request is received
    ///
    /// The delegate should verify that the referenced instances exist and are safe
    /// to commit (e.g., stored on reliable media). Return a CommitmentResult with
    /// the appropriate committed and failed references.
    ///
    /// - Parameter request: The commitment request information
    /// - Returns: The commitment result indicating success/failure for each instance
    func processCommitmentRequest(_ request: CommitmentRequestInfo) async throws -> CommitmentResult
}

/// Default implementation of StorageCommitmentDelegate
extension StorageCommitmentDelegate {
    public func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool {
        true
    }
}

// MARK: - Storage Commitment Server Event

/// Events emitted by the Storage Commitment SCP
public enum StorageCommitmentServerEvent: Sendable {
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
    
    /// A commitment request was received
    case commitmentRequestReceived(CommitmentRequestInfo)
    
    /// A commitment result was sent
    case commitmentResultSent(transactionUID: String, success: Bool)
    
    /// An error occurred
    case error(Error)
}

// MARK: - Default Commitment Handler

/// Default commitment handler that commits all requested instances
///
/// This handler always reports success for all instances. In production use,
/// you should implement a custom delegate that verifies instance storage.
public actor DefaultCommitmentHandler: StorageCommitmentDelegate {
    
    public init() {}
    
    public func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool {
        true
    }
    
    public func processCommitmentRequest(_ request: CommitmentRequestInfo) async throws -> CommitmentResult {
        // Default implementation: commit all instances successfully
        CommitmentResult(
            transactionUID: request.transactionUID,
            committedReferences: request.references,
            failedReferences: [],
            remoteAETitle: request.callingAETitle
        )
    }
}

#if canImport(Network)
import Network

// MARK: - Storage Commitment Server

/// DICOM Storage Commitment Server (SCP)
///
/// Implements the DICOM Storage Commitment Service Class as a Service Class Provider (SCP).
/// This enables receiving storage commitment requests (N-ACTION) and sending
/// commitment results (N-EVENT-REPORT) to remote Service Class Users (SCUs).
///
/// Reference: PS3.4 Annex J - Storage Commitment Service Class
/// Reference: PS3.7 Section 10.1 - N-ACTION Service
/// Reference: PS3.7 Section 10.3 - N-EVENT-REPORT Service
///
/// ## Usage
///
/// ```swift
/// // Create configuration
/// let config = StorageCommitmentSCPConfiguration(
///     aeTitle: try AETitle("MY_SCP"),
///     port: 11112
/// )
///
/// // Create handler
/// let handler = DefaultCommitmentHandler()
///
/// // Create and start server
/// let server = StorageCommitmentServer(configuration: config, delegate: handler)
/// try await server.start()
///
/// // Listen for events
/// for await event in server.events {
///     switch event {
///     case .commitmentRequestReceived(let request):
///         print("Received commitment request: \(request.transactionUID)")
///     case .commitmentResultSent(let txn, let success):
///         print("Sent result for \(txn): \(success ? "success" : "with failures")")
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
public actor StorageCommitmentServer {
    
    /// Server configuration
    public let configuration: StorageCommitmentSCPConfiguration
    
    /// Commitment delegate for handling requests
    private let delegate: any StorageCommitmentDelegate
    
    /// The network listener
    private var listener: NWListener?
    
    /// Active associations
    private var activeAssociations: [ObjectIdentifier: CommitmentSCPAssociation] = [:]
    
    /// Event stream continuation
    private var eventContinuation: AsyncStream<StorageCommitmentServerEvent>.Continuation?
    
    /// Whether the server is running
    public private(set) var isRunning: Bool = false
    
    /// Creates a Storage Commitment SCP server
    ///
    /// - Parameters:
    ///   - configuration: Server configuration
    ///   - delegate: Commitment delegate for handling requests
    public init(configuration: StorageCommitmentSCPConfiguration, delegate: any StorageCommitmentDelegate) {
        self.configuration = configuration
        self.delegate = delegate
    }
    
    /// Event stream for monitoring server activity
    public var events: AsyncStream<StorageCommitmentServerEvent> {
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
        let association = CommitmentSCPAssociation(
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
    
    private func handleAssociationEvent(_ event: StorageCommitmentServerEvent) {
        eventContinuation?.yield(event)
    }
    
    nonisolated func removeAssociation(_ association: CommitmentSCPAssociation) {
        Task {
            await removeAssociationAsync(association)
        }
    }
    
    private func removeAssociationAsync(_ association: CommitmentSCPAssociation) {
        let id = ObjectIdentifier(association)
        activeAssociations.removeValue(forKey: id)
    }
}

// MARK: - Commitment SCP Association

/// Handles a single association for the Storage Commitment SCP
actor CommitmentSCPAssociation {
    private let connection: NWConnection
    private let configuration: StorageCommitmentSCPConfiguration
    private let delegate: any StorageCommitmentDelegate
    private let eventHandler: @Sendable (StorageCommitmentServerEvent) async -> Void
    private let completionHandler: @Sendable (CommitmentSCPAssociation) async -> Void
    
    private var callingAETitle: String = ""
    private var calledAETitle: String = ""
    private var remoteHost: String = ""
    private var remotePort: UInt16 = 0
    private var maxPDUSize: UInt32 = defaultMaxPDUSize
    private var acceptedContexts: [UInt8: String] = [:] // Context ID -> Transfer Syntax
    private var messageAssembler = MessageAssembler()
    private var isReleasing = false
    private var currentMessageID: UInt16 = 1
    
    init(
        connection: NWConnection,
        configuration: StorageCommitmentSCPConfiguration,
        delegate: any StorageCommitmentDelegate,
        eventHandler: @escaping @Sendable (StorageCommitmentServerEvent) async -> Void,
        completionHandler: @escaping @Sendable (CommitmentSCPAssociation) async -> Void
    ) {
        self.connection = connection
        self.configuration = configuration
        self.delegate = delegate
        self.eventHandler = eventHandler
        self.completionHandler = completionHandler
        
        // Extract remote address info
        if case .hostPort(let host, let port) = connection.endpoint {
            self.remoteHost = "\(host)"
            self.remotePort = port.rawValue
        }
    }
    
    func start() async {
        connection.start(queue: .global(qos: .userInitiated))
        
        do {
            try await handleAssociation()
        } catch {
            await eventHandler(.error(error))
        }
        
        connection.cancel()
        await completionHandler(self)
    }
    
    func abort() async {
        try? await sendAbort(reason: .serviceProviderInitiatedAbort)
        connection.cancel()
    }
    
    // MARK: - Association Handling
    
    private func handleAssociation() async throws {
        // Wait for and process A-ASSOCIATE-RQ
        let firstPDU = try await receivePDU()
        
        guard let associateRequest = firstPDU as? AssociateRequestPDU else {
            try await sendAbort(reason: .unexpectedPDU)
            throw DICOMNetworkError.protocolError("Expected A-ASSOCIATE-RQ, got \(type(of: firstPDU))")
        }
        
        // Extract association info
        callingAETitle = associateRequest.callingAETitle.trimmingCharacters(in: .whitespaces)
        calledAETitle = associateRequest.calledAETitle.trimmingCharacters(in: .whitespaces)
        
        // Check calling AE is allowed
        guard configuration.isCallingAEAllowed(callingAETitle) else {
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "Calling AE not allowed"))
            try await sendAssociateReject(
                result: .rejectedPermanent,
                source: .serviceUserACSERelated,
                reason: 3 // Calling AE Title not recognized
            )
            throw DICOMNetworkError.associationRejected("Calling AE not allowed: \(callingAETitle)")
        }
        
        // Check called AE matches our AE
        if calledAETitle != configuration.aeTitle.value {
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "Called AE mismatch"))
            try await sendAssociateReject(
                result: .rejectedPermanent,
                source: .serviceUserACSERelated,
                reason: 7 // Called AE Title not recognized
            )
            throw DICOMNetworkError.associationRejected("Called AE mismatch: \(calledAETitle)")
        }
        
        // Create association info for delegate
        let proposedSOPClasses = associateRequest.presentationContexts.map { $0.abstractSyntax }
        let proposedTransferSyntaxes = associateRequest.presentationContexts.flatMap { $0.transferSyntaxes }
        
        let associationInfo = AssociationInfo(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            remoteHost: remoteHost,
            remotePort: remotePort,
            proposedSOPClasses: proposedSOPClasses,
            proposedTransferSyntaxes: Array(Set(proposedTransferSyntaxes))
        )
        
        // Ask delegate if we should accept
        let shouldAccept = await delegate.shouldAcceptAssociation(from: associationInfo)
        guard shouldAccept else {
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "Rejected by delegate"))
            try await sendAssociateReject(
                result: .rejectedPermanent,
                source: .serviceUserACSERelated,
                reason: 1 // No reason given
            )
            throw DICOMNetworkError.associationRejected("Rejected by delegate")
        }
        
        // Negotiate presentation contexts
        let acceptedContextList = negotiatePresentationContexts(associateRequest.presentationContexts)
        
        // Check if at least one context was accepted
        guard !acceptedContextList.isEmpty else {
            await eventHandler(.associationRejected(callingAE: callingAETitle, reason: "No presentation contexts accepted"))
            try await sendAssociateReject(
                result: .rejectedTransient,
                source: .serviceProviderACSERelated,
                reason: 1 // No reason given
            )
            throw DICOMNetworkError.presentationContextRejected("No presentation contexts could be accepted")
        }
        
        // Store accepted contexts
        for context in acceptedContextList {
            acceptedContexts[context.id] = context.transferSyntax
        }
        
        // Set max PDU size from request
        if let userInfo = associateRequest.userInformation {
            if let maxLength = userInfo.maxPDULength {
                maxPDUSize = min(maxLength, configuration.maxPDUSize)
            }
        }
        
        // Build and send A-ASSOCIATE-AC
        let acceptPDU = try buildAssociateAccept(
            calledAE: calledAETitle,
            callingAE: callingAETitle,
            acceptedContexts: acceptedContextList,
            applicationContext: associateRequest.applicationContext
        )
        
        try await send(pdu: acceptPDU)
        
        await eventHandler(.associationEstablished(associationInfo))
        
        // Process messages until release or abort
        try await processMessages()
        
        await eventHandler(.associationReleased(callingAE: callingAETitle))
    }
    
    private func negotiatePresentationContexts(_ proposed: [PresentationContext]) -> [AcceptedPresentationContext] {
        var accepted: [AcceptedPresentationContext] = []
        
        for context in proposed {
            // Check if this is the Storage Commitment SOP Class
            if context.abstractSyntax == storageCommitmentPushModelSOPClassUID {
                // Find a transfer syntax we support
                let supportedTS = [
                    explicitVRLittleEndianTransferSyntaxUID,
                    implicitVRLittleEndianTransferSyntaxUID
                ]
                
                for ts in context.transferSyntaxes {
                    if supportedTS.contains(ts) {
                        do {
                            let acceptedContext = try AcceptedPresentationContext(
                                id: context.id,
                                result: .acceptance,
                                transferSyntax: ts
                            )
                            accepted.append(acceptedContext)
                        } catch {
                            // Skip invalid contexts
                        }
                        break
                    }
                }
            }
        }
        
        return accepted
    }
    
    private func processMessages() async throws {
        while !isReleasing {
            let pdu = try await receivePDU()
            
            switch pdu {
            case let releasePDU as ReleaseRequestPDU:
                _ = releasePDU // Acknowledge we received it
                isReleasing = true
                let releaseResponse = ReleaseResponsePDU()
                try await send(pdu: releaseResponse)
                
            case let abortPDU as AbortPDU:
                _ = abortPDU // Acknowledge we received it
                throw DICOMNetworkError.associationAborted("Association aborted by peer")
                
            case let dataPDU as DataTransferPDU:
                try await handleDataTransfer(dataPDU)
                
            default:
                throw DICOMNetworkError.protocolError("Unexpected PDU type: \(type(of: pdu))")
            }
        }
    }
    
    private func handleDataTransfer(_ dataPDU: DataTransferPDU) async throws {
        // Add PDVs to the assembler
        for pdv in dataPDU.presentationDataValues {
            if let message = try messageAssembler.addPDV(pdv) {
                try await handleAssembledMessage(message)
            }
        }
    }
    
    private func handleAssembledMessage(_ message: AssembledMessage) async throws {
        // Parse the command set
        let commandData = message.commandData
        guard let commandField = CommandSet.parseCommandField(from: commandData) else {
            throw DICOMNetworkError.invalidPDU("Failed to parse command field")
        }
        
        switch commandField {
        case .nActionRequest:
            try await handleNAction(message)
        default:
            // Unsupported command
            throw DICOMNetworkError.protocolError("Unsupported command: \(commandField)")
        }
    }
    
    private func handleNAction(_ message: AssembledMessage) async throws {
        // Parse the N-ACTION request
        let commandSet = CommandSet(data: message.commandData)
        let request = NActionRequest(commandSet: commandSet, presentationContextID: message.presentationContextID)
        
        // Validate it's a Storage Commitment request
        guard request.requestedSOPClassUID == storageCommitmentPushModelSOPClassUID else {
            let response = NActionResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.requestedSOPClassUID,
                affectedSOPInstanceUID: request.requestedSOPInstanceUID,
                actionTypeID: request.actionTypeID,
                status: .sopClassNotSupported,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            return
        }
        
        guard request.actionTypeID == storageCommitmentRequestActionTypeID else {
            let response = NActionResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.requestedSOPClassUID,
                affectedSOPInstanceUID: request.requestedSOPInstanceUID,
                actionTypeID: request.actionTypeID,
                status: .noSuchActionType,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            return
        }
        
        // Parse the data set to extract Transaction UID and Referenced SOP Sequence
        guard let dataSetData = message.dataSetData else {
            let response = NActionResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.requestedSOPClassUID,
                affectedSOPInstanceUID: request.requestedSOPInstanceUID,
                actionTypeID: request.actionTypeID,
                status: .processingFailure,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            return
        }
        
        // Extract transaction UID and references
        guard let transactionUID = extractUIValue(from: dataSetData, tag: Tag(group: 0x0008, element: 0x1195)) else {
            let response = NActionResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.requestedSOPClassUID,
                affectedSOPInstanceUID: request.requestedSOPInstanceUID,
                actionTypeID: request.actionTypeID,
                status: .processingFailure,
                presentationContextID: message.presentationContextID
            )
            try await sendDIMSEResponse(response)
            return
        }
        
        let references = extractSOPReferences(from: dataSetData)
        
        // Create commitment request info
        let requestInfo = CommitmentRequestInfo(
            transactionUID: transactionUID,
            references: references,
            callingAETitle: callingAETitle
        )
        
        await eventHandler(.commitmentRequestReceived(requestInfo))
        
        // Send N-ACTION response (acknowledgment that request was received)
        let actionResponse = NActionResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.requestedSOPClassUID,
            affectedSOPInstanceUID: request.requestedSOPInstanceUID,
            actionTypeID: request.actionTypeID,
            status: .success,
            presentationContextID: message.presentationContextID
        )
        try await sendDIMSEResponse(actionResponse)
        
        // Process the commitment request via delegate
        do {
            let result = try await delegate.processCommitmentRequest(requestInfo)
            
            // Send N-EVENT-REPORT with the result
            try await sendCommitmentResult(result, presentationContextID: message.presentationContextID)
            
            await eventHandler(.commitmentResultSent(transactionUID: transactionUID, success: result.isSuccess))
        } catch {
            await eventHandler(.error(error))
        }
    }
    
    private func sendCommitmentResult(_ result: CommitmentResult, presentationContextID: UInt8) async throws {
        // Determine event type based on result
        let eventTypeID: UInt16 = result.failedReferences.isEmpty ? 
            storageCommitmentSuccessEventTypeID : storageCommitmentFailureEventTypeID
        
        // Build the N-EVENT-REPORT data set
        let dataSetData = buildCommitmentResultDataSet(result)
        
        // Create N-EVENT-REPORT request
        let eventReport = NEventReportRequest(
            messageID: currentMessageID,
            affectedSOPClassUID: storageCommitmentPushModelSOPClassUID,
            affectedSOPInstanceUID: storageCommitmentPushModelSOPInstanceUID,
            eventTypeID: eventTypeID,
            hasDataSet: true,
            presentationContextID: presentationContextID
        )
        currentMessageID += 1
        
        // Send the event report with data set
        try await sendDIMSERequest(eventReport, dataSetData: dataSetData)
        
        // Wait for and process the N-EVENT-REPORT response
        let responsePDU = try await receivePDU()
        guard let dataPDU = responsePDU as? DataTransferPDU else {
            throw DICOMNetworkError.protocolError("Expected P-DATA-TF for N-EVENT-REPORT response")
        }
        
        // Process the response
        for pdv in dataPDU.presentationDataValues {
            if let message = try messageAssembler.addPDV(pdv) {
                let responseCommandSet = CommandSet(data: message.commandData)
                let response = NEventReportResponse(commandSet: responseCommandSet, presentationContextID: message.presentationContextID)
                
                if !response.status.isSuccess {
                    throw DICOMNetworkError.dimseError(response.status, "N-EVENT-REPORT failed")
                }
            }
        }
    }
    
    private func buildCommitmentResultDataSet(_ result: CommitmentResult) -> Data {
        var data = Data()
        
        // Transaction UID (0008,1195)
        data.append(encodeUIElement(tag: Tag(group: 0x0008, element: 0x1195), value: result.transactionUID))
        
        // Referenced SOP Sequence (0008,1199) - committed references
        if !result.committedReferences.isEmpty {
            var sequenceContent = Data()
            for ref in result.committedReferences {
                var itemData = Data()
                // Referenced SOP Class UID (0008,1150)
                itemData.append(encodeUIElement(tag: Tag(group: 0x0008, element: 0x1150), value: ref.sopClassUID))
                // Referenced SOP Instance UID (0008,1155)
                itemData.append(encodeUIElement(tag: Tag(group: 0x0008, element: 0x1155), value: ref.sopInstanceUID))
                sequenceContent.append(encodeSequenceItem(itemData))
            }
            sequenceContent.append(encodeSequenceDelimiter())
            data.append(encodeSequenceElement(tag: Tag(group: 0x0008, element: 0x1199), content: sequenceContent))
        }
        
        // Failed SOP Sequence (0008,1198) - failed references
        if !result.failedReferences.isEmpty {
            var sequenceContent = Data()
            for failedRef in result.failedReferences {
                var itemData = Data()
                // Referenced SOP Class UID (0008,1150)
                itemData.append(encodeUIElement(tag: Tag(group: 0x0008, element: 0x1150), value: failedRef.reference.sopClassUID))
                // Referenced SOP Instance UID (0008,1155)
                itemData.append(encodeUIElement(tag: Tag(group: 0x0008, element: 0x1155), value: failedRef.reference.sopInstanceUID))
                // Failure Reason (0008,1197)
                itemData.append(encodeUSElement(tag: Tag(group: 0x0008, element: 0x1197), value: failedRef.failureReason))
                sequenceContent.append(encodeSequenceItem(itemData))
            }
            sequenceContent.append(encodeSequenceDelimiter())
            data.append(encodeSequenceElement(tag: Tag(group: 0x0008, element: 0x1198), content: sequenceContent))
        }
        
        return data
    }
    
    // MARK: - Helper Methods for Data Encoding
    
    private func encodeUIElement(tag: Tag, value: String) -> Data {
        var data = Data()
        
        // Tag (group, element)
        data.append(contentsOf: withUnsafeBytes(of: tag.group.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: tag.element.littleEndian) { Array($0) })
        
        // VR "UI"
        data.append(contentsOf: [0x55, 0x49]) // "UI"
        
        // Pad value to even length
        var paddedValue = value
        if paddedValue.count % 2 != 0 {
            paddedValue.append("\0")
        }
        
        // Length (2 bytes for short VRs)
        let length = UInt16(paddedValue.count)
        data.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Array($0) })
        
        // Value
        data.append(Data(paddedValue.utf8))
        
        return data
    }
    
    private func encodeUSElement(tag: Tag, value: UInt16) -> Data {
        var data = Data()
        
        // Tag (group, element)
        data.append(contentsOf: withUnsafeBytes(of: tag.group.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: tag.element.littleEndian) { Array($0) })
        
        // VR "US"
        data.append(contentsOf: [0x55, 0x53]) // "US"
        
        // Length (2 bytes)
        let length: UInt16 = 2
        data.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Array($0) })
        
        // Value
        data.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
        
        return data
    }
    
    private func encodeSequenceItem(_ itemData: Data) -> Data {
        var data = Data()
        
        // Item tag (FFFE,E000)
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0])
        
        // Item length (4 bytes, little endian)
        let length = UInt32(itemData.count)
        data.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Array($0) })
        
        // Item data
        data.append(itemData)
        
        return data
    }
    
    private func encodeSequenceDelimiter() -> Data {
        var data = Data()
        
        // Sequence Delimitation Item tag (FFFE,E0DD)
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0])
        
        // Length (always 0)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        
        return data
    }
    
    private func encodeSequenceElement(tag: Tag, content: Data) -> Data {
        var data = Data()
        
        // Tag (group, element)
        data.append(contentsOf: withUnsafeBytes(of: tag.group.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: tag.element.littleEndian) { Array($0) })
        
        // VR "SQ"
        data.append(contentsOf: [0x53, 0x51]) // "SQ"
        
        // Reserved (2 bytes)
        data.append(contentsOf: [0x00, 0x00])
        
        // Length (4 bytes, undefined length = FFFFFFFF)
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])
        
        // Content
        data.append(content)
        
        return data
    }
    
    // MARK: - Helper Methods for Data Extraction
    
    private func extractUIValue(from data: Data, tag: Tag) -> String? {
        var offset = 0
        
        while offset + 8 <= data.count {
            let group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            offset += 4
            
            let byte0 = data[offset]
            let byte1 = data[offset + 1]
            let possibleVR = String(bytes: [byte0, byte1], encoding: .ascii) ?? ""
            
            let length: Int
            if possibleVR == "UI" || possibleVR == "SH" || possibleVR == "LO" || possibleVR == "CS" {
                // Short VR - 2 byte length
                length = Int(UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8))
                offset += 4
            } else if possibleVR == "SQ" || possibleVR == "OB" || possibleVR == "OW" || possibleVR == "UN" {
                // Long VR - 2 reserved + 4 byte length
                offset += 2
                length = Int(UInt32(data[offset]) |
                            (UInt32(data[offset + 1]) << 8) |
                            (UInt32(data[offset + 2]) << 16) |
                            (UInt32(data[offset + 3]) << 24))
                offset += 4
            } else {
                // Implicit VR - 4 byte length
                length = Int(UInt32(data[offset]) |
                            (UInt32(data[offset + 1]) << 8) |
                            (UInt32(data[offset + 2]) << 16) |
                            (UInt32(data[offset + 3]) << 24))
                offset += 4
            }
            
            if group == tag.group && element == tag.element {
                if length > 0 && offset + length <= data.count {
                    let valueData = data.subdata(in: offset..<(offset + length))
                    return String(data: valueData, encoding: .ascii)?
                        .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
                }
                return nil
            }
            
            if length > 0 && length != 0xFFFFFFFF {
                offset += length
            }
        }
        
        return nil
    }
    
    private func extractSOPReferences(from data: Data) -> [SOPReference] {
        var references: [SOPReference] = []
        
        // Find Referenced SOP Sequence (0008,1199)
        guard let sequenceItems = extractSequenceItems(from: data, tag: Tag(group: 0x0008, element: 0x1199)) else {
            return references
        }
        
        for itemData in sequenceItems {
            guard let sopClassUID = extractUIValue(from: itemData, tag: Tag(group: 0x0008, element: 0x1150)),
                  let sopInstanceUID = extractUIValue(from: itemData, tag: Tag(group: 0x0008, element: 0x1155)) else {
                continue
            }
            
            references.append(SOPReference(sopClassUID: sopClassUID, sopInstanceUID: sopInstanceUID))
        }
        
        return references
    }
    
    private func extractSequenceItems(from data: Data, tag: Tag) -> [Data]? {
        var offset = 0
        
        while offset + 8 <= data.count {
            let group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            offset += 4
            
            let byte0 = data[offset]
            let byte1 = data[offset + 1]
            let possibleVR = String(bytes: [byte0, byte1], encoding: .ascii) ?? ""
            
            var sequenceLength: Int = 0
            if possibleVR == "SQ" {
                offset += 2 // Skip VR
                offset += 2 // Skip reserved
                sequenceLength = Int(UInt32(data[offset]) |
                                    (UInt32(data[offset + 1]) << 8) |
                                    (UInt32(data[offset + 2]) << 16) |
                                    (UInt32(data[offset + 3]) << 24))
                offset += 4
            } else {
                sequenceLength = Int(UInt32(data[offset]) |
                                    (UInt32(data[offset + 1]) << 8) |
                                    (UInt32(data[offset + 2]) << 16) |
                                    (UInt32(data[offset + 3]) << 24))
                offset += 4
            }
            
            if group == tag.group && element == tag.element {
                var items: [Data] = []
                let sequenceEnd = sequenceLength == 0xFFFFFFFF ? data.count : offset + sequenceLength
                
                while offset < sequenceEnd && offset + 8 <= data.count {
                    let itemGroup = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                    let itemElement = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
                    
                    if itemGroup == 0xFFFE && itemElement == 0xE000 {
                        let itemLength = Int(UInt32(data[offset + 4]) |
                                            (UInt32(data[offset + 5]) << 8) |
                                            (UInt32(data[offset + 6]) << 16) |
                                            (UInt32(data[offset + 7]) << 24))
                        offset += 8
                        
                        if itemLength == 0xFFFFFFFF {
                            let itemStart = offset
                            while offset + 8 <= data.count {
                                let delimGroup = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                                let delimElement = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
                                if delimGroup == 0xFFFE && delimElement == 0xE00D {
                                    items.append(data.subdata(in: itemStart..<offset))
                                    offset += 8
                                    break
                                }
                                offset += 1
                            }
                        } else if offset + itemLength <= data.count {
                            items.append(data.subdata(in: offset..<(offset + itemLength)))
                            offset += itemLength
                        }
                    } else if itemGroup == 0xFFFE && itemElement == 0xE0DD {
                        break
                    } else {
                        break
                    }
                }
                
                return items.isEmpty ? nil : items
            }
            
            if sequenceLength > 0 && sequenceLength != 0xFFFFFFFF {
                offset += sequenceLength
            }
        }
        
        return nil
    }
    
    // MARK: - PDU Communication
    
    private func sendDIMSEResponse(_ response: DIMSEResponse) async throws {
        let commandData = response.commandSet.encode()
        let pdv = PresentationDataValue(
            contextID: response.presentationContextID,
            isCommand: true,
            isLast: true,
            data: commandData
        )
        
        let dataPDU = DataTransferPDU(presentationDataValues: [pdv])
        try await send(pdu: dataPDU)
    }
    
    private func sendDIMSERequest(_ request: DIMSERequest, dataSetData: Data?) async throws {
        var pdvs: [PresentationDataValue] = []
        
        // Command PDV
        let commandData = request.commandSet.encode()
        let commandPDV = PresentationDataValue(
            contextID: request.presentationContextID,
            isCommand: true,
            isLast: dataSetData == nil,
            data: commandData
        )
        pdvs.append(commandPDV)
        
        // Data PDV (if present)
        if let data = dataSetData {
            let dataPDV = PresentationDataValue(
                contextID: request.presentationContextID,
                isCommand: false,
                isLast: true,
                data: data
            )
            pdvs.append(dataPDV)
        }
        
        let dataPDU = DataTransferPDU(presentationDataValues: pdvs)
        try await send(pdu: dataPDU)
    }
    
    private func sendAssociateReject(result: AssociateRejectResult, source: AssociateRejectSource, reason: UInt8) async throws {
        let rejectPDU = AssociateRejectPDU(result: result, source: source, reason: reason)
        try await send(pdu: rejectPDU)
    }
    
    private func sendAbort(reason: AbortReason) async throws {
        let abortPDU = AbortPDU(source: .serviceProvider, reason: reason)
        try await send(pdu: abortPDU)
    }
    
    private func send(pdu: any PDU) async throws {
        let data = pdu.encode()
        
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
        // First read the 6-byte PDU header
        let headerData = try await receive(length: 6)
        
        guard headerData.count == 6 else {
            throw DICOMNetworkError.connectionClosed
        }
        
        // Parse header to get PDU length
        let pduLength = Int(UInt32(headerData[2]) |
                          (UInt32(headerData[3]) << 8) |
                          (UInt32(headerData[4]) << 16) |
                          (UInt32(headerData[5]) << 24))
        
        // Read the PDU body
        var fullData = headerData
        if pduLength > 0 {
            let bodyData = try await receive(length: pduLength)
            fullData.append(bodyData)
        }
        
        // Decode the PDU
        return try PDUDecoder.decode(data: fullData)
    }
    
    private func receive(length: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { content, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: DICOMNetworkError.connectionFailed(error.localizedDescription))
                } else if let data = content {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: DICOMNetworkError.connectionClosed)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
    
    private func buildAssociateAccept(
        calledAE: String,
        callingAE: String,
        acceptedContexts: [AcceptedPresentationContext],
        applicationContext: String
    ) throws -> AssociateAcceptPDU {
        let userInfo = UserInformation(
            maxPDULength: maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName
        )
        
        return AssociateAcceptPDU(
            calledAETitle: calledAE,
            callingAETitle: callingAE,
            applicationContext: applicationContext,
            presentationContexts: acceptedContexts,
            userInformation: userInfo
        )
    }
}

#endif
