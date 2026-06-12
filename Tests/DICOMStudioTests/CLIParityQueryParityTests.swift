// CLIParityQueryParityTests.swift
// dicom-query network parity: the comparator must judge two C-FIND result sets
// equal regardless of PACS ordering and catch genuine differences, and the
// scenario matrix must reflect the user-supplied query keys.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityQueryParityTests: XCTestCase {

    private typealias C = CLIParityQueryComparator

    // MARK: Comparator

    func testMatchesRegardlessOfResultOrdering() {
        let refObjects: [[String: String]] = [
            ["(0020,000D)": "1.2.3", "(0010,0010)": "DOE^JOHN"],
            ["(0020,000D)": "1.2.4", "(0010,0010)": "SMITH^JANE"],
        ]
        let ref = C.semantics(level: "study", success: true, objects: refObjects)
        // CLI JSON with the two studies in the OPPOSITE order.
        let cliJSON = """
        [
          {"(0020,000D)": "1.2.4", "(0010,0010)": "SMITH^JANE"},
          {"(0020,000D)": "1.2.3", "(0010,0010)": "DOE^JOHN"}
        ]
        """
        let cli = C.parse(cliJSON, level: "study", success: true)
        XCTAssertTrue(C.compare(reference: ref, cli: cli).match, "Result ordering must not cause drift")
        XCTAssertEqual(ref.count, 2)
    }

    func testDetectsAttributeValueDifference() {
        let ref = C.semantics(level: "study", success: true,
                              objects: [["(0020,000D)": "1.2.3", "(0010,0010)": "DOE^JOHN"]])
        let cli = C.parse(#"[{"(0020,000D)": "1.2.3", "(0010,0010)": "DOE^JANE"}]"#, level: "study", success: true)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match, "A differing attribute value must be drift")
    }

    func testCountMismatchIsDrift() {
        let ref = C.semantics(level: "study", success: true,
                              objects: [["(0020,000D)": "1.2.3"], ["(0020,000D)": "1.2.4"]])
        let cli = C.parse(#"[{"(0020,000D)": "1.2.3"}]"#, level: "study", success: true)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testEmptyResultsMatch() {
        let ref = C.semantics(level: "study", success: true, objects: [])
        let cli = C.parse("[]\n", level: "study", success: true)
        let cmp = C.compare(reference: ref, cli: cli)
        XCTAssertTrue(cmp.match)
        XCTAssertEqual(cli.count, 0)
    }

    func testParseToleratesStderrPrefix() {
        // combinedCLIText may prefix a "── stderr ──" marker; parse should still
        // find the JSON array on stdout.
        let cli = C.parse("── stderr ──\nFound 1 result\n[{\"(0020,000D)\": \"1.2.3\"}]\n", level: "study", success: true)
        XCTAssertEqual(cli.count, 1)
    }

    // MARK: Scenario matrix

    func testNoFiltersGeneratesBaseScenariosIncludingFormatsAndLevels() {
        let ids = CLIParityNetworkScenarios.queryScenarios(filters: QueryFilters()).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-query_net_study-all"))
        XCTAssertTrue(ids.contains("dicom-query_net_patient"))
        // Series/instance are ALWAYS generated (runner skips at run time without UIDs).
        XCTAssertTrue(ids.contains("dicom-query_net_series"))
        XCTAssertTrue(ids.contains("dicom-query_net_instance"))
        // --format coverage.
        XCTAssertTrue(ids.contains("dicom-query_net_study-format-csv"))
        XCTAssertTrue(ids.contains("dicom-query_net_study-format-table"))
        XCTAssertTrue(ids.contains("dicom-query_net_study-format-compact"))
        // Nothing filter-specific without inputs.
        XCTAssertFalse(ids.contains("dicom-query_net_study-combined"))
        XCTAssertFalse(ids.contains("dicom-query_net_study-patient-name"))
    }

    func testProvidedFiltersAddPerFilterAndCombinedScenarios() {
        var f = QueryFilters(); f.patientName = "DOE*"; f.modality = "CT"
        let ids = CLIParityNetworkScenarios.queryScenarios(filters: f).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-query_net_study-patient-name"))
        XCTAssertTrue(ids.contains("dicom-query_net_study-modality"))
        XCTAssertTrue(ids.contains("dicom-query_net_study-combined"), "≥2 filters → combined scenario")
    }

    func testSeriesAndInstanceAlwaysGeneratedAndCarryUIDsWhenProvided() {
        // Without UIDs the scenarios still exist (the runner skips them with guidance).
        let bare = CLIParityNetworkScenarios.queryScenarios(filters: QueryFilters())
        XCTAssertNil(bare.first { $0.scenarioId == "dicom-query_net_series" }?.studioParams["study-uid"])

        var f = QueryFilters(); f.studyUID = "1.2.3"; f.seriesUID = "1.2.3.4"
        let scs = CLIParityNetworkScenarios.queryScenarios(filters: f)
        let series = scs.first { $0.scenarioId == "dicom-query_net_series" }
        XCTAssertEqual(series?.studioParams["study-uid"], "1.2.3")
        let inst = scs.first { $0.scenarioId == "dicom-query_net_instance" }
        XCTAssertEqual(inst?.studioParams["study-uid"], "1.2.3")
        XCTAssertEqual(inst?.studioParams["series-uid"], "1.2.3.4")
    }

    func testFormatScenariosCarryTheirFormat() {
        let scs = CLIParityNetworkScenarios.queryScenarios(filters: QueryFilters())
        let csv = scs.first { $0.scenarioId == "dicom-query_net_study-format-csv" }
        XCTAssertEqual(csv?.studioParams["format"], "csv")
        XCTAssertTrue(csv?.cliArgs.contains("csv") ?? false)
    }

    func testFormatCountExtractionAndCompare() {
        let ref = C.semantics(level: "study", success: true, objects: [["a": "1"], ["a": "2"], ["a": "3"]])
        XCTAssertEqual(C.count(in: "──────\nrows…\nTotal: 3 study(ies)\n", format: "table"), 3)
        XCTAssertEqual(C.count(in: "h1,h2\nv1,v2\nv3,v4\n", format: "csv"), 2)         // 2 data rows
        XCTAssertEqual(C.count(in: "a | b\nc | d\n", format: "compact"), 2)
        XCTAssertTrue(C.compareCount(reference: ref, cliCount: 3, format: "table").match)
        XCTAssertFalse(C.compareCount(reference: ref, cliCount: 2, format: "csv").match)
    }

    func testScenariosForceJSONAndCarryLevel() {
        var f = QueryFilters(); f.patientName = "DOE*"
        let study = CLIParityNetworkScenarios.queryScenarios(filters: f)
            .first { $0.scenarioId == "dicom-query_net_study-patient-name" }
        let s = try! XCTUnwrap(study)
        XCTAssertEqual(s.studioParams["level"], "study")
        XCTAssertEqual(s.studioParams["patient-name"], "DOE*")
        XCTAssertTrue(s.cliArgs.contains("json"), "CLI must run --format json for parseable output")
        XCTAssertTrue(s.cliArgs.contains("--patient-name") && s.cliArgs.contains("DOE*"))
    }
}
