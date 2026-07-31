// PrintMarkWindowTests.swift
// DICOMStudioTests
//
// The film has to look like the screen the reader approved it on, and the mark
// is what carries the screen's window to the film. Those numbers are in stored
// values (the renderer's space); the print preparer windows in output units. The
// crossing point is ``PrintService/prepare(items:request:...)``, and getting it
// wrong on a CT prints a flat black cell with nothing on it but the burned
// caption and whatever the reader drew — which is how the printer emulator first
// showed the fault.

import XCTest
import DICOMCore
import DICOMKit
import DICOMPrintKit
@testable import DICOMStudio

#if canImport(CoreGraphics)

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class PrintMarkWindowTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-mark-window-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A CT-like file: 16-bit MONOCHROME2, Rescale Intercept −1024, stored
    /// values running the full −1024…+1016 HU range.
    private func writeCTFile() throws -> String {
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
            .string(tag: .windowWidth, vr: .DS, value: "80"),
            .string(tag: .sopClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2"),
            .string(tag: .sopInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7.8.9")
        ]
        var pixels = Data()
        for index in 0..<256 {
            let stored = UInt16(index * 8)
            pixels.append(UInt8(stored & 0xFF))
            pixels.append(UInt8(stored >> 8))
        }
        elements.append(DataElement(
            tag: .pixelData, vr: .OW, length: UInt32(pixels.count), valueData: pixels))

        let data = try DICOMFile.create(
            dataSet: DataSet(elements: elements),
            transferSyntaxUID: TransferSyntax.explicitVRLittleEndian.uid).write()
        let url = directory.appendingPathComponent("ct.dcm")
        try data.write(to: url)
        return url.path
    }

    /// A mark's window is the viewer's, in stored values: 40 HU at intercept
    /// −1024 is stored 1064. Sent as-is it would window 1024…1104 HU — above
    /// every pixel in the file — and the cell would come out flat.
    func testMarkWindowPrintsThePictureTheViewerShowed() async throws {
        let path = try writeCTFile()
        let mark = PrintSelectionItem(filePath: path, windowCenter: 1064, windowWidth: 80)

        let prepared = try await PrintService().prepare(
            items: [mark], request: PrintJobRequest())
        let levels = Set([UInt8](try XCTUnwrap(prepared.first).descriptor.pixelData))

        XCTAssertGreaterThan(levels.count, 8,
                             "The mark's stored-value window must be converted to output "
                             + "units, not applied on the far side of the rescale")
    }

    /// A mark with no window of its own prints at the file's VOI — the window
    /// the scanner recorded and the viewer shows — rather than a full-range
    /// stretch. Marking a whole series without opening it is the common way to
    /// get here.
    func testUnwindowedMarkPrintsAtTheFilesOwnWindow() async throws {
        let path = try writeCTFile()          // VOI 40 / 80
        let bare = PrintSelectionItem(filePath: path)
        let windowed = PrintSelectionItem(filePath: path, windowCenter: 1064, windowWidth: 80)

        let fromFile = try await PrintService().prepare(
            items: [bare], request: PrintJobRequest())
        let fromMark = try await PrintService().prepare(
            items: [windowed], request: PrintJobRequest())

        XCTAssertEqual(try XCTUnwrap(fromFile.first).descriptor.pixelData,
                       try XCTUnwrap(fromMark.first).descriptor.pixelData,
                       "An unmarked window must resolve to the file's VOI, which is the "
                       + "same 40 HU window the viewer would be showing")
    }

    // MARK: - The preview's side of the same crossing

    /// The job-wide window is typed in HU, so a preview cell rendered from it
    /// has to be converted into the renderer's stored space first. Left as-is
    /// the cell washes out while the film prints correctly — the preview lying
    /// about the film it is previewing.
    func testJobWideWindowRendersThePreviewCellAtThatWindow() async throws {
        let path = try writeCTFile()
        let mark = PrintSelectionItem(filePath: path)

        // 40 HU typed into the sheet, and the same window in the renderer's own
        // space (stored 1064 at intercept −1024): the same picture.
        let typed = await FrameRenderer.render(
            path: path, frameIndex: 0, windowCenter: 40, windowWidth: 80,
            windowSpace: .outputUnits, presentation: nil, maxDimension: 64)
        let stored = await FrameRenderer.render(
            path: mark.filePath, frameIndex: 0, windowCenter: 1064, windowWidth: 80,
            windowSpace: .storedValues, presentation: nil, maxDimension: 64)
        let mislabelled = await FrameRenderer.render(
            path: path, frameIndex: 0, windowCenter: 40, windowWidth: 80,
            windowSpace: .storedValues, presentation: nil, maxDimension: 64)

        XCTAssertEqual(Self.pixels(try XCTUnwrap(typed)),
                       Self.pixels(try XCTUnwrap(stored)),
                       "A window declared in output units must be converted, not applied raw")
        XCTAssertNotEqual(Self.pixels(try XCTUnwrap(typed)),
                          Self.pixels(try XCTUnwrap(mislabelled)),
                          "…and the two spaces must not render the same, or this test proves "
                          + "nothing about the file it runs on")
    }

    /// The cache must not serve one space's picture for the other's key.
    func testCacheKeyDistinguishesTheTwoWindowSpaces() {
        let outputUnits = FrameRenderer.cacheKey(
            path: "/a.dcm", frameIndex: 0, windowCenter: 40, windowWidth: 80,
            windowSpace: .outputUnits, presentation: nil)
        let storedValues = FrameRenderer.cacheKey(
            path: "/a.dcm", frameIndex: 0, windowCenter: 40, windowWidth: 80,
            windowSpace: .storedValues, presentation: nil)
        XCTAssertNotEqual(outputUnits, storedValues)
    }

    private static func pixels(_ image: CGImage) -> Data {
        image.dataProvider?.data as Data? ?? Data()
    }

    /// The job-wide window from the print sheet is typed by a user, so it is in
    /// output units and must not be converted.
    func testExplicitJobWindowIsTakenAsOutputUnits() async throws {
        let path = try writeCTFile()
        // Same mark, but the job overrides it with 40 HU / 80.
        let mark = PrintSelectionItem(filePath: path, windowCenter: 1064, windowWidth: 80)
        let request = PrintJobRequest(windowSettings: WindowSettings(center: 40, width: 80))

        let explicit = try await PrintService().prepare(items: [mark], request: request)
        let fromMark = try await PrintService().prepare(items: [mark], request: PrintJobRequest())

        XCTAssertEqual(try XCTUnwrap(explicit.first).descriptor.pixelData,
                       try XCTUnwrap(fromMark.first).descriptor.pixelData,
                       "40 HU typed into the sheet and stored 1064 off the viewer are the "
                       + "same window; only one of them needs converting")
    }
}

#endif
