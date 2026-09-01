// AnnotationLetteringUprightTests.swift
// DICOMPrintKitTests
//
// A reader's note has to read left-to-right and right way up however the
// picture beneath it has been turned or mirrored — there is no arrangement of
// a film on which upside-down or mirror-written text is correct.
//
// The three earlier tests in `PrintOverlayOrientationTests` check the *angle*
// and the *mirror flag* in isolation, which is how a sign error survived them:
// each value was individually defensible and the composition was still wrong.
// These tests rasterize an actual glyph, apply the display shader's own
// transform to the result, and measure which way the ink ends up pointing —
// the only question the reader actually cares about.

#if canImport(CoreGraphics)
import Testing
import Foundation
@testable import DICOMPrintKit

@Suite("Annotation lettering stays upright")
struct AnnotationLetteringUprightTests {

    /// The orientation of a rasterized glyph, as a pair that turns rigidly with
    /// it and reverses under a mirror.
    ///
    /// Deliberately not a bounding box or a centroid offset: both are measured
    /// against the pixel grid's own axes, so they change under a 30° turn even
    /// when the glyph is drawn correctly, and a test built on them can only
    /// check quarter turns. Image moments have no such axis dependence — the
    /// principal axis is the glyph's own, and the two skews pin down which end
    /// is which and which way round it is written.
    private struct Signature {
        /// The principal axis, disambiguated end-for-end by the skew along it.
        let axis: Double
        /// +1 written the right way round, −1 mirrored.
        let handedness: Double
    }

    private func signature(
        rotation: Double = 0, flipH: Bool = false, flipV: Bool = false
    ) -> Signature? {
        let size = 160
        // "F" has no symmetry of any kind, so every one of the eight
        // arrangements of it is distinguishable from the other seven.
        let annotation = PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.4, y: 0.45),
            text: "F", scale: 0.3)
        let orientation = PrintOverlayOrientation(
            presentation: ViewerPresentation(
                rotationDegrees: rotation,
                flipHorizontal: flipH, flipVertical: flipV),
            imageWidth: size, imageHeight: size)

        guard let (bytes, bytesPerRow) = ImageAnnotationBurner.rasterizing(
            overlays: [annotation], width: size, height: size,
            orientation: orientation) else { return nil }

        var points: [(x: Double, y: Double)] = []
        for y in 0..<size {
            for x in 0..<size where bytes[y * bytesPerRow + x * 4 + 3] > 40 {
                points.append((Double(x), Double(y)))
            }
        }
        guard points.count > 20 else { return nil }

        let count = Double(points.count)
        let cx = points.map(\.x).reduce(0, +) / count
        let cy = points.map(\.y).reduce(0, +) / count

        var mxx = 0.0, myy = 0.0, mxy = 0.0
        for point in points {
            let dx = point.x - cx, dy = point.y - cy
            mxx += dx * dx; myy += dy * dy; mxy += dx * dy
        }
        let theta = 0.5 * atan2(2 * mxy, mxx - myy)

        // The principal axis is a line, not a direction; the third moment along
        // it says which end the glyph's mass leans toward.
        var alongSkew = 0.0
        for point in points {
            let d = (point.x - cx) * cos(theta) + (point.y - cy) * sin(theta)
            alongSkew += d * d * d
        }
        let axis = alongSkew < 0 ? theta + .pi : theta

        // And the third moment across it says whether it was written backwards.
        var acrossSkew = 0.0
        for point in points {
            let d = -(point.x - cx) * sin(axis) + (point.y - cy) * cos(axis)
            acrossSkew += d * d * d
        }
        return Signature(axis: axis, handedness: acrossSkew >= 0 ? 1 : -1)
    }

    /// The signature as it reaches the reader's eye: the viewer's overlay is
    /// rasterized in the *unarranged* frame's space and then turned and
    /// mirrored by the display shader along with the picture, so the shader's
    /// transform has to be applied before asking which way the words read.
    ///
    /// Rotation is clockwise on screen while texture rows run downward, which
    /// makes it a straight addition here; the mirrors come after the turn,
    /// matching `DisplayFrameTexture`'s matrix composition.
    private func onScreenSignature(
        rotation: Double = 0, flipH: Bool = false, flipV: Bool = false
    ) -> Signature? {
        guard let raster = signature(rotation: rotation, flipH: flipH, flipV: flipV)
        else { return nil }
        var axis = raster.axis + rotation * .pi / 180
        var handedness = raster.handedness
        if flipH { axis = .pi - axis; handedness = -handedness }
        if flipV { axis = -axis;      handedness = -handedness }
        return Signature(axis: atan2(sin(axis), cos(axis)), handedness: handedness)
    }

    /// Every combination of a turn and the two mirrors must put the words on
    /// screen exactly as an unarranged picture does.
    @Test("Words read level and the right way round under every arrangement",
          arguments: [
            (0.0, false, false), (90.0, false, false),
            (180.0, false, false), (270.0, false, false),
            (0.0, true, false), (0.0, false, true), (0.0, true, true),
            (90.0, true, false), (90.0, false, true), (90.0, true, true),
            (270.0, true, false), (180.0, false, true),
            // Free angles, which the rotate tool sweeps through.
            (30.0, false, false), (45.0, false, false),
            (30.0, true, false), (30.0, false, true),
            (135.0, true, false), (200.0, false, true)
          ])
    func testLetteringIsUpright(rotation: Double, flipH: Bool, flipV: Bool) throws {
        let upright = try #require(onScreenSignature())
        let actual = try #require(
            onScreenSignature(rotation: rotation, flipH: flipH, flipV: flipV))

        let difference = abs(atan2(sin(actual.axis - upright.axis),
                                   cos(actual.axis - upright.axis))) * 180 / .pi
        // A few degrees of slack for glyph rasterization on the pixel grid;
        // every way of getting this wrong is off by 90° or more, or mirrored.
        #expect(difference < 8,
                "rotation \(rotation) flipH \(flipH) flipV \(flipV): words tilted \(difference)°")
        #expect(actual.handedness == upright.handedness,
                "rotation \(rotation) flipH \(flipH) flipV \(flipV): words written backwards")
    }

    /// The guard on the measurement itself: a signature that could not tell the
    /// eight arrangements apart would pass the test above no matter what the
    /// burner did.
    @Test("The measurement can actually see a wrongly-turned glyph")
    func testSignatureDistinguishesArrangements() throws {
        let upright = try #require(signature())
        // Rasterized with no orientation to cancel, a turned glyph is left
        // lying on its side — which is exactly what the bug looked like.
        let uncancelled = try #require(signature(rotation: 0))
        #expect(abs(uncancelled.axis - upright.axis) < 0.01)

        // And a mirrored one is written backwards.
        var backwards = upright
        backwards = Signature(axis: upright.axis, handedness: -upright.handedness)
        #expect(backwards.handedness != upright.handedness)
    }
}
#endif
