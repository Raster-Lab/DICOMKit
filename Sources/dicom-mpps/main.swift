import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMMPPSCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-mpps",
        abstract: "DICOM Modality Performed Procedure Step (MPPS) operations",
        discussion: """
            Create and update DICOM Modality Performed Procedure Step (MPPS) instances.
            Implements the MPPS SOP Class for notifying PACS/RIS systems about
            procedure execution status.
            
            URL Format:
              pacs://hostname:port     - DICOM MPPS protocol
            
            Examples:
              # Create MPPS (procedure started)
              dicom-mpps create pacs://server:11112 \\
                --aet MODALITY \\
                --study-uid 1.2.3.4.5.6.7.8.9 \\
                --status "IN PROGRESS"
              
              # Update MPPS (procedure completed)
              dicom-mpps update pacs://server:11112 \\
                --aet MODALITY \\
                --mpps-uid 1.2.840.113619.2.xxx \\
                --status COMPLETED
            
            Reference: PS3.4 Annex F - Modality Performed Procedure Step SOP Class
            """,
        version: "1.0.0",
        subcommands: [Create.self, Update.self]
    )
}

// MARK: - Create Subcommand

extension DICOMMPPSCommand {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create MPPS instance (N-CREATE)"
        )
        
        @Argument(help: "PACS server URL (pacs://host:port)")
        var url: String
        
        @Option(name: .long, help: "Local Application Entity Title (calling AE)")
        var aet: String
        
        @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
        var calledAet: String = "ANY-SCP"
        
        @Option(name: .long, help: "Study Instance UID for the procedure")
        var studyUid: String
        
        @Option(name: .long, help: "Initial status (default: IN PROGRESS)")
        var status: String = "IN PROGRESS"
        
        @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
        var timeout: Int = 60
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() async throws {
            #if canImport(Network)
            // Parse URL
            let serverInfo = try parseServerURL(url)
            
            guard serverInfo.scheme == "pacs" else {
                throw ValidationError("Only pacs:// URLs are supported")
            }
            
            // Parse status
            let mppsStatus = try parseStatus(status)
            
            if verbose {
                fprintln("DICOM MPPS Tool v1.0.0")
                fprintln("======================")
                fprintln("Operation: Create (N-CREATE)")
                fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
                fprintln("Calling AE: \(aet)")
                fprintln("Called AE: \(calledAet)")
                fprintln("Study UID: \(studyUid)")
                fprintln("Status: \(mppsStatus.rawValue)")
                fprintln("Timeout: \(timeout)s")
                fprintln("")
            }
            
            // Create MPPS
            let mppsInstanceUID = try await DICOMMPPSService.create(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                studyInstanceUID: studyUid,
                status: mppsStatus,
                timeout: TimeInterval(timeout)
            )
            
            fprintln("✓ MPPS instance created successfully")
            fprintln("  MPPS Instance UID: \(mppsInstanceUID)")
            fprintln("")
            fprintln("Use this UID to update the MPPS when the procedure completes:")
            fprintln("  dicom-mpps update pacs://\(serverInfo.host):\(serverInfo.port) \\")
            fprintln("    --aet \(aet) --mpps-uid \(mppsInstanceUID) --status COMPLETED")
            
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
        
        func parseStatus(_ statusString: String) throws -> MPPSStatus {
            switch statusString.uppercased().replacingOccurrences(of: " ", with: "") {
            case "INPROGRESS", "IN_PROGRESS":
                return .inProgress
            case "COMPLETED":
                return .completed
            case "DISCONTINUED":
                return .discontinued
            default:
                throw ValidationError("Invalid status. Use 'IN PROGRESS', 'COMPLETED', or 'DISCONTINUED'")
            }
        }
    }
}

// MARK: - Update Subcommand

extension DICOMMPPSCommand {
    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update MPPS instance (N-SET)"
        )
        
        @Argument(help: "PACS server URL (pacs://host:port)")
        var url: String
        
        @Option(name: .long, help: "Local Application Entity Title (calling AE)")
        var aet: String
        
        @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
        var calledAet: String = "ANY-SCP"
        
        @Option(name: .long, help: "MPPS SOP Instance UID to update")
        var mppsUid: String
        
        @Option(name: .long, help: "New status (COMPLETED or DISCONTINUED)")
        var status: String
        
        @Option(name: .long, help: "Study Instance UID for referenced images")
        var studyUid: String?
        
        @Option(name: .long, help: "Series Instance UID for referenced images")
        var seriesUid: String?
        
        @Option(name: .long, help: "SOP Instance UID for referenced images (can be repeated)")
        var imageUid: [String] = []
        
        @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
        var timeout: Int = 60
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() async throws {
            #if canImport(Network)
            // Parse URL
            let serverInfo = try parseServerURL(url)
            
            guard serverInfo.scheme == "pacs" else {
                throw ValidationError("Only pacs:// URLs are supported")
            }
            
            // Parse status
            let mppsStatus = try parseStatus(status)
            
            // Validate status
            guard mppsStatus == .completed || mppsStatus == .discontinued else {
                throw ValidationError("Update status must be COMPLETED or DISCONTINUED")
            }
            
            if verbose {
                fprintln("DICOM MPPS Tool v1.0.0")
                fprintln("======================")
                fprintln("Operation: Update (N-SET)")
                fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
                fprintln("Calling AE: \(aet)")
                fprintln("Called AE: \(calledAet)")
                fprintln("MPPS UID: \(mppsUid)")
                fprintln("Status: \(mppsStatus.rawValue)")
                if let study = studyUid, let series = seriesUid {
                    fprintln("Referenced Images: \(imageUid.count) instance(s)")
                }
                fprintln("Timeout: \(timeout)s")
                fprintln("")
            }
            
            // Build referenced SOPs list
            var referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] = []
            if let study = studyUid, let series = seriesUid {
                for imageUID in imageUid {
                    referencedSOPs.append((study, series, imageUID))
                }
            }
            
            // Update MPPS
            try await DICOMMPPSService.update(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                mppsInstanceUID: mppsUid,
                status: mppsStatus,
                referencedSOPs: referencedSOPs,
                timeout: TimeInterval(timeout)
            )
            
            fprintln("✓ MPPS instance updated successfully")
            fprintln("  MPPS Instance UID: \(mppsUid)")
            fprintln("  New Status: \(mppsStatus.rawValue)")
            if !referencedSOPs.isEmpty {
                fprintln("  Referenced Images: \(referencedSOPs.count)")
            }
            
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
        
        func parseStatus(_ statusString: String) throws -> MPPSStatus {
            switch statusString.uppercased().replacingOccurrences(of: " ", with: "") {
            case "INPROGRESS", "IN_PROGRESS":
                return .inProgress
            case "COMPLETED":
                return .completed
            case "DISCONTINUED":
                return .discontinued
            default:
                throw ValidationError("Invalid status. Use 'IN PROGRESS', 'COMPLETED', or 'DISCONTINUED'")
            }
        }
    }
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMMPPSCommand.main()
