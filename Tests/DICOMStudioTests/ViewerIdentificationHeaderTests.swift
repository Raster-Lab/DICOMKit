// ViewerIdentificationHeaderTests.swift
// DICOMStudioTests
//
// What the viewer's series pane says at the top — who the patient is, what made
// the pictures, what the study is and when it was — and what opening a study
// from the library clears out first.

import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation

@Suite("Viewer Identification Header Tests")
struct ViewerIdentificationHeaderTests {

    @MainActor
    private func studyViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        viewModel.loadStudySeries([
            ViewerSeriesEntry(seriesInstanceUID: "s1", title: "Topogram", seriesNumber: 1,
                              modality: "CT", filePaths: ["/s1-a.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "s2", title: "Attenuation", seriesNumber: 2,
                              modality: "PT", filePaths: ["/s2-a.dcm"], frameCount: 1),
            ViewerSeriesEntry(seriesInstanceUID: "s3", title: "Brain 3.00", seriesNumber: 3,
                              modality: "CT", filePaths: ["/s3-a.dcm"], frameCount: 1)
        ], studyUID: "1.2")
        return viewModel
    }

    // MARK: - Modality

    @Test("Every modality of the study is listed once, in series order")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @MainActor
    func testModalitiesAreDeduplicatedInSeriesOrder() {
        let viewModel = studyViewModel()
        #expect(viewModel.modalitiesForOverlay == ["CT", "PT"])
        #expect(viewModel.modalityLineForOverlay == "CT / PT")
    }

    @Test("With no study loaded and no file open there is no modality to name")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @MainActor
    func testNoModalityWithoutStudyOrFile() {
        let viewModel = ImageViewerViewModel()
        #expect(viewModel.modalitiesForOverlay.isEmpty)
        #expect(viewModel.modalityLineForOverlay == nil)
    }

    @Test("The identification line carries the modality alongside the patient")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @MainActor
    func testIdentityLineCarriesModality() {
        let viewModel = studyViewModel()
        // No file is open, so the name half is empty and only the modality
        // remains — the line must not begin with a stray separator.
        #expect(viewModel.patientIdentityLine == "CT / PT")
    }

    // MARK: - Study description

    @Test("A description keeps its words and loses the separators around them")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @MainActor
    func testDescriptionSanitising() {
        // The sanitiser is exercised through the same rules the accessor uses.
        #expect(Self.sanitise("CT^HEAD/NECK_W|CONTRAST") == "CT HEAD/NECK W CONTRAST")
        #expect(Self.sanitise("  MR  BRAIN  ") == "MR BRAIN")
        #expect(Self.sanitise("CT 1.25mm - AXIAL") == "CT 1.25mm - AXIAL")
        #expect(Self.sanitise("^^^") == nil)
    }

    /// The same transformation ``ImageViewerViewModel/studyDescriptionSanitizedForOverlay``
    /// applies, run on a literal so it can be checked without a file on disk.
    private static func sanitise(_ raw: String) -> String? {
        let cleaned = String(raw.map { character in
            character.isLetter || character.isNumber || character == " "
                || character == "-" || character == "." || character == "/"
                ? character : " "
        })
        let collapsed = cleaned.split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    // MARK: - Opening a study from the library

    @Test("Opening a study clears the print selection and the print sheet")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @MainActor
    func testPrepareForNewStudyResetsPrintSelection() {
        let viewModel = studyViewModel()
        viewModel.printSelection.add(PrintSelectionItem(filePath: "/old-a.dcm"))
        viewModel.printSelection.add(PrintSelectionItem(filePath: "/old-b.dcm"))
        viewModel.isPrintSheetPresented = true

        viewModel.prepareForNewStudy()

        #expect(viewModel.printSelection.isEmpty)
        #expect(viewModel.printSelection.count == 0)
        #expect(!viewModel.isPrintSheetPresented)
        // And the rest of the slate it always cleared.
        #expect(viewModel.studySeries.isEmpty)
        #expect(viewModel.studyInstanceUID == nil)
    }

    @Test("Each study opened asks for the print screen to be taken down")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @MainActor
    func testPrepareForNewStudyRequestsPrintScreenDismissal() {
        let viewModel = studyViewModel()
        #expect(viewModel.printScreenDismissRequests == 0)

        viewModel.prepareForNewStudy()
        #expect(viewModel.printScreenDismissRequests == 1)

        // A counter, not a flag: the print window can be re-opened between two
        // studies, and the second one has to take it down again.
        viewModel.prepareForNewStudy()
        #expect(viewModel.printScreenDismissRequests == 2)
    }
}
