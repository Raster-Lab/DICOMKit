// StudioParityTests.swift
//
// Tier-2 output-parity harness (Wave 1). Drives the in-app Studio
// reimplementations (CLIWorkshopViewModel.executeCommand, via
// CLIAutomationTestingViewModel.runOutputVerification) headlessly against the
// bundled CLI goldens and diffs the normalized output.
//
// Regenerate goldens first, then rebuild so the new bundle is picked up:
//   swift run cli-parity-gen
//   swift test --filter StudioParityTests
//
// PHI: the real fixture (and therefore golden stdout / diff lines) can contain
// patient data, so this test prints ONLY scenario ids, statuses, and line
// COUNTS — never raw output content. Set PARITY_STRICT=1 to fail on DIFFERS.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
final class StudioParityTests: XCTestCase {

    func testWave1OutputParity() async throws {
        let goldens = CLIParityEngine.loadGoldens()
        try XCTSkipIf(goldens.isEmpty,
            "No bundled goldens. Run `swift run cli-parity-gen` then rebuild DICOMStudio.")

        let toolIDs = Set(goldens.map { $0.toolId }).sorted()
        let vm = CLIAutomationTestingViewModel()

        var comparisons: [OutputComparison] = []
        for toolID in toolIDs {
            await vm.runOutputVerification(for: toolID)
            comparisons.append(contentsOf: vm.outputComparisons)
        }

        // --- PHI-safe report (status + counts only) ---
        var match = 0, differs = 0, unavailable = 0, error = 0
        print("\n=== Tier-2 Wave 1 output parity (\(comparisons.count) scenarios) ===")
        for c in comparisons.sorted(by: { $0.scenarioId < $1.scenarioId }) {
            let cliOnly = c.diff.filter { $0.kind == .cliOnly }.count
            let studioOnly = c.diff.filter { $0.kind == .studioOnly }.count
            let detail: String
            switch c.status {
            case .match:       match += 1;       detail = ""
            case .differs:     differs += 1;     detail = "  (cliOnly=\(cliOnly) studioOnly=\(studioOnly))"
            case .unavailable: unavailable += 1; detail = "  (\(c.note))"
            case .error:       error += 1;       detail = "  (\(c.note))"
            }
            let id = c.scenarioId.split(separator: "_", omittingEmptySubsequences: true).suffix(3).joined(separator: "_")
            print(String(format: "[%-11@] %@%@", c.status.displayName as NSString, id, detail))
        }
        print("--- MATCH=\(match) DIFFERS=\(differs) UNAVAILABLE=\(unavailable) ERROR=\(error) ---\n")

        // Machine-readable emission (full content incl. diffs — may contain PHI,
        // so opt-in via env and write to a caller-chosen path, never committed).
        if let out = ProcessInfo.processInfo.environment["STUDIO_PARITY_OUT"], !out.isEmpty {
            var lines: [String] = []
            for c in comparisons {
                let obj: [String: Any] = [
                    "scenarioId": c.scenarioId, "toolId": c.toolId,
                    "status": c.status.rawValue, "note": c.note,
                    "diff": c.diff.map { ["kind": $0.kind.rawValue, "text": $0.text] },
                ]
                if let d = try? JSONSerialization.data(withJSONObject: obj),
                   let s = String(data: d, encoding: .utf8) { lines.append(s) }
            }
            try? lines.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
            print("wrote \(comparisons.count) results -> \(out)")
        }

        // The harness itself must not error (missing fixture, crash, no case).
        XCTAssertEqual(error, 0, "\(error) scenario(s) errored — the harness/fixtures are broken, not a parity diff.")

        // All wired W1 tools should be runnable (no UNAVAILABLE for the bundled set).
        XCTAssertEqual(unavailable, 0, "\(unavailable) scenario(s) unavailable — executeSupported is out of sync with executeCommand().")

        // --- Allowlist-aware gate ---
        // KNOWN, triaged DIFFERS live in parity-allowlist.json. A DIFFERS not on
        // the list is new drift or a regression of a fixed bug. An allowlisted
        // scenario that now MATCHES is a stale entry to remove.
        let allow = Self.loadAllowlist()
        let unexpected = comparisons.filter { $0.status == .differs && allow[$0.scenarioId] == nil }
        let stale = comparisons.filter { $0.status == .match && allow[$0.scenarioId] != nil }
        for u in unexpected { print("‼️ un-allowlisted DIFFERS: \(u.scenarioId)") }
        for s in stale { print("⚠️ stale allowlist entry (now MATCHES — remove it): \(s.scenarioId)") }

        // Strict mode (CI gate): fail on un-allowlisted DIFFERS and stale entries.
        if ProcessInfo.processInfo.environment["PARITY_STRICT"] == "1" {
            XCTAssertTrue(unexpected.isEmpty,
                "Parity gate FAILED — \(unexpected.count) un-allowlisted DIFFERS:\n"
                + unexpected.map { "  • \($0.scenarioId)" }.joined(separator: "\n")
                + "\nFix the Studio reimplementation, or (if intentional) add to parity-allowlist.json with a reason.")
            XCTAssertTrue(stale.isEmpty,
                "Parity gate — \(stale.count) allowlisted scenario(s) now MATCH; delete them from parity-allowlist.json:\n"
                + stale.map { "  • \($0.scenarioId)" }.joined(separator: "\n"))
        }

        // --- Coverage ratchet (Phase 4) ---
        // Output-flag coverage = accepted CLI flags exercised by >=1 golden scenario, over the
        // SAME golden set the gate ran (in CI that's the committed goldens.synthetic.json). With
        // PARITY_COVERAGE_MIN set, fail when coverage drops below the floor — so removing a
        // scenario or adding a flag without coverage is caught, and coverage can only ratchet up.
        if let contracts = CLIParityEngine.loadContracts() {
            let results = CLIParityEngine.compareAll(contracts: contracts)
            let scenariosByTool = Dictionary(grouping: goldens, by: { $0.toolId })
            var accepted = 0, covered = 0
            for r in results where r.executeSupported {
                let scen = scenariosByTool[r.toolId] ?? []
                for row in r.rows where row.inCLI {
                    accepted += 1
                    if scen.contains(where: { $0.cliArgs.contains(row.flag) }) { covered += 1 }
                }
            }
            let pct = accepted > 0 ? (Double(covered) / Double(accepted) * 1000).rounded() / 10 : 0
            print("--- COVERAGE=\(covered)/\(accepted) (\(pct)%) output-flag ---")
            if let minStr = ProcessInfo.processInfo.environment["PARITY_COVERAGE_MIN"], let floor = Double(minStr) {
                XCTAssertGreaterThanOrEqual(pct, floor,
                    "Output-flag coverage \(pct)% is below the PARITY_COVERAGE_MIN floor of \(floor)% — a covered scenario was removed, or a flag was added without coverage. Add a scenario, or lower the floor deliberately.")
            }
        }
    }

    /// Loads the committed gate allowlist (scenarioId → reason) from the bundle.
    private static func loadAllowlist() -> [String: String] {
        guard let url = CLIParityEngine.bundledURL("parity-allowlist", "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let allow = obj["allow"] as? [String: String] else { return [:] }
        return allow
    }
}
