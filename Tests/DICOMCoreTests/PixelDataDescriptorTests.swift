import Testing
import Foundation
@testable import DICOMCore

@Suite("PixelDataDescriptor Tests")
struct PixelDataDescriptorTests {
    
    // MARK: - Initialization Tests
    
    @Test("Create descriptor for 8-bit monochrome image")
    func testCreate8BitMonochromeDescriptor() {
        let descriptor = PixelDataDescriptor(
            rows: 512,
            columns: 512,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            photometricInterpretation: .monochrome2
        )
        
        #expect(descriptor.rows == 512)
        #expect(descriptor.columns == 512)
        #expect(descriptor.numberOfFrames == 1)
        #expect(descriptor.bitsAllocated == 8)
        #expect(descriptor.bitsStored == 8)
        #expect(descriptor.highBit == 7)
        #expect(descriptor.isSigned == false)
        #expect(descriptor.samplesPerPixel == 1)
        #expect(descriptor.photometricInterpretation == .monochrome2)
        #expect(descriptor.planarConfiguration == 0)
    }
    
    @Test("Create descriptor for 16-bit signed CT image")
    func testCreate16BitSignedDescriptor() {
        let descriptor = PixelDataDescriptor(
            rows: 512,
            columns: 512,
            numberOfFrames: 1,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: true,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2,
            planarConfiguration: 0
        )
        
        #expect(descriptor.bitsAllocated == 16)
        #expect(descriptor.bitsStored == 12)
        #expect(descriptor.highBit == 11)
        #expect(descriptor.isSigned == true)
    }
    
    @Test("Create descriptor for RGB image")
    func testCreateRGBDescriptor() {
        let descriptor = PixelDataDescriptor(
            rows: 256,
            columns: 256,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 3,
            photometricInterpretation: .rgb,
            planarConfiguration: 0
        )
        
        #expect(descriptor.samplesPerPixel == 3)
        #expect(descriptor.photometricInterpretation == .rgb)
    }
    
    @Test("Create descriptor for multi-frame image")
    func testCreateMultiFrameDescriptor() {
        let descriptor = PixelDataDescriptor(
            rows: 512,
            columns: 512,
            numberOfFrames: 100,
            bitsAllocated: 16,
            bitsStored: 16,
            highBit: 15,
            isSigned: false,
            photometricInterpretation: .monochrome2
        )
        
        #expect(descriptor.numberOfFrames == 100)
        #expect(descriptor.isMultiFrame == true)
    }
    
    // MARK: - Computed Property Tests
    
    @Test("bytesPerSample for 8-bit")
    func testBytesPerSampleFor8Bit() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.bytesPerSample == 1)
    }
    
    @Test("bytesPerSample for 16-bit")
    func testBytesPerSampleFor16Bit() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.bytesPerSample == 2)
    }
    
    @Test("bytesPerPixel for monochrome")
    func testBytesPerPixelForMonochrome() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.bytesPerPixel == 2)
    }
    
    @Test("bytesPerPixel for RGB")
    func testBytesPerPixelForRGB() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 3, photometricInterpretation: .rgb
        )
        #expect(descriptor.bytesPerPixel == 3)
    }
    
    @Test("pixelsPerFrame")
    func testPixelsPerFrame() {
        let descriptor = PixelDataDescriptor(
            rows: 512, columns: 256, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.pixelsPerFrame == 512 * 256)
    }
    
    @Test("bytesPerFrame for monochrome")
    func testBytesPerFrameForMonochrome() {
        let descriptor = PixelDataDescriptor(
            rows: 512, columns: 512, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.bytesPerFrame == 512 * 512 * 2)
    }
    
    @Test("totalBytes for multi-frame")
    func testTotalBytesForMultiFrame() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, numberOfFrames: 10, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.totalBytes == 256 * 256 * 2 * 10)
    }
    
    @Test("storedBitMask for 12-bit")
    func testStoredBitMaskFor12Bit() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.storedBitMask == 0x0FFF)
    }
    
    @Test("storedBitMask for 16-bit")
    func testStoredBitMaskFor16Bit() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 16, highBit: 15,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.storedBitMask == 0xFFFF)
    }
    
    @Test("minPossibleValue for unsigned")
    func testMinPossibleValueForUnsigned() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.minPossibleValue == 0)
    }
    
    @Test("minPossibleValue for signed")
    func testMinPossibleValueForSigned() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: true, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.minPossibleValue == -2048)
    }
    
    @Test("maxPossibleValue for unsigned")
    func testMaxPossibleValueForUnsigned() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.maxPossibleValue == 4095)
    }
    
    @Test("maxPossibleValue for signed")
    func testMaxPossibleValueForSigned() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, bitsAllocated: 16, bitsStored: 12, highBit: 11,
            isSigned: true, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.maxPossibleValue == 2047)
    }
    
    @Test("isMultiFrame false for single frame")
    func testIsMultiFrameFalseForSingleFrame() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, numberOfFrames: 1, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.isMultiFrame == false)
    }
    
    @Test("Zero frames becomes one")
    func testZeroFramesBecomesOne() {
        let descriptor = PixelDataDescriptor(
            rows: 256, columns: 256, numberOfFrames: 0, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, photometricInterpretation: .monochrome2
        )
        #expect(descriptor.numberOfFrames == 1)
    }
}
