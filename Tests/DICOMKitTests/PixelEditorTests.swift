import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Regression tests for `PixelEditor` operating on compressed (encapsulated) sources.
///
/// A compressed Pixel Data element holds a fragmented/compressed bitstream, not a flat
/// pixel array. Editing those bytes in place corrupts the bitstream, and the result —
/// still tagged as the compressed transfer syntax — cannot be decoded by a viewer such
/// as Horos, so the image fails to display. `PixelEditor` must therefore decode such a
/// source to native pixels and emit uncompressed Explicit VR Little Endian.
final class PixelEditorTests: XCTestCase {

    /// Builds a minimal single-frame 16-bit MONOCHROME2 image with sequential pixels.
    private func makeUncompressed(rows: Int = 8, columns: Int = 8) -> DICOMFile {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setUInt16(UInt16(rows), for: .rows)
        ds.setUInt16(UInt16(columns), for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(16, for: .bitsStored)
        ds.setUInt16(15, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        var px = Data()
        for i in 0..<(rows * columns) {
            let v = UInt16(i % 256)
            px.append(UInt8(v & 0xFF)); px.append(UInt8(v >> 8))
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: px)
        return DICOMFile.create(
            dataSet: ds,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
        )
    }

    /// Builds a multi-frame 16-bit MONOCHROME2 image where every pixel of frame `f`
    /// holds the constant value `f + 1`, so per-frame edits are trivial to assert.
    private func makeMultiFrame(rows: Int = 4, columns: Int = 4, frames: Int = 3) -> DICOMFile {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.10", for: .sopInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds.setUInt16(UInt16(rows), for: .rows)
        ds.setUInt16(UInt16(columns), for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(16, for: .bitsStored)
        ds.setUInt16(15, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("\(frames)", for: .numberOfFrames, vr: .IS)
        var px = Data()
        for f in 0..<frames {
            let v = UInt16(f + 1)
            for _ in 0..<(rows * columns) {
                px.append(UInt8(v & 0xFF)); px.append(UInt8(v >> 8))
            }
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: px)
        return DICOMFile.create(
            dataSet: ds,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid
        )
    }

    private func readU16(_ d: Data, _ index: Int) -> Int {
        let o = d.startIndex + index * 2
        return Int(d[o]) | (Int(d[o + 1]) << 8)
    }

    /// Inverting an RLE-compressed source must decode it, invert the native pixels, and
    /// write uncompressed Explicit VR Little Endian — not invert the compressed bytes and
    /// re-tag the file as RLE (which yields an undisplayable image).
    func testInvertOnRLECompressedSourceDecodesAndWritesUncompressed() throws {
        let original = makeUncompressed()
        let originalPixels = try original.tryPixelData().data

        // Encode to RLE Lossless (encapsulated) via the shared converter.
        let rleBytes = try DICOMConverter.convertToDICOM(
            dicomFile: original, to: .rleLossless, stripPrivate: false).data
        let rleFile = try DICOMFile.read(from: rleBytes)
        XCTAssertEqual(rleFile.transferSyntaxUID, TransferSyntax.rleLossless.uid,
                       "test setup: source should be RLE-encapsulated")

        // Invert through the shared editor.
        let (outBytes, info) = try PixelEditor(verbose: false)
            .processData(rleBytes, operations: [.invert])

        // Output must be uncompressed Explicit VR LE and re-readable.
        let out = try DICOMFile.read(from: outBytes)
        XCTAssertEqual(out.transferSyntaxUID, TransferSyntax.explicitVRLittleEndian.uid,
                       "a compressed source must be re-emitted uncompressed so viewers can display it")
        XCTAssertFalse(TransferSyntax.from(uid: out.transferSyntaxUID ?? "")?.isEncapsulated ?? true,
                       "output transfer syntax must not be encapsulated")

        // Pixel data must be native (directly decodable) and correctly inverted.
        let outPixels = try out.tryPixelData().data
        XCTAssertEqual(outPixels.count, originalPixels.count)
        XCTAssertEqual(info.rows, 8)
        XCTAssertEqual(info.columns, 8)

        // bitsStored 16 → maxVal 65535; inverted = 65535 - original (lossless round-trip).
        for i in 0..<(8 * 8) {
            XCTAssertEqual(readU16(outPixels, i), 65535 - readU16(originalPixels, i),
                           "pixel \(i) should be inverted")
        }
    }

    /// A native (uncompressed) source must be edited in place and keep its transfer syntax,
    /// VR, and dimensions — the decode path must not perturb the existing behavior.
    func testInvertOnNativeSourceKeepsUncompressedSyntax() throws {
        let original = makeUncompressed()
        let nativeBytes = try original.write()

        let (outBytes, _) = try PixelEditor(verbose: false)
            .processData(nativeBytes, operations: [.invert])
        let out = try DICOMFile.read(from: outBytes)

        XCTAssertEqual(out.transferSyntaxUID, TransferSyntax.explicitVRLittleEndian.uid)
        XCTAssertEqual(out.dataSet[.pixelData]?.vr, .OW, "16-bit native pixel data stays OW")

        let originalPixels = try original.tryPixelData().data
        let outPixels = try out.tryPixelData().data
        XCTAssertEqual(readU16(outPixels, 0), 65535 - readU16(originalPixels, 0))
    }

    /// Invert must touch every frame of a multi-frame image, not just frame 0.
    func testInvertAppliesToAllFrames() throws {
        let bytes = try makeMultiFrame(rows: 4, columns: 4, frames: 3).write()
        let (outBytes, info) = try PixelEditor(verbose: false)
            .processData(bytes, operations: [.invert])
        XCTAssertEqual(info.rows, 4)
        XCTAssertEqual(info.columns, 4)

        let px = try DICOMFile.read(from: outBytes).tryPixelData().data
        let frameSamples = 4 * 4
        for f in 0..<3 {
            // Frame f held the constant (f + 1); inverted = 65535 - (f + 1).
            XCTAssertEqual(readU16(px, f * frameSamples), 65535 - (f + 1),
                           "frame \(f) should be inverted")
        }
    }

    /// Crop must crop every frame and preserve the frame count.
    func testCropAppliesToAllFrames() throws {
        let bytes = try makeMultiFrame(rows: 4, columns: 4, frames: 3).write()
        let (outBytes, info) = try PixelEditor(verbose: false)
            .processData(bytes, operations: [.crop(x: 0, y: 0, width: 2, height: 2)])
        XCTAssertEqual(info.rows, 2)
        XCTAssertEqual(info.columns, 2)

        let out = try DICOMFile.read(from: outBytes)
        XCTAssertEqual(out.imageColumns, 2)
        XCTAssertEqual(out.imageRows, 2)
        XCTAssertEqual(out.numberOfFrames, 3, "crop must preserve the frame count")

        let px = try out.tryPixelData().data
        XCTAssertEqual(px.count, 3 * 2 * 2 * 2, "3 frames × 2×2 × 2 bytes/sample")
        let frameSamples = 2 * 2
        for f in 0..<3 {
            XCTAssertEqual(readU16(px, f * frameSamples), f + 1,
                           "cropped frame \(f) keeps its value")
        }
    }
}
