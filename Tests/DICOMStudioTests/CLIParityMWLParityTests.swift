// CLIParityMWLParityTests.swift
// dicom-mwl network parity: the comparator must reduce the worklist C-FIND's
// `--json` stdout to the same matched-item record the SDK reference produces, and
// the scenario matrix must drive read-only worklist queries with `--json`.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityMWLParityTests: XCTestCase {

    private typealias C = CLIParityMWLComparator

    // MARK: parse

    func testParsesJSONItemsAndCount() {
        let cli = """
        [
          {"StudyInstanceUID": "1.2.840.1", "SPSID": "SPS1", "AccessionNumber": "ACC1", "Modality": "CT"},
          {"StudyInstanceUID": "1.2.840.2", "SPSID": "SPS2", "AccessionNumber": "ACC2", "Modality": "MR"}
        ]
        """
        let s = C.parse(cli, success: true)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.itemKeys, ["study=1.2.840.1|sps=SPS1|acc=ACC1",
                                    "study=1.2.840.2|sps=SPS2|acc=ACC2"])
        XCTAssertTrue(s.overallOK)
    }

    func testParsesEmptyArrayAsZero() {
        let s = C.parse("[]\n", success: true)
        XCTAssertEqual(s.count, 0)
        XCTAssertTrue(s.itemKeys.isEmpty)
        XCTAssertTrue(s.overallOK)   // a successful empty worklist is still a success
    }

    /// Leading verbose / stderr-marker text before the JSON array must be tolerated
    /// (the array is sliced from the first '[' to the last ']').
    func testParseSlicesLeadingNoise() {
        let cli = """
        ── stderr ──
        Querying worklist...
        [ {"StudyInstanceUID": "9.9", "SPSID": "S", "AccessionNumber": "A"} ]
        """
        let s = C.parse(cli, success: true)
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s.itemKeys, ["study=9.9|sps=S|acc=A"])
    }

    /// An item missing every identity field still contributes a deterministic key
    /// and is counted (so two keyless items don't silently collapse the count).
    func testKeylessItemsAreStillCounted() {
        let cli = """
        [ {"Modality": "CT"}, {"Modality": "MR"} ]
        """
        let s = C.parse(cli, success: true)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.itemKeys, ["study=|sps=|acc=", "study=|sps=|acc="])
    }

    // MARK: canonical / compare (order-independent)

    func testOrderIndependentMatch() {
        let ref = C.record(success: true, count: 2,
                           keys: ["study=b|sps=2|acc=", "study=a|sps=1|acc="])
        let cli = C.record(success: true, count: 2,
                           keys: ["study=a|sps=1|acc=", "study=b|sps=2|acc="])
        XCTAssertTrue(C.compare(reference: ref, cli: cli).match)
    }

    func testCountMismatchIsDrift() {
        let ref = C.record(success: true, count: 3, keys: ["a", "b", "c"])
        let cli = C.record(success: true, count: 2, keys: ["a", "b"])
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testDifferentItemSetIsDrift() {
        let ref = C.record(success: true, count: 2, keys: ["a", "b"])
        let cli = C.record(success: true, count: 2, keys: ["a", "c"])
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    /// The success flag participates in the record, so a process disagreement shows.
    func testSuccessFlagIsCompared() {
        let ref = C.record(success: true, count: 1, keys: ["x"])
        let cli = C.record(success: false, count: 1, keys: ["x"])
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    // MARK: scenario matrix

    func testAllQueryAlwaysGenerated() {
        let scs = CLIParityNetworkScenarios.mwlScenarios(filters: WorklistFilters())
        let ids = scs.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-mwl_net_all"))
        XCTAssertEqual(ids.count, 1)   // no per-filter rows without filter values
    }

    func testPerFilterAndCombinedScenarios() {
        var f = WorklistFilters()
        f.modality = "CT"; f.date = "20240101"
        let scs = CLIParityNetworkScenarios.mwlScenarios(filters: f)
        let ids = scs.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-mwl_net_modality"))
        XCTAssertTrue(ids.contains("dicom-mwl_net_date"))
        XCTAssertTrue(ids.contains("dicom-mwl_net_combined"))  // ≥2 filters → combined
    }

    /// Every scenario runs the explicit `query` subcommand with `--json` so the
    /// per-item output parses robustly.
    func testScenariosAreQueryJSON() {
        var f = WorklistFilters(); f.patientID = "12345"
        for s in CLIParityNetworkScenarios.mwlScenarios(filters: f) {
            XCTAssertEqual(s.cliArgs.first, "query", "\(s.scenarioId) must run the query subcommand")
            XCTAssertTrue(s.cliArgs.contains("--json"), "\(s.scenarioId) must pass --json")
        }
    }

    /// A provided filter value reaches both the CLI argv and the studioParams the
    /// runner reads to build the reference query keys.
    func testFilterValueFlowsToArgvAndParams() {
        var f = WorklistFilters(); f.station = "CT1"
        let sc = CLIParityNetworkScenarios.mwlScenarios(filters: f)
            .first { $0.scenarioId == "dicom-mwl_net_station" }
        XCTAssertNotNil(sc)
        if let i = sc?.cliArgs.firstIndex(of: "--station") {
            XCTAssertEqual(sc?.cliArgs[i + 1], "CT1")
        } else { XCTFail("station scenario must carry --station CT1") }
        XCTAssertEqual(sc?.studioParams["station"], "CT1")
    }

    func testSupportedToolsIncludeMWL() {
        XCTAssertTrue(CLIParityNetworkScenarios.supportedToolIDs.contains("dicom-mwl"))
    }

    // MARK: reference date resolution (mirrors the CLI's parseDateFilter)

    func testDateResolutionMatchesCLI() {
        XCTAssertEqual(CLIParityNetworkReference.resolveWorklistDate("20240315"), "20240315")
        XCTAssertNil(CLIParityNetworkReference.resolveWorklistDate("2024-03-15"))
        XCTAssertNil(CLIParityNetworkReference.resolveWorklistDate("notadate"))
        XCTAssertNotNil(CLIParityNetworkReference.resolveWorklistDate("today"))
        XCTAssertNotNil(CLIParityNetworkReference.resolveWorklistDate("tomorrow"))
    }
}
