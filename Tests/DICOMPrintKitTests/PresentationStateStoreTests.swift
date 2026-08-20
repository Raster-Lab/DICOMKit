//
// PresentationStateStoreTests.swift
// DICOMPrintKit
//
// Covers the arrangement itself — one shared series per study, saved views
// grouped by label — as well as the round trip through disk. The grouping tests
// matter most: the label is what ties several objects into one saved view, so
// its behaviour under duplication, re-save and deletion is the design.
//

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class PresentationStateStoreTests: XCTestCase {

    private var root: URL!
    private var store: PresentationStateStore!

    private let studyUID = "1.2.3.4.5"
    private let seriesUID = "1.2.3.4.5.6"
    private let imageSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PresentationStateStoreTests-\(UUID().uuidString)")
        store = PresentationStateStore(root: root)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    private func context() -> PresentationStatePatientContext {
        PresentationStatePatientContext(
            patientName: "DOE^JANE",
            patientID: "12345",
            studyInstanceUID: studyUID,
            studyDate: "20260101")
    }

    private func image(
        _ sopInstanceUID: String,
        windowCenter: Double = 40,
        windowWidth: Double = 400,
        zoom: Double = 1
    ) -> PresentationStateStore.ImageToSave {
        let presentation = ViewerPresentation(
            zoom: zoom, viewportWidth: 800, viewportHeight: 600)
        let display = ViewerPresentationStateBridge.capture(
            presentation: presentation,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            imageWidth: 512,
            imageHeight: 512)
        return PresentationStateStore.ImageToSave(
            sopClassUID: imageSOPClass,
            sopInstanceUID: sopInstanceUID,
            seriesInstanceUID: seriesUID,
            display: display)
    }

    @discardableResult
    private func save(
        _ images: [PresentationStateStore.ImageToSave],
        label: String,
        created: Date = Date()
    ) throws -> SavedView? {
        try store.save(
            images: images, label: label, patient: context(), created: created)
    }

    // MARK: - Saving and loading

    func test_save_thenLoad_returnsTheView() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")

        let views = store.views(forStudy: studyUID)
        XCTAssertEqual(views.count, 1)
        XCTAssertEqual(views.first?.label, "Lung window")
        XCTAssertEqual(views.first?.states.count, 1)
    }

    func test_save_writesOneObjectPerImage() throws {
        try save(
            [image("1.2.3.4.5.6.1"), image("1.2.3.4.5.6.2"), image("1.2.3.4.5.6.3")],
            label: "Lung window")

        let views = store.views(forStudy: studyUID)
        XCTAssertEqual(views.count, 1, "one label is one saved view")
        XCTAssertEqual(views.first?.states.count, 3, "one object per image")
    }

    func test_save_withNoImages_writesNothing() throws {
        let result = try save([], label: "Empty")

        XCTAssertNil(result)
        XCTAssertTrue(store.views(forStudy: studyUID).isEmpty)
    }

    func test_save_roundTripsWindowThroughDisk() throws {
        try save([image("1.2.3.4.5.6.1", windowCenter: -600, windowWidth: 1500)],
                 label: "Lung window")

        let state = store.views(forStudy: studyUID).first?.states.first?.state
        guard case .window(let center, let width, _, _)? = state?.voiLUT else {
            return XCTFail("expected a window VOI LUT after reloading")
        }
        XCTAssertEqual(center, -600)
        XCTAssertEqual(width, 1500)
    }

    // MARK: - The shared series

    /// The defining property of this arrangement: however many views a study
    /// accumulates, they all live in one series.
    func test_allViewsOfAStudyShareOneSeries() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")
        try save([image("1.2.3.4.5.6.1")], label: "Bone window")
        try save([image("1.2.3.4.5.6.2")], label: "Soft tissue")

        let seriesUIDs = Set(store.views(forStudy: studyUID)
            .flatMap(\.states)
            .compactMap { stored -> String? in
                try? DICOMFile.read(from: stored.url).dataSet.string(for: .seriesInstanceUID)
            })

        XCTAssertEqual(seriesUIDs.count, 1, "a study has exactly one PR series")
    }

    func test_savedObjectsCarryPRModality() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")

        let stored = try XCTUnwrap(store.views(forStudy: studyUID).first?.states.first)
        let file = try DICOMFile.read(from: stored.url)
        XCTAssertEqual(file.dataSet.string(for: .modality), "PR")
        XCTAssertEqual(file.dataSet.string(for: .studyInstanceUID), studyUID)
    }

    // MARK: - Several views of one image

    /// The requirement that makes a picker worth having: one image, more than
    /// one saved way of looking at it.
    func test_oneImageCanCarrySeveralViews() throws {
        try save([image("1.2.3.4.5.6.1", windowCenter: -600, windowWidth: 1500)],
                 label: "Lung window")
        try save([image("1.2.3.4.5.6.1", windowCenter: 300, windowWidth: 1500)],
                 label: "Bone window")

        let views = store.views(forStudy: studyUID, image: "1.2.3.4.5.6.1")
        XCTAssertEqual(Set(views.map(\.label)), ["Lung window", "Bone window"])
    }

    /// A view saved over other images has nothing to offer this one, so the
    /// picker must not list it.
    func test_views_forImage_excludesViewsThatDoNotCoverIt() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")
        try save([image("1.2.3.4.5.6.2")], label: "Soft tissue")

        let views = store.views(forStudy: studyUID, image: "1.2.3.4.5.6.1")
        XCTAssertEqual(views.map(\.label), ["Lung window"])
    }

    /// Presentation Label is CS-valued, so the reader's wording is folded to
    /// uppercase on the way out. It has to come back as typed — the label is
    /// what groups a saved view, so a folded one no longer matches the view a
    /// delete or a re-save is looking for, and the picker shows shouting.
    func test_label_survivesMixedCaseAndPunctuation() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window (thin)")

        XCTAssertEqual(
            store.views(forStudy: studyUID).map(\.label), ["Lung window (thin)"])
    }

    func test_label_withMixedCase_stillMatchesForDeletion() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")
        try store.deleteView(label: "Lung window", studyInstanceUID: studyUID)

        XCTAssertTrue(store.views(forStudy: studyUID).isEmpty)
    }

    func test_savedView_findsTheStateForAGivenImage() throws {
        try save([image("1.2.3.4.5.6.1"), image("1.2.3.4.5.6.2")], label: "Lung window")

        let view = try XCTUnwrap(store.views(forStudy: studyUID).first)
        XCTAssertNotNil(view.state(forImage: "1.2.3.4.5.6.2"))
        XCTAssertNil(view.state(forImage: "1.2.3.4.5.6.99"))
    }

    // MARK: - Re-saving

    /// Saving again under the same name is the reader correcting the view. It
    /// must replace, or the picker fills with duplicates that cannot be told
    /// apart — the known cost of grouping by label.
    func test_saveUnderAnExistingLabel_replacesIt() throws {
        try save([image("1.2.3.4.5.6.1", windowCenter: 40, windowWidth: 400)],
                 label: "Lung window")
        try save([image("1.2.3.4.5.6.1", windowCenter: -600, windowWidth: 1500)],
                 label: "Lung window")

        let views = store.views(forStudy: studyUID)
        XCTAssertEqual(views.count, 1, "one entry, not two")

        guard case .window(let center, _, _, _)? = views.first?.states.first?.state.voiLUT else {
            return XCTFail("expected a window VOI LUT")
        }
        XCTAssertEqual(center, -600, "the newer save wins")
    }

    func test_reSaving_staysInTheSameSeries() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")
        let firstSeries = try seriesUIDOfStoredObjects()

        try save([image("1.2.3.4.5.6.1")], label: "Bone window")
        let afterSecond = try seriesUIDOfStoredObjects()

        XCTAssertEqual(firstSeries, afterSecond)
    }

    private func seriesUIDOfStoredObjects() throws -> Set<String> {
        Set(store.views(forStudy: studyUID)
            .flatMap(\.states)
            .compactMap { stored -> String? in
                try? DICOMFile.read(from: stored.url).dataSet.string(for: .seriesInstanceUID)
            })
    }

    // MARK: - Deleting

    func test_deleteView_removesOnlyThatView() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")
        try save([image("1.2.3.4.5.6.1")], label: "Bone window")

        try store.deleteView(label: "Lung window", studyInstanceUID: studyUID)

        XCTAssertEqual(store.views(forStudy: studyUID).map(\.label), ["Bone window"])
    }

    func test_deleteView_removesEveryObjectOfAMultiImageView() throws {
        try save([image("1.2.3.4.5.6.1"), image("1.2.3.4.5.6.2")], label: "Lung window")

        try store.deleteView(label: "Lung window", studyInstanceUID: studyUID)

        XCTAssertTrue(store.views(forStudy: studyUID).isEmpty)
    }

    func test_deleteAll_clearsTheStudy() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")
        try save([image("1.2.3.4.5.6.2")], label: "Bone window")

        try store.deleteAll(forStudy: studyUID)

        XCTAssertTrue(store.views(forStudy: studyUID).isEmpty)
    }

    // MARK: - Ordering and robustness

    func test_views_areReturnedNewestFirst() throws {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_000)

        try save([image("1.2.3.4.5.6.1")], label: "Older", created: older)
        try save([image("1.2.3.4.5.6.2")], label: "Newer", created: newer)

        XCTAssertEqual(store.views(forStudy: studyUID).map(\.label), ["Newer", "Older"])
    }

    func test_views_ofUnknownStudy_isEmpty() {
        XCTAssertTrue(store.views(forStudy: "9.9.9").isEmpty)
    }

    /// One unreadable object must not cost the reader their other saved views.
    func test_views_skipsUnreadableFiles() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")

        let junk = store.directory(forStudy: studyUID)
            .appendingPathComponent("not-a-dicom-file.dcm")
        try Data("garbage".utf8).write(to: junk)

        XCTAssertEqual(store.views(forStudy: studyUID).map(\.label), ["Lung window"])
    }
}

// MARK: - Drawn annotations

/// The sidecar exists so a saved view can carry what the reader drew without
/// distorting it through a vocabulary that has no arrow and no per-annotation
/// colour. These cover the round trip and the two ways a stale sidecar could
/// otherwise outlive the object it belongs to.
extension PresentationStateStoreTests {

    private func annotated(
        _ sopInstanceUID: String,
        annotations: [PrintOverlayAnnotation]
    ) -> PresentationStateStore.ImageToSave {
        let base = image(sopInstanceUID)
        return PresentationStateStore.ImageToSave(
            sopClassUID: base.sopClassUID,
            sopInstanceUID: base.sopInstanceUID,
            seriesInstanceUID: base.seriesInstanceUID,
            display: base.display,
            annotations: annotations)
    }

    private var arrow: PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.3),
            end: PrintOverlayPoint(x: 0.6, y: 0.7),
            color: .cyan)
    }

    private var label: PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.1, y: 0.15),
            text: "Nodule",
            scale: 0.06)
    }

    func test_annotations_surviveTheRoundTrip() throws {
        try save([annotated("1.2.3.4.5.6.1", annotations: [arrow, label])],
                 label: "Marked up")

        let restored = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first?.annotations)

        XCTAssertEqual(restored.count, 2)

        // Every field the print path draws from, not just the geometry: a
        // round trip that lost the colour or the type size would still look
        // like a success from a count alone.
        let restoredArrow = try XCTUnwrap(restored.first { $0.kind == .arrow })
        XCTAssertEqual(restoredArrow.start.x, 0.2, accuracy: 1e-9)
        XCTAssertEqual(restoredArrow.start.y, 0.3, accuracy: 1e-9)
        XCTAssertEqual(restoredArrow.end.x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(restoredArrow.end.y, 0.7, accuracy: 1e-9)
        XCTAssertEqual(restoredArrow.color, .cyan)

        let restoredText = try XCTUnwrap(restored.first { $0.kind == .text })
        XCTAssertEqual(restoredText.text, "Nodule")
        XCTAssertEqual(restoredText.scale, 0.06, accuracy: 1e-9)
    }

    func test_viewWithoutAnnotations_loadsEmptyAndWritesNoSidecar() throws {
        try save([image("1.2.3.4.5.6.1")], label: "Lung window")

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertTrue(state.annotations.isEmpty)

        // The ordinary saved view should leave no file behind at all.
        let sidecar = state.url
            .deletingPathExtension().appendingPathExtension("annotations.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.path))
    }

    func test_blankAnnotations_areNotSaved() throws {
        // A text annotation is empty for as long as it takes to type into it;
        // one left empty is not a drawing and must not come back as one.
        let empty = PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5), text: "   ")
        try save([annotated("1.2.3.4.5.6.1", annotations: [empty])],
                 label: "Nothing drawn")

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertTrue(state.annotations.isEmpty)
    }

    func test_resavingWithoutAnnotations_dropsTheOldOnes() throws {
        // The regression this guards: a reader deletes their arrow and saves
        // the view again. An orphaned sidecar would put the arrow back.
        try save([annotated("1.2.3.4.5.6.1", annotations: [arrow])],
                 label: "Marked up")
        try save([image("1.2.3.4.5.6.1")], label: "Marked up")

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        XCTAssertTrue(state.annotations.isEmpty)
    }

    func test_deletingAView_removesItsSidecar() throws {
        try save([annotated("1.2.3.4.5.6.1", annotations: [arrow])],
                 label: "Marked up")
        let sidecar = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first?.url)
            .deletingPathExtension().appendingPathExtension("annotations.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecar.path))

        try store.deleteView(label: "Marked up", studyInstanceUID: studyUID)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.path))
    }

    func test_annotationsAreKeptPerView() throws {
        // Two views of the same image, drawn on differently: applying one must
        // not hand back the other's drawings.
        try save([annotated("1.2.3.4.5.6.1", annotations: [arrow])],
                 label: "With arrow")
        try save([annotated("1.2.3.4.5.6.1", annotations: [label, arrow])],
                 label: "With both")

        let views = store.views(forStudy: studyUID)
        let withArrow = try XCTUnwrap(views.first { $0.label == "With arrow" })
        let withBoth = try XCTUnwrap(views.first { $0.label == "With both" })

        XCTAssertEqual(withArrow.states.first?.annotations.count, 1)
        XCTAssertEqual(withBoth.states.first?.annotations.count, 2)
    }
}
