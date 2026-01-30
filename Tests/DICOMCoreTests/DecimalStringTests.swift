import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMDecimalString Tests")
struct DICOMDecimalStringTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse simple decimal value")
    func testParseSimpleDecimal() {
        let ds = DICOMDecimalString.parse("3.14159")
        #expect(ds != nil)
        #expect(ds?.value == 3.14159)
    }
    
    @Test("Parse integer as decimal")
    func testParseInteger() {
        let ds = DICOMDecimalString.parse("123")
        #expect(ds != nil)
        #expect(ds?.value == 123.0)
    }
    
    @Test("Parse negative value")
    func testParseNegative() {
        let ds = DICOMDecimalString.parse("-456.789")
        #expect(ds != nil)
        #expect(ds?.value == -456.789)
    }
    
    @Test("Parse positive with explicit sign")
    func testParseExplicitPositive() {
        let ds = DICOMDecimalString.parse("+123.45")
        #expect(ds != nil)
        #expect(ds?.value == 123.45)
    }
    
    @Test("Parse scientific notation with lowercase e")
    func testParseScientificLowercase() {
        let ds = DICOMDecimalString.parse("1.5e-2")
        #expect(ds != nil)
        #expect(ds != nil ? abs(ds!.value - 0.015) < 0.0001 : false)
    }
    
    @Test("Parse scientific notation with uppercase E")
    func testParseScientificUppercase() {
        let ds = DICOMDecimalString.parse("2.5E+3")
        #expect(ds != nil)
        #expect(ds?.value == 2500.0)
    }
    
    @Test("Parse zero")
    func testParseZero() {
        let ds = DICOMDecimalString.parse("0")
        #expect(ds != nil)
        #expect(ds?.value == 0.0)
        
        let dsZeroDecimal = DICOMDecimalString.parse("0.0")
        #expect(dsZeroDecimal != nil)
        #expect(dsZeroDecimal?.value == 0.0)
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let ds = DICOMDecimalString.parse("  3.14  ")
        #expect(ds != nil)
        #expect(ds?.value == 3.14)
    }
    
    @Test("Parse boundary values")
    func testParseBoundaryValues() {
        // Very small positive
        let small = DICOMDecimalString.parse("1e-10")
        #expect(small != nil)
        #expect(small?.value == 1e-10)
        
        // Large value
        let large = DICOMDecimalString.parse("1e10")
        #expect(large != nil)
        #expect(large?.value == 1e10)
    }
    
    @Test("Reject invalid formats")
    func testRejectInvalidFormats() {
        // Empty string
        #expect(DICOMDecimalString.parse("") == nil)
        
        // Only whitespace
        #expect(DICOMDecimalString.parse("   ") == nil)
        
        // Invalid characters
        #expect(DICOMDecimalString.parse("abc") == nil)
        #expect(DICOMDecimalString.parse("12.3.4") == nil)
        
        // Multiple signs
        #expect(DICOMDecimalString.parse("++123") == nil)
        #expect(DICOMDecimalString.parse("--123") == nil)
        
        // Too long (> 16 characters)
        #expect(DICOMDecimalString.parse("12345678901234567") == nil)
    }
    
    // MARK: - Multiple Values Tests
    
    @Test("Parse multiple values")
    func testParseMultiple() {
        let values = DICOMDecimalString.parseMultiple("1.0\\2.5\\3.14159")
        #expect(values != nil)
        #expect(values?.count == 3)
        #expect(values?[0].value == 1.0)
        #expect(values?[1].value == 2.5)
        #expect(values?[2].value == 3.14159)
    }
    
    @Test("Parse single value as multiple")
    func testParseSingleAsMultiple() {
        let values = DICOMDecimalString.parseMultiple("42.5")
        #expect(values != nil)
        #expect(values?.count == 1)
        #expect(values?[0].value == 42.5)
    }
    
    @Test("Reject invalid multiple values")
    func testRejectInvalidMultiple() {
        // One invalid value causes entire parse to fail
        #expect(DICOMDecimalString.parseMultiple("1.0\\invalid\\3.0") == nil)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Direct initialization")
    func testInitialization() {
        let ds = DICOMDecimalString(value: 3.14159)
        #expect(ds.value == 3.14159)
    }
    
    @Test("ExpressibleByFloatLiteral")
    func testFloatLiteralInit() {
        let ds: DICOMDecimalString = 2.71828
        #expect(ds.value == 2.71828)
    }
    
    // MARK: - Conversion Tests
    
    @Test("Float value conversion")
    func testFloatValue() {
        let ds = DICOMDecimalString(value: 3.14159)
        let floatVal = ds.floatValue
        #expect(abs(floatVal - 3.14159) < 0.001)
    }
    
    @Test("Int value conversion (truncation)")
    func testIntValue() {
        let ds = DICOMDecimalString(value: 3.999)
        #expect(ds.intValue == 3)
        
        let negative = DICOMDecimalString(value: -2.5)
        #expect(negative.intValue == -2)
    }
    
    // MARK: - String Output Tests
    
    @Test("DICOM string format")
    func testDicomString() {
        let ds = DICOMDecimalString(value: 3.14159)
        let dicomStr = ds.dicomString
        #expect(dicomStr.count <= 16)
        
        // Round-trip check
        if let reparsed = DICOMDecimalString.parse(dicomStr) {
            #expect(abs(reparsed.value - 3.14159) < 0.0001)
        } else {
            #expect(Bool(false), "Failed to reparse DICOM string")
        }
    }
    
    @Test("CustomStringConvertible")
    func testDescription() {
        let ds = DICOMDecimalString.parse("3.14159")
        #expect(ds?.description == "3.14159")
    }
    
    @Test("Original string preservation")
    func testOriginalStringPreservation() {
        let ds = DICOMDecimalString.parse("  00123.450  ")
        #expect(ds != nil)
        #expect(ds?.originalString == "00123.450")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let ds1 = DICOMDecimalString(value: 3.14)
        let ds2 = DICOMDecimalString(value: 3.14)
        let ds3 = DICOMDecimalString(value: 2.71)
        
        #expect(ds1 == ds2)
        #expect(ds1 != ds3)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let ds1 = DICOMDecimalString(value: 3.14)
        let ds2 = DICOMDecimalString(value: 3.14)
        
        // Equal values should have equal hash values
        #expect(ds1.hashValue == ds2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMDecimalString> = [ds1, ds2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable ordering")
    func testComparable() {
        let ds1 = DICOMDecimalString(value: 1.0)
        let ds2 = DICOMDecimalString(value: 2.0)
        let ds3 = DICOMDecimalString(value: -1.0)
        
        #expect(ds1 < ds2)
        #expect(ds2 > ds1)
        #expect(ds3 < ds1)
    }
    
    @Test("Comparable with equal values")
    func testComparableEqual() {
        let ds1 = DICOMDecimalString(value: 3.14)
        let ds2 = DICOMDecimalString(value: 3.14)
        
        #expect(!(ds1 < ds2))
        #expect(!(ds1 > ds2))
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip")
    func testRoundTrip() {
        let testCases = ["0", "1.5", "-2.5", "3.14159", "1e-5", "1.23E+4"]
        
        for original in testCases {
            let parsed = DICOMDecimalString.parse(original)
            #expect(parsed != nil, "Failed to parse: \(original)")
            
            if let ds = parsed {
                // Reparse the DICOM string output
                let reparsed = DICOMDecimalString.parse(ds.dicomString)
                #expect(reparsed != nil, "Failed to reparse: \(ds.dicomString)")
                
                // Values should be approximately equal
                if let rp = reparsed {
                    #expect(abs(ds.value - rp.value) < 0.0001)
                }
            }
        }
    }
    
    // MARK: - Practical Usage Tests
    
    @Test("Typical DICOM pixel spacing value")
    func testPixelSpacing() {
        // Pixel spacing is commonly stored as DS
        let pixelSpacing = DICOMDecimalString.parseMultiple("0.3125\\0.3125")
        #expect(pixelSpacing != nil)
        #expect(pixelSpacing?.count == 2)
        #expect(pixelSpacing?[0].value == 0.3125)
        #expect(pixelSpacing?[1].value == 0.3125)
    }
    
    @Test("Typical DICOM slice thickness value")
    func testSliceThickness() {
        let thickness = DICOMDecimalString.parse("2.5")
        #expect(thickness != nil)
        #expect(thickness?.value == 2.5)
    }
}
