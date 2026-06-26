import Testing
import Foundation
import DICOMKit
@testable import DICOMCore

/// Regression coverage for `CompressionManager.getCompressionInfo` reporting the
/// real Pixel Data size of an encapsulated (compressed) file. Encapsulated
/// PixelData carries the `0xFFFFFFFF` undefined-length sentinel in its length
/// field; reporting it literally surfaced as a ≈4.0 GB "Pixel Data Size" for
/// every compressed file. The fix sums the actual encapsulated fragment bytes.
@Suite("Compression info — encapsulated Pixel Data size")
struct CompressionInfoSizeTests {

    /// Builds a minimal uncompressed (Explicit VR LE) DICOM file as bytes.
    private func uncompressedDICOM(rows: UInt16 = 64, columns: UInt16 = 64,
                                   bitsAllocated: UInt16 = 8) throws -> Data {
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

        // Constant image → compresses well, so the payload is far below source.
        let pixelByteCount = Int(rows) * Int(columns) * (Int(bitsAllocated) / 8)
        let pixelData = Data(repeating: 128, count: pixelByteCount)
        let vr: VR = bitsAllocated <= 8 ? .OB : .OW
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: vr, data: pixelData)

        return try DICOMFile.create(dataSet: dataSet).write()
    }

    @Test("Native Pixel Data size is the byte count; encapsulated is the fragment payload, not the 4 GB sentinel")
    func encapsulatedSizeIsRealNotSentinel() throws {
        let manager = CompressionManager()
        let uncompressed = try uncompressedDICOM(rows: 64, columns: 64, bitsAllocated: 8)

        // Uncompressed baseline: exact 64×64×1 byte count.
        let originalInfo = try manager.getCompressionInfo(data: uncompressed)
        #expect(originalInfo.isCompressed == false)
        #expect(originalInfo.pixelDataSize == 64 * 64)

        // Compress to RLE (lossless, encapsulated) — codec-agnostic to the bug.
        let compressed = try manager.compressData(uncompressed, codec: "rle", quality: nil)
        let info = try manager.getCompressionInfo(data: compressed)

        #expect(info.isCompressed == true)
        let size = try #require(info.pixelDataSize)
        #expect(size != Int(UInt32.max))        // not the 0xFFFFFFFF sentinel (≈4.0 GB)
        #expect(size > 0)
        #expect(size <= 64 * 64)                // realistic compressed payload
    }
}
