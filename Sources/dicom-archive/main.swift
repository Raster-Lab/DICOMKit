import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

// MARK: - Archive Index Types

struct ArchiveInstance: Codable, Sendable {
    let sopInstanceUID: String
    let sopClassUID: String
    let filePath: String
    let fileSize: Int64
    let importDate: String
    let instanceNumber: String?
}

struct ArchiveSeries: Codable, Sendable {
    let seriesInstanceUID: String
    let modality: String
    let seriesDescription: String?
    let seriesNumber: String?
    var instances: [ArchiveInstance]
}

struct ArchiveStudy: Codable, Sendable {
    let studyInstanceUID: String
    let studyDate: String?
    let studyDescription: String?
    let modality: String?
    let accessionNumber: String?
    var series: [ArchiveSeries]
}

struct ArchivePatient: Codable, Sendable {
    let patientName: String
    let patientID: String
    var studies: [ArchiveStudy]
}

struct ArchiveIndex: Codable, Sendable {
    let version: String
    let creationDate: String
    var lastModified: String
    var fileCount: Int
    var patients: [ArchivePatient]
}

// MARK: - Wildcard Matching

private func wildcardMatch(_ pattern: String, _ text: String) -> Bool {
    let p = Array(pattern.uppercased())
    let t = Array(text.uppercased())
    return wildcardMatchHelper(p, 0, t, 0)
}

private func wildcardMatchHelper(_ pattern: [Character], _ pi: Int, _ text: [Character], _ ti: Int) -> Bool {
    var pi = pi
    var ti = ti

    while pi < pattern.count {
        let pc = pattern[pi]
        if pc == "*" {
            // Skip consecutive *
            pi += 1
            while pi < pattern.count && pattern[pi] == "*" {
                pi += 1
            }
            if pi == pattern.count {
                return true
            }
            while ti <= text.count {
                if wildcardMatchHelper(pattern, pi, text, ti) {
                    return true
                }
                ti += 1
            }
            return false
        } else if pc == "?" {
            guard ti < text.count else { return false }
            pi += 1
            ti += 1
        } else {
            guard ti < text.count, pc == text[ti] else { return false }
            pi += 1
            ti += 1
        }
    }
    return ti == text.count
}

// MARK: - Archive Helper Functions

private func isoDateString() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: Date())
}

private func indexURL(for archivePath: String) -> URL {
    URL(fileURLWithPath: archivePath).appendingPathComponent("archive_index.json")
}

private func dataDirectory(for archivePath: String) -> URL {
    URL(fileURLWithPath: archivePath).appendingPathComponent("data")
}

private func loadIndex(from archivePath: String) throws -> ArchiveIndex {
    let url = indexURL(for: archivePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw ValidationError("No archive found at: \(archivePath) (missing archive_index.json)")
    }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(ArchiveIndex.self, from: data)
}

private func saveIndex(_ index: ArchiveIndex, to archivePath: String) throws {
    let url = indexURL(for: archivePath)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(index)
    try data.write(to: url)
}

private func sanitizePathComponent(_ value: String) -> String {
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

private func countTotalInstances(_ index: ArchiveIndex) -> Int {
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
            let archivePath = path
            let fm = FileManager.default
            let idxURL = indexURL(for: archivePath)

            if fm.fileExists(atPath: idxURL.path) && !force {
                throw ValidationError("Archive already exists at: \(archivePath). Use --force to overwrite.")
            }

            // Create directories
            let dataDir = dataDirectory(for: archivePath)
            try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

            // Create index
            let index = ArchiveIndex(
                version: "1.2.1",
                creationDate: isoDateString(),
                lastModified: isoDateString(),
                fileCount: 0,
                patients: []
            )
            try saveIndex(index, to: archivePath)

            print("✅ Archive initialized at: \(archivePath)")
            print("")
            print("Structure:")
            print("  \(archivePath)/")
            print("  ├── archive_index.json")
            print("  └── data/")
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
            var index = try loadIndex(from: archive)
            let fm = FileManager.default
            let dataDir = dataDirectory(for: archive)

            // Collect all file paths
            var filePaths: [String] = []
            for input in files {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: input, isDirectory: &isDir) else {
                    print("⚠️  File not found: \(input)")
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
                throw ValidationError("No files found to import")
            }

            // Build existing SOP Instance UID set for deduplication
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
                    print("[\(i + 1)/\(filePaths.count)] Processing \(URL(fileURLWithPath: filePath).lastPathComponent)...")
                }

                do {
                    let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
                    let dicomFile = try DICOMFile.read(from: fileData, force: true)
                    let ds = dicomFile.dataSet

                    // Extract required metadata
                    guard let sopInstanceUID = ds.string(for: .sopInstanceUID) else {
                        if verbose { print("  ⚠️  Missing SOP Instance UID, skipping") }
                        failed += 1
                        continue
                    }

                    // Deduplication check
                    if existingSOPs.contains(sopInstanceUID) {
                        if skipDuplicates {
                            if verbose { print("  ⏭️  Duplicate SOP Instance UID, skipping") }
                            skipped += 1
                            continue
                        } else {
                            if verbose { print("  ⏭️  Duplicate SOP Instance UID, skipping") }
                            skipped += 1
                            continue
                        }
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

                    // Build file path in archive
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

                    // Update index
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
                        print("  ❌ Failed: \(error.localizedDescription)")
                    }
                }
            }

            // Update index metadata
            index.fileCount = countTotalInstances(index)
            index.lastModified = isoDateString()
            try saveIndex(index, to: archive)

            print("")
            print("✅ Import complete")
            print("  Imported: \(imported)")
            if skipped > 0 { print("  Skipped (duplicates): \(skipped)") }
            if failed > 0 { print("  Failed: \(failed)") }
            print("  Total files in archive: \(index.fileCount)")
        }

        private func collectDICOMFiles(in directory: String, recursive: Bool) throws -> [String] {
            let fm = FileManager.default
            let dirURL = URL(fileURLWithPath: directory)
            var results: [String] = []

            if recursive {
                guard let enumerator = fm.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    throw ValidationError("Cannot enumerate directory: \(directory)")
                }
                for case let fileURL as URL in enumerator {
                    let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if values.isRegularFile == true {
                        results.append(fileURL.path)
                    }
                }
            } else {
                let contents = try fm.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                for fileURL in contents {
                    let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if values.isRegularFile == true {
                        results.append(fileURL.path)
                    }
                }
            }

            return results.sorted()
        }

        private func addInstanceToIndex(
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
            // Find or create patient
            if let pi = index.patients.firstIndex(where: { $0.patientID == patientID }) {
                // Find or create study
                if let si = index.patients[pi].studies.firstIndex(where: { $0.studyInstanceUID == studyInstanceUID }) {
                    // Find or create series
                    if let sei = index.patients[pi].studies[si].series.firstIndex(where: { $0.seriesInstanceUID == seriesInstanceUID }) {
                        index.patients[pi].studies[si].series[sei].instances.append(instance)
                    } else {
                        let newSeries = ArchiveSeries(
                            seriesInstanceUID: seriesInstanceUID,
                            modality: modality,
                            seriesDescription: seriesDescription,
                            seriesNumber: seriesNumber,
                            instances: [instance]
                        )
                        index.patients[pi].studies[si].series.append(newSeries)
                    }
                } else {
                    let newSeries = ArchiveSeries(
                        seriesInstanceUID: seriesInstanceUID,
                        modality: modality,
                        seriesDescription: seriesDescription,
                        seriesNumber: seriesNumber,
                        instances: [instance]
                    )
                    let newStudy = ArchiveStudy(
                        studyInstanceUID: studyInstanceUID,
                        studyDate: studyDate,
                        studyDescription: studyDescription,
                        modality: modality,
                        accessionNumber: accessionNumber,
                        series: [newSeries]
                    )
                    index.patients[pi].studies.append(newStudy)
                }
            } else {
                let newSeries = ArchiveSeries(
                    seriesInstanceUID: seriesInstanceUID,
                    modality: modality,
                    seriesDescription: seriesDescription,
                    seriesNumber: seriesNumber,
                    instances: [instance]
                )
                let newStudy = ArchiveStudy(
                    studyInstanceUID: studyInstanceUID,
                    studyDate: studyDate,
                    studyDescription: studyDescription,
                    modality: modality,
                    accessionNumber: accessionNumber,
                    series: [newSeries]
                )
                let newPatient = ArchivePatient(
                    patientName: patientName,
                    patientID: patientID,
                    studies: [newStudy]
                )
                index.patients.append(newPatient)
            }
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
            let index = try loadIndex(from: archive)

            guard ["table", "json", "text"].contains(format.lowercased()) else {
                throw ValidationError("Invalid format: \(format). Use table, json, or text")
            }

            // Filter patients
            var results: [(patient: ArchivePatient, study: ArchiveStudy)] = []

            for patient in index.patients {
                if let pn = patientName, !wildcardMatch(pn, patient.patientName) {
                    continue
                }
                if let pid = patientID, !wildcardMatch(pid, patient.patientID) {
                    continue
                }

                for study in patient.studies {
                    if let uid = studyUID, study.studyInstanceUID != uid {
                        continue
                    }
                    if let mod = modality {
                        let studyModalities = Set(study.series.map { $0.modality })
                        if !studyModalities.contains(mod.uppercased()) {
                            continue
                        }
                    }
                    if let sd = studyDate, study.studyDate != sd {
                        continue
                    }
                    results.append((patient: patient, study: study))
                }
            }

            if results.isEmpty {
                print("No matching results found.")
                return
            }

            switch format.lowercased() {
            case "json":
                printQueryJSON(results)
            case "text":
                printQueryText(results)
            default:
                printQueryTable(results)
            }
        }

        private func printQueryTable(_ results: [(patient: ArchivePatient, study: ArchiveStudy)]) {
            // Header
            let cols = ["Patient Name", "Patient ID", "Study Date", "Modality", "Description", "Series", "Images"]
            let widths = [20, 15, 12, 10, 25, 6, 6]

            let header = zip(cols, widths).map { $0.0.padding(toLength: $0.1, withPad: " ", startingAt: 0) }.joined(separator: " | ")
            let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-")

            print(header)
            print(separator)

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
                print(line)
            }

            print("")
            print("Found \(results.count) matching study(ies)")
        }

        private func printQueryJSON(_ results: [(patient: ArchivePatient, study: ArchiveStudy)]) {
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
                    imageCount: r.study.series.reduce(0) { $0 + $1.instances.count }
                )
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(items), let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        }

        private func printQueryText(_ results: [(patient: ArchivePatient, study: ArchiveStudy)]) {
            for (i, result) in results.enumerated() {
                if i > 0 { print("") }
                let imageCount = result.study.series.reduce(0) { $0 + $1.instances.count }
                print("Patient: \(result.patient.patientName) (ID: \(result.patient.patientID))")
                print("  Study: \(result.study.studyInstanceUID)")
                if let date = result.study.studyDate { print("  Date: \(date)") }
                if let desc = result.study.studyDescription { print("  Description: \(desc)") }
                if let mod = result.study.modality { print("  Modality: \(mod)") }
                print("  Series: \(result.study.series.count)")
                print("  Images: \(imageCount)")
            }
            print("")
            print("Found \(results.count) matching study(ies)")
        }

        private func truncate(_ str: String, to length: Int) -> String {
            if str.count <= length { return str }
            return String(str.prefix(length - 1)) + "…"
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
            let index = try loadIndex(from: archive)

            guard ["tree", "table", "json"].contains(format.lowercased()) else {
                throw ValidationError("Invalid format: \(format). Use tree, table, or json")
            }

            if index.patients.isEmpty {
                print("Archive is empty.")
                return
            }

            switch format.lowercased() {
            case "json":
                printListJSON(index)
            case "table":
                printListTable(index)
            default:
                printListTree(index, showInstances: showInstances)
            }
        }

        private func printListTree(_ index: ArchiveIndex, showInstances: Bool) {
            print("Archive: \(archive)")
            print("Files: \(index.fileCount)")
            print("")

            for (pi, patient) in index.patients.enumerated() {
                let isLastPatient = pi == index.patients.count - 1
                let pPrefix = isLastPatient ? "└── " : "├── "
                let pCont = isLastPatient ? "    " : "│   "

                print("\(pPrefix)Patient: \(patient.patientName) (ID: \(patient.patientID))")

                for (si, study) in patient.studies.enumerated() {
                    let isLastStudy = si == patient.studies.count - 1
                    let sPrefix = pCont + (isLastStudy ? "└── " : "├── ")
                    let sCont = pCont + (isLastStudy ? "    " : "│   ")

                    let desc = study.studyDescription ?? study.studyInstanceUID
                    let date = study.studyDate.map { " [\($0)]" } ?? ""
                    print("\(sPrefix)Study: \(desc)\(date)")

                    for (sei, series) in study.series.enumerated() {
                        let isLastSeries = sei == study.series.count - 1
                        let sePrefix = sCont + (isLastSeries ? "└── " : "├── ")
                        let seCont = sCont + (isLastSeries ? "    " : "│   ")

                        let seDesc = series.seriesDescription ?? series.seriesInstanceUID
                        print("\(sePrefix)Series: \(series.modality) - \(seDesc) (\(series.instances.count) instances)")

                        if showInstances {
                            for (ii, instance) in series.instances.enumerated() {
                                let isLastInstance = ii == series.instances.count - 1
                                let iPrefix = seCont + (isLastInstance ? "└── " : "├── ")
                                print("\(iPrefix)\(instance.sopInstanceUID)")
                            }
                        }
                    }
                }
            }
        }

        private func printListTable(_ index: ArchiveIndex) {
            let cols = ["Patient Name", "Patient ID", "Studies", "Series", "Images"]
            let widths = [25, 15, 8, 8, 8]

            let header = zip(cols, widths).map { $0.0.padding(toLength: $0.1, withPad: " ", startingAt: 0) }.joined(separator: " | ")
            let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-")

            print(header)
            print(separator)

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
                print(row.joined(separator: " | "))
            }

            print("")
            print("Total: \(index.patients.count) patient(s), \(index.fileCount) file(s)")
        }

        private func printListJSON(_ index: ArchiveIndex) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(index), let json = String(data: data, encoding: .utf8) {
                print(json)
            }
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
            let index = try loadIndex(from: archive)
            let fm = FileManager.default
            let dataDir = dataDirectory(for: archive)
            let outputURL = URL(fileURLWithPath: output)

            if studyUID == nil && seriesUID == nil && patientID == nil {
                throw ValidationError("Specify at least one filter: --study-uid, --series-uid, or --patient-id")
            }

            try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

            var exported = 0
            var failed = 0

            for patient in index.patients {
                if let pid = patientID, patient.patientID != pid {
                    continue
                }

                for study in patient.studies {
                    if let uid = studyUID, study.studyInstanceUID != uid {
                        continue
                    }

                    for series in study.series {
                        if let uid = seriesUID, series.seriesInstanceUID != uid {
                            continue
                        }

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
                                if verbose {
                                    print("  Exported: \(instance.sopInstanceUID)")
                                }
                            } catch {
                                failed += 1
                                if verbose {
                                    print("  ❌ Failed to export \(instance.sopInstanceUID): \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
            }

            print("")
            print("✅ Export complete")
            print("  Exported: \(exported) file(s)")
            if failed > 0 { print("  Failed: \(failed)") }
            print("  Output: \(output)")
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
            let index = try loadIndex(from: archive)
            let fm = FileManager.default
            let dataDir = dataDirectory(for: archive)

            var missingFiles = 0
            var sizeMismatches = 0
            var unreadableFiles = 0
            var orphanedFiles: [String] = []
            var totalChecked = 0

            // Check that all indexed files exist and match
            for patient in index.patients {
                for study in patient.studies {
                    for series in study.series {
                        for instance in series.instances {
                            totalChecked += 1
                            let filePath = dataDir.appendingPathComponent(instance.filePath).path

                            if !fm.fileExists(atPath: filePath) {
                                missingFiles += 1
                                if verbose {
                                    print("❌ Missing: \(instance.filePath)")
                                }
                                continue
                            }

                            // Check file size
                            do {
                                let attrs = try fm.attributesOfItem(atPath: filePath)
                                if let fileSize = attrs[.size] as? Int64, fileSize != instance.fileSize {
                                    sizeMismatches += 1
                                    if verbose {
                                        print("⚠️  Size mismatch: \(instance.filePath) (expected \(instance.fileSize), got \(fileSize))")
                                    }
                                }
                            } catch {
                                if verbose {
                                    print("⚠️  Cannot read attributes: \(instance.filePath)")
                                }
                            }

                            // Optionally verify DICOM readability
                            if verifyFiles {
                                do {
                                    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                                    _ = try DICOMFile.read(from: data, force: true)
                                } catch {
                                    unreadableFiles += 1
                                    if verbose {
                                        print("❌ Unreadable DICOM: \(instance.filePath) - \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Check for orphaned files (files in data/ not in index)
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
                            if verbose {
                                print("🔍 Orphaned file: \(relativePath)")
                            }
                        }
                    }
                }
            }

            // Summary
            print("")
            print("Archive Integrity Report")
            print("========================")
            print("  Files checked: \(totalChecked)")
            print("  Index file count: \(index.fileCount)")
            print("")

            var hasIssues = false

            if missingFiles > 0 {
                print("  ❌ Missing files: \(missingFiles)")
                hasIssues = true
            }
            if sizeMismatches > 0 {
                print("  ⚠️  Size mismatches: \(sizeMismatches)")
                hasIssues = true
            }
            if unreadableFiles > 0 {
                print("  ❌ Unreadable DICOM files: \(unreadableFiles)")
                hasIssues = true
            }
            if !orphanedFiles.isEmpty {
                print("  🔍 Orphaned files: \(orphanedFiles.count)")
                hasIssues = true
            }

            if hasIssues {
                print("")
                print("⚠️  Archive has integrity issues")
            } else {
                print("  ✅ All files present and accounted for")
                if verifyFiles {
                    print("  ✅ All DICOM files readable")
                }
                print("")
                print("✅ Archive integrity OK")
            }
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
            let index = try loadIndex(from: archive)

            guard ["text", "json"].contains(format.lowercased()) else {
                throw ValidationError("Invalid format: \(format). Use text or json")
            }

            // Compute statistics
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
                printStatsJSON(
                    index: index,
                    totalStudies: totalStudies,
                    totalSeries: totalSeries,
                    totalInstances: totalInstances,
                    totalSize: totalSize,
                    modalities: modalities
                )
            default:
                printStatsText(
                    index: index,
                    totalStudies: totalStudies,
                    totalSeries: totalSeries,
                    totalInstances: totalInstances,
                    totalSize: totalSize,
                    modalities: modalities,
                    sopClasses: sopClasses
                )
            }
        }

        private func printStatsText(
            index: ArchiveIndex,
            totalStudies: Int,
            totalSeries: Int,
            totalInstances: Int,
            totalSize: Int64,
            modalities: [String: Int],
            sopClasses: [String: Int]
        ) {
            print("Archive Statistics")
            print("==================")
            print("")
            print("Archive Info:")
            print("  Version: \(index.version)")
            print("  Created: \(index.creationDate)")
            print("  Last modified: \(index.lastModified)")
            print("")
            print("Contents:")
            print("  Patients: \(index.patients.count)")
            print("  Studies: \(totalStudies)")
            print("  Series: \(totalSeries)")
            print("  Instances: \(totalInstances)")
            print("  Total size: \(formatBytes(totalSize))")
            print("")

            if !modalities.isEmpty {
                print("Modalities:")
                for (mod, count) in modalities.sorted(by: { $0.key < $1.key }) {
                    let label = mod.isEmpty ? "(unknown)" : mod
                    print("  \(label): \(count) instance(s)")
                }
                print("")
            }

            if !sopClasses.isEmpty {
                print("SOP Classes:")
                for (sop, count) in sopClasses.sorted(by: { $0.value > $1.value }).prefix(10) {
                    print("  \(sop): \(count)")
                }
                if sopClasses.count > 10 {
                    print("  ... and \(sopClasses.count - 10) more")
                }
            }
        }

        private func printStatsJSON(
            index: ArchiveIndex,
            totalStudies: Int,
            totalSeries: Int,
            totalInstances: Int,
            totalSize: Int64,
            modalities: [String: Int]
        ) {
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
                version: index.version,
                creationDate: index.creationDate,
                lastModified: index.lastModified,
                patients: index.patients.count,
                studies: totalStudies,
                series: totalSeries,
                instances: totalInstances,
                totalSizeBytes: totalSize,
                modalities: modalities
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(output), let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        }

        private func formatBytes(_ bytes: Int64) -> String {
            let units = ["B", "KB", "MB", "GB", "TB"]
            var value = Double(bytes)
            var unitIndex = 0
            while value >= 1024 && unitIndex < units.count - 1 {
                value /= 1024
                unitIndex += 1
            }
            if unitIndex == 0 {
                return "\(bytes) B"
            }
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }
}

DICOMArchive.main()
