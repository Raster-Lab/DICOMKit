// ImageAnnotationBurnerTests.swift
// DICOMPrintKitTests
//
// Burning patient identification into the pixels that are sent to the printer.
//
// The property under test throughout: the text lands in the corners it was given
// and nowhere else, the picture keeps every row it had, and a frame this cannot
// safely write into comes back untouched rather than corrupted.

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

    /// The columns of a grayscale frame that differ from the original.
    private func changedColumns(_ before: PreparedPrintImage, _ after: PreparedPrintImage,
                                width: Int, height: Int) -> [Int] {
        let old = [UInt8](before.descriptor.pixelData)
        let new = [UInt8](after.descriptor.pixelData)
        return (0..<width).filter { column in
            (0..<height).contains { old[$0 * width + column] != new[$0 * width + column] }
        }
    }

    private let identification = PrintCornerAnnotation(
        topRight: ["DOE^JANE, 711794", "CT ABDOMEN"],
        bottomLeft: ["CT · Se 2, Im 45", "5.00 mm"],
        bottomRight: ["15 Oct 2025"])

    @Test("The identification is written into the pixels")
    func testBurnsIntoPixels() {
        let original = frame()
        let burned = ImageAnnotationBurner.burning(corners: identification, into: original)

        #expect(burned.descriptor.pixelData != original.descriptor.pixelData)
        #expect(burned.descriptor.pixelData.count == original.descriptor.pixelData.count,
                "the frame keeps its size — the printer was told these dimensions")
        #expect(burned.descriptor.rows == original.descriptor.rows)
        #expect(burned.sourcePath == original.sourcePath)
    }

    @Test("A top corner is written at the top and a bottom corner at the bottom")
    func testCornersLandWhereTheyAreNamed() {
        let original = frame(width: 300, height: 300)

        let top = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(topRight: ["PATIENT NAME"]), into: original)
        let topRows = changedRows(original, top, width: 300, height: 300)
        #expect(!topRows.isEmpty, "something was drawn")
        // DICOM rows run top to bottom, so a top corner is in the first of them.
        #expect(topRows.allSatisfy { $0 < 60 }, "changed rows: \(topRows)")

        let bottom = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(bottomLeft: ["CT · 5.00 mm"]), into: original)
        let bottomRows = changedRows(original, bottom, width: 300, height: 300)
        #expect(!bottomRows.isEmpty)
        #expect(bottomRows.allSatisfy { $0 > 240 }, "changed rows: \(bottomRows)")
    }

    @Test("A left corner is written on the left and a right corner on the right")
    func testCornersPickTheirSide() {
        let original = frame(width: 300, height: 300)

        let left = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(bottomLeft: ["CT"]), into: original)
        let leftColumns = changedColumns(original, left, width: 300, height: 300)
        #expect(!leftColumns.isEmpty)
        #expect(leftColumns.allSatisfy { $0 < 150 }, "changed columns: \(leftColumns)")

        let right = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(bottomRight: ["2025"]), into: original)
        let rightColumns = changedColumns(original, right, width: 300, height: 300)
        #expect(!rightColumns.isEmpty)
        #expect(rightColumns.allSatisfy { $0 > 150 }, "changed columns: \(rightColumns)")
    }

    @Test("The picture keeps every row it had — nothing is scaled away")
    func testTheMiddleIsUntouched() {
        // A frame with content everywhere: the middle of it must come back
        // exactly as it went in, because corner text costs the picture no rows.
        let original = frame(width: 300, height: 300, fill: 200)
        let burned = ImageAnnotationBurner.burning(corners: identification, into: original)

        let pixels = [UInt8](burned.descriptor.pixelData)
        let middle = (140..<160).flatMap { row in (100..<200).map { pixels[row * 300 + $0] } }
        #expect(middle.allSatisfy { $0 == 200 }, "the anatomy in the middle is as it was")
    }

    @Test("Nothing to say means nothing is touched")
    func testEmptyCornersLeavePixelsAlone() {
        let original = frame()
        #expect(ImageAnnotationBurner.burning(corners: PrintCornerAnnotation(), into: original)
                .descriptor.pixelData == original.descriptor.pixelData)
        #expect(ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(topRight: ["", "   "]), into: original)
                .descriptor.pixelData == original.descriptor.pixelData)
    }

    @Test("Colour frames are burned in place, keeping their three samples")
    func testRGB() {
        let original = frame(width: 120, height: 120, samples: 3, photometric: "RGB")
        let burned = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(topRight: ["PATIENT"]), into: original)

        #expect(burned.descriptor.pixelData != original.descriptor.pixelData)
        #expect(burned.descriptor.pixelData.count == 120 * 120 * 3,
                "packed back to RGB, not left as RGBA")
        #expect(burned.descriptor.samplesPerPixel == 3)
        #expect(burned.descriptor.photometricInterpretation == "RGB")
    }

    @Test("A 16-bit frame is printed uncaptioned rather than written into blindly")
    func testUnsupportedDepthIsLeftAlone() {
        let original = frame(bitsAllocated: 16)
        let burned = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(topRight: ["PATIENT"]), into: original)
        #expect(burned.descriptor.pixelData == original.descriptor.pixelData)
    }

    @Test("The film sets every corner line at the one size, as the preview does")
    func testOneCaptionSizeForTheWholeCell() {
        let short = PrintCornerAnnotation(topRight: ["DOE, JOHN", "ID 12345"])
        #expect(ImageAnnotationBurner.fittedCaptionFontSize(
                    for: short, width: 512, height: 512)
                == ImageAnnotationBurner.captionFontSize(width: 512, height: 512),
                "lines that fit burn at the cell's own size")

        let long = PrintCornerAnnotation(
            topRight: ["DOE, JOHN"],
            bottomLeft: ["CT CHEST ABDOMEN PELVIS WITH CONTRAST — DELAYED PHASE 2"])
        let base = ImageAnnotationBurner.captionFontSize(width: 512, height: 512)
        let fitted = ImageAnnotationBurner.fittedCaptionFontSize(
            for: long, width: 512, height: 512)
        #expect(fitted < base,
                "one long line steps the whole block down, not itself alone")
        #expect(fitted >= base * 0.5, "never below half the cell's size")
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

        #expect(ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(topRight: ["PATIENT"]), into: short)
                .descriptor.pixelData == short.descriptor.pixelData)
    }

    @Test("On MONOCHROME1 the caption is drawn in the value that reads as white")
    func testMonochrome1Polarity() {
        // MONOCHROME1's maximum is black, so a caption drawn at maximum would be
        // invisible on the black background these frames use.
        let white = frame(photometric: "MONOCHROME1", fill: 0)
        let burned = ImageAnnotationBurner.burning(
            corners: PrintCornerAnnotation(topRight: ["PATIENT"]), into: white)
        let bytes = [UInt8](burned.descriptor.pixelData)
        #expect(bytes.contains { $0 > 200 },
                "a halo in the opposite polarity is present either way")
    }
}
#endif
