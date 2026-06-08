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

/// Errors raised while converting a standard image to DICOM Secondary Capture.
public enum ImageConversionError: Error, LocalizedError {
    case imageLoadFailed
    case pixelDataExtractionFailed
    case contextCreationFailed
    case noPages
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .imageLoadFailed: return "Failed to load image file"
        case .pixelDataExtractionFailed: return "Failed to extract pixel data from image"
        case .contextCreationFailed: return "Failed to create graphics context"
        case .noPages: return "TIFF file contains no pages"
        case .unsupportedPlatform: return "Image conversion not supported on this platform"
        }
    }
}

/// Converts standard images (JPEG/PNG/TIFF/…) to DICOM Secondary Capture.
///
/// Lives in the DICOMKit library so the `dicom-image` CLI and DICOMStudio run the
/// exact same conversion (pixel extraction, color-space handling, EXIF mapping,
/// Secondary Capture data-set assembly). Each adapter keeps its own orchestration
/// (file enumeration, output paths, sandbox writes, summaries); the per-image core
/// is shared here. UIDs are minted with `DICOMCore.UIDGenerator` for conformance.
public enum ImageConverter {

    /// Per-image Secondary Capture metadata.
    public struct Metadata: Sendable {
        public var patientName: String
        public var patientID: String
        public var studyUID: String
        public var seriesUID: String
        public var instanceNumber: Int
        public var studyDescription: String?
        public var seriesDescription: String?
        public var modality: String
        public var seriesNumber: Int?

        public init(
            patientName: String, patientID: String,
            studyUID: String, seriesUID: String, instanceNumber: Int,
            studyDescription: String? = nil, seriesDescription: String? = nil,
            modality: String = "OT", seriesNumber: Int? = nil
        ) {
            self.patientName = patientName
            self.patientID = patientID
            self.studyUID = studyUID
            self.seriesUID = seriesUID
            self.instanceNumber = instanceNumber
            self.studyDescription = studyDescription
            self.seriesDescription = seriesDescription
            self.modality = modality
            self.seriesNumber = seriesNumber
        }
    }

    /// A fresh DICOM UID (delegates to the shared `UIDGenerator`).
    public static func generateUID() -> String {
        UIDGenerator.generateUID().value
    }

    /// Whether the URL looks like a supported image by extension.
    public static func isImageFile(_ url: URL) -> Bool {
        let supportedExtensions = ["jpg", "jpeg", "png", "tif", "tiff", "bmp", "gif"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    #if canImport(CoreGraphics)
    /// Number of pages/frames in an image (1 for most formats; >1 for multi-page TIFF).
    public static func pageCount(of imageURL: URL) throws -> Int {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw ImageConversionError.imageLoadFailed
        }
        return CGImageSourceGetCount(imageSource)
    }

    /// Loads one page of an image and returns a DICOM Secondary Capture file as
    /// bytes. `useExif` pulls acquisition date/time, pixel spacing, and a study
    /// description from the image's metadata.
    public static func secondaryCaptureData(
        imageURL: URL,
        pageIndex: Int = 0,
        metadata: Metadata,
        useExif: Bool
    ) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, pageIndex, nil) else {
            throw ImageConversionError.imageLoadFailed
        }

        var exifMetadata: [String: Any]?
        if useExif {
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, pageIndex, nil) as? [String: Any] {
                exifMetadata = properties
            }
        }

        let dataSet = try makeSecondaryCaptureDataSet(image: cgImage, metadata: metadata, exifMetadata: exifMetadata)
        let dicomFile = DICOMFile.create(dataSet: dataSet, transferSyntaxUID: "1.2.840.10008.1.2.1")
        return try dicomFile.write()
    }

    // MARK: - Secondary Capture DataSet Creation

    private static func makeSecondaryCaptureDataSet(
        image: CGImage,
        metadata: Metadata,
        exifMetadata: [String: Any]?
    ) throws -> DataSet {
        var dataSet = DataSet()

        // SOP Common Module
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI) // Secondary Capture Image Storage
        dataSet.setString(generateUID(), for: .sopInstanceUID, vr: .UI)

        // Patient Module
        dataSet.setString(metadata.patientName, for: .patientName, vr: .PN)
        dataSet.setString(metadata.patientID, for: .patientID, vr: .LO)

        // Study Module
        dataSet.setString(metadata.studyUID, for: .studyInstanceUID, vr: .UI)
        if let studyDesc = metadata.studyDescription {
            dataSet.setString(studyDesc, for: .studyDescription, vr: .LO)
        } else if let exifDesc = extractEXIFDescription(from: exifMetadata) {
            dataSet.setString(exifDesc, for: .studyDescription, vr: .LO)
        }
        dataSet.setString(formatDate(Date()), for: .studyDate, vr: .DA)
        dataSet.setString(formatTime(Date()), for: .studyTime, vr: .TM)

        // Series Module
        dataSet.setString(metadata.seriesUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString(metadata.modality, for: .modality, vr: .CS)
        if let seriesDesc = metadata.seriesDescription {
            dataSet.setString(seriesDesc, for: .seriesDescription, vr: .LO)
        }
        if let seriesNum = metadata.seriesNumber {
            dataSet.setInt(seriesNum, for: .seriesNumber, vr: .IS)
        }

        // General Equipment Module
        dataSet.setString("DICOMKit", for: .manufacturer, vr: .LO)
        dataSet.setString("dicom-image CLI", for: .manufacturerModelName, vr: .LO)
        dataSet.setString("1.1.6", for: .softwareVersions, vr: .LO)

        // General Image Module
        dataSet.setInt(metadata.instanceNumber, for: .instanceNumber, vr: .IS)

        // Image Pixel Module
        let width = image.width
        let height = image.height
        let samplesPerPixel = getSamplesPerPixel(image: image)
        let photometricInterpretation = getPhotometricInterpretation(image: image)

        dataSet.setInt(samplesPerPixel, for: .samplesPerPixel, vr: .US)
        dataSet.setString(photometricInterpretation, for: .photometricInterpretation, vr: .CS)
        dataSet.setInt(height, for: .rows, vr: .US)
        dataSet.setInt(width, for: .columns, vr: .US)
        dataSet.setInt(8, for: .bitsAllocated, vr: .US)
        dataSet.setInt(8, for: .bitsStored, vr: .US)
        dataSet.setInt(7, for: .highBit, vr: .US)
        dataSet.setInt(0, for: .pixelRepresentation, vr: .US)

        if samplesPerPixel == 3 {
            dataSet.setInt(0, for: .planarConfiguration, vr: .US)
        }

        // Extract and convert pixel data
        let pixelData = try extractPixelData(from: image, samplesPerPixel: samplesPerPixel)
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixelData)

        // Add EXIF metadata if available
        if let exif = exifMetadata {
            addEXIFMetadataToDICOM(exif: exif, dataSet: &dataSet)
        }

        return dataSet
    }

    // MARK: - Pixel / format helpers

    private static func extractPixelData(from image: CGImage, samplesPerPixel: Int) throws -> Data {
        let width = image.width
        let height = image.height
        let bytesPerPixel = samplesPerPixel
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = bytesPerRow * height

        var pixelData = Data(count: bufferSize)

        try pixelData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw ImageConversionError.pixelDataExtractionFailed
            }

            let colorSpace: CGColorSpace
            let bitmapInfo: CGBitmapInfo

            if samplesPerPixel == 3 {
                colorSpace = CGColorSpaceCreateDeviceRGB()
                bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            } else {
                colorSpace = CGColorSpaceCreateDeviceGray()
                bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            }

            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw ImageConversionError.contextCreationFailed
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return pixelData
    }

    private static func getSamplesPerPixel(image: CGImage) -> Int {
        switch image.colorSpace?.model {
        case .monochrome: return 1
        case .rgb: return 3
        default: return 3
        }
    }

    private static func getPhotometricInterpretation(image: CGImage) -> String {
        getSamplesPerPixel(image: image) == 1 ? "MONOCHROME2" : "RGB"
    }

    private static func extractEXIFDescription(from exif: [String: Any]?) -> String? {
        guard let exif = exif else { return nil }

        if let exifDict = exif[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let userComment = exifDict[kCGImagePropertyExifUserComment as String] as? String {
                return userComment
            }
            if let imageDescription = exifDict["ImageDescription"] as? String {
                return imageDescription
            }
        }

        if let tiffDict = exif[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let imageDescription = tiffDict[kCGImagePropertyTIFFImageDescription as String] as? String {
                return imageDescription
            }
        }

        return nil
    }

    private static func addEXIFMetadataToDICOM(exif: [String: Any], dataSet: inout DataSet) {
        if let exifDict = exif[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                // EXIF date format: "YYYY:MM:DD HH:MM:SS"
                let components = dateTimeOriginal.components(separatedBy: " ")
                if components.count == 2 {
                    let datePart = components[0].replacingOccurrences(of: ":", with: "")
                    let timePart = components[1].replacingOccurrences(of: ":", with: "")
                    dataSet.setString(datePart, for: .acquisitionDate, vr: .DA)
                    dataSet.setString(timePart, for: .acquisitionTime, vr: .TM)
                }
            }
        }

        if let dpiWidth = exif[kCGImagePropertyDPIWidth as String] as? Double,
           let dpiHeight = exif[kCGImagePropertyDPIHeight as String] as? Double {
            let mmPerInch = 25.4
            let pixelSpacingX = mmPerInch / dpiWidth
            let pixelSpacingY = mmPerInch / dpiHeight
            let pixelSpacing = String(format: "%.6f\\%.6f", pixelSpacingY, pixelSpacingX)
            dataSet.setString(pixelSpacing, for: .pixelSpacing, vr: .DS)
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter.string(from: date)
    }
    #endif
}
