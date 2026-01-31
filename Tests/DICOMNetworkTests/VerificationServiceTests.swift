import XCTest
import DICOMCore
@testable import DICOMNetwork

final class VerificationServiceTests: XCTestCase {
    
    // MARK: - SOP Class UID Tests
    
    func testVerificationSOPClassUID() {
        XCTAssertEqual(verificationSOPClassUID, "1.2.840.10008.1.1")
    }
    
    func testTransferSyntaxUIDs() {
        XCTAssertEqual(implicitVRLittleEndianTransferSyntaxUID, "1.2.840.10008.1.2")
        XCTAssertEqual(explicitVRLittleEndianTransferSyntaxUID, "1.2.840.10008.1.2.1")
    }
    
    // MARK: - VerificationResult Tests
    
    func testVerificationResultSuccess() {
        let result = VerificationResult(
            success: true,
            status: .success,
            roundTripTime: 0.125,
            remoteAETitle: "PACS"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.status.isSuccess)
        XCTAssertEqual(result.roundTripTime, 0.125, accuracy: 0.001)
        XCTAssertEqual(result.remoteAETitle, "PACS")
    }
    
    func testVerificationResultFailure() {
        let status = DIMSEStatus.refusedOutOfResources
        let result = VerificationResult(
            success: false,
            status: status,
            roundTripTime: 0.050,
            remoteAETitle: "TEST_SCP"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.status.isFailure)
        XCTAssertEqual(result.remoteAETitle, "TEST_SCP")
    }
    
    func testVerificationResultHashable() {
        let result1 = VerificationResult(
            success: true,
            status: .success,
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        let result2 = VerificationResult(
            success: true,
            status: .success,
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        let result3 = VerificationResult(
            success: false,
            status: .success,
            roundTripTime: 0.100,
            remoteAETitle: "PACS"
        )
        
        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }
    
    func testVerificationResultDescription() {
        let result = VerificationResult(
            success: true,
            status: .success,
            roundTripTime: 0.125,
            remoteAETitle: "PACS"
        )
        
        let description = result.description
        XCTAssertTrue(description.contains("SUCCESS"))
        XCTAssertTrue(description.contains("PACS"))
    }
    
    // MARK: - VerificationConfiguration Tests
    
    func testVerificationConfigurationDefaults() throws {
        let callingAE = try AETitle("CALLING")
        let calledAE = try AETitle("CALLED")
        
        let config = VerificationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE
        )
        
        XCTAssertEqual(config.callingAETitle.value, "CALLING")
        XCTAssertEqual(config.calledAETitle.value, "CALLED")
        XCTAssertEqual(config.timeout, 30)
        XCTAssertEqual(config.maxPDUSize, defaultMaxPDUSize)
        XCTAssertEqual(config.implementationClassUID, VerificationConfiguration.defaultImplementationClassUID)
        XCTAssertEqual(config.implementationVersionName, VerificationConfiguration.defaultImplementationVersionName)
    }
    
    func testVerificationConfigurationCustomValues() throws {
        let callingAE = try AETitle("MY_SCU")
        let calledAE = try AETitle("PACS")
        
        let config = VerificationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 10,
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5",
            implementationVersionName: "TEST_V1"
        )
        
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.calledAETitle.value, "PACS")
        XCTAssertEqual(config.timeout, 10)
        XCTAssertEqual(config.maxPDUSize, 32768)
        XCTAssertEqual(config.implementationClassUID, "1.2.3.4.5")
        XCTAssertEqual(config.implementationVersionName, "TEST_V1")
    }
    
    func testVerificationConfigurationHashable() throws {
        let callingAE = try AETitle("SCU")
        let calledAE = try AETitle("SCP")
        
        let config1 = VerificationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 30
        )
        let config2 = VerificationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 30
        )
        let config3 = VerificationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 60
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    // MARK: - Default Implementation Constants Tests
    
    func testDefaultImplementationClassUID() {
        let uid = VerificationConfiguration.defaultImplementationClassUID
        XCTAssertFalse(uid.isEmpty)
        XCTAssertTrue(uid.hasPrefix("1.2."))
    }
    
    func testDefaultImplementationVersionName() {
        let name = VerificationConfiguration.defaultImplementationVersionName
        XCTAssertNotNil(name)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains("DICOMKIT"))
    }
    
    // MARK: - C-ECHO Message Integration Tests
    
    func testCEchoRequestWithVerificationSOP() {
        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, verificationSOPClassUID)
        XCTAssertFalse(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cEchoRequest)
    }
    
    func testCEchoResponseFromVerification() {
        let response = CEchoResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            status: .success,
            presentationContextID: 1
        )
        
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
        XCTAssertEqual(response.affectedSOPClassUID, verificationSOPClassUID)
        XCTAssertTrue(response.status.isSuccess)
        XCTAssertFalse(response.hasDataSet)
    }
    
    // MARK: - Presentation Context Tests
    
    func testVerificationPresentationContext() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: verificationSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        XCTAssertEqual(context.id, 1)
        XCTAssertEqual(context.abstractSyntax, verificationSOPClassUID)
        XCTAssertEqual(context.transferSyntaxes.count, 2)
        XCTAssertTrue(context.transferSyntaxes.contains(explicitVRLittleEndianTransferSyntaxUID))
        XCTAssertTrue(context.transferSyntaxes.contains(implicitVRLittleEndianTransferSyntaxUID))
    }
    
    // MARK: - Command Set Encoding Tests
    
    func testCEchoRequestCommandSetEncoding() {
        let request = CEchoRequest(
            messageID: 42,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )
        
        let encodedData = request.commandSet.encode()
        
        // Verify the command set can be encoded
        XCTAssertGreaterThan(encodedData.count, 0)
        
        // Verify round-trip decode
        do {
            let decodedCommandSet = try CommandSet.decode(from: encodedData)
            XCTAssertEqual(decodedCommandSet.command, .cEchoRequest)
            XCTAssertEqual(decodedCommandSet.messageID, 42)
            XCTAssertEqual(decodedCommandSet.affectedSOPClassUID, verificationSOPClassUID)
            XCTAssertFalse(decodedCommandSet.hasDataSet)
        } catch {
            XCTFail("Failed to decode command set: \(error)")
        }
    }
    
    func testCEchoResponseCommandSetEncoding() {
        let response = CEchoResponse(
            messageIDBeingRespondedTo: 42,
            affectedSOPClassUID: verificationSOPClassUID,
            status: .success,
            presentationContextID: 1
        )
        
        let encodedData = response.commandSet.encode()
        
        // Verify round-trip decode
        do {
            let decodedCommandSet = try CommandSet.decode(from: encodedData)
            XCTAssertEqual(decodedCommandSet.command, .cEchoResponse)
            XCTAssertEqual(decodedCommandSet.messageIDBeingRespondedTo, 42)
            XCTAssertEqual(decodedCommandSet.affectedSOPClassUID, verificationSOPClassUID)
            XCTAssertTrue(decodedCommandSet.status?.isSuccess ?? false)
            XCTAssertFalse(decodedCommandSet.hasDataSet)
        } catch {
            XCTFail("Failed to decode command set: \(error)")
        }
    }
    
    // MARK: - Message Fragmentation Tests
    
    func testCEchoRequestFragmentation() {
        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )
        
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: nil,
            presentationContextID: 1
        )
        
        // C-ECHO has no data set, should be a single PDU
        XCTAssertEqual(pdus.count, 1)
        
        // Verify PDV properties
        let pdu = pdus[0]
        XCTAssertEqual(pdu.presentationDataValues.count, 1)
        
        let pdv = pdu.presentationDataValues[0]
        XCTAssertEqual(pdv.presentationContextID, 1)
        XCTAssertTrue(pdv.isCommand)
        XCTAssertTrue(pdv.isLastFragment)
    }
    
    // MARK: - Message Assembly Tests
    
    func testCEchoResponseAssembly() throws {
        // Create a C-ECHO response
        let response = CEchoResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            status: .success,
            presentationContextID: 1
        )
        
        // Fragment it
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: response.commandSet,
            dataSet: nil,
            presentationContextID: 1
        )
        
        // Assemble it back
        let assembler = MessageAssembler()
        var assembledMessage: AssembledMessage?
        
        for pdu in pdus {
            assembledMessage = try assembler.addPDVs(from: pdu)
        }
        
        XCTAssertNotNil(assembledMessage)
        
        let echoResponse = assembledMessage?.asCEchoResponse()
        XCTAssertNotNil(echoResponse)
        XCTAssertEqual(echoResponse?.messageIDBeingRespondedTo, 1)
        XCTAssertTrue(echoResponse?.status.isSuccess ?? false)
    }
}
