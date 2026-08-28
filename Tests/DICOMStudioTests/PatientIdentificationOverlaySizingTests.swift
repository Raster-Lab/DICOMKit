// PatientIdentificationOverlaySizingTests.swift
// DICOMStudioTests
//
// The identification band under an image: how deep it is, and how big the type
// inside it is.
//
// The property under test throughout: the band is sized from the cell and the
// type is fitted into the band — never the other way round, which is what made
// a full-screen image reserve a strip deep enough to notice.

#if canImport(SwiftUI)
import Testing
@testable import DICOMStudio
import Foundation
import CoreGraphics

@Suite("Patient Identification Overlay Sizing Tests")
struct PatientIdentificationOverlaySizingTests {

    private typealias Overlay = PatientIdentificationOverlayView

    @Test("Two lines of type fit inside the band that was reserved for them")
    func testTypeFitsTheBand() {
        for cell in [CGSize(width: 240, height: 200),
                     CGSize(width: 600, height: 600),
                     CGSize(width: 1600, height: 1200)] {
            let band = Overlay.bandHeight(for: cell, lines: 2)
            let size = Overlay.fontSize(for: cell, lines: 2)
            // Line boxes + the gap between them + the band's own padding.
            let needed = 2 * size * 1.2 + size * 0.25 + size * 0.6
            #expect(needed <= band + 0.01,
                    "\(cell): \(needed) of type in a \(band) band")
        }
    }

    @Test("The band is a small share of the image, whatever the image size")
    func testBandStaysOutOfTheWay() {
        let small = Overlay.bandHeight(for: CGSize(width: 200, height: 200))
        let large = Overlay.bandHeight(for: CGSize(width: 1600, height: 1400))

        #expect(small <= 200 * 0.12)
        // The cap is the point: a caption on a full-screen image must not grow
        // in proportion with the picture.
        #expect(large <= 40.5)
        #expect(large >= small, "a bigger cell never gets a shallower band")
    }

    @Test("Type is legible on a small tile and restrained on a big one")
    func testTypeRange() {
        let tile = Overlay.fontSize(for: CGSize(width: 220, height: 180))
        let full = Overlay.fontSize(for: CGSize(width: 1600, height: 1200))

        #expect(tile >= 6, "a 4×4 tile's caption is still readable")
        #expect(full <= 13, "a full-screen caption is a caption, not a headline")
        #expect(full > tile)
    }

    @Test("A single line gets a shallower band than two")
    func testOneLineBand() {
        let cell = CGSize(width: 800, height: 800)
        #expect(Overlay.bandHeight(for: cell, lines: 1)
                < Overlay.bandHeight(for: cell, lines: 2))
        #expect(Overlay.bandHeight(for: cell, lines: 0) == 0,
                "nothing to draw reserves nothing")
    }

    @Test("A cell with no size yet still yields a usable type size")
    func testZeroCell() {
        let size = Overlay.fontSize(for: .zero)
        #expect(size >= 6 && size <= 13)
    }

    @Test("A wide, short cell is sized by its height, not its width")
    func testWideShortCell() {
        // Sizing on width alone gave a letterbox tile oversized type that then
        // had to be shrunk by minimumScaleFactor to fit.
        let wide = Overlay.fontSize(for: CGSize(width: 1600, height: 200))
        let square = Overlay.fontSize(for: CGSize(width: 1600, height: 1600))
        #expect(wide < square)
    }
}
#endif
