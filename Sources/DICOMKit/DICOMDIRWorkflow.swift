//
// DICOMDIRWorkflow.swift
// DICOMKit
//
// Shared orchestration helpers for the `dicom-dcmdir` workflow.
//
// The `dicom-dcmdir` CLI and DICOMStudio's CLI Workshop must produce
// byte-identical output for CLI-parity. The DICOMDIR `dump` output is already
// shared through `DICOMDIRDumpFormatter`; this file does the same for the
// remaining surfaces that both call sites previously hand-mirrored:
//
//   • DICOM-file discovery (the recursive/flat scan that skips an existing
//     DICOMDIR and sorts by path),
//   • the create build-loop (read each file, compute its relative path, add it
//     to the `DICOMDirectory.Builder`), and its summary block,
//   • the `validate` report (statistics + file-set + optional record-type
//     breakdown).
//
// Both surfaces call the helpers below, so this orchestration cannot silently
// drift between them. Output WRITING (sandbox-aware on the app side) and
// argument parsing / exit-code conventions stay with each caller.
//

import Foundation
import DICOMCore

public enum DICOMDIRWorkflow {

    // MARK: - Errors

    public enum WorkflowError: Error, CustomStringConvertible {
        /// No DICOM files were found under the input directory.
        case noDICOMFiles
        public var description: String {
            switch self {
            case .noDICOMFiles: return "No DICOM files found"
            }
        }
    }

    // MARK: - Path resolution (directory ⇄ DICOMDIR file)

    /// True when `path` denotes a directory: it ends with a path separator, or it
    /// exists on disk as a directory.
    public static func isDirectoryPath(_ path: String) -> Bool {
        if path.hasSuffix("/") { return true }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Resolves a user-supplied path to the DICOMDIR *file* it refers to. A DICOMDIR
    /// is a single index file conventionally named `DICOMDIR`; when the user points at
    /// a directory (the media folder) the file is `<dir>/DICOMDIR`. Shared by every
    /// `dicom-dcmdir` subcommand so "create into a folder", "validate a folder", and
    /// "dump a folder" all work — and so a write never targets a directory path (which
    /// fails with "the file … couldn't be saved in the folder …").
    public static func resolvedDICOMDIRPath(_ path: String) -> String {
        isDirectoryPath(path) ? (path as NSString).appendingPathComponent("DICOMDIR") : path
    }

    /// URL variant of `resolvedDICOMDIRPath` — appends `DICOMDIR` when `url` is a
    /// directory (so a security-scoped folder grant is preserved), else returns it
    /// unchanged.
    public static func resolvedDICOMDIRURL(_ url: URL) -> URL {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if (exists && isDir.boolValue) || url.hasDirectoryPath {
            return url.appendingPathComponent("DICOMDIR")
        }
        return url
    }

    // MARK: - File discovery

    /// Finds the DICOM files under `directory`, skipping any existing `DICOMDIR`
    /// index file, sorted by path for deterministic ordering. Shared verbatim by
    /// the CLI's `create` and the Studio reimplementation so the file set (and its
    /// order, which fixes the directory-record order) cannot drift between them.
    public static func findDICOMFiles(in directory: URL, recursive: Bool) throws -> [URL] {
        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        var files: [URL] = []

        if recursive {
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else {
                throw WorkflowError.noDICOMFiles
            }
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if values.isRegularFile == true, fileURL.lastPathComponent != "DICOMDIR" {
                    files.append(fileURL)
                }
            }
        } else {
            let contents = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            for fileURL in contents {
                let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if values.isRegularFile == true, fileURL.lastPathComponent != "DICOMDIR" {
                    files.append(fileURL)
                }
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    // MARK: - Create

    /// The outcome of building a DICOMDIR from a directory of DICOM files.
    public struct CreateResult: Sendable {
        public let directory: DICOMDirectory
        /// Files successfully added to the index.
        public let processed: Int
        /// Files that could not be added (unreadable / non-conformant).
        public let failed: Int
        /// Total candidate files discovered.
        public let total: Int
    }

    /// Builds a DICOMDIR from the DICOM files under `inputURL`, using the shared
    /// `DICOMDirectory.Builder`. The relative path stored for each file is computed
    /// the same way on both surfaces (relative to the input directory), so the two
    /// produced DICOMDIRs are byte-identical for the same input.
    ///
    /// `progress` receives the human-readable verbose lines ("Found N DICOM files",
    /// the per-file "[i/n] Processing …", and any per-file failure) so the CLI can
    /// `print` them and the app can append them — identical text either way. It is
    /// only invoked when `verbose` is true.
    ///
    /// Throws `WorkflowError.noDICOMFiles` when the directory holds no DICOM files.
    public static func buildDirectory(
        fromFilesIn inputURL: URL,
        recursive: Bool,
        strict: Bool,
        fileSetID: String,
        profile: DICOMDIRProfile,
        verbose: Bool = false,
        progress: ((String) -> Void)? = nil
    ) throws -> CreateResult {
        let dicomFiles = try findDICOMFiles(in: inputURL, recursive: recursive)
        guard !dicomFiles.isEmpty else { throw WorkflowError.noDICOMFiles }

        if verbose { progress?("Found \(dicomFiles.count) DICOM files\n\n") }

        var builder = DICOMDirectory.Builder(fileSetID: fileSetID, profile: profile)
        var processed = 0
        var failed = 0

        for (index, fileURL) in dicomFiles.enumerated() {
            if verbose { progress?("[\(index + 1)/\(dicomFiles.count)] Processing \(fileURL.lastPathComponent)...\n") }
            do {
                let fileData = try Data(contentsOf: fileURL)
                let dicomFile = try DICOMFile.read(from: fileData, force: !strict)
                let relativePath = fileURL.path.replacingOccurrences(of: inputURL.path + "/", with: "")
                let pathComponents = relativePath.components(separatedBy: "/")
                try builder.addFile(dicomFile, relativePath: pathComponents)
                processed += 1
            } catch {
                failed += 1
                if verbose { progress?("  Failed: \(error.localizedDescription)\n") }
            }
        }

        return CreateResult(directory: builder.build(), processed: processed,
                            failed: failed, total: dicomFiles.count)
    }

    /// Renders the create summary block, shared verbatim by the CLI and the Studio
    /// reimplementation. The returned string begins and ends with a newline so the
    /// CLI can emit it with `print(summary, terminator: "")` and the app can append
    /// it directly to its console buffer.
    public static func renderCreateSummary(_ result: CreateResult, outputPath: String) -> String {
        let stats = result.directory.statistics()
        var s = ""
        s += "\n"
        s += "✅ DICOMDIR created successfully\n"
        s += "\n"
        s += "Summary:\n"
        s += "  Files processed: \(result.processed)/\(result.total)\n"
        if result.failed > 0 { s += "  Failed: \(result.failed)\n" }
        s += "  Patients: \(stats.patientCount)\n"
        s += "  Studies: \(stats.studyCount)\n"
        s += "  Series: \(stats.seriesCount)\n"
        s += "  Images: \(stats.imageCount)\n"
        s += "\n"
        s += "Output: \(outputPath)\n"
        return s
    }

    // MARK: - Validate

    /// Renders the `validate` success report (everything after the "Validating …"
    /// header line), shared verbatim by the CLI and the Studio reimplementation.
    /// The caller emits the header and handles the read / validation failure paths
    /// (with its own exit-code convention); on success it emits this block.
    ///
    /// The returned string begins with the "valid" confirmation line and ends with
    /// a trailing newline so the CLI can `print(report, terminator: "")` and the
    /// app can append it directly.
    public static func renderValidationReport(_ directory: DICOMDirectory, detailed: Bool) -> String {
        let stats = directory.statistics()
        var s = ""
        s += "✅ DICOMDIR structure is valid\n"
        s += "\n"
        s += "Statistics:\n"
        s += "  Patients: \(stats.patientCount)\n"
        s += "  Studies: \(stats.studyCount)\n"
        s += "  Series: \(stats.seriesCount)\n"
        s += "  Images: \(stats.imageCount)\n"
        s += "  Total records: \(stats.totalRecordCount)\n"
        s += "  Active records: \(stats.activeRecordCount)\n"
        s += "  Inactive records: \(stats.inactiveRecordCount)\n"
        s += "\n"
        s += "File-set:\n"
        s += "  ID: \(directory.fileSetID.isEmpty ? "<none>" : directory.fileSetID)\n"
        s += "  Profile: \(directory.profile.rawValue)\n"
        s += "  Consistent: \(directory.isConsistent ? "Yes" : "No")\n"

        if detailed {
            s += "\n"
            s += "Records by type:\n"
            let allRecords = directory.allRecords()
            let recordTypes = Set(allRecords.map { $0.recordType })
            for recordType in recordTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
                let count = allRecords.filter { $0.recordType == recordType }.count
                s += "  \(recordType.rawValue): \(count)\n"
            }
        }

        s += "\n"
        s += "✅ Validation complete\n"
        return s
    }
}
