// PrintCellToolReliabilityTests.swift
// DICOMStudioTests
//
// The film preview's tools, driven the way the view actually drives them: a
// drag is many small events, tools are used in sequence on the same cell, and
// reset is reached for after all of it. Each test here pins a way a tool used
// to *look* dead while the model insisted it was working:
//
// * Zoom had a dead zone below fitted — every value in [0.25, 1) rendered and
//   printed identically to 1, so a downward drag changed nothing and the next
//   upward drag spent its travel climbing invisibly back to fitted. While zoom
//   sat in that zone the pan tool was clamped to zero too, and reset appeared
//   to do nothing because the cell already looked untouched.
// * Pan moved opposite to the hand on flipped cells, because the stored pan is
//   a screen-space vector and the region reader un-rotated it without
//   un-mirroring it.
// * "Reset Cell" lit up for cells that were never edited, because the window
//   seeded on first click counted as an edit — and a seed landing after a
//   reset re-lit the button, as though the reset had not taken.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Cell Tool Reliability Tests")
struct PrintCellToolReliabilityTests {

    private func makeViewModel(items: [PrintSelectionItem]) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: items)
        return PrintViewModel(selection: selection)
    }

    private var markedFrames: [PrintSelectionItem] {
        [
            PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0,
                               windowCenter: 40, windowWidth: 400),
            PrintSelectionItem(filePath: "/b.dcm", frameIndex: 0)
        ]
    }

    private let cell = CGSize(width: 300, height: 250)
    private let pixels = CGSize(width: 512, height: 512)

    private func presentation(
        of viewModel: PrintViewModel, _ id: String = "/a.dcm#0"
    ) -> ViewerPresentation? {
        viewModel.selection.items.first { $0.id == id }?.presentation
    }

    // MARK: - The zoom dead zone

    @Test("A zoom-out drag stops at fitted instead of falling into a dead zone")
    func testZoomOutStopsAtFitted() {
        let viewModel = makeViewModel(items: markedFrames)
        // A long downward drag, one small event at a time — the way a real
        // mouse delivers it.
        for _ in 0..<200 {
            viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 0.99,
                                 cellSize: cell, pixelSize: pixels)
        }
        #expect(presentation(of: viewModel)?.zoom == 1.0,
                "below fitted every zoom renders and prints identically, so the tool must not go there")

        // The very next upward event must move the picture: no invisible climb
        // back through [0.25, 1) before anything responds.
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 1.05,
                             cellSize: cell, pixelSize: pixels)
        let zoom = presentation(of: viewModel)?.zoom ?? 0
        #expect(zoom > 1.0, "the first zoom-in event after a zoom-out drag must respond")
    }

    @Test("Pan responds immediately after zooming in, even after a zoom-out drag")
    func testPanAfterZoomRoundTrip() {
        let viewModel = makeViewModel(items: markedFrames)
        for _ in 0..<100 {
            viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 0.98,
                                 cellSize: cell, pixelSize: pixels)
        }
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2.0,
                             cellSize: cell, pixelSize: pixels)
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 20, dy: 0,
                          cellSize: cell, pixelSize: pixels)
        #expect((presentation(of: viewModel)?.panX ?? 0) != 0,
                "a zoomed cell has pixels hidden beside it, so the pan must travel")
    }

    // MARK: - Pan on flipped cells

    @Test("Pan follows the hand on a horizontally flipped cell")
    func testPanFollowsTheHandWhenFlipped() throws {
        // A mark flipped in the viewer, zoomed here so a pan has travel.
        let flipped = PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            windowCenter: 40, windowWidth: 400,
            presentation: ViewerPresentation(
                zoom: 2.0, viewportWidth: 300, viewportHeight: 250,
                flipHorizontal: true))
        let viewModel = makeViewModel(items: [flipped])

        let before = try #require(
            presentation(of: viewModel)?.visibleRegion(
                imageWidth: 512, imageHeight: 512))
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 40, dy: 0,
                          cellSize: cell, pixelSize: pixels)
        let after = try #require(
            presentation(of: viewModel)?.visibleRegion(
                imageWidth: 512, imageHeight: 512))

        // Dragging right slides the picture right, revealing what was hidden on
        // the picture's screen-left — which on a mirrored image is the *right*
        // of the stored frame. The region must move up the image's x axis; when
        // the flip was ignored it moved down it, and the picture ran away from
        // the hand.
        #expect(after.x > before.x,
                "on a mirrored image, screen-left is the image's right")
    }

    @Test("Pan follows the hand on an unflipped cell")
    func testPanFollowsTheHandUnflipped() throws {
        let plain = PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            windowCenter: 40, windowWidth: 400,
            presentation: ViewerPresentation(
                zoom: 2.0, viewportWidth: 300, viewportHeight: 250))
        let viewModel = makeViewModel(items: [plain])

        let before = try #require(
            presentation(of: viewModel)?.visibleRegion(
                imageWidth: 512, imageHeight: 512))
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 40, dy: 0,
                          cellSize: cell, pixelSize: pixels)
        let after = try #require(
            presentation(of: viewModel)?.visibleRegion(
                imageWidth: 512, imageHeight: 512))

        #expect(after.x < before.x,
                "dragging right reveals pixels to the picture's left")
    }

    @Test("Re-basing a viewer viewport onto the cell carries the pan across")
    func testRebaseScalesThePan() {
        // Panned and zoomed in a wide viewer tile, then touched on a square
        // film cell: the viewport is re-based to the cell's shape, and the pan
        // — stored in view points — must be rescaled with it, or the crop
        // jumps on the first tool touch as though the tool had moved it.
        let marked = PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            presentation: ViewerPresentation(
                zoom: 2.0, panX: 80, panY: 0,
                viewportWidth: 800, viewportHeight: 600))
        let viewModel = makeViewModel(items: [marked])

        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 1.0,
                             cellSize: CGSize(width: 400, height: 400))

        let presentation = presentation(of: viewModel)
        #expect(presentation?.viewportWidth == 400)
        #expect(presentation?.panX == 40,
                "80 points across an 800-point viewport is 40 across a 400-point one")
    }

    @Test("Pan travel exists exactly where something is hidden to bring in")
    func testPanTravelReport() {
        let viewModel = makeViewModel(items: markedFrames)

        // Fitted and unzoomed: the whole image is in the cell, nothing hidden.
        #expect(!viewModel.cellHasPanTravel(viewModel.selection.items[0]),
                "the preview must say so instead of letting the drag die silently")

        // Zoomed in: pixels are hidden beside the cell, so pan has travel.
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2,
                             cellSize: cell, pixelSize: pixels)
        #expect(viewModel.cellHasPanTravel(viewModel.selection.items[0]))

        // Fill scaling crops at every zoom, so even an unzoomed cell pans.
        viewModel.scalingMode = .fillToFilm
        #expect(viewModel.cellHasPanTravel(viewModel.selection.items[1]))
    }

    // MARK: - Reset after a working session

    @Test("Reset returns a cell worked over by every tool to the untouched frame")
    func testResetAfterManyTools() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.focusCell("/a.dcm#0")

        // A realistic session: window drags, zoom drags, pans, an inversion —
        // dozens of small events, as the gestures actually deliver them.
        for _ in 0..<30 {
            viewModel.adjustWindow(forItemID: "/a.dcm#0", deltaCenter: 4, deltaWidth: -6)
        }
        for _ in 0..<20 {
            viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 1.05,
                                 cellSize: cell, pixelSize: pixels)
        }
        for _ in 0..<15 {
            viewModel.panCell(forItemID: "/a.dcm#0", dx: 6, dy: -4,
                              cellSize: cell, pixelSize: pixels)
        }
        for _ in 0..<12 {
            viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 2.5, cellSize: cell)
        }
        viewModel.toggleCellInversion(forItemID: "/a.dcm#0")

        let worked = viewModel.selection.items[0]
        #expect(viewModel.isCellEdited(worked))

        viewModel.resetFocusedCell()

        let reset = viewModel.selection.items[0]
        #expect(reset.windowCenter == nil)
        #expect(reset.windowWidth == nil)
        #expect(reset.presentation == nil)
        #expect(!viewModel.isCellEdited(reset))
        #expect(!viewModel.selection.isAdjusted("/a.dcm#0"),
                "a reset cell follows the viewer again")
    }

    @Test("Reset All undoes a linked drag that reached every cell")
    func testResetAllAfterLinkedEdits() {
        let items = [
            PrintSelectionItem(filePath: "/s/1.dcm", frameIndex: 0,
                               seriesInstanceUID: "S1",
                               windowCenter: 40, windowWidth: 400),
            PrintSelectionItem(filePath: "/s/2.dcm", frameIndex: 0,
                               seriesInstanceUID: "S1",
                               windowCenter: 40, windowWidth: 400)
        ]
        let viewModel = makeViewModel(items: items)
        viewModel.cellSync = [.zoomPan, .window, .invert]
        viewModel.focusCell("/s/1.dcm#0")

        viewModel.adjustZoom(forItemID: "/s/1.dcm#0", factor: 3,
                             cellSize: cell, pixelSize: pixels)
        viewModel.adjustWindow(forItemID: "/s/1.dcm#0", deltaCenter: 100, deltaWidth: 200)
        #expect(viewModel.hasEditedCells)
        #expect(viewModel.selection.items.allSatisfy { viewModel.isCellEdited($0) },
                "the shut locks carried the drag to the peer")

        viewModel.resetAllCells()
        #expect(!viewModel.hasEditedCells)
        for item in viewModel.selection.items {
            #expect(item.presentation == nil)
            #expect(item.windowCenter == nil)
        }
    }

    // MARK: - Rotation

    @Test("A rotate drag accumulates, one small event at a time")
    func testRotateDragAccumulates() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.focusCell("/a.dcm#0")

        // The way the gesture actually arrives: a bearing delta per mouse move,
        // each far too small to see on its own.
        for _ in 0..<24 {
            viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 1.25, cellSize: cell)
        }

        #expect(presentation(of: viewModel)?.rotationDegrees == 30)
    }

    @Test("Turning a cell does not disturb the crop it was zoomed to")
    func testRotateKeepsTheCrop() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.focusCell("/a.dcm#0")
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 3,
                             cellSize: cell, pixelSize: pixels)
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 20, dy: -12,
                          cellSize: cell, pixelSize: pixels)
        let before = presentation(of: viewModel)

        for _ in 0..<10 {
            viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 4, cellSize: cell)
        }

        let after = presentation(of: viewModel)
        #expect(after?.rotationDegrees == 40)
        #expect(after?.zoom == before?.zoom)
        #expect(after?.panX == before?.panX)
        #expect(after?.panY == before?.panY)
    }

    @Test("A turned cell says it is edited, so Reset lights up for it")
    func testRotationCountsAsAnEdit() {
        let viewModel = makeViewModel(items: markedFrames)
        // The cell with no window of its own, so rotation is the only edit.
        viewModel.focusCell("/b.dcm#0")
        #expect(!viewModel.isCellEdited(viewModel.selection.items[1]))

        viewModel.rotateCell(forItemID: "/b.dcm#0", byDegrees: 12, cellSize: cell)

        #expect(viewModel.isCellEdited(viewModel.selection.items[1]))
        viewModel.resetFocusedCell()
        #expect(viewModel.selection.items[1].presentation == nil)
    }

    @Test("Turning a cell switches the film on to carrying arrangements")
    func testRotateTurnsOnViewerPresentation() {
        let viewModel = makeViewModel(items: markedFrames)
        // With this off the edit is written and then dropped by the preview, so
        // the tool would look dead however far it was dragged — the same trap
        // zoom and pan fell into.
        viewModel.useViewerPresentation = false

        viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 15, cellSize: cell)

        #expect(viewModel.useViewerPresentation)
        #expect(viewModel.previewItem(for: viewModel.selection.items[0])
            .presentation?.rotationDegrees == 15,
                "what the preview renders carries the turn")
    }

    // MARK: - The seed is not an edit

    @Test("A seeded window does not count as an edit, so Reset stays honest")
    func testSeededWindowIsNotAnEdit() {
        let viewModel = makeViewModel(items: [
            PrintSelectionItem(filePath: "/c.dcm", frameIndex: 0)
        ])
        // What seedWindowIfNeeded does once the file has been read: the file's
        // own resolved window, written into the mark and remembered as the
        // baseline.
        viewModel.selection.update(
            viewModel.selection.items[0].with(
                windowCenter: .some(50), windowWidth: .some(350)),
            force: true)
        viewModel.seededWindows["/c.dcm#0"] = WindowSettings(center: 50, width: 350)

        #expect(!viewModel.isCellEdited(viewModel.selection.items[0]),
                "clicking a cell must not light Reset")
        #expect(!viewModel.hasEditedCells)

        // A real drag away from the seed is an edit…
        viewModel.adjustWindow(forItemID: "/c.dcm#0", deltaCenter: 30, deltaWidth: 0)
        #expect(viewModel.isCellEdited(viewModel.selection.items[0]))

        // …and reset takes it back, including when the asynchronous seed lands
        // *after* the reset and re-writes the same baseline values.
        viewModel.resetCell(forItemID: "/c.dcm#0")
        #expect(!viewModel.isCellEdited(viewModel.selection.items[0]))
        viewModel.selection.update(
            viewModel.selection.items[0].with(
                windowCenter: .some(50), windowWidth: .some(350)),
            force: true)
        #expect(!viewModel.isCellEdited(viewModel.selection.items[0]),
                "a late-landing seed must not read as the reset failing")
    }

    @Test("Windowing still works after a reset, without leaving the cell")
    func testWindowingAliveAfterReset() {
        let viewModel = makeViewModel(items: [
            PrintSelectionItem(filePath: "/c.dcm", frameIndex: 0)
        ])
        // The cell was clicked once, so it carries the file's own window and
        // the seed baseline remembers it.
        viewModel.selection.update(
            viewModel.selection.items[0].with(
                windowCenter: .some(50), windowWidth: .some(350)),
            force: true)
        viewModel.seededWindows["/c.dcm#0"] = WindowSettings(center: 50, width: 350)

        viewModel.adjustWindow(forItemID: "/c.dcm#0", deltaCenter: 30, deltaWidth: 20)
        viewModel.resetCell(forItemID: "/c.dcm#0")

        // Reset must not leave the mark windowless: the cell stays focused, so
        // no click re-seeds it, and a drag with no starting values is dead.
        #expect(viewModel.window(forItemID: "/c.dcm#0") ==
                WindowSettings(center: 50, width: 350),
                "reset restores the file's own window from the seed baseline")
        #expect(!viewModel.isCellEdited(viewModel.selection.items[0]),
                "the restored seed must not light Reset")

        // The user's next window drag, straight after the reset.
        viewModel.adjustWindow(forItemID: "/c.dcm#0", deltaCenter: -10, deltaWidth: 40)
        #expect(viewModel.window(forItemID: "/c.dcm#0") ==
                WindowSettings(center: 40, width: 390),
                "the first drag after a reset must move the window")
    }

    @Test("A window that came from the viewer still counts as an edit")
    func testViewerWindowStillCountsAsEdited() {
        let viewModel = makeViewModel(items: markedFrames)
        // "/a.dcm#0" carries the viewer's window and was never seeded here, so
        // reset has real work to do: back to the file's own window.
        #expect(viewModel.isCellEdited(viewModel.selection.items[0]))
    }

    // MARK: - Selection against what the films actually carry

    /// One series of four numbered marks, so an image range can hide some.
    private var numberedSeries: [PrintSelectionItem] {
        (1...4).map { (number: Int) in
            PrintSelectionItem(filePath: "/s/\(number).dcm", frameIndex: 0,
                               seriesInstanceUID: "S1", instanceNumber: number)
        }
    }

    @Test("Select-all-on-film picks the printed cells, not the range-hidden ones")
    func testSelectAllRespectsTheImageRange() throws {
        let viewModel = makeViewModel(items: numberedSeries)
        let seriesKey = try #require(viewModel.selection.items.first?.seriesKey)
        viewModel.imageRanges[seriesKey] = 2...4

        #expect(viewModel.printedItems.map(\.instanceNumber) == [2, 3, 4])

        viewModel.focusCell("/s/2.dcm#0")
        let count = viewModel.selectAllCellsOnFilm()
        #expect(count == 3)
        #expect(!viewModel.selectedItemIDs.contains("/s/1.dcm#0"),
                "a cell the range took off the film must not be picked")
    }

    @Test("Focus and selection are dropped for cells an image range hides")
    func testRangeHiddenCellsLoseFocusAndSelection() throws {
        let viewModel = makeViewModel(items: numberedSeries)
        viewModel.focusCell("/s/1.dcm#0")
        viewModel.selectCells(["/s/1.dcm#0", "/s/2.dcm#0"])

        let seriesKey = try #require(viewModel.selection.items.first?.seriesKey)
        viewModel.imageRanges[seriesKey] = 2...4
        viewModel.pruneFocus()
        viewModel.pruneCellSelection()

        #expect(viewModel.focusedItemID == nil,
                "a focus ring on a cell no sheet shows decides where a keyboard reset lands")
        #expect(viewModel.selectedItemIDs == ["/s/2.dcm#0"])
    }
}
