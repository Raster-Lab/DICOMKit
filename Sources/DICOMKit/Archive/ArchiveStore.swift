import Foundation
import DICOMCore
import DICOMDictionary

// Shared local-archive engine for the `dicom-archive` CLI and DICOMStudio. The
// index model, helpers, and every operation (init/import/query/list/export/
// check/stats) live here and RETURN their rendered output as a string (never
// printing) so the two adapters run identical code and cannot drift.

// MARK: - Errors

public enum ArchiveError: Error, LocalizedError {
    case archiveNotFound(String)
    case archiveExists(String)
    case noFilesToImport
    case invalidFormat(String)
    case cannotEnumerate(String)
    case noExportFilter

    public var errorDescription: String? {
        switch self {
        case .archiveNotFound(let path): return "No archive found at: \(path) (missing archive_index.json)"
        case .archiveExists(let path): return "Archive already exists at: \(path). Use --force to overwrite."
        case .noFilesToImport: return "No files found to import"
        case .invalidFormat(let msg): return msg
        case .cannotEnumerate(let dir): return "Cannot enumerate directory: \(dir)"
        case .noExportFilter: return "Specify at least one filter: --study-uid, --series-uid, or --patient-id"
        }
    }
}

// MARK: - Archive Index Types

public struct ArchiveInstance: Codable, Sendable {
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let filePath: String
    public let fileSize: Int64
    public let importDate: String
    public let instanceNumber: String?
}

public struct ArchiveSeries: Codable, Sendable {
    public let seriesInstanceUID: String
    public let modality: String
    public let seriesDescription: String?
    public let seriesNumber: String?
    public var instances: [ArchiveInstance]
}

public struct ArchiveStudy: Codable, Sendable {
    public let studyInstanceUID: String
    public let studyDate: String?
    public let studyDescription: String?
    public let modality: String?
    public let accessionNumber: String?
    public var series: [ArchiveSeries]
}

public struct ArchivePatient: Codable, Sendable {
    public let patientName: String
    public let patientID: String
    public var studies: [ArchiveStudy]
}

public struct ArchiveIndex: Codable, Sendable {
    public let version: String
    public let creationDate: String
    public var lastModified: String
    public var fileCount: Int
    public var patients: [ArchivePatient]
}

// MARK: - Archive Store

public enum ArchiveStore {

    public static let archiveVersion = "1.2.1"

    // MARK: Wildcard Matching

    static func wildcardMatch(_ pattern: String, _ text: String) -> Bool {
        let p = Array(pattern.uppercased())
        let t = Array(text.uppercased())
        return wildcardMatchHelper(p, 0, t, 0)
    }

    private static func wildcardMatchHelper(_ pattern: [Character], _ pi: Int, _ text: [Character], _ ti: Int) -> Bool {
        var pi = pi
        var ti = ti
        while pi < pattern.count {
            let pc = pattern[pi]
            if pc == "*" {
                pi += 1
                while pi < pattern.count && pattern[pi] == "*" { pi += 1 }
                if pi == pattern.count { return true }
                while ti <= text.count {
                    if wildcardMatchHelper(pattern, pi, text, ti) { return true }
                    ti += 1
                }
                return false
            } else if pc == "?" {
                guard ti < text.count else { return false }
                pi += 1; ti += 1
            } else {
                guard ti < text.count, pc == text[ti] else { return false }
                pi += 1; ti += 1
            }
        }
        return ti == text.count
    }

    // MARK: Helpers

    static func isoDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    public static func indexURL(for archivePath: String) -> URL {
        URL(fileURLWithPath: archivePath).appendingPathComponent("archive_index.json")
    }

    public static func dataDirectory(for archivePath: String) -> URL {
        URL(fileURLWithPath: archivePath).appendingPathComponent("data")
    }

    public static func loadIndex(from archivePath: String) throws -> ArchiveIndex {
        let url = indexURL(for: archivePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ArchiveError.archiveNotFound(archivePath)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ArchiveIndex.self, from: data)
    }

    static func saveIndex(_ index: ArchiveIndex, to archivePath: String) throws {
        let url = indexURL(for: archivePath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: url)
    }

    static func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var result = ""
        for char in value.unicodeScalars {
            if allowed.contains(char) {
                result.append(Character(char))
            } else {
                result.append("_")
            }
        }
        if result.isEmpty { result = "UNKNOWN" }
        return result
    }

    static func countTotalInstances(_ index: ArchiveIndex) -> Int {
        var count = 0
        for patient in index.patients {
            for study in patient.studies {
                for series in study.series {
                    count += series.instances.count
                }
            }
        }
        return count
    }

    private static func truncate(_ str: String, to length: Int) -> String {
        if str.count <= length { return str }
        return String(str.prefix(length - 1)) + "…"
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        let maxUnitIndex = units.count - 1
        while value >= 1024 && unitIndex < maxUnitIndex {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 { return "\(bytes) B" }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    // MARK: - init

    public static func initArchive(at archivePath: String, force: Bool) throws -> String {
        let fm = FileManager.default
        let idxURL = indexURL(for: archivePath)
        if fm.fileExists(atPath: idxURL.path) && !force {
            throw ArchiveError.archiveExists(archivePath)
        }
        let dataDir = dataDirectory(for: archivePath)
        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
        let index = ArchiveIndex(
            version: archiveVersion,
            creationDate: isoDateString(),
            lastModified: isoDateString(),
            fileCount: 0,
            patients: []
        )
        try saveIndex(index, to: archivePath)
        var out = ""
        out += "✅ Archive initialized at: \(archivePath)\n"
        out += "\n"
        out += "Structure:\n"
        out += "  \(archivePath)/\n"
        out += "  ├── archive_index.json\n"
        out += "  └── data/\n"
        return out
    }

    // MARK: - import

    public static func importFiles(
        into archive: String,
        files: [String],
        recursive: Bool,
        skipDuplicates: Bool,
        verbose: Bool
    ) throws -> String {
        var index = try loadIndex(from: archive)
        let fm = FileManager.default
        let dataDir = dataDirectory(for: archive)
        var out = ""

        // Collect all file paths
        var filePaths: [String] = []
        for input in files {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: input, isDirectory: &isDir) else {
                out += "⚠️  File not found: \(input)\n"
                continue
            }
            if isDir.boolValue {
                let dirFiles = try collectDICOMFiles(in: input, recursive: recursive)
                filePaths.append(contentsOf: dirFiles)
            } else {
                filePaths.append(input)
            }
        }

        if filePaths.isEmpty {
            throw ArchiveError.noFilesToImport
        }

        var existingSOPs = Set<String>()
        for patient in index.patients {
            for study in patient.studies {
                for series in study.series {
                    for instance in series.instances {
                        existingSOPs.insert(instance.sopInstanceUID)
                    }
                }
            }
        }

        var imported = 0
        var skipped = 0
        var failed = 0

        for (i, filePath) in filePaths.enumerated() {
            if verbose {
                out += "[\(i + 1)/\(filePaths.count)] Processing \(URL(fileURLWithPath: filePath).lastPathComponent)...\n"
            }
            do {
                let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
                let dicomFile = try DICOMFile.read(from: fileData, force: true)
                let ds = dicomFile.dataSet

                guard let sopInstanceUID = ds.string(for: .sopInstanceUID) else {
                    if verbose { out += "  ⚠️  Missing SOP Instance UID, skipping\n" }
                    failed += 1
                    continue
                }

                if existingSOPs.contains(sopInstanceUID) {
                    if verbose { out += "  ⏭️  Duplicate SOP Instance UID, skipping\n" }
                    skipped += 1
                    continue
                }

                let patientName = ds.string(for: .patientName) ?? "UNKNOWN"
                let patientID = ds.string(for: .patientID) ?? "UNKNOWN"
                let studyInstanceUID = ds.string(for: .studyInstanceUID) ?? "UNKNOWN_STUDY"
                let seriesInstanceUID = ds.string(for: .seriesInstanceUID) ?? "UNKNOWN_SERIES"
                let sopClassUID = ds.string(for: .sopClassUID) ?? ""
                let modality = ds.string(for: .modality) ?? ""
                let studyDate = ds.string(for: .studyDate)
                let studyDescription = ds.string(for: .studyDescription)
                let seriesDescription = ds.string(for: .seriesDescription)
                let seriesNumber = ds.string(for: .seriesNumber)
                let instanceNumber = ds.string(for: .instanceNumber)
                let accessionNumber = ds.string(for: .accessionNumber)

                let safePID = sanitizePathComponent(patientID)
                let safeStudy = sanitizePathComponent(studyInstanceUID)
                let safeSeries = sanitizePathComponent(seriesInstanceUID)
                let fileName = sanitizePathComponent(sopInstanceUID) + ".dcm"
                let relativePath = "\(safePID)/\(safeStudy)/\(safeSeries)/\(fileName)"

                let destDir = dataDir
                    .appendingPathComponent(safePID)
                    .appendingPathComponent(safeStudy)
                    .appendingPathComponent(safeSeries)
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

                let destFile = destDir.appendingPathComponent(fileName)
                try fileData.write(to: destFile)

                let instance = ArchiveInstance(
                    sopInstanceUID: sopInstanceUID,
                    sopClassUID: sopClassUID,
                    filePath: relativePath,
                    fileSize: Int64(fileData.count),
                    importDate: isoDateString(),
                    instanceNumber: instanceNumber
                )

                addInstanceToIndex(
                    &index,
                    instance: instance,
                    patientName: patientName,
                    patientID: patientID,
                    studyInstanceUID: studyInstanceUID,
                    studyDate: studyDate,
                    studyDescription: studyDescription,
                    modality: modality,
                    accessionNumber: accessionNumber,
                    seriesInstanceUID: seriesInstanceUID,
                    seriesDescription: seriesDescription,
                    seriesNumber: seriesNumber
                )

                existingSOPs.insert(sopInstanceUID)
                imported += 1
            } catch {
                failed += 1
                if verbose {
                    out += "  ❌ Failed: \(error.localizedDescription)\n"
                }
            }
        }

        index.fileCount = countTotalInstances(index)
        index.lastModified = isoDateString()
        try saveIndex(index, to: archive)

        out += "\n"
        out += "✅ Import complete\n"
        out += "  Imported: \(imported)\n"
        if skipped > 0 { out += "  Skipped (duplicates): \(skipped)\n" }
        if failed > 0 { out += "  Failed: \(failed)\n" }
        out += "  Total files in archive: \(index.fileCount)\n"
        return out
    }

    private static func collectDICOMFiles(in directory: String, recursive: Bool) throws -> [String] {
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: directory)
        var results: [String] = []
        if recursive {
            guard let enumerator = fm.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw ArchiveError.cannotEnumerate(directory)
            }
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values.isRegularFile == true { results.append(fileURL.path) }
            }
        } else {
            let contents = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for fileURL in contents {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values.isRegularFile == true { results.append(fileURL.path) }
            }
        }
        return results.sorted()
    }

    private static func addInstanceToIndex(
        _ index: inout ArchiveIndex,
        instance: ArchiveInstance,
        patientName: String,
        patientID: String,
        studyInstanceUID: String,
        studyDate: String?,
        studyDescription: String?,
        modality: String,
        accessionNumber: String?,
        seriesInstanceUID: String,
        seriesDescription: String?,
        seriesNumber: String?
    ) {
        func makeSeries() -> ArchiveSeries {
            ArchiveSeries(
                seriesInstanceUID: seriesInstanceUID,
                modality: modality,
                seriesDescription: seriesDescription,
                seriesNumber: seriesNumber,
                instances: [instance])
        }
        func makeStudy() -> ArchiveStudy {
            ArchiveStudy(
                studyInstanceUID: studyInstanceUID,
                studyDate: studyDate,
                studyDescription: studyDescription,
                modality: modality,
                accessionNumber: accessionNumber,
                series: [makeSeries()])
        }
        if let pi = index.patients.firstIndex(where: { $0.patientID == patientID }) {
            if let si = index.patients[pi].studies.firstIndex(where: { $0.studyInstanceUID == studyInstanceUID }) {
                if let sei = index.patients[pi].studies[si].series.firstIndex(where: { $0.seriesInstanceUID == seriesInstanceUID }) {
                    index.patients[pi].studies[si].series[sei].instances.append(instance)
                } else {
                    index.patients[pi].studies[si].series.append(makeSeries())
                }
            } else {
                index.patients[pi].studies.append(makeStudy())
            }
        } else {
            index.patients.append(ArchivePatient(patientName: patientName, patientID: patientID, studies: [makeStudy()]))
        }
    }

    // MARK: - query

    public static func query(
        in archive: String,
        patientName: String?,
        patientID: String?,
        studyUID: String?,
        modality: String?,
        studyDate: String?,
        format: String
    ) throws -> String {
        let index = try loadIndex(from: archive)
        guard ["table", "json", "text"].contains(format.lowercased()) else {
            throw ArchiveError.invalidFormat("Invalid format: \(format). Use table, json, or text")
        }

        var results: [(patient: ArchivePatient, study: ArchiveStudy)] = []
        for patient in index.patients {
            if let pn = patientName, !wildcardMatch(pn, patient.patientName) { continue }
            if let pid = patientID, !wildcardMatch(pid, patient.patientID) { continue }
            for study in patient.studies {
                if let uid = studyUID, study.studyInstanceUID != uid { continue }
                if let mod = modality {
                    let studyModalities = Set(study.series.map { $0.modality })
                    if !studyModalities.contains(mod.uppercased()) { continue }
                }
                if let sd = studyDate, study.studyDate != sd { continue }
                results.append((patient: patient, study: study))
            }
        }

        if results.isEmpty {
            return "No matching results found.\n"
        }

        switch format.lowercased() {
        case "json": return queryJSON(results)
        case "text": return queryText(results)
        default: return queryTable(results)
        }
    }

    private static func queryTable(_ results: [(patient: ArchivePatient, study: ArchiveStudy)]) -> String {
        var out = ""
        let cols = ["Patient Name", "Patient ID", "Study Date", "Modality", "Description", "Series", "Images"]
        let widths = [20, 15, 12, 10, 25, 6, 6]
        let header = zip(cols, widths).map { $0.0.padding(toLength: $0.1, withPad: " ", startingAt: 0) }.joined(separator: " | ")
        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-")
        out += header + "\n"
        out += separator + "\n"
        for result in results {
            let imageCount = result.study.series.reduce(0) { $0 + $1.instances.count }
            let row = [
                truncate(result.patient.patientName, to: 20),
                truncate(result.patient.patientID, to: 15),
                truncate(result.study.studyDate ?? "", to: 12),
                truncate(result.study.modality ?? "", to: 10),
                truncate(result.study.studyDescription ?? "", to: 25),
                truncate(String(result.study.series.count), to: 6),
                truncate(String(imageCount), to: 6)
            ]
            let line = zip(row, widths).map { $0.0.padding(toLength: $0.1, withPad: " ", startingAt: 0) }.joined(separator: " | ")
            out += line + "\n"
        }
        out += "\n"
        out += "Found \(results.count) matching study(ies)\n"
        return out
    }

    private static func queryJSON(_ results: [(patient: ArchivePatient, study: ArchiveStudy)]) -> String {
        struct QueryResult: Codable {
            let patientName: String
            let patientID: String
            let studyInstanceUID: String
            let studyDate: String?
            let studyDescription: String?
            let modality: String?
            let seriesCount: Int
            let imageCount: Int
        }
        let items = results.map { r in
            QueryResult(
                patientName: r.patient.patientName,
                patientID: r.patient.patientID,
                studyInstanceUID: r.study.studyInstanceUID,
                studyDate: r.study.studyDate,
                studyDescription: r.study.studyDescription,
                modality: r.study.modality,
                seriesCount: r.study.series.count,
                imageCount: r.study.series.reduce(0) { $0 + $1.instances.count })
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(items), let json = String(data: data, encoding: .utf8) {
            return json + "\n"
        }
        return ""
    }

    private static func queryText(_ results: [(patient: ArchivePatient, study: ArchiveStudy)]) -> String {
        var out = ""
        for (i, result) in results.enumerated() {
            if i > 0 { out += "\n" }
            let imageCount = result.study.series.reduce(0) { $0 + $1.instances.count }
            out += "Patient: \(result.patient.patientName) (ID: \(result.patient.patientID))\n"
            out += "  Study: \(result.study.studyInstanceUID)\n"
            if let date = result.study.studyDate { out += "  Date: \(date)\n" }
            if let desc = result.study.studyDescription { out += "  Description: \(desc)\n" }
            if let mod = result.study.modality { out += "  Modality: \(mod)\n" }
            out += "  Series: \(result.study.series.count)\n"
            out += "  Images: \(imageCount)\n"
        }
        out += "\n"
        out += "Found \(results.count) matching study(ies)\n"
        return out
    }

    // MARK: - list

    public static func list(in archive: String, format: String, showInstances: Bool) throws -> String {
        let index = try loadIndex(from: archive)
        guard ["tree", "table", "json"].contains(format.lowercased()) else {
            throw ArchiveError.invalidFormat("Invalid format: \(format). Use tree, table, or json")
        }
        if index.patients.isEmpty {
            return "Archive is empty.\n"
        }
        switch format.lowercased() {
        case "json": return listJSON(index)
        case "table": return listTable(index)
        default: return listTree(index, archive: archive, showInstances: showInstances)
        }
    }

    private static func listTree(_ index: ArchiveIndex, archive: String, showInstances: Bool) -> String {
        var out = ""
        out += "Archive: \(archive)\n"
        out += "Files: \(index.fileCount)\n"
        out += "\n"
        for (pi, patient) in index.patients.enumerated() {
            let isLastPatient = pi == index.patients.count - 1
            let pPrefix = isLastPatient ? "└── " : "├── "
            let pCont = isLastPatient ? "    " : "│   "
            out += "\(pPrefix)Patient: \(patient.patientName) (ID: \(patient.patientID))\n"
            for (si, study) in patient.studies.enumerated() {
                let isLastStudy = si == patient.studies.count - 1
                let sPrefix = pCont + (isLastStudy ? "└── " : "├── ")
                let sCont = pCont + (isLastStudy ? "    " : "│   ")
                let desc = study.studyDescription ?? study.studyInstanceUID
                let date = study.studyDate.map { " [\($0)]" } ?? ""
                out += "\(sPrefix)Study: \(desc)\(date)\n"
                for (sei, series) in study.series.enumerated() {
                    let isLastSeries = sei == study.series.count - 1
                    let sePrefix = sCont + (isLastSeries ? "└── " : "├── ")
                    let seCont = sCont + (isLastSeries ? "    " : "│   ")
                    let seDesc = series.seriesDescription ?? series.seriesInstanceUID
                    out += "\(sePrefix)Series: \(series.modality) - \(seDesc) (\(series.instances.count) instances)\n"
                    if showInstances {
                        for (ii, instance) in series.instances.enumerated() {
                            let isLastInstance = ii == series.instances.count - 1
                            let iPrefix = seCont + (isLastInstance ? "└── " : "├── ")
                            out += "\(iPrefix)\(instance.sopInstanceUID)\n"
                        }
                    }
                }
            }
        }
        return out
    }

    private static func listTable(_ index: ArchiveIndex) -> String {
        var out = ""
        let cols = ["Patient Name", "Patient ID", "Studies", "Series", "Images"]
        let widths = [25, 15, 8, 8, 8]
        let header = zip(cols, widths).map { $0.0.padding(toLength: $0.1, withPad: " ", startingAt: 0) }.joined(separator: " | ")
        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-")
        out += header + "\n"
        out += separator + "\n"
        for patient in index.patients {
            let seriesCount = patient.studies.reduce(0) { $0 + $1.series.count }
            let imageCount = patient.studies.reduce(0) { total, study in
                total + study.series.reduce(0) { $0 + $1.instances.count }
            }
            let name = patient.patientName.count > 25 ? String(patient.patientName.prefix(24)) + "…" : patient.patientName
            let pid = patient.patientID.count > 15 ? String(patient.patientID.prefix(14)) + "…" : patient.patientID
            let row = [
                name.padding(toLength: 25, withPad: " ", startingAt: 0),
                pid.padding(toLength: 15, withPad: " ", startingAt: 0),
                String(patient.studies.count).padding(toLength: 8, withPad: " ", startingAt: 0),
                String(seriesCount).padding(toLength: 8, withPad: " ", startingAt: 0),
                String(imageCount).padding(toLength: 8, withPad: " ", startingAt: 0)
            ]
            out += row.joined(separator: " | ") + "\n"
        }
        out += "\n"
        out += "Total: \(index.patients.count) patient(s), \(index.fileCount) file(s)\n"
        return out
    }

    private static func listJSON(_ index: ArchiveIndex) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(index), let json = String(data: data, encoding: .utf8) {
            return json + "\n"
        }
        return ""
    }

    // MARK: - export

    public static func export(
        from archive: String,
        output: String,
        studyUID: String?,
        seriesUID: String?,
        patientID: String?,
        flatten: Bool,
        verbose: Bool
    ) throws -> String {
        let index = try loadIndex(from: archive)
        let fm = FileManager.default
        let dataDir = dataDirectory(for: archive)
        let outputURL = URL(fileURLWithPath: output)
        var out = ""

        if studyUID == nil && seriesUID == nil && patientID == nil {
            throw ArchiveError.noExportFilter
        }

        try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

        var exported = 0
        var failed = 0

        for patient in index.patients {
            if let pid = patientID, patient.patientID != pid { continue }
            for study in patient.studies {
                if let uid = studyUID, study.studyInstanceUID != uid { continue }
                for series in study.series {
                    if let uid = seriesUID, series.seriesInstanceUID != uid { continue }
                    for instance in series.instances {
                        let sourceFile = dataDir.appendingPathComponent(instance.filePath)
                        let destFile: URL
                        if flatten {
                            let fileName = sanitizePathComponent(instance.sopInstanceUID) + ".dcm"
                            destFile = outputURL.appendingPathComponent(fileName)
                        } else {
                            let destDir = outputURL
                                .appendingPathComponent(sanitizePathComponent(patient.patientID))
                                .appendingPathComponent(sanitizePathComponent(study.studyInstanceUID))
                                .appendingPathComponent(sanitizePathComponent(series.seriesInstanceUID))
                            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                            let fileName = sanitizePathComponent(instance.sopInstanceUID) + ".dcm"
                            destFile = destDir.appendingPathComponent(fileName)
                        }
                        do {
                            try fm.copyItem(at: sourceFile, to: destFile)
                            exported += 1
                            if verbose { out += "  Exported: \(instance.sopInstanceUID)\n" }
                        } catch {
                            failed += 1
                            if verbose { out += "  ❌ Failed to export \(instance.sopInstanceUID): \(error.localizedDescription)\n" }
                        }
                    }
                }
            }
        }

        out += "\n"
        out += "✅ Export complete\n"
        out += "  Exported: \(exported) file(s)\n"
        if failed > 0 { out += "  Failed: \(failed)\n" }
        out += "  Output: \(output)\n"
        return out
    }

    // MARK: - check

    public static func check(in archive: String, verifyFiles: Bool, verbose: Bool) throws -> String {
        let index = try loadIndex(from: archive)
        let fm = FileManager.default
        let dataDir = dataDirectory(for: archive)
        var out = ""

        var missingFiles = 0
        var sizeMismatches = 0
        var unreadableFiles = 0
        var orphanedFiles: [String] = []
        var totalChecked = 0

        for patient in index.patients {
            for study in patient.studies {
                for series in study.series {
                    for instance in series.instances {
                        totalChecked += 1
                        let filePath = dataDir.appendingPathComponent(instance.filePath).path
                        if !fm.fileExists(atPath: filePath) {
                            missingFiles += 1
                            if verbose { out += "❌ Missing: \(instance.filePath)\n" }
                            continue
                        }
                        do {
                            let attrs = try fm.attributesOfItem(atPath: filePath)
                            if let fileSize = attrs[.size] as? Int64, fileSize != instance.fileSize {
                                sizeMismatches += 1
                                if verbose { out += "⚠️  Size mismatch: \(instance.filePath) (expected \(instance.fileSize), got \(fileSize))\n" }
                            }
                        } catch {
                            if verbose { out += "⚠️  Cannot read attributes: \(instance.filePath)\n" }
                        }
                        if verifyFiles {
                            do {
                                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                                _ = try DICOMFile.read(from: data, force: true)
                            } catch {
                                unreadableFiles += 1
                                if verbose { out += "❌ Unreadable DICOM: \(instance.filePath) - \(error.localizedDescription)\n" }
                            }
                        }
                    }
                }
            }
        }

        let indexedPaths = Set(
            index.patients.flatMap { p in
                p.studies.flatMap { st in
                    st.series.flatMap { se in
                        se.instances.map { $0.filePath }
                    }
                }
            }
        )

        if let enumerator = fm.enumerator(
            at: dataDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values?.isRegularFile == true {
                    let relativePath = fileURL.path.replacingOccurrences(of: dataDir.path + "/", with: "")
                    if !indexedPaths.contains(relativePath) {
                        orphanedFiles.append(relativePath)
                        if verbose { out += "🔍 Orphaned file: \(relativePath)\n" }
                    }
                }
            }
        }

        out += "\n"
        out += "Archive Integrity Report\n"
        out += "========================\n"
        out += "  Files checked: \(totalChecked)\n"
        out += "  Index file count: \(index.fileCount)\n"
        out += "\n"

        var hasIssues = false
        if missingFiles > 0 { out += "  ❌ Missing files: \(missingFiles)\n"; hasIssues = true }
        if sizeMismatches > 0 { out += "  ⚠️  Size mismatches: \(sizeMismatches)\n"; hasIssues = true }
        if unreadableFiles > 0 { out += "  ❌ Unreadable DICOM files: \(unreadableFiles)\n"; hasIssues = true }
        if !orphanedFiles.isEmpty { out += "  🔍 Orphaned files: \(orphanedFiles.count)\n"; hasIssues = true }

        if hasIssues {
            out += "\n"
            out += "⚠️  Archive has integrity issues\n"
        } else {
            out += "  ✅ All files present and accounted for\n"
            if verifyFiles { out += "  ✅ All DICOM files readable\n" }
            out += "\n"
            out += "✅ Archive integrity OK\n"
        }
        return out
    }

    // MARK: - stats

    public static func stats(in archive: String, format: String) throws -> String {
        let index = try loadIndex(from: archive)
        guard ["text", "json"].contains(format.lowercased()) else {
            throw ArchiveError.invalidFormat("Invalid format: \(format). Use text or json")
        }

        var totalSeries = 0
        var totalInstances = 0
        var totalSize: Int64 = 0
        var modalities = [String: Int]()
        var sopClasses = [String: Int]()

        for patient in index.patients {
            for study in patient.studies {
                for series in study.series {
                    totalSeries += 1
                    totalInstances += series.instances.count
                    modalities[series.modality, default: 0] += series.instances.count
                    for instance in series.instances {
                        totalSize += instance.fileSize
                        if !instance.sopClassUID.isEmpty {
                            sopClasses[instance.sopClassUID, default: 0] += 1
                        }
                    }
                }
            }
        }

        let totalStudies = index.patients.reduce(0) { $0 + $1.studies.count }

        switch format.lowercased() {
        case "json":
            return statsJSON(index: index, totalStudies: totalStudies, totalSeries: totalSeries,
                             totalInstances: totalInstances, totalSize: totalSize, modalities: modalities)
        default:
            return statsText(index: index, totalStudies: totalStudies, totalSeries: totalSeries,
                             totalInstances: totalInstances, totalSize: totalSize,
                             modalities: modalities, sopClasses: sopClasses)
        }
    }

    private static func statsText(
        index: ArchiveIndex, totalStudies: Int, totalSeries: Int, totalInstances: Int,
        totalSize: Int64, modalities: [String: Int], sopClasses: [String: Int]
    ) -> String {
        var out = ""
        out += "Archive Statistics\n"
        out += "==================\n"
        out += "\n"
        out += "Archive Info:\n"
        out += "  Version: \(index.version)\n"
        out += "  Created: \(index.creationDate)\n"
        out += "  Last modified: \(index.lastModified)\n"
        out += "\n"
        out += "Contents:\n"
        out += "  Patients: \(index.patients.count)\n"
        out += "  Studies: \(totalStudies)\n"
        out += "  Series: \(totalSeries)\n"
        out += "  Instances: \(totalInstances)\n"
        out += "  Total size: \(formatBytes(totalSize))\n"
        out += "\n"
        if !modalities.isEmpty {
            out += "Modalities:\n"
            for (mod, count) in modalities.sorted(by: { $0.key < $1.key }) {
                let label = mod.isEmpty ? "(unknown)" : mod
                out += "  \(label): \(count) instance(s)\n"
            }
            out += "\n"
        }
        if !sopClasses.isEmpty {
            out += "SOP Classes:\n"
            for (sop, count) in sopClasses.sorted(by: { $0.value > $1.value }).prefix(10) {
                out += "  \(sop): \(count)\n"
            }
            if sopClasses.count > 10 {
                out += "  ... and \(sopClasses.count - 10) more\n"
            }
        }
        return out
    }

    private static func statsJSON(
        index: ArchiveIndex, totalStudies: Int, totalSeries: Int, totalInstances: Int,
        totalSize: Int64, modalities: [String: Int]
    ) -> String {
        struct StatsOutput: Codable {
            let version: String
            let creationDate: String
            let lastModified: String
            let patients: Int
            let studies: Int
            let series: Int
            let instances: Int
            let totalSizeBytes: Int64
            let modalities: [String: Int]
        }
        let output = StatsOutput(
            version: index.version, creationDate: index.creationDate, lastModified: index.lastModified,
            patients: index.patients.count, studies: totalStudies, series: totalSeries,
            instances: totalInstances, totalSizeBytes: totalSize, modalities: modalities)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output), let json = String(data: data, encoding: .utf8) {
            return json + "\n"
        }
        return ""
    }
}
