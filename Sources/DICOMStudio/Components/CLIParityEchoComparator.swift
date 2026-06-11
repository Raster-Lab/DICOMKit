// CLIParityEchoComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's NETWORK tools (dicom-echo).
//
// Unlike the file tools — whose outputs can be diffed byte-for-byte after path
// normalization — a C-ECHO's surface text legitimately differs between the app
// and the CLI: different glyphs (✅ vs ✓), different units (ms vs s), the app's
// helpful failure hints, and a round-trip time that is volatile run-to-run. The
// user-chosen parity definition is therefore SEMANTIC: do the app and CLI agree
// on the C-ECHO OUTCOME (success/failure counts, DIMSE status, remote AE),
// ignoring timing?
//
// Both sides ultimately derive these fields from the same
// DICOMVerificationService.echo() result, so a faithful app reimplementation
// produces an identical record. This file extracts that record from each side's
// text (tolerant to the wording each uses) and diffs the canonical form.

import Foundation

/// A timing-independent semantic summary of a dicom-echo run, extracted from
/// either the app's console output or the CLI's stdout+stderr.
public struct EchoSemantics: Equatable, Sendable {
    /// "echo" for the normal verification flow, "diagnose" for `--diagnose`.
    public var mode: String
    public var sent: Int
    public var succeeded: Int
    public var failed: Int
    /// DIMSE status codes seen (e.g. ["0x0000"]), sorted. Empty when the echo
    /// failed before a response (connection error / association reject).
    public var statusCodes: [String]
    /// Distinct non-empty remote AE titles reported, sorted.
    public var remoteAEs: [String]
    // --- diagnose-only ---
    public var diagBasicOK: Bool?
    public var diagStability: Int?   // successful of 5
    public var diagResult: String?   // "PASSED" | "PARTIAL" | "FAILED"

    /// Overall success regardless of timing: at least one echo and no failures
    /// (echo mode), or a clean diagnostics pass (diagnose mode).
    public var overallOK: Bool {
        if mode == "diagnose" { return diagResult == "PASSED" }
        return failed == 0 && succeeded >= 1
    }
}

public enum CLIParityEchoComparator {

    // MARK: Parse

    /// Parses dicom-echo output (app console OR CLI stdout+stderr) into a
    /// timing-independent semantic record. Tolerant to the differing glyphs and
    /// wording the two sides use.
    public static func parse(_ raw: String) -> EchoSemantics {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let isDiagnose = lines.contains { $0.localizedCaseInsensitiveContains("diagnostic") }

        var sent = 0, succeeded = 0, failed = 0
        var sawSent = false, sawSucceeded = false, sawFailed = false
        var successMarkers = 0, failMarkers = 0
        var statusCodes: [String] = []
        var remoteAEs: [String] = []
        var diagBasicOK: Bool? = nil
        var diagStability: Int? = nil
        var diagResult: String? = nil

        for l in lines {
            // Per-echo success / failure markers (glyph-agnostic).
            if l.contains("C-ECHO successful") { successMarkers += 1 }
            if l.contains("C-ECHO failed") || l.contains("C-ECHO error") { failMarkers += 1 }

            // Summary counters (authoritative when present — esp. for --count > 1).
            if let n = intAfter(label: "Sent:", in: l)      { sent = n;      sawSent = true }
            if let n = intAfter(label: "Successful:", in: l) { succeeded = n; sawSucceeded = true }
            if let n = intAfter(label: "Failed:", in: l)     { failed = n;    sawFailed = true }

            // DIMSE status code(s) — from "Status: Success (0x0000)" etc.
            if l.contains("Status:"), let code = hexCode(in: l) { statusCodes.append(code) }

            // Remote AE title (covers "Remote AE:" and "Remote AE Title:").
            if l.contains("Remote AE") {
                let ae = valueAfterColon(l)
                if !ae.isEmpty { remoteAEs.append(ae) }
            }

            // --- diagnose specifics ---
            if l.contains("Basic connectivity:") {
                if l.contains("PASS") { diagBasicOK = true }
                else if l.contains("FAIL") || l.contains("ERROR") { diagBasicOK = false }
            }
            if l.contains("Connection stability:"), let n = firstInt(in: l) { diagStability = n }
            if l.contains("PASSED") { diagResult = "PASSED" }
            else if l.contains("Partial") { diagResult = "PARTIAL" }
            else if l.contains("All tests FAILED") || (l.hasPrefix("Result:") && l.contains("FAILED")) { diagResult = "FAILED" }
        }

        if !sawSucceeded { succeeded = successMarkers }
        if !sawFailed { failed = failMarkers }
        if !sawSent { sent = max(succeeded + failed, successMarkers + failMarkers) }
        if sent == 0 { sent = succeeded + failed }   // single echo without a summary

        return EchoSemantics(
            mode: isDiagnose ? "diagnose" : "echo",
            sent: sent, succeeded: succeeded, failed: failed,
            statusCodes: Array(Set(statusCodes)).sorted(),
            remoteAEs: Array(Set(remoteAEs)).sorted(),
            diagBasicOK: diagBasicOK, diagStability: diagStability, diagResult: diagResult)
    }

    // MARK: Canonical form + diff

    /// A stable, human-readable rendering of the record — diffed to produce the
    /// per-row comparison the UI shows.
    public static func canonical(_ s: EchoSemantics) -> [String] {
        var out: [String] = ["mode: \(s.mode)"]
        if s.mode == "diagnose" {
            out.append("basic-connectivity: \(s.diagBasicOK.map { $0 ? "pass" : "fail" } ?? "n/a")")
            out.append("stability-successful: \(s.diagStability.map(String.init) ?? "n/a")")
            out.append("result: \(s.diagResult ?? "n/a")")
        } else {
            out.append("sent: \(s.sent)")
            out.append("succeeded: \(s.succeeded)")
            out.append("failed: \(s.failed)")
            out.append("dimse-status: \(s.statusCodes.isEmpty ? "(none)" : s.statusCodes.joined(separator: ","))")
            out.append("remote-ae: \(s.remoteAEs.isEmpty ? "(none)" : s.remoteAEs.joined(separator: ","))")
        }
        return out
    }

    /// Compares the app's and CLI's echo output on MEANING (timing ignored).
    /// Returns the canonical diff plus a match flag and both parsed records.
    public static func compare(appOutput: String, cliOutput: String)
        -> (diff: [OutputDiffLine], match: Bool, app: EchoSemantics, cli: EchoSemantics) {
        let a = parse(appOutput)
        let c = parse(cliOutput)
        let diff = CLIParityEngine.diff(cli: canonical(c), studio: canonical(a))
        let match = !diff.contains { $0.kind != .same }
        return (diff, match, a, c)
    }

    /// Compares a STRUCTURED reference record (built directly from the DICOMKit
    /// package API — see CLIParityNetworkReference) against the CLI's parsed record.
    /// Used by the network parity runner, which builds its reference side directly
    /// rather than from text.
    public static func compare(reference: EchoSemantics, cli: EchoSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }

    // MARK: Small parsing helpers

    private static func intAfter(label: String, in line: String) -> Int? {
        guard let r = line.range(of: label) else { return nil }
        return firstInt(in: String(line[r.upperBound...]))
    }

    private static func firstInt(in s: String) -> Int? {
        guard let r = s.range(of: "[0-9]+", options: .regularExpression) else { return nil }
        return Int(s[r])
    }

    /// Captures a 16-bit DICOM status code "0xXXXX" (case-insensitive), upper-cased.
    private static func hexCode(in line: String) -> String? {
        guard let r = line.range(of: "0[xX][0-9A-Fa-f]{4}", options: .regularExpression) else { return nil }
        return "0x" + String(line[r].suffix(4)).uppercased()
    }

    /// The trimmed value after the LAST colon — AE titles contain no colon, so
    /// this reliably extracts "TEAMPACS" from "Remote AE: TEAMPACS".
    private static func valueAfterColon(_ line: String) -> String {
        guard let idx = line.lastIndex(of: ":") else { return "" }
        return String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
    }
}
