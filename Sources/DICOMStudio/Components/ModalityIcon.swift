// ModalityIcon.swift
// DICOMStudio
//
// DICOM Studio — Modality-specific SF Symbol icons

import Foundation

/// Platform-independent DICOM modality mapping utilities.
///
/// Provides SF Symbol names and full modality names for DICOM modality codes
/// without requiring SwiftUI, and the canonical enumerable list of modalities
/// DICOM Studio recognizes (see ``allCodes``).
public enum ModalityMapping: Sendable {

    /// Canonical DICOM modality codes recognized by DICOM Studio, in display order.
    ///
    /// Each case is a primary DICOM modality code with a dedicated icon and
    /// human-readable name. Alias codes (e.g. "MRI", "PET", "RTPLAN", "PDF")
    /// normalize onto these primaries via ``ModalityMapping/normalize(_:)``.
    /// The set mirrors the DICOM object types DICOMKit models with dedicated
    /// tag modules (CT/MR/US/NM/PT, RT, SEG, PR, SR, waveform, video, document, …).
    public enum StandardModality: String, CaseIterable, Sendable {
        case ct = "CT"
        case mr = "MR"
        case us = "US"
        case cr = "CR"
        case dx = "DX"
        case nm = "NM"
        case pt = "PT"
        case mg = "MG"
        case rf = "RF"
        case xa = "XA"
        case sc = "SC"
        case ot = "OT"
        case sr = "SR"
        case pr = "PR"
        case ko = "KO"
        case seg = "SEG"
        case rt = "RT"
        case ecg = "ECG"
        case hd = "HD"
        case io = "IO"
        case op = "OP"
        case doc = "DOC"
        case vl = "VL"

        /// SF Symbol name for this modality.
        var systemImage: String {
            switch self {
            case .ct: return "cylinder.split.1x2"
            case .mr: return "brain.head.profile"
            case .us: return "waveform.path.ecg"
            case .cr, .dx: return "xray"
            case .nm: return "atom"
            case .pt: return "sparkles"
            case .mg: return "rectangle.compress.vertical"
            case .rf: return "film"
            case .xa: return "heart"
            case .sc: return "camera"
            case .ot: return "questionmark.square"
            case .sr: return "doc.text"
            case .pr: return "paintbrush"
            case .ko: return "key"
            case .seg: return "square.on.square.dashed"
            case .rt: return "target"
            case .ecg: return "waveform.path.ecg.rectangle"
            case .hd: return "waveform"
            case .io: return "mouth"
            case .op: return "eye"
            case .doc: return "doc.richtext"
            case .vl: return "video"
            }
        }

        /// Human-readable name for this modality.
        var fullName: String {
            switch self {
            case .ct: return "Computed Tomography"
            case .mr: return "Magnetic Resonance"
            case .us: return "Ultrasound"
            case .cr: return "Computed Radiography"
            case .dx: return "Digital Radiography"
            case .nm: return "Nuclear Medicine"
            case .pt: return "Positron Emission Tomography"
            case .mg: return "Mammography"
            case .rf: return "Radiofluoroscopy"
            case .xa: return "X-Ray Angiography"
            case .sc: return "Secondary Capture"
            case .ot: return "Other"
            case .sr: return "Structured Report"
            case .pr: return "Presentation State"
            case .ko: return "Key Object"
            case .seg: return "Segmentation"
            case .rt: return "Radiation Therapy"
            case .ecg: return "Electrocardiography"
            case .hd: return "Hemodynamic Waveform"
            case .io: return "Intra-Oral Radiography"
            case .op: return "Ophthalmic Photography"
            case .doc: return "Document"
            case .vl: return "Visible Light"
            }
        }
    }

    /// All canonical modality codes recognized by DICOM Studio, in display order.
    ///
    /// Use this as the single source of truth wherever the app offers a fixed
    /// choice of modalities (e.g. CLI Workshop dropdowns).
    public static var allCodes: [String] { StandardModality.allCases.map(\.rawValue) }

    /// Normalizes a raw DICOM modality code — including common aliases — to a
    /// canonical ``StandardModality``, or `nil` if unrecognized.
    static func normalize(_ modality: String) -> StandardModality? {
        switch modality.uppercased() {
        case "MRI": return .mr
        case "PET": return .pt
        case "RTPLAN", "RTDOSE", "RTSTRUCT": return .rt
        case "PDF": return .doc
        default: return StandardModality(rawValue: modality.uppercased())
        }
    }

    /// Maps DICOM modality codes to appropriate SF Symbol names.
    ///
    /// - Parameter modality: DICOM modality code (e.g. "CT", "MR").
    /// - Returns: SF Symbol name for the modality.
    public static func systemImage(for modality: String) -> String {
        normalize(modality)?.systemImage ?? "square.grid.2x2"
    }

    /// Returns the full human-readable name for a DICOM modality code.
    ///
    /// - Parameter modality: DICOM modality code (e.g. "CT", "MR").
    /// - Returns: Human-readable modality name.
    public static func fullName(for modality: String) -> String {
        normalize(modality)?.fullName ?? modality.uppercased()
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// Displays an SF Symbol icon appropriate for a DICOM modality.
///
/// Usage:
/// ```swift
/// ModalityIcon(modality: "CT")
/// ModalityIcon(modality: "MR", size: 24)
/// ```
@available(macOS 14.0, iOS 17.0, *)
public struct ModalityIcon: View {
    let modality: String
    let size: CGFloat

    public init(modality: String, size: CGFloat = 16) {
        self.modality = modality.uppercased()
        self.size = size
    }

    public var body: some View {
        Image(systemName: ModalityMapping.systemImage(for: modality))
            .font(.system(size: size))
            .foregroundStyle(StudioColors.color(for: modality))
            .accessibilityLabel("\(ModalityMapping.fullName(for: modality)) modality")
    }
}
#endif
