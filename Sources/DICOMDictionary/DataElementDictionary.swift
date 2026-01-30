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
        
        // Additional elements commonly needed for Implicit VR parsing
        // Image Information elements
        dict[.specificCharacterSet] = DataElementEntry(
            tag: .specificCharacterSet,
            name: "Specific Character Set",
            keyword: "SpecificCharacterSet",
            vr: .CS,
            vm: "1-n"
        )
        
        dict[.imageType] = DataElementEntry(
            tag: .imageType,
            name: "Image Type",
            keyword: "ImageType",
            vr: .CS,
            vm: "2-n"
        )
        
        dict[.instanceCreationDate] = DataElementEntry(
            tag: .instanceCreationDate,
            name: "Instance Creation Date",
            keyword: "InstanceCreationDate",
            vr: .DA,
            vm: "1"
        )
        
        dict[.instanceCreationTime] = DataElementEntry(
            tag: .instanceCreationTime,
            name: "Instance Creation Time",
            keyword: "InstanceCreationTime",
            vr: .TM,
            vm: "1"
        )
        
        dict[.acquisitionDate] = DataElementEntry(
            tag: .acquisitionDate,
            name: "Acquisition Date",
            keyword: "AcquisitionDate",
            vr: .DA,
            vm: "1"
        )
        
        dict[.contentDate] = DataElementEntry(
            tag: .contentDate,
            name: "Content Date",
            keyword: "ContentDate",
            vr: .DA,
            vm: "1"
        )
        
        dict[.acquisitionTime] = DataElementEntry(
            tag: .acquisitionTime,
            name: "Acquisition Time",
            keyword: "AcquisitionTime",
            vr: .TM,
            vm: "1"
        )
        
        dict[.contentTime] = DataElementEntry(
            tag: .contentTime,
            name: "Content Time",
            keyword: "ContentTime",
            vr: .TM,
            vm: "1"
        )
        
        // Study Description
        dict[.studyDescription] = DataElementEntry(
            tag: .studyDescription,
            name: "Study Description",
            keyword: "StudyDescription",
            vr: .LO,
            vm: "1"
        )
        
        // Series Description
        dict[.seriesDescription] = DataElementEntry(
            tag: .seriesDescription,
            name: "Series Description",
            keyword: "SeriesDescription",
            vr: .LO,
            vm: "1"
        )
        
        // Image Pixel Module elements (essential for image data)
        dict[.samplesPerPixel] = DataElementEntry(
            tag: .samplesPerPixel,
            name: "Samples per Pixel",
            keyword: "SamplesPerPixel",
            vr: .US,
            vm: "1"
        )
        
        dict[.photometricInterpretation] = DataElementEntry(
            tag: .photometricInterpretation,
            name: "Photometric Interpretation",
            keyword: "PhotometricInterpretation",
            vr: .CS,
            vm: "1"
        )
        
        dict[.rows] = DataElementEntry(
            tag: .rows,
            name: "Rows",
            keyword: "Rows",
            vr: .US,
            vm: "1"
        )
        
        dict[.columns] = DataElementEntry(
            tag: .columns,
            name: "Columns",
            keyword: "Columns",
            vr: .US,
            vm: "1"
        )
        
        dict[.bitsAllocated] = DataElementEntry(
            tag: .bitsAllocated,
            name: "Bits Allocated",
            keyword: "BitsAllocated",
            vr: .US,
            vm: "1"
        )
        
        dict[.bitsStored] = DataElementEntry(
            tag: .bitsStored,
            name: "Bits Stored",
            keyword: "BitsStored",
            vr: .US,
            vm: "1"
        )
        
        dict[.highBit] = DataElementEntry(
            tag: .highBit,
            name: "High Bit",
            keyword: "HighBit",
            vr: .US,
            vm: "1"
        )
        
        dict[.pixelRepresentation] = DataElementEntry(
            tag: .pixelRepresentation,
            name: "Pixel Representation",
            keyword: "PixelRepresentation",
            vr: .US,
            vm: "1"
        )
        
        dict[.numberOfFrames] = DataElementEntry(
            tag: .numberOfFrames,
            name: "Number of Frames",
            keyword: "NumberOfFrames",
            vr: .IS,
            vm: "1"
        )
        
        // Image Plane elements
        dict[.pixelSpacing] = DataElementEntry(
            tag: .pixelSpacing,
            name: "Pixel Spacing",
            keyword: "PixelSpacing",
            vr: .DS,
            vm: "2"
        )
        
        dict[.imagePositionPatient] = DataElementEntry(
            tag: .imagePositionPatient,
            name: "Image Position (Patient)",
            keyword: "ImagePositionPatient",
            vr: .DS,
            vm: "3"
        )
        
        dict[.imageOrientationPatient] = DataElementEntry(
            tag: .imageOrientationPatient,
            name: "Image Orientation (Patient)",
            keyword: "ImageOrientationPatient",
            vr: .DS,
            vm: "6"
        )
        
        dict[.sliceThickness] = DataElementEntry(
            tag: .sliceThickness,
            name: "Slice Thickness",
            keyword: "SliceThickness",
            vr: .DS,
            vm: "1"
        )
        
        dict[.sliceLocation] = DataElementEntry(
            tag: .sliceLocation,
            name: "Slice Location",
            keyword: "SliceLocation",
            vr: .DS,
            vm: "1"
        )
        
        // Window/Level
        dict[.windowCenter] = DataElementEntry(
            tag: .windowCenter,
            name: "Window Center",
            keyword: "WindowCenter",
            vr: .DS,
            vm: "1-n"
        )
        
        dict[.windowWidth] = DataElementEntry(
            tag: .windowWidth,
            name: "Window Width",
            keyword: "WindowWidth",
            vr: .DS,
            vm: "1-n"
        )
        
        // Rescale
        dict[.rescaleIntercept] = DataElementEntry(
            tag: .rescaleIntercept,
            name: "Rescale Intercept",
            keyword: "RescaleIntercept",
            vr: .DS,
            vm: "1"
        )
        
        dict[.rescaleSlope] = DataElementEntry(
            tag: .rescaleSlope,
            name: "Rescale Slope",
            keyword: "RescaleSlope",
            vr: .DS,
            vm: "1"
        )
        
        dict[.rescaleType] = DataElementEntry(
            tag: .rescaleType,
            name: "Rescale Type",
            keyword: "RescaleType",
            vr: .LO,
            vm: "1"
        )
        
        // Equipment elements
        dict[.manufacturer] = DataElementEntry(
            tag: .manufacturer,
            name: "Manufacturer",
            keyword: "Manufacturer",
            vr: .LO,
            vm: "1"
        )
        
        dict[.institutionName] = DataElementEntry(
            tag: .institutionName,
            name: "Institution Name",
            keyword: "InstitutionName",
            vr: .LO,
            vm: "1"
        )
        
        dict[.stationName] = DataElementEntry(
            tag: .stationName,
            name: "Station Name",
            keyword: "StationName",
            vr: .SH,
            vm: "1"
        )
        
        dict[.manufacturerModelName] = DataElementEntry(
            tag: .manufacturerModelName,
            name: "Manufacturer's Model Name",
            keyword: "ManufacturerModelName",
            vr: .LO,
            vm: "1"
        )
        
        dict[.softwareVersions] = DataElementEntry(
            tag: .softwareVersions,
            name: "Software Versions",
            keyword: "SoftwareVersions",
            vr: .LO,
            vm: "1-n"
        )
        
        // Referring Physician
        dict[.referringPhysicianName] = DataElementEntry(
            tag: .referringPhysicianName,
            name: "Referring Physician's Name",
            keyword: "ReferringPhysicianName",
            vr: .PN,
            vm: "1"
        )
        
        // Performing Physician
        dict[.performingPhysicianName] = DataElementEntry(
            tag: .performingPhysicianName,
            name: "Performing Physician's Name",
            keyword: "PerformingPhysicianName",
            vr: .PN,
            vm: "1-n"
        )
        
        // Accession Number
        dict[.accessionNumber] = DataElementEntry(
            tag: .accessionNumber,
            name: "Accession Number",
            keyword: "AccessionNumber",
            vr: .SH,
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
