// CLIParityMPPSComparator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Semantic comparator for the CLI Parity screen's `dicom-mpps` (Modality
// Performed Procedure Step) tool.
//
// dicom-mpps WRITES to the PACS/RIS: N-CREATE starts a performed procedure step
// and N-SET completes/discontinues it. The screen sweeps the FULL lifecycle —
// the package-API reference (DICOMMPPSService.create → .update) and the real CLI
// (`dicom-mpps create` → `dicom-mpps update`) each run an independent
// create-then-update against the same server.
//
// The MPPS SOP Instance UID is generated CLIENT-SIDE (UIDGenerator) inside
// DICOMMPPSService.create, so the reference and the CLI necessarily mint
// DIFFERENT UIDs — the UID is therefore NEVER compared. Parity is on the OUTCOME:
// did N-CREATE succeed, did N-SET succeed, the final status the step landed in,
// and the number of referenced images carried by N-SET. (A create-only scenario
// has no N-SET, so `updateOK` is nil and `finalStatus` is the create status.)

import Foundation

/// A timing/identity-independent semantic summary of an MPPS lifecycle.
public struct MPPSSemantics: Equatable, Sendable {
    public var lifecycle: Bool        // true: N-CREATE + N-SET; false: N-CREATE only
    public var createOK: Bool         // N-CREATE succeeded
    public var updateOK: Bool?        // N-SET succeeded (nil for create-only)
    public var finalStatus: String    // "IN PROGRESS" | "COMPLETED" | "DISCONTINUED"
    public var referencedImages: Int  // referenced image count carried by N-SET

    /// Overall success: the create succeeded and (for a lifecycle) so did the update.
    public var success: Bool { createOK && (updateOK ?? true) }
    public var overallOK: Bool { success }

    public init(lifecycle: Bool, createOK: Bool, updateOK: Bool?,
                finalStatus: String, referencedImages: Int) {
        self.lifecycle = lifecycle; self.createOK = createOK; self.updateOK = updateOK
        self.finalStatus = finalStatus; self.referencedImages = referencedImages
    }
}

public enum CLIParityMPPSComparator {

    public static func record(lifecycle: Bool, createOK: Bool, updateOK: Bool?,
                              finalStatus: String, referencedImages: Int) -> MPPSSemantics {
        MPPSSemantics(lifecycle: lifecycle, createOK: createOK, updateOK: updateOK,
                      finalStatus: finalStatus, referencedImages: referencedImages)
    }

    /// Parses the `dicom-mpps create` output (now printed to STDOUT via the shared
    /// NetworkConsole formatter; the runner passes the combined stdout+stderr text in
    /// for robustness). Returns whether the create succeeded and the minted MPPS SOP
    /// Instance UID — the latter is NOT used for comparison; the runner threads it into
    /// the subsequent `dicom-mpps update --mpps-uid …`. Success is taken from the exit
    /// code (the CLI exits nonzero on any failure).
    public static func parseCreate(_ text: String, exitOK: Bool) -> (ok: Bool, uid: String?) {
        var uid: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("MPPS Instance UID:") {
                let v = line.dropFirst("MPPS Instance UID:".count).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { uid = v }
            }
        }
        return (exitOK, uid)
    }

    /// Parses the `dicom-mpps update` output (STDOUT via the shared NetworkConsole
    /// formatter; combined stdout+stderr is passed in): the new status and the
    /// referenced-image count (printed only when ≥1 image was referenced — absent ==
    /// 0). Success is from the exit code.
    public static func parseUpdate(_ text: String, exitOK: Bool) -> (ok: Bool, status: String?, refImages: Int) {
        var status: String?
        var refImages = 0
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("New Status:") {
                status = line.dropFirst("New Status:".count).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Referenced Images:") {
                if let r = line.range(of: "[0-9]+", options: .regularExpression) { refImages = Int(line[r]) ?? 0 }
            }
        }
        return (exitOK, status, refImages)
    }

    /// A stable, human-readable rendering. The UID is intentionally omitted — it is
    /// client-generated and differs between the reference and the CLI by design.
    public static func canonical(_ s: MPPSSemantics) -> [String] {
        ["lifecycle: \(s.lifecycle)",
         "createOK: \(s.createOK)",
         "updateOK: \(s.updateOK.map { String($0) } ?? "—")",
         "finalStatus: \(s.finalStatus)",
         "referencedImages: \(s.referencedImages)"]
    }

    /// Compares the structured reference record against the CLI's parsed record.
    public static func compare(reference: MPPSSemantics, cli: MPPSSemantics)
        -> (diff: [OutputDiffLine], match: Bool) {
        let diff = CLIParityEngine.diff(cli: canonical(cli), studio: canonical(reference))
        return (diff, !diff.contains { $0.kind != .same })
    }
}
