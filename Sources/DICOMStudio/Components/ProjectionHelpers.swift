// ProjectionHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent intensity projection helpers

import Foundation

/// Platform-independent helpers for intensity projection computations.
///
/// Provides parameter validation, slab range calculations, and display
/// formatting for MIP, MinIP, and Average projections.
public enum ProjectionHelpers: Sendable {

    // MARK: - Projection Labels

    /// Returns a user-facing label for a projection mode.
    ///
    /// - Parameter mode: The projection mode.
    /// - Returns: Display label.
    public static func projectionLabel(_ mode: ProjectionMode) -> String {
        switch mode {
        case .mip: return "Maximum Intensity Projection"
        case .minIP: return "Minimum Intensity Projection"
        case .avgIP: return "Average Intensity Projection"
        }
    }

    /// Returns a short abbreviation for a projection mode.
    ///
    /// - Parameter mode: The projection mode.
    /// - Returns: Short label.
    public static func projectionAbbreviation(_ mode: ProjectionMode) -> String {
        switch mode {
        case .mip: return "MIP"
        case .minIP: return "MinIP"
        case .avgIP: return "AvgIP"
        }
    }

    /// Returns an SF Symbol name for a projection mode.
    ///
    /// - Parameter mode: The projection mode.
    /// - Returns: SF Symbol name.
    public static func projectionSymbol(_ mode: ProjectionMode) -> String {
        switch mode {
        case .mip: return "arrow.up.to.line"
        case .minIP: return "arrow.down.to.line"
        case .avgIP: return "equal.square"
        }
    }

    /// Returns a description of the clinical use of a projection mode.
    ///
    /// - Parameter mode: The projection mode.
    /// - Returns: Clinical use description.
    public static func clinicalUse(_ mode: ProjectionMode) -> String {
        switch mode {
        case .mip: return "CT angiography, bone visualization, bright structure detection"
        case .minIP: return "Airway visualization, low-density structure detection"
        case .avgIP: return "Noise reduction, subtle finding detection"
        }
    }

    // MARK: - Slab Validation

    /// Validates and clamps slab thickness to a valid range.
    ///
    /// - Parameters:
    ///   - thickness: Requested slab thickness in mm.
    ///   - maxThickness: Maximum allowed thickness in mm.
    /// - Returns: Clamped slab thickness (≥ 0.1 mm).
    public static func clampSlabThickness(
        _ thickness: Double,
        maxThickness: Double
    ) -> Double {
        max(0.1, min(thickness, max(0.1, maxThickness)))
    }

    /// Computes the number of slices included in a slab.
    ///
    /// - Parameters:
    ///   - thicknessMM: Slab thickness in mm.
    ///   - sliceSpacing: Spacing between slices in mm.
    /// - Returns: Number of slices in the slab.
    public static func sliceCountForSlab(
        thicknessMM: Double,
        sliceSpacing: Double
    ) -> Int {
        guard sliceSpacing > 0 else { return 1 }
        return max(1, Int(ceil(thicknessMM / sliceSpacing)))
    }

    /// Computes the maximum slab thickness for a given direction.
    ///
    /// - Parameters:
    ///   - direction: Projection direction.
    ///   - dimensions: Volume dimensions.
    /// - Returns: Maximum slab thickness in mm.
    public static func maximumSlabThickness(
        direction: MPRPlane,
        dimensions: VolumeDimensionsModel
    ) -> Double {
        switch direction {
        case .axial: return Double(dimensions.depth) * dimensions.spacingZ
        case .sagittal: return Double(dimensions.width) * dimensions.spacingX
        case .coronal: return Double(dimensions.height) * dimensions.spacingY
        }
    }

    // MARK: - Projection Result Formatting

    /// Formats projection parameters as a summary string.
    ///
    /// - Parameter config: The projection configuration.
    /// - Returns: Human-readable summary.
    public static func formatProjectionSummary(
        _ config: ProjectionConfiguration
    ) -> String {
        var parts: [String] = [projectionAbbreviation(config.mode)]
        parts.append(MPRHelpers.planeLabel(config.direction))
        if let thickness = config.slabThickness {
            parts.append(String(format: "%.1f mm slab", thickness))
        } else {
            parts.append("full volume")
        }
        return parts.joined(separator: " — ")
    }

    // MARK: - Value Aggregation

    /// Applies a projection operation to an array of values.
    ///
    /// - Parameters:
    ///   - mode: The projection mode.
    ///   - values: Array of voxel intensity values.
    /// - Returns: Projected value.
    public static func projectValues(
        mode: ProjectionMode,
        values: [Double]
    ) -> Double {
        guard !values.isEmpty else { return 0.0 }
        switch mode {
        case .mip:
            return values.max() ?? 0.0
        case .minIP:
            return values.min() ?? 0.0
        case .avgIP:
            return values.reduce(0.0, +) / Double(values.count)
        }
    }
}
