// PrintCornerCellAnchoringTests.swift
// DICOMStudioTests
//
// The preview holds the corner identification to the corners of the film cell;
// the wire has only the image box to draw into. The crossing point is
// ``PrintService/prepare(items:request:...)``, which letterboxes a fitted frame
// to its cell's shape before the caption is burned — so the film and the
// preview put the patient's name in the same corner. These tests pin down when
// that padding happens (fit scaling, caption present) and, just as important,
// when it must not (fill, true size, raw, no caption).

import XCTest
import DICOMCore
import DICOMKit
import DICOMPrintKit
import DICOMNetwork
@testable import DICOMStudio

#if canImport(CoreGraphics)

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class PrintCornerCellAnchoringTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-corner-cell-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A small square frame — 16×16, so any padding shows up as a changed shape.
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

    private let caption = PrintCornerAnnotation(
        topRight: ["DOE^JANE, 711794"], bottomRight: ["15 Oct 2025"])

    /// The shape of the cell this request lays image `index` into — computed
    /// through the same plan and layout the service pads with.
    private func cellAspect(of request: PrintJobRequest,
                            imageCount: Int, index: Int = 0) -> Double {
        let sheet = FilmSheet(filmSize: request.effectiveFilmSize,
                              orientation: request.effectiveFilmOrientation,
                              dpi: 25.4)
        let cells = request.plan(forImageCount: imageCount).cells(
            onSheetOfWidth: sheet.widthMillimeters, height: sheet.heightMillimeters)
        let cell = cells[index % cells.count]
        return cell.width / cell.height
    }

    // MARK: - Fit scaling pads

    /// A square frame on a portrait 14×17 film: the fitted picture leaves a
    /// letterbox above and below, and the caption must own it — the prepared
    /// frame comes out the shape of the cell, not the shape of the picture.
    func testFitScalingPadsTheFrameToItsCell() async throws {
        let path = try writeFile()
        let mark = PrintSelectionItem(filePath: path)
        let request = PrintJobRequest()

        let prepared = try await PrintService().prepare(
            items: [mark], request: request, annotations: [mark.id: caption])

        let frame = try XCTUnwrap(prepared.first)
        let aspect = Double(frame.descriptor.columns) / Double(frame.descriptor.rows)
        XCTAssertGreaterThan(frame.descriptor.rows, 16,
                             "A square picture in a portrait cell gains letterbox rows")
        XCTAssertEqual(frame.descriptor.columns, 16,
                       "Padding grows exactly one axis — the picture is never scaled")
        XCTAssertEqual(aspect, cellAspect(of: request, imageCount: 1),
                       accuracy: 0.06,
                       "The prepared frame takes the cell's shape, so the printer's "
                       + "fit fills the cell and the caption sits at its corners")
    }

    /// A two-across layout narrows the cell; each frame is padded to the cell
    /// it will actually occupy, not to the sheet.
    func testEachFrameIsPaddedToItsOwnCell() async throws {
        let first = PrintSelectionItem(filePath: try writeFile(named: "a.dcm"))
        let second = PrintSelectionItem(filePath: try writeFile(named: "b.dcm"))
        let request = PrintJobRequest(
            layoutSelection: .custom(PrintLayout(rows: 1, columns: 2)))

        let prepared = try await PrintService().prepare(
            items: [first, second], request: request,
            annotations: [first.id: caption, second.id: caption])

        XCTAssertEqual(prepared.count, 2)
        for (index, frame) in prepared.enumerated() {
            let aspect = Double(frame.descriptor.columns) / Double(frame.descriptor.rows)
            XCTAssertEqual(aspect, cellAspect(of: request, imageCount: 2, index: index),
                           accuracy: 0.03,
                           "Frame \(index) must take the shape of its own half-width cell")
        }
    }

    // MARK: - Everything else does not pad

    func testNoCaptionMeansNoPadding() async throws {
        let mark = PrintSelectionItem(filePath: try writeFile())

        let prepared = try await PrintService().prepare(
            items: [mark], request: PrintJobRequest())

        let frame = try XCTUnwrap(prepared.first)
        XCTAssertEqual(frame.descriptor.rows, 16)
        XCTAssertEqual(frame.descriptor.columns, 16)
    }

    /// Fill covers the cell — there is no letterbox for a caption to cross,
    /// and pre-padding would turn the fill into a letterboxed fit.
    func testFillScalingIsNotPadded() async throws {
        let mark = PrintSelectionItem(filePath: try writeFile())

        let prepared = try await PrintService().prepare(
            items: [mark],
            request: PrintJobRequest(scalingMode: .fillToFilm),
            annotations: [mark.id: caption])

        let frame = try XCTUnwrap(prepared.first)
        XCTAssertEqual(frame.descriptor.rows, 16)
        XCTAssertEqual(frame.descriptor.columns, 16)
    }

    /// True size prints the picture at its physical dimensions; padding would
    /// change the width the film box is asked to hold.
    func testTrueSizeIsNotPadded() async throws {
        let mark = PrintSelectionItem(filePath: try writeFile())

        let prepared = try await PrintService().prepare(
            items: [mark],
            request: PrintJobRequest(scalingMode: .trueSize),
            annotations: [mark.id: caption])

        let frame = try XCTUnwrap(prepared.first)
        XCTAssertEqual(frame.descriptor.rows, 16)
        XCTAssertEqual(frame.descriptor.columns, 16)
    }

    /// Raw sends stored pixels untouched — no caption, no padding, by definition.
    func testRawIsNotPadded() async throws {
        let mark = PrintSelectionItem(filePath: try writeFile())

        let prepared = try await PrintService().prepare(
            items: [mark],
            request: PrintJobRequest(raw: true),
            annotations: [mark.id: caption])

        let frame = try XCTUnwrap(prepared.first)
        XCTAssertEqual(frame.descriptor.rows, 16)
        XCTAssertEqual(frame.descriptor.columns, 16)
    }
}

#endif
