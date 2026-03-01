// AnnotationHelpersTests.swift
// DICOMStudioTests
//
// Tests for AnnotationHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("AnnotationHelpers Validation Tests")
struct AnnotationValidationTests {

    @Test("Valid point annotation")
    func testValidPoint() {
        let annotation = GraphicAnnotation(graphicType: .point, points: [AnnotationPoint(x: 100, y: 100)])
        #expect(AnnotationHelpers.isValid(annotation))
    }

    @Test("Invalid point - no points")
    func testInvalidPoint() {
        let annotation = GraphicAnnotation(graphicType: .point, points: [])
        #expect(!AnnotationHelpers.isValid(annotation))
    }

    @Test("Valid polyline")
    func testValidPolyline() {
        let annotation = GraphicAnnotation(graphicType: .polyline, points: [
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 100)
        ])
        #expect(AnnotationHelpers.isValid(annotation))
    }

    @Test("Invalid polyline - only 1 point")
    func testInvalidPolyline() {
        let annotation = GraphicAnnotation(graphicType: .polyline, points: [AnnotationPoint(x: 0, y: 0)])
        #expect(!AnnotationHelpers.isValid(annotation))
    }

    @Test("Valid circle")
    func testValidCircle() {
        let annotation = GraphicAnnotation(graphicType: .circle, points: [
            AnnotationPoint(x: 256, y: 256),
            AnnotationPoint(x: 356, y: 256)
        ])
        #expect(AnnotationHelpers.isValid(annotation))
    }

    @Test("Valid ellipse")
    func testValidEllipse() {
        let annotation = GraphicAnnotation(graphicType: .ellipse, points: [
            AnnotationPoint(x: 200, y: 256),
            AnnotationPoint(x: 400, y: 256),
            AnnotationPoint(x: 300, y: 200),
            AnnotationPoint(x: 300, y: 312)
        ])
        #expect(AnnotationHelpers.isValid(annotation))
    }
}

@Suite("AnnotationHelpers Circle Tests")
struct AnnotationCircleTests {

    @Test("Circle parameters")
    func testCircleParams() {
        let annotation = GraphicAnnotation(graphicType: .circle, points: [
            AnnotationPoint(x: 256, y: 256),
            AnnotationPoint(x: 356, y: 256)
        ])
        let params = AnnotationHelpers.circleParameters(annotation)
        #expect(params != nil)
        #expect(params?.center.x == 256)
        #expect(params?.center.y == 256)
        #expect(abs((params?.radius ?? 0) - 100) < 0.001)
    }

    @Test("Non-circle annotation returns nil")
    func testNonCircle() {
        let annotation = GraphicAnnotation(graphicType: .point, points: [AnnotationPoint(x: 0, y: 0)])
        #expect(AnnotationHelpers.circleParameters(annotation) == nil)
    }
}

@Suite("AnnotationHelpers Ellipse Tests")
struct AnnotationEllipseTests {

    @Test("Ellipse parameters")
    func testEllipseParams() {
        let annotation = GraphicAnnotation(graphicType: .ellipse, points: [
            AnnotationPoint(x: 100, y: 200),
            AnnotationPoint(x: 300, y: 200),
            AnnotationPoint(x: 200, y: 150),
            AnnotationPoint(x: 200, y: 250)
        ])
        let params = AnnotationHelpers.ellipseParameters(annotation)
        #expect(params != nil)
        #expect(params?.center.x == 200)
        #expect(params?.center.y == 200)
        #expect(abs((params?.semiMajor ?? 0) - 100) < 0.001)
        #expect(abs((params?.semiMinor ?? 0) - 50) < 0.001)
    }
}

@Suite("AnnotationHelpers Distance Tests")
struct AnnotationDistanceTests {

    @Test("Distance between same points is zero")
    func testZeroDistance() {
        let p = AnnotationPoint(x: 100, y: 200)
        #expect(AnnotationHelpers.distance(from: p, to: p) == 0)
    }

    @Test("Horizontal distance")
    func testHorizontalDistance() {
        let a = AnnotationPoint(x: 0, y: 0)
        let b = AnnotationPoint(x: 100, y: 0)
        #expect(AnnotationHelpers.distance(from: a, to: b) == 100)
    }

    @Test("Diagonal distance (3-4-5 triangle)")
    func testDiagonalDistance() {
        let a = AnnotationPoint(x: 0, y: 0)
        let b = AnnotationPoint(x: 3, y: 4)
        #expect(abs(AnnotationHelpers.distance(from: a, to: b) - 5) < 0.001)
    }
}

@Suite("AnnotationHelpers Polyline Tests")
struct AnnotationPolylineTests {

    @Test("Polyline length")
    func testPolylineLength() {
        let annotation = GraphicAnnotation(graphicType: .polyline, points: [
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 0),
            AnnotationPoint(x: 100, y: 100)
        ])
        let length = AnnotationHelpers.polylineLength(annotation)
        #expect(abs((length ?? 0) - 200) < 0.001)
    }

    @Test("Non-polyline returns nil")
    func testNonPolyline() {
        let annotation = GraphicAnnotation(graphicType: .circle, points: [
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 0)
        ])
        #expect(AnnotationHelpers.polylineLength(annotation) == nil)
    }
}

@Suite("AnnotationHelpers BoundingBox Tests")
struct AnnotationBoundingBoxTests {

    @Test("Bounding box of points")
    func testBoundingBox() {
        let points = [
            AnnotationPoint(x: 10, y: 20),
            AnnotationPoint(x: 50, y: 5),
            AnnotationPoint(x: 30, y: 40)
        ]
        let box = AnnotationHelpers.boundingBox(of: points)
        #expect(box?.minX == 10)
        #expect(box?.minY == 5)
        #expect(box?.maxX == 50)
        #expect(box?.maxY == 40)
    }

    @Test("Empty points returns nil")
    func testEmptyBoundingBox() {
        #expect(AnnotationHelpers.boundingBox(of: []) == nil)
    }
}

@Suite("AnnotationHelpers HitTest Tests")
struct AnnotationHitTestTests {

    @Test("Hit test on point annotation")
    func testHitPoint() {
        let annotation = GraphicAnnotation(graphicType: .point, points: [AnnotationPoint(x: 100, y: 100)])
        #expect(AnnotationHelpers.hitTest(point: AnnotationPoint(x: 102, y: 102), annotation: annotation))
        #expect(!AnnotationHelpers.hitTest(point: AnnotationPoint(x: 200, y: 200), annotation: annotation))
    }

    @Test("Hit test on circle border")
    func testHitCircle() {
        let annotation = GraphicAnnotation(graphicType: .circle, points: [
            AnnotationPoint(x: 256, y: 256),
            AnnotationPoint(x: 356, y: 256)
        ])
        // Point on circumference
        #expect(AnnotationHelpers.hitTest(point: AnnotationPoint(x: 356, y: 256), annotation: annotation))
        // Point far from circle
        #expect(!AnnotationHelpers.hitTest(point: AnnotationPoint(x: 0, y: 0), annotation: annotation))
    }
}

@Suite("AnnotationHelpers Text Tests")
struct AnnotationTextTests {

    @Test("Text bounding box size")
    func testTextBBox() {
        let annotation = TextAnnotation(
            text: "Test",
            boundingBoxTopLeft: AnnotationPoint(x: 10, y: 10),
            boundingBoxBottomRight: AnnotationPoint(x: 200, y: 50)
        )
        let size = AnnotationHelpers.textBoundingBoxSize(annotation)
        #expect(size?.width == 190)
        #expect(size?.height == 40)
    }

    @Test("No bounding box returns nil")
    func testNoBBox() {
        let annotation = TextAnnotation(text: "Test")
        #expect(AnnotationHelpers.textBoundingBoxSize(annotation) == nil)
    }
}

@Suite("AnnotationHelpers Display Tests")
struct AnnotationDisplayTests {

    @Test("Graphic type labels")
    func testLabels() {
        #expect(AnnotationHelpers.graphicTypeLabel(for: .point) == "Point")
        #expect(AnnotationHelpers.graphicTypeLabel(for: .polyline) == "Polyline")
        #expect(AnnotationHelpers.graphicTypeLabel(for: .circle) == "Circle")
        #expect(AnnotationHelpers.graphicTypeLabel(for: .ellipse) == "Ellipse")
    }

    @Test("Graphic type system images")
    func testSystemImages() {
        #expect(!AnnotationHelpers.graphicTypeSystemImage(for: .point).isEmpty)
        #expect(!AnnotationHelpers.graphicTypeSystemImage(for: .circle).isEmpty)
    }
}
