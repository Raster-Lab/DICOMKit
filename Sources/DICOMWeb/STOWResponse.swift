import Foundation

/// Response from a STOW-RS store operation
///
/// Contains the results of storing one or more DICOM instances,
/// including successfully stored instances and any failures.
///
/// Reference: PS3.18 Section 10.5 - STOW-RS
///
/// ## Example Usage
///
/// ```swift
/// let response = try await client.storeInstances(instances: [dicomData])
///
/// if response.isFullSuccess {
///     print("All \(response.successCount) instances stored successfully")
/// } else if response.isPartialSuccess {
///     print("Stored \(response.successCount) instances with \(response.failureCount) failures")
/// } else {
///     print("Store failed: \(response.failedInstances)")
/// }
/// ```
public struct STOWResponse: Sendable, Equatable {
    
    // MARK: - Types
    
    /// Result for a single stored instance
    public struct InstanceResult: Sendable, Equatable {
        /// The SOP Class UID of the stored instance
        public let sopClassUID: String?
        
        /// The SOP Instance UID of the stored instance
        public let sopInstanceUID: String
        
        /// The retrieve URL for the stored instance (if available)
        public let retrieveURL: String?
        
        /// Creates an instance result
        /// - Parameters:
        ///   - sopClassUID: The SOP Class UID
        ///   - sopInstanceUID: The SOP Instance UID
        ///   - retrieveURL: The retrieve URL for the stored instance
        public init(sopClassUID: String? = nil, sopInstanceUID: String, retrieveURL: String? = nil) {
            self.sopClassUID = sopClassUID
            self.sopInstanceUID = sopInstanceUID
            self.retrieveURL = retrieveURL
        }
    }
    
    /// Failure information for a single instance
    public struct InstanceFailure: Sendable, Equatable {
        /// The SOP Class UID of the failed instance
        public let sopClassUID: String?
        
        /// The SOP Instance UID of the failed instance
        public let sopInstanceUID: String?
        
        /// The failure reason code (DICOM PS3.4 Annex B)
        public let failureReason: UInt16?
        
        /// Human-readable failure description
        public let failureDescription: String?
        
        /// Creates an instance failure
        /// - Parameters:
        ///   - sopClassUID: The SOP Class UID
        ///   - sopInstanceUID: The SOP Instance UID
        ///   - failureReason: The failure reason code
        ///   - failureDescription: Human-readable description
        public init(
            sopClassUID: String? = nil,
            sopInstanceUID: String? = nil,
            failureReason: UInt16? = nil,
            failureDescription: String? = nil
        ) {
            self.sopClassUID = sopClassUID
            self.sopInstanceUID = sopInstanceUID
            self.failureReason = failureReason
            self.failureDescription = failureDescription
        }
        
        // MARK: - Standard Failure Reasons
        
        /// Well-known STOW-RS failure reason codes from DICOM PS3.4 Annex B
        public enum FailureReasonCode: UInt16, Sendable {
            /// Processing failure
            case processingFailure = 0x0110
            
            /// Duplicate SOP Instance
            case duplicateSOPInstance = 0x0111
            
            /// No such object instance (referenced object doesn't exist)
            case noSuchObjectInstance = 0x0112
            
            /// No such event type
            case noSuchEventType = 0x0113
            
            /// No such argument
            case noSuchArgument = 0x0114
            
            /// Invalid argument value
            case invalidArgumentValue = 0x0115
            
            /// Mandatory attribute missing
            case mandatoryAttributeMissing = 0x0120
            
            /// SOP Class not supported
            case sopClassNotSupported = 0x0122
            
            /// Transfer syntax not supported
            case transferSyntaxNotSupported = 0x0124
            
            /// Data set does not match SOP Class
            case dataSetDoesNotMatchSOPClass = 0x0131
            
            /// Cannot understand
            case cannotUnderstand = 0xC000
            
            /// Out of resources
            case outOfResources = 0xA700
            
            /// Data element coerced
            case dataSetCoercion = 0xB000
            
            /// Elements discarded
            case elementsDiscarded = 0xB006
        }
        
        /// Returns the failure reason as a known code, if applicable
        public var knownFailureReason: FailureReasonCode? {
            guard let reason = failureReason else { return nil }
            return FailureReasonCode(rawValue: reason)
        }
    }
    
    /// Warning message from the server
    public struct Warning: Sendable, Equatable {
        /// Warning code
        public let code: String?
        
        /// Warning message
        public let message: String
        
        /// Creates a warning
        /// - Parameters:
        ///   - code: Optional warning code
        ///   - message: The warning message
        public init(code: String? = nil, message: String) {
            self.code = code
            self.message = message
        }
    }
    
    // MARK: - Properties
    
    /// Successfully stored instances
    public let storedInstances: [InstanceResult]
    
    /// Failed instances with failure information
    public let failedInstances: [InstanceFailure]
    
    /// Warning messages from the server
    public let warnings: [Warning]
    
    /// The base retrieve URL for the stored instances
    public let retrieveURL: String?
    
    // MARK: - Computed Properties
    
    /// Number of successfully stored instances
    public var successCount: Int {
        return storedInstances.count
    }
    
    /// Number of failed instances
    public var failureCount: Int {
        return failedInstances.count
    }
    
    /// Total number of instances processed
    public var totalCount: Int {
        return successCount + failureCount
    }
    
    /// Whether all instances were stored successfully
    public var isFullSuccess: Bool {
        return failedInstances.isEmpty && !storedInstances.isEmpty
    }
    
    /// Whether some but not all instances were stored
    public var isPartialSuccess: Bool {
        return !storedInstances.isEmpty && !failedInstances.isEmpty
    }
    
    /// Whether all instances failed
    public var isFullFailure: Bool {
        return storedInstances.isEmpty && !failedInstances.isEmpty
    }
    
    /// Whether there are any warnings
    public var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    // MARK: - Initialization
    
    /// Creates a STOW response
    /// - Parameters:
    ///   - storedInstances: Successfully stored instances
    ///   - failedInstances: Failed instances
    ///   - warnings: Warning messages
    ///   - retrieveURL: Base retrieve URL
    public init(
        storedInstances: [InstanceResult] = [],
        failedInstances: [InstanceFailure] = [],
        warnings: [Warning] = [],
        retrieveURL: String? = nil
    ) {
        self.storedInstances = storedInstances
        self.failedInstances = failedInstances
        self.warnings = warnings
        self.retrieveURL = retrieveURL
    }
}

// MARK: - JSON Parsing

extension STOWResponse {
    
    /// DICOM JSON tags used in STOW-RS responses
    private enum Tag {
        static let referencedSOPSequence = "00081199"  // (0008,1199)
        static let failedSOPSequence = "00081198"      // (0008,1198)
        static let retrieveURL = "00081190"            // (0008,1190)
        static let referencedSOPClassUID = "00081150"  // (0008,1150)
        static let referencedSOPInstanceUID = "00081155" // (0008,1155)
        static let failureReason = "00081197"          // (0008,1197)
        static let warningReason = "00081196"          // (0008,1196)
    }
    
    /// Parses a STOW-RS JSON response
    /// - Parameter json: The DICOM JSON object (single dataset)
    /// - Returns: Parsed STOWResponse
    /// - Throws: DICOMwebError if parsing fails
    public static func parse(json: [String: Any]) throws -> STOWResponse {
        var storedInstances: [InstanceResult] = []
        var failedInstances: [InstanceFailure] = []
        let warnings: [Warning] = []
        var retrieveURL: String?
        
        // Parse RetrieveURL (0008,1190)
        if let urlElement = json[Tag.retrieveURL] as? [String: Any],
           let values = urlElement["Value"] as? [String] {
            retrieveURL = values.first
        }
        
        // Parse ReferencedSOPSequence (0008,1199) - successful instances
        if let seqElement = json[Tag.referencedSOPSequence] as? [String: Any],
           let items = seqElement["Value"] as? [[String: Any]] {
            for item in items {
                let result = parseInstanceResult(from: item)
                storedInstances.append(result)
            }
        }
        
        // Parse FailedSOPSequence (0008,1198) - failed instances
        if let seqElement = json[Tag.failedSOPSequence] as? [String: Any],
           let items = seqElement["Value"] as? [[String: Any]] {
            for item in items {
                let failure = parseInstanceFailure(from: item)
                failedInstances.append(failure)
            }
        }
        
        return STOWResponse(
            storedInstances: storedInstances,
            failedInstances: failedInstances,
            warnings: warnings,
            retrieveURL: retrieveURL
        )
    }
    
    /// Parses an InstanceResult from a DICOM JSON sequence item
    private static func parseInstanceResult(from json: [String: Any]) -> InstanceResult {
        var sopClassUID: String?
        var sopInstanceUID = ""
        var retrieveURL: String?
        
        // ReferencedSOPClassUID (0008,1150)
        if let element = json[Tag.referencedSOPClassUID] as? [String: Any],
           let values = element["Value"] as? [String] {
            sopClassUID = values.first
        }
        
        // ReferencedSOPInstanceUID (0008,1155)
        if let element = json[Tag.referencedSOPInstanceUID] as? [String: Any],
           let values = element["Value"] as? [String] {
            sopInstanceUID = values.first ?? ""
        }
        
        // RetrieveURL (0008,1190)
        if let element = json[Tag.retrieveURL] as? [String: Any],
           let values = element["Value"] as? [String] {
            retrieveURL = values.first
        }
        
        return InstanceResult(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            retrieveURL: retrieveURL
        )
    }
    
    /// Parses an InstanceFailure from a DICOM JSON sequence item
    private static func parseInstanceFailure(from json: [String: Any]) -> InstanceFailure {
        var sopClassUID: String?
        var sopInstanceUID: String?
        var failureReason: UInt16?
        var failureDescription: String?
        
        // ReferencedSOPClassUID (0008,1150)
        if let element = json[Tag.referencedSOPClassUID] as? [String: Any],
           let values = element["Value"] as? [String] {
            sopClassUID = values.first
        }
        
        // ReferencedSOPInstanceUID (0008,1155)
        if let element = json[Tag.referencedSOPInstanceUID] as? [String: Any],
           let values = element["Value"] as? [String] {
            sopInstanceUID = values.first
        }
        
        // FailureReason (0008,1197)
        if let element = json[Tag.failureReason] as? [String: Any],
           let values = element["Value"] as? [Int] {
            if let value = values.first {
                failureReason = UInt16(value)
            }
        }
        
        // WarningReason (0008,1196) - used for failure description
        if let element = json[Tag.warningReason] as? [String: Any],
           let values = element["Value"] as? [Int] {
            if let value = values.first {
                failureDescription = "Reason code: \(value)"
            }
        }
        
        return InstanceFailure(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            failureReason: failureReason,
            failureDescription: failureDescription
        )
    }
}

// MARK: - CustomStringConvertible

extension STOWResponse: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        
        if isFullSuccess {
            parts.append("Success: \(successCount) instance(s) stored")
        } else if isPartialSuccess {
            parts.append("Partial Success: \(successCount) stored, \(failureCount) failed")
        } else if isFullFailure {
            parts.append("Failed: \(failureCount) instance(s)")
        } else {
            parts.append("Empty response")
        }
        
        if hasWarnings {
            parts.append("(\(warnings.count) warning(s))")
        }
        
        return parts.joined(separator: " ")
    }
}

extension STOWResponse.InstanceFailure: CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["Instance failure"]
        
        if let uid = sopInstanceUID {
            parts.append("SOP Instance: \(uid)")
        }
        
        if let reason = failureReason {
            parts.append("Reason: \(String(format: "0x%04X", reason))")
        }
        
        if let desc = failureDescription {
            parts.append("Description: \(desc)")
        }
        
        return parts.joined(separator: ", ")
    }
}
