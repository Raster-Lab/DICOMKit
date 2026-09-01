// PrintDrawnAnnotationBurnInTests.swift
// DICOMStudioTests
//
// Where a reader's drawn text and arrows become pixels.
//
// On screen they are a separate layer, so they can be moved, retyped and
// deleted — that is what `PrintSelectionModel.cellAnnotations` is for. Film
// has no layer to carry them in, so the output path is where they have to
// become pixels or stop existing: a film that silently arrives without the
// arrow the preview showed is the failure these tests exist to prevent.
//
// The exception is a raw job, whose whole point is untouched stored pixels.

import XCTest
import DICOMCore
import DICOMKit
import DICOMPrintKit
import DICOMNetwork
@testable import DICOMStudio

#if canImport(CoreGraphics)

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class PrintDrawnAnnotationBurnInTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-drawn-annotation-burn-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A small square frame — 16×16, so a burned-in arrow or halo would show
    /// up as a large fraction of changed pixels if it were still being drawn.
    private func writeFile(named name: String = "a.dcm") throws -> String {
        var elements: [DataElement] = [
            .uint16(tag: .rows, value: 16),
            .uint16(tag: .columns, value: 16),
            .uint16(tag: .bitsAllocated, value: 8),
            .uint16(tag: .bitsStored, value: 8),
            .uint16(tag: .highBit, value: 7),
            .uint16(tag: .pixelRepresentation, value: 0),
            .uint16(tag: .samplesPerPixel, value: 1),
            .string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"),
            .string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.7"),
            .string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.\(name.hashValue & 0xFFFF)")
        ]
        let pixels = Data((0..<256).map { UInt8($0 % 256) })
        elements.append(DataElement(
            tag: .pixelData, vr: .OB, length: UInt32(pixels.count), valueData: pixels))

        let data = try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    private var overlays: [PrintOverlayAnnotation] {
        [
            PrintOverlayAnnotation(kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5), text: "lesion"),
            PrintOverlayAnnotation(kind: .arrow,
                                   start: PrintOverlayPoint(x: 0.1, y: 0.1),
                                   end: PrintOverlayPoint(x: 0.9, y: 0.9))
        ]
    }

    /// What the reader drew reaches the film.
    func testDrawnAnnotationsAreBurnedIntoThePreparedPixels() async throws {
        let path = try writeFile()
        let item = PrintSelectionItem(filePath: path, frameIndex: 0)
        let request = PrintJobRequest()
        let service = PrintService()

        let plain = try await service.prepare(items: [item], request: request)
        let burned = try await service.prepare(
            items: [item], request: request,
            drawnAnnotations: [item.id: overlays])

        XCTAssertEqual(plain.count, 1)
        XCTAssertEqual(burned.count, 1)
        XCTAssertNotEqual(
            plain[0].pixelData, burned[0].pixelData,
            "a film has no layer to carry a drawing in — what the reader drew "
            + "has to be in the pixels that are sent")
    }

    /// Passing none — which is what the print sheet does when the reader has
    /// turned the marks off for this job — leaves the picture alone.
    func testNoDrawnAnnotationsLeavesThePixelsUntouched() async throws {
        let path = try writeFile()
        let item = PrintSelectionItem(filePath: path, frameIndex: 0)
        let request = PrintJobRequest()
        let service = PrintService()

        let plain = try await service.prepare(items: [item], request: request)
        let empty = try await service.prepare(
            items: [item], request: request, drawnAnnotations: [:])

        XCTAssertEqual(plain[0].pixelData, empty[0].pixelData,
                       "no drawing means the picture is sent as it was prepared")
    }

    /// A raw job sends stored pixels untouched — the one case where a drawn
    /// annotation cannot travel, which the print sheet warns about rather than
    /// silently honouring.
    func testRawRequestsAreNotBurnedInto() async throws {
        let path = try writeFile()
        let item = PrintSelectionItem(filePath: path, frameIndex: 0)
        var request = PrintJobRequest()
        request.raw = true
        let service = PrintService()

        let plain = try await service.prepare(items: [item], request: request)
        let withOverlays = try await service.prepare(
            items: [item], request: request,
            drawnAnnotations: [item.id: overlays])

        XCTAssertEqual(plain[0].pixelData, withOverlays[0].pixelData,
                       "raw means the stored pixels, drawn on or not")
    }
}

#endif
