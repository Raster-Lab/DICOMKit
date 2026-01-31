import XCTest
@testable import DICOMNetwork

#if canImport(Network)

final class ConnectionPoolConfigurationTests: XCTestCase {
    
    // MARK: - Default Configuration Tests
    
    func test_defaultConfiguration() {
        let config = ConnectionPoolConfiguration.default
        
        XCTAssertEqual(config.maxConnections, 10)
        XCTAssertEqual(config.minConnections, 0)
        XCTAssertEqual(config.idleTimeout, 300)
        XCTAssertEqual(config.healthCheckInterval, 60)
        XCTAssertEqual(config.acquireTimeout, 30)
        XCTAssertFalse(config.validateOnAcquire)
    }
    
    // MARK: - Custom Configuration Tests
    
    func test_customConfiguration() {
        let config = ConnectionPoolConfiguration(
            maxConnections: 20,
            minConnections: 5,
            idleTimeout: 600,
            healthCheckInterval: 120,
            acquireTimeout: 60,
            validateOnAcquire: true
        )
        
        XCTAssertEqual(config.maxConnections, 20)
        XCTAssertEqual(config.minConnections, 5)
        XCTAssertEqual(config.idleTimeout, 600)
        XCTAssertEqual(config.healthCheckInterval, 120)
        XCTAssertEqual(config.acquireTimeout, 60)
        XCTAssertTrue(config.validateOnAcquire)
    }
    
    // MARK: - Preset Configuration Tests
    
    func test_highThroughputConfiguration() {
        let config = ConnectionPoolConfiguration.highThroughput
        
        XCTAssertEqual(config.maxConnections, 20)
        XCTAssertEqual(config.minConnections, 5)
        XCTAssertEqual(config.idleTimeout, 600)
        XCTAssertEqual(config.healthCheckInterval, 120)
        XCTAssertEqual(config.acquireTimeout, 60)
        XCTAssertFalse(config.validateOnAcquire)
    }
    
    func test_lowResourceConfiguration() {
        let config = ConnectionPoolConfiguration.lowResource
        
        XCTAssertEqual(config.maxConnections, 3)
        XCTAssertEqual(config.minConnections, 0)
        XCTAssertEqual(config.idleTimeout, 60)
        XCTAssertNil(config.healthCheckInterval)
        XCTAssertEqual(config.acquireTimeout, 15)
        XCTAssertTrue(config.validateOnAcquire)
    }
    
    // MARK: - Boundary Value Tests
    
    func test_configuration_normalizesInvalidValues() {
        let config = ConnectionPoolConfiguration(
            maxConnections: 0,  // Should be at least 1
            minConnections: -1, // Should be at least 0
            idleTimeout: 0,     // Should be at least 1
            healthCheckInterval: 0, // Should be at least 1
            acquireTimeout: 0   // Should be at least 1
        )
        
        XCTAssertEqual(config.maxConnections, 1)
        XCTAssertEqual(config.minConnections, 0)
        XCTAssertEqual(config.idleTimeout, 1)
        XCTAssertEqual(config.healthCheckInterval, 1)
        XCTAssertEqual(config.acquireTimeout, 1)
    }
    
    func test_configuration_minConnectionsCappedAtMax() {
        let config = ConnectionPoolConfiguration(
            maxConnections: 5,
            minConnections: 10  // Greater than max
        )
        
        XCTAssertEqual(config.maxConnections, 5)
        XCTAssertEqual(config.minConnections, 5)  // Capped at max
    }
    
    func test_configuration_nilHealthCheckInterval() {
        let config = ConnectionPoolConfiguration(
            healthCheckInterval: nil
        )
        
        XCTAssertNil(config.healthCheckInterval)
    }
    
    // MARK: - Hashable Tests
    
    func test_configuration_hashable() {
        let config1 = ConnectionPoolConfiguration(
            maxConnections: 5,
            minConnections: 1,
            idleTimeout: 300
        )
        
        let config2 = ConnectionPoolConfiguration(
            maxConnections: 5,
            minConnections: 1,
            idleTimeout: 300
        )
        
        let config3 = ConnectionPoolConfiguration(
            maxConnections: 10,
            minConnections: 1,
            idleTimeout: 300
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
        XCTAssertEqual(config1.hashValue, config2.hashValue)
    }
}

// MARK: - Pooled Connection Tests

final class PooledConnectionTests: XCTestCase {
    
    func test_pooledConnection_isIdleFor() {
        let config = AssociationConfiguration(
            callingAETitle: "SCU",
            calledAETitle: "SCP",
            host: "localhost",
            port: 11112,
            implementationClassUID: "1.2.3.4.5"
        )
        let association = Association(configuration: config)
        var connection = PooledConnection(association: association)
        
        // Newly created connection should not be idle
        XCTAssertFalse(connection.isIdleFor(timeout: 1))
        
        // Simulate time passing by modifying lastUsedAt
        connection.lastUsedAt = Date().addingTimeInterval(-120)
        
        // Now it should be idle for 60 seconds
        XCTAssertTrue(connection.isIdleFor(timeout: 60))
        
        // But not idle for 180 seconds
        XCTAssertFalse(connection.isIdleFor(timeout: 180))
    }
    
    func test_pooledConnection_markUsed() {
        let config = AssociationConfiguration(
            callingAETitle: "SCU",
            calledAETitle: "SCP",
            host: "localhost",
            port: 11112,
            implementationClassUID: "1.2.3.4.5"
        )
        let association = Association(configuration: config)
        var connection = PooledConnection(association: association)
        
        XCTAssertEqual(connection.useCount, 0)
        
        let oldLastUsed = connection.lastUsedAt
        
        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)
        
        connection.markUsed()
        
        XCTAssertEqual(connection.useCount, 1)
        XCTAssertGreaterThan(connection.lastUsedAt, oldLastUsed)
        
        connection.markUsed()
        XCTAssertEqual(connection.useCount, 2)
    }
    
    func test_pooledConnection_uniqueIds() {
        let config = AssociationConfiguration(
            callingAETitle: "SCU",
            calledAETitle: "SCP",
            host: "localhost",
            port: 11112,
            implementationClassUID: "1.2.3.4.5"
        )
        let association1 = Association(configuration: config)
        let association2 = Association(configuration: config)
        
        let connection1 = PooledConnection(association: association1)
        let connection2 = PooledConnection(association: association2)
        
        XCTAssertNotEqual(connection1.id, connection2.id)
    }
}

// MARK: - Connection Pool Statistics Tests

final class ConnectionPoolStatisticsTests: XCTestCase {
    
    func test_statistics_initialization() {
        let stats = ConnectionPoolStatistics(
            totalConnections: 5,
            availableConnections: 3,
            inUseConnections: 2,
            connectionsCreated: 10,
            connectionsClosed: 5,
            healthChecksSucceeded: 100,
            healthChecksFailed: 3,
            acquisitionCount: 50,
            acquisitionTimeouts: 1
        )
        
        XCTAssertEqual(stats.totalConnections, 5)
        XCTAssertEqual(stats.availableConnections, 3)
        XCTAssertEqual(stats.inUseConnections, 2)
        XCTAssertEqual(stats.connectionsCreated, 10)
        XCTAssertEqual(stats.connectionsClosed, 5)
        XCTAssertEqual(stats.healthChecksSucceeded, 100)
        XCTAssertEqual(stats.healthChecksFailed, 3)
        XCTAssertEqual(stats.acquisitionCount, 50)
        XCTAssertEqual(stats.acquisitionTimeouts, 1)
    }
    
    func test_statistics_consistency() {
        let stats = ConnectionPoolStatistics(
            totalConnections: 5,
            availableConnections: 3,
            inUseConnections: 2,
            connectionsCreated: 10,
            connectionsClosed: 5,
            healthChecksSucceeded: 100,
            healthChecksFailed: 3,
            acquisitionCount: 50,
            acquisitionTimeouts: 1
        )
        
        // Total should equal available + in use
        XCTAssertEqual(stats.totalConnections, stats.availableConnections + stats.inUseConnections)
    }
}

// MARK: - Connection Pool Creation Tests

final class ConnectionPoolCreationTests: XCTestCase {
    
    func test_pool_creation() async throws {
        let clientConfig = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let poolConfig = ConnectionPoolConfiguration.default
        
        let pool = ConnectionPool(
            clientConfiguration: clientConfig,
            poolConfiguration: poolConfig
        )
        
        // Access actor properties with await
        let host = await pool.clientConfiguration.host
        let port = await pool.clientConfiguration.port
        let maxConnections = await pool.poolConfiguration.maxConnections
        
        XCTAssertEqual(host, "pacs.hospital.com")
        XCTAssertEqual(port, 11112)
        XCTAssertEqual(maxConnections, 10)
    }
    
    func test_pool_initialStatistics() async throws {
        let clientConfig = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let pool = ConnectionPool(
            clientConfiguration: clientConfig,
            poolConfiguration: ConnectionPoolConfiguration(minConnections: 0)
        )
        
        let stats = await pool.statistics()
        
        XCTAssertEqual(stats.totalConnections, 0)
        XCTAssertEqual(stats.availableConnections, 0)
        XCTAssertEqual(stats.inUseConnections, 0)
        XCTAssertEqual(stats.connectionsCreated, 0)
        XCTAssertEqual(stats.connectionsClosed, 0)
    }
    
    func test_pool_stopWithoutStart() async throws {
        let clientConfig = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let pool = ConnectionPool(
            clientConfiguration: clientConfig,
            poolConfiguration: .default
        )
        
        // Should not throw when stopping without starting
        await pool.stop()
        
        let stats = await pool.statistics()
        XCTAssertEqual(stats.totalConnections, 0)
    }
}

// MARK: - Connection Pool Acquire/Release Tests (without network)

final class ConnectionPoolAcquireReleaseTests: XCTestCase {
    
    func test_pool_acquireWithoutStart_throwsError() async throws {
        let clientConfig = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let pool = ConnectionPool(
            clientConfiguration: clientConfig,
            poolConfiguration: .default
        )
        
        // Acquire should throw because pool is not started
        do {
            _ = try await pool.acquire(presentationContexts: [])
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected - pool not started
            XCTAssertTrue(error is DICOMNetworkError)
        }
    }
}

#endif
