// ConvertRoundTripTests.swift
// Oracle-based round-trip tests for `dicom-convert`.
//
// These exercise the SAME DICOMKit APIs the CLI invokes — `DICOMConverter`
// (transfer-syntax transcode) and `DICOMImageExporter` (image export) — never
// the CLI binary. Every assertion is a math/semantic oracle, not a comparison
// against a re-implementation.
//
// Verified against source:
//   Sources/DICOMKit/DICOMConverter.swift
//   Sources/DICOMKit/ImageExport/DICOMImageExporter.swift
//   Sources/DICOMKit/DICOMFile+Write.swift  (DICOMFile.create)
//   Sources/DICOMKit/DICOMFile+PixelData.swift (tryPixelData, rescale*, windowSettings, tryRenderFrame)
//   Sources/DICOMCore/TransferSyntax.swift  (uid, isLossless, constants, from(uid:))

import XCTest
@testable import DICOMKit
@testable import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class ConvertRoundTripTests: XCTestCase {

    // MARK: - Helpers (private; shared helpers live in RoundTripFixture.swift)

    /// Runs a DICOM-target conversion through the shared CLI pipeline and returns
    /// the re-parsed output file plus the raw outcome.
    private func convert(
        _ file: DICOMFile, to target: TransferSyntax, stripPrivate: Bool = false
    ) throws -> (outcome: DICOMConverter.Outcome, reread: DICOMFile) {
        let outcome = try DICOMConverter.convertToDICOM(
            dicomFile: file, to: target, stripPrivate: stripPrivate
        )
        let reread = try DICOMFile.read(from: outcome.data, force: false)
        return (outcome, reread)
    }

    // MARK: - Oracle: Implicit VR LE -> Explicit VR LE yields TS 1.2.840.10008.1.2.1 with unchanged pixel bytes (corpus MR is Implicit VR LE)

    func testImplicitToExplicit_corpusMR_pixelBytesUnchanged() throws {
        let f = try loadCorpus(.mr)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        let sourcePixels = pixelBytes(file)
        XCTAssertFalse(sourcePixels.isEmpty, "MR corpus must have native pixel data")

        let (outcome, reread) = try convert(file, to: .explicitVRLittleEndian)

        XCTAssertEqual(outcome.targetSyntax.uid, "1.2.840.10008.1.2.1")
        XCTAssertEqual(reread.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertTrue(outcome.isLossless)
        // Uncompressed -> uncompressed: the pixel octets must survive byte-for-byte.
        XCTAssertEqual(Array(pixelBytes(reread)), Array(sourcePixels))
    }

    // MARK: - Oracle: Implicit VR LE -> Explicit VR LE preserves synthetic pixels exactly

    func testImplicitToExplicit_synthetic_pixelExact() throws {
        // makeGrayscale16 produces an Explicit-VR file; transcode it *to* Implicit
        // first so we have a genuine Implicit source, then back to Explicit.
        let original = makeGrayscale16(rows: 8, cols: 8, fillPattern: { UInt16($0 * 7 % 4096) })
        let originalPixels = pixelBytes(original)

        let toImplicit = try convert(original, to: .implicitVRLittleEndian)
        XCTAssertEqual(toImplicit.reread.transferSyntaxUID, "1.2.840.10008.1.2")
        XCTAssertEqual(Array(pixelBytes(toImplicit.reread)), Array(originalPixels))

        let backToExplicit = try convert(toImplicit.reread, to: .explicitVRLittleEndian)
        XCTAssertEqual(backToExplicit.reread.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertEqual(Array(pixelBytes(backToExplicit.reread)), Array(originalPixels))
    }

    // MARK: - Oracle: Explicit VR LE -> DEFLATED (1.2.840.10008.1.2.1.99) is re-readable and pixel-exact after inflation

    func testExplicitToDeflate_reReadablePixelExact() throws {
        let original = makeGrayscale16(rows: 16, cols: 16, fillPattern: { UInt16($0 % 4096) })
        let originalPixels = pixelBytes(original)

        let (outcome, reread) = try convert(original, to: .deflatedExplicitVRLittleEndian)

        XCTAssertEqual(outcome.targetSyntax.uid, "1.2.840.10008.1.2.1.99")
        XCTAssertEqual(reread.transferSyntaxUID, "1.2.840.10008.1.2.1.99")
        XCTAssertTrue(outcome.isLossless)
        // DICOMFile.read inflates the deflated data set; pixels must be recovered exactly.
        XCTAssertEqual(Array(pixelBytes(reread)), Array(originalPixels))
    }

    // MARK: - Oracle: RLE Lossless round-trip is pixel-exact (lossless TS in -> back)

    func testRLELossless_roundTrip_pixelExact() throws {
        let original = makeGrayscale8(rows: 32, cols: 32, fillPattern: { UInt8(($0 * 3) % 256) })
        let originalPixels = pixelBytes(original)

        // Forward: Explicit VR LE -> RLE Lossless (encapsulated).
        let rle = try convert(original, to: .rleLossless)
        XCTAssertEqual(rle.reread.transferSyntaxUID, "1.2.840.10008.1.2.5")
        XCTAssertTrue(rle.outcome.isLossless)

        // Back: RLE Lossless -> Explicit VR LE. Lossless codec => pixel-exact recovery.
        let back = try convert(rle.reread, to: .explicitVRLittleEndian)
        XCTAssertEqual(back.reread.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertEqual(Array(pixelBytes(back.reread)), Array(originalPixels))
    }

    // MARK: - Oracle: JPEG XL JPEG Recompression (…4.111) losslessly rewraps a JPEG bitstream

    /// Encapsulated fragment bytes of a file's PixelData (empty for native pixel data).
    private func fragments(_ file: DICOMFile) -> [Data] {
        file.dataSet[.pixelData]?.encapsulatedFragments ?? []
    }

    /// Full forward+reverse recompression round-trip on a JPEG-Baseline source built
    /// hermetically from synthetic 8-bit pixels:
    ///   grayscale8 → JPEG Baseline (…4.50) → JPEG XL Recompression (…4.111) → JPEG Baseline.
    /// Oracle 1: the wrap and unwrap both report *lossless* (recompression adds no loss).
    /// Oracle 2: the reconstructed JPEG fragment is **byte-identical** to the original
    ///           Baseline fragment — the defining property of JPEG recompression.
    func testJXLRecompression_roundTrip_jpegFragmentByteIdentical() throws {
        let original = makeGrayscale8(rows: 32, cols: 32, fillPattern: { UInt8(($0 * 7) % 256) })

        // Uncompressed → JPEG Baseline (lossy DCT — the recompression *source*).
        let baseline = try convert(original, to: .jpegBaseline)
        XCTAssertEqual(baseline.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.50")
        let baselineFragments = fragments(baseline.reread)
        XCTAssertFalse(baselineFragments.isEmpty, "Baseline source must have encapsulated JPEG fragments")

        // JPEG Baseline → JPEG XL Recompression (…4.111). No added loss.
        let recomp = try convert(baseline.reread, to: .jpegXLRecompression)
        XCTAssertEqual(recomp.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.111")
        XCTAssertTrue(recomp.outcome.isLossless, "wrapping a JPEG in JXL is lossless")
        XCTAssertTrue(recomp.outcome.wasTranscoded)
        XCTAssertFalse(fragments(recomp.reread).isEmpty, "…4.111 output must be encapsulated")

        // …4.111 → JPEG Baseline (reverse). Byte-identical reconstruction.
        let back = try convert(recomp.reread, to: .jpegBaseline)
        XCTAssertEqual(back.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.50")
        XCTAssertTrue(back.outcome.isLossless, "reconstructing the original JPEG is lossless")
        let reconstructed = fragments(back.reread)
        XCTAssertEqual(reconstructed.count, baselineFragments.count, "frame count preserved")
        for (i, (a, b)) in zip(reconstructed, baselineFragments).enumerated() {
            XCTAssertEqual(Array(a), Array(b), "reconstructed JPEG fragment \(i) must be byte-identical")
        }
    }

    /// Same round trip as above, but for a 3-component (RGB) JPEG Baseline source —
    /// JXLSwift's recompression path explicitly allows 1- or 3-component frames
    /// (`nComponents == 1 || nComponents == 3`); this proves the 3-component branch
    /// end-to-end rather than by absence of a restriction:
    ///   RGB8 → JPEG Baseline (…4.50) → JPEG XL Recompression (…4.111) → JPEG Baseline.
    func testJXLRecompression_roundTrip_jpegFragmentByteIdentical_RGB() throws {
        let original = makeRGB8(rows: 32, cols: 32)

        // Uncompressed RGB → JPEG Baseline (lossy DCT — the recompression *source*).
        let baseline = try convert(original, to: .jpegBaseline)
        XCTAssertEqual(baseline.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.50")
        let baselineFragments = fragments(baseline.reread)
        XCTAssertFalse(baselineFragments.isEmpty, "Baseline source must have encapsulated JPEG fragments")

        // JPEG Baseline → JPEG XL Recompression (…4.111). No added loss.
        let recomp = try convert(baseline.reread, to: .jpegXLRecompression)
        XCTAssertEqual(recomp.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.111")
        XCTAssertTrue(recomp.outcome.isLossless, "wrapping a JPEG in JXL is lossless")
        XCTAssertTrue(recomp.outcome.wasTranscoded)
        XCTAssertFalse(fragments(recomp.reread).isEmpty, "…4.111 output must be encapsulated")

        // …4.111 → JPEG Baseline (reverse). Byte-identical reconstruction.
        let back = try convert(recomp.reread, to: .jpegBaseline)
        XCTAssertEqual(back.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.50")
        XCTAssertTrue(back.outcome.isLossless, "reconstructing the original JPEG is lossless")
        let reconstructed = fragments(back.reread)
        XCTAssertEqual(reconstructed.count, baselineFragments.count, "frame count preserved")
        for (i, (a, b)) in zip(reconstructed, baselineFragments).enumerated() {
            XCTAssertEqual(Array(a), Array(b), "reconstructed JPEG fragment \(i) must be byte-identical")
        }
    }

    /// RGB counterpart of `testJXLRecompression_decodeToPixels_matchesBaseline`: decoding
    /// a …4.111 file built from a 3-component JPEG must yield exactly the wrapped JPEG's
    /// decoded pixels.
    func testJXLRecompression_decodeToPixels_matchesBaseline_RGB() throws {
        let original = makeRGB8(rows: 24, cols: 24)

        let baseline = try convert(original, to: .jpegBaseline)
        let recomp = try convert(baseline.reread, to: .jpegXLRecompression)

        let baselinePixels = try baseline.reread.tryPixelData().data
        let recompPixels = try recomp.reread.tryPixelData().data

        XCTAssertFalse(recompPixels.isEmpty)
        XCTAssertEqual(recompPixels.count, 24 * 24 * 3, "8-bit 24×24 RGB => 1728 pixel octets")
        XCTAssertEqual(Array(recompPixels), Array(baselinePixels),
                       "…4.111 pixel decode must equal the wrapped JPEG's pixels")
    }

    /// Decoding a …4.111 file *to pixels* yields exactly the pixels of the wrapped JPEG.
    /// Oracle: the decoded pixels of the …4.111 file equal the decoded pixels of the
    /// Baseline source it was made from (both decode the same JPEG bitstream). The
    /// direct `tryPixelData()` decode is used because DICOMConverter's guard blocks
    /// decompressing a *lossy* source to uncompressed — a pre-existing policy unrelated
    /// to …4.111 (which decodes fine because recompression is flagged lossless).
    func testJXLRecompression_decodeToPixels_matchesBaseline() throws {
        let original = makeGrayscale8(rows: 24, cols: 24, fillPattern: { UInt8(($0 * 5 + 3) % 256) })

        let baseline = try convert(original, to: .jpegBaseline)
        let recomp = try convert(baseline.reread, to: .jpegXLRecompression)

        let baselinePixels = try baseline.reread.tryPixelData().data
        let recompPixels = try recomp.reread.tryPixelData().data

        XCTAssertFalse(recompPixels.isEmpty)
        XCTAssertEqual(recompPixels.count, 24 * 24, "8-bit 24×24 grayscale => 576 pixel octets")
        XCTAssertEqual(Array(recompPixels), Array(baselinePixels),
                       "…4.111 pixel decode must equal the wrapped JPEG's pixels")
    }

    /// A …4.111 file is a usable *source* for an onward transfer-syntax transcode — the
    /// user scenario "recompress to …4.111, then convert again to J2K Lossless". Oracle:
    /// the transcode succeeds, yields a valid encapsulated J2K Lossless (…4.90) file, and
    /// its decoded pixels equal the …4.111 file's decoded pixels (the pixel-level step is
    /// lossless J2K, so no further loss beyond the JPEG already in the bitstream).
    func testJXLRecompression_onwardTranscodeToJ2KLossless() throws {
        let original = makeGrayscale8(rows: 24, cols: 24, fillPattern: { UInt8(($0 * 5 + 3) % 256) })
        let baseline = try convert(original, to: .jpegBaseline)
        let recomp = try convert(baseline.reread, to: .jpegXLRecompression)

        let j2k = try convert(recomp.reread, to: .jpeg2000Lossless)
        XCTAssertEqual(j2k.reread.transferSyntaxUID, "1.2.840.10008.1.2.4.90")
        XCTAssertTrue(j2k.outcome.wasTranscoded)
        XCTAssertFalse(fragments(j2k.reread).isEmpty, "J2K Lossless output must be encapsulated")

        // The lossless J2K pixel step preserves the …4.111 pixels exactly.
        XCTAssertEqual(Array(try j2k.reread.tryPixelData().data),
                       Array(try recomp.reread.tryPixelData().data),
                       "J2K Lossless from …4.111 must preserve the decoded pixels")
    }

    /// Recompression requires a JPEG bitstream: an uncompressed (non-JPEG) source cannot
    /// be targeted at …4.111 (there is no pixel encoder for it). Oracle: the transcode is
    /// rejected rather than silently producing a wrong or lossy result.
    func testJXLRecompression_rejectsNonJPEGSource() throws {
        let original = makeGrayscale8(rows: 16, cols: 16)
        XCTAssertThrowsError(try DICOMConverter.convertToDICOM(
            dicomFile: original, to: .jpegXLRecompression, stripPrivate: false
        ), "uncompressed → …4.111 must be rejected (recompression needs a JPEG source)")
    }

    // MARK: - Oracle: --strip-private removes odd-group (private) tags; public tags survive

    func testStripPrivate_removesPrivateTagsOnly() throws {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setUInt16(4, for: .rows)
        ds.setUInt16(4, for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: Data(repeating: 5, count: 16))
        // A private (odd group) element.
        let privateTag = Tag(group: 0x0009, element: 0x0010)
        ds[privateTag] = DataElement.data(tag: privateTag, vr: .LO, data: Data("ACME".utf8))
        let file = DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.7")

        XCTAssertTrue(file.dataSet.tags.contains(where: { $0.isPrivate }))

        let (outcome, reread) = try convert(file, to: .explicitVRLittleEndian, stripPrivate: true)

        XCTAssertGreaterThanOrEqual(outcome.strippedPrivateTagCount, 1)
        // No private tags remain; a known public tag (Modality) is preserved.
        XCTAssertFalse(reread.dataSet.tags.contains(where: { $0.isPrivate }))
        XCTAssertEqual(reread.dataSet.string(for: .modality), "CT")
    }

    // MARK: - Oracle: same-syntax convert is a no-op transcode (wasTranscoded == false)

    func testSameSyntax_noOpTranscode() throws {
        let original = makeGrayscale8(rows: 8, cols: 8)
        let (outcome, reread) = try convert(original, to: .explicitVRLittleEndian)
        XCTAssertFalse(outcome.wasTranscoded)
        XCTAssertEqual(Array(pixelBytes(reread)), Array(pixelBytes(original)))
    }

    #if canImport(CoreGraphics)
    // MARK: - Oracle: exported PNG dimensions equal Columns x Rows

    func testPNGExport_dimensionsMatchColumnsRows() throws {
        let rows: UInt16 = 24, cols: UInt16 = 40
        let file = makeGrayscale16(rows: rows, cols: cols, fillPattern: { UInt16($0 % 4096) })
        let pixelData = try file.tryPixelData()

        let image = try DICOMImageExporter.renderFrameForExport(
            file: file, pixelData: pixelData, frameIndex: 0,
            applyWindow: false, windowCenter: nil, windowWidth: nil
        )
        // CGImage raster dimensions must equal the DICOM Columns (width) / Rows (height).
        XCTAssertEqual(image.width, Int(cols))
        XCTAssertEqual(image.height, Int(rows))
    }

    // MARK: - Oracle: explicit --window-center/--width changes the exported raster vs the default render

    func testWindowSettings_honoredInExport() throws {
        // 16-bit ramp so a narrow window materially changes the mapping.
        let rows: UInt16 = 16, cols: UInt16 = 16
        let file = makeGrayscale16(
            rows: rows, cols: cols,
            fillPattern: { UInt16(($0 * 16) % 4096) }
        )
        let pixelData = try file.tryPixelData()

        let defaultImage = try DICOMImageExporter.renderFrameForExport(
            file: file, pixelData: pixelData, frameIndex: 0,
            applyWindow: false, windowCenter: nil, windowWidth: nil
        )
        let windowedImage = try DICOMImageExporter.renderFrameForExport(
            file: file, pixelData: pixelData, frameIndex: 0,
            applyWindow: true, windowCenter: 1000, windowWidth: 200
        )

        // Both rasters share geometry...
        XCTAssertEqual(defaultImage.width, windowedImage.width)
        XCTAssertEqual(defaultImage.height, windowedImage.height)
        // ...but a distinct explicit window must produce a different pixel raster.
        XCTAssertNotEqual(cgImageBytes(defaultImage), cgImageBytes(windowedImage))
    }

    /// Reads the raw byte buffer backing a CGImage for equality oracles.
    private func cgImageBytes(_ image: CGImage) -> Data? {
        guard let provider = image.dataProvider, let data = provider.data else { return nil }
        return data as Data
    }
    #endif
}

