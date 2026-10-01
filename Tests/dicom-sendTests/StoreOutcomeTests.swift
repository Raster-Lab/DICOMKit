import XCTest
import DICOMNetwork
@testable import dicom_send

/// C-STORE response handling against PS3.4 2026a Table B.2-1 (C-STORE Response
/// Status Values) and PS3.7 2026a Table 9.3-1 (C-STORE-RQ Priority values).
final class StoreOutcomeTests: XCTestCase {

    // PS3.4 Table B.2-1, 2026a: Success 0000; Warning B000 / B007 / B006;
    // Failure A7xx / A9xx / Cxxx. PS3.7 9.1.1.1.9 adds 0122 Refused: SOP Class not supported.
    func testSuccessIsStored() {
        XCTAssertEqual(StoreOutcome(status: .from(0x0000)), .stored)
    }

    func testWarningClassIsStoredWithWarning() {
        for code: UInt16 in [0xB000, 0xB006, 0xB007, 0xB001, 0xBFFF] {
            XCTAssertEqual(StoreOutcome(status: .from(code)), .storedWithWarning, String(format: "%04X", code))
        }
    }

    func testFailureClassIsNotStored() {
        for code: UInt16 in [0xA700, 0xA701, 0xA7FF, 0xA900, 0xA901, 0xA9FF, 0xC000, 0xC123, 0xCFFF, 0x0122] {
            XCTAssertEqual(StoreOutcome(status: .from(code)), .failed, String(format: "%04X", code))
        }
    }

    func testFailureStatusErrorNamesTheStatus() {
        let error = SendError.storeFailed(.from(0xA700))
        let text = error.errorDescription ?? ""
        XCTAssertTrue(text.contains("0xA700"), text)
        XCTAssertTrue(text.contains("Out of resources"), text)
    }

    // PS3.7 Table 9.3-1: LOW = 0002H, MEDIUM = 0000H, HIGH = 0001H.
    func testPriorityOptionValuesMatchPS37() {
        XCTAssertEqual(PriorityOption.low.dimseValue.rawValue, 0x0002)
        XCTAssertEqual(PriorityOption.medium.dimseValue.rawValue, 0x0000)
        XCTAssertEqual(PriorityOption.high.dimseValue.rawValue, 0x0001)
        XCTAssertEqual(PriorityOption.allCases.map(\.rawValue), ["low", "medium", "high"])
    }

    func testPriorityHelpCitesTheStandardValues() {
        let help = DICOMSend.helpMessage()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(help.contains("low (0002H), medium (0000H), high (0001H)"), help)
    }
}
