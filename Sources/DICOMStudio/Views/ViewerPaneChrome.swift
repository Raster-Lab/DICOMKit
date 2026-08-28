// ViewerPaneChrome.swift
// DICOMStudio
//
// DICOM Studio — the furniture the viewer's three columns are built from.
//
// The viewer is a series pane, a reading area and a selection tray, and until
// each was given a surface and a title they sat at one tone and read as a single
// dark field — nothing on screen said which column held the images that were
// about to print. These are the parts that answer that: a titled strip at the
// top of a pane, and the surface the pane is drawn on, with a hard edge on the
// side that faces the picture.

#if canImport(SwiftUI)
import SwiftUI

/// The title strip at the top of a viewer pane.
///
/// A pane is named, counted and — for the tray — has its bulk action here, so
/// that "what is this column?" is answered by looking at the top of it rather
/// than by inferring from its contents.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerPaneHeader<Trailing: View>: View {
    let title: String
    let systemImage: String

    /// How many things the pane is listing, when a count is meaningful.
    var count: Int?

    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String,
         systemImage: String,
         count: Int? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.count = count
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))

            Text(title.uppercased())
                // Tracked capitals at caption size: a label for the column, not
                // a heading competing with the patient's name below it.
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.8))

            if let count {
                Text("\(count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            Spacer(minLength: 4)

            trailing()
        }
        .padding(.horizontal, 8)
        .frame(height: ViewerPaneMetrics.headerHeight)
        .frame(maxWidth: .infinity)
        .background(StudioColors.viewerPanelHeader)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
    }
}

/// Sizes shared by the panes, so the two columns line up with each other and
/// with the reading area's own title strip between them.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
enum ViewerPaneMetrics {
    /// Height of a pane's title strip — and of the reading area's, so the three
    /// columns share one horizon across the top of the viewer.
    static let headerHeight: CGFloat = 24
}

/// Draws a pane's surface and the hard edge on the side facing the picture.
///
/// The edge is a shadow line rather than a hairline of light: the pane is
/// nearer the viewer than the mount the image sits in, and a dark seam is what
/// that reads as. A light rule here would instead frame the gutter, which is
/// the one thing in the viewer that should never attract the eye.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerPaneSurface: ViewModifier {
    /// Which side of the pane faces the reading area.
    let imageEdge: HorizontalEdge

    func body(content: Content) -> some View {
        content
            .background(StudioColors.viewerPanel)
            .overlay(alignment: imageEdge == .leading ? .leading : .trailing) {
                Rectangle()
                    .fill(StudioColors.viewerPanelEdge)
                    .frame(width: 1)
            }
    }
}

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension View {
    /// Paints this pane on the viewer's pane surface, seamed against the gutter.
    func viewerPaneSurface(imageEdge: HorizontalEdge) -> some View {
        modifier(ViewerPaneSurface(imageEdge: imageEdge))
    }
}
#endif
