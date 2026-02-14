import Foundation
import DICOMKit
import DICOMCore

// MARK: - Plane Types

enum PlaneType {
    case axial
    case sagittal
    case coronal
    case oblique(normal: Point3D, point: Point3D)
}

enum ProjectionType {
    case axial
    case sagittal
    case coronal
}

// MARK: - Slice Image

/// Represents a 2D slice extracted from a 3D volume
struct SliceImage {
    let width: Int
    let height: Int
    let pixels: [Double]
    
    /// Save as PNG with optional windowing
    func savePNG(to url: URL, windowCenter: Double? = nil, windowWidth: Double? = nil) throws {
        #if os(macOS) || os(iOS)
        import CoreGraphics
        import ImageIO
        import UniformTypeIdentifiers
        
        // Apply windowing if specified
        let displayPixels: [UInt8]
        if let wc = windowCenter, let ww = windowWidth {
            let minValue = wc - ww / 2.0
            let maxValue = wc + ww / 2.0
            displayPixels = pixels.map { pixel in
                let clamped = max(minValue, min(maxValue, pixel))
                let normalized = (clamped - minValue) / (maxValue - minValue)
                return UInt8(normalized * 255.0)
            }
        } else {
            // Auto window
            let minPixel = pixels.min() ?? 0
            let maxPixel = pixels.max() ?? 1
            let range = maxPixel - minPixel
            displayPixels = pixels.map { pixel in
                let normalized = range > 0 ? (pixel - minPixel) / range : 0
                return UInt8(normalized * 255.0)
            }
        }
        
        // Create grayscale image
        var mutablePixels = displayPixels
        guard let providerRef = CGDataProvider(data: Data(mutablePixels) as CFData) else {
            throw SliceError.imageCreationFailed
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw SliceError.imageCreationFailed
        }
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw SliceError.fileWriteFailed
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw SliceError.fileWriteFailed
        }
        #else
        throw SliceError.unsupportedPlatform
        #endif
    }
}

// MARK: - MPR Generator

/// Generates Multi-Planar Reformation (MPR) images from a 3D volume
class MPRGenerator {
    let volume: VolumeData
    let interpolation: InterpolationMethod
    let verbose: Bool
    
    init(volume: VolumeData, interpolation: InterpolationMethod = .linear, verbose: Bool = false) {
        self.volume = volume
        self.interpolation = interpolation
        self.verbose = verbose
    }
    
    /// Generate MPR slices for a given plane type
    func generateMPR(plane: PlaneType, sliceThickness: Double? = nil) throws -> [SliceImage] {
        switch plane {
        case .axial:
            return try generateAxialSlices()
        case .sagittal:
            return try generateSagittalSlices()
        case .coronal:
            return try generateCoronalSlices()
        case .oblique(let normal, let point):
            return try [generateObliqueSlice(normal: normal, point: point)]
        }
    }
    
    /// Generate axial (transverse) slices
    private func generateAxialSlices() throws -> [SliceImage] {
        var slices: [SliceImage] = []
        
        for z in 0..<volume.dimensions.depth {
            var pixels: [Double] = []
            pixels.reserveCapacity(volume.dimensions.width * volume.dimensions.height)
            
            for y in 0..<volume.dimensions.height {
                for x in 0..<volume.dimensions.width {
                    if let value = volume.voxelAt(x: x, y: y, z: z) {
                        pixels.append(value)
                    } else {
                        pixels.append(0)
                    }
                }
            }
            
            slices.append(SliceImage(width: volume.dimensions.width, height: volume.dimensions.height, pixels: pixels))
        }
        
        return slices
    }
    
    /// Generate sagittal slices
    private func generateSagittalSlices() throws -> [SliceImage] {
        var slices: [SliceImage] = []
        
        for x in 0..<volume.dimensions.width {
            var pixels: [Double] = []
            pixels.reserveCapacity(volume.dimensions.height * volume.dimensions.depth)
            
            for z in 0..<volume.dimensions.depth {
                for y in 0..<volume.dimensions.height {
                    if let value = volume.voxelAt(x: x, y: y, z: z) {
                        pixels.append(value)
                    } else {
                        pixels.append(0)
                    }
                }
            }
            
            slices.append(SliceImage(width: volume.dimensions.height, height: volume.dimensions.depth, pixels: pixels))
        }
        
        return slices
    }
    
    /// Generate coronal slices
    private func generateCoronalSlices() throws -> [SliceImage] {
        var slices: [SliceImage] = []
        
        for y in 0..<volume.dimensions.height {
            var pixels: [Double] = []
            pixels.reserveCapacity(volume.dimensions.width * volume.dimensions.depth)
            
            for z in 0..<volume.dimensions.depth {
                for x in 0..<volume.dimensions.width {
                    if let value = volume.voxelAt(x: x, y: y, z: z) {
                        pixels.append(value)
                    } else {
                        pixels.append(0)
                    }
                }
            }
            
            slices.append(SliceImage(width: volume.dimensions.width, height: volume.dimensions.depth, pixels: pixels))
        }
        
        return slices
    }
    
    /// Generate oblique slice through an arbitrary plane
    private func generateObliqueSlice(normal: Point3D, point: Point3D) throws -> SliceImage {
        // Normalize the normal vector
        let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
        let nx = normal.x / length
        let ny = normal.y / length
        let nz = normal.z / length
        
        // Create two perpendicular vectors in the plane
        var u = Point3D(x: 1, y: 0, z: 0)
        if abs(nx) > 0.9 {
            u = Point3D(x: 0, y: 1, z: 0)
        }
        
        // u = u - (u · n)n (project onto plane)
        let dot = u.x * nx + u.y * ny + u.z * nz
        let ux = u.x - dot * nx
        let uy = u.y - dot * ny
        let uz = u.z - dot * nz
        let ulen = sqrt(ux * ux + uy * uy + uz * uz)
        let u_norm = Point3D(x: ux / ulen, y: uy / ulen, z: uz / ulen)
        
        // v = n × u (cross product)
        let vx = ny * u_norm.z - nz * u_norm.y
        let vy = nz * u_norm.x - nx * u_norm.z
        let vz = nx * u_norm.y - ny * u_norm.x
        let v_norm = Point3D(x: vx, y: vy, z: vz)
        
        // Sample the plane
        let width = volume.dimensions.width
        let height = volume.dimensions.height
        var pixels: [Double] = []
        pixels.reserveCapacity(width * height)
        
        for j in 0..<height {
            for i in 0..<width {
                let px = point.x + Double(i - width / 2) * volume.spacing.x * u_norm.x + Double(j - height / 2) * volume.spacing.y * v_norm.x
                let py = point.y + Double(i - width / 2) * volume.spacing.x * u_norm.y + Double(j - height / 2) * volume.spacing.y * v_norm.y
                let pz = point.z + Double(i - width / 2) * volume.spacing.x * u_norm.z + Double(j - height / 2) * volume.spacing.y * v_norm.z
                
                // Convert to voxel coordinates
                let vx = px / volume.spacing.x
                let vy = py / volume.spacing.y
                let vz = pz / volume.spacing.z
                
                if let value = volume.interpolatedVoxelAt(x: vx, y: vy, z: vz, method: interpolation) {
                    pixels.append(value)
                } else {
                    pixels.append(0)
                }
            }
        }
        
        return SliceImage(width: width, height: height, pixels: pixels)
    }
}

// MARK: - Projection Renderer

/// Renders intensity projection images (MIP, MinIP, Average)
class ProjectionRenderer {
    let volume: VolumeData
    let verbose: Bool
    
    init(volume: VolumeData, verbose: Bool = false) {
        self.volume = volume
        self.verbose = verbose
    }
    
    /// Generate Maximum Intensity Projection
    func maximumIntensityProjection(direction: ProjectionType, slabThickness: Double? = nil) throws -> SliceImage {
        switch direction {
        case .axial:
            return try projectAxial { $0.max() ?? 0 }
        case .sagittal:
            return try projectSagittal { $0.max() ?? 0 }
        case .coronal:
            return try projectCoronal { $0.max() ?? 0 }
        }
    }
    
    /// Generate Minimum Intensity Projection
    func minimumIntensityProjection(direction: ProjectionType, slabThickness: Double? = nil) throws -> SliceImage {
        switch direction {
        case .axial:
            return try projectAxial { $0.min() ?? 0 }
        case .sagittal:
            return try projectSagittal { $0.min() ?? 0 }
        case .coronal:
            return try projectCoronal { $0.min() ?? 0 }
        }
    }
    
    /// Generate Average Intensity Projection
    func averageIntensityProjection(direction: ProjectionType) throws -> SliceImage {
        switch direction {
        case .axial:
            return try projectAxial { values in
                values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            }
        case .sagittal:
            return try projectSagittal { values in
                values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            }
        case .coronal:
            return try projectCoronal { values in
                values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            }
        }
    }
    
    // Helper: Project along Z axis (axial)
    private func projectAxial(operation: ([Double]) -> Double) throws -> SliceImage {
        var pixels: [Double] = []
        pixels.reserveCapacity(volume.dimensions.width * volume.dimensions.height)
        
        for y in 0..<volume.dimensions.height {
            for x in 0..<volume.dimensions.width {
                var values: [Double] = []
                for z in 0..<volume.dimensions.depth {
                    if let value = volume.voxelAt(x: x, y: y, z: z) {
                        values.append(value)
                    }
                }
                pixels.append(operation(values))
            }
        }
        
        return SliceImage(width: volume.dimensions.width, height: volume.dimensions.height, pixels: pixels)
    }
    
    // Helper: Project along X axis (sagittal)
    private func projectSagittal(operation: ([Double]) -> Double) throws -> SliceImage {
        var pixels: [Double] = []
        pixels.reserveCapacity(volume.dimensions.height * volume.dimensions.depth)
        
        for z in 0..<volume.dimensions.depth {
            for y in 0..<volume.dimensions.height {
                var values: [Double] = []
                for x in 0..<volume.dimensions.width {
                    if let value = volume.voxelAt(x: x, y: y, z: z) {
                        values.append(value)
                    }
                }
                pixels.append(operation(values))
            }
        }
        
        return SliceImage(width: volume.dimensions.height, height: volume.dimensions.depth, pixels: pixels)
    }
    
    // Helper: Project along Y axis (coronal)
    private func projectCoronal(operation: ([Double]) -> Double) throws -> SliceImage {
        var pixels: [Double] = []
        pixels.reserveCapacity(volume.dimensions.width * volume.dimensions.depth)
        
        for z in 0..<volume.dimensions.depth {
            for x in 0..<volume.dimensions.width {
                var values: [Double] = []
                for y in 0..<volume.dimensions.height {
                    if let value = volume.voxelAt(x: x, y: y, z: z) {
                        values.append(value)
                    }
                }
                pixels.append(operation(values))
            }
        }
        
        return SliceImage(width: volume.dimensions.width, height: volume.dimensions.depth, pixels: pixels)
    }
}

// MARK: - Errors

enum SliceError: Error, CustomStringConvertible {
    case imageCreationFailed
    case fileWriteFailed
    case unsupportedPlatform
    
    var description: String {
        switch self {
        case .imageCreationFailed:
            return "Failed to create image"
        case .fileWriteFailed:
            return "Failed to write file"
        case .unsupportedPlatform:
            return "PNG export not supported on this platform"
        }
    }
}
