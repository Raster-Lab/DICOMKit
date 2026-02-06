// PDFReportGeneratorTests.swift
// DICOMViewer macOS - Tests for PDF Report Generator
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
import PDFKit
@testable import DICOMViewer

@MainActor
final class PDFReportGeneratorTests: XCTestCase {
    
    var generator: PDFReportGenerator!
    var testReportData: PDFReportGenerator.ReportData!
    
    override func setUp() async throws {
        generator = PDFReportGenerator()
        
        // Create test data
        let patientInfo = PDFReportGenerator.PatientInfo(
            name: "TEST^PATIENT",
            patientID: "12345",
            birthDate: "1980-01-15",
            sex: "M",
            age: "44Y"
        )
        
        let studyInfo = PDFReportGenerator.StudyInfo(
            studyDate: "2024-02-06",
            studyTime: "14:30:00",
            studyDescription: "CT CHEST WITH CONTRAST",
            modality: "CT",
            accessionNumber: "ACC12345",
            referringPhysician: "Dr. Smith"
        )
        
        let measurements = [
            PDFReportGenerator.MeasurementData(
                type: "Length",
                value: "45.2 mm",
                frameIndex: 0,
                label: "Lesion measurement"
            ),
            PDFReportGenerator.MeasurementData(
                type: "Angle",
                value: "90.0°",
                frameIndex: 1,
                label: "Angle test"
            )
        ]
        
        // Create a simple test image
        let testImage = createTestImage(width: 100, height: 100)
        let images = [
            PDFReportGenerator.ImageData(
                image: testImage,
                caption: "Test Image 1",
                measurements: [measurements[0]]
            )
        ]
        
        testReportData = PDFReportGenerator.ReportData(
            patientInfo: patientInfo,
            studyInfo: studyInfo,
            measurements: measurements,
            images: images
        )
    }
    
    override func tearDown() async throws {
        generator = nil
        testReportData = nil
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(width: Int, height: Int) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }
    
    // MARK: - Report Generation Tests
    
    func testGenerateReport_Success() {
        let pdfDocument = generator.generateReport(data: testReportData)
        
        XCTAssertNotNil(pdfDocument)
        XCTAssertGreaterThan(pdfDocument?.pageCount ?? 0, 0)
    }
    
    func testGenerateReport_MinimalData() {
        let minimalData = PDFReportGenerator.ReportData(
            patientInfo: nil,
            studyInfo: nil,
            measurements: [],
            images: []
        )
        
        let pdfDocument = generator.generateReport(data: minimalData)
        
        XCTAssertNotNil(pdfDocument)
        XCTAssertEqual(pdfDocument?.pageCount, 1) // Only title page
    }
    
    func testGenerateReport_WithPatientInfo() {
        var config = PDFReportGenerator.ReportConfig()
        config.includePatientDemographics = true
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
        XCTAssertGreaterThanOrEqual(pdfDocument?.pageCount ?? 0, 2) // Title + demographics
    }
    
    func testGenerateReport_WithMeasurements() {
        var config = PDFReportGenerator.ReportConfig()
        config.includeMeasurementsTable = true
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
        XCTAssertGreaterThanOrEqual(pdfDocument?.pageCount ?? 0, 2) // Title + measurements
    }
    
    func testGenerateReport_WithImages() {
        var config = PDFReportGenerator.ReportConfig()
        config.includeImages = true
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
        XCTAssertGreaterThanOrEqual(pdfDocument?.pageCount ?? 0, 2) // Title + images
    }
    
    func testGenerateReport_AllSections() {
        var config = PDFReportGenerator.ReportConfig()
        config.includePatientDemographics = true
        config.includeMeasurementsTable = true
        config.includeImages = true
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
        // Title + demographics + measurements + images = 4 pages
        XCTAssertGreaterThanOrEqual(pdfDocument?.pageCount ?? 0, 4)
    }
    
    func testGenerateReport_MultipleImages() {
        let testImage = createTestImage(width: 100, height: 100)
        let images = (0..<6).map { i in
            PDFReportGenerator.ImageData(
                image: testImage,
                caption: "Test Image \(i + 1)",
                measurements: []
            )
        }
        
        let dataWithManyImages = PDFReportGenerator.ReportData(
            patientInfo: testReportData.patientInfo,
            studyInfo: testReportData.studyInfo,
            measurements: testReportData.measurements,
            images: images
        )
        
        var config = PDFReportGenerator.ReportConfig()
        config.maxImagesPerPage = 4
        config.includeImages = true
        
        let pdfDocument = generator.generateReport(data: dataWithManyImages, config: config)
        
        XCTAssertNotNil(pdfDocument)
        // Should have multiple image pages (6 images / 4 per page = 2 pages)
        XCTAssertGreaterThanOrEqual(pdfDocument?.pageCount ?? 0, 2)
    }
    
    // MARK: - Save Report Tests
    
    func testSaveReport_Success() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_report.pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try generator.saveReport(data: testReportData, to: tempURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Verify it's a valid PDF
        let pdfDocument = PDFDocument(url: tempURL)
        XCTAssertNotNil(pdfDocument)
        XCTAssertGreaterThan(pdfDocument?.pageCount ?? 0, 0)
    }
    
    func testSaveReport_FileSize() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_report.pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try generator.saveReport(data: testReportData, to: tempURL)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        
        // PDF should have some content
        XCTAssertGreaterThan(fileSize, 0)
    }
    
    // MARK: - Configuration Tests
    
    func testReportConfig_DefaultValues() {
        let config = PDFReportGenerator.ReportConfig()
        
        XCTAssertEqual(config.title, "DICOM Measurement Report")
        XCTAssertNil(config.subtitle)
        XCTAssertNil(config.institutionName)
        XCTAssertNil(config.reportingPhysician)
        XCTAssertTrue(config.includePatientDemographics)
        XCTAssertTrue(config.includeStudyInformation)
        XCTAssertTrue(config.includeMeasurementsTable)
        XCTAssertTrue(config.includeImages)
        XCTAssertEqual(config.maxImagesPerPage, 4)
    }
    
    func testReportConfig_CustomTitle() {
        var config = PDFReportGenerator.ReportConfig()
        config.title = "Custom Report Title"
        config.subtitle = "Custom Subtitle"
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
    }
    
    func testReportConfig_CustomInstitution() {
        var config = PDFReportGenerator.ReportConfig()
        config.institutionName = "Test Hospital"
        config.reportingPhysician = "Dr. Test"
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
    }
    
    func testReportConfig_DisableAllSections() {
        var config = PDFReportGenerator.ReportConfig()
        config.includePatientDemographics = false
        config.includeMeasurementsTable = false
        config.includeImages = false
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
        XCTAssertEqual(pdfDocument?.pageCount, 1) // Only title page
    }
    
    func testReportConfig_PageSize() {
        var config = PDFReportGenerator.ReportConfig()
        config.pageSize = CGSize(width: 595, height: 842) // A4
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
        
        if let page = pdfDocument?.page(at: 0) {
            let pageRect = page.bounds(for: .mediaBox)
            XCTAssertEqual(pageRect.width, 595, accuracy: 1.0)
            XCTAssertEqual(pageRect.height, 842, accuracy: 1.0)
        }
    }
    
    func testReportConfig_CustomMargins() {
        var config = PDFReportGenerator.ReportConfig()
        config.margins = NSEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
    }
    
    func testReportConfig_ImagesPerPage() {
        var config = PDFReportGenerator.ReportConfig()
        config.maxImagesPerPage = 2
        
        let pdfDocument = generator.generateReport(data: testReportData, config: config)
        
        XCTAssertNotNil(pdfDocument)
    }
    
    // MARK: - Data Structure Tests
    
    func testPatientInfo_Creation() {
        let patientInfo = PDFReportGenerator.PatientInfo(
            name: "DOE^JOHN",
            patientID: "67890",
            birthDate: "1990-05-20",
            sex: "M",
            age: "34Y"
        )
        
        XCTAssertEqual(patientInfo.name, "DOE^JOHN")
        XCTAssertEqual(patientInfo.patientID, "67890")
        XCTAssertEqual(patientInfo.birthDate, "1990-05-20")
        XCTAssertEqual(patientInfo.sex, "M")
        XCTAssertEqual(patientInfo.age, "34Y")
    }
    
    func testStudyInfo_Creation() {
        let studyInfo = PDFReportGenerator.StudyInfo(
            studyDate: "2024-01-01",
            studyTime: "10:30:00",
            studyDescription: "MRI BRAIN",
            modality: "MR",
            accessionNumber: "ACC67890",
            referringPhysician: "Dr. Johnson"
        )
        
        XCTAssertEqual(studyInfo.studyDate, "2024-01-01")
        XCTAssertEqual(studyInfo.studyTime, "10:30:00")
        XCTAssertEqual(studyInfo.studyDescription, "MRI BRAIN")
        XCTAssertEqual(studyInfo.modality, "MR")
        XCTAssertEqual(studyInfo.accessionNumber, "ACC67890")
        XCTAssertEqual(studyInfo.referringPhysician, "Dr. Johnson")
    }
    
    func testMeasurementData_Creation() {
        let measurement = PDFReportGenerator.MeasurementData(
            type: "Area",
            value: "125.5 mm²",
            frameIndex: 5,
            label: "ROI measurement"
        )
        
        XCTAssertEqual(measurement.type, "Area")
        XCTAssertEqual(measurement.value, "125.5 mm²")
        XCTAssertEqual(measurement.frameIndex, 5)
        XCTAssertEqual(measurement.label, "ROI measurement")
    }
    
    func testImageData_Creation() {
        let testImage = createTestImage(width: 50, height: 50)
        let measurement = PDFReportGenerator.MeasurementData(
            type: "Length",
            value: "20.0 mm",
            frameIndex: 0,
            label: nil
        )
        
        let imageData = PDFReportGenerator.ImageData(
            image: testImage,
            caption: "Test Caption",
            measurements: [measurement]
        )
        
        XCTAssertEqual(imageData.caption, "Test Caption")
        XCTAssertEqual(imageData.measurements.count, 1)
    }
    
    // MARK: - Error Tests
    
    func testReportError_GenerationFailed() {
        let error = PDFReportGenerator.ReportError.generationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("generate"))
    }
    
    func testReportError_SaveFailed() {
        let error = PDFReportGenerator.ReportError.saveFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("save"))
    }
}
