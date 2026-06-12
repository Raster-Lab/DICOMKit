// CLIParityRunnerViewModel.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Drives the "CLI Parity" screen: a USER-DRIVEN batch parity runner. The user
// selects tool(s) + one input file; for every auto-generated subcommand/flag
// scenario this runs BOTH the app (in-process CLIWorkshopViewModel) AND the real
// `dicom-*` binary (a subprocess via CLIToolTerminalCompare), then scores three
// dimensions (INPUT / PROCESS / OUTPUT) per row and rolls them up into a
// success rate.
//
// Reuses the proven parts wholesale: ToolCatalogHelpers.parameterDefinitions +
// CommandBuilderHelpers.buildCommand (argv), CLIWorkshopViewModel.executeCommand
// (app side), CLIToolTerminalCompare.run (CLI side), and
// CLIParityEngine.normalize/diff/mask + the in-process dicom-info re-dump used by
// the golden harness (the artifact reductions are byte-identical to it).
//
// Like CLIToolTerminalCompare, the live-CLI path requires the App Sandbox to be
// DISABLED and must be removed before production (project memory
// `dicom-info-terminal-compare-testonly`).

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class CLIParityRunnerViewModel {

    // MARK: Inputs / selection

    /// Whether the screen is sweeping the offline file tools or the network
    /// (DIMSE) tools. Drives which tool pool, controls and runner are used.
    public var mode: ParityMode = .offline

    /// Offline tools this screen can sweep (supported by the generator,
    /// non-network, execute-supported), in catalog order.
    public let availableTools: [CLIToolDefinition]
    /// Network tools that have a parity implementation today (dicom-echo).
    public let availableNetworkTools: [CLIToolDefinition]
    public var selectedToolIDs: Set<String> = []

    // MARK: Network endpoint (editable PACS credentials)

    /// The PACS the network tools echo against. Pre-filled with the team's test
    /// server; every field is user-editable. The CLI requires `--aet`, so the
    /// Calling AE must be non-empty.
    public var networkHost: String = "172.17.1.200"
    public var networkPort: String = "11112"
    public var networkCallingAET: String = "DICOMSTUDIO"
    public var networkCalledAET: String = "TEAMPACS"
    public var networkTimeout: String = "30"

    /// A named PACS the user can switch between; selecting one loads its
    /// host/port/called-AE into the (still-editable) endpoint fields.
    public struct PACSServerPreset: Identifiable, Hashable, Sendable {
        public let id: String          // also the display name
        public let host: String
        public let port: String
        public let calledAET: String
    }

    public static let serverPresets: [PACSServerPreset] = [
        .init(id: "DCM4CHEE2", host: "172.17.1.200", port: "11112", calledAET: "TEAMPACS"),
        .init(id: "DCM4CHEE5", host: "172.17.1.111", port: "11112", calledAET: "DCM4CHEE"),
    ]

    /// The currently-selected server preset id (DCM4CHEE2 by default → TEAMPACS).
    public var selectedServerID: String = "DCM4CHEE2"

    /// Loads a preset's host/port/called-AE into the endpoint fields. The calling AE
    /// (local SCU identity) and timeout are left as-is.
    public func selectServer(_ id: String) {
        guard !isRunning, let p = Self.serverPresets.first(where: { $0.id == id }) else { return }
        selectedServerID = id
        networkHost = p.host
        networkPort = p.port
        networkCalledAET = p.calledAET
    }

    // MARK: Query keys (dicom-query) — read-only C-FIND inputs

    /// The user-supplied C-FIND query keys for dicom-query. Enter values that exist
    /// on the PACS so the query returns real matches; blank fields are skipped. The
    /// matrix sweeps each provided filter individually plus the query levels.
    public var queryPatientName: String = ""
    public var queryPatientID: String = ""
    public var queryStudyDate: String = ""
    public var queryModality: String = ""
    public var queryAccession: String = ""
    public var queryStudyDescription: String = ""
    public var queryStudyUID: String = ""
    public var querySeriesUID: String = ""

    private func currentQueryFilters() -> QueryFilters {
        func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var f = QueryFilters()
        f.patientName = t(queryPatientName); f.patientID = t(queryPatientID)
        f.studyDate = t(queryStudyDate); f.modality = t(queryModality)
        f.accession = t(queryAccession); f.studyDescription = t(queryStudyDescription)
        f.studyUID = t(queryStudyUID); f.seriesUID = t(querySeriesUID)
        return f
    }

    /// Tool ids for which network parity is implemented.
    private static let networkParitySupported = CLIParityNetworkScenarios.supportedToolIDs

    /// The user's selected input corpus directory (optional). When set, each tool
    /// draws its correct input shape from this corpus; otherwise bundled fixtures
    /// are used.
    public private(set) var inputDirectory: String? = nil
    private var inputDirURL: URL? = nil
    public private(set) var corpus: CorpusIndex? = nil
    public var isScanning: Bool = false
    public var scanMessage: String = ""

    /// Optional user-selected DICOM directory for `dicom-send` (network mode). When
    /// set, both the package-API reference and the CLI send its DICOM files
    /// (recursively); when nil, both fall back to the bundled synthetic CT.
    public private(set) var sendDirectory: String? = nil
    private var sendDirURL: URL? = nil
    /// DICOM-file count of the selected send directory (for the picker's status line).
    public private(set) var sendDirFileCount: Int = 0

    // MARK: Run state

    /// When true (default), the selected tools' binaries are rebuilt fresh as the
    /// first step of every run, so the comparison never uses a stale binary.
    public var rebuildBeforeRun: Bool = true

    public var isRunning: Bool = false
    public var isBuilding: Bool = false
    public var buildMessage: String = ""
    public var totalScenarios: Int = 0
    public var completedScenarios: Int = 0
    public var binaryAvailable: Bool = true
    public var errorMessage: String? = nil

    /// Bin dir of the freshly-built products; pinned for the CLI side so a stale
    /// binary elsewhere can't shadow it. nil → fall back to the default search.
    private var freshBinDir: String? = nil

    /// Input label ("file · source") for the scenario currently running; stamped
    /// onto each result row. Safe as state because scenarios run sequentially.
    private var pendingInputUsed: String = ""

    /// When true, run the same command on BOTH its real and synthetic fixtures
    /// (the full parity-test matrix). Default false → one row per unique validated
    /// command (preferring the synthetic fixture).
    public var includeFixtureVariants: Bool = false

    public var results: [BatchScenarioResult] = []
    public var summary: BatchParitySummary = BatchParitySummary()

    /// The bundled validated scenario corpus (goldens.json, or goldens.synthetic.json
    /// on a clean checkout), loaded once.
    private let allGoldens: [GoldenScenario]

    public init() {
        let goldens = CLIParityEngine.loadGoldens()
        self.allGoldens = goldens
        let toolsWithGoldens = Set(goldens.map { $0.toolId })
        let all = ToolCatalogHelpers.allTools()
        self.availableTools = all.filter {
            toolsWithGoldens.contains($0.id) && !$0.requiresNetwork &&
            CLIParityEngine.executeSupported.contains($0.id)
        }
        self.availableNetworkTools = all.filter {
            $0.requiresNetwork && Self.networkParitySupported.contains($0.id) &&
            CLIParityEngine.executeSupported.contains($0.id)
        }
    }

    // MARK: Derived

    /// The tool pool for the active mode.
    public var activeTools: [CLIToolDefinition] {
        mode == .network ? availableNetworkTools : availableTools
    }

    /// Switches mode, scoping the selection to the new pool's tools (and
    /// pre-selecting the first network tool for convenience), and clears stale
    /// results so the two modes' tables never mix.
    public func setMode(_ m: ParityMode) {
        guard m != mode, !isRunning else { return }
        mode = m
        let ids = Set(activeTools.map { $0.id })
        selectedToolIDs = selectedToolIDs.intersection(ids)
        if m == .network, selectedToolIDs.isEmpty, let first = availableNetworkTools.first {
            selectedToolIDs = [first.id]
        }
        results = []
        summary = BatchParitySummary()
        errorMessage = nil
        completedScenarios = 0
        totalScenarios = 0
    }

    /// Results grouped by tool id, preserving discovery order.
    public var groupedResults: [(toolId: String, rows: [BatchScenarioResult])] {
        var order: [String] = []
        var byTool: [String: [BatchScenarioResult]] = [:]
        for r in results {
            if byTool[r.toolId] == nil { order.append(r.toolId) }
            byTool[r.toolId, default: []].append(r)
        }
        return order.map { ($0, byTool[$0] ?? []) }
    }

    public func displayName(for toolId: String) -> String {
        (availableTools + availableNetworkTools).first { $0.id == toolId }?.displayName ?? toolId
    }

    public func inputHint(for toolId: String) -> String {
        if toolId == "dicom-query" { return "PACS endpoint + query keys" }
        if toolId == "dicom-send" { return "PACS endpoint (sends a synthetic CT)" }
        if Self.networkParitySupported.contains(toolId) { return "PACS endpoint" }
        return CLIParityScenarioGenerator.inputHint(for: toolId)
    }

    public func toggleTool(_ id: String) {
        if selectedToolIDs.contains(id) { selectedToolIDs.remove(id) } else { selectedToolIDs.insert(id) }
    }

    public func selectAllTools() { selectedToolIDs = Set(activeTools.map { $0.id }) }
    public func clearToolSelection() { selectedToolIDs.removeAll() }

    /// Selects and scans an input corpus directory. Classification runs off the
    /// main actor (it reads file headers); the resulting CorpusIndex drives
    /// per-tool input resolution.
    public func setInputDirectory(url: URL) async {
        inputDirURL = url
        inputDirectory = url.path
        isScanning = true
        scanMessage = "Scanning \((url.path as NSString).lastPathComponent)…"
        defer { isScanning = false }
        let scoped = url.startAccessingSecurityScopedResource()
        let index = await Task.detached { CLIParityCorpusScanner.scan(directory: url) }.value
        if scoped { url.stopAccessingSecurityScopedResource() }
        corpus = index
        scanMessage = index.summary
    }

    public func clearInputDirectory() {
        inputDirURL = nil; inputDirectory = nil; corpus = nil; scanMessage = ""
    }

    /// Selects the DICOM directory `dicom-send` should transmit (network mode). Counts
    /// its DICOM files using the SAME shared gatherer the CLI uses, so the status line
    /// reflects exactly what will be sent. An empty/non-DICOM directory is allowed —
    /// the send scenario then skips with guidance rather than producing a false result.
    public func setSendDirectory(url: URL) async {
        sendDirURL = url
        sendDirectory = url.path
        let scoped = url.startAccessingSecurityScopedResource()
        let count = await Task.detached {
            CLIParityNetworkReference.gatherSendFiles(path: url.path, recursive: true).count
        }.value
        if scoped { url.stopAccessingSecurityScopedResource() }
        sendDirFileCount = count
    }

    public func clearSendDirectory() {
        sendDirURL = nil; sendDirectory = nil; sendDirFileCount = 0
    }

    // MARK: Run

    public func run() async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        results = []
        summary = BatchParitySummary()
        completedScenarios = 0
        totalScenarios = 0
        isBuilding = false
        buildMessage = ""
        freshBinDir = nil
        defer { isRunning = false; isBuilding = false }

        #if os(macOS)
        let toolIds = activeTools.map { $0.id }.filter { selectedToolIDs.contains($0) }
        guard !toolIds.isEmpty else { errorMessage = "Select at least one tool to test."; return }

        if mode == .network {
            guard !networkHost.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Enter the PACS host (e.g. 172.17.1.200)."; return
            }
            guard !networkCallingAET.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Enter a Calling AE Title — the dicom-echo CLI requires --aet."; return
            }
        }

        // Step 0: build the selected tools' binaries FRESH so the comparison never
        // runs against a stale binary (a CLI built before the latest DICOMKit change).
        if rebuildBeforeRun {
            isBuilding = true
            buildMessage = "Building \(toolIds.count) tool\(toolIds.count == 1 ? "" : "s"): \(toolIds.joined(separator: ", "))…"
            let products = toolIds
            let outcome = await Task.detached { CLIToolBuilder.build(products: products) }.value
            isBuilding = false
            guard outcome.success else {
                binaryAvailable = false
                errorMessage = "Build failed — refusing to run against stale binaries.\n\n"
                    + String(outcome.log.suffix(4000))
                return
            }
            freshBinDir = outcome.binDir
            binaryAvailable = true
        } else {
            // No rebuild: at least confirm the selected tools' binaries exist somewhere.
            guard CLIToolTerminalCompare.locateBinary(tool: toolIds[0]) != nil else {
                binaryAvailable = false
                errorMessage = "\(toolIds[0]) binary not found. Enable “Rebuild binaries first”, run `swift build`, or set DICOM_CLI_BIN_DIR. (The App Sandbox must also be disabled — this is a testing-only feature.)"
                return
            }
            binaryAvailable = true
        }
        #else
        errorMessage = "Live CLI comparison is only available on macOS."
        return
        #endif

        // NETWORK mode: sweep the selected network tools against the live PACS and
        // compare the DICOMKit package-API reference vs the CLI semantically.
        if mode == .network {
            let scenarios = CLIParityNetworkScenarios.scenarios(
                toolIDs: Set(toolIds), queryFilters: currentQueryFilters())
            totalScenarios = scenarios.count
            guard !scenarios.isEmpty else { errorMessage = "No network scenarios for the selected tools."; return }
            var sum = BatchParitySummary()
            var rows: [BatchScenarioResult] = []
            for s in scenarios {
                let r = await runNetworkScenario(s)
                rows.append(r)
                sum.tally(r)
                completedScenarios += 1
                results = rows
                summary = sum
            }
            results = rows
            summary = sum
            return
        }

        let drift = computeDriftFlags(for: toolIds)
        let scenarios = CLIParityScenarioGenerator.scenarios(
            fromGoldens: allGoldens, toolIDs: Set(toolIds), dedupByCliArgs: !includeFixtureVariants)
        totalScenarios = scenarios.count
        guard !scenarios.isEmpty else { errorMessage = "No scenarios generated for the selected tools."; return }

        // Hold security-scoped access to the corpus dir for the whole run
        // (sandbox-off test build).
        let scoped = inputDirURL.map { ($0, $0.startAccessingSecurityScopedResource()) }
        defer {
            if let (u, ok) = scoped, ok { u.stopAccessingSecurityScopedResource() }
        }

        var sum = BatchParitySummary()
        var rows: [BatchScenarioResult] = []
        for s in scenarios {
            let r = await runScenario(s, driftSet: drift[s.toolId] ?? [])
            rows.append(r)
            sum.tally(r)
            completedScenarios += 1
            results = rows            // incremental update for live progress
            summary = sum
        }
        results = rows
        summary = sum
    }

    // MARK: Per-tool input drift (the contract-level INPUT signal)

    /// For each tool, the set of flags the app emits that the CLI contract does
    /// NOT accept (EXTRA_IN_STUDIO). A scenario whose argv contains one is an
    /// INPUT_DRIFT row.
    private func computeDriftFlags(for toolIds: [String]) -> [String: Set<String>] {
        guard let contracts = CLIParityEngine.loadContracts() else { return [:] }
        let tools = ToolCatalogHelpers.allTools()
        var out: [String: Set<String>] = [:]
        for id in toolIds {
            guard let tool = tools.first(where: { $0.id == id }) else { continue }
            let r = CLIParityEngine.compare(tool: tool, contracts: contracts)
            out[id] = Set(r.rows.filter { $0.status == .extraInStudio }.map { $0.flag })
        }
        return out
    }

    // MARK: One scenario

    private func resolve(_ raw: String, file1: String, file2: String, output: String, output2: String) -> String {
        switch raw {
        case "FIXTURE":  return file1
        case "FIXTURE2": return file2
        case "OUTPUT":   return output
        case "OUTPUT2":  return output2
        default:         return raw
        }
    }

    private func result(_ s: BatchScenario, command: String, input: BatchSignal, app: Bool?, cli: Int32?,
                        output: BatchSignal, status: BatchRowStatus, appOut: String = "", cliOut: String = "",
                        diff: [OutputDiffLine] = [], note: String) -> BatchScenarioResult {
        BatchScenarioResult(scenarioId: s.scenarioId, toolId: s.toolId, label: s.label, commandLine: command,
            inputSignal: input, appSucceeded: app, cliExitCode: cli, outputSignal: output, status: status,
            appOutput: appOut, cliOutput: cliOut, diff: diff, note: note, inputUsed: pendingInputUsed)
    }

    private func runScenario(_ s: BatchScenario, driftSet: Set<String>) async -> BatchScenarioResult {
        let fm = FileManager.default

        // Resolve the input(s) HYBRID: use the user's CORPUS when it provides the
        // right shape for this tool (single file, file pair, multiframe, RLE, study
        // dir); else fall back to the bundled synthetic fixture; else skip with a
        // reason. Each tool draws the input shape it actually needs — the same way
        // the manual CLAUDE_PARITY_TEST fed each tool its correct input.
        let bundled1 = s.fixtureName.flatMap { CLIParityEngine.fixtureURL(named: $0)?.path }
        let bundled2 = s.fixture2Name.flatMap { CLIParityEngine.fixtureURL(named: $0)?.path }
        let corpusHit = corpus?.resolve(kind: s.fixtureKind)

        let file1: String
        let file2: String
        let source: String
        if s.needsSecondFile {
            if let c = corpusHit, let f2 = c.file2 { file1 = c.file1; file2 = f2; source = "corpus" }
            else if let b1 = bundled1 { file1 = b1; file2 = bundled2 ?? b1; source = "bundled" }
            else { file1 = ""; file2 = ""; source = "" }
        } else {
            if let c = corpusHit { file1 = c.file1; source = "corpus" }
            else if let b1 = bundled1 { file1 = b1; source = "bundled" }
            else { file1 = ""; source = "" }
            file2 = bundled2 ?? bundled1 ?? file1
        }
        pendingInputUsed = file1.isEmpty ? "" : "\((file1 as NSString).lastPathComponent) · \(source)"

        // Skip only when no valid input could be resolved (the corpus lacks the shape
        // AND no bundled fixture is present) — not a parity defect.
        if s.needsInputFile && file1.isEmpty {
            let want = s.inputHint
            return result(s, command: s.toolId, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: corpus != nil
                            ? "No \(want) found in your corpus, and no bundled fixture available for \(s.toolId)."
                            : "No bundled fixture available for \(s.toolId) (needs \(want)).")
        }

        // INPUT drift is known from the contract — short-circuit before running anything.
        let flagToks = s.cliArgs.filter { $0.hasPrefix("-") }
        if !driftSet.isEmpty && flagToks.contains(where: { driftSet.contains($0) }) {
            let command = ([s.toolId] + s.cliArgs.map {
                resolve($0, file1: file1, file2: file2, output: "<out>", output2: "<out2>")
            }).joined(separator: " ")
            return result(s, command: command, input: .differ, app: nil, cli: nil,
                          output: .notApplicable, status: .inputDrift,
                          note: "The app emits a flag the CLI contract rejects: \(flagToks.filter { driftSet.contains($0) }.joined(separator: ", ")).")
        }

        // Scratch dirs (one per side so the two artifacts don't collide).
        let needScratch = s.artifactName != nil || s.studioParams.values.contains("OUTPUT2")
        var appScratch: URL? = nil
        var cliScratch: URL? = nil
        if needScratch {
            for which in 0..<2 {
                let dir = fm.temporaryDirectory.appendingPathComponent("studio-parity-\(UUID().uuidString)", isDirectory: true)
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                if which == 0 { appScratch = dir } else { cliScratch = dir }
            }
        }
        defer {
            if let d = appScratch { try? fm.removeItem(at: d) }
            if let d = cliScratch { try? fm.removeItem(at: d) }
        }

        let isDir = s.artifactKind == "dicom-multi" || s.artifactKind == "dicom-tree" || s.artifactKind == "image-multi"
        func artURL(_ scratch: URL?) -> URL? {
            guard let scratch, let name = s.artifactName else { return nil }
            let u = scratch.appendingPathComponent(name)
            if isDir { try? fm.createDirectory(at: u, withIntermediateDirectories: true) }
            return u
        }
        let appArt = artURL(appScratch)
        let cliArt = artURL(cliScratch)
        let appOut2 = appScratch?.appendingPathComponent("output2.dat")
        let cliOut2 = cliScratch?.appendingPathComponent("output2.dat")

        // ---- APP side (in-process) ----
        let workshop = CLIWorkshopViewModel()
        workshop.selectTool(id: s.toolId)
        // Clear catalog-default params the scenario didn't set (a leaked default --file
        // would make the app act on a different input than the CLI).
        for def in ToolCatalogHelpers.parameterDefinitions(for: s.toolId)
            where !def.isInternal && s.studioParams[def.id] == nil {
            workshop.updateParameterValue(parameterID: def.id, value: "")
        }
        for (pid, raw) in s.studioParams {
            let v = resolve(raw, file1: file1, file2: file2,
                            output: appArt?.path ?? "", output2: appOut2?.path ?? "")
            workshop.updateParameterValue(parameterID: pid, value: v)
        }
        await workshop.executeCommand()
        let appSuccess = workshop.consoleStatus == .success
        let appConsole = workshop.consoleOutput

        // ---- CLI side (subprocess) ----
        let resolvedArgs = s.cliArgs.map {
            resolve($0, file1: file1, file2: file2, output: cliArt?.path ?? "", output2: cliOut2?.path ?? "")
        }
        let command = ([s.toolId] + resolvedArgs).joined(separator: " ")

        #if os(macOS)
        let toolId = s.toolId
        let binDir = freshBinDir
        let outcome = await Task.detached { CLIToolTerminalCompare.run(tool: toolId, arguments: resolvedArgs, binDir: binDir) }.value

        if let launchError = outcome.launchError {
            return result(s, command: command, input: .match, app: appSuccess, cli: outcome.exitCode,
                          output: .notApplicable, status: .cliError, note: launchError)
        }
        let cliExit = outcome.exitCode
        // Combined CLI stdout + stderr, shown verbatim in the row's dropdown for
        // non-Pass rows so the user can see exactly why the CLI skipped/errored.
        let cliText: String = {
            let err = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if err.isEmpty { return outcome.stdout }
            return outcome.stdout + (outcome.stdout.isEmpty ? "" : "\n") + "── stderr ──\n" + outcome.stderr
        }()
        let cliProducedFile: Bool = {
            guard let u = cliArt else { return false }
            if isDir {
                let contents = (try? fm.contentsOfDirectory(atPath: u.path)) ?? []
                return !contents.isEmpty
            }
            return fm.fileExists(atPath: u.path)
        }()
        let cliProducedNothing = s.artifactName == nil
            ? outcome.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !cliProducedFile

        // Artifact scenarios with no reference artifact: if the tool was asked to
        // write a file/dir (artifactName != nil) but the CLI produced none — e.g. a
        // flag/fixture combo the tool can't fulfil, like `dicom-export bulk` on a
        // single file, which needs a directory — there is nothing to compare. Skip
        // rather than hashing a non-existent path (which would also make ImageIO log
        // a noisy "can't open" error). A genuine app-side miss (CLI produced the
        // artifact, app did not) still surfaces below as drift.
        if s.artifactName != nil && !cliProducedFile {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .skipped,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI produced no \(s.artifactName ?? "artifact") for this input — nothing to compare (the flag/fixture combination doesn't yield the expected output).")
        }

        // gen-skip net: a combo the CLI rejects (nonzero AND produced nothing).
        // Skipped only when the nonzero exit is NOT an expected result (resultExitOK) —
        // an intentional-failure scenario should be compared, not skipped.
        if cliExit != 0 && cliProducedNothing && !s.resultExitOK {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .skipped,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI rejected this combination (exit \(cliExit)) — not applicable to this input.")
        }
        // Exit-status reconciliation. For most tools any nonzero CLI exit is an
        // error. But "diff-style" tools (dicom-diff) use a nonzero exit as a RESULT
        // (exit 1 = files differ), and the app mirrors it — so when BOTH sides agree
        // on a nonzero result we still compare their outputs (parity is agreement).
        let resultExit = s.resultExitOK
        let cliOK = cliExit == 0
        if !cliOK && !resultExit {
            let stderr = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .cliError,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI exited \(cliExit)" + (stderr.isEmpty ? "." : ": \(String(stderr.prefix(300)))"))
        }
        if cliOK && !appSuccess {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .appError,
                          appOut: appConsole, cliOut: cliText,
                          note: "The app reported an error while the CLI succeeded.")
        }
        if !cliOK && appSuccess {
            // diff-style tool: CLI signalled a nonzero result (e.g. files differ) but
            // the app reported success — an exit-status divergence (real parity miss).
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .appError,
                          appOut: appConsole, cliOut: cliText,
                          note: "CLI exited \(cliExit) (a nonzero result, e.g. files differ) but the app reported success — exit-status divergence.")
        }
        // Reaching here: both succeeded, OR (diff-style) both agreed on a nonzero
        // result. Either way, compare the outputs.

        // ---- Reduce both produced outputs to comparable strings ----
        let appRaw = await reduce(artifactURL: appArt, stdout: appConsole, kind: s.artifactKind)
        let cliRaw = await reduce(artifactURL: cliArt, stdout: outcome.stdout, kind: s.artifactKind)

        // Determinism probe for stdout tools: run the CLI a second time and compare
        // its OWN two outputs (masked). If unstable, the scenario can't be fairly scored.
        var nonDeterministic = false
        if s.artifactName == nil {
            let outcome2 = await Task.detached { CLIToolTerminalCompare.run(tool: toolId, arguments: resolvedArgs, binDir: binDir) }.value
            let a = CLIParityEngine.maskUIDs(CLIParityEngine.normalize(outcome.stdout, fixtureBasenames: []))
            let b = CLIParityEngine.maskUIDs(CLIParityEngine.normalize(outcome2.stdout, fixtureBasenames: []))
            if a != b { nonDeterministic = true }
        }

        let basenames = [(file1 as NSString).lastPathComponent, (file2 as NSString).lastPathComponent].filter { !$0.isEmpty }
        var cliLines = CLIParityEngine.normalize(cliRaw, fixtureBasenames: basenames)
        var appLines = CLIParityEngine.normalize(appRaw, fixtureBasenames: basenames)
        if s.artifactKind == "dicom" || s.artifactKind == "dicom-multi" || s.artifactKind == "dicom-tree" {
            cliLines = CLIParityEngine.maskVolatileDumpTags(cliLines)
            appLines = CLIParityEngine.maskVolatileDumpTags(appLines)
        }
        if s.artifactKind == "uid-list" {
            cliLines = CLIParityEngine.maskUIDs(cliLines)
            appLines = CLIParityEngine.maskUIDs(appLines)
        }
        let diff = CLIParityEngine.diff(cli: cliLines, studio: appLines)
        let outputMatch = !diff.contains { $0.kind != .same }

        if nonDeterministic {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .nonDeterministic,
                          appOut: appRaw, cliOut: cliRaw, diff: diff,
                          note: "The CLI's own output varies run-to-run even after masking; excluded from the score.")
        }
        return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                      output: outputMatch ? .match : .differ,
                      status: outputMatch ? .pass : .outputDrift,
                      appOut: appRaw, cliOut: cliRaw, diff: diff,
                      note: outputMatch ? "App output matches the CLI output (normalized)."
                                        : "App and CLI outputs differ (normalized).")
        #else
        return result(s, command: command, input: .match, app: appSuccess, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    // MARK: Network scenario (semantic, timing-independent)

    /// Resolves an endpoint placeholder against the editable credential fields.
    private func resolveNet(_ raw: String) -> String {
        switch raw {
        case CLIParityNetworkScenarios.hostToken:      return networkHost.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.portToken:      return networkPort.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.aetToken:       return networkCallingAET.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.calledAETToken: return networkCalledAET.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.timeoutToken:   return networkTimeout.trimmingCharacters(in: .whitespaces)
        case CLIParityNetworkScenarios.sendFileToken:
            // User-picked DICOM directory if set, else the bundled synthetic CT.
            if let dir = sendDirURL?.path, !dir.isEmpty { return dir }
            return CLIParityEngine.fixtureURL(named: "syn-ct.dcm")?.path ?? ""
        default:                                       return raw
        }
    }

    #if os(macOS)
    /// Combined CLI stdout + stderr (dicom-echo prints to stderr) for parsing and display.
    private func combinedCLIText(_ outcome: CLIToolTerminalCompare.Outcome) -> String {
        let err = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if err.isEmpty { return outcome.stdout }
        return outcome.stdout + (outcome.stdout.isEmpty ? "" : "\n") + "── stderr ──\n" + outcome.stderr
    }
    #endif

    /// Runs an async network op against a wall-clock deadline, returning `fallback`
    /// if it doesn't finish in time. A hung DICOM receive isn't cancellable (it's
    /// blocked in a continuation), so the loser task is abandoned — acceptable for a
    /// testing harness, and far better than freezing the whole run. The deadline is
    /// set longer than the op's own bounded connect timeouts, so it only fires on a
    /// genuine hang (a PACS that accepts TCP but never answers a DIMSE request).
    private func raceDeadline<T: Sendable>(_ seconds: TimeInterval, fallback: T,
                                           _ op: @escaping @Sendable () async -> T) async -> T {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await op() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(1, seconds) * 1_000_000_000))
                return nil   // timeout sentinel
            }
            // First finished wins: the op yields .some(value); the timer yields nil.
            let result = await group.next()   // T?? — outer nil only if the group were empty
            group.cancelAll()
            if let inner = result, let value = inner { return value }
            return fallback
        }
    }

    /// Runs one network scenario: the app (in-process) and the real CLI both
    /// echo the SAME live PACS, and their outcomes are compared semantically
    /// (success/failure counts, DIMSE status, remote AE) with timing ignored.
    private func runNetworkScenario(_ s: BatchScenario) async -> BatchScenarioResult {
        let command = ([s.toolId] + s.cliArgs.map { resolveNet($0) }).joined(separator: " ")

        #if os(macOS)
        let host = networkHost.trimmingCharacters(in: .whitespaces)
        let portStr = networkPort.trimmingCharacters(in: .whitespaces)
        let port = UInt16(portStr) ?? 11112
        let callingAET = networkCallingAET.trimmingCharacters(in: .whitespaces)
        let calledAET = networkCalledAET.trimmingCharacters(in: .whitespaces)
        pendingInputUsed = "\(callingAET) → \(calledAET) @ \(host):\(portStr)"

        let sp = s.studioParams
        let scTimeout = TimeInterval(resolveNet(sp["timeout"] ?? "")) ?? 30

        // Series/instance query levels need the scoping UID(s). The scenarios are
        // ALWAYS generated so they're visible; skip here (with guidance) when the
        // required UID wasn't supplied, rather than running a meaningless broad query.
        if s.toolId == "dicom-query" {
            let level = sp["level"] ?? "study"
            let hasStudy = !(sp["study-uid"] ?? "").isEmpty
            let hasSeries = !(sp["series-uid"] ?? "").isEmpty
            if level == "series" && !hasStudy {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Study UID in the Query Keys to test the series level.")
            }
            if level == "instance" && (!hasStudy || !hasSeries) {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "Enter a Study UID and a Series UID in the Query Keys to test the instance level.")
            }
        }

        // ---- REFERENCE side: drive the DICOMKit package API directly (never the CLI
        //      Workshop's in-app code). Tool-specific record + render; the CLI parse +
        //      verdict below are shared. ----
        let refOK: Bool
        let refRender: String
        // Tool-specific CLI parse + compare, deferred until the CLI has run.
        let compareCLI: (_ combined: String, _ stdout: String, _ exitOK: Bool) -> (diff: [OutputDiffLine], match: Bool)
        // Worst-case count of bounded connect-timeouts this scenario can incur, used to
        // size the hang backstop (below) for both the reference and the CLI subprocess.
        var netUnits = 1

        switch s.toolId {
        case "dicom-query":
            let level = sp["level"] ?? "study"
            var f = QueryFilters()
            f.patientName = sp["patient-name"] ?? ""
            f.patientID = sp["patient-id"] ?? ""
            f.studyDate = sp["study-date"] ?? ""
            f.modality = sp["modality"] ?? ""
            f.accession = sp["accession"] ?? ""
            f.studyDescription = sp["study-description"] ?? ""
            f.studyUID = sp["study-uid"] ?? ""
            f.seriesUID = sp["series-uid"] ?? ""
            netUnits = 2
            let q = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: CLIParityQueryComparator.semantics(level: level, success: false, objects: [])) { [f] in
                await CLIParityNetworkReference.query(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                    timeout: scTimeout, level: level, filters: f)
            }
            refOK = q.overallOK
            refRender = CLIParityNetworkReference.renderQuery(q)
            // dicom-query prints results to STDOUT. JSON carries full attributes →
            // full result-set parity; csv/table/compact drop/truncate fields → result
            // COUNT parity.
            let format = sp["format"] ?? "json"
            compareCLI = { _, stdout, exitOK in
                if format == "json" {
                    return CLIParityQueryComparator.compare(
                        reference: q,
                        cli: CLIParityQueryComparator.parse(stdout, level: q.level, success: exitOK))
                }
                let cnt = CLIParityQueryComparator.count(in: stdout, format: format)
                return CLIParityQueryComparator.compareCount(reference: q, cliCount: cnt, format: format)
            }
        case "dicom-send":
            let dryRun = sp["dry-run"] == "true"
            let verify = sp["verify"] == "true"
            let priorityName = sp["priority"] ?? "medium"
            let tsName = sp["transfer-syntax"] ?? ""
            // Expand the send path (picked directory, or the bundled CT) into the
            // SAME file list the CLI will transmit — identical enumeration via the
            // shared gatherer, so dry-run "Found N" and the send counts line up.
            let sendPath = resolveNet(CLIParityNetworkScenarios.sendFileToken)
            let recursive = s.cliArgs.contains("--recursive")
            let files = CLIParityNetworkReference.gatherSendFiles(path: sendPath, recursive: recursive)
            if files.isEmpty {
                return result(s, command: command, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "No DICOM files found in the selected send directory — pick a directory that contains DICOM files, or clear it to send the bundled synthetic CT.")
            }
            netUnits = max(1, files.count) + (verify ? 1 : 0)
            let snd = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: SendSemantics(dryRun: dryRun, sent: files.count,
                                        succeeded: 0, failed: dryRun ? 0 : files.count)) {
                await CLIParityNetworkReference.send(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET, timeout: scTimeout,
                    filePaths: files, priorityName: priorityName, transferSyntaxName: tsName,
                    verify: verify, dryRun: dryRun)
            }
            refOK = snd.overallOK
            refRender = CLIParityNetworkReference.renderSend(snd)
            // dicom-send prints its summary to stdout (dry-run note to stderr) → parse combined.
            compareCLI = { combined, _, _ in
                CLIParitySendComparator.compare(reference: snd, cli: CLIParitySendComparator.parse(combined, dryRun: dryRun))
            }

        default:   // dicom-echo
            let count = max(1, Int(sp["count"] ?? "") ?? 1)
            let verbose = sp["verbose"] == "true"
            let diagnose = sp["diagnose"] == "true"
            netUnits = diagnose ? 6 : max(1, count)
            let e = await raceDeadline(
                scTimeout * Double(netUnits) + 60,
                fallback: EchoSemantics(mode: diagnose ? "diagnose" : "echo",
                                        sent: 0, succeeded: 0, failed: max(1, count),
                                        statusCodes: [], remoteAEs: [],
                                        diagBasicOK: diagnose ? false : nil, diagStability: nil,
                                        diagResult: diagnose ? "FAILED" : nil)) {
                await CLIParityNetworkReference.echo(
                    host: host, port: port, callingAET: callingAET, calledAET: calledAET,
                    timeout: scTimeout, count: count, verbose: verbose, diagnose: diagnose)
            }
            refOK = e.overallOK
            refRender = CLIParityNetworkReference.render(e)
            // dicom-echo prints to STDERR; parse the combined text.
            compareCLI = { combined, _, _ in
                CLIParityEchoComparator.compare(reference: e, cli: CLIParityEchoComparator.parse(combined))
            }
        }

        // ---- CLI side: the real binary (same hang backstop as the reference) ----
        let resolvedArgs = s.cliArgs.map { resolveNet($0) }
        let toolId = s.toolId
        let binDir = freshBinDir
        let cliDeadline = scTimeout * Double(netUnits) + 60
        let outcome = await Task.detached {
            CLIToolTerminalCompare.run(tool: toolId, arguments: resolvedArgs, binDir: binDir, timeout: cliDeadline)
        }.value
        if let launchError = outcome.launchError {
            return result(s, command: command, input: .notApplicable, app: refOK, cli: outcome.exitCode,
                          output: .notApplicable, status: .cliError, appOut: refRender, note: launchError)
        }
        let cliExit = outcome.exitCode
        let cliText = combinedCLIText(outcome)

        // Semantic comparison (timing/ordering-independent): SDK reference vs CLI.
        let cmp = compareCLI(cliText, outcome.stdout, cliExit == 0)

        // PROCESS parity: the package API and the CLI must agree on success/failure.
        let cliOK = cliExit == 0
        let processMatch = (refOK == cliOK)
        let bothFailed = !refOK && !cliOK

        if !processMatch {
            return result(s, command: command, input: .match, app: refOK, cli: cliExit,
                          output: cmp.match ? .match : .differ, status: .appError,
                          appOut: refRender, cliOut: cliText, diff: cmp.diff,
                          note: "Process divergence: the DICOMKit package API \(refOK ? "succeeded" : "failed") but the \(s.toolId) CLI exited \(cliExit). The CLI and the package API must agree on the outcome.")
        }

        // Both agree on success/failure → the semantic record decides parity.
        // A both-failed-identically row is recorded as .failureAgreement (parity held
        // on the failure path, no successful operation compared) and is EXCLUDED from
        // the score so an unreachable server can't inflate the rate.
        let bothFailedIdentically = bothFailed && cmp.match
        let status: BatchRowStatus = bothFailedIdentically ? .failureAgreement
                                   : (cmp.match ? .pass : .outputDrift)
        let note: String
        switch status {
        case .failureAgreement:
            note = "The package API and the CLI both reported failure identically (e.g. server unreachable or AE not recognised) — parity held on the failure path, but no successful operation occurred, so this row is excluded from the score."
        case .pass:
            note = "The \(s.toolId) CLI matches the DICOMKit package API reference (semantic outcome; timing/ordering ignored)."
        default:
            note = "The \(s.toolId) CLI diverges from the DICOMKit package API reference (see diff; timing/ordering ignored)."
        }
        return result(s, command: command, input: .match, app: refOK, cli: cliExit,
                      output: cmp.match ? .match : .differ,
                      status: status,
                      appOut: refRender, cliOut: cliText, diff: cmp.diff, note: note)
        #else
        return result(s, command: command, input: .match, app: nil, cli: nil,
                      output: .notApplicable, status: .cliError,
                      note: "Live CLI comparison is only available on macOS.")
        #endif
    }

    // MARK: Output reduction (byte-identical to the golden harness)

    /// Reduces a produced artifact (or stdout) to a comparable string, matching
    /// CLIAutomationTestingViewModel.compareOutput's per-artifactKind handling.
    private func reduce(artifactURL: URL?, stdout: String, kind: String) async -> String {
        guard let u = artifactURL else { return stdout }     // pure stdout tool
        let fm = FileManager.default
        switch kind {
        case "dicom-multi":
            let files = ((try? fm.contentsOfDirectory(atPath: u.path)) ?? [])
                .filter { $0.hasSuffix(".dcm") }.sorted()
            var combined = "Frames: \(files.count)\n"
            for (i, f) in files.enumerated() {
                let frame = CLIParityEngine.normalize(await dump(u.appendingPathComponent(f)), fixtureBasenames: [])
                combined += "=== frame \(i) ===\n" + frame.joined(separator: "\n") + "\n"
            }
            return combined
        case "dicom-tree":
            var rels: [String] = []
            if let en = fm.enumerator(atPath: u.path) {
                while let p = en.nextObject() as? String { if p.hasSuffix(".dcm") { rels.append(p) } }
            }
            rels.sort()
            var combined = "Files: \(rels.count)\n"
            for rel in rels {
                let frame = CLIParityEngine.normalize(await dump(u.appendingPathComponent(rel)), fixtureBasenames: [])
                combined += "=== \(rel) ===\n" + frame.joined(separator: "\n") + "\n"
            }
            return combined
        case "image-multi":   // a DIRECTORY of exported images (dicom-export bulk)
            var rels: [String] = []
            if let en = fm.enumerator(atPath: u.path) {
                while let p = en.nextObject() as? String {
                    let lp = p.lowercased()
                    if lp.hasSuffix(".png") || lp.hasSuffix(".jpg") || lp.hasSuffix(".jpeg")
                        || lp.hasSuffix(".tif") || lp.hasSuffix(".tiff") { rels.append(p) }
                }
            }
            rels.sort()
            var combined = "Images: \(rels.count)\n"
            for rel in rels {
                let h = CLIParityEngine.imageRasterHash(fileURL: u.appendingPathComponent(rel)) ?? "<image-decode-failed>"
                combined += "\(rel)\t\(h)\n"
            }
            return combined
        case "decoded-pixel-hash":
            return CLIParityEngine.decodedPixelHash(fileURL: u) ?? "<pixel-decode-failed>"
        case "image-raster-hash":
            return CLIParityEngine.imageRasterHash(fileURL: u) ?? "<image-decode-failed>"
        case "text", "uid-list":
            return (try? String(contentsOf: u, encoding: .utf8)) ?? ""
        default:   // "dicom" and "auto" → re-dump via the shared in-process dicom-info
            return await dump(u)
        }
    }

    /// Re-dumps a produced .dcm via the in-process dicom-info (shared
    /// MetadataPresenter) — the same reduction the golden harness uses, applied
    /// identically to both the app and CLI artifacts.
    private func dump(_ url: URL) async -> String {
        let info = CLIWorkshopViewModel()
        info.selectTool(id: "dicom-info")
        info.updateParameterValue(parameterID: "inputPath", value: url.path)
        await info.executeCommand()
        return info.consoleOutput
    }
}
