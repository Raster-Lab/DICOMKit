// PatientIdentificationOverlaySizingTests.swift
// DICOMStudioTests
//
// The identification in a film cell's corners: how big the type is, and how much
// of the picture a corner block stands on.
//
// The property under test throughout: the type is scaled from the cell it is
// drawn in by the *same* fractions ``ImageAnnotationBurner`` sets the film's
// caption at, so what the reader approves on screen is the size the printer
// lays down. The preview used to carry its own fractions and an 11 pt ceiling,
// which on a full-sheet film drew the caption at half the size the film got.

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

    @Test("Type is legible on a small tile and grows with the cell")
    func testTypeRange() {
        let tile = Overlay.fontSize(for: CGSize(width: 220, height: 180))
        let full = Overlay.fontSize(for: CGSize(width: 1600, height: 1200))

        #expect(tile >= 5, "a 4×4 tile's caption is still readable")
        #expect(full > tile, "a bigger cell carries bigger type, as the film does")
    }

    @Test("A cell with no size yet still yields a usable type size")
    func testZeroCell() {
        let size = Overlay.fontSize(for: .zero)
        #expect(size >= 5)
    }

    /// The whole point of the shared fractions: at any cell size above the
    /// floors, the caption occupies the same share of the cell on screen as it
    /// does of the frame on film. A preview set at a different size is a
    /// preview that cannot be used to judge the film.
    @Test("The preview sets the caption at exactly the film's proportion")
    func testPreviewMatchesTheFilm() {
        for cell in [CGSize(width: 576, height: 700),
                     CGSize(width: 741, height: 900),
                     CGSize(width: 1235, height: 1500)] {
            let preview = Double(Overlay.fontSize(for: cell)) / Double(cell.height)
            // The burner's size for a frame of the same shape — the padded
            // frame a fitted cell is letterboxed into before the burn.
            let frameWidth = 2800
            let frameHeight = Int((Double(frameWidth) * Double(cell.height / cell.width)).rounded())
            let film = ImageAnnotationBurner.captionFontSize(
                width: frameWidth, height: frameHeight) / Double(frameHeight)

            #expect(abs(preview - film) < 0.0005,
                    "cell \(cell): preview sets \(preview * 100)% of the cell where film sets \(film * 100)% of the frame")
        }
    }

    // MARK: - One face, everywhere text is drawn

    /// The caption is *measured* in the burner's face to decide where a block
    /// has to shrink, so it must be *set* in that face too. It used to be drawn
    /// in the system font: the block was then measured in one face and rendered
    /// in another, and a long study description could fit on screen while
    /// overrunning its corner on film — the one thing the preview exists to
    /// catch.
    @Test("The caption is set in the face the film burns, not the system font")
    func testCaptionUsesTheFilmsFace() {
        #expect(PrintAnnotationStyle.automatic.fontFamily
                == PrintAnnotationStyle.defaultFontFamily)
        // A job that names its own face is previewed in that face, so the
        // shrink decision on screen describes the film that will come out.
        let styled = PrintAnnotationStyle(fontFamily: "Courier")
        let corners = PrintCornerAnnotation(
            topRight: ["PATIENT, A VERY LONG NAME INDEED", "ID 123456"])
        let cell = CGSize(width: 400, height: 500)
        let inHelvetica = Overlay.fittedFontSize(for: corners, cellSize: cell)
        let inCourier = Overlay.fittedFontSize(for: corners, cellSize: cell, style: styled)
        #expect(inHelvetica != inCourier,
                "a wider face shrinks the block sooner — the preview must see that")
    }

    /// A job that sets its own caption size is previewed at that size: the
    /// fraction means the same thing on the cell as it does on the frame.
    @Test("A custom caption size reaches the preview")
    func testCustomCaptionSizeIsPreviewed() {
        let cell = CGSize(width: 800, height: 1000)
        let styled = PrintAnnotationStyle(sizeFraction: 0.06)

        let previewed = Double(Overlay.fontSize(for: cell, style: styled))
        #expect(abs(previewed / Double(cell.height) - 0.06) < 0.0005,
                "6% of the cell, as the burner takes 6% of the frame")
        #expect(previewed > Double(Overlay.fontSize(for: cell)),
                "and larger than the automatic size it overrode")
    }

    /// The reader's own drawn text is bold on film, and the preview, the
    /// viewer's Metal overlay and the saved film all draw it through the same
    /// named face. Four renderers, one literal.
    @Test("Drawn text uses one face and one size rule everywhere")
    func testDrawnTextFaceAndSizeAreShared() {
        #expect(ImageAnnotationBurner.overlayFontFamily == "Helvetica-Bold")
        #expect(ImageAnnotationBurner.overlayFontFamily
                != PrintAnnotationStyle.defaultFontFamily,
                "the reader's text carries emphasis the caption deliberately does not")

        // The size is a fraction of the picture's height, so the same
        // annotation reads the same on a preview cell and in a printed frame.
        let scale = PrintOverlayAnnotation.defaultScale
        let onScreen = ImageAnnotationBurner.overlayFontSize(imageHeight: 500, scale: scale)
        let onFilm = ImageAnnotationBurner.overlayFontSize(imageHeight: 3000, scale: scale)
        #expect(abs(onScreen / 500 - onFilm / 3000) < 0.0001,
                "one fraction of the picture, whatever it is drawn into")
        #expect(onFilm > onScreen)

        // The floor still applies, so a thumbnail's text never renders as a
        // smear of pixels.
        #expect(ImageAnnotationBurner.overlayFontSize(imageHeight: 10, scale: scale)
                == ImageAnnotationBurner.minimumFontSize)
    }

    /// The floors are in different units — points on screen, pixels on film —
    /// so a tiny cell is the one place the two legitimately diverge.
    @Test("A tile too small for the film's floor still gets readable type")
    func testSmallTileKeepsItsFloor() {
        #expect(Overlay.fontSize(for: CGSize(width: 60, height: 50)) == 5)
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
