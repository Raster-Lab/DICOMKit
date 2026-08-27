// PrintFilmResetTests.swift
// DICOMStudioTests
//
// Opening the print screen on a new set of marks.
//
// The screen is kept alive between visits, so reopening it is instant and the
// printer stays chosen. That is only safe if everything describing the *film* is
// dropped when the marks change: a range filtering a series nobody is printing,
// arrows drawn on cells that no longer exist, and image numbers cached from the
// old paths each print something other than what was ticked.
//
// The other half of the property matters just as much — a reader who picked a
// printer and a film size once should not have to pick them again for every
// study. So this checks both what goes and what stays.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Film Reset Tests")
struct PrintFilmResetTests {

    /// `count` frames of one series, numbered as a scanner would.
    private func makeSelection(count: Int, series: String, prefix: String) -> PrintSelectionModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (1...count).map {
            PrintSelectionItem(filePath: "\(prefix)/\($0).dcm", frameIndex: 0,
                               seriesInstanceUID: series, instanceNumber: $0)
        })
        return selection
    }

    // MARK: - What goes

    @Test("A range from the last study does not filter the new one")
    func testRangeIsDropped() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 20, series: "1.2.3", prefix: "/a"))
        viewModel.setImageRange(from: 5, to: 8)
        #expect(viewModel.printedItems.count == 4, "the range is filtering to begin with")

        viewModel.selection.replace(with: makeSelection(count: 12, series: "9.9.9", prefix: "/b").items)
        viewModel.resetForNewFilm()

        #expect(!viewModel.isImageRangeActive, "a new film starts unfiltered")
        #expect(viewModel.printedItems.count == 12, "every newly marked image is on the film")
        #expect(viewModel.imageRanges.isEmpty,
                "no series keeps a range from the old film")
    }

    @Test("Text and arrows drawn on an image marked for the new film reappear on it")
    func testAnnotationsSurviveOnAnImageStillMarked() {
        let selection = makeSelection(count: 4, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        let cell = selection.items[0].id

        // Typed into, because an empty text box is discarded as soon as the
        // focus leaves it — that is a different rule, tested elsewhere.
        let text = viewModel.addTextAnnotation(forItemID: cell, at: PrintOverlayPoint(x: 0.5, y: 0.5))
        viewModel.setAnnotationText("lesion", id: text, forItemID: cell)
        viewModel.addArrowAnnotation(
            forItemID: cell,
            from: PrintOverlayPoint(x: 0.1, y: 0.1),
            to: PrintOverlayPoint(x: 0.4, y: 0.4))
        #expect(viewModel.annotations(forItemID: cell).count == 2)

        viewModel.resetForNewFilm()

        // Annotations belong to the image, not to the print sheet's session —
        // the same file/frame is still marked, so what was drawn on it stays.
        #expect(viewModel.annotations(forItemID: cell).count == 2,
                "the mark still points at the same image, so its drawing stays")
        #expect(viewModel.selectedAnnotationID == nil, "nothing is left selected for editing")
    }

    @Test("Text and arrows drawn on an image dropped from the film do not reappear")
    func testAnnotationsAreDroppedForUnmarkedImages() {
        let selection = makeSelection(count: 4, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        let cell = selection.items[0].id

        let text = viewModel.addTextAnnotation(forItemID: cell, at: PrintOverlayPoint(x: 0.5, y: 0.5))
        viewModel.setAnnotationText("lesion", id: text, forItemID: cell)
        #expect(viewModel.annotations(forItemID: cell).count == 1)

        viewModel.selection.replace(with: makeSelection(count: 12, series: "9.9.9", prefix: "/b").items)
        viewModel.selection.pruneAnnotations()
        viewModel.resetForNewFilm()

        #expect(viewModel.annotations(forItemID: cell).isEmpty,
                "the image that was drawn on is no longer marked anywhere")
        #expect(viewModel.selectedAnnotationID == nil, "nothing is left selected for editing")
    }

    @Test("Cells picked out on the last film are not still picked out")
    func testSelectionAndFocusAreDropped() {
        let selection = makeSelection(count: 6, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        viewModel.selectCells(selection.items.prefix(3).map(\.id))
        viewModel.focusedItemID = selection.items[2].id
        #expect(!viewModel.selectedItemIDs.isEmpty)

        viewModel.resetForNewFilm()

        #expect(viewModel.selectedItemIDs.isEmpty)
        #expect(viewModel.focusedItemID == nil)
    }

    @Test("A new film opens ready to configure, with a clear console")
    func testConsoleAndPhaseAreReset() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 2, series: "1.2.3", prefix: "/a"))

        viewModel.resetForNewFilm()

        #expect(viewModel.consoleLines.isEmpty, "not a transcript of every past visit")
        #expect(viewModel.progress == 0)
        #expect(viewModel.result == nil, "the last job's outcome is not this film's")
        if case .configuring = viewModel.phase {} else {
            Issue.record("a new film opens ready to configure, not showing the last job's result")
        }
    }

    // MARK: - What stays

    @Test("The printer survives, because it is infrastructure and not a film")
    func testPrinterSurvives() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 4, series: "1.2.3", prefix: "/a"))
        let printer = UUID()
        viewModel.selectedPrinterID = printer
        viewModel.timeoutSeconds = 90
        viewModel.retries = 3

        viewModel.resetForNewFilm()

        #expect(viewModel.selectedPrinterID == printer, "the printer is a department setting")
        #expect(viewModel.timeoutSeconds == 90, "how to reach the printer is not a film setting")
        #expect(viewModel.retries == 3)
    }

    /// The film's own description is *not* infrastructure. Left standing it
    /// describes the previous sheet, and the reader has no way to tell a
    /// carried-over choice from a deliberate one.
    @Test("A launch gives back the default sheet, not the last film's")
    func testFilmSettingsResetToDefaults() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 4, series: "1.2.3", prefix: "/a"))
        viewModel.filmSize = .size8InX10In
        viewModel.filmOrientation = .landscape
        viewModel.mediumType = .clearFilm
        viewModel.copies = 3
        viewModel.showPatientIdentification = false
        viewModel.priority = .high
        viewModel.trimOption = .yes
        viewModel.sessionLabel = "LAST VISIT"
        viewModel.scalingMode = .stretch
        viewModel.cellAlignment = .topLeft

        viewModel.resetForNewFilm()

        #expect(viewModel.filmSize == .size14InX17In)
        #expect(viewModel.filmOrientation == .portrait)
        #expect(viewModel.mediumType == .blueFilm)
        #expect(viewModel.copies == 1)
        #expect(viewModel.showPatientIdentification)
        #expect(viewModel.priority == .medium)
        #expect(viewModel.trimOption == .no)
        #expect(viewModel.sessionLabel.isEmpty)
        #expect(viewModel.scalingMode == .fitToFilm)
        #expect(viewModel.cellAlignment == .center)
    }

    /// The two that prompted this: both silently restyle every cell on the
    /// sheet, and a reader who sees a coloured or inverted film has no reason
    /// to suspect a control three disclosure groups down.
    @Test("A launch clears the palette and the presentation LUT")
    func testRenderingSettingsResetToDefaults() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 4, series: "1.2.3", prefix: "/a"))
        viewModel.applyFilmPalette(.hotIron)
        viewModel.presentationLUTShape = .identity
        viewModel.bitDepth = 12
        viewModel.sendRawPixels = true
        viewModel.useExplicitWindow = true
        viewModel.explicitWindowCenter = 900
        viewModel.explicitWindowWidth = 1800
        viewModel.autoDetectColorMode = false
        viewModel.colorMode = .color
        viewModel.useViewerWindow = false
        viewModel.useViewerPresentation = false

        viewModel.resetForNewFilm()

        #expect(viewModel.filmPalette == nil, "a new film is not the last film's colour")
        for mark in viewModel.selection.items {
            #expect(mark.presentation?.palette == nil, "and neither is any cell on it")
        }
        #expect(viewModel.presentationLUTShape == nil)
        #expect(viewModel.bitDepth == 8)
        #expect(!viewModel.sendRawPixels)
        #expect(!viewModel.useExplicitWindow)
        #expect(viewModel.explicitWindowCenter == 40)
        #expect(viewModel.explicitWindowWidth == 400)
        #expect(viewModel.autoDetectColorMode)
        #expect(viewModel.colorMode == .grayscale)
        #expect(viewModel.useViewerWindow)
        #expect(viewModel.useViewerPresentation)
    }

    @Test("A launch resets the burned identification to its defaults")
    func testIdentificationResetsToDefaults() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 2, series: "1.2.3", prefix: "/a"))
        viewModel.identificationFields = [.accessionNumber]
        viewModel.identificationUsesCustomSize = true
        viewModel.identificationSizePercent = 9
        viewModel.identificationForeground = .black
        viewModel.burnDrawnAnnotations = false

        viewModel.resetForNewFilm()

        #expect(viewModel.identificationFields == [.birthDate, .institutionName])
        #expect(!viewModel.identificationUsesCustomSize)
        #expect(viewModel.identificationSizePercent == 3.5)
        #expect(viewModel.identificationForeground == .automatic)
        #expect(viewModel.burnDrawnAnnotations)
    }

    // MARK: - What the screen re-arms

    /// The tools and the locks do *not* survive a visit, unlike the settings
    /// above.
    ///
    /// They were treated as working habits, and the difference is that a habit
    /// is visible when you come back to it while an armed mode is not. A reader
    /// who left the pan tool armed with the W/L lock shut sees a rail at the
    /// edge of the screen and a film in front of them; the first drag of the
    /// next visit then pans four cells they meant to window, and it has already
    /// happened by the time the rail explains why.
    @Test("A new film opens with the tools and locks back to how the screen opens")
    func testToolsAndLocksAreReArmed() {
        let selection = makeSelection(count: 4, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        viewModel.cellTool = .pan
        viewModel.cellSync = [.window, .zoomPan]
        viewModel.cellSyncScope = .thisFilm
        viewModel.focusedItemID = selection.items[2].id
        viewModel.selectedItemIDs = [selection.items[0].id, selection.items[1].id]

        viewModel.resetForNewFilm()

        #expect(viewModel.cellTool == .window, "windowing is what the screen opens armed with")
        #expect(viewModel.cellSync.isEmpty, "no drag reaches a second cell until a lock is shut")
        #expect(viewModel.cellSyncScope == .sameSeries)
        #expect(viewModel.focusedItemID == nil)
        #expect(viewModel.selectedItemIDs.isEmpty)
    }

    /// Re-arming is also available on its own, for the screen being reopened on
    /// the same marks — the window can be raised again without a new film.
    @Test("Re-arming the tools leaves the film and the job settings alone")
    func testReArmingTouchesNothingElse() {
        let selection = makeSelection(count: 4, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        viewModel.filmSize = .size8InX10In
        viewModel.copies = 3
        viewModel.cellTool = .arrow
        viewModel.cellSync = .invert

        viewModel.resetPreviewTools()

        #expect(viewModel.cellTool == .window)
        #expect(viewModel.cellSync.isEmpty)
        #expect(viewModel.filmSize == .size8InX10In, "a job setting, not a mode")
        #expect(viewModel.copies == 3)
        #expect(viewModel.selection.count == 4, "the marks are not the tools")
    }

    @Test("The marks themselves survive — the reset clears the film, not the selection")
    func testTheMarksSurvive() {
        let selection = makeSelection(count: 7, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        viewModel.selection.adjust(
            selection.items[3].with(windowCenter: .some(60), windowWidth: .some(360)))

        viewModel.resetForNewFilm()

        #expect(viewModel.selection.count == 7, "what was ticked stays ticked")
    }

    // MARK: - A launch opens on the plain images

    /// Marks as the viewer takes them: carrying the window and arrangement the
    /// reader had on screen at the moment they ticked the box.
    private func makeViewerMarkedSelection(count: Int = 5) -> PrintSelectionModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: (1...count).map {
            PrintSelectionItem(
                filePath: "/a/\($0).dcm", frameIndex: 0,
                seriesInstanceUID: "1.2.3", instanceNumber: $0,
                windowCenter: 40, windowWidth: 400,
                presentation: ViewerPresentation(zoom: 2.5, panX: 30, panY: -10,
                                                 viewportWidth: 800, viewportHeight: 600,
                                                 rotationDegrees: 90, invert: true))
        })
        return selection
    }

    /// With both switches off, the film screen is where a film is composed and
    /// the work stays there: a launch shows every marked image as the file
    /// holds it — not wearing the zooms and windows of a reading session, and
    /// not wearing the tool work of a previous visit to this screen.
    @Test("A launch resets every mark when the viewer-matching switches are off")
    func testLaunchResetsToolActionsOnEveryMark() {
        let selection = makeViewerMarkedSelection()
        let viewModel = PrintViewModel(selection: selection)

        // The switches are part of what a launch puts back to default (both
        // default to on), so turning them off *before* the reset would only
        // test the reset undoing itself. The real launch order is the same:
        // the caller applies its own settings after the screen has been reset.
        viewModel.resetForNewFilm()
        viewModel.useViewerWindow = false
        viewModel.useViewerPresentation = false
        viewModel.resetCellToolsForNewFilm()

        #expect(viewModel.selection.count == 5, "every marked image is still on the film")
        for mark in viewModel.selection.items {
            #expect(mark.windowCenter == nil, "the cell opens with the file's own window")
            #expect(mark.windowWidth == nil)
            #expect(mark.presentation == nil,
                    "no zoom, pan, rotation or inversion carried in from the viewer")
            #expect(!viewModel.isCellEdited(mark), "so nothing lights Reset on a fresh film")
        }
        #expect(!viewModel.hasEditedCells)
    }

    /// The switches are standing instructions about how film relates to screen,
    /// so a launch must not quietly overrule them. Wiping every mark on the way
    /// in is what made "Match the viewer's window/level" look dead: there was
    /// nothing left in the mark for it to match, and no amount of toggling
    /// brought the reading session's window back.
    @Test("A launch keeps the viewer's window and arrangement while the switches ask for them")
    func testLaunchKeepsViewerStateWhenMatchingIsOn() {
        let selection = makeViewerMarkedSelection()
        let viewModel = PrintViewModel(selection: selection)
        // Both default to on; stated here because that is what is under test.
        viewModel.useViewerWindow = true
        viewModel.useViewerPresentation = true

        viewModel.resetForNewFilm()

        #expect(viewModel.selection.count == 5)
        for mark in viewModel.selection.items {
            #expect(mark.windowCenter == 40, "the screen's window survives the launch")
            #expect(mark.windowWidth == 400)
            #expect(mark.presentation?.zoom == 2.5,
                    "and so does the zoom, pan, rotation and inversion")
            #expect(mark.presentation?.rotationDegrees == 90)
            #expect(mark.presentation?.invert == true)
        }
        // And the preview renders what the printer will receive.
        for item in viewModel.previewItems {
            #expect(item.windowCenter == 40)
            #expect(item.presentation?.zoom == 2.5)
        }
    }

    /// The two switches are independent: matching the window without adopting
    /// the reader's zoom is a legitimate film, and vice versa.
    @Test("Each viewer-matching switch is honoured on its own")
    func testLaunchHonoursEachMatchingSwitchIndependently() {
        // Set after the launch reset, which restores both switches to on —
        // the reset is what establishes the default, and these two films are
        // about what each switch then does to the marks.
        let windowOnly = PrintViewModel(selection: makeViewerMarkedSelection(count: 2))
        windowOnly.resetForNewFilm()
        windowOnly.useViewerWindow = true
        windowOnly.useViewerPresentation = false
        windowOnly.resetCellToolsForNewFilm()
        for mark in windowOnly.selection.items {
            #expect(mark.windowCenter == 40, "the window is matched")
            #expect(mark.presentation == nil, "the arrangement is not")
        }

        let shapeOnly = PrintViewModel(selection: makeViewerMarkedSelection(count: 2))
        shapeOnly.resetForNewFilm()
        shapeOnly.useViewerWindow = false
        shapeOnly.useViewerPresentation = true
        shapeOnly.resetCellToolsForNewFilm()
        for mark in shapeOnly.selection.items {
            #expect(mark.windowCenter == nil, "the window is not matched")
            #expect(mark.presentation?.zoom == 2.5, "the arrangement is")
        }
    }

    /// What is drawn on an image is about the anatomy under it, so it outlives
    /// the film it was drawn on — while the zoom that framed it does not.
    @Test("A launch keeps what was drawn on an image and resets only the tools")
    func testLaunchKeepsAnnotationsButResetsTools() {
        let selection = makeSelection(count: 3, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        let cell = selection.items[0].id

        let text = viewModel.addTextAnnotation(forItemID: cell, at: PrintOverlayPoint(x: 0.5, y: 0.5))
        viewModel.setAnnotationText("lesion", id: text, forItemID: cell)
        viewModel.addArrowAnnotation(
            forItemID: cell,
            from: PrintOverlayPoint(x: 0.1, y: 0.1),
            to: PrintOverlayPoint(x: 0.4, y: 0.4))
        // …and the cell was windowed and zoomed to draw them.
        viewModel.setWindow(forItemID: cell, center: 60, width: 360)
        viewModel.adjustZoom(forItemID: cell, factor: 3,
                             cellSize: CGSize(width: 200, height: 200))

        viewModel.resetForNewFilm()

        #expect(viewModel.annotations(forItemID: cell).count == 2,
                "the finding an arrow marks is not undone by opening a new film")
        let mark = viewModel.selection.items.first { $0.id == cell }
        #expect(mark?.windowCenter == nil, "the windowing that framed it is")
        #expect(mark?.presentation == nil, "and so is the zoom")
    }

    /// The tray reports the selection, not the sheet being composed beside it.
    @Test("Film-screen tool work never reaches the viewer's tray")
    func testTrayShowsImagesAsMarked() {
        let selection = makeSelection(count: 3, series: "1.2.3", prefix: "/a")
        let asMarked = selection.items[1]
        let viewModel = PrintViewModel(selection: selection)

        viewModel.setWindow(forItemID: asMarked.id, center: 900, width: 1800)
        viewModel.adjustZoom(forItemID: asMarked.id, factor: 4,
                             cellSize: CGSize(width: 200, height: 200))

        // The film reads the live mark — that is the picture being sent.
        let onFilm = viewModel.selection.items.first { $0.id == asMarked.id }
        #expect(onFilm?.windowCenter == 900)
        #expect(onFilm?.presentation?.zoom == 4)

        // The tray reads the image as it was picked, so its row does not
        // re-render on every drag happening on the print screen beside it.
        let inTray = viewModel.selection.itemsAsMarked.first { $0.id == asMarked.id }
        #expect(inTray?.windowCenter == asMarked.windowCenter)
        #expect(inTray?.presentation == nil)
        #expect(viewModel.selection.itemsAsMarked.map(\.id) ==
                viewModel.selection.items.map(\.id),
                "same images, same film order — only the arrangement differs")
    }

    /// The re-sync on reopening only reaches marks the viewer has on screen, so
    /// merely unflagging an adjustment left every *other* cell wearing the last
    /// visit's edits — cancel the screen, click Print again, and the film still
    /// showed the pans and windows the cancel appeared to discard.
    @Test("Hand edits from the last visit are taken back, on-screen or not")
    func testHandEditsAreRevertedForCellsTheViewerCannotResync() {
        let selection = makeSelection(count: 7, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        let offScreen = selection.items[3]
        // Windowed and panned by hand in the preview, first visit.
        viewModel.setWindow(forItemID: offScreen.id, center: 60, width: 360)
        viewModel.panCell(forItemID: offScreen.id, dx: 40, dy: 0,
                          cellSize: CGSize(width: 200, height: 200))
        #expect(viewModel.selection.isAdjusted(offScreen.id))

        // Cancel, then reopen from the viewer's print icon. No viewer re-sync
        // follows for this mark: the file is not the one on screen.
        viewModel.resetForNewFilm()

        let kept = viewModel.selection.items.first { $0.id == offScreen.id }
        #expect(viewModel.selection.isAdjusted(offScreen.id) == false,
                "the mark follows the viewer again")
        #expect(kept?.windowCenter == nil, "the visit's windowing is gone")
        #expect(kept?.presentation == nil, "the visit's pan is gone")
    }

    // MARK: - When the reset runs at all

    /// Opening the print screen is a request to see the film, not an order to
    /// tear it up. `resetForNewFilmIfNeeded()` is what every open goes
    /// through, and it cuts a fresh sheet only for a genuinely new film — a
    /// changed tray, or a job that has finished.

    @Test("Reopening on the same marks keeps the film in progress")
    func testSameMarksKeepTheFilm() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 20, series: "1.2.3", prefix: "/a"))
        viewModel.resetForNewFilmIfNeeded()  // first open: a fresh sheet

        // Half a film's work: a range, a layout, copies.
        viewModel.setImageRange(from: 5, to: 8)
        viewModel.layoutOption = .layout3x3
        viewModel.copies = 3

        viewModel.resetForNewFilmIfNeeded()  // back to the viewer and in again

        #expect(viewModel.isImageRangeActive, "the range is the visit's work, and the visit goes on")
        #expect(viewModel.printedItems.count == 4)
        #expect(viewModel.layoutOption == .layout3x3)
        #expect(viewModel.copies == 3)
    }

    @Test("A changed tray cuts a fresh sheet")
    func testChangedMarksReset() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 20, series: "1.2.3", prefix: "/a"))
        viewModel.resetForNewFilmIfNeeded()
        viewModel.setImageRange(from: 5, to: 8)

        // The reader goes back and marks a different set.
        viewModel.selection.replace(with: makeSelection(count: 12, series: "9.9.9", prefix: "/b").items)
        viewModel.resetForNewFilmIfNeeded()

        #expect(!viewModel.isImageRangeActive, "the old range filtered a tray that is gone")
        #expect(viewModel.printedItems.count == 12)
    }

    @Test("One image added to the tray is a changed tray")
    func testAddedMarkResets() {
        let selection = makeSelection(count: 4, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        viewModel.resetForNewFilmIfNeeded()
        viewModel.copies = 5

        viewModel.selection.add(PrintSelectionItem(
            filePath: "/a/99.dcm", frameIndex: 0,
            seriesInstanceUID: "1.2.3", instanceNumber: 99))
        viewModel.resetForNewFilmIfNeeded()

        #expect(viewModel.copies == 1, "the film described the old tray")
    }

    @Test("After a finished job the same marks still open a fresh sheet")
    func testFinishedJobResets() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 4, series: "1.2.3", prefix: "/a"))
        viewModel.resetForNewFilmIfNeeded()
        viewModel.copies = 5
        viewModel.phase = .finished(success: true)

        viewModel.resetForNewFilmIfNeeded()

        #expect(viewModel.copies == 1, "a printed film is done; the next visit is the next film")
        if case .configuring = viewModel.phase {} else {
            Issue.record("the next visit opens composing, not on the old job's result")
        }
    }

    @Test("Reopening on a job still printing leaves the run alone")
    func testRunningJobIsLeftAlone() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 4, series: "1.2.3", prefix: "/a"))
        viewModel.resetForNewFilmIfNeeded()
        viewModel.phase = .printing

        viewModel.resetForNewFilmIfNeeded()

        if case .printing = viewModel.phase {} else {
            Issue.record("reopening the screen mid-print shows the run, it does not tear it down")
        }
    }
}
