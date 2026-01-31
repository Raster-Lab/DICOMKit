import Testing
import Foundation
@testable import DICOMNetwork

@Suite("Association State Machine Tests")
struct AssociationStateMachineTests {
    
    @Test("Initial state is idle")
    func testInitialState() {
        let stateMachine = AssociationStateMachine()
        #expect(stateMachine.state == .idle)
    }
    
    @Test("State machine can be initialized with custom state")
    func testCustomInitialState() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        #expect(stateMachine.state == .established)
    }
    
    @Test("Transport connected transitions from idle to awaiting transport open")
    func testTransportConnected() {
        let stateMachine = AssociationStateMachine()
        let result = stateMachine.handleEvent(.transportConnected)
        
        #expect(result.newState == .awaitingTransportOpen)
        #expect(stateMachine.state == .awaitingTransportOpen)
    }
    
    @Test("Associate request sent transitions to awaiting remote response")
    func testAssociateRequestSent() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingTransportOpen)
        let result = stateMachine.handleEvent(.associateRequestSent)
        
        #expect(result.newState == .awaitingRemoteAssociateResponse)
        #expect(stateMachine.state == .awaitingRemoteAssociateResponse)
    }
    
    @Test("Associate accept transitions to established state")
    func testAssociateAcceptReceived() throws {
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteAssociateResponse)
        
        let acceptedContext = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: [acceptedContext],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5"
        )
        
        let result = stateMachine.handleEvent(.associateAcceptReceived(acceptPDU))
        
        #expect(result.newState == .established)
        #expect(stateMachine.state == .established)
        #expect(result.actions.count > 0)
    }
    
    @Test("Associate reject transitions to idle state")
    func testAssociateRejectReceived() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteAssociateResponse)
        
        let rejectPDU = AssociateRejectPDU(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 7
        )
        
        let result = stateMachine.handleEvent(.associateRejectReceived(rejectPDU))
        
        #expect(result.newState == .idle)
        #expect(stateMachine.state == .idle)
    }
    
    @Test("Data transfer in established state stays established")
    func testDataTransferInEstablishedState() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        
        let pdv = PresentationDataValue(
            presentationContextID: 1,
            isCommand: true,
            isLastFragment: true,
            data: Data([0x01, 0x02])
        )
        let dataPDU = DataTransferPDU(pdv: pdv)
        
        let result = stateMachine.handleEvent(.dataTransferReceived(dataPDU))
        
        #expect(result.newState == .established)
        #expect(stateMachine.state == .established)
    }
    
    @Test("Local release request transitions to awaiting remote release response")
    func testLocalReleaseRequest() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        
        let result = stateMachine.handleEvent(.localReleaseRequest)
        
        #expect(result.newState == .awaitingRemoteReleaseResponse)
        #expect(stateMachine.state == .awaitingRemoteReleaseResponse)
    }
    
    @Test("Release response received completes release")
    func testReleaseResponseReceived() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteReleaseResponse)
        
        let result = stateMachine.handleEvent(.releaseResponseReceived)
        
        #expect(result.newState == .idle)
        #expect(stateMachine.state == .idle)
    }
    
    @Test("Abort received in established state transitions to idle")
    func testAbortReceivedInEstablishedState() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        
        let abortPDU = AbortPDU(source: .serviceUser, reason: 0)
        let result = stateMachine.handleEvent(.abortReceived(abortPDU))
        
        #expect(result.newState == .idle)
        #expect(stateMachine.state == .idle)
    }
    
    @Test("Local abort request from established state")
    func testLocalAbortRequest() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        
        let result = stateMachine.handleEvent(.localAbortRequest)
        
        #expect(result.newState == .awaitingTransportClose)
        #expect(stateMachine.state == .awaitingTransportClose)
    }
    
    @Test("Transport connection closed completes transport close")
    func testTransportConnectionClosed() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingTransportClose)
        
        let result = stateMachine.handleEvent(.transportConnectionClosed)
        
        #expect(result.newState == .idle)
        #expect(stateMachine.state == .idle)
    }
    
    @Test("Release collision handling")
    func testReleaseCollision() {
        // When we sent release request and receive one back (collision)
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteReleaseResponse)
        
        let result = stateMachine.handleEvent(.releaseRequestReceived)
        
        #expect(result.newState == .releaseCollision)
        #expect(stateMachine.state == .releaseCollision)
    }
    
    @Test("Reset state machine")
    func testReset() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        stateMachine.reset()
        
        #expect(stateMachine.state == .idle)
    }
    
    @Test("Transport connection failure from any state")
    func testTransportConnectionFailure() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        
        let result = stateMachine.handleEvent(.transportConnectionFailed)
        
        #expect(result.newState == .idle)
    }
}

@Suite("Association State Tests")
struct AssociationStateTests {
    
    @Test("canTransferData is true only in established state")
    func testCanTransferData() {
        #expect(AssociationState.established.canTransferData == true)
        #expect(AssociationState.idle.canTransferData == false)
        #expect(AssociationState.awaitingRemoteAssociateResponse.canTransferData == false)
        #expect(AssociationState.awaitingRemoteReleaseResponse.canTransferData == false)
    }
    
    @Test("isTerminal is true only for idle state")
    func testIsTerminal() {
        #expect(AssociationState.idle.isTerminal == true)
        #expect(AssociationState.established.isTerminal == false)
        #expect(AssociationState.awaitingTransportClose.isTerminal == false)
    }
    
    @Test("State descriptions are human readable")
    func testStateDescriptions() {
        #expect(AssociationState.idle.description.contains("Idle"))
        #expect(AssociationState.established.description.contains("Established"))
        #expect(AssociationState.awaitingRemoteAssociateResponse.description.contains("Associate"))
    }
}

@Suite("Association Configuration Tests")
struct AssociationConfigurationTests {
    
    @Test("Configuration can be created with default values")
    func testDefaultConfiguration() throws {
        let config = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            implementationClassUID: "1.2.3.4.5"
        )
        
        #expect(config.callingAETitle.value == "SCU")
        #expect(config.calledAETitle.value == "SCP")
        #expect(config.host == "localhost")
        #expect(config.port == dicomDefaultPort)
        #expect(config.maxPDUSize == defaultMaxPDUSize)
        #expect(config.timeout == 30)
        #expect(config.tlsEnabled == false)
    }
    
    @Test("Configuration can be created with custom values")
    func testCustomConfiguration() throws {
        let config = AssociationConfiguration(
            callingAETitle: try AETitle("MY_SCU"),
            calledAETitle: try AETitle("PACS"),
            host: "192.168.1.100",
            port: 11112,
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5.6.7.8.9",
            implementationVersionName: "TestVersion",
            timeout: 60,
            tlsEnabled: true
        )
        
        #expect(config.callingAETitle.value == "MY_SCU")
        #expect(config.calledAETitle.value == "PACS")
        #expect(config.host == "192.168.1.100")
        #expect(config.port == 11112)
        #expect(config.maxPDUSize == 32768)
        #expect(config.implementationClassUID == "1.2.3.4.5.6.7.8.9")
        #expect(config.implementationVersionName == "TestVersion")
        #expect(config.timeout == 60)
        #expect(config.tlsEnabled == true)
    }
    
    @Test("Configuration is Hashable")
    func testConfigurationHashable() throws {
        let config1 = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            implementationClassUID: "1.2.3.4.5"
        )
        
        let config2 = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            implementationClassUID: "1.2.3.4.5"
        )
        
        #expect(config1 == config2)
        #expect(config1.hashValue == config2.hashValue)
    }
}

@Suite("Negotiated Association Tests")
struct NegotiatedAssociationTests {
    
    @Test("Negotiated association extracts accepted contexts")
    func testNegotiatedAssociation() throws {
        let contexts = [
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: "1.2.840.10008.1.2.1"),
            AcceptedPresentationContext(id: 3, result: .abstractSyntaxNotSupported, transferSyntax: nil)
        ]
        
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5.6",
            implementationVersionName: "TEST"
        )
        
        let negotiated = NegotiatedAssociation(acceptPDU: acceptPDU, localMaxPDUSize: 16384)
        
        #expect(negotiated.acceptedPresentationContexts.count == 2)
        #expect(negotiated.maxPDUSize == 16384)  // Min of local and remote
        #expect(negotiated.remoteImplementationClassUID == "1.2.3.4.5.6")
        #expect(negotiated.remoteImplementationVersionName == "TEST")
    }
    
    @Test("Negotiated max PDU size is minimum of local and remote")
    func testNegotiatedMaxPDUSize() throws {
        let contexts = [
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: "1.2.840.10008.1.2.1")
        ]
        
        // Remote is smaller
        let acceptPDU1 = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 8192,
            implementationClassUID: "1.2.3"
        )
        
        let negotiated1 = NegotiatedAssociation(acceptPDU: acceptPDU1, localMaxPDUSize: 16384)
        #expect(negotiated1.maxPDUSize == 8192)
        
        // Local is smaller
        let acceptPDU2 = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 65536,
            implementationClassUID: "1.2.3"
        )
        
        let negotiated2 = NegotiatedAssociation(acceptPDU: acceptPDU2, localMaxPDUSize: 16384)
        #expect(negotiated2.maxPDUSize == 16384)
    }
    
    @Test("acceptedTransferSyntax returns correct value")
    func testAcceptedTransferSyntax() throws {
        let contexts = [
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: "1.2.840.10008.1.2.1"),
            AcceptedPresentationContext(id: 3, result: .acceptance, transferSyntax: "1.2.840.10008.1.2"),
            AcceptedPresentationContext(id: 5, result: .transferSyntaxesNotSupported, transferSyntax: nil)
        ]
        
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3"
        )
        
        let negotiated = NegotiatedAssociation(acceptPDU: acceptPDU, localMaxPDUSize: 16384)
        
        #expect(negotiated.acceptedTransferSyntax(forContextID: 1) == "1.2.840.10008.1.2.1")
        #expect(negotiated.acceptedTransferSyntax(forContextID: 3) == "1.2.840.10008.1.2")
        #expect(negotiated.acceptedTransferSyntax(forContextID: 5) == nil)  // Not accepted
        #expect(negotiated.acceptedTransferSyntax(forContextID: 7) == nil)  // Not present
    }
    
    @Test("isContextAccepted returns correct value")
    func testIsContextAccepted() throws {
        let contexts = [
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: "1.2.840.10008.1.2.1"),
            AcceptedPresentationContext(id: 3, result: .abstractSyntaxNotSupported, transferSyntax: nil)
        ]
        
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3"
        )
        
        let negotiated = NegotiatedAssociation(acceptPDU: acceptPDU, localMaxPDUSize: 16384)
        
        #expect(negotiated.isContextAccepted(1) == true)
        #expect(negotiated.isContextAccepted(3) == false)
        #expect(negotiated.isContextAccepted(5) == false)
    }
}

@Suite("DICOM Port Constants Tests")
struct DICOMPortConstantsTests {
    
    @Test("Default port is 104")
    func testDefaultPort() {
        #expect(dicomDefaultPort == 104)
    }
    
    @Test("Alternative port is 11112")
    func testAlternativePort() {
        #expect(dicomAlternativePort == 11112)
    }
}

@Suite("ARTIM Timer Tests")
struct ARTIMTimerTests {
    
    @Test("Configuration includes default ARTIM timeout")
    func testDefaultARTIMTimeout() throws {
        let config = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            implementationClassUID: "1.2.3.4.5"
        )
        
        #expect(config.artimTimeout == 30)
    }
    
    @Test("Configuration can have custom ARTIM timeout")
    func testCustomARTIMTimeout() throws {
        let config = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            implementationClassUID: "1.2.3.4.5",
            artimTimeout: 60
        )
        
        #expect(config.artimTimeout == 60)
    }
    
    @Test("Configuration can disable ARTIM timeout")
    func testDisabledARTIMTimeout() throws {
        let config = AssociationConfiguration(
            callingAETitle: try AETitle("SCU"),
            calledAETitle: try AETitle("SCP"),
            host: "localhost",
            implementationClassUID: "1.2.3.4.5",
            artimTimeout: nil
        )
        
        #expect(config.artimTimeout == nil)
    }
    
    @Test("ARTIM timer expiration transitions state from awaiting remote associate response")
    func testARTIMExpirationFromAwaitingRemoteAssociateResponse() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteAssociateResponse)
        
        let result = stateMachine.handleEvent(.artimTimerExpired)
        
        #expect(result.newState == .awaitingTransportClose)
        #expect(stateMachine.state == .awaitingTransportClose)
    }
    
    @Test("ARTIM timer expiration transitions state from awaiting remote release response")
    func testARTIMExpirationFromAwaitingRemoteReleaseResponse() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteReleaseResponse)
        
        let result = stateMachine.handleEvent(.artimTimerExpired)
        
        #expect(result.newState == .awaitingTransportClose)
        #expect(stateMachine.state == .awaitingTransportClose)
    }
    
    @Test("ARTIM timer expiration generates abort action")
    func testARTIMExpirationGeneratesAbortAction() {
        let stateMachine = AssociationStateMachine(initialState: .awaitingRemoteAssociateResponse)
        
        let result = stateMachine.handleEvent(.artimTimerExpired)
        
        // Should have an abort action
        let hasAbortAction = result.actions.contains { action in
            if case .sendAbort = action {
                return true
            }
            return false
        }
        #expect(hasAbortAction == true)
    }
    
    @Test("ARTIM timer event is ignored in established state")
    func testARTIMIgnoredInEstablishedState() {
        let stateMachine = AssociationStateMachine(initialState: .established)
        
        let result = stateMachine.handleEvent(.artimTimerExpired)
        
        // Should stay in established state (default handler)
        #expect(result.newState == .established)
        #expect(stateMachine.state == .established)
    }
    
    @Test("ARTIM timer event is ignored in idle state")
    func testARTIMIgnoredInIdleState() {
        let stateMachine = AssociationStateMachine(initialState: .idle)
        
        let result = stateMachine.handleEvent(.artimTimerExpired)
        
        // Should stay in idle state (default handler)
        #expect(result.newState == .idle)
        #expect(stateMachine.state == .idle)
    }
}
