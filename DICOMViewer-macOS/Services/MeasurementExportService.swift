// MeasurementExportService.swift
// DICOMViewer macOS - Measurement Export Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation

/// Service for exporting measurements to various formats
@MainActor
final class MeasurementExportService {
    
    // MARK: - Export Formats
    
    enum ExportFormat: String, CaseIterable {
        case csv = "csv"
        case json = "json"
        case text = "txt"
        
        var displayName: String {
            switch self {
            case .csv: return "CSV"
            case .json: return "JSON"
            case .text: return "Plain Text"
            }
        }
        
        var fileExtension: String {
            rawValue
        }
    }
    
    // MARK: - Export Methods
    
    /// Export measurements to CSV format
    func exportToCSV(_ measurements: [Measurement], studyInfo: StudyInfo? = nil) -> String {
        var csv = ""
        
        // Add header with study info if provided
        if let info = studyInfo {
            csv += "# Study Information\n"
            csv += "# Patient Name: \(info.patientName)\n"
            csv += "# Patient ID: \(info.patientID)\n"
            csv += "# Study Date: \(info.studyDate)\n"
            csv += "# Study Description: \(info.studyDescription)\n"
            csv += "#\n"
        }
        
        // CSV header
        csv += "ID,Type,Frame,Length (mm),Angle (deg),Area (mm²),Label,Created At\n"
        
        // Add each measurement
        for measurement in measurements {
            csv += formatMeasurementCSV(measurement)
            csv += "\n"
        }
        
        return csv
    }
    
    /// Export measurements to JSON format
    func exportToJSON(_ measurements: [Measurement], studyInfo: StudyInfo? = nil) throws -> Data {
        let exportData = ExportData(
            studyInfo: studyInfo,
            measurements: measurements.map { MeasurementExportData(measurement: $0) },
            exportDate: Date(),
            version: "1.0"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(exportData)
    }
    
    /// Export measurements to plain text format
    func exportToText(_ measurements: [Measurement], studyInfo: StudyInfo? = nil) -> String {
        var text = "DICOM Measurement Report\n"
        text += "========================\n\n"
        
        // Study information
        if let info = studyInfo {
            text += "Study Information:\n"
            text += "  Patient Name: \(info.patientName)\n"
            text += "  Patient ID: \(info.patientID)\n"
            text += "  Study Date: \(info.studyDate)\n"
            text += "  Study Description: \(info.studyDescription)\n"
            text += "\n"
        }
        
        // Export date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        text += "Export Date: \(dateFormatter.string(from: Date()))\n"
        text += "Total Measurements: \(measurements.count)\n\n"
        
        // List measurements
        text += "Measurements:\n"
        text += "=============\n\n"
        
        for (index, measurement) in measurements.enumerated() {
            text += "[\(index + 1)] \(measurement.type.displayName)\n"
            text += formatMeasurementText(measurement)
            text += "\n"
        }
        
        return text
    }
    
    /// Export measurements to clipboard
    func exportToClipboard(_ measurements: [Measurement], format: ExportFormat, studyInfo: StudyInfo? = nil) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch format {
        case .csv:
            let csvText = exportToCSV(measurements, studyInfo: studyInfo)
            pasteboard.setString(csvText, forType: .string)
            
        case .json:
            let jsonData = try exportToJSON(measurements, studyInfo: studyInfo)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                pasteboard.setString(jsonString, forType: .string)
            }
            
        case .text:
            let text = exportToText(measurements, studyInfo: studyInfo)
            pasteboard.setString(text, forType: .string)
        }
    }
    
    /// Save measurements to file
    func saveToFile(_ measurements: [Measurement], format: ExportFormat, url: URL, studyInfo: StudyInfo? = nil) throws {
        switch format {
        case .csv:
            let csvText = exportToCSV(measurements, studyInfo: studyInfo)
            try csvText.write(to: url, atomically: true, encoding: .utf8)
            
        case .json:
            let jsonData = try exportToJSON(measurements, studyInfo: studyInfo)
            try jsonData.write(to: url)
            
        case .text:
            let text = exportToText(measurements, studyInfo: studyInfo)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Private Helpers
    
    private func formatMeasurementCSV(_ measurement: Measurement) -> String {
        let id = measurement.id.uuidString
        let type = measurement.type.rawValue
        let frame = "\(measurement.frameIndex)"
        let length = measurement.lengthInMM.map { String(format: "%.2f", $0) } ?? ""
        let angle = measurement.angleInDegrees.map { String(format: "%.1f", $0) } ?? ""
        let area = measurement.areaInMM2.map { String(format: "%.2f", $0) } ?? ""
        let label = measurement.label?.replacingOccurrences(of: ",", with: ";") ?? ""
        
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.string(from: measurement.createdAt)
        
        return "\(id),\(type),\(frame),\(length),\(angle),\(area),\(label),\(createdAt)"
    }
    
    private func formatMeasurementText(_ measurement: Measurement) -> String {
        var text = "  Type: \(measurement.type.displayName)\n"
        text += "  Frame: \(measurement.frameIndex)\n"
        
        if let length = measurement.lengthInMM {
            text += "  Length: \(String(format: "%.2f", length)) mm\n"
        }
        
        if let angle = measurement.angleInDegrees {
            text += "  Angle: \(String(format: "%.1f", angle))°\n"
        }
        
        if let area = measurement.areaInMM2 {
            text += "  Area: \(String(format: "%.2f", area)) mm²\n"
        }
        
        if let label = measurement.label, !label.isEmpty {
            text += "  Label: \(label)\n"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        text += "  Created: \(dateFormatter.string(from: measurement.createdAt))\n"
        
        return text
    }
    
    // MARK: - Data Structures
    
    struct StudyInfo: Codable {
        let patientName: String
        let patientID: String
        let studyDate: String
        let studyDescription: String
    }
    
    struct ExportData: Codable {
        let studyInfo: StudyInfo?
        let measurements: [MeasurementExportData]
        let exportDate: Date
        let version: String
    }
    
    struct MeasurementExportData: Codable {
        let id: String
        let type: String
        let frameIndex: Int
        let points: [[String: Double]]
        let pixelSpacing: [String: Double]?
        let lengthMM: Double?
        let angleInDegrees: Double?
        let areaMM2: Double?
        let label: String?
        let createdAt: Date
        
        init(measurement: Measurement) {
            self.id = measurement.id.uuidString
            self.type = measurement.type.rawValue
            self.frameIndex = measurement.frameIndex
            self.points = measurement.points.map { ["x": $0.x, "y": $0.y] }
            self.pixelSpacing = measurement.pixelSpacing.map { ["row": $0.row, "column": $0.column] }
            self.lengthMM = measurement.lengthInMM
            self.angleInDegrees = measurement.angleInDegrees
            self.areaMM2 = measurement.areaInMM2
            self.label = measurement.label
            self.createdAt = measurement.createdAt
        }
    }
}
