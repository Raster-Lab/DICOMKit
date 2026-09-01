//
// FilmComposerPaletteTests.swift
// DICOMPrintKitTests
//
// The emulator's local palette. Two things have to hold at once: the operator
// sees the colours they chose, and the printer stays honest — the P-Values an
// SCU sent are still the P-Values it sent, whatever the sheet looks like.
//

import XCTest
import DICOMCore
import DICOMNetwork
@testable import DICOMPrintKit

final class FilmComposerPaletteTests: XCTestCase {

    // MARK: Fixtures

    private func image(
        value: UInt8, size: UInt16 = 32,
        samplesPerPixel: UInt16 = 1, photometric: String = "MONOCHROME2"
    ) -> PrintImageData {
        PrintImageData(
            pixelData: Data(
                repeating: value,
                count: Int(size) * Int(size) * Int(samplesPerPixel)),
            rows: size, columns: size,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: samplesPerPixel, pixelRepresentation: 0,
            photometricInterpretation: photometric)
    }

    private func film(_ payload: PrintImageData) -> ReceivedFilm {
        let format = "STANDARD\\1,1"
        let parsed = PrintImageDisplayFormat.parse(format)
        let box = ReceivedImageBox(
            sopInstanceUID: "1.2.3.1",
            sopClassUID: payload.samplesPerPixel == 3
                ? basicColorImageBoxSOPClassUID : basicGrayscaleImageBoxSOPClassUID,
            content: ImageBoxContent(
                sopInstanceUID: "1.2.3.1",
                imagePosition: 1,
                polarity: .normal,
                requestedImageSize: nil,
                requestedDecimateCropBehavior: .decimate),
            image: payload)
        return ReceivedFilm(
            printJobUID: "1.2.9.1",
            filmSession: FilmSession(sopInstanceUID: "1.2.9.2", numberOfCopies: 1),
            filmBox: FilmBox(
                sopInstanceUID: "1.2.9.3",
                imageDisplayFormat: format,
                filmOrientation: .portrait,
                filmSizeID: .size8InX10In,
                borderDensity: "BLACK",
                emptyImageDensity: "BLACK",
                trimOption: .no),
            layout: parsed.layout,
            imageBoxes: [box],
            presentationLUTShape: nil,
            annotations: [],
            callingAETitle: "TEST_SCU",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func composer(_ palette: PseudoColorPalette?) -> FilmComposer {
        FilmComposer(configuration: FilmComposerConfiguration(
            dpi: 50, previewPalette: palette))
    }

    // MARK: Default is off

    /// The emulator must not recolour anything unless it was asked to. A film
    /// composed out of the box is the film the SCU sent.
    func testNoPaletteByDefault() {
        XCTAssertNil(FilmComposerConfiguration().previewPalette)
        XCTAssertNil(PrintSCPSettings().previewPalette)
    }

    /// Grey adds no colour, so it is dropped rather than pushing the sheet down
    /// the RGB path for nothing.
    func testGreyPalettesAreDropped() {
        XCTAssertNil(FilmComposerConfiguration(previewPalette: .grayscale).previewPalette)
        XCTAssertEqual(
            FilmComposerConfiguration(previewPalette: .hotIron).previewPalette, .hotIron)
    }

    // MARK: What the operator sees

    /// The regression that motivated the whole feature: an all-grayscale film
    /// must widen to RGB when a palette is set, or the colours are computed and
    /// then thrown away by a grayscale bitmap context.
    func testAGrayscaleFilmBecomesColourUnderAPalette() throws {
        let plain = try composer(nil).compose(film(image(value: 128)))
        XCTAssertEqual(plain.samplesPerPixel, 1)

        let palettised = try composer(.hotIron).compose(film(image(value: 128)))
        XCTAssertEqual(palettised.samplesPerPixel, 3)
        XCTAssertNotEqual(palettised.pixels, plain.pixels)
    }

    /// Every photometric interpretation is eligible, colour included — the case
    /// that used to do nothing at all.
    func testAColourFilmIsRecolouredToo() throws {
        let rgb = image(value: 128, samplesPerPixel: 3, photometric: "RGB")
        let plain = try composer(nil).compose(film(rgb))
        let palettised = try composer(.hotIron).compose(film(rgb))
        XCTAssertEqual(palettised.samplesPerPixel, 3)
        XCTAssertNotEqual(palettised.pixels, plain.pixels)
    }

    /// Different palettes must actually produce different sheets — a stubbed or
    /// short-circuited lookup would pass every test above but this one.
    func testDifferentPalettesProduceDifferentFilms() throws {
        let hot = try composer(.hotIron).compose(film(image(value: 128)))
        let rainbow = try composer(.rainbow).compose(film(image(value: 128)))
        XCTAssertNotEqual(hot.pixels, rainbow.pixels)
    }

    // MARK: What the printer must not do

    /// The conformance guarantee. The palette is a viewing choice; the image
    /// box's P-Values are the sending operator's approved data. Composing a
    /// sheet must leave them untouched, so anything that re-reads or re-sends
    /// them is unaffected by what the emulator was showing.
    func testComposingDoesNotAlterTheReceivedPValues() throws {
        let payload = image(value: 128)
        let original = payload.pixelData
        let received = film(payload)

        _ = try composer(.hotIron).compose(received)

        XCTAssertEqual(received.imageBoxes[0].image?.pixelData, original)
        XCTAssertEqual(
            received.imageBoxes[0].image?.photometricInterpretation, "MONOCHROME2")
        XCTAssertEqual(received.imageBoxes[0].image?.samplesPerPixel, 1)
    }

    // MARK: The reduction

    /// Rec.601 luminance, matching the rest of the kit — so a palettised sheet
    /// and a grey one agree about which pixels are bright.
    func testColourSamplesReduceByLuminance() {
        let red = FilmComposer.palettise(
            Data([255, 0, 0]), samplesPerPixel: 3, palette: .grayscale)
        let green = FilmComposer.palettise(
            Data([0, 255, 0]), samplesPerPixel: 3, palette: .grayscale)
        let blue = FilmComposer.palettise(
            Data([0, 0, 255]), samplesPerPixel: 3, palette: .grayscale)
        XCTAssertGreaterThan(green[0], red[0])
        XCTAssertGreaterThan(red[0], blue[0])
    }

    /// One sample in, three out, whatever the input width.
    func testPalettiseAlwaysReturnsRGB() {
        XCTAssertEqual(
            FilmComposer.palettise(
                Data(repeating: 128, count: 4), samplesPerPixel: 1, palette: .hotIron).count,
            4 * 3)
        XCTAssertEqual(
            FilmComposer.palettise(
                Data(repeating: 128, count: 12), samplesPerPixel: 3, palette: .hotIron).count,
            4 * 3)
    }

    // MARK: Settings round-trip

    /// A palette chosen in the UI has to survive being written to the settings
    /// document and read back, and an older document without the key must still
    /// load — as no palette, which is the safe default.
    func testSettingsRoundTripAndBackwardCompatibility() throws {
        var settings = PrintSCPSettings()
        settings.previewPalette = .hotIron
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PrintSCPSettings.self, from: data)
        XCTAssertEqual(decoded.previewPalette, .hotIron)
        XCTAssertEqual(decoded.makeComposerConfiguration().previewPalette, .hotIron)

        let legacy = try JSONDecoder().decode(
            PrintSCPSettings.self, from: Data("{}".utf8))
        XCTAssertNil(legacy.previewPalette)
    }
}
