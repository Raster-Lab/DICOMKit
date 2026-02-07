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

// MARK: - Export Image Format

enum ExportImageFormat: String, ExpressibleByArgument, CaseIterable {
    case png
    case jpeg
    case tiff

    var fileExtension: String { rawValue }

    #if canImport(UniformTypeIdentifiers)
    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }
    #endif
}

// MARK: - Organization Scheme

enum OrganizationScheme: String, ExpressibleByArgument, CaseIterable {
    case flat
    case patient
    case study
    case series
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case noPixelData
    case renderFailed
    case exportFailed
    case unsupportedPlatform
    case invalidFrame(Int, Int)
    case noFrames
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .noPixelData:
            return "No pixel data found in DICOM file"
        case .renderFailed:
            return "Failed to render pixel data to image"
        case .exportFailed:
            return "Failed to export image to file"
        case .unsupportedPlatform:
            return "Image export requires macOS or iOS (CoreGraphics)"
        case .invalidFrame(let requested, let total):
            return "Invalid frame \(requested). File has \(total) frames (0-\(total - 1))"
        case .noFrames:
            return "No frames available in DICOM file"
        case .invalidInput(let message):
            return message
        }
    }
}

// MARK: - EXIF Metadata Helpers

/// Maps DICOM field names to EXIF/TIFF dictionary keys
func mapDICOMFieldToEXIF(_ field: String) -> (dictionary: String, key: String)? {
    switch field.lowercased() {
    case "patientname":
        return ("tiff", "ImageDescription")
    case "studydate":
        return ("exif", "DateTimeOriginal")
    case "modality":
        return ("exif", "Software")
    case "studydescription":
        return ("tiff", "DocumentName")
    case "seriesdescription":
        return ("exif", "UserComment")
    case "institutionname":
        return ("tiff", "Artist")
    case "manufacturer":
        return ("tiff", "Make")
    case "manufacturermodelname":
        return ("tiff", "Model")
    case "stationname":
        return ("tiff", "HostComputer")
    default:
        return nil
    }
}

/// Retrieves a DICOM field value from a DICOMFile by field name
func getDICOMFieldValue(_ file: DICOMFile, field: String) -> String? {
    switch field.lowercased() {
    case "patientname":
        return file.dataSet.string(for: .patientName)
    case "patientid":
        return file.dataSet.string(for: .patientID)
    case "studydate":
        return file.dataSet.string(for: .studyDate)
    case "studydescription":
        return file.dataSet.string(for: .studyDescription)
    case "seriesdescription":
        return file.dataSet.string(for: .seriesDescription)
    case "modality":
        return file.dataSet.string(for: .modality)
    case "institutionname":
        return file.dataSet.string(for: .institutionName)
    case "manufacturer":
        return file.dataSet.string(for: .manufacturer)
    case "manufacturermodelname":
        return file.dataSet.string(for: .manufacturerModelName)
    case "stationname":
        return file.dataSet.string(for: .stationName)
    default:
        return nil
    }
}

#if canImport(CoreGraphics)
/// Builds EXIF/TIFF metadata dictionaries from a DICOM file
func buildEXIFMetadata(from file: DICOMFile, fields: [String]?) -> CFDictionary {
    var tiffDict: [String: Any] = [:]
    var exifDict: [String: Any] = [:]

    let fieldsToEmbed: [String]
    if let specified = fields {
        fieldsToEmbed = specified
    } else {
        fieldsToEmbed = ["PatientName", "StudyDate", "Modality",
                         "StudyDescription", "Manufacturer"]
    }

    for field in fieldsToEmbed {
        guard let value = getDICOMFieldValue(file, field: field),
              let mapping = mapDICOMFieldToEXIF(field) else {
            continue
        }
        if mapping.dictionary == "tiff" {
            tiffDict[mapping.key] = value
        } else {
            exifDict[mapping.key] = value
        }
    }

    // Add software tag
    tiffDict["Software"] = "DICOMKit dicom-export v\(exportToolVersion)"

    var properties: [String: Any] = [:]
    if !tiffDict.isEmpty {
        properties[kCGImagePropertyTIFFDictionary as String] = tiffDict
    }
    if !exifDict.isEmpty {
        properties[kCGImagePropertyExifDictionary as String] = exifDict
    }

    return properties as CFDictionary
}
#endif

// MARK: - Contact Sheet Layout

/// Computes contact sheet grid dimensions
func contactSheetLayout(
    imageCount: Int,
    columns: Int,
    thumbnailSize: Int,
    spacing: Int,
    includeLabels: Bool
) -> (rows: Int, totalWidth: Int, totalHeight: Int) {
    let rows = max(1, (imageCount + columns - 1) / columns)
    let labelHeight = includeLabels ? 20 : 0
    let totalWidth = columns * thumbnailSize + (columns + 1) * spacing
    let totalHeight = rows * (thumbnailSize + labelHeight) + (rows + 1) * spacing
    return (rows, totalWidth, totalHeight)
}

/// Returns the position for a thumbnail at a given index in the grid
func thumbnailPosition(
    index: Int,
    columns: Int,
    thumbnailSize: Int,
    spacing: Int,
    includeLabels: Bool
) -> (x: Int, y: Int) {
    let col = index % columns
    let row = index / columns
    let labelHeight = includeLabels ? 20 : 0
    let x = spacing + col * (thumbnailSize + spacing)
    let y = spacing + row * (thumbnailSize + labelHeight + spacing)
    return (x, y)
}

// MARK: - Animation Helpers

/// Computes the GIF frame delay from FPS
func gifFrameDelay(fps: Double) -> Double {
    guard fps > 0 else { return 0.1 }
    return 1.0 / fps
}

/// Validates and clamps frame range
func validatedFrameRange(start: Int, end: Int?, totalFrames: Int) -> (start: Int, end: Int)? {
    guard totalFrames > 0 else { return nil }
    let clampedStart = max(0, min(start, totalFrames - 1))
    let clampedEnd: Int
    if let end = end {
        clampedEnd = max(clampedStart, min(end, totalFrames - 1))
    } else {
        clampedEnd = totalFrames - 1
    }
    return (clampedStart, clampedEnd)
}

// MARK: - Bulk Export Path Helpers

/// Sanitize a string for use as a path component
func sanitizePathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
    var result = ""
    for char in value.unicodeScalars {
        if allowed.contains(char) {
            result.append(Character(char))
        } else {
            result.append("_")
        }
    }
    if result.isEmpty { result = "UNKNOWN" }
    return result
}

/// Builds the output path for a bulk export file based on organization scheme
func buildOrganizedPath(
    baseOutput: String,
    scheme: OrganizationScheme,
    patientName: String?,
    studyUID: String?,
    seriesUID: String?,
    filename: String
) -> String {
    switch scheme {
    case .flat:
        return (baseOutput as NSString).appendingPathComponent(filename)
    case .patient:
        let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
        return (baseOutput as NSString)
            .appendingPathComponent(patient)
            .appending("/\(filename)")
    case .study:
        let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
        let study = sanitizePathComponent(studyUID ?? "UNKNOWN")
        return (baseOutput as NSString)
            .appendingPathComponent(patient)
            .appending("/\(study)/\(filename)")
    case .series:
        let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
        let study = sanitizePathComponent(studyUID ?? "UNKNOWN")
        let series = sanitizePathComponent(seriesUID ?? "UNKNOWN")
        return (baseOutput as NSString)
            .appendingPathComponent(patient)
            .appending("/\(study)/\(series)/\(filename)")
    }
}

// MARK: - Window Settings Helper

func determineWindowSettings(from file: DICOMFile, pixelData: PixelData, frameIndex: Int,
                              windowCenter: Double?, windowWidth: Double?) -> WindowSettings {
    if let center = windowCenter, let width = windowWidth {
        return WindowSettings(center: center, width: width)
    }
    if let windowFromFile = file.windowSettings() {
        return windowFromFile
    }
    if let range = pixelData.pixelRange(forFrame: frameIndex) {
        let center = Double(range.min + range.max) / 2.0
        let width = Double(range.max - range.min)
        return WindowSettings(center: center, width: max(1.0, width))
    }
    let assumedBitDepth = 16
    let maxPixelValue = (1 << assumedBitDepth) - 1
    return WindowSettings(center: Double(maxPixelValue) / 2.0, width: max(1.0, Double(maxPixelValue)))
}

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

            let cgImage: CGImage?
            if applyWindow {
                let window = determineWindowSettings(from: dicomFile, pixelData: pixelData,
                                                      frameIndex: frameIndex,
                                                      windowCenter: windowCenter, windowWidth: windowWidth)
                cgImage = try dicomFile.tryRenderFrame(frameIndex, window: window)
            } else {
                cgImage = try dicomFile.tryRenderFrame(frameIndex)
            }

            guard let image = cgImage else {
                throw ExportError.renderFailed
            }

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
                metadata = buildEXIFMetadata(from: dicomFile, fields: fields)
            }

            try exportCGImage(image, to: outputURL, format: format, quality: quality, metadata: metadata)
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

            let layout = contactSheetLayout(
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
                let pos = thumbnailPosition(
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
            try exportCGImage(sheetImage, to: outputURL, format: format, quality: quality, metadata: nil)
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

            guard let range = validatedFrameRange(start: startFrame, end: endFrame, totalFrames: totalFrames) else {
                throw ExportError.noFrames
            }

            let clampedScale = max(0.1, min(2.0, scale))
            let delay = gifFrameDelay(fps: fps)

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
                    let window = determineWindowSettings(from: dicomFile, pixelData: pd,
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

                    let cgImage: CGImage?
                    if applyWindow {
                        let window = determineWindowSettings(from: dicomFile, pixelData: pixelDataObj,
                                                              frameIndex: 0,
                                                              windowCenter: nil, windowWidth: nil)
                        cgImage = try dicomFile.tryRenderFrame(0, window: window)
                    } else {
                        cgImage = try dicomFile.tryRenderFrame(0)
                    }

                    guard let image = cgImage else {
                        if verbose { print("✗ Render failed: \(fileURL.lastPathComponent)") }
                        errorCount += 1
                        continue
                    }

                    // Build output path
                    let patientName = dicomFile.dataSet.string(for: .patientName)
                    let studyUID = dicomFile.dataSet.string(for: .studyInstanceUID)
                    let seriesUID = dicomFile.dataSet.string(for: .seriesInstanceUID)
                    let baseName = fileURL.deletingPathExtension().lastPathComponent + "." + format.fileExtension

                    let outputPath = buildOrganizedPath(
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
                        metadata = buildEXIFMetadata(from: dicomFile, fields: nil)
                    }

                    try exportCGImage(image, to: outputURL, format: format, quality: quality, metadata: metadata)
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

// MARK: - Image Export Helper

#if canImport(CoreGraphics) && canImport(ImageIO)
func exportCGImage(_ image: CGImage, to url: URL, format: ExportImageFormat,
                   quality: Int, metadata: CFDictionary?) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        format.utType.identifier as CFString,
        1,
        nil
    ) else {
        throw ExportError.exportFailed
    }

    var options: [CFString: Any] = [:]
    if format == .jpeg {
        options[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
    }

    if let metadata = metadata {
        // Merge metadata into options
        if let metaDict = metadata as? [String: Any] {
            for (key, value) in metaDict {
                options[key as CFString] = value
            }
        }
    }

    CGImageDestinationAddImage(destination, image, options as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
        throw ExportError.exportFailed
    }
}
#endif

DICOMExport.main()
