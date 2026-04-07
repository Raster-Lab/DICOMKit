import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMNetwork

@main
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
              dicom-qr \\
                --host server --port 11112 \\
                --aet MY_AET --called-aet PACS_SCP \\
                --move-dest MY_SCP \\
                --patient-name "DOE*" \\
                --interactive
              
              # Automatic query and retrieve
              dicom-qr \\
                --host server:11112 \\
                --aet MY_AET \\
                --move-dest MY_SCP \\
                --study-date "20240101-20240131" \\
                --modality CT \\
                --output studies/ \\
                --auto
              
              # Query, review, then retrieve
              dicom-qr \\
                --host server --port 11112 \\
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
        
        @Option(name: .long, help: "PACS server hostname or IP address (optionally host:port)")
        var host: String
        
        @Option(name: .long, help: "PACS server port (default: 11112)")
        var port: UInt16?
        
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

        @Option(name: .long, help: "Requested transfer syntax for retrieved files (e.g. explicit-vr-le, jpeg-baseline, jpeg2000, rle-lossless, implicit-vr-le)")
        var transferSyntax: String?

        @Flag(name: .long, help: "Show verbose output")
        var verbose: Bool = false
        
        /// Resolves the final host and port.
        func resolveHostPort() -> (host: String, port: UInt16) {
            dicom_qr.resolveHostPort(host: host, port: port)
        }
        
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
            
            // Parse server
            let serverInfo = resolveHostPort()
            
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
                if let ts = transferSyntax {
                    print("  Transfer Syntax: \(ts) (requested)")
                }
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
            
            if verbose {
                print("Raw C-FIND response attributes:")
                for (index, result) in results.enumerated() {
                    print("  Result [\(index + 1)]:")
                    for (tag, data) in result.attributes.sorted(by: { $0.key < $1.key }) {
                        let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? "<binary \(data.count) bytes>"
                        print("    (\(String(format: "%04X", tag.group)),\(String(format: "%04X", tag.element))) = \"\(str.trimmingCharacters(in: CharacterSet(charactersIn: " \0")))\"")
                    }
                }
                print("")
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
            // Always request all standard return keys first, then add
            // matching keys for user-supplied filter values.  This mirrors
            // the approach used by the DICOMStudio ViewModel.
            var keys = QueryKeys(level: .study)
                .requestStudyInstanceUID()
                .requestPatientName()
                .requestPatientID()
                .requestStudyDate()
                .requestStudyDescription()
                .requestAccessionNumber()
                .requestModalitiesInStudy()
                .requestNumberOfStudyRelatedSeries()
                .requestNumberOfStudyRelatedInstances()
            
            if let name = patientName {
                keys = keys.patientName(name.uppercased())
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
                keys = keys.modalitiesInStudy(mod)
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

/// Resolves the final host and port from ``--host`` and ``--port`` options.
private func resolveHostPort(host: String, port: UInt16?) -> (host: String, port: UInt16) {
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

enum DICOMQRError: Error, CustomStringConvertible {
    case missingMoveDestination
    
    var description: String {
        switch self {
        case .missingMoveDestination:
            return "Move destination AE title is required for C-MOVE retrieval"
        }
    }
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
        let configuration = try buildConfiguration(level: level)
        
        return try await DICOMQueryService.find(
            host: host,
            port: port,
            configuration: configuration,
            queryKeys: queryKeys
        )
    }
    
    private func buildConfiguration(level: QueryLevel) throws -> QueryConfiguration {
        let informationModel: QueryRetrieveInformationModel = (level == .patient) ? .patientRoot : .studyRoot
        return QueryConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            timeout: timeout,
            informationModel: informationModel
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
        
        switch method {
        case .cMove:
            guard let moveDestination = moveDestination else {
                throw DICOMQRError.missingMoveDestination
            }
            _ = try await DICOMRetrieveService.moveStudy(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                moveDestination: moveDestination,
                timeout: timeout
            )
        case .cGet:
            let stream = try await DICOMRetrieveService.getStudy(
                host: host,
                port: port,
                callingAE: callingAE,
                calledAE: calledAE,
                studyInstanceUID: studyUID,
                timeout: timeout
            )
            var filesReceived = 0
            var totalBytes = 0
            for await event in stream {
                switch event {
                case .instance(let sopInstanceUID, let sopClassUID, let transferSyntaxUID, let data):
                    try saveInstance(
                        sopInstanceUID: sopInstanceUID,
                        sopClassUID: sopClassUID,
                        transferSyntaxUID: transferSyntaxUID,
                        data: data,
                        studyUID: studyUID
                    )
                    filesReceived += 1
                    totalBytes += data.count
                    if verbose {
                        print("    Received instance: \(sopInstanceUID) (\(formatBytes(totalBytes)))")
                    }
                case .progress(let progress):
                    if verbose {
                        print("    Progress: \(progress.completed)/\(progress.completed + progress.remaining)")
                    }
                case .completed(let result):
                    print("  Files received: \(filesReceived) (\(formatBytes(totalBytes)))")
                    if verbose {
                        print("  C-GET status: \(result.status)")
                    }
                case .error(let err):
                    throw err
                }
            }
        }
    }
    
    // MARK: - File Management
    
    private func saveInstance(
        sopInstanceUID: String,
        sopClassUID: String,
        transferSyntaxUID: String,
        data: Data,
        studyUID: String
    ) throws {
        let fm = FileManager.default
        let filename = "\(sopInstanceUID).dcm"
        let dirPath: String
        
        if hierarchical {
            dirPath = (outputPath as NSString).appendingPathComponent(studyUID)
        } else {
            dirPath = outputPath
        }
        
        try fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        
        let filepath = (dirPath as NSString).appendingPathComponent(filename)
        
        // Wrap the raw dataset in a Part 10 container if it is not already one
        let fileData: Data
        if data.count >= 132,
           data[128] == 0x44, data[129] == 0x49, data[130] == 0x43, data[131] == 0x4D {
            fileData = data
        } else {
            fileData = buildPart10(
                dataset: data,
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                transferSyntaxUID: transferSyntaxUID
            )
        }
        try fileData.write(to: URL(fileURLWithPath: filepath), options: .atomic)
    }
    
    // MARK: - Part 10 Wrapper
    
    private func buildPart10(
        dataset: Data,
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String
    ) -> Data {
        func le16(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
        func le32(_ v: UInt32) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
                                               UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]) }
        func ulElem(_ g: UInt16, _ e: UInt16, _ val: UInt32) -> Data {
            le16(g) + le16(e) + Data([0x55, 0x4C]) + le16(4) + le32(val)
        }
        func obElem(_ g: UInt16, _ e: UInt16, _ val: Data) -> Data {
            le16(g) + le16(e) + Data([0x4F, 0x42, 0x00, 0x00]) + le32(UInt32(val.count)) + val
        }
        func uiElem(_ g: UInt16, _ e: UInt16, _ val: String) -> Data {
            var b = val.data(using: .ascii) ?? Data()
            if b.count % 2 != 0 { b.append(0x00) }
            return le16(g) + le16(e) + Data([0x55, 0x49]) + le16(UInt16(b.count)) + b
        }
        
        var meta = Data()
        meta += obElem(0x0002, 0x0001, Data([0x00, 0x01]))               // File Meta Information Version
        meta += uiElem(0x0002, 0x0002, sopClassUID)                      // Media Storage SOP Class UID
        meta += uiElem(0x0002, 0x0003, sopInstanceUID)                   // Media Storage SOP Instance UID
        meta += uiElem(0x0002, 0x0010, transferSyntaxUID)                // Transfer Syntax UID
        meta += uiElem(0x0002, 0x0012, "1.2.826.0.1.3680043.9.7433.1.1") // Implementation Class UID
        
        var file = Data(repeating: 0, count: 128)                         // 128-byte preamble
        file += Data([0x44, 0x49, 0x43, 0x4D])                            // DICM magic
        file += ulElem(0x0002, 0x0000, UInt32(meta.count))               // File Meta Group Length
        file += meta
        file += dataset
        return file
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        if mb < 1024.0 { return String(format: "%.1f MB", mb) }
        return String(format: "%.1f GB", mb / 1024.0)
    }
}
#endif
