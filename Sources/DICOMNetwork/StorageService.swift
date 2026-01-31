import Foundation
import DICOMCore

// MARK: - Store Result

/// Result of a DICOM storage operation (C-STORE)
///
/// Contains information about the completed C-STORE operation.
///
/// Reference: PS3.4 Annex B - Storage Service Class
public struct StoreResult: Sendable, Hashable {
    /// Whether the storage was successful
    public let success: Bool
    
    /// The DIMSE status from the response
    public let status: DIMSEStatus
    
    /// The affected SOP Class UID
    public let affectedSOPClassUID: String
    
    /// The affected SOP Instance UID
    public let affectedSOPInstanceUID: String
    
    /// Round-trip time in seconds
    public let roundTripTime: TimeInterval
    
    /// The remote Application Entity title
    public let remoteAETitle: String
    
    /// Whether the store completed with a warning
    public var hasWarning: Bool {
        status.isWarning
    }
    
    /// Creates a store result
    public init(
        success: Bool,
        status: DIMSEStatus,
        affectedSOPClassUID: String,
        affectedSOPInstanceUID: String,
        roundTripTime: TimeInterval,
        remoteAETitle: String
    ) {
        self.success = success
        self.status = status
        self.affectedSOPClassUID = affectedSOPClassUID
        self.affectedSOPInstanceUID = affectedSOPInstanceUID
        self.roundTripTime = roundTripTime
        self.remoteAETitle = remoteAETitle
    }
}

extension StoreResult: CustomStringConvertible {
    public var description: String {
        let statusStr = success ? "SUCCESS" : (status.isWarning ? "WARNING" : "FAILED")
        return "StoreResult(\(statusStr), status=\(status), sop=\(affectedSOPClassUID), rtt=\(String(format: "%.3f", roundTripTime))s, ae=\(remoteAETitle))"
    }
}

// MARK: - Storage Status Category

/// Categories of C-STORE status codes
///
/// Reference: PS3.4 Annex B.2.3 - Status
public enum StoreStatusCategory: Sendable, Hashable {
    /// Operation completed successfully (0x0000)
    case success
    
    /// Operation completed with a warning
    case warning
    
    /// Operation failed
    case failure
    
    /// Unknown status
    case unknown
    
    /// Creates a status category from a DIMSE status
    public init(from status: DIMSEStatus) {
        if status.isSuccess {
            self = .success
        } else if status.isWarning {
            self = .warning
        } else if status.isFailure {
            self = .failure
        } else {
            self = .unknown
        }
    }
}

// MARK: - Storage Configuration

/// Configuration for the DICOM Storage Service
public struct StorageConfiguration: Sendable, Hashable {
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
    
    /// Priority for the store operation
    public let priority: DIMSEPriority
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates a storage configuration
    ///
    /// - Parameters:
    ///   - callingAETitle: The local AE title
    ///   - calledAETitle: The remote AE title
    ///   - timeout: Connection timeout in seconds (default: 60)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - priority: Operation priority (default: medium)
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        priority: DIMSEPriority = .medium
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.priority = priority
    }
}

// MARK: - Batch Store Progress

/// Progress information for batch storage operations
public struct BatchStoreProgress: Sendable, Hashable {
    /// Total number of instances to store
    public let total: Int
    
    /// Number of instances stored successfully
    public let succeeded: Int
    
    /// Number of instances that failed
    public let failed: Int
    
    /// Number of instances with warnings
    public let warnings: Int
    
    /// The fraction of operations complete (0.0 to 1.0)
    public var fractionComplete: Double {
        guard total > 0 else { return 0.0 }
        return Double(succeeded + failed + warnings) / Double(total)
    }
    
    /// Whether all operations have completed (regardless of success/failure)
    public var isComplete: Bool {
        succeeded + failed + warnings >= total
    }
    
    /// Creates batch store progress information
    public init(total: Int, succeeded: Int = 0, failed: Int = 0, warnings: Int = 0) {
        self.total = total
        self.succeeded = succeeded
        self.failed = failed
        self.warnings = warnings
    }
}

extension BatchStoreProgress: CustomStringConvertible {
    public var description: String {
        "BatchProgress: \(succeeded + failed + warnings)/\(total) completed (\(succeeded) succeeded, \(failed) failed, \(warnings) warnings)"
    }
}

#if canImport(Network)

// MARK: - DICOM Storage Service

/// DICOM Storage Service (C-STORE SCU)
///
/// Implements the DICOM Storage Service Class as a Service Class User (SCU).
/// This enables sending DICOM files to remote Storage Service Class Providers (SCPs)
/// such as PACS systems, workstations, or other DICOM nodes.
///
/// Reference: PS3.4 Annex B - Storage Service Class
/// Reference: PS3.7 Section 9.1.1 - C-STORE Service
///
/// ## Usage
///
/// ```swift
/// // Store a DICOM file
/// let result = try await DICOMStorageService.store(
///     file: dicomFile,
///     to: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS"
/// )
///
/// if result.success {
///     print("Stored successfully: \(result.affectedSOPInstanceUID)")
/// }
///
/// // Store raw DICOM data
/// let dataResult = try await DICOMStorageService.store(
///     data: dicomData,
///     sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
///     sopInstanceUID: "1.2.3.4.5.6.7.8.9",
///     to: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MY_SCU",
///     calledAE: "PACS"
/// )
/// ```
public enum DICOMStorageService {
    
    // MARK: - Store File
    
    /// Stores a DICOM file to a remote SCP
    ///
    /// Extracts the SOP Class UID and SOP Instance UID from the file's data set
    /// and sends it to the specified destination.
    ///
    /// - Parameters:
    ///   - data: The complete DICOM file data (including file meta information)
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local Application Entity title
    ///   - calledAE: The remote Application Entity title
    ///   - priority: Operation priority (default: medium)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: A `StoreResult` with detailed information
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    /// - Throws: `DICOMError` if the file cannot be parsed or is missing required attributes
    public static func store(
        fileData data: Data,
        to host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        priority: DIMSEPriority = .medium,
        timeout: TimeInterval = 60
    ) async throws -> StoreResult {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        // Parse the DICOM file to get SOP Class and Instance UIDs
        let parser = DICOMFileParser(data: data)
        let fileInfo = try parser.parseForStorage()
        
        let config = StorageConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout,
            priority: priority
        )
        
        return try await performStore(
            host: host,
            port: port,
            configuration: config,
            sopClassUID: fileInfo.sopClassUID,
            sopInstanceUID: fileInfo.sopInstanceUID,
            transferSyntaxUID: fileInfo.transferSyntaxUID,
            dataSetData: fileInfo.dataSetData
        )
    }
    
    // MARK: - Store Data Set
    
    /// Stores a DICOM data set to a remote SCP
    ///
    /// Sends the provided data set with the specified SOP Class and Instance UIDs.
    /// The data should be encoded in the specified transfer syntax.
    ///
    /// - Parameters:
    ///   - data: The DICOM data set (without file meta information preamble)
    ///   - sopClassUID: The SOP Class UID
    ///   - sopInstanceUID: The SOP Instance UID  
    ///   - transferSyntaxUID: The transfer syntax of the data (default: Explicit VR Little Endian)
    ///   - host: The remote host address (IP or hostname)
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local Application Entity title
    ///   - calledAE: The remote Application Entity title
    ///   - priority: Operation priority (default: medium)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: A `StoreResult` with detailed information
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func store(
        dataSetData data: Data,
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String = explicitVRLittleEndianTransferSyntaxUID,
        to host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        priority: DIMSEPriority = .medium,
        timeout: TimeInterval = 60
    ) async throws -> StoreResult {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = StorageConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout,
            priority: priority
        )
        
        return try await performStore(
            host: host,
            port: port,
            configuration: config,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            transferSyntaxUID: transferSyntaxUID,
            dataSetData: data
        )
    }
    
    // MARK: - Store with Configuration
    
    /// Stores a DICOM data set with full configuration control
    ///
    /// - Parameters:
    ///   - data: The DICOM data set (without file meta information preamble)
    ///   - sopClassUID: The SOP Class UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - transferSyntaxUID: The transfer syntax of the data
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - configuration: The storage configuration
    /// - Returns: A `StoreResult` with detailed information
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func store(
        dataSetData data: Data,
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String,
        to host: String,
        port: UInt16 = dicomDefaultPort,
        configuration: StorageConfiguration
    ) async throws -> StoreResult {
        return try await performStore(
            host: host,
            port: port,
            configuration: configuration,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            transferSyntaxUID: transferSyntaxUID,
            dataSetData: data
        )
    }
    
    // MARK: - Private Implementation
    
    /// Performs the C-STORE operation
    private static func performStore(
        host: String,
        port: UInt16,
        configuration: StorageConfiguration,
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String,
        dataSetData: Data
    ) async throws -> StoreResult {
        let startTime = Date()
        
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
        
        // Create presentation context for the Storage SOP Class
        // Propose the original transfer syntax and fall back to Explicit/Implicit VR LE
        var transferSyntaxes = [transferSyntaxUID]
        if transferSyntaxUID != explicitVRLittleEndianTransferSyntaxUID {
            transferSyntaxes.append(explicitVRLittleEndianTransferSyntaxUID)
        }
        if transferSyntaxUID != implicitVRLittleEndianTransferSyntaxUID {
            transferSyntaxes.append(implicitVRLittleEndianTransferSyntaxUID)
        }
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: transferSyntaxes
        )
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify that the Storage SOP Class was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Get the accepted transfer syntax
            let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1)
                ?? implicitVRLittleEndianTransferSyntaxUID
            
            // Transcode the data set if the accepted transfer syntax differs
            let finalDataSetData: Data
            if acceptedTransferSyntax != transferSyntaxUID {
                // For now, we only support same transfer syntax or the common ones
                // Future versions can add transcoding support
                if acceptedTransferSyntax == explicitVRLittleEndianTransferSyntaxUID ||
                   acceptedTransferSyntax == implicitVRLittleEndianTransferSyntaxUID {
                    // Basic transcoding between Explicit and Implicit VR is possible
                    // but for now we send the data as-is if it's one of these syntaxes
                    finalDataSetData = dataSetData
                } else {
                    try await association.abort()
                    throw DICOMNetworkError.invalidState(
                        "Cannot transcode from \(transferSyntaxUID) to \(acceptedTransferSyntax)"
                    )
                }
            } else {
                finalDataSetData = dataSetData
            }
            
            // Send C-STORE request
            let response = try await performCStore(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize,
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                priority: configuration.priority,
                dataSetData: finalDataSetData
            )
            
            // Release association gracefully
            try await association.release()
            
            let endTime = Date()
            let roundTripTime = endTime.timeIntervalSince(startTime)
            
            return StoreResult(
                success: response.status.isSuccess,
                status: response.status,
                affectedSOPClassUID: response.affectedSOPClassUID,
                affectedSOPInstanceUID: response.affectedSOPInstanceUID,
                roundTripTime: roundTripTime,
                remoteAETitle: configuration.calledAETitle.value
            )
            
        } catch {
            // Attempt to abort the association on error
            try? await association.abort()
            throw error
        }
    }
    
    /// Performs the C-STORE request/response exchange
    ///
    /// - Parameters:
    ///   - association: The established association
    ///   - presentationContextID: The accepted presentation context ID
    ///   - maxPDUSize: The negotiated maximum PDU size
    ///   - sopClassUID: The SOP Class UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - priority: The operation priority
    ///   - dataSetData: The data set to store
    /// - Returns: The C-STORE response
    /// - Throws: `DICOMNetworkError` for protocol errors
    private static func performCStore(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32,
        sopClassUID: String,
        sopInstanceUID: String,
        priority: DIMSEPriority,
        dataSetData: Data
    ) async throws -> CStoreResponse {
        // Create C-STORE request
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            affectedSOPInstanceUID: sopInstanceUID,
            priority: priority,
            presentationContextID: presentationContextID
        )
        
        // Fragment and send the command and data set
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: dataSetData,
            presentationContextID: presentationContextID
        )
        
        // Send all PDUs
        for pdu in pdus {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        
        // Receive response
        let assembler = MessageAssembler()
        
        while true {
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                guard let storeResponse = message.asCStoreResponse() else {
                    throw DICOMNetworkError.decodingFailed(
                        "Expected C-STORE-RSP, got \(message.command?.description ?? "unknown")"
                    )
                }
                return storeResponse
            }
        }
    }
}

// MARK: - DICOM File Parser for Storage

/// Internal parser for extracting storage-relevant information from DICOM files
struct DICOMFileParser {
    let data: Data
    
    /// Information extracted from a DICOM file for storage
    struct FileInfo {
        let sopClassUID: String
        let sopInstanceUID: String
        let transferSyntaxUID: String
        let dataSetData: Data
    }
    
    /// Parses the file and extracts information needed for C-STORE
    func parseForStorage() throws -> FileInfo {
        // Validate minimum size (128-byte preamble + 4-byte "DICM")
        guard data.count >= 132 else {
            throw DICOMError.unexpectedEndOfData
        }
        
        // Validate "DICM" prefix at offset 128
        let dicmOffset = 128
        let dicmBytes = data[dicmOffset..<dicmOffset+4]
        guard dicmBytes.elementsEqual([0x44, 0x49, 0x43, 0x4D]) else { // "DICM" in ASCII
            throw DICOMError.invalidDICMPrefix
        }
        
        // Parse File Meta Information to get:
        // - SOP Class UID from (0002,0002) Media Storage SOP Class UID
        // - SOP Instance UID from (0002,0003) Media Storage SOP Instance UID
        // - Transfer Syntax UID from (0002,0010)
        // - End of File Meta Information from (0002,0000) File Meta Information Group Length
        
        var offset = 132 // Start after "DICM"
        var sopClassUID: String?
        var sopInstanceUID: String?
        var transferSyntaxUID: String?
        var fileMetaInfoLength: UInt32?
        
        // File Meta Information uses Explicit VR Little Endian
        while offset < data.count {
            // Read tag
            guard offset + 4 <= data.count else { break }
            let group = data.readUInt16LE(at: offset)
            let element = data.readUInt16LE(at: offset + 2)
            offset += 4
            
            // Stop when we exit Group 0002
            if group != 0x0002 {
                // Back up to the start of this element - this is the start of the data set
                offset -= 4
                break
            }
            
            // Read VR (2 bytes for Explicit VR)
            guard offset + 2 <= data.count else { break }
            let vrBytes = data.subdata(in: offset..<offset+2)
            let vrString = String(data: vrBytes, encoding: .ascii) ?? "UN"
            offset += 2
            
            // Determine value length
            let valueLength: UInt32
            let vr = VR(rawValue: vrString) ?? .UN
            
            if vr.uses4ByteLength {
                // Skip reserved 2 bytes, read 4-byte length
                guard offset + 6 <= data.count else { break }
                offset += 2
                valueLength = data.readUInt32LE(at: offset)
                offset += 4
            } else {
                // Read 2-byte length
                guard offset + 2 <= data.count else { break }
                valueLength = UInt32(data.readUInt16LE(at: offset))
                offset += 2
            }
            
            // Read value
            guard valueLength != 0xFFFFFFFF else { break } // Undefined length not expected in FMI
            guard offset + Int(valueLength) <= data.count else { break }
            let valueData = data.subdata(in: offset..<offset+Int(valueLength))
            offset += Int(valueLength)
            
            // Extract specific elements
            let tag = Tag(group: group, element: element)
            
            switch tag {
            case Tag(group: 0x0002, element: 0x0000): // File Meta Information Group Length
                if valueLength == 4 {
                    fileMetaInfoLength = valueData.readUInt32LE(at: 0)
                }
            case Tag(group: 0x0002, element: 0x0002): // Media Storage SOP Class UID
                sopClassUID = String(data: valueData, encoding: .ascii)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
            case Tag(group: 0x0002, element: 0x0003): // Media Storage SOP Instance UID
                sopInstanceUID = String(data: valueData, encoding: .ascii)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
            case Tag(group: 0x0002, element: 0x0010): // Transfer Syntax UID
                transferSyntaxUID = String(data: valueData, encoding: .ascii)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
            default:
                break
            }
        }
        
        // If we have File Meta Info Group Length, use it to find exact data set start
        if let fmiLength = fileMetaInfoLength {
            offset = 132 + Int(fmiLength)
        }
        
        // Validate required fields
        guard let finalSOPClassUID = sopClassUID, !finalSOPClassUID.isEmpty else {
            throw DICOMError.missingRequiredElement("Media Storage SOP Class UID (0002,0002)")
        }
        
        guard let finalSOPInstanceUID = sopInstanceUID, !finalSOPInstanceUID.isEmpty else {
            throw DICOMError.missingRequiredElement("Media Storage SOP Instance UID (0002,0003)")
        }
        
        let finalTransferSyntax = transferSyntaxUID ?? explicitVRLittleEndianTransferSyntaxUID
        
        // Extract data set (everything after File Meta Information)
        guard offset < data.count else {
            throw DICOMError.unexpectedEndOfData
        }
        let dataSetData = data.subdata(in: offset..<data.count)
        
        return FileInfo(
            sopClassUID: finalSOPClassUID,
            sopInstanceUID: finalSOPInstanceUID,
            transferSyntaxUID: finalTransferSyntax,
            dataSetData: dataSetData
        )
    }
}

// MARK: - Data Extensions for Reading

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        let bytes = self[self.startIndex + offset..<self.startIndex + offset + 2]
        return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex + 1]) << 8)
    }
    
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let bytes = self[self.startIndex + offset..<self.startIndex + offset + 4]
        return UInt32(bytes[bytes.startIndex]) |
               (UInt32(bytes[bytes.startIndex + 1]) << 8) |
               (UInt32(bytes[bytes.startIndex + 2]) << 16) |
               (UInt32(bytes[bytes.startIndex + 3]) << 24)
    }
}

#endif
