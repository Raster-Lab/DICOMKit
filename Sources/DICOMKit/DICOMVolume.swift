import Foundation
import DICOMCore
import J2KCore
import J2K3D

/// A decoded, in-memory representation of a DICOM volumetric image.
///
/// `DICOMVolume` holds the voxel data and spatial metadata for a multi-frame
/// DICOM series, whether loaded from a conventional multi-frame file, an
/// array of single-frame slices, or a JP3D Encapsulated Document.
///
/// ## Usage
///
/// Use `DICOMKit.openVolume(from:)` to load and decode a volume:
///
/// ```swift
/// // From a directory of DICOM slice files
/// let volume = try await DICOMKit.openVolume(from: seriesDirectoryURL)
///
/// // From a single JP3D encapsulated document
/// let volume = try await DICOMKit.openVolume(from: jp3dDocumentURL)
///
/// // Access pixel data
/// let sliceData = volume.slice(at: 42)
/// print("Dimensions: \(volume.width)×\(volume.height)×\(volume.depth)")
/// ```
public struct DICOMVolume: Sendable {

    // MARK: - Dimensions

    /// Number of columns (voxels along X).
    public let width: Int

    /// Number of rows (voxels along Y).
    public let height: Int

    /// Number of slices (voxels along Z).
    public let depth: Int

    // MARK: - Pixel Encoding

    /// Bits allocated per voxel (8 or 16 for standard DICOM).
    public let bitsAllocated: Int

    /// Bits actually stored per voxel.
    public let bitsStored: Int

    /// Whether voxel values are signed integers.
    public let isSigned: Bool

    // MARK: - Voxel Spacing (mm)

    /// Voxel size along X (column spacing, mm).
    public let spacingX: Double

    /// Voxel size along Y (row spacing, mm).
    public let spacingY: Double

    /// Voxel size along Z (slice thickness / spacing, mm).
    public let spacingZ: Double

    // MARK: - Image Origin (mm in DICOM patient coordinates)

    /// X-component of the image position of the first slice.
    public let originX: Double

    /// Y-component of the image position of the first slice.
    public let originY: Double

    /// Z-component of the image position of the first slice.
    public let originZ: Double

    // MARK: - Pixel Data

    /// Complete voxel data in frame-major order (all slices concatenated).
    ///
    /// Total size = `width × height × depth × (bitsAllocated / 8)` bytes.
    /// Frames are stored in Z-order (first slice first).
    public let pixelData: Data

    // MARK: - Source Information

    /// Transfer syntax the pixel data was loaded from.
    public let sourceTransferSyntax: TransferSyntax?

    /// Modality (e.g., "CT", "MR", "PT").
    public let modality: String?

    /// Series Instance UID of the source data.
    public let seriesInstanceUID: String?

    /// Study Instance UID.
    public let studyInstanceUID: String?

    // MARK: - Computed Properties

    /// Bytes per voxel (all samples).
    public var bytesPerVoxel: Int { (bitsAllocated + 7) / 8 }

    /// Bytes per slice plane.
    public var bytesPerSlice: Int { width * height * bytesPerVoxel }

    /// Total number of voxels.
    public var voxelCount: Int { width * height * depth }

    // MARK: - Slice Access

    /// Returns the pixel data for a single slice.
    ///
    /// - Parameter index: Zero-based slice index (0..<depth).
    /// - Returns: Data containing the slice's pixel values, or `nil` if out of range.
    public func slice(at index: Int) -> Data? {
        guard index >= 0, index < depth else { return nil }
        let start = index * bytesPerSlice
        guard start + bytesPerSlice <= pixelData.count else { return nil }
        return pixelData.subdata(in: start..<(start + bytesPerSlice))
    }

    /// Returns the voxel value at the given position.
    ///
    /// For 16-bit signed images, the returned value will be negative for values
    /// above the high bit (e.g., Hounsfield units).
    ///
    /// - Parameters:
    ///   - x: Column index (0..<width).
    ///   - y: Row index (0..<height).
    ///   - z: Slice index (0..<depth).
    /// - Returns: Voxel value as an `Int`, or `nil` if out of bounds.
    public func voxel(x: Int, y: Int, z: Int) -> Int? {
        guard x >= 0, x < width,
              y >= 0, y < height,
              z >= 0, z < depth else { return nil }

        let byteOffset = (z * height * width + y * width + x) * bytesPerVoxel
        guard byteOffset + bytesPerVoxel <= pixelData.count else { return nil }

        if bytesPerVoxel == 2 {
            let raw = pixelData.subdata(in: byteOffset..<(byteOffset + 2))
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            if isSigned && (raw & (1 << (bitsStored - 1))) != 0 {
                // Sign-extend
                let signedVal = Int16(bitPattern: raw)
                return Int(signedVal)
            }
            return Int(raw)
        } else {
            return Int(pixelData[byteOffset])
        }
    }

    // MARK: - Initialiser

    /// Creates a `DICOMVolume` with the given parameters.
    public init(
        width: Int,
        height: Int,
        depth: Int,
        bitsAllocated: Int = 16,
        bitsStored: Int = 12,
        isSigned: Bool = false,
        spacingX: Double = 1.0,
        spacingY: Double = 1.0,
        spacingZ: Double = 1.0,
        originX: Double = 0.0,
        originY: Double = 0.0,
        originZ: Double = 0.0,
        pixelData: Data,
        sourceTransferSyntax: TransferSyntax? = nil,
        modality: String? = nil,
        seriesInstanceUID: String? = nil,
        studyInstanceUID: String? = nil
    ) {
        self.width = width
        self.height = height
        self.depth = depth
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.isSigned = isSigned
        self.spacingX = spacingX
        self.spacingY = spacingY
        self.spacingZ = spacingZ
        self.originX = originX
        self.originY = originY
        self.originZ = originZ
        self.pixelData = pixelData
        self.sourceTransferSyntax = sourceTransferSyntax
        self.modality = modality
        self.seriesInstanceUID = seriesInstanceUID
        self.studyInstanceUID = studyInstanceUID
    }
}
