# DICOMKit Performance Guide

This guide provides best practices and recommendations for optimizing performance when using DICOMKit.

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

### Use Memory-Mapped Files for Large DICOM Files

For files larger than 100MB, use memory-mapped file access to reduce peak memory usage:

```swift
// Memory-mapped parsing (efficient for large files)
let options = ParsingOptions.memoryMapped
let file = try DICOMFile.read(from: fileURL, options: options)
```

**Benefits:**
- 50% reduction in memory usage for files >100MB
- Allows working with files larger than available RAM
- Minimal performance impact

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

// Lazy pixel data (deferred loading)
let options = ParsingOptions.lazyPixelData
let file = try DICOMFile.read(from: data, options: options)
// Pixel data tag exists but value not loaded until accessed
```

**Performance Impact:**
- Metadata-only: 2-10x faster for large images
- Memory savings: Up to 90% for image-heavy files
- Use for: Queries, browsing, metadata extraction

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

### Streaming vs. In-Memory

For files >50MB, consider streaming:

```swift
// Memory-mapped streaming (for large files)
let options = ParsingOptions(useMemoryMapping: true)
let file = try DICOMFile.read(from: url, options: options)
```

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

**Performance:**
- 2-5x faster than scalar implementation
- Handles 512x512 image in <1ms on modern devices
- Automatically uses vector instructions (SIMD)

### Multi-Frame Images

For multi-frame series, process frames concurrently:

```swift
// Process frames in parallel
await withTaskGroup(of: CGImage?.self) { group in
    for frameNumber in 0..<frameCount {
        group.addTask {
            // Each frame processed independently
            return try? renderFrame(frameNumber)
        }
    }
    
    // Collect results
    for await image in group {
        frames.append(image)
    }
}
```

---

## JPEG 2000 / HTJ2K / JP3D Performance

DICOMKit uses J2KSwift v3.2.0 for all JPEG 2000 family codecs. Performance varies by codec, hardware backend, and image characteristics.

### Codec Selection

`CodecBackendProbe` automatically selects the fastest available backend:

```swift
// Check active backend at runtime
let backend = CodecRegistry.shared.activeBackend
// → .metal, .accelerate, or .scalar

// Force a specific backend (testing / benchmarking)
let config = CodecBackendPreference.require(.accelerate)
```

### Decode Performance (macOS arm64, real clinical DICOM)

Measured on `instance_003317.dcm` — MR series, macOS arm64 (Apple Silicon), J2KSwift 3.2.0:

| Codec | Decode time | Relative |
|-------|-------------|----------|
| JPEG 2000 (J2KSwift scalar) | 4 809 ms | 1× baseline |
| HTJ2K Lossless (J2KSwift scalar) | 886 ms | **5.4× faster** |
| HTJ2K RPCL Lossless | ~880 ms | ~5.5× faster |

> Benchmark suite: `swift test --filter J2KSwiftCodecBenchmarkTests` — 3 tests, 125.9 s total on macOS arm64.

### Backend Speedup Summary

| Backend | Typical uplift over scalar |
|---------|---------------------------|
| J2KMetal (Apple GPU) | Up to 8–10× for large volumes |
| J2KAccelerate (SIMD / ARM Neon) | 2–4× |
| J2KCodec scalar | 1× (baseline) |

These multipliers are additive on top of the HTJ2K vs J2K codec gain, so HTJ2K + Metal can be ~40–50× faster than plain J2K scalar on Apple hardware.

### JP3D Volumetric Decoding

JP3D encoding and decoding is performed by `JP3DCodec` wrapping `J2K3D`. Throughput scales with the number of CPU cores (the J2K3D engine parallelises slice decoding):

| Volume size | Compression mode | Approximate round-trip time |
|-------------|------------------|-----------------------------|
| 128-slice CT (512×512, 16-bit) | Lossless HTJ2K | < 5 s (Apple Silicon) |
| 512-slice MR (256×256, 12-bit) | Lossless | < 10 s (Apple Silicon) |

> JP3D is available via an experimental private SOP only; see [JPEG2000_GUIDE.md](Documentation/JPEG2000_GUIDE.md).

### JPIP Progressive Streaming

JPIP (`DICOMJPIPClient`) delivers quality layers incrementally. First-tile latency is typically under 200 ms on a local 1 Gbps network; full quality converges within 1–3 s for a 512×512 CT frame.

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

| Use Case | Recommended Approach | Performance Gain |
|----------|---------------------|------------------|
| Metadata queries | `ParsingOptions.metadataOnly` | 2-10x faster |
| Large files (>100MB) | `ParsingOptions.memoryMapped` | 50% less memory |
| Image rendering | `ImageCache` + `SIMDImageProcessor` | 2-5x faster |
| Network operations | Connection pooling + caching | 3-10x faster |
| Multi-frame series | Concurrent processing | Nx faster (N cores) |
| Clinical workflows | Combine all optimizations | 10-50x overall |

---

## Troubleshooting

### Out of Memory

**Problem:** App crashes with large DICOM files

**Solutions:**
1. Use memory-mapped parsing
2. Enable metadata-only mode
3. Clear image cache periodically
4. Process multi-frame series in batches

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

*Last updated: 2026-04-21*
*DICOMKit version: 1.2.7*
