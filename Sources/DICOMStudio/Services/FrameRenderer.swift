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
import DICOMRenderKit

#if canImport(CoreGraphics)
import CoreGraphics

enum FrameRenderer {

    /// Identity of a rendered frame: everything that changes its pixels.
    ///
    /// Caches must key on this rather than on file and frame alone. Two marks of
    /// the same frame at different zooms are different pictures, and keying on
    /// identity alone silently serves the first one for both — which is exactly
    /// how a film preview ends up disagreeing with the viewer.
    ///
    /// `GPU_RENDERING_PLAN.md` M6 proposed dropping zoom, rotation, flip and invert
    /// from this key once those moved onto the GPU. They have **not** moved: they
    /// are still applied on the CPU by ``applying(_:to:)`` below, so they still
    /// change the pixels this key identifies and must stay in it. Removing them
    /// now would reintroduce exactly the bug the paragraph above describes. That
    /// rework is contingent on M5's display path, and is deferred with it.
    static func cacheKey(
        path: String,
        frameIndex: Int,
        windowCenter: Double?,
        windowWidth: Double?,
        windowSpace: PrintWindowSpace = .storedValues,
        presentation: ViewerPresentation?
    ) -> String {
        var parts: [String] = [path, String(frameIndex)]
        parts.append(windowCenter.map { String($0) } ?? "-")
        parts.append(windowWidth.map { String($0) } ?? "-")
        // The same pair of numbers is two different pictures depending on the
        // space, so it belongs in the key.
        if windowCenter != nil { parts.append(windowSpace.rawValue) }
        if let presentation {
            parts.append(contentsOf: [
                String(presentation.zoom),
                String(presentation.panX), String(presentation.panY),
                String(presentation.viewportWidth), String(presentation.viewportHeight),
                String(presentation.rotationDegrees),
                presentation.flipHorizontal ? "H" : "",
                presentation.flipVertical ? "V" : "",
                presentation.invert ? "I" : ""
            ])
        }
        return parts.joined(separator: "|")
    }

    /// Decodes, windows, arranges and scales one frame, off the main actor.
    ///
    /// A supplied window is normally already in stored-value space — it comes
    /// from the live viewer, which divides the header VOI through the rescale
    /// pair — so it is used as given. A window declared in output units (the
    /// print sheet's job-wide window, which a user types in HU) is converted
    /// first, through the same shared policy. Without a window at all, the
    /// image's own is resolved through
    /// the shared export policy: the header VOI *rescale-adjusted*, then the
    /// frame's pixel range. That is the same resolution the focused viewport
    /// performs on load, so an un-windowed tile matches the image beside it.
    ///
    /// Note what must NOT be used here: ``DICOMFile/renderFrameWithStoredWindow``
    /// hands the raw Window Center straight to the renderer, which reads *stored*
    /// pixels. On a CT with a large Rescale Intercept (−1024, −8192) a −615 HU
    /// centre then sits far below every stored value and the frame washes out to
    /// white.
    ///
    /// Arranging happens on the full-resolution frame and scaling last, so a
    /// zoomed tile shows the detail it will print rather than a blow-up of a
    /// thumbnail.
    static func render(
        path: String,
        frameIndex: Int,
        windowCenter: Double?,
        windowWidth: Double?,
        windowSpace: PrintWindowSpace = .storedValues,
        presentation: ViewerPresentation?,
        maxDimension: Int
    ) async -> CGImage? {
        // Decoded pixels are shared and reused: re-windowing or re-cropping the
        // same frame must not re-read and re-decode the file, or a window/level
        // drag renders at the speed of the codec.
        guard let source = await FrameSourceCache.shared.source(forPath: path) else {
            return nil
        }

        return await Task.detached(priority: .userInitiated) { () -> CGImage? in
            let file = source.file
            let isMonochrome = source.pixelData.descriptor
                .photometricInterpretation.isMonochrome

            let window = resolvedWindow(
                file: file, pixelData: source.pixelData, frameIndex: frameIndex,
                isMonochrome: isMonochrome,
                windowCenter: windowCenter, windowWidth: windowWidth,
                windowSpace: windowSpace)

            // GPU when it is available, exact and worth it; CPU otherwise. The
            // service decides, and its output is byte-identical either way, so a
            // tile rendered on the GPU and the film it is printed on — which stays
            // on the CPU — cannot disagree.
            let rendered = FrameRenderService.shared.renderFrame(FrameRenderRequest(
                pixelData: source.pixelData,
                frameIndex: frameIndex,
                window: window,
                paletteLUT: source.paletteLUT
            ))
            guard var image = rendered else { return nil }

            // Overlay planes go on before the frame is cropped, turned or
            // scaled: they are defined against the image's own pixel matrix, so
            // burning them here means they travel with the picture instead of
            // having to be re-registered against every arrangement.
            image = OverlayPlaneRenderer.burningOverlays(
                of: file.dataSet, onto: image, frameIndex: frameIndex)

            if let presentation, !presentation.isIdentity {
                image = applying(presentation, to: image) ?? image
            }
            return downscaled(image, maxDimension: maxDimension) ?? image
        }.value
    }

    /// Which window a frame gets, as one shared decision.
    ///
    /// Window *resolution* is the policy `DICOMImageExporter` owns, and both the
    /// CLI and the app must reach the same answer. Only the per-pixel mapping
    /// varies by backend — each is handed a resolved window and applies it.
    ///
    /// Shared by the CPU tile path and the GPU texture path below so a tile cannot
    /// change window merely by changing which renderer drew it.
    static func resolvedWindow(
        file: DICOMFile,
        pixelData: PixelData,
        frameIndex: Int,
        isMonochrome: Bool,
        windowCenter: Double?,
        windowWidth: Double?,
        windowSpace: PrintWindowSpace
    ) -> WindowSettings? {
        guard isMonochrome else { return nil }
        guard let windowCenter, let windowWidth, windowWidth >= 1 else {
            return DICOMImageExporter.determineWindowSettings(
                from: file, pixelData: pixelData, frameIndex: frameIndex,
                windowCenter: nil, windowWidth: nil)
        }
        switch windowSpace {
        case .storedValues:
            return WindowSettings(center: windowCenter, width: windowWidth)
        case .outputUnits:
            // The shared policy's explicit rung: output units in, stored values
            // out, through this file's rescale pair.
            return DICOMImageExporter.determineWindowSettings(
                from: file, pixelData: pixelData, frameIndex: frameIndex,
                windowCenter: windowCenter, windowWidth: windowWidth)
        }
    }

    #if canImport(Metal)
    /// Renders one frame of a file on disk straight to a GPU texture.
    ///
    /// The tile equivalent of the focused viewport's display path. Everything the
    /// CPU sibling above bakes into pixels — zoom, pan, rotation, flip, inversion —
    /// is deliberately *absent* here: on this path the arrangement is the display
    /// shader's transform, so a tile keeps one texture for its frame and window and
    /// re-draws a quad when a tool moves. That is what makes a synchronised zoom or
    /// window drag across a grid cost one redraw per tile rather than one decode.
    ///
    /// Two things send a tile back to the CPU. Frames with drawable overlay planes
    /// are burned rather than drawn, exactly as the focused viewport refuses them —
    /// a Siemens Patient Protocol has all-zero pixels and its whole content in a
    /// 1-bit plane, so its texture would be a black square. And an unresolvable
    /// window leaves the monochrome kernel with nothing to map, which the CPU
    /// renderer handles by auto-windowing from the pixel range.
    static func renderDisplayTexture(
        path: String,
        frameIndex: Int,
        windowCenter: Double?,
        windowWidth: Double?,
        windowSpace: PrintWindowSpace = .storedValues
    ) async -> DisplayFrameTexture? {
        guard let renderer = FrameRenderService.shared.displayRenderer,
              let source = await FrameSourceCache.shared.source(forPath: path) else { return nil }

        return await Task.detached(priority: .userInitiated) { () -> DisplayFrameTexture? in
            let file = source.file
            guard !OverlayPlaneRenderer.hasOverlay(file.dataSet, forFrame: frameIndex) else {
                return nil
            }

            let isMonochrome = source.pixelData.descriptor
                .photometricInterpretation.isMonochrome
            let window = resolvedWindow(
                file: file, pixelData: source.pixelData, frameIndex: frameIndex,
                isMonochrome: isMonochrome,
                windowCenter: windowCenter, windowWidth: windowWidth,
                windowSpace: windowSpace)
            // The monochrome kernel has no auto-window: a nil window here would be
            // rejected by the renderer anyway, so it falls to the CPU tile instead.
            if isMonochrome && window == nil { return nil }

            return renderer.renderDisplayTexture(FrameRenderRequest(
                pixelData: source.pixelData,
                frameIndex: frameIndex,
                window: window,
                paletteLUT: source.paletteLUT
            ))
        }.value
    }
    #endif

    /// The window a frame would be rendered with if none is supplied.
    ///
    /// Needed to seed an edit: a mark made without ever opening the file carries
    /// no window, and a window/level drag has to start from the values the cell
    /// is actually showing rather than from zero. Resolved by the same export
    /// policy ``render(path:frameIndex:windowCenter:windowWidth:presentation:maxDimension:)``
    /// falls back to, so seeding changes nothing on screen until the user drags.
    static func resolvedWindow(path: String, frameIndex: Int) async -> WindowSettings? {
        guard let source = await FrameSourceCache.shared.source(forPath: path) else { return nil }
        return DICOMImageExporter.determineWindowSettings(
            from: source.file, pixelData: source.pixelData, frameIndex: frameIndex,
            windowCenter: nil, windowWidth: nil)
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

        let rotation = presentation.rotationDegrees
        let flipH = presentation.flipHorizontal
        let flipV = presentation.flipVertical

        if rotation != 0 || flipH || flipV {
            // The turned box, so a free angle keeps its corners instead of being
            // cut to the crop's own rectangle — the same shape the film carries.
            let turned = presentation.turnedSize(
                width: Double(result.width), height: Double(result.height))
            let outWidth = max(1, Int(turned.width.rounded()))
            let outHeight = max(1, Int(turned.height.rounded()))
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
            context.rotate(by: rotation * .pi / 180)
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
