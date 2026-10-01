// NEMA-verified: 2026a, checked 2026-10-01 — a non-SR input is refused (root Value Type (0040,A040) must be CONTAINER, PS3.3 2026a C.17.3) with its PS3.6 Table A-1 SOP Class name; --format/--template/--language/--title/--logo/--footer/--image-dir/--embed-images/--include-*/--force/--verbose are plumbing (presentation; --template is a styling preset, not a PS3.16 TID)
import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMReport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-report",
        abstract: "Generate clinical reports from DICOM Structured Report objects",
        discussion: """
            Parse DICOM SR documents and generate professional clinical reports in various formats.
            Supports Basic Text SR, Enhanced SR, Comprehensive SR, and specialized report types.
            
            Examples:
              dicom-report sr.dcm --output report.txt --format text
              dicom-report sr.dcm --output report.html --format html
              dicom-report sr.dcm --output data.json --format json
            
            Note: PDF format and image embedding are planned for future releases.
            """,
        version: "1.4.0"
    )
    
    @Argument(help: "Path to the DICOM SR file")
    var filePath: String
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String
    
    @Option(name: .shortAndLong, help: "Output format: text, html, pdf, json, markdown")
    var format: ReportFormat = .text
    
    @Flag(name: .long, help: "Embed images from referenced instances (HTML/PDF only)")
    var embedImages: Bool = false
    
    @Option(name: .long, help: "Directory containing referenced image files")
    var imageDir: String?
    
    @Option(name: .long, help: "Report template: default, cardiology, radiology, oncology")
    var template: String = "default"
    
    @Option(name: .long, help: "Custom report title (overrides SR title)")
    var title: String?
    
    @Option(name: .long, help: "Path to hospital logo image for branding (PDF/HTML)")
    var logo: String?
    
    @Option(name: .long, help: "Custom footer text for report")
    var footer: String?
    
    @Flag(name: .long, inversion: .prefixedNo, help: "Include measurement tables in output")
    var includeMeasurements: Bool = true
    
    @Flag(name: .long, inversion: .prefixedNo, help: "Include finding summaries")
    var includeSummary: Bool = true
    
    @Option(name: .long, help: "Report language: en, es, fr, de")
    var language: String = "en"
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    @Flag(name: .long, help: "Verbose output for debugging")
    var verbose: Bool = false
    
    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File not found: \(filePath)")
        }
        
        if verbose {
            print("Reading DICOM file: \(filePath)")
        }
        
        let fileData = try Data(contentsOf: fileURL)
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        
        if verbose {
            print("Parsing SR document...")
        }
        
        // An SR Document has a root Content Item of Value Type CONTAINER (PS3.3 2026a C.17.3);
        // anything else (an image, say) is refused instead of producing an empty report.
        try Self.requireStructuredReport(dicomFile.dataSet)

        // Parse SR document
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)
        
        if verbose {
            print("SR Type: \(document.documentType?.description ?? "Unknown")")
            print("Content items: \(document.contentItemCount)")
        }
        
        // Resolve language
        let reportLanguage = ReportLanguage(rawValue: language) ?? .english
        
        // Generate report
        let generator = ReportGenerator(
            document: document,
            options: ReportOptions(
                format: format,
                template: template,
                embedImages: embedImages,
                imageDirectory: imageDir,
                customTitle: title,
                logoPath: logo,
                footerText: footer,
                includeMeasurements: includeMeasurements,
                includeSummary: includeSummary,
                language: reportLanguage
            )
        )
        
        if verbose {
            print("Generating \(format.rawValue) report...")
        }
        
        let reportData = try generator.generate()
        
        // Write output
        let outputURL = URL(fileURLWithPath: output)
        
        // Create output directory if needed
        let outputDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        try reportData.write(to: outputURL)
        
        print("✓ Report generated: \(output)")
        
        if verbose {
            let sizeKB = Double(reportData.count) / 1024.0
            print("  Size: \(String(format: "%.2f", sizeKB)) KB")
        }
    }

    /// Throws unless the data set's root Content Item has Value Type (0040,A040) CONTAINER
    /// (PS3.3 2026a C.17.3, Table C.17-6); names the SOP Class from PS3.6 Table A-1.
    static func requireStructuredReport(_ dataSet: DataSet) throws {
        let valueType = dataSet.string(for: .valueType)?.trimmingCharacters(in: .whitespaces)
        guard valueType != "CONTAINER" else { return }
        let uid = dataSet.string(for: .sopClassUID)?.trimmingCharacters(in: CharacterSet(charactersIn: " \0")) ?? ""
        let name = UIDDictionary.lookup(uid: uid)?.name ?? (uid.isEmpty ? "(no SOP Class UID)" : uid)
        throw ValidationError("Not a Structured Report. SOP Class UID indicates: \(name)")
    }
}

enum ReportFormat: String, ExpressibleByArgument {
    case text
    case html
    case pdf
    case json
    case markdown
    
    var defaultValueDescription: String {
        switch self {
        case .text: return "plain text (default)"
        case .html: return "HTML format"
        case .pdf: return "PDF format"
        case .json: return "JSON format"
        case .markdown: return "Markdown format"
        }
    }
}

DICOMReport.main()
