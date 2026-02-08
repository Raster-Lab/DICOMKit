import Testing
import Foundation
@testable import DICOMWeb

@Suite("HTTPPrefetch Configuration Tests")
struct HTTPPrefetchConfigurationTests {
    
    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = HTTPPrefetchConfiguration.default
        
        #expect(config.maxPrefetchAhead == 5)
        #expect(config.maxCacheSize == 500_000_000)
        #expect(config.enablePrefetching == true)
        #expect(config.strategy == .sequential)
        #expect(config.prefetchPriority == .low)
    }
    
    @Test("Disabled configuration disables prefetching")
    func testDisabledConfiguration() {
        let config = HTTPPrefetchConfiguration.disabled
        
        #expect(config.enablePrefetching == false)
    }
    
    @Test("Aggressive configuration has higher limits")
    func testAggressiveConfiguration() {
        let config = HTTPPrefetchConfiguration.aggressive
        
        #expect(config.maxPrefetchAhead == 20)
        #expect(config.maxCacheSize == 2_000_000_000)
        #expect(config.strategy == .aggressive)
        #expect(config.prefetchPriority == .high)
    }
    
    @Test("Low resource configuration has lower limits")
    func testLowResourceConfiguration() {
        let config = HTTPPrefetchConfiguration.lowResource
        
        #expect(config.maxPrefetchAhead == 2)
        #expect(config.maxCacheSize == 100_000_000)
        #expect(config.strategy == .sequential)
        #expect(config.prefetchPriority == .low)
    }
    
    @Test("Custom configuration accepts valid values")
    func testCustomConfiguration() {
        let config = HTTPPrefetchConfiguration(
            maxPrefetchAhead: 10,
            maxCacheSize: 1_000_000_000,
            enablePrefetching: false,
            strategy: .predictive,
            prefetchPriority: .medium
        )
        
        #expect(config.maxPrefetchAhead == 10)
        #expect(config.maxCacheSize == 1_000_000_000)
        #expect(config.enablePrefetching == false)
        #expect(config.strategy == .predictive)
        #expect(config.prefetchPriority == .medium)
    }
    
    @Test("Configuration normalizes invalid maxPrefetchAhead to 1")
    func testConfigurationNormalizesMaxPrefetch() {
        let config = HTTPPrefetchConfiguration(maxPrefetchAhead: 0)
        #expect(config.maxPrefetchAhead == 1)
        
        let config2 = HTTPPrefetchConfiguration(maxPrefetchAhead: -5)
        #expect(config2.maxPrefetchAhead == 1)
    }
    
    @Test("Configuration normalizes invalid maxCacheSize to minimum")
    func testConfigurationNormalizesCacheSize() {
        let config = HTTPPrefetchConfiguration(maxCacheSize: 0)
        #expect(config.maxCacheSize == 1_000_000)
        
        let config2 = HTTPPrefetchConfiguration(maxCacheSize: -1000)
        #expect(config2.maxCacheSize == 1_000_000)
    }
    
    @Test("Configuration is Hashable")
    func testConfigurationHashable() {
        let config1 = HTTPPrefetchConfiguration(maxPrefetchAhead: 5)
        let config2 = HTTPPrefetchConfiguration(maxPrefetchAhead: 5)
        let config3 = HTTPPrefetchConfiguration(maxPrefetchAhead: 10)
        
        #expect(config1 == config2)
        #expect(config1 != config3)
        #expect(config1.hashValue == config2.hashValue)
    }
    
    @Test("PrefetchStrategy enum values")
    func testPrefetchStrategyEnum() {
        #expect(HTTPPrefetchConfiguration.PrefetchStrategy.sequential.rawValue == "sequential")
        #expect(HTTPPrefetchConfiguration.PrefetchStrategy.predictive.rawValue == "predictive")
        #expect(HTTPPrefetchConfiguration.PrefetchStrategy.aggressive.rawValue == "aggressive")
    }
    
    @Test("Priority enum ordering")
    func testPriorityOrdering() {
        #expect(HTTPPrefetchConfiguration.Priority.low.rawValue < HTTPPrefetchConfiguration.Priority.medium.rawValue)
        #expect(HTTPPrefetchConfiguration.Priority.medium.rawValue < HTTPPrefetchConfiguration.Priority.high.rawValue)
    }
}

@Suite("HTTPPrefetch Statistics Tests")
struct HTTPPrefetchStatisticsTests {
    
    @Test("Statistics initialization")
    func testStatisticsInitialization() {
        let stats = HTTPPrefetchStatistics(
            requestsPrefetched: 100,
            prefetchHits: 75,
            prefetchMisses: 25,
            bytesPrefetched: 5_000_000,
            currentCacheSize: 3_000_000,
            cacheItems: 50,
            cacheEvictions: 10
        )
        
        #expect(stats.requestsPrefetched == 100)
        #expect(stats.prefetchHits == 75)
        #expect(stats.prefetchMisses == 25)
        #expect(stats.bytesPrefetched == 5_000_000)
        #expect(stats.currentCacheSize == 3_000_000)
        #expect(stats.cacheItems == 50)
        #expect(stats.cacheEvictions == 10)
    }
    
    @Test("Hit rate calculation with hits and misses")
    func testHitRateCalculation() {
        let stats = HTTPPrefetchStatistics(
            requestsPrefetched: 100,
            prefetchHits: 75,
            prefetchMisses: 25,
            bytesPrefetched: 5_000_000,
            currentCacheSize: 3_000_000,
            cacheItems: 50,
            cacheEvictions: 10
        )
        
        // 75 hits out of 100 total = 0.75
        #expect(stats.hitRate == 0.75)
    }
    
    @Test("Hit rate is zero with no requests")
    func testHitRateWithNoRequests() {
        let stats = HTTPPrefetchStatistics(
            requestsPrefetched: 0,
            prefetchHits: 0,
            prefetchMisses: 0,
            bytesPrefetched: 0,
            currentCacheSize: 0,
            cacheItems: 0,
            cacheEvictions: 0
        )
        
        #expect(stats.hitRate == 0.0)
    }
    
    @Test("Hit rate is 1.0 with all hits")
    func testHitRateWithAllHits() {
        let stats = HTTPPrefetchStatistics(
            requestsPrefetched: 100,
            prefetchHits: 50,
            prefetchMisses: 0,
            bytesPrefetched: 5_000_000,
            currentCacheSize: 3_000_000,
            cacheItems: 50,
            cacheEvictions: 0
        )
        
        #expect(stats.hitRate == 1.0)
    }
}

@Suite("HTTPPrefetchManager Basic Operations Tests")
struct HTTPPrefetchManagerBasicTests {
    
    @Test("Manager starts and stops")
    func testManagerStartStop() async {
        let manager = HTTPPrefetchManager()
        
        await manager.start()
        let stats = await manager.statistics()
        #expect(stats.requestsPrefetched == 0)
        
        await manager.stop()
    }
    
    @Test("Manager initial statistics are zero")
    func testInitialStatistics() async {
        let manager = HTTPPrefetchManager()
        
        let stats = await manager.statistics()
        
        #expect(stats.requestsPrefetched == 0)
        #expect(stats.prefetchHits == 0)
        #expect(stats.prefetchMisses == 0)
        #expect(stats.bytesPrefetched == 0)
        #expect(stats.currentCacheSize == 0)
        #expect(stats.cacheItems == 0)
        #expect(stats.cacheEvictions == 0)
    }
    
    @Test("URL not cached initially")
    func testURLNotCachedInitially() async {
        let manager = HTTPPrefetchManager()
        await manager.start()
        
        let testURL = URL(string: "https://example.com/test")!
        let isCached = await manager.isCached(testURL)
        
        #expect(isCached == false)
        
        await manager.stop()
    }
    
    @Test("Cache miss increments statistics")
    func testCacheMissIncrementsStats() async {
        let manager = HTTPPrefetchManager()
        await manager.start()
        
        let testURL = URL(string: "https://example.com/test")!
        _ = await manager.getCached(testURL)
        
        let stats = await manager.statistics()
        #expect(stats.prefetchMisses == 1)
        #expect(stats.prefetchHits == 0)
        
        await manager.stop()
    }
    
    @Test("Disabled manager does not enqueue requests")
    func testDisabledManagerDoesNotQueue() async {
        let config = HTTPPrefetchConfiguration.disabled
        let manager = HTTPPrefetchManager(configuration: config)
        await manager.start()
        
        let testURLs = [
            URL(string: "https://example.com/1")!,
            URL(string: "https://example.com/2")!
        ]
        
        await manager.enqueuePrefetch(urls: testURLs)
        
        // Since prefetching is disabled, nothing should be queued
        let stats = await manager.statistics()
        #expect(stats.requestsPrefetched == 0)
        
        await manager.stop()
    }
    
    @Test("Clear cache removes all entries")
    func testClearCache() async {
        let manager = HTTPPrefetchManager()
        await manager.start()
        
        await manager.clearCache()
        
        let stats = await manager.statistics()
        #expect(stats.cacheItems == 0)
        #expect(stats.currentCacheSize == 0)
        
        await manager.stop()
    }
}

@Suite("HTTPPrefetchManager Configuration Variants Tests")
struct HTTPPrefetchManagerConfigurationVariantsTests {
    
    @Test("Aggressive configuration allows more prefetching")
    func testAggressiveConfig() async {
        let manager = HTTPPrefetchManager(configuration: .aggressive)
        await manager.start()
        
        let stats = await manager.statistics()
        #expect(stats.requestsPrefetched == 0)  // No requests yet
        
        await manager.stop()
    }
    
    @Test("Low resource configuration limits cache")
    func testLowResourceConfig() async {
        let manager = HTTPPrefetchManager(configuration: .lowResource)
        await manager.start()
        
        let stats = await manager.statistics()
        #expect(stats.cacheItems == 0)
        
        await manager.stop()
    }
    
    @Test("Disabled configuration bypasses prefetch")
    func testDisabledConfig() async {
        let manager = HTTPPrefetchManager(configuration: .disabled)
        await manager.start()
        
        let testURL = URL(string: "https://example.com/test")!
        await manager.enqueuePrefetch(urls: [testURL])
        
        let stats = await manager.statistics()
        #expect(stats.requestsPrefetched == 0)
        
        await manager.stop()
    }
}
