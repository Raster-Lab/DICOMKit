import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@main
struct DICOMMWLCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-mwl",
        abstract: "DICOM Modality Worklist Management (MWL C-FIND)",
        discussion: """
            Query and manage DICOM Modality Worklist items. Implements the Modality
            Worklist Information Model (MWL) for querying scheduled procedure steps
            from a worklist SCP server.
            
            URL Format:
              hostname               - PACS server hostname or IP address
              hostname:port          - Hostname with embedded port
              --port port            - Optional explicit port (default: 11112)
            
            Examples:
              # Query worklist for today
              dicom-mwl query server --port 11112 --aet MODALITY --date today
              
              # Query with filters
              dicom-mwl query server:11112 --aet MODALITY \\
                --date 20240315 --station CT1 --patient "DOE^JOHN"
              
              # Filter to only SCHEDULED items
              dicom-mwl query server --port 11112 --aet MODALITY \\
                --sps-status SCHEDULED
              
              # Filter by modality and date with JSON output
              dicom-mwl query 192.168.1.100 --port 11112 --aet MODALITY \\
                --modality CT --date today --json
              
              # Verbose output showing all attributes
              dicom-mwl query server --port 11112 --aet MODALITY \\
                --date today --verbose
            
            SPS Status values: SCHEDULED, IN PROGRESS, DISCONTINUED, COMPLETED
            
            Note: If the server returns a limited number of results, adjust the
            server-side maximum results configuration (e.g., MaximumResults in
            Orthanc, or max_worklist_results in dcm4chee).
            
            Reference: PS3.4 Annex K - Modality Worklist Information Model
            """,
        version: "1.0.0",
        subcommands: [Query.self]
    )
}

// MARK: - Query Subcommand

extension DICOMMWLCommand {
    struct Query: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "query",
            abstract: "Query Modality Worklist (C-FIND)"
        )
        
        @Argument(help: "PACS server hostname or IP address, optionally with port (host:port)")
        var host: String
        
        @Option(name: .long, help: "PACS server port (default: 11112)")
        var port: UInt16?
        
        @Option(name: .long, help: "Local Application Entity Title (calling AE)")
        var aet: String
        
        @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
        var calledAet: String = "ANY-SCP"
        
        @Option(name: .long, help: "Scheduled date filter (YYYYMMDD or 'today', 'tomorrow')")
        var date: String?
        
        @Option(name: .long, help: "Scheduled Station AE Title filter")
        var station: String?
        
        @Option(name: .long, help: "Patient name filter (supports wildcards: *)")
        var patient: String?
        
        @Option(name: .long, help: "Patient ID filter")
        var patientId: String?
        
        @Option(name: .long, help: "Modality filter (e.g., CT, MR, US)")
        var modality: String?
        
        @Option(name: .long, help: "SPS Status filter (SCHEDULED, IN PROGRESS, DISCONTINUED, COMPLETED)")
        var spsStatus: String?
        
        @Option(name: .long, help: "Accession number filter")
        var accessionNumber: String?
        
        @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
        var timeout: Int = 60
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false
        
        mutating func run() async throws {
            #if canImport(Network)
            // Resolve host and port
            let serverInfo = resolveHostPort()
            
            // Verbose header via the SHARED NetworkConsole formatter (DICOMNetwork),
            // printed to STDOUT so its order matches the Studio MWL panel (the parity
            // harness diffs the binary's stdout+stderr against the app). Gated on
            // --verbose (and suppressed in --json mode so the JSON array stays clean).
            if verbose && !json {
                print(NetworkConsole.mwlQueryHeader(
                    host: serverInfo.host, port: serverInfo.port,
                    callingAE: aet, calledAE: calledAet,
                    timeout: timeout, filters: appliedFilters()), terminator: "")
            }

            try await performQuery(serverInfo: serverInfo)
            
            #else
            throw ValidationError("Network functionality is not available on this platform")
            #endif
        }
        
        #if canImport(Network)
        func performQuery(serverInfo: (host: String, port: UInt16)) async throws {
            // Build query keys via the SHARED package builder (DICOMNetwork) — the same
            // mapping DICOMStudio's in-app query and the CLI-parity reference use, so the
            // input→C-FIND mapping cannot drift between the CLI and the app.
            let queryKeys: WorklistQueryKeys
            do {
                queryKeys = try WorklistQueryKeys.forQuery(
                    date: date ?? "",
                    station: station ?? "",
                    patientName: patient ?? "",
                    patientID: patientId ?? "",
                    modality: modality ?? "",
                    spsStatus: spsStatus ?? "",
                    accession: accessionNumber ?? ""
                )
            } catch {
                throw ValidationError((error as? WorklistDateFilterError)?.description ?? "\(error)")
            }

            // Perform query
            let items = try await DICOMModalityWorklistService.find(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                matching: queryKeys,
                timeout: TimeInterval(timeout)
            )

            // Render via the SHARED NetworkConsole formatter (DICOMNetwork) to STDOUT —
            // the IDENTICAL functions the Studio MWL panel uses, so the formatted list,
            // the JSON array, and the result-limit caution cannot drift between sides.
            if json {
                print(NetworkConsole.mwlJSON(items: items), terminator: "")
            } else if items.isEmpty {
                print(NetworkConsole.mwlNoResults(), terminator: "")
            } else {
                print(NetworkConsole.mwlFound(count: items.count), terminator: "")
                for (index, item) in items.enumerated() {
                    print(NetworkConsole.mwlItem(index: index + 1, item: item, verbose: verbose), terminator: "")
                }
                print(NetworkConsole.mwlCompleted(count: items.count), terminator: "")
            }
            // Warn about a likely server-side result limit (heuristic lives in the
            // shared formatter). Suppressed in --json mode to keep the array clean.
            if !json {
                let warning = NetworkConsole.mwlLimitWarning(count: items.count)
                if !warning.isEmpty { print(warning, terminator: "") }
            }
        }
        #endif

        /// Applied, non-empty worklist filters in the canonical order/labels shared
        /// with the Studio MWL header, so the verbose listing is identical on both sides.
        func appliedFilters() -> [(label: String, value: String)] {
            var f: [(String, String)] = []
            func add(_ label: String, _ value: String?) {
                if let v = value, !v.isEmpty { f.append((label, v)) }
            }
            add("Date:", date)
            add("Station AET:", station)
            add("Patient Name:", patient)
            add("Patient ID:", patientId)
            add("Modality:", modality)
            add("SPS Status:", spsStatus)
            add("Accession:", accessionNumber)
            return f
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
}
