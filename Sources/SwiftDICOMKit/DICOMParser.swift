import Foundation
import DICOMCore
import DICOMDictionary

/// Internal parser for DICOM files
///
/// Parses DICOM Part 10 files with Explicit VR or Implicit VR Little Endian transfer syntax.
/// Reference: PS3.10 Section 7 - DICOM File Format
struct DICOMParser {
    private let data: Data
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
            // Peek at the group number
            guard let groupNumber = data.readUInt16LE(at: offset) else {
                break
            }
            
            // Stop when we're past group 0002
            if groupNumber != 0x0002 {
                break
            }
            
            // Parse this element
            guard let element = try? parseExplicitVRElement() else {
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
        let isExplicitVR: Bool
        switch transferSyntaxUID {
        case "1.2.840.10008.1.2.1":
            // Explicit VR Little Endian
            isExplicitVR = true
        case "1.2.840.10008.1.2":
            // Implicit VR Little Endian
            isExplicitVR = false
        default:
            throw DICOMError.unsupportedTransferSyntax(transferSyntaxUID)
        }
        
        var elements: [DataElement] = []
        
        // Parse elements until we reach the end or pixel data
        while offset < data.count {
            // Stop at pixel data (7FE0,0010) for v0.1
            guard let groupNumber = data.readUInt16LE(at: offset) else {
                break
            }
            guard let elementNumber = data.readUInt16LE(at: offset + 2) else {
                break
            }
            
            // Stop at pixel data
            if groupNumber == 0x7FE0 && elementNumber == 0x0010 {
                break
            }
            
            // Parse this element
            let element: DataElement
            if isExplicitVR {
                guard let parsed = try? parseExplicitVRElement() else {
                    break
                }
                element = parsed
            } else {
                guard let parsed = try? parseImplicitVRElement() else {
                    break
                }
                element = parsed
            }
            
            elements.append(element)
        }
        
        return DataSet(elements: elements)
    }
    
    /// Parses a single data element with Implicit VR encoding
    ///
    /// In Implicit VR encoding, the VR is not explicitly specified in the data stream
    /// and must be determined from the Data Element Dictionary.
    /// Reference: PS3.5 Section 7.1.3 - Data Element Structure with Implicit VR
    private mutating func parseImplicitVRElement() throws -> DataElement {
        // Read tag (4 bytes)
        guard let groupNumber = data.readUInt16LE(at: offset) else {
            throw DICOMError.unexpectedEndOfData
        }
        guard let elementNumber = data.readUInt16LE(at: offset + 2) else {
            throw DICOMError.unexpectedEndOfData
        }
        offset += 4
        
        let tag = Tag(group: groupNumber, element: elementNumber)
        
        // Read value length (4 bytes) - Implicit VR always uses 32-bit length
        // Reference: PS3.5 Section 7.1.3
        guard let valueLength = data.readUInt32LE(at: offset) else {
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
            return try parseSequenceElement(tag: tag, vr: vr, valueLength: valueLength, isExplicitVR: false)
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
    private mutating func parseExplicitVRElement() throws -> DataElement {
        // Read tag (4 bytes)
        guard let groupNumber = data.readUInt16LE(at: offset) else {
            throw DICOMError.unexpectedEndOfData
        }
        guard let elementNumber = data.readUInt16LE(at: offset + 2) else {
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
            
            guard let length32 = data.readUInt32LE(at: offset) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 4
            valueLength = length32
        } else {
            guard let length16 = data.readUInt16LE(at: offset) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 2
            valueLength = UInt32(length16)
        }
        
        // Handle sequence elements (SQ VR)
        if vr == .SQ {
            return try parseSequenceElement(tag: tag, vr: vr, valueLength: valueLength, isExplicitVR: true)
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
    private mutating func parseSequenceElement(tag: Tag, vr: VR, valueLength: UInt32, isExplicitVR: Bool) throws -> DataElement {
        let startOffset = offset
        var sequenceItems: [SequenceItem] = []
        
        if valueLength == 0xFFFFFFFF {
            // Undefined length sequence - parse until Sequence Delimitation Item
            sequenceItems = try parseUndefinedLengthSequence(isExplicitVR: isExplicitVR)
        } else {
            // Explicit length sequence
            let endOffset = offset + Int(valueLength)
            sequenceItems = try parseExplicitLengthSequence(endOffset: endOffset, isExplicitVR: isExplicitVR)
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
    private mutating func parseExplicitLengthSequence(endOffset: Int, isExplicitVR: Bool) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        while offset < endOffset && offset < data.count {
            // Read item tag
            guard let groupNumber = data.readUInt16LE(at: offset) else {
                break
            }
            guard let elementNumber = data.readUInt16LE(at: offset + 2) else {
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
            guard let itemLength = data.readUInt32LE(at: offset) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 4
            
            // Parse item contents
            let item = try parseSequenceItem(itemLength: itemLength, isExplicitVR: isExplicitVR)
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
    private mutating func parseUndefinedLengthSequence(isExplicitVR: Bool) throws -> [SequenceItem] {
        var items: [SequenceItem] = []
        
        while offset < data.count {
            // Read tag
            guard let groupNumber = data.readUInt16LE(at: offset) else {
                throw DICOMError.unexpectedEndOfData
            }
            guard let elementNumber = data.readUInt16LE(at: offset + 2) else {
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
            guard let itemLength = data.readUInt32LE(at: offset) else {
                throw DICOMError.unexpectedEndOfData
            }
            offset += 4
            
            // Parse item contents
            let item = try parseSequenceItem(itemLength: itemLength, isExplicitVR: isExplicitVR)
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
    private mutating func parseSequenceItem(itemLength: UInt32, isExplicitVR: Bool) throws -> SequenceItem {
        var elements: [DataElement] = []
        
        if itemLength == 0xFFFFFFFF {
            // Undefined length item - parse until Item Delimitation Item
            elements = try parseUndefinedLengthItem(isExplicitVR: isExplicitVR)
        } else {
            // Explicit length item
            let itemEndOffset = offset + Int(itemLength)
            elements = try parseExplicitLengthItem(endOffset: itemEndOffset, isExplicitVR: isExplicitVR)
        }
        
        return SequenceItem(elements: elements)
    }
    
    /// Parses an item with explicit length
    private mutating func parseExplicitLengthItem(endOffset: Int, isExplicitVR: Bool) throws -> [DataElement] {
        var elements: [DataElement] = []
        
        while offset < endOffset && offset < data.count {
            let element: DataElement
            if isExplicitVR {
                element = try parseExplicitVRElement()
            } else {
                element = try parseImplicitVRElement()
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
    private mutating func parseUndefinedLengthItem(isExplicitVR: Bool) throws -> [DataElement] {
        var elements: [DataElement] = []
        
        while offset < data.count {
            // Peek at tag
            guard let groupNumber = data.readUInt16LE(at: offset) else {
                throw DICOMError.unexpectedEndOfData
            }
            guard let elementNumber = data.readUInt16LE(at: offset + 2) else {
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
                element = try parseExplicitVRElement()
            } else {
                element = try parseImplicitVRElement()
            }
            elements.append(element)
        }
        
        return elements
    }
}
