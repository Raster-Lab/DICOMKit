# GPU (Metal) Image Rendering — Implementation Plan

Goal: move DICOM frame rendering — window/level, photometric interpretation, palette/colour
mapping, and the interactive spatial transforms (zoom, pan, rotate, flip, invert) — onto the
GPU via Metal compute, **exploiting Apple Silicon's Unified Memory Architecture (UMA) so that
pixel data is never copied between CPU and GPU**, with a CPU path retained as an
always-available fallback.

**Verdict: feasible, and the repo is better positioned for it than it looks.** Metal is already
in the dependency graph (`J2KMetal`, wired at `Package.swift:257`), and there is an established
in-repo pattern for GPU/CPU backend selection to mirror
(`Sources/DICOMCore/CodecBackend.swift` — `.metal` → `.accelerate` → `.scalar` with
`J2KMetalDevice.isAvailable`). The deployment baseline is macOS 15 / iOS 18
(`Package.swift:9-12`), so no Metal feature gating is needed.

Estimated **11–15 working days** to a shipped, tested GPU display path (Milestones 0–7), of
which the first ~3 days deliver most of the measurable speedup and are prerequisites for the
GPU work regardless.

Two design decisions carry this plan, and both are non-negotiable for it to be worth doing:
a **shared integer LUT** (which makes GPU output bit-exact with CPU output) and **UMA zero-copy
buffers** (which remove the upload and readback that would otherwise eat the speedup). They are
described next, in that order.

---

## Design pillar 1: a shared integer LUT, not float shader math

This is what makes a GPU path *safe* in this codebase, so it comes first.

This repo's core invariant is **one shared render decision between the CLIs and the app** —
stated at `Sources/DICOMKit/ImageExport/DICOMImageExporter.swift:281-283`, exercised by
`dicom-export` (`Sources/dicom-export/main.swift:108,470`) and `dicom-convert`
(`Sources/dicom-convert/DICOMConvert.swift:210`), and asserted byte-for-byte in
`Tests/DICOMKitTests/ExportWindowParityTests.swift`. A naive Metal shader that recomputes
window/level in `float` will not reproduce the CPU's `Double` math bit-for-bit, and that
divergence would break the parity contract the whole project is built on.

The fix is to make the GPU shader do **no floating-point work at all**.

Observe that in the CPU loop at `Sources/DICOMKit/PixelDataRenderer.swift:100-138`, everything
from line 117 to line 137 — bit shift, mask, sign extension, `window.apply(to:)`
(`Sources/DICOMCore/WindowSettings.swift:63`), MONOCHROME1 inversion, clamp to `UInt8` — depends
on exactly one variable, `rawValue`. Every other input is a per-frame constant hoisted at lines
95-98. That block is therefore a pure function `Int → UInt8` over at most 65,536 inputs.

So:

1. Build a 65,536-entry `[UInt8]` table **once per render**, on the CPU, using the *existing*
   `WindowSettings.apply` code — unchanged, so the values are by construction identical to
   today's output.
2. Upload it to the GPU as a 1D `.r8Unorm` texture (64 KB).
3. The shader's entire per-pixel job becomes: read bytes → assemble integer → sample the table
   → write the byte. Pure integer and texture-fetch work.

**Consequence: GPU output is bit-exact with CPU output**, the parity tests keep passing
unmodified, and "what you see is what you print" holds exactly. It also makes the expensive
window functions free — `applySigmoid` (`WindowSettings.swift:101`) currently calls `exp()`
*per pixel*; under the LUT it is called 65,536 times regardless of image size.

The same table is what the CPU path should use too, which is why Milestone 1 is shared work
rather than throwaway scaffolding.

---

## Design pillar 2: UMA — zero-copy, not upload/render/readback

On Apple Silicon the CPU and GPU address **the same physical memory**. There is no discrete VRAM
and therefore no reason to copy pixel data across a bus. A naive Metal port would still do
`memcpy` → upload → dispatch → readback, and for a 3000×4000 16-bit MG frame that is **24 MB in
and 12 MB out per render** — enough to erase the entire benefit of moving the maths to the GPU.
The whole point of doing this on Apple hardware is that both of those copies can be **zero**.

The rule for this project: **on a unified-memory device, no pixel buffer is ever copied. The
decoded frame the CPU already holds is the same memory the shader reads, and the byte buffer the
shader writes is the same memory `CGImage` displays.**

### Input: wrap the decoded frame in place

`FrameSourceCache` already holds decoded pixel bytes on the CPU. Rather than allocating an
`MTLBuffer` and copying into it, wrap that allocation directly:

```swift
// Zero copy — the GPU reads the CPU's existing decoded-frame allocation.
let buffer = device.makeBuffer(bytesNoCopy: pageAlignedPointer,
                               length: pageAlignedLength,
                               options: [.storageModeShared],
                               deallocator: nil)
```

`makeBuffer(bytesNoCopy:)` requires the pointer to be page-aligned and the length rounded up to a
page multiple (`vm_page_size` — 16 KB on Apple Silicon). That means `FrameSourceCache` must
allocate decoded frames with `posix_memalign` / an aligned `UnsafeMutableRawBufferPointer` rather
than as a plain Swift `[UInt8]`. **This is a real change to the decode path and is scheduled as
its own milestone (M2b) — it is the single most invasive prerequisite in the plan.**

Where an aligned allocation genuinely cannot be arranged, fall back to a pooled
`.storageModeShared` buffer and one `memcpy`. Still no bus transfer — just an avoidable
in-memory copy.

### Output: let `CGImage` read the shader's own memory

The readback in a conventional design (`getBytes` from a `.private` texture) disappears entirely.
Allocate the output as a `.storageModeShared` `MTLBuffer`, create a **texture view onto that
buffer** so the kernel can write to it, and then hand the *same* memory to Core Graphics:

```swift
let out = device.makeBuffer(length: alignedBytesPerRow * height, options: [.storageModeShared])!
let view = out.makeTexture(descriptor: desc,            // .shaderWrite usage
                           offset: 0,
                           bytesPerRow: alignedBytesPerRow)

// …dispatch, commandBuffer.waitUntilCompleted()…

// No getBytes, no copy: CGImage is backed by the buffer the GPU just wrote.
let provider = CGDataProvider(dataInfo: retainedBuffer,
                              data: out.contents(),
                              size: out.length, releaseData: release)!
let image = CGImage(width: width, height: height, ..., provider: provider, ...)
```

`bytesPerRow` must satisfy `device.minimumLinearTextureAlignment(for: .r8Unorm)`, so the row
stride is padded and passed to `CGImage` as-is — do not assume `width == bytesPerRow`.

This matters more than it first appears: it means **M3 alone already delivers a zero-copy
pipeline**, while keeping the `CGImage` output type that all ~12 existing consumers expect. No
call site changes. M5's zero-copy display path then becomes an optimisation of the spatial
transforms rather than the thing that unlocks the performance.

### Coherency and hazard tracking

`.storageModeShared` is coherent on Apple Silicon at command-buffer boundaries — there is **no
`didModifyRange`, no `synchronize(resource:)`, no blit encoder**. Those are `.storageModeManaged`
concerns and `.managed` does not exist on Apple Silicon. Do not port that ceremony in from
generic Metal samples; it is pure overhead here.

For pooled buffers whose lifetime we manage explicitly, prefer
`[.storageModeShared, .hazardTrackingModeUntracked]` to skip Metal's automatic dependency
tracking, and allocate the pool from an `MTLHeap` so buffer reuse across dispatches costs nothing.

### Non-UMA hardware: fall back to CPU, do not build a second Metal path

macOS 15 still runs on some 2018–2020 Intel Macs, a few with discrete AMD GPUs, where
`MTLDevice.hasUnifiedMemory == false`. On those machines the copies are unavoidable and the win
over an LUT-accelerated CPU renderer is marginal.

**Decision: `RenderBackend.automatic()` selects `.metal` only when `device.hasUnifiedMemory` is
true; otherwise `.cpu`.** We do not build and maintain a staging-buffer/`.private`/blit variant
for hardware that is out of the support window within this plan's lifetime. This removes an
entire class of storage-mode branching from the shaders and the equivalence tests, and the
LUT-accelerated CPU path (M1) is a perfectly good answer for those machines.

`.metal` remains forceable via `RenderBackendPreference.metal` on non-UMA devices for
diagnostics, taking the pooled-`memcpy` route; it is not the automatic choice.

---

## Current state (what we are replacing)

| Concern | Where | Today |
|---|---|---|
| Monochrome window/LUT | `Sources/DICOMKit/PixelDataRenderer.swift:100-138` | Scalar `Double`, single-threaded, branch per pixel |
| RGB / YBR | `PixelDataRenderer.swift:180-236`, second pass `:394-408` | Two full CPU passes |
| Palette colour | `PixelDataRenderer.swift:283-321` | Scalar loop, `Sources/DICOMCore/PaletteColorLUT.swift` |
| Focused-viewer render | `Sources/DICOMStudio/ViewModels/ImageViewerViewModel.swift:594` (`renderCurrentFrame`), driven by `:761` `adjustWindowLevel` | **Synchronous on the main actor, full resolution, no cache, no coalescing** — a full pass per mouse delta |
| Tile / film render | `Sources/DICOMStudio/Services/FrameRenderer.swift:75` | `Task.detached` (`:88`), decoded pixels cached via `FrameSourceCache` |
| Render cache | `Sources/DICOMStudio/Services/FrameImageStore.swift:114-132`, key at `FrameRenderer.swift:25` | Key includes window/zoom/rotation/flip/invert → every window change is a miss by design |
| Rotate / flip / crop | `FrameRenderer.swift:158-207` | CPU `CGContext` |
| Zoom resample | `FrameRenderer.swift:214-238` | CPU `CGContext`, `.high` interpolation |
| Invert | `Sources/DICOMStudio/Components/ImageInversion.swift:23` | Full `CGContext` draw + difference blend |
| Overlay plane burn | `Sources/DICOMKit/OverlayPlaneRenderer.swift:181,215-225,346-348` | Per-pixel CPU |
| Display | `Views/ImageViewerView.swift:439`, `Views/ProgressiveImageView.swift:63` | `Image(decorative: cgImage)`; zoom/pan/rotate/flip applied as SwiftUI modifiers |

There is no Metal, `MTLDevice`, `MTKView`, or `CIContext` anywhere in `Sources/DICOMStudio` or
`Sources/DICOMPrintKit` today. `Sources/DICOMKit/Performance/SIMDImageProcessor.swift:25`
(`applyWindowLevel`) exists but has **zero production callers**.

Roughly **12 sites consume the finished `CGImage`** (viewer, tiles, series thumbnails, print
film composition at `DICOMPrintKit/Printing/ComposedFilm.swift:218` and `FilmComposer.swift:331`,
export, and the CLIs). This is why the plan reaches a zero-copy display path in two stages
rather than one.

---

## Target architecture

New target **`DICOMRenderKit`**, sitting between `DICOMCore` and `DICOMStudio`. It is a separate
target — not folded into `DICOMKit` — so the headless `dicom-*` executables never link Metal and
CI without a GPU is unaffected.

```
DICOMCore ──> DICOMRenderKit ──> DICOMStudio
   │              │
   │              ├── RenderBackend.swift        (mirrors CodecBackend.swift)
   │              ├── FrameRenderBackend.swift   (protocol both impls satisfy)
   │              ├── CPUFrameRenderer.swift     (wraps PixelDataRenderer — the fallback)
   │              ├── Metal/MetalRenderDevice.swift
   │              ├── Metal/MetalFrameRenderer.swift
   │              ├── Metal/UnifiedMemoryPool.swift  (bytesNoCopy wrapping + MTLHeap reuse)
   │              └── Metal/FrameRender.metal.txt  (shader source, shipped as a resource)
   │
   └── WindowLUT.swift   (shared table builder — CPU and GPU both consume it)
```

`WindowLUT` lives in **`DICOMCore`**, not `DICOMRenderKit`, because the CPU path and the CLIs
must use the identical table.

### Backend selection — mirror the existing pattern

`Sources/DICOMCore/CodecBackend.swift` already establishes the house idiom: an enum with a
`displayName`, an `isAvailable` check, an auto-selecting priority chain (`:93-97`), and a
`...Preference` struct with a `.forced` initialiser (`:152`). `RenderBackend` should be a direct
analogue:

```swift
public enum RenderBackend: String, Sendable, CaseIterable {
    case metal          // GPU compute
    case cpu            // PixelDataRenderer — always available

    public var displayName: String { ... }
    public var isAvailable: Bool { ... }

    /// `.metal` only on unified-memory devices — see "Design pillar 2".
    public static func automatic() -> RenderBackend { ... }
}

public struct RenderBackendPreference: Sendable {
    public static let automatic = RenderBackendPreference()
    public static let metal     = RenderBackendPreference(forced: .metal)
    public static let cpu       = RenderBackendPreference(forced: .cpu)
}
```

Following the existing pattern means the Studio settings UI, the benchmark harness, and any
future `--render-backend` CLI flag all get a shape the codebase already knows.

### Shader interface

One `.metal` file, one compute kernel per photometric family, sharing an unpack helper.
Function constants (`[[function_constant(n)]]`) specialise `bytesPerSample`, `isSigned`, and
`planarConfiguration` at pipeline-build time rather than branching per pixel.

```metal
struct FrameParams {
    uint  width, height;
    uint  bitShift, storedBitMask, bitsStored;
    uint  samplesPerPixel;
    uint  isMonochrome1;      // applied when building the LUT, kept for colour paths
};

kernel void render_monochrome(
    device   const uchar*   frameBytes  [[buffer(0)]],
    constant FrameParams&   p           [[buffer(1)]],
    texture1d<float, access::sample> lut [[texture(0)]],   // 65536 × r8Unorm
    texture2d<float, access::write>  out [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{ ... }
```

Pixel data is passed as a **buffer, not a texture** — DICOM packing is irregular (12 bits stored
in 16 allocated, `planarConfiguration` 0 vs 1, YBR variants) and does not map onto a native
`MTLPixelFormat`. Unpacking in the kernel is cheap, and a buffer is what lets the input be
wrapped `bytesNoCopy` over the decoded frame the CPU already holds (Design pillar 2). A texture
input would force a format conversion and therefore a copy.

The output is likewise a `.storageModeShared` buffer with a texture view over it for
`access::write`, so the kernel's writes land directly in the memory `CGImage` will read. Every
resource in the kernel signature is shared-storage; nothing is `.private`.

### SwiftPM and the metallib

SwiftPM compiles `.metal` files found in a target's sources into a `default.metallib` inside the
target's resource bundle. Load it with
`device.makeDefaultLibrary(bundle: Bundle.module)` — **not** the argument-less
`makeDefaultLibrary()`, which looks in the main app bundle and will return `nil` from a library
target. This is the single most common way this wiring fails; Milestone 2 has a smoke test for
exactly it.

---

## Milestones

### M0 — Benchmark harness and baseline · ~1 day — **LANDED**

Nothing else in this plan can be judged without numbers.

- Add `Tests/DICOMRenderKitTests/RenderBenchmarks.swift` (or a `swift run` bench target) timing a
  full `renderMonochromeFrame` across representative sizes: CT 512×512, CR/DX 2048×2500, MG
  3000×4000, plus an RGB and a palette-colour case.
- Instrument the real interaction: wall-clock per `adjustWindowLevel`
  (`ImageViewerViewModel.swift:761`) during a synthetic drag, and frame-to-frame latency in cine.
- Measure a plain `memcpy` of each frame size, and log `MTLDevice.hasUnifiedMemory` and
  `recommendedMaxWorkingSetSize` for the test machine. This quantifies exactly what Design pillar
  2 is buying — if the copies were going to be cheap, we want that on record before building
  around avoiding them.
- Record baselines in this file so every later milestone reports a delta.

**Exit:** a committed baseline table. ✅ See "Measured results" below.

**As built:** `Tests/DICOMKitTests/RenderBenchmarks.swift` — DICOMKitTests rather than the
not-yet-existing `DICOMRenderKitTests`; it moves when M2 creates that target. Skipped unless
`DICOMKIT_RUN_RENDER_BENCH=1`, so it costs the normal test pass nothing:

```
DICOMKIT_RUN_RENDER_BENCH=1 swift test -c release --filter RenderBenchmarks
```

Release is mandatory — a debug build's bounds checking dominates the scalar loop and would
flatter every later milestone. The synthetic drag stands in for `adjustWindowLevel`: 60 renders
at 60 distinct windows, reported per step.

### M1 — `WindowLUT` and CPU adoption · ~1.5 days — **LANDED**

- New `Sources/DICOMCore/WindowLUT.swift`: builds `[UInt8]` (65,536 or 256 entries) from
  `WindowSettings` + `PixelDataDescriptor`, folding shift, mask, sign extension, window,
  MONOCHROME1 and clamp — reusing `WindowSettings.apply` verbatim.
- Rewrite the `PixelDataRenderer.swift:100-138` inner loop as a table lookup.
- Cache the table on the descriptor+window pair so repeated renders at one window skip the build.

**Exit:** all existing tests green **with no golden regeneration** — the output is bit-identical
by construction. `ExportWindowParityTests` must pass untouched; if it does not, the LUT is wrong.
Report the M0 delta. ✅

**As built:**

- `Sources/DICOMCore/WindowLUT.swift` — `WindowLUT.grayscale(descriptor:window:)` returns a
  cached table; `makeGrayscale` builds one unconditionally. The build loop is a verbatim
  transcription of the old per-pixel chain, hoisted over its single input.
- The cache key (`WindowLUT.Parameters`) carries **only** what changes a table entry: entry
  count, bit shift, stored-bit mask, signedness, bits stored, MONOCHROME1, and the window's
  centre/width/function. Rows, columns and frame count are excluded, so every differently-sized
  image in a study shares one table; `explanation` is excluded, so a labelled window
  ("SOFT TISSUE") does not split the cache from an unlabelled one with the same numbers.
- Capacity 4, MRU, `NSLock`-guarded, built outside the lock — a duplicate build under contention
  is harmless because the tables are equal.
- `PixelDataRenderer.renderMonochromeFrame` now iterates
  `min(totalPixels, frameData.count / bytesPerSample)` and indexes the table through
  `withUnsafeBytes`/`withUnsafeBufferPointer`. Samples past the end of a short frame stay 0, as
  they did when the scalar loop broke out of its bounds check.
- `Tests/DICOMKitTests/WindowLUTParityTests.swift` re-implements the *original* scalar chain as
  an oracle and asserts byte equality over **every** table entry, for 20 descriptor shapes
  (8/10/12/16-bit, signed and unsigned, non-zero bit shift, MONOCHROME1 and MONOCHROME2) × 8
  windows (including width 1, negative centres, LINEAR_EXACT and SIGMOID) — then again end to
  end through rendered frames.

One deliberate behaviour change: a descriptor with `bitsAllocated == 0` now returns a black
frame instead of reading past the end of the buffer. The old loop's `offset + 0 <= count` guard
always passed and it then read two bytes anyway.

`swift test` is green on the whole package apart from
`CompressionConsoleTests.testCompressBackendReporting`, which **fails identically on a clean
checkout of `main`** — it asserts a lossless J2K encode never reports "Metal (GPU)", but
`CodecBackend.effectiveEncodeBackend` deliberately dispatches lossless to the GPU (the
reversible path has been bit-exact since J2KSwift v11.0.1). Stale test, unrelated to this work,
not fixed here.

> This milestone is not optional preparation that GPU work later discards. The table it produces
> *is* the GPU's window operator, and it is also what keeps `dicom-export`, `dicom-convert`, print
> film burn, and headless CI fast — none of which the GPU path will ever serve.

### M2 — `DICOMRenderKit` target, Metal device, pipeline plumbing · ~1.5 days — **LANDED**

- Add the target to `Package.swift`; add `DICOMRenderKit` to the `DICOMStudio` dependency list
  (`Package.swift:~910`).
- `MetalRenderDevice`: a `Sendable` singleton holding `MTLDevice`, `MTLCommandQueue`, an
  `MTLHeap` for the buffer pool, and a pipeline-state cache keyed by kernel + function constants.
  Graceful `nil` when no device.
- `RenderBackend` / `RenderBackendPreference` per the pattern above, with `automatic()` gated on
  **`device.hasUnifiedMemory`** — non-UMA hardware resolves to `.cpu`.
- `FrameRenderBackend` protocol; `CPUFrameRenderer` conforming by delegating to
  `PixelDataRenderer`.
- Stub shader + a smoke test that loads the library via `Bundle.module` and builds a
  pipeline state.

**As built — one plan assumption was wrong, and it was the one flagged as riskiest.**

> SwiftPM does **not** compile `.metal` files. A `.metal` file in a target's sources is
> silently ignored on this toolchain: no `default.metallib`, no resource bundle, no warning —
> `Bundle.module` is not even generated. Verified with a minimal probe package before changing
> course, because the failure mode is invisible: everything builds and only the GPU path goes
> missing.
>
> The shader therefore ships as a **bundle resource** (`.copy`) and is compiled with
> `device.makeLibrary(source:)` once per process. One source of truth for the kernels, one small
> compile at first GPU render, no toolchain dependency.
>
> **Xcode is the mirror image of this, and it broke the app build.** Xcode's build system matches
> its `CompileMetalFile` rule on the `.metal` extension alone — even for a file declared as a
> *resource* rather than a source — and then hard-fails the entire build when the optional Metal
> Toolchain component is not installed: `cannot execute tool 'metal' due to missing Metal
> Toolchain`. Since Xcode 26 that component is a separate multi-gigabyte download, so a clean
> machine could `swift build` fine and still not build DICOMStudio.
>
> The shader is consequently named **`FrameRender.metal.txt`** — no build rule claims it, so
> `swift build`, `xcodebuild` and CI all take the identical runtime-compile path and none of them
> needs the toolchain. Ahead-of-time compilation was the alternative, and was rejected: it would
> apply only under Xcode and only with the extra download, which would leave the shipping app
> running a shader binary that `swift test` and CI never exercise. For a renderer whose whole
> correctness argument is bit-identical output with the CPU, one path everywhere is worth more
> than a first-render saving. `MetalPlumbingTests` asserts the resource is present *and* that its
> extension is not `.metal`, because neither failure is visible to `swift build`.

Also as built, deviating deliberately:

- **No function constants.** The plan wanted `bytesPerSample`, `isSigned` and
  `planarConfiguration` specialised at pipeline-build time. `isSigned` and `bitShift` are folded
  into the table before the shader sees them, and the two that remain are uniform branches —
  free on Apple GPUs, where every thread takes the same side. The pipeline cache is keyed on
  function name alone.
- **No `MTLHeap`.** `UnifiedMemoryPool` uses a size-keyed free list. Reuse is equally free (a hit
  allocates nothing at all), and with the handful of distinct buffer sizes a viewer uses, heap
  sub-allocation would buy nothing for its extra lifetime rules.

**Exit:** `swift build` and `swift test` green on a GPU machine **and** with Metal forced off. ✅
10 plumbing tests, including one asserting `automatic()` picks `.metal` only on unified memory.
`RenderBackend.automatic()` reports `.metal` on Apple Silicon and `.cpu` on a non-UMA device.

### M2b — Page-aligned decoded-frame allocation · ~1 day — **LANDED**

The prerequisite for zero-copy input, and the most invasive change in the plan because it reaches
back into the decode path rather than the render path.

- Introduce an aligned pixel-buffer type in `DICOMCore` (`posix_memalign` to `vm_page_size`,
  length rounded up to a page multiple) and have `FrameSourceCache`
  (`Sources/DICOMStudio/Services/FrameSourceCache.swift`) hold decoded frames in it instead of a
  plain `[UInt8]`.
- Keep the existing `[UInt8]`-shaped accessor so `PixelDataRenderer` and every CPU consumer are
  unaffected. This must be a storage change only, with no observable behaviour change.
- `UnifiedMemoryPool.wrap(_:)` returns an `MTLBuffer` via `makeBuffer(bytesNoCopy:)` for aligned
  input, and transparently falls back to a pooled shared buffer + `memcpy` for unaligned input, so
  correctness never depends on the alignment succeeding.

**Exit:** full suite green with the new storage; a unit test asserting `bytesNoCopy` wrapping
actually takes the no-copy path (`buffer.contents() == originalPointer`) for a cached frame. ✅

**As built — far less invasive than scheduled.** The plan expected this to reach back into the
decode path. It does not need to: `AlignedPixelBuffer` (`Sources/DICOMCore/AlignedPixelBuffer.swift`)
copies a decoded `PixelData` into page-aligned storage **once, when a file enters
`FrameSourceCache`** — 0.54 ms for a 23 MB mammogram, paid per *file*, against a 23 MB copy per
*render* if it were not done. The codec and decode paths are untouched.

`PixelData` gained an optional `alignedStorage`; its `data` is a no-copy view of that allocation,
so every CPU consumer is unaffected and does not know the difference. The `Data` keeps the buffer
alive on its own — the deallocator closure holds the reference — so a caller holding only the
`Data` can never read freed memory. `FrameSourceCache` aligns only when the GPU is the active
backend; on a CPU-only machine the copy would be pure waste.

### M3 — Monochrome compute kernel, end-to-end zero copy · ~2 days — **LANDED**

- Implement `render_monochrome`. `MetalFrameRenderer` wraps the input via `UnifiedMemoryPool`
  (no copy), writes the 64 KB LUT texture, dispatches, and constructs a `CGImage` over the
  output buffer's own memory through a `CGDataProvider` — **no `getBytes`, no readback**.
- Output type stays `CGImage`, so all ~12 consumers are untouched at this stage.
- Pool input and output buffers from the `MTLHeap`; allocate per (dimensions, format), not per
  dispatch.
- **On a window change, nothing is re-wrapped and nothing is re-uploaded except the 64 KB LUT
  texture.** This is the interactive hot path and the reason the drag becomes free.
- Honour `minimumLinearTextureAlignment` for the output row stride and pass the padded
  `bytesPerRow` through to `CGImage`.

**Exit:** `MetalCPUEquivalenceTests` — for every corpus file in
`Tests/DICOMRoundTripTest/Corpus` plus synthetic 8/12/16-bit signed and unsigned cases, GPU and
CPU output must be **byte-for-byte equal**. Not "within tolerance". Plus an allocation assertion:
a steady-state window drag performs **zero** buffer allocations and zero pixel-data copies.
Report the M0 delta. ✅

**As built.** 18 equivalence tests. The corpus at `Tests/DICOMRoundTripTest/Corpus` is empty in
this checkout (user-supplied, never committed), so coverage comes from synthetics — but
exhaustive ones: the full descriptor matrix at 37×23 (dimensions coprime with any threadgroup
size, which is what would expose an off-by-one in the grid rounding that 512×512 would hide),
**every one of the 65,536 representable 16-bit samples**, multi-frame indexing, and unaligned
input.

Two deviations, both toward exactness:

- **The table is a buffer, not an `r8Unorm` texture.** A texture read returns a float in
  〔0,1〕 which must be scaled back to a byte — a round-trip that can quantise. A `device const
  uchar*` indexes exactly.
- **The output is a plain byte buffer, not a texture view.** So `bytesPerRow` is exactly `width`,
  which is what `CGImage` wants, and `minimumLinearTextureAlignment` never enters into it. M5 can
  add a texture view if it ever needs one for display.

### M4 — Colour kernels · ~1.5 days — **LANDED (RGB + palette; YBR stays CPU)**

- `render_rgb` (folding the separate YBR→RGB pass at `PixelDataRenderer.swift:394-408` into the
  single kernel) and `render_palette` (palette tables from
  `Sources/DICOMCore/PaletteColorLUT.swift` uploaded as three 1D textures).
- YBR→RGB must be transcribed as **integer/fixed-point arithmetic matching the CPU exactly**, not
  reformulated in float. Where the CPU uses floating-point coefficients, either pre-bake a LUT or
  accept a documented, tested tolerance for that path specifically — decide it here, explicitly,
  rather than discovering it in review.

**Exit:** equivalence tests extended to colour and palette. Any accepted tolerance is documented
in this file with its justification. ✅

**The YBR decision, made explicitly as the plan required: YBR stays on the CPU, and no tolerance
is accepted anywhere.**

RGB and palette are pure functions of *one* sample, so `ColorSampleLUT` and `PaletteDisplayLUT`
(`Sources/DICOMCore/ColorSampleLUT.swift`) reproduce the CPU's `Double` arithmetic exactly, the
same way `WindowLUT` does. YBR is not: green depends on all three of Y, Cb and Cr, so an exact
table needs 2^24 entries — 16 MB, ~17 million `Double` evaluations to build — and any smaller
formulation means recomputing the coefficients in `float` on the GPU, which diverges from
`Double` at truncation boundaries by one grey level on some pixels. That is precisely what design
pillar 1 exists to prevent.

So `MetalFrameRenderer` **declines** YBR frames and `FrameRenderService` renders them on the CPU,
where they are already fast enough — YBR is ultrasound and secondary capture, not mammography.
`testYBRIsDeclinedByGPUAndStillRenders` asserts both halves: that the GPU refuses, and that the
fallback produces exactly the CPU's bytes. The plan's `render_rgb` was also to fold the separate
YBR→RGB second pass into the kernel; that pass stays on the CPU with the rest of YBR.

### M5 — Direct-to-display path for the focused viewer · ~3 days — **LANDED**

The largest and riskiest milestone. Because M3 already eliminated the copies, this milestone is
**not** where the performance arrives — it is where the *spatial transforms* move onto the GPU and
the `CGImage` construction per frame goes away. Judge it on the M0 cine and zoom/pan numbers, and
be willing to defer it if M3's numbers already clear the 60 fps bar.

- `MetalImageView`: `NSViewRepresentable`/`UIViewRepresentable` wrapping an `MTKView`, rendering
  the output texture through a trivial blit with a vertex transform. Under UMA the drawable and
  the compute output can share an `IOSurface`-backed texture, so presentation is also copy-free.
- Move **zoom, pan, rotation, flip and invert into that transform**. Today they are SwiftUI
  modifiers (`ProgressiveImageView.swift:66-75`, `ImageViewerView.swift:449-455`) layered on top
  of CPU passes (`FrameRenderer.swift:158-238`, `ImageInversion.swift:23`); on the GPU they become
  free, and — importantly — they stop invalidating the render cache, whose key currently includes
  all of them (`FrameRenderer.swift:25`).
- Keep `ProgressiveImageView`'s decode-progress badge behaviour intact, and keep its
  `Image(decorative:)` path as the fallback branch when the backend resolves to `.cpu`.

**Caution:** the comment at `ProgressiveImageView.swift:55-62` records a real prior bug — a
`Canvas`-based viewer blanked *every* progressively-decoded J2K file because the canvas resolved
to zero size under `.aspectRatio`. An `MTKView` has the same hazard class (drawable size vs
layout). Add an explicit non-zero-drawable regression test for the J2K/HTJ2K path before
declaring this milestone done.

**Exit:** interactive window/level, zoom and pan at a sustained 60 fps on an MG frame, with the
CPU fallback branch still rendering correctly when Metal is forced off.

**Built — and the justification is not the window drag.**

This milestone was first deferred on its own stated criterion (M3's numbers already clear the
60 fps bar by 16×), then reinstated on a better argument from the project owner: the value of
keeping the frame on the GPU is not drag latency, it is that **every tool action becomes free**.
The size threshold M3 introduced is not a property of the GPU either — it is a property of
round-tripping each render through a `CGImage`. Once the frame stays in a texture, the fixed
dispatch cost is paid once per *displayed frame* rather than once per *operation*.

Measured, Apple M4, release — one re-render (what a tool action used to imply) against one
redraw with a new transform (what it now costs):

| Case | re-render | redraw per tool step | |
|---|---|---|---|
| MG 3000×4000 | 1.586 ms | **0.008 ms** | 198× |
| CR/DX 2048×2500 | 0.777 ms | **0.008 ms** | 97× |
| CT 512×512 | 0.229 ms | **0.054 ms** | 4× |

**As built:**

- `DisplayFrameTexture` + `DisplayPresentation` + `MetalImageRenderer` + `MetalImageView`
  (`NSViewRepresentable`/`UIViewRepresentable` over `MTKView`). Zoom, pan, rotation, flip and
  inversion are a 4×4 matrix in `display_vertex` and a `1 - x` in `display_fragment`.
- `display_vertex`/`display_fragment` are the **only** floating-point code in the shader,
  and deliberately so: they are *geometry*, not pixel values. Nothing there can change what value
  a pixel has, only where it lands. Inversion is the one exception and is exact — `1 - x` on an
  8-bit unorm round-trips through the same 256 levels.
- **One dispatch, two views of it.** `renderForDisplay` returns the texture *and* a `CGImage` over
  the same output buffer, so having both costs nothing. The buffer returns to the pool only when
  both are released — they share one owner (`OutputBufferBox`); recycling while either was still
  reading would corrupt what is on screen.
- The kernels gained an `outputRowStride` parameter. The `CGImage` path keeps a dense stride so
  the equality tests can compare whole buffers; the display path pads to
  `minimumLinearTextureAlignment`, which a texture view over a buffer requires.
- **The sampler is `nearest`, not `linear`.** The existing viewer builds its `CGImage` with
  `shouldInterpolate: false`, so zooming in shows actual pixels rather than a smoothed guess.
  Switching to linear here would silently change what is on screen.
- The display path deliberately ignores `minimumGPUPixelCount`: a frame already headed for a GPU
  texture has no cheaper route, whatever its size.
- `toggleInversion()` no longer re-renders when the display path is active.

**Two frames deliberately keep the CPU path**, and the viewport falls back to
`Image(decorative:)` for them:

1. **Frames with overlay planes.** Overlays are burned into the `CGImage`; the display path does
   not burn them. Some Secondary Captures — Siemens' Patient Protocol is the standing example —
   carry all-zero pixel data with their entire content in a 1-bit overlay, so showing the texture
   would present a blank square where a page of text belongs.
   `testOverlayFrameDoesNotUseDisplayTexture` holds this.
2. **Anything reaching the auto-window or stored-window fallback rungs**, which produce a
   `CGImage` only.

**The drawable-size hazard is tested, not trusted.** The plan's caution here is a real prior
incident: a `Canvas`-based viewer blanked *every* progressively-decoded J2K file when the canvas
resolved to zero size under `.aspectRatio`. `DisplayPresentation.transform` returns `nil` for a
degenerate viewport rather than dividing by zero, `MetalImageRenderer` records
`lastDrawHadZeroSizedDrawable`, and both halves are asserted — a zero-sized drawable must refuse
to draw, and a sized one must draw. A renderer that never drew anything would otherwise pass the
first half alone.

**What M5 did *not* change:** `FrameRenderer.cacheKey` still carries zoom/rotation/flip/invert.
The display path is the focused viewport only; tiles and the film preview still apply their
transforms on the CPU in `FrameRenderer.applying`, so those transforms still change the pixels
the key identifies. Removing them from the key would reintroduce the exact bug the key's own doc
comment warns about. That rework belongs with moving the *tile* path onto the display renderer,
which is a separate piece of work.

### M6 — Extend to tiles, film preview and thumbnails · ~1.5 days — **LANDED (cache-key rework deferred with M5)**

- Route `FrameRenderer.render` (`FrameRenderer.swift:75`) through `FrameRenderBackend`.
- Rework the `FrameRenderer.cacheKey` (`:25`) so GPU-side transforms are no longer part of the
  key — the cache should key on decoded frame + window only.
- `ViewerTileImageCache` (1024 px), `PrintThumbnailCache` (512 px) and series thumbnails (256 px)
  keep their existing size caps; they draw into `CGImage` and stay on the readback path.
- **Print film composition and export stay on the CPU.** `ComposedFilm.swift:218`,
  `FilmComposer.swift:331` and `DICOMImageExporter.renderFrameForExport:293` are the shared
  CLI↔app surface; they inherit M1's speedup and must not diverge.

**As built.** `FrameRenderer.render` now builds a `FrameRenderRequest` and calls
`FrameRenderService.shared`. Window *resolution* deliberately stays where it was — which window a
frame gets is `DICOMImageExporter.determineWindowSettings`' policy, shared with the CLIs; only the
per-pixel mapping moved. `FrameSourceCache` page-aligns each decoded file once so those renders
are zero-copy. Print and export were already on `PixelDataRenderer` directly and are untouched;
because GPU and CPU output are byte-identical, a GPU-rendered tile and the CPU-rendered film it
prints to cannot disagree regardless.

The cache-key rework is **not** done — see M5.

### M7 — Fallback guarantees, CI and docs · ~1 day — **LANDED**

- Force-CPU environment override (`DICOMKIT_RENDER_BACKEND=cpu`) for support and CI.
- CI matrix runs the full suite with Metal forced off, so no test may silently depend on a GPU.
- Surface the active backend in Studio (the codec backend is already surfaced this way — follow it).
- Update `Sources/DICOMKit/DICOMKit.docc/RenderingImages.md` and record final numbers here.

**As built.** `DICOMKIT_RENDER_BACKEND=cpu|metal` is honoured, and it **outranks a forced
preference** — including code that hard-codes `.metal`. That is the point of the variable: it
exists so support can say "run with the GPU off" and have it actually happen, which it would not
if any code path could ignore it.

CI (`.github/workflows/ci.yml`) re-runs the render suites with the backend pinned to CPU, so no
test can silently come to depend on a GPU — the failure that would otherwise only appear on
machines without one, which is where support calls come from and not where CI runs.

Studio's Platform tab gained a **Render Backends** box beside the existing Codec Backends box.
Two different questions matter when a call opens with "it's slow" or "the picture looks wrong":
which backend decompressed the pixels, and which one windowed them for the screen. They are
chosen independently, so showing only the codec backend answers half of it.

---

## Measured results

Machine: **Apple M4**, 10 cores, 16 GB, `hasUnifiedMemory = true`,
`recommendedMaxWorkingSetSize = 11.8 GB`, `maxThreadsPerThreadgroup = 1024×1024×1024`.
Release build, best of 5 runs (best-of, not mean: we are measuring the cost of the work, and the
fastest run is the least polluted by scheduling noise).

The M4 reports unified memory, so `RenderBackend.automatic()` will resolve to `.metal` here and
design pillar 2 applies in full.

### Full-frame monochrome render — M0 baseline → M1

| Case | VOI function | M0 (scalar) | M1 (LUT) | Speedup |
|---|---|---|---|---|
| CT 512×512 16-bit | LINEAR | 1.606 ms | **0.162 ms** | 9.9× |
| CR/DX 2048×2500 16-bit | LINEAR | 30.627 ms | **2.161 ms** | 14.2× |
| MG 3000×4000 16-bit | LINEAR | 73.935 ms | **7.226 ms** | 10.2× |
| CT 512×512 16-bit | SIGMOID | 2.180 ms | **0.151 ms** | 14.4× |
| CR/DX 2048×2500 16-bit | SIGMOID | 41.821 ms | **2.177 ms** | 19.2× |
| MG 3000×4000 16-bit | SIGMOID | 100.264 ms | **7.303 ms** | 13.7× |

The sigmoid penalty is gone outright. `applySigmoid` called `exp()` per pixel — 12 million times
for an MG frame; under the table it is called 65,536 times whatever the image size, so SIGMOID
now costs the same as LINEAR (7.303 vs 7.226 ms) instead of 36% more.

### Interaction

| Case | M0 baseline | M1 | Speedup |
|---|---|---|---|
| Window drag, CT 512×512 (per step) | 1.623 ms | **0.262 ms** | 6.2× |
| Window drag, CR/DX 2048×2500 (per step) | 31.186 ms | **2.301 ms** | 13.6× |
| Window drag, MG 3000×4000 (per step) | 78.520 ms | **7.448 ms** | 10.5× |
| Cine, CT 512×512 (per frame) | 1.614 ms | **0.168 ms** | 9.6× |
| Cine, CR/DX 2048×2500 (per frame) | 30.927 ms | **2.232 ms** | 13.9× |

A drag rebuilds the table on every step (each mouse delta is a new window, so no cache hit);
cine reuses one. The gap between the two — 7.448 vs ~7.2 ms on MG — is the whole cost of a table
build, ≈0.2 ms, and it is flat in image size.

**This bears directly on M5.** The 60 fps budget is 16.7 ms per step, and the MG drag now fits
inside it at 7.4 ms with room to spare, on the largest frame size we care about, before any GPU
work at all. M5's justification therefore has to come from the spatial transforms and the
per-frame `CGImage` construction, not from the window maths — which is what the milestone
already says, but the numbers now say it too.

### Colour — unchanged, as expected

| Case | M0 | M1 |
|---|---|---|
| RGB 1024×1024 8-bit | 8.176 ms | 8.437 ms |
| PALETTE 512×512 8-bit | 1.314 ms | 1.319 ms |

M1 touched only the monochrome path; the difference is run-to-run noise. Both are still scalar
`Double` loops and are M4's target. Note the palette path is the same
`raw sample → colour` pure function the window LUT exploits, over three output bytes instead of
one, so it can have the identical treatment when M4 arrives.

### GPU — M3 / M4

Measured in the same run as the CPU column beside it, so the two are directly comparable.
Pixel data is page-aligned first, as it is in the app — benchmarking unaligned input would
measure a copy the real path never makes.

| Case | CPU (M1) | GPU (M3/M4) | Speedup |
|---|---|---|---|
| MG 3000×4000 render | 6.313 ms | **0.780 ms** | 8.1× |
| CR/DX 2048×2500 render | 2.717 ms | **0.810 ms** | 3.4× |
| CT 512×512 render | 0.156 ms | 0.254 ms | **0.6× — CPU wins** |
| MG 3000×4000 drag (per step) | 7.079 ms | **1.023 ms** | 6.9× |
| CR/DX 2048×2500 drag (per step) | 2.880 ms | **0.586 ms** | 4.9× |
| CT 512×512 drag (per step) | 0.261 ms | 0.325 ms | **0.8× — CPU wins** |
| RGB 1024×1024 | 8.576 ms | **0.390 ms** | 22.0× |
| PALETTE 512×512 | 1.327 ms | **0.247 ms** | 5.4× |

**The small-frame result is the important one, and it changed the design.** A dispatch — encode,
commit, wait — costs about 0.24 ms whatever the image size, while the LUT-based CPU renderer runs
at roughly 0.53 ms per megapixel. Below about half a megapixel the fixed cost dominates and the
GPU *loses*. Sending everything to the GPU because it is available would have made the most
common render in the app — tiles and thumbnails — measurably slower.

So `MetalFrameRenderer.minimumGPUPixelCount` is **1 megapixel**: past the crossover with margin,
and it keeps every tile (1024 px), print thumbnail (512 px) and series thumbnail (256 px) render
on the CPU where they belong. `testSmallFramesAreDeclinedByTheProductionRenderer` and
`testLargeFramesAreAcceptedByTheProductionRenderer` hold both sides of the threshold.

One-time cost of page-aligning a decoded file, paid per file on entry to `FrameSourceCache`:
0.008 ms (CT), 0.193 ms (CR/DX), 0.536 ms (MG). The alternative is a copy of the same size on
every render.

### Tool actions — M5

One re-render (what zoom / rotate / invert used to imply) against one redraw with a new
transform (what they now cost), once the frame lives in a GPU texture:

| Case | re-render | redraw per tool step | |
|---|---|---|---|
| MG 3000×4000 | 1.586 ms | **0.008 ms** | 198× |
| CR/DX 2048×2500 | 0.777 ms | **0.008 ms** | 97× |
| CT 512×512 | 0.229 ms | **0.054 ms** | 4× |

### The focused viewport's per-drag decode

Found while wiring M5, fixed separately because it is a pre-existing defect rather than anything
this plan introduced. `ImageViewerViewModel.renderCurrentFrame` reached its pixels through
`DICOMFile.tryRenderFrame` → `tryPixelData()`, which decodes from scratch on every call — and
`adjustWindowLevel` calls it once per mouse event. So a window drag ran the **codec** once per
mouse-move. The tile and film path had solved this years earlier with `FrameSourceCache`; the
focused viewport simply never got the same treatment.

Per drag step, 2048×2500 CR:

| Transfer syntax | decoding each step | cached pixels | |
|---|---|---|---|
| Uncompressed | 2.319 ms | **0.570 ms** | 4× |
| JPEG 2000 lossless | 16.161 ms | **0.558 ms** | 29× |
| JPEG-LS lossless | 74.120 ms | **0.589 ms** | 126× |
| RLE lossless | 354.986 ms | **0.526 ms** | 675× |

RLE was rendering at under three frames a second. Note the uncompressed row: its decode is
0.001 ms, so the 1.7 ms it still saves is `PixelData.frameData(at:)` copying the frame out on
every call — which is why the cache covers uncompressed sources too, not just the obviously
expensive ones.

### Whole journey — M0 baseline to today

| Case | M0 (scalar CPU) | Now | Speedup |
|---|---|---|---|
| MG 3000×4000 render, LINEAR | 73.935 ms | **0.780 ms** | 95× |
| MG 3000×4000 render, SIGMOID | 100.264 ms | **0.780 ms** | 129× |
| MG 3000×4000 drag (per step) | 78.520 ms | **1.023 ms** | 77× |
| RGB 1024×1024 | 8.176 ms | **0.390 ms** | 21× |

### Cost of a copy — what design pillar 2 is buying

| Frame | Size | `memcpy` |
|---|---|---|
| CT 512×512 16-bit | 0.5 MB | 0.007 ms |
| CR/DX 2048×2500 16-bit | 9.8 MB | 0.169 ms |
| MG 3000×4000 16-bit | 22.9 MB | 0.481 ms |

An upload plus a readback of an MG frame is ~0.48 ms in and ~0.25 ms out (the 8-bit output is
half the size), so **≈0.7 ms of pure copying per render**. Against the *current, post-M1* CPU
render of 7.2 ms that is 10% — but the point of the GPU path is to get the render itself well
under a millisecond, and at that target the copies would be the dominant term and would cap the
achievable speedup at roughly 10×. Pillar 2 stands.

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| GPU output diverges from CPU → breaks the CLI↔app parity contract | **High** | Integer-only shader over a shared LUT (pillar 1); byte-equality tests in M3/M4 are the gate, not tolerance checks |
| Copies creep back in and silently eat the speedup | **High** | Pillar 2 is enforced by test, not convention: M3's exit criterion asserts zero allocations and zero pixel copies in a steady-state drag |
| M2b's aligned allocation destabilises the decode path | Medium | Storage-only change behind the existing accessor; `UnifiedMemoryPool` falls back to pooled-copy so correctness never depends on alignment succeeding |
| `Bundle.module` metallib not found from a library target | Medium | M2 smoke test; use `makeDefaultLibrary(bundle:)` explicitly |
| `MTKView` drawable-size-zero blanking, repeating the `Canvas` bug | Medium | Explicit regression test in M5 for the J2K/HTJ2K path |
| Memory pressure: shared buffers count against system RAM, not separate VRAM | Medium | Heap-backed pool with an explicit cap; evict alongside `FrameSourceCache`. UMA means a large cine series competes with the rest of the app for the same pool |
| CI or a headless environment without a GPU | Low | `.cpu` is always available; CI runs Metal-off as a matrix leg |
| Scope creeping into print/export | Low | M6 explicitly fences these to the CPU |

## Non-goals

- GPU rendering for `dicom-*` CLI tools or export/convert output.
- A staging-buffer Metal path for non-UMA (Intel + discrete GPU) hardware — those devices resolve
  to the LUT-accelerated CPU renderer. See Design pillar 2.
- Replacing `PixelDataRenderer` — it remains the reference implementation and the fallback.
- 3D / MPR / volume rendering. **Out of scope for DICOMStudio entirely — not deferred, not a
  follow-on.** Nothing in this plan should be generalised, abstracted, or over-built in
  anticipation of a volume renderer: `MetalRenderDevice`, the buffer pool and the shader
  interface are designed for 2D frame display and may stay that way. If a 3D need ever appears
  it belongs in a separate effort with its own plan.

## Effort summary

| Milestone | Days |
|---|---|
| M0 Benchmarks | 1.0 |
| M1 `WindowLUT` + CPU adoption | 1.5 |
| M2 Target + Metal plumbing | 1.5 |
| M2b Page-aligned frame allocation (UMA prerequisite) | 1.0 |
| M3 Monochrome kernel, end-to-end zero copy | 2.0 |
| M4 Colour kernels | 1.5 |
| M5 Direct-to-display path | 3.0 |
| M6 Tiles / film / thumbnails | 1.5 |
| M7 Fallback, CI, docs | 1.0 |
| **Total** | **14.0** (range 12–16) |

Milestones 0–1 (~2.5 days) are independently shippable and benefit every render path in the
project, including the ones the GPU will never touch. Recommend landing them as their own commit
before opening the Metal work.

**M0 → M3 (~7 days) is the natural first release.** At that point rendering is on the GPU with no
copies in either direction, output is bit-exact with the CPU, and no call site has changed. M4–M7
are then incremental and independently schedulable.
