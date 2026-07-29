// PrintOptionCatalog.swift
// DICOMPrintKit
//
// The single source of truth for the selectable values of every print option:
// the layouts, presets, film sizes, and enumerations both the dicom-print CLI
// and the DICOMStudio print UI offer. UI pickers derive from these tables so a
// value can never exist in one surface and not the other.

import Foundation
import DICOMNetwork

// MARK: - Layout

/// A selectable rows × columns film layout.
public enum PrintLayoutOption: String, CaseIterable, Sendable, Identifiable {
    case layout1x1 = "1x1"
    case layout1x2 = "1x2"
    case layout2x1 = "2x1"
    case layout2x2 = "2x2"
    case layout2x3 = "2x3"
    case layout3x3 = "3x3"
    case layout3x4 = "3x4"
    case layout4x4 = "4x4"
    case layout4x5 = "4x5"

    public var id: String { rawValue }

    /// Rows and columns for this layout.
    public var layout: PrintLayout {
        switch self {
        case .layout1x1: return PrintLayout(rows: 1, columns: 1)
        case .layout1x2: return PrintLayout(rows: 1, columns: 2)
        case .layout2x1: return PrintLayout(rows: 2, columns: 1)
        case .layout2x2: return PrintLayout(rows: 2, columns: 2)
        case .layout2x3: return PrintLayout(rows: 2, columns: 3)
        case .layout3x3: return PrintLayout(rows: 3, columns: 3)
        case .layout3x4: return PrintLayout(rows: 3, columns: 4)
        case .layout4x4: return PrintLayout(rows: 4, columns: 4)
        case .layout4x5: return PrintLayout(rows: 4, columns: 5)
    }
    }

    /// The Image Display Format (2010,0010) string this layout sends.
    public var imageDisplayFormat: String { layout.imageDisplayFormat }

    /// Cells on one film.
    public var cellCount: Int { layout.rows * layout.columns }

    /// Label for menus: "2×2 (4 images)".
    public var displayName: String {
        "\(layout.rows)×\(layout.columns) (\(cellCount) image\(cellCount == 1 ? "" : "s"))"
    }
}

// MARK: - Template presets

/// A layout preset that also fixes film size and orientation.
public enum PrintTemplatePreset: String, CaseIterable, Sendable, Identifiable {
    case single
    case comparison
    case grid
    case multiPhase = "multi-phase"

    public var id: String { rawValue }

    /// The built-in `PrintTemplate` this preset maps to.
    public var template: PrintTemplate {
        switch self {
        case .single:     return SingleImageTemplate()
        case .comparison: return ComparisonTemplate()
        case .grid:       return GridTemplate(rows: 2, columns: 2)
        case .multiPhase: return MultiPhaseTemplate(rows: 2, columns: 3)
        }
    }

    /// The image layout (rows × columns) for this preset.
    public var layout: PrintLayout {
        switch self {
        case .single:     return PrintLayout(rows: 1, columns: 1)
        case .comparison: return PrintLayout(rows: 1, columns: 2)
        case .grid:       return PrintLayout(rows: 2, columns: 2)
        case .multiPhase: return PrintLayout(rows: 2, columns: 3)
        }
    }

    /// The film size this preset fixes.
    public var filmSize: FilmSize { template.filmSize }

    /// The orientation this preset fixes.
    public var filmOrientation: FilmOrientation { template.filmOrientation }

    /// Label for menus.
    public var displayName: String {
        switch self {
        case .single:     return "Single image"
        case .comparison: return "Comparison (1×2)"
        case .grid:       return "Grid (2×2)"
        case .multiPhase: return "Multi-phase (2×3)"
        }
    }
}

// MARK: - Catalog

/// Selectable values, with labels, for every print option.
public enum PrintOptionCatalog {

    /// Film sizes offered, in the CLI's `--film-size` order.
    public static let filmSizes: [(value: FilmSize, cliToken: String, label: String)] = [
        (.size8InX10In,   "8x10",    "8 × 10 in"),
        (.size8_5InX11In, "8.5x11",  "8.5 × 11 in"),
        (.size10InX12In,  "10x12",   "10 × 12 in"),
        (.size10InX14In,  "10x14",   "10 × 14 in"),
        (.size11InX14In,  "11x14",   "11 × 14 in"),
        (.size11InX17In,  "11x17",   "11 × 17 in"),
        (.size14InX14In,  "14x14",   "14 × 14 in"),
        (.size14InX17In,  "14x17",   "14 × 17 in"),
        (.size24CmX24Cm,  "24x24cm", "24 × 24 cm"),
        (.size24CmX30Cm,  "24x30cm", "24 × 30 cm"),
        (.a4,             "a4",      "A4"),
        (.a3,             "a3",      "A3")
    ]

    /// Film orientations.
    public static let orientations: [(value: FilmOrientation, cliToken: String, label: String)] = [
        (.portrait,  "portrait",  "Portrait"),
        (.landscape, "landscape", "Landscape")
    ]

    /// Print priorities.
    public static let priorities: [(value: PrintPriority, cliToken: String, label: String)] = [
        (.low,    "low",    "Low"),
        (.medium, "medium", "Medium"),
        (.high,   "high",   "High")
    ]

    /// Medium types.
    public static let mediumTypes: [(value: MediumType, cliToken: String, label: String)] = [
        (.paper,     "paper",      "Paper"),
        (.clearFilm, "clear-film", "Clear film"),
        (.blueFilm,  "blue-film",  "Blue film")
    ]

    /// Film destinations.
    public static let filmDestinations: [(value: FilmDestination, cliToken: String, label: String)] = [
        (.magazine,  "magazine",  "Magazine"),
        (.processor, "processor", "Processor"),
        (.bin1,      "bin-1",     "Bin 1"),
        (.bin2,      "bin-2",     "Bin 2")
    ]

    /// Magnification (interpolation) types.
    public static let magnificationTypes: [(value: MagnificationType, cliToken: String, label: String)] = [
        (.replicate,            "replicate", "Replicate"),
        (.bilinear,             "bilinear",  "Bilinear"),
        (.cubic,                "cubic",     "Cubic"),
        (MagnificationType.none, "none",     "None")
    ]

    /// Image polarities.
    public static let polarities: [(value: ImagePolarity, cliToken: String, label: String)] = [
        (.normal,  "normal",  "Normal"),
        (.reverse, "reverse", "Reverse")
    ]

    /// Trim options.
    public static let trimOptions: [(value: TrimOption, cliToken: String, label: String)] = [
        (TrimOption.no,  "no",  "No trim box"),
        (TrimOption.yes, "yes", "Trim box")
    ]

    /// Presentation LUT shapes (plus "none", represented by `nil`).
    public static let presentationLUTShapes: [(value: PresentationLUTShape, cliToken: String, label: String)] = [
        (.identity,               "identity", "Identity"),
        (.inverse,                "inverse",  "Inverse"),
        (.linearOpticalDensity,   "lin-od",   "Linear optical density")
    ]

    /// Color modes.
    public static let colorModes: [(value: DICOMNetwork.PrintColorMode, cliToken: String, label: String)] = [
        (.grayscale, "grayscale", "Grayscale"),
        (.color,     "color",     "Color")
    ]

    /// Grayscale output bit depths.
    public static let bitDepths: [Int] = [8, 12, 16]

    /// Border / empty-image density values.
    public static let densities: [String] = ["BLACK", "WHITE"]

    // MARK: Token lookup

    /// Resolves a CLI film-size token ("14x17") to its `FilmSize`.
    public static func filmSize(forToken token: String) -> FilmSize? {
        filmSizes.first { $0.cliToken == token }?.value
    }

    /// The CLI token for a film size, for round-tripping UI state to a command line.
    public static func token(for filmSize: FilmSize) -> String? {
        filmSizes.first { $0.value == filmSize }?.cliToken
    }

    /// Human label for a film size.
    public static func label(for filmSize: FilmSize) -> String {
        filmSizes.first { $0.value == filmSize }?.label ?? filmSize.rawValue
    }
}
