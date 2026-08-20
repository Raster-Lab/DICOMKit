//
// PresentationLUTTransformTests.swift
// DICOMPrintKitTests
//
// The Presentation LUT's conformance rules and its pixel transform.
//
// The rules under test come from PS3.3 C.11.4, which enumerates IDENTITY and
// LIN OD and no others — INVERSE is the softcopy module's value (C.11.6) and
// must never reach the wire from the print path.
//

import XCTest
import DICOMNetwork
@testable import DICOMPrintKit

final class PresentationLUTTransformTests: XCTestCase {

    // MARK: Conformance

    /// PS3.3 C.11.4 enumerates exactly IDENTITY and LIN OD as shapes.
    func testOnlyStandardShapesGoOnTheWire() {
        XCTAssertEqual(PresentationLUTShape.identity.wireValue, "IDENTITY")
        XCTAssertEqual(PresentationLUTShape.linearOpticalDensity.wireValue, "LIN OD")
        XCTAssertNil(PresentationLUTShape.inverseRendered.wireValue,
                     "INVERSE is not a legal print Presentation LUT Shape")
    }

    func testLegalityAndPixelRenderingAreComplementary() {
        for shape in PresentationLUTShape.allCases {
            XCTAssertNotEqual(shape.isLegalPrintShape, shape.invertsPixels,
                              "\(shape) must be sent as a shape or rendered, not both")
        }
    }

    /// The LIN OD token carries a space, matching DCMTK's `"LIN OD"`.
    func testLinODTokenSpelling() {
        XCTAssertEqual(PresentationLUTShape.linearOpticalDensity.rawValue, "LIN OD")
    }

    // MARK: Curves

    func testIdentityNeedsNoCurve() {
        XCTAssertNil(PresentationLUTTransform.curve(for: .identity))
        XCTAssertNil(PresentationLUTTransform.curve(for: nil))
    }

    func testRenderedInverseIsAFullNegation() {
        let curve = try? XCTUnwrap(PresentationLUTTransform.curve(for: .inverseRendered))
        XCTAssertEqual(curve?.first, 255)
        XCTAssertEqual(curve?.last, 0)
        XCTAssertEqual(curve?[100], 155)
    }

    /// LIN OD is a density curve, not a negation: it runs bright-to-dark like
    /// an inversion but along 10^(−OD), so its midpoint is nowhere near 127.
    func testLinODIsExponentialNotLinear() throws {
        let curve = try XCTUnwrap(PresentationLUTTransform.curve(for: .linearOpticalDensity))
        XCTAssertEqual(curve.count, 256)
        XCTAssertEqual(curve[0], 255, "Min Density prints brightest")
        XCTAssertEqual(curve[255], 0, "Max Density prints darkest")
        XCTAssertTrue(curve.first! > curve[128] && curve[128] > curve.last!,
                      "monotonically decreasing")
        XCTAssertLessThan(curve[128], 100,
                          "a straight negation would put the midpoint near 127")
    }

    func testLinODHonoursFilmDensityBounds() throws {
        let standard = try XCTUnwrap(PresentationLUTTransform.curve(
            for: .linearOpticalDensity, minDensity: 20, maxDensity: 300))
        let narrow = try XCTUnwrap(PresentationLUTTransform.curve(
            for: .linearOpticalDensity, minDensity: 20, maxDensity: 150))
        XCTAssertNotEqual(standard, narrow, "Max Density changes the curve")
    }

    func testLinODRejectsInvertedDensityRange() {
        XCTAssertNil(PresentationLUTTransform.curve(
            for: .linearOpticalDensity, minDensity: 300, maxDensity: 20))
    }

    // MARK: Application

    func testCurveAppliesToGrayscaleSamples() throws {
        let curve = try XCTUnwrap(PresentationLUTTransform.curve(for: .inverseRendered))
        let out = PresentationLUTTransform.apply(
            curve: curve, to: Data([0, 10, 255]), samplesPerPixel: 1, bitsStored: 8)
        XCTAssertEqual(Array(out), [255, 245, 0])
    }

    /// A density curve has no meaning for an RGB box, and inverting only the
    /// luminance of a colour image would shift its hue.
    func testColourSamplesArePassedThrough() throws {
        let curve = try XCTUnwrap(PresentationLUTTransform.curve(for: .inverseRendered))
        let rgb = Data([10, 20, 30])
        XCTAssertEqual(
            PresentationLUTTransform.apply(
                curve: curve, to: rgb, samplesPerPixel: 3, bitsStored: 8),
            rgb)
    }

    /// The curve is 8-bit; deeper pixels are left to the printer's own LUT
    /// rather than being silently truncated.
    func testDeepPixelsArePassedThrough() throws {
        let curve = try XCTUnwrap(PresentationLUTTransform.curve(for: .inverseRendered))
        let samples = Data([1, 2, 3, 4])
        XCTAssertEqual(
            PresentationLUTTransform.apply(
                curve: curve, to: samples, samplesPerPixel: 1, bitsStored: 12),
            samples)
    }
}
