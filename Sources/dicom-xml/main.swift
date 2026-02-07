import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMWeb
import DICOMDictionary

struct DICOMXml: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-xml",
        abstract: "Convert between DICOM and XML formats",
        discussion: """
            Converts DICOM files to XML format (DICOM Native XML Model) and vice versa.
            Supports DICOM Part 19 Native XML format with bulk data handling.
            
            Examples:
              dicom-xml file.dcm --output file.xml
              dicom-xml file.xml --output file.dcm --reverse
              dicom-xml file.dcm --pretty
              dicom-xml file.dcm --output file.xml --no-keywords
            """,
        version: "1.1.4"
    )
    
    @Argument(help: "Input file (DICOM or XML)")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    @Flag(name: .shortAndLong, help: "Convert from XML to DICOM")
    var reverse: Bool = false
    
    @Flag(name: .shortAndLong, help: "Pretty-print XML output")
    var pretty: Bool = false
    
    @Flag(name: .long, help: "Don't include keyword attributes in XML")
    var noKeywords: Bool = false
    
    @Flag(name: .long, help: "Include empty values in XML")
    var includeEmpty: Bool = false
    
    @Option(name: .long, help: "Inline binary data up to this size (bytes, 0 to always use URIs)")
    var inlineThreshold: Int = 1024
    
    @Option(name: .long, help: "Base URL for bulk data URIs")
    var bulkDataURL: String?
    
    @Flag(name: .long, help: "Only include metadata (exclude pixel data)")
    var metadataOnly: Bool = false
    
    @Option(name: .long, help: "Filter tags by name or group (can be used multiple times)")
    var filterTag: [String] = []
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Validate input file exists
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("File not found: \(input)")
        }
        
        // Determine output path
        let outputPath: String
        if let specifiedOutput = output {
            outputPath = specifiedOutput
        } else {
            // Default output: change extension
            let inputURL = URL(fileURLWithPath: input)
            if reverse {
                outputPath = inputURL.deletingPathExtension().appendingPathExtension("dcm").path
            } else {
                outputPath = inputURL.deletingPathExtension().appendingPathExtension("xml").path
            }
        }
        
        if verbose {
            print("Input:  \(input)")
            print("Output: \(outputPath)")
            print("Mode:   \(reverse ? "XML → DICOM" : "DICOM → XML")")
            print()
        }
        
        // Perform conversion
        if reverse {
            try convertXmlToDicom(inputPath: input, outputPath: outputPath)
        } else {
            try convertDicomToXml(inputPath: input, outputPath: outputPath)
        }
        
        if verbose {
            let fileSize = try FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64 ?? 0
            print()
            print("✓ Conversion complete")
            print("  Output size: \(formatFileSize(fileSize))")
        }
    }
    
    private func convertDicomToXml(inputPath: String, outputPath: String) throws {
        // Read DICOM file
        let startTime = Date()
        let inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        
        if verbose {
            let readTime = Date().timeIntervalSince(startTime)
            print("Read DICOM file: \(formatFileSize(Int64(inputData.count))) in \(String(format: "%.2f", readTime))s")
        }
        
        // Parse DICOM file
        let parseStart = Date()
        let dicomFile = try DICOMFile.read(from: inputData)
        
        if verbose {
            let parseTime = Date().timeIntervalSince(parseStart)
            print("Parsed DICOM: \(dicomFile.dataSet.allElements.count) elements in \(String(format: "%.2f", parseTime))s")
        }
        
        // Filter elements if requested
        var elements = dicomFile.dataSet.allElements
        if !filterTag.isEmpty {
            elements = try filterElements(elements, tags: filterTag)
            if verbose {
                print("Filtered to \(elements.count) elements")
            }
        }
        
        // Exclude pixel data if metadata-only
        if metadataOnly {
            elements = elements.filter { $0.tag != Tag.pixelData }
        }
        
        // Configure encoder
        let bulkDataBaseURL: URL?
        if let urlString = bulkDataURL {
            bulkDataBaseURL = URL(string: urlString)
        } else {
            bulkDataBaseURL = nil
        }
        
        let encoderConfig = DICOMXMLEncoder.Configuration(
            includeEmptyValues: includeEmpty,
            inlineBinaryThreshold: inlineThreshold > 0 ? inlineThreshold : nil,
            bulkDataBaseURL: bulkDataBaseURL,
            prettyPrinted: pretty,
            includeKeywords: !noKeywords
        )
        
        let encoder = DICOMXMLEncoder(configuration: encoderConfig)
        
        // Encode to XML
        let encodeStart = Date()
        let xmlData = try encoder.encode(elements)
        
        if verbose {
            let encodeTime = Date().timeIntervalSince(encodeStart)
            print("Encoded to XML: \(formatFileSize(Int64(xmlData.count))) in \(String(format: "%.2f", encodeTime))s")
        }
        
        // Write output
        let writeStart = Date()
        try xmlData.write(to: URL(fileURLWithPath: outputPath))
        
        if verbose {
            let writeTime = Date().timeIntervalSince(writeStart)
            print("Wrote output file in \(String(format: "%.2f", writeTime))s")
        }
    }
    
    private func convertXmlToDicom(inputPath: String, outputPath: String) throws {
        // Read XML file
        let startTime = Date()
        let inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        
        if verbose {
            let readTime = Date().timeIntervalSince(startTime)
            print("Read XML file: \(formatFileSize(Int64(inputData.count))) in \(String(format: "%.2f", readTime))s")
        }
        
        // Configure decoder
        let decoderConfig = DICOMXMLDecoder.Configuration(
            allowMissingVR: true,
            fetchBulkData: false,
            bulkDataHandler: nil
        )
        
        let decoder = DICOMXMLDecoder(configuration: decoderConfig)
        
        // Decode XML
        let decodeStart = Date()
        let elements = try decoder.decode(inputData)
        
        if verbose {
            let decodeTime = Date().timeIntervalSince(decodeStart)
            print("Decoded XML: \(elements.count) elements in \(String(format: "%.2f", decodeTime))s")
        }
        
        // Create DICOM file
        let createStart = Date()
        let dataSet = DataSet(elements: elements)
        
        // Determine transfer syntax from data or use default
        let transferSyntaxUID = dataSet[Tag.transferSyntaxUID]?.stringValues?.first ?? "1.2.840.10008.1.2.1"
        
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: transferSyntaxUID
        )
        
        if verbose {
            let createTime = Date().timeIntervalSince(createStart)
            print("Created DICOM file in \(String(format: "%.2f", createTime))s")
        }
        
        // Write DICOM file
        let writeStart = Date()
        let dicomData = try dicomFile.write()
        try dicomData.write(to: URL(fileURLWithPath: outputPath))
        
        if verbose {
            let writeTime = Date().timeIntervalSince(writeStart)
            print("Wrote DICOM file: \(formatFileSize(Int64(dicomData.count))) in \(String(format: "%.2f", writeTime))s")
        }
    }
    
    private func filterElements(_ elements: [DataElement], tags: [String]) throws -> [DataElement] {
        var tagSet = Set<Tag>()
        
        for tagString in tags {
            // Try parsing as tag name/keyword first
            if let entries = DataElementDictionary.lookup(keyword: tagString) {
                tagSet.insert(entries.tag)
            } else if let tag = try? parseTagString(tagString) {
                // Parse as hex tag (e.g., "0010,0010")
                tagSet.insert(tag)
            } else {
                throw ValidationError("Invalid tag: \(tagString)")
            }
        }
        
        return elements.filter { tagSet.contains($0.tag) }
    }
    
    private func parseTagString(_ string: String) throws -> Tag {
        let components = string.split(separator: ",")
        guard components.count == 2,
              let group = UInt16(components[0], radix: 16),
              let element = UInt16(components[1], radix: 16) else {
            throw ValidationError("Invalid tag format: \(string). Expected format: GGGG,EEEE")
        }
        return Tag(group: group, element: element)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        
        if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}

DICOMXml.main()
