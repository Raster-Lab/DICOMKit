// CombinedAnnotationStoreTests.swift
// DICOMStudioTests
//
// The store's side of the merged annotation tool: how a combined annotation
// is created (a click's plain label, or a drag's anchor-plus-label), which
// empties are discarded on deselection, and that both of its ends answer the
// handle drags the viewer sends them.

import Testing
import Foundation
@testable import DICOMStudio
import DICOMPrintKit

@MainActor
@Suite("Combined Annotation Store Tests")
struct CombinedAnnotationStoreTests {

    private let key = ImageAnnotationKey(filePath: "/study/slice42.dcm", frameIndex: 0)

    @Test("A click places a label with no arrow, selected for typing")
    func testClickPlacesPlainLabel() {
        let selection = PrintSelectionModel()
        let id = selection.addAnnotation(forKey: key, at: PrintOverlayPoint(x: 0.3, y: 0.4))

        let drawn = selection.annotations(forKey: key).first
        #expect(drawn?.kind == .annotation)
        #expect(drawn?.start == drawn?.end)
        #expect(drawn?.hasArrow == false)
        #expect(selection.selectedAnnotationID == id)
    }

    @Test("A drag names the anchor and pulls the label out of it")
    func testDragCreatesAnchoredLabel() {
        let selection = PrintSelectionModel()
        selection.addAnnotation(
            forKey: key,
            at: PrintOverlayPoint(x: 0.2, y: 0.2),
            anchor: PrintOverlayPoint(x: 0.6, y: 0.6))

        let drawn = selection.annotations(forKey: key).first
        #expect(drawn?.start == PrintOverlayPoint(x: 0.2, y: 0.2))
        #expect(drawn?.end == PrintOverlayPoint(x: 0.6, y: 0.6))
        #expect(drawn?.hasArrow == true)
    }

    @Test("Deselecting discards a combined annotation only when both halves are empty")
    func testDiscardOnDeselect() {
        let selection = PrintSelectionModel()
        let point = PrintOverlayPoint(x: 0.3, y: 0.4)

        // A click nothing was typed into: gone on deselect, like the old
        // text tool's empty box.
        selection.addAnnotation(forKey: key, at: point)
        selection.selectAnnotation(nil)
        #expect(selection.annotations(forKey: key).isEmpty)

        // An arrow left unlabelled is a drawing, not a slip: it stays.
        let arrowOnly = selection.addAnnotation(
            forKey: key, at: point, anchor: PrintOverlayPoint(x: 0.8, y: 0.8))
        selection.selectAnnotation(nil)
        #expect(selection.annotations(forKey: key).map(\.id) == [arrowOnly])

        // Words with no arrow stay too.
        let labelled = selection.addAnnotation(forKey: key, at: point)
        selection.setAnnotationText("Nodule", id: labelled, forKey: key)
        selection.selectAnnotation(nil)
        #expect(selection.annotations(forKey: key).map(\.id) == [arrowOnly, labelled])
    }

    @Test("Both ends answer the handle drags: anchor re-aims, label moves alone")
    func testMovingEitherEnd() {
        let selection = PrintSelectionModel()
        let id = selection.addAnnotation(
            forKey: key,
            at: PrintOverlayPoint(x: 0.2, y: 0.2),
            anchor: PrintOverlayPoint(x: 0.6, y: 0.6))

        selection.moveArrowEnd(id, forKey: key, isHead: true,
                               to: PrintOverlayPoint(x: 0.9, y: 0.5))
        selection.moveArrowEnd(id, forKey: key, isHead: false,
                               to: PrintOverlayPoint(x: 0.1, y: 0.1))

        let drawn = selection.annotations(forKey: key).first
        #expect(drawn?.end == PrintOverlayPoint(x: 0.9, y: 0.5))
        #expect(drawn?.start == PrintOverlayPoint(x: 0.1, y: 0.1))
    }

    @Test("Blank combined annotations are not offered for printing")
    func testBlankIsNotPrinted() {
        let selection = PrintSelectionModel()
        selection.addAnnotation(forKey: key, at: PrintOverlayPoint(x: 0.3, y: 0.4))
        #expect(selection.hasAnnotations == false)
    }
}
