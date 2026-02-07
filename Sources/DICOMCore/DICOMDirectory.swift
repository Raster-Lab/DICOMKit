import Foundation

/// DICOMDIR Profile Type
///
/// Defines the application profile for a DICOMDIR file-set.
/// Reference: DICOM PS3.11 - Media Storage Application Profiles
public enum DICOMDIRProfile: String, Sendable, Codable {
    /// General Purpose CD-R/DVD Interchange (STD-GEN-CD/DVD)
    case standardGeneralCD = "STD-GEN-CD"
    
    /// General Purpose DVD with JPEG Interchange
    case standardGeneralDVD = "STD-GEN-DVD"
    
    /// General Purpose DVD with JPEG 2000 Interchange
    case standardGeneralDVDJPEG2000 = "STD-GEN-DVD-J2K"
    
    /// General Purpose USB/Flash Memory with JPEG/JPEG 2000
    case standardGeneralUSB = "STD-GEN-USB"
    
    /// General Purpose MIME Interchange
    case standardGeneralMIME = "STD-GEN-MIME"
    
    /// General Purpose Secure DICOM Interchange
    case standardGeneralSecure = "STD-GEN-SEC"
    
    /// CT/MR Interchange on Media
    case standardCTMR = "STD-CTMR-xxxx"
    
    /// Ultrasound Interchange
    case standardUltrasound = "STD-US-xxxx"
    
    /// Mammography Interchange
    case standardMammography = "STD-MAM-xxxx"
    
    /// No specific profile
    case none = ""
}

/// DICOM Directory (DICOMDIR)
///
/// Represents a complete DICOMDIR structure for media storage directory.
/// Reference: DICOM PS3.10 - Media Storage and File Format
/// Reference: DICOM PS3.3 F.5 - Media Storage Directory SOP Class
public struct DICOMDirectory: Sendable {
    /// File-set ID (identifier for this file-set)
    public var fileSetID: String
    
    /// Application profile type
    public var profile: DICOMDIRProfile
    
    /// Specific character set
    public var specificCharacterSet: String?
    
    /// File-set descriptor file ID (optional)
    public var fileSetDescriptorFileID: [String]?
    
    /// Specific character set of file-set descriptor file
    public var specificCharacterSetOfFileSetDescriptorFile: String?
    
    /// Root directory records (typically PATIENT records)
    public var rootRecords: [DirectoryRecord]
    
    /// File-set consistency flag (true if consistent)
    public var isConsistent: Bool
    
    /// Initialize a new DICOMDIR
    ///
    /// - Parameters:
    ///   - fileSetID: File-set identifier (default: empty string)
    ///   - profile: Application profile (default: .standardGeneralCD)
    ///   - specificCharacterSet: Character set (default: nil)
    ///   - rootRecords: Root directory records (default: empty)
    ///   - isConsistent: Consistency flag (default: true)
    public init(
        fileSetID: String = "",
        profile: DICOMDIRProfile = .standardGeneralCD,
        specificCharacterSet: String? = nil,
        fileSetDescriptorFileID: [String]? = nil,
        specificCharacterSetOfFileSetDescriptorFile: String? = nil,
        rootRecords: [DirectoryRecord] = [],
        isConsistent: Bool = true
    ) {
        self.fileSetID = fileSetID
        self.profile = profile
        self.specificCharacterSet = specificCharacterSet
        self.fileSetDescriptorFileID = fileSetDescriptorFileID
        self.specificCharacterSetOfFileSetDescriptorFile = specificCharacterSetOfFileSetDescriptorFile
        self.rootRecords = rootRecords
        self.isConsistent = isConsistent
    }
    
    /// Get all records flattened in depth-first order
    ///
    /// - Returns: Array of all directory records
    public func allRecords() -> [DirectoryRecord] {
        var records: [DirectoryRecord] = []
        
        func traverse(_ record: DirectoryRecord) {
            records.append(record)
            for child in record.children {
                traverse(child)
            }
        }
        
        for root in rootRecords {
            traverse(root)
        }
        
        return records
    }
    
    /// Get total count of all records (including nested)
    ///
    /// - Returns: Total number of records
    public func totalRecordCount() -> Int {
        return allRecords().count
    }
    
    /// Find all records of a specific type
    ///
    /// - Parameter recordType: Type of records to find
    /// - Returns: Array of matching directory records
    public func records(ofType recordType: DirectoryRecordType) -> [DirectoryRecord] {
        return allRecords().filter { $0.recordType == recordType }
    }
    
    /// Find a record by SOP Instance UID
    ///
    /// - Parameter sopInstanceUID: SOP Instance UID to search for
    /// - Returns: The directory record if found, nil otherwise
    public func record(withSOPInstanceUID sopInstanceUID: String) -> DirectoryRecord? {
        return allRecords().first { $0.referencedSOPInstanceUID == sopInstanceUID }
    }
    
    /// Get all referenced file paths
    ///
    /// - Returns: Array of file paths referenced in the directory
    public func allReferencedFiles() -> [String] {
        return allRecords().compactMap { $0.referencedFilePath() }
    }
    
    /// Add a root record
    ///
    /// - Parameter record: Directory record to add at root level
    public mutating func addRootRecord(_ record: DirectoryRecord) {
        rootRecords.append(record)
    }
    
    /// Remove all root records
    public mutating func removeAllRootRecords() {
        rootRecords.removeAll()
    }
}

// MARK: - DICOMDIR Statistics

extension DICOMDirectory {
    /// Statistics about the DICOMDIR content
    public struct Statistics: Sendable {
        /// Number of patient records
        public let patientCount: Int
        
        /// Number of study records
        public let studyCount: Int
        
        /// Number of series records
        public let seriesCount: Int
        
        /// Number of image records
        public let imageCount: Int
        
        /// Total number of all records
        public let totalRecordCount: Int
        
        /// Number of active records
        public let activeRecordCount: Int
        
        /// Number of inactive records
        public let inactiveRecordCount: Int
    }
    
    /// Calculate statistics for this DICOMDIR
    ///
    /// - Returns: Statistics about the directory content
    public func statistics() -> Statistics {
        let allRecords = self.allRecords()
        
        return Statistics(
            patientCount: records(ofType: .patient).count,
            studyCount: records(ofType: .study).count,
            seriesCount: records(ofType: .series).count,
            imageCount: records(ofType: .image).count,
            totalRecordCount: allRecords.count,
            activeRecordCount: allRecords.filter { $0.isActive }.count,
            inactiveRecordCount: allRecords.filter { !$0.isActive }.count
        )
    }
}

// MARK: - CustomStringConvertible

extension DICOMDirectory: CustomStringConvertible {
    public var description: String {
        let stats = statistics()
        return """
            DICOMDIR(
              fileSetID: \(fileSetID.isEmpty ? "<none>" : fileSetID)
              profile: \(profile.rawValue)
              patients: \(stats.patientCount)
              studies: \(stats.studyCount)
              series: \(stats.seriesCount)
              images: \(stats.imageCount)
              consistent: \(isConsistent)
            )
            """
    }
}

// MARK: - Validation

extension DICOMDirectory {
    /// Validation error types
    public enum ValidationError: Error, CustomStringConvertible {
        /// File-set ID is missing or invalid
        case invalidFileSetID
        
        /// Directory record hierarchy is invalid
        case invalidHierarchy(String)
        
        /// Referenced file does not exist
        case missingReferencedFile(String)
        
        /// SOP Instance UID is missing or invalid
        case invalidSOPInstanceUID(String)
        
        /// Duplicate SOP Instance UID found
        case duplicateSOPInstanceUID(String)
        
        /// Record type is invalid for its position in hierarchy
        case invalidRecordTypeInHierarchy(String)
        
        public var description: String {
            switch self {
            case .invalidFileSetID:
                return "File-set ID is missing or invalid"
            case .invalidHierarchy(let msg):
                return "Invalid directory hierarchy: \(msg)"
            case .missingReferencedFile(let path):
                return "Referenced file does not exist: \(path)"
            case .invalidSOPInstanceUID(let uid):
                return "Invalid SOP Instance UID: \(uid)"
            case .duplicateSOPInstanceUID(let uid):
                return "Duplicate SOP Instance UID: \(uid)"
            case .invalidRecordTypeInHierarchy(let msg):
                return "Invalid record type in hierarchy: \(msg)"
            }
        }
    }
    
    /// Validate the directory structure
    ///
    /// - Parameter checkFileExistence: Whether to check if referenced files exist (default: false)
    /// - Throws: ValidationError if validation fails
    public func validate(checkFileExistence: Bool = false) throws {
        // Check for duplicate SOP Instance UIDs
        var seenUIDs = Set<String>()
        for record in allRecords() {
            if let uid = record.referencedSOPInstanceUID {
                if seenUIDs.contains(uid) {
                    throw ValidationError.duplicateSOPInstanceUID(uid)
                }
                seenUIDs.insert(uid)
            }
        }
        
        // Validate hierarchy: PATIENT -> STUDY -> SERIES -> IMAGE
        func validateHierarchy(_ record: DirectoryRecord, allowedChildTypes: [DirectoryRecordType]) throws {
            for child in record.children {
                if !allowedChildTypes.contains(child.recordType) {
                    throw ValidationError.invalidRecordTypeInHierarchy(
                        "\(child.recordType.rawValue) cannot be child of \(record.recordType.rawValue)"
                    )
                }
                
                // Recursively validate children
                switch child.recordType {
                case .patient:
                    try validateHierarchy(child, allowedChildTypes: [.study])
                case .study:
                    try validateHierarchy(child, allowedChildTypes: [.series])
                case .series:
                    try validateHierarchy(child, allowedChildTypes: [.image, .presentation, .srDocument, .waveform, .rtDose, .rtStructureSet, .rtPlan])
                default:
                    // Leaf nodes typically don't have children
                    if !child.children.isEmpty {
                        throw ValidationError.invalidHierarchy("Leaf node \(child.recordType.rawValue) should not have children")
                    }
                }
            }
        }
        
        // Validate root level records (should be PATIENT records typically)
        for root in rootRecords {
            if root.recordType == .patient {
                try validateHierarchy(root, allowedChildTypes: [.study])
            }
        }
        
        // Optionally check file existence
        if checkFileExistence {
            for record in allRecords() {
                if let filePath = record.referencedFilePath() {
                    // Note: Actual file existence check would require base path context
                    // This is a placeholder for the validation logic
                    if filePath.isEmpty {
                        throw ValidationError.missingReferencedFile(filePath)
                    }
                }
            }
        }
    }
}
