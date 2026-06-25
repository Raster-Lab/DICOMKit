// CLIParityMWLComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-mwl` (Modality Worklist
// C-FIND) tool.
//
// dicom-mwl is READ-ONLY (a worklist C-FIND), so it's safe to run against a live
// worklist SCP. Both the package-API reference and the CLI build their query keys
// from the SAME shared `WorklistQueryKeys.default()` builder (DICOMNetwork) and
// hit the server moments apart, so the matched item set is stable between the two
// calls. The record is order-independent: each worklist item is reduced to a
// STABLE composite identity — Study Instance UID + Scheduled Procedure Step ID +
// Accession Number — and the list is sorted, so the server returning items in a
// different order between the two calls is not a false drift.
//
// We deliberately do NOT compare every attribute (scheduled times, physician
// names, …): the identity triple uniquely pins a scheduled procedure step, and
// the matched-set + count parity is what proves the CLI and the SDK agree. The
// CLI is always run with `--json` so the per-item fields parse robustly and
// order-independently (the `--json` array carries StudyInstanceUID / SPSID /
// AccessionNumber for every item).

import Foundation

/// A timing/ordering-independent semantic summary of a `dicom-mwl query` C-FIND.
public struct MWLSemantics: Equatable, Sendable {
    public var success: Bool          // query completed (no connection/protocol error)
    public var count: Int             // number of matched worklist items
    public var itemKeys: [String]     // sorted composite identity per item

    public var overallOK: Bool { success }

    public init(success: Bool, count: Int, itemKeys: [String]) {
        self.success = success; self.count = count; self.itemKeys = itemKeys
    }
}

public enum CLIParityMWLComparator {

    /// The stable composite identity for one worklist item. The Scheduled Procedure
    /// Step ID disambiguates the multiple steps a single study can schedule (so the
    /// Study UID alone is not unique per item); the Accession Number ties it to the
    /// imaging order. Empty components are kept (rendered blank) so an item missing
    /// every identifier still contributes a deterministic — if degenerate — key.
    public static func key(studyUID: String?, spsID: String?, accession: String?) -> String {
        "study=\(studyUID ?? "")|sps=\(spsID ?? "")|acc=\(accession ?? "")"
    }

    /// Builds the record from per-item identity keys (sorted). `count` is kept
    /// distinct from `keys.count` so the caller can record the true matched-item
    /// count even if it chose to pass fewer keys.
    public static func record(success: Bool, count: Int, keys: [String]) -> MWLSemantics {
        MWLSemantics(success: success, count: count, itemKeys: keys.sorted())
    }

    /// Parses the `dicom-mwl query --json` stdout: a JSON array of worklist items,
    /// each carrying `StudyInstanceUID` / `SPSID` / `AccessionNumber` (any of which
    /// may be absent). Each item is reduced to its composite identity key; the count
    /// is the array length. Leading verbose / `── stderr ──` text is sliced off by
    /// taking the first '[' to the last ']'.
    public static func parse(_ jsonStdout: String, success: Bool) -> MWLSemantics {
        let items = parseItems(jsonStdout)
        let keys = items.map { key(studyUID: $0["StudyInstanceUID"], spsID: $0["SPSID"], accession: $0["AccessionNumber"]) }
        return record(success: success, count: items.count, keys: keys)
    }

    static func parseItems(_ jsonStdout: String) -> [[String: String]] {
        guard let start = jsonStdout.firstIndex(of: "["),
              let end = jsonStdout.lastIndex(of: "]"), start <= end else { return [] }
        let slice = String(jsonStdout[start...end])
        guard let data = slice.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { dict in
            var out: [String: String] = [:]
            for (k, v) in dict { out[k] = "\(v)" }
            return out
        }
    }

    /// A stable, human-readable rendering of the record. Per-item lines are capped so
    /// a broad (no-filter) worklist returning a huge set doesn't render an enormous
    /// diff — the `count:` line already flags a size mismatch outright.
    static let itemDisplayCap = 150
    public static func canonical(_ s: MWLSemantics) -> [String] {
        var out = ["success: \(s.success)", "count: \(s.count)"]
        for (i, k) in s.itemKeys.prefix(itemDisplayCap).enumerated() { out.append("[\(i)] \(k)") }
        if s.itemKeys.count > itemDisplayCap {
            out.append("… (\(s.itemKeys.count - itemDisplayCap) more items not shown)")
        }
        return out
    }

    /// Compares the structured reference record against the CLI's parsed record.
    public static func compare(reference: MWLSemantics, cli: MWLSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
