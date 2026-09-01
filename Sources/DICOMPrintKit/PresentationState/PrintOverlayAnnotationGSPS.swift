// PrintOverlayAnnotationGSPS.swift
// DICOMPrintKit
//
// Drawn text and arrows, translated into the DICOM vocabulary a GSPS carries —
// PS3.3 C.10.5 text objects and polylines.
//
// This is a one-way, best-effort translation written *in addition to* the JSON
// sidecar (see ``AnnotationSidecar``), never instead of it. DICOM's vocabulary
// cannot say everything ``PrintOverlayAnnotation`` says — there is no arrow
// primitive, no per-annotation colour (a layer carries one *recommended*
// value), and nothing corresponding to `scale` — so the sidecar remains the
// authority our own restore reads, and this sequence is what makes the saved
// object legible to any other DICOM viewer: the words at their anchor, and the
// arrow as the polylines of its shaft and head.

import Foundation
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Translates drawn overlays into GSPS Graphic Annotation vocabulary.
public enum PrintOverlayAnnotationGSPS {

    /// The one layer every drawn annotation is filed under.
    ///
    /// One layer rather than one per colour: layers exist for stacking order,
    /// and drawn annotations have none — they were placed on one image by one
    /// reader. The layer's recommended RGB is the first annotation's colour,
    /// which is right when the film uses one colour (the common case) and an
    /// honest approximation when it does not.
    public static let layerName = "DRAWINGS"

    /// The layer the annotation below belongs to — required by C.10.5, which
    /// files every annotation under a named layer.
    public static func graphicLayers(
        for annotations: [PrintOverlayAnnotation]
    ) -> [GraphicLayer] {
        let drawable = annotations.filter { !$0.isBlank }
        guard let first = drawable.first else { return [] }
        return [GraphicLayer(
            name: layerName,
            order: 1,
            description: "Reader-drawn text and arrows",
            recommendedRGBValue: (
                red: Int((first.color.red * 65535).rounded()),
                green: Int((first.color.green * 65535).rounded()),
                blue: Int((first.color.blue * 65535).rounded())))]
    }

    /// One Graphic Annotation item per frame that was drawn on, each naming
    /// its own frame — the multi-frame spelling of ``graphicAnnotation(from:imageWidth:imageHeight:referencedImage:)``.
    ///
    /// A GSPS names the image it describes, but a multi-frame image's arrows
    /// are statements about individual frames: flattening every frame's
    /// drawings into one un-framed item makes a conforming viewer paint frame
    /// 3's arrow onto all sixty frames, mixed in with frame 1's and frame 7's.
    /// Referenced Frame Number (0008,1160) inside each item is what confines
    /// them, and the sidecar has always kept this distinction — this is the
    /// same statement in DICOM's own vocabulary.
    ///
    /// - Parameters:
    ///   - annotationsByFrame: What the reader drew, keyed by *zero-based*
    ///     frame index — the app's own numbering, converted to DICOM's
    ///     one-based Referenced Frame Number here.
    ///   - imageWidth: The image's columns — the annotations are stored as
    ///     fractions and a GSPS states pixels, so the size is what converts.
    ///   - imageHeight: The image's rows.
    ///   - referencedImage: The image the annotations apply to. Any frame
    ///     numbers it already carries are replaced per item.
    ///   - isMultiFrame: Whether the image has more than one frame. False
    ///     writes no frame number at all, which is what a single-frame image
    ///     means and the exact bytes this bridge wrote before frames were
    ///     stated — the sole frame of a single-frame image is the whole
    ///     instance, and naming it would only add a tag older readers must
    ///     interpret.
    /// - Returns: One item per drawn-on frame, in frame order. Empty when
    ///   nothing drawable remains after blanks are dropped.
    public static func graphicAnnotations(
        from annotationsByFrame: [Int: [PrintOverlayAnnotation]],
        imageWidth: Int,
        imageHeight: Int,
        referencedImage: ReferencedImage,
        isMultiFrame: Bool
    ) -> [GraphicAnnotation] {
        // A single-frame image has nothing frame-shaped to say: every drawing
        // is a statement about the whole instance, so they collapse into the
        // one un-framed item this bridge has always written.
        guard isMultiFrame else {
            let flattened = annotationsByFrame
                .sorted { $0.key < $1.key }
                .flatMap(\.value)
            return graphicAnnotation(
                from: flattened,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                referencedImage: referencedImage).map { [$0] } ?? []
        }

        return annotationsByFrame
            .sorted { $0.key < $1.key }
            .compactMap { frame, annotations in
                // DICOM counts frames from one; the store counts from zero.
                // A negative key cannot be named at all, and writing it as a
                // frame number would produce an out-of-range reference.
                guard frame >= 0 else { return nil }
                let framed = ReferencedImage(
                    sopClassUID: referencedImage.sopClassUID,
                    sopInstanceUID: referencedImage.sopInstanceUID,
                    referencedFrameNumbers: [frame + 1])
                return graphicAnnotation(
                    from: annotations,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    referencedImage: framed)
            }
    }

    /// One image's drawn annotations as a single Graphic Annotation item, or
    /// `nil` when nothing drawable remains after blanks are dropped.
    ///
    /// - Parameters:
    ///   - annotations: What the reader drew, in image-normalized coordinates.
    ///   - imageWidth: The image's columns — the annotations are stored as
    ///     fractions and a GSPS states pixels, so the size is what converts.
    ///   - imageHeight: The image's rows.
    ///   - referencedImage: The image the annotation applies to, stated
    ///     explicitly so a multi-image series cannot misfile it — including
    ///     the frame, when the caller has one to name.
    public static func graphicAnnotation(
        from annotations: [PrintOverlayAnnotation],
        imageWidth: Int,
        imageHeight: Int,
        referencedImage: ReferencedImage
    ) -> GraphicAnnotation? {
        guard imageWidth > 0, imageHeight > 0 else { return nil }
        let drawable = annotations.filter { !$0.isBlank }
        guard !drawable.isEmpty else { return nil }

        var graphicObjects: [GraphicObject] = []
        var textObjects: [TextObject] = []

        for annotation in drawable {
            switch annotation.kind {
            case .text:
                textObjects.append(textObject(
                    for: annotation, imageWidth: imageWidth, imageHeight: imageHeight))
            case .arrow:
                graphicObjects.append(contentsOf: arrowObjects(
                    for: annotation, imageWidth: imageWidth, imageHeight: imageHeight))
            case .annotation:
                // The combined kind is exactly DICOM's anchored text: the words
                // in their bounding box, with a visible anchor point the display
                // draws a line to — the same statement Weasis writes for its
                // Annotation graphic. Only an annotation that never got words
                // falls back to the arrow's polylines.
                if annotation.hasWords {
                    textObjects.append(textObject(
                        for: annotation, imageWidth: imageWidth, imageHeight: imageHeight,
                        anchor: annotation.hasArrow ? annotation.end : nil))
                } else {
                    graphicObjects.append(contentsOf: arrowObjects(
                        for: annotation, imageWidth: imageWidth, imageHeight: imageHeight))
                }
            case .polyline, .circle, .ellipse, .point:
                // A shape that came *from* a GSPS goes back out as the same
                // graphic object it was read from — re-saving a view that
                // carries an imported ruler must not lose the ruler.
                if let object = shapeObject(
                    for: annotation, imageWidth: imageWidth, imageHeight: imageHeight) {
                    graphicObjects.append(object)
                }
            case .shutter:
                // Shutters are the Display Shutter module's, not an annotation;
                // they are written by the state's own `shutters`, not here.
                break
            }
        }

        guard !graphicObjects.isEmpty || !textObjects.isEmpty else { return nil }
        return GraphicAnnotation(
            layer: layerName,
            referencedImages: [referencedImage],
            graphicObjects: graphicObjects,
            textObjects: textObjects)
    }

    // MARK: - Text

    /// - Parameter anchor: for the combined kind, the image point the words'
    ///   arrow names — written as a *visible* anchor point, which is DICOM's
    ///   own "text with a leader line". `nil` keeps the plain-text form: the
    ///   anchor restated at the box corner, invisible.
    private static func textObject(
        for annotation: PrintOverlayAnnotation,
        imageWidth: Int,
        imageHeight: Int,
        anchor: PrintOverlayPoint? = nil
    ) -> TextObject {
        let anchorColumn = annotation.start.x * Double(imageWidth)
        let anchorRow = annotation.start.y * Double(imageHeight)
        let size = measuredTextSize(
            annotation.text, imageHeight: Double(imageHeight), scale: annotation.scale)

        // The box runs down-right from the anchor because that is where every
        // renderer of this model sets the words — the anchor is the top-left.
        // Clamped to the image: a GSPS bounding box outside the pixels is a
        // claim about pixels that do not exist.
        let bottomRightColumn = min(Double(imageWidth), anchorColumn + size.width)
        let bottomRightRow = min(Double(imageHeight), anchorRow + size.height)

        return TextObject(
            text: annotation.text,
            boundingBoxTopLeft: (column: anchorColumn, row: anchorRow),
            boundingBoxBottomRight: (column: bottomRightColumn, row: bottomRightRow),
            anchorPoint: anchor.map { (column: $0.x * Double(imageWidth),
                                       row: $0.y * Double(imageHeight)) }
                ?? (column: anchorColumn, row: anchorRow),
            anchorPointVisible: anchor != nil,
            boundingBoxUnits: .pixel,
            anchorPointUnits: .pixel)
    }

    /// The words' extent in image pixels — measured with the burner's own face
    /// where CoreText exists, estimated where it does not, so the conversion
    /// never fails for want of a font. Public because the viewer's edit layer
    /// sizes its selection chrome from the same measurement.
    public static func measuredTextSize(
        _ text: String, imageHeight: Double, scale: Double
    ) -> (width: Double, height: Double) {
        let fontSize = ImageAnnotationBurner.overlayFontSize(
            imageHeight: imageHeight, scale: scale)
        #if canImport(CoreGraphics)
        let size = ImageAnnotationBurner.overlayTextSize(
            text, imageHeight: imageHeight, scale: scale)
        if size.width > 0 {
            return (Double(size.width), Double(size.height))
        }
        #endif
        return (fontSize * 0.6 * Double(text.count), fontSize)
    }

    // MARK: - Shapes

    /// A shape kind as the graphic object it was read from.
    private static func shapeObject(
        for annotation: PrintOverlayAnnotation,
        imageWidth: Int,
        imageHeight: Int
    ) -> GraphicObject? {
        let type: PresentationGraphicType
        switch annotation.kind {
        case .polyline: type = .polyline
        case .circle:   type = .circle
        case .ellipse:  type = .ellipse
        case .point:    type = .point
        default:        return nil
        }
        guard !annotation.isBlank else { return nil }
        var data: [Double] = []
        for point in annotation.points {
            data.append(point.x * Double(imageWidth))
            data.append(point.y * Double(imageHeight))
        }
        return GraphicObject(type: type, data: data, filled: annotation.filled, units: .pixel)
    }

    // MARK: - Reading a state written elsewhere

    /// The drawings a presentation state carries for one image, as the
    /// overlays this app displays and burns — the reverse of the writers
    /// above, for states written by another viewer.
    ///
    /// Every graphic object becomes a shape overlay in its layer's colour;
    /// every text object becomes a text overlay, or the combined kind when it
    /// has a visible anchor (Weasis's annotation with its leader line). All of
    /// them locked: they say what another reader measured, and moving one
    /// here would make its label wrong.
    ///
    /// Frames follow the item's Referenced Frame Number (one-based): an item
    /// that names none applies to every frame of a multi-frame image, which is
    /// what the standard means by the omission and what a cine viewer shows.
    ///
    /// - Parameters:
    ///   - state: The parsed state.
    ///   - sopInstanceUID: The image to read drawings for; items naming other
    ///     images are skipped.
    ///   - imageWidth: The image's columns, to normalize PIXEL coordinates.
    ///   - imageHeight: The image's rows.
    ///   - numberOfFrames: How many frames the image has, so an unframed item
    ///     can be spread across all of them.
    /// - Returns: Overlays keyed by zero-based frame index. Empty when the
    ///   state draws nothing on this image.
    public static func overlays(
        from state: GrayscalePresentationState,
        forImage sopInstanceUID: String,
        imageWidth: Int,
        imageHeight: Int,
        numberOfFrames: Int = 1
    ) -> [Int: [PrintOverlayAnnotation]] {
        guard imageWidth > 0, imageHeight > 0 else { return [:] }
        let width = Double(imageWidth)
        let height = Double(imageHeight)
        let colours = Dictionary(
            state.graphicLayers.map { ($0.name, layerColor($0)) },
            uniquingKeysWith: { first, _ in first })
        var byFrame: [Int: [PrintOverlayAnnotation]] = [:]

        for item in state.graphicAnnotations {
            let references = item.referencedImages.filter { $0.sopInstanceUID == sopInstanceUID }
            guard !references.isEmpty else { continue }
            let color = colours[item.layer] ?? .yellow

            var overlays: [PrintOverlayAnnotation] = []
            for object in item.graphicObjects {
                if let overlay = shapeOverlay(object, width: width, height: height, color: color) {
                    overlays.append(overlay)
                }
            }
            for text in item.textObjects {
                if let overlay = textOverlay(text, width: width, height: height, color: color) {
                    overlays.append(overlay)
                }
            }
            guard !overlays.isEmpty else { continue }

            // The frames this item speaks for. Several references to the same
            // image with different frames are legal and are all honoured.
            var frames = Set<Int>()
            for reference in references {
                if let numbers = reference.referencedFrameNumbers, !numbers.isEmpty {
                    for number in numbers where number >= 1 { frames.insert(number - 1) }
                } else {
                    for frame in 0..<max(1, numberOfFrames) { frames.insert(frame) }
                }
            }
            for frame in frames {
                // Fresh identities per frame: the same drawing on two frames is
                // two overlays as far as selection and deletion are concerned.
                byFrame[frame, default: []].append(contentsOf: overlays.map {
                    var copy = $0
                    copy.id = UUID()
                    return copy
                })
            }
        }
        return byFrame
    }

    /// The layer's recommended colour, RGB first (16-bit per channel), then
    /// grey, then the reading-room default.
    static func layerColor(_ layer: GraphicLayer) -> PrintOverlayColor {
        if let rgb = layer.recommendedRGBValue {
            return PrintOverlayColor(
                red: Double(rgb.red) / 65535,
                green: Double(rgb.green) / 65535,
                blue: Double(rgb.blue) / 65535)
        }
        if let grey = layer.recommendedGrayscaleValue {
            let value = Double(grey) / 65535
            return PrintOverlayColor(red: value, green: value, blue: value)
        }
        return .yellow
    }

    /// One graphic object as a shape overlay, or nil for one this cannot draw.
    static func shapeOverlay(
        _ object: GraphicObject,
        width: Double, height: Double,
        color: PrintOverlayColor
    ) -> PrintOverlayAnnotation? {
        let kind: PrintOverlayAnnotation.Kind
        switch object.type {
        case .point:                  kind = .point
        case .polyline, .interpolated: kind = .polyline
        case .circle:                 kind = .circle
        case .ellipse:                kind = .ellipse
        }
        let points = normalizedPoints(object.data, units: object.units, width: width, height: height)
        let overlay = PrintOverlayAnnotation(
            shape: kind, points: points, filled: object.filled,
            scale: PrintOverlayAnnotation.defaultScale, color: color, isLocked: true)
        return overlay.isBlank ? nil : overlay
    }

    /// One text object as a text overlay — the combined kind when its anchor
    /// is visible, since that is DICOM's own "label with a leader line".
    ///
    /// The type size is taken from the bounding box's height, which is how
    /// the writer said how large the words were; clamped to what this app can
    /// set, which is wide enough for any measurement label.
    static func textOverlay(
        _ text: TextObject,
        width: Double, height: Double,
        color: PrintOverlayColor
    ) -> PrintOverlayAnnotation? {
        let words = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        let topLeft = normalizedPoints(
            [text.boundingBoxTopLeft.column, text.boundingBoxTopLeft.row],
            units: text.boundingBoxUnits, width: width, height: height).first
            ?? PrintOverlayPoint(x: 0, y: 0)
        let bottomRight = normalizedPoints(
            [text.boundingBoxBottomRight.column, text.boundingBoxBottomRight.row],
            units: text.boundingBoxUnits, width: width, height: height).first
            ?? topLeft
        // Bounding box height as a fraction of the image is exactly what
        // `scale` means. A box with no height (some writers state a point)
        // falls back to the default size.
        let boxHeight = abs(bottomRight.y - topLeft.y)
        let scale = boxHeight > 0.001
            ? boxHeight
            : PrintOverlayAnnotation.defaultScale
        // The words start at the box's top-left whichever corner order the
        // writer used.
        let start = PrintOverlayPoint(
            x: min(topLeft.x, bottomRight.x), y: min(topLeft.y, bottomRight.y))

        if text.anchorPointVisible, let anchor = text.anchorPoint {
            let end = normalizedPoints(
                [anchor.column, anchor.row],
                units: text.anchorPointUnits, width: width, height: height).first ?? start
            return PrintOverlayAnnotation(
                kind: .annotation, start: start, end: end, text: words,
                scale: scale, color: color, isLocked: true)
        }
        return PrintOverlayAnnotation(
            kind: .text, start: start, text: words,
            scale: scale, color: color, isLocked: true)
    }

    /// Pairs of coordinates as normalized points. PIXEL values are divided by
    /// the image's size; DISPLAY values are already fractions of the displayed
    /// area, which this treats as the image — right for the whole-image
    /// display most writers state, and the only reading possible without the
    /// writer's viewport.
    static func normalizedPoints(
        _ data: [Double], units: AnnotationUnits, width: Double, height: Double
    ) -> [PrintOverlayPoint] {
        guard data.count >= 2 else { return [] }
        var points: [PrintOverlayPoint] = []
        for index in stride(from: 0, to: data.count - 1, by: 2) {
            let x = data[index]
            let y = data[index + 1]
            switch units {
            case .pixel:
                // The same convention the writers above use — a fraction of
                // the image's size, no half-pixel offset — so a shape written
                // by this app and read back lands exactly where it was.
                points.append(PrintOverlayPoint(x: x / width, y: y / height))
            case .display:
                points.append(PrintOverlayPoint(x: x, y: y))
            }
        }
        return points
    }

    // MARK: - Arrow

    /// An arrow as two polylines: the shaft from tail to tip, and the open
    /// head traced left wing → tip → right wing.
    ///
    /// GSPS has no arrow primitive, so this is the closest statement its
    /// vocabulary makes: a viewer that renders the polylines shows a line with
    /// a chevron at the pointing end. The head's size comes from the same
    /// ``PrintArrowGeometry`` the film is burned with, so the two agree.
    private static func arrowObjects(
        for annotation: PrintOverlayAnnotation,
        imageWidth: Int,
        imageHeight: Int
    ) -> [GraphicObject] {
        let tail = PrintPlanePoint(
            x: annotation.start.x * Double(imageWidth),
            y: annotation.start.y * Double(imageHeight))
        let head = PrintPlanePoint(
            x: annotation.end.x * Double(imageWidth),
            y: annotation.end.y * Double(imageHeight))
        let dx = head.x - tail.x
        let dy = head.y - tail.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return [] }

        let geometry = PrintArrowGeometry(
            scale: annotation.scale,
            imageHeight: Double(imageHeight),
            arrowLength: length)
        guard let outline = geometry.outline(tail: tail, head: head) else { return [] }

        return [
            GraphicObject(
                type: .polyline,
                data: [tail.x, tail.y, head.x, head.y],
                filled: false,
                units: .pixel),
            GraphicObject(
                type: .polyline,
                data: [outline.headLeft.x, outline.headLeft.y,
                       head.x, head.y,
                       outline.headRight.x, outline.headRight.y],
                filled: false,
                units: .pixel)
        ]
    }
}
