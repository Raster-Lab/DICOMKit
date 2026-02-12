/// Report generation engine for DICOM SR documents
///
/// Converts parsed SR documents into various output formats.

import Foundation
import DICOMKit
import DICOMCore

/// Report generation options
struct ReportOptions {
    let format: ReportFormat
    let template: String
    let embedImages: Bool
    let imageDirectory: String?
    let customTitle: String?
    let logoPath: String?
    let footerText: String?
    let includeMeasurements: Bool
    let includeSummary: Bool
}

/// Main report generator
struct ReportGenerator {
    let document: SRDocument
    let options: ReportOptions
    
    func generate() async throws -> Data {
        switch options.format {
        case .text:
            return try generateTextReport()
        case .html:
            return try generateHTMLReport()
        case .pdf:
            return try generatePDFReport()
        case .json:
            return try generateJSONReport()
        case .markdown:
            return try generateMarkdownReport()
        }
    }
    
    // MARK: - Text Report
    
    private func generateTextReport() throws -> Data {
        var output = ""
        
        // Header
        output += "=" + String(repeating: "=", count: 78) + "\n"
        output += centerText(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Structured Report", width: 80)
        output += "=" + String(repeating: "=", count: 78) + "\n\n"
        
        // Patient Information
        if let patientName = document.patientName {
            output += "Patient: \(patientName)\n"
        }
        if let patientID = document.patientID {
            output += "Patient ID: \(patientID)\n"
        }
        
        // Study Information
        if let studyDate = document.studyDate {
            output += "Study Date: \(formatDate(studyDate))\n"
        }
        if let accessionNumber = document.accessionNumber {
            output += "Accession Number: \(accessionNumber)\n"
        }
        
        output += "\n"
        output += "-" + String(repeating: "-", count: 78) + "\n\n"
        
        // Content
        output += renderContentTree(document.rootContent, level: 0)
        
        // Measurements
        if options.includeMeasurements {
            let measurements = extractMeasurements()
            if !measurements.isEmpty {
                output += "\n" + "-" + String(repeating: "-", count: 78) + "\n"
                output += "MEASUREMENTS\n"
                output += "-" + String(repeating: "-", count: 78) + "\n\n"
                for measurement in measurements {
                    output += "\(measurement.name): \(measurement.value) \(measurement.units)\n"
                }
            }
        }
        
        // Footer
        if let footer = options.footerText {
            output += "\n" + "-" + String(repeating: "-", count: 78) + "\n"
            output += centerText(footer, width: 80)
        }
        
        return Data(output.utf8)
    }
    
    private func renderContentTree(_ item: ContainerContentItem, level: Int) -> String {
        var output = ""
        let indent = String(repeating: "  ", count: level)
        
        for child in item.contentItems {
            output += renderContentItem(child, indent: indent)
        }
        
        return output
    }
    
    private func renderContentItem(_ item: AnyContentItem, indent: String) -> String {
        var output = ""
        
        // Concept name
        if let name = item.conceptName {
            output += "\(indent)\(name.codeMeaning):\n"
        }
        
        // Value
        output += "\(indent)  \(formatContentValue(item))\n"
        
        // Children (for containers)
        if let container = item.asContainer {
            for child in container.contentItems {
                output += renderContentItem(child, indent: indent + "  ")
            }
        }
        
        return output
    }
    
    private func formatContentValue(_ item: AnyContentItem) -> String {
        if let textItem = item.asText {
            return textItem.textValue
        } else if let numItem = item.asNumeric {
            if let units = numItem.measurementUnits {
                let value = numItem.numericValues.first ?? 0.0
                return "\(value) \(units.codeMeaning)"
            }
            let value = numItem.numericValues.first ?? 0.0
            return "\(value)"
        } else if let codeItem = item.asCode {
            return codeItem.conceptCode.codeMeaning
        } else if let dateTimeItem = item.asDateTime {
            return dateTimeItem.dateTimeValue
        } else if let imageItem = item.asImage {
            return "Image: \(imageItem.imageReference.sopReference.sopInstanceUID)"
        } else if let containerItem = item.asContainer {
            return "[\(containerItem.contentItems.count) items]"
        } else {
            return "[Content]"
        }
    }
    
    // MARK: - HTML Report
    
    private func generateHTMLReport() throws -> Data {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Report")</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 900px;
                    margin: 40px auto;
                    padding: 20px;
                    background: #f5f5f5;
                }
                .report {
                    background: white;
                    padding: 40px;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                .header {
                    text-align: center;
                    border-bottom: 3px solid #007AFF;
                    padding-bottom: 20px;
                    margin-bottom: 30px;
                }
                .header h1 {
                    margin: 0 0 10px 0;
                    color: #333;
                }
                .patient-info {
                    background: #f9f9f9;
                    padding: 15px;
                    border-radius: 4px;
                    margin-bottom: 25px;
                }
                .patient-info table {
                    width: 100%;
                    border-collapse: collapse;
                }
                .patient-info td {
                    padding: 5px 0;
                }
                .patient-info td:first-child {
                    font-weight: 600;
                    width: 150px;
                }
                .content-item {
                    margin: 15px 0;
                    padding: 10px;
                    border-left: 3px solid #007AFF;
                    background: #fafafa;
                }
                .content-item.level-1 {
                    margin-left: 20px;
                }
                .content-item.level-2 {
                    margin-left: 40px;
                }
                .item-name {
                    font-weight: 600;
                    color: #007AFF;
                }
                .item-value {
                    margin-top: 5px;
                    color: #333;
                }
                .measurements {
                    margin-top: 30px;
                    border-top: 2px solid #eee;
                    padding-top: 20px;
                }
                .measurements h2 {
                    color: #333;
                }
                .measurement-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-top: 15px;
                }
                .measurement-table th {
                    background: #007AFF;
                    color: white;
                    padding: 10px;
                    text-align: left;
                }
                .measurement-table td {
                    padding: 8px 10px;
                    border-bottom: 1px solid #eee;
                }
                .measurement-table tr:hover {
                    background: #f9f9f9;
                }
                .footer {
                    margin-top: 40px;
                    padding-top: 20px;
                    border-top: 1px solid #eee;
                    text-align: center;
                    color: #666;
                    font-size: 0.9em;
                }
            </style>
        </head>
        <body>
            <div class="report">
        """
        
        // Header
        html += """
                <div class="header">
        """
        
        if let logoPath = options.logoPath {
            html += """
                    <img src="file://\(logoPath)" alt="Logo" style="max-height: 60px; margin-bottom: 10px;">
            """
        }
        
        html += """
                    <h1>\(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Structured Report")</h1>
        """
        
        if let docType = document.documentType {
            html += """
                    <p style="color: #666; margin: 5px 0 0 0;">\(docType.description)</p>
            """
        }
        
        html += """
                </div>
        """
        
        // Patient Info
        html += """
                <div class="patient-info">
                    <table>
        """
        
        if let patientName = document.patientName {
            html += """
                        <tr><td>Patient:</td><td>\(patientName)</td></tr>
            """
        }
        if let patientID = document.patientID {
            html += """
                        <tr><td>Patient ID:</td><td>\(patientID)</td></tr>
            """
        }
        if let studyDate = document.studyDate {
            html += """
                        <tr><td>Study Date:</td><td>\(formatDate(studyDate))</td></tr>
            """
        }
        if let accessionNumber = document.accessionNumber {
            html += """
                        <tr><td>Accession Number:</td><td>\(accessionNumber)</td></tr>
            """
        }
        
        html += """
                    </table>
                </div>
        """
        
        // Content
        html += renderHTMLContentTree(document.rootContent, level: 0)
        
        // Measurements
        if options.includeMeasurements {
            let measurements = extractMeasurements()
            if !measurements.isEmpty {
                html += """
                <div class="measurements">
                    <h2>Measurements</h2>
                    <table class="measurement-table">
                        <thead>
                            <tr>
                                <th>Measurement</th>
                                <th>Value</th>
                                <th>Units</th>
                            </tr>
                        </thead>
                        <tbody>
                """
                
                for measurement in measurements {
                    html += """
                            <tr>
                                <td>\(measurement.name)</td>
                                <td>\(measurement.value)</td>
                                <td>\(measurement.units)</td>
                            </tr>
                    """
                }
                
                html += """
                        </tbody>
                    </table>
                </div>
                """
            }
        }
        
        // Footer
        if let footer = options.footerText {
            html += """
                <div class="footer">
                    <p>\(footer)</p>
                </div>
            """
        }
        
        html += """
            </div>
        </body>
        </html>
        """
        
        return Data(html.utf8)
    }
    
    private func renderHTMLContentTree(_ item: ContainerContentItem, level: Int) -> String {
        var html = ""
        
        for child in item.contentItems {
            html += renderHTMLContentItem(child, level: level)
        }
        
        return html
    }
    
    private func renderHTMLContentItem(_ item: AnyContentItem, level: Int) -> String {
        var html = """
                <div class="content-item level-\(level)">
        """
        
        if let name = item.conceptName {
            html += """
                    <div class="item-name">\(name.codeMeaning)</div>
            """
        }
        
        html += """
                    <div class="item-value">\(formatContentValue(item))</div>
        """
        
        html += """
                </div>
        """
        
        // Recursively render children for containers
        if let container = item.asContainer {
            html += renderHTMLContentTree(container, level: level + 1)
        }
        
        return html
    }
    
    // MARK: - JSON Report
    
    private func generateJSONReport() throws -> Data {
        let report: [String: Any] = [
            "document_type": document.documentType?.description ?? "Unknown",
            "sop_class_uid": document.sopClassUID,
            "sop_instance_uid": document.sopInstanceUID,
            "title": options.customTitle ?? document.documentTitle?.codeMeaning ?? "",
            "patient": [
                "name": document.patientName ?? "",
                "id": document.patientID ?? ""
            ],
            "study": [
                "uid": document.studyInstanceUID ?? "",
                "date": document.studyDate ?? "",
                "accession_number": document.accessionNumber ?? ""
            ],
            "content_item_count": document.contentItemCount,
            "content": serializeContentTree(document.rootContent),
            "measurements": options.includeMeasurements ? extractMeasurements().map { measurement in
                [
                    "name": measurement.name,
                    "value": measurement.value,
                    "units": measurement.units
                ]
            } : []
        ]
        
        return try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }
    
    private func serializeContentTree(_ item: ContainerContentItem) -> [[String: Any]] {
        item.contentItems.map { child in
            serializeContentItem(child)
        }
    }
    
    private func serializeContentItem(_ item: AnyContentItem) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let relationshipType = item.relationshipType {
            dict["relationship_type"] = relationshipType.rawValue
        }
        
        if let name = item.conceptName {
            dict["concept_name"] = [
                "code_value": name.codeValue,
                "coding_scheme": name.codingSchemeDesignator,
                "code_meaning": name.codeMeaning
            ]
        }
        
        dict["value"] = formatContentValue(item)
        
        if let container = item.asContainer {
            dict["children"] = serializeContentTree(container)
        }
        
        return dict
    }
    
    // MARK: - Markdown Report
    
    private func generateMarkdownReport() throws -> Data {
        var md = ""
        
        // Title
        md += "# \(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Structured Report")\n\n"
        
        if let docType = document.documentType {
            md += "*\(docType.description)*\n\n"
        }
        
        // Patient Information
        md += "## Patient Information\n\n"
        
        if let patientName = document.patientName {
            md += "- **Patient:** \(patientName)\n"
        }
        if let patientID = document.patientID {
            md += "- **Patient ID:** \(patientID)\n"
        }
        if let studyDate = document.studyDate {
            md += "- **Study Date:** \(formatDate(studyDate))\n"
        }
        if let accessionNumber = document.accessionNumber {
            md += "- **Accession Number:** \(accessionNumber)\n"
        }
        
        md += "\n---\n\n"
        
        // Content
        md += "## Report Content\n\n"
        md += renderMarkdownContentTree(document.rootContent, level: 0)
        
        // Measurements
        if options.includeMeasurements {
            let measurements = extractMeasurements()
            if !measurements.isEmpty {
                md += "\n---\n\n"
                md += "## Measurements\n\n"
                md += "| Measurement | Value | Units |\n"
                md += "|-------------|-------|-------|\n"
                
                for measurement in measurements {
                    md += "| \(measurement.name) | \(measurement.value) | \(measurement.units) |\n"
                }
                
                md += "\n"
            }
        }
        
        // Footer
        if let footer = options.footerText {
            md += "\n---\n\n"
            md += "*\(footer)*\n"
        }
        
        return Data(md.utf8)
    }
    
    private func renderMarkdownContentTree(_ item: ContainerContentItem, level: Int) -> String {
        var md = ""
        
        for child in item.contentItems {
            md += renderMarkdownContentItem(child, level: level)
        }
        
        return md
    }
    
    private func renderMarkdownContentItem(_ item: AnyContentItem, level: Int) -> String {
        var md = ""
        
        let indent = String(repeating: "  ", count: level)
        
        if let name = item.conceptName {
            md += "\(indent)- **\(name.codeMeaning):** \(formatContentValue(item))\n"
        } else {
            md += "\(indent)- \(formatContentValue(item))\n"
        }
        
        // Children
        if let container = item.asContainer {
            md += renderMarkdownContentTree(container, level: level + 1)
        }
        
        return md
    }
    
    // MARK: - PDF Report (Placeholder - requires additional PDF library)
    
    private func generatePDFReport() throws -> Data {
        // For now, generate HTML and note that PDF conversion would require additional library
        // In a full implementation, this would use a PDF library like PDFKit
        throw ReportError.pdfNotImplemented
    }
    
    // MARK: - Helper Methods
    
    private func centerText(_ text: String, width: Int) -> String {
        let padding = max(0, (width - text.count) / 2)
        return String(repeating: " ", count: padding) + text + "\n"
    }
    
    private func formatDate(_ dateString: String) -> String {
        // DICOM date format: YYYYMMDD
        guard dateString.count == 8 else { return dateString }
        
        let year = dateString.prefix(4)
        let month = dateString.dropFirst(4).prefix(2)
        let day = dateString.dropFirst(6).prefix(2)
        
        return "\(year)-\(month)-\(day)"
    }
    
    private func extractMeasurements() -> [Measurement] {
        var measurements: [Measurement] = []
        
        func collectMeasurements(from item: AnyContentItem) {
            if let numItem = item.asNumeric {
                let name = item.conceptName?.codeMeaning ?? "Measurement"
                let value = numItem.numericValues.first.map { String($0) } ?? "0"
                let units = numItem.measurementUnits?.codeMeaning ?? ""
                measurements.append(Measurement(name: name, value: value, units: units))
            }
            
            if let container = item.asContainer {
                for child in container.contentItems {
                    collectMeasurements(from: child)
                }
            }
        }
        
        for child in document.rootContent.contentItems {
            collectMeasurements(from: child)
        }
        
        return measurements
    }
}

// MARK: - Supporting Types

struct Measurement {
    let name: String
    let value: String
    let units: String
}

enum ReportError: LocalizedError {
    case pdfNotImplemented
    case invalidTemplate
    case imageNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .pdfNotImplemented:
            return "PDF generation requires additional libraries. Use HTML or Markdown format instead."
        case .invalidTemplate:
            return "Invalid report template specified"
        case .imageNotFound(let path):
            return "Image not found: \(path)"
        }
    }
}
