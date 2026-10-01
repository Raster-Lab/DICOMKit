// NEMA-verified: 2026a, checked 2026-10-01 — option help names the PS3.6 2026a attributes it reads (Window Center (0028,1050), Window Width (0028,1051), VOI LUT Function (0028,1056), VOI LUT Sequence (0028,3010), Patient's Name (0010,0010), Study / Series Instance UID, the 9 --exif-fields keywords, all match Table 6-1); frames are 0-based indexes (frame number - 1, PS3.3 C.7.6.5.1.1 numbers the first Frame 1); PNG/JPEG/TIFF/GIF outputs are non-DICOM plumbing; every subcommand renders through ExportFrames (PS3.4 N.2 chain)
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

            Monochrome frames are rendered through the PS3.4 grayscale chain: Modality LUT
            (Rescale Slope/Intercept), then the file's VOI (Window Center (0028,1050) and
            Window Width (0028,1051) with VOI LUT Function (0028,1056), else VOI LUT Sequence
            (0028,3010), else the full pixel range), then INVERSE for MONOCHROME1. Frames are
            0-based indexes (DICOM frame number - 1). Files with Burned In Annotation
            (0028,0301) YES get a warning on stderr. The outputs (PNG, JPEG, TIFF, GIF) are
            not DICOM files.

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

        @Option(name: .long, help: "Comma-separated PS3.6 keywords to embed: PatientName, StudyDate, Modality, StudyDescription, SeriesDescription, InstitutionName, Manufacturer, ManufacturerModelName, StationName (default: PatientName,StudyDate,Modality,StudyDescription,Manufacturer)")
        var exifFields: String?

        @Flag(name: .long, help: ArgumentHelp(stringLiteral: "Use --window-center/--window-width (LINEAR, PS3.3 C.11.2.1.2.1). Without it the file's VOI is applied: Window Center (0028,1050) and Window Width (0028,1051), else VOI LUT Sequence (0028,3010), else the full pixel range"))
        var applyWindow: Bool = false

        @Option(name: .long, help: "Window Center (0028,1050) in modality units (after Rescale Slope/Intercept); needs --apply-window and --window-width")
        var windowCenter: Double?

        @Option(name: .long, help: "Window Width (0028,1051) in modality units, >= 1; needs --apply-window and --window-center")
        var windowWidth: Double?

        @Option(name: .long, help: "Frame to export as a 0-based index (DICOM frame number - 1; PS3.3 numbers the first frame 1). Default: 0")
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
            if BurnedInAnnotation.isYes(dicomFile.dataSet) {
                BurnedInAnnotation.printWarning(BurnedInAnnotation.warning(for: input))
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
            print(ExportConsole.exportedLine(path: outputPath))
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

        @Flag(name: .long, help: ArgumentHelp(stringLiteral: "No effect, kept for compatibility: the file's VOI (Window Center (0028,1050) and Window Width (0028,1051), else VOI LUT Sequence (0028,3010), else the full pixel range) is always applied"))
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

            var burnedIn = 0
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

                    // Same render as `single` (the PS3.4 N.2 chain with the file's VOI in
                    // modality units); the old stored-window path applied a Window Center
                    // in HU to stored values (wrong whenever Rescale Intercept != 0).
                    let image = try ExportFrames.render(
                        file: dicomFile, frameIndex: 0,
                        applyWindow: false, windowCenter: nil, windowWidth: nil)
                    if BurnedInAnnotation.isYes(dicomFile.dataSet) { burnedIn += 1 }

                    // CGContext origin is bottom-left, flip y
                    let flippedY = layout.totalHeight - pos.y - thumbnailSize
                    let rect = CGRect(x: pos.x, y: flippedY, width: thumbnailSize, height: thumbnailSize)
                    context.draw(image, in: rect)
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
            print(ExportConsole.contactSheetLine(path: output, imageCount: inputs.count, columns: columns, rows: layout.rows))
            if burnedIn > 0 { BurnedInAnnotation.printWarning(BurnedInAnnotation.summaryWarning(count: burnedIn)) }
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

        @Option(name: .long, help: "Frames per second. Default: the file's Recommended Display Frame Rate (0008,2144), else Cine Rate (0018,0040), else 1000 / Frame Time (0018,1063) (msec), else 10")
        var fps: Double?

        @Option(name: .long, help: "Number of loops (0 = infinite)")
        var loopCount: Int = 0

        @Flag(name: .long, help: ArgumentHelp(stringLiteral: "Use --window-center/--window-width (LINEAR, PS3.3 C.11.2.1.2.1). Without it the file's VOI is applied: Window Center (0028,1050) and Window Width (0028,1051), else VOI LUT Sequence (0028,3010), else the full pixel range"))
        var applyWindow: Bool = false

        @Option(name: .long, help: "Window Center (0028,1050) in modality units (after Rescale Slope/Intercept); needs --apply-window and --window-width")
        var windowCenter: Double?

        @Option(name: .long, help: "Window Width (0028,1051) in modality units, >= 1; needs --apply-window and --window-center")
        var windowWidth: Double?

        @Option(name: .long, help: "First frame, 0-based index (DICOM frame number - 1)")
        var startFrame: Int = 0

        @Option(name: .long, help: "Last frame, 0-based index, inclusive (default: last frame)")
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
            let rate = CineFrameRate.resolve(explicit: fps, dataSet: dicomFile.dataSet)
            let delay = DICOMImageExporter.gifFrameDelay(fps: rate.fps)
            if BurnedInAnnotation.isYes(dicomFile.dataSet) {
                BurnedInAnnotation.printWarning(BurnedInAnnotation.warning(for: input))
            }

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

            guard let pixelData = dicomFile.pixelData() else {
                throw ExportError.noPixelData
            }

            for frameIndex in range.start...range.end {
                // Same render as `single`: the PS3.4 N.2 chain, window in modality units.
                // The old path applied a stored-unit window (wrong for slope != 1 and for a
                // Modality LUT Sequence) and, without --apply-window, a per-frame auto window.
                var image = try ExportFrames.render(
                    file: dicomFile, pixelData: pixelData, frameIndex: frameIndex,
                    applyWindow: applyWindow, windowCenter: windowCenter, windowWidth: windowWidth)

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

            print(ExportConsole.animatedGIFLine(path: output, frameCount: frameCount, fps: rate.fps))
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

        @Option(name: .long, help: "Folders: flat; patient = Patient's Name (0010,0010); study = patient + Study Instance UID (0020,000D); series = study + Series Instance UID (0020,000E)")
        var organizeBy: OrganizationScheme = .flat

        @Flag(name: .long, help: "Process directories recursively")
        var recursive: Bool = false

        @Flag(name: .long, help: ArgumentHelp(stringLiteral: "No effect, kept for compatibility: the file's VOI (Window Center (0028,1050) and Window Width (0028,1051), else VOI LUT Sequence (0028,3010), else the full pixel range) is always applied"))
        var applyWindow: Bool = false

        @Flag(name: .long, help: "Embed DICOM attributes as EXIF/TIFF tags: PatientName, StudyDate, Modality, StudyDescription, Manufacturer (PS3.6 keywords)")
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

            // Enumerate files via the shared, sorted gatherer (same walk as the Workshop).
            guard let fileURLs = FileGatherer.regularFiles(under: inputURL, recursive: recursive) else {
                throw ExportError.invalidInput("Failed to enumerate directory: \(input)")
            }

            var fileCount = 0
            var successCount = 0
            var errorCount = 0
            var burnedIn = 0

            for fileURL in fileURLs {
                fileCount += 1

                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let dicomFile = try DICOMFile.read(from: fileData)

                    guard let pixelDataObj = dicomFile.pixelData() else {
                        if verbose {
                            print(ExportConsole.bulkSkipLine(fileName: fileURL.lastPathComponent))
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
                    if BurnedInAnnotation.isYes(dicomFile.dataSet) { burnedIn += 1 }
                    if verbose { print(ExportConsole.bulkSuccessLine(path: outputPath)) }
                } catch {
                    errorCount += 1
                    if verbose { print(ExportConsole.bulkFailureLine(fileName: fileURL.lastPathComponent, message: error.localizedDescription)) }
                }
            }

            print(ExportConsole.bulkSummaryLine(success: successCount, total: fileCount, failed: errorCount))
            if burnedIn > 0 { BurnedInAnnotation.printWarning(BurnedInAnnotation.summaryWarning(count: burnedIn)) }
            #else
            throw ExportError.unsupportedPlatform
            #endif
        }
    }
}


DICOMExport.main()
