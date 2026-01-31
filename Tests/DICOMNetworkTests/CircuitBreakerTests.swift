import XCTest
@testable import DICOMNetwork

final class CircuitBreakerConfigurationTests: XCTestCase {
    
    // MARK: - Configuration Tests
    
    func test_configuration_defaultValues() {
        let config = CircuitBreakerConfiguration()
        
        XCTAssertEqual(config.failureThreshold, 5)
        XCTAssertEqual(config.successThreshold, 2)
        XCTAssertEqual(config.resetTimeout, 30)
        XCTAssertEqual(config.failureWindow, 60)
    }
    
    func test_configuration_customValues() {
        let config = CircuitBreakerConfiguration(
            failureThreshold: 3,
            successThreshold: 1,
            resetTimeout: 15,
            failureWindow: 30
        )
        
        XCTAssertEqual(config.failureThreshold, 3)
        XCTAssertEqual(config.successThreshold, 1)
        XCTAssertEqual(config.resetTimeout, 15)
        XCTAssertEqual(config.failureWindow, 30)
    }
    
    func test_configuration_negativeValuesAreNormalized() {
        let config = CircuitBreakerConfiguration(
            failureThreshold: -5,
            successThreshold: -2,
            resetTimeout: -10,
            failureWindow: -30
        )
        
        // All values should be at least 1
        XCTAssertEqual(config.failureThreshold, 1)
        XCTAssertEqual(config.successThreshold, 1)
        XCTAssertEqual(config.resetTimeout, 1)
        XCTAssertEqual(config.failureWindow, 1)
    }
    
    func test_configuration_presets() {
        let defaultConfig = CircuitBreakerConfiguration.default
        let aggressiveConfig = CircuitBreakerConfiguration.aggressive
        let conservativeConfig = CircuitBreakerConfiguration.conservative
        
        // Default preset
        XCTAssertEqual(defaultConfig.failureThreshold, 5)
        
        // Aggressive preset - lower thresholds
        XCTAssertEqual(aggressiveConfig.failureThreshold, 3)
        XCTAssertEqual(aggressiveConfig.successThreshold, 1)
        XCTAssertEqual(aggressiveConfig.resetTimeout, 15)
        
        // Conservative preset - higher thresholds
        XCTAssertEqual(conservativeConfig.failureThreshold, 10)
        XCTAssertEqual(conservativeConfig.successThreshold, 3)
        XCTAssertEqual(conservativeConfig.resetTimeout, 60)
    }
    
    func test_configuration_hashable() {
        let config1 = CircuitBreakerConfiguration(failureThreshold: 5)
        let config2 = CircuitBreakerConfiguration(failureThreshold: 5)
        let config3 = CircuitBreakerConfiguration(failureThreshold: 10)
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
        XCTAssertEqual(config1.hashValue, config2.hashValue)
    }
}

// MARK: - Circuit Breaker State Tests

final class CircuitBreakerStateTests: XCTestCase {
    
    func test_state_description() {
        XCTAssertEqual(CircuitBreakerState.closed.description, "closed")
        XCTAssertEqual(CircuitBreakerState.open.description, "open")
        XCTAssertEqual(CircuitBreakerState.halfOpen.description, "half-open")
    }
    
    func test_state_hashable() {
        XCTAssertEqual(CircuitBreakerState.closed, CircuitBreakerState.closed)
        XCTAssertNotEqual(CircuitBreakerState.closed, CircuitBreakerState.open)
    }
}

// MARK: - Circuit Breaker Tests

final class CircuitBreakerTests: XCTestCase {
    
    func test_initialState_isClosed() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: .default
        )
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed)
        XCTAssertEqual(stats.totalSuccesses, 0)
        XCTAssertEqual(stats.totalFailures, 0)
    }
    
    func test_recordSuccess_incrementsCounter() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: .default
        )
        
        await breaker.recordSuccess()
        await breaker.recordSuccess()
        await breaker.recordSuccess()
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.totalSuccesses, 3)
        XCTAssertEqual(stats.state, .closed)
    }
    
    func test_recordFailure_incrementsCounter() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 10) // High threshold
        )
        
        await breaker.recordFailure()
        await breaker.recordFailure()
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.totalFailures, 2)
        XCTAssertEqual(stats.state, .closed)
    }
    
    func test_circuitOpens_afterThresholdReached() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 3)
        )
        
        // Record failures up to threshold
        await breaker.recordFailure()
        await breaker.recordFailure()
        
        var stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed)
        
        // Third failure should trip the circuit
        await breaker.recordFailure()
        
        stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .open)
        XCTAssertEqual(stats.timesOpened, 1)
        XCTAssertNotNil(stats.lastOpenedAt)
    }
    
    func test_checkState_throwsWhenOpen() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 1, resetTimeout: 30)
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        // Check state should throw
        do {
            try await breaker.checkState()
            XCTFail("Expected CircuitBreakerOpenError")
        } catch let error as CircuitBreakerOpenError {
            XCTAssertEqual(error.host, "test.example.com")
            XCTAssertEqual(error.port, 11112)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func test_checkState_succeedsWhenClosed() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: .default
        )
        
        do {
            try await breaker.checkState()
            // Success - no exception thrown
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_execute_recordsSuccess() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: .default
        )
        
        let result = try? await breaker.execute {
            return 42
        }
        
        XCTAssertEqual(result, 42)
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.totalSuccesses, 1)
    }
    
    func test_execute_recordsFailure() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 10)
        )
        
        struct TestError: Error {}
        
        do {
            _ = try await breaker.execute {
                throw TestError()
            }
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.totalFailures, 1)
    }
    
    func test_execute_failsImmediatelyWhenOpen() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 1, resetTimeout: 300)
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        // Verify the circuit is open
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .open)
        
        do {
            _ = try await breaker.execute { () -> String in
                // This closure should never execute
                return "success"
            }
            XCTFail("Expected CircuitBreakerOpenError")
        } catch is CircuitBreakerOpenError {
            // Expected - circuit is open so it should fail fast
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func test_reset_returnsToClosed() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 1)
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        var stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .open)
        
        // Reset
        await breaker.reset()
        
        stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed)
    }
    
    func test_forceOpen_tripsCircuit() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: .default
        )
        
        await breaker.forceOpen()
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .open)
    }
    
    func test_forceClose_closesCircuit() async {
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(failureThreshold: 1)
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        await breaker.forceClose()
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed)
    }
    
    func test_halfOpen_afterResetTimeout() async {
        let resetTimeout: TimeInterval = 0.2
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 1,
                resetTimeout: resetTimeout
            )
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        var stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .open)
        
        // Capture the opened time
        let openedAt = stats.lastOpenedAt!
        
        // Wait much longer than reset timeout
        try? await Task.sleep(for: .seconds(1))
        
        // Calculate how long we actually waited
        let actualWait = Date().timeIntervalSince(openedAt)
        XCTAssertGreaterThan(actualWait, resetTimeout, "Wait time \(actualWait) should exceed reset timeout \(resetTimeout)")
        
        // Check state should now transition to half-open
        do {
            try await breaker.checkState()
        } catch let error as CircuitBreakerOpenError {
            XCTFail("Circuit should have transitioned to half-open after \(actualWait)s, but is still open. retryAfter shows: \(error.retryAfter.timeIntervalSinceNow)s")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .halfOpen)
    }
    
    func test_halfOpen_closesAfterSuccesses() async {
        let resetTimeout: TimeInterval = 0.2
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 1,
                successThreshold: 2,
                resetTimeout: resetTimeout
            )
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        // Wait longer than reset timeout
        try? await Task.sleep(for: .seconds(1))
        
        // Transition to half-open
        try? await breaker.checkState()
        
        // Record successes
        await breaker.recordSuccess()
        
        var stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .halfOpen) // Still half-open
        XCTAssertEqual(stats.consecutiveSuccesses, 1)
        
        await breaker.recordSuccess()
        
        stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed) // Now closed
        XCTAssertNotNil(stats.lastClosedAt)
    }
    
    func test_halfOpen_reopensOnFailure() async {
        let resetTimeout: TimeInterval = 0.2
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 1,
                successThreshold: 5, // High threshold
                resetTimeout: resetTimeout
            )
        )
        
        // Trip the circuit
        await breaker.recordFailure()
        
        // Wait longer than reset timeout
        try? await Task.sleep(for: .seconds(1))
        
        // Transition to half-open
        try? await breaker.checkState()
        
        var stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .halfOpen)
        
        // Record some successes
        await breaker.recordSuccess()
        await breaker.recordSuccess()
        
        // Any failure should trip the circuit again
        await breaker.recordFailure()
        
        stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .open)
        XCTAssertEqual(stats.timesOpened, 2)
    }
    
    func test_failureWindow_prunesOldFailures() async {
        let failureWindow: TimeInterval = 0.2
        let breaker = CircuitBreaker(
            host: "test.example.com",
            port: 11112,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                failureWindow: failureWindow
            )
        )
        
        // Record 2 failures
        await breaker.recordFailure()
        await breaker.recordFailure()
        
        // Wait longer than failure window
        try? await Task.sleep(for: .seconds(1))
        
        // Trigger pruning by checking state
        try? await breaker.checkState()
        
        // Record 1 more failure - should not trip because old ones expired
        await breaker.recordFailure()
        
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed)
        XCTAssertEqual(stats.recentFailures, 1) // Only the recent failure counts
    }
}

// MARK: - Circuit Breaker Open Error Tests

final class CircuitBreakerOpenErrorTests: XCTestCase {
    
    func test_errorDescription() {
        let error = CircuitBreakerOpenError(
            host: "pacs.hospital.com",
            port: 11112,
            openedAt: Date(),
            retryAfter: Date().addingTimeInterval(30)
        )
        
        let description = error.description
        XCTAssertTrue(description.contains("pacs.hospital.com"))
        XCTAssertTrue(description.contains("11112"))
        XCTAssertTrue(description.contains("Circuit breaker open"))
    }
}

// MARK: - Circuit Breaker Registry Tests

final class CircuitBreakerRegistryTests: XCTestCase {
    
    func test_registry_createsNewBreaker() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker = await registry.breaker(for: "pacs1.hospital.com", port: 11112)
        
        // Verify by checking statistics instead of accessing properties directly
        let stats = await breaker.statistics()
        XCTAssertEqual(stats.state, .closed)
        XCTAssertEqual(stats.totalSuccesses, 0)
    }
    
    func test_registry_reusesSameBreaker() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker1 = await registry.breaker(for: "pacs.hospital.com", port: 11112)
        let breaker2 = await registry.breaker(for: "pacs.hospital.com", port: 11112)
        
        // Record failure on first reference
        await breaker1.recordFailure()
        
        // Second reference should see the same state
        let stats = await breaker2.statistics()
        XCTAssertEqual(stats.totalFailures, 1)
    }
    
    func test_registry_separateBreakersForDifferentHosts() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker1 = await registry.breaker(for: "pacs1.hospital.com", port: 11112)
        let breaker2 = await registry.breaker(for: "pacs2.hospital.com", port: 11112)
        
        // Record failure on first breaker
        await breaker1.recordFailure()
        
        // Second breaker should not be affected
        let stats1 = await breaker1.statistics()
        let stats2 = await breaker2.statistics()
        
        XCTAssertEqual(stats1.totalFailures, 1)
        XCTAssertEqual(stats2.totalFailures, 0)
    }
    
    func test_registry_separateBreakersForDifferentPorts() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker1 = await registry.breaker(for: "pacs.hospital.com", port: 11112)
        let breaker2 = await registry.breaker(for: "pacs.hospital.com", port: 11113)
        
        // Record failure on first breaker
        await breaker1.recordFailure()
        
        // Second breaker should not be affected
        let stats1 = await breaker1.statistics()
        let stats2 = await breaker2.statistics()
        
        XCTAssertEqual(stats1.totalFailures, 1)
        XCTAssertEqual(stats2.totalFailures, 0)
    }
    
    func test_registry_remove() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker1 = await registry.breaker(for: "pacs.hospital.com", port: 11112)
        await breaker1.recordFailure()
        
        // Remove the breaker
        await registry.remove(host: "pacs.hospital.com", port: 11112)
        
        // Getting the breaker again should create a new one
        let breaker2 = await registry.breaker(for: "pacs.hospital.com", port: 11112)
        let stats = await breaker2.statistics()
        
        XCTAssertEqual(stats.totalFailures, 0) // New breaker, no failures
    }
    
    func test_registry_removeAll() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker1 = await registry.breaker(for: "pacs1.hospital.com", port: 11112)
        let breaker2 = await registry.breaker(for: "pacs2.hospital.com", port: 11112)
        
        await breaker1.recordFailure()
        await breaker2.recordFailure()
        
        // Remove all
        await registry.removeAll()
        
        // Getting all statistics should be empty now
        let allStats = await registry.allStatistics()
        XCTAssertTrue(allStats.isEmpty)
    }
    
    func test_registry_allStatistics() async {
        let registry = CircuitBreakerRegistry(configuration: .default)
        
        let breaker1 = await registry.breaker(for: "pacs1.hospital.com", port: 11112)
        let breaker2 = await registry.breaker(for: "pacs2.hospital.com", port: 11113)
        
        await breaker1.recordSuccess()
        await breaker2.recordFailure()
        
        let allStats = await registry.allStatistics()
        
        XCTAssertEqual(allStats.count, 2)
        XCTAssertEqual(allStats["pacs1.hospital.com:11112"]?.totalSuccesses, 1)
        XCTAssertEqual(allStats["pacs2.hospital.com:11113"]?.totalFailures, 1)
    }
    
    func test_registry_resetAll() async {
        let registry = CircuitBreakerRegistry(
            configuration: CircuitBreakerConfiguration(failureThreshold: 1)
        )
        
        let breaker1 = await registry.breaker(for: "pacs1.hospital.com", port: 11112)
        let breaker2 = await registry.breaker(for: "pacs2.hospital.com", port: 11112)
        
        // Trip both circuits
        await breaker1.recordFailure()
        await breaker2.recordFailure()
        
        var stats1 = await breaker1.statistics()
        var stats2 = await breaker2.statistics()
        XCTAssertEqual(stats1.state, .open)
        XCTAssertEqual(stats2.state, .open)
        
        // Reset all
        await registry.resetAll()
        
        stats1 = await breaker1.statistics()
        stats2 = await breaker2.statistics()
        XCTAssertEqual(stats1.state, .closed)
        XCTAssertEqual(stats2.state, .closed)
    }
}
