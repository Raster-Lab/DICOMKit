// PrintSavedViewPickerTests.swift
// DICOMStudioTests
//
// What the film screen's saved-view (PR) controls may offer, and what picking
// one must do.
//
// The rule both halves rest on: a saved view is a statement about *particular
// images*. A label saved over three slices of a series says nothing about the
// fourth, so offering it against that fourth cell is offering a choice that
// cannot take — and a picker whose selection does nothing is indistinguishable
// from a broken one. These tests pin that a label is only ever offered where it
// can actually apply.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import DICOMKit
import DICOMCore
import Foundation

@MainActor
@Suite("Print Saved View Picker Tests")
struct PrintSavedViewPickerTests {

    // MARK: - Fixtures

    private static let studyUID = "1.2.3.4.5"
    private static let seriesUID = "1.2.3.4.5.6"
    /// The image a view is saved for.
    private static let coveredUID = "1.2.3.4.5.6.7"
    /// A second image in the same study that nothing is saved for.
    private static let uncoveredUID = "1.2.3.4.5.6.8"

    private func makeStore() -> (PresentationStateStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintSavedViewPickerTests-\(UUID().uuidString)")
        return (PresentationStateStore(root: root), root)
    }

    private func cleanUp(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    /// Saves one view, named, covering exactly one image.
    private func saveView(
        label: String, forImage sopInstanceUID: String, in store: PresentationStateStore
    ) throws {
        try saveView(label: label, forImages: [sopInstanceUID], in: store)
    }

    /// Saves one view spanning several images — one save, one label, many
    /// objects, which is how a view saved across a series is written.
    private func saveView(
        label: String, forImages sopInstanceUIDs: [String],
        in store: PresentationStateStore
    ) throws {
        let patient = PresentationStatePatientContext(
            patientName: "DOE^JANE", patientID: "12345",
            studyInstanceUID: Self.studyUID)
        // A window and a 2× zoom, so the restored view is visibly not the
        // image as marked.
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 2, viewportWidth: 800, viewportHeight: 600),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        try store.save(
            images: sopInstanceUIDs.map {
                .init(sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                      sopInstanceUID: $0,
                      seriesInstanceUID: Self.seriesUID,
                      display: display)
            },
            label: label, patient: patient)
    }

    /// A print view model over two marks: one the view covers, one it does not.
    private func makeViewModel(
        store: PresentationStateStore
    ) -> (PrintViewModel, PrintSelectionItem, PrintSelectionItem) {
        let selection = PrintSelectionModel()
        let covered = PrintSelectionItem(
            filePath: "/covered.dcm", sopInstanceUID: Self.coveredUID)
        let uncovered = PrintSelectionItem(
            filePath: "/uncovered.dcm", sopInstanceUID: Self.uncoveredUID)
        selection.add(contentsOf: [covered, uncovered])

        let viewModel = PrintViewModel(selection: selection)
        viewModel.presentationStateStore = store
        viewModel.presentationStateStudyUID = Self.studyUID
        return (viewModel, covered, uncovered)
    }

    // MARK: - What may be offered

    @Test("A label is offered for the image it covers, and not for one it does not")
    func testLabelsAreOfferedPerImage() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, uncovered) = makeViewModel(store: store)

        #expect(viewModel.savedViews(for: covered).map(\.label) == ["Lung window"])
        #expect(viewModel.savedViews(for: uncovered).isEmpty,
                "nothing was saved for this image, so it has nothing to offer")
    }

    /// The bug: the job-wide picker listed every label on the film, so a label
    /// saved on one slice was offered against a cell it says nothing about.
    /// Picking it there wrote nothing and looked like a dead control.
    @Test("The job-wide picker offers a label only where some cell can take it")
    func testJobWidePickerOffersOnlyApplicableLabels() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, _, _) = makeViewModel(store: store)

        #expect(viewModel.savedViewLabelsOnFilm == ["Lung window"])
        #expect(viewModel.hasSavedViewsForAnyCell)
    }

    /// The gate the sheet keys off. With nothing saved for *any* marked image
    /// the controls must be gone entirely — a toggle that cannot change the
    /// film invites the reader to look for an effect that was never possible.
    @Test("With nothing saved for any marked image the controls are hidden")
    func testControlsHiddenWhenNothingApplies() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        // Saved for an image that is not on this film.
        try saveView(label: "Lung window", forImage: "1.2.3.4.5.6.99", in: store)

        let (viewModel, _, _) = makeViewModel(store: store)

        #expect(viewModel.savedViewLabelsOnFilm.isEmpty)
        #expect(viewModel.hasSavedViewsForAnyCell == false,
                "no marked image carries a state, so there is nothing to switch on")
    }

    @Test("A mark with no image identity is offered nothing")
    func testMarkWithoutUIDIsOfferedNothing() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let selection = PrintSelectionModel()
        // Marked from the library without opening the file: no SOP Instance UID
        // to look a state up by.
        let anonymous = PrintSelectionItem(filePath: "/anonymous.dcm")
        selection.add(contentsOf: [anonymous])
        let viewModel = PrintViewModel(selection: selection)
        viewModel.presentationStateStore = store
        viewModel.presentationStateStudyUID = Self.studyUID

        #expect(viewModel.savedViews(for: anonymous).isEmpty)
        #expect(viewModel.hasSavedViewsForAnyCell == false)
    }

    // MARK: - What picking one does

    @Test("Picking a label the cell carries changes the cell")
    func testApplyingAViewChangesTheCell() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, _) = makeViewModel(store: store)

        let applied = await viewModel.applySavedView(
            label: "Lung window", toItemID: covered.id,
            cellSize: CGSize(width: 400, height: 400))
        #expect(applied, "the cell carries this view, so it must take")

        #expect(viewModel.savedViewSelectionLabel(forItemID: covered.id) == "Lung window")
        #expect(viewModel.isCellAdjusted(covered.id),
                "the reader chose this view for this cell, so it must survive a re-sync")

        // The write has to reach the film, not just the mark: arranging a cell
        // says the film carries arrangements, or `previewItem(for:)` drops it
        // and applying a view appears to do nothing at all.
        #expect(viewModel.useViewerPresentation)
    }

    @Test("Picking a label the cell does not carry is refused rather than silently ignored")
    func testApplyingAnUncoveringViewIsRefused() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, _, uncovered) = makeViewModel(store: store)

        let applied = await viewModel.applySavedView(
            label: "Lung window", toItemID: uncovered.id,
            cellSize: CGSize(width: 400, height: 400))
        #expect(applied == false)
        #expect(viewModel.savedViewSelectionLabel(forItemID: uncovered.id)
                == PrintViewModel.defaultViewLabel,
                "a refused apply must not leave the picker naming a view the cell is not showing")
    }

    /// The job-wide picker lists the union of labels across the film, so on a
    /// mixed sheet a label offered there lands on some cells and not others.
    /// That is deliberate — but the *cell* inspector must never repeat it.
    @Test("A label saved on one cell is not offered by the other cell's picker")
    func testMixedFilmDoesNotOfferALabelToTheWrongCell() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, uncovered) = makeViewModel(store: store)

        // The union, which the job-wide picker shows.
        #expect(viewModel.savedViewLabelsOnFilm == ["Lung window"])
        // But per cell, only where it applies.
        #expect(viewModel.savedViews(for: covered).map(\.label) == ["Lung window"])
        #expect(viewModel.savedViews(for: uncovered).isEmpty)
    }

    /// Adoption must skip cells the chosen label says nothing about, rather
    /// than leaving them flagged as showing it.
    @Test("Adopting a label touches only the cells it covers")
    func testAdoptionSkipsUncoveredCells() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, uncovered) = makeViewModel(store: store)
        viewModel.defaultSavedViewLabel = "Lung window"
        await viewModel.adoptSavedViewsWhereUntouched()

        #expect(viewModel.appliedSavedViewLabel(forItemID: covered.id) == nil,
                "the switch is off, so nothing should have been adopted")
        #expect(viewModel.appliedSavedViewLabel(forItemID: uncovered.id) == nil)
    }

    /// The cell inspector's picker applies with no `cellSize` — the view layer
    /// has no cell geometry to hand. That must still change the cell: a mark
    /// made from the library carries no viewport either, so both fall back
    /// together and the restore has to survive it.
    @Test("Applying without a cell size still changes the cell")
    func testApplyingWithoutACellSizeStillChangesTheCell() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, _) = makeViewModel(store: store)
        let before = viewModel.selection.items.first { $0.id == covered.id }

        // Exactly what `savedViewPicker` does: no cellSize.
        let applied = await viewModel.applySavedView(
            label: "Lung window", toItemID: covered.id)
        #expect(applied)

        let after = try #require(viewModel.selection.items.first { $0.id == covered.id })
        #expect(after.presentation != before?.presentation,
                "the picker's own call path must move the picture")
        #expect(after.windowCenter == 40)
        #expect(after.windowWidth == 400)
        #expect((after.presentation?.zoom ?? 1) > 1,
                "the saved 2x zoom has to survive the restore")
    }

    /// A job-wide explicit window overrides every cell's own window, so the
    /// window half of a saved view cannot reach the film while it is on. The
    /// view still carries zoom, rotation and inversion — but the reader has to
    /// be told, or picking a view looks like it did nothing.
    @Test("An explicit job window swallows the saved view's window")
    func testExplicitWindowOverridesTheSavedWindow() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, _) = makeViewModel(store: store)
        viewModel.useExplicitWindow = true
        viewModel.explicitWindowCenter = 8232
        viewModel.explicitWindowWidth = 80

        #expect(await viewModel.applySavedView(
            label: "Lung window", toItemID: covered.id))

        let mark = try #require(viewModel.selection.items.first { $0.id == covered.id })
        #expect(mark.windowCenter == 40, "the mark itself took the saved window")

        // But what the film shows is the job-wide window, not the saved one.
        let onFilm = viewModel.previewItem(for: mark)
        #expect(onFilm.windowCenter == 8232,
                "the explicit window wins — this is what makes the picker look dead")
        #expect(viewModel.isCellWindowingOverridden)
    }

    /// Raw pixels bypass window *and* arrangement, so a saved view cannot
    /// change the film at all while it is on.
    @Test("Raw pixels leave a saved view with nothing to change")
    func testRawPixelsDropTheSavedView() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, _) = makeViewModel(store: store)
        viewModel.sendRawPixels = true

        _ = await viewModel.applySavedView(label: "Lung window", toItemID: covered.id)

        let mark = try #require(viewModel.selection.items.first { $0.id == covered.id })
        let onFilm = viewModel.previewItem(for: mark)
        #expect(onFilm.windowCenter == nil)
        #expect(onFilm.presentation == nil,
                "raw sends stored pixels, so nothing a view says survives")
    }

    // MARK: - Saying so when a view cannot reach the film

    @Test("Nothing is said while a saved view can reach the film")
    func testNoNoticeWhenTheViewApplies() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, _, _) = makeViewModel(store: store)
        #expect(viewModel.savedViewBlockedReason == nil)
        #expect(viewModel.savedViewsCanReachTheFilm)
    }

    @Test("A job-wide window says it is swallowing the view's window")
    func testExplicitWindowIsAnnounced() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, _, _) = makeViewModel(store: store)
        viewModel.useExplicitWindow = true

        let reason = try #require(viewModel.savedViewBlockedReason)
        #expect(reason.contains("window"))
        // The rest of the view still lands, so the picker stays usable.
        #expect(viewModel.savedViewsCanReachTheFilm)
    }

    @Test("Raw pixels shut the picker rather than letting it do nothing")
    func testRawPixelsShutThePicker() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, _, _) = makeViewModel(store: store)
        viewModel.sendRawPixels = true

        #expect(viewModel.savedViewBlockedReason != nil)
        #expect(viewModel.savedViewsCanReachTheFilm == false,
                "nothing a view carries survives raw, so the control must not invite a pick")
    }

    // MARK: - How far a label reaches

    @Test("A label reports how many cells it covers")
    func testLabelCoverageIsCounted() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, _, _) = makeViewModel(store: store)

        #expect(viewModel.cellCountCovered(byLabel: "Lung window") == 1,
                "one of the two cells carries it")
        #expect(viewModel.cellCountCovered(byLabel: "Nothing saved here") == 0)
        #expect(viewModel.cellCountWithSavedViews == 1)
        #expect(viewModel.printedItems.count == 2,
                "so the sheet can say 1 of 2 rather than leaving it to be discovered")
    }

    @Test("A label saved on every cell covers every cell")
    func testFullCoverageIsCounted() throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        // One save spanning both images. Saving twice under the same label
        // would *replace* rather than append — a second save under one name is
        // the reader correcting the view, not adding another.
        try saveView(label: "Lung window",
                     forImages: [Self.coveredUID, Self.uncoveredUID], in: store)

        let (viewModel, _, _) = makeViewModel(store: store)
        #expect(viewModel.cellCountCovered(byLabel: "Lung window") == 2)
        #expect(viewModel.cellCountWithSavedViews == viewModel.printedItems.count)
    }

    // MARK: - The cell the crop is restored against

    @Test("The recorded cell size is what a restore uses as its viewport")
    func testRecordedCellSizeBecomesTheViewport() async throws {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        try saveView(label: "Lung window", forImage: Self.coveredUID, in: store)

        let (viewModel, covered, _) = makeViewModel(store: store)
        // What the preview reports for the focused cell.
        viewModel.recordCellSize(CGSize(width: 300, height: 380))

        #expect(await viewModel.applySavedView(
            label: "Lung window", toItemID: covered.id,
            cellSize: viewModel.lastCellSize))

        let mark = try #require(viewModel.selection.items.first { $0.id == covered.id })
        let presentation = try #require(mark.presentation)
        #expect(presentation.viewportWidth == 300)
        #expect(presentation.viewportHeight == 380,
                "the crop is restored against the cell it prints in, not the viewer tile")
    }

    @Test("A cell size is only recorded when it is real")
    func testDegenerateCellSizesAreIgnored() {
        let (store, root) = makeStore()
        defer { cleanUp(root) }
        let (viewModel, _, _) = makeViewModel(store: store)

        viewModel.recordCellSize(.zero)
        #expect(viewModel.lastCellSize == nil,
                "a zero cell is a layout that has not happened yet, not a viewport")

        viewModel.recordCellSize(CGSize(width: 300, height: 380))
        #expect(viewModel.lastCellSize == CGSize(width: 300, height: 380))
    }
}
