import XCTest
@testable import DICOMNetwork

final class DIMSEPriorityTests: XCTestCase {
    
    func testPriorityValues() {
        XCTAssertEqual(DIMSEPriority.low.rawValue, 0x0002)
        XCTAssertEqual(DIMSEPriority.medium.rawValue, 0x0000)
        XCTAssertEqual(DIMSEPriority.high.rawValue, 0x0001)
    }
    
    func testDefaultPriority() {
        XCTAssertEqual(DIMSEPriority.default, .medium)
    }
    
    func testDescriptions() {
        XCTAssertEqual(DIMSEPriority.low.description, "LOW")
        XCTAssertEqual(DIMSEPriority.medium.description, "MEDIUM")
        XCTAssertEqual(DIMSEPriority.high.description, "HIGH")
    }
    
    func testHashable() {
        var set = Set<DIMSEPriority>()
        set.insert(.low)
        set.insert(.medium)
        set.insert(.high)
        
        XCTAssertEqual(set.count, 3)
        XCTAssertTrue(set.contains(.medium))
    }
}
