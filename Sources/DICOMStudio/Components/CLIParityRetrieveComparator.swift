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
// and overall success. C-MOVE additionally compares the completed / failed / warning
// sub-operation counts (its result block prints them); C-GET compares the
// received-file count instead — its shared summary prints ONLY that, not the
// per-sub-operation counts. Round-trip time and throughput are never compared.
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
    /// so the combined stdout+stderr text is passed in). `success` comes from the
    /// CLI's exit code (the records must agree on it — see runNetworkScenario).
    ///
    /// C-MOVE prints a structured `C-MOVE Result:` block carrying `Completed:` /
    /// `Failed:` / `Warnings:`. Those are matched by line PREFIX (after trimming the
    /// two-space indent), NOT by substring-contains. This is essential because:
    ///   • the verbose per-sub-operation "Progress:" lines use lower-case
    ///     "completed"/"failed" (no colon) — excluded by the capitalised label; and
    ///   • the `Status:` line embeds the DIMSEStatus description, which for a FAILURE
    ///     status begins with the literal "Failed:" (e.g. "Status: Failed: Unable to
    ///     process (0x0110)"). A contains-search would match that line first and read
    ///     the status hex (→ 0) instead of the real failed-sub-operation count. The
    ///     `Status:` prefix means `hasPrefix("Failed:")` correctly skips it.
    ///
    /// C-GET no longer prints a structured count block: its shared
    /// NetworkConsole.cGetSummary emits EXACTLY one terse line —
    /// "✅ C-GET completed — N file(s) received" on success, or
    /// "⚠️ C-GET completed but received 0 instances. …" when nothing arrived. The
    /// received-file count is therefore the only comparable C-GET signal; it is read
    /// from that line (the 0-instances warning ⇒ 0). The per-sub-operation
    /// completed/failed counts from the final C-GET-RSP are unobservable in the CLI
    /// text, so they are not parsed (and not compared — see `canonical`).
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
            // Read N from "… — N file(s) received"; the 0-instances warning line
            // ("received 0 instances") carries no received count and means 0.
            func cGetFilesReceived() -> Int {
                for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
                    let line = raw.trimmingCharacters(in: .whitespaces)
                    if line.contains("received 0 instances") { return 0 }
                    if line.contains("file(s) received"),
                       let r = line.range(of: "[0-9]+", options: .regularExpression) {
                        return Int(line[r]) ?? 0
                    }
                }
                return 0
            }
            return RetrieveSemantics(
                method: "c-get", level: level, success: success,
                completed: 0, failed: 0, warning: 0,
                filesReceived: cGetFilesReceived())
        }
        return RetrieveSemantics(
            method: "c-move", level: level, success: success,
            completed: intAfter("Completed:") ?? 0,
            failed: intAfter("Failed:") ?? 0,
            warning: intAfter("Warnings:") ?? 0,
            filesReceived: 0)
    }

    /// A stable, human-readable rendering of the record. C-MOVE compares the
    /// completed / failed / warning sub-operation counts (its result block prints
    /// them); C-GET compares ONLY the received-file count — its shared summary emits
    /// nothing else, so including completed/failed would diff forever against the
    /// reference's (unprintable) C-GET-RSP counts. `success` participates for both.
    public static func canonical(_ s: RetrieveSemantics) -> [String] {
        var out = ["method: \(s.method)", "level: \(s.level)", "success: \(s.success)"]
        if s.method == "c-get" {
            out.append("files: \(s.filesReceived)")
        } else {
            out += ["completed: \(s.completed)", "failed: \(s.failed)", "warning: \(s.warning)"]
        }
        return out
    }

    /// Compares the structured reference record against the CLI's parsed record.
    public static func compare(reference: RetrieveSemantics, cli: RetrieveSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
