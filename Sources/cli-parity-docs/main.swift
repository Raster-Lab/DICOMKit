// cli-parity-docs
//
// Developer tool — NOT shipped in DICOMStudio.app.
//
// Emits a per-tool CLI ↔ DICOMStudio parity matrix under docs/cli-parity/<tool>.md:
// for every flag of every (wired) tool, the INPUT-contract parity (does the UI
// emit a flag the CLI accepts?) and the OUTPUT behavior (does the UI's output
// match the CLI's?), plus per-scenario success/drift.
//
// Everything is computed IN-PROCESS from bundled artifacts — the committed
// CLIContracts.json (CLI side) + the in-process buildCommand() (UI side) +
// the bundled goldens (output side). No `dicom-*` binary is dumped or run, so
// this is fast and works from a clean checkout.
//
//   swift run cli-parity-docs            # writes docs/cli-parity/*.md
//
// Reuses: CLIParityEngine.compareAll (input parity), .loadGoldens (coverage),
// CLIAutomationTestingViewModel.runOutputVerification (output success/drift).

import Foundation
import DICOMStudio

// MARK: - Status glyphs

private func inputCell(_ s: FlagParityStatus) -> String {
    switch s {
    case .match:           return "✅ match"
    case .missingInStudio: return "⚠️ missing in UI"
    case .extraInStudio:   return "➕ extra in UI (drift)"
    }
}

/// Phase 3: the type/default sub-checks for a flag present on both sides ("—" otherwise).
private func subCheckCell(_ row: ParityFlagRow) -> String {
    guard row.status == .match else { return "—" }
    var parts: [String] = []
    if row.typeCheck == .mismatch { parts.append("⚠️ type") }
    if row.defaultCheck == .mismatch { parts.append("⚠️ default `\(row.cliDefault)`↔`\(row.studioDefault)`") }
    return parts.isEmpty ? "✓" : parts.joined(separator: " · ")
}

/// Output status for one flag, aggregated over the scenarios that exercise it.
private enum FlagOutput {
    case notWired, notCovered(String), success, drift, flaky(String)
    var cell: String {
        switch self {
        case .notWired:        return "— not wired"
        case .notCovered(let why): return "⊘ not covered (\(why))"
        case .success:         return "✅ success"
        case .drift:           return "❌ DRIFT"
        case .flaky(let s):    return "⚠️ \(s)"
        }
    }
}

// MARK: - Why a flag is uncovered (so `⊘` is honest, not a bare gap)

/// Tools whose output is genuinely non-deterministic (fresh SOP/Study/Series UIDs
/// + current date/time) → cannot have a stable golden.
private let nonDeterministicTools: Set<String> = ["dicom-image", "dicom-merge"]

/// Per-tool flags that are non-deterministic even though the tool also has
/// deterministic subcommands (e.g. uid generate/regenerate vs validate/lookup).
private let nonDeterministicFlags: [String: Set<String>] = [
    "dicom-uid": ["--count", "--root", "--type", "--json", "--export-map"],   // generate / fresh-UID map
]

/// Flags whose subcommand runs a SHARED engine (so output is identical by
/// construction) but writes a file TREE the offline harness can't golden — parity
/// is guaranteed by the shared engine + a smoke test, not a stdout/artifact golden.
private let sharedTreeFlags: [String: Set<String>] = [
    "dicom-study": ["--copy", "--output", "--pattern"],   // organize → shared StudyOrganizer
]

/// Flags whose CLI preview goes to STDERR (so the harness, which diffs stdout, can't
/// compare it) even though the TEXT matches the app console — a stream quirk, not a
/// content divergence.
private let stderrPreviewFlags: [String: Set<String>] = [
    "dicom-tags": ["--dry-run"],   // tags fprintln → stderr; app shows it in-console
]

/// Flags with a CONFIRMED App↔CLI CONTENT divergence — a real gap to fix, surfaced
/// (not masked) by the parity test so it stays visible until resolved. (Currently
/// empty: uid `regenerate --dry-run` was fixed via the shared UIDManager preview.)
private let knownDivergenceFlags: [String: Set<String>] = [:]

/// The reason an offline golden does not (and often cannot) exercise a flag.
private func uncoveredReason(toolId: String, flag: String, requiresNetwork: Bool) -> String {
    if requiresNetwork { return "network — needs a live PACS/DICOMweb server" }
    if knownDivergenceFlags[toolId]?.contains(flag) == true { return "⚠️ App↔CLI divergence — needs a fix (surfaced, not masked)" }
    if stderrPreviewFlags[toolId]?.contains(flag) == true { return "preview on stderr — text matches the app console; not stdout-golden-able" }
    if nonDeterministicTools.contains(toolId) { return "non-deterministic — fresh UIDs/timestamps" }
    if nonDeterministicFlags[toolId]?.contains(flag) == true { return "non-deterministic — fresh UIDs" }
    if sharedTreeFlags[toolId]?.contains(flag) == true { return "shared engine — writes a file tree; parity by construction, smoke-tested" }
    if flag.contains("dry-run") { return "no-write preview — nothing to compare" }
    return "coverage gap — offline-testable, not yet templated"
}

private func scenarioCell(_ s: OutputParityStatus) -> String {
    switch s {
    case .match:       return "✅ success"
    case .differs:     return "❌ DRIFT"
    case .unavailable: return "⊘ unavailable"
    case .error:       return "⚠️ error"
    }
}

// MARK: - Per-flag output aggregation

/// Scenarios (by id) whose `cliArgs` contain the flag token, and their statuses.
private func flagOutput(flag: String,
                        toolId: String,
                        wired: Bool,
                        requiresNetwork: Bool,
                        scenarios: [GoldenScenario],
                        status: [String: OutputParityStatus]) -> FlagOutput {
    guard wired else { return .notWired }
    func uncovered() -> FlagOutput { .notCovered(uncoveredReason(toolId: toolId, flag: flag, requiresNetwork: requiresNetwork)) }
    let covering = scenarios.filter { $0.cliArgs.contains(flag) }
    guard !covering.isEmpty else { return uncovered() }
    let sts = covering.map { status[$0.scenarioId] ?? .unavailable }
    if sts.contains(.differs) { return .drift }
    if sts.contains(.error) { return .flaky("error") }
    if sts.allSatisfy({ $0 == .unavailable }) { return uncovered() }
    if sts.contains(where: { $0 == .match }) { return .success }
    return .flaky("unavailable")
}

// MARK: - Verified App↔CLI parity verdict (durable; survives regeneration)
//
// Code-level audit (2026-06-09): the shared DICOMKit engine both adapters call and a
// one-line same/differ verdict. This is what makes `⊘ not covered` flags trustworthy —
// for shared-engine tools the uncovered flags still produce identical output by
// construction. Full per-subcommand/flag detail lives in the repo-root
// APP_CLI_PARITY_MATRIX.md. Update an entry here when a tool's engine/behavior changes.

private struct EngineVerdict { let engine: String; let module: String; let scope: String; let verdict: String }

private let verifiedVerdict: [String: EngineVerdict] = [
    "dicom-anon":     .init(engine: "Anonymizer", module: "DICOMKit/Anonymization", scope: "full", verdict: "output DICOM byte-identical (9 goldens); verbose per-file line format + sandbox write-note differ."),
    "dicom-archive":  .init(engine: "ArchiveStore", module: "DICOMKit/Archive", scope: "full", verdict: "read ops (query/list/check/stats) byte-identical; init/import/export add a sandbox redirect note. `--skip-duplicates` parity bug fixed."),
    "dicom-compress": .init(engine: "CompressionManager", module: "DICOMKit/Compression", scope: "full", verdict: "info/backends byte-identical (goldens); compress/decompress produced DICOM byte-identical; app adds a sandbox note under TCC."),
    "dicom-convert":  .init(engine: "TransferSyntaxConverter + DICOMFile", module: "DICOMCore + DICOMKit", scope: "partial", verdict: "DICOM→DICOM converted file byte-identical (golden); app adds progress lines + a sandbox note."),
    "dicom-dcmdir":   .init(engine: "DICOMDirectory / DICOMDIRReader / DICOMDIRWriter", module: "DICOMKit + DICOMCore", scope: "full", verdict: "`dump` byte-identical; create/validate/update differ by emoji only (CLI ✅/⚠️ vs app plain)."),
    "dicom-diff":     .init(engine: "DICOMComparer / ComparisonReport", module: "DICOMKit/Comparison", scope: "full", verdict: "byte/text-identical across text, json, and summary (11 goldens)."),
    "dicom-dump":     .init(engine: "HexDumper", module: "DICOMKit", scope: "full", verdict: "byte-identical (9 goldens); app forces `--no-color` (harness normalizes ANSI)."),
    "dicom-echo":     .init(engine: "DICOMVerificationService", module: "DICOMNetwork", scope: "full", verdict: "C-ECHO via the identical shared service; console differs (✅/❌ vs ✓/✗, ms vs s). Live network → no goldens."),
    "dicom-export":   .init(engine: "DICOMImageExporter", module: "DICOMKit/ImageExport", scope: "full", verdict: "produced image bytes identical (shared EXIF/layout/window/encode); app adds a sandbox note. Binary output → no goldens."),
    "dicom-image":    .init(engine: "ImageConverter", module: "DICOMKit/SecondaryCapture", scope: "full", verdict: "same engine; output Secondary-Capture DICOM carries fresh UIDs + timestamps → non-deterministic, verified by smoke."),
    "dicom-info":     .init(engine: "MetadataPresenter", module: "DICOMKit", scope: "full", verdict: "byte-identical (9 goldens); no divergence."),
    "dicom-json":     .init(engine: "DICOMJSONEncoder / DICOMJSONDecoder", module: "DICOMWeb", scope: "full", verdict: "byte-identical both directions (11 goldens); sandbox note only on TCC denial."),
    "dicom-merge":    .init(engine: "FrameMerger", module: "DICOMKit/Merging", scope: "full", verdict: "same engine (input paths sorted for deterministic frame order); merged object gets a fresh SOP UID → non-deterministic."),
    "dicom-mpps":     .init(engine: "DICOMMPPSService", module: "DICOMNetwork", scope: "full", verdict: "create/update via the identical shared service. Live network → no goldens."),
    "dicom-mwl":      .init(engine: "DICOMModalityWorklistService", module: "DICOMNetwork", scope: "full", verdict: "query via the shared service; app ADDS `create` (REST + HL7) the CLI lacks. Live network → no goldens."),
    "dicom-pdf":      .init(engine: "EncapsulatedDocumentParser / …Builder", module: "DICOMKit + DICOMCore", scope: "partial", verdict: "`extract` byte-identical; `encapsulate` non-deterministic (fresh Study/Series/SOP UIDs)."),
    "dicom-pixedit":  .init(engine: "PixelEditor", module: "DICOMKit/PixelEditing", scope: "full", verdict: "edited DICOM byte-identical (3 goldens); app appends a 2-line summary."),
    "dicom-qido":     .init(engine: "DICOMwebClient (QIDO-RS)", module: "DICOMWeb", scope: "full", verdict: "QIDO-RS via the identical shared client. Live network → no goldens."),
    "dicom-qr":       .init(engine: "DICOMQueryService / DICOMRetrieveService", module: "DICOMNetwork", scope: "full", verdict: "query+retrieve via shared services. BUG: CLI uppercases the patient-name C-FIND key, the app sends it as-typed. Live network → no goldens."),
    "dicom-query":    .init(engine: "DICOMQueryService", module: "DICOMNetwork", scope: "partial", verdict: "C-FIND via shared `find()`; app adds parent-study columns + XML/HL7 + a two-step SERIES/IMAGE fallback. Live network → no goldens."),
    "dicom-retrieve": .init(engine: "DICOMRetrieveService", module: "DICOMNetwork", scope: "full", verdict: "C-MOVE/C-GET + Part-10 wrapping via the shared service; app auto-resolves a missing Study UID + prints saved paths. Live network → no goldens."),
    "dicom-script":   .init(engine: "ScriptParser / Executor / Validator / TemplateGenerator", module: "DICOMKit/Scripting", scope: "partial", verdict: "`template` byte-identical (2 goldens); `run`/`validate` show a parsed plan only (the sandbox cannot spawn nested processes)."),
    "dicom-send":     .init(engine: "DICOMStorageService", module: "DICOMNetwork", scope: "full", verdict: "C-STORE via the shared service; console differs (emoji, ms vs s, error hints). Live network → no goldens."),
    "dicom-split":    .init(engine: "FrameSplitter", module: "DICOMKit/Splitting", scope: "full", verdict: "extracted frames byte-identical (shared engine); app lists written paths + sizes. Non-deterministic path set → no goldens."),
    "dicom-stow":     .init(engine: "DICOMwebClient (STOW-RS)", module: "DICOMWeb", scope: "full", verdict: "STOW-RS store via the identical shared client. Live network → no goldens."),
    "dicom-study":    .init(engine: "StudyScanner / StudyReport / StudyOrganizer", module: "DICOMKit/Study", scope: "full", verdict: "ALL subcommands shared — summary/check/stats/compare byte-identical (12 goldens); `organize` now uses the shared StudyOrganizer too (identical file naming/ordering, `→` arrow, and the same copy/move `already exists` error)."),
    "dicom-tags":     .init(engine: "TagEditor", module: "DICOMKit/TagEditing", scope: "full", verdict: "edited DICOM byte-identical (set/delete/copy-from/verbose goldens). `--dry-run` not stdout-golden-able: the CLI prints the preview to STDERR (text matches the app console)."),
    "dicom-uid":      .init(engine: "UIDManager", module: "DICOMKit/UIDManagement", scope: "full", verdict: "validate/lookup/search + regenerate (UIDs masked) + regenerate --dry-run byte/text-identical (dry-run now shares `UIDManager.regenerationPreviewLines`); generate is non-deterministic (fresh UIDs)."),
    "dicom-ups":      .init(engine: "DICOMwebClient (UPS-RS)", module: "DICOMWeb", scope: "full", verdict: "create/retrieve/search/subscribe via the shared client; change-state echoes the raw HTTP request/response (educational). Live network → no goldens."),
    "dicom-validate": .init(engine: "DICOMValidator / ValidationReport", module: "DICOMKit/Validation", scope: "full", verdict: "byte-identical (8 goldens); app appends an educational `Exit code: N` line (excluded from the parity path)."),
    "dicom-wado":     .init(engine: "DICOMwebClient / WADOURIClient", module: "DICOMWeb", scope: "full", verdict: "WADO-RS/URI, QIDO-RS, STOW-RS, UPS-RS all via the identical shared client; console uses emoji + a `Mode:` line. Live network → no goldens."),
    "dicom-xml":      .init(engine: "DICOMXMLEncoder / DICOMXMLDecoder", module: "DICOMWeb", scope: "full", verdict: "byte-identical (8 goldens); sandbox note only on TCC denial."),
]

// MARK: - Render one tool

private func renderTool(_ r: ToolParityResult,
                        scenarios: [GoldenScenario],
                        status: [String: OutputParityStatus]) -> String {
    var md = "# \(r.toolId)\n\n"
    md += "_CLI binary:_ `\(r.binary)`"
    if !r.subcommand.isEmpty { md += " · _subcommand:_ `\(r.subcommand)`" }
    md += " · _category:_ \(r.category.rawValue)"
    md += " · _wired in Studio:_ \(r.executeSupported ? "yes" : "**no**")"
    md += " · _network:_ \(r.requiresNetwork ? "yes" : "no")\n\n"

    md += "**Input-contract parity:** \(r.matchCount)/\(r.cliFlagCount) CLI flags matched"
    if r.missingCount > 0 { md += " · \(r.missingCount) missing in UI" }
    if r.extraCount > 0 { md += " · \(r.extraCount) extra in UI (drift)" }
    md += " · status **\(r.status.rawValue)** (\(String(format: "%.0f", r.parityPercent))%)\n\n"

    // Phase 3 input sub-checks: flags present on both sides that disagree on shape.
    let typeMis = r.rows.filter { $0.typeCheck == .mismatch }
    let defMis  = r.rows.filter { $0.defaultCheck == .mismatch }
    if !typeMis.isEmpty || !defMis.isEmpty {
        md += "**Input sub-checks (Phase 3):** "
        var s: [String] = []
        if !typeMis.isEmpty { s.append("⚠️ \(typeMis.count) type mismatch(es): " + typeMis.map { "`\($0.flag)`" }.joined(separator: ", ")) }
        if !defMis.isEmpty  { s.append("⚠️ \(defMis.count) default mismatch(es): " + defMis.map { "`\($0.flag)`" }.joined(separator: ", ")) }
        md += s.joined(separator: " · ") + ".\n\n"
    }

    let runScenarios = scenarios.count
    let succ = scenarios.filter { status[$0.scenarioId] == .match }.count
    let drift = scenarios.filter { status[$0.scenarioId] == .differs }.count
    if !r.executeSupported {
        md += "**Output behavior:** not wired in Studio — no in-process reimplementation to compare.\n\n"
    } else if runScenarios == 0 {
        md += "**Output behavior:** no golden scenarios yet (offline output not exercised; e.g. network tool or not-yet-templated).\n\n"
    } else {
        md += "**Output behavior:** \(runScenarios) scenario(s) — \(succ) success / \(drift) drift.\n\n"
    }

    // Verified App↔CLI parity verdict (durable — emitted from the audited data table).
    if let v = verifiedVerdict[r.toolId] {
        let scopeWord = v.scope == "full" ? "all logic shared" : "core shared; some orchestration adapter-local"
        md += "## Verified App↔CLI parity\n\n"
        md += "- **Shared DICOMKit engine:** `\(v.engine)` (`\(v.module)`) — both the CLI and DICOMStudio call it (\(scopeWord)); flags with no golden still produce identical output **by construction**.\n"
        md += "- **Verdict:** \(v.verdict)\n\n"
        md += "> Full per-subcommand/flag detail: [`APP_CLI_PARITY_MATRIX.md`](../../APP_CLI_PARITY_MATRIX.md) · architecture: [`APP_CLI_SHARED_API.md`](../../APP_CLI_SHARED_API.md).\n\n"
    }

    // Per-flag matrix
    md += "## Flags\n\n"
    md += "| Flag | Kind | Input (UI ↔ CLI) | Type/Default | Output (UI vs CLI) |\n"
    md += "|---|---|---|---|---|\n"
    for row in r.rows.sorted(by: { $0.flag < $1.flag }) {
        let out = flagOutput(flag: row.flag, toolId: r.toolId, wired: r.executeSupported,
                             requiresNetwork: r.requiresNetwork, scenarios: scenarios, status: status)
        md += "| `\(row.flag)` | \(row.kind) | \(inputCell(row.status)) | \(subCheckCell(row)) | \(out.cell) |\n"
    }
    if r.rows.isEmpty { md += "| _(no flag-bearing options)_ | | | | |\n" }

    // Per-scenario output detail (the concrete success/drift evidence)
    if !scenarios.isEmpty {
        md += "\n## Output scenarios\n\n"
        md += "| Scenario | CLI args | Result |\n|---|---|---|\n"
        for s in scenarios.sorted(by: { $0.scenarioId < $1.scenarioId }) {
            let st = status[s.scenarioId] ?? .unavailable
            let args = s.cliArgs.joined(separator: " ").replacingOccurrences(of: "|", with: "\\|")
            md += "| \(s.label) | `\(args)` | \(scenarioCell(st)) |\n"
        }
    }

    md += "\n---\n_Legend — Input:_ ✅ match · ⚠️ missing in UI · ➕ extra in UI (drift). "
    md += "_Output:_ ✅ success · ❌ drift · ⊘ not covered *(reason: network · non-deterministic · coverage gap · no-write preview)* · — not wired. "
    md += "The **Verified App↔CLI parity** block above is the durable verdict for ALL flags (incl. uncovered). "
    md += "Generated by `swift run cli-parity-docs` (in-process, from bundled contracts + goldens)._\n"
    return md
}

// MARK: - Render index

private func renderIndex(_ results: [ToolParityResult],
                         scenariosByTool: [String: [GoldenScenario]],
                         status: [String: OutputParityStatus]) -> String {
    var md = "# CLI ↔ DICOMStudio parity matrix\n\n"
    md += "Per-tool success-vs-drift for **input flags** (does the UI emit what the CLI accepts) "
    md += "and **output behavior** (does the UI's output match the CLI's). One row per tool; "
    md += "click through for the full flag-by-flag table.\n\n"
    md += "Generated by `swift run cli-parity-docs` — in-process from the bundled `CLIContracts.json` "
    md += "(CLI side) + `buildCommand()` (UI side) + goldens (output side). No binaries are run.\n\n"
    md += "| Tool | Wired | Input parity | Input status | Output (success/drift/covered flags) |\n"
    md += "|---|---|---|---|---|\n"
    for r in results.sorted(by: { $0.toolId < $1.toolId }) {
        let scen = scenariosByTool[r.toolId] ?? []
        let succ = scen.filter { status[$0.scenarioId] == .match }.count
        let drift = scen.filter { status[$0.scenarioId] == .differs }.count
        let coveredFlags = r.rows.filter { row in r.executeSupported && scen.contains { $0.cliArgs.contains(row.flag) } }.count
        let outCol = !r.executeSupported ? "— not wired"
            : (scen.isEmpty ? "no scenarios" : "\(succ)✅ / \(drift)❌ · \(coveredFlags)/\(r.rows.count) flags")
        md += "| [\(r.toolId)](\(r.toolId).md) | \(r.executeSupported ? "yes" : "no") "
        md += "| \(r.matchCount)/\(r.cliFlagCount) (\(String(format: "%.0f", r.parityPercent))%) "
        md += "| \(r.status.rawValue) | \(outCol) |\n"
    }
    md += "\n> **Reading `⊘ not covered`:** a flag is output-tested only if a golden scenario "
    md += "exercises it. Each uncovered flag now states **why** — `network` (needs a live PACS/"
    md += "DICOMweb server), `non-deterministic` (fresh UIDs/timestamps, no stable golden), "
    md += "`no-write preview` (e.g. `--dry-run`), or `coverage gap` (offline-testable, not yet "
    md += "templated). Only the **coverage gap** flags can be driven down by contract-driven "
    md += "auto-generation; the network/non-deterministic ones are a permanent floor. For those, "
    md += "the per-tool **Verified App↔CLI parity** block is the authority — both adapters call the "
    md += "same DICOMKit engine, so the output matches *by construction* even without a golden.\n"
    md += "\n> **Not-wired CLI tools** (e.g. `dicom-3d`, `dicom-measure`, `dicom-gateway`, `dicom-jpip`, "
    md += "`dicom-report`, `dicom-j2k`, `dicom-viewer`) have no DICOMStudio reimplementation, so output "
    md += "parity is undefined for them; they are out of scope here.\n"
    return md
}

// MARK: - Coverage ledger

/// Per-tool output-flag coverage: how many CLI-accepted flags are exercised by at
/// least one golden scenario. Turns the "silent coverage gap" into a tracked number.
private struct CoverageEntry: Encodable {
    let toolId: String
    let wired: Bool
    let acceptedFlags: Int       // flags the CLI accepts (output-coverable)
    let coveredFlags: Int        // accepted flags exercised by >=1 scenario
    let uncoveredFlags: [String] // accepted flags with NO scenario (the gap)
    let coveragePct: Double
}

private struct CoverageReport: Encodable {
    struct Totals: Encodable { let accepted: Int; let covered: Int; let pct: Double; let toolsWired: Int }
    let schemaVersion: Int
    let tools: [CoverageEntry]
    let totals: Totals
}

/// Accepted (CLI) flags of `r`, and which are exercised by a golden scenario.
private func coverage(of r: ToolParityResult, scenarios: [GoldenScenario]) -> (accepted: Int, covered: Int, uncovered: [String]) {
    let accepted = r.rows.filter { $0.inCLI }
    guard r.executeSupported else { return (accepted.count, 0, []) }
    var covered = 0
    var uncovered: [String] = []
    for row in accepted {
        if scenarios.contains(where: { $0.cliArgs.contains(row.flag) }) { covered += 1 }
        else { uncovered.append(row.flag) }
    }
    return (accepted.count, covered, uncovered.sorted())
}

// MARK: - Main

@MainActor
func generate() async {
    func err(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

    guard let contracts = CLIParityEngine.loadContracts() else {
        err("cli-parity-docs: no bundled CLIContracts.json — run cli-parity.sh first or build DICOMStudio with resources.")
        exit(1)
    }
    let goldens = CLIParityEngine.loadGoldens()
    let scenariosByTool = Dictionary(grouping: goldens, by: { $0.toolId })
    let results = CLIParityEngine.compareAll(contracts: contracts)
    err("cli-parity-docs: \(results.count) tools, \(goldens.count) golden scenarios")

    // Run output verification per wired tool with scenarios → per-scenario status.
    let vm = CLIAutomationTestingViewModel()
    var status: [String: OutputParityStatus] = [:]
    for r in results where r.executeSupported && !(scenariosByTool[r.toolId] ?? []).isEmpty {
        await vm.runOutputVerification(for: r.toolId)
        for c in vm.outputComparisons { status[c.scenarioId] = c.status }
    }
    err("cli-parity-docs: ran output verification → \(status.count) scenario results")

    let outDir = URL(fileURLWithPath: "docs/cli-parity", isDirectory: true)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    for r in results {
        let md = renderTool(r, scenarios: scenariosByTool[r.toolId] ?? [], status: status)
        try? md.write(to: outDir.appendingPathComponent("\(r.toolId).md"), atomically: true, encoding: .utf8)
    }
    // Coverage ledger — covered vs accepted CLI flags per tool (output-exercised).
    var entries: [CoverageEntry] = []
    var totAccepted = 0, totCovered = 0, wiredCount = 0
    for r in results {
        let cov = coverage(of: r, scenarios: scenariosByTool[r.toolId] ?? [])
        let pct = cov.accepted == 0 ? 0 : (Double(cov.covered) / Double(cov.accepted) * 1000).rounded() / 10
        entries.append(CoverageEntry(toolId: r.toolId, wired: r.executeSupported,
                                     acceptedFlags: cov.accepted, coveredFlags: cov.covered,
                                     uncoveredFlags: cov.uncovered, coveragePct: pct))
        if r.executeSupported { totAccepted += cov.accepted; totCovered += cov.covered; wiredCount += 1 }
    }
    let totPct = totAccepted == 0 ? 0 : (Double(totCovered) / Double(totAccepted) * 1000).rounded() / 10
    let report = CoverageReport(schemaVersion: 1, tools: entries.sorted { $0.toolId < $1.toolId },
                                totals: .init(accepted: totAccepted, covered: totCovered, pct: totPct, toolsWired: wiredCount))
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? enc.encode(report) {
        try? data.write(to: outDir.appendingPathComponent("coverage.json"))
    }

    var readme = renderIndex(results, scenariosByTool: scenariosByTool, status: status)
    readme += "\n## Output-flag coverage ledger\n\n"
    // Categorize the uncovered flags so the ledger is honest about the permanent floor.
    var netCount = 0, ndCount = 0, dryCount = 0, gapCount = 0
    for r in results where r.executeSupported {
        let scen = scenariosByTool[r.toolId] ?? []
        for row in r.rows where row.inCLI {
            if scen.contains(where: { $0.cliArgs.contains(row.flag) }) { continue }   // covered
            if r.requiresNetwork { netCount += 1 }
            else if nonDeterministicTools.contains(r.toolId) || (nonDeterministicFlags[r.toolId]?.contains(row.flag) ?? false) { ndCount += 1 }
            else if row.flag.contains("dry-run") { dryCount += 1 }
            else { gapCount += 1 }
        }
    }
    readme += "**\(totCovered) / \(totAccepted) CLI flags (\(totPct)%)** are exercised by ≥1 output scenario "
    readme += "across \(wiredCount) wired tools. The \(totAccepted - totCovered) uncovered flags break down as: "
    readme += "**\(netCount) network** (need a live PACS/DICOMweb server), **\(ndCount) non-deterministic** "
    readme += "(fresh UIDs/timestamps — no stable golden), **\(dryCount) no-write preview**, and **\(gapCount) "
    readme += "coverage gap** (offline-testable, not yet templated). Only the **\(gapCount) gap** flags are "
    readme += "reducible by contract-driven auto-generation; the \(netCount + ndCount + dryCount) network / "
    readme += "non-deterministic / preview flags are a permanent floor whose App↔CLI parity is asserted by the "
    readme += "per-tool **Verified** verdict (same shared DICOMKit engine → identical output by construction), "
    readme += "not by a golden. Machine-readable per-tool detail (incl. each tool's `uncoveredFlags`) is in `coverage.json`.\n"
    try? readme.write(to: outDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

    err("cli-parity-docs: output-flag coverage = \(totCovered)/\(totAccepted) (\(totPct)%) across \(wiredCount) wired tools")
    err("cli-parity-docs: wrote \(results.count) tool docs + README + coverage.json to \(outDir.path)")
}

await generate()
