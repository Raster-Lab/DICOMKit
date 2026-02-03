import Foundation

// MARK: - QIDO-RS Result Types

/// Protocol for QIDO-RS query results
public protocol QIDOResult {
    /// The raw DICOM JSON attributes
    /// 
    /// This contains the parsed JSON from the QIDO-RS response.
    /// Keys are DICOM tags in GGGGEEEE format, values are DICOM JSON attribute objects.
    var attributes: [String: Any] { get }
    
    /// Creates a result from DICOM JSON attributes
    /// - Parameter attributes: DICOM JSON object
    init(attributes: [String: Any])
    
    /// Gets a string value for a specific tag
    /// - Parameter tag: DICOM tag in GGGGEEEE format
    /// - Returns: String value, or nil if not present
    func string(forTag tag: String) -> String?
    
    /// Gets an array of string values for a specific tag
    /// - Parameter tag: DICOM tag in GGGGEEEE format
    /// - Returns: Array of string values
    func strings(forTag tag: String) -> [String]
    
    /// Gets an integer value for a specific tag
    /// - Parameter tag: DICOM tag in GGGGEEEE format
    /// - Returns: Integer value, or nil if not present
    func integer(forTag tag: String) -> Int?
    
    /// Gets a double value for a specific tag
    /// - Parameter tag: DICOM tag in GGGGEEEE format
    /// - Returns: Double value, or nil if not present
    func double(forTag tag: String) -> Double?
}

// MARK: - Default Implementation

extension QIDOResult {
    /// Extracts the Value array from a DICOM JSON attribute
    private func valueArray(forTag tag: String) -> [Any]? {
        guard let attr = attributes[tag] as? [String: Any],
              let value = attr["Value"] as? [Any] else {
            return nil
        }
        return value
    }
    
    public func string(forTag tag: String) -> String? {
        guard let values = valueArray(forTag: tag), let first = values.first else {
            return nil
        }
        // Handle PersonName which is a nested object with "Alphabetic" key
        if let pnDict = first as? [String: Any],
           let alphabetic = pnDict["Alphabetic"] as? String {
            return alphabetic
        }
        // Handle simple string values
        if let str = first as? String {
            return str
        }
        // Handle numeric values that should be strings
        if let num = first as? NSNumber {
            return num.stringValue
        }
        return nil
    }
    
    public func strings(forTag tag: String) -> [String] {
        guard let values = valueArray(forTag: tag) else {
            return []
        }
        return values.compactMap { value -> String? in
            if let pnDict = value as? [String: Any],
               let alphabetic = pnDict["Alphabetic"] as? String {
                return alphabetic
            }
            if let str = value as? String {
                return str
            }
            if let num = value as? NSNumber {
                return num.stringValue
            }
            return nil
        }
    }
    
    public func integer(forTag tag: String) -> Int? {
        guard let values = valueArray(forTag: tag), let first = values.first else {
            return nil
        }
        if let num = first as? NSNumber {
            return num.intValue
        }
        if let str = first as? String {
            return Int(str)
        }
        return nil
    }
    
    public func double(forTag tag: String) -> Double? {
        guard let values = valueArray(forTag: tag), let first = values.first else {
            return nil
        }
        if let num = first as? NSNumber {
            return num.doubleValue
        }
        if let str = first as? String {
            return Double(str)
        }
        return nil
    }
}

// MARK: - QIDOStudyResult

/// Result from a QIDO-RS study query
public struct QIDOStudyResult: QIDOResult {
    /// The raw DICOM JSON attributes
    public let attributes: [String: Any]
    
    /// Creates a study result from DICOM JSON attributes
    /// - Parameter attributes: DICOM JSON object
    public init(attributes: [String: Any]) {
        self.attributes = attributes
    }
    
    // MARK: - Study Level Attributes
    
    /// Study Instance UID (0020,000D)
    public var studyInstanceUID: String? {
        return string(forTag: QIDOQueryAttribute.studyInstanceUID)
    }
    
    /// Study Date (0008,0020)
    public var studyDate: String? {
        return string(forTag: QIDOQueryAttribute.studyDate)
    }
    
    /// Study Time (0008,0030)
    public var studyTime: String? {
        return string(forTag: QIDOQueryAttribute.studyTime)
    }
    
    /// Study Description (0008,1030)
    public var studyDescription: String? {
        return string(forTag: QIDOQueryAttribute.studyDescription)
    }
    
    /// Accession Number (0008,0050)
    public var accessionNumber: String? {
        return string(forTag: QIDOQueryAttribute.accessionNumber)
    }
    
    /// Study ID (0020,0010)
    public var studyID: String? {
        return string(forTag: QIDOQueryAttribute.studyID)
    }
    
    /// Referring Physician's Name (0008,0090)
    public var referringPhysicianName: String? {
        return string(forTag: QIDOQueryAttribute.referringPhysicianName)
    }
    
    /// Number of Study Related Series (0020,1206)
    public var numberOfStudyRelatedSeries: Int? {
        return integer(forTag: QIDOQueryAttribute.numberOfStudyRelatedSeries)
    }
    
    /// Number of Study Related Instances (0020,1208)
    public var numberOfStudyRelatedInstances: Int? {
        return integer(forTag: QIDOQueryAttribute.numberOfStudyRelatedInstances)
    }
    
    /// Modalities in Study (0008,0061)
    public var modalitiesInStudy: [String] {
        return strings(forTag: "00080061")
    }
    
    // MARK: - Patient Level Attributes
    
    /// Patient Name (0010,0010)
    public var patientName: String? {
        return string(forTag: QIDOQueryAttribute.patientName)
    }
    
    /// Patient ID (0010,0020)
    public var patientID: String? {
        return string(forTag: QIDOQueryAttribute.patientID)
    }
    
    /// Patient Birth Date (0010,0030)
    public var patientBirthDate: String? {
        return string(forTag: QIDOQueryAttribute.patientBirthDate)
    }
    
    /// Patient Sex (0010,0040)
    public var patientSex: String? {
        return string(forTag: QIDOQueryAttribute.patientSex)
    }
}

// MARK: - QIDOSeriesResult

/// Result from a QIDO-RS series query
public struct QIDOSeriesResult: QIDOResult {
    /// The raw DICOM JSON attributes
    public let attributes: [String: Any]
    
    /// Creates a series result from DICOM JSON attributes
    /// - Parameter attributes: DICOM JSON object
    public init(attributes: [String: Any]) {
        self.attributes = attributes
    }
    
    // MARK: - Series Level Attributes
    
    /// Series Instance UID (0020,000E)
    public var seriesInstanceUID: String? {
        return string(forTag: QIDOQueryAttribute.seriesInstanceUID)
    }
    
    /// Series Number (0020,0011)
    public var seriesNumber: Int? {
        return integer(forTag: QIDOQueryAttribute.seriesNumber)
    }
    
    /// Series Description (0008,103E)
    public var seriesDescription: String? {
        return string(forTag: QIDOQueryAttribute.seriesDescription)
    }
    
    /// Modality (0008,0060)
    public var modality: String? {
        return string(forTag: QIDOQueryAttribute.modality)
    }
    
    /// Body Part Examined (0018,0015)
    public var bodyPartExamined: String? {
        return string(forTag: QIDOQueryAttribute.bodyPartExamined)
    }
    
    /// Performed Procedure Step Start Date (0040,0244)
    public var performedProcedureStepStartDate: String? {
        return string(forTag: QIDOQueryAttribute.performedProcedureStepStartDate)
    }
    
    /// Number of Series Related Instances (0020,1209)
    public var numberOfSeriesRelatedInstances: Int? {
        return integer(forTag: QIDOQueryAttribute.numberOfSeriesRelatedInstances)
    }
    
    // MARK: - Parent Study Attributes
    
    /// Study Instance UID (0020,000D) of the parent study
    public var studyInstanceUID: String? {
        return string(forTag: QIDOQueryAttribute.studyInstanceUID)
    }
}

// MARK: - QIDOInstanceResult

/// Result from a QIDO-RS instance query
public struct QIDOInstanceResult: QIDOResult {
    /// The raw DICOM JSON attributes
    public let attributes: [String: Any]
    
    /// Creates an instance result from DICOM JSON attributes
    /// - Parameter attributes: DICOM JSON object
    public init(attributes: [String: Any]) {
        self.attributes = attributes
    }
    
    // MARK: - Instance Level Attributes
    
    /// SOP Instance UID (0008,0018)
    public var sopInstanceUID: String? {
        return string(forTag: QIDOQueryAttribute.sopInstanceUID)
    }
    
    /// SOP Class UID (0008,0016)
    public var sopClassUID: String? {
        return string(forTag: QIDOQueryAttribute.sopClassUID)
    }
    
    /// Instance Number (0020,0013)
    public var instanceNumber: Int? {
        return integer(forTag: QIDOQueryAttribute.instanceNumber)
    }
    
    /// Number of Frames (0028,0008)
    public var numberOfFrames: Int? {
        return integer(forTag: QIDOQueryAttribute.numberOfFrames)
    }
    
    /// Rows (0028,0010)
    public var rows: Int? {
        return integer(forTag: QIDOQueryAttribute.rows)
    }
    
    /// Columns (0028,0011)
    public var columns: Int? {
        return integer(forTag: QIDOQueryAttribute.columns)
    }
    
    // MARK: - Parent Series/Study Attributes
    
    /// Series Instance UID (0020,000E) of the parent series
    public var seriesInstanceUID: String? {
        return string(forTag: QIDOQueryAttribute.seriesInstanceUID)
    }
    
    /// Study Instance UID (0020,000D) of the parent study
    public var studyInstanceUID: String? {
        return string(forTag: QIDOQueryAttribute.studyInstanceUID)
    }
}

// MARK: - QIDOResults Container

/// Container for QIDO-RS query results with pagination info
public struct QIDOResults<T: QIDOResult> {
    /// The query results
    public let results: [T]
    
    /// Total number of matching results (if provided by server)
    public let totalCount: Int?
    
    /// Whether there are more results available
    public let hasMore: Bool
    
    /// Offset to use for the next page (if hasMore is true)
    public let nextOffset: Int?
    
    /// Number of results returned
    public var count: Int {
        return results.count
    }
    
    /// Whether the results are empty
    public var isEmpty: Bool {
        return results.isEmpty
    }
    
    /// Creates a results container
    ///
    /// - Parameters:
    ///   - results: Array of query results
    ///   - totalCount: Total count from server (from X-Total-Count header)
    ///   - offset: Current offset used in query
    ///   - limit: Limit used in query
    public init(
        results: [T],
        totalCount: Int? = nil,
        offset: Int = 0,
        limit: Int? = nil
    ) {
        self.results = results
        self.totalCount = totalCount
        
        // Determine if there are more results
        if let total = totalCount {
            self.hasMore = (offset + results.count) < total
            self.nextOffset = self.hasMore ? offset + results.count : nil
        } else if let limit = limit, results.count >= limit {
            // If we got as many results as the limit, there might be more
            self.hasMore = true
            self.nextOffset = offset + results.count
        } else {
            self.hasMore = false
            self.nextOffset = nil
        }
    }
}

// MARK: - Type Aliases for Convenience

/// Results from a study search
public typealias QIDOStudyResults = QIDOResults<QIDOStudyResult>

/// Results from a series search
public typealias QIDOSeriesResults = QIDOResults<QIDOSeriesResult>

/// Results from an instance search
public typealias QIDOInstanceResults = QIDOResults<QIDOInstanceResult>

// MARK: - Equatable Conformance

extension QIDOStudyResult: Equatable {
    public static func == (lhs: QIDOStudyResult, rhs: QIDOStudyResult) -> Bool {
        // Compare by Study Instance UID since it's unique
        return lhs.studyInstanceUID == rhs.studyInstanceUID
    }
}

extension QIDOSeriesResult: Equatable {
    public static func == (lhs: QIDOSeriesResult, rhs: QIDOSeriesResult) -> Bool {
        // Compare by Series Instance UID since it's unique
        return lhs.seriesInstanceUID == rhs.seriesInstanceUID
    }
}

extension QIDOInstanceResult: Equatable {
    public static func == (lhs: QIDOInstanceResult, rhs: QIDOInstanceResult) -> Bool {
        // Compare by SOP Instance UID since it's unique
        return lhs.sopInstanceUID == rhs.sopInstanceUID
    }
}

// MARK: - Hashable Conformance

extension QIDOStudyResult: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(studyInstanceUID)
    }
}

extension QIDOSeriesResult: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(seriesInstanceUID)
    }
}

extension QIDOInstanceResult: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sopInstanceUID)
    }
}
