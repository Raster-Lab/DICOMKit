import XCTest
import DICOMCore
@testable import DICOMNetwork

final class QueryServiceTests: XCTestCase {
    
    // MARK: - Query Configuration Tests
    
    func testQueryConfigurationDefaults() throws {
        let callingAE = try AETitle("CALLING")
        let calledAE = try AETitle("CALLED")
        
        let config = QueryConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE
        )
        
        XCTAssertEqual(config.callingAETitle.value, "CALLING")
        XCTAssertEqual(config.calledAETitle.value, "CALLED")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.maxPDUSize, defaultMaxPDUSize)
        XCTAssertEqual(config.implementationClassUID, QueryConfiguration.defaultImplementationClassUID)
        XCTAssertEqual(config.implementationVersionName, QueryConfiguration.defaultImplementationVersionName)
        XCTAssertEqual(config.informationModel, .studyRoot)
    }
    
    func testQueryConfigurationCustomValues() throws {
        let callingAE = try AETitle("MY_SCU")
        let calledAE = try AETitle("PACS")
        
        let config = QueryConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 120,
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5",
            implementationVersionName: "TEST_V1",
            informationModel: .patientRoot
        )
        
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.calledAETitle.value, "PACS")
        XCTAssertEqual(config.timeout, 120)
        XCTAssertEqual(config.maxPDUSize, 32768)
        XCTAssertEqual(config.implementationClassUID, "1.2.3.4.5")
        XCTAssertEqual(config.implementationVersionName, "TEST_V1")
        XCTAssertEqual(config.informationModel, .patientRoot)
    }
    
    func testQueryConfigurationHashable() throws {
        let callingAE = try AETitle("SCU")
        let calledAE = try AETitle("SCP")
        
        let config1 = QueryConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 60
        )
        let config2 = QueryConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 60
        )
        let config3 = QueryConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: 120
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    // MARK: - Default Implementation Constants Tests
    
    func testDefaultImplementationClassUID() {
        let uid = QueryConfiguration.defaultImplementationClassUID
        XCTAssertFalse(uid.isEmpty)
        XCTAssertTrue(uid.hasPrefix("1.2."))
    }
    
    func testDefaultImplementationVersionName() {
        let name = QueryConfiguration.defaultImplementationVersionName
        XCTAssertNotNil(name)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains("DICOMKIT"))
    }
    
    // MARK: - C-FIND Message Tests
    
    func testCFindRequestCreation() {
        let request = CFindRequest(
            messageID: 1,
            affectedSOPClassUID: studyRootQueryRetrieveFindSOPClassUID,
            priority: .medium,
            presentationContextID: 1
        )
        
        XCTAssertEqual(request.messageID, 1)
        XCTAssertEqual(request.affectedSOPClassUID, studyRootQueryRetrieveFindSOPClassUID)
        XCTAssertEqual(request.priority, .medium)
        XCTAssertEqual(request.presentationContextID, 1)
        XCTAssertTrue(request.hasDataSet)
        XCTAssertEqual(request.commandSet.command, .cFindRequest)
    }
    
    func testCFindRequestWithPatientRootModel() {
        let request = CFindRequest(
            messageID: 1,
            affectedSOPClassUID: patientRootQueryRetrieveFindSOPClassUID,
            priority: .high,
            presentationContextID: 3
        )
        
        XCTAssertEqual(request.affectedSOPClassUID, patientRootQueryRetrieveFindSOPClassUID)
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.presentationContextID, 3)
    }
    
    func testCFindResponseCreation() {
        // Success response
        let successResponse = CFindResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: studyRootQueryRetrieveFindSOPClassUID,
            status: .success,
            hasDataSet: false,
            presentationContextID: 1
        )
        
        XCTAssertEqual(successResponse.messageIDBeingRespondedTo, 1)
        XCTAssertEqual(successResponse.affectedSOPClassUID, studyRootQueryRetrieveFindSOPClassUID)
        XCTAssertTrue(successResponse.status.isSuccess)
        XCTAssertFalse(successResponse.hasDataSet)
        
        // Pending response
        let pendingResponse = CFindResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: studyRootQueryRetrieveFindSOPClassUID,
            status: .pending(warningOptionalKeys: false),
            hasDataSet: true,
            presentationContextID: 1
        )
        
        XCTAssertTrue(pendingResponse.status.isPending)
        XCTAssertTrue(pendingResponse.hasDataSet)
    }
    
    func testCFindCommandSetEncoding() {
        let request = CFindRequest(
            messageID: 42,
            affectedSOPClassUID: studyRootQueryRetrieveFindSOPClassUID,
            priority: .medium,
            presentationContextID: 1
        )
        
        let encodedData = request.commandSet.encode()
        
        // Verify the command set can be encoded
        XCTAssertGreaterThan(encodedData.count, 0)
        
        // Verify round-trip decode
        do {
            let decodedCommandSet = try CommandSet.decode(from: encodedData)
            XCTAssertEqual(decodedCommandSet.command, .cFindRequest)
            XCTAssertEqual(decodedCommandSet.messageID, 42)
            XCTAssertEqual(decodedCommandSet.affectedSOPClassUID, studyRootQueryRetrieveFindSOPClassUID)
            XCTAssertTrue(decodedCommandSet.hasDataSet)
        } catch {
            XCTFail("Failed to decode command set: \(error)")
        }
    }
    
    // MARK: - Message Fragmentation Tests
    
    func testCFindRequestFragmentation() {
        let request = CFindRequest(
            messageID: 1,
            affectedSOPClassUID: studyRootQueryRetrieveFindSOPClassUID,
            presentationContextID: 1
        )
        
        // Create a sample identifier data set
        let identifierData = Data([0x08, 0x00, 0x52, 0x00]) // Query Retrieve Level tag
        
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: identifierData,
            presentationContextID: 1
        )
        
        // Should have at least command and data set PDVs
        XCTAssertGreaterThanOrEqual(pdus.count, 2)
        
        // First PDU should be command
        let commandPDU = pdus[0]
        XCTAssertEqual(commandPDU.presentationDataValues.count, 1)
        XCTAssertTrue(commandPDU.presentationDataValues[0].isCommand)
    }
    
    // MARK: - Presentation Context Tests
    
    func testCFindPresentationContextCreation() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: studyRootQueryRetrieveFindSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        XCTAssertEqual(context.id, 1)
        XCTAssertEqual(context.abstractSyntax, studyRootQueryRetrieveFindSOPClassUID)
        XCTAssertEqual(context.transferSyntaxes.count, 2)
    }
    
    // MARK: - Message Assembly Tests
    
    func testCFindResponseAssembly() throws {
        // Create a C-FIND response (pending, with data set)
        let response = CFindResponse(
            messageIDBeingRespondedTo: 1,
            affectedSOPClassUID: studyRootQueryRetrieveFindSOPClassUID,
            status: .pending(warningOptionalKeys: false),
            hasDataSet: true,
            presentationContextID: 1
        )
        
        // Create sample data set
        let dataSetData = Data([0x08, 0x00, 0x52, 0x00, 0x43, 0x53, 0x06, 0x00, 0x53, 0x54, 0x55, 0x44, 0x59, 0x20])
        
        // Fragment it
        let fragmenter = MessageFragmenter(maxPDUSize: 16384)
        let pdus = fragmenter.fragmentMessage(
            commandSet: response.commandSet,
            dataSet: dataSetData,
            presentationContextID: 1
        )
        
        // Assemble it back
        let assembler = MessageAssembler()
        var assembledMessage: AssembledMessage?
        
        for pdu in pdus {
            assembledMessage = try assembler.addPDVs(from: pdu)
        }
        
        XCTAssertNotNil(assembledMessage)
        
        let findResponse = assembledMessage?.asCFindResponse()
        XCTAssertNotNil(findResponse)
        XCTAssertEqual(findResponse?.messageIDBeingRespondedTo, 1)
        XCTAssertTrue(findResponse?.status.isPending ?? false)
    }
    
    // MARK: - VR Extension Tests
    
    func testVRIsStringVR() {
        // String VRs
        XCTAssertTrue(VR.AE.isStringVR)
        XCTAssertTrue(VR.CS.isStringVR)
        XCTAssertTrue(VR.DA.isStringVR)
        XCTAssertTrue(VR.LO.isStringVR)
        XCTAssertTrue(VR.PN.isStringVR)
        XCTAssertTrue(VR.SH.isStringVR)
        XCTAssertTrue(VR.TM.isStringVR)
        XCTAssertTrue(VR.UI.isStringVR)
        
        // Non-string VRs
        XCTAssertFalse(VR.US.isStringVR)
        XCTAssertFalse(VR.UL.isStringVR)
        XCTAssertFalse(VR.OB.isStringVR)
        XCTAssertFalse(VR.OW.isStringVR)
    }
    
    func testVRUses4ByteLength() {
        // VRs that use 4-byte length
        XCTAssertTrue(VR.OB.uses4ByteLength)
        XCTAssertTrue(VR.OW.uses4ByteLength)
        XCTAssertTrue(VR.SQ.uses4ByteLength)
        XCTAssertTrue(VR.UN.uses4ByteLength)
        XCTAssertTrue(VR.UC.uses4ByteLength)
        XCTAssertTrue(VR.UR.uses4ByteLength)
        XCTAssertTrue(VR.UT.uses4ByteLength)
        
        // VRs that use 2-byte length
        XCTAssertFalse(VR.AE.uses4ByteLength)
        XCTAssertFalse(VR.CS.uses4ByteLength)
        XCTAssertFalse(VR.DA.uses4ByteLength)
        XCTAssertFalse(VR.US.uses4ByteLength)
        XCTAssertFalse(VR.UL.uses4ByteLength)
    }
    
    // MARK: - Error Type Tests
    
    func testQueryFailedError() {
        let error = DICOMNetworkError.queryFailed(.refusedOutOfResources)
        
        switch error {
        case .queryFailed(let status):
            XCTAssertTrue(status.isFailure)
            XCTAssertEqual(status.rawValue, 0xA700)
        default:
            XCTFail("Expected queryFailed error")
        }
        
        let description = error.description
        XCTAssertTrue(description.contains("Query failed"))
    }
}
