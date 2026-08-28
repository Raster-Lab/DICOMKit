// PatientIdentificationOverlayView.swift
// DICOMStudio
//
// DICOM Studio — patient identification under a film cell.
//
// Two lines, centred: "name, ID, study date" over the study description, in a
// reserved strip below the picture so text and anatomy never share pixels. The
// type scales with the cell it sits in, so a 4×5 film sheet carries the same
// strip as a single-image film without either drowning the picture or becoming
// unreadable.
//
// Film only. The viewer annotates in the corners instead
// (``ViewerAnnotationOverlayView``): on screen the reader can move the picture
// out from under the text, and paper cannot — a name printed over anatomy is a
// name that can hide a finding on the one copy that leaves the department.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct PatientIdentificationOverlayView: View {

    /// "Patient name, ID, study date".
    let primaryLine: String

    /// Study description.
    let secondaryLine: String

    /// Size of the cell the overlay is drawn in — the type scales against it.
    let cellSize: CGSize

    var body: some View {
        if primaryLine.isEmpty && secondaryLine.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: fontSize * 0.25) {
                if !primaryLine.isEmpty {
                    Text(primaryLine)
                        .font(.system(size: fontSize, weight: .semibold))
                }
                if !secondaryLine.isEmpty {
                    Text(secondaryLine)
                        .font(.system(size: fontSize))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(1)
            // A long name must shrink rather than truncate: the point of the
            // overlay is that the identification is legible in full.
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 1.5)
            .padding(.horizontal, fontSize * 0.5)
            .padding(.vertical, fontSize * 0.3)
            .frame(maxWidth: .infinity)
            .frame(height: Self.bandHeight(for: cellSize, lines: lineCount))
            .background(Color.black)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Patient identification: \(primaryLine). \(secondaryLine)")
        }
    }

    /// Type size derived from the band the text has to live in.
    private var fontSize: CGFloat { Self.fontSize(for: cellSize, lines: lineCount) }

    private var lineCount: Int {
        (primaryLine.isEmpty ? 0 : 1) + (secondaryLine.isEmpty ? 0 : 1)
    }

    /// Height of the band reserved under the image for this overlay.
    ///
    /// The band is sized first and the type is fitted into it — not the other way
    /// round. Deriving the band from the type let a large image reserve a strip
    /// deep enough to notice; a caption's job is to be read, not to take height
    /// from the picture, so the strip is a small, bounded fraction of the cell.
    ///
    /// The text sits below the picture rather than on it: identification drawn
    /// over the anatomy is exactly where a finding can hide.
    static func bandHeight(for cellSize: CGSize, lines: Int = 2) -> CGFloat {
        guard lines > 0 else { return 0 }
        let full = min(max(cellSize.height * bandFraction, minimumBandHeight), maximumBandHeight)
        guard lines == 1 else { return full }
        // One line needs roughly half the box two do, padding aside.
        return full * 0.62
    }

    /// Type size that fits `lines` lines inside the band for this cell.
    ///
    /// Both axes still matter: the band bounds the height, and the cell's width
    /// bounds how much text fits on a line before `minimumScaleFactor` starts
    /// shrinking it anyway. The smaller of the two wins.
    static func fontSize(for cellSize: CGSize, lines: Int = 2) -> CGFloat {
        let lines = max(1, lines)
        let band = bandHeight(for: cellSize, lines: lines)
        // Line boxes, the gaps between them, and the band's own padding, all
        // expressed in multiples of the type size — invert to get the size.
        let boxesPerSize = CGFloat(lines) * lineHeightFactor
            + CGFloat(lines - 1) * lineGapFactor
            + verticalPaddingFactor
        let byBand = band / boxesPerSize
        let byWidth = cellSize.width * widthFraction
        let fitted = byWidth > 0 ? min(byBand, byWidth) : byBand
        return min(max(fitted, minimumSize), maximumSize)
    }

    /// Fraction of the cell's height a two-line band occupies.
    private static let bandFraction: CGFloat = 0.09
    /// Deep enough to hold two lines at the smallest legible type — a floor
    /// below that would clip the text it exists to protect.
    private static let minimumBandHeight: CGFloat = 20
    private static let maximumBandHeight: CGFloat = 40

    // Must match the VStack above: line box, inter-line spacing, vertical padding.
    private static let lineHeightFactor: CGFloat = 1.2
    private static let lineGapFactor: CGFloat = 0.25
    private static let verticalPaddingFactor: CGFloat = 0.6

    private static let widthFraction: CGFloat = 0.024
    private static let minimumSize: CGFloat = 6
    private static let maximumSize: CGFloat = 13
}
#endif
