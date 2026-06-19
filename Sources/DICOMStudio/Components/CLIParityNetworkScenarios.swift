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

    /// C-STORE scenarios. The user supplies the endpoint and, optionally, a DICOM file
    /// or directory to send (otherwise the bundled synthetic CT, syn-ct.dcm). Includes a
    /// no-write --dry-run plus real sends across the priority/verify flags. Every
    /// scenario passes `--recursive` so a picked directory is scanned in full; it's a
    /// harmless no-op for a single file. NOTE: the real-send rows persist the sent
    /// instance(s) on the server (deduplicated on repeats).
    static func sendScenarios() -> [BatchScenario] {
        [
            sendSc("dry-run",       "send --dry-run",        flags: ["--dry-run"],          params: ["dry-run": "true"]),
            sendSc("default",       "send (default)",        flags: [],                     params: [:]),
            sendSc("priority-high", "send --priority high",  flags: ["--priority", "high"], params: ["priority": "high"]),
            sendSc("verify",        "send --verify",         flags: ["--verify"],           params: ["verify": "true"]),
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
                                   scope: RetrieveScope) -> BatchScenario {
        let ts = method == "c-get" ? scope.transferSyntax : ""

        var cli = [hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken,
                   "--study-uid", scope.studyUID]
        if level == "series" || level == "instance" { cli += ["--series-uid", scope.seriesUID] }
        if level == "instance" { cli += ["--instance-uid", scope.instanceUID] }
        cli += ["--method", method]
        if method == "c-move" { cli += ["--move-dest", scope.moveDest] }
        cli += ["--output", outDirToken, "--timeout", timeoutToken, "--verbose"]
        if !ts.isEmpty { cli += ["--transfer-syntax", ts] }

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

        // Interactive select-all retrieve — bound by the user's filters (a row, like the
        // combined review, that carries every supplied key so the matched/retrieved set
        // is the same scope). C-GET first (pulls to a scratch dir), then C-MOVE (forwards).
        var scoped = f; scoped.seriesUID = ""
        out.append(qrInteractiveSc("interactive-cget", "qr interactive c-get (select all)",
                                   method: "c-get", apply: scoped))
        out.append(qrInteractiveSc("interactive-cmove", "qr interactive c-move (select all)",
                                   method: "c-move", apply: scoped, moveDest: moveDest))
        return out
    }

    /// Assembles one dicom-qr review scenario. Endpoint stays tokenised; the query-key
    /// VALUES are concrete. `query` is the explicit subcommand; `--review` runs the
    /// C-FIND only (no retrieve), and `--method c-get` avoids the C-MOVE move-dest check.
    private static func qrSc(_ idSuffix: String, _ label: String, apply f: QueryFilters) -> BatchScenario {
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
                                        apply f: QueryFilters, moveDest: String = "") -> BatchScenario {
        var cli = ["query", hostToken, "--port", portToken, "--aet", aetToken, "--called-aet", calledAETToken,
                   "--interactive", "--method", method]
        if method == "c-move" { cli += ["--move-dest", moveDest] }
        if method == "c-get"  { cli += ["--output", outDirToken] }
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
        return out
    }

    /// Assembles one dicom-mwl scenario. Endpoint stays tokenised; the filter VALUES
    /// are concrete. `query` is the explicit subcommand; `--json` makes the per-item
    /// output parse robustly. The filter values are also stored in studioParams so the
    /// runner builds the IDENTICAL package-API query keys for the reference side.
    private static func mwlSc(_ idSuffix: String, _ label: String, apply f: WorklistFilters) -> BatchScenario {
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
        out.append(mppsSc("create-in-progress", "mpps create (IN PROGRESS)",
                          lifecycle: false, finalStatus: "", scope: scope))
        out.append(mppsSc("lifecycle-completed", "mpps create → complete",
                          lifecycle: true, finalStatus: "COMPLETED", scope: scope))
        out.append(mppsSc("lifecycle-discontinued", "mpps create → discontinue",
                          lifecycle: true, finalStatus: "DISCONTINUED", scope: scope))
        // Referenced-image completion — only when a Series UID and image UID(s) exist.
        if !scope.seriesUID.isEmpty && !scope.imageUIDs.isEmpty {
            out.append(mppsSc("lifecycle-completed-images", "mpps create → complete (referenced images)",
                              lifecycle: true, finalStatus: "COMPLETED", scope: scope, withImages: true))
        }
        return out
    }

    /// Assembles one dicom-mpps scenario. `cliArgs` is the N-CREATE command (subcommand
    /// `create` first, like dicom-qr's `query`); the runner runs it, parses the minted
    /// MPPS UID, and — for a lifecycle row — builds + runs the matching `update`
    /// command itself (the UID is only known at run time). studioParams carries the
    /// lifecycle flag, the final status, and the scope so the package-API reference
    /// drives the identical create→update.
    private static func mppsSc(_ idSuffix: String, _ label: String, lifecycle: Bool, finalStatus: String,
                               scope: MPPSScope, withImages: Bool = false) -> BatchScenario {
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
        out += wadoQueryScenarios(filters: scope.query)
        out += wadoRetrieveScenarios(scope: scope)
        out += wadoStoreScenarios()
        out += wadoUPSScenarios(scope: scope)
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

        // Series / instance levels — ALWAYS shown so they're never silently missing;
        // the runner skips each with guidance when the scoping UID(s) aren't supplied.
        var seriesF = QueryFilters(); seriesF.studyUID = f.studyUID
        out.append(wadoQuerySc("query-series", "wado query series (--study)", level: "series", apply: seriesF))
        var instF = QueryFilters(); instF.studyUID = f.studyUID; instF.seriesUID = f.seriesUID
        out.append(wadoQuerySc("query-instance", "wado query instance (--study --series)", level: "instance", apply: instF))
        return out
    }

    private static func wadoQuerySc(_ idSuffix: String, _ label: String, level: String,
                                    apply f: QueryFilters, format: String = "json") -> BatchScenario {
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
        cli += ["--format", format]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + query keys")
    }

    // dicom-wado retrieve (WADO-RS) — pulls instances / metadata, mirrors dicom-retrieve.
    static func wadoRetrieveScenarios(scope: WADOScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        // Study level — always shown (skipped at run time when no Study UID).
        out.append(wadoRetrieveSc("retrieve-study", "wado retrieve study", level: "study", metadata: false, scope: scope))
        out.append(wadoRetrieveSc("retrieve-study-metadata", "wado retrieve study --metadata", level: "study", metadata: true, scope: scope))
        // Series level — only when a Series UID is supplied.
        if !scope.query.seriesUID.isEmpty {
            out.append(wadoRetrieveSc("retrieve-series", "wado retrieve series", level: "series", metadata: false, scope: scope))
        }
        // Instance level — only when a SOP Instance UID is supplied.
        if !scope.instanceUID.isEmpty {
            out.append(wadoRetrieveSc("retrieve-instance", "wado retrieve instance", level: "instance", metadata: false, scope: scope))
        }
        return out
    }

    private static func wadoRetrieveSc(_ idSuffix: String, _ label: String, level: String,
                                       metadata: Bool, scope: WADOScope) -> BatchScenario {
        let studyUID = scope.query.studyUID
        let seriesUID = scope.query.seriesUID
        let instanceUID = scope.instanceUID

        var cli = ["retrieve", webURLToken, "--study", studyUID]
        if level == "series" || level == "instance" { cli += ["--series", seriesUID] }
        if level == "instance" { cli += ["--instance", instanceUID] }
        if metadata {
            // Metadata prints the JSON array to stdout unconditionally (no files); no
            // --verbose, whose "Retrieved metadata for N" trailer would only add noise.
            cli += ["--metadata", "--format", "json"]
        } else {
            // Instances are written to the output dir (counted on disk); --verbose is
            // harmless here (its stdout isn't parsed) but kept for a readable output pane.
            cli += ["--output", outDirToken, "--verbose"]
        }

        let sp: [String: String] = [
            "wado-mode": "retrieve", "level": level, "metadata": metadata ? "true" : "false",
            "study-uid": studyUID, "series-uid": seriesUID, "instance-uid": instanceUID,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + retrieve scope")
    }

    // dicom-wado store (STOW-RS) — uploads instances (WRITES), mirrors dicom-send.
    static func wadoStoreScenarios() -> [BatchScenario] {
        [wadoStoreSc("store-default", "wado store (STOW-RS)")]
    }

    private static func wadoStoreSc(_ idSuffix: String, _ label: String) -> BatchScenario {
        // The argv is a template — the runner expands SENDFILE into the gathered DICOM
        // file list (STOW-RS takes file arguments, not a directory) before running. No
        // --verbose: the runner parses the unconditional "Upload Summary" counts, and
        // --verbose would add per-failure "Failed: <SOPUID>" lines that collide with it.
        let cli = ["store", webURLToken, sendFileToken]
        let sp: [String: String] = ["wado-mode": "store"]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint (stores a picked DICOM file/directory, or a synthetic CT)")
    }

    // dicom-wado ups (UPS-RS) — search (read) always; create → claim lifecycle (writes)
    // only when a Procedure Step Label is supplied.
    static func wadoUPSScenarios(scope: WADOScope) -> [BatchScenario] {
        var out: [BatchScenario] = []
        out.append(wadoUPSSearchSc("ups-search", "wado ups --search (UPS-RS)"))
        if !scope.upsLabel.isEmpty {
            out.append(wadoUPSLifecycleSc("ups-lifecycle", "wado ups create → claim", scope: scope))
        }
        return out
    }

    private static func wadoUPSSearchSc(_ idSuffix: String, _ label: String) -> BatchScenario {
        let cli = ["ups", webURLToken, "--search", "--format", "json"]
        let sp: [String: String] = ["wado-mode": "ups-search"]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint")
    }

    private static func wadoUPSLifecycleSc(_ idSuffix: String, _ label: String, scope: WADOScope) -> BatchScenario {
        // The argv is the `--create-workitem` command; the runner runs it, parses the
        // minted Workitem UID, then builds + runs the claim (`--update --state
        // IN_PROGRESS --aet …`) itself (the UID is only known at run time).
        var cli = ["ups", webURLToken, "--create-workitem", "--label", scope.upsLabel]
        if !scope.upsPatientName.isEmpty { cli += ["--patient-name", scope.upsPatientName] }
        if !scope.upsPatientID.isEmpty   { cli += ["--patient-id", scope.upsPatientID] }
        let sp: [String: String] = [
            "wado-mode": "ups-lifecycle", "label": scope.upsLabel,
            "patient-name": scope.upsPatientName, "patient-id": scope.upsPatientID, "aet": scope.upsAET,
        ]
        return wadoScenario(idSuffix, label, cliArgs: cli, studioParams: sp,
                            inputHint: "DICOMweb endpoint + UPS scope (writes)")
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
