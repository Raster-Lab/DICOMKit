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
