import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

// The image→Secondary-Capture conversion engine now lives in the DICOMKit library
// (Sources/DICOMKit/SecondaryCapture/ImageConverter.swift) so the CLI and
// DICOMStudio run the same code. This CLI handles argument parsing, file/directory
// orchestration, output paths, and summaries; ImageConverter does the per-image
// pixel extraction, EXIF mapping, and Secondary Capture assembly.

struct DICOMImage: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-image",
        abstract: "Convert standard images to DICOM Secondary Capture format",
        discussion: """
            Convert JPEG, PNG, TIFF, and other image formats to DICOM Secondary Capture SOP Class.
            Supports EXIF metadata extraction and batch conversion.

            Supported formats: JPEG, PNG, TIFF, BMP, GIF (depends on platform support)

            Examples:
              # Convert JPEG to DICOM
              dicom-image photo.jpg --output capture.dcm \\
                --patient-name "DOE^JOHN" \\
                --patient-id "12345"

              # Convert with EXIF metadata
              dicom-image photo.jpg --output capture.dcm \\
                --patient-name "SMITH^JANE" \\
                --patient-id "54321" \\
                --use-exif \\
                --study-description "Clinical Photography"

              # Batch convert images
              dicom-image photos/ --output dicoms/ --recursive \\
                --patient-name "BATCH^PATIENT" \\
                --patient-id "BATCH001" \\
                --series-description "Clinical Photos"

              # Convert multi-page TIFF
              dicom-image multipage.tiff --output frames/ \\
                --split-pages \\
                --patient-name "TEST^PATIENT" \\
                --patient-id "99999"
            """,
        version: "1.1.6"
    )

    @Argument(help: "Input image file or directory")
    var input: String

    @Option(name: .shortAndLong, help: "Output file or directory path")
    var output: String?

    @Option(name: .long, help: "Patient Name (DICOM PN format, e.g., 'DOE^JOHN')")
    var patientName: String?

    @Option(name: .long, help: "Patient ID")
    var patientId: String?

    @Option(name: .long, help: "Study Description")
    var studyDescription: String?

    @Option(name: .long, help: "Series Description")
    var seriesDescription: String?

    @Option(name: .long, help: "Study Instance UID (auto-generated if not provided)")
    var studyUid: String?

    @Option(name: .long, help: "Series Instance UID (auto-generated if not provided)")
    var seriesUid: String?

    @Option(name: .long, help: "Series Number")
    var seriesNumber: Int?

    @Option(name: .long, help: "Instance Number (starting value for batch)")
    var instanceNumber: Int?

    @Option(name: .long, help: "Modality (default: OT - Other)")
    var modality: String?

    @Flag(name: .long, help: "Use EXIF metadata from images")
    var useExif: Bool = false

    @Flag(name: .long, help: "Split multi-page TIFF into separate DICOM files")
    var splitPages: Bool = false

    @Flag(name: .long, help: "Process directories recursively")
    var recursive: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    mutating func run() throws {
        #if canImport(CoreGraphics)
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("Input path not found: \(input)")
        }

        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            guard recursive else {
                throw ValidationError("Directory processing requires --recursive flag")
            }
            try convertDirectory(inputPath: input, outputPath: output)
        } else {
            try convertFile(inputPath: input, outputPath: output)
        }
        #else
        throw ValidationError("Image conversion not supported on this platform")
        #endif
    }

    #if canImport(CoreGraphics)
    private func metadata(studyUID: String, seriesUID: String, instanceNumber: Int,
                          patientName: String, patientID: String) -> ImageConverter.Metadata {
        ImageConverter.Metadata(
            patientName: patientName, patientID: patientID,
            studyUID: studyUID, seriesUID: seriesUID, instanceNumber: instanceNumber,
            studyDescription: studyDescription, seriesDescription: seriesDescription,
            modality: modality ?? "OT", seriesNumber: seriesNumber)
    }

    // MARK: - Directory Processing

    private func convertDirectory(inputPath: String, outputPath: String?) throws {
        let inputURL = URL(fileURLWithPath: inputPath)

        let outputDirURL: URL
        if let specifiedOutput = outputPath {
            outputDirURL = URL(fileURLWithPath: specifiedOutput)
        } else {
            outputDirURL = inputURL.appendingPathComponent("dicom")
        }

        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)

        if verbose {
            print("Converting images from: \(inputPath)")
            print("Output directory: \(outputDirURL.path)")
            print()
        }

        guard let patientName = patientName, !patientName.isEmpty else {
            throw ValidationError("Patient Name is required for batch conversion (--patient-name)")
        }
        guard let patientId = patientId, !patientId.isEmpty else {
            throw ValidationError("Patient ID is required for batch conversion (--patient-id)")
        }

        var successCount = 0
        var failureCount = 0
        var instanceNum = instanceNumber ?? 1

        let finalStudyUID = studyUid ?? ImageConverter.generateUID()
        let finalSeriesUID = seriesUid ?? ImageConverter.generateUID()

        let enumerator = FileManager.default.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isRegularFile else {
                continue
            }

            guard ImageConverter.isImageFile(fileURL) else {
                if verbose {
                    print("⊘ \(fileURL.lastPathComponent): Not a supported image file")
                }
                continue
            }

            do {
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let outputFileURL = outputDirURL.appendingPathComponent("\(baseName).dcm")

                let data = try ImageConverter.secondaryCaptureData(
                    imageURL: fileURL,
                    metadata: metadata(studyUID: finalStudyUID, seriesUID: finalSeriesUID,
                                       instanceNumber: instanceNum, patientName: patientName, patientID: patientId),
                    useExif: useExif)
                try data.write(to: outputFileURL)

                successCount += 1
                instanceNum += 1

                if verbose {
                    print("✓ \(fileURL.lastPathComponent) → \(outputFileURL.lastPathComponent)")
                }
            } catch {
                failureCount += 1
                if verbose {
                    print("✗ \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        print()
        print("Conversion complete:")
        print("  Successful: \(successCount)")
        if failureCount > 0 {
            print("  Failed: \(failureCount)")
        }
        print("  Study UID: \(finalStudyUID)")
        print("  Series UID: \(finalSeriesUID)")
        print("  Output directory: \(outputDirURL.path)")
    }

    // MARK: - File Processing

    private func convertFile(inputPath: String, outputPath: String?) throws {
        let inputURL = URL(fileURLWithPath: inputPath)

        guard let patientName = patientName, !patientName.isEmpty else {
            throw ValidationError("Patient Name is required for conversion (--patient-name)")
        }
        guard let patientId = patientId, !patientId.isEmpty else {
            throw ValidationError("Patient ID is required for conversion (--patient-id)")
        }

        if splitPages && (inputURL.pathExtension.lowercased() == "tiff" || inputURL.pathExtension.lowercased() == "tif") {
            try convertMultiPageTIFF(inputURL: inputURL, outputPath: outputPath,
                                     patientName: patientName, patientID: patientId)
        } else {
            let finalOutputPath: String
            if let specifiedOutput = outputPath {
                finalOutputPath = specifiedOutput
            } else {
                finalOutputPath = inputURL.deletingPathExtension().appendingPathExtension("dcm").path
            }

            let outputURL = URL(fileURLWithPath: finalOutputPath)

            if verbose {
                print("Converting image: \(inputPath)")
            }

            let data = try ImageConverter.secondaryCaptureData(
                imageURL: inputURL,
                metadata: metadata(studyUID: studyUid ?? ImageConverter.generateUID(),
                                   seriesUID: seriesUid ?? ImageConverter.generateUID(),
                                   instanceNumber: instanceNumber ?? 1,
                                   patientName: patientName, patientID: patientId),
                useExif: useExif)
            try data.write(to: outputURL)

            if verbose {
                print("✓ Converted to: \(finalOutputPath)")
            } else {
                print("Converted: \(finalOutputPath)")
            }
        }
    }

    // MARK: - Multi-Page TIFF Handling

    private func convertMultiPageTIFF(inputURL: URL, outputPath: String?, patientName: String, patientID: String) throws {
        let pageCount = try ImageConverter.pageCount(of: inputURL)
        guard pageCount > 0 else {
            throw ImageConversionError.noPages
        }

        let outputDirURL: URL
        if let specifiedOutput = outputPath {
            outputDirURL = URL(fileURLWithPath: specifiedOutput)
        } else {
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            outputDirURL = inputURL.deletingLastPathComponent().appendingPathComponent("\(baseName)_frames")
        }

        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)

        if verbose {
            print("Splitting multi-page TIFF: \(inputURL.lastPathComponent)")
            print("Pages: \(pageCount)")
            print("Output directory: \(outputDirURL.path)")
            print()
        }

        let finalStudyUID = studyUid ?? ImageConverter.generateUID()
        let finalSeriesUID = seriesUid ?? ImageConverter.generateUID()

        for pageIndex in 0..<pageCount {
            let outputFileName = String(format: "frame_%04d.dcm", pageIndex + 1)
            let outputFileURL = outputDirURL.appendingPathComponent(outputFileName)

            do {
                let data = try ImageConverter.secondaryCaptureData(
                    imageURL: inputURL,
                    pageIndex: pageIndex,
                    metadata: metadata(studyUID: finalStudyUID, seriesUID: finalSeriesUID,
                                       instanceNumber: (instanceNumber ?? 1) + pageIndex,
                                       patientName: patientName, patientID: patientID),
                    useExif: false)
                try data.write(to: outputFileURL)

                if verbose {
                    print("✓ Page \(pageIndex + 1) → \(outputFileName)")
                }
            } catch {
                if verbose {
                    print("✗ Page \(pageIndex + 1): \(error.localizedDescription)")
                }
            }
        }

        print()
        print("Multi-page TIFF conversion complete:")
        print("  Pages: \(pageCount)")
        print("  Output directory: \(outputDirURL.path)")
    }
    #endif
}

DICOMImage.main()
