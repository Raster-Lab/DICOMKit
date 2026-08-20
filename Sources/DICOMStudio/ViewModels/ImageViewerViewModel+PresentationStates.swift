// ImageViewerViewModel+PresentationStates.swift
// DICOMStudio
//
// Saving what a reader is looking at, and putting it back.
//
// The viewer holds one extra idea because of this: a *selected* view. It starts
// as the default — the image as the file describes it — and naming one of the
// saved views applies that instead. The selection is remembered per image so
// stepping through a series does not silently drop it, and cleared whenever the
// reader moves a tool, because at that point what is on screen is no longer the
// view that was saved.

import Foundation
import DICOMKit
import DICOMCore
import DICOMPrintKit

extension ImageViewerViewModel {

    // MARK: - Listing

    /// The saved views that apply to the image on screen.
    ///
    /// Empty when nothing has been saved for it — the picker then has only the
    /// default view to offer, and hides itself.
    public var savedViewsForCurrentImage: [SavedView] {
        guard let studyInstanceUID, let sopInstanceUID,
              let store = presentationStateStore else { return [] }
        return store.views(forStudy: studyInstanceUID, image: sopInstanceUID)
    }

    /// Whether there is anything to choose between.
    public var hasSavedViews: Bool { !savedViewsForCurrentImage.isEmpty }

    /// The name shown on the picker: the selected view, or the default.
    public var selectedViewLabel: String {
        selectedPresentationStateLabel ?? Self.defaultViewLabel
    }

    /// What the picker calls the image as the file describes it.
    public static let defaultViewLabel = "Default view"

    // MARK: - Drawn annotations

    /// This image's identity in the annotation store.
    ///
    /// Keyed on file path and frame rather than SOP Instance UID, matching
    /// ``ImageAnnotationKey`` — a multi-tile layout leaves the UID nil for
    /// unfocused tiles, so keying on it would drop their annotations.
    var currentAnnotationKey: ImageAnnotationKey? {
        guard let filePath else { return nil }
        return ImageAnnotationKey(filePath: filePath, frameIndex: currentFrameIndex)
    }

    /// The text and arrows drawn on the image on screen.
    var currentDrawnAnnotations: [PrintOverlayAnnotation] {
        guard let key = currentAnnotationKey else { return [] }
        return printSelection.cellAnnotations[key] ?? []
    }

    // MARK: - Saving

    /// Whether the current view is worth offering to save.
    ///
    /// An untouched image has nothing in it that the file does not already say,
    /// so saving it would add an entry to the picker that changes nothing.
    public var canSaveCurrentView: Bool {
        guard studyInstanceUID != nil, sopInstanceUID != nil,
              dicomFile != nil else { return false }
        // Any tool moved, or a window the reader chose: `isIdentity` covers
        // zoom, pan, rotation, flips and inversion, and a changed window is the
        // other thing worth naming a view for. A drawing counts on its own —
        // an untouched image with an arrow on it is worth saving, and was not
        // offerable before annotations were part of a view.
        return !currentPresentation.isIdentity
            || hasReaderChosenWindow
            || currentDrawnAnnotations.contains { !$0.isBlank }
    }

    /// Saves the current view under a name.
    ///
    /// Only the image on screen is recorded. A reader who wants a window across
    /// a whole series saves it on each image they care about — which is also
    /// what makes the picker's per-image list honest.
    ///
    /// - Returns: Whether anything was written.
    @discardableResult
    public func saveCurrentView(label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let studyInstanceUID,
              let sopInstanceUID,
              let file = dicomFile,
              let store = presentationStateStore else { return false }

        let sopClassUID = file.dataSet.string(for: .sopClassUID)
            ?? "1.2.840.10008.5.1.4.1.1.7"

        let display = ViewerPresentationStateBridge.capture(
            presentation: currentPresentation,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            imageWidth: imageColumns,
            imageHeight: imageRows)

        var context = PresentationStatePatientContext.make(from: file.dataSet)
        // The data set is the authority on study identity, but a file loaded
        // without one would otherwise be filed under an empty UID.
        if context.studyInstanceUID.isEmpty {
            context.studyInstanceUID = studyInstanceUID
        }

        let image = PresentationStateStore.ImageToSave(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            seriesInstanceUID: currentSeriesUID
                ?? file.dataSet.string(for: .seriesInstanceUID) ?? "",
            display: display,
            annotations: currentDrawnAnnotations)

        do {
            let saved = try store.save(
                images: [image], label: trimmed, patient: context)
            guard saved != nil else { return false }
            // The reader is now looking at the view they just named.
            selectedPresentationStateLabel = trimmed
            presentationStateError = nil
            return true
        } catch {
            presentationStateError = "Could not save the view: \(error.localizedDescription)"
            return false
        }
    }

    /// Removes a saved view from the study.
    public func deleteSavedView(label: String) {
        guard let studyInstanceUID, let store = presentationStateStore else { return }
        do {
            try store.deleteView(label: label, studyInstanceUID: studyInstanceUID)
            if selectedPresentationStateLabel == label {
                selectedPresentationStateLabel = nil
            }
            presentationStateError = nil
        } catch {
            presentationStateError = "Could not delete the view: \(error.localizedDescription)"
        }
    }

    // MARK: - Applying

    /// Puts the image back to how the file describes it.
    ///
    /// "The image as the file describes it" includes carrying no drawings: the
    /// file describes none, so the default view shows none. Picking it after
    /// reading a marked-up view therefore gives a clean image — window, zoom
    /// and orientation reset, arrows and labels gone, and only the corner
    /// identification text, which is drawn from the data set rather than
    /// drawn by the reader.
    ///
    /// The drawings are not lost by this. They were written into the saved
    /// view when it was saved, so choosing that view again brings them back;
    /// what this clears is the working copy on screen.
    public func applyDefaultView() {
        selectedPresentationStateLabel = nil
        applyingPresentationState = true
        defer { applyingPresentationState = false }
        resetTransformations()
        // Inversion is part of a view, not a separate mode: ``canSaveCurrentView``
        // offers to save an image *because* it is inverted (`isIdentity` counts
        // `invert`), and `applySavedView` restores it. `resetTransformations` is
        // geometry only, so the default view used to come back still inverted —
        // a presentation state applied to a monochrome image left the greys
        // swapped with the picker claiming the file's own view was on screen.
        isInverted = false
        resetWindowToFileDefault()
        clearDrawnAnnotationsForCurrentImage()
        renderCurrentFrame()
    }

    /// Drops the drawings on the image on screen, leaving other images alone.
    ///
    /// Scoped to the current image because the default view is a statement
    /// about one image: stepping to the next frame and picking it there must
    /// not take the previous frame's arrows with it.
    func clearDrawnAnnotationsForCurrentImage() {
        guard let key = currentAnnotationKey else { return }
        // A selection pointing into the annotations being removed would
        // outlive them, and the editing paths treat a selected id as live.
        if let ids = printSelection.cellAnnotations[key]?.map(\.id),
           ids.contains(where: { $0 == printSelection.selectedAnnotationID }) {
            printSelection.selectedAnnotationID = nil
        }
        printSelection.cellAnnotations[key] = nil
    }

    /// Applies a saved view to the image on screen.
    ///
    /// A view that covers other images but not this one leaves the viewer alone:
    /// the picker does not offer those, but a stale selection carried across a
    /// series step can still land here.
    @discardableResult
    public func applySavedView(_ view: SavedView) -> Bool {
        guard let sopInstanceUID,
              let stored = view.state(forImage: sopInstanceUID) else { return false }

        let restored = ViewerPresentationStateBridge.restore(
            stored.state,
            imageWidth: imageColumns,
            imageHeight: imageRows,
            viewportWidth: viewContentWidth,
            viewportHeight: viewContentHeight)

        // Applied without going through the tool paths: those clear the
        // selection, which would drop the view the moment it was applied.
        applyingPresentationState = true
        defer { applyingPresentationState = false }

        if let center = restored.windowCenter, let width = restored.windowWidth {
            windowCenter = center
            windowWidth = width
        }
        zoomLevel = restored.zoom
        panOffsetX = restored.panX
        panOffsetY = restored.panY
        rotationAngle = restored.rotationDegrees
        isFlippedHorizontal = restored.flipHorizontal
        // GSPS carries no vertical flip: the bridge folded it into the rotation
        // on the way out, so restoring one is always "not flipped vertically".
        isFlippedVertical = false
        if isInverted != restored.invert {
            toggleInversion()
        }

        // The drawings come back with the view. Replacing rather than merging:
        // the saved view is a complete statement of what was on this image, so
        // an arrow deleted before saving must not survive the restore.
        if let key = currentAnnotationKey {
            printSelection.cellAnnotations[key] = stored.annotations
        }

        selectedPresentationStateLabel = view.label
        renderCurrentFrame()
        return true
    }

    /// Applies the saved view of a given name, if the current image has one.
    @discardableResult
    public func applySavedView(label: String) -> Bool {
        guard let view = savedViewsForCurrentImage.first(where: { $0.label == label })
        else { return false }
        return applySavedView(view)
    }

    // MARK: - Keeping the selection honest

    /// Drops the selected view once the reader moves a tool.
    ///
    /// What is on screen after a drag is no longer the view that was saved, and
    /// a picker still naming it would be lying. Called from the tool paths
    /// rather than from the property observers, so that *applying* a state does
    /// not immediately clear itself.
    func presentationStateFollowsTools() {
        guard !applyingPresentationState else { return }
        guard selectedPresentationStateLabel != nil else { return }
        selectedPresentationStateLabel = nil
    }
}
