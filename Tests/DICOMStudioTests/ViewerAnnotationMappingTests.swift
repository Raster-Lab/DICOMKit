// ViewerAnnotationMappingTests.swift
// DICOMStudioTests
//
// The geometry under the viewer's annotation editing: view point → image
// fraction and back, for both transform orders the viewer draws with. A wrong
// mapping here puts an arrow beside the anatomy the reader aimed at, so
// everything is pinned as arithmetic — forward then inverse must return where
// it started, whatever the picture is doing.

import Testing
import Foundation
import CoreGraphics
@testable import DICOMStudio

@Suite("Viewer Annotation Mapping Tests")
struct ViewerAnnotationMappingTests {

    private let viewSize = CGSize(width: 800, height: 600)
    private let imageWidth = 400
    private let imageHeight = 300

    private func roundTrip(
        x: Double, y: Double,
        zoom: Double = 1, panX: Double = 0, panY: Double = 0,
        rotationDegrees: Double = 0,
        flipHorizontal: Bool = false, flipVertical: Bool = false,
        order: ViewerTransformOrder
    ) -> (x: Double, y: Double)? {
        let viewPoint = ViewerHoverGeometry.viewPoint(
            forNormalizedX: x, y: y,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: zoom, panX: panX, panY: panY,
            rotationDegrees: rotationDegrees,
            flipHorizontal: flipHorizontal, flipVertical: flipVertical,
            order: order)
        return ViewerHoverGeometry.normalizedImagePoint(
            atViewPoint: viewPoint,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: zoom, panX: panX, panY: panY,
            rotationDegrees: rotationDegrees,
            flipHorizontal: flipHorizontal, flipVertical: flipVertical,
            order: order)
    }

    @Test("An untransformed picture maps its centre to the viewport's centre")
    func testIdentityCentre() throws {
        let centre = ViewerHoverGeometry.viewPoint(
            forNormalizedX: 0.5, y: 0.5,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, panX: 0, panY: 0, rotationDegrees: 0,
            flipHorizontal: false, flipVertical: false,
            order: .panAfterRotation)
        #expect(abs(centre.x - 400) < 1e-9)
        #expect(abs(centre.y - 300) < 1e-9)
    }

    @Test("Forward then inverse returns the starting fraction, transformed every way",
          arguments: [ViewerTransformOrder.panBeforeRotation, .panAfterRotation])
    func testRoundTripSurvivesEveryTransform(order: ViewerTransformOrder) throws {
        let cases: [(Double, Double, Double, Double, Double, Double, Bool, Bool)] = [
            // (x, y, zoom, panX, panY, rotation, flipH, flipV)
            (0.25, 0.75, 1, 0, 0, 0, false, false),
            (0.25, 0.75, 2.5, 40, -30, 0, false, false),
            (0.25, 0.75, 1, 0, 0, 90, false, false),
            (0.1, 0.9, 1.7, -25, 60, 30, false, false),
            (0.1, 0.9, 1.7, -25, 60, 0, true, false),
            (0.1, 0.9, 1.7, -25, 60, 213.5, true, true),
            (0.0, 1.0, 3, 100, 100, 45, false, true)
        ]
        for (x, y, zoom, panX, panY, rotation, flipH, flipV) in cases {
            let back = try #require(roundTrip(
                x: x, y: y, zoom: zoom, panX: panX, panY: panY,
                rotationDegrees: rotation,
                flipHorizontal: flipH, flipVertical: flipV, order: order))
            #expect(abs(back.x - x) < 1e-9)
            #expect(abs(back.y - y) < 1e-9)
        }
    }

    @Test("The two transform orders genuinely differ when rotated and panned")
    func testOrdersDisagreeExactlyWhenTheyShould() {
        // Rotated *and* panned: the orders compose differently.
        let a = ViewerHoverGeometry.viewPoint(
            forNormalizedX: 0.25, y: 0.25,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, panX: 50, panY: 0, rotationDegrees: 90,
            flipHorizontal: false, flipVertical: false, order: .panBeforeRotation)
        let b = ViewerHoverGeometry.viewPoint(
            forNormalizedX: 0.25, y: 0.25,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, panX: 50, panY: 0, rotationDegrees: 90,
            flipHorizontal: false, flipVertical: false, order: .panAfterRotation)
        #expect(a != b)
    }

    @Test("A screen drag maps to the image delta that moves an annotation with the pointer")
    func testNormalizedDeltaFollowsThePointer() throws {
        // Turned a quarter clockwise, the image's down-axis points screen-left
        // — so dragging right on screen moves the annotation towards the
        // image's *top* (negative image y).
        let delta = ViewerHoverGeometry.normalizedDelta(
            forViewDelta: CGSize(width: 100, height: 0),
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, rotationDegrees: 90,
            flipHorizontal: false, flipVertical: false,
            order: .panAfterRotation)
        #expect(abs(delta.dx) < 1e-9)
        #expect(delta.dy < 0)

        // Sanity: the moved annotation lands where the pointer went. Forward-map
        // a point, move the fraction by the delta of a screen drag, forward-map
        // again — the screen distance must equal the drag.
        let start = ViewerHoverGeometry.viewPoint(
            forNormalizedX: 0.5, y: 0.5,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, panX: 0, panY: 0, rotationDegrees: 90,
            flipHorizontal: false, flipVertical: false, order: .panAfterRotation)
        let moved = ViewerHoverGeometry.viewPoint(
            forNormalizedX: 0.5 + delta.dx, y: 0.5 + delta.dy,
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, panX: 0, panY: 0, rotationDegrees: 90,
            flipHorizontal: false, flipVertical: false, order: .panAfterRotation)
        #expect(abs((moved.x - start.x) - 100) < 1e-9)
        #expect(abs(moved.y - start.y) < 1e-9)
    }

    @Test("The continuous mapping reports off-picture fractions instead of refusing them")
    func testOffPictureFractionsAreReturned() throws {
        // The 800×600 viewport letterboxes a 400×300 image at fit scale 2 —
        // no margin here, so pan the picture away and click where it was.
        let fraction = try #require(ViewerHoverGeometry.normalizedImagePoint(
            atViewPoint: CGPoint(x: 0, y: 300),
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1, panX: 500, panY: 0, rotationDegrees: 0,
            flipHorizontal: false, flipVertical: false,
            order: .panAfterRotation))
        #expect(fraction.x < 0, "the click missed the picture, and the fraction says by how much")
    }

    @Test("Display scale is the fitted scale times the zoom")
    func testDisplayScale() {
        let scale = ViewerHoverGeometry.displayScale(
            viewSize: viewSize, imageWidth: imageWidth, imageHeight: imageHeight,
            zoom: 1.5)
        // Fit of 400×300 into 800×600 is 2×; zoomed 1.5 → 3.
        #expect(abs(scale - 3) < 1e-9)
    }
}
