import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

@main
struct DICOMQuery: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-query",
        abstract: "Query DICOM servers using C-FIND and QIDO-RS protocols",
        discussion: """
            Performs DICOM queries against PACS servers using the C-FIND service.
            Supports patient, study, series, and instance level queries.
            
            The host argument accepts a hostname or IP address, optionally with a
            port suffix (host:port). Use --port to specify the port separately.
            If no port is given, the default is 11112.
            
            Examples:
              dicom-query server --port 11112 --aet MY_SCU --patient-name "SMITH^JOHN"
              dicom-query server:11112 --aet MY_SCU --study-date 20240101-20240131
              dicom-query server:11112 --aet MY_SCU --modality CT --format json
              dicom-query 192.168.1.100:11112 --aet MY_SCU --level series --study-uid 1.2.3
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "PACS server hostname or IP address, optionally with port (host:port)")
    var host: String
    
    @Option(name: .long, help: "PACS server port (default: 11112, overrides port in host argument)")
    var port: UInt16?
    
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
    
    @Option(name: .long, help: ArgumentHelp(stringLiteral: ModalityOptionValidator.helpText("filter")))
    var modality: String?

    @Flag(name: .long, help: "Reject a --modality value that is not a current DICOM Defined Term")
    var strictModality: Bool = false
    
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

    @Flag(name: .long, help: "Non-baseline: at SERIES/INSTANCE level also request parent-level attributes (Patient Name/ID, Study Date/Description, Accession) as return keys, for lenient SCPs such as dcm4chee (PS3.4 C.4.1.2.1 does not allow them)")
    var includeParentKeys: Bool = false
    
    /// PS3.4 C.4.1.2.1: a SERIES query needs the parent Study UID, an INSTANCE
    /// query needs Study and Series UIDs. Checked here so the message names the
    /// flag, before any connection is opened.
    func validate() throws {
        switch level {
        case .series:
            if (studyUid ?? "").isEmpty {
                throw ValidationError("--level series requires --study-uid (PS3.4 C.4.1.2.1: the Study Instance UID of the level above must be given)")
            }
        case .instance:
            if (studyUid ?? "").isEmpty || (seriesUid ?? "").isEmpty {
                throw ValidationError("--level instance requires --study-uid and --series-uid (PS3.4 C.4.1.2.1)")
            }
        default:
            break
        }
    }

    mutating func run() async throws {
        // Validate --modality once, up front: an unrecognized code otherwise
        // reaches the PACS as a filter that silently matches nothing.
        modality = try ModalityOptionValidator.resolve(
            modality, strict: strictModality, verbose: verbose)

        #if canImport(Network)
        let serverInfo = resolveHostPort()

        // Verbose header via the SHARED NetworkConsole formatter, printed to STDOUT so
        // its order matches DICOMStudio's in-process console (the parity harness diffs
        // the binary's stdout+stderr against the app). Gated on --verbose so a plain
        // run stays just the results table (clean for piping).
        if verbose {
            let model = level.queryLevel == .patient ? "Patient Root" : "Study Root"
            print(NetworkConsole.queryHeader(
                host: serverInfo.host, port: serverInfo.port,
                callingAE: aet, calledAE: calledAet,
                level: level.queryLevel, informationModel: model,
                timeout: timeout, filters: appliedFilters()), terminator: "")
        }

        // PS3.4 C.4.1.2.1: patient/study filters cannot be matched at SERIES or
        // INSTANCE level under the hierarchical model. Say so instead of dropping
        // them silently.
        if let warning = parentLevelFilterWarning() {
            FileHandle.standardError.write((warning + "\n").data(using: .utf8) ?? Data())
        }

        // Build query keys
        let queryKeys = buildQueryKeys()

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

        // Format and output results via the shared formatter (DICOMNetwork).
        let formatter = DICOMQueryResultFormatter(format: format.asShared, level: level.queryLevel)
        let output = formatter.format(results: results)
        print(output, terminator: "")
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }

    /// Applied, non-empty match filters in the canonical order shared with the app's
    /// header, so the verbose listing is identical on both sides.
    func appliedFilters() -> [(label: String, value: String)] {
        var f: [(String, String)] = []
        func add(_ label: String, _ value: String?) {
            if let v = value, !v.isEmpty { f.append((label, v)) }
        }
        add("Patient Name:", patientName)
        add("Patient ID:", patientId)
        add("Study Date:", studyDate)
        add("Modality:", modality)
        add("Study UID:", studyUid)
        add("Series UID:", seriesUid)
        add("Accession:", accessionNumber)
        add("Study Desc:", studyDescription)
        add("Referring Physician:", referringPhysician)
        return f
    }

    func buildQueryKeys() -> QueryKeys {
        // Single shared mapping (DICOMNetwork) used by the CLI, the app, and the
        // CLI-parity reference — so input→C-FIND keys cannot drift. (This is also
        // where the study-level `--modality` → ModalitiesInStudy fix lives.)
        DICOMQueryService.buildQueryKeys(
            level: level.queryLevel,
            patientName: patientName ?? "",
            patientID: patientId ?? "",
            studyDate: studyDate ?? "",
            modality: modality ?? "",
            accession: accessionNumber ?? "",
            studyDescription: studyDescription ?? "",
            referringPhysician: referringPhysician ?? "",
            studyUID: studyUid ?? "",
            seriesUID: seriesUid ?? "",
            includeParentLevelReturnKeys: includeParentKeys
        )
    }

    /// The stderr warning for patient/study filters given at SERIES/INSTANCE
    /// level, or nil when nothing is ignored (PS3.4 C.4.1.2.1).
    func parentLevelFilterWarning() -> String? {
        let ignored = DICOMQueryService.ignoredParentLevelFilters(
            level: level.queryLevel,
            patientName: patientName ?? "",
            patientID: patientId ?? "",
            studyDate: studyDate ?? "",
            accession: accessionNumber ?? "",
            studyDescription: studyDescription ?? "",
            referringPhysician: referringPhysician ?? ""
        )
        guard !ignored.isEmpty else { return nil }
        return "Warning: \(ignored.joined(separator: ", ")) cannot be matched at \(level.rawValue.uppercased()) level "
            + "under the hierarchical query model and will be ignored "
            + "(PS3.4 C.4.1.2.1: only the Unique Keys of the levels above may be sent). "
            + "Query at STUDY level first, then narrow with --study-uid."
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

    /// Maps to the shared package formatter's format.
    var asShared: QueryOutputFormat { QueryOutputFormat(rawValue: rawValue) ?? .table }
}
