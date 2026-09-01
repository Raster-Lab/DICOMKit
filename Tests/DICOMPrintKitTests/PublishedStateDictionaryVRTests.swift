//
// PublishedStateDictionaryVRTests.swift
// DICOMPrintKit
//
// The viewer's "save view" and the print screen both publish through
// `PresentationStateStore`, and what they write has to satisfy a validator that
// has never seen this library. It did not: every presentation state carried
// Image Rotation (0070,0042) as IS, so `dcmpschk` rejected the object at the
// first attribute it looked at —
//
//     Error: Unexpected Value Representation.
//        Affected VR       : [IS], should be [US] according to data dictionary.
//        Affected attribute: (0070,0042) ImageRotation
//
// — and six more attributes behind it were wrong the same way. None of it was
// visible from inside: the parser read back the same wrong forms the builder
// wrote, so every round-trip test passed.
//
// These tests read published files back off disk and check every element
// against DICOMKit's own `DataElementDictionary`. That is the same authority
// the external validator uses, so agreeing with it here means agreeing with it
// there.
//

import XCTest
import DICOMCore
import DICOMKit
import DICOMDictionary
@testable import DICOMPrintKit

final class PublishedStateDictionaryVRTests: XCTestCase {

    private var root: URL!
    private var store: PresentationStateStore!
    private var published: [URL] = []

    private let studyUID = "1.2.3.4.5"
    private let seriesUID = "1.2.3.4.5.6"
    private let imageSOPClass = "1.2.840.10008.5.1.4.1.1.2"

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PSStore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = PresentationStateStore(root: root)
    }

    override func tearDownWithError() throws {
        for url in published where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        published = []
        if FileManager.default.fileExists(atPath: root.path) {
            try? FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    // MARK: - The check itself

    /// Every element in a data set, nested sequences included, whose VR
    /// disagrees with the standard data dictionary.
    ///
    /// Tags carrying more than one legal VR are skipped: LUT Data and the
    /// palette descriptors are `US or SS` keyed to Pixel Representation, and
    /// Pixel Data is `OB or OW` keyed to the transfer syntax. The dictionary
    /// resource flattens those to a single VR, so checking them here would
    /// report a conformant file as broken.
    private static let contextDependentVRTags: Set<Tag> = [
        Tag(group: 0x7FE0, element: 0x0010),   // Pixel Data — OB or OW
        Tag(group: 0x0028, element: 0x3006),   // LUT Data — US or OW
        Tag(group: 0x0028, element: 0x1101),   // Red Palette Descriptor — US or SS
        Tag(group: 0x0028, element: 0x1102),   // Green Palette Descriptor
        Tag(group: 0x0028, element: 0x1103),   // Blue Palette Descriptor
        Tag(group: 0x0028, element: 0x1201),   // Red Palette Data — US or OW
        Tag(group: 0x0028, element: 0x1202),   // Green Palette Data
        Tag(group: 0x0028, element: 0x1203)    // Blue Palette Data
    ]

    private func vrOffenders(in elements: [DataElement], path: String = "") -> [String] {
        var offenders: [String] = []
        for element in elements {
            // Group lengths and private tags are not in the dictionary.
            guard element.tag.element != 0x0000, !element.tag.isPrivate,
                  !Self.contextDependentVRTags.contains(element.tag),
                  let entry = DataElementDictionary.lookup(tag: element.tag)
            else { continue }

            if element.vr == .SQ {
                for (index, item) in (element.sequenceItems ?? []).enumerated() {
                    offenders += vrOffenders(
                        in: Array(item.elements.values),
                        path: "\(path)\(entry.keyword)[\(index)]/")
                }
                continue
            }

            if !entry.vr.contains(element.vr) {
                let expected = entry.vr.map(String.init(describing:)).joined(separator: " or ")
                offenders.append(
                    "\(path)\(entry.keyword) \(element.tag) is \(element.vr), should be \(expected)")
            }
        }
        return offenders
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
        rotation: Int = 0,
        annotations: [PrintOverlayAnnotation] = [],
        palette: PseudoColorPalette? = nil
    ) -> PresentationStateStore.ImageToSave {
        let presentation = ViewerPresentation(
            zoom: 1.6,
            viewportWidth: 800, viewportHeight: 600,
            rotationDegrees: Double(rotation))
        let display = ViewerPresentationStateBridge.capture(
            presentation: presentation,
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)
        return PresentationStateStore.ImageToSave(
            sopClassUID: imageSOPClass,
            sopInstanceUID: sopInstanceUID,
            seriesInstanceUID: seriesUID,
            display: display,
            annotations: annotations,
            palette: palette,
            imageWidth: 512,
            imageHeight: 512,
            bitsStored: 12)
    }

    private func studyFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PublishedStudy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        published.append(url)
        return url
    }

    private func publish(
        _ images: [PresentationStateStore.ImageToSave],
        label: String
    ) throws -> [URL] {
        _ = try store.save(
            images: images, label: label, patient: context(), created: Date())
        let series = try store.publish(
            label: label, studyInstanceUID: studyUID, into: try studyFolder())
        return (series?.instances ?? []).map(\.url)
    }

    // MARK: - Tests

    /// A plain saved view: window, zoom and rotation, no drawings.
    func test_publishedState_usesDictionaryVRsThroughout() throws {
        let urls = try publish([image("1.2.3.4.5.6.1", rotation: 90)], label: "Lung window")
        XCTAssertFalse(urls.isEmpty, "the view published at least one object")

        for url in urls {
            let file = try DICOMFile.read(from: url)
            XCTAssertEqual(
                vrOffenders(in: Array(file.dataSet.allElements)), [],
                "VRs disagreeing with the data dictionary in \(url.lastPathComponent)")
        }
    }

    /// The annotated case, which is where the FL-versus-DS coordinate
    /// attributes live: Graphic Data, the bounding box corners, the anchor.
    func test_publishedAnnotatedState_usesDictionaryVRsThroughout() throws {
        let annotations = [
            PrintOverlayAnnotation(
                kind: .text,
                start: PrintOverlayPoint(x: 0.25, y: 0.5),
                text: "Nodule", scale: 0.04, color: .yellow),
            PrintOverlayAnnotation(
                kind: .arrow,
                start: PrintOverlayPoint(x: 0.1, y: 0.1),
                end: PrintOverlayPoint(x: 0.9, y: 0.1),
                scale: 0.04, color: .yellow)
        ]
        let urls = try publish(
            [image("1.2.3.4.5.6.2", rotation: 270, annotations: annotations)],
            label: "Marked up")
        XCTAssertFalse(urls.isEmpty)

        for url in urls {
            let file = try DICOMFile.read(from: url)
            // The drawings really are in there, so this is not a vacuous pass.
            XCTAssertNotNil(file.dataSet[.graphicAnnotationSequence],
                            "the annotations reached the published object")
            XCTAssertEqual(
                vrOffenders(in: Array(file.dataSet.allElements)), [],
                "VRs disagreeing with the data dictionary in \(url.lastPathComponent)")
        }
    }

    /// The pseudo-colour path publishes a different SOP class through the same
    /// shared modules, so it inherits whatever the grayscale builder does.
    func test_publishedPseudoColorState_usesDictionaryVRsThroughout() throws {
        let urls = try publish(
            [image("1.2.3.4.5.6.3", palette: .hotIron)], label: "Hot iron")
        XCTAssertFalse(urls.isEmpty)

        for url in urls {
            let file = try DICOMFile.read(from: url)
            XCTAssertEqual(
                vrOffenders(in: Array(file.dataSet.allElements)), [],
                "VRs disagreeing with the data dictionary in \(url.lastPathComponent)")
        }
    }

    /// Image Rotation is the attribute the external validator named. Pinned
    /// with its value so a regression cannot hide behind a passing sweep.
    func test_publishedState_writesImageRotationAsUS() throws {
        let urls = try publish([image("1.2.3.4.5.6.4", rotation: 180)], label: "Half turn")
        let file = try DICOMFile.read(from: try XCTUnwrap(urls.first))

        let rotation = try XCTUnwrap(file.dataSet[.imageRotation])
        XCTAssertEqual(rotation.vr, .US, "(0070,0042) is US, not IS")
        XCTAssertEqual(rotation.uint16Value, 180)
    }
}
