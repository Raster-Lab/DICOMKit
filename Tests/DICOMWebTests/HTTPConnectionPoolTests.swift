import Testing
import Foundation
@testable import DICOMWeb

@Suite("HTTPConnectionPool Configuration Tests")
struct HTTPConnectionPoolConfigurationTests {
    
    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = HTTPConnectionPoolConfiguration.default
        
        #expect(config.maxConnectionsPerHost == 6)
        #expect(config.maxStreamsPerConnection == 100)
        #expect(config.idleTimeout == 60)
        #expect(config.maxConnectionAge == 600)
        #expect(config.enableKeepAlive == true)
        #expect(config.enableHTTP2 == true)
    }
    
    @Test("High throughput configuration has higher limits")
    func testHighThroughputConfiguration() {
        let config = HTTPConnectionPoolConfiguration.highThroughput
        
        #expect(config.maxConnectionsPerHost == 10)
        #expect(config.maxStreamsPerConnection == 200)
        #expect(config.idleTimeout == 120)
        #expect(config.maxConnectionAge == 1200)
    }
    
    @Test("Low resource configuration has lower limits")
    func testLowResourceConfiguration() {
        let config = HTTPConnectionPoolConfiguration.lowResource
        
        #expect(config.maxConnectionsPerHost == 2)
        #expect(config.maxStreamsPerConnection == 50)
        #expect(config.idleTimeout == 30)
        #expect(config.maxConnectionAge == 300)
    }
    
    @Test("Custom configuration accepts valid values")
    func testCustomConfiguration() {
        let config = HTTPConnectionPoolConfiguration(
            maxConnectionsPerHost: 8,
            maxStreamsPerConnection: 150,
            idleTimeout: 90,
            maxConnectionAge: 800,
            enableKeepAlive: false,
            enableHTTP2: false
        )
        
        #expect(config.maxConnectionsPerHost == 8)
        #expect(config.maxStreamsPerConnection == 150)
        #expect(config.idleTimeout == 90)
        #expect(config.maxConnectionAge == 800)
        #expect(config.enableKeepAlive == false)
        #expect(config.enableHTTP2 == false)
    }
    
    @Test("Configuration normalizes invalid maxConnectionsPerHost to 1")
    func testConfigurationNormalizesMaxConnections() {
        let config = HTTPConnectionPoolConfiguration(maxConnectionsPerHost: 0)
        #expect(config.maxConnectionsPerHost == 1)
        
        let config2 = HTTPConnectionPoolConfiguration(maxConnectionsPerHost: -5)
        #expect(config2.maxConnectionsPerHost == 1)
    }
    
    @Test("Configuration normalizes invalid maxStreamsPerConnection to 1")
    func testConfigurationNormalizesMaxStreams() {
        let config = HTTPConnectionPoolConfiguration(maxStreamsPerConnection: 0)
        #expect(config.maxStreamsPerConnection == 1)
        
        let config2 = HTTPConnectionPoolConfiguration(maxStreamsPerConnection: -10)
        #expect(config2.maxStreamsPerConnection == 1)
    }
    
    @Test("Configuration normalizes invalid idleTimeout to 1")
    func testConfigurationNormalizesIdleTimeout() {
        let config = HTTPConnectionPoolConfiguration(idleTimeout: 0)
        #expect(config.idleTimeout == 1)
        
        let config2 = HTTPConnectionPoolConfiguration(idleTimeout: -30)
        #expect(config2.idleTimeout == 1)
    }
    
    @Test("Configuration normalizes invalid maxConnectionAge to 1")
    func testConfigurationNormalizesMaxAge() {
        let config = HTTPConnectionPoolConfiguration(maxConnectionAge: 0)
        #expect(config.maxConnectionAge == 1)
        
        let config2 = HTTPConnectionPoolConfiguration(maxConnectionAge: -100)
        #expect(config2.maxConnectionAge == 1)
    }
    
    @Test("Configuration is Hashable")
    func testConfigurationHashable() {
        let config1 = HTTPConnectionPoolConfiguration(maxConnectionsPerHost: 5)
        let config2 = HTTPConnectionPoolConfiguration(maxConnectionsPerHost: 5)
        let config3 = HTTPConnectionPoolConfiguration(maxConnectionsPerHost: 10)
        
        #expect(config1 == config2)
        #expect(config1 != config3)
        #expect(config1.hashValue == config2.hashValue)
    }
}

@Suite("HTTPConnectionPool Statistics Tests")
struct HTTPConnectionPoolStatisticsTests {
    
    @Test("Statistics initialization")
    func testStatisticsInitialization() {
        let stats = HTTPConnectionPoolStatistics(
            totalConnections: 10,
            activeConnections: 6,
            idleConnections: 4,
            activeStreams: 25,
            connectionsCreated: 50,
            connectionsClosed: 40,
            connectionsReused: 200,
            connectionsRecycled: 5,
            requestsQueued: 3
        )
        
        #expect(stats.totalConnections == 10)
        #expect(stats.activeConnections == 6)
        #expect(stats.idleConnections == 4)
        #expect(stats.activeStreams == 25)
        #expect(stats.connectionsCreated == 50)
        #expect(stats.connectionsClosed == 40)
        #expect(stats.connectionsReused == 200)
        #expect(stats.connectionsRecycled == 5)
        #expect(stats.requestsQueued == 3)
    }
    
    @Test("Statistics consistency check")
    func testStatisticsConsistency() {
        let stats = HTTPConnectionPoolStatistics(
            totalConnections: 10,
            activeConnections: 6,
            idleConnections: 4,
            activeStreams: 25,
            connectionsCreated: 50,
            connectionsClosed: 40,
            connectionsReused: 200,
            connectionsRecycled: 5,
            requestsQueued: 3
        )
        
        // Total should equal active + idle
        #expect(stats.totalConnections == stats.activeConnections + stats.idleConnections)
    }
}

@Suite("HTTPConnectionPool Pooled Connection Tests")
struct PooledConnectionTests {
    
    @Test("Pooled connection initialization")
    func testPooledConnectionInit() async {
        let pool = HTTPConnectionPool()
        await pool.start()
        
        let connID = await pool.acquireConnection(for: "example.com")
        #expect(connID != UUID())  // Should have a valid UUID
        
        await pool.stop()
    }
    
    @Test("Pooled connection has unique IDs")
    func testUniqueConnectionIDs() async {
        let pool = HTTPConnectionPool()
        await pool.start()
        
        let conn1 = await pool.acquireConnection(for: "example.com")
        let conn2 = await pool.acquireConnection(for: "example.com")
        
        #expect(conn1 != conn2)
        
        await pool.stop()
    }
}

@Suite("HTTPConnectionPool Basic Operations Tests")
struct HTTPConnectionPoolBasicTests {
    
    @Test("Pool starts and stops")
    func testPoolStartStop() async {
        let pool = HTTPConnectionPool()
        
        await pool.start()
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 0)
        
        await pool.stop()
        let statsAfterStop = await pool.statistics()
        #expect(statsAfterStop.totalConnections == 0)
    }
    
    @Test("Pool initial statistics are zero")
    func testInitialStatistics() async {
        let pool = HTTPConnectionPool()
        
        let stats = await pool.statistics()
        
        #expect(stats.totalConnections == 0)
        #expect(stats.activeConnections == 0)
        #expect(stats.idleConnections == 0)
        #expect(stats.activeStreams == 0)
        #expect(stats.connectionsCreated == 0)
        #expect(stats.connectionsClosed == 0)
        #expect(stats.connectionsReused == 0)
        #expect(stats.connectionsRecycled == 0)
        #expect(stats.requestsQueued == 0)
    }
    
    @Test("Acquiring connection creates new connection")
    func testAcquireCreatesConnection() async {
        let pool = HTTPConnectionPool()
        await pool.start()
        
        let connID = await pool.acquireConnection(for: "example.com")
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 1)
        #expect(stats.activeConnections == 1)
        #expect(stats.idleConnections == 0)
        #expect(stats.activeStreams == 1)
        #expect(stats.connectionsCreated == 1)
        
        await pool.stop()
    }
    
    @Test("Releasing connection makes it idle")
    func testReleaseConnection() async {
        let pool = HTTPConnectionPool()
        await pool.start()
        
        let connID = await pool.acquireConnection(for: "example.com")
        await pool.releaseConnection(connID, for: "example.com")
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 1)
        #expect(stats.activeConnections == 0)
        #expect(stats.idleConnections == 1)
        #expect(stats.activeStreams == 0)
        
        await pool.stop()
    }
    
    @Test("Multiple acquires on same host reuse connection")
    func testConnectionReuse() async {
        let config = HTTPConnectionPoolConfiguration(maxStreamsPerConnection: 10)
        let pool = HTTPConnectionPool(configuration: config)
        await pool.start()
        
        let conn1 = await pool.acquireConnection(for: "example.com")
        let conn2 = await pool.acquireConnection(for: "example.com")
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 1)  // Only one connection created
        #expect(stats.activeStreams == 2)     // Two streams on the same connection
        #expect(stats.connectionsReused == 1) // Second acquire reused connection
        
        await pool.stop()
    }
    
    @Test("Exceeding max streams creates new connection")
    func testMaxStreamsCreatesNewConnection() async {
        let config = HTTPConnectionPoolConfiguration(
            maxConnectionsPerHost: 5,
            maxStreamsPerConnection: 2
        )
        let pool = HTTPConnectionPool(configuration: config)
        await pool.start()
        
        let conn1 = await pool.acquireConnection(for: "example.com")
        let conn2 = await pool.acquireConnection(for: "example.com")
        let conn3 = await pool.acquireConnection(for: "example.com")  // Should create new connection
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 2)  // Two connections
        #expect(stats.activeStreams == 3)     // Three streams total
        
        await pool.stop()
    }
    
    @Test("Different hosts have separate connections")
    func testSeparateHostConnections() async {
        let pool = HTTPConnectionPool()
        await pool.start()
        
        _ = await pool.acquireConnection(for: "example.com")
        _ = await pool.acquireConnection(for: "other.com")
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 2)  // One for each host
        #expect(stats.activeStreams == 2)
        
        await pool.stop()
    }
    
    @Test("Exceeding max connections per host queues request")
    func testMaxConnectionsPerHostQueues() async {
        let config = HTTPConnectionPoolConfiguration(
            maxConnectionsPerHost: 2,
            maxStreamsPerConnection: 1
        )
        let pool = HTTPConnectionPool(configuration: config)
        await pool.start()
        
        // Create 2 connections with 1 stream each
        _ = await pool.acquireConnection(for: "example.com")
        _ = await pool.acquireConnection(for: "example.com")
        
        // Try to acquire a third - should reuse least loaded
        _ = await pool.acquireConnection(for: "example.com")
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections == 2)  // Still only 2 connections
        #expect(stats.activeStreams == 3)     // But 3 streams (overloaded)
        #expect(stats.requestsQueued == 1)    // One request had to queue
        
        await pool.stop()
    }
}

@Suite("HTTPConnectionPool Lifecycle Tests")
struct HTTPConnectionPoolLifecycleTests {
    
    @Test("Pool can be stopped and restarted")
    func testPoolRestartable() async {
        let pool = HTTPConnectionPool()
        
        await pool.start()
        _ = await pool.acquireConnection(for: "example.com")
        await pool.stop()
        
        let stats1 = await pool.statistics()
        #expect(stats1.totalConnections == 0)  // Connections closed on stop
        
        await pool.start()
        _ = await pool.acquireConnection(for: "example.com")
        
        let stats2 = await pool.statistics()
        #expect(stats2.totalConnections == 1)
        
        await pool.stop()
    }
    
    @Test("Stopping pool closes all connections")
    func testStopClosesAllConnections() async {
        let pool = HTTPConnectionPool()
        await pool.start()
        
        // Create multiple connections
        _ = await pool.acquireConnection(for: "example.com")
        _ = await pool.acquireConnection(for: "other.com")
        _ = await pool.acquireConnection(for: "third.com")
        
        let statsBefore = await pool.statistics()
        #expect(statsBefore.totalConnections == 3)
        
        await pool.stop()
        
        let statsAfter = await pool.statistics()
        #expect(statsAfter.totalConnections == 0)
    }
}

@Suite("HTTPConnectionPool Configuration Variants Tests")
struct HTTPConnectionPoolConfigurationVariantsTests {
    
    @Test("High throughput configuration allows more connections")
    func testHighThroughputConfig() async {
        let pool = HTTPConnectionPool(configuration: .highThroughput)
        await pool.start()
        
        // Should be able to create up to 10 connections
        for _ in 0..<10 {
            _ = await pool.acquireConnection(for: "example.com")
        }
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections <= 10)
        
        await pool.stop()
    }
    
    @Test("Low resource configuration limits connections")
    func testLowResourceConfig() async {
        let config = HTTPConnectionPoolConfiguration.lowResource
        let pool = HTTPConnectionPool(configuration: config)
        await pool.start()
        
        // Try to create more than allowed
        for _ in 0..<5 {
            _ = await pool.acquireConnection(for: "example.com")
        }
        
        let stats = await pool.statistics()
        #expect(stats.totalConnections <= config.maxConnectionsPerHost)
        
        await pool.stop()
    }
}
