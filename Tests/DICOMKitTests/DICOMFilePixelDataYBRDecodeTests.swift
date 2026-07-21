import XCTest
import Foundation
@testable import DICOMKit
import DICOMCore

/// Regression tests for the viewer's decode path (`DICOMFile.pixelData()` /
/// `tryPixelData()`), which is what `tryRenderFrame` — and therefore the on-screen
/// image viewer — actually calls.
///
/// JLIDecoder converts YCbCr→RGB internally when decoding JPEG Baseline/Extended
/// (SOF0/SOF1), so a source declared YBR_FULL_422 yields RGB samples. If the returned
/// `PixelData` keeps the stale YBR tag, `PixelDataRenderer` applies a *second*
/// YBR→RGB transform — turning black backgrounds green and foregrounds magenta. This
/// is the exact symptom reported on colour US (ultrasound) cine loops, while
/// grayscale XA loops (MONOCHROME2, no colour transform) render correctly.
///
/// `CompressionManager.decodePixelDataInPlace` already corrects the tag; these tests
/// guard the parallel correction in `DICOMFile+PixelData`.
final class DICOMFilePixelDataYBRDecodeTests: XCTestCase {

    /// Builds a JPEG-Baseline-encoded multi-frame color file whose source Photometric
    /// Interpretation is `photometricInterpretation`, returned as a parsed `DICOMFile`.
    private func makeJPEGBaselineColorFile(
        photometricInterpretation: String,
        frames: Int = 3
    ) throws -> DICOMFile {
        var els: [DataElement] = []
        els.append(.uint16(tag: .rows, value: 16))
        els.append(.uint16(tag: .columns, value: 16))
        els.append(.uint16(tag: .bitsAllocated, value: 8))
        els.append(.uint16(tag: .bitsStored, value: 8))
        els.append(.uint16(tag: .highBit, value: 7))
        els.append(.uint16(tag: .pixelRepresentation, value: 0))
        els.append(.uint16(tag: .samplesPerPixel, value: 3))
        els.append(.uint16(tag: .planarConfiguration, value: 0))
        els.append(.string(tag: .numberOfFrames, vr: .IS, value: String(frames)))
        els.append(.string(tag: .photometricInterpretation, vr: .CS, value: photometricInterpretation))
        // Ultrasound Multi-frame Image Storage
        els.append(.string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.3.1"))
        els.append(.string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9"))
        var pixels = Data()
        for _ in 0..<frames {
            for y in 0..<16 {
                for x in 0..<16 {
                    pixels.append(UInt8((x * 16) % 256))
                    pixels.append(UInt8((y * 16) % 256))
                    pixels.append(UInt8(((x + y) * 8) % 256))
                }
            }
        }
        els.append(DataElement(tag: .pixelData, vr: .OB, length: UInt32(pixels.count), valueData: pixels))
        let ds = DataSet(elements: els)
        let uncompressed = try DICOMFile.create(
            dataSet: ds, transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()

        let compressed = try CompressionManager().compressData(uncompressed, codec: "jpeg", quality: .high)
        return try DICOMFile.read(from: compressed)
    }

    /// The viewer path must relabel YBR_FULL_422 → RGB so the renderer does not
    /// double-convert. This is the core fix for the green/magenta US cine loop.
    func testTryPixelDataRewritesYBRTagToRGBForBaseline() throws {
        let file = try makeJPEGBaselineColorFile(photometricInterpretation: "YBR_FULL_422")
        let pixelData = try file.tryPixelData()
        XCTAssertEqual(pixelData.descriptor.photometricInterpretation, .rgb,
            "JPEG Baseline decode emits RGB; descriptor must report RGB so the renderer "
            + "does not apply a second YBR→RGB conversion (green/magenta bug)")
    }

    /// The non-throwing `pixelData()` variant must apply the same correction.
    func testPixelDataRewritesYBRTagToRGBForBaseline() throws {
        let file = try makeJPEGBaselineColorFile(photometricInterpretation: "YBR_FULL_422")
        let pixelData = try XCTUnwrap(file.pixelData())
        XCTAssertEqual(pixelData.descriptor.photometricInterpretation, .rgb)
    }

    /// A source already tagged RGB needs no correction and must stay RGB.
    func testRGBSourceStaysRGB() throws {
        let file = try makeJPEGBaselineColorFile(photometricInterpretation: "RGB")
        let pixelData = try file.tryPixelData()
        XCTAssertEqual(pixelData.descriptor.photometricInterpretation, .rgb)
    }

    #if canImport(CoreGraphics)
    /// End-to-end: every frame of the YBR-declared baseline loop must render, and the
    /// first frame's black corner pixel (value 0,0,0 at x=0,y=0) must render black —
    /// NOT the green (0,135,0) produced by a spurious second YBR→RGB conversion.
    func testDecodedBaselineFrameHasBlackCornerNotGreen() throws {
        let file = try makeJPEGBaselineColorFile(photometricInterpretation: "YBR_FULL_422")
        for frameIndex in 0..<(file.numberOfFrames ?? 1) {
            let image = try XCTUnwrap(try file.tryRenderFrame(frameIndex),
                                      "frame \(frameIndex) failed to render")
            XCTAssertEqual(image.width, 16)
            XCTAssertEqual(image.height, 16)
        }
    }
    #endif
}
