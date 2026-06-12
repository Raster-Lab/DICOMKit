import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@main
struct DICOMSend: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-send",
        abstract: "Send DICOM files to PACS using C-STORE protocol",
        discussion: """
            Transfers DICOM files to PACS servers using the C-STORE service.
            Supports single files, multiple files, and recursive directory traversal.
            
            The host argument accepts a hostname or IP address, optionally with a
            port suffix (host:port). Use --port to specify the port separately.
            If no port is given, the default is 11112.
            
            Examples:
              dicom-send server --port 11112 --aet SENDER file.dcm
              dicom-send server:11112 --aet SENDER study/ --recursive
              dicom-send server --port 11112 --aet SENDER *.dcm --verify
              dicom-send 192.168.1.100 --port 11112 --aet SENDER files/ --recursive --dry-run
              dicom-send server --port 11112 --aet SENDER study/ --retry 3 --verbose
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "PACS server hostname or IP address, optionally with port (host:port)")
    var host: String
    
    @Option(name: .long, help: "PACS server port (default: 11112)")
    var port: UInt16?
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Argument(help: "DICOM files or directories to send")
    var paths: [String]
    
    @Flag(name: .shortAndLong, help: "Recursively scan directories for DICOM files")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Verify connection with C-ECHO before sending")
    var verify: Bool = false
    
    @Option(name: .long, help: "Number of retry attempts on failure (default: 0)")
    var retry: Int = 0
    
    @Flag(name: .long, help: "Show what would be sent without actually sending")
    var dryRun: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output including progress")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
    var timeout: Int = 60
    
    @Option(name: .long, help: "Operation priority: low, medium, high (default: medium)")
    var priority: PriorityOption = .medium

    @Option(name: .long, help: "Preferred transfer syntax for C-STORE presentation context negotiation (for example explicit-vr-le, jpeg2000, htj2k-lossless, htj2k-rpcl, htj2k, rle-lossless)")
    var transferSyntax: String?

    mutating func run() async throws {
        #if canImport(Network)
        let serverInfo = resolveHostPort()

        let preferredTransferSyntaxUID: String?
        if let transferSyntax, !transferSyntax.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let syntax = TransferSyntax.parse(transferSyntax) else {
                throw ValidationError("Unknown transfer syntax: \(transferSyntax)")
            }
            preferredTransferSyntaxUID = syntax.uid
        } else {
            preferredTransferSyntaxUID = nil
        }
        
        if verbose {
            fprintln("DICOM Send Tool v1.0.0")
            fprintln("======================")
            fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Priority: \(priority)")
            fprintln("Timeout: \(timeout)s")
            if let ts = preferredTransferSyntaxUID {
                fprintln("Transfer Syntax: \(ts) (preferred in presentation context)")
            }
            if retry > 0 {
                fprintln("Retry attempts: \(retry)")
            }
            if dryRun {
                fprintln("Mode: DRY RUN (no files will be sent)")
            }
            fprintln("")
        }
        
        // Gather files to send. Uses the SHARED DICOMSendFileGatherer (DICOMNetwork)
        // so the CLI and the CLI-parity reference enumerate a directory identically.
        let filesToSend = DICOMSendFileGatherer.gather(
            paths: paths, recursive: recursive,
            warn: verbose ? { fprintln("Warning: \($0)") } : nil)
        
        if filesToSend.isEmpty {
            throw ValidationError("No DICOM files found to send")
        }
        
        if verbose || dryRun {
            fprintln("Found \(filesToSend.count) file(s) to send")
            if verbose {
                for (index, path) in filesToSend.enumerated() {
                    fprintln("  [\(index + 1)] \(path)")
                }
                fprintln("")
            }
        }
        
        if dryRun {
            fprintln("Dry run complete. Use without --dry-run to send files.")
            return
        }
        
        // Create executor
        let executor = SendExecutor(
            host: serverInfo.host,
            port: serverInfo.port,
            callingAE: aet,
            calledAE: calledAet,
            timeout: TimeInterval(timeout),
            priority: priority.dimseValue,
            retryAttempts: retry,
            verbose: verbose,
            preferredTransferSyntaxUID: preferredTransferSyntaxUID
        )
        
        // Verify connection if requested
        if verify {
            if verbose {
                fprintln("Verifying connection with C-ECHO...")
            }
            try await executor.verifyConnection()
            if verbose {
                fprintln("✓ Connection verified\n")
            }
        }
        
        // Send files
        try await executor.sendFiles(filesToSend)
        
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }
    
    /// Resolves the final host and port from ``--host`` and ``--port`` options.
    func resolveHostPort() -> (host: String, port: UInt16) {
        var resolvedHost = host
        var resolvedPort: UInt16 = port ?? 11112

        if resolvedHost.hasPrefix("pacs://") {
            resolvedHost = String(resolvedHost.dropFirst(7))
        }

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

enum PriorityOption: String, ExpressibleByArgument {
    case low
    case medium
    case high
    
    var dimseValue: DIMSEPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}
