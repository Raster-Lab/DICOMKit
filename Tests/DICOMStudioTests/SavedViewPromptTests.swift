// SavedViewPromptTests.swift
// DICOMStudioTests
//
// What happens when an image with saved views is opened.
//
// It used to be a question: a sheet listing the views, answered by a click.
// That sheet is held — it put a dialog between the reader and the picture on
// every arrival at a new image — and arrival now *applies* instead: the
// series-wide view when the series has one, else the image's first, shown
// immediately, with the on-image badge stepping through the others and the
// default view. These tests pin that behaviour, and the parts of the old
// contract that survive it unchanged: a choice is remembered per image, a
// deliberate return to the default stays chosen, a grid is never interrupted,
// and the save box offers the right name.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Saved View Arrival Tests")
struct SavedViewPromptTests {

    // MARK: - Fixtures

    private static let studyUID = "1.2.3.4.5"
    private static let seriesUID = "1.2.3.4.5.6"
    private static let sopUID = "1.2.3.4.5.6.7"
    private static let otherSOPUID = "1.2.3.4.5.6.8"

    private func makeViewModel(
        sopInstanceUID: String = SavedViewPromptTests.sopUID,
        store: PresentationStateStore? = nil
    ) throws -> (ImageViewerViewModel, URL) {
        let root = store?.root ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedViewPromptTests-\(UUID().uuidString)")

        let elements: [DataElement] = [
            .string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2"),
            .string(tag: .sopInstanceUID, vr: .UI, value: sopInstanceUID),
            .string(tag: .studyInstanceUID, vr: .UI, value: Self.studyUID),
            .string(tag: .seriesInstanceUID, vr: .UI, value: Self.seriesUID),
            .string(tag: .patientName, vr: .PN, value: "DOE^JANE"),
            .string(tag: .patientID, vr: .LO, value: "12345"),
            .string(tag: .windowCenter, vr: .DS, value: "40"),
            .string(tag: .windowWidth, vr: .DS, value: "400")
        ]
        let file = DICOMFile.create(
            dataSet: DataSet(elements: elements),
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: sopInstanceUID)

        let viewModel = ImageViewerViewModel()
        viewModel.dicomFile = file
        viewModel.filePath = "/tmp/\(sopInstanceUID).dcm"
        viewModel.sopInstanceUID = sopInstanceUID
        viewModel.studyInstanceUID = Self.studyUID
        viewModel.currentSeriesUID = Self.seriesUID
        viewModel.imageColumns = 512
        viewModel.imageRows = 512
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.presentationStateStore = store ?? PresentationStateStore(root: root)

        return (viewModel, root)
    }

    /// A viewer with one saved view already stored for the image on screen, as
    /// though it had been saved in an earlier session.
    private func makeViewModelWithSavedView(
        label: String = "Lung window"
    ) throws -> (ImageViewerViewModel, URL) {
        let (viewModel, root) = try makeViewModel()
        viewModel.zoomLevel = 2.5
        #expect(viewModel.saveCurrentView(label: label))
        // Back to how the image opens on a *fresh* arrival: the view exists in
        // the store, nothing is applied, and — the part that matters — the
        // image carries no standing choice, because saving and unsaving it
        // happened in an earlier session. Clearing the map is what a file load
        // in a new session would amount to.
        viewModel.applyDefaultView()
        viewModel.appliedViewByImage = [:]
        viewModel.selectedPresentationStateLabel = nil
        return (viewModel, root)
    }

    private func cleanUp(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    /// What arriving back at the image amounts to, short of re-reading the file.
    ///
    /// `loadDICOMData` resets the transforms and drops the label — which names
    /// the slice being left — then calls `offerSavedViewsIfNeeded()`. The
    /// standing choice in `appliedViewByImage` is deliberately *not* touched:
    /// that is the thing under test, and clearing it here would test nothing.
    private func returnToImage(_ viewModel: ImageViewerViewModel) {
        viewModel.zoomLevel = 1.0
        viewModel.panOffsetX = 0
        viewModel.panOffsetY = 0
        viewModel.selectedPresentationStateLabel = nil
        viewModel.offerSavedViewsIfNeeded()
    }

    // MARK: - Arrival applies

    @Test("An image with a saved view opens showing it — no sheet in between")
    func imageWithSavedViewOpensShowingIt() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()

        #expect(viewModel.savedViewPrompt == nil, "the sheet is held; nothing raises it")
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
        #expect(abs(viewModel.zoomLevel - 2.5) < 0.05,
                "the view is genuinely applied, not merely named")
    }

    @Test("With several views, arrival applies the cycle's first")
    func arrivalAppliesTheCycleHead() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 1.8
        #expect(viewModel.saveCurrentView(label: "Bone window"))
        viewModel.applyDefaultView()
        // Saved in an earlier session, as in the fixture: the store holds two
        // views and the image arrives carrying no choice between them.
        viewModel.appliedViewByImage = [:]
        viewModel.selectedPresentationStateLabel = nil

        viewModel.offerSavedViewsIfNeeded()

        // The same ordering the badge steps in, so what arrival shows is what
        // the badge's cycle starts from.
        let head = try #require(viewModel.savedViewCycle.first)
        #expect(viewModel.selectedPresentationStateLabel == head.label)
        #expect(viewModel.savedViewPrompt == nil)

        // And the badge steps on from there to the other view.
        let labels = viewModel.savedViewCycle.map(\.label)
        #expect(viewModel.applyNextSavedView() == labels[1])
    }

    @Test("An image with nothing saved opens as the file describes it")
    func imageWithoutSavedViewsIsLeftAlone() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()

        #expect(viewModel.savedViewPrompt == nil)
        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.zoomLevel == 1.0)
    }

    @Test("A view saved on another image does not reach this one")
    func viewOfAnotherImageIsNotApplied() throws {
        let (saver, root) = try makeViewModel()
        defer { cleanUp(root) }
        saver.zoomLevel = 2.5
        #expect(saver.saveCurrentView(label: "Lung window"))

        // A different image of the same study, so the same store is searched.
        let (viewModel, _) = try makeViewModel(
            sopInstanceUID: Self.otherSOPUID,
            store: PresentationStateStore(root: root))

        viewModel.offerSavedViewsIfNeeded()

        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.zoomLevel == 1.0)
    }

    @Test("A grid is not touched by arrival")
    func multiCellLayoutIsLeftAlone() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.applyLayout(ViewerTileLayout(rows: 2, columns: 2))
        viewModel.offerSavedViewsIfNeeded()

        #expect(viewModel.savedViewPrompt == nil)
        #expect(viewModel.selectedPresentationStateLabel == nil,
                "focus moves between tiles constantly; nothing may be applied under it")
    }

    @Test("Arrival is idempotent — the second trigger changes nothing")
    func arrivalIsIdempotent() throws {
        // The two trigger points — the file load and the study pane arriving —
        // both call this, and either can be last. The first applies and
        // records; the second finds the image answered and restores the same
        // reading rather than stepping it onward.
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
    }

    // MARK: - Choices are remembered per image

    @Test("An applied view is put back when the reader returns to the image")
    func appliedViewIsRestoredOnReturn() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")

        // The reader scrolls to the next slice and back.
        returnToImage(viewModel)

        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
        #expect(abs(viewModel.zoomLevel - 2.5) < 0.05)
    }

    @Test("A deliberate default view stays chosen — arrival does not re-apply")
    func chosenDefaultSurvivesReturn() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        // Arrival shows the view; the reader steps the badge past it to the
        // default — a standing answer for this slice.
        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.applyNextSavedView() == ImageViewerViewModel.defaultViewLabel)
        #expect(viewModel.selectedPresentationStateLabel == nil)

        // Away and back: the choice holds. Auto-apply speaks only for
        // unanswered images, or the badge's default step would be undone by
        // the very next arrival.
        returnToImage(viewModel)
        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.zoomLevel == 1.0)
    }

    @Test("Switching back to the default view stops the image being read that way")
    func defaultViewReplacesAStandingChoice() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        #expect(viewModel.applySavedView(label: "Lung window"))
        viewModel.applyDefaultView()

        returnToImage(viewModel)

        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.zoomLevel == 1.0)
    }

    @Test("A standing choice naming a deleted view falls back to the default")
    func deletedViewDropsTheStandingChoice() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        #expect(viewModel.applySavedView(label: "Lung window"))
        viewModel.deleteSavedView(label: "Lung window")

        // Nothing left to put back, and nothing left to apply either.
        viewModel.offerSavedViewsIfNeeded()

        #expect(viewModel.selectedPresentationStateLabel == nil)
    }

    @Test("A reading is remembered per image, not for the viewer")
    func standingChoiceIsPerImage() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        #expect(viewModel.applySavedView(label: "Lung window"))

        // A different slice of the same study, with its own saved view. The
        // first slice's reading says nothing about this one, so arrival shows
        // this slice's own view.
        let (next, _) = try makeViewModel(
            sopInstanceUID: Self.otherSOPUID,
            store: PresentationStateStore(root: root))
        next.zoomLevel = 1.4
        #expect(next.saveCurrentView(label: "Soft tissue"))
        next.applyDefaultView()
        // As above: a fresh arrival at this slice, carrying the previous
        // slice's label the way a real step leaves it.
        next.appliedViewByImage = [:]
        next.selectedPresentationStateLabel = "Lung window"

        next.offerSavedViewsIfNeeded()

        #expect(next.selectedPresentationStateLabel == "Soft tissue")
    }

    @Test("A different study takes the readings with it")
    func newStudyClearsTheChoices() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")

        viewModel.prepareForNewStudy()
        #expect(viewModel.savedViewPrompt == nil)
        #expect(viewModel.appliedViewByImage.isEmpty)
    }

    // MARK: - The default is one badge step away

    @Test("The badge steps from the arrival view to the default")
    func badgeReachesTheDefaultFromArrival() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()
        #expect(abs(viewModel.zoomLevel - 2.5) < 0.05)

        #expect(viewModel.applyNextSavedView() == ImageViewerViewModel.defaultViewLabel)
        #expect(viewModel.selectedViewLabel == ImageViewerViewModel.defaultViewLabel)
        #expect(viewModel.zoomLevel == 1.0, "the default step really resets the picture")
    }

    // MARK: - The name offered when saving

    @Test("An image with a saved view offers its name in the save box")
    func savePromptOffersTheExistingViewName() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        // A fresh arrival: the view is in the store and nothing has been
        // applied yet. The reader who now saves means to update the view the
        // picker is showing, not to start a second one.
        #expect(viewModel.savePromptLabel == "Lung window")
    }

    @Test("The newest saved view is the one offered")
    func savePromptOffersTheNewestView() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 1.8
        #expect(viewModel.saveCurrentView(label: "Bone window"))
        viewModel.applyDefaultView()
        viewModel.appliedViewByImage = [:]
        viewModel.selectedPresentationStateLabel = nil

        // Whatever the store lists first is what the picker shows first, so it
        // is what the box must agree with.
        let newest = try #require(viewModel.savedViewsForCurrentImage.first)
        #expect(viewModel.savePromptLabel == newest.label)
    }

    @Test("An image with nothing saved offers a blank name")
    func savePromptIsBlankWithNothingSaved() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        #expect(viewModel.savePromptLabel.isEmpty)
    }

    @Test("Choosing the default view keeps the save box blank")
    func savePromptIsBlankAfterChoosingTheDefault() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        // Arrival shows the view; the badge steps past it to the default — a
        // deliberate "no, the file's own view", which is not a half-typed name
        // for the saved one. Saving from here is starting something new.
        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.applyNextSavedView() == ImageViewerViewModel.defaultViewLabel)

        #expect(viewModel.savePromptLabel.isEmpty)
    }

    @Test("An applied view's name survives a tool edit")
    func savePromptSurvivesAToolEdit() throws {
        let (viewModel, root) = try makeViewModelWithSavedView()
        defer { cleanUp(root) }

        viewModel.offerSavedViewsIfNeeded()
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")

        // Nudging the window drops the picker's checkmark, because what is on
        // screen is no longer the view as saved — but the reader is still
        // revising that view.
        viewModel.presentationStateFollowsTools()

        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.savePromptLabel == "Lung window")
    }
}
