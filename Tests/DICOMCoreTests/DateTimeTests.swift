import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMDate Tests")
struct DICOMDateTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse standard YYYYMMDD format")
    func testParseStandardFormat() {
        let date = DICOMDate.parse("20250130")
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("Parse legacy YYYY.MM.DD format with dots")
    func testParseLegacyFormat() {
        let date = DICOMDate.parse("2025.01.30")
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let date = DICOMDate.parse("  20250130  ")
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("Parse boundary values")
    func testParseBoundaryValues() {
        // First day of year
        let jan1 = DICOMDate.parse("20250101")
        #expect(jan1 != nil)
        #expect(jan1?.month == 1)
        #expect(jan1?.day == 1)
        
        // Last day of year
        let dec31 = DICOMDate.parse("20251231")
        #expect(dec31 != nil)
        #expect(dec31?.month == 12)
        #expect(dec31?.day == 31)
    }
    
    @Test("Reject invalid formats")
    func testRejectInvalidFormats() {
        // Too short
        #expect(DICOMDate.parse("2025013") == nil)
        
        // Too long
        #expect(DICOMDate.parse("202501301") == nil)
        
        // Invalid month
        #expect(DICOMDate.parse("20251301") == nil)
        #expect(DICOMDate.parse("20250001") == nil)
        
        // Invalid day
        #expect(DICOMDate.parse("20250132") == nil)
        #expect(DICOMDate.parse("20250100") == nil)
        
        // Non-numeric
        #expect(DICOMDate.parse("2025AB30") == nil)
    }
    
    // MARK: - Conversion Tests
    
    @Test("Convert to Foundation Date")
    func testToFoundationDate() {
        let dicomDate = DICOMDate(year: 2025, month: 1, day: 30)
        let date = dicomDate.toDate()
        #expect(date != nil)
        
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        #expect(components.year == 2025)
        #expect(components.month == 1)
        #expect(components.day == 30)
    }
    
    @Test("DICOM string format")
    func testDicomString() {
        let date = DICOMDate(year: 2025, month: 1, day: 5)
        #expect(date.dicomString == "20250105")
        
        let date2 = DICOMDate(year: 2000, month: 12, day: 31)
        #expect(date2.dicomString == "20001231")
    }
    
    @Test("CustomStringConvertible")
    func testDescription() {
        let date = DICOMDate(year: 2025, month: 1, day: 30)
        #expect(String(describing: date) == "20250130")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let date1 = DICOMDate(year: 2025, month: 1, day: 30)
        let date2 = DICOMDate(year: 2025, month: 1, day: 30)
        let date3 = DICOMDate(year: 2025, month: 1, day: 31)
        
        #expect(date1 == date2)
        #expect(date1 != date3)
    }
}

@Suite("DICOMTime Tests")
struct DICOMTimeTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse HH format (hour only)")
    func testParseHourOnly() {
        let time = DICOMTime.parse("14")
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == nil)
        #expect(time?.second == nil)
        #expect(time?.microsecond == nil)
    }
    
    @Test("Parse HHMM format")
    func testParseHourMinute() {
        let time = DICOMTime.parse("1430")
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == nil)
    }
    
    @Test("Parse HHMMSS format")
    func testParseHourMinuteSecond() {
        let time = DICOMTime.parse("143025")
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
        #expect(time?.microsecond == nil)
    }
    
    @Test("Parse HHMMSS.FFFFFF format")
    func testParseWithFractionalSeconds() {
        let time = DICOMTime.parse("143025.123456")
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
        #expect(time?.microsecond == 123456)
    }
    
    @Test("Parse with fewer fractional digits")
    func testParseShorterFractionalSeconds() {
        // Should pad to 6 digits
        let time = DICOMTime.parse("143025.1")
        #expect(time != nil)
        #expect(time?.microsecond == 100000)
        
        let time2 = DICOMTime.parse("143025.123")
        #expect(time2 != nil)
        #expect(time2?.microsecond == 123000)
    }
    
    @Test("Parse legacy format with colons")
    func testParseLegacyFormat() {
        let time = DICOMTime.parse("14:30:25")
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
    }
    
    @Test("Parse boundary values")
    func testParseBoundaryValues() {
        // Midnight
        let midnight = DICOMTime.parse("000000")
        #expect(midnight != nil)
        #expect(midnight?.hour == 0)
        #expect(midnight?.minute == 0)
        #expect(midnight?.second == 0)
        
        // End of day
        let endOfDay = DICOMTime.parse("235959")
        #expect(endOfDay != nil)
        #expect(endOfDay?.hour == 23)
        #expect(endOfDay?.minute == 59)
        #expect(endOfDay?.second == 59)
        
        // Leap second (60 seconds is valid per DICOM)
        let leapSecond = DICOMTime.parse("235960")
        #expect(leapSecond != nil)
        #expect(leapSecond?.second == 60)
    }
    
    @Test("Reject invalid formats")
    func testRejectInvalidFormats() {
        // Too short
        #expect(DICOMTime.parse("1") == nil)
        
        // Invalid hour
        #expect(DICOMTime.parse("24") == nil)
        
        // Invalid minute
        #expect(DICOMTime.parse("1460") == nil)
        
        // Invalid second (61 is invalid, 60 is leap second)
        #expect(DICOMTime.parse("143061") == nil)
    }
    
    // MARK: - Conversion Tests
    
    @Test("Convert to DateComponents")
    func testToDateComponents() {
        let time = DICOMTime(hour: 14, minute: 30, second: 25, microsecond: 123456)
        let components = time.toDateComponents()
        
        #expect(components.hour == 14)
        #expect(components.minute == 30)
        #expect(components.second == 25)
        #expect(components.nanosecond == 123456000)
    }
    
    @Test("DICOM string format")
    func testDicomString() {
        let hourOnly = DICOMTime(hour: 14)
        #expect(hourOnly.dicomString == "14")
        
        let hourMinute = DICOMTime(hour: 14, minute: 30)
        #expect(hourMinute.dicomString == "1430")
        
        let full = DICOMTime(hour: 14, minute: 30, second: 25, microsecond: 123456)
        #expect(full.dicomString == "143025.123456")
    }
}

@Suite("DICOMDateTime Tests")
struct DICOMDateTimeTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse year only")
    func testParseYearOnly() {
        let dt = DICOMDateTime.parse("2025")
        #expect(dt != nil)
        #expect(dt?.year == 2025)
        #expect(dt?.month == nil)
        #expect(dt?.day == nil)
        #expect(dt?.hour == nil)
    }
    
    @Test("Parse date only (YYYYMMDD)")
    func testParseDateOnly() {
        let dt = DICOMDateTime.parse("20250130")
        #expect(dt != nil)
        #expect(dt?.year == 2025)
        #expect(dt?.month == 1)
        #expect(dt?.day == 30)
        #expect(dt?.hour == nil)
    }
    
    @Test("Parse full datetime")
    func testParseFullDateTime() {
        let dt = DICOMDateTime.parse("20250130143025")
        #expect(dt != nil)
        #expect(dt?.year == 2025)
        #expect(dt?.month == 1)
        #expect(dt?.day == 30)
        #expect(dt?.hour == 14)
        #expect(dt?.minute == 30)
        #expect(dt?.second == 25)
    }
    
    @Test("Parse with fractional seconds")
    func testParseWithFractionalSeconds() {
        let dt = DICOMDateTime.parse("20250130143025.123456")
        #expect(dt != nil)
        #expect(dt?.microsecond == 123456)
    }
    
    @Test("Parse with positive timezone offset")
    func testParsePositiveTimezone() {
        let dt = DICOMDateTime.parse("20250130143025+0530")
        #expect(dt != nil)
        #expect(dt?.timezoneOffsetMinutes == 330) // 5 hours 30 minutes = 330 minutes
    }
    
    @Test("Parse with negative timezone offset")
    func testParseNegativeTimezone() {
        let dt = DICOMDateTime.parse("20250130143025-0800")
        #expect(dt != nil)
        #expect(dt?.timezoneOffsetMinutes == -480) // -8 hours = -480 minutes
    }
    
    @Test("Parse with UTC timezone")
    func testParseUTCTimezone() {
        let dt = DICOMDateTime.parse("20250130143025+0000")
        #expect(dt != nil)
        #expect(dt?.timezoneOffsetMinutes == 0)
    }
    
    @Test("Parse full format with fractional seconds and timezone")
    func testParseFullFormat() {
        let dt = DICOMDateTime.parse("20250130143025.123456+0530")
        #expect(dt != nil)
        #expect(dt?.year == 2025)
        #expect(dt?.month == 1)
        #expect(dt?.day == 30)
        #expect(dt?.hour == 14)
        #expect(dt?.minute == 30)
        #expect(dt?.second == 25)
        #expect(dt?.microsecond == 123456)
        #expect(dt?.timezoneOffsetMinutes == 330)
    }
    
    @Test("Reject invalid formats")
    func testRejectInvalidFormats() {
        // Too short
        #expect(DICOMDateTime.parse("202") == nil)
        
        // Invalid month
        #expect(DICOMDateTime.parse("20251301") == nil)
        
        // Too long main part
        #expect(DICOMDateTime.parse("202501301430251") == nil)
    }
    
    // MARK: - Conversion Tests
    
    @Test("Convert to Foundation Date")
    func testToFoundationDate() {
        let dt = DICOMDateTime(year: 2025, month: 1, day: 30, hour: 14, minute: 30, second: 25)
        let date = dt.toDate()
        #expect(date != nil)
    }
    
    @Test("Get date component")
    func testGetDateComponent() {
        let dt = DICOMDateTime(year: 2025, month: 1, day: 30, hour: 14, minute: 30)
        let date = dt.date
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("Get time component")
    func testGetTimeComponent() {
        let dt = DICOMDateTime(year: 2025, month: 1, day: 30, hour: 14, minute: 30, second: 25, microsecond: 123456)
        let time = dt.time
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
        #expect(time?.microsecond == 123456)
    }
    
    @Test("DICOM string format")
    func testDicomString() {
        let yearOnly = DICOMDateTime(year: 2025)
        #expect(yearOnly.dicomString == "2025")
        
        let dateOnly = DICOMDateTime(year: 2025, month: 1, day: 30)
        #expect(dateOnly.dicomString == "20250130")
        
        let withTime = DICOMDateTime(year: 2025, month: 1, day: 30, hour: 14, minute: 30, second: 25)
        #expect(withTime.dicomString == "20250130143025")
        
        let withTimezone = DICOMDateTime(year: 2025, month: 1, day: 30, hour: 14, minute: 30, second: 25, timezoneOffsetMinutes: 330)
        #expect(withTimezone.dicomString == "20250130143025+0530")
        
        let withNegativeTimezone = DICOMDateTime(year: 2025, month: 1, day: 30, hour: 14, minute: 30, second: 25, timezoneOffsetMinutes: -480)
        #expect(withNegativeTimezone.dicomString == "20250130143025-0800")
    }
}
