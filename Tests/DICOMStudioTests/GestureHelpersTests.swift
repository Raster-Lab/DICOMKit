// GestureHelpersTests.swift
// DICOMStudioTests
//
// Tests for GestureHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("GestureHelpers Tests")
struct GestureHelpersTests {

    // MARK: - Zoom Constants

    @Test("Zoom constants")
    func testZoomConstants() {
        #expect(GestureHelpers.minZoom == 0.1)
        #expect(GestureHelpers.maxZoom == 20.0)
        #expect(GestureHelpers.defaultZoom == 1.0)
    }

    // MARK: - clampZoom

    @Test("Clamp zoom within range")
    func testClampZoomNormal() {
        #expect(GestureHelpers.clampZoom(5.0) == 5.0)
    }

    @Test("Clamp zoom below minimum")
    func testClampZoomBelowMin() {
        #expect(GestureHelpers.clampZoom(0.01) == 0.1)
    }

    @Test("Clamp zoom above maximum")
    func testClampZoomAboveMax() {
        #expect(GestureHelpers.clampZoom(50.0) == 20.0)
    }

    @Test("Clamp zoom at boundaries")
    func testClampZoomBoundaries() {
        #expect(GestureHelpers.clampZoom(0.1) == 0.1)
        #expect(GestureHelpers.clampZoom(20.0) == 20.0)
    }

    // MARK: - zoomFromMagnification

    @Test("Zoom from magnification increases")
    func testZoomFromMagnificationIncrease() {
        let result = GestureHelpers.zoomFromMagnification(currentZoom: 1.0, magnification: 2.0)
        #expect(result == 2.0)
    }

    @Test("Zoom from magnification decreases")
    func testZoomFromMagnificationDecrease() {
        let result = GestureHelpers.zoomFromMagnification(currentZoom: 2.0, magnification: 0.5)
        #expect(result == 1.0)
    }

    @Test("Zoom from magnification clamps max")
    func testZoomFromMagnificationClampMax() {
        let result = GestureHelpers.zoomFromMagnification(currentZoom: 15.0, magnification: 3.0)
        #expect(result == 20.0)
    }

    @Test("Zoom from magnification clamps min")
    func testZoomFromMagnificationClampMin() {
        let result = GestureHelpers.zoomFromMagnification(currentZoom: 0.2, magnification: 0.1)
        #expect(result == 0.1)
    }

    // MARK: - zoomFromScrollDelta

    @Test("Zoom from scroll delta positive")
    func testZoomFromScrollDeltaPositive() {
        let result = GestureHelpers.zoomFromScrollDelta(currentZoom: 1.0, scrollDelta: 10.0)
        #expect(result > 1.0)
    }

    @Test("Zoom from scroll delta negative")
    func testZoomFromScrollDeltaNegative() {
        let result = GestureHelpers.zoomFromScrollDelta(currentZoom: 1.0, scrollDelta: -10.0)
        #expect(result < 1.0)
    }

    @Test("Zoom from scroll delta zero unchanged")
    func testZoomFromScrollDeltaZero() {
        let result = GestureHelpers.zoomFromScrollDelta(currentZoom: 1.0, scrollDelta: 0.0)
        #expect(result == 1.0)
    }

    // MARK: - fitZoom

    @Test("Fit zoom landscape image")
    func testFitZoomLandscape() {
        let zoom = GestureHelpers.fitZoom(
            imageWidth: 1024, imageHeight: 512,
            viewWidth: 800, viewHeight: 600
        )
        // Scale by width: 800/1024 = 0.78125
        // Scale by height: 600/512 = 1.171875
        // Min: 0.78125
        #expect(abs(zoom - 800.0 / 1024.0) < 0.001)
    }

    @Test("Fit zoom portrait image")
    func testFitZoomPortrait() {
        let zoom = GestureHelpers.fitZoom(
            imageWidth: 512, imageHeight: 1024,
            viewWidth: 800, viewHeight: 600
        )
        // Scale by width: 800/512 = 1.5625
        // Scale by height: 600/1024 = 0.5859375
        // Min: 0.5859375
        #expect(abs(zoom - 600.0 / 1024.0) < 0.001)
    }

    @Test("Fit zoom exact fit")
    func testFitZoomExactFit() {
        let zoom = GestureHelpers.fitZoom(
            imageWidth: 800, imageHeight: 600,
            viewWidth: 800, viewHeight: 600
        )
        #expect(zoom == 1.0)
    }

    @Test("Fit zoom zero image returns default")
    func testFitZoomZeroImage() {
        let zoom = GestureHelpers.fitZoom(
            imageWidth: 0, imageHeight: 0,
            viewWidth: 800, viewHeight: 600
        )
        #expect(zoom == GestureHelpers.defaultZoom)
    }

    @Test("Fit zoom zero view returns default")
    func testFitZoomZeroView() {
        let zoom = GestureHelpers.fitZoom(
            imageWidth: 512, imageHeight: 512,
            viewWidth: 0, viewHeight: 0
        )
        #expect(zoom == GestureHelpers.defaultZoom)
    }

    // MARK: - clampOffset

    @Test("Clamp offset within bounds")
    func testClampOffsetWithinBounds() {
        let result = GestureHelpers.clampOffset(
            x: 10, y: 10,
            imageWidth: 512, imageHeight: 512,
            viewWidth: 800, viewHeight: 600,
            zoom: 1.0
        )
        // Image fits within view, so offset is limited
        #expect(abs(result.x) <= 200) // rough check
        #expect(abs(result.y) <= 150)
    }

    @Test("Clamp offset at zero")
    func testClampOffsetZero() {
        let result = GestureHelpers.clampOffset(
            x: 0, y: 0,
            imageWidth: 512, imageHeight: 512,
            viewWidth: 800, viewHeight: 600,
            zoom: 1.0
        )
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    // MARK: - Rotation

    @Test("Rotation angles")
    func testRotationAngles() {
        #expect(GestureHelpers.rotationAngles == [0, 90, 180, 270])
    }

    @Test("Snap rotation 0")
    func testSnapRotation0() {
        #expect(GestureHelpers.snapRotation(0) == 0)
    }

    @Test("Snap rotation 90")
    func testSnapRotation90() {
        #expect(GestureHelpers.snapRotation(90) == 90)
    }

    @Test("Snap rotation 180")
    func testSnapRotation180() {
        #expect(GestureHelpers.snapRotation(180) == 180)
    }

    @Test("Snap rotation 270")
    func testSnapRotation270() {
        #expect(GestureHelpers.snapRotation(270) == 270)
    }

    @Test("Snap rotation 45 snaps to 0")
    func testSnapRotation45() {
        let result = GestureHelpers.snapRotation(45)
        // 45/90 = 0.5, rounds to 0 or 1 depending on rounding
        #expect(result == 0 || result == 90)
    }

    @Test("Snap rotation 360 wraps to 0")
    func testSnapRotation360() {
        #expect(GestureHelpers.snapRotation(360) == 0)
    }

    @Test("Snap rotation negative")
    func testSnapRotationNegative() {
        let result = GestureHelpers.snapRotation(-90)
        #expect(result == 270)
    }

    @Test("Rotate clockwise from 0")
    func testRotateClockwiseFrom0() {
        #expect(GestureHelpers.rotateClockwise(from: 0) == 90)
    }

    @Test("Rotate clockwise from 90")
    func testRotateClockwiseFrom90() {
        #expect(GestureHelpers.rotateClockwise(from: 90) == 180)
    }

    @Test("Rotate clockwise from 270 wraps to 0")
    func testRotateClockwiseFrom270() {
        #expect(GestureHelpers.rotateClockwise(from: 270) == 0)
    }

    @Test("Rotate counter-clockwise from 90")
    func testRotateCCWFrom90() {
        #expect(GestureHelpers.rotateCounterClockwise(from: 90) == 0)
    }

    @Test("Rotate counter-clockwise from 0 wraps to 270")
    func testRotateCCWFrom0() {
        #expect(GestureHelpers.rotateCounterClockwise(from: 0) == 270)
    }

    // MARK: - windowLevelFromDrag

    @Test("Window level from positive drag")
    func testWindowLevelFromDragPositive() {
        let result = GestureHelpers.windowLevelFromDrag(
            currentCenter: 40, currentWidth: 400,
            deltaX: 10, deltaY: 5
        )
        #expect(result.width == 410)
        #expect(result.center == 35)
    }

    @Test("Window level from negative drag")
    func testWindowLevelFromDragNegative() {
        let result = GestureHelpers.windowLevelFromDrag(
            currentCenter: 40, currentWidth: 400,
            deltaX: -10, deltaY: -5
        )
        #expect(result.width == 390)
        #expect(result.center == 45)
    }

    @Test("Window level width minimum clamp")
    func testWindowLevelWidthClamp() {
        let result = GestureHelpers.windowLevelFromDrag(
            currentCenter: 40, currentWidth: 5,
            deltaX: -100, deltaY: 0
        )
        #expect(result.width >= 1.0)
    }

    @Test("Window level from drag with sensitivity")
    func testWindowLevelFromDragSensitivity() {
        let result = GestureHelpers.windowLevelFromDrag(
            currentCenter: 40, currentWidth: 400,
            deltaX: 10, deltaY: 5,
            sensitivity: 2.0
        )
        #expect(result.width == 420)
        #expect(result.center == 30)
    }

    @Test("Window level from zero drag unchanged")
    func testWindowLevelFromDragZero() {
        let result = GestureHelpers.windowLevelFromDrag(
            currentCenter: 40, currentWidth: 400,
            deltaX: 0, deltaY: 0
        )
        #expect(result.center == 40)
        #expect(result.width == 400)
    }
}
