import Foundation

/// Directory Record Type
///
/// Defines the type of directory record in a DICOMDIR structure.
/// Reference: DICOM PS3.3 F.5 - Media Storage Directory SOP Class
public enum DirectoryRecordType: String, Sendable, Codable {
    /// Root of the directory hierarchy
    case root = "ROOT"
    
    /// Patient-level record
    case patient = "PATIENT"
    
    /// Study-level record
    case study = "STUDY"
    
    /// Series-level record
    case series = "SERIES"
    
    /// Image-level record (CT, MR, etc.)
    case image = "IMAGE"
    
    /// Overlay-level record
    case overlay = "OVERLAY"
    
    /// Modality LUT-level record
    case modalityLUT = "MODALITY LUT"
    
    /// VOI LUT-level record
    case voiLUT = "VOI LUT"
    
    /// Curve-level record
    case curve = "CURVE"
    
    /// Topic-level record (for Structured Reporting)
    case topic = "TOPIC"
    
    /// Visit-level record
    case visit = "VISIT"
    
    /// Results-level record
    case results = "RESULTS"
    
    /// Interpretation-level record
    case interpretation = "INTERPRETATION"
    
    /// Study Component-level record
    case studyComponent = "STUDY COMPONENT"
    
    /// Stored Print-level record
    case storedPrint = "STORED PRINT"
    
    /// RT Dose-level record
    case rtDose = "RT DOSE"
    
    /// RT Structure Set-level record
    case rtStructureSet = "RT STRUCTURE SET"
    
    /// RT Plan-level record
    case rtPlan = "RT PLAN"
    
    /// RT Treat Record-level record
    case rtTreatRecord = "RT TREAT RECORD"
    
    /// Presentation-level record
    case presentation = "PRESENTATION"
    
    /// Waveform-level record
    case waveform = "WAVEFORM"
    
    /// SR Document-level record
    case srDocument = "SR DOCUMENT"
    
    /// Key Object Document-level record
    case keyObjectDoc = "KEY OBJECT DOC"
    
    /// Spectroscopy-level record
    case spectroscopy = "SPECTROSCOPY"
    
    /// Raw Data-level record
    case rawData = "RAW DATA"
    
    /// Registration-level record
    case registration = "REGISTRATION"
    
    /// Fiducial-level record
    case fiducial = "FIDUCIAL"
    
    /// Hanging Protocol-level record
    case hangingProtocol = "HANGING PROTOCOL"
    
    /// Encapsulated Document-level record
    case encapsulatedDocument = "ENCAP DOC"
    
    /// HL7 Structured Document-level record
    case hl7StructuredDocument = "HL7 STRUC DOC"
    
    /// Value Map-level record
    case valueMap = "VALUE MAP"
    
    /// Stereometric Relationship-level record
    case stereometricRelationship = "STEREOMETRIC"
    
    /// Palette-level record
    case palette = "PALETTE"
    
    /// Surface-level record
    case surface = "SURFACE"
    
    /// Measurement-level record
    case measurement = "MEASUREMENT"
    
    /// Implant-level record
    case implant = "IMPLANT"
    
    /// Implant Group-level record
    case implantGroup = "IMPLANT GROUP"
    
    /// Implant Assy-level record
    case implantAssy = "IMPLANT ASSY"
    
    /// Surface Scan-level record
    case surfaceScan = "SURFACE SCAN"
    
    /// Private record type
    case `private` = "PRIVATE"
}

/// Directory Record
///
/// Represents a single record in a DICOMDIR directory structure.
/// Reference: DICOM PS3.3 F.5 - Media Storage Directory SOP Class
public struct DirectoryRecord: Sendable {
    /// Type of directory record
    public var recordType: DirectoryRecordType
    
    /// Reference to the file (for IMAGE, etc. records)
    public var referencedFileID: [String]?
    
    /// Referenced SOP Class UID
    public var referencedSOPClassUID: String?
    
    /// Referenced SOP Instance UID
    public var referencedSOPInstanceUID: String?
    
    /// Referenced Transfer Syntax UID
    public var referencedTransferSyntaxUID: String?
    
    /// Record is active (in-use flag)
    public var isActive: Bool
    
    /// Offset to next record at same level (used during serialization)
    public var offsetToNext: UInt32?
    
    /// Offset to first child record (used during serialization)
    public var offsetToLowerLevel: UInt32?
    
    /// Additional attributes specific to this record type
    /// These are the actual DICOM data elements for this record
    public var attributes: [Tag: DataElement]
    
    /// Child records
    public var children: [DirectoryRecord]
    
    /// Initialize a new directory record
    ///
    /// - Parameters:
    ///   - recordType: Type of directory record
    ///   - referencedFileID: Path components to referenced file (optional)
    ///   - referencedSOPClassUID: SOP Class UID (optional)
    ///   - referencedSOPInstanceUID: SOP Instance UID (optional)
    ///   - referencedTransferSyntaxUID: Transfer Syntax UID (optional)
    ///   - isActive: Whether record is active (default: true)
    ///   - attributes: Additional DICOM attributes (default: empty)
    ///   - children: Child records (default: empty)
    public init(
        recordType: DirectoryRecordType,
        referencedFileID: [String]? = nil,
        referencedSOPClassUID: String? = nil,
        referencedSOPInstanceUID: String? = nil,
        referencedTransferSyntaxUID: String? = nil,
        isActive: Bool = true,
        attributes: [Tag: DataElement] = [:],
        children: [DirectoryRecord] = []
    ) {
        self.recordType = recordType
        self.referencedFileID = referencedFileID
        self.referencedSOPClassUID = referencedSOPClassUID
        self.referencedSOPInstanceUID = referencedSOPInstanceUID
        self.referencedTransferSyntaxUID = referencedTransferSyntaxUID
        self.isActive = isActive
        self.attributes = attributes
        self.children = children
    }
    
    /// Get attribute value for a specific tag
    ///
    /// - Parameter tag: The DICOM tag to retrieve
    /// - Returns: The data element if present
    public func attribute(for tag: Tag) -> DataElement? {
        return attributes[tag]
    }
    
    /// Set attribute value for a specific tag
    ///
    /// - Parameters:
    ///   - element: The data element to set
    ///   - tag: The DICOM tag
    public mutating func setAttribute(_ element: DataElement, for tag: Tag) {
        attributes[tag] = element
    }
    
    /// Add a child record
    ///
    /// - Parameter child: The child directory record to add
    public mutating func addChild(_ child: DirectoryRecord) {
        children.append(child)
    }
    
    /// Remove all child records
    public mutating func removeAllChildren() {
        children.removeAll()
    }
    
    /// Get the referenced file path (joined components)
    ///
    /// - Returns: The file path as a string, or nil if no file reference
    public func referencedFilePath() -> String? {
        guard let fileID = referencedFileID, !fileID.isEmpty else {
            return nil
        }
        return fileID.joined(separator: "/")
    }
}

// MARK: - Convenience Initializers

extension DirectoryRecord {
    /// Create a patient-level directory record
    ///
    /// - Parameters:
    ///   - patientID: Patient ID
    ///   - patientName: Patient name
    ///   - children: Child study records
    /// - Returns: A new patient directory record
    public static func patient(
        patientID: String,
        patientName: String,
        children: [DirectoryRecord] = []
    ) -> DirectoryRecord {
        var attributes: [Tag: DataElement] = [:]
        attributes[.patientID] = DataElement.string(tag: .patientID, vr: .LO, value: patientID)
        attributes[.patientName] = DataElement.string(tag: .patientName, vr: .PN, value: patientName)
        
        return DirectoryRecord(
            recordType: .patient,
            attributes: attributes,
            children: children
        )
    }
    
    /// Create a study-level directory record
    ///
    /// - Parameters:
    ///   - studyInstanceUID: Study Instance UID
    ///   - studyDate: Study date (optional)
    ///   - studyTime: Study time (optional)
    ///   - studyDescription: Study description (optional)
    ///   - children: Child series records
    /// - Returns: A new study directory record
    public static func study(
        studyInstanceUID: String,
        studyDate: String? = nil,
        studyTime: String? = nil,
        studyDescription: String? = nil,
        children: [DirectoryRecord] = []
    ) -> DirectoryRecord {
        var attributes: [Tag: DataElement] = [:]
        attributes[.studyInstanceUID] = DataElement.string(tag: .studyInstanceUID, vr: .UI, value: studyInstanceUID)
        
        if let date = studyDate {
            attributes[.studyDate] = DataElement.string(tag: .studyDate, vr: .DA, value: date)
        }
        
        if let time = studyTime {
            attributes[.studyTime] = DataElement.string(tag: .studyTime, vr: .TM, value: time)
        }
        
        if let description = studyDescription {
            attributes[.studyDescription] = DataElement.string(tag: .studyDescription, vr: .LO, value: description)
        }
        
        return DirectoryRecord(
            recordType: .study,
            attributes: attributes,
            children: children
        )
    }
    
    /// Create a series-level directory record
    ///
    /// - Parameters:
    ///   - seriesInstanceUID: Series Instance UID
    ///   - modality: Modality (e.g., "CT", "MR")
    ///   - seriesNumber: Series number (optional)
    ///   - seriesDescription: Series description (optional)
    ///   - children: Child image records
    /// - Returns: A new series directory record
    public static func series(
        seriesInstanceUID: String,
        modality: String,
        seriesNumber: String? = nil,
        seriesDescription: String? = nil,
        children: [DirectoryRecord] = []
    ) -> DirectoryRecord {
        var attributes: [Tag: DataElement] = [:]
        attributes[.seriesInstanceUID] = DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: seriesInstanceUID)
        attributes[.modality] = DataElement.string(tag: .modality, vr: .CS, value: modality)
        
        if let number = seriesNumber {
            attributes[.seriesNumber] = DataElement.string(tag: .seriesNumber, vr: .IS, value: number)
        }
        
        if let description = seriesDescription {
            attributes[.seriesDescription] = DataElement.string(tag: .seriesDescription, vr: .LO, value: description)
        }
        
        return DirectoryRecord(
            recordType: .series,
            attributes: attributes,
            children: children
        )
    }
    
    /// Create an image-level directory record
    ///
    /// - Parameters:
    ///   - referencedFileID: Path components to the image file
    ///   - sopClassUID: SOP Class UID
    ///   - sopInstanceUID: SOP Instance UID
    ///   - transferSyntaxUID: Transfer Syntax UID
    ///   - instanceNumber: Instance number (optional)
    /// - Returns: A new image directory record
    public static func image(
        referencedFileID: [String],
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String,
        instanceNumber: String? = nil
    ) -> DirectoryRecord {
        var attributes: [Tag: DataElement] = [:]
        
        if let number = instanceNumber {
            attributes[.instanceNumber] = DataElement.string(tag: .instanceNumber, vr: .IS, value: number)
        }
        
        return DirectoryRecord(
            recordType: .image,
            referencedFileID: referencedFileID,
            referencedSOPClassUID: sopClassUID,
            referencedSOPInstanceUID: sopInstanceUID,
            referencedTransferSyntaxUID: transferSyntaxUID,
            attributes: attributes
        )
    }
}

// MARK: - CustomStringConvertible

extension DirectoryRecord: CustomStringConvertible {
    public var description: String {
        var desc = "DirectoryRecord(type: \(recordType.rawValue)"
        
        if let fileID = referencedFileID {
            desc += ", file: \(fileID.joined(separator: "/"))"
        }
        
        if let sopClass = referencedSOPClassUID {
            desc += ", sopClass: \(sopClass)"
        }
        
        if !children.isEmpty {
            desc += ", children: \(children.count)"
        }
        
        desc += ")"
        return desc
    }
}
