// CombinedAnnotationTests.swift
// DICOMPrintKitTests
//
// The merged text-and-arrow annotation kind (`Kind.annotation`, after
// Weasis's Annotation graphic): what counts as blank, where its arrow's tail
// leaves the label box, what the burner draws for it, and what the GSPS copy
// says — DICOM's own anchored text, anchor visible.

import XCTest
import DICOMKit
@testable import DICOMPrintKit

final class CombinedAnnotationTests: XCTestCase {

    private let referencedImage = ReferencedImage(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
        sopInstanceUID: "1.2.3.4.5.6.7")

    private func combined(
        text: String,
        start: PrintOverlayPoint = PrintOverlayPoint(x: 0.2, y: 0.2),
        end: PrintOverlayPoint = PrintOverlayPoint(x: 0.7, y: 0.7)
    ) -> PrintOverlayAnnotation {
        PrintOverlayAnnotation(kind: .annotation, start: start, end: end,
                               text: text, scale: 0.05, color: .yellow)
    }

    // MARK: - Blankness

    func test_blankOnlyWhenBothHalvesAreMissing() {
        let point = PrintOverlayPoint(x: 0.5, y: 0.5)
        XCTAssertTrue(combined(text: "  ", start: point, end: point).isBlank)
        XCTAssertFalse(combined(text: "Nodule", start: point, end: point).isBlank,
                       "Words alone carry the annotation")
        XCTAssertFalse(combined(text: "").isBlank,
                       "An arrow alone carries the annotation")
        XCTAssertFalse(combined(text: "Nodule").isBlank)
    }

    // MARK: - Leader geometry

    func test_leaderExitLandsOnTheBoxBorder() throws {
        // Box 100 wide, 20 tall, anchor straight off to the right: the exit
        // is the middle of the right edge.
        let exit = try XCTUnwrap(PrintAnnotationLayout.leaderExit(
            boxOrigin: PrintPlanePoint(x: 10, y: 10), boxWidth: 100, boxHeight: 20,
            anchor: PrintPlanePoint(x: 300, y: 20)))
        XCTAssertEqual(exit.x, 110, accuracy: 1e-9)
        XCTAssertEqual(exit.y, 20, accuracy: 1e-9)
    }

    func test_leaderExitIsNilWhenTheAnchorIsInsideTheBox() {
        XCTAssertNil(PrintAnnotationLayout.leaderExit(
            boxOrigin: PrintPlanePoint(x: 10, y: 10), boxWidth: 100, boxHeight: 20,
            anchor: PrintPlanePoint(x: 60, y: 20)))
    }

    func test_leaderTailIsTheRawStartWhenThereAreNoWords() {
        let annotation = combined(text: "")
        let tail = PrintAnnotationLayout.leaderTail(
            for: annotation, imageWidth: 400, imageHeight: 400)
        XCTAssertEqual(tail?.x, annotation.start.x)
        XCTAssertEqual(tail?.y, annotation.start.y)
    }

    func test_leaderTailWithWordsSitsOutsideTheStartButShortOfTheAnchor() throws {
        let annotation = combined(text: "Nodule")
        let tail = try XCTUnwrap(PrintAnnotationLayout.leaderTail(
            for: annotation, imageWidth: 400, imageHeight: 400))
        // On the segment from the box toward the anchor: strictly between the
        // label's top-left and the anchor on both axes (the anchor is down-right).
        XCTAssertGreaterThan(tail.x, annotation.start.x)
        XCTAssertLessThan(tail.x, annotation.end.x)
        XCTAssertGreaterThan(tail.y, annotation.start.y)
        XCTAssertLessThan(tail.y, annotation.end.y)
    }

    func test_leaderTailIsNilWithoutAnArrow() {
        let point = PrintOverlayPoint(x: 0.5, y: 0.5)
        XCTAssertNil(PrintAnnotationLayout.leaderTail(
            for: combined(text: "Nodule", start: point, end: point),
            imageWidth: 400, imageHeight: 400))
    }

    // MARK: - Rasterizing

    func test_rasterizingDrawsACombinedAnnotation() throws {
        let raster = try XCTUnwrap(ImageAnnotationBurner.rasterizing(
            overlays: [combined(text: "Nodule")], width: 256, height: 256))
        XCTAssertTrue(raster.bytes.contains { $0 != 0 },
                      "A combined annotation must reach the overlay texture")
    }

    func test_rasterizingDrawsAnUnlabelledCombinedAnnotation() throws {
        let raster = try XCTUnwrap(ImageAnnotationBurner.rasterizing(
            overlays: [combined(text: "")], width: 256, height: 256))
        XCTAssertTrue(raster.bytes.contains { $0 != 0 },
                      "The arrow half alone must still draw")
    }

    // MARK: - GSPS

    func test_combinedAnnotationBecomesTextObjectWithVisibleAnchor() throws {
        let converted = try XCTUnwrap(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [combined(text: "Nodule")], imageWidth: 400, imageHeight: 200,
            referencedImage: referencedImage))

        XCTAssertTrue(converted.graphicObjects.isEmpty,
                      "Anchored text carries the leader; no polylines beside it")
        let text = try XCTUnwrap(converted.textObjects.first)
        XCTAssertEqual(text.text, "Nodule")
        XCTAssertEqual(text.boundingBoxTopLeft.column ?? -1, 0.2 * 400, accuracy: 1e-9)
        XCTAssertEqual(text.boundingBoxTopLeft.row ?? -1, 0.2 * 200, accuracy: 1e-9)
        XCTAssertEqual(text.anchorPoint?.column ?? -1, 0.7 * 400, accuracy: 1e-9)
        XCTAssertEqual(text.anchorPoint?.row ?? -1, 0.7 * 200, accuracy: 1e-9)
        XCTAssertEqual(text.anchorPointVisible, true)
    }

    func test_combinedAnnotationWithoutArrowKeepsItsAnchorInvisible() throws {
        let point = PrintOverlayPoint(x: 0.25, y: 0.5)
        let converted = try XCTUnwrap(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [combined(text: "Nodule", start: point, end: point)],
            imageWidth: 400, imageHeight: 200, referencedImage: referencedImage))

        let text = try XCTUnwrap(converted.textObjects.first)
        XCTAssertEqual(text.anchorPointVisible, false,
                       "No arrow was drawn, so no leader is promised")
    }

    func test_unlabelledCombinedAnnotationFallsBackToArrowPolylines() throws {
        let converted = try XCTUnwrap(PrintOverlayAnnotationGSPS.graphicAnnotation(
            from: [combined(text: "")], imageWidth: 400, imageHeight: 200,
            referencedImage: referencedImage))

        XCTAssertTrue(converted.textObjects.isEmpty)
        XCTAssertEqual(converted.graphicObjects.count, 2,
                       "Shaft and open head, as the plain arrow kind writes them")
    }

    // MARK: - Codable

    func test_combinedAnnotationSurvivesTheSidecarEncoding() throws {
        let annotation = combined(text: "Nodule")
        let data = try JSONEncoder().encode([annotation])
        let decoded = try JSONDecoder().decode([PrintOverlayAnnotation].self, from: data)
        XCTAssertEqual(decoded, [annotation])
    }
}
