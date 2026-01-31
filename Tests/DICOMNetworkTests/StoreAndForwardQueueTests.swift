import XCTest
@testable import DICOMNetwork

// MARK: - Queue Item Status Tests

final class QueueItemStatusTests: XCTestCase {
    
    func test_status_allCases() {
        XCTAssertEqual(QueueItemStatus.allCases.count, 5)
        XCTAssertTrue(QueueItemStatus.allCases.contains(.pending))
        XCTAssertTrue(QueueItemStatus.allCases.contains(.sending))
        XCTAssertTrue(QueueItemStatus.allCases.contains(.completed))
        XCTAssertTrue(QueueItemStatus.allCases.contains(.failed))
        XCTAssertTrue(QueueItemStatus.allCases.contains(.cancelled))
    }
    
    func test_status_rawValues() {
        XCTAssertEqual(QueueItemStatus.pending.rawValue, "pending")
        XCTAssertEqual(QueueItemStatus.sending.rawValue, "sending")
        XCTAssertEqual(QueueItemStatus.completed.rawValue, "completed")
        XCTAssertEqual(QueueItemStatus.failed.rawValue, "failed")
        XCTAssertEqual(QueueItemStatus.cancelled.rawValue, "cancelled")
    }
    
    func test_status_description() {
        XCTAssertEqual(QueueItemStatus.pending.description, "Pending")
        XCTAssertEqual(QueueItemStatus.sending.description, "Sending")
        XCTAssertEqual(QueueItemStatus.completed.description, "Completed")
        XCTAssertEqual(QueueItemStatus.failed.description, "Failed")
        XCTAssertEqual(QueueItemStatus.cancelled.description, "Cancelled")
    }
    
    func test_status_codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for status in QueueItemStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(QueueItemStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - Queued Store Item Tests

final class QueuedStoreItemTests: XCTestCase {
    
    func test_item_initialization() {
        let item = QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            priority: .high,
            fileSize: 1024
        )
        
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(item.sopInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(item.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertEqual(item.host, "pacs.hospital.com")
        XCTAssertEqual(item.port, 11112)
        XCTAssertEqual(item.callingAETitle, "TEST_SCU")
        XCTAssertEqual(item.calledAETitle, "PACS")
        XCTAssertEqual(item.priority, .high)
        XCTAssertEqual(item.fileSize, 1024)
        XCTAssertEqual(item.status, .pending)
        XCTAssertEqual(item.attemptCount, 0)
        XCTAssertNil(item.lastAttemptAt)
        XCTAssertNil(item.lastError)
        XCTAssertNil(item.completedAt)
    }
    
    func test_item_defaultPriority() {
        let item = QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            fileSize: 1024
        )
        
        XCTAssertEqual(item.priority, .medium)
    }
    
    func test_item_codable() throws {
        let item = QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            priority: .high,
            fileSize: 2048
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(QueuedStoreItem.self, from: data)
        
        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.sopClassUID, item.sopClassUID)
        XCTAssertEqual(decoded.sopInstanceUID, item.sopInstanceUID)
        XCTAssertEqual(decoded.transferSyntaxUID, item.transferSyntaxUID)
        XCTAssertEqual(decoded.host, item.host)
        XCTAssertEqual(decoded.port, item.port)
        XCTAssertEqual(decoded.callingAETitle, item.callingAETitle)
        XCTAssertEqual(decoded.calledAETitle, item.calledAETitle)
        XCTAssertEqual(decoded.priority, item.priority)
        XCTAssertEqual(decoded.fileSize, item.fileSize)
        XCTAssertEqual(decoded.status, item.status)
    }
    
    func test_item_hashableEquality() {
        let item1 = QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            fileSize: 1024
        )
        
        // Same ID should be equal
        XCTAssertEqual(item1, item1)
        
        // Different items should not be equal
        let item2 = QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            fileSize: 1024
        )
        
        XCTAssertNotEqual(item1, item2)
    }
    
    func test_item_description() {
        let item = QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            fileSize: 1024
        )
        
        let desc = item.description
        XCTAssertTrue(desc.contains("QueuedStoreItem"))
        XCTAssertTrue(desc.contains("Pending")) // Capitalized from rawValue.capitalized
        XCTAssertTrue(desc.contains("PACS"))
    }
}

// MARK: - Queue Status Tests

final class QueueStatusTests: XCTestCase {
    
    func test_status_allCases() {
        XCTAssertEqual(QueueStatus.allCases.count, 4)
        XCTAssertTrue(QueueStatus.allCases.contains(.running))
        XCTAssertTrue(QueueStatus.allCases.contains(.paused))
        XCTAssertTrue(QueueStatus.allCases.contains(.stopped))
        XCTAssertTrue(QueueStatus.allCases.contains(.draining))
    }
    
    func test_status_description() {
        XCTAssertEqual(QueueStatus.running.description, "Running")
        XCTAssertEqual(QueueStatus.paused.description, "Paused")
        XCTAssertEqual(QueueStatus.stopped.description, "Stopped")
        XCTAssertEqual(QueueStatus.draining.description, "Draining")
    }
}

// MARK: - Queue Statistics Tests

final class QueueStatisticsTests: XCTestCase {
    
    func test_statistics_totalCount() {
        let stats = QueueStatistics(
            status: .running,
            pendingCount: 5,
            sendingCount: 2,
            completedCount: 10,
            failedCount: 1,
            cancelledCount: 2,
            pendingBytes: 1024000,
            totalProcessed: 13,
            averageDeliveryTime: 2.5,
            createdAt: Date()
        )
        
        XCTAssertEqual(stats.totalCount, 20) // 5 + 2 + 10 + 1 + 2
    }
    
    func test_statistics_hasPendingWork() {
        let statsWithPending = QueueStatistics(
            status: .running,
            pendingCount: 5,
            sendingCount: 0,
            completedCount: 10,
            failedCount: 0,
            cancelledCount: 0,
            pendingBytes: 1024,
            totalProcessed: 10,
            averageDeliveryTime: nil,
            createdAt: Date()
        )
        
        XCTAssertTrue(statsWithPending.hasPendingWork)
        
        let statsWithSending = QueueStatistics(
            status: .running,
            pendingCount: 0,
            sendingCount: 2,
            completedCount: 10,
            failedCount: 0,
            cancelledCount: 0,
            pendingBytes: 0,
            totalProcessed: 10,
            averageDeliveryTime: nil,
            createdAt: Date()
        )
        
        XCTAssertTrue(statsWithSending.hasPendingWork)
        
        let statsEmpty = QueueStatistics(
            status: .running,
            pendingCount: 0,
            sendingCount: 0,
            completedCount: 10,
            failedCount: 0,
            cancelledCount: 0,
            pendingBytes: 0,
            totalProcessed: 10,
            averageDeliveryTime: nil,
            createdAt: Date()
        )
        
        XCTAssertFalse(statsEmpty.hasPendingWork)
    }
    
    func test_statistics_description() {
        let stats = QueueStatistics(
            status: .running,
            pendingCount: 5,
            sendingCount: 2,
            completedCount: 10,
            failedCount: 1,
            cancelledCount: 0,
            pendingBytes: 1024000,
            totalProcessed: 11,
            averageDeliveryTime: 2.5,
            createdAt: Date()
        )
        
        let desc = stats.description
        XCTAssertTrue(desc.contains("QueueStats"))
        XCTAssertTrue(desc.contains("Running")) // Capitalized from QueueStatus.description
        XCTAssertTrue(desc.contains("pending=5"))
    }
}

// MARK: - Store and Forward Configuration Tests

final class StoreAndForwardConfigurationTests: XCTestCase {
    
    func test_configuration_defaultValues() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_queue")
        let config = StoreAndForwardConfiguration(storageDirectory: tempDir)
        
        XCTAssertEqual(config.storageDirectory, tempDir)
        XCTAssertEqual(config.maxRetryAttempts, 10)
        XCTAssertEqual(config.maxConcurrentTransfers, 1)
        XCTAssertTrue(config.autoRemoveCompleted)
        XCTAssertEqual(config.completedRetentionDuration, 3600)
        XCTAssertTrue(config.autoRetryOnConnectivityRestored)
        XCTAssertEqual(config.connectivityRestoredDelay, 5.0)
        XCTAssertTrue(config.priorityOrdering)
        XCTAssertEqual(config.maxQueueSizeBytes, 0)
        XCTAssertEqual(config.maxQueueItems, 0)
        XCTAssertEqual(config.connectionTimeout, 60)
    }
    
    func test_configuration_customValues() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_queue")
        let config = StoreAndForwardConfiguration(
            storageDirectory: tempDir,
            maxRetryAttempts: 5,
            retryPolicy: .conservative,
            maxConcurrentTransfers: 3,
            autoRemoveCompleted: false,
            completedRetentionDuration: 7200,
            autoRetryOnConnectivityRestored: false,
            connectivityRestoredDelay: 10.0,
            priorityOrdering: false,
            maxQueueSizeBytes: 1073741824, // 1 GB
            maxQueueItems: 1000,
            connectionTimeout: 120
        )
        
        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.maxConcurrentTransfers, 3)
        XCTAssertFalse(config.autoRemoveCompleted)
        XCTAssertEqual(config.completedRetentionDuration, 7200)
        XCTAssertFalse(config.autoRetryOnConnectivityRestored)
        XCTAssertEqual(config.connectivityRestoredDelay, 10.0)
        XCTAssertFalse(config.priorityOrdering)
        XCTAssertEqual(config.maxQueueSizeBytes, 1073741824)
        XCTAssertEqual(config.maxQueueItems, 1000)
        XCTAssertEqual(config.connectionTimeout, 120)
    }
    
    func test_configuration_negativeValuesAreNormalized() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_queue")
        let config = StoreAndForwardConfiguration(
            storageDirectory: tempDir,
            maxRetryAttempts: -5,
            maxConcurrentTransfers: -3,
            completedRetentionDuration: -100,
            connectivityRestoredDelay: -10.0,
            maxQueueSizeBytes: -1000,
            maxQueueItems: -100,
            connectionTimeout: -60
        )
        
        XCTAssertEqual(config.maxRetryAttempts, 1) // min 1
        XCTAssertEqual(config.maxConcurrentTransfers, 1) // min 1
        XCTAssertEqual(config.completedRetentionDuration, 0) // min 0
        XCTAssertEqual(config.connectivityRestoredDelay, 0) // min 0
        XCTAssertEqual(config.maxQueueSizeBytes, 0) // min 0
        XCTAssertEqual(config.maxQueueItems, 0) // min 0
        XCTAssertEqual(config.connectionTimeout, 1) // min 1
    }
    
    func test_configuration_default() {
        let config = StoreAndForwardConfiguration.default
        
        XCTAssertTrue(config.storageDirectory.path.contains("StoreAndForward"))
    }
}

// MARK: - Store and Forward Error Tests

final class StoreAndForwardErrorTests: XCTestCase {
    
    func test_error_descriptions() {
        let errorNotRunning = StoreAndForwardError.queueNotRunning
        XCTAssertTrue(errorNotRunning.description.contains("not running"))
        
        let errorFull = StoreAndForwardError.queueFull(reason: "max items reached")
        XCTAssertTrue(errorFull.description.contains("full"))
        XCTAssertTrue(errorFull.description.contains("max items reached"))
        
        let id = UUID()
        let errorNotFound = StoreAndForwardError.itemNotFound(id: id)
        XCTAssertTrue(errorNotFound.description.contains("not found"))
        XCTAssertTrue(errorNotFound.description.contains(id.uuidString))
        
        let errorStorage = StoreAndForwardError.storageError(reason: "disk full")
        XCTAssertTrue(errorStorage.description.contains("Storage error"))
        XCTAssertTrue(errorStorage.description.contains("disk full"))
        
        let errorConfig = StoreAndForwardError.invalidConfiguration(reason: "bad path")
        XCTAssertTrue(errorConfig.description.contains("Invalid configuration"))
        XCTAssertTrue(errorConfig.description.contains("bad path"))
        
        let errorDraining = StoreAndForwardError.queueDraining
        XCTAssertTrue(errorDraining.description.contains("draining"))
        
        let errorProcessed = StoreAndForwardError.itemAlreadyProcessed(id: id)
        XCTAssertTrue(errorProcessed.description.contains("already been processed"))
    }
    
    func test_error_localizedDescription() {
        let error = StoreAndForwardError.queueNotRunning
        XCTAssertEqual(error.localizedDescription, error.description)
    }
}

// MARK: - Queue Event Tests

final class StoreAndForwardEventTests: XCTestCase {
    
    func test_event_itemQueued() {
        let item = createTestItem()
        let event = StoreAndForwardEvent.itemQueued(item)
        
        if case .itemQueued(let eventItem) = event {
            XCTAssertEqual(eventItem.id, item.id)
        } else {
            XCTFail("Expected itemQueued event")
        }
    }
    
    func test_event_statusChanged() {
        let event = StoreAndForwardEvent.statusChanged(.running)
        
        if case .statusChanged(let status) = event {
            XCTAssertEqual(status, .running)
        } else {
            XCTFail("Expected statusChanged event")
        }
    }
    
    func test_event_queueCleared() {
        let event = StoreAndForwardEvent.queueCleared(itemCount: 5)
        
        if case .queueCleared(let count) = event {
            XCTAssertEqual(count, 5)
        } else {
            XCTFail("Expected queueCleared event")
        }
    }
    
    func test_event_connectivityRestored() {
        let event = StoreAndForwardEvent.connectivityRestored
        
        if case .connectivityRestored = event {
            // Success
        } else {
            XCTFail("Expected connectivityRestored event")
        }
    }
    
    func test_event_connectivityLost() {
        let event = StoreAndForwardEvent.connectivityLost
        
        if case .connectivityLost = event {
            // Success
        } else {
            XCTFail("Expected connectivityLost event")
        }
    }
    
    // Helper
    private func createTestItem() -> QueuedStoreItem {
        QueuedStoreItem(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: "TEST_SCU",
            calledAETitle: "PACS",
            fileSize: 1024
        )
    }
}

#if canImport(Network)

// MARK: - Store and Forward Queue Tests

final class StoreAndForwardQueueTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMKitTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }
    
    func test_queue_initialization() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let status = await queue.status
        XCTAssertEqual(status, .stopped)
        
        let stats = await queue.statistics
        XCTAssertEqual(stats.pendingCount, 0)
        XCTAssertEqual(stats.completedCount, 0)
        XCTAssertEqual(stats.failedCount, 0)
    }
    
    func test_queue_startStop() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        try await queue.start()
        var status = await queue.status
        XCTAssertEqual(status, .running)
        
        await queue.stop()
        status = await queue.status
        XCTAssertEqual(status, .stopped)
    }
    
    func test_queue_pauseResume() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        try await queue.start()
        
        await queue.pause()
        var status = await queue.status
        XCTAssertEqual(status, .paused)
        
        await queue.resume()
        status = await queue.status
        XCTAssertEqual(status, .running)
        
        await queue.stop()
    }
    
    func test_queue_drain() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        try await queue.start()
        
        await queue.drain()
        let status = await queue.status
        XCTAssertEqual(status, .draining)
        
        await queue.stop()
    }
    
    func test_queue_enqueueWithDataSet() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        // Enqueue works even when stopped
        let testData = Data(repeating: 0, count: 1024)
        
        let item = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS",
            priority: .high
        )
        
        XCTAssertEqual(item.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(item.sopInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(item.host, "pacs.hospital.com")
        XCTAssertEqual(item.port, 11112)
        XCTAssertEqual(item.priority, .high)
        XCTAssertEqual(item.status, .pending)
        
        let stats = await queue.statistics
        XCTAssertEqual(stats.pendingCount, 1)
        XCTAssertEqual(stats.pendingBytes, 1024)
    }
    
    func test_queue_enqueueDrainingThrows() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        try await queue.start()
        await queue.drain()
        
        let testData = Data(repeating: 0, count: 1024)
        
        do {
            _ = try await queue.enqueue(
                dataSetData: testData,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9",
                to: "pacs.hospital.com",
                port: 11112,
                callingAE: "TEST_SCU",
                calledAE: "PACS"
            )
            XCTFail("Should throw queueDraining error")
        } catch let error as StoreAndForwardError {
            if case .queueDraining = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        await queue.stop()
    }
    
    func test_queue_maxItemsLimit() async throws {
        let config = StoreAndForwardConfiguration(
            storageDirectory: tempDirectory,
            maxQueueItems: 2
        )
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let testData = Data(repeating: 0, count: 1024)
        
        // First two should succeed
        _ = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.1",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        _ = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.2",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        // Third should fail
        do {
            _ = try await queue.enqueue(
                dataSetData: testData,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.3",
                to: "pacs.hospital.com",
                port: 11112,
                callingAE: "TEST_SCU",
                calledAE: "PACS"
            )
            XCTFail("Should throw queueFull error")
        } catch let error as StoreAndForwardError {
            if case .queueFull = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func test_queue_maxSizeLimit() async throws {
        let config = StoreAndForwardConfiguration(
            storageDirectory: tempDirectory,
            maxQueueSizeBytes: 2000 // 2KB limit
        )
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let testData = Data(repeating: 0, count: 1024) // 1KB
        
        // First should succeed
        _ = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.1",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        // Second should fail (would exceed 2KB)
        do {
            _ = try await queue.enqueue(
                dataSetData: testData,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.2",
                to: "pacs.hospital.com",
                port: 11112,
                callingAE: "TEST_SCU",
                calledAE: "PACS"
            )
            XCTFail("Should throw queueFull error")
        } catch let error as StoreAndForwardError {
            if case .queueFull = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func test_queue_cancelItem() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let testData = Data(repeating: 0, count: 1024)
        
        let item = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        try await queue.cancel(itemId: item.id)
        
        let cancelledItem = await queue.item(withId: item.id)
        XCTAssertNotNil(cancelledItem)
        XCTAssertEqual(cancelledItem?.status, .cancelled)
        
        let stats = await queue.statistics
        XCTAssertEqual(stats.cancelledCount, 1)
        XCTAssertEqual(stats.pendingCount, 0)
    }
    
    func test_queue_cancelNotFoundThrows() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let randomId = UUID()
        
        do {
            try await queue.cancel(itemId: randomId)
            XCTFail("Should throw itemNotFound error")
        } catch let error as StoreAndForwardError {
            if case .itemNotFound(let id) = error {
                XCTAssertEqual(id, randomId)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func test_queue_removeItem() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let testData = Data(repeating: 0, count: 1024)
        
        let item = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        try await queue.remove(itemId: item.id)
        
        let removedItem = await queue.item(withId: item.id)
        XCTAssertNil(removedItem)
        
        let stats = await queue.statistics
        XCTAssertEqual(stats.totalCount, 0)
    }
    
    func test_queue_clear() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let testData = Data(repeating: 0, count: 1024)
        
        // Add a few items
        for i in 1...5 {
            _ = try await queue.enqueue(
                dataSetData: testData,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.\(i)",
                to: "pacs.hospital.com",
                port: 11112,
                callingAE: "TEST_SCU",
                calledAE: "PACS"
            )
        }
        
        var stats = await queue.statistics
        XCTAssertEqual(stats.pendingCount, 5)
        
        let clearedCount = await queue.clear()
        XCTAssertEqual(clearedCount, 5)
        
        stats = await queue.statistics
        XCTAssertEqual(stats.totalCount, 0)
    }
    
    func test_queue_itemsFiltering() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        let testData = Data(repeating: 0, count: 1024)
        
        let item1 = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.1",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        _ = try await queue.enqueue(
            dataSetData: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.2",
            to: "pacs.hospital.com",
            port: 11112,
            callingAE: "TEST_SCU",
            calledAE: "PACS"
        )
        
        // Cancel one
        try await queue.cancel(itemId: item1.id)
        
        let pendingItems = await queue.pendingItems
        XCTAssertEqual(pendingItems.count, 1)
        
        let allItems = await queue.allItems
        XCTAssertEqual(allItems.count, 2)
        
        let cancelledItems = await queue.items(withStatus: .cancelled)
        XCTAssertEqual(cancelledItems.count, 1)
    }
    
    func test_queue_persistence() async throws {
        let testData = Data(repeating: 0, count: 1024)
        var itemId: UUID!
        
        // Create queue and add item
        do {
            let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
            let queue = try await StoreAndForwardQueue(configuration: config)
            
            let item = try await queue.enqueue(
                dataSetData: testData,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7.8.9",
                to: "pacs.hospital.com",
                port: 11112,
                callingAE: "TEST_SCU",
                calledAE: "PACS"
            )
            
            itemId = item.id
            await queue.stop()
        }
        
        // Create new queue instance - should load persisted data
        do {
            let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
            let queue = try await StoreAndForwardQueue(configuration: config)
            
            let loadedItem = await queue.item(withId: itemId)
            XCTAssertNotNil(loadedItem)
            XCTAssertEqual(loadedItem?.sopInstanceUID, "1.2.3.4.5.6.7.8.9")
            XCTAssertEqual(loadedItem?.status, .pending)
        }
    }
    
    func test_queue_connectivityNotification() async throws {
        let config = StoreAndForwardConfiguration(storageDirectory: tempDirectory)
        let queue = try await StoreAndForwardQueue(configuration: config)
        
        // Notify lost
        await queue.notifyConnectivityLost()
        
        // Notify restored
        await queue.notifyConnectivityRestored()
        
        // Multiple calls should be idempotent
        await queue.notifyConnectivityRestored()
    }
}

#endif
