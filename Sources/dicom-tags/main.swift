import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

// The tag-editing engine (`TagEditor`) and `TagEditorError` now live in the
// DICOMKit library so the CLI and DICOMStudio run the exact same code. This CLI
// is a thin adapter: parse argv → read file(s) → TagEditor.applyChanges → print
// → write.
@available(macOS 10.15, *)
struct DICOMTags: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-tags",
        abstract: "Add, modify, and delete tags in DICOM files",
        discussion: """
            Manipulate DICOM tags by setting values, deleting tags, removing private tags,
            or copying tags from another DICOM file. Supports tag specification by name
            (e.g., PatientName) or hex format (e.g., 0010,0010).

            Examples:
              dicom-tags file.dcm --set PatientName=DOE^JOHN
              dicom-tags file.dcm --set 0010,0010=DOE^JOHN --output modified.dcm
              dicom-tags file.dcm --delete PatientName --delete PatientBirthDate
              dicom-tags file.dcm --delete-private --output clean.dcm
              dicom-tags file.dcm --copy-from source.dcm --tags PatientName,PatientID
              dicom-tags file.dcm --set StudyDescription=Research --delete AccessionNumber --dry-run
            """,
        version: "1.3.1"
    )

    @Argument(help: "Input DICOM file path")
    var input: String

    @Option(name: .shortAndLong, help: "Output file path (defaults to overwrite input)")
    var output: String?

    @Option(name: .long, help: "Tag values to set (format: TagName=Value or GGGG,EEEE=Value)")
    var set: [String] = []

    @Option(name: .long, help: "Tags to delete (by name or GGGG,EEEE)")
    var delete: [String] = []

    @Flag(name: .long, help: "Delete all private tags (odd group numbers)")
    var deletePrivate: Bool = false

    @Option(name: .long, help: "Copy tags from another DICOM file")
    var copyFrom: String?

    @Option(name: .long, help: "Comma-separated tag names to copy (used with --copy-from)")
    var tags: String?

    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Show what would be changed without writing")
    var dryRun: Bool = false

    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: input) else {
            throw TagEditorError.fileNotFound(input)
        }

        let copyTags: [String] = tags?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? []

        if let copyFrom = copyFrom {
            guard FileManager.default.fileExists(atPath: copyFrom) else {
                throw TagEditorError.fileNotFound(copyFrom)
            }
        }

        if set.isEmpty && delete.isEmpty && !deletePrivate && copyFrom == nil {
            throw TagEditorError.noOperationsSpecified
        }

        // Read input + optional copy-from source.
        let dicomFile = try DICOMFile.read(from: try Data(contentsOf: URL(fileURLWithPath: input)))
        var dataSet = dicomFile.dataSet

        var sourceDataSet: DataSet?
        if let copyFrom = copyFrom {
            let sourceFile = try DICOMFile.read(from: try Data(contentsOf: URL(fileURLWithPath: copyFrom)))
            sourceDataSet = sourceFile.dataSet
        }

        // Apply all operations via the shared DICOMKit engine.
        let editor = TagEditor()
        let changes = editor.applyChanges(
            to: &dataSet,
            sets: set,
            deletes: delete,
            deletePrivate: deletePrivate,
            sourceDataSet: sourceDataSet,
            copyTags: copyTags,
            verbose: verbose,
            dryRun: dryRun
        )

        if verbose || dryRun {
            for change in changes { fprintln(change) }
            fprintln("\(changes.count) change(s) applied.")
        }

        let destPath = OutputPathResolver.resolveFileOutput(output: output, input: input)
        if !dryRun {
            let modifiedFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: dataSet)
            let outputData = try modifiedFile.write()
            let destURL = URL(fileURLWithPath: destPath)
            try FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try outputData.write(to: destURL)
        }

        if dryRun {
            fprintln("Dry run complete — no files modified.")
        } else {
            fprintln("Output written to: \(destPath)")
        }
    }
}

private func fprintln(_ message: String) {
    // Route the change preview / dry-run summary to STDOUT so the CLI and DICOMStudio
    // (which shows it in-console) are text-exact. These are results, not errors.
    print(message)
}

DICOMTags.main()
