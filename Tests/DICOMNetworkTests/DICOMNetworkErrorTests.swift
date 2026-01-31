import Testing
@testable import DICOMNetwork

@Suite("DICOM Network Error Tests")
struct DICOMNetworkErrorTests {
    
    @Test("Error descriptions are informative")
    func testErrorDescriptions() {
        let connectionError = DICOMNetworkError.connectionFailed("Host unreachable")
        #expect(connectionError.description.contains("Host unreachable"))
        
        let timeoutError = DICOMNetworkError.timeout
        #expect(timeoutError.description.contains("timed out"))
        
        let pduError = DICOMNetworkError.invalidPDU("Bad format")
        #expect(pduError.description.contains("Bad format"))
        
        let pduSizeError = DICOMNetworkError.pduTooLarge(received: 100000, maximum: 16384)
        #expect(pduSizeError.description.contains("100000"))
        #expect(pduSizeError.description.contains("16384"))
        
        let unexpectedPDUError = DICOMNetworkError.unexpectedPDUType(expected: .associateAccept, received: .abort)
        #expect(unexpectedPDUError.description.contains("A-ASSOCIATE-AC"))
        #expect(unexpectedPDUError.description.contains("A-ABORT"))
        
        let rejectError = DICOMNetworkError.associationRejected(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 3
        )
        #expect(rejectError.description.contains("rejected"))
        
        let abortError = DICOMNetworkError.associationAborted(source: .serviceProvider, reason: 2)
        #expect(abortError.description.contains("aborted"))
        
        let noPCError = DICOMNetworkError.noPresentationContextAccepted
        #expect(noPCError.description.contains("presentation context"))
        
        let sopError = DICOMNetworkError.sopClassNotSupported("1.2.3.4.5")
        #expect(sopError.description.contains("1.2.3.4.5"))
        
        let aeError = DICOMNetworkError.invalidAETitle("TOOLONGANAMETOUSE!")
        #expect(aeError.description.contains("TOOLONGANAMETOUSE!"))
        
        let closedError = DICOMNetworkError.connectionClosed
        #expect(closedError.description.contains("closed"))
        
        let stateError = DICOMNetworkError.invalidState("Not connected")
        #expect(stateError.description.contains("Not connected"))
        
        let encodeError = DICOMNetworkError.encodingFailed("Buffer overflow")
        #expect(encodeError.description.contains("Buffer overflow"))
        
        let decodeError = DICOMNetworkError.decodingFailed("Invalid header")
        #expect(decodeError.description.contains("Invalid header"))
    }
    
    @Test("Associate Reject Result values")
    func testAssociateRejectResultValues() {
        #expect(AssociateRejectResult.rejectedPermanent.rawValue == 1)
        #expect(AssociateRejectResult.rejectedTransient.rawValue == 2)
        
        #expect(AssociateRejectResult.rejectedPermanent.description.contains("Permanent"))
        #expect(AssociateRejectResult.rejectedTransient.description.contains("Transient"))
    }
    
    @Test("Associate Reject Source values")
    func testAssociateRejectSourceValues() {
        #expect(AssociateRejectSource.serviceUser.rawValue == 1)
        #expect(AssociateRejectSource.serviceProviderACSE.rawValue == 2)
        #expect(AssociateRejectSource.serviceProviderPresentation.rawValue == 3)
        
        #expect(AssociateRejectSource.serviceUser.description.contains("User"))
        #expect(AssociateRejectSource.serviceProviderACSE.description.contains("ACSE"))
        #expect(AssociateRejectSource.serviceProviderPresentation.description.contains("Presentation"))
    }
    
    @Test("Abort Source values")
    func testAbortSourceValues() {
        #expect(AbortSource.serviceUser.rawValue == 0)
        #expect(AbortSource.serviceProvider.rawValue == 2)
        
        #expect(AbortSource.serviceUser.description.contains("User"))
        #expect(AbortSource.serviceProvider.description.contains("Provider"))
    }
    
    @Test("Abort Reason descriptions")
    func testAbortReasonDescriptions() {
        #expect(AbortReason.notSpecified.description.contains("not specified"))
        #expect(AbortReason.unrecognizedPDU.description.contains("Unrecognized PDU"))
        #expect(AbortReason.unexpectedPDU.description.contains("Unexpected PDU"))
        #expect(AbortReason.reserved.description.contains("Reserved"))
        #expect(AbortReason.unrecognizedPDUParameter.description.contains("parameter"))
        #expect(AbortReason.unexpectedPDUParameter.description.contains("parameter"))
        #expect(AbortReason.invalidPDUParameterValue.description.contains("Invalid"))
    }
}
