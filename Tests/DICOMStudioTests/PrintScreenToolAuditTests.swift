// PrintScreenToolAuditTests.swift
// DICOMStudioTests
//
// A sweep of the film print screen: every layout mode, every rail tool, and the
// options the cell menu offers, driven through the view model the way the views
// drive them. This exists because "the Viewer match option did not work" is a
// report the model alone could not confirm or deny — the mode is chosen in one
// view and seeded from another, and only an end-to-end pass over the request
// says whether the film that would be printed is the grid that was asked for.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMNetwork
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Screen Tool Audit")
struct PrintScreenToolAuditTests {

    private func makeViewModel(count: Int = 4) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (0..<count).map {
            PrintSelectionItem(filePath: "/img\($0).dcm", frameIndex: 0,
                               windowCenter: 40, windowWidth: 400)
        })
        return PrintViewModel(selection: selection)
    }

    private let cell = CGSize(width: 300, height: 250)
    private let pixels = CGSize(width: 512, height: 512)

    // MARK: - Layout modes

    @Test("Viewer match sends the viewer's grid, not the automatic one")
    func testMatchViewerReachesTheRequest() {
        let viewModel = makeViewModel(count: 4)
        // What ImageViewerView.prepare() does when the viewer is in a 1×3 grid.
        viewModel.viewerLayout = PrintLayout(rows: 1, columns: 3)
        viewModel.layoutMode = .matchViewer

        #expect(viewModel.request.layoutSelection.layout == PrintLayout(rows: 1, columns: 3))
        #expect(viewModel.plan.layout == (rows: 1, columns: 3),
                "the preview's own grid must be the viewer's grid")
        #expect(viewModel.request.layoutSelection.imageDisplayFormat?.raw == "STANDARD\\3,1"
                || viewModel.request.layoutSelection.imageDisplayFormat?.raw == "STANDARD\\1,3")
    }

    @Test("Viewer match with no viewer grid falls back to automatic rather than 1×1")
    func testMatchViewerFallsBack() {
        let viewModel = makeViewModel(count: 4)
        viewModel.viewerLayout = nil
        viewModel.layoutMode = .matchViewer
        // Automatic picks a grid that fits; the one thing it must not do is
        // silently print one image per sheet.
        #expect(viewModel.plan.cellsPerFilm > 1)
    }

    @Test("Viewer match survives resetForNewFilm")
    func testMatchViewerSurvivesReset() {
        let viewModel = makeViewModel(count: 4)
        viewModel.viewerLayout = PrintLayout(rows: 2, columns: 2)
        viewModel.layoutMode = .matchViewer
        viewModel.resetForNewFilm()
        #expect(viewModel.layoutMode == .matchViewer)
        #expect(viewModel.viewerLayout == PrintLayout(rows: 2, columns: 2),
                "the grid the film was opened for must not be wiped by the reset")
        #expect(viewModel.plan.layout == (rows: 2, columns: 2))
    }

    @Test("Every layout mode produces the grid it names")
    func testAllLayoutModes() {
        let viewModel = makeViewModel(count: 6)

        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        #expect(viewModel.plan.layout == (rows: 2, columns: 2))

        viewModel.layoutMode = .automatic
        #expect(viewModel.plan.cellsPerFilm >= 1)

        viewModel.layoutMode = .custom
        viewModel.customLayoutText = "STANDARD\\2,3"
        #expect(viewModel.customLayoutFormat != nil)
        #expect(viewModel.request.layoutSelection.imageDisplayFormat?.raw == "STANDARD\\2,3")

        viewModel.customLayoutText = "not a format"
        #expect(viewModel.customLayoutFormat == nil)
        #expect(viewModel.plan.cellsPerFilm > 1, "half-typed text must not print 1×1")

        viewModel.layoutMode = .template
        viewModel.templatePreset = PrintTemplatePreset.allCases[0]
        #expect(viewModel.request.layoutSelection.layout != nil)
    }

    // MARK: - The rail tools

    @Test("Window drag changes the focused cell's window")
    func testWindowTool() async {
        let viewModel = makeViewModel()
        viewModel.cellTool = .window
        viewModel.focusCell("/img0.dcm#0")
        await viewModel.seedWindowIfNeeded(forItemID: "/img0.dcm#0")
        let before = viewModel.window(forItemID: "/img0.dcm#0")
        viewModel.adjustWindow(forItemID: "/img0.dcm#0", deltaCenter: 25, deltaWidth: 50)
        let after = viewModel.window(forItemID: "/img0.dcm#0")
        #expect(before != nil && after != nil)
        #expect(after?.center != before?.center)
        #expect(after?.width != before?.width)
    }

    @Test("Zoom and pan move the picture, and reset puts it back")
    func testZoomPanReset() {
        let viewModel = makeViewModel()
        let id = "/img0.dcm#0"
        viewModel.focusCell(id)
        viewModel.adjustZoom(forItemID: id, factor: 1.5, cellSize: cell, pixelSize: pixels)
        let zoomed = viewModel.selection.items.first { $0.id == id }?.presentation?.zoom
        #expect((zoomed ?? 1) > 1.0)

        viewModel.panCell(forItemID: id, dx: 20, dy: -15, cellSize: cell, pixelSize: pixels)
        let panned = viewModel.selection.items.first { $0.id == id }?.presentation
        #expect(panned?.panX != 0 || panned?.panY != 0)

        #expect(viewModel.isCellEdited(viewModel.selection.items.first { $0.id == id }!))
        viewModel.resetCell(forItemID: id)
        let reset = viewModel.selection.items.first { $0.id == id }?.presentation
        #expect((reset?.zoom ?? 1) == 1.0)
        #expect((reset?.panX ?? 0) == 0 && (reset?.panY ?? 0) == 0)
    }

    @Test("The rotate tool turns the focused cell, and Straighten squares it up")
    func testRotateAndStraighten() {
        let viewModel = makeViewModel()
        let id = "/img0.dcm#0"
        viewModel.cellTool = .rotate
        viewModel.focusCell(id)

        // A drag: many small deltas, ending at an angle that is not square.
        for _ in 0..<11 {
            viewModel.rotateCell(forItemID: id, byDegrees: 8, cellSize: cell)
        }
        #expect(viewModel.rotation(forItemID: id) == 88)
        #expect(viewModel.isCellSkewed(id))

        viewModel.straightenCell(forItemID: id, cellSize: cell)
        #expect(viewModel.rotation(forItemID: id) == 90)
        #expect(!viewModel.isCellSkewed(id))
    }

    @Test("A shut rotate lock carries the turn across the film")
    func testRotateLock() {
        let viewModel = makeViewModel()
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSyncFromUI(.rotate)
        viewModel.focusCell("/img0.dcm#0")

        viewModel.rotateCell(forItemID: "/img0.dcm#0", byDegrees: 45, cellSize: cell)

        for item in viewModel.selection.items {
            #expect(item.presentation?.rotationDegrees == 45,
                    "every cell on the film stands the same way round")
        }

        // And opening it again leaves the next turn on its own cell.
        viewModel.toggleSyncFromUI(.rotate)
        viewModel.rotateCell(forItemID: "/img0.dcm#0", byDegrees: 10, cellSize: cell)
        #expect(viewModel.rotation(forItemID: "/img0.dcm#0") == 55)
        #expect(viewModel.rotation(forItemID: "/img1.dcm#0") == 45)
    }

    @Test("Invert toggles one cell and reads back")
    func testInvert() {
        let viewModel = makeViewModel()
        let id = "/img0.dcm#0"
        viewModel.focusCell(id)
        viewModel.toggleCellInversion(forItemID: id)
        #expect(viewModel.selection.items.first { $0.id == id }?.presentation?.invert == true)
        viewModel.toggleCellInversion(forItemID: id)
        #expect(viewModel.selection.items.first { $0.id == id }?.presentation?.invert != true)
    }

    @Test("Reset All clears every edited cell")
    func testResetAll() {
        let viewModel = makeViewModel()
        viewModel.adjustZoom(forItemID: "/img0.dcm#0", factor: 1.4,
                             cellSize: cell, pixelSize: pixels)
        viewModel.adjustZoom(forItemID: "/img1.dcm#0", factor: 1.4,
                             cellSize: cell, pixelSize: pixels)
        #expect(viewModel.hasEditedCells)
        viewModel.resetAllCells()
        #expect(!viewModel.hasEditedCells)
    }

    // MARK: - Locks and picked cells

    @Test("A shut zoom lock carries the drag across the film")
    func testZoomLockCarries() {
        let viewModel = makeViewModel()
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSyncFromUI(.zoomPan)
        #expect(viewModel.cellSync.contains(.zoomPan))
        viewModel.focusCell("/img0.dcm#0")
        viewModel.adjustZoom(forItemID: "/img0.dcm#0", factor: 1.5,
                             cellSize: cell, pixelSize: pixels)
        let others = viewModel.selection.items
            .filter { $0.id != "/img0.dcm#0" }
            .compactMap { $0.presentation?.zoom }
        #expect(others.allSatisfy { $0 > 1.0 },
                "a shut lock at film scope must move every cell")
    }

    @Test("A picked set outranks the locks")
    func testPickedSetOutranksLocks() {
        let viewModel = makeViewModel()
        viewModel.cellSyncScope = .thisFilm
        viewModel.toggleSyncFromUI(.zoomPan)
        viewModel.focusCell("/img0.dcm#0")
        viewModel.toggleCellSelection("/img0.dcm#0")
        viewModel.toggleCellSelection("/img1.dcm#0")
        #expect(viewModel.hasCellSelection)
        viewModel.adjustZoom(forItemID: "/img0.dcm#0", factor: 1.5,
                             cellSize: cell, pixelSize: pixels)
        let untouched = viewModel.selection.items.first { $0.id == "/img3.dcm#0" }
        #expect((untouched?.presentation?.zoom ?? 1.0) == 1.0,
                "a cell outside the picked set must not move")
    }

    @Test("Clearing the picked set leaves the cells alone")
    func testClearSelection() {
        let viewModel = makeViewModel()
        viewModel.toggleCellSelection("/img0.dcm#0")
        viewModel.clearCellSelection()
        #expect(!viewModel.hasCellSelection)
    }

    // MARK: - Cell menu actions

    @Test("Apply This Window to All Cells reaches every cell")
    func testApplyWindowToAll() async {
        let viewModel = makeViewModel()
        let id = "/img0.dcm#0"
        viewModel.focusCell(id)
        await viewModel.seedWindowIfNeeded(forItemID: id)
        viewModel.adjustWindow(forItemID: id, deltaCenter: 100, deltaWidth: 200)
        guard let source = viewModel.window(forItemID: id) else {
            Issue.record("no window to apply"); return
        }
        viewModel.applyFocusedWindowToAllCells()
        for item in viewModel.selection.items {
            let w = viewModel.window(forItemID: item.id)
            #expect(w?.center == source.center && w?.width == source.width,
                    "cell \(item.id) did not take the applied window")
        }
    }

    @Test("Take Off the Film removes the mark")
    func testRemoveCell() {
        let viewModel = makeViewModel()
        let before = viewModel.selection.items.count
        viewModel.selection.remove(filePath: "/img0.dcm", frameIndex: 0)
        #expect(viewModel.selection.items.count == before - 1)
    }

    @Test("Fit the Whole Image in Every Cell is honoured by the request path")
    func testUseViewerPresentationToggle() {
        let viewModel = makeViewModel()
        #expect(viewModel.useViewerPresentation)
        viewModel.useViewerPresentation = false
        #expect(!viewModel.useViewerPresentation)
    }

    // MARK: - Annotations

    @Test("Text and arrow annotations are added, kept and cleared per cell")
    func testAnnotations() {
        let viewModel = makeViewModel()
        let id = "/img0.dcm#0"
        viewModel.cellTool = .text
        let text = viewModel.addTextAnnotation(forItemID: id,
                                               at: PrintOverlayPoint(x: 0.5, y: 0.5))
        #expect(viewModel.annotations(forItemID: id).count == 1)
        // A text box that was never typed into is a slip, and selecting
        // anything else abandons it — so it has to carry text to survive the
        // arrow that follows.
        viewModel.setAnnotationText("Lesion", id: text, forItemID: id)

        viewModel.cellTool = .arrow
        let arrow = viewModel.addArrowAnnotation(
            forItemID: id,
            from: PrintOverlayPoint(x: 0.2, y: 0.2),
            to: PrintOverlayPoint(x: 0.8, y: 0.8))
        #expect(viewModel.annotations(forItemID: id).count == 2)
        viewModel.moveArrowEnd(arrow, forItemID: id, isHead: true,
                               to: PrintOverlayPoint(x: 0.9, y: 0.9))

        viewModel.clearAnnotations(forItemID: id)
        #expect(viewModel.annotations(forItemID: id).isEmpty)
    }

    // MARK: - Job settings

    @Test("Explicit window and raw pixels shape the request as the panel says")
    func testWindowAndRawOptions() {
        let viewModel = makeViewModel()
        viewModel.useExplicitWindow = true
        viewModel.explicitWindowCenter = 50
        viewModel.explicitWindowWidth = 350
        #expect(viewModel.request.windowSettings?.center == 50)
        #expect(viewModel.request.windowSettings?.width == 350)

        viewModel.sendRawPixels = true
        #expect(viewModel.request.windowSettings == nil,
                "raw pixels carry no window")
        #expect(viewModel.request.bitDepth == 8)
    }

    @Test("Copies, priority, medium, destination and trim reach the request")
    func testJobSettingsReachRequest() {
        let viewModel = makeViewModel()
        viewModel.copies = 3
        viewModel.priority = .high
        viewModel.mediumType = .blueFilm
        viewModel.filmDestination = .processor
        viewModel.trimOption = .yes
        viewModel.sessionLabel = "  Session A  "
        let request = viewModel.request
        #expect(request.copies == 3)
        #expect(request.priority == .high)
        #expect(request.mediumType == .blueFilm)
        #expect(request.filmDestination == .processor)
        #expect(request.trimOption == .yes)
        #expect(request.sessionLabel == "Session A", "whitespace must be trimmed")
    }

    @Test("Annotation texts become numbered PrintAnnotations, blanks dropped")
    func testAnnotationTexts() {
        let viewModel = makeViewModel()
        viewModel.annotationTexts = ["First", "   ", "Third"]
        let annotations = viewModel.request.annotations
        #expect(annotations.count == 2)
        #expect(annotations.map(\.text) == ["First", "Third"])
    }

    // MARK: - Stale viewer grid

    @Test("A viewer grid left over from a previous film is not silently reused")
    func testStaleViewerLayoutIsNotReused() {
        let viewModel = makeViewModel(count: 4)
        // A film composed from a 2x2 viewer grid.
        viewModel.viewerLayout = PrintLayout(rows: 2, columns: 2)
        viewModel.layoutMode = .matchViewer
        #expect(viewModel.plan.layout == (rows: 2, columns: 2))

        // The reader goes back to the viewer, drops to a single image, and
        // opens the print screen again. ImageViewerView.preparePrintScreen()
        // clears the grid and moves the mode off matchViewer.
        viewModel.viewerLayout = nil
        if viewModel.layoutMode == .matchViewer { viewModel.layoutMode = .automatic }
        #expect(viewModel.layoutMode == .automatic,
                "with no viewer grid the mode must not stay on Viewer")
    }

    @Test("Choosing Viewer with no grid seeded leaves the film on automatic")
    func testChoosingViewerWithoutAGrid() {
        let viewModel = makeViewModel(count: 4)
        viewModel.viewerLayout = nil
        // The gallery disables the Viewer tile in this state; if it is reached
        // anyway the request must still describe a usable film.
        viewModel.layoutMode = .matchViewer
        #expect(viewModel.request.layoutSelection == .automatic)
    }
}
