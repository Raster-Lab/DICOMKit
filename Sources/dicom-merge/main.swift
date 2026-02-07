import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@available(macOS 10.15, *)
struct DICOMMerge: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-merge",
        abstract: "Combine single-frame DICOM images into multi-frame files",
        discussion: """
            Combines single-frame DICOM images into multi-frame DICOM files. Supports creating
            Enhanced CT/MR/XA formats with proper functional groups, or legacy multi-frame formats.
            Can also combine multiple series into a single study.
            
            Examples:
              # Combine single frames into multi-frame
              dicom-merge frame_*.dcm --output multiframe.dcm
              
              # Create enhanced multi-frame CT
              dicom-merge ct_slices/*.dcm \\
                --output enhanced_ct.dcm \\
                --format enhanced-ct
              
              # Combine series into single study
              dicom-merge series1/ series2/ \\
                --output combined_study/ \\
                --level study
              
              # Custom frame ordering
              dicom-merge slices/*.dcm \\
                --output volume.dcm \\
                --sort-by ImagePositionPatient \\
                --order ascending
            """,
        version: "1.1.2"
    )
    
    @Argument(help: "Input DICOM files or directories")
    var inputs: [String]
    
    @Option(name: .shortAndLong, help: "Output file or directory path")
    var output: String
    
    @Option(name: .long, help: "Output format: standard, enhanced-ct, enhanced-mr, enhanced-xa (default: standard)")
    var format: MergeFormat = .standard
    
    @Option(name: .long, help: "Merge level: file, series, study (default: file)")
    var level: MergeLevel = .file
    
    @Option(name: .long, help: "Sort frames by: InstanceNumber, ImagePositionPatient, AcquisitionTime, none (default: InstanceNumber)")
    var sortBy: SortCriteria = .instanceNumber
    
    @Option(name: .long, help: "Sort order: ascending, descending (default: ascending)")
    var order: SortOrder = .ascending
    
    @Flag(name: .long, help: "Validate consistency of input files")
    var validate: Bool = false
    
    @Flag(name: .shortAndLong, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        // Validate inputs
        guard !inputs.isEmpty else {
            throw ValidationError("No input files specified")
        }
        
        for input in inputs {
            guard FileManager.default.fileExists(atPath: input) else {
                throw ValidationError("Input path does not exist: \(input)")
            }
        }
        
        if verbose {
            fprintln("DICOM Merge Tool v1.1.2")
            fprintln("========================")
            fprintln("Inputs: \(inputs.count) path(s)")
            fprintln("Output: \(output)")
            fprintln("Format: \(format)")
            fprintln("Level: \(level)")
            fprintln("Sort: \(sortBy) (\(order))")
            fprintln("")
        }
        
        // Create merger
        let merger = FrameMerger(
            format: format,
            level: level,
            sortBy: sortBy,
            order: order,
            validate: validate,
            verbose: verbose
        )
        
        // Gather input files
        let files = try gatherInputFiles(from: inputs, recursive: recursive)
        
        if verbose {
            fprintln("Found \(files.count) DICOM files to process")
            fprintln("")
        }
        
        guard !files.isEmpty else {
            throw ValidationError("No DICOM files found in input paths")
        }
        
        // Process based on merge level
        switch level {
        case .file:
            try await merger.mergeToSingleFile(files: files, outputPath: output)
        case .series:
            try await merger.mergeBySeries(files: files, outputDirectory: output)
        case .study:
            try await merger.mergeByStudy(files: files, outputDirectory: output)
        }
        
        fprintln("\nMerge complete!")
    }
    
    func gatherInputFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        
        for path in paths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }
            
            if isDirectory.boolValue {
                // Directory - gather files
                if recursive {
                    // Recursive scan
                    guard let enumerator = fileManager.enumerator(atPath: path) else {
                        throw ValidationError("Failed to enumerate directory: \(path)")
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
                    // Only direct children
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
            } else {
                // Single file
                if isDICOMFile(path) {
                    files.append(path)
                }
            }
        }
        
        return files
    }
    
    func isDICOMFile(_ path: String) -> Bool {
        // Check file extension
        let ext = (path as NSString).pathExtension.lowercased()
        if ["dcm", "dicom", "dic"].contains(ext) {
            return true
        }
        
        // Check for DICM magic bytes
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: 132) else {
            return false
        }
        
        // DICOM files have "DICM" at byte 128
        if data.count >= 132 {
            let magic = data[128..<132]
            return magic == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
        }
        
        return false
    }
}

enum MergeFormat: String, ExpressibleByArgument {
    case standard
    case enhancedCt = "enhanced-ct"
    case enhancedMr = "enhanced-mr"
    case enhancedXa = "enhanced-xa"
}

enum MergeLevel: String, ExpressibleByArgument {
    case file
    case series
    case study
}

enum SortCriteria: String, ExpressibleByArgument {
    case instanceNumber = "InstanceNumber"
    case imagePositionPatient = "ImagePositionPatient"
    case acquisitionTime = "AcquisitionTime"
    case none
}

enum SortOrder: String, ExpressibleByArgument {
    case ascending
    case descending
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMMerge.main()
