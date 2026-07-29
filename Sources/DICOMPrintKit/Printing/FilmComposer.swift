//
// FilmComposer.swift
// DICOMPrintKit
//
// Milestone C of the Print SCP plan: turn a `ReceivedFilm` — film box
// attributes plus its ordered image boxes — into one rasterized sheet.
//
// This is the only genuinely new piece of the emulator: everything upstream is
// protocol handling and everything downstream is a sink.
//
// Reference: PS3.3 C.13.3 (Film Box), C.13.5 (Image Box), C.11.6 (Presentation LUT).
//

import Foundation
import DICOMCore
import DICOMNetwork

#if canImport(CoreGraphics)
import CoreGraphics
import CoreText
#endif

// MARK: - Configuration

/// Tunables for ``FilmComposer``.
public struct FilmComposerConfiguration: Sendable, Hashable {
    /// Rasterization resolution. 300 is print quality; 150 is a fast draft.
    public let dpi: Double

    /// How optical density is interpreted (see ``DensityMapping``).
    public let densityMapping: DensityMapping

    /// Sheet margin in millimetres on all four edges.
    public let marginMillimeters: Double

    /// Gap between adjacent image cells, in millimetres.
    public let cellSpacingMillimeters: Double

    /// Whether to draw Basic Annotation Box text on the sheet.
    public let drawAnnotations: Bool

    /// Whether to draw crop marks when Trim (2010,0140) is YES.
    public let drawTrimMarks: Bool

    /// Safety cap on the composed bitmap's longest side, in pixels.
    ///
    /// A 14×17 in sheet at 300 DPI is ~4200×5100; a hostile or mistaken
    /// Film Size / DPI combination must not be able to allocate unboundedly.
    public let maximumPixelDimension: Int

    public init(
        dpi: Double = 300,
        densityMapping: DensityMapping = .paperDirect,
        marginMillimeters: Double = 5,
        cellSpacingMillimeters: Double = 2,
        drawAnnotations: Bool = true,
        drawTrimMarks: Bool = true,
        maximumPixelDimension: Int = 12000
    ) {
        self.dpi = max(36, min(1200, dpi))
        self.densityMapping = densityMapping
        self.marginMillimeters = max(0, marginMillimeters)
        self.cellSpacingMillimeters = max(0, cellSpacingMillimeters)
        self.drawAnnotations = drawAnnotations
        self.drawTrimMarks = drawTrimMarks
        self.maximumPixelDimension = max(256, maximumPixelDimension)
    }

    /// Print-quality defaults (300 DPI, paper-direct density).
    public static let `default` = FilmComposerConfiguration()

    /// A fast, low-resolution configuration for previews.
    public static let draft = FilmComposerConfiguration(dpi: 150)
}

// MARK: - Errors

/// Failures raised while composing a film.
public enum FilmCompositionError: Error, Sendable, Equatable, CustomStringConvertible {
    /// CoreGraphics is unavailable or the bitmap context could not be created.
    case rasterizerUnavailable
    /// The sheet would exceed ``FilmComposerConfiguration/maximumPixelDimension``.
    case sheetTooLarge(width: Int, height: Int, limit: Int)
    /// An image box carried a photometric interpretation we cannot render.
    case unsupportedPhotometricInterpretation(String)

    public var description: String {
        switch self {
        case .rasterizerUnavailable:
            return "No rasterizer available on this platform"
        case .sheetTooLarge(let width, let height, let limit):
            return "Composed sheet \(width)×\(height) px exceeds the \(limit) px limit"
        case .unsupportedPhotometricInterpretation(let value):
            return "Unsupported Photometric Interpretation: \(value)"
        }
    }
}

// MARK: - Composer

/// Composes a received film into a printable sheet.
///
/// Pure and synchronous: no network, no file system, no global state, so the
/// composition can be golden-tested by hashing the resulting bitmap.
public struct FilmComposer: Sendable {

    public let configuration: FilmComposerConfiguration

    public init(configuration: FilmComposerConfiguration = .default) {
        self.configuration = configuration
    }

    /// Composes one film.
    public func compose(_ film: ReceivedFilm) throws -> ComposedFilm {
        #if canImport(CoreGraphics)
        return try rasterize(film)
        #else
        throw FilmCompositionError.rasterizerUnavailable
        #endif
    }

    // MARK: Sheet setup

    /// The sheet geometry a film will be composed on.
    public func sheet(for film: ReceivedFilm) -> FilmSheet {
        FilmSheet(
            filmSize: film.filmBox.filmSizeID,
            orientation: film.filmBox.filmOrientation,
            dpi: configuration.dpi)
    }

    /// The cell rectangles a film's layout produces.
    public func cells(for film: ReceivedFilm) -> [FilmCell] {
        FilmCellLayout.cells(
            for: PrintImageDisplayFormat.parse(film.filmBox.imageDisplayFormat),
            on: sheet(for: film),
            marginMillimeters: configuration.marginMillimeters,
            spacingMillimeters: configuration.cellSpacingMillimeters)
    }

    #if canImport(CoreGraphics)

    private func rasterize(_ film: ReceivedFilm) throws -> ComposedFilm {
        let sheet = self.sheet(for: film)
        let width = sheet.pixelWidth
        let height = sheet.pixelHeight
        guard max(width, height) <= configuration.maximumPixelDimension else {
            throw FilmCompositionError.sheetTooLarge(
                width: width, height: height, limit: configuration.maximumPixelDimension)
        }

        let isColor = film.imageBoxes.contains { ($0.image?.samplesPerPixel ?? 1) > 1 }
        let samplesPerPixel = isColor ? 3 : 1

        // A bitmap CGContext supports 8 bpp gray, but *not* 24 bpp RGB — colour
        // has to be drawn into a 32 bpp RGBX buffer and compacted afterwards.
        // (A 24 bpp `CGImage` is fine, which is why `ComposedFilm` can still
        // publish tightly packed RGB.)
        let contextSamples = isColor ? 4 : 1
        let contextBytesPerRow = width * contextSamples
        var scratch = Data(count: contextBytesPerRow * height)
        var skipped: [String] = []

        let composed: Bool = try scratch.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: contextBytesPerRow,
                    space: isColor ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: isColor
                        ? CGImageAlphaInfo.noneSkipLast.rawValue
                        : CGImageAlphaInfo.none.rawValue) else { return false }

            try draw(film: film, sheet: sheet, in: context, isColor: isColor, skipped: &skipped)
            return true
        }
        guard composed else { throw FilmCompositionError.rasterizerUnavailable }

        let pixels = isColor
            ? Self.compactRGBX(scratch, width: width, height: height)
            : scratch

        return ComposedFilm(
            info: info(for: film, sheet: sheet, skipped: skipped),
            width: width, height: height,
            samplesPerPixel: samplesPerPixel,
            pixels: pixels)
    }

    /// Drops the unused fourth byte of each RGBX pixel.
    private static func compactRGBX(_ source: Data, width: Int, height: Int) -> Data {
        var output = Data(count: width * height * 3)
        source.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { result in
                guard let src = input.bindMemory(to: UInt8.self).baseAddress,
                      let dst = result.bindMemory(to: UInt8.self).baseAddress else { return }
                for index in 0..<(width * height) {
                    dst[index * 3] = src[index * 4]
                    dst[index * 3 + 1] = src[index * 4 + 1]
                    dst[index * 3 + 2] = src[index * 4 + 2]
                }
            }
        }
        return output
    }

    /// Draws the whole sheet. The context uses CoreGraphics' native
    /// bottom-left origin; cell rectangles are top-left, so every rect is
    /// flipped once, here, rather than by a global transform (which would also
    /// mirror the images and the text).
    private func draw(
        film: ReceivedFilm,
        sheet: FilmSheet,
        in context: CGContext,
        isColor: Bool,
        skipped: inout [String]
    ) throws {
        let sheetHeight = Double(sheet.pixelHeight)
        func flip(_ cell: FilmCell) -> CGRect {
            CGRect(x: cell.x, y: sheetHeight - (cell.y + cell.height),
                   width: cell.width, height: cell.height)
        }

        context.interpolationQuality = interpolation(for: film.filmBox.magnificationType)

        // Border: the sheet's background outside the image cells.
        let border = luminance(
            forDensity: film.filmBox.borderDensity, film: film, default: 0)
        context.setFillColor(gray(border, isColor: isColor))
        context.fill(CGRect(x: 0, y: 0, width: Double(sheet.pixelWidth), height: sheetHeight))

        let emptyDensity = luminance(
            forDensity: film.filmBox.emptyImageDensity, film: film, default: 0)
        let boxesByPosition = Dictionary(
            film.imageBoxes.map { (Int($0.content.imagePosition), $0) },
            uniquingKeysWith: { first, _ in first })

        for cell in cells(for: film) where !cell.isEmpty {
            let destination = flip(cell)
            guard let box = boxesByPosition[cell.position], let image = box.image else {
                // An unfilled box shows Empty Image Density, not the border.
                context.setFillColor(gray(emptyDensity, isColor: isColor))
                context.fill(destination)
                continue
            }

            do {
                try draw(box: box, image: image, film: film, cell: cell,
                         sheet: sheet, in: context, isColor: isColor,
                         emptyDensity: emptyDensity)
            } catch {
                context.setFillColor(gray(emptyDensity, isColor: isColor))
                context.fill(destination)
                skipped.append("position \(cell.position): \(error)")
            }
        }

        if configuration.drawTrimMarks, film.filmBox.trimOption == .yes {
            drawTrimMarks(sheet: sheet, in: context, isColor: isColor, border: border)
        }
        if configuration.drawAnnotations, !film.annotations.isEmpty {
            drawAnnotations(film.annotations, sheet: sheet, in: context,
                            isColor: isColor, background: border)
        }
    }

    /// Draws one image box into its cell.
    private func draw(
        box: ReceivedImageBox,
        image: PrintImageData,
        film: ReceivedFilm,
        cell: FilmCell,
        sheet: FilmSheet,
        in context: CGContext,
        isColor: Bool,
        emptyDensity: Double
    ) throws {
        let invert = shouldInvert(box: box, image: image, film: film)
        guard let cgImage = try makeCGImage(from: image, invert: invert, forceColor: isColor) else {
            throw FilmCompositionError.unsupportedPhotometricInterpretation(
                image.photometricInterpretation)
        }

        let requestedMillimeters = box.content.requestedImageSize
            .flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        let placement = FilmImageFitter.fit(
            imageWidth: Double(image.columns), imageHeight: Double(image.rows),
            in: cell,
            requestedSizeMillimeters: requestedMillimeters,
            behavior: box.content.requestedDecimateCropBehavior,
            sheet: sheet)

        switch placement {
        case .failed(let reason):
            throw FilmCompositionError.unsupportedPhotometricInterpretation(reason)

        case .placed(let destination, let sourceX, let sourceY, let sourceWidth, let sourceHeight):
            let source: CGImage
            if sourceWidth < Double(image.columns) || sourceHeight < Double(image.rows) {
                // CROP: `cropping(to:)` takes image coordinates (origin top-left),
                // which is exactly what the fitter reports.
                guard let cropped = cgImage.cropping(to: CGRect(
                    x: sourceX, y: sourceY, width: sourceWidth, height: sourceHeight)) else {
                    throw FilmCompositionError.rasterizerUnavailable
                }
                source = cropped
            } else {
                source = cgImage
            }

            let sheetHeight = Double(sheet.pixelHeight)
            let rect = CGRect(
                x: destination.x, y: sheetHeight - (destination.y + destination.height),
                width: destination.width, height: destination.height)

            // The unused part of the cell keeps Empty Image Density so a
            // letterboxed image does not show the border colour instead.
            context.saveGState()
            context.setFillColor(gray(emptyDensity, isColor: isColor))
            context.fill(CGRect(
                x: cell.x, y: sheetHeight - (cell.y + cell.height),
                width: cell.width, height: cell.height))
            context.draw(source, in: rect)
            context.restoreGState()
        }
    }

    // MARK: Pixels

    /// Converts an image box's P-Values into an 8-bit `CGImage`.
    private func makeCGImage(
        from image: PrintImageData,
        invert: Bool,
        forceColor: Bool
    ) throws -> CGImage? {
        let width = Int(image.columns), height = Int(image.rows)
        guard width > 0, height > 0 else { return nil }

        let photometric = image.photometricInterpretation
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")).uppercased()
        let isColorSource = image.samplesPerPixel == 3

        var samples: Data
        var samplesPerPixel: Int
        if isColorSource {
            samples = try rgbSamples(from: image, photometric: photometric)
            samplesPerPixel = 3
        } else {
            samples = graySamples(from: image)
            samplesPerPixel = 1
        }

        if invert {
            samples = Data(samples.map { 255 &- $0 })
        }

        // A grayscale box on a colour film has to be widened to RGB so it can
        // share one bitmap context with the colour boxes.
        if forceColor && samplesPerPixel == 1 {
            var rgb = Data(count: samples.count * 3)
            samples.withUnsafeBytes { source in
                rgb.withUnsafeMutableBytes { destination in
                    guard let src = source.bindMemory(to: UInt8.self).baseAddress,
                          let dst = destination.bindMemory(to: UInt8.self).baseAddress else { return }
                    for index in 0..<samples.count {
                        dst[index * 3] = src[index]
                        dst[index * 3 + 1] = src[index]
                        dst[index * 3 + 2] = src[index]
                    }
                }
            }
            samples = rgb
            samplesPerPixel = 3
        }

        guard samples.count >= width * height * samplesPerPixel,
              let provider = CGDataProvider(data: samples as CFData) else { return nil }

        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 8 * samplesPerPixel,
            bytesPerRow: width * samplesPerPixel,
            space: samplesPerPixel == 3 ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// 8-bit grayscale samples, rescaled from Bits Stored and sign-corrected.
    private func graySamples(from image: PrintImageData) -> Data {
        let count = Int(image.rows) * Int(image.columns)
        if image.bitsAllocated == 8 {
            var data = image.pixelData.prefix(count)
            if data.count < count { data.append(contentsOf: repeatElement(0, count: count - data.count)) }
            return Data(data)
        }

        // 16-bit allocated: little-endian P-Values scaled from Bits Stored.
        let stored = max(1, min(16, Int(image.bitsStored)))
        let maximum = Double((1 << stored) - 1)
        let signed = image.pixelRepresentation == 1
        let offset = signed ? Double(1 << (stored - 1)) : 0

        var output = Data(count: count)
        image.pixelData.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                guard let src = raw.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dst = out.bindMemory(to: UInt8.self).baseAddress else { return }
                let available = min(count, raw.count / 2)
                for index in 0..<available {
                    let low = UInt16(src[index * 2])
                    let high = UInt16(src[index * 2 + 1])
                    let raw16 = low | (high << 8)
                    let value = signed
                        ? Double(Int16(bitPattern: raw16)) + offset
                        : Double(raw16)
                    let scaled = (value / maximum) * 255
                    dst[index] = UInt8(max(0, min(255, scaled.rounded())))
                }
            }
        }
        return output
    }

    /// 8-bit interleaved RGB samples for a colour image box.
    ///
    /// Our own SCU converts to RGB before sending, but third-party SCUs do send
    /// YBR — including the 4:2:2 packed form (PS3.5 8.7.4) — so both are handled.
    private func rgbSamples(from image: PrintImageData, photometric: String) throws -> Data {
        let width = Int(image.columns), height = Int(image.rows)
        let pixelCount = width * height
        let source = image.pixelData

        switch photometric {
        case "RGB", "":
            var data = source.prefix(pixelCount * 3)
            if data.count < pixelCount * 3 {
                data.append(contentsOf: repeatElement(0, count: pixelCount * 3 - data.count))
            }
            return Data(data)

        case "YBR_FULL", "YBR_PARTIAL_420", "YBR_ICT", "YBR_RCT":
            guard photometric == "YBR_FULL" else {
                throw FilmCompositionError.unsupportedPhotometricInterpretation(photometric)
            }
            var output = Data(count: pixelCount * 3)
            for index in 0..<pixelCount {
                let base = index * 3
                guard base + 2 < source.count else { break }
                let (r, g, b) = Self.ybrToRGB(
                    y: Double(source[source.startIndex + base]),
                    cb: Double(source[source.startIndex + base + 1]),
                    cr: Double(source[source.startIndex + base + 2]),
                    fullRange: true)
                output[base] = r; output[base + 1] = g; output[base + 2] = b
            }
            return output

        case "YBR_FULL_422", "YBR_PARTIAL_422":
            // Packed: Y1 Y2 Cb Cr per horizontal pixel pair.
            let fullRange = photometric == "YBR_FULL_422"
            var output = Data(count: pixelCount * 3)
            var pixel = 0
            var offset = source.startIndex
            while pixel + 1 < pixelCount, offset + 3 < source.endIndex {
                let y1 = Double(source[offset])
                let y2 = Double(source[offset + 1])
                let cb = Double(source[offset + 2])
                let cr = Double(source[offset + 3])
                let first = Self.ybrToRGB(y: y1, cb: cb, cr: cr, fullRange: fullRange)
                let second = Self.ybrToRGB(y: y2, cb: cb, cr: cr, fullRange: fullRange)
                output[pixel * 3] = first.0
                output[pixel * 3 + 1] = first.1
                output[pixel * 3 + 2] = first.2
                output[(pixel + 1) * 3] = second.0
                output[(pixel + 1) * 3 + 1] = second.1
                output[(pixel + 1) * 3 + 2] = second.2
                pixel += 2
                offset += 4
            }
            return output

        default:
            throw FilmCompositionError.unsupportedPhotometricInterpretation(photometric)
        }
    }

    /// YCbCr → RGB. Full range is the DICOM YBR_FULL convention; partial range
    /// is BT.601 studio swing (Y 16–235, C 16–240).
    static func ybrToRGB(y: Double, cb: Double, cr: Double, fullRange: Bool) -> (UInt8, UInt8, UInt8) {
        let yy: Double, cbb: Double, crr: Double
        if fullRange {
            yy = y; cbb = cb - 128; crr = cr - 128
        } else {
            yy = (y - 16) * (255.0 / 219.0)
            cbb = (cb - 128) * (255.0 / 224.0)
            crr = (cr - 128) * (255.0 / 224.0)
        }
        let r = yy + 1.402 * crr
        let g = yy - 0.344136 * cbb - 0.714136 * crr
        let b = yy + 1.772 * cbb
        func clamp(_ value: Double) -> UInt8 { UInt8(max(0, min(255, value.rounded()))) }
        return (clamp(r), clamp(g), clamp(b))
    }

    // MARK: Density and polarity

    /// Whether an image box's pixels must be inverted before drawing.
    ///
    /// Four independent inversions compose (each flips the sense of the last):
    /// MONOCHROME1 source, Polarity REVERSE, an INVERSE / LIN OD Presentation
    /// LUT shape, and film-emulation density mapping.
    func shouldInvert(box: ReceivedImageBox, image: PrintImageData, film: ReceivedFilm) -> Bool {
        var invert = false
        let photometric = image.photometricInterpretation
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")).uppercased()
        if photometric == "MONOCHROME1" { invert.toggle() }
        if box.content.polarity == .reverse { invert.toggle() }
        switch film.presentationLUTShape {
        case .inverse, .linearOpticalDensity: invert.toggle()
        case .identity, nil: break
        }
        if configuration.densityMapping == .filmEmulation { invert.toggle() }
        return invert
    }

    /// Maps a Border / Empty Image Density value to a luminance in 0...1.
    ///
    /// The attribute is either `BLACK`, `WHITE`, or a numeric optical density in
    /// hundredths (PS3.3 C.13.3), which is interpolated between the film box's
    /// Min and Max Density when both are known.
    func luminance(forDensity value: String, film: ReceivedFilm, default fallback: Double) -> Double {
        let text = value.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")).uppercased()
        switch text {
        case "BLACK": return configuration.densityMapping == .filmEmulation ? 1 : 0
        case "WHITE": return configuration.densityMapping == .filmEmulation ? 0 : 1
        default:
            guard let density = Double(text) else { return fallback }
            let minimum = Double(film.minDensity ?? 20)
            let maximum = Double(film.maxDensity ?? 300)
            guard maximum > minimum else { return fallback }
            // Higher optical density = darker on film.
            let normalized = (density - minimum) / (maximum - minimum)
            let clamped = max(0, min(1, normalized))
            return configuration.densityMapping == .filmEmulation ? clamped : 1 - clamped
        }
    }

    private func gray(_ luminance: Double, isColor: Bool) -> CGColor {
        let value = max(0, min(1, luminance))
        if isColor {
            return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                           components: [value, value, value, 1])
                ?? CGColor(gray: value, alpha: 1)
        }
        return CGColor(gray: value, alpha: 1)
    }

    private func interpolation(for magnification: MagnificationType) -> CGInterpolationQuality {
        switch magnification {
        case .none, .replicate: return .none
        case .bilinear: return .low
        case .cubic: return .high
        }
    }

    // MARK: Decoration

    /// Corner crop marks for Trim = YES.
    private func drawTrimMarks(sheet: FilmSheet, in context: CGContext, isColor: Bool, border: Double) {
        let inset = sheet.pixels(fromMillimeters: 2)
        let length = sheet.pixels(fromMillimeters: 6)
        let width = Double(sheet.pixelWidth), height = Double(sheet.pixelHeight)

        context.saveGState()
        context.setStrokeColor(gray(border > 0.5 ? 0 : 1, isColor: isColor))
        context.setLineWidth(max(1, sheet.pixels(fromMillimeters: 0.3)))
        for (x, y, dx, dy) in [
            (inset, inset, 1.0, 1.0),
            (width - inset, inset, -1.0, 1.0),
            (inset, height - inset, 1.0, -1.0),
            (width - inset, height - inset, -1.0, -1.0)
        ] {
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + dx * length, y: y))
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x, y: y + dy * length))
        }
        context.strokePath()
        context.restoreGState()
    }

    /// Draws Basic Annotation Box text in a strip along the bottom margin.
    ///
    /// A real printer places annotations per its configured Annotation Display
    /// Format; an emulator has no such configuration, so positions are laid out
    /// in order along the bottom of the sheet, which is where film headers
    /// conventionally sit.
    private func drawAnnotations(
        _ annotations: [PrintAnnotation],
        sheet: FilmSheet,
        in context: CGContext,
        isColor: Bool,
        background: Double
    ) {
        let fontSize = max(8, sheet.pixels(fromMillimeters: 3))
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let color = gray(background > 0.5 ? 0 : 1, isColor: isColor)
        let lineHeight = fontSize * 1.3
        let left = sheet.pixels(fromMillimeters: configuration.marginMillimeters)

        context.saveGState()
        context.textMatrix = .identity
        for (index, annotation) in annotations.enumerated() {
            // CoreText attribute keys directly: DICOMPrintKit must not pull in
            // AppKit/UIKit for `NSAttributedString.Key.font`.
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: color
            ]
            let attributed = CFAttributedStringCreate(
                nil, annotation.text as CFString, attributes as CFDictionary)
            guard let attributed else { continue }
            let line = CTLineCreateWithAttributedString(attributed)
            // Stack upwards from the bottom margin, first position lowest.
            context.textPosition = CGPoint(
                x: left,
                y: sheet.pixels(fromMillimeters: 1.5) + Double(annotations.count - index - 1) * lineHeight)
            CTLineDraw(line, context)
        }
        context.restoreGState()
    }

    #endif

    // MARK: Metadata

    /// Builds the metadata payload that travels with the bitmap.
    func info(for film: ReceivedFilm, sheet: FilmSheet, skipped: [String]) -> ComposedFilmInfo {
        let format = PrintImageDisplayFormat.parse(film.filmBox.imageDisplayFormat)
        return ComposedFilmInfo(
            printJobUID: film.printJobUID,
            filmSessionUID: film.filmSession.sopInstanceUID,
            filmBoxUID: film.filmBox.sopInstanceUID,
            callingAETitle: film.callingAETitle,
            receivedAt: film.timestamp,
            filmSize: film.filmBox.filmSizeID.rawValue,
            filmOrientation: film.filmBox.filmOrientation.rawValue,
            imageDisplayFormat: film.filmBox.imageDisplayFormat,
            rows: format.layout.rows,
            columns: format.layout.columns,
            mediumType: film.filmSession.mediumType.rawValue,
            numberOfCopies: film.filmSession.numberOfCopies,
            filmSessionLabel: film.filmSession.filmSessionLabel,
            magnificationType: film.filmBox.magnificationType.rawValue,
            borderDensity: film.filmBox.borderDensity,
            emptyImageDensity: film.filmBox.emptyImageDensity,
            trim: film.filmBox.trimOption.rawValue,
            minDensity: film.minDensity,
            maxDensity: film.maxDensity,
            presentationLUTShape: film.presentationLUTShape?.rawValue,
            annotations: film.annotations.map { "\($0.position): \($0.text)" },
            sheetWidthMillimeters: sheet.widthMillimeters,
            sheetHeightMillimeters: sheet.heightMillimeters,
            dpi: sheet.dpi,
            densityMapping: configuration.densityMapping,
            filledImageBoxCount: film.filledImageBoxes.count,
            imageBoxCount: film.imageBoxes.count,
            skippedImageBoxes: skipped)
    }
}
