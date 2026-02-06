import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@available(macOS 10.15, *)
struct DICOMSplit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-split",
        abstract: "Extract individual frames from multi-frame DICOM files",
        discussion: """
            Extracts individual frames from multi-frame DICOM files such as Enhanced CT/MR/XA,
            ultrasound, or nuclear medicine images. Supports output as DICOM files or common
            image formats (PNG, JPEG, TIFF).
            
            Examples:
              # Extract all frames to DICOM files
              dicom-split multiframe.dcm --output frames/
              
              # Extract specific frames
              dicom-split multiframe.dcm --frames 1,5,10-15 --output selected/
              
              # Extract as PNG images with windowing
              dicom-split ct-multiframe.dcm \\
                --format png \\
                --apply-window \\
                --window-center 40 \\
                --window-width 400 \\
                --output images/
              
              # Batch processing with custom naming
              dicom-split studies/ \\
                --output split_studies/ \\
                --pattern "frame_{number:04d}_{modality}.dcm" \\
                --recursive
            """,
        version: "1.1.2"
    )
    
    @Argument(help: "Input DICOM file or directory")
    var input: String
    
    @Option(name: .long, help: "Output directory for extracted frames")
    var output: String = "."
    
    @Option(name: .long, help: "Frame numbers to extract (e.g., '1,3,5-10')")
    var frames: String?
    
    @Option(name: .long, help: "Output format: dicom, png, jpeg, tiff (default: dicom)")
    var format: OutputFormat = .dicom
    
    @Flag(name: .long, help: "Apply window/level settings to image output")
    var applyWindow: Bool = false
    
    @Option(name: .long, help: "Window center for image rendering")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width for image rendering")
    var windowWidth: Double?
    
    @Option(name: .long, help: "Naming pattern for output files (variables: {number}, {modality}, {series})")
    var pattern: String?
    
    @Flag(name: .shortAndLong, help: "Recursively process directories")
    var recursive: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        // Validate input
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("Input path does not exist: \(input)")
        }
        
        // Create output directory
        try createOutputDirectory(output)
        
        if verbose {
            fprintln("DICOM Split Tool v1.1.2")
            fprintln("========================")
            fprintln("Input: \(input)")
            fprintln("Output: \(output)")
            fprintln("Format: \(format)")
            if let frames = frames {
                fprintln("Frames: \(frames)")
            }
            if applyWindow {
                fprintln("Window Center: \(windowCenter ?? 0)")
                fprintln("Window Width: \(windowWidth ?? 0)")
            }
            fprintln("")
        }
        
        // Create splitter
        let splitter = FrameSplitter(
            outputPath: output,
            format: format,
            applyWindow: applyWindow,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            namingPattern: pattern,
            verbose: verbose
        )
        
        // Parse frame ranges
        let frameIndices = try frames.map { try parseFrameRange($0) }
        
        // Process files
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory), isDirectory.boolValue {
            // Directory processing
            try await splitter.processDirectory(input, recursive: recursive, frameIndices: frameIndices)
        } else {
            // Single file processing
            try await splitter.processFile(input, frameIndices: frameIndices)
        }
        
        fprintln("\nSplit complete!")
    }
    
    func createOutputDirectory(_ path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw ValidationError("Output path exists but is not a directory: \(path)")
            }
        } else {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
    
    func parseFrameRange(_ rangeString: String) throws -> Set<Int> {
        var indices = Set<Int>()
        
        let parts = rangeString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for part in parts {
            if part.contains("-") {
                // Range like "5-10"
                let bounds = part.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard bounds.count == 2,
                      let start = Int(bounds[0]),
                      let end = Int(bounds[1]),
                      start <= end else {
                    throw ValidationError("Invalid frame range: \(part)")
                }
                for i in start...end {
                    indices.insert(i)
                }
            } else {
                // Single number
                guard let index = Int(part) else {
                    throw ValidationError("Invalid frame number: \(part)")
                }
                indices.insert(index)
            }
        }
        
        return indices
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case dicom
    case png
    case jpeg
    case tiff
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMSplit.main()
