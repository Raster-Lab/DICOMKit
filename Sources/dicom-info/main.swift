import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMInfo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-info",
        abstract: "Display metadata from DICOM medical imaging files",
        discussion: """
            Extracts and displays metadata tags from DICOM Part 10 files.
            Supports multiple output formats for different use cases.
            
            Examples:
              dicom-info scan.dcm
              dicom-info --format json report.dcm
              dicom-info --tag PatientName --tag StudyDate exam.dcm
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "Path to the DICOM file")
    var filePath: String
    
    @Option(name: .shortAndLong, help: "Output format: text, json, csv")
    var format: OutputFormat = .text
    
    @Option(name: .shortAndLong, help: "Filter by specific tag names (can be used multiple times)")
    var tag: [String] = []
    
    @Flag(name: .long, help: "Include private tags in output")
    var showPrivate: Bool = false
    
    @Flag(name: .long, help: "Show file statistics")
    var statistics: Bool = false
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File not found: \(filePath)")
        }
        
        let fileData = try Data(contentsOf: fileURL)
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        
        let presenter = MetadataPresenter(
            file: dicomFile,
            filterTags: tag,
            includePrivate: showPrivate,
            showStats: statistics
        )
        
        let output = try presenter.render(format: format)
        print(output, terminator: "")
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
    case csv
    
    var defaultValueDescription: String {
        switch self {
        case .text: return "plain text (default)"
        case .json: return "JSON format"
        case .csv: return "CSV format"
        }
    }
}

DICOMInfo.main()
