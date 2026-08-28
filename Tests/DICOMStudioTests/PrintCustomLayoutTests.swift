// PrintCustomLayoutTests.swift
// DICOMStudioTests
//
// The print sheet's custom layout: an Image Display Format (2010,0010) typed by
// hand, for the films PS3.3 C.13.3 can describe and a rows × columns grid
// cannot — `ROW\1,3` is a scout over three slices.
//
// What is under test is that the typed string reaches the job unchanged and
// that the plan the preview draws from counts the film's own cells. Half-typed
// text is not a layout, and must not be silently turned into a 1×1 film.

import Testing
@testable import DICOMStudio
import DICOMNetwork
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Custom Layout Tests")
struct PrintCustomLayoutTests {

    private func makeViewModel(imageCount: Int = 4) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (0..<imageCount).map {
            PrintSelectionItem(filePath: "/f\($0).dcm", frameIndex: 0)
        })
        return PrintViewModel(selection: selection)
    }

    @Test("A typed format travels to the job verbatim")
    func testCustomFormatReachesTheRequest() {
        let viewModel = makeViewModel()
        viewModel.layoutMode = .custom
        viewModel.customLayoutText = "ROW\\1,3"

        #expect(viewModel.request.resolvedDisplayFormat?.raw == "ROW\\1,3")
        #expect(viewModel.request.layoutSelection == .displayFormat(
            PrintImageDisplayFormat.parse("ROW\\1,3")))
    }

    @Test("The plan counts the band layout's own cells")
    func testPlanCountsBandCells() {
        let viewModel = makeViewModel(imageCount: 6)
        viewModel.layoutMode = .custom
        viewModel.customLayoutText = "ROW\\1,1"

        let plan = viewModel.plan
        #expect(plan.cellsPerFilm == 2)
        #expect(plan.filmCount == 3)
        #expect(plan.displayFormat.raw == "ROW\\1,1")
    }

    @Test("Text that is not a format leaves the film on the automatic grid")
    func testHalfTypedFormatDoesNotBecomeASingleCellFilm() {
        let viewModel = makeViewModel()
        viewModel.layoutMode = .custom
        viewModel.customLayoutText = "ROW\\"

        #expect(viewModel.customLayoutFormat == nil)
        #expect(viewModel.request.layoutSelection == .automatic)
        // Four images on an automatic grid is one film of four cells — not the
        // four one-cell films a lenient parse would have produced.
        #expect(viewModel.plan.filmCount == 1)
        #expect(viewModel.plan.cellsPerFilm == 4)
    }

    @Test("Every named band reaches the job as its own format")
    func testNamedBandsGoThroughTheSameField() {
        let viewModel = makeViewModel()
        for band in PrintBandLayout.allCases {
            // What the gallery's band tile does: fill the field, adopt the mode.
            viewModel.customLayoutText = band.imageDisplayFormat
            viewModel.layoutMode = .custom

            #expect(viewModel.customLayoutFormat != nil)
            #expect(viewModel.request.resolvedDisplayFormat?.raw == band.imageDisplayFormat)
            #expect(viewModel.plan.cellsPerFilm == band.cellCount)
        }
    }

    @Test("The grid modes are unchanged by the custom field")
    func testGridModesAreUnaffected() {
        let viewModel = makeViewModel()
        viewModel.customLayoutText = "ROW\\1,3"
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2

        #expect(viewModel.request.resolvedDisplayFormat?.raw == "STANDARD\\2,2")
        #expect(viewModel.plan.cellsPerFilm == 4)
    }

    @Test("The film's cells are the bands, not the bounding grid")
    func testPreviewCellsFollowTheBands() {
        let viewModel = makeViewModel()
        viewModel.layoutMode = .custom
        viewModel.customLayoutText = "ROW\\1,3"

        let cells = viewModel.plan.cells(
            onSheetOfWidth: 300, height: 400, margin: 0, spacing: 0)
        #expect(cells.count == 4)
        #expect(cells[0].width == 300)          // the scout, full width
        #expect(cells[1].width == 100)          // three slices beneath it
        #expect(cells[1].y == 200)
    }
}
