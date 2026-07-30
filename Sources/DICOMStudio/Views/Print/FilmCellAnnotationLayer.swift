// FilmCellAnnotationLayer.swift
// DICOMStudio
//
// DICOM Studio — the reader's own text and arrows, drawn over a film cell.
//
// This layer draws what will be burned into the printed pixels, from the same
// numbers: positions are fractions of the image, so what is on screen here is
// what the printer receives — not an approximation of it. The geometry of an
// arrow (line weight, head length, head width) is deliberately the same formula
// ``ImageAnnotationBurner`` uses, because an arrow that looks balanced in the
// preview and heavy on the film is a preview that lied.
//
// Annotations are positioned against the *image rect* rather than the cell: a
// portrait CT in a landscape cell leaves black margins, and an arrow dropped in
// the margin would have no pixels to be burned into.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmCellAnnotationLayer: View {
    @Bindable var viewModel: PrintViewModel

    /// The mark this cell shows, which is what annotations belong to.
    let itemID: String

    /// Where the image is actually drawn inside the cell, in cell points.
    let imageRect: CGRect

    /// Whether this cell accepts clicks. A cell only takes annotation edits while
    /// a drawing tool is active or something on it is already selected — otherwise
    /// windowing a cell would be interrupted by whatever text is sitting on it.
    let isInteractive: Bool

    /// Anchor for the annotation being dragged, so a drag applies deltas.
    @State private var dragAnchor: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(viewModel.annotations(forItemID: itemID)) { annotation in
                switch annotation.kind {
                case .text:  textAnnotation(annotation)
                case .arrow: arrowAnnotation(annotation)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(name: Self.space)
        // Nothing here should swallow a click meant for the picture underneath.
        .allowsHitTesting(isInteractive)
    }

    private static let space = "filmCellAnnotations"

    // MARK: - Text

    @ViewBuilder
    private func textAnnotation(_ annotation: PrintOverlayAnnotation) -> some View {
        let isSelected = viewModel.selectedAnnotationID == annotation.id
        let fontSize = max(Self.minimumPreviewFontSize, imageRect.height * annotation.scale)
        let position = point(annotation.start)

        Group {
            if annotation.text.isEmpty {
                // A caret, not placeholder words. Prompt text drawn on the film
                // reads as something that will print — and the moment it appears
                // over anatomy, the preview is lying about the film. The caret
                // marks where typing will land and nothing more; it is only ever
                // shown while this annotation is the one being edited.
                Rectangle()
                    .fill(color(annotation.color))
                    .frame(width: max(1, fontSize * 0.08), height: fontSize)
                    .shadow(color: halo(annotation.color), radius: 1)
            } else {
                // Helvetica Bold, because that is the face burned into the pixels
                // — a preview in the system font would set to a different width
                // and break differently from the film.
                Text(annotation.text)
                    .font(.custom("Helvetica-Bold", size: fontSize))
                    .foregroundStyle(color(annotation.color))
                    .shadow(color: halo(annotation.color), radius: max(1, fontSize * 0.08))
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(isSelected ? Color.accentColor : .clear,
                              style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        )
        .contentShape(Rectangle())
        .offset(x: position.x, y: position.y)
        .gesture(moveGesture(annotation))
        .onTapGesture { viewModel.selectAnnotation(annotation.id) }
        .accessibilityLabel(annotation.text.isEmpty
                            ? "Empty text annotation"
                            : "Text annotation: \(annotation.text)")
    }

    // MARK: - Arrow

    @ViewBuilder
    private func arrowAnnotation(_ annotation: PrintOverlayAnnotation) -> some View {
        let isSelected = viewModel.selectedAnnotationID == annotation.id
        let tail = point(annotation.start)
        let head = point(annotation.end)
        let metrics = ArrowMetrics(
            scale: annotation.scale, imageHeight: imageRect.height,
            tail: tail, head: head)

        ZStack(alignment: .topLeading) {
            ArrowShape(metrics: metrics)
                .fill(color(annotation.color))
                .shadow(color: halo(annotation.color), radius: max(1, metrics.lineWidth * 0.5))
                // A thin arrow is hard to hit, so the touchable area is the line
                // fattened, not the drawn width.
                .contentShape(ArrowShape(metrics: metrics).stroke(lineWidth: Self.grabWidth))
                .gesture(moveGesture(annotation))
                .onTapGesture { viewModel.selectAnnotation(annotation.id) }

            if isSelected {
                handle(at: tail) { newPoint in
                    viewModel.moveArrowEnd(annotation.id, forItemID: itemID,
                                           isHead: false, to: newPoint)
                }
                handle(at: head) { newPoint in
                    viewModel.moveArrowEnd(annotation.id, forItemID: itemID,
                                           isHead: true, to: newPoint)
                }
            }
        }
        .accessibilityLabel("Arrow annotation")
    }

    /// A draggable end of a selected arrow.
    private func handle(at position: CGPoint, move: @escaping (PrintOverlayPoint) -> Void) -> some View {
        Circle()
            .fill(Color.accentColor)
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1))
            .frame(width: Self.handleSize, height: Self.handleSize)
            .offset(x: position.x - Self.handleSize / 2, y: position.y - Self.handleSize / 2)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in move(normalized(value.location)) }
            )
            .accessibilityHidden(true)
    }

    // MARK: - Moving

    /// Drag anywhere on an annotation to move the whole thing.
    private func moveGesture(_ annotation: PrintOverlayAnnotation) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if viewModel.selectedAnnotationID != annotation.id {
                    viewModel.selectAnnotation(annotation.id)
                }
                let dx = value.translation.width - dragAnchor.width
                let dy = value.translation.height - dragAnchor.height
                dragAnchor = value.translation
                guard imageRect.width > 0, imageRect.height > 0 else { return }
                viewModel.moveAnnotation(annotation.id, forItemID: itemID,
                                         dx: Double(dx) / imageRect.width,
                                         dy: Double(dy) / imageRect.height)
            }
            .onEnded { _ in dragAnchor = .zero }
    }

    // MARK: - Coordinates

    /// A normalized point in cell points.
    private func point(_ overlayPoint: PrintOverlayPoint) -> CGPoint {
        CGPoint(x: imageRect.minX + overlayPoint.x * imageRect.width,
                y: imageRect.minY + overlayPoint.y * imageRect.height)
    }

    /// A point in cell points, back to a fraction of the image.
    private func normalized(_ location: CGPoint) -> PrintOverlayPoint {
        guard imageRect.width > 0, imageRect.height > 0 else {
            return PrintOverlayPoint(x: 0, y: 0)
        }
        return PrintOverlayPoint(
            x: Double((location.x - imageRect.minX) / imageRect.width),
            y: Double((location.y - imageRect.minY) / imageRect.height))
    }

    private func color(_ overlayColor: PrintOverlayColor) -> Color {
        Color(red: overlayColor.red, green: overlayColor.green, blue: overlayColor.blue)
    }

    /// The halo behind an annotation, so it reads over lung and over mediastinum.
    private func halo(_ overlayColor: PrintOverlayColor) -> Color {
        overlayColor.luminance > 0.45 ? .black.opacity(0.9) : .white.opacity(0.9)
    }

    /// Below this the preview type is illegible however small the cell is.
    private static let minimumPreviewFontSize: CGFloat = 6

    private static let handleSize: CGFloat = 9

    /// How wide an arrow is to the pointer, whatever it is to the eye.
    private static let grabWidth: CGFloat = 12
}

// MARK: - Arrow geometry

/// The measurements of one drawn arrow, in cell points.
///
/// Mirrors ``ImageAnnotationBurner``'s arrow: same fractions of the image height,
/// so preview and film agree on how heavy the arrow looks.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ArrowMetrics: Equatable {
    let tail: CGPoint
    let head: CGPoint
    let lineWidth: CGFloat
    let headLength: CGFloat
    let headHalfWidth: CGFloat

    init(scale: Double, imageHeight: CGFloat, tail: CGPoint, head: CGPoint) {
        self.tail = tail
        self.head = head
        self.lineWidth = max(1, imageHeight * scale * 0.18)
        self.headLength = max(lineWidth * 3, imageHeight * scale * 0.9)
        self.headHalfWidth = headLength * 0.45
    }
}

/// A line with a filled head, as one fillable shape.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ArrowShape: Shape {
    let metrics: ArrowMetrics

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let dx = metrics.head.x - metrics.tail.x
        let dy = metrics.head.y - metrics.tail.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return path }

        let ux = dx / length
        let uy = dy / length
        let shaftEnd = CGPoint(x: metrics.head.x - ux * metrics.headLength,
                               y: metrics.head.y - uy * metrics.headLength)

        // The shaft as a quad rather than a stroked line, so the whole arrow is
        // one filled path and needs no separate stroke pass.
        let nx = -uy * metrics.lineWidth / 2
        let ny = ux * metrics.lineWidth / 2
        let end = length > metrics.headLength ? shaftEnd : metrics.head
        path.move(to: CGPoint(x: metrics.tail.x + nx, y: metrics.tail.y + ny))
        path.addLine(to: CGPoint(x: end.x + nx, y: end.y + ny))
        path.addLine(to: CGPoint(x: end.x - nx, y: end.y - ny))
        path.addLine(to: CGPoint(x: metrics.tail.x - nx, y: metrics.tail.y - ny))
        path.closeSubpath()

        path.move(to: metrics.head)
        path.addLine(to: CGPoint(x: shaftEnd.x - uy * metrics.headHalfWidth,
                                 y: shaftEnd.y + ux * metrics.headHalfWidth))
        path.addLine(to: CGPoint(x: shaftEnd.x + uy * metrics.headHalfWidth,
                                 y: shaftEnd.y - ux * metrics.headHalfWidth))
        path.closeSubpath()

        return path
    }
}
#endif
