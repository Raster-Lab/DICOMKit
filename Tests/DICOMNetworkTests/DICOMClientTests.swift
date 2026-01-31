import XCTest
@testable import DICOMNetwork

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

final class RetryPolicyTests: XCTestCase {
    
    func test_nonePolicy() {
        let policy = RetryPolicy.none
        
        XCTAssertEqual(policy.maxRetries, 0)
        XCTAssertFalse(policy.allowsRetries)
    }
    
    func test_fixedPolicy() {
        let policy = RetryPolicy.fixed(maxRetries: 3, delay: 2.0)
        
        XCTAssertEqual(policy.maxRetries, 3)
        XCTAssertEqual(policy.initialDelay, 2.0)
        XCTAssertEqual(policy.maxDelay, 2.0)
        XCTAssertEqual(policy.multiplier, 1.0)
        XCTAssertTrue(policy.allowsRetries)
    }
    
    func test_fixedPolicy_delayCalculation() {
        let policy = RetryPolicy.fixed(maxRetries: 5, delay: 1.5)
        
        // First attempt has no delay
        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
        
        // All subsequent attempts have fixed delay
        XCTAssertEqual(policy.delay(forAttempt: 1), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 2), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 3), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 4), 1.5)
        XCTAssertEqual(policy.delay(forAttempt: 5), 1.5)
    }
    
    func test_exponentialBackoffPolicy() {
        let policy = RetryPolicy.exponentialBackoff(
            maxRetries: 5,
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0
        )
        
        XCTAssertEqual(policy.maxRetries, 5)
        XCTAssertEqual(policy.initialDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
        XCTAssertTrue(policy.allowsRetries)
    }
    
    func test_exponentialBackoffPolicy_delayCalculation() {
        let policy = RetryPolicy.exponentialBackoff(
            maxRetries: 10,
            initialDelay: 0.5,
            maxDelay: 10.0,
            multiplier: 2.0
        )
        
        // First attempt has no delay
        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
        
        // Exponential growth: 0.5, 1.0, 2.0, 4.0, 8.0, then capped at 10
        XCTAssertEqual(policy.delay(forAttempt: 1), 0.5, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 2), 1.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 3), 2.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 4), 4.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 5), 8.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 6), 10.0, accuracy: 0.001)  // Capped
        XCTAssertEqual(policy.delay(forAttempt: 7), 10.0, accuracy: 0.001)  // Capped
    }
    
    func test_exponentialBackoffPolicy_defaultValues() {
        let policy = RetryPolicy.exponentialBackoff(maxRetries: 3)
        
        XCTAssertEqual(policy.maxRetries, 3)
        XCTAssertEqual(policy.initialDelay, 0.5)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
    }
    
    func test_customPolicy() {
        let policy = RetryPolicy(
            maxRetries: 7,
            initialDelay: 0.25,
            maxDelay: 5.0,
            multiplier: 1.5
        )
        
        XCTAssertEqual(policy.maxRetries, 7)
        XCTAssertEqual(policy.initialDelay, 0.25)
        XCTAssertEqual(policy.maxDelay, 5.0)
        XCTAssertEqual(policy.multiplier, 1.5)
    }
    
    func test_policy_negativeValuesAreNormalized() {
        let policy = RetryPolicy(
            maxRetries: -1,
            initialDelay: -5,
            maxDelay: -10,
            multiplier: 0.5
        )
        
        // Negative values should be normalized
        XCTAssertEqual(policy.maxRetries, 0)
        XCTAssertEqual(policy.initialDelay, 0)
        XCTAssertEqual(policy.maxDelay, 0)  // maxDelay >= initialDelay, but both are 0
        XCTAssertEqual(policy.multiplier, 1.0)  // Minimum multiplier is 1.0
    }
    
    func test_policy_hashable() {
        let policy1 = RetryPolicy.fixed(maxRetries: 3, delay: 1.0)
        let policy2 = RetryPolicy.fixed(maxRetries: 3, delay: 1.0)
        let policy3 = RetryPolicy.fixed(maxRetries: 5, delay: 1.0)
        
        XCTAssertEqual(policy1, policy2)
        XCTAssertNotEqual(policy1, policy3)
        XCTAssertEqual(policy1.hashValue, policy2.hashValue)
    }
}

// MARK: - DICOMClient Creation Tests

#if canImport(Network)

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
