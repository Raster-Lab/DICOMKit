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
        let resolvedArgs = scenario.cliArgs.map { tok -> String in
            if tok == "FIXTURE"  { return scenario.fixtureFile }
            if tok == "FIXTURE2" { return scenario.fixtureFile2 ?? tok }
            return tok
        }
        let inputDesc = ([scenario.toolId] + resolvedArgs).joined(separator: " ")

        func err(_ note: String) -> OutputComparison {
            OutputComparison(scenarioId: scenario.scenarioId, toolId: scenario.toolId, label: scenario.label,
                inputDescription: inputDesc, cliOutput: scenario.stdout, studioOutput: "",
                status: .error, diff: [], note: note)
        }

        // Tools whose output Studio doesn't (yet) produce in-process.
        guard CLIParityEngine.executeSupported.contains(scenario.toolId) else {
            return OutputComparison(
                scenarioId: scenario.scenarioId, toolId: scenario.toolId, label: scenario.label,
                inputDescription: inputDesc, cliOutput: scenario.stdout, studioOutput: "",
                status: .unavailable, diff: [],
                note: "Studio executeCommand() has no case for \(scenario.toolId); output not produced in-process.")
        }

        // Resolve fixtures to bundled paths (primary may be absent for no-file tools).
        var fixturePath = ""
        if !scenario.fixtureFile.isEmpty {
            guard let f = CLIParityEngine.fixtureURL(named: scenario.fixtureFile) else {
                return err("Bundled fixture \(scenario.fixtureFile) not found (run: swift run cli-parity-gen).")
            }
            fixturePath = f.path
        }
        var fixturePath2: String? = nil
        if let name2 = scenario.fixtureFile2, !name2.isEmpty {
            guard let f2 = CLIParityEngine.fixtureURL(named: name2) else {
                return err("Bundled fixture \(name2) not found (run: swift run cli-parity-gen).")
            }
            fixturePath2 = f2.path
        }

        // Drive the real Studio code path in-process.
        let workshop = CLIWorkshopViewModel()
        workshop.selectTool(id: scenario.toolId)

        // Artifact (file-producer) scenarios: the tool writes a file (or a directory
        // of files) at the OUTPUT placeholder; we compare the produced file(s).
        let isDicomMulti = scenario.artifactKind == "dicom-multi"
        var artifactURL: URL? = nil
        if let art = scenario.artifactName, !art.isEmpty {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("studio-parity-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            artifactURL = dir.appendingPathComponent(art)
            if isDicomMulti, let u = artifactURL {   // OUTPUT is a directory the producer fills
                try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
            }
        }
        defer { if let u = artifactURL { try? FileManager.default.removeItem(at: u.deletingLastPathComponent()) } }

        // Clear optional output-path params the scenario didn't set: the catalog
        // default-fills them (e.g. ~/Desktop/DICOM_Output), but the CLI golden ran
        // without those flags, so the Studio side must not write spurious files.
        for def in ToolCatalogHelpers.parameterDefinitions(for: scenario.toolId)
            where def.parameterType == .outputPath && scenario.studioParams[def.id] == nil {
            workshop.updateParameterValue(parameterID: def.id, value: "")
        }
        for (pid, raw) in scenario.studioParams {
            let value: String
            if raw == "FIXTURE"       { value = fixturePath }
            else if raw == "FIXTURE2" { value = fixturePath2 ?? raw }
            else if raw == "OUTPUT"   { value = artifactURL?.path ?? raw }
            else                      { value = raw }
            workshop.updateParameterValue(parameterID: pid, value: value)
        }
        await workshop.executeCommand()

        // Re-dump a produced .dcm via dicom-info (shared MetadataPresenter) — the
        // same way the golden was captured.
        func dump(_ url: URL) async -> String {
            let info = CLIWorkshopViewModel()
            info.selectTool(id: "dicom-info")
            info.updateParameterValue(parameterID: "inputPath", value: url.path)
            await info.executeCommand()
            return info.consoleOutput
        }

        let isDicomArtifact = scenario.artifactKind == "dicom"
        let studioRaw: String
        if let u = artifactURL, isDicomMulti {
            let files = ((try? FileManager.default.contentsOfDirectory(atPath: u.path)) ?? [])
                .filter { $0.hasSuffix(".dcm") }.sorted()
            var combined = "Frames: \(files.count)\n"
            for (i, f) in files.enumerated() {
                // Normalize each frame to clean tag lines (strips the $ echo / Exit-code
                // trailer / edge blanks) so per-frame blocks match the generator's trim.
                let frame = CLIParityEngine.normalize(await dump(u.appendingPathComponent(f)), fixtureBasenames: [])
                combined += "=== frame \(i) ===\n" + frame.joined(separator: "\n") + "\n"
            }
            studioRaw = combined
        } else if let u = artifactURL, isDicomArtifact {
            studioRaw = await dump(u)
        } else if let u = artifactURL {
            studioRaw = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
        } else {
            studioRaw = workshop.consoleOutput
        }

        var basenames: [String] = []
        if !scenario.fixtureFile.isEmpty { basenames.append(scenario.fixtureFile) }
        if let f2 = scenario.fixtureFile2, !f2.isEmpty { basenames.append(f2) }
        var cliLines = CLIParityEngine.normalize(scenario.stdout, fixtureBasenames: basenames)
        var studioLines = CLIParityEngine.normalize(studioRaw, fixtureBasenames: basenames)
        if isDicomArtifact || isDicomMulti {
            cliLines = CLIParityEngine.maskVolatileDumpTags(cliLines)
            studioLines = CLIParityEngine.maskVolatileDumpTags(studioLines)
        }
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
