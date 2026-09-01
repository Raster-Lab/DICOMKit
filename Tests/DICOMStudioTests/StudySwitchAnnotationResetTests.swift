// StudySwitchAnnotationResetTests.swift
// DICOMStudioTests
//
// Drawn annotations are tool state, and reset with the study like every other
// tool. Window, zoom and rotation were already dropped by the study switch;
// the drawings were the one thing that stayed behind, keyed to the previous
// study's file paths, and came back the next time that study was opened.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@Suite("Study switch resets drawn annotations")
@MainActor
struct StudySwitchAnnotationResetTests {

    @Test("Opening a different study drops the previous study's drawings")
    func drawingsDoNotSurviveStudySwitch() {
        let viewModel = ImageViewerViewModel()
        let store = viewModel.printSelection

        // Drawn on an image that is on screen but not marked for print — the
        // ordinary viewer case, which `clear()` (marks only) never reached.
        let unmarked = ImageAnnotationKey(filePath: "/study-a/1.dcm", frameIndex: 0)
        store.addTextAnnotation(forKey: unmarked, at: PrintOverlayPoint(x: 0.3, y: 0.3))
        store.addArrowAnnotation(
            forKey: unmarked,
            from: PrintOverlayPoint(x: 0.1, y: 0.1),
            to: PrintOverlayPoint(x: 0.5, y: 0.5))

        // And on a marked one, so both addressing modes are covered.
        store.add(PrintSelectionItem(filePath: "/study-a/2.dcm"))
        let marked = ImageAnnotationKey(filePath: "/study-a/2.dcm", frameIndex: 0)
        let id = store.addTextAnnotation(forKey: marked, at: PrintOverlayPoint(x: 0.5, y: 0.5))
        store.selectedAnnotationID = id

        // Presence, not a count: a blank text box is dropped by the store's
        // own rules when another drawing is added, and that is not what is
        // under test here.
        #expect(!store.annotations(forKey: unmarked).isEmpty)
        #expect(!store.annotations(forKey: marked).isEmpty)

        viewModel.prepareForNewStudy()

        #expect(store.annotations(forKey: unmarked).isEmpty)
        #expect(store.annotations(forKey: marked).isEmpty)
        #expect(store.cellAnnotations.isEmpty)
        // A selection pointing at a drawing that no longer exists would leave
        // the inspector editing nothing.
        #expect(store.selectedAnnotationID == nil)
    }

    @Test("Closing a deleted study drops its drawings too")
    func drawingsDoNotSurviveClose() {
        let viewModel = ImageViewerViewModel()
        let key = ImageAnnotationKey(filePath: "/study-a/1.dcm", frameIndex: 0)
        viewModel.printSelection.addTextAnnotation(forKey: key, at: PrintOverlayPoint(x: 0.5, y: 0.5))

        viewModel.closeStudy()

        #expect(viewModel.printSelection.cellAnnotations.isEmpty)
    }
}
