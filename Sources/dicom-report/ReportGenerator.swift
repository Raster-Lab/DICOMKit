/// Report generation engine for DICOM SR documents
///
/// Converts parsed SR documents into various output formats with support for
/// specialty-specific templates, image embedding, branding, and multi-language output.

import Foundation
import DICOMKit
import DICOMCore

// MARK: - Report Template Engine

/// Defines specialty-specific report templates with section ordering and formatting
struct ReportTemplate {
    let name: String
    let displayName: String
    let sections: [ReportSection]
    let colorScheme: ColorScheme
    let headerStyle: HeaderStyle
    let contentStyle: ContentStyle

    /// Predefined specialty templates
    static let `default` = ReportTemplate(
        name: "default",
        displayName: "Standard Report",
        sections: [.patientInfo, .studyInfo, .findings, .measurements, .impressions],
        colorScheme: ColorScheme(primary: "#007AFF", secondary: "#5856D6", accent: "#34C759", background: "#f5f5f5", text: "#333333"),
        headerStyle: .standard,
        contentStyle: .detailed
    )

    static let cardiology = ReportTemplate(
        name: "cardiology",
        displayName: "Cardiology Report",
        sections: [.patientInfo, .studyInfo, .cardiacFindings, .measurements, .hemodynamics, .impressions, .recommendations],
        colorScheme: ColorScheme(primary: "#E53E3E", secondary: "#C53030", accent: "#FC8181", background: "#FFF5F5", text: "#2D3748"),
        headerStyle: .specialty,
        contentStyle: .detailed
    )

    static let radiology = ReportTemplate(
        name: "radiology",
        displayName: "Radiology Report",
        sections: [.patientInfo, .studyInfo, .indication, .technique, .findings, .measurements, .impressions],
        colorScheme: ColorScheme(primary: "#3182CE", secondary: "#2B6CB0", accent: "#63B3ED", background: "#EBF8FF", text: "#2D3748"),
        headerStyle: .specialty,
        contentStyle: .detailed
    )

    static let oncology = ReportTemplate(
        name: "oncology",
        displayName: "Oncology Report",
        sections: [.patientInfo, .studyInfo, .tumorAssessment, .measurements, .stagingInfo, .findings, .impressions, .recommendations],
        colorScheme: ColorScheme(primary: "#805AD5", secondary: "#6B46C1", accent: "#B794F4", background: "#FAF5FF", text: "#2D3748"),
        headerStyle: .specialty,
        contentStyle: .detailed
    )

    /// Resolve a template by name
    static func resolve(name: String) -> ReportTemplate {
        switch name.lowercased() {
        case "cardiology": return .cardiology
        case "radiology": return .radiology
        case "oncology": return .oncology
        default: return .default
        }
    }
}

/// Report section types for template-driven ordering
enum ReportSection: String {
    case patientInfo = "patient_info"
    case studyInfo = "study_info"
    case indication = "indication"
    case technique = "technique"
    case findings = "findings"
    case cardiacFindings = "cardiac_findings"
    case tumorAssessment = "tumor_assessment"
    case stagingInfo = "staging_info"
    case hemodynamics = "hemodynamics"
    case measurements = "measurements"
    case impressions = "impressions"
    case recommendations = "recommendations"

    var displayName: String {
        switch self {
        case .patientInfo: return "Patient Information"
        case .studyInfo: return "Study Information"
        case .indication: return "Clinical Indication"
        case .technique: return "Technique"
        case .findings: return "Findings"
        case .cardiacFindings: return "Cardiac Findings"
        case .tumorAssessment: return "Tumor Assessment"
        case .stagingInfo: return "Staging Information"
        case .hemodynamics: return "Hemodynamic Parameters"
        case .measurements: return "Measurements"
        case .impressions: return "Impressions"
        case .recommendations: return "Recommendations"
        }
    }
}

/// Color scheme for report styling
struct ColorScheme {
    let primary: String
    let secondary: String
    let accent: String
    let background: String
    let text: String
}

/// Header rendering style
enum HeaderStyle {
    case standard
    case specialty
}

/// Content detail level
enum ContentStyle {
    case summary
    case detailed
}

// MARK: - Image Embedding

/// Handles embedding of referenced images into reports
struct ImageEmbedder {
    let imageDirectory: String?

    /// Attempt to load an image file as base64 data for embedding
    func loadImageAsBase64(sopInstanceUID: String) -> String? {
        guard let dir = imageDirectory else { return nil }

        // Look for image files matching the SOP Instance UID
        let possibleExtensions = ["dcm", "png", "jpg", "jpeg", "tiff"]
        let fileManager = FileManager.default

        for ext in possibleExtensions {
            let filePath = (dir as NSString).appendingPathComponent("\(sopInstanceUID).\(ext)")
            if fileManager.fileExists(atPath: filePath),
               let data = fileManager.contents(atPath: filePath) {
                let mimeType = mimeTypeForExtension(ext)
                return "data:\(mimeType);base64,\(data.base64EncodedString())"
            }
        }

        return nil
    }

    /// Load a logo image file as base64
    func loadLogoAsBase64(path: String) -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path),
              let data = fileManager.contents(atPath: path) else {
            return nil
        }
        let ext = (path as NSString).pathExtension.lowercased()
        let mimeType = mimeTypeForExtension(ext)
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "tiff", "tif": return "image/tiff"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Branding Configuration

/// Branding and customization settings for reports
struct BrandingConfiguration {
    let institutionName: String?
    let logoBase64: String?
    let headerColor: String?
    let footerText: String?
    let showGenerationDate: Bool

    init(logoPath: String?, footerText: String?, institutionName: String? = nil,
         headerColor: String? = nil, showGenerationDate: Bool = true) {
        self.institutionName = institutionName
        self.footerText = footerText
        self.headerColor = headerColor
        self.showGenerationDate = showGenerationDate

        if let path = logoPath {
            self.logoBase64 = ImageEmbedder(imageDirectory: nil).loadLogoAsBase64(path: path)
        } else {
            self.logoBase64 = nil
        }
    }
}

// MARK: - Multi-Language Support

/// Language configuration for report localization
enum ReportLanguage: String {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    /// Localized section headers
    func localizedSectionName(_ section: ReportSection) -> String {
        switch self {
        case .english:
            return section.displayName
        case .spanish:
            return spanishSectionName(section)
        case .french:
            return frenchSectionName(section)
        case .german:
            return germanSectionName(section)
        }
    }

    private func spanishSectionName(_ section: ReportSection) -> String {
        switch section {
        case .patientInfo: return "Información del Paciente"
        case .studyInfo: return "Información del Estudio"
        case .indication: return "Indicación Clínica"
        case .technique: return "Técnica"
        case .findings: return "Hallazgos"
        case .cardiacFindings: return "Hallazgos Cardíacos"
        case .tumorAssessment: return "Evaluación del Tumor"
        case .stagingInfo: return "Información de Estadificación"
        case .hemodynamics: return "Parámetros Hemodinámicos"
        case .measurements: return "Mediciones"
        case .impressions: return "Impresiones"
        case .recommendations: return "Recomendaciones"
        }
    }

    private func frenchSectionName(_ section: ReportSection) -> String {
        switch section {
        case .patientInfo: return "Informations Patient"
        case .studyInfo: return "Informations de l'Étude"
        case .indication: return "Indication Clinique"
        case .technique: return "Technique"
        case .findings: return "Résultats"
        case .cardiacFindings: return "Résultats Cardiaques"
        case .tumorAssessment: return "Évaluation Tumorale"
        case .stagingInfo: return "Informations de Stadification"
        case .hemodynamics: return "Paramètres Hémodynamiques"
        case .measurements: return "Mesures"
        case .impressions: return "Impressions"
        case .recommendations: return "Recommandations"
        }
    }

    private func germanSectionName(_ section: ReportSection) -> String {
        switch section {
        case .patientInfo: return "Patienteninformationen"
        case .studyInfo: return "Studieninformationen"
        case .indication: return "Klinische Indikation"
        case .technique: return "Technik"
        case .findings: return "Befunde"
        case .cardiacFindings: return "Kardiale Befunde"
        case .tumorAssessment: return "Tumorbewertung"
        case .stagingInfo: return "Staging-Informationen"
        case .hemodynamics: return "Hämodynamische Parameter"
        case .measurements: return "Messungen"
        case .impressions: return "Beurteilung"
        case .recommendations: return "Empfehlungen"
        }
    }

    /// Localized labels
    func localizedLabel(_ key: String) -> String {
        switch self {
        case .english:
            return key
        case .spanish:
            return spanishLabel(key)
        case .french:
            return frenchLabel(key)
        case .german:
            return germanLabel(key)
        }
    }

    private func spanishLabel(_ key: String) -> String {
        let labels: [String: String] = [
            "Patient": "Paciente",
            "Patient ID": "ID del Paciente",
            "Study Date": "Fecha del Estudio",
            "Accession Number": "Número de Acceso",
            "Measurement": "Medición",
            "Value": "Valor",
            "Units": "Unidades",
            "Generated": "Generado",
        ]
        return labels[key] ?? key
    }

    private func frenchLabel(_ key: String) -> String {
        let labels: [String: String] = [
            "Patient": "Patient",
            "Patient ID": "ID Patient",
            "Study Date": "Date de l'Étude",
            "Accession Number": "Numéro d'Accession",
            "Measurement": "Mesure",
            "Value": "Valeur",
            "Units": "Unités",
            "Generated": "Généré",
        ]
        return labels[key] ?? key
    }

    private func germanLabel(_ key: String) -> String {
        let labels: [String: String] = [
            "Patient": "Patient",
            "Patient ID": "Patienten-ID",
            "Study Date": "Studiendatum",
            "Accession Number": "Auftragsnummer",
            "Measurement": "Messung",
            "Value": "Wert",
            "Units": "Einheiten",
            "Generated": "Erstellt",
        ]
        return labels[key] ?? key
    }
}

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
    let language: ReportLanguage

    init(format: ReportFormat, template: String, embedImages: Bool,
         imageDirectory: String?, customTitle: String?, logoPath: String?,
         footerText: String?, includeMeasurements: Bool, includeSummary: Bool,
         language: ReportLanguage = .english) {
        self.format = format
        self.template = template
        self.embedImages = embedImages
        self.imageDirectory = imageDirectory
        self.customTitle = customTitle
        self.logoPath = logoPath
        self.footerText = footerText
        self.includeMeasurements = includeMeasurements
        self.includeSummary = includeSummary
        self.language = language
    }
}

/// Main report generator
struct ReportGenerator {
    let document: SRDocument
    let options: ReportOptions

    private var template: ReportTemplate {
        ReportTemplate.resolve(name: options.template)
    }

    private var imageEmbedder: ImageEmbedder {
        ImageEmbedder(imageDirectory: options.imageDirectory)
    }

    private var branding: BrandingConfiguration {
        BrandingConfiguration(logoPath: options.logoPath, footerText: options.footerText)
    }

    private var language: ReportLanguage {
        options.language
    }

    func generate() throws -> Data {
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
        let resolvedTemplate = template

        // Header
        output += "=" + String(repeating: "=", count: 78) + "\n"
        output += centerText(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Structured Report", width: 80)
        if resolvedTemplate.name != "default" {
            output += centerText("(\(resolvedTemplate.displayName))", width: 80)
        }
        output += "=" + String(repeating: "=", count: 78) + "\n\n"

        // Render sections in template-defined order
        for section in resolvedTemplate.sections {
            output += renderTextSection(section)
        }

        // Footer
        if let footer = options.footerText {
            output += "\n" + "-" + String(repeating: "-", count: 78) + "\n"
            output += centerText(footer, width: 80)
        }

        return Data(output.utf8)
    }

    private func renderTextSection(_ section: ReportSection) -> String {
        var output = ""
        let sectionName = language.localizedSectionName(section)

        switch section {
        case .patientInfo:
            if let patientName = document.patientName {
                output += "\(language.localizedLabel("Patient")): \(patientName)\n"
            }
            if let patientID = document.patientID {
                output += "\(language.localizedLabel("Patient ID")): \(patientID)\n"
            }
        case .studyInfo:
            if let studyDate = document.studyDate {
                output += "\(language.localizedLabel("Study Date")): \(formatDate(studyDate))\n"
            }
            if let accessionNumber = document.accessionNumber {
                output += "\(language.localizedLabel("Accession Number")): \(accessionNumber)\n"
            }
            output += "\n" + "-" + String(repeating: "-", count: 78) + "\n\n"
        case .findings, .cardiacFindings, .tumorAssessment:
            output += renderContentTree(document.rootContent, level: 0)
        case .measurements, .hemodynamics:
            if options.includeMeasurements {
                let measurements = extractMeasurements()
                if !measurements.isEmpty {
                    output += "\n" + "-" + String(repeating: "-", count: 78) + "\n"
                    output += "\(sectionName.uppercased())\n"
                    output += "-" + String(repeating: "-", count: 78) + "\n\n"
                    for measurement in measurements {
                        output += "\(measurement.name): \(measurement.value) \(measurement.units)\n"
                    }
                }
            }
        case .impressions, .recommendations, .indication, .technique, .stagingInfo:
            // These sections extract content by matching concept names in the SR tree
            let sectionContent = findContentForSection(section)
            if !sectionContent.isEmpty {
                output += "\n" + "-" + String(repeating: "-", count: 78) + "\n"
                output += "\(sectionName.uppercased())\n"
                output += "-" + String(repeating: "-", count: 78) + "\n\n"
                output += sectionContent
            }
        }

        return output
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
        let resolvedTemplate = template
        let colors = resolvedTemplate.colorScheme

        var html = """
        <!DOCTYPE html>
        <html lang="\(language.rawValue)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Report"))</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 900px;
                    margin: 40px auto;
                    padding: 20px;
                    background: \(colors.background);
                    color: \(colors.text);
                }
                .report {
                    background: white;
                    padding: 40px;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                .header {
                    text-align: center;
                    border-bottom: 3px solid \(colors.primary);
                    padding-bottom: 20px;
                    margin-bottom: 30px;
                }
                .header h1 {
                    margin: 0 0 10px 0;
                    color: \(colors.text);
                }
                .header .template-badge {
                    display: inline-block;
                    background: \(colors.primary);
                    color: white;
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 0.85em;
                    margin-top: 8px;
                }
                .logo {
                    max-height: 60px;
                    margin-bottom: 10px;
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
                .section-header {
                    color: \(colors.primary);
                    border-bottom: 2px solid \(colors.accent);
                    padding-bottom: 8px;
                    margin-top: 30px;
                    margin-bottom: 15px;
                }
                .content-item {
                    margin: 15px 0;
                    padding: 10px;
                    border-left: 3px solid \(colors.primary);
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
                    color: \(colors.primary);
                }
                .item-value {
                    margin-top: 5px;
                    color: \(colors.text);
                }
                .embedded-image {
                    max-width: 100%;
                    margin: 15px 0;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    padding: 4px;
                }
                .measurements {
                    margin-top: 30px;
                    border-top: 2px solid #eee;
                    padding-top: 20px;
                }
                .measurements h2 {
                    color: \(colors.text);
                }
                .measurement-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-top: 15px;
                }
                .measurement-table th {
                    background: \(colors.primary);
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
                .generation-date {
                    font-size: 0.8em;
                    color: #999;
                    margin-top: 8px;
                }
            </style>
        </head>
        <body>
            <div class="report">
        """

        // Header with branding
        html += """
                <div class="header">
        """

        if let logoBase64 = branding.logoBase64 {
            html += """
                    <img src="\(logoBase64)" alt="Logo" class="logo">
            """
        } else if let logoPath = options.logoPath {
            html += """
                    <img src="file://\(escapeHTML(logoPath))" alt="Logo" class="logo">
            """
        }

        html += """
                    <h1>\(escapeHTML(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Structured Report"))</h1>
        """

        if let docType = document.documentType {
            html += """
                    <p style="color: #666; margin: 5px 0 0 0;">\(escapeHTML(docType.description))</p>
            """
        }

        if resolvedTemplate.name != "default" {
            html += """
                    <span class="template-badge">\(escapeHTML(resolvedTemplate.displayName))</span>
            """
        }

        html += """
                </div>
        """

        // Render sections in template-defined order
        for section in resolvedTemplate.sections {
            html += renderHTMLSection(section)
        }

        // Embedded images
        if options.embedImages {
            let imageItems = collectImageItems()
            if !imageItems.isEmpty {
                html += """
                    <div class="section-header">
                        <h2>\(escapeHTML(language.localizedLabel("Referenced Images")))</h2>
                    </div>
                """
                for imageItem in imageItems {
                    let uid = imageItem.imageReference.sopReference.sopInstanceUID
                    if let base64 = imageEmbedder.loadImageAsBase64(sopInstanceUID: uid) {
                        html += """
                            <img src="\(base64)" alt="Referenced Image \(escapeHTML(uid))" class="embedded-image">
                        """
                    } else {
                        html += """
                            <p><em>Image referenced: \(escapeHTML(uid))</em></p>
                        """
                    }
                }
            }
        }

        // Footer
        html += """
                <div class="footer">
        """
        if let footer = options.footerText {
            html += """
                    <p>\(escapeHTML(footer))</p>
            """
        }
        if branding.showGenerationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            html += """
                    <p class="generation-date">\(language.localizedLabel("Generated")): \(dateFormatter.string(from: Date()))</p>
            """
        }
        html += """
                </div>
            </div>
        </body>
        </html>
        """

        return Data(html.utf8)
    }

    private func renderHTMLSection(_ section: ReportSection) -> String {
        var html = ""
        let sectionName = language.localizedSectionName(section)

        switch section {
        case .patientInfo:
            html += """
                    <div class="patient-info">
                        <table>
            """
            if let patientName = document.patientName {
                html += """
                            <tr><td>\(escapeHTML(language.localizedLabel("Patient"))):</td><td>\(escapeHTML(patientName))</td></tr>
                """
            }
            if let patientID = document.patientID {
                html += """
                            <tr><td>\(escapeHTML(language.localizedLabel("Patient ID"))):</td><td>\(escapeHTML(patientID))</td></tr>
                """
            }
            html += """
                        </table>
                    </div>
            """
        case .studyInfo:
            html += """
                    <div class="patient-info">
                        <table>
            """
            if let studyDate = document.studyDate {
                html += """
                            <tr><td>\(escapeHTML(language.localizedLabel("Study Date"))):</td><td>\(formatDate(studyDate))</td></tr>
                """
            }
            if let accessionNumber = document.accessionNumber {
                html += """
                            <tr><td>\(escapeHTML(language.localizedLabel("Accession Number"))):</td><td>\(escapeHTML(accessionNumber))</td></tr>
                """
            }
            html += """
                        </table>
                    </div>
            """
        case .findings, .cardiacFindings, .tumorAssessment:
            html += """
                    <div class="section-header"><h2>\(escapeHTML(sectionName))</h2></div>
            """
            html += renderHTMLContentTree(document.rootContent, level: 0)
        case .measurements, .hemodynamics:
            if options.includeMeasurements {
                let measurements = extractMeasurements()
                if !measurements.isEmpty {
                    html += """
                    <div class="measurements">
                        <h2>\(escapeHTML(sectionName))</h2>
                        <table class="measurement-table">
                            <thead>
                                <tr>
                                    <th>\(escapeHTML(language.localizedLabel("Measurement")))</th>
                                    <th>\(escapeHTML(language.localizedLabel("Value")))</th>
                                    <th>\(escapeHTML(language.localizedLabel("Units")))</th>
                                </tr>
                            </thead>
                            <tbody>
                    """
                    for measurement in measurements {
                        html += """
                                <tr>
                                    <td>\(escapeHTML(measurement.name))</td>
                                    <td>\(escapeHTML(measurement.value))</td>
                                    <td>\(escapeHTML(measurement.units))</td>
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
        case .impressions, .recommendations, .indication, .technique, .stagingInfo:
            let sectionContent = findContentForSection(section)
            if !sectionContent.isEmpty {
                html += """
                    <div class="section-header"><h2>\(escapeHTML(sectionName))</h2></div>
                    <div class="content-item"><div class="item-value">\(escapeHTML(sectionContent))</div></div>
                """
            }
        }

        return html
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
        let resolvedTemplate = template
        let report: [String: Any] = [
            "document_type": document.documentType?.description ?? "Unknown",
            "sop_class_uid": document.sopClassUID,
            "sop_instance_uid": document.sopInstanceUID,
            "title": options.customTitle ?? document.documentTitle?.codeMeaning ?? "",
            "template": [
                "name": resolvedTemplate.name,
                "display_name": resolvedTemplate.displayName,
                "sections": resolvedTemplate.sections.map { $0.rawValue }
            ],
            "language": language.rawValue,
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
            } : [],
            "referenced_images": collectImageItems().map { imageItem in
                [
                    "sop_instance_uid": imageItem.imageReference.sopReference.sopInstanceUID,
                    "sop_class_uid": imageItem.imageReference.sopReference.sopClassUID
                ]
            }
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
        let resolvedTemplate = template

        // Title
        md += "# \(options.customTitle ?? document.documentTitle?.codeMeaning ?? "DICOM Structured Report")\n\n"

        if let docType = document.documentType {
            md += "*\(docType.description)*\n\n"
        }

        if resolvedTemplate.name != "default" {
            md += "**Template:** \(resolvedTemplate.displayName)\n\n"
        }

        // Render sections in template-defined order
        for section in resolvedTemplate.sections {
            md += renderMarkdownSection(section)
        }

        // Embedded image references
        if options.embedImages {
            let imageItems = collectImageItems()
            if !imageItems.isEmpty {
                md += "\n---\n\n"
                md += "## Referenced Images\n\n"
                for imageItem in imageItems {
                    let uid = imageItem.imageReference.sopReference.sopInstanceUID
                    md += "- Image: `\(uid)`\n"
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

    private func renderMarkdownSection(_ section: ReportSection) -> String {
        var md = ""
        let sectionName = language.localizedSectionName(section)

        switch section {
        case .patientInfo:
            md += "## \(sectionName)\n\n"
            if let patientName = document.patientName {
                md += "- **\(language.localizedLabel("Patient")):** \(patientName)\n"
            }
            if let patientID = document.patientID {
                md += "- **\(language.localizedLabel("Patient ID")):** \(patientID)\n"
            }
            md += "\n"
        case .studyInfo:
            md += "## \(sectionName)\n\n"
            if let studyDate = document.studyDate {
                md += "- **\(language.localizedLabel("Study Date")):** \(formatDate(studyDate))\n"
            }
            if let accessionNumber = document.accessionNumber {
                md += "- **\(language.localizedLabel("Accession Number")):** \(accessionNumber)\n"
            }
            md += "\n---\n\n"
        case .findings, .cardiacFindings, .tumorAssessment:
            md += "## \(sectionName)\n\n"
            md += renderMarkdownContentTree(document.rootContent, level: 0)
        case .measurements, .hemodynamics:
            if options.includeMeasurements {
                let measurements = extractMeasurements()
                if !measurements.isEmpty {
                    md += "\n---\n\n"
                    md += "## \(sectionName)\n\n"
                    md += "| \(language.localizedLabel("Measurement")) | \(language.localizedLabel("Value")) | \(language.localizedLabel("Units")) |\n"
                    md += "|-------------|-------|-------|\n"
                    for measurement in measurements {
                        md += "| \(measurement.name) | \(measurement.value) | \(measurement.units) |\n"
                    }
                    md += "\n"
                }
            }
        case .impressions, .recommendations, .indication, .technique, .stagingInfo:
            let sectionContent = findContentForSection(section)
            if !sectionContent.isEmpty {
                md += "## \(sectionName)\n\n"
                md += "\(sectionContent)\n\n"
            }
        }

        return md
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

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func extractMeasurements() -> [ReportMeasurement] {
        var measurements: [ReportMeasurement] = []

        func collectMeasurements(from item: AnyContentItem) {
            if let numItem = item.asNumeric {
                let name = item.conceptName?.codeMeaning ?? "Measurement"
                let value: String
                if let firstValue = numItem.numericValues.first {
                    value = String(firstValue)
                } else {
                    value = "N/A"
                }
                let units = numItem.measurementUnits?.codeMeaning ?? ""
                measurements.append(ReportMeasurement(name: name, value: value, units: units))
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

    /// Collect all image content items from the SR document tree
    private func collectImageItems() -> [ImageContentItem] {
        var images: [ImageContentItem] = []

        func collect(from item: AnyContentItem) {
            if let imageItem = item.asImage {
                images.append(imageItem)
            }
            if let container = item.asContainer {
                for child in container.contentItems {
                    collect(from: child)
                }
            }
        }

        for child in document.rootContent.contentItems {
            collect(from: child)
        }

        return images
    }

    /// Find content items matching a report section by concept name keywords
    private func findContentForSection(_ section: ReportSection) -> String {
        let keywords: [String]
        switch section {
        case .impressions:
            keywords = ["impression", "conclusion", "summary"]
        case .recommendations:
            keywords = ["recommendation", "follow-up", "followup", "action"]
        case .indication:
            keywords = ["indication", "clinical information", "reason", "history"]
        case .technique:
            keywords = ["technique", "procedure", "protocol", "method"]
        case .stagingInfo:
            keywords = ["staging", "stage", "tnm", "grade"]
        default:
            return ""
        }

        var results: [String] = []

        func searchContent(in item: AnyContentItem) {
            if let name = item.conceptName?.codeMeaning.lowercased() {
                for keyword in keywords {
                    if name.contains(keyword) {
                        results.append(formatContentValue(item))
                        break
                    }
                }
            }
            if let container = item.asContainer {
                for child in container.contentItems {
                    searchContent(in: child)
                }
            }
        }

        for child in document.rootContent.contentItems {
            searchContent(in: child)
        }

        return results.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

struct ReportMeasurement {
    let name: String
    let value: String
    let units: String
}

enum ReportError: LocalizedError {
    case pdfNotImplemented
    case invalidTemplate
    case imageNotFound(String)
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .pdfNotImplemented:
            return "PDF generation requires additional libraries. Use HTML or Markdown format instead."
        case .invalidTemplate:
            return "Invalid report template specified"
        case .imageNotFound(let path):
            return "Image not found: \(path)"
        case .unsupportedLanguage(let lang):
            return "Unsupported report language: \(lang)"
        }
    }
}
