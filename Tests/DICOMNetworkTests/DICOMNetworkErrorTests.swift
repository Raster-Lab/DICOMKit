import Testing
import Foundation
@testable import DICOMNetwork

@Suite("DICOM Network Error Tests")
struct DICOMNetworkErrorTests {
    
    /// Helper date in the future for circuit breaker tests
    private static func futureDate(secondsFromNow: TimeInterval = 60) -> Date {
        Date(timeIntervalSinceNow: secondsFromNow)
    }
    
    @Test("Error descriptions are informative")
    func testErrorDescriptions() {
        let connectionError = DICOMNetworkError.connectionFailed("Host unreachable")
        #expect(connectionError.description.contains("Host unreachable"))
        
        let timeoutError = DICOMNetworkError.timeout
        #expect(timeoutError.description.contains("timed out"))
        
        let pduError = DICOMNetworkError.invalidPDU("Bad format")
        #expect(pduError.description.contains("Bad format"))
        
        let pduSizeError = DICOMNetworkError.pduTooLarge(received: 100000, maximum: 16384)
        #expect(pduSizeError.description.contains("100000"))
        #expect(pduSizeError.description.contains("16384"))
        
        let unexpectedPDUError = DICOMNetworkError.unexpectedPDUType(expected: .associateAccept, received: .abort)
        #expect(unexpectedPDUError.description.contains("A-ASSOCIATE-AC"))
        #expect(unexpectedPDUError.description.contains("A-ABORT"))
        
        let rejectError = DICOMNetworkError.associationRejected(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 3
        )
        #expect(rejectError.description.contains("rejected"))
        
        let abortError = DICOMNetworkError.associationAborted(source: .serviceProvider, reason: 2)
        #expect(abortError.description.contains("aborted"))
        
        let noPCError = DICOMNetworkError.noPresentationContextAccepted
        #expect(noPCError.description.contains("presentation context"))
        
        let sopError = DICOMNetworkError.sopClassNotSupported("1.2.3.4.5")
        #expect(sopError.description.contains("1.2.3.4.5"))
        
        let aeError = DICOMNetworkError.invalidAETitle("TOOLONGANAMETOUSE!")
        #expect(aeError.description.contains("TOOLONGANAMETOUSE!"))
        
        let closedError = DICOMNetworkError.connectionClosed
        #expect(closedError.description.contains("closed"))
        
        let stateError = DICOMNetworkError.invalidState("Not connected")
        #expect(stateError.description.contains("Not connected"))
        
        let encodeError = DICOMNetworkError.encodingFailed("Buffer overflow")
        #expect(encodeError.description.contains("Buffer overflow"))
        
        let decodeError = DICOMNetworkError.decodingFailed("Invalid header")
        #expect(decodeError.description.contains("Invalid header"))
        
        let artimError = DICOMNetworkError.artimTimerExpired
        #expect(artimError.description.contains("ARTIM"))
        #expect(artimError.description.contains("expired"))
    }
    
    @Test("Associate Reject Result values")
    func testAssociateRejectResultValues() {
        #expect(AssociateRejectResult.rejectedPermanent.rawValue == 1)
        #expect(AssociateRejectResult.rejectedTransient.rawValue == 2)
        
        #expect(AssociateRejectResult.rejectedPermanent.description.contains("Permanent"))
        #expect(AssociateRejectResult.rejectedTransient.description.contains("Transient"))
    }
    
    @Test("Associate Reject Source values")
    func testAssociateRejectSourceValues() {
        #expect(AssociateRejectSource.serviceUser.rawValue == 1)
        #expect(AssociateRejectSource.serviceProviderACSE.rawValue == 2)
        #expect(AssociateRejectSource.serviceProviderPresentation.rawValue == 3)
        
        #expect(AssociateRejectSource.serviceUser.description.contains("User"))
        #expect(AssociateRejectSource.serviceProviderACSE.description.contains("ACSE"))
        #expect(AssociateRejectSource.serviceProviderPresentation.description.contains("Presentation"))
    }
    
    @Test("Abort Source values")
    func testAbortSourceValues() {
        #expect(AbortSource.serviceUser.rawValue == 0)
        #expect(AbortSource.serviceProvider.rawValue == 2)
        
        #expect(AbortSource.serviceUser.description.contains("User"))
        #expect(AbortSource.serviceProvider.description.contains("Provider"))
    }
    
    @Test("Abort Reason descriptions")
    func testAbortReasonDescriptions() {
        #expect(AbortReason.notSpecified.description.contains("not specified"))
        #expect(AbortReason.unrecognizedPDU.description.contains("Unrecognized PDU"))
        #expect(AbortReason.unexpectedPDU.description.contains("Unexpected PDU"))
        #expect(AbortReason.reserved.description.contains("Reserved"))
        #expect(AbortReason.unrecognizedPDUParameter.description.contains("parameter"))
        #expect(AbortReason.unexpectedPDUParameter.description.contains("parameter"))
        #expect(AbortReason.invalidPDUParameterValue.description.contains("Invalid"))
    }
    
    @Test("isARTIMExpired helper returns correct values")
    func testIsARTIMExpiredHelper() {
        // ARTIM timer expired error should return true
        let artimError = DICOMNetworkError.artimTimerExpired
        #expect(artimError.isARTIMExpired == true)
        
        // Other errors should return false
        #expect(DICOMNetworkError.timeout.isARTIMExpired == false)
        #expect(DICOMNetworkError.connectionClosed.isARTIMExpired == false)
        #expect(DICOMNetworkError.connectionFailed("test").isARTIMExpired == false)
    }
    
    // MARK: - Error Category Tests
    
    @Test("ErrorCategory has all expected cases")
    func testErrorCategoryAllCases() {
        let allCases = ErrorCategory.allCases
        #expect(allCases.count == 6)
        #expect(allCases.contains(.transient))
        #expect(allCases.contains(.permanent))
        #expect(allCases.contains(.configuration))
        #expect(allCases.contains(.protocol))
        #expect(allCases.contains(.timeout))
        #expect(allCases.contains(.resource))
    }
    
    @Test("ErrorCategory descriptions are informative")
    func testErrorCategoryDescriptions() {
        #expect(ErrorCategory.transient.description == "Transient")
        #expect(ErrorCategory.permanent.description == "Permanent")
        #expect(ErrorCategory.configuration.description == "Configuration")
        #expect(ErrorCategory.protocol.description == "Protocol")
        #expect(ErrorCategory.timeout.description == "Timeout")
        #expect(ErrorCategory.resource.description == "Resource")
    }
    
    @Test("Error categories are correctly assigned")
    func testErrorCategoryAssignment() {
        // Transient errors
        #expect(DICOMNetworkError.connectionFailed("test").category == .transient)
        #expect(DICOMNetworkError.connectionClosed.category == .transient)
        #expect(DICOMNetworkError.associationAborted(source: .serviceUser, reason: 0).category == .transient)
        #expect(DICOMNetworkError.partialFailure(succeeded: 5, failed: 2, details: nil).category == .transient)
        
        // Permanent errors
        #expect(DICOMNetworkError.sopClassNotSupported("1.2.3").category == .permanent)
        #expect(DICOMNetworkError.queryFailed(.failedUnableToProcess).category == .permanent)
        #expect(DICOMNetworkError.retrieveFailed(.failedUnableToProcess).category == .permanent)
        #expect(DICOMNetworkError.storeFailed(.failedUnableToProcess).category == .permanent)
        
        // Configuration errors
        #expect(DICOMNetworkError.pduTooLarge(received: 100000, maximum: 16384).category == .configuration)
        #expect(DICOMNetworkError.invalidAETitle("bad").category == .configuration)
        #expect(DICOMNetworkError.noPresentationContextAccepted.category == .configuration)
        
        // Protocol errors
        #expect(DICOMNetworkError.invalidPDU("bad").category == .protocol)
        #expect(DICOMNetworkError.unexpectedPDUType(expected: .associateAccept, received: .abort).category == .protocol)
        #expect(DICOMNetworkError.invalidState("test").category == .protocol)
        #expect(DICOMNetworkError.encodingFailed("test").category == .protocol)
        #expect(DICOMNetworkError.decodingFailed("test").category == .protocol)
        
        // Timeout errors
        #expect(DICOMNetworkError.timeout.category == .timeout)
        #expect(DICOMNetworkError.artimTimerExpired.category == .timeout)
        #expect(DICOMNetworkError.operationTimeout(type: .connect, duration: 30, operation: nil).category == .timeout)
        
        // Resource errors
        let futureDate = Self.futureDate()
        #expect(DICOMNetworkError.circuitBreakerOpen(host: "host", port: 104, retryAfter: futureDate).category == .resource)
    }
    
    @Test("Association rejection category depends on result type")
    func testAssociationRejectionCategory() {
        let permanentReject = DICOMNetworkError.associationRejected(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 1
        )
        #expect(permanentReject.category == .permanent)
        
        let transientReject = DICOMNetworkError.associationRejected(
            result: .rejectedTransient,
            source: .serviceUser,
            reason: 2
        )
        #expect(transientReject.category == .transient)
    }
    
    // MARK: - Retryability Tests
    
    @Test("Retryable errors are correctly identified")
    func testRetryableErrors() {
        // Retryable errors
        #expect(DICOMNetworkError.connectionFailed("test").isRetryable == true)
        #expect(DICOMNetworkError.timeout.isRetryable == true)
        #expect(DICOMNetworkError.connectionClosed.isRetryable == true)
        #expect(DICOMNetworkError.artimTimerExpired.isRetryable == true)
        #expect(DICOMNetworkError.partialFailure(succeeded: 5, failed: 2, details: nil).isRetryable == true)
        #expect(DICOMNetworkError.associationAborted(source: .serviceUser, reason: 0).isRetryable == true)
        #expect(DICOMNetworkError.operationTimeout(type: .read, duration: 30, operation: nil).isRetryable == true)
        
        let futureDate = Self.futureDate()
        #expect(DICOMNetworkError.circuitBreakerOpen(host: "host", port: 104, retryAfter: futureDate).isRetryable == true)
        
        // Non-retryable errors
        #expect(DICOMNetworkError.sopClassNotSupported("1.2.3").isRetryable == false)
        #expect(DICOMNetworkError.invalidAETitle("bad").isRetryable == false)
        #expect(DICOMNetworkError.invalidPDU("test").isRetryable == false)
        #expect(DICOMNetworkError.pduTooLarge(received: 100000, maximum: 16384).isRetryable == false)
        #expect(DICOMNetworkError.noPresentationContextAccepted.isRetryable == false)
        #expect(DICOMNetworkError.encodingFailed("test").isRetryable == false)
        #expect(DICOMNetworkError.decodingFailed("test").isRetryable == false)
        #expect(DICOMNetworkError.queryFailed(.failedUnableToProcess).isRetryable == false)
        #expect(DICOMNetworkError.retrieveFailed(.failedUnableToProcess).isRetryable == false)
        #expect(DICOMNetworkError.storeFailed(.failedUnableToProcess).isRetryable == false)
    }
    
    @Test("Association rejection retryability depends on result type")
    func testAssociationRejectionRetryability() {
        let permanentReject = DICOMNetworkError.associationRejected(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 1
        )
        #expect(permanentReject.isRetryable == false)
        
        let transientReject = DICOMNetworkError.associationRejected(
            result: .rejectedTransient,
            source: .serviceUser,
            reason: 2
        )
        #expect(transientReject.isRetryable == true)
    }
    
    // MARK: - Recovery Suggestion Tests
    
    @Test("RecoverySuggestion descriptions are informative")
    func testRecoverySuggestionDescriptions() {
        #expect(RecoverySuggestion.retry.description == "Retry the operation")
        #expect(RecoverySuggestion.retryWithBackoff(initialDelay: 2.0).description.contains("exponential backoff"))
        #expect(RecoverySuggestion.checkConfiguration(details: "test").description.contains("test"))
        #expect(RecoverySuggestion.contactAdministrator(reason: "help").description.contains("help"))
        #expect(RecoverySuggestion.waitAndRetry(duration: 30).description.contains("30"))
        #expect(RecoverySuggestion.useAlternateServer.description.contains("alternate"))
        #expect(RecoverySuggestion.noRecovery(reason: "permanent").description.contains("permanent"))
    }
    
    @Test("Recovery suggestions are appropriate for errors")
    func testRecoverySuggestions() {
        // Connection errors should suggest retry with backoff
        if case .retryWithBackoff = DICOMNetworkError.connectionFailed("test").recoverySuggestion {
            // Expected
        } else {
            Issue.record("connectionFailed should suggest retryWithBackoff")
        }
        
        // Connection closed should suggest simple retry
        #expect(DICOMNetworkError.connectionClosed.recoverySuggestion == .retry)
        
        // Configuration errors should suggest checking configuration
        if case .checkConfiguration = DICOMNetworkError.invalidAETitle("bad").recoverySuggestion {
            // Expected
        } else {
            Issue.record("invalidAETitle should suggest checkConfiguration")
        }
        
        // Permanent errors should indicate no recovery
        if case .noRecovery = DICOMNetworkError.sopClassNotSupported("1.2.3").recoverySuggestion {
            // Expected
        } else {
            Issue.record("sopClassNotSupported should suggest noRecovery")
        }
        
        // Circuit breaker should suggest wait and retry
        let futureDate = Self.futureDate()
        if case .waitAndRetry = DICOMNetworkError.circuitBreakerOpen(host: "host", port: 104, retryAfter: futureDate).recoverySuggestion {
            // Expected
        } else {
            Issue.record("circuitBreakerOpen should suggest waitAndRetry")
        }
    }
    
    // MARK: - Explanation Tests
    
    @Test("Error explanations are human-readable")
    func testErrorExplanations() {
        // Connection errors
        let connError = DICOMNetworkError.connectionFailed("Host unreachable")
        #expect(connError.explanation.contains("Failed to establish"))
        #expect(connError.explanation.contains("Host unreachable"))
        
        // Timeout
        let timeoutError = DICOMNetworkError.timeout
        #expect(timeoutError.explanation.contains("timed out"))
        
        // PDU size errors
        let pduError = DICOMNetworkError.pduTooLarge(received: 100000, maximum: 16384)
        #expect(pduError.explanation.contains("100000"))
        #expect(pduError.explanation.contains("16384"))
        
        // Association rejection
        let rejectError = DICOMNetworkError.associationRejected(
            result: .rejectedPermanent,
            source: .serviceUser,
            reason: 3
        )
        #expect(rejectError.explanation.contains("rejected"))
        #expect(rejectError.explanation.contains("Service User"))
        
        // Circuit breaker
        let futureDate = Self.futureDate()
        let cbError = DICOMNetworkError.circuitBreakerOpen(host: "pacs.example.com", port: 104, retryAfter: futureDate)
        #expect(cbError.explanation.contains("circuit breaker"))
        #expect(cbError.explanation.contains("pacs.example.com"))
        
        // Partial failure
        let partialError = DICOMNetworkError.partialFailure(succeeded: 10, failed: 3, details: "Network issues")
        #expect(partialError.explanation.contains("10"))
        #expect(partialError.explanation.contains("3"))
        #expect(partialError.explanation.contains("Network issues"))
    }
    
    // MARK: - Timeout Configuration Tests
    
    @Test("TimeoutConfiguration default values")
    func testTimeoutConfigurationDefaults() {
        let config = TimeoutConfiguration.default
        #expect(config.connect == 30)
        #expect(config.read == 30)
        #expect(config.write == 30)
        #expect(config.operation == 120)
        #expect(config.association == 30)
    }
    
    @Test("TimeoutConfiguration fast preset")
    func testTimeoutConfigurationFast() {
        let config = TimeoutConfiguration.fast
        #expect(config.connect == 5)
        #expect(config.read == 10)
        #expect(config.write == 10)
        #expect(config.operation == 30)
        #expect(config.association == 10)
    }
    
    @Test("TimeoutConfiguration slow preset")
    func testTimeoutConfigurationSlow() {
        let config = TimeoutConfiguration.slow
        #expect(config.connect == 60)
        #expect(config.read == 120)
        #expect(config.write == 120)
        #expect(config.operation == 600)
        #expect(config.association == 90)
    }
    
    @Test("TimeoutConfiguration custom values")
    func testTimeoutConfigurationCustom() {
        let config = TimeoutConfiguration(
            connect: 15,
            read: 45,
            write: 20,
            operation: 180,
            association: 60
        )
        #expect(config.connect == 15)
        #expect(config.read == 45)
        #expect(config.write == 20)
        #expect(config.operation == 180)
        #expect(config.association == 60)
    }
    
    @Test("TimeoutConfiguration is Sendable and Hashable")
    func testTimeoutConfigurationConformance() {
        let config1 = TimeoutConfiguration.default
        let config2 = TimeoutConfiguration.default
        let config3 = TimeoutConfiguration.fast
        
        // Hashable
        #expect(config1 == config2)
        #expect(config1 != config3)
        
        // Use in set
        var set = Set<TimeoutConfiguration>()
        set.insert(config1)
        set.insert(config2)
        set.insert(config3)
        #expect(set.count == 2)
    }
    
    @Test("TimeoutConfiguration description")
    func testTimeoutConfigurationDescription() {
        let config = TimeoutConfiguration.default
        #expect(config.description.contains("connect"))
        #expect(config.description.contains("read"))
        #expect(config.description.contains("write"))
        #expect(config.description.contains("operation"))
        #expect(config.description.contains("association"))
    }
    
    // MARK: - Timeout Type Tests
    
    @Test("TimeoutType has all expected cases")
    func testTimeoutTypeAllCases() {
        let allCases = TimeoutType.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.connect))
        #expect(allCases.contains(.read))
        #expect(allCases.contains(.write))
        #expect(allCases.contains(.operation))
        #expect(allCases.contains(.association))
    }
    
    @Test("TimeoutType descriptions")
    func testTimeoutTypeDescriptions() {
        #expect(TimeoutType.connect.description == "Connection")
        #expect(TimeoutType.read.description == "Read")
        #expect(TimeoutType.write.description == "Write")
        #expect(TimeoutType.operation.description == "Operation")
        #expect(TimeoutType.association.description == "Association")
    }
    
    // MARK: - New Error Cases Tests
    
    @Test("Operation timeout error with details")
    func testOperationTimeoutError() {
        let error1 = DICOMNetworkError.operationTimeout(type: .connect, duration: 30, operation: nil)
        #expect(error1.description.contains("Connection"))
        #expect(error1.description.contains("30"))
        
        let error2 = DICOMNetworkError.operationTimeout(type: .operation, duration: 120, operation: "C-FIND")
        #expect(error2.description.contains("Operation"))
        #expect(error2.description.contains("120"))
        #expect(error2.description.contains("C-FIND"))
        
        // Test explanation
        #expect(error1.explanation.contains("Connection timeout"))
        #expect(error2.explanation.contains("C-FIND"))
    }
    
    @Test("Store failed error")
    func testStoreFailedError() {
        let error = DICOMNetworkError.storeFailed(.failedUnableToProcess)
        #expect(error.description.contains("Store failed"))
        #expect(error.category == .permanent)
        #expect(error.isRetryable == false)
    }
    
    @Test("Partial failure error")
    func testPartialFailureError() {
        let error1 = DICOMNetworkError.partialFailure(succeeded: 10, failed: 2, details: nil)
        #expect(error1.description.contains("10 succeeded"))
        #expect(error1.description.contains("2 failed"))
        
        let error2 = DICOMNetworkError.partialFailure(succeeded: 5, failed: 3, details: "Some files had issues")
        #expect(error2.description.contains("Some files had issues"))
        
        // Category and retryability
        #expect(error1.category == .transient)
        #expect(error1.isRetryable == true)
    }
}
