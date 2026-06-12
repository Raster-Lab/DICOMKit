// CLIParityQueryComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-query` (C-FIND) tool.
//
// dicom-query is READ-ONLY, so it's safe to run against a live PACS. Because the
// reference side and the CLI hit the same server moments apart, the matched
// result set is stable between the two calls — so we compare the ACTUAL matched
// attribute sets (not masked counts). The record is order-independent: each
// result is canonicalised to a sorted "tag=value;…" string and the list of
// results is sorted, so the PACS returning matches in a different order between
// the two calls is not a false drift.

import Foundation

/// A timing/ordering-independent semantic summary of a C-FIND query.
public struct QuerySemantics: Equatable, Sendable {
    public var level: String          // "study" | "series" | "patient" | "instance"
    public var success: Bool          // query completed (no connection/protocol error)
    public var count: Int             // number of matched results
    public var results: [String]      // sorted canonical "tag=value;…" per result

    public var overallOK: Bool { success }
}

public enum CLIParityQueryComparator {

    /// Builds the record from per-result attribute objects ([tag.description: value]),
    /// canonicalising each result to a sorted "key=value;…" string and sorting the list.
    public static func semantics(level: String, success: Bool, objects: [[String: String]]) -> QuerySemantics {
        let canon = objects.map { obj in
            obj.keys.sorted().map { "\($0)=\(obj[$0] ?? "")" }.joined(separator: ";")
        }.sorted()
        return QuerySemantics(level: level, success: success, count: objects.count, results: canon)
    }

    /// Parses the dicom-query CLI's `--format json` stdout (a JSON array of
    /// {tag.description: value} objects) into the record.
    public static func parse(_ jsonStdout: String, level: String, success: Bool) -> QuerySemantics {
        semantics(level: level, success: success, objects: parseObjects(jsonStdout))
    }

    static func parseObjects(_ jsonStdout: String) -> [[String: String]] {
        // The JSON array may be preceded by a "── stderr ──" marker or verbose
        // lines — slice from the first '[' to the matching end so JSONSerialization
        // sees only the array.
        guard let start = jsonStdout.firstIndex(of: "["),
              let end = jsonStdout.lastIndex(of: "]") , start <= end else { return [] }
        let slice = String(jsonStdout[start...end])
        guard let data = slice.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { dict in
            var out: [String: String] = [:]
            for (k, v) in dict { out[k] = "\(v)" }
            return out
        }
    }

    /// A stable, human-readable rendering of the record — diffed for the row's
    /// per-result comparison. Per-result lines are capped so a large divergence
    /// (e.g. a missing filter returning thousands of studies) doesn't render an
    /// enormous diff — the `count:` line already flags a size mismatch outright.
    static let resultDisplayCap = 150
    public static func canonical(_ s: QuerySemantics) -> [String] {
        var out = ["level: \(s.level)", "success: \(s.success)", "count: \(s.count)"]
        for (i, r) in s.results.prefix(resultDisplayCap).enumerated() { out.append("[\(i)] \(r)") }
        if s.results.count > resultDisplayCap {
            out.append("… (\(s.results.count - resultDisplayCap) more results not shown)")
        }
        return out
    }

    /// Compares the structured reference record against the CLI's parsed record.
    public static func compare(reference: QuerySemantics, cli: QuerySemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }

    // MARK: Non-JSON format validation (result-count parity)

    /// The JSON format carries full attributes, so it gets full result-set parity.
    /// The table/csv/compact formats drop or truncate fields (e.g. the study table
    /// omits Study Instance UID), so they're validated by **result count** — i.e.
    /// each format renders the same number of matches as the package-API reference.
    public static func count(in stdout: String, format: String) -> Int {
        switch format {
        case "json":
            return parseObjects(stdout).count
        case "csv":
            // header row + one row per result; empty output → 0.
            let lines = stdout.split(separator: "\n", omittingEmptySubsequences: true)
            return lines.isEmpty ? 0 : max(0, lines.count - 1)
        case "compact":
            // one line per result.
            return stdout.split(separator: "\n", omittingEmptySubsequences: true)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        default: // table
            for line in stdout.split(separator: "\n") where line.contains("Total:") {
                return Int(line.filter { $0.isNumber }) ?? 0
            }
            return 0   // "No results found."
        }
    }

    /// Compares only the result COUNT (for table/csv/compact, which don't carry the
    /// full attribute set) against the reference.
    public static func compareCount(reference: QuerySemantics, cliCount: Int, format: String)
        -> (diff: [OutputDiffLine], match: Bool) {
        let ref = ["level: \(reference.level)", "format: \(format)", "count: \(reference.count)"]
        let cli = ["level: \(reference.level)", "format: \(format)", "count: \(cliCount)"]
        let diff = CLIParityEngine.diff(cli: cli, studio: ref)
        return (diff, !diff.contains { $0.kind != .same })
    }
}
