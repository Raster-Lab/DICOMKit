// AnnotationLabelOrbitTests.swift
// DICOMStudioTests
//
// Swinging a combined annotation's label around the point its arrow names.
//
// While an annotation is first drawn, the drag itself aims the label out of
// the anchor. Re-selecting one used to offer only the two straight drags —
// move the whole thing, or move one end — so the circling was available for
// the length of one gesture and never again. The orbit handle restores it, and
// these pin the two things that make it feel right: the distance to the anchor
// is held, and a circle on screen stays a circle on a non-square image.

import Testing
import Foundation
import DICOMPrintKit
@testable import DICOMStudio

@MainActor
@Suite("Annotation label orbit")
struct AnnotationLabelOrbitTests {

    private let key = ImageAnnotationKey(filePath: "/tmp/orbit.dcm", frameIndex: 0)

    /// A model holding one combined annotation whose label sits `radius` to the
    /// right of its anchor, in fractions of a square image.
    private func model(
        labelAt label: PrintOverlayPoint = PrintOverlayPoint(x: 0.7, y: 0.5),
        anchorAt anchor: PrintOverlayPoint = PrintOverlayPoint(x: 0.5, y: 0.5)
    ) -> (PrintSelectionModel, UUID) {
        let model = PrintSelectionModel()
        let id = model.addAnnotation(forKey: key, at: label, anchor: anchor)
        return (model, id)
    }

    private func annotation(_ model: PrintSelectionModel, _ id: UUID)
        -> PrintOverlayAnnotation? {
        model.annotations(forKey: key).first { $0.id == id }
    }

    /// The distance from label to anchor, in pixels of a `width` × `height`
    /// image — the thing an orbit must not change.
    private func radius(
        _ annotation: PrintOverlayAnnotation, width: Double, height: Double
    ) -> Double {
        let dx = (annotation.start.x - annotation.end.x) * width
        let dy = (annotation.start.y - annotation.end.y) * height
        return (dx * dx + dy * dy).squareRoot()
    }

    @Test("The label swings to the direction asked for, anchor unmoved")
    func testOrbitAimsTheLabel() throws {
        let (model, id) = model()
        let before = try #require(annotation(model, id))

        // Straight up, in image coordinates — y runs downward.
        model.orbitAnnotationLabel(id, forKey: key, towards: (dx: 0, dy: -1),
                                   imageWidth: 512, imageHeight: 512)

        let after = try #require(annotation(model, id))
        #expect(abs(after.start.x - 0.5) < 0.001)
        #expect(abs(after.start.y - 0.3) < 0.001)
        // The point the arrow names does not move: that is what it is anchored to.
        #expect(after.end == before.end)
    }

    @Test("Swinging holds the label's distance from the anchor")
    func testOrbitKeepsTheRadius() throws {
        let (model, id) = model()
        let start = try #require(annotation(model, id))
        let expected = radius(start, width: 512, height: 512)

        // All the way round, in steps that are not multiples of each other, so
        // a per-step drift would accumulate rather than cancel.
        for degrees in stride(from: 0.0, to: 360.0, by: 17.0) {
            let radians = degrees * .pi / 180
            model.orbitAnnotationLabel(
                id, forKey: key, towards: (dx: cos(radians), dy: sin(radians)),
                imageWidth: 512, imageHeight: 512)
            let now = try #require(annotation(model, id))
            #expect(abs(radius(now, width: 512, height: 512) - expected) < 0.5,
                    "radius drifted at \(degrees)°")
        }
    }

    /// The reason the swing is computed in pixels rather than in fractions.
    @Test("On a non-square image the orbit is a circle, not an ellipse")
    func testOrbitIsCircularOnANonSquareImage() throws {
        // Twice as wide as tall: a fraction of the width is half the pixels a
        // fraction of the height is, so a naive fraction-space swing would
        // squash the orbit flat in one axis.
        let width = 1024.0, height = 512.0
        let (model, id) = model()
        let start = try #require(annotation(model, id))
        let expected = radius(start, width: width, height: height)

        for degrees in stride(from: 0.0, to: 360.0, by: 23.0) {
            let radians = degrees * .pi / 180
            model.orbitAnnotationLabel(
                id, forKey: key, towards: (dx: cos(radians), dy: sin(radians)),
                imageWidth: width, imageHeight: height)
            let now = try #require(annotation(model, id))
            #expect(abs(radius(now, width: width, height: height) - expected) < 0.5,
                    "orbit was elliptical at \(degrees)°")
        }
    }

    @Test("A pointer resting on the anchor names no direction, so nothing moves")
    func testDegenerateDirectionIsIgnored() throws {
        let (model, id) = model()
        let before = try #require(annotation(model, id))
        model.orbitAnnotationLabel(id, forKey: key, towards: (dx: 0, dy: 0),
                                   imageWidth: 512, imageHeight: 512)
        #expect(try #require(annotation(model, id)) == before)
    }

    @Test("Plain text has no anchor to orbit around, and is left alone")
    func testTextIsNotOrbited() throws {
        let model = PrintSelectionModel()
        let id = model.addTextAnnotation(
            forKey: key, at: PrintOverlayPoint(x: 0.3, y: 0.3))
        let before = try #require(annotation(model, id))
        model.orbitAnnotationLabel(id, forKey: key, towards: (dx: 1, dy: 0),
                                   imageWidth: 512, imageHeight: 512)
        #expect(try #require(annotation(model, id)) == before)
    }
}
