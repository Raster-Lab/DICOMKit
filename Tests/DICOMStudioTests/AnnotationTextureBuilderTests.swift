// AnnotationTextureBuilderTests.swift
// DICOMStudioTests
//
// The main viewer's GPU overlay is a promise: whatever it shows is what a
// print job would have burned, had burning not moved off the pixel path.
// These tests hold that promise by comparing `AnnotationTextureBuilder`'s
// rasterization against `ImageAnnotationBurner`'s own burn of the same
// overlays — both call the same `drawText`/`drawArrow` geometry, so a
// divergence here means the two have drifted apart, not that either alone
// is wrong.

import XCTest
import DICOMCore
import DICOMKit
import DICOMNetwork
import DICOMPrintKit
import DICOMRenderKit
@testable import DICOMStudio

#if canImport(Metal) && canImport(CoreGraphics)
import Metal

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class AnnotationTextureBuilderTests: XCTestCase {

    private func requireDevice() throws -> MTLDevice {
        guard let device = MetalRenderDevice.shared?.device else {
            throw XCTSkip("No Metal device on this machine")
        }
        return device
    }

    /// A blank grayscale prepared frame, the size the annotations are drawn
    /// against — what `ImageAnnotationBurner.burning(overlays:into:)` burns
    /// into, for comparison against the texture builder's own rasterization.
    private func blankPreparedImage(width: Int, height: Int) -> PreparedPrintImage {
        PreparedPrintImage(
            descriptor: PrintImageData(
                pixelData: Data(repeating: 0, count: width * height),
                rows: UInt16(height), columns: UInt16(width),
                bitsAllocated: 8, bitsStored: 8, highBit: 7,
                samplesPerPixel: 1, pixelRepresentation: 0,
                photometricInterpretation: "MONOCHROME2"),
            sourcePath: nil, frameIndex: 0,
            rowSpacingMillimeters: nil, columnSpacingMillimeters: nil)
    }

    func testTextureIsTransparentWhenThereIsNothingToDraw() throws {
        let device = try requireDevice()
        let texture = try XCTUnwrap(AnnotationTextureBuilder.build(
            overlays: [], width: 16, height: 16, device: device))

        var bytes = [UInt8](repeating: 0, count: 16 * 16 * 4)
        bytes.withUnsafeMutableBytes { buffer in
            texture.texture.getBytes(buffer.baseAddress!, bytesPerRow: 16 * 4,
                                     from: MTLRegionMake2D(0, 0, 16, 16), mipmapLevel: 0)
        }
        XCTAssertTrue(bytes.allSatisfy { $0 == 0 }, "nothing drawn must mean nothing but zero bytes")
    }

    func testTextureDimensionsMatchTheRequestedFrameSize() throws {
        let device = try requireDevice()
        let texture = try XCTUnwrap(AnnotationTextureBuilder.build(
            overlays: [], width: 37, height: 23, device: device))
        XCTAssertEqual(texture.width, 37)
        XCTAssertEqual(texture.height, 23)
    }

    /// The texture's opaque pixels — where alpha is non-zero — land at the
    /// same place `ImageAnnotationBurner` would have burned a visible mark,
    /// for a simple, unmistakable case: a short arrow whose shaft crosses
    /// the frame's centre.
    func testArrowPixelsLandWhereTheBurnerWouldHaveBurnedThem() throws {
        let device = try requireDevice()
        let width = 64, height = 64

        let overlay = PrintOverlayAnnotation(
            kind: .arrow,
            start: PrintOverlayPoint(x: 0.1, y: 0.5),
            end: PrintOverlayPoint(x: 0.9, y: 0.5),
            color: .white)

        let burned = ImageAnnotationBurner.burning(
            overlays: [overlay], into: blankPreparedImage(width: width, height: height))
        let burnedBytes = [UInt8](burned.pixelData)

        let texture = try XCTUnwrap(AnnotationTextureBuilder.build(
            overlays: [overlay], width: width, height: height, device: device))
        var textureBytes = [UInt8](repeating: 0, count: width * height * 4)
        textureBytes.withUnsafeMutableBytes { buffer in
            texture.texture.getBytes(buffer.baseAddress!, bytesPerRow: width * 4,
                                     from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }

        // The arrow's shaft crosses y = 0.5 — row 32, a horizontal band
        // around the frame's centre — and must be drawn (opaque) in both
        // outputs, while a corner far from the arrow must be undrawn in
        // both.
        let midRow = height / 2
        let shaftBurned = burnedBytes[midRow * width + width / 2]
        XCTAssertNotEqual(shaftBurned, 0, "the burner must have drawn something on the shaft")

        let shaftAlpha = textureBytes[(midRow * width + width / 2) * 4 + 3]
        XCTAssertNotEqual(shaftAlpha, 0, "the texture must carry the same mark, alpha non-zero on the shaft")

        let cornerAlpha = textureBytes[(2 * width + 2) * 4 + 3]
        XCTAssertEqual(cornerAlpha, 0, "a corner far from the arrow must be untouched")
    }

    /// Blank annotations (an empty text box, a click-length arrow) are
    /// skipped by both paths — the texture must not show them either.
    func testBlankAnnotationsAreSkippedLikeTheBurner() throws {
        let device = try requireDevice()
        let overlay = PrintOverlayAnnotation(kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5), text: "")

        let burned = ImageAnnotationBurner.burning(
            overlays: [overlay], into: blankPreparedImage(width: 32, height: 32))
        XCTAssertEqual(burned.pixelData, Data(repeating: 0, count: 32 * 32), "a blank text box burns nothing")

        let texture = try XCTUnwrap(AnnotationTextureBuilder.build(
            overlays: [overlay], width: 32, height: 32, device: device))
        var bytes = [UInt8](repeating: 0, count: 32 * 32 * 4)
        bytes.withUnsafeMutableBytes { buffer in
            texture.texture.getBytes(buffer.baseAddress!, bytesPerRow: 32 * 4,
                                     from: MTLRegionMake2D(0, 0, 32, 32), mipmapLevel: 0)
        }
        XCTAssertTrue(bytes.allSatisfy { $0 == 0 }, "a blank text box must draw nothing in the texture either")
    }
}
#endif
