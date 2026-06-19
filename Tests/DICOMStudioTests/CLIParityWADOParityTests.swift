// CLIParityWADOParityTests.swift
// dicom-wado (DICOMweb) network parity: the comparator must reduce each subcommand's
// CLI output (QIDO-RS query JSON, WADO-RS retrieve, STOW-RS store summary, UPS-RS
// search/lifecycle) to the same semantic record the SDK reference produces, and the
// scenario matrix must drive the single dicom-wado binary's four subcommands.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityWADOParityTests: XCTestCase {

    private typealias C = CLIParityWADOComparator

    // MARK: QIDO-RS query — parse / canonical / compare

    func testParseQueryReducesJSONToSortedResultSet() {
        let json = """
        [
          {"StudyInstanceUID": "1.2.3", "PatientName": "DOE^JOHN", "NumberOfStudyRelatedSeries": 2},
          {"StudyInstanceUID": "1.2.4", "PatientName": "DOE^JANE"}
        ]
        """
        let s = C.parseQuery(json, level: "study", success: true)
        XCTAssertEqual(s.count, 2)
        XCTAssertTrue(s.overallOK)
        // Each result is canonicalised to a sorted "key=value;…" string.
        XCTAssertEqual(s.results, [
            "PatientName=DOE^JANE;StudyInstanceUID=1.2.4",
            "NumberOfStudyRelatedSeries=2;PatientName=DOE^JOHN;StudyInstanceUID=1.2.3",
        ].sorted())
    }

    /// The matched set is order-independent: the same objects in a different server
    /// order must still compare equal.
    func testQueryOrderIndependentMatch() {
        let a = C.querySemantics(level: "study", success: true, objects: [
            ["StudyInstanceUID": "1.2.4"], ["StudyInstanceUID": "1.2.3"],
        ])
        let b = C.querySemantics(level: "study", success: true, objects: [
            ["StudyInstanceUID": "1.2.3"], ["StudyInstanceUID": "1.2.4"],
        ])
        XCTAssertTrue(C.compareQuery(reference: a, cli: b).match)
    }

    func testQueryCountMismatchIsDrift() {
        let ref = C.querySemantics(level: "study", success: true, objects: [["StudyInstanceUID": "1.2.3"], ["StudyInstanceUID": "1.2.4"]])
        let cli = C.querySemantics(level: "study", success: true, objects: [["StudyInstanceUID": "1.2.3"]])
        XCTAssertFalse(C.compareQuery(reference: ref, cli: cli).match)
    }

    // MARK: QIDO-RS non-JSON format counts (csv / table)

    func testCountCSVIsRowsMinusHeader() {
        let csv = """
        StudyInstanceUID,PatientName,PatientID,StudyDate,StudyDescription,ModalitiesInStudy,NumberOfSeries
        1.2.3,DOE^JOHN,P1,20240101,CHEST,CT,2
        1.2.4,DOE^JANE,P2,20240102,BRAIN,MR,1
        """
        XCTAssertEqual(C.count(in: csv, format: "csv"), 2)
        XCTAssertEqual(C.count(in: "", format: "csv"), 0)
    }

    func testCountTableIsDataRows() {
        let border = String(repeating: "=", count: 120)
        let table = [
            border,
            "Study UID            Patient Name                   Study Date           Modality   # Series",
            border,
            "1.2.3                DOE^JOHN                       20240101             CT         2",
            "1.2.4                DOE^JANE                       20240102             MR         1",
            border,
        ].joined(separator: "\n")
        XCTAssertEqual(C.count(in: table, format: "table"), 2)
        // An empty / borderless render → 0.
        XCTAssertEqual(C.count(in: "No results.", format: "table"), 0)
    }

    // MARK: WADO-RS retrieve

    func testParseMetadataCount() {
        let json = """
        [ {"00080018": {"vr":"UI","Value":["1.2"]}}, {"00080018": {"vr":"UI","Value":["1.3"]}} ]
        """
        XCTAssertEqual(C.parseMetadataCount(json), 2)
        XCTAssertEqual(C.parseMetadataCount("(nothing)"), 0)
    }

    func testCompareRetrieveCountMatch() {
        let ref = C.retrieveRecord(level: "study", mode: "instances", success: true, count: 5)
        let same = C.retrieveRecord(level: "study", mode: "instances", success: true, count: 5)
        let diff = C.retrieveRecord(level: "study", mode: "instances", success: true, count: 4)
        XCTAssertTrue(C.compareRetrieve(reference: ref, cli: same).match)
        XCTAssertFalse(C.compareRetrieve(reference: ref, cli: diff).match)
    }

    // MARK: STOW-RS store

    func testParseStoreSummary() {
        let out = """
        Upload Summary:
          Total files: 3
          Successful: 2
          Failed: 1
        """
        let s = C.parseStore(out)
        XCTAssertEqual(s.sent, 3)
        XCTAssertEqual(s.succeeded, 2)
        XCTAssertEqual(s.failed, 1)
        XCTAssertFalse(s.overallOK)   // a failure means not OK
    }

    func testStoreOverallOKAndCompare() {
        let ref = WADOStoreSemantics(sent: 1, succeeded: 1, failed: 0)
        XCTAssertTrue(ref.overallOK)
        XCTAssertTrue(C.compareStore(reference: ref, cli: WADOStoreSemantics(sent: 1, succeeded: 1, failed: 0)).match)
        XCTAssertFalse(C.compareStore(reference: ref, cli: WADOStoreSemantics(sent: 1, succeeded: 0, failed: 1)).match)
    }

    // MARK: UPS-RS search / lifecycle

    func testParseSearchCollectsWorkitemUIDs() {
        let json = """
        [ {"workitemUID": "1.2.9", "state": "SCHEDULED"}, {"workitemUID": "1.2.8"} ]
        """
        let s = C.parseSearch(json, success: true)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.workitemUIDs, ["1.2.8", "1.2.9"])   // sorted
        XCTAssertTrue(s.overallOK)
    }

    func testParseCreateAndClaim() {
        let create = """
        Created worklist item:
          UID: 1.2.3.4.5
          Retrieve URL: http://x/workitems/1.2.3.4.5
        """
        let pc = C.parseCreate(create, exitOK: true)
        XCTAssertTrue(pc.ok)
        XCTAssertEqual(pc.uid, "1.2.3.4.5")

        let claim = """
        Successfully updated worklist item 1.2.3.4.5 to IN PROGRESS
        Transaction UID: 9.9.9
        """
        let cl = C.parseClaim(claim, exitOK: true)
        XCTAssertTrue(cl.ok)
        XCTAssertEqual(cl.transactionUID, "9.9.9")
    }

    /// The lifecycle compares the outcome (create/claim/finalState), never the
    /// client-minted UIDs.
    func testLifecycleCompareIgnoresUIDs() {
        let ref = C.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS")
        let cli = C.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS")
        XCTAssertTrue(C.compareUPS(reference: ref, cli: cli).match)
        let mismatch = C.lifecycleRecord(createOK: true, claimOK: false, finalState: "")
        XCTAssertFalse(C.compareUPS(reference: ref, cli: mismatch).match)
    }

    // MARK: scenario matrix

    func testSupportedToolsIncludeWADO() {
        XCTAssertTrue(CLIParityNetworkScenarios.supportedToolIDs.contains("dicom-wado"))
    }

    /// Every scenario targets the single `dicom-wado` binary and its argv begins with
    /// the subcommand under test (query / retrieve / store / ups).
    func testEveryScenarioIsSubcommandPrefixed() {
        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.4"
        scope.instanceUID = "1.2.5"; scope.upsLabel = "CT Scan"
        let subs: Set<String> = ["query", "retrieve", "store", "ups"]
        for s in CLIParityNetworkScenarios.wadoScenarios(scope: scope) {
            XCTAssertEqual(s.toolId, "dicom-wado")
            XCTAssertTrue(subs.contains(s.cliArgs.first ?? ""), "\(s.scenarioId) must begin with a dicom-wado subcommand")
            XCTAssertTrue(s.cliArgs.contains(CLIParityNetworkScenarios.webURLToken),
                          "\(s.scenarioId) must carry the WEBURL token")
        }
    }

    /// The always-on scenarios are generated even with an empty scope.
    func testAlwaysOnScenariosGenerated() {
        let ids = CLIParityNetworkScenarios.wadoScenarios(scope: WADOScope()).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-wado_net_query-study-all"))
        XCTAssertTrue(ids.contains("dicom-wado_net_query-format-csv"))
        XCTAssertTrue(ids.contains("dicom-wado_net_query-format-table"))
        XCTAssertTrue(ids.contains("dicom-wado_net_query-series"))
        XCTAssertTrue(ids.contains("dicom-wado_net_query-instance"))
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-study"))
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-study-metadata"))
        XCTAssertTrue(ids.contains("dicom-wado_net_store-default"))
        XCTAssertTrue(ids.contains("dicom-wado_net_ups-search"))
        // Gated scenarios are absent without their inputs.
        XCTAssertFalse(ids.contains("dicom-wado_net_retrieve-series"))
        XCTAssertFalse(ids.contains("dicom-wado_net_retrieve-instance"))
        XCTAssertFalse(ids.contains("dicom-wado_net_ups-lifecycle"))
    }

    /// Series/instance retrieve and the UPS lifecycle appear once their inputs are set.
    func testGatedScenariosAppearWithInputs() {
        var scope = WADOScope()
        scope.query.seriesUID = "1.2.4"; scope.instanceUID = "1.2.5"; scope.upsLabel = "CT Scan"
        let ids = CLIParityNetworkScenarios.wadoScenarios(scope: scope).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-series"))
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-instance"))
        XCTAssertTrue(ids.contains("dicom-wado_net_ups-lifecycle"))
    }

    /// Per-filter and combined QIDO scenarios mirror the dicom-query study sweep.
    func testPerFilterAndCombinedQueryScenarios() {
        var f = QueryFilters()
        f.patientName = "DOE*"; f.modality = "CT"
        let ids = CLIParityNetworkScenarios.wadoQueryScenarios(filters: f).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-wado_net_query-patient-name"))
        XCTAssertTrue(ids.contains("dicom-wado_net_query-modality"))
        XCTAssertTrue(ids.contains("dicom-wado_net_query-combined"))  // ≥2 filters → combined
    }

    /// The store scenario carries the SENDFILE token (the runner expands it into the
    /// transmitted DICOM file list) and the verbose flag.
    func testStoreScenarioShape() {
        let store = CLIParityNetworkScenarios.wadoStoreScenarios().first
        XCTAssertEqual(store?.cliArgs.first, "store")
        XCTAssertTrue(store?.cliArgs.contains(CLIParityNetworkScenarios.sendFileToken) ?? false)
        XCTAssertEqual(store?.studioParams["wado-mode"], "store")
    }
}
