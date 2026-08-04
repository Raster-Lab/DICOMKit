// MetalRenderDevice.swift
// DICOMRenderKit — GPU_RENDERING_PLAN.md milestone M2
//
// The process-wide Metal device, command queue, shader library and pipeline-state
// cache. One of these, created lazily, `nil` when the machine has no GPU.

import Foundation

#if canImport(Metal)
import Metal

/// Owns the Metal objects the frame renderer needs, for the life of the process.
///
/// Everything here is expensive to create and safe to share: `MTLDevice` and
/// `MTLCommandQueue` are thread-safe, and compiled pipeline states are immutable.
/// The only mutable state is the pipeline cache, which is lock-guarded.
public final class MetalRenderDevice: @unchecked Sendable {

    /// The shared device, or `nil` on a machine with no Metal GPU (CI containers,
    /// some VMs). Every caller must handle `nil` — that is what makes `.cpu` the
    /// guaranteed fallback rather than a nice-to-have.
    public static let shared: MetalRenderDevice? = MetalRenderDevice()

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary

    /// How the shader library was obtained. Reported by the M2 smoke test.
    public enum LibrarySource: String, Sendable {
        /// A `default.metallib` found in `Bundle.module` — used if a future
        /// toolchain starts producing one.
        case bundledMetallib
        /// Compiled from `FrameRender.metal`, shipped as a bundle resource. This
        /// is the expected path today.
        case runtimeCompiled
    }
    public let librarySource: LibrarySource

    private let lock = NSLock()
    private var pipelineStates: [String: MTLComputePipelineState] = [:]

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        guard let (library, source) = Self.loadLibrary(device: device) else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.librarySource = source
    }

    /// Loads the shader library — once, at first use.
    ///
    /// The plan assumed SwiftPM would compile the target's `.metal` file into a
    /// `default.metallib` in its resource bundle, to be loaded with
    /// `makeDefaultLibrary(bundle:)`. **It does not.** On this toolchain a
    /// `.metal` file in a target's sources is silently ignored: no metallib, no
    /// resource bundle, no warning. Verified with a minimal probe package before
    /// changing course, because the failure is invisible — everything builds and
    /// only the GPU path goes missing.
    ///
    /// So `FrameRender.metal` ships as a bundle *resource* and is compiled here,
    /// once per process. That keeps one source of truth for the kernels and costs
    /// a single small compile at first GPU render. The `makeDefaultLibrary(bundle:)`
    /// attempt is kept first so that a future toolchain which does emit a metallib
    /// is picked up automatically, and `librarySource` records which path was
    /// taken so the change would be visible rather than silent.
    private static func loadLibrary(device: MTLDevice) -> (MTLLibrary, LibrarySource)? {
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.module),
           library.functionNames.contains(MetalKernel.monochrome) {
            return (library, .bundledMetallib)
        }
        guard let url = Bundle.module.url(forResource: "FrameRender", withExtension: "metal"),
              let source = try? String(contentsOf: url, encoding: .utf8),
              let library = try? device.makeLibrary(source: source, options: nil) else {
            return nil
        }
        return (library, .runtimeCompiled)
    }

    /// A compute pipeline state for a kernel, compiled once and reused.
    ///
    /// There are no function constants to key on: the per-pixel decisions the plan
    /// proposed specialising (`isSigned`, `bitShift`) are folded into the window
    /// table before the shader ever sees them, and the two that remain
    /// (`bytesPerSample`, `planarConfiguration`) are uniform branches — free on
    /// Apple GPUs, where every thread in a dispatch takes the same side. So the
    /// cache is keyed on the function name alone.
    public func pipelineState(for functionName: String) -> MTLComputePipelineState? {
        lock.lock()
        if let cached = pipelineStates[functionName] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let function = library.makeFunction(name: functionName),
              let state = try? device.makeComputePipelineState(function: function) else {
            return nil
        }

        lock.lock()
        pipelineStates[functionName] = state
        lock.unlock()
        return state
    }

    /// Whether this device addresses one pool of memory with the CPU.
    ///
    /// The condition the whole zero-copy design rests on. False on Intel Macs with
    /// a discrete GPU, where `RenderBackend.automatic()` therefore chooses `.cpu`.
    public var hasUnifiedMemory: Bool { device.hasUnifiedMemory }
}

/// Kernel function names, in one place so Swift and the smoke test cannot drift
/// from the `.metal` file.
public enum MetalKernel {
    public static let monochrome = "render_monochrome"
    public static let color = "render_color"
    public static let palette = "render_palette"

    public static let all = [monochrome, color, palette]
}
#endif
