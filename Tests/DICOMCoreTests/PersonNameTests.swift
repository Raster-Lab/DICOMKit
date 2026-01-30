import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMPersonName Tests")
struct DICOMPersonNameTests {
    
    // MARK: - Basic Parsing Tests
    
    @Test("Parse simple name with family and given name")
    func testParseSimpleName() {
        let name = DICOMPersonName.parse("Doe^John")
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
        #expect(name?.middleName == "")
        #expect(name?.namePrefix == "")
        #expect(name?.nameSuffix == "")
    }
    
    @Test("Parse name with all components")
    func testParseFullName() {
        let name = DICOMPersonName.parse("Doe^John^Robert^Dr.^Jr.")
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
        #expect(name?.middleName == "Robert")
        #expect(name?.namePrefix == "Dr.")
        #expect(name?.nameSuffix == "Jr.")
    }
    
    @Test("Parse family name only")
    func testParseFamilyNameOnly() {
        let name = DICOMPersonName.parse("Smith")
        #expect(name != nil)
        #expect(name?.familyName == "Smith")
        #expect(name?.givenName == "")
        #expect(name?.middleName == "")
    }
    
    @Test("Parse name with trailing carets")
    func testParseNameWithTrailingCarets() {
        let name = DICOMPersonName.parse("Doe^John^^Dr.^")
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
        #expect(name?.middleName == "")
        #expect(name?.namePrefix == "Dr.")
        #expect(name?.nameSuffix == "")
    }
    
    @Test("Parse name with empty middle component")
    func testParseNameWithEmptyMiddle() {
        let name = DICOMPersonName.parse("Doe^John^^Dr.")
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
        #expect(name?.middleName == "")
        #expect(name?.namePrefix == "Dr.")
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let name = DICOMPersonName.parse("  Doe^John  ")
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
    }
    
    @Test("Reject empty string")
    func testRejectEmptyString() {
        #expect(DICOMPersonName.parse("") == nil)
        #expect(DICOMPersonName.parse("   ") == nil)
    }
    
    @Test("Parse trims whitespace from individual components")
    func testParseTrimComponentWhitespace() {
        let name = DICOMPersonName.parse("Doe ^ John ^ Robert")
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
        #expect(name?.middleName == "Robert")
    }
    
    // MARK: - Multiple Representation Tests
    
    @Test("Parse name with ideographic representation")
    func testParseWithIdeographic() {
        let name = DICOMPersonName.parse("Yamada^Tarou=山田^太郎")
        #expect(name != nil)
        #expect(name?.alphabetic.familyName == "Yamada")
        #expect(name?.alphabetic.givenName == "Tarou")
        #expect(name?.ideographic.familyName == "山田")
        #expect(name?.ideographic.givenName == "太郎")
        #expect(name?.hasIdeographic == true)
        #expect(name?.hasPhonetic == false)
    }
    
    @Test("Parse name with phonetic representation")
    func testParseWithPhonetic() {
        let name = DICOMPersonName.parse("Yamada^Tarou==やまだ^たろう")
        #expect(name != nil)
        #expect(name?.alphabetic.familyName == "Yamada")
        #expect(name?.alphabetic.givenName == "Tarou")
        #expect(name?.ideographic.isEmpty == true)
        #expect(name?.phonetic.familyName == "やまだ")
        #expect(name?.phonetic.givenName == "たろう")
        #expect(name?.hasIdeographic == false)
        #expect(name?.hasPhonetic == true)
    }
    
    @Test("Parse name with all three representations")
    func testParseWithAllRepresentations() {
        let name = DICOMPersonName.parse("Yamada^Tarou=山田^太郎=やまだ^たろう")
        #expect(name != nil)
        #expect(name?.alphabetic.familyName == "Yamada")
        #expect(name?.alphabetic.givenName == "Tarou")
        #expect(name?.ideographic.familyName == "山田")
        #expect(name?.ideographic.givenName == "太郎")
        #expect(name?.phonetic.familyName == "やまだ")
        #expect(name?.phonetic.givenName == "たろう")
        #expect(name?.hasIdeographic == true)
        #expect(name?.hasPhonetic == true)
    }
    
    @Test("Parse name with empty ideographic but phonetic present")
    func testParseWithEmptyIdeographic() {
        let name = DICOMPersonName.parse("Smith^John==スミス^ジョン")
        #expect(name != nil)
        #expect(name?.alphabetic.familyName == "Smith")
        #expect(name?.ideographic.isEmpty == true)
        #expect(name?.phonetic.familyName == "スミス")
    }
    
    // MARK: - Initialization Tests
    
    @Test("Direct initialization with component group")
    func testInitializationWithComponentGroup() {
        let alphabetic = DICOMPersonName.ComponentGroup(
            familyName: "Doe",
            givenName: "John",
            middleName: "Robert"
        )
        let name = DICOMPersonName(alphabetic: alphabetic)
        
        #expect(name.familyName == "Doe")
        #expect(name.givenName == "John")
        #expect(name.middleName == "Robert")
        #expect(name.hasIdeographic == false)
        #expect(name.hasPhonetic == false)
    }
    
    @Test("Convenience initialization with name components")
    func testConvenienceInitialization() {
        let name = DICOMPersonName(
            familyName: "Smith",
            givenName: "Jane",
            namePrefix: "Dr."
        )
        
        #expect(name.familyName == "Smith")
        #expect(name.givenName == "Jane")
        #expect(name.namePrefix == "Dr.")
        #expect(name.middleName == "")
        #expect(name.nameSuffix == "")
    }
    
    // MARK: - DICOM String Output Tests
    
    @Test("DICOM string output for simple name")
    func testDicomStringSimple() {
        let name = DICOMPersonName(familyName: "Doe", givenName: "John")
        #expect(name.dicomString == "Doe^John")
    }
    
    @Test("DICOM string output for full name")
    func testDicomStringFull() {
        let name = DICOMPersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "Robert",
            namePrefix: "Dr.",
            nameSuffix: "Jr."
        )
        #expect(name.dicomString == "Doe^John^Robert^Dr.^Jr.")
    }
    
    @Test("DICOM string output omits trailing empty components")
    func testDicomStringOmitsTrailingEmpty() {
        let name = DICOMPersonName(familyName: "Doe", givenName: "John", middleName: "")
        #expect(name.dicomString == "Doe^John")
    }
    
    @Test("DICOM string output with gap in components")
    func testDicomStringWithGap() {
        let name = DICOMPersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "",
            namePrefix: "Dr."
        )
        #expect(name.dicomString == "Doe^John^^Dr.")
    }
    
    @Test("DICOM string output with multiple representations")
    func testDicomStringWithRepresentations() {
        let alphabetic = DICOMPersonName.ComponentGroup(familyName: "Yamada", givenName: "Tarou")
        let ideographic = DICOMPersonName.ComponentGroup(familyName: "山田", givenName: "太郎")
        let name = DICOMPersonName(alphabetic: alphabetic, ideographic: ideographic)
        
        #expect(name.dicomString == "Yamada^Tarou=山田^太郎")
    }
    
    @Test("DICOM string output with phonetic only")
    func testDicomStringWithPhoneticOnly() {
        let alphabetic = DICOMPersonName.ComponentGroup(familyName: "Yamada", givenName: "Tarou")
        let phonetic = DICOMPersonName.ComponentGroup(familyName: "やまだ", givenName: "たろう")
        let name = DICOMPersonName(alphabetic: alphabetic, ideographic: .init(), phonetic: phonetic)
        
        #expect(name.dicomString == "Yamada^Tarou==やまだ^たろう")
    }
    
    // MARK: - Formatted Name Tests
    
    @Test("Formatted name for simple name")
    func testFormattedNameSimple() {
        let name = DICOMPersonName(familyName: "Doe", givenName: "John")
        #expect(name.formattedName == "John Doe")
    }
    
    @Test("Formatted name for full name")
    func testFormattedNameFull() {
        let name = DICOMPersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "Robert",
            namePrefix: "Dr.",
            nameSuffix: "Jr."
        )
        #expect(name.formattedName == "Dr. John Robert Doe Jr.")
    }
    
    @Test("Formatted name with only family name")
    func testFormattedNameOnlyFamily() {
        let name = DICOMPersonName(familyName: "Smith")
        #expect(name.formattedName == "Smith")
    }
    
    @Test("CustomStringConvertible")
    func testDescription() {
        let name = DICOMPersonName(familyName: "Doe", givenName: "John")
        #expect(String(describing: name) == "John Doe")
    }
    
    // MARK: - ComponentGroup Tests
    
    @Test("ComponentGroup isEmpty check")
    func testComponentGroupIsEmpty() {
        let empty = DICOMPersonName.ComponentGroup()
        #expect(empty.isEmpty == true)
        
        let notEmpty = DICOMPersonName.ComponentGroup(familyName: "Doe")
        #expect(notEmpty.isEmpty == false)
    }
    
    @Test("ComponentGroup parse")
    func testComponentGroupParse() {
        let group = DICOMPersonName.ComponentGroup.parse("Doe^John^Robert^Dr.^Jr.")
        #expect(group.familyName == "Doe")
        #expect(group.givenName == "John")
        #expect(group.middleName == "Robert")
        #expect(group.namePrefix == "Dr.")
        #expect(group.nameSuffix == "Jr.")
    }
    
    @Test("ComponentGroup parse with fewer components")
    func testComponentGroupParsePartial() {
        let group = DICOMPersonName.ComponentGroup.parse("Doe^John")
        #expect(group.familyName == "Doe")
        #expect(group.givenName == "John")
        #expect(group.middleName == "")
        #expect(group.namePrefix == "")
        #expect(group.nameSuffix == "")
    }
    
    @Test("ComponentGroup dicomString")
    func testComponentGroupDicomString() {
        let group = DICOMPersonName.ComponentGroup(
            familyName: "Doe",
            givenName: "John",
            middleName: "",
            namePrefix: "Dr."
        )
        #expect(group.dicomString == "Doe^John^^Dr.")
    }
    
    @Test("ComponentGroup formattedName")
    func testComponentGroupFormattedName() {
        let group = DICOMPersonName.ComponentGroup(
            familyName: "Doe",
            givenName: "John",
            namePrefix: "Dr."
        )
        #expect(group.formattedName == "Dr. John Doe")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let name1 = DICOMPersonName(familyName: "Doe", givenName: "John")
        let name2 = DICOMPersonName(familyName: "Doe", givenName: "John")
        let name3 = DICOMPersonName(familyName: "Doe", givenName: "Jane")
        
        #expect(name1 == name2)
        #expect(name1 != name3)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let name1 = DICOMPersonName(familyName: "Doe", givenName: "John")
        let name2 = DICOMPersonName(familyName: "Doe", givenName: "John")
        
        #expect(name1.hashValue == name2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMPersonName> = [name1, name2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable - different family names")
    func testComparableFamilyName() {
        let name1 = DICOMPersonName(familyName: "Adams", givenName: "John")
        let name2 = DICOMPersonName(familyName: "Brown", givenName: "John")
        
        #expect(name1 < name2)
    }
    
    @Test("Comparable - same family, different given names")
    func testComparableGivenName() {
        let name1 = DICOMPersonName(familyName: "Doe", givenName: "Alice")
        let name2 = DICOMPersonName(familyName: "Doe", givenName: "Bob")
        
        #expect(name1 < name2)
    }
    
    @Test("Comparable - case insensitive")
    func testComparableCaseInsensitive() {
        let name1 = DICOMPersonName(familyName: "doe", givenName: "john")
        let name2 = DICOMPersonName(familyName: "Doe", givenName: "John")
        
        // Neither should be less than the other if they're equal
        #expect(!(name1 < name2) && !(name2 < name1))
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip - simple name")
    func testRoundTripSimple() {
        let original = "Doe^John"
        let parsed = DICOMPersonName.parse(original)
        #expect(parsed != nil)
        #expect(parsed?.dicomString == original)
    }
    
    @Test("Parse and reformat round-trip - full name")
    func testRoundTripFull() {
        let original = "Doe^John^Robert^Dr.^Jr."
        let parsed = DICOMPersonName.parse(original)
        #expect(parsed != nil)
        #expect(parsed?.dicomString == original)
    }
    
    @Test("Parse and reformat round-trip - multiple representations")
    func testRoundTripMultipleRepresentations() {
        let original = "Yamada^Tarou=山田^太郎=やまだ^たろう"
        let parsed = DICOMPersonName.parse(original)
        #expect(parsed != nil)
        #expect(parsed?.dicomString == original)
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty family name with given name")
    func testEmptyFamilyNameWithGiven() {
        let name = DICOMPersonName.parse("^John")
        #expect(name != nil)
        #expect(name?.familyName == "")
        #expect(name?.givenName == "John")
    }
    
    @Test("Name with special characters")
    func testSpecialCharacters() {
        let name = DICOMPersonName.parse("O'Brien^Mary-Jane")
        #expect(name != nil)
        #expect(name?.familyName == "O'Brien")
        #expect(name?.givenName == "Mary-Jane")
    }
    
    @Test("Single caret only")
    func testSingleCaret() {
        let name = DICOMPersonName.parse("^")
        #expect(name != nil)
        #expect(name?.familyName == "")
        #expect(name?.givenName == "")
    }
    
    @Test("Multiple equals signs")
    func testMultipleEquals() {
        let name = DICOMPersonName.parse("A=B=C=D")
        #expect(name != nil)
        // Only first 3 groups should be parsed
        #expect(name?.alphabetic.familyName == "A")
        #expect(name?.ideographic.familyName == "B")
        #expect(name?.phonetic.familyName == "C")
    }
}
