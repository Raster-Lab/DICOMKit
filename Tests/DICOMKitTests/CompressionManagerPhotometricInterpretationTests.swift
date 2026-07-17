import XCTest
import Foundation
@testable import DICOMKit
import DICOMCore

/// PS3.5 Table 8.2.1-1 permits either RGB or YBR_FULL_422 as the source Photometric
/// Interpretation for JPEG Baseline/Extended. JLIEncoder/JLIDecoder always transform
/// through YCbCr internally on that lossy DCT path, so DICOMKit must (a) tell the
/// encoder when input is already YCbCr rather than re-transforming it, and (b) correct
/// the Photometric Interpretation tag after decode, since JLIDecoder always emits RGB.
final class CompressionManagerPhotometricInterpretationTests: XCTestCase {

    /// 16x16, 8-bit, 3-samples-per-pixel uncompressed file with the given Photometric
    /// Interpretation. Component values form a smooth, non-degenerate gradient so a
    /// color-space transform (or lack of one) is actually observable in the output.
    private func makeUncompressedColorFile(photometricInterpretation: String) throws -> Data {
        var els: [DataElement] = []
        els.append(.uint16(tag: .rows, value: 16))
        els.append(.uint16(tag: .columns, value: 16))
        els.append(.uint16(tag: .bitsAllocated, value: 8))
        els.append(.uint16(tag: .bitsStored, value: 8))
        els.append(.uint16(tag: .highBit, value: 7))
        els.append(.uint16(tag: .pixelRepresentation, value: 0))
        els.append(.uint16(tag: .samplesPerPixel, value: 3))
        els.append(.uint16(tag: .planarConfiguration, value: 0))
        els.append(.string(tag: .photometricInterpretation, vr: .CS, value: photometricInterpretation))
        els.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"))
        els.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9"))
        var pixels = Data()
        for y in 0..<16 {
            for x in 0..<16 {
                pixels.append(UInt8((x * 16) % 256))
                pixels.append(UInt8((y * 16) % 256))
                pixels.append(UInt8(((x + y) * 8) % 256))
            }
        }
        els.append(DataElement(tag: .pixelData, vr: .OB, length: UInt32(pixels.count), valueData: pixels))
        let ds = DataSet(elements: els)
        return try DICOMFile.create(dataSet: ds,
                                    transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()
    }

    /// Decompressing a JPEG Baseline object whose source declared YBR_FULL_422 must
    /// rewrite the tag to RGB, since JLIDecoder's output is always RGB regardless of
    /// what the source declared. A stale YBR_FULL_422 tag over RGB bytes would cause
    /// any consumer that trusts the tag (e.g. a YBR->RGB display path) to corrupt
    /// color by converting already-RGB data a second time.
    func testDecompressingBaselineRewritesYBRTagToRGB() throws {
        let input = try makeUncompressedColorFile(photometricInterpretation: "YBR_FULL_422")
        let mgr = CompressionManager()
        let compressed = try mgr.compressData(input, codec: "jpeg", quality: .high)
        let decompressed = try mgr.decompressData(compressed, syntax: .explicitVRLittleEndian)

        let ds = try DICOMFile.read(from: decompressed).dataSet
        XCTAssertEqual(ds.string(for: .photometricInterpretation)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "RGB",
            "decompressed Baseline object must carry RGB, matching JLIDecoder's actual output")
    }

    /// An RGB-declared source needs no correction — the tag already matches what
    /// JLIDecoder produces.
    func testDecompressingBaselineLeavesRGBTagUnchanged() throws {
        let input = try makeUncompressedColorFile(photometricInterpretation: "RGB")
        let mgr = CompressionManager()
        let compressed = try mgr.compressData(input, codec: "jpeg", quality: .high)
        let decompressed = try mgr.decompressData(compressed, syntax: .explicitVRLittleEndian)

        let ds = try DICOMFile.read(from: decompressed).dataSet
        XCTAssertEqual(ds.string(for: .photometricInterpretation)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "RGB")
    }

    /// JPEG Lossless (SOF3) never applies a color transform, so the tag round-trips
    /// unchanged regardless of which color-ish value it declares.
    func testDecompressingLosslessLeavesYBRTagUnchanged() throws {
        let input = try makeUncompressedColorFile(photometricInterpretation: "YBR_FULL")
        let mgr = CompressionManager()
        let compressed = try mgr.compressData(input, codec: "jpeg-lossless-sv1", quality: nil)
        let decompressed = try mgr.decompressData(compressed, syntax: .explicitVRLittleEndian)

        let ds = try DICOMFile.read(from: decompressed).dataSet
        XCTAssertEqual(ds.string(for: .photometricInterpretation)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "YBR_FULL")
    }

    /// Compressing YBR_FULL_422 input must not silently corrupt it by re-running it
    /// through an RGB->YCbCr transform: encoding the same raw bytes as RGB vs. as
    /// YBR_FULL_422 must take different code paths and diverge at the compressed
    /// byte level. (Before the fix, JLICodec ignored photometricInterpretation
    /// entirely, so both produced byte-identical output.)
    func testCompressingRGBAndYBRSourcesDivergeAtByteLevel() throws {
        let rgbInput = try makeUncompressedColorFile(photometricInterpretation: "RGB")
        let ybrInput = try makeUncompressedColorFile(photometricInterpretation: "YBR_FULL_422")
        let mgr = CompressionManager()

        let rgbCompressed = try mgr.compressData(rgbInput, codec: "jpeg", quality: .high)
        let ybrCompressed = try mgr.compressData(ybrInput, codec: "jpeg", quality: .high)

        let rgbFragment = try XCTUnwrap(
            try DICOMFile.read(from: rgbCompressed).dataSet[.pixelData]?.encapsulatedFragments?.first)
        let ybrFragment = try XCTUnwrap(
            try DICOMFile.read(from: ybrCompressed).dataSet[.pixelData]?.encapsulatedFragments?.first)

        XCTAssertNotEqual(rgbFragment, ybrFragment,
                          "RGB and YBR_FULL_422 sources produced identical JPEG bytes — "
                          + "photometricInterpretation is being ignored on encode")
    }
}
