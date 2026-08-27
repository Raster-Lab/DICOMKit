// SeriesToolCacheTests.swift
// DICOMStudioTests
//
// The series-wide tool memory: every tool the toolbar offers — window, zoom,
// pan, rotation, the flips, inversion, the palette — holds across the slices
// of a series, swaps when the reader steps to another series, comes back when
// they return, and ends when the arrangement is saved as a presentation
// state, reset, or the study closes. The drawn annotations stay per image.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Series Tool Cache Tests")
struct SeriesToolCacheTests {

    // MARK: - Fixtures

    private static let studyUID = "1.2.3.4.5"
    private static let seriesAUID = "1.2.3.4.5.6"
    private static let seriesBUID = "1.2.3.4.5.7"
    private static let ctSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    private struct Fixture {
        let viewModel: ImageViewerViewModel
        let root: URL
        /// Two slices of series A, then two of series B.
        let a1: String
        let a2: String
        let b1: String
        let b2: String
    }

    private func writeImageFile(
        sopInstanceUID: String, seriesInstanceUID: String,
        windowCenter: String, to url: URL
    ) throws {
        let elements: [DataElement] = [
            .string(tag: .sopClassUID, vr: .UI, value: Self.ctSOPClass),
            .string(tag: .sopInstanceUID, vr: .UI, value: sopInstanceUID),
            .string(tag: .studyInstanceUID, vr: .UI, value: Self.studyUID),
            .string(tag: .seriesInstanceUID, vr: .UI, value: seriesInstanceUID),
            .string(tag: .patientName, vr: .PN, value: "DOE^JANE"),
            .string(tag: .patientID, vr: .LO, value: "12345"),
            .uint16(tag: .rows, value: 16),
            .uint16(tag: .columns, value: 16),
            .string(tag: .windowCenter, vr: .DS, value: windowCenter),
            .string(tag: .windowWidth, vr: .DS, value: "400")
        ]
        let file = DICOMFile.create(
            dataSet: DataSet(elements: elements),
            sopClassUID: Self.ctSOPClass,
            sopInstanceUID: sopInstanceUID)
        try file.write().write(to: url, options: [.atomic])
    }

    /// Four real files on disk: A1 and A2 in one series, B1 and B2 in another.
    /// A's slices ask for a window of 40, B's for 80 — so a test can tell a
    /// restored window from a file's own.
    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeriesToolCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)

        var paths: [String: String] = [:]
        for (name, series, center) in [
            ("a1", Self.seriesAUID, "40"), ("a2", Self.seriesAUID, "40"),
            ("b1", Self.seriesBUID, "80"), ("b2", Self.seriesBUID, "80")
        ] {
            let url = root.appendingPathComponent("\(name).dcm")
            try writeImageFile(
                sopInstanceUID: "\(series).\(name)", seriesInstanceUID: series,
                windowCenter: center, to: url)
            paths[name] = url.path
        }

        let viewModel = ImageViewerViewModel()
        viewModel.studyInstanceUID = Self.studyUID
        return Fixture(
            viewModel: viewModel, root: root,
            a1: paths["a1"]!, a2: paths["a2"]!, b1: paths["b1"]!, b2: paths["b2"]!)
    }

    private func cleanUp(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    private var somePalette: DICOMCore.PseudoColorPalette {
        DICOMCore.PseudoColorPalette.catalog.first!.palettes.first!
    }

    // MARK: - Within a series

    @Test("Tool actions hold across the slices of a series")
    func toolsHoldAcrossSlices() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        vm.loadFile(at: fixture.a1)
        vm.zoomLevel = 2.5
        vm.panOffsetX = 30
        vm.panOffsetY = -12
        vm.rotationAngle = 90
        vm.flipHorizontal()
        vm.toggleInversion()
        vm.applyPalette(somePalette)
        vm.windowCenter = 300
        vm.windowWidth = 1500

        vm.loadFile(at: fixture.a2)

        #expect(vm.zoomLevel == 2.5)
        #expect(vm.panOffsetX == 30)
        #expect(vm.panOffsetY == -12)
        #expect(vm.rotationAngle == 90)
        #expect(vm.isFlippedHorizontal)
        #expect(vm.isInverted)
        #expect(vm.palette == somePalette)
        #expect(vm.windowCenter == 300)
        #expect(vm.windowWidth == 1500)
    }

    @Test("An untouched window follows each file's own header")
    func untouchedWindowStaysPerFile() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        vm.loadFile(at: fixture.a1)
        vm.zoomLevel = 3.0 // a tool action, but not a windowing one

        vm.loadFile(at: fixture.b1)
        // B's own header window, not A's.
        #expect(vm.windowCenter == 80)
        #expect(vm.zoomLevel == 1.0) // and B starts unarranged
    }

    // MARK: - Across series

    @Test("Another series starts at its own defaults, and the arrangement comes back")
    func seriesSwapAndReturn() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        vm.loadFile(at: fixture.a1)
        vm.zoomLevel = 2.0
        vm.flipVertical()
        vm.applyPalette(somePalette)

        vm.loadFile(at: fixture.b1)
        #expect(vm.zoomLevel == 1.0)
        #expect(vm.isFlippedVertical == false)
        #expect(vm.palette == nil)

        // B gets its own arrangement…
        vm.rotationAngle = 180

        // …and returning to A restores A's, not B's.
        vm.loadFile(at: fixture.a2)
        #expect(vm.zoomLevel == 2.0)
        #expect(vm.isFlippedVertical)
        #expect(vm.palette == somePalette)
        #expect(vm.rotationAngle == 0)

        // And B's is still waiting for it too.
        vm.loadFile(at: fixture.b2)
        #expect(vm.rotationAngle == 180)
        #expect(vm.zoomLevel == 1.0)
    }

    // MARK: - Where the memory ends

    @Test("Reset clears the tools, the drawings, and the series' memory")
    func resetClearsEverything() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        vm.loadFile(at: fixture.a1)
        vm.zoomLevel = 2.5
        vm.applyPalette(somePalette)
        vm.addDrawnAnnotation(at: PrintOverlayPoint(x: 0.5, y: 0.5))
        vm.setDrawnAnnotationText("lesion", id: vm.currentDrawnAnnotations[0].id)
        #expect(!vm.currentDrawnAnnotations.isEmpty)

        vm.resetView()

        #expect(vm.zoomLevel == 1.0)
        #expect(vm.palette == nil)
        #expect(vm.currentDrawnAnnotations.isEmpty)

        // Stepping away and back does not resurrect the arrangement.
        vm.loadFile(at: fixture.b1)
        vm.loadFile(at: fixture.a1)
        #expect(vm.zoomLevel == 1.0)
        #expect(vm.palette == nil)
    }

    @Test("Saving the arrangement as a presentation state ends the memory")
    func savingEndsTheMemory() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel
        vm.presentationStateStore = PresentationStateStore(
            root: fixture.root.appendingPathComponent("store", isDirectory: true))

        vm.loadFile(at: fixture.a1)
        vm.zoomLevel = 2.5
        #expect(vm.saveCurrentView(label: "Reading view"))

        // The saved view is what stands now; the unsaved cache is gone, so the
        // next slice arrives as its file describes it (its own standing choice,
        // if any, is the saved-view machinery's business, not the cache's).
        #expect(vm.toolStateBySeries.isEmpty)
        #expect(vm.toolsTouchedInSeries == false)
    }

    @Test("Annotations stay with their image, not the series")
    func annotationsStayPerImage() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        vm.loadFile(at: fixture.a1)
        vm.addDrawnAnnotation(at: PrintOverlayPoint(x: 0.4, y: 0.4))
        vm.setDrawnAnnotationText("here", id: vm.currentDrawnAnnotations[0].id)

        vm.loadFile(at: fixture.a2)
        #expect(vm.currentDrawnAnnotations.isEmpty)

        vm.loadFile(at: fixture.a1)
        #expect(vm.currentDrawnAnnotations.count == 1)
        #expect(vm.currentDrawnAnnotations[0].text == "here")
    }

    // MARK: - The series pane's own workflow

    /// A card click, not a file open: the pane hangs series through
    /// `selectSeries` → `assignSeriesToFocusedCell`, which is a different path
    /// from `loadFile` — the one that used to wipe the restored arrangement
    /// with a trailing `resetTransformations()`.
    @Test("Rotation survives a series-pane round trip (1×1)")
    func paneRoundTripRestoresTools() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        let entryA = ViewerSeriesEntry(
            seriesInstanceUID: Self.seriesAUID, title: "A",
            filePaths: [fixture.a1, fixture.a2], frameCount: 2)
        let entryB = ViewerSeriesEntry(
            seriesInstanceUID: Self.seriesBUID, title: "B",
            filePaths: [fixture.b1, fixture.b2], frameCount: 2)
        vm.loadStudySeries([entryA, entryB], studyUID: Self.studyUID)

        #expect(vm.selectSeries(Self.seriesAUID))
        vm.rotationAngle = 90
        vm.zoomLevel = 2.0

        #expect(vm.selectSeries(Self.seriesBUID))
        #expect(vm.rotationAngle == 0)
        #expect(vm.zoomLevel == 1.0)

        #expect(vm.selectSeries(Self.seriesAUID))
        #expect(vm.rotationAngle == 90)
        #expect(vm.zoomLevel == 2.0)
    }

    @Test("A tile re-hung with a series shows its cached arrangement (grid)")
    func gridTileAdoptsCachedArrangement() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        let entryA = ViewerSeriesEntry(
            seriesInstanceUID: Self.seriesAUID, title: "A",
            filePaths: [fixture.a1, fixture.a2], frameCount: 2)
        let entryB = ViewerSeriesEntry(
            seriesInstanceUID: Self.seriesBUID, title: "B",
            filePaths: [fixture.b1, fixture.b2], frameCount: 2)
        vm.loadStudySeries([entryA, entryB], studyUID: Self.studyUID)
        vm.applyLayout(ViewerTileLayout(rows: 1, columns: 2))

        #expect(vm.assignSeries(Self.seriesAUID, toCell: 0))
        vm.rotationAngle = 90
        vm.flipHorizontal()

        // The same tile hung with B, then with A again.
        #expect(vm.assignSeries(Self.seriesBUID, toCell: 0))
        #expect(vm.rotationAngle == 0)
        #expect(vm.assignSeries(Self.seriesAUID, toCell: 0))

        #expect(vm.rotationAngle == 90)
        #expect(vm.isFlippedHorizontal)
        #expect(vm.cells[0].rotationAngle == 90)
    }

    @Test("A new study drops every series' memory")
    func newStudyClearsTheCache() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture.root) }
        let vm = fixture.viewModel

        vm.loadFile(at: fixture.a1)
        vm.zoomLevel = 2.5
        vm.loadFile(at: fixture.b1) // A's arrangement is now cached

        vm.prepareForNewStudy()

        #expect(vm.toolStateBySeries.isEmpty)
        vm.loadFile(at: fixture.a2)
        #expect(vm.zoomLevel == 1.0)
    }
}
