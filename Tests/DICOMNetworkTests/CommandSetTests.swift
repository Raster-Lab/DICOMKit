import XCTest
import DICOMCore
@testable import DICOMNetwork

final class CommandSetTests: XCTestCase {
    
    // MARK: - Basic Creation
    
    func testEmptyCommandSet() {
        let cmd = CommandSet()
        XCTAssertNil(cmd.command)
        XCTAssertNil(cmd.messageID)
        XCTAssertNil(cmd.status)
        XCTAssertFalse(cmd.hasDataSet)
    }
    
    // MARK: - UInt16 Values
    
    func testSetGetUInt16() {
        var cmd = CommandSet()
        cmd.setUInt16(42, for: .messageID)
        XCTAssertEqual(cmd.getUInt16(.messageID), 42)
    }
    
    func testSetGetUInt16Missing() {
        let cmd = CommandSet()
        XCTAssertNil(cmd.getUInt16(.messageID))
    }
    
    // MARK: - UInt32 Values
    
    func testSetGetUInt32() {
        var cmd = CommandSet()
        cmd.setUInt32(123456, for: .commandGroupLength)
        XCTAssertEqual(cmd.getUInt32(.commandGroupLength), 123456)
    }
    
    // MARK: - String Values
    
    func testSetGetString() {
        var cmd = CommandSet()
        cmd.setString("1.2.840.10008.1.1", for: .affectedSOPClassUID)
        XCTAssertEqual(cmd.getString(.affectedSOPClassUID), "1.2.840.10008.1.1")
    }
    
    func testStringPaddingToEvenLength() {
        var cmd = CommandSet()
        cmd.setString("123", for: .affectedSOPClassUID)
        // String "123" has length 3, should be padded to 4
        let data = cmd.getData(.affectedSOPClassUID)
        XCTAssertEqual(data?.count, 4)
    }
    
    func testStringPaddingEvenLength() {
        var cmd = CommandSet()
        cmd.setString("1234", for: .affectedSOPClassUID)
        // String "1234" has length 4, no padding needed
        let data = cmd.getData(.affectedSOPClassUID)
        XCTAssertEqual(data?.count, 4)
    }
    
    // MARK: - Command Type
    
    func testSetGetCommand() {
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        XCTAssertEqual(cmd.command, .cEchoRequest)
    }
    
    // MARK: - Message ID
    
    func testSetGetMessageID() {
        var cmd = CommandSet()
        cmd.setMessageID(1)
        XCTAssertEqual(cmd.messageID, 1)
    }
    
    func testSetGetMessageIDBeingRespondedTo() {
        var cmd = CommandSet()
        cmd.setMessageIDBeingRespondedTo(42)
        XCTAssertEqual(cmd.messageIDBeingRespondedTo, 42)
    }
    
    // MARK: - SOP UIDs
    
    func testSetGetAffectedSOPClassUID() {
        var cmd = CommandSet()
        cmd.setAffectedSOPClassUID("1.2.840.10008.1.1")
        XCTAssertEqual(cmd.affectedSOPClassUID, "1.2.840.10008.1.1")
    }
    
    func testSetGetAffectedSOPInstanceUID() {
        var cmd = CommandSet()
        let uid = "1.2.3.4.5.6.7.8.9"
        cmd.setAffectedSOPInstanceUID(uid)
        XCTAssertEqual(cmd.affectedSOPInstanceUID, uid)
    }
    
    // MARK: - Status
    
    func testSetGetStatus() {
        var cmd = CommandSet()
        cmd.setStatus(.success)
        XCTAssertEqual(cmd.status, .success)
        XCTAssertTrue(cmd.status?.isSuccess == true)
    }
    
    func testSetGetStatusPending() {
        var cmd = CommandSet()
        cmd.setStatus(.pending(warningOptionalKeys: false))
        XCTAssertTrue(cmd.status?.isPending == true)
    }
    
    // MARK: - Priority
    
    func testSetGetPriority() {
        var cmd = CommandSet()
        cmd.setPriority(.high)
        XCTAssertEqual(cmd.priority, .high)
    }
    
    // MARK: - Data Set Type
    
    func testHasDataSetTrue() {
        var cmd = CommandSet()
        cmd.setHasDataSet(true)
        XCTAssertTrue(cmd.hasDataSet)
    }
    
    func testHasDataSetFalse() {
        var cmd = CommandSet()
        cmd.setHasDataSet(false)
        XCTAssertFalse(cmd.hasDataSet)
    }
    
    func testNoDataSetPresentValue() {
        XCTAssertEqual(noDataSetPresent, 0x0101)
    }
    
    // MARK: - Move Destination
    
    func testSetGetMoveDestination() {
        var cmd = CommandSet()
        cmd.setMoveDestination("STORESCP")
        XCTAssertEqual(cmd.moveDestination, "STORESCP")
    }
    
    // MARK: - Sub-operation Counts
    
    func testSetGetRemainingSuboperations() {
        var cmd = CommandSet()
        cmd.setNumberOfRemainingSuboperations(10)
        XCTAssertEqual(cmd.numberOfRemainingSuboperations, 10)
    }
    
    func testSetGetCompletedSuboperations() {
        var cmd = CommandSet()
        cmd.setNumberOfCompletedSuboperations(5)
        XCTAssertEqual(cmd.numberOfCompletedSuboperations, 5)
    }
    
    func testSetGetFailedSuboperations() {
        var cmd = CommandSet()
        cmd.setNumberOfFailedSuboperations(2)
        XCTAssertEqual(cmd.numberOfFailedSuboperations, 2)
    }
    
    func testSetGetWarningSuboperations() {
        var cmd = CommandSet()
        cmd.setNumberOfWarningSuboperations(1)
        XCTAssertEqual(cmd.numberOfWarningSuboperations, 1)
    }
    
    // MARK: - Remove
    
    func testRemoveElement() {
        var cmd = CommandSet()
        cmd.setMessageID(42)
        XCTAssertEqual(cmd.messageID, 42)
        cmd.remove(.messageID)
        XCTAssertNil(cmd.messageID)
    }
    
    // MARK: - Encoding/Decoding
    
    func testEncodeDecode() throws {
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.1.1")
        cmd.setHasDataSet(false)
        
        let encoded = cmd.encode()
        let decoded = try CommandSet.decode(from: encoded)
        
        XCTAssertEqual(decoded.command, .cEchoRequest)
        XCTAssertEqual(decoded.messageID, 1)
        XCTAssertEqual(decoded.affectedSOPClassUID, "1.2.840.10008.1.1")
        XCTAssertFalse(decoded.hasDataSet)
    }
    
    func testEncodeIncludesGroupLength() throws {
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        
        let encoded = cmd.encode()
        let decoded = try CommandSet.decode(from: encoded)
        
        // Group length should be present after encoding
        XCTAssertNotNil(decoded.getUInt32(.commandGroupLength))
    }
    
    func testDecodeShortDataReturnsEmpty() throws {
        let shortData = Data([0x00, 0x00, 0x00]) // Only 3 bytes, not enough for any element
        let decoded = try CommandSet.decode(from: shortData)
        // With less than 8 bytes, no elements can be decoded
        XCTAssertNil(decoded.command)
    }
    
    // MARK: - Description
    
    func testDescription() {
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.1.1")
        cmd.setHasDataSet(false)
        
        let desc = cmd.description
        XCTAssertTrue(desc.contains("CommandSet"))
        XCTAssertTrue(desc.contains("C-ECHO-RQ"))
        XCTAssertTrue(desc.contains("Message ID: 1"))
    }
    
    // MARK: - Hashable
    
    func testHashable() {
        var cmd1 = CommandSet()
        cmd1.setCommand(.cEchoRequest)
        cmd1.setMessageID(1)
        
        var cmd2 = CommandSet()
        cmd2.setCommand(.cEchoRequest)
        cmd2.setMessageID(1)
        
        XCTAssertEqual(cmd1, cmd2)
        
        var cmd3 = CommandSet()
        cmd3.setCommand(.cEchoRequest)
        cmd3.setMessageID(2)
        
        XCTAssertNotEqual(cmd1, cmd3)
    }
}
