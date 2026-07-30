// ImageAnnotationBurner.swift
// DICOMPrintKit
//
// Burning text into the pixels of a printable frame: the patient caption the
// print path always adds, and whatever the reader drew on the film cell.
//
// A DICOM printer draws annotation from the film box's own annotation boxes,
// which every printer lays out differently and many ignore. Film that must
// carry the patient's name — which is most film — therefore carries it in the
// pixels, exactly where the viewer draws it: two lines across the bottom of the
// image. A drawn arrow could not be expressed as an annotation box at all.
//
// This runs once per image, on the already-prepared 8-bit frame, so the cost is
// one bitmap pass per film cell rather than anything per redraw.

import Foundation
import DICOMNetwork

#if canImport(CoreGraphics)
import CoreGraphics
import CoreText

public enum ImageAnnotationBurner {

    /// Draws lines of text across the bottom of a prepared frame.
    ///
    /// Returns the frame unchanged when there is nothing to draw, or when the
    /// pixels are not 8-bit grayscale or 8-bit RGB — the two formats an image
    /// box is prepared into. Refusing quietly is deliberate: an unexpected
    /// format is a reason to print the picture without a caption, never a reason
    /// to fail the job or to write text into pixels of a depth this has not
    /// been asked to interpret.
    public static func burning(
        _ lines: [String],
        into image: PreparedPrintImage
    ) -> PreparedPrintImage {
        let text = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !text.isEmpty else { return image }

        return rendering(into: image) { canvas in
            // A reserved strip, not a caption laid over the anatomy: text drawn on
            // the picture is exactly where a finding can hide, and the viewer
            // reserves the same band on screen. The picture is scaled into what is
            // left, so the film shows what the preview showed.
            reserveCaptionBand(lineCount: text.count, in: canvas)
            draw(text, in: canvas.context,
                 width: canvas.width, height: canvas.height,
                 foreground: canvas.captionForeground,
                 shadow: canvas.captionShadow)
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
            frameIndex: image.frameIndex
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

    /// Draws the lines centred along the bottom of the context.
    ///
    /// A bitmap context's origin is its bottom-left, and its bottom row is the
    /// last row in memory — which is the bottom of a DICOM image, whose rows run
    /// top to bottom. So drawing at low `y` puts the caption under the anatomy,
    /// not over it.
    private static func draw(
        _ lines: [String],
        in context: CGContext,
        width: Int,
        height: Int,
        foreground: CGColor,
        shadow: CGColor
    ) {
        let fontSize = captionFontSize(width: width, height: height)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let lineHeight = fontSize * 1.3
        let margin = fontSize * 0.5

        context.saveGState()
        context.textMatrix = .identity
        // Lines read top to bottom, so the last one sits lowest.
        for (index, text) in lines.enumerated() {
            let baseline = margin + Double(lines.count - index - 1) * lineHeight
            // A caption has to survive both a white lung field and a black
            // background, so it is drawn twice: a dark halo, then the text.
            for (offset, color) in [(1.0, shadow), (0.0, foreground)] {
                let attributes: [CFString: Any] = [
                    kCTFontAttributeName: font,
                    kCTForegroundColorAttributeName: color
                ]
                guard let attributed = CFAttributedStringCreate(
                    nil, text as CFString, attributes as CFDictionary) else { continue }
                let line = CTLineCreateWithAttributedString(attributed)
                let bounds = CTLineGetImageBounds(line, context)
                let x = max(margin, (Double(width) - Double(bounds.width)) / 2)
                if offset > 0 {
                    // The halo is the same text nudged around the glyphs.
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

    /// How deep the caption's own strip is on a frame of these dimensions.
    ///
    /// Matches what ``draw(_:in:width:height:foreground:shadow:)`` lays out: a
    /// margin, the line boxes, and a margin.
    static func captionBandHeight(lineCount: Int, width: Int, height: Int) -> Double {
        guard lineCount > 0 else { return 0 }
        let fontSize = captionFontSize(width: width, height: height)
        return fontSize * (2 * captionMarginFactor + Double(lineCount) * captionLineFactor)
    }

    /// Clears a strip at the bottom of the frame and scales the picture into what
    /// is left above it.
    ///
    /// Nothing is reserved when the strip would eat a serious fraction of the
    /// image — a tiny frame is better captioned over than shrunk to a stamp — or
    /// when the pixels cannot be snapshotted, in which case the caption is drawn
    /// over the anatomy as it used to be. Both fallbacks keep the name on the
    /// film, which matters more than where it sits.
    private static func reserveCaptionBand(lineCount: Int, in canvas: Canvas) {
        let width = Double(canvas.width)
        let height = Double(canvas.height)
        let band = captionBandHeight(lineCount: lineCount,
                                     width: canvas.width, height: canvas.height)
        guard band > 0, band < height * maximumBandFraction,
              let snapshot = canvas.context.makeImage() else { return }

        let available = height - band
        // Fitted, never stretched: the caption must not cost the picture its
        // aspect ratio, which is a measurement radiologists read off the film.
        let scale = available / height
        let fittedWidth = width * scale

        canvas.context.saveGState()
        canvas.context.setFillColor(canvas.background)
        canvas.context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // The context runs bottom-up, so the band at `y = 0` is the image's last
        // rows — the bottom of the anatomy as it is displayed.
        canvas.context.draw(snapshot,
                            in: CGRect(x: (width - fittedWidth) / 2, y: band,
                                       width: fittedWidth, height: available))
        canvas.context.restoreGState()
    }

    /// Above this the strip is taking too much of the picture to be worth it.
    static let maximumBandFraction: Double = 0.3

    // Must match the caption layout: margin, then one line box per line.
    static let captionMarginFactor: Double = 0.5
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
        // one setting makes an annotation heavier or lighter as a whole.
        let lineWidth = max(1.0, Double(canvas.height) * overlay.scale * 0.18)
        let headLength = max(lineWidth * 3, Double(canvas.height) * overlay.scale * 0.9)
        let headHalfWidth = headLength * 0.45

        let ux = dx / length
        let uy = dy / length
        // The shaft stops where the head begins, or the head's point would sit on
        // a line that already reaches past it.
        let shaftEnd = CGPoint(x: head.x - ux * headLength, y: head.y - uy * headLength)
        let base = shaftEnd
        let left = CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth)
        let right = CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth)

        canvas.context.saveGState()
        canvas.context.setLineCap(.round)
        canvas.context.setLineJoin(.round)

        for (extra, color) in [(max(1.0, lineWidth * 0.8), canvas.halo(for: overlay.color)),
                               (0.0, canvas.color(for: overlay.color))] {
            canvas.context.setStrokeColor(color)
            canvas.context.setFillColor(color)
            canvas.context.setLineWidth(lineWidth + extra)

            canvas.context.beginPath()
            canvas.context.move(to: tail)
            canvas.context.addLine(to: length > headLength ? shaftEnd : head)
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

    /// A normalized point in the context's own coordinates, which run bottom-up.
    private static func pixelPoint(_ point: PrintOverlayPoint, in canvas: Canvas) -> CGPoint {
        CGPoint(x: point.x * Double(canvas.width),
                y: Double(canvas.height) * (1 - point.y))
    }
}
#endif
