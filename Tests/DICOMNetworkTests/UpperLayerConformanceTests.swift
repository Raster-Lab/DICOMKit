import Foundation
import Testing
import XCTest
@testable import DICOMNetwork

// Tests that pin DICOM PS3.8 / PS3.7 2026a Upper Layer values:
// A-ASSOCIATE-AC rejected contexts (Table 9-18), A-ABORT source/reason
// (Tables 9-9, 9-26), A-ASSOCIATE-RJ reasons (Table 9-21), the state machine
// numbering (Tables 9-1..9-5, 9-10), Maximum Length semantics (Annex D.1),
// AE Title characters (Table 9-11), implementation sub-item limits
// (PS3.7 Table D.3-3/D.3-4), Protocol-version (Table 9-11) and the DIMSE
// statuses answered by the SCPs (PS3.7 §10.1).

// MARK: - Helpers

private let explicitVRLE = "1.2.840.10008.1.2.1"
private let verificationSOPClass = "1.2.840.10008.1.1"
private let scpTitle: AETitle = "SCP"
private let scuTitle: AETitle = "SCU"

private func readUInt16BE(_ data: Data, _ offset: Int) -> Int {
    Int(data[data.startIndex + offset]) << 8 | Int(data[data.startIndex + offset + 1])
}

private extension DICOMNetworkError {
    var isConnectionClosed: Bool {
        if case .connectionClosed = self { return true }
        return false
    }
}

// MARK: - 1. A-ASSOCIATE-AC rejected presentation contexts (PS3.8 Table 9-18)

@Suite("A-ASSOCIATE-AC rejected context sub-item")
struct AssociateAcceptRejectedContextTests {

    private func makeAccept(_ contexts: [AcceptedPresentationContext]) throws -> AssociateAcceptPDU {
        AssociateAcceptPDU(
            calledAETitle: scpTitle,
            callingAETitle: scuTitle,
            presentationContexts: contexts,
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3.4"
        )
    }

    @Test("A rejected context still carries exactly one 0x40 Transfer Syntax sub-item (item-length 0)")
    func rejectedContextCarriesEmptyTransferSyntaxSubItem() throws {
        let accept = try makeAccept([
            AcceptedPresentationContext(id: 1, result: .abstractSyntaxNotSupported, transferSyntax: nil)
        ])
        let encoded = try accept.encode()

        // Locate the 0x21 item: after the 74-byte fixed part and the 0x10 item.
        var offset = 6 + 68
        #expect(encoded[offset] == 0x10)
        offset += 4 + readUInt16BE(encoded, offset + 2)
        #expect(encoded[offset] == 0x21)
        let itemLength = readUInt16BE(encoded, offset + 2)
        // ID, reserved, result, reserved + one 4-byte sub-item header with no name
        #expect(itemLength == 4 + 4)
        let subItemOffset = offset + 4 + 4
        #expect(encoded[subItemOffset] == 0x40)
        #expect(readUInt16BE(encoded, subItemOffset + 2) == 0)
        #expect(encoded[offset + 4 + 2] == PresentationContextResult.abstractSyntaxNotSupported.rawValue)
    }

    @Test("Decoding a rejected context yields transferSyntax nil and isAccepted false")
    func rejectedContextRoundTrip() throws {
        let accept = try makeAccept([
            AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: explicitVRLE),
            AcceptedPresentationContext(id: 3, result: .transferSyntaxesNotSupported, transferSyntax: nil)
        ])
        let decoded = try #require(try PDUDecoder.decode(from: try accept.encode()) as? AssociateAcceptPDU)
        #expect(decoded.presentationContexts.count == 2)
        #expect(decoded.presentationContexts[0].isAccepted)
        #expect(decoded.presentationContexts[0].transferSyntax == explicitVRLE)
        #expect(decoded.presentationContexts[1].result == .transferSyntaxesNotSupported)
        #expect(decoded.presentationContexts[1].transferSyntax == nil)
        #expect(decoded.presentationContexts[1].isAccepted == false)
        #expect(decoded.acceptedContextIDs == [1])
    }

    @Test("A rejected context whose sub-item names a syntax is not tested: transferSyntax stays nil")
    func rejectedContextWithNamedSyntaxIsNotSignificant() throws {
        let accept = try makeAccept([
            AcceptedPresentationContext(id: 5, result: .abstractSyntaxNotSupported, transferSyntax: explicitVRLE)
        ])
        let decoded = try #require(try PDUDecoder.decode(from: try accept.encode()) as? AssociateAcceptPDU)
        #expect(decoded.presentationContexts[0].transferSyntax == nil)
        #expect(decoded.presentationContexts[0].isAccepted == false)
    }
}

