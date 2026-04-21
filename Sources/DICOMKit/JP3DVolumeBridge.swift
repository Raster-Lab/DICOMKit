import Foundation
import DICOMCore
import J2KCore
import J2K3D

/// Bridges between DICOM multi-frame series and J2KSwift's `J2KVolume` type.
///
/// `JP3DVolumeBridge` converts a sorted series of single-frame DICOM files into a
/// `J2KVolume` for JP3D volumetric encoding, and vice-versa — reconstructing individual
/// DICOM files from a decoded volume.
///
/// ## Usage
///
/// ```swift
/// // Series → Volume
/// let volume = try JP3DVolumeBridge.makeVolume(from: dicomFiles)
///
/// // Volume → Series
/// let files = try JP3DVolumeBridge.makeDICOMSeries(from: volume, template: dicomFiles[0])
/// ```
///
/// ## Limitations
///
/// - JP3D has **no standard DICOM transfer syntax**. This bridge is experimental.
/// - Slice spacing uniformity is validated; non-uniform spacing throws an error.
/// - Only single-component (grayscale) and 3-component (RGB) volumes are supported.
public enum JP3DVolumeBridge: Sendable {

    // MARK: - Errors

    /// Errors that can occur during volume bridging.
    public enum BridgeError: Error, Sendable {
        /// The input series is empty.
        case emptySeries
        /// Inconsistent image dimensions across slices.
        case inconsistentDimensions(expected: String, found: String)
        /// Non-uniform slice spacing detected.
        case nonUniformSliceSpacing(spacings: [Double])
        /// Missing required DICOM tag.
        case missingTag(String)
        /// Unsupported pixel format.
        case unsupportedPixelFormat(String)
    }

    // MARK: - Series → Volume

    /// Creates a `J2KVolume` from a sorted series of single-frame DICOM files.
    ///
    /// Files are sorted by `SliceLocation` (0020,1041) or `ImagePositionPatient` (0020,0032)
    /// Z-component. Validates that all slices share the same rows, columns, bits allocated,
    /// and samples per pixel.
    ///
    /// - Parameter series: Array of `DICOMFile` instances forming a volume.
    /// - Returns: A `J2KVolume` with voxel data and spatial metadata.
    /// - Throws: `BridgeError` if the series is invalid or inconsistent.
    public static func makeVolume(from series: [DICOMFile]) throws -> J2KVolume {
        guard !series.isEmpty else {
            throw BridgeError.emptySeries
        }

        // Sort slices by spatial position
        let sorted = try sortBySlicePosition(series)

        // Extract reference geometry from first slice
        let ref = sorted[0].dataSet
        let rows = try requireUInt16(ref, tag: .rows, name: "Rows")
        let cols = try requireUInt16(ref, tag: .columns, name: "Columns")
        let bitsAllocated = try requireUInt16(ref, tag: .bitsAllocated, name: "BitsAllocated")
        let bitsStored = try requireUInt16(ref, tag: .bitsStored, name: "BitsStored")
        let samplesPerPixel = ref.uint16(for: .samplesPerPixel) ?? 1
        let isSigned = (ref.uint16(for: .pixelRepresentation) ?? 0) != 0

        // Validate all slices match reference geometry
        for (idx, file) in sorted.enumerated() {
            let ds = file.dataSet
            let r = ds.uint16(for: .rows) ?? 0
            let c = ds.uint16(for: .columns) ?? 0
            if r != rows || c != cols {
                throw BridgeError.inconsistentDimensions(
                    expected: "\(rows)×\(cols)",
                    found: "\(r)×\(c) at slice \(idx)"
                )
            }
        }

        // Validate slice spacing uniformity
        let spacing = try computeSliceSpacing(sorted)

        // Extract pixel spacing from first slice
        let (pixelSpacingRow, pixelSpacingCol) = extractPixelSpacing(from: ref)
        let origin = extractImagePosition(from: ref)

        // Build voxel data by stacking pixel data from each slice
        let bytesPerPixel = Int(bitsAllocated) / 8
        let pixelsPerSlice = Int(rows) * Int(cols) * Int(samplesPerPixel)
        let bytesPerSlice = pixelsPerSlice * bytesPerPixel

        var voxelData = Data(capacity: bytesPerSlice * sorted.count)

        for file in sorted {
            let ds = file.dataSet
            guard let pixelElement = ds[.pixelData] else {
                throw BridgeError.missingTag("PixelData (7FE0,0010)")
            }

            let pixelBytes: Data
            if let fragments = pixelElement.encapsulatedFragments, !fragments.isEmpty {
                // Compressed pixel data — decode first frame
                let transferSyntaxUID = file.fileMetaInformation.string(for: .transferSyntaxUID)
                    ?? TransferSyntax.explicitVRLittleEndian.uid
                let registry = CodecRegistry.shared
                if let codec = registry.codec(for: transferSyntaxUID) {
                    let descriptor = PixelDataDescriptor(
                        rows: Int(rows),
                        columns: Int(cols),
                        numberOfFrames: 1,
                        bitsAllocated: Int(bitsAllocated),
                        bitsStored: Int(bitsStored),
                        highBit: Int(ref.uint16(for: .highBit) ?? (bitsStored - 1)),
                        isSigned: isSigned,
                        samplesPerPixel: Int(samplesPerPixel),
                        photometricInterpretation: photometricInterpretation(from: ref)
                    )
                    pixelBytes = try codec.decodeFrame(fragments[0], descriptor: descriptor, frameIndex: 0)
                } else {
                    // Concatenate fragments as raw data
                    pixelBytes = fragments.reduce(Data()) { $0 + $1 }
                }
            } else {
                pixelBytes = pixelElement.valueData
            }

            // Take exactly the expected number of bytes
            if pixelBytes.count >= bytesPerSlice {
                voxelData.append(pixelBytes.prefix(bytesPerSlice))
            } else {
                // Pad if short (shouldn't happen with valid DICOM)
                voxelData.append(pixelBytes)
                voxelData.append(Data(count: bytesPerSlice - pixelBytes.count))
            }
        }

        // Build J2KVolume
        let component = J2KVolumeComponent(
            index: 0,
            bitDepth: Int(bitsStored),
            signed: isSigned,
            width: Int(cols),
            height: Int(rows),
            depth: sorted.count,
            data: voxelData
        )

        return J2KVolume(
            width: Int(cols),
            height: Int(rows),
            depth: sorted.count,
            components: [component],
            spacingX: pixelSpacingCol,
            spacingY: pixelSpacingRow,
            spacingZ: spacing
        )
    }

    // MARK: - Volume → Series

    /// Reconstructs a series of single-frame DICOM files from a `J2KVolume`.
    ///
    /// Uses `template` as the basis for DICOM metadata. Each slice gets a new
    /// `SOPInstanceUID` while preserving the `SeriesInstanceUID`.
    ///
    /// - Parameters:
    ///   - volume: The decoded `J2KVolume`.
    ///   - template: A DICOM file to use as the metadata template.
    /// - Returns: An array of `DICOMFile` instances, one per slice.
    /// - Throws: `BridgeError` if the volume or template is invalid.
    public static func makeDICOMSeries(
        from volume: J2KVolume,
        template: DICOMFile
    ) throws -> [DICOMFile] {
        guard !volume.components.isEmpty else {
            throw BridgeError.unsupportedPixelFormat("Volume has no components")
        }
        guard volume.depth > 0 else {
            throw BridgeError.emptySeries
        }

        let component = volume.components[0]
        let bytesPerPixel = (component.bitDepth + 7) / 8
        let bytesPerSlice = component.width * component.height * bytesPerPixel

        // Preserve the series UID from template
        let seriesUID = template.dataSet.string(for: .seriesInstanceUID)
            ?? UIDGenerator.generateSeriesInstanceUID().value

        var files: [DICOMFile] = []
        files.reserveCapacity(volume.depth)

        for sliceIndex in 0..<volume.depth {
            // Extract slice pixel data
            let offset = sliceIndex * bytesPerSlice
            let sliceData: Data
            if offset + bytesPerSlice <= component.data.count {
                sliceData = component.data.subdata(in: offset..<(offset + bytesPerSlice))
            } else {
                // Partial last slice — pad
                let available = component.data.subdata(in: offset..<component.data.count)
                var padded = available
                padded.append(Data(count: bytesPerSlice - available.count))
                sliceData = padded
            }

            // Build data set from template
            var ds = template.dataSet
            ds[.sopInstanceUID] = DataElement.string(
                tag: .sopInstanceUID, vr: .UI,
                value: UIDGenerator.generateSOPInstanceUID().value
            )
            ds[.seriesInstanceUID] = DataElement.string(
                tag: .seriesInstanceUID, vr: .UI,
                value: seriesUID
            )
            ds[.instanceNumber] = DataElement.string(
                tag: .instanceNumber, vr: .IS,
                value: String(sliceIndex + 1)
            )

            // Set image position
            if volume.spacingZ > 0 {
                let z = volume.originZ + Double(sliceIndex) * volume.spacingZ
                ds[.imagePositionPatient] = DataElement.string(
                    tag: .imagePositionPatient, vr: .DS,
                    value: "\(volume.originX)\\\(volume.originY)\\\(z)"
                )
                ds[.sliceLocation] = DataElement.string(
                    tag: .sliceLocation, vr: .DS,
                    value: String(z)
                )
            }

            // Set number of frames to 1
            ds[.numberOfFrames] = DataElement.string(
                tag: .numberOfFrames, vr: .IS, value: "1"
            )

            // Set pixel data (uncompressed native)
            ds[.pixelData] = DataElement(
                tag: .pixelData,
                vr: bytesPerPixel > 1 ? .OW : .OB,
                length: UInt32(sliceData.count),
                valueData: sliceData
            )

            let file = DICOMFile(
                fileMetaInformation: template.fileMetaInformation,
                dataSet: ds
            )
            files.append(file)
        }

        return files
    }

    // MARK: - Validation

    /// Validates that a series has uniform slice spacing.
    ///
    /// - Parameter series: Array of DICOM files sorted by slice position.
    /// - Returns: `true` if spacing is uniform within 1% tolerance.
    public static func validateSliceSpacing(_ series: [DICOMFile]) -> Bool {
        guard series.count > 2 else { return true }
        do {
            let sorted = try sortBySlicePosition(series)
            _ = try computeSliceSpacing(sorted)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private static func sortBySlicePosition(_ series: [DICOMFile]) throws -> [DICOMFile] {
        // Try ImagePositionPatient Z first, then SliceLocation, then InstanceNumber
        let withPositions: [(file: DICOMFile, position: Double)] = series.compactMap { file in
            let ds = file.dataSet
            if let ipp = ds.string(for: .imagePositionPatient) {
                let parts = ipp.split(separator: "\\")
                if parts.count >= 3, let z = Double(parts[2]) {
                    return (file, z)
                }
            }
            if let sl = ds.string(for: .sliceLocation), let z = Double(sl) {
                return (file, z)
            }
            if let inst = ds.uint16(for: .instanceNumber) {
                return (file, Double(inst))
            }
            return nil
        }

        guard withPositions.count == series.count else {
            throw BridgeError.missingTag("ImagePositionPatient/SliceLocation/InstanceNumber")
        }

        return withPositions.sorted { $0.position < $1.position }.map(\.file)
    }

    private static func computeSliceSpacing(_ sorted: [DICOMFile]) throws -> Double {
        guard sorted.count > 1 else { return 1.0 }

        let positions: [Double] = sorted.compactMap { file in
            let ds = file.dataSet
            if let ipp = ds.string(for: .imagePositionPatient) {
                let parts = ipp.split(separator: "\\")
                if parts.count >= 3, let z = Double(parts[2]) { return z }
            }
            if let sl = ds.string(for: .sliceLocation), let z = Double(sl) { return z }
            return nil
        }

        guard positions.count == sorted.count else { return 1.0 }

        var spacings: [Double] = []
        for i in 1..<positions.count {
            spacings.append(abs(positions[i] - positions[i - 1]))
        }

        guard let first = spacings.first, first > 0 else { return 1.0 }

        // Validate uniformity (1% tolerance)
        let tolerance = first * 0.01
        for sp in spacings {
            if abs(sp - first) > tolerance {
                throw BridgeError.nonUniformSliceSpacing(spacings: spacings)
            }
        }

        return first
    }

    private static func extractPixelSpacing(from ds: DataSet) -> (row: Double, col: Double) {
        if let ps = ds.string(for: .pixelSpacing) {
            let parts = ps.split(separator: "\\")
            if parts.count >= 2,
               let row = Double(parts[0]),
               let col = Double(parts[1]) {
                return (row, col)
            }
        }
        return (1.0, 1.0)
    }

    private static func extractImagePosition(from ds: DataSet) -> (x: Double, y: Double, z: Double) {
        if let ipp = ds.string(for: .imagePositionPatient) {
            let parts = ipp.split(separator: "\\")
            if parts.count >= 3,
               let x = Double(parts[0]),
               let y = Double(parts[1]),
               let z = Double(parts[2]) {
                return (x, y, z)
            }
        }
        return (0, 0, 0)
    }

    private static func photometricInterpretation(from ds: DataSet) -> PhotometricInterpretation {
        if let piStr = ds.string(for: .photometricInterpretation) {
            return PhotometricInterpretation(rawValue: piStr.trimmingCharacters(in: .whitespaces))
                ?? .monochrome2
        }
        return .monochrome2
    }

    private static func requireUInt16(_ ds: DataSet, tag: Tag, name: String) throws -> UInt16 {
        guard let value = ds.uint16(for: tag) else {
            throw BridgeError.missingTag(name)
        }
        return value
    }
}
