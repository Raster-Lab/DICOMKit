// SeriesSavedViewTests.swift
// DICOMStudioTests
//
// Saving a view for a whole series — or every series — rather than one image.
//
// The shape under test: a series-scoped save writes the same window, zoom and
// orientation onto every image the scope covers, one presentation state per
// image under one label. Because that is exactly the shape an image-scoped
// view has (with one state instead of many), everything the reader can do to
// an image view — apply it, update it by re-saving the name, delete it,
// export it into the study's own folder — must work identically on a series
// view. These tests hold each of those to it.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Series Saved View Tests")
struct SeriesSavedViewTests {

    // MARK: - Fixtures

    private static let studyUID = "1.2.3.4.5"
    private static let seriesAUID = "1.2.3.4.5.6"
    private static let seriesBUID = "1.2.3.4.5.7"
    private static let ctSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    private static let sopA1 = "1.2.3.4.5.6.1"
    private static let sopA2 = "1.2.3.4.5.6.2"
    private static let sopB1 = "1.2.3.4.5.7.1"
    private static let sopB2 = "1.2.3.4.5.7.2"

    /// Everything a test needs: the viewer, where saved views are stored, and
    /// the study's own folder on disk.
    private struct Fixture {
        let viewModel: ImageViewerViewModel
        let root: URL
        let studyDirectory: URL
        let store: PresentationStateStore
        let seriesAPaths: [String]
        let seriesBPaths: [String]
    }

    /// An image file as it would sit in a study folder — real, readable, with
    /// the identity a series save reads back out of it.
    private func writeImageFile(
        sopInstanceUID: String, seriesInstanceUID: String, to url: URL
    ) throws -> DICOMFile {
        let elements: [DataElement] = [
            .string(tag: .sopClassUID, vr: .UI, value: Self.ctSOPClass),
            .string(tag: .sopInstanceUID, vr: .UI, value: sopInstanceUID),
            .string(tag: .studyInstanceUID, vr: .UI, value: Self.studyUID),
            .string(tag: .seriesInstanceUID, vr: .UI, value: seriesInstanceUID),
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

    /// A viewer showing the first image of series A, over a study of two
    /// series with two images each — all real files in one study folder.
    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeriesSavedViewTests-\(UUID().uuidString)")
        let studyDirectory = root.appendingPathComponent("study", isDirectory: true)
        try FileManager.default.createDirectory(
            at: studyDirectory, withIntermediateDirectories: true)

        var seriesAPaths: [String] = []
        var seriesBPaths: [String] = []
        var firstFile: DICOMFile?
        for (sop, series) in [
            (Self.sopA1, Self.seriesAUID), (Self.sopA2, Self.seriesAUID),
            (Self.sopB1, Self.seriesBUID), (Self.sopB2, Self.seriesBUID)
        ] {
            let url = studyDirectory.appendingPathComponent("\(sop).dcm")
            let file = try writeImageFile(
                sopInstanceUID: sop, seriesInstanceUID: series, to: url)
            if sop == Self.sopA1 { firstFile = file }
            if series == Self.seriesAUID { seriesAPaths.append(url.path) }
            else { seriesBPaths.append(url.path) }
        }

        let store = PresentationStateStore(
            root: root.appendingPathComponent("store", isDirectory: true))

        let viewModel = ImageViewerViewModel()
        viewModel.dicomFile = firstFile
        viewModel.filePath = seriesAPaths[0]
        viewModel.sopInstanceUID = Self.sopA1
        viewModel.studyInstanceUID = Self.studyUID
        viewModel.currentSeriesUID = Self.seriesAUID
        viewModel.imageColumns = 512
        viewModel.imageRows = 512
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.presentationStateStore = store
        viewModel.studySeries = [
            ViewerSeriesEntry(
                seriesInstanceUID: Self.seriesAUID, title: "Axial",
                seriesNumber: 1, modality: "CT",
                filePaths: seriesAPaths, frameCount: 2),
            ViewerSeriesEntry(
                seriesInstanceUID: Self.seriesBUID, title: "Coronal",
                seriesNumber: 2, modality: "CT",
                filePaths: seriesBPaths, frameCount: 2)
        ]

        return Fixture(
            viewModel: viewModel, root: root, studyDirectory: studyDirectory,
            store: store, seriesAPaths: seriesAPaths, seriesBPaths: seriesBPaths)
    }

    private func cleanUp(_ fixture: Fixture) {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    /// The presentation states sitting in the study's own folder.
    private func publishedStates(in directory: URL) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { url in
            guard url.pathExtension.lowercased() == "dcm",
                  let file = try? DICOMFile.read(from: url) else { return false }
            return file.dataSet.string(for: .sopClassUID)
                == GrayscalePresentationStateBuilder.sopClassUID
        }
    }

    // MARK: - Offering the scopes

    @Test("A series of more than one image offers the series scope")
    func seriesScopeIsOffered() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        #expect(fixture.viewModel.canSaveViewForSeries)
        #expect(fixture.viewModel.canSaveViewForAllSeries)
    }

    @Test("A lone image offers neither series scope")
    func loneImageOffersNoSeriesScope() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // The same viewer with no series pane and no navigation list: the
        // series save would cover exactly what the image save does.
        fixture.viewModel.studySeries = []
        fixture.viewModel.currentSeriesUID = nil

        #expect(fixture.viewModel.canSaveViewForSeries == false)
        #expect(fixture.viewModel.canSaveViewForAllSeries == false)
    }

    // MARK: - Saving

    @Test("A series save covers every image of the series")
    func seriesSaveCoversTheSeries() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        let saved = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        #expect(saved)

        let view = try #require(fixture.store
            .views(forStudy: Self.studyUID).first { $0.label == "Lung window" })
        #expect(view.coveredImageCount == 2)
        #expect(view.covers(image: Self.sopA1))
        #expect(view.covers(image: Self.sopA2))
        // The other series was not asked for and is not touched.
        #expect(view.covers(image: Self.sopB1) == false)
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")
    }

    @Test("An all-series save covers every image of every series")
    func allSeriesSaveCoversTheStudy() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        let saved = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .allSeries)
        #expect(saved)

        let view = try #require(fixture.store
            .views(forStudy: Self.studyUID).first { $0.label == "Lung window" })
        #expect(view.coveredImageCount == 4)
        for sop in [Self.sopA1, Self.sopA2, Self.sopB1, Self.sopB2] {
            #expect(view.covers(image: sop))
        }
        // Each image's state names its own series, not the current one.
        let stateB = try #require(view.state(forImage: Self.sopB1))
        #expect(stateB.state.referencedSeries.first?.seriesInstanceUID == Self.seriesBUID)
    }

    @Test("The image-scope path is unchanged by the scoped API")
    func imageScopeDelegatesToTheImageSave() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        let saved = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentImage)
        #expect(saved)

        let view = try #require(fixture.store
            .views(forStudy: Self.studyUID).first { $0.label == "Lung window" })
        #expect(view.coveredImageCount == 1)
        #expect(view.covers(image: Self.sopA1))
    }

    @Test("A series save keeps drawings on the image they were drawn on")
    func seriesSaveDoesNotSpreadDrawings() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        let arrow = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.3),
            end: PrintOverlayPoint(x: 0.6, y: 0.7))
        let key = ImageAnnotationKey(
            filePath: fixture.seriesAPaths[0], frameIndex: 0)
        fixture.viewModel.printSelection.cellAnnotations[key] = [arrow]
        fixture.viewModel.zoomLevel = 2

        let saved = await fixture.viewModel.saveCurrentView(
            label: "Marked up", scope: .currentSeries)
        #expect(saved)

        let view = try #require(fixture.store
            .views(forStudy: Self.studyUID).first { $0.label == "Marked up" })
        let drawnOn = try #require(view.state(forImage: Self.sopA1))
        let clean = try #require(view.state(forImage: Self.sopA2))
        #expect(drawnOn.annotations.count == 1)
        #expect(clean.annotations.isEmpty)
    }

    // MARK: - Applying

    @Test("A series view, once applied, holds while stepping through the series")
    func seriesViewHoldsAcrossTheSeries() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.windowCenter = -600
        fixture.viewModel.windowWidth = 1500
        let saved = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        #expect(saved)

        // Step to the second image of the series, as navigation would.
        fixture.viewModel.filePath = fixture.seriesAPaths[1]
        fixture.viewModel.sopInstanceUID = Self.sopA2
        fixture.viewModel.windowCenter = 40
        fixture.viewModel.windowWidth = 400
        fixture.viewModel.offerSavedViewsIfNeeded()

        // The standing choice recorded by the series save is put back
        // silently — no prompt, the view simply holds.
        #expect(fixture.viewModel.savedViewPrompt == nil)
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")
        #expect(fixture.viewModel.windowCenter == -600)
        #expect(fixture.viewModel.windowWidth == 1500)
    }

    @Test("Applying a series view by hand marks every image it covers")
    func applyingMarksEveryCoveredImage() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        // Wander off it, then apply it again by name.
        fixture.viewModel.applyDefaultView()
        #expect(fixture.viewModel.applySavedView(label: "Lung window"))

        // Stepping to the other covered image finds the view standing.
        fixture.viewModel.filePath = fixture.seriesAPaths[1]
        fixture.viewModel.sopInstanceUID = Self.sopA2
        fixture.viewModel.offerSavedViewsIfNeeded()
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")
    }

    // MARK: - Updating

    @Test("Re-saving a series view under its name replaces it")
    func resavingUpdatesTheSeriesView() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.windowCenter = -600
        fixture.viewModel.windowWidth = 1500
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)

        // The correction: a different window, saved over the same name.
        fixture.viewModel.windowCenter = -500
        fixture.viewModel.windowWidth = 1400
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)

        let views = fixture.store.views(forStudy: Self.studyUID)
            .filter { $0.label == "Lung window" }
        #expect(views.count == 1)
        let view = try #require(views.first)
        #expect(view.coveredImageCount == 2)
        let state = try #require(view.state(forImage: Self.sopA2))
        guard case let .window(center, width, _, _)? = state.state.voiLUT else {
            Issue.record("The updated view carries no window")
            return
        }
        #expect(center == -500)
        #expect(width == 1400)
    }

    // MARK: - Deleting

    @Test("Deleting a series view removes it from every image it covered")
    func deletingRemovesTheSeriesView() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        #expect(publishedStates(in: fixture.studyDirectory).count == 2)

        fixture.viewModel.deleteSavedView(label: "Lung window")

        #expect(fixture.store.views(
            forStudy: Self.studyUID, image: Self.sopA1).isEmpty)
        #expect(fixture.store.views(
            forStudy: Self.studyUID, image: Self.sopA2).isEmpty)
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)
        // The study's own copies go with it, or the deleted view would come
        // back on the next folder scan.
        #expect(publishedStates(in: fixture.studyDirectory).isEmpty)
    }

    // MARK: - Exporting

    @Test("A series save exports one object per covered image into the study")
    func seriesSaveExportsIntoTheStudyFolder() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)

        #expect(publishedStates(in: fixture.studyDirectory).count == 2)
        let published = try #require(fixture.viewModel.publishedPresentationSeries)
        #expect(published.instances.count == 2)
        #expect(published.label == "Lung window")
    }

    @Test("Exporting a series view again re-publishes without duplicating")
    func reExportingDoesNotDuplicate() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)

        let republished = fixture.viewModel.addSavedViewToStudy(label: "Lung window")

        #expect(republished?.instances.count == 2)
        #expect(publishedStates(in: fixture.studyDirectory).count == 2)
    }

    @Test("An all-series export lands every covered image's object")
    func allSeriesExportCoversTheStudy() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .allSeries)

        #expect(publishedStates(in: fixture.studyDirectory).count == 4)
        let published = try #require(fixture.viewModel.publishedPresentationSeries)
        #expect(published.instances.count == 4)
    }

    // MARK: - Reverting to the default view

    @Test("The series-wide revert is offered only where it covers more")
    func seriesRevertOfferedOnlyWhereItCoversMore() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        #expect(fixture.viewModel.canApplyDefaultViewForSeries)

        // A lone image: reverting "the series" is the same act as reverting
        // the image, so the second row would be a choice without a difference.
        fixture.viewModel.studySeries = []
        fixture.viewModel.currentSeriesUID = nil
        fixture.viewModel.seriesFiles = [fixture.seriesAPaths[0]]
        #expect(!fixture.viewModel.canApplyDefaultViewForSeries)
    }

    @Test("Reverting the series clears the view from every image it covered")
    func seriesRevertClearsEveryCoveredImage() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")

        await fixture.viewModel.applyDefaultViewForSeries()

        // The image on screen is back to the file's own reading...
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)

        // ...and so is the other image of the series: stepping to it neither
        // re-applies the view nor re-raises the prompt, which is what a
        // present key holding nil records.
        fixture.viewModel.filePath = fixture.seriesAPaths[1]
        fixture.viewModel.sopInstanceUID = Self.sopA2
        fixture.viewModel.offerSavedViewsIfNeeded()
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)
        #expect(fixture.viewModel.savedViewPrompt == nil)
    }

    @Test("Reverting one image leaves the rest of the series on the view")
    func imageRevertLeavesTheSeriesAlone() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // A view over the whole series, then "Default view — this image" on the
        // slice on screen. The reader asked about one image; the other slices
        // must still be reading the view they were given.
        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")

        fixture.viewModel.applyDefaultView()
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)

        // The other slice of the same series still stands on the view. This is
        // the regression: `applyDefaultView` used to sweep every image in the
        // study holding the label, so backing one slice out reverted all of
        // them — the whole series reset from a row that said "this image".
        fixture.viewModel.filePath = fixture.seriesAPaths[1]
        fixture.viewModel.sopInstanceUID = Self.sopA2
        fixture.viewModel.offerSavedViewsIfNeeded()
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")
    }

    @Test("An image reverted by hand stays reverted when stepped back to")
    func imageRevertHoldsForThatImage() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        fixture.viewModel.applyDefaultView()

        // Step away and back: the slice the reader reverted must not have the
        // view put back on it, and must not re-raise the prompt either.
        fixture.viewModel.filePath = fixture.seriesAPaths[1]
        fixture.viewModel.sopInstanceUID = Self.sopA2
        fixture.viewModel.offerSavedViewsIfNeeded()

        fixture.viewModel.filePath = fixture.seriesAPaths[0]
        fixture.viewModel.sopInstanceUID = Self.sopA1
        fixture.viewModel.offerSavedViewsIfNeeded()
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)
        #expect(fixture.viewModel.savedViewPrompt == nil)
    }

    @Test("Applying a series view from the list holds across the whole series")
    func applyingSeriesViewFromTheListHolds() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // Save a series view, then go back to the default so nothing is
        // standing — the state a reader is in when they open the list to pick
        // the view again.
        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        await fixture.viewModel.applyDefaultViewForSeries()
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)

        // Now apply it again, the way the popover's row does.
        let view = try #require(
            fixture.viewModel.savedViewsForCurrentImage.first { $0.label == "Lung window" })
        #expect(fixture.viewModel.applySavedView(view))
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")

        // And it must reach the rest of the series, not just this slice. This
        // is the regression the `appliedViewByImage[uid] == nil` guard
        // introduced: every other slice was carrying a present-key-holding-nil
        // from the revert above, so the guard skipped them all and a series
        // view applied to one image only.
        fixture.viewModel.filePath = fixture.seriesAPaths[1]
        fixture.viewModel.sopInstanceUID = Self.sopA2
        fixture.viewModel.offerSavedViewsIfNeeded()
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window",
                "a series view applied from the list must hold on every slice")
    }

    // MARK: - The badge's cycle

    @Test("The badge's first press applies the series-wide view when one exists")
    func badgeCyclePrefersTheSeriesView() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        // An image-level view saved FIRST, a series-wide view second: the
        // series view must still come first in the cycle — the preference is
        // by reach, not by the order the store happens to hold them in.
        vm.zoomLevel = 2.0
        #expect(vm.saveCurrentView(label: "Bone"))
        vm.zoomLevel = 2.5
        _ = await vm.saveCurrentView(label: "Lung window", scope: .currentSeries)
        vm.applyDefaultView()
        #expect(vm.selectedPresentationStateLabel == nil)

        #expect(vm.applyNextSavedView() == "Lung window")
        #expect(vm.selectedPresentationStateLabel == "Lung window")

        // And because the press is a by-hand apply, the series view reaches
        // the series: the next slice shows it too.
        vm.filePath = fixture.seriesAPaths[1]
        vm.sopInstanceUID = Self.sopA2
        vm.offerSavedViewsIfNeeded()
        #expect(vm.selectedPresentationStateLabel == "Lung window")
    }

    @Test("Without a series-wide view, the first press applies the image's first")
    func badgeCycleFallsBackToTheImageView() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        vm.zoomLevel = 2.0
        #expect(vm.saveCurrentView(label: "Bone"))
        vm.applyDefaultView()

        #expect(vm.applyNextSavedView() == "Bone")
        #expect(vm.selectedPresentationStateLabel == "Bone")
    }

    @Test("Pressing the badge walks every view, then the default, then wraps")
    func badgeCycleWalksViewsThenDefaultThenWraps() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        vm.zoomLevel = 2.0
        #expect(vm.saveCurrentView(label: "Bone"))
        vm.zoomLevel = 2.5
        _ = await vm.saveCurrentView(label: "Lung window", scope: .currentSeries)
        vm.applyDefaultView()

        // Series view, image view, default, and round again.
        #expect(vm.applyNextSavedView() == "Lung window")
        #expect(vm.applyNextSavedView() == "Bone")
        #expect(vm.applyNextSavedView() == ImageViewerViewModel.defaultViewLabel)
        #expect(vm.selectedPresentationStateLabel == nil,
                "the default step really shows the file's own view")
        #expect(vm.applyNextSavedView() == "Lung window",
                "after the default the cycle starts over")
    }

    @Test("The badge does nothing on an image with no saved views")
    func badgeCycleIsEmptyWithoutViews() throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        #expect(fixture.viewModel.applyNextSavedView() == nil)
        #expect(fixture.viewModel.selectedPresentationStateLabel == nil)
    }

    @Test("A tool edit restarts the cycle from the top")
    func badgeCycleRestartsAfterAToolEdit() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        vm.zoomLevel = 2.5
        _ = await vm.saveCurrentView(label: "Lung window", scope: .currentSeries)
        vm.applyDefaultView()
        #expect(vm.applyNextSavedView() == "Lung window")

        // A windowing nudge clears the selected label — the picker must stop
        // claiming the view is on screen unchanged — so the next press starts
        // over rather than stepping from a position that no longer exists.
        vm.presentationStateFollowsTools()
        #expect(vm.selectedPresentationStateLabel == nil)
        #expect(vm.applyNextSavedView() == "Lung window")
    }

    // MARK: - What the on-image badge's list does

    @Test("The badge list's rows drive apply, image revert and series revert")
    func badgeListRowActionsAllWork() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        // Two views on this image, so the list has real rows to choose between.
        vm.zoomLevel = 2.5
        _ = await vm.saveCurrentView(label: "Lung window", scope: .currentSeries)
        vm.zoomLevel = 1.75
        #expect(vm.saveCurrentView(label: "Bone"))

        // The row for a named view — exactly what `savedViewRow` calls.
        let lung = try #require(
            vm.savedViewsForCurrentImage.first { $0.label == "Lung window" })
        vm.applySavedView(lung, byHand: true)
        #expect(vm.selectedPresentationStateLabel == "Lung window")
        // Close, not equal: a view stores its geometry as a GSPS displayed
        // area, so the zoom comes back through that round trip rather than as
        // the literal number that went in.
        #expect(abs(vm.zoomLevel - 2.5) < 0.05,
                "applying a row restores that view's zoom")

        // ...and it reaches the rest of the series, which is what "by hand"
        // buys: a series view picked from the list holds while stepping.
        vm.filePath = fixture.seriesAPaths[1]
        vm.sopInstanceUID = Self.sopA2
        vm.offerSavedViewsIfNeeded()
        #expect(vm.selectedPresentationStateLabel == "Lung window")

        // The "this image" row.
        vm.applyDefaultView()
        #expect(vm.selectedPresentationStateLabel == nil)
        // The slice we came from still stands on the view — one image only.
        vm.filePath = fixture.seriesAPaths[0]
        vm.sopInstanceUID = Self.sopA1
        vm.offerSavedViewsIfNeeded()
        #expect(vm.selectedPresentationStateLabel == "Lung window")

        // The "whole series" row.
        await vm.applyDefaultViewForSeries()
        #expect(vm.selectedPresentationStateLabel == nil)
        vm.filePath = fixture.seriesAPaths[1]
        vm.sopInstanceUID = Self.sopA2
        vm.offerSavedViewsIfNeeded()
        #expect(vm.selectedPresentationStateLabel == nil)
    }

    @Test("The badge list can apply a view again after everything was reverted")
    func badgeListAppliesAfterAFullRevert() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        vm.zoomLevel = 2.5
        _ = await vm.saveCurrentView(label: "Lung window", scope: .currentSeries)
        await vm.applyDefaultViewForSeries()
        #expect(vm.selectedPresentationStateLabel == nil)

        // Re-opening the badge and clicking the row must work: this is the
        // state every slice carries a "reader chose default" answer in, and a
        // guard that skipped those made the apply reach one image only.
        let lung = try #require(
            vm.savedViewsForCurrentImage.first { $0.label == "Lung window" })
        vm.applySavedView(lung, byHand: true)
        #expect(vm.selectedPresentationStateLabel == "Lung window")

        vm.filePath = fixture.seriesAPaths[1]
        vm.sopInstanceUID = Self.sopA2
        vm.offerSavedViewsIfNeeded()
        #expect(vm.selectedPresentationStateLabel == "Lung window")
    }

    @Test("Deleting from the badge list removes the view")
    func badgeListDeleteRemovesTheView() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }
        let vm = fixture.viewModel

        vm.zoomLevel = 2.5
        #expect(vm.saveCurrentView(label: "Bone"))
        #expect(vm.savedViewsForCurrentImage.contains { $0.label == "Bone" })

        // What the row's trash button confirms into.
        vm.deleteSavedView(label: "Bone")
        #expect(!vm.savedViewsForCurrentImage.contains { $0.label == "Bone" })
    }

    @Test("Reverting one series leaves another series' view standing")
    func seriesRevertLeavesOtherSeriesAlone() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        // One view over both series, then back out of series A only.
        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .allSeries)
        await fixture.viewModel.applyDefaultViewForSeries()

        // Series B still stands on it.
        fixture.viewModel.filePath = fixture.seriesBPaths[0]
        fixture.viewModel.sopInstanceUID = Self.sopB1
        fixture.viewModel.currentSeriesUID = Self.seriesBUID
        fixture.viewModel.offerSavedViewsIfNeeded()
        #expect(fixture.viewModel.selectedPresentationStateLabel == "Lung window")
    }

    // MARK: - The series pane's badge

    @Test("A saved view marks its image's series, not the study's others")
    func savedViewMarksItsOwnSeries() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        #expect(fixture.viewModel.savedViewSeriesUIDs.isEmpty)

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)

        #expect(fixture.viewModel.seriesHasSavedViews(Self.seriesAUID))
        #expect(!fixture.viewModel.seriesHasSavedViews(Self.seriesBUID))
    }

    @Test("Deleting the last view unmarks the series")
    func deletingUnmarksTheSeries() async throws {
        let fixture = try makeFixture()
        defer { cleanUp(fixture) }

        fixture.viewModel.zoomLevel = 2.5
        _ = await fixture.viewModel.saveCurrentView(
            label: "Lung window", scope: .currentSeries)
        #expect(fixture.viewModel.seriesHasSavedViews(Self.seriesAUID))

        fixture.viewModel.deleteSavedView(label: "Lung window")
        #expect(!fixture.viewModel.seriesHasSavedViews(Self.seriesAUID))
    }
}
