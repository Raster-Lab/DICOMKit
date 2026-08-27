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
// draw into, so a fitted frame is first letterboxed to its cell's shape (see
// ``PreparedPrintImage/padded(toCellAspectRatio:)``) and the film's text lands
// at the cell's corners exactly as it does here. The type scales with the cell,
// so a 4×5 sheet carries the same block as a single-image film without either
// drowning the picture or becoming unreadable.

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

    /// The typography this job burns with. Defaults to the automatic style, so
    /// callers that are not a print job — the viewer's own overlay — get the
    /// same caption the film carries when nobody has asked for anything else.
    var style: PrintAnnotationStyle = .automatic

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
            //
            // In the face the burner will use, not the system font. The block is
            // *measured* in that face to decide where it has to shrink (see
            // `width(of:fontSize:)`), so setting it in another one measured one
            // thing and drew another — a long study description could fit on
            // screen and overrun on film, which is exactly what the preview is
            // there to catch.
            .font(.custom(style.fontFamily, size: fontSize))
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
        // The burner sets one line every `captionLineFactor` of the type size;
        // a VStack's spacing is the gap *between* line boxes, so the gap is
        // that pitch less the line box itself. Set by eye at 0.22 before, which
        // put the preview's lines closer together than the film's.
        VStack(alignment: alignment, spacing: fontSize * Self.lineSpacingFactor) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        // Half the cell apiece, so the two blocks along an edge cannot run into
        // each other and leave a name overprinted by a technique — the same
        // share the burner allots a corner on the film.
        .frame(maxWidth: max(0, cellSize.width * CGFloat(ImageAnnotationBurner.cornerWidthFraction)),
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
        Self.fittedFontSize(for: corners, cellSize: cellSize, style: style)
    }

    /// Inset from the cell's edge — enough that the text does not sit on the
    /// border, scaled so a small cell does not lose room to margins.
    private var padding: CGFloat { max(2, fontSize * Self.marginFactor) }

    /// Type size for a cell of this size.
    ///
    /// The *burner's* proportion, applied to the cell: the film is the artifact
    /// that has to be right, and a preview set at a different fraction is a
    /// preview that cannot be used to judge it. This used to be 2.3% of the
    /// cell's height capped at 11 pt, against the burner's 3.5% of the frame
    /// with no ceiling at all — so on a single-image film the preview drew the
    /// caption at under half the size the printer laid down, and the bigger the
    /// preview the wider the gap.
    ///
    /// Bounded below only, and in points rather than pixels: a floor keeps a
    /// 4×5 tile's caption legible on screen, where the burner's floor is in the
    /// pixels of the frame. There is deliberately no ceiling — the film has
    /// none, and a cap is exactly what put the two out of step.
    static func fontSize(
        for cellSize: CGSize, style: PrintAnnotationStyle = .automatic
    ) -> CGFloat {
        // A job that states its own caption size states it as a fraction of the
        // picture's height, exactly as the burner reads it — so the preview
        // applies it to the cell the same way and the two stay one size.
        //
        // `resolvedSizeFraction`, not `sizeFraction`: the single-image taper is
        // part of the size the film will carry, and reading the untapered
        // fraction here would put the preview back out of step with the burner
        // on exactly the layout the taper exists for.
        if let fraction = style.resolvedSizeFraction {
            return max(cellSize.height * CGFloat(fraction), minimumSize)
        }
        // The same taper the burner applies to the automatic size on a sheet cut
        // into one cell — see ``PrintAnnotationStyle/singleImageFilm``. Applied
        // before the floor, as there, so a tapered caption stops at the floor
        // rather than below it.
        let factor = style.singleImageFilm
            ? CGFloat(PrintAnnotationStyle.singleImageFactor) : 1
        let byHeight = cellSize.height * heightFraction
        let byWidth = cellSize.width * widthFraction
        return max(min(byHeight, byWidth) * factor, minimumSize)
    }

    /// The cell's type size, shrunk as one block until the widest line fits
    /// its corner — never below half, the floor the per-line shrink used to
    /// have, past which a line truncates rather than dragging every other
    /// line into illegibility with it.
    ///
    /// The same shrink the burner applies, against the same share of the width
    /// and down to the same floor, so preview and film step the block down on
    /// the same line rather than one shrinking while the other does not.
    static func fittedFontSize(
        for corners: PrintCornerAnnotation, cellSize: CGSize,
        style: PrintAnnotationStyle = .automatic
    ) -> CGFloat {
        let base = fontSize(for: cellSize, style: style)
        let available = cellSize.width * CGFloat(ImageAnnotationBurner.cornerWidthFraction)
        guard available > 0 else { return base }
        let widest = corners.allLines
            .map { width(of: $0, fontSize: base, fontFamily: style.fontFamily) }
            .max() ?? 0
        guard widest > available else { return base }
        return base * max(CGFloat(ImageAnnotationBurner.minimumShrinkFactor),
                          available / widest)
    }

    /// One line's set width at a size, in the face it will be set in.
    ///
    /// The film's face, which is now also the face this view draws with — so
    /// the measurement that decides where the block shrinks describes the type
    /// actually on screen as well as the type on film.
    private static func width(
        of line: String, fontSize: CGFloat,
        fontFamily: String = PrintAnnotationStyle.defaultFontFamily
    ) -> CGFloat {
        let font = CTFontCreateWithName(fontFamily as CFString, fontSize, nil)
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

    /// Type size as a fraction of the cell — the burner's own fractions, so the
    /// preview and the film set the caption at one size. Kept as aliases rather
    /// than copies: a second set of numbers here is what drifted last time.
    private static let heightFraction = CGFloat(ImageAnnotationBurner.heightFraction)
    private static let widthFraction = CGFloat(ImageAnnotationBurner.widthFraction)

    /// Must match the layout above: the inset off the edge, and one line box
    /// (type plus its gap) per line — both the burner's, so a block of four
    /// lines occupies the same share of the cell on screen as on film.
    static let marginFactor = CGFloat(ImageAnnotationBurner.captionMarginFactor)
    static let lineHeightFactor = CGFloat(ImageAnnotationBurner.captionLineFactor)

    /// The gap a `VStack` needs to produce the burner's line pitch: the pitch
    /// less the line box the type already occupies.
    static let lineSpacingFactor: CGFloat = lineHeightFactor - 1

    /// A floor in points, so a caption in a 4×5 tile stays readable on screen.
    /// There is no ceiling: the film has none, and one is what put the preview
    /// and the burner out of step.
    private static let minimumSize: CGFloat = 5
}
#endif
