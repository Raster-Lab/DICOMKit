import XCTest
@testable import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics

final class ImageCacheTests: XCTestCase {
    
    /// Helper to create a test CGImage
    private func createTestImage(width: Int = 512, height: Int = 512) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // Fill with gray
        context.setFillColor(gray: 0.5, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    func testDefaultConfiguration() {
        let config = ImageCache.Configuration.default
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxImages, 100)
        XCTAssertEqual(config.maxMemoryBytes, 500 * 1024 * 1024)
    }
    
    func testHighMemoryConfiguration() {
        let config = ImageCache.Configuration.highMemory
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxImages, 500)
        XCTAssertEqual(config.maxMemoryBytes, 2 * 1024 * 1024 * 1024)
    }
    
    func testLowMemoryConfiguration() {
        let config = ImageCache.Configuration.lowMemory
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxImages, 20)
        XCTAssertEqual(config.maxMemoryBytes, 100 * 1024 * 1024)
    }
    
    func testDisabledConfiguration() {
        let config = ImageCache.Configuration.disabled
        
        XCTAssertFalse(config.enabled)
    }
    
    func testCacheKey() {
        let key1 = ImageCacheKey(
            sopInstanceUID: "1.2.3",
            frameNumber: 0
        )
        
        let key2 = ImageCacheKey(
            sopInstanceUID: "1.2.3",
            frameNumber: 0
        )
        
        let key3 = ImageCacheKey(
            sopInstanceUID: "1.2.3",
            frameNumber: 1
        )
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testCacheKeyWithWindowSettings() {
        let key1 = ImageCacheKey(
            sopInstanceUID: "1.2.3",
            frameNumber: 0,
            windowCenter: 40,
            windowWidth: 400
        )
        
        let key2 = ImageCacheKey(
            sopInstanceUID: "1.2.3",
            frameNumber: 0,
            windowCenter: 40,
            windowWidth: 400
        )
        
        let key3 = ImageCacheKey(
            sopInstanceUID: "1.2.3",
            frameNumber: 0,
            windowCenter: 50,
            windowWidth: 400
        )
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testSetAndGet() async {
        let cache = ImageCache(configuration: .default)
        
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Initially cache should be empty
        XCTAssertNil(await cache.get(key))
        
        // Store image
        await cache.set(image, forKey: key)
        
        // Should now be in cache
        let cached = await cache.get(key)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.width, image.width)
        XCTAssertEqual(cached?.height, image.height)
    }
    
    func testCacheMiss() async {
        let cache = ImageCache(configuration: .default)
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Get non-existent image
        XCTAssertNil(await cache.get(key))
        
        // Check statistics
        let stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 1)
    }
    
    func testCacheHit() async {
        let cache = ImageCache(configuration: .default)
        
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Store image
        await cache.set(image, forKey: key)
        
        // Get image (hit)
        _ = await cache.get(key)
        
        // Check statistics
        let stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 0)
    }
    
    func testLRUEviction() async {
        // Small cache that can hold only 2 images
        let config = ImageCache.Configuration(
            maxImages: 2,
            maxMemoryBytes: 10 * 1024 * 1024
        )
        let cache = ImageCache(configuration: config)
        
        guard let image1 = createTestImage(),
              let image2 = createTestImage(),
              let image3 = createTestImage() else {
            XCTFail("Failed to create test images")
            return
        }
        
        let key1 = ImageCacheKey(sopInstanceUID: "1.2.3.1", frameNumber: 0)
        let key2 = ImageCacheKey(sopInstanceUID: "1.2.3.2", frameNumber: 0)
        let key3 = ImageCacheKey(sopInstanceUID: "1.2.3.3", frameNumber: 0)
        
        // Add first two images
        await cache.set(image1, forKey: key1)
        await cache.set(image2, forKey: key2)
        
        // Both should be in cache
        XCTAssertNotNil(await cache.get(key1))
        XCTAssertNotNil(await cache.get(key2))
        
        // Add third image - should evict first (LRU)
        await cache.set(image3, forKey: key3)
        
        // First should be evicted
        XCTAssertNil(await cache.get(key1))
        // Second and third should still be there
        XCTAssertNotNil(await cache.get(key2))
        XCTAssertNotNil(await cache.get(key3))
    }
    
    func testLRUAccessOrder() async {
        // Small cache that can hold only 2 images
        let config = ImageCache.Configuration(
            maxImages: 2,
            maxMemoryBytes: 10 * 1024 * 1024
        )
        let cache = ImageCache(configuration: config)
        
        guard let image1 = createTestImage(),
              let image2 = createTestImage(),
              let image3 = createTestImage() else {
            XCTFail("Failed to create test images")
            return
        }
        
        let key1 = ImageCacheKey(sopInstanceUID: "1.2.3.1", frameNumber: 0)
        let key2 = ImageCacheKey(sopInstanceUID: "1.2.3.2", frameNumber: 0)
        let key3 = ImageCacheKey(sopInstanceUID: "1.2.3.3", frameNumber: 0)
        
        // Add first two images
        await cache.set(image1, forKey: key1)
        await cache.set(image2, forKey: key2)
        
        // Access first image to make it recently used
        _ = await cache.get(key1)
        
        // Add third image - should evict second (LRU)
        await cache.set(image3, forKey: key3)
        
        // Second should be evicted (it was LRU)
        XCTAssertNil(await cache.get(key2))
        // First and third should still be there
        XCTAssertNotNil(await cache.get(key1))
        XCTAssertNotNil(await cache.get(key3))
    }
    
    func testClear() async {
        let cache = ImageCache(configuration: .default)
        
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Store image
        await cache.set(image, forKey: key)
        XCTAssertNotNil(await cache.get(key))
        
        // Clear cache
        await cache.clear()
        
        // Should be empty
        XCTAssertNil(await cache.get(key))
        
        let stats = await cache.statistics()
        XCTAssertEqual(stats.imageCount, 0)
        XCTAssertEqual(stats.memoryUsageBytes, 0)
    }
    
    func testRemove() async {
        let cache = ImageCache(configuration: .default)
        
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Store image
        await cache.set(image, forKey: key)
        XCTAssertNotNil(await cache.get(key))
        
        // Remove image
        await cache.remove(key)
        
        // Should be gone
        XCTAssertNil(await cache.get(key))
    }
    
    func testStatistics() async {
        let cache = ImageCache(configuration: .default)
        
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Initial stats
        var stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
        XCTAssertEqual(stats.imageCount, 0)
        XCTAssertEqual(stats.memoryUsageBytes, 0)
        XCTAssertEqual(stats.hitRate, 0.0)
        
        // Miss
        _ = await cache.get(key)
        stats = await cache.statistics()
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hitRate, 0.0)
        
        // Store and hit
        await cache.set(image, forKey: key)
        _ = await cache.get(key)
        
        stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.imageCount, 1)
        XCTAssertGreaterThan(stats.memoryUsageBytes, 0)
        XCTAssertEqual(stats.hitRate, 0.5) // 1 hit out of 2 total
    }
    
    func testResetStatistics() async {
        let cache = ImageCache(configuration: .default)
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Generate some stats
        _ = await cache.get(key)
        
        var stats = await cache.statistics()
        XCTAssertEqual(stats.misses, 1)
        
        // Reset
        await cache.resetStatistics()
        
        stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
    }
    
    func testDisabledCache() async {
        let cache = ImageCache(configuration: .disabled)
        
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        // Try to store image
        await cache.set(image, forKey: key)
        
        // Should not be cached
        XCTAssertNil(await cache.get(key))
        
        let stats = await cache.statistics()
        XCTAssertEqual(stats.imageCount, 0)
    }
    
    func testMemoryUsageTracking() async {
        let cache = ImageCache(configuration: .default)
        
        guard let image = createTestImage(width: 512, height: 512) else {
            XCTFail("Failed to create test image")
            return
        }
        
        let key = ImageCacheKey(sopInstanceUID: "1.2.3", frameNumber: 0)
        
        await cache.set(image, forKey: key)
        
        let stats = await cache.statistics()
        
        // Should track approximate memory usage
        XCTAssertGreaterThan(stats.memoryUsageBytes, 0)
        XCTAssertGreaterThan(stats.memoryUsageMB, 0)
        
        // For a 512x512 grayscale image (8 bits per pixel), expect around 256KB
        let expectedSize = 512 * 512 * 1 // 1 byte per pixel for 8-bit grayscale
        XCTAssertEqual(stats.memoryUsageBytes, expectedSize, accuracy: 10000)
    }
    
    func testMemoryLimit() async {
        // Cache with very small memory limit
        let config = ImageCache.Configuration(
            maxImages: 100,
            maxMemoryBytes: 300 * 1024 // 300KB - enough for 1 image but not 2
        )
        let cache = ImageCache(configuration: config)
        
        guard let image1 = createTestImage(width: 512, height: 512),
              let image2 = createTestImage(width: 512, height: 512) else {
            XCTFail("Failed to create test images")
            return
        }
        
        let key1 = ImageCacheKey(sopInstanceUID: "1.2.3.1", frameNumber: 0)
        let key2 = ImageCacheKey(sopInstanceUID: "1.2.3.2", frameNumber: 0)
        
        // Add first image
        await cache.set(image1, forKey: key1)
        XCTAssertNotNil(await cache.get(key1))
        
        // Add second image - should evict first due to memory limit
        await cache.set(image2, forKey: key2)
        
        let stats = await cache.statistics()
        
        // Should only have one image (evicted due to memory)
        XCTAssertLessThanOrEqual(stats.memoryUsageBytes, config.maxMemoryBytes)
    }
}

#endif
