import Testing
import Foundation
@testable import DICOMCore

@Suite("PixelData Tests")
struct PixelDataTests {
    
    // MARK: - Basic Creation Tests
    
    @Test("Create pixel data with descriptor")
    func testCreatePixelData() {
        let descriptor = PixelDataDescriptor(
            rows: 4, columns: 4, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data(repeating: 128, count: 16)
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        #expect(pixelData.data.count == 16)
        #expect(pixelData.descriptor.rows == 4)
        #expect(pixelData.descriptor.columns == 4)
    }
    
    // MARK: - Frame Access Tests
    
    @Test("frameData returns correct bytes for single frame")
    func testFrameDataSingleFrame() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([10, 20, 30, 40])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let frameData = pixelData.frameData(at: 0)
        #expect(frameData != nil)
        #expect(frameData!.count == 4)
        #expect(frameData![0] == 10)
        #expect(frameData![3] == 40)
    }
    
    @Test("frameData returns correct bytes for multi-frame")
    func testFrameDataMultiFrame() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, numberOfFrames: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([10, 20, 30, 40, 50, 60, 70, 80])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let frame0 = pixelData.frameData(at: 0)
        let frame1 = pixelData.frameData(at: 1)
        
        #expect(frame0![0] == 10)
        #expect(frame1![0] == 50)
    }
    
    @Test("frameData returns nil for invalid index")
    func testFrameDataInvalidIndex() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([10, 20, 30, 40])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        #expect(pixelData.frameData(at: -1) == nil)
        #expect(pixelData.frameData(at: 1) == nil)
    }
    
    // MARK: - Pixel Value Tests
    
    @Test("pixelValues for 8-bit unsigned")
    func testPixelValues8BitUnsigned() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([0, 100, 200, 255])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let values = pixelData.pixelValues(forFrame: 0)
        #expect(values != nil)
        #expect(values! == [0, 100, 200, 255])
    }
    
    @Test("pixelValues for 16-bit unsigned")
    func testPixelValues16BitUnsigned() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        // Little endian: [0x00, 0x00] = 0, [0xFF, 0x00] = 255, [0x00, 0x01] = 256, [0xFF, 0xFF] = 65535
        let data = Data([0x00, 0x00, 0xFF, 0x00, 0x00, 0x01, 0xFF, 0xFF])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let values = pixelData.pixelValues(forFrame: 0)
        #expect(values != nil)
        #expect(values! == [0, 255, 256, 65535])
    }
    
    @Test("pixelValues for 12-bit in 16-bit allocation")
    func testPixelValues12Bit() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        // 12-bit values: 0, 2047, 4095, 1000
        // In 16-bit little endian
        let data = Data([
            0x00, 0x00,  // 0
            0xFF, 0x07,  // 2047 (0x07FF)
            0xFF, 0x0F,  // 4095 (0x0FFF)
            0xE8, 0x03   // 1000 (0x03E8)
        ])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let values = pixelData.pixelValues(forFrame: 0)
        #expect(values != nil)
        #expect(values! == [0, 2047, 4095, 1000])
    }
    
    @Test("pixelValues for signed 16-bit")
    func testPixelValuesSigned16Bit() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: true, photometricInterpretation: .monochrome2
        )
        
        // Signed values: 0, 100, -100 (0xFF9C), -1 (0xFFFF)
        let data = Data([
            0x00, 0x00,  // 0
            0x64, 0x00,  // 100
            0x9C, 0xFF,  // -100
            0xFF, 0xFF   // -1
        ])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let values = pixelData.pixelValues(forFrame: 0)
        #expect(values != nil)
        #expect(values![0] == 0)
        #expect(values![1] == 100)
        #expect(values![2] == -100)
        #expect(values![3] == -1)
    }
    
    // MARK: - Single Pixel Access Tests
    
    @Test("pixelValue at specific location")
    func testPixelValueAtLocation() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 3, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        // 2x3 image:
        // [10, 20, 30]
        // [40, 50, 60]
        let data = Data([10, 20, 30, 40, 50, 60])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        #expect(pixelData.pixelValue(row: 0, column: 0) == 10)
        #expect(pixelData.pixelValue(row: 0, column: 1) == 20)
        #expect(pixelData.pixelValue(row: 0, column: 2) == 30)
        #expect(pixelData.pixelValue(row: 1, column: 0) == 40)
        #expect(pixelData.pixelValue(row: 1, column: 1) == 50)
        #expect(pixelData.pixelValue(row: 1, column: 2) == 60)
    }
    
    @Test("pixelValue returns nil for out of bounds")
    func testPixelValueOutOfBounds() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([10, 20, 30, 40])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        #expect(pixelData.pixelValue(row: -1, column: 0) == nil)
        #expect(pixelData.pixelValue(row: 0, column: -1) == nil)
        #expect(pixelData.pixelValue(row: 2, column: 0) == nil)
        #expect(pixelData.pixelValue(row: 0, column: 2) == nil)
    }
    
    // MARK: - Color Value Tests
    
    @Test("colorValue for RGB image")
    func testColorValueRGB() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 3, photometricInterpretation: .rgb, planarConfiguration: 0
        )
        
        // RGB pixel data (color-by-pixel): R1G1B1 R2G2B2 ...
        let data = Data([
            255, 0, 0,     // Pixel 0,0: Red
            0, 255, 0,     // Pixel 0,1: Green
            0, 0, 255,     // Pixel 1,0: Blue
            255, 255, 255  // Pixel 1,1: White
        ])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let color00 = pixelData.colorValue(row: 0, column: 0)
        #expect(color00 != nil)
        #expect(color00!.red == 255)
        #expect(color00!.green == 0)
        #expect(color00!.blue == 0)
        
        let color01 = pixelData.colorValue(row: 0, column: 1)
        #expect(color01 != nil)
        #expect(color01!.red == 0)
        #expect(color01!.green == 255)
        #expect(color01!.blue == 0)
    }
    
    @Test("colorValue returns nil for monochrome")
    func testColorValueReturnsNilForMonochrome() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([10, 20, 30, 40])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        #expect(pixelData.colorValue(row: 0, column: 0) == nil)
    }
    
    // MARK: - Statistics Tests
    
    @Test("pixelRange calculates min and max")
    func testPixelRange() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([50, 100, 25, 200])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let range = pixelData.pixelRange(forFrame: 0)
        #expect(range != nil)
        #expect(range!.min == 25)
        #expect(range!.max == 200)
    }
    
    @Test("pixelRange for signed values")
    func testPixelRangeSigned() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: true, photometricInterpretation: .monochrome2
        )
        
        // Values: -100, 0, 100, -50
        let data = Data([
            0x9C, 0xFF,  // -100
            0x00, 0x00,  // 0
            0x64, 0x00,  // 100
            0xCE, 0xFF   // -50
        ])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let range = pixelData.pixelRange(forFrame: 0)
        #expect(range != nil)
        #expect(range!.min == -100)
        #expect(range!.max == 100)
    }
    
    // MARK: - All Pixel Values Tests
    
    @Test("allPixelValues for multi-frame")
    func testAllPixelValues() {
        let descriptor = PixelDataDescriptor(
            rows: 2, columns: 2, numberOfFrames: 2, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        
        let data = Data([10, 20, 30, 40, 50, 60, 70, 80])
        let pixelData = PixelData(data: data, descriptor: descriptor)
        
        let allValues = pixelData.allPixelValues()
        #expect(allValues != nil)
        #expect(allValues!.count == 2)
        #expect(allValues![0] == [10, 20, 30, 40])
        #expect(allValues![1] == [50, 60, 70, 80])
    }
}
