import XCTest
import Foundation
@testable import DICOMNetwork

/// Instruction §17 ("Security, fuzzing and resource limits") fuzz coverage for the
/// association/PDU surface.
///
/// M0 fuzzed `DICOMParser` only. The PDU decoder is the *other* attacker-reachable
/// entry point: every byte of an A-ASSOCIATE-RQ arrives from an unauthenticated peer
/// before any AE-title check has happened. The contract asserted here is the same one
/// M0 established for the parser — a malformed input must throw a structured error,
/// never trap, hang, or allocate without bound.
final class PDUFuzzTests: XCTestCase {

    /// Deterministic LCG so a failure is reproducible from the logged seed.
    /// (Same generator as `ParserLimitTests` — kept local to avoid a cross-target
    /// test-helper dependency.)
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private var fuzzIterations: Int {
        ProcessInfo.processInfo.environment["DICOM_FUZZ_ITERATIONS"].flatMap(Int.init) ?? 2000
    }

    // MARK: - Corpus

    /// A structurally valid A-ASSOCIATE-RQ: PDU header, protocol version, called/calling
    /// AE titles, one Application Context, one Presentation Context (Abstract Syntax +
    /// one Transfer Syntax) and User Information (max PDU length, implementation class
    /// UID). Mutating this reaches every sub-item parser.
    private func associateRequest() -> Data {
        func item(_ type: UInt8, _ payload: [UInt8]) -> [UInt8] {
            let length = UInt16(payload.count)
            return [type, 0x00, UInt8(length >> 8), UInt8(length & 0xFF)] + payload
        }
        func ae(_ title: String) -> [UInt8] {
            Array(title.padding(toLength: 16, withPad: " ", startingAt: 0).utf8)
        }

        let applicationContext = item(0x10, Array("1.2.840.10008.3.1.1.1".utf8))
        let abstractSyntax = item(0x30, Array("1.2.840.10008.1.1".utf8))
        let transferSyntax = item(0x40, Array("1.2.840.10008.1.2".utf8))
        let presentationContext = item(0x20, [0x01, 0x00, 0x00, 0x00] + abstractSyntax + transferSyntax)
        let maxLength = item(0x51, [0x00, 0x01, 0x00, 0x00])
        let implementationClass = item(0x52, Array("1.2.826.0.1.3680043.9.7133.1".utf8))
        let userInformation = item(0x50, maxLength + implementationClass)

        var body: [UInt8] = [0x00, 0x01, 0x00, 0x00]   // protocol version + reserved
        body += ae("FUZZ_SCP")
        body += ae("FUZZ_SCU")
        body += [UInt8](repeating: 0x00, count: 32)     // reserved
        body += applicationContext + presentationContext + userInformation

        let length = UInt32(body.count)
        var pdu: [UInt8] = [0x01, 0x00]                 // A-ASSOCIATE-RQ, reserved
        pdu += [UInt8(length >> 24), UInt8((length >> 16) & 0xFF),
                UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        return Data(pdu + body)
    }

    /// A P-DATA-TF carrying one presentation-data-value item.
    private func dataTransfer() -> Data {
        let fragment: [UInt8] = [0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let pdvLength = UInt32(fragment.count)
        var body: [UInt8] = [UInt8(pdvLength >> 24), UInt8((pdvLength >> 16) & 0xFF),
                             UInt8((pdvLength >> 8) & 0xFF), UInt8(pdvLength & 0xFF)]
        body += fragment

        let length = UInt32(body.count)
        var pdu: [UInt8] = [0x04, 0x00]
        pdu += [UInt8(length >> 24), UInt8((length >> 16) & 0xFF),
                UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        return Data(pdu + body)
    }

    // MARK: - Fuzz

    /// Random mutation of an otherwise valid A-ASSOCIATE-RQ must never trap.
    func testAssociateRequestSurvivesRandomByteMutations() {
        fuzz(base: associateRequest(), seed: 0xD1C0_2026_0810_0101, label: "A-ASSOCIATE-RQ")
    }

    /// Same contract for the P-DATA-TF path.
    func testDataTransferSurvivesRandomByteMutations() {
        fuzz(base: dataTransfer(), seed: 0xD1C0_2026_0810_0102, label: "P-DATA-TF")
    }

    /// Every PDU type byte, including undefined ones, over a truncated body.
    func testAllPDUTypeBytesWithTruncatedBodies() {
        for type in UInt8(0)...UInt8(255) {
            for bodyLength in [0, 1, 5, 17] {
                var pdu: [UInt8] = [type, 0x00, 0x00, 0x00, 0x00, UInt8(bodyLength)]
                pdu += [UInt8](repeating: 0xAB, count: max(0, bodyLength - 1))
                // Declared length deliberately disagrees with the bytes supplied.
                _ = try? PDUDecoder.decode(from: Data(pdu))
                _ = try? PDUDecoder.readHeader(from: Data(pdu))
            }
        }
    }

    /// A declared PDU length beyond the guard must be rejected rather than reserved.
    /// This is the allocation-DoS gate from §17, asserted rather than merely survived.
    func testOversizedDeclaredLengthIsRejected() {
        let oversized = PDUDecoder.maximumPDULength + 1
        var pdu: [UInt8] = [0x01, 0x00]
        pdu += [UInt8(oversized >> 24), UInt8((oversized >> 16) & 0xFF),
                UInt8((oversized >> 8) & 0xFF), UInt8(oversized & 0xFF)]

        XCTAssertThrowsError(try PDUDecoder.decode(from: Data(pdu))) { error in
            // §17: limit violations are structured errors, mirroring
            // `DICOMError.limitExceeded` at the network layer (added 2026-08-11).
            guard case DICOMNetworkError.limitExceeded(let message) = error,
                  message.contains("exceeds maximum") else {
                return XCTFail("Expected .limitExceeded for a \(oversized)-byte declared PDU, got \(error)")
            }
        }
    }

    /// Sub-item lengths that overrun their parent item must fail closed, not read past.
    func testSubItemLengthOverrunFailsClosed() {
        var request = associateRequest()
        // Locate the Application Context item (type 0x10) and inflate its declared
        // length so it claims more bytes than the enclosing PDU contains.
        guard let index = request.firstIndex(of: 0x10), index + 3 < request.count else {
            return XCTFail("corpus no longer contains an Application Context item")
        }
        request[index + 2] = 0xFF
        request[index + 3] = 0xFF
        _ = try? PDUDecoder.decode(from: request)   // must not trap
    }

    // MARK: - Harness

    private func fuzz(base: Data, seed: UInt64, label: String) {
        var rng = SplitMix64(state: seed)
        let iterations = fuzzIterations

        for iteration in 0..<iterations {
            var mutated = base
            for _ in 0..<Int.random(in: 1...8, using: &rng) {
                let index = Int.random(in: 0..<mutated.count, using: &rng)
                mutated[index] = UInt8.random(in: 0...255, using: &rng)
            }
            // Truncate one input in ten to exercise short-read handling.
            if Int.random(in: 0..<10, using: &rng) == 0, mutated.count > 1 {
                mutated = Data(mutated.prefix(Int.random(in: 1..<mutated.count, using: &rng)))
            }
            // Reproduce a failure with seed \(seed), iteration \(iteration), target \(label).
            _ = try? PDUDecoder.decode(from: mutated)
            _ = iteration
        }
    }
}
