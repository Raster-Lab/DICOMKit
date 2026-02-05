// DICOMKit Sample Code: Window/Level Adjustments
//
// This example demonstrates how to:
// - Apply window/level (W/L) transformations
// - Use common window presets for different tissues
// - Calculate optimal window settings
// - Implement interactive W/L adjustment
// - Handle VOI LUT modules

import DICOMKit
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Example 1: Basic Window/Level

#if canImport(CoreGraphics)
func example1_basicWindowLevel() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Get default window/level from DICOM tags
    let dataSet = file.dataSet
    let windowCenter = dataSet.float64(for: .windowCenter) ?? 40.0
    let windowWidth = dataSet.float64(for: .windowWidth) ?? 400.0
    
    print("Default Window/Level:")
    print("  Center: \(windowCenter)")
    print("  Width: \(windowWidth)")
    
    // Create windowed image
    if let cgImage = try pixelData.createCGImage(
        frame: 0,
        windowCenter: windowCenter,
        windowWidth: windowWidth
    ) {
        print("✅ Created windowed image")
        print("   Size: \(cgImage.width) × \(cgImage.height)")
    }
}
#endif

// MARK: - Example 2: Common Window Presets for CT

struct WindowPreset {
    let name: String
    let center: Double
    let width: Double
    
    static let lung = WindowPreset(name: "Lung", center: -600, width: 1500)
    static let bone = WindowPreset(name: "Bone", center: 400, width: 1800)
    static let softTissue = WindowPreset(name: "Soft Tissue", center: 40, width: 400)
    static let brain = WindowPreset(name: "Brain", center: 40, width: 80)
    static let liver = WindowPreset(name: "Liver", center: 30, width: 150)
    static let mediastinum = WindowPreset(name: "Mediastinum", center: 50, width: 350)
    static let abdomen = WindowPreset(name: "Abdomen", center: 60, width: 400)
}

#if canImport(CoreGraphics)
func example2_windowPresets() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Apply different window presets
    let presets: [WindowPreset] = [
        .lung, .bone, .softTissue, .brain, .liver, .mediastinum
    ]
    
    for preset in presets {
        if let cgImage = try pixelData.createCGImage(
            frame: 0,
            windowCenter: preset.center,
            windowWidth: preset.width
        ) {
            print("✅ \(preset.name) window: C=\(preset.center), W=\(preset.width)")
            // In a real app, display these side-by-side or allow user to switch
        }
    }
}
#endif

// MARK: - Example 3: Auto Window/Level from Pixel Range

#if canImport(CoreGraphics)
func example3_autoWindowLevel() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Calculate window/level from actual pixel values
    if let (minValue, maxValue) = pixelData.pixelRange(forFrame: 0) {
        print("Pixel value range: \(minValue) to \(maxValue)")
        
        // Calculate center and width
        let autoCenter = Double(minValue + maxValue) / 2.0
        let autoWidth = Double(maxValue - minValue)
        
        print("Auto Window/Level:")
        print("  Center: \(autoCenter)")
        print("  Width: \(autoWidth)")
        
        // Create image with auto window
        if let cgImage = try pixelData.createCGImage(
            frame: 0,
            windowCenter: autoCenter,
            windowWidth: autoWidth
        ) {
            print("✅ Created auto-windowed image")
        }
        
        // You can also exclude extremes (e.g., use 5th-95th percentile)
        // This requires loading all pixel values
        if let allPixels = pixelData.pixelValues(forFrame: 0) {
            let sorted = allPixels.sorted()
            let p5 = sorted[sorted.count / 20]  // 5th percentile
            let p95 = sorted[sorted.count * 19 / 20]  // 95th percentile
            
            let robustCenter = Double(p5 + p95) / 2.0
            let robustWidth = Double(p95 - p5)
            
            print("Robust Window/Level (5-95 percentile):")
            print("  Center: \(robustCenter)")
            print("  Width: \(robustWidth)")
        }
    }
}
#endif

// MARK: - Example 4: Interactive Window/Level Adjustment

class WindowLevelAdjuster {
    private(set) var windowCenter: Double
    private(set) var windowWidth: Double
    
    // Sensitivity for adjustments (adjust based on image range)
    let sensitivity: Double
    
    init(center: Double, width: Double, sensitivity: Double = 1.0) {
        self.windowCenter = center
        self.windowWidth = width
        self.sensitivity = sensitivity
    }
    
    // Adjust based on mouse/touch delta (e.g., in pixels)
    func adjust(deltaX: Double, deltaY: Double) {
        // Common convention:
        // - Horizontal movement adjusts window width
        // - Vertical movement adjusts window center
        
        windowWidth += deltaX * sensitivity
        windowCenter += deltaY * sensitivity
        
        // Ensure width is always positive
        windowWidth = max(1.0, windowWidth)
        
        print("Adjusted W/L: C=\(windowCenter), W=\(windowWidth)")
    }
    
    // Reset to default
    func reset(center: Double, width: Double) {
        self.windowCenter = center
        self.windowWidth = width
        print("Reset W/L: C=\(windowCenter), W=\(windowWidth)")
    }
    
    // Apply preset
    func applyPreset(_ preset: WindowPreset) {
        self.windowCenter = preset.center
        self.windowWidth = preset.width
        print("Applied \(preset.name) preset: C=\(windowCenter), W=\(windowWidth)")
    }
}

func example4_interactiveAdjustment() {
    // Initial window/level
    let adjuster = WindowLevelAdjuster(center: 40, width: 400, sensitivity: 2.0)
    
    // Simulate user dragging
    print("Initial: C=\(adjuster.windowCenter), W=\(adjuster.windowWidth)")
    
    // User drags right and up
    adjuster.adjust(deltaX: 50, deltaY: -20)
    
    // Apply a preset
    adjuster.applyPreset(.lung)
    
    // Reset to default
    adjuster.reset(center: 40, width: 400)
}

// MARK: - Example 5: Multiple Window/Level Values

#if canImport(CoreGraphics)
func example5_multipleWindows() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Some DICOM files have multiple window/level values
    // e.g., for different tissue types
    
    if let centerStrings = dataSet.strings(for: .windowCenter),
       let widthStrings = dataSet.strings(for: .windowWidth) {
        
        print("File contains \(centerStrings.count) window/level settings:")
        
        for (index, (centerStr, widthStr)) in zip(centerStrings, widthStrings).enumerated() {
            if let center = Double(centerStr),
               let width = Double(widthStr) {
                print("  \(index + 1). C=\(center), W=\(width)")
                
                // Get window explanation if available
                if let explanations = dataSet.strings(for: .windowCenterWidthExplanation),
                   index < explanations.count {
                    print("     \(explanations[index])")
                }
                
                // Create image for this window
                if let cgImage = try pixelData.createCGImage(
                    frame: 0,
                    windowCenter: center,
                    windowWidth: width
                ) {
                    print("     ✅ Image created")
                }
            }
        }
    } else {
        print("Single window/level or not specified")
    }
}
#endif

// MARK: - Example 6: Manual Window/Level Calculation

func example6_manualCalculation() {
    // Window/Level defines linear transformation from pixel values to display values
    
    let windowCenter: Double = 40.0
    let windowWidth: Double = 400.0
    let pixelValue: Int = 100
    
    // Calculate window boundaries
    let windowMin = windowCenter - (windowWidth / 2.0)
    let windowMax = windowCenter + (windowWidth / 2.0)
    
    print("Window range: \(windowMin) to \(windowMax)")
    
    // Map pixel value to display value (0-255 for 8-bit display)
    func mapToDisplayValue(_ pixel: Int) -> UInt8 {
        let p = Double(pixel)
        
        if p <= windowMin {
            return 0  // Below window: black
        } else if p >= windowMax {
            return 255  // Above window: white
        } else {
            // Linear interpolation
            let normalized = (p - windowMin) / windowWidth
            return UInt8(normalized * 255.0)
        }
    }
    
    let displayValue = mapToDisplayValue(pixelValue)
    print("Pixel value \(pixelValue) → Display value \(displayValue)")
    
    // Test boundary values
    print("\nBoundary tests:")
    print("  -200 → \(mapToDisplayValue(-200))")
    print("  \(Int(windowMin)) → \(mapToDisplayValue(Int(windowMin)))")
    print("  \(Int(windowCenter)) → \(mapToDisplayValue(Int(windowCenter)))")
    print("  \(Int(windowMax)) → \(mapToDisplayValue(Int(windowMax)))")
    print("  500 → \(mapToDisplayValue(500))")
}

// MARK: - Example 7: VOI LUT Module

#if canImport(CoreGraphics)
func example7_voiLUT() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // VOI LUT (Value of Interest Lookup Table) Module
    // Defines how to map stored pixel values to values for display
    
    // Check for VOI LUT Sequence
    if let voiLUTElement = dataSet[.voiLUTSequence],
       case .sequence(let items) = voiLUTElement.value,
       let firstLUT = items.first {
        
        print("File contains VOI LUT Sequence")
        
        // LUT Descriptor defines LUT structure
        if let descriptorStrings = firstLUT.strings(for: .lutDescriptor),
           descriptorStrings.count >= 3 {
            let numberOfEntries = Int(descriptorStrings[0]) ?? 0
            let firstMappedValue = Int(descriptorStrings[1]) ?? 0
            let bitsPerEntry = Int(descriptorStrings[2]) ?? 0
            
            print("LUT Descriptor:")
            print("  Entries: \(numberOfEntries)")
            print("  First Mapped Value: \(firstMappedValue)")
            print("  Bits Per Entry: \(bitsPerEntry)")
        }
        
        // LUT Data contains the actual lookup table
        if let lutData = firstLUT[.lutData] {
            print("LUT Data present")
            // Parse and apply LUT (implementation depends on data format)
        }
        
        // LUT Explanation
        if let explanation = firstLUT.string(for: .lutExplanation) {
            print("Explanation: \(explanation)")
        }
    } else {
        print("No VOI LUT Sequence - using Window Center/Width")
        
        // Fall back to Window Center/Width
        if let center = dataSet.float64(for: .windowCenter),
           let width = dataSet.float64(for: .windowWidth) {
            print("Window Center: \(center)")
            print("Window Width: \(width)")
        }
    }
}
#endif

// MARK: - Example 8: Modality LUT

func example8_modalityLUT() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Modality LUT transforms stored pixel values to modality values (e.g., Hounsfield Units for CT)
    
    // Check Rescale Intercept and Slope (most common method)
    let rescaleIntercept = dataSet.float64(for: .rescaleIntercept) ?? 0.0
    let rescaleSlope = dataSet.float64(for: .rescaleSlope) ?? 1.0
    
    print("Modality LUT (Rescale):")
    print("  Intercept: \(rescaleIntercept)")
    print("  Slope: \(rescaleSlope)")
    
    // For CT, rescale type is typically "HU" (Hounsfield Units)
    if let rescaleType = dataSet.string(for: .rescaleType) {
        print("  Type: \(rescaleType)")
    }
    
    // Convert stored pixel value to Hounsfield Units
    let storedValue: Double = 2000
    let hounsfield = storedValue * rescaleSlope + rescaleIntercept
    print("Stored value \(storedValue) → \(hounsfield) HU")
    
    // Example values in HU:
    print("\nTypical Hounsfield Units:")
    print("  Air: -1000 HU")
    print("  Lung: -500 HU")
    print("  Fat: -100 to -50 HU")
    print("  Water: 0 HU")
    print("  Soft tissue: +40 to +80 HU")
    print("  Bone: +400 to +1000 HU")
    
    // Alternatively, check for Modality LUT Sequence (less common)
    if let modalityLUTElement = dataSet[.modalityLUTSequence],
       case .sequence = modalityLUTElement.value {
        print("\nFile also contains Modality LUT Sequence")
    }
}

// MARK: - Example 9: Window/Level for MR Images

#if canImport(CoreGraphics)
func example9_mrWindowLevel() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/mr/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // MR images don't have standardized units like CT
    // Window/level is often based on signal intensity
    
    print("MR Image:")
    if let modality = dataSet.string(for: .modality) {
        print("  Modality: \(modality)")
    }
    if let sequenceName = dataSet.string(for: .sequenceName) {
        print("  Sequence: \(sequenceName)")
    }
    
    // Auto-calculate from image statistics
    if let (minValue, maxValue) = pixelData.pixelRange(forFrame: 0) {
        // For MR, often use full range
        let center = Double(minValue + maxValue) / 2.0
        let width = Double(maxValue - minValue)
        
        print("Auto W/L: C=\(center), W=\(width)")
        
        if let cgImage = try pixelData.createCGImage(
            frame: 0,
            windowCenter: center,
            windowWidth: width
        ) {
            print("✅ Created MR image with auto window")
        }
    }
    
    // Some MR images may have recommended window/level
    if let center = dataSet.float64(for: .windowCenter),
       let width = dataSet.float64(for: .windowWidth) {
        print("Recommended W/L: C=\(center), W=\(width)")
    }
}
#endif

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_basicWindowLevel()
// try? example2_windowPresets()
// try? example3_autoWindowLevel()
// example4_interactiveAdjustment()
// try? example5_multipleWindows()
// example6_manualCalculation()
// try? example7_voiLUT()
// try? example8_modalityLUT()
// try? example9_mrWindowLevel()

// MARK: - Quick Reference

/*
 Window/Level Concepts:
 
 Definition:
 • Window Center (C)  - Middle gray value to display
 • Window Width (W)   - Range of values to display
 • Window Min         - C - W/2
 • Window Max         - C + W/2
 
 Linear Transformation:
 • Values ≤ Window Min  → Black (0)
 • Values ≥ Window Max  → White (255)
 • Values in between    → Linear interpolation
 
 Formula:
 • displayValue = ((pixelValue - windowMin) / windowWidth) × 255
 • windowMin = windowCenter - (windowWidth / 2)
 • windowMax = windowCenter + (windowWidth / 2)
 
 Common CT Window Presets:
 • Lung:         C=-600,  W=1500
 • Bone:         C=400,   W=1800
 • Soft Tissue:  C=40,    W=400
 • Brain:        C=40,    W=80
 • Liver:        C=30,    W=150
 • Mediastinum:  C=50,    W=350
 • Abdomen:      C=60,    W=400
 
 DICOM Tags:
 • .windowCenter (0028,1050)       - Window center value(s)
 • .windowWidth (0028,1051)        - Window width value(s)
 • .windowCenterWidthExplanation   - Description of each window
 • .voiLUTSequence (0028,3010)     - VOI LUT alternative to W/C
 • .rescaleIntercept (0028,1052)   - Modality LUT intercept
 • .rescaleSlope (0028,1053)       - Modality LUT slope
 • .rescaleType (0028,1054)        - Units (e.g., "HU")
 
 VOI LUT (Value of Interest):
 • Alternative to Window Center/Width
 • Defines lookup table for display transformation
 • More flexible than linear window/level
 • Less commonly used than W/C
 
 Modality LUT:
 • Transforms stored values to modality-specific units
 • For CT: Hounsfield Units (HU)
 • Formula: HU = storedValue × slope + intercept
 • Typically applied before VOI LUT or Window/Level
 
 Full Transform Chain:
 1. Stored Pixel Value
 2. → Modality LUT (to HU, etc.)
 3. → VOI LUT or Window/Level (for display)
 4. → Presentation LUT (gamma correction, etc.)
 5. → Display Value
 
 Auto Window/Level:
 • Calculate from image statistics (min/max)
 • Use percentiles (5-95) for robust calculation
 • Useful when tags are missing or incorrect
 
 Interactive Adjustment:
 • Horizontal drag: Adjust width
 • Vertical drag: Adjust center
 • Sensitivity based on image range
 • Provide preset buttons for common windows
 
 Tips:
 
 1. Always use rescale slope/intercept for CT
 2. Check for multiple W/C values in tags
 3. Provide presets for common anatomies
 4. Allow user to adjust interactively
 5. Auto-calculate when tags missing
 6. Clamp width to positive values
 7. Consider VOI LUT Sequence if present
 8. MR images may need full-range window
 9. Store user preferences for each study/modality
 10. Update display in real-time during adjustment
 */
