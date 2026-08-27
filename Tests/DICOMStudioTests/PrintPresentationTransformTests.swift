// PrintPresentationTransformTests.swift
// DICOMStudioTests
//
// Baking the viewer's arrangement into film pixels. Every operation must be
// exact — cropping selects, rotation and flipping permute, inversion negates —
// so these tests assert pixel values, not just dimensions.

import Testing
import DICOMPrintKit
import DICOMNetwork
import Foundation

@Suite("Print Presentation Transform Tests")
struct PrintPresentationTransformTests {

    // MARK: - Helpers

    /// An 8-bit grayscale image whose pixel values are `row * 10 + column`, so
    /// any permutation is identifiable from the values alone.
    private func grayImage(width: Int, height: Int) -> PrintImageData {
        var bytes = [UInt8]()
        for row in 0..<height {
            for column in 0..<width {
                bytes.append(UInt8(row * 10 + column))
            }
        }
        return PrintImageData(
            pixelData: Data(bytes),
            rows: UInt16(height), columns: UInt16(width),
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME2")
    }

    private func values(_ image: PrintImageData) -> [UInt8] { [UInt8](image.pixelData) }

    /// A uniformly bright image, so "did this pixel get any image at all" is a
    /// question the value alone answers: every real pixel is 200, and anything
    /// the transform could not fill stays 0.
    private func brightImage(width: Int, height: Int) -> PrintImageData {
        PrintImageData(
            pixelData: Data([UInt8](repeating: 200, count: width * height)),
            rows: UInt16(height), columns: UInt16(width),
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME2")
    }

    // MARK: - A turned cell's corners

    @Test("A zoomed, freely turned cell fills its corners from outside the crop")
    func testFreeAngleFillsCornersFromBeyondTheCrop() throws {
        // A 400² frame, zoomed 2× into its middle and turned 30°. The crop the
        // reader composed is the centre 200², and turning that about its centre
        // swings its corners out of the cell — the wedges left behind used to be
        // background, because the crop had been taken before the rotation and
        // the pixels that belong in those wedges had been thrown away with it.
        // They are well inside this frame, so every output pixel must be image.
        let image = brightImage(width: 400, height: 400)
        let presentation = ViewerPresentation(
            zoom: 2.0, viewportWidth: 400, viewportHeight: 400,
            rotationDegrees: 30)
        let result = PrintPresentationTransform.apply(presentation, to: image)

        // The picture keeps the size the crop had: turning must not resize it.
        #expect(abs(Int(result.columns) - 200) <= 2)
        #expect(abs(Int(result.rows) - 200) <= 2)

        // And not one pixel of it is background.
        let pixels = values(result)
        #expect(pixels.allSatisfy { $0 > 0 },
                "every pixel of a turned cell inside a larger frame is image")
        #expect(pixels.contains { $0 > 150 }, "and it is the frame's own brightness")
    }

    @Test("At the frame's edge the wedge stays background — there is nothing to fill it with")
    func testFreeAngleAtTheEdgeKeepsItsBackground() throws {
        // The whole frame, turned: there is no image beyond it to swing in, so
        // the corners are honestly empty. This is the other half of the contract
        // — the fix must widen the crop where the pixels exist, not invent them.
        let image = brightImage(width: 200, height: 200)
        let presentation = ViewerPresentation(
            zoom: 1.0, viewportWidth: 200, viewportHeight: 200,
            rotationDegrees: 45)
        let result = PrintPresentationTransform.apply(presentation, to: image)

        let pixels = values(result)
        #expect(pixels.contains { $0 == 0 },
                "a 45° turn of a whole frame leaves real background at its corners")
    }

    // MARK: - Identity

    @Test("An identity presentation returns the image untouched")
    func testIdentityIsUntouched() {
        let image = grayImage(width: 3, height: 2)
        let result = PrintPresentationTransform.apply(ViewerPresentation(), to: image)
        #expect(result == image)
    }

    // MARK: - Rotation

    @Test("90° clockwise moves the top-left pixel to the top-right")
    func testRotate90() {
        // 0 1 2      20 10 0
        // 10 11 12 → 21 11 1
        //            22 12 2
        let image = grayImage(width: 3, height: 2)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 90), to: image)

        #expect(result.columns == 2, "a quarter turn swaps the axes")
        #expect(result.rows == 3)
        #expect(values(result) == [10, 0, 11, 1, 12, 2])
    }

    @Test("180° reverses the pixel order")
    func testRotate180() {
        let image = grayImage(width: 3, height: 2)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 180), to: image)

        #expect(result.columns == 3)
        #expect(result.rows == 2)
        #expect(values(result) == values(image).reversed())
    }

    @Test("Four quarter turns return the original pixels")
    func testFourTurnsIsIdentity() {
        let image = grayImage(width: 4, height: 3)
        var result = image
        for _ in 0..<4 {
            result = PrintPresentationTransform.apply(
                ViewerPresentation(rotationDegrees: 90), to: result)
        }
        #expect(result == image)
    }

    // MARK: - Flips

    // MARK: - Free angles

    @Test("A free angle is carried to film rather than snapped upright")
    func testFreeAngleIsRotated() {
        // 20° is nobody's quarter turn: before, the film printed this upright.
        let image = grayImage(width: 4, height: 4)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 20), to: image)

        // The box does not grow. The picture turns about its centre at the size
        // it already had and the corners that swing outside are cut — the way
        // the viewer turns one. Growing to the turned bounding box would keep
        // those corners, but the printer fits whatever it is handed into the
        // image box, so the anatomy would land smaller on film for no reason the
        // reader asked for.
        #expect(result.columns == 4)
        #expect(result.rows == 4)
        #expect(result != image, "the pixels are turned, not passed through")
    }

    @Test("A free angle keeps the anatomy's scale — the middle row is still filled")
    func testFreeAngleKeepsScale() {
        // A turn about the centre leaves the centre where it was, whatever the
        // angle: the row through the middle crosses the picture, not background.
        // This is the whole point of not growing the box — the anatomy is drawn
        // at the size it was, rather than shrunk to fit its own turned corners.
        let image = grayImage(width: 9, height: 9)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 30), to: image)

        let pixels = values(result)
        let width = Int(result.columns)
        let middleRow = Int(result.rows) / 2
        let centre = pixels[middleRow * width + width / 2]
        #expect(centre != 0, "the centre of a turned picture is still picture")
    }

    @Test("The corners the turn leaves empty are film background, not smeared edge")
    func testFreeAngleCornersAreBackground() {
        let image = grayImage(width: 8, height: 8)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 45), to: image)

        let pixels = values(result)
        let width = Int(result.columns)
        #expect(pixels[0] == 0, "top-left corner is outside the turned picture")
        #expect(pixels[width - 1] == 0, "and so is the top-right")
        #expect(pixels[pixels.count - 1] == 0)
    }

    @Test("An angle a hair off a quarter turn is still taken exactly")
    func testNearQuarterTurnStaysExact() {
        // The rotate tool emits a float per mouse event; 90° must not become a
        // resampling rotation because it arrived as 90.0000000001.
        let image = grayImage(width: 3, height: 2)
        let exact = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 90), to: image)
        let nearly = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 90 + 1e-9), to: image)

        #expect(values(nearly) == values(exact))
        #expect(nearly.columns == exact.columns)
    }

    @Test("A free angle keeps the rectangle it was given, whatever the angle")
    func testFreeAngleGeometryIsConsistent() {
        // Every angle prints into the same box, so a cell does not change size
        // as it is dragged round — which is what made the rotate tool look
        // wrong on screen: the picture shrank towards 45° and grew back by 90°.
        let image = grayImage(width: 10, height: 10)
        for angle in [15.0, 30, 45, 60, 75] {
            let result = PrintPresentationTransform.apply(
                ViewerPresentation(rotationDegrees: angle), to: image)
            #expect(result.columns == 10, "a \(angle)° turn keeps the width")
            #expect(result.rows == 10, "a \(angle)° turn keeps the height")
        }
    }

    @Test("Horizontal flip mirrors each row")
    func testFlipHorizontal() {
        let image = grayImage(width: 3, height: 2)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(flipHorizontal: true), to: image)
        #expect(values(result) == [2, 1, 0, 12, 11, 10])
    }

    @Test("Vertical flip reverses the row order")
    func testFlipVertical() {
        let image = grayImage(width: 3, height: 2)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(flipVertical: true), to: image)
        #expect(values(result) == [10, 11, 12, 0, 1, 2])
    }

    @Test("Both flips together equal a 180° turn")
    func testBothFlipsEqual180() {
        let image = grayImage(width: 4, height: 3)
        let flipped = PrintPresentationTransform.apply(
            ViewerPresentation(flipHorizontal: true, flipVertical: true), to: image)
        let turned = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 180), to: image)
        #expect(flipped == turned)
    }

    // MARK: - Crop

    @Test("Zoom crops to the visible region at full source resolution")
    func testZoomCrops() {
        // 4×4 image, 400×400 viewport (fit 100), 2× zoom → centre 2×2.
        let image = grayImage(width: 4, height: 4)
        let presentation = ViewerPresentation(
            zoom: 2.0, viewportWidth: 400, viewportHeight: 400)
        let result = PrintPresentationTransform.apply(presentation, to: image)

        #expect(result.columns == 2)
        #expect(result.rows == 2)
        // Rows 1–2, columns 1–2 of the source — original values, not resampled.
        #expect(values(result) == [11, 12, 21, 22])
    }

    @Test("Cropped pixels are the source's own, never interpolated")
    func testCropDoesNotResample() {
        let image = grayImage(width: 8, height: 8)
        let presentation = ViewerPresentation(
            zoom: 4.0, viewportWidth: 800, viewportHeight: 800)
        let result = PrintPresentationTransform.apply(presentation, to: image)

        let source = Set(values(image))
        #expect(values(result).allSatisfy { source.contains($0) })
        #expect(result.columns == 2 && result.rows == 2)
    }

    @Test("Crop and rotation compose: crop first, then permute")
    func testCropThenRotate() {
        let image = grayImage(width: 4, height: 4)
        let presentation = ViewerPresentation(
            zoom: 2.0, viewportWidth: 400, viewportHeight: 400, rotationDegrees: 90)
        let result = PrintPresentationTransform.apply(presentation, to: image)

        #expect(result.columns == 2 && result.rows == 2)
        // The 2×2 crop [11 12 / 21 22] turned 90° clockwise.
        #expect(values(result) == [21, 11, 22, 12])
    }

    // MARK: - Inversion

    @Test("Inversion negates 8-bit P-values")
    func testInvert8Bit() {
        let image = grayImage(width: 3, height: 2)
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(invert: true), to: image)
        #expect(values(result) == values(image).map { 255 - $0 })
    }

    @Test("Inversion negates 16-bit P-values against bits stored")
    func testInvert16Bit() {
        // Two little-endian 12-bit samples: 0 and 4095.
        let image = PrintImageData(
            pixelData: Data([0x00, 0x00, 0xFF, 0x0F]),
            rows: 1, columns: 2,
            bitsAllocated: 16, bitsStored: 12, highBit: 11,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME2")
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(invert: true), to: image)
        #expect([UInt8](result.pixelData) == [0xFF, 0x0F, 0x00, 0x00])
    }

    @Test("Inversion applied twice restores the original")
    func testInvertIsAnInvolution() {
        let image = grayImage(width: 4, height: 4)
        let once = PrintPresentationTransform.apply(ViewerPresentation(invert: true), to: image)
        let twice = PrintPresentationTransform.apply(ViewerPresentation(invert: true), to: once)
        #expect(twice == image)
    }

    // MARK: - Colour

    @Test("RGB pixels are permuted as whole pixels, not split channels")
    func testColorRotation() {
        // 2×1 RGB: red, then green.
        let image = PrintImageData(
            pixelData: Data([255, 0, 0, 0, 255, 0]),
            rows: 1, columns: 2,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 3, pixelRepresentation: 0,
            photometricInterpretation: "RGB")
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(flipHorizontal: true), to: image)
        #expect([UInt8](result.pixelData) == [0, 255, 0, 255, 0, 0])
        #expect(result.samplesPerPixel == 3)
    }

    // MARK: - Safety

    @Test("A truncated buffer is printed untransformed rather than mangled")
    func testTruncatedBufferIsLeftAlone() {
        let image = PrintImageData(
            pixelData: Data([1, 2, 3]),   // 3 bytes for a claimed 4×4
            rows: 4, columns: 4,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME2")
        let result = PrintPresentationTransform.apply(
            ViewerPresentation(rotationDegrees: 90), to: image)
        #expect(result == image)
    }
}
