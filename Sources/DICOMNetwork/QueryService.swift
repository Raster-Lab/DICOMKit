import Foundation
import DICOMCore

/// Configuration for the DICOM Query Service
public struct QueryConfiguration: Sendable, Hashable {
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

#if canImport(Network)
    /// Complete TLS transport policy, or `nil` for plain TCP
    public let tlsConfiguration: TLSConfiguration?
#endif
    
    /// User identity for authentication (optional)
    ///
    /// Reference: PS3.7 Section D.3.3.7 - User Identity Negotiation
    public let userIdentity: UserIdentity?

    /// Specific Character Set (0008,0005) to declare in the C-FIND Identifier.
    ///
    /// `nil` (the default) lets the service pick the narrowest repertoire that
    /// represents every text-VR key value (none for pure ISO 646, "ISO_IR 100"
    /// for Latin-1, "ISO_IR 192" otherwise). A non-nil value forces that defined
    /// term and encodes all text keys with it.
    ///
    /// Reference: PS3.4 C.4.1.1.3.1, PS3.5 6.1.2
    public let specificCharacterSet: String?
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates a query configuration
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
        self.init(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout,
            maxPDUSize: maxPDUSize,
            implementationClassUID: implementationClassUID,
            implementationVersionName: implementationVersionName,
            informationModel: informationModel,
            userIdentity: userIdentity,
            specificCharacterSet: nil
        )
    }

    /// Creates a query configuration with a forced Specific Character Set.
    ///
    /// - Parameters:
    ///   - specificCharacterSet: The (0008,0005) defined term to declare in the
    ///     C-FIND Identifier and encode text keys with, or nil for automatic
    ///     selection (PS3.4 C.4.1.1.3.1).
    ///
    /// Other parameters are as in the primary initializer.
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        informationModel: QueryRetrieveInformationModel = .studyRoot,
        userIdentity: UserIdentity? = nil,
        specificCharacterSet: String?
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.informationModel = informationModel
#if canImport(Network)
        self.tlsConfiguration = nil
#endif
        self.userIdentity = userIdentity
        self.specificCharacterSet = specificCharacterSet
    }

#if canImport(Network)
    /// Creates a query configuration with an exact TLS transport policy.
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        informationModel: QueryRetrieveInformationModel = .studyRoot,
        tlsConfiguration: TLSConfiguration?,
        userIdentity: UserIdentity? = nil
    ) {
        self.init(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout,
            maxPDUSize: maxPDUSize,
            implementationClassUID: implementationClassUID,
            implementationVersionName: implementationVersionName,
            informationModel: informationModel,
            tlsConfiguration: tlsConfiguration,
            userIdentity: userIdentity,
            specificCharacterSet: nil
        )
    }

    /// Creates a query configuration with an exact TLS transport policy and a
    /// forced Specific Character Set (see the non-TLS variant).
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        informationModel: QueryRetrieveInformationModel = .studyRoot,
        tlsConfiguration: TLSConfiguration?,
        userIdentity: UserIdentity? = nil,
        specificCharacterSet: String?
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.informationModel = informationModel
        self.tlsConfiguration = tlsConfiguration
        self.userIdentity = userIdentity
        self.specificCharacterSet = specificCharacterSet
    }

    /// Builds the exact association configuration used by query operations.
    func associationConfiguration(host: String, port: UInt16) -> AssociationConfiguration {
        AssociationConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            host: host,
            port: port,
            maxPDUSize: maxPDUSize,
            implementationClassUID: implementationClassUID,
            implementationVersionName: implementationVersionName,
            timeout: timeout,
            tlsConfiguration: tlsConfiguration,
            userIdentity: userIdentity
        )
    }
#endif
}

#if canImport(Network)

// MARK: - DICOM Query Service

/// DICOM Query Service (C-FIND SCU)
///
/// Implements the DICOM Query/Retrieve Service Class for finding studies, series,
/// and instances on a remote DICOM SCP (Service Class Provider).
///
/// Reference: PS3.4 Section C - Query/Retrieve Service Class
/// Reference: PS3.7 Section 9.1.2 - C-FIND Service
///
/// ## Usage
///
/// ```swift
/// // Simple study query
/// let studies = try await DICOMQueryService.findStudies(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS",
///     matching: QueryKeys(level: .study)
///         .patientName("DOE^JOHN*")
///         .studyDate("20240101-20241231")
/// )
///
/// // Query for series in a study
/// let series = try await DICOMQueryService.findSeries(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS",
///     forStudy: "1.2.3.4.5.6.7.8.9",
///     matching: QueryKeys(level: .series)
///         .modality("CT")
/// )
/// ```
public enum DICOMQueryService {
    
    // MARK: - Study Queries
    
    /// Finds studies matching the specified query keys
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - matching: Query keys specifying match criteria and return attributes
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: Array of study results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func findStudies(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        matching: QueryKeys? = nil,
        timeout: TimeInterval = 60
    ) async throws -> [StudyResult] {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = QueryConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let queryKeys = matching ?? QueryKeys.defaultStudyKeys()
        let results = try await performFind(
            host: host,
            port: port,
            configuration: config,
            level: .study,
            queryKeys: queryKeys
        )
        
        return results.map { $0.toStudyResult() }
    }
    
    // MARK: - Series Queries
    
    /// Finds series matching the specified query keys
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - forStudy: The Study Instance UID to query within
    ///   - matching: Additional query keys (optional)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: Array of series results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func findSeries(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        forStudy studyInstanceUID: String,
        matching: QueryKeys? = nil,
        timeout: TimeInterval = 60
    ) async throws -> [SeriesResult] {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = QueryConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        var queryKeys = matching ?? QueryKeys.defaultSeriesKeys()
        // Add the study instance UID constraint
        queryKeys = queryKeys.studyInstanceUID(studyInstanceUID)
        
        let results = try await performFind(
            host: host,
            port: port,
            configuration: config,
            level: .series,
            queryKeys: queryKeys
        )
        
        return results.map { $0.toSeriesResult() }
    }
    
    // MARK: - Instance Queries
    
    /// Finds instances matching the specified query keys
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - forStudy: The Study Instance UID
    ///   - forSeries: The Series Instance UID
    ///   - matching: Additional query keys (optional)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: Array of instance results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func findInstances(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        forStudy studyInstanceUID: String,
        forSeries seriesInstanceUID: String,
        matching: QueryKeys? = nil,
        timeout: TimeInterval = 60
    ) async throws -> [InstanceResult] {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = QueryConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        var queryKeys = matching ?? QueryKeys.defaultInstanceKeys()
        // Add the study and series instance UID constraints
        queryKeys = queryKeys
            .studyInstanceUID(studyInstanceUID)
            .seriesInstanceUID(seriesInstanceUID)
        
        let results = try await performFind(
            host: host,
            port: port,
            configuration: config,
            level: .image,
            queryKeys: queryKeys
        )
        
        return results.map { $0.toInstanceResult() }
    }
    
    // MARK: - Full-Configuration Queries

    /// Finds studies using an explicit query configuration.
    public static func findStudies(
        host: String,
        port: UInt16 = dicomDefaultPort,
        configuration: QueryConfiguration,
        matching: QueryKeys? = nil
    ) async throws -> [StudyResult] {
        let results = try await performFind(
            host: host,
            port: port,
            configuration: configuration,
            level: .study,
            queryKeys: matching ?? QueryKeys.defaultStudyKeys()
        )
        return results.map { $0.toStudyResult() }
    }

    /// Finds series using an explicit query configuration.
    public static func findSeries(
        host: String,
        port: UInt16 = dicomDefaultPort,
        configuration: QueryConfiguration,
        forStudy studyInstanceUID: String,
        matching: QueryKeys? = nil
    ) async throws -> [SeriesResult] {
        var queryKeys = matching ?? QueryKeys.defaultSeriesKeys()
        queryKeys = queryKeys.studyInstanceUID(studyInstanceUID)
        let results = try await performFind(
            host: host,
            port: port,
            configuration: configuration,
            level: .series,
            queryKeys: queryKeys
        )
        return results.map { $0.toSeriesResult() }
    }

    /// Finds instances using an explicit query configuration.
    public static func findInstances(
        host: String,
        port: UInt16 = dicomDefaultPort,
        configuration: QueryConfiguration,
        forStudy studyInstanceUID: String,
        forSeries seriesInstanceUID: String,
        matching: QueryKeys? = nil
    ) async throws -> [InstanceResult] {
        var queryKeys = matching ?? QueryKeys.defaultInstanceKeys()
        queryKeys = queryKeys
            .studyInstanceUID(studyInstanceUID)
            .seriesInstanceUID(seriesInstanceUID)
        let results = try await performFind(
            host: host,
            port: port,
            configuration: configuration,
            level: .image,
            queryKeys: queryKeys
        )
        return results.map { $0.toInstanceResult() }
    }

    // MARK: - Generic Query
    
    /// Performs a generic C-FIND query
    ///
    /// Use this method for custom queries at any level.
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number
    ///   - configuration: The query configuration
    ///   - queryKeys: The query keys
    /// - Returns: Array of generic query results
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func find(
        host: String,
        port: UInt16 = dicomDefaultPort,
        configuration: QueryConfiguration,
        queryKeys: QueryKeys
    ) async throws -> [GenericQueryResult] {
        try await performFind(
            host: host,
            port: port,
            configuration: configuration,
            level: queryKeys.level,
            queryKeys: queryKeys
        )
    }

    // MARK: - Shared query-key builder

    /// Builds the C-FIND `QueryKeys` for a direct query at `level` from user-supplied
    /// filter values. This is the SINGLE source of truth shared by the dicom-query
    /// CLI, DICOMStudio's in-app query, and the CLI-parity reference, so their
    /// input→C-FIND mapping cannot drift.
    ///
    /// Each non-empty value becomes a MATCHING key; absent ones become RETURN keys.
    /// Matching follows PS3.4: at STUDY level `modality` matches **ModalitiesInStudy**
    /// (0008,0061); at SERIES level it matches **Modality** (0008,0060). (A previous
    /// dicom-query bug used Modality at study level, which the PACS ignores — so the
    /// modality filter silently returned every study.)
    ///
    /// Return keys are the union needed by all callers; superfluous ones are harmless.
    ///
    /// Hierarchical identifier content (PS3.4 C.4.1.2.1, C.4.1.3.2.1): a SERIES or
    /// IMAGE level Identifier carries only the Unique Keys of the levels above plus
    /// attributes of its own level. Patient/Study attributes (Patient Name/ID,
    /// Study Date/Description, Accession) are therefore NOT emitted at those levels
    /// by default: an SCP may reject them or, worse, silently ignore them. Passing
    /// `includeParentLevelReturnKeys: true` re-adds them as zero-length return
    /// keys for lenient SCPs such as dcm4chee that populate parent-level
    /// attributes in child-level responses. This is a non-baseline extension and
    /// is never used for matching.
    public static func buildQueryKeys(
        level: QueryLevel,
        patientName: String = "",
        patientID: String = "",
        studyDate: String = "",
        modality: String = "",
        accession: String = "",
        studyDescription: String = "",
        referringPhysician: String = "",
        studyUID: String = "",
        seriesUID: String = "",
        seriesDate: String = "",
        instanceUID: String = "",
        includeParentLevelReturnKeys: Bool = false
    ) -> QueryKeys {
        var keys = QueryKeys(level: level)
        switch level {
        case .patient:
            keys = patientID.isEmpty ? keys.requestPatientID() : keys.patientID(patientID)
            keys = patientName.isEmpty ? keys.requestPatientName() : keys.patientName(patientName)
            keys = keys.requestPatientBirthDate().requestPatientSex()
                .requestNumberOfPatientRelatedStudies()
                .requestNumberOfPatientRelatedSeries()
                .requestNumberOfPatientRelatedInstances()

        case .study:
            keys = patientID.isEmpty ? keys.requestPatientID() : keys.patientID(patientID)
            keys = patientName.isEmpty ? keys.requestPatientName() : keys.patientName(patientName)
            keys = keys.requestPatientBirthDate()
            keys = studyUID.isEmpty ? keys.requestStudyInstanceUID() : keys.studyInstanceUID(studyUID)
            keys = studyDate.isEmpty ? keys.requestStudyDate() : keys.studyDate(studyDate)
            // Study-level modality → ModalitiesInStudy (0008,0061).
            keys = modality.isEmpty ? keys.requestModalitiesInStudy() : keys.modalitiesInStudy(modality)
            keys = accession.isEmpty ? keys.requestAccessionNumber() : keys.accessionNumber(accession)
            keys = studyDescription.isEmpty ? keys.requestStudyDescription() : keys.studyDescription(studyDescription)
            // Referring physician (0008,0090) is a study-level attribute: a non-empty
            // value becomes a matching key, otherwise it stays a return key.
            keys = referringPhysician.isEmpty ? keys.requestReferringPhysicianName()
                                              : keys.referringPhysicianName(referringPhysician)
            keys = keys.requestStudyTime().requestStudyID()
                .requestNumberOfStudyRelatedSeries().requestNumberOfStudyRelatedInstances()

        case .series:
            keys = studyUID.isEmpty ? keys.requestStudyInstanceUID() : keys.studyInstanceUID(studyUID)
            keys = seriesUID.isEmpty ? keys.requestSeriesInstanceUID() : keys.seriesInstanceUID(seriesUID)
            // Series-level modality → Modality (0008,0060).
            keys = modality.isEmpty ? keys.requestModality() : keys.modality(modality)
            if !seriesDate.isEmpty { keys = keys.seriesDate(seriesDate) }
            keys = keys.requestSeriesNumber().requestSeriesDescription()
                .requestNumberOfSeriesRelatedInstances()
            if includeParentLevelReturnKeys {
                // Non-baseline: parent-level return keys (dcm4chee5 style).
                keys = keys.requestPatientName().requestPatientID().requestStudyDate()
                    .requestStudyDescription().requestAccessionNumber()
            }

        case .image:
            keys = studyUID.isEmpty ? keys.requestStudyInstanceUID() : keys.studyInstanceUID(studyUID)
            keys = seriesUID.isEmpty ? keys.requestSeriesInstanceUID() : keys.seriesInstanceUID(seriesUID)
            keys = instanceUID.isEmpty ? keys.requestSOPInstanceUID() : keys.sopInstanceUID(instanceUID)
            keys = keys.requestSOPClassUID().requestInstanceNumber().requestContentDate()
                .requestRows().requestColumns().requestNumberOfFrames()
            if includeParentLevelReturnKeys {
                // Non-baseline: parent-level return keys.
                keys = keys.requestPatientName().requestPatientID().requestStudyDate()
                    .requestStudyDescription().requestAccessionNumber()
                    .requestModality().requestSeriesNumber().requestSeriesDescription()
            }
        }
        return keys
    }

    /// Patient/Study filter values that a caller supplied for a SERIES or IMAGE
    /// level query. Under the hierarchical model (PS3.4 C.4.1.2.1) these attributes
    /// belong to levels above the Query/Retrieve level and cannot be matched
    /// there, so `buildQueryKeys` does not emit them. CLIs use this to warn the
    /// user rather than dropping the filters silently.
    ///
    /// - Returns: The human-readable names of the ignored filters, or an empty
    ///   array when nothing is ignored (including at PATIENT/STUDY level).
    public static func ignoredParentLevelFilters(
        level: QueryLevel,
        patientName: String = "",
        patientID: String = "",
        studyDate: String = "",
        accession: String = "",
        studyDescription: String = "",
        referringPhysician: String = ""
    ) -> [String] {
        guard level == .series || level == .image else { return [] }
        var ignored: [String] = []
        if !patientName.isEmpty { ignored.append("Patient Name") }
        if !patientID.isEmpty { ignored.append("Patient ID") }
        if !studyDate.isEmpty { ignored.append("Study Date") }
        if !accession.isEmpty { ignored.append("Accession Number") }
        if !studyDescription.isEmpty { ignored.append("Study Description") }
        if !referringPhysician.isEmpty { ignored.append("Referring Physician") }
        return ignored
    }

    // MARK: - Private Implementation
    
    /// Performs the C-FIND operation
    private static func performFind(
        host: String,
        port: UInt16,
        configuration: QueryConfiguration,
        level: QueryLevel,
        queryKeys: QueryKeys
    ) async throws -> [GenericQueryResult] {
        
        // Validate that the level is supported by the information model
        guard configuration.informationModel.supportsLevel(level) else {
            throw DICOMNetworkError.invalidState(
                "Query level \(level) is not supported by \(configuration.informationModel)"
            )
        }

        // PS3.4 C.4.1.2.1 (baseline hierarchical search): the Identifier shall
        // contain a single value in the Unique Key of every level above the
        // Query/Retrieve level. Relational queries lift this, but DICOMKit does not
        // negotiate them, so fail here with a readable message instead of letting
        // the SCP answer 0xA900.
        if let missing = missingHigherLevelUniqueKey(level: level, queryKeys: queryKeys,
                                                     informationModel: configuration.informationModel) {
            throw DICOMNetworkError.invalidState(missing)
        }
        
        // Create association configuration
        let associationConfig = configuration.associationConfiguration(host: host, port: port)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        // Create presentation context for C-FIND
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: configuration.informationModel.findSOPClassUID,
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
                throw DICOMNetworkError.sopClassNotSupported(configuration.informationModel.findSOPClassUID)
            }
            
            // Get the accepted transfer syntax
            let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1) 
                ?? implicitVRLittleEndianTransferSyntaxUID
            
            // Perform the C-FIND query
            let results = try await performCFind(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize,
                level: level,
                queryKeys: queryKeys,
                transferSyntax: acceptedTransferSyntax,
                sopClassUID: configuration.informationModel.findSOPClassUID,
                specificCharacterSet: configuration.specificCharacterSet
            )
            
            // Release association gracefully
            try await association.release()
            
            return results
            
        } catch {
            // Attempt to abort the association on error
            try? await association.abort()
            throw error
        }
    }
    
    /// Performs the C-FIND request/response exchange
    private static func performCFind(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32,
        level: QueryLevel,
        queryKeys: QueryKeys,
        transferSyntax: String,
        sopClassUID: String,
        specificCharacterSet: String? = nil
    ) async throws -> [GenericQueryResult] {
        // Build the query identifier data set
        let identifierData = buildQueryIdentifier(
            level: level,
            queryKeys: queryKeys,
            transferSyntax: transferSyntax,
            specificCharacterSet: specificCharacterSet
        )
        
        // Create C-FIND request using the correct SOP Class UID from the information model
        let request = CFindRequest(
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
        
        // Receive responses
        var results: [GenericQueryResult] = []
        let assembler = MessageAssembler()
        
        while true {
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                guard let findResponse = message.asCFindResponse() else {
                    throw DICOMNetworkError.decodingFailed(
                        "Expected C-FIND-RSP, got \(message.command?.description ?? "unknown")"
                    )
                }
                
                // Check the status
                let status = findResponse.status
                
                if status.isPending {
                    // Pending - parse the data set and add to results
                    if let dataSetData = message.dataSet {
                        let attributes = parseQueryResponse(data: dataSetData, transferSyntax: transferSyntax)
                        results.append(GenericQueryResult(attributes: attributes, level: level))
                    }
                } else if status.isSuccess {
                    // Success - query complete
                    break
                } else if status.isCancel {
                    // Cancelled - return what we have
                    break
                } else if status.isFailure {
                    // Failure
                    throw DICOMNetworkError.queryFailed(status)
                } else {
                    // Unknown status - treat as completion
                    break
                }
            }
        }
        
        return results
    }
    
    /// The PS3.4 C.4.1.2.1 rule: Unique Keys of all levels above `level` must be
    /// present with a single value (no wildcard, no UID list). Returns a message
    /// naming the first missing key, or nil when the identifier is well-formed.
    internal static func missingHigherLevelUniqueKey(
        level: QueryLevel,
        queryKeys: QueryKeys,
        informationModel: QueryRetrieveInformationModel
    ) -> String? {
        func singleValue(_ tag: Tag) -> Bool {
            guard let key = queryKeys.keys.first(where: { $0.tag == tag }) else { return false }
            let v = key.value.trimmingCharacters(in: .whitespaces)
            return !v.isEmpty && !v.contains("*") && !v.contains("?") && !v.contains("\\")
        }
        var required: [(Tag, String)] = []
        if informationModel == .patientRoot, level != .patient {
            required.append((.patientID, "Patient ID (0010,0020)"))
        }
        if level == .series || level == .image {
            required.append((.studyInstanceUID, "Study Instance UID (0020,000D)"))
        }
        if level == .image {
            required.append((.seriesInstanceUID, "Series Instance UID (0020,000E)"))
        }
        for (tag, name) in required where !singleValue(tag) {
            return "A \(level.rawValue)-level query must carry a single value for \(name) "
                + "(PS3.4 C.4.1.2.1: the Unique Key of every level above the query level is required)"
        }
        return nil
    }

    /// Value Representations whose values are text in the declared character
    /// repertoire (PS3.5 6.1.2). Every other string VR (UI, CS, DA, TM, DT, IS,
    /// DS, AE, AS) is restricted to the default repertoire by definition.
    static let textVRs: Set<VR> = [.PN, .LO, .SH, .ST, .LT, .UT, .UC]

    /// Builds the query identifier data set
    ///
    /// Chooses a character set over all text-VR key values (or uses the forced
    /// `specificCharacterSet` / a caller-supplied (0008,0005) key) and, when the
    /// default repertoire does not suffice, inserts (0008,0005) into the
    /// Identifier as PS3.4 C.4.1.1.3.1 requires. Text values are encoded with the
    /// chosen set so a non-ASCII key never degrades to a zero-length (universal
    /// match) element.
    static func buildQueryIdentifier(
        level: QueryLevel,
        queryKeys: QueryKeys,
        transferSyntax: String,
        specificCharacterSet: String? = nil
    ) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID

        // A caller-supplied (0008,0005) matching key wins over the configuration
        // override; both win over automatic selection.
        var keys = queryKeys.keys
        let callerCharacterSetKey = keys.first { $0.tag == .specificCharacterSet }
        let callerValue = callerCharacterSetKey?.value.trimmingCharacters(in: .whitespaces)
        let override = (callerValue?.isEmpty == false) ? callerValue : specificCharacterSet

        let textValues = keys.filter { textVRs.contains($0.vr) }.map { $0.value }
        let characterSet = DIMSECharacterSet.choose(for: textValues, override: override)

        if let chosen = characterSet.specificCharacterSet {
            keys.removeAll { $0.tag == .specificCharacterSet }
            keys.append(QueryKey(tag: .specificCharacterSet, value: chosen, vr: .CS))
        } else if callerCharacterSetKey != nil, callerValue?.isEmpty ?? true {
            // A (0008,0005) return key is meaningless in a C-FIND request; drop it.
            keys.removeAll { $0.tag == .specificCharacterSet }
        }
        
        // Merge Query/Retrieve Level into the key set and sort everything
        // by ascending tag order per DICOM PS3.5 Section 7.1.
        let levelKey = QueryKey(tag: .queryRetrieveLevel, value: level.queryRetrieveLevel, vr: .CS)
        let allKeys = (keys + [levelKey]).sorted { $0.tag < $1.tag }
        for key in allKeys {
            data.append(encodeElement(
                tag: key.tag,
                vr: key.vr,
                value: key.value,
                explicit: isExplicitVR,
                characterSet: characterSet
            ))
        }
        
        return data
    }
    
    /// Encodes a single data element for the query identifier
    ///
    /// Text VRs are encoded with `characterSet`; the default-repertoire VRs are
    /// encoded as ISO 646. In neither case is a non-empty value allowed to become
    /// a zero-length element: if the bytes cannot be produced, UTF-8 is used.
    static func encodeElement(
        tag: Tag,
        vr: VR,
        value: String,
        explicit: Bool,
        characterSet: DIMSECharacterSet = DIMSECharacterSet(specificCharacterSet: nil)
    ) -> Data {
        var data = Data()
        
        // Tag (4 bytes, little endian)
        var group = tag.group.littleEndian
        var element = tag.element.littleEndian
        data.append(Data(bytes: &group, count: 2))
        data.append(Data(bytes: &element, count: 2))
        
        // Prepare value data with padding
        var valueData: Data
        if textVRs.contains(vr) {
            valueData = characterSet.encode(value)
        } else {
            valueData = value.data(using: .ascii) ?? Data(value.utf8)
        }
        
        // Pad to even length per DICOM rules
        if valueData.count % 2 != 0 {
            // UI VR uses null (0x00) padding per PS3.5 §6.2; other string VRs use space
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
    
    /// Parses a response data set (C-FIND Identifier, or the final C-MOVE/C-GET
    /// response Identifier) into top-level attributes. Shared with
    /// `DICOMRetrieveService`.
    static func parseQueryResponse(data: Data, transferSyntax: String) -> [Tag: Data] {
        var attributes: [Tag: Data] = [:]
        var offset = 0
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID
        
        while offset + 4 <= data.count {
            // Read tag
            let group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            let tag = Tag(group: group, element: element)
            offset += 4
            
            // Check for sequence delimiter or item tags
            if group == 0xFFFE {
                // Skip sequence/item delimiters
                if offset + 4 <= data.count {
                    offset += 4 // Skip length
                }
                continue
            }
            
            var valueLength: UInt32 = 0
            
            if isExplicitVR {
                // Read VR (2 bytes)
                guard offset + 2 <= data.count else { break }
                let vrBytes = Data(data[offset..<(offset + 2)])
                let vrString = String(data: vrBytes, encoding: .ascii) ?? "UN"
                let vr = VR(rawValue: vrString) ?? .UN
                offset += 2
                
                // Read length based on VR
                if vr.uses4ByteLength {
                    // Skip reserved 2 bytes, read 4-byte length
                    guard offset + 6 <= data.count else { break }
                    offset += 2
                    valueLength = UInt32(data[offset]) |
                                  (UInt32(data[offset + 1]) << 8) |
                                  (UInt32(data[offset + 2]) << 16) |
                                  (UInt32(data[offset + 3]) << 24)
                    offset += 4
                } else {
                    // Read 2-byte length
                    guard offset + 2 <= data.count else { break }
                    valueLength = UInt32(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                    offset += 2
                }
            } else {
                // Implicit VR - 4-byte length
                guard offset + 4 <= data.count else { break }
                valueLength = UInt32(data[offset]) |
                              (UInt32(data[offset + 1]) << 8) |
                              (UInt32(data[offset + 2]) << 16) |
                              (UInt32(data[offset + 3]) << 24)
                offset += 4
            }
            
            // Handle undefined length
            if valueLength == 0xFFFFFFFF {
                // Skip sequences with undefined length for now
                continue
            }
            
            // Read value
            guard offset + Int(valueLength) <= data.count else { break }
            let value = data.subdata(in: offset..<(offset + Int(valueLength)))
            offset += Int(valueLength)
            
            attributes[tag] = value
        }
        
        return attributes
    }
}

#endif

// MARK: - VR Extension

extension VR {
    /// Whether this VR is a string type that uses space padding
    var isStringVR: Bool {
        switch self {
        case .AE, .AS, .CS, .DA, .DS, .DT, .IS, .LO, .LT, .PN, .SH, .ST, .TM, .UC, .UI, .UR, .UT:
            return true
        default:
            return false
        }
    }
    
    /// Whether this VR uses 4-byte length in Explicit VR encoding
    var uses4ByteLength: Bool {
        switch self {
        case .OB, .OD, .OF, .OL, .OW, .SQ, .UC, .UN, .UR, .UT:
            return true
        default:
            return false
        }
    }
}
