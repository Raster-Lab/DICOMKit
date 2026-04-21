import Foundation
import DICOMCore
import J2KCore
import J2K3D

/// Volume loading entry points for DICOMKit.
///
/// These functions provide the high-level `openVolume` API that transparently
/// handles both conventional multi-frame DICOM series and JP3D Encapsulated Documents.
extension DICOMFile {

    /// Opens a volumetric DICOM data source and returns a decoded `DICOMVolume`.
    ///
    /// Automatically detects the source type:
    ///
    /// 1. **JP3D Encapsulated Document** — if `url` points to a single file whose
    ///    SOP class is the DICOMKit JP3D private class, decodes the JP3D codestream.
    /// 2. **Single multi-frame DICOM file** — concatenates all frames into a volume.
    /// 3. **Directory** — reads all `.dcm` files in the directory (non-recursively),
    ///    sorts them by slice position, and concatenates their pixel data.
    ///
    /// - Parameter url: A URL pointing to a single DICOM file or a directory of slices.
    /// - Returns: A `DICOMVolume` ready for display or processing.
    /// - Throws: `DICOMError` or `JP3DVolumeBridge.BridgeError` if loading fails.
    public static func openVolume(from url: URL) async throws -> DICOMVolume {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        guard exists else {
            throw DICOMError.parsingFailed("Path does not exist: \(url.path)")
        }

        if isDir.boolValue {
            return try await openVolumeFromDirectory(url)
        } else {
            return try await openVolumeFromFile(url)
        }
    }

    // MARK: - Single file

    private static func openVolumeFromFile(_ url: URL) async throws -> DICOMVolume {
        let file = try DICOMFile.read(from: url)

        // Check for JP3D encapsulated document first
        if JP3DVolumeDocument.isJP3DVolumeDocument(file) {
            return try await openVolumeFromJP3DDocument(file)
        }

        // Conventional multi-frame (or single-frame) DICOM
        return try openVolumeFromMultiframe(file)
    }

    // MARK: - JP3D document decode

    private static func openVolumeFromJP3DDocument(_ file: DICOMFile) async throws -> DICOMVolume {
        let slices = try await JP3DVolumeDocument.decode(from: file)
        guard !slices.isEmpty else {
            throw DICOMError.parsingFailed("JP3D document decoded to empty series")
        }

        // Concatenate decoded slice pixel data
        let refDS = slices[0].dataSet
        let rows = Int(refDS.uint16(for: .rows) ?? 0)
        let cols = Int(refDS.uint16(for: .columns) ?? 0)
        let bitsAlloc = Int(refDS.uint16(for: .bitsAllocated) ?? 16)
        let bitsStored = Int(refDS.uint16(for: .bitsStored) ?? 12)
        let isSigned = (refDS.uint16(for: .pixelRepresentation) ?? 0) != 0
        let depth = slices.count

        var allPixels = Data(capacity: rows * cols * (bitsAlloc / 8) * depth)
        for slice in slices {
            if let px = slice.dataSet[.pixelData]?.valueData {
                allPixels.append(px)
            }
        }

        let (spacing, origin) = extractSpatialMetadata(from: slices)
        let tsUID = file.fileMetaInformation.string(for: .transferSyntaxUID)

        return DICOMVolume(
            width: cols,
            height: rows,
            depth: depth,
            bitsAllocated: bitsAlloc,
            bitsStored: bitsStored,
            isSigned: isSigned,
            spacingX: spacing.x,
            spacingY: spacing.y,
            spacingZ: spacing.z,
            originX: origin.x,
            originY: origin.y,
            originZ: origin.z,
            pixelData: allPixels,
            sourceTransferSyntax: tsUID.flatMap { TransferSyntax.from(uid: $0) },
            modality: file.dataSet.string(for: .modality),
            seriesInstanceUID: file.dataSet.string(for: .seriesInstanceUID),
            studyInstanceUID: file.dataSet.string(for: .studyInstanceUID)
        )
    }

    // MARK: - Multi-frame DICOM

    private static func openVolumeFromMultiframe(_ file: DICOMFile) throws -> DICOMVolume {
        let ds = file.dataSet
        let rows = Int(ds.uint16(for: .rows) ?? 0)
        let cols = Int(ds.uint16(for: .columns) ?? 0)
        let bitsAlloc = Int(ds.uint16(for: .bitsAllocated) ?? 16)
        let bitsStored = Int(ds.uint16(for: .bitsStored) ?? 12)
        let isSigned = (ds.uint16(for: .pixelRepresentation) ?? 0) != 0
        let frames = Int(ds.string(for: .numberOfFrames).flatMap(Int.init) ?? 1)

        guard rows > 0, cols > 0 else {
            throw DICOMError.parsingFailed("Multi-frame volume has no valid image dimensions")
        }

        // Decode pixel data through CodecRegistry if compressed
        let tsUID = file.fileMetaInformation.string(for: .transferSyntaxUID)
            ?? TransferSyntax.explicitVRLittleEndian.uid
        let descriptor = PixelDataDescriptor(
            rows: rows,
            columns: cols,
            numberOfFrames: frames,
            bitsAllocated: bitsAlloc,
            bitsStored: bitsStored,
            highBit: bitsStored - 1,
            isSigned: isSigned,
            samplesPerPixel: Int(ds.uint16(for: .samplesPerPixel) ?? 1),
            photometricInterpretation: .monochrome2
        )

        let rawPixelData: Data
        if let element = ds[.pixelData] {
            let compressed = element.valueData
            if let codec = CodecRegistry.shared.codec(for: tsUID) {
                rawPixelData = try codec.decode(compressed, descriptor: descriptor)
            } else {
                rawPixelData = compressed
            }
        } else {
            rawPixelData = Data()
        }

        let pixelSpacing = extractPixelSpacing(from: ds)
        let sliceThickness = ds.string(for: .sliceThickness).flatMap(Double.init) ?? 1.0
        let origin = extractOriginFromDataSet(ds)

        return DICOMVolume(
            width: cols,
            height: rows,
            depth: frames,
            bitsAllocated: bitsAlloc,
            bitsStored: bitsStored,
            isSigned: isSigned,
            spacingX: pixelSpacing.x,
            spacingY: pixelSpacing.y,
            spacingZ: sliceThickness,
            originX: origin.x,
            originY: origin.y,
            originZ: origin.z,
            pixelData: rawPixelData,
            sourceTransferSyntax: TransferSyntax.from(uid: tsUID),
            modality: ds.string(for: .modality),
            seriesInstanceUID: ds.string(for: .seriesInstanceUID),
            studyInstanceUID: ds.string(for: .studyInstanceUID)
        )
    }

    // MARK: - Directory of slice files

    private static func openVolumeFromDirectory(_ url: URL) async throws -> DICOMVolume {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        let dcmURLs = contents.filter {
            $0.pathExtension.lowercased() == "dcm"
                || isDICOMFile($0)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !dcmURLs.isEmpty else {
            throw DICOMError.parsingFailed("No DICOM files found in directory: \(url.path)")
        }

        var files: [DICOMFile] = []
        for fileURL in dcmURLs {
            if let f = try? DICOMFile.read(from: fileURL) {
                files.append(f)
            }
        }
        guard !files.isEmpty else {
            throw DICOMError.parsingFailed("Failed to read any DICOM files in directory: \(url.path)")
        }

        // If the directory contains a single JP3D document, decode it
        if files.count == 1 && JP3DVolumeDocument.isJP3DVolumeDocument(files[0]) {
            return try await openVolumeFromJP3DDocument(files[0])
        }

        return try openVolumeFromSliceSeries(files)
    }

    // MARK: - Series of individual slices

    private static func openVolumeFromSliceSeries(_ files: [DICOMFile]) throws -> DICOMVolume {
        // Sort by ImagePositionPatient Z or SliceLocation
        let sorted = sortSlicesByPosition(files)

        let refDS = sorted[0].dataSet
        let rows = Int(refDS.uint16(for: .rows) ?? 0)
        let cols = Int(refDS.uint16(for: .columns) ?? 0)
        let bitsAlloc = Int(refDS.uint16(for: .bitsAllocated) ?? 16)
        let bitsStored = Int(refDS.uint16(for: .bitsStored) ?? 12)
        let isSigned = (refDS.uint16(for: .pixelRepresentation) ?? 0) != 0
        let depth = sorted.count

        guard rows > 0, cols > 0 else {
            throw DICOMError.parsingFailed("Slice series has no valid image dimensions")
        }

        var allPixels = Data(capacity: rows * cols * (bitsAlloc / 8) * depth)
        let tsUID = sorted[0].fileMetaInformation.string(for: .transferSyntaxUID)
            ?? TransferSyntax.explicitVRLittleEndian.uid
        let descriptor = PixelDataDescriptor(
            rows: rows,
            columns: cols,
            numberOfFrames: 1,
            bitsAllocated: bitsAlloc,
            bitsStored: bitsStored,
            highBit: bitsStored - 1,
            isSigned: isSigned,
            samplesPerPixel: Int(refDS.uint16(for: .samplesPerPixel) ?? 1),
            photometricInterpretation: .monochrome2
        )

        for file in sorted {
            guard let element = file.dataSet[.pixelData] else { continue }
            let raw = element.valueData
            if let codec = CodecRegistry.shared.codec(for: tsUID) {
                let decoded = try codec.decode(raw, descriptor: descriptor)
                allPixels.append(decoded)
            } else {
                allPixels.append(raw)
            }
        }

        let (spacing, origin) = extractSpatialMetadata(from: sorted)

        return DICOMVolume(
            width: cols,
            height: rows,
            depth: depth,
            bitsAllocated: bitsAlloc,
            bitsStored: bitsStored,
            isSigned: isSigned,
            spacingX: spacing.x,
            spacingY: spacing.y,
            spacingZ: spacing.z,
            originX: origin.x,
            originY: origin.y,
            originZ: origin.z,
            pixelData: allPixels,
            sourceTransferSyntax: TransferSyntax.from(uid: tsUID),
            modality: refDS.string(for: .modality),
            seriesInstanceUID: refDS.string(for: .seriesInstanceUID),
            studyInstanceUID: refDS.string(for: .studyInstanceUID)
        )
    }

    // MARK: - Spatial helpers

    private typealias Vec3 = (x: Double, y: Double, z: Double)

    private static func extractSpatialMetadata(from slices: [DICOMFile]) -> (spacing: Vec3, origin: Vec3) {
        let refDS = slices[0].dataSet

        // Pixel spacing (row spacing, column spacing in mm)
        let ps = extractPixelSpacing(from: refDS)

        // Slice spacing from consecutive positions
        let sliceSpacing: Double
        if slices.count > 1 {
            let z0 = extractZ(from: slices[0].dataSet) ?? 0.0
            let z1 = extractZ(from: slices[1].dataSet) ?? 1.0
            sliceSpacing = abs(z1 - z0)
        } else {
            sliceSpacing = refDS.string(for: .sliceThickness).flatMap(Double.init) ?? 1.0
        }

        let origin = extractOriginFromDataSet(refDS)
        return (Vec3(ps.x, ps.y, sliceSpacing), origin)
    }

    private static func extractPixelSpacing(from ds: DataSet) -> Vec3 {
        if let psStr = ds.string(for: .pixelSpacing) {
            let parts = psStr.split(separator: "\\").compactMap { Double($0) }
            if parts.count >= 2 {
                return Vec3(parts[1], parts[0], 1.0) // [row spacing, col spacing]
            }
        }
        return Vec3(1.0, 1.0, 1.0)
    }

    private static func extractOriginFromDataSet(_ ds: DataSet) -> Vec3 {
        if let posStr = ds.string(for: .imagePositionPatient) {
            let parts = posStr.split(separator: "\\").compactMap { Double($0) }
            if parts.count == 3 { return Vec3(parts[0], parts[1], parts[2]) }
        }
        return Vec3(0.0, 0.0, 0.0)
    }

    private static func extractZ(from ds: DataSet) -> Double? {
        if let posStr = ds.string(for: .imagePositionPatient) {
            let parts = posStr.split(separator: "\\").compactMap { Double($0) }
            if parts.count == 3 { return parts[2] }
        }
        return ds.string(for: .sliceLocation).flatMap(Double.init)
    }

    private static func sortSlicesByPosition(_ files: [DICOMFile]) -> [DICOMFile] {
        files.sorted { a, b in
            let zA = extractZ(from: a.dataSet) ?? 0
            let zB = extractZ(from: b.dataSet) ?? 0
            if zA != zB { return zA < zB }
            let ia = a.dataSet.string(for: .instanceNumber).flatMap(Int.init) ?? 0
            let ib = b.dataSet.string(for: .instanceNumber).flatMap(Int.init) ?? 0
            return ia < ib
        }
    }

    private static func isDICOMFile(_ url: URL) -> Bool {
        // Heuristic: try reading the first 132 bytes for the "DICM" magic
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        let header = handle.readData(ofLength: 132)
        try? handle.close()
        guard header.count == 132 else { return false }
        return header[128] == 0x44 && header[129] == 0x49
            && header[130] == 0x43 && header[131] == 0x4D
    }
}
