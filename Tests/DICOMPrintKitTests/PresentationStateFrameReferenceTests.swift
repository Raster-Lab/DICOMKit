//
// PresentationStateFrameReferenceTests.swift
// DICOMPrintKit
//
// Referenced Frame Number (0008,1160) in the written object — the half of the
// frame story that leaves the machine.
//
// `PresentationStateFramePaletteTests` covers the sidecar round trip: our own
// restore putting frame 3's arrow back on frame 3. These cover the DICOM
// object instead, because the sidecar is private and a study that is exported
// travels as DICOM alone. Without a frame number inside the Graphic Annotation
// Sequence, a conforming viewer paints every frame's drawings onto all of
// them.
//
// Two properties are asserted throughout:
//
//   * Frames are named whenever the image has more than one, whatever the
//     modality. Nothing here branches on SOP class or modality — the frame
//     count is the whole test, and the cases below span CT, US, XA and MR to
//     prove the behaviour does not depend on which.
//   * A single-frame image is untouched. It writes no frame number at all,
//     exactly as before frames were stated, so an existing single-frame
//     workflow produces the same bytes it always has.
//

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class PresentationStateFrameReferenceTests: XCTestCase {

    private var root: URL!
    private var store: PresentationStateStore!

    private let studyUID = "1.2.3.4.5"
    private let seriesUID = "1.2.3.4.5.6"

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PSFrameReferenceTests-\(UUID().uuidString)")
        store = PresentationStateStore(root: root)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    /// The multi-frame storage classes this has to work for, and the one
    /// single-frame class that must not change. The point of the list is that
    /// the code under test never looks at it.
    private enum SOPClass {
        static let ctImage = "1.2.840.10008.5.1.4.1.1.2"
        static let ultrasoundMultiFrame = "1.2.840.10008.5.1.4.1.1.3.1"
        static let xaImage = "1.2.840.10008.5.1.4.1.1.12.1"
        static let enhancedMR = "1.2.840.10008.5.1.4.1.1.4.1"
    }

    private func arrow(_ x: Double) -> PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: x, y: 0.3),
            end: PrintOverlayPoint(x: x + 0.2, y: 0.7),
            color: .cyan)
    }

    private func text(_ words: String) -> PrintOverlayAnnotation {
        PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.1, y: 0.15),
            text: words,
            scale: 0.06)
    }

    private func image(
        sopClassUID: String,
        sopInstanceUID: String = "1.2.3.4.5.6.1",
        annotationsByFrame: [Int: [PrintOverlayAnnotation]],
        numberOfFrames: Int,
        palette: PseudoColorPalette? = nil
    ) -> PresentationStateStore.ImageToSave {
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 2, viewportWidth: 800, viewportHeight: 600),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        return PresentationStateStore.ImageToSave(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            seriesInstanceUID: seriesUID,
            display: display,
            annotationsByFrame: annotationsByFrame,
            palette: palette,
            imageWidth: 512,
            imageHeight: 512,
            bitsStored: 12,
            numberOfFrames: numberOfFrames)
    }

    private func context() -> PresentationStatePatientContext {
        PresentationStatePatientContext(
            patientName: "DOE^JANE",
            patientID: "12345",
            studyInstanceUID: studyUID,
            studyDate: "20260101")
    }

    // MARK: - Reading the written object back

    /// The saved view's data set, re-read from disk as any other viewer would.
    private func savedDataSet(label: String) throws -> DataSet {
        let state = try XCTUnwrap(
            store.views(forStudy: studyUID)
                .first { $0.label == label }?.states.first)
        return try DICOMFile.read(from: state.url).dataSet
    }

    /// Every Graphic Annotation item's frame numbers, in the order written.
    /// `nil` for an item that names no frame.
    private func annotationFrameNumbers(in dataSet: DataSet) -> [[Int]?] {
        (dataSet.sequence(for: .graphicAnnotationSequence) ?? []).map { item in
            guard let refs = item[.referencedImageSequence]?.sequenceItems,
                  let first = refs.first else { return nil }
            return first[.referencedFrameNumber]?
                .integerStringValues?.map { $0.value }
        }
    }

    /// How many drawable objects an item carries, graphics and text together.
    private func objectCount(in item: SequenceItem) -> Int {
        (item[.graphicObjectSequence]?.sequenceItems?.count ?? 0)
            + (item[.textObjectSequence]?.sequenceItems?.count ?? 0)
    }

    // MARK: - Multi-frame: frames are named

    func test_multiFrame_writesOneItemPerDrawnFrame_withOneBasedFrameNumbers() throws {
        try store.save(
            images: [image(sopClassUID: SOPClass.ultrasoundMultiFrame,
                           annotationsByFrame: [0: [arrow(0.2)],
                                                2: [text("Nodule")],
                                                7: [arrow(0.5)]],
                           numberOfFrames: 60)],
            label: "Cine marks", patient: context())

        let dataSet = try savedDataSet(label: "Cine marks")
        // DICOM counts frames from one; the store counts from zero.
        XCTAssertEqual(annotationFrameNumbers(in: dataSet), [[1], [3], [8]],
                       "each drawn frame gets its own item naming that frame")
    }

    func test_multiFrame_keepsEachFramesDrawingsInItsOwnItem() throws {
        try store.save(
            images: [image(sopClassUID: SOPClass.xaImage,
                           annotationsByFrame: [0: [arrow(0.1), arrow(0.2)],
                                                4: [text("Stenosis")]],
                           numberOfFrames: 30)],
            label: "Run", patient: context())

        let dataSet = try savedDataSet(label: "Run")
        let items = try XCTUnwrap(dataSet.sequence(for: .graphicAnnotationSequence))
        XCTAssertEqual(items.count, 2)
        // Frame 1's two arrows stay on frame 1; frame 5's text stays on frame 5.
        // Flattening is exactly the bug this prevents. An arrow is two
        // polylines — the shaft and the head — so two arrows are four objects.
        XCTAssertEqual(objectCount(in: items[0]), 4)
        XCTAssertEqual(objectCount(in: items[1]), 1)
    }

    func test_multiFrame_referencedSeries_namesNoFrame() throws {
        try store.save(
            images: [image(sopClassUID: SOPClass.enhancedMR,
                           annotationsByFrame: [3: [arrow(0.4)]],
                           numberOfFrames: 120)],
            label: "Whole-image view", patient: context())

        let dataSet = try savedDataSet(label: "Whole-image view")
        let series = try XCTUnwrap(
            dataSet.sequence(for: .referencedSeriesSequence)?.first)
        let refImage = try XCTUnwrap(
            series[.referencedImageSequence]?.sequenceItems?.first)
        // The window, the zoom and the palette are statements about the whole
        // image. Naming a frame here would narrow the view to one frame of a
        // cine the reader adjusted entirely.
        XCTAssertNil(refImage[.referencedFrameNumber],
                     "the state itself applies to the instance, not one frame")
    }

    /// The behaviour must come from the frame count alone. Same drawings, same
    /// assertions, four unrelated modalities.
    func test_frameNumbering_isTheSameForEveryModality() throws {
        let classes = [SOPClass.ctImage,
                       SOPClass.ultrasoundMultiFrame,
                       SOPClass.xaImage,
                       SOPClass.enhancedMR]

        for (index, sopClass) in classes.enumerated() {
            let label = "Modality \(index)"
            try store.save(
                images: [image(sopClassUID: sopClass,
                               sopInstanceUID: "1.2.3.4.5.6.\(index + 1)",
                               annotationsByFrame: [1: [arrow(0.3)],
                                                    5: [text("Finding")]],
                               numberOfFrames: 24)],
                label: label, patient: context())

            let dataSet = try savedDataSet(label: label)
            XCTAssertEqual(annotationFrameNumbers(in: dataSet), [[2], [6]],
                           "\(sopClass) must be framed like every other")
        }
    }

    func test_twoFrameImage_isAlreadyMultiFrame() throws {
        try store.save(
            images: [image(sopClassUID: SOPClass.ctImage,
                           annotationsByFrame: [1: [arrow(0.3)]],
                           numberOfFrames: 2)],
            label: "Just two", patient: context())

        let dataSet = try savedDataSet(label: "Just two")
        XCTAssertEqual(annotationFrameNumbers(in: dataSet), [[2]],
                       "the boundary is one frame, not some larger count")
    }

    func test_colouredMultiFrame_isFramedToo() throws {
        // The Pseudo-Color builder delegates to the grayscale one, so this
        // guards that the delegation keeps carrying the frames.
        try store.save(
            images: [image(sopClassUID: SOPClass.ultrasoundMultiFrame,
                           annotationsByFrame: [2: [arrow(0.3)]],
                           numberOfFrames: 40,
                           palette: .hotIron)],
            label: "Coloured cine", patient: context())

        let dataSet = try savedDataSet(label: "Coloured cine")
        XCTAssertEqual(dataSet.string(for: .sopClassUID),
                       PseudoColorPresentationStateBuilder.sopClassUID,
                       "a coloured view is still a Pseudo-Color object")
        XCTAssertEqual(annotationFrameNumbers(in: dataSet), [[3]])
    }

    // MARK: - Single frame: nothing changes

    func test_singleFrame_namesNoFrameAnywhere() throws {
        try store.save(
            images: [image(sopClassUID: SOPClass.ctImage,
                           annotationsByFrame: [0: [arrow(0.2), text("Mass")]],
                           numberOfFrames: 1)],
            label: "Plain slice", patient: context())

        let dataSet = try savedDataSet(label: "Plain slice")
        let items = try XCTUnwrap(dataSet.sequence(for: .graphicAnnotationSequence))
        XCTAssertEqual(items.count, 1, "one image, one item, as before")
        XCTAssertEqual(annotationFrameNumbers(in: dataSet), [nil],
                       "the sole frame of a single-frame image is the instance")
        // The arrow's two polylines plus the one text object.
        XCTAssertEqual(objectCount(in: items[0]), 3)
    }

    /// The default is what every existing caller gets, and it must be the
    /// single-frame form — this is what keeps normal studies untouched.
    func test_unstatedFrameCount_writesTheSingleFrameForm() throws {
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 1, viewportWidth: 800, viewportHeight: 600),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        // No `numberOfFrames:` — the call an existing caller already writes.
        let legacy = PresentationStateStore.ImageToSave(
            sopClassUID: SOPClass.ctImage,
            sopInstanceUID: "1.2.3.4.5.6.9",
            seriesInstanceUID: seriesUID,
            display: display,
            annotations: [arrow(0.2)],
            imageWidth: 512,
            imageHeight: 512)

        try store.save(images: [legacy], label: "Legacy", patient: context())

        let dataSet = try savedDataSet(label: "Legacy")
        XCTAssertEqual(annotationFrameNumbers(in: dataSet), [nil])
    }

    func test_singleFrameWithDrawingsOnHigherFrames_stillFlattens() throws {
        // A frame count of one with drawings keyed above zero is a
        // contradiction the store should not propagate into frame numbers —
        // the count is the authority.
        try store.save(
            images: [image(sopClassUID: SOPClass.ctImage,
                           annotationsByFrame: [0: [arrow(0.2)], 3: [text("Odd")]],
                           numberOfFrames: 1)],
            label: "Contradiction", patient: context())

        let dataSet = try savedDataSet(label: "Contradiction")
        XCTAssertEqual(annotationFrameNumbers(in: dataSet), [nil])
        let items = try XCTUnwrap(dataSet.sequence(for: .graphicAnnotationSequence))
        XCTAssertEqual(objectCount(in: items[0]), 3,
                       "both drawings still travel: an arrow's two polylines "
                       + "and the text")
    }

    // MARK: - The sidecar is unaffected

    func test_framedWrite_leavesTheSidecarRoundTripIntact() throws {
        try store.save(
            images: [image(sopClassUID: SOPClass.ultrasoundMultiFrame,
                           annotationsByFrame: [0: [arrow(0.2)], 2: [text("Nodule")]],
                           numberOfFrames: 60)],
            label: "Both halves", patient: context())

        let state = try XCTUnwrap(
            store.views(forStudy: studyUID).first?.states.first)
        // Our own restore still reads the sidecar, unchanged by any of this.
        XCTAssertEqual(state.annotations(forFrame: 0).count, 1)
        XCTAssertEqual(state.annotations(forFrame: 2).first?.text, "Nodule")
        XCTAssertTrue(state.annotations(forFrame: 1).isEmpty)
    }
}
