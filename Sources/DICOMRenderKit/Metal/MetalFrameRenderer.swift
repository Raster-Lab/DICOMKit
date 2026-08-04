// MetalFrameRenderer.swift
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestones M3 (monochrome) and M4 (colour)
//
// The GPU backend. Wraps the decoded frame without copying it, dispatches a
// compute kernel over a byte table built on the CPU, and hands the shader's own
// output memory straight to CoreGraphics — no upload, no readback.

import Foundation
import DICOMCore

#if canImport(Metal) && canImport(CoreGraphics)
import Metal
import CoreGraphics

/// Renders DICOM frames with Metal compute.
///
/// Returns `nil` for anything it cannot handle — an unsupported layout, a YBR
/// frame, a frame larger than the shader's 32-bit offsets, any Metal failure — and
/// ``FrameRenderService`` then renders it on the CPU. Every one of those is a
/// correctness-preserving fallback, never a blank image.
public final class MetalFrameRenderer: FrameRenderBackend, @unchecked Sendable {

    public var backend: RenderBackend { .metal }

    private let renderDevice: MetalRenderDevice
    private let pool: UnifiedMemoryPool

    /// Persistent table buffers, reused across renders.
    ///
    /// A window drag changes the table on every mouse delta, so these are written
    /// often — but they are allocated once. 64 KB written per drag step is the
    /// *entire* per-frame data movement in this design.
    private let lock = NSLock()
    private var tableBuffers: [Int: MTLBuffer] = [:]

    /// Frames smaller than this render on the CPU instead.
    ///
    /// Measured, not guessed. A dispatch — encode, commit, wait — costs about
    /// 0.24 ms whatever the image size, while the LUT-based CPU renderer runs at
    /// roughly 0.53 ms per megapixel. Below about half a megapixel the fixed cost
    /// dominates and the GPU *loses*: on an M4 a 512×512 CT takes 0.156 ms on the
    /// CPU and 0.254 ms on the GPU.
    ///
    /// One megapixel leaves margin past that crossover, and it keeps every
    /// thumbnail- and tile-sized render (256, 512 and 1024 px caps) on the CPU,
    /// where they belong — those are the renders a viewer does most of.
    public static let minimumGPUPixelCount = 1_000_000

    /// The threshold this instance applies. Lowered to 0 by the equivalence tests,
    /// which must exercise the kernels on small synthetic frames — the shader's
    /// correctness does not depend on the frame being big enough to be worth
    /// dispatching, and the tests need to prove that on frames they can enumerate
    /// exhaustively.
    private let minimumPixelCount: Int

    public init?(
        device: MetalRenderDevice? = MetalRenderDevice.shared,
        minimumPixelCount: Int = MetalFrameRenderer.minimumGPUPixelCount
    ) {
        guard let device else { return nil }
        self.renderDevice = device
        self.pool = UnifiedMemoryPool(device: device.device)
        self.minimumPixelCount = minimumPixelCount
    }

    // MARK: - Entry point

    public func renderFrame(_ request: FrameRenderRequest) -> CGImage? {
        switch request.family {
        case .monochrome:
            // No window means "auto-window from this frame's pixel range", which
            // requires a full scan of the pixels the CPU renderer already does.
            // Reproducing that scan here would be a second implementation of a
            // policy decision, so the CPU keeps it.
            guard let window = request.window else { return nil }
            return renderMonochrome(request, window: window)
        case .palette:
            guard let palette = request.paletteLUT else { return nil }
            return renderPalette(request, palette: palette)
        case .color:
            return renderColor(request)
        }
    }

    // MARK: - Monochrome

    private struct MonochromeParams {
        var width: UInt32
        var height: UInt32
        var frameByteOffset: UInt32
        var bytesPerSample: UInt32
        var availablePixels: UInt32
    }

    private func renderMonochrome(_ request: FrameRenderRequest, window: WindowSettings) -> CGImage? {
        let descriptor = request.pixelData.descriptor
        guard let geometry = FrameGeometry(request, minimumPixelCount: minimumPixelCount) else { return nil }

        // The same table the CPU renderer uses — built by the same code, from the
        // same WindowSettings.apply. This is what makes GPU output bit-identical
        // rather than merely close.
        let lut = WindowLUT.grayscale(descriptor: descriptor, window: window)

        var params = MonochromeParams(
            width: UInt32(geometry.width),
            height: UInt32(geometry.height),
            frameByteOffset: UInt32(geometry.frameOffset),
            bytesPerSample: UInt32(descriptor.bytesPerSample),
            availablePixels: UInt32(geometry.availablePixels)
        )

        return dispatch(
            request: request,
            geometry: geometry,
            kernel: MetalKernel.monochrome,
            outputByteCount: geometry.pixelCount,
            bytesPerRow: geometry.width,
            isGrayscale: true,
            configure: { encoder, input, output in
                encoder.setBuffer(input, offset: 0, index: 0)
                encoder.setBytes(&params, length: MemoryLayout<MonochromeParams>.stride, index: 1)
                guard let table = self.tableBuffer(lut.table, slot: 0) else { return false }
                encoder.setBuffer(table, offset: 0, index: 2)
                encoder.setBuffer(output, offset: 0, index: 3)
                return true
            }
        )
    }

    // MARK: - Colour

    private struct ColorParams {
        var width: UInt32
        var height: UInt32
        var frameByteOffset: UInt32
        var bytesPerSample: UInt32
        var planarConfiguration: UInt32
        var frameByteCount: UInt32
        var planeSizeBytes: UInt32
    }

    private func renderColor(_ request: FrameRenderRequest) -> CGImage? {
        let descriptor = request.pixelData.descriptor
        guard descriptor.samplesPerPixel == 3 else { return nil }

        // YBR stays on the CPU — deliberately, and permanently.
        //
        // The plan required this decision to be made explicitly here rather than
        // discovered in review. The RGB and palette maps are pure functions of ONE
        // sample, so a table reproduces the CPU's Double arithmetic exactly. YBR is
        // not: green depends on all three of Y, Cb and Cr, so an exact table would
        // need 2^24 entries (16 MB, ~17 million Double evaluations to build), and
        // any smaller formulation means recomputing those coefficients in `float`
        // on the GPU. Float would diverge from the CPU's `Double` at truncation
        // boundaries — one grey level, on some pixels — and that is precisely the
        // divergence design pillar 1 exists to prevent.
        //
        // So: no tolerance is accepted for this path. YBR frames render on the CPU,
        // where they are already fast enough (ultrasound and secondary capture, not
        // mammograms), and remain bit-identical everywhere.
        guard !descriptor.photometricInterpretation.isYBR else { return nil }

        guard let geometry = FrameGeometry(request, minimumPixelCount: minimumPixelCount) else { return nil }
        let lut = ColorSampleLUT.normalisation(for: descriptor)

        var params = ColorParams(
            width: UInt32(geometry.width),
            height: UInt32(geometry.height),
            frameByteOffset: UInt32(geometry.frameOffset),
            bytesPerSample: UInt32(descriptor.bytesPerSample),
            planarConfiguration: UInt32(descriptor.planarConfiguration),
            frameByteCount: UInt32(geometry.frameByteCount),
            planeSizeBytes: UInt32(geometry.pixelCount * descriptor.bytesPerSample)
        )

        return dispatch(
            request: request,
            geometry: geometry,
            kernel: MetalKernel.color,
            outputByteCount: geometry.pixelCount * 4,
            bytesPerRow: geometry.width * 4,
            isGrayscale: false,
            configure: { encoder, input, output in
                encoder.setBuffer(input, offset: 0, index: 0)
                encoder.setBytes(&params, length: MemoryLayout<ColorParams>.stride, index: 1)
                guard let table = self.tableBuffer(lut.table, slot: 0) else { return false }
                encoder.setBuffer(table, offset: 0, index: 2)
                encoder.setBuffer(output, offset: 0, index: 3)
                return true
            }
        )
    }

    // MARK: - Palette colour

    private struct PaletteParams {
        var width: UInt32
        var height: UInt32
        var frameByteOffset: UInt32
        var bytesPerSample: UInt32
        var availablePixels: UInt32
    }

    private func renderPalette(_ request: FrameRenderRequest, palette: PaletteColorLUT) -> CGImage? {
        let descriptor = request.pixelData.descriptor
        guard let geometry = FrameGeometry(request, minimumPixelCount: minimumPixelCount) else { return nil }

        let lut = PaletteDisplayLUT.make(descriptor: descriptor, palette: palette)

        var params = PaletteParams(
            width: UInt32(geometry.width),
            height: UInt32(geometry.height),
            frameByteOffset: UInt32(geometry.frameOffset),
            bytesPerSample: UInt32(descriptor.bytesPerSample),
            availablePixels: UInt32(geometry.availablePixels)
        )

        return dispatch(
            request: request,
            geometry: geometry,
            kernel: MetalKernel.palette,
            outputByteCount: geometry.pixelCount * 4,
            bytesPerRow: geometry.width * 4,
            isGrayscale: false,
            configure: { encoder, input, output in
                encoder.setBuffer(input, offset: 0, index: 0)
                encoder.setBytes(&params, length: MemoryLayout<PaletteParams>.stride, index: 1)
                guard let red = self.tableBuffer(lut.red, slot: 0),
                      let green = self.tableBuffer(lut.green, slot: 1),
                      let blue = self.tableBuffer(lut.blue, slot: 2) else { return false }
                encoder.setBuffer(red, offset: 0, index: 2)
                encoder.setBuffer(green, offset: 0, index: 3)
                encoder.setBuffer(blue, offset: 0, index: 4)
                encoder.setBuffer(output, offset: 0, index: 5)
                return true
            }
        )
    }

    // MARK: - Dispatch

    /// The shape of one frame within the wrapped pixel buffer.
    private struct FrameGeometry {
        let width: Int
        let height: Int
        let pixelCount: Int
        let frameOffset: Int
        let frameByteCount: Int
        let availablePixels: Int

        init?(_ request: FrameRenderRequest, minimumPixelCount: Int) {
            let descriptor = request.pixelData.descriptor
            let width = descriptor.columns
            let height = descriptor.rows
            guard width > 0, height > 0, descriptor.bytesPerSample >= 1 else { return nil }

            let pixelCount = width * height
            let frameByteCount = descriptor.bytesPerFrame
            let frameOffset = request.frameIndex * frameByteCount

            // Mirrors `PixelData.frameData(at:)`, which returns nil — and so
            // renders nothing — when the frame is not wholly present.
            guard request.frameIndex >= 0,
                  request.frameIndex < descriptor.numberOfFrames,
                  frameOffset + frameByteCount <= request.pixelData.data.count else {
                return nil
            }

            // The shader addresses bytes with 32-bit offsets. A frame beyond 4 GB
            // is not something to silently mis-render.
            guard frameOffset + frameByteCount <= Int(UInt32.max),
                  pixelCount * 4 <= Int(UInt32.max) else {
                return nil
            }

            // Too small to be worth a dispatch — the CPU is measurably faster.
            guard pixelCount >= minimumPixelCount else { return nil }

            self.width = width
            self.height = height
            self.pixelCount = pixelCount
            self.frameOffset = frameOffset
            self.frameByteCount = frameByteCount
            self.availablePixels = min(pixelCount, frameByteCount / descriptor.bytesPerSample)
        }
    }

    private func dispatch(
        request: FrameRenderRequest,
        geometry: FrameGeometry,
        kernel: String,
        outputByteCount: Int,
        bytesPerRow: Int,
        isGrayscale: Bool,
        configure: (MTLComputeCommandEncoder, MTLBuffer, MTLBuffer) -> Bool
    ) -> CGImage? {
        guard let pipeline = renderDevice.pipelineState(for: kernel),
              let (input, _) = pool.inputBuffer(for: request.pixelData, frameIndex: request.frameIndex),
              let output = pool.outputBuffer(byteCount: outputByteCount),
              let commandBuffer = renderDevice.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        guard configure(encoder, input, output) else {
            encoder.endEncoding()
            pool.recycle(output)
            return nil
        }

        // Uniform threadgroups with an in-kernel bounds check, rather than
        // `dispatchThreads`: it works on every Metal device without a
        // non-uniform-threadgroup capability check, and the guard clause the
        // kernels already carry makes the rounded-up grid harmless.
        let executionWidth = pipeline.threadExecutionWidth
        let groupHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / executionWidth)
        let threadsPerGroup = MTLSize(width: executionWidth, height: groupHeight, depth: 1)
        let groups = MTLSize(
            width: (geometry.width + executionWidth - 1) / executionWidth,
            height: (geometry.height + groupHeight - 1) / groupHeight,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.error == nil else {
            pool.recycle(output)
            return nil
        }

        return makeImage(
            from: output, byteCount: outputByteCount,
            width: geometry.width, height: geometry.height,
            bytesPerRow: bytesPerRow, isGrayscale: isGrayscale
        )
    }

    /// Builds a `CGImage` over the shader's own output memory.
    ///
    /// This is the half of design pillar 2 that removes the readback: there is no
    /// `getBytes`, no second allocation, no copy. CoreGraphics reads the shared
    /// buffer the GPU just wrote, and the buffer returns to the pool when the image
    /// is released — which is the only moment it is provably safe to reuse.
    private func makeImage(
        from buffer: MTLBuffer, byteCount: Int,
        width: Int, height: Int, bytesPerRow: Int, isGrayscale: Bool
    ) -> CGImage? {
        let box = OutputBufferBox(buffer: buffer, pool: pool)
        let info = Unmanaged.passRetained(box).toOpaque()

        guard let provider = CGDataProvider(
            dataInfo: info,
            data: buffer.contents(),
            size: byteCount,
            releaseData: { info, _, _ in
                guard let info else { return }
                Unmanaged<OutputBufferBox>.fromOpaque(info).release()
            }
        ) else {
            Unmanaged<OutputBufferBox>.fromOpaque(info).release()
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: isGrayscale ? 8 : 32,
            bytesPerRow: bytesPerRow,
            space: isGrayscale ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: isGrayscale
                                     ? CGImageAlphaInfo.none.rawValue
                                     : CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Writes a byte table into a reusable shared buffer.
    ///
    /// `slot` separates the three palette tables, which are live simultaneously.
    private func tableBuffer(_ table: [UInt8], slot: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }

        let buffer: MTLBuffer
        if let existing = tableBuffers[slot], existing.length >= table.count {
            buffer = existing
        } else {
            // Always allocate the largest table size so a switch between 8- and
            // 16-bit images does not reallocate.
            guard let created = renderDevice.device.makeBuffer(
                length: 65_536,
                options: [.storageModeShared, .hazardTrackingModeUntracked]
            ) else { return nil }
            tableBuffers[slot] = created
            buffer = created
        }

        table.withUnsafeBytes { source in
            guard let base = source.baseAddress else { return }
            buffer.contents().copyMemory(from: base, byteCount: table.count)
        }
        return buffer
    }

    // MARK: - Diagnostics

    /// Buffer allocation / pixel copy counters, so the zero-copy claim can be
    /// asserted by a test rather than trusted.
    var memoryCounters: UnifiedMemoryPool.Counters { pool.counters }

    /// Releases pooled GPU memory.
    public func purgeCaches() { pool.purge() }
}

/// Keeps an output buffer alive for exactly as long as the `CGImage` reading it,
/// then returns it to the pool.
private final class OutputBufferBox {
    let buffer: MTLBuffer
    let pool: UnifiedMemoryPool

    init(buffer: MTLBuffer, pool: UnifiedMemoryPool) {
        self.buffer = buffer
        self.pool = pool
    }

    deinit {
        pool.recycle(buffer)
    }
}
#endif
