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

    @Test("A preset's window is marked as output units — HU, not stored values")
    func testPresetIsTaggedOutputUnits() {
        let viewModel = makeViewModel(items: markedFrames)
        let lung = WindowLevelPreset(name: "Lung", center: -600, width: 1500, modality: "CT")
        viewModel.applyWindowPreset(lung, toItemID: "/b.dcm#0")

        // −600 is HU. Rendered as a stored value it sits below every pixel of a
        // CT with a −1024 intercept and the cell washes out to white — the space
        // has to travel with the numbers so the renderer converts them.
        let mark = viewModel.selection.items.first { $0.id == "/b.dcm#0" }
        #expect(mark?.windowSpace == .outputUnits)
    }

    @Test("A drag after a preset keeps the window in the preset's space")
    func testDragAfterPresetKeepsSpace() {
        let viewModel = makeViewModel(items: markedFrames)
        let lung = WindowLevelPreset(name: "Lung", center: -600, width: 1500, modality: "CT")
        viewModel.applyWindowPreset(lung, toItemID: "/b.dcm#0")

        viewModel.adjustWindow(forItemID: "/b.dcm#0", deltaCenter: 10, deltaWidth: 50)

        let mark = viewModel.selection.items.first { $0.id == "/b.dcm#0" }
        #expect(mark?.windowCenter == -590)
        // The nudge must not relabel HU numbers as stored values.
        #expect(mark?.windowSpace == .outputUnits)
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

    @Test("Apply to all stops at the edge of the focused cell's film")
    func testApplyToAllIsBoundedToTheFilm() {
        // Six marks on 2×2 films: four on film 0, two on film 1. Every other
        // cell-to-cell edit on this screen stops at the sheet being judged (see
        // `PrintCellSyncScope`), and both the button and the menu item say "on
        // film" — but this one wrote `selection.items`, so it rewrote the whole
        // job. On a long job that is hundreds of writes the reader cannot see,
        // each one observed by the preview.
        let items = (0..<6).map {
            PrintSelectionItem(filePath: "/f\($0).dcm", frameIndex: 0)
        }
        let viewModel = makeViewModel(items: items)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        #expect(viewModel.plan.cellsPerFilm == 4)
        #expect(viewModel.plan.filmCount == 2)

        viewModel.focusCell("/f0.dcm#0")
        viewModel.setWindow(forItemID: "/f0.dcm#0", center: 300, width: 1500)
        viewModel.applyFocusedWindowToAllCells()

        // Film 0 takes the window…
        for index in 0..<4 {
            let mark = viewModel.selection.items.first { $0.id == "/f\(index).dcm#0" }
            #expect(mark?.windowCenter == 300)
            #expect(mark?.windowWidth == 1500)
        }
        // …and film 1, which the reader has not turned to, is left alone.
        for index in 4..<6 {
            let mark = viewModel.selection.items.first { $0.id == "/f\(index).dcm#0" }
            #expect(mark?.windowCenter == nil)
            #expect(mark?.windowWidth == nil)
        }
    }

    @Test("Apply to all reaches the focused cell's own film, not always the first")
    func testApplyToAllFollowsTheFocusedFilm() {
        // Focus on the second sheet: the bound is "the film the focused cell is
        // on", not "the first film".
        let items = (0..<6).map {
            PrintSelectionItem(filePath: "/f\($0).dcm", frameIndex: 0)
        }
        let viewModel = makeViewModel(items: items)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2

        viewModel.focusCell("/f4.dcm#0")
        viewModel.setWindow(forItemID: "/f4.dcm#0", center: -600, width: 1200)
        viewModel.applyFocusedWindowToAllCells()

        for index in 4..<6 {
            #expect(viewModel.selection.items.first { $0.id == "/f\(index).dcm#0" }?
                .windowCenter == -600)
        }
        for index in 0..<4 {
            #expect(viewModel.selection.items.first { $0.id == "/f\(index).dcm#0" }?
                .windowCenter == nil)
        }
    }

    @Test("Apply to all carries the focused cell's window space with the numbers")
    func testApplyToAllCarriesSpace() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.focusCell("/a.dcm#0")
        let lung = WindowLevelPreset(name: "Lung", center: -600, width: 1500, modality: "CT")
        viewModel.applyWindowPreset(lung, toItemID: "/a.dcm#0")

        viewModel.applyFocusedWindowToAllCells()

        #expect(viewModel.selection.items.allSatisfy {
            $0.windowCenter == -600 && $0.windowSpace == .outputUnits
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

    /// The other half of the rule above, and the one that was wrong: a *filled*
    /// cell is showing a crop at every zoom, so the pan tool has real travel
    /// there even at zoom 1. Clamping it as though it were fitted zeroed both
    /// axes, and the tool looked dead on a fill-scaled film.
    @Test("A filled cell is a crop, so the pan tool moves it even unzoomed")
    func testPanWorksOnAFilledCellAtZoomOne() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.scalingMode = .fillToFilm

        // A 1000×500 frame covering a square 300-point cell is scaled by 0.6 on
        // its short side, so it is 600 points wide in a 300-point cell: 150
        // points hidden either side, and the drag stops there.
        viewModel.panCell(forItemID: "/a.dcm#0", dx: 1000, dy: 0,
                          cellSize: CGSize(width: 300, height: 300),
                          pixelSize: CGSize(width: 1000, height: 500))

        #expect(viewModel.selection.items[0].presentation?.panX == 150)
    }

    @Test("Zooming a filled cell back out keeps the framing the reader chose")
    func testZoomOutKeepsPanOnAFilledCell() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.scalingMode = .fillToFilm
        let cell = CGSize(width: 300, height: 300)
        let pixels = CGSize(width: 1000, height: 500)

        viewModel.panCell(forItemID: "/a.dcm#0", dx: 100, dy: 0,
                          cellSize: cell, pixelSize: pixels)
        #expect(viewModel.selection.items[0].presentation?.panX == 100)

        // Zoom in and straight back out to 1. On a filled cell zoom 1 is still
        // a crop, so the part of the picture the reader framed must survive —
        // on a fitted cell this same step correctly clears the pan (above).
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2,
                             cellSize: cell, pixelSize: pixels)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 0.5,
                             cellSize: cell, pixelSize: pixels)

        #expect(viewModel.selection.items[0].presentation?.zoom == 1.0)
        #expect(viewModel.selection.items[0].presentation?.panX == 100,
                "zooming back to fitted is not a request to re-frame the crop")
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

    @Test("The rotate tool turns to any angle, both ways, and wraps")
    func testFreeAngleRotation() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)

        // A drag emits many small deltas; they add up to the angle dragged.
        for _ in 0..<10 {
            viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 3, cellSize: cell)
        }
        #expect(viewModel.selection.items[0].presentation?.rotationDegrees == 30)
        // Not a quarter turn, so the film resamples it rather than permuting.
        #expect(viewModel.isCellSkewed("/a.dcm#0"))

        // Dragging back unwinds it, through zero and round the other way.
        viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: -50, cellSize: cell)
        #expect(viewModel.selection.items[0].presentation?.rotationDegrees == 340)
    }

    @Test("Flipping a cell mirrors it, and mirrors it back")
    func testFlipCell() {
        let viewModel = makeViewModel(items: markedFrames)

        viewModel.flipCellHorizontal(forItemID: "/a.dcm#0")
        #expect(viewModel.selection.items[0].presentation?.flipHorizontal == true)
        #expect(viewModel.isCellFlipped("/a.dcm#0"))

        viewModel.flipCellVertical(forItemID: "/a.dcm#0")
        #expect(viewModel.selection.items[0].presentation?.flipVertical == true)

        viewModel.flipCellHorizontal(forItemID: "/a.dcm#0")
        #expect(viewModel.selection.items[0].presentation?.flipHorizontal == false)
        // Still mirrored on the other axis, so still flipped.
        #expect(viewModel.isCellFlipped("/a.dcm#0"))

        viewModel.flipCellVertical(forItemID: "/a.dcm#0")
        #expect(!viewModel.isCellFlipped("/a.dcm#0"))
    }

    @Test("A flip stays on the cell it was made on — laterality is not carried")
    func testFlipIsNeverPropagated() {
        let viewModel = makeViewModel(items: markedFrames)
        // Every lock shut, the widest reach: a flip still goes nowhere, because
        // mirroring a whole film prints a sheet nobody can read.
        viewModel.cellSync = .all
        viewModel.cellSyncScope = .thisFilm

        viewModel.flipCellHorizontal(forItemID: "/a.dcm#0")
        viewModel.flipCellVertical(forItemID: "/a.dcm#0")

        #expect(viewModel.selection.items[0].presentation?.flipHorizontal == true)
        #expect(viewModel.selection.items[0].presentation?.flipVertical == true)
        #expect(viewModel.selection.items[1].presentation?.flipHorizontal != true)
        #expect(viewModel.selection.items[1].presentation?.flipVertical != true)
    }

    @Test("Flipping a cell keeps its window, zoom and angle")
    func testFlipKeepsTheRestOfTheArrangement() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2, cellSize: cell)
        viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 90, cellSize: cell)

        viewModel.flipCellHorizontal(forItemID: "/a.dcm#0", cellSize: cell)

        let mark = viewModel.selection.items[0]
        #expect(mark.presentation?.flipHorizontal == true)
        #expect(mark.presentation?.zoom == 2)
        #expect(mark.presentation?.rotationDegrees == 90)
        #expect(mark.windowCenter == 300)
        #expect(mark.windowWidth == 1500)
    }

    @Test("Straighten squares a cell up without touching its window or crop")
    func testStraighten() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2, cellSize: cell)
        viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 84, cellSize: cell)
        #expect(viewModel.isCellSkewed("/a.dcm#0"))

        viewModel.straightenCell(forItemID: "/a.dcm#0", cellSize: cell)

        let mark = viewModel.selection.items[0]
        #expect(mark.presentation?.rotationDegrees == 90)
        #expect(!viewModel.isCellSkewed("/a.dcm#0"))
        // The rest of the arrangement is left exactly where it was.
        #expect(mark.presentation?.zoom == 2)
        #expect(mark.windowCenter == 300)
        #expect(mark.windowWidth == 1500)
    }

    @Test("A drag of nothing is not an edit")
    func testZeroRotationIsIgnored() {
        let viewModel = makeViewModel(items: markedFrames)
        let cell = CGSize(width: 200, height: 200)

        viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: 0, cellSize: cell)
        viewModel.rotateCell(forItemID: "/a.dcm#0", byDegrees: .nan, cellSize: cell)

        // No presentation written at all, so the cell still counts as untouched
        // and `useViewerPresentation` was not switched on behind the reader.
        #expect(viewModel.selection.items[0].presentation == nil)
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

    @Test("Revert All takes every cell back to what the viewer showed")
    func testRevertAllCells() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.setWindow(forItemID: "/b.dcm#0", center: 90, width: 60)
        viewModel.adjustZoom(forItemID: "/a.dcm#0", factor: 2,
                             cellSize: CGSize(width: 200, height: 200))
        #expect(viewModel.hasAdjustedCells)

        viewModel.revertAllCells()

        #expect(!viewModel.hasAdjustedCells)
        // The viewer's own window survives: revert takes back what *this
        // screen* did, which is exactly the distinction from reset.
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.center == 40)
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.width == 400)
        #expect(viewModel.selection.items[0].presentation == nil)
        // A cell the viewer marked with no window of its own goes back to none,
        // rather than keeping the one set here.
        #expect(viewModel.window(forItemID: "/b.dcm#0") == nil)
        // …and every cell follows the screen again.
        #expect(viewModel.selection.update(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 0,
            windowCenter: 55, windowWidth: 200)) == true)
    }

    @Test("Revert All is quiet when nothing has been adjusted")
    func testRevertAllWithNothingToTakeBack() {
        let viewModel = makeViewModel(items: markedFrames)
        #expect(!viewModel.hasAdjustedCells)

        viewModel.revertAllCells()

        // The marks are untouched, and specifically the viewer's window is not
        // cleared by a revert that had nothing to revert.
        #expect(viewModel.window(forItemID: "/a.dcm#0")?.center == 40)
        #expect(!viewModel.hasAdjustedCells)
    }

    @Test("Revert on the focused cell takes back that cell alone")
    func testRevertFocusedCell() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setWindow(forItemID: "/a.dcm#0", center: 300, width: 1500)
        viewModel.setWindow(forItemID: "/b.dcm#0", center: 90, width: 60)
        viewModel.focusCell("/a.dcm#0")

        viewModel.revertFocusedCell()

        #expect(viewModel.window(forItemID: "/a.dcm#0")?.center == 40)
        #expect(viewModel.window(forItemID: "/b.dcm#0")?.center == 90,
                "the cell that was not focused keeps its edit")
        #expect(viewModel.hasAdjustedCells)
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

    // MARK: - Film palette across visits

    @Test("Reopening the print screen gives back a grey film")
    func testFilmPaletteResetsForNewFilm() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.applyFilmPalette(.hotIron)
        #expect(viewModel.filmPalette == .hotIron)

        // The screen is kept alive between visits, so the second launch runs
        // the same reset the first one did.
        viewModel.resetForNewFilm()
        #expect(viewModel.filmPalette == nil)
        for item in viewModel.selection.items {
            #expect(item.presentation?.palette == nil)
        }
    }

    @Test("The palette picker still colours the film on a second launch")
    func testFilmPaletteAppliesAfterRelaunch() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.applyFilmPalette(.hotIron)
        viewModel.resetForNewFilm()

        // The bug: the stale film palette made every cell look self-chosen, so
        // this pick reached none of them and the picker read dead.
        viewModel.applyFilmPalette(.pet)
        #expect(viewModel.filmPalette == .pet)
        for item in viewModel.selection.items {
            #expect(item.presentation?.palette == .pet)
        }
    }

    @Test("A cell that chose its own palette keeps it through a film-wide pick")
    func testSelfChosenPaletteSurvivesFilmPalette() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.setCellPalette(.pet, forItemID: "/a.dcm#0")

        viewModel.applyFilmPalette(.hotIron)
        #expect(viewModel.cellPalette(forItemID: "/a.dcm#0") == .pet)
        #expect(viewModel.cellPalette(forItemID: "/b.dcm#0") == .hotIron)
    }

    @Test("Resetting a cell hands it back to the film's picker")
    func testResetCellFollowsFilmAgain() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.applyFilmPalette(.hotIron)
        viewModel.setCellPalette(.pet, forItemID: "/a.dcm#0")
        viewModel.resetCell(forItemID: "/a.dcm#0")

        // Reset gives the cell back to the film, so the next film-wide pick
        // must reach it — the drift that previously stranded it for good.
        #expect(viewModel.cellPalette(forItemID: "/a.dcm#0") == .hotIron)
        viewModel.applyFilmPalette(.pet)
        #expect(viewModel.cellPalette(forItemID: "/a.dcm#0") == .pet)
    }

    @Test("Picking the film's own colour by hand does not strand the cell")
    func testHandPickingFilmColourStillFollows() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.applyFilmPalette(.hotIron)
        viewModel.setCellPalette(.hotIron, forItemID: "/a.dcm#0")

        viewModel.applyFilmPalette(.pet)
        #expect(viewModel.cellPalette(forItemID: "/a.dcm#0") == .pet)
    }

    @Test("Grey chosen on a coloured film is a choice and is defended")
    func testGreyIsAChoice() {
        let viewModel = makeViewModel(items: markedFrames)
        viewModel.applyFilmPalette(.hotIron)
        viewModel.setCellPalette(.grayscale, forItemID: "/a.dcm#0")

        viewModel.applyFilmPalette(.pet)
        #expect(viewModel.cellPalette(forItemID: "/a.dcm#0") == .grayscale)
        #expect(viewModel.cellPalette(forItemID: "/b.dcm#0") == .pet)
    }
}
