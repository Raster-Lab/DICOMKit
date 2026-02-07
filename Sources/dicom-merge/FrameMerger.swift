import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

/// Merges single-frame DICOM files into multi-frame files
struct FrameMerger {
    let format: MergeFormat
    let level: MergeLevel
    let sortBy: SortCriteria
    let order: SortOrder
    let validate: Bool
    let verbose: Bool
    
    private let fileManager = FileManager.default
    
    /// Merges all files into a single multi-frame file
    func mergeToSingleFile(files: [String], outputPath: String) async throws {
        if verbose {
            fprintln("Merging \(files.count) files into single multi-frame file")
        }
        
        // Load all DICOM files
        var dicomFiles: [(String, DICOMFile)] = []
        for path in files {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)) {
                dicomFiles.append((path, file))
            } else if verbose {
                fprintln("Warning: Skipping non-DICOM file: \(path)")
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
            fprintln("Created multi-frame file with \(sortedFiles.count) frames: \(outputPath)")
        }
    }
    
    /// Merges files grouped by series
    func mergeBySeries(files: [String], outputDirectory: String) async throws {
        if verbose {
            fprintln("Merging files by series")
        }
        
        // Create output directory
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
        
        // Load and group by series
        var seriesGroups: [String: [(String, DICOMFile)]] = [:]
        
        for path in files {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)),
               let seriesUID = file.dataSet.string(for: .seriesInstanceUID) {
                seriesGroups[seriesUID, default: []].append((path, file))
            } else if verbose {
                fprintln("Warning: Skipping file without series UID: \(path)")
            }
        }
        
        if verbose {
            fprintln("Found \(seriesGroups.count) series")
        }
        
        // Process each series
        for (seriesUID, seriesFiles) in seriesGroups {
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
                fprintln("  Series \(seriesUID): \(sortedFiles.count) frames -> \(outputPath)")
            }
        }
    }
    
    /// Merges files grouped by study
    func mergeByStudy(files: [String], outputDirectory: String) async throws {
        if verbose {
            fprintln("Merging files by study")
        }
        
        // Create output directory
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
        
        // Load and group by study
        var studyGroups: [String: [(String, DICOMFile)]] = [:]
        
        for path in files {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)),
               let studyUID = file.dataSet.string(for: .studyInstanceUID) {
                studyGroups[studyUID, default: []].append((path, file))
            } else if verbose {
                fprintln("Warning: Skipping file without study UID: \(path)")
            }
        }
        
        if verbose {
            fprintln("Found \(studyGroups.count) studies")
        }
        
        // Process each study (further group by series within study)
        for (studyUID, studyFiles) in studyGroups {
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
                fprintln("  Study \(studyUID): \(seriesGroups.count) series")
            }
            
            // Process each series
            for (seriesUID, seriesFiles) in seriesGroups {
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
                    fprintln("    Series \(seriesUID): \(sortedFiles.count) frames -> \(outputPath)")
                }
            }
        }
    }
    
    /// Creates a multi-frame DICOM file from sorted single-frame files
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
        
        // Remove per-frame attributes that are no longer valid for multi-frame
        // (These should be moved to functional groups for Enhanced formats)
        let perFrameTagsToRemove: [Tag] = []
        for tag in perFrameTagsToRemove {
            mergedDataSet.remove(tag: tag)
        }
        
        // Create new DICOM file
        let newFile = DICOMFile(
            fileMetaInformation: firstFile.1.fileMetaInformation,
            dataSet: mergedDataSet
        )
        
        return newFile
    }
    
    /// Sorts frames based on specified criteria
    private func sortFrames(
        _ files: [(String, DICOMFile)],
        by criteria: SortCriteria,
        order: SortOrder
    ) -> [(String, DICOMFile)] {
        guard criteria != .none else {
            return files
        }
        
        let sorted = files.sorted { file1, file2 in
            let result: Bool
            
            switch criteria {
            case .instanceNumber:
                // Parse Instance Number from integer string
                let num1 = file1.1.dataSet.int32(for: .instanceNumber) ?? 0
                let num2 = file2.1.dataSet.int32(for: .instanceNumber) ?? 0
                result = num1 < num2
                
            case .imagePositionPatient:
                // Sort by Z position (third component of ImagePositionPatient)
                // Parse as decimal strings
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
    
    /// Parses a decimal string array (DS VR) into doubles
    private func parseDecimalArray(from dataSet: DataSet, tag: Tag) -> [Double] {
        guard let decimalStrings = dataSet.decimalStrings(for: tag) else {
            return []
        }
        return decimalStrings.map { $0.value }
    }
    
    /// Validates that files are consistent for merging
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

enum MergeError: Error, CustomStringConvertible {
    case noValidFiles
    case missingPixelData(file: String)
    case inconsistentAttribute(tag: String, expected: String, found: String)
    case inconsistentPixelDataSize(expected: Int, found: Int)
    
    var description: String {
        switch self {
        case .noValidFiles:
            return "No valid DICOM files found"
        case .missingPixelData(let file):
            return "Missing pixel data in file: \(file)"
        case .inconsistentAttribute(let tag, let expected, let found):
            return "Inconsistent \(tag): expected '\(expected)', found '\(found)'"
        case .inconsistentPixelDataSize(let expected, let found):
            return "Inconsistent pixel data size: expected \(expected) bytes, found \(found) bytes"
        }
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
