import XCTest
@testable import DICOMNetwork

final class DIMSEStatusTests: XCTestCase {
    
    // MARK: - Success Status
    
    func testSuccessStatus() {
        let status = DIMSEStatus.success
        XCTAssertEqual(status.rawValue, 0x0000)
        XCTAssertTrue(status.isSuccess)
        XCTAssertFalse(status.isPending)
        XCTAssertFalse(status.isFailure)
        XCTAssertFalse(status.isWarning)
        XCTAssertFalse(status.isCancel)
        XCTAssertTrue(status.isFinal)
    }
    
    func testSuccessFromRawValue() {
        let status = DIMSEStatus.from(0x0000)
        XCTAssertTrue(status.isSuccess)
    }
    
    // MARK: - Pending Status
    
    func testPendingStatusNoWarning() {
        let status = DIMSEStatus.pending(warningOptionalKeys: false)
        XCTAssertEqual(status.rawValue, 0xFF00)
        XCTAssertTrue(status.isPending)
        XCTAssertFalse(status.isSuccess)
        XCTAssertFalse(status.isFinal)
    }
    
    func testPendingStatusWithWarning() {
        let status = DIMSEStatus.pending(warningOptionalKeys: true)
        XCTAssertEqual(status.rawValue, 0xFF01)
        XCTAssertTrue(status.isPending)
    }
    
    func testPendingFromRawValue() {
        let status1 = DIMSEStatus.from(0xFF00)
        XCTAssertTrue(status1.isPending)
        
        let status2 = DIMSEStatus.from(0xFF01)
        XCTAssertTrue(status2.isPending)
    }
    
    // MARK: - Cancel Status
    
    func testCancelStatus() {
        let status = DIMSEStatus.cancel
        XCTAssertEqual(status.rawValue, 0xFE00)
        XCTAssertTrue(status.isCancel)
        XCTAssertTrue(status.isFinal)
    }
    
    func testCancelFromRawValue() {
        let status = DIMSEStatus.from(0xFE00)
        XCTAssertTrue(status.isCancel)
    }
    
    // MARK: - Failure Status
    
    func testRefusedOutOfResources() {
        let status = DIMSEStatus.refusedOutOfResources
        XCTAssertEqual(status.rawValue, 0xA700)
        XCTAssertTrue(status.isFailure)
    }
    
    func testRefusedSOPClassNotSupported() {
        let status = DIMSEStatus.refusedSOPClassNotSupported
        XCTAssertEqual(status.rawValue, 0x0122)
        XCTAssertTrue(status.isFailure)
        XCTAssertTrue(status.isFinal)
    }
    
    func testErrorIdentifierDoesNotMatchSOPClass() {
        let status = DIMSEStatus.errorIdentifierDoesNotMatchSOPClass
        XCTAssertEqual(status.rawValue, 0xA900)
        XCTAssertTrue(status.isFailure)
    }
    
    func testErrorIdentifierDoesNotMatchSOPClassFromRawValue() {
        let status = DIMSEStatus.from(0xA900)
        if case .errorIdentifierDoesNotMatchSOPClass = status {
            // Expected
        } else {
            XCTFail("Expected errorIdentifierDoesNotMatchSOPClass status")
        }
        XCTAssertTrue(status.isFailure)
    }
    
    func testFailedUnableToProcess() {
        let status = DIMSEStatus.failedUnableToProcess
        XCTAssertEqual(status.rawValue, 0x0110)
        XCTAssertTrue(status.isFailure)
    }
    
    func testFailedDuplicateSOPInstance() {
        let status = DIMSEStatus.failedDuplicateSOPInstance
        XCTAssertEqual(status.rawValue, 0x0111)
        XCTAssertTrue(status.isFailure)
    }
    
    func testFailedNoSuchSOPClass() {
        let status = DIMSEStatus.failedNoSuchSOPClass
        XCTAssertEqual(status.rawValue, 0x0118)
        XCTAssertTrue(status.isFailure)
    }
    
    func testFailedNoSuchSOPInstance() {
        let status = DIMSEStatus.failedNoSuchSOPInstance
        XCTAssertEqual(status.rawValue, 0x0112)
        XCTAssertTrue(status.isFailure)
    }
    
    func testFailedMoveDestinationUnknown() {
        let status = DIMSEStatus.failedMoveDestinationUnknown
        XCTAssertEqual(status.rawValue, 0xA801)
        XCTAssertTrue(status.isFailure)
    }
    
    func testErrorCannotUnderstand() {
        let status = DIMSEStatus.errorCannotUnderstand(0xC001)
        XCTAssertEqual(status.rawValue, 0xC001)
        XCTAssertTrue(status.isFailure)
    }
    
    func testErrorCannotUnderstandFromRawValue() {
        let status = DIMSEStatus.from(0xC123)
        if case .errorCannotUnderstand(let code) = status {
            XCTAssertEqual(code, 0xC123)
        } else {
            XCTFail("Expected errorCannotUnderstand status")
        }
        XCTAssertTrue(status.isFailure)
    }
    
    // MARK: - Warning Status
    
    func testWarningCoercionOfDataElements() {
        let status = DIMSEStatus.warningCoercionOfDataElements
        XCTAssertEqual(status.rawValue, 0xB000)
        XCTAssertTrue(status.isWarning)
        XCTAssertFalse(status.isFailure)
        XCTAssertTrue(status.isFinal)
    }
    
    func testWarningDataSetDoesNotMatchSOPClass() {
        let status = DIMSEStatus.warningDataSetDoesNotMatchSOPClass
        XCTAssertEqual(status.rawValue, 0xB007)
        XCTAssertTrue(status.isWarning)
    }
    
    func testWarningElementsDiscarded() {
        let status = DIMSEStatus.warningElementsDiscarded
        XCTAssertEqual(status.rawValue, 0xB006)
        XCTAssertTrue(status.isWarning)
    }
    
    // MARK: - Unknown Status
    
    func testUnknownStatus() {
        let status = DIMSEStatus.unknown(0x1234)
        XCTAssertEqual(status.rawValue, 0x1234)
    }
    
    func testUnknownFromRawValue() {
        let status = DIMSEStatus.from(0x9999)
        if case .unknown(let code) = status {
            XCTAssertEqual(code, 0x9999)
        } else {
            XCTFail("Expected unknown status")
        }
    }
    
    // MARK: - Descriptions
    
    func testDescriptions() {
        XCTAssertEqual(DIMSEStatus.success.description, "Success (0x0000)")
        XCTAssertEqual(DIMSEStatus.pending(warningOptionalKeys: false).description, "Pending (0xFF00)")
        XCTAssertEqual(DIMSEStatus.pending(warningOptionalKeys: true).description, "Pending (0xFF01)")
        XCTAssertEqual(DIMSEStatus.cancel.description, "Cancel (0xFE00)")
        XCTAssertTrue(DIMSEStatus.failedUnableToProcess.description.contains("0x0110"))
    }
    
    // MARK: - Hashable
    
    func testHashable() {
        var set = Set<DIMSEStatus>()
        set.insert(.success)
        set.insert(.pending(warningOptionalKeys: false))
        set.insert(.cancel)
        
        XCTAssertEqual(set.count, 3)
        XCTAssertTrue(set.contains(.success))
    }
}
