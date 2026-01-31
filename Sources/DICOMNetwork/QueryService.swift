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
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        informationModel: QueryRetrieveInformationModel = .studyRoot
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.informationModel = informationModel
    }
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
        
        // Create association configuration
        let associationConfig = AssociationConfiguration(
            callingAETitle: configuration.callingAETitle,
            calledAETitle: configuration.calledAETitle,
            host: host,
            port: port,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName,
            timeout: configuration.timeout
        )
        
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
                transferSyntax: acceptedTransferSyntax
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
        transferSyntax: String
    ) async throws -> [GenericQueryResult] {
        // Build the query identifier data set
        let identifierData = buildQueryIdentifier(level: level, queryKeys: queryKeys, transferSyntax: transferSyntax)
        
        // Create C-FIND request
        let request = CFindRequest(
            messageID: 1,
            affectedSOPClassUID: association.configuration.calledAETitle.value.isEmpty 
                ? studyRootQueryRetrieveFindSOPClassUID 
                : studyRootQueryRetrieveFindSOPClassUID,
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
    
    /// Builds the query identifier data set
    private static func buildQueryIdentifier(
        level: QueryLevel,
        queryKeys: QueryKeys,
        transferSyntax: String
    ) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID
        
        // Add Query/Retrieve Level
        data.append(encodeElement(
            tag: .queryRetrieveLevel,
            vr: .CS,
            value: level.queryRetrieveLevel,
            explicit: isExplicitVR
        ))
        
        // Add all query keys, sorted by tag
        let sortedKeys = queryKeys.keys.sorted { $0.tag < $1.tag }
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
    
    /// Encodes a single data element for the query identifier
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
            // Use space padding for text VRs, null for others
            let paddingChar: UInt8 = vr.isStringVR ? 0x20 : 0x00
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
    
    /// Parses the query response data set into attributes
    private static func parseQueryResponse(data: Data, transferSyntax: String) -> [Tag: Data] {
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
