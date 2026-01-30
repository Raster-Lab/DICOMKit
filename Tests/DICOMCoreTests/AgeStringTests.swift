import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMAgeString Tests")
struct DICOMAgeStringTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse years format (nnnY)")
    func testParseYears() {
        let age = DICOMAgeString.parse("018Y")
        #expect(age != nil)
        #expect(age?.value == 18)
        #expect(age?.unit == .years)
    }
    
    @Test("Parse months format (nnnM)")
    func testParseMonths() {
        let age = DICOMAgeString.parse("003M")
        #expect(age != nil)
        #expect(age?.value == 3)
        #expect(age?.unit == .months)
    }
    
    @Test("Parse weeks format (nnnW)")
    func testParseWeeks() {
        let age = DICOMAgeString.parse("006W")
        #expect(age != nil)
        #expect(age?.value == 6)
        #expect(age?.unit == .weeks)
    }
    
    @Test("Parse days format (nnnD)")
    func testParseDays() {
        let age = DICOMAgeString.parse("045D")
        #expect(age != nil)
        #expect(age?.value == 45)
        #expect(age?.unit == .days)
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let age = DICOMAgeString.parse("  018Y  ")
        #expect(age != nil)
        #expect(age?.value == 18)
        #expect(age?.unit == .years)
    }
    
    @Test("Parse boundary values")
    func testParseBoundaryValues() {
        // Zero
        let zero = DICOMAgeString.parse("000Y")
        #expect(zero != nil)
        #expect(zero?.value == 0)
        
        // Maximum value
        let max = DICOMAgeString.parse("999Y")
        #expect(max != nil)
        #expect(max?.value == 999)
        
        // Single digit with leading zeros
        let one = DICOMAgeString.parse("001D")
        #expect(one != nil)
        #expect(one?.value == 1)
    }
    
    @Test("Reject invalid formats")
    func testRejectInvalidFormats() {
        // Too short
        #expect(DICOMAgeString.parse("18Y") == nil)
        #expect(DICOMAgeString.parse("18") == nil)
        
        // Too long
        #expect(DICOMAgeString.parse("0018Y") == nil)
        
        // Invalid unit
        #expect(DICOMAgeString.parse("018X") == nil)
        #expect(DICOMAgeString.parse("018Z") == nil)
        #expect(DICOMAgeString.parse("0181") == nil)
        
        // Lowercase unit (DICOM requires uppercase)
        #expect(DICOMAgeString.parse("018y") == nil)
        
        // Non-numeric value
        #expect(DICOMAgeString.parse("ABCY") == nil)
        
        // Empty string
        #expect(DICOMAgeString.parse("") == nil)
        
        // Only whitespace
        #expect(DICOMAgeString.parse("    ") == nil)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Direct initialization with components")
    func testInitialization() {
        let age = DICOMAgeString(value: 25, unit: .years)
        #expect(age.value == 25)
        #expect(age.unit == .years)
    }
    
    @Test("Initialization clamps value to valid range")
    func testInitializationClamping() {
        // Value is clamped to 0-999
        let negative = DICOMAgeString(value: -5, unit: .years)
        #expect(negative.value == 0)
        
        let tooLarge = DICOMAgeString(value: 1500, unit: .years)
        #expect(tooLarge.value == 999)
    }
    
    // MARK: - Conversion Tests
    
    @Test("Approximate years calculation")
    func testApproximateYears() {
        // Years
        let years = DICOMAgeString(value: 30, unit: .years)
        #expect(years.approximateYears == 30.0)
        
        // Months
        let months = DICOMAgeString(value: 24, unit: .months)
        #expect(months.approximateYears == 2.0)
        
        // Weeks (52.18 weeks per year)
        let weeks = DICOMAgeString(value: 52, unit: .weeks)
        #expect(weeks.approximateYears > 0.99 && weeks.approximateYears < 1.0)
        
        // Days (365.25 days per year)
        let days = DICOMAgeString(value: 365, unit: .days)
        #expect(days.approximateYears > 0.99 && days.approximateYears < 1.0)
    }
    
    @Test("Approximate days calculation")
    func testApproximateDays() {
        // Days
        let days = DICOMAgeString(value: 45, unit: .days)
        #expect(days.approximateDays == 45.0)
        
        // Weeks (7 days per week)
        let weeks = DICOMAgeString(value: 2, unit: .weeks)
        #expect(weeks.approximateDays == 14.0)
        
        // Months (30.4375 days per month = 365.25 / 12)
        let months = DICOMAgeString(value: 1, unit: .months)
        #expect(months.approximateDays == 30.4375)
        
        // Years (365.25 days per year)
        let years = DICOMAgeString(value: 1, unit: .years)
        #expect(years.approximateDays == 365.25)
    }
    
    // MARK: - String Output Tests
    
    @Test("DICOM string format")
    func testDicomString() {
        let age1 = DICOMAgeString(value: 18, unit: .years)
        #expect(age1.dicomString == "018Y")
        
        let age2 = DICOMAgeString(value: 3, unit: .months)
        #expect(age2.dicomString == "003M")
        
        let age3 = DICOMAgeString(value: 150, unit: .days)
        #expect(age3.dicomString == "150D")
        
        let age4 = DICOMAgeString(value: 0, unit: .weeks)
        #expect(age4.dicomString == "000W")
    }
    
    @Test("Human readable format")
    func testHumanReadable() {
        let years = DICOMAgeString(value: 18, unit: .years)
        #expect(years.humanReadable == "18 years")
        
        let oneYear = DICOMAgeString(value: 1, unit: .years)
        #expect(oneYear.humanReadable == "1 year")
        
        let months = DICOMAgeString(value: 6, unit: .months)
        #expect(months.humanReadable == "6 months")
        
        let oneMonth = DICOMAgeString(value: 1, unit: .months)
        #expect(oneMonth.humanReadable == "1 month")
        
        let weeks = DICOMAgeString(value: 4, unit: .weeks)
        #expect(weeks.humanReadable == "4 weeks")
        
        let oneWeek = DICOMAgeString(value: 1, unit: .weeks)
        #expect(oneWeek.humanReadable == "1 week")
        
        let days = DICOMAgeString(value: 10, unit: .days)
        #expect(days.humanReadable == "10 days")
        
        let oneDay = DICOMAgeString(value: 1, unit: .days)
        #expect(oneDay.humanReadable == "1 day")
    }
    
    @Test("CustomStringConvertible")
    func testDescription() {
        let age = DICOMAgeString(value: 25, unit: .years)
        #expect(String(describing: age) == "25 years")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let age1 = DICOMAgeString(value: 18, unit: .years)
        let age2 = DICOMAgeString(value: 18, unit: .years)
        let age3 = DICOMAgeString(value: 18, unit: .months)
        let age4 = DICOMAgeString(value: 19, unit: .years)
        
        #expect(age1 == age2)
        #expect(age1 != age3)
        #expect(age1 != age4)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let age1 = DICOMAgeString(value: 18, unit: .years)
        let age2 = DICOMAgeString(value: 18, unit: .years)
        
        #expect(age1.hashValue == age2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMAgeString> = [age1, age2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable - same unit")
    func testComparableSameUnit() {
        let age1 = DICOMAgeString(value: 20, unit: .years)
        let age2 = DICOMAgeString(value: 30, unit: .years)
        
        #expect(age1 < age2)
        #expect(age2 > age1)
    }
    
    @Test("Comparable - different units")
    func testComparableDifferentUnits() {
        let years = DICOMAgeString(value: 1, unit: .years)
        let months = DICOMAgeString(value: 6, unit: .months)
        
        #expect(months < years)
        
        let weeks = DICOMAgeString(value: 52, unit: .weeks)
        // 52 weeks is just under 1 year
        #expect(weeks < years)
        
        let days = DICOMAgeString(value: 365, unit: .days)
        // 365 days is just under 1 year (using 365.25 days/year)
        #expect(days < years)
    }
    
    // MARK: - AgeUnit Tests
    
    @Test("AgeUnit descriptions")
    func testAgeUnitDescriptions() {
        #expect(DICOMAgeString.AgeUnit.days.description == "days")
        #expect(DICOMAgeString.AgeUnit.weeks.description == "weeks")
        #expect(DICOMAgeString.AgeUnit.months.description == "months")
        #expect(DICOMAgeString.AgeUnit.years.description == "years")
    }
    
    @Test("AgeUnit singular descriptions")
    func testAgeUnitSingularDescriptions() {
        #expect(DICOMAgeString.AgeUnit.days.singularDescription == "day")
        #expect(DICOMAgeString.AgeUnit.weeks.singularDescription == "week")
        #expect(DICOMAgeString.AgeUnit.months.singularDescription == "month")
        #expect(DICOMAgeString.AgeUnit.years.singularDescription == "year")
    }
    
    @Test("AgeUnit raw values")
    func testAgeUnitRawValues() {
        #expect(DICOMAgeString.AgeUnit.days.rawValue == "D")
        #expect(DICOMAgeString.AgeUnit.weeks.rawValue == "W")
        #expect(DICOMAgeString.AgeUnit.months.rawValue == "M")
        #expect(DICOMAgeString.AgeUnit.years.rawValue == "Y")
    }
    
    @Test("AgeUnit CaseIterable")
    func testAgeUnitCaseIterable() {
        let allCases = DICOMAgeString.AgeUnit.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.days))
        #expect(allCases.contains(.weeks))
        #expect(allCases.contains(.months))
        #expect(allCases.contains(.years))
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip")
    func testRoundTrip() {
        let testCases = ["000D", "001W", "012M", "100Y", "999Y"]
        
        for original in testCases {
            let parsed = DICOMAgeString.parse(original)
            #expect(parsed != nil)
            #expect(parsed?.dicomString == original)
        }
    }
}
