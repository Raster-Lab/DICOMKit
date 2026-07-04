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

    // MARK: - Elapsed time formatting (shared)

    /// Formats an elapsed time interval as a human-readable string (e.g. `0.123s`, `1.234s`, `1m 23.456s`).
    public static func formatElapsed(_ elapsed: TimeInterval) -> String {
        if elapsed < 60 {
            return String(format: "%.3fs", elapsed)
        }
        let minutes = Int(elapsed) / 60
        let seconds = elapsed.truncatingRemainder(dividingBy: 60)
        return String(format: "%dm %.3fs", minutes, seconds)
    }

    // MARK: - Phase ratio/time lines (shared)

    /// Shared "<Phase> ratio: N.N%" builder — the output size relative to the input
    /// size for a phase (below 100% = smaller; above = larger). `phase` is
    /// "Compression" or "Decompression". Returns "" when `inputSize` is 0.
    private static func ratioLine(phase: String, inputSize: Int, outputSize: Int) -> String {
        guard inputSize > 0 else { return "" }
        let ratio = Double(outputSize) / Double(inputSize) * 100.0
        return "\(phase) ratio: \(String(format: "%.1f%%", ratio))\n"
    }

    /// Shared "<Phase> time:  <elapsed>" builder. The trailing double space aligns the
    /// value under the ratio line above it (the "… time:" label is exactly one
    /// character shorter than "… ratio:").
    private static func timeLine(phase: String, elapsed: TimeInterval) -> String {
        "\(phase) time:  \(formatElapsed(elapsed))\n"
    }

    // MARK: - Compress output (shared)

    /// Verbose preamble printed before a compress run (only when `--verbose`).
    /// When `sourceTransferSyntaxName` is provided the source is already compressed, so
    /// the source codec and a "Target codec" label are shown (the run first decompresses
    /// to native pixels, then compresses). `quality` is the raw user string (echoed
    /// as-is); omitted when empty/nil.
    public static func compressPreamble(input: String, codec: String,
                                        quality: String?, backendDisplayName: String,
                                        sourceTransferSyntaxName: String? = nil) -> String {
        var out = "Compressing: \(input)\n"
        if let sourceName = sourceTransferSyntaxName {
            out += "Source codec: \(sourceName) (compressed)\n"
        }
        out += "\(sourceTransferSyntaxName != nil ? "Target codec" : "Codec"): \(codec)\n"
        if let q = quality?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            out += "Quality: \(q)\n"
        }
        out += "Backend: \(backendDisplayName)\n"
        return out
    }

    /// Informational line printed (always, not just verbose) when the source file is
    /// already compressed and will be decoded to native pixels before re-encoding.
    public static func recompressNoteLine(sourceName: String) -> String {
        "Note: Source is already compressed (\(sourceName)) — decompressing to native pixels first, then re-encoding\n"
    }

    /// The single result line every compress run prints.
    public static func compressResultLine(input: String, output: String) -> String {
        "Compressed: \(input) → \(output)\n"
    }

    /// Size-ratio line for the compression phase: output size relative to input size
    /// (below 100% = smaller). Returns "" when `inputSize` is 0.
    public static func compressRatioLine(inputSize: Int, outputSize: Int) -> String {
        ratioLine(phase: "Compression", inputSize: inputSize, outputSize: outputSize)
    }

    /// Elapsed-time line for the compression phase.
    public static func compressTimeLine(elapsed: TimeInterval) -> String {
        timeLine(phase: "Compression", elapsed: elapsed)
    }

    /// Non-verbose summary printed after a compress run. When the source was already
    /// compressed the engine decompresses it to native pixels and then re-encodes, so
    /// BOTH phases are reported — the decompression (source → native) and the
    /// compression (native → target), each with its own ratio + time. For a plain
    /// compress (uncompressed source) only the single compression ratio + time show.
    /// A recompression is signalled by a non-nil `intermediateSize` + `decompressElapsed`.
    public static func compressSummary(inputSize: Int, intermediateSize: Int?, outputSize: Int,
                                       decompressElapsed: TimeInterval?, compressElapsed: TimeInterval) -> String {
        if let inter = intermediateSize, let dt = decompressElapsed {
            return decompressRatioLine(inputSize: inputSize, outputSize: inter)
                 + decompressTimeLine(elapsed: dt)
                 + compressRatioLine(inputSize: inter, outputSize: outputSize)
                 + compressTimeLine(elapsed: compressElapsed)
        }
        return compressRatioLine(inputSize: inputSize, outputSize: outputSize)
             + compressTimeLine(elapsed: compressElapsed)
    }

    /// Verbose size/ratio/time block printed after a compress run (only when
    /// `--verbose`). Mirrors `compressSummary`'s phase handling and prepends the byte
    /// sizes (including the intermediate decompressed size for a recompression).
    public static func compressStats(inputSize: Int, intermediateSize: Int?, outputSize: Int,
                                     decompressElapsed: TimeInterval?, compressElapsed: TimeInterval) -> String {
        if let inter = intermediateSize, let dt = decompressElapsed {
            var out = "Input size:        \(formatBytes(inputSize))\n"
            out += "Decompressed size: \(formatBytes(inter))\n"
            out += "Output size:       \(formatBytes(outputSize))\n"
            out += decompressRatioLine(inputSize: inputSize, outputSize: inter)
            out += decompressTimeLine(elapsed: dt)
            out += compressRatioLine(inputSize: inter, outputSize: outputSize)
            out += compressTimeLine(elapsed: compressElapsed)
            return out
        }
        var out = "Input size:  \(formatBytes(inputSize))\n"
        out += "Output size: \(formatBytes(outputSize))\n"
        out += compressRatioLine(inputSize: inputSize, outputSize: outputSize)
        out += compressTimeLine(elapsed: compressElapsed)
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

    /// Size-expansion ratio line for a decompress run: the uncompressed output
    /// relative to the compressed input (above 100% = larger). Returns "" when
    /// `inputSize` is 0.
    public static func decompressRatioLine(inputSize: Int, outputSize: Int) -> String {
        ratioLine(phase: "Decompression", inputSize: inputSize, outputSize: outputSize)
    }

    /// Elapsed-time line printed after a decompress run.
    public static func decompressTimeLine(elapsed: TimeInterval) -> String {
        timeLine(phase: "Decompression", elapsed: elapsed)
    }

    /// Non-verbose summary printed after a decompress run: expansion ratio + time.
    public static func decompressSummary(inputSize: Int, outputSize: Int, elapsed: TimeInterval) -> String {
        decompressRatioLine(inputSize: inputSize, outputSize: outputSize)
            + decompressTimeLine(elapsed: elapsed)
    }

    /// Verbose size/ratio/time block printed after a decompress run (only when `--verbose`).
    public static func decompressStats(inputSize: Int, outputSize: Int, elapsed: TimeInterval? = nil) -> String {
        var out = "Input size:  \(formatBytes(inputSize))\n"
        out += "Output size: \(formatBytes(outputSize))\n"
        out += decompressRatioLine(inputSize: inputSize, outputSize: outputSize)
        if let t = elapsed {
            out += decompressTimeLine(elapsed: t)
        }
        return out
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

    // MARK: - Info subcommand (shared)

    /// The codec label the `info` text output prints (HTJ2K distinguished by UID prefix).
    private static func infoCodecLabel(_ info: CompressionInfo) -> String {
        if info.isJPEG { return "JPEG" }
        if info.isJPEG2000 {
            return info.transferSyntaxUID.hasPrefix("1.2.840.10008.1.2.4.20")
                ? "HTJ2K (High-Throughput JPEG 2000)" : "JPEG 2000"
        }
        if info.isJPEGLS { return "JPEG-LS" }
        if info.isJPEGXL { return "JPEG XL" }
        if info.isRLE { return "RLE" }
        if info.isDeflated { return "Deflate" }
        return "None (uncompressed)"
    }

    /// The full `dicom-compress info` text block (every line newline-terminated).
    public static func infoText(_ info: CompressionInfo, filePath: String) -> String {
        var lines: [String] = []
        lines.append("File: \(filePath)")
        lines.append("Transfer Syntax: \(info.transferSyntaxName)")
        lines.append("Transfer Syntax UID: \(info.transferSyntaxUID)")
        lines.append("Compressed: \(info.isCompressed ? "Yes" : "No")")
        lines.append("Lossless: \(info.isLossless ? "Yes" : "No")")
        lines.append("Codec: \(infoCodecLabel(info))")
        if let size = info.pixelDataSize {
            lines.append("Pixel Data Size: \(formatBytes(size))")
        } else {
            lines.append("Pixel Data Size: N/A (no pixel data)")
        }
        if let rows = info.rows, let cols = info.columns {
            lines.append("Image Dimensions: \(cols) x \(rows)")
        }
        if let ba = info.bitsAllocated { lines.append("Bits Allocated: \(ba)") }
        if let bs = info.bitsStored { lines.append("Bits Stored: \(bs)") }
        if let spp = info.samplesPerPixel { lines.append("Samples Per Pixel: \(spp)") }
        if let pi = info.photometricInterpretation { lines.append("Photometric Interpretation: \(pi)") }
        if let nf = info.numberOfFrames { lines.append("Number of Frames: \(nf)") }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The full `dicom-compress info --json` document (pretty-printed, sorted keys,
    /// trailing newline). The JSON codec label intentionally has no HTJ2K variant.
    public static func infoJSON(_ info: CompressionInfo, filePath: String) throws -> String {
        var dict: [String: Any] = [
            "file": filePath,
            "transferSyntax": info.transferSyntaxName,
            "transferSyntaxUID": info.transferSyntaxUID,
            "compressed": info.isCompressed,
            "lossless": info.isLossless,
        ]
        if info.isJPEG { dict["codec"] = "JPEG" }
        else if info.isJPEG2000 { dict["codec"] = "JPEG 2000" }
        else if info.isJPEGLS { dict["codec"] = "JPEG-LS" }
        else if info.isJPEGXL { dict["codec"] = "JPEG XL" }
        else if info.isRLE { dict["codec"] = "RLE" }
        else if info.isDeflated { dict["codec"] = "Deflate" }
        else { dict["codec"] = "None" }
        if let v = info.pixelDataSize { dict["pixelDataSize"] = v }
        if let v = info.rows { dict["rows"] = Int(v) }
        if let v = info.columns { dict["columns"] = Int(v) }
        if let v = info.bitsAllocated { dict["bitsAllocated"] = Int(v) }
        if let v = info.bitsStored { dict["bitsStored"] = Int(v) }
        if let v = info.samplesPerPixel { dict["samplesPerPixel"] = Int(v) }
        if let v = info.photometricInterpretation { dict["photometricInterpretation"] = v }
        if let v = info.numberOfFrames { dict["numberOfFrames"] = v }
        let jsonData = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
        return (String(data: jsonData, encoding: .utf8) ?? "") + "\n"
    }

    /// The `info` read-failure line. The CLI prints the raw error value, not
    /// `localizedDescription` — keep that exact rendering on both surfaces.
    public static func infoErrorLine(_ error: Error) -> String {
        "Error reading file: \(error)\n"
    }

    // MARK: - Backends subcommand (shared)

    /// The full `dicom-compress backends` text block (trailing newline).
    public static func backendsText() -> String {
        let best = CodecBackendProbe.bestAvailable
        var lines: [String] = []
        lines.append("Available hardware acceleration backends:")
        lines.append("")
        for backend in CodecBackend.allCases {
            let isAvail = CodecBackendProbe.isAvailable(backend)
            let marker = isAvail ? (backend == best ? "✓ (active)" : "✓") : "✗"
            lines.append("  [\(marker)] \(backend.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0))\(backend.displayName)")
        }
        lines.append("")
        lines.append("Active backend: \(best.displayName)")
        lines.append("Use --backend <name> on the compress command to select a specific backend.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// The full `dicom-compress backends --json` document (trailing newline).
    public static func backendsJSON() throws -> String {
        let best = CodecBackendProbe.bestAvailable
        var items: [[String: Any]] = []
        for backend in CodecBackend.allCases {
            items.append([
                "backend": backend.rawValue,
                "available": CodecBackendProbe.isAvailable(backend),
                "active": backend == best,
                "displayName": backend.displayName
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted])
        return (String(data: data, encoding: .utf8) ?? "") + "\n"
    }
}
