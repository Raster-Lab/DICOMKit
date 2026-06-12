// CLIParityNetworkScenarios.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Generates the NETWORK-mode scenarios for the CLI Parity screen. Unlike the
// file tools (whose scenarios come from bundled goldens), network scenarios are
// a curated flag-wise matrix run against a USER-SUPPLIED PACS endpoint — the end
// user provides only the connection credentials and the harness sweeps each
// valid dicom-echo flag, running the app and the real CLI against the same live
// server and comparing the outcome semantically (see CLIParityEchoComparator).
//
// Endpoint placeholders are resolved at run time from the screen's editable
// credential fields:
//   HOST · PORT · AET (calling) · CALLED_AET · TIMEOUT

import Foundation

public enum CLIParityNetworkScenarios {

    /// Placeholder tokens the network runner resolves from the endpoint config.
    public static let hostToken = "HOST"
    public static let portToken = "PORT"
    public static let aetToken = "AET"
    public static let calledAETToken = "CALLED_AET"
    public static let timeoutToken = "TIMEOUT"
    /// The dicom-send positional path. The runner resolves it to the user-selected
    /// DICOM directory (CLIParityRunnerViewModel.sendDirectory) when set, otherwise to
    /// the bundled synthetic CT (syn-ct.dcm).
    public static let sendFileToken = "SENDFILE"

    /// Number of requests used by the multi-echo scenarios. Kept small so the
    /// live-server sweep stays quick and light on network traffic.
    private static let multiCount = "3"

    /// Tool ids that have a network-parity implementation today.
    public static let supportedToolIDs: Set<String> = ["dicom-echo", "dicom-query", "dicom-send"]

    /// Builds the scenario list for the selected network tools. `queryFilters`
    /// supplies the user's query keys for dicom-query (ignored by other tools).
    public static func scenarios(toolIDs: Set<String>, queryFilters: QueryFilters = QueryFilters()) -> [BatchScenario] {
        var out: [BatchScenario] = []
        if toolIDs.contains("dicom-echo") { out += echoScenarios() }
        if toolIDs.contains("dicom-query") { out += queryScenarios(filters: queryFilters) }
        if toolIDs.contains("dicom-send") { out += sendScenarios() }
        return out
    }

    // MARK: dicom-echo flag matrix

    /// One scenario per valid dicom-echo flag (and the meaningful combinations),
    /// so parity is verified flag-by-flag.
    static func echoScenarios() -> [BatchScenario] {
        [
            echo("basic",          "echo (default)",            extraArgs: [],                              extraParams: [:]),
            echo("timeout",        "echo --timeout",            extraArgs: ["--timeout", timeoutToken],     extraParams: ["timeout": timeoutToken]),
            echo("verbose",        "echo --verbose",            extraArgs: ["--verbose"],                   extraParams: ["verbose": "true"]),
            echo("count",          "echo --count \(multiCount)",            extraArgs: ["--count", multiCount],          extraParams: ["count": multiCount]),
            echo("count-stats",    "echo --count \(multiCount) --stats",    extraArgs: ["--count", multiCount, "--stats"], extraParams: ["count": multiCount, "stats": "true"]),
            echo("stats",          "echo --stats",              extraArgs: ["--stats"],                     extraParams: ["stats": "true"]),
            echo("count-verbose",  "echo --count \(multiCount) --verbose",  extraArgs: ["--count", multiCount, "--verbose"], extraParams: ["count": multiCount, "verbose": "true"]),
            echo("diagnose",       "echo --diagnose",           extraArgs: ["--diagnose"],                  extraParams: ["diagnose": "true"]),
        ]
    }

    /// Assembles one dicom-echo scenario. Every scenario carries the endpoint
    /// (host/port) plus calling+called AE titles; `extraArgs`/`extraParams` add
    /// the flag(s) under test.
    private static func echo(_ idSuffix: String, _ label: String,
                             extraArgs: [String], extraParams: [String: String]) -> BatchScenario {
        // CLI: positional "HOST" + --port + AE titles, then the flag(s) under test.
        let cliArgs = [hostToken, "--port", portToken,
                       "--aet", aetToken, "--called-aet", calledAETToken] + extraArgs

        // App (Studio): the catalog param map for dicom-echo.
        var studioParams: [String: String] = [
            "host": hostToken, "port": portToken,
            "aet": aetToken, "called-aet": calledAETToken,
        ]
        for (k, v) in extraParams { studioParams[k] = v }

        return BatchScenario(
            scenarioId: "dicom-echo_net_\(idSuffix)",
            toolId: "dicom-echo",
            label: label,
            cliArgs: cliArgs,
            studioParams: studioParams,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "echo-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint")
    }

    // MARK: dicom-query flag/level matrix (driven by user-supplied query keys)

    /// Builds the C-FIND scenarios from the user's query keys: a broad study query,
    /// one study scenario per provided filter (flag-wise), a combined-filter study
    /// query, a patient-level query, and series/instance levels when the matching
    /// UID(s) are supplied. Scenarios whose required input is absent are simply not
    /// generated (so nothing is silently skipped at run time).
    static func queryScenarios(filters f: QueryFilters) -> [BatchScenario] {
        var out: [BatchScenario] = []

        // Broad study-level query (no filters).
        out.append(querySc("study-all", "query study (no filters)", level: "study", apply: QueryFilters()))

        // One study-level scenario per provided filter — flag-wise.
        var perFilter = 0
        func single(_ id: String, _ label: String, _ build: (inout QueryFilters) -> Void) {
            var sub = QueryFilters(); build(&sub)
            out.append(querySc(id, label, level: "study", apply: sub)); perFilter += 1
        }
        if !f.patientName.isEmpty       { single("study-patient-name", "query study --patient-name") { $0.patientName = f.patientName } }
        if !f.patientID.isEmpty         { single("study-patient-id", "query study --patient-id") { $0.patientID = f.patientID } }
        if !f.studyDate.isEmpty         { single("study-date", "query study --study-date") { $0.studyDate = f.studyDate } }
        if !f.modality.isEmpty          { single("study-modality", "query study --modality") { $0.modality = f.modality } }
        if !f.accession.isEmpty         { single("study-accession", "query study --accession-number") { $0.accession = f.accession } }
        if !f.studyDescription.isEmpty  { single("study-desc", "query study --study-description") { $0.studyDescription = f.studyDescription } }

        // Combined filters (only when ≥2 provided, else it duplicates a single scenario).
        if perFilter >= 2 {
            var combined = f; combined.studyUID = ""; combined.seriesUID = ""
            out.append(querySc("study-combined", "query study (all filters)", level: "study", apply: combined))
        }

        // --format coverage (broad study query): json gets full result-set parity via
        // the scenarios above; csv/table/compact are validated by result count (they
        // drop/truncate fields, so full parity isn't meaningful for them).
        for fmt in ["csv", "table", "compact"] {
            out.append(querySc("study-format-\(fmt)", "query study --format \(fmt)", level: "study", apply: QueryFilters(), format: fmt))
        }

        // Patient level (carries patient filters if provided).
        var patientF = QueryFilters(); patientF.patientName = f.patientName; patientF.patientID = f.patientID
        out.append(querySc("patient", "query patient", level: "patient", apply: patientF))

        // Series / instance levels — ALWAYS shown so they're never silently missing;
        // the runner skips each with guidance when the scoping UID(s) aren't supplied.
        var seriesF = QueryFilters(); seriesF.studyUID = f.studyUID
        out.append(querySc("series", "query series (--study-uid)", level: "series", apply: seriesF))
        var instF = QueryFilters(); instF.studyUID = f.studyUID; instF.seriesUID = f.seriesUID
        out.append(querySc("instance", "query instance (--study-uid --series-uid)", level: "instance", apply: instF))
        return out
    }

    /// Assembles one dicom-query scenario. Endpoint stays tokenised (resolved at run
    /// time); the query-key VALUES are concrete (known when the scenario is built).
    /// The CLI is always run with `--format json` for robust, order-independent parsing.
    private static func querySc(_ idSuffix: String, _ label: String, level: String,
                                apply f: QueryFilters, format: String = "json") -> BatchScenario {
        var cli = [hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken, "--level", level]
        var sp: [String: String] = ["level": level, "timeout": timeoutToken, "format": format]
        func add(_ flag: String, _ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            cli += [flag, value]; sp[key] = value
        }
        add("--patient-name", "patient-name", f.patientName)
        add("--patient-id", "patient-id", f.patientID)
        add("--study-date", "study-date", f.studyDate)
        add("--modality", "modality", f.modality)
        add("--accession-number", "accession", f.accession)
        add("--study-description", "study-description", f.studyDescription)
        add("--study-uid", "study-uid", f.studyUID)
        add("--series-uid", "series-uid", f.seriesUID)
        cli += ["--timeout", timeoutToken, "--format", format]
        return BatchScenario(
            scenarioId: "dicom-query_net_\(idSuffix)",
            toolId: "dicom-query",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "query-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + query keys")
    }

    // MARK: dicom-send flag matrix (sends a bundled synthetic CT — writes to the PACS)

    /// C-STORE scenarios. The user supplies the endpoint and, optionally, a DICOM
    /// directory to send (otherwise the bundled synthetic CT, syn-ct.dcm). Includes a
    /// no-write --dry-run plus real sends across the priority/transfer-syntax/verify
    /// flags. Every scenario passes `--recursive` so a picked directory is scanned in
    /// full; it's a harmless no-op for the single bundled file. NOTE: the real-send
    /// rows persist the sent instance(s) on the server (deduplicated on repeats).
    static func sendScenarios() -> [BatchScenario] {
        [
            sendSc("dry-run",       "send --dry-run",                      flags: ["--dry-run"],                          params: ["dry-run": "true"]),
            sendSc("default",       "send (default)",                      flags: [],                                     params: [:]),
            sendSc("priority-high", "send --priority high",                flags: ["--priority", "high"],                 params: ["priority": "high"]),
            sendSc("ts-evle",       "send --transfer-syntax explicit-vr-le", flags: ["--transfer-syntax", "explicit-vr-le"], params: ["transfer-syntax": "explicit-vr-le"]),
            sendSc("verify",        "send --verify",                       flags: ["--verify"],                           params: ["verify": "true"]),
        ]
    }

    private static func sendSc(_ idSuffix: String, _ label: String,
                               flags: [String], params: [String: String]) -> BatchScenario {
        // dicom-send: positional host, then the file/dir path, then options. --recursive
        // lets a user-picked directory be scanned in full (no-op for the bundled file).
        let cli = [hostToken, sendFileToken, "--port", portToken,
                   "--aet", aetToken, "--called-aet", calledAETToken, "--timeout", timeoutToken, "--recursive"] + flags
        var sp: [String: String] = ["timeout": timeoutToken]
        for (k, v) in params { sp[k] = v }
        return BatchScenario(
            scenarioId: "dicom-send_net_\(idSuffix)",
            toolId: "dicom-send",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "send-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint (sends a picked DICOM directory, or a synthetic CT)")
    }
}
