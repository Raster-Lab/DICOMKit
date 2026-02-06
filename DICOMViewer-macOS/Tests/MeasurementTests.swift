// MeasurementTests.swift
// DICOMViewer macOS - Measurement Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer_macOS

final class MeasurementTests: XCTestCase {
    
    // MARK: - ImagePoint Tests
    
    func testImagePointInitialization() {
        let point = ImagePoint(x: 10.0, y: 20.0)
        XCTAssertEqual(point.x, 10.0)
        XCTAssertEqual(point.y, 20.0)
    }
    
    func testImagePointCGPointConversion() {
        let cgPoint = CGPoint(x: 15.5, y: 25.5)
        let imagePoint = ImagePoint(cgPoint)
        XCTAssertEqual(imagePoint.x, 15.5)
        XCTAssertEqual(imagePoint.y, 25.5)
        XCTAssertEqual(imagePoint.cgPoint, cgPoint)
    }
    
    func testImagePointDistance() {
        let p1 = ImagePoint(x: 0, y: 0)
        let p2 = ImagePoint(x: 3, y: 4)
        XCTAssertEqual(p1.distance(to: p2), 5.0, accuracy: 0.001)
    }
    
    // MARK: - Length Measurement Tests
    
    func testLengthMeasurementInPixels() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 3, y: 4)
            ]
        )
        
        XCTAssertEqual(measurement.lengthInPixels, 5.0, accuracy: 0.001)
    }
    
    func testLengthMeasurementInMM() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 0)
            ],
            pixelSpacing: (row: 0.5, column: 0.5)
        )
        
        XCTAssertEqual(measurement.lengthInMM, 5.0, accuracy: 0.001)
    }
    
    func testLengthFormattedValue() {
        let measurementWithSpacing = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 0)
            ],
            pixelSpacing: (row: 0.5, column: 0.5)
        )
        
        XCTAssertTrue(measurementWithSpacing.formattedValue.contains("mm"))
        
        let measurementWithoutSpacing = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 0)
            ]
        )
        
        XCTAssertTrue(measurementWithoutSpacing.formattedValue.contains("px"))
    }
    
    // MARK: - Angle Measurement Tests
    
    func testAngleMeasurement90Degrees() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 1, y: 0),  // Right
                ImagePoint(x: 0, y: 0),  // Vertex at origin
                ImagePoint(x: 0, y: 1)   // Up
            ]
        )
        
        XCTAssertEqual(measurement.angleInDegrees, 90.0, accuracy: 0.1)
    }
    
    func testAngleMeasurement180Degrees() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: -1, y: 0),
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 1, y: 0)
            ]
        )
        
        XCTAssertEqual(measurement.angleInDegrees, 180.0, accuracy: 0.1)
    }
    
    func testAngleMeasurement45Degrees() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 1, y: 0),
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 1, y: 1)
            ]
        )
        
        XCTAssertEqual(measurement.angleInDegrees, 45.0, accuracy: 0.1)
    }
    
    // MARK: - Rectangle ROI Tests
    
    func testRectangleArea() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 5)
            ]
        )
        
        XCTAssertEqual(measurement.areaInPixels, 50.0, accuracy: 0.001)
    }
    
    func testRectangleAreaInMM2() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 5)
            ],
            pixelSpacing: (row: 0.5, column: 0.5)
        )
        
        XCTAssertEqual(measurement.areaInMM2, 12.5, accuracy: 0.001)
    }
    
    func testRectanglePerimeter() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 5)
            ]
        )
        
        XCTAssertEqual(measurement.perimeterInPixels, 30.0, accuracy: 0.001)
    }
    
    // MARK: - Ellipse ROI Tests
    
    func testEllipseArea() {
        let measurement = Measurement(
            type: .ellipse,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 6)
            ]
        )
        
        let expectedArea = .pi * 5.0 * 3.0  // π * a * b
        XCTAssertEqual(measurement.areaInPixels, expectedArea, accuracy: 0.001)
    }
    
    func testCircleArea() {
        let measurement = Measurement(
            type: .ellipse,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 10)
            ]
        )
        
        let expectedArea = .pi * 5.0 * 5.0  // π * r²
        XCTAssertEqual(measurement.areaInPixels, expectedArea, accuracy: 0.001)
    }
    
    // MARK: - Polygon ROI Tests
    
    func testTriangleArea() {
        let measurement = Measurement(
            type: .polygon,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 4, y: 0),
                ImagePoint(x: 2, y: 3)
            ]
        )
        
        XCTAssertEqual(measurement.areaInPixels, 6.0, accuracy: 0.001)
    }
    
    func testSquareAreaAsPolygon() {
        let measurement = Measurement(
            type: .polygon,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 5, y: 0),
                ImagePoint(x: 5, y: 5),
                ImagePoint(x: 0, y: 5)
            ]
        )
        
        XCTAssertEqual(measurement.areaInPixels, 25.0, accuracy: 0.001)
    }
    
    func testPolygonPerimeter() {
        let measurement = Measurement(
            type: .polygon,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 4, y: 0),
                ImagePoint(x: 4, y: 3),
                ImagePoint(x: 0, y: 3)
            ]
        )
        
        XCTAssertEqual(measurement.perimeterInPixels, 14.0, accuracy: 0.001)
    }
    
    // MARK: - Measurement Validation Tests
    
    func testIncompleteLengthMeasurement() {
        let measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0)]
        )
        
        XCTAssertNil(measurement.lengthInPixels)
        XCTAssertNil(measurement.lengthInMM)
    }
    
    func testIncompleteAngleMeasurement() {
        let measurement = Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 1, y: 1)
            ]
        )
        
        XCTAssertNil(measurement.angleInDegrees)
    }
    
    func testIncompleteROIMeasurement() {
        let measurement = Measurement(
            type: .rectangle,
            points: [ImagePoint(x: 0, y: 0)]
        )
        
        XCTAssertNil(measurement.areaInPixels)
    }
    
    // MARK: - Measurement Codable Tests
    
    func testMeasurementEncodingDecoding() throws {
        let original = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 0, y: 0),
                ImagePoint(x: 10, y: 10)
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
    
    func testMeasurementArrayEncodingDecoding() throws {
        let measurements = [
            Measurement(type: .length, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)]),
            Measurement(type: .angle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 0), ImagePoint(x: 0, y: 1)]),
            Measurement(type: .rectangle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 5, y: 5)])
        ]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(measurements)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([Measurement].self, from: data)
        
        XCTAssertEqual(decoded.count, measurements.count)
        XCTAssertEqual(decoded[0].type, .length)
        XCTAssertEqual(decoded[1].type, .angle)
        XCTAssertEqual(decoded[2].type, .rectangle)
    }
    
    // MARK: - Measurement Visibility Tests
    
    func testMeasurementVisibility() {
        var measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)]
        )
        
        XCTAssertTrue(measurement.isVisible)
        
        measurement.isVisible = false
        XCTAssertFalse(measurement.isVisible)
    }
    
    // MARK: - Edge Cases
    
    func testZeroLengthMeasurement() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: 5, y: 5),
                ImagePoint(x: 5, y: 5)
            ]
        )
        
        XCTAssertEqual(measurement.lengthInPixels, 0.0, accuracy: 0.001)
    }
    
    func testZeroAreaRectangle() {
        let measurement = Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 5, y: 5),
                ImagePoint(x: 5, y: 5)
            ]
        )
        
        XCTAssertEqual(measurement.areaInPixels, 0.0, accuracy: 0.001)
    }
    
    func testNegativeCoordinates() {
        let measurement = Measurement(
            type: .length,
            points: [
                ImagePoint(x: -5, y: -5),
                ImagePoint(x: 5, y: 5)
            ]
        )
        
        let expectedLength = sqrt(100.0 + 100.0)  // sqrt(10² + 10²)
        XCTAssertEqual(measurement.lengthInPixels, expectedLength, accuracy: 0.001)
    }
}
