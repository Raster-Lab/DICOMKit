import XCTest
import DICOMCore
@testable import DICOMNetwork

final class DIMSEMessagesTests: XCTestCase {
    
    // MARK: - C-ECHO Tests
    
    func testCEchoRequestCreation() {
        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.1.1",
            presentationContextID: 1
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, "1.2.840.10008.1.1")
        XCTAssertEqual(request.presentationContextID, 1)
        XCTAssertFalse(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cEchoRequest)
    }
    
    func testCEchoRequestDefaultSOPClass() {
        let request = CEchoRequest(messageID: 1, presentationContextID: 1)
        XCTAssertEqual(request.affectedSOPClassUID, "1.2.840.10008.1.1")
    }
    
    func testCEchoResponseCreation() {
        let response = CEchoResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.1.1",
            status: .success,
            presentationContextID: 1
        )
        
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
        XCTAssertEqual(response.affectedSOPClassUID, "1.2.840.10008.1.1")
        XCTAssertTrue(response.status.isSuccess)
        XCTAssertEqual(response.presentationContextID, 1)
        XCTAssertFalse(response.hasDataSet)
        XCTAssertEqual(response.commandSet.command, .cEchoResponse)
    }
    
    // MARK: - C-STORE Tests
    
    func testCStoreRequestCreation() {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.7",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            priority: .medium,
            presentationContextID: 3
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.7")
        XCTAssertEqual(request.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(request.priority, .medium)
        XCTAssertEqual(request.presentationContextID, 3)
        XCTAssertTrue(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cStoreRequest)
    }
    
    func testCStoreRequestWithMoveOriginator() {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.7",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            moveOriginatorAETitle: "MOVESCU",
            moveOriginatorMessageID: 42,
            presentationContextID: 3
        )
        
        XCTAssertEqual(request.moveOriginatorAETitle, "MOVESCU")
        XCTAssertEqual(request.moveOriginatorMessageID, 42)
    }
    
    func testCStoreResponseCreation() {
        let response = CStoreResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.7",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            status: .success,
            presentationContextID: 3
        )
        
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
        XCTAssertEqual(response.affectedSOPClassUID, "1.2.840.10008.5.1.4.1.1.7")
        XCTAssertEqual(response.affectedSOPInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertTrue(response.status.isSuccess)
        XCTAssertFalse(response.hasDataSet)
        XCTAssertEqual(response.commandSet.command, .cStoreResponse)
    }
    
    // MARK: - C-FIND Tests
    
    func testCFindRequestCreation() {
        let sopClassUID = "1.2.840.10008.5.1.4.1.2.2.1" // Study Root Find
        let request = CFindRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            priority: .high,
            presentationContextID: 5
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, sopClassUID)
        XCTAssertEqual(request.priority, .high)
        XCTAssertTrue(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cFindRequest)
    }
    
    func testCFindResponseCreationWithPending() {
        let response = CFindResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.2.2.1",
            status: .pending(warningOptionalKeys: false),
            hasDataSet: true,
            presentationContextID: 5
        )
        
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
        XCTAssertTrue(response.status.isPending)
        XCTAssertTrue(response.hasDataSet)
        XCTAssertEqual(response.commandSet.command, .cFindResponse)
    }
    
    func testCFindResponseCreationFinal() {
        let response = CFindResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.2.2.1",
            status: .success,
            hasDataSet: false,
            presentationContextID: 5
        )
        
        XCTAssertTrue(response.status.isSuccess)
        XCTAssertFalse(response.hasDataSet)
    }
    
    // MARK: - C-MOVE Tests
    
    func testCMoveRequestCreation() {
        let sopClassUID = "1.2.840.10008.5.1.4.1.2.2.2" // Study Root Move
        let request = CMoveRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            moveDestination: "STORESCP",
            priority: .medium,
            presentationContextID: 7
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, sopClassUID)
        XCTAssertEqual(request.moveDestination, "STORESCP")
        XCTAssertEqual(request.priority, .medium)
        XCTAssertTrue(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cMoveRequest)
    }
    
    func testCMoveResponseWithSuboperations() {
        let response = CMoveResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.2.2.2",
            status: .pending(warningOptionalKeys: false),
            remaining: 10,
            completed: 5,
            failed: 0,
            warning: 0,
            presentationContextID: 7
        )
        
        XCTAssertEqual(response.numberOfRemainingSuboperations, 10)
        XCTAssertEqual(response.numberOfCompletedSuboperations, 5)
        XCTAssertEqual(response.numberOfFailedSuboperations, 0)
        XCTAssertEqual(response.numberOfWarningSuboperations, 0)
        XCTAssertTrue(response.status.isPending)
        XCTAssertEqual(response.commandSet.command, .cMoveResponse)
    }
    
    func testCMoveResponseFinal() {
        let response = CMoveResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.2.2.2",
            status: .success,
            remaining: 0,
            completed: 15,
            failed: 0,
            warning: 0,
            presentationContextID: 7
        )
        
        XCTAssertTrue(response.status.isSuccess)
        XCTAssertEqual(response.numberOfCompletedSuboperations, 15)
    }
    
    // MARK: - C-GET Tests
    
    func testCGetRequestCreation() {
        let sopClassUID = "1.2.840.10008.5.1.4.1.2.2.3" // Study Root Get
        let request = CGetRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            priority: .low,
            presentationContextID: 9
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, sopClassUID)
        XCTAssertEqual(request.priority, .low)
        XCTAssertTrue(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cGetRequest)
    }
    
    func testCGetResponseWithSuboperations() {
        let response = CGetResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.2.2.3",
            status: .pending(warningOptionalKeys: false),
            remaining: 5,
            completed: 10,
            failed: 1,
            warning: 2,
            presentationContextID: 9
        )
        
        XCTAssertEqual(response.numberOfRemainingSuboperations, 5)
        XCTAssertEqual(response.numberOfCompletedSuboperations, 10)
        XCTAssertEqual(response.numberOfFailedSuboperations, 1)
        XCTAssertEqual(response.numberOfWarningSuboperations, 2)
        XCTAssertTrue(response.status.isPending)
        XCTAssertEqual(response.commandSet.command, .cGetResponse)
    }
    
    // MARK: - C-CANCEL Tests
    
    func testCCancelRequestCreation() {
        let request = CCancelRequest(
            messageIDBeingCancelled: 42,
            presentationContextID: 5
        )
        
        XCTAssertEqual(request.messageIDBeingCancelled, 42)
        XCTAssertEqual(request.presentationContextID, 5)
        XCTAssertFalse(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cCancelRequest)
    }
    
    // MARK: - Protocol Conformance
    
    func testDIMSERequestProtocol() {
        let request: any DIMSERequest = CEchoRequest(messageID: 1, presentationContextID: 1)
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.presentationContextID, 1)
    }
    
    func testDIMSEResponseProtocol() {
        let response: any DIMSEResponse = CEchoResponse(
            messageIDBeingRespondedTo: 1,
            status: .success,
            presentationContextID: 1
        )
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
        XCTAssertTrue(response.status.isSuccess)
    }
    
    // MARK: - Hashable
    
    func testCEchoRequestHashable() {
        let request1 = CEchoRequest(messageID: 1, presentationContextID: 1)
        let request2 = CEchoRequest(messageID: 1, presentationContextID: 1)
        let request3 = CEchoRequest(messageID: 2, presentationContextID: 1)
        
        XCTAssertEqual(request1, request2)
        XCTAssertNotEqual(request1, request3)
    }
}
