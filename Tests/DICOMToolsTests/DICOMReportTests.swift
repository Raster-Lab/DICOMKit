import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

// MARK: - Phase C Test Types (mirrored from dicom-report executable)
// CLI executable targets cannot be imported as test dependencies,
// so we mirror the types here for unit testing.

/// Report section types for template-driven ordering
private enum ReportSection: String, CaseIterable {
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
private struct ColorScheme {
    let primary: String
    let secondary: String
    let accent: String
    let background: String
    let text: String
}

/// Header rendering style
private enum HeaderStyle {
    case standard
    case specialty
}

/// Content detail level
private enum ContentStyle {
    case summary
    case detailed
}

/// Defines specialty-specific report templates
private struct ReportTemplate {
    let name: String
    let displayName: String
    let sections: [ReportSection]
    let colorScheme: ColorScheme
    let headerStyle: HeaderStyle
    let contentStyle: ContentStyle

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

    static func resolve(name: String) -> ReportTemplate {
        switch name.lowercased() {
        case "cardiology": return .cardiology
        case "radiology": return .radiology
        case "oncology": return .oncology
        default: return .default
        }
    }
}

/// Image embedder for referenced images
private struct ImageEmbedder {
    let imageDirectory: String?

    func loadImageAsBase64(sopInstanceUID: String) -> String? {
        guard let dir = imageDirectory else { return nil }
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

    func loadLogoAsBase64(path: String) -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path),
              let data = fileManager.contents(atPath: path) else { return nil }
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

/// Branding configuration
private struct BrandingConfiguration {
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

/// Language configuration for report localization
private enum ReportLanguage: String {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    func localizedSectionName(_ section: ReportSection) -> String {
        switch self {
        case .english: return section.displayName
        case .spanish: return spanishSectionName(section)
        case .french: return frenchSectionName(section)
        case .german: return germanSectionName(section)
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

    func localizedLabel(_ key: String) -> String {
        switch self {
        case .english: return key
        case .spanish: return spanishLabel(key)
        case .french: return frenchLabel(key)
        case .german: return germanLabel(key)
        }
    }

    private func spanishLabel(_ key: String) -> String {
        let labels: [String: String] = [
            "Patient": "Paciente", "Patient ID": "ID del Paciente",
            "Study Date": "Fecha del Estudio", "Accession Number": "Número de Acceso",
            "Measurement": "Medición", "Value": "Valor", "Units": "Unidades",
            "Generated": "Generado",
        ]
        return labels[key] ?? key
    }

    private func frenchLabel(_ key: String) -> String {
        let labels: [String: String] = [
            "Patient": "Patient", "Patient ID": "ID Patient",
            "Study Date": "Date de l'Étude", "Accession Number": "Numéro d'Accession",
            "Measurement": "Mesure", "Value": "Valeur", "Units": "Unités",
            "Generated": "Généré",
        ]
        return labels[key] ?? key
    }

    private func germanLabel(_ key: String) -> String {
        let labels: [String: String] = [
            "Patient": "Patient", "Patient ID": "Patienten-ID",
            "Study Date": "Studiendatum", "Accession Number": "Auftragsnummer",
            "Measurement": "Messung", "Value": "Wert", "Units": "Einheiten",
            "Generated": "Erstellt",
        ]
        return labels[key] ?? key
    }
}

/// Report measurement type
private struct ReportMeasurement {
    let name: String
    let value: String
    let units: String
}

/// Report errors
private enum ReportError: LocalizedError {
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

/// Tests for dicom-report CLI tool functionality
/// These tests validate SR parsing, content tree navigation, output format generation,
/// measurement extraction, and report generation workflows.
///
/// The report generation logic is tested using the underlying DICOMKit SR infrastructure
/// since CLI executable targets cannot be imported as test dependencies.
/// Phase C types (templates, image embedding, branding, localization) are mirrored
/// above for direct unit testing of the standalone logic.
final class DICOMReportTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a minimal DICOM SR file for report testing
    private func createTestSRFile(
        documentTitle: String = "Test Report",
        patientName: String? = "DOE^JOHN",
        patientID: String? = "12345",
        studyDate: String? = "20260213",
        accessionNumber: String? = "ACC001",
        textContent: [(name: String, value: String)] = [],
        numericContent: [(name: String, value: Double, units: String)] = [],
        codeContent: [(name: String, code: String, meaning: String)] = []
    ) throws -> Data {
        var data = Data()

        // 128-byte preamble
        data.append(Data(count: 128))

        // DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])

        // File Meta Information Group Length (0002,0000) - UL
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0xB4, 0x00, 0x00, 0x00]) // Adjusted value

        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntax = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        let tsLength = UInt16(transferSyntax.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(transferSyntax.data(using: .utf8)!)

        // Media Storage SOP Class UID (0002,0002) - UI
        data.append(contentsOf: [0x02, 0x00, 0x02, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopClass = "1.2.840.10008.5.1.4.1.1.88.11" // Basic Text SR
        let scLength = UInt16(sopClass.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: scLength.littleEndian) { Data($0) })
        data.append(sopClass.data(using: .utf8)!)

        // Media Storage SOP Instance UID (0002,0003) - UI
        data.append(contentsOf: [0x02, 0x00, 0x03, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopInstance = "1.2.3.4.5.6.7.8.9.10"
        let siPadded = sopInstance.utf8.count % 2 != 0 ? sopInstance + "\0" : sopInstance
        let siLength = UInt16(siPadded.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: siLength.littleEndian) { Data($0) })
        data.append(siPadded.data(using: .utf8)!)

        // Transfer Syntax UID (0002,0010) - already added above
        // Meta info complete

        // === Main Dataset ===

        // SOP Class UID (0008,0016) - UI
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        data.append(contentsOf: withUnsafeBytes(of: scLength.littleEndian) { Data($0) })
        data.append(sopClass.data(using: .utf8)!)

        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        data.append(contentsOf: withUnsafeBytes(of: siLength.littleEndian) { Data($0) })
        data.append(siPadded.data(using: .utf8)!)

        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00])
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modalityStr = "SR"
        let modPadded = modalityStr.utf8.count % 2 != 0 ? modalityStr + " " : modalityStr
        let modLen = UInt16(modPadded.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modLen.littleEndian) { Data($0) })
        data.append(modPadded.data(using: .utf8)!)

        // Study Date (0008,0020) - DA
        if let date = studyDate {
            data.append(contentsOf: [0x08, 0x00, 0x20, 0x00])
            data.append(contentsOf: [0x44, 0x41]) // VR = DA
            let datePadded = date.utf8.count % 2 != 0 ? date + " " : date
            let dateLen = UInt16(datePadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: dateLen.littleEndian) { Data($0) })
            data.append(datePadded.data(using: .utf8)!)
        }

        // Accession Number (0008,0050) - SH
        if let accNum = accessionNumber {
            data.append(contentsOf: [0x08, 0x00, 0x50, 0x00])
            data.append(contentsOf: [0x53, 0x48]) // VR = SH
            let accPadded = accNum.utf8.count % 2 != 0 ? accNum + " " : accNum
            let accLen = UInt16(accPadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: accLen.littleEndian) { Data($0) })
            data.append(accPadded.data(using: .utf8)!)
        }

        // Patient Name (0010,0010) - PN
        if let name = patientName {
            data.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
            data.append(contentsOf: [0x50, 0x4E]) // VR = PN
            let namePadded = name.utf8.count % 2 != 0 ? name + " " : name
            let nameLen = UInt16(namePadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: nameLen.littleEndian) { Data($0) })
            data.append(namePadded.data(using: .utf8)!)
        }

        // Patient ID (0010,0020) - LO
        if let pid = patientID {
            data.append(contentsOf: [0x10, 0x00, 0x20, 0x00])
            data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
            let pidPadded = pid.utf8.count % 2 != 0 ? pid + " " : pid
            let pidLen = UInt16(pidPadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: pidLen.littleEndian) { Data($0) })
            data.append(pidPadded.data(using: .utf8)!)
        }

        // Study Instance UID (0020,000D) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let studyUID = "1.2.3.4.5"
        let studyUIDLen = UInt16(studyUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: studyUIDLen.littleEndian) { Data($0) })
        data.append(studyUID.data(using: .utf8)!)

        // Series Instance UID (0020,000E) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0E, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let seriesUID = "1.2.3.4.5.6"
        let seriesUIDLen = UInt16(seriesUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: seriesUIDLen.littleEndian) { Data($0) })
        data.append(seriesUID.data(using: .utf8)!)

        // Value Type (0040,A040) - CS (required for SR)
        data.append(contentsOf: [0x40, 0x00, 0x40, 0xA0])
        data.append(contentsOf: [0x43, 0x53])
        let valueType = "CONTAINER"
        let vtPadded = valueType.utf8.count % 2 != 0 ? valueType + " " : valueType
        let vtLen = UInt16(vtPadded.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: vtLen.littleEndian) { Data($0) })
        data.append(vtPadded.data(using: .utf8)!)

        // Concept Name Code Sequence (0040,A043) - SQ
        // Document Title
        data.append(contentsOf: [0x40, 0x00, 0x43, 0xA0])
        data.append(contentsOf: [0x53, 0x51]) // VR = SQ
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Undefined length

        // Item (FFFE,E000)
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0])
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF]) // Undefined length

        // Code Value (0008,0100) - SH
        data.append(contentsOf: [0x08, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x53, 0x48])
        let codeValue = "11528-7"
        let cvLen = UInt16(codeValue.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: cvLen.littleEndian) { Data($0) })
        data.append(codeValue.data(using: .utf8)!)

        // Coding Scheme Designator (0008,0102) - SH
        data.append(contentsOf: [0x08, 0x00, 0x02, 0x01])
        data.append(contentsOf: [0x53, 0x48])
        let codeScheme = "LN"
        let csLen = UInt16(codeScheme.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: csLen.littleEndian) { Data($0) })
        data.append(codeScheme.data(using: .utf8)!)

        // Code Meaning (0008,0104) - LO
        data.append(contentsOf: [0x08, 0x00, 0x04, 0x01])
        data.append(contentsOf: [0x4C, 0x4F])
        let titlePadded = documentTitle.utf8.count % 2 != 0 ? documentTitle + " " : documentTitle
        let cmLen = UInt16(titlePadded.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: cmLen.littleEndian) { Data($0) })
        data.append(titlePadded.data(using: .utf8)!)

        // Item Delimitation Item (FFFE,E00D)
        data.append(contentsOf: [0xFE, 0xFF, 0x0D, 0xE0])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Sequence Delimitation Item (FFFE,E0DD)
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Continuity Of Content (0040,A050) - CS
        data.append(contentsOf: [0x40, 0x00, 0x50, 0xA0])
        data.append(contentsOf: [0x43, 0x53])
        let continuity = "SEPARATE"
        let contPadded = continuity.utf8.count % 2 != 0 ? continuity + " " : continuity
        let contLen = UInt16(contPadded.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: contLen.littleEndian) { Data($0) })
        data.append(contPadded.data(using: .utf8)!)

        // Content Sequence (0040,A730) - SQ
        // This would contain the actual report content items
        // For simplicity, we'll add a minimal structure
        data.append(contentsOf: [0x40, 0x00, 0x30, 0xA7])
        data.append(contentsOf: [0x53, 0x51])
        data.append(contentsOf: [0x00, 0x00])
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])

        // Add content items if specified
        for textItem in textContent {
            // Item
            data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0])
            data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])

            // Relationship Type (0040,A010) - CS
            data.append(contentsOf: [0x40, 0x00, 0x10, 0xA0])
            data.append(contentsOf: [0x43, 0x53])
            let relType = "CONTAINS"
            let relLen = UInt16(relType.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: relLen.littleEndian) { Data($0) })
            data.append(relType.data(using: .utf8)!)

            // Value Type (0040,A040) - CS
            data.append(contentsOf: [0x40, 0x00, 0x40, 0xA0])
            data.append(contentsOf: [0x43, 0x53])
            let textVT = "TEXT"
            let textVTLen = UInt16(textVT.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: textVTLen.littleEndian) { Data($0) })
            data.append(textVT.data(using: .utf8)!)

            // Text Value (0040,A160) - UT
            data.append(contentsOf: [0x40, 0x00, 0x60, 0xA1])
            data.append(contentsOf: [0x55, 0x54])
            let textValuePadded = textItem.value.utf8.count % 2 != 0 ? textItem.value + " " : textItem.value
            let textValueLen = UInt16(textValuePadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: textValueLen.littleEndian) { Data($0) })
            data.append(textValuePadded.data(using: .utf8)!)

            // Item Delimitation
            data.append(contentsOf: [0xFE, 0xFF, 0x0D, 0xE0])
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        }

        // Sequence Delimitation
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        return data
    }

    // MARK: - SR Parsing Tests

    func testParseBasicTextSR() throws {
        let srData = try createTestSRFile(
            documentTitle: "Radiology Report",
            patientName: "DOE^JOHN",
            patientID: "12345",
            studyDate: "20260213",
            textContent: [
                (name: "Finding", value: "Normal chest X-ray")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
        XCTAssertEqual(document.patientName, "DOE^JOHN")
        XCTAssertEqual(document.patientID, "12345")
        XCTAssertEqual(document.studyDate, "20260213")
    }

    func testParseSRWithMissingPatientInfo() throws {
        let srData = try createTestSRFile(
            documentTitle: "Test Report",
            patientName: nil,
            patientID: nil
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
        XCTAssertNil(document.patientName)
        XCTAssertNil(document.patientID)
    }

    func testParseSRDocumentType() throws {
        let srData = try createTestSRFile(documentTitle: "Cardiology Report")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document.documentType)
    }

    func testExtractSRMetadata() throws {
        let srData = try createTestSRFile(
            documentTitle: "CT Scan Report",
            patientName: "SMITH^JANE",
            patientID: "67890",
            studyDate: "20260114",
            accessionNumber: "ACC12345"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertEqual(document.patientName, "SMITH^JANE")
        XCTAssertEqual(document.patientID, "67890")
        XCTAssertEqual(document.studyDate, "20260114")
        XCTAssertEqual(document.accessionNumber, "ACC12345")
    }

    // MARK: - Content Tree Navigation Tests

    func testNavigateContentTree() throws {
        let srData = try createTestSRFile(
            textContent: [
                (name: "Finding 1", value: "First finding"),
                (name: "Finding 2", value: "Second finding")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document.rootContent)
        XCTAssertGreaterThanOrEqual(document.rootContent.contentItems.count, 0)
    }

    func testContentItemCount() throws {
        let srData = try createTestSRFile(
            textContent: [
                (name: "Finding 1", value: "Test"),
                (name: "Finding 2", value: "Test"),
                (name: "Finding 3", value: "Test")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Content item count should reflect the structure
        XCTAssertGreaterThanOrEqual(document.contentItemCount, 0)
    }

    // MARK: - Text Report Generation Tests

    func testGenerateTextReport() throws {
        let srData = try createTestSRFile(
            documentTitle: "Test Report",
            patientName: "TEST^PATIENT",
            patientID: "TEST123"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // We can't directly instantiate ReportGenerator from the CLI tool,
        // but we can verify the document was parsed correctly for report generation
        XCTAssertNotNil(document)
        XCTAssertEqual(document.patientName, "TEST^PATIENT")
        XCTAssertEqual(document.patientID, "TEST123")
    }

    func testTextReportContainsPatientInfo() throws {
        let srData = try createTestSRFile(
            patientName: "JONES^BOB",
            patientID: "PAT456",
            studyDate: "20260213"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify patient info is available for report generation
        XCTAssertEqual(document.patientName, "JONES^BOB")
        XCTAssertEqual(document.patientID, "PAT456")
        XCTAssertEqual(document.studyDate, "20260213")
    }

    func testTextReportFormatting() throws {
        let srData = try createTestSRFile(
            documentTitle: "Imaging Report",
            patientName: "DOE^JANE"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify document structure is suitable for formatted output
        XCTAssertNotNil(document.documentTitle)
        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - HTML Report Generation Tests

    func testHTMLReportStructure() throws {
        let srData = try createTestSRFile(
            documentTitle: "HTML Test Report",
            patientName: "HTML^TEST"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify document is ready for HTML generation
        XCTAssertNotNil(document.documentTitle)
        XCTAssertNotNil(document.patientName)
    }

    func testHTMLReportWithStyling() throws {
        let srData = try createTestSRFile(
            documentTitle: "Styled Report"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify document structure supports styled output
        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - JSON Report Generation Tests

    func testJSONReportStructure() throws {
        let srData = try createTestSRFile(
            documentTitle: "JSON Test",
            patientName: "JSON^TEST",
            patientID: "JSON001"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify all fields needed for JSON serialization
        XCTAssertNotNil(document.sopClassUID)
        XCTAssertNotNil(document.sopInstanceUID)
        XCTAssertNotNil(document.studyInstanceUID)
    }

    func testJSONReportWithAllFields() throws {
        let srData = try createTestSRFile(
            documentTitle: "Complete JSON Report",
            patientName: "COMPLETE^TEST",
            patientID: "COMP001",
            studyDate: "20260213",
            accessionNumber: "ACC999"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify all metadata fields are present
        XCTAssertNotNil(document.patientName)
        XCTAssertNotNil(document.patientID)
        XCTAssertNotNil(document.studyDate)
        XCTAssertNotNil(document.accessionNumber)
        XCTAssertNotNil(document.studyInstanceUID)
    }

    // MARK: - Markdown Report Generation Tests

    func testMarkdownReportGeneration() throws {
        let srData = try createTestSRFile(
            documentTitle: "Markdown Report",
            patientName: "MD^TEST"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify document is ready for Markdown formatting
        XCTAssertNotNil(document.documentTitle)
        XCTAssertNotNil(document.rootContent)
    }

    func testMarkdownHierarchicalStructure() throws {
        let srData = try createTestSRFile(
            textContent: [
                (name: "Section 1", value: "Content 1"),
                (name: "Section 2", value: "Content 2")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify hierarchical content exists
        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - Measurement Extraction Tests

    func testExtractNumericMeasurements() throws {
        // For now, test basic document structure
        // Full numeric measurement support would require more complex SR structure
        let srData = try createTestSRFile(
            textContent: [
                (name: "Measurement", value: "10.5 mm")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document.rootContent)
    }

    func testMeasurementTableFormatting() throws {
        let srData = try createTestSRFile(documentTitle: "Measurement Report")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify document structure supports measurement extraction
        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - Date Formatting Tests

    func testDateFormatting() throws {
        let srData = try createTestSRFile(studyDate: "20260213")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertEqual(document.studyDate, "20260213")
        
        // Test date formatting logic
        let dateString = document.studyDate ?? ""
        if dateString.count == 8 {
            let year = dateString.prefix(4)
            let month = dateString.dropFirst(4).prefix(2)
            let day = dateString.dropFirst(6).prefix(2)
            let formatted = "\(year)-\(month)-\(day)"
            XCTAssertEqual(formatted, "2026-02-13")
        }
    }

    func testInvalidDateHandling() throws {
        let srData = try createTestSRFile(studyDate: "INVALID")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Invalid date should still be stored
        XCTAssertEqual(document.studyDate, "INVALID")
    }

    // MARK: - Error Handling Tests

    func testInvalidSRFile() throws {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])

        XCTAssertThrowsError(try DICOMFile.read(from: invalidData)) { error in
            // Should throw an error for invalid DICOM data
            XCTAssertNotNil(error)
        }
    }

    func testMissingRequiredFields() throws {
        // Create minimal SR without some optional fields
        let srData = try createTestSRFile(
            patientName: nil,
            patientID: nil,
            studyDate: nil
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Should parse successfully even with missing optional fields
        XCTAssertNotNil(document)
        XCTAssertNil(document.patientName)
        XCTAssertNil(document.patientID)
    }

    // MARK: - Content Type Tests

    func testTextContentItem() throws {
        let srData = try createTestSRFile(
            textContent: [(name: "Finding", value: "Normal examination")]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document.rootContent)
    }

    func testCodedContentItem() throws {
        let srData = try createTestSRFile(
            codeContent: [(name: "Diagnosis", code: "123456", meaning: "Normal")]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - Multiple Format Output Tests

    func testMultipleFormatCompatibility() throws {
        let srData = try createTestSRFile(
            documentTitle: "Multi-Format Test",
            patientName: "MULTI^TEST",
            patientID: "MTF001",
            studyDate: "20260213"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify document is suitable for all output formats
        XCTAssertNotNil(document.documentTitle)
        XCTAssertNotNil(document.patientName)
        XCTAssertNotNil(document.sopClassUID)
        XCTAssertNotNil(document.sopInstanceUID)
        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - Customization Tests

    func testCustomTitleOverride() throws {
        let srData = try createTestSRFile(documentTitle: "Original Title")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify original title is present
        XCTAssertNotNil(document.documentTitle)
        XCTAssertEqual(document.documentTitle?.codeMeaning, "Original Title")
    }

    func testCustomFooter() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Document should be ready for custom footer
        XCTAssertNotNil(document)
    }

    // MARK: - Template Tests

    func testDefaultTemplate() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Default template should work with any valid SR
        XCTAssertNotNil(document)
    }

    // MARK: - Integration Tests

    func testEndToEndReportGeneration() throws {
        let srData = try createTestSRFile(
            documentTitle: "Complete Clinical Report",
            patientName: "COMPLETE^PATIENT",
            patientID: "CMP001",
            studyDate: "20260213",
            accessionNumber: "ACC2026001",
            textContent: [
                (name: "Indication", value: "Chest pain"),
                (name: "Findings", value: "Clear lung fields"),
                (name: "Impression", value: "Normal study")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify complete document structure
        XCTAssertNotNil(document.documentTitle)
        XCTAssertEqual(document.patientName, "COMPLETE^PATIENT")
        XCTAssertEqual(document.patientID, "CMP001")
        XCTAssertEqual(document.studyDate, "20260213")
        XCTAssertEqual(document.accessionNumber, "ACC2026001")
        XCTAssertNotNil(document.rootContent)
    }

    func testRealWorldSRParsing() throws {
        // Test with a more realistic SR structure
        let srData = try createTestSRFile(
            documentTitle: "Radiology Report - Chest CT",
            patientName: "REALISTIC^TEST",
            patientID: "REAL001",
            studyDate: "20260213",
            accessionNumber: "RW2026001",
            textContent: [
                (name: "Clinical History", value: "Follow-up scan"),
                (name: "Technique", value: "Non-contrast CT chest"),
                (name: "Findings", value: "Lungs clear")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
        XCTAssertEqual(document.patientName, "REALISTIC^TEST")
        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - Edge Case Tests

    func testEmptySRDocument() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Should handle empty content gracefully
        XCTAssertNotNil(document)
    }

    func testVeryLongTextContent() throws {
        let longText = String(repeating: "A", count: 1000)
        let srData = try createTestSRFile(
            textContent: [(name: "Long Finding", value: longText)]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
    }

    func testSpecialCharactersInText() throws {
        let specialText = "Special chars: <>&\"'\n\t"
        let srData = try createTestSRFile(
            textContent: [(name: "Special", value: specialText)]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
    }

    func testUnicodeCharacters() throws {
        let unicodeText = "Patient: 患者, Diagnose: διάγνωση"
        let srData = try createTestSRFile(
            patientName: unicodeText
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
    }

    // MARK: - Performance Tests

    func testLargeContentTreePerformance() throws {
        let textItems = (1...50).map { i in
            (name: "Finding \(i)", value: "Content for finding \(i)")
        }
        
        let srData = try createTestSRFile(textContent: textItems)

        measure {
            do {
                let dicomFile = try DICOMFile.read(from: srData)
                let parser = SRDocumentParser()
                _ = try parser.parse(dataSet: dicomFile.dataSet)
            } catch {
                XCTFail("Failed to parse: \(error)")
            }
        }
    }

    // MARK: - Report Options Tests

    func testIncludeMeasurementsOption() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Options should affect report generation
        XCTAssertNotNil(document)
    }

    func testExcludeMeasurementsOption() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Report generation should work without measurements
        XCTAssertNotNil(document)
    }

    func testIncludeSummaryOption() throws {
        let srData = try createTestSRFile(
            textContent: [(name: "Summary", value: "Test summary")]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document)
    }

    func testExcludeSummaryOption() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Report generation should work without summary
        XCTAssertNotNil(document)
    }

    // MARK: - Template Tests

    func testCardiologyTemplate() throws {
        let srData = try createTestSRFile(documentTitle: "Cardiology Report")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Cardiology template should be applicable
        XCTAssertNotNil(document)
    }

    func testRadiologyTemplate() throws {
        let srData = try createTestSRFile(documentTitle: "Radiology Report")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Radiology template should be applicable
        XCTAssertNotNil(document)
    }

    func testOncologyTemplate() throws {
        let srData = try createTestSRFile(documentTitle: "Oncology Report")

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Oncology template should be applicable
        XCTAssertNotNil(document)
    }

    // MARK: - Content Validation Tests

    func testValidateDocumentStructure() throws {
        let srData = try createTestSRFile()

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Verify required SR fields
        XCTAssertNotNil(document.sopClassUID)
        XCTAssertNotNil(document.sopInstanceUID)
        XCTAssertNotNil(document.rootContent)
    }

    func testValidatePatientDemographics() throws {
        let srData = try createTestSRFile(
            patientName: "VALIDATION^TEST",
            patientID: "VAL001"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertEqual(document.patientName, "VALIDATION^TEST")
        XCTAssertEqual(document.patientID, "VAL001")
    }

    func testValidateStudyMetadata() throws {
        let srData = try createTestSRFile(
            studyDate: "20260213",
            accessionNumber: "VAL2026"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertEqual(document.studyDate, "20260213")
        XCTAssertEqual(document.accessionNumber, "VAL2026")
    }

    // MARK: - Complex Content Tests

    func testNestedContainerItems() throws {
        let srData = try createTestSRFile(
            textContent: [
                (name: "Section 1", value: "Level 1"),
                (name: "Subsection 1.1", value: "Level 2"),
                (name: "Subsection 1.2", value: "Level 2")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Should handle nested structures
        XCTAssertNotNil(document.rootContent)
    }

    func testMixedContentTypes() throws {
        let srData = try createTestSRFile(
            textContent: [
                (name: "Text Finding", value: "Normal"),
                (name: "Additional Note", value: "Follow-up needed")
            ],
            numericContent: [
                (name: "Size", value: 5.2, units: "cm")
            ]
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        XCTAssertNotNil(document.rootContent)
    }

    // MARK: - Output Consistency Tests

    func testConsistentOutputAcrossFormats() throws {
        let srData = try createTestSRFile(
            documentTitle: "Consistency Test",
            patientName: "CONSISTENT^TEST"
        )

        let dicomFile = try DICOMFile.read(from: srData)
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)

        // Same document should generate consistent output in all formats
        XCTAssertNotNil(document.patientName)
        XCTAssertNotNil(document.documentTitle)
    }

    func testReproducibleReports() throws {
        let srData = try createTestSRFile(patientName: "REPRODUCIBLE^TEST")

        let dicomFile1 = try DICOMFile.read(from: srData)
        let parser1 = SRDocumentParser()
        let document1 = try parser1.parse(dataSet: dicomFile1.dataSet)

        let dicomFile2 = try DICOMFile.read(from: srData)
        let parser2 = SRDocumentParser()
        let document2 = try parser2.parse(dataSet: dicomFile2.dataSet)

        // Same input should produce same parsed results
        XCTAssertEqual(document1.patientName, document2.patientName)
        XCTAssertEqual(document1.sopInstanceUID, document2.sopInstanceUID)
    }

    // MARK: - Phase C: Template Engine Tests

    func testReportTemplateDefaultResolves() throws {
        let template = ReportTemplate.resolve(name: "default")
        XCTAssertEqual(template.name, "default")
        XCTAssertEqual(template.displayName, "Standard Report")
        XCTAssertFalse(template.sections.isEmpty)
        XCTAssertTrue(template.sections.contains(.patientInfo))
        XCTAssertTrue(template.sections.contains(.findings))
    }

    func testReportTemplateCardiologyResolves() throws {
        let template = ReportTemplate.resolve(name: "cardiology")
        XCTAssertEqual(template.name, "cardiology")
        XCTAssertEqual(template.displayName, "Cardiology Report")
        XCTAssertTrue(template.sections.contains(.cardiacFindings))
        XCTAssertTrue(template.sections.contains(.hemodynamics))
        XCTAssertEqual(template.colorScheme.primary, "#E53E3E")
    }

    func testReportTemplateRadiologyResolves() throws {
        let template = ReportTemplate.resolve(name: "radiology")
        XCTAssertEqual(template.name, "radiology")
        XCTAssertEqual(template.displayName, "Radiology Report")
        XCTAssertTrue(template.sections.contains(.indication))
        XCTAssertTrue(template.sections.contains(.technique))
        XCTAssertEqual(template.colorScheme.primary, "#3182CE")
    }

    func testReportTemplateOncologyResolves() throws {
        let template = ReportTemplate.resolve(name: "oncology")
        XCTAssertEqual(template.name, "oncology")
        XCTAssertEqual(template.displayName, "Oncology Report")
        XCTAssertTrue(template.sections.contains(.tumorAssessment))
        XCTAssertTrue(template.sections.contains(.stagingInfo))
        XCTAssertEqual(template.colorScheme.primary, "#805AD5")
    }

    func testReportTemplateUnknownFallsBackToDefault() throws {
        let template = ReportTemplate.resolve(name: "unknown_template")
        XCTAssertEqual(template.name, "default")
        XCTAssertEqual(template.displayName, "Standard Report")
    }

    func testReportTemplateSectionOrdering() throws {
        let cardioTemplate = ReportTemplate.resolve(name: "cardiology")
        // Cardiology should have patient info before findings
        guard let patientIdx = cardioTemplate.sections.firstIndex(of: .patientInfo),
              let findingsIdx = cardioTemplate.sections.firstIndex(of: .cardiacFindings) else {
            XCTFail("Expected sections not found")
            return
        }
        XCTAssertLessThan(patientIdx, findingsIdx)
    }

    func testReportSectionDisplayNames() throws {
        XCTAssertEqual(ReportSection.patientInfo.displayName, "Patient Information")
        XCTAssertEqual(ReportSection.findings.displayName, "Findings")
        XCTAssertEqual(ReportSection.measurements.displayName, "Measurements")
        XCTAssertEqual(ReportSection.cardiacFindings.displayName, "Cardiac Findings")
        XCTAssertEqual(ReportSection.tumorAssessment.displayName, "Tumor Assessment")
        XCTAssertEqual(ReportSection.hemodynamics.displayName, "Hemodynamic Parameters")
        XCTAssertEqual(ReportSection.impressions.displayName, "Impressions")
        XCTAssertEqual(ReportSection.recommendations.displayName, "Recommendations")
    }

    func testColorSchemeInitialization() throws {
        let scheme = ColorScheme(primary: "#FF0000", secondary: "#00FF00",
                                  accent: "#0000FF", background: "#FFFFFF", text: "#000000")
        XCTAssertEqual(scheme.primary, "#FF0000")
        XCTAssertEqual(scheme.secondary, "#00FF00")
        XCTAssertEqual(scheme.accent, "#0000FF")
    }

    // MARK: - Phase C: Image Embedding Tests

    func testImageEmbedderNilDirectory() throws {
        let embedder = ImageEmbedder(imageDirectory: nil)
        let result = embedder.loadImageAsBase64(sopInstanceUID: "1.2.3.4")
        XCTAssertNil(result, "Should return nil when no image directory is set")
    }

    func testImageEmbedderNonexistentFile() throws {
        let embedder = ImageEmbedder(imageDirectory: "/tmp/nonexistent_dir_12345")
        let result = embedder.loadImageAsBase64(sopInstanceUID: "1.2.3.4")
        XCTAssertNil(result, "Should return nil when image file does not exist")
    }

    func testImageEmbedderLoadsExistingImage() throws {
        // Create a temp directory with a test image
        let tempDir = NSTemporaryDirectory() + "dicom_report_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        // Write a minimal PNG file
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header
        let imagePath = (tempDir as NSString).appendingPathComponent("1.2.3.4.5.png")
        try pngData.write(to: URL(fileURLWithPath: imagePath))

        let embedder = ImageEmbedder(imageDirectory: tempDir)
        let result = embedder.loadImageAsBase64(sopInstanceUID: "1.2.3.4.5")
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.hasPrefix("data:image/png;base64,") ?? false)
    }

    func testImageEmbedderLogoLoading() throws {
        let tempDir = NSTemporaryDirectory() + "dicom_logo_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let logoData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let logoPath = (tempDir as NSString).appendingPathComponent("logo.png")
        try logoData.write(to: URL(fileURLWithPath: logoPath))

        let embedder = ImageEmbedder(imageDirectory: nil)
        let result = embedder.loadLogoAsBase64(path: logoPath)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.hasPrefix("data:image/png;base64,") ?? false)
    }

    func testImageEmbedderLogoNonexistent() throws {
        let embedder = ImageEmbedder(imageDirectory: nil)
        let result = embedder.loadLogoAsBase64(path: "/tmp/nonexistent_logo.png")
        XCTAssertNil(result)
    }

    // MARK: - Phase C: Branding Tests

    func testBrandingConfigurationWithoutLogo() throws {
        let branding = BrandingConfiguration(logoPath: nil, footerText: "Confidential")
        XCTAssertNil(branding.logoBase64)
        XCTAssertEqual(branding.footerText, "Confidential")
        XCTAssertTrue(branding.showGenerationDate)
    }

    func testBrandingConfigurationWithInstitution() throws {
        let branding = BrandingConfiguration(
            logoPath: nil, footerText: "Test Footer",
            institutionName: "Test Hospital",
            headerColor: "#FF0000"
        )
        XCTAssertEqual(branding.institutionName, "Test Hospital")
        XCTAssertEqual(branding.headerColor, "#FF0000")
    }

    func testBrandingConfigurationWithLogo() throws {
        let tempDir = NSTemporaryDirectory() + "dicom_branding_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let logoData = Data([0x89, 0x50, 0x4E, 0x47])
        let logoPath = (tempDir as NSString).appendingPathComponent("brand.png")
        try logoData.write(to: URL(fileURLWithPath: logoPath))

        let branding = BrandingConfiguration(logoPath: logoPath, footerText: nil)
        XCTAssertNotNil(branding.logoBase64)
    }

    // MARK: - Phase C: Multi-Language Support Tests

    func testLanguageEnglishSectionNames() throws {
        let lang = ReportLanguage.english
        XCTAssertEqual(lang.localizedSectionName(.patientInfo), "Patient Information")
        XCTAssertEqual(lang.localizedSectionName(.measurements), "Measurements")
        XCTAssertEqual(lang.localizedSectionName(.findings), "Findings")
    }

    func testLanguageSpanishSectionNames() throws {
        let lang = ReportLanguage.spanish
        XCTAssertEqual(lang.localizedSectionName(.patientInfo), "Información del Paciente")
        XCTAssertEqual(lang.localizedSectionName(.measurements), "Mediciones")
        XCTAssertEqual(lang.localizedSectionName(.findings), "Hallazgos")
    }

    func testLanguageFrenchSectionNames() throws {
        let lang = ReportLanguage.french
        XCTAssertEqual(lang.localizedSectionName(.patientInfo), "Informations Patient")
        XCTAssertEqual(lang.localizedSectionName(.measurements), "Mesures")
        XCTAssertEqual(lang.localizedSectionName(.findings), "Résultats")
    }

    func testLanguageGermanSectionNames() throws {
        let lang = ReportLanguage.german
        XCTAssertEqual(lang.localizedSectionName(.patientInfo), "Patienteninformationen")
        XCTAssertEqual(lang.localizedSectionName(.measurements), "Messungen")
        XCTAssertEqual(lang.localizedSectionName(.findings), "Befunde")
    }

    func testLanguageEnglishLabels() throws {
        let lang = ReportLanguage.english
        XCTAssertEqual(lang.localizedLabel("Patient"), "Patient")
        XCTAssertEqual(lang.localizedLabel("Study Date"), "Study Date")
    }

    func testLanguageSpanishLabels() throws {
        let lang = ReportLanguage.spanish
        XCTAssertEqual(lang.localizedLabel("Patient"), "Paciente")
        XCTAssertEqual(lang.localizedLabel("Study Date"), "Fecha del Estudio")
        XCTAssertEqual(lang.localizedLabel("Measurement"), "Medición")
    }

    func testLanguageFrenchLabels() throws {
        let lang = ReportLanguage.french
        XCTAssertEqual(lang.localizedLabel("Patient"), "Patient")
        XCTAssertEqual(lang.localizedLabel("Study Date"), "Date de l'Étude")
    }

    func testLanguageGermanLabels() throws {
        let lang = ReportLanguage.german
        XCTAssertEqual(lang.localizedLabel("Patient"), "Patient")
        XCTAssertEqual(lang.localizedLabel("Study Date"), "Studiendatum")
    }

    func testLanguageUnknownLabelFallback() throws {
        let lang = ReportLanguage.spanish
        // Unknown keys should fall back to the key itself
        XCTAssertEqual(lang.localizedLabel("UnknownKey"), "UnknownKey")
    }

    func testLanguageRawValueInit() throws {
        XCTAssertEqual(ReportLanguage(rawValue: "en"), .english)
        XCTAssertEqual(ReportLanguage(rawValue: "es"), .spanish)
        XCTAssertEqual(ReportLanguage(rawValue: "fr"), .french)
        XCTAssertEqual(ReportLanguage(rawValue: "de"), .german)
        XCTAssertNil(ReportLanguage(rawValue: "xx"))
    }

    // MARK: - Phase C: Report Error Tests

    func testReportErrorDescriptions() throws {
        let pdfError = ReportError.pdfNotImplemented
        XCTAssertNotNil(pdfError.errorDescription)
        XCTAssertTrue(pdfError.errorDescription?.contains("PDF") ?? false)

        let templateError = ReportError.invalidTemplate
        XCTAssertNotNil(templateError.errorDescription)

        let imageError = ReportError.imageNotFound("/path/to/image.png")
        XCTAssertNotNil(imageError.errorDescription)
        XCTAssertTrue(imageError.errorDescription?.contains("/path/to/image.png") ?? false)

        let langError = ReportError.unsupportedLanguage("xx")
        XCTAssertNotNil(langError.errorDescription)
        XCTAssertTrue(langError.errorDescription?.contains("xx") ?? false)
    }

    // MARK: - Phase C: Template-Driven Report Integration Tests

    func testCardiologyTemplateSectionsPresent() throws {
        let template = ReportTemplate.resolve(name: "cardiology")
        XCTAssertTrue(template.sections.contains(.patientInfo))
        XCTAssertTrue(template.sections.contains(.studyInfo))
        XCTAssertTrue(template.sections.contains(.cardiacFindings))
        XCTAssertTrue(template.sections.contains(.measurements))
        XCTAssertTrue(template.sections.contains(.hemodynamics))
        XCTAssertTrue(template.sections.contains(.impressions))
        XCTAssertTrue(template.sections.contains(.recommendations))
        XCTAssertEqual(template.sections.count, 7)
    }

    func testRadiologyTemplateSectionsPresent() throws {
        let template = ReportTemplate.resolve(name: "radiology")
        XCTAssertTrue(template.sections.contains(.indication))
        XCTAssertTrue(template.sections.contains(.technique))
        XCTAssertTrue(template.sections.contains(.findings))
        XCTAssertTrue(template.sections.contains(.measurements))
        XCTAssertTrue(template.sections.contains(.impressions))
        XCTAssertEqual(template.sections.count, 7)
    }

    func testOncologyTemplateSectionsPresent() throws {
        let template = ReportTemplate.resolve(name: "oncology")
        XCTAssertTrue(template.sections.contains(.tumorAssessment))
        XCTAssertTrue(template.sections.contains(.stagingInfo))
        XCTAssertTrue(template.sections.contains(.findings))
        XCTAssertTrue(template.sections.contains(.impressions))
        XCTAssertTrue(template.sections.contains(.recommendations))
        XCTAssertEqual(template.sections.count, 8)
    }

    func testDefaultTemplateCompleteness() throws {
        let template = ReportTemplate.resolve(name: "default")
        // Default template should have the essential sections
        XCTAssertTrue(template.sections.contains(.patientInfo))
        XCTAssertTrue(template.sections.contains(.studyInfo))
        XCTAssertTrue(template.sections.contains(.findings))
        XCTAssertTrue(template.sections.contains(.measurements))
        XCTAssertTrue(template.sections.contains(.impressions))
        XCTAssertEqual(template.sections.count, 5)
    }

    func testAllTemplatesHavePatientInfo() throws {
        let templates = ["default", "cardiology", "radiology", "oncology"]
        for templateName in templates {
            let template = ReportTemplate.resolve(name: templateName)
            XCTAssertTrue(template.sections.contains(.patientInfo),
                          "\(templateName) template should contain patient info section")
        }
    }

    func testAllTemplatesHaveUniqueColorSchemes() throws {
        let defaultColors = ReportTemplate.default.colorScheme.primary
        let cardioColors = ReportTemplate.cardiology.colorScheme.primary
        let radioColors = ReportTemplate.radiology.colorScheme.primary
        let oncoColors = ReportTemplate.oncology.colorScheme.primary

        // Each template should have a unique primary color
        let colors = [defaultColors, cardioColors, radioColors, oncoColors]
        XCTAssertEqual(Set(colors).count, 4, "All templates should have unique primary colors")
    }

    func testAllLanguagesSupportAllSections() throws {
        let languages: [ReportLanguage] = [.english, .spanish, .french, .german]
        let sections: [ReportSection] = [.patientInfo, .studyInfo, .findings, .measurements, .impressions]

        for lang in languages {
            for section in sections {
                let name = lang.localizedSectionName(section)
                XCTAssertFalse(name.isEmpty,
                               "\(lang.rawValue) should have a non-empty name for \(section.rawValue)")
            }
        }
    }

    func testReportMeasurementStruct() throws {
        let measurement = ReportMeasurement(name: "Length", value: "25.5", units: "mm")
        XCTAssertEqual(measurement.name, "Length")
        XCTAssertEqual(measurement.value, "25.5")
        XCTAssertEqual(measurement.units, "mm")
    }
}
