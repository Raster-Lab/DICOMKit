// PrintSelectionModel+Annotations.swift
// DICOMStudio
//
// DICOM Studio — the text and arrows a reader draws on an image.
//
// An annotation belongs to the image it is drawn on, not to any one film
// mark: the same frame can be marked onto more than one film cell, and the
// main viewer shows an image's annotations whether or not that image is
// marked at all. They are held per image identity, in coordinates normalized
// to the image, and the same values drive the print-tray preview overlay,
// the main viewer's GPU overlay, and (while a print run is composing) the
// burn into film pixels.
//
// Nothing here renders. See ``ImageAnnotationBurner`` for the CPU drawing
// that reaches the printer and ``AnnotationTextureBuilder`` for the GPU
// texture the main viewer composites.

import Foundation
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintSelectionModel {

    // MARK: - Reading

    /// The annotations drawn on one mark's image, in the order they were added.
    public func annotations(forItemID itemID: String) -> [PrintOverlayAnnotation] {
        guard let key = annotationKey(forItemID: itemID) else { return [] }
        return cellAnnotations[key] ?? []
    }

    /// Every marked image's annotations, keyed by mark ID, blank ones dropped.
    ///
    /// This is what a print run burns: a text box the user opened and never
    /// typed into is not something to draw on film. Two marks that point at
    /// the same image share one annotation set in storage; this join expands
    /// that back out to per-mark keying, because a print job burns per mark
    /// (the same frame marked onto two film cells is burned twice).
    public var annotationsForPrinting: [String: [PrintOverlayAnnotation]] {
        var result: [String: [PrintOverlayAnnotation]] = [:]
        for item in items {
            guard let overlays = cellAnnotations[item.annotationKey] else { continue }
            let drawable = overlays.filter { !$0.isBlank }
            if !drawable.isEmpty { result[item.id] = drawable }
        }
        return result
    }

    /// Whether any image carries a drawn annotation.
    public var hasAnnotations: Bool {
        !annotationsForPrinting.isEmpty
    }

    /// The annotation the inspector is editing, with the mark it belongs to.
    ///
    /// `itemID` is `nil` when the annotation's image is not currently marked
    /// on the tray (e.g. it was drawn from the main viewer only) — callers
    /// that need a mark ID for a `forItemID:` call should treat that as "no
    /// tray cell to point at" rather than fall back to a synthetic ID.
    public var selectedAnnotation: (itemID: String?, annotation: PrintOverlayAnnotation)? {
        guard let selectedAnnotationID else { return nil }
        for (key, overlays) in cellAnnotations {
            if let match = overlays.first(where: { $0.id == selectedAnnotationID }) {
                let itemID = items.first { $0.annotationKey == key }?.id
                return (itemID, match)
            }
        }
        return nil
    }

    // MARK: - Adding

    /// Puts a line of text on a mark's image at a point, and selects it for
    /// editing.
    ///
    /// Created empty rather than with placeholder words: placeholder text
    /// that nobody clears is how "Text" ends up printed on a film.
    @discardableResult
    public func addTextAnnotation(
        forItemID itemID: String,
        at point: PrintOverlayPoint
    ) -> UUID {
        let annotation = PrintOverlayAnnotation(
            kind: .text,
            start: point,
            text: "",
            scale: annotationScale,
            color: annotationColor)
        if let key = annotationKey(forItemID: itemID) {
            cellAnnotations[key, default: []].append(annotation)
        }
        selectAnnotation(annotation.id)
        return annotation.id
    }

    /// Puts an arrow on a mark's image, tail to head, and selects it.
    @discardableResult
    public func addArrowAnnotation(
        forItemID itemID: String,
        from start: PrintOverlayPoint,
        to end: PrintOverlayPoint
    ) -> UUID {
        let annotation = PrintOverlayAnnotation(
            kind: .arrow,
            start: start,
            end: end,
            scale: annotationScale,
            color: annotationColor)
        if let key = annotationKey(forItemID: itemID) {
            cellAnnotations[key, default: []].append(annotation)
        }
        selectAnnotation(annotation.id)
        return annotation.id
    }

    // MARK: - Editing

    /// Selects an annotation, or clears the selection with `nil`.
    ///
    /// Selecting something else abandons a text box that was never typed into. A
    /// text annotation is created empty and only exists to be typed into, so one
    /// left behind is a slip, not a decision — and an empty box that lingers on the
    /// preview looks exactly like text that failed to print.
    public func selectAnnotation(_ id: UUID?) {
        discardEmptyText(except: id)
        selectedAnnotationID = id
    }

    /// Removes text annotations that were never typed into, other than one.
    public func discardEmptyText(except keptID: UUID?) {
        for (key, overlays) in cellAnnotations {
            let kept = overlays.filter { overlay in
                overlay.kind != .text || !overlay.text.isEmpty || overlay.id == keptID
            }
            guard kept.count != overlays.count else { continue }
            cellAnnotations[key] = kept.isEmpty ? nil : kept
        }
    }

    /// Moves an annotation bodily by a normalized delta — both ends, so an arrow
    /// keeps its length and direction.
    public func moveAnnotation(_ id: UUID, forItemID itemID: String, dx: Double, dy: Double) {
        mutate(id, forItemID: itemID) { $0 = $0.moved(dx: dx, dy: dy) }
    }

    /// Drags one end of an arrow, leaving the other where it is.
    public func moveArrowEnd(
        _ id: UUID,
        forItemID itemID: String,
        isHead: Bool,
        to point: PrintOverlayPoint
    ) {
        mutate(id, forItemID: itemID) { annotation in
            guard annotation.kind == .arrow else { return }
            if isHead {
                annotation.end = point
            } else {
                annotation.start = point
            }
        }
    }

    /// Puts an annotation at an absolute point (its top-left, or an arrow's tail
    /// with the head carried along).
    public func placeAnnotation(_ id: UUID, forItemID itemID: String, at point: PrintOverlayPoint) {
        guard let existing = annotations(forItemID: itemID).first(where: { $0.id == id }) else { return }
        moveAnnotation(id, forItemID: itemID,
                       dx: point.x - existing.start.x,
                       dy: point.y - existing.start.y)
    }

    public func setAnnotationText(_ text: String, id: UUID, forItemID itemID: String) {
        mutate(id, forItemID: itemID) { $0.text = text }
    }

    /// Sets one annotation's size, and adopts it as the size for the next one —
    /// a reader who has decided how big their annotations should be has decided
    /// it for the whole film, not for one cell.
    public func setAnnotationScale(_ scale: Double, id: UUID, forItemID itemID: String) {
        mutate(id, forItemID: itemID) { $0 = $0.withScale(scale) }
        annotationScale = PrintOverlayAnnotation.clampScale(scale)
    }

    public func setAnnotationColor(_ color: PrintOverlayColor, id: UUID, forItemID itemID: String) {
        mutate(id, forItemID: itemID) { $0.color = color }
        annotationColor = color
    }

    // MARK: - Removing

    /// Deletes one annotation.
    public func removeAnnotation(_ id: UUID, forItemID itemID: String) {
        guard let key = annotationKey(forItemID: itemID) else { return }
        cellAnnotations[key]?.removeAll { $0.id == id }
        if cellAnnotations[key]?.isEmpty == true { cellAnnotations[key] = nil }
        if selectedAnnotationID == id { selectedAnnotationID = nil }
    }

    /// Deletes whatever is selected, if anything.
    @discardableResult
    public func removeSelectedAnnotation() -> Bool {
        guard let selected = selectedAnnotation, let itemID = selected.itemID else { return false }
        removeAnnotation(selected.annotation.id, forItemID: itemID)
        return true
    }

    /// Clears one mark's image of annotations.
    public func clearAnnotations(forItemID itemID: String) {
        guard let key = annotationKey(forItemID: itemID) else { return }
        if let ids = cellAnnotations[key]?.map(\.id), ids.contains(where: { $0 == selectedAnnotationID }) {
            selectedAnnotationID = nil
        }
        cellAnnotations[key] = nil
    }

    /// Clears every drawn annotation.
    public func clearAllAnnotations() {
        cellAnnotations = [:]
        selectedAnnotationID = nil
    }

    /// Drops annotations belonging to images that are no longer marked.
    ///
    /// Unmarking an image and marking it again is a routine thing to do while
    /// composing a film; what must not happen is annotations outliving every
    /// mark that pointed at their image and reappearing on some later film.
    /// An image still shown in the main viewer (marked or not) is unaffected
    /// by this — pruning only removes keys with no live mark at all.
    public func pruneAnnotations() {
        let live = Set(items.map(\.annotationKey))
        for key in cellAnnotations.keys where !live.contains(key) {
            cellAnnotations[key] = nil
        }
        if let selectedAnnotationID,
           !cellAnnotations.values.flatMap({ $0 }).contains(where: { $0.id == selectedAnnotationID }) {
            self.selectedAnnotationID = nil
        }
    }

    // MARK: - Plumbing

    /// Resolves a print-tray mark ID to the image identity its annotations
    /// are stored under. `nil` when the mark is no longer selected —
    /// annotation calls against a mark that just left the tray are then
    /// no-ops, same as before this store moved off the mark's own ID.
    private func annotationKey(forItemID itemID: String) -> ImageAnnotationKey? {
        items.first { $0.id == itemID }?.annotationKey
    }

    /// Edits one annotation in place, if it is still there.
    private func mutate(
        _ id: UUID,
        forItemID itemID: String,
        _ transform: (inout PrintOverlayAnnotation) -> Void
    ) {
        guard let key = annotationKey(forItemID: itemID),
              var overlays = cellAnnotations[key],
              let index = overlays.firstIndex(where: { $0.id == id }) else { return }
        transform(&overlays[index])
        cellAnnotations[key] = overlays
    }
}
