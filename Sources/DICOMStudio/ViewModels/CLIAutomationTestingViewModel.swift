// CLIAutomationTestingViewModel.swift
// DICOMStudio
//
// Drives the CLI Automation Testing screen. 100% Swift-native:
//   * Param-mismatch parity is computed in-process by CLIParityEngine against
//     the bundled CLIContracts.json.
//   * Output (input/output) verification drives a CLIWorkshopViewModel in-process
//     on the bundled fixture and diffs its console output against bundled golden
//     CLI output — no external processes.

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class CLIAutomationTestingViewModel {

    private let service: CLIAutomationTestingService

    // Parity results
    public var results: [ToolParityResult] = []
    public var selectedToolID: String? = nil
    public var searchText: String = ""

    // Loading / status
    public var isAnalyzing: Bool = false
    public var isRunningOutput: Bool = false
    public var hasLoaded: Bool = false
    public var contractsAvailable: Bool = true
    public var errorMessage: String? = nil

    // Output comparisons for the selected tool
    public var outputComparisons: [OutputComparison] = []

    public init(service: CLIAutomationTestingService = CLIAutomationTestingService()) {
        self.service = service
    }

    // MARK: - Derived

    public var filteredResults: [ToolParityResult] {
        let base = results
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter { $0.toolId.lowercased().contains(q) || $0.displayName.lowercased().contains(q) }
    }

    public var selectedResult: ToolParityResult? {
        guard let id = selectedToolID else { return nil }
        return results.first { $0.toolId == id }
    }

    /// Results grouped by CLI Workshop tab, in the same order as the CLI Workshop
    /// screen (CLIWorkshopTab.allCases), with catalog order preserved within each.
    public var groupedResults: [(tab: CLIWorkshopTab, tools: [ToolParityResult])] {
        let filtered = filteredResults
        var out: [(CLIWorkshopTab, [ToolParityResult])] = []
        for tab in CLIWorkshopTab.allCases {
            let tools = filtered.filter { $0.category == tab }
            if !tools.isEmpty { out.append((tab, tools)) }
        }
        return out
    }

    public var summary: (ok: Int, drift: Int, incomplete: Int, noParams: Int, noCli: Int) {
        var s = (ok: 0, drift: 0, incomplete: 0, noParams: 0, noCli: 0)
        for r in results {
            switch r.status {
            case .ok: s.ok += 1
            case .drift: s.drift += 1
            case .incomplete: s.incomplete += 1
            case .noParams: s.noParams += 1
            case .noCliData: s.noCli += 1
            }
        }
        return s
    }

    public var totalTools: Int { results.count }

    // MARK: - Parity analysis (param mismatch)

    /// Loads bundled contracts and computes parity for every catalog tool.
    public func runParityAnalysis() {
        isAnalyzing = true
        errorMessage = nil
        guard let contracts = CLIParityEngine.loadContracts() else {
            contractsAvailable = false
            isAnalyzing = false
            hasLoaded = true
            errorMessage = "Bundled CLIContracts.json not found. Regenerate with: swift run cli-parity-gen"
            return
        }
        contractsAvailable = true
        // Preserve ToolCatalogHelpers.allTools() order — the same order the CLI
        // Workshop screen presents tools — so this list aligns for easy reference.
        let computed = CLIParityEngine.compareAll(contracts: contracts)
        results = computed
        service.setResults(computed)
        if selectedToolID == nil { selectedToolID = computed.first?.toolId }
        isAnalyzing = false
        hasLoaded = true
    }

    public func loadIfNeeded() {
        if !hasLoaded { runParityAnalysis() }
    }

    public func selectTool(_ id: String) {
        selectedToolID = id
        service.setSelectedToolID(id)
        outputComparisons = service.getOutputComparisons(for: id)
    }

    // MARK: - Output verification (input/output data)

    /// Returns the bundled golden scenarios available for a tool.
    public func goldenScenarios(for toolID: String) -> [GoldenScenario] {
        CLIParityEngine.loadGoldens().filter { $0.toolId == toolID }
    }

    public func hasOutputScenarios(for toolID: String) -> Bool {
        !goldenScenarios(for: toolID).isEmpty
    }

    /// Runs output verification for the selected tool: drives a CLIWorkshopViewModel
    /// in-process on the bundled fixture and diffs against the golden CLI output.
    public func runOutputVerification(for toolID: String) async {
        isRunningOutput = true
        defer { isRunningOutput = false }

        let scenarios = goldenScenarios(for: toolID)
        guard !scenarios.isEmpty else {
            outputComparisons = []
            service.setOutputComparisons([], for: toolID)
            return
        }

        var comparisons: [OutputComparison] = []
        for scenario in scenarios {
            let comparison = await compareOutput(scenario: scenario)
            comparisons.append(comparison)
        }
        outputComparisons = comparisons
        service.setOutputComparisons(comparisons, for: toolID)
    }

    private func compareOutput(scenario: GoldenScenario) async -> OutputComparison {
        let resolvedArgs = scenario.cliArgs.map { $0 == "FIXTURE" ? scenario.fixtureFile : $0 }
        let inputDesc = ([scenario.toolId] + resolvedArgs).joined(separator: " ")

        // Tools whose output Studio doesn't (yet) produce in-process.
        guard CLIParityEngine.executeSupported.contains(scenario.toolId) else {
            return OutputComparison(
                scenarioId: scenario.scenarioId, toolId: scenario.toolId, label: scenario.label,
                inputDescription: inputDesc, cliOutput: scenario.stdout, studioOutput: "",
                status: .unavailable, diff: [],
                note: "Studio executeCommand() has no case for \(scenario.toolId); output not produced in-process.")
        }
        guard let fixture = CLIParityEngine.fixtureURL(named: scenario.fixtureFile) else {
            return OutputComparison(
                scenarioId: scenario.scenarioId, toolId: scenario.toolId, label: scenario.label,
                inputDescription: inputDesc, cliOutput: scenario.stdout, studioOutput: "",
                status: .error, diff: [],
                note: "Bundled fixture \(scenario.fixtureFile) not found (run: swift run cli-parity-gen).")
        }
        let fixturePath = fixture.path

        // Drive the real Studio code path in-process.
        let workshop = CLIWorkshopViewModel()
        workshop.selectTool(id: scenario.toolId)
        for (pid, raw) in scenario.studioParams {
            let value = raw == "FIXTURE" ? fixturePath : raw
            workshop.updateParameterValue(parameterID: pid, value: value)
        }
        await workshop.executeCommand()
        let studioRaw = workshop.consoleOutput

        let cliLines = CLIParityEngine.normalize(scenario.stdout, fixtureBasename: scenario.fixtureFile)
        let studioLines = CLIParityEngine.normalize(studioRaw, fixtureBasename: scenario.fixtureFile)
        let diff = CLIParityEngine.diff(cli: cliLines, studio: studioLines)
        let isMatch = !diff.contains { $0.kind != .same }

        return OutputComparison(
            scenarioId: scenario.scenarioId, toolId: scenario.toolId, label: scenario.label,
            inputDescription: inputDesc, cliOutput: scenario.stdout, studioOutput: studioRaw,
            status: isMatch ? .match : .differs, diff: diff,
            note: isMatch ? "Studio output matches the CLI golden output (normalized)."
                          : "Differences found between Studio and CLI output (normalized).")
    }
}
