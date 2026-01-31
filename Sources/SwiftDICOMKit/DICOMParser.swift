import Foundation
import DICOMCore
import DICOMDictionary

/// Internal parser for DICOM files
///
/// Parses DICOM Part 10 files with supported transfer syntaxes including:
/// - Explicit VR Little Endian (1.2.840.10008.1.2.1)
/// - Implicit VR Little Endian (1.2.840.10008.1.2)
/// - Explicit VR Big Endian (1.2.840.10008.1.2.2) - Retired
/// - Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99)
///
/// Reference: PS3.10 Section 7 - DICOM File Format
struct DICOMParser {
    private var data: Data
    private var offset: Int
    
    init(data: Data) {
        self.data = data
        self.offset = 0
    }
    
    /// Parses File Meta Information elements
    ///
    /// File Meta Information elements are always encoded with Explicit VR Little Endian,
    /// regardless of the transfer syntax used for the main data set.
    /// Reference: PS3.10 Section 7.1
    mutating func parseFileMetaInformation(startOffset: Int) throws -> DataSet {
        offset = startOffset
        var elements: [DataElement] = []
        
        // File Meta Information starts after DICM prefix (offset 132)
        // Group 0002 elements only
        while offset < data.count {
            // Peek at the group number (always Little Endian for File Meta Information)
            guard let groupNumber = data.readUInt16LE(at: offset) else {
                break
            }
            
            // Stop when we're past group 0002
            if groupNumber != 0x0002 {
                break
            }
            
            // Parse this element (File Meta Info is always Explicit VR Little Endian)
            guard let element = try? parseExplicitVRElement(byteOrder: .littleEndian) else {
                break
            }
            
            elements.append(element)
        }
        
        return DataSet(elements: elements)
    }
    
    /// Parses main data set elements
    ///
    /// Parses data elements using the specified transfer syntax encoding.
    /// Reference: PS3.5 Section 7.1 - Data Element Structure
    mutating func parseDataSet(transferSyntaxUID: String) throws -> DataSet {
        // Determine transfer syntax
        guard let transferSyntax = TransferSyntax.from(uid: transferSyntaxUID) else {
            throw DICOMError.unsupportedTransferSyntax(transferSyntaxUID)
        }
        
        // Handle deflated data
        if transferSyntax.isDeflated {
            try decompressDeflatedData()
        }
        
        let isExplicitVR = transferSyntax.isExplicitVR
        let byteOrder = transferSyntax.byteOrder
        
        var elements: [DataElement] = []
        
        // Parse elements until we reach the end or pixel data
        while offset < data.count {
            // Stop at pixel data (7FE0,0010) for v0.1
            guard let groupNumber = readUInt16(at: offset, byteOrder: byteOrder) else {
                break
            }
            guard let elementNumber = readUInt16(at: offset + 2, byteOrder: byteOrder) else {
                break
            }
            
            // Stop at pixel data
            if groupNumber == 0x7FE0 && elementNumber == 0x0010 {
                break
            }
            
            // Parse this element
            let element: DataElement
            if isExplicitVR {
                guard let parsed = try? parseExplicitVRElement(byteOrder: byteOrder) else {
                    break
                }
                element = parsed
            } else {
                guard let parsed = try? parseImplicitVRElement(byteOrder: byteOrder) else {
                    break
                }
                element = parsed
            }
            
            elements.append(element)
        }
        
        return DataSet(elements: elements)
    }
    
    // MARK: - Byte Order Helpers
    
    /// Reads a 16-bit unsigned integer with the specified byte order
    private func readUInt16(at offset: Int, byteOrder: ByteOrder) -> UInt16? {
        switch byteOrder {
        case .littleEndian:
            return data.readUInt16LE(at: offset)
        case .bigEndian:
            return data.readUInt16BE(at: offset)
        }
    }
    
    /// Reads a 32-bit unsigned integer with the specified byte order
    private func readUInt32(at offset: Int, byteOrder: ByteOrder) -> UInt32? {
        switch byteOrder {
        case .littleEndian:
            return data.readUInt32LE(at: offset)
        case .bigEndian:
            return data.readUInt32BE(at: offset)
        }
    }
    
    // MARK: - Deflate Decompression
    
    /// Decompresses deflated data starting at the current offset
    ///
    /// The File Meta Information is not deflated, only the Data Set portion.
    /// Reference: PS3.5 Section A.5
    private mutating func decompressDeflatedData() throws {
        // Get the deflated portion (everything from current offset to end)
        let deflatedData = data.subdata(in: offset..<data.count)
        
        // Decompress using zlib
        guard let decompressedData = deflatedData.decompress() else {
            throw DICOMError.parsingFailed("Failed to decompress deflated data")
        }
        
        // Replace the data from current offset with decompressed data
        let headerData = data.subdata(in: 0..<offset)
        data = headerData + decompressedData
    }
    
    /// Parses a single data element with Implicit VR encoding
    ///
    /// In Implicit VR encoding, the VR is not explicitly specified in the data stream
    /// and must be determined from the Data Element Dictionary.
    /// Reference: PS3.5 Section 7.1.3 - Data Element Structure with Implicit VR
    private mutating func parseImplicitVRElement(byteOrder: ByteOrder) throws -> DataElement {
        // Read tag (4 bytes)
        guard let groupNumber = readUInt16(at: offset, byteOrder: byteOrder) else {
            throw DICOMError.unexpectedEndOfData
        }
        guard let elementNumber = readUInt16(at: offset + 2, byteOrder: byteOrder) else {
            throw DICOMError.unexpectedEndOfData
        }
        offset += 4
        
        let tag = Tag(group: groupNumber, element: elementNumber)
        
        // Read value length (4 bytes) - Implicit VR always uses 32-bit length
        // Reference: PS3.5 Section 7.1.3
        guard let valueLength = readUInt32(at: offset, byteOrder: byteOrder) else {
            throw DICOMError.unexpectedEndOfData
        }
        offset += 4
        
        // Look up VR from the dictionary
        // If not found, use UN (Unknown) per PS3.5 Section 6.2.2
        let vr: VR
        if let entry = DataElementDictionary.lookup(tag: tag) {
            vr = entry.vr.first ?? .UN
        } else {
            // For unknown tags (both private and standard), use UN
            vr = .UN
        }
        
        // Handle sequence elements (SQ VR)
        if vr == .SQ {
            return try parseSequenceElement(tag: tag, vr: vr, valueLength: valueLength, isExplicitVR: false, byteOrder: byteOrder)
        }
        
        // Handle undefined length for non-sequence elements - skip to delimiter
        if valueLength == 0xFFFFFFFF {
            throw DICOMError.parsingFailed("Undefined length for non-sequence elements not supported")
        }
        
        guard offset + Int(valueLength) <= data.count else {
            throw DICOMError.unexpectedEndOfData
        }
        
        let valueData = data.subdata(in: offset..<offset + Int(valueLength))
        offset += Int(valueLength)
        
        return DataElement(tag: tag, vr: vr, length: valueLength, valueData: valueData)
    }
    
    /// Parses a single data element with Explicit VR encoding
    ///
    /// Reference: PS3.5 Section 7.1.2 - Data Element Structure with Explicit VR
    private mutating func parseExplicitVRElement(byteOrder: ByteOrder) throws -> DataElement {
        // Read tag (4 bytes)
        guard let groupNumber = readUInt16(at: offset, byteOrder: byteOrder) else {
            throw DICOMError.unexpectedEndOfData
        }
        guard let elementNumber = readUInt16(at: offset + 2, byteOrder: byteOrder) else {
            throw DICOMError.unexpectedEndOfData
        }
        offset += 4
        
        let tag = Tag(group: groupNumber, element: elementNumber)
        
        // Read VR (2 bytes, ASCII characters)
        guard offset + 2 <= data.count else {
            throw DICOMError.unexpectedEndOfData
        }
        
        let vrByte0 = data[offset]
        let vrByte1 = data[offset + 1]
        offset += 2
        
        guard let vrString = String(bytes: [vrByte0, vrByte1], encoding: .ascii),
              let vr = VR(rawValue: vrString) else {
            throw DICOMError.invalidVR(String(format: "%02X%02X", vrByte0, vrByte1))
        }
        
        // Read value length
        // For VRs with 32-bit length: skip 2 reserved bytes, then read 4-byte length
        // For VRs with 16-bit length: read 2-byte length
        // Reference: PS3.5 Section 7.1.2
        let valueLength: UInt32
        if vr.uses32BitLength {
            // Skip 2 reserved bytes
            offset += 2
            
            guard let length32 = readUInt32(at: offset, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 4
            valueLength = length32
        } else {
            guard let length16 = readUInt16(at: offset, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 2
            valueLength = UInt32(length16)
        }
        
        // Handle sequence elements (SQ VR)
        if vr == .SQ {
            return try parseSequenceElement(tag: tag, vr: vr, valueLength: valueLength, isExplicitVR: true, byteOrder: byteOrder)
        }
        
        // Handle undefined length for non-sequence elements
        if valueLength == 0xFFFFFFFF {
            throw DICOMError.parsingFailed("Undefined length for non-sequence elements not supported")
        }
        
        guard offset + Int(valueLength) <= data.count else {
            throw DICOMError.unexpectedEndOfData
        }
        
        let valueData = data.subdata(in: offset..<offset + Int(valueLength))
        offset += Int(valueLength)
        
        return DataElement(tag: tag, vr: vr, length: valueLength, valueData: valueData)
    }
    
    // MARK: - Sequence Parsing
    
    /// Parses a sequence element (SQ VR) and its items
    ///
    /// Sequences can have either explicit length or undefined length (0xFFFFFFFF).
    /// Each item in the sequence is delimited by Item tags (FFFE,E000).
    /// Undefined length sequences end with Sequence Delimitation Item (FFFE,E0DD).
    ///
    /// Reference: PS3.5 Section 7.5 - Nesting of Data Sets
    private mutating func parseSequenceElement(tag: Tag, vr: VR, valueLength: UInt32, isExplicitVR: Bool, byteOrder: ByteOrder) throws -> DataElement {
        let startOffset = offset
        var sequenceItems: [SequenceItem] = []
        
        if valueLength == 0xFFFFFFFF {
            // Undefined length sequence - parse until Sequence Delimitation Item
            sequenceItems = try parseUndefinedLengthSequence(isExplicitVR: isExplicitVR, byteOrder: byteOrder)
        } else {
            // Explicit length sequence
            let endOffset = offset + Int(valueLength)
            sequenceItems = try parseExplicitLengthSequence(endOffset: endOffset, isExplicitVR: isExplicitVR, byteOrder: byteOrder)
        }
        
        // Get the raw value data (for completeness)
        let valueData = data.subdata(in: startOffset..<offset)
        
        return DataElement(
            tag: tag,
            vr: vr,
            length: valueLength,
            valueData: valueData,
            sequenceItems: sequenceItems
        )
    }
    
    /// Parses a sequence with explicit length
    ///
    /// The sequence ends when we reach the specified end offset.
    /// Reference: PS3.5 Section 7.5.2
    private mutating func parseExplicitLengthSequence(endOffset: Int, isExplicitVR: Bool, byteOrder: ByteOrder) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        while offset < endOffset && offset < data.count {
            // Read item tag
            guard let groupNumber = readUInt16(at: offset, byteOrder: byteOrder) else {
                break
            }
            guard let elementNumber = readUInt16(at: offset + 2, byteOrder: byteOrder) else {
                break
            }
            
            let itemTag = Tag(group: groupNumber, element: elementNumber)
            
            // Must be Item tag (FFFE,E000)
            guard itemTag == .item else {
                // Not an item tag - we're done with the sequence
                break
            }
            
            offset += 4
            
            // Read item length
            guard let itemLength = readUInt32(at: offset, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 4
            
            // Parse item contents
            let item = try parseSequenceItem(itemLength: itemLength, isExplicitVR: isExplicitVR, byteOrder: byteOrder)
            items.append(item)
        }
        
        // Ensure we've consumed all the sequence data
        if offset < endOffset {
            offset = endOffset
        }
        
        return items
    }
    
    /// Parses a sequence with undefined length
    ///
    /// The sequence ends with Sequence Delimitation Item (FFFE,E0DD).
    /// Reference: PS3.5 Section 7.5.1
    private mutating func parseUndefinedLengthSequence(isExplicitVR: Bool, byteOrder: ByteOrder) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        while offset < data.count {
            // Read tag
            guard let groupNumber = readUInt16(at: offset, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            guard let elementNumber = readUInt16(at: offset + 2, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            
            let itemTag = Tag(group: groupNumber, element: elementNumber)
            
            // Check for Sequence Delimitation Item
            if itemTag == .sequenceDelimitationItem {
                offset += 4
                // Read and skip the length (should be 0)
                offset += 4
                break
            }
            
            // Must be Item tag (FFFE,E000)
            guard itemTag == .item else {
                throw DICOMError.parsingFailed("Expected Item tag (FFFE,E000) in sequence, found \(itemTag)")
            }
            
            offset += 4
            
            // Read item length
            guard let itemLength = readUInt32(at: offset, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 4
            
            // Parse item contents
            let item = try parseSequenceItem(itemLength: itemLength, isExplicitVR: isExplicitVR, byteOrder: byteOrder)
            items.append(item)
        }
        
        return items
    }
    
    /// Parses a single sequence item
    ///
    /// Items can have explicit length or undefined length (0xFFFFFFFF).
    /// Undefined length items end with Item Delimitation Item (FFFE,E00D).
    ///
    /// Reference: PS3.5 Section 7.5.2 & 7.5.3
    private mutating func parseSequenceItem(itemLength: UInt32, isExplicitVR: Bool, byteOrder: ByteOrder) throws -> SequenceItem {
        var elements: [DataElement] = []
        
        if itemLength == 0xFFFFFFFF {
            // Undefined length item - parse until Item Delimitation Item
            elements = try parseUndefinedLengthItem(isExplicitVR: isExplicitVR, byteOrder: byteOrder)
        } else {
            // Explicit length item
            let itemEndOffset = offset + Int(itemLength)
            elements = try parseExplicitLengthItem(endOffset: itemEndOffset, isExplicitVR: isExplicitVR, byteOrder: byteOrder)
        }
        
        return SequenceItem(elements: elements)
    }
    
    /// Parses an item with explicit length
    private mutating func parseExplicitLengthItem(endOffset: Int, isExplicitVR: Bool, byteOrder: ByteOrder) throws -> [DataElement] {
        var elements: [DataElement] = []
        
        while offset < endOffset && offset < data.count {
            let element: DataElement
            if isExplicitVR {
                element = try parseExplicitVRElement(byteOrder: byteOrder)
            } else {
                element = try parseImplicitVRElement(byteOrder: byteOrder)
            }
            elements.append(element)
        }
        
        // Ensure we've consumed all the item data
        if offset < endOffset {
            offset = endOffset
        }
        
        return elements
    }
    
    /// Parses an item with undefined length
    ///
    /// Ends with Item Delimitation Item (FFFE,E00D).
    private mutating func parseUndefinedLengthItem(isExplicitVR: Bool, byteOrder: ByteOrder) throws -> [DataElement] {
        var elements: [DataElement] = []
        
        while offset < data.count {
            // Peek at tag
            guard let groupNumber = readUInt16(at: offset, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            guard let elementNumber = readUInt16(at: offset + 2, byteOrder: byteOrder) else {
                throw DICOMError.unexpectedEndOfData
            }
            
            let nextTag = Tag(group: groupNumber, element: elementNumber)
            
            // Check for Item Delimitation Item
            if nextTag == .itemDelimitationItem {
                offset += 4
                // Read and skip the length (should be 0)
                offset += 4
                break
            }
            
            // Parse the element
            let element: DataElement
            if isExplicitVR {
                element = try parseExplicitVRElement(byteOrder: byteOrder)
            } else {
                element = try parseImplicitVRElement(byteOrder: byteOrder)
            }
            elements.append(element)
        }
        
        return elements
    }
}

// MARK: - Data Decompression Extension

#if canImport(Compression)
import Compression

extension Data {
    /// Decompresses data using the deflate algorithm (RFC 1951)
    ///
    /// Uses Foundation's built-in compression support via the Compression framework.
    /// Reference: PS3.5 Section A.5 - Deflated Explicit VR Little Endian
    func decompress() -> Data? {
        // For DICOM deflated data, we use raw DEFLATE (no zlib header)
        // The data should be pure deflate-compressed bytes
        return self.withUnsafeBytes { sourceBuffer in
            guard let sourcePointer = sourceBuffer.baseAddress else {
                return nil
            }
            
            // Allocate destination buffer - start with 4x source size as initial estimate
            let destinationCapacity = max(count * 4, 64 * 1024)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationCapacity)
            defer { destinationBuffer.deallocate() }
            
            // Decompress using compression framework
            let decompressedSize = compression_decode_buffer(
                destinationBuffer,
                destinationCapacity,
                sourcePointer.assumingMemoryBound(to: UInt8.self),
                count,
                nil,
                COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else {
                return nil
            }
            
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
}

#else

extension Data {
    /// Decompresses data using the deflate algorithm (RFC 1951)
    ///
    /// On platforms without Compression framework, this returns nil.
    /// The deflated transfer syntax will be reported as unsupported.
    /// Reference: PS3.5 Section A.5 - Deflated Explicit VR Little Endian
    func decompress() -> Data? {
        // Decompression not available on this platform
        // The parser will throw an appropriate error
        return nil
    }
}

#endif
