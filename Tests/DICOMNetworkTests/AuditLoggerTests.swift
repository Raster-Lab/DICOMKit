import XCTest
@testable import DICOMNetwork

/// Tests for the AuditLogger and related types
final class AuditLoggerTests: XCTestCase {
    
    // MARK: - AuditEventType Tests
    
    func test_auditEventType_rawValues() {
        XCTAssertEqual(AuditEventType.associationEstablished.rawValue, "ASSOCIATION_ESTABLISHED")
        XCTAssertEqual(AuditEventType.associationRejected.rawValue, "ASSOCIATION_REJECTED")
        XCTAssertEqual(AuditEventType.associationReleased.rawValue, "ASSOCIATION_RELEASED")
        XCTAssertEqual(AuditEventType.associationAborted.rawValue, "ASSOCIATION_ABORTED")
        XCTAssertEqual(AuditEventType.storeSent.rawValue, "STORE_SENT")
        XCTAssertEqual(AuditEventType.storeReceived.rawValue, "STORE_RECEIVED")
        XCTAssertEqual(AuditEventType.queryExecuted.rawValue, "QUERY_EXECUTED")
        XCTAssertEqual(AuditEventType.retrieveMoveStarted.rawValue, "RETRIEVE_MOVE_STARTED")
        XCTAssertEqual(AuditEventType.retrieveMoveCompleted.rawValue, "RETRIEVE_MOVE_COMPLETED")
        XCTAssertEqual(AuditEventType.retrieveGetStarted.rawValue, "RETRIEVE_GET_STARTED")
        XCTAssertEqual(AuditEventType.retrieveGetCompleted.rawValue, "RETRIEVE_GET_COMPLETED")
        XCTAssertEqual(AuditEventType.verificationPerformed.rawValue, "VERIFICATION_PERFORMED")
        XCTAssertEqual(AuditEventType.commitmentRequested.rawValue, "COMMITMENT_REQUESTED")
        XCTAssertEqual(AuditEventType.commitmentResultReceived.rawValue, "COMMITMENT_RESULT_RECEIVED")
        XCTAssertEqual(AuditEventType.connectionEstablished.rawValue, "CONNECTION_ESTABLISHED")
        XCTAssertEqual(AuditEventType.connectionFailed.rawValue, "CONNECTION_FAILED")
        XCTAssertEqual(AuditEventType.securityEvent.rawValue, "SECURITY_EVENT")
    }
    
    func test_auditEventType_description() {
        XCTAssertEqual(AuditEventType.storeSent.description, "STORE_SENT")
        XCTAssertEqual(AuditEventType.queryExecuted.description, "QUERY_EXECUTED")
    }
    
    func test_auditEventType_allCases() {
        XCTAssertEqual(AuditEventType.allCases.count, 17)
    }
    
    // MARK: - AuditEventOutcome Tests
    
    func test_auditEventOutcome_rawValues() {
        XCTAssertEqual(AuditEventOutcome.success.rawValue, "SUCCESS")
        XCTAssertEqual(AuditEventOutcome.minorFailure.rawValue, "MINOR_FAILURE")
        XCTAssertEqual(AuditEventOutcome.seriousFailure.rawValue, "SERIOUS_FAILURE")
        XCTAssertEqual(AuditEventOutcome.majorFailure.rawValue, "MAJOR_FAILURE")
    }
    
    func test_auditEventOutcome_description() {
        XCTAssertEqual(AuditEventOutcome.success.description, "SUCCESS")
        XCTAssertEqual(AuditEventOutcome.majorFailure.description, "MAJOR_FAILURE")
    }
    
    // MARK: - AuditParticipant Tests
    
    func test_auditParticipant_initialization() {
        let participant = AuditParticipant(
            aeTitle: "TEST_AE",
            host: "192.168.1.1",
            port: 11112,
            isRequestor: true,
            userIdentity: "testuser"
        )
        
        XCTAssertEqual(participant.aeTitle, "TEST_AE")
        XCTAssertEqual(participant.host, "192.168.1.1")
        XCTAssertEqual(participant.port, 11112)
        XCTAssertTrue(participant.isRequestor)
        XCTAssertEqual(participant.userIdentity, "testuser")
    }
    
    func test_auditParticipant_initializationWithoutUserIdentity() {
        let participant = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "pacs.hospital.com",
            port: 104,
            isRequestor: false
        )
        
        XCTAssertEqual(participant.aeTitle, "PACS_AE")
        XCTAssertEqual(participant.host, "pacs.hospital.com")
        XCTAssertEqual(participant.port, 104)
        XCTAssertFalse(participant.isRequestor)
        XCTAssertNil(participant.userIdentity)
    }
    
    func test_auditParticipant_description() {
        let requestor = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true,
            userIdentity: "admin"
        )
        
        XCTAssertTrue(requestor.description.contains("CLIENT_AE"))
        XCTAssertTrue(requestor.description.contains("10.0.0.1"))
        XCTAssertTrue(requestor.description.contains("11112"))
        XCTAssertTrue(requestor.description.contains("requestor"))
        XCTAssertTrue(requestor.description.contains("admin"))
        
        let responder = AuditParticipant(
            aeTitle: "SERVER_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        XCTAssertTrue(responder.description.contains("responder"))
    }
    
    func test_auditParticipant_hashable() {
        let participant1 = AuditParticipant(
            aeTitle: "TEST_AE",
            host: "192.168.1.1",
            port: 11112,
            isRequestor: true
        )
        
        let participant2 = AuditParticipant(
            aeTitle: "TEST_AE",
            host: "192.168.1.1",
            port: 11112,
            isRequestor: true
        )
        
        let participant3 = AuditParticipant(
            aeTitle: "OTHER_AE",
            host: "192.168.1.1",
            port: 11112,
            isRequestor: true
        )
        
        XCTAssertEqual(participant1, participant2)
        XCTAssertNotEqual(participant1, participant3)
    }
    
    // MARK: - AuditLogEntry Tests
    
    func test_auditLogEntry_minimalInitialization() {
        let source = AuditParticipant(
            aeTitle: "SOURCE_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let entry = AuditLogEntry(
            eventType: .verificationPerformed,
            outcome: .success,
            source: source
        )
        
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.eventType, .verificationPerformed)
        XCTAssertEqual(entry.outcome, .success)
        XCTAssertNotNil(entry.timestamp)
        XCTAssertEqual(entry.source.aeTitle, "SOURCE_AE")
        XCTAssertNil(entry.destination)
        XCTAssertNil(entry.sopClassUID)
        XCTAssertNil(entry.sopInstanceUID)
        XCTAssertNil(entry.studyInstanceUID)
        XCTAssertNil(entry.seriesInstanceUID)
        XCTAssertNil(entry.patientID)
        XCTAssertNil(entry.accessionNumber)
        XCTAssertNil(entry.bytesTransferred)
        XCTAssertNil(entry.duration)
        XCTAssertNil(entry.instanceCount)
        XCTAssertNil(entry.statusCode)
        XCTAssertNil(entry.errorMessage)
        XCTAssertTrue(entry.metadata.isEmpty)
    }
    
    func test_auditLogEntry_fullInitialization() {
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        let entry = AuditLogEntry(
            eventType: .storeSent,
            outcome: .success,
            source: source,
            destination: destination,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6",
            patientID: "PATIENT123",
            accessionNumber: "ACC001",
            bytesTransferred: 524288,
            duration: 1.5,
            instanceCount: 1,
            statusCode: 0x0000,
            errorMessage: nil,
            metadata: ["customKey": "customValue"]
        )
        
        XCTAssertEqual(entry.eventType, .storeSent)
        XCTAssertEqual(entry.outcome, .success)
        XCTAssertEqual(entry.source.aeTitle, "CLIENT_AE")
        XCTAssertEqual(entry.destination?.aeTitle, "PACS_AE")
        XCTAssertEqual(entry.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(entry.sopInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(entry.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(entry.seriesInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(entry.patientID, "PATIENT123")
        XCTAssertEqual(entry.accessionNumber, "ACC001")
        XCTAssertEqual(entry.bytesTransferred, 524288)
        XCTAssertEqual(entry.duration, 1.5)
        XCTAssertEqual(entry.instanceCount, 1)
        XCTAssertEqual(entry.statusCode, 0x0000)
        XCTAssertNil(entry.errorMessage)
        XCTAssertEqual(entry.metadata["customKey"], "customValue")
    }
    
    func test_auditLogEntry_description() {
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        let entry = AuditLogEntry(
            eventType: .storeSent,
            outcome: .success,
            source: source,
            destination: destination,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            bytesTransferred: 524288,
            duration: 1.5,
            statusCode: 0x0000
        )
        
        let description = entry.description
        
        XCTAssertTrue(description.contains("[STORE_SENT]"))
        XCTAssertTrue(description.contains("[SUCCESS]"))
        XCTAssertTrue(description.contains("source="))
        XCTAssertTrue(description.contains("dest="))
        XCTAssertTrue(description.contains("sopClass="))
        XCTAssertTrue(description.contains("sopInstance="))
        XCTAssertTrue(description.contains("bytes=524288"))
        XCTAssertTrue(description.contains("duration="))
        XCTAssertTrue(description.contains("status=0x0000"))
    }
    
    func test_auditLogEntry_errorDescription() {
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let entry = AuditLogEntry(
            eventType: .connectionFailed,
            outcome: .majorFailure,
            source: source,
            errorMessage: "Connection refused"
        )
        
        XCTAssertTrue(entry.description.contains("error=Connection refused"))
    }
    
    // MARK: - ConsoleAuditLogHandler Tests
    
    func test_consoleAuditLogHandler_initialization() {
        let handler = ConsoleAuditLogHandler(verbose: true)
        XCTAssertTrue(handler.verbose)
        
        let briefHandler = ConsoleAuditLogHandler(verbose: false)
        XCTAssertFalse(briefHandler.verbose)
    }
    
    func test_consoleAuditLogHandler_handleAuditEvent() {
        let handler = ConsoleAuditLogHandler(verbose: false)
        
        let source = AuditParticipant(
            aeTitle: "TEST_AE",
            host: "localhost",
            port: 11112,
            isRequestor: true
        )
        
        let entry = AuditLogEntry(
            eventType: .verificationPerformed,
            outcome: .success,
            source: source
        )
        
        // Just verify it doesn't crash
        handler.handleAuditEvent(entry)
    }
    
    // MARK: - AuditLogger Tests
    
    func test_auditLogger_isAuditingEnabledByDefault() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let enabled = await logger.isAuditingEnabled
        XCTAssertFalse(enabled)
    }
    
    func test_auditLogger_addHandler() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = ConsoleAuditLogHandler(verbose: false)
        await logger.addHandler(handler)
        
        let enabled = await logger.isAuditingEnabled
        XCTAssertTrue(enabled)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_removeAllHandlers() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = ConsoleAuditLogHandler(verbose: false)
        await logger.addHandler(handler)
        
        var enabled = await logger.isAuditingEnabled
        XCTAssertTrue(enabled)
        
        await logger.removeAllHandlers()
        
        enabled = await logger.isAuditingEnabled
        XCTAssertFalse(enabled)
    }
    
    func test_auditLogger_setEnabledEventTypes() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        // Set only specific event types
        await logger.setEnabledEventTypes([.storeSent, .storeReceived])
        
        // Clean up
        await logger.setEnabledEventTypes([])
    }
    
    func test_auditLogger_logStoreSent() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logStoreSent(
            outcome: .success,
            source: source,
            destination: destination,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            bytesTransferred: 524288,
            duration: 1.5,
            statusCode: 0x0000
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .storeSent)
        XCTAssertEqual(handler.entries.first?.outcome, .success)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logStoreReceived() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "SENDER_AE",
            host: "10.0.0.3",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "SCP_AE",
            host: "10.0.0.1",
            port: 104,
            isRequestor: false
        )
        
        await logger.logStoreReceived(
            outcome: .success,
            source: source,
            destination: destination,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.4",
            sopInstanceUID: "1.2.3.4.5.6.7.8.10",
            bytesTransferred: 1048576,
            duration: 2.5,
            statusCode: 0x0000
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .storeReceived)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logAssociationEstablished() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logAssociationEstablished(
            outcome: .success,
            source: source,
            destination: destination,
            acceptedContexts: 5
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .associationEstablished)
        XCTAssertEqual(handler.entries.first?.metadata["acceptedContexts"], "5")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logAssociationRejected() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logAssociationRejected(
            source: source,
            destination: destination,
            reason: "Invalid AE Title",
            resultCode: 2
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .associationRejected)
        XCTAssertEqual(handler.entries.first?.outcome, .majorFailure)
        XCTAssertEqual(handler.entries.first?.errorMessage, "Invalid AE Title")
        XCTAssertEqual(handler.entries.first?.statusCode, 2)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logAssociationReleased() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logAssociationReleased(
            source: source,
            destination: destination
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .associationReleased)
        XCTAssertEqual(handler.entries.first?.outcome, .success)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logAssociationAborted() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logAssociationAborted(
            source: source,
            destination: destination,
            reason: "Protocol error"
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .associationAborted)
        XCTAssertEqual(handler.entries.first?.outcome, .seriousFailure)
        XCTAssertEqual(handler.entries.first?.errorMessage, "Protocol error")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logQueryExecuted() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logQueryExecuted(
            outcome: .success,
            source: source,
            destination: destination,
            queryLevel: "STUDY",
            resultCount: 42,
            duration: 0.5
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .queryExecuted)
        XCTAssertEqual(handler.entries.first?.metadata["queryLevel"], "STUDY")
        XCTAssertEqual(handler.entries.first?.metadata["resultCount"], "42")
        XCTAssertEqual(handler.entries.first?.instanceCount, 42)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logVerificationPerformed() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logVerificationPerformed(
            outcome: .success,
            source: source,
            destination: destination,
            duration: 0.1
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .verificationPerformed)
        XCTAssertEqual(handler.entries.first?.outcome, .success)
        XCTAssertEqual(handler.entries.first?.duration, 0.1)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logConnectionEvent_success() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        await logger.logConnectionEvent(
            established: true,
            source: source,
            host: "10.0.0.2",
            port: 104
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .connectionEstablished)
        XCTAssertEqual(handler.entries.first?.outcome, .success)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logConnectionEvent_failure() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        await logger.logConnectionEvent(
            established: false,
            source: source,
            host: "10.0.0.2",
            port: 104,
            errorMessage: "Connection refused"
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .connectionFailed)
        XCTAssertEqual(handler.entries.first?.outcome, .majorFailure)
        XCTAssertEqual(handler.entries.first?.errorMessage, "Connection refused")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logSecurityEvent() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "UNKNOWN_AE",
            host: "10.0.0.99",
            port: 11112,
            isRequestor: true
        )
        
        await logger.logSecurityEvent(
            outcome: .majorFailure,
            source: source,
            description: "Authentication failed: invalid credentials"
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .securityEvent)
        XCTAssertEqual(handler.entries.first?.metadata["description"], "Authentication failed: invalid credentials")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logCommitmentRequested() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logCommitmentRequested(
            source: source,
            destination: destination,
            transactionUID: "1.2.3.4.5.6.7.8.9.0",
            instanceCount: 10
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .commitmentRequested)
        XCTAssertEqual(handler.entries.first?.metadata["transactionUID"], "1.2.3.4.5.6.7.8.9.0")
        XCTAssertEqual(handler.entries.first?.instanceCount, 10)
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logCommitmentResultReceived() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logCommitmentResultReceived(
            outcome: .minorFailure,
            source: source,
            destination: destination,
            transactionUID: "1.2.3.4.5.6.7.8.9.0",
            committedCount: 8,
            failedCount: 2
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .commitmentResultReceived)
        XCTAssertEqual(handler.entries.first?.outcome, .minorFailure)
        XCTAssertEqual(handler.entries.first?.metadata["committedCount"], "8")
        XCTAssertEqual(handler.entries.first?.metadata["failedCount"], "2")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_eventTypeFiltering() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        // Only allow store events
        await logger.setEnabledEventTypes([.storeSent, .storeReceived])
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        // This should be logged
        await logger.logStoreSent(
            outcome: .success,
            source: source,
            destination: destination,
            sopClassUID: nil,
            sopInstanceUID: nil,
            bytesTransferred: nil,
            duration: nil,
            statusCode: nil
        )
        
        // This should NOT be logged (filtered out)
        await logger.logVerificationPerformed(
            outcome: .success,
            source: source,
            destination: destination,
            duration: 0.1
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .storeSent)
        
        // Clean up
        await logger.setEnabledEventTypes([])
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_disabledLogging() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        // No handler added, so this should not crash
        await logger.logVerificationPerformed(
            outcome: .success,
            source: source,
            destination: destination,
            duration: 0.1
        )
        
        // Test passed if no crash occurred
    }
    
    // MARK: - Retrieve Logging Tests
    
    func test_auditLogger_logRetrieveMoveStarted() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logRetrieveMoveStarted(
            source: source,
            destination: destination,
            moveDestination: "STORE_SCP",
            studyInstanceUID: "1.2.3.4.5"
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .retrieveMoveStarted)
        XCTAssertEqual(handler.entries.first?.metadata["moveDestination"], "STORE_SCP")
        XCTAssertEqual(handler.entries.first?.studyInstanceUID, "1.2.3.4.5")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logRetrieveMoveCompleted() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logRetrieveMoveCompleted(
            outcome: .success,
            source: source,
            destination: destination,
            completedCount: 50,
            failedCount: 0,
            duration: 30.5
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .retrieveMoveCompleted)
        XCTAssertEqual(handler.entries.first?.instanceCount, 50)
        XCTAssertEqual(handler.entries.first?.metadata["completedCount"], "50")
        XCTAssertEqual(handler.entries.first?.metadata["failedCount"], "0")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logRetrieveGetStarted() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logRetrieveGetStarted(
            source: source,
            destination: destination,
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .retrieveGetStarted)
        XCTAssertEqual(handler.entries.first?.seriesInstanceUID, "1.2.3.4.5.6")
        
        // Clean up
        await logger.removeAllHandlers()
    }
    
    func test_auditLogger_logRetrieveGetCompleted() async {
        let logger = AuditLogger.shared
        await logger.removeAllHandlers()
        
        let handler = MockAuditLogHandler()
        await logger.addHandler(handler)
        
        let source = AuditParticipant(
            aeTitle: "CLIENT_AE",
            host: "10.0.0.1",
            port: 11112,
            isRequestor: true
        )
        
        let destination = AuditParticipant(
            aeTitle: "PACS_AE",
            host: "10.0.0.2",
            port: 104,
            isRequestor: false
        )
        
        await logger.logRetrieveGetCompleted(
            outcome: .minorFailure,
            source: source,
            destination: destination,
            completedCount: 48,
            failedCount: 2,
            bytesTransferred: 104857600, // 100 MB
            duration: 60.0
        )
        
        XCTAssertEqual(handler.entries.count, 1)
        XCTAssertEqual(handler.entries.first?.eventType, .retrieveGetCompleted)
        XCTAssertEqual(handler.entries.first?.outcome, .minorFailure)
        XCTAssertEqual(handler.entries.first?.instanceCount, 48)
        XCTAssertEqual(handler.entries.first?.bytesTransferred, 104857600)
        XCTAssertEqual(handler.entries.first?.metadata["completedCount"], "48")
        XCTAssertEqual(handler.entries.first?.metadata["failedCount"], "2")
        
        // Clean up
        await logger.removeAllHandlers()
    }
}

// MARK: - Mock Audit Log Handler

/// Mock handler for testing audit logging.
/// This class uses @unchecked Sendable because it is only used in test contexts
/// where synchronization is handled by test expectations and awaiting the logger.
/// The entries array is accessed sequentially in each test case.
final class MockAuditLogHandler: AuditLogHandler, @unchecked Sendable {
    var entries: [AuditLogEntry] = []
    
    func handleAuditEvent(_ entry: AuditLogEntry) {
        entries.append(entry)
    }
}
