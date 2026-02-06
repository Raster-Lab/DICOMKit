import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

@available(macOS 10.15, iOS 13, *)
struct DICOMValidate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-validate",
        abstract: "Validate DICOM files against standards and best practices",
        discussion: """
            Validates DICOM files for conformance to the DICOM standard.
            Supports multiple validation levels from basic file format to IOD-specific rules.
            
            Examples:
              dicom-validate file.dcm
              dicom-validate file.dcm --level 3 --detailed
              dicom-validate file.dcm --iod CTImageStorage
              dicom-validate study/ --recursive --format json --output report.json
              dicom-validate file.dcm --strict
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "Path to DICOM file or directory")
    var inputPath: String
    
    @Option(name: .long, help: "Validation level (1-4): 1=Format, 2=Tags/VR/VM, 3=IOD, 4=Best practices")
    var level: Int = 3
    
    @Option(name: .long, help: "Specific IOD to validate against (e.g., CTImageStorage, MRImageStorage)")
    var iod: String?
    
    @Flag(name: .long, help: "Show detailed validation report")
    var detailed: Bool = false
    
    @Flag(name: .long, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Option(name: .shortAndLong, help: "Output format: text, json")
    var format: OutputFormat = .text
    
    @Option(name: .shortAndLong, help: "Output file path (stdout if not specified)")
    var output: String?
    
    @Flag(name: .long, help: "Treat warnings as errors (exit code non-zero)")
    var strict: Bool = false
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    mutating func run() async throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
            throw ValidationError("Input path not found: \(inputPath)")
        }
        
        guard level >= 1 && level <= 4 else {
            throw ValidationError("Validation level must be between 1 and 4")
        }
        
        let results: [ValidationResult]
        if isDirectory.boolValue {
            guard recursive else {
                throw ValidationError("Directory validation requires --recursive flag")
            }
            results = try validateDirectory(url: inputURL)
        } else {
            let result = try validateFile(url: inputURL)
            results = [result]
        }
        
        let report = ValidationReport(results: results, detailed: detailed, strict: strict)
        let outputText = try report.render(format: format)
        
        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: outputPath)
            try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
        } else {
            print(outputText, terminator: "")
        }
        
        let exitCode = report.exitCode()
        if exitCode != 0 {
            throw ExitCode(exitCode)
        }
    }
    
    private func validateDirectory(url: URL) throws -> [ValidationResult] {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        guard let enumerator = enumerator else {
            throw ValidationError("Failed to enumerate directory: \(url.path)")
        }
        
        var results: [ValidationResult] = []
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            
            do {
                let result = try validateFile(url: fileURL)
                results.append(result)
            } catch {
                let result = ValidationResult(
                    filePath: fileURL.path,
                    isValid: false,
                    errors: [ValidationIssue(level: .error, message: error.localizedDescription, tag: nil)],
                    warnings: []
                )
                results.append(result)
            }
        }
        
        return results
    }
    
    private func validateFile(url: URL) throws -> ValidationResult {
        let fileData = try Data(contentsOf: url)
        
        let validator = DICOMValidator(level: level, iod: iod, force: force)
        return try validator.validate(data: fileData, filePath: url.path)
    }
}

await DICOMValidate.main()
