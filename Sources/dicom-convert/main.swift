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
    
    @Option(name: .long, help: "Target transfer syntax: ExplicitVRLittleEndian, ImplicitVRLittleEndian, ExplicitVRBigEndian, DEFLATE")
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
        
        // Create modified dataset
        var newDataSet = dicomFile.dataSet
        
        // Strip private tags if requested
        if stripPrivate {
            let tags = newDataSet.tags.filter { !$0.isPrivate }
            var filteredDataSet = DataSet()
            for tag in tags {
                if let element = newDataSet[tag] {
                    filteredDataSet[tag] = element
                }
            }
            newDataSet = filteredDataSet
        }
        
        // Write DICOM file with new transfer syntax
        let converter = TransferSyntaxConverter()
        let outputData = try converter.convert(
            dataSet: newDataSet,
            to: targetSyntax,
            preservePixelData: true
        )
        
        try outputData.write(to: output)
    }
    
    private func exportImage(dicomFile: DICOMFile, output: URL) throws {
        #if canImport(CoreGraphics)
        // Extract pixel data
        guard let pixelData = try? dicomFile.extractPixelData() else {
            throw ConversionError.noPixelData
        }
        
        let frameIndex = frame ?? 0
        guard frameIndex < pixelData.descriptor.numberOfFrames else {
            throw ConversionError.invalidFrame(frameIndex, pixelData.descriptor.numberOfFrames)
        }
        
        // Render frame
        let cgImage: CGImage?
        if applyWindow {
            let window = determineWindowSettings(from: dicomFile, pixelData: pixelData, frameIndex: frameIndex)
            cgImage = try dicomFile.tryRenderFrame(frameIndex, window: window)
        } else {
            cgImage = try dicomFile.tryRenderFrame(frameIndex)
        }
        
        guard let image = cgImage else {
            throw ConversionError.renderFailed
        }
        
        // Export to appropriate format
        try exportCGImage(image, to: output, format: format)
        #else
        throw ConversionError.unsupportedPlatform
        #endif
    }
    
    #if canImport(CoreGraphics)
    private func exportCGImage(_ image: CGImage, to url: URL, format: ExportFormat) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.exportFailed
        }
        
        var options: [CFString: Any] = [:]
        
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
        }
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.exportFailed
        }
    }
    #endif
    
    private func determineWindowSettings(from file: DICOMFile, pixelData: PixelData, frameIndex: Int) -> WindowSettings {
        // Use command-line specified values if available
        if let center = windowCenter, let width = windowWidth {
            return WindowSettings(center: center, width: width)
        }
        
        // Try to get window from DICOM tags
        if let windowFromFile = file.windowSettings() {
            return windowFromFile
        }
        
        // Calculate from pixel range
        if let range = pixelData.pixelRange(forFrame: frameIndex) {
            let center = Double(range.min + range.max) / 2.0
            let width = Double(range.max - range.min)
            return WindowSettings(center: center, width: max(1.0, width))
        }
        
        // Default fallback window settings when no explicit window or pixel range is available.
        // Assume a conservative 16-bit pixel depth to avoid implicitly restricting to an 8-bit [0, 255] range.
        // This provides a wide window suitable for mapping higher dynamic range data to 8-bit output formats.
        let assumedBitDepth = 16
        let maxPixelValue = (1 << assumedBitDepth) - 1
        let defaultCenter = Double(maxPixelValue) / 2.0
        let defaultWidth = Double(maxPixelValue)
        return WindowSettings(center: defaultCenter, width: max(1.0, defaultWidth))
    }
    
    private func parseTransferSyntax(_ name: String) throws -> TransferSyntax {
        switch name.lowercased() {
        case "explicitvrlittleendian", "explicit", "evle":
            return .explicitVRLittleEndian
        case "implicitvrlittleendian", "implicit", "ivle":
            return .implicitVRLittleEndian
        case "explicitvrbigendian", "evbe":
            return .explicitVRBigEndian
        case "deflate", "deflated":
            return .deflatedExplicitVRLittleEndian
        default:
            throw ValidationError("Unknown transfer syntax: \(name). Use: ExplicitVRLittleEndian, ImplicitVRLittleEndian, ExplicitVRBigEndian, or DEFLATE")
        }
    }
}

enum ExportFormat: String, ExpressibleByArgument {
    case dicom
    case png
    case jpeg
    case tiff
    
    #if canImport(UniformTypeIdentifiers)
    var utType: UTType {
        switch self {
        case .dicom:
            return UTType(filenameExtension: "dcm") ?? .data
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .tiff:
            return .tiff
        }
    }
    #endif
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

await DICOMConvert.main()
