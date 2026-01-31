import XCTest
@testable import DICOMNetwork

// MARK: - Retry Policy Configuration Tests

final class RetryPolicyConfigurationTests: XCTestCase {
    
    // MARK: - Default Configuration Tests
    
    func test_configuration_defaultValues() {
        let policy = RetryPolicy()
        
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.initialDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertNil(policy.maxTotalTime)
        XCTAssertTrue(policy.useCircuitBreaker)
        XCTAssertTrue(policy.retryableCategories.contains(.transient))
        XCTAssertTrue(policy.retryableCategories.contains(.timeout))
        XCTAssertTrue(policy.retryableCategories.contains(.resource))
    }
    
    func test_configuration_customValues() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            initialDelay: 2.0,
            maxDelay: 60.0,
            maxTotalTime: 120.0,
            strategy: .fixed,
            retryableCategories: [.transient],
            useCircuitBreaker: false
        )
        
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 2.0)
        XCTAssertEqual(policy.maxDelay, 60.0)
        XCTAssertEqual(policy.maxTotalTime, 120.0)
        XCTAssertFalse(policy.useCircuitBreaker)
        XCTAssertEqual(policy.retryableCategories, [.transient])
    }
    
    func test_configuration_negativeValuesAreNormalized() {
        let policy = RetryPolicy(
            maxAttempts: -5,
            initialDelay: -2.0,
            maxDelay: -10.0
        )
        
        // maxAttempts should be at least 0
        XCTAssertEqual(policy.maxAttempts, 0)
        // initialDelay should be at least 0.1
        XCTAssertEqual(policy.initialDelay, 0.1)
        // maxDelay should be at least initialDelay
        XCTAssertGreaterThanOrEqual(policy.maxDelay, policy.initialDelay)
    }
    
    func test_configuration_maxDelayNormalizedToInitialDelay() {
        let policy = RetryPolicy(
            initialDelay: 10.0,
            maxDelay: 5.0  // Less than initialDelay
        )
        
        // maxDelay should be at least initialDelay
        XCTAssertEqual(policy.maxDelay, 10.0)
    }
    
    // MARK: - Preset Tests
    
    func test_preset_noRetry() {
        let policy = RetryPolicy.noRetry
        
        XCTAssertEqual(policy.maxAttempts, 0)
        XCTAssertEqual(policy.initialDelay, 0.1)  // Minimum allowed, won't be used
        XCTAssertEqual(policy.maxDelay, 0.1)      // Same as initialDelay
    }
    
    func test_preset_aggressive() {
        let policy = RetryPolicy.aggressive
        
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 0.5)
        XCTAssertEqual(policy.maxDelay, 60.0)
        XCTAssertEqual(policy.maxTotalTime, 180.0)
    }
    
    func test_preset_conservative() {
        let policy = RetryPolicy.conservative
        
        XCTAssertEqual(policy.maxAttempts, 2)
        XCTAssertEqual(policy.initialDelay, 2.0)
        XCTAssertEqual(policy.maxDelay, 10.0)
        XCTAssertEqual(policy.maxTotalTime, 30.0)
    }
    
    func test_preset_fast() {
        let policy = RetryPolicy.fast
        
        XCTAssertEqual(policy.maxAttempts, 2)
        XCTAssertEqual(policy.initialDelay, 0.1)
        XCTAssertEqual(policy.maxDelay, 1.0)
    }
    
    // MARK: - Hashable Tests
    
    func test_configuration_hashable() {
        let policy1 = RetryPolicy(maxAttempts: 3, initialDelay: 1.0)
        let policy2 = RetryPolicy(maxAttempts: 3, initialDelay: 1.0)
        let policy3 = RetryPolicy(maxAttempts: 5, initialDelay: 2.0)
        
        XCTAssertEqual(policy1, policy2)
        XCTAssertNotEqual(policy1, policy3)
        XCTAssertEqual(policy1.hashValue, policy2.hashValue)
    }
    
    // MARK: - Description Tests
    
    func test_configuration_description() {
        let policy = RetryPolicy.default
        let description = policy.description
        
        XCTAssertTrue(description.contains("RetryPolicy"))
        XCTAssertTrue(description.contains("maxAttempts: 3"))
        XCTAssertTrue(description.contains("initialDelay: 1.0"))
    }
}

// MARK: - Retry Strategy Tests

final class RetryStrategyTests: XCTestCase {
    
    // MARK: - Fixed Strategy Tests
    
    func test_strategy_fixed_constantDelay() {
        let strategy = RetryStrategy.fixed
        
        // All attempts should have the same delay
        XCTAssertEqual(strategy.calculateDelay(attempt: 0, initialDelay: 1.0), 1.0)
        XCTAssertEqual(strategy.calculateDelay(attempt: 1, initialDelay: 1.0), 1.0)
        XCTAssertEqual(strategy.calculateDelay(attempt: 2, initialDelay: 1.0), 1.0)
        XCTAssertEqual(strategy.calculateDelay(attempt: 5, initialDelay: 1.0), 1.0)
    }
    
    // MARK: - Exponential Strategy Tests
    
    func test_strategy_exponential_doublingDelay() {
        let strategy = RetryStrategy.exponential(factor: 2.0)
        
        // Delay should double each attempt
        XCTAssertEqual(strategy.calculateDelay(attempt: 0, initialDelay: 1.0), 1.0)
        XCTAssertEqual(strategy.calculateDelay(attempt: 1, initialDelay: 1.0), 2.0)
        XCTAssertEqual(strategy.calculateDelay(attempt: 2, initialDelay: 1.0), 4.0)
        XCTAssertEqual(strategy.calculateDelay(attempt: 3, initialDelay: 1.0), 8.0)
    }
    
    func test_strategy_exponential_customFactor() {
        let strategy = RetryStrategy.exponential(factor: 1.5)
        
        // Delay should multiply by 1.5 each attempt
        let attempt0 = strategy.calculateDelay(attempt: 0, initialDelay: 2.0)
        let attempt1 = strategy.calculateDelay(attempt: 1, initialDelay: 2.0)
        let attempt2 = strategy.calculateDelay(attempt: 2, initialDelay: 2.0)
        
        XCTAssertEqual(attempt0, 2.0, accuracy: 0.001)
        XCTAssertEqual(attempt1, 3.0, accuracy: 0.001)
        XCTAssertEqual(attempt2, 4.5, accuracy: 0.001)
    }
    
    // MARK: - Exponential with Jitter Tests
    
    func test_strategy_exponentialWithJitter_hasRandomness() {
        let strategy = RetryStrategy.exponentialWithJitter(factor: 2.0, jitterRange: 0.25)
        
        // Run multiple times to verify randomness
        var delays: [TimeInterval] = []
        for _ in 0..<10 {
            delays.append(strategy.calculateDelay(attempt: 2, initialDelay: 1.0))
        }
        
        // Not all delays should be exactly the same (with very high probability)
        let uniqueDelays = Set(delays)
        XCTAssertGreaterThan(uniqueDelays.count, 1, "Jitter should produce varying delays")
    }
    
    func test_strategy_exponentialWithJitter_withinJitterRange() {
        let strategy = RetryStrategy.exponentialWithJitter(factor: 2.0, jitterRange: 0.25)
        
        // For attempt 1 with initialDelay 1.0, base is 2.0
        // With 25% jitter, range should be 1.5 to 2.5
        for _ in 0..<20 {
            let delay = strategy.calculateDelay(attempt: 1, initialDelay: 1.0)
            XCTAssertGreaterThanOrEqual(delay, 1.5)
            XCTAssertLessThanOrEqual(delay, 2.5)
        }
    }
    
    // MARK: - Linear Strategy Tests
    
    func test_strategy_linear_incrementalDelay() {
        let strategy = RetryStrategy.linear(increment: 1.0)
        
        // Delay should increase linearly
        let attempt0 = strategy.calculateDelay(attempt: 0, initialDelay: 1.0)
        let attempt1 = strategy.calculateDelay(attempt: 1, initialDelay: 1.0)
        let attempt2 = strategy.calculateDelay(attempt: 2, initialDelay: 1.0)
        let attempt3 = strategy.calculateDelay(attempt: 3, initialDelay: 1.0)
        
        XCTAssertEqual(attempt0, 1.0)  // 1 * (1 + 0*1)
        XCTAssertEqual(attempt1, 2.0)  // 1 * (1 + 1*1)
        XCTAssertEqual(attempt2, 3.0)  // 1 * (1 + 2*1)
        XCTAssertEqual(attempt3, 4.0)  // 1 * (1 + 3*1)
    }
    
    // MARK: - Hashable Tests
    
    func test_strategy_hashable() {
        let strategy1 = RetryStrategy.exponential(factor: 2.0)
        let strategy2 = RetryStrategy.exponential(factor: 2.0)
        let strategy3 = RetryStrategy.exponential(factor: 1.5)
        let strategy4 = RetryStrategy.fixed
        
        XCTAssertEqual(strategy1, strategy2)
        XCTAssertNotEqual(strategy1, strategy3)
        XCTAssertNotEqual(strategy1, strategy4)
    }
    
    // MARK: - Description Tests
    
    func test_strategy_description() {
        XCTAssertEqual(RetryStrategy.fixed.description, "fixed")
        XCTAssertTrue(RetryStrategy.exponential(factor: 2.0).description.contains("exponential"))
        XCTAssertTrue(RetryStrategy.exponentialWithJitter(factor: 2.0, jitterRange: 0.25).description.contains("jitter"))
        XCTAssertTrue(RetryStrategy.linear(increment: 1.0).description.contains("linear"))
    }
}

// MARK: - Retry Policy Delay Tests

final class RetryPolicyDelayTests: XCTestCase {
    
    func test_delay_cappedAtMaxDelay() {
        let policy = RetryPolicy(
            maxAttempts: 10,
            initialDelay: 1.0,
            maxDelay: 5.0,
            strategy: .exponential(factor: 2.0)
        )
        
        // Delay should never exceed maxDelay
        for attempt in 0..<10 {
            let delay = policy.delay(forAttempt: attempt)
            XCTAssertLessThanOrEqual(delay, 5.0)
        }
    }
    
    func test_delay_exponentialGrowth() {
        let policy = RetryPolicy(
            initialDelay: 1.0,
            maxDelay: 100.0,
            strategy: .exponential(factor: 2.0)
        )
        
        XCTAssertEqual(policy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(policy.delay(forAttempt: 2), 4.0)
    }
}

// MARK: - Retry Policy Should Retry Tests

final class RetryPolicyShouldRetryTests: XCTestCase {
    
    func test_shouldRetry_transientError() {
        let policy = RetryPolicy(retryableCategories: [.transient])
        
        // Transient error should be retried
        let error = DICOMNetworkError.connectionFailed("test")
        XCTAssertTrue(policy.shouldRetry(error))
    }
    
    func test_shouldRetry_permanentError() {
        let policy = RetryPolicy(retryableCategories: [.transient])
        
        // Permanent error should NOT be retried
        let error = DICOMNetworkError.sopClassNotSupported("1.2.3")
        XCTAssertFalse(policy.shouldRetry(error))
    }
    
    func test_shouldRetry_timeoutError() {
        let policy = RetryPolicy(retryableCategories: [.timeout])
        
        // Timeout error should be retried
        let error = DICOMNetworkError.timeout
        XCTAssertTrue(policy.shouldRetry(error))
    }
    
    func test_shouldRetry_nonDICOMError() {
        let policy = RetryPolicy.default
        
        // Non-DICOM errors are not retried
        let error = NSError(domain: "test", code: 1)
        XCTAssertFalse(policy.shouldRetry(error))
    }
    
    func test_shouldRetry_circuitBreakerError() {
        let policy = RetryPolicy(retryableCategories: [.resource])
        
        // Circuit breaker error should be retried
        let error = DICOMNetworkError.circuitBreakerOpen(
            host: "test",
            port: 11112,
            retryAfter: Date().addingTimeInterval(10)
        )
        XCTAssertTrue(policy.shouldRetry(error))
    }
}

// MARK: - Retry Context Tests

final class RetryContextTests: XCTestCase {
    
    func test_context_hasMoreAttempts_true() {
        let context = RetryContext(attemptNumber: 2, maxAttempts: 3)
        XCTAssertTrue(context.hasMoreAttempts)
    }
    
    func test_context_hasMoreAttempts_false() {
        let context = RetryContext(attemptNumber: 5, maxAttempts: 3)
        XCTAssertFalse(context.hasMoreAttempts)
    }
    
    func test_context_fractionUsed() {
        let context = RetryContext(attemptNumber: 2, maxAttempts: 4)
        // Fraction used = (2-1)/4 = 0.25 (1 retry used out of 4 allowed)
        XCTAssertEqual(context.fractionUsed, 0.25, accuracy: 0.001)
    }
    
    func test_context_description() {
        let context = RetryContext(
            attemptNumber: 2,
            maxAttempts: 3,
            elapsedTime: 1.5,
            nextDelay: 2.0
        )
        let description = context.description
        
        // attemptNumber=2, maxAttempts=3 means we're on attempt 2 of 4 total (1 initial + 3 retries)
        XCTAssertTrue(description.contains("attempt 2/4"))
        XCTAssertTrue(description.contains("elapsed"))
        XCTAssertTrue(description.contains("nextDelay"))
    }
}

// MARK: - Retry Result Tests

final class RetryResultTests: XCTestCase {
    
    func test_result_success() {
        let result = RetryResult<String>.success(
            "test value",
            attempts: 2,
            time: 1.5
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.value, "test value")
        XCTAssertEqual(result.totalAttempts, 2)
        XCTAssertEqual(result.totalTime, 1.5)
        XCTAssertNil(result.finalError)
    }
    
    func test_result_failure() {
        let errors = [
            DICOMNetworkError.connectionFailed("test1"),
            DICOMNetworkError.timeout
        ]
        let result = RetryResult<String>.failure(
            attempts: 3,
            time: 5.0,
            errors: errors as [Error]
        )
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.totalAttempts, 3)
        XCTAssertEqual(result.totalTime, 5.0)
        XCTAssertNotNil(result.finalError)
        XCTAssertEqual(result.errors.count, 2)
    }
    
    func test_result_description_success() {
        let result = RetryResult<String>.success("test", attempts: 2, time: 1.0)
        let description = result.description
        
        XCTAssertTrue(description.contains("success"))
        XCTAssertTrue(description.contains("2 attempt"))
    }
    
    func test_result_description_failure() {
        let result = RetryResult<String>.failure(
            attempts: 3,
            time: 5.0,
            errors: [DICOMNetworkError.timeout]
        )
        let description = result.description
        
        XCTAssertTrue(description.contains("failed"))
        XCTAssertTrue(description.contains("3 attempt"))
    }
}

// MARK: - Test Counter Actor

/// Thread-safe counter for async tests
private actor TestCounter {
    var value: Int = 0
    
    func increment() {
        value += 1
    }
    
    func get() -> Int {
        return value
    }
}

/// Thread-safe array for async tests
private actor TestContextCollector {
    var contexts: [RetryContext] = []
    
    func append(_ context: RetryContext) {
        contexts.append(context)
    }
    
    func getAll() -> [RetryContext] {
        return contexts
    }
    
    func count() -> Int {
        return contexts.count
    }
}

// MARK: - Retry Executor Tests

final class RetryExecutorTests: XCTestCase {
    
    func test_executor_successOnFirstAttempt() async throws {
        let executor = RetryExecutor(policy: .default)
        let counter = TestCounter()
        
        let result = try await executor.execute {
            await counter.increment()
            return "success"
        }
        
        let attempts = await counter.get()
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 1)
    }
    
    func test_executor_successAfterRetry() async throws {
        let executor = RetryExecutor(policy: RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.01,  // Short delay for tests
            strategy: .fixed
        ))
        
        let counter = TestCounter()
        let result = try await executor.execute {
            await counter.increment()
            let attempts = await counter.get()
            if attempts < 2 {
                throw DICOMNetworkError.connectionFailed("test")
            }
            return "success"
        }
        
        let attempts = await counter.get()
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 2)
    }
    
    func test_executor_exhaustsRetries() async {
        let executor = RetryExecutor(policy: RetryPolicy(
            maxAttempts: 2,
            initialDelay: 0.01,
            strategy: .fixed
        ))
        
        let counter = TestCounter()
        do {
            _ = try await executor.execute {
                await counter.increment()
                throw DICOMNetworkError.connectionFailed("test")
            }
            XCTFail("Should have thrown")
        } catch {
            // Expected
            let attempts = await counter.get()
            XCTAssertEqual(attempts, 3)  // Initial + 2 retries
        }
    }
    
    func test_executor_permanentErrorNoRetry() async {
        let executor = RetryExecutor(policy: RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.01,
            retryableCategories: [.transient]
        ))
        
        let counter = TestCounter()
        do {
            _ = try await executor.execute {
                await counter.increment()
                throw DICOMNetworkError.sopClassNotSupported("1.2.3")
            }
            XCTFail("Should have thrown")
        } catch {
            // Permanent errors are not retried
            let attempts = await counter.get()
            XCTAssertEqual(attempts, 1)
        }
    }
    
    func test_executor_callsOnRetryCallback() async {
        let executor = RetryExecutor(policy: RetryPolicy(
            maxAttempts: 2,
            initialDelay: 0.01,
            strategy: .fixed
        ))
        
        let collector = TestContextCollector()
        let counter = TestCounter()
        
        do {
            _ = try await executor.execute(
                onRetry: { context in
                    await collector.append(context)
                }
            ) {
                await counter.increment()
                throw DICOMNetworkError.connectionFailed("test")
            }
        } catch {
            // Expected
        }
        
        let contexts = await collector.getAll()
        XCTAssertEqual(contexts.count, 2)  // Called before each retry
        XCTAssertEqual(contexts[0].attemptNumber, 2)
        XCTAssertEqual(contexts[1].attemptNumber, 3)
    }
    
    func test_executor_executeWithResult_success() async {
        let executor = RetryExecutor(policy: .fast)
        
        let result = await executor.executeWithResult {
            return "test"
        }
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.value, "test")
        XCTAssertEqual(result.totalAttempts, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func test_executor_executeWithResult_failure() async {
        let executor = RetryExecutor(policy: RetryPolicy(
            maxAttempts: 1,
            initialDelay: 0.01,
            strategy: .fixed
        ))
        
        let result: RetryResult<String> = await executor.executeWithResult {
            throw DICOMNetworkError.connectionFailed("test")
        }
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.totalAttempts, 2)  // Initial + 1 retry
        XCTAssertEqual(result.errors.count, 2)
    }
    
    func test_executor_noRetryPolicy() async {
        let executor = RetryExecutor(policy: .noRetry)
        
        let counter = TestCounter()
        do {
            _ = try await executor.execute {
                await counter.increment()
                throw DICOMNetworkError.connectionFailed("test")
            }
        } catch {
            // Expected
        }
        
        let attempts = await counter.get()
        XCTAssertEqual(attempts, 1)  // No retries
    }
}

// MARK: - Retry Error Tests

final class RetryErrorTests: XCTestCase {
    
    func test_error_exhausted_description() {
        let error = RetryError.exhausted(
            attempts: 3,
            errors: [DICOMNetworkError.connectionFailed("test")]
        )
        let description = error.description
        
        XCTAssertTrue(description.contains("exhausted"))
        XCTAssertTrue(description.contains("3 attempt"))
    }
    
    func test_error_cancelled_description() {
        let error = RetryError.cancelled
        XCTAssertTrue(error.description.contains("cancelled"))
    }
    
    func test_error_timeLimitExceeded_description() {
        let error = RetryError.timeLimitExceeded(elapsed: 120.0, limit: 100.0)
        let description = error.description
        
        XCTAssertTrue(description.contains("time limit"))
        XCTAssertTrue(description.contains("120"))
        XCTAssertTrue(description.contains("100"))
    }
}

// MARK: - SOP Class Retry Configuration Tests

final class SOPClassRetryConfigurationTests: XCTestCase {
    
    func test_configuration_defaultPolicy() {
        let config = SOPClassRetryConfiguration()
        let policy = config.policy(for: "1.2.3.4.5")
        
        XCTAssertEqual(policy, .default)
    }
    
    func test_configuration_customDefaultPolicy() {
        let config = SOPClassRetryConfiguration(defaultPolicy: .aggressive)
        let policy = config.policy(for: "1.2.3.4.5")
        
        XCTAssertEqual(policy, .aggressive)
    }
    
    func test_configuration_setAndGetPolicy() {
        var config = SOPClassRetryConfiguration()
        let ctUID = "1.2.840.10008.5.1.4.1.1.2"  // CT Image Storage
        
        config.setPolicy(.aggressive, for: ctUID)
        
        let policy = config.policy(for: ctUID)
        XCTAssertEqual(policy, .aggressive)
        XCTAssertTrue(config.hasSpecificPolicy(for: ctUID))
    }
    
    func test_configuration_removePolicy() {
        var config = SOPClassRetryConfiguration()
        let ctUID = "1.2.840.10008.5.1.4.1.1.2"
        
        config.setPolicy(.aggressive, for: ctUID)
        config.removePolicy(for: ctUID)
        
        XCTAssertFalse(config.hasSpecificPolicy(for: ctUID))
        XCTAssertEqual(config.policy(for: ctUID), .default)
    }
    
    func test_configuration_configuredSOPClasses() {
        var config = SOPClassRetryConfiguration()
        let ctUID = "1.2.840.10008.5.1.4.1.1.2"
        let mrUID = "1.2.840.10008.5.1.4.1.1.4"
        
        config.setPolicy(.aggressive, for: ctUID)
        config.setPolicy(.conservative, for: mrUID)
        
        let configured = config.configuredSOPClasses
        XCTAssertEqual(configured.count, 2)
        XCTAssertTrue(configured.contains(ctUID))
        XCTAssertTrue(configured.contains(mrUID))
    }
    
    func test_configuration_modalityImagesPreset() {
        let config = SOPClassRetryConfiguration.modalityImages
        
        // CT should have aggressive policy
        let ctPolicy = config.policy(for: "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(ctPolicy, .aggressive)
        
        // MR should have aggressive policy
        let mrPolicy = config.policy(for: "1.2.840.10008.5.1.4.1.1.4")
        XCTAssertEqual(mrPolicy, .aggressive)
        
        // Unknown should have default policy
        let unknownPolicy = config.policy(for: "1.2.3.4.5")
        XCTAssertEqual(unknownPolicy, .default)
    }
    
    func test_configuration_description() {
        var config = SOPClassRetryConfiguration()
        
        // Empty config
        XCTAssertTrue(config.description.contains("SOPClassRetryConfiguration"))
        
        // With specific policies
        config.setPolicy(.aggressive, for: "1.2.3.4.5")
        XCTAssertTrue(config.description.contains("1 specific"))
    }
}
