// PrintOverlayAnnotationTests.swift
// DICOMPrintKitTests
//
// The text and arrows a reader draws on a film cell, and their burn into pixels.
//
// The properties under test: an annotation's coordinates stay inside the image
// however they were produced, a blank annotation draws nothing, and what is drawn
// lands where the fractions say it should — because those same fractions position
// the preview overlay, and film disagreeing with preview is the whole failure this
// design exists to prevent.

#if canImport(CoreGraphics)
import Testing
@testable import DICOMPrintKit
import DICOMNetwork
import Foundation

@Suite("Print Overlay Annotation Tests")
struct PrintOverlayAnnotationTests {

    private func frame(
        width: Int = 128,
        height: Int = 128,
        samples: Int = 1,
        photometric: String = "MONOCHROME2",
        fill: UInt8 = 0
    ) -> PreparedPrintImage {
        PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: Data(repeating: fill, count: width * height * samples),
                rows: UInt16(height),
                columns: UInt16(width),
                bitsAllocated: 8,
                bitsStored: 8,
                highBit: 7,
                samplesPerPixel: UInt16(samples),
                pixelRepresentation: 0,
                photometricInterpretation: photometric
            ),
            sourcePath: "/a.dcm",
            frameIndex: 0)
    }

    /// Rows of a grayscale frame that the burn changed.
    private func changedRows(_ before: PreparedPrintImage, _ after: PreparedPrintImage,
                             width: Int, height: Int) -> [Int] {
        let old = [UInt8](before.descriptor.pixelData)
        let new = [UInt8](after.descriptor.pixelData)
        return (0..<height).filter { row in
            (0..<width).contains { old[row * width + $0] != new[row * width + $0] }
        }
    }

    // MARK: - The model

    @Test("Coordinates are clamped into the image")
    func testClampsPoints() {
        let point = PrintOverlayPoint(x: 1.4, y: -0.3)
        #expect(point.x == 1)
        #expect(point.y == 0)

        // Non-finite values come from divisions by a zero-sized cell during
        // layout, and must not poison an annotation's position.
        #expect(PrintOverlayPoint(x: .nan, y: .infinity).x == 0)
    }

    @Test("Moving an annotation keeps it in the image and keeps an arrow's shape")
    func testMoving() {
        let arrow = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.4, y: 0.4),
            end: PrintOverlayPoint(x: 0.6, y: 0.5))
        let moved = arrow.moved(dx: 0.1, dy: -0.1)
        #expect(abs(moved.start.x - 0.5) < 0.0001)
        #expect(abs(moved.end.x - 0.7) < 0.0001)
        // Same vector, so the arrow still points the same way.
        #expect(abs((moved.end.x - moved.start.x) - (arrow.end.x - arrow.start.x)) < 0.0001)

        // Pushed off the edge, the leading end stops at the edge — an annotation
        // outside the image has no pixels to be burned into.
        let pushed = arrow.moved(dx: 0.9, dy: 0)
        #expect(pushed.end.x == 1)
    }

    @Test("Size is held between a readable floor and a covering ceiling")
    func testScaleClamped() {
        #expect(PrintOverlayAnnotation(kind: .text, start: .init(x: 0, y: 0), scale: 5).scale
                == PrintOverlayAnnotation.maximumScale)
        #expect(PrintOverlayAnnotation(kind: .text, start: .init(x: 0, y: 0), scale: 0).scale
                == PrintOverlayAnnotation.minimumScale)
        #expect(PrintOverlayAnnotation.clampScale(.nan) == PrintOverlayAnnotation.defaultScale)
    }

    @Test("Empty text and zero-length arrows are blank")
    func testBlank() {
        #expect(PrintOverlayAnnotation(kind: .text, start: .init(x: 0.5, y: 0.5),
                                       text: "   ").isBlank)
        #expect(!PrintOverlayAnnotation(kind: .text, start: .init(x: 0.5, y: 0.5),
                                        text: "LAD").isBlank)
        // A click with the arrow tool is not a drawing.
        #expect(PrintOverlayAnnotation(kind: .arrow, start: .init(x: 0.5, y: 0.5),
                                       end: .init(x: 0.502, y: 0.5)).isBlank)
        #expect(!PrintOverlayAnnotation(kind: .arrow, start: .init(x: 0.2, y: 0.2),
                                        end: .init(x: 0.8, y: 0.8)).isBlank)
    }

    @Test("Luminance is what a colour becomes on a greyscale printer")
    func testLuminance() {
        // The three weights sum to one, give or take the last binary digit.
        #expect(abs(PrintOverlayColor.white.luminance - 1) < 0.0001)
        // Yellow is bright — which is why it is the default on greyscale film.
        #expect(PrintOverlayColor.yellow.luminance > 0.8)
        #expect(PrintOverlayColor(red: 0, green: 0, blue: 0).luminance == 0)
    }

    // MARK: - Burning

    @Test("Text is burned where its fractions say, not at the bottom")
    func testTextBurnsAtItsOwnPosition() {
        let original = frame()
        let annotation = PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.1, y: 0.1),
            text: "LAD",
            scale: 0.1)
        let burned = ImageAnnotationBurner.burning(overlays: [annotation], into: original)

        let rows = changedRows(original, burned, width: 128, height: 128)
        #expect(!rows.isEmpty)
        // Anchored at 10% down with type 10% of the height: everything drawn
        // belongs in the top third, nowhere near the caption band at the bottom.
        #expect(rows.allSatisfy { $0 < 43 })
    }

    @Test("On a turned cell an annotation is burned where the anatomy went")
    func testBurnFollowsAQuarterTurn() {
        // The frame handed to the burner has already been turned, so an
        // annotation drawn near the top-left of the *image* belongs near the
        // top-right of the frame. Without the arrangement the burn used the
        // raw fraction and put it back at the top-left, on different anatomy.
        let original = frame()
        let annotation = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.1, y: 0.1),
            end: PrintOverlayPoint(x: 0.1, y: 0.3))
        let orientation = PrintOverlayOrientation(
            presentation: ViewerPresentation(rotationDegrees: 90),
            imageWidth: 128, imageHeight: 128)

        let burned = ImageAnnotationBurner.burning(
            overlays: [annotation], into: original, orientation: orientation)
        let pixels = [UInt8](burned.descriptor.pixelData)

        // A quarter turn clockwise sends the top-left of the image to the
        // top-right of the frame, so that is the half the marks are in.
        func drawn(columns: Range<Int>, rows: Range<Int>) -> Bool {
            rows.contains { row in columns.contains { pixels[row * 128 + $0] != 0 } }
        }
        #expect(drawn(columns: 64..<128, rows: 0..<64))
        #expect(!drawn(columns: 0..<40, rows: 0..<128))
    }

    @Test("An unturned cell burns exactly where it always did")
    func testAnIdentityOrientationChangesNothing() {
        // The arrangement is threaded through every burn now, so the common
        // case — an untouched cell — has to come out byte for byte as before,
        // or every existing film changes.
        let original = frame()
        let annotation = PrintOverlayAnnotation(
            kind: .text,
            start: PrintOverlayPoint(x: 0.1, y: 0.1),
            text: "LAD",
            scale: 0.1)

        let withoutOrientation = ImageAnnotationBurner.burning(
            overlays: [annotation], into: original)
        let withIdentity = ImageAnnotationBurner.burning(
            overlays: [annotation], into: original,
            orientation: .identity(imageWidth: 128, imageHeight: 128))

        #expect(withoutOrientation.descriptor.pixelData
                == withIdentity.descriptor.pixelData)
    }

    @Test("An arrow is burned along the line it was drawn on")
    func testArrowBurnsAlongItsLine() {
        let original = frame()
        let arrow = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.5),
            end: PrintOverlayPoint(x: 0.8, y: 0.5))
        let burned = ImageAnnotationBurner.burning(overlays: [arrow], into: original)

        let rows = changedRows(original, burned, width: 128, height: 128)
        #expect(!rows.isEmpty)
        // A horizontal arrow across the middle: nothing drawn near either edge.
        #expect(rows.allSatisfy { $0 > 40 && $0 < 88 })

        // And it is drawn in the horizontal band it was aimed along.
        let pixels = [UInt8](burned.descriptor.pixelData)
        let middleRow = 64
        let leftEdge = (0..<10).contains { pixels[middleRow * 128 + $0] != 0 }
        #expect(!leftEdge)
    }

    @Test("Blank annotations leave the pixels alone")
    func testBlankBurnsNothing() {
        let original = frame()
        let blank = [
            PrintOverlayAnnotation(kind: .text, start: .init(x: 0.5, y: 0.5), text: ""),
            PrintOverlayAnnotation(kind: .arrow, start: .init(x: 0.5, y: 0.5),
                                   end: .init(x: 0.5, y: 0.5))
        ]
        #expect(ImageAnnotationBurner.burning(overlays: blank, into: original)
                .descriptor.pixelData == original.descriptor.pixelData)
        #expect(ImageAnnotationBurner.burning(overlays: [], into: original)
                .descriptor.pixelData == original.descriptor.pixelData)
    }

    @Test("A colour annotation survives a colour frame and a greyscale frame")
    func testBurnsIntoBothFormats() {
        let arrow = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.2, y: 0.2),
            end: PrintOverlayPoint(x: 0.8, y: 0.8),
            color: .red)

        let gray = frame()
        #expect(ImageAnnotationBurner.burning(overlays: [arrow], into: gray)
                .descriptor.pixelData != gray.descriptor.pixelData)

        let color = frame(samples: 3, photometric: "RGB")
        let burnedColor = ImageAnnotationBurner.burning(overlays: [arrow], into: color)
        #expect(burnedColor.descriptor.pixelData != color.descriptor.pixelData)
        // Still three samples per pixel and the same size: the RGB path widens to
        // RGBA to draw and has to pack back down.
        #expect(burnedColor.descriptor.pixelData.count == color.descriptor.pixelData.count)
        #expect(burnedColor.descriptor.samplesPerPixel == 3)
    }

    @Test("A frame this cannot write into comes back untouched")
    func testRefusesUnsupportedFrames() {
        let annotation = PrintOverlayAnnotation(
            kind: .text, start: .init(x: 0.5, y: 0.5), text: "LAD")

        // Short of the pixels its own descriptor claims.
        let short = PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: Data(repeating: 0, count: 10),
                rows: 128, columns: 128, bitsAllocated: 8, bitsStored: 8, highBit: 7,
                samplesPerPixel: 1, pixelRepresentation: 0,
                photometricInterpretation: "MONOCHROME2"),
            sourcePath: "/a.dcm", frameIndex: 0)
        #expect(ImageAnnotationBurner.burning(overlays: [annotation], into: short)
                .descriptor.pixelData == short.descriptor.pixelData)
    }

    @Test("On MONOCHROME1 a bright colour is burned as a low value")
    func testInvertedPhotometric() {
        // MONOCHROME1's maximum value is black, so white text has to be written
        // as a *low* value or it disappears into the background.
        let white = PrintOverlayAnnotation(
            kind: .text, start: .init(x: 0.1, y: 0.2), text: "LAD",
            scale: 0.15, color: .white)
        let inverted = frame(photometric: "MONOCHROME1", fill: 255)
        let burned = ImageAnnotationBurner.burning(overlays: [white], into: inverted)
        let pixels = [UInt8](burned.descriptor.pixelData)
        #expect(pixels.contains { $0 < 128 })
    }

    // MARK: - Arrow geometry

    @Test("An arrow's head is unmistakably wider than its shaft")
    func testArrowHeadReadsAsAHead() {
        // The complaint this guards: a head only a little wider than the line
        // reads as a plain line with a dot on the end. Both the preview overlay
        // and the burn take these numbers, so one assertion covers both.
        let geometry = PrintArrowGeometry(
            scale: PrintOverlayAnnotation.defaultScale, imageHeight: 512, arrowLength: 200)
        #expect(geometry.headHalfWidth * 2 > geometry.lineWidth * 5)
        #expect(geometry.headLength > geometry.lineWidth * 3)
    }

    @Test("A short arrow keeps a shaft — the head never swallows it")
    func testShortArrowKeepsShaft() {
        let length = 12.0
        let geometry = PrintArrowGeometry(scale: 0.2, imageHeight: 512, arrowLength: length)
        #expect(geometry.headLength < length)

        let outline = geometry.outline(tail: PrintPlanePoint(x: 0, y: 0),
                                       head: PrintPlanePoint(x: length, y: 0))
        // The shaft stops short of the point rather than collapsing onto it.
        #expect(outline?.shaftEnd.x ?? 0 > 0)
        #expect((outline?.shaftEnd.x ?? 0) < length)
    }

    @Test("An arrow of no length draws nothing")
    func testZeroLengthArrowHasNoOutline() {
        let geometry = PrintArrowGeometry(scale: 0.04, imageHeight: 512, arrowLength: 0)
        #expect(geometry.outline(tail: PrintPlanePoint(x: 10, y: 10),
                                 head: PrintPlanePoint(x: 10, y: 10)) == nil)
    }

    @Test("An arrow burns pixels along its whole length, head included")
    func testArrowBurnsHeadAndShaft() {
        // An explicit scale rather than the default: this pins the head/shaft
        // geometry, and the default (now 2%) is thin enough on this small test
        // frame that antialiasing levels the two sampled columns.
        let arrow = PrintOverlayAnnotation(
            kind: .arrow, start: .init(x: 0.2, y: 0.5), end: .init(x: 0.8, y: 0.5),
            scale: 0.04, color: .white)
        let burned = ImageAnnotationBurner.burning(
            overlays: [arrow], into: frame(photometric: "MONOCHROME2", fill: 0))
        let pixels = [UInt8](burned.descriptor.pixelData)
        let width = Int(burned.descriptor.columns)

        // The head end is wider across than the shaft: count lit rows in a column
        // just behind the point, and in a column back along the shaft. The
        // threshold is well under white because a hairline shaft lands
        // antialiased across two rows on a small frame.
        func litRows(atColumn column: Int) -> Int {
            (0..<Int(burned.descriptor.rows)).count { y in
                pixels[y * width + column] > 64
            }
        }
        let shaftColumn = Int(Double(width) * 0.3)
        let headColumn = Int(Double(width) * 0.76)
        #expect(litRows(atColumn: shaftColumn) > 0)
        #expect(litRows(atColumn: headColumn) > litRows(atColumn: shaftColumn))
    }
}
#endif
