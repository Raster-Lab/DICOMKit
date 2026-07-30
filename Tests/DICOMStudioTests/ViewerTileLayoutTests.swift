// ViewerTileLayoutTests.swift
// DICOMStudioTests
//
// The viewer's tile grid: which tiles show what, how each keeps its own
// arrangement, and how tiles become film cells in the same order.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import DICOMNetwork
import Foundation

@Suite("Viewer Tile Layout Tests")
struct ViewerTileLayoutTests {

    // MARK: - The layout itself

    @Test("Every grid from 1×1 to 4×4 is offered, rows varying slowest")
    func testAllCases() {
        let all = ViewerTileLayout.allCases
        #expect(all.count == 16)
        #expect(all.first == ViewerTileLayout(rows: 1, columns: 1))
        #expect(all.last == ViewerTileLayout(rows: 4, columns: 4))
        // 1×1, 1×2, 1×3, 1×4, 2×1 … — the order the labels read in.
        #expect(all.prefix(5).map(\.displayName) == ["1×1", "1×2", "1×3", "1×4", "2×1"])
    }

    @Test("Cell count and label follow rows × columns")
    func testCellCount() {
        #expect(ViewerTileLayout(rows: 2, columns: 3).cellCount == 6)
        #expect(ViewerTileLayout(rows: 2, columns: 3).displayName == "2×3")
        #expect(ViewerTileLayout.single.cellCount == 1)
    }

    @Test("Degenerate sizes are clamped rather than producing an empty grid")
    func testClamping() {
        #expect(ViewerTileLayout(rows: 0, columns: -3).cellCount == 1)
    }

    // MARK: - Tile state

    @Test("A tile's arrangement becomes a print presentation")
    func testCellPresentation() {
        let cell = ViewerCellState(
            index: 2, filePath: "/a.dcm", frameIndex: 4,
            zoom: 3, panX: 12, panY: -8, rotationAngle: 180,
            isFlippedHorizontal: true, isInverted: true,
            viewportWidth: 400, viewportHeight: 300)

        let presentation = cell.presentation
        #expect(presentation.zoom == 3)
        #expect(presentation.panX == 12)
        #expect(presentation.quarterTurns == 2)
        #expect(presentation.flipHorizontal)
        #expect(presentation.invert)
        #expect(presentation.viewportWidth == 400)
    }

    @Test("An empty tile produces no print mark")
    func testEmptyCellHasNoItem() {
        let empty = ViewerCellState(index: 0)
        #expect(empty.isEmpty)
        #expect(empty.selectionItem() == nil)
    }
}

@MainActor
@Suite("Viewer Tile Layout ViewModel Tests")
struct ViewerTileLayoutViewModelTests {

    private func seriesViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        viewModel.seriesFiles = ["/a.dcm", "/b.dcm", "/c.dcm", "/d.dcm", "/e.dcm"]
        viewModel.currentFileIndex = 0
        viewModel.filePath = "/a.dcm"
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 800
        return viewModel
    }

    @Test("The viewer starts at 1×1")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultIsSingle() {
        let viewModel = ImageViewerViewModel()
        #expect(viewModel.layout == .single)
        #expect(viewModel.isMultiCellLayout == false)
        #expect(viewModel.cells.isEmpty)
    }

    @Test("Applying a grid fills tiles from the series in order")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGridFillsFromSeries() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        #expect(viewModel.isMultiCellLayout)
        #expect(viewModel.cells.count == 4)
        #expect(viewModel.cells.map(\.filePath) == ["/a.dcm", "/b.dcm", "/c.dcm", "/d.dcm"])
        #expect(viewModel.focusedCellIndex == 0)
    }

    @Test("Tiles beyond the end of the series stay empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTilesBeyondSeriesAreEmpty() {
        let viewModel = seriesViewModel()
        viewModel.currentFileIndex = 3
        viewModel.filePath = "/d.dcm"
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 4))

        #expect(viewModel.cells.map(\.filePath) == ["/d.dcm", "/e.dcm", nil, nil])
        #expect(viewModel.cells[2].isEmpty)
    }

    @Test("Each tile keeps its own zoom and pan")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerTileArrangement() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        // Arrange the first tile.
        viewModel.zoomLevel = 3
        viewModel.panOffsetX = 40
        viewModel.captureFocusedCell()

        #expect(viewModel.cells[0].zoom == 3)
        #expect(viewModel.cells[0].panX == 40)
        // The second tile is untouched by the first tile's arrangement.
        #expect(viewModel.cells[1].zoom == 1)
        #expect(viewModel.cells[1].panX == 0)
    }

    @Test("Focusing a tile hands the live viewer over to it")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFocusSwitchesLiveState() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        viewModel.zoomLevel = 5
        viewModel.rotationAngle = 90
        viewModel.focusCell(1)

        // Tile 0's arrangement was saved…
        #expect(viewModel.cells[0].zoom == 5)
        #expect(viewModel.cells[0].rotationAngle == 90)
        // …and the live view model now reflects tile 1's own (default) state.
        #expect(viewModel.focusedCellIndex == 1)
        #expect(viewModel.zoomLevel == 1)
        #expect(viewModel.rotationAngle == 0)
        // Switching tiles must not tear down the series being navigated.
        #expect(viewModel.seriesFiles.count == 5)
        #expect(viewModel.currentFileIndex == 1)
    }

    @Test("Returning to a tile restores the arrangement it had")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFocusRestoresArrangement() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        viewModel.zoomLevel = 4
        viewModel.panOffsetY = -30
        viewModel.focusCell(1)
        viewModel.zoomLevel = 2
        viewModel.focusCell(0)

        #expect(viewModel.zoomLevel == 4)
        #expect(viewModel.panOffsetY == -30)
    }

    @Test("Resizing the grid keeps arrangements for tiles that stay")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResizeKeepsArrangements() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.zoomLevel = 6
        viewModel.captureFocusedCell()

        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        #expect(viewModel.cells.count == 4)
        #expect(viewModel.cells[0].filePath == "/a.dcm")
        #expect(viewModel.cells[0].zoom == 6, "the tile kept its arrangement")
    }

    @Test("A tile's viewport size is recorded so its zoom resolves to a crop")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testViewportIsRecordedPerTile() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.setCellViewport(0, width: 400, height: 300)
        viewModel.setCellViewport(1, width: 400, height: 300)

        #expect(viewModel.cells[0].viewportWidth == 400)
        // The focused tile's size is the live viewport, not the whole viewer's.
        #expect(viewModel.viewContentWidth == 400)
        #expect(viewModel.viewContentHeight == 300)
    }

    // MARK: - Marking

    @Test("Tiles start unmarked and are marked individually")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerTileMarking() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        #expect((0..<4).allSatisfy { !viewModel.isCellMarkedForPrint($0) })

        #expect(viewModel.togglePrintMarkForCell(2))
        #expect(viewModel.isCellMarkedForPrint(2))
        #expect(viewModel.isCellMarkedForPrint(1) == false)
        #expect(viewModel.printSelection.count == 1)
        #expect(viewModel.printSelection.items.first?.filePath == "/c.dcm")

        #expect(viewModel.togglePrintMarkForCell(2) == false)
        #expect(viewModel.printSelection.isEmpty)
    }

    @Test("A marked tile carries its own arrangement to the film")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkCarriesTileArrangement() throws {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.setCellViewport(0, width: 400, height: 400)

        viewModel.zoomLevel = 2.5
        viewModel.rotationAngle = 270
        viewModel.togglePrintMarkForCell(0)

        let item = try #require(viewModel.printSelection.items.first)
        let presentation = try #require(item.presentation)
        #expect(presentation.zoom == 2.5)
        #expect(presentation.quarterTurns == 3)
        #expect(presentation.viewportWidth == 400)
    }

    @Test("Marking all tiles fills the film in grid order")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkAllTiles() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        #expect(viewModel.markLayoutForPrint() == 4)
        #expect(viewModel.printSelection.items.map(\.filePath)
                == ["/a.dcm", "/b.dcm", "/c.dcm", "/d.dcm"])
    }

    @Test("Empty tiles contribute no film cells")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkAllSkipsEmptyTiles() {
        let viewModel = seriesViewModel()
        viewModel.currentFileIndex = 4
        viewModel.filePath = "/e.dcm"
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        #expect(viewModel.markLayoutForPrint() == 1)
        #expect(viewModel.printSelection.items.map(\.filePath) == ["/e.dcm"])
    }

    @Test("Select all covers what the layout shows, not the series behind it")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectAllIsLayoutScoped() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        #expect(viewModel.markLayoutForPrint() == 2)
        // /c, /d and /e are in the series but not on screen.
        #expect(viewModel.printSelection.items.map(\.filePath) == ["/a.dcm", "/b.dcm"])
        #expect(viewModel.isLayoutFullyMarkedForPrint)
    }

    @Test("Unselect all clears the images on screen and leaves the rest alone")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUnselectAllIsLayoutScoped() {
        let viewModel = seriesViewModel()
        // A mark taken elsewhere in the study, off screen.
        viewModel.printSelection.add(PrintSelectionItem(filePath: "/z.dcm"))
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.markLayoutForPrint()
        #expect(viewModel.printSelection.count == 3)

        #expect(viewModel.unmarkLayoutForPrint() == 2)
        #expect(viewModel.printSelection.items.map(\.filePath) == ["/z.dcm"])
        #expect(!viewModel.isAnyLayoutImageMarkedForPrint)
    }

    @Test("Nothing is marked until the user asks — select all starts available")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultsToNothingMarked() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        #expect(viewModel.printSelection.isEmpty)
        #expect(!viewModel.isLayoutFullyMarkedForPrint)
        #expect(!viewModel.isAnyLayoutImageMarkedForPrint)
    }

    @Test("At 1×1 the layout is the one image on screen")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectAllAtSingleLayout() {
        let viewModel = seriesViewModel()

        #expect(viewModel.markLayoutForPrint() == 1)
        #expect(viewModel.printSelection.items.map(\.filePath) == ["/a.dcm"])
        #expect(viewModel.isLayoutFullyMarkedForPrint)

        #expect(viewModel.unmarkLayoutForPrint() == 1)
        #expect(viewModel.printSelection.isEmpty)
    }

    @Test("Scrolling the focused tile moves its checkbox onto the new image")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCheckboxFollowsTheImageOnScreen() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.togglePrintMarkForCell(0)
        #expect(viewModel.isCellMarkedForPrint(0))

        // The focused tile steps onto the next image, which is not marked.
        viewModel.currentFileIndex = 2
        viewModel.filePath = "/c.dcm"
        #expect(!viewModel.isCellMarkedForPrint(0), "an unmarked image reads as unticked")

        // Ticking here marks the image now on screen, not the one hung earlier.
        #expect(viewModel.togglePrintMarkForCell(0))
        #expect(viewModel.printSelection.items.map(\.filePath).contains("/c.dcm"))
        #expect(viewModel.isCellMarkedForPrint(0))

        // Stepping back onto the first image finds it still marked.
        viewModel.currentFileIndex = 0
        viewModel.filePath = "/a.dcm"
        #expect(viewModel.isCellMarkedForPrint(0))
    }

    @Test("Capturing a navigated tile records the image it is showing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCaptureFollowsNavigation() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        viewModel.currentFileIndex = 3
        viewModel.filePath = "/d.dcm"
        viewModel.captureFocusedCell()

        #expect(viewModel.cells[0].filePath == "/d.dcm")
        #expect(viewModel.cells[0].fileIndex == 3)
    }

    // MARK: - Grids across series

    private func studyViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "s1", title: "Topogram", seriesNumber: 1,
                              filePaths: ["/s1-a.dcm", "/s1-b.dcm"], frameCount: 2),
            ViewerSeriesEntry(seriesInstanceUID: "s2", title: "Brain 0.80", seriesNumber: 2,
                              filePaths: ["/s2-a.dcm", "/s2-b.dcm", "/s2-c.dcm"], frameCount: 3),
            ViewerSeriesEntry(seriesInstanceUID: "s3", title: "Brain 3.00", seriesNumber: 3,
                              filePaths: ["/s3-a.dcm"], frameCount: 1)
        ], studyUID: "1.2")
        return viewModel
    }

    @Test("A grid hangs the first image of each series, in series order")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGridFillsFromStudySeries() throws {
        let viewModel = studyViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 3))

        #expect(viewModel.cells.map(\.filePath) == ["/s1-a.dcm", "/s2-a.dcm", "/s3-a.dcm"])
        // Each tile navigates its own series, not the one the grid came from.
        #expect(viewModel.cells[1].seriesUID == "s2")
        #expect(viewModel.cells[1].seriesFiles == ["/s2-a.dcm", "/s2-b.dcm", "/s2-c.dcm"])
    }

    @Test("A grid starts from the series on screen, not always the first")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGridStartsFromCurrentSeries() {
        let viewModel = studyViewModel()
        viewModel.selectSeries("s2")
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        #expect(viewModel.cells.map(\.filePath) == ["/s2-a.dcm", "/s3-a.dcm"])
    }

    @Test("More tiles than series falls back to the current stack rather than blanks")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGridFallsBackToTheStack() {
        let viewModel = studyViewModel()
        viewModel.selectSeries("s2")
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))

        let paths = viewModel.cells.map(\.filePath)
        #expect(paths[0] == "/s2-a.dcm")
        #expect(paths[1] == "/s3-a.dcm")
        // Beyond the last series, the tiles continue through the open stack.
        #expect(paths[2] != nil)
        #expect(!viewModel.cells[2].isEmpty)
    }

    @Test("Loose files with no study still fill a grid from the open series")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGridWithoutAStudy() {
        let viewModel = seriesViewModel()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 3))

        #expect(viewModel.cells.map(\.filePath) == ["/a.dcm", "/b.dcm", "/c.dcm"])
    }

    // MARK: - Series selection

    @Test("A study with nothing on screen opens on its first series")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFirstSeriesSelectedByDefault() {
        let viewModel = ImageViewerViewModel()
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "1.2.1", title: "Scout", seriesNumber: 1,
                              filePaths: ["/s1-a.dcm", "/s1-b.dcm"], frameCount: 2),
            ViewerSeriesEntry(seriesInstanceUID: "1.2.2", title: "Axial", seriesNumber: 2,
                              filePaths: ["/s2-a.dcm"], frameCount: 1)
        ], studyUID: "1.2")

        #expect(viewModel.currentSeriesUID == "1.2.1")
        #expect(viewModel.seriesFiles == ["/s1-a.dcm", "/s1-b.dcm"])
        #expect(viewModel.currentFileIndex == 0, "the series opens at its first image")
    }

    @Test("A viewer already showing an image is not taken over by the pane")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testExistingImageIsNotReplaced() {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/opened-by-the-user.dcm"

        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "1.2.1", title: "Scout",
                              filePaths: ["/s1-a.dcm"], frameCount: 1)
        ], studyUID: "1.2")

        #expect(viewModel.filePath == "/opened-by-the-user.dcm")
    }

    @Test("The pane lists series in Series Number order, whatever order they arrive in")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSeriesSortedBySeriesNumber() {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/other.dcm"
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "c", title: "Delayed", seriesNumber: 10,
                              filePaths: ["/c.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "a", title: "Scout", seriesNumber: 2,
                              filePaths: ["/a.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "d", title: "Unnumbered",
                              filePaths: ["/d.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "b", title: "Axial", seriesNumber: 3,
                              filePaths: ["/b.dcm"], frameCount: 1)
        ], studyUID: "1.2")

        #expect(viewModel.studySeries.map(\.seriesInstanceUID) == ["a", "b", "c", "d"],
                "ascending Series Number, unnumbered last — not the order given")
    }

    @Test("A study opening on its first series takes the lowest Series Number")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultSelectionFollowsSeriesNumber() {
        let viewModel = ImageViewerViewModel()
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "later", title: "Axial", seriesNumber: 4,
                              filePaths: ["/later.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "first", title: "Scout", seriesNumber: 1,
                              filePaths: ["/first.dcm"], frameCount: 1)
        ], studyUID: "1.2")

        #expect(viewModel.currentSeriesUID == "first")
    }

    @Test("Selecting a series shows it from its first image")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectSeries() {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/other.dcm"
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "1.2.1", title: "Scout", seriesNumber: 1,
                              filePaths: ["/s1-a.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "1.2.2", title: "Axial", seriesNumber: 2,
                              filePaths: ["/s2-a.dcm", "/s2-b.dcm"], frameCount: 2)
        ], studyUID: "1.2")

        #expect(viewModel.selectSeries("1.2.2"))
        #expect(viewModel.currentSeriesUID == "1.2.2")
        #expect(viewModel.seriesFiles == ["/s2-a.dcm", "/s2-b.dcm"])
        #expect(viewModel.currentFileIndex == 0)
    }

    // MARK: - Repeat navigation

    @Test("Stepping past the last image wraps round to the first")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRepeatWrapsForward() {
        let viewModel = seriesViewModel()
        viewModel.currentFileIndex = 4
        viewModel.filePath = "/e.dcm"
        #expect(!viewModel.canGoNextImage)

        #expect(viewModel.navigateToNextImage())
        #expect(viewModel.currentFileIndex == 0)
    }

    @Test("Stepping back from the first image wraps round to the last")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRepeatWrapsBackward() {
        let viewModel = seriesViewModel()
        #expect(!viewModel.canGoPreviousImage)

        #expect(viewModel.navigateToPreviousImage())
        #expect(viewModel.currentFileIndex == 4)
    }

    @Test("With repeat off, the ends of the series are the ends")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRepeatDisabledStops() {
        let viewModel = seriesViewModel()
        viewModel.isRepeatNavigationEnabled = false

        #expect(!viewModel.navigateToPreviousImage())
        #expect(viewModel.currentFileIndex == 0)

        viewModel.currentFileIndex = 4
        viewModel.filePath = "/e.dcm"
        #expect(!viewModel.navigateToNextImage())
        #expect(viewModel.currentFileIndex == 4)
    }
}

@MainActor
@Suite("Film Mirrors Viewer Grid Tests")
struct FilmMirrorsViewerGridTests {

    @Test("The film layout can be any viewer grid, including ones the catalogue omits")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCustomLayoutMirrorsViewer() throws {
        let viewModel = PrintViewModel()
        // 1×3 has no PrintLayoutOption case; the viewer still offers it.
        viewModel.viewerLayout = PrintLayout(rows: 1, columns: 3)
        viewModel.layoutMode = .matchViewer

        let layout = try #require(viewModel.request.layoutSelection.layout)
        #expect(layout.rows == 1)
        #expect(layout.columns == 3)
    }

    @Test("Without a viewer grid, matching falls back to automatic")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFallsBackToAutomatic() {
        let viewModel = PrintViewModel()
        viewModel.viewerLayout = nil
        viewModel.layoutMode = .matchViewer

        #expect(viewModel.request.layoutSelection.layout == nil)
    }
}

@MainActor
@Suite("Preview Matches Viewer Tests")
struct PreviewMatchesViewerTests {

    private func gridViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        viewModel.seriesFiles = ["/a.dcm", "/b.dcm", "/c.dcm", "/d.dcm"]
        viewModel.filePath = "/a.dcm"
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))
        for index in 0..<4 {
            viewModel.setCellViewport(index, width: 400, height: 400)
        }
        return viewModel
    }

    @Test("Arranging a tile after ticking it updates what will print")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkFollowsLaterArrangement() throws {
        let viewModel = gridViewModel()
        viewModel.togglePrintMarkForCell(0)
        #expect(viewModel.printSelection.items.first?.presentation?.zoom == 1)

        // The user carries on zooming the tile they already ticked.
        viewModel.zoomLevel = 3.5
        viewModel.rotationAngle = 90
        viewModel.refreshMarksFromViewer()

        let item = try #require(viewModel.printSelection.items.first)
        #expect(item.presentation?.zoom == 3.5)
        #expect(item.presentation?.quarterTurns == 1)
    }

    @Test("Refreshing keeps film order and adds nothing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRefreshPreservesOrderAndCount() {
        let viewModel = gridViewModel()
        viewModel.togglePrintMarkForCell(2)
        viewModel.togglePrintMarkForCell(1)
        #expect(viewModel.printSelection.items.map(\.filePath) == ["/c.dcm", "/b.dcm"])

        viewModel.zoomLevel = 2
        viewModel.refreshMarksFromViewer()

        #expect(viewModel.printSelection.count == 2, "refresh must not mark anything new")
        #expect(viewModel.printSelection.items.map(\.filePath) == ["/c.dcm", "/b.dcm"])
    }

    @Test("At 1×1 the same refresh keeps the single mark current")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRefreshAtSingleLayout() throws {
        let viewModel = ImageViewerViewModel()
        viewModel.filePath = "/a.dcm"
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 800
        viewModel.togglePrintMarkForCurrentFrame()

        viewModel.zoomLevel = 2.5
        viewModel.refreshMarksFromViewer()

        let item = try #require(viewModel.printSelection.items.first)
        #expect(item.presentation?.zoom == 2.5)
        #expect(viewModel.printSelection.count == 1)
    }

    @Test("Updating an unmarked frame does nothing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateOnlyTouchesMarkedFrames() {
        let selection = PrintSelectionModel()
        #expect(selection.update(PrintSelectionItem(filePath: "/a.dcm")) == false)
        #expect(selection.isEmpty)
    }
}
