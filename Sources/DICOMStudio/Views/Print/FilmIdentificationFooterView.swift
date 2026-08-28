// FilmIdentificationFooterView.swift
// DICOMStudio
//
// DICOM Studio — the one caption a film of a single study carries.
//
// The sheet's counterpart to ``PatientIdentificationOverlayView``: where that
// names the patient under each picture, this names them once along the bottom of
// the film, in the strip ``FilmCellLayout`` kept clear of cells. Which of the two
// a film uses is ``FilmIdentificationPlanner``'s decision, not this view's.
//
// Sized in millimetres of real film rather than in points of preview, so a
// half-size preview shows a half-size footer: the reader is judging what the
// sheet will look like, and a caption drawn at screen sizes would read as far
// larger on the film than it is.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmIdentificationFooterView: View {

    /// The caption lines, in order — the same lines the composer draws.
    let lines: [String]

    /// The height the sheet is drawn at on screen.
    let sheetHeight: CGFloat

    /// The height of the physical sheet, for the millimetre → point scale.
    let sheetHeightMillimeters: CGFloat

    var body: some View {
        if lines.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: fontSize * CGFloat(FilmIdentificationFooter.lineFactor - 1)) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: fontSize, weight: index == 0 ? .semibold : .regular))
                        .foregroundStyle(index == 0 ? .white : .white.opacity(0.85))
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(1)
            // A long name shrinks rather than truncates: a half-printed patient
            // name identifies nobody.
            .minimumScaleFactor(0.5)
            .padding(.horizontal, fontSize)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Film identification: \(lines.joined(separator: ". "))")
        }
    }

    /// The composer's type size, in the preview's points.
    ///
    /// Off the physical sheet, exactly as the composer sets it: a 14×17 film
    /// carries larger type than an 8×10, and the preview has to show that.
    private var fontSize: CGFloat {
        guard sheetHeightMillimeters > 0, sheetHeight > 0 else { return 9 }
        let millimeters = FilmIdentificationFooter.fontMillimeters(
            sheetHeightMillimeters: Double(sheetHeightMillimeters))
        let scaled = CGFloat(millimeters) * (sheetHeight / sheetHeightMillimeters)
        // Legible even on a preview squeezed into a narrow panel — below this
        // the strip stops being readable and stops being worth its height.
        return max(6, scaled)
    }
}
#endif
