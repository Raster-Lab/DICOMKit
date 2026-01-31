import XCTest
import DICOMCore
@testable import DICOMNetwork

final class QueryLevelTests: XCTestCase {
    
    // MARK: - Query Level Tests
    
    func testQueryLevelRawValues() {
        XCTAssertEqual(QueryLevel.patient.rawValue, "PATIENT")
        XCTAssertEqual(QueryLevel.study.rawValue, "STUDY")
        XCTAssertEqual(QueryLevel.series.rawValue, "SERIES")
        XCTAssertEqual(QueryLevel.image.rawValue, "IMAGE")
    }
    
    func testQueryRetrieveLevel() {
        XCTAssertEqual(QueryLevel.patient.queryRetrieveLevel, "PATIENT")
        XCTAssertEqual(QueryLevel.study.queryRetrieveLevel, "STUDY")
        XCTAssertEqual(QueryLevel.series.queryRetrieveLevel, "SERIES")
        XCTAssertEqual(QueryLevel.image.queryRetrieveLevel, "IMAGE")
    }
    
    func testQueryLevelAllCases() {
        XCTAssertEqual(QueryLevel.allCases.count, 4)
        XCTAssertTrue(QueryLevel.allCases.contains(.patient))
        XCTAssertTrue(QueryLevel.allCases.contains(.study))
        XCTAssertTrue(QueryLevel.allCases.contains(.series))
        XCTAssertTrue(QueryLevel.allCases.contains(.image))
    }
    
    func testQueryLevelHashable() {
        let set: Set<QueryLevel> = [.patient, .study, .series, .image]
        XCTAssertEqual(set.count, 4)
    }
    
    func testQueryLevelEquality() {
        XCTAssertEqual(QueryLevel.patient, QueryLevel.patient)
        XCTAssertNotEqual(QueryLevel.patient, QueryLevel.study)
    }
    
    func testQueryLevelDescription() {
        XCTAssertEqual(QueryLevel.patient.description, "PATIENT")
        XCTAssertEqual(QueryLevel.study.description, "STUDY")
        XCTAssertEqual(QueryLevel.series.description, "SERIES")
        XCTAssertEqual(QueryLevel.image.description, "IMAGE")
    }
}
