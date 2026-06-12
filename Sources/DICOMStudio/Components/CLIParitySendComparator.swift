// CLIParitySendComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-send` (C-STORE) tool.
//
// dicom-send WRITES instances to the PACS. Both the app and the CLI drive the same
// DICOMStorageService.store; the parity reference does too. Comparison is on the
// store OUTCOME counts (files sent / succeeded / failed) plus the dry-run flag —
// success is taken as success-OR-warning so a duplicate-instance warning on the
// second store of the same synthetic file (reference then CLI) isn't a false drift.
// Round-trip time / throughput are never compared.

import Foundation

public struct SendSemantics: Equatable, Sendable {
    public var dryRun: Bool
    public var sent: Int
    public var succeeded: Int   // success-or-warning
    public var failed: Int

    public var overallOK: Bool { dryRun ? sent >= 1 : (failed == 0 && succeeded >= 1) }
}

public enum CLIParitySendComparator {

    /// Parses the dicom-send CLI output (stdout summary + stderr dry-run line).
    public static func parse(_ text: String, dryRun: Bool) -> SendSemantics {
        func intAfter(_ label: String) -> Int? {
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) where line.contains(label) {
                if let r = line.range(of: "[0-9]+", options: .regularExpression) { return Int(line[r]) }
            }
            return nil
        }
        if dryRun {
            // "Found N file(s) to send" + "Dry run complete."
            return SendSemantics(dryRun: true, sent: intAfter("Found") ?? 0, succeeded: 0, failed: 0)
        }
        return SendSemantics(
            dryRun: false,
            sent: intAfter("Total files:") ?? 0,
            succeeded: intAfter("Succeeded:") ?? 0,
            failed: intAfter("Failed:") ?? 0)
    }

    public static func canonical(_ s: SendSemantics) -> [String] {
        ["mode: \(s.dryRun ? "dry-run" : "send")",
         "sent: \(s.sent)",
         "succeeded: \(s.succeeded)",
         "failed: \(s.failed)"]
    }

    public static func compare(reference: SendSemantics, cli: SendSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
