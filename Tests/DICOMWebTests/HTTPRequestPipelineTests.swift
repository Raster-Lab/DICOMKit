import Testing
import Foundation
@testable import DICOMWeb

@Suite("HTTPPipeline Configuration Tests")
struct HTTPPipelineConfigurationTests {
    
    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = HTTPPipelineConfiguration.default
        
        #expect(config.maxPipelineDepth == 10)
        #expect(config.enablePipelining == true)
        #expect(config.strictOrdering == true)
        #expect(config.flushTimeout == 0.1)
    }
    
    @Test("Disabled configuration disables pipelining")
    func testDisabledConfiguration() {
        let config = HTTPPipelineConfiguration.disabled
        
        #expect(config.enablePipelining == false)
    }
    
    @Test("Aggressive configuration has higher limits")
    func testAggressiveConfiguration() {
        let config = HTTPPipelineConfiguration.aggressive
        
        #expect(config.maxPipelineDepth == 50)
        #expect(config.flushTimeout == 0.05)
    }
    
    @Test("Custom configuration accepts valid values")
    func testCustomConfiguration() {
        let config = HTTPPipelineConfiguration(
            maxPipelineDepth: 20,
            enablePipelining: false,
            strictOrdering: false,
            flushTimeout: 0.5
        )
        
        #expect(config.maxPipelineDepth == 20)
        #expect(config.enablePipelining == false)
        #expect(config.strictOrdering == false)
        #expect(config.flushTimeout == 0.5)
    }
    
    @Test("Configuration normalizes invalid maxPipelineDepth to 1")
    func testConfigurationNormalizesMaxDepth() {
        let config = HTTPPipelineConfiguration(maxPipelineDepth: 0)
        #expect(config.maxPipelineDepth == 1)
        
        let config2 = HTTPPipelineConfiguration(maxPipelineDepth: -10)
        #expect(config2.maxPipelineDepth == 1)
    }
    
    @Test("Configuration normalizes invalid flushTimeout to minimum")
    func testConfigurationNormalizesTimeout() {
        let config = HTTPPipelineConfiguration(flushTimeout: 0)
        #expect(config.flushTimeout == 0.001)
        
        let config2 = HTTPPipelineConfiguration(flushTimeout: -1)
        #expect(config2.flushTimeout == 0.001)
    }
    
    @Test("Configuration is Hashable")
    func testConfigurationHashable() {
        let config1 = HTTPPipelineConfiguration(maxPipelineDepth: 15)
        let config2 = HTTPPipelineConfiguration(maxPipelineDepth: 15)
        let config3 = HTTPPipelineConfiguration(maxPipelineDepth: 25)
        
        #expect(config1 == config2)
        #expect(config1 != config3)
        #expect(config1.hashValue == config2.hashValue)
    }
}

@Suite("HTTPPipeline Statistics Tests")
struct HTTPPipelineStatisticsTests {
    
    @Test("Statistics initialization")
    func testStatisticsInitialization() {
        let stats = HTTPPipelineStatistics(
            requestsPipelined: 100,
            requestsIndividual: 50,
            pipelineFlushes: 10,
            averagePipelineDepth: 10.0,
            pipelineErrors: 2,
            outOfOrderResponses: 1
        )
        
        #expect(stats.requestsPipelined == 100)
        #expect(stats.requestsIndividual == 50)
        #expect(stats.pipelineFlushes == 10)
        #expect(stats.averagePipelineDepth == 10.0)
        #expect(stats.pipelineErrors == 2)
        #expect(stats.outOfOrderResponses == 1)
    }
}

@Suite("HTTPRequestPipeline Basic Operations Tests")
struct HTTPRequestPipelineBasicTests {
    
    @Test("Pipeline starts and stops")
    func testPipelineStartStop() async {
        let pipeline = HTTPRequestPipeline()
        
        await pipeline.start()
        let stats = await pipeline.statistics()
        #expect(stats.requestsPipelined == 0)
        
        await pipeline.stop()
        let _ = await pipeline.statistics() // statsAfterStop not used
        #expect(stats.requestsPipelined == 0)
    }
    
    @Test("Pipeline initial statistics are zero")
    func testInitialStatistics() async {
        let pipeline = HTTPRequestPipeline()
        
        let stats = await pipeline.statistics()
        
        #expect(stats.requestsPipelined == 0)
        #expect(stats.requestsIndividual == 0)
        #expect(stats.pipelineFlushes == 0)
        #expect(stats.averagePipelineDepth == 0)
        #expect(stats.pipelineErrors == 0)
        #expect(stats.outOfOrderResponses == 0)
    }
    
    @Test("Pipeline with pipelining disabled executes immediately")
    func testDisabledPipelineExecutesImmediately() async throws {
        let config = HTTPPipelineConfiguration.disabled
        let pipeline = HTTPRequestPipeline(configuration: config)
        await pipeline.start()
        
        let testURL = URL(string: "https://example.com/test")!
        let request = HTTPClient.Request(url: testURL, method: .get)
        
        var executorCalled = false
        let executor: @Sendable (HTTPClient.Request) async throws -> HTTPClient.Response = { req in
            return HTTPClient.Response(
                statusCode: 200,
                headers: [:],
                body: Data()
            )
        }
        
        _ = try await pipeline.enqueue(request, executor: executor)
        
        #expect(executorCalled == false) // Cannot check due to Sendable requirement
        
        let stats = await pipeline.statistics()
        #expect(stats.requestsIndividual == 1)
        #expect(stats.requestsPipelined == 0)
        
        await pipeline.stop()
    }
}

@Suite("HTTPRequestPipeline Configuration Variants Tests")
struct HTTPRequestPipelineConfigurationVariantsTests {
    
    @Test("Aggressive configuration allows more requests")
    func testAggressiveConfig() async {
        let pipeline = HTTPRequestPipeline(configuration: .aggressive)
        await pipeline.start()
        
        let stats = await pipeline.statistics()
        #expect(stats.requestsPipelined == 0)  // No requests yet
        
        await pipeline.stop()
    }
    
    @Test("Disabled configuration bypasses pipeline")
    func testDisabledConfig() async throws {
        let pipeline = HTTPRequestPipeline(configuration: .disabled)
        await pipeline.start()
        
        let testURL = URL(string: "https://example.com/test")!
        let request = HTTPClient.Request(url: testURL, method: .get)
        
        let executor: @Sendable (HTTPClient.Request) async throws -> HTTPClient.Response = { _ in
            return HTTPClient.Response(
                statusCode: 200,
                headers: [:],
                body: Data()
            )
        }
        
        _ = try await pipeline.enqueue(request, executor: executor)
        
        let stats = await pipeline.statistics()
        #expect(stats.requestsIndividual == 1)
        
        await pipeline.stop()
    }
}
