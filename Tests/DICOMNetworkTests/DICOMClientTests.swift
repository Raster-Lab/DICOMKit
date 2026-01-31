import XCTest
@testable import DICOMNetwork

#if canImport(Network)

final class DICOMClientTests: XCTestCase {
    
    // MARK: - Configuration Tests
    
    func test_configuration_defaultValues() throws {
        let config = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        XCTAssertEqual(config.host, "pacs.hospital.com")
        XCTAssertEqual(config.port, 11112)
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.calledAETitle.value, "PACS")
        XCTAssertEqual(config.timeout, 30)
        XCTAssertEqual(config.maxPDUSize, defaultMaxPDUSize)
        XCTAssertFalse(config.tlsEnabled)
        XCTAssertFalse(config.retryPolicy.allowsRetries)
    }
    
    func test_configuration_customValues() throws {
        let config = try DICOMClientConfiguration(
            host: "secure-pacs.hospital.com",
            port: 2762,
            callingAE: "SECURE_SCU",
            calledAE: "SECURE_SCP",
            timeout: 60,
            maxPDUSize: 32768,
            tlsEnabled: true,
            retryPolicy: .fixed(maxRetries: 3, delay: 1.0)
        )
        
        XCTAssertEqual(config.host, "secure-pacs.hospital.com")
        XCTAssertEqual(config.port, 2762)
        XCTAssertEqual(config.callingAETitle.value, "SECURE_SCU")
        XCTAssertEqual(config.calledAETitle.value, "SECURE_SCP")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.maxPDUSize, 32768)
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertTrue(config.retryPolicy.allowsRetries)
    }
    
    func test_configuration_invalidCallingAE() {
        XCTAssertThrowsError(try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "THIS_AE_IS_TOO_LONG_",  // More than 16 characters
            calledAE: "PACS"
        ))
    }
    
    func test_configuration_invalidCalledAE() {
        XCTAssertThrowsError(try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: ""  // Empty AE title
        ))
    }
    
    func test_configuration_withAETitle() {
        let callingAE = try! AETitle("MY_SCU")
        let calledAE = try! AETitle("PACS")
        
        let config = DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAETitle: callingAE,
            calledAETitle: calledAE
        )
        
        XCTAssertEqual(config.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(config.calledAETitle.value, "PACS")
    }
    
    func test_configuration_hashable() throws {
        let config1 = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let config2 = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let config3 = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 104,  // Different port
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
        XCTAssertEqual(config1.hashValue, config2.hashValue)
    }
    
    // MARK: - Default Port Tests
    
    func test_configuration_defaultPort() throws {
        let config = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        XCTAssertEqual(config.port, dicomDefaultPort)
    }
}

// MARK: - Retry Policy Tests

final class DICOMClientRetryPolicyTests: XCTestCase {
    
    func test_noRetryPolicy() {
        let policy = RetryPolicy.noRetry
        
        XCTAssertEqual(policy.maxAttempts, 0)
    }
    
    func test_defaultPolicy() {
        let policy = RetryPolicy.default
        
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.initialDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
    }
    
    func test_fixedStrategy_delayCalculation() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            initialDelay: 1.5,
            maxDelay: 10.0,
            strategy: .fixed
        )
        
        // With fixed strategy, delay(forAttempt:) returns the same delay for all attempts
        // The attempt number represents the retry attempt (0 = first retry, 1 = second retry, etc.)
        XCTAssertEqual(policy.delay(forAttempt: 0), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 1), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 2), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 3), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 4), 1.5)
    }
    
    func test_exponentialStrategy() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            initialDelay: 1.0,
            maxDelay: 30.0,
            strategy: .exponential(factor: 2.0)
        )
        
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
    }
    
    func test_exponentialStrategy_delayCalculation() {
        let policy = RetryPolicy(
            maxAttempts: 10,
            initialDelay: 0.5,
            maxDelay: 10.0,
            strategy: .exponential(factor: 2.0)
        )
        
        // Exponential backoff: delay = initialDelay * (factor ^ attempt)
        // The attempt number represents the retry attempt (0 = first retry, 1 = second retry, etc.)
        // Sequence: 0.5 (attempt 0), 1.0 (attempt 1), 2.0 (attempt 2), 4.0 (attempt 3), 8.0 (attempt 4), then capped at maxDelay
        XCTAssertEqual(policy.delay(forAttempt: 0), 0.5, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 1), 1.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 4), 8.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 5), 10.0, accuracy: 0.001)  // Capped at maxDelay
        XCTAssertEqual(policy.delay(forAttempt: 6), 10.0, accuracy: 0.001)  // Capped at maxDelay
    }
    
    func test_aggressivePolicy() {
        let policy = RetryPolicy.aggressive
        
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 0.5)
        XCTAssertEqual(policy.maxDelay, 60.0)
        XCTAssertEqual(policy.maxTotalTime, 180.0)
    }
    
    func test_customPolicy() {
        let policy = RetryPolicy(
            maxAttempts: 7,
            initialDelay: 0.25,
            maxDelay: 5.0,
            strategy: .exponential(factor: 1.5)
        )
        
        XCTAssertEqual(policy.maxAttempts, 7)
        XCTAssertEqual(policy.initialDelay, 0.25)
        XCTAssertEqual(policy.maxDelay, 5.0)
    }
    
    func test_policy_negativeValuesAreNormalized() {
        let policy = RetryPolicy(
            maxAttempts: -1,
            initialDelay: -5,
            maxDelay: -10
        )
        
        // Negative values should be normalized to valid minimums:
        // - maxAttempts: minimum is 0
        // - initialDelay: minimum is 0.1 seconds
        // - maxDelay: must be >= initialDelay
        XCTAssertEqual(policy.maxAttempts, 0)
        XCTAssertEqual(policy.initialDelay, 0.1)
        XCTAssertGreaterThanOrEqual(policy.maxDelay, policy.initialDelay)
    }
    
    func test_policy_minimumInitialDelay() {
        // Test that very small positive values are also normalized to minimum 0.1
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.01,  // Below minimum
            maxDelay: 5.0
        )
        
        XCTAssertEqual(policy.initialDelay, 0.1)  // Enforced minimum is 0.1 seconds
    }
    
    func test_policy_hashable() {
        let policy1 = RetryPolicy(maxAttempts: 3, initialDelay: 1.0)
        let policy2 = RetryPolicy(maxAttempts: 3, initialDelay: 1.0)
        let policy3 = RetryPolicy(maxAttempts: 5, initialDelay: 1.0)
        
        XCTAssertEqual(policy1, policy2)
        XCTAssertNotEqual(policy1, policy3)
        XCTAssertEqual(policy1.hashValue, policy2.hashValue)
    }
}

// MARK: - DICOMClient Creation Tests

final class DICOMClientCreationTests: XCTestCase {
    
    func test_client_initWithConfiguration() throws {
        let config = try DICOMClientConfiguration(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        let client = DICOMClient(configuration: config)
        
        XCTAssertEqual(client.configuration.host, "pacs.hospital.com")
        XCTAssertEqual(client.configuration.port, 11112)
    }
    
    func test_client_initWithParameters() throws {
        let client = try DICOMClient(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS"
        )
        
        XCTAssertEqual(client.configuration.host, "pacs.hospital.com")
        XCTAssertEqual(client.configuration.port, 11112)
        XCTAssertEqual(client.configuration.callingAETitle.value, "MY_SCU")
        XCTAssertEqual(client.configuration.calledAETitle.value, "PACS")
    }
    
    func test_client_initWithRetryPolicy() throws {
        let client = try DICOMClient(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            retryPolicy: .exponentialBackoff(maxRetries: 5)
        )
        
        XCTAssertTrue(client.configuration.retryPolicy.allowsRetries)
        XCTAssertEqual(client.configuration.retryPolicy.maxRetries, 5)
    }
    
    func test_client_invalidAEThrows() {
        XCTAssertThrowsError(try DICOMClient(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "THIS_IS_TOO_LONG_AE",
            calledAE: "PACS"
        ))
    }
    
    func test_client_description() throws {
        let client = try DICOMClient(
            host: "pacs.hospital.com",
            port: 11112,
            callingAE: "MY_SCU",
            calledAE: "PACS",
            retryPolicy: .fixed(maxRetries: 3, delay: 1.0)
        )
        
        let description = client.description
        
        XCTAssertTrue(description.contains("pacs.hospital.com"))
        XCTAssertTrue(description.contains("11112"))
        XCTAssertTrue(description.contains("MY_SCU"))
        XCTAssertTrue(description.contains("PACS"))
        XCTAssertTrue(description.contains("3 attempts"))
    }
}

#endif
