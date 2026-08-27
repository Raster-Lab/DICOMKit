// SavedViewPaletteFrameTests.swift
// DICOMStudioTests
//
// The viewer's half of frames and colour in saved views.
//
// Two asymmetries these pin shut. The palette used to be cleared by the
// default view but never captured by a save — so a coloured view came back
// grey, silently. And a series save read other images' drawings at frame 0
// only, so an arrow on any later frame of a multi-frame image vanished from
// the view that claimed to record it.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Saved View Palette And Frame Tests")
struct SavedViewPaletteFrameTests {

    // MARK: - Fixtures

    private static let studyUID = "1.2.3.4.5"
    private static let seriesUID = "1.2.3.4.5.6"
    private static let ctSOPClass = "1.2.840.10008.5.1.4.1.1.2"
    private static let sop1 = "1.2.3.4.5.6.1"
    private static let sop2 = "1.2.3.4.5.6.2"

    private struct Fixture {
        let viewModel: ImageViewerViewModel
        let root: URL
        let store: PresentationStateStore
        let paths: [String]
    }

    private func writeImageFile(
        sopInstanceUID: String, to url: URL
    ) throws -> DICOMFile {
        let elements: [DataElement] = [
            .string(tag: .sopClassUID, vr: .UI, value: Self.ctSOPClass),
            .string(tag: .sopInstanceUID, vr: .UI, value: sopInstanceUID),
            .string(tag: .studyInstanceUID, vr: .UI, value: Self.studyUID),
            .string(tag: .seriesInstanceUID, vr: .UI, value: Self.seriesUID),
            .string(tag: .patientName, vr: .PN, value: "DOE^JANE"),
            .string(tag: .patientID, vr: .LO, value: "12345"),
            .uint16(tag: .rows, value: 512),
            .uint16(tag: .columns, value: 512),
            .string(tag: .windowCenter, vr: .DS, value: "40"),
            .string(tag: .windowWidth, vr: .DS, value: "400")
        ]
        let file = DICOMFile.create(
            dataSet: DataSet(elements: elements),
            sopClassUID: Self.ctSOPClass,
            sopInstanceUID: sopInstanceUID)
        try file.write().write(to: url, options: [.atomic])
        return file
    }

    /// A viewer on the first of two images of one series, all real files.
    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedViewPaletteFrameTests-\(UUID().uuidString)")
        let studyDirectory = root.appendingPathComponent("study", isDirectory: true)
        try FileManager.default.createDirectory(
            at: studyDirectory, withIntermediateDirectories: true)

        var paths: [String] = []
        var firstFile: DICOMFile?
        for sop in [Self.sop1, Self.sop2] {
            let url = studyDirectory.appendingPathComponent("\(sop).dcm")
            let file = try writeImageFile(sopInstanceUID: sop, to: url)
            if sop == Self.sop1 { firstFile = file }
            paths.append(url.path)
        }

        let store = PresentationStateStore(
            root: root.appendingPathComponent("store", isDirectory: true))

        let viewModel = ImageViewerViewModel()
        viewModel.dicomFile = firstFile
        viewModel.filePath = paths[0]
        viewModel.sopInstanceUID = Self.sop1
        viewModel.studyInstanceUID = Self.studyUID
        viewModel.currentSeriesUID = Self.seriesUID
        viewModel.imageColumns = 512
        viewModel.imageRows = 512
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.presentationStateStore = store
        viewModel.studySeries = [
            ViewerSeriesEntry(
                seriesInstanceUID: Self.seriesUID, title: "Axial",
                seriesNumber: 1, modality: "CT",
                filePaths: paths, frameCount: 2)
        ]

        return Fixture(viewModel: viewModel, root: root, store: store, paths: paths)
    }

    private func cleanUp(_ fixture: Fixture) {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    private func arrow() -> PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.3),
            end: PrintOverlayPoint(x: 0.6, y: 0.7))
    }

    // MARK: - Palette

    @Test("A coloured but otherwise untouched image is worth saving")
    func colourAloneOffersTheSave() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // At the file's own window, so the baseline really is untouched.
        fixture.viewModel.windowCenter = 40
        fixture.viewModel.windowWidth = 400

        #expect(fixture.viewModel.canSaveCurrentView == false)
        fixture.viewModel.applyPalette(.hotIron)
        #expect(fixture.viewModel.canSaveCurrentView)
    }

    @Test("The palette is part of the view: cleared by default, restored by apply")
    func paletteRoundTripsThroughAView() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.applyPalette(.hotIron)
        #expect(fixture.viewModel.saveCurrentView(label: "Hot iron"))

        fixture.viewModel.applyDefaultView()
        #expect(fixture.viewModel.palette == nil,
                "the file describes no palette, so the default view is grey")

        #expect(fixture.viewModel.applySavedView(label: "Hot iron"))
        #expect(fixture.viewModel.palette == .hotIron)
    }

    @Test("A view that recorded no colour takes the colour off when applied")
    func greyViewRemovesTheColour() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // Saved grey — the view's complete statement includes "no palette".
        fixture.viewModel.zoomLevel = 2
        #expect(fixture.viewModel.saveCurrentView(label: "Grey zoom"))

        fixture.viewModel.applyPalette(.pet)
        #expect(fixture.viewModel.applySavedView(label: "Grey zoom"))
        #expect(fixture.viewModel.palette == nil)
    }

    @Test("A series save carries the palette to every covered image")
    func seriesSaveSpreadsThePalette() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.applyPalette(.viridis)
        let saved = await fixture.viewModel.saveCurrentView(
            label: "Coloured series", scope: .currentSeries)
        #expect(saved)

        let view = try #require(fixture.store
            .views(forStudy: Self.studyUID).first { $0.label == "Coloured series" })
        for sop in [Self.sop1, Self.sop2] {
            #expect(view.state(forImage: sop)?.palette == .viridis)
        }
    }

    // MARK: - Frames

    @Test("A save records every frame's drawings, not just the one on screen")
    func saveRecordsAllFrames() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // Frame 0 is on screen; the reader also drew on frame 2 earlier.
        fixture.viewModel.printSelection.cellAnnotations[
            ImageAnnotationKey(filePath: fixture.paths[0], frameIndex: 0)] = [arrow()]
        fixture.viewModel.printSelection.cellAnnotations[
            ImageAnnotationKey(filePath: fixture.paths[0], frameIndex: 2)] = [arrow()]

        #expect(fixture.viewModel.saveCurrentView(label: "Marked frames"))

        let state = try #require(fixture.store
            .views(forStudy: Self.studyUID)
            .first { $0.label == "Marked frames" }?
            .state(forImage: Self.sop1))
        #expect(state.annotations(forFrame: 0).count == 1)
        #expect(state.annotations(forFrame: 2).count == 1)
    }

    @Test("A series save keeps another image's later-frame drawings")
    func seriesSaveKeepsOtherImagesFrames() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // The regression: the other image's drawings were read at frame 0
        // only, so an arrow on its frame 2 vanished from the saved view.
        fixture.viewModel.printSelection.cellAnnotations[
            ImageAnnotationKey(filePath: fixture.paths[1], frameIndex: 2)] = [arrow()]
        fixture.viewModel.zoomLevel = 2

        let saved = await fixture.viewModel.saveCurrentView(
            label: "Marked elsewhere", scope: .currentSeries)
        #expect(saved)

        let view = try #require(fixture.store
            .views(forStudy: Self.studyUID).first { $0.label == "Marked elsewhere" })
        let other = try #require(view.state(forImage: Self.sop2))
        #expect(other.annotations(forFrame: 2).count == 1)
        #expect(other.annotations(forFrame: 0).isEmpty)
    }

    @Test("Applying a view puts each frame's drawings back on its frame")
    func applyRestoresDrawingsPerFrame() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        let frame0 = ImageAnnotationKey(filePath: fixture.paths[0], frameIndex: 0)
        let frame2 = ImageAnnotationKey(filePath: fixture.paths[0], frameIndex: 2)
        fixture.viewModel.printSelection.cellAnnotations[frame0] = [arrow()]
        fixture.viewModel.printSelection.cellAnnotations[frame2] = [arrow()]
        #expect(fixture.viewModel.saveCurrentView(label: "Marked frames"))

        // The reader wipes the slate, then draws something new on frame 5.
        fixture.viewModel.printSelection.cellAnnotations = [:]
        fixture.viewModel.printSelection.cellAnnotations[
            ImageAnnotationKey(filePath: fixture.paths[0], frameIndex: 5)] = [arrow()]

        #expect(fixture.viewModel.applySavedView(label: "Marked frames"))

        let annotations = fixture.viewModel.printSelection.cellAnnotations
        #expect(annotations[frame0]?.count == 1)
        #expect(annotations[frame2]?.count == 1)
        // The complete-statement rule: the view says nothing about frame 5,
        // so applying it leaves nothing there.
        #expect(annotations[
            ImageAnnotationKey(filePath: fixture.paths[0], frameIndex: 5)] == nil)
    }
}
