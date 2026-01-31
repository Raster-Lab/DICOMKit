import Testing
import Foundation
@testable import DICOMCore

@Suite("PaletteColorLUT Tests")
struct PaletteColorLUTTests {
    
    // MARK: - Descriptor Tests
    
    @Test("Parse valid descriptor data")
    func testParseValidDescriptor() {
        // Create descriptor data: 256 entries, first value 0, 16 bits per entry
        var data = Data(count: 6)
        data[0] = UInt8(256 & 0xFF)  // Number of entries (low byte)
        data[1] = UInt8((256 >> 8) & 0xFF)  // Number of entries (high byte)
        data[2] = 0  // First mapped value (low byte)
        data[3] = 0  // First mapped value (high byte)
        data[4] = 16 // Bits per entry (low byte)
        data[5] = 0  // Bits per entry (high byte)
        
        let descriptor = PaletteColorLUT.Descriptor.parse(from: data)
        
        #expect(descriptor != nil)
        #expect(descriptor?.numberOfEntries == 256)
        #expect(descriptor?.firstMappedValue == 0)
        #expect(descriptor?.bitsPerEntry == 16)
    }
    
    @Test("Parse descriptor with 8 bits per entry")
    func testParseDescriptorWith8Bits() {
        var data = Data(count: 6)
        data[0] = UInt8(256 & 0xFF)
        data[1] = UInt8((256 >> 8) & 0xFF)
        data[2] = 0
        data[3] = 0
        data[4] = 8  // 8 bits per entry
        data[5] = 0
        
        let descriptor = PaletteColorLUT.Descriptor.parse(from: data)
        
        #expect(descriptor != nil)
        #expect(descriptor?.bitsPerEntry == 8)
    }
    
    @Test("Parse descriptor with zero entries means 65536")
    func testParseDescriptorWithZeroEntries() {
        // Per DICOM PS3.3 C.7.6.3.1.5, a value of 0 means 2^16 entries
        var data = Data(count: 6)
        data[0] = 0  // 0 entries means 65536
        data[1] = 0
        data[2] = 0
        data[3] = 0
        data[4] = 16
        data[5] = 0
        
        let descriptor = PaletteColorLUT.Descriptor.parse(from: data)
        
        #expect(descriptor != nil)
        #expect(descriptor?.numberOfEntries == 65536)
    }
    
    @Test("Parse descriptor with non-zero first mapped value")
    func testParseDescriptorWithNonZeroFirstMappedValue() {
        var data = Data(count: 6)
        data[0] = UInt8(256 & 0xFF)
        data[1] = UInt8((256 >> 8) & 0xFF)
        data[2] = 100  // First mapped value = 100
        data[3] = 0
        data[4] = 16
        data[5] = 0
        
        let descriptor = PaletteColorLUT.Descriptor.parse(from: data)
        
        #expect(descriptor != nil)
        #expect(descriptor?.firstMappedValue == 100)
    }
    
    @Test("Parse descriptor with invalid bits per entry returns nil")
    func testParseDescriptorWithInvalidBitsPerEntry() {
        var data = Data(count: 6)
        data[0] = UInt8(256 & 0xFF)
        data[1] = UInt8((256 >> 8) & 0xFF)
        data[2] = 0
        data[3] = 0
        data[4] = 12  // Invalid - must be 8 or 16
        data[5] = 0
        
        let descriptor = PaletteColorLUT.Descriptor.parse(from: data)
        
        #expect(descriptor == nil)
    }
    
    @Test("Parse descriptor with insufficient data returns nil")
    func testParseDescriptorWithInsufficientData() {
        let data = Data([0, 1, 0, 0])  // Only 4 bytes, need 6
        
        let descriptor = PaletteColorLUT.Descriptor.parse(from: data)
        
        #expect(descriptor == nil)
    }
    
    // MARK: - LUT Data Parsing Tests
    
    @Test("Parse 16-bit LUT data")
    func testParse16BitLUTData() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        // Create 16-bit LUT data (4 entries, little endian)
        var data = Data(count: 8)
        // Entry 0: 0x1000
        data[0] = 0x00
        data[1] = 0x10
        // Entry 1: 0x2000
        data[2] = 0x00
        data[3] = 0x20
        // Entry 2: 0x3000
        data[4] = 0x00
        data[5] = 0x30
        // Entry 3: 0x4000
        data[6] = 0x00
        data[7] = 0x40
        
        let lutData = PaletteColorLUT.parseLUTData(from: data, descriptor: descriptor)
        
        #expect(lutData != nil)
        #expect(lutData?.count == 4)
        #expect(lutData?[0] == 0x1000)
        #expect(lutData?[1] == 0x2000)
        #expect(lutData?[2] == 0x3000)
        #expect(lutData?[3] == 0x4000)
    }
    
    @Test("Parse 8-bit LUT data (byte storage)")
    func testParse8BitLUTDataByteStorage() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 0,
            bitsPerEntry: 8
        )
        
        // Create 8-bit LUT data (4 entries as individual bytes)
        let data = Data([0x10, 0x20, 0x30, 0x40])
        
        let lutData = PaletteColorLUT.parseLUTData(from: data, descriptor: descriptor)
        
        #expect(lutData != nil)
        #expect(lutData?.count == 4)
        // 8-bit values are shifted to high byte
        #expect(lutData?[0] == 0x1000)
        #expect(lutData?[1] == 0x2000)
        #expect(lutData?[2] == 0x3000)
        #expect(lutData?[3] == 0x4000)
    }
    
    @Test("Parse LUT data with insufficient data returns nil")
    func testParseLUTDataWithInsufficientData() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 256,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        // Only 4 bytes, but need 512 for 256 entries with 16 bits each
        let data = Data([0, 0, 0, 0])
        
        let lutData = PaletteColorLUT.parseLUTData(from: data, descriptor: descriptor)
        
        #expect(lutData == nil)
    }
    
    // MARK: - Color Lookup Tests
    
    @Test("Lookup color at beginning of LUT")
    func testLookupColorAtBeginning() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        // RGB LUTs where index 0 = red, 1 = green, 2 = blue, 3 = white
        let redLUT: [UInt16] = [0xFF00, 0x0000, 0x0000, 0xFF00]
        let greenLUT: [UInt16] = [0x0000, 0xFF00, 0x0000, 0xFF00]
        let blueLUT: [UInt16] = [0x0000, 0x0000, 0xFF00, 0xFF00]
        
        let lut = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: redLUT,
            greenLUT: greenLUT,
            blueLUT: blueLUT
        )
        
        // Lookup pixel value 0 (should be red)
        let color0 = lut.lookup(0)
        #expect(color0.red == 255)
        #expect(color0.green == 0)
        #expect(color0.blue == 0)
        
        // Lookup pixel value 1 (should be green)
        let color1 = lut.lookup(1)
        #expect(color1.red == 0)
        #expect(color1.green == 255)
        #expect(color1.blue == 0)
        
        // Lookup pixel value 2 (should be blue)
        let color2 = lut.lookup(2)
        #expect(color2.red == 0)
        #expect(color2.green == 0)
        #expect(color2.blue == 255)
        
        // Lookup pixel value 3 (should be white)
        let color3 = lut.lookup(3)
        #expect(color3.red == 255)
        #expect(color3.green == 255)
        #expect(color3.blue == 255)
    }
    
    @Test("Lookup color with non-zero first mapped value")
    func testLookupColorWithNonZeroFirstMappedValue() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 100,  // LUT starts at pixel value 100
            bitsPerEntry: 16
        )
        
        let redLUT: [UInt16] = [0xFF00, 0x0000, 0x0000, 0xFF00]
        let greenLUT: [UInt16] = [0x0000, 0xFF00, 0x0000, 0xFF00]
        let blueLUT: [UInt16] = [0x0000, 0x0000, 0xFF00, 0xFF00]
        
        let lut = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: redLUT,
            greenLUT: greenLUT,
            blueLUT: blueLUT
        )
        
        // Lookup pixel value 100 (should map to index 0 = red)
        let color100 = lut.lookup(100)
        #expect(color100.red == 255)
        #expect(color100.green == 0)
        #expect(color100.blue == 0)
        
        // Lookup pixel value 101 (should map to index 1 = green)
        let color101 = lut.lookup(101)
        #expect(color101.red == 0)
        #expect(color101.green == 255)
        #expect(color101.blue == 0)
    }
    
    @Test("Lookup color clamps values below first mapped value")
    func testLookupColorClampsBelowRange() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 100,
            bitsPerEntry: 16
        )
        
        let redLUT: [UInt16] = [0xFF00, 0x0000, 0x0000, 0x8000]
        let greenLUT: [UInt16] = [0x0000, 0xFF00, 0x0000, 0x8000]
        let blueLUT: [UInt16] = [0x0000, 0x0000, 0xFF00, 0x8000]
        
        let lut = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: redLUT,
            greenLUT: greenLUT,
            blueLUT: blueLUT
        )
        
        // Lookup pixel value 50 (below first mapped value, should clamp to index 0)
        let colorBelow = lut.lookup(50)
        #expect(colorBelow.red == 255)
        #expect(colorBelow.green == 0)
        #expect(colorBelow.blue == 0)
    }
    
    @Test("Lookup color clamps values above LUT range")
    func testLookupColorClampsAboveRange() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        let redLUT: [UInt16] = [0xFF00, 0x0000, 0x0000, 0x8000]
        let greenLUT: [UInt16] = [0x0000, 0xFF00, 0x0000, 0x8000]
        let blueLUT: [UInt16] = [0x0000, 0x0000, 0xFF00, 0x8000]
        
        let lut = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: redLUT,
            greenLUT: greenLUT,
            blueLUT: blueLUT
        )
        
        // Lookup pixel value 100 (above LUT range of 0-3, should clamp to index 3)
        let colorAbove = lut.lookup(100)
        #expect(colorAbove.red == 128)  // 0x8000 >> 8 = 128
        #expect(colorAbove.green == 128)
        #expect(colorAbove.blue == 128)
    }
    
    // MARK: - Equatable Tests
    
    @Test("PaletteColorLUT equality")
    func testPaletteColorLUTEquality() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        let lut1 = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: [0, 1, 2, 3],
            greenLUT: [0, 1, 2, 3],
            blueLUT: [0, 1, 2, 3]
        )
        
        let lut2 = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: [0, 1, 2, 3],
            greenLUT: [0, 1, 2, 3],
            blueLUT: [0, 1, 2, 3]
        )
        
        #expect(lut1 == lut2)
    }
    
    @Test("PaletteColorLUT inequality")
    func testPaletteColorLUTInequality() {
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: 4,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        let lut1 = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: [0, 1, 2, 3],
            greenLUT: [0, 1, 2, 3],
            blueLUT: [0, 1, 2, 3]
        )
        
        let lut2 = PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: [0, 1, 2, 4],  // Different value
            greenLUT: [0, 1, 2, 3],
            blueLUT: [0, 1, 2, 3]
        )
        
        #expect(lut1 != lut2)
    }
    
    // MARK: - Descriptor Equatable Tests
    
    @Test("Descriptor equality")
    func testDescriptorEquality() {
        let desc1 = PaletteColorLUT.Descriptor(
            numberOfEntries: 256,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        let desc2 = PaletteColorLUT.Descriptor(
            numberOfEntries: 256,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        #expect(desc1 == desc2)
    }
    
    @Test("Descriptor inequality")
    func testDescriptorInequality() {
        let desc1 = PaletteColorLUT.Descriptor(
            numberOfEntries: 256,
            firstMappedValue: 0,
            bitsPerEntry: 16
        )
        
        let desc2 = PaletteColorLUT.Descriptor(
            numberOfEntries: 256,
            firstMappedValue: 10,  // Different first mapped value
            bitsPerEntry: 16
        )
        
        #expect(desc1 != desc2)
    }
}
