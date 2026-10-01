// NEMA-verified: 2026a, checked 2026-10-01 — plane names against the patient-based coordinate system of PS3.3 2026a C.7.6.2.1.1 (x to patient left, y to posterior, z to head; 3 planes mapped to the volume axis nearest each LPS axis, rows/columns oriented as row +x/+y and column +y/-z); reformatted-plane geometry by Equation C.7.6.2.1-1 with Pixel Spacing row\column order of Table C.7-10; window by the LINEAR function of C.11.2.1.2.1 (width >= 1) and MONOCHROME1 shown inverted (C.7.6.3.1.2)
import Foundation
import DICOMKit
import DICOMCore

#if os(macOS) || os(iOS)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif

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

/// The three orthogonal planes, named in the patient-based coordinate system of
/// PS3.3 2026a C.7.6.2.1.1: "the x-axis is increasing to the left hand side of the
/// patient. The y-axis is increasing to the posterior side of the patient. The
/// z-axis is increasing toward the head of the patient."
///
/// - axial (transverse): perpendicular to z; rows run to patient left (+x), columns to posterior (+y)
/// - coronal: perpendicular to y; rows run to patient left (+x), columns toward the feet (−z)
/// - sagittal: perpendicular to x; rows run to posterior (+y), columns toward the feet (−z)
enum PatientPlane: String, CaseIterable {
    case axial
    case sagittal
    case coronal

    /// LPS axis the plane is perpendicular to.
    var normalAxis: Point3D {
        switch self {
        case .axial: return Point3D(x: 0, y: 0, z: 1)
        case .sagittal: return Point3D(x: 1, y: 0, z: 0)
        case .coronal: return Point3D(x: 0, y: 1, z: 0)
        }
    }

    /// Direction the image rows run (left to right on screen).
    var rowDirection: Point3D {
        switch self {
        case .axial, .coronal: return Point3D(x: 1, y: 0, z: 0)
        case .sagittal: return Point3D(x: 0, y: 1, z: 0)
        }
    }

    /// Direction the image columns run (top to bottom on screen).
    var columnDirection: Point3D {
        switch self {
        case .axial: return Point3D(x: 0, y: 1, z: 0)
        case .sagittal, .coronal: return Point3D(x: 0, y: 0, z: -1)
        }
    }

    init(_ plane: PlaneType) {
        switch plane {
        case .sagittal: self = .sagittal
        case .coronal: self = .coronal
        default: self = .axial
        }
    }

    init(_ projection: ProjectionType) {
        switch projection {
        case .axial: self = .axial
        case .sagittal: self = .sagittal
        case .coronal: self = .coronal
        }
    }
}

/// How a patient plane maps onto the volume's index axes (0 = columns, 1 = rows,
/// 2 = slices). The plane is cut perpendicular to the index axis closest to its
/// LPS normal, so a sagittal or coronal acquisition reformats correctly.
struct ReformatLayout: Equatable {
    let fixedAxis: Int
    let uAxis: Int        // runs along the output rows (output column index)
    let uReversed: Bool
    let vAxis: Int        // runs along the output columns (output row index)
    let vReversed: Bool

    init(fixedAxis: Int, uAxis: Int, uReversed: Bool, vAxis: Int, vReversed: Bool) {
        self.fixedAxis = fixedAxis
        self.uAxis = uAxis
        self.uReversed = uReversed
        self.vAxis = vAxis
        self.vReversed = vReversed
    }

    init(plane: PatientPlane, volume: VolumeData) {
        func alignment(_ axis: Int, _ target: Point3D) -> Double { volume.axisDirection(axis).dot(target) }
        let fixed = (0..<3).max { abs(alignment($0, plane.normalAxis)) < abs(alignment($1, plane.normalAxis)) }!
        let others = (0..<3).filter { $0 != fixed }
        let u = abs(alignment(others[0], plane.rowDirection)) >= abs(alignment(others[1], plane.rowDirection))
            ? others[0] : others[1]
        let v = others[0] == u ? others[1] : others[0]
        self.init(fixedAxis: fixed,
                  uAxis: u, uReversed: alignment(u, plane.rowDirection) < 0,
                  vAxis: v, vReversed: alignment(v, plane.columnDirection) < 0)
    }

    /// Volume index of output pixel (i, j) on fixed-axis position k.
    func index(i: Int, j: Int, k: Int, volume: VolumeData) -> [Int] {
        var idx = [0, 0, 0]
        idx[fixedAxis] = k
        idx[uAxis] = uReversed ? volume.axisCount(uAxis) - 1 - i : i
        idx[vAxis] = vReversed ? volume.axisCount(vAxis) - 1 - j : j
        return idx
    }

    func width(_ volume: VolumeData) -> Int { volume.axisCount(uAxis) }
    func height(_ volume: VolumeData) -> Int { volume.axisCount(vAxis) }

    /// Image Plane geometry of an output image whose fixed-axis position is `k`
    /// (fractional for a slab centre): PS3.3 C.7.6.2.1.1 Equation C.7.6.2.1-1.
    func geometry(k: Double, thickness: Double, volume: VolumeData) -> SliceGeometry {
        var first = [0.0, 0.0, 0.0]
        first[fixedAxis] = k
        first[uAxis] = uReversed ? Double(volume.axisCount(uAxis) - 1) : 0
        first[vAxis] = vReversed ? Double(volume.axisCount(vAxis) - 1) : 0
        let position = volume.physicalCoordinates(x: first[0], y: first[1], z: first[2])
        let row = volume.axisDirection(uAxis).scaled(uReversed ? -1 : 1)
        let column = volume.axisDirection(vAxis).scaled(vReversed ? -1 : 1)
        return SliceGeometry(imagePosition: position, rowCosines: row, columnCosines: column,
                             rowSpacing: volume.axisSpacing(vAxis), columnSpacing: volume.axisSpacing(uAxis),
                             sliceThickness: thickness)
    }
}

/// Image Plane attributes of a reformatted image (PS3.3 Table C.7-10).
struct SliceGeometry: Equatable {
    /// Image Position (Patient): centre of the first transmitted pixel.
    let imagePosition: Point3D
    /// Image Orientation (Patient) values 1-3 (row direction) and 4-6 (column direction).
    let rowCosines: Point3D
    let columnCosines: Point3D
    /// Pixel Spacing value 1 (between rows) and value 2 (between columns).
    let rowSpacing: Double
    let columnSpacing: Double
    /// Slice Thickness (0018,0050).
    let sliceThickness: Double
}

// MARK: - Slice Image

/// Represents a 2D slice extracted from a 3D volume
struct SliceImage {
    let width: Int
    let height: Int
    let pixels: [Double]
    var geometry: SliceGeometry? = nil

    /// 8-bit display values: the VOI LUT Function LINEAR of PS3.3 2026a C.11.2.1.2.1
    /// (the function that applies when VOI LUT Function (0028,1056) is absent),
    /// or the full pixel range when no window is given. MONOCHROME1 data are shown
    /// inverted: "The minimum sample value is intended to be displayed as white
    /// after any VOI gray scale transformations" (C.7.6.3.1.2).
    func displayValues(windowCenter: Double? = nil, windowWidth: Double? = nil,
                       monochrome1: Bool = false) -> [UInt8] {
        let window: WindowSettings
        if let wc = windowCenter, let ww = windowWidth {
            window = WindowSettings(center: wc, width: ww, function: .linear)
        } else {
            let minPixel = pixels.min() ?? 0
            let maxPixel = pixels.max() ?? 1
            window = WindowSettings(center: (minPixel + maxPixel) / 2, width: max(maxPixel - minPixel, 0),
                                    function: .linearExact)
        }
        return pixels.map { pixel in
            var normalized = window.apply(to: pixel)
            if monochrome1 { normalized = 1.0 - normalized }
            return UInt8(max(0, min(255, (normalized * 255.0).rounded())))
        }
    }
    
    /// Save as PNG with optional windowing
    func savePNG(to url: URL, windowCenter: Double? = nil, windowWidth: Double? = nil,
                 monochrome1: Bool = false) throws {
        #if os(macOS) || os(iOS)
        let displayPixels = displayValues(windowCenter: windowCenter, windowWidth: windowWidth,
                                          monochrome1: monochrome1)
        guard let providerRef = CGDataProvider(data: Data(displayPixels) as CFData) else {
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
    
    /// Generate MPR slices for a given plane type.
    ///
    /// With `sliceThickness`, consecutive planes are averaged into slabs of that
    /// thickness (rounded to whole voxels along the cut axis), one output image per slab.
    func generateMPR(plane: PlaneType, sliceThickness: Double? = nil) throws -> [SliceImage] {
        if case .oblique(let normal, let point) = plane {
            return try [generateObliqueSlice(normal: normal, point: point)]
        }
        let layout = ReformatLayout(plane: PatientPlane(plane), volume: volume)
        let depth = volume.axisCount(layout.fixedAxis)
        let axisSpacing = volume.axisSpacing(layout.fixedAxis)
        let slab = max(1, Int((( sliceThickness ?? 0) / axisSpacing).rounded()))
        let width = layout.width(volume)
        let height = layout.height(volume)

        var slices: [SliceImage] = []
        var start = 0
        while start < depth {
            let end = min(start + slab, depth)
            var pixels = [Double](repeating: 0, count: width * height)
            for j in 0..<height {
                for i in 0..<width {
                    var sum = 0.0
                    for k in start..<end {
                        sum += volume.voxelAt(layout.index(i: i, j: j, k: k, volume: volume)) ?? 0
                    }
                    pixels[j * width + i] = sum / Double(end - start)
                }
            }
            let thickness: Double
            if end - start == 1, layout.fixedAxis == 2,
               let nominal = volume.template.decimalString(for: .sliceThickness)?.value, nominal > 0 {
                thickness = nominal
            } else {
                thickness = Double(end - start) * axisSpacing
            }
            let centre = Double(start) + Double(end - start - 1) / 2
            slices.append(SliceImage(width: width, height: height, pixels: pixels,
                                     geometry: layout.geometry(k: centre, thickness: thickness, volume: volume)))
            start = end
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
        try project(direction, slabThickness: slabThickness) { $0.max() ?? 0 }
    }
    
    /// Generate Minimum Intensity Projection
    func minimumIntensityProjection(direction: ProjectionType, slabThickness: Double? = nil) throws -> SliceImage {
        try project(direction, slabThickness: slabThickness) { $0.min() ?? 0 }
    }
    
    /// Generate Average Intensity Projection
    func averageIntensityProjection(direction: ProjectionType, slabThickness: Double? = nil) throws -> SliceImage {
        try project(direction, slabThickness: slabThickness) { values in
            values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
    }

    /// Project along the volume axis closest to the plane's LPS normal. A slab
    /// thickness limits the projection to that many millimetres centred on the
    /// middle of the volume; nil or 0 projects the whole volume.
    func project(_ direction: ProjectionType, slabThickness: Double? = nil,
                 operation: ([Double]) -> Double) throws -> SliceImage {
        let layout = ReformatLayout(plane: PatientPlane(direction), volume: volume)
        let depth = volume.axisCount(layout.fixedAxis)
        let axisSpacing = volume.axisSpacing(layout.fixedAxis)
        var count = depth
        if let slab = slabThickness, slab > 0 {
            count = min(depth, max(1, Int((slab / axisSpacing).rounded())))
        }
        let start = (depth - count) / 2
        let width = layout.width(volume)
        let height = layout.height(volume)
        var pixels: [Double] = []
        pixels.reserveCapacity(width * height)
        var values: [Double] = []
        values.reserveCapacity(count)
        for j in 0..<height {
            for i in 0..<width {
                values.removeAll(keepingCapacity: true)
                for k in start..<(start + count) {
                    if let value = volume.voxelAt(layout.index(i: i, j: j, k: k, volume: volume)) {
                        values.append(value)
                    }
                }
                pixels.append(operation(values))
            }
        }
        let centre = Double(start) + Double(count - 1) / 2
        return SliceImage(width: width, height: height, pixels: pixels,
                          geometry: layout.geometry(k: centre, thickness: Double(count) * axisSpacing, volume: volume))
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
