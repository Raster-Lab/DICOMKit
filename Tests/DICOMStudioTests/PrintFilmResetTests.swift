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

    @Test("Text and arrows drawn on the last film do not reappear on the new one")
    func testAnnotationsAreDropped() {
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

        #expect(viewModel.annotations(forItemID: cell).isEmpty)
        #expect(viewModel.cellAnnotations.isEmpty, "no cell keeps a drawing")
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

    @Test("The printer and the film settings are not forgotten between studies")
    func testDepartmentSettingsSurvive() {
        let viewModel = PrintViewModel(selection: makeSelection(count: 4, series: "1.2.3", prefix: "/a"))
        let printer = UUID()
        viewModel.selectedPrinterID = printer
        viewModel.filmSize = .size8InX10In
        viewModel.filmOrientation = .landscape
        viewModel.mediumType = .clearFilm
        viewModel.copies = 3
        viewModel.showPatientIdentification = false

        viewModel.resetForNewFilm()

        #expect(viewModel.selectedPrinterID == printer, "the printer is a department setting")
        #expect(viewModel.filmSize == .size8InX10In)
        #expect(viewModel.filmOrientation == .landscape)
        #expect(viewModel.mediumType == .clearFilm)
        #expect(viewModel.copies == 3)
        #expect(viewModel.showPatientIdentification == false)
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

    @Test("The marks themselves are untouched — the reset clears the film, not the selection")
    func testTheMarksSurvive() {
        let selection = makeSelection(count: 7, series: "1.2.3", prefix: "/a")
        let viewModel = PrintViewModel(selection: selection)
        viewModel.selection.adjust(
            selection.items[3].with(windowCenter: .some(60), windowWidth: .some(360)))

        viewModel.resetForNewFilm()

        #expect(viewModel.selection.count == 7)
        let kept = viewModel.selection.items.first { $0.id == selection.items[3].id }
        #expect(kept?.windowCenter == 60, "windowing done on a mark belongs to the mark")
        #expect(kept?.windowWidth == 360)
    }
}
