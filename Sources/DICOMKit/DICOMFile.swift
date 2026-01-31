import Foundation

/// DICOM File
///
/// Represents a DICOM Part 10 file with File Meta Information and main data set.
/// Reference: DICOM PS3.10 Section 7 - DICOM File Format
public struct DICOMFile: Sendable {
    /// File Meta Information (Group 0002 elements)
    ///
    /// Contains metadata about the file, including Transfer Syntax UID.
    /// Reference: PS3.10 Section 7.1
    public let fileMetaInformation: DataSet
    
    /// Main data set (all elements after File Meta Information)
    public let dataSet: DataSet
    
    /// Creates a DICOM file
    /// - Parameters:
    ///   - fileMetaInformation: File Meta Information data set
    ///   - dataSet: Main data set
    public init(fileMetaInformation: DataSet, dataSet: DataSet) {
        self.fileMetaInformation = fileMetaInformation
        self.dataSet = dataSet
    }
    
    /// Reads a DICOM file from data
    ///
    /// Validates the 128-byte preamble and "DICM" prefix per PS3.10 Section 7.1.
    /// Parses File Meta Information and main data set using Explicit VR Little Endian.
    ///
    /// - Parameter data: Raw file data
    /// - Returns: Parsed DICOM file
    /// - Throws: DICOMError if file is invalid or parsing fails
    public static func read(from data: Data) throws -> DICOMFile {
        // Validate minimum size (128-byte preamble + 4-byte "DICM")
        guard data.count >= 132 else {
            throw DICOMError.unexpectedEndOfData
        }
        
        // Validate "DICM" prefix at offset 128
        // Reference: PS3.10 Section 7.1 - DICOM File Meta Information
        let dicmOffset = 128
        let dicmBytes = data[dicmOffset..<dicmOffset+4]
        guard dicmBytes.elementsEqual([0x44, 0x49, 0x43, 0x4D]) else { // "DICM" in ASCII
            throw DICOMError.invalidDICMPrefix
        }
        
        // Parse File Meta Information (starts at offset 132, after DICM prefix)
        var parser = DICOMParser(data: data)
        let fileMetaInfo = try parser.parseFileMetaInformation(startOffset: 132)
        
        // Get Transfer Syntax UID from File Meta Information
        // Default to Explicit VR Little Endian if not specified
        let transferSyntaxUID = fileMetaInfo.string(for: .transferSyntaxUID) ?? "1.2.840.10008.1.2.1"
        
        // Parse main data set
        let mainDataSet = try parser.parseDataSet(transferSyntaxUID: transferSyntaxUID)
        
        return DICOMFile(fileMetaInformation: fileMetaInfo, dataSet: mainDataSet)
    }
    
    /// Transfer Syntax UID from File Meta Information
    ///
    /// Returns the Transfer Syntax UID (0002,0010) if present.
    public var transferSyntaxUID: String? {
        return fileMetaInformation.string(for: .transferSyntaxUID)
    }
    
    /// SOP Class UID from main data set
    ///
    /// Returns the SOP Class UID (0008,0016) if present.
    public var sopClassUID: String? {
        return dataSet.string(for: .sopClassUID)
    }
    
    /// SOP Instance UID from main data set
    ///
    /// Returns the SOP Instance UID (0008,0018) if present.
    public var sopInstanceUID: String? {
        return dataSet.string(for: .sopInstanceUID)
    }
}
