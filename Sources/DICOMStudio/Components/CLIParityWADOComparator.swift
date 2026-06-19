// CLIParityWADOComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-wado` (DICOMweb) tool.
//
// Unlike the DIMSE tools — each of which is its own `dicom-*` binary — the four
// DICOMweb operations (QIDO-RS query, WADO-RS retrieve, STOW-RS store, UPS-RS
// worklist) are SUBCOMMANDS of a single `dicom-wado` binary. The Studio catalog
// splits them into separate tool IDs (dicom-qido / dicom-stow / dicom-ups) for the
// CLI Workshop's per-operation forms, but in CLI Parity they share the one
// `dicom-wado` binary, so the sweep drives that binary's subcommands directly:
//
//   dicom-wado query     <url> …   (QIDO-RS — read-only)
//   dicom-wado retrieve  <url> …   (WADO-RS — pulls; writes files locally)
//   dicom-wado store     <url> …   (STOW-RS — WRITES to the server)
//   dicom-wado ups       <url> …   (UPS-RS  — search read; claim writes)
//
// Both sides drive the SAME DICOMWeb package API (DICOMwebClient) — the reference
// calls it directly, the CLI calls it internally — so the records line up. Each
// subcommand has its own timing/ordering-independent semantic record below; the
// comparison is always on the OUTCOME (matched set / counts / lifecycle outcome),
// never round-trip time or throughput.

import Foundation

// MARK: - QIDO-RS query (read-only)

/// A timing/ordering-independent semantic summary of a `dicom-wado query` (QIDO-RS).
/// Mirrors the DIMSE `dicom-query` record: the matched result set is stable between
/// the reference's and the CLI's near-simultaneous calls, so the ACTUAL matched
/// attribute objects are compared (not masked counts). Each result is canonicalised
/// to a sorted "key=value;…" string (over the QIDO-RS JSON keys the CLI emits) and
/// the list is sorted, so the server returning matches in a different order is not a
/// false drift.
public struct WADOQuerySemantics: Equatable, Sendable {
    public var level: String          // "study" | "series" | "instance"
    public var success: Bool          // query completed (no HTTP/transport error)
    public var count: Int             // number of matched results
    public var results: [String]      // sorted canonical "key=value;…" per result

    public var overallOK: Bool { success }

    public init(level: String, success: Bool, count: Int, results: [String]) {
        self.level = level; self.success = success; self.count = count; self.results = results
    }
}

// MARK: - WADO-RS retrieve (pulls instances / metadata)

/// A timing-independent semantic summary of a `dicom-wado retrieve` (WADO-RS).
/// `mode == "metadata"` retrieves only the per-instance metadata (the CLI prints a
/// JSON array to stdout, the reference counts the objects); `mode == "instances"`
/// pulls the DICOM instances (the CLI writes N files to its `--output` dir, the
/// reference counts them in memory). Either way the comparison is on success + count.
public struct WADORetrieveSemantics: Equatable, Sendable {
    public var level: String          // "study" | "series" | "instance"
    public var mode: String           // "instances" | "metadata"
    public var success: Bool
    public var count: Int             // instances pulled, or metadata objects retrieved

    public var overallOK: Bool { success }

    public init(level: String, mode: String, success: Bool, count: Int) {
        self.level = level; self.mode = mode; self.success = success; self.count = count
    }
}

// MARK: - STOW-RS store (WRITES)

/// A timing-independent semantic summary of a `dicom-wado store` (STOW-RS). Both
/// sides drive DICOMwebClient.storeInstances; comparison is on the upload OUTCOME
/// counts. Success is success-OR-no-failures so a duplicate-instance warning on the
/// second store of the same synthetic file (reference then CLI) isn't a false drift.
public struct WADOStoreSemantics: Equatable, Sendable {
    public var sent: Int
    public var succeeded: Int
    public var failed: Int

    public var overallOK: Bool { failed == 0 && succeeded >= 1 }

    public init(sent: Int, succeeded: Int, failed: Int) {
        self.sent = sent; self.succeeded = succeeded; self.failed = failed
    }
}

// MARK: - UPS-RS worklist (search read / claim writes)

/// A timing/identity-independent semantic summary of a `dicom-wado ups` operation.
///
///   • search   — read-only worklist search; comparison is on the matched workitem
///                set (sorted Workitem UIDs) + count, like dicom-mwl.
///   • lifecycle — a write claim: N-CREATE the workitem (SCHEDULED) then change its
///                state to IN PROGRESS. The Workitem UID and Transaction UID are
///                client-/server-minted and differ between the reference and the
///                CLI by design, so they are NEVER compared — parity is on the
///                outcome (createOK, claimOK, finalState), like dicom-mpps.
public struct WADOUPSSemantics: Equatable, Sendable {
    public var operation: String      // "search" | "lifecycle"
    // search
    public var success: Bool          // search completed (no transport error)
    public var count: Int             // matched workitems
    public var workitemUIDs: [String] // sorted Workitem UIDs of the matches
    // lifecycle
    public var createOK: Bool         // N-CREATE (SCHEDULED) succeeded
    public var claimOK: Bool?         // state change to IN PROGRESS succeeded (nil for search)
    public var finalState: String     // "" (search) | "IN PROGRESS" | "" on failure

    /// Overall success: search → the query completed; lifecycle → create AND claim.
    public var overallOK: Bool {
        operation == "lifecycle" ? (createOK && (claimOK ?? false)) : success
    }

    public init(operation: String, success: Bool, count: Int, workitemUIDs: [String],
                createOK: Bool, claimOK: Bool?, finalState: String) {
        self.operation = operation; self.success = success; self.count = count
        self.workitemUIDs = workitemUIDs; self.createOK = createOK
        self.claimOK = claimOK; self.finalState = finalState
    }
}

public enum CLIParityWADOComparator {

    // MARK: QIDO-RS query

    /// Builds the query record from per-result attribute objects ([QIDO-JSON-key:
    /// value]), canonicalising each result to a sorted "key=value;…" string and
    /// sorting the list — identical reduction for the reference and the CLI.
    public static func querySemantics(level: String, success: Bool, objects: [[String: String]]) -> WADOQuerySemantics {
        let canon = objects.map { obj in
            obj.keys.sorted().map { "\($0)=\(obj[$0] ?? "")" }.joined(separator: ";")
        }.sorted()
        return WADOQuerySemantics(level: level, success: success, count: objects.count, results: canon)
    }

    /// Parses a `dicom-wado query --format json` stdout (a JSON array of QIDO-RS
    /// result objects, keyed by the CLI's camel-case names: StudyInstanceUID,
    /// PatientName, …) into the record. The reference produces the IDENTICAL JSON
    /// (same key construction) and feeds it through this same parse, so the two
    /// records compare equal iff the matched sets are equal.
    public static func parseQuery(_ jsonStdout: String, level: String, success: Bool) -> WADOQuerySemantics {
        querySemantics(level: level, success: success, objects: parseObjects(jsonStdout))
    }

    static func parseObjects(_ jsonStdout: String) -> [[String: String]] {
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

    static let resultDisplayCap = 150
    public static func queryCanonical(_ s: WADOQuerySemantics) -> [String] {
        var out = ["level: \(s.level)", "success: \(s.success)", "count: \(s.count)"]
        for (i, r) in s.results.prefix(resultDisplayCap).enumerated() { out.append("[\(i)] \(r)") }
        if s.results.count > resultDisplayCap {
            out.append("… (\(s.results.count - resultDisplayCap) more results not shown)")
        }
        return out
    }

    public static func compareQuery(reference: WADOQuerySemantics, cli: WADOQuerySemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: queryCanonical(cli), studio: queryCanonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }

    /// The JSON format carries full attributes → full result-set parity; the
    /// table/csv formats drop or truncate fields, so they're validated by result
    /// COUNT. The QIDO-RS table is a "="-bordered block (header + N data rows + a
    /// trailing border); the CSV is a header row + one row per result.
    public static func count(in stdout: String, format: String) -> Int {
        switch format {
        case "json":
            return parseObjects(stdout).count
        case "csv":
            let lines = stdout.split(separator: "\n", omittingEmptySubsequences: true)
            return lines.isEmpty ? 0 : max(0, lines.count - 1)
        default: // table — data rows are the lines between the "="-borders that
                 // aren't the border itself or the column-header line.
            let lines = stdout.split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let borders = lines.filter { !$0.isEmpty && $0.allSatisfy { $0 == "=" } }.count
            guard borders >= 2 else { return 0 }
            // rows = (non-empty, non-border lines) − 1 header line.
            let content = lines.filter { !$0.isEmpty && !$0.allSatisfy { $0 == "=" } }.count
            return max(0, content - 1)
        }
    }

    public static func compareCount(reference: WADOQuerySemantics, cliCount: Int, format: String)
        -> (diff: [OutputDiffLine], match: Bool) {
        let ref = ["level: \(reference.level)", "format: \(format)", "count: \(reference.count)"]
        let cli = ["level: \(reference.level)", "format: \(format)", "count: \(cliCount)"]
        let diff = CLIParityEngine.diff(cli: cli, studio: ref)
        return (diff, !diff.contains { $0.kind != .same })
    }

    // MARK: WADO-RS retrieve

    public static func retrieveRecord(level: String, mode: String, success: Bool, count: Int) -> WADORetrieveSemantics {
        WADORetrieveSemantics(level: level, mode: mode, success: success, count: count)
    }

    /// Parses a `dicom-wado retrieve --metadata --format json` stdout: the CLI prints
    /// the metadata as a JSON array (one object per instance), so the object count is
    /// the array length. Used only for the metadata mode; the instances mode compares
    /// the file count the CLI wrote to its `--output` dir (counted by the runner).
    public static func parseMetadataCount(_ jsonStdout: String) -> Int {
        guard let start = jsonStdout.firstIndex(of: "["),
              let end = jsonStdout.lastIndex(of: "]"), start <= end else { return 0 }
        let slice = String(jsonStdout[start...end])
        guard let data = slice.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        return arr.count
    }

    public static func retrieveCanonical(_ s: WADORetrieveSemantics) -> [String] {
        ["mode: \(s.mode)", "level: \(s.level)", "success: \(s.success)", "count: \(s.count)"]
    }

    public static func compareRetrieve(reference: WADORetrieveSemantics, cli: WADORetrieveSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: retrieveCanonical(cli), studio: retrieveCanonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }

    // MARK: STOW-RS store

    /// Parses the `dicom-wado store` stdout "Upload Summary" block:
    ///   Total files: N / Successful: N / Failed: N
    public static func parseStore(_ text: String) -> WADOStoreSemantics {
        func intAfter(_ label: String) -> Int? {
            for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix(label) else { continue }
                if let r = line.range(of: "[0-9]+", options: .regularExpression) { return Int(line[r]) }
            }
            return nil
        }
        return WADOStoreSemantics(
            sent: intAfter("Total files:") ?? 0,
            succeeded: intAfter("Successful:") ?? 0,
            failed: intAfter("Failed:") ?? 0)
    }

    public static func storeCanonical(_ s: WADOStoreSemantics) -> [String] {
        ["sent: \(s.sent)", "succeeded: \(s.succeeded)", "failed: \(s.failed)"]
    }

    public static func compareStore(reference: WADOStoreSemantics, cli: WADOStoreSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: storeCanonical(cli), studio: storeCanonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }

    // MARK: UPS-RS worklist

    /// Builds the search record from a match count and the per-match Workitem UIDs (sorted).
    public static func searchRecord(success: Bool, count: Int, uids: [String]) -> WADOUPSSemantics {
        WADOUPSSemantics(operation: "search", success: success, count: count,
                         workitemUIDs: uids.sorted(), createOK: false, claimOK: nil, finalState: "")
    }

    /// Builds the lifecycle (claim) record: N-CREATE then state change to IN PROGRESS.
    public static func lifecycleRecord(createOK: Bool, claimOK: Bool?, finalState: String) -> WADOUPSSemantics {
        WADOUPSSemantics(operation: "lifecycle", success: createOK && (claimOK ?? false), count: 0,
                         workitemUIDs: [], createOK: createOK, claimOK: claimOK, finalState: finalState)
    }

    /// Parses a `dicom-wado ups --search --format json` stdout: a JSON array of
    /// workitems, each carrying `workitemUID`. Each item's UID is collected; the
    /// count is the array length. Leading verbose / `── stderr ──` text is sliced off
    /// by taking the first '[' to the last ']'.
    public static func parseSearch(_ jsonStdout: String, success: Bool) -> WADOUPSSemantics {
        var uids: [String] = []
        if let start = jsonStdout.firstIndex(of: "["), let end = jsonStdout.lastIndex(of: "]"), start <= end,
           let data = String(jsonStdout[start...end]).data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in arr {
                if let uid = item["workitemUID"] as? String, !uid.isEmpty { uids.append(uid) }
            }
            return searchRecord(success: success, count: arr.count, uids: uids)
        }
        return searchRecord(success: success, count: 0, uids: [])
    }

    /// Parses the `dicom-wado ups --create-workitem` output: whether the create
    /// succeeded and the minted Workitem UID (threaded into the subsequent claim by
    /// the runner; never compared). Success is taken from the exit code, corroborated
    /// by the "Created worklist item:" marker.
    public static func parseCreate(_ text: String, exitOK: Bool) -> (ok: Bool, uid: String?) {
        var uid: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("UID:") {
                let v = line.dropFirst("UID:".count).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { uid = v }
            }
        }
        return (exitOK, uid)
    }

    /// Parses the `dicom-wado ups --update --state IN_PROGRESS` output: whether the
    /// claim succeeded and the server-returned Transaction UID (never compared).
    public static func parseClaim(_ text: String, exitOK: Bool) -> (ok: Bool, transactionUID: String?) {
        var tx: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Transaction UID:") {
                let v = line.dropFirst("Transaction UID:".count).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { tx = v }
            }
        }
        return (exitOK, tx)
    }

    static let upsDisplayCap = 150
    public static func upsCanonical(_ s: WADOUPSSemantics) -> [String] {
        if s.operation == "lifecycle" {
            return ["operation: lifecycle",
                    "createOK: \(s.createOK)",
                    "claimOK: \(s.claimOK.map { String($0) } ?? "—")",
                    "finalState: \(s.finalState)"]
        }
        var out = ["operation: search", "success: \(s.success)", "count: \(s.count)"]
        for (i, u) in s.workitemUIDs.prefix(upsDisplayCap).enumerated() { out.append("[\(i)] \(u)") }
        if s.workitemUIDs.count > upsDisplayCap {
            out.append("… (\(s.workitemUIDs.count - upsDisplayCap) more workitems not shown)")
        }
        return out
    }

    public static func compareUPS(reference: WADOUPSSemantics, cli: WADOUPSSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: upsCanonical(cli), studio: upsCanonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
