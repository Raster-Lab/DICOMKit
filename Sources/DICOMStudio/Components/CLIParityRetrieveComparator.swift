// CLIParityRetrieveComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-retrieve` (C-MOVE / C-GET)
// tool.
//
// dicom-retrieve PULLS instances from the PACS: C-GET streams them back on the
// association (the CLI writes them to disk; the reference counts them in memory),
// while C-MOVE asks the PACS to forward them to a destination AE. Both the package
// API reference and the CLI drive the SAME DICOMRetrieveService.move*/get* calls, so
// their sub-operation counts line up. Comparison is on the OUTCOME — method, level,
// overall success, and the completed / failed sub-operation counts (plus the
// retrieved-file count for C-GET and the warning count for C-MOVE). Round-trip time
// and throughput are never compared.
//
// NOTE: every retrieve scenario runs with `--verbose`, because dicom-retrieve only
// prints its result block when `--verbose` is set (or the op failed) — without it a
// successful retrieve emits nothing to parse.

import Foundation

/// A timing-independent semantic summary of a C-MOVE / C-GET retrieve.
public struct RetrieveSemantics: Equatable, Sendable {
    public var method: String         // "c-move" | "c-get"
    public var level: String          // "study" | "series" | "instance"
    public var success: Bool          // overall op succeeded (no failure/error)
    public var completed: Int         // sub-operations completed
    public var failed: Int            // sub-operations failed
    public var warning: Int           // sub-operations with warnings (C-MOVE only)
    public var filesReceived: Int     // instances received on the association (C-GET only)

    public var overallOK: Bool { success }

    public init(method: String, level: String, success: Bool,
                completed: Int, failed: Int, warning: Int, filesReceived: Int) {
        self.method = method; self.level = level; self.success = success
        self.completed = completed; self.failed = failed
        self.warning = warning; self.filesReceived = filesReceived
    }
}

public enum CLIParityRetrieveComparator {

    /// Parses the dicom-retrieve CLI output (it prints its result block to stderr,
    /// so the combined stdout+stderr text is passed in). The C-MOVE block carries
    /// `Completed:` / `Failed:` / `Warnings:`; the C-GET block carries
    /// `Files received:` / `Completed:` / `Failed:`. `success` comes from the CLI's
    /// exit code (the records must agree on it — see runNetworkScenario).
    ///
    /// The count lines are matched by line PREFIX (after trimming the two-space
    /// indent), NOT by substring-contains. This is essential because:
    ///   • the verbose per-sub-operation "Progress:" lines use lower-case
    ///     "completed"/"failed" (no colon) — excluded by the capitalised label; and
    ///   • the `Status:` line embeds the DIMSEStatus description, which for a FAILURE
    ///     status begins with the literal "Failed:" (e.g. "Status: Failed: Unable to
    ///     process (0x0110)"). A contains-search would match that line first and read
    ///     the status hex (→ 0) instead of the real failed-sub-operation count. The
    ///     `Status:` prefix means `hasPrefix("Failed:")` correctly skips it.
    /// (The "C-GET Completed:" header is likewise skipped — its prefix is "C-GET".)
    public static func parse(_ text: String, method: String, level: String, success: Bool) -> RetrieveSemantics {
        func intAfter(_ label: String) -> Int? {
            for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix(label) else { continue }
                if let r = line.range(of: "[0-9]+", options: .regularExpression) { return Int(line[r]) }
            }
            return nil
        }
        if method == "c-get" {
            return RetrieveSemantics(
                method: "c-get", level: level, success: success,
                completed: intAfter("Completed:") ?? 0,
                failed: intAfter("Failed:") ?? 0,
                warning: 0,
                filesReceived: intAfter("Files received:") ?? 0)
        }
        return RetrieveSemantics(
            method: "c-move", level: level, success: success,
            completed: intAfter("Completed:") ?? 0,
            failed: intAfter("Failed:") ?? 0,
            warning: intAfter("Warnings:") ?? 0,
            filesReceived: 0)
    }

    /// A stable, human-readable rendering of the record. The trailing line is
    /// method-specific: C-GET reports the received-file count, C-MOVE the warning
    /// count (dicom-retrieve doesn't print warnings for C-GET).
    public static func canonical(_ s: RetrieveSemantics) -> [String] {
        var out = ["method: \(s.method)", "level: \(s.level)", "success: \(s.success)",
                   "completed: \(s.completed)", "failed: \(s.failed)"]
        if s.method == "c-get" { out.append("files: \(s.filesReceived)") }
        else { out.append("warning: \(s.warning)") }
        return out
    }

    /// Compares the structured reference record against the CLI's parsed record.
    public static func compare(reference: RetrieveSemantics, cli: RetrieveSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
