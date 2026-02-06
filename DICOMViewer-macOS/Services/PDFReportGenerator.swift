// PDFReportGenerator.swift
// DICOMViewer macOS - PDF Report Generation Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import AppKit
import PDFKit

/// Service for generating PDF reports with DICOM images and measurements
@MainActor
final class PDFReportGenerator {
    
    // MARK: - Report Configuration
    
    struct ReportConfig {
        /// Report title
        var title: String = "DICOM Measurement Report"
        
        /// Report subtitle
        var subtitle: String?
        
        /// Institution name for header
        var institutionName: String?
        
        /// Report author/physician
        var reportingPhysician: String?
        
        /// Include patient demographics
        var includePatientDemographics: Bool = true
        
        /// Include study information
        var includeStudyInformation: Bool = true
        
        /// Include measurements table
        var includeMeasurementsTable: Bool = true
        
        /// Include images with measurements
        var includeImages: Bool = true
        
        /// Maximum images per page
        var maxImagesPerPage: Int = 4
        
        /// Image size on page (points)
        var imageSize: CGSize = CGSize(width: 300, height: 300)
        
        /// Page size (US Letter by default)
        var pageSize: CGSize = CGSize(width: 612, height: 792) // 8.5" x 11"
        
        /// Page margins
        var margins: NSEdgeInsets = NSEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
        
        /// Show header on all pages
        var showHeaderOnAllPages: Bool = true
        
        /// Show footer on all pages
        var showFooterOnAllPages: Bool = true
    }
    
    // MARK: - Report Data
    
    struct ReportData {
        let patientInfo: PatientInfo?
        let studyInfo: StudyInfo?
        let measurements: [MeasurementData]
        let images: [ImageData]
    }
    
    struct PatientInfo {
        let name: String
        let patientID: String
        let birthDate: String?
        let sex: String?
        let age: String?
    }
    
    struct StudyInfo {
        let studyDate: String
        let studyTime: String?
        let studyDescription: String
        let modality: String
        let accessionNumber: String?
        let referringPhysician: String?
    }
    
    struct MeasurementData {
        let type: String
        let value: String
        let frameIndex: Int
        let label: String?
    }
    
    struct ImageData {
        let image: NSImage
        let caption: String
        let measurements: [MeasurementData]
    }
    
    // MARK: - PDF Generation
    
    /// Generate a PDF report
    func generateReport(data: ReportData, config: ReportConfig = ReportConfig()) -> PDFDocument? {
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            return nil
        }
        
        var mediaBox = CGRect(origin: .zero, size: config.pageSize)
        
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }
        
        // Generate pages
        var currentPage = 1
        
        // Title page
        beginPage(context: context, mediaBox: mediaBox, pageNumber: currentPage, config: config)
        drawTitlePage(context: context, data: data, config: config, bounds: mediaBox)
        context.endPage()
        currentPage += 1
        
        // Patient demographics page
        if config.includePatientDemographics && data.patientInfo != nil {
            beginPage(context: context, mediaBox: mediaBox, pageNumber: currentPage, config: config)
            drawPatientDemographics(context: context, patientInfo: data.patientInfo!, studyInfo: data.studyInfo, config: config, bounds: mediaBox)
            context.endPage()
            currentPage += 1
        }
        
        // Measurements table
        if config.includeMeasurementsTable && !data.measurements.isEmpty {
            beginPage(context: context, mediaBox: mediaBox, pageNumber: currentPage, config: config)
            drawMeasurementsTable(context: context, measurements: data.measurements, config: config, bounds: mediaBox)
            context.endPage()
            currentPage += 1
        }
        
        // Images with measurements
        if config.includeImages && !data.images.isEmpty {
            var imageIndex = 0
            while imageIndex < data.images.count {
                beginPage(context: context, mediaBox: mediaBox, pageNumber: currentPage, config: config)
                
                let endIndex = min(imageIndex + config.maxImagesPerPage, data.images.count)
                let pageImages = Array(data.images[imageIndex..<endIndex])
                
                drawImagesPage(context: context, images: pageImages, config: config, bounds: mediaBox)
                context.endPage()
                
                imageIndex = endIndex
                currentPage += 1
            }
        }
        
        context.closePDF()
        
        return PDFDocument(data: pdfData as Data)
    }
    
    /// Save report to file
    func saveReport(data: ReportData, config: ReportConfig = ReportConfig(), to url: URL) throws {
        guard let pdfDocument = generateReport(data: data, config: config) else {
            throw ReportError.generationFailed
        }
        
        guard pdfDocument.write(to: url) else {
            throw ReportError.saveFailed
        }
    }
    
    // MARK: - Private Drawing Methods
    
    private func beginPage(context: CGContext, mediaBox: CGRect, pageNumber: Int, config: ReportConfig) {
        context.beginPage(mediaBoxPointer: UnsafePointer<CGRect>([mediaBox]))
    }
    
    private func drawTitlePage(context: CGContext, data: ReportData, config: ReportConfig, bounds: CGRect) {
        let centerX = bounds.midX
        let centerY = bounds.midY
        
        // Institution name (top)
        if let institution = config.institutionName {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.gray
            ]
            let institutionString = NSAttributedString(string: institution, attributes: attributes)
            let institutionSize = institutionString.size()
            institutionString.draw(at: CGPoint(x: centerX - institutionSize.width / 2, y: bounds.height - config.margins.top))
        }
        
        // Main title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
        let titleString = NSAttributedString(string: config.title, attributes: titleAttributes)
        let titleSize = titleString.size()
        titleString.draw(at: CGPoint(x: centerX - titleSize.width / 2, y: centerY + 50))
        
        // Subtitle
        if let subtitle = config.subtitle {
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.darkGray
            ]
            let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
            let subtitleSize = subtitleString.size()
            subtitleString.draw(at: CGPoint(x: centerX - subtitleSize.width / 2, y: centerY + 10))
        }
        
        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let dateString = "Generated: \(dateFormatter.string(from: Date()))"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.gray
        ]
        let dateAttrString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateSize = dateAttrString.size()
        dateAttrString.draw(at: CGPoint(x: centerX - dateSize.width / 2, y: centerY - 50))
        
        // Reporting physician
        if let physician = config.reportingPhysician {
            let physicianString = "Reporting Physician: \(physician)"
            let physicianAttrString = NSAttributedString(string: physicianString, attributes: dateAttributes)
            let physicianSize = physicianAttrString.size()
            physicianAttrString.draw(at: CGPoint(x: centerX - physicianSize.width / 2, y: centerY - 80))
        }
    }
    
    private func drawPatientDemographics(context: CGContext, patientInfo: PatientInfo, studyInfo: StudyInfo?, config: ReportConfig, bounds: CGRect) {
        var y = bounds.height - config.margins.top - 50
        let leftMargin = config.margins.left
        
        // Section title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: NSColor.black
        ]
        NSAttributedString(string: "Patient Information", attributes: titleAttributes).draw(at: CGPoint(x: leftMargin, y: y))
        y -= 40
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.darkGray
        ]
        
        // Patient info fields
        let fields: [(String, String?)] = [
            ("Patient Name:", patientInfo.name),
            ("Patient ID:", patientInfo.patientID),
            ("Birth Date:", patientInfo.birthDate),
            ("Sex:", patientInfo.sex),
            ("Age:", patientInfo.age)
        ]
        
        for (label, value) in fields {
            guard let value = value else { continue }
            
            NSAttributedString(string: label, attributes: labelAttributes).draw(at: CGPoint(x: leftMargin, y: y))
            NSAttributedString(string: value, attributes: valueAttributes).draw(at: CGPoint(x: leftMargin + 150, y: y))
            y -= 25
        }
        
        // Study information
        if let studyInfo = studyInfo {
            y -= 20
            NSAttributedString(string: "Study Information", attributes: titleAttributes).draw(at: CGPoint(x: leftMargin, y: y))
            y -= 40
            
            let studyFields: [(String, String?)] = [
                ("Study Date:", studyInfo.studyDate),
                ("Study Time:", studyInfo.studyTime),
                ("Modality:", studyInfo.modality),
                ("Study Description:", studyInfo.studyDescription),
                ("Accession Number:", studyInfo.accessionNumber),
                ("Referring Physician:", studyInfo.referringPhysician)
            ]
            
            for (label, value) in studyFields {
                guard let value = value else { continue }
                
                NSAttributedString(string: label, attributes: labelAttributes).draw(at: CGPoint(x: leftMargin, y: y))
                NSAttributedString(string: value, attributes: valueAttributes).draw(at: CGPoint(x: leftMargin + 150, y: y))
                y -= 25
            }
        }
    }
    
    private func drawMeasurementsTable(context: CGContext, measurements: [MeasurementData], config: ReportConfig, bounds: CGRect) {
        var y = bounds.height - config.margins.top - 50
        let leftMargin = config.margins.left
        let rightMargin = bounds.width - config.margins.right
        
        // Section title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: NSColor.black
        ]
        NSAttributedString(string: "Measurements", attributes: titleAttributes).draw(at: CGPoint(x: leftMargin, y: y))
        y -= 40
        
        // Table header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.black
        ]
        
        let tableWidth = rightMargin - leftMargin
        let colWidths = [tableWidth * 0.15, tableWidth * 0.25, tableWidth * 0.15, tableWidth * 0.45]
        
        // Draw header background
        context.setFillColor(NSColor.darkGray.cgColor)
        context.fill(CGRect(x: leftMargin, y: y, width: tableWidth, height: 25))
        
        // Draw header text
        var x = leftMargin + 5
        for (header, width) in zip(["#", "Type", "Frame", "Value / Label"], colWidths) {
            NSAttributedString(string: header, attributes: headerAttributes).draw(at: CGPoint(x: x, y: y + 5))
            x += width
        }
        y -= 25
        
        // Draw rows
        for (index, measurement) in measurements.enumerated() {
            // Alternate row colors
            if index % 2 == 0 {
                context.setFillColor(NSColor.systemGray.withAlphaComponent(0.1).cgColor)
                context.fill(CGRect(x: leftMargin, y: y, width: tableWidth, height: 20))
            }
            
            x = leftMargin + 5
            let rowData = [
                "\(index + 1)",
                measurement.type,
                "\(measurement.frameIndex)",
                measurement.label.map { "\(measurement.value) - \($0)" } ?? measurement.value
            ]
            
            for (text, width) in zip(rowData, colWidths) {
                NSAttributedString(string: text, attributes: cellAttributes).draw(at: CGPoint(x: x, y: y + 3))
                x += width
            }
            
            y -= 20
            
            // Start new page if needed
            if y < config.margins.bottom + 50 {
                break
            }
        }
    }
    
    private func drawImagesPage(context: CGContext, images: [ImageData], config: ReportConfig, bounds: CGRect) {
        let imagesPerRow = 2
        let imageSpacing: CGFloat = 20
        
        let contentWidth = bounds.width - config.margins.left - config.margins.right
        let imageWidth = (contentWidth - imageSpacing) / CGFloat(imagesPerRow)
        let imageHeight = imageWidth
        
        var row = 0
        var col = 0
        var y = bounds.height - config.margins.top - 50
        
        for imageData in images {
            let x = config.margins.left + CGFloat(col) * (imageWidth + imageSpacing)
            
            // Draw image
            let imageRect = CGRect(x: x, y: y - imageHeight, width: imageWidth, height: imageHeight)
            if let cgImage = imageData.image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: imageRect)
            }
            
            // Draw caption
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.black
            ]
            NSAttributedString(string: imageData.caption, attributes: captionAttributes)
                .draw(at: CGPoint(x: x, y: y - imageHeight - 20))
            
            // Move to next position
            col += 1
            if col >= imagesPerRow {
                col = 0
                row += 1
                y -= imageHeight + 40
            }
        }
    }
    
    // MARK: - Errors
    
    enum ReportError: Error, LocalizedError {
        case generationFailed
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .generationFailed:
                return "Failed to generate PDF report"
            case .saveFailed:
                return "Failed to save PDF report to file"
            }
        }
    }
}
