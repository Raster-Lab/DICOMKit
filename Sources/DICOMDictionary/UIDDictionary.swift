/// Standard DICOM UID Dictionary
///
/// Provides lookup for standard DICOM UIDs including Transfer Syntaxes and SOP Classes.
/// Reference: DICOM PS3.6 2025e - Registry of DICOM unique identifiers (UIDs)
public struct UIDDictionary {
    
    private static let entries: [String: UIDEntry] = {
        var dict: [String: UIDEntry] = [:]
        
        // Transfer Syntax UIDs
        dict["1.2.840.10008.1.2"] = UIDEntry(
            uid: "1.2.840.10008.1.2",
            name: "Implicit VR Little Endian",
            keyword: "ImplicitVRLittleEndian",
            type: .transferSyntax
        )
        
        dict["1.2.840.10008.1.2.1"] = UIDEntry(
            uid: "1.2.840.10008.1.2.1",
            name: "Explicit VR Little Endian",
            keyword: "ExplicitVRLittleEndian",
            type: .transferSyntax
        )
        
        dict["1.2.840.10008.1.2.2"] = UIDEntry(
            uid: "1.2.840.10008.1.2.2",
            name: "Explicit VR Big Endian",
            keyword: "ExplicitVRBigEndian",
            type: .transferSyntax
        )
        
        // Common SOP Class UIDs
        dict["1.2.840.10008.5.1.4.1.1.2"] = UIDEntry(
            uid: "1.2.840.10008.5.1.4.1.1.2",
            name: "CT Image Storage",
            keyword: "CTImageStorage",
            type: .sopClass
        )
        
        dict["1.2.840.10008.5.1.4.1.1.4"] = UIDEntry(
            uid: "1.2.840.10008.5.1.4.1.1.4",
            name: "MR Image Storage",
            keyword: "MRImageStorage",
            type: .sopClass
        )
        
        dict["1.2.840.10008.5.1.4.1.1.7"] = UIDEntry(
            uid: "1.2.840.10008.5.1.4.1.1.7",
            name: "Secondary Capture Image Storage",
            keyword: "SecondaryCaptureImageStorage",
            type: .sopClass
        )
        
        dict["1.2.840.10008.5.1.4.1.1.1"] = UIDEntry(
            uid: "1.2.840.10008.5.1.4.1.1.1",
            name: "Computed Radiography Image Storage",
            keyword: "ComputedRadiographyImageStorage",
            type: .sopClass
        )
        
        dict["1.2.840.10008.5.1.4.1.1.6.1"] = UIDEntry(
            uid: "1.2.840.10008.5.1.4.1.1.6.1",
            name: "Ultrasound Image Storage",
            keyword: "UltrasoundImageStorage",
            type: .sopClass
        )
        
        dict["1.2.840.10008.5.1.4.1.1.128"] = UIDEntry(
            uid: "1.2.840.10008.5.1.4.1.1.128",
            name: "Positron Emission Tomography Image Storage",
            keyword: "PositronEmissionTomographyImageStorage",
            type: .sopClass
        )
        
        return dict
    }()
    
    /// Looks up a UID entry by UID value
    /// - Parameter uid: The UID to look up
    /// - Returns: The UID entry, or nil if not found
    public static func lookup(uid: String) -> UIDEntry? {
        return entries[uid]
    }
    
    /// Looks up a UID entry by keyword
    /// - Parameter keyword: The keyword to look up
    /// - Returns: The UID entry, or nil if not found
    public static func lookup(keyword: String) -> UIDEntry? {
        return entries.values.first { $0.keyword == keyword }
    }
    
    /// All registered UID entries
    public static var allEntries: [UIDEntry] {
        return Array(entries.values).sorted { $0.uid < $1.uid }
    }
    
    /// Transfer Syntax UIDs only
    public static var transferSyntaxes: [UIDEntry] {
        return entries.values.filter { $0.type == .transferSyntax }.sorted { $0.uid < $1.uid }
    }
    
    /// SOP Class UIDs only
    public static var sopClasses: [UIDEntry] {
        return entries.values.filter { $0.type == .sopClass }.sorted { $0.uid < $1.uid }
    }
}
