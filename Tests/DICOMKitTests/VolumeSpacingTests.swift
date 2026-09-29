import Foundation
import Testing
@testable import DICOMKit
import DICOMCore

/// Pins `DICOMFile.openVolume` to the Image Plane Module (PS3.3 Table C.7-10,
/// C.7.6.2.1.1) and Image Pixel Module (Table C.7-11c) semantics: slice spacing
/// comes from Image Position (Patient) along the slice normal (or Spacing Between
/// Slices), never from the nominal Slice Thickness when something better exists,
/// and the source Photometric Interpretation / High Bit / Pixel Representation
/// are honoured instead of assumed.
@Suite("Volume spacing and pixel module")
struct VolumeSpacingTests {

    private static let ctSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    private func ds(_ value: Double) -> String { String(format: "%.6f", value) }

    private func makeSlice(
        index: Int,
        position: (Double, Double, Double),
        orientation: [Double]?,
        sliceThickness: String,
        spacingBetweenSlices: String? = nil,
        photometric: String = "MONOCHROME2",
        firstPixel: UInt16 = 100
    ) throws -> DICOMFile {
        var ds = DataSet()
        ds.setUInt16(2, for: .rows)
        ds.setUInt16(2, for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(12, for: .bitsStored)
        ds.setUInt16(11, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString(photometric, for: .photometricInterpretation, vr: .CS)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setString("1.2.3.4", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5", for: .seriesInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.\(index + 1)", for: .sopInstanceUID, vr: .UI)
        ds.setString(Self.ctSOPClass, for: .sopClassUID, vr: .UI)
        ds.setInt(index + 1, for: .instanceNumber, vr: .IS)
        ds.setString("\(self.ds(position.0))\\\(self.ds(position.1))\\\(self.ds(position.2))",
                     for: .imagePositionPatient, vr: .DS)
        if let orientation {
            ds.setString(orientation.map(self.ds).joined(separator: "\\"), for: .imageOrientationPatient, vr: .DS)
        }
        ds.setString("0.5\\0.75", for: .pixelSpacing, vr: .DS) // row spacing 0.5, column spacing 0.75
        ds.setString(sliceThickness, for: .sliceThickness, vr: .DS)
        if let spacingBetweenSlices {
            ds.setString(spacingBetweenSlices, for: .spacingBetweenSlices, vr: .DS)
        }
        var pixels = Data()
        for v in [firstPixel, 200, 300, 400] {
            var le = v.littleEndian
            pixels.append(Data(bytes: &le, count: 2))
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        return try DICOMFile.create(
            dataSet: ds, sopClassUID: Self.ctSOPClass,
            sopInstanceUID: "1.2.3.4.5.\(index + 1)",
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid)
    }

    private func writeSeries(_ files: [DICOMFile]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("volume_spacing_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Reverse file-name order so the result depends on the position sort, not on names.
        for (i, file) in files.enumerated() {
            try file.write().write(to: dir.appendingPathComponent("slice_\(files.count - i).dcm"))
        }
        return dir
    }

    // MARK: - Slice spacing

    @Test("slice spacing is the Image Position (Patient) delta along the normal, not Slice Thickness")
    func sliceSpacing_fromPositionsAlongNormal() async throws {
        // Row cosines (1,0,0), column cosines (0, cos45°, sin45°) → normal (0, −sin45°, cos45°).
        let c = 0.5.squareRoot()
        let orientation = [1.0, 0.0, 0.0, 0.0, c, c]
        let spacing = 2.5
        let files = try (0..<3).map { k in
            try makeSlice(index: k,
                          position: (0, -c * spacing * Double(k), c * spacing * Double(k)),
                          orientation: orientation,
                          sliceThickness: "5.0")
        }
        let dir = try writeSeries(files)
        defer { try? FileManager.default.removeItem(at: dir) }

        let volume = try await DICOMFile.openVolume(from: dir)
        #expect(volume.depth == 3)
        // The z delta alone is 1.7678 and Slice Thickness says 5.0; the standard's
        // centre-to-centre distance along the normal is 2.5.
        #expect(abs(volume.spacingZ - spacing) < 1e-6)
        // Pixel Spacing is "adjacent row spacing \ adjacent column spacing": Y then X.
        #expect(abs(volume.spacingY - 0.5) < 1e-9)
        #expect(abs(volume.spacingX - 0.75) < 1e-9)
        // First slice is the one at the origin regardless of file-name order.
        #expect(abs(volume.originX) < 1e-9 && abs(volume.originY) < 1e-9 && abs(volume.originZ) < 1e-9)
    }

    @Test("without an orientation the Euclidean distance between positions is used")
    func sliceSpacing_euclideanWithoutOrientation() async throws {
        let files = try (0..<2).map { k in
            try makeSlice(index: k, position: (0, 0, 3.0 * Double(k)), orientation: nil, sliceThickness: "1.0")
        }
        let dir = try writeSeries(files)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volume = try await DICOMFile.openVolume(from: dir)
        #expect(abs(volume.spacingZ - 3.0) < 1e-9)
    }

    @Test("a single slice uses Spacing Between Slices before the nominal Slice Thickness")
    func sliceSpacing_singleSlice_prefersSpacingBetweenSlices() async throws {
        let dir = try writeSeries([
            try makeSlice(index: 0, position: (0, 0, 0), orientation: nil,
                          sliceThickness: "5.0", spacingBetweenSlices: "3.0"),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let volume = try await DICOMFile.openVolume(from: dir)
        #expect(abs(volume.spacingZ - 3.0) < 1e-9)
    }

    @Test("a single slice falls back to Slice Thickness only when nothing else exists")
    func sliceSpacing_singleSlice_fallsBackToThickness() async throws {
        let dir = try writeSeries([
            try makeSlice(index: 0, position: (0, 0, 0), orientation: nil, sliceThickness: "5.0"),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let volume = try await DICOMFile.openVolume(from: dir)
        #expect(abs(volume.spacingZ - 5.0) < 1e-9)
    }

    @Test("a multi-frame object uses Spacing Between Slices (0018,0088) over Slice Thickness")
    func sliceSpacing_multiframe_usesSpacingBetweenSlices() async throws {
        var ds = DataSet()
        ds.setUInt16(2, for: .rows)
        ds.setUInt16(2, for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(12, for: .bitsStored)
        ds.setUInt16(11, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setString("2", for: .numberOfFrames, vr: .IS)
        ds.setString("1.2.3.4.5.9", for: .sopInstanceUID, vr: .UI)
        ds.setString(Self.ctSOPClass, for: .sopClassUID, vr: .UI)
        ds.setString("5.0", for: .sliceThickness, vr: .DS)
        ds.setString("1.25", for: .spacingBetweenSlices, vr: .DS)
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0, count: 16))
        let file = try DICOMFile.create(dataSet: ds, sopClassUID: Self.ctSOPClass,
                                        sopInstanceUID: "1.2.3.4.5.9",
                                        transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mf_\(UUID().uuidString).dcm")
        defer { try? FileManager.default.removeItem(at: url) }
        try file.write().write(to: url)
        let volume = try await DICOMFile.openVolume(from: url)
        #expect(volume.depth == 2)
        #expect(abs(volume.spacingZ - 1.25) < 1e-9)
    }

    // MARK: - Image Pixel Module

    @Test("MONOCHROME1 stored values are preserved, not inverted (inversion is a post-VOI display step)")
    func monochrome1_storedValuesPreserved() async throws {
        let dir = try writeSeries([
            try makeSlice(index: 0, position: (0, 0, 0), orientation: nil, sliceThickness: "1.0",
                          photometric: "MONOCHROME1", firstPixel: 123),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let volume = try await DICOMFile.openVolume(from: dir)
        #expect(volume.voxel(x: 0, y: 0, z: 0) == 123)
        #expect(volume.bitsStored == 12)
        #expect(volume.isSigned == false)
    }

    @Test("the decode descriptor carries the source Photometric Interpretation, High Bit and Pixel Representation")
    func sourceDescriptor_readsImagePixelModule() throws {
        var ds = DataSet()
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(12, for: .bitsStored)
        ds.setUInt16(11, for: .highBit)
        ds.setUInt16(1, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME1", for: .photometricInterpretation, vr: .CS)
        let d = DICOMFile.sourceDescriptor(from: ds, rows: 4, columns: 5, numberOfFrames: 1)
        #expect(d.photometricInterpretation == .monochrome1)
        #expect(d.highBit == 11)
        #expect(d.isSigned == true)
        #expect(d.bitsStored == 12)

        // High Bit absent → Bits Stored − 1 (PS3.5 8.1.1: "High Bit (0028,0102)
        // shall be one less than Bits Stored (0028,0101)").
        var noHighBit = DataSet()
        noHighBit.setUInt16(16, for: .bitsAllocated)
        noHighBit.setUInt16(10, for: .bitsStored)
        let d2 = DICOMFile.sourceDescriptor(from: noHighBit, rows: 1, columns: 1, numberOfFrames: 1)
        #expect(d2.highBit == 9)
        #expect(d2.photometricInterpretation == .monochrome2)
    }
}
