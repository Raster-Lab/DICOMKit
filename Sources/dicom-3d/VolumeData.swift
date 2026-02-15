import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

// MARK: - Volume Data Structure

/// Represents a 3D medical imaging volume with associated metadata
struct VolumeData {
    /// Volume dimensions (width x height x depth)
    let dimensions: VolumeDimensions
    
    /// Physical spacing between voxels in mm
    let spacing: VolumeSpacing
    
    /// Volume orientation (Image Orientation Patient)
    let orientation: VolumeOrientation
    
    /// Volume origin (Image Position Patient of first slice)
    let origin: Point3D
    
    /// Raw voxel data (stored in row-major order: x varies fastest, then y, then z)
    let voxels: [Double]
    
    /// Bits allocated per voxel
    let bitsAllocated: Int
    
    /// Bits stored per voxel
    let bitsStored: Int
    
    /// Pixel representation (0 = unsigned, 1 = signed)
    let pixelRepresentation: Int
    
    /// Photometric interpretation
    let photometricInterpretation: String
    
    /// Window center (if specified)
    let windowCenter: Double?
    
    /// Window width (if specified)
    let windowWidth: Double?
    
    /// Rescale slope (for Hounsfield units in CT)
    let rescaleSlope: Double
    
    /// Rescale intercept (for Hounsfield units in CT)
    let rescaleIntercept: Double
    
    /// Initialize a volume
    init(
        dimensions: VolumeDimensions,
        spacing: VolumeSpacing,
        orientation: VolumeOrientation,
        origin: Point3D,
        voxels: [Double],
        bitsAllocated: Int = 16,
        bitsStored: Int = 16,
        pixelRepresentation: Int = 0,
        photometricInterpretation: String = "MONOCHROME2",
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        rescaleSlope: Double = 1.0,
        rescaleIntercept: Double = 0.0
    ) {
        self.dimensions = dimensions
        self.spacing = spacing
        self.orientation = orientation
        self.origin = origin
        self.voxels = voxels
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.pixelRepresentation = pixelRepresentation
        self.photometricInterpretation = photometricInterpretation
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
    }
    
    /// Get voxel value at (x, y, z)
    func voxelAt(x: Int, y: Int, z: Int) -> Double? {
        guard x >= 0 && x < dimensions.width &&
              y >= 0 && y < dimensions.height &&
              z >= 0 && z < dimensions.depth else {
            return nil
        }
        
        let index = z * dimensions.width * dimensions.height + y * dimensions.width + x
        return voxels[index]
    }
    
    /// Get interpolated voxel value at continuous coordinates using trilinear interpolation
    func interpolatedVoxelAt(x: Double, y: Double, z: Double, method: InterpolationMethod = .linear) -> Double? {
        guard x >= 0 && x < Double(dimensions.width) &&
              y >= 0 && y < Double(dimensions.height) &&
              z >= 0 && z < Double(dimensions.depth) else {
            return nil
        }
        
        switch method {
        case .nearest:
            return voxelAt(x: Int(round(x)), y: Int(round(y)), z: Int(round(z)))
            
        case .linear, .cubic:
            // Trilinear interpolation
            let x0 = Int(floor(x))
            let y0 = Int(floor(y))
            let z0 = Int(floor(z))
            let x1 = min(x0 + 1, dimensions.width - 1)
            let y1 = min(y0 + 1, dimensions.height - 1)
            let z1 = min(z0 + 1, dimensions.depth - 1)
            
            let fx = x - Double(x0)
            let fy = y - Double(y0)
            let fz = z - Double(z0)
            
            guard let v000 = voxelAt(x: x0, y: y0, z: z0),
                  let v100 = voxelAt(x: x1, y: y0, z: z0),
                  let v010 = voxelAt(x: x0, y: y1, z: z0),
                  let v110 = voxelAt(x: x1, y: y1, z: z0),
                  let v001 = voxelAt(x: x0, y: y0, z: z1),
                  let v101 = voxelAt(x: x1, y: y0, z: z1),
                  let v011 = voxelAt(x: x0, y: y1, z: z1),
                  let v111 = voxelAt(x: x1, y: y1, z: z1) else {
                return nil
            }
            
            // Interpolate along x
            let v00 = v000 * (1 - fx) + v100 * fx
            let v01 = v001 * (1 - fx) + v101 * fx
            let v10 = v010 * (1 - fx) + v110 * fx
            let v11 = v011 * (1 - fx) + v111 * fx
            
            // Interpolate along y
            let v0 = v00 * (1 - fy) + v10 * fy
            let v1 = v01 * (1 - fy) + v11 * fy
            
            // Interpolate along z
            return v0 * (1 - fz) + v1 * fz
        }
    }
    
    /// Get physical coordinates from voxel indices
    func physicalCoordinates(x: Int, y: Int, z: Int) -> Point3D {
        let px = origin.x + Double(x) * spacing.x * orientation.rowX + Double(y) * spacing.y * orientation.colX
        let py = origin.y + Double(x) * spacing.x * orientation.rowY + Double(y) * spacing.y * orientation.colY
        let pz = origin.z + Double(x) * spacing.x * orientation.rowZ + Double(y) * spacing.y * orientation.colZ + Double(z) * spacing.z
        return Point3D(x: px, y: py, z: pz)
    }
}

// MARK: - Supporting Types

struct VolumeDimensions: Equatable {
    let width: Int
    let height: Int
    let depth: Int
    
    var totalVoxels: Int {
        width * height * depth
    }
}

struct VolumeSpacing: Equatable {
    let x: Double  // mm
    let y: Double  // mm
    let z: Double  // mm
}

struct VolumeOrientation: Equatable {
    // Row direction cosines (x, y, z)
    let rowX: Double
    let rowY: Double
    let rowZ: Double
    
    // Column direction cosines (x, y, z)
    let colX: Double
    let colY: Double
    let colZ: Double
    
    /// Initialize from Image Orientation Patient tag
    init(imageOrientation: [Double]) {
        assert(imageOrientation.count == 6)
        rowX = imageOrientation[0]
        rowY = imageOrientation[1]
        rowZ = imageOrientation[2]
        colX = imageOrientation[3]
        colY = imageOrientation[4]
        colZ = imageOrientation[5]
    }
    
    /// Default axial orientation
    static let axial = VolumeOrientation(imageOrientation: [1, 0, 0, 0, 1, 0])
    
    /// Compute slice direction (cross product of row and column)
    var sliceDirection: Point3D {
        let x = rowY * colZ - rowZ * colY
        let y = rowZ * colX - rowX * colZ
        let z = rowX * colY - rowY * colX
        return Point3D(x: x, y: y, z: z)
    }
}

struct Point3D: Equatable {
    let x: Double
    let y: Double
    let z: Double
    
    static let zero = Point3D(x: 0, y: 0, z: 0)
    
    func distance(to other: Point3D) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}

// MARK: - Volume Loader

/// Loads multi-slice DICOM series into a 3D volume
class VolumeLoader {
    let verbose: Bool
    
    init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    /// Load volume from a list of DICOM file paths
    func loadVolume(from paths: [String]) throws -> VolumeData {
        if verbose {
            print("Loading \(paths.count) DICOM files...")
        }
        
        // Load all DICOM files
        var slices: [(file: DICOMFile, position: Point3D)] = []
        
        for path in paths {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
            let dicomFile = try DICOMFile.read(from: fileData)
            
            // Extract image position
            guard let positionStrings = dicomFile.dataSet.decimalStrings(for: .imagePositionPatient),
                  positionStrings.count == 3 else {
                throw VolumeError.missingMetadata("Image Position Patient")
            }
            
            let positionValues = positionStrings.map { $0.value }
            let position = Point3D(x: positionValues[0], y: positionValues[1], z: positionValues[2])
            slices.append((dicomFile, position))
        }
        
        guard !slices.isEmpty else {
            throw VolumeError.noSlices
        }
        
        // Sort slices by position along slice direction
        let firstFile = slices[0].file
        guard let orientationStrings = firstFile.dataSet.decimalStrings(for: .imageOrientationPatient),
              orientationStrings.count == 6 else {
            throw VolumeError.missingMetadata("Image Orientation Patient")
        }
        
        let orientationValues = orientationStrings.map { $0.value }
        
        let orientation = VolumeOrientation(imageOrientation: orientationValues)
        let sliceDir = orientation.sliceDirection
        
        // Sort by dot product with slice direction
        slices.sort { slice1, slice2 in
            let dot1 = slice1.position.x * sliceDir.x + slice1.position.y * sliceDir.y + slice1.position.z * sliceDir.z
            let dot2 = slice2.position.x * sliceDir.x + slice2.position.y * sliceDir.y + slice2.position.z * sliceDir.z
            return dot1 < dot2
        }
        
        // Extract dimensions from first slice
        let columns = try firstFile.dataSet.unsignedShort(for: .columns)
        let rows = try firstFile.dataSet.unsignedShort(for: .rows)
        let depth = slices.count
        
        let dimensions = VolumeDimensions(width: Int(columns), height: Int(rows), depth: depth)
        
        // Extract pixel spacing
        guard let pixelSpacingStrings = firstFile.dataSet.decimalStrings(for: .pixelSpacing),
              pixelSpacingStrings.count == 2 else {
            throw VolumeError.missingMetadata("Pixel Spacing")
        }
        
        let pixelSpacingValues = pixelSpacingStrings.map { $0.value }
        
        // Calculate slice spacing
        let sliceSpacing: Double
        if slices.count > 1 {
            let dist = slices[0].position.distance(to: slices[1].position)
            sliceSpacing = dist
        } else {
            // Try to get from Slice Thickness or Spacing Between Slices
            if let thickness = try? firstFile.dataSet.decimalString(for: .sliceThickness) {
                sliceSpacing = thickness.value
            } else if let spacing = try? firstFile.dataSet.decimalString(for: .spacingBetweenSlices) {
                sliceSpacing = spacing.value
            } else {
                sliceSpacing = 1.0
            }
        }
        
        let spacing = VolumeSpacing(x: pixelSpacingValues[0], y: pixelSpacingValues[1], z: sliceSpacing)
        
        // Extract other metadata
        let bitsAllocated = Int(try firstFile.dataSet.unsignedShort(for: .bitsAllocated))
        let bitsStored = Int(try firstFile.dataSet.unsignedShort(for: .bitsStored))
        let pixelRepresentation = Int(try firstFile.dataSet.unsignedShort(for: .pixelRepresentation))
        let photometricInterpretation = try firstFile.dataSet.string(for: .photometricInterpretation) ?? "MONOCHROME2"
        
        let windowCenter = try? firstFile.dataSet.decimalString(for: .windowCenter)
        let windowWidth = try? firstFile.dataSet.decimalString(for: .windowWidth)
        
        let rescaleSlope = (try? firstFile.dataSet.decimalString(for: .rescaleSlope))?.value ?? 1.0
        let rescaleIntercept = (try? firstFile.dataSet.decimalString(for: .rescaleIntercept))?.value ?? 0.0
        
        if verbose {
            print("Volume dimensions: \(dimensions.width)x\(dimensions.height)x\(dimensions.depth)")
            print("Pixel spacing: \(spacing.x)x\(spacing.y)x\(spacing.z) mm")
        }
        
        // Extract pixel data from all slices
        var voxels: [Double] = []
        voxels.reserveCapacity(dimensions.totalVoxels)
        
        for (index, slice) in slices.enumerated() {
            if verbose && (index % 10 == 0 || index == slices.count - 1) {
                print("Loading slice \(index + 1)/\(slices.count)...")
            }
            
            guard let pixelData = slice.file.dataSet.pixelData() else {
                throw VolumeError.invalidPixelData
            }
            
            guard let pixels = pixelData.pixelValues(forFrame: 0) else {
                throw VolumeError.invalidPixelData
            }
            
            // Convert to double and apply rescale
            for pixel in pixels {
                let rescaled = Double(pixel) * rescaleSlope + rescaleIntercept
                voxels.append(rescaled)
            }
        }
        
        return VolumeData(
            dimensions: dimensions,
            spacing: spacing,
            orientation: orientation,
            origin: slices[0].position,
            voxels: voxels,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            pixelRepresentation: pixelRepresentation,
            photometricInterpretation: photometricInterpretation,
            windowCenter: windowCenter?.value,
            windowWidth: windowWidth?.value,
            rescaleSlope: rescaleSlope,
            rescaleIntercept: rescaleIntercept
        )
    }
}

// MARK: - Errors

enum VolumeError: Error, CustomStringConvertible {
    case noSlices
    case missingMetadata(String)
    case invalidPixelData
    case invalidDimensions
    case interpolationFailed
    
    var description: String {
        switch self {
        case .noSlices:
            return "No DICOM slices found"
        case .missingMetadata(let tag):
            return "Missing required metadata: \(tag)"
        case .invalidPixelData:
            return "Invalid or missing pixel data"
        case .invalidDimensions:
            return "Invalid volume dimensions"
        case .interpolationFailed:
            return "Interpolation failed"
        }
    }
}
