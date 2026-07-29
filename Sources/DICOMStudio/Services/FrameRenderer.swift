// FrameRenderer.swift
// DICOMStudio
//
// DICOM Studio — rendering one frame of a file on disk, arranged.
//
// Shared by the film preview and the viewer's unfocused tiles: both need "this
// frame, windowed and arranged the way the user left it, at a size that suits
// the box it goes in", and both must agree with what the printer will produce.

import Foundation
import DICOMKit
import DICOMCore
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics

enum FrameRenderer {

    /// Identity of a rendered frame: everything that changes its pixels.
    ///
    /// Caches must key on this rather than on file and frame alone. Two marks of
    /// the same frame at different zooms are different pictures, and keying on
    /// identity alone silently serves the first one for both — which is exactly
    /// how a film preview ends up disagreeing with the viewer.
    static func cacheKey(
        path: String,
        frameIndex: Int,
        windowCenter: Double?,
        windowWidth: Double?,
        presentation: ViewerPresentation?
    ) -> String {
        var parts: [String] = [path, String(frameIndex)]
        parts.append(windowCenter.map { String($0) } ?? "-")
        parts.append(windowWidth.map { String($0) } ?? "-")
        if let presentation {
            parts.append(contentsOf: [
                String(presentation.zoom),
                String(presentation.panX), String(presentation.panY),
                String(presentation.viewportWidth), String(presentation.viewportHeight),
                String(presentation.quarterTurns),
                presentation.flipHorizontal ? "H" : "",
                presentation.flipVertical ? "V" : "",
                presentation.invert ? "I" : ""
            ])
        }
        return parts.joined(separator: "|")
    }

    /// Decodes, windows, arranges and scales one frame, off the main actor.
    ///
    /// The render ladder mirrors the viewer's: the supplied window first, then
    /// automatic windowing, then the file's stored window. Arranging happens on
    /// the full-resolution frame and scaling last, so a zoomed tile shows the
    /// detail it will print rather than a blow-up of a thumbnail.
    static func render(
        path: String,
        frameIndex: Int,
        windowCenter: Double?,
        windowWidth: Double?,
        presentation: ViewerPresentation?,
        maxDimension: Int
    ) async -> CGImage? {
        await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let data = FileManager.default.contents(atPath: path),
                  let file = try? DICOMFile.read(from: data, force: true) else { return nil }

            var image: CGImage?
            if let windowCenter, let windowWidth, windowWidth >= 1 {
                image = try? file.tryRenderFrame(
                    frameIndex, window: WindowSettings(center: windowCenter, width: windowWidth))
            }
            if image == nil {
                image = try? file.tryRenderFrame(frameIndex)
            }
            if image == nil {
                image = try? file.tryRenderFrameWithStoredWindow(frameIndex)
            }
            guard var image else { return nil }

            if let presentation, !presentation.isIdentity {
                image = applying(presentation, to: image) ?? image
            }
            return downscaled(image, maxDimension: maxDimension) ?? image
        }.value
    }

    // MARK: - Arrangement

    /// Applies a presentation to a rendered frame: crop, rotate, flip, invert.
    ///
    /// The same `ViewerPresentation` the print path consumes, so what a preview
    /// or tile shows is what the film gets.
    static func applying(
        _ presentation: ViewerPresentation,
        to image: CGImage
    ) -> CGImage? {
        var result = image
        if let region = presentation.visibleRegion(
            imageWidth: image.width, imageHeight: image.height),
           let cropped = image.cropping(to: CGRect(
            x: region.x, y: region.y, width: region.width, height: region.height)) {
            result = cropped
        }

        let quarterTurns = presentation.quarterTurns
        let flipH = presentation.flipHorizontal
        let flipV = presentation.flipVertical

        if quarterTurns != 0 || flipH || flipV {
            let swapsAxes = quarterTurns % 2 == 1
            let outWidth = swapsAxes ? result.height : result.width
            let outHeight = swapsAxes ? result.width : result.height
            guard let context = CGContext(
                data: nil,
                width: outWidth,
                height: outHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return result }

            // CoreGraphics' origin is bottom-left while the viewer rotates in
            // screen space, so the clockwise turn is negated here.
            context.translateBy(x: Double(outWidth) / 2, y: Double(outHeight) / 2)
            context.scaleBy(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
            context.rotate(by: Double(quarterTurns) * .pi / 2)
            context.draw(result, in: CGRect(
                x: -Double(result.width) / 2,
                y: -Double(result.height) / 2,
                width: Double(result.width),
                height: Double(result.height)))
            result = context.makeImage() ?? result
        }

        if presentation.invert {
            result = ImageInversion.inverted(result) ?? result
        }
        return result
    }

    // MARK: - Scaling

    /// Scales an image down so its longest edge is at most `maxDimension`.
    ///
    /// Only ever downscales: enlarging here would waste memory and add nothing,
    /// since the view scales to its own box anyway.
    static func downscaled(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let longest = max(image.width, image.height)
        guard longest > maxDimension, maxDimension > 0 else { return image }

        let scale = Double(maxDimension) / Double(longest)
        let targetWidth = max(1, Int((Double(image.width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(image.height) * scale).rounded()))

        // An 8-bit RGBA context: the source may be 16-bit grayscale or indexed,
        // and matching that exactly buys nothing for a scaled-down copy.
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }
}
#endif
