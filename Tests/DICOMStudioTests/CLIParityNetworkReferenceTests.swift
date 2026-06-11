// CLIParityNetworkReferenceTests.swift
// The network parity reference builds its EchoSemantics record DIRECTLY from the
// DICOMKit package API results, while the CLI side is parsed from text. These
// tests lock the alignment: for every flag combination, the reference record must
// equal what parse() extracts from the corresponding dicom-echo CLI output.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityNetworkReferenceTests: XCTestCase {

    private typealias Ref = CLIParityNetworkReference
    private func ok(_ ae: String = "TEAMPACS") -> Ref.EchoCallOutcome {
        .init(responded: true, success: true, statusHex: "0x0000", remoteAE: ae)
    }
    private func connErr() -> Ref.EchoCallOutcome {
        .init(responded: false, success: false, statusHex: "", remoteAE: "")
    }

    private func assertMatch(_ reference: EchoSemantics, _ cliText: String,
                             _ msg: String, file: StaticString = #filePath, line: UInt = #line) {
        let cli = CLIParityEchoComparator.parse(cliText)
        let cmp = CLIParityEchoComparator.compare(reference: reference, cli: cli)
        XCTAssertTrue(cmp.match, "\(msg)\n  reference: \(CLIParityEchoComparator.canonical(reference))\n  cli:       \(CLIParityEchoComparator.canonical(cli))",
                      file: file, line: line)
    }

    // count == 1, success: CLI prints the full per-echo block.
    func testSingleSuccessMatchesCLI() {
        let ref = Ref.echoRecord([ok()], verbose: false)
        assertMatch(ref, """
        ── stderr ──
        ✓ C-ECHO successful
          Remote AE: TEAMPACS
          Status: Success (0x0000)
          Round-trip time: 0.012s
        """, "single echo")
        XCTAssertEqual(ref.statusCodes, ["0x0000"])
        XCTAssertEqual(ref.remoteAEs, ["TEAMPACS"])
    }

    // count > 1, non-verbose: CLI prints only dots + Summary (no per-echo Status/AE).
    func testMultiNonVerboseOmitsPerEchoDetail() {
        let ref = Ref.echoRecord([ok(), ok(), ok()], verbose: false)
        XCTAssertEqual(ref.statusCodes, [], "non-verbose multi-echo must not carry per-echo status")
        XCTAssertEqual(ref.remoteAEs, [])
        assertMatch(ref, """
        ...
        ── stderr ──
        Summary:
          Sent: 3
          Successful: 3
          Failed: 0
          Success rate: 100.0%
        """, "multi non-verbose")
    }

    // count > 1, verbose: CLI prints a per-echo block each time.
    func testMultiVerboseCarriesDedupedDetail() {
        let ref = Ref.echoRecord([ok(), ok(), ok()], verbose: true)
        XCTAssertEqual(ref.statusCodes, ["0x0000"], "deduped across echoes")
        XCTAssertEqual(ref.remoteAEs, ["TEAMPACS"])
        func block(_ i: Int) -> String { "[\(i)/3] Sending C-ECHO...\n✓ C-ECHO successful\n  Remote AE: TEAMPACS\n  Status: Success (0x0000)\n  Round-trip time: 0.01\(i)s" }
        assertMatch(ref, "── stderr ──\n" + [block(1),block(2),block(3)].joined(separator: "\n")
                    + "\n\nSummary:\n  Sent: 3\n  Successful: 3\n  Failed: 0\n  Success rate: 100.0%\n",
                    "multi verbose")
    }

    // count == 1, connection error: CLI's catch branch prints no Status line.
    func testSingleConnectionErrorMatchesCLI() {
        let ref = Ref.echoRecord([connErr()], verbose: false)
        XCTAssertEqual(ref.sent, 1); XCTAssertEqual(ref.failed, 1); XCTAssertEqual(ref.statusCodes, [])
        XCTAssertFalse(ref.overallOK)
        assertMatch(ref, """
        ── stderr ──
        ✗ C-ECHO error: connectionFailed("Connection refused")
        """, "single connection error")
    }

    // diagnose, all pass.
    func testDiagnoseAllPassMatchesCLI() {
        let ref = Ref.diagnoseRecord(test1Responded: true, test1Success: true, stabilitySuccesses: 5)
        XCTAssertEqual(ref.diagResult, "PASSED")
        XCTAssertTrue(ref.overallOK)
        assertMatch(ref, """
        ── stderr ──
        Running DICOM network diagnostics...
        Test 1: Basic C-ECHO connectivity
          ✓ Basic connectivity: PASS
            Round-trip time: 0.012s
        Test 2: Connection stability (5 requests)
          Connection stability: 5/5 successful
        Diagnostics complete.
        Result: All tests PASSED ✓
        """, "diagnose all-pass")
    }

    // diagnose, basic connectivity threw → CLI exits early (no stability/result).
    func testDiagnoseEarlyExitMatchesCLI() {
        let ref = Ref.diagnoseRecord(test1Responded: false, test1Success: false, stabilitySuccesses: nil)
        XCTAssertEqual(ref.diagBasicOK, false)
        XCTAssertNil(ref.diagStability)
        XCTAssertNil(ref.diagResult)
        XCTAssertFalse(ref.overallOK)
        assertMatch(ref, """
        ── stderr ──
        Running DICOM network diagnostics...
        Test 1: Basic C-ECHO connectivity
          Testing connection to 1.2.3.4:11112...
          ✗ Basic connectivity: ERROR
            Error: connectionFailed("Connection refused")
        """, "diagnose early-exit")
    }

    // diagnose partial.
    func testDiagnosePartialMatchesCLI() {
        let ref = Ref.diagnoseRecord(test1Responded: true, test1Success: true, stabilitySuccesses: 3)
        XCTAssertEqual(ref.diagResult, "PARTIAL")
        assertMatch(ref, """
        ── stderr ──
        Running DICOM network diagnostics...
          Basic connectivity: PASS
          Connection stability: 3/5 successful
        Result: Partial success (some tests failed) ⚠
        """, "diagnose partial")
    }
}
