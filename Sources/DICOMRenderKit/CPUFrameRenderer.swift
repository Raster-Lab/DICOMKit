// CPUFrameRenderer.swift
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestone M2
//
// The always-available backend, and the reference implementation the Metal path is
// tested against. It is a thin adapter over `PixelDataRenderer`, which is *not*
// being replaced: it remains what `dicom-export`, `dicom-convert`, the print film
// burn and headless CI use, none of which the GPU will ever serve.

import Foundation
import DICOMCore
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics

/// Renders frames with `PixelDataRenderer` on the CPU.
public struct CPUFrameRenderer: FrameRenderBackend {
    public var backend: RenderBackend { .cpu }

    public init() {}

    public func renderFrame(_ request: FrameRenderRequest) -> CGImage? {
        let renderer = PixelDataRenderer(
            pixelData: request.pixelData, paletteColorLUT: request.paletteLUT
        )
        switch request.family {
        case .monochrome:
            // Without a window the renderer's own auto-window (the frame's pixel
            // range) applies — the same behaviour callers get from
            // `PixelDataRenderer.renderFrame`.
            guard let window = request.window else {
                return renderer.renderFrame(request.frameIndex)
            }
            // A pseudo-colour palette folds into the window as one raw-sample →
            // RGB table, exactly as the Metal path folds it, so the two backends
            // stay byte-identical in colour as they are in grey.
            if let palette = request.effectivePseudoColorPalette {
                let lut = PaletteDisplayLUT.make(
                    window: WindowLUT.grayscale(
                        descriptor: request.pixelData.descriptor, window: window),
                    entries: palette.entries())
                return renderer.renderMonochromeFrame(
                    request.frameIndex, displayLUT: lut)
            }
            return renderer.renderMonochromeFrame(request.frameIndex, window: window)
        case .palette:
            return renderer.renderPaletteColorFrame(request.frameIndex)
        case .color:
            return renderer.renderColorFrame(request.frameIndex)
        }
    }
}
#endif
