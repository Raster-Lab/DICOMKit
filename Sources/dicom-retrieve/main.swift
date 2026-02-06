import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, *)
struct DICOMRetrieve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-retrieve",
        abstract: "Retrieve DICOM files from PACS using C-MOVE or C-GET protocols",
        discussion: """
            Retrieves DICOM studies, series, or instances from PACS servers using the C-MOVE
            or C-GET service. C-MOVE requires a destination AE, while C-GET retrieves directly.
            
            URL Formats:
              pacs://hostname:port     - DICOM C-MOVE/C-GET protocol
            
            Examples:
              # Retrieve study using C-MOVE
              dicom-retrieve pacs://server:11112 \\
                --aet MY_SCU \\
                --move-dest MY_SCP \\
                --study-uid 1.2.840.xxx \\
                --output study_dir/
              
              # Retrieve using C-GET (simpler, no move destination)
              dicom-retrieve pacs://server:11112 \\
                --aet MY_SCU \\
                --study-uid 1.2.840.xxx \\
                --method c-get \\
                --output study_dir/
              
              # Retrieve specific series
              dicom-retrieve pacs://server:11112 \\
                --aet MY_SCU \\
                --move-dest MY_SCP \\
                --study-uid 1.2.840.xxx \\
                --series-uid 1.2.840.yyy \\
                --output series_dir/
              
              # Bulk retrieve from UID list
              dicom-retrieve pacs://server:11112 \\
                --aet MY_SCU \\
                --move-dest MY_SCP \\
                --uid-list study_uids.txt \\
                --output studies/ \\
                --parallel 4
            """,
        version: "1.1.2"
    )
    
    @Argument(help: "PACS server URL (pacs://host:port)")
    var url: String
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Option(name: .long, help: "Study Instance UID to retrieve")
    var studyUid: String?
    
    @Option(name: .long, help: "Series Instance UID to retrieve (requires --study-uid)")
    var seriesUid: String?
    
    @Option(name: .long, help: "SOP Instance UID to retrieve (requires --study-uid and --series-uid)")
    var instanceUid: String?
    
    @Option(name: .long, help: "File containing list of Study UIDs to retrieve (one per line)")
    var uidList: String?
    
    @Option(name: .long, help: "Output directory for retrieved files")
    var output: String = "."
    
    @Option(name: .long, help: "Retrieval method: c-move or c-get (default: c-move)")
    var method: RetrievalMethod = .cMove
    
    @Option(name: .long, help: "Move destination AE title (required for C-MOVE)")
    var moveDest: String?
    
    @Flag(name: .long, help: "Organize output hierarchically (patient/study/series)")
    var hierarchical: Bool = false
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
    var timeout: Int = 60
    
    @Option(name: .long, help: "Number of parallel retrieval operations (default: 1)")
    var parallel: Int = 1
    
    @Flag(name: .shortAndLong, help: "Show verbose output including progress")
    var verbose: Bool = false
    
    mutating func run() async throws {
        #if canImport(Network)
        // Parse URL
        let serverInfo = try parseServerURL(url)
        
        guard serverInfo.scheme == "pacs" else {
            throw ValidationError("Only pacs:// URLs are supported")
        }
        
        // Validate method and destination
        if method == .cMove && moveDest == nil {
            throw ValidationError("C-MOVE requires --move-dest parameter")
        }
        
        // Validate UID parameters
        guard studyUid != nil || uidList != nil else {
            throw ValidationError("Must specify either --study-uid or --uid-list")
        }
        
        if seriesUid != nil && studyUid == nil {
            throw ValidationError("--series-uid requires --study-uid")
        }
        
        if instanceUid != nil && (studyUid == nil || seriesUid == nil) {
            throw ValidationError("--instance-uid requires both --study-uid and --series-uid")
        }
        
        if verbose {
            fprintln("DICOM Retrieve Tool v1.1.2")
            fprintln("==========================")
            fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Method: \(method)")
            if let dest = moveDest {
                fprintln("Move Destination: \(dest)")
            }
            fprintln("Output: \(output)")
            fprintln("Organization: \(hierarchical ? "Hierarchical" : "Flat")")
            fprintln("Timeout: \(timeout)s")
            fprintln("Parallel: \(parallel)")
            fprintln("")
        }
        
        // Create output directory
        try createOutputDirectory(output)
        
        // Create executor
        let executor = RetrieveExecutor(
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
        
        // Execute retrieval
        if let uidListPath = uidList {
            // Bulk retrieval from file
            let uids = try loadUIDList(from: uidListPath)
            if verbose {
                fprintln("Loaded \(uids.count) UIDs from \(uidListPath)")
                fprintln("")
            }
            try await executor.retrieveBulk(studyUIDs: uids, method: method, parallelism: parallel)
        } else if let sopUID = instanceUid, let seriesUID = seriesUid, let studyUID = studyUid {
            // Single instance retrieval
            try await executor.retrieveInstance(
                studyUID: studyUID,
                seriesUID: seriesUID,
                sopUID: sopUID,
                method: method
            )
        } else if let seriesUID = seriesUid, let studyUID = studyUid {
            // Series retrieval
            try await executor.retrieveSeries(
                studyUID: studyUID,
                seriesUID: seriesUID,
                method: method
            )
        } else if let studyUID = studyUid {
            // Study retrieval
            try await executor.retrieveStudy(studyUID: studyUID, method: method)
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
    
    func createOutputDirectory(_ path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw ValidationError("Output path exists but is not a directory: \(path)")
            }
        } else {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
    
    func loadUIDList(from path: String) throws -> [String] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") } // Filter empty lines and comments
    }
}

enum RetrievalMethod: String, ExpressibleByArgument {
    case cMove = "c-move"
    case cGet = "c-get"
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMRetrieve.main()
