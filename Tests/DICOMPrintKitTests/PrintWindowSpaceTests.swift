// PrintWindowSpaceTests.swift
// DICOMPrintKitTests
//
// Regression tests for how the print path resolves a VOI window: which of the
// two window spaces the numbers are in, and what happens when there are no
// numbers at all.
//
// A window taken off the viewer is in *stored* values — the renderer works on
// stored pixels, so Studio divides the header's window through the rescale pair
// before it holds it — while `ImagePreprocessor` rescales first and windows in
// *output* units. Feeding one to the other is not a small shift: on a CT with a
// −1024 (or −8192) Rescale Intercept the window lands clear of every pixel and
// the film cell prints flat black, with only the burned caption and any drawn
// annotation visible on it. That is exactly what the printer emulator received.

import XCTest
import DICOMCore
import DICOMKit
import DICOMNetwork
@testable import DICOMPrintKit

final class PrintWindowSpaceTests: XCTestCase {

    // MARK: - Fixture

    /// Rescale Intercept of the fixture: a CT-style negative intercept, which is
    /// what makes the two spaces disagree at all.
    private let intercept: Double = -1024

    /// A narrow soft-tissue window, in output units (HU).
    private let windowInHU = WindowSettings(center: 40, width: 80)

    /// 16×16 16-bit MONOCHROME2 frame whose stored values span the window:
    /// stored 1024 is 0 HU, so the frame runs roughly −1024…+1000 HU.
    private func makeDataSet() -> DataSet {
        var elements: [DataElement] = [
            .uint16(tag: .rows, value: 16),
            .uint16(tag: .columns, value: 16),
            .uint16(tag: .bitsAllocated, value: 16),
            .uint16(tag: .bitsStored, value: 12),
            .uint16(tag: .highBit, value: 11),
            .uint16(tag: .pixelRepresentation, value: 0),
            .uint16(tag: .samplesPerPixel, value: 1),
            .string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"),
            .string(tag: .rescaleIntercept, vr: .DS, value: "-1024"),
            .string(tag: .rescaleSlope, vr: .DS, value: "1"),
            .string(tag: .windowCenter, vr: .DS, value: "40"),
            .string(tag: .windowWidth, vr: .DS, value: "80")
        ]
        var pixels = Data()
        for index in 0..<256 {
            let stored = UInt16(index * 8)          // 0…2040 stored = −1024…+1016 HU
            pixels.append(UInt8(stored & 0xFF))
            pixels.append(UInt8(stored >> 8))
        }
        elements.append(DataElement(
            tag: .pixelData, vr: .OW, length: UInt32(pixels.count), valueData: pixels))
        return DataSet(elements: elements)
    }

    private func makePixelData(_ dataSet: DataSet) throws -> PixelData {
        try XCTUnwrap(dataSet.pixelData())
    }

    /// How many distinct grey levels a prepared frame carries. A window that
    /// misses the pixels collapses this to 1 (or 2 with a stray edge value).
    private func greyLevels(_ image: PreparedPrintImage) -> Int {
        Set([UInt8](image.descriptor.pixelData)).count
    }

    // MARK: - The conversion

    func testStoredWindowIsConvertedToOutputUnits() {
        let dataSet = makeDataSet()
        // The viewer holds this window as stored values: 40 HU at intercept
        // −1024 is stored 1064.
        var request = PrintJobRequest(
            windowSettings: WindowSettings(center: 1064, width: 400),
            windowSpace: .storedValues)

        let converted = PrintImagePreparer.windowInOutputUnits(request, dataSet: dataSet)
        XCTAssertEqual(converted?.center, 40)
        XCTAssertEqual(converted?.width, 400)

        // The same numbers declared as output units are passed straight through:
        // that is what `dicom-print --window-center 1064` means.
        request.windowSpace = .outputUnits
        let untouched = PrintImagePreparer.windowInOutputUnits(request, dataSet: dataSet)
        XCTAssertEqual(untouched?.center, 1064)
        XCTAssertEqual(untouched?.width, 400)
    }

    func testConversionHonorsRescaleSlope() {
        let dataSet = DataSet(elements: [
            .string(tag: .rescaleIntercept, vr: .DS, value: "-1024"),
            .string(tag: .rescaleSlope, vr: .DS, value: "2")
        ])
        let request = PrintJobRequest(
            windowSettings: WindowSettings(center: 532, width: 200),
            windowSpace: .storedValues)

        let converted = PrintImagePreparer.windowInOutputUnits(request, dataSet: dataSet)
        XCTAssertEqual(converted?.center, 40)     // 532 × 2 − 1024
        XCTAssertEqual(converted?.width, 400)     // 200 × 2
    }

    func testNoWindowStaysNil() {
        let request = PrintJobRequest(windowSpace: .storedValues)
        XCTAssertNil(PrintImagePreparer.windowInOutputUnits(request, dataSet: makeDataSet()))
    }

    // MARK: - What it does to the pixels

    /// The regression: a viewer window sent as-is prints a flat cell.
    func testStoredWindowSentAsOutputUnitsFlattensTheFrame() async throws {
        let dataSet = makeDataSet()
        let pixelData = try makePixelData(dataSet)
        let preparer = PrintImagePreparer()

        // Mislabelled — the bug. Stored 1064 read as 1064 HU puts the window at
        // 1024…1104 HU, above every pixel in the frame (which tops out at
        // 1016 HU), so every pixel clips to one value.
        let wrong = try await preparer.prepare(
            pixelData: pixelData, dataSet: dataSet,
            request: PrintJobRequest(
                windowSettings: WindowSettings(center: 1064, width: 80),
                windowSpace: .outputUnits))
        XCTAssertEqual(greyLevels(try XCTUnwrap(wrong.first)), 1,
                       "A stored-value window read as output units must be the flat cell "
                       + "this test exists to distinguish, not a picture")

        // Labelled — the fix.
        let right = try await preparer.prepare(
            pixelData: pixelData, dataSet: dataSet,
            request: PrintJobRequest(
                windowSettings: WindowSettings(center: 1064, width: 80),
                windowSpace: .storedValues))
        XCTAssertGreaterThan(greyLevels(try XCTUnwrap(right.first)), 8,
                             "A viewer window must produce the same picture the viewer showed")
    }

    /// Declaring the space must not disturb a window that was already in output
    /// units, which is every window the CLI sends.
    func testOutputUnitsWindowIsUnchangedByTheFix() async throws {
        let dataSet = makeDataSet()
        let pixelData = try makePixelData(dataSet)
        let preparer = PrintImagePreparer()

        let prepared = try await preparer.prepare(
            pixelData: pixelData, dataSet: dataSet,
            request: PrintJobRequest(windowSettings: windowInHU))
        let converted = try await preparer.prepare(
            pixelData: pixelData, dataSet: dataSet,
            request: PrintJobRequest(
                windowSettings: WindowSettings(center: 1064, width: 80),
                windowSpace: .storedValues))

        XCTAssertEqual(try XCTUnwrap(prepared.first).descriptor.pixelData,
                       try XCTUnwrap(converted.first).descriptor.pixelData,
                       "40 HU and stored 1064 at intercept −1024 are the same window")
    }

    // MARK: - No window at all

    /// A mark made without opening the file carries no window — marking a whole
    /// series, or printing from the library. The film must still read at the
    /// window the scanner recorded, not at a full-range stretch from air to bone.
    func testUnwindowedFrameUsesTheDataSetsOwnVOI() async throws {
        let dataSet = makeDataSet()          // VOI 40 / 80 in the header
        let pixelData = try makePixelData(dataSet)
        let preparer = PrintImagePreparer()

        let resolved = PrintImagePreparer.resolvedWindow(PrintJobRequest(), dataSet: dataSet)
        XCTAssertEqual(resolved?.center, 40)
        XCTAssertEqual(resolved?.width, 80)

        let implicit = try await preparer.prepare(
            pixelData: pixelData, dataSet: dataSet, request: PrintJobRequest())
        let explicit = try await preparer.prepare(
            pixelData: pixelData, dataSet: dataSet,
            request: PrintJobRequest(windowSettings: windowInHU))

        XCTAssertEqual(try XCTUnwrap(implicit.first).descriptor.pixelData,
                       try XCTUnwrap(explicit.first).descriptor.pixelData,
                       "An unwindowed frame must print at the file's VOI, which is what "
                       + "the viewer shows it at")
    }

    /// The VOI rung must not swallow a window the caller did state.
    func testRequestWindowStillWinsOverTheDataSetVOI() {
        let dataSet = makeDataSet()          // VOI 40 / 80
        let request = PrintJobRequest(windowSettings: WindowSettings(center: -600, width: 1200))
        let resolved = PrintImagePreparer.resolvedWindow(request, dataSet: dataSet)
        XCTAssertEqual(resolved?.center, -600)
        XCTAssertEqual(resolved?.width, 1200)
    }

    /// A multi-valued VOI — a lung and a soft-tissue window in one element —
    /// resolves to its first pair, the default presentation (PS3.3 C.11.2).
    func testMultiValuedVOIResolvesToItsFirstPair() {
        let dataSet = DataSet(elements: [
            .string(tag: .windowCenter, vr: .DS, value: "-600\\50"),
            .string(tag: .windowWidth, vr: .DS, value: "1200\\350")
        ])
        let resolved = PrintImagePreparer.resolvedWindow(PrintJobRequest(), dataSet: dataSet)
        XCTAssertEqual(resolved?.center, -600)
        XCTAssertEqual(resolved?.width, 1200)
    }

    /// A file with no VOI at all leaves the preprocessor to auto-stretch, which
    /// is the only thing left to do and what it did before.
    func testFrameWithNoVOIFallsBackToTheAutoStretch() {
        let dataSet = DataSet(elements: [
            .string(tag: .rescaleIntercept, vr: .DS, value: "-1024"),
            .string(tag: .rescaleSlope, vr: .DS, value: "1")
        ])
        XCTAssertNil(PrintImagePreparer.resolvedWindow(PrintJobRequest(), dataSet: dataSet))
    }
}
