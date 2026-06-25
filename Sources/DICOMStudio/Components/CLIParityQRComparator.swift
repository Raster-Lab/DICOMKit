// CLIParityQRComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-qr` (integrated
// query-retrieve) tool.
//
// dicom-qr's retrieval half is already covered by dicom-retrieve (same
// DICOMRetrieveService calls), so the parity here targets its query half via the
// READ-ONLY `--review` mode: it runs the integrated tool's C-FIND and verifies the
// matched study set equals the package-API reference. Because dicom-qr builds its
// OWN study-level QueryKeys (uppercasing the patient name) rather than going through
// DICOMQueryService.buildQueryKeys, the reference replicates that key-building
// exactly (see CLIParityNetworkReference.qrReview) so the matched set lines up.
//
// The record is order-independent: each match is reduced to its Study Instance UID
// (the stable identifier across the reference's and the CLI's near-simultaneous
// calls) and the list is sorted, so the PACS returning matches in a different order
// between the two calls is not a false drift.

import Foundation

/// The retrieval outcome of a dicom-qr INTERACTIVE run (nil for read-only `--review`).
/// dicom-qr's interactive mode queries, then — once the study selection is entered
/// ("all" here) — retrieves each selected study and prints a "Retrieval Summary"
/// (Total / Success / Failed). Mirrors that summary so the SDK reference and the CLI
/// can be compared on the retrieve outcome, not just the matched set.
public struct QRRetrieval: Equatable, Sendable {
    public var total: Int      // studies selected for retrieval (dicom-qr "Total")
    public var success: Int    // studies retrieved without a thrown error ("Success")
    public var failed: Int     // studies that threw / lacked a Study UID ("Failed")

    public init(total: Int, success: Int, failed: Int) {
        self.total = total; self.success = success; self.failed = failed
    }
}

/// A timing/ordering-independent semantic summary of a dicom-qr query — its `--review`
/// C-FIND, plus (for `--interactive`) the retrieval outcome of selecting "all".
public struct QRSemantics: Equatable, Sendable {
    public var success: Bool          // query completed (no connection/protocol error)
    public var count: Int             // number of matched studies ("Found N studies")
    public var studyUIDs: [String]    // sorted Study Instance UIDs of the matches
    public var retrieval: QRRetrieval? // interactive retrieve outcome (nil for review)

    public var overallOK: Bool { success }

    public init(success: Bool, count: Int, studyUIDs: [String], retrieval: QRRetrieval? = nil) {
        self.success = success; self.count = count; self.studyUIDs = studyUIDs
        self.retrieval = retrieval
    }
}

public enum CLIParityQRComparator {

    /// Builds the record from a match count and the per-match Study UIDs (sorted).
    /// `count` is kept distinct from `studyUIDs.count` because a matched study that
    /// lacks a Study Instance UID is still counted by dicom-qr's "Found N studies"
    /// but contributes no UID line — the reference mirrors that. `retrieval` is the
    /// interactive-mode retrieve summary (nil for read-only review).
    public static func record(success: Bool, count: Int, uids: [String],
                              retrieval: QRRetrieval? = nil) -> QRSemantics {
        QRSemantics(success: success, count: count, studyUIDs: uids.sorted(), retrieval: retrieval)
    }

    /// Parses dicom-qr stdout for both modes:
    ///   • "Found N studies" (or "No studies found …" → 0) gives the count;
    ///   • each "    UID: <studyUID>" results line gives a Study UID;
    ///   • the interactive "Retrieval Summary" block's Total / Success / Failed lines
    ///     give the retrieve outcome (absent in `--review`, so `retrieval` stays nil).
    /// Run without `--verbose` so the only "UID:" lines are the per-study ones.
    public static func parse(_ stdout: String, success: Bool) -> QRSemantics {
        var count = 0
        var uids: [String] = []
        var total: Int? = nil, succeeded: Int? = nil, failed: Int? = nil
        var inSummary = false
        func number(_ t: String, after prefix: String) -> Int {
            let tail = t.dropFirst(prefix.count)
            if let r = tail.range(of: "[0-9]+", options: .regularExpression) { return Int(tail[r]) ?? 0 }
            return 0
        }
        for raw in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.lowercased().hasPrefix("no studies found") {
                count = 0
            } else if t.hasPrefix("Found "), t.contains("studies") {
                if let r = t.range(of: "[0-9]+", options: .regularExpression) { count = Int(t[r]) ?? 0 }
            } else if t.hasPrefix("UID:") {
                let uid = t.dropFirst("UID:".count).trimmingCharacters(in: .whitespaces)
                if !uid.isEmpty { uids.append(uid) }
            } else if t.hasPrefix("Retrieval Summary") {
                inSummary = true
            } else if inSummary && t.hasPrefix("Total:") {
                total = number(t, after: "Total:")
            } else if inSummary && t.hasPrefix("Success:") {
                succeeded = number(t, after: "Success:")
            } else if inSummary && t.hasPrefix("Failed:") {
                failed = number(t, after: "Failed:")
            }
        }
        // A "Retrieval Summary" block (an interactive run) is signalled by its Total line.
        let retrieval = total.map { QRRetrieval(total: $0, success: succeeded ?? 0, failed: failed ?? 0) }
        return record(success: success, count: count, uids: uids, retrieval: retrieval)
    }

    /// A stable, human-readable rendering. Per-study UID lines are capped so a broad
    /// (no-filter) query returning thousands of studies doesn't render an enormous
    /// diff — the `count:` line already flags a size mismatch outright.
    static let resultDisplayCap = 150
    public static func canonical(_ s: QRSemantics) -> [String] {
        var out = ["success: \(s.success)", "count: \(s.count)"]
        for (i, u) in s.studyUIDs.prefix(resultDisplayCap).enumerated() { out.append("[\(i)] \(u)") }
        if s.studyUIDs.count > resultDisplayCap {
            out.append("… (\(s.studyUIDs.count - resultDisplayCap) more studies not shown)")
        }
        if let r = s.retrieval {
            out.append("retrieved.total: \(r.total)")
            out.append("retrieved.success: \(r.success)")
            out.append("retrieved.failed: \(r.failed)")
        }
        return out
    }

    /// Compares the structured reference record against the CLI's parsed record.
    public static func compare(reference: QRSemantics, cli: QRSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
