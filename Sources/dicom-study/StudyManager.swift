import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

// StudyError, the study metadata models (StudyMetadata/SeriesMetadata/
// InstanceMetadata), the analysis result types (Statistics/StudyComparison/
// SeriesDifference), the scanner (StudyScanner) and the renderers (StudyReport)
// now live in the DICOMKit library (Sources/DICOMKit/Study/) so the CLI and
// DICOMStudio run the exact same code. The summary/check/stats/compare engine
// types below are thin CLI adapters over that shared code; StudyOrganizer (file
// moves) remains CLI-local.

// MARK: - Study Organizer

struct StudyOrganizer {
    func organize(
        inputPath: String,
        outputPath: String,
        pattern: String,
        copy: Bool,
        verbose: Bool
    ) throws {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw StudyError.directoryNotFound(inputPath)
        }

        guard pattern == "descriptive" || pattern == "uid" else {
            throw StudyError.invalidPattern(pattern)
        }

        if verbose {
            fprintln("Scanning directory: \(inputPath)")
        }

        let dicomFiles = try collectDICOMFiles(at: inputPath, verbose: verbose)

        if dicomFiles.isEmpty {
            throw StudyError.noFilesFound
        }

        if verbose {
            fprintln("Found \(dicomFiles.count) DICOM files")
            fprintln("Organizing files...")
        }

        let studies = try groupFilesByStudy(dicomFiles, verbose: verbose)

        try createOutputDirectory(at: outputPath)

        var copiedCount = 0
        for (studyUID, studyInfo) in studies {
            let studyDir = try createStudyDirectory(
                at: outputPath,
                studyUID: studyUID,
                studyInfo: studyInfo,
                pattern: pattern
            )

            for (seriesUID, seriesFiles) in studyInfo.series {
                let seriesDir = try createSeriesDirectory(
                    at: studyDir,
                    seriesUID: seriesUID,
                    seriesInfo: seriesFiles,
                    pattern: pattern
                )

                for (index, filePath) in seriesFiles.filePaths.enumerated() {
                    let destPath = "\(seriesDir)/\(index + 1).dcm"
                    if copy {
                        try FileManager.default.copyItem(atPath: filePath, toPath: destPath)
                    } else {
                        try FileManager.default.moveItem(atPath: filePath, toPath: destPath)
                    }
                    copiedCount += 1

                    if verbose {
                        fprintln("  \(copy ? "Copied" : "Moved"): \(URL(fileURLWithPath: filePath).lastPathComponent) → \(destPath)")
                    }
                }
            }
        }

        fprintln("\(copy ? "Copied" : "Moved") \(copiedCount) files to \(outputPath)")
        fprintln("Organized \(studies.count) studies")
    }

    private func collectDICOMFiles(at path: String, verbose: Bool) throws -> [String] {
        var dicomFiles: [String] = []
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: path)

        while let file = enumerator?.nextObject() as? String {
            let filePath = "\(path)/\(file)"
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory),
               !isDirectory.boolValue,
               file.hasSuffix(".dcm") || isDICOMFile(filePath) {
                dicomFiles.append(filePath)
            }
        }

        return dicomFiles
    }

    private func isDICOMFile(_ path: String) -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? fileHandle.close() }

        guard let data = try? fileHandle.read(upToCount: 132) else { return false }
        guard data.count >= 132 else { return false }

        let dicmPrefix = data.subdata(in: 128..<132)
        return dicmPrefix == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
    }

    private func groupFilesByStudy(_ files: [String], verbose: Bool) throws -> [String: StudyGroupInfo] {
        var studies: [String: StudyGroupInfo] = [:]

        for filePath in files {
            do {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                    continue
                }

                let file = try DICOMFile.read(from: data)
                let dataset = file.dataSet

                guard let studyUID = dataset.string(for: Tag.studyInstanceUID) else {
                    if verbose {
                        fprintln("Warning: Missing StudyInstanceUID in \(filePath)")
                    }
                    continue
                }

                let seriesUID = dataset.string(for: Tag.seriesInstanceUID) ?? "UNKNOWN_SERIES"

                if studies[studyUID] == nil {
                    studies[studyUID] = StudyGroupInfo(
                        studyDescription: dataset.string(for: Tag.studyDescription),
                        patientName: dataset.string(for: Tag.patientName),
                        series: [:]
                    )
                }

                if studies[studyUID]!.series[seriesUID] == nil {
                    studies[studyUID]!.series[seriesUID] = SeriesGroupInfo(
                        seriesNumber: dataset.string(for: Tag.seriesNumber),
                        seriesDescription: dataset.string(for: Tag.seriesDescription),
                        modality: dataset.string(for: Tag.modality),
                        filePaths: []
                    )
                }

                studies[studyUID]!.series[seriesUID]!.filePaths.append(filePath)
            } catch {
                if verbose {
                    fprintln("Warning: Failed to read \(filePath): \(error.localizedDescription)")
                }
            }
        }

        return studies
    }

    private func createOutputDirectory(at path: String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func createStudyDirectory(
        at basePath: String,
        studyUID: String,
        studyInfo: StudyGroupInfo,
        pattern: String
    ) throws -> String {
        let dirName: String
        if pattern == "descriptive" {
            let desc = studyInfo.studyDescription ?? "Unknown"
            let patientName = studyInfo.patientName ?? "Unknown"
            dirName = sanitizeFilename("\(patientName)_\(desc)_\(studyUID.suffix(8))")
        } else {
            dirName = studyUID
        }

        let studyPath = "\(basePath)/\(dirName)"
        try FileManager.default.createDirectory(
            atPath: studyPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return studyPath
    }

    private func createSeriesDirectory(
        at studyPath: String,
        seriesUID: String,
        seriesInfo: SeriesGroupInfo,
        pattern: String
    ) throws -> String {
        let dirName: String
        if pattern == "descriptive" {
            let seriesNum = seriesInfo.seriesNumber ?? "0"
            let desc = seriesInfo.seriesDescription ?? "Unknown"
            let modality = seriesInfo.modality ?? "XX"
            dirName = sanitizeFilename("\(seriesNum)_\(modality)_\(desc)")
        } else {
            dirName = seriesUID
        }

        let seriesPath = "\(studyPath)/\(dirName)"
        try FileManager.default.createDirectory(
            atPath: seriesPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return seriesPath
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

struct StudyGroupInfo {
    let studyDescription: String?
    let patientName: String?
    var series: [String: SeriesGroupInfo]
}

struct SeriesGroupInfo {
    let seriesNumber: String?
    let seriesDescription: String?
    let modality: String?
    var filePaths: [String]
}

// MARK: - Thin CLI adapters over the shared DICOMKit study engine

struct StudyAnalyzer {
    func summarize(path: String, format: String, verbose: Bool) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw StudyError.directoryNotFound(path)
        }
        let studies = StudyScanner.scanStudies(at: path)
        if studies.isEmpty { throw StudyError.noFilesFound }
        print(try StudyReport.renderSummary(studies: studies, format: format, verbose: verbose), terminator: "")
    }
}

struct CompletenessChecker {
    func check(
        studyPath: String,
        expectedSeries: Int?,
        expectedInstances: Int?,
        reportPath: String?,
        verbose: Bool
    ) throws {
        guard FileManager.default.fileExists(atPath: studyPath) else {
            throw StudyError.directoryNotFound(studyPath)
        }
        // The completeness result is this command's primary output, so it goes to
        // stdout (consistent with summary/stats/compare, and matching DICOMStudio).
        if verbose {
            print("Checking study completeness: \(studyPath)")
        }
        let studies = StudyScanner.scanStudies(at: studyPath)
        guard let study = studies.first else {
            throw StudyError.noFilesFound
        }
        let result = StudyReport.evaluateCompleteness(
            study: study,
            expectedSeries: expectedSeries,
            expectedInstances: expectedInstances
        )
        print(result.output, terminator: "")
        if let reportPath = reportPath {
            let report = result.issues.joined(separator: "\n")
            try report.write(toFile: reportPath, atomically: true, encoding: .utf8)
            print("Report written to: \(reportPath)")
        }
    }
}

struct StatsCalculator {
    func calculateStats(studyPath: String, detailed: Bool, format: String) throws {
        guard FileManager.default.fileExists(atPath: studyPath) else {
            throw StudyError.directoryNotFound(studyPath)
        }
        let studies = StudyScanner.scanStudies(at: studyPath)
        guard let study = studies.first else {
            throw StudyError.noFilesFound
        }
        let stats = StudyReport.computeStatistics(for: study, detailed: detailed)
        print(try StudyReport.renderStats(stats, detailed: detailed, format: format), terminator: "")
    }
}

struct StudyComparator {
    func compare(study1Path: String, study2Path: String, format: String, verbose: Bool) throws {
        guard FileManager.default.fileExists(atPath: study1Path) else {
            throw StudyError.directoryNotFound(study1Path)
        }
        guard FileManager.default.fileExists(atPath: study2Path) else {
            throw StudyError.directoryNotFound(study2Path)
        }
        let studies1 = StudyScanner.scanStudies(at: study1Path)
        let studies2 = StudyScanner.scanStudies(at: study2Path)
        guard let study1 = studies1.first else { throw StudyError.noFilesFound }
        guard let study2 = studies2.first else { throw StudyError.noFilesFound }
        let comparison = StudyReport.compareStudies(study1, study2)
        print(try StudyReport.renderComparison(comparison, format: format, verbose: verbose), terminator: "")
    }
}

// MARK: - Helper Functions

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
