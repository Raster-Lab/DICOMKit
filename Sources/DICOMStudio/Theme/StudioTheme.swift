// StudioTheme.swift
// DICOMStudio
//
// DICOM Studio — Theming and appearance definitions

#if canImport(SwiftUI)
import SwiftUI
#endif

import Foundation

/// Medical imaging color palette for radiology-appropriate theming.
///
/// Colors are defined as platform-independent values; SwiftUI `Color`
/// extensions are conditionally available on Apple platforms.
public enum StudioColors: Sendable {
    // MARK: - Primary Palette

    /// Teal blue used for primary actions and navigation highlights.
    public static let primaryRed: Double = 0.22
    public static let primaryGreen: Double = 0.60
    public static let primaryBlue: Double = 0.78

    /// Deep navy for backgrounds in radiology mode.
    public static let backgroundRed: Double = 0.06
    public static let backgroundGreen: Double = 0.07
    public static let backgroundBlue: Double = 0.10

    /// Soft white for text on dark backgrounds.
    public static let textOnDarkRed: Double = 0.92
    public static let textOnDarkGreen: Double = 0.93
    public static let textOnDarkBlue: Double = 0.94

    // MARK: - Status Colors

    /// Green for success/connected status.
    public static let successRed: Double = 0.30
    public static let successGreen: Double = 0.75
    public static let successBlue: Double = 0.40

    /// Amber for warnings.
    public static let warningRed: Double = 0.95
    public static let warningGreen: Double = 0.75
    public static let warningBlue: Double = 0.20

    /// Red for errors.
    public static let errorRed: Double = 0.90
    public static let errorGreen: Double = 0.25
    public static let errorBlue: Double = 0.25

    // MARK: - Modality Colors

    /// Color for CT modality.
    public static let ctRed: Double = 0.25
    public static let ctGreen: Double = 0.55
    public static let ctBlue: Double = 0.85

    /// Color for MR modality.
    public static let mrRed: Double = 0.50
    public static let mrGreen: Double = 0.35
    public static let mrBlue: Double = 0.80

    /// Color for US modality.
    public static let usRed: Double = 0.30
    public static let usGreen: Double = 0.70
    public static let usBlue: Double = 0.50

    /// Color for XR/DX modality.
    public static let xrRed: Double = 0.75
    public static let xrGreen: Double = 0.60
    public static let xrBlue: Double = 0.30

    /// Returns RGB tuple for a given modality string.
    public static func modalityColor(for modality: String) -> (red: Double, green: Double, blue: Double) {
        switch modality.uppercased() {
        case "CT": return (ctRed, ctGreen, ctBlue)
        case "MR", "MRI": return (mrRed, mrGreen, mrBlue)
        case "US": return (usRed, usGreen, usBlue)
        case "CR", "DX", "XR": return (xrRed, xrGreen, xrBlue)
        default: return (primaryRed, primaryGreen, primaryBlue)
        }
    }
}

#if canImport(SwiftUI)
extension StudioColors {
    /// Primary accent color.
    public static var primary: Color {
        Color(red: primaryRed, green: primaryGreen, blue: primaryBlue)
    }

    /// Radiology-mode background color.
    public static var radiologyBackground: Color {
        Color(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue)
    }

    /// Text color for dark backgrounds.
    public static var textOnDark: Color {
        Color(red: textOnDarkRed, green: textOnDarkGreen, blue: textOnDarkBlue)
    }

    /// Success/connected indicator color.
    public static var success: Color {
        Color(red: successRed, green: successGreen, blue: successBlue)
    }

    /// Warning indicator color.
    public static var warning: Color {
        Color(red: warningRed, green: warningGreen, blue: warningBlue)
    }

    /// Error indicator color.
    public static var error: Color {
        Color(red: errorRed, green: errorGreen, blue: errorBlue)
    }

    /// Returns a SwiftUI Color for a given modality.
    public static func color(for modality: String) -> Color {
        let rgb = modalityColor(for: modality)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
#endif

/// Typography scale constants following Dynamic Type sizing.
public enum StudioTypography: Sendable {
    /// Display title size.
    public static let displaySize: CGFloat = 28

    /// Section header size.
    public static let headerSize: CGFloat = 20

    /// Body text size.
    public static let bodySize: CGFloat = 14

    /// Caption / detail size.
    public static let captionSize: CGFloat = 11

    /// Monospaced size for tags and UIDs.
    public static let monoSize: CGFloat = 12
}
