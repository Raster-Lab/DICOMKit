import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMEcho: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-echo",
        abstract: "Test DICOM connectivity using C-ECHO (verification service)",
        discussion: """
            Performs DICOM C-ECHO verification to test connectivity with PACS servers.
            This is the simplest DICOM network operation and is useful for testing
            connectivity, network configuration, and PACS server availability.
            
            URL Format:
              pacs://hostname:port     - DICOM C-ECHO protocol
            
            Examples:
              dicom-echo pacs://server:11112 --aet TEST_SCU
              dicom-echo pacs://server:11112 --aet TEST_SCU --count 10 --stats
              dicom-echo pacs://server:11112 --aet TEST_SCU --verbose
              dicom-echo pacs://server:11112 --aet TEST_SCU --diagnose
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "PACS server URL (pacs://host:port)")
    var url: String
    
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
        // Parse URL
        let serverInfo = try parseServerURL(url)
        
        guard serverInfo.scheme == "pacs" else {
            throw ValidationError("Only pacs:// URLs are supported")
        }
        
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
    func runEcho(serverInfo: (scheme: String, host: String, port: UInt16)) async throws {
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
    
    func runDiagnostics(serverInfo: (scheme: String, host: String, port: UInt16)) async throws {
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
    
    func parseServerURL(_ urlString: String) throws -> (scheme: String, host: String, port: UInt16) {
        guard let url = URL(string: urlString) else {
            throw ValidationError("Invalid URL: \(urlString)")
        }
        
        guard let scheme = url.scheme, scheme == "pacs" else {
            throw ValidationError("URL must use pacs:// scheme")
        }
        
        guard let host = url.host else {
            throw ValidationError("URL must include a hostname")
        }
        
        let port: UInt16
        if let urlPort = url.port {
            port = UInt16(urlPort)
        } else {
            port = 104 // DICOM default port
        }
        
        return (scheme, host, port)
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMEcho.main()
