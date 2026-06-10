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

    /// Tools this screen can sweep (supported by the generator, non-network,
    /// execute-supported), in catalog order.
    public let availableTools: [CLIToolDefinition]
    public var selectedToolIDs: Set<String> = []

    public private(set) var inputFilePath: String? = nil
    public private(set) var inputFilePath2: String? = nil
    private var inputURL: URL? = nil
    private var inputURL2: URL? = nil

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

    public var results: [BatchScenarioResult] = []
    public var summary: BatchParitySummary = BatchParitySummary()

    public init() {
        let supported = CLIParityScenarioGenerator.supportedToolIDs
        self.availableTools = ToolCatalogHelpers.allTools().filter {
            supported.contains($0.id) && !$0.requiresNetwork &&
            CLIParityEngine.executeSupported.contains($0.id)
        }
    }

    // MARK: Derived

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
        availableTools.first { $0.id == toolId }?.displayName ?? toolId
    }

    public func inputHint(for toolId: String) -> String {
        CLIParityScenarioGenerator.inputHint(for: toolId)
    }

    public func toggleTool(_ id: String) {
        if selectedToolIDs.contains(id) { selectedToolIDs.remove(id) } else { selectedToolIDs.insert(id) }
    }

    public func selectAllTools() { selectedToolIDs = Set(availableTools.map { $0.id }) }
    public func clearToolSelection() { selectedToolIDs.removeAll() }

    public func setInputFile(url: URL) {
        inputURL = url
        inputFilePath = url.path
    }
    public func setSecondInputFile(url: URL) {
        inputURL2 = url
        inputFilePath2 = url.path
    }
    public func clearSecondInputFile() { inputURL2 = nil; inputFilePath2 = nil }

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
        let toolIds = availableTools.map { $0.id }.filter { selectedToolIDs.contains($0) }
        guard !toolIds.isEmpty else { errorMessage = "Select at least one tool to test."; return }

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

        let drift = computeDriftFlags(for: toolIds)
        var scenarios: [BatchScenario] = []
        for id in toolIds { scenarios += CLIParityScenarioGenerator.scenarios(for: id) }
        totalScenarios = scenarios.count
        guard !scenarios.isEmpty else { errorMessage = "No scenarios generated for the selected tools."; return }

        // Hold security-scoped access for the whole run (sandbox-off test build).
        let scoped = inputURL.map { ($0, $0.startAccessingSecurityScopedResource()) }
        let scoped2 = inputURL2.map { ($0, $0.startAccessingSecurityScopedResource()) }
        defer {
            if let (u, ok) = scoped, ok { u.stopAccessingSecurityScopedResource() }
            if let (u, ok) = scoped2, ok { u.stopAccessingSecurityScopedResource() }
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
            appOutput: appOut, cliOutput: cliOut, diff: diff, note: note)
    }

    private func runScenario(_ s: BatchScenario, driftSet: Set<String>) async -> BatchScenarioResult {
        let fm = FileManager.default
        let file1 = inputFilePath ?? ""
        let file2 = (inputFilePath2?.isEmpty == false ? inputFilePath2! : inputFilePath) ?? ""

        // Structural skips (not parity defects).
        if s.needsInputFile && file1.isEmpty {
            return result(s, command: s.toolId, input: .notApplicable, app: nil, cli: nil,
                          output: .notApplicable, status: .skipped,
                          note: "Provide an input file (\(s.inputHint)) to run \(s.toolId).")
        }
        // Directory-input tools (e.g. dicom-study organize, dicom-archive) reject a
        // single file with a cryptic exit — surface a clear note instead of a bare skip.
        if s.needsDirectory && !file1.isEmpty {
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: file1, isDirectory: &isDir)
            if !exists || !isDir.boolValue {
                return result(s, command: s.toolId, input: .notApplicable, app: nil, cli: nil,
                              output: .notApplicable, status: .skipped,
                              note: "\(s.toolId) needs a study DIRECTORY (a folder of DICOM files); you selected a single file. Pick a folder as the input.")
            }
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

        let isDir = s.artifactKind == "dicom-multi" || s.artifactKind == "dicom-tree"
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

        // gen-skip net: an auto combo the CLI rejects (nonzero AND produced nothing).
        if cliExit != 0 && cliProducedNothing {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .skipped,
                          note: "CLI rejected this combination (exit \(cliExit)) — not applicable to this input.")
        }
        // Exit-status reconciliation. For most tools any nonzero CLI exit is an
        // error. But "diff-style" tools (dicom-diff) use a nonzero exit as a RESULT
        // (exit 1 = files differ), and the app mirrors it — so when BOTH sides agree
        // on a nonzero result we still compare their outputs (parity is agreement).
        let resultExit = CLIParityScenarioGenerator.resultExitTools.contains(s.toolId)
        let cliOK = cliExit == 0
        if !cliOK && !resultExit {
            let stderr = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .cliError,
                          appOut: appConsole, cliOut: outcome.stdout,
                          note: "CLI exited \(cliExit)" + (stderr.isEmpty ? "." : ": \(String(stderr.prefix(300)))"))
        }
        if cliOK && !appSuccess {
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .appError,
                          appOut: appConsole, cliOut: outcome.stdout,
                          note: "The app reported an error while the CLI succeeded.")
        }
        if !cliOK && appSuccess {
            // diff-style tool: CLI signalled a nonzero result (e.g. files differ) but
            // the app reported success — an exit-status divergence (real parity miss).
            return result(s, command: command, input: .match, app: appSuccess, cli: cliExit,
                          output: .notApplicable, status: .appError,
                          appOut: appConsole, cliOut: outcome.stdout,
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
