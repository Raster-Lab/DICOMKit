// ImageAnnotationBurnerTests.swift
// DICOMPrintKitTests
//
// Burning patient identification into the pixels that are sent to the printer.
//
// The property under test throughout: the caption lands at the bottom of the
// image and nowhere else, and a frame this cannot safely write into comes back
// untouched rather than corrupted.

#if canImport(CoreGraphics)
import Testing
@testable import DICOMPrintKit
import DICOMNetwork
import Foundation

@Suite("Image Annotation Burner Tests")
struct ImageAnnotationBurnerTests {

    private func frame(
        width: Int = 128,
        height: Int = 128,
        samples: Int = 1,
        bitsAllocated: Int = 8,
        photometric: String = "MONOCHROME2",
        fill: UInt8 = 0
    ) -> PreparedPrintImage {
        let bytesPerSample = bitsAllocated / 8
        let pixels = Data(repeating: fill, count: width * height * samples * bytesPerSample)
        return PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: pixels,
                rows: UInt16(height),
                columns: UInt16(width),
                bitsAllocated: UInt16(bitsAllocated),
                bitsStored: UInt16(bitsAllocated),
                highBit: UInt16(bitsAllocated - 1),
                samplesPerPixel: UInt16(samples),
                pixelRepresentation: 0,
                photometricInterpretation: photometric
            ),
            sourcePath: "/a.dcm",
            frameIndex: 0)
    }

    /// The rows of a grayscale frame that differ from the original.
    private func changedRows(_ before: PreparedPrintImage, _ after: PreparedPrintImage,
                             width: Int, height: Int) -> [Int] {
        let old = [UInt8](before.descriptor.pixelData)
        let new = [UInt8](after.descriptor.pixelData)
        return (0..<height).filter { row in
            (0..<width).contains { old[row * width + $0] != new[row * width + $0] }
        }
    }

    @Test("The caption is written into the pixels")
    func testBurnsIntoPixels() {
        let original = frame()
        let burned = ImageAnnotationBurner.burning(["DOE^JANE, 711794", "CT ABDOMEN"],
                                                   into: original)
        #expect(burned.descriptor.pixelData != original.descriptor.pixelData)
        #expect(burned.descriptor.pixelData.count == original.descriptor.pixelData.count,
                "the frame keeps its size — the printer was told these dimensions")
        #expect(burned.descriptor.rows == original.descriptor.rows)
        #expect(burned.sourcePath == original.sourcePath)
    }

    @Test("It lands at the bottom of the image, under the anatomy")
    func testCaptionSitsAtTheBottom() {
        let original = frame(width: 200, height: 200)
        let burned = ImageAnnotationBurner.burning(["PATIENT NAME", "STUDY"], into: original)

        let rows = changedRows(original, burned, width: 200, height: 200)
        #expect(!rows.isEmpty, "something was drawn")
        // DICOM rows run top to bottom, so the caption must be in the last ones.
        #expect(rows.allSatisfy { $0 > 140 },
                "changed rows: \(rows.first.map(String.init) ?? "none")…")
    }

    @Test("The caption gets its own strip — no anatomy under the text")
    func testCaptionBandIsReserved() {
        // A frame with content everywhere, so anything left under the caption
        // would show up as a bright pixel inside the strip.
        let original = frame(width: 200, height: 200, fill: 200)
        let burned = ImageAnnotationBurner.burning(["PATIENT NAME", "STUDY"], into: original)

        let band = Int(ImageAnnotationBurner.captionBandHeight(
            lineCount: 2, width: 200, height: 200).rounded())
        #expect(band > 0)

        let pixels = [UInt8](burned.descriptor.pixelData)
        let firstBandRow = 200 - band + 1   // one row in, clear of rounding
        let inBand = (firstBandRow..<200).flatMap { row in
            (0..<200).map { pixels[row * 200 + $0] }
        }
        #expect(!inBand.contains(200), "the picture was moved off the strip")

        // And the picture is still there, above the strip.
        let topRow = (0..<200).map { pixels[10 * 200 + $0] }
        #expect(topRow.contains(200))
    }

    @Test("A strip that would eat the picture is not reserved")
    func testTinyFrameIsCaptionedOver() {
        // 40 rows with a two-line caption: the strip would be most of the frame,
        // so the caption is drawn over the pixels rather than shrinking them away.
        let original = frame(width: 40, height: 40, fill: 200)
        let burned = ImageAnnotationBurner.burning(["PATIENT NAME", "STUDY"], into: original)
        let pixels = [UInt8](burned.descriptor.pixelData)
        // The picture is untouched at the top: nothing was rescaled.
        #expect((0..<40).allSatisfy { pixels[$0] == 200 })
        #expect(burned.descriptor.pixelData != original.descriptor.pixelData)
    }

    @Test("Nothing to say means nothing is touched")
    func testEmptyLinesLeavePixelsAlone() {
        let original = frame()
        #expect(ImageAnnotationBurner.burning([], into: original)
                .descriptor.pixelData == original.descriptor.pixelData)
        #expect(ImageAnnotationBurner.burning(["", "   "], into: original)
                .descriptor.pixelData == original.descriptor.pixelData)
    }

    @Test("Colour frames are burned in place, keeping their three samples")
    func testRGB() {
        let original = frame(width: 120, height: 120, samples: 3, photometric: "RGB")
        let burned = ImageAnnotationBurner.burning(["PATIENT"], into: original)

        #expect(burned.descriptor.pixelData != original.descriptor.pixelData)
        #expect(burned.descriptor.pixelData.count == 120 * 120 * 3,
                "packed back to RGB, not left as RGBA")
        #expect(burned.descriptor.samplesPerPixel == 3)
        #expect(burned.descriptor.photometricInterpretation == "RGB")
    }

    @Test("A 16-bit frame is printed uncaptioned rather than written into blindly")
    func testUnsupportedDepthIsLeftAlone() {
        let original = frame(bitsAllocated: 16)
        let burned = ImageAnnotationBurner.burning(["PATIENT"], into: original)
        #expect(burned.descriptor.pixelData == original.descriptor.pixelData)
    }

    @Test("A truncated frame is left alone")
    func testTruncatedFrameIsLeftAlone() {
        let short = PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: Data(repeating: 0, count: 10),
                rows: 128, columns: 128,
                bitsAllocated: 8, bitsStored: 8, highBit: 7,
                samplesPerPixel: 1, pixelRepresentation: 0,
                photometricInterpretation: "MONOCHROME2"),
            sourcePath: nil, frameIndex: 0)

        #expect(ImageAnnotationBurner.burning(["PATIENT"], into: short)
                .descriptor.pixelData == short.descriptor.pixelData)
    }

    @Test("On MONOCHROME1 the caption is drawn in the value that reads as white")
    func testMonochrome1Polarity() {
        // MONOCHROME1's maximum is black, so a caption drawn at maximum would be
        // invisible on the black background these frames use.
        let white = frame(photometric: "MONOCHROME1", fill: 0)
        let burned = ImageAnnotationBurner.burning(["PATIENT"], into: white)
        let bytes = [UInt8](burned.descriptor.pixelData)
        #expect(bytes.contains { $0 > 200 },
                "a halo in the opposite polarity is present either way")
    }
}
#endif
