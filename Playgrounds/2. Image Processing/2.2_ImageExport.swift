// DICOMKit Sample Code: Image Export
//
// This example demonstrates how to:
// - Export DICOM images to PNG format
// - Export to JPEG with quality settings
// - Export to TIFF format
// - Export multi-frame series
// - Apply transformations before export
// - Batch export multiple files

import DICOMKit
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(ImageIO)
import ImageIO
#endif

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Example 1: Basic PNG Export

#if canImport(CoreGraphics) && canImport(ImageIO)
func example1_exportToPNG() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data found")
        return
    }
    
    // Create CGImage from pixel data
    guard let cgImage = try pixelData.createCGImage(frame: 0) else {
        print("❌ Failed to create image")
        return
    }
    
    // Export to PNG
    let outputURL = URL(fileURLWithPath: "/tmp/output.png")
    
    #if os(macOS)
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        throw DICOMError.corruptedData
    }
    try pngData.write(to: outputURL)
    #elseif os(iOS)
    let uiImage = UIImage(cgImage: cgImage)
    guard let pngData = uiImage.pngData() else {
        throw DICOMError.corruptedData
    }
    try pngData.write(to: outputURL)
    #endif
    
    print("✅ Exported to PNG: \(outputURL.path)")
    print("   Image size: \(cgImage.width) × \(cgImage.height)")
}
#endif

// MARK: - Example 2: JPEG Export with Quality Settings

#if canImport(CoreGraphics) && canImport(ImageIO)
func example2_exportToJPEG(quality: Double = 0.95) throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData,
          let cgImage = try pixelData.createCGImage(frame: 0) else {
        print("❌ Failed to get image")
        return
    }
    
    let outputURL = URL(fileURLWithPath: "/tmp/output.jpg")
    
    #if os(macOS)
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    let properties: [NSBitmapImageRep.PropertyKey: Any] = [
        .compressionFactor: quality
    ]
    guard let jpegData = bitmapRep.representation(using: .jpeg, properties: properties) else {
        throw DICOMError.corruptedData
    }
    try jpegData.write(to: outputURL)
    #elseif os(iOS)
    let uiImage = UIImage(cgImage: cgImage)
    guard let jpegData = uiImage.jpegData(compressionQuality: quality) else {
        throw DICOMError.corruptedData
    }
    try jpegData.write(to: outputURL)
    #endif
    
    let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
    print("✅ Exported to JPEG with quality \(quality)")
    print("   File size: \(fileSize / 1024) KB")
}
#endif

// MARK: - Example 3: TIFF Export (16-bit Support)

#if canImport(CoreGraphics) && canImport(ImageIO)
func example3_exportToTIFF() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData,
          let cgImage = try pixelData.createCGImage(frame: 0) else {
        print("❌ Failed to get image")
        return
    }
    
    let outputURL = URL(fileURLWithPath: "/tmp/output.tiff")
    
    #if os(macOS)
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    let properties: [NSBitmapImageRep.PropertyKey: Any] = [
        .compressionMethod: NSNumber(value: NSTIFFCompression.lzw.rawValue)
    ]
    guard let tiffData = bitmapRep.representation(using: .tiff, properties: properties) else {
        throw DICOMError.corruptedData
    }
    try tiffData.write(to: outputURL)
    print("✅ Exported to TIFF with LZW compression")
    print("   Bits per sample: \(bitmapRep.bitsPerSample)")
    #else
    // iOS doesn't have native TIFF support via UIImage
    // Use ImageIO for cross-platform TIFF export
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        kUTTypeTIFF,
        1,
        nil
    ) else {
        throw DICOMError.corruptedData
    }
    
    let properties: [CFString: Any] = [
        kCGImagePropertyTIFFCompression: 5  // LZW compression
    ]
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    
    if CGImageDestinationFinalize(destination) {
        print("✅ Exported to TIFF")
    } else {
        throw DICOMError.corruptedData
    }
    #endif
}
#endif

// MARK: - Example 4: Export with Window/Level Applied

#if canImport(CoreGraphics)
func example4_exportWithWindowLevel() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    // Apply lung window preset
    let windowCenter: Double = -600
    let windowWidth: Double = 1500
    
    guard let cgImage = try pixelData.createCGImage(
        frame: 0,
        windowCenter: windowCenter,
        windowWidth: windowWidth
    ) else {
        print("❌ Failed to create image")
        return
    }
    
    let outputURL = URL(fileURLWithPath: "/tmp/output_windowed.png")
    
    #if os(macOS)
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        throw DICOMError.corruptedData
    }
    try pngData.write(to: outputURL)
    #elseif os(iOS)
    let uiImage = UIImage(cgImage: cgImage)
    guard let pngData = uiImage.pngData() else {
        throw DICOMError.corruptedData
    }
    try pngData.write(to: outputURL)
    #endif
    
    print("✅ Exported with lung window (C=\(windowCenter), W=\(windowWidth))")
}
#endif

// MARK: - Example 5: Multi-Frame Export

#if canImport(CoreGraphics)
func example5_exportMultiFrame() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/multiframe/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    let outputDirectory = URL(fileURLWithPath: "/tmp/frames")
    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    
    print("Exporting \(pixelData.numberOfFrames) frames...")
    
    for frameIndex in 0..<pixelData.numberOfFrames {
        guard let cgImage = try pixelData.createCGImage(frame: frameIndex) else {
            print("⚠️  Failed to create image for frame \(frameIndex)")
            continue
        }
        
        let filename = String(format: "frame_%04d.png", frameIndex)
        let outputURL = outputDirectory.appendingPathComponent(filename)
        
        #if os(macOS)
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            continue
        }
        try pngData.write(to: outputURL)
        #elseif os(iOS)
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else {
            continue
        }
        try pngData.write(to: outputURL)
        #endif
        
        if frameIndex % 10 == 0 {
            print("  Exported frame \(frameIndex + 1)/\(pixelData.numberOfFrames)")
        }
    }
    
    print("✅ Exported all frames to \(outputDirectory.path)")
}
#endif

// MARK: - Example 6: Batch Export

#if canImport(CoreGraphics)
func example6_batchExport() async throws {
    // Get all DICOM files from a directory
    let inputDirectory = URL(fileURLWithPath: "/path/to/study")
    let outputDirectory = URL(fileURLWithPath: "/tmp/exported")
    
    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    
    let files = try FileManager.default.contentsOfDirectory(
        at: inputDirectory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "dcm" }
    
    print("Batch exporting \(files.count) files...")
    
    for (index, fileURL) in files.enumerated() {
        do {
            let file = try DICOMFile.read(from: fileURL)
            
            guard let pixelData = file.pixelData,
                  let cgImage = try pixelData.createCGImage(frame: 0) else {
                print("⚠️  Skipping \(fileURL.lastPathComponent) - no pixel data")
                continue
            }
            
            // Use SOP Instance UID or filename
            let sopInstanceUID = file.dataSet.string(for: .sopInstanceUID) ?? UUID().uuidString
            let filename = "\(sopInstanceUID).png"
            let outputURL = outputDirectory.appendingPathComponent(filename)
            
            #if os(macOS)
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                continue
            }
            try pngData.write(to: outputURL)
            #elseif os(iOS)
            let uiImage = UIImage(cgImage: cgImage)
            guard let pngData = uiImage.pngData() else {
                continue
            }
            try pngData.write(to: outputURL)
            #endif
            
            print("  [\(index + 1)/\(files.count)] ✅ \(fileURL.lastPathComponent)")
            
        } catch {
            print("  [\(index + 1)/\(files.count)] ❌ \(fileURL.lastPathComponent) - \(error)")
        }
    }
    
    print("✅ Batch export complete")
}
#endif

// MARK: - Example 7: Export with Metadata Preservation

#if canImport(ImageIO)
func example7_exportWithMetadata() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData,
          let cgImage = try pixelData.createCGImage(frame: 0) else {
        print("❌ Failed to get image")
        return
    }
    
    let outputURL = URL(fileURLWithPath: "/tmp/output_with_metadata.png")
    
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        kUTTypePNG,
        1,
        nil
    ) else {
        throw DICOMError.corruptedData
    }
    
    // Extract DICOM metadata
    let dataSet = file.dataSet
    let patientName = dataSet.string(for: .patientName) ?? "Unknown"
    let studyDate = dataSet.string(for: .studyDate) ?? "Unknown"
    let modality = dataSet.string(for: .modality) ?? "Unknown"
    
    // Create PNG metadata dictionary
    let metadata: [CFString: Any] = [
        kCGImagePropertyPNGDescription: "Patient: \(patientName), Study: \(studyDate), Modality: \(modality)",
        kCGImagePropertyPNGSoftware: "DICOMKit"
    ]
    
    let properties: [CFString: Any] = [
        kCGImagePropertyPNGDictionary: metadata
    ]
    
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    
    if CGImageDestinationFinalize(destination) {
        print("✅ Exported PNG with metadata")
        print("   Patient: \(patientName)")
        print("   Study Date: \(studyDate)")
        print("   Modality: \(modality)")
    } else {
        throw DICOMError.corruptedData
    }
}
#endif

// MARK: - Example 8: Export to Photos Library (iOS only)

#if os(iOS) && canImport(Photos)
import Photos

func example8_exportToPhotos() async throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData,
          let cgImage = try pixelData.createCGImage(frame: 0) else {
        print("❌ Failed to get image")
        return
    }
    
    let uiImage = UIImage(cgImage: cgImage)
    
    // Request authorization
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    
    guard status == .authorized else {
        print("❌ Photo library access denied")
        return
    }
    
    // Save to Photos
    try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.creationRequestForAsset(from: uiImage)
    }
    
    print("✅ Saved to Photos library")
}
#endif

// MARK: - Example 9: Smart Format Selection

#if canImport(CoreGraphics)
func example9_smartFormatSelection() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData,
          let cgImage = try pixelData.createCGImage(frame: 0) else {
        print("❌ Failed to get image")
        return
    }
    
    // Determine best export format based on image characteristics
    let bitsStored = file.dataSet.uint16(for: .bitsStored) ?? 8
    let photometricInterpretation = file.dataSet.string(for: .photometricInterpretation) ?? ""
    
    let recommendedFormat: String
    let outputURL: URL
    
    if bitsStored > 8 {
        // 16-bit images: use TIFF to preserve dynamic range
        recommendedFormat = "TIFF"
        outputURL = URL(fileURLWithPath: "/tmp/output.tiff")
    } else if photometricInterpretation.contains("RGB") {
        // Color images: use JPEG for smaller size
        recommendedFormat = "JPEG"
        outputURL = URL(fileURLWithPath: "/tmp/output.jpg")
    } else {
        // Grayscale 8-bit: use PNG for lossless compression
        recommendedFormat = "PNG"
        outputURL = URL(fileURLWithPath: "/tmp/output.png")
    }
    
    print("✅ Recommended format: \(recommendedFormat)")
    print("   Bits Stored: \(bitsStored)")
    print("   Photometric Interpretation: \(photometricInterpretation)")
}
#endif

// MARK: - Usage Notes

/*
 Image Export Best Practices:
 
 1. Format Selection:
    - PNG: Lossless, good for 8-bit grayscale
    - JPEG: Lossy compression, good for color images
    - TIFF: Best for 16-bit images, preserves dynamic range
 
 2. Quality Considerations:
    - JPEG quality 0.8-0.95 for diagnostic images
    - Always preserve original DICOM for clinical use
    - Exported images are for display/sharing only
 
 3. Multi-frame Export:
    - Consider memory usage for large series
    - Process frames in batches if needed
    - Use async/await for responsiveness
 
 4. Window/Level:
    - Apply appropriate presets before export
    - Export multiple windows for different tissues
    - Document window settings used
 
 5. Metadata:
    - Preserve key DICOM metadata when possible
    - Remove PHI for sharing outside clinical context
    - Use ImageIO for advanced metadata handling
 
 6. Performance:
    - Batch exports benefit from parallel processing
    - Cache CGImages when exporting multiple formats
    - Monitor memory usage with large images
 
 7. iOS Photos Integration:
    - Request proper authorization
    - Handle authorization denial gracefully
    - Consider privacy implications
 
 8. Cross-platform Considerations:
    - macOS: Use NSBitmapImageRep for more format options
    - iOS: Use UIImage for simpler API
    - Both: Use ImageIO for advanced control
 */
