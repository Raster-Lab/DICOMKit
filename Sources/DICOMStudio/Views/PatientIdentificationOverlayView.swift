// PatientIdentificationOverlayView.swift
// DICOMStudio
//
// DICOM Studio — patient identification in the corners of a film cell.
//
// The arrangement a reading station has used for decades, and the one
// ``ViewerAnnotationOverlayView`` draws on screen: who and what at the top
// right, what made the picture at the bottom left, when it was taken at the
// bottom right. The corners of a fitted image are background, the reader's eye
// is in the middle, and a caption in a strip below the picture is a caption read
// by looking away from the anatomy it describes.
//
// Held to the corners of the *cell*, so the text reads off the edges of the film
// rather than floating against the letterbox margin of a picture that does not
// happen to be the cell's shape. ``ImageAnnotationBurner`` burns the same four
// blocks into the printed pixels; on the wire the image box is all there is to
// draw into, so on a letterboxed cell the film's text sits at the picture's edge
// rather than the cell's. The type scales with the cell, so a 4×5 sheet carries
// the same block as a single-image film without either drowning the picture or
// becoming unreadable.

#if canImport(SwiftUI)
import SwiftUI
import CoreText
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct PatientIdentificationOverlayView: View {

    /// What each corner says. Blank lines are already dropped — see
    /// ``PatientOverlayText/corners``.
    let corners: PrintCornerAnnotation

    /// The cell this is drawn in — the corners the text is pushed into.
    ///
    /// The cell rather than the picture inside it: a frame fitted into a cell of
    /// a different shape leaves a letterbox margin, and text held to the picture
    /// floats in the middle of the cell with black either side of it. The reader
    /// looks at the corner of the *cell* for the corner text, which is where the
    /// eye goes on a light box.
    let cellSize: CGSize

    var body: some View {
        if corners.isEmpty {
            EmptyView()
        } else {
            ZStack {
                block(corners.topLeft, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                block(corners.topRight, alignment: .trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                block(corners.bottomLeft, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                block(corners.bottomRight, alignment: .trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            // Plain, at one weight: nothing in the corners is a different kind of
            // statement from anything else there, and bold type on film reads as
            // emphasis nobody meant.
            .font(.system(size: fontSize))
            .foregroundStyle(.white)
            // The picture underneath is arbitrary: a halo is what keeps a line
            // readable over bone as well as over air, without a panel behind it
            // that would hide the anatomy the corner stands on. The burner draws
            // the same halo into the pixels.
            .shadow(color: .black.opacity(0.9), radius: 1.4)
            .padding(padding)
            .frame(width: cellSize.width, height: cellSize.height)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Patient identification: \(corners.allLines.joined(separator: ". "))")
        }
    }

    private func block(_ lines: [String], alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: fontSize * 0.22) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        // Half the cell apiece, so the two blocks along an edge cannot run into
        // each other and leave a name overprinted by a technique.
        .frame(maxWidth: max(0, cellSize.width * 0.48),
               alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Metrics

    /// The one size every line in this cell is set at.
    ///
    /// Derived from the cell, then shrunk — as a block — until the widest line
    /// fits its corner. It used to be per-line `minimumScaleFactor`, which
    /// shrank only the lines that needed it: the patient's name at full size
    /// over a study description at half size read as two kinds of statement,
    /// and the burner (which draws every line at one size) disagreed with the
    /// preview. One size, fitted to the longest line, keeps the corners a
    /// single block of type on screen and on film alike.
    private var fontSize: CGFloat {
        Self.fittedFontSize(for: corners, cellSize: cellSize)
    }

    /// Inset from the cell's edge — enough that the text does not sit on the
    /// border, scaled so a small cell does not lose room to margins.
    private var padding: CGFloat { max(2, fontSize * Self.marginFactor) }

    /// Type size for a cell of this size.
    ///
    /// Scaled to the cell's height, so a 4×5 tile carries a block in proportion
    /// to it rather than one sized for a full sheet, and bounded at both ends:
    /// below the floor nothing is readable at any distance, above the ceiling a
    /// caption starts competing with the anatomy.
    static func fontSize(for cellSize: CGSize) -> CGFloat {
        let byHeight = cellSize.height * heightFraction
        return min(max(byHeight, minimumSize), maximumSize)
    }

    /// The cell's type size, shrunk as one block until the widest line fits
    /// its corner — never below half, the floor the per-line shrink used to
    /// have, past which a line truncates rather than dragging every other
    /// line into illegibility with it.
    static func fittedFontSize(
        for corners: PrintCornerAnnotation, cellSize: CGSize
    ) -> CGFloat {
        let base = fontSize(for: cellSize)
        let available = cellSize.width * 0.48
        guard available > 0 else { return base }
        let widest = corners.allLines
            .map { width(of: $0, fontSize: base) }
            .max() ?? 0
        guard widest > available else { return base }
        return base * max(0.5, available / widest)
    }

    /// One line's set width at a size.
    ///
    /// Measured in Helvetica — the film's face — rather than the view's system
    /// font: the two set within a few percent of each other, and one
    /// measurement shared with the burner means preview and film step the
    /// block down at the same line.
    private static func width(of line: String, fontSize: CGFloat) -> CGFloat {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        guard let attributed = CFAttributedStringCreate(
            nil, line as CFString, attributes as CFDictionary) else { return 0 }
        let ctLine = CTLineCreateWithAttributedString(attributed)
        return CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
    }

    /// The room a corner block of this many lines takes in a cell of this size —
    /// what tells a caller whether the corners are about to collide.
    static func blockHeight(for cellSize: CGSize, lines: Int) -> CGFloat {
        guard lines > 0 else { return 0 }
        let size = fontSize(for: cellSize)
        return size * (marginFactor + CGFloat(lines) * lineHeightFactor)
    }

    /// Type size as a fraction of the cell's height. A notch under the viewer's
    /// own 0.026: film cells sit four and sixteen to a sheet, and the corners
    /// carry more lines than a viewport's do, so the block has to stay out of the
    /// picture's way at sizes a viewport never reaches.
    private static let heightFraction: CGFloat = 0.023

    /// Must match the layout above: the inset off the edge, and one line box
    /// (type plus its gap) per line.
    static let marginFactor: CGFloat = 0.6
    static let lineHeightFactor: CGFloat = 1.22

    private static let minimumSize: CGFloat = 5
    private static let maximumSize: CGFloat = 11
}
#endif
