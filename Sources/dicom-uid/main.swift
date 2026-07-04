import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@available(macOS 10.15, *)
struct DICOMUID: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-uid",
        abstract: "DICOM UID generation, validation, and management",
        discussion: """
            Generate, validate, regenerate, and look up DICOM Unique Identifiers (UIDs).
            
            Examples:
              dicom-uid generate
              dicom-uid generate --count 5 --type study
              dicom-uid generate --root 1.2.826.0.1.3680043.9.1234
              dicom-uid validate 1.2.840.10008.1.2.1
              dicom-uid validate --file study.dcm
              dicom-uid lookup 1.2.840.10008.1.2.1
              dicom-uid regenerate file.dcm --output new.dcm
              dicom-uid regenerate study/*.dcm --output new_study/ --export-map mapping.json
            """,
        version: "1.3.2",
        subcommands: [Generate.self, Validate.self, Lookup.self, Regenerate.self],
        defaultSubcommand: Generate.self
    )
}

// MARK: - Generate Subcommand

@available(macOS 10.15, *)
extension DICOMUID {
    struct Generate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate new DICOM UIDs",
            discussion: """
                Creates one or more unique DICOM UIDs. Optionally specify a UID type
                (study, series, instance) or a custom root.
                
                Examples:
                  dicom-uid generate
                  dicom-uid generate --count 10
                  dicom-uid generate --type study
                  dicom-uid generate --root 1.2.826.0.1.3680043.9.1234
                  dicom-uid generate --count 3 --type series --json
                """
        )

        @Option(name: .shortAndLong, help: "Number of UIDs to generate (default: 1)")
        var count: Int = 1

        @Option(name: .shortAndLong, help: "UID type: study, series, instance, or generic (default)")
        var type: String?

        @Option(name: .shortAndLong, help: "Custom UID root prefix")
        var root: String?

        @Flag(name: .long, help: "Output as JSON array")
        var json: Bool = false

        mutating func validate() throws {
            if count < 1 {
                throw ValidationError("Count must be at least 1")
            }
            if count > 1000 {
                throw ValidationError("Count must not exceed 1000")
            }
            if let type = type {
                let validTypes = ["study", "series", "instance", "sop", "generic"]
                if !validTypes.contains(type.lowercased()) {
                    throw ValidationError("Invalid type '\(type)'. Valid types: study, series, instance, generic")
                }
            }
        }

        mutating func run() throws {
            let manager = UIDManager()
            let uids = manager.generateUIDs(count: count, root: root, type: type)

            if json {
                print(try UIDConsole.generatedJSON(uids: uids), terminator: "")
            } else {
                print(UIDConsole.generatedList(uids: uids), terminator: "")
            }
        }
    }
}

// MARK: - Validate Subcommand

@available(macOS 10.15, *)
extension DICOMUID {
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate DICOM UIDs for compliance",
            discussion: """
                Check UIDs against DICOM PS3.5 Section 9 rules: max 64 characters,
                digits and periods only, no leading zeros, no consecutive periods, etc.
                
                Examples:
                  dicom-uid validate 1.2.840.10008.1.2.1
                  dicom-uid validate 1.2.3 4.5.6 --json
                  dicom-uid validate --file study.dcm
                  dicom-uid validate --file study.dcm --check-registry
                """
        )

        @Argument(help: "UIDs to validate")
        var uids: [String] = []

        @Option(name: .long, help: "Validate all UIDs in a DICOM file")
        var file: String?

        @Flag(name: .long, help: "Check UIDs against the DICOM registry")
        var checkRegistry: Bool = false

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        mutating func validate() throws {
            if uids.isEmpty && file == nil {
                throw ValidationError("Provide UIDs as arguments or use --file to validate a DICOM file")
            }
        }

        mutating func run() throws {
            let manager = UIDManager()
            var results: [UIDValidationResult] = []

            // Validate UIDs from arguments
            for uid in uids {
                results.append(manager.validateUID(uid))
            }

            // Validate UIDs from file
            if let filePath = file {
                let fileResults = try manager.validateFileUIDs(path: filePath)
                results.append(contentsOf: fileResults)
            }

            if json {
                print(try UIDConsole.validationJSON(results: results), terminator: "")
            } else {
                let (text, allValid) = UIDConsole.validationText(results: results, checkRegistry: checkRegistry)
                print(text, terminator: "")
                if !allValid {
                    throw ExitCode.failure
                }
            }
        }
    }
}

// MARK: - Lookup Subcommand

@available(macOS 10.15, *)
extension DICOMUID {
    struct Lookup: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Look up UIDs in the DICOM registry",
            discussion: """
                Search the DICOM UID registry for Transfer Syntaxes, SOP Classes,
                and other well-known UIDs.
                
                Examples:
                  dicom-uid lookup 1.2.840.10008.1.2.1
                  dicom-uid lookup 1.2.840.10008.5.1.4.1.1.2
                  dicom-uid lookup --list-all
                  dicom-uid lookup --list-all --type transfer-syntax
                  dicom-uid lookup --search "CT"
                """
        )

        @Argument(help: "UID to look up")
        var uid: String?

        @Flag(name: .long, help: "List all known UIDs")
        var listAll: Bool = false

        @Option(name: .long, help: "Filter by type: transfer-syntax, sop-class")
        var type: String?

        @Option(name: .long, help: "Search UIDs by name keyword")
        var search: String?

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        mutating func validate() throws {
            if uid == nil && !listAll && search == nil {
                throw ValidationError("Provide a UID, use --list-all, or --search to find UIDs")
            }
        }

        mutating func run() throws {
            let dictionary = UIDDictionary.self

            if let uidValue = uid {
                // Single UID lookup
                if let entry = dictionary.lookup(uid: uidValue) {
                    let typeName = UIDManager.uidTypeDescription(entry.type)
                    if json {
                        print(try UIDConsole.lookupEntryJSON(uid: uidValue, name: entry.name, type: typeName), terminator: "")
                    } else {
                        print(UIDConsole.lookupEntryText(uid: uidValue, name: entry.name, type: typeName), terminator: "")
                    }
                } else {
                    fprintln(UIDConsole.lookupNotFoundLine(uid: uidValue))
                    throw ExitCode.failure
                }
            } else if listAll || search != nil {
                // List/search entries
                var entries = dictionary.allEntries

                // Filter by type
                if let typeFilter = type {
                    switch typeFilter.lowercased() {
                    case "transfer-syntax", "transfersyntax":
                        entries = dictionary.transferSyntaxes
                    case "sop-class", "sopclass":
                        entries = dictionary.sopClasses
                    default:
                        fprintln(UIDConsole.unknownTypeFilterLine(typeFilter))
                        throw ExitCode.failure
                    }
                }

                // Filter by search term
                if let searchTerm = search {
                    let lowerSearch = searchTerm.lowercased()
                    entries = entries.filter { entry in
                        entry.name.lowercased().contains(lowerSearch) ||
                        entry.uid.lowercased().contains(lowerSearch)
                    }
                }

                if entries.isEmpty {
                    fprintln(UIDConsole.noMatchesLine())
                    throw ExitCode.failure
                }

                if json {
                    let rows = entries.map { (uid: $0.uid, name: $0.name, type: UIDManager.uidTypeDescription($0.type)) }
                    print(try UIDConsole.listingJSON(entries: rows), terminator: "")
                } else {
                    for entry in entries {
                        print(UIDConsole.listingLine(uid: entry.uid, name: entry.name, type: UIDManager.uidTypeDescription(entry.type)))
                    }
                    // Result summary belongs on stdout (with the listing), consistent
                    // with how DICOMStudio renders it — keeps app/CLI output in parity.
                    print(UIDConsole.listingSummary(count: entries.count))
                }
            }
        }
    }
}

// MARK: - Regenerate Subcommand

@available(macOS 10.15, *)
extension DICOMUID {
    struct Regenerate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Regenerate UIDs in DICOM files",
            discussion: """
                Replace UIDs in DICOM files with new unique identifiers. Well-known UIDs
                (Transfer Syntaxes, SOP Classes) are preserved. Use --maintain-relationships
                to ensure consistent UID mapping across files in a study.
                
                Examples:
                  dicom-uid regenerate file.dcm
                  dicom-uid regenerate file.dcm --output new.dcm
                  dicom-uid regenerate file1.dcm file2.dcm --output output_dir/ --maintain-relationships
                  dicom-uid regenerate study/*.dcm --output new/ --export-map mapping.json
                  dicom-uid regenerate file.dcm --root 1.2.826.0.1.3680043.9.1234
                """
        )

        @Argument(help: "Input DICOM file(s)")
        var inputs: [String]

        @Option(name: .shortAndLong, help: "Output file or directory path")
        var output: String?

        @Option(name: .shortAndLong, help: "Custom UID root prefix")
        var root: String?

        @Flag(name: .long, help: "Maintain UID relationships across files (same old UID maps to same new UID)")
        var maintainRelationships: Bool = false

        @Option(name: .long, help: "Export old→new UID mapping to JSON file")
        var exportMap: String?

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        @Flag(name: .long, help: "Show what would be changed without writing")
        var dryRun: Bool = false

        mutating func validate() throws {
            if inputs.isEmpty {
                throw ValidationError("At least one input file is required")
            }
        }

        mutating func run() throws {
            let manager = UIDManager()
            var globalMappings: [String: String] = [:]
            var allMappings: [UIDMapping] = []

            // Determine if output is a directory (multiple files)
            let isMultipleFiles = inputs.count > 1
            var outputDir: String?

            if isMultipleFiles, let out = output {
                outputDir = out
                // Create output directory if it doesn't exist
                if !dryRun {
                    try FileManager.default.createDirectory(
                        atPath: out,
                        withIntermediateDirectories: true
                    )
                }
            }

            for inputPath in inputs {
                guard FileManager.default.fileExists(atPath: inputPath) else {
                    fprintln(UIDConsole.fileNotFoundWarning(path: inputPath))
                    continue
                }

                let outputPath: String?
                if let dir = outputDir {
                    let filename = URL(fileURLWithPath: inputPath).lastPathComponent
                    outputPath = (dir as NSString).appendingPathComponent(filename)
                } else {
                    outputPath = output
                }

                if verbose {
                    fprintln(UIDConsole.processingLine(path: inputPath))
                }

                if dryRun {
                    // Shared preview (Sources/DICOMKit/UIDManagement/UIDManager.swift) so the
                    // CLI and DICOMStudio print byte-identical dry-run output.
                    let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
                    let file = try DICOMFile.read(from: data)
                    for line in UIDManager.regenerationPreviewLines(for: file.dataSet) { print(line) }
                } else {
                    let mappings = try manager.regenerateUIDs(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        root: root,
                        maintainRelationships: maintainRelationships || isMultipleFiles,
                        existingMappings: &globalMappings
                    )

                    allMappings.append(contentsOf: mappings)

                    if verbose {
                        for mapping in mappings {
                            fprintln(UIDConsole.mappingLine(tagName: mapping.tagName, oldUID: mapping.oldUID, newUID: mapping.newUID))
                        }
                    }

                    let outDescription = outputPath ?? inputPath
                    fprintln(UIDConsole.wroteLine(path: outDescription, count: mappings.count))
                }
            }

            // Export mapping if requested
            if let mapPath = exportMap, !dryRun {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let mapData = try encoder.encode(allMappings)
                try mapData.write(to: URL(fileURLWithPath: mapPath))
                fprintln(UIDConsole.mapExportedLine(path: mapPath))
            }

            if dryRun {
                fprintln(UIDConsole.dryRunCompleteLine())
            }
        }
    }
}

// MARK: - Helpers

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMUID.main()
