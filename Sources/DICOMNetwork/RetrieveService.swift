import Foundation
import DICOMCore

// MARK: - Retrieve Progress

/// Progress information for a retrieve operation
///
/// Reports the status of sub-operations during C-MOVE or C-GET retrieval.
///
/// Reference: PS3.7 Section 9.1.4 (C-MOVE), Section 9.1.3 (C-GET)
public struct RetrieveProgress: Sendable, Hashable {
    /// Number of sub-operations remaining
    public let remaining: Int
    
    /// Number of sub-operations completed successfully
    public let completed: Int
    
    /// Number of sub-operations that failed
    public let failed: Int
    
    /// Number of sub-operations that completed with warnings
    public let warning: Int
    
    /// The total number of sub-operations (remaining + completed + failed + warning)
    public var total: Int {
        remaining + completed + failed + warning
    }
    
    /// The fraction of operations complete (0.0 to 1.0)
    public var fractionComplete: Double {
        guard total > 0 else { return 0.0 }
        return Double(completed + failed + warning) / Double(total)
    }
    
    /// Whether all sub-operations have completed (regardless of success/failure)
    public var isComplete: Bool {
        remaining == 0
    }
    
    /// Whether any sub-operations failed
    public var hasFailures: Bool {
        failed > 0
    }
    
    /// Creates retrieve progress information
    ///
    /// - Parameters:
    ///   - remaining: Number of remaining sub-operations
    ///   - completed: Number of completed sub-operations
    ///   - failed: Number of failed sub-operations
    ///   - warning: Number of warning sub-operations
    public init(remaining: Int = 0, completed: Int = 0, failed: Int = 0, warning: Int = 0) {
        self.remaining = remaining
        self.completed = completed
        self.failed = failed
        self.warning = warning
    }
    
    /// Creates retrieve progress from a C-MOVE or C-GET response
    init(from response: CMoveResponse) {
        self.remaining = Int(response.numberOfRemainingSuboperations ?? 0)
        self.completed = Int(response.numberOfCompletedSuboperations ?? 0)
        self.failed = Int(response.numberOfFailedSuboperations ?? 0)
        self.warning = Int(response.numberOfWarningSuboperations ?? 0)
    }
    
    /// Creates retrieve progress from a C-GET response
    init(from response: CGetResponse) {
        self.remaining = Int(response.numberOfRemainingSuboperations ?? 0)
        self.completed = Int(response.numberOfCompletedSuboperations ?? 0)
        self.failed = Int(response.numberOfFailedSuboperations ?? 0)
        self.warning = Int(response.numberOfWarningSuboperations ?? 0)
    }
}

// MARK: - CustomStringConvertible

extension RetrieveProgress: CustomStringConvertible {
    public var description: String {
        "Progress: \(completed)/\(total) completed, \(failed) failed, \(warning) warnings, \(remaining) remaining"
    }
}

// MARK: - Retrieve Result

/// Result of a retrieve operation
///
/// Contains information about the completed C-MOVE or C-GET operation.
public struct RetrieveResult: Sendable, Hashable {
    /// The final status of the retrieve operation
    public let status: DIMSEStatus
    
    /// The final progress information
    public let progress: RetrieveProgress
    
    /// Whether the retrieve was successful (all sub-operations completed successfully)
    public var isSuccess: Bool {
        status.isSuccess && progress.failed == 0
    }
    
    /// Whether the retrieve completed with some failures
    public var hasPartialFailures: Bool {
        status.isSuccess && progress.failed > 0
    }
    
    /// Creates a retrieve result
    ///
    /// - Parameters:
    ///   - status: The final DIMSE status
    ///   - progress: The final progress information
    public init(status: DIMSEStatus, progress: RetrieveProgress) {
        self.status = status
        self.progress = progress
    }
}

// MARK: - CustomStringConvertible

extension RetrieveResult: CustomStringConvertible {
    public var description: String {
        """
        RetrieveResult:
          Status: \(status)
          \(progress)
        """
    }
}

// MARK: - Retrieve Configuration

/// Configuration for the DICOM Retrieve Service
public struct RetrieveConfiguration: Sendable, Hashable {
    /// The local Application Entity title (calling AE)
    public let callingAETitle: AETitle
    
    /// The remote Application Entity title (called AE)
    public let calledAETitle: AETitle
    
    /// Connection timeout in seconds
    public let timeout: TimeInterval
    
    /// Maximum PDU size to propose
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID for this DICOM implementation
    public let implementationClassUID: String
    
    /// Implementation Version Name (optional)
    public let implementationVersionName: String?
    
    /// The Query/Retrieve Information Model to use
    public let informationModel: QueryRetrieveInformationModel
    
    /// User identity for authentication (optional)
    public let userIdentity: UserIdentity?
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates a retrieve configuration
    ///
    /// - Parameters:
    ///   - callingAETitle: The local AE title
    ///   - calledAETitle: The remote AE title
    ///   - timeout: Connection timeout in seconds (default: 60)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - informationModel: The Query/Retrieve Information Model (default: Study Root)
    ///   - userIdentity: User identity for authentication (optional)
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        informationModel: QueryRetrieveInformationModel = .studyRoot,
        userIdentity: UserIdentity? = nil
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.informationModel = informationModel
        self.userIdentity = userIdentity
    }
}

// MARK: - Retrieve Keys

/// Keys for building retrieve request identifiers
///
/// Similar to QueryKeys but for C-MOVE and C-GET retrieve operations.
public struct RetrieveKeys: Sendable, Hashable {
    /// The query level for the retrieve
    public let level: QueryLevel
    
    /// The key-value pairs for the identifier
    public private(set) var keys: [RetrieveKey]
    
    /// A single retrieve key
    public struct RetrieveKey: Sendable, Hashable {
        public let tag: Tag
        public let vr: VR
        public let value: String
        
        public init(tag: Tag, vr: VR, value: String) {
            self.tag = tag
            self.vr = vr
            self.value = value
        }
    }
    
    /// Creates retrieve keys for a specific level
    ///
    /// - Parameter level: The query level
    public init(level: QueryLevel) {
        self.level = level
        self.keys = []
    }
    
    // MARK: - Fluent API for common keys
    
    /// Sets the Study Instance UID
    public func studyInstanceUID(_ uid: String) -> RetrieveKeys {
        var copy = self
        copy.keys.append(RetrieveKey(tag: .studyInstanceUID, vr: .UI, value: uid))
        return copy
    }
    
    /// Sets the Series Instance UID
    public func seriesInstanceUID(_ uid: String) -> RetrieveKeys {
        var copy = self
        copy.keys.append(RetrieveKey(tag: .seriesInstanceUID, vr: .UI, value: uid))
        return copy
    }
    
    /// Sets the SOP Instance UID
    public func sopInstanceUID(_ uid: String) -> RetrieveKeys {
        var copy = self
        copy.keys.append(RetrieveKey(tag: .sopInstanceUID, vr: .UI, value: uid))
        return copy
    }
    
    /// Sets the Patient ID
    public func patientID(_ id: String) -> RetrieveKeys {
        var copy = self
        copy.keys.append(RetrieveKey(tag: .patientID, vr: .LO, value: id))
        return copy
    }
    
    // MARK: - Default Keys
    
    /// Creates retrieve keys for a study-level retrieval
    ///
    /// - Parameter studyUID: The Study Instance UID to retrieve
    /// - Returns: Configured retrieve keys
    public static func forStudy(_ studyUID: String) -> RetrieveKeys {
        RetrieveKeys(level: .study)
            .studyInstanceUID(studyUID)
    }
    
    /// Creates retrieve keys for a series-level retrieval
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID to retrieve
    /// - Returns: Configured retrieve keys
    public static func forSeries(studyUID: String, seriesUID: String) -> RetrieveKeys {
        RetrieveKeys(level: .series)
            .studyInstanceUID(studyUID)
            .seriesInstanceUID(seriesUID)
    }
    
    /// Creates retrieve keys for an instance-level retrieval
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID to retrieve
    /// - Returns: Configured retrieve keys
    public static func forInstance(studyUID: String, seriesUID: String, instanceUID: String) -> RetrieveKeys {
        RetrieveKeys(level: .image)
            .studyInstanceUID(studyUID)
            .seriesInstanceUID(seriesUID)
            .sopInstanceUID(instanceUID)
    }
}

#if canImport(Network)

// MARK: - DICOM Retrieve Service

/// DICOM Retrieve Service (C-MOVE and C-GET SCU)
///
/// Implements the DICOM Query/Retrieve Service Class for retrieving studies, series,
/// and instances from a remote DICOM SCP (Service Class Provider).
///
/// ## C-MOVE vs C-GET
///
/// - **C-MOVE**: Requests the SCP to send images to a specified destination AE.
///   Requires a separate Storage SCP to receive the images.
/// - **C-GET**: Requests images to be sent back on the same association.
///   Simpler to use but requires the SCU to be able to receive C-STORE sub-operations.
///
/// Reference: PS3.4 Section C - Query/Retrieve Service Class
/// Reference: PS3.7 Section 9.1.3 - C-GET Service
/// Reference: PS3.7 Section 9.1.4 - C-MOVE Service
///
/// ## Usage - C-MOVE
///
/// ```swift
/// // Retrieve a study to a destination AE
/// let result = try await DICOMRetrieveService.moveStudy(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS",
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9",
///     moveDestination: "MY_SCP"
/// )
/// print("Completed: \(result.progress.completed)")
/// print("Failed: \(result.progress.failed)")
/// ```
///
/// ## Usage - C-GET
///
/// ```swift
/// // Download a study directly (C-GET)
/// let stream = try await DICOMRetrieveService.getStudy(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS",
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9"
/// )
///
/// for await event in stream {
///     switch event {
///     case .progress(let progress):
///         print("Progress: \(progress.completed)/\(progress.total)")
///     case .instance(let sopInstanceUID, let data):
///         print("Received instance: \(sopInstanceUID)")
///         // Process the DICOM data
///     case .completed(let result):
///         print("Completed: \(result)")
///     }
/// }
/// ```
public enum DICOMRetrieveService {
    
    // MARK: - C-MOVE Operations
    
    /// Moves a study to a destination AE using C-MOVE
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID to retrieve
    ///   - moveDestination: The destination AE title to receive the images
    ///   - onProgress: Optional callback for progress updates
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: The result of the C-MOVE operation
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func moveStudy(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        moveDestination: String,
        onProgress: (@Sendable (RetrieveProgress) -> Void)? = nil,
        timeout: TimeInterval = 60
    ) async throws -> RetrieveResult {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = RetrieveConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let keys = RetrieveKeys.forStudy(studyInstanceUID)
        
        return try await performMove(
            host: host,
            port: port,
            configuration: config,
            keys: keys,
            moveDestination: moveDestination,
            onProgress: onProgress
        )
    }
    
    /// Moves a series to a destination AE using C-MOVE
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID to retrieve
    ///   - moveDestination: The destination AE title to receive the images
    ///   - onProgress: Optional callback for progress updates
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: The result of the C-MOVE operation
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func moveSeries(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        moveDestination: String,
        onProgress: (@Sendable (RetrieveProgress) -> Void)? = nil,
        timeout: TimeInterval = 60
    ) async throws -> RetrieveResult {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = RetrieveConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let keys = RetrieveKeys.forSeries(studyUID: studyInstanceUID, seriesUID: seriesInstanceUID)
        
        return try await performMove(
            host: host,
            port: port,
            configuration: config,
            keys: keys,
            moveDestination: moveDestination,
            onProgress: onProgress
        )
    }
    
    /// Moves an instance to a destination AE using C-MOVE
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID to retrieve
    ///   - moveDestination: The destination AE title to receive the image
    ///   - onProgress: Optional callback for progress updates
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: The result of the C-MOVE operation
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func moveInstance(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        moveDestination: String,
        onProgress: (@Sendable (RetrieveProgress) -> Void)? = nil,
        timeout: TimeInterval = 60
    ) async throws -> RetrieveResult {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = RetrieveConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let keys = RetrieveKeys.forInstance(
            studyUID: studyInstanceUID,
            seriesUID: seriesInstanceUID,
            instanceUID: sopInstanceUID
        )
        
        return try await performMove(
            host: host,
            port: port,
            configuration: config,
            keys: keys,
            moveDestination: moveDestination,
            onProgress: onProgress
        )
    }
    
    // MARK: - C-GET Operations
    
    /// Event types emitted during a C-GET retrieve operation
    public enum GetEvent: Sendable {
        /// Progress update with current sub-operation counts
        case progress(RetrieveProgress)
        
        /// A DICOM instance has been received
        case instance(sopInstanceUID: String, sopClassUID: String, data: Data)
        
        /// The operation has completed
        case completed(RetrieveResult)
        
        /// An error occurred
        case error(DICOMNetworkError)
    }
    
    /// Downloads a study using C-GET
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID to retrieve
    ///   - storageSopClasses: Storage SOP Classes to accept (default: common SOP classes)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: An async stream of get events
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func getStudy(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        storageSopClasses: [String]? = nil,
        timeout: TimeInterval = 60
    ) async throws -> AsyncStream<GetEvent> {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = RetrieveConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let keys = RetrieveKeys.forStudy(studyInstanceUID)
        
        return performGet(
            host: host,
            port: port,
            configuration: config,
            keys: keys,
            storageSopClasses: storageSopClasses ?? commonStorageSOPClassUIDs
        )
    }
    
    /// Downloads a series using C-GET
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID to retrieve
    ///   - storageSopClasses: Storage SOP Classes to accept (default: common SOP classes)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: An async stream of get events
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func getSeries(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        storageSopClasses: [String]? = nil,
        timeout: TimeInterval = 60
    ) async throws -> AsyncStream<GetEvent> {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = RetrieveConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let keys = RetrieveKeys.forSeries(studyUID: studyInstanceUID, seriesUID: seriesInstanceUID)
        
        return performGet(
            host: host,
            port: port,
            configuration: config,
            keys: keys,
            storageSopClasses: storageSopClasses ?? commonStorageSOPClassUIDs
        )
    }
    
    /// Downloads an instance using C-GET
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID to retrieve
    ///   - storageSopClasses: Storage SOP Classes to accept (default: common SOP classes)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: An async stream of get events
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func getInstance(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        storageSopClasses: [String]? = nil,
        timeout: TimeInterval = 60
    ) async throws -> AsyncStream<GetEvent> {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = RetrieveConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let keys = RetrieveKeys.forInstance(
            studyUID: studyInstanceUID,
            seriesUID: seriesInstanceUID,
            instanceUID: sopInstanceUID
        )
        
        return performGet(
            host: host,
            port: port,
            configuration: config,
            keys: keys,
            storageSopClasses: storageSopClasses ?? commonStorageSOPClassUIDs
        )
    }
    
    // MARK: - Private Implementation - C-MOVE
    
    /// Performs the C-MOVE operation
    private static func performMove(
        host: String,
        port: UInt16,
        configuration: RetrieveConfiguration,
        keys: RetrieveKeys,
        moveDestination: String,
        onProgress: (@Sendable (RetrieveProgress) -> Void)?
    ) async throws -> RetrieveResult {
        
        // Validate that the level is supported by the information model
        guard configuration.informationModel.supportsLevel(keys.level) else {
            throw DICOMNetworkError.invalidState(
                "Retrieve level \(keys.level) is not supported by \(configuration.informationModel)"
            )
        }
        
        // Create association configuration
        let associationConfig = AssociationConfiguration(
            callingAETitle: configuration.callingAETitle,
            calledAETitle: configuration.calledAETitle,
            host: host,
            port: port,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName,
            timeout: configuration.timeout,
            userIdentity: configuration.userIdentity
        )
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        // Create presentation context for C-MOVE
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: configuration.informationModel.moveSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify that the SOP Class was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(configuration.informationModel.moveSOPClassUID)
            }
            
            // Get the accepted transfer syntax
            let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1) 
                ?? implicitVRLittleEndianTransferSyntaxUID
            
            // Perform the C-MOVE
            let result = try await performCMove(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize,
                keys: keys,
                moveDestination: moveDestination,
                transferSyntax: acceptedTransferSyntax,
                sopClassUID: configuration.informationModel.moveSOPClassUID,
                onProgress: onProgress
            )
            
            // Release association gracefully
            try await association.release()
            
            return result
            
        } catch {
            // Attempt to abort the association on error
            try? await association.abort()
            throw error
        }
    }
    
    /// Performs the C-MOVE request/response exchange
    private static func performCMove(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32,
        keys: RetrieveKeys,
        moveDestination: String,
        transferSyntax: String,
        sopClassUID: String,
        onProgress: (@Sendable (RetrieveProgress) -> Void)?
    ) async throws -> RetrieveResult {
        // Build the retrieve identifier data set
        let identifierData = buildRetrieveIdentifier(keys: keys, transferSyntax: transferSyntax)
        
        // Create C-MOVE request
        let request = CMoveRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            moveDestination: moveDestination,
            priority: .medium,
            presentationContextID: presentationContextID
        )
        
        // Fragment and send the command and data set
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: identifierData,
            presentationContextID: presentationContextID
        )
        
        // Send all PDUs
        for pdu in pdus {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        
        // Receive responses
        let assembler = MessageAssembler()
        
        while true {
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                guard let moveResponse = message.asCMoveResponse() else {
                    throw DICOMNetworkError.decodingFailed(
                        "Expected C-MOVE-RSP, got \(message.command?.description ?? "unknown")"
                    )
                }
                
                // Update progress
                let progress = RetrieveProgress(from: moveResponse)
                onProgress?(progress)
                
                // Check the status
                let status = moveResponse.status
                
                if status.isPending {
                    // Pending - continue receiving responses
                    continue
                } else if status.isSuccess {
                    // Success - operation complete
                    return RetrieveResult(status: status, progress: progress)
                } else if status.isCancel {
                    // Cancelled
                    return RetrieveResult(status: status, progress: progress)
                } else if status.isFailure {
                    // Failure
                    throw DICOMNetworkError.retrieveFailed(status)
                } else {
                    // Unknown status - treat as completion
                    return RetrieveResult(status: status, progress: progress)
                }
            }
        }
    }
    
    // MARK: - Private Implementation - C-GET
    
    /// Performs the C-GET operation
    private static func performGet(
        host: String,
        port: UInt16,
        configuration: RetrieveConfiguration,
        keys: RetrieveKeys,
        storageSopClasses: [String]
    ) -> AsyncStream<GetEvent> {
        AsyncStream { continuation in
            Task {
                do {
                    // Validate that the level is supported by the information model
                    guard configuration.informationModel.supportsLevel(keys.level) else {
                        continuation.yield(.error(DICOMNetworkError.invalidState(
                            "Retrieve level \(keys.level) is not supported by \(configuration.informationModel)"
                        )))
                        continuation.finish()
                        return
                    }
                    
                    // Create association configuration
                    let associationConfig = AssociationConfiguration(
                        callingAETitle: configuration.callingAETitle,
                        calledAETitle: configuration.calledAETitle,
                        host: host,
                        port: port,
                        maxPDUSize: configuration.maxPDUSize,
                        implementationClassUID: configuration.implementationClassUID,
                        implementationVersionName: configuration.implementationVersionName,
                        timeout: configuration.timeout,
                        userIdentity: configuration.userIdentity
                    )
                    
                    // Create association
                    let association = Association(configuration: associationConfig)
                    
                    // Build presentation contexts:
                    // 1. C-GET SOP Class
                    // 2. Storage SOP Classes for receiving C-STORE sub-operations
                    var presentationContexts: [PresentationContext] = []
                    var contextID: UInt8 = 1
                    
                    // C-GET presentation context
                    let getContext = try PresentationContext(
                        id: contextID,
                        abstractSyntax: configuration.informationModel.getSOPClassUID,
                        transferSyntaxes: [
                            explicitVRLittleEndianTransferSyntaxUID,
                            implicitVRLittleEndianTransferSyntaxUID
                        ]
                    )
                    presentationContexts.append(getContext)
                    contextID += 2
                    
                    // Storage SOP Class presentation contexts
                    for sopClassUID in storageSopClasses {
                        if contextID > 255 { break }
                        let storageContext = try PresentationContext(
                            id: contextID,
                            abstractSyntax: sopClassUID,
                            transferSyntaxes: [
                                explicitVRLittleEndianTransferSyntaxUID,
                                implicitVRLittleEndianTransferSyntaxUID
                            ]
                        )
                        presentationContexts.append(storageContext)
                        contextID += 2
                    }
                    
                    // Establish association
                    let negotiated = try await association.request(presentationContexts: presentationContexts)
                    
                    // Verify that the C-GET SOP Class was accepted
                    guard negotiated.isContextAccepted(1) else {
                        try await association.abort()
                        continuation.yield(.error(DICOMNetworkError.sopClassNotSupported(
                            configuration.informationModel.getSOPClassUID
                        )))
                        continuation.finish()
                        return
                    }
                    
                    // Get the accepted transfer syntax
                    let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1) 
                        ?? implicitVRLittleEndianTransferSyntaxUID
                    
                    // Perform the C-GET
                    try await performCGet(
                        association: association,
                        presentationContextID: 1,
                        maxPDUSize: negotiated.maxPDUSize,
                        keys: keys,
                        transferSyntax: acceptedTransferSyntax,
                        sopClassUID: configuration.informationModel.getSOPClassUID,
                        negotiated: negotiated,
                        continuation: continuation
                    )
                    
                    // Release association gracefully
                    try await association.release()
                    
                } catch let error as DICOMNetworkError {
                    continuation.yield(.error(error))
                    continuation.finish()
                } catch {
                    continuation.yield(.error(DICOMNetworkError.connectionFailed(error.localizedDescription)))
                    continuation.finish()
                }
            }
        }
    }
    
    /// Performs the C-GET request/response exchange
    private static func performCGet(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32,
        keys: RetrieveKeys,
        transferSyntax: String,
        sopClassUID: String,
        negotiated: NegotiatedAssociation,
        continuation: AsyncStream<GetEvent>.Continuation
    ) async throws {
        // Build the retrieve identifier data set
        let identifierData = buildRetrieveIdentifier(keys: keys, transferSyntax: transferSyntax)
        
        // Create C-GET request
        let request = CGetRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            priority: .medium,
            presentationContextID: presentationContextID
        )
        
        // Fragment and send the command and data set
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: identifierData,
            presentationContextID: presentationContextID
        )
        
        // Send all PDUs
        for pdu in pdus {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        
        // Receive responses and C-STORE sub-operations
        let assembler = MessageAssembler()
        
        while true {
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                // Check what type of message we received
                switch message.command {
                case .cGetResponse:
                    guard let getResponse = message.asCGetResponse() else {
                        throw DICOMNetworkError.decodingFailed("Failed to parse C-GET-RSP")
                    }
                    
                    // Update progress
                    let progress = RetrieveProgress(from: getResponse)
                    continuation.yield(.progress(progress))
                    
                    // Check the status
                    let status = getResponse.status
                    
                    if status.isPending {
                        // Pending - continue receiving
                        continue
                    } else {
                        // Complete (success, failure, or cancel)
                        let result = RetrieveResult(status: status, progress: progress)
                        continuation.yield(.completed(result))
                        continuation.finish()
                        return
                    }
                    
                case .cStoreRequest:
                    // Incoming C-STORE sub-operation
                    guard let storeRequest = message.asCStoreRequest() else {
                        throw DICOMNetworkError.decodingFailed("Failed to parse C-STORE-RQ")
                    }
                    
                    let sopInstanceUID = storeRequest.affectedSOPInstanceUID
                    let sopClassUID = storeRequest.affectedSOPClassUID
                    
                    // Yield the instance data
                    if let dataSetData = message.dataSet {
                        continuation.yield(.instance(
                            sopInstanceUID: sopInstanceUID,
                            sopClassUID: sopClassUID,
                            data: dataSetData
                        ))
                    }
                    
                    // Send C-STORE response
                    let storeResponse = CStoreResponse(
                        messageIDBeingRespondedTo: storeRequest.messageID,
                        affectedSOPClassUID: sopClassUID,
                        affectedSOPInstanceUID: sopInstanceUID,
                        status: .success,
                        presentationContextID: message.presentationContextID
                    )
                    
                    let responsePDUs = fragmenter.fragmentMessage(
                        commandSet: storeResponse.commandSet,
                        dataSet: nil,
                        presentationContextID: message.presentationContextID
                    )
                    
                    for pdu in responsePDUs {
                        for pdv in pdu.presentationDataValues {
                            try await association.send(pdv: pdv)
                        }
                    }
                    
                default:
                    throw DICOMNetworkError.decodingFailed(
                        "Unexpected command during C-GET: \(message.command?.description ?? "unknown")"
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Builds the retrieve identifier data set
    private static func buildRetrieveIdentifier(keys: RetrieveKeys, transferSyntax: String) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID
        
        // Add Query/Retrieve Level
        data.append(encodeElement(
            tag: .queryRetrieveLevel,
            vr: .CS,
            value: keys.level.queryRetrieveLevel,
            explicit: isExplicitVR
        ))
        
        // Add all retrieve keys, sorted by tag
        let sortedKeys = keys.keys.sorted { $0.tag < $1.tag }
        for key in sortedKeys {
            data.append(encodeElement(
                tag: key.tag,
                vr: key.vr,
                value: key.value,
                explicit: isExplicitVR
            ))
        }
        
        return data
    }
    
    /// Encodes a single data element
    private static func encodeElement(tag: Tag, vr: VR, value: String, explicit: Bool) -> Data {
        var data = Data()
        
        // Tag (4 bytes, little endian)
        var group = tag.group.littleEndian
        var element = tag.element.littleEndian
        data.append(Data(bytes: &group, count: 2))
        data.append(Data(bytes: &element, count: 2))
        
        // Prepare value data with padding
        var valueData = value.data(using: .ascii) ?? Data()
        
        // Pad to even length per DICOM rules
        if valueData.count % 2 != 0 {
            // Use space padding for text VRs, null for UI
            let paddingChar: UInt8 = (vr == .UI) ? 0x00 : (vr.isStringVR ? 0x20 : 0x00)
            valueData.append(paddingChar)
        }
        
        if explicit {
            // Explicit VR encoding
            // VR (2 bytes)
            if let vrBytes = vr.rawValue.data(using: .ascii) {
                data.append(vrBytes)
            } else {
                data.append(Data([0x55, 0x4E])) // "UN" fallback
            }
            
            // Check if VR uses 4-byte length
            if vr.uses4ByteLength {
                // Reserved (2 bytes)
                data.append(Data([0x00, 0x00]))
                // Value Length (4 bytes)
                var length = UInt32(valueData.count).littleEndian
                data.append(Data(bytes: &length, count: 4))
            } else {
                // Value Length (2 bytes)
                var length = UInt16(valueData.count).littleEndian
                data.append(Data(bytes: &length, count: 2))
            }
        } else {
            // Implicit VR encoding
            // Value Length (4 bytes)
            var length = UInt32(valueData.count).littleEndian
            data.append(Data(bytes: &length, count: 4))
        }
        
        // Value
        data.append(valueData)
        
        return data
    }
}

#endif

// MARK: - Common Storage SOP Class UIDs

/// Common Storage SOP Class UIDs for C-GET operations
///
/// These are the most commonly used storage SOP classes that a C-GET SCU
/// should be prepared to accept as sub-operations.
public let commonStorageSOPClassUIDs: [String] = [
    // CT Image Storage
    "1.2.840.10008.5.1.4.1.1.2",
    // Enhanced CT Image Storage
    "1.2.840.10008.5.1.4.1.1.2.1",
    // MR Image Storage
    "1.2.840.10008.5.1.4.1.1.4",
    // Enhanced MR Image Storage
    "1.2.840.10008.5.1.4.1.1.4.1",
    // Ultrasound Image Storage
    "1.2.840.10008.5.1.4.1.1.6.1",
    // Secondary Capture Image Storage
    "1.2.840.10008.5.1.4.1.1.7",
    // Digital X-Ray Image Storage - For Presentation
    "1.2.840.10008.5.1.4.1.1.1.1",
    // Digital X-Ray Image Storage - For Processing
    "1.2.840.10008.5.1.4.1.1.1.1.1",
    // Computed Radiography Image Storage
    "1.2.840.10008.5.1.4.1.1.1",
    // Digital Mammography X-Ray Image Storage - For Presentation
    "1.2.840.10008.5.1.4.1.1.1.2",
    // Digital Mammography X-Ray Image Storage - For Processing
    "1.2.840.10008.5.1.4.1.1.1.2.1",
    // Nuclear Medicine Image Storage
    "1.2.840.10008.5.1.4.1.1.20",
    // PET Image Storage
    "1.2.840.10008.5.1.4.1.1.128",
    // RT Image Storage
    "1.2.840.10008.5.1.4.1.1.481.1",
    // RT Structure Set Storage
    "1.2.840.10008.5.1.4.1.1.481.3",
    // RT Plan Storage
    "1.2.840.10008.5.1.4.1.1.481.5",
    // RT Dose Storage
    "1.2.840.10008.5.1.4.1.1.481.2"
]
