# DICOMKit Performance Guide

This guide provides best practices and recommendations for optimizing performance when using DICOMKit.

> **Corrective review (2026-08-10).** This guide was audited against the source tree
> (see `Documentation/ResearchAdoption/Current_State_Reconciliation_and_Gap_Report_v0.1.0.md`).
> Claims are now labelled: **[measured]** (named environment + dataset),
> **[example]** (configuration illustration), **[heuristic]** (reasonable default,
> unmeasured), **[hypothesis]** (requires a benchmark before being relied on), or
> **[not implemented]** (the API exists but has no effect today). Unlabelled speed-up
> figures from earlier revisions were unattributed and have been removed. Speed-up
> multipliers from different layers must never be multiplied together.

## Table of Contents

1. [Memory Optimization](#memory-optimization)
2. [Parsing Performance](#parsing-performance)
3. [Image Processing](#image-processing)
4. [JPEG 2000 / HTJ2K / JP3D Performance](#jpeg-2000--htj2k--jp3d-performance)
5. [Network Performance](#network-performance)
6. [Benchmarking](#benchmarking)
7. [Platform Considerations](#platform-considerations)

---

## Memory Optimization

### Memory-Mapped Files — [example]

`ParsingOptions.memoryMapped` is functional (since M2, 2026-08-10):
`DICOMFile.read(from url:)` maps the file with `.mappedIfSafe`, so pages fault in
on demand instead of being read eagerly.

```swift
let file = try DICOMFile.read(from: fileURL, options: .memoryMapped)
```

Do not modify the file while parsed data is alive. There is **no universal
file-size threshold** at which mapping wins — choose per workload and measure
(the earlier "50% reduction >100MB" claim was unattributed and remains
withdrawn). The backing `DICOMByteSource` abstraction (in-memory + file today)
is the seam where pooled-read and network sources will land.

### Selected-Frame Access — [measured]

`DICOMFile.pixelData(frame:)` decodes exactly one frame — via a validated
frame/fragment index (Extended Offset Table → Basic Offset Table →
one-fragment-per-frame → single-frame; malformed tables fail closed) for
encapsulated syntaxes, or a byte-range slice for native ones.

```swift
let frameCount = file.pixelFrameCount ?? 1
let frame = try file.pixelData(frame: 20)   // single-frame PixelData
```

Measured (release, Mac16,13, macOS 26.6, synthetic 256×256×40 RLE, 2026-08-10,
20 iterations): selecting frame 20 via `pixelData()` + slice = median 182.9 ms
(all 40 frames decoded, ~10 MB transient growth); via `pixelData(frame:)` =
**median 4.56 ms, P95 4.63 ms** — 40× faster with no measurable resident-memory
growth. Raw artifact: `Tests/Benchmarks/Artifacts/`. Output is byte-identical to
the all-frames path (asserted in `FrameAccessTests`).

Related APIs (same measurement session):
- `alignedPixelData(frame:)` — [measured] median 4.55 ms: same speed, but the
  frame decodes directly into page-aligned storage Metal wraps with
  `makeBuffer(bytesNoCopy:)`, so the render path skips its `pageAligned()`
  re-copy. RLE also decodes caller-owned (no intermediate output buffer).
- `pixelDataParallel(maxInFlightBytes:)` — [measured] all 40 frames: 181.6 ms
  serial → **34.1 ms** (5.3× on a 10-core machine), bounded by decoded-bytes
  budget, cancellable between frames, byte-identical.
- `pixelDataProgressive(frame:)` — [measured behaviour] for JPEG 2000/HTJ2K:
  coarse reduced-resolution previews stream first, then the exact final frame
  (byte-identical to a direct decode — asserted); other syntaxes emit the final
  frame only. Coarse previews are for display; measurements/exports must use
  the final update.

### Lazy Loading of Pixel Data

When you only need metadata (study information, patient data, etc.), use lazy or metadata-only parsing:

```swift
// Metadata-only (fastest, lowest memory)
let options = ParsingOptions.metadataOnly
let file = try DICOMFile.read(from: data, options: options)

// Access metadata
let patientName = file.dataSet.string(for: .patientName)
let studyDate = file.dataSet.string(for: .studyDate)
// Pixel data is NOT loaded
```

**Caveats:**
- `.metadataOnly` stops parsing at Pixel Data; any elements after (7FE0,0010) are
  not represented in the resulting data set.
- `ParsingOptions.lazyPixelData` — **[not implemented / do not use]**: it does not
  defer pixel loading, it *discards* the pixel bytes (the parser skips fragments
  and stores an empty value with no offset handle; `LazyPixelDataLoader` is never
  wired in). A file read this way cannot yield pixels later.

**Performance Impact — [hypothesis]:** skipping pixel data should reduce time and
memory roughly in proportion to the pixel fraction of the file, but no attributed
measurement exists yet. The former "2-10x faster / up to 90% memory" figures were
unattributed and are withdrawn pending the benchmark baseline.

### Partial Parsing

Stop parsing after specific tags to save time and memory:

```swift
// Parse only up to Study Description
let options = ParsingOptions(stopAfterTag: .studyDescription)
let file = try DICOMFile.read(from: data, options: options)
```

### Limit Element Count

For very large files with many elements, limit parsing:

```swift
// Parse only first 100 elements
let options = ParsingOptions(maxElements: 100)
let file = try DICOMFile.read(from: data, options: options)
```

---

## Parsing Performance

### Choose the Right Transfer Syntax

Parsing performance varies by transfer syntax:

| Transfer Syntax | Parsing Speed | Notes |
|----------------|---------------|-------|
| Implicit VR Little Endian | Fastest | No VR lookups needed |
| Explicit VR Little Endian | Fast | Native byte order |
| Explicit VR Big Endian | Moderate | Byte swapping required |
| Deflated | Slower | Decompression overhead |
| Compressed (JPEG, etc.) | Depends | Codec performance varies |

### Streaming vs. In-Memory — [not implemented]

There is currently no streaming or memory-mapped parse path;
`ParsingOptions(useMemoryMapping: true)` is a no-op (see above). All parsing is
whole-file in-memory today.

### Reuse Parsed Data

Cache frequently accessed DICOM files:

```swift
// Simple in-memory cache
var fileCache: [URL: DICOMFile] = [:]

func loadFile(url: URL) throws -> DICOMFile {
    if let cached = fileCache[url] {
        return cached
    }
    
    let file = try DICOMFile.read(from: url)
    fileCache[url] = file
    return file
}
```

---

## Image Processing

### Image Cache (LRU Eviction)

Use `ImageCache` to avoid re-rendering the same images:

```swift
// Create cache (default: 100 images, 500MB)
let cache = ImageCache(configuration: .default)

// Check cache before rendering
let key = ImageCacheKey(
    sopInstanceUID: "1.2.3.4.5",
    frameNumber: 0,
    windowCenter: 40,
    windowWidth: 400
)

if let cachedImage = await cache.get(key) {
    // Use cached image (fast!)
    return cachedImage
} else {
    // Render and cache
    let image = renderImage(from: pixelData)
    await cache.set(image, forKey: key)
    return image
}
```

**Cache Configurations:**

```swift
// Default (100 images, 500MB)
ImageCache.Configuration.default

// High memory (500 images, 2GB) - for workstations
ImageCache.Configuration.highMemory

// Low memory (20 images, 100MB) - for mobile devices
ImageCache.Configuration.lowMemory

// Disabled (for testing)
ImageCache.Configuration.disabled
```

### SIMD-Accelerated Processing (Apple Platforms)

Use `SIMDImageProcessor` for vectorized operations (iOS, macOS, visionOS):

```swift
import DICOMKit

// Window/level transformation (most common operation)
let displayPixels = SIMDImageProcessor.applyWindowLevel(
    to: pixelData,        // [UInt16]
    windowCenter: 40,
    windowWidth: 400,
    bitsStored: 12
)

// Invert for MONOCHROME1
let inverted = SIMDImageProcessor.invertPixels(displayPixels)

// Normalize to 8-bit range
let normalized = SIMDImageProcessor.normalize(
    pixelData,
    minValue: 0,
    maxValue: 4095
)

// Find min/max for auto-windowing
let (min, max) = SIMDImageProcessor.findMinMax(pixelData)

// Adjust contrast and brightness
let adjusted = SIMDImageProcessor.adjustContrast(
    displayPixels,
    alpha: 1.5,  // contrast multiplier
    beta: 10     // brightness offset
)
```

**Performance — [hypothesis]:** vectorised window/level is expected to beat the
scalar path, but the former "2-5x faster / <1ms" figures carried no device,
dataset or statistic and are withdrawn pending the benchmark baseline. Note also
that the GPU path (DICOMRenderKit) supersedes SIMD CPU windowing when Metal is
available.

### Multi-Frame Images

Note: DICOMKit itself currently decodes multi-frame pixel data **serially and
eagerly** (`DICOMFile.pixelData()` decodes every frame into one buffer). If you
parallelise rendering at the application layer, always **bound the concurrency** —
an unbounded task group over a large series can hold every decoded frame in memory
at once. Launching all frame tasks concurrently without a width/byte budget is an
anti-pattern:

```swift
// Bounded concurrent rendering (width-limited task group)
let maxConcurrent = 4
var results = [Int: CGImage]()
try await withThrowingTaskGroup(of: (Int, CGImage).self) { group in
    var next = 0
    func addTask(_ frame: Int) {
        group.addTask { (frame, try renderFrame(frame)) }
    }
    while next < min(maxConcurrent, frameCount) { addTask(next); next += 1 }
    for try await (frame, image) in group {
        results[frame] = image
        if next < frameCount { addTask(next); next += 1 }
    }
}
```

A memory-budgeted decode scheduler inside DICOMKit is planned (work package G of
the research-adoption instructions).

---

## JPEG 2000 / HTJ2K / JP3D Performance

DICOMKit uses J2KSwift v11.0.0 for all JPEG 2000 family codecs. Performance varies by codec, hardware backend, and image characteristics.

### Codec Selection

`CodecBackendProbe` automatically selects the fastest available backend:

```swift
// Check active backend at runtime
let backend = CodecRegistry.shared.activeBackend
// → .metal, .accelerate, or .scalar

// Force a specific backend (testing / benchmarking)
let config = CodecBackendPreference.require(.accelerate)
```

### Decode Performance (macOS arm64, real clinical DICOM) — [measured]

Measured on `instance_003317.dcm` — MR series, macOS arm64 (Apple Silicon), J2KSwift 11.0.0:

| Codec | Decode time | Relative |
|-------|-------------|----------|
| JPEG 2000 (J2KSwift scalar) | 4 809 ms | 1× baseline |
| HTJ2K Lossless (J2KSwift scalar) | 886 ms | **5.4× faster** |
| HTJ2K RPCL Lossless | ~880 ms | ~5.5× faster |

> Benchmark suite: `swift test --filter J2KSwiftCodecBenchmarkTests` — 3 tests, 125.9 s total on macOS arm64.

### Backend Speedup Summary — [hypothesis]

| Backend | Reported uplift over scalar (unattributed — reproduce before relying on) |
|---------|---------------------------|
| Metal (J2KMetal, Apple GPU) | up to 8–10× for large volumes (no median/range/workload recorded) |
| Apple Accelerate (SIMD / ARM Neon) | 2–4× |
| Scalar (pure Swift) | 1× (baseline) |

**Do not combine multipliers.** Codec-level gains (HTJ2K vs J2K) and backend-level
gains (Metal/Accelerate vs scalar) are **not additive or multiplicative**; the
earlier "~40–50× faster" combined claim was invalid reasoning and is withdrawn. Any
end-to-end figure must come from an end-to-end measurement on named hardware and a
named dataset.

### JP3D Volumetric Decoding — [hypothesis: timings unattributed]

JP3D encoding and decoding is performed by `JP3DCodec` wrapping `J2K3D`. Throughput scales with the number of CPU cores (the J2K3D engine parallelises slice decoding):

| Volume size | Compression mode | Approximate round-trip time |
|-------------|------------------|-----------------------------|
| 128-slice CT (512×512, 16-bit) | Lossless HTJ2K | < 5 s (Apple Silicon) |
| 512-slice MR (256×256, 12-bit) | Lossless | < 10 s (Apple Silicon) |

> JP3D is available via an experimental private SOP only; see [JPEG2000_GUIDE.md](Documentation/JPEG2000_GUIDE.md).

### JPIP Progressive Streaming — [hypothesis: latencies unattributed]

JPIP (`DICOMJPIPClient`) forwards per-call requests to J2KSwift's JPIP client; each
call returns one finished image (there is no incremental refinement stream or
session reuse across quality levels yet). The former "first tile <200 ms / 1–3 s
convergence" figures carried no environment or corpus and are withdrawn.

```swift
let client = DICOMJPIPClient(serverURL: jpipURL)
for await update in client.stream(quality: .layers(4)) {
    display(update.image)   // progressively improves
}
```

### Choosing the Right Codec

| Scenario | Recommended transfer syntax | Why |
|----------|-----------------------------|-----|
| Archive / long-term storage | HTJ2K Lossless (`.201`) | 5× faster decode, same bit-exact quality as J2K |
| Lossy compression for display | HTJ2K Lossy (`.203`) | Superior rate-distortion vs. JPEG 2000 lossy |
| Cross-vendor interop | JPEG 2000 Lossless (`.90`) | Universally supported |
| Large remote study (WSI / CT) | JPIP Referenced (`.94`) | Stream only requested tiles/quality layers |
| Multi-frame volume exchange | JP3D private SOP | Compact volumetric storage (experimental) |

---

## Network Performance

### Connection Pooling (DICOM Networking)

Reuse DICOM associations for better performance:

```swift
// Create connection pool
let poolConfig = ConnectionPoolConfiguration(
    maxConnections: 10,
    minConnections: 2,
    idleTimeout: 300
)

// Connections are automatically reused
for file in files {
    try await storeFile(file, using: pool)
}
```

### DICOMweb Caching

Enable HTTP caching for DICOMweb:

```swift
let cacheConfig = CacheConfiguration(
    enabled: true,
    maxSizeBytes: 500 * 1024 * 1024,  // 500MB
    maxEntries: 1000,
    ttl: 3600  // 1 hour
)

let client = DICOMwebClient(
    baseURL: url,
    cacheConfiguration: cacheConfig
)
```

### Compression

Use compression for network transfers:

```swift
// Request compressed responses
headers["Accept-Encoding"] = "gzip, deflate"

// Reduces bandwidth by 50-70% for metadata
// Reduces bandwidth by 10-30% for pixel data (already compressed)
```

---

## Benchmarking

### Measure Performance

Use `DICOMBenchmark` to measure operations:

```swift
// Measure parsing time
let result = DICOMBenchmark.measure(
    name: "Parse DICOM file",
    iterations: 10,
    trackMemory: true
) {
    try! DICOMFile.read(from: data)
}

print("Average: \(result.averageDurationMs)ms")
print("Memory: \(result.peakMemoryUsageMB!)MB")
```

### Compare Optimizations

```swift
// Baseline
let baseline = DICOMBenchmark.measure(name: "Full parsing") {
    try! DICOMFile.read(from: data, options: .default)
}

// Optimized
let optimized = DICOMBenchmark.measure(name: "Metadata only") {
    try! DICOMFile.read(from: data, options: .metadataOnly)
}

// Compare
let comparison = BenchmarkComparison(
    baseline: baseline,
    optimized: optimized
)

print(comparison.description)
// Illustrative output format only — these are not measured DICOMKit figures.
// Speed: 250.0% improvement
// Memory: 87.0% reduction
```

### Async Operations

```swift
let result = await DICOMBenchmark.measureAsync(
    name: "Network retrieve",
    iterations: 5
) {
    try await client.retrieveStudy(studyUID)
}
```

---

## Platform Considerations

### iOS Optimization

**Memory Constraints:**
```swift
// Use low memory configuration
let cache = ImageCache(configuration: .lowMemory)

// Prefer metadata-only parsing
let options = ParsingOptions.metadataOnly

// Clear caches on memory warning
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: nil
) { _ in
    await cache.clear()
}
```

### macOS Optimization

**Leverage More RAM:**
```swift
// High memory configuration for workstations
let cache = ImageCache(configuration: .highMemory)

// Memory-mapped files for large datasets
let options = ParsingOptions.memoryMapped
```

### visionOS Optimization

**Spatial Computing:**
```swift
// Concurrent processing for multiple viewpoints
let leftImage = try await renderFrame(0)
let rightImage = try await renderFrame(1)

// Use SIMD for real-time transformations
let processed = SIMDImageProcessor.applyWindowLevel(
    to: pixelData,
    windowCenter: windowSettings.center,
    windowWidth: windowSettings.width,
    bitsStored: 12
)
```

---

## Performance Recommendations Summary

| Use Case | Recommended Approach | Status |
|----------|---------------------|--------|
| Metadata queries | `ParsingOptions.metadataOnly` | [heuristic] — avoids pixel parse; magnitude unmeasured |
| Large files (>100MB) | ~~`ParsingOptions.memoryMapped`~~ | [not implemented] — no-op today |
| Image rendering | `ImageCache` + GPU path (DICOMRenderKit) | [measured] for GPU path; see GPU_RENDERING_PLAN.md |
| Network operations | Connection pooling + HTTP caching | [heuristic] — unmeasured |
| Multi-frame series | Bounded concurrent rendering (app layer) | [heuristic] — bound width; library decode is serial |

Combined "overall" multipliers are not published: layer speed-ups must not be
multiplied together (see the corrective-review note at the top of this guide).

---

## Troubleshooting

### Out of Memory

**Problem:** App crashes with large DICOM files

**Solutions:**
1. Enable metadata-only mode when pixels aren't needed
2. Clear image cache periodically
3. Process multi-frame series in bounded batches
4. (Memory-mapped parsing is not yet available — see work package A)

### Slow Parsing

**Problem:** DICOM file parsing takes too long

**Solutions:**
1. Use metadata-only mode if pixel data not needed
2. Use stopAfterTag for partial parsing
3. Enable compression for network transfers
4. Profile with DICOMBenchmark to find bottlenecks

### Cache Misses

**Problem:** Low cache hit rate

**Solutions:**
1. Include all relevant parameters in cache key
2. Increase cache size
3. Review cache eviction policy
4. Monitor cache statistics

---

## Best Practices

1. **Always measure** - Use DICOMBenchmark before and after optimizations
2. **Profile first** - Identify bottlenecks before optimizing
3. **Match resources** - Use appropriate configurations for device capabilities
4. **Cache wisely** - Cache expensive operations, not cheap ones
5. **Monitor memory** - Track peak usage and adjust limits
6. **Test realistic data** - Benchmark with actual clinical files
7. **Document performance** - Record baseline and improvements

---

## Further Reading

- [DICOM Standard PS3.5](https://www.dicomstandard.org/current) - Transfer Syntax details
- [Apple Accelerate Framework](https://developer.apple.com/documentation/accelerate) - SIMD operations
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) - Async/await patterns

---

*Last updated: 2026-08-10 (corrective review per Documentation/ResearchAdoption instructions §4)*
