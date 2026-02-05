import Foundation

#if canImport(CoreFoundation)
import CoreFoundation
#endif

#if canImport(Darwin)
import Darwin
#endif

/// Benchmark result for a single measurement
public struct BenchmarkResult: Sendable {
    /// Name of the benchmark
    public let name: String
    
    /// Duration in seconds
    public let duration: TimeInterval
    
    /// Peak memory usage in bytes
    public let peakMemoryUsage: Int64?
    
    /// Number of iterations
    public let iterations: Int
    
    /// Average duration per iteration in seconds
    public var averageDuration: TimeInterval {
        duration / Double(iterations)
    }
    
    /// Duration in milliseconds
    public var durationMs: Double {
        duration * 1000.0
    }
    
    /// Average duration per iteration in milliseconds
    public var averageDurationMs: Double {
        averageDuration * 1000.0
    }
    
    /// Peak memory usage in megabytes
    public var peakMemoryUsageMB: Double? {
        guard let bytes = peakMemoryUsage else { return nil }
        return Double(bytes) / (1024.0 * 1024.0)
    }
    
    public init(
        name: String,
        duration: TimeInterval,
        peakMemoryUsage: Int64? = nil,
        iterations: Int = 1
    ) {
        self.name = name
        self.duration = duration
        self.peakMemoryUsage = peakMemoryUsage
        self.iterations = iterations
    }
}

/// Benchmark harness for measuring DICOM operations performance
public struct DICOMBenchmark {
    /// Measures the execution time of a synchronous operation
    ///
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of times to run the operation (default: 1)
    ///   - warmup: Number of warmup iterations before measurement (default: 0)
    ///   - trackMemory: Whether to track peak memory usage (default: false)
    ///   - operation: The operation to benchmark
    /// - Returns: Benchmark result with timing information
    public static func measure<T>(
        name: String,
        iterations: Int = 1,
        warmup: Int = 0,
        trackMemory: Bool = false,
        operation: () throws -> T
    ) rethrows -> BenchmarkResult {
        // Warmup runs
        for _ in 0..<warmup {
            _ = try operation()
        }
        
        // Memory tracking setup
        var initialMemory: Int64 = 0
        var peakMemory: Int64 = 0
        if trackMemory {
            initialMemory = currentMemoryUsage()
        }
        
        // Measure iterations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try operation()
            
            if trackMemory {
                let currentMemory = currentMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        let memoryDelta = trackMemory ? (peakMemory - initialMemory) : nil
        
        return BenchmarkResult(
            name: name,
            duration: duration,
            peakMemoryUsage: memoryDelta,
            iterations: iterations
        )
    }
    
    /// Measures the execution time of an asynchronous operation
    ///
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of times to run the operation (default: 1)
    ///   - warmup: Number of warmup iterations before measurement (default: 0)
    ///   - trackMemory: Whether to track peak memory usage (default: false)
    ///   - operation: The async operation to benchmark
    /// - Returns: Benchmark result with timing information
    public static func measureAsync<T>(
        name: String,
        iterations: Int = 1,
        warmup: Int = 0,
        trackMemory: Bool = false,
        operation: () async throws -> T
    ) async rethrows -> BenchmarkResult {
        // Warmup runs
        for _ in 0..<warmup {
            _ = try await operation()
        }
        
        // Memory tracking setup
        var initialMemory: Int64 = 0
        var peakMemory: Int64 = 0
        if trackMemory {
            initialMemory = currentMemoryUsage()
        }
        
        // Measure iterations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try await operation()
            
            if trackMemory {
                let currentMemory = currentMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        let memoryDelta = trackMemory ? (peakMemory - initialMemory) : nil
        
        return BenchmarkResult(
            name: name,
            duration: duration,
            peakMemoryUsage: memoryDelta,
            iterations: iterations
        )
    }
    
    /// Gets the current memory usage of the process
    ///
    /// - Returns: Memory usage in bytes
    private static func currentMemoryUsage() -> Int64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0
        }
        
        return Int64(info.resident_size)
        #else
        // Memory tracking not available on this platform
        return 0
        #endif
    }
}

/// Comparison result between two benchmarks
public struct BenchmarkComparison: Sendable {
    /// Baseline result
    public let baseline: BenchmarkResult
    
    /// Optimized result
    public let optimized: BenchmarkResult
    
    /// Speed improvement factor (positive = faster, negative = slower)
    public var speedImprovement: Double {
        baseline.averageDuration / optimized.averageDuration
    }
    
    /// Speed improvement percentage
    public var speedImprovementPercent: Double {
        (speedImprovement - 1.0) * 100.0
    }
    
    /// Memory improvement factor (positive = less memory, negative = more memory)
    public var memoryImprovement: Double? {
        guard let baselineMem = baseline.peakMemoryUsage,
              let optimizedMem = optimized.peakMemoryUsage else {
            return nil
        }
        return Double(baselineMem) / Double(optimizedMem)
    }
    
    /// Memory improvement percentage
    public var memoryImprovementPercent: Double? {
        guard let improvement = memoryImprovement else {
            return nil
        }
        return (improvement - 1.0) * 100.0
    }
    
    public init(baseline: BenchmarkResult, optimized: BenchmarkResult) {
        self.baseline = baseline
        self.optimized = optimized
    }
    
    /// Formats the comparison as a human-readable string
    public var description: String {
        var result = "Benchmark Comparison: \(baseline.name)\n"
        result += "  Baseline: \(String(format: "%.2f", baseline.averageDurationMs))ms"
        if let mem = baseline.peakMemoryUsageMB {
            result += " (\(String(format: "%.2f", mem))MB)"
        }
        result += "\n"
        result += "  Optimized: \(String(format: "%.2f", optimized.averageDurationMs))ms"
        if let mem = optimized.peakMemoryUsageMB {
            result += " (\(String(format: "%.2f", mem))MB)"
        }
        result += "\n"
        result += "  Speed: \(String(format: "%.1f", speedImprovementPercent))% improvement"
        if let memImp = memoryImprovementPercent {
            result += "\n"
            result += "  Memory: \(String(format: "%.1f", memImp))% reduction"
        }
        return result
    }
}
