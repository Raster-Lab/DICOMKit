//
// PresentationStateFramePaletteTests.swift
// DICOMPrintKit
//
// The two things a sidecar carries that GSPS cannot: which frame each drawing
// belongs to, and the pseudo-colour palette the view was read through. These
// cover the round trip for both, and the compatibility path — sidecars written
// before either existed are a bare array of annotations, and must keep reading.
//

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class PresentationStateFramePaletteTests: XCTestCase {

    private var root: URL!
    private var store: PresentationStateStore!

    private let studyUID = "1.2.3.4.5"
    private let seriesUID = "1.2.3.4.5.6"
    private let imageSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PresentationStateFramePaletteTests-\(UUID().uuidString)")
        store = PresentationStateStore(root: root)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private var arrow: PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.3),
            end: PrintOverlayPoint(x: 0.6, y: 0.7),
            color: .cyan)
    }

    private var text: PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.1, y: 0.15),
            text: "Nodule",
            scale: 0.06)
    }

    private func image(
        _ sopInstanceUID: String,
        annotationsByFrame: [Int: [PrintOverlayAnnotation]] = [:],
        palette: PseudoColorPalette? = nil
    ) -> PresentationStateStore.ImageToSave {
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 2, viewportWidth: 800, viewportHeight: 600),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        return PresentationStateStore.ImageToSave(
            sopClassUID: imageSOPClass,
            sopInstanceUID: sopInstanceUID,
            seriesInstanceUID: seriesUID,
            display: display,
            annotationsByFrame: annotationsByFrame,
            palette: palette)
    }

    private func context() -> PresentationStatePatientContext {
        PresentationStatePatientContext(
            patientName: "DOE^JANE",
            patientID: "12345",
            studyInstanceUID: studyUID,
            studyDate: "20260101")
    }

    // MARK: - Frames

    func test_framedAnnotations_surviveTheRoundTrip() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1",
                           annotationsByFrame: [0: [arrow], 2: [text]])],
            label: "Marked frames", patient: context())

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)

        XCTAssertEqual(state.annotations(forFrame: 0).count, 1)
        XCTAssertEqual(state.annotations(forFrame: 0).first?.kind, .arrow)
        XCTAssertEqual(state.annotations(forFrame: 2).count, 1)
        XCTAssertEqual(state.annotations(forFrame: 2).first?.text, "Nodule")
        XCTAssertTrue(state.annotations(forFrame: 1).isEmpty,
                      "a frame nothing was drawn on says nothing")
        // The flattened list still speaks for the whole image.
        XCTAssertEqual(state.annotations.count, 2)
    }

    func test_blankFrames_writeNothing() throws {
        let blank = PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5), text: "   ")
        try store.save(
            images: [image("1.2.3.4.5.6.1",
                           annotationsByFrame: [0: [arrow], 3: [blank]])],
            label: "One real drawing", patient: context())

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertEqual(state.annotationsByFrame.keys.sorted(), [0],
                       "an empty text box on frame 3 is not a drawing")
    }

    // MARK: - Palette

    func test_palette_survivesTheRoundTrip() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .hotIron)],
            label: "Hot iron", patient: context())

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertEqual(state.palette, .hotIron)
    }

    func test_paletteAlone_stillWritesASidecar() throws {
        // A coloured view with nothing drawn used to be the "no sidecar" case;
        // the palette has nowhere else to live, so the file must exist now.
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .pet)],
            label: "Coloured only", patient: context())

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertEqual(state.palette, .pet)
    }

    func test_viewWithoutColourOrDrawings_writesNoSidecar() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1")],
            label: "Plain", patient: context())

        let url = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first?.url)
        let sidecar = url
            .deletingPathExtension().appendingPathExtension("annotations.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.path))
    }

    // MARK: - Sidecars written before frames and palettes existed

    func test_legacyFlatSidecar_readsAsFrameZero() throws {
        try store.save(
            images: [image("1.2.3.4.5.6.1")],
            label: "Old view", patient: context())
        let url = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first?.url)

        // What the sidecar used to be: a bare JSON array of annotations.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode([arrow]).write(
            to: url.deletingPathExtension().appendingPathExtension("annotations.json"))

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertNil(state.palette)
        XCTAssertEqual(state.annotations(forFrame: 0).count, 1)
        XCTAssertEqual(state.annotations(forFrame: 0).first?.kind, .arrow)
    }

    func test_resavingPlain_removesTheColouredSidecar() throws {
        // The palette's version of the orphaned-arrow regression: take the
        // colour off, save again, and the old sidecar must not put it back.
        try store.save(
            images: [image("1.2.3.4.5.6.1", palette: .rainbow)],
            label: "Was coloured", patient: context())
        try store.save(
            images: [image("1.2.3.4.5.6.1")],
            label: "Was coloured", patient: context())

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertNil(state.palette)
    }
}
