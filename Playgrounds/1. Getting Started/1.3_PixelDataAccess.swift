// DICOMKit Sample Code: Pixel Data Access
//
// This example demonstrates how to:
// - Extract pixel data from DICOM files
// - Understand photometric interpretation
// - Create CGImage for display on Apple platforms
// - Handle multi-frame images
// - Access raw pixel values
// - Apply window/level transformations

import DICOMKit
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Example 1: Basic Pixel Data Access

func example1_basicPixelData() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    // Check if file has pixel data
    guard let pixelData = file.pixelData else {
        print("No pixel data found in this file")
        return
    }
    
    // Access pixel data descriptor
    let descriptor = pixelData.descriptor
    
    print("=== Pixel Data Information ===")
    print("Dimensions: \(descriptor.columns) × \(descriptor.rows)")
    print("Number of Frames: \(descriptor.numberOfFrames)")
    print("Bits Allocated: \(descriptor.bitsAllocated)")
    print("Bits Stored: \(descriptor.bitsStored)")
    print("High Bit: \(descriptor.highBit)")
    print("Pixel Representation: \(descriptor.isSigned ? "Signed" : "Unsigned")")
    print("Samples Per Pixel: \(descriptor.samplesPerPixel)")
    print("Photometric Interpretation: \(descriptor.photometricInterpretation)")
    
    if descriptor.samplesPerPixel > 1 {
        print("Planar Configuration: \(descriptor.planarConfiguration ?? 0)")
    }
    
    // Computed properties
    print("\nComputed Properties:")
    print("Pixels Per Frame: \(descriptor.pixelsPerFrame)")
    print("Bytes Per Frame: \(descriptor.bytesPerFrame)")
    print("Bytes Per Sample: \(descriptor.bytesPerSample)")
}

// MARK: - Example 2: Creating CGImage for Display

#if canImport(CoreGraphics)
func example2_createCGImage() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Create a CGImage from the first frame
    if let cgImage = try pixelData.createCGImage(frame: 0) {
        print("✅ Created CGImage: \(cgImage.width) × \(cgImage.height)")
        
        #if canImport(UIKit)
        // On iOS: Create UIImage
        let uiImage = UIImage(cgImage: cgImage)
        print("Created UIImage for display")
        // Display in UIImageView: imageView.image = uiImage
        #elseif canImport(AppKit)
        // On macOS: Create NSImage
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)
        print("Created NSImage for display")
        // Display in NSImageView: imageView.image = nsImage
        #endif
    } else {
        print("❌ Could not create CGImage")
    }
}
#endif

// MARK: - Example 3: Applying Window/Level

#if canImport(CoreGraphics)
func example3_windowLevel() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let dataSet = file.dataSet
    
    // Get window/level from DICOM tags (if present)
    let windowCenter = dataSet.float64(for: .windowCenter) ?? 40.0
    let windowWidth = dataSet.float64(for: .windowWidth) ?? 400.0
    
    print("Window Center: \(windowCenter)")
    print("Window Width: \(windowWidth)")
    
    // Create windowed image
    if let cgImage = try pixelData.createCGImage(
        frame: 0,
        windowCenter: windowCenter,
        windowWidth: windowWidth
    ) {
        print("✅ Created windowed CGImage")
        
        // Try different window presets
        let lungWindow = (center: -600.0, width: 1500.0)
        let boneWindow = (center: 400.0, width: 1800.0)
        let softTissueWindow = (center: 40.0, width: 400.0)
        
        if let lungImage = try pixelData.createCGImage(
            frame: 0,
            windowCenter: lungWindow.center,
            windowWidth: lungWindow.width
        ) {
            print("✅ Created lung window image")
        }
    }
}
#endif

// MARK: - Example 4: Multi-Frame Images

#if canImport(CoreGraphics)
func example4_multiFrame() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let frameCount = pixelData.descriptor.numberOfFrames
    print("Number of frames: \(frameCount)")
    
    if frameCount > 1 {
        print("This is a multi-frame image")
        
        // Create images for each frame
        for frameIndex in 0..<frameCount {
            if let cgImage = try pixelData.createCGImage(frame: frameIndex) {
                print("Frame \(frameIndex): \(cgImage.width) × \(cgImage.height)")
                
                // In a real app, you might store these in an array for cine playback
                // frames.append(cgImage)
            }
        }
        
        // Example: Create images for specific frames only
        let framesToLoad = [0, frameCount / 2, frameCount - 1] // First, middle, last
        for frameIndex in framesToLoad where frameIndex < frameCount {
            if let cgImage = try pixelData.createCGImage(frame: frameIndex) {
                print("Loaded keyframe \(frameIndex)")
            }
        }
    } else {
        print("This is a single-frame image")
    }
}
#endif

// MARK: - Example 5: Raw Pixel Value Access

func example5_rawPixelValues() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Get raw pixel data for a frame
    if let frameData = pixelData.frameData(at: 0) {
        print("Frame data size: \(frameData.count) bytes")
        
        // Access first few bytes
        let firstBytes = frameData.prefix(10)
        print("First 10 bytes: \(firstBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    // Get pixel value at specific location
    if let pixelValue = pixelData.pixelValue(row: 100, column: 100, frame: 0) {
        print("Pixel value at (100, 100): \(pixelValue)")
    }
    
    // Get all pixel values for a frame (memory intensive for large images!)
    if let allPixels = pixelData.pixelValues(forFrame: 0) {
        print("Total pixels in frame: \(allPixels.count)")
        
        // Calculate statistics
        if !allPixels.isEmpty {
            let min = allPixels.min() ?? 0
            let max = allPixels.max() ?? 0
            let sum = allPixels.reduce(0, +)
            let mean = Double(sum) / Double(allPixels.count)
            
            print("Min pixel value: \(min)")
            print("Max pixel value: \(max)")
            print("Mean pixel value: \(mean)")
        }
    }
}

// MARK: - Example 6: Color Images

#if canImport(CoreGraphics)
func example6_colorImages() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/color_file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let descriptor = pixelData.descriptor
    
    // Check if this is a color image
    if descriptor.samplesPerPixel == 3 {
        print("This is a color image")
        print("Photometric Interpretation: \(descriptor.photometricInterpretation)")
        
        // Common color photometric interpretations:
        // - "RGB" - Red, Green, Blue
        // - "YBR_FULL" - YCbCr color space
        // - "PALETTE COLOR" - Uses a color palette/LUT
        
        // Access RGB color value at specific location
        if let (r, g, b) = pixelData.colorValue(row: 100, column: 100, frame: 0) {
            print("RGB at (100, 100): R=\(r), G=\(g), B=\(b)")
        }
        
        // Create CGImage (DICOMKit handles color space conversion)
        if let cgImage = try pixelData.createCGImage(frame: 0) {
            print("✅ Created color CGImage")
        }
    } else if descriptor.samplesPerPixel == 1 {
        print("This is a grayscale image")
        print("Photometric Interpretation: \(descriptor.photometricInterpretation)")
        
        // Common grayscale interpretations:
        // - "MONOCHROME1" - 0 = white, max = black (inverted)
        // - "MONOCHROME2" - 0 = black, max = white (normal)
    }
}
#endif

// MARK: - Example 7: Pixel Data Statistics

func example7_pixelStatistics() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Get pixel range for a frame (min and max values)
    if let (min, max) = pixelData.pixelRange(forFrame: 0) {
        print("Pixel value range: \(min) to \(max)")
        print("Dynamic range: \(max - min)")
        
        // Suggest window/level based on range
        let suggestedCenter = Double(min + max) / 2.0
        let suggestedWidth = Double(max - min)
        print("Suggested window: C=\(suggestedCenter), W=\(suggestedWidth)")
    }
}

// MARK: - Example 8: Checking Photometric Interpretation

func example8_photometricInterpretation() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let photoInterp = pixelData.descriptor.photometricInterpretation
    
    print("Photometric Interpretation: \(photoInterp)")
    
    switch photoInterp {
    case "MONOCHROME1":
        print("Grayscale - 0 is white (inverted)")
        print("Tip: May need to invert for natural display")
        
    case "MONOCHROME2":
        print("Grayscale - 0 is black (normal)")
        
    case "RGB":
        print("Color - Red, Green, Blue")
        print("Samples per pixel: \(pixelData.descriptor.samplesPerPixel)")
        
    case "PALETTE COLOR":
        print("Indexed color - Uses color lookup table")
        print("Need to apply color palette for display")
        
    case "YBR_FULL", "YBR_FULL_422", "YBR_PARTIAL_422":
        print("Color - YCbCr color space")
        print("DICOMKit will convert to RGB for display")
        
    default:
        print("Other photometric interpretation: \(photoInterp)")
    }
}

// MARK: - Example 9: Bit Depth Information

func example9_bitDepth() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let descriptor = pixelData.descriptor
    
    print("=== Bit Depth Information ===")
    print("Bits Allocated: \(descriptor.bitsAllocated)")
    print("Bits Stored: \(descriptor.bitsStored)")
    print("High Bit: \(descriptor.highBit)")
    print("Signed: \(descriptor.isSigned)")
    
    // Interpret bit depth
    if descriptor.bitsAllocated == 8 {
        print("8-bit image (256 gray levels)")
    } else if descriptor.bitsAllocated == 16 {
        print("16-bit image (up to 65536 gray levels)")
        
        if descriptor.bitsStored < 16 {
            print("  Actually using \(descriptor.bitsStored) bits")
            let levels = 1 << descriptor.bitsStored
            print("  Effective gray levels: \(levels)")
        }
    }
    
    // Calculate value range
    if descriptor.isSigned {
        let maxPositive = (1 << (descriptor.bitsStored - 1)) - 1
        let maxNegative = -(1 << (descriptor.bitsStored - 1))
        print("Value range: \(maxNegative) to \(maxPositive)")
    } else {
        let maxValue = (1 << descriptor.bitsStored) - 1
        print("Value range: 0 to \(maxValue)")
    }
}

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_basicPixelData()
// try? example2_createCGImage()
// try? example3_windowLevel()
// try? example4_multiFrame()
// try? example5_rawPixelValues()
// try? example6_colorImages()
// try? example7_pixelStatistics()
// try? example8_photometricInterpretation()
// try? example9_bitDepth()

// MARK: - Quick Reference

/*
 DICOMKit Pixel Data Access:
 
 Main Types:
 • PixelData                          - Container for pixel data
 • PixelDataDescriptor                - Metadata about pixel data
 
 Accessing Pixel Data:
 • file.pixelData                     → PixelData?
 • pixelData.descriptor               → PixelDataDescriptor
 • pixelData.data                     → Data (raw bytes)
 
 Descriptor Properties:
 • .rows, .columns                    - Image dimensions
 • .numberOfFrames                    - Number of frames
 • .bitsAllocated, .bitsStored        - Bit depth
 • .highBit                           - High bit position
 • .isSigned                          - Signed vs unsigned
 • .samplesPerPixel                   - 1=grayscale, 3=color
 • .photometricInterpretation         - Color interpretation
 • .planarConfiguration               - Color data layout (if RGB)
 • .pixelsPerFrame                    - Total pixels per frame
 • .bytesPerFrame                     - Bytes per frame
 • .bytesPerSample                    - Bytes per pixel component
 
 Creating Images (iOS/macOS):
 • .createCGImage(frame:)                           → CGImage?
 • .createCGImage(frame:windowCenter:windowWidth:)  → CGImage?
 
 Raw Pixel Access:
 • .frameData(at:)                    → Data?
 • .pixelValue(row:column:frame:)     → Int?
 • .pixelValues(forFrame:)            → [Int]?
 • .allPixelValues()                  → [[Int]]?
 • .colorValue(row:column:frame:)     → (red, green, blue)?
 • .pixelRange(forFrame:)             → (min, max)?
 
 Common Photometric Interpretations:
 • "MONOCHROME1"      - Grayscale inverted (0=white)
 • "MONOCHROME2"      - Grayscale normal (0=black)
 • "RGB"              - Red, Green, Blue color
 • "PALETTE COLOR"    - Indexed color
 • "YBR_FULL"         - YCbCr color space
 
 Window/Level:
 • Window Center      - Middle gray value
 • Window Width       - Range of values to display
 • Formula:           - output = (pixel - (center - width/2)) / width
 
 Common Window Presets (for CT):
 • Lung:      C=-600,  W=1500
 • Bone:      C=400,   W=1800
 • Soft:      C=40,    W=400
 • Brain:     C=40,    W=80
 • Liver:     C=30,    W=150
 
 Tips:
 
 1. Always check if pixelData exists before accessing
 2. Multi-frame images have numberOfFrames > 1
 3. Use createCGImage() for easy display on Apple platforms
 4. Apply window/level for medical images (CT, MR)
 5. MONOCHROME1 may need inversion for natural appearance
 6. Color images (RGB) have samplesPerPixel = 3
 7. Large images: avoid loading all pixel values at once
 8. Frame index is 0-based
 9. Use pixelRange() to auto-calculate window/level
 */
