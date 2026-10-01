import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@main
struct DICOMSplit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-split",
        abstract: "Extract individual frames from multi-frame DICOM files",
        discussion: """
            Extracts individual frames from multi-frame DICOM files. Enhanced CT/MR/PET/XA/XRF
            and Legacy Converted objects become classic single-frame instances (CT/MR/PET/XA/XRF
            Image Storage) with their Shared and Per-frame Functional Groups flattened to the top
            level; US Multi-frame and Multi-frame Secondary Capture become US/SC Image Storage
            with cine vectors resolved; NM, XA/RF, RT, Breast Tomosynthesis, X-Ray 3D, OPT,
            Enhanced US Volume and similar keep their SOP Class with one frame per instance.
            Compressed sources keep their transfer syntax frame by frame. Supports output as
            DICOM files or common image formats (PNG, JPEG, TIFF).

            Examples:
              # Extract all frames to DICOM files (Enhanced CT -> CT Image Storage)
              dicom-split multiframe.dcm --output frames/

              # Extract specific frames
              dicom-split multiframe.dcm --frames 1,5,10-15 --output selected/

              # Keep the Enhanced SOP class, one series per stack
              dicom-split enhanced-mr.dcm --target same --split-by stack --output stacks/

              # Decode a JPEG 2000 multi-frame to native pixels while splitting
              dicom-split j2k-multiframe.dcm --pixel-handling decode --output native/

              # Split a Segmentation into concatenation parts of 25 frames
              dicom-split seg.dcm --frames-per 25 --output parts/

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
    var format: SplitOutputFormat = .dicom
    
    @Flag(name: .long, help: "Apply window/level settings to image output")
    var applyWindow: Bool = false
    
    @Option(name: .long, help: ArgumentHelp(SplitConsole.windowCenterHelp))
    var windowCenter: Double?
    
    @Option(name: .long, help: ArgumentHelp(SplitConsole.windowWidthHelp))
    var windowWidth: Double?
    
    @Option(name: .long, help: "Naming pattern for output files (variables: {number}, {number:04d}, {instance}, {stack}, {modality}, {series})")
    var pattern: String?

    @Option(name: .long, help: "SOP class of the extracted frames: auto (classic when one exists), same, classic (default: auto)")
    var target: SplitTargetPolicy = .auto

    @Option(name: .long, help: "Compressed sources: preserve the transfer syntax per frame, or decode to native (default: preserve)")
    var pixelHandling: MultiframePixelHandling = .preserve

    @Option(name: .long, help: "Private functional groups: flatten, keep, drop (default: flatten)")
    var privateGroups: PrivateFunctionalGroupPolicy = .flatten

    @Option(name: .long, help: "Instance Number of the frames: frame, instack, original (default: frame)")
    var instanceNumber: SplitInstanceNumbering = .frame

    @Option(name: .long, help: "Write one series per: none, stack, temporal (default: none)")
    var splitBy: SplitSeriesGrouping = .none

    @Flag(name: .long, help: "Mint a new Series Instance UID for the extracted frames")
    var newSeries: Bool = false

    @Option(name: .long, help: ArgumentHelp(SplitConsole.framesPerHelp))
    var framesPer: Int?

    @Flag(name: .long, help: "Generate random SOP/Series Instance UIDs instead of deriving them from the source (derived UIDs make the split reproducible and let frame references be rewritten)")
    var randomUids: Bool = false

    @Flag(name: .shortAndLong, help: "Recursively process directories")
    var recursive: Bool = false

    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
        // Validate input
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError(SplitConsole.inputNotFoundMessage(path: input))
        }

        // Create output directory
        try createOutputDirectory(output)

        var options = SplitOptions()
        options.target = target
        options.pixelHandling = pixelHandling
        options.privateGroups = privateGroups
        options.instanceNumbering = instanceNumber
        options.seriesGrouping = splitBy
        options.newSeries = newSeries
        options.framesPerInstance = framesPer
        options.deterministicUIDs = !randomUids
        if let framesPer, framesPer < 1 {
            throw ValidationError(SplitConsole.framesPerTooSmallMessage)
        }

        // Banner via the shared SplitConsole — the exact lines DICOMStudio's
        // Workshop emits (see Sources/DICOMKit/Splitting/SplitConsole.swift).
        if verbose {
            for line in SplitConsole.headerLines(
                input: input, output: output, format: format, frames: frames,
                applyWindow: applyWindow, windowCenter: windowCenter, windowWidth: windowWidth,
                options: options
            ) {
                fprintln(line)
            }
        }

        // Create splitter (shared DICOMKit engine; verbose output routed to stderr)
        let splitter = FrameSplitter(
            outputPath: output,
            format: format,
            applyWindow: applyWindow,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            namingPattern: pattern,
            verbose: verbose,
            options: options,
            log: { fprintln($0) }
        )

        // Parse frame ranges through the shared parser (one copy of the grammar
        // and its error text for both surfaces).
        let frameIndices = try frames.map { spec -> Set<Int> in
            do { return try SplitConsole.parseFrameSelection(spec) }
            catch let e as SplitConsole.FrameSelectionError { throw ValidationError(e.description) }
        }

        // Process files
        var isDirectory: ObjCBool = false
        let result: SplitResult
        if FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory), isDirectory.boolValue {
            // Directory processing
            result = try await splitter.processDirectory(input, recursive: recursive, frameIndices: frameIndices)
        } else {
            // Single file processing
            var single = SplitResult()
            await splitter.processFile(input, frameIndices: frameIndices, into: &single)
            result = single
        }

        for line in SplitConsole.completionLines(result: result) { fprintln(line) }

        // Surface real extraction failures through the exit code so scripts can detect
        // them. Skips (non-DICOM or single-frame files) are not failures and keep exit 0.
        if result.failed > 0 {
            throw ExitCode.failure
        }
    }
    
    func createOutputDirectory(_ path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw ValidationError(SplitConsole.outputNotDirectoryMessage(path: path))
            }
        } else {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
}

// FrameSplitter + SplitError + SplitResult + SplitOutputFormat now live in the
// DICOMKit library (Sources/DICOMKit/Splitting/). ArgumentParser stays out of the
// library, so the CLI supplies the command-line conformance here.
extension SplitOutputFormat: ExpressibleByArgument {}
extension SplitTargetPolicy: ExpressibleByArgument {}
extension MultiframePixelHandling: ExpressibleByArgument {}
extension PrivateFunctionalGroupPolicy: ExpressibleByArgument {}
extension SplitInstanceNumbering: ExpressibleByArgument {}
extension SplitSeriesGrouping: ExpressibleByArgument {}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
