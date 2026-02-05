import XCTest
@testable import DICOMKit

final class DICOMBenchmarkTests: XCTestCase {
    func testMeasureSyncOperation() {
        // Test basic synchronous measurement
        let result = DICOMBenchmark.measure(name: "Simple operation") {
            // Simulate some work
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            return sum
        }
        
        XCTAssertEqual(result.name, "Simple operation")
        XCTAssertEqual(result.iterations, 1)
        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertGreaterThan(result.durationMs, 0)
    }
    
    func testMeasureWithIterations() {
        // Test multiple iterations
        let iterations = 10
        let result = DICOMBenchmark.measure(name: "Multiple iterations", iterations: iterations) {
            var sum = 0
            for i in 0..<100 {
                sum += i
            }
            return sum
        }
        
        XCTAssertEqual(result.iterations, iterations)
        XCTAssertGreaterThan(result.averageDuration, 0)
        XCTAssertLessThan(result.averageDuration, result.duration)
    }
    
    func testMeasureWithMemoryTracking() {
        // Test memory tracking
        let result = DICOMBenchmark.measure(name: "Memory test", trackMemory: true) {
            // Allocate some memory
            let data = Data(count: 1024 * 1024) // 1 MB
            return data.count
        }
        
        XCTAssertNotNil(result.peakMemoryUsage)
        XCTAssertNotNil(result.peakMemoryUsageMB)
        if let memUsage = result.peakMemoryUsageMB {
            XCTAssertGreaterThanOrEqual(memUsage, 0)
        }
    }
    
    func testMeasureWithWarmup() {
        // Test warmup iterations
        var counter = 0
        let result = DICOMBenchmark.measure(name: "Warmup test", warmup: 2) {
            counter += 1
        }
        
        // Counter should be 3 (2 warmup + 1 measured)
        XCTAssertEqual(counter, 3)
    }
    
    func testMeasureAsyncOperation() async {
        // Test async measurement
        let result = await DICOMBenchmark.measureAsync(name: "Async operation") {
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return 42
        }
        
        XCTAssertEqual(result.name, "Async operation")
        XCTAssertGreaterThan(result.durationMs, 0)
    }
    
    func testBenchmarkComparison() {
        // Test benchmark comparison
        let baseline = DICOMBenchmark.measure(name: "Baseline") {
            var sum = 0
            for i in 0..<10000 {
                sum += i * i
            }
            return sum
        }
        
        let optimized = DICOMBenchmark.measure(name: "Optimized") {
            var sum = 0
            for i in 0..<5000 {
                sum += i * i
            }
            return sum
        }
        
        let comparison = BenchmarkComparison(baseline: baseline, optimized: optimized)
        
        // Optimized should be faster (roughly 2x)
        XCTAssertGreaterThan(comparison.speedImprovement, 1.0)
        XCTAssertGreaterThan(comparison.speedImprovementPercent, 0)
        
        // Check description format
        let description = comparison.description
        XCTAssertTrue(description.contains("Baseline"))
        XCTAssertTrue(description.contains("improvement"))
    }
    
    func testBenchmarkComparisonWithMemory() {
        let baseline = DICOMBenchmark.measure(name: "Baseline", trackMemory: true) {
            let data = Data(count: 2 * 1024 * 1024) // 2 MB
            return data.count
        }
        
        let optimized = DICOMBenchmark.measure(name: "Optimized", trackMemory: true) {
            let data = Data(count: 1024 * 1024) // 1 MB
            return data.count
        }
        
        let comparison = BenchmarkComparison(baseline: baseline, optimized: optimized)
        
        XCTAssertNotNil(comparison.memoryImprovement)
        if let memImp = comparison.memoryImprovementPercent {
            // Optimized should use less memory (roughly 50% reduction)
            XCTAssertGreaterThan(memImp, 0)
        }
    }
}
