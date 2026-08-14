// PatientIdentificationOverlaySizingTests.swift
// DICOMStudioTests
//
// The identification in a film cell's corners: how big the type is, and how much
// of the picture a corner block stands on.
//
// The property under test throughout: the type is scaled from the picture it is
// drawn on and bounded at both ends, so a 4×5 tile's caption is still readable
// and a full-sheet caption is still a caption rather than a headline.

#if canImport(SwiftUI)
import Testing
@testable import DICOMStudio
import DICOMPrintKit
import Foundation
import CoreGraphics

@Suite("Patient Identification Overlay Sizing Tests")
@MainActor
struct PatientIdentificationOverlaySizingTests {

    private typealias Overlay = PatientIdentificationOverlayView

    @Test("Type is legible on a small tile and restrained on a big one")
    func testTypeRange() {
        let tile = Overlay.fontSize(for: CGSize(width: 220, height: 180))
        let full = Overlay.fontSize(for: CGSize(width: 1600, height: 1200))

        #expect(tile >= 5, "a 4×4 tile's caption is still readable")
        #expect(full <= 11, "a full-sheet caption is a caption, not a headline")
        #expect(full > tile)
    }

    @Test("A cell with no size yet still yields a usable type size")
    func testZeroCell() {
        let size = Overlay.fontSize(for: .zero)
        #expect(size >= 5 && size <= 11)
    }

    @Test("A corner block stands on a small share of the picture")
    func testBlocksStayOutOfTheWay() {
        for picture in [CGSize(width: 240, height: 200),
                        CGSize(width: 600, height: 600),
                        CGSize(width: 1600, height: 1200)] {
            // The deepest block the film draws: modality, position and three
            // technique values.
            let block = Overlay.blockHeight(for: picture, lines: 4)
            #expect(block < picture.height * 0.4,
                    "\(picture): a \(block) block on a \(picture.height) picture")
        }
    }

    @Test("A deeper block takes more room than a shallow one, and none takes none")
    func testBlockGrowsWithItsLines() {
        let picture = CGSize(width: 800, height: 800)
        #expect(Overlay.blockHeight(for: picture, lines: 1)
                < Overlay.blockHeight(for: picture, lines: 3))
        #expect(Overlay.blockHeight(for: picture, lines: 0) == 0,
                "nothing to draw stands on nothing")
    }

    @Test("Every line in a cell is set at the one size, long lines included")
    func testOneSizeForTheWholeBlock() {
        let cell = CGSize(width: 300, height: 300)
        let short = PrintCornerAnnotation(topRight: ["DOE, JOHN", "ID 12345"])
        #expect(Overlay.fittedFontSize(for: short, cellSize: cell)
                == Overlay.fontSize(for: cell),
                "lines that fit take the cell's own size")

        let long = PrintCornerAnnotation(
            topRight: ["DOE, JOHN", "ID 12345"],
            bottomLeft: ["CT CHEST ABDOMEN PELVIS WITH CONTRAST — DELAYED PHASE"])
        let fitted = Overlay.fittedFontSize(for: long, cellSize: cell)
        #expect(fitted < Overlay.fontSize(for: cell),
                "one long line steps the whole block down, not itself alone")
        #expect(fitted >= Overlay.fontSize(for: cell) * 0.5,
                "never below half — past that a line truncates instead")
    }
}
#endif
