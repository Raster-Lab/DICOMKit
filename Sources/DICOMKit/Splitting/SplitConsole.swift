import Foundation

/// Console lines and input parsing for `dicom-split` — the single source of truth
/// used by BOTH the CLI and DICOMStudio's Workshop executor, so their output
/// cannot drift.
///
/// `FrameSplitter` already shares the per-file progress lines through its `log`
/// sink; what lived in two places was everything around it: the verbose banner,
/// the completion summary, the `--frames` parser and the two input-validation
/// messages. The two copies had already drifted (the app dropped the version
/// from the banner and replaced the stats line with prose), which is exactly
/// what this type exists to prevent.
public enum SplitConsole {
    /// Mirrors `CommandConfiguration.version` in the CLI; part of the banner text.
    public static let toolVersion = "1.1.2"

    // MARK: - Input parsing

    /// A bad `--frames` selection. Carries the CLI-exact message so the CLI can
    /// re-wrap it in `ValidationError` and the app can print it verbatim.
    public struct FrameSelectionError: Error, CustomStringConvertible, LocalizedError {
        public let description: String
        public init(_ description: String) { self.description = description }
        public var errorDescription: String? { description }
    }

    /// Parses a `--frames` selection such as `1,3,5-10` into 0-based frame indices.
    ///
    /// `split(separator:)` omits empty components, so `1,` and `1,,2` are accepted;
    /// a whitespace-only component (`1, ,2`) is not — it fails as "Invalid frame
    /// number:", which is what the CLI always did. The app's copy skipped those
    /// components instead, silently running a different frame set.
    public static func parseFrameSelection(_ spec: String) throws -> Set<Int> {
        var indices = Set<Int>()

        for rawPart in spec.split(separator: ",") {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            if part.contains("-") {
                // Range like "5-10"
                let bounds = part.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard bounds.count == 2,
                      let start = Int(bounds[0]),
                      let end = Int(bounds[1]),
                      start <= end else {
                    throw FrameSelectionError("Invalid frame range: \(part)")
                }
                for i in start...end { indices.insert(i) }
            } else {
                guard let index = Int(part) else {
                    throw FrameSelectionError("Invalid frame number: \(part)")
                }
                indices.insert(index)
            }
        }

        return indices
    }

    // MARK: - Validation messages

    /// Input path missing. The CLI throws this inside `ValidationError` (which
    /// ArgumentParser prints as `Error: <message>`), so the app prefixes it the
    /// same way.
    public static func inputNotFoundMessage(path: String) -> String {
        "Input path does not exist: \(path)"
    }

    /// `--output` names something that already exists and isn't a directory.
    public static func outputNotDirectoryMessage(path: String) -> String {
        "Output path exists but is not a directory: \(path)"
    }

    // MARK: - Console lines

    /// Verbose banner, emitted before any frame work. Newline-free lines.
    public static func headerLines(
        input: String,
        output: String,
        format: SplitOutputFormat,
        frames: String?,
        applyWindow: Bool,
        windowCenter: Double?,
        windowWidth: Double?
    ) -> [String] {
        var lines = [
            "DICOM Split Tool v\(toolVersion)",
            "========================",
            "Input: \(input)",
            "Output: \(output)",
            "Format: \(format.rawValue)",
        ]
        if let frames, !frames.isEmpty {
            lines.append("Frames: \(frames)")
        }
        if applyWindow {
            lines.append("Window Center: \(windowCenter ?? 0)")
            lines.append("Window Width: \(windowWidth ?? 0)")
        }
        lines.append("")
        return lines
    }

    /// Final summary. Always emitted (including the all-zero case), so a run that
    /// found nothing to split still reports its counts instead of prose.
    public static func completionLines(result: SplitResult) -> [String] {
        ["",
         "Split complete! Processed: \(result.processedFiles), extracted: \(result.extracted), "
         + "skipped: \(result.skippedFiles), failed: \(result.failed)"]
    }
}
