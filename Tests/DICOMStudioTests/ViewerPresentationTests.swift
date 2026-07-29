// ViewerPresentationTests.swift
// DICOMStudioTests
//
// The viewer's zoom/pan/rotate/flip arrangement, resolved to a region of source
// pixels. This is the geometry the print path crops with, so an error here
// prints the wrong part of the image at the right resolution — the kind of bug
// a visual check misses.

import Testing
import DICOMPrintKit
import Foundation

@Suite("Viewer Presentation Tests")
struct ViewerPresentationTests {

    /// A 1000×1000 image in a 500×500 viewport: fit scale is exactly 0.5.
    private func square(zoom: Double, panX: Double = 0, panY: Double = 0,
                        rotationDegrees: Double = 0) -> ViewerPresentation {
        ViewerPresentation(
            zoom: zoom, panX: panX, panY: panY,
            viewportWidth: 500, viewportHeight: 500,
            rotationDegrees: rotationDegrees)
    }

    // MARK: - No crop

    @Test("Fitted, unpanned image is not cropped")
    func testFittedIsNotCropped() {
        let presentation = square(zoom: 1.0)
        #expect(presentation.visibleRegion(imageWidth: 1000, imageHeight: 1000) == nil)
    }

    @Test("Zooming out shows the whole image, so nothing is cropped")
    func testZoomedOutIsNotCropped() {
        let presentation = square(zoom: 0.4)
        #expect(presentation.visibleRegion(imageWidth: 1000, imageHeight: 1000) == nil)
    }

    @Test("Without a known viewport no crop is applied")
    func testUnknownViewportIsNotCropped() {
        let presentation = ViewerPresentation(zoom: 4.0)
        #expect(presentation.visibleRegion(imageWidth: 1000, imageHeight: 1000) == nil)
    }

    @Test("A mark with no transforms is an identity")
    func testIdentity() {
        #expect(ViewerPresentation().isIdentity)
        #expect(ViewerPresentation(zoom: 2).isIdentity == false)
        #expect(ViewerPresentation(rotationDegrees: 90).isIdentity == false)
        #expect(ViewerPresentation(flipHorizontal: true).isIdentity == false)
        #expect(ViewerPresentation(invert: true).isIdentity == false)
    }

    // MARK: - Zoom

    @Test("2x zoom shows the centre half of the image")
    func testZoomCropsToCentre() throws {
        // fit 0.5 × zoom 2 = scale 1: the 500-point viewport shows 500 pixels.
        let region = try #require(
            square(zoom: 2.0).visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(region == PixelRegion(x: 250, y: 250, width: 500, height: 500))
    }

    @Test("4x zoom shows a quarter of the width, still centred")
    func testDeeperZoom() throws {
        let region = try #require(
            square(zoom: 4.0).visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(region == PixelRegion(x: 375, y: 375, width: 250, height: 250))
    }

    // MARK: - Pan

    @Test("Panning the image right reveals pixels to its left")
    func testPanMovesRegionOppositely() throws {
        // Scale is 1, so a 100-point pan is 100 pixels.
        let region = try #require(
            square(zoom: 2.0, panX: 100).visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(region == PixelRegion(x: 150, y: 250, width: 500, height: 500))
    }

    @Test("Panning past the edge clamps to the image instead of padding it")
    func testPanClampsToImage() throws {
        let region = try #require(
            square(zoom: 2.0, panX: 400).visibleRegion(imageWidth: 1000, imageHeight: 1000))
        // Region would start at -150; film has no "outside the image".
        #expect(region.x == 0)
        #expect(region.width == 350)
        #expect(region.y == 250)
    }

    // MARK: - Rotation

    @Test("A quarter turn swaps the visible region's aspect")
    func testRotationSwapsViewportAxes() throws {
        // Viewport 400 wide × 800 tall over a 1000×1000 image: fit = 0.4.
        let presentation = ViewerPresentation(
            zoom: 2.0, viewportWidth: 400, viewportHeight: 800, rotationDegrees: 90)
        let region = try #require(presentation.visibleRegion(imageWidth: 1000, imageHeight: 1000))
        // Rotated, the tall viewport reads across the image: 800/0.8 wide,
        // 400/0.8 tall.
        #expect(region.width == 1000)   // 1000 wanted, clamped to the image
        #expect(region.height == 500)
    }

    @Test("Rotation is normalized to quarter turns")
    func testQuarterTurnNormalization() {
        #expect(ViewerPresentation.quarterTurns(fromDegrees: 0) == 0)
        #expect(ViewerPresentation.quarterTurns(fromDegrees: 90) == 1)
        #expect(ViewerPresentation.quarterTurns(fromDegrees: 270) == 3)
        #expect(ViewerPresentation.quarterTurns(fromDegrees: 360) == 0)
        #expect(ViewerPresentation.quarterTurns(fromDegrees: 450) == 1)
        #expect(ViewerPresentation.quarterTurns(fromDegrees: -90) == 3)
        #expect(ViewerPresentation.quarterTurns(fromDegrees: .nan) == 0)
    }

    @Test("Pan is un-rotated into image space")
    func testPanIsUnrotated() throws {
        // The pan is applied before the rotation on screen, so a horizontal
        // screen pan moves vertically over a 90°-rotated image.
        let presentation = square(zoom: 2.0, panX: 100, rotationDegrees: 90)
        let region = try #require(presentation.visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(region.x == 250)
        #expect(region.y == 350)
    }

    // MARK: - Flips

    @Test("Flipping does not change which pixels are visible")
    func testFlipsDoNotAffectTheRegion() throws {
        let plain = square(zoom: 2.0, panX: 60, panY: -40)
        var flipped = plain
        flipped.flipHorizontal = true
        flipped.flipVertical = true

        let a = try #require(plain.visibleRegion(imageWidth: 1000, imageHeight: 1000))
        let b = try #require(flipped.visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(a == b, "a mirror of a centred viewport is the same viewport")
    }

    // MARK: - Degenerate input

    @Test("Nonsense geometry is ignored rather than cropping to nothing")
    func testDegenerateInputs() {
        var presentation = square(zoom: 2.0)
        presentation.zoom = 0
        #expect(presentation.visibleRegion(imageWidth: 100, imageHeight: 100) == nil)

        presentation = square(zoom: 2.0)
        presentation.panX = .infinity
        #expect(presentation.visibleRegion(imageWidth: 100, imageHeight: 100) == nil)

        #expect(square(zoom: 2.0).visibleRegion(imageWidth: 0, imageHeight: 0) == nil)
    }
}
