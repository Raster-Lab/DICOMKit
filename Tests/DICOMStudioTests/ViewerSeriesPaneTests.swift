// ViewerSeriesPaneTests.swift
// DICOMStudioTests
//
// The viewer's series pane: what it lists, and hanging a series in a tile by
// drag or double-click.

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Viewer Series Entry Tests")
struct ViewerSeriesEntryTests {

    @Test("Counts distinguish objects from frames")
    func testCountsLabel() {
        // A cine: one object, many frames.
        let cine = ViewerSeriesEntry(
            seriesInstanceUID: "1.1", title: "ThorHR",
            filePaths: ["/a.dcm"], frameCount: 358)
        #expect(cine.countsLabel == "1 object, 358 frames")

        // A stack: many objects, one frame each.
        let stack = ViewerSeriesEntry(
            seriesInstanceUID: "1.2", title: "THIN LUNG",
            filePaths: (0..<715).map { "/\($0).dcm" }, frameCount: 715)
        #expect(stack.countsLabel == "715 objects, 715 frames")
    }

    @Test("The card shows the series number, and omits it when there is none")
    func testSeriesNumberLabel() {
        let numbered = ViewerSeriesEntry(
            seriesInstanceUID: "1.1", title: "THIN LUNG",
            seriesNumber: 4, filePaths: ["/a.dcm"], frameCount: 1)
        #expect(numbered.seriesNumberLabel == "4")
        #expect(numbered.spokenLabel == "Series 4, THIN LUNG")

        let unnumbered = ViewerSeriesEntry(
            seriesInstanceUID: "1.2", title: "Patient Protocol",
            filePaths: ["/a.dcm"], frameCount: 1)
        #expect(unnumbered.seriesNumberLabel == nil)
        #expect(unnumbered.spokenLabel == "Patient Protocol")
    }

    @Test("An unknown orientation says so rather than being left blank")
    func testOrientationLabel() {
        let entry = ViewerSeriesEntry(
            seriesInstanceUID: "1.1", title: "Patient Protocol",
            filePaths: ["/a.dcm"], frameCount: 1)
        #expect(entry.orientationLabel == "Orientation Unavailable")

        let axial = ViewerSeriesEntry(
            seriesInstanceUID: "1.2", title: "THIN LUNG",
            orientation: "Axial", filePaths: ["/a.dcm"], frameCount: 1)
        #expect(axial.orientationLabel == "Axial")
    }
}

@Suite("Viewer Series Catalog Tests")
struct ViewerSeriesCatalogTests {

    /// A library with one study of two series.
    private func library() -> LibraryModel {
        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: "study-1"))
        library.addSeries(SeriesModel(
            seriesInstanceUID: "series-2", studyInstanceUID: "study-1",
            seriesNumber: 2, modality: "CT", seriesDescription: "THIN LUNG"))
        library.addSeries(SeriesModel(
            seriesInstanceUID: "series-1", studyInstanceUID: "study-1",
            seriesNumber: 1, modality: "CT", seriesDescription: "Topogram"))
        library.addInstance(InstanceModel(
            sopInstanceUID: "i-1", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "series-1", instanceNumber: 1, filePath: "/topo.dcm"))
        library.addInstance(InstanceModel(
            sopInstanceUID: "i-2", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "series-2", instanceNumber: 1, filePath: "/lung1.dcm"))
        library.addInstance(InstanceModel(
            sopInstanceUID: "i-3", sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "series-2", instanceNumber: 2, filePath: "/lung2.dcm"))
        return library
    }

    @Test("Entries list the study's series in series-number order")
    func testEntriesOrdered() {
        let entries = ViewerSeriesCatalog.entries(forStudy: "study-1", in: library())
        #expect(entries.map(\.seriesNumber) == [1, 2])
        #expect(entries.map(\.title) == ["Topogram", "THIN LUNG"])
        #expect(entries[1].filePaths == ["/lung1.dcm", "/lung2.dcm"])
        #expect(entries[1].objectCount == 2)
    }

    @Test("Series numbers order numerically, not as text")
    func testNumericOrdering() {
        var model = LibraryModel()
        model.addStudy(StudyModel(studyInstanceUID: "s"))
        for number in [10, 2, 1, 20] {
            model.addSeries(SeriesModel(
                seriesInstanceUID: "u\(number)", studyInstanceUID: "s",
                seriesNumber: number, modality: "CT",
                seriesDescription: "Series \(number)"))
        }
        let entries = ViewerSeriesCatalog.entries(forStudy: "s", in: model)
        #expect(entries.map(\.seriesNumber) == [1, 2, 10, 20])
    }

    @Test("Unnumbered series sort last, not ahead of series 1")
    func testUnnumberedSeriesSortLast() {
        var model = LibraryModel()
        model.addStudy(StudyModel(studyInstanceUID: "s"))
        model.addSeries(SeriesModel(
            seriesInstanceUID: "u-none", studyInstanceUID: "s",
            modality: "CT", seriesDescription: "Unnumbered"))
        model.addSeries(SeriesModel(
            seriesInstanceUID: "u-1", studyInstanceUID: "s",
            seriesNumber: 1, modality: "CT", seriesDescription: "First"))

        let entries = ViewerSeriesCatalog.entries(forStudy: "s", in: model)
        #expect(entries.map(\.title) == ["First", "Unnumbered"])
    }

    @Test("Series sharing a number keep a stable order")
    func testTiedNumbersAreStable() {
        var model = LibraryModel()
        model.addStudy(StudyModel(studyInstanceUID: "s"))
        model.addSeries(SeriesModel(
            seriesInstanceUID: "u-b", studyInstanceUID: "s",
            seriesNumber: 3, modality: "CT", seriesDescription: "Beta"))
        model.addSeries(SeriesModel(
            seriesInstanceUID: "u-a", studyInstanceUID: "s",
            seriesNumber: 3, modality: "CT", seriesDescription: "Alpha"))

        // A study can repeat a Series Number; the pane must not reshuffle
        // between reads, so ties fall back to title.
        let first = ViewerSeriesCatalog.entries(forStudy: "s", in: model).map(\.title)
        let second = ViewerSeriesCatalog.entries(forStudy: "s", in: model).map(\.title)
        #expect(first == ["Alpha", "Beta"])
        #expect(first == second)
    }

    @Test("Resolving orientations preserves the pane's order")
    func testOrientationRefinementKeepsOrder() async {
        let entries = ViewerSeriesCatalog.entries(forStudy: "study-1", in: library())
        let resolved = await ViewerSeriesCatalog.resolvingOrientations(entries)
        #expect(resolved.map(\.seriesInstanceUID) == entries.map(\.seriesInstanceUID))
    }

    @Test("A series with no description still gets a usable title")
    func testTitleFallback() {
        var model = LibraryModel()
        model.addStudy(StudyModel(studyInstanceUID: "s"))
        model.addSeries(SeriesModel(
            seriesInstanceUID: "u", studyInstanceUID: "s",
            seriesNumber: 7, modality: "MR"))
        #expect(ViewerSeriesCatalog.entries(forStudy: "s", in: model).first?.title
                == "MR series 7")
    }

    @Test("A file resolves back to its study")
    func testStudyLookup() {
        #expect(ViewerSeriesCatalog.studyUID(containing: "/lung2.dcm", in: library()) == "study-1")
        #expect(ViewerSeriesCatalog.studyUID(containing: "/nope.dcm", in: library()) == nil)
    }

    @Test("Multi-frame instances count frames, not just objects")
    func testFrameCounts() {
        var model = LibraryModel()
        model.addStudy(StudyModel(studyInstanceUID: "s"))
        model.addSeries(SeriesModel(seriesInstanceUID: "u", studyInstanceUID: "s"))
        model.addInstance(InstanceModel(
            sopInstanceUID: "i", sopClassUID: "c", seriesInstanceUID: "u",
            filePath: "/cine.dcm", numberOfFrames: 358))

        let entry = ViewerSeriesCatalog.entries(forStudy: "s", in: model).first
        #expect(entry?.objectCount == 1)
        #expect(entry?.frameCount == 358)
    }
}

@MainActor
@Suite("Hanging Series In Tiles Tests")
struct HangingSeriesInTilesTests {

    private let topogram = ViewerSeriesEntry(
        seriesInstanceUID: "series-1", title: "Topogram",
        filePaths: ["/topo.dcm"], frameCount: 1)

    private let lung = ViewerSeriesEntry(
        seriesInstanceUID: "series-2", title: "THIN LUNG",
        filePaths: ["/lung1.dcm", "/lung2.dcm", "/lung3.dcm"], frameCount: 3)

    private func viewerWithSeries() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        // The shell loads the series first, then fills the pane — the pane needs
        // a loaded file to know which series is the current one.
        viewModel.seriesFiles = topogram.filePaths
        viewModel.filePath = "/topo.dcm"
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.loadStudySeries([topogram, lung], studyUID: "study-1")
        return viewModel
    }

    @Test("The pane lists the study's series and marks the one on screen")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPaneContents() {
        let viewModel = viewerWithSeries()
        #expect(viewModel.studySeries.count == 2)
        #expect(viewModel.isCurrentSeries("series-1"))
        #expect(viewModel.isSeriesVisited("series-1"))
        // Nothing else has been looked at yet.
        #expect(viewModel.isSeriesVisited("series-2") == false)
    }

    @Test("Dropping a series on a tile hangs it there")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAssignSeriesToTile() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        #expect(viewModel.assignSeries("series-2", toCell: 1))
        #expect(viewModel.cells[1].seriesUID == "series-2")
        #expect(viewModel.cells[1].filePath == "/lung1.dcm")
        #expect(viewModel.cells[1].seriesFiles == lung.filePaths)
        #expect(viewModel.isSeriesVisited("series-2"))
        // The other tile is untouched.
        #expect(viewModel.cells[0].filePath == "/topo.dcm")
    }

    @Test("A tile hung with a new series starts from a clean arrangement")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAssignResetsArrangement() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.setCellViewport(1, width: 400, height: 600)

        // Arrange tile 1, then hang something else in it.
        viewModel.focusCell(1)
        viewModel.zoomLevel = 4
        viewModel.rotationAngle = 90
        viewModel.captureFocusedCell()

        viewModel.assignSeries("series-2", toCell: 1)

        #expect(viewModel.cells[1].zoom == 1, "a crop composed for another series is meaningless")
        #expect(viewModel.cells[1].rotationAngle == 0)
        // The tile keeps the space it occupies, so its zoom still resolves.
        #expect(viewModel.cells[1].viewportWidth == 400)
        #expect(viewModel.cells[1].viewportHeight == 600)
    }

    @Test("A newly hung tile has no window of its own, so the image keeps its VOI")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAssignLeavesWindowToTheImage() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        viewModel.assignSeries("series-2", toCell: 1)

        #expect(viewModel.cells[1].windowCenter == nil,
                "a hung series has never been windowed by the user")
        #expect(viewModel.cells[1].windowWidth == nil)
    }

    @Test("Focusing a tile that was never windowed does not impose a stock window")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testWindowlessTileKeepsTheLoadedImageWindow() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.assignSeries("series-2", toCell: 1)

        // Stand in for the window the loaded file's VOI produces — a lung window,
        // nothing like the 128/256 a blank tile used to carry.
        viewModel.windowCenter = -600
        viewModel.windowWidth = 1600

        viewModel.focusCell(1)

        #expect(viewModel.windowCenter == -600)
        #expect(viewModel.windowWidth == 1600)
    }

    @Test("Filling a grid does not stamp one series' window on another's images")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testWindowDoesNotTravelAcrossSeries() {
        let viewModel = viewerWithSeries()
        // A grid drawn from a flat file list — a folder of a whole study — runs
        // off the end of one series and into the next.
        viewModel.seriesFiles = topogram.filePaths + lung.filePaths
        viewModel.filePath = "/topo.dcm"
        viewModel.windowCenter = 424
        viewModel.windowWidth = 1200

        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 4))

        #expect(viewModel.cells[0].windowCenter == 424, "the current image's own window stays put")
        for index in 1..<4 {
            #expect(viewModel.cells[index].windowCenter == nil,
                    "tile \(index) shows another series — its rescale pair may differ entirely")
            #expect(viewModel.cells[index].windowWidth == nil)
        }
    }

    @Test("Within one series the user's window follows across the grid")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testWindowTravelsWithinASeries() {
        // A grid hangs one series per tile until the study runs out of series;
        // past that the tiles continue through the open stack, and those slices
        // share its rescale pair — so the user's window travels with them. Here
        // the study is a single series, so every tile is one of its slices.
        let viewModel = ImageViewerViewModel()
        viewModel.seriesFiles = lung.filePaths
        viewModel.filePath = "/lung1.dcm"
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.loadStudySeries([lung], studyUID: "study-1")
        viewModel.windowCenter = 7577
        viewModel.windowWidth = 1160

        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 3))
        #expect(viewModel.cells.map(\.filePath)
                == ["/lung1.dcm", "/lung2.dcm", "/lung3.dcm"])

        for index in 0..<3 {
            #expect(viewModel.cells[index].windowCenter == 7577,
                    "slices of one series share a rescale pair, so the adjustment carries")
            #expect(viewModel.cells[index].windowWidth == 1160)
        }
    }

    @Test("Double-clicking hangs the series in the selected tile")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAssignToFocusedCell() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))
        viewModel.focusCell(3)

        #expect(viewModel.assignSeriesToFocusedCell("series-2"))
        #expect(viewModel.cells[3].seriesUID == "series-2")
        #expect(viewModel.cells[0].seriesUID != "series-2")
    }

    @Test("The focused tile owns navigation, so it walks its own series")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFocusedTileOwnsNavigation() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))
        viewModel.assignSeries("series-2", toCell: 1)
        viewModel.focusCell(1)

        #expect(viewModel.seriesFiles == lung.filePaths)
        #expect(viewModel.currentSeriesUID == "series-2")

        // Going back to tile 0 restores the topogram's (single-file) list.
        viewModel.focusCell(0)
        #expect(viewModel.seriesFiles == topogram.filePaths)
        #expect(viewModel.currentSeriesUID == "series-1")
    }

    @Test("An unknown series is refused rather than blanking the tile")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUnknownSeriesIsRefused() {
        let viewModel = viewerWithSeries()
        viewModel.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        #expect(viewModel.assignSeries("nope", toCell: 1) == false)
        #expect(viewModel.cells[1].filePath != nil || viewModel.cells[1].isEmpty)
    }

    @Test("At 1×1 a dropped series replaces what the viewer is showing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAssignAtSingleLayout() {
        let viewModel = viewerWithSeries()
        #expect(viewModel.cells.isEmpty)

        #expect(viewModel.assignSeries("series-2", toCell: 0))
        #expect(viewModel.seriesFiles == lung.filePaths)
        #expect(viewModel.currentSeriesUID == "series-2")
        #expect(viewModel.zoomLevel == 1)
    }
}
