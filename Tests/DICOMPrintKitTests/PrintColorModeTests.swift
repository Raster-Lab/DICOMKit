//
// PrintColorModeTests.swift
// DICOMPrintKitTests
//
// The colour mode a job actually goes out on.
//
// Basic Grayscale and Basic Colour are different SOP classes with different
// Image Box rules — grayscale accepts Samples per Pixel 1 only (PS3.3 C.13.5) —
// so a request whose colour mode disagrees with the pixels it prepared is a
// job the printer rejects (0x0106). ``PrintWorkflow/reconcilingColorMode``
// makes the SOP class follow the pixels; these tests pin that both ways.
//

import XCTest
import DICOMNetwork
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class PrintColorModeTests: XCTestCase {

    // MARK: Fixtures

    private func configuration(_ mode: DICOMNetwork.PrintColorMode) -> PrintConfiguration {
        PrintConfiguration(
            host: "127.0.0.1", port: 11112,
            callingAETitle: "SCU", calledAETitle: "PRINTER",
            timeout: 5, colorMode: mode)
    }

    private func descriptor(samplesPerPixel: UInt16) -> PrintImageData {
        let isColor = samplesPerPixel == 3
        return PrintImageData(
            pixelData: Data(repeating: 128, count: 8 * 8 * Int(samplesPerPixel)),
            rows: 8, columns: 8, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: samplesPerPixel, pixelRepresentation: 0,
            photometricInterpretation: isColor ? "RGB" : "MONOCHROME2")
    }

    // MARK: The failing case from the field

    /// An RGB frame on a grayscale request: the Basic Grayscale Image Box would
    /// reject it outright ("Samples per Pixel must be 1"), so the job is moved
    /// onto Basic Colour instead of being sent to fail.
    func testColorPixelsOnGrayscaleRequestSwitchToColor() {
        let reconciled = PrintWorkflow.reconcilingColorMode(
            configuration(.grayscale), with: [descriptor(samplesPerPixel: 3)])
        XCTAssertEqual(reconciled.colorMode, .color)
    }

    /// One colour frame in a mixed job is enough: every box travels on the same
    /// association, and the grayscale class cannot carry that one.
    func testOneColorFrameAmongMonochromeSwitchesTheWholeJob() {
        let images = [
            descriptor(samplesPerPixel: 1),
            descriptor(samplesPerPixel: 3),
            descriptor(samplesPerPixel: 1)
        ]
        let reconciled = PrintWorkflow.reconcilingColorMode(
            configuration(.grayscale), with: images)
        XCTAssertEqual(reconciled.colorMode, .color)
    }

    // MARK: The other direction

    /// Monochrome pixels on a colour request: widening greys to RGB triples the
    /// bytes on the wire and changes nothing on the film, so the job drops back.
    func testMonochromePixelsOnColorRequestDropToGrayscale() {
        let reconciled = PrintWorkflow.reconcilingColorMode(
            configuration(.color), with: [descriptor(samplesPerPixel: 1)])
        XCTAssertEqual(reconciled.colorMode, .grayscale)
    }

    // MARK: Left alone

    func testAgreeingConfigurationIsUnchanged() {
        let gray = PrintWorkflow.reconcilingColorMode(
            configuration(.grayscale), with: [descriptor(samplesPerPixel: 1)])
        XCTAssertEqual(gray.colorMode, .grayscale)

        let color = PrintWorkflow.reconcilingColorMode(
            configuration(.color), with: [descriptor(samplesPerPixel: 3)])
        XCTAssertEqual(color.colorMode, .color)
    }

    /// Nothing prepared says nothing about colour, so the request stands.
    func testEmptyDescriptorsLeaveTheRequestAlone() {
        let reconciled = PrintWorkflow.reconcilingColorMode(
            configuration(.color), with: [])
        XCTAssertEqual(reconciled.colorMode, .color)
    }

    /// Only the colour mode moves — the association is otherwise the one the
    /// profile described.
    func testConnectionSettingsSurviveReconciliation() {
        let original = configuration(.grayscale)
        let reconciled = PrintWorkflow.reconcilingColorMode(
            original, with: [descriptor(samplesPerPixel: 3)])
        XCTAssertEqual(reconciled.host, original.host)
        XCTAssertEqual(reconciled.port, original.port)
        XCTAssertEqual(reconciled.callingAETitle, original.callingAETitle)
        XCTAssertEqual(reconciled.calledAETitle, original.calledAETitle)
        XCTAssertEqual(reconciled.timeout, original.timeout)
    }

    // MARK: What the reader is told

    /// Collects diagnostics from the `@Sendable` handler the workflow takes.
    private final class DiagnosticCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String] = []

        func append(_ line: String) {
            lock.lock(); defer { lock.unlock() }
            storage.append(line)
        }

        var lines: [String] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }
    }

    /// The switch is announced: a film that comes out in colour when grayscale
    /// was configured is something the reader has to know about.
    func testSwitchIsReportedToDiagnostics() {
        let collector = DiagnosticCollector()
        _ = PrintWorkflow.reconcilingColorMode(
            configuration(.grayscale), with: [descriptor(samplesPerPixel: 3)],
            diagnostics: { collector.append($0.text) })
        XCTAssertEqual(collector.lines.count, 1)
        XCTAssertTrue(collector.lines[0].lowercased().contains("colour"))
    }

    func testAgreeingConfigurationSaysNothing() {
        let collector = DiagnosticCollector()
        _ = PrintWorkflow.reconcilingColorMode(
            configuration(.grayscale), with: [descriptor(samplesPerPixel: 1)],
            diagnostics: { collector.append($0.text) })
        XCTAssertTrue(collector.lines.isEmpty)
    }
}

// MARK: - Preparation policy

/// Which colour mode the *preprocessor* is driven with.
///
/// This is the half of the defect that raw mode hid. Raw copies the source
/// descriptor, so a colour ultrasound stayed RGB and printed in colour; the
/// processed path handed the preprocessor the request's mode, which flattened
/// the same image to greys before it ever reached the wire. Colour is now kept
/// unless the job deliberately gives it up.
final class PrintPreparationColorModeTests: XCTestCase {

    private func request(
        colorMode: DICOMNetwork.PrintColorMode = .grayscale,
        preservesSourceColor: Bool = true
    ) -> PrintJobRequest {
        var request = PrintJobRequest()
        request.colorMode = colorMode
        request.preservesSourceColor = preservesSourceColor
        return request
    }

    private func descriptor(
        samplesPerPixel: Int, photometric: PhotometricInterpretation
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: 8, columns: 8, numberOfFrames: 1,
            bitsAllocated: 8, bitsStored: 8, highBit: 7, isSigned: false,
            samplesPerPixel: samplesPerPixel,
            photometricInterpretation: photometric)
    }

    /// The reported bug: an RGB source on a grayscale job kept its colour.
    func testRGBSourceIsPreparedInColorDespiteAGrayscaleRequest() {
        let mode: DICOMKit.PrintColorMode = PrintImagePreparer.preparationColorMode(
            request(), sourceDescriptor: descriptor(samplesPerPixel: 3, photometric: .rgb))
        XCTAssertEqual(mode, .color)
    }

    /// YBR sources are colour too — the preprocessor converts them to RGB.
    func testYBRSourceIsPreparedInColor() {
        let mode: DICOMKit.PrintColorMode = PrintImagePreparer.preparationColorMode(
            request(), sourceDescriptor: descriptor(samplesPerPixel: 3, photometric: .ybrFull422))
        XCTAssertEqual(mode, .color)
    }

    /// PALETTE COLOR stores one sample per pixel and is still colour, so the
    /// photometric interpretation has to be consulted, not just the sample count.
    func testPaletteColorSourceIsPreparedInColor() {
        let mode: DICOMKit.PrintColorMode = PrintImagePreparer.preparationColorMode(
            request(), sourceDescriptor: descriptor(samplesPerPixel: 1, photometric: .paletteColor))
        XCTAssertEqual(mode, .color)
    }

    /// There is no colour in a monochrome source to keep.
    func testMonochromeSourceStaysGrayscale() {
        let mode: DICOMKit.PrintColorMode = PrintImagePreparer.preparationColorMode(
            request(), sourceDescriptor: descriptor(samplesPerPixel: 1, photometric: .monochrome2))
        XCTAssertEqual(mode, .grayscale)
    }

    /// Switching preservation off is how greys are asked for now.
    func testColorIsFlattenedWhenPreservationIsOff() {
        let mode: DICOMKit.PrintColorMode = PrintImagePreparer.preparationColorMode(
            request(preservesSourceColor: false),
            sourceDescriptor: descriptor(samplesPerPixel: 3, photometric: .rgb))
        XCTAssertEqual(mode, .grayscale)
    }

    /// The explicit ask for greys wins even on a colour-mode job: the colour
    /// mode is the printer's channel (which SOP class the wire negotiates),
    /// while "print colour images as greys" is the reader's word on the
    /// pixels — and a grey frame rides in a colour box without contradiction,
    /// where colour in a job that promised greys is the bug this fixes.
    func testExplicitGreysWinOverAColorRequest() {
        let mode: DICOMKit.PrintColorMode = PrintImagePreparer.preparationColorMode(
            request(colorMode: .color, preservesSourceColor: false),
            sourceDescriptor: descriptor(samplesPerPixel: 3, photometric: .rgb))
        XCTAssertEqual(mode, .grayscale)
    }

    /// The regression behind the switch looking dead: a film-wide palette used
    /// to force the cell back to colour past an explicit ask for greys. The
    /// palette now loses on colour sources — and still colourises monochrome
    /// ones, where it is a deliberate act the toggle does not speak to.
    func testExplicitGreysWinOverAPaletteOnAColorSource() {
        var withPalette = request(preservesSourceColor: false)
        withPalette.palette = .hotIron
        let colorSource = descriptor(samplesPerPixel: 3, photometric: .rgb)
        XCTAssertEqual(
            PrintImagePreparer.preparationColorMode(
                withPalette, sourceDescriptor: colorSource),
            .grayscale)
        XCTAssertNil(PrintImagePreparer.preparationPalette(
            withPalette, sourceDescriptor: colorSource))

        let monochromeSource = descriptor(samplesPerPixel: 1, photometric: .monochrome2)
        XCTAssertEqual(
            PrintImagePreparer.preparationColorMode(
                withPalette, sourceDescriptor: monochromeSource),
            .color)
        XCTAssertEqual(PrintImagePreparer.preparationPalette(
            withPalette, sourceDescriptor: monochromeSource), .hotIron)
    }
}
