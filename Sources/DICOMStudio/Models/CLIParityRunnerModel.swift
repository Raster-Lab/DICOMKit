// CLIParityRunnerModel.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Data models for the "CLI Parity" screen — a USER-DRIVEN batch parity runner.
// The user picks tool(s) + one input file; the runner auto-sweeps each tool's
// subcommand/flag combinations and, for every scenario, executes BOTH the app
// (in-process, via CLIWorkshopViewModel) AND the real `dicom-*` CLI binary (a
// subprocess, via CLIToolTerminalCompare), then tabulates three signals:
//   • INPUT   — does the app emit a flag the CLI rejects? (argv/contract parity)
//   • PROCESS — did both sides run as expected? (exit codes)
//   • OUTPUT  — is the normalized output identical?
//
// Because it forks the live binary, this screen inherits the same constraint as
// CLIToolTerminalCompare: it only works with the App Sandbox DISABLED and must
// be removed before production (see CLIToolTerminalCompare.swift and project
// memory `dicom-info-terminal-compare-testonly`).

import Foundation

// MARK: - Row status taxonomy

/// The verdict for a single batch-parity scenario row.
///
/// Only `pass`/`outputDrift`/`inputDrift`/`appError`/`cliError` count toward the
/// success-rate denominator. `skipped` (structural, e.g. wrong fixture / missing
/// file / network tool) and `nonDeterministic` (output not byte-stable even after
/// masking) are EXCLUDED so they neither inflate nor deflate the rate.
public enum BatchRowStatus: String, Sendable, Hashable {
    case pass             = "PASS"
    case outputDrift      = "OUTPUT_DRIFT"
    case inputDrift       = "INPUT_DRIFT"
    case appError         = "APP_ERROR"
    case cliError         = "CLI_ERROR"
    case skipped          = "SKIPPED"
    case nonDeterministic = "NON_DETERMINISTIC"

    public var displayName: String {
        switch self {
        case .pass:             return "Pass"
        case .outputDrift:      return "Output Drift"
        case .inputDrift:       return "Input Drift"
        case .appError:         return "App Error"
        case .cliError:         return "CLI Error"
        case .skipped:          return "Skipped"
        case .nonDeterministic: return "Non-deterministic"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .pass:             return "checkmark.seal.fill"
        case .outputDrift:      return "exclamationmark.triangle.fill"
        case .inputDrift:       return "exclamationmark.octagon.fill"
        case .appError:         return "xmark.octagon.fill"
        case .cliError:         return "xmark.circle.fill"
        case .skipped:          return "minus.circle"
        case .nonDeterministic: return "dice"
        }
    }

    /// Whether this row participates in the success-rate denominator.
    public var countsInDenominator: Bool {
        switch self {
        case .skipped, .nonDeterministic: return false
        default:                          return true
        }
    }

    /// Whether this row is a success (only a clean PASS).
    public var isSuccess: Bool { self == .pass }

    public var explanation: String {
        switch self {
        case .pass:             return "Input matched, both processes succeeded, and normalized output matched."
        case .outputDrift:      return "Input matched and both sides ran, but the normalized outputs differ — the app diverged from the CLI."
        case .inputDrift:       return "The app emitted a flag the CLI does not accept; the generated command would fail."
        case .appError:         return "The app exited with an error when success was expected; output is incomparable."
        case .cliError:         return "The CLI binary exited with an error (or could not launch) when success was expected."
        case .skipped:          return "Not run for a structural reason (wrong/absent input fixture, or a flag combo the CLI rejects) — not a parity defect."
        case .nonDeterministic: return "The CLI's own output is not byte-stable across runs even after masking — cannot be fairly scored."
        }
    }
}

// MARK: - Per-column signal

/// Tri-state signal used for the INPUT and OUTPUT table columns.
public enum BatchSignal: String, Sendable, Hashable {
    case match         = "MATCH"
    case differ        = "DIFFER"
    case notApplicable = "—"

    public var displayName: String {
        switch self {
        case .match:         return "Match"
        case .differ:        return "Differ"
        case .notApplicable: return "—"
        }
    }
}

// MARK: - Generated scenario (one subcommand/flag combo)

/// A single generated test scenario for one tool. Placeholders `FIXTURE`,
/// `FIXTURE2`, `OUTPUT` and `OUTPUT2` are resolved at run time to the user's
/// input file(s) and per-side scratch paths.
public struct BatchScenario: Sendable, Identifiable, Hashable {
    public var id: String { scenarioId }
    public let scenarioId: String
    public let toolId: String
    public let label: String
    /// argv WITHOUT the leading tool name, with placeholders unresolved.
    public let cliArgs: [String]
    /// Studio parameter map (parameterID → value), placeholders unresolved.
    public let studioParams: [String: String]
    /// True when the scenario references a primary input file (`FIXTURE`).
    public let needsInputFile: Bool
    /// True when the scenario references a second input file (`FIXTURE2`).
    public let needsSecondFile: Bool
    /// Name of the artifact the tool writes at `OUTPUT` (e.g. "out.dcm"); nil for
    /// pure stdout tools.
    public let artifactName: String?
    /// How the produced output is reduced before comparison: "stdout", "text",
    /// "dicom", "dicom-multi", "dicom-tree", "decoded-pixel-hash",
    /// "image-raster-hash", "uid-list".
    public let artifactKind: String
    /// True when the tool needs a DIRECTORY of DICOM files as its input (e.g.
    /// dicom-study organize, dicom-archive) — used to skip with a clear note when
    /// the user supplied a single file instead.
    public let needsDirectory: Bool
    /// Human hint about the expected input shape (e.g. "multiframe", "directory").
    public let inputHint: String

    public init(scenarioId: String, toolId: String, label: String, cliArgs: [String],
                studioParams: [String: String], needsInputFile: Bool, needsSecondFile: Bool,
                artifactName: String?, artifactKind: String, needsDirectory: Bool, inputHint: String) {
        self.scenarioId = scenarioId; self.toolId = toolId; self.label = label
        self.cliArgs = cliArgs; self.studioParams = studioParams
        self.needsInputFile = needsInputFile; self.needsSecondFile = needsSecondFile
        self.artifactName = artifactName; self.artifactKind = artifactKind
        self.needsDirectory = needsDirectory
        self.inputHint = inputHint
    }
}

// MARK: - One results-table row

public struct BatchScenarioResult: Sendable, Identifiable, Hashable {
    public var id: String { scenarioId }
    public let scenarioId: String
    public let toolId: String
    public let label: String
    /// The resolved command line the CLI ran (for display).
    public let commandLine: String
    public let inputSignal: BatchSignal
    /// nil when the app side was not run (e.g. skipped before execution).
    public let appSucceeded: Bool?
    /// nil when the CLI side was not run.
    public let cliExitCode: Int32?
    public let outputSignal: BatchSignal
    public let status: BatchRowStatus
    public let appOutput: String
    public let cliOutput: String
    public let diff: [OutputDiffLine]
    public let note: String

    public init(scenarioId: String, toolId: String, label: String, commandLine: String,
                inputSignal: BatchSignal, appSucceeded: Bool?, cliExitCode: Int32?,
                outputSignal: BatchSignal, status: BatchRowStatus,
                appOutput: String, cliOutput: String, diff: [OutputDiffLine], note: String) {
        self.scenarioId = scenarioId; self.toolId = toolId; self.label = label
        self.commandLine = commandLine
        self.inputSignal = inputSignal; self.appSucceeded = appSucceeded
        self.cliExitCode = cliExitCode; self.outputSignal = outputSignal
        self.status = status
        self.appOutput = appOutput; self.cliOutput = cliOutput
        self.diff = diff; self.note = note
    }
}

// MARK: - Aggregate metrics

/// The success-rate roll-up. Per the design, four numbers are reported:
/// the headline OVERALL row-pass rate plus the three independent per-dimension
/// rates, so a regression's nature (input vs process vs output) is visible.
public struct BatchParitySummary: Sendable, Hashable {
    public var total: Int = 0
    public var denominator: Int = 0       // total − skipped − nonDeterministic
    public var passed: Int = 0
    public var inputMatched: Int = 0      // denominator rows with no input drift
    public var processMatched: Int = 0    // denominator rows where both sides ran as expected
    public var outputComparable: Int = 0  // rows where output was actually compared
    public var outputMatched: Int = 0
    public var skipped: Int = 0
    public var nonDeterministic: Int = 0

    public init() {}

    /// Headline: rows that PASS all three dimensions ÷ scored rows.
    public var overallPercent: Double {
        denominator == 0 ? 0 : (1000.0 * Double(passed) / Double(denominator)).rounded() / 10
    }
    public var inputPercent: Double {
        denominator == 0 ? 0 : (1000.0 * Double(inputMatched) / Double(denominator)).rounded() / 10
    }
    public var processPercent: Double {
        denominator == 0 ? 0 : (1000.0 * Double(processMatched) / Double(denominator)).rounded() / 10
    }
    /// Output rate is taken over COMPARABLE rows only (excludes input-drift /
    /// process-failed rows) so a process failure isn't double-charged as an
    /// output failure.
    public var outputPercent: Double {
        outputComparable == 0 ? 0 : (1000.0 * Double(outputMatched) / Double(outputComparable)).rounded() / 10
    }

    public mutating func tally(_ r: BatchScenarioResult) {
        total += 1
        switch r.status {
        case .skipped:          skipped += 1; return
        case .nonDeterministic: nonDeterministic += 1; return
        default: break
        }
        denominator += 1
        if r.status == .pass { passed += 1 }
        // Derive the per-dimension tallies from the row STATUS so they stay
        // consistent with the verdict (e.g. a diff-style PASS exits nonzero on both
        // sides yet still counts as process-matched and output-matched).
        if r.status != .inputDrift { inputMatched += 1 }
        // PROCESS matched = both sides ran to a comparable result (both succeeded, or
        // a diff-style tool where both agreed on a nonzero result).
        if r.status == .pass || r.status == .outputDrift { processMatched += 1 }
        // OUTPUT was actually compared only for the rows that reached the diff.
        if r.status == .pass || r.status == .outputDrift {
            outputComparable += 1
            if r.status == .pass { outputMatched += 1 }
        }
    }
}
