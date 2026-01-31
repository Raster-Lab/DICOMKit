import Testing
import Foundation
@testable import DICOMCore

@Suite("PhotometricInterpretation Tests")
struct PhotometricInterpretationTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse MONOCHROME1")
    func testParseMonochrome1() {
        let pi = PhotometricInterpretation.parse("MONOCHROME1")
        #expect(pi == .monochrome1)
    }
    
    @Test("Parse MONOCHROME2")
    func testParseMonochrome2() {
        let pi = PhotometricInterpretation.parse("MONOCHROME2")
        #expect(pi == .monochrome2)
    }
    
    @Test("Parse RGB")
    func testParseRGB() {
        let pi = PhotometricInterpretation.parse("RGB")
        #expect(pi == .rgb)
    }
    
    @Test("Parse PALETTE COLOR")
    func testParsePaletteColor() {
        let pi = PhotometricInterpretation.parse("PALETTE COLOR")
        #expect(pi == .paletteColor)
    }
    
    @Test("Parse YBR_FULL")
    func testParseYBRFull() {
        let pi = PhotometricInterpretation.parse("YBR_FULL")
        #expect(pi == .ybrFull)
    }
    
    @Test("Parse with whitespace")
    func testParseWithWhitespace() {
        let pi = PhotometricInterpretation.parse("  MONOCHROME2  ")
        #expect(pi == .monochrome2)
    }
    
    @Test("Parse invalid returns nil")
    func testParseInvalidReturnsNil() {
        let pi = PhotometricInterpretation.parse("INVALID")
        #expect(pi == nil)
    }
    
    // MARK: - Property Tests
    
    @Test("isMonochrome for MONOCHROME1")
    func testIsMonochromeForMonochrome1() {
        #expect(PhotometricInterpretation.monochrome1.isMonochrome == true)
        #expect(PhotometricInterpretation.monochrome1.isColor == false)
    }
    
    @Test("isMonochrome for MONOCHROME2")
    func testIsMonochromeForMonochrome2() {
        #expect(PhotometricInterpretation.monochrome2.isMonochrome == true)
        #expect(PhotometricInterpretation.monochrome2.isColor == false)
    }
    
    @Test("isColor for RGB")
    func testIsColorForRGB() {
        #expect(PhotometricInterpretation.rgb.isMonochrome == false)
        #expect(PhotometricInterpretation.rgb.isColor == true)
    }
    
    @Test("isColor for PALETTE COLOR")
    func testIsColorForPaletteColor() {
        #expect(PhotometricInterpretation.paletteColor.isMonochrome == false)
        #expect(PhotometricInterpretation.paletteColor.isColor == true)
    }
    
    @Test("expectedSamplesPerPixel for monochrome")
    func testExpectedSamplesPerPixelForMonochrome() {
        #expect(PhotometricInterpretation.monochrome1.expectedSamplesPerPixel == 1)
        #expect(PhotometricInterpretation.monochrome2.expectedSamplesPerPixel == 1)
    }
    
    @Test("expectedSamplesPerPixel for color")
    func testExpectedSamplesPerPixelForColor() {
        #expect(PhotometricInterpretation.rgb.expectedSamplesPerPixel == 3)
        #expect(PhotometricInterpretation.paletteColor.expectedSamplesPerPixel == 3)
        #expect(PhotometricInterpretation.ybrFull.expectedSamplesPerPixel == 3)
    }
    
    // MARK: - Equatable and Hashable
    
    @Test("Equality")
    func testEquality() {
        #expect(PhotometricInterpretation.monochrome2 == PhotometricInterpretation.monochrome2)
        #expect(PhotometricInterpretation.monochrome1 != PhotometricInterpretation.monochrome2)
    }
    
    @Test("Hashable")
    func testHashable() {
        var set = Set<PhotometricInterpretation>()
        set.insert(.monochrome1)
        set.insert(.monochrome2)
        set.insert(.monochrome1)
        #expect(set.count == 2)
    }
}
