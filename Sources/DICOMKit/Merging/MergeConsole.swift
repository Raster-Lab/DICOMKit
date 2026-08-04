import Foundation

/// Console lines and validation messages for `dicom-merge` — the single source of
/// truth used by BOTH the CLI and DICOMStudio's Workshop executor, so their
/// output cannot drift.
///
/// `FrameMerger` already shares the merge itself (and its progress lines through
/// the `log` sink) plus `gatherInputFiles`; the banner, the "Found N files" line,
/// the completion line and the three validation messages were duplicated, and had
/// drifted in three ways: the app dropped the version from the banner, relabelled
/// `Inputs: N path(s)` to `Input: <path>` and padded the `Level:`/`Sort:` labels,
/// and the CLI interpolated the option *enums* (printing `enhancedCt`,
/// `instanceNumber`) where the app printed what the user actually typed
/// (`enhanced-ct`, `InstanceNumber`). The raw values win here.
public enum MergeConsole {
    /// Mirrors `CommandConfiguration.version` in the CLI; part of the banner text.
    public static let toolVersion = "1.1.2"

    // MARK: - Validation messages

    /// No `<inputs>` given at all.
    public static let noInputFilesMessage = "No input files specified"

    /// One of the `<inputs>` roots doesn't exist.
    public static func inputNotFoundMessage(path: String) -> String {
        "Input path does not exist: \(path)"
    }

    /// The roots exist but the (shared, sorted) gather found no DICOM files.
    public static let noDICOMFilesFoundMessage = "No DICOM files found in input paths"

    // MARK: - Console lines

    /// Verbose banner, emitted before gathering. Newline-free lines.
    public static func headerLines(
        inputCount: Int,
        output: String,
        format: MergeFormat,
        level: MergeLevel,
        sortBy: MergeSortCriteria,
        order: MergeSortOrder
    ) -> [String] {
        [
            "DICOM Merge Tool v\(toolVersion)",
            "========================",
            "Inputs: \(inputCount) path(s)",
            "Output: \(output)",
            "Format: \(format.rawValue)",
            "Level: \(level.rawValue)",
            "Sort: \(sortBy.rawValue) (\(order.rawValue))",
            "",
        ]
    }

    /// Verbose line emitted once the input files have been gathered.
    public static func foundFilesLines(count: Int) -> [String] {
        ["Found \(count) DICOM files to process", ""]
    }

    /// Final summary (a blank line, then the completion text).
    public static func completionLines() -> [String] {
        ["", "Merge complete!"]
    }
}
