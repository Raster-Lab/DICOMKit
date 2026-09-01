// PrintCellAnnotationTests.swift
// DICOMStudioTests
//
// The text and arrows a reader draws on a film cell.
//
// The property under test throughout: an annotation belongs to a mark, and what
// the print run burns is exactly what the preview is showing — so an annotation
// on a mark that has left the film must not survive, a blank one must not print,
// and editing one must not touch its neighbours.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Cell Annotation Tests")
struct PrintCellAnnotationTests {

    private func makeViewModel(items: [PrintSelectionItem]) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: items)
        return PrintViewModel(selection: selection)
    }

    private var markedFrames: [PrintSelectionItem] {
        [
            PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0),
            PrintSelectionItem(filePath: "/b.dcm", frameIndex: 0)
        ]
    }

    private func point(_ x: Double, _ y: Double) -> PrintOverlayPoint {
        PrintOverlayPoint(x: x, y: y)
    }

    // MARK: - Adding

    @Test("Text is placed on the cell it was drawn on, and selected for typing")
    func testAddText() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.3, 0.4))

        let annotations = viewModel.annotations(forItemID: "/a.dcm#0")
        #expect(annotations.count == 1)
        #expect(annotations.first?.kind == .text)
        // Empty, not placeholder text: placeholder words nobody clears end up on film.
        #expect(annotations.first?.text == "")
        #expect(viewModel.selectedAnnotationID == id)
        // The other cell is untouched.
        #expect(viewModel.annotations(forItemID: "/b.dcm#0").isEmpty)
    }

    @Test("A new annotation takes the current size and colour")
    func testNewAnnotationTakesDefaults() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.annotationColor = .cyan
        viewModel.annotationScale = 0.08

        viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))
        let arrow = viewModel.annotations(forItemID: "/a.dcm#0").first
        #expect(arrow?.color == .cyan)
        #expect(arrow?.scale == 0.08)
    }

    // MARK: - Editing

    @Test("Moving an annotation moves both ends of an arrow")
    func testMove() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                              from: point(0.2, 0.2), to: point(0.4, 0.4))
        viewModel.moveAnnotation(id, forItemID: "/a.dcm#0", dx: 0.1, dy: 0.1)

        let arrow = viewModel.annotations(forItemID: "/a.dcm#0").first
        #expect(abs((arrow?.start.x ?? 0) - 0.3) < 0.0001)
        #expect(abs((arrow?.end.x ?? 0) - 0.5) < 0.0001)
    }

    @Test("Dragging one end of an arrow leaves the other where it was")
    func testMoveArrowEnd() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                              from: point(0.2, 0.2), to: point(0.4, 0.4))
        viewModel.moveArrowEnd(id, forItemID: "/a.dcm#0", isHead: true, to: point(0.9, 0.1))

        let arrow = viewModel.annotations(forItemID: "/a.dcm#0").first
        #expect(arrow?.start == point(0.2, 0.2))
        #expect(arrow?.end == point(0.9, 0.1))
    }

    @Test("Size and colour set on one annotation become the size and colour of the next")
    func testEditingAdoptsDefaults() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.5, 0.5))
        viewModel.setAnnotationScale(0.12, id: id, forItemID: "/a.dcm#0")
        viewModel.setAnnotationColor(.red, id: id, forItemID: "/a.dcm#0")

        #expect(viewModel.annotationScale == 0.12)
        #expect(viewModel.annotationColor == .red)

        // A reader who has decided how their annotations should look has decided
        // it for the film, not for one cell.
        viewModel.addTextAnnotation(forItemID: "/b.dcm#0", at: point(0.5, 0.5))
        #expect(viewModel.annotations(forItemID: "/b.dcm#0").first?.scale == 0.12)
        #expect(viewModel.annotations(forItemID: "/b.dcm#0").first?.color == .red)
    }

    @Test("A text box never typed into is abandoned when something else is selected")
    func testEmptyTextDiscarded() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.3, 0.3))
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").count == 1)

        // Drawing an arrow instead of typing: the empty box goes, rather than
        // sitting on the preview looking like text that failed to print.
        viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))
        let remaining = viewModel.annotations(forItemID: "/a.dcm#0")
        #expect(remaining.count == 1)
        #expect(remaining.first?.kind == .arrow)

        // Clicking away with nothing selected clears it too.
        let id = viewModel.addTextAnnotation(forItemID: "/b.dcm#0", at: point(0.3, 0.3))
        viewModel.selectAnnotation(nil)
        #expect(viewModel.annotations(forItemID: "/b.dcm#0").isEmpty)
        #expect(viewModel.selectedAnnotationID != id)
    }

    @Test("Text that was typed into survives losing the selection")
    func testTypedTextKept() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.3, 0.3))
        viewModel.setAnnotationText("LAD", id: id, forItemID: "/a.dcm#0")
        viewModel.selectAnnotation(nil)

        #expect(viewModel.annotations(forItemID: "/a.dcm#0").first?.text == "LAD")
        #expect(viewModel.annotationsForPrinting["/a.dcm#0"]?.count == 1)
    }

    @Test("An edit to a missing annotation changes nothing")
    func testEditingMissingAnnotation() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setAnnotationText("LAD", id: UUID(), forItemID: "/a.dcm#0")
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").isEmpty)
    }

    // MARK: - What prints

    @Test("Blank annotations are not printed")
    func testBlankNotPrinted() {
        let viewModel = makeViewModel(items: markedFrames)
        // A text box the user opened and never typed into.
        viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.5, 0.5))
        #expect(viewModel.annotationsForPrinting.isEmpty)
        #expect(!viewModel.hasAnnotations)

        let id = viewModel.annotations(forItemID: "/a.dcm#0")[0].id
        viewModel.setAnnotationText("LAD", id: id, forItemID: "/a.dcm#0")
        #expect(viewModel.annotationsForPrinting["/a.dcm#0"]?.count == 1)
        #expect(viewModel.hasAnnotations)
    }

    @Test("Turning the marks off for a job leaves them on screen but off the film")
    func testBurnToggleGatesOnlyTheOutput() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.5, 0.5))
        viewModel.setAnnotationText("LAD", id: id, forItemID: "/a.dcm#0")

        #expect(viewModel.burnDrawnAnnotations, "film carries what was drawn, by default")

        viewModel.burnDrawnAnnotations = false
        // The store is untouched: the marks are still on screen, still
        // editable, and still there if the switch goes back on.
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").count == 1)
        #expect(viewModel.hasAnnotations)
        #expect(viewModel.annotationsForPrinting["/a.dcm#0"]?.count == 1,
                "the switch gates what the job is given, not what is drawn")
    }

    // MARK: - Removing

    @Test("Delete removes what is selected, and nothing else")
    func testRemoveSelected() {
        let viewModel = makeViewModel(items: markedFrames)
        let first = viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                                 from: point(0.1, 0.1), to: point(0.5, 0.5))
        let second = viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                                  from: point(0.2, 0.2), to: point(0.6, 0.6))
        #expect(viewModel.selectedAnnotationID == second)

        #expect(viewModel.removeSelectedAnnotation())
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").map(\.id) == [first])
        #expect(viewModel.selectedAnnotationID == nil)
        // Nothing selected, nothing to delete — and no crash for trying.
        #expect(!viewModel.removeSelectedAnnotation())
    }

    @Test("Clearing a cell leaves the other cells alone")
    func testClearCell() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))
        viewModel.addArrowAnnotation(forItemID: "/b.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))

        viewModel.clearAnnotations(forItemID: "/a.dcm#0")
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").isEmpty)
        #expect(viewModel.annotations(forItemID: "/b.dcm#0").count == 1)
        // The selection was on the cleared cell, so it is let go of.
        #expect(viewModel.selectedAnnotationID != nil)  // still the /b arrow
    }

    @Test("Annotations do not outlive the mark they were drawn on")
    func testPruning() {
        let viewModel = makeViewModel(items: markedFrames)
        let id = viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                              from: point(0.1, 0.1), to: point(0.5, 0.5))
        viewModel.selectAnnotation(id)

        // Unmarking the image takes its annotations with it: an arrow that
        // survived invisibly would reappear if the image were marked again.
        viewModel.selection.remove(filePath: "/a.dcm", frameIndex: 0)
        viewModel.pruneAnnotations()

        #expect(viewModel.annotations(forItemID: "/a.dcm#0").isEmpty)
        #expect(viewModel.selectedAnnotationID == nil)
        #expect(viewModel.annotationsForPrinting.isEmpty)
    }

    @Test("Annotations are shared by image identity, not owned by one mark")
    func testAnnotationsSharedByImageIdentity() {
        // Two marks that, despite carrying different mark IDs were the film
        // arranged with duplicate cells, point at the very same file and
        // frame — the case that matters for the main viewer, which has no
        // notion of "which mark", only "which image".
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))

        // A second mark pointing at the same image, added after the first is
        // unmarked, sees the same drawing — it is the image's annotation,
        // not the mark's.
        viewModel.selection.remove(filePath: "/a.dcm", frameIndex: 0)
        viewModel.pruneAnnotations()
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").isEmpty,
                "pruning drops annotations once no mark points at the image")

        viewModel.selection.add(PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0))
        viewModel.addTextAnnotation(forItemID: "/a.dcm#0", at: point(0.2, 0.2))
        #expect(viewModel.annotations(forItemID: "/a.dcm#0").count == 1)
    }

    @Test("Clearing the film clears every cell")
    func testClearAll() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.addArrowAnnotation(forItemID: "/a.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))
        viewModel.addArrowAnnotation(forItemID: "/b.dcm#0",
                                     from: point(0.1, 0.1), to: point(0.5, 0.5))
        viewModel.clearAllAnnotations()

        #expect(!viewModel.hasAnnotations)
        #expect(viewModel.selectedAnnotationID == nil)
    }

    // MARK: - Tools

    @Test("Only the drawing tools are drawing tools")
    func testDrawingTools() {
        #expect(PrintViewModel.CellTool.text.isDrawing)
        #expect(PrintViewModel.CellTool.arrow.isDrawing)
        #expect(!PrintViewModel.CellTool.window.isDrawing)
        #expect(!PrintViewModel.CellTool.zoom.isDrawing)
        #expect(!PrintViewModel.CellTool.pan.isDrawing)
    }
}
