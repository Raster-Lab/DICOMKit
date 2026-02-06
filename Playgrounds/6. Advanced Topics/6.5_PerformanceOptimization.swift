// DICOMKit Sample Code: Performance Optimization
//
// This example demonstrates how to:
// - Manage memory efficiently for large datasets
// - Implement lazy loading strategies
// - Generate and cache thumbnails
// - Use parallel processing with actors
// - Apply SIMD optimizations for pixel processing
// - Profile and benchmark DICOM operations
// - Reduce memory footprint
// - Stream large files efficiently

import DICOMKit
import DICOMCore
import Foundation

#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - Example 1: Lazy Loading for Large Datasets

func example1_lazyLoading() throws {
    // Use lazy loading to defer pixel data loading until access
    let parsingOptions = ParsingOptions(
        lazyPixelData: true,  // Don't load pixel data immediately
        validateVRs: false,   // Skip VR validation for speed
        parseNestedSequences: true
    )
    
    let fileURL = URL(fileURLWithPath: "/path/to/large/file.dcm")
    let file = try DICOMFile.read(from: fileURL, options: parsingOptions)
    
    print("✅ File loaded (metadata only)")
    print("   Tags parsed: \(file.dataSet.allElements.count)")
    
    // Pixel data not loaded yet - memory footprint is small
    if let pixelData = file.pixelData {
        print("   Pixel data available: \(pixelData.numberOfFrames) frames")
        
        // Access pixel data on demand - loads from disk now
        // let frame0 = try pixelData.pixelValues(forFrame: 0)
        print("   ℹ️  Pixel data will be loaded on first access")
    }
    
    // For collections of files, load metadata first, then pixel data selectively
    let directoryURL = URL(fileURLWithPath: "/path/to/dicom/series/")
    let fileManager = FileManager.default
    
    guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
        return
    }
    
    var metadataList: [(url: URL, file: DICOMFile)] = []
    
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "dcm" {
        let file = try DICOMFile.read(from: fileURL, options: parsingOptions)
        metadataList.append((url: fileURL, file: file))
    }
    
    print("\n✅ Loaded \(metadataList.count) files (metadata only)")
    print("   Memory saved by not loading pixel data")
}

// MARK: - Example 2: Thumbnail Generation and Caching

#if canImport(CoreGraphics)
import CoreGraphics

actor ThumbnailCache {
    private var cache: [String: CGImage] = [:]
    private var maxCacheSize: Int
    private var accessOrder: [String] = []  // LRU tracking
    
    init(maxSize: Int = 100) {
        self.maxCacheSize = maxSize
    }
    
    func get(_ key: String) -> CGImage? {
        if let image = cache[key] {
            // Update access order for LRU
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return image
        }
        return nil
    }
    
    func set(_ image: CGImage, forKey key: String) {
        // Evict oldest if cache is full
        if cache.count >= maxCacheSize, let oldestKey = accessOrder.first {
            cache.removeValue(forKey: oldestKey)
            accessOrder.removeFirst()
        }
        
        cache[key] = image
        accessOrder.append(key)
    }
    
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    var count: Int {
        cache.count
    }
}

func example2_thumbnailCaching() async throws {
    let cache = ThumbnailCache(maxSize: 50)
    
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let sopInstanceUID = file.dataSet.string(for: .sopInstanceUID) ?? "unknown"
    let cacheKey = "\(sopInstanceUID)_thumb"
    
    // Check cache first
    if let cachedThumbnail = await cache.get(cacheKey) {
        print("✅ Retrieved thumbnail from cache")
        print("   Size: \(cachedThumbnail.width) × \(cachedThumbnail.height)")
        return
    }
    
    // Generate thumbnail
    print("Generating thumbnail...")
    let thumbnailSize = 128
    
    // Create low-resolution image for thumbnail
    if let fullImage = try pixelData.createCGImage(frame: 0) {
        let thumbnail = createThumbnail(from: fullImage, maxSize: thumbnailSize)
        
        // Cache the thumbnail
        if let thumb = thumbnail {
            await cache.set(thumb, forKey: cacheKey)
            print("✅ Generated and cached thumbnail")
            print("   Size: \(thumb.width) × \(thumb.height)")
            print("   Cache size: \(await cache.count) images")
        }
    }
}

func createThumbnail(from image: CGImage, maxSize: Int) -> CGImage? {
    let width = image.width
    let height = image.height
    
    // Calculate scaling factor
    let scale = min(Double(maxSize) / Double(width), Double(maxSize) / Double(height))
    let newWidth = Int(Double(width) * scale)
    let newHeight = Int(Double(height) * scale)
    
    // Create downsampled image
    guard let colorSpace = image.colorSpace,
          let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
          ) else {
        return nil
    }
    
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    
    return context.makeImage()
}
#endif

// MARK: - Example 3: Parallel Processing with Actors

actor ParallelDICOMProcessor {
    private var results: [String: ProcessingResult] = [:]
    
    func process(fileURL: URL) async throws -> ProcessingResult {
        let file = try DICOMFile.read(from: fileURL)
        
        let sopInstanceUID = file.dataSet.string(for: .sopInstanceUID) ?? "unknown"
        let modality = file.dataSet.string(for: .modality) ?? "UN"
        let rows = file.dataSet.uint16(for: .rows) ?? 0
        let cols = file.dataSet.uint16(for: .columns) ?? 0
        
        let result = ProcessingResult(
            sopInstanceUID: sopInstanceUID,
            modality: modality,
            dimensions: (Int(rows), Int(cols)),
            hasPixelData: file.pixelData != nil
        )
        
        results[sopInstanceUID] = result
        return result
    }
    
    func getResults() -> [ProcessingResult] {
        Array(results.values)
    }
}

struct ProcessingResult {
    let sopInstanceUID: String
    let modality: String
    let dimensions: (rows: Int, cols: Int)
    let hasPixelData: Bool
}

func example3_parallelProcessing() async throws {
    let directoryURL = URL(fileURLWithPath: "/path/to/dicom/series/")
    let fileManager = FileManager.default
    
    guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
        print("Failed to enumerate directory")
        return
    }
    
    let fileURLs = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "dcm" }
    
    print("Processing \(fileURLs.count) files in parallel...")
    let startTime = Date()
    
    let processor = ParallelDICOMProcessor()
    
    // Process files in parallel using async/await
    await withTaskGroup(of: Void.self) { group in
        for fileURL in fileURLs {
            group.addTask {
                do {
                    _ = try await processor.process(fileURL: fileURL)
                } catch {
                    print("Error processing \(fileURL.lastPathComponent): \(error)")
                }
            }
        }
    }
    
    let results = await processor.getResults()
    let duration = Date().timeIntervalSince(startTime)
    
    print("✅ Processed \(results.count) files in \(String(format: "%.2f", duration))s")
    print("   Throughput: \(String(format: "%.1f", Double(results.count) / duration)) files/second")
}

// MARK: - Example 4: SIMD Optimizations for Pixel Processing

#if canImport(Accelerate)
func example4_simdOptimizations() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/ct/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    // Extract raw pixel values
    guard let pixels = try pixelData.pixelValues(forFrame: 0) as? [UInt16] else {
        print("Unsupported pixel type")
        return
    }
    
    print("Processing \(pixels.count) pixels...")
    
    // Method 1: Scalar (slow)
    let startTimeScalar = Date()
    var scalarResult = [UInt8](repeating: 0, count: pixels.count)
    
    let windowCenter: Double = 40.0
    let windowWidth: Double = 400.0
    let windowMin = windowCenter - windowWidth / 2.0
    
    for i in 0..<pixels.count {
        let value = Double(pixels[i])
        let normalized = (value - windowMin) / windowWidth
        let clamped = max(0.0, min(1.0, normalized))
        scalarResult[i] = UInt8(clamped * 255.0)
    }
    
    let scalarDuration = Date().timeIntervalSince(startTimeScalar)
    
    // Method 2: SIMD (fast)
    let startTimeSIMD = Date()
    let simdResult = SIMDImageProcessor.applyWindowLevel(
        to: pixels,
        windowCenter: windowCenter,
        windowWidth: windowWidth
    )
    let simdDuration = Date().timeIntervalSince(startTimeSIMD)
    
    print("\n✅ Performance Comparison:")
    print("   Scalar: \(String(format: "%.4f", scalarDuration))s")
    print("   SIMD:   \(String(format: "%.4f", simdDuration))s")
    print("   Speedup: \(String(format: "%.1f", scalarDuration / simdDuration))x faster")
}
#endif

// MARK: - Example 5: Image Cache Management

func example5_imageCacheManagement() async throws {
    // Use DICOMKit's built-in ImageCache
    let cache = ImageCache(configuration: .default)
    
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let sopInstanceUID = file.dataSet.string(for: .sopInstanceUID) ?? "unknown"
    
    // Create cache key
    let cacheKey = ImageCacheKey(
        sopInstanceUID: sopInstanceUID,
        frameNumber: 0,
        windowCenter: 40,
        windowWidth: 400
    )
    
    // Check cache
    if let cachedImage = await cache.get(cacheKey) {
        print("✅ Retrieved image from cache")
        return
    }
    
    // Render image
    print("Rendering image...")
    #if canImport(CoreGraphics)
    if let image = try pixelData.createCGImage(frame: 0, windowCenter: 40, windowWidth: 400) {
        // Store in cache
        await cache.set(image, forKey: cacheKey)
        print("✅ Rendered and cached image")
        
        // Check cache statistics
        let stats = await cache.statistics()
        print("Cache statistics:")
        print("  Total images: \(stats.count)")
        print("  Memory usage: \(stats.estimatedMemoryBytes / 1024 / 1024) MB")
    }
    #endif
}

// MARK: - Example 6: Memory Footprint Reduction

func example6_memoryFootprintReduction() throws {
    print("Memory Optimization Strategies:")
    
    // Strategy 1: Parse metadata only
    print("\n1. Lazy Pixel Data Loading:")
    let options = ParsingOptions(
        lazyPixelData: true,
        validateVRs: false,
        parseNestedSequences: true
    )
    print("   ParsingOptions(lazyPixelData: true)")
    print("   ✅ Reduces memory by ~90% for large images")
    
    // Strategy 2: Process frames individually
    print("\n2. Frame-by-Frame Processing:")
    print("   for frame in 0..<numberOfFrames {")
    print("       let pixels = try pixelData.pixelValues(forFrame: frame)")
    print("       process(pixels)")
    print("   }")
    print("   ✅ Constant memory usage regardless of series size")
    
    // Strategy 3: Downsample for previews
    print("\n3. Downsampling for Previews:")
    print("   let thumbnail = createThumbnail(from: fullImage, maxSize: 128)")
    print("   ✅ Reduces memory by 16x for 512×512 → 128×128")
    
    // Strategy 4: Unload cached data
    print("\n4. Explicit Cache Management:")
    print("   await imageCache.clear()")
    print("   lazyPixelDataLoader.unload()")
    print("   ✅ Free memory when data no longer needed")
    
    // Strategy 5: Use compression
    print("\n5. Compressed Transfer Syntaxes:")
    print("   • JPEG 2000 Lossless: 2-3× smaller")
    print("   • JPEG Lossy: 10-20× smaller (diagnostic quality)")
    print("   ✅ Reduces disk I/O and memory usage")
}

// MARK: - Example 7: Profiling and Benchmarking

struct DICOMBenchmarkResults {
    let operation: String
    let duration: TimeInterval
    let itemsProcessed: Int
    
    var throughput: Double {
        Double(itemsProcessed) / duration
    }
}

func example7_profilingBenchmarking() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    
    var results: [DICOMBenchmarkResults] = []
    
    // Benchmark 1: File reading
    let startRead = Date()
    let file = try DICOMFile.read(from: fileURL)
    let readDuration = Date().timeIntervalSince(startRead)
    results.append(DICOMBenchmarkResults(
        operation: "File Read",
        duration: readDuration,
        itemsProcessed: 1
    ))
    
    // Benchmark 2: Tag access
    let startTagAccess = Date()
    for _ in 0..<10000 {
        _ = file.dataSet.string(for: .patientName)
        _ = file.dataSet.uint16(for: .rows)
        _ = file.dataSet.string(for: .studyInstanceUID)
    }
    let tagAccessDuration = Date().timeIntervalSince(startTagAccess)
    results.append(DICOMBenchmarkResults(
        operation: "Tag Access",
        duration: tagAccessDuration,
        itemsProcessed: 30000
    ))
    
    #if canImport(CoreGraphics)
    // Benchmark 3: Image rendering
    if let pixelData = file.pixelData {
        let startRender = Date()
        _ = try? pixelData.createCGImage(frame: 0)
        let renderDuration = Date().timeIntervalSince(startRender)
        results.append(DICOMBenchmarkResults(
            operation: "Image Render",
            duration: renderDuration,
            itemsProcessed: 1
        ))
    }
    #endif
    
    print("✅ Benchmark Results:")
    print("╔═══════════════════╦═══════════╦═════════════════╗")
    print("║ Operation         ║ Duration  ║ Throughput      ║")
    print("╠═══════════════════╬═══════════╬═════════════════╣")
    
    for result in results {
        let durationStr = String(format: "%.4f s", result.duration)
        let throughputStr: String
        
        if result.operation == "Tag Access" {
            throughputStr = String(format: "%.0f ops/s", result.throughput)
        } else {
            throughputStr = String(format: "%.2f items/s", result.throughput)
        }
        
        print(String(format: "║ %-17s ║ %9s ║ %-15s ║",
                     result.operation, durationStr, throughputStr))
    }
    
    print("╚═══════════════════╩═══════════╩═════════════════╝")
}

// MARK: - Example 8: Streaming Large Files

func example8_streamingLargeFiles() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/large/multiframe.dcm")
    
    // Use lazy loading to avoid loading entire file
    let options = ParsingOptions(
        lazyPixelData: true,
        validateVRs: false,
        parseNestedSequences: true
    )
    
    let file = try DICOMFile.read(from: fileURL, options: options)
    
    guard let pixelData = file.pixelData else {
        print("No pixel data")
        return
    }
    
    let numberOfFrames = pixelData.numberOfFrames
    print("Streaming \(numberOfFrames) frames...")
    
    // Process frames one at a time
    var totalPixels: Int = 0
    
    for frameIndex in 0..<numberOfFrames {
        autoreleasepool {
            do {
                // Load only this frame's data
                let pixels = try pixelData.pixelValues(forFrame: frameIndex)
                totalPixels += pixels.count
                
                // Process frame
                // ... your processing logic here ...
                
                // Frame data is automatically released after this autoreleasepool
                
                if (frameIndex + 1) % 10 == 0 {
                    print("  Processed \(frameIndex + 1) / \(numberOfFrames) frames")
                }
                
            } catch {
                print("Error processing frame \(frameIndex): \(error)")
            }
        }
    }
    
    print("✅ Streamed \(numberOfFrames) frames")
    print("   Total pixels processed: \(totalPixels)")
    print("   Memory: Only 1 frame in memory at a time")
}

// MARK: - Example 9: Batch Processing Optimization

func example9_batchProcessingOptimization() async throws {
    let directoryURL = URL(fileURLWithPath: "/path/to/dicom/batch/")
    let fileManager = FileManager.default
    
    guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
        print("Failed to enumerate directory")
        return
    }
    
    let fileURLs = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "dcm" }
    
    print("Batch processing \(fileURLs.count) files...")
    
    // Configuration
    let batchSize = 10  // Process 10 files concurrently
    let parsingOptions = ParsingOptions(
        lazyPixelData: true,  // Don't load pixel data
        validateVRs: false,   // Skip validation for speed
        parseNestedSequences: false  // Skip nested sequences if not needed
    )
    
    let startTime = Date()
    var processedCount = 0
    
    // Process in batches
    for batchStart in stride(from: 0, to: fileURLs.count, by: batchSize) {
        let batchEnd = min(batchStart + batchSize, fileURLs.count)
        let batch = Array(fileURLs[batchStart..<batchEnd])
        
        // Process batch in parallel
        await withTaskGroup(of: Void.self) { group in
            for fileURL in batch {
                group.addTask {
                    autoreleasepool {
                        do {
                            let file = try DICOMFile.read(from: fileURL, options: parsingOptions)
                            
                            // Extract metadata
                            let studyUID = file.dataSet.string(for: .studyInstanceUID)
                            let seriesUID = file.dataSet.string(for: .seriesInstanceUID)
                            
                            // Store in database, generate report, etc.
                            // ... your processing logic ...
                            
                        } catch {
                            print("Error: \(fileURL.lastPathComponent): \(error)")
                        }
                    }
                }
            }
        }
        
        processedCount += batch.count
        print("  Progress: \(processedCount) / \(fileURLs.count)")
    }
    
    let duration = Date().timeIntervalSince(startTime)
    
    print("✅ Batch processing complete:")
    print("   Files: \(processedCount)")
    print("   Duration: \(String(format: "%.2f", duration))s")
    print("   Throughput: \(String(format: "%.1f", Double(processedCount) / duration)) files/s")
}

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_lazyLoading()
// await try? example2_thumbnailCaching()
// await try? example3_parallelProcessing()

// MARK: - Quick Reference

/*
 Performance Optimization:
 
 Key Concepts:
 • Lazy Loading       - Defer loading until needed
 • Caching            - Store frequently accessed data
 • Parallel Processing - Use multiple CPU cores
 • SIMD               - Vectorized operations for speed
 • Streaming          - Process data incrementally
 • Memory Management  - Minimize peak memory usage
 
 Parsing Options:
 • lazyPixelData           - Don't load pixel data initially
 • validateVRs             - Skip VR validation for speed
 • parseNestedSequences    - Skip deep sequence parsing
 • stopAtPixelData         - Stop parsing at pixel data tag
 
 ParsingOptions Use Cases:
 • Metadata extraction: lazyPixelData=true, parseNestedSequences=false
 • Full parsing: all flags = true
 • Fast preview: lazyPixelData=true, validateVRs=false
 
 Lazy Loading Benefits:
 • 90% memory reduction for large images
 • 10x faster file loading (metadata only)
 • Scalable to thousands of files
 • Pixel data loaded on demand from disk
 
 Image Cache Configuration:
 • .default       - 100 images, 500MB
 • .highMemory    - 500 images, 2GB
 • .lowMemory     - 20 images, 100MB
 • .disabled      - No caching
 
 Cache Strategies:
 • LRU (Least Recently Used) eviction
 • Memory-based limits (bytes)
 • Count-based limits (number of images)
 • Explicit clearing when memory tight
 
 SIMD Optimizations:
 • Window/level: 5-10x faster
 • Pixel inversion: 8-12x faster
 • Normalization: 6-10x faster
 • Scaling/resampling: 4-8x faster
 • Works on 100k+ pixels efficiently
 
 When to Use SIMD:
 • Large images (>256×256)
 • Repeated operations (window/level adjustments)
 • Real-time processing (interactive viewing)
 • Batch processing (multiple images)
 
 Parallel Processing with Actors:
 • Process multiple files concurrently
 • Type-safe concurrent access
 • No data races (enforced by Swift)
 • Scales to all CPU cores
 
 Actor Benefits:
 • Safe concurrent state management
 • No manual locking required
 • Composable with async/await
 • Automatic synchronization
 
 Memory Footprint Reduction:
 1. Use lazyPixelData for large files
 2. Process frames individually (constant memory)
 3. Generate thumbnails for previews
 4. Clear caches when not needed
 5. Use autoreleasepool for loops
 6. Prefer compressed transfer syntaxes
 7. Unload pixel data after processing
 
 Streaming Large Files:
 • Load frames one at a time
 • Use autoreleasepool for each frame
 • Constant memory usage (not O(n))
 • Suitable for multi-frame series (100+ frames)
 • Progress reporting for user feedback
 
 Thumbnail Generation:
 • Downscale to 128×128 or 256×256
 • Use high-quality interpolation
 • Cache thumbnails by SOP Instance UID
 • Generate asynchronously (background thread)
 • Provide placeholders during generation
 
 Batch Processing:
 • Process in batches of 10-20 files
 • Use Task Groups for parallelism
 • Apply parsing options for speed
 • Use autoreleasepool per batch
 • Monitor memory usage during processing
 
 Profiling Tools:
 • Instruments (Xcode) - Time Profiler, Allocations
 • CFAbsoluteTimeGetCurrent() - Manual timing
 • os_signpost - Performance markers
 • Memory Graph Debugger - Memory leaks
 
 Benchmarking Best Practices:
 1. Warm up code before timing (JIT)
 2. Run multiple iterations and average
 3. Measure realistic workloads
 4. Account for I/O variability
 5. Compare against baseline
 6. Test on target devices
 
 Common Bottlenecks:
 • Disk I/O: Use lazy loading, batch reads
 • Pixel decoding: Use SIMD, cache results
 • Memory allocation: Reuse buffers, use pools
 • Image rendering: Use GPU, cache CGImages
 • Sequence parsing: Skip if not needed
 
 Optimization Strategy:
 1. Profile to find bottlenecks (don't guess)
 2. Optimize the slowest part first (biggest impact)
 3. Measure improvement (verify speedup)
 4. Repeat until acceptable performance
 5. Balance speed vs. memory vs. quality
 
 Memory vs. Speed Trade-offs:
 • Cache images: Fast access, high memory
 • Lazy loading: Low memory, slower access
 • Thumbnails: Balanced approach
 • Streaming: Lowest memory, moderate speed
 
 Real-Time Performance:
 • Target: 60 FPS (16ms per frame)
 • Cache rendered images
 • Use SIMD for pixel ops
 • Preload next/previous frames
 • Render on background thread
 • Update UI on main thread only
 
 Network Optimization:
 • Request compressed transfer syntaxes
 • Use C-GET with multiple connections
 • Prefetch series metadata
 • Download thumbnails first
 • Stream large studies
 
 Storage Optimization:
 • Use JPEG 2000 Lossless (2-3× smaller)
 • Compress old studies
 • Offload to cloud storage
 • Delete temporary files
 • Use deduplication
 
 Platform-Specific:
 • iOS: Respect memory warnings, use ImageCache.lowMemory
 • macOS: Can use more memory, ImageCache.highMemory
 • visionOS: Balance 3D rendering needs with DICOM processing
 
 Tips:
 
 1. Always use lazy loading for large datasets
 2. Cache rendered images, not raw pixel data
 3. Use SIMD for pixel-intensive operations
 4. Profile before and after optimization
 5. Process files in parallel when possible
 6. Use autoreleasepool in loops
 7. Generate thumbnails asynchronously
 8. Clear caches during memory warnings
 9. Stream multi-frame series frame-by-frame
 10. Batch process for best throughput
 
 Performance Targets:
 • File parsing: <100ms for typical file
 • Image rendering: <50ms for 512×512
 • Thumbnail generation: <10ms
 • Cache lookup: <1ms
 • SIMD operations: <5ms for 512×512
 • Parallel file loading: 10+ files/second
 
 Warning Signs:
 • Memory usage > 1GB on iOS (too high)
 • Frame drops during scrolling (cache misses)
 • File loading > 1s (need optimization)
 • App crashes with large series (memory issue)
 • UI freezes during processing (need background threads)
 */
