// ImageMetadataHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent image metadata formatting helpers

import Foundation

/// Platform-independent helpers for formatting DICOM image pixel metadata
/// for overlay display.
///
/// Provides human-readable formatting of pixel data descriptors, window settings,
/// and photometric interpretations.
public enum ImageMetadataHelpers: Sendable {

    /// Formats image dimensions as "columns × rows".
    ///
    /// - Parameters:
    ///   - columns: Number of pixel columns.
    ///   - rows: Number of pixel rows.
    /// - Returns: Formatted string, e.g., "512 × 512".
    public static func dimensionsText(columns: Int, rows: Int) -> String {
        "\(columns) × \(rows)"
    }

    /// Formats bit depth information.
    ///
    /// - Parameters:
    ///   - bitsAllocated: Bits allocated per sample.
    ///   - bitsStored: Bits stored per sample.
    ///   - highBit: Most significant bit position.
    /// - Returns: Formatted string, e.g., "16 / 12 / 11".
    public static func bitDepthText(bitsAllocated: Int, bitsStored: Int, highBit: Int) -> String {
        "\(bitsAllocated) / \(bitsStored) / \(highBit)"
    }

    /// Returns a human-readable pixel representation label.
    ///
    /// - Parameter isSigned: Whether pixel values are signed.
    /// - Returns: "Signed" or "Unsigned".
    public static func pixelRepresentationText(isSigned: Bool) -> String {
        isSigned ? "Signed" : "Unsigned"
    }

    /// Formats samples per pixel and planar configuration.
    ///
    /// - Parameters:
    ///   - samplesPerPixel: Number of samples per pixel.
    ///   - planarConfiguration: Planar configuration (0 = color-by-pixel, 1 = color-by-plane).
    /// - Returns: Formatted string, e.g., "3 (color-by-pixel)".
    public static func samplesText(samplesPerPixel: Int, planarConfiguration: Int) -> String {
        if samplesPerPixel == 1 {
            return "1"
        }
        let configLabel = planarConfiguration == 0 ? "color-by-pixel" : "color-by-plane"
        return "\(samplesPerPixel) (\(configLabel))"
    }

    /// Returns a human-readable photometric interpretation label.
    ///
    /// - Parameter interpretation: The photometric interpretation string.
    /// - Returns: Human-readable label.
    public static func photometricLabel(for interpretation: String) -> String {
        switch interpretation.uppercased() {
        case "MONOCHROME1":
            return "Monochrome 1 (inverted)"
        case "MONOCHROME2":
            return "Monochrome 2"
        case "RGB":
            return "RGB Color"
        case "PALETTE COLOR":
            return "Palette Color"
        case "YBR_FULL":
            return "YBR Full"
        case "YBR_FULL_422":
            return "YBR Full 4:2:2"
        case "YBR_PARTIAL_422":
            return "YBR Partial 4:2:2"
        case "YBR_PARTIAL_420":
            return "YBR Partial 4:2:0"
        case "YBR_ICT":
            return "YBR ICT (JPEG 2000)"
        case "YBR_RCT":
            return "YBR RCT (JPEG 2000 Lossless)"
        default:
            return interpretation
        }
    }

    /// Formats window center/width as a display string.
    ///
    /// - Parameters:
    ///   - center: Window center value.
    ///   - width: Window width value.
    /// - Returns: Formatted string, e.g., "C: 40 W: 400".
    public static func windowLevelText(center: Double, width: Double) -> String {
        let c = center.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", center)
            : String(format: "%.1f", center)
        let w = width.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", width)
            : String(format: "%.1f", width)
        return "C: \(c) W: \(w)"
    }

    /// Formats frame information.
    ///
    /// - Parameters:
    ///   - current: Current frame number (1-based for display).
    ///   - total: Total number of frames.
    /// - Returns: Formatted string, e.g., "Frame 1 / 120".
    public static func frameText(current: Int, total: Int) -> String {
        "Frame \(current) / \(total)"
    }

    /// Returns an estimated memory usage string for pixel data.
    ///
    /// - Parameter totalBytes: Total bytes of pixel data.
    /// - Returns: Formatted string, e.g., "25.0 MB".
    public static func memorySizeText(totalBytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(totalBytes))
    }
}
