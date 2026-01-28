import DICOMCore

/// Data Element Dictionary Entry
///
/// Represents a standard DICOM data element definition from the Data Element Dictionary.
/// Reference: DICOM PS3.6 - Data Dictionary
public struct DataElementEntry: Sendable, Hashable {
    /// Data element tag
    public let tag: Tag
    
    /// Human-readable name
    public let name: String
    
    /// Keyword identifier
    public let keyword: String
    
    /// Value Representation(s) - some elements support multiple VRs
    public let vr: [VR]
    
    /// Value Multiplicity (e.g., "1", "1-n", "3", "1-3")
    public let vm: String
    
    /// Indicates if this element is retired
    public let retired: Bool
    
    /// Creates a data element entry
    /// - Parameters:
    ///   - tag: Data element tag
    ///   - name: Human-readable name
    ///   - keyword: Keyword identifier
    ///   - vr: Value Representation(s)
    ///   - vm: Value Multiplicity
    ///   - retired: Whether this element is retired
    public init(tag: Tag, name: String, keyword: String, vr: [VR], vm: String, retired: Bool = false) {
        self.tag = tag
        self.name = name
        self.keyword = keyword
        self.vr = vr
        self.vm = vm
        self.retired = retired
    }
    
    /// Convenience initializer for single VR elements
    public init(tag: Tag, name: String, keyword: String, vr: VR, vm: String, retired: Bool = false) {
        self.init(tag: tag, name: name, keyword: keyword, vr: [vr], vm: vm, retired: retired)
    }
}

/// UID Dictionary Entry
///
/// Represents a standard DICOM UID definition.
/// Reference: DICOM PS3.6 - Registry of DICOM unique identifiers (UIDs)
public struct UIDEntry: Sendable, Hashable {
    /// UID value
    public let uid: String
    
    /// Human-readable name
    public let name: String
    
    /// Keyword identifier
    public let keyword: String
    
    /// UID type classification
    public let type: UIDType
    
    /// Creates a UID entry
    /// - Parameters:
    ///   - uid: UID value
    ///   - name: Human-readable name
    ///   - keyword: Keyword identifier
    ///   - type: UID type
    public init(uid: String, name: String, keyword: String, type: UIDType) {
        self.uid = uid
        self.name = name
        self.keyword = keyword
        self.type = type
    }
}

/// UID Type Classification
public enum UIDType: Sendable, Hashable {
    /// Transfer Syntax UID
    case transferSyntax
    
    /// SOP Class UID
    case sopClass
    
    /// Meta SOP Class UID
    case metaSOPClass
    
    /// Well-known UID
    case wellKnown
    
    /// LDAP OID
    case ldap
    
    /// Coding Scheme
    case codingScheme
    
    /// Application Context Name
    case applicationContext
}
