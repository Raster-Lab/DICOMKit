// CLIParityQRParityTests.swift
// dicom-qr network parity: the comparator must reduce the integrated tool's
// `--review` C-FIND stdout (and the `--interactive` retrieve summary) to the same
// matched-study / retrieve record the SDK reference produces, and the scenario matrix
// must drive both the read-only review sweep and the interactive select-all retrieve.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityQRParityTests: XCTestCase {

    private typealias C = CLIParityQRComparator

    // MARK: parse

    func testParsesFoundCountAndStudyUIDs() {
        let cli = """
        Found 2 studies

        Studies:
        ─────────────────────────────────────────────────────────────────
        [1] DOE^JOHN (ID: 12345)
            Study: CHEST CT
            Date: 20240101  Modality: CT
            UID: 1.2.840.1
            Accession: ACC1
        [2] DOE^JANE (ID: 67890)
            Study: BRAIN MR
            Date: 20240102  Modality: MR
            UID: 1.2.840.2
        ─────────────────────────────────────────────────────────────────
        """
        let s = C.parse(cli, success: true)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.studyUIDs, ["1.2.840.1", "1.2.840.2"])
        XCTAssertTrue(s.overallOK)
    }

    func testParsesNoStudiesFoundAsZero() {
        let s = C.parse("No studies found matching the query criteria.\n", success: true)
        XCTAssertEqual(s.count, 0)
        XCTAssertTrue(s.studyUIDs.isEmpty)
        XCTAssertTrue(s.overallOK)   // a successful empty query is still a success
    }

    /// Only the "    UID:" study lines are collected — the "Accession:" / "Date:" /
    /// "Study:" display lines must not leak into the UID set.
    func testIgnoresNonUIDDisplayLines() {
        let cli = """
        Found 1 studies
        [1] X (ID: 1)
            Study: S
            Accession: A
            UID: 9.9.9
        """
        let s = C.parse(cli, success: true)
        XCTAssertEqual(s.studyUIDs, ["9.9.9"])
    }

    // MARK: canonical / compare (order-independent)

    func testOrderIndependentMatch() {
        let ref = C.record(success: true, count: 2, uids: ["1.2.840.2", "1.2.840.1"])
        let cli = C.record(success: true, count: 2, uids: ["1.2.840.1", "1.2.840.2"])
        XCTAssertTrue(C.compare(reference: ref, cli: cli).match)
    }

    func testCountMismatchIsDrift() {
        let ref = C.record(success: true, count: 3, uids: ["a", "b", "c"])
        let cli = C.record(success: true, count: 2, uids: ["a", "b"])
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testDifferentStudySetIsDrift() {
        let ref = C.record(success: true, count: 2, uids: ["a", "b"])
        let cli = C.record(success: true, count: 2, uids: ["a", "c"])
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    // MARK: parse — interactive retrieve summary

    /// The interactive run also prints a "Retrieval Summary" block (Total / Success /
    /// Failed) that must be parsed into the record's `retrieval`, while the per-study
    /// "✅ Success" / "[i/N] Retrieving:" lines must NOT leak into the count or UID set.
    func testParsesInteractiveRetrievalSummary() {
        let cli = """
        Found 2 studies

        Studies:
        [1] DOE^JOHN (ID: 1)
            UID: 1.2.840.1
        [2] DOE^JANE (ID: 2)
            UID: 1.2.840.2

        Retrieving 2 studies...

        [1/2] Retrieving: 1.2.840.1
          ✅ Success

        [2/2] Retrieving: 1.2.840.2
          ❌ Failed: timed out

        Retrieval Summary:
          Total: 2
          Success: 1
          Failed: 1
        """
        let s = C.parse(cli, success: true)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.studyUIDs, ["1.2.840.1", "1.2.840.2"])
        XCTAssertEqual(s.retrieval, QRRetrieval(total: 2, success: 1, failed: 1))
    }

    /// A read-only review run has no Retrieval Summary, so `retrieval` stays nil.
    func testReviewParseHasNoRetrieval() {
        let s = C.parse("Found 1 studies\n    UID: 9.9.9\n", success: true)
        XCTAssertNil(s.retrieval)
    }

    /// canonical() and compare() must include the retrieval outcome: a matching set but a
    /// differing retrieve tally is a drift, not a false pass.
    func testRetrievalTallyMismatchIsDrift() {
        let ref = C.record(success: true, count: 1, uids: ["a"], retrieval: QRRetrieval(total: 1, success: 1, failed: 0))
        let cli = C.record(success: true, count: 1, uids: ["a"], retrieval: QRRetrieval(total: 1, success: 0, failed: 1))
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testRetrievalTallyMatch() {
        let ref = C.record(success: true, count: 2, uids: ["b", "a"], retrieval: QRRetrieval(total: 2, success: 2, failed: 0))
        let cli = C.record(success: true, count: 2, uids: ["a", "b"], retrieval: QRRetrieval(total: 2, success: 2, failed: 0))
        XCTAssertTrue(C.compare(reference: ref, cli: cli).match)
    }

    // MARK: scenario matrix

    /// With no filters, the matrix is the review-all sweep plus the two interactive
    /// (select-all) retrieve rows — the interactive rows are always generated (the
    /// runner skips them when no query key bounds the match set).
    func testBaseScenariosAlwaysGenerated() {
        let scs = CLIParityNetworkScenarios.qrScenarios(filters: QueryFilters())
        let ids = scs.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-qr_net_review-all"))
        XCTAssertTrue(ids.contains("dicom-qr_net_interactive-cget"))
        XCTAssertTrue(ids.contains("dicom-qr_net_interactive-cmove"))
        XCTAssertEqual(ids.count, 3)   // no per-filter rows without filter values
    }

    func testPerFilterAndCombinedScenarios() {
        var f = QueryFilters()
        f.patientName = "DOE*"; f.modality = "CT"
        let scs = CLIParityNetworkScenarios.qrScenarios(filters: f)
        let ids = scs.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-qr_net_review-patient-name"))
        XCTAssertTrue(ids.contains("dicom-qr_net_review-modality"))
        XCTAssertTrue(ids.contains("dicom-qr_net_review-combined")) // ≥2 filters → combined
    }

    /// Every REVIEW scenario runs the explicit `query` subcommand in `--review` mode with
    /// `--method c-get` so the tool never demands a `--move-dest` it doesn't use.
    func testReviewScenariosAreReadOnlyAndCGet() {
        var f = QueryFilters(); f.patientID = "12345"
        let review = CLIParityNetworkScenarios.qrScenarios(filters: f)
            .filter { $0.studioParams["qr-mode"] == "review" }
        XCTAssertFalse(review.isEmpty)
        for s in review {
            XCTAssertEqual(s.cliArgs.first, "query")
            XCTAssertTrue(s.cliArgs.contains("--review"), "\(s.scenarioId) must be --review")
            XCTAssertFalse(s.cliArgs.contains("--auto"))
            XCTAssertFalse(s.cliArgs.contains("--interactive"))
            // c-get avoids the C-MOVE move-dest validation in review mode.
            if let i = s.cliArgs.firstIndex(of: "--method") { XCTAssertEqual(s.cliArgs[i + 1], "c-get") }
            else { XCTFail("\(s.scenarioId) must pin --method c-get") }
            XCTAssertFalse(s.cliArgs.contains("--move-dest"))
        }
    }

    /// The interactive rows run `query … --interactive`, auto-answer "all" (carried in
    /// studioParams["stdin"]), and the C-MOVE row carries the supplied Move Destination AE.
    func testInteractiveScenariosDriveRetrieve() {
        var f = QueryFilters(); f.patientName = "DOE*"
        let scs = CLIParityNetworkScenarios.qrScenarios(filters: f, moveDest: "MY_SCP")

        let get = scs.first { $0.scenarioId == "dicom-qr_net_interactive-cget" }!
        XCTAssertEqual(get.cliArgs.first, "query")
        XCTAssertTrue(get.cliArgs.contains("--interactive"))
        XCTAssertFalse(get.cliArgs.contains("--review"))
        XCTAssertEqual(get.studioParams["qr-mode"], "interactive-get")
        XCTAssertEqual(get.studioParams["stdin"], "all")
        if let i = get.cliArgs.firstIndex(of: "--method") { XCTAssertEqual(get.cliArgs[i + 1], "c-get") }
        XCTAssertFalse(get.cliArgs.contains("--move-dest"))
        // The C-GET row carries the bounding filter so its match set is scoped.
        XCTAssertTrue(get.cliArgs.contains("DOE*"))

        let move = scs.first { $0.scenarioId == "dicom-qr_net_interactive-cmove" }!
        XCTAssertTrue(move.cliArgs.contains("--interactive"))
        XCTAssertEqual(move.studioParams["qr-mode"], "interactive-move")
        XCTAssertEqual(move.studioParams["stdin"], "all")
        if let i = move.cliArgs.firstIndex(of: "--method") { XCTAssertEqual(move.cliArgs[i + 1], "c-move") }
        if let i = move.cliArgs.firstIndex(of: "--move-dest") { XCTAssertEqual(move.cliArgs[i + 1], "MY_SCP") }
        else { XCTFail("interactive c-move must carry --move-dest") }
        XCTAssertEqual(move.studioParams["move-dest"], "MY_SCP")
    }

    func testSupportedToolsIncludeQR() {
        XCTAssertTrue(CLIParityNetworkScenarios.supportedToolIDs.contains("dicom-qr"))
    }
}
