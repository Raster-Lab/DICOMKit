// PrintCellPaddingTests.swift
// DICOMPrintKitTests
//
// Letterboxing a prepared frame to its film cell's shape, so burned corner
// text lands at the cell's corners the way the preview draws it.
//
// The properties under test: exactly one axis grows and only ever grows, the
// picture is centred and byte-identical inside the padding, the padding is
// film background for every photometric, and a frame this cannot safely
// rebuild comes back untouched rather than corrupted.

import Testing
@testable import DICOMPrintKit
import DICOMNetwork
import Foundation

@Suite("Print Cell Padding Tests")
struct PrintCellPaddingTests {

    private func frame(
        width: Int = 100,
        height: Int = 80,
        samples: Int = 1,
        bitsAllocated: Int = 8,
        photometric: String = "MONOCHROME2",
        fill: UInt8 = 200,
        rowSpacing: Double? = nil,
        columnSpacing: Double? = nil
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
            frameIndex: 0,
            rowSpacingMillimeters: rowSpacing,
            columnSpacingMillimeters: columnSpacing)
    }

    // MARK: - Geometry

    @Test("A wide frame in a tall cell grows rows, and only rows")
    func testWideFrameGainsRows() {
        // 100×80 into a cell of aspect 0.8 (portrait): height must become 125.
        let padded = frame().padded(toCellAspectRatio: 0.8)

        #expect(padded.descriptor.columns == 100)
        #expect(padded.descriptor.rows == 125)
        #expect(padded.descriptor.pixelData.count == 100 * 125)
    }

    @Test("A tall frame in a wide cell grows columns, and only columns")
    func testTallFrameGainsColumns() {
        let padded = frame(width: 80, height: 100).padded(toCellAspectRatio: 1.25)

        #expect(padded.descriptor.columns == 125)
        #expect(padded.descriptor.rows == 100)
    }

    @Test("The picture is centred in the padding, byte for byte")
    func testPictureIsCentred() {
        let padded = frame(width: 100, height: 80, fill: 200)
            .padded(toCellAspectRatio: 0.8)
        let bytes = [UInt8](padded.descriptor.pixelData)

        // 125 rows for 80 of picture: 22 rows of background above, 23 below.
        let offsetY = (125 - 80) / 2
        for row in 0..<125 {
            let isPicture = row >= offsetY && row < offsetY + 80
            let value = bytes[row * 100 + 50]
            #expect(value == (isPicture ? 200 : 0),
                    "row \(row) should be \(isPicture ? "picture" : "background")")
        }
    }

    @Test("A frame already the cell's shape is returned untouched")
    func testMatchingAspectIsUntouched() {
        let original = frame(width: 100, height: 80)
        let padded = original.padded(toCellAspectRatio: 1.25)

        #expect(padded.descriptor.pixelData == original.descriptor.pixelData)
        #expect(padded.descriptor.rows == original.descriptor.rows)
        #expect(padded.descriptor.columns == original.descriptor.columns)
    }

    // MARK: - Background

    @Test("MONOCHROME2 pads with the minimum stored value — black on film")
    func testMonochrome2Background() {
        let padded = frame().padded(toCellAspectRatio: 0.5)
        let bytes = [UInt8](padded.descriptor.pixelData)
        #expect(bytes.first == 0)
        #expect(bytes.last == 0)
    }

    @Test("MONOCHROME1 pads with the maximum stored value — black on film")
    func testMonochrome1Background() {
        let padded = frame(photometric: "MONOCHROME1", fill: 30)
            .padded(toCellAspectRatio: 0.5)
        let bytes = [UInt8](padded.descriptor.pixelData)
        #expect(bytes.first == 255)
        #expect(bytes.last == 255)
    }

    @Test("RGB pads with black and keeps the picture's samples interleaved")
    func testRGBBackground() {
        let padded = frame(width: 10, height: 10, samples: 3, fill: 90)
            .padded(toCellAspectRatio: 2.0)
        let bytes = [UInt8](padded.descriptor.pixelData)

        #expect(padded.descriptor.columns == 20)
        #expect(padded.descriptor.rows == 10)
        // First pixel of a row is padding; the centre of the row is picture.
        #expect(Array(bytes[0..<3]) == [0, 0, 0])
        let centre = (0 * 20 + 10) * 3
        #expect(Array(bytes[centre..<(centre + 3)]) == [90, 90, 90])
    }

    // MARK: - Refusals

    @Test("A 16-bit frame is refused untouched — the burner cannot caption it")
    func test16BitIsRefused() {
        let original = frame(bitsAllocated: 16)
        let padded = original.padded(toCellAspectRatio: 0.5)
        #expect(padded.descriptor.pixelData == original.descriptor.pixelData)
        #expect(padded.descriptor.rows == original.descriptor.rows)
    }

    @Test("A senseless aspect ratio is refused untouched")
    func testBadAspectIsRefused() {
        let original = frame()
        #expect(original.padded(toCellAspectRatio: 0).descriptor.rows == 80)
        #expect(original.padded(toCellAspectRatio: -1).descriptor.rows == 80)
        #expect(original.padded(toCellAspectRatio: .nan).descriptor.rows == 80)
        #expect(original.padded(toCellAspectRatio: .infinity).descriptor.rows == 80)
    }

    // MARK: - Metadata

    @Test("Pixel spacing rides along — padded pixels are the same physical size")
    func testSpacingIsKept() {
        let padded = frame(rowSpacing: 0.5, columnSpacing: 0.5)
            .padded(toCellAspectRatio: 0.8)
        #expect(padded.rowSpacingMillimeters == 0.5)
        #expect(padded.columnSpacingMillimeters == 0.5)
        #expect(padded.sourcePath == "/a.dcm")
        #expect(padded.frameIndex == 0)
    }

    // MARK: - With the burner

    #if canImport(CoreGraphics)
    @Test("Corner text burned after padding lands in the letterbox — the cell's corners")
    func testCaptionLandsInThePadding() {
        // A landscape frame in a portrait cell: the letterbox is above and
        // below. Burn a caption into the padded frame and it must touch rows
        // the picture does not reach — the proof that the text sits at the
        // cell's corner rather than the picture's.
        let padded = frame(width: 200, height: 100, fill: 128)
            .padded(toCellAspectRatio: 0.8)
        let corners = PrintCornerAnnotation(
            topRight: ["DOE^JANE, 711794"], bottomRight: ["15 Oct 2025"])
        let burned = ImageAnnotationBurner.burning(corners: corners, into: padded)

        let width = Int(padded.descriptor.columns)
        let height = Int(padded.descriptor.rows)
        let before = [UInt8](padded.descriptor.pixelData)
        let after = [UInt8](burned.descriptor.pixelData)
        let changedRows = (0..<height).filter { row in
            (0..<width).contains { before[row * width + $0] != after[row * width + $0] }
        }

        let pictureTop = (height - 100) / 2
        let pictureBottom = pictureTop + 100
        #expect(!changedRows.isEmpty)
        #expect(changedRows.contains { $0 < pictureTop },
                "the top caption belongs in the letterbox above the picture")
        #expect(changedRows.contains { $0 >= pictureBottom },
                "the bottom caption belongs in the letterbox below the picture")
    }
    #endif
}
