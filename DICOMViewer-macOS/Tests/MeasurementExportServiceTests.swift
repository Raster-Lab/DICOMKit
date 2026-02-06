// MeasurementExportServiceTests.swift
// DICOMViewer macOS - Tests for Measurement Export Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer

@MainActor
final class MeasurementExportServiceTests: XCTestCase {
    
    var service: MeasurementExportService!
    var testMeasurements: [Measurement]!
    var testStudyInfo: MeasurementExportService.StudyInfo!
    
    override func setUp() async throws {
        service = MeasurementExportService()
        
        // Create test measurements
        testMeasurements = [
            Measurement(
                type: .length,
                points: [ImagePoint(x: 10, y: 10), ImagePoint(x: 50, y: 50)],
                frameIndex: 0,
                pixelSpacing: (row: 0.5, column: 0.5),
                label: "Test Length"
            ),
            Measurement(
                type: .angle,
                points: [
                    ImagePoint(x: 20, y: 20),
                    ImagePoint(x: 40, y: 20),
                    ImagePoint(x: 40, y: 40)
                ],
                frameIndex: 1,
                pixelSpacing: (row: 0.5, column: 0.5),
                label: "Test Angle"
            ),
            Measurement(
                type: .ellipse,
                points: [
                    ImagePoint(x: 30, y: 30),
                    ImagePoint(x: 70, y: 70)
                ],
                frameIndex: 0,
                pixelSpacing: (row: 0.5, column: 0.5)
            )
        ]
        
        testStudyInfo = MeasurementExportService.StudyInfo(
            patientName: "TEST^PATIENT",
            patientID: "12345",
            studyDate: "2024-01-15",
            studyDescription: "Test Study"
        )
    }
    
    override func tearDown() async throws {
        service = nil
        testMeasurements = nil
        testStudyInfo = nil
    }
    
    // MARK: - CSV Export Tests
    
    func testExportToCSV_WithStudyInfo() {
        let csv = service.exportToCSV(testMeasurements, studyInfo: testStudyInfo)
        
        XCTAssertTrue(csv.contains("# Study Information"))
        XCTAssertTrue(csv.contains("# Patient Name: TEST^PATIENT"))
        XCTAssertTrue(csv.contains("# Patient ID: 12345"))
        XCTAssertTrue(csv.contains("# Study Date: 2024-01-15"))
        XCTAssertTrue(csv.contains("# Study Description: Test Study"))
    }
    
    func testExportToCSV_WithoutStudyInfo() {
        let csv = service.exportToCSV(testMeasurements, studyInfo: nil)
        
        XCTAssertFalse(csv.contains("# Study Information"))
        XCTAssertTrue(csv.contains("ID,Type,Frame,Length (mm)"))
    }
    
    func testExportToCSV_ContainsHeader() {
        let csv = service.exportToCSV(testMeasurements)
        
        XCTAssertTrue(csv.contains("ID,Type,Frame,Length (mm),Angle (deg),Area (mm²)"))
        XCTAssertTrue(csv.contains("Label,Created At"))
    }
    
    func testExportToCSV_ContainsMeasurementData() {
        let csv = service.exportToCSV(testMeasurements)
        
        XCTAssertTrue(csv.contains("length"))
        XCTAssertTrue(csv.contains("angle"))
        XCTAssertTrue(csv.contains("ellipse"))
        XCTAssertTrue(csv.contains("Test Length"))
        XCTAssertTrue(csv.contains("Test Angle"))
    }
    
    func testExportToCSV_CorrectNumberOfRows() {
        let csv = service.exportToCSV(testMeasurements)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        // Header + 3 measurements
        XCTAssertEqual(lines.count, 4)
    }
    
    // MARK: - JSON Export Tests
    
    func testExportToJSON_ValidFormat() throws {
        let jsonData = try service.exportToJSON(testMeasurements, studyInfo: testStudyInfo)
        
        XCTAssertFalse(jsonData.isEmpty)
        
        // Decode to verify structure
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(MeasurementExportService.ExportData.self, from: jsonData)
        
        XCTAssertNotNil(exportData.studyInfo)
        XCTAssertEqual(exportData.measurements.count, 3)
        XCTAssertEqual(exportData.version, "1.0")
    }
    
    func testExportToJSON_ContainsStudyInfo() throws {
        let jsonData = try service.exportToJSON(testMeasurements, studyInfo: testStudyInfo)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("TEST^PATIENT"))
        XCTAssertTrue(jsonString.contains("12345"))
        XCTAssertTrue(jsonString.contains("2024-01-15"))
        XCTAssertTrue(jsonString.contains("Test Study"))
    }
    
    func testExportToJSON_ContainsMeasurements() throws {
        let jsonData = try service.exportToJSON(testMeasurements)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"type\" : \"length\""))
        XCTAssertTrue(jsonString.contains("\"type\" : \"angle\""))
        XCTAssertTrue(jsonString.contains("\"type\" : \"ellipse\""))
        XCTAssertTrue(jsonString.contains("Test Length"))
        XCTAssertTrue(jsonString.contains("Test Angle"))
    }
    
    func testExportToJSON_PrettyPrinted() throws {
        let jsonData = try service.exportToJSON(testMeasurements)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Pretty printed JSON should have line breaks
        XCTAssertTrue(jsonString.contains("\n"))
        XCTAssertTrue(jsonString.contains("  ")) // Indentation
    }
    
    func testExportToJSON_MeasurementStructure() throws {
        let jsonData = try service.exportToJSON(testMeasurements)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(MeasurementExportService.ExportData.self, from: jsonData)
        
        let firstMeasurement = exportData.measurements[0]
        XCTAssertEqual(firstMeasurement.type, "length")
        XCTAssertEqual(firstMeasurement.frameIndex, 0)
        XCTAssertEqual(firstMeasurement.points.count, 2)
        XCTAssertNotNil(firstMeasurement.pixelSpacing)
        XCTAssertNotNil(firstMeasurement.lengthMM)
        XCTAssertNotNil(firstMeasurement.angleInDegrees)
    }
    
    // MARK: - Text Export Tests
    
    func testExportToText_ContainsTitle() {
        let text = service.exportToText(testMeasurements)
        
        XCTAssertTrue(text.contains("DICOM Measurement Report"))
        XCTAssertTrue(text.contains("========================"))
    }
    
    func testExportToText_ContainsStudyInfo() {
        let text = service.exportToText(testMeasurements, studyInfo: testStudyInfo)
        
        XCTAssertTrue(text.contains("Study Information:"))
        XCTAssertTrue(text.contains("Patient Name: TEST^PATIENT"))
        XCTAssertTrue(text.contains("Patient ID: 12345"))
        XCTAssertTrue(text.contains("Study Date: 2024-01-15"))
    }
    
    func testExportToText_ContainsMeasurementCount() {
        let text = service.exportToText(testMeasurements)
        
        XCTAssertTrue(text.contains("Total Measurements: 3"))
    }
    
    func testExportToText_ContainsMeasurementDetails() {
        let text = service.exportToText(testMeasurements)
        
        XCTAssertTrue(text.contains("[1] Length"))
        XCTAssertTrue(text.contains("[2] Angle"))
        XCTAssertTrue(text.contains("[3] Ellipse"))
        XCTAssertTrue(text.contains("Type:"))
        XCTAssertTrue(text.contains("Frame:"))
    }
    
    func testExportToText_EmptyMeasurements() {
        let text = service.exportToText([])
        
        XCTAssertTrue(text.contains("Total Measurements: 0"))
        XCTAssertTrue(text.contains("Measurements:"))
    }
    
    // MARK: - Clipboard Tests
    
    func testExportToClipboard_CSV() throws {
        try service.exportToClipboard(testMeasurements, format: .csv)
        
        let pasteboard = NSPasteboard.general
        let string = pasteboard.string(forType: .string)
        
        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("ID,Type,Frame"))
        XCTAssertTrue(string!.contains("length"))
    }
    
    func testExportToClipboard_JSON() throws {
        try service.exportToClipboard(testMeasurements, format: .json)
        
        let pasteboard = NSPasteboard.general
        let string = pasteboard.string(forType: .string)
        
        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("\"measurements\""))
        XCTAssertTrue(string!.contains("\"version\""))
    }
    
    func testExportToClipboard_Text() throws {
        try service.exportToClipboard(testMeasurements, format: .text)
        
        let pasteboard = NSPasteboard.general
        let string = pasteboard.string(forType: .string)
        
        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("DICOM Measurement Report"))
    }
    
    // MARK: - File Save Tests
    
    func testSaveToFile_CSV() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_measurements.csv")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try service.saveToFile(testMeasurements, format: .csv, url: tempURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("ID,Type,Frame"))
        XCTAssertTrue(content.contains("length"))
    }
    
    func testSaveToFile_JSON() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_measurements.json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try service.saveToFile(testMeasurements, format: .json, url: tempURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        let data = try Data(contentsOf: tempURL)
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }
    
    func testSaveToFile_Text() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_measurements.txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try service.saveToFile(testMeasurements, format: .text, url: tempURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("DICOM Measurement Report"))
    }
    
    // MARK: - Format Tests
    
    func testExportFormat_DisplayNames() {
        XCTAssertEqual(MeasurementExportService.ExportFormat.csv.displayName, "CSV")
        XCTAssertEqual(MeasurementExportService.ExportFormat.json.displayName, "JSON")
        XCTAssertEqual(MeasurementExportService.ExportFormat.text.displayName, "Plain Text")
    }
    
    func testExportFormat_FileExtensions() {
        XCTAssertEqual(MeasurementExportService.ExportFormat.csv.fileExtension, "csv")
        XCTAssertEqual(MeasurementExportService.ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(MeasurementExportService.ExportFormat.text.fileExtension, "txt")
    }
    
    func testExportFormat_AllCases() {
        let formats = MeasurementExportService.ExportFormat.allCases
        XCTAssertEqual(formats.count, 3)
        XCTAssertTrue(formats.contains(.csv))
        XCTAssertTrue(formats.contains(.json))
        XCTAssertTrue(formats.contains(.text))
    }
}
