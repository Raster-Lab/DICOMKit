// DisplayFrameTexture.swift
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestone M5
//
// A rendered frame that has not been flattened into a CGImage, plus the geometry
// that decides where it lands on screen.

import Foundation
import simd

#if canImport(Metal)
import Metal

/// A windowed frame living in GPU memory, ready to be drawn.
///
/// Holds the `MTLBuffer` the texture views so the memory cannot be recycled while
/// the texture is still being drawn — the texture itself does not retain the buffer
/// it was created from.
public struct DisplayFrameTexture: @unchecked Sendable {
    public let texture: MTLTexture

    /// True for `.r8Unorm` single-channel frames, which the fragment shader splats
    /// across RGB.
    public let isGrayscale: Bool

    /// Owner of the output buffer the texture views. Retained, never read here.
    ///
    /// Shared with the `CGImage` built over the same memory: the buffer returns to
    /// the pool only once both are gone. Recycling it while either was still reading
    /// would corrupt what is on screen.
    let backing: OutputBufferBox

    init(texture: MTLTexture, isGrayscale: Bool, retaining backing: OutputBufferBox) {
        self.texture = texture
        self.isGrayscale = isGrayscale
        self.backing = backing
    }

    public var width: Int { texture.width }
    public var height: Int { texture.height }
}

// MARK: - Presentation

/// How a frame is arranged on screen: the tool state, as pure geometry.
///
/// Every field here is free to change. None of them re-renders anything — they
/// become a 4×4 matrix in the display shader, so a zoom, a rotation or a flip costs
/// one redraw of a textured quad. That is the whole point of M5: before it, a
/// rotation or an invert meant a full CPU `CGContext` pass over every pixel, and a
/// zoom meant a resample.
public struct DisplayPresentation: Equatable, Sendable {
    /// 1.0 = fit to the view.
    public var zoom: Double = 1.0
    /// Pan in points, in view space.
    public var panX: Double = 0
    public var panY: Double = 0
    /// Clockwise rotation in degrees. Any angle — not just quarter turns.
    public var rotationDegrees: Double = 0
    public var flipHorizontal: Bool = false
    public var flipVertical: Bool = false
    /// Grey inversion, applied in the fragment shader as `1 - x`. Exact on 8-bit.
    public var invert: Bool = false

    public init(
        zoom: Double = 1.0, panX: Double = 0, panY: Double = 0,
        rotationDegrees: Double = 0,
        flipHorizontal: Bool = false, flipVertical: Bool = false,
        invert: Bool = false
    ) {
        self.zoom = zoom
        self.panX = panX
        self.panY = panY
        self.rotationDegrees = rotationDegrees
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.invert = invert
    }

    public static let identity = DisplayPresentation()
}

/// The parameter block the display shader reads. Layout must match `DisplayParams`
/// in `FrameRender.metal`.
struct DisplayShaderParams {
    var transform: simd_float4x4
    var invert: UInt32
    var isGrayscale: UInt32
}

extension DisplayPresentation {
    /// Builds the image-quad → normalised-device-coordinates matrix.
    ///
    /// Order matters and is: aspect-fit, then flip, then zoom, then rotate, then
    /// pan. Fit first so zoom is relative to the fitted image rather than to the
    /// view; rotate after zoom so the image spins about its own centre; pan last so
    /// dragging moves the picture across the screen rather than through its own
    /// rotated frame — which is what a hand tool is expected to feel like.
    ///
    /// Returns `nil` for a degenerate viewport. **A zero-sized drawable is the known
    /// hazard here**: this codebase has already shipped a viewer that blanked every
    /// progressively-decoded J2K file because its canvas resolved to zero size under
    /// `.aspectRatio` (see `ProgressiveImageView`). Answering `nil` rather than
    /// dividing by zero is what makes that case detectable instead of silent.
    func transform(imageWidth: Int, imageHeight: Int,
                   viewWidth: Double, viewHeight: Double) -> simd_float4x4? {
        guard imageWidth > 0, imageHeight > 0,
              viewWidth > 0, viewHeight > 0,
              zoom > 0 else { return nil }

        // Aspect fit: scale the unit quad so the image's aspect ratio is preserved
        // inside the view and its longest constrained edge just touches the bounds.
        let imageAspect = Double(imageWidth) / Double(imageHeight)
        let viewAspect = viewWidth / viewHeight
        var fitX = 1.0
        var fitY = 1.0
        if imageAspect > viewAspect {
            fitY = viewAspect / imageAspect   // width-limited: shrink vertically
        } else {
            fitX = imageAspect / viewAspect   // height-limited: shrink horizontally
        }

        let scaleX = fitX * zoom * (flipHorizontal ? -1 : 1)
        let scaleY = fitY * zoom * (flipVertical ? -1 : 1)
        var matrix = simd_float4x4(diagonal: SIMD4<Float>(Float(scaleX), Float(scaleY), 1, 1))

        if rotationDegrees != 0 {
            // Negated: the viewer rotates clockwise in screen space while NDC y runs
            // upward, so a positive angle here would turn the image the wrong way.
            let radians = Float(-rotationDegrees * .pi / 180)
            let c = cos(radians), s = sin(radians)
            let rotation = simd_float4x4(
                SIMD4<Float>( c, s, 0, 0),
                SIMD4<Float>(-s, c, 0, 0),
                SIMD4<Float>( 0, 0, 1, 0),
                SIMD4<Float>( 0, 0, 0, 1)
            )
            matrix = rotation * matrix
        }

        // Pan is in points; NDC spans 2 units across the view, hence the doubling.
        if panX != 0 || panY != 0 {
            var translation = matrix_identity_float4x4
            translation.columns.3 = SIMD4<Float>(
                Float(2 * panX / viewWidth),
                Float(-2 * panY / viewHeight),   // view y grows downward, NDC upward
                0, 1
            )
            matrix = translation * matrix
        }

        return matrix
    }
}
#endif
