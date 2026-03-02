// SurfaceExtractionHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent surface extraction helpers

import Foundation

/// Platform-independent helpers for isosurface extraction parameters,
/// mesh statistics, and export format utilities.
public enum SurfaceExtractionHelpers: Sendable {

    // MARK: - Common Thresholds

    /// Standard Hounsfield Unit thresholds for common tissue types.
    public static let boneThreshold: Double = 300.0
    /// Soft tissue threshold.
    public static let softTissueThreshold: Double = 0.0
    /// Skin threshold.
    public static let skinThreshold: Double = -200.0
    /// Lung threshold.
    public static let lungThreshold: Double = -500.0

    /// All standard presets as (label, threshold) pairs.
    public static let standardPresets: [(label: String, threshold: Double)] = [
        ("Bone", 300.0),
        ("Soft Tissue", 0.0),
        ("Skin", -200.0),
        ("Lung", -500.0),
    ]

    // MARK: - Threshold Validation

    /// Validates that a threshold is within a reasonable HU range.
    ///
    /// - Parameter threshold: The HU threshold to validate.
    /// - Returns: Whether the threshold is valid (–1024 to +3071).
    public static func isValidThreshold(_ threshold: Double) -> Bool {
        threshold >= -1024.0 && threshold <= 3071.0
    }

    /// Clamps a threshold to a valid HU range.
    ///
    /// - Parameter threshold: The HU threshold.
    /// - Returns: Clamped threshold.
    public static func clampThreshold(_ threshold: Double) -> Double {
        max(-1024.0, min(3071.0, threshold))
    }

    // MARK: - Export Format

    /// Returns the file extension for an export format.
    ///
    /// - Parameter format: Export format.
    /// - Returns: File extension (without dot).
    public static func fileExtension(for format: SurfaceExportFormat) -> String {
        switch format {
        case .stl: return "stl"
        case .obj: return "obj"
        }
    }

    /// Returns a MIME type for an export format.
    ///
    /// - Parameter format: Export format.
    /// - Returns: MIME type string.
    public static func mimeType(for format: SurfaceExportFormat) -> String {
        switch format {
        case .stl: return "model/stl"
        case .obj: return "model/obj"
        }
    }

    /// Returns a user-facing label for an export format.
    ///
    /// - Parameter format: Export format.
    /// - Returns: Display label.
    public static func formatLabel(_ format: SurfaceExportFormat) -> String {
        switch format {
        case .stl: return "STL (Binary)"
        case .obj: return "OBJ (ASCII)"
        }
    }

    /// Returns a description of an export format's typical use.
    ///
    /// - Parameter format: Export format.
    /// - Returns: Use-case description.
    public static func formatDescription(_ format: SurfaceExportFormat) -> String {
        switch format {
        case .stl: return "3D printing, rapid prototyping"
        case .obj: return "3D modeling, visualization"
        }
    }

    // MARK: - Mesh Statistics

    /// Estimates the file size (bytes) of an STL export.
    ///
    /// STL binary format: 80 byte header + 4 byte count + 50 bytes/triangle.
    ///
    /// - Parameter triangleCount: Number of triangles.
    /// - Returns: Estimated file size in bytes.
    public static func estimatedSTLFileSize(triangleCount: Int) -> Int {
        80 + 4 + triangleCount * 50
    }

    /// Estimates the file size (bytes) of an OBJ export.
    ///
    /// Approximate: ~30 bytes/vertex + ~20 bytes/face.
    ///
    /// - Parameters:
    ///   - vertexCount: Number of vertices.
    ///   - triangleCount: Number of triangles.
    /// - Returns: Estimated file size in bytes.
    public static func estimatedOBJFileSize(vertexCount: Int, triangleCount: Int) -> Int {
        100 + vertexCount * 30 + triangleCount * 20
    }

    /// Formats a file size as a human-readable string.
    ///
    /// - Parameter bytes: File size in bytes.
    /// - Returns: Formatted string (e.g., "1.5 MB").
    public static func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    /// Formats mesh statistics as a summary string.
    ///
    /// - Parameter stats: The mesh statistics.
    /// - Returns: Human-readable summary.
    public static func formatMeshSummary(_ stats: MeshStatistics) -> String {
        let vertices = formatCount(stats.vertexCount) + " vertices"
        let triangles = formatCount(stats.triangleCount) + " triangles"
        return "\(vertices), \(triangles)"
    }

    /// Formats a count with thousands separators.
    ///
    /// - Parameter count: The count to format.
    /// - Returns: Formatted count string.
    public static func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    // MARK: - Surface Color Presets

    /// Standard color presets for surface rendering.
    public static let colorPresets: [(label: String, red: Double, green: Double, blue: Double)] = [
        ("White", 1.0, 1.0, 1.0),
        ("Bone", 0.95, 0.9, 0.75),
        ("Skin", 1.0, 0.8, 0.7),
        ("Red", 0.9, 0.2, 0.2),
        ("Blue", 0.2, 0.4, 0.9),
        ("Green", 0.2, 0.8, 0.3),
    ]

    // MARK: - Multi-Surface Validation

    /// Validates a collection of surface configurations.
    ///
    /// - Parameter surfaces: Array of surface configurations.
    /// - Returns: Array of validation warning messages.
    public static func validateSurfaces(_ surfaces: [SurfaceConfiguration]) -> [String] {
        var warnings: [String] = []

        if surfaces.isEmpty {
            warnings.append("No surfaces configured")
        }

        // Check for duplicate thresholds
        let thresholds = surfaces.map(\.threshold)
        let uniqueThresholds = Set(thresholds)
        if thresholds.count != uniqueThresholds.count {
            warnings.append("Multiple surfaces share the same threshold")
        }

        // Check for invalid thresholds
        for surface in surfaces where !isValidThreshold(surface.threshold) {
            warnings.append("Surface '\(surface.label)' has threshold outside valid HU range")
        }

        return warnings
    }
}
