import Testing
import Foundation
@testable import DICOMCore

@Suite("ByteOrder Tests")
struct ByteOrderTests {
    
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
}
