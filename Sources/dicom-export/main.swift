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

// MARK: - Version

let exportToolVersion = "1.2.2"

// ExportImageFormat / OrganizationScheme / ExportError and the export helpers now
// live in DICOMKit (DICOMImageExporter). Add the CLI-only ArgumentParser
// conformance here — both enums are RawRepresentable<String>, so the default
// ExpressibleByArgument implementation applies.
extension ExportImageFormat: ExpressibleByArgument {}
extension OrganizationScheme: ExpressibleByArgument {}

// MARK: - Main Command

struct DICOMExport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-export",
        abstract: "Advanced DICOM image export with metadata embedding, contact sheets, animation, and bulk export",
        discussion: """
            Export DICOM images to standard formats with advanced features including
            EXIF metadata embedding, contact sheet generation, animated GIF export,
            and bulk directory export with organization.

            Examples:
              dicom-export single ct.dcm --output ct.jpg --embed-metadata
              dicom-export contact-sheet *.dcm --output sheet.png --columns 6
              dicom-export animate cine.dcm --output cine.gif --fps 15
              dicom-export bulk input/ --output output/ --organize-by patient
            """,
        version: exportToolVersion,
        subcommands: [Single.self, ContactSheet.self, Animate.self, Bulk.self]
    )
}

// MARK: - Single Export

extension DICOMExport {
    struct Single: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "single",
            abstract: "Export a single DICOM file to an image"
        )

        @Argument(help: "Path to DICOM file")
        var input: String

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String?

        @Option(name: .long, help: "Output format: png, jpeg, tiff")
        var format: ExportImageFormat = .jpeg

        @Option(name: .long, help: "JPEG quality (1-100)")
        var quality: Int = 90

        @Flag(name: .long, help: "Embed DICOM metadata as EXIF/TIFF tags")
        var embedMetadata: Bool = false

        @Option(name: .long, help: "Comma-separated DICOM fields to embed (e.g., PatientName,StudyDate,Modality)")
        var exifFields: String?

        @Flag(name: .long, help: "Apply windowing")
        var applyWindow: Bool = false

        @Option(name: .long, help: "Window center value")
        var windowCenter: Double?

        @Option(name: .long, help: "Window width value")
        var windowWidth: Double?

        @Option(name: .long, help: "Frame number to export (0-indexed)")
        var frame: Int?

        mutating func run() throws {
            #if canImport(CoreGraphics) && canImport(ImageIO)
            let inputURL = URL(fileURLWithPath: input)
            guard FileManager.default.fileExists(atPath: input) else {
                throw ExportError.invalidInput("Input file not found: \(input)")
            }

            let fileData = try Data(contentsOf: inputURL)
            let dicomFile = try DICOMFile.read(from: fileData)

            guard let pixelData = dicomFile.pixelData() else {
                throw ExportError.noPixelData
            }

            let frameIndex = frame ?? 0
            let totalFrames = pixelData.descriptor.numberOfFrames
            guard frameIndex >= 0 && frameIndex < totalFrames else {
                throw ExportError.invalidFrame(frameIndex, totalFrames)
            }

            let image = try DICOMImageExporter.renderFrameForExport(
                file: dicomFile, pixelData: pixelData, frameIndex: frameIndex,
                applyWindow: applyWindow, windowCenter: windowCenter, windowWidth: windowWidth
            )

            // Determine output path
            let outputPath: String
            if let out = output {
                outputPath = out
            } else {
                let baseName = inputURL.deletingPathExtension().lastPathComponent
                outputPath = baseName + "." + format.fileExtension
            }
            let outputURL = URL(fileURLWithPath: outputPath)

            // Build metadata if requested
            var metadata: CFDictionary? = nil
            if embedMetadata {
                let fields = exifFields?.split(separator: ",").map(String.init)
                metadata = DICOMImageExporter.buildEXIFMetadata(from: dicomFile, fields: fields)
            }

            try DICOMImageExporter.exportCGImage(image, to: outputURL, format: format, quality: quality, metadata: metadata)
            print("Exported: \(outputPath)")
            #else
            throw ExportError.unsupportedPlatform
            #endif
        }
    }
}

// MARK: - Contact Sheet

extension DICOMExport {
    struct ContactSheet: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "contact-sheet",
            abstract: "Generate a contact sheet from multiple DICOM files"
        )

        @Argument(help: "Paths to DICOM files")
        var inputs: [String]

        @Option(name: .shortAndLong, help: "Output file path")
        var output: String

        @Option(name: .long, help: "Number of columns")
        var columns: Int = 4

        @Option(name: .long, help: "Thumbnail size in pixels")
        var thumbnailSize: Int = 256

        @Option(name: .long, help: "Spacing between thumbnails in pixels")
        var spacing: Int = 4

        @Option(name: .long, help: "Output format: png, jpeg")
        var format: ExportImageFormat = .png

        @Option(name: .long, help: "JPEG quality (1-100)")
        var quality: Int = 90

        @Flag(name: .long, help: "Apply windowing")
        var applyWindow: Bool = false

        @Flag(name: .long, help: "Add filename labels below thumbnails")
        var labels: Bool = false

        mutating func run() throws {
            #if canImport(CoreGraphics) && canImport(ImageIO)
            guard !inputs.isEmpty else {
                throw ExportError.invalidInput("No input files specified")
            }

            let layout = DICOMImageExporter.contactSheetLayout(
                imageCount: inputs.count,
                columns: columns,
                thumbnailSize: thumbnailSize,
                spacing: spacing,
                includeLabels: labels
            )

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: layout.totalWidth,
                height: layout.totalHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ExportError.exportFailed
            }

            // Fill background with black
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: layout.totalWidth, height: layout.totalHeight))

            for (index, inputPath) in inputs.enumerated() {
                let pos = DICOMImageExporter.thumbnailPosition(
                    index: index,
                    columns: columns,
                    thumbnailSize: thumbnailSize,
                    spacing: spacing,
                    includeLabels: labels
                )

                do {
                    let fileData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
                    let dicomFile = try DICOMFile.read(from: fileData)

                    var cgImage: CGImage?
                    if applyWindow {
                        cgImage = try dicomFile.tryRenderFrameWithStoredWindow(0)
                    } else {
                        cgImage = try dicomFile.tryRenderFrame(0)
                    }

                    if let image = cgImage {
                        // CGContext origin is bottom-left, flip y
                        let flippedY = layout.totalHeight - pos.y - thumbnailSize
                        let rect = CGRect(x: pos.x, y: flippedY, width: thumbnailSize, height: thumbnailSize)
                        context.draw(image, in: rect)
                    }
                } catch {
                    // Draw placeholder for failed files
                    let flippedY = layout.totalHeight - pos.y - thumbnailSize
                    context.setFillColor(CGColor(red: 0.2, green: 0, blue: 0, alpha: 1))
                    context.fill(CGRect(x: pos.x, y: flippedY, width: thumbnailSize, height: thumbnailSize))
                }
            }

            guard let sheetImage = context.makeImage() else {
                throw ExportError.renderFailed
            }

            let outputURL = URL(fileURLWithPath: output)
            try DICOMImageExporter.exportCGImage(sheetImage, to: outputURL, format: format, quality: quality, metadata: nil)
            print("Contact sheet exported: \(output) (\(inputs.count) images, \(columns)x\(layout.rows) grid)")
            #else
            throw ExportError.unsupportedPlatform
            #endif
        }
    }
}

// MARK: - Animate

extension DICOMExport {
    struct Animate: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "animate",
            abstract: "Export multi-frame DICOM as animated GIF"
        )

        @Argument(help: "Path to multi-frame DICOM file")
        var input: String

        @Option(name: .shortAndLong, help: "Output GIF file path")
        var output: String

        @Option(name: .long, help: "Frames per second")
        var fps: Double = 10

        @Option(name: .long, help: "Number of loops (0 = infinite)")
        var loopCount: Int = 0

        @Flag(name: .long, help: "Apply windowing")
        var applyWindow: Bool = false

        @Option(name: .long, help: "Window center value")
        var windowCenter: Double?

        @Option(name: .long, help: "Window width value")
        var windowWidth: Double?

        @Option(name: .long, help: "Start frame (0-indexed)")
        var startFrame: Int = 0

        @Option(name: .long, help: "End frame (default: last frame)")
        var endFrame: Int?

        @Option(name: .long, help: "Scale factor (0.1-2.0)")
        var scale: Double = 1.0

        mutating func run() throws {
            #if canImport(CoreGraphics) && canImport(ImageIO)
            let inputURL = URL(fileURLWithPath: input)
            guard FileManager.default.fileExists(atPath: input) else {
                throw ExportError.invalidInput("Input file not found: \(input)")
            }

            let fileData = try Data(contentsOf: inputURL)
            let dicomFile = try DICOMFile.read(from: fileData)

            let totalFrames = dicomFile.numberOfFrames ?? 1
            guard totalFrames > 0 else {
                throw ExportError.noFrames
            }

            guard let range = DICOMImageExporter.validatedFrameRange(start: startFrame, end: endFrame, totalFrames: totalFrames) else {
                throw ExportError.noFrames
            }

            let clampedScale = max(0.1, min(2.0, scale))
            let delay = DICOMImageExporter.gifFrameDelay(fps: fps)

            let outputURL = URL(fileURLWithPath: output)
            let frameCount = range.end - range.start + 1

            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                "com.compuserve.gif" as CFString,
                frameCount,
                nil
            ) else {
                throw ExportError.exportFailed
            }

            // Set GIF file properties (loop count)
            let gifFileProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: loopCount
                ]
            ]
            CGImageDestinationSetProperties(destination, gifFileProperties as CFDictionary)

            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: delay
                ]
            ]

            let pixelData = dicomFile.pixelData()

            for frameIndex in range.start...range.end {
                let cgImage: CGImage?
                if applyWindow, let pd = pixelData {
                    let window = DICOMImageExporter.determineWindowSettings(from: dicomFile, pixelData: pd,
                                                          frameIndex: frameIndex,
                                                          windowCenter: windowCenter, windowWidth: windowWidth)
                    cgImage = try dicomFile.tryRenderFrame(frameIndex, window: window)
                } else {
                    cgImage = try dicomFile.tryRenderFrame(frameIndex)
                }

                guard var image = cgImage else {
                    throw ExportError.renderFailed
                }

                // Apply scaling if needed
                if clampedScale != 1.0 {
                    let newWidth = Int(Double(image.width) * clampedScale)
                    let newHeight = Int(Double(image.height) * clampedScale)
                    if newWidth > 0 && newHeight > 0,
                       let colorSpace = image.colorSpace,
                       let ctx = CGContext(
                           data: nil,
                           width: newWidth,
                           height: newHeight,
                           bitsPerComponent: 8,
                           bytesPerRow: 0,
                           space: colorSpace,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                       ) {
                        ctx.interpolationQuality = .high
                        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                        if let scaled = ctx.makeImage() {
                            image = scaled
                        }
                    }
                }

                CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            }

            guard CGImageDestinationFinalize(destination) else {
                throw ExportError.exportFailed
            }

            print("Animated GIF exported: \(output) (\(frameCount) frames, \(fps) fps)")
            #else
            throw ExportError.unsupportedPlatform
            #endif
        }
    }
}

// MARK: - Bulk Export

extension DICOMExport {
    struct Bulk: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "bulk",
            abstract: "Bulk export DICOM files with directory organization"
        )

        @Argument(help: "Input directory path")
        var input: String

        @Option(name: .shortAndLong, help: "Output directory path")
        var output: String

        @Option(name: .long, help: "Output format: png, jpeg, tiff")
        var format: ExportImageFormat = .png

        @Option(name: .long, help: "JPEG quality (1-100)")
        var quality: Int = 90

        @Option(name: .long, help: "Organization: flat, patient, study, series")
        var organizeBy: OrganizationScheme = .flat

        @Flag(name: .long, help: "Process directories recursively")
        var recursive: Bool = false

        @Flag(name: .long, help: "Apply windowing")
        var applyWindow: Bool = false

        @Flag(name: .long, help: "Embed DICOM metadata as EXIF")
        var embedMetadata: Bool = false

        @Flag(name: .long, help: "Verbose output")
        var verbose: Bool = false

        mutating func run() throws {
            #if canImport(CoreGraphics) && canImport(ImageIO)
            let inputURL = URL(fileURLWithPath: input)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw ExportError.invalidInput("Input must be a directory: \(input)")
            }

            // Create output directory
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: output),
                withIntermediateDirectories: true
            )

            // Enumerate files
            let enumerator: FileManager.DirectoryEnumerator?
            if recursive {
                enumerator = FileManager.default.enumerator(
                    at: inputURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            } else {
                enumerator = FileManager.default.enumerator(
                    at: inputURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
            }

            guard let dirEnum = enumerator else {
                throw ExportError.invalidInput("Failed to enumerate directory: \(input)")
            }

            var fileCount = 0
            var successCount = 0
            var errorCount = 0

            for case let fileURL as URL in dirEnum {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }

                fileCount += 1

                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let dicomFile = try DICOMFile.read(from: fileData)

                    guard let pixelDataObj = dicomFile.pixelData() else {
                        if verbose {
                            print("⚠ Skipping (no pixel data): \(fileURL.lastPathComponent)")
                        }
                        continue
                    }

                    let image = try DICOMImageExporter.renderFrameForExport(
                        file: dicomFile, pixelData: pixelDataObj, frameIndex: 0,
                        applyWindow: applyWindow, windowCenter: nil, windowWidth: nil
                    )

                    // Build output path
                    let patientName = dicomFile.dataSet.string(for: .patientName)
                    let studyUID = dicomFile.dataSet.string(for: .studyInstanceUID)
                    let seriesUID = dicomFile.dataSet.string(for: .seriesInstanceUID)
                    let baseName = fileURL.deletingPathExtension().lastPathComponent + "." + format.fileExtension

                    let outputPath = DICOMImageExporter.buildOrganizedPath(
                        baseOutput: output,
                        scheme: organizeBy,
                        patientName: patientName,
                        studyUID: studyUID,
                        seriesUID: seriesUID,
                        filename: baseName
                    )

                    let outputURL = URL(fileURLWithPath: outputPath)
                    try FileManager.default.createDirectory(
                        at: outputURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )

                    var metadata: CFDictionary? = nil
                    if embedMetadata {
                        metadata = DICOMImageExporter.buildEXIFMetadata(from: dicomFile, fields: nil)
                    }

                    try DICOMImageExporter.exportCGImage(image, to: outputURL, format: format, quality: quality, metadata: metadata)
                    successCount += 1
                    if verbose { print("✓ \(outputPath)") }
                } catch {
                    errorCount += 1
                    if verbose { print("✗ \(fileURL.lastPathComponent): \(error.localizedDescription)") }
                }
            }

            print("Bulk export complete: \(successCount)/\(fileCount) succeeded, \(errorCount) failed")
            #else
            throw ExportError.unsupportedPlatform
            #endif
        }
    }
}


DICOMExport.main()
