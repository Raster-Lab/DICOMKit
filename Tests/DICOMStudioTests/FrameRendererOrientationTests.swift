// FrameRendererOrientationTests.swift
// DICOMStudioTests
//
// The tray thumbnail and the film must be the same picture.
//
// Two implementations arrange a marked frame: `PrintPresentationTransform`
// permutes raw pixels for the film, and `FrameRenderer.applying` draws through a
// `CGContext` for the tray thumbnails, the film preview's CPU cells and the
// viewer's unfocused tiles. The film path's orientation is pinned pixel-by-pixel
// in `PrintPresentationTransformTests`; nothing pinned the CG path against it,
// and the two disagreed about which way a rotation turns — `rotate(by:)` in a
// bottom-left-origin context comes out counterclockwise on a top-down display,
// and the negation the code's comment promised was never in the code. Every
// thumbnail turned its image the opposite way from the viewer and the film,
// twice the angle apart, and no test noticed because each path was only ever
// compared with itself.
//
// So this suite compares them with *each other*: the same source, the same
// presentation, both paths, pixel for pixel. Whatever convention the two use,
// they must use the same one.

import Testing
import Foundation
@testable import DICOMStudio
import DICOMPrintKit
import DICOMNetwork

#if canImport(CoreGraphics)
import CoreGraphics

@Suite("Frame Renderer Orientation Tests")
struct FrameRendererOrientationTests {

    /// The asymmetric ramp `PrintPresentationTransformTests` uses:
    ///  0  1  2
    /// 10 11 12
    /// Every pixel distinct, so any wrong turn or mirror shows.
    private static let width = 3, height = 2

    private func printImage() -> PrintImageData {
        var bytes = [UInt8]()
        for row in 0..<Self.height {
            for column in 0..<Self.width {
                bytes.append(UInt8(row * 10 + column))
            }
        }
        return PrintImageData(
            pixelData: Data(bytes),
            rows: UInt16(Self.height), columns: UInt16(Self.width),
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME2")
    }

    private func cgImage() throws -> CGImage {
        var px = [UInt8]()
        for row in 0..<Self.height {
            for column in 0..<Self.width {
                let v = UInt8(row * 10 + column)
                px += [v, v, v, 255]
            }
        }
        let data = try #require(CFDataCreate(nil, px, px.count))
        let provider = try #require(CGDataProvider(data: data))
        return try #require(CGImage(
            width: Self.width, height: Self.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Self.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent))
    }

    /// The red channel of every pixel, row-major — comparable with the film's bytes.
    private func values(of image: CGImage) throws -> [UInt8] {
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(
            x: 0, y: 0, width: image.width, height: image.height))
        let buffer = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<(image.width * image.height)).map { buffer[$0 * 4] }
    }

    @Test("Quarter turns and flips: the CG path matches the film's pixels",
          arguments: [
            ViewerPresentation(rotationDegrees: 90),
            ViewerPresentation(rotationDegrees: 180),
            ViewerPresentation(rotationDegrees: 270),
            ViewerPresentation(flipHorizontal: true),
            ViewerPresentation(flipVertical: true),
            ViewerPresentation(rotationDegrees: 90, flipHorizontal: true),
            ViewerPresentation(rotationDegrees: 90, flipVertical: true),
            ViewerPresentation(rotationDegrees: 270, flipHorizontal: true),
            ViewerPresentation(rotationDegrees: 180,
                               flipHorizontal: true, flipVertical: true),
          ])
    func testCGPathMatchesFilmPath(_ presentation: ViewerPresentation) throws {
        let film = PrintPresentationTransform.apply(presentation, to: printImage())
        let thumbnail = try #require(
            FrameRenderer.applying(presentation, to: cgImage()),
            "the CG path failed to render at all")

        #expect(thumbnail.width == Int(film.columns),
                "the two paths disagree about the turned shape")
        #expect(thumbnail.height == Int(film.rows))
        #expect(try values(of: thumbnail) == [UInt8](film.pixelData),
                "the thumbnail is not the film's picture — same mark, different arrangement")
    }
}
#endif
