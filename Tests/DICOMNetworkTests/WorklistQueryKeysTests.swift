import XCTest
import DICOMCore
@testable import DICOMNetwork

/// Tests for MWL scheduled-date/time filter resolution (PS3.4 C.2.2.2.5, K.6.1).
final class WorklistQueryKeysTests: XCTestCase {

    // MARK: - Date: Single Value Matching

    func testResolveScheduledDate_exact() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("20240315"), "20240315")
    }

    func testResolveScheduledDate_today() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("today"), formatter.string(from: Date()))
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("TODAY"), formatter.string(from: Date()))
    }

    func testResolveScheduledDate_tomorrow() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("tomorrow"), formatter.string(from: tomorrow))
    }

    func testResolveScheduledDate_invalidThrows() {
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledDate("2024-03-15"))
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledDate("bogus"))
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledDate("202403"))
    }

    // MARK: - Date: Range Matching (PS3.4 C.2.2.2.5.1)

    func testResolveScheduledDate_closedRange() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("20240701-20240707"), "20240701-20240707")
    }

    func testResolveScheduledDate_openStartRange() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("-20240707"), "-20240707")
    }

    func testResolveScheduledDate_openEndRange() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("20240701-"), "20240701-")
    }

    func testResolveScheduledDate_rangeWithTodayTomorrowBounds() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = formatter.string(from: Date())
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("today-"), "\(today)-")
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledDate("-today"), "-\(today)")
    }

    func testResolveScheduledDate_malformedRangeThrows() {
        // Both bounds empty
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledDate("-"))
        // More than one hyphen
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledDate("20240701-20240707-20240709"))
        // Invalid bound
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledDate("2024-20240707"))
    }

    // MARK: - Time: Single Value Matching

    func testResolveScheduledTime_exact() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("103000"), "103000")
    }

    func testResolveScheduledTime_shortForms() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("10"), "10")
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("1030"), "1030")
    }

    func testResolveScheduledTime_fraction() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("100000.123456"), "100000.123456")
    }

    func testResolveScheduledTime_invalidThrows() {
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledTime("10:00"))
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledTime("bogus"))
    }

    // MARK: - Time: Range Matching (PS3.4 C.2.2.2.5.2)

    func testResolveScheduledTime_closedRange() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("1000-1800"), "1000-1800")
    }

    func testResolveScheduledTime_openStartRange() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("-1800"), "-1800")
    }

    func testResolveScheduledTime_openEndRange() throws {
        XCTAssertEqual(try WorklistQueryKeys.resolveScheduledTime("1000-"), "1000-")
    }

    func testResolveScheduledTime_malformedRangeThrows() {
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledTime("-"))
        XCTAssertThrowsError(try WorklistQueryKeys.resolveScheduledTime("1000-1800-2000"))
    }

    // MARK: - forQuery integration

    func testForQuery_setsBothDateAndTimeMatchingKeys() throws {
        let keys = try WorklistQueryKeys.forQuery(date: "20240705-20240707", time: "1000-1800")
        XCTAssertEqual(keys.allSPSKeys[Tag(group: 0x0040, element: 0x0002)], "20240705-20240707")
        XCTAssertEqual(keys.allSPSKeys[Tag(group: 0x0040, element: 0x0003)], "1000-1800")
    }

    func testForQuery_emptyDateAndTimeOmitted() throws {
        let keys = try WorklistQueryKeys.forQuery()
        XCTAssertEqual(keys.allSPSKeys[Tag(group: 0x0040, element: 0x0002)], "")
        XCTAssertEqual(keys.allSPSKeys[Tag(group: 0x0040, element: 0x0003)], "")
    }

    func testForQuery_invalidDatePropagatesError() {
        XCTAssertThrowsError(try WorklistQueryKeys.forQuery(date: "not-a-date"))
    }

    func testForQuery_invalidTimePropagatesError() {
        XCTAssertThrowsError(try WorklistQueryKeys.forQuery(time: "not-a-time"))
    }
}
