// MeasurementTests.swift
// DICOMViewer iOS - Measurement Model Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMKit

/// Tests for Measurement model calculations
final class MeasurementTests: XCTestCase {
    
    // MARK: - ImagePoint Tests
    
    func testImagePointDistance() {
        let p1 = ImagePoint(x: 0, y: 0)
        let p2 = ImagePoint(x: 3, y: 4)
        
        XCTAssertEqual(p1.distance(to: p2), 5.0, accuracy: 0.001)
    }
    
    func testImagePointDistanceHorizontal() {
        let p1 = ImagePoint(x: 0, y: 0)
        let p2 = ImagePoint(x: 10, y: 0)
        
        XCTAssertEqual(p1.distance(to: p2), 10.0, accuracy: 0.001)
    }
    
    func testImagePointDistanceVertical() {
        let p1 = ImagePoint(x: 0, y: 0)
        let p2 = ImagePoint(x: 0, y: 10)
        
        XCTAssertEqual(p1.distance(to: p2), 10.0, accuracy: 0.001)
    }
    
    func testImagePointCGPointConversion() {
        let point = ImagePoint(x: 100.5, y: 200.5)
        let cgPoint = point.cgPoint
        
        XCTAssertEqual(cgPoint.x, 100.5)
        XCTAssertEqual(cgPoint.y, 200.5)
    }
    
    // MARK: - Length Measurement Tests
    
    func testLengthMeasurementInPixels() {
        var measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.lengthInPixels, 100.0, accuracy: 0.001)
    }
    
    func testLengthMeasurementInMM() {
        var measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0)
            ],
            frameIndex: 0,
            pixelSpacing: (row: 0.5, column: 0.5)
        )
        
        // 100 pixels * 0.5 mm/pixel = 50 mm
        XCTAssertEqual(measurement.lengthInMM, 50.0, accuracy: 0.001)
    }
    
    func testLengthMeasurementDiagonal() {
        var measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 30, y: 40)
            ],
            frameIndex: 0,
            pixelSpacing: (row: 1.0, column: 1.0)
        )
        
        // sqrt(30^2 + 40^2) = 50
        XCTAssertEqual(measurement.lengthInPixels, 50.0, accuracy: 0.001)
        XCTAssertEqual(measurement.lengthInMM, 50.0, accuracy: 0.001)
    }
    
    func testLengthMeasurementWithAnisotropicPixelSpacing() {
        var measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 100)
            ],
            frameIndex: 0,
            pixelSpacing: (row: 1.0, column: 2.0)
        )
        
        // dx = 100 * 2 = 200, dy = 100 * 1 = 100
        // distance = sqrt(200^2 + 100^2) = sqrt(50000) ≈ 223.6
        let expected = sqrt(200.0 * 200.0 + 100.0 * 100.0)
        XCTAssertEqual(measurement.lengthInMM, expected, accuracy: 0.001)
    }
    
    func testLengthMeasurementNoPixelSpacing() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.lengthInPixels, 100.0, accuracy: 0.001)
        XCTAssertNil(measurement.lengthInMM)
    }
    
    func testLengthMeasurementInsufficientPoints() {
        let measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0)],
            frameIndex: 0
        )
        
        XCTAssertNil(measurement.lengthInPixels)
        XCTAssertNil(measurement.lengthInMM)
    }
    
    // MARK: - Angle Measurement Tests
    
    func testAngleMeasurement90Degrees() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),   // First arm endpoint
                ImagePoint(x: 100, y: 0), // Vertex
                ImagePoint(x: 100, y: 100) // Second arm endpoint
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.angleInDegrees, 90.0, accuracy: 0.001)
    }
    
    func testAngleMeasurement180Degrees() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0),
                ImagePoint(x: 200, y: 0)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.angleInDegrees, 180.0, accuracy: 0.001)
    }
    
    func testAngleMeasurement45Degrees() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0),
                ImagePoint(x: 100, y: 100)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.angleInDegrees, 90.0, accuracy: 0.001)
    }
    
    func testAngleMeasurementInsufficientPoints() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0)
            ],
            frameIndex: 0
        )
        
        XCTAssertNil(measurement.angleInDegrees)
    }
    
    // MARK: - Area Measurement Tests
    
    func testEllipseArea() {
        let measurement = Measurement(
            type: .ellipse,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 50)
            ],
            frameIndex: 0
        )
        
        // Semi-axes: a = 50, b = 25
        // Area = π * a * b = π * 50 * 25 = 3926.99
        let expected = Double.pi * 50.0 * 25.0
        XCTAssertEqual(measurement.areaInPixels, expected, accuracy: 0.001)
    }
    
    func testRectangleArea() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 50)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.areaInPixels, 5000.0, accuracy: 0.001)
    }
    
    func testAreaInMM2() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 100)
            ],
            frameIndex: 0,
            pixelSpacing: (row: 0.5, column: 0.5)
        )
        
        // 10000 pixels² * 0.5 * 0.5 mm² = 2500 mm²
        XCTAssertEqual(measurement.areaInPixels, 10000.0, accuracy: 0.001)
        XCTAssertEqual(measurement.areaInMM2, 2500.0, accuracy: 0.001)
    }
    
    func testFreehandTriangleArea() {
        let measurement = Measurement(
            type: .freehand,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0),
                ImagePoint(x: 50, y: 100)
            ],
            frameIndex: 0
        )
        
        // Triangle with base 100 and height 100
        // Area = 0.5 * 100 * 100 = 5000
        XCTAssertEqual(measurement.areaInPixels, 5000.0, accuracy: 0.001)
    }
    
    // MARK: - Formatted Value Tests
    
    func testFormattedLengthInMM() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0)
            ],
            frameIndex: 0,
            pixelSpacing: (row: 0.5, column: 0.5)
        )
        
        XCTAssertEqual(measurement.formattedValue, "50.0 mm")
    }
    
    func testFormattedLengthInPixels() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.formattedValue, "100.0 px")
    }
    
    func testFormattedAngle() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 0),
                ImagePoint(x: 100, y: 100)
            ],
            frameIndex: 0
        )
        
        XCTAssertEqual(measurement.formattedValue, "90.0°")
    }
    
    func testFormattedAreaInMM2() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 100, y: 100)
            ],
            frameIndex: 0,
            pixelSpacing: (row: 1.0, column: 1.0)
        )
        
        XCTAssertEqual(measurement.formattedValue, "10000.0 mm²")
    }
    
    // MARK: - Codable Tests
    
    func testMeasurementCodable() throws {
        let original = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 10, y: 20),
                ImagePoint(x: 110, y: 120)
            ],
            frameIndex: 5,
            pixelSpacing: (row: 0.5, column: 0.5),
            label: "Test Measurement"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Measurement.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.points.count, original.points.count)
        XCTAssertEqual(decoded.frameIndex, original.frameIndex)
        XCTAssertEqual(decoded.pixelSpacing?.row, original.pixelSpacing?.row)
        XCTAssertEqual(decoded.pixelSpacing?.column, original.pixelSpacing?.column)
        XCTAssertEqual(decoded.label, original.label)
    }
    
    func testMeasurementCodableWithoutPixelSpacing() throws {
        let original = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 50, y: 0),
                ImagePoint(x: 50, y: 50)
            ],
            frameIndex: 0
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Measurement.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertNil(decoded.pixelSpacing)
    }
    
    // MARK: - MeasurementType Tests
    
    func testMeasurementTypeDisplayNames() {
        XCTAssertEqual(MeasurementType.length.displayName, "Length")
        XCTAssertEqual(MeasurementType.angle.displayName, "Angle")
        XCTAssertEqual(MeasurementType.ellipse.displayName, "Ellipse")
        XCTAssertEqual(MeasurementType.rectangle.displayName, "Rectangle")
        XCTAssertEqual(MeasurementType.freehand.displayName, "Freehand")
    }
    
    func testMeasurementTypeSymbolNames() {
        XCTAssertEqual(MeasurementType.length.symbolName, "ruler")
        XCTAssertEqual(MeasurementType.angle.symbolName, "angle")
        XCTAssertEqual(MeasurementType.ellipse.symbolName, "circle.dashed")
        XCTAssertEqual(MeasurementType.rectangle.symbolName, "rectangle.dashed")
        XCTAssertEqual(MeasurementType.freehand.symbolName, "scribble")
    }
}
