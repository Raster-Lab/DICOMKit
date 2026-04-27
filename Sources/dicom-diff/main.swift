import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary
import DICOMCLITools

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
    var format: DiffOutputFormat = .text
    
    @Option(name: .long, help: "Tags to ignore (can be used multiple times, e.g. '0008,0012' or 'SOPInstanceUID')")
    var ignoreTag: [String] = []
    
    @Flag(name: .long, help: "Ignore all private tags")
    var ignorePrivate: Bool = false
    
    @Flag(name: .long, help: "Compare pixel data")
    var comparePixels: Bool = false
    
    @Option(name: .long, help: "Pixel value tolerance for comparison (default: 0)")
    var tolerance: Double = 0.0
    
    @Flag(name: .long, help: "Quick mode: metadata only, skip pixel data")
    var quick: Bool = false
    
    @Flag(name: .long, help: "Show identical tags in detailed mode")
    var showIdentical: Bool = false
    
    @Flag(name: .long, help: "Verbose output with detailed information")
    var verbose: Bool = false
    
    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: file1) else {
            throw ValidationError("File not found: \(file1)")
        }
        
        guard FileManager.default.fileExists(atPath: file2) else {
            throw ValidationError("File not found: \(file2)")
        }
        
        let data1 = try Data(contentsOf: URL(fileURLWithPath: file1))
        let data2 = try Data(contentsOf: URL(fileURLWithPath: file2))
        
        let dicomFile1 = try DICOMFile.read(from: data1)
        let dicomFile2 = try DICOMFile.read(from: data2)
        
        if verbose {
            print("Comparing: \(URL(fileURLWithPath: file1).lastPathComponent)")
            print("     with: \(URL(fileURLWithPath: file2).lastPathComponent)")
            print()
        }
        
        let tagsToIgnore = try parseIgnoreTags(ignoreTag)
        
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
        
        let formatter = DiffOutputFormatter(
            file1Path: file1,
            file2Path: file2,
            showIdentical: showIdentical
        )
        let output = try formatter.format(result, format: format)
        print(output)
        
        if result.hasDifferences {
            throw ExitCode(1)
        }
    }
    
    private func parseIgnoreTags(_ tags: [String]) throws -> Set<Tag> {
        var result = Set<Tag>()

        for raw in tags {
            // Each `--ignore-tag` value may itself contain multiple tokens
            // separated by whitespace or commas-between-pairs (e.g. when a
            // GUI passes "0010,0010 0010,0040" as a single argument). Split
            // first, then merge adjacent 4-hex pieces back into "GGGG,EEEE".
            let pieces = raw
                .split(whereSeparator: { $0.isWhitespace })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for tagStr in pieces {
                if let tag = parseTag(tagStr) {
                    result.insert(tag)
                } else {
                    throw ValidationError("Invalid tag format: \(tagStr). Use format like '0008,0012' or tag keyword like 'SOPInstanceUID'")
                }
            }
        }

        return result
    }
    
    private func parseTag(_ str: String) -> Tag? {
        let components = str.components(separatedBy: ",")
        if components.count == 2,
           let group = UInt16(components[0], radix: 16),
           let element = UInt16(components[1], radix: 16) {
            return Tag(group: group, element: element)
        }
        return DataElementDictionary.lookup(keyword: str)?.tag
    }
}

extension DiffOutputFormat: ExpressibleByArgument {}

DICOMDiff.main()
