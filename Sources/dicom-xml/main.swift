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
        version: "1.1.5"
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
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("File not found: \(input)")
        }

        // Entire pipeline via the SHARED DataExchangeWorkflow (DICOMWeb) — the
        // same code DICOMStudio's Workshop executor runs, so behavior (default
        // output path, always-write-file) and verbose text cannot drift.
        let outputPath = output ?? DataExchangeWorkflow.defaultOutputPath(
            input: input, reverse: reverse, format: .xml)

        let options = DataExchangeWorkflow.Options(
            reverse: reverse, pretty: pretty, includeEmpty: includeEmpty,
            inlineThreshold: inlineThreshold, bulkDataURL: bulkDataURL,
            metadataOnly: metadataOnly, filterTags: filterTag, verbose: verbose,
            includeKeywords: !noKeywords
        )

        for line in DataExchangeWorkflow.headerLines(
            input: input, output: outputPath, reverse: reverse, format: .xml, verbose: verbose) {
            print(line)
        }

        let readStart = Date()
        let inputData = try Data(contentsOf: URL(fileURLWithPath: input))
        let readSeconds = Date().timeIntervalSince(readStart)

        let result: (data: Data, console: [String])
        do {
            result = reverse
                ? try DataExchangeWorkflow.decode(textData: inputData, format: .xml, options: options, readSeconds: readSeconds)
                : try DataExchangeWorkflow.encode(dicomData: inputData, format: .xml, options: options, readSeconds: readSeconds)
        } catch let e as DataExchangeWorkflow.WorkflowError {
            throw ValidationError(e.errorDescription ?? "\(e)")
        }
        for line in result.console { print(line) }

        let writeStart = Date()
        try result.data.write(to: URL(fileURLWithPath: outputPath))
        let writeSeconds = Date().timeIntervalSince(writeStart)
        let writeLines = reverse
            ? DataExchangeWorkflow.reverseWriteLine(size: Int64(result.data.count), seconds: writeSeconds, verbose: verbose)
            : DataExchangeWorkflow.forwardWriteLine(seconds: writeSeconds, verbose: verbose)
        for line in writeLines { print(line) }

        for line in DataExchangeWorkflow.completionLines(
            outputSize: Int64(result.data.count), verbose: verbose) {
            print(line)
        }
    }
}

DICOMXml.main()
