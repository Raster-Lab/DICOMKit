import Foundation

/// DICOM Data Element
///
/// A data element is a unit of information as defined by a single entry in the data dictionary.
/// It consists of a tag, VR, length, and value field.
///
/// Reference: DICOM PS3.5 Section 7.1 - Data Element Structure
public struct DataElement: Sendable {
    /// Data element tag (group, element pair)
    public let tag: Tag
    
    /// Value Representation
    public let vr: VR
    
    /// Value length in bytes
    ///
    /// The value 0xFFFFFFFF (4294967295) indicates an undefined length.
    /// Reference: PS3.5 Section 7.1.2
    public let length: UInt32
    
    /// Raw value data
    public let valueData: Data
    
    /// Creates a new data element
    /// - Parameters:
    ///   - tag: Data element tag
    ///   - vr: Value Representation
    ///   - length: Value length (use 0xFFFFFFFF for undefined length)
    ///   - valueData: Raw value data
    public init(tag: Tag, vr: VR, length: UInt32, valueData: Data) {
        self.tag = tag
        self.vr = vr
        self.length = length
        self.valueData = valueData
    }
    
    /// Indicates whether this data element has undefined length
    ///
    /// Reference: PS3.5 Section 7.1.2 - Data Element with Explicit Length
    public var hasUndefinedLength: Bool {
        return length == 0xFFFFFFFF
    }
    
    /// Extracts the value as a string (for string-based VRs)
    ///
    /// Returns nil if the VR doesn't support string values or if decoding fails.
    /// Trims leading/trailing whitespace per DICOM conventions.
    public var stringValue: String? {
        guard vr.characterRepertoire != nil else {
            return nil
        }
        
        guard let string = String(data: valueData, encoding: .utf8) else {
            return nil
        }
        
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Extracts multiple string values (for multi-valued string VRs)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2
    public var stringValues: [String]? {
        guard let value = stringValue else {
            return nil
        }
        
        return value.split(separator: "\\").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// Extracts the value as a 16-bit unsigned integer (for US VR)
    public var uint16Value: UInt16? {
        guard vr == .US && valueData.count >= 2 else {
            return nil
        }
        return valueData.readUInt16LE(at: 0)
    }
    
    /// Extracts the value as a 32-bit unsigned integer (for UL VR)
    public var uint32Value: UInt32? {
        guard vr == .UL && valueData.count >= 4 else {
            return nil
        }
        return valueData.readUInt32LE(at: 0)
    }
    
    /// Extracts the value as a 16-bit signed integer (for SS VR)
    public var int16Value: Int16? {
        guard vr == .SS && valueData.count >= 2 else {
            return nil
        }
        return valueData.readInt16LE(at: 0)
    }
    
    /// Extracts the value as a 32-bit signed integer (for SL VR)
    public var int32Value: Int32? {
        guard vr == .SL && valueData.count >= 4 else {
            return nil
        }
        return valueData.readInt32LE(at: 0)
    }
    
    /// Extracts the value as a 32-bit floating point (for FL VR)
    public var float32Value: Float32? {
        guard vr == .FL && valueData.count >= 4 else {
            return nil
        }
        return valueData.readFloat32LE(at: 0)
    }
    
    /// Extracts the value as a 64-bit floating point (for FD VR)
    public var float64Value: Float64? {
        guard vr == .FD && valueData.count >= 8 else {
            return nil
        }
        return valueData.readFloat64LE(at: 0)
    }
}
