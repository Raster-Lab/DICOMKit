import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@main
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
    var sortBy: MergeSortCriteria = .instanceNumber
    
    @Option(name: .long, help: "Sort order: ascending, descending (default: ascending)")
    var order: MergeSortOrder = .ascending
    
    @Flag(name: .long, help: "Validate consistency of input files")
    var validate: Bool = false
    
    @Flag(name: .shortAndLong, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        // Validate inputs
        guard !inputs.isEmpty else {
            throw ValidationError(MergeConsole.noInputFilesMessage)
        }

        for input in inputs {
            guard FileManager.default.fileExists(atPath: input) else {
                throw ValidationError(MergeConsole.inputNotFoundMessage(path: input))
            }
        }

        // Banner via the shared MergeConsole — the exact lines DICOMStudio's
        // Workshop emits (see Sources/DICOMKit/Merging/MergeConsole.swift).
        if verbose {
            for line in MergeConsole.headerLines(
                inputCount: inputs.count, output: output, format: format,
                level: level, sortBy: sortBy, order: order
            ) {
                fprintln(line)
            }
        }

        // Create merger (shared DICOMKit engine; verbose output routed to stderr)
        let merger = FrameMerger(
            format: format,
            level: level,
            sortBy: sortBy,
            order: order,
            validate: validate,
            verbose: verbose,
            log: { fprintln($0) }
        )
        
        // Gather input files
        let files = try gatherInputFiles(from: inputs, recursive: recursive)
        
        if verbose {
            for line in MergeConsole.foundFilesLines(count: files.count) { fprintln(line) }
        }

        guard !files.isEmpty else {
            throw ValidationError(MergeConsole.noDICOMFilesFoundMessage)
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
        
        for line in MergeConsole.completionLines() { fprintln(line) }
    }
    
    func gatherInputFiles(from paths: [String], recursive: Bool) throws -> [String] {
        // Shared, sorted gatherer (FrameMerger) — the exact walk the Workshop uses,
        // so both surfaces merge the same files in the same deterministic order.
        try FrameMerger.gatherInputFiles(from: paths, recursive: recursive)
    }
}

// FrameMerger + MergeError + these option enums now live in the DICOMKit library
// (Sources/DICOMKit/Merging/). ArgumentParser stays out of the library, so the
// CLI supplies the command-line conformances here.
extension MergeFormat: ExpressibleByArgument {}
extension MergeLevel: ExpressibleByArgument {}
extension MergeSortCriteria: ExpressibleByArgument {}
extension MergeSortOrder: ExpressibleByArgument {}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
