import Foundation
import DICOMCore

/// DICOMDIR Reader
///
/// Reads and parses DICOMDIR files (Media Storage Directory).
/// Reference: DICOM PS3.10 - Media Storage and File Format
/// Reference: DICOM PS3.3 F.5 - Media Storage Directory SOP Class
public struct DICOMDIRReader {
    /// Read a DICOMDIR file from data
    ///
    /// - Parameter data: Raw DICOMDIR file data
    /// - Returns: Parsed DICOMDIR structure
    /// - Throws: DICOMError if parsing fails
    public static func read(from data: Data) throws -> DICOMDirectory {
        // Read as a standard DICOM file
        let dicomFile = try DICOMFile.read(from: data)
        
        // Verify it's a DICOMDIR (SOP Class UID should be 1.2.840.10008.1.3.10)
        let sopClassUID = dicomFile.fileMetaInformation.string(for: .mediaStorageSOPClassUID)
        guard sopClassUID == "1.2.840.10008.1.3.10" else {
            throw DICOMError.invalidFormat(message: "Not a valid DICOMDIR file (incorrect SOP Class UID)")
        }
        
        return try parse(dataSet: dicomFile.dataSet)
    }
    
    /// Read a DICOMDIR file from URL
    ///
    /// - Parameter url: File URL to the DICOMDIR file
    /// - Returns: Parsed DICOMDIR structure
    /// - Throws: DICOMError if reading or parsing fails
    public static func read(from url: URL) throws -> DICOMDirectory {
        let data = try Data(contentsOf: url)
        return try read(from: data)
    }
    
    /// Parse a DICOMDIR from a DataSet
    ///
    /// - Parameter dataSet: DICOM DataSet containing directory information
    /// - Returns: Parsed DICOMDIR structure
    /// - Throws: DICOMError if parsing fails
    static func parse(dataSet: DataSet) throws -> DICOMDirectory {
        // Extract file-set metadata
        let fileSetID = dataSet.string(for: .fileSetID) ?? ""
        let specificCharacterSet = dataSet.string(for: .specificCharacterSet)
        
        // Extract file-set descriptor information
        let fileSetDescriptorFileID = dataSet.strings(forTag: .fileSetDescriptorFileID)
        let specificCharacterSetOfFileSetDescriptorFile = dataSet.string(for: .specificCharacterSetOfFileSetDescriptorFile)
        
        // Extract consistency flag
        let consistencyFlag = dataSet.uint16(forTag: .fileSetConsistencyFlag) ?? 0x0000
        let isConsistent = (consistencyFlag == 0x0000)
        
        // Parse directory record sequence
        let rootRecords = try parseDirectoryRecordSequence(dataSet: dataSet)
        
        // Determine profile (would need additional logic to detect from content)
        let profile = DICOMDIRProfile.standardGeneralCD
        
        return DICOMDirectory(
            fileSetID: fileSetID,
            profile: profile,
            specificCharacterSet: specificCharacterSet,
            fileSetDescriptorFileID: fileSetDescriptorFileID,
            specificCharacterSetOfFileSetDescriptorFile: specificCharacterSetOfFileSetDescriptorFile,
            rootRecords: rootRecords,
            isConsistent: isConsistent
        )
    }
    
    /// Parse the Directory Record Sequence
    ///
    /// - Parameter dataSet: DataSet containing the sequence
    /// - Returns: Array of root directory records
    /// - Throws: DICOMError if parsing fails
    private static func parseDirectoryRecordSequence(dataSet: DataSet) throws -> [DirectoryRecord] {
        guard let element = dataSet.element(forTag: .directoryRecordSequence),
              case .sequence(let items) = element.data else {
            // No directory records
            return []
        }
        
        // Parse each item as a directory record
        var records: [DirectoryRecord] = []
        var recordMap: [Int: (record: DirectoryRecord, nextOffset: UInt32?, lowerOffset: UInt32?)] = [:]
        
        // First pass: Parse all records and build a map
        for (index, item) in items.enumerated() {
            let record = try parseDirectoryRecord(from: item.dataSet)
            
            // Get offsets for navigation
            let nextOffset = item.dataSet.uint32(for: .offsetOfTheNextDirectoryRecord)
            let lowerOffset = item.dataSet.uint32(for: .offsetOfReferencedLowerLevelDirectoryEntity)
            
            recordMap[index] = (record, nextOffset, lowerOffset)
        }
        
        // Second pass: Build hierarchy using offsets
        // For simplicity in this initial implementation, we'll build a flat structure
        // and assume proper hierarchy based on record types
        
        // Build hierarchy: PATIENT -> STUDY -> SERIES -> IMAGE
        var patients: [DirectoryRecord] = []
        var currentPatient: DirectoryRecord?
        var currentStudy: DirectoryRecord?
        var currentSeries: DirectoryRecord?
        
        for (_, entry) in recordMap.sorted(by: { $0.key < $1.key }) {
            var record = entry.record
            
            switch record.recordType {
            case .patient:
                // Save previous patient if any
                if var patient = currentPatient {
                    if var study = currentStudy {
                        if var series = currentSeries {
                            study.addChild(series)
                            currentSeries = nil
                        }
                        patient.addChild(study)
                        currentStudy = nil
                    }
                    patients.append(patient)
                }
                currentPatient = record
                
            case .study:
                // Save previous study if any
                if var patient = currentPatient, var study = currentStudy {
                    if var series = currentSeries {
                        study.addChild(series)
                        currentSeries = nil
                    }
                    patient.addChild(study)
                }
                currentStudy = record
                
            case .series:
                // Save previous series if any
                if var study = currentStudy, var series = currentSeries {
                    study.addChild(series)
                }
                currentSeries = record
                
            case .image, .presentation, .srDocument, .waveform, .rtDose, .rtStructureSet, .rtPlan:
                // Add to current series
                if var series = currentSeries {
                    series.addChild(record)
                    currentSeries = series
                }
                
            default:
                // Handle other record types
                break
            }
        }
        
        // Save final records
        if var patient = currentPatient {
            if var study = currentStudy {
                if var series = currentSeries {
                    study.addChild(series)
                }
                patient.addChild(study)
            }
            patients.append(patient)
        }
        
        return patients
    }
    
    /// Parse a single directory record from a SequenceItem
    ///
    /// - Parameter dataSet: DataSet for the record
    /// - Returns: Parsed directory record
    /// - Throws: DICOMError if parsing fails
    private static func parseDirectoryRecord(from dataSet: DataSet) throws -> DirectoryRecord {
        // Get record type
        guard let recordTypeString = dataSet.string(for: .directoryRecordType),
              let recordType = DirectoryRecordType(rawValue: recordTypeString) else {
            throw DICOMError.invalidFormat(message: "Missing or invalid Directory Record Type")
        }
        
        // Get in-use flag
        let inUseFlag = dataSet.uint16(forTag: .recordInUseFlag) ?? 0xFFFF
        let isActive = (inUseFlag == 0xFFFF)
        
        // Get referenced file information
        let referencedFileID = dataSet.strings(forTag: .referencedFileID)
        let referencedSOPClassUID = dataSet.string(for: .referencedSOPClassUIDInFile)
        let referencedSOPInstanceUID = dataSet.string(for: .referencedSOPInstanceUIDInFile)
        let referencedTransferSyntaxUID = dataSet.string(for: .referencedTransferSyntaxUIDInFile)
        
        // Extract all other attributes for this record
        var attributes: [Tag: DataElement] = [:]
        for tag in dataSet.tags {
            // Skip navigation and reference tags (we handle those separately)
            if tag == .directoryRecordType || 
               tag == .recordInUseFlag ||
               tag == .offsetOfTheNextDirectoryRecord ||
               tag == .offsetOfReferencedLowerLevelDirectoryEntity ||
               tag == .referencedFileID ||
               tag == .referencedSOPClassUIDInFile ||
               tag == .referencedSOPInstanceUIDInFile ||
               tag == .referencedTransferSyntaxUIDInFile {
                continue
            }
            
            if let element = dataSet.element(forTag: tag) {
                attributes[tag] = element
            }
        }
        
        return DirectoryRecord(
            recordType: recordType,
            referencedFileID: referencedFileID,
            referencedSOPClassUID: referencedSOPClassUID,
            referencedSOPInstanceUID: referencedSOPInstanceUID,
            referencedTransferSyntaxUID: referencedTransferSyntaxUID,
            isActive: isActive,
            attributes: attributes,
            children: []
        )
    }
}
