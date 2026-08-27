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

        // Read back at the texture's own size, which may exceed the frame's.
        let tw = texture.width, th = texture.height
        var bytes = [UInt8](repeating: 0, count: tw * th * 4)
        bytes.withUnsafeMutableBytes { buffer in
            texture.texture.getBytes(buffer.baseAddress!, bytesPerRow: tw * 4,
                                     from: MTLRegionMake2D(0, 0, tw, th), mipmapLevel: 0)
        }
        XCTAssertTrue(bytes.allSatisfy { $0 == 0 }, "nothing drawn must mean nothing but zero bytes")
    }

    /// The overlay is addressed in the same 0...1 texture coordinates as the
    /// frame, so its canvas need not be the frame's pixel grid — and for a
    /// small frame it deliberately is not: type rasterized at frame resolution
    /// arrives on screen magnified by whatever the viewer's zoom is, so the
    /// canvas is a whole multiple of the grid (see
    /// ``AnnotationTextureBuilder/supersamplingFactor(width:height:)``).
    ///
    /// What must hold is that it is the *same* multiple on both axes: an
    /// overlay stretched on one axis would slide its annotations off the
    /// anatomy they were drawn on.
    func testTextureDimensionsAreAWholeMultipleOfTheFrameGrid() throws {
        let device = try requireDevice()
        let texture = try XCTUnwrap(AnnotationTextureBuilder.build(
            overlays: [], width: 37, height: 23, device: device))

        let factor = AnnotationTextureBuilder.supersamplingFactor(width: 37, height: 23)
        XCTAssertEqual(texture.width, 37 * factor)
        XCTAssertEqual(texture.height, 23 * factor)
        XCTAssertEqual(texture.width % 37, 0, "the canvas must be a whole multiple of the grid")
        XCTAssertEqual(texture.height % 23, 0, "the canvas must be a whole multiple of the grid")
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
        // The texture's own grid, which is a multiple of the frame's — so the
        // comparison below is made in normalized coordinates rather than in
        // either grid's pixels.
        let tw = texture.width, th = texture.height
        var textureBytes = [UInt8](repeating: 0, count: tw * th * 4)
        textureBytes.withUnsafeMutableBytes { buffer in
            texture.texture.getBytes(buffer.baseAddress!, bytesPerRow: tw * 4,
                                     from: MTLRegionMake2D(0, 0, tw, th), mipmapLevel: 0)
        }

        /// Alpha at a 0...1 point on the overlay canvas.
        func textureAlpha(atX x: Double, y: Double) -> UInt8 {
            let column = min(tw - 1, max(0, Int(x * Double(tw))))
            let row = min(th - 1, max(0, Int(y * Double(th))))
            return textureBytes[(row * tw + column) * 4 + 3]
        }

        // The arrow's shaft crosses y = 0.5 — a horizontal band across the
        // frame's centre — and must be drawn (opaque) in both outputs, while a
        // corner far from the arrow must be undrawn in both.
        let midRow = height / 2
        let shaftBurned = burnedBytes[midRow * width + width / 2]
        XCTAssertNotEqual(shaftBurned, 0, "the burner must have drawn something on the shaft")

        let shaftAlpha = textureAlpha(atX: 0.5, y: 0.5)
        XCTAssertNotEqual(shaftAlpha, 0, "the texture must carry the same mark, alpha non-zero on the shaft")

        // Far from the arrow in both grids: the same normalized corner the
        // burner leaves black.
        let cornerAlpha = textureAlpha(atX: 2.0 / Double(width), y: 2.0 / Double(height))
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
        let tw = texture.width, th = texture.height
        var bytes = [UInt8](repeating: 0, count: tw * th * 4)
        bytes.withUnsafeMutableBytes { buffer in
            texture.texture.getBytes(buffer.baseAddress!, bytesPerRow: tw * 4,
                                     from: MTLRegionMake2D(0, 0, tw, th), mipmapLevel: 0)
        }
        XCTAssertTrue(bytes.allSatisfy { $0 == 0 }, "a blank text box must draw nothing in the texture either")
    }
}
#endif
