// PrintCellSelectionTests.swift
// DICOMStudioTests
//
// Picking out the cells a tool acts on.
//
// The property under test throughout: an explicit selection is a statement the
// reader has just made by hand, and nothing may quietly widen it. While one is
// in force the locks stand aside; a drag on a cell outside it is a drag on that
// cell alone; and clearing it hands the film back to the locks unchanged.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Cell Selection Tests")
struct PrintCellSelectionTests {

    /// Eight frames of one series, so the sync scope's "same series" rule would
    /// reach all of them if it were allowed to.
    private func makeViewModel(count: Int = 8) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (0..<count).map {
            PrintSelectionItem(filePath: "/\($0).dcm", frameIndex: 0,
                               seriesInstanceUID: "1.2.3")
        })
        let viewModel = PrintViewModel(selection: selection)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        return viewModel
    }

    private func id(_ index: Int) -> String { "/\(index).dcm#0" }

    // MARK: Building a selection the way a click does

    @Test("⌘-clicking three cells picks three, and Delete takes all three")
    func testPickThreeThenDelete() {
        // The path the film actually drives: one toggle per ⌘-click, then the
        // menu's delete. It used to take only the cell clicked last, because
        // the modified click never reached the selection at all.
        let viewModel = makeViewModel()
        viewModel.toggleCellSelection(id(1))
        viewModel.toggleCellSelection(id(2))
        viewModel.toggleCellSelection(id(5))

        #expect(viewModel.selectedItemIDs.count == 3)
        #expect(viewModel.removableCellCount == 3, "the menu says three, so three go")

        let removed = viewModel.removeSelectedCells()
        #expect(removed == 3)
        #expect(viewModel.selection.items.map(\.id) == [id(0), id(3), id(4), id(6), id(7)])
    }

    @Test("With nothing picked, delete takes the focused cell alone")
    func testDeleteFocusedOnly() {
        let viewModel = makeViewModel()
        viewModel.focusCell(id(3))

        #expect(viewModel.removableCellCount == 1)
        #expect(viewModel.removeSelectedCells() == 1)
        #expect(!viewModel.selection.items.contains { $0.id == id(3) })
        #expect(viewModel.selection.count == 7)
    }

    // MARK: What counts as a selection

    @Test("One cell is not a selection — that is what the focus already says")
    func testSingleCellIsNotASelection() {
        let viewModel = makeViewModel()
        viewModel.toggleCellSelection(id(0))

        #expect(!viewModel.hasCellSelection)
        #expect(viewModel.isCellSelected(id(0)), "it is still marked, just not in force")
    }

    @Test("Two cells are")
    func testTwoCellsAreASelection() {
        let viewModel = makeViewModel()
        viewModel.toggleCellSelection(id(0))
        viewModel.toggleCellSelection(id(3))

        #expect(viewModel.hasCellSelection)
        #expect(viewModel.cellSelectionSummary?.contains("2 cells") == true)
    }

    @Test("⌘-clicking a selected cell takes it out again, and still focuses it")
    func testToggleOff() {
        let viewModel = makeViewModel()
        viewModel.toggleCellSelection(id(0))
        viewModel.toggleCellSelection(id(3))
        viewModel.toggleCellSelection(id(3))

        #expect(!viewModel.isCellSelected(id(3)))
        #expect(viewModel.focusedItemID == id(3), "the cell was pointed at, so it is the subject")
    }

    // MARK: Selection wins over the locks

    @Test("A tool acts on the selected cells and no others, whatever the locks say")
    func testSelectionOverridesLocks() {
        let viewModel = makeViewModel()
        // Locks wide open: every cell of the series would move.
        viewModel.cellSync = .all
        viewModel.cellSyncScope = .thisFilm
        viewModel.selectCells([id(1), id(2), id(5)])

        let affected = Set(viewModel.cellsAffected(byEditing: id(1)).map(\.id))
        #expect(affected == [id(1), id(2), id(5)],
                "a hand-picked set may span films; a lock may not")

        let peers = Set(viewModel.editPeers(of: id(1)).map(\.id))
        #expect(peers == [id(2), id(5)], "the source is not among its own peers")
    }

    @Test("Dragging a cell outside the selection moves that cell alone")
    func testUnselectedCellIsNotCarriedByTheSelection() {
        let viewModel = makeViewModel()
        viewModel.selectCells([id(1), id(2)])

        #expect(viewModel.cellsAffected(byEditing: id(6)).map(\.id) == [id(6)])
        #expect(viewModel.editPeers(of: id(6)).isEmpty)
        #expect(!viewModel.propagates(.window, from: id(6)),
                "a lock is off and this cell is not selected: nothing travels")
    }

    @Test("With no selection the locks decide, exactly as before")
    func testLocksStillWorkWithoutASelection() {
        let viewModel = makeViewModel()
        viewModel.cellSync = [.window]
        viewModel.cellSyncScope = .thisFilm

        #expect(!viewModel.hasCellSelection)
        #expect(viewModel.propagates(.window, from: id(0)))
        #expect(!viewModel.propagates(.zoomPan, from: id(0)), "that lock is open")
        #expect(viewModel.editPeers(of: id(0)).count == 3,
                "the other three cells of this film — never the next film's")
    }

    @Test("A selected cell carries every kind of edit, no lock required")
    func testSelectionCarriesEveryTool() {
        let viewModel = makeViewModel()
        viewModel.cellSync = []
        viewModel.selectCells([id(0), id(1)])

        #expect(viewModel.propagates(.window, from: id(0)))
        #expect(viewModel.propagates(.zoomPan, from: id(0)))
        #expect(viewModel.propagates(.invert, from: id(0)))
    }

    @Test("A job-wide window still stops window edits travelling")
    func testJobWideWindowBeatsTheSelection() {
        let viewModel = makeViewModel()
        viewModel.selectCells([id(0), id(1)])
        viewModel.useExplicitWindow = true

        #expect(!viewModel.propagates(.window, from: id(0)),
                "nothing per-cell reaches the film, so there is nothing to carry")
        #expect(viewModel.propagates(.zoomPan, from: id(0)), "geometry still does")
    }

    // MARK: Succeeding cells

    @Test("Succeeding cells run from the focused cell to the end of its film")
    func testSucceedingCellsStopAtTheFilmEdge() {
        let viewModel = makeViewModel()
        // 2×2: cells 0–3 on film one, 4–7 on film two.
        viewModel.focusCell(id(1))
        let count = viewModel.selectSucceedingCellsOnFilm()

        #expect(count == 3)
        #expect(viewModel.selectedItemIDs == [id(1), id(2), id(3)])
        #expect(!viewModel.isCellSelected(id(4)), "the next film is not on screen to be judged")
    }

    @Test("Succeeding from a cell on the second film stays on the second film")
    func testSucceedingOnALaterFilm() {
        let viewModel = makeViewModel()
        viewModel.focusCell(id(5))
        viewModel.selectSucceedingCellsOnFilm()

        #expect(viewModel.selectedItemIDs == [id(5), id(6), id(7)])
    }

    @Test("The last cell of a film selects only itself, which is not a selection")
    func testSucceedingFromTheLastCell() {
        let viewModel = makeViewModel()
        viewModel.focusCell(id(3))
        let count = viewModel.selectSucceedingCellsOnFilm()

        #expect(count == 1)
        #expect(!viewModel.hasCellSelection, "one cell changes nothing about what a drag hits")
    }

    @Test("All cells on this film takes the whole sheet, not the whole job")
    func testAllCellsOnFilm() {
        let viewModel = makeViewModel()
        viewModel.focusCell(id(6))
        let count = viewModel.selectAllCellsOnFilm()

        #expect(count == 4)
        #expect(viewModel.selectedItemIDs == [id(4), id(5), id(6), id(7)])
    }

    @Test("With nothing focused there is nothing to select from")
    func testNoFocusSelectsNothing() {
        let viewModel = makeViewModel()
        viewModel.focusCell(nil)

        #expect(viewModel.selectSucceedingCellsOnFilm() == 0)
        #expect(viewModel.selectAllCellsOnFilm() == 0)
        #expect(viewModel.selectedItemIDs.isEmpty)
    }

    // MARK: Housekeeping

    @Test("A mark taken off the film leaves the selection")
    func testPruning() {
        let viewModel = makeViewModel()
        viewModel.selectCells([id(0), id(1), id(2)])
        viewModel.selection.remove(filePath: "/1.dcm", frameIndex: 0)
        viewModel.pruneCellSelection()

        #expect(viewModel.selectedItemIDs == [id(0), id(2)])
    }

    @Test("Clearing hands the film back to the locks")
    func testClearing() {
        let viewModel = makeViewModel()
        viewModel.cellSync = [.window]
        viewModel.cellSyncScope = .thisFilm
        viewModel.selectCells([id(0), id(1)])
        viewModel.clearCellSelection()

        #expect(!viewModel.hasCellSelection)
        #expect(viewModel.cellSelectionSummary == nil)
        #expect(viewModel.editPeers(of: id(0)).count == 3, "the lock reaches this film again")
    }

    // MARK: What the cell badges say

    @Test("The badge marks the cells a drag will move")
    func testBadges() {
        let viewModel = makeViewModel()
        viewModel.focusCell(id(0))
        viewModel.selectCells([id(0), id(2)])

        #expect(viewModel.movesWithFocus(id(0)))
        #expect(viewModel.movesWithFocus(id(2)))
        #expect(!viewModel.movesWithFocus(id(1)), "not picked, so it stays put")
    }
}
