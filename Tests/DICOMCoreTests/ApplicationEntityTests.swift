import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMApplicationEntity Tests")
struct DICOMApplicationEntityTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse standard AE Title")
    func testParseStandardAETitle() {
        let ae = DICOMApplicationEntity.parse("STORESCU")
        #expect(ae != nil)
        #expect(ae?.value == "STORESCU")
    }
    
    @Test("Parse AE Title with underscores")
    func testParseAETitleWithUnderscores() {
        let ae = DICOMApplicationEntity.parse("MY_PACS_SERVER")
        #expect(ae != nil)
        #expect(ae?.value == "MY_PACS_SERVER")
    }
    
    @Test("Parse AE Title with numbers")
    func testParseAETitleWithNumbers() {
        let ae = DICOMApplicationEntity.parse("DICOM123")
        #expect(ae != nil)
        #expect(ae?.value == "DICOM123")
    }
    
    @Test("Parse AE Title with mixed case")
    func testParseAETitleMixedCase() {
        let ae = DICOMApplicationEntity.parse("MyDicomApp")
        #expect(ae != nil)
        #expect(ae?.value == "MyDicomApp")
    }
    
    @Test("Parse maximum length AE Title (16 characters)")
    func testParseMaximumLengthAETitle() {
        let ae = DICOMApplicationEntity.parse("1234567890123456")
        #expect(ae != nil)
        #expect(ae?.value.count == 16)
        #expect(ae?.length == 16)
    }
    
    @Test("Parse single character AE Title")
    func testParseSingleCharacter() {
        let ae = DICOMApplicationEntity.parse("A")
        #expect(ae != nil)
        #expect(ae?.value == "A")
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let ae = DICOMApplicationEntity.parse("  STORESCU  ")
        #expect(ae != nil)
        #expect(ae?.value == "STORESCU")
    }
    
    @Test("Parse with null padding (common in DICOM)")
    func testParseWithNullPadding() {
        let ae = DICOMApplicationEntity.parse("STORESCU\0\0")
        #expect(ae != nil)
        #expect(ae?.value == "STORESCU")
    }
    
    @Test("Parse empty string returns empty AE")
    func testParseEmptyString() {
        let ae = DICOMApplicationEntity.parse("")
        #expect(ae != nil)
        #expect(ae?.value == "")
        #expect(ae?.isEmpty == true)
    }
    
    @Test("Parse whitespace-only string returns empty AE")
    func testParseWhitespaceOnly() {
        let ae = DICOMApplicationEntity.parse("   ")
        #expect(ae != nil)
        #expect(ae?.value == "")
        #expect(ae?.isEmpty == true)
    }
    
    @Test("Parse AE Title with all valid special characters")
    func testParseWithSpecialCharacters() {
        // Test various allowed ASCII characters
        let ae = DICOMApplicationEntity.parse("A-B.C_D!E@F")
        #expect(ae != nil)
        #expect(ae?.value == "A-B.C_D!E@F")
    }
    
    // MARK: - Validation Tests
    
    @Test("Reject AE Title exceeding maximum length")
    func testRejectOverlengthAETitle() {
        // 17 characters is too long
        let ae = DICOMApplicationEntity.parse("12345678901234567")
        #expect(ae == nil)
    }
    
    @Test("Reject AE Title with backslash")
    func testRejectBackslash() {
        let ae = DICOMApplicationEntity.parse("STORE\\SCU")
        #expect(ae == nil)
    }
    
    @Test("Reject AE Title with control characters")
    func testRejectControlCharacters() {
        // Tab character
        let aeTab = DICOMApplicationEntity.parse("STORE\tSCU")
        #expect(aeTab == nil)
        
        // Newline
        let aeNewline = DICOMApplicationEntity.parse("STORE\nSCU")
        #expect(aeNewline == nil)
        
        // Carriage return
        let aeCR = DICOMApplicationEntity.parse("STORE\rSCU")
        #expect(aeCR == nil)
    }
    
    @Test("Reject AE Title with non-ASCII characters")
    func testRejectNonASCII() {
        // Unicode character
        let ae = DICOMApplicationEntity.parse("STORE©SCU")
        #expect(ae == nil)
        
        // Extended ASCII
        let ae2 = DICOMApplicationEntity.parse("STOREéSCU")
        #expect(ae2 == nil)
    }
    
    @Test("Accept AE Title with various printable ASCII")
    func testAcceptPrintableASCII() {
        // Various printable ASCII characters that should be valid
        let validChars = "!#$%&'()*+,-./:;<=>?@[]^_`{|}~"
        for char in validChars {
            let ae = DICOMApplicationEntity.parse("A\(char)B")
            #expect(ae != nil, "Should accept '\(char)'")
        }
    }
    
    // MARK: - Multiple Values Tests
    
    @Test("Parse multiple AE Titles")
    func testParseMultiple() {
        let aes = DICOMApplicationEntity.parseMultiple("STORESCU\\STORESCP")
        #expect(aes != nil)
        #expect(aes?.count == 2)
        #expect(aes?[0].value == "STORESCU")
        #expect(aes?[1].value == "STORESCP")
    }
    
    @Test("Parse single AE Title as multiple returns single element")
    func testParseSingleAsMultiple() {
        let aes = DICOMApplicationEntity.parseMultiple("STORESCU")
        #expect(aes != nil)
        #expect(aes?.count == 1)
        #expect(aes?[0].value == "STORESCU")
    }
    
    @Test("Parse multiple with invalid AE returns nil")
    func testParseMultipleWithInvalid() {
        // One AE exceeds maximum length
        let aes = DICOMApplicationEntity.parseMultiple("STORESCU\\12345678901234567")
        #expect(aes == nil)
    }
    
    @Test("Parse three AE Titles")
    func testParseThreeAETitles() {
        let aes = DICOMApplicationEntity.parseMultiple("SERVER1\\SERVER2\\SERVER3")
        #expect(aes != nil)
        #expect(aes?.count == 3)
        #expect(aes?[0].value == "SERVER1")
        #expect(aes?[1].value == "SERVER2")
        #expect(aes?[2].value == "SERVER3")
    }
    
    @Test("Parse multiple with empty values")
    func testParseMultipleWithEmpty() {
        // Empty values between delimiters are valid
        let aes = DICOMApplicationEntity.parseMultiple("STORESCU\\\\STORESCP")
        #expect(aes != nil)
        #expect(aes?.count == 3)
        #expect(aes?[0].value == "STORESCU")
        #expect(aes?[1].value == "")
        #expect(aes?[2].value == "STORESCP")
    }
    
    // MARK: - Property Tests
    
    @Test("isEmpty property")
    func testIsEmptyProperty() {
        let emptyAE = DICOMApplicationEntity.parse("")
        #expect(emptyAE?.isEmpty == true)
        
        let nonEmptyAE = DICOMApplicationEntity.parse("STORESCU")
        #expect(nonEmptyAE?.isEmpty == false)
    }
    
    @Test("length property")
    func testLengthProperty() {
        let ae = DICOMApplicationEntity.parse("STORESCU")
        #expect(ae?.length == 8)
        
        let emptyAE = DICOMApplicationEntity.parse("")
        #expect(emptyAE?.length == 0)
    }
    
    @Test("paddedValue property")
    func testPaddedValueProperty() {
        let ae = DICOMApplicationEntity.parse("STORESCU")
        #expect(ae?.paddedValue.count == 16)
        #expect(ae?.paddedValue == "STORESCU        ")
    }
    
    @Test("paddedValue for maximum length AE")
    func testPaddedValueMaxLength() {
        let ae = DICOMApplicationEntity.parse("1234567890123456")
        #expect(ae?.paddedValue.count == 16)
        #expect(ae?.paddedValue == "1234567890123456")
    }
    
    @Test("dicomString property")
    func testDicomStringProperty() {
        let ae = DICOMApplicationEntity.parse("STORESCU")
        #expect(ae?.dicomString == "STORESCU")
    }
    
    // MARK: - CustomStringConvertible Tests
    
    @Test("CustomStringConvertible description")
    func testDescription() {
        let ae = DICOMApplicationEntity.parse("STORESCU")
        #expect(String(describing: ae!) == "STORESCU")
    }
    
    // MARK: - ExpressibleByStringLiteral Tests
    
    @Test("Create AE from string literal")
    func testStringLiteral() {
        let ae: DICOMApplicationEntity = "STORESCU"
        #expect(ae.value == "STORESCU")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let ae1 = DICOMApplicationEntity.parse("STORESCU")
        let ae2 = DICOMApplicationEntity.parse("STORESCU")
        let ae3 = DICOMApplicationEntity.parse("STORESCP")
        
        #expect(ae1 == ae2)
        #expect(ae1 != ae3)
    }
    
    @Test("Equality with trimmed whitespace")
    func testEqualityWithWhitespace() {
        let ae1 = DICOMApplicationEntity.parse("STORESCU")
        let ae2 = DICOMApplicationEntity.parse("  STORESCU  ")
        
        #expect(ae1 == ae2)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let ae1 = DICOMApplicationEntity.parse("STORESCU")!
        let ae2 = DICOMApplicationEntity.parse("STORESCU")!
        
        #expect(ae1.hashValue == ae2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMApplicationEntity> = [ae1, ae2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable - lexicographic ordering")
    func testComparable() {
        let ae1 = DICOMApplicationEntity.parse("ASERVER")!
        let ae2 = DICOMApplicationEntity.parse("BSERVER")!
        
        #expect(ae1 < ae2)
        #expect(ae2 > ae1)
    }
    
    @Test("Comparable - case sensitive")
    func testComparableCaseSensitive() {
        let ae1 = DICOMApplicationEntity.parse("ASERVER")!
        let ae2 = DICOMApplicationEntity.parse("aserver")!
        
        // 'A' (65) < 'a' (97)
        #expect(ae1 < ae2)
    }
    
    @Test("Comparable - equal AEs")
    func testComparableEqual() {
        let ae1 = DICOMApplicationEntity.parse("STORESCU")!
        let ae2 = DICOMApplicationEntity.parse("STORESCU")!
        
        #expect(!(ae1 < ae2))
        #expect(!(ae2 < ae1))
    }
    
    // MARK: - Codable Tests
    
    @Test("Encode and decode AE")
    func testCodable() throws {
        let original = DICOMApplicationEntity.parse("STORESCU")!
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DICOMApplicationEntity.self, from: data)
        
        #expect(original == decoded)
    }
    
    @Test("Decode invalid AE throws error")
    func testDecodeInvalid() {
        // Backslash is not allowed in AE Title
        let json = "\"STORE\\\\SCU\""
        let data = json.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DICOMApplicationEntity.self, from: data)
        }
    }
    
    @Test("Decode overlength AE throws error")
    func testDecodeOverlength() {
        let json = "\"12345678901234567\""  // 17 characters
        let data = json.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DICOMApplicationEntity.self, from: data)
        }
    }
    
    // MARK: - Constants Tests
    
    @Test("Maximum length constant")
    func testMaximumLengthConstant() {
        #expect(DICOMApplicationEntity.maximumLength == 16)
    }
    
    // MARK: - Real-World AE Title Tests
    
    @Test("Common DCMTK AE Titles")
    func testDCMTKAETitles() {
        let dcmtkAEs = ["STORESCU", "STORESCP", "FINDSCU", "MOVESCU", "ECHOSCU", "DCMQRSCP"]
        
        for aeTitle in dcmtkAEs {
            let ae = DICOMApplicationEntity.parse(aeTitle)
            #expect(ae != nil, "Should parse \(aeTitle)")
            #expect(ae?.value == aeTitle)
        }
    }
    
    @Test("PACS system AE Titles")
    func testPACSAETitles() {
        let pacsAEs = ["PACS_SERVER", "ARCHIVE", "WORKSTATION01", "DICOM_PRINT"]
        
        for aeTitle in pacsAEs {
            let ae = DICOMApplicationEntity.parse(aeTitle)
            #expect(ae != nil, "Should parse \(aeTitle)")
            #expect(ae?.value == aeTitle)
        }
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip")
    func testRoundTrip() {
        let testCases = [
            "STORESCU",
            "STORESCP",
            "MY_SERVER",
            "1234567890123456",
            "A",
            "PACS.Server"
        ]
        
        for original in testCases {
            let parsed = DICOMApplicationEntity.parse(original)
            #expect(parsed != nil)
            #expect(parsed?.value == original)
            #expect(parsed?.dicomString == original)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("AE Title with only digits")
    func testDigitsOnly() {
        let ae = DICOMApplicationEntity.parse("1234567890")
        #expect(ae != nil)
        #expect(ae?.value == "1234567890")
    }
    
    @Test("AE Title with only special characters")
    func testSpecialCharsOnly() {
        let ae = DICOMApplicationEntity.parse("!@#$%^&*()")
        #expect(ae != nil)
        #expect(ae?.value == "!@#$%^&*()")
    }
    
    @Test("AE Title boundary at 16 characters")
    func testBoundaryLength() {
        // Exactly 16 characters - should pass
        let valid = DICOMApplicationEntity.parse("1234567890123456")
        #expect(valid != nil)
        #expect(valid?.length == 16)
        
        // 17 characters after trimming - should fail
        let invalid = DICOMApplicationEntity.parse("12345678901234567")
        #expect(invalid == nil)
    }
}
