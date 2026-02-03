import XCTest
@testable import DICOMNetwork

// MARK: - Transfer Priority Tests

final class TransferPriorityTests: XCTestCase {
    
    func test_comparison_statIsHighest() {
        XCTAssertTrue(TransferPriority.stat < TransferPriority.high)
        XCTAssertTrue(TransferPriority.stat < TransferPriority.normal)
        XCTAssertTrue(TransferPriority.stat < TransferPriority.low)
        XCTAssertTrue(TransferPriority.stat < TransferPriority.background)
    }
    
    func test_comparison_ordering() {
        XCTAssertTrue(TransferPriority.high < TransferPriority.normal)
        XCTAssertTrue(TransferPriority.normal < TransferPriority.low)
        XCTAssertTrue(TransferPriority.low < TransferPriority.background)
    }
    
    func test_dimseConversion_fromDIMSE() {
        XCTAssertEqual(TransferPriority(fromDIMSE: .high), .high)
        XCTAssertEqual(TransferPriority(fromDIMSE: .medium), .normal)
        XCTAssertEqual(TransferPriority(fromDIMSE: .low), .low)
    }
    
    func test_dimseConversion_toDIMSE() {
        XCTAssertEqual(TransferPriority.stat.dimseValue, .high)
        XCTAssertEqual(TransferPriority.high.dimseValue, .high)
        XCTAssertEqual(TransferPriority.normal.dimseValue, .medium)
        XCTAssertEqual(TransferPriority.low.dimseValue, .low)
        XCTAssertEqual(TransferPriority.background.dimseValue, .low)
    }
    
    func test_description_returnsReadableString() {
        XCTAssertEqual(TransferPriority.stat.description, "STAT")
        XCTAssertEqual(TransferPriority.high.description, "High")
        XCTAssertEqual(TransferPriority.normal.description, "Normal")
        XCTAssertEqual(TransferPriority.low.description, "Low")
        XCTAssertEqual(TransferPriority.background.description, "Background")
    }
    
    func test_allCases_containsAllPriorities() {
        XCTAssertEqual(TransferPriority.allCases.count, 5)
        XCTAssertTrue(TransferPriority.allCases.contains(.stat))
        XCTAssertTrue(TransferPriority.allCases.contains(.background))
    }
    
    func test_codable_roundTrip() throws {
        let original = TransferPriority.high
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransferPriority.self, from: encoded)
        
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - Prioritized Transfer Item Tests

final class PrioritizedTransferItemTests: XCTestCase {
    
    func test_init_setsAllProperties() {
        let deadline = Date().addingTimeInterval(60)
        let item = PrioritizedTransferItem(
            data: "test data",
            priority: .high,
            deadline: deadline,
            tag: "urgent",
            droppable: true
        )
        
        XCTAssertEqual(item.data, "test data")
        XCTAssertEqual(item.priority, .high)
        XCTAssertEqual(item.deadline, deadline)
        XCTAssertEqual(item.tag, "urgent")
        XCTAssertTrue(item.droppable)
        XCTAssertNotNil(item.id)
        XCTAssertNotNil(item.queuedAt)
    }
    
    func test_init_usesDefaults() {
        let item = PrioritizedTransferItem(data: "test")
        
        XCTAssertEqual(item.priority, .normal)
        XCTAssertNil(item.deadline)
        XCTAssertNil(item.tag)
        XCTAssertFalse(item.droppable)
    }
    
    func test_isExpired_withNoDeadline_returnsFalse() {
        let item = PrioritizedTransferItem(data: "test")
        
        XCTAssertFalse(item.isExpired)
    }
    
    func test_isExpired_withFutureDeadline_returnsFalse() {
        let item = PrioritizedTransferItem(
            data: "test",
            deadline: Date().addingTimeInterval(60)
        )
        
        XCTAssertFalse(item.isExpired)
    }
    
    func test_isExpired_withPastDeadline_returnsTrue() {
        let item = PrioritizedTransferItem(
            data: "test",
            deadline: Date().addingTimeInterval(-60)
        )
        
        XCTAssertTrue(item.isExpired)
    }
    
    func test_timeRemaining_withNoDeadline_returnsNil() {
        let item = PrioritizedTransferItem(data: "test")
        
        XCTAssertNil(item.timeRemaining)
    }
    
    func test_timeRemaining_withDeadline_returnsValue() {
        let item = PrioritizedTransferItem(
            data: "test",
            deadline: Date().addingTimeInterval(60)
        )
        
        let remaining = item.timeRemaining
        XCTAssertNotNil(remaining)
        XCTAssertGreaterThan(remaining!, 50)
        XCTAssertLessThan(remaining!, 65)
    }
    
    func test_equatable_comparesById() {
        let item1 = PrioritizedTransferItem(data: "test1")
        let item2 = PrioritizedTransferItem(data: "test1")
        
        XCTAssertNotEqual(item1, item2) // Different IDs
    }
    
    func test_hashable_usesId() {
        let item = PrioritizedTransferItem(data: "test")
        var set = Set<PrioritizedTransferItem<String>>()
        set.insert(item)
        
        XCTAssertTrue(set.contains(item))
    }
}

// MARK: - Transfer Priority Queue Configuration Tests

final class TransferPriorityQueueConfigurationTests: XCTestCase {
    
    func test_init_setsAllProperties() {
        let config = TransferPriorityQueueConfiguration(
            maxSize: 100,
            allowDroppingOnFull: false,
            maxAge: 3600,
            enableAging: true,
            agingInterval: 600
        )
        
        XCTAssertEqual(config.maxSize, 100)
        XCTAssertFalse(config.allowDroppingOnFull)
        XCTAssertEqual(config.maxAge, 3600)
        XCTAssertTrue(config.enableAging)
        XCTAssertEqual(config.agingInterval, 600)
    }
    
    func test_init_usesDefaults() {
        let config = TransferPriorityQueueConfiguration()
        
        XCTAssertEqual(config.maxSize, 0) // unlimited
        XCTAssertTrue(config.allowDroppingOnFull)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.enableAging)
        XCTAssertEqual(config.agingInterval, 300)
    }
    
    func test_init_clampsNegativeSize() {
        let config = TransferPriorityQueueConfiguration(maxSize: -10)
        
        XCTAssertEqual(config.maxSize, 0)
    }
    
    func test_init_clampsAgingInterval() {
        let config = TransferPriorityQueueConfiguration(agingInterval: 0)
        
        XCTAssertEqual(config.agingInterval, 1)
    }
    
    func test_default_hasExpectedValues() {
        let config = TransferPriorityQueueConfiguration.default
        
        XCTAssertEqual(config.maxSize, 0)
        XCTAssertTrue(config.allowDroppingOnFull)
    }
    
    func test_limited_setsSize() {
        let config = TransferPriorityQueueConfiguration.limited(size: 500)
        
        XCTAssertEqual(config.maxSize, 500)
        XCTAssertTrue(config.allowDroppingOnFull)
    }
}

// MARK: - Transfer Priority Queue Statistics Tests

final class TransferPriorityQueueStatisticsTests: XCTestCase {
    
    func test_statistics_containsAllFields() {
        let stats = TransferPriorityQueueStatistics(
            itemsByPriority: [.stat: 1, .normal: 5],
            totalItems: 6,
            totalProcessed: 10,
            totalDropped: 2,
            totalExpired: 1,
            averageWaitTime: 1.5,
            oldestItemAge: 10.0
        )
        
        XCTAssertEqual(stats.totalItems, 6)
        XCTAssertEqual(stats.totalProcessed, 10)
        XCTAssertEqual(stats.totalDropped, 2)
        XCTAssertEqual(stats.totalExpired, 1)
        XCTAssertEqual(stats.averageWaitTime, 1.5)
        XCTAssertEqual(stats.oldestItemAge, 10.0)
        XCTAssertEqual(stats.itemsByPriority[.stat], 1)
        XCTAssertEqual(stats.itemsByPriority[.normal], 5)
    }
}

// MARK: - Transfer Priority Queue Event Tests

final class TransferPriorityQueueEventTests: XCTestCase {
    
    func test_itemEnqueued_containsItem() {
        let item = PrioritizedTransferItem(data: "test")
        let event = TransferPriorityQueueEvent.itemEnqueued(item)
        
        if case .itemEnqueued(let eventItem) = event {
            XCTAssertEqual(eventItem.id, item.id)
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    func test_itemDequeued_containsItem() {
        let item = PrioritizedTransferItem(data: "test")
        let event = TransferPriorityQueueEvent.itemDequeued(item)
        
        if case .itemDequeued(let eventItem) = event {
            XCTAssertEqual(eventItem.id, item.id)
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    func test_queueFull_containsSize() {
        let event = TransferPriorityQueueEvent<String>.queueFull(size: 100)
        
        if case .queueFull(let size) = event {
            XCTAssertEqual(size, 100)
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    func test_queueCleared_containsCount() {
        let event = TransferPriorityQueueEvent<String>.queueCleared(itemCount: 50)
        
        if case .queueCleared(let count) = event {
            XCTAssertEqual(count, 50)
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    func test_priorityBoosted_containsDetails() {
        let id = UUID()
        let event = TransferPriorityQueueEvent<String>.priorityBoosted(
            id: id,
            from: .normal,
            to: .high
        )
        
        if case .priorityBoosted(let eventId, let from, let to) = event {
            XCTAssertEqual(eventId, id)
            XCTAssertEqual(from, .normal)
            XCTAssertEqual(to, .high)
        } else {
            XCTFail("Wrong event type")
        }
    }
}

// MARK: - Transfer Priority Queue Tests

final class TransferPriorityQueueTests: XCTestCase {
    
    func test_init_createsEmptyQueue() async {
        let queue = TransferPriorityQueue<String>()
        
        let count = await queue.totalCount
        let isEmpty = await queue.isEmpty
        
        XCTAssertEqual(count, 0)
        XCTAssertTrue(isEmpty)
    }
    
    func test_enqueue_addsItem() async throws {
        let queue = TransferPriorityQueue<String>()
        
        let item = try await queue.enqueue("test data")
        
        let count = await queue.totalCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(item.data, "test data")
    }
    
    func test_enqueue_withPriority_setsCorrectPriority() async throws {
        let queue = TransferPriorityQueue<String>()
        
        let item = try await queue.enqueue("test", priority: .stat)
        
        XCTAssertEqual(item.priority, .stat)
    }
    
    func test_enqueue_respectsMaxSize() async {
        let config = TransferPriorityQueueConfiguration(
            maxSize: 2,
            allowDroppingOnFull: false
        )
        let queue = TransferPriorityQueue<String>(configuration: config)
        
        do {
            try await queue.enqueue("item1")
            try await queue.enqueue("item2")
            try await queue.enqueue("item3")
            XCTFail("Should have thrown")
        } catch let error as TransferPriorityQueueError {
            if case .queueFull(let capacity, _) = error {
                XCTAssertEqual(capacity, 2)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func test_enqueue_dropsLowerPriority() async throws {
        let config = TransferPriorityQueueConfiguration(
            maxSize: 2,
            allowDroppingOnFull: true
        )
        let queue = TransferPriorityQueue<String>(configuration: config)
        
        try await queue.enqueue("low1", priority: .low, droppable: true)
        try await queue.enqueue("low2", priority: .low, droppable: true)
        
        // This should succeed by dropping a low priority item
        try await queue.enqueue("high", priority: .high)
        
        let count = await queue.totalCount
        XCTAssertEqual(count, 2)
    }
    
    func test_dequeue_returnsHighestPriority() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("low", priority: .low)
        try await queue.enqueue("high", priority: .high)
        try await queue.enqueue("normal", priority: .normal)
        
        let first = await queue.dequeue()
        let second = await queue.dequeue()
        let third = await queue.dequeue()
        
        XCTAssertEqual(first?.data, "high")
        XCTAssertEqual(second?.data, "normal")
        XCTAssertEqual(third?.data, "low")
    }
    
    func test_dequeue_fromEmpty_returnsNil() async {
        let queue = TransferPriorityQueue<String>()
        
        let item = await queue.dequeue()
        
        XCTAssertNil(item)
    }
    
    func test_dequeue_byId_returnsCorrectItem() async throws {
        let queue = TransferPriorityQueue<String>()
        
        let item1 = try await queue.enqueue("item1")
        _ = try await queue.enqueue("item2")
        
        let dequeued = await queue.dequeue(id: item1.id)
        
        XCTAssertEqual(dequeued?.id, item1.id)
        
        let count = await queue.totalCount
        XCTAssertEqual(count, 1)
    }
    
    func test_dequeue_byTag_returnsMatchingItems() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("tagged1", tag: "groupA")
        try await queue.enqueue("untagged")
        try await queue.enqueue("tagged2", tag: "groupA")
        
        let items = await queue.dequeue(tag: "groupA")
        
        XCTAssertEqual(items.count, 2)
        
        let remaining = await queue.totalCount
        XCTAssertEqual(remaining, 1)
    }
    
    func test_dequeue_byTag_withLimit_respectsLimit() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("item1", tag: "group")
        try await queue.enqueue("item2", tag: "group")
        try await queue.enqueue("item3", tag: "group")
        
        let items = await queue.dequeue(tag: "group", limit: 2)
        
        XCTAssertEqual(items.count, 2)
    }
    
    func test_peek_returnsHighestPriority() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("low", priority: .low)
        try await queue.enqueue("stat", priority: .stat)
        
        let peeked = await queue.peek()
        
        XCTAssertEqual(peeked?.data, "stat")
        
        // Should still be in queue
        let count = await queue.totalCount
        XCTAssertEqual(count, 2)
    }
    
    func test_peek_byId_returnsCorrectItem() async throws {
        let queue = TransferPriorityQueue<String>()
        
        let item = try await queue.enqueue("test")
        
        let peeked = await queue.peek(id: item.id)
        
        XCTAssertEqual(peeked?.id, item.id)
    }
    
    func test_count_forPriority_returnsCorrectCount() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("high1", priority: .high)
        try await queue.enqueue("high2", priority: .high)
        try await queue.enqueue("normal", priority: .normal)
        
        let highCount = await queue.count(for: .high)
        let normalCount = await queue.count(for: .normal)
        let lowCount = await queue.count(for: .low)
        
        XCTAssertEqual(highCount, 2)
        XCTAssertEqual(normalCount, 1)
        XCTAssertEqual(lowCount, 0)
    }
    
    func test_clear_removesAllItems() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("item1")
        try await queue.enqueue("item2")
        try await queue.enqueue("item3")
        
        let cleared = await queue.clear()
        
        XCTAssertEqual(cleared, 3)
        
        let count = await queue.totalCount
        XCTAssertEqual(count, 0)
    }
    
    func test_statistics_returnsCorrectValues() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("stat", priority: .stat)
        try await queue.enqueue("high", priority: .high)
        try await queue.enqueue("normal", priority: .normal)
        
        _ = await queue.dequeue()
        
        let stats = await queue.statistics()
        
        XCTAssertEqual(stats.totalItems, 2)
        XCTAssertEqual(stats.totalProcessed, 1)
        XCTAssertEqual(stats.itemsByPriority[.high], 1)
        XCTAssertEqual(stats.itemsByPriority[.normal], 1)
    }
    
    func test_fifo_withinSamePriority() async throws {
        let queue = TransferPriorityQueue<String>()
        
        try await queue.enqueue("first", priority: .normal)
        try await queue.enqueue("second", priority: .normal)
        try await queue.enqueue("third", priority: .normal)
        
        let first = await queue.dequeue()
        let second = await queue.dequeue()
        let third = await queue.dequeue()
        
        XCTAssertEqual(first?.data, "first")
        XCTAssertEqual(second?.data, "second")
        XCTAssertEqual(third?.data, "third")
    }
}

// MARK: - Transfer Priority Queue Error Tests

final class TransferPriorityQueueErrorTests: XCTestCase {
    
    func test_queueFull_description() {
        let error = TransferPriorityQueueError.queueFull(
            capacity: 100,
            requestedPriority: .high
        )
        
        let description = error.description
        
        XCTAssertTrue(description.contains("100"))
        XCTAssertTrue(description.contains("High"))
    }
    
    func test_itemNotFound_description() {
        let id = UUID()
        let error = TransferPriorityQueueError.itemNotFound(id: id)
        
        let description = error.description
        
        XCTAssertTrue(description.contains(id.uuidString))
    }
}
