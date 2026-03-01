// WindowLevelPresets.swift
// DICOMStudio
//
// DICOM Studio — Window/level preset definitions for common modalities

import Foundation

/// A single window/level preset with descriptive metadata.
public struct WindowLevelPreset: Sendable, Equatable, Identifiable, Hashable {
    /// Unique identifier.
    public var id: String { name }

    /// Display name for the preset (e.g., "Bone", "Lung").
    public let name: String

    /// Window center (level) value.
    public let center: Double

    /// Window width value.
    public let width: Double

    /// Modality this preset is intended for (e.g., "CT", "MR").
    public let modality: String

    /// Creates a new preset.
    public init(name: String, center: Double, width: Double, modality: String) {
        self.name = name
        self.center = center
        self.width = width
        self.modality = modality
    }
}

/// Platform-independent window/level preset definitions for common DICOM modalities.
///
/// Provides standard presets for CT, MR, and other modalities per DICOM PS3.3 C.11.2.1.2.
public enum WindowLevelPresets: Sendable {

    // MARK: - CT Presets

    /// Standard CT presets for various tissue types.
    public static let ctPresets: [WindowLevelPreset] = [
        WindowLevelPreset(name: "Abdomen", center: 40, width: 400, modality: "CT"),
        WindowLevelPreset(name: "Bone", center: 300, width: 1500, modality: "CT"),
        WindowLevelPreset(name: "Brain", center: 40, width: 80, modality: "CT"),
        WindowLevelPreset(name: "Chest", center: 40, width: 400, modality: "CT"),
        WindowLevelPreset(name: "Lung", center: -600, width: 1500, modality: "CT"),
        WindowLevelPreset(name: "Liver", center: 60, width: 150, modality: "CT"),
        WindowLevelPreset(name: "Mediastinum", center: 50, width: 350, modality: "CT"),
        WindowLevelPreset(name: "Stroke", center: 40, width: 40, modality: "CT"),
    ]

    // MARK: - MR Presets

    /// Standard MR presets for common sequence types.
    public static let mrPresets: [WindowLevelPreset] = [
        WindowLevelPreset(name: "T1", center: 500, width: 1000, modality: "MR"),
        WindowLevelPreset(name: "T2", center: 400, width: 800, modality: "MR"),
        WindowLevelPreset(name: "FLAIR", center: 600, width: 1200, modality: "MR"),
    ]

    // MARK: - Lookup

    /// Returns the preset list for the given modality.
    ///
    /// - Parameter modality: DICOM modality code (e.g., "CT", "MR").
    /// - Returns: Array of presets, empty if no presets are defined for the modality.
    public static func presets(for modality: String) -> [WindowLevelPreset] {
        switch modality.uppercased() {
        case "CT":
            return ctPresets
        case "MR", "MRI":
            return mrPresets
        default:
            return []
        }
    }

    /// Returns all available presets across all modalities.
    public static var allPresets: [WindowLevelPreset] {
        ctPresets + mrPresets
    }

    /// Finds a preset by name and modality.
    ///
    /// - Parameters:
    ///   - name: Preset name (case-insensitive).
    ///   - modality: DICOM modality code.
    /// - Returns: The matching preset, or nil.
    public static func preset(named name: String, modality: String) -> WindowLevelPreset? {
        presets(for: modality).first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Returns a default preset for the given modality (the first in the list).
    ///
    /// - Parameter modality: DICOM modality code.
    /// - Returns: The first preset for that modality, or nil.
    public static func defaultPreset(for modality: String) -> WindowLevelPreset? {
        presets(for: modality).first
    }
}
