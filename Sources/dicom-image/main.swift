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
        // Validate input exists
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("Input path not found: \(input)")
        }
        
        // Determine if input is a directory
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
    
    // MARK: - Directory Processing
    
    #if canImport(CoreGraphics)
    private func convertDirectory(inputPath: String, outputPath: String?) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        // Determine output directory
        let outputDirURL: URL
        if let specifiedOutput = outputPath {
            outputDirURL = URL(fileURLWithPath: specifiedOutput)
        } else {
            outputDirURL = inputURL.appendingPathComponent("dicom")
        }
        
        // Create output directory
        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
        
        if verbose {
            print("Converting images from: \(inputPath)")
            print("Output directory: \(outputDirURL.path)")
            print()
        }
        
        // Validate required metadata
        guard let patientName = patientName, !patientName.isEmpty else {
            throw ValidationError("Patient Name is required for batch conversion (--patient-name)")
        }
        
        guard let patientId = patientId, !patientId.isEmpty else {
            throw ValidationError("Patient ID is required for batch conversion (--patient-id)")
        }
        
        var successCount = 0
        var failureCount = 0
        var instanceNum = instanceNumber ?? 1
        
        // Generate series UIDs once for the batch
        let finalStudyUID = studyUid ?? generateUID()
        let finalSeriesUID = seriesUid ?? generateUID()
        
        // Enumerate image files
        let enumerator = FileManager.default.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip non-files
            guard let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isRegularFile else {
                continue
            }
            
            // Check if it's a supported image type
            guard isImageFile(fileURL) else {
                if verbose {
                    print("⊘ \(fileURL.lastPathComponent): Not a supported image file")
                }
                continue
            }
            
            // Try to convert this file
            do {
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let outputFileURL = outputDirURL.appendingPathComponent("\(baseName).dcm")
                
                try convertImageFile(
                    imageURL: fileURL,
                    outputURL: outputFileURL,
                    patientName: patientName,
                    patientID: patientId,
                    studyUID: finalStudyUID,
                    seriesUID: finalSeriesUID,
                    instanceNumber: instanceNum
                )
                
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
        
        // Summary
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
        
        // Validate required metadata
        guard let patientName = patientName, !patientName.isEmpty else {
            throw ValidationError("Patient Name is required for conversion (--patient-name)")
        }
        
        guard let patientId = patientId, !patientId.isEmpty else {
            throw ValidationError("Patient ID is required for conversion (--patient-id)")
        }
        
        // Check if it's a multi-page TIFF that needs splitting
        if splitPages && (inputURL.pathExtension.lowercased() == "tiff" || inputURL.pathExtension.lowercased() == "tif") {
            try convertMultiPageTIFF(
                inputURL: inputURL,
                outputPath: outputPath,
                patientName: patientName,
                patientID: patientId
            )
        } else {
            // Determine output path
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
            
            try convertImageFile(
                imageURL: inputURL,
                outputURL: outputURL,
                patientName: patientName,
                patientID: patientId,
                studyUID: studyUid ?? generateUID(),
                seriesUID: seriesUid ?? generateUID(),
                instanceNumber: instanceNumber ?? 1
            )
            
            if verbose {
                print("✓ Converted to: \(finalOutputPath)")
            } else {
                print("Converted: \(finalOutputPath)")
            }
        }
    }
    
    // MARK: - Image Conversion
    
    private func convertImageFile(
        imageURL: URL,
        outputURL: URL,
        patientName: String,
        patientID: String,
        studyUID: String,
        seriesUID: String,
        instanceNumber: Int
    ) throws {
        // Load image
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.imageLoadFailed
        }
        
        // Extract EXIF metadata if requested
        var exifMetadata: [String: Any]?
        if useExif {
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                exifMetadata = properties
            }
        }
        
        // Create Secondary Capture DICOM file
        let dataSet = try createSecondaryCaptureDataSet(
            image: cgImage,
            patientName: patientName,
            patientID: patientID,
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceNumber: instanceNumber,
            exifMetadata: exifMetadata
        )
        
        // Create DICOM file
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        )
        
        // Write to file
        let dicomData = try dicomFile.write()
        try dicomData.write(to: outputURL)
    }
    
    // MARK: - Multi-Page TIFF Handling
    
    private func convertMultiPageTIFF(
        inputURL: URL,
        outputPath: String?,
        patientName: String,
        patientID: String
    ) throws {
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ConversionError.imageLoadFailed
        }
        
        let pageCount = CGImageSourceGetCount(imageSource)
        guard pageCount > 0 else {
            throw ConversionError.noPages
        }
        
        // Determine output directory
        let outputDirURL: URL
        if let specifiedOutput = outputPath {
            outputDirURL = URL(fileURLWithPath: specifiedOutput)
        } else {
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            outputDirURL = inputURL.deletingLastPathComponent().appendingPathComponent("\(baseName)_frames")
        }
        
        // Create output directory
        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
        
        if verbose {
            print("Splitting multi-page TIFF: \(inputURL.lastPathComponent)")
            print("Pages: \(pageCount)")
            print("Output directory: \(outputDirURL.path)")
            print()
        }
        
        // Generate series UIDs once for all pages
        let finalStudyUID = studyUid ?? generateUID()
        let finalSeriesUID = seriesUid ?? generateUID()
        
        // Convert each page
        for pageIndex in 0..<pageCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, pageIndex, nil) else {
                if verbose {
                    print("✗ Page \(pageIndex + 1): Failed to load")
                }
                continue
            }
            
            let outputFileName = String(format: "frame_%04d.dcm", pageIndex + 1)
            let outputFileURL = outputDirURL.appendingPathComponent(outputFileName)
            
            do {
                let dataSet = try createSecondaryCaptureDataSet(
                    image: cgImage,
                    patientName: patientName,
                    patientID: patientID,
                    studyUID: finalStudyUID,
                    seriesUID: finalSeriesUID,
                    instanceNumber: (instanceNumber ?? 1) + pageIndex,
                    exifMetadata: nil
                )
                
                let dicomFile = DICOMFile.create(
                    dataSet: dataSet,
                    transferSyntaxUID: "1.2.840.10008.1.2.1"
                )
                
                let dicomData = try dicomFile.write()
                try dicomData.write(to: outputFileURL)
                
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
    
    // MARK: - Secondary Capture DataSet Creation
    
    private func createSecondaryCaptureDataSet(
        image: CGImage,
        patientName: String,
        patientID: String,
        studyUID: String,
        seriesUID: String,
        instanceNumber: Int,
        exifMetadata: [String: Any]?
    ) throws -> DataSet {
        var dataSet = DataSet()
        
        // SOP Common Module
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI) // Secondary Capture Image Storage
        dataSet.setString(generateUID(), for: .sopInstanceUID, vr: .UI)
        
        // Patient Module
        dataSet.setString(patientName, for: .patientName, vr: .PN)
        dataSet.setString(patientID, for: .patientID, vr: .LO)
        
        // Study Module
        dataSet.setString(studyUID, for: .studyInstanceUID, vr: .UI)
        if let studyDesc = studyDescription {
            dataSet.setString(studyDesc, for: .studyDescription, vr: .LO)
        } else if let exifDesc = extractEXIFDescription(from: exifMetadata) {
            dataSet.setString(exifDesc, for: .studyDescription, vr: .LO)
        }
        dataSet.setString(formatDate(Date()), for: .studyDate, vr: .DA)
        dataSet.setString(formatTime(Date()), for: .studyTime, vr: .TM)
        
        // Series Module
        dataSet.setString(seriesUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString(modality ?? "OT", for: .modality, vr: .CS)
        if let seriesDesc = seriesDescription {
            dataSet.setString(seriesDesc, for: .seriesDescription, vr: .LO)
        }
        if let seriesNum = seriesNumber {
            dataSet.setInt(seriesNum, for: .seriesNumber, vr: .IS)
        }
        
        // General Equipment Module (optional but recommended)
        dataSet.setString("DICOMKit", for: .manufacturer, vr: .LO)
        dataSet.setString("dicom-image CLI", for: .manufacturerModelName, vr: .LO)
        dataSet.setString("1.1.6", for: .softwareVersions, vr: .LO)
        
        // General Image Module
        dataSet.setInt(instanceNumber, for: .instanceNumber, vr: .IS)
        
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
        dataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: .OB,
            data: pixelData
        )
        
        // Add EXIF metadata to DICOM if available
        if let exif = exifMetadata {
            addEXIFMetadataToDICOM(exif: exif, dataSet: &dataSet)
        }
        
        return dataSet
    }
    
    // MARK: - Helper Methods
    
    private func extractPixelData(from image: CGImage, samplesPerPixel: Int) throws -> Data {
        let width = image.width
        let height = image.height
        let bytesPerPixel = samplesPerPixel
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = bytesPerRow * height
        
        var pixelData = Data(count: bufferSize)
        
        try pixelData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw ConversionError.pixelDataExtractionFailed
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
                throw ConversionError.contextCreationFailed
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        return pixelData
    }
    
    private func getSamplesPerPixel(image: CGImage) -> Int {
        let colorSpace = image.colorSpace
        let model = colorSpace?.model
        
        switch model {
        case .monochrome:
            return 1
        case .rgb:
            return 3
        default:
            // Default to RGB for unknown color spaces
            return 3
        }
    }
    
    private func getPhotometricInterpretation(image: CGImage) -> String {
        let samplesPerPixel = getSamplesPerPixel(image: image)
        return samplesPerPixel == 1 ? "MONOCHROME2" : "RGB"
    }
    
    private func extractEXIFDescription(from exif: [String: Any]?) -> String? {
        guard let exif = exif else { return nil }
        
        // Try different EXIF fields for description
        if let exifDict = exif[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let userComment = exifDict[kCGImagePropertyExifUserComment as String] as? String {
                return userComment
            }
            if let imageDescription = exifDict[kCGImagePropertyExifImageDescription as String] as? String {
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
    
    private func addEXIFMetadataToDICOM(exif: [String: Any], dataSet: inout DataSet) {
        // Extract acquisition date/time from EXIF
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
        
        // Extract pixel spacing from EXIF (DPI)
        if let dpiWidth = exif[kCGImagePropertyDPIWidth as String] as? Double,
           let dpiHeight = exif[kCGImagePropertyDPIHeight as String] as? Double {
            // Convert DPI to mm/pixel
            let mmPerInch = 25.4
            let pixelSpacingX = mmPerInch / dpiWidth
            let pixelSpacingY = mmPerInch / dpiHeight
            let pixelSpacing = String(format: "%.6f\\%.6f", pixelSpacingY, pixelSpacingX)
            dataSet.setString(pixelSpacing, for: .pixelSpacing, vr: .DS)
        }
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let supportedExtensions = ["jpg", "jpeg", "png", "tif", "tiff", "bmp", "gif"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter.string(from: date)
    }
    
    private func generateUID() -> String {
        // Generate a DICOM UID
        // Using a simple timestamp-based UID for now
        let timestamp = Date().timeIntervalSince1970
        let random = UInt32.random(in: 0...999999)
        return "2.25.\(Int(timestamp * 1000000)).\(random)"
    }
    #endif
}

enum ConversionError: LocalizedError {
    case imageLoadFailed
    case pixelDataExtractionFailed
    case contextCreationFailed
    case noPages
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            return "Failed to load image file"
        case .pixelDataExtractionFailed:
            return "Failed to extract pixel data from image"
        case .contextCreationFailed:
            return "Failed to create graphics context"
        case .noPages:
            return "TIFF file contains no pages"
        }
    }
}

DICOMImage.main()
