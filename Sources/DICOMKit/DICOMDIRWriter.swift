import Foundation
import DICOMCore

/// DICOMDIR Writer
///
/// Writes DICOMDIR files (Media Storage Directory).
/// Reference: DICOM PS3.10 - Media Storage and File Format
/// Reference: DICOM PS3.3 F.5 - Media Storage Directory SOP Class
public struct DICOMDIRWriter {
    /// Media Storage Directory SOP Class UID
    private static let mediaStorageDirectorySOPClassUID = "1.2.840.10008.1.3.10"
    
    /// Write a DICOMDIR to data
    ///
    /// - Parameter directory: DICOMDIR structure to write
    /// - Returns: Serialized DICOM file data
    /// - Throws: DICOMError if writing fails
    public static func write(_ directory: DICOMDirectory) throws -> Data {
        // Create main data set with directory information
        var dataSet = DataSet()
        
        // Add file-set identification
        if !directory.fileSetID.isEmpty {
            dataSet[.fileSetID] = DataElement.string(tag: .fileSetID, vr: .CS, value: directory.fileSetID)
        }
        
        // Add specific character set
        if let charset = directory.specificCharacterSet {
            dataSet[.specificCharacterSet] = DataElement.string(tag: .specificCharacterSet, vr: .CS, value: charset)
        }
        
        // Add file-set descriptor information
        if let fileSetDescriptor = directory.fileSetDescriptorFileID {
            dataSet[.fileSetDescriptorFileID] = DataElement.strings(tag: .fileSetDescriptorFileID, vr: .CS, values: fileSetDescriptor)
        }
        
        if let charset = directory.specificCharacterSetOfFileSetDescriptorFile {
            dataSet[.specificCharacterSetOfFileSetDescriptorFile] = DataElement.string(tag: .specificCharacterSetOfFileSetDescriptorFile, vr: .CS, value: charset)
        }
        
        // Add consistency flag
        let consistencyFlag: UInt16 = directory.isConsistent ? 0x0000 : 0xFFFF
        dataSet[.fileSetConsistencyFlag] = DataElement.uint16(tag: .fileSetConsistencyFlag, value: consistencyFlag)
        
        // Build directory record sequence
        let directoryRecordSequence = try buildDirectoryRecordSequence(from: directory.rootRecords)
        
        // Add directory record sequence to data set
        let sequenceElement = DataElement(
            tag: .directoryRecordSequence,
            vr: .sequence,
            data: .sequence(directoryRecordSequence)
        )
        dataSet.set(sequenceElement)
        
        // Create file meta information
        let fileMetaInformation = createFileMetaInformation()
        
        // Create DICOM file
        let dicomFile = DICOMFile(fileMetaInformation: fileMetaInformation, dataSet: dataSet)
        
        // Write to data
        return try dicomFile.write()
    }
    
    /// Write a DICOMDIR to a file URL
    ///
    /// - Parameters:
    ///   - directory: DICOMDIR structure to write
    ///   - url: File URL to write to
    /// - Throws: DICOMError or IO error if writing fails
    public static func write(_ directory: DICOMDirectory, to url: URL) throws {
        let data = try write(directory)
        try data.write(to: url)
    }
    
    /// Create file meta information for DICOMDIR
    ///
    /// - Returns: DataSet with file meta information
    private static func createFileMetaInformation() -> DataSet {
        var fmi = DataSet()
        
        // File Meta Information Group Length - will be set by DICOMFile.write()
        // File Meta Information Version
        var versionData = Data(count: 2)
        versionData[0] = 0x00
        versionData[1] = 0x01
        fmi.set(DataElement(tag: .fileMetaInformationVersion, vr: .otherByteString, data: .bytes(versionData)))
        
        // Media Storage SOP Class UID (DICOMDIR)
        fmi[.mediaStorageSOPClassUID] = DataElement.string(tag: .mediaStorageSOPClassUID, vr: .UI, value: mediaStorageDirectorySOPClassUID)
        
        // Media Storage SOP Instance UID (generate unique UID)
        let sopInstanceUID = UIDGenerator.generateUID()
        fmi[.mediaStorageSOPInstanceUID] = DataElement.string(tag: .mediaStorageSOPInstanceUID, vr: .UI, value: sopInstanceUID)
        
        // Transfer Syntax UID (Explicit VR Little Endian)
        fmi[.transferSyntaxUID] = DataElement.string(tag: .transferSyntaxUID, vr: .UI, value: TransferSyntax.explicitVRLittleEndian.uid)
        
        // Implementation Class UID
        fmi[.implementationClassUID] = DataElement.string(tag: .implementationClassUID, vr: .UI, value: "1.2.840.10008.1.2.1.99")
        
        // Implementation Version Name
        fmi[.implementationVersionName] = DataElement.string(tag: .implementationVersionName, vr: .SH, value: "DICOMKit_1_0")
        
        return fmi
    }
    
    /// Build directory record sequence from root records
    ///
    /// - Parameter rootRecords: Root directory records
    /// - Returns: Array of sequence items
    /// - Throws: DICOMError if building fails
    private static func buildDirectoryRecordSequence(from rootRecords: [DirectoryRecord]) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        // Flatten records in depth-first order
        func flattenRecords(_ records: [DirectoryRecord]) -> [DirectoryRecord] {
            var flattened: [DirectoryRecord] = []
            for record in records {
                flattened.append(record)
                if !record.children.isEmpty {
                    flattened.append(contentsOf: flattenRecords(record.children))
                }
            }
            return flattened
        }
        
        let allRecords = flattenRecords(rootRecords)
        
        // Build sequence items for each record
        // Note: Offset calculation would be done during actual serialization
        // For now, we'll create the structure without offset values
        for record in allRecords {
            let recordDataSet = try buildDirectoryRecordDataSet(from: record)
            let item = SequenceItem(dataSet: recordDataSet)
            items.append(item)
        }
        
        return items
    }
    
    /// Build a DataSet for a single directory record
    ///
    /// - Parameter record: Directory record to serialize
    /// - Returns: DataSet representing the record
    /// - Throws: DICOMError if building fails
    private static func buildDirectoryRecordDataSet(from record: DirectoryRecord) throws -> DataSet {
        var dataSet = DataSet()
        
        // Add directory record type
        dataSet[.directoryRecordType] = DataElement.string(tag: .directoryRecordType, vr: .CS, value: record.recordType.rawValue)
        
        // Add in-use flag
        let inUseFlag: UInt16 = record.isActive ? 0xFFFF : 0x0000
        dataSet[.recordInUseFlag] = DataElement.uint16(tag: .recordInUseFlag, value: inUseFlag)
        
        // Add referenced file information (for IMAGE and similar records)
        if let referencedFileID = record.referencedFileID {
            dataSet[.referencedFileID] = DataElement.strings(tag: .referencedFileID, vr: .CS, values: referencedFileID)
        }
        
        if let sopClassUID = record.referencedSOPClassUID {
            dataSet[.referencedSOPClassUIDInFile] = DataElement.string(tag: .referencedSOPClassUIDInFile, vr: .UI, value: sopClassUID)
        }
        
        if let sopInstanceUID = record.referencedSOPInstanceUID {
            dataSet[.referencedSOPInstanceUIDInFile] = DataElement.string(tag: .referencedSOPInstanceUIDInFile, vr: .UI, value: sopInstanceUID)
        }
        
        if let transferSyntaxUID = record.referencedTransferSyntaxUID {
            dataSet[.referencedTransferSyntaxUIDInFile] = DataElement.string(tag: .referencedTransferSyntaxUIDInFile, vr: .UI, value: transferSyntaxUID)
        }
        
        // Add offset placeholders (these would be calculated during serialization)
        // Offset of the Next Directory Record (0 = no next record)
        dataSet[.offsetOfTheNextDirectoryRecord] = DataElement.uint32(tag: .offsetOfTheNextDirectoryRecord, value: 0)
        
        // Offset of Referenced Lower-Level Directory Entity (0 = no children)
        dataSet[.offsetOfReferencedLowerLevelDirectoryEntity] = DataElement.uint32(tag: .offsetOfReferencedLowerLevelDirectoryEntity, value: 0)
        
        // Add all other attributes
        for (tag, element) in record.attributes {
            dataSet.set(element)
        }
        
        return dataSet
    }
}

// MARK: - DICOMDIR Builder

extension DICOMDirectory {
    /// Builder for constructing DICOMDIR from DICOM files
    public struct Builder {
        private var fileSetID: String
        private var profile: DICOMDIRProfile
        private var specificCharacterSet: String?
        private var patients: [String: DirectoryRecord] = [:]
        
        /// Initialize a new DICOMDIR builder
        ///
        /// - Parameters:
        ///   - fileSetID: File-set identifier
        ///   - profile: Application profile (default: .standardGeneralCD)
        public init(fileSetID: String = "", profile: DICOMDIRProfile = .standardGeneralCD) {
            self.fileSetID = fileSetID
            self.profile = profile
        }
        
        /// Add a DICOM file to the directory
        ///
        /// - Parameters:
        ///   - file: DICOM file to add
        ///   - relativePath: Relative path to the file from DICOMDIR location
        /// - Throws: DICOMError if file cannot be added
        public mutating func addFile(_ file: DICOMFile, relativePath: [String]) throws {
            let dataSet = file.dataSet
            
            // Extract patient information
            guard let patientID = dataSet.string(forTag: .patientID) else {
                throw DICOMError.invalidFormat(message: "Missing Patient ID")
            }
            let patientName = dataSet.string(forTag: .patientName) ?? ""
            
            // Extract study information
            guard let studyInstanceUID = dataSet.string(forTag: .studyInstanceUID) else {
                throw DICOMError.invalidFormat(message: "Missing Study Instance UID")
            }
            let studyDate = dataSet.string(forTag: .studyDate)
            let studyTime = dataSet.string(forTag: .studyTime)
            let studyDescription = dataSet.string(forTag: .studyDescription)
            
            // Extract series information
            guard let seriesInstanceUID = dataSet.string(forTag: .seriesInstanceUID) else {
                throw DICOMError.invalidFormat(message: "Missing Series Instance UID")
            }
            let modality = dataSet.string(forTag: .modality) ?? "OT"
            let seriesNumber = dataSet.string(forTag: .seriesNumber)
            let seriesDescription = dataSet.string(forTag: .seriesDescription)
            
            // Extract instance information
            guard let sopClassUID = file.fileMetaInformation.string(forTag: .mediaStorageSOPClassUID) else {
                throw DICOMError.invalidFormat(message: "Missing SOP Class UID")
            }
            guard let sopInstanceUID = file.fileMetaInformation.string(forTag: .mediaStorageSOPInstanceUID) else {
                throw DICOMError.invalidFormat(message: "Missing SOP Instance UID")
            }
            let transferSyntaxUID = file.fileMetaInformation.string(forTag: .transferSyntaxUID) ?? TransferSyntax.explicitVRLittleEndian.uid
            let instanceNumber = dataSet.string(forTag: .instanceNumber)
            
            // Get or create patient record
            var patient: DirectoryRecord
            if let existingPatient = patients[patientID] {
                patient = existingPatient
            } else {
                patient = DirectoryRecord.patient(patientID: patientID, patientName: patientName)
                patients[patientID] = patient
            }
            
            // Find or create study record
            let studyKey = studyInstanceUID
            var study: DirectoryRecord?
            for (index, child) in patient.children.enumerated() {
                if child.recordType == .study,
                   child.attribute(for: .studyInstanceUID)?.stringValue == studyInstanceUID {
                    study = patient.children[index]
                    break
                }
            }
            
            if study == nil {
                study = DirectoryRecord.study(
                    studyInstanceUID: studyInstanceUID,
                    studyDate: studyDate,
                    studyTime: studyTime,
                    studyDescription: studyDescription
                )
            }
            
            // Find or create series record
            var series: DirectoryRecord?
            if var currentStudy = study {
                for (index, child) in currentStudy.children.enumerated() {
                    if child.recordType == .series,
                       child.attribute(for: .seriesInstanceUID)?.stringValue == seriesInstanceUID {
                        series = currentStudy.children[index]
                        break
                    }
                }
                
                if series == nil {
                    series = DirectoryRecord.series(
                        seriesInstanceUID: seriesInstanceUID,
                        modality: modality,
                        seriesNumber: seriesNumber,
                        seriesDescription: seriesDescription
                    )
                }
                
                // Create image record
                let image = DirectoryRecord.image(
                    referencedFileID: relativePath,
                    sopClassUID: sopClassUID,
                    sopInstanceUID: sopInstanceUID,
                    transferSyntaxUID: transferSyntaxUID,
                    instanceNumber: instanceNumber
                )
                
                // Add image to series
                if var currentSeries = series {
                    currentSeries.addChild(image)
                    series = currentSeries
                }
                
                // Update study with series
                if var currentSeries = series {
                    let seriesExists = currentStudy.children.contains { $0.recordType == .series && $0.attribute(for: .seriesInstanceUID)?.stringValue == seriesInstanceUID }
                    if !seriesExists {
                        currentStudy.addChild(currentSeries)
                    }
                }
                
                study = currentStudy
            }
            
            // Update patient with study
            if var currentStudy = study {
                let studyExists = patient.children.contains { $0.recordType == .study && $0.attribute(for: .studyInstanceUID)?.stringValue == studyInstanceUID }
                if !studyExists {
                    patient.addChild(currentStudy)
                }
            }
            
            patients[patientID] = patient
        }
        
        /// Build the final DICOMDIR
        ///
        /// - Returns: Complete DICOMDIR structure
        public func build() -> DICOMDirectory {
            let rootRecords = Array(patients.values)
            
            return DICOMDirectory(
                fileSetID: fileSetID,
                profile: profile,
                specificCharacterSet: specificCharacterSet,
                rootRecords: rootRecords
            )
        }
    }
}
