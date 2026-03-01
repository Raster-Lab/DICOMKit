// ShutterHelpersTests.swift
// DICOMStudioTests
//
// Tests for ShutterHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ShutterHelpers Rectangular Tests")
struct ShutterRectangularTests {

    @Test("Point inside rectangular shutter")
    func testInside() {
        let shutter = RectangularShutter(top: 50, bottom: 450, left: 50, right: 450)
        #expect(ShutterHelpers.isInsideRectangular(row: 100, column: 100, shutter: shutter))
        #expect(ShutterHelpers.isInsideRectangular(row: 50, column: 50, shutter: shutter))
        #expect(ShutterHelpers.isInsideRectangular(row: 450, column: 450, shutter: shutter))
    }

    @Test("Point outside rectangular shutter")
    func testOutside() {
        let shutter = RectangularShutter(top: 50, bottom: 450, left: 50, right: 450)
        #expect(!ShutterHelpers.isInsideRectangular(row: 0, column: 0, shutter: shutter))
        #expect(!ShutterHelpers.isInsideRectangular(row: 49, column: 100, shutter: shutter))
        #expect(!ShutterHelpers.isInsideRectangular(row: 100, column: 49, shutter: shutter))
    }
}

@Suite("ShutterHelpers Circular Tests")
struct ShutterCircularTests {

    @Test("Point inside circular shutter")
    func testInside() {
        let shutter = CircularShutter(centerRow: 256, centerColumn: 256, radius: 200)
        #expect(ShutterHelpers.isInsideCircular(row: 256, column: 256, shutter: shutter))
        #expect(ShutterHelpers.isInsideCircular(row: 256, column: 456, shutter: shutter))
    }

    @Test("Point outside circular shutter")
    func testOutside() {
        let shutter = CircularShutter(centerRow: 256, centerColumn: 256, radius: 200)
        #expect(!ShutterHelpers.isInsideCircular(row: 0, column: 0, shutter: shutter))
        #expect(!ShutterHelpers.isInsideCircular(row: 256, column: 500, shutter: shutter))
    }
}

@Suite("ShutterHelpers Polygonal Tests")
struct ShutterPolygonalTests {

    @Test("Point inside triangle")
    func testInsideTriangle() {
        let shutter = PolygonalShutter(vertices: [
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 0),
            AnnotationPoint(x: 50, y: 100)
        ])
        #expect(ShutterHelpers.isInsidePolygonal(row: 10, column: 50, shutter: shutter))
    }

    @Test("Point outside triangle")
    func testOutsideTriangle() {
        let shutter = PolygonalShutter(vertices: [
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 0),
            AnnotationPoint(x: 50, y: 100)
        ])
        #expect(!ShutterHelpers.isInsidePolygonal(row: 200, column: 200, shutter: shutter))
    }

    @Test("Point in polygon - square")
    func testInsideSquare() {
        let vertices = [
            AnnotationPoint(x: 0, y: 0),
            AnnotationPoint(x: 100, y: 0),
            AnnotationPoint(x: 100, y: 100),
            AnnotationPoint(x: 0, y: 100)
        ]
        #expect(ShutterHelpers.isPointInPolygon(x: 50, y: 50, vertices: vertices))
        #expect(!ShutterHelpers.isPointInPolygon(x: 200, y: 200, vertices: vertices))
    }
}

@Suite("ShutterHelpers Combined Tests")
struct ShutterCombinedTests {

    @Test("No shutter - pixel always visible")
    func testNoShutter() {
        let model = ShutterModel()
        #expect(ShutterHelpers.isPixelVisible(row: 0, column: 0, shutter: model))
    }

    @Test("Rectangular shutter visibility")
    func testRectVisibility() {
        let model = ShutterModel(
            shapes: [.rectangular],
            rectangular: RectangularShutter(top: 50, bottom: 450, left: 50, right: 450)
        )
        #expect(ShutterHelpers.isPixelVisible(row: 100, column: 100, shutter: model))
        #expect(!ShutterHelpers.isPixelVisible(row: 0, column: 0, shutter: model))
    }

    @Test("Multiple shutters AND together")
    func testMultipleShutters() {
        let model = ShutterModel(
            shapes: [.rectangular, .circular],
            rectangular: RectangularShutter(top: 0, bottom: 512, left: 0, right: 512),
            circular: CircularShutter(centerRow: 256, centerColumn: 256, radius: 100)
        )
        // Center should be visible (inside both)
        #expect(ShutterHelpers.isPixelVisible(row: 256, column: 256, shutter: model))
        // Corner should not be visible (outside circular)
        #expect(!ShutterHelpers.isPixelVisible(row: 0, column: 0, shutter: model))
    }
}

@Suite("ShutterHelpers Validation Tests")
struct ShutterValidationTests {

    @Test("Valid rectangular shutter model")
    func testValidRect() {
        let model = ShutterModel(
            shapes: [.rectangular],
            rectangular: RectangularShutter(top: 50, bottom: 450, left: 50, right: 450)
        )
        #expect(ShutterHelpers.isValid(model))
    }

    @Test("Invalid rectangular shutter model")
    func testInvalidRect() {
        let model = ShutterModel(
            shapes: [.rectangular],
            rectangular: RectangularShutter(top: 450, bottom: 50, left: 50, right: 450)
        )
        #expect(!ShutterHelpers.isValid(model))
    }

    @Test("Missing shutter data is invalid")
    func testMissingData() {
        let model = ShutterModel(shapes: [.rectangular])
        #expect(!ShutterHelpers.isValid(model))
    }
}

@Suite("ShutterHelpers Display Tests")
struct ShutterDisplayTests {

    @Test("Shape labels")
    func testLabels() {
        #expect(ShutterHelpers.shapeLabel(for: .rectangular) == "Rectangular")
        #expect(ShutterHelpers.shapeLabel(for: .circular) == "Circular")
        #expect(ShutterHelpers.shapeLabel(for: .polygonal) == "Polygonal")
        #expect(ShutterHelpers.shapeLabel(for: .bitmap) == "Bitmap")
    }

    @Test("Shutter description")
    func testDescription() {
        let model = ShutterModel(shapes: [.rectangular, .circular])
        #expect(ShutterHelpers.shutterDescription(model) == "Rectangular + Circular")
    }

    @Test("No shutter description")
    func testNoShutterDesc() {
        let model = ShutterModel()
        #expect(ShutterHelpers.shutterDescription(model) == "No shutter")
    }

    @Test("Normalized shutter gray")
    func testNormalizedGray() {
        #expect(ShutterHelpers.normalizedShutterGray(0) == 0.0)
        #expect(ShutterHelpers.normalizedShutterGray(65535) == 1.0)
        #expect(abs(ShutterHelpers.normalizedShutterGray(32768) - 0.5) < 0.01)
    }
}
