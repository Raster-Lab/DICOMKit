// MeasurementServiceTests.swift
// DICOMViewer macOS - Measurement Service Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer_macOS

@MainActor
final class MeasurementServiceTests: XCTestCase {
    
    var service: MeasurementService!
    let testInstanceUID = "1.2.3.4.5.test"
    
    override func setUp() async throws {
        service = MeasurementService.shared
        // Clear any existing measurements
        service.clearMeasurements(for: testInstanceUID)
    }
    
    override func tearDown() async throws {
        service.clearMeasurements(for: testInstanceUID)
        service = nil
    }
    
    // MARK: - Add Measurement Tests
    
    func testAddMeasurement() {
        let measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)],
            frameIndex: 0
        )
        
        service.addMeasurement(measurement, for: testInstanceUID)
        
        let retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved.first?.id, measurement.id)
    }
    
    func testAddMultipleMeasurements() {
        let measurement1 = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)],
            frameIndex: 0
        )
        
        let measurement2 = Measurement(
            type: .angle,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 0), ImagePoint(x: 0, y: 1)],
            frameIndex: 0
        )
        
        service.addMeasurement(measurement1, for: testInstanceUID)
        service.addMeasurement(measurement2, for: testInstanceUID)
        
        let retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 2)
    }
    
    // MARK: - Update Measurement Tests
    
    func testUpdateMeasurement() {
        var measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)],
            frameIndex: 0
        )
        
        service.addMeasurement(measurement, for: testInstanceUID)
        
        measurement.label = "Updated Label"
        service.updateMeasurement(measurement, for: testInstanceUID)
        
        let retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.first?.label, "Updated Label")
    }
    
    // MARK: - Remove Measurement Tests
    
    func testRemoveMeasurement() {
        let measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)],
            frameIndex: 0
        )
        
        service.addMeasurement(measurement, for: testInstanceUID)
        XCTAssertEqual(service.getMeasurements(for: testInstanceUID, frameIndex: 0).count, 1)
        
        service.removeMeasurement(id: measurement.id, for: testInstanceUID)
        XCTAssertEqual(service.getMeasurements(for: testInstanceUID, frameIndex: 0).count, 0)
    }
    
    func testClearAllMeasurements() {
        service.addMeasurement(
            Measurement(type: .length, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)], frameIndex: 0),
            for: testInstanceUID
        )
        service.addMeasurement(
            Measurement(type: .angle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 0), ImagePoint(x: 0, y: 1)], frameIndex: 0),
            for: testInstanceUID
        )
        
        XCTAssertEqual(service.getAllMeasurements(for: testInstanceUID).count, 2)
        
        service.clearMeasurements(for: testInstanceUID)
        XCTAssertEqual(service.getAllMeasurements(for: testInstanceUID).count, 0)
    }
    
    // MARK: - Frame Filtering Tests
    
    func testGetMeasurementsForSpecificFrame() {
        service.addMeasurement(
            Measurement(type: .length, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)], frameIndex: 0),
            for: testInstanceUID
        )
        service.addMeasurement(
            Measurement(type: .angle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 0), ImagePoint(x: 0, y: 1)], frameIndex: 1),
            for: testInstanceUID
        )
        service.addMeasurement(
            Measurement(type: .rectangle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 5, y: 5)], frameIndex: 0),
            for: testInstanceUID
        )
        
        let frame0 = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        let frame1 = service.getMeasurements(for: testInstanceUID, frameIndex: 1)
        
        XCTAssertEqual(frame0.count, 2)
        XCTAssertEqual(frame1.count, 1)
    }
    
    // MARK: - Visibility Tests
    
    func testToggleVisibility() {
        let measurement = Measurement(
            type: .length,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)],
            frameIndex: 0
        )
        
        service.addMeasurement(measurement, for: testInstanceUID)
        
        // Initially visible
        var retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertTrue(retrieved.first?.isVisible ?? false)
        
        // Toggle to hidden
        service.toggleVisibility(id: measurement.id, for: testInstanceUID)
        retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 0) // Hidden measurements not returned
        
        // Toggle back to visible
        service.toggleVisibility(id: measurement.id, for: testInstanceUID)
        retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 1)
    }
    
    // MARK: - Active Measurement Tests
    
    func testStartMeasurement() {
        service.startMeasurement(type: .length, frameIndex: 0, pixelSpacing: (0.5, 0.5))
        
        XCTAssertNotNil(service.activeMeasurement)
        XCTAssertEqual(service.activeMeasurement?.type, .length)
        XCTAssertEqual(service.activeMeasurement?.frameIndex, 0)
        XCTAssertEqual(service.activeMeasurement?.pixelSpacing?.row, 0.5)
    }
    
    func testAddPointToActiveMeasurement() {
        service.startMeasurement(type: .length, frameIndex: 0, pixelSpacing: nil)
        
        service.addPoint(ImagePoint(x: 0, y: 0))
        XCTAssertEqual(service.activeMeasurement?.points.count, 1)
        
        service.addPoint(ImagePoint(x: 10, y: 10))
        XCTAssertEqual(service.activeMeasurement?.points.count, 2)
    }
    
    func testFinishValidMeasurement() {
        service.startMeasurement(type: .length, frameIndex: 0, pixelSpacing: nil)
        service.addPoint(ImagePoint(x: 0, y: 0))
        service.addPoint(ImagePoint(x: 10, y: 10))
        
        let finished = service.finishMeasurement(for: testInstanceUID)
        
        XCTAssertNotNil(finished)
        XCTAssertEqual(finished?.points.count, 2)
        XCTAssertNil(service.activeMeasurement)
        
        let retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 1)
    }
    
    func testFinishInvalidMeasurement() {
        service.startMeasurement(type: .length, frameIndex: 0, pixelSpacing: nil)
        service.addPoint(ImagePoint(x: 0, y: 0))
        // Only one point - length needs two
        
        let finished = service.finishMeasurement(for: testInstanceUID)
        
        XCTAssertNil(finished)
        XCTAssertNil(service.activeMeasurement)
        
        let retrieved = service.getMeasurements(for: testInstanceUID, frameIndex: 0)
        XCTAssertEqual(retrieved.count, 0)
    }
    
    func testCancelMeasurement() {
        service.startMeasurement(type: .length, frameIndex: 0, pixelSpacing: nil)
        service.addPoint(ImagePoint(x: 0, y: 0))
        
        XCTAssertNotNil(service.activeMeasurement)
        
        service.cancelMeasurement()
        
        XCTAssertNil(service.activeMeasurement)
    }
    
    // MARK: - Export/Import Tests
    
    func testExportMeasurements() throws {
        service.addMeasurement(
            Measurement(type: .length, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)], frameIndex: 0),
            for: testInstanceUID
        )
        service.addMeasurement(
            Measurement(type: .angle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 0), ImagePoint(x: 0, y: 1)], frameIndex: 0),
            for: testInstanceUID
        )
        
        let data = try service.exportMeasurements(for: testInstanceUID)
        
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertNotNil(json)
    }
    
    func testImportMeasurements() throws {
        let measurements = [
            Measurement(type: .length, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)], frameIndex: 0),
            Measurement(type: .angle, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 0), ImagePoint(x: 0, y: 1)], frameIndex: 0)
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(measurements)
        
        try service.importMeasurements(from: data, for: testInstanceUID)
        
        let retrieved = service.getAllMeasurements(for: testInstanceUID)
        XCTAssertEqual(retrieved.count, 2)
    }
    
    func testRoundTripExportImport() throws {
        service.addMeasurement(
            Measurement(type: .length, points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)], frameIndex: 0, label: "Test"),
            for: testInstanceUID
        )
        
        let originalCount = service.getAllMeasurements(for: testInstanceUID).count
        let data = try service.exportMeasurements(for: testInstanceUID)
        
        service.clearMeasurements(for: testInstanceUID)
        XCTAssertEqual(service.getAllMeasurements(for: testInstanceUID).count, 0)
        
        try service.importMeasurements(from: data, for: testInstanceUID)
        
        let imported = service.getAllMeasurements(for: testInstanceUID)
        XCTAssertEqual(imported.count, originalCount)
        XCTAssertEqual(imported.first?.label, "Test")
    }
}
