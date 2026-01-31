import Foundation

/// Utilities for reading byte data with different endianness
///
/// DICOM uses Little Endian byte ordering for most Transfer Syntaxes,
/// but also supports Big Endian for the retired Explicit VR Big Endian Transfer Syntax.
/// Reference: PS3.5 Section 7.1.1 - Little Endian Byte Ordering
/// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering (Retired)
extension Data {
    /// Reads a 16-bit unsigned integer in Little Endian byte order
    /// - Parameter offset: Byte offset to read from
    /// - Returns: UInt16 value, or nil if offset is out of bounds
    public func readUInt16LE(at offset: Int) -> UInt16? {
        guard offset + 2 <= count else {
            return nil
        }
        
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        
        return byte0 | (byte1 << 8)
    }
    
    /// Reads a 32-bit unsigned integer in Little Endian byte order
    /// - Parameter offset: Byte offset to read from
    /// - Returns: UInt32 value, or nil if offset is out of bounds
    public func readUInt32LE(at offset: Int) -> UInt32? {
        guard offset + 4 <= count else {
            return nil
        }
        
        let byte0 = UInt32(self[offset])
        let byte1 = UInt32(self[offset + 1])
        let byte2 = UInt32(self[offset + 2])
        let byte3 = UInt32(self[offset + 3])
        
        return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
    }
    
    /// Reads a 16-bit signed integer in Little Endian byte order
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Int16 value, or nil if offset is out of bounds
    public func readInt16LE(at offset: Int) -> Int16? {
        guard let value = readUInt16LE(at: offset) else {
            return nil
        }
        return Int16(bitPattern: value)
    }
    
    /// Reads a 32-bit signed integer in Little Endian byte order
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Int32 value, or nil if offset is out of bounds
    public func readInt32LE(at offset: Int) -> Int32? {
        guard let value = readUInt32LE(at: offset) else {
            return nil
        }
        return Int32(bitPattern: value)
    }
    
    /// Reads a 32-bit floating point number in Little Endian byte order
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Float32 value, or nil if offset is out of bounds
    public func readFloat32LE(at offset: Int) -> Float32? {
        guard let bits = readUInt32LE(at: offset) else {
            return nil
        }
        return Float32(bitPattern: bits)
    }
    
    /// Reads a 64-bit floating point number in Little Endian byte order
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Float64 value, or nil if offset is out of bounds
    public func readFloat64LE(at offset: Int) -> Float64? {
        guard offset + 8 <= count else {
            return nil
        }
        
        let byte0 = UInt64(self[offset])
        let byte1 = UInt64(self[offset + 1])
        let byte2 = UInt64(self[offset + 2])
        let byte3 = UInt64(self[offset + 3])
        let byte4 = UInt64(self[offset + 4])
        let byte5 = UInt64(self[offset + 5])
        let byte6 = UInt64(self[offset + 6])
        let byte7 = UInt64(self[offset + 7])
        
        let bits = byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24) |
                   (byte4 << 32) | (byte5 << 40) | (byte6 << 48) | (byte7 << 56)
        
        return Float64(bitPattern: bits)
    }
    
    // MARK: - Big Endian Byte Reading
    
    /// Reads a 16-bit unsigned integer in Big Endian byte order
    ///
    /// Used by the retired Explicit VR Big Endian Transfer Syntax (1.2.840.10008.1.2.2).
    /// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering
    /// - Parameter offset: Byte offset to read from
    /// - Returns: UInt16 value, or nil if offset is out of bounds
    public func readUInt16BE(at offset: Int) -> UInt16? {
        guard offset + 2 <= count else {
            return nil
        }
        
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        
        return (byte0 << 8) | byte1
    }
    
    /// Reads a 32-bit unsigned integer in Big Endian byte order
    ///
    /// Used by the retired Explicit VR Big Endian Transfer Syntax (1.2.840.10008.1.2.2).
    /// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering
    /// - Parameter offset: Byte offset to read from
    /// - Returns: UInt32 value, or nil if offset is out of bounds
    public func readUInt32BE(at offset: Int) -> UInt32? {
        guard offset + 4 <= count else {
            return nil
        }
        
        let byte0 = UInt32(self[offset])
        let byte1 = UInt32(self[offset + 1])
        let byte2 = UInt32(self[offset + 2])
        let byte3 = UInt32(self[offset + 3])
        
        return (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | byte3
    }
    
    /// Reads a 16-bit signed integer in Big Endian byte order
    ///
    /// Used by the retired Explicit VR Big Endian Transfer Syntax (1.2.840.10008.1.2.2).
    /// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Int16 value, or nil if offset is out of bounds
    public func readInt16BE(at offset: Int) -> Int16? {
        guard let value = readUInt16BE(at: offset) else {
            return nil
        }
        return Int16(bitPattern: value)
    }
    
    /// Reads a 32-bit signed integer in Big Endian byte order
    ///
    /// Used by the retired Explicit VR Big Endian Transfer Syntax (1.2.840.10008.1.2.2).
    /// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Int32 value, or nil if offset is out of bounds
    public func readInt32BE(at offset: Int) -> Int32? {
        guard let value = readUInt32BE(at: offset) else {
            return nil
        }
        return Int32(bitPattern: value)
    }
    
    /// Reads a 32-bit floating point number in Big Endian byte order
    ///
    /// Used by the retired Explicit VR Big Endian Transfer Syntax (1.2.840.10008.1.2.2).
    /// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Float32 value, or nil if offset is out of bounds
    public func readFloat32BE(at offset: Int) -> Float32? {
        guard let bits = readUInt32BE(at: offset) else {
            return nil
        }
        return Float32(bitPattern: bits)
    }
    
    /// Reads a 64-bit floating point number in Big Endian byte order
    ///
    /// Used by the retired Explicit VR Big Endian Transfer Syntax (1.2.840.10008.1.2.2).
    /// Reference: PS3.5 Section 7.1.2 - Big Endian Byte Ordering
    /// - Parameter offset: Byte offset to read from
    /// - Returns: Float64 value, or nil if offset is out of bounds
    public func readFloat64BE(at offset: Int) -> Float64? {
        guard offset + 8 <= count else {
            return nil
        }
        
        let byte0 = UInt64(self[offset])
        let byte1 = UInt64(self[offset + 1])
        let byte2 = UInt64(self[offset + 2])
        let byte3 = UInt64(self[offset + 3])
        let byte4 = UInt64(self[offset + 4])
        let byte5 = UInt64(self[offset + 5])
        let byte6 = UInt64(self[offset + 6])
        let byte7 = UInt64(self[offset + 7])
        
        let bits = (byte0 << 56) | (byte1 << 48) | (byte2 << 40) | (byte3 << 32) |
                   (byte4 << 24) | (byte5 << 16) | (byte6 << 8) | byte7
        
        return Float64(bitPattern: bits)
    }
}
