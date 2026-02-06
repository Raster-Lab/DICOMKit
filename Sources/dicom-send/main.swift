import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMSend: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-send",
        abstract: "Send DICOM files to PACS using C-STORE protocol",
        discussion: """
            Transfers DICOM files to PACS servers using the C-STORE service.
            Supports single files, multiple files, and recursive directory traversal.
            
            URL Formats:
              pacs://hostname:port     - DICOM C-STORE protocol
            
            Examples:
              dicom-send pacs://server:11112 --aet SENDER file.dcm
              dicom-send pacs://server:11112 --aet SENDER study/ --recursive
              dicom-send pacs://server:11112 --aet SENDER *.dcm --verify
              dicom-send pacs://server:11112 --aet SENDER files/ --recursive --dry-run
              dicom-send pacs://server:11112 --aet SENDER study/ --retry 3 --verbose
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "PACS server URL (pacs://host:port)")
    var url: String
    
    @Argument(help: "DICOM files or directories to send")
    var paths: [String]
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
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
    
    mutating func run() async throws {
        #if canImport(Network)
        // Parse URL
        let serverInfo = try parseServerURL(url)
        
        guard serverInfo.scheme == "pacs" else {
            throw ValidationError("Only pacs:// URLs are supported. STOW-RS support coming soon.")
        }
        
        if verbose {
            fprintln("DICOM Send Tool v1.0.0")
            fprintln("======================")
            fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Priority: \(priority)")
            fprintln("Timeout: \(timeout)s")
            if retry > 0 {
                fprintln("Retry attempts: \(retry)")
            }
            if dryRun {
                fprintln("Mode: DRY RUN (no files will be sent)")
            }
            fprintln("")
        }
        
        // Gather files to send
        let filesToSend = try gatherFiles(from: paths, recursive: recursive)
        
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
            verbose: verbose
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
    
    func gatherFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        
        for path in paths {
            // Handle glob patterns
            let expandedPaths = expandGlobPattern(path)
            
            for expandedPath in expandedPaths {
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
                    if verbose {
                        fprintln("Warning: Path not found: \(expandedPath)")
                    }
                    continue
                }
                
                if isDirectory.boolValue {
                    if recursive {
                        // Recursively find DICOM files
                        let foundFiles = try scanDirectory(expandedPath, recursive: true)
                        files.append(contentsOf: foundFiles)
                    } else {
                        // Only direct children
                        let foundFiles = try scanDirectory(expandedPath, recursive: false)
                        files.append(contentsOf: foundFiles)
                    }
                } else {
                    // Single file
                    files.append(expandedPath)
                }
            }
        }
        
        return files
    }
    
    func expandGlobPattern(_ pattern: String) -> [String] {
        // Simple glob expansion using FileManager
        let fileManager = FileManager.default
        
        // If no wildcards, return as-is
        if !pattern.contains("*") && !pattern.contains("?") {
            return [pattern]
        }
        
        // Split into directory and pattern
        let url = URL(fileURLWithPath: pattern)
        let directory = url.deletingLastPathComponent().path
        let filePattern = url.lastPathComponent
        
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return []
        }
        
        var matches: [String] = []
        for case let item as String in enumerator {
            if matchesPattern(item, pattern: filePattern) {
                matches.append((directory as NSString).appendingPathComponent(item))
            }
        }
        
        return matches
    }
    
    func matchesPattern(_ string: String, pattern: String) -> Bool {
        // Simple pattern matching (* matches any chars, ? matches single char)
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$") else {
            return false
        }
        
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
    
    func scanDirectory(_ path: String, recursive: Bool) throws -> [String] {
        let fileManager = FileManager.default
        var files: [String] = []
        
        if recursive {
            // Use enumerator for recursive scan
            guard let enumerator = fileManager.enumerator(atPath: path) else {
                throw ValidationError("Cannot access directory: \(path)")
            }
            
            for case let item as String in enumerator {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        } else {
            // Only direct children
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        }
        
        return files
    }
    
    func isDICOMFile(_ path: String) -> Bool {
        // Check file extension
        let ext = (path as NSString).pathExtension.lowercased()
        if ["dcm", "dicom", "dic"].contains(ext) {
            return true
        }
        
        // Check for DICM magic bytes
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: 132) else {
            return false
        }
        
        // DICOM files have "DICM" at byte 128
        if data.count >= 132 {
            let magic = data[128..<132]
            return magic == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
        }
        
        return false
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

DICOMSend.main()
