import XCTest
@testable import DICOMNetwork

#if canImport(Network)

// MARK: - Server Entry Tests

final class ServerEntryTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_serverEntry_initializationWithAETitle() {
        let aeTitle = try! AETitle("PACS_SERVER")
        let server = ServerEntry(
            host: "pacs.hospital.com",
            port: 11112,
            aeTitle: aeTitle,
            priority: 10,
            weight: 2.0
        )
        
        XCTAssertEqual(server.host, "pacs.hospital.com")
        XCTAssertEqual(server.port, 11112)
        XCTAssertEqual(server.aeTitle.value, "PACS_SERVER")
        XCTAssertEqual(server.priority, 10)
        XCTAssertEqual(server.weight, 2.0)
        XCTAssertTrue(server.isEnabled)
        XCTAssertNil(server.tlsConfiguration)
        XCTAssertNil(server.userIdentity)
    }
    
    func test_serverEntry_initializationWithStringAETitle() throws {
        let server = try ServerEntry(
            host: "pacs.hospital.com",
            port: 11112,
            aeTitle: "PACS_SERVER",
            priority: 5
        )
        
        XCTAssertEqual(server.aeTitle.value, "PACS_SERVER")
        XCTAssertEqual(server.priority, 5)
        XCTAssertEqual(server.weight, 1.0) // Default
    }
    
    func test_serverEntry_invalidAETitleThrows() {
        XCTAssertThrowsError(try ServerEntry(
            host: "test.com",
            port: 104,
            aeTitle: "THIS_IS_TOO_LONG_FOR_AE_TITLE"
        ))
    }
    
    func test_serverEntry_defaultValues() {
        let aeTitle = try! AETitle("TEST")
        let server = ServerEntry(host: "test.com", aeTitle: aeTitle)
        
        XCTAssertEqual(server.port, dicomDefaultPort)
        XCTAssertEqual(server.priority, 0)
        XCTAssertEqual(server.weight, 1.0)
        XCTAssertTrue(server.isEnabled)
        XCTAssertEqual(server.maxPDUSize, defaultMaxPDUSize)
        XCTAssertEqual(server.timeout, 60)
    }
    
    func test_serverEntry_weightNormalization() {
        let aeTitle = try! AETitle("TEST")
        let server = ServerEntry(
            host: "test.com",
            aeTitle: aeTitle,
            weight: -5.0 // Negative weight
        )
        
        // Weight should be normalized to minimum positive value
        XCTAssertGreaterThan(server.weight, 0)
    }
    
    func test_serverEntry_description() {
        let aeTitle = try! AETitle("PACS")
        let server = ServerEntry(
            host: "test.com",
            port: 11112,
            aeTitle: aeTitle,
            priority: 5,
            weight: 2.0
        )
        
        let description = server.description
        XCTAssertTrue(description.contains("PACS"))
        XCTAssertTrue(description.contains("test.com"))
        XCTAssertTrue(description.contains("11112"))
    }
    
    func test_serverEntry_identifiable() {
        let aeTitle = try! AETitle("TEST")
        let server1 = ServerEntry(host: "test1.com", aeTitle: aeTitle)
        let server2 = ServerEntry(host: "test2.com", aeTitle: aeTitle)
        
        // Each server should have a unique ID
        XCTAssertNotEqual(server1.id, server2.id)
    }
    
    func test_serverEntry_hashable() {
        let aeTitle = try! AETitle("TEST")
        let server1 = ServerEntry(host: "test.com", aeTitle: aeTitle)
        let server2 = ServerEntry(host: "test.com", aeTitle: aeTitle)
        
        // Different instances with same parameters should have different IDs
        var set = Set<ServerEntry>()
        set.insert(server1)
        set.insert(server2)
        
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - Server Selection Strategy Tests

final class ServerSelectionStrategyTests: XCTestCase {
    
    func test_selectionStrategy_description() {
        XCTAssertEqual(ServerSelectionStrategy.roundRobin.description, "RoundRobin")
        XCTAssertEqual(ServerSelectionStrategy.priority.description, "Priority")
        XCTAssertEqual(ServerSelectionStrategy.weightedRoundRobin.description, "WeightedRoundRobin")
        XCTAssertEqual(ServerSelectionStrategy.random.description, "Random")
        XCTAssertEqual(ServerSelectionStrategy.randomWeighted.description, "RandomWeighted")
        XCTAssertEqual(ServerSelectionStrategy.failover.description, "Failover")
    }
    
    func test_selectionStrategy_hashable() {
        let strategies: Set<ServerSelectionStrategy> = [
            .roundRobin, .priority, .weightedRoundRobin, .random, .randomWeighted, .failover
        ]
        XCTAssertEqual(strategies.count, 6)
    }
}

// MARK: - Server Pool Tests

final class ServerPoolTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_serverPool_emptyInitialization() {
        let pool = ServerPool()
        
        XCTAssertTrue(pool.isEmpty)
        XCTAssertEqual(pool.count, 0)
        XCTAssertEqual(pool.enabledCount, 0)
        XCTAssertFalse(pool.hasEnabledServers)
    }
    
    func test_serverPool_initializationWithServers() throws {
        let server1 = try ServerEntry(host: "server1.com", aeTitle: "S1")
        let server2 = try ServerEntry(host: "server2.com", aeTitle: "S2")
        
        let pool = ServerPool(servers: [server1, server2], selectionStrategy: .priority)
        
        XCTAssertEqual(pool.count, 2)
        XCTAssertEqual(pool.enabledCount, 2)
        XCTAssertTrue(pool.hasEnabledServers)
    }
    
    // MARK: - Server Management Tests
    
    func test_serverPool_addServer() throws {
        var pool = ServerPool()
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        
        pool.addServer(server)
        
        XCTAssertEqual(pool.count, 1)
        XCTAssertTrue(pool.hasEnabledServers)
    }
    
    func test_serverPool_addServerWithParameters() throws {
        var pool = ServerPool()
        
        try pool.addServer(host: "test.com", port: 11112, aeTitle: "TEST", priority: 5)
        
        XCTAssertEqual(pool.count, 1)
        XCTAssertEqual(pool.allServers.first?.priority, 5)
    }
    
    func test_serverPool_removeServer() throws {
        var pool = ServerPool()
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        pool.addServer(server)
        
        let removed = pool.removeServer(id: server.id)
        
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.id, server.id)
        XCTAssertEqual(pool.count, 0)
    }
    
    func test_serverPool_removeNonexistentServer() throws {
        var pool = ServerPool()
        
        let removed = pool.removeServer(id: UUID())
        
        XCTAssertNil(removed)
    }
    
    func test_serverPool_setServerEnabled() throws {
        var pool = ServerPool()
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        pool.addServer(server)
        
        pool.setServerEnabled(id: server.id, enabled: false)
        
        XCTAssertEqual(pool.enabledCount, 0)
        XCTAssertFalse(pool.hasEnabledServers)
        
        pool.setServerEnabled(id: server.id, enabled: true)
        
        XCTAssertEqual(pool.enabledCount, 1)
        XCTAssertTrue(pool.hasEnabledServers)
    }
    
    func test_serverPool_allServers() throws {
        var pool = ServerPool()
        let server1 = try ServerEntry(host: "s1.com", aeTitle: "S1")
        let server2 = try ServerEntry(host: "s2.com", aeTitle: "S2")
        
        pool.addServer(server1)
        pool.addServer(server2)
        pool.setServerEnabled(id: server1.id, enabled: false)
        
        XCTAssertEqual(pool.allServers.count, 2)
        XCTAssertEqual(pool.enabledServers.count, 1)
    }
    
    // MARK: - Round Robin Selection Tests
    
    func test_serverPool_roundRobinSelection() throws {
        var pool = ServerPool(selectionStrategy: .roundRobin)
        try pool.addServer(host: "s1.com", aeTitle: "S1")
        try pool.addServer(host: "s2.com", aeTitle: "S2")
        try pool.addServer(host: "s3.com", aeTitle: "S3")
        
        let first = pool.selectServer()
        let second = pool.selectServer()
        let third = pool.selectServer()
        let fourth = pool.selectServer() // Should wrap around
        
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotNil(third)
        XCTAssertNotNil(fourth)
        
        // Round robin should cycle through servers
        XCTAssertEqual(first?.host, fourth?.host)
    }
    
    // MARK: - Priority Selection Tests
    
    func test_serverPool_prioritySelection() throws {
        var pool = ServerPool(selectionStrategy: .priority)
        try pool.addServer(host: "low.com", aeTitle: "LOW", priority: 1)
        try pool.addServer(host: "high.com", aeTitle: "HIGH", priority: 10)
        try pool.addServer(host: "medium.com", aeTitle: "MED", priority: 5)
        
        let selected = pool.selectServer()
        
        XCTAssertNotNil(selected)
        XCTAssertEqual(selected?.host, "high.com")
        XCTAssertEqual(selected?.priority, 10)
    }
    
    // MARK: - Failover Selection Tests
    
    func test_serverPool_failoverSelection() throws {
        var pool = ServerPool(selectionStrategy: .failover)
        try pool.addServer(host: "primary.com", aeTitle: "PRIMARY", priority: 10)
        try pool.addServer(host: "backup.com", aeTitle: "BACKUP", priority: 5)
        
        // Failover always selects highest priority (primary)
        let first = pool.selectServer()
        let second = pool.selectServer()
        
        XCTAssertEqual(first?.host, "primary.com")
        XCTAssertEqual(second?.host, "primary.com")
    }
    
    // MARK: - Random Selection Tests
    
    func test_serverPool_randomSelection() throws {
        var pool = ServerPool(selectionStrategy: .random)
        try pool.addServer(host: "s1.com", aeTitle: "S1")
        try pool.addServer(host: "s2.com", aeTitle: "S2")
        
        // Run multiple selections - should not crash
        for _ in 0..<10 {
            let selected = pool.selectServer()
            XCTAssertNotNil(selected)
        }
    }
    
    // MARK: - Weighted Round Robin Tests
    
    func test_serverPool_weightedRoundRobinSelection() throws {
        var pool = ServerPool(selectionStrategy: .weightedRoundRobin)
        try pool.addServer(host: "heavy.com", aeTitle: "HEAVY", weight: 3.0)
        try pool.addServer(host: "light.com", aeTitle: "LIGHT", weight: 1.0)
        
        var heavyCount = 0
        var lightCount = 0
        
        // Select 100 times
        for _ in 0..<100 {
            if let server = pool.selectServer() {
                if server.host == "heavy.com" {
                    heavyCount += 1
                } else {
                    lightCount += 1
                }
            }
        }
        
        // Heavy should be selected approximately 3x more than light
        // With weighted round robin, the ratio should be close to 3:1
        XCTAssertGreaterThan(heavyCount, lightCount)
    }
    
    // MARK: - Empty Pool Tests
    
    func test_serverPool_selectFromEmpty() {
        var pool = ServerPool()
        
        let selected = pool.selectServer()
        
        XCTAssertNil(selected)
    }
    
    func test_serverPool_selectWithAllDisabled() throws {
        var pool = ServerPool()
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        pool.addServer(server)
        pool.setServerEnabled(id: server.id, enabled: false)
        
        let selected = pool.selectServer()
        
        XCTAssertNil(selected)
    }
    
    // MARK: - Select By ID Tests
    
    func test_serverPool_selectServerByID() throws {
        var pool = ServerPool()
        let server1 = try ServerEntry(host: "s1.com", aeTitle: "S1")
        let server2 = try ServerEntry(host: "s2.com", aeTitle: "S2")
        pool.addServer(server1)
        pool.addServer(server2)
        
        let selected = pool.selectServer(id: server2.id)
        
        XCTAssertNotNil(selected)
        XCTAssertEqual(selected?.id, server2.id)
    }
    
    func test_serverPool_selectServerByIDDisabled() throws {
        var pool = ServerPool()
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        pool.addServer(server)
        pool.setServerEnabled(id: server.id, enabled: false)
        
        let selected = pool.selectServer(id: server.id)
        
        XCTAssertNil(selected) // Disabled servers should not be selected
    }
    
    // MARK: - Description Tests
    
    func test_serverPool_description() throws {
        var pool = ServerPool(selectionStrategy: .roundRobin)
        try pool.addServer(host: "s1.com", aeTitle: "S1")
        try pool.addServer(host: "s2.com", aeTitle: "S2")
        
        guard let firstServer = pool.allServers.first else {
            XCTFail("Expected at least one server in the pool")
            return
        }
        pool.setServerEnabled(id: firstServer.id, enabled: false)
        
        let description = pool.description
        
        XCTAssertTrue(description.contains("2 servers"))
        XCTAssertTrue(description.contains("1 enabled"))
        XCTAssertTrue(description.contains("RoundRobin"))
    }
}

// MARK: - DICOMStorageClientConfiguration Tests

final class DICOMStorageClientConfigurationTests: XCTestCase {
    
    func test_configuration_initialization() throws {
        let callingAE = try AETitle("MY_SCU")
        var pool = ServerPool()
        try pool.addServer(host: "test.com", aeTitle: "PACS")
        
        let config = DICOMStorageClientConfiguration(
            callingAETitle: callingAE,
            serverPool: pool,
            retryPolicy: .aggressive,
            useQueue: false
        )
        
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.serverPool.count, 1)
        XCTAssertEqual(config.retryPolicy.maxAttempts, 5) // Aggressive has 5 attempts
        XCTAssertFalse(config.useQueue)
        XCTAssertTrue(config.useCircuitBreaker)
    }
    
    func test_configuration_simpleInitialization() throws {
        let config = try DICOMStorageClientConfiguration(
            callingAETitle: "MY_SCU",
            host: "pacs.hospital.com",
            port: 11112,
            calledAETitle: "PACS"
        )
        
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.serverPool.count, 1)
        XCTAssertEqual(config.serverPool.allServers.first?.host, "pacs.hospital.com")
    }
    
    func test_configuration_invalidAETitleThrows() {
        XCTAssertThrowsError(try DICOMStorageClientConfiguration(
            callingAETitle: "THIS_IS_TOO_LONG_AE",
            host: "test.com",
            port: 104,
            calledAETitle: "TEST"
        ))
    }
    
    func test_configuration_defaultValues() throws {
        let callingAE = try AETitle("TEST")
        let pool = ServerPool()
        
        let config = DICOMStorageClientConfiguration(
            callingAETitle: callingAE,
            serverPool: pool
        )
        
        XCTAssertEqual(config.retryPolicy.maxAttempts, 3) // Default
        XCTAssertFalse(config.useQueue)
        XCTAssertNil(config.queueConfiguration)
        XCTAssertEqual(config.defaultPriority, .medium)
        XCTAssertTrue(config.useCircuitBreaker)
        XCTAssertEqual(config.circuitBreakerThreshold, 5)
        XCTAssertEqual(config.circuitBreakerResetTimeout, 30)
    }
    
    func test_configuration_circuitBreakerThresholdNormalization() throws {
        let callingAE = try AETitle("TEST")
        let pool = ServerPool()
        
        let config = DICOMStorageClientConfiguration(
            callingAETitle: callingAE,
            serverPool: pool,
            circuitBreakerThreshold: 0 // Should be normalized to 1
        )
        
        XCTAssertEqual(config.circuitBreakerThreshold, 1)
    }
    
    func test_configuration_description() throws {
        let callingAE = try AETitle("MY_SCU")
        var pool = ServerPool()
        try pool.addServer(host: "test.com", aeTitle: "PACS")
        
        let config = DICOMStorageClientConfiguration(
            callingAETitle: callingAE,
            serverPool: pool,
            useCircuitBreaker: true
        )
        
        let description = config.description
        XCTAssertTrue(description.contains("MY_SCU"))
        XCTAssertTrue(description.contains("servers=1"))
        XCTAssertTrue(description.contains("circuitBreaker=enabled"))
    }
}

// MARK: - StorageClientResult Tests

final class StorageClientResultTests: XCTestCase {
    
    func test_storageClientResult_initialization() throws {
        let server = try ServerEntry(host: "test.com", aeTitle: "PACS")
        let storeResult = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5",
            roundTripTime: 0.5,
            remoteAETitle: "PACS"
        )
        
        let result = StorageClientResult(
            storeResult: storeResult,
            server: server,
            retryAttempts: 2,
            totalTime: 5.5,
            usedFailover: true
        )
        
        XCTAssertTrue(result.storeResult.success)
        XCTAssertEqual(result.server.host, "test.com")
        XCTAssertEqual(result.retryAttempts, 2)
        XCTAssertEqual(result.totalTime, 5.5)
        XCTAssertTrue(result.usedFailover)
    }
    
    func test_storageClientResult_description() throws {
        let server = try ServerEntry(host: "test.com", aeTitle: "PACS")
        let storeResult = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5",
            roundTripTime: 0.5,
            remoteAETitle: "PACS"
        )
        
        let result = StorageClientResult(
            storeResult: storeResult,
            server: server,
            retryAttempts: 0,
            totalTime: 1.0,
            usedFailover: false
        )
        
        let description = result.description
        XCTAssertTrue(description.contains("SUCCESS"))
        XCTAssertTrue(description.contains("PACS"))
        XCTAssertTrue(description.contains("retries=0"))
    }
    
    func test_storageClientResult_failoverIndicator() throws {
        let server = try ServerEntry(host: "test.com", aeTitle: "PACS")
        let storeResult = StoreResult(
            success: true,
            status: .success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5",
            roundTripTime: 0.5,
            remoteAETitle: "PACS"
        )
        
        let resultWithFailover = StorageClientResult(
            storeResult: storeResult,
            server: server,
            retryAttempts: 1,
            totalTime: 2.0,
            usedFailover: true
        )
        
        XCTAssertTrue(resultWithFailover.description.contains("[FAILOVER]"))
    }
}

// MARK: - DICOMStorageClient Tests

final class DICOMStorageClientTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_storageClient_initialization() async throws {
        let config = try DICOMStorageClientConfiguration(
            callingAETitle: "MY_SCU",
            host: "test.com",
            port: 11112,
            calledAETitle: "PACS"
        )
        
        let client = DICOMStorageClient(configuration: config)
        
        let pool = await client.serverPool
        XCTAssertEqual(pool.count, 1)
    }
    
    // MARK: - Server Management Tests
    
    func test_storageClient_addServer() async throws {
        let config = try DICOMStorageClientConfiguration(
            callingAETitle: "MY_SCU",
            host: "test.com",
            port: 11112,
            calledAETitle: "PACS"
        )
        
        let client = DICOMStorageClient(configuration: config)
        let newServer = try ServerEntry(host: "backup.com", aeTitle: "BACKUP")
        
        await client.addServer(newServer)
        
        let pool = await client.serverPool
        XCTAssertEqual(pool.count, 2)
    }
    
    func test_storageClient_removeServer() async throws {
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        var pool = ServerPool()
        pool.addServer(server)
        
        let config = DICOMStorageClientConfiguration(
            callingAETitle: try AETitle("MY_SCU"),
            serverPool: pool
        )
        
        let client = DICOMStorageClient(configuration: config)
        
        let removed = await client.removeServer(id: server.id)
        
        XCTAssertNotNil(removed)
        let currentPool = await client.serverPool
        XCTAssertEqual(currentPool.count, 0)
    }
    
    func test_storageClient_setServerEnabled() async throws {
        let server = try ServerEntry(host: "test.com", aeTitle: "TEST")
        var pool = ServerPool()
        pool.addServer(server)
        
        let config = DICOMStorageClientConfiguration(
            callingAETitle: try AETitle("MY_SCU"),
            serverPool: pool
        )
        
        let client = DICOMStorageClient(configuration: config)
        
        await client.setServerEnabled(id: server.id, enabled: false)
        
        let currentPool = await client.serverPool
        XCTAssertEqual(currentPool.enabledCount, 0)
    }
    
    // MARK: - Lifecycle Tests
    
    func test_storageClient_startStop() async throws {
        let config = try DICOMStorageClientConfiguration(
            callingAETitle: "MY_SCU",
            host: "test.com",
            port: 11112,
            calledAETitle: "PACS"
        )
        
        let client = DICOMStorageClient(configuration: config)
        
        // Should not throw when starting/stopping without queue
        try await client.start()
        await client.stop()
    }
}
#endif
