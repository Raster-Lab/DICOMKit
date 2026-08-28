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

    @Test("Panning past the edge stops at it, keeping a full viewport of pixels")
    func testPanStopsAtTheEdge() throws {
        let region = try #require(
            square(zoom: 2.0, panX: 400).visibleRegion(imageWidth: 1000, imageHeight: 1000))
        // The pan is held at 250 — the point where the image's edge reaches the
        // viewport — so the region sits on the edge and is still 500 wide. A
        // narrower region would be refitted into the whole image box and the
        // cell would print enlarged, which is not what panning means.
        #expect(region.x == 0)
        #expect(region.width == 500)
        #expect(region.y == 250)
    }

    @Test("A fitted image cannot be cropped by a pan")
    func testPanOnAFittedImageCropsNothing() {
        // Nothing is hidden at fit, so there is nothing a pan could bring in —
        // and a film that cropped here would show an enlarged slice of anatomy
        // for a drag the reader made on screen and thought nothing of.
        #expect(square(zoom: 1.0, panX: 300, panY: -220)
            .visibleRegion(imageWidth: 1000, imageHeight: 1000) == nil)
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

    // MARK: - Free angles

    @Test("The angle survives the round trip instead of snapping to a quarter turn")
    func testFreeAngleIsKept() {
        let presentation = ViewerPresentation(rotationDegrees: 37.5)
        #expect(presentation.rotationDegrees == 37.5)
        #expect(!presentation.isQuarterTurn)
        #expect(presentation.quarterTurns == 0, "the nearest quarter turn is still 0")
    }

    @Test("Angles wrap into [0, 360) and quarter turns stay exact")
    func testAngleNormalisation() {
        #expect(ViewerPresentation(rotationDegrees: -90).rotationDegrees == 270)
        #expect(ViewerPresentation(rotationDegrees: 450).rotationDegrees == 90)

        let quarter = ViewerPresentation(rotationDegrees: 270)
        #expect(quarter.isQuarterTurn)
        #expect(quarter.quarterTurns == 3)
    }

    @Test("A turned rectangle needs the box its corners sweep out")
    func testTurnedSize() {
        let square = ViewerPresentation(rotationDegrees: 45)
        let turned = square.turnedSize(width: 100, height: 100)
        #expect(abs(turned.width - 141.42) < 0.01)
        #expect(abs(turned.height - 141.42) < 0.01)

        // A quarter turn is exact — no floating-point residue from cos(90°).
        let quarter = ViewerPresentation(rotationDegrees: 90)
        let swapped = quarter.turnedSize(width: 300, height: 200)
        #expect(swapped.width == 200)
        #expect(swapped.height == 300)
    }

    @Test("A free angle crops the box the viewport sweeps, not a swapped rectangle")
    func testVisibleRegionAtAFreeAngle() throws {
        // Fit 0.5 × zoom 4 = 2 points per pixel, so the 500-point viewport sees
        // 250 pixels upright. Turned 45° it needs 250·(cos45+sin45) ≈ 354.
        let presentation = square(zoom: 4.0, rotationDegrees: 45)
        let region = try #require(
            presentation.visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(abs(region.width - 354) <= 1)
        #expect(abs(region.height - 354) <= 1)
        #expect(region.x == region.y, "centred, so it is inset equally on both axes")
    }

    // MARK: - Pan limits

    @Test("A fitted image has nothing hidden, so it cannot be panned")
    func testFittedImageCannotPan() {
        let clamped = square(zoom: 1.0).clampedPan(
            x: 200, y: -200, imageWidth: 1000, imageHeight: 1000)
        #expect(clamped.x == 0)
        #expect(clamped.y == 0)
    }

    @Test("A zoomed image pans up to the edge and no further")
    func testPanStopsAtTheImageEdge() {
        // Fit scale 0.5 × zoom 2 = 1, so the 1000-pixel image is 1000 points
        // wide in a 500-point viewport: 250 points hidden either side.
        let presentation = square(zoom: 2.0)
        let inside = presentation.clampedPan(x: 100, y: -80,
                                             imageWidth: 1000, imageHeight: 1000)
        #expect(inside.x == 100, "a pan within the image is left alone")
        #expect(inside.y == -80)

        let beyond = presentation.clampedPan(x: 900, y: -900,
                                             imageWidth: 1000, imageHeight: 1000)
        #expect(beyond.x == 250)
        #expect(beyond.y == -250)
    }

    @Test("The clamped pan is exactly the pan that still crops nothing away")
    func testClampedPanLeavesTheRegionInsideTheImage() throws {
        let presentation = square(zoom: 2.0)
        let clamped = presentation.clampedPan(x: 10_000, y: 0,
                                              imageWidth: 1000, imageHeight: 1000)
        var panned = presentation
        panned.panX = clamped.x
        let region = try #require(
            panned.visibleRegion(imageWidth: 1000, imageHeight: 1000))
        #expect(region.x == 0, "the crop sits on the image's edge…")
        #expect(region.width == 500, "…and is still a full viewport wide")
    }

    @Test("A quarter turn swaps which axis binds the pan")
    func testPanLimitsFollowRotation() {
        // A wide image in a square viewport: fit scale 500/1000 = 0.5, so at
        // zoom 2 the 1000×400 image is 1000×400 points. Nothing is hidden
        // vertically, 250 points are hidden either side horizontally.
        let upright = ViewerPresentation(
            zoom: 2, viewportWidth: 500, viewportHeight: 500)
        let flat = upright.clampedPan(x: 400, y: 400,
                                      imageWidth: 1000, imageHeight: 400)
        #expect(flat.x == 250)
        #expect(flat.y == 0)

        // Turned on its side the same limits apply to the other view axis.
        let turned = ViewerPresentation(
            zoom: 2, viewportWidth: 500, viewportHeight: 500, rotationDegrees: 90)
        let sideways = turned.clampedPan(x: 400, y: 400,
                                         imageWidth: 1000, imageHeight: 400)
        #expect(sideways.x == 0)
        #expect(sideways.y == 250)
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
