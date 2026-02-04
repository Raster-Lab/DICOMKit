import XCTest
@testable import DICOMWeb

/// Tests for caching functionality
final class CachingTests: XCTestCase {
    
    // MARK: - CacheConfiguration Tests
    
    func testDefaultConfiguration() {
        let config = CacheConfiguration.default
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxEntries, 1000)
        XCTAssertEqual(config.maxSizeBytes, 100 * 1024 * 1024)
        XCTAssertEqual(config.defaultTTL, 300)
        XCTAssertTrue(config.useETags)
        XCTAssertTrue(config.useLastModified)
        XCTAssertTrue(config.respectCacheControl)
    }
    
    func testDisabledConfiguration() {
        let config = CacheConfiguration.disabled
        XCTAssertFalse(config.enabled)
    }
    
    func testMinimalConfiguration() {
        let config = CacheConfiguration.minimal
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxEntries, 100)
        XCTAssertEqual(config.maxSizeBytes, 10 * 1024 * 1024)
        XCTAssertEqual(config.defaultTTL, 60)
    }
    
    func testAggressiveConfiguration() {
        let config = CacheConfiguration.aggressive
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxEntries, 10000)
        XCTAssertEqual(config.maxSizeBytes, 500 * 1024 * 1024)
        XCTAssertEqual(config.defaultTTL, 3600)
    }
    
    // MARK: - CacheEntry Tests
    
    func testCacheEntryCreation() {
        let data = "test data".data(using: .utf8)!
        let entry = CacheEntry(
            data: data,
            contentType: "application/json",
            etag: "\"abc123\"",
            lastModified: Date(),
            expiresAt: Date().addingTimeInterval(300)
        )
        
        XCTAssertEqual(entry.data, data)
        XCTAssertEqual(entry.contentType, "application/json")
        XCTAssertEqual(entry.etag, "\"abc123\"")
        XCTAssertNotNil(entry.lastModified)
        XCTAssertNotNil(entry.expiresAt)
        XCTAssertEqual(entry.size, data.count)
    }
    
    func testCacheEntryExpiration() {
        let data = Data()
        
        // Not expired
        let validEntry = CacheEntry(
            data: data,
            expiresAt: Date().addingTimeInterval(300)
        )
        XCTAssertFalse(validEntry.isExpired)
        
        // Expired
        let expiredEntry = CacheEntry(
            data: data,
            expiresAt: Date().addingTimeInterval(-100)
        )
        XCTAssertTrue(expiredEntry.isExpired)
        
        // No expiration
        let noExpirationEntry = CacheEntry(data: data)
        XCTAssertFalse(noExpirationEntry.isExpired)
    }
    
    func testCacheEntryCanValidate() {
        let data = Data()
        
        // Has ETag
        let withETag = CacheEntry(data: data, etag: "\"test\"")
        XCTAssertTrue(withETag.canValidate)
        
        // Has Last-Modified
        let withLastModified = CacheEntry(data: data, lastModified: Date())
        XCTAssertTrue(withLastModified.canValidate)
        
        // Has neither
        let withNeither = CacheEntry(data: data)
        XCTAssertFalse(withNeither.canValidate)
    }
    
    // MARK: - InMemoryCache Tests
    
    func testCacheSetAndGet() async {
        let cache = InMemoryCache(configuration: .default)
        let data = "test data".data(using: .utf8)!
        let entry = CacheEntry(data: data)
        
        await cache.set(entry, forKey: "test-key")
        
        let retrieved = await cache.get("test-key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.data, data)
    }
    
    func testCacheMiss() async {
        let cache = InMemoryCache(configuration: .default)
        
        let retrieved = await cache.get("nonexistent")
        XCTAssertNil(retrieved)
    }
    
    func testCacheRemove() async {
        let cache = InMemoryCache(configuration: .default)
        let data = Data()
        let entry = CacheEntry(data: data)
        
        await cache.set(entry, forKey: "test-key")
        await cache.remove("test-key")
        
        let retrieved = await cache.get("test-key")
        XCTAssertNil(retrieved)
    }
    
    func testCacheClear() async {
        let cache = InMemoryCache(configuration: .default)
        let data = Data()
        let entry = CacheEntry(data: data)
        
        await cache.set(entry, forKey: "key1")
        await cache.set(entry, forKey: "key2")
        await cache.clear()
        
        let stats = await cache.getStats()
        XCTAssertEqual(stats.entryCount, 0)
    }
    
    func testCacheExpiredEntryNotReturned() async {
        let cache = InMemoryCache(configuration: .default)
        let data = Data()
        let expiredEntry = CacheEntry(
            data: data,
            expiresAt: Date().addingTimeInterval(-100)
        )
        
        await cache.set(expiredEntry, forKey: "expired")
        
        let retrieved = await cache.get("expired")
        XCTAssertNil(retrieved)
    }
    
    func testCacheEvictionByCount() async {
        let config = CacheConfiguration(maxEntries: 3)
        let cache = InMemoryCache(configuration: config)
        
        for i in 0..<5 {
            let entry = CacheEntry(data: "data\(i)".data(using: .utf8)!)
            await cache.set(entry, forKey: "key\(i)")
        }
        
        let stats = await cache.getStats()
        XCTAssertLessThanOrEqual(stats.entryCount, 3)
    }
    
    func testCacheEvictionBySize() async {
        let config = CacheConfiguration(maxSizeBytes: 100)
        let cache = InMemoryCache(configuration: config)
        
        // Each entry is ~50 bytes
        let largeData = Data(repeating: 0, count: 50)
        
        for i in 0..<5 {
            let entry = CacheEntry(data: largeData)
            await cache.set(entry, forKey: "key\(i)")
        }
        
        let stats = await cache.getStats()
        XCTAssertLessThanOrEqual(stats.totalSize, 100)
    }
    
    func testCacheStats() async {
        let cache = InMemoryCache(configuration: .default)
        let data = "test".data(using: .utf8)!
        let entry = CacheEntry(data: data)
        
        await cache.set(entry, forKey: "key1")
        _ = await cache.get("key1") // Hit
        _ = await cache.get("key2") // Miss
        
        let stats = await cache.getStats()
        XCTAssertEqual(stats.entryCount, 1)
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hitRatio, 0.5)
    }
    
    func testCacheDisabled() async {
        let cache = InMemoryCache(configuration: .disabled)
        let data = Data()
        let entry = CacheEntry(data: data)
        
        await cache.set(entry, forKey: "key")
        let retrieved = await cache.get("key")
        
        XCTAssertNil(retrieved)
    }
    
    // MARK: - CacheKeyGenerator Tests
    
    func testCacheKeyForURL() {
        let url = URL(string: "https://example.com/studies/1.2.3")!
        let key = CacheKeyGenerator.key(for: url)
        
        XCTAssertEqual(key, "https://example.com/studies/1.2.3")
    }
    
    func testCacheKeyForURLWithHeaders() {
        let url = URL(string: "https://example.com/studies")!
        let headers = [
            "Accept": "application/dicom+json",
            "Authorization": "Bearer token"  // Should be ignored
        ]
        
        let key = CacheKeyGenerator.key(for: url, headers: headers)
        
        XCTAssertTrue(key.contains("https://example.com/studies"))
        XCTAssertTrue(key.contains("Accept:application/dicom+json"))
        XCTAssertFalse(key.contains("Authorization"))
    }
    
    func testCacheMetadataKey() {
        let studyKey = CacheKeyGenerator.metadataKey(studyUID: "1.2.3")
        XCTAssertEqual(studyKey, "metadata/1.2.3")
        
        let seriesKey = CacheKeyGenerator.metadataKey(studyUID: "1.2.3", seriesUID: "4.5.6")
        XCTAssertEqual(seriesKey, "metadata/1.2.3/4.5.6")
        
        let instanceKey = CacheKeyGenerator.metadataKey(
            studyUID: "1.2.3",
            seriesUID: "4.5.6",
            instanceUID: "7.8.9"
        )
        XCTAssertEqual(instanceKey, "metadata/1.2.3/4.5.6/7.8.9")
    }
    
    // MARK: - CacheControlDirective Tests
    
    func testCacheControlParsing() {
        let header = "public, max-age=3600, must-revalidate"
        let directive = CacheControlDirective(headerValue: header)
        
        XCTAssertTrue(directive.isPublic)
        XCTAssertEqual(directive.maxAge, 3600)
        XCTAssertTrue(directive.mustRevalidate)
        XCTAssertFalse(directive.noStore)
        XCTAssertFalse(directive.noCache)
    }
    
    func testCacheControlNoStore() {
        let directive = CacheControlDirective(headerValue: "no-store")
        
        XCTAssertTrue(directive.noStore)
        XCTAssertFalse(directive.shouldCache)
    }
    
    func testCacheControlNoCache() {
        let directive = CacheControlDirective(headerValue: "no-cache")
        
        XCTAssertTrue(directive.noCache)
        XCTAssertTrue(directive.shouldCache) // no-cache still allows caching with validation
    }
    
    func testCacheControlExpirationDate() {
        let directive = CacheControlDirective(headerValue: "max-age=600")
        
        let expiration = directive.expirationDate()
        let expectedExpiration = Date().addingTimeInterval(600)
        
        // Allow 1 second tolerance
        XCTAssertEqual(expiration.timeIntervalSince1970, expectedExpiration.timeIntervalSince1970, accuracy: 1)
    }
    
    func testCacheControlFallbackTTL() {
        let directive = CacheControlDirective(headerValue: "public")
        
        let expiration = directive.expirationDate(fallbackTTL: 120)
        let expectedExpiration = Date().addingTimeInterval(120)
        
        XCTAssertEqual(expiration.timeIntervalSince1970, expectedExpiration.timeIntervalSince1970, accuracy: 1)
    }
    
    func testCacheControlStaleWhileRevalidate() {
        let directive = CacheControlDirective(headerValue: "max-age=300, stale-while-revalidate=60")
        
        XCTAssertEqual(directive.maxAge, 300)
        XCTAssertEqual(directive.staleWhileRevalidate, 60)
    }
}
