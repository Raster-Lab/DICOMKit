import XCTest
@testable import DICOMNetwork

final class DIMSECommandTests: XCTestCase {
    
    // MARK: - DIMSE-C Commands
    
    func testCStoreCommandValues() {
        XCTAssertEqual(DIMSECommand.cStoreRequest.rawValue, 0x0001)
        XCTAssertEqual(DIMSECommand.cStoreResponse.rawValue, 0x8001)
    }
    
    func testCGetCommandValues() {
        XCTAssertEqual(DIMSECommand.cGetRequest.rawValue, 0x0010)
        XCTAssertEqual(DIMSECommand.cGetResponse.rawValue, 0x8010)
    }
    
    func testCFindCommandValues() {
        XCTAssertEqual(DIMSECommand.cFindRequest.rawValue, 0x0020)
        XCTAssertEqual(DIMSECommand.cFindResponse.rawValue, 0x8020)
    }
    
    func testCMoveCommandValues() {
        XCTAssertEqual(DIMSECommand.cMoveRequest.rawValue, 0x0021)
        XCTAssertEqual(DIMSECommand.cMoveResponse.rawValue, 0x8021)
    }
    
    func testCEchoCommandValues() {
        XCTAssertEqual(DIMSECommand.cEchoRequest.rawValue, 0x0030)
        XCTAssertEqual(DIMSECommand.cEchoResponse.rawValue, 0x8030)
    }
    
    func testCCancelCommandValue() {
        XCTAssertEqual(DIMSECommand.cCancelRequest.rawValue, 0x0FFF)
    }
    
    // MARK: - DIMSE-N Commands
    
    func testNEventReportCommandValues() {
        XCTAssertEqual(DIMSECommand.nEventReportRequest.rawValue, 0x0100)
        XCTAssertEqual(DIMSECommand.nEventReportResponse.rawValue, 0x8100)
    }
    
    func testNGetCommandValues() {
        XCTAssertEqual(DIMSECommand.nGetRequest.rawValue, 0x0110)
        XCTAssertEqual(DIMSECommand.nGetResponse.rawValue, 0x8110)
    }
    
    func testNSetCommandValues() {
        XCTAssertEqual(DIMSECommand.nSetRequest.rawValue, 0x0120)
        XCTAssertEqual(DIMSECommand.nSetResponse.rawValue, 0x8120)
    }
    
    func testNActionCommandValues() {
        XCTAssertEqual(DIMSECommand.nActionRequest.rawValue, 0x0130)
        XCTAssertEqual(DIMSECommand.nActionResponse.rawValue, 0x8130)
    }
    
    func testNCreateCommandValues() {
        XCTAssertEqual(DIMSECommand.nCreateRequest.rawValue, 0x0140)
        XCTAssertEqual(DIMSECommand.nCreateResponse.rawValue, 0x8140)
    }
    
    func testNDeleteCommandValues() {
        XCTAssertEqual(DIMSECommand.nDeleteRequest.rawValue, 0x0150)
        XCTAssertEqual(DIMSECommand.nDeleteResponse.rawValue, 0x8150)
    }
    
    // MARK: - Request/Response Detection
    
    func testIsRequest() {
        XCTAssertTrue(DIMSECommand.cStoreRequest.isRequest)
        XCTAssertTrue(DIMSECommand.cFindRequest.isRequest)
        XCTAssertTrue(DIMSECommand.cMoveRequest.isRequest)
        XCTAssertTrue(DIMSECommand.cGetRequest.isRequest)
        XCTAssertTrue(DIMSECommand.cEchoRequest.isRequest)
        XCTAssertTrue(DIMSECommand.cCancelRequest.isRequest)
        
        XCTAssertFalse(DIMSECommand.cStoreResponse.isRequest)
        XCTAssertFalse(DIMSECommand.cFindResponse.isRequest)
    }
    
    func testIsResponse() {
        XCTAssertTrue(DIMSECommand.cStoreResponse.isResponse)
        XCTAssertTrue(DIMSECommand.cFindResponse.isResponse)
        XCTAssertTrue(DIMSECommand.cMoveResponse.isResponse)
        XCTAssertTrue(DIMSECommand.cGetResponse.isResponse)
        XCTAssertTrue(DIMSECommand.cEchoResponse.isResponse)
        
        XCTAssertFalse(DIMSECommand.cStoreRequest.isResponse)
        XCTAssertFalse(DIMSECommand.cFindRequest.isResponse)
    }
    
    // MARK: - Request/Response Conversion
    
    func testRequestToResponse() {
        XCTAssertEqual(DIMSECommand.cStoreRequest.responseCommand, .cStoreResponse)
        XCTAssertEqual(DIMSECommand.cFindRequest.responseCommand, .cFindResponse)
        XCTAssertEqual(DIMSECommand.cMoveRequest.responseCommand, .cMoveResponse)
        XCTAssertEqual(DIMSECommand.cGetRequest.responseCommand, .cGetResponse)
        XCTAssertEqual(DIMSECommand.cEchoRequest.responseCommand, .cEchoResponse)
        XCTAssertNil(DIMSECommand.cCancelRequest.responseCommand)
    }
    
    func testResponseToRequest() {
        XCTAssertEqual(DIMSECommand.cStoreResponse.requestCommand, .cStoreRequest)
        XCTAssertEqual(DIMSECommand.cFindResponse.requestCommand, .cFindRequest)
        XCTAssertEqual(DIMSECommand.cMoveResponse.requestCommand, .cMoveRequest)
        XCTAssertEqual(DIMSECommand.cGetResponse.requestCommand, .cGetRequest)
        XCTAssertEqual(DIMSECommand.cEchoResponse.requestCommand, .cEchoRequest)
    }
    
    // MARK: - Description
    
    func testDescriptions() {
        XCTAssertEqual(DIMSECommand.cStoreRequest.description, "C-STORE-RQ")
        XCTAssertEqual(DIMSECommand.cStoreResponse.description, "C-STORE-RSP")
        XCTAssertEqual(DIMSECommand.cEchoRequest.description, "C-ECHO-RQ")
        XCTAssertEqual(DIMSECommand.cEchoResponse.description, "C-ECHO-RSP")
        XCTAssertEqual(DIMSECommand.cCancelRequest.description, "C-CANCEL-RQ")
    }
}
