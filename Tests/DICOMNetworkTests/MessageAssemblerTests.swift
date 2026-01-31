import XCTest
import DICOMCore
@testable import DICOMNetwork

final class MessageAssemblerTests: XCTestCase {
    
    // MARK: - Basic Assembly
    
    func testAssembleCommandOnly() throws {
        let assembler = MessageAssembler()
        
        // Create a C-ECHO request command set
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.1.1")
        cmd.setHasDataSet(false)
        
        let commandData = cmd.encode()
        
        // Create PDV with command data (last fragment)
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: commandData
        )
        
        let message = try assembler.addPDV(pdv)
        
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.presentationContextID, 1)
        XCTAssertEqual(message?.command, .cEchoRequest)
        XCTAssertFalse(message?.hasDataSet ?? true)
    }
    
    func testAssembleCommandWithDataSet() throws {
        let assembler = MessageAssembler()
        
        // Create a C-STORE request command set
        var cmd = CommandSet()
        cmd.setCommand(.cStoreRequest)
        cmd.setMessageID(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.5.1.4.1.1.7")
        cmd.setAffectedSOPInstanceUID("1.2.3.4.5.6.7.8.9")
        cmd.setHasDataSet(true)
        
        let commandData = cmd.encode()
        
        // Create command PDV
        let commandPDV = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: commandData
        )
        
        // Add command - should not complete yet (data set expected)
        let messageAfterCommand = try assembler.addPDV(commandPDV)
        XCTAssertNil(messageAfterCommand)
        
        // Create data set PDV
        let dataSetData = Data([0x08, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00]) // Dummy data
        let dataSetPDV = PresentationDataValue(
            presentationContextID: 1,
            isCommand: false,
            isLastFragment: true,
            data: dataSetData
        )
        
        // Add data set - should complete now
        let message = try assembler.addPDV(dataSetPDV)
        
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.command, .cStoreRequest)
        XCTAssertTrue(message?.hasDataSet ?? false)
        XCTAssertEqual(message?.dataSet, dataSetData)
    }
    
    // MARK: - Multi-Fragment Assembly
    
    func testAssembleMultiFragmentCommand() throws {
        let assembler = MessageAssembler()
        
        // Create command data
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        let commandData = cmd.encode()
        
        // Split into two fragments
        let midpoint = commandData.count / 2
        let fragment1 = commandData.subdata(in: 0..<midpoint)
        let fragment2 = commandData.subdata(in: midpoint..<commandData.count)
        
        // First fragment
        let pdv1 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: false,
            data: fragment1
        )
        
        let message1 = try assembler.addPDV(pdv1)
        XCTAssertNil(message1) // Not complete yet
        XCTAssertTrue(assembler.isProcessing)
        
        // Second fragment (last)
        let pdv2 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: fragment2
        )
        
        let message2 = try assembler.addPDV(pdv2)
        XCTAssertNotNil(message2)
        XCTAssertEqual(message2?.command, .cEchoRequest)
    }
    
    // MARK: - Context ID Mismatch
    
    func testContextIDMismatchThrows() throws {
        let assembler = MessageAssembler()
        
        // First PDV with context ID 1
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(true)
        let commandData = cmd.encode()
        
        let pdv1 = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: commandData
        )
        
        _ = try assembler.addPDV(pdv1)
        
        // Second PDV with different context ID
        let pdv2 = PresentationDataValue(
            presentationContextID: 3, // Different!
            isCommand: false,
            isLastFragment: true,
            data: Data([0x01, 0x02])
        )
        
        XCTAssertThrowsError(try assembler.addPDV(pdv2)) { error in
            if case DICOMNetworkError.decodingFailed(let message) = error {
                XCTAssertTrue(message.contains("Context ID mismatch"))
            } else {
                XCTFail("Expected decodingFailed error")
            }
        }
    }
    
    // MARK: - Reset
    
    func testReset() throws {
        let assembler = MessageAssembler()
        
        // Add partial command
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(true)
        let commandData = cmd.encode()
        
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: commandData
        )
        
        _ = try assembler.addPDV(pdv)
        XCTAssertTrue(assembler.isProcessing)
        
        assembler.reset()
        XCTAssertFalse(assembler.isProcessing)
    }
    
    // MARK: - Add PDVs from PDU
    
    func testAddPDVsFromDataTransferPDU() throws {
        let assembler = MessageAssembler()
        
        // Create command
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        let commandData = cmd.encode()
        
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: commandData
        )
        
        let pdu = DataTransferPDU(pdv: pdv)
        
        let message = try assembler.addPDVs(from: pdu)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.command, .cEchoRequest)
    }
    
    // MARK: - AssembledMessage Conversion
    
    func testAssembledMessageToCEchoRequest() throws {
        let assembler = MessageAssembler()
        
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.1.1")
        cmd.setHasDataSet(false)
        
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: cmd.encode()
        )
        
        let message = try assembler.addPDV(pdv)
        
        let request = message?.asCEchoRequest()
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.messageID, 1)
        XCTAssertEqual(request?.affectedSOPClassUID, "1.2.840.10008.1.1")
    }
    
    func testAssembledMessageToCEchoResponse() throws {
        let assembler = MessageAssembler()
        
        var cmd = CommandSet()
        cmd.setCommand(.cEchoResponse)
        cmd.setMessageIDBeingRespondedTo(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.1.1")
        cmd.setStatus(.success)
        cmd.setHasDataSet(false)
        
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: cmd.encode()
        )
        
        let message = try assembler.addPDV(pdv)
        
        let response = message?.asCEchoResponse()
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.messageIDBeingRespondedTo, 1)
        XCTAssertTrue(response?.status.isSuccess ?? false)
    }
    
    func testAssembledMessageWrongTypeReturnsNil() throws {
        let assembler = MessageAssembler()
        
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: cmd.encode()
        )
        
        let message = try assembler.addPDV(pdv)
        
        // Request message should not convert to response
        XCTAssertNil(message?.asCEchoResponse())
        XCTAssertNil(message?.asCStoreRequest())
    }
}

// MARK: - MessageFragmenter Tests

final class MessageFragmenterTests: XCTestCase {
    
    func testFragmentSmallCommand() {
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        
        let pdvs = fragmenter.fragmentCommand(cmd, presentationContextID: 1)
        
        // Small command should fit in single PDV
        XCTAssertEqual(pdvs.count, 1)
        XCTAssertTrue(pdvs[0].isCommand)
        XCTAssertTrue(pdvs[0].isLastFragment)
        XCTAssertEqual(pdvs[0].presentationContextID, 1)
    }
    
    func testFragmentDataSet() {
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        
        // Create data set that's smaller than max size
        let dataSet = Data(repeating: 0xAB, count: 1000)
        
        let pdvs = fragmenter.fragmentDataSet(dataSet, presentationContextID: 3)
        
        // Should fit in single PDV
        XCTAssertEqual(pdvs.count, 1)
        XCTAssertFalse(pdvs[0].isCommand)
        XCTAssertTrue(pdvs[0].isLastFragment)
        XCTAssertEqual(pdvs[0].presentationContextID, 3)
        XCTAssertEqual(pdvs[0].data, dataSet)
    }
    
    func testFragmentLargeDataSet() {
        // Use small max PDU size to force fragmentation
        let fragmenter = MessageFragmenter(maxPDUSize: 100)
        
        // Create data set larger than max size
        let dataSet = Data(repeating: 0xCD, count: 500)
        
        let pdvs = fragmenter.fragmentDataSet(dataSet, presentationContextID: 5)
        
        // Should be split into multiple PDVs
        XCTAssertGreaterThan(pdvs.count, 1)
        
        // Only last should have isLastFragment = true
        for (index, pdv) in pdvs.enumerated() {
            XCTAssertFalse(pdv.isCommand)
            XCTAssertEqual(pdv.presentationContextID, 5)
            if index == pdvs.count - 1 {
                XCTAssertTrue(pdv.isLastFragment)
            } else {
                XCTAssertFalse(pdv.isLastFragment)
            }
        }
        
        // Reassemble and verify
        var reassembled = Data()
        for pdv in pdvs {
            reassembled.append(pdv.data)
        }
        XCTAssertEqual(reassembled, dataSet)
    }
    
    func testCreateDataTransferPDUs() {
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        
        let pdvs = fragmenter.fragmentCommand(cmd, presentationContextID: 1)
        let pdus = fragmenter.createDataTransferPDUs(from: pdvs)
        
        XCTAssertEqual(pdus.count, pdvs.count)
        XCTAssertEqual(pdus[0].presentationDataValues.count, 1)
    }
    
    func testFragmentCompleteMessage() {
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        
        var cmd = CommandSet()
        cmd.setCommand(.cStoreRequest)
        cmd.setMessageID(1)
        cmd.setAffectedSOPClassUID("1.2.840.10008.5.1.4.1.1.7")
        cmd.setAffectedSOPInstanceUID("1.2.3.4.5.6.7.8.9")
        cmd.setHasDataSet(true)
        
        let dataSet = Data(repeating: 0xEF, count: 100)
        
        let pdus = fragmenter.fragmentMessage(
            commandSet: cmd,
            dataSet: dataSet,
            presentationContextID: 3
        )
        
        // Should have at least 2 PDUs (command + data set)
        XCTAssertGreaterThanOrEqual(pdus.count, 2)
        
        // First PDU should contain command
        XCTAssertTrue(pdus[0].presentationDataValues[0].isCommand)
        
        // Last PDU should contain data set
        XCTAssertFalse(pdus.last!.presentationDataValues[0].isCommand)
    }
    
    func testFragmentMessageWithoutDataSet() {
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(1)
        cmd.setHasDataSet(false)
        
        let pdus = fragmenter.fragmentMessage(
            commandSet: cmd,
            dataSet: nil,
            presentationContextID: 1
        )
        
        // Should have 1 PDU (command only)
        XCTAssertEqual(pdus.count, 1)
        XCTAssertTrue(pdus[0].presentationDataValues[0].isCommand)
        XCTAssertTrue(pdus[0].presentationDataValues[0].isLastFragment)
    }
}
