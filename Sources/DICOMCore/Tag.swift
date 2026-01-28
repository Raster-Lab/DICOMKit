/// DICOM Data Element Tag
///
/// A tag uniquely identifies a data element and consists of an ordered pair
/// of 16-bit unsigned integers: group number and element number.
///
/// Reference: DICOM PS3.5 Section 7.1 - Data Element Structure
public struct Tag: Sendable, Hashable, Comparable {
    /// Group number (16-bit unsigned integer)
    public let group: UInt16
    
    /// Element number (16-bit unsigned integer)
    public let element: UInt16
    
    /// Creates a new DICOM tag
    /// - Parameters:
    ///   - group: Group number
    ///   - element: Element number
    public init(group: UInt16, element: UInt16) {
        self.group = group
        self.element = element
    }
    
    /// Indicates whether this is a private tag
    ///
    /// Private tags have odd group numbers.
    /// Reference: PS3.5 Section 7.8 - Private Data Elements
    public var isPrivate: Bool {
        return (group & 0x0001) != 0
    }
    
    /// Comparable conformance - tags are ordered by group, then element
    public static func < (lhs: Tag, rhs: Tag) -> Bool {
        if lhs.group != rhs.group {
            return lhs.group < rhs.group
        }
        return lhs.element < rhs.element
    }
}

// MARK: - Common Tags
extension Tag {
    /// File Meta Information Group Length (0002,0000)
    public static let fileMetaInformationGroupLength = Tag(group: 0x0002, element: 0x0000)
    
    /// File Meta Information Version (0002,0001)
    public static let fileMetaInformationVersion = Tag(group: 0x0002, element: 0x0001)
    
    /// Media Storage SOP Class UID (0002,0002)
    public static let mediaStorageSOPClassUID = Tag(group: 0x0002, element: 0x0002)
    
    /// Media Storage SOP Instance UID (0002,0003)
    public static let mediaStorageSOPInstanceUID = Tag(group: 0x0002, element: 0x0003)
    
    /// Transfer Syntax UID (0002,0010)
    public static let transferSyntaxUID = Tag(group: 0x0002, element: 0x0010)
    
    /// Implementation Class UID (0002,0012)
    public static let implementationClassUID = Tag(group: 0x0002, element: 0x0012)
    
    /// Implementation Version Name (0002,0013)
    public static let implementationVersionName = Tag(group: 0x0002, element: 0x0013)
    
    /// SOP Class UID (0008,0016)
    public static let sopClassUID = Tag(group: 0x0008, element: 0x0016)
    
    /// SOP Instance UID (0008,0018)
    public static let sopInstanceUID = Tag(group: 0x0008, element: 0x0018)
    
    /// Study Date (0008,0020)
    public static let studyDate = Tag(group: 0x0008, element: 0x0020)
    
    /// Study Time (0008,0030)
    public static let studyTime = Tag(group: 0x0008, element: 0x0030)
    
    /// Modality (0008,0060)
    public static let modality = Tag(group: 0x0008, element: 0x0060)
    
    /// Patient Name (0010,0010)
    public static let patientName = Tag(group: 0x0010, element: 0x0010)
    
    /// Patient ID (0010,0020)
    public static let patientID = Tag(group: 0x0010, element: 0x0020)
    
    /// Patient Birth Date (0010,0030)
    public static let patientBirthDate = Tag(group: 0x0010, element: 0x0030)
    
    /// Patient Sex (0010,0040)
    public static let patientSex = Tag(group: 0x0010, element: 0x0040)
    
    /// Study Instance UID (0020,000D)
    public static let studyInstanceUID = Tag(group: 0x0020, element: 0x000D)
    
    /// Series Instance UID (0020,000E)
    public static let seriesInstanceUID = Tag(group: 0x0020, element: 0x000E)
    
    /// Study ID (0020,0010)
    public static let studyID = Tag(group: 0x0020, element: 0x0010)
    
    /// Series Number (0020,0011)
    public static let seriesNumber = Tag(group: 0x0020, element: 0x0011)
    
    /// Instance Number (0020,0013)
    public static let instanceNumber = Tag(group: 0x0020, element: 0x0013)
}

// MARK: - CustomStringConvertible
extension Tag: CustomStringConvertible {
    /// Formatted string representation in (GGGG,EEEE) format
    public var description: String {
        return String(format: "(%04X,%04X)", group, element)
    }
}
