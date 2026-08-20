// FilmDisplayGeometryTests.swift
// DICOMRenderKitTests
//
// The film preview draws its cells on the GPU, and a preview of a film is only
// worth having if it composes the way film does.
//
// The viewer's display transform and the printer's composition are different
// answers to different questions — fit-zoom-rotate-pan against a screen, versus
// "crop this rectangle of source pixels, turn it, and fit *that* into the image
// box". They agree while a cell is merely zoomed and nowhere else. So the preview
// uses `DisplayPresentation.sourceRegion`, and these tests are what pin that path
// to the printer's arithmetic: pure geometry, no GPU, so a wrong sign or a swapped
// order fails here rather than by looking subtly wrong on a film.

import XCTest
import simd
@testable import DICOMRenderKit

#if canImport(Metal)

final class FilmDisplayGeometryTests: XCTestCase {

    // MARK: - Helpers

    private func region(_ x: Double, _ y: Double, _ w: Double, _ h: Double)
    -> DisplayPresentation.SourceRegion {
        DisplayPresentation.SourceRegion(x: x, y: y, width: w, height: h)
    }

    private func transform(
        _ presentation: DisplayPresentation,
        image: (Int, Int) = (100, 100),
        view: (Double, Double) = (200, 200)
    ) -> simd_float4x4? {
        presentation.transform(imageWidth: image.0, imageHeight: image.1,
                               viewWidth: view.0, viewHeight: view.1)
    }

    /// Where a point of the source frame, in pixels from its top left, lands in
    /// normalised device coordinates.
    ///
    /// The quad spans ±1 with the image's first row at the top, which is the
    /// mapping `display_vertex` uses (its v coordinates are flipped for exactly
    /// that reason). Everything here is asserted through this, so the tests read
    /// as "this pixel ends up here" rather than as matrix entries.
    private func project(
        _ matrix: simd_float4x4, pixel: (Double, Double), image: (Int, Int)
    ) -> (x: Double, y: Double) {
        let u = Float(2 * pixel.0 / Double(image.0) - 1)
        let v = Float(1 - 2 * pixel.1 / Double(image.1))
        let out = matrix * SIMD4<Float>(u, v, 0, 1)
        return (Double(out.x), Double(out.y))
    }

    // MARK: - Fit

    /// With the whole frame as the region and nothing else set, this is the plain
    /// aspect fit — the preview must not shift a cell that has never been touched.
    func testWholeFrameIsThePlainAspectFit() throws {
        let plain = try XCTUnwrap(transform(.identity, image: (200, 100)))
        let film = try XCTUnwrap(transform(
            DisplayPresentation(sourceRegion: region(0, 0, 200, 100)), image: (200, 100)))

        for column in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(plain[column][row], film[column][row], accuracy: 1e-6,
                               "column \(column) row \(row)")
            }
        }
    }

    /// The region — not the frame — is what fills the view, and it is centred in
    /// it. This is the printer's image box: it is handed a crop, not a viewport.
    func testRegionFillsAndCentresItself() throws {
        let image = (100, 100)
        let matrix = try XCTUnwrap(transform(
            DisplayPresentation(sourceRegion: region(60, 20, 20, 20)), image: image))

        let centre = project(matrix, pixel: (70, 30), image: image)
        XCTAssertEqual(centre.x, 0, accuracy: 1e-6)
        XCTAssertEqual(centre.y, 0, accuracy: 1e-6)

        // A square region in a square view: its corners are the view's corners.
        let topLeft = project(matrix, pixel: (60, 20), image: image)
        let bottomRight = project(matrix, pixel: (80, 40), image: image)
        XCTAssertEqual(topLeft.x, -1, accuracy: 1e-6)
        XCTAssertEqual(topLeft.y, 1, accuracy: 1e-6)
        XCTAssertEqual(bottomRight.x, 1, accuracy: 1e-6)
        XCTAssertEqual(bottomRight.y, -1, accuracy: 1e-6)
    }

    /// A crop clamped by the edge of the frame is *centred*, exactly as the
    /// printer centres it — not left lying against one side of the cell the way
    /// the viewer leaves a picture panned off its edge.
    func testClampedRegionIsCentredNotPushedAside() throws {
        let image = (100, 100)
        let matrix = try XCTUnwrap(transform(
            DisplayPresentation(sourceRegion: region(0, 0, 40, 40)), image: image))

        let centre = project(matrix, pixel: (20, 20), image: image)
        XCTAssertEqual(centre.x, 0, accuracy: 1e-6)
        XCTAssertEqual(centre.y, 0, accuracy: 1e-6)
    }

    // MARK: - Rotation

    /// A quarter turn changes the shape being fitted: a wide crop becomes a tall
    /// one, and the fit is of the *turned* rectangle. Fitting before the turn — the
    /// viewer's order — would leave the picture at the wrong size on the film.
    func testQuarterTurnFitsTheTurnedRectangle() throws {
        let image = (200, 200)
        let matrix = try XCTUnwrap(transform(
            DisplayPresentation(rotationDegrees: 90, sourceRegion: region(0, 0, 200, 100)),
            image: image))

        // 200×100 turned is 100 wide by 200 tall; in a square view that is
        // height-limited, so it spans the full height and half the width.
        let corners = [(0.0, 0.0), (200.0, 0.0), (0.0, 100.0), (200.0, 100.0)]
            .map { project(matrix, pixel: $0, image: image) }
        XCTAssertEqual(corners.map(\.x).min() ?? 0, -0.5, accuracy: 1e-6)
        XCTAssertEqual(corners.map(\.x).max() ?? 0, 0.5, accuracy: 1e-6)
        XCTAssertEqual(corners.map(\.y).min() ?? 0, -1, accuracy: 1e-6)
        XCTAssertEqual(corners.map(\.y).max() ?? 0, 1, accuracy: 1e-6)
    }

    /// The turn is clockwise on screen: the crop's top-left corner ends up top
    /// right. A sign slip here turns every rotated film cell the wrong way.
    func testQuarterTurnIsClockwise() throws {
        let image = (100, 100)
        let matrix = try XCTUnwrap(transform(
            DisplayPresentation(rotationDegrees: 90, sourceRegion: region(0, 0, 100, 100)),
            image: image))

        let topLeft = project(matrix, pixel: (0, 0), image: image)
        XCTAssertEqual(topLeft.x, 1, accuracy: 1e-6)
        XCTAssertEqual(topLeft.y, 1, accuracy: 1e-6)
    }

    // MARK: - Flip

    /// Flips come *after* the rotation, which is the order `PrintPresentationTransform`
    /// applies them in on the film and `FrameRenderer.applying` on the CPU cell. On a
    /// quarter turn the other order is a different picture, so this is asserted as a
    /// mirror in view space: the same pixel, with x negated and y untouched.
    func testFlipIsAppliedAfterRotation() throws {
        let image = (100, 100)
        let turned = try XCTUnwrap(transform(
            DisplayPresentation(rotationDegrees: 90, sourceRegion: region(0, 0, 100, 100)),
            image: image))
        let turnedAndFlipped = try XCTUnwrap(transform(
            DisplayPresentation(rotationDegrees: 90, flipHorizontal: true,
                                sourceRegion: region(0, 0, 100, 100)),
            image: image))

        let plain = project(turned, pixel: (10, 30), image: image)
        let flipped = project(turnedAndFlipped, pixel: (10, 30), image: image)
        XCTAssertEqual(flipped.x, -plain.x, accuracy: 1e-6)
        XCTAssertEqual(flipped.y, plain.y, accuracy: 1e-6)
    }

    // MARK: - Free angles keep their scale

    /// A freely turned cell must not shrink.
    ///
    /// The film path used to fit the *turned bounding box* into the cell, so a
    /// square picture turned 45° was drawn at 1/√2 — 71% — of the size it had at
    /// 0°, and grew back to full size by 90°. On a sheet of otherwise identical
    /// cells that reads as the rotate tool having zoomed the picture out, and it
    /// is worst at the small angles used to straighten a tilted head.
    ///
    /// So the scale is now the quarter-turn scale at every angle: the picture
    /// turns about its centre at the size it already had, and the corners that
    /// swing outside the cell are cut, exactly as the viewer does it.
    func testFreeAngleKeepsTheUnrotatedScale() throws {
        let image = (100, 100)
        let square = region(0, 0, 100, 100)

        // How far the centre of the top edge sits from the middle, unturned.
        let upright = try XCTUnwrap(transform(
            DisplayPresentation(sourceRegion: square), image: image))
        let reference = project(upright, pixel: (50, 0), image: image)
        let radius = abs(Double(reference.y))
        XCTAssertGreaterThan(radius, 0)

        // The same point, turned. Its distance from the centre is the picture's
        // scale, and a turn about the centre must not change it.
        for angle in [10.0, 20, 30, 45, 60, 80] {
            let turned = try XCTUnwrap(transform(
                DisplayPresentation(rotationDegrees: angle, sourceRegion: square),
                image: image))
            let point = project(turned, pixel: (50, 0), image: image)
            let distance = (Double(point.x) * Double(point.x)
                            + Double(point.y) * Double(point.y)).squareRoot()
            XCTAssertEqual(distance, radius, accuracy: 1e-5,
                           "a \(angle)° turn must not resize the picture")
        }
    }

    /// The corners are what a constant scale spends: at 45° they leave the cell.
    ///
    /// The other half of the contract above — this is the cost the choice
    /// accepts, and pinning it stops a well-meaning "fix" from quietly bringing
    /// the shrink back to reclaim them.
    func testFreeAngleLetsTheCornersLeaveTheCell() throws {
        let image = (100, 100)
        let turned = try XCTUnwrap(transform(
            DisplayPresentation(rotationDegrees: 45, sourceRegion: region(0, 0, 100, 100)),
            image: image))

        // A corner of the frame, turned 45°, sits outside the cell's own edges
        // (|NDC| > 1) — it is cropped rather than scaled down to fit.
        let corner = project(turned, pixel: (0, 0), image: image)
        XCTAssertGreaterThan(max(abs(Double(corner.x)), abs(Double(corner.y))), 1.0)
    }

    // MARK: - Degenerate input

    /// Nothing here may divide by zero: a zero-sized region or view answers nil, so
    /// a blank cell is a detectable state rather than a silently empty draw. This
    /// codebase has already shipped one viewer that blanked every J2K preview that
    /// way.
    func testDegenerateInputReturnsNil() {
        XCTAssertNil(transform(DisplayPresentation(sourceRegion: region(0, 0, 0, 40))))
        XCTAssertNil(transform(DisplayPresentation(sourceRegion: region(0, 0, 40, 0))))
        XCTAssertNil(transform(DisplayPresentation(sourceRegion: region(0, 0, 40, 40)),
                               image: (0, 100)))
        XCTAssertNil(transform(DisplayPresentation(sourceRegion: region(0, 0, 40, 40)),
                               view: (200, 0)))
    }

    /// The region path ignores zoom and pan rather than compounding them: the
    /// region already *is* where the zoom and pan ended up, and applying both
    /// would crop twice.
    func testRegionIgnoresZoomAndPan() throws {
        let image = (100, 100)
        let plain = try XCTUnwrap(transform(
            DisplayPresentation(sourceRegion: region(20, 20, 40, 40)), image: image))
        let withTools = try XCTUnwrap(transform(
            DisplayPresentation(zoom: 3, panX: 25, panY: -10,
                                sourceRegion: region(20, 20, 40, 40)),
            image: image))

        for column in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(plain[column][row], withTools[column][row], accuracy: 1e-6)
            }
        }
    }

    // MARK: - Stretch

    /// Stretch pulls the composed picture to the view's edges on each axis
    /// independently — the film's stretch mode, which distorts and does not crop.
    /// A wide region in a square view therefore spans the whole view, not the
    /// letterboxed band the fit leaves.
    func testStretchPullsThePictureToTheViewEdges() throws {
        let image = (200, 100)
        let matrix = try XCTUnwrap(transform(
            DisplayPresentation(sourceRegion: region(0, 0, 200, 100),
                                stretchToFill: true),
            image: image))

        let topLeft = project(matrix, pixel: (0, 0), image: image)
        let bottomRight = project(matrix, pixel: (200, 100), image: image)
        XCTAssertEqual(topLeft.x, -1, accuracy: 1e-5)
        XCTAssertEqual(topLeft.y, 1, accuracy: 1e-5)
        XCTAssertEqual(bottomRight.x, 1, accuracy: 1e-5)
        XCTAssertEqual(bottomRight.y, -1, accuracy: 1e-5)
    }

    /// Stretch acts on the *turned* picture: rotate a wide crop a quarter turn
    /// and it is the tall result that is pulled to the edges — the same order
    /// the printer-side composition uses. Stretching before the turn would
    /// shear, not stretch.
    func testStretchStretchesTheTurnedPicture() throws {
        let image = (200, 100)
        let matrix = try XCTUnwrap(transform(
            DisplayPresentation(rotationDegrees: 90,
                                sourceRegion: region(0, 0, 200, 100),
                                stretchToFill: true),
            image: image))

        // Wherever the four corners land, together they must span the view.
        let corners = [(0.0, 0.0), (200.0, 0.0), (0.0, 100.0), (200.0, 100.0)]
            .map { project(matrix, pixel: $0, image: image) }
        XCTAssertEqual(corners.map(\.x).min() ?? 0, -1, accuracy: 1e-5)
        XCTAssertEqual(corners.map(\.x).max() ?? 0, 1, accuracy: 1e-5)
        XCTAssertEqual(corners.map(\.y).min() ?? 0, -1, accuracy: 1e-5)
        XCTAssertEqual(corners.map(\.y).max() ?? 0, 1, accuracy: 1e-5)
    }

    /// Without a region the flag is inert: stretch is the film's mode, and the
    /// viewer — which never sets a region — must be unaffected by it.
    func testStretchWithoutRegionDoesNothing() throws {
        let plain = try XCTUnwrap(transform(.identity, image: (200, 100)))
        let flagged = try XCTUnwrap(transform(
            DisplayPresentation(stretchToFill: true), image: (200, 100)))

        for column in 0..<4 {
            for row in 0..<4 {
                XCTAssertEqual(plain[column][row], flagged[column][row], accuracy: 1e-6)
            }
        }
    }

    // MARK: - The mask rectangle

    /// The crop the fragment shader masks to, in texture coordinates, with half
    /// a texel of slack — the outward rounding the CPU crop also performs. The
    /// slack is what keeps a fill-scaled cell's border pixel from flickering
    /// black when the mask edge lands exactly on the view edge.
    func testSourceRegionUVCarriesTheCropWithHalfATexelOfSlack() {
        let presentation = DisplayPresentation(sourceRegion: region(60, 20, 20, 20))
        let uv = presentation.sourceRegionUV(imageWidth: 100, imageHeight: 100)
        XCTAssertEqual(uv.x, 0.6 - 0.005, accuracy: 1e-6)
        XCTAssertEqual(uv.y, 0.2 - 0.005, accuracy: 1e-6)
        XCTAssertEqual(uv.z, 0.8 + 0.005, accuracy: 1e-6)
        XCTAssertEqual(uv.w, 0.4 + 0.005, accuracy: 1e-6)
    }

    /// No region — the viewer's path — answers the whole frame, which is the
    /// mask's off switch. A full-frame region clamps to the same answer.
    func testSourceRegionUVIsTheWholeFrameWhenThereIsNoCrop() {
        let none = DisplayPresentation.identity
            .sourceRegionUV(imageWidth: 100, imageHeight: 100)
        XCTAssertEqual(none, SIMD4<Float>(0, 0, 1, 1))

        let whole = DisplayPresentation(sourceRegion: region(0, 0, 100, 100))
            .sourceRegionUV(imageWidth: 100, imageHeight: 100)
        XCTAssertEqual(whole, SIMD4<Float>(0, 0, 1, 1))
    }
}

#endif
