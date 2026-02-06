// DICOMKit Sample Code: 3D Volume Reconstruction and MPR
//
// This example demonstrates how to:
// - Load 3D series (multiple DICOM slices)
// - Sort slices by spatial position
// - Build 3D volume from slices
// - Multiplanar Reconstruction (MPR) - axial, sagittal, coronal
// - Oblique slicing
// - Maximum Intensity Projection (MIP)
// - Volume spacing and orientation
// - Interpolation techniques

import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Example 1: Loading and Sorting 3D Series

func example1_loadAndSort3DSeries() throws {
    // Load all DICOM files from a directory containing a 3D series
    let directoryURL = URL(fileURLWithPath: "/path/to/ct/series/")
    let fileManager = FileManager.default
    
    guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
        print("Failed to enumerate directory")
        return
    }
    
    var slices: [(file: DICOMFile, position: Double)] = []
    
    // Load each DICOM file
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "dcm" {
        do {
            let file = try DICOMFile.read(from: fileURL)
            
            // Get Image Position Patient (0020,0032)
            // This is a 3-element array: [x, y, z] in patient coordinate system (mm)
            if let imagePosition = file.dataSet.string(for: .imagePositionPatient) {
                let components = imagePosition.split(separator: "\\").compactMap { Double($0) }
                if components.count == 3 {
                    // For axial slices, z-coordinate determines position
                    // For sagittal, use x; for coronal, use y
                    let zPosition = components[2]
                    slices.append((file: file, position: zPosition))
                }
            }
        } catch {
            print("Warning: Failed to load \(fileURL.lastPathComponent): \(error)")
        }
    }
    
    // Sort slices by position
    slices.sort { $0.position < $1.position }
    
    print("✅ Loaded \(slices.count) slices")
    print("Position range: \(slices.first?.position ?? 0) to \(slices.last?.position ?? 0) mm")
    
    // Calculate spacing between slices
    if slices.count > 1 {
        let spacing = (slices.last!.position - slices.first!.position) / Double(slices.count - 1)
        print("Average slice spacing: \(spacing) mm")
    }
}

// MARK: - Example 2: Building 3D Volume Data Structure

struct Volume3D {
    let data: [UInt16]  // Raw voxel data
    let dimensions: (x: Int, y: Int, z: Int)  // Voxel dimensions
    let spacing: (x: Double, y: Double, z: Double)  // Spacing in mm
    let origin: (x: Double, y: Double, z: Double)  // Origin in patient coordinates
    let orientation: ImageOrientation  // Image orientation
    
    /// Get voxel value at (x, y, z)
    func voxel(x: Int, y: Int, z: Int) -> UInt16? {
        guard x >= 0, x < dimensions.x,
              y >= 0, y < dimensions.y,
              z >= 0, z < dimensions.z else {
            return nil
        }
        
        let index = z * (dimensions.x * dimensions.y) + y * dimensions.x + x
        return data[index]
    }
    
    /// Get voxel value with bounds checking
    subscript(x: Int, y: Int, z: Int) -> UInt16 {
        return voxel(x: x, y: y, z: z) ?? 0
    }
}

struct ImageOrientation {
    let rowDirection: (x: Double, y: Double, z: Double)  // Row direction cosine
    let colDirection: (x: Double, y: Double, z: Double)  // Column direction cosine
}

#if canImport(CoreGraphics)
func example2_build3DVolume() throws {
    let directoryURL = URL(fileURLWithPath: "/path/to/ct/series/")
    
    // Load and sort slices (from example 1)
    var sortedFiles: [DICOMFile] = []
    // ... load and sort logic from example 1 ...
    
    guard let firstFile = sortedFiles.first else {
        print("No slices loaded")
        return
    }
    
    // Get volume dimensions
    let rows = firstFile.dataSet.uint16(for: .rows) ?? 0
    let cols = firstFile.dataSet.uint16(for: .columns) ?? 0
    let slices = sortedFiles.count
    
    // Get pixel spacing (in-plane resolution)
    let pixelSpacing = firstFile.dataSet.string(for: .pixelSpacing)?
        .split(separator: "\\")
        .compactMap { Double($0) } ?? [1.0, 1.0]
    
    // Get slice thickness or calculate from positions
    var sliceSpacing = firstFile.dataSet.float64(for: .sliceThickness) ?? 1.0
    if sortedFiles.count > 1,
       let pos1 = parseImagePosition(sortedFiles[0]),
       let pos2 = parseImagePosition(sortedFiles[1]) {
        sliceSpacing = abs(pos2.2 - pos1.2)
    }
    
    // Get origin (position of first slice)
    let origin = parseImagePosition(firstFile) ?? (0.0, 0.0, 0.0)
    
    // Get orientation
    let orientation = parseImageOrientation(firstFile) ?? ImageOrientation(
        rowDirection: (1.0, 0.0, 0.0),
        colDirection: (0.0, 1.0, 0.0)
    )
    
    // Allocate volume data
    var volumeData: [UInt16] = []
    volumeData.reserveCapacity(Int(rows) * Int(cols) * slices)
    
    // Fill volume with pixel data from each slice
    for file in sortedFiles {
        guard let pixelData = file.pixelData else {
            print("Warning: Slice missing pixel data")
            continue
        }
        
        // Extract pixel values for this slice
        if let pixels = try? pixelData.pixelValues(forFrame: 0) as? [UInt16] {
            volumeData.append(contentsOf: pixels)
        }
    }
    
    let volume = Volume3D(
        data: volumeData,
        dimensions: (x: Int(cols), y: Int(rows), z: slices),
        spacing: (x: pixelSpacing[0], y: pixelSpacing[1], z: sliceSpacing),
        origin: origin,
        orientation: orientation
    )
    
    print("✅ Built 3D volume:")
    print("   Dimensions: \(volume.dimensions.x) × \(volume.dimensions.y) × \(volume.dimensions.z)")
    print("   Spacing: \(volume.spacing.x) × \(volume.spacing.y) × \(volume.spacing.z) mm")
    print("   Total voxels: \(volumeData.count)")
}
#endif

// Helper functions
func parseImagePosition(_ file: DICOMFile) -> (Double, Double, Double)? {
    guard let positionStr = file.dataSet.string(for: .imagePositionPatient) else {
        return nil
    }
    let components = positionStr.split(separator: "\\").compactMap { Double($0) }
    guard components.count == 3 else { return nil }
    return (components[0], components[1], components[2])
}

func parseImageOrientation(_ file: DICOMFile) -> ImageOrientation? {
    guard let orientStr = file.dataSet.string(for: .imageOrientationPatient) else {
        return nil
    }
    let components = orientStr.split(separator: "\\").compactMap { Double($0) }
    guard components.count == 6 else { return nil }
    
    return ImageOrientation(
        rowDirection: (components[0], components[1], components[2]),
        colDirection: (components[3], components[4], components[5])
    )
}

// MARK: - Example 3: Axial Slice Extraction (Original Plane)

#if canImport(CoreGraphics)
func example3_extractAxialSlice(volume: Volume3D, sliceIndex: Int) -> CGImage? {
    guard sliceIndex >= 0 && sliceIndex < volume.dimensions.z else {
        print("Slice index out of bounds")
        return nil
    }
    
    let width = volume.dimensions.x
    let height = volume.dimensions.y
    
    // Extract slice data
    var sliceData: [UInt16] = []
    sliceData.reserveCapacity(width * height)
    
    for y in 0..<height {
        for x in 0..<width {
            sliceData.append(volume[x, y, sliceIndex])
        }
    }
    
    // Convert to 8-bit for display (apply window/level)
    let windowCenter: Double = 40.0
    let windowWidth: Double = 400.0
    let windowMin = windowCenter - windowWidth / 2.0
    let windowMax = windowCenter + windowWidth / 2.0
    
    var displayData = Data(count: width * height)
    displayData.withUnsafeMutableBytes { ptr in
        guard let baseAddress = ptr.baseAddress else { return }
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for i in 0..<sliceData.count {
            let value = Double(sliceData[i])
            let normalized = (value - windowMin) / windowWidth
            let clamped = max(0.0, min(1.0, normalized))
            bytes[i] = UInt8(clamped * 255.0)
        }
    }
    
    // Create CGImage
    guard let provider = CGDataProvider(data: displayData as CFData),
          let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
        return nil
    }
    
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: [],
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}
#endif

// MARK: - Example 4: Sagittal MPR (Side View)

#if canImport(CoreGraphics)
func example4_extractSagittalSlice(volume: Volume3D, xIndex: Int) -> CGImage? {
    guard xIndex >= 0 && xIndex < volume.dimensions.x else {
        print("X index out of bounds")
        return nil
    }
    
    // Sagittal slice: fix X, vary Y and Z
    let width = volume.dimensions.y  // Y becomes width
    let height = volume.dimensions.z  // Z becomes height
    
    var sliceData: [UInt16] = []
    sliceData.reserveCapacity(width * height)
    
    // Iterate from top to bottom (Z), left to right (Y)
    for z in stride(from: height - 1, through: 0, by: -1) {  // Flip Z for proper orientation
        for y in 0..<width {
            sliceData.append(volume[xIndex, y, z])
        }
    }
    
    // Convert to display image (same as example 3)
    return convertToDisplayImage(sliceData, width: width, height: height)
}
#endif

// MARK: - Example 5: Coronal MPR (Front View)

#if canImport(CoreGraphics)
func example5_extractCoronalSlice(volume: Volume3D, yIndex: Int) -> CGImage? {
    guard yIndex >= 0 && yIndex < volume.dimensions.y else {
        print("Y index out of bounds")
        return nil
    }
    
    // Coronal slice: fix Y, vary X and Z
    let width = volume.dimensions.x  // X becomes width
    let height = volume.dimensions.z  // Z becomes height
    
    var sliceData: [UInt16] = []
    sliceData.reserveCapacity(width * height)
    
    // Iterate from top to bottom (Z), left to right (X)
    for z in stride(from: height - 1, through: 0, by: -1) {  // Flip Z
        for x in 0..<width {
            sliceData.append(volume[x, yIndex, z])
        }
    }
    
    return convertToDisplayImage(sliceData, width: width, height: height)
}
#endif

// MARK: - Example 6: Oblique Slicing with Interpolation

#if canImport(CoreGraphics)
func example6_obliqueSlice(
    volume: Volume3D,
    origin: (x: Double, y: Double, z: Double),
    normal: (x: Double, y: Double, z: Double),
    uAxis: (x: Double, y: Double, z: Double),
    size: (width: Int, height: Int)
) -> CGImage? {
    // Normalize normal vector
    let normalLen = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
    let n = (x: normal.x / normalLen, y: normal.y / normalLen, z: normal.z / normalLen)
    
    // Normalize u axis
    let uLen = sqrt(uAxis.x * uAxis.x + uAxis.y * uAxis.y + uAxis.z * uAxis.z)
    let u = (x: uAxis.x / uLen, y: uAxis.y / uLen, z: uAxis.z / uLen)
    
    // Compute v axis (perpendicular to both u and n)
    let v = (
        x: u.y * n.z - u.z * n.y,
        y: u.z * n.x - u.x * n.z,
        z: u.x * n.y - u.y * n.x
    )
    
    var sliceData: [UInt16] = []
    sliceData.reserveCapacity(size.width * size.height)
    
    // Sample along the oblique plane
    for row in 0..<size.height {
        for col in 0..<size.width {
            // Calculate 3D position on the oblique plane
            let offsetU = Double(col) - Double(size.width) / 2.0
            let offsetV = Double(row) - Double(size.height) / 2.0
            
            let x = origin.x + offsetU * u.x + offsetV * v.x
            let y = origin.y + offsetU * u.y + offsetV * v.y
            let z = origin.z + offsetU * u.z + offsetV * v.z
            
            // Trilinear interpolation
            let value = trilinearInterpolate(volume: volume, x: x, y: y, z: z)
            sliceData.append(value)
        }
    }
    
    return convertToDisplayImage(sliceData, width: size.width, height: size.height)
}

/// Trilinear interpolation for smooth oblique slicing
func trilinearInterpolate(volume: Volume3D, x: Double, y: Double, z: Double) -> UInt16 {
    // Get integer and fractional parts
    let x0 = Int(floor(x))
    let y0 = Int(floor(y))
    let z0 = Int(floor(z))
    
    let xd = x - Double(x0)
    let yd = y - Double(y0)
    let zd = z - Double(z0)
    
    // Bounds checking
    guard x0 >= 0, x0 < volume.dimensions.x - 1,
          y0 >= 0, y0 < volume.dimensions.y - 1,
          z0 >= 0, z0 < volume.dimensions.z - 1 else {
        return 0
    }
    
    // Get 8 corner values
    let c000 = Double(volume[x0, y0, z0])
    let c001 = Double(volume[x0, y0, z0 + 1])
    let c010 = Double(volume[x0, y0 + 1, z0])
    let c011 = Double(volume[x0, y0 + 1, z0 + 1])
    let c100 = Double(volume[x0 + 1, y0, z0])
    let c101 = Double(volume[x0 + 1, y0, z0 + 1])
    let c110 = Double(volume[x0 + 1, y0 + 1, z0])
    let c111 = Double(volume[x0 + 1, y0 + 1, z0 + 1])
    
    // Interpolate along x
    let c00 = c000 * (1 - xd) + c100 * xd
    let c01 = c001 * (1 - xd) + c101 * xd
    let c10 = c010 * (1 - xd) + c110 * xd
    let c11 = c011 * (1 - xd) + c111 * xd
    
    // Interpolate along y
    let c0 = c00 * (1 - yd) + c10 * yd
    let c1 = c01 * (1 - yd) + c11 * yd
    
    // Interpolate along z
    let result = c0 * (1 - zd) + c1 * zd
    
    return UInt16(max(0, min(65535, result)))
}
#endif

// MARK: - Example 7: Maximum Intensity Projection (MIP)

#if canImport(CoreGraphics)
func example7_maximumIntensityProjection(volume: Volume3D, axis: Axis) -> CGImage? {
    var width: Int
    var height: Int
    var sliceData: [UInt16] = []
    
    switch axis {
    case .z:  // Axial MIP (project along Z)
        width = volume.dimensions.x
        height = volume.dimensions.y
        sliceData = Array(repeating: 0, count: width * height)
        
        for z in 0..<volume.dimensions.z {
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    let value = volume[x, y, z]
                    sliceData[index] = max(sliceData[index], value)
                }
            }
        }
        
    case .y:  // Coronal MIP (project along Y)
        width = volume.dimensions.x
        height = volume.dimensions.z
        sliceData = Array(repeating: 0, count: width * height)
        
        for y in 0..<volume.dimensions.y {
            for z in 0..<height {
                for x in 0..<width {
                    let index = (height - 1 - z) * width + x
                    let value = volume[x, y, z]
                    sliceData[index] = max(sliceData[index], value)
                }
            }
        }
        
    case .x:  // Sagittal MIP (project along X)
        width = volume.dimensions.y
        height = volume.dimensions.z
        sliceData = Array(repeating: 0, count: width * height)
        
        for x in 0..<volume.dimensions.x {
            for z in 0..<height {
                for y in 0..<width {
                    let index = (height - 1 - z) * width + y
                    let value = volume[x, y, z]
                    sliceData[index] = max(sliceData[index], value)
                }
            }
        }
    }
    
    print("✅ Created MIP (\(axis)) - \(width) × \(height)")
    return convertToDisplayImage(sliceData, width: width, height: height)
}

enum Axis {
    case x, y, z
}
#endif

// MARK: - Example 8: Minimum Intensity Projection (MinIP)

#if canImport(CoreGraphics)
func example8_minimumIntensityProjection(volume: Volume3D, axis: Axis) -> CGImage? {
    var width: Int
    var height: Int
    var sliceData: [UInt16] = []
    
    switch axis {
    case .z:
        width = volume.dimensions.x
        height = volume.dimensions.y
        sliceData = Array(repeating: UInt16.max, count: width * height)
        
        for z in 0..<volume.dimensions.z {
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    let value = volume[x, y, z]
                    sliceData[index] = min(sliceData[index], value)
                }
            }
        }
        
    case .y:
        width = volume.dimensions.x
        height = volume.dimensions.z
        sliceData = Array(repeating: UInt16.max, count: width * height)
        
        for y in 0..<volume.dimensions.y {
            for z in 0..<height {
                for x in 0..<width {
                    let index = (height - 1 - z) * width + x
                    let value = volume[x, y, z]
                    sliceData[index] = min(sliceData[index], value)
                }
            }
        }
        
    case .x:
        width = volume.dimensions.y
        height = volume.dimensions.z
        sliceData = Array(repeating: UInt16.max, count: width * height)
        
        for x in 0..<volume.dimensions.x {
            for z in 0..<height {
                for y in 0..<width {
                    let index = (height - 1 - z) * width + y
                    let value = volume[x, y, z]
                    sliceData[index] = min(sliceData[index], value)
                }
            }
        }
    }
    
    print("✅ Created MinIP (\(axis)) - \(width) × \(height)")
    return convertToDisplayImage(sliceData, width: width, height: height)
}
#endif

// MARK: - Example 9: Average Intensity Projection (AvgIP)

#if canImport(CoreGraphics)
func example9_averageIntensityProjection(volume: Volume3D, axis: Axis) -> CGImage? {
    var width: Int
    var height: Int
    var sumData: [UInt32] = []
    var count: Int
    
    switch axis {
    case .z:
        width = volume.dimensions.x
        height = volume.dimensions.y
        count = volume.dimensions.z
        sumData = Array(repeating: 0, count: width * height)
        
        for z in 0..<count {
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    sumData[index] += UInt32(volume[x, y, z])
                }
            }
        }
        
    case .y:
        width = volume.dimensions.x
        height = volume.dimensions.z
        count = volume.dimensions.y
        sumData = Array(repeating: 0, count: width * height)
        
        for y in 0..<count {
            for z in 0..<height {
                for x in 0..<width {
                    let index = (height - 1 - z) * width + x
                    sumData[index] += UInt32(volume[x, y, z])
                }
            }
        }
        
    case .x:
        width = volume.dimensions.y
        height = volume.dimensions.z
        count = volume.dimensions.x
        sumData = Array(repeating: 0, count: width * height)
        
        for x in 0..<count {
            for z in 0..<height {
                for y in 0..<width {
                    let index = (height - 1 - z) * width + y
                    sumData[index] += UInt32(volume[x, y, z])
                }
            }
        }
    }
    
    // Convert sum to average
    let sliceData = sumData.map { UInt16($0 / UInt32(count)) }
    
    print("✅ Created AvgIP (\(axis)) - \(width) × \(height)")
    return convertToDisplayImage(sliceData, width: width, height: height)
}
#endif

// MARK: - Helper: Convert to Display Image

#if canImport(CoreGraphics)
func convertToDisplayImage(_ pixelData: [UInt16], width: Int, height: Int) -> CGImage? {
    // Apply window/level for display
    let windowCenter: Double = 40.0
    let windowWidth: Double = 400.0
    let windowMin = windowCenter - windowWidth / 2.0
    
    var displayData = Data(count: width * height)
    displayData.withUnsafeMutableBytes { ptr in
        guard let baseAddress = ptr.baseAddress else { return }
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for i in 0..<pixelData.count {
            let value = Double(pixelData[i])
            let normalized = (value - windowMin) / windowWidth
            let clamped = max(0.0, min(1.0, normalized))
            bytes[i] = UInt8(clamped * 255.0)
        }
    }
    
    guard let provider = CGDataProvider(data: displayData as CFData),
          let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
        return nil
    }
    
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: [],
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}
#endif

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_loadAndSort3DSeries()
// try? example2_build3DVolume()

// MARK: - Quick Reference

/*
 3D Volume Reconstruction and MPR:
 
 Key Concepts:
 • Volume3D          - 3D array of voxels (volumetric pixels)
 • Voxel             - 3D pixel with (x, y, z) coordinates
 • MPR               - Multiplanar Reconstruction (reformatting)
 • MIP               - Maximum Intensity Projection
 • MinIP             - Minimum Intensity Projection
 • AvgIP             - Average Intensity Projection
 
 DICOM Tags for 3D Volumes:
 • .imagePositionPatient (0020,0032)    - X\Y\Z position (mm)
 • .imageOrientationPatient (0020,0037) - Row\Col direction cosines
 • .pixelSpacing (0028,0030)            - Row\Col spacing (mm)
 • .sliceThickness (0018,0050)          - Slice thickness (mm)
 • .sliceLocation (0020,1041)           - Slice position along normal
 • .instanceNumber (0020,0013)          - Instance number (slice order)
 
 Image Orientation Patient:
 • 6 values: [Xx, Xy, Xz, Yx, Yy, Yz]
 • First 3: Direction of row (X) in patient space
 • Last 3: Direction of column (Y) in patient space
 • Common values:
   - Axial: [1\0\0\0\1\0]
   - Sagittal: [0\1\0\0\0\-1]
   - Coronal: [1\0\0\0\0\-1]
 
 Image Position Patient:
 • 3 values: [X, Y, Z] in mm
 • Position of upper-left pixel center
 • Patient coordinate system (LPS or RAS)
 
 Slice Sorting:
 1. Parse Image Position Patient for each file
 2. Determine primary axis (axial: Z, sagittal: X, coronal: Y)
 3. Sort slices by position along that axis
 4. Verify consistent spacing (detect missing slices)
 
 Volume Spacing:
 • In-plane (XY): From Pixel Spacing (0028,0030)
 • Through-plane (Z): From Slice Thickness or calculated from positions
 • Formula: spacing = (lastPos - firstPos) / (numSlices - 1)
 
 MPR Planes:
 • Axial    - Transverse plane (looking down)
 • Sagittal - Side plane (looking from side)
 • Coronal  - Front plane (looking from front)
 • Oblique  - Arbitrary plane (custom orientation)
 
 Axial Slice Extraction:
 • Fix Z, vary X and Y
 • Same as original acquisition for axial scans
 • Dimensions: Original X × Y
 
 Sagittal Slice Extraction:
 • Fix X, vary Y and Z
 • Dimensions: Original Y × Z
 • May need aspect ratio correction based on spacing
 
 Coronal Slice Extraction:
 • Fix Y, vary X and Z
 • Dimensions: Original X × Z
 • May need aspect ratio correction
 
 Oblique Slicing:
 • Arbitrary plane through volume
 • Requires interpolation (trilinear, cubic)
 • Define plane by: origin, normal, in-plane axes
 
 Interpolation Methods:
 • Nearest Neighbor - Fastest, blocky artifacts
 • Bilinear         - Good for 2D, moderate speed
 • Trilinear        - Good for 3D, smooth results
 • Cubic            - Best quality, slower
 
 Trilinear Interpolation:
 • Sample 8 corner voxels of surrounding cube
 • Interpolate along X, then Y, then Z
 • Formula: f(x,y,z) = weighted average of 8 corners
 • Weights based on fractional position
 
 Maximum Intensity Projection (MIP):
 • Take maximum value along projection ray
 • Excellent for angiography (bright vessels)
 • Hides low-intensity structures
 • Formula: output(x,y) = max(volume(x,y,:))
 
 Minimum Intensity Projection (MinIP):
 • Take minimum value along projection ray
 • Useful for air-filled structures (lungs)
 • Opposite of MIP
 • Formula: output(x,y) = min(volume(x,y,:))
 
 Average Intensity Projection (AvgIP):
 • Take average value along projection ray
 • Balanced view, reduces noise
 • Similar to conventional radiography
 • Formula: output(x,y) = mean(volume(x,y,:))
 
 Slab Techniques:
 • MIP/MinIP over thickness range (e.g., 10mm slab)
 • Reduces noise while preserving features
 • Commonly used for CTA, MRA
 
 Volume Rendering Considerations:
 • Memory: rows × cols × slices × bytes_per_voxel
 • Example: 512×512×300 × 2 bytes = 150MB
 • Use lazy loading for very large volumes
 • Consider downsampling for interactive display
 
 Aspect Ratio Correction:
 • Account for different spacing in X, Y, Z
 • Scale displayed image to match physical size
 • Formula: displayScale = spacing / minSpacing
 
 Performance Tips:
 1. Load slices in parallel (GCD, async/await)
 2. Use memory mapping for very large datasets
 3. Cache rendered slices for smooth scrolling
 4. Downsample for preview, full-res for export
 5. Use SIMD for interpolation (vDSP, Accelerate)
 6. Stream slices from disk if memory limited
 7. Precompute common MPR views
 8. Use GPU for real-time rendering (Metal)
 
 Common Applications:
 • CT Angiography (CTA) - MIP for vessels
 • Virtual Colonoscopy - MPR navigation
 • Radiation Planning - Oblique slicing for beam alignment
 • Spine Imaging - Sagittal/Coronal reformats
 • Cardiac CT - Oblique slicing along cardiac axes
 
 Quality Checks:
 1. Verify consistent slice spacing (no gaps)
 2. Check image orientation (avoid flips)
 3. Validate physical dimensions match expected
 4. Ensure proper sorting (compare instance numbers)
 5. Test interpolation at boundaries
 
 Tips:
 
 1. Always sort slices by Image Position Patient
 2. Verify spacing consistency across series
 3. Use trilinear interpolation for oblique slicing
 4. Apply window/level after MPR/MIP reconstruction
 5. Consider aspect ratio when displaying reformats
 6. Cache rendered slices for interactive viewing
 7. Use slab MIP for thick slice viewing
 8. Validate orientation matches anatomical expectations
 9. Handle missing slices gracefully
 10. Optimize memory usage for large volumes
 */
