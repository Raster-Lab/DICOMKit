// CLIParityWADOParityTests.swift
// dicom-wado (DICOMweb) network parity: the comparator must reduce each subcommand's
// CLI output (QIDO-RS query JSON, WADO-RS retrieve, STOW-RS store summary, UPS-RS
// search/lifecycle) to the same semantic record the SDK reference produces, and the
// scenario matrix must drive the single dicom-wado binary's four subcommands.

import XCTest
@testable import DICOMStudio
import DICOMWeb

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

    /// The store sweep covers the default plus the outcome-neutral flags; the file-arg
    /// rows carry SENDFILE with their flag(s) trailing (the runner appends them after the
    /// expanded file list). The --input row is the exception: it uses a temp file list, so
    /// it carries no SENDFILE (see testStoreInputAndStudyScenarios).
    func testStoreFlagVariants() {
        let stores = CLIParityNetworkScenarios.wadoStoreScenarios()
        let ids = stores.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-wado_net_store-default"))
        XCTAssertTrue(ids.contains("dicom-wado_net_store-verbose"))
        XCTAssertTrue(ids.contains("dicom-wado_net_store-batch-1"))
        XCTAssertTrue(ids.contains("dicom-wado_net_store-continue-on-error"))
        XCTAssertEqual(ids.count, Set(ids).count)

        for s in stores {
            XCTAssertEqual(s.cliArgs.first, "store")
            XCTAssertEqual(s.studioParams["wado-mode"], "store")
            // The --input row drives the upload from a temp file list, not positional
            // file args, so it deliberately carries no SENDFILE token.
            if s.studioParams["store-input"] == "true" { continue }
            guard let idx = s.cliArgs.firstIndex(of: CLIParityNetworkScenarios.sendFileToken) else {
                return XCTFail("\(s.scenarioId) must carry the SENDFILE token")
            }
            let trailing = Array(s.cliArgs[(idx + 1)...])
            switch s.scenarioId {
            case "dicom-wado_net_store-default":           XCTAssertEqual(trailing, [])
            case "dicom-wado_net_store-verbose":           XCTAssertEqual(trailing, ["--verbose"])
            case "dicom-wado_net_store-batch-1":           XCTAssertEqual(trailing, ["--batch", "1"])
            case "dicom-wado_net_store-continue-on-error": XCTAssertEqual(trailing, ["--continue-on-error"])
            case "dicom-wado_net_store-study":             XCTAssertEqual(trailing, ["--study", "1.2.3"])
            default: break
            }
        }
    }

    // MARK: UPS-RS search filter-state + format sweep

    /// The UPS search sweep covers the broad query, one row per --filter-state value,
    /// and json/csv/table format coverage. Each search row carries --search; the state
    /// rows carry their --filter-state; the format rows carry their --format.
    func testUPSSearchFilterAndFormatScenarios() {
        let ups = CLIParityNetworkScenarios.wadoUPSScenarios(scope: WADOScope())
        let ids = ups.map { $0.scenarioId }
        for id in ["ups-search", "ups-search-scheduled", "ups-search-in-progress",
                   "ups-search-completed", "ups-search-canceled", "ups-search-csv", "ups-search-table"] {
            XCTAssertTrue(ids.contains("dicom-wado_net_\(id)"), "missing \(id)")
        }
        // The lifecycle is NOT generated without a label.
        XCTAssertFalse(ids.contains("dicom-wado_net_ups-lifecycle"))

        for s in ups {
            XCTAssertEqual(s.cliArgs.first, "ups")
            XCTAssertEqual(s.studioParams["wado-mode"], "ups-search")
            XCTAssertTrue(s.cliArgs.contains("--search"))
        }
        let scheduled = ups.first { $0.scenarioId == "dicom-wado_net_ups-search-scheduled" }
        XCTAssertEqual(scheduled?.studioParams["filter-state"], "SCHEDULED")
        XCTAssertTrue(scheduled?.cliArgs.contains("--filter-state") ?? false)
        let inProgress = ups.first { $0.scenarioId == "dicom-wado_net_ups-search-in-progress" }
        XCTAssertEqual(inProgress?.studioParams["filter-state"], "IN_PROGRESS")
        let csv = ups.first { $0.scenarioId == "dicom-wado_net_ups-search-csv" }
        XCTAssertEqual(csv?.studioParams["format"], "csv")
        XCTAssertNil(csv?.studioParams["filter-state"])   // broad search, format only
    }

    /// Non-JSON ups search renders are validated by matched COUNT: CSV = rows−header,
    /// table = data rows between the "="-borders, JSON via the workitem array.
    func testCountWorkitems() {
        let csv = """
        WorkitemUID,State,ProcedureStepLabel,PatientName,PatientID
        1.2.9,SCHEDULED,CT,DOE^JOHN,P1
        1.2.8,IN PROGRESS,MR,DOE^JANE,P2
        """
        XCTAssertEqual(C.countWorkitems(in: csv, format: "csv"), 2)
        XCTAssertEqual(C.countWorkitems(in: "WorkitemUID,State,ProcedureStepLabel,PatientName,PatientID", format: "csv"), 0)

        let border = String(repeating: "=", count: 84)
        let table = [
            border,
            "Worklist UID   State                Label                          Patient",
            border,
            "1.2.9          SCHEDULED            CT                             DOE^JOHN",
            "1.2.8          IN PROGRESS          MR                             DOE^JANE",
            border,
        ].joined(separator: "\n")
        XCTAssertEqual(C.countWorkitems(in: table, format: "table"), 2)
        XCTAssertEqual(C.countWorkitems(in: "No results.", format: "table"), 0)

        let json = """
        [ {"workitemUID": "1.2.9"}, {"workitemUID": "1.2.8"} ]
        """
        XCTAssertEqual(C.countWorkitems(in: json, format: "json"), 2)
    }

    // MARK: WADO-RS metadata XML parity (--format xml)

    /// The CLI's `retrieve --metadata --format xml` emits one `<NativeDicomModel>` per
    /// instance — a lone model for one instance, a `<NativeDicomModelList>` of N for
    /// many, an empty list for none — and the count reduces to the instance count.
    func testParseMetadataXMLCount() {
        let ns = "http://dicom.nema.org/PS3.19/models/NativeDICOM"
        let single = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel xmlns="\(ns)">
          <DicomAttribute tag="00080018" vr="UI" keyword="SOPInstanceUID"><Value number="1">1.2.3</Value></DicomAttribute>
        </NativeDicomModel>
        """
        XCTAssertEqual(C.parseMetadataXMLCount(single), 1)

        let multi = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModelList>
        <NativeDicomModel xmlns="\(ns)">
        </NativeDicomModel>
        <NativeDicomModel xmlns="\(ns)">
        </NativeDicomModel>
        </NativeDicomModelList>
        """
        XCTAssertEqual(C.parseMetadataXMLCount(multi), 2)

        let empty = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModelList>
        </NativeDicomModelList>
        """
        XCTAssertEqual(C.parseMetadataXMLCount(empty), 0)   // matches reference count 0
        XCTAssertEqual(C.parseMetadataXMLCount("(no xml)"), 0)
    }

    /// `parseStore` must read the counts from the "Upload Summary" block only — a
    /// `--verbose` run prints per-failure "Failed: <SOPUID> - …" detail lines first,
    /// and a digit from a SOP Instance UID must not be mistaken for the failure count.
    func testParseStoreIgnoresVerboseFailureLines() {
        let verbose = """
        Batch 1: Uploading 3 file(s)...
          Success: 1, Failure: 2
            Failed: 1.2.840.113619.2.5.123456 - Code 272
            Failed: 1.2.840.113619.2.5.999888 - Code 272

        Upload Summary:
          Total files: 3
          Successful: 1
          Failed: 2
        """
        let s = C.parseStore(verbose)
        XCTAssertEqual(s.sent, 3)
        XCTAssertEqual(s.succeeded, 1)
        XCTAssertEqual(s.failed, 2)   // NOT 1, which a naive prefix match would read from the UID
    }

    // MARK: retrieve metadata format matrix + guards

    /// Metadata is swept in both JSON and XML: study level is always on; series/instance
    /// metadata (and the instance XML variant) appear once their scoping UID is supplied.
    func testRetrieveMetadataFormatScenarios() {
        let base = CLIParityNetworkScenarios.wadoScenarios(scope: WADOScope())
        let baseIDs = base.map { $0.scenarioId }
        XCTAssertTrue(baseIDs.contains("dicom-wado_net_retrieve-study-metadata"))
        XCTAssertTrue(baseIDs.contains("dicom-wado_net_retrieve-study-metadata-xml"))
        // Gated metadata scenarios are absent without their scoping UIDs.
        XCTAssertFalse(baseIDs.contains("dicom-wado_net_retrieve-series-metadata"))
        XCTAssertFalse(baseIDs.contains("dicom-wado_net_retrieve-instance-metadata-xml"))

        // The XML scenario carries --metadata --format xml and the metadata-format param.
        let xml = base.first { $0.scenarioId == "dicom-wado_net_retrieve-study-metadata-xml" }
        XCTAssertEqual(xml?.studioParams["metadata-format"], "xml")
        XCTAssertEqual(xml?.studioParams["metadata"], "true")
        XCTAssertTrue(xml?.cliArgs.contains("--metadata") ?? false)
        if let args = xml?.cliArgs, let i = args.firstIndex(of: "--format") {
            XCTAssertEqual(args[i + 1], "xml")
        } else {
            XCTFail("metadata-xml scenario must pass --format xml")
        }

        // With series + instance UIDs the gated metadata scenarios appear.
        var scope = WADOScope()
        scope.query.seriesUID = "1.2.4"; scope.instanceUID = "1.2.5"
        let ids = CLIParityNetworkScenarios.wadoScenarios(scope: scope).map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-series-metadata"))
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-instance-metadata"))
        XCTAssertTrue(ids.contains("dicom-wado_net_retrieve-instance-metadata-xml"))
    }

    /// Every retrieve scenario must pass `--study` — dicom-wado retrieve throws without it.
    func testAllRetrieveScenariosCarryStudyFlag() {
        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.4"; scope.instanceUID = "1.2.5"
        let retrieves = CLIParityNetworkScenarios.wadoScenarios(scope: scope)
            .filter { $0.studioParams["wado-mode"] == "retrieve" }
        XCTAssertFalse(retrieves.isEmpty)
        for s in retrieves {
            XCTAssertTrue(s.cliArgs.contains("--study"),
                          "\(s.scenarioId) must pass --study (required by dicom-wado retrieve)")
        }
    }

    /// No two generated scenarios may share an ID (a copy-paste guard for the matrix).
    func testWADOScenarioIDsAreUnique() {
        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.4"; scope.instanceUID = "1.2.5"
        scope.upsLabel = "CT Scan"
        scope.query.patientName = "DOE*"; scope.query.modality = "CT"
        let ids = CLIParityNetworkScenarios.wadoScenarios(scope: scope).map { $0.scenarioId }
        XCTAssertEqual(ids.count, Set(ids).count, "wado scenario IDs must be unique")
    }

    // MARK: QIDO-RS pagination (--limit / --offset)

    /// The pagination rows are always generated (broad study query); they carry the
    /// harness-picked page size/offset on BOTH the argv (for the CLI) and studioParams
    /// (so the runner replays the same page in the reference and selects count parity).
    func testQueryLimitOffsetScenarios() {
        let q = CLIParityNetworkScenarios.wadoQueryScenarios(filters: QueryFilters())
        let limit = q.first { $0.scenarioId == "dicom-wado_net_query-limit" }
        XCTAssertNotNil(limit)
        XCTAssertEqual(limit?.studioParams["limit"], "5")
        XCTAssertNil(limit?.studioParams["offset"])
        if let args = limit?.cliArgs, let i = args.firstIndex(of: "--limit") {
            XCTAssertEqual(args[i + 1], "5")
        } else { XCTFail("query-limit must pass --limit 5") }

        let offset = q.first { $0.scenarioId == "dicom-wado_net_query-offset" }
        XCTAssertEqual(offset?.studioParams["limit"], "5")
        XCTAssertEqual(offset?.studioParams["offset"], "5")
        if let args = offset?.cliArgs, let i = args.firstIndex(of: "--offset") {
            XCTAssertEqual(args[i + 1], "5")
        } else { XCTFail("query-offset must pass --offset 5") }
        XCTAssertTrue(offset?.cliArgs.contains("--limit") ?? false)

        // The plain broad query carries NEITHER paging flag (it keeps full set parity).
        let all = q.first { $0.scenarioId == "dicom-wado_net_query-study-all" }
        XCTAssertFalse(all?.cliArgs.contains("--limit") ?? true)
        XCTAssertNil(all?.studioParams["limit"])
    }

    // MARK: WADO-URI retrieve (--uri)

    /// The WADO-URI rows appear only with an Instance UID (always single-instance). Each
    /// carries --uri + study/series/instance (reused from the scope, no new field) and
    /// --output (scratch dir), routes through the retrieve-uri runner, and the variants
    /// add their --content-type / --timeout.
    func testWADOURIScenarios() {
        // Absent without an Instance UID.
        let bare = CLIParityNetworkScenarios.wadoScenarios(scope: WADOScope()).map { $0.scenarioId }
        XCTAssertFalse(bare.contains("dicom-wado_net_retrieve-uri"))

        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.4"; scope.instanceUID = "1.2.5"
        let uris = CLIParityNetworkScenarios.wadoScenarios(scope: scope)
            .filter { $0.studioParams["wado-mode"] == "retrieve-uri" }
        let ids = uris.map { $0.scenarioId }
        for id in ["retrieve-uri", "retrieve-uri-jpeg", "retrieve-uri-timeout"] {
            XCTAssertTrue(ids.contains("dicom-wado_net_\(id)"), "missing \(id)")
        }

        for s in uris {
            XCTAssertEqual(s.cliArgs.first, "retrieve")
            XCTAssertTrue(s.cliArgs.contains("--uri"))
            XCTAssertTrue(s.cliArgs.contains("--study"))
            XCTAssertTrue(s.cliArgs.contains("--series"))
            XCTAssertTrue(s.cliArgs.contains("--instance"))
            XCTAssertTrue(s.cliArgs.contains("--output"))   // saves to the scratch dir, not cwd
            XCTAssertEqual(s.studioParams["level"], "instance")
            XCTAssertEqual(s.studioParams["instance-uid"], "1.2.5")
        }

        let jpeg = uris.first { $0.scenarioId == "dicom-wado_net_retrieve-uri-jpeg" }
        XCTAssertEqual(jpeg?.studioParams["content-type"], "image/jpeg")
        if let args = jpeg?.cliArgs, let i = args.firstIndex(of: "--content-type") {
            XCTAssertEqual(args[i + 1], "image/jpeg")
        } else { XCTFail("uri-jpeg must pass --content-type image/jpeg") }

        // The default URI row requests application/dicom implicitly (no --content-type).
        let plain = uris.first { $0.scenarioId == "dicom-wado_net_retrieve-uri" }
        XCTAssertEqual(plain?.studioParams["content-type"], "")
        XCTAssertFalse(plain?.cliArgs.contains("--content-type") ?? true)

        // The timeout combo proves --timeout is accepted in URI mode (ignored, stays at parity).
        let to = uris.first { $0.scenarioId == "dicom-wado_net_retrieve-uri-timeout" }
        if let args = to?.cliArgs, let i = args.firstIndex(of: "--timeout") {
            XCTAssertEqual(args[i + 1], "60")
        } else { XCTFail("uri-timeout must pass --timeout 60") }
    }

    /// The CLI's WADO-URI retrieve prints "Retrieved N bytes" (with or without --verbose);
    /// the byte count is the first integer on that line — a digit in the trailing filename
    /// must not be read instead.
    func testParseURIBytes() {
        XCTAssertEqual(C.parseURIBytes("Retrieved 524288 bytes → 1.2.840.10.dcm"), 524288)
        XCTAssertEqual(C.parseURIBytes("Retrieved 12345 bytes via WADO-URI"), 12345)
        let verbose = """
        WADO-URI Server: http://h/wado
        Study UID:    1.2.3
        Instance UID: 1.2.5
        Retrieved 1024 bytes via WADO-URI
        Saved to: /tmp/out/1.2.5.dcm
        """
        XCTAssertEqual(C.parseURIBytes(verbose), 1024)
        XCTAssertEqual(C.parseURIBytes("Retrieved 0 bytes → x.dcm"), 0)
        XCTAssertEqual(C.parseURIBytes("(nothing retrieved)"), 0)   // no "Retrieved" line → 0
    }

    /// uriContentType (reference) must map each --content-type string to the SAME
    /// WADOURIClient content type the dicom-wado CLI's switch produces — both sides must
    /// request the identical representation. For transcoded types the live URI comparison
    /// is success-only (the server may re-encode per request), so THIS mapping test is
    /// what guards content-type → enum parity. Mirrors DICOMWado.swift runWADOURI's switch.
    func testURIContentTypeMapping() {
        typealias R = CLIParityNetworkReference
        XCTAssertEqual(R.uriContentType(""), .dicom)                       // CLI default (no flag)
        XCTAssertEqual(R.uriContentType("application/dicom"), .dicom)
        XCTAssertEqual(R.uriContentType("image/jpeg"), .jpeg)
        XCTAssertEqual(R.uriContentType("jpeg"), .jpeg)
        XCTAssertEqual(R.uriContentType("image/png"), .png)
        XCTAssertEqual(R.uriContentType("png"), .png)
        XCTAssertEqual(R.uriContentType("image/gif"), .gif)
        XCTAssertEqual(R.uriContentType("image/jp2"), .jpeg2000)
        XCTAssertEqual(R.uriContentType("htj2k"), .htj2k)
        XCTAssertEqual(R.uriContentType("image/jph"), .htj2k)
        XCTAssertEqual(R.uriContentType("htj2k-container"), .htj2kContainer)
        XCTAssertEqual(R.uriContentType("image/jphc"), .htj2kContainer)
        XCTAssertEqual(R.uriContentType("video/mpeg"), .mpeg)
        XCTAssertEqual(R.uriContentType("IMAGE/JPEG"), .jpeg)              // case-insensitive
        XCTAssertEqual(R.uriContentType("bogus/unknown"), .dicom)         // unknown → default
    }

    /// The URI record compares on mode + level + success + byte count (a byte-count
    /// mismatch is a real drift; matching counts pass).
    func testURIRecordCompare() {
        let ref = C.retrieveRecord(level: "instance", mode: "uri", success: true, count: 2048)
        let same = C.retrieveRecord(level: "instance", mode: "uri", success: true, count: 2048)
        XCTAssertTrue(C.compareRetrieve(reference: ref, cli: same).match)
        let drift = C.retrieveRecord(level: "instance", mode: "uri", success: true, count: 4096)
        XCTAssertFalse(C.compareRetrieve(reference: ref, cli: drift).match)
        // Both-fail (server can't speak WADO-URI) is still parity, not a false DIFFERS.
        let bothFail = C.retrieveRecord(level: "instance", mode: "uri", success: false, count: 0)
        XCTAssertTrue(C.compareRetrieve(reference: bothFail, cli: bothFail).match)
    }

    // MARK: WADO-RS derived retrieve (--rendered / --thumbnail / --frames)

    /// The derived retrievals are level-gated like the WADO-RS retrieve: study-level
    /// thumbnail is always shown; series thumbnail needs a Series UID; rendered, instance
    /// thumbnail, and frames need a SOP Instance UID. Each carries --study + its mode flag
    /// + --output, routes through the retrieve-derived runner, and records its kind.
    func testRetrieveDerivedScenarios() {
        // Without a Series/Instance UID: only the study-level thumbnail appears.
        let bare = CLIParityNetworkScenarios.wadoScenarios(scope: WADOScope())
        let bareIDs = bare.map { $0.scenarioId }
        XCTAssertTrue(bareIDs.contains("dicom-wado_net_retrieve-thumbnail-study"))
        XCTAssertFalse(bareIDs.contains("dicom-wado_net_retrieve-thumbnail-series"))
        XCTAssertFalse(bareIDs.contains("dicom-wado_net_retrieve-rendered"))
        XCTAssertFalse(bareIDs.contains("dicom-wado_net_retrieve-frames"))

        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.4"; scope.instanceUID = "1.2.5"
        let all = CLIParityNetworkScenarios.wadoScenarios(scope: scope)
        let derived = all.filter { $0.studioParams["wado-mode"] == "retrieve-derived" }
        let ids = derived.map { $0.scenarioId }
        for id in ["retrieve-thumbnail-study", "retrieve-thumbnail-series", "retrieve-thumbnail-instance",
                   "retrieve-rendered", "retrieve-frames"] {
            XCTAssertTrue(ids.contains("dicom-wado_net_\(id)"), "missing \(id)")
        }

        for s in derived {
            XCTAssertEqual(s.cliArgs.first, "retrieve")
            XCTAssertTrue(s.cliArgs.contains("--study"), "\(s.scenarioId) must pass --study")
            XCTAssertTrue(s.cliArgs.contains("--output"), "\(s.scenarioId) must write to a scratch dir")
            XCTAssertNotNil(s.studioParams["retrieve-kind"])
        }

        let rendered = derived.first { $0.scenarioId == "dicom-wado_net_retrieve-rendered" }
        XCTAssertEqual(rendered?.studioParams["retrieve-kind"], "rendered")
        XCTAssertEqual(rendered?.studioParams["level"], "instance")
        XCTAssertTrue(rendered?.cliArgs.contains("--rendered") ?? false)
        XCTAssertTrue(rendered?.cliArgs.contains("--instance") ?? false)

        let thumbStudy = derived.first { $0.scenarioId == "dicom-wado_net_retrieve-thumbnail-study" }
        XCTAssertEqual(thumbStudy?.studioParams["level"], "study")
        XCTAssertTrue(thumbStudy?.cliArgs.contains("--thumbnail") ?? false)
        XCTAssertFalse(thumbStudy?.cliArgs.contains("--series") ?? true)   // study level → no --series

        let frames = derived.first { $0.scenarioId == "dicom-wado_net_retrieve-frames" }
        XCTAssertEqual(frames?.studioParams["retrieve-kind"], "frames")
        XCTAssertEqual(frames?.studioParams["frames"], "1")
        if let args = frames?.cliArgs, let i = args.firstIndex(of: "--frames") {
            XCTAssertEqual(args[i + 1], "1")
        } else { XCTFail("frames scenario must pass --frames 1") }
    }

    // MARK: STOW-RS --study / --input

    /// store --input is always generated (uploads via a temp file list — no SENDFILE);
    /// store --study appears only with a Study UID and carries --study + the study-uid param.
    func testStoreInputAndStudyScenarios() {
        // --input always present; --study absent without a Study UID.
        let plain = CLIParityNetworkScenarios.wadoStoreScenarios()
        let plainIDs = plain.map { $0.scenarioId }
        XCTAssertTrue(plainIDs.contains("dicom-wado_net_store-input"))
        XCTAssertFalse(plainIDs.contains("dicom-wado_net_store-study"))

        let input = plain.first { $0.scenarioId == "dicom-wado_net_store-input" }
        XCTAssertEqual(input?.studioParams["store-input"], "true")
        XCTAssertEqual(input?.studioParams["wado-mode"], "store")
        XCTAssertTrue(input?.cliArgs.contains("--input") ?? false)
        XCTAssertFalse(input?.cliArgs.contains(CLIParityNetworkScenarios.sendFileToken) ?? true)

        // With a Study UID, store-study appears and carries --study + the param.
        let withStudy = CLIParityNetworkScenarios.wadoStoreScenarios(studyUID: "1.2.3")
        let study = withStudy.first { $0.scenarioId == "dicom-wado_net_store-study" }
        XCTAssertNotNil(study)
        XCTAssertEqual(study?.studioParams["study-uid"], "1.2.3")
        if let args = study?.cliArgs, let i = args.firstIndex(of: "--study") {
            XCTAssertEqual(args[i + 1], "1.2.3")
        } else { XCTFail("store-study must pass --study 1.2.3") }
        // store-study still uploads positional files (SENDFILE), with --study trailing.
        XCTAssertTrue(study?.cliArgs.contains(CLIParityNetworkScenarios.sendFileToken) ?? false)
    }

    // MARK: UPS-RS create → get round-trip

    /// ups-get is generated only with a Procedure Step Label (it must create a workitem
    /// first); it carries the --create-workitem command and routes through the ups-get
    /// runner (which chains the --get by the minted UID).
    func testUPSGetScenario() {
        let bare = CLIParityNetworkScenarios.wadoUPSScenarios(scope: WADOScope()).map { $0.scenarioId }
        XCTAssertFalse(bare.contains("dicom-wado_net_ups-get"))

        var scope = WADOScope()
        scope.upsLabel = "CT Scan"; scope.upsPatientName = "DOE^JANE"
        let ups = CLIParityNetworkScenarios.wadoUPSScenarios(scope: scope)
        let get = ups.first { $0.scenarioId == "dicom-wado_net_ups-get" }
        XCTAssertNotNil(get)
        XCTAssertEqual(get?.studioParams["wado-mode"], "ups-get")
        XCTAssertEqual(get?.studioParams["label"], "CT Scan")
        XCTAssertEqual(get?.cliArgs.first, "ups")
        XCTAssertTrue(get?.cliArgs.contains("--create-workitem") ?? false)
        if let args = get?.cliArgs, let i = args.firstIndex(of: "--label") {
            XCTAssertEqual(args[i + 1], "CT Scan")
        } else { XCTFail("ups-get must pass --label") }
    }

    /// The get record compares on operation + createOK + getOK (the minted UIDs differ by
    /// design and are never compared). A divergence in either outcome shows DIFFERS.
    func testUPSGetRecordCompare() {
        let ref = C.getRecord(createOK: true, getOK: true)
        XCTAssertEqual(ref.operation, "get")
        XCTAssertTrue(ref.overallOK)
        XCTAssertTrue(C.compareUPS(reference: ref, cli: C.getRecord(createOK: true, getOK: true)).match)
        // get failed on one side → DIFFERS.
        XCTAssertFalse(C.compareUPS(reference: ref, cli: C.getRecord(createOK: true, getOK: false)).match)
        // Both failed to create → parity holds on the failure path (both !overallOK).
        let bothFail = C.getRecord(createOK: false, getOK: false)
        XCTAssertFalse(bothFail.overallOK)
        XCTAssertTrue(C.compareUPS(reference: bothFail, cli: bothFail).match)
        // A get record must never compare equal to a lifecycle record (different op).
        XCTAssertFalse(C.compareUPS(reference: ref,
                                    cli: C.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS")).match)
    }

    // MARK: countFiles helper

    /// countFiles counts every regular file the CLI wrote into a fresh derived-retrieve
    /// scratch dir (rendered/thumbnail → 1; frames → one per frame), ignoring sub-dirs.
    func testCountFiles() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("studio-parity-countfiles-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        XCTAssertEqual(CLIParityRunnerViewModel.countFiles(inDir: dir.path), 0)
        try Data([0x1]).write(to: dir.appendingPathComponent("rendered_1.2.5.jpg"))
        try Data([0x2]).write(to: dir.appendingPathComponent("frame_1_1.2.5.raw"))
        try fm.createDirectory(at: dir.appendingPathComponent("subdir"), withIntermediateDirectories: true)
        // A hidden/system file (e.g. .DS_Store) the OS may drop into the temp dir must NOT
        // inflate the CLI count vs the reference's in-memory count → no false DIFFERS.
        try Data([0x3]).write(to: dir.appendingPathComponent(".DS_Store"))
        XCTAssertEqual(CLIParityRunnerViewModel.countFiles(inDir: dir.path), 2)   // sub-dir + hidden file not counted
        XCTAssertEqual(CLIParityRunnerViewModel.countFiles(inDir: ""), 0)
    }

    /// The reference-pane header must name the actual UPS operation (a get round-trip is
    /// not a search) — the comparison logic already distinguishes them; the label must too.
    func testRenderWADOUPSLabels() {
        let get = CLIParityNetworkReference.renderWADOUPS(C.getRecord(createOK: true, getOK: true))
        XCTAssertTrue(get.contains("create → get"), "get render must say create → get, got: \(get)")
        let life = CLIParityNetworkReference.renderWADOUPS(C.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS"))
        XCTAssertTrue(life.contains("create → claim"))
        let search = CLIParityNetworkReference.renderWADOUPS(C.searchRecord(success: true, count: 0, uids: []))
        XCTAssertTrue(search.contains("search"))
        let create = CLIParityNetworkReference.renderWADOUPS(C.createRecord(createOK: true))
        XCTAssertTrue(create.contains("create-workitem"))
        let sub = CLIParityNetworkReference.renderWADOUPS(C.subscribeRecord(createOK: true, roundTripOK: true))
        XCTAssertTrue(sub.contains("subscribe"))
    }

    // MARK: Group B — UPS scheduled-station / create-attrs / create-json / subscribe

    /// The --scheduled-station search row is always generated; it carries the harness-picked
    /// station on both the argv and studioParams (the runner replays it in the reference).
    func testUPSScheduledStationScenario() {
        let ups = CLIParityNetworkScenarios.wadoUPSScenarios(scope: WADOScope())
        let station = ups.first { $0.scenarioId == "dicom-wado_net_ups-search-station" }
        XCTAssertNotNil(station)
        XCTAssertEqual(station?.studioParams["wado-mode"], "ups-search")
        let st = station?.studioParams["scheduled-station"]
        XCTAssertEqual(st?.isEmpty, false)
        if let args = station?.cliArgs, let i = args.firstIndex(of: "--scheduled-station") {
            XCTAssertEqual(args[i + 1], st)
        } else { XCTFail("station search must pass --scheduled-station") }
    }

    /// The create-attrs / create-json / subscribe rows are generated only with a Procedure
    /// Step Label; each routes through its own runner and carries the right command shape.
    func testUPSGroupBScenariosGatedOnLabel() {
        let bare = CLIParityNetworkScenarios.wadoUPSScenarios(scope: WADOScope()).map { $0.scenarioId }
        for id in ["ups-create-attrs", "ups-create-json", "ups-subscribe"] {
            XCTAssertFalse(bare.contains("dicom-wado_net_\(id)"), "\(id) must be gated on a label")
        }

        var scope = WADOScope()
        scope.upsLabel = "CT Scan"; scope.upsPatientName = "DOE^JANE"; scope.upsPatientID = "P1"
        let ups = CLIParityNetworkScenarios.wadoUPSScenarios(scope: scope)

        // create-attrs: --create-workitem with the full attribute set; wado-mode ups-create.
        let attrs = ups.first { $0.scenarioId == "dicom-wado_net_ups-create-attrs" }
        XCTAssertEqual(attrs?.studioParams["wado-mode"], "ups-create")
        XCTAssertTrue(attrs?.cliArgs.contains("--create-workitem") ?? false)
        // Every attribute flag must appear in the argv AND be replayable from studioParams.
        for flag in ["--priority", "--patient-birth-date", "--patient-sex", "--accession-number",
                     "--referring-physician", "--procedure-id", "--step-id", "--worklist-label",
                     "--comments", "--scheduled-start", "--expected-completion", "--station-name",
                     "--performer-name", "--performer-organization", "--admission-id"] {
            XCTAssertTrue(attrs?.cliArgs.contains(flag) ?? false, "create-attrs must pass \(flag)")
            let key = String(flag.dropFirst(2))
            XCTAssertNotNil(attrs?.studioParams[key], "create-attrs studioParams must carry \(key)")
        }
        // The argv value and the studioParams value must match for each attribute (so the
        // reference replays the IDENTICAL value the CLI received).
        if let args = attrs?.cliArgs, let i = args.firstIndex(of: "--priority") {
            XCTAssertEqual(args[i + 1], attrs?.studioParams["priority"])
        }

        // create-json: --create with a placeholder; wado-mode ups-create-json.
        let json = ups.first { $0.scenarioId == "dicom-wado_net_ups-create-json" }
        XCTAssertEqual(json?.studioParams["wado-mode"], "ups-create-json")
        XCTAssertTrue(json?.cliArgs.contains("--create") ?? false)

        // subscribe: --create-workitem (the runner chains subscribe/unsubscribe); carries an AE.
        let sub = ups.first { $0.scenarioId == "dicom-wado_net_ups-subscribe" }
        XCTAssertEqual(sub?.studioParams["wado-mode"], "ups-subscribe")
        XCTAssertEqual(sub?.studioParams["aet"]?.isEmpty, false)
        XCTAssertTrue(sub?.cliArgs.contains("--create-workitem") ?? false)
    }

    /// createRecord/subscribeRecord overallOK + compareUPS keep the operations distinct (a
    /// create record must never compare equal to a subscribe/get/lifecycle record).
    func testUPSCreateAndSubscribeRecords() {
        let create = C.createRecord(createOK: true)
        XCTAssertEqual(create.operation, "create")
        XCTAssertTrue(create.overallOK)
        XCTAssertFalse(C.createRecord(createOK: false).overallOK)
        XCTAssertTrue(C.compareUPS(reference: create, cli: C.createRecord(createOK: true)).match)
        XCTAssertFalse(C.compareUPS(reference: create, cli: C.createRecord(createOK: false)).match)

        let sub = C.subscribeRecord(createOK: true, roundTripOK: true)
        XCTAssertEqual(sub.operation, "subscribe")
        XCTAssertTrue(sub.overallOK)
        XCTAssertFalse(C.subscribeRecord(createOK: true, roundTripOK: false).overallOK)
        XCTAssertTrue(C.compareUPS(reference: sub, cli: C.subscribeRecord(createOK: true, roundTripOK: true)).match)
        // Both-fail (server lacks UPS subscription) still holds parity on the failure path.
        let bothFail = C.subscribeRecord(createOK: true, roundTripOK: false)
        XCTAssertTrue(C.compareUPS(reference: bothFail, cli: bothFail).match)
        // Distinct operations must never compare equal.
        XCTAssertFalse(C.compareUPS(reference: create, cli: sub).match)
        XCTAssertFalse(C.compareUPS(reference: sub, cli: C.getRecord(createOK: true, getOK: true)).match)
    }

    /// The synthesised --create JSON must be a non-empty, well-formed DICOM-JSON object the
    /// CLI can read (the reference and the file get DISTINCT minted UIDs, so creates don't collide).
    func testUPSCreateWorkitemJSON() throws {
        let a = CLIParityNetworkReference.upsCreateWorkitemJSON(label: "CT Scan", patientName: "DOE^JANE", patientID: "P1")
        XCTAssertFalse(a.isEmpty)
        let data = try XCTUnwrap(a.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(obj is [String: Any], "create JSON must be a DICOM-JSON object")
        XCTAssertFalse((obj as? [String: Any])?.isEmpty ?? true, "create JSON must carry attributes")
    }

    // MARK: Invalid-input parity (reference must FAIL where the CLI throws)

    /// The CLI's createWorkitemFromOptions throws (non-zero exit → create fails) on an
    /// invalid priority / patient-sex / date; the reference must report createOK=false too —
    /// not silently skip the bad attribute — so both sides agree for ANY input. These return
    /// at the validation guard BEFORE any network call, so no live server is needed.
    func testReferenceFailsInvalidCreateAttrs() async {
        let url = "http://127.0.0.1:9/rs"
        let badPriority = await CLIParityNetworkReference.wadoUPSCreate(
            baseURL: url, token: "", label: "CT Scan", patientName: "", patientID: "", attrs: ["priority": "BOGUS"])
        XCTAssertFalse(badPriority.createOK, "invalid priority must fail the create (mirrors the CLI throw)")
        XCTAssertEqual(badPriority.operation, "create")

        let badSex = await CLIParityNetworkReference.wadoUPSCreate(
            baseURL: url, token: "", label: "CT Scan", patientName: "", patientID: "", attrs: ["patient-sex": "X"])
        XCTAssertFalse(badSex.createOK, "invalid patient-sex must fail the create")

        let badDate = await CLIParityNetworkReference.wadoUPSCreate(
            baseURL: url, token: "", label: "CT Scan", patientName: "", patientID: "", attrs: ["scheduled-start": "not-a-date"])
        XCTAssertFalse(badDate.createOK, "unparseable scheduled-start must fail the create")
    }

    /// A NON-empty invalid --filter-state makes the CLI throw; the reference must fail the
    /// search rather than silently issue an unfiltered query (returns at the guard, no network).
    func testReferenceFailsInvalidFilterState() async {
        let bad = await CLIParityNetworkReference.wadoUPSSearch(
            baseURL: "http://127.0.0.1:9/rs", token: "", filterState: "BOGUS")
        XCTAssertFalse(bad.success, "invalid filter-state must fail the search (mirrors the CLI throw)")
        XCTAssertEqual(bad.count, 0)
    }

    // MARK: Group C — UPS state machine (COMPLETED/CANCELED) / URI png+gif / verbose / token

    /// The full state-machine rows (create → claim → COMPLETED, and → CANCELED) are generated
    /// only with a Procedure Step Label, route through the ups-lifecycle runner, and carry the
    /// target terminal state in `ups-final` (the claim-only row stays at IN_PROGRESS).
    func testUPSLifecycleStateMachineScenarios() {
        let bare = CLIParityNetworkScenarios.wadoUPSScenarios(scope: WADOScope()).map { $0.scenarioId }
        for id in ["ups-lifecycle-complete", "ups-lifecycle-cancel"] {
            XCTAssertFalse(bare.contains("dicom-wado_net_\(id)"), "\(id) must be gated on a label")
        }

        var scope = WADOScope()
        scope.upsLabel = "CT Scan"; scope.upsAET = "STUDIO_SCU"
        let ups = CLIParityNetworkScenarios.wadoUPSScenarios(scope: scope)

        // Claim-only row defaults to IN_PROGRESS.
        let claim = ups.first { $0.scenarioId == "dicom-wado_net_ups-lifecycle" }
        XCTAssertEqual(claim?.studioParams["wado-mode"], "ups-lifecycle")
        XCTAssertEqual(claim?.studioParams["ups-final"], "IN_PROGRESS")

        let complete = ups.first { $0.scenarioId == "dicom-wado_net_ups-lifecycle-complete" }
        XCTAssertEqual(complete?.studioParams["wado-mode"], "ups-lifecycle")
        XCTAssertEqual(complete?.studioParams["ups-final"], "COMPLETED")
        // The argv is still the create-workitem command (the runner chains claim + terminal step).
        XCTAssertTrue(complete?.cliArgs.contains("--create-workitem") ?? false)

        let cancel = ups.first { $0.scenarioId == "dicom-wado_net_ups-lifecycle-cancel" }
        XCTAssertEqual(cancel?.studioParams["ups-final"], "CANCELED")
        XCTAssertTrue(cancel?.cliArgs.contains("--create-workitem") ?? false)
    }

    /// The lifecycle `success` requires the requested terminal state to have been REACHED:
    /// a claim that holds but a rejected completion scores as NOT successful (so both sides
    /// failing the terminal step becomes failureAgreement, never a false success). The
    /// claim-only behaviour is unchanged (finalState "IN PROGRESS" ⟺ claim succeeded).
    func testLifecycleSuccessRequiresTerminalReached() {
        // Reached terminal → success.
        XCTAssertTrue(C.lifecycleRecord(createOK: true, claimOK: true, finalState: "COMPLETED").overallOK)
        XCTAssertTrue(C.lifecycleRecord(createOK: true, claimOK: true, finalState: "CANCELED").overallOK)
        XCTAssertTrue(C.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS").overallOK)
        // Claim held but terminal transition rejected (finalState "") → NOT success.
        XCTAssertFalse(C.lifecycleRecord(createOK: true, claimOK: true, finalState: "").overallOK)
        // Claim failed and create failed → NOT success (unchanged).
        XCTAssertFalse(C.lifecycleRecord(createOK: true, claimOK: false, finalState: "").overallOK)
        XCTAssertFalse(C.lifecycleRecord(createOK: false, claimOK: false, finalState: "").overallOK)
    }

    /// The terminal state is part of the compared canonical: COMPLETED, CANCELED and
    /// IN PROGRESS are all distinct, but two sides that BOTH fail the terminal step the same
    /// way (finalState "") still hold parity (failureAgreement).
    func testLifecycleCompareDistinguishesTerminalState() {
        let completed = C.lifecycleRecord(createOK: true, claimOK: true, finalState: "COMPLETED")
        let canceled  = C.lifecycleRecord(createOK: true, claimOK: true, finalState: "CANCELED")
        let claimed   = C.lifecycleRecord(createOK: true, claimOK: true, finalState: "IN PROGRESS")
        XCTAssertTrue(C.compareUPS(reference: completed, cli: completed).match)
        XCTAssertFalse(C.compareUPS(reference: completed, cli: canceled).match)
        XCTAssertFalse(C.compareUPS(reference: completed, cli: claimed).match)
        XCTAssertFalse(C.compareUPS(reference: canceled, cli: claimed).match)
        // Both fail the terminal step identically → parity holds on the failure path.
        let bothFail = C.lifecycleRecord(createOK: true, claimOK: true, finalState: "")
        XCTAssertTrue(C.compareUPS(reference: bothFail, cli: bothFail).match)
        // A real divergence (one completes, one stuck) must DIFFER.
        XCTAssertFalse(C.compareUPS(reference: completed, cli: bothFail).match)
    }

    /// The transcoded WADO-URI representations (image/png, image/gif) are generated only at
    /// the instance level, carry the content-type on both the argv and studioParams, and use
    /// the retrieve-uri runner mode (which compares success only — not byte count).
    func testRetrieveURIPngGifScenarios() {
        // Not generated without a SOP Instance UID.
        let bare = CLIParityNetworkScenarios.wadoRetrieveScenarios(scope: WADOScope()).map { $0.scenarioId }
        for id in ["retrieve-uri-png", "retrieve-uri-gif"] {
            XCTAssertFalse(bare.contains("dicom-wado_net_\(id)"), "\(id) must be gated on an instance UID")
        }

        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.3.4"; scope.instanceUID = "1.2.3.4.5"
        let ret = CLIParityNetworkScenarios.wadoRetrieveScenarios(scope: scope)
        for (id, ct) in [("retrieve-uri-png", "image/png"), ("retrieve-uri-gif", "image/gif")] {
            let sc = ret.first { $0.scenarioId == "dicom-wado_net_\(id)" }
            XCTAssertEqual(sc?.studioParams["wado-mode"], "retrieve-uri", "\(id) must use the URI runner")
            XCTAssertEqual(sc?.studioParams["content-type"], ct)
            if let args = sc?.cliArgs, let i = args.firstIndex(of: "--content-type") {
                XCTAssertEqual(args[i + 1], ct, "\(id) argv content-type must match")
            } else { XCTFail("\(id) must pass --content-type") }
            XCTAssertTrue(sc?.cliArgs.contains("--uri") ?? false, "\(id) must pass --uri")
        }
    }

    /// The --verbose search row proves the flag is accepted and semantically transparent:
    /// it issues the same QIDO-RS search (json) so the matched count stays at parity.
    func testUPSSearchVerboseScenario() {
        let ups = CLIParityNetworkScenarios.wadoUPSScenarios(scope: WADOScope())
        let v = ups.first { $0.scenarioId == "dicom-wado_net_ups-search-verbose" }
        XCTAssertNotNil(v, "ups-search-verbose is always generated (no label needed)")
        XCTAssertEqual(v?.studioParams["wado-mode"], "ups-search")
        XCTAssertEqual(v?.studioParams["format"], "json")
        XCTAssertTrue(v?.cliArgs.contains("--verbose") ?? false, "verbose row must pass --verbose")
        XCTAssertTrue(v?.cliArgs.contains("--search") ?? false)
    }

    /// The bearer token is NEVER embedded in a generated scenario's argv — the runner injects
    /// `--token` only at execution time (so it stays out of the displayed command). Every
    /// dicom-wado scenario must be token-free as generated.
    func testScenariosNeverEmbedToken() {
        var scope = WADOScope()
        scope.query.studyUID = "1.2.3"; scope.query.seriesUID = "1.2.3.4"; scope.instanceUID = "1.2.3.4.5"
        scope.upsLabel = "CT Scan"; scope.upsAET = "STUDIO_SCU"
        scope.upsPatientName = "DOE^JANE"; scope.upsPatientID = "P1"
        for sc in CLIParityNetworkScenarios.wadoScenarios(scope: scope) {
            XCTAssertFalse(sc.cliArgs.contains("--token"),
                           "scenario \(sc.scenarioId) must not embed --token (injected at run time)")
        }
    }

    // MARK: Group C review fixes

    /// The --content-type → WADOURIClient.ContentType mapping is a SINGLE source of truth
    /// shared by the CLI and the reference (uriContentType delegates to it), so the two can
    /// never request different representations for the same argument.
    func testSharedContentTypeFactoryIsSingleSourceOfTruth() {
        typealias CT = WADOURIClient.ContentType
        for raw in ["", "application/dicom", "image/jpeg", "jpeg", "image/png", "png",
                    "image/gif", "gif", "image/jp2", "htj2k", "video/mpeg", "BOGUS"] {
            XCTAssertEqual(CLIParityNetworkReference.uriContentType(raw), CT.fromRequestString(raw),
                           "uriContentType must delegate to the shared factory for \(raw)")
        }
        XCTAssertEqual(CT.fromRequestString("image/png"), .png)
        XCTAssertEqual(CT.fromRequestString("image/gif"), .gif)
        XCTAssertEqual(CT.fromRequestString(nil), .dicom)     // no flag → default
        XCTAssertEqual(CT.fromRequestString("bogus"), .dicom) // unknown → default
    }

    /// parseSearch must survive a `--verbose` preamble whose base URL is an IPv6 literal —
    /// the preamble's '[' (in "http://[::1]:…") must NOT be mistaken for the JSON array start,
    /// otherwise a genuine match flakes to DIFFERS (the count parses as 0).
    func testParseSearchSurvivesIPv6VerbosePreamble() {
        let stdout = """
        DICOMweb Server: http://[::1]:8080/dcm4chee-arc/aets/DCM4CHEE/rs
        Searching worklist items...

        [
          {"workitemUID": "1.2.3"},
          {"workitemUID": "1.2.4"}
        ]
        """
        let s = C.parseSearch(stdout, success: true)
        XCTAssertEqual(s.count, 2, "verbose IPv6 preamble must not corrupt the array slice")
        XCTAssertEqual(s.workitemUIDs, ["1.2.3", "1.2.4"])
        // The non-verbose / non-IPv6 path still parses identically.
        let plain = C.parseSearch("[{\"workitemUID\": \"9.9\"}]", success: true)
        XCTAssertEqual(plain.count, 1)
        XCTAssertEqual(plain.workitemUIDs, ["9.9"])
    }
}
