import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@main
struct DICOMConvert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-convert",
        abstract: "Convert DICOM files between transfer syntaxes and export to image formats",
        discussion: """
            Convert DICOM files to different transfer syntaxes or export pixel data to PNG, JPEG, or TIFF.
            Supports both single file and batch directory conversion.
            
            Examples:
              dicom-convert file.dcm --output output.dcm --transfer-syntax ExplicitVRLittleEndian
              dicom-convert ct.dcm --output ct.png --apply-window --window-center 40 --window-width 400
              dicom-convert input/ --output output/ --transfer-syntax ExplicitVRLittleEndian --recursive
              dicom-convert xray.dcm --output xray.jpg --format jpeg --quality 95
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "Path to DICOM file or directory")
    var inputPath: String
    
    @Option(name: .shortAndLong, help: "Output file or directory path")
    var output: String
    
    @Option(name: .long, help: "\(DICOMConverter.transferSyntaxOptionHelp)")
    var transferSyntax: String?
    
    @Option(name: .long, help: "Output format for image export: png, jpeg, tiff, dicom (default: dicom)")
    var format: ExportFormat = .dicom
    
    @Option(name: .long, help: "JPEG quality (1-100, default: 90)")
    var quality: Int = 90
    
    @Flag(name: .long, help: "Apply window/level during export")
    var applyWindow: Bool = false
    
    @Option(name: .long, help: "Window center value")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width value")
    var windowWidth: Double?
    
    @Option(name: .long, help: "Export specific frame number (0-indexed)")
    var frame: Int?
    
    @Flag(name: .long, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Strip private tags during conversion")
    var stripPrivate: Bool = false
    
    @Flag(name: .long, help: "Validate output after conversion")
    var validate: Bool = false
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    mutating func run() async throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: output)
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
            throw ValidationError("Input path not found: \(inputPath)")
        }
        
        if isDirectory.boolValue {
            try convertDirectory(input: inputURL, output: outputURL)
        } else {
            try convertFile(input: inputURL, output: outputURL)
        }
    }
    
    private func convertDirectory(input: URL, output: URL) throws {
        guard recursive else {
            throw ValidationError("Directory conversion requires --recursive flag")
        }
        
        // Create output directory if needed
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        
        let enumerator = FileManager.default.enumerator(
            at: input,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        guard let enumerator = enumerator else {
            throw ValidationError("Failed to enumerate directory: \(input.path)")
        }
        
        var fileCount = 0
        var successCount = 0
        var errorCount = 0
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            
            fileCount += 1
            
            // Calculate relative path
            let relativePath = fileURL.path.replacingOccurrences(of: input.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            let outputFileURL = output.appendingPathComponent(relativePath)
            
            // Create intermediate directories
            let outputDir = outputFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            
            do {
                try convertFile(input: fileURL, output: outputFileURL)
                successCount += 1
                print("✓ \(relativePath)")
            } catch {
                errorCount += 1
                print("✗ \(relativePath): \(error.localizedDescription)")
            }
        }
        
        print("\nConversion complete: \(successCount)/\(fileCount) succeeded, \(errorCount) failed")
    }
    
    private func convertFile(input: URL, output: URL) throws {
        let fileData = try Data(contentsOf: input)
        
        // Read DICOM file
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        
        // Process based on output format
        switch format {
        case .dicom:
            try convertTransferSyntax(dicomFile: dicomFile, output: output)
        case .png, .jpeg, .tiff:
            try exportImage(dicomFile: dicomFile, output: output)
        }
        
        // Validate if requested
        if validate && format == .dicom {
            let outputData = try Data(contentsOf: output)
            _ = try DICOMFile.read(from: outputData, force: false)
        }
    }
    
    private func convertTransferSyntax(dicomFile: DICOMFile, output: URL) throws {
        guard let transferSyntaxName = transferSyntax else {
            throw ValidationError("--transfer-syntax required for DICOM output")
        }

        let targetSyntax = try parseTransferSyntax(transferSyntaxName)

        // Shared process → output pipeline (identical bytes in CLI and app).
        let outcome = try DICOMConverter.convertToDICOM(
            dicomFile: dicomFile,
            to: targetSyntax,
            stripPrivate: stripPrivate
        )

        try outcome.data.write(to: output)

        if outcome.wasTranscoded {
            let lossInfo = outcome.isLossless ? "lossless" : "lossy"
            print("Transcoded from \(outcome.sourceSyntax.uid) to \(outcome.targetSyntax.uid) (\(lossInfo))")
        }
    }
    
    private func exportImage(dicomFile: DICOMFile, output: URL) throws {
        #if canImport(CoreGraphics)
        // Extract pixel data
        let pixelData = try dicomFile.tryPixelData()

        let frameIndex = frame ?? 0
        guard frameIndex < pixelData.descriptor.numberOfFrames else {
            throw ConversionError.invalidFrame(frameIndex, pixelData.descriptor.numberOfFrames)
        }

        guard let imageFormat = format.exportImageFormat else {
            throw ConversionError.exportFailed
        }

        // Shared render (incl. window resolution) + shared encode → identical raster in CLI and app.
        let image = try DICOMImageExporter.renderFrameForExport(
            file: dicomFile, pixelData: pixelData, frameIndex: frameIndex,
            applyWindow: applyWindow, windowCenter: windowCenter, windowWidth: windowWidth
        )
        try DICOMImageExporter.exportCGImage(
            image, to: output, format: imageFormat, quality: quality, metadata: nil
        )
        #else
        throw ConversionError.unsupportedPlatform
        #endif
    }

    private func parseTransferSyntax(_ name: String) throws -> TransferSyntax {
        // Single source of truth: the shared DICOMConverter target catalog (DICOMKit).
        guard let syntax = DICOMConverter.parseTarget(name) else {
            throw ValidationError(DICOMConverter.unknownTargetMessage(name))
        }
        return syntax
    }
}

enum ExportFormat: String, ExpressibleByArgument {
    case dicom
    case png
    case jpeg
    case tiff

    /// Maps to the shared image-export format, or `nil` for `.dicom` (handled by the
    /// transfer-syntax path, not the image exporter).
    var exportImageFormat: ExportImageFormat? {
        switch self {
        case .dicom: return nil
        case .png:   return .png
        case .jpeg:  return .jpeg
        case .tiff:  return .tiff
        }
    }
}

enum ConversionError: LocalizedError {
    case noPixelData
    case invalidFrame(Int, Int)
    case renderFailed
    case exportFailed
    case unsupportedPlatform
    
    var errorDescription: String? {
        switch self {
        case .noPixelData:
            return "No pixel data found in DICOM file"
        case .invalidFrame(let requested, let total):
            return "Invalid frame \(requested). File has \(total) frames (0-\(total-1))"
        case .renderFailed:
            return "Failed to render pixel data to image"
        case .exportFailed:
            return "Failed to export image to file"
        case .unsupportedPlatform:
            return "Image export not supported on this platform"
        }
    }
}
