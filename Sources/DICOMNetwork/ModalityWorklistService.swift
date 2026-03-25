import Foundation
import DICOMCore
import DICOMDictionary

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
///
/// Top-level patient / study attributes are encoded directly in the query
/// identifier.  Attributes that belong to the Scheduled Procedure Step (SPS)
/// are encoded inside a `(0040,0100)` Sequence item per DICOM PS3.4 Table K.6-1.
public struct WorklistQueryKeys: Sendable {
    /// Top-level query attributes (patient, study level).
    private var keys: [Tag: String] = [:]
    /// Attributes that go inside the `(0040,0100)` SPS Sequence item.
    private var spsKeys: [Tag: String] = [:]

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

    /// Accession Number (SH) — top-level matching key.
    public func accessionNumber(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[.accessionNumber] = value
        return copy
    }

    // MARK: - Scheduled Procedure Step (SPS) attributes (inside (0040,0100) sequence)

    /// Scheduled Procedure Step Start Date (DA) — encoded inside the SPS sequence.
    /// - Parameter value: Date in YYYYMMDD format, or a DICOM date range such as
    ///   "20240101-20240131".  Pass "" to request all dates.
    public func scheduledDate(_ value: String) -> WorklistQueryKeys {
        var copy = self
        // (0040,0002) Scheduled Procedure Step Start Date — inside (0040,0100) SPS Sequence
        copy.spsKeys[Tag(group: 0x0040, element: 0x0002)] = value
        return copy
    }

    /// Scheduled Station AE Title (AE) — encoded inside the SPS sequence.
    public func scheduledStationAET(_ value: String) -> WorklistQueryKeys {
        var copy = self
        // (0040,0001) Scheduled Station AE Title — inside (0040,0100) SPS Sequence
        copy.spsKeys[Tag(group: 0x0040, element: 0x0001)] = value
        return copy
    }

    /// Modality (CS) — encoded inside the SPS sequence per PS3.4 Table K.6-1.
    public func modality(_ value: String) -> WorklistQueryKeys {
        var copy = self
        // (0008,0060) Modality — inside (0040,0100) SPS Sequence
        copy.spsKeys[Tag(group: 0x0008, element: 0x0060)] = value
        return copy
    }

    // MARK: - SPS status filter

    /// Scheduled Procedure Step Status (CS) — encoded inside the SPS sequence.
    /// Common values: "SCHEDULED", "IN PROGRESS", "DISCONTINUED", "COMPLETED".
    /// Pass "" to request items regardless of status.
    public func scheduledProcedureStepStatus(_ value: String) -> WorklistQueryKeys {
        var copy = self
        // (0040,0020) Scheduled Procedure Step Status — inside (0040,0100) SPS Sequence
        copy.spsKeys[Tag(group: 0x0040, element: 0x0020)] = value
        return copy
    }

    /// Returns top-level query attributes.
    internal var allKeys: [Tag: String] { keys }
    /// Returns SPS-level attributes that go inside `(0040,0100)` sequence item.
    internal var allSPSKeys: [Tag: String] { spsKeys }

    /// Specific Character Set (CS) — declares the character set used in the query
    /// identifier so the SCP can properly encode response strings.
    /// Common values: "ISO_IR 100" (Latin-1), "ISO_IR 192" (UTF-8).
    /// Reference: PS3.3 C.12.1.1.2
    public func specificCharacterSet(_ value: String) -> WorklistQueryKeys {
        var copy = self
        copy.keys[.specificCharacterSet] = value
        return copy
    }

    /// Default worklist query keys requesting all common return attributes.
    public static func `default`() -> WorklistQueryKeys {
        var wlk = WorklistQueryKeys()
        // Specific Character Set — required by many RIS/PACS servers to avoid
        // null-tag errors.  Default to ISO_IR 100 (Latin-1) which is the most
        // widely supported single-byte character set per PS3.3 C.12.1.1.2.
        wlk.keys[.specificCharacterSet]                   = "ISO_IR 100"
        // Top-level return attributes
        wlk.keys[.patientName]                            = ""
        wlk.keys[.patientID]                             = ""
        wlk.keys[.studyInstanceUID]                      = ""
        wlk.keys[.accessionNumber]                       = ""
        wlk.keys[Tag(group: 0x0010, element: 0x0030)]    = ""  // Patient's Birth Date
        wlk.keys[Tag(group: 0x0010, element: 0x0040)]    = ""  // Patient's Sex
        wlk.keys[Tag(group: 0x0008, element: 0x0090)]    = ""  // Referring Physician's Name
        wlk.keys[Tag(group: 0x0040, element: 0x1001)]    = ""  // Requested Procedure ID
        wlk.keys[Tag(group: 0x0032, element: 0x1070)]    = ""  // Requested Procedure Description
        // SPS return attributes (encoded inside (0040,0100) sequence)
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0001)] = ""  // Scheduled Station AE Title
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0002)] = ""  // Scheduled Procedure Step Start Date
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0003)] = ""  // Scheduled Procedure Step Start Time
        wlk.spsKeys[Tag(group: 0x0008, element: 0x0060)] = ""  // Modality
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0009)] = ""  // Scheduled Procedure Step ID
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0007)] = ""  // Scheduled Procedure Step Description
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0020)] = ""  // Scheduled Procedure Step Status (CS)
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0006)] = ""  // Scheduled Performing Physician's Name
        wlk.spsKeys[Tag(group: 0x0040, element: 0x0010)] = ""  // Scheduled Station Name
        return wlk
    }
}

/// Modality Worklist item result.
///
/// Attributes from the top-level dataset and from the nested SPS sequence
/// `(0040,0100)` are stored in the same flat dictionary — their tag numbers
/// never collide, so direct lookup works without a second container.
public struct WorklistItem: Sendable {
    public let attributes: [Tag: Data]

    public init(attributes: [Tag: Data]) {
        self.attributes = attributes
    }

    // MARK: - Private helper

    private func stringValue(group: UInt16, element: UInt16) -> String? {
        let tag = Tag(group: group, element: element)
        guard let data = attributes[tag] else { return nil }
        let s = String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
        return s.flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Patient Demographics

    /// Patient's Name (0010,0010)
    public var patientName: String? { stringValue(group: 0x0010, element: 0x0010) }

    /// Patient ID (0010,0020)
    public var patientID: String? { stringValue(group: 0x0010, element: 0x0020) }

    /// Patient's Birth Date (0010,0030) in YYYYMMDD format.
    public var patientBirthDate: String? { stringValue(group: 0x0010, element: 0x0030) }

    /// Patient's Sex (0010,0040) — "M", "F", or "O".
    public var patientSex: String? { stringValue(group: 0x0010, element: 0x0040) }

    // MARK: - Study Level

    /// Study Instance UID (0020,000D)
    public var studyInstanceUID: String? { stringValue(group: 0x0020, element: 0x000D) }

    /// Accession Number (0008,0050)
    public var accessionNumber: String? { stringValue(group: 0x0008, element: 0x0050) }

    /// Referring Physician's Name (0008,0090)
    public var referringPhysicianName: String? { stringValue(group: 0x0008, element: 0x0090) }

    /// Requested Procedure ID (0040,1001)
    public var requestedProcedureID: String? { stringValue(group: 0x0040, element: 0x1001) }

    /// Requested Procedure Description (0032,1070)
    public var requestedProcedureDescription: String? { stringValue(group: 0x0032, element: 0x1070) }

    // MARK: - Scheduled Procedure Step (SPS) attributes — from (0040,0100) sequence

    /// Scheduled Station AE Title (0040,0001)
    public var scheduledStationAETitle: String? { stringValue(group: 0x0040, element: 0x0001) }

    /// Scheduled Procedure Step Start Date (0040,0002) in YYYYMMDD format.
    public var scheduledProcedureStepStartDate: String? { stringValue(group: 0x0040, element: 0x0002) }

    /// Scheduled Procedure Step Start Time (0040,0003) in HHMMSS.FFFFFF format.
    public var scheduledProcedureStepStartTime: String? { stringValue(group: 0x0040, element: 0x0003) }

    /// Scheduled Procedure Step Status (0040,0020) — e.g. "SCHEDULED", "IN PROGRESS", "COMPLETED".
    public var scheduledProcedureStepStatus: String? { stringValue(group: 0x0040, element: 0x0020) }

    /// Scheduled Performing Physician's Name (0040,0006)
    public var scheduledPerformingPhysicianName: String? { stringValue(group: 0x0040, element: 0x0006) }

    /// Scheduled Procedure Step Description (0040,0007)
    public var scheduledProcedureStepDescription: String? { stringValue(group: 0x0040, element: 0x0007) }

    /// Scheduled Procedure Step ID (0040,0009)
    public var scheduledProcedureStepID: String? { stringValue(group: 0x0040, element: 0x0009) }

    /// Scheduled Station Name (0040,0010)
    public var scheduledStationName: String? { stringValue(group: 0x0040, element: 0x0010) }

    /// Modality (0008,0060) — e.g. "CT", "MR", "US".
    public var modality: String? { stringValue(group: 0x0008, element: 0x0060) }
}

#if canImport(Network)
import Network

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

        // Determine which tags go at the top level and which go in the SPS sequence.
        // The SPS sequence tag (0040,0100) must appear in tag-number order relative to
        // the surrounding top-level attributes.
        let topSorted   = queryKeys.allKeys.sorted   { $0.key < $1.key }
        let spsSorted   = queryKeys.allSPSKeys.sorted { $0.key < $1.key }
        let spsSeqTag   = Tag(group: 0x0040, element: 0x0100)

        // Merge: emit top-level tags before (0040,0100), then the SPS sequence, then the rest.
        for (tag, value) in topSorted where tag < spsSeqTag {
            data.append(encodeElement(tag: tag, vr: determineVR(for: tag),
                                      value: value, explicit: isExplicitVR))
        }

        // Encode the SPS Sequence (0040,0100) with one item containing all SPS attributes.
        // Each PACS (including dcm4chee2) expects the SPS attributes nested here per PS3.4 Annex K.
        if !spsSorted.isEmpty {
            data.append(encodeSPSSequence(spsKeys: spsSorted, explicit: isExplicitVR))
        }

        // Remaining top-level tags after (0040,0100)
        for (tag, value) in topSorted where tag > spsSeqTag {
            data.append(encodeElement(tag: tag, vr: determineVR(for: tag),
                                      value: value, explicit: isExplicitVR))
        }

        return data
    }

    /// Encodes the Scheduled Procedure Step Sequence (0040,0100) with a single item.
    ///
    /// Uses undefined-length encoding for both the sequence and its item, terminated
    /// by explicit delimiter tags per PS3.5 §7.5.  This is the most widely supported
    /// format across PACS vendors including dcm4chee2.
    private static func encodeSPSSequence(spsKeys: [(key: Tag, value: String)],
                                           explicit: Bool) -> Data {
        // Build the item's attribute bytes first
        var itemData = Data()
        for (tag, value) in spsKeys {
            itemData.append(encodeElement(
                tag: tag,
                vr: determineSPSVR(for: tag),
                value: value,
                explicit: explicit
            ))
        }

        var data = Data()
        // (0040,0100) Scheduled Procedure Step Sequence — SQ
        data.append(le16mwl(0x0040)); data.append(le16mwl(0x0100))
        if explicit {
            data.append(contentsOf: [0x53, 0x51])   // "SQ"
            data.append(contentsOf: [0x00, 0x00])   // reserved
        }
        data.append(le32mwl(0xFFFFFFFF))             // undefined sequence length

        // Item (FFFE,E000) with undefined length
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0])  // item tag LE
        data.append(le32mwl(0xFFFFFFFF))
        data.append(itemData)
        // Item delimiter (FFFE,E00D)
        data.append(contentsOf: [0xFE, 0xFF, 0x0D, 0xE0])
        data.append(le32mwl(0x00000000))

        // Sequence delimiter (FFFE,E0DD)
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0])
        data.append(le32mwl(0x00000000))

        return data
    }

    // MARK: - MWL little-endian helpers (file-private to avoid name collision)

    private static func le16mwl(_ v: UInt16) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)])
    }
    private static func le32mwl(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
              UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
    }

    /// Determines the VR for a top-level MWL query tag.
    private static func determineVR(for tag: Tag) -> VR {
        // First, try to look up the tag in the DICOM Dictionary
        if let entry = DataElementDictionary.lookup(tag: tag) {
            return entry.vr.first ?? .UN
        }
        // Fallback for common MWL tags not yet in dictionary
        switch tag {
        case .patientName:     return .PN
        case .patientID:       return .LO
        case .studyInstanceUID: return .UI
        case .accessionNumber: return .SH
        default:               return .LO
        }
    }

    /// Determines the VR for an attribute inside the SPS Sequence item.
    private static func determineSPSVR(for tag: Tag) -> VR {
        if let entry = DataElementDictionary.lookup(tag: tag) {
            return entry.vr.first ?? .UN
        }
        switch (tag.group, tag.element) {
        case (0x0008, 0x0060): return .CS  // Modality
        case (0x0040, 0x0001): return .AE  // Scheduled Station AE Title
        case (0x0040, 0x0002): return .DA  // Scheduled Procedure Step Start Date
        case (0x0040, 0x0003): return .TM  // Scheduled Procedure Step Start Time
        case (0x0040, 0x0006): return .PN  // Scheduled Performing Physician Name
        case (0x0040, 0x0007): return .LO  // Scheduled Procedure Step Description
        case (0x0040, 0x0009): return .SH  // Scheduled Procedure Step ID
        case (0x0040, 0x0010): return .SH  // Scheduled Station Name
        case (0x0040, 0x0020): return .CS  // Scheduled Procedure Step Status
        default:               return .LO
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
    
    /// Parses the query response dataset — including nested SPS sequence items — into a flat
    /// attribute map.  SPS-level attributes (from the `(0040,0100)` sequence) are merged directly
    /// into the result because their tag numbers do not collide with top-level MWL attributes.
    private static func parseQueryResponse(data: Data, transferSyntax: String) -> [Tag: Data] {
        var attributes: [Tag: Data] = [:]
        var offset = 0
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID
        parseMWLDataSet(data: data, offset: &offset, end: data.count,
                        isExplicitVR: isExplicitVR, into: &attributes)
        return attributes
    }

    /// Recursively parses DICOM tags from `data[offset..<end]`, merging every encountered
    /// attribute (including items within SPS sequences) into `out`.
    /// Returns early when a delimiter tag `(FFFE,E00D)` or `(FFFE,E0DD)` is encountered.
    private static func parseMWLDataSet(
        data: Data,
        offset: inout Int,
        end: Int,
        isExplicitVR: Bool,
        into out: inout [Tag: Data]
    ) {
        while offset + 4 <= end {
            let group   = UInt16(data[offset])     | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            let tag = Tag(group: group, element: element)
            offset += 4

            // Delimiter tags (sequence/item): 4-byte length field (always 0x00000000).
            if group == 0xFFFE {
                if offset + 4 <= data.count { offset += 4 }
                if element == 0xE00D || element == 0xE0DD { return }  // bubble up
                continue
            }

            var valueLength: UInt32
            var isSequence = false

            if isExplicitVR {
                guard offset + 2 <= data.count else { return }
                let vr = VR(rawValue: String(bytes: [data[offset], data[offset + 1]],
                                             encoding: .ascii) ?? "UN") ?? .UN
                isSequence = (vr == .SQ)
                offset += 2
                if vr.uses4ByteLength {
                    guard offset + 6 <= data.count else { return }
                    offset += 2  // skip reserved 2 bytes
                    valueLength = UInt32(data[offset])     | (UInt32(data[offset + 1]) << 8)
                                | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
                    offset += 4
                } else {
                    guard offset + 2 <= data.count else { return }
                    valueLength = UInt32(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
                    offset += 2
                }
            } else {
                guard offset + 4 <= data.count else { return }
                valueLength = UInt32(data[offset])     | (UInt32(data[offset + 1]) << 8)
                            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
                offset += 4
                // In implicit VR, (0040,0100) is the MWL Scheduled Procedure Step Sequence
                isSequence = (group == 0x0040 && element == 0x0100)
            }

            if valueLength == 0xFFFFFFFF {
                if isSequence {
                    // Undefined-length SQ: parse items until (FFFE,E0DD) sequence delimiter
                    parseMWLSequenceItems(data: data, offset: &offset,
                                         isExplicitVR: isExplicitVR, into: &out)
                } else {
                    // Non-sequence undefined-length item: scan forward to next delimiter pair
                    skipMWLUndefinedItem(data: data, offset: &offset)
                }
            } else if isSequence {
                // Defined-length SQ: items are bounded by valueLength bytes
                let seqEnd = min(offset + Int(valueLength), data.count)
                parseMWLSequenceItems(data: data, offset: &offset,
                                      isExplicitVR: isExplicitVR, into: &out,
                                      boundedEnd: seqEnd)
                offset = seqEnd
            } else {
                guard offset + Int(valueLength) <= data.count else { return }
                out[tag] = data.subdata(in: offset ..< (offset + Int(valueLength)))
                offset += Int(valueLength)
            }
        }
    }

    /// Parses items within a sequence, recursing into each item's dataset and merging tags into `out`.
    /// Stops at `(FFFE,E0DD)` (sequence delimiter) or when `boundedEnd` is reached.
    private static func parseMWLSequenceItems(
        data: Data,
        offset: inout Int,
        isExplicitVR: Bool,
        into out: inout [Tag: Data],
        boundedEnd: Int? = nil
    ) {
        let limit = boundedEnd ?? data.count
        while offset + 8 <= limit {
            let group      = UInt16(data[offset])     | (UInt16(data[offset + 1]) << 8)
            let element    = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            let itemLength = UInt32(data[offset + 4]) | (UInt32(data[offset + 5]) << 8)
                           | (UInt32(data[offset + 6]) << 16) | (UInt32(data[offset + 7]) << 24)
            offset += 8

            guard group == 0xFFFE else { continue }
            if element == 0xE0DD { return }                            // sequence delimiter
            guard element == 0xE000 else { continue }                  // item tag
            if itemLength == 0xFFFFFFFF {
                // Undefined-length item — parse until (FFFE,E00D)
                parseMWLDataSet(data: data, offset: &offset, end: data.count,
                                isExplicitVR: isExplicitVR, into: &out)
            } else {
                let itemEnd = min(offset + Int(itemLength), data.count)
                parseMWLDataSet(data: data, offset: &offset, end: itemEnd,
                                isExplicitVR: isExplicitVR, into: &out)
                offset = itemEnd
            }
        }
    }

    /// Scans forward over an undefined-length non-sequence item to safely skip it.
    private static func skipMWLUndefinedItem(data: Data, offset: inout Int) {
        while offset + 8 <= data.count {
            let group   = UInt16(data[offset])     | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            offset += 8  // consume tag (4) + length (4)
            if group == 0xFFFE && (element == 0xE00D || element == 0xE0DD) { return }
        }
    }

    // MARK: - Create Worklist Item (REST API)

    /// Creates a new worklist item on a remote Worklist server via REST API.
    ///
    /// The DICOM standard (PS3.4 Annex K) defines the Modality Worklist
    /// Information Model as C-FIND only; N-CREATE is not supported for the
    /// MWL FIND SOP Class.  Modern PACS (dcm4chee-arc, Orthanc, etc.)
    /// expose REST endpoints for MWL item management instead.
    ///
    /// This method builds a DICOM JSON payload (PS3.18 Annex F) and POSTs
    /// it to the server's MWL management REST endpoint.
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104) — used only when no `restBaseURL` is given
    ///   - callingAE: The local AE title (informational for REST)
    ///   - calledAE: The remote AE title — used to construct the REST path when no explicit URL is given
    ///   - patientName: Patient's Name (0010,0010)
    ///   - patientID: Patient ID (0010,0020)
    ///   - patientBirthDate: Patient's Birth Date in YYYYMMDD (0010,0030)
    ///   - patientSex: Patient's Sex — M, F, O (0010,0040)
    ///   - accessionNumber: Accession Number (0008,0050)
    ///   - referringPhysicianName: Referring Physician's Name (0008,0090)
    ///   - requestedProcedureID: Requested Procedure ID (0040,1001)
    ///   - requestedProcedureDescription: Requested Procedure Description (0032,1070)
    ///   - studyInstanceUID: Study Instance UID (0020,000D) — auto-generated if nil
    ///   - modality: Modality, e.g. "CT", "MR" (0008,0060)
    ///   - scheduledStationAETitle: Scheduled Station AE Title (0040,0001)
    ///   - scheduledStationName: Scheduled Station Name (0040,0010)
    ///   - scheduledStartDate: Scheduled start date in YYYYMMDD (0040,0002)
    ///   - scheduledStartTime: Scheduled start time in HHMMSS (0040,0003)
    ///   - scheduledProcedureStepID: Scheduled Procedure Step ID (0040,0009)
    ///   - scheduledProcedureStepDescription: SPS Description (0040,0007)
    ///   - scheduledPerformingPhysicianName: Scheduled Performing Physician (0040,0006)
    ///   - restBaseURL: Full REST base URL, e.g. `http://host:8080/dcm4chee-arc`.
    ///     When nil, defaults to `http://{host}:8080/dcm4chee-arc`.
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: The SOP Instance UID of the created worklist item
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    ///
    /// Reference: PS3.4 Annex K — Modality Worklist Information Model
    public static func create(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        patientName: String,
        patientID: String,
        patientBirthDate: String? = nil,
        patientSex: String? = nil,
        accessionNumber: String? = nil,
        referringPhysicianName: String? = nil,
        requestedProcedureID: String? = nil,
        requestedProcedureDescription: String? = nil,
        studyInstanceUID: String? = nil,
        modality: String? = nil,
        scheduledStationAETitle: String? = nil,
        scheduledStationName: String? = nil,
        scheduledStartDate: String? = nil,
        scheduledStartTime: String? = nil,
        scheduledProcedureStepID: String? = nil,
        scheduledProcedureStepDescription: String? = nil,
        scheduledPerformingPhysicianName: String? = nil,
        restBaseURL: String? = nil,
        timeout: TimeInterval = 60
    ) async throws -> String {
        let sopInstanceUID = studyInstanceUID ?? UIDGenerator.generateUID().value

        // Build REST endpoint URL
        let baseURL = restBaseURL ?? "http://\(host):8080/dcm4chee-arc"
        let endpointString = "\(baseURL)/aets/\(calledAE)/rs/mwlitems"

        guard let endpointURL = URL(string: endpointString) else {
            throw DICOMNetworkError.connectionFailed(
                "Invalid MWL REST endpoint URL: \(endpointString)")
        }

        try await performRESTCreate(
            endpointURL: endpointURL,
            sopInstanceUID: sopInstanceUID,
            patientName: patientName,
            patientID: patientID,
            patientBirthDate: patientBirthDate,
            patientSex: patientSex,
            accessionNumber: accessionNumber,
            referringPhysicianName: referringPhysicianName,
            requestedProcedureID: requestedProcedureID,
            requestedProcedureDescription: requestedProcedureDescription,
            modality: modality,
            scheduledStationAETitle: scheduledStationAETitle,
            scheduledStationName: scheduledStationName,
            scheduledStartDate: scheduledStartDate,
            scheduledStartTime: scheduledStartTime,
            scheduledProcedureStepID: scheduledProcedureStepID,
            scheduledProcedureStepDescription: scheduledProcedureStepDescription,
            scheduledPerformingPhysicianName: scheduledPerformingPhysicianName,
            timeout: timeout
        )

        return sopInstanceUID
    }

    // MARK: - REST Create Private Implementation

    /// Posts a DICOM JSON MWL item to the server's REST endpoint.
    private static func performRESTCreate(
        endpointURL: URL,
        sopInstanceUID: String,
        patientName: String,
        patientID: String,
        patientBirthDate: String?,
        patientSex: String?,
        accessionNumber: String?,
        referringPhysicianName: String?,
        requestedProcedureID: String?,
        requestedProcedureDescription: String?,
        modality: String?,
        scheduledStationAETitle: String?,
        scheduledStationName: String?,
        scheduledStartDate: String?,
        scheduledStartTime: String?,
        scheduledProcedureStepID: String?,
        scheduledProcedureStepDescription: String?,
        scheduledPerformingPhysicianName: String?,
        timeout: TimeInterval
    ) async throws {
        // Build DICOM JSON payload (PS3.18 Annex F)
        let jsonPayload = buildMWLCreateJSON(
            studyInstanceUID: sopInstanceUID,
            patientName: patientName,
            patientID: patientID,
            patientBirthDate: patientBirthDate,
            patientSex: patientSex,
            accessionNumber: accessionNumber,
            referringPhysicianName: referringPhysicianName,
            requestedProcedureID: requestedProcedureID,
            requestedProcedureDescription: requestedProcedureDescription,
            modality: modality,
            scheduledStationAETitle: scheduledStationAETitle,
            scheduledStationName: scheduledStationName,
            scheduledStartDate: scheduledStartDate,
            scheduledStartTime: scheduledStartTime,
            scheduledProcedureStepID: scheduledProcedureStepID,
            scheduledProcedureStepDescription: scheduledProcedureStepDescription,
            scheduledPerformingPhysicianName: scheduledPerformingPhysicianName
        )

        let jsonData = try JSONSerialization.data(withJSONObject: jsonPayload, options: [])

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/dicom+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dicom+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DICOMNetworkError.connectionFailed(
                "MWL REST create received non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200, 201, 202:
            return // Success
        case 401, 403:
            throw DICOMNetworkError.connectionFailed(
                "MWL REST create failed: Authentication required (HTTP \(httpResponse.statusCode)). " +
                "Configure credentials for the server's REST API.")
        case 404:
            throw DICOMNetworkError.connectionFailed(
                "MWL REST endpoint not found (HTTP 404). " +
                "Verify the REST base URL — default pattern is " +
                "http://<host>:8080/dcm4chee-arc/aets/<AET>/rs/mwlitems")
        case 409:
            throw DICOMNetworkError.connectionFailed(
                "MWL REST create conflict (HTTP 409): A worklist item with this UID may already exist.")
        default:
            throw DICOMNetworkError.connectionFailed(
                "MWL REST create failed with HTTP \(httpResponse.statusCode)")
        }
    }

    /// Builds a DICOM JSON dictionary (PS3.18 Annex F) for MWL item creation.
    private static func buildMWLCreateJSON(
        studyInstanceUID: String,
        patientName: String,
        patientID: String,
        patientBirthDate: String?,
        patientSex: String?,
        accessionNumber: String?,
        referringPhysicianName: String?,
        requestedProcedureID: String?,
        requestedProcedureDescription: String?,
        modality: String?,
        scheduledStationAETitle: String?,
        scheduledStationName: String?,
        scheduledStartDate: String?,
        scheduledStartTime: String?,
        scheduledProcedureStepID: String?,
        scheduledProcedureStepDescription: String?,
        scheduledPerformingPhysicianName: String?
    ) -> [String: Any] {
        var json: [String: Any] = [:]

        // Specific Character Set (0008,0005)
        json["00080005"] = ["vr": "CS", "Value": ["ISO_IR 100"]]

        // Accession Number (0008,0050) — Type 2
        json["00080050"] = ["vr": "SH", "Value": [accessionNumber ?? ""]]

        // Referring Physician's Name (0008,0090) — Type 2
        if let ref = referringPhysicianName, !ref.isEmpty {
            json["00080090"] = ["vr": "PN", "Value": [["Alphabetic": ref]]]
        } else {
            json["00080090"] = ["vr": "PN"]
        }

        // Patient's Name (0010,0010) — Type 1
        json["00100010"] = ["vr": "PN", "Value": [["Alphabetic": patientName]]]

        // Patient ID (0010,0020) — Type 1
        json["00100020"] = ["vr": "LO", "Value": [patientID]]

        // Patient's Birth Date (0010,0030) — Type 2
        json["00100030"] = ["vr": "DA", "Value": [patientBirthDate ?? ""]]

        // Patient's Sex (0010,0040) — Type 2
        json["00100040"] = ["vr": "CS", "Value": [patientSex ?? ""]]

        // Study Instance UID (0020,000D) — Type 1
        json["0020000D"] = ["vr": "UI", "Value": [studyInstanceUID]]

        // Requested Procedure Description (0032,1070) — Type 2
        json["00321070"] = ["vr": "LO", "Value": [requestedProcedureDescription ?? ""]]

        // --- Scheduled Procedure Step Sequence (0040,0100) ---
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let defaultDate = dateFormatter.string(from: Date())

        var spsItem: [String: Any] = [:]

        // Scheduled Station AE Title (0040,0001)
        spsItem["00400001"] = ["vr": "AE", "Value": [scheduledStationAETitle ?? ""]]

        // Scheduled Procedure Step Start Date (0040,0002) — Type 1
        spsItem["00400002"] = ["vr": "DA", "Value": [scheduledStartDate ?? defaultDate]]

        // Scheduled Procedure Step Start Time (0040,0003)
        if let time = scheduledStartTime, !time.isEmpty {
            spsItem["00400003"] = ["vr": "TM", "Value": [time]]
        }

        // Scheduled Performing Physician's Name (0040,0006) — Type 2
        if let perf = scheduledPerformingPhysicianName, !perf.isEmpty {
            spsItem["00400006"] = ["vr": "PN", "Value": [["Alphabetic": perf]]]
        } else {
            spsItem["00400006"] = ["vr": "PN"]
        }

        // Scheduled Procedure Step Description (0040,0007) — Type 2
        spsItem["00400007"] = ["vr": "LO", "Value": [scheduledProcedureStepDescription ?? ""]]

        // Modality (0008,0060) within SPS — Type 1
        spsItem["00080060"] = ["vr": "CS", "Value": [modality ?? "OT"]]

        // Scheduled Procedure Step ID (0040,0009) — Type 1
        spsItem["00400009"] = ["vr": "SH", "Value": [scheduledProcedureStepID ?? "SPS001"]]

        // Scheduled Station Name (0040,0010) — Type 2
        spsItem["00400010"] = ["vr": "SH", "Value": [scheduledStationName ?? ""]]

        // Scheduled Procedure Step Status (0040,0020) — default SCHEDULED
        spsItem["00400020"] = ["vr": "CS", "Value": ["SCHEDULED"]]

        json["00400100"] = ["vr": "SQ", "Value": [spsItem]]

        // Requested Procedure ID (0040,1001) — Type 1
        json["00401001"] = ["vr": "SH", "Value": [requestedProcedureID ?? ""]]

        return json
    }

    // MARK: - Create Worklist Item via HL7 (ORM^O01 over MLLP)

    /// Creates a new worklist item by sending an HL7 ORM^O01 order message
    /// to the server via MLLP (Minimum Lower Layer Protocol).
    ///
    /// Unlike REST-based creation, the HL7 ORM^O01 message causes the
    /// receiving system (e.g. dcm4chee-arc, Mirth Connect) to **automatically
    /// create the patient record and the worklist item** in one step.
    ///
    /// - Parameters:
    ///   - host: The HL7 server hostname or IP address
    ///   - hl7Port: The HL7 MLLP port (default: 2575)
    ///   - sendingApplication: MSH-3 Sending Application (default: "DICOMSTUDIO")
    ///   - sendingFacility: MSH-4 Sending Facility (default: "IMAGING")
    ///   - receivingApplication: MSH-5 Receiving Application (default: "DCM4CHEE")
    ///   - receivingFacility: MSH-6 Receiving Facility (default: "HOSPITAL")
    ///   - patientName: Patient's Name in HL7 format (Last^First)
    ///   - patientID: Patient ID
    ///   - patientBirthDate: Patient's Birth Date in YYYYMMDD
    ///   - patientSex: Patient's Sex — M, F, O
    ///   - accessionNumber: Accession Number
    ///   - referringPhysicianName: Referring Physician's Name (Last^First)
    ///   - requestedProcedureID: Requested Procedure ID
    ///   - requestedProcedureDescription: Requested Procedure Description
    ///   - studyInstanceUID: Study Instance UID — auto-generated if nil
    ///   - modality: Modality, e.g. "CT", "MR"
    ///   - scheduledStationAETitle: Scheduled Station AE Title
    ///   - scheduledStationName: Scheduled Station Name
    ///   - scheduledStartDate: Scheduled start date in YYYYMMDD
    ///   - scheduledStartTime: Scheduled start time in HHMMSS
    ///   - scheduledProcedureStepID: Scheduled Procedure Step ID
    ///   - scheduledProcedureStepDescription: SPS Description
    ///   - scheduledPerformingPhysicianName: Scheduled Performing Physician (Last^First)
    ///   - timeout: Connection timeout in seconds (default: 30)
    /// - Returns: The message control ID of the sent HL7 message
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func createViaHL7(
        host: String,
        hl7Port: UInt16 = 2575,
        sendingApplication: String = "DICOMSTUDIO",
        sendingFacility: String = "IMAGING",
        receivingApplication: String = "DCM4CHEE",
        receivingFacility: String = "HOSPITAL",
        patientName: String,
        patientID: String,
        patientBirthDate: String? = nil,
        patientSex: String? = nil,
        accessionNumber: String? = nil,
        referringPhysicianName: String? = nil,
        requestedProcedureID: String? = nil,
        requestedProcedureDescription: String? = nil,
        studyInstanceUID: String? = nil,
        modality: String? = nil,
        scheduledStationAETitle: String? = nil,
        scheduledStationName: String? = nil,
        scheduledStartDate: String? = nil,
        scheduledStartTime: String? = nil,
        scheduledProcedureStepID: String? = nil,
        scheduledProcedureStepDescription: String? = nil,
        scheduledPerformingPhysicianName: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> String {
        let messageControlID = generateHL7MessageControlID()
        let studyUID = studyInstanceUID ?? UIDGenerator.generateUID().value

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let resolvedDate = scheduledStartDate ?? dateFormatter.string(from: Date())

        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMddHHmmss"
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = timestampFormatter.string(from: Date())

        let resolvedTime = scheduledStartTime ?? ""
        let scheduledDateTime = resolvedTime.isEmpty ? resolvedDate : "\(resolvedDate)\(resolvedTime)"

        // Build HL7 ORM^O01 message
        let ormMessage = buildHL7ORM(
            messageControlID: messageControlID,
            timestamp: timestamp,
            sendingApplication: sendingApplication,
            sendingFacility: sendingFacility,
            receivingApplication: receivingApplication,
            receivingFacility: receivingFacility,
            patientName: patientName,
            patientID: patientID,
            patientBirthDate: patientBirthDate,
            patientSex: patientSex,
            accessionNumber: accessionNumber ?? "",
            referringPhysicianName: referringPhysicianName,
            requestedProcedureID: requestedProcedureID ?? "RP001",
            requestedProcedureDescription: requestedProcedureDescription ?? "",
            studyInstanceUID: studyUID,
            modality: modality ?? "OT",
            scheduledStationAETitle: scheduledStationAETitle ?? "",
            scheduledStationName: scheduledStationName ?? "",
            scheduledDateTime: scheduledDateTime,
            scheduledProcedureStepID: scheduledProcedureStepID ?? "SPS001",
            scheduledProcedureStepDescription: scheduledProcedureStepDescription ?? "",
            scheduledPerformingPhysicianName: scheduledPerformingPhysicianName
        )

        // Send via MLLP and receive ACK
        let ack = try await sendHL7ViaMLLP(
            message: ormMessage,
            host: host,
            port: hl7Port,
            timeout: timeout
        )

        // Parse ACK — expect MSA|AA or MSA|CA for success
        guard let ackCode = parseHL7AckCode(ack) else {
            throw DICOMNetworkError.connectionFailed(
                "HL7 response missing MSA segment or unreadable")
        }

        switch ackCode {
        case "AA", "CA":
            return messageControlID
        case "AE":
            let errorText = parseHL7AckErrorText(ack) ?? "Application error"
            throw DICOMNetworkError.connectionFailed(
                "HL7 ORM rejected (AE): \(errorText)")
        case "AR":
            let errorText = parseHL7AckErrorText(ack) ?? "Application reject"
            throw DICOMNetworkError.connectionFailed(
                "HL7 ORM rejected (AR): \(errorText)")
        default:
            throw DICOMNetworkError.connectionFailed(
                "HL7 unexpected ACK code: \(ackCode)")
        }
    }

    // MARK: - HL7 ORM^O01 Message Builder

    /// Builds an HL7 v2.5 ORM^O01 order message for MWL creation.
    ///
    /// Segments: MSH, PID, PV1, ORC, OBR, ZDS
    /// The ZDS segment carries the Study Instance UID for DICOM-aware receivers.
    private static func buildHL7ORM(
        messageControlID: String,
        timestamp: String,
        sendingApplication: String,
        sendingFacility: String,
        receivingApplication: String,
        receivingFacility: String,
        patientName: String,
        patientID: String,
        patientBirthDate: String?,
        patientSex: String?,
        accessionNumber: String,
        referringPhysicianName: String?,
        requestedProcedureID: String,
        requestedProcedureDescription: String,
        studyInstanceUID: String,
        modality: String,
        scheduledStationAETitle: String,
        scheduledStationName: String,
        scheduledDateTime: String,
        scheduledProcedureStepID: String,
        scheduledProcedureStepDescription: String,
        scheduledPerformingPhysicianName: String?
    ) -> String {
        let cr = "\r"

        // MSH — Message Header
        var msg = "MSH|^~\\&"
        msg += "|\(sendingApplication)"
        msg += "|\(sendingFacility)"
        msg += "|\(receivingApplication)"
        msg += "|\(receivingFacility)"
        msg += "|\(timestamp)"
        msg += "|"                        // Security
        msg += "|ORM^O01^ORM_O01"         // Message Type
        msg += "|\(messageControlID)"     // Message Control ID
        msg += "|P"                       // Processing ID
        msg += "|2.5"                     // Version ID
        msg += cr

        // PID — Patient Identification
        msg += "PID"
        msg += "||"                       // PID-1: Set ID (empty)
        msg += "\(patientID)"             // PID-2: Patient ID (External)
        msg += "|\(patientID)"            // PID-3: Patient Identifier List
        msg += "|"                        // PID-4: Alternate Patient ID
        msg += "|\(patientName)"          // PID-5: Patient Name (Last^First)
        msg += "|"                        // PID-6: Mother's Maiden Name
        msg += "|\(patientBirthDate ?? "")" // PID-7: Date of Birth
        msg += "|\(patientSex ?? "")"     // PID-8: Sex
        msg += cr

        // PV1 — Patient Visit
        msg += "PV1"
        msg += "||O"                      // PV1-2: Patient Class (O=Outpatient)
        msg += cr

        // ORC — Common Order
        msg += "ORC"
        msg += "|NW"                      // ORC-1: Order Control (NW = New order)
        msg += "|\(accessionNumber)"      // ORC-2: Placer Order Number
        msg += "|"                        // ORC-3: Filler Order Number
        msg += "|"                        // ORC-4: Placer Group Number
        msg += "|SC"                      // ORC-5: Order Status (SC = Scheduled)
        msg += cr

        // OBR — Observation Request
        msg += "OBR"
        msg += "|1"                       // OBR-1: Set ID
        msg += "|\(accessionNumber)"      // OBR-2: Placer Order Number
        msg += "|"                        // OBR-3: Filler Order Number
        // OBR-4: Universal Service Identifier (procedure code^description)
        msg += "|\(requestedProcedureID)^\(requestedProcedureDescription)"
        msg += "|"                        // OBR-5: Priority
        msg += "|"                        // OBR-6: Requested Date/Time
        msg += "|\(scheduledDateTime)"    // OBR-7: Observation Date/Time
        msg += "||||"                     // OBR-8..11
        msg += "|"                        // OBR-12: Danger Code
        msg += "|"                        // OBR-13: Relevant Clinical Info
        msg += "|"                        // OBR-14: Specimen Received Date/Time
        msg += "|"                        // OBR-15: Specimen Source
        msg += "|\(referringPhysicianName ?? "")" // OBR-16: Ordering Provider
        msg += "|"                        // OBR-17: Order Callback Phone Number
        msg += "|\(scheduledProcedureStepDescription)" // OBR-18: Placer Field 1 (SPS description)
        msg += "|\(scheduledProcedureStepID)"   // OBR-19: Placer Field 2 (SPS ID)
        msg += "|\(scheduledStationAETitle)"    // OBR-20: Filler Field 1 (Station AET)
        msg += "|\(scheduledStationName)"       // OBR-21: Filler Field 2 (Station Name)
        msg += "|"                        // OBR-22: Results Rpt/Status Date
        msg += "|"                        // OBR-23: Charge to Practice
        msg += "|\(modality)"             // OBR-24: Diagnostic Serv Sect ID (modality)
        msg += "|"                        // OBR-25: Result Status
        msg += "|"                        // OBR-26: Parent Result
        msg += "|^^^" + scheduledDateTime // OBR-27: Quantity/Timing (for scheduled date/time)
        if let performer = scheduledPerformingPhysicianName, !performer.isEmpty {
            // OBR-28..33 (skip to OBR-34: Technician)
            msg += "|||||||\(performer)"
        }
        msg += cr

        // ZDS — Study Instance UID (custom Z-segment, dcm4chee convention)
        msg += "ZDS"
        msg += "|\(studyInstanceUID)^100^Application^DICOM"
        msg += cr

        return msg
    }

    // MARK: - MLLP Transport

    /// Sends an HL7 message via MLLP and returns the ACK response.
    ///
    /// MLLP framing:
    ///   - Start block: 0x0B (VT)
    ///   - End block:   0x1C 0x0D (FS + CR)
    static func sendHL7ViaMLLP(
        message: String,
        host: String,
        port: UInt16,
        timeout: TimeInterval
    ) async throws -> String {
        guard let messageData = message.data(using: .utf8) else {
            throw DICOMNetworkError.connectionFailed("Failed to encode HL7 message as UTF-8")
        }

        // Frame the message in MLLP: 0x0B + message + 0x1C 0x0D
        let framedData = Data([0x0B]) + messageData + Data([0x1C, 0x0D])

        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw DICOMNetworkError.connectionFailed("Invalid HL7 port: \(port)")
        }

        let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            let resumed = MLLPContinuationGuard(continuation)

            // Timeout
            nonisolated(unsafe) let timeoutTask = DispatchWorkItem { [weak connection] in
                guard !resumed.hasResumed else { return }
                connection?.cancel()
                resumed.resume(with: .failure(
                    DICOMNetworkError.timeout))
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeout,
                execute: timeoutTask
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Connected — send the MLLP-framed message
                    connection.send(content: framedData, completion: .contentProcessed { error in
                        if let error = error {
                            timeoutTask.cancel()
                            resumed.resume(with: .failure(
                                DICOMNetworkError.connectionFailed(
                                    "HL7 MLLP send failed: \(error.localizedDescription)")))
                            connection.cancel()
                            return
                        }

                        // Receive the ACK response
                        connection.receive(minimumIncompleteLength: 1,
                                           maximumLength: 65536) { data, _, _, recvError in
                            timeoutTask.cancel()
                            defer { connection.cancel() }

                            if let recvError = recvError {
                                resumed.resume(with: .failure(
                                    DICOMNetworkError.connectionFailed(
                                        "HL7 MLLP receive failed: \(recvError.localizedDescription)")))
                                return
                            }

                            guard let data = data, !data.isEmpty else {
                                resumed.resume(with: .failure(
                                    DICOMNetworkError.connectionClosed))
                                return
                            }

                            // Strip MLLP framing from the response
                            var responseData = data
                            if responseData.first == 0x0B {
                                responseData = responseData.dropFirst()
                            }
                            if responseData.count >= 2,
                               responseData[responseData.endIndex - 2] == 0x1C,
                               responseData[responseData.endIndex - 1] == 0x0D {
                                responseData = responseData.dropLast(2)
                            }

                            guard let ackString = String(data: responseData, encoding: .utf8) else {
                                resumed.resume(with: .failure(
                                    DICOMNetworkError.connectionFailed(
                                        "HL7 ACK response not valid UTF-8")))
                                return
                            }

                            resumed.resume(with: .success(ackString))
                        }
                    })

                case .failed(let error):
                    timeoutTask.cancel()
                    resumed.resume(with: .failure(
                        DICOMNetworkError.connectionFailed(
                            "HL7 MLLP connection failed: \(error.localizedDescription)")))

                case .cancelled:
                    timeoutTask.cancel()
                    resumed.resume(with: .failure(
                        DICOMNetworkError.connectionClosed))

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    // MARK: - HL7 ACK Parsing Helpers

    /// Extracts the ACK code from an HL7 ACK/NAK message (MSA-1).
    /// Returns "AA", "AE", "AR", "CA", "CE", "CR", or nil if not found.
    static func parseHL7AckCode(_ ack: String) -> String? {
        for line in ack.split(separator: "\r") {
            let str = String(line)
            if str.hasPrefix("MSA|") || str.hasPrefix("MSA\u{7C}") {
                let fields = str.split(separator: "|", omittingEmptySubsequences: false)
                if fields.count >= 2 {
                    return String(fields[1])
                }
            }
        }
        return nil
    }

    /// Extracts the error text from an HL7 ACK message (MSA-3 or ERR segment).
    static func parseHL7AckErrorText(_ ack: String) -> String? {
        for line in ack.split(separator: "\r") {
            let str = String(line)
            if str.hasPrefix("MSA|") {
                let fields = str.split(separator: "|", omittingEmptySubsequences: false)
                if fields.count >= 4 {
                    let text = String(fields[3])
                    if !text.isEmpty { return text }
                }
            }
            if str.hasPrefix("ERR|") {
                let fields = str.split(separator: "|", omittingEmptySubsequences: false)
                if fields.count >= 2 {
                    return String(fields[1])
                }
            }
        }
        return nil
    }

    /// Generates a unique HL7 message control ID.
    static func generateHL7MessageControlID() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = UInt32.random(in: 1000...9999)
        return "MSG\(timestamp)\(random)"
    }
}

/// Thread-safe continuation guard to ensure the continuation is resumed exactly once.
private final class MLLPContinuationGuard: @unchecked Sendable {
    private var continuation: CheckedContinuation<String, Error>?
    private let lock = NSLock()
    private(set) var hasResumed = false

    init(_ continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<String, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed, let cont = continuation else { return }
        hasResumed = true
        continuation = nil
        cont.resume(with: result)
    }
}

#endif
