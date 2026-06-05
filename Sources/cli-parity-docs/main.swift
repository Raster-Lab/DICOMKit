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

/// Output status for one flag, aggregated over the scenarios that exercise it.
private enum FlagOutput {
    case notWired, notCovered, success, drift, flaky(String)
    var cell: String {
        switch self {
        case .notWired:     return "— not wired"
        case .notCovered:   return "⊘ not covered"
        case .success:      return "✅ success"
        case .drift:        return "❌ DRIFT"
        case .flaky(let s): return "⚠️ \(s)"
        }
    }
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
                        wired: Bool,
                        scenarios: [GoldenScenario],
                        status: [String: OutputParityStatus]) -> FlagOutput {
    guard wired else { return .notWired }
    let covering = scenarios.filter { $0.cliArgs.contains(flag) }
    guard !covering.isEmpty else { return .notCovered }
    let sts = covering.map { status[$0.scenarioId] ?? .unavailable }
    if sts.contains(.differs) { return .drift }
    if sts.contains(.error) { return .flaky("error") }
    if sts.allSatisfy({ $0 == .unavailable }) { return .notCovered }
    if sts.contains(where: { $0 == .match }) { return .success }
    return .flaky("unavailable")
}

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

    // Per-flag matrix
    md += "## Flags\n\n"
    md += "| Flag | Kind | Input (UI ↔ CLI) | Output (UI vs CLI) |\n"
    md += "|---|---|---|---|\n"
    for row in r.rows.sorted(by: { $0.flag < $1.flag }) {
        let out = flagOutput(flag: row.flag, wired: r.executeSupported, scenarios: scenarios, status: status)
        md += "| `\(row.flag)` | \(row.kind) | \(inputCell(row.status)) | \(out.cell) |\n"
    }
    if r.rows.isEmpty { md += "| _(no flag-bearing options)_ | | | |\n" }

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
    md += "_Output:_ ✅ success · ❌ drift · ⊘ not covered · — not wired. "
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
    md += "\n> **Output coverage caveat:** a flag counts as output-tested only if a golden "
    md += "scenario exercises it. Flags marked `⊘ not covered` are a known gap (the silent-coverage "
    md += "issue) — contract-driven auto-generation (plan Phase 2) drives this to zero.\n"
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
    readme += "**\(totCovered) / \(totAccepted) CLI flags (\(totPct)%)** are exercised by ≥1 output scenario "
    readme += "across \(wiredCount) wired tools. The rest are the silent-coverage gap (the `⊘ not covered` "
    readme += "flags above) — contract-driven auto-generation (plan Phase 2) drives this toward 100%. "
    readme += "Machine-readable per-tool detail (incl. each tool's `uncoveredFlags`) is in `coverage.json`.\n"
    try? readme.write(to: outDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

    err("cli-parity-docs: output-flag coverage = \(totCovered)/\(totAccepted) (\(totPct)%) across \(wiredCount) wired tools")
    err("cli-parity-docs: wrote \(results.count) tool docs + README + coverage.json to \(outDir.path)")
}

await generate()
