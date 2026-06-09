import Foundation
import DICOMCore
import DICOMDictionary

// Shared study-organize engine for the `dicom-study organize` CLI and DICOMStudio.
// Joins the already-shared StudyScanner / StudyReport so EVERY dicom-study
// subcommand (summary/check/stats/compare AND organize) runs the exact same code
// and produces text-exact output. No ArgumentParser / printing here — verbose
// progress + the summary flow through the injected `log` closure; the adapters
// route it to stdout (CLI) or the console (app). copyItem/moveItem are used
// directly, so re-running over an existing tree raises the same "already exists"
// error in both adapters (parity).

/// Organizes a directory of DICOM files into a Patient/Study/Series tree.
public struct StudyOrganizer {
    public init() {}

    private struct SeriesGroup {
        let seriesNumber: String?
        let seriesDescription: String?
        let modality: String?
        var filePaths: [String] = []
    }
    private struct StudyGroup {
        let studyDescription: String?
        let patientName: String?
        var series: [String: SeriesGroup] = [:]
        var seriesOrder: [String] = []
    }

    /// Organizes `inputPath` into `outputPath`. `pattern` is "descriptive" or "uid".
    /// `copy` copies (else moves). Verbose per-file lines + the final summary are
    /// emitted via `log`. Throws `StudyError` for bad input and propagates the
    /// FileManager error (e.g. "already exists") if a destination already exists.
    @discardableResult
    public func organize(
        inputPath: String,
        outputPath: String,
        pattern: String,
        copy: Bool,
        verbose: Bool,
        log: (String) -> Void
    ) throws -> (copied: Int, studies: Int) {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw StudyError.directoryNotFound(inputPath)
        }
        guard pattern == "descriptive" || pattern == "uid" else {
            throw StudyError.invalidPattern(pattern)
        }

        if verbose { log("Scanning directory: \(inputPath)") }

        let dicomFiles = collectDICOMFiles(at: inputPath)
        if dicomFiles.isEmpty { throw StudyError.noFilesFound }

        if verbose {
            log("Found \(dicomFiles.count) DICOM files")
            log("Organizing files...")
        }

        // Group by study → series, preserving first-encounter order over the
        // sorted file list (deterministic across CLI and app).
        var studies: [String: StudyGroup] = [:]
        var studyOrder: [String] = []
        for filePath in dicomFiles {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let file = try? DICOMFile.read(from: data) else {
                if verbose { log("Warning: Failed to read \(filePath)") }
                continue
            }
            let ds = file.dataSet
            guard let studyUID = ds.string(for: Tag.studyInstanceUID) else {
                if verbose { log("Warning: Missing StudyInstanceUID in \(filePath)") }
                continue
            }
            let seriesUID = ds.string(for: Tag.seriesInstanceUID) ?? "UNKNOWN_SERIES"
            if studies[studyUID] == nil {
                studies[studyUID] = StudyGroup(
                    studyDescription: ds.string(for: Tag.studyDescription),
                    patientName: ds.string(for: Tag.patientName))
                studyOrder.append(studyUID)
            }
            if studies[studyUID]!.series[seriesUID] == nil {
                studies[studyUID]!.series[seriesUID] = SeriesGroup(
                    seriesNumber: ds.string(for: Tag.seriesNumber),
                    seriesDescription: ds.string(for: Tag.seriesDescription),
                    modality: ds.string(for: Tag.modality))
                studies[studyUID]!.seriesOrder.append(seriesUID)
            }
            studies[studyUID]!.series[seriesUID]!.filePaths.append(filePath)
        }

        try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

        var copiedCount = 0
        for studyUID in studyOrder {
            guard let study = studies[studyUID] else { continue }
            let studyDirName: String
            if pattern == "descriptive" {
                let desc = study.studyDescription ?? "Unknown"
                let pn = study.patientName ?? "Unknown"
                studyDirName = sanitizeFilename("\(pn)_\(desc)_\(studyUID.suffix(8))")
            } else {
                studyDirName = studyUID
            }
            let studyDir = "\(outputPath)/\(studyDirName)"
            try FileManager.default.createDirectory(atPath: studyDir, withIntermediateDirectories: true)

            for seriesUID in study.seriesOrder {
                guard let series = study.series[seriesUID] else { continue }
                let seriesDirName: String
                if pattern == "descriptive" {
                    let num = series.seriesNumber ?? "0"
                    let desc = series.seriesDescription ?? "Unknown"
                    let mod = series.modality ?? "XX"
                    seriesDirName = sanitizeFilename("\(num)_\(mod)_\(desc)")
                } else {
                    seriesDirName = seriesUID
                }
                let seriesDir = "\(studyDir)/\(seriesDirName)"
                try FileManager.default.createDirectory(atPath: seriesDir, withIntermediateDirectories: true)

                for (index, filePath) in series.filePaths.enumerated() {
                    let destPath = "\(seriesDir)/\(index + 1).dcm"
                    // copyItem/moveItem throw if destPath exists — re-running over an
                    // existing tree errors identically in the CLI and the app.
                    if copy {
                        try FileManager.default.copyItem(atPath: filePath, toPath: destPath)
                    } else {
                        try FileManager.default.moveItem(atPath: filePath, toPath: destPath)
                    }
                    copiedCount += 1
                    if verbose {
                        log("  \(copy ? "Copied" : "Moved"): \(URL(fileURLWithPath: filePath).lastPathComponent) → \(destPath)")
                    }
                }
            }
        }

        log("\(copy ? "Copied" : "Moved") \(copiedCount) files to \(outputPath)")
        log("Organized \(studyOrder.count) studies")
        return (copiedCount, studyOrder.count)
    }

    // MARK: - Helpers

    /// All DICOM files under `path`, sorted by path for deterministic ordering.
    private func collectDICOMFiles(at path: String) -> [String] {
        var dicomFiles: [String] = []
        let fm = FileManager.default
        let enumerator = fm.enumerator(atPath: path)
        while let file = enumerator?.nextObject() as? String {
            let filePath = "\(path)/\(file)"
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: filePath, isDirectory: &isDirectory),
               !isDirectory.boolValue,
               file.hasSuffix(".dcm") || isDICOMFile(filePath) {
                dicomFiles.append(filePath)
            }
        }
        return dicomFiles.sorted()
    }

    private func isDICOMFile(_ path: String) -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? fileHandle.close() }
        guard let data = try? fileHandle.read(upToCount: 132), data.count >= 132 else { return false }
        return data.subdata(in: 128..<132) == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}
