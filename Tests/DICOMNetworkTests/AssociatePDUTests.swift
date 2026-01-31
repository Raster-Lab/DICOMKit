import Testing
import Foundation
@testable import DICOMNetwork

// Helper function to read big-endian UInt32 from data
fileprivate func readUInt32BigEndian(from data: Data, at offset: Int) -> UInt32 {
    return (UInt32(data[offset]) << 24) |
           (UInt32(data[offset + 1]) << 16) |
           (UInt32(data[offset + 2]) << 8) |
           UInt32(data[offset + 3])
}

@Suite("Associate Request PDU Tests")
struct AssociateRequestPDUTests {
    
    @Test("Associate Request PDU creation")
    func testAssociateRequestCreation() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let request = AssociateRequestPDU(
            calledAETitle: try AETitle("PACS_SERVER"),
            callingAETitle: try AETitle("MY_CLIENT"),
            presentationContexts: [context],
            implementationClassUID: "1.2.3.4.5.6.7.8.9"
        )
        
        #expect(request.pduType == .associateRequest)
        #expect(request.calledAETitle.value == "PACS_SERVER")
        #expect(request.callingAETitle.value == "MY_CLIENT")
        #expect(request.presentationContexts.count == 1)
        #expect(request.maxPDUSize == defaultMaxPDUSize)
        #expect(request.implementationClassUID == "1.2.3.4.5.6.7.8.9")
        #expect(request.applicationContextName == AssociateRequestPDU.dicomApplicationContextName)
    }
    
    @Test("Associate Request PDU encoding")
    func testAssociateRequestEncoding() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let request = AssociateRequestPDU(
            calledAETitle: try AETitle("SCP"),
            callingAETitle: try AETitle("SCU"),
            presentationContexts: [context],
            implementationClassUID: "1.2.3.4.5"
        )
        
        let data = try request.encode()
        
        // PDU Type should be 0x01
        #expect(data[0] == 0x01)
        
        // Reserved byte should be 0x00
        #expect(data[1] == 0x00)
        
        // PDU Length (4 bytes, big endian)
        let pduLength = readUInt32BigEndian(from: data, at: 2)
        #expect(pduLength > 0)
        
        // Total length should match
        #expect(data.count == 6 + Int(pduLength))
    }
    
    @Test("Associate Request PDU with version name")
    func testAssociateRequestWithVersionName() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let request = AssociateRequestPDU(
            calledAETitle: try AETitle("SCP"),
            callingAETitle: try AETitle("SCU"),
            presentationContexts: [context],
            implementationClassUID: "1.2.3.4.5",
            implementationVersionName: "DICOMKIT_0_6"
        )
        
        #expect(request.implementationVersionName == "DICOMKIT_0_6")
        
        // Should encode without error
        let data = try request.encode()
        #expect(data.count > 0)
    }
    
    @Test("Associate Request round-trip encoding/decoding")
    func testAssociateRequestRoundTrip() throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.5.1.4.1.1.7",
            transferSyntaxes: ["1.2.840.10008.1.2.1"]
        )
        
        let original = AssociateRequestPDU(
            calledAETitle: try AETitle("PACS_SERVER"),
            callingAETitle: try AETitle("MY_CLIENT"),
            presentationContexts: [context],
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5.6.7.8.9",
            implementationVersionName: "TEST_V1"
        )
        
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedRequest = decoded as? AssociateRequestPDU else {
            #expect(Bool(false), "Decoded PDU is not AssociateRequestPDU")
            return
        }
        
        #expect(decodedRequest.calledAETitle == original.calledAETitle)
        #expect(decodedRequest.callingAETitle == original.callingAETitle)
        #expect(decodedRequest.presentationContexts.count == original.presentationContexts.count)
        #expect(decodedRequest.maxPDUSize == original.maxPDUSize)
        #expect(decodedRequest.implementationClassUID == original.implementationClassUID)
        #expect(decodedRequest.implementationVersionName == original.implementationVersionName)
    }
}

@Suite("Associate Accept PDU Tests")
struct AssociateAcceptPDUTests {
    
    @Test("Associate Accept PDU creation")
    func testAssociateAcceptCreation() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let accept = AssociateAcceptPDU(
            calledAETitle: try AETitle("MY_CLIENT"),
            callingAETitle: try AETitle("PACS_SERVER"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5.6.7"
        )
        
        #expect(accept.pduType == .associateAccept)
        #expect(accept.presentationContexts.count == 1)
        #expect(accept.acceptedContextIDs.count == 1)
        #expect(accept.acceptedContextIDs[0] == 1)
    }
    
    @Test("Associate Accept PDU encoding")
    func testAssociateAcceptEncoding() throws {
        let accepted = AcceptedPresentationContext(
            id: 1,
            result: .acceptance,
            transferSyntax: "1.2.840.10008.1.2.1"
        )
        
        let accept = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: [accepted],
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5"
        )
        
        let data = try accept.encode()
        
        // PDU Type should be 0x02
        #expect(data[0] == 0x02)
        #expect(data.count > 6)
    }
    
    @Test("Associate Accept get accepted transfer syntax")
    func testAcceptedTransferSyntax() throws {
        let contexts = [
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: "1.2.840.10008.1.2.1"),
            AcceptedPresentationContext(id: 3, result: .abstractSyntaxNotSupported, transferSyntax: nil)
        ]
        
        let accept = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4.5"
        )
        
        #expect(accept.acceptedTransferSyntax(forContextID: 1) == "1.2.840.10008.1.2.1")
        #expect(accept.acceptedTransferSyntax(forContextID: 3) == nil)
        #expect(accept.acceptedTransferSyntax(forContextID: 5) == nil)
    }
    
    @Test("Associate Accept round-trip encoding/decoding")
    func testAssociateAcceptRoundTrip() throws {
        let contexts = [
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: "1.2.840.10008.1.2.1"),
            AcceptedPresentationContext(id: 3, result: .abstractSyntaxNotSupported, transferSyntax: nil)
        ]
        
        let original = AssociateAcceptPDU(
            calledAETitle: try AETitle("SCU"),
            callingAETitle: try AETitle("SCP"),
            presentationContexts: contexts,
            maxPDUSize: 32768,
            implementationClassUID: "1.2.3.4.5.6",
            implementationVersionName: "TEST"
        )
        
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedAccept = decoded as? AssociateAcceptPDU else {
            #expect(Bool(false), "Decoded PDU is not AssociateAcceptPDU")
            return
        }
        
        #expect(decodedAccept.calledAETitle == original.calledAETitle)
        #expect(decodedAccept.callingAETitle == original.callingAETitle)
        #expect(decodedAccept.presentationContexts.count == original.presentationContexts.count)
        #expect(decodedAccept.maxPDUSize == original.maxPDUSize)
    }
}

@Suite("Associate Reject PDU Tests")
struct AssociateRejectPDUTests {
    
    @Test("Associate Reject PDU creation")
    func testAssociateRejectCreation() {
        let reject = AssociateRejectPDU(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 3
        )
        
        #expect(reject.pduType == .associateReject)
        #expect(reject.result == .rejectedPermanent)
        #expect(reject.source == .serviceUser)
        #expect(reject.reason == 3)
    }
    
    @Test("Associate Reject PDU encoding")
    func testAssociateRejectEncoding() throws {
        let reject = AssociateRejectPDU(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 7
        )
        
        let data = try reject.encode()
        
        // PDU Type should be 0x03
        #expect(data[0] == 0x03)
        
        // PDU Length should be 4
        let pduLength = readUInt32BigEndian(from: data, at: 2)
        #expect(pduLength == 4)
        
        // Total size should be 10 bytes
        #expect(data.count == 10)
    }
    
    @Test("Associate Reject reason descriptions")
    func testAssociateRejectReasonDescriptions() {
        // Service User reasons
        var reject = AssociateRejectPDU(result: .rejectedPermanent, source: .serviceUser, reason: 1)
        #expect(reject.reasonDescription.contains("No reason"))
        
        reject = AssociateRejectPDU(result: .rejectedPermanent, source: .serviceUser, reason: 3)
        #expect(reject.reasonDescription.contains("Calling AE title"))
        
        reject = AssociateRejectPDU(result: .rejectedPermanent, source: .serviceUser, reason: 7)
        #expect(reject.reasonDescription.contains("Called AE title"))
        
        // Service Provider (ACSE) reasons
        reject = AssociateRejectPDU(result: .rejectedTransient, source: .serviceProviderACSE, reason: 2)
        #expect(reject.reasonDescription.contains("Protocol version"))
        
        // Service Provider (Presentation) reasons
        reject = AssociateRejectPDU(result: .rejectedTransient, source: .serviceProviderPresentation, reason: 1)
        #expect(reject.reasonDescription.contains("congestion"))
    }
    
    @Test("Associate Reject round-trip encoding/decoding")
    func testAssociateRejectRoundTrip() throws {
        let original = AssociateRejectPDU(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 7
        )
        
        let encoded = try original.encode()
        let decoded = try PDUDecoder.decode(from: encoded)
        
        guard let decodedReject = decoded as? AssociateRejectPDU else {
            #expect(Bool(false), "Decoded PDU is not AssociateRejectPDU")
            return
        }
        
        #expect(decodedReject.result == original.result)
        #expect(decodedReject.source == original.source)
        #expect(decodedReject.reason == original.reason)
    }
}
