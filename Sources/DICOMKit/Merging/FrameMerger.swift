import Foundation
import DICOMCore
import DICOMDictionary

/// Output container format for a merge.
public enum MergeFormat: String, Sendable {
    case standard
    case enhancedCt = "enhanced-ct"
    case enhancedMr = "enhanced-mr"
    case enhancedXa = "enhanced-xa"

    /// The Enhanced multi-frame SOP Class UID for this format (nil for standard).
    public var enhancedSOPClassUID: String? {
        switch self {
        case .standard:   return nil
        case .enhancedCt: return "1.2.840.10008.5.1.4.1.1.2.1"     // Enhanced CT Image Storage
        case .enhancedMr: return "1.2.840.10008.5.1.4.1.1.4.1"     // Enhanced MR Image Storage
        case .enhancedXa: return "1.2.840.10008.5.1.4.1.1.12.1.1"  // Enhanced XA Image Storage
        }
    }
}

/// How input files are grouped into outputs.
public enum MergeLevel: String, Sendable {
    case file
    case series
    case study
}

/// Frame ordering criteria.
public enum MergeSortCriteria: String, Sendable {
    case instanceNumber = "InstanceNumber"
    case imagePositionPatient = "ImagePositionPatient"
    case acquisitionTime = "AcquisitionTime"
    case none
}

/// Frame ordering direction.
public enum MergeSortOrder: String, Sendable {
    case ascending
    case descending
}

/// Merges single-frame DICOM files into multi-frame files.
///
/// Lives in the DICOMKit library so the `dicom-merge` CLI and DICOMStudio run the
/// exact same merge code. Verbose progress is emitted through the injected `log`
/// closure (the CLI routes it to stderr, the app to its console string) so the
/// wording comes from one place. Group iteration is sorted by UID so multi-output
/// (series/study) runs are deterministic.
public struct FrameMerger {
    public let format: MergeFormat
    public let level: MergeLevel
    public let sortBy: MergeSortCriteria
    public let order: MergeSortOrder
    public let validate: Bool
    public let verbose: Bool

    /// Verbose progress sink. Called only when `verbose` is true.
    private let log: (String) -> Void

    private let fileManager = FileManager.default

    public init(
        format: MergeFormat,
        level: MergeLevel,
        sortBy: MergeSortCriteria,
        order: MergeSortOrder,
        validate: Bool,
        verbose: Bool,
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.format = format
        self.level = level
        self.sortBy = sortBy
        self.order = order
        self.validate = validate
        self.verbose = verbose
        self.log = log
    }

    /// Merges all files into a single multi-frame file.
    public func mergeToSingleFile(files: [String], outputPath: String) async throws {
        if verbose {
            log("Merging \(files.count) files into single multi-frame file")
        }

        // Load all DICOM files
        var dicomFiles: [(String, DICOMFile)] = []
        for path in files.sorted() {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)) {
                dicomFiles.append((path, file))
            } else if verbose {
                log("Warning: Skipping non-DICOM file: \(path)")
            }
        }

        guard !dicomFiles.isEmpty else {
            throw MergeError.noValidFiles
        }

        // Validate consistency if requested
        if validate {
            try validateConsistency(dicomFiles.map { $0.1 })
        }

        // Sort frames
        let sortedFiles = sortFrames(dicomFiles, by: sortBy, order: order)

        // Merge into multi-frame
        let multiFrameFile = try createMultiFrameFile(from: sortedFiles)

        // Write output
        let data = try multiFrameFile.write()
        try data.write(to: URL(fileURLWithPath: outputPath))

        if verbose {
            log("Created multi-frame file with \(sortedFiles.count) frames: \(outputPath)")
        }
    }

    /// Merges files grouped by series.
    public func mergeBySeries(files: [String], outputDirectory: String) async throws {
        if verbose {
            log("Merging files by series")
        }

        // Create output directory
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        // Load and group by series
        var seriesGroups: [String: [(String, DICOMFile)]] = [:]

        for path in files.sorted() {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)),
               let seriesUID = file.dataSet.string(for: .seriesInstanceUID) {
                seriesGroups[seriesUID, default: []].append((path, file))
            } else if verbose {
                log("Warning: Skipping file without series UID: \(path)")
            }
        }

        if verbose {
            log("Found \(seriesGroups.count) series")
        }

        // Process each series (sorted by UID for deterministic output)
        for (seriesUID, seriesFiles) in seriesGroups.sorted(by: { $0.key < $1.key }) {
            let outputPath = (outputDirectory as NSString).appendingPathComponent("series_\(seriesUID).dcm")

            // Sort frames
            let sortedFiles = sortFrames(seriesFiles, by: sortBy, order: order)

            // Validate consistency if requested
            if validate {
                try validateConsistency(sortedFiles.map { $0.1 })
            }

            // Merge into multi-frame
            let multiFrameFile = try createMultiFrameFile(from: sortedFiles)

            // Write output
            let data = try multiFrameFile.write()
            try data.write(to: URL(fileURLWithPath: outputPath))

            if verbose {
                log("  Series \(seriesUID): \(sortedFiles.count) frames -> \(outputPath)")
            }
        }
    }

    /// Merges files grouped by study.
    public func mergeByStudy(files: [String], outputDirectory: String) async throws {
        if verbose {
            log("Merging files by study")
        }

        // Create output directory
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        // Load and group by study
        var studyGroups: [String: [(String, DICOMFile)]] = [:]

        for path in files.sorted() {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)),
               let studyUID = file.dataSet.string(for: .studyInstanceUID) {
                studyGroups[studyUID, default: []].append((path, file))
            } else if verbose {
                log("Warning: Skipping file without study UID: \(path)")
            }
        }

        if verbose {
            log("Found \(studyGroups.count) studies")
        }

        // Process each study (sorted by UID for deterministic output)
        for (studyUID, studyFiles) in studyGroups.sorted(by: { $0.key < $1.key }) {
            let studyDir = (outputDirectory as NSString).appendingPathComponent("study_\(studyUID)")
            try fileManager.createDirectory(atPath: studyDir, withIntermediateDirectories: true)

            // Group by series within study
            var seriesGroups: [String: [(String, DICOMFile)]] = [:]

            for (path, file) in studyFiles {
                if let seriesUID = file.dataSet.string(for: .seriesInstanceUID) {
                    seriesGroups[seriesUID, default: []].append((path, file))
                }
            }

            if verbose {
                log("  Study \(studyUID): \(seriesGroups.count) series")
            }

            // Process each series (sorted by UID for deterministic output)
            for (seriesUID, seriesFiles) in seriesGroups.sorted(by: { $0.key < $1.key }) {
                let outputPath = (studyDir as NSString).appendingPathComponent("series_\(seriesUID).dcm")

                // Sort frames
                let sortedFiles = sortFrames(seriesFiles, by: sortBy, order: order)

                // Validate consistency if requested
                if validate {
                    try validateConsistency(sortedFiles.map { $0.1 })
                }

                // Merge into multi-frame
                let multiFrameFile = try createMultiFrameFile(from: sortedFiles)

                // Write output
                let data = try multiFrameFile.write()
                try data.write(to: URL(fileURLWithPath: outputPath))

                if verbose {
                    log("    Series \(seriesUID): \(sortedFiles.count) frames -> \(outputPath)")
                }
            }
        }
    }

    /// Creates a multi-frame DICOM file from sorted single-frame files.
    private func createMultiFrameFile(from files: [(String, DICOMFile)]) throws -> DICOMFile {
        guard let firstFile = files.first else {
            throw MergeError.noValidFiles
        }

        // Use first file as template
        var mergedDataSet = firstFile.1.dataSet

        // Collect pixel data from all frames
        var allPixelData = Data()

        for (_, file) in files {
            guard let pixelData = file.dataSet[.pixelData]?.valueData else {
                throw MergeError.missingPixelData(file: file.dataSet.string(for: .sopInstanceUID) ?? "unknown")
            }
            allPixelData.append(pixelData)
        }

        // Update Number of Frames
        let numberOfFrames = files.count
        mergedDataSet.setString("\(numberOfFrames)", for: .numberOfFrames, vr: .IS)

        // Update pixel data with all frames
        mergedDataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: .OW,
            length: UInt32(allPixelData.count),
            valueData: allPixelData
        )

        // Generate new SOP Instance UID for the merged file
        let newSOPInstanceUID = UIDGenerator.generateSOPInstanceUID()
        mergedDataSet.setString(newSOPInstanceUID.value, for: .sopInstanceUID, vr: .UI)

        // Update instance number to 1 (multi-frame is a single instance)
        mergedDataSet.setString("1", for: .instanceNumber, vr: .IS)

        // Enhanced formats: rewrite the SOP Class to the Enhanced multi-frame
        // IOD and emit the Multi-frame Functional Groups module (PS3.3 C.7.6.16)
        // — Shared (Pixel Measures) + Per-frame (Frame Content, Plane Position).
        var fileMetaInformation = firstFile.1.fileMetaInformation
        if let enhancedUID = format.enhancedSOPClassUID {
            mergedDataSet.setString(enhancedUID, for: .sopClassUID, vr: .UI)
            fileMetaInformation.setString(enhancedUID, for: .mediaStorageSOPClassUID, vr: .UI)
            fileMetaInformation.setString(newSOPInstanceUID.value, for: .mediaStorageSOPInstanceUID, vr: .UI)

            let writer = DICOMWriter()

            // Shared Functional Groups: Pixel Measures lifted from the template frame.
            var pixelMeasuresElements: [DataElement] = []
            for (tag, vr) in [(Tag.pixelSpacing, VR.DS), (.sliceThickness, .DS), (.spacingBetweenSlices, .DS)] {
                if let value = mergedDataSet.string(for: tag), !value.isEmpty {
                    pixelMeasuresElements.append(DataElement.string(tag: tag, vr: vr, value: value))
                }
            }
            var sharedElements: [DataElement] = []
            if !pixelMeasuresElements.isEmpty {
                let pmItem = SequenceItem(elements: pixelMeasuresElements)
                let pmData = writer.serializeSequenceItem(pmItem)
                sharedElements.append(DataElement(
                    tag: .pixelMeasuresSequence, vr: .SQ,
                    length: UInt32(pmData.count), valueData: pmData, sequenceItems: [pmItem]))
            }
            mergedDataSet.setSequence([SequenceItem(elements: sharedElements)],
                                      for: .sharedFunctionalGroupsSequence)

            // Per-frame Functional Groups: one item per source frame.
            var perFrameItems: [SequenceItem] = []
            for (index, (_, file)) in files.enumerated() {
                var groupElements: [DataElement] = []

                // Frame Content: stack bookkeeping in source order.
                let frameContentElements: [DataElement] = [
                    DataElement.string(tag: .stackID, vr: .SH, value: "1"),
                    DataElement.uint32(tag: .inStackPositionNumber, value: UInt32(index + 1)),
                    DataElement.uint32s(tag: .dimensionIndexValues, values: [1, UInt32(index + 1)]),
                ]
                let fcItem = SequenceItem(elements: frameContentElements)
                let fcData = writer.serializeSequenceItem(fcItem)
                groupElements.append(DataElement(
                    tag: .frameContentSequence, vr: .SQ,
                    length: UInt32(fcData.count), valueData: fcData, sequenceItems: [fcItem]))

                // Plane Position: the source frame's Image Position (Patient), when present.
                if let position = file.dataSet.string(for: .imagePositionPatient), !position.isEmpty {
                    let ppItem = SequenceItem(elements: [
                        DataElement.string(tag: .imagePositionPatient, vr: .DS, value: position)
                    ])
                    let ppData = writer.serializeSequenceItem(ppItem)
                    groupElements.append(DataElement(
                        tag: .planePositionSequence, vr: .SQ,
                        length: UInt32(ppData.count), valueData: ppData, sequenceItems: [ppItem]))
                }

                perFrameItems.append(SequenceItem(elements: groupElements))
            }
            mergedDataSet.setSequence(perFrameItems, for: .perFrameFunctionalGroupsSequence)
        }

        // Create new DICOM file
        let newFile = DICOMFile(
            fileMetaInformation: fileMetaInformation,
            dataSet: mergedDataSet
        )

        return newFile
    }

    /// Sorts frames based on specified criteria.
    private func sortFrames(
        _ files: [(String, DICOMFile)],
        by criteria: MergeSortCriteria,
        order: MergeSortOrder
    ) -> [(String, DICOMFile)] {
        guard criteria != .none else {
            return files
        }

        let sorted = files.sorted { file1, file2 in
            let result: Bool

            switch criteria {
            case .instanceNumber:
                // InstanceNumber (0020,0013) is VR=IS — an integer *string*.
                // int32(for:) only decodes binary SL and returns nil here, which
                // collapses every value to 0 and silently disables the sort. Parse
                // the IS string instead.
                let num1 = file1.1.dataSet.string(for: .instanceNumber)
                    .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
                let num2 = file2.1.dataSet.string(for: .instanceNumber)
                    .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
                result = num1 < num2

            case .imagePositionPatient:
                let pos1 = parseDecimalArray(from: file1.1.dataSet, tag: .imagePositionPatient)
                let pos2 = parseDecimalArray(from: file2.1.dataSet, tag: .imagePositionPatient)
                let z1 = pos1.count >= 3 ? pos1[2] : 0.0
                let z2 = pos2.count >= 3 ? pos2[2] : 0.0
                result = z1 < z2

            case .acquisitionTime:
                let time1 = file1.1.dataSet.string(for: .acquisitionTime) ?? ""
                let time2 = file2.1.dataSet.string(for: .acquisitionTime) ?? ""
                result = time1 < time2

            case .none:
                result = false
            }

            return order == .ascending ? result : !result
        }

        return sorted
    }

    /// Parses a decimal string array (DS VR) into doubles.
    private func parseDecimalArray(from dataSet: DataSet, tag: Tag) -> [Double] {
        guard let decimalStrings = dataSet.decimalStrings(for: tag) else {
            return []
        }
        return decimalStrings.map { $0.value }
    }

    /// Validates that files are consistent for merging.
    private func validateConsistency(_ files: [DICOMFile]) throws {
        guard let first = files.first else {
            return
        }

        // Check required attributes match
        let requiredMatchingTags: [Tag] = [
            .studyInstanceUID,
            .seriesInstanceUID,
            .modality,
            .rows,
            .columns,
            .bitsAllocated,
            .bitsStored,
            .highBit,
            .pixelRepresentation,
            .samplesPerPixel,
            .photometricInterpretation
        ]

        for tag in requiredMatchingTags {
            let firstValue = first.dataSet.string(for: tag)

            for file in files.dropFirst() {
                let value = file.dataSet.string(for: tag)
                if value != firstValue {
                    let tagName = tag.description
                    throw MergeError.inconsistentAttribute(
                        tag: tagName,
                        expected: firstValue ?? "nil",
                        found: value ?? "nil"
                    )
                }
            }
        }

        // Check pixel data size
        if let firstPixelData = first.dataSet[.pixelData]?.valueData {
            let firstSize = firstPixelData.count

            for file in files.dropFirst() {
                if let pixelData = file.dataSet[.pixelData]?.valueData {
                    if pixelData.count != firstSize {
                        throw MergeError.inconsistentPixelDataSize(
                            expected: firstSize,
                            found: pixelData.count
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Errors

public enum MergeError: Error, CustomStringConvertible {
    case noValidFiles
    case missingPixelData(file: String)
    case inconsistentAttribute(tag: String, expected: String, found: String)
    case inconsistentPixelDataSize(expected: Int, found: Int)
    case directoryEnumerationFailed(path: String)

    public var description: String {
        switch self {
        case .noValidFiles:
            return "No valid DICOM files found"
        case .missingPixelData(let file):
            return "Missing pixel data in file: \(file)"
        case .inconsistentAttribute(let tag, let expected, let found):
            return "Inconsistent \(tag): expected '\(expected)', found '\(found)'"
        case .inconsistentPixelDataSize(let expected, let found):
            return "Inconsistent pixel data size: expected \(expected) bytes, found \(found) bytes"
        case .directoryEnumerationFailed(let path):
            return "Failed to enumerate directory: \(path)"
        }
    }
}

// MARK: - Shared input gathering (dicom-merge CLI ⇄ Workshop executor)

extension FrameMerger {
    /// True when the path looks like a DICOM file: a known extension
    /// (.dcm/.dicom/.dic) or the "DICM" magic at byte 128.
    public static func isDICOMFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if ["dcm", "dicom", "dic"].contains(ext) {
            return true
        }
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: 132) else {
            return false
        }
        if data.count >= 132 {
            let magic = data[128..<132]
            return magic == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
        }
        return false
    }

    /// Gathers DICOM input files from a mix of file and directory paths.
    /// Directories are expanded (recursively when requested); non-existent paths
    /// are skipped. The result is sorted so the merge frame/instance order is
    /// deterministic and identical on the CLI and Workshop surfaces.
    public static func gatherInputFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default

        for path in paths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                if recursive {
                    guard let enumerator = fileManager.enumerator(atPath: path) else {
                        throw MergeError.directoryEnumerationFailed(path: path)
                    }
                    for case let item as String in enumerator {
                        let fullPath = (path as NSString).appendingPathComponent(item)
                        var itemIsDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDirectory),
                           !itemIsDirectory.boolValue,
                           isDICOMFile(fullPath) {
                            files.append(fullPath)
                        }
                    }
                } else {
                    let contents = try fileManager.contentsOfDirectory(atPath: path)
                    for item in contents {
                        let fullPath = (path as NSString).appendingPathComponent(item)
                        var itemIsDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDirectory),
                           !itemIsDirectory.boolValue,
                           isDICOMFile(fullPath) {
                            files.append(fullPath)
                        }
                    }
                }
            } else if isDICOMFile(path) {
                files.append(path)
            }
        }

        return files.sorted()
    }
}
