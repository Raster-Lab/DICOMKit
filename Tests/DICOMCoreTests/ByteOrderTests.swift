import Testing
import Foundation
@testable import DICOMCore

@Suite("ByteOrder Tests")
struct ByteOrderTests {
    
    // MARK: - Little Endian Tests
    
    @Test("Read UInt16 Little Endian")
    func testReadUInt16LE() {
        var data = Data()
        data.append(0x34)
        data.append(0x12)
        
        let value = data.readUInt16LE(at: 0)
        #expect(value == 0x1234)
    }
    
    @Test("Read UInt32 Little Endian")
    func testReadUInt32LE() {
        var data = Data()
        data.append(0x78)
        data.append(0x56)
        data.append(0x34)
        data.append(0x12)
        
        let value = data.readUInt32LE(at: 0)
        #expect(value == 0x12345678)
    }
    
    @Test("Read Int16 Little Endian")
    func testReadInt16LE() {
        var data = Data()
        data.append(0xFF)
        data.append(0xFF)
        
        let value = data.readInt16LE(at: 0)
        #expect(value == -1)
    }
    
    @Test("Read Int32 Little Endian")
    func testReadInt32LE() {
        var data = Data()
        data.append(0xFF)
        data.append(0xFF)
        data.append(0xFF)
        data.append(0xFF)
        
        let value = data.readInt32LE(at: 0)
        #expect(value == -1)
    }
    
    @Test("Read Float32 Little Endian")
    func testReadFloat32LE() {
        // IEEE 754 representation of 1.0
        var data = Data()
        data.append(0x00)
        data.append(0x00)
        data.append(0x80)
        data.append(0x3F)
        
        let value = data.readFloat32LE(at: 0)
        #expect(value == 1.0)
    }
    
    @Test("Read Float64 Little Endian")
    func testReadFloat64LE() {
        // IEEE 754 representation of 1.0
        var data = Data()
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0xF0)
        data.append(0x3F)
        
        let value = data.readFloat64LE(at: 0)
        #expect(value == 1.0)
    }
    
    @Test("Out of bounds returns nil")
    func testOutOfBounds() {
        let data = Data([0x00, 0x01])
        
        #expect(data.readUInt16LE(at: 1) == nil)
        #expect(data.readUInt32LE(at: 0) == nil)
        #expect(data.readFloat64LE(at: 0) == nil)
    }
    
    // MARK: - Big Endian Tests
    
    @Test("Read UInt16 Big Endian")
    func testReadUInt16BE() {
        var data = Data()
        data.append(0x12)
        data.append(0x34)
        
        let value = data.readUInt16BE(at: 0)
        #expect(value == 0x1234)
    }
    
    @Test("Read UInt32 Big Endian")
    func testReadUInt32BE() {
        var data = Data()
        data.append(0x12)
        data.append(0x34)
        data.append(0x56)
        data.append(0x78)
        
        let value = data.readUInt32BE(at: 0)
        #expect(value == 0x12345678)
    }
    
    @Test("Read Int16 Big Endian")
    func testReadInt16BE() {
        var data = Data()
        data.append(0xFF)
        data.append(0xFF)
        
        let value = data.readInt16BE(at: 0)
        #expect(value == -1)
    }
    
    @Test("Read Int16 Big Endian - positive value")
    func testReadInt16BEPositive() {
        var data = Data()
        data.append(0x00)
        data.append(0x7F)
        
        let value = data.readInt16BE(at: 0)
        #expect(value == 127)
    }
    
    @Test("Read Int32 Big Endian")
    func testReadInt32BE() {
        var data = Data()
        data.append(0xFF)
        data.append(0xFF)
        data.append(0xFF)
        data.append(0xFF)
        
        let value = data.readInt32BE(at: 0)
        #expect(value == -1)
    }
    
    @Test("Read Float32 Big Endian")
    func testReadFloat32BE() {
        // IEEE 754 representation of 1.0 in Big Endian
        var data = Data()
        data.append(0x3F)
        data.append(0x80)
        data.append(0x00)
        data.append(0x00)
        
        let value = data.readFloat32BE(at: 0)
        #expect(value == 1.0)
    }
    
    @Test("Read Float64 Big Endian")
    func testReadFloat64BE() {
        // IEEE 754 representation of 1.0 in Big Endian
        var data = Data()
        data.append(0x3F)
        data.append(0xF0)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        
        let value = data.readFloat64BE(at: 0)
        #expect(value == 1.0)
    }
    
    @Test("Big Endian out of bounds returns nil")
    func testBigEndianOutOfBounds() {
        let data = Data([0x00, 0x01])
        
        #expect(data.readUInt16BE(at: 1) == nil)
        #expect(data.readUInt32BE(at: 0) == nil)
        #expect(data.readFloat64BE(at: 0) == nil)
    }
    
    // MARK: - Byte Order Comparison Tests
    
    @Test("Same bytes produce different results for LE vs BE - UInt16")
    func testByteOrderDifferenceUInt16() {
        let data = Data([0x12, 0x34])
        
        let leValue = data.readUInt16LE(at: 0)
        let beValue = data.readUInt16BE(at: 0)
        
        #expect(leValue == 0x3412)
        #expect(beValue == 0x1234)
        #expect(leValue != beValue)
    }
    
    @Test("Same bytes produce different results for LE vs BE - UInt32")
    func testByteOrderDifferenceUInt32() {
        let data = Data([0x12, 0x34, 0x56, 0x78])
        
        let leValue = data.readUInt32LE(at: 0)
        let beValue = data.readUInt32BE(at: 0)
        
        #expect(leValue == 0x78563412)
        #expect(beValue == 0x12345678)
        #expect(leValue != beValue)
    }
    
    @Test("Read at non-zero offset - Little Endian")
    func testNonZeroOffsetLE() {
        let data = Data([0x00, 0x00, 0x34, 0x12])
        
        let value = data.readUInt16LE(at: 2)
        #expect(value == 0x1234)
    }
    
    @Test("Read at non-zero offset - Big Endian")
    func testNonZeroOffsetBE() {
        let data = Data([0x00, 0x00, 0x12, 0x34])
        
        let value = data.readUInt16BE(at: 2)
        #expect(value == 0x1234)
    }
}
