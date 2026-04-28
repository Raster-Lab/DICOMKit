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
    
    @Option(name: .long, help: "Target transfer syntax: ExplicitVRLittleEndian, ImplicitVRLittleEndian, ExplicitVRBigEndian, DEFLATE, JPEGBaseline, JPEGExtended, JPEGLossless, JPEGLosslessSV1, JPEG2000Lossless, JPEG2000, JPEG2000Part2Lossless, JPEG2000Part2, HTJ2KLossless, HTJ2KRPCLLossless, HTJ2K, JPEGLSLossless, JPEGLSNearLossless, RLELossless")
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
        var outputURL = URL(fileURLWithPath: output)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
            throw ValidationError("Input path not found: \(inputPath)")
        }

        // Print conversion header (mirrors DICOMStudio CLI Workshop output so the
        // GUI and terminal experiences are identical).
        print("Input:  \(inputURL.path)")
        print("Output: \(outputURL.path)")
        print("Format: \(format.rawValue)")
        if format == .dicom, let ts = transferSyntax, !ts.isEmpty {
            print("Transfer Syntax: \(ts)")
        }
        print("")

        if isDirectory.boolValue {
            try convertDirectory(input: inputURL, output: outputURL)
        } else {
            // When converting a single file and the output path is (or was chosen
            // as) a directory, write the result *inside* that directory using the
            // input filename. Mirrors the CLI Workshop behaviour so the GUI and
            // terminal produce identical results.
            var outputIsDirectory: ObjCBool = false
            let outputExists = FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &outputIsDirectory)
            let treatAsDir = (outputExists && outputIsDirectory.boolValue)
                || (!outputExists && outputURL.pathExtension.isEmpty)
            if treatAsDir {
                try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                let stem = inputURL.deletingPathExtension().lastPathComponent
                let ext: String
                switch format {
                case .png:  ext = "png"
                case .jpeg: ext = "jpg"
                case .tiff: ext = "tiff"
                case .dicom: ext = "dcm"
                }
                outputURL = outputURL.appendingPathComponent("\(stem).\(ext)")
            } else if !outputExists {
                let parentDir = outputURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            try convertFile(input: inputURL, output: outputURL)
            print("\n✅ Conversion completed successfully.")
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

        let inputSize = fileData.count
        print("  Read \(input.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(inputSize), countStyle: .file)))")

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
            print("  ✓ Output validation passed")
        }
    }
    
    private func convertTransferSyntax(dicomFile: DICOMFile, output: URL) throws {
        guard let transferSyntaxName = transferSyntax else {
            throw ValidationError("--transfer-syntax required for DICOM output")
        }
        
        let targetSyntax = try parseTransferSyntax(transferSyntaxName)
        
        // Determine source transfer syntax from the file
        let sourceSyntaxUID = dicomFile.transferSyntaxUID ?? DICOMCore.TransferSyntax.explicitVRLittleEndian.uid
        let sourceSyntax = DICOMCore.TransferSyntax.from(uid: sourceSyntaxUID) ?? .explicitVRLittleEndian
        
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
        
        // Use the DICOMCore TransferSyntaxConverter for full transcoding (including pixel data)
        // Use lossless compression config for lossless targets, default for lossy
        let compressionConfig: DICOMCore.CompressionConfiguration = targetSyntax.isLossless
            ? .lossless
            : .default
        let coreConverter = DICOMCore.TransferSyntaxConverter(
            configuration: TranscodingConfiguration(
                preferredSyntaxes: [targetSyntax],
                allowLossyCompression: !targetSyntax.isLossless,
                preservePixelDataFidelity: targetSyntax.isLossless
            ),
            compressionConfiguration: compressionConfig
        )
        
        // Serialize the current dataset to bytes in the source transfer syntax
        let sourceWriter = DICOMWriter(
            byteOrder: sourceSyntax.byteOrder,
            explicitVR: sourceSyntax.isExplicitVR
        )
        let dataSetBytes = newDataSet.write(using: sourceWriter)
        
        // Transcode the dataset bytes
        let result = try coreConverter.transcode(
            dataSetData: dataSetBytes,
            from: sourceSyntax,
            to: targetSyntax
        )
        
        // Write the complete DICOM file with proper File Meta Information
        let sopClassUID = newDataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.7"
        let sopInstanceUID = newDataSet.string(for: .sopInstanceUID) ?? UIDGenerator.generateSOPInstanceUID().value
        let outputFile = DICOMFile.create(
            dataSet: newDataSet,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            transferSyntaxUID: targetSyntax.uid
        )
        
        // Build the final output: preamble + DICM + file meta info + transcoded dataset
        var outputData = Data()
        outputData.append(Data(repeating: 0, count: 128))  // Preamble
        outputData.append(contentsOf: "DICM".utf8)          // DICM prefix
        
        // Write File Meta Information (always Explicit VR Little Endian)
        let fmiWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        outputData.append(outputFile.fileMetaInformation.write(using: fmiWriter))
        
        // Append the transcoded dataset bytes
        outputData.append(result.data)
        
        try outputData.write(to: output)

        let lossInfo = result.isLossless ? "lossless" : "lossy"
        print("  Wrote \(output.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(outputData.count), countStyle: .file)))")
        print("  Transfer Syntax: \(targetSyntax.uid) (\(lossInfo))")
        if result.wasTranscoded {
            print("  Transcoded from \(sourceSyntax.uid)")
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
        // Uncompressed
        case "explicitvrlittleendian", "explicit", "evle":
            return .explicitVRLittleEndian
        case "implicitvrlittleendian", "implicit", "ivle":
            return .implicitVRLittleEndian
        case "explicitvrbigendian", "evbe":
            return .explicitVRBigEndian
        case "deflate", "deflated":
            return .deflatedExplicitVRLittleEndian
        // JPEG
        case "jpegbaseline", "jpeg-baseline", "jpeg":
            return .jpegBaseline
        case "jpegextended", "jpeg-extended":
            return .jpegExtended
        case "jpeglossless", "jpeg-lossless":
            return .jpegLossless
        case "jpeglosslesssv1", "jpeg-lossless-sv1":
            return .jpegLosslessSV1
        // JPEG 2000
        case "jpeg2000lossless", "jpeg2000-lossless", "j2k-lossless":
            return .jpeg2000Lossless
        case "jpeg2000", "jpeg2000-lossy", "j2k":
            return .jpeg2000
        case "jpeg2000part2lossless", "jpeg2000-part2-lossless", "j2k-part2-lossless":
            return .jpeg2000Part2Lossless
        case "jpeg2000part2", "jpeg2000-part2", "j2k-part2":
            return .jpeg2000Part2
        case "htj2klossless", "htj2k-lossless":
            return .htj2kLossless
        case "htj2krpcllossless", "htj2k-rpcl", "htj2k-lossless-rpcl":
            return .htj2kRPCLLossless
        case "htj2k", "htj2k-lossy":
            return .htj2kLossy
        // JPEG-LS
        case "jpeglslossless", "jpeg-ls-lossless", "jpegls":
            return .jpegLSLossless
        case "jpeglsnearlossless", "jpeg-ls-near-lossless", "jpegls-near":
            return .jpegLSNearLossless
        // RLE
        case "rlelossless", "rle-lossless", "rle":
            return .rleLossless
        default:
            throw ValidationError("""
                Unknown transfer syntax: \(name).
                Available syntaxes:
                  Uncompressed: ExplicitVRLittleEndian, ImplicitVRLittleEndian, ExplicitVRBigEndian, DEFLATE
                  JPEG:         JPEGBaseline, JPEGExtended, JPEGLossless, JPEGLosslessSV1
                  JPEG 2000:    JPEG2000Lossless, JPEG2000, JPEG2000Part2Lossless, JPEG2000Part2, HTJ2KLossless, HTJ2KRPCLLossless, HTJ2K
                  JPEG-LS:      JPEGLSLossless, JPEGLSNearLossless
                  RLE:          RLELossless
                """)
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
