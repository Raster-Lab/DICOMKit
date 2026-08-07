//
// PrintPlanLayoutTests.swift
// DICOMPrintKitTests
//
// The film plan under every layout selection, and in particular under the
// PS3.3 C.13.3 band forms: a `ROW\` or `COL\` film holds a number of images no
// rows × columns product predicts, so the count of cells, the count of films,
// and the rectangles the cells occupy all have to come from the format itself.
//

import XCTest
import DICOMNetwork
@testable import DICOMPrintKit

final class PrintPlanLayoutTests: XCTestCase {

    private func request(_ selection: PrintLayoutSelection) -> PrintJobRequest {
        PrintJobRequest(layoutSelection: selection)
    }

    private func format(_ raw: String) -> PrintImageDisplayFormat {
        guard let format = PrintImageDisplayFormat.validated(raw) else {
            XCTFail("\(raw) should be an Image Display Format")
            return PrintImageDisplayFormat(layout: PrintLayout(rows: 1, columns: 1))
        }
        return format
    }

    // MARK: - Cell and film counts

    func testBandLayoutCountsItsOwnCellsRatherThanTheBoundingGrid() {
        // ROW\1,3 is one image over three: 4 cells, not the 2 × 3 = 6 its
        // bounding grid would suggest.
        let plan = request(.displayFormat(format("ROW\\1,3"))).plan(forImageCount: 4)
        XCTAssertEqual(plan.cellsPerFilm, 4)
        XCTAssertEqual(plan.filmCount, 1)
        XCTAssertEqual(plan.layout.rows, 2)
        XCTAssertEqual(plan.layout.columns, 3)
    }

    func testBandLayoutChunksFilmsByImageBoxCount() {
        let request = request(.displayFormat(format("ROW\\1,1")))
        XCTAssertEqual(request.filmCount(forImageCount: 4), 2)

        let plan = request.plan(forImageCount: 5)
        XCTAssertEqual(plan.cellsPerFilm, 2)
        XCTAssertEqual(plan.filmCount, 3)
        XCTAssertEqual(plan.imageIndices(onFilm: 0), 0..<2)
        XCTAssertEqual(plan.imageIndices(onFilm: 2), 4..<5)
    }

    func testColumnLayoutCountsItsCells() {
        let plan = request(.displayFormat(format("COL\\1,2,3"))).plan(forImageCount: 6)
        XCTAssertEqual(plan.cellsPerFilm, 6)
        XCTAssertEqual(plan.filmCount, 1)
    }

    func testGridSelectionsStillReportTheirGrid() {
        let explicit = request(.explicit(.layout2x3)).plan(forImageCount: 6)
        XCTAssertEqual(explicit.cellsPerFilm, 6)
        XCTAssertEqual(explicit.displayFormat.raw, "STANDARD\\3,2")
        XCTAssertTrue(explicit.displayFormat.isUniformGrid)

        let automatic = request(.automatic).plan(forImageCount: 4)
        XCTAssertEqual(automatic.layout.rows, 2)
        XCTAssertEqual(automatic.layout.columns, 2)
        XCTAssertEqual(automatic.cellsPerFilm, 4)
    }

    func testTemplateSelectionCarriesTheTemplatesOwnFormat() {
        let plan = request(.template(.comparison)).plan(forImageCount: 2)
        XCTAssertEqual(plan.displayFormat.raw, PrintTemplatePreset.comparison.template.imageDisplayFormat)
        XCTAssertEqual(plan.cellsPerFilm, 2)
    }

    // MARK: - What goes on the wire

    func testTheSelectionResolvesToTheFormatItSends() {
        XCTAssertNil(request(.automatic).resolvedDisplayFormat)
        XCTAssertEqual(request(.explicit(.layout1x2)).resolvedDisplayFormat?.raw, "STANDARD\\2,1")
        XCTAssertEqual(request(.custom(PrintLayout(rows: 3, columns: 1))).resolvedDisplayFormat?.raw,
                       "STANDARD\\1,3")
        // A hand-written format travels verbatim — a printer matches the string.
        XCTAssertEqual(request(.displayFormat(format("ROW\\2,1,2"))).resolvedDisplayFormat?.raw,
                       "ROW\\2,1,2")
    }

    // MARK: - Cell rectangles

    func testBandCellsAreTheBandsAndNotAGrid() {
        let plan = request(.displayFormat(format("ROW\\1,3"))).plan(forImageCount: 4)
        let cells = plan.cells(onSheetOfWidth: 300, height: 400, margin: 0, spacing: 0)
        XCTAssertEqual(cells.count, 4)
        XCTAssertEqual(cells.map(\.position), [1, 2, 3, 4])

        // The single image in the first row takes the full width; the three
        // below it take a third each, on the second band.
        XCTAssertEqual(cells[0].width, 300, accuracy: 0.001)
        XCTAssertEqual(cells[0].height, 200, accuracy: 0.001)
        XCTAssertEqual(cells[1].width, 100, accuracy: 0.001)
        XCTAssertEqual(cells[1].y, 200, accuracy: 0.001)
        XCTAssertEqual(cells[3].x, 200, accuracy: 0.001)
    }

    func testGridCellsAreUniformAndRowMajor() {
        let plan = request(.explicit(.layout2x2)).plan(forImageCount: 4)
        let cells = plan.cells(onSheetOfWidth: 200, height: 100, margin: 0, spacing: 0)
        XCTAssertEqual(cells.count, 4)
        for cell in cells {
            XCTAssertEqual(cell.width, 100, accuracy: 0.001)
            XCTAssertEqual(cell.height, 50, accuracy: 0.001)
        }
        XCTAssertEqual(cells[1].x, 100, accuracy: 0.001)
        XCTAssertEqual(cells[2].y, 50, accuracy: 0.001)
    }

    func testMarginAndSpacingInsetTheCells() {
        let plan = request(.explicit(.layout1x2)).plan(forImageCount: 2)
        let cells = plan.cells(onSheetOfWidth: 100, height: 100, margin: 10, spacing: 10)
        XCTAssertEqual(cells[0].x, 10, accuracy: 0.001)
        XCTAssertEqual(cells[0].width, 35, accuracy: 0.001)   // (80 − 10) / 2
        XCTAssertEqual(cells[1].x, 55, accuracy: 0.001)
        XCTAssertEqual(cells[0].height, 80, accuracy: 0.001)
    }

    // MARK: - The named bands

    func testEveryCataloguedBandIsAFormatAndNotAGrid() {
        for band in PrintBandLayout.allCases {
            let format = PrintImageDisplayFormat.validated(band.imageDisplayFormat)
            XCTAssertNotNil(format, "\(band.rawValue) must be an Image Display Format")
            XCTAssertFalse(format?.isUniformGrid ?? true,
                           "\(band.rawValue) is a band layout, not a grid")
            XCTAssertEqual(format?.imageBoxCount, band.cellCount)
            XCTAssertGreaterThan(band.cellCount, 1)
            XCTAssertFalse(band.displayName.isEmpty)
        }
        XCTAssertEqual(Set(PrintBandLayout.allCases.map(\.rawValue)).count,
                       PrintBandLayout.allCases.count, "no format is listed twice")
    }

    func testTheNamedBandsHoldTheImagesTheirNamesSay() {
        XCTAssertEqual(PrintBandLayout.rowOneOverTwo.cellCount, 3)
        XCTAssertEqual(PrintBandLayout.rowTwoOverThree.cellCount, 5)
        XCTAssertEqual(PrintBandLayout.columnOneAndTwo.cellCount, 3)
        XCTAssertEqual(PrintBandLayout.columnOneAndThree.cellCount, 4)
        XCTAssertEqual(PrintBandLayout.columnOneAndFour.cellCount, 5)
        XCTAssertEqual(PrintBandLayout.columnOneAndTwoFours.cellCount, 9)
        XCTAssertEqual(PrintBandLayout.columnTwoAndTwoFours.cellCount, 10)
    }

    func testANamedBandPlansTheFilmItDraws() {
        // COL\1,4,4 is one image beside two columns of four: three columns, the
        // first holding a single full-height cell.
        let band = PrintBandLayout.columnOneAndTwoFours
        let plan = request(.displayFormat(band.displayFormat)).plan(forImageCount: 9)
        XCTAssertEqual(plan.cellsPerFilm, 9)
        XCTAssertEqual(plan.filmCount, 1)

        let cells = plan.cells(onSheetOfWidth: 300, height: 400, margin: 0, spacing: 0)
        XCTAssertEqual(cells.count, 9)
        XCTAssertEqual(cells[0].width, 100, accuracy: 0.001)
        XCTAssertEqual(cells[0].height, 400, accuracy: 0.001)   // full height
        XCTAssertEqual(cells[1].x, 100, accuracy: 0.001)
        XCTAssertEqual(cells[1].height, 100, accuracy: 0.001)   // four to a column
        XCTAssertEqual(cells[5].x, 200, accuracy: 0.001)
    }

    // MARK: - Console

    func testPlanSummaryNamesABandLayoutByItsFormat() {
        let banded = request(.displayFormat(format("ROW\\1,1"))).plan(forImageCount: 4)
        XCTAssertTrue(PrintConsoleFormatter.planSummary(banded).contains("ROW\\1,1"),
                      PrintConsoleFormatter.planSummary(banded))

        let grid = request(.explicit(.layout2x2)).plan(forImageCount: 4)
        XCTAssertTrue(PrintConsoleFormatter.planSummary(grid).contains("2×2"),
                      PrintConsoleFormatter.planSummary(grid))
    }
}
