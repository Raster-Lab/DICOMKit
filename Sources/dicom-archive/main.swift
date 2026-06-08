import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

// The archive index model, helpers, and every operation now live in the DICOMKit
// library (Sources/DICOMKit/Archive/ArchiveStore.swift) so the CLI and DICOMStudio
// run the exact same code. This CLI is a thin adapter: parse argv, call the shared
// ArchiveStore operation, and print the rendered output.

// MARK: - Main Command

struct DICOMArchive: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-archive",
        abstract: "Local DICOM file archive manager",
        discussion: """
            Manage a local archive of DICOM files with a JSON-based metadata index.
            Files are organized in a Patient/Study/Series directory hierarchy with
            deduplication by SOP Instance UID.

            Examples:
              # Initialize a new archive
              dicom-archive init --path /data/archive

              # Import DICOM files
              dicom-archive import file1.dcm file2.dcm --archive /data/archive

              # Query archive metadata
              dicom-archive query --archive /data/archive --patient-name "DOE*"

              # List archive contents
              dicom-archive list --archive /data/archive

              # Export files from archive
              dicom-archive export --archive /data/archive --study-uid 1.2.3 --output /tmp/out

              # Check archive integrity
              dicom-archive check --archive /data/archive

              # Show archive statistics
              dicom-archive stats --archive /data/archive
            """,
        version: "1.2.1",
        subcommands: [
            Init.self,
            Import.self,
            Query.self,
            List.self,
            Export.self,
            Check.self,
            Stats.self
        ]
    )
}

// MARK: - Init Subcommand

extension DICOMArchive {
    struct Init: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Initialize a new DICOM archive"
        )

        @Option(name: .shortAndLong, help: "Path for the new archive directory")
        var path: String

        @Flag(name: .long, help: "Overwrite existing archive")
        var force: Bool = false

        mutating func run() throws {
            print(try ArchiveStore.initArchive(at: path, force: force), terminator: "")
        }
    }
}

// MARK: - Import Subcommand

extension DICOMArchive {
    struct Import: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import DICOM files into the archive"
        )

        @Argument(help: "DICOM files or directories to import")
        var files: [String]

        @Option(name: .shortAndLong, help: "Path to the archive")
        var archive: String

        @Flag(name: .long, help: "Recursive import from directories")
        var recursive: Bool = false

        @Flag(name: .long, help: "Skip duplicate SOP Instance UIDs without error")
        var skipDuplicates: Bool = false

        @Flag(name: .long, help: "Verbose output")
        var verbose: Bool = false

        mutating func run() throws {
            print(try ArchiveStore.importFiles(
                into: archive, files: files, recursive: recursive,
                skipDuplicates: skipDuplicates, verbose: verbose), terminator: "")
        }
    }
}

// MARK: - Query Subcommand

extension DICOMArchive {
    struct Query: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "query",
            abstract: "Query archive metadata"
        )

        @Option(name: .shortAndLong, help: "Path to the archive")
        var archive: String

        @Option(name: .long, help: "Filter by patient name (supports * and ? wildcards)")
        var patientName: String?

        @Option(name: .long, help: "Filter by patient ID (supports * and ? wildcards)")
        var patientID: String?

        @Option(name: .long, help: "Filter by study UID")
        var studyUID: String?

        @Option(name: .long, help: "Filter by modality")
        var modality: String?

        @Option(name: .long, help: "Filter by study date (YYYYMMDD)")
        var studyDate: String?

        @Option(name: .shortAndLong, help: "Output format: table, json, text")
        var format: String = "table"

        mutating func run() throws {
            print(try ArchiveStore.query(
                in: archive, patientName: patientName, patientID: patientID,
                studyUID: studyUID, modality: modality, studyDate: studyDate,
                format: format), terminator: "")
        }
    }
}

// MARK: - List Subcommand

extension DICOMArchive {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List archive contents"
        )

        @Option(name: .shortAndLong, help: "Path to the archive")
        var archive: String

        @Option(name: .shortAndLong, help: "Output format: tree, table, json")
        var format: String = "tree"

        @Flag(name: .long, help: "Show individual instances")
        var showInstances: Bool = false

        mutating func run() throws {
            print(try ArchiveStore.list(in: archive, format: format, showInstances: showInstances), terminator: "")
        }
    }
}

// MARK: - Export Subcommand

extension DICOMArchive {
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export files from the archive"
        )

        @Option(name: .shortAndLong, help: "Path to the archive")
        var archive: String

        @Option(name: .shortAndLong, help: "Output directory for exported files")
        var output: String

        @Option(name: .long, help: "Export by Study Instance UID")
        var studyUID: String?

        @Option(name: .long, help: "Export by Series Instance UID")
        var seriesUID: String?

        @Option(name: .long, help: "Export by Patient ID")
        var patientID: String?

        @Flag(name: .long, help: "Flatten output (no subdirectories)")
        var flatten: Bool = false

        @Flag(name: .long, help: "Verbose output")
        var verbose: Bool = false

        mutating func run() throws {
            print(try ArchiveStore.export(
                from: archive, output: output, studyUID: studyUID, seriesUID: seriesUID,
                patientID: patientID, flatten: flatten, verbose: verbose), terminator: "")
        }
    }
}

// MARK: - Check Subcommand

extension DICOMArchive {
    struct Check: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "check",
            abstract: "Check archive integrity"
        )

        @Option(name: .shortAndLong, help: "Path to the archive")
        var archive: String

        @Flag(name: .long, help: "Verify DICOM file readability")
        var verifyFiles: Bool = false

        @Flag(name: .long, help: "Verbose output")
        var verbose: Bool = false

        mutating func run() throws {
            print(try ArchiveStore.check(in: archive, verifyFiles: verifyFiles, verbose: verbose), terminator: "")
        }
    }
}

// MARK: - Stats Subcommand

extension DICOMArchive {
    struct Stats: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Show archive statistics"
        )

        @Option(name: .shortAndLong, help: "Path to the archive")
        var archive: String

        @Option(name: .shortAndLong, help: "Output format: text, json")
        var format: String = "text"

        mutating func run() throws {
            print(try ArchiveStore.stats(in: archive, format: format), terminator: "")
        }
    }
}

DICOMArchive.main()
