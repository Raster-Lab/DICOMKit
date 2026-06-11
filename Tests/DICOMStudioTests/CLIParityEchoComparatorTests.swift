// CLIParityEchoComparatorTests.swift
// Validates the timing-independent semantic comparator used by the CLI Parity
// screen's NETWORK mode. For each dicom-echo flag combination, the app's console
// output and the real CLI's stdout+stderr must reduce to the SAME canonical
// record (so a correct run is a parity PASS), while genuine differences must
// still be detected.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityEchoComparatorTests: XCTestCase {

    // MARK: basic (count == 1) success — app uses ✅/ms, CLI uses ✓/seconds.

    func testBasicEchoSuccessMatchesAcrossGlyphAndUnits() {
        let app = """
        $ dicom-echo 172.17.1.200:11112 --aet DICOMSTUDIO --called-aet TEAMPACS

        Connecting to 172.17.1.200:11112 ...
          Calling AE Title: DICOMSTUDIO
          Called AE Title:  TEAMPACS
          Timeout:          30s

        ✅ C-ECHO successful
          Remote AE: TEAMPACS
          Status: Success (0x0000)
          Round-trip time: 12.3 ms
        """
        let cli = """
        ── stderr ──
        ✓ C-ECHO successful
          Remote AE: TEAMPACS
          Status: Success (0x0000)
          Round-trip time: 0.012s
        """
        let cmp = CLIParityEchoComparator.compare(appOutput: app, cliOutput: cli)
        XCTAssertTrue(cmp.match, "Basic echo should match despite glyph/unit/RTT differences")
        XCTAssertEqual(cmp.app.sent, 1)
        XCTAssertEqual(cmp.app.succeeded, 1)
        XCTAssertEqual(cmp.app.failed, 0)
        XCTAssertEqual(cmp.app.statusCodes, ["0x0000"])
        XCTAssertEqual(cmp.app.remoteAEs, ["TEAMPACS"])
        XCTAssertTrue(cmp.app.overallOK)
    }

    // MARK: --count 3 --verbose — exercises the status-code dedup fix.

    func testMultiVerboseDeduplicatesStatusCodes() {
        func block(_ glyph: String, _ rtt: String, _ i: Int) -> String {
            """
            [\(i)/3] Sending C-ECHO...
            \(glyph) C-ECHO successful
              Remote AE: TEAMPACS
              Status: Success (0x0000)
              Round-trip time: \(rtt)
            """
        }
        let app = ([block("✅", "11.1 ms", 1), block("✅", "12.2 ms", 2), block("✅", "13.3 ms", 3)]
                   .joined(separator: "\n"))
            + "\n\nSummary:\n  Sent: 3\n  Successful: 3\n  Failed: 0\n  Success rate: 100.0%\n"
        let cli = "── stderr ──\n"
            + ([block("✓", "0.011s", 1), block("✓", "0.012s", 2), block("✓", "0.013s", 3)]
               .joined(separator: "\n"))
            + "\n\nSummary:\n  Sent: 3\n  Successful: 3\n  Failed: 0\n  Success rate: 100.0%\n"
        let cmp = CLIParityEchoComparator.compare(appOutput: app, cliOutput: cli)
        XCTAssertTrue(cmp.match, "Multi-echo verbose should match")
        XCTAssertEqual(cmp.app.statusCodes, ["0x0000"], "Status codes must be de-duplicated, not tripled")
        XCTAssertEqual(cmp.app.sent, 3)
        XCTAssertEqual(cmp.app.succeeded, 3)
    }

    // MARK: --count 3 (non-verbose) — counts come from the Summary; dots ignored.

    func testMultiNonVerboseUsesSummaryCounts() {
        let app = """
        Connecting to 172.17.1.200:11112 ...
          Calling AE Title: DICOMSTUDIO
          Called AE Title:  TEAMPACS
          Timeout:          30s
          Count:            3

        ...

        Summary:
          Sent: 3
          Successful: 3
          Failed: 0
          Success rate: 100.0%
        """
        let cli = """
        ...
        ── stderr ──
        Summary:
          Sent: 3
          Successful: 3
          Failed: 0
          Success rate: 100.0%
        """
        let cmp = CLIParityEchoComparator.compare(appOutput: app, cliOutput: cli)
        XCTAssertTrue(cmp.match, "Non-verbose multi-echo should match on Summary counts")
        XCTAssertEqual(cmp.app.succeeded, 3)
        XCTAssertEqual(cmp.app.statusCodes, [], "No per-echo Status lines in non-verbose multi-echo")
        XCTAssertEqual(cmp.app.remoteAEs, [])
    }

    // MARK: --diagnose — basic connectivity, stability x/5, final result.

    func testDiagnoseAllPassMatches() {
        let app = """
        Running DICOM network diagnostics...

        Test 1: Basic C-ECHO connectivity
          Testing connection to 172.17.1.200:11112...
          Basic connectivity: PASS
            Round-trip time: 12.0 ms

        Test 2: Connection stability (5 requests)
          [1/5] RTT: 11.0 ms
          [2/5] RTT: 12.0 ms
          [3/5] RTT: 13.0 ms
          [4/5] RTT: 12.5 ms
          [5/5] RTT: 11.5 ms
          Connection stability: 5/5 successful
          RTT min/avg/max: 11.0/12.0/13.0 ms

        Test 3: Association parameters
          Implementation Class UID: 1.2.826.0.1.3680043.9.7433.1.1
          Implementation Version: DICOMKIT_001
          SOP Class: Verification (1.2.840.10008.1.1)
          Transfer Syntaxes: Explicit VR Little Endian, Implicit VR Little Endian

        Diagnostics complete.
        Result: All tests PASSED ✓
        """
        let cli = """
        ── stderr ──
        Running DICOM network diagnostics...

        Test 1: Basic C-ECHO connectivity
          Testing connection to 172.17.1.200:11112...
          ✓ Basic connectivity: PASS
            Round-trip time: 0.012s

        Test 2: Connection stability (5 requests)
          [1/5] ✓ RTT: 0.011s
          [2/5] ✓ RTT: 0.012s
          [3/5] ✓ RTT: 0.013s
          [4/5] ✓ RTT: 0.012s
          [5/5] ✓ RTT: 0.011s
          Connection stability: 5/5 successful
          RTT min/avg/max/stddev: 0.011/0.012/0.013/0.001s

        Test 3: Association parameters
          Implementation Class UID: 1.2.826.0.1.3680043.9.7433.1.1
          Implementation Version: DICOMKIT_001
          SOP Class: Verification (1.2.840.10008.1.1)
          Transfer Syntaxes: Explicit VR Little Endian, Implicit VR Little Endian

        Diagnostics complete.
        Result: All tests PASSED ✓
        """
        let cmp = CLIParityEchoComparator.compare(appOutput: app, cliOutput: cli)
        XCTAssertTrue(cmp.match, "Diagnose all-pass should match")
        XCTAssertEqual(cmp.app.mode, "diagnose")
        XCTAssertEqual(cmp.app.diagBasicOK, true)
        XCTAssertEqual(cmp.app.diagStability, 5)
        XCTAssertEqual(cmp.app.diagResult, "PASSED")
    }

    // MARK: both sides fail identically (server unreachable) — parity on failure.

    func testBothFailedIdenticallyMatchesButNotOK() {
        let app = """
        Connecting to 172.17.1.200:11112 ...
          Calling AE Title: DICOMSTUDIO
          Called AE Title:  TEAMPACS
          Timeout:          30s

        ❌ C-ECHO failed
          Error: Connection failed: Connection refused
          💡 Hint: Check host (172.17.1.200), port (11112), and that the DICOM server is running.
        """
        let cli = """
        ── stderr ──
        ✗ C-ECHO error: connectionFailed("Connection refused")
        """
        let cmp = CLIParityEchoComparator.compare(appOutput: app, cliOutput: cli)
        XCTAssertTrue(cmp.match, "Both-failed-identically should match semantically")
        XCTAssertFalse(cmp.app.overallOK, "A failed echo is not overallOK")
        XCTAssertFalse(cmp.cli.overallOK)
        XCTAssertEqual(cmp.app.failed, 1)
        XCTAssertEqual(cmp.app.statusCodes, [])
    }

    // MARK: a genuine divergence (app succeeds, CLI fails) must be detected.

    func testGenuineDivergenceIsDetected() {
        let app = """
        ✅ C-ECHO successful
          Remote AE: TEAMPACS
          Status: Success (0x0000)
          Round-trip time: 12.3 ms
        """
        let cli = """
        ── stderr ──
        ✗ C-ECHO error: connectionFailed("Connection refused")
        """
        let cmp = CLIParityEchoComparator.compare(appOutput: app, cliOutput: cli)
        XCTAssertFalse(cmp.match, "App-success vs CLI-failure must NOT be reported as parity")
    }
}
