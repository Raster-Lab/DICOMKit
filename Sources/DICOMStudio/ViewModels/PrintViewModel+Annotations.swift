// PrintViewModel+Annotations.swift
// DICOMStudio
//
// DICOM Studio — the print tray's forwarding surface onto the annotations
// drawn on marked images.
//
// The annotations themselves are stored on `PrintViewModel.selection` (a
// `PrintSelectionModel`), not here — see `PrintSelectionModel+Annotations.swift`
// — because that store must be reachable from the main viewer even when this
// print sheet has never been opened. This file only forwards the print
// tray's `forItemID:`-shaped calls to it, so the tray's views did not need
// to change when the storage moved.
//
// Nothing here renders. See ``ImageAnnotationBurner`` for the CPU drawing
// that reaches the printer and ``AnnotationTextureBuilder`` for the GPU
// texture the main viewer composites.

import Foundation
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintViewModel {

    // MARK: - Reading

    /// The annotations drawn on one cell's image, in the order they were added.
    public func annotations(forItemID itemID: String) -> [PrintOverlayAnnotation] {
        selection.annotations(forItemID: itemID)
    }

    /// Every cell's annotations, keyed by mark ID, blank ones dropped.
    ///
    /// This is what the print run burns: a text box the user opened and never
    /// typed into is not something to draw on film.
    public var annotationsForPrinting: [String: [PrintOverlayAnnotation]] {
        selection.annotationsForPrinting
    }

    /// Whether any cell carries a drawn annotation.
    public var hasAnnotations: Bool {
        selection.hasAnnotations
    }

    /// The annotation the inspector is editing, with the cell it belongs to.
    ///
    /// Always paired with a mark ID here: the print tray only ever selects an
    /// annotation by tapping it on a cell, so by construction a mark exists.
    public var selectedAnnotation: (itemID: String, annotation: PrintOverlayAnnotation)? {
        guard let selected = selection.selectedAnnotation, let itemID = selected.itemID else { return nil }
        return (itemID, selected.annotation)
    }

    // MARK: - Adding

    /// Puts a line of text on a cell at a point, and selects it for editing.
    @discardableResult
    public func addTextAnnotation(
        forItemID itemID: String,
        at point: PrintOverlayPoint
    ) -> UUID {
        selection.addTextAnnotation(forItemID: itemID, at: point)
    }

    /// Puts an arrow on a cell, tail to head, and selects it.
    @discardableResult
    public func addArrowAnnotation(
        forItemID itemID: String,
        from start: PrintOverlayPoint,
        to end: PrintOverlayPoint
    ) -> UUID {
        selection.addArrowAnnotation(forItemID: itemID, from: start, to: end)
    }

    // MARK: - Editing

    /// Selects an annotation, or clears the selection with `nil`.
    public func selectAnnotation(_ id: UUID?) {
        selection.selectAnnotation(id)
    }

    /// Removes text annotations that were never typed into, other than one.
    public func discardEmptyText(except keptID: UUID?) {
        selection.discardEmptyText(except: keptID)
    }

    /// Moves an annotation bodily by a normalized delta — both ends, so an arrow
    /// keeps its length and direction.
    public func moveAnnotation(_ id: UUID, forItemID itemID: String, dx: Double, dy: Double) {
        selection.moveAnnotation(id, forItemID: itemID, dx: dx, dy: dy)
    }

    /// Drags one end of an arrow, leaving the other where it is.
    public func moveArrowEnd(
        _ id: UUID,
        forItemID itemID: String,
        isHead: Bool,
        to point: PrintOverlayPoint
    ) {
        selection.moveArrowEnd(id, forItemID: itemID, isHead: isHead, to: point)
    }

    /// Puts an annotation at an absolute point (its top-left, or an arrow's tail
    /// with the head carried along).
    public func placeAnnotation(_ id: UUID, forItemID itemID: String, at point: PrintOverlayPoint) {
        selection.placeAnnotation(id, forItemID: itemID, at: point)
    }

    public func setAnnotationText(_ text: String, id: UUID, forItemID itemID: String) {
        selection.setAnnotationText(text, id: id, forItemID: itemID)
    }

    /// Sets one annotation's size, and adopts it as the size for the next one.
    public func setAnnotationScale(_ scale: Double, id: UUID, forItemID itemID: String) {
        selection.setAnnotationScale(scale, id: id, forItemID: itemID)
    }

    public func setAnnotationColor(_ color: PrintOverlayColor, id: UUID, forItemID itemID: String) {
        selection.setAnnotationColor(color, id: id, forItemID: itemID)
    }

    // MARK: - Removing

    /// Deletes one annotation.
    public func removeAnnotation(_ id: UUID, forItemID itemID: String) {
        selection.removeAnnotation(id, forItemID: itemID)
    }

    /// Deletes whatever is selected, if anything.
    @discardableResult
    public func removeSelectedAnnotation() -> Bool {
        selection.removeSelectedAnnotation()
    }

    /// Clears one cell.
    public func clearAnnotations(forItemID itemID: String) {
        selection.clearAnnotations(forItemID: itemID)
    }

    /// Clears the whole film.
    public func clearAllAnnotations() {
        selection.clearAllAnnotations()
    }

    /// Drops annotations belonging to images no mark points at anymore.
    public func pruneAnnotations() {
        selection.pruneAnnotations()
    }
}
