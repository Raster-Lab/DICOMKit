// CLIParityRetrieveParityTests.swift
// dicom-retrieve network parity: the comparator must reduce the CLI's C-MOVE / C-GET
// verbose output to the same outcome record the SDK reference produces, and the
// scenario matrix must cover the methods/levels with the flags the parse depends on.

import XCTest
import DICOMCore
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityRetrieveParityTests: XCTestCase {

    private typealias C = CLIParityRetrieveComparator

    // MARK: parse — C-MOVE

    func testParsesCMoveSummaryCounts() {
        // dicom-retrieve prints to stderr; the runner passes combined stdout+stderr.
        let cli = """
        ── stderr ──
        Retrieving study: 1.2.3
          Progress: 0/3 completed, 0 failed, 3 remaining
          Progress: 3/3 completed, 0 failed, 0 remaining

        C-MOVE Result:
          Status: Success
          Completed: 3
          Failed: 0
          Warnings: 0
        """
        let s = C.parse(cli, method: "c-move", level: "study", success: true)
        XCTAssertEqual(s.method, "c-move")
        XCTAssertEqual(s.completed, 3)
        XCTAssertEqual(s.failed, 0)
        XCTAssertEqual(s.warning, 0)
        XCTAssertEqual(s.filesReceived, 0)
        XCTAssertTrue(s.overallOK)
    }

    // MARK: parse — C-GET

    func testParsesCGetSummaryCounts() {
        let cli = """
        ── stderr ──
        Retrieving study: 1.2.3
          Progress: 0/3 completed, 0 failed, 3 remaining
          Received instance: 1.2.3.1 (10.5 KB)
          Received instance: 1.2.3.2 (10.5 KB)
          Received instance: 1.2.3.3 (10.5 KB)

        C-GET Completed:
          Files received: 3
          Total size: 31.5 KB
          Status: Success
          Completed: 3
          Failed: 0
        """
        let s = C.parse(cli, method: "c-get", level: "study", success: true)
        XCTAssertEqual(s.method, "c-get")
        XCTAssertEqual(s.completed, 3)
        XCTAssertEqual(s.failed, 0)
        XCTAssertEqual(s.filesReceived, 3)
    }

    /// REGRESSION: the CLI prints "Status: <desc>" before the count lines, and a
    /// FAILURE DIMSEStatus.description begins with the literal "Failed:" (e.g.
    /// "Failed: Unable to process (0x0110)"). A substring search would read the status
    /// hex (→ 0) instead of the real failed-sub-operation count; the prefix-anchored
    /// parse must read the true "Failed: N" line. This is the exact false-DIFFERS case
    /// the harness must avoid on a C-GET failure-status retrieve.
    func testStatusLineDoesNotShadowFailedCount() {
        let cli = """
        ── stderr ──
          Received instance: 1.2.3.1 (10.5 KB)

        C-GET Completed:
          Files received: 1
          Total size: 10.5 KB
          Status: Failed: Unable to process (0x0110)
          Completed: 0
          Failed: 2
        """
        let s = C.parse(cli, method: "c-get", level: "study", success: false)
        XCTAssertEqual(s.failed, 2)          // the real count, NOT the status hex (0)
        XCTAssertEqual(s.completed, 0)
        XCTAssertEqual(s.filesReceived, 1)
        // The reference for the same failed C-GET reports failed:2 too → records agree,
        // so a genuinely-identical failure path is NOT a false drift.
        let ref = RetrieveSemantics(method: "c-get", level: "study", success: false,
                                    completed: 0, failed: 2, warning: 0, filesReceived: 1)
        XCTAssertTrue(C.compare(reference: ref, cli: s).match)
    }

    /// The same Status-line shadowing must not corrupt the C-MOVE Warnings/Failed parse.
    func testCMoveStatusLineDoesNotShadowCounts() {
        let cli = """
        C-MOVE Result:
          Status: Failed: Move destination unknown (0xA801)
          Completed: 4
          Failed: 1
          Warnings: 0
        """
        let s = C.parse(cli, method: "c-move", level: "study", success: false)
        XCTAssertEqual(s.completed, 4)
        XCTAssertEqual(s.failed, 1)
        XCTAssertEqual(s.warning, 0)
    }

    /// The verbose per-sub-operation "Progress:" lines (lower-case "completed"/"failed",
    /// no colon) must NOT be mistaken for the summary counts.
    func testProgressLinesAreNotParsedAsSummary() {
        let cli = """
          Progress: 7/9 completed, 2 failed, 0 remaining

        C-MOVE Result:
          Status: Warning
          Completed: 9
          Failed: 0
          Warnings: 1
        """
        let s = C.parse(cli, method: "c-move", level: "study", success: true)
        XCTAssertEqual(s.completed, 9)   // not 7 from the Progress line
        XCTAssertEqual(s.warning, 1)
    }

    // MARK: canonical / compare

    func testMatchAndDriftCMove() {
        let ref = RetrieveSemantics(method: "c-move", level: "study", success: true,
                                    completed: 3, failed: 0, warning: 0, filesReceived: 0)
        let match = C.parse("C-MOVE Result:\n  Completed: 3\n  Failed: 0\n  Warnings: 0\n",
                            method: "c-move", level: "study", success: true)
        XCTAssertTrue(C.compare(reference: ref, cli: match).match)

        let drift = C.parse("C-MOVE Result:\n  Completed: 2\n  Failed: 1\n  Warnings: 0\n",
                            method: "c-move", level: "study", success: true)
        XCTAssertFalse(C.compare(reference: ref, cli: drift).match)
    }

    func testCGetFileCountDriftIsDetected() {
        let ref = RetrieveSemantics(method: "c-get", level: "series", success: true,
                                    completed: 3, failed: 0, warning: 0, filesReceived: 3)
        // Same completed/failed but a different received-file count must be a drift.
        let cli = C.parse("C-GET Completed:\n  Files received: 2\n  Completed: 3\n  Failed: 0\n",
                          method: "c-get", level: "series", success: true)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    /// The success flag participates in the record, so a process disagreement shows.
    func testSuccessFlagIsCompared() {
        let ref = RetrieveSemantics(method: "c-get", level: "study", success: true,
                                    completed: 1, failed: 0, warning: 0, filesReceived: 1)
        let cli = C.parse("C-GET Completed:\n  Files received: 1\n  Completed: 1\n  Failed: 0\n",
                          method: "c-get", level: "study", success: false)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    // MARK: scenario matrix

    func testStudyScenariosAlwaysGeneratedAndCarryVerbose() {
        let scs = CLIParityNetworkScenarios.retrieveScenarios(scope: RetrieveScope())
        let ids = scs.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-retrieve_net_get-study"))
        XCTAssertTrue(ids.contains("dicom-retrieve_net_move-study"))
        // No series/instance rows without the scoping UIDs.
        XCTAssertFalse(ids.contains { $0.contains("series") || $0.contains("instance") })
        // No transfer syntax is requested when none was selected.
        XCTAssertFalse(scs.contains { $0.cliArgs.contains("--transfer-syntax") })
        // Every scenario must pass --verbose (else a successful retrieve prints nothing).
        for s in scs { XCTAssertTrue(s.cliArgs.contains("--verbose"), "\(s.scenarioId) must pass --verbose") }
    }

    func testSeriesAndInstanceAppearWithUIDs() {
        var scope = RetrieveScope()
        scope.studyUID = "1.2.3"; scope.seriesUID = "1.2.3.4"; scope.instanceUID = "1.2.3.4.5"
        scope.moveDest = "STORESCP"
        let ids = CLIParityNetworkScenarios.retrieveScenarios(scope: scope).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-retrieve_net_get-series"))
        XCTAssertTrue(ids.contains("dicom-retrieve_net_move-series"))
        XCTAssertTrue(ids.contains("dicom-retrieve_net_get-instance"))
        XCTAssertTrue(ids.contains("dicom-retrieve_net_move-instance"))
    }

    func testCMoveCarriesMoveDestCGetDoesNot() {
        var scope = RetrieveScope()
        scope.studyUID = "1.2.3"; scope.moveDest = "STORESCP"
        let scs = CLIParityNetworkScenarios.retrieveScenarios(scope: scope)
        let move = scs.first { $0.scenarioId == "dicom-retrieve_net_move-study" }
        let get = scs.first { $0.scenarioId == "dicom-retrieve_net_get-study" }
        XCTAssertTrue(move?.cliArgs.contains("--move-dest") ?? false)
        XCTAssertEqual(move?.studioParams["method"], "c-move")
        XCTAssertFalse(get?.cliArgs.contains("--move-dest") ?? true)
        XCTAssertEqual(get?.studioParams["method"], "c-get")
    }

    /// A selected transfer syntax is requested by the C-GET rows (by UID) but NOT by
    /// the C-MOVE rows (dicom-retrieve treats it as advisory and ignores it for move).
    func testSelectedTransferSyntaxAppliesToCGetOnly() {
        var scope = RetrieveScope()
        scope.studyUID = "1.2.3"; scope.moveDest = "STORESCP"
        scope.transferSyntax = TransferSyntax.jpeg2000Lossless.uid
        let scs = CLIParityNetworkScenarios.retrieveScenarios(scope: scope)

        let get = scs.first { $0.scenarioId == "dicom-retrieve_net_get-study" }
        XCTAssertEqual(get?.studioParams["transfer-syntax"], TransferSyntax.jpeg2000Lossless.uid)
        if let i = get?.cliArgs.firstIndex(of: "--transfer-syntax") {
            XCTAssertEqual(get?.cliArgs[i + 1], TransferSyntax.jpeg2000Lossless.uid)
            // The UID round-trips through the same parser the CLI/reference use.
            XCTAssertNotNil(TransferSyntax.parse(get!.cliArgs[i + 1]))
        } else { XCTFail("c-get study must carry --transfer-syntax when one is selected") }

        let move = scs.first { $0.scenarioId == "dicom-retrieve_net_move-study" }
        XCTAssertFalse(move?.cliArgs.contains("--transfer-syntax") ?? true)
        XCTAssertNil(move?.studioParams["transfer-syntax"])
    }

    /// The picker list is sourced from DICOMKit and covers every known transfer syntax.
    @MainActor
    func testTransferSyntaxOptionsCoverAllKnown() {
        let vm = CLIParityRunnerViewModel()
        let ids = Set(vm.transferSyntaxOptions.map { $0.id })
        XCTAssertTrue(ids.contains(""))  // the "server decides" default
        for ts in TransferSyntax.allKnown {
            XCTAssertTrue(ids.contains(ts.uid), "picker missing \(ts.displayName)")
        }
        XCTAssertEqual(vm.transferSyntaxOptions.count, TransferSyntax.allKnown.count + 1)
    }

    func testRetrieveScenariosTokeniseOutputDir() {
        let scope = { var s = RetrieveScope(); s.studyUID = "1.2.3"; return s }()
        for s in CLIParityNetworkScenarios.retrieveScenarios(scope: scope) {
            XCTAssertTrue(s.cliArgs.contains(CLIParityNetworkScenarios.outDirToken),
                          "\(s.scenarioId) must tokenise --output to OUTDIR")
        }
    }

    func testSupportedToolsIncludeRetrieve() {
        XCTAssertTrue(CLIParityNetworkScenarios.supportedToolIDs.contains("dicom-retrieve"))
    }
}
