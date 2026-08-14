// PrintCellPlacementTests.swift
// DICOMPrintKitTests
//
// SRS FR-003: scaling modes and 9-way positioning.
//
// The regression that matters most: with the default arguments — centre
// alignment, no stretch — every fit is the fit films printed before FR-003
// existed. The new modes are additions, not a re-interpretation.

import Testing
@testable import DICOMPrintKit
import DICOMCore
import DICOMKit
import DICOMNetwork
import Foundation

@Suite("Print Cell Placement Tests")
struct PrintCellPlacementTests {

    /// A sheet at 25.4 dpi: one pixel is one millimetre, so requested sizes
    /// read straight off the numbers.
    private let sheet = FilmSheet(widthMillimeters: 400, heightMillimeters: 400, dpi: 25.4)

    private func cell(_ width: Double, _ height: Double) -> FilmCell {
        FilmCell(position: 1, x: 40, y: 20, width: width, height: height)
    }

    private func destination(_ result: FilmFitResult) -> FilmCell? {
        guard case .placed(let destination, _, _, _, _) = result else { return nil }
        return destination
    }

    // MARK: Regression

    @Test("Default arguments reproduce the centred fit exactly")
    func testDefaultIsCentredFit() throws {
        let result = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 50,
            in: cell(400, 400),
            requestedSizeMillimeters: nil,
            behavior: .decimate,
            sheet: sheet)
        let placed = try #require(destination(result))
        // Scale 4 → 400×200, centred vertically in a 400-tall cell at y=20.
        #expect(placed.width == 400)
        #expect(placed.height == 200)
        #expect(placed.x == 40)
        #expect(placed.y == 20 + 100)
    }

    // MARK: Alignment

    @Test("Each of the nine alignments places the letterboxed image at its anchor",
          arguments: PrintCellAlignment.allCases)
    func testAlignmentAnchors(alignment: PrintCellAlignment) throws {
        // 100×50 into 400×400: content 400×200, slack is all vertical.
        let result = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 50,
            in: cell(400, 400),
            requestedSizeMillimeters: nil,
            behavior: .decimate,
            sheet: sheet,
            alignment: alignment)
        let placed = try #require(destination(result))
        let expectedY = 20 + (400.0 - 200.0) * alignment.verticalFraction
        #expect(placed.y == expectedY)
        // No horizontal slack, so x never moves.
        #expect(placed.x == 40)
    }

    @Test("Alignment is a no-op when the image fills the cell")
    func testAlignmentNoSlack() throws {
        for alignment in PrintCellAlignment.allCases {
            let result = FilmImageFitter.fit(
                imageWidth: 200, imageHeight: 200,
                in: cell(400, 400),
                requestedSizeMillimeters: nil,
                behavior: .decimate,
                sheet: sheet,
                alignment: alignment)
            let placed = try #require(destination(result))
            #expect(placed.x == 40)
            #expect(placed.y == 20)
            #expect(placed.width == 400)
            #expect(placed.height == 400)
        }
    }

    @Test("Fill alignment moves the crop window, not the destination")
    func testFillAlignmentMovesTheCrop() throws {
        // 100×200 into a square cell: fill crops vertically.
        let top = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 200,
            in: cell(400, 400),
            requestedSizeMillimeters: nil,
            behavior: .crop,
            sheet: sheet,
            alignment: .topCenter)
        guard case .placed(let destination, _, let sourceY, _, let sourceHeight) = top else {
            Issue.record("expected a placement"); return
        }
        #expect(destination.width == 400)
        #expect(destination.height == 400)
        #expect(sourceY == 0, "top alignment keeps the top of the anatomy")
        #expect(sourceHeight == 100)

        let bottom = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 200,
            in: cell(400, 400),
            requestedSizeMillimeters: nil,
            behavior: .crop,
            sheet: sheet,
            alignment: .bottomCenter)
        guard case .placed(_, _, let bottomSourceY, _, _) = bottom else {
            Issue.record("expected a placement"); return
        }
        #expect(bottomSourceY == 100, "bottom alignment keeps the bottom")
    }

    // MARK: Stretch

    @Test("Stretch fills the cell exactly and ignores the aspect ratio")
    func testStretch() throws {
        let result = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 50,
            in: cell(400, 300),
            requestedSizeMillimeters: nil,
            behavior: .decimate,
            sheet: sheet,
            stretch: true)
        guard case .placed(let destination, let sx, let sy, let sw, let sh) = result else {
            Issue.record("expected a placement"); return
        }
        #expect(destination.width == 400)
        #expect(destination.height == 300)
        #expect(destination.x == 40)
        #expect(destination.y == 20)
        // Whole image, non-uniform scale: 4× wide, 6× tall.
        #expect(sx == 0 && sy == 0 && sw == 100 && sh == 50)
    }

    // MARK: Requested size (true size on the wire)

    @Test("CROP with a requested size prints at that size, letterboxed when smaller")
    func testCropHonorsRequestedSize() throws {
        // 100 px at 50 mm on a 1 px/mm sheet: 50×50 in a 100×100 cell.
        let result = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 100,
            in: cell(100, 100),
            requestedSizeMillimeters: 50,
            behavior: .crop,
            sheet: sheet)
        let placed = try #require(destination(result))
        #expect(placed.width == 50)
        #expect(placed.height == 50)
        #expect(placed.x == 40 + 25)
        #expect(placed.y == 20 + 25)
    }

    @Test("CROP with an oversize request crops to the cell instead of shrinking")
    func testCropClipsOversizeRequest() throws {
        // 100 px at 200 mm: scale 2, only half the image fits the 100-wide cell.
        let result = FilmImageFitter.fit(
            imageWidth: 100, imageHeight: 100,
            in: cell(100, 100),
            requestedSizeMillimeters: 200,
            behavior: .crop,
            sheet: sheet)
        guard case .placed(let destination, let sx, _, let sw, _) = result else {
            Issue.record("expected a placement"); return
        }
        #expect(destination.width == 100)
        #expect(sw == 50, "half the columns are visible at scale 2")
        #expect(sx == 25, "centred crop")
    }

    @Test("FAIL still fails when the image cannot fit at the requested size")
    func testFailBehaviorUnchanged() {
        let result = FilmImageFitter.fit(
            imageWidth: 200, imageHeight: 200,
            in: cell(100, 100),
            requestedSizeMillimeters: nil,
            behavior: .failOver,
            sheet: sheet)
        guard case .failed = result else {
            Issue.record("a 200 px image must not fit a 100 px cell at 1:1"); return
        }
    }

    // MARK: Request mapping

    private func prepared(columns: UInt16, spacing: Double?) -> PreparedPrintImage {
        PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: Data(count: Int(columns)),
                rows: 1, columns: columns,
                bitsAllocated: 8, bitsStored: 8, highBit: 7,
                samplesPerPixel: 1, pixelRepresentation: 0,
                photometricInterpretation: "MONOCHROME2"),
            sourcePath: nil, frameIndex: 0,
            rowSpacingMillimeters: spacing,
            columnSpacingMillimeters: spacing)
    }

    @Test("True size sends CROP plus the physical width; missing spacing falls back")
    func testTrueSizeImageBoxOptions() {
        var request = PrintJobRequest()
        request.scalingMode = .trueSize
        let images = [prepared(columns: 512, spacing: 0.5),
                      prepared(columns: 512, spacing: nil)]
        let options = request.imageBoxOptions(for: images)
        #expect(options.count == 2)
        #expect(options[0].requestedImageSize == "256.0000")
        #expect(options[0].requestedDecimateCropBehavior == .crop)
        // No spacing: true size is undefined; the image falls back to fit.
        #expect(options[1].requestedImageSize == nil)
        #expect(options[1].requestedDecimateCropBehavior == .decimate)
        #expect(request.trueSizeFallbackCount(for: images) == 1)
    }

    @Test("Fill sends CROP for every image; fit and stretch send nothing")
    func testModeWireMapping() {
        let images = [prepared(columns: 100, spacing: 1)]
        var request = PrintJobRequest()

        request.scalingMode = .fillToFilm
        let fill = request.imageBoxOptions(for: images)
        #expect(fill.first?.requestedDecimateCropBehavior == .crop)
        #expect(fill.first?.requestedImageSize == nil)

        request.scalingMode = .fitToFilm
        #expect(request.imageBoxOptions(for: images).isEmpty)
        request.scalingMode = .stretch
        #expect(request.imageBoxOptions(for: images).isEmpty)
        #expect(request.trueSizeFallbackCount(for: images) == 0)
    }

    @Test("The DS rendering of a physical width stays within 16 characters")
    func testDecimalString() {
        #expect(PrintJobRequest.decimalString(256.0) == "256.0000")
        #expect(PrintJobRequest.decimalString(431.8) == "431.8000")
        #expect(PrintJobRequest.decimalString(123456789.123456).count <= 16)
    }

    // MARK: Physical size reading

    private func dataSet(_ values: [(UInt16, UInt16, String)]) -> DataSet {
        DataSet(elements: values.map { group, element, value in
            let padded = value.count % 2 == 0 ? value : value + " "
            return DataElement(
                tag: Tag(group: group, element: element),
                vr: .DS,
                length: UInt32(padded.utf8.count),
                valueData: Data(padded.utf8))
        })
    }

    @Test("Pixel Spacing reads row then column, and column drives the width")
    func testPixelSpacingOrder() {
        let spacing = PrintPhysicalSize.pixelSpacing(
            from: dataSet([(0x0028, 0x0030, "0.5\\0.25")]))
        #expect(spacing?.row == 0.5)
        #expect(spacing?.column == 0.25)
        #expect(PrintPhysicalSize.trueWidthMillimeters(
            columns: 400, dataSet: dataSet([(0x0028, 0x0030, "0.5\\0.25")])) == 100)
    }

    @Test("Imager Pixel Spacing is the fallback; zeros and singletons are rejected")
    func testPixelSpacingFallbacks() {
        #expect(PrintPhysicalSize.pixelSpacing(
            from: dataSet([(0x0018, 0x1164, "0.2\\0.2")]))?.column == 0.2)
        #expect(PrintPhysicalSize.pixelSpacing(
            from: dataSet([(0x0028, 0x0030, "0\\0")])) == nil)
        #expect(PrintPhysicalSize.pixelSpacing(
            from: dataSet([(0x0028, 0x0030, "0.5")])) == nil)
        #expect(PrintPhysicalSize.pixelSpacing(from: DataSet()) == nil)
    }

    // MARK: Spacing through the presentation transform

    @Test("A quarter turn swaps row and column spacing; a free angle clears both")
    func testSpacingFollowsRotation() {
        // Asymmetric, so the rotation genuinely changes the descriptor — a
        // no-op transform returns the image (and its spacing) untouched.
        let image = PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: Data([1, 2]),
                rows: 1, columns: 2,
                bitsAllocated: 8, bitsStored: 8, highBit: 7,
                samplesPerPixel: 1, pixelRepresentation: 0,
                photometricInterpretation: "MONOCHROME2"),
            sourcePath: nil, frameIndex: 0,
            rowSpacingMillimeters: 0.5,
            columnSpacingMillimeters: 0.25)

        let turned = image.applying(ViewerPresentation(rotationDegrees: 90))
        #expect(turned.rowSpacingMillimeters == 0.25)
        #expect(turned.columnSpacingMillimeters == 0.5)

        let resampled = image.applying(ViewerPresentation(rotationDegrees: 30))
        #expect(resampled.rowSpacingMillimeters == nil)
        #expect(resampled.columnSpacingMillimeters == nil)
    }
}
