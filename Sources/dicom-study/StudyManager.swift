import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

// MARK: - Errors

enum StudyError: Error, LocalizedError {
    case directoryNotFound(String)
    case fileNotFound(String)
    case invalidDICOMFile(String)
    case noFilesFound
    case invalidPattern(String)
    case writeError(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidDICOMFile(let path):
            return "Invalid DICOM file: \(path)"
        case .noFilesFound:
            return "No DICOM files found in the specified directory"
        case .invalidPattern(let pattern):
            return "Invalid naming pattern: \(pattern). Use 'descriptive' or 'uid'"
        case .writeError(let msg):
            return "Write error: \(msg)"
        }
    }
}

// MARK: - Study Metadata

struct StudyMetadata: Codable {
    let studyInstanceUID: String
    let studyDate: String?
    let studyTime: String?
    let studyDescription: String?
    let patientName: String?
    let patientID: String?
    let accessionNumber: String?
    var series: [SeriesMetadata] = []
    
    var totalInstances: Int {
        series.reduce(0) { $0 + $1.instances.count }
    }
}

struct SeriesMetadata: Codable {
    let seriesInstanceUID: String
    let seriesNumber: String?
    let seriesDescription: String?
    let modality: String?
    var instances: [InstanceMetadata] = []
}

struct InstanceMetadata: Codable {
    let sopInstanceUID: String
    let instanceNumber: String?
    let filePath: String
    let fileSize: Int64
}

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

// MARK: - Study Analyzer

struct StudyAnalyzer {
    func summarize(path: String, format: String, verbose: Bool) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw StudyError.directoryNotFound(path)
        }
        
        let studies = try scanStudies(at: path, verbose: verbose)
        
        if studies.isEmpty {
            throw StudyError.noFilesFound
        }
        
        switch format {
        case "json":
            try outputJSON(studies: studies)
        case "csv":
            try outputCSV(studies: studies, verbose: verbose)
        case "table":
            outputTable(studies: studies, verbose: verbose)
        default:
            throw StudyError.invalidPattern(format)
        }
    }
    
    func scanStudies(at path: String, verbose: Bool) throws -> [StudyMetadata] {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        
        if !isDirectory.boolValue {
            // Single file
            return [try scanSingleFile(path)]
        }
        
        // Directory - scan all DICOM files
        var studiesDict: [String: StudyMetadata] = [:]
        let enumerator = FileManager.default.enumerator(atPath: path)
        
        while let file = enumerator?.nextObject() as? String {
            let filePath = "\(path)/\(file)"
            var isDir: ObjCBool = false
            
            guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir),
                  !isDir.boolValue else { continue }
            
            do {
                let fileMetadata = try scanSingleFile(filePath)
                let studyUID = fileMetadata.studyInstanceUID
                
                if var existingStudy = studiesDict[studyUID] {
                    // Merge series
                    for newSeries in fileMetadata.series {
                        if let existingSeriesIndex = existingStudy.series.firstIndex(where: { $0.seriesInstanceUID == newSeries.seriesInstanceUID }) {
                            existingStudy.series[existingSeriesIndex].instances.append(contentsOf: newSeries.instances)
                        } else {
                            existingStudy.series.append(newSeries)
                        }
                    }
                    studiesDict[studyUID] = existingStudy
                } else {
                    studiesDict[studyUID] = fileMetadata
                }
            } catch {
                if verbose {
                    fprintln("Warning: Failed to read \(filePath): \(error.localizedDescription)")
                }
            }
        }
        
        return Array(studiesDict.values).sorted { $0.studyInstanceUID < $1.studyInstanceUID }
    }
    
    private func scanSingleFile(_ path: String) throws -> StudyMetadata {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw StudyError.invalidDICOMFile(path)
        }
        
        let file = try DICOMFile.read(from: data)
        let dataset = file.dataSet
        
        guard let studyUID = dataset.string(for: Tag.studyInstanceUID) else {
            throw StudyError.invalidDICOMFile(path)
        }
        
        let seriesUID = dataset.string(for: Tag.seriesInstanceUID) ?? "UNKNOWN"
        let sopInstanceUID = dataset.string(for: Tag.sopInstanceUID) ?? "UNKNOWN"
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 ?? 0
        
        let instance = InstanceMetadata(
            sopInstanceUID: sopInstanceUID,
            instanceNumber: dataset.string(for: Tag.instanceNumber),
            filePath: path,
            fileSize: fileSize
        )
        
        let series = SeriesMetadata(
            seriesInstanceUID: seriesUID,
            seriesNumber: dataset.string(for: Tag.seriesNumber),
            seriesDescription: dataset.string(for: Tag.seriesDescription),
            modality: dataset.string(for: Tag.modality),
            instances: [instance]
        )
        
        return StudyMetadata(
            studyInstanceUID: studyUID,
            studyDate: dataset.string(for: Tag.studyDate),
            studyTime: dataset.string(for: Tag.studyTime),
            studyDescription: dataset.string(for: Tag.studyDescription),
            patientName: dataset.string(for: Tag.patientName),
            patientID: dataset.string(for: Tag.patientID),
            accessionNumber: dataset.string(for: Tag.accessionNumber),
            series: [series]
        )
    }
    
    private func outputJSON(studies: [StudyMetadata]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(studies)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    private func outputCSV(studies: [StudyMetadata], verbose: Bool) throws {
        print("StudyUID,StudyDate,PatientName,PatientID,SeriesCount,InstanceCount")
        for study in studies {
            let studyDate = study.studyDate ?? ""
            let patientName = study.patientName ?? ""
            let patientID = study.patientID ?? ""
            print("\(study.studyInstanceUID),\(studyDate),\(patientName),\(patientID),\(study.series.count),\(study.totalInstances)")
        }
    }
    
    private func outputTable(studies: [StudyMetadata], verbose: Bool) {
        for study in studies {
            print("═══════════════════════════════════════════════════════════════")
            print("Study UID: \(study.studyInstanceUID)")
            if let studyDate = study.studyDate {
                print("Study Date: \(studyDate)")
            }
            if let patientName = study.patientName {
                print("Patient Name: \(patientName)")
            }
            if let patientID = study.patientID {
                print("Patient ID: \(patientID)")
            }
            if let studyDesc = study.studyDescription {
                print("Description: \(studyDesc)")
            }
            print("Series Count: \(study.series.count)")
            print("Total Instances: \(study.totalInstances)")
            
            if verbose {
                print("\nSeries:")
                for (index, series) in study.series.enumerated() {
                    print("  [\(index + 1)] \(series.seriesInstanceUID)")
                    if let seriesNum = series.seriesNumber {
                        print("      Number: \(seriesNum)")
                    }
                    if let modality = series.modality {
                        print("      Modality: \(modality)")
                    }
                    if let desc = series.seriesDescription {
                        print("      Description: \(desc)")
                    }
                    print("      Instances: \(series.instances.count)")
                }
            }
            print("")
        }
    }
}

// MARK: - Completeness Checker

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
        
        if verbose {
            fprintln("Checking study completeness: \(studyPath)")
        }
        
        let analyzer = StudyAnalyzer()
        let studies = try analyzer.scanStudies(at: studyPath, verbose: false)
        
        guard let study = studies.first else {
            throw StudyError.noFilesFound
        }
        
        var issues: [String] = []
        var isComplete = true
        
        // Check series count
        if let expected = expectedSeries {
            if study.series.count != expected {
                issues.append("Expected \(expected) series, found \(study.series.count)")
                isComplete = false
            }
        }
        
        // Check instances per series
        for series in study.series {
            if let expected = expectedInstances {
                if series.instances.count != expected {
                    let seriesDesc = series.seriesDescription ?? series.seriesInstanceUID
                    issues.append("Series '\(seriesDesc)': Expected \(expected) instances, found \(series.instances.count)")
                    isComplete = false
                }
            }
            
            // Check for missing slices (gaps in instance numbers)
            let instanceNumbers = series.instances.compactMap { $0.instanceNumber }.compactMap { Int($0) }.sorted()
            if !instanceNumbers.isEmpty {
                let minNum = instanceNumbers.first!
                let maxNum = instanceNumbers.last!
                let expectedRange = Set(minNum...maxNum)
                let actualSet = Set(instanceNumbers)
                let missing = expectedRange.subtracting(actualSet)
                
                if !missing.isEmpty {
                    let seriesDesc = series.seriesDescription ?? series.seriesInstanceUID
                    issues.append("Series '\(seriesDesc)': Missing instance numbers: \(missing.sorted())")
                    isComplete = false
                }
            }
        }
        
        // Output results
        if isComplete {
            fprintln("✓ Study is complete")
        } else {
            fprintln("✗ Study has \(issues.count) issues:")
            for issue in issues {
                fprintln("  - \(issue)")
            }
        }
        
        // Write report if requested
        if let reportPath = reportPath {
            let report = issues.joined(separator: "\n")
            try report.write(toFile: reportPath, atomically: true, encoding: .utf8)
            fprintln("Report written to: \(reportPath)")
        }
    }
}

// MARK: - Stats Calculator

struct StatsCalculator {
    func calculateStats(studyPath: String, detailed: Bool, format: String) throws {
        guard FileManager.default.fileExists(atPath: studyPath) else {
            throw StudyError.directoryNotFound(studyPath)
        }
        
        let analyzer = StudyAnalyzer()
        let studies = try analyzer.scanStudies(at: studyPath, verbose: false)
        
        guard let study = studies.first else {
            throw StudyError.noFilesFound
        }
        
        let stats = computeStatistics(for: study, detailed: detailed)
        
        if format == "json" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(stats)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            outputStatsText(stats: stats, detailed: detailed)
        }
    }
    
    private func computeStatistics(for study: StudyMetadata, detailed: Bool) -> Statistics {
        let totalInstances = study.totalInstances
        let totalSize = study.series.flatMap { $0.instances }.reduce(0) { $0 + $1.fileSize }
        let avgSizePerInstance = totalInstances > 0 ? totalSize / Int64(totalInstances) : 0
        
        var modalityCounts: [String: Int] = [:]
        for series in study.series {
            let modality = series.modality ?? "Unknown"
            modalityCounts[modality, default: 0] += 1
        }
        
        var instancesPerSeries: [Int] = []
        for series in study.series {
            instancesPerSeries.append(series.instances.count)
        }
        
        return Statistics(
            studyUID: study.studyInstanceUID,
            seriesCount: study.series.count,
            totalInstances: totalInstances,
            totalSizeBytes: totalSize,
            averageSizePerInstance: avgSizePerInstance,
            modalityCounts: modalityCounts,
            instancesPerSeries: detailed ? instancesPerSeries : []
        )
    }
    
    private func outputStatsText(stats: Statistics, detailed: Bool) {
        print("═══════════════════════════════════════════════════════════════")
        print("Study Statistics")
        print("═══════════════════════════════════════════════════════════════")
        print("Study UID: \(stats.studyUID)")
        print("Series Count: \(stats.seriesCount)")
        print("Total Instances: \(stats.totalInstances)")
        print("Total Size: \(formatBytes(stats.totalSizeBytes))")
        print("Avg Size/Instance: \(formatBytes(stats.averageSizePerInstance))")
        
        print("\nModalities:")
        for (modality, count) in stats.modalityCounts.sorted(by: { $0.key < $1.key }) {
            print("  \(modality): \(count) series")
        }
        
        if detailed && !stats.instancesPerSeries.isEmpty {
            print("\nInstances per Series:")
            for (index, count) in stats.instancesPerSeries.enumerated() {
                print("  Series \(index + 1): \(count) instances")
            }
            
            let min = stats.instancesPerSeries.min() ?? 0
            let max = stats.instancesPerSeries.max() ?? 0
            let avg = stats.instancesPerSeries.isEmpty ? 0 : Double(stats.instancesPerSeries.reduce(0, +)) / Double(stats.instancesPerSeries.count)
            
            print("\nInstance Count Statistics:")
            print("  Min: \(min)")
            print("  Max: \(max)")
            print("  Average: \(String(format: "%.1f", avg))")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}

struct Statistics: Codable {
    let studyUID: String
    let seriesCount: Int
    let totalInstances: Int
    let totalSizeBytes: Int64
    let averageSizePerInstance: Int64
    let modalityCounts: [String: Int]
    let instancesPerSeries: [Int]
}

// MARK: - Study Comparator

struct StudyComparator {
    func compare(study1Path: String, study2Path: String, format: String, verbose: Bool) throws {
        guard FileManager.default.fileExists(atPath: study1Path) else {
            throw StudyError.directoryNotFound(study1Path)
        }
        guard FileManager.default.fileExists(atPath: study2Path) else {
            throw StudyError.directoryNotFound(study2Path)
        }
        
        let analyzer = StudyAnalyzer()
        let studies1 = try analyzer.scanStudies(at: study1Path, verbose: false)
        let studies2 = try analyzer.scanStudies(at: study2Path, verbose: false)
        
        guard let study1 = studies1.first else {
            throw StudyError.noFilesFound
        }
        guard let study2 = studies2.first else {
            throw StudyError.noFilesFound
        }
        
        let comparison = compareStudies(study1: study1, study2: study2, verbose: verbose)
        
        if format == "json" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(comparison)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            outputComparisonText(comparison: comparison, verbose: verbose)
        }
    }
    
    private func compareStudies(study1: StudyMetadata, study2: StudyMetadata, verbose: Bool) -> StudyComparison {
        let seriesSet1 = Set(study1.series.map { $0.seriesInstanceUID })
        let seriesSet2 = Set(study2.series.map { $0.seriesInstanceUID })
        
        let commonSeries = seriesSet1.intersection(seriesSet2)
        let onlyInStudy1 = seriesSet1.subtracting(seriesSet2)
        let onlyInStudy2 = seriesSet2.subtracting(seriesSet1)
        
        var seriesDifferences: [SeriesDifference] = []
        
        for seriesUID in commonSeries {
            if let series1 = study1.series.first(where: { $0.seriesInstanceUID == seriesUID }),
               let series2 = study2.series.first(where: { $0.seriesInstanceUID == seriesUID }) {
                
                let diff = SeriesDifference(
                    seriesUID: seriesUID,
                    instanceCountStudy1: series1.instances.count,
                    instanceCountStudy2: series2.instances.count
                )
                
                if diff.instanceCountStudy1 != diff.instanceCountStudy2 {
                    seriesDifferences.append(diff)
                }
            }
        }
        
        return StudyComparison(
            study1UID: study1.studyInstanceUID,
            study2UID: study2.studyInstanceUID,
            study1SeriesCount: study1.series.count,
            study2SeriesCount: study2.series.count,
            study1InstanceCount: study1.totalInstances,
            study2InstanceCount: study2.totalInstances,
            commonSeriesCount: commonSeries.count,
            onlyInStudy1Count: onlyInStudy1.count,
            onlyInStudy2Count: onlyInStudy2.count,
            seriesDifferences: seriesDifferences
        )
    }
    
    private func outputComparisonText(comparison: StudyComparison, verbose: Bool) {
        print("═══════════════════════════════════════════════════════════════")
        print("Study Comparison")
        print("═══════════════════════════════════════════════════════════════")
        print("Study 1 UID: \(comparison.study1UID)")
        print("Study 2 UID: \(comparison.study2UID)")
        print("")
        print("Series Counts:")
        print("  Study 1: \(comparison.study1SeriesCount)")
        print("  Study 2: \(comparison.study2SeriesCount)")
        print("  Common: \(comparison.commonSeriesCount)")
        print("  Only in Study 1: \(comparison.onlyInStudy1Count)")
        print("  Only in Study 2: \(comparison.onlyInStudy2Count)")
        print("")
        print("Instance Counts:")
        print("  Study 1: \(comparison.study1InstanceCount)")
        print("  Study 2: \(comparison.study2InstanceCount)")
        
        if !comparison.seriesDifferences.isEmpty {
            print("\nSeries with Different Instance Counts:")
            for diff in comparison.seriesDifferences {
                print("  \(diff.seriesUID):")
                print("    Study 1: \(diff.instanceCountStudy1)")
                print("    Study 2: \(diff.instanceCountStudy2)")
                print("    Difference: \(abs(diff.instanceCountStudy1 - diff.instanceCountStudy2))")
            }
        }
        
        if comparison.study1SeriesCount == comparison.study2SeriesCount &&
           comparison.study1InstanceCount == comparison.study2InstanceCount &&
           comparison.seriesDifferences.isEmpty {
            print("\n✓ Studies are structurally identical")
        } else {
            print("\n✗ Studies have differences")
        }
    }
}

struct StudyComparison: Codable {
    let study1UID: String
    let study2UID: String
    let study1SeriesCount: Int
    let study2SeriesCount: Int
    let study1InstanceCount: Int
    let study2InstanceCount: Int
    let commonSeriesCount: Int
    let onlyInStudy1Count: Int
    let onlyInStudy2Count: Int
    let seriesDifferences: [SeriesDifference]
}

struct SeriesDifference: Codable {
    let seriesUID: String
    let instanceCountStudy1: Int
    let instanceCountStudy2: Int
}

// MARK: - Helper Functions

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
