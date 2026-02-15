import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMGateway: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-gateway",
        abstract: "Bridge DICOM with HL7 v2, HL7 FHIR, and IHE profiles",
        discussion: """
            Bridge DICOM with other healthcare standards (HL7 v2, HL7 FHIR, IHE profiles)
            for interoperability and integration with broader healthcare IT systems.
            
            Examples:
              # Convert DICOM to HL7 ADT message
              dicom-gateway dicom-to-hl7 study.dcm --output study.hl7 --message-type ADT
              
              # Convert HL7 to DICOM
              dicom-gateway hl7-to-dicom message.hl7 --template template.dcm --output study.dcm
              
              # Convert DICOM to FHIR ImagingStudy
              dicom-gateway dicom-to-fhir study.dcm --output study.json --resource ImagingStudy
              
              # Convert FHIR to DICOM
              dicom-gateway fhir-to-dicom imaging-study.json --output study.dcm
              
              # Batch conversion
              dicom-gateway batch dicom-to-fhir studies/*.dcm --output fhir-resources/
            """,
        version: "1.0.0",
        subcommands: [
            DICOMToHL7.self,
            HL7ToDICOM.self,
            DICOMToFHIR.self,
            FHIRToDICOM.self,
            BatchConvert.self
        ],
        defaultSubcommand: DICOMToHL7.self
    )
}

// MARK: - DICOM to HL7 Command

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMToHL7: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-to-hl7",
        abstract: "Convert DICOM files to HL7 v2 messages",
        discussion: """
            Extract demographics, study info, and other data from DICOM files
            and generate HL7 v2 messages (ADT, ORM, ORU).
            """
    )
    
    @Argument(help: "Input DICOM file")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output HL7 file path")
    var output: String?
    
    @Option(name: [.customLong("message-type"), .customShort("t")], help: "HL7 message type: ADT, ORM, ORU")
    var messageType: String = "ADT"
    
    @Option(name: .long, help: "ADT event type (e.g., A01, A02, A03)")
    var eventType: String = "A01"
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            throw GatewayError.invalidInput("Input file not found: \(input)")
        }
        
        if verbose {
            print("Converting DICOM to HL7 \(messageType)...")
        }
        
        // Load DICOM file
        let dicomFile = try DICOMFile.read(from: URL(fileURLWithPath: input))
        
        // Convert to HL7
        let converter = DICOMToHL7Converter()
        let hl7Message: HL7Message
        
        switch messageType.uppercased() {
        case "ADT":
            hl7Message = try converter.convertToADT(dicomFile: dicomFile, eventType: eventType)
        case "ORM":
            hl7Message = try converter.convertToORM(dicomFile: dicomFile)
        case "ORU":
            hl7Message = try converter.convertToORU(dicomFile: dicomFile)
        default:
            throw GatewayError.invalidProtocol("Unsupported message type: \(messageType)")
        }
        
        // Generate HL7 text
        let parser = HL7Parser()
        let hl7Text = parser.generate(message: hl7Message)
        
        // Output
        if let outputPath = output {
            try hl7Text.write(toFile: outputPath, atomically: true, encoding: .utf8)
            if verbose {
                print("✓ HL7 message written to: \(outputPath)")
            }
        } else {
            print(hl7Text)
        }
        
        if verbose {
            print("✓ Conversion complete")
            print("  Message Type: \(messageType)")
            print("  Segments: \(hl7Message.segments.count)")
        }
    }
}

// MARK: - HL7 to DICOM Command

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct HL7ToDICOM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hl7-to-dicom",
        abstract: "Convert HL7 v2 messages to DICOM files",
        discussion: """
            Parse HL7 v2 messages and populate DICOM tags from demographics
            and order information.
            """
    )
    
    @Argument(help: "Input HL7 file")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output DICOM file path")
    var output: String
    
    @Option(name: .long, help: "Template DICOM file to populate")
    var template: String?
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            throw GatewayError.invalidInput("Input file not found: \(input)")
        }
        
        if verbose {
            print("Converting HL7 to DICOM...")
        }
        
        // Read HL7 message
        let hl7Text = try String(contentsOfFile: input, encoding: .utf8)
        
        // Parse HL7
        let parser = HL7Parser()
        let hl7Message = try parser.parse(hl7Text)
        
        if verbose {
            print("  Parsed HL7 message type: \(hl7Message.messageType)")
            print("  Segments: \(hl7Message.segments.count)")
        }
        
        // Load template if provided
        var templateFile: DICOMFile?
        if let templatePath = template {
            guard FileManager.default.fileExists(atPath: templatePath) else {
                throw GatewayError.invalidInput("Template file not found: \(templatePath)")
            }
            templateFile = try DICOMFile.read(from: URL(fileURLWithPath: templatePath))
        }
        
        // Convert to DICOM
        let converter = HL7ToDICOMConverter()
        let dicomFile = try converter.convert(hl7Message: hl7Message, templateFile: templateFile)
        
        // Write output
        let dicomData = try dicomFile.write()
        try dicomData.write(to: URL(fileURLWithPath: output))
        
        if verbose {
            print("✓ DICOM file written to: \(output)")
            print("✓ Conversion complete")
        }
    }
}

// MARK: - DICOM to FHIR Command

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMToFHIR: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-to-fhir",
        abstract: "Convert DICOM files to FHIR resources",
        discussion: """
            Convert DICOM files to FHIR resources including ImagingStudy,
            Patient, Practitioner, and DiagnosticReport.
            """
    )
    
    @Argument(help: "Input DICOM file")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output JSON file path")
    var output: String?
    
    @Option(name: [.customLong("resource"), .customShort("r")], help: "FHIR resource type: ImagingStudy, Patient, Practitioner, DiagnosticReport")
    var resourceType: String = "ImagingStudy"
    
    @Flag(name: .long, help: "Pretty-print JSON output")
    var pretty: Bool = false
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            throw GatewayError.invalidInput("Input file not found: \(input)")
        }
        
        guard let fhirType = FHIRResourceType(rawValue: resourceType) else {
            throw GatewayError.invalidProtocol("Unsupported FHIR resource type: \(resourceType)")
        }
        
        if verbose {
            print("Converting DICOM to FHIR \(resourceType)...")
        }
        
        // Load DICOM file
        let dicomFile = try DICOMFile.read(from: URL(fileURLWithPath: input))
        
        // Convert to FHIR
        let converter = FHIRConverter()
        let fhirResource = try converter.convertToFHIR(dicomFile: dicomFile, resourceType: fhirType)
        
        // Serialize to JSON
        let jsonData: Data
        if pretty {
            jsonData = try JSONSerialization.data(withJSONObject: fhirResource, options: [.prettyPrinted, .sortedKeys])
        } else {
            jsonData = try JSONSerialization.data(withJSONObject: fhirResource, options: [])
        }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw GatewayError.conversionFailed("Failed to encode JSON")
        }
        
        // Output
        if let outputPath = output {
            try jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
            if verbose {
                print("✓ FHIR resource written to: \(outputPath)")
            }
        } else {
            print(jsonString)
        }
        
        if verbose {
            print("✓ Conversion complete")
            print("  Resource Type: \(resourceType)")
        }
    }
}

// MARK: - FHIR to DICOM Command

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct FHIRToDICOM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fhir-to-dicom",
        abstract: "Convert FHIR resources to DICOM files",
        discussion: """
            Parse FHIR JSON resources and populate DICOM tags.
            """
    )
    
    @Argument(help: "Input FHIR JSON file")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output DICOM file path")
    var output: String
    
    @Option(name: .long, help: "Template DICOM file to populate")
    var template: String?
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            throw GatewayError.invalidInput("Input file not found: \(input)")
        }
        
        if verbose {
            print("Converting FHIR to DICOM...")
        }
        
        // Read FHIR JSON
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: input))
        guard let fhirResource = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw GatewayError.parsingFailed("Invalid FHIR JSON format")
        }
        
        if let resourceType = fhirResource["resourceType"] as? String, verbose {
            print("  Resource Type: \(resourceType)")
        }
        
        // Load template if provided
        var templateFile: DICOMFile?
        if let templatePath = template {
            guard FileManager.default.fileExists(atPath: templatePath) else {
                throw GatewayError.invalidInput("Template file not found: \(templatePath)")
            }
            templateFile = try DICOMFile.read(from: URL(fileURLWithPath: templatePath))
        }
        
        // Convert to DICOM
        let converter = FHIRConverter()
        let dicomFile = try converter.convertFromFHIR(fhirResource: fhirResource, templateFile: templateFile)
        
        // Write output
        let dicomData = try dicomFile.write()
        try dicomData.write(to: URL(fileURLWithPath: output))
        
        if verbose {
            print("✓ DICOM file written to: \(output)")
            print("✓ Conversion complete")
        }
    }
}

// MARK: - Batch Convert Command

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct BatchConvert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "batch",
        abstract: "Batch convert multiple files",
        discussion: """
            Convert multiple DICOM files to HL7/FHIR or vice versa in batch mode.
            """
    )
    
    @Argument(help: "Conversion type: dicom-to-hl7, dicom-to-fhir")
    var conversionType: String
    
    @Argument(help: "Input file pattern (e.g., studies/*.dcm)")
    var inputPattern: String
    
    @Option(name: .shortAndLong, help: "Output directory")
    var output: String
    
    @Option(name: .long, help: "Message/resource type")
    var type: String = "ADT"
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        // Create output directory if needed
        try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
        
        // Expand glob pattern
        let inputFiles = try expandGlobPattern(inputPattern)
        
        if verbose {
            print("Batch converting \(inputFiles.count) files...")
            print("  Conversion: \(conversionType)")
            print("  Type: \(type)")
        }
        
        var successCount = 0
        var failureCount = 0
        
        for inputFile in inputFiles {
            let filename = URL(fileURLWithPath: inputFile).lastPathComponent
            let baseName = URL(fileURLWithPath: inputFile).deletingPathExtension().lastPathComponent
            
            do {
                switch conversionType.lowercased() {
                case "dicom-to-hl7":
                    let outputFile = URL(fileURLWithPath: output).appendingPathComponent("\(baseName).hl7").path
                    let dicomFile = try DICOMFile.read(from: URL(fileURLWithPath: inputFile))
                    let converter = DICOMToHL7Converter()
                    let hl7Message = try converter.convertToADT(dicomFile: dicomFile)
                    let parser = HL7Parser()
                    let hl7Text = parser.generate(message: hl7Message)
                    try hl7Text.write(toFile: outputFile, atomically: true, encoding: .utf8)
                    
                case "dicom-to-fhir":
                    let outputFile = URL(fileURLWithPath: output).appendingPathComponent("\(baseName).json").path
                    let dicomFile = try DICOMFile.read(from: URL(fileURLWithPath: inputFile))
                    let converter = FHIRConverter()
                    let resourceType = FHIRResourceType(rawValue: type) ?? .imagingStudy
                    let fhirResource = try converter.convertToFHIR(dicomFile: dicomFile, resourceType: resourceType)
                    let jsonData = try JSONSerialization.data(withJSONObject: fhirResource, options: [.prettyPrinted])
                    try jsonData.write(to: URL(fileURLWithPath: outputFile))
                    
                default:
                    throw GatewayError.invalidProtocol("Unsupported conversion type: \(conversionType)")
                }
                
                successCount += 1
                if verbose {
                    print("  ✓ \(filename)")
                }
            } catch {
                failureCount += 1
                if verbose {
                    print("  ✗ \(filename): \(error)")
                }
            }
        }
        
        print("✓ Batch conversion complete")
        print("  Success: \(successCount)")
        print("  Failures: \(failureCount)")
    }
    
    private func expandGlobPattern(_ pattern: String) throws -> [String] {
        // Simple glob expansion - in production, use a proper glob library
        let components = pattern.components(separatedBy: "/")
        guard !components.isEmpty else { return [] }
        
        let directory = components.dropLast().joined(separator: "/")
        let dirPath = directory.isEmpty ? "." : directory
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: dirPath) else {
            throw GatewayError.invalidInput("Cannot enumerate directory: \(dirPath)")
        }
        
        var files: [String] = []
        for case let file as String in enumerator {
            if file.hasSuffix(".dcm") || file.hasSuffix(".hl7") || file.hasSuffix(".json") {
                files.append(URL(fileURLWithPath: dirPath).appendingPathComponent(file).path)
            }
        }
        
        return files
    }
}

// MARK: - Main Entry Point

if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
    DICOMGateway.main()
} else {
    fatalError("This tool requires macOS 10.15, iOS 13, tvOS 13, watchOS 6, or later")
}
