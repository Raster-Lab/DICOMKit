import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMCodeString Tests")
struct DICOMCodeStringTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse standard Code String")
    func testParseStandardCodeString() {
        let cs = DICOMCodeString.parse("CT")
        #expect(cs != nil)
        #expect(cs?.value == "CT")
    }
    
    @Test("Parse Code String with underscore")
    func testParseCodeStringWithUnderscore() {
        let cs = DICOMCodeString.parse("MR_HEAD")
        #expect(cs != nil)
        #expect(cs?.value == "MR_HEAD")
    }
    
    @Test("Parse Code String with numbers")
    func testParseCodeStringWithNumbers() {
        let cs = DICOMCodeString.parse("PHASE123")
        #expect(cs != nil)
        #expect(cs?.value == "PHASE123")
    }
    
    @Test("Parse Code String with space")
    func testParseCodeStringWithSpace() {
        let cs = DICOMCodeString.parse("MR HEAD")
        #expect(cs != nil)
        #expect(cs?.value == "MR HEAD")
    }
    
    @Test("Parse maximum length Code String (16 characters)")
    func testParseMaximumLengthCodeString() {
        let cs = DICOMCodeString.parse("1234567890123456")
        #expect(cs != nil)
        #expect(cs?.value.count == 16)
        #expect(cs?.length == 16)
    }
    
    @Test("Parse single character Code String")
    func testParseSingleCharacter() {
        let cs = DICOMCodeString.parse("M")
        #expect(cs != nil)
        #expect(cs?.value == "M")
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let cs = DICOMCodeString.parse("  CT  ")
        #expect(cs != nil)
        #expect(cs?.value == "CT")
    }
    
    @Test("Parse with null padding (common in DICOM)")
    func testParseWithNullPadding() {
        let cs = DICOMCodeString.parse("CT\0\0")
        #expect(cs != nil)
        #expect(cs?.value == "CT")
    }
    
    @Test("Parse empty string returns empty CS")
    func testParseEmptyString() {
        let cs = DICOMCodeString.parse("")
        #expect(cs != nil)
        #expect(cs?.value == "")
        #expect(cs?.isEmpty == true)
    }
    
    @Test("Parse whitespace-only string returns empty CS")
    func testParseWhitespaceOnly() {
        let cs = DICOMCodeString.parse("   ")
        #expect(cs != nil)
        #expect(cs?.value == "")
        #expect(cs?.isEmpty == true)
    }
    
    @Test("Parse Code String with only digits")
    func testParseDigitsOnly() {
        let cs = DICOMCodeString.parse("123456")
        #expect(cs != nil)
        #expect(cs?.value == "123456")
    }
    
    // MARK: - Validation Tests
    
    @Test("Reject Code String exceeding maximum length")
    func testRejectOverlengthCodeString() {
        // 17 characters is too long
        let cs = DICOMCodeString.parse("12345678901234567")
        #expect(cs == nil)
    }
    
    @Test("Reject Code String with lowercase letters")
    func testRejectLowercase() {
        let cs = DICOMCodeString.parse("ct")
        #expect(cs == nil)
        
        let cs2 = DICOMCodeString.parse("Ct")
        #expect(cs2 == nil)
    }
    
    @Test("Reject Code String with special characters")
    func testRejectSpecialCharacters() {
        // Hyphen is not allowed
        let csHyphen = DICOMCodeString.parse("MR-HEAD")
        #expect(csHyphen == nil)
        
        // Period is not allowed
        let csPeriod = DICOMCodeString.parse("MR.HEAD")
        #expect(csPeriod == nil)
        
        // Backslash is not allowed (it's a delimiter)
        let csBackslash = DICOMCodeString.parse("MR\\HEAD")
        #expect(csBackslash == nil)
    }
    
    @Test("Reject Code String with control characters")
    func testRejectControlCharacters() {
        // Tab character
        let csTab = DICOMCodeString.parse("MR\tHEAD")
        #expect(csTab == nil)
        
        // Newline
        let csNewline = DICOMCodeString.parse("MR\nHEAD")
        #expect(csNewline == nil)
        
        // Carriage return
        let csCR = DICOMCodeString.parse("MR\rHEAD")
        #expect(csCR == nil)
    }
    
    @Test("Reject Code String with non-ASCII characters")
    func testRejectNonASCII() {
        // Unicode character
        let cs = DICOMCodeString.parse("MR©HEAD")
        #expect(cs == nil)
        
        // Extended ASCII
        let cs2 = DICOMCodeString.parse("MRéHEAD")
        #expect(cs2 == nil)
    }
    
    @Test("Accept Code String with all valid characters")
    func testAcceptAllValidCharacters() {
        // All uppercase letters
        let letters = DICOMCodeString.parse("ABCDEFGHIJKLMNOP")
        #expect(letters != nil)
        
        // All digits
        let digits = DICOMCodeString.parse("0123456789")
        #expect(digits != nil)
        
        // Underscore
        let underscore = DICOMCodeString.parse("A_B")
        #expect(underscore != nil)
        
        // Space (internal)
        let space = DICOMCodeString.parse("A B")
        #expect(space != nil)
        
        // Combined
        let combined = DICOMCodeString.parse("ABC_123 XYZ")
        #expect(combined != nil)
    }
    
    // MARK: - Multiple Values Tests
    
    @Test("Parse multiple Code Strings")
    func testParseMultiple() {
        let css = DICOMCodeString.parseMultiple("CT\\MR")
        #expect(css != nil)
        #expect(css?.count == 2)
        #expect(css?[0].value == "CT")
        #expect(css?[1].value == "MR")
    }
    
    @Test("Parse single Code String as multiple returns single element")
    func testParseSingleAsMultiple() {
        let css = DICOMCodeString.parseMultiple("CT")
        #expect(css != nil)
        #expect(css?.count == 1)
        #expect(css?[0].value == "CT")
    }
    
    @Test("Parse multiple with invalid CS returns nil")
    func testParseMultipleWithInvalid() {
        // One CS has lowercase
        let css = DICOMCodeString.parseMultiple("CT\\mr")
        #expect(css == nil)
    }
    
    @Test("Parse three Code Strings")
    func testParseThreeCodeStrings() {
        let css = DICOMCodeString.parseMultiple("CT\\MR\\US")
        #expect(css != nil)
        #expect(css?.count == 3)
        #expect(css?[0].value == "CT")
        #expect(css?[1].value == "MR")
        #expect(css?[2].value == "US")
    }
    
    @Test("Parse multiple with empty values")
    func testParseMultipleWithEmpty() {
        // Empty values between delimiters are valid
        let css = DICOMCodeString.parseMultiple("CT\\\\MR")
        #expect(css != nil)
        #expect(css?.count == 3)
        #expect(css?[0].value == "CT")
        #expect(css?[1].value == "")
        #expect(css?[2].value == "MR")
    }
    
    // MARK: - Property Tests
    
    @Test("isEmpty property")
    func testIsEmptyProperty() {
        let emptyCS = DICOMCodeString.parse("")
        #expect(emptyCS?.isEmpty == true)
        
        let nonEmptyCS = DICOMCodeString.parse("CT")
        #expect(nonEmptyCS?.isEmpty == false)
    }
    
    @Test("length property")
    func testLengthProperty() {
        let cs = DICOMCodeString.parse("CT")
        #expect(cs?.length == 2)
        
        let emptyCS = DICOMCodeString.parse("")
        #expect(emptyCS?.length == 0)
    }
    
    @Test("paddedValue property for odd length")
    func testPaddedValueOddLength() {
        let cs = DICOMCodeString.parse("CT")  // 2 chars (even)
        #expect(cs?.paddedValue.count == 2)
        #expect(cs?.paddedValue == "CT")
        
        let csOdd = DICOMCodeString.parse("MRI")  // 3 chars (odd)
        #expect(csOdd?.paddedValue.count == 4)
        #expect(csOdd?.paddedValue == "MRI ")
    }
    
    @Test("paddedValue property for even length")
    func testPaddedValueEvenLength() {
        let cs = DICOMCodeString.parse("HEAD")  // 4 chars (even)
        #expect(cs?.paddedValue.count == 4)
        #expect(cs?.paddedValue == "HEAD")
    }
    
    @Test("dicomString property")
    func testDicomStringProperty() {
        let cs = DICOMCodeString.parse("CT")
        #expect(cs?.dicomString == "CT")
    }
    
    // MARK: - CustomStringConvertible Tests
    
    @Test("CustomStringConvertible description")
    func testDescription() {
        let cs = DICOMCodeString.parse("CT")
        #expect(String(describing: cs!) == "CT")
    }
    
    // MARK: - ExpressibleByStringLiteral Tests
    
    @Test("Create CS from string literal")
    func testStringLiteral() {
        let cs: DICOMCodeString = "CT"
        #expect(cs.value == "CT")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let cs1 = DICOMCodeString.parse("CT")
        let cs2 = DICOMCodeString.parse("CT")
        let cs3 = DICOMCodeString.parse("MR")
        
        #expect(cs1 == cs2)
        #expect(cs1 != cs3)
    }
    
    @Test("Equality with trimmed whitespace")
    func testEqualityWithWhitespace() {
        let cs1 = DICOMCodeString.parse("CT")
        let cs2 = DICOMCodeString.parse("  CT  ")
        
        #expect(cs1 == cs2)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let cs1 = DICOMCodeString.parse("CT")!
        let cs2 = DICOMCodeString.parse("CT")!
        
        #expect(cs1.hashValue == cs2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMCodeString> = [cs1, cs2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable - lexicographic ordering")
    func testComparable() {
        let cs1 = DICOMCodeString.parse("CT")!
        let cs2 = DICOMCodeString.parse("MR")!
        
        #expect(cs1 < cs2)
        #expect(cs2 > cs1)
    }
    
    @Test("Comparable - equal Code Strings")
    func testComparableEqual() {
        let cs1 = DICOMCodeString.parse("CT")!
        let cs2 = DICOMCodeString.parse("CT")!
        
        #expect(!(cs1 < cs2))
        #expect(!(cs2 < cs1))
    }
    
    // MARK: - Codable Tests
    
    @Test("Encode and decode Code String")
    func testCodable() throws {
        let original = DICOMCodeString.parse("CT")!
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DICOMCodeString.self, from: data)
        
        #expect(original == decoded)
    }
    
    @Test("Decode invalid Code String throws error")
    func testDecodeInvalid() {
        // Lowercase is not allowed in Code String
        let json = "\"ct\""
        let data = json.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DICOMCodeString.self, from: data)
        }
    }
    
    @Test("Decode overlength Code String throws error")
    func testDecodeOverlength() {
        let json = "\"12345678901234567\""  // 17 characters
        let data = json.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DICOMCodeString.self, from: data)
        }
    }
    
    // MARK: - Constants Tests
    
    @Test("Maximum length constant")
    func testMaximumLengthConstant() {
        #expect(DICOMCodeString.maximumLength == 16)
    }
    
    // MARK: - Real-World DICOM Code String Tests
    
    @Test("Common Modality values")
    func testModalityValues() {
        let modalities = ["CT", "MR", "US", "CR", "DX", "MG", "NM", "PT", "XA", "RF", "OT"]
        
        for modality in modalities {
            let cs = DICOMCodeString.parse(modality)
            #expect(cs != nil, "Should parse modality \(modality)")
            #expect(cs?.value == modality)
        }
    }
    
    @Test("Common Patient Sex values")
    func testPatientSexValues() {
        let sexValues = ["M", "F", "O"]  // Male, Female, Other
        
        for sex in sexValues {
            let cs = DICOMCodeString.parse(sex)
            #expect(cs != nil, "Should parse sex value \(sex)")
            #expect(cs?.value == sex)
        }
    }
    
    @Test("Body Part Examined values")
    func testBodyPartExaminedValues() {
        let bodyParts = ["HEAD", "CHEST", "ABDOMEN", "PELVIS", "EXTREMITY", "SPINE", "SKULL", "BRAIN"]
        
        for bodyPart in bodyParts {
            let cs = DICOMCodeString.parse(bodyPart)
            #expect(cs != nil, "Should parse body part \(bodyPart)")
            #expect(cs?.value == bodyPart)
        }
    }
    
    @Test("Image Type values with backslash delimiter")
    func testImageTypeValues() {
        // Image Type (0008,0008) commonly has multiple values
        let css = DICOMCodeString.parseMultiple("ORIGINAL\\PRIMARY\\AXIAL")
        #expect(css != nil)
        #expect(css?.count == 3)
        #expect(css?[0].value == "ORIGINAL")
        #expect(css?[1].value == "PRIMARY")
        #expect(css?[2].value == "AXIAL")
    }
    
    @Test("Laterality values")
    func testLateralityValues() {
        let lateralities = ["R", "L"]  // Right, Left
        
        for laterality in lateralities {
            let cs = DICOMCodeString.parse(laterality)
            #expect(cs != nil, "Should parse laterality \(laterality)")
            #expect(cs?.value == laterality)
        }
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip")
    func testRoundTrip() {
        let testCases = [
            "CT",
            "MR",
            "HEAD",
            "1234567890123456",
            "M",
            "ORIGINAL"
        ]
        
        for original in testCases {
            let parsed = DICOMCodeString.parse(original)
            #expect(parsed != nil)
            #expect(parsed?.value == original)
            #expect(parsed?.dicomString == original)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Code String with only underscores")
    func testUnderscoresOnly() {
        let cs = DICOMCodeString.parse("___")
        #expect(cs != nil)
        #expect(cs?.value == "___")
    }
    
    @Test("Code String boundary at 16 characters")
    func testBoundaryLength() {
        // Exactly 16 characters - should pass
        let valid = DICOMCodeString.parse("ABCDEFGHIJKLMNOP")
        #expect(valid != nil)
        #expect(valid?.length == 16)
        
        // 17 characters after trimming - should fail
        let invalid = DICOMCodeString.parse("ABCDEFGHIJKLMNOPQ")
        #expect(invalid == nil)
    }
    
    @Test("Code String with internal spaces")
    func testInternalSpaces() {
        let cs = DICOMCodeString.parse("A B C")
        #expect(cs != nil)
        #expect(cs?.value == "A B C")
    }
    
    @Test("Code String with multiple internal spaces")
    func testMultipleInternalSpaces() {
        let cs = DICOMCodeString.parse("A  B")
        #expect(cs != nil)
        #expect(cs?.value == "A  B")
    }
}
