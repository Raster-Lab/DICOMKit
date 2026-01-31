import XCTest
@testable import DICOMNetwork

/// Tests for DICOMLogger and related types
final class DICOMLoggerTests: XCTestCase {
    
    // MARK: - Log Level Tests
    
    func testLogLevelOrdering() {
        XCTAssertTrue(DICOMLogLevel.debug < DICOMLogLevel.info)
        XCTAssertTrue(DICOMLogLevel.info < DICOMLogLevel.warning)
        XCTAssertTrue(DICOMLogLevel.warning < DICOMLogLevel.error)
    }
    
    func testLogLevelRawValues() {
        XCTAssertEqual(DICOMLogLevel.debug.rawValue, 0)
        XCTAssertEqual(DICOMLogLevel.info.rawValue, 1)
        XCTAssertEqual(DICOMLogLevel.warning.rawValue, 2)
        XCTAssertEqual(DICOMLogLevel.error.rawValue, 3)
    }
    
    func testLogLevelDescriptions() {
        XCTAssertEqual(DICOMLogLevel.debug.description, "DEBUG")
        XCTAssertEqual(DICOMLogLevel.info.description, "INFO")
        XCTAssertEqual(DICOMLogLevel.warning.description, "WARNING")
        XCTAssertEqual(DICOMLogLevel.error.description, "ERROR")
    }
    
    // MARK: - Log Category Tests
    
    func testLogCategoryRawValues() {
        XCTAssertEqual(DICOMLogCategory.connection.rawValue, "Connection")
        XCTAssertEqual(DICOMLogCategory.association.rawValue, "Association")
        XCTAssertEqual(DICOMLogCategory.pdu.rawValue, "PDU")
        XCTAssertEqual(DICOMLogCategory.dimse.rawValue, "DIMSE")
        XCTAssertEqual(DICOMLogCategory.query.rawValue, "Query")
        XCTAssertEqual(DICOMLogCategory.retrieve.rawValue, "Retrieve")
        XCTAssertEqual(DICOMLogCategory.verification.rawValue, "Verification")
        XCTAssertEqual(DICOMLogCategory.stateMachine.rawValue, "StateMachine")
        XCTAssertEqual(DICOMLogCategory.performance.rawValue, "Performance")
        XCTAssertEqual(DICOMLogCategory.storage.rawValue, "Storage")
        XCTAssertEqual(DICOMLogCategory.audit.rawValue, "Audit")
    }
    
    func testLogCategoryAllCases() {
        let allCategories = DICOMLogCategory.allCases
        XCTAssertEqual(allCategories.count, 11)
        XCTAssertTrue(allCategories.contains(.connection))
        XCTAssertTrue(allCategories.contains(.association))
        XCTAssertTrue(allCategories.contains(.pdu))
        XCTAssertTrue(allCategories.contains(.dimse))
        XCTAssertTrue(allCategories.contains(.query))
        XCTAssertTrue(allCategories.contains(.retrieve))
        XCTAssertTrue(allCategories.contains(.verification))
        XCTAssertTrue(allCategories.contains(.stateMachine))
        XCTAssertTrue(allCategories.contains(.performance))
        XCTAssertTrue(allCategories.contains(.storage))
        XCTAssertTrue(allCategories.contains(.audit))
    }
    
    // MARK: - Log Message Tests
    
    func testLogMessageCreation() {
        let message = DICOMLogMessage(
            level: .info,
            category: .connection,
            message: "Test message"
        )
        
        XCTAssertEqual(message.level, .info)
        XCTAssertEqual(message.category, .connection)
        XCTAssertEqual(message.message, "Test message")
        XCTAssertTrue(message.context.isEmpty)
        XCTAssertNotNil(message.timestamp)
    }
    
    func testLogMessageWithContext() {
        let context = ["host": "localhost", "port": "11112"]
        let message = DICOMLogMessage(
            level: .debug,
            category: .pdu,
            message: "PDU sent",
            context: context
        )
        
        XCTAssertEqual(message.context["host"], "localhost")
        XCTAssertEqual(message.context["port"], "11112")
        XCTAssertEqual(message.context.count, 2)
    }
    
    // MARK: - Console Log Handler Tests
    
    func testConsoleLogHandlerCreation() {
        let handler = ConsoleLogHandler()
        XCTAssertTrue(handler.includeTimestamp)
        
        let handlerNoTimestamp = ConsoleLogHandler(includeTimestamp: false)
        XCTAssertFalse(handlerNoTimestamp.includeTimestamp)
    }
    
    // MARK: - Mock Log Handler for Testing
    
    final class MockLogHandler: DICOMLogHandler, @unchecked Sendable {
        var messages: [DICOMLogMessage] = []
        
        func log(_ message: DICOMLogMessage) {
            messages.append(message)
        }
    }
    
    // MARK: - DICOMLogger Integration Tests
    
    func testLoggerConfiguration() async {
        let logger = DICOMLogger.shared
        
        // Initially logging should be disabled
        await logger.removeAllHandlers()
        let initialEnabled = await logger.isLoggingEnabled
        XCTAssertFalse(initialEnabled)
        
        // Add a handler
        let mockHandler = MockLogHandler()
        await logger.addHandler(mockHandler)
        
        let afterAddEnabled = await logger.isLoggingEnabled
        XCTAssertTrue(afterAddEnabled)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func testLoggerMinimumLevel() async {
        let logger = DICOMLogger.shared
        await logger.removeAllHandlers()
        
        let mockHandler = MockLogHandler()
        await logger.addHandler(mockHandler)
        await logger.setMinimumLevel(.warning)
        
        // Debug and info should be filtered
        await logger.debug(.connection, "Debug message")
        await logger.info(.connection, "Info message")
        
        // Warning and error should pass through
        await logger.warning(.connection, "Warning message")
        await logger.error(.connection, "Error message")
        
        // Give some time for the messages to be processed
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(mockHandler.messages.count, 2)
        XCTAssertEqual(mockHandler.messages[0].level, .warning)
        XCTAssertEqual(mockHandler.messages[1].level, .error)
        
        // Clean up
        await logger.removeAllHandlers()
        await logger.setMinimumLevel(.info) // Reset to default
    }
    
    func testLoggerCategoryFiltering() async {
        let logger = DICOMLogger.shared
        await logger.removeAllHandlers()
        
        let mockHandler = MockLogHandler()
        await logger.addHandler(mockHandler)
        await logger.setMinimumLevel(.debug)
        await logger.setEnabledCategories([.connection, .association])
        
        // These should be logged
        await logger.info(.connection, "Connection message")
        await logger.info(.association, "Association message")
        
        // These should be filtered
        await logger.info(.pdu, "PDU message")
        await logger.info(.dimse, "DIMSE message")
        
        // Give some time for the messages to be processed
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(mockHandler.messages.count, 2)
        XCTAssertEqual(mockHandler.messages[0].category, .connection)
        XCTAssertEqual(mockHandler.messages[1].category, .association)
        
        // Clean up
        await logger.removeAllHandlers()
        await logger.setEnabledCategories([]) // Reset to allow all
    }
    
    func testLoggerHelperMethods() async {
        let logger = DICOMLogger.shared
        await logger.removeAllHandlers()
        
        let mockHandler = MockLogHandler()
        await logger.addHandler(mockHandler)
        await logger.setMinimumLevel(.debug)
        await logger.setEnabledCategories([])
        
        // Test PDU logging
        await logger.logPDU(type: "A-ASSOCIATE-RQ", direction: "sent", size: 256)
        
        // Test connection logging
        await logger.logConnectionAttempt(host: "localhost", port: 11112)
        await logger.logConnectionEstablished(host: "localhost", port: 11112)
        await logger.logConnectionClosed(graceful: true)
        
        // Test association logging
        await logger.logAssociationRequest(callingAE: "MY_SCU", calledAE: "PACS", host: "localhost", port: 11112)
        await logger.logAssociationEstablished(acceptedContexts: 3)
        await logger.logAssociationReleased()
        
        // Test verification logging
        await logger.logVerification(host: "localhost", port: 11112, success: true)
        
        // Give some time for the messages to be processed
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertGreaterThan(mockHandler.messages.count, 0)
        
        // Clean up
        await logger.removeAllHandlers()
    }
}

// MARK: - Log Level and Category Sendable Tests

final class LogLevelConformanceTests: XCTestCase {
    
    func testLogLevelSendable() async {
        let level = DICOMLogLevel.info
        
        // Use the level in an async context
        let rawValue = await Task {
            return level.rawValue
        }.value
        
        XCTAssertEqual(rawValue, 1)
    }
    
    func testLogCategorySendable() async {
        let category = DICOMLogCategory.connection
        
        // Use the category in an async context  
        let rawValue = await Task {
            return category.rawValue
        }.value
        
        XCTAssertEqual(rawValue, "Connection")
    }
}

// MARK: - Performance Logging Tests

final class PerformanceLoggingTests: XCTestCase {
    
    func testOperationTiming() async {
        let logger = DICOMLogger.shared
        await logger.removeAllHandlers()
        
        let mockHandler = DICOMLoggerTests.MockLogHandler()
        await logger.addHandler(mockHandler)
        await logger.setMinimumLevel(.debug)
        
        // Start an operation
        let startTime = await logger.operationStart("Test operation", category: .performance)
        
        // Simulate some work
        try? await Task.sleep(for: .milliseconds(50))
        
        // End the operation
        await logger.operationEnd("Test operation", startTime: startTime, category: .performance, success: true)
        
        // Give some time for the messages to be processed
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(mockHandler.messages.count, 2)
        
        // First message should be "Starting"
        XCTAssertTrue(mockHandler.messages[0].message.contains("Starting"))
        
        // Second message should be "Completed" and include duration
        XCTAssertTrue(mockHandler.messages[1].message.contains("Completed"))
        XCTAssertNotNil(mockHandler.messages[1].context["duration_ms"])
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func testFailedOperationTiming() async {
        let logger = DICOMLogger.shared
        await logger.removeAllHandlers()
        
        let mockHandler = DICOMLoggerTests.MockLogHandler()
        await logger.addHandler(mockHandler)
        await logger.setMinimumLevel(.debug)
        
        let startTime = await logger.operationStart("Failing operation", category: .performance)
        await logger.operationEnd("Failing operation", startTime: startTime, category: .performance, success: false)
        
        // Give some time for the messages to be processed
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(mockHandler.messages.count, 2)
        XCTAssertTrue(mockHandler.messages[1].message.contains("Failed"))
        XCTAssertEqual(mockHandler.messages[1].level, .warning)
        
        // Clean up
        await logger.removeAllHandlers()
    }
}
