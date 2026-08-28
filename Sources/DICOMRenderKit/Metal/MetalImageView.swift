// MetalImageView.swift
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestone M5
//
// Presenting a frame from GPU memory, with zoom, pan, rotation, flip and inversion
// applied by the display shader instead of by CPU passes and view modifiers.

import Foundation
import simd

#if canImport(MetalKit) && canImport(SwiftUI)
import MetalKit
import SwiftUI

// MARK: - Drawing

/// Draws a `DisplayFrameTexture` into an `MTKView`, arranged by a
/// `DisplayPresentation`.
///
/// Separate from the view itself so the geometry and the draw call can be tested
/// without instantiating AppKit/UIKit — which matters here, because the failure this
/// class most needs guarding against (a zero-sized drawable) is precisely the one a
/// headless test can reach.
public final class MetalImageRenderer: NSObject, MTKViewDelegate {

    private let device: MetalRenderDevice
    private var pipelineState: MTLRenderPipelineState?

    /// The frame being shown. Assigning a new one does not re-window anything — it
    /// swaps which texture the quad samples.
    public var frame: DisplayFrameTexture?

    /// Tool state. Changing any of it costs one redraw and touches no pixel data.
    public var presentation: DisplayPresentation = .identity

    /// Set when a draw was skipped because the drawable had no size.
    ///
    /// Exists because of a real prior incident: a `Canvas`-based viewer in this app
    /// blanked *every* progressively-decoded J2K file when the canvas resolved to
    /// zero size under `.aspectRatio`. The decode was fine; the view silently drew
    /// nothing. An `MTKView` has the same hazard, so it is recorded rather than
    /// ignored, and asserted by test.
    public private(set) var lastDrawHadZeroSizedDrawable = false

    /// Counts completed draws, so a test can prove a redraw actually happened rather
    /// than inferring it from the absence of a crash.
    public private(set) var drawCount = 0

    public init?(device: MetalRenderDevice? = MetalRenderDevice.shared) {
        guard let device else { return nil }
        self.device = device
        super.init()
        self.pipelineState = Self.makePipelineState(device: device)
        if pipelineState == nil { return nil }
    }

    private static func makePipelineState(device: MetalRenderDevice) -> MTLRenderPipelineState? {
        guard let vertexFunction = device.library.makeFunction(name: MetalKernel.displayVertex),
              let fragmentFunction = device.library.makeFunction(name: MetalKernel.displayFragment)
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.device.makeRenderPipelineState(descriptor: descriptor)
    }

    /// The pixel format an `MTKView` must be configured with to match the pipeline.
    public static let colorPixelFormat: MTLPixelFormat = .bgra8Unorm

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Nothing cached on size — the transform is rebuilt per draw. Kept explicit
        // rather than omitted so it is clear that is deliberate.
    }

    public func draw(in view: MTKView) {
        let size = view.drawableSize
        _ = render(size: size,
                   descriptor: view.currentRenderPassDescriptor,
                   drawable: view.currentDrawable)
    }

    /// The draw, with its inputs passed in rather than pulled from a view.
    ///
    /// - Returns: `true` if a frame was drawn. `false` means nothing was presented —
    ///   no frame, no drawable, or a zero-sized drawable.
    @discardableResult
    public func render(
        size: CGSize,
        descriptor: MTLRenderPassDescriptor?,
        drawable: (any MTLDrawable)?
    ) -> Bool {
        lastDrawHadZeroSizedDrawable = size.width <= 0 || size.height <= 0
        guard !lastDrawHadZeroSizedDrawable else { return false }

        guard let frame,
              let pipelineState,
              let descriptor,
              let transform = presentation.transform(
                imageWidth: frame.width, imageHeight: frame.height,
                viewWidth: Double(size.width), viewHeight: Double(size.height)),
              let commandBuffer = device.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return false }

        var params = DisplayShaderParams(
            transform: transform,
            invert: presentation.invert ? 1 : 0,
            isGrayscale: frame.isGrayscale ? 1 : 0
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBytes(&params, length: MemoryLayout<DisplayShaderParams>.stride, index: 0)
        encoder.setFragmentBytes(&params, length: MemoryLayout<DisplayShaderParams>.stride, index: 0)
        encoder.setFragmentTexture(frame.texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        if let drawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
        drawCount += 1
        return true
    }
}

// MARK: - SwiftUI

#if os(macOS)
public typealias PlatformViewRepresentable = NSViewRepresentable
#else
public typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// Shows a GPU-resident frame, arranged by a `DisplayPresentation`.
///
/// Use this instead of `Image(decorative:)` when the frame is already a texture. The
/// callers that have only a `CGImage` — tiles, thumbnails, the film preview, the CPU
/// fallback — keep using `Image`, and must: this view has no CPU path.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct MetalImageView: PlatformViewRepresentable {

    private let frame: DisplayFrameTexture?
    private let presentation: DisplayPresentation

    public init(frame: DisplayFrameTexture?, presentation: DisplayPresentation) {
        self.frame = frame
        self.presentation = presentation
    }

    public final class Coordinator {
        public let renderer: MetalImageRenderer?
        init() { self.renderer = MetalImageRenderer() }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    private func makeView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MetalRenderDevice.shared?.device
        view.colorPixelFormat = MetalImageRenderer.colorPixelFormat
        view.framebufferOnly = true
        // Redraw only when something changes: a viewer showing a still frame has no
        // reason to burn a GPU pass 60 times a second.
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.delegate = context.coordinator.renderer
        update(view, context: context)
        return view
    }

    private func update(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.frame = frame
        renderer.presentation = presentation
        #if os(macOS)
        view.needsDisplay = true
        #else
        view.setNeedsDisplay()
        #endif
    }

    #if os(macOS)
    public func makeNSView(context: Context) -> MTKView { makeView(context: context) }
    public func updateNSView(_ view: MTKView, context: Context) { update(view, context: context) }
    #else
    public func makeUIView(context: Context) -> MTKView { makeView(context: context) }
    public func updateUIView(_ view: MTKView, context: Context) { update(view, context: context) }
    #endif
}
#endif
