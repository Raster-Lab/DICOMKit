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
        let isDicomTree = scenario.artifactKind == "dicom-tree"
        let isImageRasterMulti = scenario.artifactKind == "image-raster-multi"
        var artifactURL: URL? = nil
        var scratchDir: URL? = nil
        // A scratch dir is needed for the compared artifact AND/OR an OUTPUT2 secondary output.
        if (scenario.artifactName?.isEmpty == false) || scenario.studioParams.values.contains("OUTPUT2") {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("studio-parity-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            scratchDir = dir
            if let art = scenario.artifactName, !art.isEmpty {
                artifactURL = dir.appendingPathComponent(art)
                if (isDicomMulti || isDicomTree || isImageRasterMulti), let u = artifactURL {   // OUTPUT is a directory the producer fills
                    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
                }
            }
        }
        let output2URL = scratchDir?.appendingPathComponent("output2.dat")
        defer { if let d = scratchDir { try? FileManager.default.removeItem(at: d) } }

        // Clear EVERY param the scenario didn't set: the catalog default-fills some
        // (e.g. ~/Desktop/DICOM_Output, or a default --file/--path), but the CLI golden
        // ran with ONLY the scenario's flags, so the Studio side must match exactly —
        // a form default must never leak into a parity run (e.g. a default --file would
        // make uid-validate validate that file while the CLI validated nothing).
        for def in ToolCatalogHelpers.parameterDefinitions(for: scenario.toolId)
            where !def.isInternal && scenario.studioParams[def.id] == nil {
            workshop.updateParameterValue(parameterID: def.id, value: "")
        }
        for (pid, raw) in scenario.studioParams {
            let value: String
            if raw == "FIXTURE"       { value = fixturePath }
            else if raw == "FIXTURE2" { value = fixturePath2 ?? raw }
            else if raw == "OUTPUT"   { value = artifactURL?.path ?? raw }
            else if raw == "OUTPUT2"  { value = output2URL?.path ?? raw }  // secondary output
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
        let isPixelHash = scenario.artifactKind == "decoded-pixel-hash"
        let isImageRasterHash = scenario.artifactKind == "image-raster-hash"
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
        } else if let u = artifactURL, isDicomTree {
            // Nested tree (e.g. study organize): recursively dump each .dcm keyed by its
            // RELATIVE PATH, so folder naming/structure is compared alongside content.
            var rels: [String] = []
            if let en = FileManager.default.enumerator(atPath: u.path) {
                while let p = en.nextObject() as? String { if p.hasSuffix(".dcm") { rels.append(p) } }
            }
            rels.sort()
            var combined = "Files: \(rels.count)\n"
            for rel in rels {
                let frame = CLIParityEngine.normalize(await dump(u.appendingPathComponent(rel)), fixtureBasenames: [])
                combined += "=== \(rel) ===\n" + frame.joined(separator: "\n") + "\n"
            }
            studioRaw = combined
        } else if let u = artifactURL, isPixelHash {
            // compress/decompress: compare decoded PixelData (sha256), not bytes, so
            // encapsulation / transfer-syntax differences don't matter (plan §4b).
            studioRaw = CLIParityEngine.decodedPixelHash(fileURL: u) ?? "<pixel-decode-failed>"
        } else if let u = artifactURL, isImageRasterHash {
            // image producers (dicom-export): compare the decoded raster (sha256),
            // which strips non-deterministic encoder metadata (EXIF/ICC) (plan §4b).
            studioRaw = CLIParityEngine.imageRasterHash(fileURL: u) ?? "<image-decode-failed>"
        } else if let u = artifactURL, isImageRasterMulti {
            // OUTPUT is a directory of images (e.g. dicom-convert --format png --recursive).
            // Hash each produced file's decoded raster, sorted by relative path for stable
            // pairing, with index headers — must match cli-parity-gen's image-raster-multi.
            var rels: [String] = []
            if let en = FileManager.default.enumerator(atPath: u.path) {
                while let p = en.nextObject() as? String {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: u.appendingPathComponent(p).path, isDirectory: &isDir),
                       !isDir.boolValue {
                        rels.append(p)
                    }
                }
            }
            rels.sort()
            var combined = "Images: \(rels.count)\n"
            for (i, rel) in rels.enumerated() {
                let h = CLIParityEngine.imageRasterHash(fileURL: u.appendingPathComponent(rel)) ?? "<image-decode-failed>"
                combined += "=== image \(i) ===\n" + h + "\n"
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
        if isDicomArtifact || isDicomMulti || isDicomTree {
            cliLines = CLIParityEngine.maskVolatileDumpTags(cliLines)
            studioLines = CLIParityEngine.maskVolatileDumpTags(studioLines)
        }
        if scenario.artifactKind == "uid-list" {   // dicom-uid generate: mask the random UID values
            cliLines = CLIParityEngine.maskUIDs(cliLines)
            studioLines = CLIParityEngine.maskUIDs(studioLines)
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
