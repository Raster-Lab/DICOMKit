import Foundation
import DICOMCore

/// SOP Class UID for Modality Worklist Information Model - FIND
/// Reference: PS3.4 Annex K - Modality Worklist Information Model
public let modalityWorklistInformationModelFindSOPClassUID = "1.2.840.10008.5.1.4.31"

/// Configuration for the Modality Worklist Service
public struct ModalityWorklistConfiguration: Sendable, Hashable {
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
    
    /// User identity for authentication (optional)
    public let userIdentity: UserIdentity?
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates a worklist configuration
    ///
    /// - Parameters:
    ///   - callingAETitle: The local AE title
    ///   - calledAETitle: The remote AE title
    ///   - timeout: Connection timeout in seconds (default: 60)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - userIdentity: User identity for authentication (optional)
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        userIdentity: UserIdentity? = nil
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.userIdentity = userIdentity
    }
}

/// Modality Worklist query keys
public struct WorklistQueryKeys: Sendable {
    private var keys: [Tag: String] = [:]
    
    public init() {}
    
    // MARK: - Patient Demographics
    
    /// Patient's Name
    public func patientName(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[.patientName] = value
        return copy
    }
    
    /// Patient ID
    public func patientID(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[.patientID] = value
        return copy
    }
    
    // MARK: - Scheduled Procedure Step
    
    /// Scheduled Procedure Step Start Date (YYYYMMDD)
    public func scheduledDate(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[Tag(group: 0x0040, element: 0x0100)] = value // Scheduled Procedure Step Sequence
        return copy
    }
    
    /// Scheduled Station AE Title
    public func scheduledStationAET(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[Tag(group: 0x0040, element: 0x0001)] = value
        return copy
    }
    
    /// Modality
    public func modality(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[.modality] = value
        return copy
    }
    
    /// Returns all keys
    internal var allKeys: [Tag: String] { keys }
    
    /// Default worklist query keys (returns all attributes)
    public static func `default`() -> WorklistQueryKeys {
        var keys = WorklistQueryKeys()
        // Request common return attributes
        keys.keys[.patientName] = ""
        keys.keys[.patientID] = ""
        keys.keys[Tag(group: 0x0040, element: 0x0100)] = "" // Scheduled Procedure Step Sequence
        keys.keys[.studyInstanceUID] = ""
        keys.keys[.accessionNumber] = ""
        return keys
    }
}

/// Modality Worklist item result
public struct WorklistItem: Sendable {
    public let attributes: [Tag: Data]
    
    public init(attributes: [Tag: Data]) {
        self.attributes = attributes
    }
    
    /// Get patient name
    public var patientName: String? {
        guard let data = attributes[.patientName] else { return nil }
        return String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
    }
    
    /// Get patient ID
    public var patientID: String? {
        guard let data = attributes[.patientID] else { return nil }
        return String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
    }
    
    /// Get study instance UID
    public var studyInstanceUID: String? {
        guard let data = attributes[.studyInstanceUID] else { return nil }
        return String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
    }
    
    /// Get accession number
    public var accessionNumber: String? {
        guard let data = attributes[.accessionNumber] else { return nil }
        return String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
    }
}

#if canImport(Network)

// MARK: - DICOM Modality Worklist Service

/// DICOM Modality Worklist Service (MWL C-FIND SCU)
///
/// Implements the DICOM Modality Worklist Information Model for querying
/// scheduled procedure steps from a worklist SCP.
///
/// Reference: PS3.4 Annex K - Modality Worklist Information Model
///
/// ## Usage
///
/// ```swift
/// // Query worklist for today
/// let items = try await DICOMModalityWorklistService.find(
///     host: "worklist.hospital.com",
///     port: 11112,
///     callingAE: "MODALITY",
///     calledAE: "WORKLIST_SCP",
///     matching: WorklistQueryKeys()
///         .scheduledDate("20240315")
///         .scheduledStationAET("CT1")
/// )
/// ```
public enum DICOMModalityWorklistService {
    
    /// Finds worklist items matching the specified query keys
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - matching: Query keys specifying match criteria (optional)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: Array of worklist items
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func find(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        matching: WorklistQueryKeys? = nil,
        timeout: TimeInterval = 60
    ) async throws -> [WorklistItem] {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = ModalityWorklistConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let queryKeys = matching ?? WorklistQueryKeys.default()
        
        return try await performFind(
            host: host,
            port: port,
            configuration: config,
            queryKeys: queryKeys
        )
    }
    
    // MARK: - Private Implementation
    
    /// Performs the C-FIND operation for worklist
    private static func performFind(
        host: String,
        port: UInt16,
        configuration: ModalityWorklistConfiguration,
        queryKeys: WorklistQueryKeys
    ) async throws -> [WorklistItem] {
        
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
        
        // Create presentation context for MWL C-FIND
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: modalityWorklistInformationModelFindSOPClassUID,
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
                throw DICOMNetworkError.sopClassNotSupported(modalityWorklistInformationModelFindSOPClassUID)
            }
            
            // Get the accepted transfer syntax
            let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1) 
                ?? implicitVRLittleEndianTransferSyntaxUID
            
            // Perform the C-FIND query
            let results = try await performCFind(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize,
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
        queryKeys: WorklistQueryKeys,
        transferSyntax: String
    ) async throws -> [WorklistItem] {
        // Build the query identifier data set
        let identifierData = buildQueryIdentifier(queryKeys: queryKeys, transferSyntax: transferSyntax)
        
        // Create C-FIND request
        let request = CFindRequest(
            messageID: 1,
            affectedSOPClassUID: modalityWorklistInformationModelFindSOPClassUID,
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
        var results: [WorklistItem] = []
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
                        results.append(WorklistItem(attributes: attributes))
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
        queryKeys: WorklistQueryKeys,
        transferSyntax: String
    ) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID
        
        // Add all query keys, sorted by tag
        let sortedKeys = queryKeys.allKeys.sorted { $0.key < $1.key }
        for (tag, value) in sortedKeys {
            // Determine VR for the tag (simplified - in production use a dictionary)
            let vr: VR = determineVR(for: tag)
            
            data.append(encodeElement(
                tag: tag,
                vr: vr,
                value: value,
                explicit: isExplicitVR
            ))
        }
        
        return data
    }
    
    /// Determines the VR for a given tag
    /// 
    /// Note: This is a simplified implementation for common MWL tags.
    /// TODO: Consider using DICOMDictionary module for comprehensive VR lookup
    /// when the dictionary is available in DICOMNetwork dependencies.
    private static func determineVR(for tag: Tag) -> VR {
        switch tag {
        case .patientName: return .PN
        case .patientID: return .LO
        case .studyInstanceUID: return .UI
        case .accessionNumber: return .SH
        case .modality: return .CS
        default:
            // Common defaults for worklist tags
            if tag.group == 0x0040 {
                return .SQ // Most 0x0040 tags in MWL are sequences or strings
            }
            return .LO
        }
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
        
        // Pad to even length per DICOM rules (PS3.5 Section 6.2)
        // DICOM requires all Value Fields to have even length
        if valueData.count % 2 != 0 {
            // Use space (0x20) padding for text VRs, null (0x00) for binary VRs
            // This is a DICOM-specific requirement to maintain alignment
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
