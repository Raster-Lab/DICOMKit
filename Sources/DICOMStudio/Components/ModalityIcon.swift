// ModalityIcon.swift
// DICOMStudio
//
// DICOM Studio — Modality-specific SF Symbol icons

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
        Image(systemName: systemImageName)
            .font(.system(size: size))
            .foregroundStyle(StudioColors.color(for: modality))
            .accessibilityLabel("\(modalityFullName) modality")
    }

    /// Maps DICOM modality codes to appropriate SF Symbols.
    public static func systemImage(for modality: String) -> String {
        switch modality.uppercased() {
        case "CT": return "cylinder.split.1x2"
        case "MR", "MRI": return "brain.head.profile"
        case "US": return "waveform.path.ecg"
        case "CR", "DX": return "xray"
        case "NM": return "atom"
        case "PT", "PET": return "sparkles"
        case "MG": return "rectangle.compress.vertical"
        case "RF": return "film"
        case "XA": return "heart"
        case "SC": return "camera"
        case "OT": return "questionmark.square"
        case "SR": return "doc.text"
        case "PR": return "paintbrush"
        case "KO": return "key"
        case "SEG": return "square.on.square.dashed"
        case "RT", "RTPLAN", "RTDOSE", "RTSTRUCT": return "target"
        case "ECG": return "waveform.path.ecg.rectangle"
        case "HD": return "waveform"
        case "IO": return "mouth"
        case "OP": return "eye"
        case "DOC", "PDF": return "doc.richtext"
        case "VL": return "video"
        default: return "square.grid.2x2"
        }
    }

    private var systemImageName: String {
        Self.systemImage(for: modality)
    }

    private var modalityFullName: String {
        switch modality {
        case "CT": return "Computed Tomography"
        case "MR", "MRI": return "Magnetic Resonance"
        case "US": return "Ultrasound"
        case "CR": return "Computed Radiography"
        case "DX": return "Digital Radiography"
        case "NM": return "Nuclear Medicine"
        case "PT", "PET": return "Positron Emission Tomography"
        case "MG": return "Mammography"
        case "RF": return "Radiofluoroscopy"
        case "XA": return "X-Ray Angiography"
        case "SC": return "Secondary Capture"
        case "OT": return "Other"
        case "SR": return "Structured Report"
        case "PR": return "Presentation State"
        case "KO": return "Key Object"
        case "SEG": return "Segmentation"
        case "RT": return "Radiation Therapy"
        case "ECG": return "Electrocardiography"
        default: return modality
        }
    }
}
#endif
