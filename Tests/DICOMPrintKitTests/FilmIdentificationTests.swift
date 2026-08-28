// FilmIdentificationTests.swift
// DICOMPrintKitTests
//
// The rule that decides whether a film names its patient once at its foot or
// under every picture.
//
// The clinical property throughout: a footer is a statement about the whole
// sheet, so it is only ever produced when the whole sheet supports it. A film
// that mixes studies — the case this exists for, and the one a multi-study
// selection will produce — must fall back to captioning each image.

import XCTest
import DICOMNetwork
@testable import DICOMPrintKit

final class FilmIdentificationTests: XCTestCase {

    private func source(
        _ key: String,
        study: String,
        lines: [String] = ["DOE^JANE, 711794, 2026-08-01", "CT ABDOMEN"]
    ) -> FilmIdentificationSource {
        FilmIdentificationSource(key: key, studyKey: study, lines: lines)
    }

    // MARK: Automatic

    func testOneStudyFootersOnce() {
        let identification = FilmIdentificationPlanner.identification(
            for: [source("a", study: "1.2.3"), source("b", study: "1.2.3")],
            placement: .automatic)

        XCTAssertEqual(identification,
                       .footer(lines: ["DOE^JANE, 711794, 2026-08-01", "CT ABDOMEN"]))
    }

    func testMixedStudiesCaptionEachImage() {
        let identification = FilmIdentificationPlanner.identification(
            for: [
                source("a", study: "1.2.3"),
                source("b", study: "9.9.9", lines: ["ROE^RICHARD, 4412", "MR BRAIN"])
            ],
            placement: .automatic)

        XCTAssertEqual(identification, .perImage)
    }

    /// Two studies of one patient on the same day carry identical caption text
    /// and are still two studies: the UID decides, not the words.
    func testSameTextDifferentStudyStillCaptionsEachImage() {
        let identification = FilmIdentificationPlanner.identification(
            for: [source("a", study: "1.2.3"), source("b", study: "1.2.4")],
            placement: .automatic)

        XCTAssertEqual(identification, .perImage)
    }

    /// An unreadable header has no study to agree with, so the film says less
    /// than it might rather than something it cannot support.
    func testUnknownStudyCaptionsEachImage() {
        let identification = FilmIdentificationPlanner.identification(
            for: [source("a", study: ""), source("b", study: "")],
            placement: .automatic)

        XCTAssertEqual(identification, .perImage)
    }

    func testNothingToSayDrawsNothing() {
        let identification = FilmIdentificationPlanner.identification(
            for: [source("a", study: "1.2.3", lines: []),
                  source("b", study: "1.2.3", lines: ["  "])],
            placement: .automatic)

        XCTAssertEqual(identification, .none)
    }

    /// An image whose header could not be read does not break a film that is
    /// otherwise one study — it simply has no caption of its own.
    func testUncaptionedImageDoesNotBreakAFooter() {
        let identification = FilmIdentificationPlanner.identification(
            for: [source("a", study: "1.2.3"), source("b", study: "", lines: [])],
            placement: .automatic)

        XCTAssertEqual(identification.footerLines.count, 2)
    }

    // MARK: Forced placements

    func testPerImageIsNeverFootered() {
        let identification = FilmIdentificationPlanner.identification(
            for: [source("a", study: "1.2.3"), source("b", study: "1.2.3")],
            placement: .perImage)

        XCTAssertEqual(identification, .perImage)
    }

    /// A forced footer on a mixed film lists every patient on it rather than
    /// naming one of them for all of them.
    func testForcedFooterListsEveryStudyOnTheFilm() {
        let identification = FilmIdentificationPlanner.identification(
            for: [
                source("a", study: "1.2.3", lines: ["DOE^JANE", "CT"]),
                source("b", study: "9.9.9", lines: ["ROE^RICHARD", "MR"]),
                source("c", study: "1.2.3", lines: ["DOE^JANE", "CT"])
            ],
            placement: .filmFooter)

        XCTAssertEqual(identification,
                       .footer(lines: ["DOE^JANE", "CT", "ROE^RICHARD", "MR"]))
    }

    // MARK: Footer geometry

    func testFooterBandGrowsWithItsLines() {
        let sheet = FilmSheet(filmSize: .size14InX17In, orientation: .portrait, dpi: 100)
        func band(_ lines: Int) -> Double {
            FilmIdentificationFooter.heightMillimeters(
                lineCount: lines, sheetHeightMillimeters: sheet.heightMillimeters)
        }

        XCTAssertEqual(band(0), 0)
        XCTAssertGreaterThan(band(1), 0)
        XCTAssertGreaterThan(band(2), band(1))
    }

    /// A caption is read at the distance its film is read from: the big sheet
    /// on a viewing box carries bigger type than the small one in a hand.
    func testTypeSizeFollowsTheFilmSize() {
        let large = FilmSheet(filmSize: .size14InX17In, orientation: .portrait, dpi: 100)
        let small = FilmSheet(filmSize: .size8InX10In, orientation: .portrait, dpi: 100)

        let largeFont = FilmIdentificationFooter.fontMillimeters(
            sheetHeightMillimeters: large.heightMillimeters)
        let smallFont = FilmIdentificationFooter.fontMillimeters(
            sheetHeightMillimeters: small.heightMillimeters)

        XCTAssertGreaterThan(largeFont, smallFont)
        // Bounded at both ends: unreadable below, and eating the pictures above.
        XCTAssertGreaterThanOrEqual(smallFont, FilmIdentificationFooter.minimumFontMillimeters)
        XCTAssertLessThanOrEqual(largeFont, FilmIdentificationFooter.maximumFontMillimeters)
        XCTAssertEqual(FilmIdentificationFooter.fontMillimeters(sheetHeightMillimeters: 0),
                       FilmIdentificationFooter.minimumFontMillimeters)

        // And the strip it needs follows it.
        XCTAssertGreaterThan(
            FilmIdentificationFooter.heightMillimeters(
                lineCount: 2, sheetHeightMillimeters: large.heightMillimeters),
            FilmIdentificationFooter.heightMillimeters(
                lineCount: 2, sheetHeightMillimeters: small.heightMillimeters))
    }

    func testFooterAnnotationsArePositionedInOrder() {
        let annotations = FilmIdentificationFooter.annotations(for: ["one", "two"])

        XCTAssertEqual(annotations.map(\.position), [1, 2])
        XCTAssertEqual(annotations.map(\.text), ["one", "two"])
    }

    // MARK: Layout

    /// The footer is kept clear of the cells: text drawn across the bottom row
    /// is text over anatomy, which is what the strip exists to prevent.
    func testCellsLeaveRoomForTheFooter() {
        let sheet = FilmSheet(filmSize: .size14InX17In, orientation: .portrait, dpi: 100)
        let format = PrintImageDisplayFormat.parse("STANDARD\\2,2")
        let footer = FilmIdentificationFooter.heightMillimeters(
            lineCount: 2, sheetHeightMillimeters: sheet.heightMillimeters)

        let plain = FilmCellLayout.cells(for: format, on: sheet)
        let footered = FilmCellLayout.cells(for: format, on: sheet, footerMillimeters: footer)

        let plainBottom = plain.map { $0.y + $0.height }.max() ?? 0
        let footeredBottom = footered.map { $0.y + $0.height }.max() ?? 0
        XCTAssertEqual(plainBottom - footeredBottom,
                       sheet.pixels(fromMillimeters: footer), accuracy: 1)
        // Only the height gives way — the film is no narrower for having a name
        // on it.
        XCTAssertEqual(plain[0].width, footered[0].width, accuracy: 0.001)
    }

    /// A footer that would swallow the sheet is capped: a film with no cells is
    /// not an improvement on a film with a repeated caption.
    func testAbsurdFooterCannotSwallowTheSheet() {
        let sheet = FilmSheet(filmSize: .size8InX10In, orientation: .portrait, dpi: 50)
        let cells = FilmCellLayout.cells(
            for: PrintImageDisplayFormat.parse("STANDARD\\1,1"),
            on: sheet, footerMillimeters: 10_000)

        XCTAssertGreaterThan(cells[0].height, 0)
    }

    // MARK: Per-film annotations on the wire

    func testAFilmWithoutItsOwnAnnotationsFallsBackToTheJobWideSet() {
        let options = PrintOptions(
            annotations: [PrintAnnotation(position: 1, text: "JOB")],
            filmAnnotations: [[PrintAnnotation(position: 1, text: "FILM 1")], []])

        XCTAssertEqual(options.annotations(forFilm: 0).map(\.text), ["FILM 1"])
        XCTAssertEqual(options.annotations(forFilm: 1).map(\.text), ["JOB"])
        XCTAssertEqual(options.annotations(forFilm: 7).map(\.text), ["JOB"])
        XCTAssertTrue(options.hasAnnotations)
    }
}
