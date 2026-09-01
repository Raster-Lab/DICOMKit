// PrintIdentificationPlacementTests.swift
// DICOMStudioTests
//
// Where a print job puts the patient's name.
//
// The property under test: every marked frame on a film carries its own
// identification, burned into the corners of the picture it belongs to. It
// states the technique of that image as well as the patient, so there is nothing
// one line at the foot of a sheet could say for all of them — and a sheet that
// says nothing about its patient is the one outcome none of these paths may
// produce.

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
        PatientOverlayText(patientLine: "\(patient), 711794",
                           studyDate: "2026-08-01 09:14",
                           studyDescription: "CT ABDOMEN",
                           modalityLine: "Modality: CT",
                           positionLine: "Image: 5",
                           techniqueLines: ["Slice Thickness: 5.00 mm", "kVp: 120"],
                           studyInstanceUID: study)
    }

    private var fourFrames: [PrintSelectionItem] {
        (0..<4).map { PrintSelectionItem(filePath: "/\($0).dcm", frameIndex: 0) }
    }

    // MARK: One film

    @Test("Every image on a single-study film still carries its own caption")
    func testSingleStudyFilmCaptionsEachImage() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        let items = viewModel.selection.items
        let texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)

        #expect(identifications.count == 1)
        #expect(identifications[0] == .perImage)
        #expect(identifications[0].footerLines.isEmpty, "no film states its identification once")

        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications, plan: plan)
        #expect(burns.count == items.count)
        // Who and what at the top right, what made the picture at the bottom
        // left — the second of those is why the caption cannot be lifted to the
        // foot of the sheet.
        #expect(burns["/0.dcm#0"]?.topRight == ["DOE^JANE, 711794", "CT ABDOMEN"])
        #expect(burns["/0.dcm#0"]?.bottomLeft.contains("Slice Thickness: 5.00 mm") == true)
        #expect(burns["/0.dcm#0"]?.bottomRight == ["2026-08-01 09:14"])
    }

    @Test("A film mixing studies captions every image too")
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
            for: items, texts: texts, identifications: identifications, plan: plan)
        #expect(burns.count == items.count)
        #expect(burns["/3.dcm#0"]?.topRight.first?.hasPrefix("ROE^RICHARD") == true)
    }

    // MARK: Two films

    @Test("Every sheet of a spilling job is captioned")
    func testFilmsAreEachCaptioned() {
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
        #expect(identifications.allSatisfy { $0 == .perImage })

        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications, plan: plan)
        #expect(Set(burns.keys) == ["/0.dcm#0", "/1.dcm#0", "/2.dcm#0", "/3.dcm#0"])
    }

    // MARK: Off

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
            for: items, texts: texts, identifications: identifications, plan: plan).isEmpty)
    }

    @Test("A file whose header could not be read is not captioned with someone else's name")
    func testUnreadableFileIsSkipped() {
        let viewModel = makeViewModel(items: fourFrames)
        viewModel.layoutMode = .explicit
        viewModel.layoutOption = .layout2x2
        let items = viewModel.selection.items
        var texts = Dictionary(uniqueKeysWithValues: items.map { ($0.filePath, text("1.2.3")) })
        texts["/2.dcm"] = nil
        let plan = viewModel.request.plan(forImageCount: items.count)

        let identifications = viewModel.filmIdentifications(
            for: items, texts: texts, plan: plan)
        let burns = viewModel.identificationBurns(
            for: items, texts: texts, identifications: identifications, plan: plan)

        #expect(burns["/2.dcm#0"] == nil)
        #expect(burns.count == 3)
    }
}
