// CompressionConsole.swift
// DICOMKit
//
// Shared console-output + input-parsing helpers for `dicom-compress`.
//
// WHY: the standalone `dicom-compress` CLI and DICOMStudio's CLI Workshop both
// drive the SAME `CompressionManager` engine, but each used to format its own
// console text (byte sizes, the "Compressed:" line, the verbose preamble/stats)
// and parse `--quality` with its own copy of the logic. Duplicated formatting
// drifts: a tweak in one surface silently diverges the other, and the Workshop's
// terminal-compare then reports a mismatch even though the bytes are identical.
//
// This type is the single source of truth for that text and for `--quality`
// parsing, so the CLI and the app render byte-for-byte identical output. It is
// pure (no I/O) and `Sendable`, so it is safe to call from the app's detached
// formatting tasks and the CLI alike.
//
// Reference: mirrors the shared-formatter pattern used by NetworkConsole and
// DICOMConverter (CLI ↔ app parity).

import Foundation
import DICOMCore

/// Pure formatters and parsers shared by the `dicom-compress` CLI and the
/// DICOMStudio CLI Workshop so their console output never drifts.
public enum CompressionConsole {

    // MARK: - Input parsing (shared)

    /// Parses the `--quality` option: `maximum` / `high` / `medium` / `low`, or a
    /// floating-point value in `0.0...1.0`. Returns `nil` when no value is given
    /// (codec default). Throws `CompressionError.invalidQuality` on a bad value —
    /// the CLI and app surface the identical message.
    public static func parseQuality(_ string: String?) throws -> CompressionQuality? {
        guard let qs = string?.trimmingCharacters(in: .whitespaces), !qs.isEmpty else { return nil }
        switch qs.lowercased() {
        case "maximum": return .maximum
        case "high":    return .high
        case "medium":  return .medium
        case "low":     return .low
        default:
            if let v = Double(qs), v >= 0.0, v <= 1.0 { return .custom(v) }
            throw CompressionError.invalidQuality(qs)
        }
    }

    /// Maps a `--backend` raw value to a `CodecBackendPreference` (defaults to
    /// `.auto` for unknown/empty input), matching the CLI's accepted spellings.
    public static func backendPreference(for raw: String) -> CodecBackendPreference {
        switch raw.lowercased() {
        case "metal":      return .metal
        case "accelerate": return .accelerate
        case "scalar":     return .scalar
        default:           return .auto
        }
    }

    // MARK: - Byte formatting (shared)

    /// Formats a byte count using binary (1024) units: `B`, `KB`, `MB`, `GB`.
    public static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0)) }
        return String(format: "%.1f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
    }

    // MARK: - Compress output (shared)

    /// Verbose preamble printed before a compress run (only when `--verbose`).
    /// `quality` is the raw user string (echoed as-is); omitted when empty/nil.
    public static func compressPreamble(input: String, codec: String,
                                        quality: String?, backendDisplayName: String) -> String {
        var out = "Compressing: \(input)\n"
        out += "Codec: \(codec)\n"
        if let q = quality?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            out += "Quality: \(q)\n"
        }
        out += "Backend: \(backendDisplayName)\n"
        return out
    }

    /// The single result line every compress run prints.
    public static func compressResultLine(input: String, output: String) -> String {
        "Compressed: \(input) → \(output)\n"
    }

    /// Verbose size/ratio block printed after a compress run (only when `--verbose`).
    public static func compressStats(inputSize: Int, outputSize: Int) -> String {
        var out = "Input size:  \(formatBytes(inputSize))\n"
        out += "Output size: \(formatBytes(outputSize))\n"
        if inputSize > 0 {
            let ratio = Double(outputSize) / Double(inputSize) * 100.0
            out += "Ratio: \(String(format: "%.1f%%", ratio))\n"
        }
        return out
    }

    // MARK: - Decompress output (shared)

    /// Verbose preamble printed before a decompress run (only when `--verbose`).
    public static func decompressPreamble(input: String, targetSyntaxName: String) -> String {
        "Decompressing: \(input)\nTarget syntax: \(targetSyntaxName)\n"
    }

    /// The single result line every decompress run prints.
    public static func decompressResultLine(input: String, output: String) -> String {
        "Decompressed: \(input) → \(output)\n"
    }

    /// Verbose size block printed after a decompress run (only when `--verbose`).
    public static func decompressStats(inputSize: Int, outputSize: Int) -> String {
        "Input size:  \(formatBytes(inputSize))\nOutput size: \(formatBytes(outputSize))\n"
    }

    // MARK: - Batch output (shared)

    /// The "Found N DICOM file(s)" line printed at the start of a batch run.
    public static func batchFoundLine(count: Int) -> String {
        "Found \(count) DICOM file(s)\n"
    }

    /// A per-file progress line (only when `--verbose`). `error` is the rendered
    /// error string for a failure (nil for success).
    public static func batchProgressLine(success: Bool, relativePath: String, error: String?) -> String {
        if success { return "  ✅ \(relativePath)\n" }
        return "  ❌ \(relativePath): \(error ?? "")\n"
    }

    /// The summary line printed at the end of a batch run.
    public static func batchSummaryLine(decompress: Bool, success: Int, fail: Int, total: Int) -> String {
        let action = decompress ? "Decompressed" : "Compressed"
        return "\(action): \(success) succeeded, \(fail) failed out of \(total) files\n"
    }
}
