import DICOMCore

/// Standard DICOM Data Element Dictionary
///
/// Provides lookup for standard DICOM data elements.
/// This is a minimal v0.1 dictionary with essential tags for File Meta Information
/// and basic Patient/Study/Series level elements.
///
/// Full dictionary from DICOM PS3.6 2025e will be expanded in future versions.
public struct DataElementDictionary {
    
    private static let entries: [Tag: DataElementEntry] = {
        var dict: [Tag: DataElementEntry] = [:]
        
        // File Meta Information elements (Group 0002)
        dict[.fileMetaInformationGroupLength] = DataElementEntry(
            tag: .fileMetaInformationGroupLength,
            name: "File Meta Information Group Length",
            keyword: "FileMetaInformationGroupLength",
            vr: .UL,
            vm: "1"
        )
        
        dict[.fileMetaInformationVersion] = DataElementEntry(
            tag: .fileMetaInformationVersion,
            name: "File Meta Information Version",
            keyword: "FileMetaInformationVersion",
            vr: .OB,
            vm: "1"
        )
        
        dict[.mediaStorageSOPClassUID] = DataElementEntry(
            tag: .mediaStorageSOPClassUID,
            name: "Media Storage SOP Class UID",
            keyword: "MediaStorageSOPClassUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.mediaStorageSOPInstanceUID] = DataElementEntry(
            tag: .mediaStorageSOPInstanceUID,
            name: "Media Storage SOP Instance UID",
            keyword: "MediaStorageSOPInstanceUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.transferSyntaxUID] = DataElementEntry(
            tag: .transferSyntaxUID,
            name: "Transfer Syntax UID",
            keyword: "TransferSyntaxUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.implementationClassUID] = DataElementEntry(
            tag: .implementationClassUID,
            name: "Implementation Class UID",
            keyword: "ImplementationClassUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.implementationVersionName] = DataElementEntry(
            tag: .implementationVersionName,
            name: "Implementation Version Name",
            keyword: "ImplementationVersionName",
            vr: .SH,
            vm: "1"
        )
        
        // Study/Series/Instance level elements
        dict[.sopClassUID] = DataElementEntry(
            tag: .sopClassUID,
            name: "SOP Class UID",
            keyword: "SOPClassUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.sopInstanceUID] = DataElementEntry(
            tag: .sopInstanceUID,
            name: "SOP Instance UID",
            keyword: "SOPInstanceUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.studyDate] = DataElementEntry(
            tag: .studyDate,
            name: "Study Date",
            keyword: "StudyDate",
            vr: .DA,
            vm: "1"
        )
        
        dict[.studyTime] = DataElementEntry(
            tag: .studyTime,
            name: "Study Time",
            keyword: "StudyTime",
            vr: .TM,
            vm: "1"
        )
        
        dict[.modality] = DataElementEntry(
            tag: .modality,
            name: "Modality",
            keyword: "Modality",
            vr: .CS,
            vm: "1"
        )
        
        // Patient level elements
        dict[.patientName] = DataElementEntry(
            tag: .patientName,
            name: "Patient's Name",
            keyword: "PatientName",
            vr: .PN,
            vm: "1"
        )
        
        dict[.patientID] = DataElementEntry(
            tag: .patientID,
            name: "Patient ID",
            keyword: "PatientID",
            vr: .LO,
            vm: "1"
        )
        
        dict[.patientBirthDate] = DataElementEntry(
            tag: .patientBirthDate,
            name: "Patient's Birth Date",
            keyword: "PatientBirthDate",
            vr: .DA,
            vm: "1"
        )
        
        dict[.patientSex] = DataElementEntry(
            tag: .patientSex,
            name: "Patient's Sex",
            keyword: "PatientSex",
            vr: .CS,
            vm: "1"
        )
        
        dict[.studyInstanceUID] = DataElementEntry(
            tag: .studyInstanceUID,
            name: "Study Instance UID",
            keyword: "StudyInstanceUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.seriesInstanceUID] = DataElementEntry(
            tag: .seriesInstanceUID,
            name: "Series Instance UID",
            keyword: "SeriesInstanceUID",
            vr: .UI,
            vm: "1"
        )
        
        dict[.studyID] = DataElementEntry(
            tag: .studyID,
            name: "Study ID",
            keyword: "StudyID",
            vr: .SH,
            vm: "1"
        )
        
        dict[.seriesNumber] = DataElementEntry(
            tag: .seriesNumber,
            name: "Series Number",
            keyword: "SeriesNumber",
            vr: .IS,
            vm: "1"
        )
        
        dict[.instanceNumber] = DataElementEntry(
            tag: .instanceNumber,
            name: "Instance Number",
            keyword: "InstanceNumber",
            vr: .IS,
            vm: "1"
        )
        
        return dict
    }()
    
    /// Looks up a data element entry by tag
    /// - Parameter tag: The tag to look up
    /// - Returns: The dictionary entry, or nil if not found
    public static func lookup(tag: Tag) -> DataElementEntry? {
        return entries[tag]
    }
    
    /// Looks up a data element entry by keyword
    /// - Parameter keyword: The keyword to look up
    /// - Returns: The dictionary entry, or nil if not found
    public static func lookup(keyword: String) -> DataElementEntry? {
        return entries.values.first { $0.keyword == keyword }
    }
    
    /// All registered data element entries
    public static var allEntries: [DataElementEntry] {
        return Array(entries.values).sorted { $0.tag < $1.tag }
    }
}
