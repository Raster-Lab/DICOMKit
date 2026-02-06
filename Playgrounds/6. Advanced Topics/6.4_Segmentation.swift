// DICOMKit Sample Code: DICOM Segmentation (SEG IOD)
//
// This example demonstrates how to:
// - Load SEG files
// - Handle binary and fractional segmentation
// - Manage multi-segment data
// - Render segment overlays with colors
// - Calculate segment statistics
// - Create SEG from masks
// - Access segment metadata and properties
// - Convert between segmentation formats

import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Example 1: Loading SEG Files

func example1_loadSegmentation() throws {
    let segURL = URL(fileURLWithPath: "/path/to/segmentation.dcm")
    let segFile = try DICOMFile.read(from: segURL)
    
    // Verify this is a Segmentation object
    let sopClassUID = segFile.dataSet.string(for: .sopClassUID) ?? ""
    guard sopClassUID == "1.2.840.10008.5.1.4.1.1.66.4" else {
        print("Not a Segmentation object")
        return
    }
    
    print("✅ Segmentation loaded")
    
    // Parse using SegmentationParser
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    print("Content Label: \(segmentation.contentLabel ?? "Unnamed")")
    print("Content Description: \(segmentation.contentDescription ?? "N/A")")
    print("Segmentation Type: \(segmentation.segmentationType.rawValue)")
    print("Number of Segments: \(segmentation.numberOfSegments)")
    print("Dimensions: \(segmentation.columns) × \(segmentation.rows)")
    print("Number of Frames: \(segmentation.numberOfFrames)")
    
    // Fractional segmentation details
    if segmentation.segmentationType == .fractional {
        if let fractionalType = segmentation.segmentationFractionalType {
            print("Fractional Type: \(fractionalType.rawValue)")
        }
        if let maxValue = segmentation.maxFractionalValue {
            print("Max Fractional Value: \(maxValue)")
        }
    }
    
    // List all segments
    print("\nSegments:")
    for segment in segmentation.segments {
        print("  [\(segment.segmentNumber)] \(segment.segmentLabel)")
        if let desc = segment.segmentDescription {
            print("    Description: \(desc)")
        }
        if let algorithmType = segment.segmentAlgorithmType {
            print("    Algorithm: \(algorithmType.rawValue)")
        }
        if let category = segment.category {
            print("    Category: \(category.codeMeaning ?? "N/A")")
        }
    }
}

// MARK: - Example 2: Binary vs. Fractional Segmentation

func example2_binaryVsFractional() throws {
    let segURL = URL(fileURLWithPath: "/path/to/segmentation.dcm")
    let segFile = try DICOMFile.read(from: segURL)
    
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    switch segmentation.segmentationType {
    case .binary:
        print("✅ Binary Segmentation:")
        print("   Each pixel is either 0 (absent) or 1 (present)")
        print("   1 bit per pixel per segment")
        print("   Typical use: Hard tissue classification")
        
        // Binary segmentation packs multiple segments per frame
        print("   Bits Allocated: \(segmentation.bitsAllocated)")
        print("   Bits Stored: \(segmentation.bitsStored)")
        
    case .fractional:
        print("✅ Fractional Segmentation:")
        print("   Each pixel has probability/occupancy value")
        
        if let fractionalType = segmentation.segmentationFractionalType {
            switch fractionalType {
            case .probability:
                print("   Type: PROBABILITY (likelihood of segment membership)")
            case .occupancy:
                print("   Type: OCCUPANCY (fraction of voxel occupied)")
            }
        }
        
        if let maxValue = segmentation.maxFractionalValue {
            print("   Max Value: \(maxValue)")
            print("   Range: 0 to \(maxValue)")
            print("   Typical use: AI/ML predictions with confidence scores")
        }
    }
}

// MARK: - Example 3: Extracting Segment Masks

#if canImport(CoreGraphics)
func example3_extractSegmentMasks() throws {
    let segURL = URL(fileURLWithPath: "/path/to/segmentation.dcm")
    let segFile = try DICOMFile.read(from: segURL)
    
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    // Extract pixel data
    guard let pixelData = segFile.pixelData else {
        print("No pixel data")
        return
    }
    
    let extractor = SegmentationPixelDataExtractor()
    
    // Extract masks for all segments
    print("✅ Extracting segment masks:")
    
    for segment in segmentation.segments {
        do {
            let mask = try extractor.extractSegmentMask(
                segmentation: segmentation,
                pixelData: pixelData,
                segmentNumber: segment.segmentNumber,
                frameIndex: 0  // First frame
            )
            
            print("  [\(segment.segmentNumber)] \(segment.segmentLabel):")
            print("    Mask size: \(mask.count) pixels")
            
            // Count non-zero pixels
            let nonZeroCount = mask.filter { $0 > 0 }.count
            let percentage = (Double(nonZeroCount) / Double(mask.count)) * 100.0
            print("    Coverage: \(nonZeroCount) pixels (\(String(format: "%.1f", percentage))%)")
            
        } catch {
            print("  [\(segment.segmentNumber)] Error: \(error)")
        }
    }
}
#endif

// MARK: - Example 4: Rendering Segment Overlays

#if canImport(CoreGraphics)
func example4_renderSegmentOverlay() throws {
    let imageURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let segURL = URL(fileURLWithPath: "/path/to/segmentation.dcm")
    
    let imageFile = try DICOMFile.read(from: imageURL)
    let segFile = try DICOMFile.read(from: segURL)
    
    // Load segmentation
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    // Create base image
    guard let pixelData = imageFile.pixelData,
          let baseImage = try pixelData.createCGImage(frame: 0) else {
        print("Failed to create base image")
        return
    }
    
    // Extract segment masks
    guard let segPixelData = segFile.pixelData else {
        print("No segmentation pixel data")
        return
    }
    
    let extractor = SegmentationPixelDataExtractor()
    var segmentMasks: [Int: [UInt8]] = [:]
    
    for segment in segmentation.segments {
        if let mask = try? extractor.extractSegmentMask(
            segmentation: segmentation,
            pixelData: segPixelData,
            segmentNumber: segment.segmentNumber,
            frameIndex: 0
        ) {
            segmentMasks[segment.segmentNumber] = mask
        }
    }
    
    // Render overlay using SegmentationRenderer
    let renderer = SegmentationRenderer()
    let renderOptions = SegmentationRenderer.RenderOptions(
        opacity: 0.5,  // 50% transparent
        visibleSegments: nil,  // All segments visible
        customColors: nil  // Use recommended colors
    )
    
    if let overlayImage = SegmentationRenderer.renderOverlay(
        segmentation: segmentation,
        segmentMasks: segmentMasks,
        options: renderOptions
    ) {
        print("✅ Rendered segmentation overlay:")
        print("   Overlay size: \(overlayImage.width) × \(overlayImage.height)")
        
        // In a real app, composite base image + overlay
        // let composite = compositeImages(base: baseImage, overlay: overlayImage)
    }
}
#endif

// MARK: - Example 5: Custom Color Rendering

#if canImport(CoreGraphics)
func example5_customColorRendering() throws {
    let segURL = URL(fileURLWithPath: "/path/to/segmentation.dcm")
    let segFile = try DICOMFile.read(from: segURL)
    
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    // Define custom colors for specific segments
    var customColors: [Int: (r: UInt8, g: UInt8, b: UInt8)] = [:]
    
    for segment in segmentation.segments {
        switch segment.segmentLabel.lowercased() {
        case let label where label.contains("tumor"):
            customColors[segment.segmentNumber] = (255, 0, 0)  // Red
        case let label where label.contains("liver"):
            customColors[segment.segmentNumber] = (139, 69, 19)  // Brown
        case let label where label.contains("lung"):
            customColors[segment.segmentNumber] = (135, 206, 250)  // Sky blue
        case let label where label.contains("heart"):
            customColors[segment.segmentNumber] = (220, 20, 60)  // Crimson
        case let label where label.contains("kidney"):
            customColors[segment.segmentNumber] = (128, 0, 128)  // Purple
        default:
            // Use recommended display color if available
            if let cielab = segment.recommendedDisplayCIELabValue {
                let rgb = convertCIELabToRGB(cielab)
                customColors[segment.segmentNumber] = rgb
            }
        }
    }
    
    print("✅ Custom segment colors:")
    for (segmentNum, color) in customColors.sorted(by: { $0.key < $1.key }) {
        if let segment = segmentation.segments.first(where: { $0.segmentNumber == segmentNum }) {
            print("  [\(segmentNum)] \(segment.segmentLabel): RGB(\(color.r), \(color.g), \(color.b))")
        }
    }
    
    // Use in rendering
    let renderOptions = SegmentationRenderer.RenderOptions(
        opacity: 0.6,
        visibleSegments: nil,
        customColors: customColors
    )
}

func convertCIELabToRGB(_ cielab: CIELabColor) -> (r: UInt8, g: UInt8, b: UInt8) {
    // Simplified CIELab to RGB conversion
    // In production, use proper color space conversion
    
    // Normalize from 0-65535 to proper ranges
    let L = Double(cielab.l) / 65535.0 * 100.0
    let a = (Double(cielab.a) / 65535.0 - 0.5) * 256.0
    let b = (Double(cielab.b) / 65535.0 - 0.5) * 256.0
    
    // CIELab → XYZ → RGB (simplified)
    // This is a placeholder - use proper color management in production
    let r = max(0, min(255, Int((L + a) * 2.55)))
    let g = max(0, min(255, Int((L - a / 2 - b / 2) * 2.55)))
    let b_val = max(0, min(255, Int((L + b) * 2.55)))
    
    return (r: UInt8(r), g: UInt8(g), b: UInt8(b_val))
}
#endif

// MARK: - Example 6: Segment Statistics

func example6_calculateSegmentStatistics() throws {
    let segURL = URL(fileURLWithPath: "/path/to/segmentation.dcm")
    let segFile = try DICOMFile.read(from: segURL)
    
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    guard let pixelData = segFile.pixelData else {
        print("No pixel data")
        return
    }
    
    let extractor = SegmentationPixelDataExtractor()
    
    print("✅ Segment Statistics:")
    
    for segment in segmentation.segments {
        var totalPixels = 0
        var totalValue: Double = 0.0
        var minValue: UInt8 = 255
        var maxValue: UInt8 = 0
        
        // Process all frames for this segment
        for frameIndex in 0..<segmentation.numberOfFrames {
            guard let mask = try? extractor.extractSegmentMask(
                segmentation: segmentation,
                pixelData: pixelData,
                segmentNumber: segment.segmentNumber,
                frameIndex: frameIndex
            ) else {
                continue
            }
            
            for value in mask {
                if value > 0 {
                    totalPixels += 1
                    totalValue += Double(value)
                    minValue = min(minValue, value)
                    maxValue = max(maxValue, value)
                }
            }
        }
        
        print("\n[\(segment.segmentNumber)] \(segment.segmentLabel):")
        print("  Total pixels: \(totalPixels)")
        
        if totalPixels > 0 {
            let avgValue = totalValue / Double(totalPixels)
            print("  Value range: \(minValue) - \(maxValue)")
            print("  Average value: \(String(format: "%.2f", avgValue))")
            
            // Calculate volume if spacing is available
            if let pixelSpacing = getPixelSpacing(from: segmentation),
               let sliceThickness = getSliceThickness(from: segmentation) {
                let voxelVolume = pixelSpacing.0 * pixelSpacing.1 * sliceThickness  // mm³
                let totalVolume = Double(totalPixels) * voxelVolume
                print("  Volume: \(String(format: "%.2f", totalVolume / 1000.0)) cc")
            }
        } else {
            print("  No pixels in this segment")
        }
    }
}

func getPixelSpacing(from segmentation: Segmentation) -> (Double, Double)? {
    // Extract from shared functional groups or per-frame functional groups
    // This is simplified - real implementation would parse functional groups
    return (1.0, 1.0)  // Default 1mm × 1mm
}

func getSliceThickness(from segmentation: Segmentation) -> Double? {
    // Extract from functional groups
    return 1.0  // Default 1mm
}

// MARK: - Example 7: Creating SEG from Binary Masks

func example7_createSegmentationFromMasks() throws {
    // Define segments
    let segments = [
        Segment(
            segmentNumber: 1,
            segmentLabel: "Liver",
            segmentDescription: "Liver parenchyma",
            segmentAlgorithmType: .automatic,
            segmentAlgorithmName: "DeepLab v3+",
            category: CodedConcept(
                codingSchemeDesignator: "SCT",
                codeValue: "123037004",
                codeMeaning: "Anatomical Structure"
            ),
            type: CodedConcept(
                codingSchemeDesignator: "SCT",
                codeValue: "10200004",
                codeMeaning: "Liver"
            )
        ),
        Segment(
            segmentNumber: 2,
            segmentLabel: "Tumor",
            segmentDescription: "Hepatocellular carcinoma",
            segmentAlgorithmType: .semiautomatic,
            segmentAlgorithmName: "U-Net with manual correction",
            category: CodedConcept(
                codingSchemeDesignator: "SCT",
                codeValue: "49755003",
                codeMeaning: "Morphologically Altered Structure"
            ),
            type: CodedConcept(
                codingSchemeDesignator: "SCT",
                codeValue: "25370001",
                codeMeaning: "Hepatocellular Carcinoma"
            )
        )
    ]
    
    // Create binary masks (simplified example)
    let width = 512
    let height = 512
    let liverMask = Array(repeating: UInt8(0), count: width * height)
    let tumorMask = Array(repeating: UInt8(0), count: width * height)
    
    // Build segmentation using SegmentationBuilder
    let builder = SegmentationBuilder()
    
    // Set basic properties
    builder.setContentLabel("Liver Lesion Segmentation")
    builder.setContentDescription("AI-generated liver and tumor segmentation")
    builder.setSegmentationType(.binary)
    builder.setDimensions(rows: height, columns: width, frames: 1)
    
    // Add segments with their masks
    builder.addSegment(segments[0], mask: liverMask, frameIndex: 0)
    builder.addSegment(segments[1], mask: tumorMask, frameIndex: 0)
    
    // Build the segmentation object
    // let segmentation = try builder.build()
    
    print("✅ Created segmentation with \(segments.count) segments")
}

// MARK: - Example 8: Multi-Frame Segmentation

func example8_multiFrameSegmentation() throws {
    let segURL = URL(fileURLWithPath: "/path/to/multislice_seg.dcm")
    let segFile = try DICOMFile.read(from: segURL)
    
    let parser = SegmentationParser()
    let segmentation = try parser.parse(from: segFile)
    
    print("✅ Multi-Frame Segmentation:")
    print("   Total frames: \(segmentation.numberOfFrames)")
    print("   Segments: \(segmentation.numberOfSegments)")
    
    // Each frame may contain different segments
    // Per-Frame Functional Groups specify which segment each frame contains
    
    if segmentation.perFrameFunctionalGroups.count > 0 {
        print("\nFrame Analysis:")
        
        for (frameIndex, functionalGroup) in segmentation.perFrameFunctionalGroups.enumerated() {
            // Extract segment number for this frame
            // Real implementation would parse the functional group sequence
            print("  Frame \(frameIndex + 1):")
            // print("    Segment: \(segmentNumber)")
            // print("    Referenced Image: \(referencedImageUID)")
        }
    }
    
    // Frame organization strategies:
    // 1. One segment per frame (sparse)
    // 2. All segments in each frame (dense)
    // 3. Hybrid approach
    
    print("\nExtraction Strategy:")
    if segmentation.numberOfFrames == segmentation.numberOfSegments {
        print("  One frame per segment (sparse encoding)")
    } else if segmentation.numberOfFrames > segmentation.numberOfSegments {
        print("  Multiple slices per segment")
    }
}

// MARK: - Example 9: Segment Visibility Management

#if canImport(SwiftUI)
import SwiftUI

struct SegmentVisibilityControl: View {
    let segmentation: Segmentation
    @Binding var visibleSegments: Set<Int>
    @Binding var segmentOpacity: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Segments")
                .font(.headline)
            
            // Opacity slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity: \(Int(segmentOpacity * 100))%")
                    .font(.subheadline)
                
                Slider(value: $segmentOpacity, in: 0.0...1.0)
            }
            
            Divider()
            
            // Segment list with toggles
            ForEach(segmentation.segments) { segment in
                HStack {
                    // Color indicator
                    if let cielab = segment.recommendedDisplayCIELabValue {
                        let rgb = convertCIELabToRGB(cielab)
                        Circle()
                            .fill(Color(
                                red: Double(rgb.r) / 255.0,
                                green: Double(rgb.g) / 255.0,
                                blue: Double(rgb.b) / 255.0
                            ))
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 20, height: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.segmentLabel)
                            .font(.body)
                        
                        if let desc = segment.segmentDescription {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { visibleSegments.contains(segment.segmentNumber) },
                        set: { isVisible in
                            if isVisible {
                                visibleSegments.insert(segment.segmentNumber)
                            } else {
                                visibleSegments.remove(segment.segmentNumber)
                            }
                        }
                    ))
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

// Usage:
// @State private var visibleSegments: Set<Int> = [1, 2, 3]
// @State private var segmentOpacity: Double = 0.5
// SegmentVisibilityControl(
//     segmentation: loadedSegmentation,
//     visibleSegments: $visibleSegments,
//     segmentOpacity: $segmentOpacity
// )
#endif

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_loadSegmentation()
// try? example2_binaryVsFractional()
// try? example3_extractSegmentMasks()

// MARK: - Quick Reference

/*
 DICOM Segmentation (SEG IOD):
 
 SOP Class UID:
 • 1.2.840.10008.5.1.4.1.1.66.4 - Segmentation Storage
 
 Key Concepts:
 • Segmentation       - Labeled pixel regions
 • Segment            - Individual structure/region definition
 • Binary             - Presence/absence (1-bit per pixel)
 • Fractional         - Probability/occupancy (8 or 16-bit)
 • Multi-Segment      - Multiple segments in one object
 
 DICOM Tags (Segmentation Module):
 • (0062,0001) - Segmentation Type (BINARY, FRACTIONAL)
 • (0062,0002) - Segment Sequence
 • (0062,0003) - Segmentation Fractional Type
 • (0062,0010) - Segment Identification Sequence
 • (0062,000E) - Maximum Fractional Value
 
 DICOM Tags (Segment Description):
 • (0062,0004) - Segment Number
 • (0062,0005) - Segment Label
 • (0062,0006) - Segment Description
 • (0062,0008) - Segment Algorithm Type
 • (0062,0009) - Segment Algorithm Name
 • (0062,000A) - Segment Category Code Sequence
 • (0062,000B) - Segment Type Code Sequence
 • (0062,000D) - Recommended Display CIELab Value
 • (0062,0020) - Tracking ID
 • (0062,0021) - Tracking UID
 
 Segmentation Types:
 • BINARY      - Each pixel is 0 or 1 (present/absent)
 • FRACTIONAL  - Each pixel has value 0 to maxValue
 
 Fractional Types:
 • PROBABILITY - Likelihood of segment membership (0.0 to 1.0)
 • OCCUPANCY   - Fraction of voxel occupied (0.0 to 1.0)
 
 Segment Algorithm Types:
 • AUTOMATIC      - Fully automatic (AI/ML)
 • SEMIAUTOMATIC  - Semi-automatic (with user input)
 • MANUAL         - Manual delineation
 
 Binary Segmentation:
 • 1 bit per pixel per segment
 • Packed into bytes (8 segments per byte)
 • Efficient for hard classifications
 • Typical use: Tissue segmentation, organ masks
 
 Fractional Segmentation:
 • 8 or 16 bits per pixel per segment
 • Values from 0 to maxFractionalValue
 • Supports soft/probabilistic segmentations
 • Typical use: AI predictions, fuzzy segmentation
 
 Multi-Segment Organization:
 • Each segment has unique number (1 to n)
 • Segments stored in separate frames or packed
 • Segment Sequence defines all segments
 • Per-Frame Functional Groups map frames to segments
 
 Frame Organization:
 • Sparse: One frame per segment
 • Dense: All segments in each frame
 • Hybrid: Variable segments per frame
 
 Segment Colors:
 • Recommended Display CIELab Value
 • CIELab color space (L: 0-100, a/b: -128 to 127)
 • Stored as unsigned 16-bit (0-65535)
 • Convert to RGB for display
 
 CIELab to RGB Conversion:
 1. Denormalize CIELab values
 2. CIELab → XYZ color space
 3. XYZ → RGB color space
 4. Apply gamma correction
 5. Clamp to 0-255 range
 
 Overlay Rendering:
 • Extract segment mask for each segment
 • Convert to colored overlay (using segment color)
 • Apply opacity (alpha blending)
 • Composite with base image
 • Support visibility toggling
 
 Segment Statistics:
 • Pixel count (number of labeled pixels)
 • Coverage percentage (labeled / total pixels)
 • Volume (pixel count × voxel volume)
 • Mean/min/max values (for fractional)
 • Centroid position
 • Bounding box
 
 Volume Calculation:
 • Count pixels with value > 0
 • Get voxel dimensions from pixel spacing
 • Formula: volume = count × spacingX × spacingY × spacingZ
 • Units: mm³ (divide by 1000 for cc)
 
 Creating Segmentation:
 1. Define segments with metadata
 2. Generate or load binary/fractional masks
 3. Use SegmentationBuilder to construct object
 4. Set dimensions, type, content labels
 5. Add segments with masks
 6. Reference source images
 7. Save as DICOM file
 
 Segment Metadata:
 • Label: Human-readable name
 • Description: Detailed description
 • Algorithm: Type and name of algorithm used
 • Category: Coded anatomical/morphological category
 • Type: Specific structure type (SNOMED, etc.)
 • Anatomic Region: Body part
 • Tracking ID/UID: For longitudinal studies
 
 Coded Concepts:
 • Use SNOMED CT, FMA, or other terminologies
 • Format: (Scheme, Code, Meaning)
 • Example: (SCT, 10200004, "Liver")
 • Enables semantic interoperability
 
 Referenced Images:
 • Segmentation references source images
 • Use Referenced Series Sequence
 • Match Frame of Reference UID
 • Per-frame references for multi-frame sources
 
 Functional Groups:
 • Shared Functional Groups (common to all frames)
 • Per-Frame Functional Groups (unique per frame)
 • Contains: Segment ID, Referenced Image, Position, etc.
 • Essential for multi-frame segmentations
 
 Common Use Cases:
 • AI/ML model outputs (organ segmentation)
 • Tumor/lesion delineation
 • Tissue classification
 • CAD results (detection probability maps)
 • Atlas-based segmentation
 • Multi-organ segmentation
 • Pathology quantification
 
 Workflow:
 1. Load DICOM Segmentation
 2. Parse segment definitions
 3. Extract masks for each segment
 4. Render overlays on source images
 5. Calculate statistics (volume, coverage)
 6. Support interactive editing
 7. Export results or re-save as DICOM
 
 Performance Tips:
 1. Cache extracted masks per segment
 2. Use GPU for overlay rendering
 3. Lazy load frames for large datasets
 4. Downsample for preview, full-res for analysis
 5. Parallelize segment extraction
 6. Use SIMD for mask processing
 7. Compress masks in memory (RLE)
 8. Stream frames from disk if memory limited
 
 Quality Checks:
 1. Verify segment numbers are unique
 2. Check segmentation type matches data
 3. Validate fractional values <= maxFractionalValue
 4. Ensure dimensions match source images
 5. Verify Frame of Reference UID matches
 6. Check for overlapping segments (if applicable)
 7. Validate coded concepts against terminologies
 
 Interoperability:
 • DICOM SEG is the standard for medical imaging
 • Export to NIFTI, NRRD for research tools
 • Import from common formats (PNG masks, etc.)
 • Support conversion to/from RT Structure Sets
 • Maintain provenance (algorithm, creator, date)
 
 Tips:
 
 1. Always check segmentation type (binary vs. fractional)
 2. Use recommended display colors for consistency
 3. Support visibility toggle for each segment
 4. Calculate volumes for clinical reporting
 5. Provide segment editing capabilities
 6. Validate against source image dimensions
 7. Use coded concepts for semantic interoperability
 8. Track algorithm provenance for reproducibility
 9. Implement undo/redo for manual editing
 10. Export composite images for presentation
 */
