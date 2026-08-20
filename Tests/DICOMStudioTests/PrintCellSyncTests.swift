// PrintCellSyncTests.swift
// DICOMStudioTests
//
// Linking the film's cells, so adjusting one adjusts the rest.
//
// The properties under test are the two that make the mode safe to leave on:
// geometry is copied absolutely (every cell is the same size, so the same zoom
// and pan is the same picture), and windowing is carried as a proportion (a film
// mixes modalities, and one modality's numbers mean nothing in another's
// pixels). Everything still lands in the marks, which is what prints.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@MainActor
@Suite("Print Cell Sync Tests")
struct PrintCellSyncTests {

    private func makeViewModel(items: [PrintSelectionItem]) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: items)
        return PrintViewModel(selection: selection)
    }

    /// Two frames of one series and one from another, so scope is testable.
    ///
    /// Three marks land on one film under the default layout, which is what
    /// makes them peers at all: a locked edit never leaves the sheet it was made
    /// on — see ``PrintCellSyncScope``.
    private var mixedFilm: [PrintSelectionItem] {
        [
            PrintSelectionItem(filePath: "/ct1.dcm", seriesInstanceUID: "1.2.3",
                               windowCenter: 40, windowWidth: 400),
            PrintSelectionItem(filePath: "/ct2.dcm", seriesInstanceUID: "1.2.3",
                               windowCenter: 40, windowWidth: 400),
            PrintSelectionItem(filePath: "/mr1.dcm", seriesInstanceUID: "9.9.9",
                               windowCenter: 600, windowWidth: 1200)
        ]
    }

    private let cell = CGSize(width: 200, height: 200)

    // MARK: - Off by default

    @Test("Nothing is linked until it is switched on")
    func testOffByDefault() {
        let viewModel = makeViewModel(items: mixedFilm)
        #expect(!viewModel.isCellSyncActive)

        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 2, cellSize: cell)
        #expect(viewModel.selection.items.first { $0.id == "/ct2.dcm#0" }?.presentation == nil)
    }

    // MARK: - Geometry

    @Test("A linked zoom is copied to the other cells exactly")
    func testZoomIsCopiedAbsolutely() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.zoomPan)

        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 2, cellSize: cell)

        for id in ["/ct1.dcm#0", "/ct2.dcm#0", "/mr1.dcm#0"] {
            let zoom = viewModel.selection.items.first { $0.id == id }?.presentation?.zoom
            #expect(zoom == 2)
        }
    }

    @Test("A linked pan puts every cell over the same part of its image")
    func testPanIsCopied() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.zoomPan)

        // Zoomed in first: a fitted cell has nowhere to pan to.
        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 4, cellSize: cell)
        viewModel.panCell(forItemID: "/ct1.dcm#0", dx: 20, dy: -10, cellSize: cell)

        let source = viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?.presentation
        let peer = viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?.presentation
        #expect(source?.panX == peer?.panX)
        #expect(source?.panY == peer?.panY)
    }

    @Test("Rotation stays on the cell it was made on while its lock is open")
    func testRotationIsNotLinkedWithTheLockOpen() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        // Every other lock shut: turning a cell must still be about that cell.
        viewModel.cellSync = [.window, .zoomPan, .invert]

        viewModel.rotateCell(forItemID: "/ct1.dcm#0", cellSize: cell)

        #expect(viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?
            .presentation?.quarterTurns == 1)
        #expect(viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?.presentation == nil)
    }

    @Test("A shut rotate lock stands the other cells the same way round")
    func testRotationIsLinked() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.rotate)

        viewModel.rotateCell(forItemID: "/ct1.dcm#0", byDegrees: 30, cellSize: cell)

        #expect(viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?
            .presentation?.rotationDegrees == 30)
        #expect(viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?
            .presentation?.rotationDegrees == 30)
        // The switch is offered, like every other lock.
        #expect(PrintCellSyncOptions.catalog.contains { $0.title == "Rotate" })
    }

    @Test("The angle is copied, not the turn: peers end up standing the same way")
    func testRotationTravelsAsAValue() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm

        // The two cells start at different angles, set with the lock open.
        viewModel.rotateCell(forItemID: "/ct1.dcm#0", byDegrees: 90, cellSize: cell)
        viewModel.rotateCell(forItemID: "/mr1.dcm#0", byDegrees: 10, cellSize: cell)

        // Shut the lock and turn one of them: both end up at the same angle,
        // rather than the peer keeping its 10° head start.
        viewModel.toggleSync(.rotate)
        viewModel.rotateCell(forItemID: "/ct1.dcm#0", byDegrees: 15, cellSize: cell)

        #expect(viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?
            .presentation?.rotationDegrees == 105)
        #expect(viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?
            .presentation?.rotationDegrees == 105)
    }

    @Test("Flip is never carried, however the locks are set")
    func testFlipIsNeverLinked() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.cellSync = .all

        #expect(!PrintCellSyncOptions.catalog.contains { $0.title.contains("Flip") })
    }

    @Test("Inversion travels on its own switch")
    func testInvertIsLinked() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.invert)

        viewModel.toggleCellInversion(forItemID: "/ct1.dcm#0", cellSize: cell)

        #expect(viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?
            .presentation?.invert == true)
    }

    /// The rail's Invert button has no cell to speak of, so it passes none —
    /// and inversion is not geometry, so that must leave the crop exactly where
    /// the drag tools put it.
    @Test("Inverting without a cell size leaves the arrangement untouched")
    func testInvertWithoutACellKeepsTheCrop() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 3, cellSize: cell)
        viewModel.panCell(forItemID: "/ct1.dcm#0", dx: 12, dy: 8, cellSize: cell)
        let before = viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?.presentation

        viewModel.toggleCellInversion(forItemID: "/ct1.dcm#0")

        let after = viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?.presentation
        #expect(after?.invert == true)
        #expect(after?.zoom == before?.zoom)
        #expect(after?.panX == before?.panX)
        #expect(after?.panY == before?.panY)
        #expect(after?.viewportWidth == before?.viewportWidth)
        #expect(after?.viewportHeight == before?.viewportHeight)
    }

    // MARK: - Getting back out

    @Test("Reset returns the focused cell alone to the untouched frame")
    func testResetFocusedCell() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.zoomPan)
        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 3, cellSize: cell)
        viewModel.focusCell("/ct1.dcm#0")

        viewModel.resetFocusedCell()

        #expect(viewModel.selection.items.first { $0.id == "/ct1.dcm#0" }?.presentation == nil)
        // The cells it was linked to keep the arrangement; one cell was reset.
        #expect(viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?
            .presentation?.zoom == 3)
    }

    @Test("Reset All clears the whole sheet, which is what a linked drag can spoil")
    func testResetAllCells() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.zoomPan)
        viewModel.toggleSync(.window)
        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 3, cellSize: cell)
        viewModel.setWindow(forItemID: "/ct1.dcm#0", center: 80, width: 600)
        #expect(viewModel.hasEditedCells)

        viewModel.resetAllCells()

        #expect(!viewModel.hasEditedCells)
        for item in viewModel.selection.items {
            #expect(item.presentation == nil)
            #expect(item.windowCenter == nil)
            // Reset marks are no longer defended from the viewer.
            #expect(!viewModel.isCellAdjusted(item.id))
        }
    }

    // MARK: - Windowing

    @Test("A linked window drag moves each cell in proportion to its own window")
    func testWindowIsCarriedRelatively() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.window)

        // The CT is widened by half and its centre raised by a tenth of a width.
        viewModel.setWindow(forItemID: "/ct1.dcm#0", center: 80, width: 600)

        let mr = viewModel.window(forItemID: "/mr1.dcm#0")
        // Width scales by the same factor: 1200 × 1.5.
        #expect(mr?.width == 1800)
        // The centre moves by the same fraction of a width: 600 + 0.1 × 1200.
        #expect(mr?.center == 720)
        // Copying the CT's numbers over would have blacked the MR out.
        #expect(mr?.center != 80)
    }

    @Test("A preset is copied as the window it is, not as the change it made")
    func testPresetIsCopiedAbsolutely() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.window)

        let lung = WindowLevelPreset(name: "Lung", center: -600, width: 1500, modality: "CT")
        viewModel.applyWindowPreset(lung, toItemID: "/ct1.dcm#0")

        let source = viewModel.window(forItemID: "/ct1.dcm#0")
        let peer = viewModel.window(forItemID: "/mr1.dcm#0")
        #expect(peer?.center == source?.center)
        #expect(peer?.width == source?.width)
        // The space comes with the numbers: −600 HU written into a peer still
        // labelled "stored values" would wash that peer out to white.
        #expect(viewModel.selection.items
            .first { $0.id == "/mr1.dcm#0" }?.windowSpace == .outputUnits)
    }

    @Test("A job-wide window switches the cell link off — nothing per-cell prints")
    func testWindowSyncYieldsToTheJobWideWindow() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSync(.window)
        viewModel.useExplicitWindow = true

        #expect(!viewModel.isSynced(.window))
        viewModel.setWindow(forItemID: "/ct1.dcm#0", center: 80, width: 600)
        #expect(viewModel.window(forItemID: "/mr1.dcm#0")?.width == 1200)
        // And no cell claims a lock it is not honouring.
        viewModel.focusCell("/ct1.dcm#0")
        #expect(!viewModel.isCellSyncActive)
        #expect(!viewModel.isLinkedToFocus("/ct2.dcm#0"))
    }

    // MARK: - Scope

    @Test("Same Series is the default and holds the edit inside one series")
    func testSameSeriesScope() {
        let viewModel = makeViewModel(items: mixedFilm)
        #expect(viewModel.cellSyncScope == .sameSeries)
        viewModel.toggleSync(.zoomPan)

        viewModel.adjustZoom(forItemID: "/ct1.dcm#0", factor: 2, cellSize: cell)

        #expect(viewModel.selection.items.first { $0.id == "/ct2.dcm#0" }?
            .presentation?.zoom == 2)
        // The other series is a comparison, not a copy.
        #expect(viewModel.selection.items.first { $0.id == "/mr1.dcm#0" }?.presentation == nil)
    }

    @Test("Marks that know no series group by the folder they came from")
    func testSeriesKeyFallsBackToTheFolder() {
        let items = [
            PrintSelectionItem(filePath: "/study/a.dcm"),
            PrintSelectionItem(filePath: "/study/b.dcm"),
            PrintSelectionItem(filePath: "/elsewhere/c.dcm")
        ]
        let viewModel = makeViewModel(items: items)
        viewModel.toggleSync(.zoomPan)

        viewModel.adjustZoom(forItemID: "/study/a.dcm#0", factor: 2, cellSize: cell)

        #expect(viewModel.selection.items.first { $0.id == "/study/b.dcm#0" }?
            .presentation?.zoom == 2)
        #expect(viewModel.selection.items.first { $0.id == "/elsewhere/c.dcm#0" }?
            .presentation == nil)
    }

    // MARK: - The lock on the cell

    @Test("A cell shows a lock only when it would move with the focused cell")
    func testLockIsShownOnLinkedCellsOnly() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.focusCell("/ct1.dcm#0")

        // Nothing locked: no cell claims to be linked, not even the focused one.
        #expect(!viewModel.isLinkedToFocus("/ct1.dcm#0"))
        #expect(!viewModel.isLinkedToFocus("/ct2.dcm#0"))

        // Locked, at the default scope: the series moves, the other one does not.
        viewModel.toggleSync(.zoomPan)
        #expect(viewModel.isLinkedToFocus("/ct1.dcm#0"))
        #expect(viewModel.isLinkedToFocus("/ct2.dcm#0"))
        #expect(!viewModel.isLinkedToFocus("/mr1.dcm#0"))

        // Widening the scope lights the rest of the sheet — which is the point
        // of drawing it per cell rather than stating it once.
        viewModel.cellSyncScope = .thisFilm
        #expect(viewModel.isLinkedToFocus("/mr1.dcm#0"))
    }

    @Test("With nothing focused there is nothing to be linked to")
    func testNoFocusNoLocks() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSync = .all
        #expect(!viewModel.isLinkedToFocus("/ct1.dcm#0"))
    }

    @Test("The source cell is never in its own peer list")
    func testSourceIsNotItsOwnPeer() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.cellSyncScope = .thisFilm
        #expect(!viewModel.syncPeers(of: "/ct1.dcm#0").contains { $0.id == "/ct1.dcm#0" })
        #expect(viewModel.syncPeers(of: "/ct1.dcm#0").count == 2)
    }

    // MARK: - The one door the UI toggles a lock through

    /// The rail button, the context menu and the keyboard shortcut all shut a
    /// lock through ``toggleSyncFromUI(_:)`` — so the seeding and the job-wide
    /// window guard cannot be honoured by one caller and forgotten by another.

    @Test("Shutting and opening a lock from the UI is a plain toggle")
    func testUIToggleShutsAndOpens() {
        let viewModel = makeViewModel(items: mixedFilm)

        #expect(viewModel.toggleSyncFromUI(.zoomPan))
        #expect(viewModel.cellSync.contains(.zoomPan))

        #expect(viewModel.toggleSyncFromUI(.zoomPan))
        #expect(!viewModel.cellSync.contains(.zoomPan))
    }

    @Test("A job-wide window refuses the window lock, whoever asks")
    func testUIToggleRefusesWindowLockWhenOverridden() {
        let viewModel = makeViewModel(items: mixedFilm)
        viewModel.useExplicitWindow = true
        #expect(viewModel.isCellWindowingOverridden)

        // The rail's button is disabled in this state, but a keyboard shortcut
        // is delivered whether or not a button would have taken the click — so
        // the refusal has to live below the button, not in it.
        #expect(viewModel.toggleSyncFromUI(.window) == false)
        #expect(!viewModel.cellSync.contains(.window),
                "a lit window lock would promise a link that reaches no film")

        // The other locks are unaffected: a job-wide window says nothing about
        // where the cells are zoomed to.
        #expect(viewModel.toggleSyncFromUI(.zoomPan))
        #expect(viewModel.cellSync.contains(.zoomPan))
    }
}
