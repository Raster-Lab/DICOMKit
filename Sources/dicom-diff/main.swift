// NEMA-verified: 2026a, checked 2026-10-01 — --ignore-tag accepts the Tag notation of PS3.6 2026a Table 6-1 ((gggg,eeee), also gggg,eeee / ggggeeee; PS3.5 7.1.1) and Table 6-1 keywords; --ignore-private is the odd-group rule of PS3.5 7.1/7.8; the 10 options otherwise carry no DICOM-standard data (comparison engine verified in DICOMKit/Comparison)
import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

// The comparison engine (`DICOMComparer`), its result types, the report renderer
// (`ComparisonReport`), and `ComparisonOutputFormat` now live in the DICOMKit
// library so the CLI and DICOMStudio run the exact same code. ArgumentParser
// stays out of the library, so the CLI supplies the command-line conformance here.
extension ComparisonOutputFormat: ExpressibleByArgument {}

struct DICOMDiff: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-diff",
        abstract: "Compare two DICOM files and report differences",
        discussion: """
            Compares metadata tags and optionally pixel data between two DICOM files.
            Supports filtering, tolerance settings, and multiple output formats.

            Examples:
              dicom-diff file1.dcm file2.dcm
              dicom-diff --compare-pixels --tolerance 5 original.dcm processed.dcm
              dicom-diff --ignore-tag 0008,0012 --format json file1.dcm file2.dcm
            """,
        version: "1.0.0"
    )

    @Argument(help: "First DICOM file to compare")
    var file1: String

    @Argument(help: "Second DICOM file to compare")
    var file2: String

    @Option(name: .shortAndLong, help: "Output format: text, json, summary")
    var format: ComparisonOutputFormat = .text

    @Option(name: .long, help: "Tag to ignore, repeatable: (gggg,eeee), gggg,eeee, ggggeeee or a PS3.6 keyword (e.g. '(0008,0018)' or 'SOPInstanceUID')")
    var ignoreTag: [String] = []

    @Flag(name: .long, help: "Ignore private data elements (odd group number, PS3.5 7.1) at the top level of the data set")
    var ignorePrivate: Bool = false

    @Flag(name: .long, help: "Compare Pixel Data (7FE0,0010) byte by byte instead of as one element")
    var comparePixels: Bool = false

    @Option(name: .long, help: "Largest per-byte difference in Pixel Data (7FE0,0010) still treated as identical; bytes, not sample values (default: 0)")
    var tolerance: Double = 0.0

    @Flag(name: .long, help: "Quick mode: metadata only, overrides --compare-pixels")
    var quick: Bool = false

    @Flag(name: .long, help: "Show identical tags in detailed mode")
    var showIdentical: Bool = false

    @Flag(name: .long, help: "Verbose output with detailed information")
    var verbose: Bool = false

    mutating func run() throws {
        // Validate files exist
        guard FileManager.default.fileExists(atPath: file1) else {
            throw ValidationError("File not found: \(file1)")
        }

        guard FileManager.default.fileExists(atPath: file2) else {
            throw ValidationError("File not found: \(file2)")
        }

        // Read DICOM files
        let data1 = try Data(contentsOf: URL(fileURLWithPath: file1))
        let data2 = try Data(contentsOf: URL(fileURLWithPath: file2))

        let dicomFile1 = try DICOMFile.read(from: data1)
        let dicomFile2 = try DICOMFile.read(from: data2)

        if verbose {
            print("Comparing: \(URL(fileURLWithPath: file1).lastPathComponent)")
            print("     with: \(URL(fileURLWithPath: file2).lastPathComponent)")
            print()
        }

        // Parse ignore tags
        let tagsToIgnore = try parseIgnoreTags(ignoreTag)

        // Perform comparison via the shared DICOMKit engine
        let comparer = DICOMComparer(
            file1: dicomFile1,
            file2: dicomFile2,
            tagsToIgnore: tagsToIgnore,
            ignorePrivate: ignorePrivate,
            comparePixels: comparePixels && !quick,
            pixelTolerance: tolerance,
            showIdentical: showIdentical
        )

        let result = try comparer.compare()

        // Output results via the shared DICOMKit renderer
        let report = ComparisonReport(
            result: result,
            file1Name: URL(fileURLWithPath: file1).lastPathComponent,
            file2Name: URL(fileURLWithPath: file2).lastPathComponent,
            showIdentical: showIdentical
        )
        let output = try report.render(format: format)
        print(output)

        // Exit with appropriate code
        if result.hasDifferences {
            throw ExitCode(1)
        }
    }

    private func parseIgnoreTags(_ tags: [String]) throws -> Set<Tag> {
        var result = Set<Tag>()

        for tagStr in tags {
            if let tag = Self.parseTag(tagStr) {
                result.insert(tag)
            } else {
                throw ValidationError("Invalid tag format: \(tagStr). Use (gggg,eeee), gggg,eeee, ggggeeee or a PS3.6 keyword like 'SOPInstanceUID'")
            }
        }

        return result
    }

    /// Parses an `--ignore-tag` value: the PS3.6 Table 6-1 Tag notation `(gggg,eeee)` that the
    /// report itself prints, `gggg,eeee`, the 8-digit `ggggeeee` form, or a PS3.6
    /// Table 6-1 keyword.
    static func parseTag(_ input: String) -> Tag? {
        var str = input.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("("), str.hasSuffix(")") {
            str = String(str.dropFirst().dropLast())
        }
        let isHex4: (String) -> Bool = { (1...4).contains($0.count) && $0.allSatisfy(\.isHexDigit) }

        // gggg,eeee
        let components = str.components(separatedBy: ",")
        if components.count == 2, isHex4(components[0]), isHex4(components[1]),
           let group = UInt16(components[0], radix: 16),
           let element = UInt16(components[1], radix: 16) {
            return Tag(group: group, element: element)
        }

        // ggggeeee
        if str.count == 8, str.allSatisfy(\.isHexDigit), let value = UInt32(str, radix: 16) {
            return Tag(group: UInt16(value >> 16), element: UInt16(value & 0xFFFF))
        }

        // PS3.6 keyword
        return DataElementDictionary.lookup(keyword: str)?.tag
    }
}

DICOMDiff.main()
