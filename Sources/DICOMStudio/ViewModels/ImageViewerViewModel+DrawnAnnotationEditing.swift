// ImageViewerViewModel+DrawnAnnotationEditing.swift
// DICOMStudio
//
// Editing the drawn annotations of the image on screen — the viewer-side twin
// of `PrintViewModel+Annotations`.
//
// The store is the same one the print screen edits (`printSelection`, keyed by
// image identity), so an arrow drawn here is on the film the moment the image
// is marked, and an arrow drawn on a film cell is on this screen the moment
// the image is shown. What differs is only the address: the print screen edits
// through a mark ID, the viewer through ``currentAnnotationKey`` — the image
// itself, marked or not.

import Foundation
import DICOMPrintKit

extension ImageViewerViewModel {

    /// Puts an empty text annotation on the image on screen and selects it, so
    /// the overlay opens it for typing. `nil` when no image is loaded.
    @discardableResult
    public func addDrawnTextAnnotation(at point: PrintOverlayPoint) -> UUID? {
        guard let key = currentAnnotationKey else { return nil }
        let id = printSelection.addTextAnnotation(forKey: key, at: point)
        drawnAnnotationsFollowTools()
        return id
    }

    /// Puts a combined annotation on the image on screen and selects it, so
    /// the overlay opens it for typing. `anchor` is the point its arrow names;
    /// `nil` (or the label point itself) starts it as plain words.
    @discardableResult
    public func addDrawnAnnotation(
        at start: PrintOverlayPoint, anchor: PrintOverlayPoint? = nil
    ) -> UUID? {
        guard let key = currentAnnotationKey else { return nil }
        let id = printSelection.addAnnotation(forKey: key, at: start, anchor: anchor)
        drawnAnnotationsFollowTools()
        return id
    }

    /// Puts an arrow on the image on screen, tail to head, and selects it.
    @discardableResult
    public func addDrawnArrowAnnotation(
        from start: PrintOverlayPoint, to end: PrintOverlayPoint
    ) -> UUID? {
        guard let key = currentAnnotationKey else { return nil }
        let id = printSelection.addArrowAnnotation(forKey: key, from: start, to: end)
        drawnAnnotationsFollowTools()
        return id
    }

    /// Moves an annotation bodily by a normalized delta.
    public func moveDrawnAnnotation(_ id: UUID, dx: Double, dy: Double) {
        guard let key = currentAnnotationKey else { return }
        printSelection.moveAnnotation(id, forKey: key, dx: dx, dy: dy)
        drawnAnnotationsFollowTools()
    }

    /// Drags one end of an arrow, leaving the other where it is.
    public func moveDrawnArrowEnd(_ id: UUID, isHead: Bool, to point: PrintOverlayPoint) {
        guard let key = currentAnnotationKey else { return }
        printSelection.moveArrowEnd(id, forKey: key, isHead: isHead, to: point)
        drawnAnnotationsFollowTools()
    }

    /// Swings a combined annotation's label around the point its arrow names,
    /// keeping their distance — the orbit handle's edit.
    ///
    /// `direction` is in image space, not screen space: the caller maps the
    /// pointer through the same transform the picture is drawn with, so the
    /// label follows the hand on a turned or mirrored image too.
    public func orbitDrawnAnnotationLabel(
        _ id: UUID, towards direction: (dx: Double, dy: Double)
    ) {
        guard let key = currentAnnotationKey else { return }
        printSelection.orbitAnnotationLabel(
            id, forKey: key, towards: direction,
            imageWidth: Double(imageColumns), imageHeight: Double(imageRows))
        drawnAnnotationsFollowTools()
    }

    /// Sets an annotation's words.
    public func setDrawnAnnotationText(_ text: String, id: UUID) {
        guard let key = currentAnnotationKey else { return }
        printSelection.setAnnotationText(text, id: id, forKey: key)
        drawnAnnotationsFollowTools()
    }

    /// Sets an annotation's size, which also becomes the size of the next one.
    public func setDrawnAnnotationScale(_ scale: Double, id: UUID) {
        guard let key = currentAnnotationKey else { return }
        printSelection.setAnnotationScale(scale, id: id, forKey: key)
        drawnAnnotationsFollowTools()
    }

    /// Sets an annotation's colour, which also becomes the next one's.
    public func setDrawnAnnotationColor(_ color: PrintOverlayColor, id: UUID) {
        guard let key = currentAnnotationKey else { return }
        printSelection.setAnnotationColor(color, id: id, forKey: key)
        drawnAnnotationsFollowTools()
    }

    /// Deletes one annotation from the image on screen.
    public func removeDrawnAnnotation(_ id: UUID) {
        guard let key = currentAnnotationKey else { return }
        printSelection.removeAnnotation(id, forKey: key)
        drawnAnnotationsFollowTools()
    }

    /// Deletes whatever is selected, if anything. Wherever it lives — a
    /// selection can outlast a frame step, and the delete key must still work.
    @discardableResult
    public func removeSelectedDrawnAnnotation() -> Bool {
        let removed = printSelection.removeSelectedAnnotation()
        if removed { drawnAnnotationsFollowTools() }
        return removed
    }

    /// Selects an annotation, or clears the selection with `nil`.
    public func selectDrawnAnnotation(_ id: UUID?) {
        printSelection.selectAnnotation(id)
    }

    /// A drawing edit is a tool action: what is on screen afterwards is no
    /// longer the saved view the picker may still be naming.
    private func drawnAnnotationsFollowTools() {
        presentationStateFollowsTools()
    }
}
