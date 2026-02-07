import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, *)
struct DICOMQR: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-qr",
        abstract: "Integrated DICOM query-retrieve tool",
        discussion: """
            Performs integrated C-FIND query and C-MOVE/C-GET retrieval operations.
            Provides both interactive and automatic modes for seamless workflow.
            
            Interactive Mode:
              Query PACS, display results, and interactively select studies to retrieve.
            
            Automatic Mode:
              Query PACS and automatically retrieve all matching studies.
            
            Resume Mode:
              Resume interrupted retrievals from saved state.
            
            Examples:
              # Interactive query and retrieve
              dicom-qr pacs://server:11112 \\
                --aet MY_AET \\
                --move-dest MY_SCP \\
                --patient-name "DOE*" \\
                --interactive
              
              # Automatic query and retrieve
              dicom-qr pacs://server:11112 \\
                --aet MY_AET \\
                --move-dest MY_SCP \\
                --study-date "20240101-20240131" \\
                --modality CT \\
                --output studies/ \\
                --auto
              
              # Query, review, then retrieve
              dicom-qr pacs://server:11112 \\
                --aet MY_AET \\
                --patient-id "12345" \\
                --review \\
                --save-state query.state
              
              # Resume interrupted retrieval
              dicom-qr resume --state retrieval.state
            """,
        version: "1.2.3",
        subcommands: [
            Query.self,
            Resume.self
        ],
        defaultSubcommand: Query.self
    )
}

// MARK: - Query Subcommand

extension DICOMQR {
    struct Query: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "query",
            abstract: "Query and retrieve DICOM studies"
        )
        
        @Argument(help: "PACS server URL (pacs://host:port)")
        var url: String
        
        @Option(name: .long, help: "Local Application Entity Title (calling AE)")
        var aet: String
        
        @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
        var calledAet: String = "ANY-SCP"
        
        @Option(name: .long, help: "Move destination AE title (required for C-MOVE)")
        var moveDest: String?
        
        @Option(name: .long, help: "Retrieval method: c-move or c-get (default: c-move)")
        var method: String = "c-move"
        
        // Query parameters
        @Option(name: .long, help: "Patient name (wildcards * and ? supported)")
        var patientName: String?
        
        @Option(name: .long, help: "Patient ID")
        var patientId: String?
        
        @Option(name: .long, help: "Study date or range (YYYYMMDD or YYYYMMDD-YYYYMMDD)")
        var studyDate: String?
        
        @Option(name: .long, help: "Study Instance UID")
        var studyUid: String?
        
        @Option(name: .long, help: "Accession Number")
        var accessionNumber: String?
        
        @Option(name: .long, help: "Modality (e.g., CT, MR, US)")
        var modality: String?
        
        @Option(name: .long, help: "Study description (wildcards supported)")
        var studyDescription: String?
        
        // Output options
        @Option(name: .shortAndLong, help: "Output directory for retrieved files")
        var output: String = "."
        
        @Flag(name: .long, help: "Organize files hierarchically (Patient/Study/Series)")
        var hierarchical: Bool = false
        
        // Mode options
        @Flag(name: .long, help: "Interactive mode - select studies to retrieve")
        var interactive: Bool = false
        
        @Flag(name: .long, help: "Automatic mode - retrieve all matching studies")
        var auto: Bool = false
        
        @Flag(name: .long, help: "Review mode - query only, save state for later")
        var review: Bool = false
        
        @Option(name: .long, help: "Save query/retrieval state to file")
        var saveState: String?
        
        // Additional options
        @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
        var timeout: Int = 60
        
        @Option(name: .long, help: "Maximum concurrent retrievals (default: 1)")
        var parallel: Int = 1
        
        @Flag(name: .long, help: "Validate retrieved files")
        var validate: Bool = false
        
        @Flag(name: .long, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() async throws {
            #if canImport(Network)
            // Validate mode selection
            let modeCount = [interactive, auto, review].filter { $0 }.count
            if modeCount == 0 {
                throw ValidationError("Must specify one of: --interactive, --auto, or --review")
            }
            if modeCount > 1 {
                throw ValidationError("Cannot specify multiple modes (--interactive, --auto, --review)")
            }
            
            // Validate retrieval method
            let retrievalMethod: RetrievalMethod
            switch method.lowercased() {
            case "c-move":
                retrievalMethod = .cMove
                guard moveDest != nil else {
                    throw ValidationError("--move-dest is required for C-MOVE method")
                }
            case "c-get":
                retrievalMethod = .cGet
            default:
                throw ValidationError("Invalid method: \(method). Use c-move or c-get")
            }
            
            // Parse server URL
            let serverInfo = try parseServerURL(url)
            
            if verbose {
                print("Query-Retrieve Configuration:")
                print("  Server: \(serverInfo.host):\(serverInfo.port)")
                print("  Calling AET: \(aet)")
                print("  Called AET: \(calledAet)")
                print("  Method: \(method)")
                if let dest = moveDest {
                    print("  Move Dest: \(dest)")
                }
                print("  Output: \(output)")
                print("  Mode: \(interactive ? "Interactive" : auto ? "Automatic" : "Review")")
                print("")
            }
            
            // Build query keys
            let queryKeys = buildQueryKeys()
            
            // Execute query
            if verbose {
                print("Executing C-FIND query...")
            }
            
            let queryExecutor = QueryExecutor(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                timeout: TimeInterval(timeout)
            )
            
            let results = try await queryExecutor.executeQuery(level: .study, queryKeys: queryKeys)
            
            if results.isEmpty {
                print("No studies found matching the query criteria.")
                return
            }
            
            print("Found \(results.count) studies")
            print("")
            
            // Display results
            displayResults(results)
            
            // Handle different modes
            if review {
                // Review mode - just display and optionally save
                if let statePath = saveState {
                    try saveQueryState(results: results, path: statePath)
                    print("")
                    print("Query state saved to: \(statePath)")
                    print("To retrieve later, use: dicom-qr resume --state \(statePath)")
                }
                return
            }
            
            // Determine which studies to retrieve
            let studiesToRetrieve: [GenericQueryResult]
            if interactive {
                studiesToRetrieve = try selectStudiesInteractively(results)
            } else {
                studiesToRetrieve = results
            }
            
            if studiesToRetrieve.isEmpty {
                print("No studies selected for retrieval.")
                return
            }
            
            print("")
            print("Retrieving \(studiesToRetrieve.count) studies...")
            print("")
            
            // Create retrieve executor
            let retrieveExecutor = RetrieveExecutor(
                host: serverInfo.host,
                port: serverInfo.port,
                callingAE: aet,
                calledAE: calledAet,
                moveDestination: moveDest,
                timeout: TimeInterval(timeout),
                outputPath: output,
                hierarchical: hierarchical,
                verbose: verbose
            )
            
            // Save state if requested before retrieval
            if let statePath = saveState {
                try saveRetrievalState(
                    studies: studiesToRetrieve,
                    host: serverInfo.host,
                    port: serverInfo.port,
                    callingAE: aet,
                    calledAE: calledAet,
                    moveDestination: moveDest,
                    method: retrievalMethod,
                    outputPath: output,
                    hierarchical: hierarchical,
                    path: statePath
                )
            }
            
            // Execute retrievals
            var successCount = 0
            var failureCount = 0
            
            for (index, result) in studiesToRetrieve.enumerated() {
                guard let studyUID = result.studyInstanceUID else {
                    print("[\(index + 1)/\(studiesToRetrieve.count)] ⚠️  Missing Study UID")
                    failureCount += 1
                    continue
                }
                
                print("[\(index + 1)/\(studiesToRetrieve.count)] Retrieving: \(studyUID)")
                
                do {
                    try await retrieveExecutor.retrieveStudy(studyUID: studyUID, method: retrievalMethod)
                    successCount += 1
                    print("  ✅ Success")
                } catch {
                    failureCount += 1
                    print("  ❌ Failed: \(error.localizedDescription)")
                }
                
                print("")
            }
            
            // Print summary
            print("Retrieval Summary:")
            print("  Total: \(studiesToRetrieve.count)")
            print("  Success: \(successCount)")
            print("  Failed: \(failureCount)")
            
            if validate && successCount > 0 {
                print("")
                print("Validating retrieved files...")
                try validateRetrievedFiles(in: output)
            }
            #else
            print("Error: Network operations not supported on this platform")
            throw ExitCode(1)
            #endif
        }
        
        // MARK: - Helper Methods
        
        private func buildQueryKeys() -> QueryKeys {
            var keys = QueryKeys(level: .study)
            
            if let name = patientName {
                keys = keys.patientName(name)
            }
            if let id = patientId {
                keys = keys.patientID(id)
            }
            if let date = studyDate {
                keys = keys.studyDate(date)
            }
            if let uid = studyUid {
                keys = keys.studyInstanceUID(uid)
            }
            if let accession = accessionNumber {
                keys = keys.accessionNumber(accession)
            }
            if let mod = modality {
                keys = keys.modality(mod)
            }
            if let desc = studyDescription {
                keys = keys.studyDescription(desc)
            }
            
            return keys
        }
        
        private func displayResults(_ results: [GenericQueryResult]) {
            print("Studies:")
            print("─────────────────────────────────────────────────────────────────")
            for (index, result) in results.enumerated() {
                print("[\(index + 1)] \(result.patientName ?? "Unknown") (ID: \(result.patientID ?? "N/A"))")
                print("    Study: \(result.studyDescription ?? "No description")")
                print("    Date: \(result.studyDate ?? "N/A")  Modality: \(result.modality ?? "N/A")")
                if let uid = result.studyInstanceUID {
                    print("    UID: \(uid)")
                }
                if let accession = result.accessionNumber {
                    print("    Accession: \(accession)")
                }
            }
            print("─────────────────────────────────────────────────────────────────")
        }
        
        private func selectStudiesInteractively(_ results: [GenericQueryResult]) throws -> [GenericQueryResult] {
            print("")
            print("Enter study numbers to retrieve (comma-separated, or 'all'):")
            print("Examples: 1,3,5  or  all  or  1-5")
            print("")
            print("> ", terminator: "")
            
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
                return []
            }
            
            if input.lowercased() == "all" {
                return results
            }
            
            var selectedIndices = Set<Int>()
            let parts = input.components(separatedBy: ",")
            
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                
                // Handle ranges (e.g., "1-5")
                if trimmed.contains("-") {
                    let rangeParts = trimmed.components(separatedBy: "-")
                    if rangeParts.count == 2,
                       let start = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
                       let end = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)) {
                        for i in start...end {
                            if i >= 1 && i <= results.count {
                                selectedIndices.insert(i - 1)
                            }
                        }
                    }
                } else if let index = Int(trimmed) {
                    if index >= 1 && index <= results.count {
                        selectedIndices.insert(index - 1)
                    }
                }
            }
            
            return selectedIndices.sorted().map { results[$0] }
        }
        
        private func saveQueryState(results: [GenericQueryResult], path: String) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let studies = results.map { QueryState.StudyInfo(from: $0) }
            let state = QueryState(studies: studies)
            let data = try encoder.encode(state)
            try data.write(to: URL(fileURLWithPath: path))
        }
        
        private func saveRetrievalState(
            studies: [GenericQueryResult],
            host: String,
            port: UInt16,
            callingAE: String,
            calledAE: String,
            moveDestination: String?,
            method: RetrievalMethod,
            outputPath: String,
            hierarchical: Bool,
            path: String
        ) throws {
            let studyInfos = studies.map { QueryState.StudyInfo(from: $0) }
            let state = RetrievalState(
                studies: studyInfos,
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                moveDestination: moveDestination,
                method: method,
                outputPath: outputPath,
                hierarchical: hierarchical
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: URL(fileURLWithPath: path))
        }
        
        private func validateRetrievedFiles(in directory: String) throws {
            let fileManager = FileManager.default
            let dirURL = URL(fileURLWithPath: directory)
            
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                print("  ⚠️  Cannot enumerate directory")
                return
            }
            
            var validCount = 0
            var invalidCount = 0
            
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                
                // Skip non-DICOM files
                guard fileURL.pathExtension.lowercased() == "dcm" || fileURL.pathExtension.isEmpty else {
                    continue
                }
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    _ = try DICOMFile.read(from: data)
                    validCount += 1
                } catch {
                    invalidCount += 1
                    print("  ⚠️  Invalid file: \(fileURL.lastPathComponent)")
                }
            }
            
            print("  Validation: \(validCount) valid, \(invalidCount) invalid")
        }
    }
}

// MARK: - Resume Subcommand

extension DICOMQR {
    struct Resume: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "resume",
            abstract: "Resume interrupted retrieval from saved state"
        )
        
        @Option(name: .shortAndLong, help: "Path to saved state file")
        var state: String
        
        @Flag(name: .long, help: "Show verbose output")
        var verbose: Bool = false
        
        mutating func run() async throws {
            #if canImport(Network)
            print("Loading retrieval state from: \(state)")
            
            let data = try Data(contentsOf: URL(fileURLWithPath: state))
            let decoder = JSONDecoder()
            let retrievalState = try decoder.decode(RetrievalState.self, from: data)
            
            print("Resuming retrieval of \(retrievalState.studies.count) studies")
            print("")
            
            // Create retrieve executor from saved state
            let retrieveExecutor = RetrieveExecutor(
                host: retrievalState.host,
                port: retrievalState.port,
                callingAE: retrievalState.callingAE,
                calledAE: retrievalState.calledAE,
                moveDestination: retrievalState.moveDestination,
                timeout: 60,
                outputPath: retrievalState.outputPath,
                hierarchical: retrievalState.hierarchical,
                verbose: verbose
            )
            
            var successCount = 0
            var failureCount = 0
            
            for (index, studyInfo) in retrievalState.studies.enumerated() {
                guard let studyUID = studyInfo.studyInstanceUID else {
                    print("[\(index + 1)/\(retrievalState.studies.count)] ⚠️  Missing Study UID")
                    failureCount += 1
                    continue
                }
                
                print("[\(index + 1)/\(retrievalState.studies.count)] Retrieving: \(studyUID)")
                if let patientName = studyInfo.patientName {
                    print("  Patient: \(patientName)")
                }
                
                do {
                    try await retrieveExecutor.retrieveStudy(studyUID: studyUID, method: retrievalState.method)
                    successCount += 1
                    print("  ✅ Success")
                } catch {
                    failureCount += 1
                    print("  ❌ Failed: \(error.localizedDescription)")
                }
                
                print("")
            }
            
            print("Retrieval Summary:")
            print("  Total: \(retrievalState.studies.count)")
            print("  Success: \(successCount)")
            print("  Failed: \(failureCount)")
            #else
            print("Error: Network operations not supported on this platform")
            throw ExitCode(1)
            #endif
        }
    }
}

// MARK: - Helper Types

struct ServerInfo {
    let host: String
    let port: UInt16
}

func parseServerURL(_ urlString: String) throws -> ServerInfo {
    guard urlString.hasPrefix("pacs://") else {
        throw ValidationError("Invalid URL format. Must start with pacs://")
    }
    
    let withoutScheme = String(urlString.dropFirst(7))
    let components = withoutScheme.components(separatedBy: ":")
    
    guard components.count == 2,
          let port = UInt16(components[1]) else {
        throw ValidationError("Invalid URL format. Expected pacs://host:port")
    }
    
    return ServerInfo(host: components[0], port: port)
}

// MARK: - State Types

struct QueryState: Codable {
    let studies: [StudyInfo]
    
    struct StudyInfo: Codable {
        let studyInstanceUID: String?
        let patientName: String?
        let patientID: String?
        let studyDate: String?
        let studyDescription: String?
        let accessionNumber: String?
        let modality: String?
        
        init(from result: GenericQueryResult) {
            self.studyInstanceUID = result.studyInstanceUID
            self.patientName = result.patientName
            self.patientID = result.patientID
            self.studyDate = result.studyDate
            self.studyDescription = result.studyDescription
            self.accessionNumber = result.accessionNumber
            self.modality = result.modality
        }
    }
}

struct RetrievalState: Codable {
    let studies: [QueryState.StudyInfo]
    let host: String
    let port: UInt16
    let callingAE: String
    let calledAE: String
    let moveDestination: String?
    let method: RetrievalMethod
    let outputPath: String
    let hierarchical: Bool
}

// Extension to add study-level accessors to GenericQueryResult
extension GenericQueryResult {
    var studyInstanceUID: String? {
        uid(for: .studyInstanceUID)
    }
    
    var patientName: String? {
        string(for: .patientName)
    }
    
    var patientID: String? {
        string(for: .patientID)
    }
    
    var studyDate: String? {
        string(for: .studyDate)
    }
    
    var studyDescription: String? {
        string(for: .studyDescription)
    }
    
    var accessionNumber: String? {
        string(for: .accessionNumber)
    }
    
    var modality: String? {
        string(for: .modality)
    }
}

enum RetrievalMethod: String, Codable, ExpressibleByArgument {
    case cMove = "c-move"
    case cGet = "c-get"
}

#if canImport(Network)
// Import executor types from dicom-query and dicom-retrieve
// These would normally be in separate files but for CLI tools they're duplicated
struct QueryExecutor {
    let host: String
    let port: UInt16
    let callingAE: String
    let calledAE: String
    let timeout: TimeInterval
    
    func executeQuery(level: QueryLevel, queryKeys: QueryKeys) async throws -> [GenericQueryResult] {
        let configuration = try buildConfiguration()
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
    
    private func buildConfiguration() throws -> QueryConfiguration {
        return QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout
        )
    }
}

struct RetrieveExecutor {
    let host: String
    let port: UInt16
    let callingAE: String
    let calledAE: String
    let moveDestination: String?
    let timeout: TimeInterval
    let outputPath: String
    let hierarchical: Bool
    let verbose: Bool
    
    func retrieveStudy(studyUID: String, method: RetrievalMethod) async throws {
        if verbose {
            print("  Executing \(method.rawValue.uppercased()) for study: \(studyUID)")
        }
        
        let configuration = try buildConfiguration(moveDestination: moveDestination)
        
        switch method {
        case .cMove:
            try await DICOMRetrieveService.moveStudy(
                studyUID: studyUID,
                host: host,
                port: port,
                configuration: configuration,
                outputPath: outputPath,
                hierarchical: hierarchical
            )
        case .cGet:
            try await DICOMRetrieveService.getStudy(
                studyUID: studyUID,
                host: host,
                port: port,
                configuration: configuration,
                outputPath: outputPath,
                hierarchical: hierarchical
            )
        }
    }
    
    private func buildConfiguration(moveDestination: String?) throws -> RetrieveConfiguration {
        return RetrieveConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            moveDestinationAETitle: moveDestination.map { try? AETitle($0) },
            timeout: timeout
        )
    }
}
#endif

DICOMQR.main()
