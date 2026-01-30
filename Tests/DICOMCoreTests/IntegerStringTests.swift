import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMIntegerString Tests")
struct DICOMIntegerStringTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse simple positive integer")
    func testParsePositive() {
        let is_value = DICOMIntegerString.parse("123")
        #expect(is_value != nil)
        #expect(is_value?.value == 123)
    }
    
    @Test("Parse negative integer")
    func testParseNegative() {
        let is_value = DICOMIntegerString.parse("-456")
        #expect(is_value != nil)
        #expect(is_value?.value == -456)
    }
    
    @Test("Parse positive with explicit sign")
    func testParseExplicitPositive() {
        let is_value = DICOMIntegerString.parse("+789")
        #expect(is_value != nil)
        #expect(is_value?.value == 789)
    }
    
    @Test("Parse zero")
    func testParseZero() {
        let is_value = DICOMIntegerString.parse("0")
        #expect(is_value != nil)
        #expect(is_value?.value == 0)
    }
    
    @Test("Parse with leading zeros")
    func testParseLeadingZeros() {
        let is_value = DICOMIntegerString.parse("00123")
        #expect(is_value != nil)
        #expect(is_value?.value == 123)
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let is_value = DICOMIntegerString.parse("  42  ")
        #expect(is_value != nil)
        #expect(is_value?.value == 42)
    }
    
    @Test("Parse boundary values (Int32 range)")
    func testParseBoundaryValues() {
        // Maximum Int32 value
        let maxVal = DICOMIntegerString.parse("2147483647")
        #expect(maxVal != nil)
        #expect(maxVal?.value == Int(Int32.max))
        
        // Minimum Int32 value
        let minVal = DICOMIntegerString.parse("-2147483648")
        #expect(minVal != nil)
        #expect(minVal?.value == Int(Int32.min))
    }
    
    @Test("Reject values outside Int32 range")
    func testRejectOutOfRange() {
        // Just above Int32.max
        #expect(DICOMIntegerString.parse("2147483648") == nil)
        
        // Just below Int32.min
        #expect(DICOMIntegerString.parse("-2147483649") == nil)
        
        // Way out of range
        #expect(DICOMIntegerString.parse("99999999999") == nil)
    }
    
    @Test("Reject invalid formats")
    func testRejectInvalidFormats() {
        // Empty string
        #expect(DICOMIntegerString.parse("") == nil)
        
        // Only whitespace
        #expect(DICOMIntegerString.parse("   ") == nil)
        
        // Decimal point (IS doesn't support decimals)
        #expect(DICOMIntegerString.parse("123.45") == nil)
        
        // Scientific notation (IS doesn't support it)
        #expect(DICOMIntegerString.parse("1e5") == nil)
        
        // Invalid characters
        #expect(DICOMIntegerString.parse("abc") == nil)
        #expect(DICOMIntegerString.parse("12a34") == nil)
        
        // Multiple signs
        #expect(DICOMIntegerString.parse("++123") == nil)
        #expect(DICOMIntegerString.parse("--123") == nil)
        
        // Too long (> 12 characters)
        #expect(DICOMIntegerString.parse("1234567890123") == nil)
    }
    
    // MARK: - Multiple Values Tests
    
    @Test("Parse multiple values")
    func testParseMultiple() {
        let values = DICOMIntegerString.parseMultiple("1\\2\\3")
        #expect(values != nil)
        #expect(values?.count == 3)
        #expect(values?[0].value == 1)
        #expect(values?[1].value == 2)
        #expect(values?[2].value == 3)
    }
    
    @Test("Parse single value as multiple")
    func testParseSingleAsMultiple() {
        let values = DICOMIntegerString.parseMultiple("42")
        #expect(values != nil)
        #expect(values?.count == 1)
        #expect(values?[0].value == 42)
    }
    
    @Test("Parse multiple with negative values")
    func testParseMultipleWithNegatives() {
        let values = DICOMIntegerString.parseMultiple("-1\\0\\+1")
        #expect(values != nil)
        #expect(values?.count == 3)
        #expect(values?[0].value == -1)
        #expect(values?[1].value == 0)
        #expect(values?[2].value == 1)
    }
    
    @Test("Reject invalid multiple values")
    func testRejectInvalidMultiple() {
        // One invalid value causes entire parse to fail
        #expect(DICOMIntegerString.parseMultiple("1\\invalid\\3") == nil)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Direct initialization")
    func testInitialization() {
        let is_value = DICOMIntegerString(value: 42)
        #expect(is_value.value == 42)
    }
    
    @Test("ExpressibleByIntegerLiteral")
    func testIntegerLiteralInit() {
        let is_value: DICOMIntegerString = 123
        #expect(is_value.value == 123)
    }
    
    // MARK: - Conversion Tests
    
    @Test("Int32 value conversion")
    func testInt32Value() {
        let is_value = DICOMIntegerString(value: 12345)
        #expect(is_value.int32Value == 12345)
        
        let negative = DICOMIntegerString(value: -12345)
        #expect(negative.int32Value == -12345)
    }
    
    @Test("UInt16 value conversion - valid range")
    func testUInt16ValueValid() {
        let is_value = DICOMIntegerString(value: 65535)
        #expect(is_value.uint16Value == 65535)
        
        let zero = DICOMIntegerString(value: 0)
        #expect(zero.uint16Value == 0)
    }
    
    @Test("UInt16 value conversion - out of range")
    func testUInt16ValueOutOfRange() {
        let negative = DICOMIntegerString(value: -1)
        #expect(negative.uint16Value == nil)
        
        let tooLarge = DICOMIntegerString(value: 65536)
        #expect(tooLarge.uint16Value == nil)
    }
    
    // MARK: - String Output Tests
    
    @Test("DICOM string format")
    func testDicomString() {
        let is_value = DICOMIntegerString(value: 42)
        #expect(is_value.dicomString == "42")
        
        let negative = DICOMIntegerString(value: -123)
        #expect(negative.dicomString == "-123")
        
        let zero = DICOMIntegerString(value: 0)
        #expect(zero.dicomString == "0")
    }
    
    @Test("CustomStringConvertible")
    func testDescription() {
        let is_value = DICOMIntegerString.parse("12345")
        #expect(is_value?.description == "12345")
    }
    
    @Test("Original string preservation")
    func testOriginalStringPreservation() {
        let is_value = DICOMIntegerString.parse("  00123  ")
        #expect(is_value != nil)
        #expect(is_value?.originalString == "00123")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let is1 = DICOMIntegerString(value: 42)
        let is2 = DICOMIntegerString(value: 42)
        let is3 = DICOMIntegerString(value: 43)
        
        #expect(is1 == is2)
        #expect(is1 != is3)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let is1 = DICOMIntegerString(value: 42)
        let is2 = DICOMIntegerString(value: 42)
        
        // Equal values should have equal hash values
        #expect(is1.hashValue == is2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMIntegerString> = [is1, is2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable ordering")
    func testComparable() {
        let is1 = DICOMIntegerString(value: 1)
        let is2 = DICOMIntegerString(value: 2)
        let is3 = DICOMIntegerString(value: -1)
        
        #expect(is1 < is2)
        #expect(is2 > is1)
        #expect(is3 < is1)
    }
    
    @Test("Comparable with equal values")
    func testComparableEqual() {
        let is1 = DICOMIntegerString(value: 42)
        let is2 = DICOMIntegerString(value: 42)
        
        #expect(!(is1 < is2))
        #expect(!(is1 > is2))
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip")
    func testRoundTrip() {
        let testCases = ["0", "1", "-1", "12345", "-67890", "+123"]
        
        for original in testCases {
            let parsed = DICOMIntegerString.parse(original)
            #expect(parsed != nil, "Failed to parse: \(original)")
            
            if let is_value = parsed {
                // Reparse the DICOM string output
                let reparsed = DICOMIntegerString.parse(is_value.dicomString)
                #expect(reparsed != nil, "Failed to reparse: \(is_value.dicomString)")
                
                // Values should be equal
                if let rp = reparsed {
                    #expect(is_value.value == rp.value)
                }
            }
        }
    }
    
    // MARK: - Practical Usage Tests
    
    @Test("Typical DICOM instance number")
    func testInstanceNumber() {
        // Instance Number is commonly stored as IS
        let instanceNumber = DICOMIntegerString.parse("1")
        #expect(instanceNumber != nil)
        #expect(instanceNumber?.value == 1)
    }
    
    @Test("Typical DICOM series number")
    func testSeriesNumber() {
        let seriesNumber = DICOMIntegerString.parse("3")
        #expect(seriesNumber != nil)
        #expect(seriesNumber?.value == 3)
    }
    
    @Test("Typical DICOM rows/columns values")
    func testRowsColumns() {
        // Rows and Columns can be represented as IS
        let rows = DICOMIntegerString.parse("512")
        #expect(rows != nil)
        #expect(rows?.value == 512)
        #expect(rows?.uint16Value == 512)
        
        let cols = DICOMIntegerString.parse("512")
        #expect(cols != nil)
        #expect(cols?.value == 512)
        #expect(cols?.uint16Value == 512)
    }
}
