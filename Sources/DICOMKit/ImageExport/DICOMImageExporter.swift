import Foundation
import DICOMCore
import DICOMDictionary

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// Shared image-export engine for the `dicom-export` CLI and DICOMStudio. Builds on
// the already-shared rendering primitives (PixelData / PixelDataRenderer /
// WindowSettings / DICOMFile.tryRenderFrame). This collects the pure, deterministic
// pieces both adapters used to duplicate — EXIF mapping, contact-sheet geometry,
// path organization, window resolution, and image encoding. Each adapter keeps its
// own render/compose orchestration (the CLI writes files directly; DICOMStudio
// writes through its sandbox-aware OutputAccess) but shares this logic.

/// Output image formats for export.
public enum ExportImageFormat: String, CaseIterable, Sendable {
    case png
    case jpeg
    case tiff

    public var fileExtension: String { rawValue }

    #if canImport(UniformTypeIdentifiers)
    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }
    #endif
}

/// Directory organization scheme for bulk export.
public enum OrganizationScheme: String, CaseIterable, Sendable {
    case flat
    case patient
    case study
    case series
}

/// Errors raised during image export.
public enum ExportError: LocalizedError {
    case noPixelData
    case renderFailed
    case exportFailed
    case unsupportedPlatform
    case invalidFrame(Int, Int)
    case noFrames
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .noPixelData: return "No pixel data found in DICOM file"
        case .renderFailed: return "Failed to render pixel data to image"
        case .exportFailed: return "Failed to export image to file"
        case .unsupportedPlatform: return "Image export requires macOS or iOS (CoreGraphics)"
        case .invalidFrame(let requested, let total):
            return "Invalid frame \(requested). File has \(total) frames (0-\(total - 1))"
        case .noFrames: return "No frames available in DICOM file"
        case .invalidInput(let message): return message
        }
    }
}

/// Shared, deterministic helpers behind the DICOM image-export workflow.
public enum DICOMImageExporter {

    /// Version stamp embedded in EXIF Software tags (matches the CLI tool version).
    public static let toolVersion = "1.2.2"

    // MARK: - EXIF metadata

    /// Maps DICOM field names to EXIF/TIFF dictionary keys.
    public static func mapDICOMFieldToEXIF(_ field: String) -> (dictionary: String, key: String)? {
        switch field.lowercased() {
        case "patientname": return ("tiff", "ImageDescription")
        case "studydate": return ("exif", "DateTimeOriginal")
        case "modality": return ("exif", "Software")
        case "studydescription": return ("tiff", "DocumentName")
        case "seriesdescription": return ("exif", "UserComment")
        case "institutionname": return ("tiff", "Artist")
        case "manufacturer": return ("tiff", "Make")
        case "manufacturermodelname": return ("tiff", "Model")
        case "stationname": return ("tiff", "HostComputer")
        default: return nil
        }
    }

    /// Retrieves a DICOM field value from a DICOMFile by field name.
    public static func getDICOMFieldValue(_ file: DICOMFile, field: String) -> String? {
        switch field.lowercased() {
        case "patientname": return file.dataSet.string(for: .patientName)
        case "patientid": return file.dataSet.string(for: .patientID)
        case "studydate": return file.dataSet.string(for: .studyDate)
        case "studydescription": return file.dataSet.string(for: .studyDescription)
        case "seriesdescription": return file.dataSet.string(for: .seriesDescription)
        case "modality": return file.dataSet.string(for: .modality)
        case "institutionname": return file.dataSet.string(for: .institutionName)
        case "manufacturer": return file.dataSet.string(for: .manufacturer)
        case "manufacturermodelname": return file.dataSet.string(for: .manufacturerModelName)
        case "stationname": return file.dataSet.string(for: .stationName)
        default: return nil
        }
    }

    #if canImport(CoreGraphics)
    /// Builds EXIF/TIFF metadata dictionaries from a DICOM file.
    public static func buildEXIFMetadata(from file: DICOMFile, fields: [String]?) -> CFDictionary {
        var tiffDict: [String: Any] = [:]
        var exifDict: [String: Any] = [:]

        let fieldsToEmbed = fields ?? ["PatientName", "StudyDate", "Modality", "StudyDescription", "Manufacturer"]

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

        tiffDict["Software"] = "DICOMKit dicom-export v\(toolVersion)"

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

    // MARK: - Contact sheet geometry

    /// Computes contact sheet grid dimensions.
    public static func contactSheetLayout(
        imageCount: Int, columns: Int, thumbnailSize: Int, spacing: Int, includeLabels: Bool
    ) -> (rows: Int, totalWidth: Int, totalHeight: Int) {
        let rows = max(1, (imageCount + columns - 1) / columns)
        let labelHeight = includeLabels ? 20 : 0
        let totalWidth = columns * thumbnailSize + (columns + 1) * spacing
        let totalHeight = rows * (thumbnailSize + labelHeight) + (rows + 1) * spacing
        return (rows, totalWidth, totalHeight)
    }

    /// Returns the position for a thumbnail at a given index in the grid.
    public static func thumbnailPosition(
        index: Int, columns: Int, thumbnailSize: Int, spacing: Int, includeLabels: Bool
    ) -> (x: Int, y: Int) {
        let col = index % columns
        let row = index / columns
        let labelHeight = includeLabels ? 20 : 0
        let x = spacing + col * (thumbnailSize + spacing)
        let y = spacing + row * (thumbnailSize + labelHeight + spacing)
        return (x, y)
    }

    // MARK: - Animation

    /// Computes the GIF frame delay from FPS.
    public static func gifFrameDelay(fps: Double) -> Double {
        guard fps > 0 else { return 0.1 }
        return 1.0 / fps
    }

    /// Validates and clamps a frame range.
    public static func validatedFrameRange(start: Int, end: Int?, totalFrames: Int) -> (start: Int, end: Int)? {
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

    // MARK: - Bulk export paths

    /// Sanitizes a string for use as a path component.
    public static func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var result = ""
        for char in value.unicodeScalars {
            result.append(allowed.contains(char) ? Character(char) : "_")
        }
        return result.isEmpty ? "UNKNOWN" : result
    }

    /// Builds the output path for a bulk export file based on the organization scheme.
    public static func buildOrganizedPath(
        baseOutput: String, scheme: OrganizationScheme,
        patientName: String?, studyUID: String?, seriesUID: String?, filename: String
    ) -> String {
        switch scheme {
        case .flat:
            return (baseOutput as NSString).appendingPathComponent(filename)
        case .patient:
            let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
            return (baseOutput as NSString).appendingPathComponent(patient).appending("/\(filename)")
        case .study:
            let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
            let study = sanitizePathComponent(studyUID ?? "UNKNOWN")
            return (baseOutput as NSString).appendingPathComponent(patient).appending("/\(study)/\(filename)")
        case .series:
            let patient = sanitizePathComponent(patientName ?? "UNKNOWN")
            let study = sanitizePathComponent(studyUID ?? "UNKNOWN")
            let series = sanitizePathComponent(seriesUID ?? "UNKNOWN")
            return (baseOutput as NSString).appendingPathComponent(patient).appending("/\(study)/\(series)/\(filename)")
        }
    }

    // MARK: - Window settings

    /// Resolves window settings for a frame: explicit values, the file's own
    /// window, the frame's pixel range, or a 16-bit fallback.
    public static func determineWindowSettings(
        from file: DICOMFile, pixelData: PixelData, frameIndex: Int,
        windowCenter: Double?, windowWidth: Double?
    ) -> WindowSettings {
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

    // MARK: - Image encoding

    #if canImport(CoreGraphics) && canImport(ImageIO)
    /// Writes a CGImage to a file URL in the given format, with optional EXIF metadata.
    public static func exportCGImage(
        _ image: CGImage, to url: URL, format: ExportImageFormat, quality: Int, metadata: CFDictionary?
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, format.utType.identifier as CFString, 1, nil
        ) else {
            throw ExportError.exportFailed
        }

        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
        }

        if let metadata = metadata, let metaDict = metadata as? [String: Any] {
            for (key, value) in metaDict {
                options[key as CFString] = value
            }
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.exportFailed
        }
    }
    #endif
}
