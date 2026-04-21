import Foundation
import DICOMCore
import J2KCore
import J2K3D

/// Encapsulated SOP adapter for JP3D volumetric data.
///
/// `JP3DVolumeDocument` wraps a complete JP3D codestream inside a DICOM
/// Encapsulated Document IOD, allowing multi-frame volumetric data to be
/// stored as a single DICOM file.
///
/// ## Private SOP Class
///
/// JP3D has no DICOM-standard SOP class. This implementation uses:
/// - **SOP Class UID**: `1.2.826.0.1.3680043.10.511.10`
///   ("DICOMKit JP3D Volumetric Storage — EXPERIMENTAL")
/// - **MIME type**: `application/x-jp3d` (unregistered, DICOMKit internal)
///
/// These UIDs and MIME types are **not interoperable** with other DICOM
/// implementations and are clearly labelled experimental.
///
/// ## Warning
///
/// This SOP class is experimental and may change or be removed in future
/// versions of DICOMKit. Do **not** use it for clinical data storage.
/// See `Documentation/ConformanceStatement.md` for limitations.
///
/// ## Usage
///
/// ```swift
/// // Write: encode a series to a JP3D document
/// let doc = try await JP3DVolumeDocument.encode(
///     series: dicomFiles,
///     compressionMode: .lossless,
///     studyInstanceUID: studyUID,
///     seriesInstanceUID: seriesUID
/// )
/// let data = try doc.write()
/// try data.write(to: outputURL)
///
/// // Read: detect and decode a JP3D document
/// let dicomFile = try DICOMFile.read(from: inputURL)
/// if JP3DVolumeDocument.isJP3DVolumeDocument(dicomFile) {
///     let series = try await JP3DVolumeDocument.decode(from: dicomFile)
///     // series is [DICOMFile], one per slice
/// }
/// ```
public enum JP3DVolumeDocument: Sendable {

    // MARK: - SOP Class Constants

    /// Private SOP Class UID for the DICOMKit JP3D Volumetric Storage.
    ///
    /// **Experimental** — not interoperable with other DICOM implementations.
    /// Documented in `Documentation/ConformanceStatement.md`.
    public static let sopClassUID = "1.2.826.0.1.3680043.10.511.10"

    /// MIME type used for the embedded JP3D codestream.
    public static let mimeType = "application/x-jp3d"

    /// Document title embedded in the DICOM file.
    public static let documentTitle = "JP3D Volumetric Codestream (EXPERIMENTAL)"

    // MARK: - Metadata Keys (stored as JSON sidecar in DocumentTitle-equivalent OB element)

    private static let metadataMIMEType = "application/x-jp3d-meta+json"

    // MARK: - Detection

    /// Returns `true` if the given DICOM file is a JP3D volume document.
    ///
    /// Detection checks both the SOP Class UID and the MIME type of the
    /// encapsulated document to guard against false positives.
    ///
    /// - Parameter file: A `DICOMFile` to inspect.
    /// - Returns: `true` when the file contains a JP3D codestream.
    public static func isJP3DVolumeDocument(_ file: DICOMFile) -> Bool {
        let fmiSOP = file.fileMetaInformation.string(for: .mediaStorageSOPClassUID)
        let dsSOP = file.dataSet.string(for: .sopClassUID)
        let mime = file.dataSet.string(for: .mimeTypeOfEncapsulatedDocument)

        let sopMatch = (fmiSOP == sopClassUID) || (dsSOP == sopClassUID)
        let mimeMatch = mime == mimeType
        return sopMatch && mimeMatch
    }

    // MARK: - Encoding

    /// Encodes a DICOM multi-frame series as a single JP3D Encapsulated Document.
    ///
    /// The series is sorted, validated, converted to a `J2KVolume`, and encoded
    /// with JP3D. The resulting codestream is embedded into a DICOM Encapsulated
    /// Document IOD alongside a JSON sidecar that preserves voxel geometry metadata.
    ///
    /// - Parameters:
    ///   - series: Sorted or unsorted array of DICOM files forming a volume.
    ///   - compressionMode: JP3D compression mode (default: `.lossless`).
    ///   - studyInstanceUID: Study UID for the output file (uses series if nil).
    ///   - seriesInstanceUID: Series UID for the output file (auto-generated if nil).
    ///   - sopInstanceUID: SOP Instance UID (auto-generated if nil).
    /// - Returns: A `DICOMFile` containing the encoded JP3D volume document.
    /// - Throws: `JP3DVolumeBridge.BridgeError` or `DICOMError` on failure.
    public static func encode(
        series: [DICOMFile],
        compressionMode: JP3DCodec.CompressionMode = .lossless,
        studyInstanceUID: String? = nil,
        seriesInstanceUID: String? = nil,
        sopInstanceUID: String? = nil
    ) async throws -> DICOMFile {
        guard !series.isEmpty else {
            throw JP3DVolumeBridge.BridgeError.emptySeries
        }

        // Build volume from series
        let volume = try JP3DVolumeBridge.makeVolume(from: series)

        // Encode volume to JP3D codestream
        let descriptor = makeDescriptor(from: series[0].dataSet, depth: series.count)
        let codec = JP3DCodec(compressionMode: compressionMode)
        guard let component = volume.components.first else {
            throw JP3DVolumeBridge.BridgeError.unsupportedPixelFormat("Volume has no components")
        }
        let codestream = try await codec.encodeVolume(component.data, descriptor: descriptor)

        // Build JSON metadata sidecar
        let meta = makeMetadata(from: series, volume: volume, compressionMode: compressionMode)
        let metaJSON = try JSONSerialization.data(withJSONObject: meta, options: [.sortedKeys, .prettyPrinted])

        // Assemble Encapsulated Document + meta payload
        // Layout: [4-byte JP3D length LE][jp3d codestream][4-byte JSON length LE][JSON bytes]
        var payload = Data()
        var jp3dLen = UInt32(codestream.count).littleEndian
        payload.append(Data(bytes: &jp3dLen, count: 4))
        payload.append(codestream)
        var jsonLen = UInt32(metaJSON.count).littleEndian
        payload.append(Data(bytes: &jsonLen, count: 4))
        payload.append(metaJSON)

        // Resolve UIDs
        let template = series[0].dataSet
        let studyUID = studyInstanceUID
            ?? template.string(for: .studyInstanceUID)
            ?? UIDGenerator.generateUID().value
        let seriesUID = seriesInstanceUID ?? UIDGenerator.generateUID().value
        let instanceUID = sopInstanceUID ?? UIDGenerator.generateUID().value

        // Build data set
        var ds = DataSet()

        // Patient Module
        if let name = template.string(for: .patientName) {
            ds.setString(name, for: .patientName, vr: .PN)
        }
        if let pid = template.string(for: .patientID) {
            ds.setString(pid, for: .patientID, vr: .LO)
        }
        if let dob = template.string(for: .patientBirthDate) {
            ds.setString(dob, for: .patientBirthDate, vr: .DA)
        }
        if let sex = template.string(for: .patientSex) {
            ds.setString(sex, for: .patientSex, vr: .CS)
        }

        // General Study Module
        ds.setString(studyUID, for: .studyInstanceUID, vr: .UI)
        if let acc = template.string(for: .accessionNumber) {
            ds.setString(acc, for: .accessionNumber, vr: .SH)
        }
        if let studyDate = template.string(for: .studyDate) {
            ds.setString(studyDate, for: .studyDate, vr: .DA)
        }
        if let studyTime = template.string(for: .studyTime) {
            ds.setString(studyTime, for: .studyTime, vr: .TM)
        }

        // General Series Module
        ds.setString(seriesUID, for: .seriesInstanceUID, vr: .UI)
        ds.setString("DOC", for: .modality, vr: .CS)
        ds.setInt(1, for: .seriesNumber, vr: .IS)

        // SOP Common Module
        ds.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        ds.setString(instanceUID, for: .sopInstanceUID, vr: .UI)
        ds.setString("1", for: .instanceNumber, vr: .IS)

        // General Equipment Module (minimal)
        ds.setString("DICOMKit", for: .manufacturer, vr: .LO)
        ds.setString("JP3DVolumeDocument", for: .softwareVersions, vr: .LO)

        // Encapsulated Document Module
        ds.setString(mimeType, for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        ds.setString(documentTitle, for: .documentTitle, vr: .LO)
        ds[.encapsulatedDocument] = DataElement.data(
            tag: .encapsulatedDocument,
            vr: .OB,
            data: payload
        )

        // Content Date/Time
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let dateStr = String(format: "%04d%02d%02d",
            comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1)
        let timeStr = String(format: "%02d%02d%02d",
            comps.hour ?? 0, comps.minute ?? 0, comps.second ?? 0)
        ds.setString(dateStr, for: .contentDate, vr: .DA)
        ds.setString(timeStr, for: .contentTime, vr: .TM)

        // Use Explicit VR Little Endian for the container file
        let tsUID = TransferSyntax.explicitVRLittleEndian.uid
        return try DICOMFile.create(
            dataSet: ds,
            sopClassUID: sopClassUID,
            sopInstanceUID: instanceUID,
            transferSyntaxUID: tsUID
        )
    }

    // MARK: - Decoding

    /// Decodes a JP3D Encapsulated Document back to a synthetic multi-frame series.
    ///
    /// Reads the JP3D codestream and JSON sidecar from the encapsulated document,
    /// decodes the volume using `JP3DDecoder`, and reconstructs individual DICOM files
    /// using the template metadata stored in the sidecar.
    ///
    /// - Parameter file: A `DICOMFile` known to be a JP3D volume document.
    /// - Returns: An array of `DICOMFile`, one per decoded slice.
    /// - Throws: `DICOMError` if parsing or decoding fails.
    public static func decode(from file: DICOMFile) async throws -> [DICOMFile] {
        guard let payloadElement = file.dataSet[.encapsulatedDocument] else {
            throw DICOMError.parsingFailed("JP3D document: missing Encapsulated Document element")
        }
        let payload = payloadElement.valueData

        // Parse composite payload: [4-byte JP3D len][jp3d][4-byte JSON len][json]
        guard payload.count >= 8 else {
            throw DICOMError.parsingFailed("JP3D document: payload too short (\(payload.count) bytes)")
        }

        let jp3dLen = Int(payload.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        guard 4 + jp3dLen + 4 <= payload.count else {
            throw DICOMError.parsingFailed("JP3D document: JP3D codestream length overflows payload")
        }
        let codestream = payload.subdata(in: 4..<(4 + jp3dLen))

        let jsonOffset = 4 + jp3dLen
        let jsonLen = Int(payload.subdata(in: jsonOffset..<(jsonOffset + 4)).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        guard jsonOffset + 4 + jsonLen <= payload.count else {
            throw DICOMError.parsingFailed("JP3D document: JSON sidecar length overflows payload")
        }
        let jsonData = payload.subdata(in: (jsonOffset + 4)..<(jsonOffset + 4 + jsonLen))

        // Parse sidecar to get geometry
        guard let meta = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw DICOMError.parsingFailed("JP3D document: failed to parse JSON sidecar")
        }

        let rows = meta["rows"] as? Int ?? 0
        let columns = meta["columns"] as? Int ?? 0
        let frames = meta["frames"] as? Int ?? 0
        let bitsAllocated = meta["bitsAllocated"] as? Int ?? 16
        let bitsStored = meta["bitsStored"] as? Int ?? 12
        let isSigned = meta["signed"] as? Bool ?? false

        guard rows > 0, columns > 0, frames > 0 else {
            throw DICOMError.parsingFailed("JP3D document: invalid geometry in sidecar (rows=\(rows) cols=\(columns) frames=\(frames))")
        }

        // Decode the JP3D codestream
        let descriptor = PixelDataDescriptor(
            rows: rows,
            columns: columns,
            numberOfFrames: frames,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: bitsStored - 1,
            isSigned: isSigned,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        let codec = JP3DCodec()
        let pixelData = try await codec.decodeVolume(codestream, descriptor: descriptor)

        // Build a synthetic template DICOMFile from the sidecar metadata
        let template = buildTemplate(from: meta, fileDataSet: file.dataSet)

        // Use bridge to reconstruct slices from decoded volume
        let sliceSpacing = meta["sliceSpacing"] as? Double
        let origin = meta["origin"] as? [Double] ?? [0, 0, 0]
        return try reconstructSlices(
            pixelData: pixelData,
            descriptor: descriptor,
            template: template,
            sliceSpacing: sliceSpacing ?? 1.0,
            origin: origin
        )
    }

    // MARK: - Private helpers

    private static func makeDescriptor(from ds: DataSet, depth: Int) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: Int(ds.uint16(for: .rows) ?? 0),
            columns: Int(ds.uint16(for: .columns) ?? 0),
            numberOfFrames: depth,
            bitsAllocated: Int(ds.uint16(for: .bitsAllocated) ?? 16),
            bitsStored: Int(ds.uint16(for: .bitsStored) ?? 12),
            highBit: Int((ds.uint16(for: .bitsStored) ?? 12)) - 1,
            isSigned: (ds.uint16(for: .pixelRepresentation) ?? 0) != 0,
            samplesPerPixel: Int(ds.uint16(for: .samplesPerPixel) ?? 1),
            photometricInterpretation: .monochrome2
        )
    }

    private static func makeMetadata(
        from series: [DICOMFile],
        volume: J2KVolume,
        compressionMode: JP3DCodec.CompressionMode
    ) -> [String: Any] {
        let ds = series[0].dataSet
        var meta: [String: Any] = [
            "rows": volume.height,
            "columns": volume.width,
            "frames": volume.depth,
            "bitsAllocated": Int(ds.uint16(for: .bitsAllocated) ?? 16),
            "bitsStored": Int(ds.uint16(for: .bitsStored) ?? 12),
            "signed": (ds.uint16(for: .pixelRepresentation) ?? 0) != 0,
            "spacingX": volume.spacingX,
            "spacingY": volume.spacingY,
            "spacingZ": volume.spacingZ,
            "originX": volume.originX,
            "originY": volume.originY,
            "originZ": volume.originZ,
            "generator": "DICOMKit/JP3DVolumeDocument",
            "version": 1
        ]

        // Store compression mode for informational purposes
        switch compressionMode {
        case .lossless: meta["compressionMode"] = "lossless"
        case .losslessHTJ2K: meta["compressionMode"] = "losslessHTJ2K"
        case .lossy(let psnr): meta["compressionMode"] = "lossy"; meta["psnr"] = psnr
        case .lossyHTJ2K(let psnr): meta["compressionMode"] = "lossyHTJ2K"; meta["psnr"] = psnr
        }

        // Slice spacing
        if series.count > 1,
           let sp = computeSliceSpacing(series) {
            meta["sliceSpacing"] = sp
        }

        // First slice origin
        if let pos = series[0].dataSet.string(for: .imagePositionPatient) {
            let parts = pos.split(separator: "\\").compactMap { Double(String($0).trimmingCharacters(in: .whitespaces)) }
            if parts.count == 3 {
                meta["origin"] = parts
            }
        }

        // Preserve key patient/study tags for round-trip fidelity
        if let uid = ds.string(for: .studyInstanceUID) { meta["studyInstanceUID"] = uid }
        if let uid = ds.string(for: .seriesInstanceUID) { meta["sourceSeriesInstanceUID"] = uid }
        if let name = ds.string(for: .patientName) { meta["patientName"] = name }
        if let pid = ds.string(for: .patientID) { meta["patientID"] = pid }
        if let mod = ds.string(for: .modality) { meta["modality"] = mod }
        if let sn = ds.string(for: .seriesDescription) { meta["seriesDescription"] = sn }
        if let thick = ds.string(for: .sliceThickness) { meta["sliceThickness"] = thick }

        return meta
    }

    private static func computeSliceSpacing(_ series: [DICOMFile]) -> Double? {
        guard series.count > 1 else { return nil }
        var positions: [Double] = []
        for file in series {
            if let pos = file.dataSet.string(for: .imagePositionPatient) {
                let parts = pos.split(separator: "\\").compactMap { Double($0) }
                if parts.count == 3 { positions.append(parts[2]); continue }
            }
            if let loc = file.dataSet.string(for: .sliceLocation).flatMap(Double.init) {
                positions.append(loc)
            }
        }
        guard positions.count >= 2 else { return nil }
        return (positions.last! - positions.first!) / Double(positions.count - 1)
    }

    private static func buildTemplate(from meta: [String: Any], fileDataSet: DataSet) -> DICOMFile {
        var ds = DataSet()
        if let name = (meta["patientName"] as? String) ?? fileDataSet.string(for: .patientName) {
            ds.setString(name, for: .patientName, vr: .PN)
        }
        if let pid = (meta["patientID"] as? String) ?? fileDataSet.string(for: .patientID) {
            ds.setString(pid, for: .patientID, vr: .LO)
        }
        if let uid = (meta["studyInstanceUID"] as? String) ?? fileDataSet.string(for: .studyInstanceUID) {
            ds.setString(uid, for: .studyInstanceUID, vr: .UI)
        }
        if let uid = meta["sourceSeriesInstanceUID"] as? String {
            ds.setString(uid, for: .seriesInstanceUID, vr: .UI)
        }
        if let mod = meta["modality"] as? String {
            ds.setString(mod, for: .modality, vr: .CS)
        }
        let fmi = DataSet()
        return DICOMFile(fileMetaInformation: fmi, dataSet: ds)
    }

    private static func reconstructSlices(
        pixelData: Data,
        descriptor: PixelDataDescriptor,
        template: DICOMFile,
        sliceSpacing: Double,
        origin: [Double]
    ) throws -> [DICOMFile] {
        let bytesPerFrame = descriptor.bytesPerFrame
        let seriesUID = template.dataSet.string(for: .seriesInstanceUID) ?? UIDGenerator.generateUID().value
        let studyUID = template.dataSet.string(for: .studyInstanceUID) ?? UIDGenerator.generateUID().value

        var slices: [DICOMFile] = []
        for i in 0..<descriptor.numberOfFrames {
            let start = i * bytesPerFrame
            guard start + bytesPerFrame <= pixelData.count else { break }
            let frameData = pixelData.subdata(in: start..<(start + bytesPerFrame))

            var ds = template.dataSet

            // Geometry
            ds.setUInt16(UInt16(descriptor.rows), for: .rows)
            ds.setUInt16(UInt16(descriptor.columns), for: .columns)
            ds.setUInt16(UInt16(descriptor.bitsAllocated), for: .bitsAllocated)
            ds.setUInt16(UInt16(descriptor.bitsStored), for: .bitsStored)
            ds.setUInt16(UInt16(descriptor.bitsStored - 1), for: .highBit)
            ds.setUInt16(descriptor.isSigned ? 1 : 0, for: .pixelRepresentation)
            ds.setUInt16(1, for: .samplesPerPixel)
            ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)

            // Identity
            ds.setString(UIDGenerator.generateUID().value, for: .sopInstanceUID, vr: .UI)
            ds.setString(studyUID, for: .studyInstanceUID, vr: .UI)
            ds.setString(seriesUID, for: .seriesInstanceUID, vr: .UI)
            ds.setInt(i + 1, for: .instanceNumber, vr: .IS)

            // Spatial position
            let z = (origin.count >= 3 ? origin[2] : 0.0) + Double(i) * sliceSpacing
            let x = origin.count >= 1 ? origin[0] : 0.0
            let y = origin.count >= 2 ? origin[1] : 0.0
            ds.setString("\(x)\\\(y)\\\(z)", for: .imagePositionPatient, vr: .DS)
            ds.setString(String(z), for: .sliceLocation, vr: .DS)

            // Pixel data (uncompressed)
            ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: frameData)

            let sliceFile = try DICOMFile.create(
                dataSet: ds,
                sopClassUID: template.dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: ds.string(for: .sopInstanceUID) ?? UIDGenerator.generateUID().value,
                transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
            )
            slices.append(sliceFile)
        }
        return slices
    }
}
