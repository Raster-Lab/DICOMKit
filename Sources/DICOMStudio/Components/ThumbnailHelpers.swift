// ThumbnailHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent thumbnail generation helpers

import Foundation

/// Platform-independent helpers for thumbnail generation sizing and metadata.
///
/// Provides calculations for thumbnail dimensions, default window/level settings
/// for common modalities, and thumbnail cache key generation.
public enum ThumbnailHelpers: Sendable {

    /// Calculates the scaled thumbnail dimensions maintaining aspect ratio.
    ///
    /// - Parameters:
    ///   - imageWidth: Original image width in pixels.
    ///   - imageHeight: Original image height in pixels.
    ///   - maxSize: Maximum width or height of the thumbnail.
    /// - Returns: A tuple of (width, height) for the thumbnail, or nil if input is invalid.
    public static func thumbnailDimensions(
        imageWidth: Int,
        imageHeight: Int,
        maxSize: Int
    ) -> (width: Int, height: Int)? {
        guard imageWidth > 0, imageHeight > 0, maxSize > 0 else { return nil }

        if imageWidth <= maxSize && imageHeight <= maxSize {
            return (imageWidth, imageHeight)
        }

        let widthRatio = Double(maxSize) / Double(imageWidth)
        let heightRatio = Double(maxSize) / Double(imageHeight)
        let scale = min(widthRatio, heightRatio)

        let newWidth = max(1, Int(Double(imageWidth) * scale))
        let newHeight = max(1, Int(Double(imageHeight) * scale))
        return (newWidth, newHeight)
    }

    /// Returns default window center and width for a given modality.
    ///
    /// These defaults are used when no window/level is specified in the DICOM header,
    /// providing reasonable visibility for thumbnail generation.
    ///
    /// - Parameter modality: The DICOM modality code (e.g., "CT", "MR", "CR").
    /// - Returns: A tuple of (center, width) values.
    public static func defaultWindowSettings(for modality: String) -> (center: Double, width: Double) {
        switch modality.uppercased() {
        case "CT":
            return (center: 40.0, width: 400.0) // Soft tissue
        case "MR":
            return (center: 500.0, width: 1000.0)
        case "CR", "DX":
            return (center: 2048.0, width: 4096.0)
        case "MG":
            return (center: 3000.0, width: 6000.0)
        case "NM", "PT":
            return (center: 500.0, width: 1000.0)
        case "US":
            return (center: 128.0, width: 256.0)
        case "XA":
            return (center: 128.0, width: 256.0)
        default:
            return (center: 128.0, width: 256.0)
        }
    }

    /// Generates a cache key for a thumbnail.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: The SOP Instance UID.
    ///   - frameNumber: The frame number (0-based).
    /// - Returns: A cache key string safe for file naming.
    public static func cacheKey(sopInstanceUID: String, frameNumber: Int = 0) -> String {
        let sanitized = sopInstanceUID.replacingOccurrences(of: ".", with: "_")
        if frameNumber > 0 {
            return "\(sanitized)_f\(frameNumber)"
        }
        return sanitized
    }

    /// Determines whether a thumbnail should be generated for the given instance.
    ///
    /// - Parameters:
    ///   - rows: Number of pixel rows (may be nil if no pixel data).
    ///   - columns: Number of pixel columns (may be nil if no pixel data).
    ///   - photometricInterpretation: Photometric interpretation string.
    /// - Returns: `true` if the instance contains renderable pixel data.
    public static func shouldGenerateThumbnail(
        rows: Int?,
        columns: Int?,
        photometricInterpretation: String?
    ) -> Bool {
        guard let r = rows, let c = columns else { return false }
        guard r > 0, c > 0 else { return false }
        // Must have a photometric interpretation to render
        guard let pi = photometricInterpretation, !pi.isEmpty else { return false }
        return true
    }

    /// Returns the supported photometric interpretations for thumbnail generation.
    public static let supportedPhotometricInterpretations: Set<String> = [
        "MONOCHROME1", "MONOCHROME2", "RGB",
        "PALETTE COLOR", "YBR_FULL", "YBR_FULL_422", "YBR_PARTIAL_422"
    ]

    /// Checks if a photometric interpretation is supported for thumbnail rendering.
    ///
    /// - Parameter interpretation: The photometric interpretation string.
    /// - Returns: `true` if thumbnails can be generated for this interpretation.
    public static func isSupportedPhotometricInterpretation(_ interpretation: String) -> Bool {
        supportedPhotometricInterpretations.contains(interpretation.uppercased())
    }
}
