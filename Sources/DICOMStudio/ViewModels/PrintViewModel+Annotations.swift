// PrintViewModel+Annotations.swift
// DICOMStudio
//
// DICOM Studio — the text and arrows a reader draws on a film cell.
//
// An annotation belongs to a mark, not to a film position: re-arranging the film,
// changing the layout or printing to a different sheet must not move an arrow off
// the vessel it was pointing at. So they are held per mark ID, in coordinates
// normalized to the image, and the same values drive both the preview overlay and
// the burn into the printed pixels — the preview cannot show an arrow the film
// will not carry.
//
// Nothing here renders. See ``ImageAnnotationBurner`` for the drawing that
// actually reaches the printer.

import Foundation
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintViewModel {

    // MARK: - Reading

    /// The annotations drawn on one cell, in the order they were added.
    public func annotations(forItemID itemID: String) -> [PrintOverlayAnnotation] {
        cellAnnotations[itemID] ?? []
    }

    /// Every cell's annotations, keyed by mark ID, blank ones dropped.
    ///
    /// This is what the print run burns: a text box the user opened and never
    /// typed into is not something to draw on film.
    public var annotationsForPrinting: [String: [PrintOverlayAnnotation]] {
        cellAnnotations.compactMapValues { overlays in
            let drawable = overlays.filter { !$0.isBlank }
            return drawable.isEmpty ? nil : drawable
        }
    }

    /// Whether any cell carries a drawn annotation.
    public var hasAnnotations: Bool {
        !annotationsForPrinting.isEmpty
    }

    /// The annotation the inspector is editing, with the cell it belongs to.
    public var selectedAnnotation: (itemID: String, annotation: PrintOverlayAnnotation)? {
        guard let selectedAnnotationID else { return nil }
        for (itemID, overlays) in cellAnnotations {
            if let match = overlays.first(where: { $0.id == selectedAnnotationID }) {
                return (itemID, match)
            }
        }
        return nil
    }

    // MARK: - Adding

    /// Puts a line of text on a cell at a point, and selects it for editing.
    ///
    /// Created empty rather than with placeholder words: placeholder text that
    /// nobody clears is how "Text" ends up printed on a film.
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
        cellAnnotations[itemID, default: []].append(annotation)
        selectAnnotation(annotation.id)
        return annotation.id
    }

    /// Puts an arrow on a cell, tail to head, and selects it.
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
        cellAnnotations[itemID, default: []].append(annotation)
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
        for (itemID, overlays) in cellAnnotations {
            let kept = overlays.filter { overlay in
                overlay.kind != .text || !overlay.text.isEmpty || overlay.id == keptID
            }
            guard kept.count != overlays.count else { continue }
            cellAnnotations[itemID] = kept.isEmpty ? nil : kept
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
        cellAnnotations[itemID]?.removeAll { $0.id == id }
        if cellAnnotations[itemID]?.isEmpty == true { cellAnnotations[itemID] = nil }
        if selectedAnnotationID == id { selectedAnnotationID = nil }
    }

    /// Deletes whatever is selected, if anything.
    @discardableResult
    public func removeSelectedAnnotation() -> Bool {
        guard let selected = selectedAnnotation else { return false }
        removeAnnotation(selected.annotation.id, forItemID: selected.itemID)
        return true
    }

    /// Clears one cell.
    public func clearAnnotations(forItemID itemID: String) {
        if let ids = cellAnnotations[itemID]?.map(\.id), ids.contains(where: { $0 == selectedAnnotationID }) {
            selectedAnnotationID = nil
        }
        cellAnnotations[itemID] = nil
    }

    /// Clears the whole film.
    public func clearAllAnnotations() {
        cellAnnotations = [:]
        selectedAnnotationID = nil
    }

    /// Drops annotations belonging to marks that are no longer on film.
    ///
    /// Unmarking an image and marking it again is a routine thing to do while
    /// composing a film; what must not happen is annotations outliving their mark
    /// invisibly and reappearing on some later film.
    public func pruneAnnotations() {
        let live = Set(selection.items.map(\.id))
        for itemID in cellAnnotations.keys where !live.contains(itemID) {
            cellAnnotations[itemID] = nil
        }
        if let selectedAnnotationID,
           !cellAnnotations.values.flatMap({ $0 }).contains(where: { $0.id == selectedAnnotationID }) {
            self.selectedAnnotationID = nil
        }
    }

    // MARK: - Plumbing

    /// Edits one annotation in place, if it is still there.
    private func mutate(
        _ id: UUID,
        forItemID itemID: String,
        _ transform: (inout PrintOverlayAnnotation) -> Void
    ) {
        guard var overlays = cellAnnotations[itemID],
              let index = overlays.firstIndex(where: { $0.id == id }) else { return }
        transform(&overlays[index])
        cellAnnotations[itemID] = overlays
    }
}
