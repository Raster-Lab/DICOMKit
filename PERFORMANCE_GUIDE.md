# DICOMKit Performance Guide

This guide provides best practices and recommendations for optimizing performance when using DICOMKit.

## Table of Contents

1. [Memory Optimization](#memory-optimization)
2. [Parsing Performance](#parsing-performance)
3. [Image Processing](#image-processing)
4. [Network Performance](#network-performance)
5. [Benchmarking](#benchmarking)
6. [Platform Considerations](#platform-considerations)

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

*Last updated: 2026-02-05*
*DICOMKit version: 1.0.12*
