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
    /// DICOM file or directory (CLIParityRunnerViewModel.sendInputPath) when set,
    /// otherwise to the bundled synthetic CT (syn-ct.dcm).
    public static let sendFileToken = "SENDFILE"

    /// The dicom-retrieve `--output` directory. The runner resolves it to a fresh
    /// per-scenario scratch dir where the CLI writes its retrieved (C-GET) files; the
    /// package-API reference counts instances in memory and never writes there. The
    /// dicom-wado WADO-RS retrieve scenarios reuse it for their `--output` dir.
    public static let outDirToken = "OUTDIR"

    /// The dicom-wado DICOMweb base URL (HTTP/S). The runner resolves it from the
    /// network endpoint's editable "DICOMweb Base URL" field — the four `dicom-wado`
    /// subcommands all hit it.
    public static let webURLToken = "WEBURL"

    /// WADO-URI variant of the DICOMweb base URL. The runner resolves it by applying
    /// `WADOURIClient.resolveURIEndpoint` to `networkWebBaseURL` — so a dcm4chee5 `/rs`
    /// base becomes `.../wado` (the correct WADO-URI servlet), while dcm4chee2's root
    /// `/wado` is returned unchanged. Used exclusively by WADO-URI (`--uri`) scenarios
    /// so the displayed CLI command and the reference both show the explicit `/wado` URL.
    public static let webWADOURIURLToken = "WEBURIURL"

    /// Number of requests used by the multi-echo scenarios. Kept small so the
    /// live-server sweep stays quick and light on network traffic.
    private static let multiCount = "3"

    /// Tool ids that have a network-parity implementation today. `dicom-wado` is the
    /// single real DICOMweb binary; its QIDO/WADO/STOW/UPS subcommands are swept as
    /// scenarios (the Studio catalog's dicom-qido / dicom-stow / dicom-ups aliases are
    /// NOT separate binaries, so they don't appear here — the runner collapses them).
    public static let supportedToolIDs: Set<String> = [
        "dicom-echo", "dicom-query", "dicom-send", "dicom-retrieve", "dicom-qr",
        "dicom-mwl", "dicom-mpps", "dicom-wado",
    ]

    /// Builds the scenario list for the selected network tools. `queryFilters`
    /// supplies the user's query keys for dicom-query / dicom-qr; `retrieveScope`
    /// supplies dicom-retrieve's UIDs + move destination; `worklistFilters` supplies
    /// dicom-mwl's worklist filters; `mppsScope` supplies dicom-mpps's lifecycle
    /// inputs (each ignored by the others).
    public static func scenarios(toolIDs: Set<String>, queryFilters: QueryFilters = QueryFilters(),
                                 retrieveScope: RetrieveScope = RetrieveScope(),
                                 worklistFilters: WorklistFilters = WorklistFilters(),
                                 mppsScope: MPPSScope = MPPSScope(),
                                 wadoScope: WADOScope = WADOScope(),
                                 qrMoveDest: String = "") -> [BatchScenario] {
        var out: [BatchScenario] = []
        if toolIDs.contains("dicom-echo") { out += echoScenarios() }
        if toolIDs.contains("dicom-query") { out += queryScenarios(filters: queryFilters) }
        if toolIDs.contains("dicom-send") { out += sendScenarios() }
        if toolIDs.contains("dicom-retrieve") { out += retrieveScenarios(scope: retrieveScope) }
        if toolIDs.contains("dicom-qr") { out += qrScenarios(filters: queryFilters, moveDest: qrMoveDest) }
        if toolIDs.contains("dicom-mwl") { out += mwlScenarios(filters: worklistFilters) }
        if toolIDs.contains("dicom-mpps") { out += mppsScenarios(scope: mppsScope) }
        if toolIDs.contains("dicom-wado") { out += wadoScenarios(scope: wadoScope) }
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

        // --verbose: proves the flag is accepted and the stdout result is unaffected
        // (verbose output goes to stderr only; the parity comparator ignores stderr).
        out.append(querySc("study-all-verbose", "query study --verbose", level: "study", apply: QueryFilters(), verbose: true))

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
                                apply f: QueryFilters, format: String = "json",
                                verbose: Bool = false) -> BatchScenario {
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
        if verbose { cli += ["--verbose"]; sp["verbose"] = "true" }
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

    /// C-STORE scenarios. The user supplies the endpoint and, optionally, a DICOM file
    /// or directory to send (otherwise the bundled synthetic CT, syn-ct.dcm). Includes a
    /// no-write --dry-run plus real sends across the priority/verify flags. Every
    /// scenario passes `--recursive` so a picked directory is scanned in full; it's a
    /// harmless no-op for a single file. NOTE: the real-send rows persist the sent
    /// instance(s) on the server (deduplicated on repeats).
    static func sendScenarios() -> [BatchScenario] {
        [
            sendSc("dry-run",          "send --dry-run",           flags: ["--dry-run"],               params: ["dry-run": "true"]),
            sendSc("default",          "send (default)",           flags: [],                          params: [:]),
            sendSc("priority-high",    "send --priority high",     flags: ["--priority", "high"],      params: ["priority": "high"]),
            sendSc("priority-medium",  "send --priority medium",   flags: ["--priority", "medium"],    params: ["priority": "medium"]),
            sendSc("priority-low",     "send --priority low",      flags: ["--priority", "low"],       params: ["priority": "low"]),
            sendSc("verify",           "send --verify",            flags: ["--verify"],                params: ["verify": "true"]),
            sendSc("verbose",          "send --verbose",           flags: ["--verbose"],               params: ["verbose": "true"]),
            sendSc("retry",            "send --retry 1",           flags: ["--retry", "1"],            params: ["retry": "1"]),
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
            inputHint: "PACS endpoint (sends a picked DICOM file/directory, or a synthetic CT)")
    }

    // MARK: dicom-retrieve flag/level matrix (PULLS instances — C-MOVE / C-GET)

    /// C-MOVE / C-GET scenarios driven by the user-supplied retrieve scope. The
    /// study-level rows are ALWAYS generated (skipped at run time with guidance when
    /// no Study UID is supplied); series/instance rows appear once the matching UID is
    /// given. Every scenario passes `--verbose` because dicom-retrieve prints its
    /// result block only when verbose (or the op failed) — without it a successful
    /// retrieve emits nothing to compare. C-MOVE rows are skipped at run time when no
    /// Move Destination AE is supplied. NOTE: real retrieves move/copy instances —
    /// C-GET writes them to a scratch dir (cleaned up); C-MOVE forwards them to the
    /// destination AE.
    static func retrieveScenarios(scope: RetrieveScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        // Study level — always shown.
        out.append(retrieveSc("get-study", "retrieve c-get study", method: "c-get", level: "study", scope: scope))
        out.append(retrieveSc("move-study", "retrieve c-move study", method: "c-move", level: "study", scope: scope))
        // --hierarchical: organise output as patient/study/series. C-GET only (files
        // are written to disk); the reference counts instances in memory so the
        // comparison is on success+count, not file layout. C-MOVE forwards to the
        // destination AE and never writes locally, so --hierarchical is a no-op there.
        out.append(retrieveSc("get-study-hierarchical", "retrieve c-get study --hierarchical",
                              method: "c-get", level: "study", scope: scope, hierarchical: true))
        // Series level — only when a Series UID is supplied.
        if !scope.seriesUID.isEmpty {
            out.append(retrieveSc("get-series", "retrieve c-get series", method: "c-get", level: "series", scope: scope))
            out.append(retrieveSc("move-series", "retrieve c-move series", method: "c-move", level: "series", scope: scope))
        }
        // Instance level — only when a SOP Instance UID is supplied.
        if !scope.instanceUID.isEmpty {
            out.append(retrieveSc("get-instance", "retrieve c-get instance", method: "c-get", level: "instance", scope: scope))
            out.append(retrieveSc("move-instance", "retrieve c-move instance", method: "c-move", level: "instance", scope: scope))
        }
        return out
    }

    /// Assembles one dicom-retrieve scenario. The endpoint stays tokenised; the
    /// retrieve UIDs + move destination are concrete (known when the scenario is built).
    /// `--output` is tokenised (OUTDIR) to the user-selected output directory, or a
    /// per-scenario scratch dir, resolved by the runner. The user-selected transfer
    /// syntax (`scope.transferSyntax`, a UID) is requested by the C-GET scenarios; for
    /// C-MOVE it's advisory and dicom-retrieve ignores it, so it isn't passed there.
    private static func retrieveSc(_ idSuffix: String, _ label: String, method: String, level: String,
                                   scope: RetrieveScope, hierarchical: Bool = false) -> BatchScenario {
        let ts = method == "c-get" ? scope.transferSyntax : ""

        var cli = [hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken,
                   "--study-uid", scope.studyUID]
        if level == "series" || level == "instance" { cli += ["--series-uid", scope.seriesUID] }
        if level == "instance" { cli += ["--instance-uid", scope.instanceUID] }
        cli += ["--method", method]
        if method == "c-move" { cli += ["--move-dest", scope.moveDest] }
        cli += ["--output", outDirToken, "--timeout", timeoutToken, "--verbose"]
        if !ts.isEmpty { cli += ["--transfer-syntax", ts] }
        if hierarchical { cli += ["--hierarchical"] }

        var sp: [String: String] = [
            "method": method, "level": level, "timeout": timeoutToken,
            "study-uid": scope.studyUID, "series-uid": scope.seriesUID,
            "instance-uid": scope.instanceUID, "move-dest": scope.moveDest,
        ]
        if !ts.isEmpty { sp["transfer-syntax"] = ts }

        return BatchScenario(
            scenarioId: "dicom-retrieve_net_\(idSuffix)",
            toolId: "dicom-retrieve",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "retrieve-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + retrieve scope")
    }

    // MARK: dicom-qr matrix (read-only review C-FIND + interactive select-all retrieve)

    /// dicom-qr scenarios for the integrated query-retrieve tool:
    ///   • a read-only `--review` C-FIND sweep — a broad query, one scenario per supplied
    ///     filter (flag-wise), and a combined query when ≥2 filters are given (`--method
    ///     c-get` so the tool never demands a `--move-dest` it doesn't use in review);
    ///   • two `--interactive` retrieve rows that exercise the FULL query→select→retrieve
    ///     flow: the harness auto-answers the study-selection prompt with "all" (fed to
    ///     the CLI's stdin and replicated by the reference), then dicom-qr retrieves every
    ///     matched study — one row for C-GET (pulls files), one for C-MOVE (forwards them
    ///     to the Move Destination AE). The interactive rows are ALWAYS generated so
    ///     they're visible; the runner skips them when no Query Key is supplied (so a
    ///     broad "all" never moves the whole PACS) and C-MOVE additionally needs a
    ///     Move Destination AE.
    static func qrScenarios(filters f: QueryFilters, moveDest: String = "") -> [BatchScenario] {
        var out: [BatchScenario] = []
        out.append(qrSc("review-all", "qr review (no filters)", apply: QueryFilters()))

        var perFilter = 0
        func single(_ id: String, _ label: String, _ build: (inout QueryFilters) -> Void) {
            var sub = QueryFilters(); build(&sub)
            out.append(qrSc(id, label, apply: sub)); perFilter += 1
        }
        if !f.patientName.isEmpty      { single("review-patient-name", "qr review --patient-name") { $0.patientName = f.patientName } }
        if !f.patientID.isEmpty        { single("review-patient-id", "qr review --patient-id") { $0.patientID = f.patientID } }
        if !f.studyDate.isEmpty        { single("review-date", "qr review --study-date") { $0.studyDate = f.studyDate } }
        if !f.modality.isEmpty         { single("review-modality", "qr review --modality") { $0.modality = f.modality } }
        if !f.accession.isEmpty        { single("review-accession", "qr review --accession-number") { $0.accession = f.accession } }
        if !f.studyDescription.isEmpty { single("review-desc", "qr review --study-description") { $0.studyDescription = f.studyDescription } }
        if !f.studyUID.isEmpty         { single("review-study-uid", "qr review --study-uid") { $0.studyUID = f.studyUID } }

        // Combined filters (only when ≥2 provided, else it duplicates a single scenario).
        if perFilter >= 2 {
            var combined = f; combined.seriesUID = ""
            out.append(qrSc("review-combined", "qr review (all filters)", apply: combined))
        }

        // --verbose: proves the flag is accepted; the QR comparator searches for
        // "Found N studies" and "UID:" by pattern, so the extra verbose preamble and
        // raw attribute dump (print() to stdout) are harmless — they don't match those
        // patterns and never produce spurious UID lines.
        out.append(qrSc("review-all-verbose", "qr review --verbose", apply: QueryFilters(), verbose: true))

        // Interactive select-all retrieve — bound by the user's filters (a row, like the
        // combined review, that carries every supplied key so the matched/retrieved set
        // is the same scope). C-GET first (pulls to a scratch dir), then C-MOVE (forwards).
        var scoped = f; scoped.seriesUID = ""
        out.append(qrInteractiveSc("interactive-cget", "qr interactive c-get (select all)",
                                   method: "c-get", apply: scoped))
        out.append(qrInteractiveSc("interactive-cmove", "qr interactive c-move (select all)",
                                   method: "c-move", apply: scoped, moveDest: moveDest))

        // --hierarchical: organise C-GET output as patient/study/series. Only applicable
        // to C-GET (files written to disk); the reference counts in memory so the
        // retrieval totals are the comparator, not the file layout.
        out.append(qrInteractiveSc("interactive-cget-hierarchical",
                                   "qr interactive c-get --hierarchical (select all)",
                                   method: "c-get", apply: scoped, hierarchical: true))

        // --auto: retrieves ALL matched studies automatically, without prompting (unlike
        // --interactive which prompts and is answered "all"). Functionally equivalent
        // outcome — the runner uses the same qrInteractive reference but does NOT pipe
        // stdin (the tool never reaches a prompt).
        out.append(qrAutoSc("auto-cget", "qr auto c-get (retrieve all)",
                            method: "c-get", apply: scoped))
        out.append(qrAutoSc("auto-cmove", "qr auto c-move (retrieve all)",
                            method: "c-move", apply: scoped, moveDest: moveDest))
        return out
    }

    /// Assembles one dicom-qr review scenario. Endpoint stays tokenised; the query-key
    /// VALUES are concrete. `query` is the explicit subcommand; `--review` runs the
    /// C-FIND only (no retrieve), and `--method c-get` avoids the C-MOVE move-dest check.
    private static func qrSc(_ idSuffix: String, _ label: String, apply f: QueryFilters,
                              verbose: Bool = false) -> BatchScenario {
        var cli = ["query", hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken,
                   "--review", "--method", "c-get"]
        var sp: [String: String] = ["timeout": timeoutToken, "qr-mode": "review"]
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
        cli += ["--timeout", timeoutToken]
        if verbose { cli += ["--verbose"]; sp["verbose"] = "true" }
        return BatchScenario(
            scenarioId: "dicom-qr_net_\(idSuffix)",
            toolId: "dicom-qr",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "qr-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + query keys (review)")
    }

    /// Assembles one dicom-qr INTERACTIVE scenario. `query … --interactive --method
    /// <c-get|c-move>` runs the full query→select→retrieve flow; the runner feeds the
    /// auto-answer "all" to the CLI's stdin (via `stdin`) and the SDK reference replicates
    /// it (`qr-mode` = interactive-get / interactive-move). C-MOVE carries `--move-dest`
    /// (concrete); C-GET writes to the OUTDIR scratch dir. The study-key VALUES are
    /// concrete; the endpoint stays tokenised.
    private static func qrInteractiveSc(_ idSuffix: String, _ label: String, method: String,
                                        apply f: QueryFilters, moveDest: String = "",
                                        hierarchical: Bool = false) -> BatchScenario {
        var cli = ["query", hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken,
                   "--interactive", "--method", method]
        if method == "c-move" { cli += ["--move-dest", moveDest] }
        if method == "c-get"  { cli += ["--output", outDirToken] }
        if hierarchical && method == "c-get" { cli += ["--hierarchical"] }
        var sp: [String: String] = [
            "timeout": timeoutToken,
            "qr-mode": method == "c-move" ? "interactive-move" : "interactive-get",
            "method": method,
            "move-dest": moveDest,
            "stdin": "all",   // auto-answer the study-selection prompt
        ]
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
        cli += ["--timeout", timeoutToken]
        return BatchScenario(
            scenarioId: "dicom-qr_net_\(idSuffix)",
            toolId: "dicom-qr",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "qr-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + query keys + Move Destination AE (interactive)")
    }

    /// Assembles one dicom-qr AUTO scenario. `query … --auto --method <c-get|c-move>`
    /// retrieves ALL matched studies without prompting. Unlike interactive mode, no stdin
    /// is fed to the CLI (the tool never waits for input). The reference is identical to
    /// interactive (`qrInteractive`) — query + retrieve all. The runner guards this mode
    /// the same way as interactive: a filter must bound the match set, and C-MOVE needs
    /// a Move Destination AE.
    private static func qrAutoSc(_ idSuffix: String, _ label: String, method: String,
                                  apply f: QueryFilters, moveDest: String = "") -> BatchScenario {
        var cli = ["query", hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken,
                   "--auto", "--method", method]
        if method == "c-move" { cli += ["--move-dest", moveDest] }
        if method == "c-get"  { cli += ["--output", outDirToken] }
        var sp: [String: String] = [
            "timeout": timeoutToken,
            "qr-mode": method == "c-move" ? "auto-move" : "auto-get",
            "method": method,
            "move-dest": moveDest,
            // No "stdin" key — auto mode retrieves without prompting.
        ]
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
        cli += ["--timeout", timeoutToken]
        return BatchScenario(
            scenarioId: "dicom-qr_net_\(idSuffix)",
            toolId: "dicom-qr",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "qr-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + query keys + Move Destination AE (auto)")
    }

    // MARK: dicom-mwl worklist matrix (read-only Modality Worklist C-FIND)

    /// Builds the worklist C-FIND scenarios from the user's worklist filters: a broad
    /// query (no filters), one scenario per supplied filter (flag-wise), and a combined
    /// query when ≥2 filters are given — mirroring the dicom-query study sweep. Every
    /// scenario runs `--json` so the matched items parse robustly and order-independently.
    static func mwlScenarios(filters f: WorklistFilters) -> [BatchScenario] {
        var out: [BatchScenario] = []
        out.append(mwlSc("all", "mwl query (no filters)", apply: WorklistFilters()))

        var perFilter = 0
        func single(_ id: String, _ label: String, _ build: (inout WorklistFilters) -> Void) {
            var sub = WorklistFilters(); build(&sub)
            out.append(mwlSc(id, label, apply: sub)); perFilter += 1
        }
        if !f.date.isEmpty        { single("date", "mwl query --date") { $0.date = f.date } }
        if !f.station.isEmpty     { single("station", "mwl query --station") { $0.station = f.station } }
        if !f.patientName.isEmpty { single("patient-name", "mwl query --patient") { $0.patientName = f.patientName } }
        if !f.patientID.isEmpty   { single("patient-id", "mwl query --patient-id") { $0.patientID = f.patientID } }
        if !f.modality.isEmpty    { single("modality", "mwl query --modality") { $0.modality = f.modality } }
        if !f.spsStatus.isEmpty   { single("sps-status", "mwl query --sps-status") { $0.spsStatus = f.spsStatus } }
        if !f.accession.isEmpty   { single("accession", "mwl query --accession-number") { $0.accession = f.accession } }

        // Combined filters (only when ≥2 provided, else it duplicates a single scenario).
        if perFilter >= 2 {
            out.append(mwlSc("combined", "mwl query (all filters)", apply: f))
        }

        // --verbose: proves the flag is accepted. Every MWL scenario also passes --json,
        // and the shared verbose header is gated on `!json`, so it is suppressed and the
        // JSON stdout is unaffected. (The MWL comparator also slices stdout to the first
        // '[' … last ']', so any stray chrome would be harmless regardless.)
        out.append(mwlSc("verbose", "mwl query --verbose", apply: WorklistFilters(), verbose: true))
        return out
    }

    /// Assembles one dicom-mwl scenario. Endpoint stays tokenised; the filter VALUES
    /// are concrete. `query` is the explicit subcommand; `--json` makes the per-item
    /// output parse robustly. The filter values are also stored in studioParams so the
    /// runner builds the IDENTICAL package-API query keys for the reference side.
    private static func mwlSc(_ idSuffix: String, _ label: String, apply f: WorklistFilters,
                               verbose: Bool = false) -> BatchScenario {
        var cli = ["query", hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken]
        var sp: [String: String] = ["timeout": timeoutToken]
        func add(_ flag: String, _ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            cli += [flag, value]; sp[key] = value
        }
        add("--date", "date", f.date)
        add("--station", "station", f.station)
        add("--patient", "patient-name", f.patientName)
        add("--patient-id", "patient-id", f.patientID)
        add("--modality", "modality", f.modality)
        add("--sps-status", "sps-status", f.spsStatus)
        add("--accession-number", "accession", f.accession)
        cli += ["--timeout", timeoutToken, "--json"]
        if verbose { cli += ["--verbose"]; sp["verbose"] = "true" }
        return BatchScenario(
            scenarioId: "dicom-mwl_net_\(idSuffix)",
            toolId: "dicom-mwl",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "mwl-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + worklist filters")
    }

    // MARK: dicom-mpps lifecycle matrix (WRITES — N-CREATE / N-SET)

    /// Builds the MPPS lifecycle scenarios driven by the user-supplied MPPS scope. The
    /// study-level rows are ALWAYS generated (skipped at run time with guidance when no
    /// Study UID is supplied): a create-only (N-CREATE, stays IN PROGRESS), a
    /// create→complete lifecycle, and a create→discontinue lifecycle. A
    /// create→complete-with-referenced-images row is added once a Series UID + image
    /// UID(s) are supplied. NOTE: every row WRITES to the server — each mints an
    /// independent MPPS instance (the reference and the CLI use different client-minted
    /// UIDs by design).
    static func mppsScenarios(scope: MPPSScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        out.append(mppsSc("create-in-progress", "mpps create (N-CREATE · IN PROGRESS)",
                          lifecycle: false, finalStatus: "", scope: scope))
        out.append(mppsSc("lifecycle-completed", "mpps create → update COMPLETED (N-CREATE → N-SET)",
                          lifecycle: true, finalStatus: "COMPLETED", scope: scope))
        out.append(mppsSc("lifecycle-discontinued", "mpps create → update DISCONTINUED (N-CREATE → N-SET)",
                          lifecycle: true, finalStatus: "DISCONTINUED", scope: scope))
        // Referenced-image completion — only when a Series UID and image UID(s) exist.
        if !scope.seriesUID.isEmpty && !scope.imageUIDs.isEmpty {
            out.append(mppsSc("lifecycle-completed-images", "mpps create → update COMPLETED + referenced images (N-CREATE → N-SET)",
                              lifecycle: true, finalStatus: "COMPLETED", scope: scope, withImages: true))
        }
        // --verbose on create: proves the flag is accepted. The verbose header now
        // prints to STDOUT via the shared NetworkConsole formatter, and the
        // "MPPS Instance UID:" result marker (also STDOUT) is parsed from the combined
        // stream, so the marker remains unaffected. The runner also threads --verbose
        // into the update command when
        // sp["verbose"] == "true" (lifecycle rows carry it too, but create-only is
        // cheapest to exercise the flag).
        out.append(mppsSc("create-in-progress-verbose", "mpps create (N-CREATE · IN PROGRESS) --verbose",
                          lifecycle: false, finalStatus: "", scope: scope, verbose: true))
        return out
    }

    /// Assembles one dicom-mpps scenario. `cliArgs` is the N-CREATE command (subcommand
    /// `create` first, like dicom-qr's `query`); the runner runs it, parses the minted
    /// MPPS UID, and — for a lifecycle row — builds + runs the matching `update`
    /// command itself (the UID is only known at run time). studioParams carries the
    /// lifecycle flag, the final status, and the scope so the package-API reference
    /// drives the identical create→update.
    private static func mppsSc(_ idSuffix: String, _ label: String, lifecycle: Bool, finalStatus: String,
                               scope: MPPSScope, withImages: Bool = false, verbose: Bool = false) -> BatchScenario {
        // N-CREATE argv. The create always starts the step IN PROGRESS; a lifecycle row
        // then transitions it via N-SET. Study UID + endpoint are required; the optional
        // attributes are added only when present.
        var cli = ["create", hostToken, "--port", portToken, "--aet", aetToken,
                   "--called-aet", calledAETToken, "--study-uid", scope.studyUID,
                   "--status", "IN PROGRESS"]
        if !scope.patientName.isEmpty { cli += ["--patient-name", scope.patientName] }
        if !scope.patientID.isEmpty   { cli += ["--patient-id", scope.patientID] }
        if !scope.accession.isEmpty   { cli += ["--accession-number", scope.accession] }
        if !scope.spsID.isEmpty       { cli += ["--sps-id", scope.spsID] }
        cli += ["--timeout", timeoutToken]
        var sp: [String: String] = [
            "operation": lifecycle ? "lifecycle" : "create",
            "final-status": finalStatus,
            "timeout": timeoutToken,
            "study-uid": scope.studyUID,
            "patient-name": scope.patientName,
            "patient-id": scope.patientID,
            "accession": scope.accession,
            "sps-id": scope.spsID,
        ]
        // Referenced images flow to the N-SET only for the with-images lifecycle row.
        if withImages {
            sp["series-uid"] = scope.seriesUID
            sp["image-uids"] = scope.imageUIDs.joined(separator: ",")
        }
        if verbose { sp["verbose"] = "true" }

        return BatchScenario(
            scenarioId: "dicom-mpps_net_\(idSuffix)",
            toolId: "dicom-mpps",
            label: label,
            cliArgs: cli,
            studioParams: sp,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "mpps-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint + MPPS scope")
    }

    // MARK: dicom-wado matrix (DICOMweb — QIDO-RS / WADO-RS / STOW-RS / UPS-RS subcommands)

    /// Builds the dicom-wado scenarios across its four subcommands. Unlike the DIMSE
    /// tools (each its own binary), these are subcommands of the single `dicom-wado`
    /// binary, so every scenario's argv begins with the subcommand (`query` /
    /// `retrieve` / `store` / `ups`), exactly like dicom-qr's `query` and dicom-mpps's
    /// `create`. The QIDO query keys come from the shared Query Keys; the retrieve
    /// scope and UPS lifecycle inputs come from the dicom-wado scope.
    static func wadoScenarios(scope: WADOScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        // Only generate the selected subcommand's scenarios (empty = all four), so the
        // sweep runs exactly the subcommand the user picked in the WADO panel.
        let only = scope.subcommand
        if only.isEmpty || only == "query"    { out += wadoQueryScenarios(filters: scope.query) }
        if only.isEmpty || only == "retrieve" { out += wadoRetrieveScenarios(scope: scope) }
        if only.isEmpty || only == "store"    { out += wadoStoreScenarios(studyUID: scope.query.studyUID) }
        if only.isEmpty || only == "ups"      { out += wadoUPSScenarios(scope: scope) }
        return out
    }

    // dicom-wado query (QIDO-RS) — read-only, mirrors the dicom-query study sweep.
    static func wadoQueryScenarios(filters f: QueryFilters) -> [BatchScenario] {
        var out: [BatchScenario] = []
        out.append(wadoQuerySc("query-study-all", "wado query study (no filters)", level: "study", apply: QueryFilters()))

        var perFilter = 0
        func single(_ id: String, _ label: String, _ build: (inout QueryFilters) -> Void) {
            var sub = QueryFilters(); build(&sub)
            out.append(wadoQuerySc(id, label, level: "study", apply: sub)); perFilter += 1
        }
        if !f.patientName.isEmpty      { single("query-patient-name", "wado query study --patient-name") { $0.patientName = f.patientName } }
        if !f.patientID.isEmpty        { single("query-patient-id", "wado query study --patient-id") { $0.patientID = f.patientID } }
        if !f.studyDate.isEmpty        { single("query-study-date", "wado query study --study-date") { $0.studyDate = f.studyDate } }
        if !f.modality.isEmpty         { single("query-modality", "wado query study --modality") { $0.modality = f.modality } }
        if !f.accession.isEmpty        { single("query-accession", "wado query study --accession-number") { $0.accession = f.accession } }
        if !f.studyDescription.isEmpty { single("query-desc", "wado query study --study-description") { $0.studyDescription = f.studyDescription } }

        // Combined filters (only when ≥2 provided, else it duplicates a single scenario).
        if perFilter >= 2 {
            var combined = f; combined.studyUID = ""; combined.seriesUID = ""
            out.append(wadoQuerySc("query-combined", "wado query study (all filters)", level: "study", apply: combined))
        }

        // --format coverage (broad study query): json gets full result-set parity via
        // the scenarios above; csv/table are validated by result count (they drop fields).
        for fmt in ["csv", "table"] {
            out.append(wadoQuerySc("query-format-\(fmt)", "wado query study --format \(fmt)", level: "study", apply: QueryFilters(), format: fmt))
        }

        // --limit / --offset pagination (broad study query). Both sides request the
        // IDENTICAL page, so the page SIZE (matched count) is deterministic — but the
        // server need not return the SAME members in the SAME order across the two
        // near-simultaneous requests, so these validate the matched COUNT only (the
        // runner forces count parity for paginated rows even under --format json). The
        // page size 5 / offset 5 are fixed harness values (the user supplies no paging
        // input — there's no end-user field for it).
        out.append(wadoQuerySc("query-limit", "wado query study --limit 5", level: "study", apply: QueryFilters(), limit: 5))
        out.append(wadoQuerySc("query-offset", "wado query study --limit 5 --offset 5", level: "study", apply: QueryFilters(), limit: 5, offset: 5))

        // Series / instance levels — ALWAYS shown so they're never silently missing;
        // the runner skips each with guidance when the scoping UID(s) aren't supplied.
        var seriesF = QueryFilters(); seriesF.studyUID = f.studyUID
        out.append(wadoQuerySc("query-series", "wado query series (--study)", level: "series", apply: seriesF))
        var instF = QueryFilters(); instF.studyUID = f.studyUID; instF.seriesUID = f.seriesUID
        out.append(wadoQuerySc("query-instance", "wado query instance (--study --series)", level: "instance", apply: instF))
        return out
    }

    private static func wadoQuerySc(_ idSuffix: String, _ label: String, level: String,
                                    apply f: QueryFilters, format: String = "json",
                                    limit: Int? = nil, offset: Int? = nil) -> BatchScenario {
        var cli = ["query", webURLToken, "--level", level]
        var sp: [String: String] = ["wado-mode": "query", "level": level, "format": format]
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
        add("--study", "study-uid", f.studyUID)
        add("--series", "series-uid", f.seriesUID)
        // --limit / --offset pagination — only when set (the runner mirrors the same
        // page in the package-API reference and compares on matched COUNT). Stored in
        // studioParams so the runner both replays the page and selects count parity.
        if let limit = limit  { cli += ["--limit", String(limit)];   sp["limit"]  = String(limit) }
        if let offset = offset { cli += ["--offset", String(offset)]; sp["offset"] = String(offset) }
        cli += ["--format", format]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + query keys")
    }

    // dicom-wado retrieve (WADO-RS) — pulls instances / metadata, mirrors dicom-retrieve.
    // Metadata is swept in BOTH formats: --format json (object-array count) and
    // --format xml (PS3.19 Native DICOM Model, one <NativeDicomModel> per instance) —
    // both reduce to the same instance count, so the XML path is verified end-to-end
    // against the package-API reference.
    static func wadoRetrieveScenarios(scope: WADOScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        // Study level — always shown (skipped at run time when no Study UID).
        out.append(wadoRetrieveSc("retrieve-study", "wado retrieve study", level: "study", metadata: false, scope: scope))
        out.append(wadoRetrieveSc("retrieve-study-metadata", "wado retrieve study --metadata --format json", level: "study", metadata: true, scope: scope))
        out.append(wadoRetrieveSc("retrieve-study-metadata-xml", "wado retrieve study --metadata --format xml", level: "study", metadata: true, scope: scope, metadataFormat: "xml"))
        // Study-level thumbnail — always shown (needs only the Study UID, like the
        // study retrieve). Rendered/frames are instance-only, so they appear below.
        out.append(wadoRetrieveDerivedSc("retrieve-thumbnail-study", "wado retrieve --thumbnail (study)",
                                         kind: "thumbnail", level: "study", scope: scope))
        // Series level — only when a Series UID is supplied.
        if !scope.query.seriesUID.isEmpty {
            out.append(wadoRetrieveSc("retrieve-series", "wado retrieve series", level: "series", metadata: false, scope: scope))
            out.append(wadoRetrieveSc("retrieve-series-metadata", "wado retrieve series --metadata --format json", level: "series", metadata: true, scope: scope))
            out.append(wadoRetrieveDerivedSc("retrieve-thumbnail-series", "wado retrieve --thumbnail (series)",
                                             kind: "thumbnail", level: "series", scope: scope))
        }
        // Instance level — only when a SOP Instance UID is supplied.
        if !scope.instanceUID.isEmpty {
            out.append(wadoRetrieveSc("retrieve-instance", "wado retrieve instance", level: "instance", metadata: false, scope: scope))
            out.append(wadoRetrieveSc("retrieve-instance-metadata", "wado retrieve instance --metadata --format json", level: "instance", metadata: true, scope: scope))
            out.append(wadoRetrieveSc("retrieve-instance-metadata-xml", "wado retrieve instance --metadata --format xml", level: "instance", metadata: true, scope: scope, metadataFormat: "xml"))
            // Derived WADO-RS retrievals (instance level): rendered image, instance
            // thumbnail, and a single frame. These produce transcoded/raw bytes that
            // aren't byte-stable, so parity is on success + the COUNT of files produced
            // (1 each) — see wadoRetrieveDerivedSc.
            out.append(wadoRetrieveDerivedSc("retrieve-rendered", "wado retrieve --rendered",
                                             kind: "rendered", level: "instance", scope: scope))
            out.append(wadoRetrieveDerivedSc("retrieve-thumbnail-instance", "wado retrieve --thumbnail (instance)",
                                             kind: "thumbnail", level: "instance", scope: scope))
            out.append(wadoRetrieveDerivedSc("retrieve-frames", "wado retrieve --frames 1",
                                             kind: "frames", level: "instance", scope: scope, frames: "1"))
            // WADO-URI (legacy, PS3.18 §8) — always single-instance, so it reuses the
            // SAME study/series/instance UIDs (no separate endpoint field). --content-type
            // selects the representation; the timeout row proves --timeout is accepted but
            // IGNORED in URI mode (stays at parity). See wadoRetrieveURISc.
            out.append(wadoRetrieveURISc("retrieve-uri", "wado retrieve --uri (WADO-URI)",
                                         scope: scope, contentType: ""))
            out.append(wadoRetrieveURISc("retrieve-uri-jpeg", "wado retrieve --uri --content-type image/jpeg",
                                         scope: scope, contentType: "image/jpeg"))
            // Remaining transcoded representations the CLI advertises (image/png,
            // image/gif). Like JPEG these aren't byte-stable, so the runner compares
            // success only (not byte count). Servers without a renderer reject them →
            // both sides fail identically (failureAgreement), never a false DIFFERS.
            out.append(wadoRetrieveURISc("retrieve-uri-png", "wado retrieve --uri --content-type image/png",
                                         scope: scope, contentType: "image/png"))
            out.append(wadoRetrieveURISc("retrieve-uri-gif", "wado retrieve --uri --content-type image/gif",
                                         scope: scope, contentType: "image/gif"))
            out.append(wadoRetrieveURISc("retrieve-uri-timeout", "wado retrieve --uri --content-type application/dicom --timeout 60",
                                         scope: scope, contentType: "application/dicom", timeout: "60"))
        }
        return out
    }

    /// Assembles one dicom-wado DERIVED WADO-RS retrieve scenario — `--rendered`
    /// (instance), `--thumbnail` (study/series/instance), or `--frames` (instance). These
    /// write transcoded image / raw frame files to `--output` whose BYTES aren't stable to
    /// compare, so the runner compares success + the COUNT of files produced (the package
    /// reference counts what it pulled). `--study` is always passed; `--series`/`--instance`
    /// are added per level. Rendered/frames require series+instance; thumbnail uses
    /// whatever level it's built at.
    private static func wadoRetrieveDerivedSc(_ idSuffix: String, _ label: String, kind: String,
                                              level: String, scope: WADOScope, frames: String = "") -> BatchScenario {
        let studyUID = scope.query.studyUID
        let seriesUID = scope.query.seriesUID
        let instanceUID = scope.instanceUID

        var cli = ["retrieve", webURLToken, "--study", studyUID]
        if level == "series" || level == "instance" { cli += ["--series", seriesUID] }
        if level == "instance" { cli += ["--instance", instanceUID] }
        switch kind {
        case "rendered":  cli += ["--rendered"]
        case "thumbnail": cli += ["--thumbnail"]
        case "frames":    cli += ["--frames", frames]
        default: break
        }
        // --output → the runner's scratch dir (cleaned up); the produced files are counted
        // on disk, not parsed from stdout (rendered/thumbnail print nothing without -v).
        cli += ["--output", outDirToken]

        var sp: [String: String] = [
            "wado-mode": "retrieve-derived", "retrieve-kind": kind, "level": level,
            "study-uid": studyUID, "series-uid": seriesUID, "instance-uid": instanceUID,
        ]
        if !frames.isEmpty { sp["frames"] = frames }
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + retrieve scope (\(kind))")
    }

    /// Assembles one dicom-wado WADO-URI retrieve scenario (`retrieve … --uri`). WADO-URI
    /// (PS3.18 §8) is the legacy query-parameter protocol — it always identifies a single
    /// object, so it needs study + series + instance (taken from the shared Query Keys +
    /// the dicom-wado scope; the user supplies no separate WADO-URI endpoint). The CLI
    /// short-circuits to WADO-URI, SAVES one object to --output, and prints
    /// "Retrieved N bytes"; both sides call the SAME WADOURIClient against the SAME URL,
    /// so the retrieved BYTE count is deterministic — parity is on success + byte count.
    /// A server that can't speak WADO-URI here throws on BOTH sides identically, so the
    /// row stays at parity (both fail) rather than false-DIFFERing. `--content-type` is
    /// the only flag with effect in URI mode; `--timeout` is accepted but ignored.
    private static func wadoRetrieveURISc(_ idSuffix: String, _ label: String, scope: WADOScope,
                                          contentType: String, timeout: String = "") -> BatchScenario {
        let studyUID = scope.query.studyUID
        let seriesUID = scope.query.seriesUID
        let instanceUID = scope.instanceUID

        var cli = ["retrieve", webWADOURIURLToken, "--uri",
                   "--study", studyUID, "--series", seriesUID, "--instance", instanceUID]
        if !contentType.isEmpty { cli += ["--content-type", contentType] }
        if !timeout.isEmpty     { cli += ["--timeout", timeout] }
        // --output directs the saved object to the runner's per-scenario scratch dir
        // (cleaned up) instead of the app's working directory; its contents aren't parsed
        // (the byte count comes from the CLI's "Retrieved N bytes" stdout).
        cli += ["--output", outDirToken]

        let sp: [String: String] = [
            "wado-mode": "retrieve-uri", "level": "instance",
            "study-uid": studyUID, "series-uid": seriesUID, "instance-uid": instanceUID,
            "content-type": contentType,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + retrieve scope (WADO-URI)")
    }

    private static func wadoRetrieveSc(_ idSuffix: String, _ label: String, level: String,
                                       metadata: Bool, scope: WADOScope,
                                       metadataFormat: String = "json") -> BatchScenario {
        let studyUID = scope.query.studyUID
        let seriesUID = scope.query.seriesUID
        let instanceUID = scope.instanceUID

        var cli = ["retrieve", webURLToken, "--study", studyUID]
        if level == "series" || level == "instance" { cli += ["--series", seriesUID] }
        if level == "instance" { cli += ["--instance", instanceUID] }
        if metadata {
            // Metadata prints to stdout unconditionally (no files); no --verbose, whose
            // "Retrieved metadata for N" trailer would only add noise. The format is
            // swept (json | xml) — the runner parses the matching count.
            cli += ["--metadata", "--format", metadataFormat]
        } else {
            // Instances are written to the output dir (counted on disk); --verbose is
            // harmless here (its stdout isn't parsed) but kept for a readable output pane.
            cli += ["--output", outDirToken, "--verbose"]
        }

        var sp: [String: String] = [
            "wado-mode": "retrieve", "level": level, "metadata": metadata ? "true" : "false",
            "study-uid": studyUID, "series-uid": seriesUID, "instance-uid": instanceUID,
        ]
        // The metadata format drives only the CLI's stdout shape (the reference counts
        // objects regardless), so it's threaded only for metadata scenarios.
        if metadata { sp["metadata-format"] = metadataFormat }
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + retrieve scope")
    }

    // dicom-wado store (STOW-RS) — uploads instances (WRITES), mirrors dicom-send.
    // The upload OUTCOME (sent / succeeded / failed) is independent of --batch (chunk
    // size), --verbose (extra progress lines), and --continue-on-error (only changes
    // behaviour on a read/upload error), so each flag is swept against the same set of
    // files and must yield the identical outcome the package-API reference produces.
    static func wadoStoreScenarios(studyUID: String = "") -> [BatchScenario] {
        var out: [BatchScenario] = [
            wadoStoreSc("store-default",           "wado store (STOW-RS)",          flags: []),
            wadoStoreSc("store-verbose",           "wado store --verbose",          flags: ["--verbose"]),
            wadoStoreSc("store-batch-1",           "wado store --batch 1",          flags: ["--batch", "1"]),
            wadoStoreSc("store-continue-on-error", "wado store --continue-on-error", flags: ["--continue-on-error"]),
            // --input <filelist>: the runner writes the gathered file paths to a temp list
            // file and passes `--input` instead of positional args. The upload OUTCOME is
            // identical to positional files, so the same store comparator applies.
            wadoStoreInputSc("store-input", "wado store --input <filelist>"),
        ]
        // --study <uid> (targeted STOW-RS) — only when a Study UID is supplied. Both sides
        // STOW to /studies/{uid} and compare the upload outcome counts (an instance whose
        // own StudyInstanceUID doesn't match the target is rejected identically on both).
        if !studyUID.isEmpty {
            out.append(wadoStoreSc("store-study", "wado store --study", flags: ["--study", studyUID],
                                   params: ["study-uid": studyUID]))
        }
        return out
    }

    private static func wadoStoreSc(_ idSuffix: String, _ label: String, flags: [String],
                                    params: [String: String] = [:]) -> BatchScenario {
        // The argv is a template — the runner expands SENDFILE into the gathered DICOM
        // file list (STOW-RS takes file arguments, not a directory) and appends the
        // flag(s) under test (everything trailing the SENDFILE token) before running.
        // parseStore reads the unconditional "Upload Summary" block, so the --verbose
        // per-failure detail lines no longer collide with the summary counts.
        let cli = ["store", webURLToken, sendFileToken] + flags
        var sp: [String: String] = ["wado-mode": "store"]
        for (k, v) in params { sp[k] = v }
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint (stores a picked DICOM file/directory, or a synthetic CT)")
    }

    private static func wadoStoreInputSc(_ idSuffix: String, _ label: String) -> BatchScenario {
        // No SENDFILE positional — the runner gathers the files, writes them to a temp
        // list file, and passes `--input <listfile>` (the `<filelist>` here is a display
        // placeholder; the real path is the per-run temp file). The reference stores the
        // SAME gathered files, so the upload outcome compares like any other store row.
        let cli = ["store", webURLToken, "--input", "<filelist>"]
        let sp: [String: String] = ["wado-mode": "store", "store-input": "true"]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint (stores a picked DICOM file/directory, or a synthetic CT) via --input")
    }

    // dicom-wado ups (UPS-RS) — search (read) always; create → claim lifecycle (writes)
    // only when a Procedure Step Label is supplied. The search sweep covers the broad
    // query, one row per --filter-state value (both sides issue the IDENTICAL filtered
    // query, so the matched workitem set is comparable), and --format coverage (csv/
    // table validated by matched COUNT, like the QIDO query sweep).
    static func wadoUPSScenarios(scope: WADOScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        out.append(wadoUPSSearchSc("ups-search", "wado ups --search (UPS-RS)", filterState: "", format: "json"))
        for st in ["SCHEDULED", "IN_PROGRESS", "COMPLETED", "CANCELED"] {
            let idState = st.lowercased().replacingOccurrences(of: "_", with: "-")
            out.append(wadoUPSSearchSc("ups-search-\(idState)", "wado ups --search --filter-state \(st)",
                                       filterState: st, format: "json"))
        }
        out.append(wadoUPSSearchSc("ups-search-csv",   "wado ups --search --format csv",   filterState: "", format: "csv"))
        out.append(wadoUPSSearchSc("ups-search-table", "wado ups --search --format table", filterState: "", format: "table"))
        // --scheduled-station filter (harness-picked station AE; the user supplies no station
        // field). Both sides issue the IDENTICAL filtered query, so the matched COUNT lines
        // up (typically 0 — no workitem is scheduled on this synthetic station — which is
        // still valid parity).
        out.append(wadoUPSSearchSc("ups-search-station", "wado ups --search --scheduled-station \(upsStationFilter)",
                                   filterState: "", format: "json", scheduledStation: upsStationFilter))
        // --verbose proves the flag is accepted and is semantically transparent: the
        // extra progress lines don't change the parsed result, so the matched count
        // stays at parity with the non-verbose search.
        out.append(wadoUPSSearchSc("ups-search-verbose", "wado ups --search --verbose",
                                   filterState: "", format: "json", verbose: true))
        if !scope.upsLabel.isEmpty {
            out.append(wadoUPSLifecycleSc("ups-lifecycle", "wado ups create → claim", scope: scope))
            // Full state machine: create → claim (IN PROGRESS) → COMPLETED, and
            // create → claim → CANCELED. The runner threads ONE harness-minted
            // Transaction UID through both the claim and the final transition (the
            // server requires the same UID that locked the workitem). COMPLETED also
            // sends the required Final State attributes (shared client helper). Some
            // servers reject these without extra config → both sides fail identically
            // (failureAgreement), never a false DIFFERS.
            out.append(wadoUPSLifecycleSc("ups-lifecycle-complete", "wado ups create → claim → COMPLETED",
                                          scope: scope, finalState: "COMPLETED"))
            out.append(wadoUPSLifecycleSc("ups-lifecycle-cancel", "wado ups create → claim → CANCELED",
                                          scope: scope, finalState: "CANCELED"))
            // --get round-trip: create a workitem, then retrieve it back by its minted UID
            // (chained by the runner — the UID is only known at run time). Each side gets
            // its OWN workitem, so parity is on the outcome (create / get success).
            out.append(wadoUPSGetSc("ups-get", "wado ups create → --get", scope: scope))
            // --create-workitem attribute sweep: create with the FULL harness-picked
            // attribute set (priority/dates/station/performer/…). Parity on create success.
            out.append(wadoUPSCreateAttrsSc("ups-create-attrs", "wado ups --create-workitem (all attributes)", scope: scope))
            // --create <jsonfile>: create from a synthesised DICOM-JSON workitem file.
            out.append(wadoUPSCreateJSONSc("ups-create-json", "wado ups --create <jsonfile>", scope: scope))
            // --subscribe / --unsubscribe round-trip (create → subscribe → unsubscribe).
            out.append(wadoUPSSubscribeSc("ups-subscribe", "wado ups create → --subscribe → --unsubscribe", scope: scope))
        }
        return out
    }

    /// Harness-picked station AE for the --scheduled-station search filter (the user
    /// supplies no station input; both sides filter by the same value → comparable count).
    private static let upsStationFilter = "CT_AE_01"

    private static func wadoUPSSearchSc(_ idSuffix: String, _ label: String,
                                        filterState: String, format: String,
                                        scheduledStation: String = "",
                                        verbose: Bool = false) -> BatchScenario {
        var cli = ["ups", webURLToken, "--search"]
        var sp: [String: String] = ["wado-mode": "ups-search", "format": format]
        if !filterState.isEmpty {
            cli += ["--filter-state", filterState]
            sp["filter-state"] = filterState
        }
        if !scheduledStation.isEmpty {
            cli += ["--scheduled-station", scheduledStation]
            sp["scheduled-station"] = scheduledStation
        }
        cli += ["--format", format]
        if verbose { cli += ["--verbose"] }   // semantically transparent — count unaffected
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint")
    }

    private static func wadoUPSLifecycleSc(_ idSuffix: String, _ label: String, scope: WADOScope,
                                           finalState: String = "IN_PROGRESS") -> BatchScenario {
        // The argv is the `--create-workitem` command; the runner runs it, parses the
        // minted Workitem UID, then builds + runs the claim (`--update --state
        // IN_PROGRESS --aet … --transaction-uid …`) itself (the UID is only known at
        // run time). When `finalState` is COMPLETED/CANCELED the runner additionally
        // runs `--update --state <FINAL> --transaction-uid <same UID>`.
        var cli = ["ups", webURLToken, "--create-workitem", "--label", scope.upsLabel]
        if !scope.upsPatientName.isEmpty { cli += ["--patient-name", scope.upsPatientName] }
        if !scope.upsPatientID.isEmpty   { cli += ["--patient-id", scope.upsPatientID] }
        let sp: [String: String] = [
            "wado-mode": "ups-lifecycle", "label": scope.upsLabel,
            "patient-name": scope.upsPatientName, "patient-id": scope.upsPatientID, "aet": scope.upsAET,
            "ups-final": finalState,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + UPS scope (writes)")
    }

    private static func wadoUPSGetSc(_ idSuffix: String, _ label: String, scope: WADOScope) -> BatchScenario {
        // The argv is the `--create-workitem` command; the runner runs it, parses the
        // minted Workitem UID, then runs `ups --get <uid>` itself (the UID is only known
        // at run time). Each side retrieves its OWN just-created workitem.
        var cli = ["ups", webURLToken, "--create-workitem", "--label", scope.upsLabel]
        if !scope.upsPatientName.isEmpty { cli += ["--patient-name", scope.upsPatientName] }
        if !scope.upsPatientID.isEmpty   { cli += ["--patient-id", scope.upsPatientID] }
        let sp: [String: String] = [
            "wado-mode": "ups-get", "label": scope.upsLabel,
            "patient-name": scope.upsPatientName, "patient-id": scope.upsPatientID,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + UPS scope (writes)")
    }

    /// Harness-picked create-workitem attribute set (the user supplies no per-attribute
    /// fields). Keyed by the CLI flag name (minus `--`); each flows to BOTH the CLI argv
    /// and studioParams so the runner replays the IDENTICAL values in the reference builder.
    /// `--study-uid` is intentionally omitted (it needs a real referenced study).
    private static let upsCreateAttrs: [(flag: String, value: String)] = [
        ("priority", "HIGH"),
        ("patient-birth-date", "19800101"),
        ("patient-sex", "M"),
        ("accession-number", "ACC-PARITY-1"),
        ("referring-physician", "REF^DOCTOR"),
        ("procedure-id", "RP-PARITY-1"),
        ("step-id", "SPS-PARITY-1"),
        ("worklist-label", "WL-PARITY"),
        ("comments", "CLI parity test workitem"),
        ("scheduled-start", "2026-03-20T14:00:00"),
        ("expected-completion", "2026-03-20T15:00:00"),
        ("station-name", "CT_AE_01"),
        ("performer-name", "PERF^ONE"),
        ("performer-organization", "ORG-PARITY"),
        ("admission-id", "ADM-PARITY-1"),
    ]

    /// Harness-picked Application Entity title for the subscribe/unsubscribe round-trip
    /// (the CLI requires `--aet`; the user supplies no AE field for UPS subscription).
    private static let upsSubscribeAET = "STUDIO_SCU"

    private static func wadoUPSCreateAttrsSc(_ idSuffix: String, _ label: String, scope: WADOScope) -> BatchScenario {
        // Single `--create-workitem` invocation carrying the full attribute set; the runner
        // compares create success (the reference builds the IDENTICAL workitem via the same
        // WorkitemBuilder glue). Each side mints its own UID (no --workitem-uid), so the two
        // creates don't collide.
        var cli = ["ups", webURLToken, "--create-workitem", "--label", scope.upsLabel]
        var sp: [String: String] = [
            "wado-mode": "ups-create", "label": scope.upsLabel,
            "patient-name": scope.upsPatientName, "patient-id": scope.upsPatientID,
        ]
        if !scope.upsPatientName.isEmpty { cli += ["--patient-name", scope.upsPatientName] }
        if !scope.upsPatientID.isEmpty   { cli += ["--patient-id", scope.upsPatientID] }
        for (flag, value) in upsCreateAttrs {
            cli += ["--\(flag)", value]
            sp[flag] = value
        }
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + UPS scope (writes, all attributes)")
    }

    private static func wadoUPSCreateJSONSc(_ idSuffix: String, _ label: String, scope: WADOScope) -> BatchScenario {
        // The runner synthesises a DICOM-JSON workitem file and passes `--create <file>`
        // (the `<jsonfile>` here is a display placeholder; the real per-run temp path is
        // built in the runner). The reference creates an equivalent workitem with its own
        // distinct UID, so the two creates don't collide.
        let cli = ["ups", webURLToken, "--create", "<jsonfile>"]
        let sp: [String: String] = [
            "wado-mode": "ups-create-json", "label": scope.upsLabel,
            "patient-name": scope.upsPatientName, "patient-id": scope.upsPatientID,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + UPS scope (writes, via JSON file)")
    }

    private static func wadoUPSSubscribeSc(_ idSuffix: String, _ label: String, scope: WADOScope) -> BatchScenario {
        // The argv is the `--create-workitem` command; the runner runs it, parses the minted
        // Workitem UID, then runs `ups --subscribe`/`--unsubscribe --workitem-uid <uid>
        // --aet <ae>` itself. AE title is harness-picked.
        var cli = ["ups", webURLToken, "--create-workitem", "--label", scope.upsLabel]
        if !scope.upsPatientName.isEmpty { cli += ["--patient-name", scope.upsPatientName] }
        if !scope.upsPatientID.isEmpty   { cli += ["--patient-id", scope.upsPatientID] }
        let sp: [String: String] = [
            "wado-mode": "ups-subscribe", "label": scope.upsLabel,
            "patient-name": scope.upsPatientName, "patient-id": scope.upsPatientID,
            "aet": upsSubscribeAET,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + UPS scope (writes, subscription)")
    }

    /// Assembles one dicom-wado scenario — all four subcommands share the same shape
    /// (no input file/fixture; the semantic record is built from the live DICOMweb
    /// reference vs the CLI).
    private static func wadoScenario(_ idSuffix: String, _ label: String,
                                     cliArgs: [String], studioParams: [String: String],
                                     inputHint: String) -> BatchScenario {
        BatchScenario(
            scenarioId: "dicom-wado_net_\(idSuffix)",
            toolId: "dicom-wado",
            label: label,
            cliArgs: cliArgs,
            studioParams: studioParams,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "wado-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: inputHint)
    }
}
