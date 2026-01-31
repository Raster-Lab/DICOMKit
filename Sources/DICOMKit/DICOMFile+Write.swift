import Foundation
import DICOMCore

// MARK: - DataSet Writing Extension

extension DataSet {
    
    /// Serializes the data set to binary data
    ///
    /// Serializes all data elements in tag order using the specified writer configuration.
    ///
    /// Reference: PS3.5 Section 7.1 - Data Element Structure
    ///
    /// - Parameter writer: The DICOM writer to use for serialization
    /// - Returns: Serialized data set
    public func write(using writer: DICOMWriter = DICOMWriter()) -> Data {
        var data = Data()
        
        // Elements must be written in tag order per DICOM specification
        let sortedTags = tags.sorted()
        
        for tag in sortedTags {
            if let element = self[tag] {
                data.append(writer.serializeElement(element))
            }
        }
        
        return data
    }
    
    // MARK: - Convenience Setters
    
    /// Sets a string value for the given tag
    ///
    /// - Parameters:
    ///   - value: The string value to set
    ///   - tag: The tag to set
    ///   - vr: The Value Representation to use
    public mutating func setString(_ value: String, for tag: Tag, vr: VR) {
        self[tag] = DataElement.string(tag: tag, vr: vr, value: value)
    }
    
    /// Sets multiple string values for the given tag
    ///
    /// - Parameters:
    ///   - values: The string values to set
    ///   - tag: The tag to set
    ///   - vr: The Value Representation to use
    public mutating func setStrings(_ values: [String], for tag: Tag, vr: VR) {
        self[tag] = DataElement.strings(tag: tag, vr: vr, values: values)
    }
    
    /// Sets a UInt16 value for the given tag
    ///
    /// - Parameters:
    ///   - value: The UInt16 value to set
    ///   - tag: The tag to set
    public mutating func setUInt16(_ value: UInt16, for tag: Tag) {
        self[tag] = DataElement.uint16(tag: tag, value: value)
    }
    
    /// Sets multiple UInt16 values for the given tag
    ///
    /// - Parameters:
    ///   - values: The UInt16 values to set
    ///   - tag: The tag to set
    public mutating func setUInt16s(_ values: [UInt16], for tag: Tag) {
        self[tag] = DataElement.uint16s(tag: tag, values: values)
    }
    
    /// Sets a UInt32 value for the given tag
    ///
    /// - Parameters:
    ///   - value: The UInt32 value to set
    ///   - tag: The tag to set
    public mutating func setUInt32(_ value: UInt32, for tag: Tag) {
        self[tag] = DataElement.uint32(tag: tag, value: value)
    }
    
    /// Sets a sequence value for the given tag
    ///
    /// - Parameters:
    ///   - items: The sequence items to set
    ///   - tag: The tag to set
    public mutating func setSequence(_ items: [SequenceItem], for tag: Tag) {
        // Serialize items to calculate length
        let writer = DICOMWriter()
        var itemsData = Data()
        for item in items {
            itemsData.append(writer.serializeSequenceItem(item))
        }
        
        self[tag] = DataElement(
            tag: tag,
            vr: .SQ,
            length: UInt32(itemsData.count),
            valueData: itemsData,
            sequenceItems: items
        )
    }
    
    /// Removes the element at the given tag
    ///
    /// - Parameter tag: The tag to remove
    public mutating func remove(tag: Tag) {
        self[tag] = nil
    }
}

// MARK: - DICOMFile Writing Extension

extension DICOMFile {
    
    /// DICOM File Preamble size (128 bytes of zeros)
    private static let preambleSize = 128
    
    /// DICOM File Prefix
    private static let dicomPrefix: [UInt8] = [0x44, 0x49, 0x43, 0x4D] // "DICM"
    
    /// Writes the DICOM file to binary data
    ///
    /// Generates a complete DICOM Part 10 file with:
    /// - 128-byte preamble (zeros)
    /// - "DICM" prefix
    /// - File Meta Information (always Explicit VR Little Endian)
    /// - Main data set (using the transfer syntax specified in File Meta Information)
    ///
    /// Reference: PS3.10 Section 7 - DICOM File Format
    ///
    /// - Returns: Complete DICOM file data
    /// - Throws: DICOMError if writing fails
    public func write() throws -> Data {
        var data = Data()
        
        // 1. Write 128-byte preamble (all zeros)
        data.append(Data(count: Self.preambleSize))
        
        // 2. Write "DICM" prefix
        data.append(contentsOf: Self.dicomPrefix)
        
        // 3. Write File Meta Information (always Explicit VR Little Endian per PS3.10)
        let fileMetaWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        data.append(fileMetaInformation.write(using: fileMetaWriter))
        
        // 4. Determine transfer syntax for main data set
        let transferSyntaxUID = self.transferSyntaxUID ?? "1.2.840.10008.1.2.1"
        let transferSyntax = TransferSyntax.from(uid: transferSyntaxUID)
        
        // Ensure transfer syntax is supported for writing
        let isExplicitVR = transferSyntax?.isExplicitVR ?? true
        let byteOrder = transferSyntax?.byteOrder ?? .littleEndian
        
        // 5. Write main data set
        let mainWriter = DICOMWriter(byteOrder: byteOrder, explicitVR: isExplicitVR)
        data.append(dataSet.write(using: mainWriter))
        
        return data
    }
    
    /// Creates a new DICOM file with File Meta Information automatically generated
    ///
    /// Generates required File Meta Information elements including:
    /// - File Meta Information Version (0002,0001)
    /// - Media Storage SOP Class UID (0002,0002)
    /// - Media Storage SOP Instance UID (0002,0003)
    /// - Transfer Syntax UID (0002,0010)
    /// - Implementation Class UID (0002,0012)
    /// - Implementation Version Name (0002,0013)
    ///
    /// Reference: PS3.10 Section 7.1 - DICOM File Meta Information
    ///
    /// - Parameters:
    ///   - dataSet: The main data set
    ///   - sopClassUID: SOP Class UID (defaults to Secondary Capture Image Storage)
    ///   - sopInstanceUID: SOP Instance UID (auto-generated if nil)
    ///   - transferSyntaxUID: Transfer Syntax UID (defaults to Explicit VR Little Endian)
    /// - Returns: A new DICOMFile with generated File Meta Information
    public static func create(
        dataSet: DataSet,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.7", // Secondary Capture Image Storage
        sopInstanceUID: String? = nil,
        transferSyntaxUID: String = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
    ) -> DICOMFile {
        var fileMetaInfo = DataSet()
        
        // Generate SOP Instance UID if not provided
        let instanceUID = sopInstanceUID ?? UIDGenerator.generateSOPInstanceUID().value
        
        // File Meta Information Version (0002,0001)
        fileMetaInfo[.fileMetaInformationVersion] = DataElement.data(
            tag: .fileMetaInformationVersion,
            vr: .OB,
            data: Data([0x00, 0x01])
        )
        
        // Media Storage SOP Class UID (0002,0002)
        fileMetaInfo.setString(sopClassUID, for: .mediaStorageSOPClassUID, vr: .UI)
        
        // Media Storage SOP Instance UID (0002,0003)
        fileMetaInfo.setString(instanceUID, for: .mediaStorageSOPInstanceUID, vr: .UI)
        
        // Transfer Syntax UID (0002,0010)
        fileMetaInfo.setString(transferSyntaxUID, for: .transferSyntaxUID, vr: .UI)
        
        // Implementation Class UID (0002,0012)
        fileMetaInfo.setString(
            "1.2.276.0.7230010.3.0.3.6.5",  // DICOMKit implementation UID
            for: .implementationClassUID,
            vr: .UI
        )
        
        // Implementation Version Name (0002,0013)
        fileMetaInfo.setString("DICOMKIT_0.5.0", for: .implementationVersionName, vr: .SH)
        
        // Calculate and set File Meta Information Group Length (0002,0000)
        let writer = DICOMWriter()
        let metaInfoData = fileMetaInfo.write(using: writer)
        fileMetaInfo[.fileMetaInformationGroupLength] = DataElement.uint32(
            tag: .fileMetaInformationGroupLength,
            value: UInt32(metaInfoData.count)
        )
        
        return DICOMFile(fileMetaInformation: fileMetaInfo, dataSet: dataSet)
    }
}
