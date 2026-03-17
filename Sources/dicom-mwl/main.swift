import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct DICOMMWLCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-mwl",
        abstract: "DICOM Modality Worklist Management (MWL C-FIND)",
        discussion: """
            Query and manage DICOM Modality Worklist items. Implements the Modality
            Worklist Information Model (MWL) for querying scheduled procedure steps
            from a worklist SCP server.
            
            URL Format:
              pacs://hostname:port     - DICOM MWL protocol
            
            Examples:
              # Query worklist for today
              dicom-mwl query pacs://server:11112 --aet MODALITY --date today
              
              # Query with filters
              dicom-mwl query pacs://server:11112 --aet MODALITY \\
                --date 20240315 --station CT1 --patient "DOE^JOHN"
              
              # Filter to only SCHEDULED items
              dicom-mwl query pacs://server:11112 --aet MODALITY \\
                --sps-status SCHEDULED
              
              # Filter by modality and date with JSON output
              dicom-mwl query pacs://server:11112 --aet MODALITY \\
                --modality CT --date today --json
              
              # Verbose output showing all attributes
              dicom-mwl query pacs://server:11112 --aet MODALITY \\
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
        
        @Argument(help: "PACS server URL (pacs://host:port)")
        var url: String
        
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
            // Parse URL
            let serverInfo = try parseServerURL(url)
            
            guard serverInfo.scheme == "pacs" else {
                throw ValidationError("Only pacs:// URLs are supported")
            }
            
            if verbose && !json {
                fprintln("DICOM Modality Worklist Tool v1.0.0")
                fprintln("====================================")
                fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
                fprintln("Calling AE: \(aet)")
                fprintln("Called AE: \(calledAet)")
                fprintln("Timeout: \(timeout)s")
                if let date = date          { fprintln("Date filter:       \(date)") }
                if let s = station          { fprintln("Station AE filter: \(s)") }
                if let p = patient          { fprintln("Patient filter:    \(p)") }
                if let pid = patientId      { fprintln("Patient ID filter: \(pid)") }
                if let mod = modality       { fprintln("Modality filter:   \(mod)") }
                if let st = spsStatus       { fprintln("SPS Status filter: \(st)") }
                if let acc = accessionNumber { fprintln("Accession filter:  \(acc)") }
                fprintln("")
            }
            
            try await performQuery(serverInfo: serverInfo)
            
            #else
            throw ValidationError("Network functionality is not available on this platform")
            #endif
        }
        
        #if canImport(Network)
        func performQuery(serverInfo: (scheme: String, host: String, port: UInt16)) async throws {
            // Build query keys
            var queryKeys = WorklistQueryKeys.default()
            
            // Apply filters
            if let date = date {
                let dateString = try parseDateFilter(date)
                queryKeys = queryKeys.scheduledDate(dateString)
            }
            
            if let station = station {
                queryKeys = queryKeys.scheduledStationAET(station)
            }
            
            if let patient = patient {
                queryKeys = queryKeys.patientName(patient)
            }
            
            if let patientId = patientId {
                queryKeys = queryKeys.patientID(patientId)
            }
            
            if let modality = modality {
                queryKeys = queryKeys.modality(modality)
            }
            
            if let spsStatus = spsStatus {
                queryKeys = queryKeys.scheduledProcedureStepStatus(spsStatus)
            }
            
            if let accessionNumber = accessionNumber {
                queryKeys = queryKeys.accessionNumber(accessionNumber)
            }
            
            if verbose && !json {
                fprintln("Querying worklist...")
                fprintln("")
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
            
            // Display results
            if json {
                printJSON(items: items)
            } else {
                printFormatted(items: items)
            }
            // Warn about likely server-side result limit
            let commonLimits: Set<Int> = [50, 100, 200, 250, 500, 1000, 2000, 5000]
            if commonLimits.contains(items.count) {
                fprintln("Warning: The result count (\(items.count)) may be capped by a server-side limit.")
                fprintln("  Check your PACS server configuration (e.g., LimitFindResults in Orthanc,")
                fprintln("  or max_worklist_results in dcm4chee) to increase or remove the limit.")
            }
        }
        
        func parseDateFilter(_ filter: String) throws -> String {
            switch filter.lowercased() {
            case "today":
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                return formatter.string(from: Date())
                
            case "tomorrow":
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
                    throw ValidationError("Failed to calculate tomorrow's date")
                }
                return formatter.string(from: tomorrow)
                
            default:
                // Validate YYYYMMDD format
                if filter.count == 8 && Int(filter) != nil {
                    return filter
                } else {
                    throw ValidationError("Invalid date format. Use YYYYMMDD, 'today', or 'tomorrow'")
                }
            }
        }
        
        func printFormatted(items: [WorklistItem]) {
            if items.isEmpty {
                fprintln("No worklist items found.")
                return
            }
            
            fprintln("Found \(items.count) worklist item(s):")
            fprintln("")
            
            let sep = String(repeating: "─", count: 60)
            
            for (index, item) in items.enumerated() {
                fprintln("[\(index + 1)] Worklist Item")
                fprintln(sep)
                // Patient
                if let v = item.patientName       { fprintln("  Patient Name:          \(v)") }
                if let v = item.patientID         { fprintln("  Patient ID:            \(v)") }
                if let v = item.patientBirthDate  { fprintln("  Date of Birth:         \(v)") }
                if let v = item.patientSex        { fprintln("  Sex:                   \(v)") }
                // Study / order
                if let v = item.accessionNumber   { fprintln("  Accession Number:      \(v)") }
                if let v = item.referringPhysicianName     { fprintln("  Referring Physician:   \(v)") }
                if let v = item.requestedProcedureID       { fprintln("  Requested Proc. ID:    \(v)") }
                if let v = item.requestedProcedureDescription { fprintln("  Requested Proc. Desc:  \(v)") }
                if let v = item.studyInstanceUID  { fprintln("  Study UID:             \(v)") }
                // Scheduled Procedure Step
                if let v = item.modality          { fprintln("  Modality:              \(v)") }
                if let date = item.scheduledProcedureStepStartDate {
                    let dateTime: String
                    if let t = item.scheduledProcedureStepStartTime {
                        dateTime = "\(date)  \(t)"
                    } else {
                        dateTime = date
                    }
                    fprintln("  Scheduled Date/Time:   \(dateTime)")
                }
                if let v = item.scheduledProcedureStepStatus      { fprintln("  SPS Status:            \(v)") }
                if let v = item.scheduledProcedureStepID          { fprintln("  SPS ID:                \(v)") }
                if let v = item.scheduledProcedureStepDescription { fprintln("  SPS Description:       \(v)") }
                if let v = item.scheduledStationAETitle           { fprintln("  Station AE Title:      \(v)") }
                if let v = item.scheduledStationName              { fprintln("  Station Name:          \(v)") }
                if let v = item.scheduledPerformingPhysicianName  { fprintln("  Performing Physician:  \(v)") }
                // Verbose: all raw attributes
                if verbose {
                    fprintln("  Raw Attributes:")
                    for (tag, data) in item.attributes.sorted(by: { $0.key < $1.key }) {
                        let value = String(data: data, encoding: .ascii) ??
                            data.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
                        fprintln("    (\(String(format: "%04X", tag.group)),\(String(format: "%04X", tag.element))): \(value)")
                    }
                }
                fprintln("")
            }
        }
        
        func printJSON(items: [WorklistItem]) {
            var jsonItems: [[String: Any]] = []
            
            for item in items {
                var jsonItem: [String: Any] = [:]
                if let v = item.patientName                       { jsonItem["PatientName"] = v }
                if let v = item.patientID                         { jsonItem["PatientID"] = v }
                if let v = item.patientBirthDate                  { jsonItem["PatientBirthDate"] = v }
                if let v = item.patientSex                        { jsonItem["PatientSex"] = v }
                if let v = item.accessionNumber                   { jsonItem["AccessionNumber"] = v }
                if let v = item.studyInstanceUID                  { jsonItem["StudyInstanceUID"] = v }
                if let v = item.referringPhysicianName            { jsonItem["ReferringPhysicianName"] = v }
                if let v = item.requestedProcedureID              { jsonItem["RequestedProcedureID"] = v }
                if let v = item.requestedProcedureDescription     { jsonItem["RequestedProcedureDescription"] = v }
                if let v = item.modality                          { jsonItem["Modality"] = v }
                if let v = item.scheduledStationAETitle           { jsonItem["ScheduledStationAETitle"] = v }
                if let v = item.scheduledStationName              { jsonItem["ScheduledStationName"] = v }
                if let v = item.scheduledProcedureStepStartDate   { jsonItem["SPSStartDate"] = v }
                if let v = item.scheduledProcedureStepStartTime   { jsonItem["SPSStartTime"] = v }
                if let v = item.scheduledProcedureStepStatus      { jsonItem["SPSStatus"] = v }
                if let v = item.scheduledProcedureStepID          { jsonItem["SPSID"] = v }
                if let v = item.scheduledProcedureStepDescription { jsonItem["SPSDescription"] = v }
                if let v = item.scheduledPerformingPhysicianName  { jsonItem["ScheduledPerformingPhysician"] = v }
                jsonItems.append(jsonItem)
            }
            
            let jsonData = (try? JSONSerialization.data(withJSONObject: jsonItems, options: [.prettyPrinted, .sortedKeys])) ?? Data()
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
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
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMMWLCommand.main()
