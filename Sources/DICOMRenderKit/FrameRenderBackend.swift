// FrameRenderBackend.swift
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestone M2
//
// The one interface the CPU and Metal renderers both satisfy, and the request
// type that describes a frame render without committing to how it happens.

import Foundation
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics

// MARK: - Request

/// Everything needed to turn one frame of decoded pixel data into a displayable
/// image.
///
/// Deliberately does **not** carry zoom, pan, rotation or flip. Those are
/// arrangement, applied after the frame is rendered, and folding them in here
/// would put them in every cache key — which is exactly the problem M6 exists to
/// undo.
public struct FrameRenderRequest: Sendable {
    /// The decoded pixels. When its ``PixelData/alignedStorage`` is non-nil the
    /// Metal backend can read it without a copy.
    public let pixelData: PixelData

    /// Zero-based frame index.
    public let frameIndex: Int

    /// The VOI window for monochrome frames.
    ///
    /// Required for monochrome; ignored otherwise. Resolving *which* window
    /// (explicit → the file's rescale-adjusted VOI → the frame's pixel range) is
    /// `DICOMImageExporter.determineWindowSettings`' job and stays there — this
    /// layer renders the window it is handed and makes no policy of its own. That
    /// separation is what keeps the CLI and the app agreeing on what an image
    /// looks like.
    public let window: WindowSettings?

    /// Palette tables for PALETTE COLOR frames. Ignored otherwise.
    public let paletteLUT: PaletteColorLUT?

    /// A pseudo-colour palette the reader chose, applied to monochrome frames
    /// *after* the window. Ignored for colour and PALETTE COLOR frames.
    ///
    /// Not the same thing as ``paletteLUT``, and deliberately a separate field:
    /// that one is the file's own colour table, a property of the pixels, while
    /// this is a display choice laid over a grey image. They never both apply —
    /// a palette-colour frame has its own colours and a pseudo-colour ramp has
    /// nothing to say about them — but keeping them apart is what stops one
    /// being mistaken for the other.
    public let pseudoColorPalette: PseudoColorPalette?

    public init(
        pixelData: PixelData,
        frameIndex: Int = 0,
        window: WindowSettings? = nil,
        paletteLUT: PaletteColorLUT? = nil,
        pseudoColorPalette: PseudoColorPalette? = nil
    ) {
        self.pixelData = pixelData
        self.frameIndex = frameIndex
        self.window = window
        self.paletteLUT = paletteLUT
        self.pseudoColorPalette = pseudoColorPalette
    }

    /// The pseudo-colour palette that actually recolours this frame, if any.
    ///
    /// Grey is not a recolouring, and neither is a palette over a frame that
    /// carries its own colours — both resolve to `nil` so the plain monochrome
    /// kernel keeps its cheaper single-channel output.
    public var effectivePseudoColorPalette: PseudoColorPalette? {
        guard pixelData.descriptor.photometricInterpretation.isMonochrome,
              let palette = pseudoColorPalette,
              !palette.isGrayscale else { return nil }
        return palette
    }

    /// Which kernel family this frame needs.
    public var family: FrameRenderFamily {
        let photometric = pixelData.descriptor.photometricInterpretation
        if photometric.isMonochrome { return .monochrome }
        if photometric.isPaletteColor { return .palette }
        return .color
    }
}

/// The three shapes a DICOM frame render takes.
public enum FrameRenderFamily: String, Sendable {
    case monochrome
    case palette
    case color
}

// MARK: - Backend

/// A thing that can render a frame to a `CGImage`.
///
/// `CGImage` is the return type on purpose: roughly a dozen call sites already
/// consume one (viewer, tiles, thumbnails, film composition, export, the CLIs), so
/// a GPU backend that produces one changes no call site at all. Under unified
/// memory it costs nothing either — the image is backed by the very buffer the
/// shader wrote.
public protocol FrameRenderBackend: Sendable {
    /// Which backend this is, for reporting.
    var backend: RenderBackend { get }

    /// Renders one frame, or returns `nil` if this backend cannot.
    ///
    /// `nil` means "not rendered" and is a legitimate answer — an unsupported
    /// pixel layout, a missing palette, a Metal failure. Callers route through
    /// ``FrameRenderService``, which falls back to the CPU rather than showing
    /// the user nothing.
    func renderFrame(_ request: FrameRenderRequest) -> CGImage?
}
#endif
