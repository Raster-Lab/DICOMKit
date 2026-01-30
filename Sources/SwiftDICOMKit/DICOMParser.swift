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
        
        // For v0.1, we don't support undefined length (0xFFFFFFFF)
        guard valueLength != 0xFFFFFFFF else {
            throw DICOMError.parsingFailed("Undefined length elements not supported in v0.1")
        }
        
        // Look up VR from the dictionary
        // If not found, use UN (Unknown) per PS3.5 Section 6.2.2
        let vr: VR
        if let entry = DataElementDictionary.lookup(tag: tag) {
            vr = entry.vr.first ?? .UN
        } else {
            // For unknown tags (both private and standard), use UN
            vr = .UN
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
        
        // Read value data
        // For v0.1, we don't support undefined length (0xFFFFFFFF)
        guard valueLength != 0xFFFFFFFF else {
            throw DICOMError.parsingFailed("Undefined length elements not supported in v0.1")
        }
        
        guard offset + Int(valueLength) <= data.count else {
            throw DICOMError.unexpectedEndOfData
        }
        
        let valueData = data.subdata(in: offset..<offset + Int(valueLength))
        offset += Int(valueLength)
        
        return DataElement(tag: tag, vr: vr, length: valueLength, valueData: valueData)
    }
}
