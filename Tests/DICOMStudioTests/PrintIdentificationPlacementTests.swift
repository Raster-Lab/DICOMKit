// PrintIdentificationPlacementTests.swift
// DICOMStudioTests
//
// Where a print job puts the patient's name.
//
// The property under test: a film states its identification once only when the
// whole sheet is one study, and whatever the film does *not* say at its foot it
// says under each image. Between the two of them every marked frame on a film
// is always identifiable — a sheet that says nothing about its patient is the
// one outcome none of these paths may produce.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@MainActor
@Suite("Print Identification Placement Tests")
struct PrintIdentificationPlacementTests {

    private func makeViewModel(items: [PrintSelectionItem]) -> PrintViewModel {
        let selection = PrintSelectionModel()
        selection.add(contentsOf: items)
        return PrintViewModel(selection: selection)
    }

    private func text(_ study: String, patient: String = "DOE^JANE") -> PatientOverlayText {
        PatientOverlayText(primaryLine: "\(patient), 711794, 2026-08-01",
                           secondaryLine: "CT ABDOMEN",
                           studyInstanceUID: study)
    }

    private var fourFrames: [PrintSelectionItem] {
        (0..<4).map { PrintSelectionItem(filePath: "/\($0).dcm", frameIndex: 0) }
    }

    // MARK: One film

    @Test("A film of one study says whose it is once, at its foot")
    func testSingleStudyFilmIsFootered() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        let items = viewModel.selection.items
        let texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        #expect(identifications.count == 1)
        #expect(identifications[0].footerLines == ["DOE^JANE, 711794, 2026-08-01", "CT ABDOMEN"])

        // Nothing is burned under the pictures: the sheet has already said it.
        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications,
            plan: plan, footersDelivered: true)
        #expect(burns.isEmpty)
    }

    @Test("A film mixing studies captions every image instead")
    func testMixedStudyFilmCaptionsEachImage() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        let items = viewModel.selection.items
        var texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        texts["/3.dcm"] = text("9.9.9", patient: "ROE^RICHARD")
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        #expect(identifications[0] == .perImage)

        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications,
            plan: plan, footersDelivered: true)
        #expect(burns.count == items.count)
        #expect(burns["/3.dcm#0"]?.first?.hasPrefix("ROE^RICHARD") == true)
    }

    // MARK: Two films

    @Test("Each sheet of a spilling job is decided on its own")
    func testFilmsAreDecidedIndependently() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .custom
        viewModel.customLayoutText = "STANDARD\\2,1"
        let items = viewModel.selection.items
        var texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        // The second sheet is a different study; the first is untouched.
        texts["/2.dcm"] = text("9.9.9", patient: "ROE^RICHARD")
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        #expect(plan.filmCount == 2)
        #expect(identifications[0].footerLines.first?.hasPrefix("DOE^JANE") == true)
        #expect(identifications[1] == .perImage)

        // Only the mixed sheet's images carry their own caption.
        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications,
            plan: plan, footersDelivered: true)
        #expect(Set(burns.keys) == ["/2.dcm#0", "/3.dcm#0"])
    }

    // MARK: Fallback

    @Test("A footer that cannot reach the film is burned under each image instead")
    func testUndeliverableFooterFallsBackToBurning() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        let items = viewModel.selection.items
        let texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        let plan = viewModel.request.plan(forImageCount: items.count)
        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications,
            plan: plan, footersDelivered: false)

        #expect(burns.count == items.count)
    }

    // MARK: Placement override

    @Test("Forcing per-image captions overrides a single-study film")
    func testForcedPerImagePlacement() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        viewModel.identificationPlacement = .perImage
        let items = viewModel.selection.items
        let texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        #expect(identifications[0] == .perImage)
    }

    @Test("Identification switched off leaves the film alone")
    func testIdentificationOff() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.showPatientIdentification = false
        let items = viewModel.selection.items
        let texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        #expect(identifications.allSatisfy { $0 == .none })
        #expect(viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications,
            plan: plan, footersDelivered: false).isEmpty)
    }
}
