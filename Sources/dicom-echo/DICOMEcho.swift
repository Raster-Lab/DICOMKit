import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@main
struct DICOMEcho: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-echo",
        abstract: "Test DICOM connectivity using C-ECHO (verification service)",
        discussion: """
            Performs DICOM C-ECHO verification to test connectivity with PACS servers.
            This is the simplest DICOM network operation and is useful for testing
            connectivity, network configuration, and PACS server availability.
            
            The --host option accepts a hostname or IP address, optionally with a
            port suffix (host:port). Use --port to specify the port separately.
            If no port is given, the default is 11112.
            
            Examples:
              dicom-echo --host server --port 11112 --aet TEST_SCU
              dicom-echo --host server:11112 --aet TEST_SCU
              dicom-echo --host server --port 11112 --aet TEST_SCU --called-aet PACS_SCP
              dicom-echo --host 192.168.1.100 --port 11112 --aet TEST_SCU --count 10 --stats
              dicom-echo --host server --port 4242 --aet TEST_SCU --verbose
              dicom-echo --host server --port 11112 --aet TEST_SCU --diagnose
            """,
        version: "1.0.0"
    )
    
    @Option(name: .long, help: "PACS server hostname or IP address (optionally host:port)")
    var host: String
    
    @Option(name: .long, help: "PACS server port (default: 11112)")
    var port: UInt16?
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Option(name: .shortAndLong, help: "Number of echo requests to send (default: 1)")
    var count: Int = 1
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 30)")
    var timeout: Int = 30
    
    @Flag(name: .long, help: "Show statistics (min/avg/max round-trip time)")
    var stats: Bool = false
    
    @Flag(name: .long, help: "Run network diagnostics")
    var diagnose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output including connection details")
    var verbose: Bool = false
    
    mutating func run() async throws {
        #if canImport(Network)
        let serverInfo = resolveHostPort()
        
        // Validate count
        guard count > 0 else {
            throw ValidationError("Count must be greater than 0")
        }
        
        if verbose {
            fprintln("DICOM Echo Tool v1.0.0")
            fprintln("======================")
            fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Timeout: \(timeout)s")
            fprintln("Count: \(count)")
            fprintln("")
        }
        
        if diagnose {
            try await runDiagnostics(serverInfo: serverInfo)
        } else {
            try await runEcho(serverInfo: serverInfo)
        }
        
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }
    
    #if canImport(Network)
    func runEcho(serverInfo: (host: String, port: UInt16)) async throws {
        var results: [VerificationResult] = []
        var successCount = 0
        var failureCount = 0
        
        for i in 1...count {
            if verbose && count > 1 {
                fprintln("[\(i)/\(count)] Sending C-ECHO...")
            }
            
            do {
                let result = try await DICOMVerificationService.echo(
                    host: serverInfo.host,
                    port: serverInfo.port,
                    callingAE: aet,
                    calledAE: calledAet,
                    timeout: TimeInterval(timeout)
                )
                
                results.append(result)
                
                if result.success {
                    successCount += 1
                    if verbose || count == 1 {
                        fprintln("✓ C-ECHO successful")
                        fprintln("  Remote AE: \(result.remoteAETitle)")
                        fprintln("  Status: \(result.status)")
                        fprintln("  Round-trip time: \(String(format: "%.3f", result.roundTripTime))s")
                    } else {
                        print(".", terminator: "")
                        fflush(stdout)
                    }
                } else {
                    failureCount += 1
                    fprintln("✗ C-ECHO failed")
                    fprintln("  Status: \(result.status)")
                }
                
            } catch {
                failureCount += 1
                fprintln("✗ C-ECHO error: \(error)")
            }
            
            // Small delay between requests if count > 1
            if i < count && count > 1 {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        if count > 1 && !verbose {
            print("") // New line after dots
        }
        
        // Print summary
        if count > 1 || stats {
            fprintln("")
            fprintln("Summary:")
            fprintln("  Sent: \(count)")
            fprintln("  Successful: \(successCount)")
            fprintln("  Failed: \(failureCount)")
            fprintln("  Success rate: \(String(format: "%.1f", Double(successCount) / Double(count) * 100))%")
            
            if stats && !results.isEmpty {
                let roundTripTimes = results.filter { $0.success }.map { $0.roundTripTime }
                if !roundTripTimes.isEmpty {
                    let min = roundTripTimes.min()!
                    let max = roundTripTimes.max()!
                    let avg = roundTripTimes.reduce(0, +) / Double(roundTripTimes.count)
                    
                    fprintln("")
                    fprintln("Round-trip time statistics:")
                    fprintln("  Min: \(String(format: "%.3f", min))s")
                    fprintln("  Avg: \(String(format: "%.3f", avg))s")
                    fprintln("  Max: \(String(format: "%.3f", max))s")
                }
            }
        }
        
        // Exit with appropriate code
        if failureCount > 0 {
            throw ExitCode(1)
        }
    }
    
    func runDiagnostics(serverInfo: (host: String, port: UInt16)) async throws {
        fprintln("Running DICOM network diagnostics...")
        fprintln("")
        
        // Test 1: Basic connectivity
        fprintln("Test 1: Basic C-ECHO connectivity")
        fprintln("  Testing connection to \(serverInfo.host):\(serverInfo.port)...")
        
        do {
            let result = try await DICOMVerificationService.echo(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                timeout: TimeInterval(timeout)
            )
            
            if result.success {
                fprintln("  ✓ Basic connectivity: PASS")
                fprintln("    Round-trip time: \(String(format: "%.3f", result.roundTripTime))s")
            } else {
                fprintln("  ✗ Basic connectivity: FAIL")
                fprintln("    Status: \(result.status)")
            }
        } catch {
            fprintln("  ✗ Basic connectivity: ERROR")
            fprintln("    Error: \(error)")
            throw ExitCode(1)
        }
        
        fprintln("")
        
        // Test 2: Multiple requests for stability
        fprintln("Test 2: Connection stability (5 requests)")
        var stableSuccessCount = 0
        var stableRTTs: [TimeInterval] = []
        
        for i in 1...5 {
            do {
                let result = try await DICOMVerificationService.echo(
                    host: serverInfo.host,
                    port: serverInfo.port,
                    callingAE: aet,
                    calledAE: calledAet,
                    timeout: TimeInterval(timeout)
                )
                
                if result.success {
                    stableSuccessCount += 1
                    stableRTTs.append(result.roundTripTime)
                    fprintln("  [\(i)/5] ✓ RTT: \(String(format: "%.3f", result.roundTripTime))s")
                } else {
                    fprintln("  [\(i)/5] ✗ Status: \(result.status)")
                }
            } catch {
                fprintln("  [\(i)/5] ✗ Error: \(error)")
            }
            
            if i < 5 {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms between requests
            }
        }
        
        fprintln("  Connection stability: \(stableSuccessCount)/5 successful")
        
        if !stableRTTs.isEmpty {
            let minRTT = stableRTTs.min()!
            let maxRTT = stableRTTs.max()!
            let avgRTT = stableRTTs.reduce(0, +) / Double(stableRTTs.count)
            let variance = stableRTTs.map { pow($0 - avgRTT, 2) }.reduce(0, +) / Double(stableRTTs.count)
            let stdDev = sqrt(variance)
            
            fprintln("  RTT min/avg/max/stddev: \(String(format: "%.3f", minRTT))/\(String(format: "%.3f", avgRTT))/\(String(format: "%.3f", maxRTT))/\(String(format: "%.3f", stdDev))s")
        }
        
        fprintln("")
        
        // Test 3: Association info
        fprintln("Test 3: Association parameters")
        fprintln("  Implementation Class UID: \(VerificationConfiguration.defaultImplementationClassUID)")
        fprintln("  Implementation Version: \(VerificationConfiguration.defaultImplementationVersionName ?? "N/A")")
        fprintln("  SOP Class: Verification (1.2.840.10008.1.1)")
        fprintln("  Transfer Syntaxes: Explicit VR Little Endian, Implicit VR Little Endian")
        
        fprintln("")
        fprintln("Diagnostics complete.")
        
        if stableSuccessCount == 5 {
            fprintln("Result: All tests PASSED ✓")
        } else if stableSuccessCount > 0 {
            fprintln("Result: Partial success (some tests failed) ⚠")
            throw ExitCode(1)
        } else {
            fprintln("Result: All tests FAILED ✗")
            throw ExitCode(1)
        }
    }
    #endif
    
    /// Resolves the final host and port from ``--host`` and ``--port`` options.
    /// If ``--host`` contains a colon-separated port (e.g. "server:4242"),
    /// that embedded port is used unless ``--port`` is explicitly provided.
    /// Default port is 11112.
    func resolveHostPort() -> (host: String, port: UInt16) {
        var resolvedHost = host
        var resolvedPort: UInt16 = port ?? 11112

        // Strip pacs:// prefix if provided for backward compatibility
        if resolvedHost.hasPrefix("pacs://") {
            resolvedHost = String(resolvedHost.dropFirst(7))
        }

        // Check if host contains embedded port (e.g., "server:4242")
        if let lastColon = resolvedHost.lastIndex(of: ":") {
            let portString = String(resolvedHost[resolvedHost.index(after: lastColon)...])
            if let embeddedPort = UInt16(portString) {
                resolvedHost = String(resolvedHost[..<lastColon])
                if port == nil {
                    resolvedPort = embeddedPort
                }
            }
        }

        return (resolvedHost, resolvedPort)
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
