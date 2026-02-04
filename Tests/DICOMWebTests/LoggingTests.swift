import XCTest
@testable import DICOMWeb

/// Tests for logging and metrics functionality
final class LoggingTests: XCTestCase {
    
    // MARK: - RequestLogEntry Tests
    
    func testRequestLogEntryCreation() {
        let url = URL(string: "https://example.com/studies")!
        let entry = RequestLogEntry(
            requestID: "req-123",
            url: url,
            method: "GET",
            headers: ["Accept": "application/json"],
            bodySize: 0
        )
        
        XCTAssertEqual(entry.requestID, "req-123")
        XCTAssertEqual(entry.url, url)
        XCTAssertEqual(entry.method, "GET")
        XCTAssertEqual(entry.headers["Accept"], "application/json")
        XCTAssertEqual(entry.bodySize, 0)
    }
    
    func testRequestLogEntryWithBody() {
        let url = URL(string: "https://example.com/studies")!
        let entry = RequestLogEntry(
            url: url,
            method: "POST",
            bodySize: 1024 * 1024
        )
        
        XCTAssertEqual(entry.method, "POST")
        XCTAssertEqual(entry.bodySize, 1024 * 1024)
    }
    
    // MARK: - ResponseLogEntry Tests
    
    func testResponseLogEntryCreation() {
        let url = URL(string: "https://example.com/studies")!
        let entry = ResponseLogEntry(
            requestID: "req-123",
            url: url,
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            bodySize: 5000,
            duration: 0.5
        )
        
        XCTAssertEqual(entry.requestID, "req-123")
        XCTAssertEqual(entry.url, url)
        XCTAssertEqual(entry.statusCode, 200)
        XCTAssertEqual(entry.headers["Content-Type"], "application/json")
        XCTAssertEqual(entry.bodySize, 5000)
        XCTAssertEqual(entry.duration, 0.5)
        XCTAssertFalse(entry.fromCache)
    }
    
    func testResponseLogEntryFromCache() {
        let url = URL(string: "https://example.com/studies")!
        let entry = ResponseLogEntry(
            requestID: "req-123",
            url: url,
            statusCode: 200,
            duration: 0.001,
            fromCache: true
        )
        
        XCTAssertTrue(entry.fromCache)
    }
    
    // MARK: - ErrorLogEntry Tests
    
    func testErrorLogEntryCreation() {
        let url = URL(string: "https://example.com/studies")!
        let entry = ErrorLogEntry(
            requestID: "req-123",
            url: url,
            errorDescription: "Connection failed",
            errorCode: -1001,
            duration: 5.0
        )
        
        XCTAssertEqual(entry.requestID, "req-123")
        XCTAssertEqual(entry.url, url)
        XCTAssertEqual(entry.errorDescription, "Connection failed")
        XCTAssertEqual(entry.errorCode, -1001)
        XCTAssertEqual(entry.duration, 5.0)
    }
    
    // MARK: - NullRequestLogger Tests
    
    func testNullLoggerDoesNothing() async {
        let logger = NullRequestLogger()
        let url = URL(string: "https://example.com")!
        
        // These should not throw or crash
        await logger.logRequest(RequestLogEntry(url: url, method: "GET"))
        await logger.logResponse(ResponseLogEntry(requestID: "1", url: url, statusCode: 200, duration: 0.1))
        await logger.logError(ErrorLogEntry(requestID: "1", url: url, errorDescription: "Test"))
    }
    
    // MARK: - ConsoleRequestLogger Tests
    
    func testConsoleLoggerCreation() {
        let logger = ConsoleRequestLogger(includeHeaders: true, includeTimestamps: true)
        XCTAssertNotNil(logger)
    }
    
    func testConsoleLoggerLogsRequests() async {
        let logger = ConsoleRequestLogger(includeHeaders: false, includeTimestamps: false)
        let url = URL(string: "https://example.com/studies")!
        
        // This should print to console (verify manually or capture stdout in a real test)
        await logger.logRequest(RequestLogEntry(url: url, method: "GET"))
    }
    
    // MARK: - CompositeRequestLogger Tests
    
    func testCompositeLogger() async {
        let null1 = NullRequestLogger()
        let null2 = NullRequestLogger()
        
        let composite = CompositeRequestLogger(loggers: [null1, null2])
        let url = URL(string: "https://example.com")!
        
        // Both loggers should be called (they do nothing, but shouldn't crash)
        await composite.logRequest(RequestLogEntry(url: url, method: "GET"))
        await composite.logResponse(ResponseLogEntry(requestID: "1", url: url, statusCode: 200, duration: 0.1))
        await composite.logError(ErrorLogEntry(requestID: "1", url: url, errorDescription: "Test"))
    }
    
    func testCompositeLoggerAddLogger() async {
        let composite = CompositeRequestLogger(loggers: [])
        let null = NullRequestLogger()
        
        await composite.addLogger(null)
        
        let url = URL(string: "https://example.com")!
        await composite.logRequest(RequestLogEntry(url: url, method: "GET"))
    }
    
    // MARK: - DICOMwebMetrics Tests
    
    func testMetricsSampleCreation() {
        let sample = DICOMwebMetrics.Sample(
            operation: .wadoRetrieve,
            duration: 0.5,
            bytesSent: 100,
            bytesReceived: 10000,
            success: true,
            statusCode: 200
        )
        
        XCTAssertEqual(sample.operation, .wadoRetrieve)
        XCTAssertEqual(sample.duration, 0.5)
        XCTAssertEqual(sample.bytesSent, 100)
        XCTAssertEqual(sample.bytesReceived, 10000)
        XCTAssertTrue(sample.success)
        XCTAssertEqual(sample.statusCode, 200)
    }
    
    func testMetricsRecording() async {
        let metrics = DICOMwebMetrics()
        
        await metrics.recordSuccess(
            operation: .wadoRetrieve,
            duration: 0.5,
            bytesReceived: 10000
        )
        
        let summary = await metrics.getSummary()
        XCTAssertEqual(summary.totalRequests, 1)
        XCTAssertEqual(summary.successfulRequests, 1)
        XCTAssertEqual(summary.failedRequests, 0)
    }
    
    func testMetricsFailureRecording() async {
        let metrics = DICOMwebMetrics()
        
        await metrics.recordFailure(
            operation: .stowStore,
            duration: 1.0,
            statusCode: 500
        )
        
        let summary = await metrics.getSummary()
        XCTAssertEqual(summary.totalRequests, 1)
        XCTAssertEqual(summary.successfulRequests, 0)
        XCTAssertEqual(summary.failedRequests, 1)
    }
    
    func testMetricsAggregation() async {
        let metrics = DICOMwebMetrics()
        
        // Record multiple samples
        for i in 0..<10 {
            await metrics.recordSuccess(
                operation: .qidoQuery,
                duration: 0.1 * Double(i + 1),
                bytesReceived: 1000 * (i + 1)
            )
        }
        
        let aggregated = await metrics.getMetrics(for: .qidoQuery)
        XCTAssertNotNil(aggregated)
        XCTAssertEqual(aggregated?.requestCount, 10)
        XCTAssertEqual(aggregated?.successCount, 10)
        XCTAssertEqual(aggregated?.errorCount, 0)
        XCTAssertEqual(aggregated!.minDuration, 0.1, accuracy: 0.01)
        XCTAssertEqual(aggregated!.maxDuration, 1.0, accuracy: 0.01)
    }
    
    func testMetricsSummary() async {
        let metrics = DICOMwebMetrics()
        
        await metrics.recordSuccess(operation: .wadoRetrieve, duration: 0.5)
        await metrics.recordSuccess(operation: .qidoQuery, duration: 0.2)
        await metrics.recordFailure(operation: .stowStore, duration: 1.0)
        
        let summary = await metrics.getSummary()
        XCTAssertEqual(summary.totalRequests, 3)
        XCTAssertEqual(summary.successfulRequests, 2)
        XCTAssertEqual(summary.failedRequests, 1)
        XCTAssertEqual(summary.successRate, 2.0/3.0, accuracy: 0.01)
        XCTAssertEqual(summary.errorRate, 1.0/3.0, accuracy: 0.01)
    }
    
    func testMetricsClear() async {
        let metrics = DICOMwebMetrics()
        
        await metrics.recordSuccess(operation: .wadoRetrieve, duration: 0.5)
        await metrics.clear()
        
        let summary = await metrics.getSummary()
        XCTAssertEqual(summary.totalRequests, 0)
    }
    
    func testMetricsPerOperation() async {
        let metrics = DICOMwebMetrics()
        
        await metrics.recordSuccess(operation: .wadoRetrieve, duration: 0.5)
        await metrics.recordSuccess(operation: .wadoRetrieve, duration: 0.6)
        await metrics.recordSuccess(operation: .qidoQuery, duration: 0.1)
        
        let allAggregated = await metrics.getAggregatedMetrics()
        XCTAssertEqual(allAggregated.count, 2)
        
        let wadoMetrics = await metrics.getMetrics(for: .wadoRetrieve)
        XCTAssertNotNil(wadoMetrics)
        XCTAssertEqual(wadoMetrics?.requestCount, 2)
        
        let qidoMetrics = await metrics.getMetrics(for: .qidoQuery)
        XCTAssertNotNil(qidoMetrics)
        XCTAssertEqual(qidoMetrics?.requestCount, 1)
    }
    
    // MARK: - MetricTimer Tests
    
    func testMetricTimer() async throws {
        let timer = MetricTimer(operation: .wadoRetrieve)
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let sample = timer.finish(success: true, bytesReceived: 1000, statusCode: 200)
        
        XCTAssertEqual(sample.operation, .wadoRetrieve)
        XCTAssertTrue(sample.success)
        XCTAssertEqual(sample.bytesReceived, 1000)
        XCTAssertEqual(sample.statusCode, 200)
        XCTAssertGreaterThan(sample.duration, 0)
    }
    
    func testMetricTimerElapsed() async throws {
        let timer = MetricTimer(operation: .qidoQuery)
        
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        XCTAssertGreaterThan(timer.elapsed, 0.01)
    }
    
    // MARK: - AggregatedMetrics Tests
    
    func testAggregatedMetricsSuccessRate() async {
        let metrics = DICOMwebMetrics()
        
        for _ in 0..<8 {
            await metrics.recordSuccess(operation: .wadoRetrieve, duration: 0.5)
        }
        for _ in 0..<2 {
            await metrics.recordFailure(operation: .wadoRetrieve, duration: 1.0)
        }
        
        let aggregated = await metrics.getMetrics(for: .wadoRetrieve)
        XCTAssertNotNil(aggregated)
        XCTAssertEqual(aggregated!.successRate, 0.8, accuracy: 0.01)
        XCTAssertEqual(aggregated!.errorRate, 0.2, accuracy: 0.01)
    }
}
