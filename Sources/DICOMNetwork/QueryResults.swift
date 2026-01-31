import Foundation
import DICOMCore

// MARK: - Base Query Result Protocol

/// Protocol for DICOM query results
public protocol QueryResult: Sendable, Hashable {
    /// The raw response data containing all returned attributes
    var attributes: [Tag: Data] { get }
    
    /// Gets a string value for a tag
    func string(for tag: Tag) -> String?
    
    /// Gets a UID value for a tag
    func uid(for tag: Tag) -> String?
    
    /// Gets an integer value for a tag
    func integer(for tag: Tag) -> Int?
}

// MARK: - Default Implementation

extension QueryResult {
    /// Gets a string value for a tag
    public func string(for tag: Tag) -> String? {
        guard let data = attributes[tag] else { return nil }
        let string = String(data: data, encoding: .utf8) ??
                     String(data: data, encoding: .ascii) ?? ""
        return string.trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
    }
    
    /// Gets a UID value for a tag (same as string but semantically distinct)
    public func uid(for tag: Tag) -> String? {
        string(for: tag)
    }
    
    /// Gets an integer value for a tag (parsing IS VR)
    public func integer(for tag: Tag) -> Int? {
        guard let string = string(for: tag) else { return nil }
        return Int(string.trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Patient Query Result

/// Result from a patient-level C-FIND query
public struct PatientResult: QueryResult, Sendable, Hashable {
    /// The raw response attributes
    public let attributes: [Tag: Data]
    
    /// Creates a patient result from raw attributes
    public init(attributes: [Tag: Data]) {
        self.attributes = attributes
    }
    
    // MARK: - Typed Accessors
    
    /// Patient's Name
    public var patientName: String? {
        string(for: .patientName)
    }
    
    /// Patient ID
    public var patientID: String? {
        string(for: .patientID)
    }
    
    /// Patient's Birth Date (YYYYMMDD format)
    public var patientBirthDate: String? {
        string(for: .patientBirthDate)
    }
    
    /// Patient's Sex (M, F, O)
    public var patientSex: String? {
        string(for: .patientSex)
    }
    
    /// Number of Patient Related Studies
    public var numberOfPatientRelatedStudies: Int? {
        integer(for: .numberOfPatientRelatedStudies)
    }
    
    /// Number of Patient Related Series
    public var numberOfPatientRelatedSeries: Int? {
        integer(for: .numberOfPatientRelatedSeries)
    }
    
    /// Number of Patient Related Instances
    public var numberOfPatientRelatedInstances: Int? {
        integer(for: .numberOfPatientRelatedInstances)
    }
}

// MARK: - CustomStringConvertible

extension PatientResult: CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["PatientResult:"]
        if let name = patientName {
            parts.append("  Name: \(name)")
        }
        if let id = patientID {
            parts.append("  ID: \(id)")
        }
        if let dob = patientBirthDate {
            parts.append("  Birth Date: \(dob)")
        }
        if let sex = patientSex {
            parts.append("  Sex: \(sex)")
        }
        if let studies = numberOfPatientRelatedStudies {
            parts.append("  Related Studies: \(studies)")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Study Query Result

/// Result from a study-level C-FIND query
public struct StudyResult: QueryResult, Sendable, Hashable {
    /// The raw response attributes
    public let attributes: [Tag: Data]
    
    /// Creates a study result from raw attributes
    public init(attributes: [Tag: Data]) {
        self.attributes = attributes
    }
    
    // MARK: - Typed Accessors
    
    /// Study Instance UID
    public var studyInstanceUID: String? {
        uid(for: .studyInstanceUID)
    }
    
    /// Study Date (YYYYMMDD format)
    public var studyDate: String? {
        string(for: .studyDate)
    }
    
    /// Study Time (HHMMSS format)
    public var studyTime: String? {
        string(for: .studyTime)
    }
    
    /// Study Description
    public var studyDescription: String? {
        string(for: .studyDescription)
    }
    
    /// Accession Number
    public var accessionNumber: String? {
        string(for: .accessionNumber)
    }
    
    /// Study ID
    public var studyID: String? {
        string(for: .studyID)
    }
    
    /// Patient's Name
    public var patientName: String? {
        string(for: .patientName)
    }
    
    /// Patient ID
    public var patientID: String? {
        string(for: .patientID)
    }
    
    /// Patient's Birth Date
    public var patientBirthDate: String? {
        string(for: .patientBirthDate)
    }
    
    /// Referring Physician's Name
    public var referringPhysicianName: String? {
        string(for: .referringPhysicianName)
    }
    
    /// Modalities in Study (backslash-separated list)
    public var modalitiesInStudy: String? {
        string(for: .modalitiesInStudy)
    }
    
    /// Modalities in Study as an array
    public var modalities: [String] {
        guard let value = modalitiesInStudy else { return [] }
        return value.split(separator: "\\").map { String($0) }
    }
    
    /// Number of Study Related Series
    public var numberOfStudyRelatedSeries: Int? {
        integer(for: .numberOfStudyRelatedSeries)
    }
    
    /// Number of Study Related Instances
    public var numberOfStudyRelatedInstances: Int? {
        integer(for: .numberOfStudyRelatedInstances)
    }
}

// MARK: - CustomStringConvertible

extension StudyResult: CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["StudyResult:"]
        if let uid = studyInstanceUID {
            parts.append("  Study UID: \(uid)")
        }
        if let date = studyDate {
            parts.append("  Date: \(date)")
        }
        if let desc = studyDescription {
            parts.append("  Description: \(desc)")
        }
        if let accession = accessionNumber {
            parts.append("  Accession: \(accession)")
        }
        if let patient = patientName {
            parts.append("  Patient: \(patient)")
        }
        if let series = numberOfStudyRelatedSeries {
            parts.append("  Series Count: \(series)")
        }
        if let instances = numberOfStudyRelatedInstances {
            parts.append("  Instance Count: \(instances)")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Series Query Result

/// Result from a series-level C-FIND query
public struct SeriesResult: QueryResult, Sendable, Hashable {
    /// The raw response attributes
    public let attributes: [Tag: Data]
    
    /// Creates a series result from raw attributes
    public init(attributes: [Tag: Data]) {
        self.attributes = attributes
    }
    
    // MARK: - Typed Accessors
    
    /// Series Instance UID
    public var seriesInstanceUID: String? {
        uid(for: .seriesInstanceUID)
    }
    
    /// Series Number
    public var seriesNumber: Int? {
        integer(for: .seriesNumber)
    }
    
    /// Series Description
    public var seriesDescription: String? {
        string(for: .seriesDescription)
    }
    
    /// Modality (CT, MR, US, etc.)
    public var modality: String? {
        string(for: .modality)
    }
    
    /// Series Date
    public var seriesDate: String? {
        string(for: .seriesDate)
    }
    
    /// Series Time
    public var seriesTime: String? {
        string(for: .seriesTime)
    }
    
    /// Body Part Examined
    public var bodyPartExamined: String? {
        string(for: .bodyPartExamined)
    }
    
    /// Number of Series Related Instances
    public var numberOfSeriesRelatedInstances: Int? {
        integer(for: .numberOfSeriesRelatedInstances)
    }
    
    /// Study Instance UID (if returned)
    public var studyInstanceUID: String? {
        uid(for: .studyInstanceUID)
    }
}

// MARK: - CustomStringConvertible

extension SeriesResult: CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["SeriesResult:"]
        if let uid = seriesInstanceUID {
            parts.append("  Series UID: \(uid)")
        }
        if let number = seriesNumber {
            parts.append("  Number: \(number)")
        }
        if let modality = modality {
            parts.append("  Modality: \(modality)")
        }
        if let desc = seriesDescription {
            parts.append("  Description: \(desc)")
        }
        if let instances = numberOfSeriesRelatedInstances {
            parts.append("  Instance Count: \(instances)")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Instance Query Result

/// Result from an instance-level C-FIND query
public struct InstanceResult: QueryResult, Sendable, Hashable {
    /// The raw response attributes
    public let attributes: [Tag: Data]
    
    /// Creates an instance result from raw attributes
    public init(attributes: [Tag: Data]) {
        self.attributes = attributes
    }
    
    // MARK: - Typed Accessors
    
    /// SOP Instance UID
    public var sopInstanceUID: String? {
        uid(for: .sopInstanceUID)
    }
    
    /// SOP Class UID
    public var sopClassUID: String? {
        uid(for: .sopClassUID)
    }
    
    /// Instance Number
    public var instanceNumber: Int? {
        integer(for: .instanceNumber)
    }
    
    /// Content Date
    public var contentDate: String? {
        string(for: .contentDate)
    }
    
    /// Content Time
    public var contentTime: String? {
        string(for: .contentTime)
    }
    
    /// Image Rows
    public var rows: Int? {
        integer(for: .rows)
    }
    
    /// Image Columns
    public var columns: Int? {
        integer(for: .columns)
    }
    
    /// Number of Frames
    public var numberOfFrames: Int? {
        integer(for: .numberOfFrames)
    }
    
    /// Series Instance UID (if returned)
    public var seriesInstanceUID: String? {
        uid(for: .seriesInstanceUID)
    }
    
    /// Study Instance UID (if returned)
    public var studyInstanceUID: String? {
        uid(for: .studyInstanceUID)
    }
}

// MARK: - CustomStringConvertible

extension InstanceResult: CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["InstanceResult:"]
        if let uid = sopInstanceUID {
            parts.append("  SOP Instance UID: \(uid)")
        }
        if let sopClass = sopClassUID {
            parts.append("  SOP Class: \(sopClass)")
        }
        if let number = instanceNumber {
            parts.append("  Instance Number: \(number)")
        }
        if let rows = rows, let cols = columns {
            parts.append("  Dimensions: \(cols)x\(rows)")
        }
        if let frames = numberOfFrames {
            parts.append("  Frames: \(frames)")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Generic Query Response

/// A generic C-FIND response with raw attributes
///
/// Used when the specific result type is not known or for custom queries.
public struct GenericQueryResult: QueryResult, Sendable, Hashable {
    /// The raw response attributes
    public let attributes: [Tag: Data]
    
    /// The query level from the response
    public let level: QueryLevel?
    
    /// Creates a generic result from raw attributes
    public init(attributes: [Tag: Data], level: QueryLevel? = nil) {
        self.attributes = attributes
        self.level = level
    }
    
    /// Converts to a PatientResult
    public func toPatientResult() -> PatientResult {
        PatientResult(attributes: attributes)
    }
    
    /// Converts to a StudyResult
    public func toStudyResult() -> StudyResult {
        StudyResult(attributes: attributes)
    }
    
    /// Converts to a SeriesResult
    public func toSeriesResult() -> SeriesResult {
        SeriesResult(attributes: attributes)
    }
    
    /// Converts to an InstanceResult
    public func toInstanceResult() -> InstanceResult {
        InstanceResult(attributes: attributes)
    }
}
