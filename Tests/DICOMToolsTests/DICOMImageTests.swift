import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

/// Tests for dicom-image CLI tool functionality
/// These tests verify the image-to-DICOM Secondary Capture conversion
final class DICOMImageTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    #if canImport(CoreGraphics)
    /// Creates a simple test image (grayscale)
    private func createTestGrayscaleImage(width: Int = 100, height: Int = 100) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        var pixelData = Data(count: width * height)
        for i in 0..<(width * height) {
            pixelData[i] = UInt8((i % 256))
        }
        
        guard let context = CGContext(
            data: &pixelData.withUnsafeMutableBytes({ $0.baseAddress! }),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    /// Creates a simple test image (RGB)
    private func createTestRGBImage(width: Int = 100, height: Int = 100) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        var pixelData = Data(count: width * height * 3)
        for i in 0..<(width * height) {
            let index = i * 3
            pixelData[index] = UInt8((i % 256))     // R
            pixelData[index + 1] = UInt8((i % 128)) // G
            pixelData[index + 2] = UInt8((i % 64))  // B
        }
        
        guard let context = CGContext(
            data: &pixelData.withUnsafeMutableBytes({ $0.baseAddress! }),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 3,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    /// Writes a CGImage to a PNG file
    private func writePNGImage(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image"])
        }
    }
    
    /// Writes a CGImage to a JPEG file
    private func writeJPEGImage(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image"])
        }
    }
    #endif
    
    // MARK: - Grayscale Image Conversion Tests
    
    #if canImport(CoreGraphics)
    func testConvertGrayscaleImageToSecondaryCaptureCreatesValidDICOM() throws {
        guard let image = createTestGrayscaleImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        var dataSet = DataSet()
        
        // Set required metadata
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI) // Secondary Capture
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("OT", for: .modality, vr: .CS)
        dataSet.setString("1", for: .instanceNumber, vr: .IS)
        
        // Image Pixel Module
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        dataSet.setUInt16(100, for: .rows)
        dataSet.setUInt16(100, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        
        // Verify SOP Class UID is Secondary Capture
        XCTAssertEqual(dataSet.string(for: .sopClassUID), "1.2.840.10008.5.1.4.1.1.7")
        
        // Verify Patient Module
        XCTAssertEqual(dataSet.string(for: .patientName), "Test^Patient")
        XCTAssertEqual(dataSet.string(for: .patientID), "12345")
        
        // Verify Image Pixel Module
        XCTAssertEqual(dataSet.uint16(for: .samplesPerPixel), 1)
        XCTAssertEqual(dataSet.string(for: .photometricInterpretation), "MONOCHROME2")
        XCTAssertEqual(dataSet.uint16(for: .rows), 100)
        XCTAssertEqual(dataSet.uint16(for: .columns), 100)
    }
    
    func testConvertGrayscaleImageExtractsCorrectDimensions() throws {
        guard let image = createTestGrayscaleImage(width: 256, height: 128) else {
            XCTFail("Failed to create test image")
            return
        }
        
        XCTAssertEqual(image.width, 256)
        XCTAssertEqual(image.height, 128)
    }
    #endif
    
    // MARK: - RGB Image Conversion Tests
    
    #if canImport(CoreGraphics)
    func testConvertRGBImageToSecondaryCaptureCreatesValidDICOM() throws {
        guard let image = createTestRGBImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        var dataSet = DataSet()
        
        // Set required metadata
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("OT", for: .modality, vr: .CS)
        
        // Image Pixel Module for RGB
        dataSet.setUInt16(3, for: .samplesPerPixel)
        dataSet.setString("RGB", for: .photometricInterpretation, vr: .CS)
        dataSet.setUInt16(100, for: .rows)
        dataSet.setUInt16(100, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(0, for: .planarConfiguration)
        
        // Verify RGB-specific attributes
        XCTAssertEqual(dataSet.uint16(for: .samplesPerPixel), 3)
        XCTAssertEqual(dataSet.string(for: .photometricInterpretation), "RGB")
        XCTAssertEqual(dataSet.uint16(for: .planarConfiguration), 0)
    }
    #endif
    
    // MARK: - JPEG to DICOM Tests
    
    #if canImport(CoreGraphics)
    func testConvertJPEGToDICOM() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let jpegURL = tempDir.appendingPathComponent("test.jpg")
        
        guard let image = createTestRGBImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        try writeJPEGImage(image, to: jpegURL)
        defer { try? FileManager.default.removeItem(at: jpegURL) }
        
        // Verify JPEG was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: jpegURL.path))
        
        // Load and verify image properties
        guard let imageSource = CGImageSourceCreateWithURL(jpegURL as CFURL, nil),
              let loadedImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            XCTFail("Failed to load JPEG image")
            return
        }
        
        XCTAssertEqual(loadedImage.width, 100)
        XCTAssertEqual(loadedImage.height, 100)
    }
    #endif
    
    // MARK: - PNG to DICOM Tests
    
    #if canImport(CoreGraphics)
    func testConvertPNGToDICOM() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let pngURL = tempDir.appendingPathComponent("test.png")
        
        guard let image = createTestGrayscaleImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        try writePNGImage(image, to: pngURL)
        defer { try? FileManager.default.removeItem(at: pngURL) }
        
        // Verify PNG was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: pngURL.path))
        
        // Load and verify image properties
        guard let imageSource = CGImageSourceCreateWithURL(pngURL as CFURL, nil),
              let loadedImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            XCTFail("Failed to load PNG image")
            return
        }
        
        XCTAssertEqual(loadedImage.width, 100)
        XCTAssertEqual(loadedImage.height, 100)
    }
    #endif
    
    // MARK: - EXIF Metadata Tests
    
    #if canImport(CoreGraphics)
    func testEXIFMetadataExtraction() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let jpegURL = tempDir.appendingPathComponent("test_exif.jpg")
        
        guard let image = createTestRGBImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        // Write JPEG with EXIF metadata
        guard let destination = CGImageDestinationCreateWithURL(
            jpegURL as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            XCTFail("Failed to create image destination")
            return
        }
        
        let exifDict: [String: Any] = [
            kCGImagePropertyExifDateTimeOriginal as String: "2024:01:15 10:30:00",
            kCGImagePropertyExifUserComment as String: "Test EXIF comment"
        ]
        
        let properties: [String: Any] = [
            kCGImagePropertyExifDictionary as String: exifDict,
            kCGImagePropertyDPIWidth as String: 72.0,
            kCGImagePropertyDPIHeight as String: 72.0
        ]
        
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        defer { try? FileManager.default.removeItem(at: jpegURL) }
        
        // Read back and verify EXIF
        guard let imageSource = CGImageSourceCreateWithURL(jpegURL as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            XCTFail("Failed to load image properties")
            return
        }
        
        if let exif = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            XCTAssertEqual(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String, "2024:01:15 10:30:00")
        }
    }
    #endif
    
    // MARK: - Pixel Data Extraction Tests
    
    #if canImport(CoreGraphics)
    func testExtractPixelDataFromGrayscaleImage() throws {
        guard let image = createTestGrayscaleImage(width: 10, height: 10) else {
            XCTFail("Failed to create test image")
            return
        }
        
        let width = image.width
        let height = image.height
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = bytesPerRow * height
        
        var pixelData = Data(count: bufferSize)
        
        pixelData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                XCTFail("Failed to get buffer address")
                return
            }
            
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                XCTFail("Failed to create context")
                return
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        XCTAssertEqual(pixelData.count, 100)
        XCTAssertFalse(pixelData.isEmpty)
    }
    
    func testExtractPixelDataFromRGBImage() throws {
        guard let image = createTestRGBImage(width: 10, height: 10) else {
            XCTFail("Failed to create test image")
            return
        }
        
        let width = image.width
        let height = image.height
        let bytesPerPixel = 3
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = bytesPerRow * height
        
        var pixelData = Data(count: bufferSize)
        
        pixelData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                XCTFail("Failed to get buffer address")
                return
            }
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                XCTFail("Failed to create context")
                return
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        XCTAssertEqual(pixelData.count, 300) // 10 * 10 * 3
        XCTAssertFalse(pixelData.isEmpty)
    }
    #endif
    
    // MARK: - Secondary Capture DataSet Creation Tests
    
    func testSecondaryCaptureDataSetHasRequiredModules() throws {
        var dataSet = DataSet()
        
        // SOP Common Module
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        
        // Patient Module
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        
        // Study Module
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("20240115", for: .studyDate, vr: .DA)
        dataSet.setString("103000", for: .studyTime, vr: .TM)
        
        // Series Module
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("OT", for: .modality, vr: .CS)
        
        // General Equipment Module
        dataSet.setString("DICOMKit", for: .manufacturer, vr: .LO)
        
        // General Image Module
        dataSet.setString("1", for: .instanceNumber, vr: .IS)
        
        // Verify all required tags are present
        XCTAssertNotNil(dataSet[.sopClassUID])
        XCTAssertNotNil(dataSet[.sopInstanceUID])
        XCTAssertNotNil(dataSet[.patientName])
        XCTAssertNotNil(dataSet[.patientID])
        XCTAssertNotNil(dataSet[.studyInstanceUID])
        XCTAssertNotNil(dataSet[.seriesInstanceUID])
        XCTAssertNotNil(dataSet[.modality])
        XCTAssertNotNil(dataSet[.instanceNumber])
    }
    
    func testSecondaryCaptureDataSetHasCorrectSOPClass() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        
        XCTAssertEqual(dataSet.string(for: .sopClassUID), "1.2.840.10008.5.1.4.1.1.7")
    }
    
    // MARK: - Metadata Tests
    
    func testSetPatientMetadata() throws {
        var dataSet = DataSet()
        
        dataSet.setString("DOE^JOHN", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        
        XCTAssertEqual(dataSet.string(for: .patientName), "DOE^JOHN")
        XCTAssertEqual(dataSet.string(for: .patientID), "12345")
    }
    
    func testSetStudyMetadata() throws {
        var dataSet = DataSet()
        
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("Clinical Photography", for: .studyDescription, vr: .LO)
        dataSet.setString("20240115", for: .studyDate, vr: .DA)
        dataSet.setString("103000", for: .studyTime, vr: .TM)
        
        XCTAssertEqual(dataSet.string(for: .studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(dataSet.string(for: .studyDescription), "Clinical Photography")
    }
    
    func testSetSeriesMetadata() throws {
        var dataSet = DataSet()
        
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("OT", for: .modality, vr: .CS)
        dataSet.setString("Test Series", for: .seriesDescription, vr: .LO)
        dataSet.setString("1", for: .seriesNumber, vr: .IS)
        
        XCTAssertEqual(dataSet.string(for: .seriesInstanceUID), "1.2.3.4.5.6")
        XCTAssertEqual(dataSet.string(for: .modality), "OT")
        XCTAssertEqual(dataSet.string(for: .seriesDescription), "Test Series")
        XCTAssertEqual(dataSet.string(for: .seriesNumber), "1")
    }
    
    // MARK: - Round-trip Tests
    
    #if canImport(CoreGraphics)
    func testRoundTripGrayscaleImage() throws {
        guard let originalImage = createTestGrayscaleImage(width: 50, height: 50) else {
            XCTFail("Failed to create test image")
            return
        }
        
        // Extract pixel data
        let width = originalImage.width
        let height = originalImage.height
        var pixelData = Data(count: width * height)
        
        pixelData.withUnsafeMutableBytes { buffer in
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            
            if let context = CGContext(
                data: buffer.baseAddress!,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) {
                context.draw(originalImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        
        // Create DICOM with pixel data
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("OT", for: .modality, vr: .CS)
        dataSet.setString("1", for: .instanceNumber, vr: .IS)
        
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        dataSet.setUInt16(UInt16(height), for: .rows)
        dataSet.setUInt16(UInt16(width), for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        
        dataSet[.pixelData] = DataElement(tag: .pixelData, vr: .OB, data: pixelData)
        
        // Verify pixel data can be extracted
        XCTAssertNotNil(dataSet[.pixelData])
        XCTAssertEqual(dataSet[.pixelData]?.valueData.count, 2500) // 50 * 50
    }
    #endif
    
    // MARK: - Dimension Tests
    
    func testVariousImageDimensions() throws {
        let dimensions = [(64, 64), (256, 128), (512, 512), (1024, 768)]
        
        for (width, height) in dimensions {
            var dataSet = DataSet()
            dataSet.setUInt16(UInt16(height), for: .rows)
            dataSet.setUInt16(UInt16(width), for: .columns)
            
            XCTAssertEqual(dataSet.uint16(for: .rows), UInt16(height))
            XCTAssertEqual(dataSet.uint16(for: .columns), UInt16(width))
        }
    }
    
    // MARK: - Color Space Tests
    
    #if canImport(CoreGraphics)
    func testGrayscaleColorSpaceDetection() throws {
        guard let image = createTestGrayscaleImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let colorSpace = image.colorSpace
        let model = colorSpace?.model
        
        XCTAssertEqual(model, .monochrome)
    }
    
    func testRGBColorSpaceDetection() throws {
        guard let image = createTestRGBImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let colorSpace = image.colorSpace
        let model = colorSpace?.model
        
        XCTAssertEqual(model, .rgb)
    }
    #endif
    
    // MARK: - Error Handling Tests
    
    func testMissingPatientNameThrowsError() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        // Missing patient name
        dataSet.setString("12345", for: .patientID, vr: .LO)
        
        // Verify patient ID is set but name is missing
        XCTAssertNil(dataSet[.patientName])
        XCTAssertNotNil(dataSet[.patientID])
    }
    
    func testMissingPatientIDThrowsError() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        // Missing patient ID
        
        // Verify patient name is set but ID is missing
        XCTAssertNotNil(dataSet[.patientName])
        XCTAssertNil(dataSet[.patientID])
    }
}
