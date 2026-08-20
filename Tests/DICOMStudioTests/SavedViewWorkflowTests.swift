// SavedViewWorkflowTests.swift
// DICOMStudioTests
//
// The workflow a reader actually performs: adjust an image, save the view under
// a name, come back to it later, pick it out of a list, and carry it to film.
//
// These are viewer-level tests rather than store-level ones — the store's own
// behaviour is covered in DICOMPrintKitTests. What is checked here is the part
// the reader sees: that the picker lists what it should, that applying a view
// puts the tools back, that touching a tool afterwards stops the picker
// claiming the view is still on screen, and that a restored view is what the
// film prints.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Saved View Workflow Tests")
struct SavedViewWorkflowTests {

    // MARK: - Fixtures

    private static let studyUID = "1.2.3.4.5"
    private static let seriesUID = "1.2.3.4.5.6"
    private static let sopUID = "1.2.3.4.5.6.7"

    /// A viewer holding one image, with saved views kept in a temporary place.
    private func makeViewModel() throws -> (ImageViewerViewModel, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedViewWorkflowTests-\(UUID().uuidString)")

        let elements: [DataElement] = [
            .string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2"),
            .string(tag: .sopInstanceUID, vr: .UI, value: Self.sopUID),
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
            sopInstanceUID: Self.sopUID)

        let viewModel = ImageViewerViewModel()
        viewModel.dicomFile = file
        viewModel.filePath = "/tmp/ct.dcm"
        viewModel.sopInstanceUID = Self.sopUID
        viewModel.studyInstanceUID = Self.studyUID
        viewModel.currentSeriesUID = Self.seriesUID
        viewModel.imageColumns = 512
        viewModel.imageRows = 512
        viewModel.viewContentWidth = 800
        viewModel.viewContentHeight = 600
        viewModel.presentationStateStore = PresentationStateStore(root: root)

        return (viewModel, root)
    }

    private func cleanUp(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Saving

    @Test("An untouched image has nothing worth saving")
    func untouchedImageCannotBeSaved() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        // The window matches the file's, and no tool has been moved.
        viewModel.windowCenter = 40
        viewModel.windowWidth = 400

        #expect(viewModel.canSaveCurrentView == false)
    }

    @Test("Moving a tool makes the view worth saving")
    func adjustedImageCanBeSaved() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5

        #expect(viewModel.canSaveCurrentView)
    }

    @Test("Saving names the view and selects it")
    func savingSelectsTheView() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        #expect(viewModel.saveCurrentView(label: "Lung window"))

        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
        #expect(viewModel.selectedViewLabel == "Lung window")
    }

    @Test("An unnamed view is not saved")
    func blankLabelSavesNothing() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5

        #expect(viewModel.saveCurrentView(label: "   ") == false)
        #expect(viewModel.savedViewsForCurrentImage.isEmpty)
    }

    // MARK: - Listing

    @Test("The picker lists the saved views of the image on screen")
    func pickerListsSavedViews() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.zoomLevel = 3
        viewModel.saveCurrentView(label: "Bone window")

        let labels = Set(viewModel.savedViewsForCurrentImage.map(\.label))
        #expect(labels == ["Lung window", "Bone window"])
        #expect(viewModel.hasSavedViews)
    }

    /// The requirement that makes the picker a list rather than a toggle.
    @Test("One image can carry several saved views")
    func oneImageCarriesSeveralViews() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.windowCenter = 300
        viewModel.saveCurrentView(label: "Bone window")
        viewModel.windowCenter = 40
        viewModel.saveCurrentView(label: "Soft tissue")

        #expect(viewModel.savedViewsForCurrentImage.count == 3)
    }

    @Test("A view saved on another image is not offered for this one")
    func viewsOfOtherImagesAreNotListed() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2
        viewModel.saveCurrentView(label: "Lung window")

        // Step to a different image in the same study.
        viewModel.sopInstanceUID = "1.2.3.4.5.6.99"

        #expect(viewModel.savedViewsForCurrentImage.isEmpty)
        #expect(viewModel.hasSavedViews == false)
    }

    // MARK: - Applying

    @Test("Applying a saved view puts the tools back")
    func applyingRestoresTheTools() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.zoomLevel = 2.5
        viewModel.rotationAngle = 90
        viewModel.saveCurrentView(label: "Lung window")

        // Wander off: a different window, a different zoom, no rotation.
        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        viewModel.zoomLevel = 1
        viewModel.rotationAngle = 0

        let view = try #require(viewModel.savedViewsForCurrentImage.first)
        #expect(viewModel.applySavedView(view))

        #expect(viewModel.windowCenter == -600)
        #expect(viewModel.windowWidth == 1500)
        #expect(abs(viewModel.zoomLevel - 2.5) < 0.05)
        #expect(viewModel.rotationAngle == 90)
    }

    @Test("The default view returns the image to what the file says")
    func defaultViewRestoresTheFile() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 3
        viewModel.rotationAngle = 180
        viewModel.saveCurrentView(label: "Zoomed")

        viewModel.applyDefaultView()

        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.selectedViewLabel == ImageViewerViewModel.defaultViewLabel)
        #expect(viewModel.zoomLevel == 1)
        #expect(viewModel.rotationAngle == 0)
    }

    @Test("The default view takes the inversion off with everything else")
    func defaultViewClearsInversion() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        // Inversion is part of a view — it is one of the things that makes an
        // image worth saving, and applying a saved view restores it — so the
        // default view has to undo it too. It did not: `applyDefaultView` reset
        // geometry and window only, and a reader who inverted an image, applied
        // a presentation state and then went back to the default view was left
        // with the greys still swapped under a picker naming the file's own view.
        viewModel.toggleInversion()
        viewModel.zoomLevel = 3
        viewModel.saveCurrentView(label: "Inverted")
        #expect(viewModel.isInverted)

        viewModel.applyDefaultView()

        #expect(!viewModel.isInverted)
        #expect(viewModel.zoomLevel == 1)
        #expect(viewModel.selectedPresentationStateLabel == nil)
    }

    @Test("An inverted view survives the round trip back to it")
    func invertedViewRestoresAfterDefault() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        // The other half of the contract: clearing the inversion on the way to
        // the default view must not cost the saved view its own inversion.
        viewModel.toggleInversion()
        viewModel.saveCurrentView(label: "Inverted")
        viewModel.applyDefaultView()
        #expect(!viewModel.isInverted)

        #expect(viewModel.applySavedView(label: "Inverted"))
        #expect(viewModel.isInverted)
        #expect(viewModel.selectedPresentationStateLabel == "Inverted")
    }

    @Test("A view can be applied by name")
    func applyingByName() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        #expect(viewModel.applySavedView(label: "Lung window"))
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
    }

    @Test("Applying a view that does not cover this image does nothing")
    func applyingAnUncoveringViewIsANoOp() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.saveCurrentView(label: "Lung window")
        let view = try #require(viewModel.savedViewsForCurrentImage.first)

        viewModel.sopInstanceUID = "1.2.3.4.5.6.99"
        #expect(viewModel.applySavedView(view) == false)
    }

    // MARK: - Keeping the picker honest

    /// Once a tool moves, what is on screen is no longer the view that was
    /// saved, and a picker still naming it would be lying.
    @Test("Moving a tool clears the selected view")
    func movingAToolClearsTheSelection() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.saveCurrentView(label: "Lung window")
        #expect(viewModel.selectedPresentationStateLabel == "Lung window")

        viewModel.panOffsetX = 25

        #expect(viewModel.selectedPresentationStateLabel == nil)
        #expect(viewModel.selectedViewLabel == ImageViewerViewModel.defaultViewLabel)
    }

    /// Applying a state moves the very tools that clear the selection, so
    /// without a guard it would immediately clear its own.
    @Test("Applying a view does not clear its own selection")
    func applyingKeepsItsOwnSelection() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.rotationAngle = 90
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let view = try #require(viewModel.savedViewsForCurrentImage.first)
        viewModel.applySavedView(view)

        #expect(viewModel.selectedPresentationStateLabel == "Lung window")
    }

    // MARK: - Deleting

    @Test("Deleting a view removes it from the picker")
    func deletingRemovesFromPicker() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.zoomLevel = 3
        viewModel.saveCurrentView(label: "Bone window")

        viewModel.deleteSavedView(label: "Lung window")

        #expect(viewModel.savedViewsForCurrentImage.map(\.label) == ["Bone window"])
    }

    @Test("Deleting the selected view drops the selection")
    func deletingSelectedViewDropsSelection() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.saveCurrentView(label: "Lung window")

        viewModel.deleteSavedView(label: "Lung window")

        #expect(viewModel.selectedPresentationStateLabel == nil)
    }

    // MARK: - Carrying to film

    /// The last step of the requirement: a restored view is what the film
    /// prints. The print mark reads the viewer's live state, so restoring a
    /// view and marking it must put that view's window and geometry on the film.
    @Test("A restored view is what the print mark carries")
    func restoredViewReachesTheFilm() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.zoomLevel = 2.5
        viewModel.saveCurrentView(label: "Lung window")

        viewModel.applyDefaultView()
        viewModel.applySavedView(label: "Lung window")

        let mark = try #require(viewModel.currentSelectionItem)
        #expect(mark.windowCenter == -600)
        #expect(mark.windowWidth == 1500)
        #expect(abs((mark.presentation?.zoom ?? 0) - 2.5) < 0.05)
    }

    // MARK: - Drawn annotations

    private func arrow() -> PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.3),
            end: PrintOverlayPoint(x: 0.6, y: 0.7))
    }

    private func key(_ viewModel: ImageViewerViewModel) -> ImageAnnotationKey {
        ImageAnnotationKey(
            filePath: viewModel.filePath ?? "", frameIndex: viewModel.currentFrameIndex)
    }

    @Test("A drawing alone makes the view worth saving")
    func drawingAloneCanBeSaved() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        // No tool moved and the file's own window: only the arrow is new.
        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        viewModel.printSelection.cellAnnotations[key(viewModel)] = [arrow()]

        #expect(viewModel.canSaveCurrentView)
    }

    @Test("Drawings come back with the view that carried them")
    func drawingsRestoreWithTheView() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.printSelection.cellAnnotations[key(viewModel)] = [arrow()]
        viewModel.saveCurrentView(label: "Marked up")

        viewModel.applyDefaultView()
        #expect(viewModel.printSelection.cellAnnotations[key(viewModel)] == nil)

        #expect(viewModel.applySavedView(label: "Marked up"))
        let restored = try #require(viewModel.printSelection.cellAnnotations[key(viewModel)])
        #expect(restored.count == 1)
        #expect(restored.first?.kind == .arrow)
    }

    /// The behaviour the reader asked for: after reading a marked-up view,
    /// the default view is a clean image — no tools, no drawings, and only the
    /// corner identification text, which is drawn from the data set.
    @Test("The default view shows no drawings")
    func defaultViewClearsDrawings() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.zoomLevel = 2.5
        viewModel.printSelection.cellAnnotations[key(viewModel)] = [arrow()]
        viewModel.saveCurrentView(label: "Marked up")
        #expect(viewModel.applySavedView(label: "Marked up"))

        viewModel.applyDefaultView()

        #expect(viewModel.printSelection.cellAnnotations[key(viewModel)] == nil)
        #expect(viewModel.zoomLevel == 1)
        #expect(viewModel.selectedPresentationStateLabel == nil)
    }

    @Test("Clearing drawings drops a selection pointing into them")
    func defaultViewClearsTheSelection() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        let drawn = arrow()
        viewModel.printSelection.cellAnnotations[key(viewModel)] = [drawn]
        viewModel.printSelection.selectedAnnotationID = drawn.id

        viewModel.applyDefaultView()

        // A selection outliving its annotation would have the editing paths
        // acting on an id that no longer resolves.
        #expect(viewModel.printSelection.selectedAnnotationID == nil)
    }

    @Test("The default view leaves other images' drawings alone")
    func defaultViewIsScopedToTheCurrentImage() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        let otherFrame = ImageAnnotationKey(
            filePath: viewModel.filePath ?? "", frameIndex: 7)
        viewModel.printSelection.cellAnnotations[key(viewModel)] = [arrow()]
        viewModel.printSelection.cellAnnotations[otherFrame] = [arrow()]

        viewModel.applyDefaultView()

        #expect(viewModel.printSelection.cellAnnotations[key(viewModel)] == nil)
        #expect(viewModel.printSelection.cellAnnotations[otherFrame]?.count == 1)
    }

    // MARK: - Saved views on the print screen

    /// A print screen wired to the same store as a viewer, with the viewer's
    /// current frame marked for film.
    ///
    /// The mark is made from the *default* view, so nothing the tests below
    /// observe on a cell can have arrived by the mark having been taken while a
    /// saved view happened to be applied.
    private func makePrintViewModel(
        _ viewModel: ImageViewerViewModel
    ) -> PrintViewModel {
        let print = PrintViewModel(selection: viewModel.printSelection)
        print.presentationStateStore = viewModel.presentationStateStore
        print.presentationStateStudyUID = viewModel.studyInstanceUID
        return print
    }

    @Test("A film opens on the images as marked, adopting nothing")
    func filmOpensWithoutAdoptingSavedViews() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        // A saved view is a reading decision; the film is a different artefact.
        // The screen used to open with every saved state already baked into the
        // cells, so a reader who never asked for them had to work out which
        // job-wide switch was responsible and turn it off.
        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        #expect(print.applySavedPresentationStates == false)

        await print.adoptSavedViewsWhereUntouched()

        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == 40)
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
    }

    @Test("Reopening a film puts the switch back off and drops what it adopted")
    func reopeningTheFilmResetsAdoption() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        print.applySavedPresentationStates = true
        await print.adoptSavedViewsWhereUntouched()
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == "Lung window")

        // The next visit. The switch is a per-visit decision, and the cells go
        // back to the marks the viewer made — a reopened screen showing the last
        // visit's arrangement with the switch reading off was the reported bug.
        print.resetForNewFilm()

        #expect(print.applySavedPresentationStates == false)
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == 40)
    }

    @Test("Toggling the switch off and on again settles, leaving the tools live")
    func togglingTheSwitchSettles() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)

        // Each flip starts a pass and cancels the one before it. Unmanaged these
        // piled up — every write was observed, every observation asked for
        // another pass — and the print screen stopped answering.
        for _ in 0..<5 {
            print.applySavedPresentationStates = true
            print.applySavedPresentationStates = false
        }
        print.applySavedPresentationStates = true

        // The final state wins, and the work is finishable rather than endless.
        await print.adoptSavedViewsWhereUntouched()
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == "Lung window")

        print.applySavedPresentationStates = false
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == 40)
    }

    @Test("A superseded adoption pass stops instead of writing over the newer one")
    func cancelledAdoptionStops() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        print.applySavedPresentationStates = true

        // A pass that is cancelled before it starts must not write at all.
        let task = Task { await print.adoptSavedViewsWhereUntouched() }
        task.cancel()
        await task.value

        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
    }

    @Test("The print screen offers a cell the views saved for its image")
    func printScreenListsSavedViews() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)

        #expect(print.savedViews(forItemID: mark.id).map(\.label) == ["Lung window"])
        #expect(print.hasSavedViewsForAnyCell)
        #expect(print.savedViewLabelsOnFilm == ["Lung window"])
    }

    @Test("Applying a saved view to a cell gives it that view's window")
    func applyingSavedViewWindowsTheCell() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        // Marked at the file's own window, not the saved one.
        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        let applied = await print.applySavedView(label: "Lung window", toItemID: mark.id)

        #expect(applied)
        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == -600)
        #expect(cell.windowWidth == 1500)
        #expect(print.savedViewSelectionLabel(forItemID: mark.id) == "Lung window")
    }

    @Test("A cell that took a saved view stops following the viewer")
    func appliedViewDefendsTheCell() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        await print.applySavedView(label: "Lung window", toItemID: mark.id)

        // Applying a view is the reader's own choice, so it must survive a
        // re-sync from the viewer exactly as a windowing drag does.
        #expect(print.isCellAdjusted(mark.id))
    }

    @Test("Taking the saved view back off returns the cell to how it was marked")
    func clearingSavedViewRestoresTheMark() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        await print.applySavedView(label: "Lung window", toItemID: mark.id)
        print.clearSavedView(forItemID: mark.id)

        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == 40)
        #expect(cell.windowWidth == 400)
        #expect(print.savedViewSelectionLabel(forItemID: mark.id)
                == PrintViewModel.defaultViewLabel)
    }

    @Test("A fresh sheet adopts each image's saved view")
    func freshSheetAdoptsSavedViews() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        // The switch is off when a film opens, so adoption is asked for. This
        // test is about what adoption does once requested, not about whether it
        // runs unbidden — `filmOpensWithoutAdoptingSavedViews` covers that.
        print.applySavedPresentationStates = true
        await print.adoptSavedViewsWhereUntouched()

        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == -600)
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == "Lung window")
    }

    @Test("Adoption leaves a cell the reader adjusted here alone")
    func adoptionSparesHandAdjustedCells() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        // The reader windows this cell on the print screen first.
        print.setWindow(forItemID: mark.id, center: 100, width: 200)

        await print.adoptSavedViewsWhereUntouched()

        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == 100)
        #expect(cell.windowWidth == 200)
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
    }

    @Test("Adoption does nothing while the job-wide switch is off")
    func adoptionRespectsTheSwitch() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        viewModel.windowCenter = 40
        viewModel.windowWidth = 400
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        print.applySavedPresentationStates = false
        await print.adoptSavedViewsWhereUntouched()

        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == 40)
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
    }

    @Test("A named default decides which view the cells adopt")
    func namedDefaultChoosesTheView() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")

        viewModel.windowCenter = 300
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Bone window")

        viewModel.applyDefaultView()
        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        print.applySavedPresentationStates = true
        print.defaultSavedViewLabel = "Lung window"
        await print.adoptSavedViewsWhereUntouched()

        let cell = try #require(print.selection.items.first { $0.id == mark.id })
        #expect(cell.windowCenter == -600)
        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == "Lung window")
    }

    @Test("The drawings saved with a view come onto the film cell")
    func appliedViewCarriesItsDrawings() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.printSelection.cellAnnotations[key(viewModel)] = [arrow()]
        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)
        #expect(viewModel.printSelection.cellAnnotations[mark.annotationKey] == nil)

        let print = makePrintViewModel(viewModel)
        await print.applySavedView(label: "Lung window", toItemID: mark.id)

        #expect(print.selection.cellAnnotations[mark.annotationKey]?.count == 1)
    }

    @Test("A mark with no saved view is offered none")
    func markWithoutSavedViewsIsOfferedNone() throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)

        #expect(print.savedViews(forItemID: mark.id).isEmpty)
        #expect(print.hasSavedViewsForAnyCell == false)
    }

    @Test("Resetting a cell stops it naming a saved view")
    func resettingClearsTheAppliedView() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        await print.applySavedView(label: "Lung window", toItemID: mark.id)
        print.resetCell(forItemID: mark.id)

        #expect(print.savedViewSelectionLabel(forItemID: mark.id)
                == PrintViewModel.defaultViewLabel)
    }

    @Test("A mark taken off the film leaves no adopted view behind")
    func pruningDropsViewsForVanishedMarks() async throws {
        let (viewModel, root) = try makeViewModel()
        defer { cleanUp(root) }

        viewModel.windowCenter = -600
        viewModel.windowWidth = 1500
        viewModel.saveCurrentView(label: "Lung window")
        viewModel.applyDefaultView()

        let mark = try #require(viewModel.currentSelectionItem)
        viewModel.printSelection.add(mark)

        let print = makePrintViewModel(viewModel)
        await print.applySavedView(label: "Lung window", toItemID: mark.id)

        print.selection.remove(filePath: mark.filePath, frameIndex: mark.frameIndex)
        print.pruneAppliedSavedViews()

        #expect(print.appliedSavedViewLabel(forItemID: mark.id) == nil)
    }
}
