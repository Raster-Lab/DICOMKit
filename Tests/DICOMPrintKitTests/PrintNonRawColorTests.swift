//
// PrintNonRawColorTests.swift
// DICOMPrintKitTests
//
// Colour through the *processed* path, end to end.
//
// The reported defect: raw mode sent colour, and everything else — printing and
// saving a film alike — came out grey. Raw copies the source descriptor, so its
// RGB survived; the processed path handed `ImagePreprocessor` the job's colour
// mode, which flattened RGB to luminance before the pixels ever reached the
// wire. These tests drive real files through the real preparer, so they fail if
// the flattening ever comes back.
//

import XCTest
import DICOMCore
import DICOMKit
import DICOMNetwork
import CoreGraphics
@testable import DICOMPrintKit

final class PrintNonRawColorTests: XCTestCase {

    // MARK: Fixtures

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("non-raw-colour-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        try super.tearDownWithError()
    }

    /// A 8×8 RGB image whose pixels are unmistakably coloured — a flattened
    /// copy would have all three samples equal, which the assertions look for.
    private func writeRGBFile(named name: String = "colour.dcm") throws -> String {
        let size = 8
        var pixels = Data()
        for _ in 0..<(size * size) {
            pixels.append(contentsOf: [UInt8(220), 20, 40])
        }

        var dataSet = DataSet()
        dataSet.setString("Doe^John", for: .patientName, vr: .PN)
        dataSet.setUInt16(UInt16(size), for: .rows)
        dataSet.setUInt16(UInt16(size), for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(3, for: .samplesPerPixel)
        dataSet.setUInt16(0, for: .planarConfiguration)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setString("RGB", for: .photometricInterpretation, vr: .CS)
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)

        let url = directory.appendingPathComponent(name)
        try DICOMFile.create(dataSet: dataSet).write().write(to: url)
        return url.path
    }

    /// Composes at a low resolution: these tests assert on colour, not on
    /// sharpness, and rasterizing a full-resolution 14x17 sheet costs seconds of
    /// CoreGraphics time that starve the timing-sensitive SCP tests running
    /// alongside them.
    private var settings: PrintSCPSettings { PrintSCPSettings(dpi: 36) }

    private func request(preservesSourceColor: Bool = true) -> PrintJobRequest {
        var request = PrintJobRequest()
        request.colorMode = .grayscale      // the default that used to flatten
        request.raw = false                 // the path that used to lose colour
        request.preservesSourceColor = preservesSourceColor
        return request
    }

    // MARK: The defect

    /// Processed, not raw, on a grayscale job: the frame keeps three samples
    /// per pixel and stays RGB.
    func testProcessedColorSourceKeepsItsColor() async throws {
        let path = try writeRGBFile()
        let prepared = try await PrintImagePreparer().prepare(
            paths: [path], request: request())

        let frame = try XCTUnwrap(prepared.first)
        XCTAssertEqual(frame.descriptor.samplesPerPixel, 3)
        XCTAssertEqual(frame.descriptor.photometricInterpretation, "RGB")
    }

    /// Colour that survives as three *equal* samples is grey wearing RGB's
    /// clothes, so the channels are checked to actually differ.
    func testPreparedPixelsAreNotFlattenedToGrey() async throws {
        let path = try writeRGBFile()
        let prepared = try await PrintImagePreparer().prepare(
            paths: [path], request: request())

        let pixels = try XCTUnwrap(prepared.first).descriptor.pixelData
        XCTAssertGreaterThanOrEqual(pixels.count, 3)
        let red = pixels[pixels.startIndex]
        let green = pixels[pixels.startIndex + 1]
        let blue = pixels[pixels.startIndex + 2]
        XCTAssertNotEqual(red, green, "channels are equal — the frame was flattened")
        XCTAssertNotEqual(red, blue, "channels are equal — the frame was flattened")
    }

    /// Asking for greys still gets greys — the switch is real, not decorative.
    func testFlatteningIsStillAvailableOnRequest() async throws {
        let path = try writeRGBFile()
        let prepared = try await PrintImagePreparer().prepare(
            paths: [path], request: request(preservesSourceColor: false))

        let frame = try XCTUnwrap(prepared.first)
        XCTAssertEqual(frame.descriptor.samplesPerPixel, 1)
        XCTAssertEqual(frame.descriptor.photometricInterpretation, "MONOCHROME2")
    }

    // MARK: The download

    /// "Save Film" composes through the same simulator the print path uses, so
    /// a saved sheet of a colour study is a colour sheet.
    func testSavedFilmOfAColorStudyIsInColor() async throws {
        let path = try writeRGBFile()
        let jobRequest = request()
        let prepared = try await PrintImagePreparer().prepare(
            paths: [path], request: jobRequest)

        let films = try PrintSCPSimulator().composeFilms(
            images: prepared,
            request: jobRequest,
            settings: settings,
            callingAETitle: "DICOMSTUDIO")

        let film = try XCTUnwrap(films.first)
        XCTAssertTrue(film.isColor, "the saved film flattened the study to greys")
        XCTAssertEqual(film.samplesPerPixel, 3)
    }

    /// A monochrome study is unaffected: nothing is widened just because it can be.
    func testSavedFilmOfAMonochromeStudyStaysGrey() async throws {
        var dataSet = DataSet()
        dataSet.setUInt16(8, for: .rows)
        dataSet.setUInt16(8, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        dataSet[.pixelData] = DataElement.data(
            tag: .pixelData, vr: .OB, data: Data((0..<64).map { UInt8($0 * 3) }))

        let url = directory.appendingPathComponent("grey.dcm")
        try DICOMFile.create(dataSet: dataSet).write().write(to: url)

        let jobRequest = request()
        let prepared = try await PrintImagePreparer().prepare(
            paths: [url.path], request: jobRequest)
        XCTAssertEqual(try XCTUnwrap(prepared.first).descriptor.samplesPerPixel, 1)

        let films = try PrintSCPSimulator().composeFilms(
            images: prepared, request: jobRequest,
            settings: settings, callingAETitle: "DICOMSTUDIO")
        XCTAssertFalse(try XCTUnwrap(films.first).isColor)
    }
}
