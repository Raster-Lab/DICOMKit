// ViewerAnnotationOverlayView.swift
// DICOMStudio
//
// DICOM Studio — the reading annotations drawn over a viewport.
//
// Text in the four corners and the patient's sides at the four edges, over the
// picture rather than beside it. On screen this is the right trade: the corners
// of a fitted image are background, the reader's eye is in the middle, and the
// annotation has to be in the same view as the anatomy it describes — glancing
// away to a caption strip is what a workstation exists to avoid.
//
// Film is annotated the same way, in the same corners — see
// ``PatientIdentificationOverlayView``, which draws a film cell's identification
// and ``ImageAnnotationBurner``, which burns it into the printed pixels.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerAnnotationOverlayView: View {

    /// What the file says.
    let text: ViewerAnnotationText

    /// What the viewport is currently doing with it.
    let state: ViewerAnnotationViewportState

    /// The viewport this is drawn in — sets the type size and how much is shown.
    let cellSize: CGSize

    /// Room to leave at the top right for the print checkbox that lives there.
    ///
    /// The checkbox is a control and the block is text; overlapping them would
    /// make the control hard to hit and the name hard to read, and the name is
    /// the one that must not be misread.
    var topTrailingInset: CGFloat = 0

    /// Room to leave at the top left for the film-position chip, on tiles that
    /// carry one. Same reasoning as the checkbox opposite it: the chip is the
    /// answer to "does this print, and where", and a window/level line drawn
    /// through it makes both unreadable.
    var topLeadingInset: CGFloat = 0

    /// Whether the patient-orientation letters are drawn at all.
    ///
    /// The reader's switch — see ``ImageViewerViewModel/showOrientationLabels``
    /// for why laterality gets its own one rather than riding along with the
    /// corner blocks.
    var showOrientation: Bool = true

    /// Room to leave at the middle of the right edge for the controls that sit
    /// there — the print tick, and the saved-views badge under it.
    ///
    /// The right-edge letter is centred on that edge, which is exactly where
    /// those controls are, so the tick was drawn straight over the "L" on an
    /// axial slice. A hidden orientation letter is worse than an absent one:
    /// absent, a reader knows to check; hidden, they read the picture as though
    /// the marker had been looked at. So the letter moves in by the width of
    /// the controls rather than the controls moving off the edge, which would
    /// put them back in a corner the identification block wants.
    var trailingControlsInset: CGFloat = 0

    var body: some View {
        let corners = ViewerAnnotationCorners.make(
            text: text,
            state: state,
            detail: ViewerAnnotationCorners.Detail.forViewport(cellSize))

        if corners.isEmpty {
            EmptyView()
        } else {
            ZStack {
                block(corners.topLeft, alignment: .leading)
                    .padding(.top, topLeadingInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                block(corners.topRight, alignment: .trailing)
                    .padding(.top, topTrailingInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                block(corners.bottomLeft, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                block(corners.bottomRight, alignment: .trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                if showOrientation, let orientation = corners.orientation,
                   !orientation.isEmpty {
                    edgeLabels(orientation)
                }
            }
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundStyle(Self.textColor)
            // The picture underneath is arbitrary: a shadow is what keeps a line
            // readable over bone as well as over air, without a panel behind it
            // that would hide the anatomy the corner is standing on.
            .shadow(color: .black.opacity(0.9), radius: 1.2)
            .padding(padding)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Image annotations")
        }
    }

    // MARK: - Pieces

    private func block(_ lines: [String], alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: fontSize * 0.22) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .lineLimit(1)
                    // A long protocol name shrinks rather than truncating: the
                    // end of "t2_tse_rst_sag_LS" is the part that identifies it.
                    .minimumScaleFactor(0.6)
            }
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        .frame(maxWidth: cellSize.width * 0.45,
               alignment: alignment == .leading ? .leading : .trailing)
    }

    /// The patient's sides, at the edges they are on.
    private func edgeLabels(_ orientation: ViewerOrientationLabels) -> some View {
        ZStack {
            edgeLabel(orientation.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            edgeLabel(orientation.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            edgeLabel(orientation.left)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            edgeLabel(orientation.right)
                .padding(.trailing, trailingControlsInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func edgeLabel(_ letters: String) -> some View {
        if letters.isEmpty {
            EmptyView()
        } else {
            Text(letters)
                .font(.system(size: fontSize * 1.15, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.orientationColor)
        }
    }

    // MARK: - Metrics

    /// Type size scaled to the viewport, so a 4×4 tile carries the same block at
    /// a size proportionate to it rather than a block sized for a full screen.
    private var fontSize: CGFloat {
        let byHeight = cellSize.height * 0.026
        return min(max(byHeight, Self.minimumSize), Self.maximumSize)
    }

    /// Inset from the viewport's edge — enough that the text does not touch the
    /// tile's border, scaled so a small tile does not lose room to margins.
    private var padding: CGFloat { max(4, fontSize * 0.6) }

    /// White, with the shadow below doing the work of keeping it legible over
    /// both bone and air. One hue for the whole block: nothing in the corners is
    /// a different kind of statement from anything else there.
    private static let textColor = Color.white

    /// The edge letters read in the same white as the corners; their weight and
    /// size are what set them apart.
    private static let orientationColor = Color.white

    private static let minimumSize: CGFloat = 7
    private static let maximumSize: CGFloat = 12
}
#endif
