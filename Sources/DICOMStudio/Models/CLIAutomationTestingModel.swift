// CLIAutomationTestingModel.swift
// DICOMStudio
//
// Data models for the CLI Automation Testing screen — a 100% Swift-native,
// in-app parity check between the DICOMKit core CLIs and what the DICOMStudio
// CLI Workshop drives. No Process / no Python at runtime: the CLI side is read
// from bundled generated data (Resources/CLIParity), the Studio side is
// computed in-process via CommandBuilderHelpers / CLIWorkshopViewModel.

import Foundation

// MARK: - Overall per-tool parity status

public enum ParityStatus: String, Sendable, Hashable, CaseIterable {
    case ok            = "OK"
    case drift         = "DRIFT"
    case incomplete    = "INCOMPLETE"
    case noParams      = "NO_PARAMS_DEFINED"
    case noCliData     = "NO_CLI_DATA"

    public var displayName: String {
        switch self {
        case .ok:         return "OK"
        case .drift:      return "Drift"
        case .incomplete: return "Incomplete"
        case .noParams:   return "No Params"
        case .noCliData:  return "No CLI Data"
        }
    }

    /// Explanation shown in the UI.
    public var explanation: String {
        switch self {
        case .ok:         return "Studio flags exactly match the CLI's accepted flags."
        case .drift:      return "Studio emits a flag the CLI rejects — the generated command would fail."
        case .incomplete: return "Studio is missing some flags the CLI accepts."
        case .noParams:   return "Catalog entry exists but no parameters are wired up."
        case .noCliData:  return "No bundled CLI contract for this tool (not built, or dump-help failed)."
        }
    }

    public var sfSymbol: String {
        switch self {
        case .ok:         return "checkmark.seal.fill"
        case .drift:      return "exclamationmark.octagon.fill"
        case .incomplete: return "exclamationmark.triangle.fill"
        case .noParams:   return "questionmark.circle.fill"
        case .noCliData:  return "xmark.circle.fill"
        }
    }
}

// MARK: - Per-flag parity

public enum FlagParityStatus: String, Sendable, Hashable {
    case match           = "MATCH"
    case missingInStudio = "MISSING_IN_STUDIO"   // CLI accepts it; Studio doesn't emit it
    case extraInStudio   = "EXTRA_IN_STUDIO"     // Studio emits it; CLI rejects it (drift)

    public var displayName: String {
        switch self {
        case .match:           return "Match"
        case .missingInStudio: return "Missing in Studio"
        case .extraInStudio:   return "Extra in Studio"
        }
    }
}

public struct ParityFlagRow: Sendable, Identifiable, Hashable {
    public var id: String { flag }
    public let flag: String
    public let kind: String
    public let inCLI: Bool
    public let inStudio: Bool
    public let cliDefault: String
    public let studioDefault: String
    public let cliHelp: String
    public let studioHelp: String
    public let status: FlagParityStatus

    public init(flag: String, kind: String, inCLI: Bool, inStudio: Bool,
                cliDefault: String, studioDefault: String,
                cliHelp: String, studioHelp: String, status: FlagParityStatus) {
        self.flag = flag; self.kind = kind
        self.inCLI = inCLI; self.inStudio = inStudio
        self.cliDefault = cliDefault; self.studioDefault = studioDefault
        self.cliHelp = cliHelp; self.studioHelp = studioHelp
        self.status = status
    }
}

public struct ToolParityResult: Sendable, Identifiable, Hashable {
    public var id: String { toolId }
    public let toolId: String
    public let displayName: String
    public let category: CLIWorkshopTab
    public let binary: String
    public let subcommand: String
    public let matchMode: String
    public let requiresNetwork: Bool
    public let executeSupported: Bool
    public let studioFlagCount: Int
    public let cliFlagCount: Int
    public let matchCount: Int
    public let missingCount: Int
    public let extraCount: Int
    public let parityPercent: Double
    public let status: ParityStatus
    public let rows: [ParityFlagRow]

    public init(toolId: String, displayName: String, category: CLIWorkshopTab,
                binary: String, subcommand: String,
                matchMode: String, requiresNetwork: Bool, executeSupported: Bool,
                studioFlagCount: Int, cliFlagCount: Int, matchCount: Int,
                missingCount: Int, extraCount: Int, parityPercent: Double,
                status: ParityStatus, rows: [ParityFlagRow]) {
        self.toolId = toolId; self.displayName = displayName
        self.category = category
        self.binary = binary; self.subcommand = subcommand
        self.matchMode = matchMode; self.requiresNetwork = requiresNetwork
        self.executeSupported = executeSupported
        self.studioFlagCount = studioFlagCount; self.cliFlagCount = cliFlagCount
        self.matchCount = matchCount; self.missingCount = missingCount
        self.extraCount = extraCount; self.parityPercent = parityPercent
        self.status = status; self.rows = rows
    }
}

// MARK: - Output (input/output data) verification

public enum OutputParityStatus: String, Sendable, Hashable {
    case match       = "MATCH"
    case differs     = "DIFFERS"
    case unavailable = "UNAVAILABLE"
    case error       = "ERROR"

    public var displayName: String {
        switch self {
        case .match:       return "Match"
        case .differs:     return "Differs"
        case .unavailable: return "Unavailable"
        case .error:       return "Error"
        }
    }
}

public enum DiffLineKind: String, Sendable, Hashable {
    case same       // present in both
    case cliOnly    // only in the CLI (golden) output
    case studioOnly // only in the Studio output
}

public struct OutputDiffLine: Sendable, Identifiable, Hashable {
    public let id: Int
    public let kind: DiffLineKind
    public let text: String
    public init(id: Int, kind: DiffLineKind, text: String) {
        self.id = id; self.kind = kind; self.text = text
    }
}

public struct OutputComparison: Sendable, Identifiable, Hashable {
    public var id: String { scenarioId }
    public let scenarioId: String
    public let toolId: String
    public let label: String
    public let inputDescription: String
    public let cliOutput: String
    public let studioOutput: String
    public let status: OutputParityStatus
    public let diff: [OutputDiffLine]
    public let note: String

    public init(scenarioId: String, toolId: String, label: String, inputDescription: String,
                cliOutput: String, studioOutput: String, status: OutputParityStatus,
                diff: [OutputDiffLine], note: String) {
        self.scenarioId = scenarioId; self.toolId = toolId; self.label = label
        self.inputDescription = inputDescription
        self.cliOutput = cliOutput; self.studioOutput = studioOutput
        self.status = status; self.diff = diff; self.note = note
    }
}

// MARK: - Bundled golden scenario (decoded from goldens.json)

public struct GoldenScenario: Sendable, Identifiable, Decodable, Hashable {
    public var id: String { scenarioId }
    public let scenarioId: String
    public let toolId: String
    public let label: String
    public let fixtureFile: String
    public let cliArgs: [String]
    public let studioParams: [String: String]
    public let stdout: String
    public let exitCode: Int
    /// Second input fixture for two-file tools (e.g. dicom-diff). Optional (v3+).
    public let fixtureFile2: String?
    /// True when the golden was produced from a PHI-free synthetic fixture. Optional (v3+).
    public let phiSafe: Bool?
    /// Wave 2: when set, the tool writes this file at the `OUTPUT` placeholder and
    /// the harness compares that file's content (not console output). Optional.
    public let artifactName: String?
    /// "text" (json/xml — compare bytes) or "dicom" (re-dump via dicom-info, mask
    /// volatile tags, diff tags). Optional; defaults to text when absent.
    public let artifactKind: String?

    private enum CodingKeys: String, CodingKey {
        case scenarioId = "id", toolId, label, fixtureFile, cliArgs, studioParams,
             stdout, exitCode, fixtureFile2, phiSafe, artifactName, artifactKind
    }
}
