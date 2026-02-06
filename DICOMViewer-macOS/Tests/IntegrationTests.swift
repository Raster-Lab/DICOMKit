//
//  IntegrationTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
import SwiftData
import DICOMCore
import DICOMKit
@testable import DICOMViewer

/// Integration tests for end-to-end workflows in DICOMViewer macOS
@MainActor
final class IntegrationTests: XCTestCase {
    var databaseService: DatabaseService!
    var fileImportService: FileImportService!
    var measurementService: MeasurementService!
    var measurementExportService: MeasurementExportService!
    var pdfGenerator: PDFReportGenerator!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        databaseService = DatabaseService.shared
        try databaseService.clearAllData()
        
        fileImportService = FileImportService(databaseService: databaseService)
        measurementService = MeasurementService.shared
        measurementExportService = MeasurementExportService()
        pdfGenerator = PDFReportGenerator()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMViewerTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try databaseService.clearAllData()
        
        // Clean up temp directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    // MARK: - Workflow 1: Import → View → Measure → Export
    
    func testImportViewMeasureExportWorkflow() async throws {
        // Step 1: Create a mock DICOM file
        let testFilePath = try createMockDICOMFile(
            patientName: "Test^Patient",
            patientID: "TEST001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.1",
            instanceUID: "1.2.3.4.5.1.1"
        )
        
        // Step 2: Import the file
        let importProgress = fileImportService.importFiles([testFilePath])
        
        // Wait for import to complete
        for await status in importProgress {
            if status.completed {
                XCTAssertEqual(status.successCount, 1, "Import should succeed")
                XCTAssertEqual(status.failureCount, 0, "No import failures expected")
                break
            }
        }
        
        // Step 3: Verify study was imported
        let studies = try databaseService.fetchAllStudies()
        XCTAssertEqual(studies.count, 1, "Should have one study")
        let study = studies[0]
        XCTAssertEqual(study.patientName, "Test^Patient")
        XCTAssertEqual(study.patientID, "TEST001")
        
        // Step 4: Verify series exists
        XCTAssertEqual(study.series.count, 1, "Should have one series")
        let series = study.series[0]
        
        // Step 5: Verify instance exists
        XCTAssertEqual(series.instances.count, 1, "Should have one instance")
        let instance = series.instances[0]
        
        // Step 6: Create a measurement (simulating user interaction)
        let measurement = Measurement(
            id: UUID(),
            type: .length,
            frameIndex: 0,
            points: [
                ImagePoint(x: 10, y: 10),
                ImagePoint(x: 50, y: 50)
            ],
            label: "Test Measurement",
            pixelSpacing: (0.5, 0.5)
        )
        
        measurementService.addMeasurement(measurement, forInstanceUID: instance.instanceUID)
        
        // Step 7: Export measurements to CSV
        let measurements = measurementService.getMeasurements(forInstanceUID: instance.instanceUID)
        XCTAssertEqual(measurements.count, 1, "Should have one measurement")
        
        let csvData = try measurementExportService.exportToCSV(
            measurements: measurements,
            studyInfo: (
                patientName: study.patientName,
                patientID: study.patientID,
                studyDate: study.studyDate,
                studyDescription: study.studyDescription
            )
        )
        
        XCTAssertFalse(csvData.isEmpty, "CSV export should not be empty")
        let csvString = String(data: csvData, encoding: .utf8)
        XCTAssertNotNil(csvString, "CSV should be valid UTF-8")
        XCTAssertTrue(csvString!.contains("Test^Patient"), "CSV should contain patient name")
        XCTAssertTrue(csvString!.contains("length"), "CSV should contain measurement type")
        
        // Step 8: Export measurements to JSON
        let jsonData = try measurementExportService.exportToJSON(measurements: measurements)
        XCTAssertFalse(jsonData.isEmpty, "JSON export should not be empty")
        
        // Verify JSON structure
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(json, "JSON should be valid")
        XCTAssertEqual(json?["version"] as? String, "1.0", "JSON should have version")
        
        let measurementArray = json?["measurements"] as? [[String: Any]]
        XCTAssertNotNil(measurementArray, "JSON should have measurements array")
        XCTAssertEqual(measurementArray?.count, 1, "Should have one measurement in JSON")
        
        print("✅ Import → View → Measure → Export workflow completed successfully")
    }
    
    func testBatchImportWorkflow() async throws {
        // Create multiple mock DICOM files
        let file1 = try createMockDICOMFile(
            patientName: "Patient^One",
            patientID: "P001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.1",
            instanceUID: "1.2.3.4.5.1.1"
        )
        
        let file2 = try createMockDICOMFile(
            patientName: "Patient^Two",
            patientID: "P002",
            studyUID: "1.2.3.4.6",
            seriesUID: "1.2.3.4.6.1",
            instanceUID: "1.2.3.4.6.1.1"
        )
        
        let file3 = try createMockDICOMFile(
            patientName: "Patient^One",
            patientID: "P001",
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.1",
            instanceUID: "1.2.3.4.5.1.2"
        )
        
        // Import all files
        let importProgress = fileImportService.importFiles([file1, file2, file3])
        
        for await status in importProgress {
            if status.completed {
                XCTAssertEqual(status.successCount, 3, "All imports should succeed")
                XCTAssertEqual(status.failureCount, 0, "No failures expected")
                break
            }
        }
        
        // Verify database state
        let studies = try databaseService.fetchAllStudies()
        XCTAssertEqual(studies.count, 2, "Should have two distinct studies")
        
        // Find Patient One's study (should have 2 instances)
        let patientOneStudy = studies.first { $0.patientID == "P001" }
        XCTAssertNotNil(patientOneStudy, "Patient One's study should exist")
        XCTAssertEqual(patientOneStudy?.series.count, 1, "Should have one series")
        XCTAssertEqual(patientOneStudy?.series.first?.instances.count, 2, "Should have two instances")
        
        print("✅ Batch import workflow completed successfully")
    }
    
    func testMeasurementPersistenceWorkflow() async throws {
        // Create and import a test file
        let testFilePath = try createMockDICOMFile(
            patientName: "Measure^Test",
            patientID: "M001",
            studyUID: "1.2.3.4.7",
            seriesUID: "1.2.3.4.7.1",
            instanceUID: "1.2.3.4.7.1.1"
        )
        
        let importProgress = fileImportService.importFiles([testFilePath])
        for await status in importProgress {
            if status.completed { break }
        }
        
        let studies = try databaseService.fetchAllStudies()
        let instance = studies[0].series[0].instances[0]
        
        // Create multiple measurements
        let lengthMeasurement = Measurement(
            id: UUID(),
            type: .length,
            frameIndex: 0,
            points: [ImagePoint(x: 0, y: 0), ImagePoint(x: 10, y: 10)],
            label: "Length",
            pixelSpacing: (0.5, 0.5)
        )
        
        let angleMeasurement = Measurement(
            id: UUID(),
            type: .angle,
            frameIndex: 0,
            points: [
                ImagePoint(x: 0, y: 10),
                ImagePoint(x: 10, y: 10),
                ImagePoint(x: 20, y: 0)
            ],
            label: "Angle"
        )
        
        let ellipseMeasurement = Measurement(
            id: UUID(),
            type: .ellipse,
            frameIndex: 0,
            points: [ImagePoint(x: 50, y: 50), ImagePoint(x: 70, y: 70)],
            label: "ROI"
        )
        
        // Add all measurements
        measurementService.addMeasurement(lengthMeasurement, forInstanceUID: instance.instanceUID)
        measurementService.addMeasurement(angleMeasurement, forInstanceUID: instance.instanceUID)
        measurementService.addMeasurement(ellipseMeasurement, forInstanceUID: instance.instanceUID)
        
        // Verify measurements were added
        let measurements = measurementService.getMeasurements(forInstanceUID: instance.instanceUID)
        XCTAssertEqual(measurements.count, 3, "Should have three measurements")
        
        // Test filtering by frame
        let frame0Measurements = measurementService.getMeasurements(forInstanceUID: instance.instanceUID, frameIndex: 0)
        XCTAssertEqual(frame0Measurements.count, 3, "All measurements on frame 0")
        
        // Test removal
        measurementService.removeMeasurement(lengthMeasurement.id, forInstanceUID: instance.instanceUID)
        let remainingMeasurements = measurementService.getMeasurements(forInstanceUID: instance.instanceUID)
        XCTAssertEqual(remainingMeasurements.count, 2, "Should have two measurements after removal")
        
        // Test clear all
        measurementService.clearMeasurements(forInstanceUID: instance.instanceUID)
        let clearedMeasurements = measurementService.getMeasurements(forInstanceUID: instance.instanceUID)
        XCTAssertEqual(clearedMeasurements.count, 0, "Should have no measurements after clear")
        
        print("✅ Measurement persistence workflow completed successfully")
    }
    
    // MARK: - Workflow 2: Load → MPR → 3D
    
    func testMPRWorkflow() async throws {
        // Create a mock 3D series with multiple slices
        let studyUID = "1.2.3.4.8"
        let seriesUID = "1.2.3.4.8.1"
        
        let instancePaths = try (0..<10).map { sliceIndex in
            try createMockDICOMFile(
                patientName: "MPR^Test",
                patientID: "MPR001",
                studyUID: studyUID,
                seriesUID: seriesUID,
                instanceUID: "\(seriesUID).\(sliceIndex+1)",
                sliceLocation: Double(sliceIndex * 5)
            )
        }
        
        // Import all slices
        let importProgress = fileImportService.importFiles(instancePaths)
        for await status in importProgress {
            if status.completed {
                XCTAssertEqual(status.successCount, 10, "All 10 slices should import")
                break
            }
        }
        
        // Get the series
        let studies = try databaseService.fetchAllStudies()
        XCTAssertEqual(studies.count, 1, "Should have one study")
        let series = studies[0].series[0]
        XCTAssertEqual(series.instances.count, 10, "Should have 10 instances")
        
        // Create MPR engine and build volume
        let mprEngine = MPREngine()
        
        // Load instance data (in real app, this would load from files)
        let instances: [(instance: DicomInstance, pixelData: Data)] = series.instances.map { instance in
            // Mock pixel data (256x256 image with 16-bit pixels)
            let pixelData = Data(count: 256 * 256 * 2)
            return (instance, pixelData)
        }
        
        // Sort by slice location
        let sortedInstances = instances.sorted { $0.instance.sliceLocation < $1.instance.sliceLocation }
        
        // For testing, we'll just verify the slices are in order
        for (index, item) in sortedInstances.enumerated() {
            XCTAssertEqual(item.instance.sliceLocation, Double(index * 5), "Slice location should match index")
        }
        
        print("✅ MPR workflow setup completed successfully")
    }
    
    // MARK: - Workflow 3: Report Generation
    
    func testReportGenerationWorkflow() async throws {
        // Create test data
        let testFilePath = try createMockDICOMFile(
            patientName: "Report^Patient",
            patientID: "R001",
            studyUID: "1.2.3.4.9",
            seriesUID: "1.2.3.4.9.1",
            instanceUID: "1.2.3.4.9.1.1"
        )
        
        let importProgress = fileImportService.importFiles([testFilePath])
        for await status in importProgress {
            if status.completed { break }
        }
        
        let studies = try databaseService.fetchAllStudies()
        let study = studies[0]
        let instance = study.series[0].instances[0]
        
        // Add measurements
        let measurement1 = Measurement(
            id: UUID(),
            type: .length,
            frameIndex: 0,
            points: [ImagePoint(x: 10, y: 10), ImagePoint(x: 50, y: 50)],
            label: "Lesion Diameter",
            pixelSpacing: (0.5, 0.5)
        )
        
        let measurement2 = Measurement(
            id: UUID(),
            type: .ellipse,
            frameIndex: 0,
            points: [ImagePoint(x: 100, y: 100), ImagePoint(x: 150, y: 150)],
            label: "ROI Analysis",
            pixelSpacing: (0.5, 0.5),
            statistics: ROIStatistics(mean: 120.5, stdDev: 15.2, min: 80, max: 180, area: 1234.5)
        )
        
        measurementService.addMeasurement(measurement1, forInstanceUID: instance.instanceUID)
        measurementService.addMeasurement(measurement2, forInstanceUID: instance.instanceUID)
        
        // Generate PDF report
        let measurements = measurementService.getMeasurements(forInstanceUID: instance.instanceUID)
        
        let config = PDFReportGenerator.Configuration(
            pageSize: .usLetter,
            margins: PDFReportGenerator.Margins(top: 72, left: 72, right: 72, bottom: 72),
            institutionName: "Test Hospital",
            reportingPhysician: "Dr. Test"
        )
        
        let pdfData = try pdfGenerator.generateReport(
            configuration: config,
            patientInfo: (
                name: study.patientName,
                id: study.patientID,
                birthDate: study.patientBirthDate,
                sex: study.patientSex
            ),
            studyInfo: (
                date: study.studyDate,
                time: study.studyTime,
                description: study.studyDescription,
                modalities: study.modalities
            ),
            measurements: measurements,
            images: []
        )
        
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        XCTAssertTrue(pdfData.starts(with: "%PDF".data(using: .utf8)!), "Should start with PDF header")
        
        // Save to temp file and verify
        let pdfPath = tempDirectory.appendingPathComponent("test_report.pdf")
        try pdfData.write(to: pdfPath)
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: pdfPath.path)[.size] as? Int
        XCTAssertNotNil(fileSize, "PDF file should exist")
        XCTAssertGreaterThan(fileSize!, 1000, "PDF should be at least 1KB")
        
        print("✅ Report generation workflow completed successfully")
    }
    
    // MARK: - Workflow 4: Search and Filter
    
    func testSearchAndFilterWorkflow() async throws {
        // Import multiple studies with different characteristics
        let files = try [
            createMockDICOMFile(
                patientName: "Smith^John",
                patientID: "S001",
                studyUID: "1.2.3.4.10",
                seriesUID: "1.2.3.4.10.1",
                instanceUID: "1.2.3.4.10.1.1",
                modality: "CT"
            ),
            createMockDICOMFile(
                patientName: "Doe^Jane",
                patientID: "D001",
                studyUID: "1.2.3.4.11",
                seriesUID: "1.2.3.4.11.1",
                instanceUID: "1.2.3.4.11.1.1",
                modality: "MR"
            ),
            createMockDICOMFile(
                patientName: "Johnson^Bob",
                patientID: "J001",
                studyUID: "1.2.3.4.12",
                seriesUID: "1.2.3.4.12.1",
                instanceUID: "1.2.3.4.12.1.1",
                modality: "CT"
            )
        ]
        
        let importProgress = fileImportService.importFiles(files)
        for await status in importProgress {
            if status.completed { break }
        }
        
        // Test search by patient name
        let smithStudies = try databaseService.searchStudies(query: "Smith")
        XCTAssertEqual(smithStudies.count, 1, "Should find Smith's study")
        XCTAssertEqual(smithStudies[0].patientName, "Smith^John")
        
        // Test search by patient ID
        let d001Studies = try databaseService.searchStudies(query: "D001")
        XCTAssertEqual(d001Studies.count, 1, "Should find D001 study")
        XCTAssertEqual(d001Studies[0].patientID, "D001")
        
        // Test filter by modality
        let ctStudies = try databaseService.filterStudies(modality: "CT")
        XCTAssertEqual(ctStudies.count, 2, "Should find 2 CT studies")
        
        let mrStudies = try databaseService.filterStudies(modality: "MR")
        XCTAssertEqual(mrStudies.count, 1, "Should find 1 MR study")
        
        // Test get all studies
        let allStudies = try databaseService.fetchAllStudies()
        XCTAssertEqual(allStudies.count, 3, "Should have 3 total studies")
        
        print("✅ Search and filter workflow completed successfully")
    }
    
    // MARK: - Helper Methods
    
    /// Creates a mock DICOM file with specified metadata
    private func createMockDICOMFile(
        patientName: String,
        patientID: String,
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        modality: String = "CT",
        sliceLocation: Double = 0.0
    ) throws -> URL {
        // Create a minimal DICOM file with required metadata
        var dataSet = DataSet()
        
        // Patient Module
        dataSet.append(.patientName, patientName)
        dataSet.append(.patientID, patientID)
        
        // Study Module
        dataSet.append(.studyInstanceUID, studyUID)
        dataSet.append(.studyDate, "20260206")
        dataSet.append(.studyTime, "120000")
        dataSet.append(.studyDescription, "Test Study")
        
        // Series Module
        dataSet.append(.seriesInstanceUID, seriesUID)
        dataSet.append(.modality, modality)
        dataSet.append(.seriesNumber, 1)
        dataSet.append(.seriesDescription, "Test Series")
        
        // Instance Module
        dataSet.append(.sopInstanceUID, instanceUID)
        dataSet.append(.sopClassUID, "1.2.840.10008.5.1.4.1.1.2") // CT Image Storage
        dataSet.append(.instanceNumber, 1)
        
        // Image Module
        dataSet.append(.rows, 256)
        dataSet.append(.columns, 256)
        dataSet.append(.bitsAllocated, 16)
        dataSet.append(.bitsStored, 12)
        dataSet.append(.highBit, 11)
        dataSet.append(.pixelRepresentation, 0)
        dataSet.append(.samplesPerPixel, 1)
        dataSet.append(.photometricInterpretation, "MONOCHROME2")
        
        // Slice location for MPR tests
        if sliceLocation != 0.0 {
            dataSet.append(.sliceLocation, sliceLocation)
        }
        
        // Mock pixel data (256x256 image with 16-bit pixels = 131072 bytes)
        let pixelData = Data(count: 256 * 256 * 2)
        dataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: .OW,
            length: UInt32(pixelData.count),
            valueData: pixelData
        )
        
        // Write DICOM file
        let fileName = "\(instanceUID).dcm"
        let filePath = tempDirectory.appendingPathComponent(fileName)
        
        let writer = DICOMWriter()
        let dicomData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
        try dicomData.write(to: filePath)
        
        return filePath
    }
}
