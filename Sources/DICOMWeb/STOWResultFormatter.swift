import Foundation

/// Console renderings shared by the `dicom-wado store` CLI (STOW-RS) and
/// DICOMStudio's in-app STOW upload, so both produce identical text for the same
/// upload outcome. This is the store-side peer of `QIDOResultFormatter` (query) and
/// `UPSResultFormatter` (ups): a SINGLE formatter both sides call, so their output
/// pipelines cannot drift.
///
/// The line/block strings here are the canonical `dicom-wado store` output — the
/// CLI-parity comparator's `parseStore` anchors on the "Upload Summary:" markers, so
/// the summary block format is a contract and must not change without updating that
/// parser (`CLIParityWADOComparator.parseStore`) and its unit test.
///
/// Each method returns text WITHOUT a trailing newline; callers add line termination
/// (the CLI via `fprintln`, the app via `appendConsoleOutput(_ + "\n")`).
public struct STOWResultFormatter {
    public init() {}

    /// The verbose pre-upload header block (emitted only under `--verbose`).
    /// Mirrors the CLI's preamble:
    ///   DICOMweb Server: <baseURL>
    ///   Target Study: <uid>        (only when a target study is set)
    ///   Files to upload: <count>
    ///   Batch size: <batch>
    public func header(baseURL: String, targetStudyUID: String?, fileCount: Int, batchSize: Int) -> String {
        var lines = ["DICOMweb Server: \(baseURL)"]
        if let uid = targetStudyUID, !uid.isEmpty {
            lines.append("Target Study: \(uid)")
        }
        lines.append("Files to upload: \(fileCount)")
        lines.append("Batch size: \(batchSize)")
        return lines.joined(separator: "\n")
    }

    /// Verbose per-batch start line: `Batch <n>: Uploading <count> file(s)...`
    public func batchStart(batchNumber: Int, fileCount: Int) -> String {
        "Batch \(batchNumber): Uploading \(fileCount) file(s)..."
    }

    /// Verbose per-batch result line: `  Success: <s>, Failure: <f>`
    public func batchResult(success: Int, failure: Int) -> String {
        "  Success: \(success), Failure: \(failure)"
    }

    /// Verbose per-failure detail line: `    Failed: <sopInstanceUID> - <reason>`.
    /// `uid` falls back to "unknown" and `reason` should already be resolved
    /// (description, else "Code <n>", else "unknown error").
    public func failureDetail(sopInstanceUID: String?, reason: String) -> String {
        "    Failed: \(sopInstanceUID ?? "unknown") - \(reason)"
    }

    /// Resolves a STOW failure to its human-readable reason, identical on both sides:
    /// the failure description, else "Code <n>", else "unknown error".
    public func failureReason(description: String?, code: UInt16?) -> String {
        description ?? (code.map { "Code \($0)" } ?? "unknown error")
    }

    /// The always-printed final summary block (the parity contract):
    ///
    ///     <blank line>
    ///     Upload Summary:
    ///       Total files: <total>
    ///       Successful: <succeeded>
    ///       Failed: <failed>
    public func summary(total: Int, succeeded: Int, failed: Int) -> String {
        """

        Upload Summary:
          Total files: \(total)
          Successful: \(succeeded)
          Failed: \(failed)
        """
    }
}
