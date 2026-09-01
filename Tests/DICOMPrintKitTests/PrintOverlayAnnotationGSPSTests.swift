// PrintOverlayAnnotationGSPSTests.swift
// DICOMPrintKitTests
//
// The translation of drawn annotations into GSPS vocabulary, and the store
// writing it into the saved object. The sidecar stays the authority for our
// own restore; these pin what the *DICOM* copy says, because that copy is the
// one other viewers read.

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class PrintOverlayAnnotationGSPSTests: XCTestCase {

    private let referencedImage = ReferencedImage(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
        sopInstanceUID: "1.2.3.4.5.6.7")

    // MARK: - Text

    func test_textAnnotation_becomesAnchoredTextObjectInPixels() throws {
        let annotation = PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.25, y: 0.5),
            text: "Nodule",
            scale: 0.04,
            color: .yellow)

        let converted = try XCTUnwrap(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [annotation], imageWidth: 400, imageHeight: 200,
            referencedImage: referencedImage))

        XCTAssertEqual(converted.layer, PrintOverlayAnnotationGSPS.layerName)
        XCTAssertEqual(converted.referencedImages.map(\.sopInstanceUID), ["1.2.3.4.5.6.7"])
        let text = try XCTUnwrap(converted.textObjects.first)
        XCTAssertEqual(text.text, "Nodule")
        XCTAssertEqual(text.anchorPoint?.column, 100)
        XCTAssertEqual(text.anchorPoint?.row, 100)
        XCTAssertEqual(text.boundingBoxTopLeft.column, 100)
        XCTAssertEqual(text.boundingBoxTopLeft.row, 100)
        // The box holds actual words, so it must have area — and it must stay
        // on the picture.
        XCTAssertGreaterThan(text.boundingBoxBottomRight.column, 100)
        XCTAssertLessThanOrEqual(text.boundingBoxBottomRight.column, 400)
        XCTAssertGreaterThan(text.boundingBoxBottomRight.row, 100)
        XCTAssertLessThanOrEqual(text.boundingBoxBottomRight.row, 200)
        XCTAssertEqual(text.boundingBoxUnits, .pixel)
        XCTAssertEqual(text.anchorPointUnits, .pixel)
    }

    // MARK: - Arrow

    func test_arrowAnnotation_becomesShaftAndHeadPolylines() throws {
        let annotation = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.1, y: 0.1),
            end: PrintOverlayPoint(x: 0.9, y: 0.1),
            scale: 0.04,
            color: .yellow)

        let converted = try XCTUnwrap(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [annotation], imageWidth: 1000, imageHeight: 1000,
            referencedImage: referencedImage))

        XCTAssertEqual(converted.graphicObjects.count, 2)
        let shaft = try XCTUnwrap(converted.graphicObjects.first)
        XCTAssertEqual(shaft.type, .polyline)
        XCTAssertEqual(shaft.data, [100, 100, 900, 100])
        XCTAssertEqual(shaft.units, .pixel)

        // The head's chevron passes through the tip and its wings sit behind
        // it, back towards the tail.
        let head = try XCTUnwrap(converted.graphicObjects.last)
        XCTAssertEqual(head.pointCount, 3)
        XCTAssertEqual(head.point(at: 1)?.column, 900)
        XCTAssertEqual(head.point(at: 1)?.row, 100)
        let leftWing = try XCTUnwrap(head.point(at: 0))
        XCTAssertLessThan(leftWing.column, 900,
                          "a wing sits behind the tip, towards the tail")
    }

    // MARK: - What is left out

    func test_blankAnnotationsConvertToNothing() {
        let blankText = PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5),
            text: "", scale: 0.04, color: .yellow)
        let zeroArrow = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.5, y: 0.5),
            end: PrintOverlayPoint(x: 0.5, y: 0.5),
            scale: 0.04, color: .yellow)

        XCTAssertNil(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [blankText, zeroArrow], imageWidth: 512, imageHeight: 512,
            referencedImage: referencedImage))
        XCTAssertTrue(PrintOverlayAnnotationGSPS.graphicLayers(
            for: [blankText, zeroArrow]).isEmpty)
    }

    func test_unknownImageSizeConvertsToNothing() {
        let annotation = PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5),
            text: "Words", scale: 0.04, color: .yellow)

        XCTAssertNil(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [annotation], imageWidth: 0, imageHeight: 0,
            referencedImage: referencedImage))
    }

    // MARK: - The layer

    func test_layerCarriesTheFirstAnnotationsColour() throws {
        let annotation = PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5),
            text: "Words", scale: 0.04, color: .red)

        let layer = try XCTUnwrap(
            PrintOverlayAnnotationGSPS.graphicLayers(for: [annotation]).first)
        XCTAssertEqual(layer.name, PrintOverlayAnnotationGSPS.layerName)
        // .red is (1, 0.25, 0.2) scaled onto the 16-bit P-value range.
        XCTAssertEqual(layer.recommendedRGBValue?.red, 65535)
        XCTAssertEqual(layer.recommendedRGBValue?.green, Int((0.25 * 65535).rounded()))
        XCTAssertEqual(layer.recommendedRGBValue?.blue, Int((0.2 * 65535).rounded()))
    }

    // MARK: - Through the store

    /// The saved object itself carries the sequences — parsed back by the same
    /// parser the store loads views with, so the DICOM copy is provably
    /// readable, not merely written.
    func test_storeWritesAnnotationSequencesIntoTheSavedObject() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintOverlayAnnotationGSPSTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PresentationStateStore(root: root)

        let annotation = PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.25, y: 0.25),
            text: "Nodule",
            scale: 0.04,
            color: .yellow)
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 1, viewportWidth: 512, viewportHeight: 512),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)

        let saved = try store.save(
            images: [.init(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7",
                seriesInstanceUID: "1.2.3.4.5.6",
                display: display,
                annotations: [annotation],
                imageWidth: 512,
                imageHeight: 512)],
            label: "Marked up",
            patient: PresentationStatePatientContext(studyInstanceUID: "1.2.3.4.5"))

        let url = try XCTUnwrap(saved?.states.first?.url)
        let file = try DICOMFile.read(from: url)
        let parsed = try GrayscalePresentationStateParser().parse(dataSet: file.dataSet)

        XCTAssertEqual(parsed.graphicLayers.map(\.name),
                       [PrintOverlayAnnotationGSPS.layerName])
        let readBack = try XCTUnwrap(parsed.graphicAnnotations.first)
        XCTAssertEqual(readBack.textObjects.map(\.text), ["Nodule"])
        XCTAssertEqual(readBack.textObjects.first?.anchorPoint?.column, 128)
        XCTAssertEqual(readBack.referencedImages.map(\.sopInstanceUID), ["1.2.3.4.5.6.7"])
    }

    /// Nothing drawn, or no dimensions to convert with, keeps the object as it
    /// always was: no annotation sequences at all.
    func test_storeOmitsSequencesWithoutDimensions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintOverlayAnnotationGSPSTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PresentationStateStore(root: root)

        let annotation = PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.25, y: 0.25),
            text: "Nodule",
            scale: 0.04,
            color: .yellow)
        let display = ViewerPresentationStateBridge.capture(
            presentation: ViewerPresentation(
                zoom: 1, viewportWidth: 512, viewportHeight: 512),
            windowCenter: 40, windowWidth: 400,
            imageWidth: 512, imageHeight: 512)

        // No imageWidth/imageHeight: the legacy caller shape.
        let saved = try store.save(
            images: [.init(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7",
                seriesInstanceUID: "1.2.3.4.5.6",
                display: display,
                annotations: [annotation])],
            label: "Marked up",
            patient: PresentationStatePatientContext(studyInstanceUID: "1.2.3.4.5"))

        let url = try XCTUnwrap(saved?.states.first?.url)
        let file = try DICOMFile.read(from: url)
        XCTAssertNil(file.dataSet[.graphicAnnotationSequence])
        // The sidecar still carries the drawing, so nothing is lost to us.
        XCTAssertEqual(saved?.states.first?.annotations.map(\.text), ["Nodule"])
    }
}
