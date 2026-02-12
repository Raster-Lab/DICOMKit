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
        
        // Parse SR document
        let parser = SRDocumentParser()
        let document = try parser.parse(dataSet: dicomFile.dataSet)
        
        if verbose {
            print("SR Type: \(document.documentType?.description ?? "Unknown")")
            print("Content items: \(document.contentItemCount)")
        }
        
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
                includeSummary: includeSummary
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
