// ImageAnnotationBurner.swift
// DICOMPrintKit
//
// Burning text into the pixels of a printable frame: the patient caption the
// print path always adds, and whatever the reader drew on the film cell.
//
// A DICOM printer draws annotation from the film box's own annotation boxes,
// which every printer lays out differently and many ignore. Film that must
// carry the patient's name — which is most film — therefore carries it in the
// pixels, exactly where the viewer draws it: in the corners of the picture,
// where a fitted image has background rather than anatomy. A drawn arrow could
// not be expressed as an annotation box at all.
//
// This runs once per image, on the already-prepared 8-bit frame, so the cost is
// one bitmap pass per film cell rather than anything per redraw.

import Foundation
import DICOMNetwork

// MARK: - Style

/// How burned identification text is set (SRS FR-006).
///
/// The default, `.automatic`, is exactly what the burner always did: Helvetica,
/// sized as a fraction of the frame, coloured to the far end of the greyscale
/// from whatever is under it. That logic is good — it adapts to image size and
/// flips correctly for MONOCHROME1 — so overriding it is available, not
/// required.
public struct PrintAnnotationStyle: Sendable, Equatable, Hashable, Codable {

    /// How the caption is coloured.
    public enum Foreground: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
        /// White as the pixels express it, halo at the other end — adapts to
        /// MONOCHROME1 and RGB. The default.
        case automatic
        /// Force white type (black halo). On MONOCHROME1 this is the *dark*
        /// stored value; on film it reads white.
        case white
        /// Force black type (white halo).
        case black
    }

    /// PostScript/family name of the caption font. Names CoreText cannot
    /// resolve fall back to Helvetica, so a bad value degrades to the default
    /// rather than to no caption.
    public var fontFamily: String

    /// Caption height as a fraction of the frame's height, or `nil` for the
    /// automatic size. Clamped to 0.02…0.10: below 2% the caption is
    /// illegible on any cell — the SRS's 8 pt floor, expressed relative to
    /// the picture the way every other size here is — and above 10% it is a
    /// headline over the anatomy.
    public var sizeFraction: Double?

    /// Caption colour.
    public var foreground: Foreground

    public init(fontFamily: String = "Helvetica",
                sizeFraction: Double? = nil,
                foreground: Foreground = .automatic) {
        self.fontFamily = fontFamily
        self.sizeFraction = sizeFraction.map { min(0.10, max(0.02, $0)) }
        self.foreground = foreground
    }

    /// Today's behaviour, byte for byte.
    public static let automatic = PrintAnnotationStyle()
}

#if canImport(CoreGraphics)
import CoreGraphics
import CoreText

public enum ImageAnnotationBurner {

    /// Draws identification into the four corners of a prepared frame.
    ///
    /// Over the picture, not in a strip taken out of it: the corners of a fitted
    /// image are background, and every pixel the anatomy has is a pixel the
    /// reader keeps. Each line is drawn twice — a halo at the far end of the
    /// scale, then the text — so it survives both a black background and a white
    /// lung field.
    ///
    /// Returns the frame unchanged when there is nothing to draw, or when the
    /// pixels are not 8-bit grayscale or 8-bit RGB — the two formats an image
    /// box is prepared into. Refusing quietly is deliberate: an unexpected
    /// format is a reason to print the picture without a caption, never a reason
    /// to fail the job or to write text into pixels of a depth this has not
    /// been asked to interpret.
    public static func burning(
        corners: PrintCornerAnnotation,
        into image: PreparedPrintImage,
        style: PrintAnnotationStyle = .automatic
    ) -> PreparedPrintImage {
        guard !corners.isEmpty else { return image }

        return rendering(into: image) { canvas in
            let fontSize = fittedCaptionFontSize(
                for: corners, width: canvas.width, height: canvas.height,
                style: style)
            let margin = fontSize * captionMarginFactor
            let lineHeight = fontSize * captionLineFactor
            let foreground = canvas.captionForeground(style.foreground)
            let shadow = canvas.captionShadow(style.foreground)

            // A bitmap context's origin is its bottom-left, so the top corners
            // are the high `y` values — and the top of the anatomy as it is
            // displayed, since a DICOM image's rows run top to bottom.
            let top = Double(canvas.height) - margin - fontSize
            let bottom = margin

            func block(_ lines: [String], top isTop: Bool, trailing: Bool) {
                for (index, text) in lines.enumerated() {
                    let step = Double(isTop ? index : lines.count - 1 - index) * lineHeight
                    let baseline = isTop ? top - step : bottom + step
                    drawLine(text, in: canvas.context, fontSize: fontSize,
                             baseline: baseline, margin: margin,
                             width: Double(canvas.width), trailing: trailing,
                             foreground: foreground, shadow: shadow,
                             fontFamily: style.fontFamily)
                }
            }

            block(corners.topLeft, top: true, trailing: false)
            block(corners.topRight, top: true, trailing: true)
            block(corners.bottomLeft, top: false, trailing: false)
            block(corners.bottomRight, top: false, trailing: true)
        }
    }

    /// Draws what the reader drew on the film cell — text where they put it, and
    /// arrows pointing where they pointed.
    ///
    /// Positions are fractions of the image, so the same annotations drawn on a
    /// preview thumbnail land in the same places on a full-resolution frame. Blank
    /// annotations are skipped: a text box is empty for as long as it takes to
    /// type into it, and that is not a reason to draw nothing at all.
    public static func burning(
        overlays: [PrintOverlayAnnotation],
        into image: PreparedPrintImage
    ) -> PreparedPrintImage {
        let drawable = overlays.filter { !$0.isBlank }
        guard !drawable.isEmpty else { return image }

        return rendering(into: image) { canvas in
            for overlay in drawable {
                switch overlay.kind {
                case .text:  drawText(overlay, in: canvas)
                case .arrow: drawArrow(overlay, in: canvas)
                }
            }
        }
    }

    // MARK: - The pixel buffer

    /// A prepared frame's pixels, wrapped in something drawable.
    ///
    /// Both burners need the same three things — a context the right way up, the
    /// frame's size, and colours that will read against these pixels — and the
    /// last of those depends on the photometric, which is easy to get wrong twice.
    struct Canvas {
        let context: CGContext
        let width: Int
        let height: Int

        /// True for MONOCHROME1, whose maximum value is *black*.
        let isInverted: Bool

        /// True when the frame carries one sample per pixel, so a colour has to
        /// be flattened to a grey before it can be drawn.
        let isGrayscale: Bool

        /// White as these pixels express it.
        var captionForeground: CGColor {
            isGrayscale ? CGColor(gray: isInverted ? 0 : 1, alpha: 1)
                        : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }

        /// The halo colour: the opposite end of the scale.
        var captionShadow: CGColor { background }

        /// The caption colour a style asks for, in these pixels' terms.
        ///
        /// "White" and "black" are what the *film* shows, so on MONOCHROME1 —
        /// whose maximum stored value is black — the forced values flip just
        /// as the automatic ones do.
        func captionForeground(_ choice: PrintAnnotationStyle.Foreground) -> CGColor {
            switch choice {
            case .automatic: return captionForeground
            case .white:
                return isGrayscale ? CGColor(gray: isInverted ? 0 : 1, alpha: 1)
                                   : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            case .black:
                return isGrayscale ? CGColor(gray: isInverted ? 1 : 0, alpha: 1)
                                   : CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            }
        }

        /// The halo for a styled caption: always the far end from the type.
        func captionShadow(_ choice: PrintAnnotationStyle.Foreground) -> CGColor {
            switch choice {
            case .automatic, .white: return captionShadow
            case .black:             return captionForeground
            }
        }

        /// Black as these pixels express it — the fill behind a reserved strip,
        /// and the halo a caption is drawn over.
        var background: CGColor {
            isGrayscale ? CGColor(gray: isInverted ? 1 : 0, alpha: 1)
                        : CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        }

        /// An annotation's colour, as this frame can express it.
        ///
        /// A greyscale frame gets the colour's luminance — the film is being
        /// printed in greys, and a yellow arrow at full luminance is what the
        /// preview showed. On MONOCHROME1 the value is flipped, so a bright
        /// colour stays bright on film.
        func color(for overlay: PrintOverlayColor) -> CGColor {
            guard isGrayscale else {
                return CGColor(red: overlay.red, green: overlay.green,
                               blue: overlay.blue, alpha: 1)
            }
            let value = isInverted ? 1 - overlay.luminance : overlay.luminance
            return CGColor(gray: value, alpha: 1)
        }

        /// The halo drawn behind an annotation so it survives whatever is under
        /// it: the far end of the scale from the annotation itself.
        func halo(for overlay: PrintOverlayColor) -> CGColor {
            let dark = overlay.luminance > 0.45
            if isGrayscale {
                let value = dark ? 0.0 : 1.0
                return CGColor(gray: isInverted ? 1 - value : value, alpha: 1)
            }
            let value = dark ? 0.0 : 1.0
            return CGColor(red: value, green: value, blue: value, alpha: 1)
        }
    }

    /// Runs a drawing pass over a prepared frame's pixels.
    ///
    /// Returns the frame unchanged when there is nothing drawable about it: not
    /// 8-bit, not 1 or 3 samples, or short of the pixels its own descriptor
    /// claims. Refusing quietly is deliberate — an unexpected format is a reason
    /// to print the picture without annotation, never a reason to fail the job or
    /// to write into pixels of a depth this has not been asked to interpret.
    private static func rendering(
        into image: PreparedPrintImage,
        draw: (Canvas) -> Void
    ) -> PreparedPrintImage {
        let descriptor = image.descriptor
        guard descriptor.bitsAllocated == 8,
              descriptor.rows > 0, descriptor.columns > 0 else { return image }

        let width = Int(descriptor.columns)
        let height = Int(descriptor.rows)
        let samples = Int(descriptor.samplesPerPixel)
        guard samples == 1 || samples == 3 else { return image }
        guard descriptor.pixelData.count >= width * height * samples else { return image }

        let isInverted = descriptor.photometricInterpretation.uppercased() == "MONOCHROME1"

        let burned: Data? = samples == 1
            ? drawGrayscale(pixels: descriptor.pixelData, width: width, height: height,
                            inverted: isInverted, draw: draw)
            : drawRGB(pixels: descriptor.pixelData, width: width, height: height,
                      inverted: isInverted, draw: draw)

        guard let burned else { return image }

        return PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: burned,
                rows: descriptor.rows,
                columns: descriptor.columns,
                bitsAllocated: descriptor.bitsAllocated,
                bitsStored: descriptor.bitsStored,
                highBit: descriptor.highBit,
                samplesPerPixel: descriptor.samplesPerPixel,
                pixelRepresentation: descriptor.pixelRepresentation,
                photometricInterpretation: descriptor.photometricInterpretation
            ),
            sourcePath: image.sourcePath,
            frameIndex: image.frameIndex,
            rowSpacingMillimeters: image.rowSpacingMillimeters,
            columnSpacingMillimeters: image.columnSpacingMillimeters
        )
    }

    // MARK: - Grayscale

    private static func drawGrayscale(
        pixels: Data,
        width: Int,
        height: Int,
        inverted: Bool,
        draw: (Canvas) -> Void
    ) -> Data? {
        var bytes = [UInt8](pixels.prefix(width * height))
        guard bytes.count == width * height else { return nil }

        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            draw(Canvas(context: context, width: width, height: height,
                        isInverted: inverted, isGrayscale: true))
            return true
        }
        return drawn ? Data(bytes) : nil
    }

    // MARK: - Colour

    private static func drawRGB(
        pixels: Data,
        width: Int,
        height: Int,
        inverted: Bool,
        draw: (Canvas) -> Void
    ) -> Data? {
        // CoreGraphics has no 24-bit RGB context, so the frame is widened to
        // RGBA for the draw and packed back afterwards. The alpha channel is
        // scratch space and never leaves this function.
        let pixelCount = width * height
        var rgba = [UInt8](repeating: 255, count: pixelCount * 4)
        pixels.withUnsafeBytes { source in
            guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return }
            for index in 0..<pixelCount {
                rgba[index * 4] = base[index * 3]
                rgba[index * 4 + 1] = base[index * 3 + 1]
                rgba[index * 4 + 2] = base[index * 3 + 2]
            }
        }

        let drawn: Bool = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                  ) else { return false }
            draw(Canvas(context: context, width: width, height: height,
                        isInverted: inverted, isGrayscale: false))
            return true
        }
        guard drawn else { return nil }

        var packed = [UInt8](repeating: 0, count: pixelCount * 3)
        for index in 0..<pixelCount {
            packed[index * 3] = rgba[index * 4]
            packed[index * 3 + 1] = rgba[index * 4 + 1]
            packed[index * 3 + 2] = rgba[index * 4 + 2]
        }
        return Data(packed)
    }

    // MARK: - Drawing

    /// Draws one line at a baseline, against the left or the right margin.
    ///
    /// A line too long for the frame is pulled back to the margin rather than
    /// allowed to run off the edge: a patient's name half printed is a name that
    /// can be misread, and the halo makes the overlap survivable.
    private static func drawLine(
        _ text: String,
        in context: CGContext,
        fontSize: Double,
        baseline: Double,
        margin: Double,
        width: Double,
        trailing: Bool,
        foreground: CGColor,
        shadow: CGColor,
        fontFamily: String = "Helvetica"
    ) {
        // Plain, as the preview sets it: one weight for the whole block, because
        // nothing in the corners is a different kind of statement from anything
        // else there. The halo below is what keeps it legible, not the weight.
        // CTFontCreateWithName resolves unknown names to a fallback face, so a
        // bad family degrades to a readable caption rather than to none.
        let font = CTFontCreateWithName(fontFamily as CFString, fontSize, nil)
        context.saveGState()
        context.textMatrix = .identity
        // Drawn twice: a halo at the far end of the scale, then the text — so it
        // survives both a white lung field and a black background.
        let spread = max(1.0, fontSize * 0.08)
        for (offset, color) in [(spread, shadow), (0.0, foreground)] {
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: color
            ]
            guard let attributed = CFAttributedStringCreate(
                nil, text as CFString, attributes as CFDictionary) else { continue }
            let line = CTLineCreateWithAttributedString(attributed)
            let bounds = CTLineGetImageBounds(line, context)
            let x = trailing
                ? max(margin, width - margin - Double(bounds.width))
                : margin
            if offset > 0 {
                for dx in [-offset, 0, offset] {
                    for dy in [-offset, 0, offset] where !(dx == 0 && dy == 0) {
                        context.textPosition = CGPoint(x: x + dx, y: baseline + dy)
                        CTLineDraw(line, context)
                    }
                }
            } else {
                context.textPosition = CGPoint(x: x, y: baseline)
                CTLineDraw(line, context)
            }
        }
        context.restoreGState()
    }

    /// Type size as a fraction of the frame, so a 512² CT and a 3000² CR carry
    /// a caption of the same apparent size.
    static let heightFraction: Double = 0.035
    static let widthFraction: Double = 0.030
    static let minimumFontSize: Double = 9

    /// The size the caption is set at on a frame of these dimensions.
    static func captionFontSize(width: Int, height: Int) -> Double {
        max(minimumFontSize,
            min(Double(height) * heightFraction, Double(width) * widthFraction))
    }

    /// The styled size: the style's own fraction of the frame height when it
    /// sets one (already clamped to the legible range by the style), else the
    /// automatic size. The floor still applies — a fraction of a tiny
    /// thumbnail must not become unreadable type.
    static func captionFontSize(width: Int, height: Int, style: PrintAnnotationStyle) -> Double {
        guard let fraction = style.sizeFraction else {
            return captionFontSize(width: width, height: height)
        }
        return max(minimumFontSize, Double(height) * fraction)
    }

    /// The caption size for a cell, shrunk as one block until the widest line
    /// fits its corner.
    ///
    /// Every line of every corner is set at this one size — the preview does
    /// the same (see `PatientIdentificationOverlayView`), so a long study
    /// description costs the whole block a step of size on screen and on film
    /// alike, instead of shrinking alone and printing the corners in two
    /// sizes. A corner is allotted just under half the frame, the same share
    /// the preview gives it, so the two blocks along an edge cannot collide.
    /// Never below half the base size: past that a line is cut off rather
    /// than dragging the patient's name into illegibility with it.
    static func fittedCaptionFontSize(
        for corners: PrintCornerAnnotation,
        width: Int, height: Int,
        style: PrintAnnotationStyle = .automatic
    ) -> Double {
        let base = captionFontSize(width: width, height: height, style: style)
        let available = Double(width) * 0.48
        guard available > 0 else { return base }
        let font = CTFontCreateWithName(style.fontFamily as CFString, base, nil)
        let widest = corners.allLines.map { line -> Double in
            let attributes: [CFString: Any] = [kCTFontAttributeName: font]
            guard let attributed = CFAttributedStringCreate(
                nil, line as CFString, attributes as CFDictionary) else { return 0 }
            return CTLineGetTypographicBounds(
                CTLineCreateWithAttributedString(attributed), nil, nil, nil)
        }.max() ?? 0
        guard widest > available else { return base }
        return base * max(0.5, available / widest)
    }

    /// How deep a corner block of this many lines is, in pixels — the room the
    /// text takes at the edge it is drawn against.
    static func captionBlockHeight(lineCount: Int, width: Int, height: Int) -> Double {
        guard lineCount > 0 else { return 0 }
        let fontSize = captionFontSize(width: width, height: height)
        return fontSize * (captionMarginFactor + Double(lineCount) * captionLineFactor)
    }

    // Must match the corner layout: a margin off the edge, then one line box per
    // line, running in towards the middle.
    static let captionMarginFactor: Double = 0.6
    static let captionLineFactor: Double = 1.3

    // MARK: - Drawn annotations

    /// A line of the reader's own text, at the point they put it.
    ///
    /// The anchor is the text's top-left, which is where a caret sits when you
    /// click — a baseline anchor would make text appear above the click.
    private static func drawText(_ overlay: PrintOverlayAnnotation, in canvas: Canvas) {
        let fontSize = max(Self.minimumFontSize, Double(canvas.height) * overlay.scale)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let x = overlay.start.x * Double(canvas.width)
        // Fractions run top-down, a bitmap context runs bottom-up, and the anchor
        // is the top of the type — so the baseline sits one ascent lower.
        let ascent = CTFontGetAscent(font)
        let y = Double(canvas.height) * (1 - overlay.start.y) - ascent

        canvas.context.saveGState()
        canvas.context.textMatrix = .identity
        // Drawn twice: a halo, then the text, so it survives both a black
        // background and a white lung field.
        let halo = canvas.halo(for: overlay.color)
        let offset = max(1.0, fontSize * 0.06)
        for (spread, color) in [(offset, halo), (0.0, canvas.color(for: overlay.color))] {
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: color
            ]
            guard let attributed = CFAttributedStringCreate(
                nil, overlay.text as CFString, attributes as CFDictionary) else { continue }
            let line = CTLineCreateWithAttributedString(attributed)
            if spread > 0 {
                for dx in [-spread, 0, spread] {
                    for dy in [-spread, 0, spread] where !(dx == 0 && dy == 0) {
                        canvas.context.textPosition = CGPoint(x: x + dx, y: y + dy)
                        CTLineDraw(line, canvas.context)
                    }
                }
            } else {
                canvas.context.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(line, canvas.context)
            }
        }
        canvas.context.restoreGState()
    }

    /// A straight arrow from tail to head, with a filled head.
    ///
    /// Drawn with a halo underneath for the same reason the text is: an arrow that
    /// crosses from lung into mediastinum has to stay visible in both.
    private static func drawArrow(_ overlay: PrintOverlayAnnotation, in canvas: Canvas) {
        let tail = pixelPoint(overlay.start, in: canvas)
        let head = pixelPoint(overlay.end, in: canvas)
        let dx = head.x - tail.x
        let dy = head.y - tail.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return }

        // Line weight and head size come off the same control as the type size, so
        // one setting makes an annotation heavier or lighter as a whole — and off
        // the shared geometry, so the film matches the preview that was approved.
        let geometry = PrintArrowGeometry(
            scale: overlay.scale, imageHeight: Double(canvas.height), arrowLength: length)
        guard let outline = geometry.outline(
            tail: PrintPlanePoint(x: tail.x, y: tail.y),
            head: PrintPlanePoint(x: head.x, y: head.y)) else { return }

        let shaftEnd = cgPoint(outline.shaftEnd)
        let left = cgPoint(outline.headLeft)
        let right = cgPoint(outline.headRight)

        canvas.context.saveGState()
        canvas.context.setLineCap(.round)
        canvas.context.setLineJoin(.round)

        for (extra, color) in [(geometry.haloWidth, canvas.halo(for: overlay.color)),
                               (0.0, canvas.color(for: overlay.color))] {
            canvas.context.setStrokeColor(color)
            canvas.context.setFillColor(color)
            canvas.context.setLineWidth(geometry.lineWidth + extra)

            canvas.context.beginPath()
            canvas.context.move(to: tail)
            canvas.context.addLine(to: shaftEnd)
            canvas.context.strokePath()

            canvas.context.beginPath()
            canvas.context.move(to: head)
            canvas.context.addLine(to: left)
            canvas.context.addLine(to: right)
            canvas.context.closePath()
            // The halo pass strokes the head outline as well as filling it, which
            // is what widens it into a halo.
            canvas.context.drawPath(using: extra > 0 ? .fillStroke : .fill)
        }
        canvas.context.restoreGState()
    }

    private static func cgPoint(_ point: PrintPlanePoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }

    /// A normalized point in the context's own coordinates, which run bottom-up.
    private static func pixelPoint(_ point: PrintOverlayPoint, in canvas: Canvas) -> CGPoint {
        CGPoint(x: point.x * Double(canvas.width),
                y: Double(canvas.height) * (1 - point.y))
    }
}
#endif
