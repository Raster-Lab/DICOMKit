import Testing
import Foundation
import DICOMKit
@testable import DICOMCore

/// Regression coverage for `dicom-compress --codec deflate` (Deflated Explicit VR
/// Little Endian, PS3.5 A.5). The compress path used to relabel the file
/// 1.2.840.10008.1.2.1.99 while leaving the Data Set *un-deflated*, so every reader
/// failed with "Failed to decompress deflated data" (or silently parsed garbage and
/// reported no pixel data). The writer now actually DEFLATE-compresses the Data Set
/// — the File Meta Information stays uncompressed — so the file round-trips.
@Suite("dicom-compress deflate round-trip")
struct DeflateRoundTripTests {

    /// Compressing to deflate must produce a genuinely deflated file: smaller than the
    /// source, labeled as Deflated Explicit VR LE, and fully re-readable (the reader
    /// inflates the Data Set and recovers the pixel attributes).
    @Test("compress --codec deflate produces a smaller, readable, correctly-labeled file")
    func deflateProducesReadableFile() throws {
        let manager = CompressionManager()
        let source = try uncompressedDICOM(rows: 32, columns: 32, bitsAllocated: 8)

        let deflated = try manager.compressData(source, codec: "deflate", quality: nil)

        // Actually compressed (a constant image deflates well), not a relabel.
        #expect(deflated.count < source.count, "deflate output (\(deflated.count) B) not smaller than source (\(source.count) B)")

        // Re-readable: getCompressionInfo parses through the inflated Data Set.
        let info = try manager.getCompressionInfo(data: deflated)
        #expect(info.transferSyntaxUID == TransferSyntax.deflatedExplicitVRLittleEndian.uid)
        #expect(info.isDeflated)
        #expect(info.rows == 32)
        #expect(info.columns == 32)
        #expect(info.pixelDataSize == 32 * 32)
    }

    /// A full round-trip — uncompressed → deflate → uncompressed — must preserve the
    /// pixel data byte-for-byte (deflate is lossless).
    @Test("deflate round-trip preserves pixel data byte-for-byte")
    func deflateRoundTripIsLossless() throws {
        let manager = CompressionManager()
        let source = try uncompressedDICOM(rows: 16, columns: 16, bitsAllocated: 16, varied: true)
        let originalPixels = try #require(try pixelBytes(of: source))

        let deflated = try manager.compressData(source, codec: "deflate", quality: nil)
        let restored = try manager.decompressData(deflated, syntax: .explicitVRLittleEndian)

        let restoredInfo = try manager.getCompressionInfo(data: restored)
        #expect(restoredInfo.transferSyntaxUID == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(restoredInfo.isDeflated == false)

        let restoredPixels = try #require(try pixelBytes(of: restored))
        #expect(restoredPixels == originalPixels, "pixel data changed across the deflate round-trip")
    }

    // MARK: - Fixtures

    /// Reads the raw PixelData bytes from a serialized DICOM file.
    private func pixelBytes(of fileData: Data) throws -> Data? {
        let file = try DICOMFile.read(from: fileData)
        return file.dataSet[.pixelData]?.valueData
    }

    /// Builds a minimal uncompressed (Explicit VR LE) DICOM file as bytes.
    /// `varied` fills the pixels with a deterministic ramp so a lossless round-trip
    /// is a meaningful byte-equality check (a constant image would pass trivially).
    private func uncompressedDICOM(rows: UInt16, columns: UInt16,
                                   bitsAllocated: UInt16, varied: Bool = false) throws -> Data {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        dataSet.setUInt16(rows, for: .rows)
        dataSet.setUInt16(columns, for: .columns)
        dataSet.setUInt16(bitsAllocated, for: .bitsAllocated)
        dataSet.setUInt16(bitsAllocated, for: .bitsStored)
        dataSet.setUInt16(bitsAllocated - 1, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)

        let byteCount = Int(rows) * Int(columns) * (Int(bitsAllocated) / 8)
        let pixelData: Data
        if varied {
            pixelData = Data((0..<byteCount).map { UInt8(($0 * 7 + 3) & 0xFF) })
        } else {
            pixelData = Data(repeating: 128, count: byteCount)
        }
        let vr: VR = bitsAllocated <= 8 ? .OB : .OW
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: vr, data: pixelData)

        return try DICOMFile.create(dataSet: dataSet).write()
    }
}
