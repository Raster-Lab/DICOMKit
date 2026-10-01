import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMWeb
import DICOMDictionary

// NEMA-verified: 2026a, checked 2026-10-01 — options read against PS3.19 2026a Table A.1.5-1 / A.1.5-2 (keyword
// required for PS3.6 elements, DicomAttribute per attribute, empty Value Field, BulkData uri/uuid, InlineBinary);
// 11 options; output validated by script and by xmllint against the A.1.6 RELAX NG schema (34 VRs)

struct DICOMXml: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-xml",
        abstract: "Convert between DICOM and XML formats",
        discussion: """
            Converts DICOM files to XML format (Native DICOM Model, PS3.19 Annex A.1)
            and vice versa, with bulk data handling. Every attribute is a DicomAttribute
            with tag, vr and keyword; an attribute with an empty Value Field is kept
            with no Value element (PS3.19 Table A.1.5-2).

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

    // PS3.19 Table A.1.5-2: keyword is "Required unless the DICOM Data Element is unknown to
    // the host", so output written with this flag is not conformant.
    @Flag(name: .long, help: "Don't write the keyword attribute (the output then breaks PS3.19 Table A.1.5-2, which requires it for PS3.6 elements)")
    var noKeywords: Bool = false

    // PS3.19 Table A.1.5-2: a DicomAttribute for "each DICOM Attribute"; a zero length Value
    // Field has "no Infoset Value elements at all". Keeping it is the default; --no-include-empty drops it.
    @Flag(name: .long, inversion: .prefixedNo,
          help: "Keep attributes with an empty Value Field as a DicomAttribute without Value (PS3.19 Table A.1.5-2)")
    var includeEmpty: Bool = true

    @Option(name: .long, help: "With --bulk-data-url: OB/OD/OF/OL/OV/OW/UN values longer than this many bytes become BulkData (0: all of them); without it every such value is InlineBinary (PS3.19 Table A.1.5-2)")
    var inlineThreshold: Int = 1024

    @Option(name: .long, help: "Base URL for BulkData uri values, <url>/<GGGGEEEE> (PS3.19 Table A.1.5-2 reserves uri for a WADO-RS Retrieve Metadata response)")
    var bulkDataURL: String?

    @Flag(name: .long, help: "Omit Pixel Data (7FE0,0010); other bulk data is kept (this is not the PS3.18 10.4.1.1.2 Metadata resource)")
    var metadataOnly: Bool = false

    @Option(name: .long, help: "Keep only this attribute: PS3.6 keyword, GGGG,EEEE or GGGGEEEE (can be used multiple times)")
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
            metadataOnly: metadataOnly, filterTags: Self.normalizedFilterTags(filterTag), verbose: verbose,
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

    /// Accepts the eight-character tag (the Table A.1.5-2 `tag` form, e.g. `00100020`) and
    /// `(GGGG,EEEE)` besides the keyword and `GGGG,EEEE` forms the shared workflow resolves.
    static func normalizedFilterTags(_ specs: [String]) -> [String] {
        specs.map { spec in
            var s = spec.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("("), s.hasSuffix(")") { s = String(s.dropFirst().dropLast()) }
            if s.count == 8, s.allSatisfy(\.isHexDigit) {
                return "\(s.prefix(4)),\(s.suffix(4))"
            }
            return s.contains(",") ? s : spec
        }
    }
}

DICOMXml.main()
