import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@available(macOS 10.15, *)
struct DICOMQuery: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-query",
        abstract: "Query DICOM servers using C-FIND and QIDO-RS protocols",
        discussion: """
            Performs DICOM queries against PACS servers using the C-FIND service.
            Supports patient, study, series, and instance level queries.
            
            URL Formats:
              pacs://hostname:port     - DICOM C-FIND protocol
              http://hostname/path     - QIDO-RS RESTful protocol (basic)
            
            Examples:
              dicom-query pacs://server:11112 --aet MY_SCU --patient-name "SMITH^JOHN"
              dicom-query pacs://server:11112 --aet MY_SCU --study-date 20240101-20240131
              dicom-query pacs://server:11112 --aet MY_SCU --modality CT --format json
              dicom-query pacs://server:11112 --aet MY_SCU --level series --study-uid 1.2.3
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "PACS server URL (pacs://host:port or http://host/path)")
    var url: String
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Option(name: .shortAndLong, help: "Query level: patient, study, series, instance (default: study)")
    var level: QueryLevelOption = .study
    
    @Option(name: .long, help: "Patient name (wildcards * and ? supported)")
    var patientName: String?
    
    @Option(name: .long, help: "Patient ID")
    var patientId: String?
    
    @Option(name: .long, help: "Study date or range (YYYYMMDD or YYYYMMDD-YYYYMMDD)")
    var studyDate: String?
    
    @Option(name: .long, help: "Study Instance UID")
    var studyUid: String?
    
    @Option(name: .long, help: "Series Instance UID")
    var seriesUid: String?
    
    @Option(name: .long, help: "Accession Number")
    var accessionNumber: String?
    
    @Option(name: .long, help: "Modality (e.g., CT, MR, US)")
    var modality: String?
    
    @Option(name: .long, help: "Study description (wildcards supported)")
    var studyDescription: String?
    
    @Option(name: .long, help: "Referring physician name")
    var referringPhysician: String?
    
    @Option(name: .shortAndLong, help: "Output format: table, json, csv, compact (default: table)")
    var format: OutputFormat = .table
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
    var timeout: Int = 60
    
    @Flag(name: .long, help: "Show verbose output including query details")
    var verbose: Bool = false
    
    mutating func run() async throws {
        #if canImport(Network)
        // Parse URL
        let serverInfo = try parseServerURL(url)
        
        if verbose {
            fprintln("Connecting to: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Query Level: \(level.queryLevel)")
            fprintln("")
        }
        
        guard serverInfo.scheme == "pacs" else {
            throw ValidationError("Only pacs:// URLs are supported in this version. QIDO-RS support coming soon.")
        }
        
        // Build query keys
        let queryKeys = buildQueryKeys()
        
        if verbose {
            fprintln("Query filters:")
            for key in queryKeys.keys {
                let tagName = key.tag.description
                fprintln("  \(tagName): \(key.value.isEmpty ? "(return)" : key.value)")
            }
            fprintln("")
        }
        
        // Execute query
        let executor = QueryExecutor(
            host: serverInfo.host,
            port: serverInfo.port,
            callingAE: aet,
            calledAE: calledAet,
            timeout: TimeInterval(timeout)
        )
        
        let results = try await executor.executeQuery(
            level: level.queryLevel,
            queryKeys: queryKeys
        )
        
        if verbose {
            fprintln("Found \(results.count) result(s)\n")
        }
        
        // Format and output results
        let formatter = QueryFormatter(format: format, level: level.queryLevel)
        let output = formatter.format(results: results)
        print(output, terminator: "")
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }
    
    func buildQueryKeys() -> QueryKeys {
        var keys = QueryKeys(level: level.queryLevel)
        
        // Add filters based on level
        switch level.queryLevel {
        case .patient:
            keys = keys
                .requestPatientName()
                .requestPatientID()
                .requestPatientBirthDate()
                .requestPatientSex()
                .requestNumberOfPatientRelatedStudies()
        case .study:
            keys = keys
                .requestPatientName()
                .requestPatientID()
                .requestStudyInstanceUID()
                .requestStudyDate()
                .requestStudyTime()
                .requestStudyDescription()
                .requestAccessionNumber()
                .requestStudyID()
                .requestReferringPhysicianName()
                .requestModalitiesInStudy()
                .requestNumberOfStudyRelatedSeries()
                .requestNumberOfStudyRelatedInstances()
        case .series:
            keys = keys
                .requestSeriesInstanceUID()
                .requestSeriesNumber()
                .requestSeriesDescription()
                .requestModality()
                .requestSeriesDate()
                .requestNumberOfSeriesRelatedInstances()
        case .image:
            keys = keys
                .requestSOPInstanceUID()
                .requestSOPClassUID()
                .requestInstanceNumber()
                .requestRows()
                .requestColumns()
                .requestNumberOfFrames()
        }
        
        // Apply user-specified filters
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
        if let uid = seriesUid {
            keys = keys.seriesInstanceUID(uid)
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
    
    func parseServerURL(_ urlString: String) throws -> (scheme: String, host: String, port: UInt16) {
        // Parse pacs://hostname:port or http://hostname/path
        guard let url = URL(string: urlString) else {
            throw ValidationError("Invalid URL: \(urlString)")
        }
        
        guard let scheme = url.scheme, ["pacs", "http", "https"].contains(scheme) else {
            throw ValidationError("URL must use pacs://, http://, or https:// scheme")
        }
        
        guard let host = url.host else {
            throw ValidationError("URL must include a hostname")
        }
        
        let port: UInt16
        if let urlPort = url.port {
            port = UInt16(urlPort)
        } else if scheme == "pacs" {
            port = 104 // DICOM default port
        } else {
            port = scheme == "https" ? 443 : 80
        }
        
        return (scheme, host, port)
    }
}

enum QueryLevelOption: String, ExpressibleByArgument {
    case patient
    case study
    case series
    case instance
    
    var queryLevel: QueryLevel {
        switch self {
        case .patient: return .patient
        case .study: return .study
        case .series: return .series
        case .instance: return .image
        }
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case table
    case json
    case csv
    case compact
}

/// Prints to stderr
private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMQuery.main()
