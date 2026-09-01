// PrintImageRangeTests.swift
// DICOMStudioTests
//
// Printing a run of a series, and taking cells off the film.
//
// The property under test for the range: it is a *filter*. Narrowing it never
// destroys a mark, widening it brings the images back exactly as they were, and
// what the preview lays out is what the printer receives — one filtered list,
// read by the plan, the preview and the print run alike.
//
// For deletion: the marks are an ordered list and the cells are filled from it
// in order, so removing one closes the gap rather than leaving a hole in the
// middle of a sheet.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Image Range Tests")
struct PrintImageRangeTests {

    /// `count` frames of one series, numbered 1…count as a scanner would.
    private func makeViewModel(count: Int = 20, series: String = "1.2.3") -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (1...count).map {
            PrintSelectionItem(filePath: "/\($0).dcm", frameIndex: 0,
                               seriesInstanceUID: series, instanceNumber: $0)
        })
        let viewModel = PrintViewModel(selection: selection)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        return viewModel
    }

    private func id(_ number: Int) -> String { "/\(number).dcm#0" }

    // MARK: - The range as a filter

    @Test("A range lays out only the images inside it")
    func testRangeNarrowsTheFilm() {
        let viewModel = makeViewModel()
        viewModel.setImageRange(from: 5, to: 8)

        #expect(viewModel.printedItems.map(\.instanceNumber) == [5, 6, 7, 8])
        #expect(viewModel.plan.filmCount == 1, "four images, four cells, one sheet")
        #expect(viewModel.selection.count == 20, "nothing was un-marked")
        #expect(viewModel.imagesHeldBackByRange == 16)
    }

    @Test("Widening the range brings the images straight back")
    func testWideningRestores() {
        let viewModel = makeViewModel()
        viewModel.setImageRange(from: 5, to: 8)
        viewModel.setImageRange(from: 1, to: 20)

        #expect(viewModel.printedItems.count == 20)
        #expect(!viewModel.isImageRangeActive, "a range covering everything is not a filter")
    }

    @Test("Load All puts every marked image back")
    func testLoadAll() {
        let viewModel = makeViewModel()
        viewModel.setImageRange(from: 5, to: 8)
        viewModel.loadAllImages()

        #expect(viewModel.printedItems.count == 20)
        #expect(!viewModel.isImageRangeActive)
        #expect(viewModel.imageRanges.isEmpty, "no series keeps a range")
    }

    @Test("An image's own windowing survives being filtered out and back")
    func testWindowingSurvivesTheRange() {
        let viewModel = makeViewModel()
        viewModel.selection.adjust(
            viewModel.selection.items[14].with(windowCenter: .some(60), windowWidth: .some(360)))

        viewModel.setImageRange(from: 1, to: 4)
        viewModel.loadAllImages()

        let restored = viewModel.selection.items.first { $0.id == id(15) }
        #expect(restored?.windowCenter == 60)
        #expect(restored?.windowWidth == 360)
    }

    @Test("Reversed bounds are read the way they were obviously meant")
    func testReversedBounds() {
        let viewModel = makeViewModel()
        viewModel.setImageRange(from: 8, to: 5)

        #expect(viewModel.printedItems.map(\.instanceNumber) == [5, 6, 7, 8])
    }

    @Test("A range past the end of the series is pulled back inside it")
    func testClamping() {
        let viewModel = makeViewModel()
        viewModel.setImageRange(from: 15, to: 900)

        #expect(viewModel.imageRanges.values.first?.upperBound == 20)
        #expect(viewModel.printedItems.count == 6)
    }

    @Test("The film that is drawn is the film that is printed")
    func testPlanAndPreviewAgree() {
        let viewModel = makeViewModel()
        viewModel.setImageRange(from: 1, to: 9)

        #expect(viewModel.previewItems.count == 9)
        #expect(viewModel.plan.filmCount == 3, "nine images, four to a sheet")
        #expect(viewModel.previewItems.map(\.id) == viewModel.printedItems.map(\.id))
    }

    // MARK: - When it is offered

    @Test("A range is offered for one series and for several alike")
    func testOfferedForAnyFilterableSelection() {
        #expect(makeViewModel().canRangeImages)

        let mixed = PrintSelectionModel()
        mixed.add(contentsOf: [
            PrintSelectionItem(filePath: "/a.dcm", seriesInstanceUID: "1.1", instanceNumber: 1),
            PrintSelectionItem(filePath: "/b.dcm", seriesInstanceUID: "2.2", instanceNumber: 1)
        ])
        #expect(PrintViewModel(selection: mixed).canRangeImages,
                "each series carries its own range, so mixing them is fine")

        let single = PrintSelectionModel()
        single.add(PrintSelectionItem(filePath: "/a.dcm", seriesInstanceUID: "1.1", instanceNumber: 1))
        #expect(!PrintViewModel(selection: single).canRangeImages,
                "one image has nothing to filter")
    }

    // MARK: - Several series, each with its own numbers

    /// Two series on one film: axials numbered 1…12 and a scout numbered 1…5.
    private func makeMixedViewModel() -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (1...12).map {
            PrintSelectionItem(filePath: "/ax/\($0).dcm", frameIndex: 0,
                               seriesDescription: "AXIAL",
                               seriesInstanceUID: "1.1", instanceNumber: $0)
        })
        selection.add(contentsOf: (1...5).map {
            PrintSelectionItem(filePath: "/sc/\($0).dcm", frameIndex: 0,
                               seriesDescription: "SCOUT",
                               seriesInstanceUID: "2.2", instanceNumber: $0)
        })
        return PrintViewModel(selection: selection)
    }

    @Test("A range on one series leaves the other series whole")
    func testRangeTouchesOnlyItsSeries() {
        let viewModel = makeMixedViewModel()
        viewModel.setImageRange(from: 3, to: 5, forSeries: "1.1")

        let printed = viewModel.printedItems
        #expect(printed.filter { $0.seriesInstanceUID == "1.1" }.map(\.instanceNumber) == [3, 4, 5])
        #expect(printed.filter { $0.seriesInstanceUID == "2.2" }.count == 5,
                "the scout was never narrowed")
        #expect(viewModel.imagesHeldBackByRange == 9)
    }

    @Test("Each series filters by its own numbers, side by side")
    func testIndependentRangesPerSeries() {
        let viewModel = makeMixedViewModel()
        viewModel.setImageRange(from: 3, to: 5, forSeries: "1.1")
        viewModel.setImageRange(from: 2, to: 2, forSeries: "2.2")

        let printed = viewModel.printedItems
        #expect(printed.filter { $0.seriesInstanceUID == "1.1" }.map(\.instanceNumber) == [3, 4, 5])
        #expect(printed.filter { $0.seriesInstanceUID == "2.2" }.map(\.instanceNumber) == [2])
        #expect(viewModel.isImageRangeActive(forSeries: "1.1"))
        #expect(viewModel.isImageRangeActive(forSeries: "2.2"))
    }

    @Test("The control offers one row per series, in film order")
    func testSeriesRowsInFilmOrder() {
        let viewModel = makeMixedViewModel()
        let rows = viewModel.markedSeriesRanges

        #expect(rows.map(\.key) == ["1.1", "2.2"])
        #expect(rows.map(\.label) == ["AXIAL", "SCOUT"])
        #expect(rows.map(\.bounds) == [1...12, 1...5])
        #expect(rows.map(\.imageCount) == [12, 5])
    }

    @Test("A range clamps to its own series' bounds, not the film's")
    func testClampIsPerSeries() {
        let viewModel = makeMixedViewModel()
        viewModel.setImageRange(from: 3, to: 900, forSeries: "2.2")

        #expect(viewModel.imageRange(forSeries: "2.2") == 3...5,
                "the scout ends at 5 even though the axials run to 12")
    }

    @Test("Unnumbered marks fall back to their place in their own series")
    func testOrdinalFallbackIsPerSeries() {
        // Marked whole-series style, no numbers anywhere: positions restart
        // with each series, exactly as instance numbers would.
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (0..<6).map {
            PrintSelectionItem(filePath: "/a/\($0).dcm", seriesInstanceUID: "1.1")
        })
        selection.add(contentsOf: (0..<4).map {
            PrintSelectionItem(filePath: "/b/\($0).dcm", seriesInstanceUID: "2.2")
        })
        let viewModel = PrintViewModel(selection: selection)
        viewModel.setImageRange(from: 2, to: 3, forSeries: "2.2")

        let printed = viewModel.printedItems
        #expect(printed.filter { $0.seriesInstanceUID == "1.1" }.count == 6)
        #expect(printed.filter { $0.seriesInstanceUID == "2.2" }.map(\.filePath)
                == ["/b/1.dcm", "/b/2.dcm"],
                "the second and third marks of that series, not of the film")
    }

    @Test("A range whose series left the film is dropped by the clamp")
    func testClampDropsRangesForUnmarkedSeries() {
        let viewModel = makeMixedViewModel()
        viewModel.setImageRange(from: 3, to: 5, forSeries: "1.1")
        viewModel.selection.replace(with: viewModel.selection.items.filter {
            $0.seriesInstanceUID == "2.2"
        })
        viewModel.clampImageRange()

        #expect(viewModel.imageRanges.isEmpty)
        #expect(viewModel.printedItems.count == 5)
    }

    // MARK: - Matching the series' own numbers

    @Test("The range matches image numbers, not positions in the tray")
    func testRangeMatchesInstanceNumbersNotPositions() {
        // A series marked from image 100 — which is what a reader gets after
        // scrolling into the middle of a study and marking from there. Filtering
        // by tray position would print the first seven marks; the reader asked
        // for images 103 to 109.
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (100...120).map { number in
            PrintSelectionItem(filePath: "/\(number).dcm", frameIndex: 0,
                               seriesInstanceUID: "1.2.3", instanceNumber: number)
        })
        let viewModel = PrintViewModel(selection: selection)
        viewModel.setImageRange(from: 103, to: 109)

        #expect(viewModel.printedItems.map(\.instanceNumber) == [103, 104, 105, 106, 107, 108, 109])
    }

    @Test("A gappy selection is filtered by number, not by count")
    func testGapsInTheSeries() {
        // Every third slice marked: "3 to 9" is three images, not seven.
        let selection = PrintSelectionModel()
        selection.add(contentsOf: [3, 6, 9, 12, 15].map { number in
            PrintSelectionItem(filePath: "/\(number).dcm", frameIndex: 0,
                               seriesInstanceUID: "1.2.3", instanceNumber: number)
        })
        let viewModel = PrintViewModel(selection: selection)
        viewModel.setImageRange(from: 3, to: 9)

        #expect(viewModel.printedItems.map(\.instanceNumber) == [3, 6, 9])
    }

    @Test("Marks with no image number fall back to their place in the list")
    func testFallsBackToOrdinal() {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (0..<6).map {
            PrintSelectionItem(filePath: "/\($0).dcm", seriesInstanceUID: "1.2.3")
        })
        let viewModel = PrintViewModel(selection: selection)
        viewModel.setImageRange(from: 2, to: 4)

        #expect(viewModel.printedItems.map(\.filePath) == ["/1.dcm", "/2.dcm", "/3.dcm"],
                "1-based positions, so 2…4 is the second through fourth mark")
    }

    // MARK: - Taking cells off the film

    @Test("Deleting a cell closes the gap — the rest shuffle up in order")
    func testDeleteShufflesUp() {
        let viewModel = makeViewModel(count: 8)
        viewModel.focusCell(id(2))
        let removed = viewModel.removeSelectedCells()

        #expect(removed == 1)
        #expect(viewModel.printedItems.map(\.instanceNumber) == [1, 3, 4, 5, 6, 7, 8])
        #expect(viewModel.plan.filmCount == 2, "seven images still need two sheets")
    }

    @Test("Deleting several picked cells removes exactly those")
    func testDeleteMultiple() {
        let viewModel = makeViewModel(count: 8)
        viewModel.selectCells([id(2), id(3), id(6)])
        let removed = viewModel.removeSelectedCells()

        #expect(removed == 3)
        #expect(viewModel.printedItems.map(\.instanceNumber) == [1, 4, 5, 7, 8])
        #expect(!viewModel.hasCellSelection, "the picked cells are gone, so the picking is over")
    }

    @Test("The focus lands on the cell that shuffled up into the hole")
    func testFocusFollowsTheHole() {
        let viewModel = makeViewModel(count: 8)
        viewModel.selectCells([id(2), id(3)])
        viewModel.removeSelectedCells()

        #expect(viewModel.focusedItemID == id(4),
                "so a run of deletions can be done without chasing the picture")
    }

    @Test("Deleting the last cells leaves the focus on the new last cell")
    func testFocusAtTheEnd() {
        let viewModel = makeViewModel(count: 6)
        viewModel.selectCells([id(5), id(6)])
        viewModel.removeSelectedCells()

        #expect(viewModel.focusedItemID == id(4))
    }

    @Test("With nothing picked or focused, delete does nothing")
    func testDeleteNeedsATarget() {
        let viewModel = makeViewModel(count: 4)
        viewModel.focusCell(nil)

        #expect(viewModel.removeSelectedCells() == 0)
        #expect(viewModel.selection.count == 4)
    }

    @Test("A cell held back by the range is not deleted by a delete on screen")
    func testDeleteOnlyTouchesWhatIsOnFilm() {
        let viewModel = makeViewModel(count: 20)
        viewModel.setImageRange(from: 1, to: 4)
        viewModel.selectAllCellsOnFilm()
        viewModel.focusCell(id(1))
        viewModel.selectCells([id(1), id(2)])
        viewModel.removeSelectedCells()

        #expect(viewModel.selection.count == 18, "only the two on screen went")
        #expect(viewModel.printedItems.map(\.instanceNumber) == [3, 4],
                "the range still holds the rest back")
    }
}
