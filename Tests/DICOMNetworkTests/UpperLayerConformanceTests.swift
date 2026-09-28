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

// MARK: - 2. A-ABORT source and reason (PS3.8 Tables 9-9, 9-26)

@Suite("A-ABORT service-user reason")
struct AbortReasonEncodingTests {

    @Test("A service-user abort is sent with reason 00H whatever reason was given")
    func serviceUserAbortEncodesReasonZero() throws {
        let abort = AbortPDU(source: .serviceUser, reason: AbortReason.unexpectedPDU)
        let encoded = try abort.encode()
        #expect(encoded.count == 10)
        #expect(encoded[8] == 0)   // Source: service-user
        #expect(encoded[9] == 0)   // Reason: not significant, sent as 00H
    }

    @Test("A service-provider abort keeps its reason")
    func serviceProviderAbortKeepsReason() throws {
        let encoded = try AbortPDU(source: .serviceProvider, reason: .unexpectedPDU).encode()
        #expect(encoded[8] == 2)
        #expect(encoded[9] == AbortReason.unexpectedPDU.rawValue)
    }
}

#if canImport(Network)

// MARK: - 2/4. Association behaviour on a scripted transport

/// A deterministic transport: `enqueue` bytes the peer "sends", `sentData`
/// records what the association sent. A receive that cannot be served is held
/// until bytes arrive or the transport is cancelled.
private final class ScriptedTransport: DICOMConnectionTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var stateHandler: (@Sendable (DICOMConnectionTransportState) -> Void)?
    private var inbound = Data()
    private var pendingReceive: (length: Int, completion: @Sendable (Data?, Bool, String?) -> Void)?
    private var closedByPeer = false
    private(set) var sends: [Data] = []

    var sentData: [Data] {
        lock.lock(); defer { lock.unlock() }
        return sends
    }

    func sentPDUs() throws -> [any PDU] {
        try sentData.map { try PDUDecoder.decode(from: $0) }
    }

    func enqueue(_ pdu: any PDU) throws {
        enqueue(try pdu.encode())
    }

    func enqueue(_ data: Data) {
        lock.lock()
        inbound.append(data)
        lock.unlock()
        servePending()
    }

    /// The peer closed its side: pending and future receives complete as closed.
    func closeFromPeer() {
        lock.lock()
        closedByPeer = true
        lock.unlock()
        servePending()
    }

    private func servePending() {
        lock.lock()
        guard let pending = pendingReceive else { lock.unlock(); return }
        if inbound.count >= pending.length {
            let chunk = inbound.prefix(pending.length)
            inbound.removeFirst(pending.length)
            pendingReceive = nil
            lock.unlock()
            pending.completion(Data(chunk), false, nil)
        } else if closedByPeer {
            pendingReceive = nil
            lock.unlock()
            pending.completion(nil, true, nil)
        } else {
            lock.unlock()
        }
    }

    // DICOMConnectionTransport

    func setStateUpdateHandler(_ handler: (@Sendable (DICOMConnectionTransportState) -> Void)?) {
        lock.lock(); stateHandler = handler; lock.unlock()
    }

    func start() {
        lock.lock(); let handler = stateHandler; lock.unlock()
        handler?(.ready)
    }

    func send(content: Data, completion: @escaping @Sendable (String?) -> Void) {
        lock.lock(); sends.append(content); lock.unlock()
        completion(nil)
    }

    func receive(minimumIncompleteLength: Int, maximumLength: Int,
                 completion: @escaping @Sendable (Data?, Bool, String?) -> Void) {
        lock.lock()
        pendingReceive = (maximumLength, completion)
        lock.unlock()
        servePending()
    }

    func cancel() {
        lock.lock()
        let handler = stateHandler
        let pending = pendingReceive
        pendingReceive = nil
        lock.unlock()
        pending?.completion(nil, true, "cancelled")
        handler?(.cancelled)
    }

    func forceCancel() { cancel() }
}

@Suite("Association Upper Layer behaviour", .serialized)
struct AssociationUpperLayerTests {

    private func makeAssociation(transport: ScriptedTransport, artim: TimeInterval? = 5) throws -> Association {
        let configuration = AssociationConfiguration(
            callingAETitle: scuTitle, calledAETitle: scpTitle,
            host: "scripted.test", port: 104, implementationClassUID: "1.2.826.0.1.3680043.10.543.99",
            timeout: 5, artimTimeout: artim, tlsConfiguration: nil)
        return Association(configuration: configuration) { configuration in
            DICOMConnection(host: configuration.host, port: configuration.port,
                            maxPDUSize: configuration.maxPDUSize, timeout: configuration.timeout,
                            tlsConfiguration: nil, transport: transport)
        }
    }

    private func acceptPDU() throws -> AssociateAcceptPDU {
        AssociateAcceptPDU(
            calledAETitle: scpTitle, callingAETitle: scuTitle,
            presentationContexts: [AcceptedPresentationContext(id: 1, result: .acceptance, transferSyntax: explicitVRLE)],
            maxPDUSize: 16384, implementationClassUID: "1.2.3")
    }

    private func establish(_ association: Association, _ transport: ScriptedTransport) async throws {
        try transport.enqueue(try acceptPDU())
        let context = try PresentationContext(id: 1, abstractSyntax: verificationSOPClass, transferSyntaxes: [explicitVRLE])
        _ = try await association.request(presentationContexts: [context])
        #expect(association.state == .established)
    }

    @Test("Sta6 + A-RELEASE-RQ: the association answers A-RELEASE-RP (AR-2, AR-4), closes and returns to Sta1")
    func receiveAnswersReleaseRequest() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport)
        try await establish(association, transport)

        try transport.enqueue(ReleaseRequestPDU())
        let closed = await #expect(throws: DICOMNetworkError.self) {
            _ = try await association.receive()
        }
        #expect(closed?.isConnectionClosed == true)
        let sent = try transport.sentPDUs()
        #expect(sent.count == 2)
        #expect(sent.last is ReleaseResponsePDU)
        #expect(association.state == .idle)
    }

    @Test("Release collision: after A-RELEASE-RP is sent the requestor waits for the peer's A-RELEASE-RP (AR-8, AR-9, AR-3)")
    func releaseCollisionWaitsForPeerReleaseResponse() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport)
        try await establish(association, transport)

        // Peer's A-RELEASE-RQ crosses ours; its A-RELEASE-RP follows only after ours
        try transport.enqueue(ReleaseRequestPDU())
        let release = Task { try await association.release() }
        try await Task.sleep(for: .milliseconds(100))
        var sent = try transport.sentPDUs()
        #expect(sent.count == 3)
        #expect(sent[1] is ReleaseRequestPDU)
        #expect(sent[2] is ReleaseResponsePDU)
        #expect(association.state == .awaitingRemoteReleaseResponse)  // Sta11

        try transport.enqueue(ReleaseResponsePDU())
        try await release.value
        sent = try transport.sentPDUs()
        #expect(sent.count == 3)
        #expect(association.state == .idle)
    }

    @Test("Release collision without the peer's A-RELEASE-RP times out: AA-1 abort with service-user source, reason 0")
    func releaseCollisionTimeoutAborts() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport, artim: 0.2)
        try await establish(association, transport)

        try transport.enqueue(ReleaseRequestPDU())
        let expired = await #expect(throws: DICOMNetworkError.self) {
            try await association.release()
        }
        #expect(expired?.isARTIMExpired == true)
        let sent = try transport.sentPDUs()
        let abort = try #require(sent.last as? AbortPDU)
        #expect(abort.source == .serviceUser)
        #expect(abort.reason == 0)
        #expect(association.state == .idle)
    }

    @Test("P-DATA-TF during the release wait is discarded (AR-6) and A-RELEASE-RP completes the release")
    func dataDuringReleaseIsDiscarded() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport)
        try await establish(association, transport)

        let pdv = PresentationDataValue(presentationContextID: 1, isCommand: true, isLastFragment: true, data: Data([0, 0]))
        try transport.enqueue(DataTransferPDU(pdv: pdv))
        try transport.enqueue(ReleaseResponsePDU())
        try await association.release()
        #expect(association.state == .idle)
        let sent = try transport.sentPDUs()
        #expect(sent.count == 2)
        #expect(sent.last is ReleaseRequestPDU)
    }

    @Test("ARTIM expiry while awaiting A-ASSOCIATE-AC sends an AA-1 abort: service-user source, reason 0")
    func artimExpiryDuringRequestSendsServiceUserAbort() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport, artim: 0.2)
        let context = try PresentationContext(id: 1, abstractSyntax: verificationSOPClass, transferSyntaxes: [explicitVRLE])
        let expired = await #expect(throws: DICOMNetworkError.self) {
            _ = try await association.request(presentationContexts: [context])
        }
        #expect(expired?.isARTIMExpired == true)
        let sent = try transport.sentPDUs()
        #expect(sent.count == 2)
        #expect(sent[0] is AssociateRequestPDU)
        let abort = try #require(sent[1] as? AbortPDU)
        #expect(abort.source == .serviceUser)
        #expect(abort.reason == 0)
        #expect(try abort.encode()[9] == 0)
        #expect(association.state == .idle)
    }

    @Test("abort() sends a service-user abort; a protocol reason is sent as service-provider (AA-8)")
    func abortSourceFollowsReason() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport)
        try await establish(association, transport)
        try await association.abort()
        var abort = try #require(try transport.sentPDUs().last as? AbortPDU)
        #expect(abort.source == .serviceUser)
        #expect(abort.reason == 0)

        let transport2 = ScriptedTransport()
        let association2 = try makeAssociation(transport: transport2)
        try await establish(association2, transport2)
        try await association2.abort(reason: .unexpectedPDU)
        abort = try #require(try transport2.sentPDUs().last as? AbortPDU)
        #expect(abort.source == .serviceProvider)
        #expect(abort.reason == AbortReason.unexpectedPDU.rawValue)
    }

    @Test("An unexpected PDU in Sta6 is answered with a service-provider abort, reason unexpected PDU")
    func unexpectedPDUAbortsAsServiceProvider() async throws {
        let transport = ScriptedTransport()
        let association = try makeAssociation(transport: transport)
        try await establish(association, transport)
        try transport.enqueue(try acceptPDU())
        await #expect(throws: DICOMNetworkError.self) {
            _ = try await association.receive()
        }
        let abort = try #require(try transport.sentPDUs().last as? AbortPDU)
        #expect(abort.source == .serviceProvider)
        #expect(abort.reason == AbortReason.unexpectedPDU.rawValue)
    }
}

#endif
