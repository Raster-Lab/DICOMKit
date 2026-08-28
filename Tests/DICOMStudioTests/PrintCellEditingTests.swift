// PrintCellEditingTests.swift
// DICOMStudioTests
//
// Adjusting a film cell inside the print preview.
//
// The property under test throughout is that the preview cannot disagree with
// the film: every edit lands in the mark, which is the field the print path
// reads, and what the preview renders is the mark resolved against the job-wide
// settings that would otherwise override it.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Cell Editing Tests")
struct PrintCellEditingTests {

    private func makeViewModel(items: [PrintSelectionItem]) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: items)
        return PrintViewModel(selection: selection)
    }

    private var markedFrames: [PrintSelectionItem] {
        [
            PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0,
                               windowCenter: 40, windowWidth: 400),
            PrintSelectionItem(filePath: "/b.dcm", frameIndex: 0)
        ]
    }

    // MARK: - Windowing

    @Test("Setting a cell's window writes it into the mark the printer reads")
    func testSetWindow() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: -600, width: 1500)

        let mark = viewModel.selection.items.first { $0.id == "/a.dcm#0" }
        #expect(mark?.windowCenter == -600)
        #expect(mark?.windowWidth == 1500)
        // The other cell is untouched — windowing is per image.
        #expect(viewModel.selection.items.first { $0.id == "/b.dcm#0" }?.windowCenter == nil)
    }

    @Test("A window/level drag nudges the cell's own window")
    func testAdjustWindow() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.adjustWindow(forItemID: "/a.dcm#0", deltaCenter: 10, deltaWidth: -50)

        let window = viewModel.window(forItemID: "/a.dcm#0")
        #expect(window?.center == 50)
        #expect(window?.width == 350)
    }

    @Test("Width never falls below 1 — a zero-width window is not a picture")
    func testWidthFloor() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 40, width: -30)
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.width == 1)
    }

    @Test("Editing keeps the mark's film position")
    func testEditKeepsPosition() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/b.dcm#0", center: 100, width: 200)
        #expect(viewModel.selection.items.map(\.id) == ["/a.dcm#0", "/b.dcm#0"])
    }

    @Test("A preset applies to the focused cell only")
    func testPreset() {
        let viewModel = makeViewModel(items: markedFrames)
        let lung = WindowLevelPreset(name: "Lung", center: -600, width: 1500, modality: "CT")
        viewModel.applyWindowPreset(lung, toItemID: "/b.dcm#0")

        #expect(viewModel.window(forItemID: "/b.dcm#0")?.center == -600)
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.center == 40)
    }

    @Test("Apply to all gives every cell the focused window and drops the job-wide override")
    func testApplyToAll() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.useExplicitWindow = true
        viewModel.focusCell("/a.dcm#0")
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)

        viewModel.applyFocusedWindowToAllCells()

        #expect(viewModel.useExplicitWindow == false)
        #expect(viewModel.selection.items.allSatisfy {
            $0.windowCenter == 300 && $0.windowWidth == 1500
        })
    }

    // MARK: - The preview must show what prints

    @Test("A job-wide explicit window is what the preview renders")
    func testExplicitWindowFoldedIntoPreview() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.useExplicitWindow = true
        viewModel.explicitWindowCenter = 90
        viewModel.explicitWindowWidth = 700

        #expect(viewModel.previewItems.allSatisfy {
            $0.windowCenter == 90 && $0.windowWidth == 700
        })
        // …and the mark itself is untouched, so turning the override off
        // restores the window the user set on the cell.
        #expect(viewModel.selection.items.first?.windowCenter == 40)
    }

    @Test("A job-wide window is previewed as the output units it was typed in")
    func testExplicitWindowIsPreviewedInOutputUnits() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.useExplicitWindow = true
        viewModel.explicitWindowCenter = 90
        viewModel.explicitWindowWidth = 700

        // 90 is HU, as typed. Rendered as a stored value it would sit far below
        // every pixel on a CT and wash the cell out, so the preview has to know
        // which space it was handed.
        #expect(viewModel.previewItems.allSatisfy { $0.windowSpace == .outputUnits })

        // A mark's own window still comes off the viewer, which is stored space.
        viewModel.useExplicitWindow = false
        #expect(viewModel.previewItems.allSatisfy { $0.windowSpace == .storedValues })
    }

    @Test("Turning off the viewer window previews the file's own window")
    func testViewerWindowOffFoldedIntoPreview() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.useViewerWindow = false
        #expect(viewModel.previewItems.allSatisfy { $0.windowCenter == nil })
    }

    @Test("Raw previews without window or arrangement, as it prints")
    func testRawFoldedIntoPreview() {
        let selection = PrintSelectionModel()
        selection.add(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            windowCenter: 40, windowWidth: 400,
            presentation: ViewerPresentation(zoom: 3, viewportWidth: 400, viewportHeight: 400)))
        let viewModel = PrintViewModel(selection: selection)
        viewModel.sendRawPixels = true

        let previewed = viewModel.previewItems[0]
        #expect(previewed.windowCenter == nil)
        #expect(previewed.presentation == nil)
    }

    @Test("Folding preserves identity, so a previewed cell still edits its mark")
    func testPreviewKeepsIdentity() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.useExplicitWindow = true
        #expect(viewModel.previewItems.map(\.id) == viewModel.selection.items.map(\.id))
    }

    @Test("Cell windowing is reported as blocked while a job-wide window overrides it")
    func testBlockedReason() {
        let viewModel = makeViewModel(items: markedFrames)
        #expect(viewModel.isCellWindowingOverridden == false)
        #expect(viewModel.cellWindowingBlockedReason == nil)

        viewModel.useExplicitWindow = true
        #expect(viewModel.isCellWindowingOverridden)
        #expect(viewModel.cellWindowingBlockedReason != nil)
    }

    // MARK: - Zoom, pan, orientation

    @Test("Zooming a mark that was never composed on screen uses the cell as its viewport")
    func testZoomWithoutPresentation() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.adjustZoom(forItemID: "/b.dcm#0", factor: 2,
                             cellSize: CGSize(width: 300, height: 200))

        let presentation = viewModel.selection.items.first { $0.id == "/b.dcm#0" }?.presentation
        #expect(presentation?.zoom == 2)
        #expect(presentation?.viewportWidth == 300)
        #expect(presentation?.viewportHeight == 200)
    }

    @Test("Zoom is bounded, so a cell cannot be pushed past what the viewer allows")
    func testZoomBounds() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)
        for _ in 0..<40 {
            viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2, cellSize: cell)
        }
        let zoom = viewModel.selection.items.first { $0.id == "/a.dcm#0" }?.presentation?.zoom
        #expect(zoom == PrintViewModel.maximumCellZoom)
    }

    @Test("Zooming back out to fitted clears the pan it was cropping with")
    func testZoomOutClearsPan() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 4, cellSize: cell)
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 30, dy: -10, cellSize: cell)
        #expect(viewModel.selection.items[0].presentation?.panX == 30)

        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 0.1, cellSize: cell)
        #expect(viewModel.selection.items[0].presentation?.panX == 0)
        #expect(viewModel.selection.items[0].presentation?.panY == 0)
    }

    @Test("A pan drag is scaled from cell points into the mark's own viewport")
    func testPanScaling() {
        let selection = PrintSelectionModel()
        selection.add(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            presentation: ViewerPresentation(
                zoom: 2, viewportWidth: 800, viewportHeight: 800)))
        let viewModel = PrintViewModel(selection: selection)

        // The cell is a quarter of the viewport's width, so a 10-point drag on
        // the cell is a 40-point pan in the space the crop is resolved in.
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 10, dy: 5,
                          cellSize: CGSize(width: 200, height: 200))

        #expect(viewModel.selection.items[0].presentation?.panX == 40)
        #expect(viewModel.selection.items[0].presentation?.panY == 20)
    }

    @Test("A pan stops at the image's edge instead of cropping past it")
    func testPanIsHeldInsideTheImage() {
        let selection = PrintSelectionModel()
        selection.add(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            presentation: ViewerPresentation(
                zoom: 2, viewportWidth: 500, viewportHeight: 500)))
        let viewModel = PrintViewModel(selection: selection)

        // 1000×1000 pixels fitted into a 500-point viewport at zoom 2: 250
        // points hidden either side, so that is as far as the drag goes.
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 4000, dy: 0,
                          cellSize: CGSize(width: 500, height: 500),
                          pixelSize: CGSize(width: 1000, height: 1000))

        #expect(viewModel.selection.items[0].presentation?.panX == 250)
    }

    @Test("A fitted cell has nothing hidden to pan to")
    func testPanDoesNothingWhileFitted() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 60, dy: 40,
                          cellSize: CGSize(width: 300, height: 300),
                          pixelSize: CGSize(width: 512, height: 512))

        #expect(viewModel.selection.items[0].presentation?.panX == 0)
        #expect(viewModel.selection.items[0].presentation?.panY == 0)
    }

    @Test("Arranging a cell turns the film's arrangement on, so the drag shows")
    func testArrangementEditEnablesViewerPresentation() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.useViewerPresentation = false

        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2,
                             cellSize: CGSize(width: 300, height: 300))

        #expect(viewModel.useViewerPresentation)
        #expect(viewModel.previewItems[0].presentation?.zoom == 2)
    }

    @Test("Zooming a cell re-bases the crop on the cell's own shape")
    func testZoomRebasesViewportOnTheCell() {
        let selection = PrintSelectionModel()
        // Marked from a tall viewer tile…
        selection.add(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            presentation: ViewerPresentation(
                zoom: 1, viewportWidth: 300, viewportHeight: 900)))
        let viewModel = PrintViewModel(selection: selection)

        // …then zoomed in a wide film cell. The crop must take the cell's shape,
        // or the cell can only letterbox it — which reads as the image being cut
        // off in height instead of filling the cell.
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2,
                             cellSize: CGSize(width: 400, height: 200))

        let presentation = viewModel.selection.items[0].presentation
        #expect(presentation?.viewportWidth == 400)
        #expect(presentation?.viewportHeight == 200)
        #expect(presentation?.zoom == 2, "the magnification is carried across")
    }

    @Test("A cell already the right shape keeps its viewport across redraws")
    func testMatchingAspectIsNotRebased() {
        let selection = PrintSelectionModel()
        selection.add(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            presentation: ViewerPresentation(
                zoom: 1, panX: 25, viewportWidth: 800, viewportHeight: 400)))
        let viewModel = PrintViewModel(selection: selection)

        // Same 2:1 shape, half the size, and a fractional height as layout
        // actually reports it. Re-basing here would walk the crop every redraw.
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 1.5,
                             cellSize: CGSize(width: 400, height: 200.4))

        #expect(viewModel.selection.items[0].presentation?.viewportWidth == 800)
        #expect(viewModel.selection.items[0].presentation?.panX == 25)
    }

    @Test("Rotation walks in quarter turns and wraps")
    func testRotation() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)
        for _ in 0..<5 {
            viewModel.rotateCell(forItemID: "/a.dcm#0", cellSize: cell)
        }
        #expect(viewModel.selection.items[0].presentation?.quarterTurns == 1)
    }

    // MARK: - Reset and focus

    @Test("Reset returns a cell to the untouched frame")
    func testReset() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 3, cellSize: cell)
        #expect(viewModel.isCellEdited(viewModel.selection.items[0]))

        viewModel.resetCell(forItemID: "/a.dcm#0")

        let mark = viewModel.selection.items[0]
        #expect(mark.windowCenter == nil)
        #expect(mark.windowWidth == nil)
        #expect(mark.presentation == nil)
        #expect(!viewModel.isCellEdited(mark))
    }

    // MARK: - Adjustments survive a viewer re-sync

    @Test("A hand-adjusted cell stops following the viewer")
    func testAdjustedCellIgnoresViewerResync() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)

        // What `refreshMarksFromViewer` does: push the viewer's current state
        // over the mark. It must not undo the window the user set on the film.
        let fromViewer = PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0, windowCenter: 40, windowWidth: 400)
        #expect(viewModel.selection.update(fromViewer) == false)
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.center == 300)

        // An untouched cell still follows the screen.
        let otherFromViewer = PrintSelectionItem(
            filePath: "/b.dcm", frameIndex: 0, windowCenter: 60, windowWidth: 150)
        #expect(viewModel.selection.update(otherFromViewer) == true)
        #expect(viewModel.window(forItemID: "/b.dcm#0")?.center == 60)
    }

    @Test("Revert takes back the adjustment and lets the cell follow the viewer again")
    func testRevert() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2,
                             cellSize: CGSize(width: 200, height: 200))
        #expect(viewModel.isCellAdjusted("/a.dcm#0"))

        viewModel.revertCell(forItemID: "/a.dcm#0")

        // Back to the mark as the viewer left it — both edits, not just the last.
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.center == 40)
        #expect(viewModel.selection.items[0].presentation == nil)
        #expect(!viewModel.isCellAdjusted("/a.dcm#0"))

        let fromViewer = PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0, windowCenter: 55, windowWidth: 200)
        #expect(viewModel.selection.update(fromViewer) == true)
    }

    @Test("Reset lets the cell follow the viewer again too")
    func testResetClearsAdjustment() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.resetCell(forItemID: "/a.dcm#0")

        #expect(!viewModel.isCellAdjusted("/a.dcm#0"))
        #expect(viewModel.selection.items[0].windowCenter == nil)
    }

    @Test("Unmarking an adjusted image forgets its adjustment")
    func testAdjustmentPrunedOnUnmark() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.selection.remove(filePath: "/a.dcm", frameIndex: 0)
        #expect(viewModel.selection.adjustedIDs.isEmpty)

        // Marked again, it is a fresh mark that follows the viewer.
        viewModel.selection.add(PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0))
        #expect(!viewModel.isCellAdjusted("/a.dcm#0"))
    }

    @Test("Focus is dropped when the focused mark leaves the film")
    func testPruneFocus() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.focusCell("/b.dcm#0")
        #expect(viewModel.focusedItem?.id == "/b.dcm#0")

        viewModel.selection.remove(filePath: "/b.dcm", frameIndex: 0)
        viewModel.pruneFocus()
        #expect(viewModel.focusedItemID == nil)
        #expect(viewModel.focusedItem == nil)
    }
}
