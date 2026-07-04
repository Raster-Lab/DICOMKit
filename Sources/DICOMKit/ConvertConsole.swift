import Foundation
import DICOMCore

/// Console lines for `dicom-convert` — the single source of truth used by BOTH
/// the CLI and DICOMStudio's Workshop executor, so their output cannot drift.
///
/// The CLI's console is deliberately terse: a transcode prints one line (and
/// only when bytes were actually transcoded), an image export prints nothing,
/// and a batch prints one ✓/✗ line per file plus a final summary. An earlier
/// app copy layered extra "Read/Wrote/Transfer Syntax" chrome on top, which
/// made terminal-compare diff on every run.
public enum ConvertConsole {
    /// Single-file transcode result line — emitted only when a transcode
    /// actually happened (same-syntax copies stay silent, like the CLI).
    public static func transcodeLine(
        wasTranscoded: Bool, sourceUID: String, targetUID: String, isLossless: Bool
    ) -> String {
        guard wasTranscoded else { return "" }
        let lossInfo = isLossless ? "lossless" : "lossy"
        return "Transcoded from \(sourceUID) to \(targetUID) (\(lossInfo))\n"
    }

    /// Per-file progress line for a batch (recursive) conversion.
    public static func batchProgressLine(success: Bool, relativePath: String, error: String?) -> String {
        success ? "✓ \(relativePath)\n"
                : "✗ \(relativePath): \(error ?? "unknown error")\n"
    }

    /// Final batch summary line.
    public static func batchSummary(succeeded: Int, total: Int, failed: Int) -> String {
        "\nConversion complete: \(succeeded)/\(total) succeeded, \(failed) failed\n"
    }
}
