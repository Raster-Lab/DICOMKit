// PrintOverlayOrientationTests.swift
// DICOMPrintKitTests
//
// Where a drawn annotation lands, and which way up its words read, once the
// picture has been turned or mirrored.
//
// The property under test throughout is that the three drawers agree: the
// film's burn maps an image-space fraction into the arranged frame, the
// viewer's overlay leaves the anchor alone and cancels only the lettering, and
// the preview maps clicks back the way it maps annotations out. A mapping that
// is right in one direction and not the other is what puts an annotation
// somewhere the reader did not click.

import Testing
import Foundation
@testable import DICOMPrintKit

@Suite("Print Overlay Orientation Tests")
struct PrintOverlayOrientationTests {

    /// A square image with no crop, so only the turn and the mirrors bear.
    private func orientation(
        rotation: Double = 0,
        flipH: Bool = false,
        flipV: Bool = false,
        width: Int = 512,
        height: Int = 512
    ) -> PrintOverlayOrientation {
        PrintOverlayOrientation(
            presentation: ViewerPresentation(
                rotationDegrees: rotation,
                flipHorizontal: flipH,
                flipVertical: flipV),
            imageWidth: width,
            imageHeight: height)
    }

    private func point(_ x: Double, _ y: Double) -> PrintOverlayPoint {
        PrintOverlayPoint(x: x, y: y)
    }

    // MARK: - Where it lands

    @Test("An unarranged picture moves nothing")
    func testIdentity() {
        let mapping = orientation()
        #expect(mapping.isIdentity)
        let landed = mapping.point(point(0.25, 0.75))
        #expect(abs(landed.x - 0.25) < 1e-9)
        #expect(abs(landed.y - 0.75) < 1e-9)
    }

    @Test("A quarter turn takes the top-left corner to the top-right")
    func testQuarterTurn() {
        // Clockwise: what was at the top-left is now at the top-right.
        let landed = orientation(rotation: 90).point(point(0, 0))
        #expect(abs(landed.x - 1) < 1e-9)
        #expect(abs(landed.y - 0) < 1e-9)
    }

    @Test("A half turn takes a corner to the opposite one")
    func testHalfTurn() {
        let landed = orientation(rotation: 180).point(point(0.2, 0.3))
        #expect(abs(landed.x - 0.8) < 1e-9)
        #expect(abs(landed.y - 0.7) < 1e-9)
    }

    @Test("A mirror reflects across the middle, and only on its own axis")
    func testMirrors() {
        let horizontal = orientation(flipH: true).point(point(0.2, 0.3))
        #expect(abs(horizontal.x - 0.8) < 1e-9)
        #expect(abs(horizontal.y - 0.3) < 1e-9)

        let vertical = orientation(flipV: true).point(point(0.2, 0.3))
        #expect(abs(vertical.x - 0.2) < 1e-9)
        #expect(abs(vertical.y - 0.7) < 1e-9)
    }

    @Test("The centre is the one point every arrangement leaves alone")
    func testCentreIsFixed() {
        for rotation in [0.0, 90, 180, 270, 37] {
            for flipH in [false, true] {
                for flipV in [false, true] {
                    let landed = orientation(rotation: rotation, flipH: flipH, flipV: flipV)
                        .point(point(0.5, 0.5))
                    #expect(abs(landed.x - 0.5) < 1e-9)
                    #expect(abs(landed.y - 0.5) < 1e-9)
                }
            }
        }
    }

    // MARK: - The way back

    @Test("A click maps back to the annotation it was made on")
    func testRoundTrip() {
        // Every arrangement, including a free angle and both mirrors together:
        // the preview maps clicks in with the inverse it maps annotations out
        // with, or an annotation lands somewhere other than the pointer.
        for rotation in [0.0, 90, 180, 270, 30, 213.5] {
            for flipH in [false, true] {
                for flipV in [false, true] {
                    let mapping = orientation(rotation: rotation, flipH: flipH, flipV: flipV)
                    let original = point(0.3, 0.6)
                    let landed = mapping.point(original)
                    let back = mapping.imagePoint(x: landed.x, y: landed.y)
                    #expect(abs(back.x - original.x) < 1e-9,
                            "x at \(rotation)° H:\(flipH) V:\(flipV)")
                    #expect(abs(back.y - original.y) < 1e-9,
                            "y at \(rotation)° H:\(flipH) V:\(flipV)")
                }
            }
        }
    }

    @Test("A round trip survives a crop too")
    func testRoundTripThroughACrop() {
        // A zoomed, panned cell: the crop re-bases the fraction, so the inverse
        // has to put the offset back as well as the scale.
        let mapping = PrintOverlayOrientation(
            presentation: ViewerPresentation(
                zoom: 2, panX: 30, panY: -20,
                viewportWidth: 400, viewportHeight: 400,
                rotationDegrees: 90, flipHorizontal: true),
            imageWidth: 512, imageHeight: 512)
        #expect(!mapping.isIdentity)

        let original = point(0.45, 0.55)
        let landed = mapping.point(original)
        let back = mapping.imagePoint(x: landed.x, y: landed.y)
        #expect(abs(back.x - original.x) < 1e-6)
        #expect(abs(back.y - original.y) < 1e-6)
    }

    @Test("A drag on a turned cell moves the annotation the way the hand went")
    func testDeltaFollowsTheHand() {
        // A quarter turn clockwise puts the image's top-left at the top-right,
        // so the image's *downward* axis now runs leftwards across the cell.
        // Dragging right therefore walks the annotation up the image beneath.
        // The check that matters is that it agrees with the forward map:
        // move the annotation by this delta and it lands where the hand went.
        let mapping = orientation(rotation: 90)
        let moved = mapping.imageDelta(dx: 0.1, dy: 0)
        #expect(abs(moved.dx - 0) < 1e-9)
        #expect(abs(moved.dy + 0.1) < 1e-9)

        let before = mapping.point(point(0.4, 0.5))
        let after = mapping.point(point(0.4 + moved.dx, 0.5 + moved.dy))
        #expect(abs((after.x - before.x) - 0.1) < 1e-9)
        #expect(abs(after.y - before.y) < 1e-9)
    }

    @Test("A drag is a delta, so a crop's offset drops out of it")
    func testDeltaIgnoresTheCropOffset() {
        // Only the crop's *scale* bears on a drag: at 2× zoom the crop is half
        // the image, so half a crop-width of drag is a quarter of the image.
        let mapping = PrintOverlayOrientation(
            presentation: ViewerPresentation(
                zoom: 2, panX: 40, panY: 25,
                viewportWidth: 400, viewportHeight: 400),
            imageWidth: 512, imageHeight: 512)
        let moved = mapping.imageDelta(dx: 0.5, dy: 0)
        // The crop is the viewport over the zoom, held inside the image, so it
        // is half the image's width give or take the clamp's rounding — and
        // half a crop of drag is a quarter of the image.
        #expect(abs(moved.dx - 0.25) < 0.01)
        #expect(moved.dx > 0)
        #expect(abs(moved.dy) < 1e-9)
    }

    // MARK: - Which way up the words read

    @Test("Words are turned back by exactly what turned them")
    func testTextAngleCancelsTheTurn() {
        #expect(orientation(rotation: 90).textAngleDegrees == -90)
        #expect(orientation(rotation: 30).textAngleDegrees == -30)
        #expect(orientation().textAngleDegrees == 0)
    }

    @Test("One mirror reverses the sense of a turn, so the cancellation flips")
    func testMirrorReversesTheAngle() {
        // Mirroring a picture turned 30° clockwise leaves the words running
        // 30° the *other* way — un-turning by −30° would double the tilt.
        #expect(orientation(rotation: 30, flipH: true).textAngleDegrees == 30)
        #expect(orientation(rotation: 30, flipV: true).textAngleDegrees == 30)
        // Two mirrors are a half turn, not a mirror: the sign comes back, and
        // the half turn itself has to be taken out here, since `textIsMirrored`
        // rightly declines a pair of flips. Without the 180° a picture flipped
        // both ways read its annotations upside down.
        #expect(orientation(rotation: 30, flipH: true, flipV: true)
            .textAngleDegrees == 150)
        #expect(orientation(flipH: true, flipV: true).textAngleDegrees == 180)
    }

    @Test("Lettering is mirrored back only when the picture actually mirrors it")
    func testTextMirroring() {
        #expect(!orientation().textIsMirrored)
        #expect(orientation(flipH: true).textIsMirrored)
        #expect(orientation(flipV: true).textIsMirrored)
        // Both together are a half turn: upside down, but not written backwards.
        #expect(!orientation(flipH: true, flipV: true).textIsMirrored)
    }

    @Test("Windowing and inversion are not arrangement — they move nothing")
    func testInversionIsNotGeometry() {
        let mapping = PrintOverlayOrientation(
            presentation: ViewerPresentation(invert: true),
            imageWidth: 512, imageHeight: 512)
        #expect(mapping.isIdentity)
        #expect(mapping.textAngleDegrees == 0)
        #expect(!mapping.textIsMirrored)
    }
}
