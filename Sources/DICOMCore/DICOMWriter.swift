import Foundation

/// DICOM Data Writer
///
/// Serializes DICOM data elements to binary format according to DICOM PS3.5.
/// Supports Explicit VR Little Endian transfer syntax (the most common format).
///
/// Reference: DICOM PS3.5 Section 7.1 - Data Element Encoding Rules
public struct DICOMWriter: Sendable {
    
    /// The byte order for writing multi-byte values
    public let byteOrder: ByteOrder
    
    /// Whether to use Explicit VR encoding
    public let explicitVR: Bool
    
    /// Creates a DICOM writer with specified encoding parameters
    /// - Parameters:
    ///   - byteOrder: Byte order for multi-byte values (default: Little Endian)
    ///   - explicitVR: Whether to use Explicit VR encoding (default: true)
    public init(byteOrder: ByteOrder = .littleEndian, explicitVR: Bool = true) {
        self.byteOrder = byteOrder
        self.explicitVR = explicitVR
    }
    
    // MARK: - Value Serialization
    
    /// Pads a string value to an even length as required by DICOM
    ///
    /// DICOM requires all values to have even byte lengths.
    /// String VRs are padded with space (0x20) for most VRs or null (0x00) for UI.
    ///
    /// Reference: PS3.5 Section 6.2 - Padding
    ///
    /// - Parameters:
    ///   - string: The string value to pad
    ///   - vr: The Value Representation (determines padding character)
    /// - Returns: Padded string data
    public func padString(_ string: String, vr: VR) -> Data {
        var data = Data(string.utf8)
        
        // DICOM requires even byte lengths
        if data.count % 2 != 0 {
            // UI uses null padding, others use space padding
            let paddingByte: UInt8 = (vr == .UI) ? 0x00 : 0x20
            data.append(paddingByte)
        }
        
        return data
    }
    
    /// Serializes a string value for writing
    ///
    /// - Parameters:
    ///   - value: The string value
    ///   - vr: The Value Representation
    /// - Returns: Serialized and padded data
    public func serializeString(_ value: String, vr: VR) -> Data {
        return padString(value, vr: vr)
    }
    
    /// Serializes multiple string values with backslash delimiter
    ///
    /// DICOM uses backslash (\) as the delimiter for multi-valued string elements.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    ///
    /// - Parameters:
    ///   - values: Array of string values
    ///   - vr: The Value Representation
    /// - Returns: Serialized and padded data
    public func serializeStrings(_ values: [String], vr: VR) -> Data {
        let joined = values.joined(separator: "\\")
        return padString(joined, vr: vr)
    }
    
    /// Serializes a UInt16 value
    ///
    /// - Parameter value: The UInt16 value
    /// - Returns: 2-byte data in the configured byte order
    public func serializeUInt16(_ value: UInt16) -> Data {
        var data = Data(count: 2)
        if byteOrder == .littleEndian {
            data[0] = UInt8(value & 0xFF)
            data[1] = UInt8((value >> 8) & 0xFF)
        } else {
            data[0] = UInt8((value >> 8) & 0xFF)
            data[1] = UInt8(value & 0xFF)
        }
        return data
    }
    
    /// Serializes multiple UInt16 values
    ///
    /// - Parameter values: Array of UInt16 values
    /// - Returns: Serialized data for all values
    public func serializeUInt16s(_ values: [UInt16]) -> Data {
        var data = Data()
        for value in values {
            data.append(serializeUInt16(value))
        }
        return data
    }
    
    /// Serializes a UInt32 value
    ///
    /// - Parameter value: The UInt32 value
    /// - Returns: 4-byte data in the configured byte order
    public func serializeUInt32(_ value: UInt32) -> Data {
        var data = Data(count: 4)
        if byteOrder == .littleEndian {
            data[0] = UInt8(value & 0xFF)
            data[1] = UInt8((value >> 8) & 0xFF)
            data[2] = UInt8((value >> 16) & 0xFF)
            data[3] = UInt8((value >> 24) & 0xFF)
        } else {
            data[0] = UInt8((value >> 24) & 0xFF)
            data[1] = UInt8((value >> 16) & 0xFF)
            data[2] = UInt8((value >> 8) & 0xFF)
            data[3] = UInt8(value & 0xFF)
        }
        return data
    }
    
    /// Serializes multiple UInt32 values
    ///
    /// - Parameter values: Array of UInt32 values
    /// - Returns: Serialized data for all values
    public func serializeUInt32s(_ values: [UInt32]) -> Data {
        var data = Data()
        for value in values {
            data.append(serializeUInt32(value))
        }
        return data
    }
    
    /// Serializes an Int16 value
    ///
    /// - Parameter value: The Int16 value
    /// - Returns: 2-byte data in the configured byte order
    public func serializeInt16(_ value: Int16) -> Data {
        return serializeUInt16(UInt16(bitPattern: value))
    }
    
    /// Serializes multiple Int16 values
    ///
    /// - Parameter values: Array of Int16 values
    /// - Returns: Serialized data for all values
    public func serializeInt16s(_ values: [Int16]) -> Data {
        var data = Data()
        for value in values {
            data.append(serializeInt16(value))
        }
        return data
    }
    
    /// Serializes an Int32 value
    ///
    /// - Parameter value: The Int32 value
    /// - Returns: 4-byte data in the configured byte order
    public func serializeInt32(_ value: Int32) -> Data {
        return serializeUInt32(UInt32(bitPattern: value))
    }
    
    /// Serializes multiple Int32 values
    ///
    /// - Parameter values: Array of Int32 values
    /// - Returns: Serialized data for all values
    public func serializeInt32s(_ values: [Int32]) -> Data {
        var data = Data()
        for value in values {
            data.append(serializeInt32(value))
        }
        return data
    }
    
    /// Serializes a Float32 value
    ///
    /// - Parameter value: The Float32 value
    /// - Returns: 4-byte data in the configured byte order
    public func serializeFloat32(_ value: Float32) -> Data {
        return serializeUInt32(value.bitPattern)
    }
    
    /// Serializes multiple Float32 values
    ///
    /// - Parameter values: Array of Float32 values
    /// - Returns: Serialized data for all values
    public func serializeFloat32s(_ values: [Float32]) -> Data {
        var data = Data()
        for value in values {
            data.append(serializeFloat32(value))
        }
        return data
    }
    
    /// Serializes a Float64 value
    ///
    /// - Parameter value: The Float64 value
    /// - Returns: 8-byte data in the configured byte order
    public func serializeFloat64(_ value: Float64) -> Data {
        let bits = value.bitPattern
        var data = Data(count: 8)
        if byteOrder == .littleEndian {
            for i in 0..<8 {
                data[i] = UInt8((bits >> (i * 8)) & 0xFF)
            }
        } else {
            for i in 0..<8 {
                data[7 - i] = UInt8((bits >> (i * 8)) & 0xFF)
            }
        }
        return data
    }
    
    /// Serializes multiple Float64 values
    ///
    /// - Parameter values: Array of Float64 values
    /// - Returns: Serialized data for all values
    public func serializeFloat64s(_ values: [Float64]) -> Data {
        var data = Data()
        for value in values {
            data.append(serializeFloat64(value))
        }
        return data
    }
    
    /// Serializes an Attribute Tag value (AT VR)
    ///
    /// AT VR stores tag values as two consecutive UInt16 values.
    /// Reference: PS3.5 Section 6.2 - AT Value Representation
    ///
    /// - Parameter tag: The tag to serialize
    /// - Returns: 4-byte data representing the tag
    public func serializeTag(_ tag: Tag) -> Data {
        var data = Data()
        data.append(serializeUInt16(tag.group))
        data.append(serializeUInt16(tag.element))
        return data
    }
    
    /// Serializes multiple Attribute Tag values
    ///
    /// - Parameter tags: Array of tags to serialize
    /// - Returns: Serialized data for all tags
    public func serializeTags(_ tags: [Tag]) -> Data {
        var data = Data()
        for tag in tags {
            data.append(serializeTag(tag))
        }
        return data
    }
    
    // MARK: - Data Element Serialization
    
    /// Serializes a data element header (tag, VR, length)
    ///
    /// Reference: PS3.5 Section 7.1 - Data Element Structure
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - vr: The Value Representation
    ///   - length: The value length in bytes
    /// - Returns: Serialized header data
    public func serializeElementHeader(tag: Tag, vr: VR, length: UInt32) -> Data {
        var data = Data()
        
        // Write tag (group, element)
        data.append(serializeUInt16(tag.group))
        data.append(serializeUInt16(tag.element))
        
        if explicitVR {
            // Write VR as 2 ASCII characters
            let vrString = vr.rawValue
            data.append(contentsOf: vrString.utf8)
            
            if vr.uses32BitLength {
                // VRs with 32-bit length: 2 reserved bytes + 4-byte length
                data.append(contentsOf: [0x00, 0x00])
                data.append(serializeUInt32(length))
            } else {
                // VRs with 16-bit length
                data.append(serializeUInt16(UInt16(length)))
            }
        } else {
            // Implicit VR: 32-bit length only
            data.append(serializeUInt32(length))
        }
        
        return data
    }
    
    /// Serializes a complete data element
    ///
    /// - Parameter element: The data element to serialize
    /// - Returns: Serialized data element including header and value
    public func serializeElement(_ element: DataElement) -> Data {
        var data = Data()
        
        // Handle sequences specially
        if element.vr == .SQ {
            data.append(serializeSequence(element))
            return data
        }
        
        // Write header
        data.append(serializeElementHeader(tag: element.tag, vr: element.vr, length: element.length))
        
        // Write value data
        if element.length != 0xFFFFFFFF {
            data.append(element.valueData)
        }
        
        return data
    }
    
    /// Serializes a sequence element (SQ VR)
    ///
    /// Reference: PS3.5 Section 7.5 - Nesting of Data Sets
    ///
    /// - Parameter element: The sequence element to serialize
    /// - Returns: Serialized sequence data
    private func serializeSequence(_ element: DataElement) -> Data {
        var data = Data()
        
        guard let items = element.sequenceItems else {
            // Empty sequence with explicit length 0
            data.append(serializeElementHeader(tag: element.tag, vr: .SQ, length: 0))
            return data
        }
        
        // Serialize items first to calculate length
        var itemsData = Data()
        for item in items {
            itemsData.append(serializeSequenceItem(item))
        }
        
        // Write sequence header with calculated length
        data.append(serializeElementHeader(tag: element.tag, vr: .SQ, length: UInt32(itemsData.count)))
        data.append(itemsData)
        
        return data
    }
    
    /// Serializes a sequence item
    ///
    /// Reference: PS3.5 Section 7.5.2 - Explicit Length
    ///
    /// - Parameter item: The sequence item to serialize
    /// - Returns: Serialized item data
    public func serializeSequenceItem(_ item: SequenceItem) -> Data {
        var data = Data()
        
        // Serialize all elements in the item
        var elementsData = Data()
        let sortedTags = item.tags.sorted()
        for tag in sortedTags {
            if let element = item[tag] {
                elementsData.append(serializeElement(element))
            }
        }
        
        // Item Tag (FFFE,E000)
        data.append(serializeUInt16(0xFFFE))
        data.append(serializeUInt16(0xE000))
        
        // Item Length
        data.append(serializeUInt32(UInt32(elementsData.count)))
        
        // Item data
        data.append(elementsData)
        
        return data
    }
}

// MARK: - Data Element Creation Helpers

extension DataElement {
    /// Creates a data element with a string value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - vr: The Value Representation
    ///   - value: The string value
    /// - Returns: A new data element
    public static func string(tag: Tag, vr: VR, value: String) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeString(value, vr: vr)
        return DataElement(tag: tag, vr: vr, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with multiple string values
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - vr: The Value Representation
    ///   - values: Array of string values
    /// - Returns: A new data element
    public static func strings(tag: Tag, vr: VR, values: [String]) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeStrings(values, vr: vr)
        return DataElement(tag: tag, vr: vr, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with a UInt16 value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - value: The UInt16 value
    /// - Returns: A new data element with US VR
    public static func uint16(tag: Tag, value: UInt16) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeUInt16(value)
        return DataElement(tag: tag, vr: .US, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with multiple UInt16 values
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - values: Array of UInt16 values
    /// - Returns: A new data element with US VR
    public static func uint16s(tag: Tag, values: [UInt16]) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeUInt16s(values)
        return DataElement(tag: tag, vr: .US, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with a UInt32 value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - value: The UInt32 value
    /// - Returns: A new data element with UL VR
    public static func uint32(tag: Tag, value: UInt32) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeUInt32(value)
        return DataElement(tag: tag, vr: .UL, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with multiple UInt32 values
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - values: Array of UInt32 values
    /// - Returns: A new data element with UL VR
    public static func uint32s(tag: Tag, values: [UInt32]) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeUInt32s(values)
        return DataElement(tag: tag, vr: .UL, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with an Int16 value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - value: The Int16 value
    /// - Returns: A new data element with SS VR
    public static func int16(tag: Tag, value: Int16) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeInt16(value)
        return DataElement(tag: tag, vr: .SS, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with an Int32 value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - value: The Int32 value
    /// - Returns: A new data element with SL VR
    public static func int32(tag: Tag, value: Int32) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeInt32(value)
        return DataElement(tag: tag, vr: .SL, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with a Float32 value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - value: The Float32 value
    /// - Returns: A new data element with FL VR
    public static func float32(tag: Tag, value: Float32) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeFloat32(value)
        return DataElement(tag: tag, vr: .FL, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with a Float64 value
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - value: The Float64 value
    /// - Returns: A new data element with FD VR
    public static func float64(tag: Tag, value: Float64) -> DataElement {
        let writer = DICOMWriter()
        let valueData = writer.serializeFloat64(value)
        return DataElement(tag: tag, vr: .FD, length: UInt32(valueData.count), valueData: valueData)
    }
    
    /// Creates a data element with raw binary data
    ///
    /// - Parameters:
    ///   - tag: The data element tag
    ///   - vr: The Value Representation (typically OB or OW)
    ///   - data: The raw binary data
    /// - Returns: A new data element
    public static func data(tag: Tag, vr: VR, data: Data) -> DataElement {
        // Ensure even length by padding if necessary
        var paddedData = data
        if paddedData.count % 2 != 0 {
            paddedData.append(0x00)
        }
        return DataElement(tag: tag, vr: vr, length: UInt32(paddedData.count), valueData: paddedData)
    }
}
