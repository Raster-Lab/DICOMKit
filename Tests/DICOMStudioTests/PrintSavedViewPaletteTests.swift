// PrintSavedViewPaletteTests.swift
// DICOMStudioTests
//
// A saved view applied to a coloured film cell must not grey the cell out.
//
// The GSPS vocabulary has no way to say "coloured" (see the bridge — palettes
// are pixels, not arrangement, and Print Management cannot reference one), so
// a restored state is *silent* about colour rather than against it. Silence
// must leave the mark's palette standing; treating it as "no palette" is the
// bug these tests pin.

import Testing
import Foundation
import CoreGraphics
@testable import DICOMStudio
import DICOMPrintKit
import DICOMKit
import DICOMCore

@MainActor
@Suite("Print Saved View Palette Tests")
struct PrintSavedViewPaletteTests {

    private static let studyUID = "1.2.3.4.5"
    private static let seriesUID = "1.2.3.4.5.6"
    private static let imageUID = "1.2.3.4.5.6.7"

    private func makeStore() -> (PresentationStateStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintSavedViewPaletteTests-\(UUID().uuidString)")
        return (PresentationStateStore(root: root), root)
    }

    private func saveView(
        label: String,
        palette: PseudoColorPalette? = nil,
        in store: PresentationStateStore
    ) throws {
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 2, viewportWidth: 800, viewportHeight: 600),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        try store.save(
            images: [.init(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: Self.imageUID,
                seriesInstanceUID: Self.seriesUID,
                display: display,
                palette: palette)],
            label: label,
            patient: PresentationStatePatientContext(studyInstanceUID: Self.studyUID))
    }

    @Test("Applying a saved view keeps the cell's palette")
    func testPaletteSurvivesASavedView() async throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try saveView(label: "Lung window", in: store)

        let selection = PrintSelectionModel()
        var presentation = ViewerPresentation(
            zoom: 1, viewportWidth: 400, viewportHeight: 400)
        presentation.palette = .hotIron
        let mark = PrintSelectionItem(
            filePath: "/pet.dcm", sopInstanceUID: Self.imageUID,
            presentation: presentation)
        _ = selection.add(mark)

        let viewModel = PrintViewModel(selection: selection)
        viewModel.presentationStateStore = store
        viewModel.presentationStateStudyUID = Self.studyUID

        let applied = await viewModel.applySavedView(
            label: "Lung window", toItemID: mark.id,
            cellSize: CGSize(width: 400, height: 400))
        #expect(applied)

        let updated = try #require(selection.items.first { $0.id == mark.id })
        #expect(updated.presentation?.palette == .hotIron,
                "the view said nothing about colour, so the colour must stand")
        // And the rest of the view still landed.
        #expect(updated.windowCenter == 40)
        #expect(updated.presentation?.zoom ?? 0 > 1)
    }

    @Test("Applying a saved view to a grey cell leaves it grey")
    func testGreyCellStaysGrey() async throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try saveView(label: "Lung window", in: store)

        let selection = PrintSelectionModel()
        let mark = PrintSelectionItem(
            filePath: "/ct.dcm", sopInstanceUID: Self.imageUID)
        _ = selection.add(mark)

        let viewModel = PrintViewModel(selection: selection)
        viewModel.presentationStateStore = store
        viewModel.presentationStateStudyUID = Self.studyUID

        let applied = await viewModel.applySavedView(
            label: "Lung window", toItemID: mark.id,
            cellSize: CGSize(width: 400, height: 400))
        #expect(applied)

        let updated = try #require(selection.items.first { $0.id == mark.id })
        #expect(updated.presentation?.palette == nil)
    }

    @Test("A view that recorded a palette colours the cell")
    func testRecordedPaletteWins() async throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        // The sidecar can say "coloured" even though the GSPS cannot, and a
        // view that does is no longer silent: it names the colour the reading
        // was made through, and the cell takes it — over whatever it had.
        try saveView(label: "Hot iron", palette: .hotIron, in: store)

        let selection = PrintSelectionModel()
        var presentation = ViewerPresentation(
            zoom: 1, viewportWidth: 400, viewportHeight: 400)
        presentation.palette = .viridis
        let mark = PrintSelectionItem(
            filePath: "/pet.dcm", sopInstanceUID: Self.imageUID,
            presentation: presentation)
        _ = selection.add(mark)

        let viewModel = PrintViewModel(selection: selection)
        viewModel.presentationStateStore = store
        viewModel.presentationStateStudyUID = Self.studyUID

        let applied = await viewModel.applySavedView(
            label: "Hot iron", toItemID: mark.id,
            cellSize: CGSize(width: 400, height: 400))
        #expect(applied)

        let updated = try #require(selection.items.first { $0.id == mark.id })
        #expect(updated.presentation?.palette == .hotIron)
    }
}
