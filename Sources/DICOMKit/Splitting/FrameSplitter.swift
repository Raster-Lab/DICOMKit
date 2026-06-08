import Foundation
import DICOMCore
import DICOMDictionary

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(ImageIO)
import ImageIO
#endif

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Output format for extracted frames.
public enum SplitOutputFormat: String, Sendable {
    case dicom
    case png
    case jpeg
    case tiff
}

/// Aggregated outcome of a split run (per-frame stats + written file paths) so
/// adapters can render their own summary.
public struct SplitResult: Sendable {
    public var processedFiles = 0
    public var skippedFiles = 0
    public var extracted = 0
    public var failed = 0
    public var writtenPaths: [String] = []

    public init() {}
}

/// Splits multi-frame DICOM files into individual frames (as DICOM or image files).
///
/// Lives in the DICOMKit library so the `dicom-split` CLI and DICOMStudio run the
/// exact same extraction code. Verbose progress flows through the injected `log`
/// closure; per-frame results accumulate into a returned ``SplitResult`` so each
/// adapter formats its own summary.
public struct FrameSplitter {
    public let outputPath: String
    public let format: SplitOutputFormat
    public let applyWindow: Bool
    public let windowCenter: Double?
    public let windowWidth: Double?
    public let namingPattern: String?
    public let verbose: Bool

    private let log: (String) -> Void
    private let fileManager = FileManager.default

    public init(
        outputPath: String,
        format: SplitOutputFormat,
        applyWindow: Bool,
        windowCenter: Double?,
        windowWidth: Double?,
        namingPattern: String?,
        verbose: Bool,
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.outputPath = outputPath
        self.format = format
        self.applyWindow = applyWindow
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.namingPattern = namingPattern
        self.verbose = verbose
        self.log = log
    }

    /// Processes a single DICOM file, accumulating into `result`.
    public func processFile(_ path: String, frameIndices: Set<Int>?, into result: inout SplitResult) async {
        if verbose {
            log("Processing: \(path)")
        }

        // Read DICOM file
        guard let dicomFile = try? DICOMFile.read(from: URL(fileURLWithPath: path)) else {
            log("Warning: Skipping non-DICOM file: \(path)")
            result.skippedFiles += 1
            return
        }

        // Check if multi-frame
        let numberOfFrames = dicomFile.numberOfFrames ?? 1

        if numberOfFrames <= 1 {
            if verbose {
                log("  Single-frame file, skipping")
            }
            result.skippedFiles += 1
            return
        }

        if verbose {
            log("  Found \(numberOfFrames) frames")
        }

        // Determine which frames to extract
        let framesToExtract: [Int]
        if let indices = frameIndices {
            framesToExtract = indices.filter { $0 >= 0 && $0 < numberOfFrames }.sorted()
        } else {
            framesToExtract = Array(0..<numberOfFrames)
        }

        if verbose {
            log("  Extracting \(framesToExtract.count) frames")
        }

        result.processedFiles += 1

        // Extract each frame
        var successCount = 0
        var failureCount = 0

        for frameIndex in framesToExtract {
            do {
                let written = try extractFrame(
                    from: dicomFile,
                    frameIndex: frameIndex,
                    totalFrames: numberOfFrames,
                    originalPath: path
                )
                successCount += 1
                result.extracted += 1
                result.writtenPaths.append(written)
            } catch {
                failureCount += 1
                result.failed += 1
                if verbose {
                    log("  Failed to extract frame \(frameIndex): \(error)")
                }
            }
        }

        if verbose {
            log("  Completed: \(successCount) succeeded, \(failureCount) failed")
        }
    }

    /// Processes a directory of DICOM files, returning the aggregated result.
    public func processDirectory(_ path: String, recursive: Bool, frameIndices: Set<Int>?) async throws -> SplitResult {
        let files = try gatherFiles(from: path, recursive: recursive)

        if verbose {
            log("Found \(files.count) files to process")
            log("")
        }

        var result = SplitResult()
        for file in files {
            await processFile(file, frameIndices: frameIndices, into: &result)
        }
        return result
    }

    /// Extracts a single frame from a multi-frame DICOM file, returning the
    /// output file path.
    @discardableResult
    private func extractFrame(
        from dicomFile: DICOMFile,
        frameIndex: Int,
        totalFrames: Int,
        originalPath: String
    ) throws -> String {
        let filename = generateFilename(
            frameIndex: frameIndex,
            totalFrames: totalFrames,
            originalPath: originalPath,
            dicomFile: dicomFile
        )
        let outputFilePath = (outputPath as NSString).appendingPathComponent(filename)

        switch format {
        case .dicom:
            try extractFrameAsDICOM(
                from: dicomFile,
                frameIndex: frameIndex,
                outputPath: outputFilePath
            )

        case .png, .jpeg, .tiff:
            try extractFrameAsImage(
                from: dicomFile,
                frameIndex: frameIndex,
                outputPath: outputFilePath
            )
        }

        if verbose {
            log("  Extracted frame \(frameIndex) -> \(filename)")
        }

        return outputFilePath
    }

    /// Extracts a frame as a new DICOM file.
    private func extractFrameAsDICOM(
        from dicomFile: DICOMFile,
        frameIndex: Int,
        outputPath: String
    ) throws {
        // Get pixel data
        guard let pixelData = dicomFile.pixelData() else {
            throw SplitError.missingPixelData
        }

        guard let frameData = pixelData.frameData(at: frameIndex) else {
            throw SplitError.frameExtractionFailed(frameIndex: frameIndex)
        }

        // Create new dataset with single frame
        var newDataSet = dicomFile.dataSet

        // Update Number of Frames to 1
        let numberOfFramesData = "1".data(using: String.Encoding.utf8) ?? Data()
        newDataSet[.numberOfFrames] = DataElement(
            tag: .numberOfFrames,
            vr: .IS,
            length: UInt32(numberOfFramesData.count),
            valueData: numberOfFramesData
        )

        // Update SOP Instance UID to make it unique
        let newSOPInstanceUID = UIDGenerator.generateSOPInstanceUID()
        let uidData = newSOPInstanceUID.value.data(using: String.Encoding.utf8) ?? Data()
        newDataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: UInt32(uidData.count),
            valueData: uidData
        )

        // Update pixel data with only this frame
        newDataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: .OW,
            length: UInt32(frameData.count),
            valueData: frameData
        )

        // Create DICOM file with existing file meta information
        let newFile = DICOMFile(
            fileMetaInformation: dicomFile.fileMetaInformation,
            dataSet: newDataSet
        )

        // Write to disk
        let dicomData = try newFile.write()
        try dicomData.write(to: URL(fileURLWithPath: outputPath))
    }

    /// Extracts a frame as an image file (PNG, JPEG, TIFF).
    private func extractFrameAsImage(
        from dicomFile: DICOMFile,
        frameIndex: Int,
        outputPath: String
    ) throws {
        #if canImport(CoreGraphics)
        let image: CGImage?

        if applyWindow, let center = windowCenter, let width = windowWidth {
            // Apply custom window
            let window = WindowSettings(center: center, width: width)
            image = dicomFile.renderFrame(frameIndex, window: window)
        } else if applyWindow {
            // Use stored window
            image = dicomFile.renderFrameWithStoredWindow(frameIndex)
        } else {
            // No windowing
            image = dicomFile.renderFrame(frameIndex)
        }

        guard let cgImage = image else {
            throw SplitError.renderingFailed(frameIndex: frameIndex)
        }

        // Write image to file
        try writeImage(cgImage, to: outputPath, format: format)
        #else
        throw SplitError.imageWriteFailed(path: "Image export not supported on this platform")
        #endif
    }

    #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
    /// Writes a CGImage to disk in the specified format.
    private func writeImage(_ image: CGImage, to path: String, format: SplitOutputFormat) throws {
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw SplitError.imageWriteFailed(path: path)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw SplitError.imageWriteFailed(path: path)
        }
    }
    #endif

    /// Generates output filename based on pattern or defaults.
    private func generateFilename(
        frameIndex: Int,
        totalFrames: Int,
        originalPath: String,
        dicomFile: DICOMFile
    ) -> String {
        let baseName = (originalPath as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "frame"
        let modality = dicomFile.dataSet.string(for: .modality) ?? "XX"
        let seriesNumber = dicomFile.dataSet.string(for: .seriesNumber) ?? "0"

        if let pattern = namingPattern {
            // Use custom pattern
            var filename = pattern
            filename = filename.replacingOccurrences(of: "{number}", with: String(format: "%04d", frameIndex))
            filename = filename.replacingOccurrences(of: "{modality}", with: modality)
            filename = filename.replacingOccurrences(of: "{series}", with: seriesNumber)
            return filename
        } else {
            // Default pattern
            let ext = format.fileExtension
            return "\(baseName)_frame_\(String(format: "%04d", frameIndex)).\(ext)"
        }
    }

    /// Gathers DICOM files from a directory.
    private func gatherFiles(from path: String, recursive: Bool) throws -> [String] {
        var files: [String] = []

        if recursive {
            // Recursive directory scan
            guard let enumerator = fileManager.enumerator(atPath: path) else {
                throw SplitError.directoryAccessFailed(path: path)
            }

            for case let item as String in enumerator {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false

                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        } else {
            // Only direct children
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false

                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        }

        return files.sorted()
    }

    /// Checks if a file is a DICOM file.
    private func isDICOMFile(_ path: String) -> Bool {
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

// MARK: - Errors

public enum SplitError: Error, CustomStringConvertible {
    case missingPixelData
    case frameExtractionFailed(frameIndex: Int)
    case renderingFailed(frameIndex: Int)
    case imageWriteFailed(path: String)
    case directoryAccessFailed(path: String)

    public var description: String {
        switch self {
        case .missingPixelData:
            return "Missing pixel data in DICOM file"
        case .frameExtractionFailed(let frameIndex):
            return "Failed to extract frame \(frameIndex)"
        case .renderingFailed(let frameIndex):
            return "Failed to render frame \(frameIndex) as image"
        case .imageWriteFailed(let path):
            return "Failed to write image to \(path)"
        case .directoryAccessFailed(let path):
            return "Failed to access directory: \(path)"
        }
    }
}

// MARK: - Output Format Extensions

extension SplitOutputFormat {
    var fileExtension: String {
        switch self {
        case .dicom:
            return "dcm"
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        case .tiff:
            return "tiff"
        }
    }

    #if canImport(UniformTypeIdentifiers)
    var utType: UTType {
        switch self {
        case .dicom:
            return .data
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
