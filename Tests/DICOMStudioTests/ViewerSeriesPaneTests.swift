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
        #expect(entries.map(\.title) == ["Topogram", "THIN LUNG"])
        #expect(entries[1].filePaths == ["/lung1.dcm", "/lung2.dcm"])
        #expect(entries[1].objectCount == 2)
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
