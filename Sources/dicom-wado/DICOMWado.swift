import Foundation
import ArgumentParser
import DICOMCore
import DICOMWeb

@main
struct DICOMWado: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-wado",
        abstract: "DICOMweb client for RESTful DICOM operations",
        discussion: """
            Comprehensive DICOMweb client supporting WADO-RS, QIDO-RS, STOW-RS, and UPS-RS protocols.
            Provides RESTful HTTP/HTTPS-based access to DICOM objects without traditional networking.
            
            Subcommands:
              retrieve  - WADO-RS: Retrieve studies, series, instances, frames
              query     - QIDO-RS: Search for studies, series, instances
              store     - STOW-RS: Upload DICOM instances to server
              ups       - UPS-RS: Unified Worklist operations
            
            Examples:
              dicom-wado retrieve https://pacs.example.com/dicom-web --study 1.2.3.4.5 -o study/
              dicom-wado query https://pacs.example.com/dicom-web --patient-name "DOE*"
              dicom-wado store https://pacs.example.com/dicom-web file1.dcm file2.dcm
              dicom-wado ups https://pacs.example.com/dicom-web --search
            """,
        version: "1.0.0",
        subcommands: [
            RetrieveCommand.self,
            QueryCommand.self,
            StoreCommand.self,
            UPSCommand.self
        ]
    )
}

// MARK: - Retrieve Command (WADO-RS)

@available(macOS 10.15, *)
struct RetrieveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "retrieve",
        abstract: "Retrieve DICOM objects using WADO-RS or WADO-URI",
        discussion: """
            Downloads studies, series, instances, frames, or metadata from DICOMweb server.
            
            By default uses WADO-RS (RESTful paths). Use --uri for legacy WADO-URI servers
            (e.g. dcm4chee2) that expect query-parameter URLs.

            WADO-URI endpoint: dcm4chee-arc serves WADO-URI from its `/wado` servlet, not the
            RESTful `/rs` endpoint. If a `/rs` base URL is supplied with --uri it is rewritten
            to `/wado` automatically (so `…/aets/AET/rs` becomes `…/aets/AET/wado`); dcm4chee2's
            root `/wado` and other paths are used as-is.
            
            WADO-RS examples:
              dicom-wado retrieve https://server/dicom-web --study 1.2.3.4.5 -o study/
              dicom-wado retrieve https://server/dicom-web --study 1.2.3 --series 1.2.3.4 -o series/
              dicom-wado retrieve https://server/dicom-web --study 1.2.3 --metadata --format json
            
            WADO-URI examples (legacy):
              dicom-wado retrieve http://server:8080/wado --uri --study 1.2.3 --series 1.2.3.4 --instance 1.2.3.4.5 -o out/
              dicom-wado retrieve http://server:8080/wado --uri --study 1.2.3 --series 1.2.3.4 --instance 1.2.3.4.5 --content-type image/jpeg -o out/
            """
    )
    
    @Argument(help: "DICOMweb server base URL (e.g., https://server/dicom-web)")
    var baseURL: String
    
    @Option(name: .long, help: "Study Instance UID to retrieve")
    var study: String?
    
    @Option(name: .long, help: "Series Instance UID to retrieve")
    var series: String?
    
    @Option(name: .long, help: "SOP Instance UID to retrieve")
    var instance: String?
    
    @Option(name: .long, help: "Frame numbers to retrieve (comma-separated, e.g., 1,2,3)")
    var frames: String?
    
    @Flag(name: .long, help: "Use WADO-URI protocol (legacy query-parameter URLs for dcm4chee2 etc.)")
    var uri: Bool = false
    
    @Option(name: .long, help: "Content type for WADO-URI: application/dicom, image/jpeg, image/png, image/gif (default: application/dicom)")
    var contentType: String?
    
    @Flag(name: .long, help: "Retrieve only metadata (not pixel data)")
    var metadata: Bool = false
    
    @Flag(name: .long, help: "Retrieve rendered image instead of DICOM")
    var rendered: Bool = false
    
    @Flag(name: .long, help: "Retrieve thumbnail images")
    var thumbnail: Bool = false
    
    @Option(name: .shortAndLong, help: "Output directory for retrieved files")
    var output: String?
    
    @Option(name: .long, help: "OAuth2 bearer token for authentication")
    var token: String?
    
    @Option(name: .shortAndLong, help: "Output format for metadata: json, xml (default: json)")
    var format: MetadataFormat = .json
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
    var timeout: Int = 60
    
    @Flag(name: .long, help: "Show verbose output including progress")
    var verbose: Bool = false
    
    func run() async throws {
        guard let studyUID = study else {
            throw ValidationError("--study is required for retrieve operations")
        }
        
        // Configure client
        let config = try DICOMwebConfiguration(
            baseURLString: baseURL,
            authentication: token.map { .bearer(token: $0) }
        )
        
        // WADO-URI mode
        if uri {
            try await runWADOURI(config: config, studyUID: studyUID)
            return
        }
        
        let client = DICOMwebClient(configuration: config)
        
        if verbose {
            // Console rendering is delegated to the SHARED WADORetrieveConsoleFormatter
            // (DICOMWeb) — the single retrieve-output renderer the CLI Workshop's in-app
            // retrieve also calls, so the CLI and app output pipelines cannot drift
            // (mirrors QIDOResultFormatter for the query subcommand).
            fprintln(WADORetrieveConsoleFormatter().verbosePreambleRS(
                baseURL: baseURL, studyUID: studyUID, seriesUID: series, instanceUID: instance))
            fprintln("")
        }
        
        // Handle different retrieval types (WADO-RS)
        if metadata {
            try await retrieveMetadata(client: client, studyUID: studyUID)
        } else if rendered {
            try await retrieveRendered(client: client, studyUID: studyUID)
        } else if thumbnail {
            try await retrieveThumbnail(client: client, studyUID: studyUID)
        } else if let framesString = frames {
            try await retrieveFrames(client: client, studyUID: studyUID, framesString: framesString)
        } else {
            try await retrieveInstances(client: client, studyUID: studyUID)
        }
    }
    
    // MARK: - WADO-URI
    
    private func runWADOURI(config: DICOMwebConfiguration, studyUID: String) async throws {
        guard let seriesUID = series else {
            throw ValidationError("--series is required for WADO-URI retrieval")
        }
        guard let instanceUID = instance else {
            throw ValidationError("--instance is required for WADO-URI retrieval")
        }
        
        // Shared mapping (single source of truth) — the CLI-parity reference calls the
        // same factory, so both request the identical representation for a --content-type.
        let wadoContentType = WADOURIClient.ContentType.fromRequestString(contentType)
        
        let frameNumber: Int?
        if let framesString = frames,
           let first = framesString.split(separator: ",").first,
           let num = Int(first.trimmingCharacters(in: .whitespaces)) {
            frameNumber = num
        } else {
            frameNumber = nil
        }
        
        let fmt = WADORetrieveConsoleFormatter()
        if verbose {
            fprintln(fmt.verbosePreambleURI(
                baseURL: baseURL, studyUID: studyUID, seriesUID: seriesUID,
                instanceUID: instanceUID, contentType: wadoContentType.rawValue, frame: frameNumber))
            fprintln("")
        }

        let client = WADOURIClient(configuration: config)
        let result = try await client.retrieve(
            studyUID: studyUID,
            seriesUID: seriesUID,
            objectUID: instanceUID,
            contentType: wadoContentType,
            frameNumber: frameNumber
        )
        
        // Determine filename and extension
        let frameSuffix = frameNumber.map { "_frame\($0)" } ?? ""
        let ext: String
        switch wadoContentType {
        case .dicom:          ext = "dcm"
        case .jpeg:           ext = "jpg"
        case .png:            ext = "png"
        case .gif:            ext = "gif"
        case .jpeg2000:       ext = "jp2"
        case .htj2k:          ext = "jph"
        case .htj2kContainer: ext = "jphc"
        case .mpeg:           ext = "mpg"
        }
        let filename = "\(instanceUID)\(frameSuffix).\(ext)"
        try saveData(result.data, filename: filename)
        
        if verbose {
            fprintln(fmt.uriRetrievedVerbose(bytes: result.data.count))
            fprintln(fmt.savedTo(path: "\(output ?? FileManager.default.currentDirectoryPath)/\(filename)"))
        } else {
            fprintln(fmt.uriRetrieved(bytes: result.data.count, filename: filename))
        }
    }
    
    private func retrieveMetadata(client: DICOMwebClient, studyUID: String) async throws {
        let fmt = WADORetrieveConsoleFormatter()
        if verbose {
            fprintln(fmt.metadataRetrieving())
        }

        // JSON and XML decode the same DICOMweb metadata response through different
        // pipelines: JSON keeps the raw dataset dictionaries, while XML decodes to
        // typed DataElements so the shared DICOMXMLEncoder (PS3.19 Native DICOM
        // Model) can render them — the same encoder dicom-xml uses.
        switch format {
        case .json:
            let metadata: [[String: Any]]
            if let instanceUID = instance, let seriesUID = series {
                metadata = try await client.retrieveInstanceMetadata(
                    studyUID: studyUID,
                    seriesUID: seriesUID,
                    instanceUID: instanceUID
                )
            } else if let seriesUID = series {
                metadata = try await client.retrieveSeriesMetadata(
                    studyUID: studyUID,
                    seriesUID: seriesUID
                )
            } else {
                metadata = try await client.retrieveStudyMetadata(studyUID: studyUID)
            }
            print(try fmt.metadataJSON(metadata))
            if verbose {
                fprintln(fmt.metadataCount(metadata.count))
            }

        case .xml:
            let instances: [[DataElement]]
            if let instanceUID = instance, let seriesUID = series {
                let elements = try await client.retrieveInstanceMetadataAsElements(
                    studyUID: studyUID,
                    seriesUID: seriesUID,
                    instanceUID: instanceUID
                )
                instances = [elements]
            } else if let seriesUID = series {
                instances = try await client.retrieveSeriesMetadataAsElements(
                    studyUID: studyUID,
                    seriesUID: seriesUID
                )
            } else {
                instances = try await client.retrieveStudyMetadataAsElements(studyUID: studyUID)
            }
            print(try fmt.metadataXML(instances))
            if verbose {
                fprintln(fmt.metadataCount(instances.count))
            }
        }
    }
    
    private func retrieveRendered(client: DICOMwebClient, studyUID: String) async throws {
        guard let instanceUID = instance, let seriesUID = series else {
            throw ValidationError("--series and --instance are required for rendered retrieval")
        }
        
        let fmt = WADORetrieveConsoleFormatter()
        if verbose {
            fprintln(fmt.renderedRetrieving())
        }

        let imageData = try await client.retrieveRenderedInstance(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )

        try saveData(imageData, filename: "rendered_\(instanceUID).jpg")

        if verbose {
            fprintln(fmt.renderedSaved(bytes: imageData.count))
        }
    }
    
    private func retrieveThumbnail(client: DICOMwebClient, studyUID: String) async throws {
        let fmt = WADORetrieveConsoleFormatter()
        if verbose {
            fprintln(fmt.thumbnailRetrieving())
        }

        let thumbnailData: Data
        
        if let instanceUID = instance, let seriesUID = series {
            thumbnailData = try await client.retrieveInstanceThumbnail(
                studyUID: studyUID,
                seriesUID: seriesUID,
                instanceUID: instanceUID
            )
            try saveData(thumbnailData, filename: "thumbnail_\(instanceUID).jpg")
        } else if let seriesUID = series {
            thumbnailData = try await client.retrieveSeriesThumbnail(
                studyUID: studyUID,
                seriesUID: seriesUID
            )
            try saveData(thumbnailData, filename: "thumbnail_series_\(seriesUID).jpg")
        } else {
            thumbnailData = try await client.retrieveStudyThumbnail(studyUID: studyUID)
            try saveData(thumbnailData, filename: "thumbnail_study_\(studyUID).jpg")
        }
        
        if verbose {
            fprintln(fmt.thumbnailSaved(bytes: thumbnailData.count))
        }
    }
    
    private func retrieveFrames(client: DICOMwebClient, studyUID: String, framesString: String) async throws {
        guard let instanceUID = instance, let seriesUID = series else {
            throw ValidationError("--series and --instance are required for frame retrieval")
        }
        
        let fmt = WADORetrieveConsoleFormatter()
        let frameNumbers: [Int]
        do {
            frameNumbers = try fmt.parseFrameNumbers(framesString)
        } catch let error as WADOFrameParseError {
            throw ValidationError(error.description)
        }

        if verbose {
            fprintln(fmt.framesRetrieving(frameNumbers))
        }

        let frames = try await client.retrieveFrames(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            frames: frameNumbers
        )

        for frame in frames {
            let filename = "frame_\(frame.frameNumber)_\(instanceUID).raw"
            try saveData(frame.data, filename: filename)
            if verbose {
                fprintln(fmt.frameSaved(number: frame.frameNumber, bytes: frame.data.count))
            }
        }

        if verbose {
            fprintln(fmt.framesCount(frames.count))
        }
    }
    
    private func retrieveInstances(client: DICOMwebClient, studyUID: String) async throws {
        let fmt = WADORetrieveConsoleFormatter()
        if verbose {
            fprintln(fmt.instancesRetrieving())
        }
        
        if let instanceUID = instance, let seriesUID = series {
            // Single instance
            let instanceData = try await client.retrieveInstance(
                studyUID: studyUID,
                seriesUID: seriesUID,
                instanceUID: instanceUID
            )
            try saveData(instanceData, filename: "instance_\(instanceUID).dcm")
            if verbose {
                fprintln(fmt.instanceSaved(bytes: instanceData.count))
            }
        } else if let seriesUID = series {
            // Series
            let result = try await client.retrieveSeries(
                studyUID: studyUID,
                seriesUID: seriesUID
            )
            for (index, instanceData) in result.instances.enumerated() {
                let filename = "instance_\(index + 1).dcm"
                try saveData(instanceData, filename: filename)
                if verbose {
                    fprintln(fmt.instanceSaved(index: index + 1, bytes: instanceData.count))
                }
            }
            if verbose {
                fprintln(fmt.instancesCount(result.instances.count))
            }
        } else {
            // Full study
            let result = try await client.retrieveStudy(studyUID: studyUID)
            for (index, instanceData) in result.instances.enumerated() {
                let filename = "instance_\(index + 1).dcm"
                try saveData(instanceData, filename: filename)
                if verbose {
                    fprintln(fmt.instanceSaved(index: index + 1, bytes: instanceData.count))
                }
            }
            if verbose {
                fprintln(fmt.instancesCount(result.instances.count))
            }
        }
    }
    
    private func saveData(_ data: Data, filename: String) throws {
        let outputDir = output ?? FileManager.default.currentDirectoryPath
        let outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        try data.write(to: outputURL)
    }
}

// MARK: - Query Command (QIDO-RS)

@available(macOS 10.15, *)
struct QueryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Search for DICOM objects using QIDO-RS",
        discussion: """
            Searches for studies, series, or instances on DICOMweb server.
            
            Examples:
              dicom-wado query https://server/dicom-web --patient-name "DOE*"
              dicom-wado query https://server/dicom-web --study-date 20240101-20240131
              dicom-wado query https://server/dicom-web --modality CT --limit 10
              dicom-wado query https://server/dicom-web --level series --study 1.2.3.4.5
            """
    )
    
    @Argument(help: "DICOMweb server base URL")
    var baseURL: String
    
    @Option(name: .long, help: "Query level: study, series, instance (default: study)")
    var level: QueryLevel = .study
    
    @Option(name: .long, help: "Patient name (wildcards * and ? supported)")
    var patientName: String?
    
    @Option(name: .long, help: "Patient ID")
    var patientId: String?
    
    @Option(name: .long, help: "Study date or range (YYYYMMDD or YYYYMMDD-YYYYMMDD)")
    var studyDate: String?
    
    @Option(name: .long, help: "Study Instance UID")
    var study: String?
    
    @Option(name: .long, help: "Series Instance UID")
    var series: String?
    
    @Option(name: .long, help: "Accession number")
    var accessionNumber: String?
    
    @Option(name: .long, help: "Modality (e.g., CT, MR, US)")
    var modality: String?
    
    @Option(name: .long, help: "Study description")
    var studyDescription: String?
    
    @Option(name: .long, help: "Maximum number of results (default: 100)")
    var limit: Int = 100
    
    @Option(name: .long, help: "Offset for pagination (default: 0)")
    var offset: Int = 0
    
    @Option(name: .long, help: "OAuth2 bearer token for authentication")
    var token: String?
    
    @Option(name: .shortAndLong, help: "Output format: table, json, csv (default: table)")
    var format: OutputFormat = .table
    
    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false
    
    func run() async throws {
        // Configure client
        let config = try DICOMwebConfiguration(
            baseURLString: baseURL,
            authentication: token.map { .bearer(token: $0) }
        )
        
        let client = DICOMwebClient(configuration: config)
        
        // Build query
        var query = QIDOQuery()
        query = query.limit(limit)
        query = query.offset(offset)
        
        if let patientName = patientName {
            query = query.patientName(patientName)
        }
        if let patientId = patientId {
            query = query.patientID(patientId)
        }
        if let studyDate = studyDate {
            query = query.studyDate(studyDate)
        }
        if let studyUID = study {
            query = query.studyInstanceUID(studyUID)
        }
        if let seriesUID = series {
            query = query.seriesInstanceUID(seriesUID)
        }
        if let accessionNumber = accessionNumber {
            query = query.accessionNumber(accessionNumber)
        }
        if let modality = modality {
            // Use the correct DICOM matching key per query level (PS3.18 §10.6),
            // mirroring the app's in-process path (CLIWorkshopViewModel.executeDicomQIDO)
            // and the sibling dicom-query / dicom-qr tools:
            //   • series level          → Modality (0008,0060)
            //   • study / instance level → Modalities in Study (0008,0061)
            // Sending Modality (0008,0060) at the study level is NOT a valid study-level
            // matching key, so servers (e.g. dcm4chee) ignore it and return ALL studies
            // unfiltered — the bug this fixes.
            switch level {
            case .series:
                query = query.modality(modality)
            case .study, .instance:
                query = query.modalitiesInStudy(modality)
            }
        }
        if let studyDescription = studyDescription {
            query = query.studyDescription(studyDescription)
        }
        
        if verbose {
            fprintln("DICOMweb Server: \(baseURL)")
            fprintln("Query Level: \(level)")
            fprintln("Limit: \(limit), Offset: \(offset)")
            fprintln("")
        }
        
        // Execute query based on level
        switch level {
        case .study:
            let results = try await client.searchStudies(query: query)
            print(formatStudyResults(results, format: format))
            if verbose {
                fprintln("\nFound \(results.results.count) study(ies)")
            }
            
        case .series:
            if let studyUID = study {
                let results = try await client.searchSeries(studyUID: studyUID, query: query)
                print(formatSeriesResults(results, format: format))
                if verbose {
                    fprintln("\nFound \(results.results.count) series")
                }
            } else {
                let results = try await client.searchAllSeries(query: query)
                print(formatSeriesResults(results, format: format))
                if verbose {
                    fprintln("\nFound \(results.results.count) series")
                }
            }
            
        case .instance:
            if let studyUID = study, let seriesUID = series {
                let results = try await client.searchInstances(
                    studyUID: studyUID,
                    seriesUID: seriesUID,
                    query: query
                )
                print(formatInstanceResults(results, format: format))
                if verbose {
                    fprintln("\nFound \(results.results.count) instance(s)")
                }
            } else if let studyUID = study {
                let results = try await client.searchInstances(studyUID: studyUID, query: query)
                print(formatInstanceResults(results, format: format))
                if verbose {
                    fprintln("\nFound \(results.results.count) instance(s)")
                }
            } else {
                let results = try await client.searchAllInstances(query: query)
                print(formatInstanceResults(results, format: format))
                if verbose {
                    fprintln("\nFound \(results.results.count) instance(s)")
                }
            }
        }
    }
    
    // QIDO-RS result rendering is delegated to the SHARED `QIDOResultFormatter`
    // (DICOMWeb) — the single formatter the CLI Workshop's in-app query also calls,
    // so the CLI and app output pipelines cannot drift (mirrors how the DIMSE
    // `dicom-query` tool shares `DICOMQueryResultFormatter`).
    private func formatStudyResults(_ results: QIDOStudyResults, format: OutputFormat) -> String {
        QIDOResultFormatter().formatStudies(results.results, format: format.asQIDO)
    }

    private func formatSeriesResults(_ results: QIDOSeriesResults, format: OutputFormat) -> String {
        QIDOResultFormatter().formatSeries(results.results, format: format.asQIDO)
    }

    private func formatInstanceResults(_ results: QIDOInstanceResults, format: OutputFormat) -> String {
        QIDOResultFormatter().formatInstances(results.results, format: format.asQIDO)
    }
}

// MARK: - Store Command (STOW-RS)

@available(macOS 10.15, *)
struct StoreCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "store",
        abstract: "Upload DICOM instances using STOW-RS",
        discussion: """
            Stores one or more DICOM files to a DICOMweb server.
            
            Examples:
              dicom-wado store https://server/dicom-web file1.dcm file2.dcm
              dicom-wado store https://server/dicom-web study/*.dcm --study 1.2.3.4.5
              dicom-wado store https://server/dicom-web --input files.txt --batch 10
            """
    )
    
    @Argument(help: "DICOMweb server base URL")
    var baseURL: String
    
    @Argument(help: "DICOM files to upload (optional if --input is used)")
    var files: [String] = []
    
    @Option(name: .long, help: "Study Instance UID for targeted storage")
    var study: String?
    
    @Option(name: .long, help: "File containing list of DICOM files to upload (one per line)")
    var input: String?
    
    @Option(name: .long, help: "Number of files to upload per batch (default: 10)")
    var batch: Int = 10
    
    @Option(name: .long, help: "OAuth2 bearer token for authentication")
    var token: String?
    
    @Flag(name: .long, help: "Continue on errors instead of stopping")
    var continueOnError: Bool = false
    
    @Flag(name: .long, help: "Show verbose output including progress")
    var verbose: Bool = false
    
    func run() async throws {
        // Collect files to upload
        var filesToUpload = files
        
        if let inputFile = input {
            let inputURL = URL(fileURLWithPath: inputFile)
            let contents = try String(contentsOf: inputURL, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            filesToUpload.append(contentsOf: lines)
        }
        
        guard !filesToUpload.isEmpty else {
            throw ValidationError("No files specified. Use file arguments or --input option.")
        }
        
        // Configure client
        let config = try DICOMwebConfiguration(
            baseURLString: baseURL,
            authentication: token.map { .bearer(token: $0) }
        )
        
        let client = DICOMwebClient(configuration: config)

        // Console rendering is delegated to the SHARED STOWResultFormatter (DICOMWeb) —
        // the single store-output renderer the CLI Workshop's in-app STOW upload also
        // calls, so the CLI and app output pipelines cannot drift (mirrors
        // QIDOResultFormatter for the query subcommand). The "Upload Summary" block is a
        // parity contract parsed by CLIParityWADOComparator.parseStore.
        let stowFmt = STOWResultFormatter()

        if verbose {
            fprintln(stowFmt.header(baseURL: baseURL, targetStudyUID: study,
                                    fileCount: filesToUpload.count, batchSize: batch))
            fprintln("")
        }
        
        // Upload in batches
        var totalSuccess = 0
        var totalFailure = 0
        
        for (batchIndex, batchFiles) in filesToUpload.chunked(into: batch).enumerated() {
            if verbose {
                fprintln(stowFmt.batchStart(batchNumber: batchIndex + 1, fileCount: batchFiles.count))
            }
            
            // Load batch files
            var instances: [Data] = []
            for filePath in batchFiles {
                do {
                    let fileURL = URL(fileURLWithPath: filePath)
                    let data = try Data(contentsOf: fileURL)
                    instances.append(data)
                } catch {
                    if continueOnError {
                        fprintln("Error reading \(filePath): \(error)", to: .standardError)
                        totalFailure += 1
                        continue
                    } else {
                        throw error
                    }
                }
            }
            
            // Upload batch
            do {
                let response = try await client.storeInstances(instances: instances, studyUID: study)
                
                let successCount = response.successCount
                let failureCount = response.failureCount
                
                totalSuccess += successCount
                totalFailure += failureCount
                
                if verbose {
                    fprintln(stowFmt.batchResult(success: successCount, failure: failureCount))
                    for failure in response.failedInstances {
                        let reason = stowFmt.failureReason(description: failure.failureDescription,
                                                           code: failure.failureReason)
                        fprintln(stowFmt.failureDetail(sopInstanceUID: failure.sopInstanceUID, reason: reason))
                    }
                }
            } catch {
                if continueOnError {
                    fprintln("Error uploading batch \(batchIndex + 1): \(error)", to: .standardError)
                    totalFailure += batchFiles.count
                    continue
                } else {
                    throw error
                }
            }
        }
        
        // Summary
        fprintln(stowFmt.summary(total: filesToUpload.count, succeeded: totalSuccess, failed: totalFailure))
        
        if totalFailure > 0 && !continueOnError {
            throw ExitCode.failure
        }
    }
}

// MARK: - UPS Command

@available(macOS 10.15, *)
struct UPSCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ups",
        abstract: "Unified Procedure Step Worklist operations (UPS-RS)",
        discussion: """
            Manages worklist items using UPS-RS protocol.
            
            Examples:
              dicom-wado ups https://server/dicom-web --search
              dicom-wado ups https://server/dicom-web --get <workitem-uid>
              dicom-wado ups https://server/dicom-web --create worklist.json
              dicom-wado ups https://server/dicom-web --create-workitem --label "CT Scan" --patient-name "Doe^Jane" --patient-id PAT001
              dicom-wado ups https://server/dicom-web --update <uid> --state IN_PROGRESS --aet MY_AE
              dicom-wado ups https://server/dicom-web --update <uid> --state COMPLETED --aet MY_AE --transaction-uid <txuid>
              dicom-wado ups https://server/dicom-web --subscribe --workitem-uid <uid> --aet MY_AE
              dicom-wado ups https://server/dicom-web --unsubscribe --workitem-uid <uid> --aet MY_AE
            """
    )
    
    @Argument(help: "DICOMweb server base URL")
    var baseURL: String
    
    @Flag(name: .long, help: "Search for worklist items")
    var search: Bool = false
    
    @Option(name: .long, help: "Get specific worklist item by UID")
    var get: String?
    
    @Option(name: .long, help: "Create worklist item from JSON file")
    var create: String?
    
    @Flag(name: .customLong("create-workitem"), help: "Create a new worklist item from command-line options")
    var createWorkitemFlag: Bool = false
    
    @Option(name: .long, help: "Update worklist item UID")
    var update: String?
    
    @Flag(name: .long, help: "Subscribe to workitem events (requires --workitem-uid and --aet)")
    var subscribe: Bool = false
    
    @Flag(name: .long, help: "Unsubscribe from workitem events (requires --workitem-uid and --aet)")
    var unsubscribe: Bool = false
    
    @Option(name: .long, help: "Local Application Entity Title for subscribe/unsubscribe")
    var aet: String?
    
    @Option(name: .long, help: "New state for update: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELED")
    var state: String?
    
    @Option(name: .long, help: "Transaction UID for state changes (required for COMPLETED/CANCELED; auto-generated for IN_PROGRESS)")
    var transactionUID: String?
    
    // MARK: - Search Filters
    
    @Option(name: .long, help: "Filter by procedure step state")
    var filterState: String?
    
    @Option(name: .long, help: "Filter by scheduled station AE")
    var scheduledStation: String?
    
    // MARK: - Create Workitem Options
    
    @Option(name: .long, help: "Workitem UID (auto-generated if omitted)")
    var workitemUID: String?
    
    @Option(name: .long, help: "Procedure step label (e.g. 'CT Scan Chest')")
    var label: String?
    
    @Option(name: .long, help: "Patient name in DICOM format (e.g. 'Doe^Jane')")
    var patientName: String?
    
    @Option(name: .long, help: "Patient ID")
    var patientID: String?
    
    @Option(name: .long, help: "Priority: STAT, HIGH, MEDIUM, LOW (default: MEDIUM)")
    var priority: String?
    
    @Option(name: .long, help: "Patient birth date (YYYYMMDD)")
    var patientBirthDate: String?
    
    @Option(name: .long, help: "Patient sex: M, F, O")
    var patientSex: String?
    
    @Option(name: .long, help: "Study Instance UID to reference")
    var studyUID: String?
    
    @Option(name: .long, help: "Accession number")
    var accessionNumber: String?
    
    @Option(name: .long, help: "Referring physician name")
    var referringPhysician: String?
    
    @Option(name: .long, help: "Requested procedure ID")
    var procedureID: String?
    
    @Option(name: .long, help: "Scheduled procedure step ID")
    var stepID: String?
    
    @Option(name: .long, help: "Worklist label")
    var worklistLabel: String?
    
    @Option(name: .long, help: "Comments on the procedure step")
    var comments: String?
    
    @Option(name: .long, help: "Scheduled start date/time (ISO 8601, e.g. '2026-03-20T14:00:00')")
    var scheduledStart: String?
    
    @Option(name: .long, help: "Expected completion date/time (ISO 8601)")
    var expectedCompletion: String?
    
    @Option(name: .long, help: "Scheduled station name")
    var stationName: String?
    
    @Option(name: .long, help: "Performer name")
    var performerName: String?
    
    @Option(name: .long, help: "Performer organization")
    var performerOrganization: String?
    
    @Option(name: .long, help: "Admission ID")
    var admissionID: String?
    
    // MARK: - Common Options
    
    @Option(name: .long, help: "OAuth2 bearer token for authentication")
    var token: String?
    
    @Option(name: .shortAndLong, help: "Output format: table, json (default: table)")
    var format: OutputFormat = .table
    
    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false
    
    func run() async throws {
        // Configure client
        let config = try DICOMwebConfiguration(
            baseURLString: baseURL,
            authentication: token.map { .bearer(token: $0) }
        )
        
        let client = DICOMwebClient(configuration: config)
        
        if verbose {
            fprintln("DICOMweb Server: \(baseURL)")
        }
        
        if search {
            try await searchWorkitems(client: client)
        } else if let uid = get {
            try await getWorkitem(client: client, uid: uid)
        } else if let jsonFile = create {
            try await createWorkitemFromJSON(client: client, jsonFile: jsonFile)
        } else if createWorkitemFlag {
            try await createWorkitemFromOptions(client: client)
        } else if let uid = update {
            try await updateWorkitem(client: client, uid: uid)
        } else if subscribe {
            try await subscribeToWorkitem(client: client)
        } else if unsubscribe {
            try await unsubscribeFromWorkitem(client: client)
        } else {
            throw ValidationError("Specify an operation: --search, --get, --create, --create-workitem, --update, --subscribe, or --unsubscribe")
        }
    }
    
    private func searchWorkitems(client: DICOMwebClient) async throws {
        // Build query via the SHARED UPSQuery.workitemSearch builder (DICOMWeb) — the
        // single source of truth the CLI Workshop's in-app search and the CLI-parity
        // reference also call, so the three issue an IDENTICAL UPS-RS query. Maps only
        // the two real search flags (--filter-state / --scheduled-station).
        let query: UPSQuery
        do {
            query = try UPSQuery.workitemSearch(filterState: filterState, scheduledStation: scheduledStation)
        } catch let error as UPSSearchFilterError {
            throw ValidationError(error.description)
        }

        if verbose {
            fprintln("Searching worklist items...")
        }

        let results = try await client.searchWorkitems(query: query)

        // Render via the SHARED UPSResultFormatter — the single workitem-search renderer
        // the CLI Workshop also calls, so the CLI and app output pipelines cannot drift
        // (mirrors QIDOResultFormatter for the query subcommand).
        print(UPSResultFormatter().format(results.workitems, format: format.asUPS))

        if verbose {
            fprintln("\nFound \(results.workitems.count) worklist item(s)")
        }
    }
    
    private func getWorkitem(client: DICOMwebClient, uid: String) async throws {
        if verbose {
            fprintln("Retrieving worklist item: \(uid)")
        }

        // Render via the SHARED UPSResultFormatter, honoring --format (table/json/csv) —
        // the SAME renderer --search uses, so get and search share one output pipeline and
        // the CLI Workshop's in-app get cannot drift. retrieveWorkitemResult returns the
        // WorkitemResult the formatter consumes (mirrors the package's UPS --format contract).
        let result = try await client.retrieveWorkitemResult(uid: uid)
        print(UPSResultFormatter().format([result], format: format.asUPS))

        if verbose {
            fprintln("\nRetrieved worklist item \(uid)")
        }
    }
    
    private func createWorkitemFromJSON(client: DICOMwebClient, jsonFile: String) async throws {
        if verbose {
            fprintln("Creating worklist item from: \(jsonFile)")
        }
        
        let fileURL = URL(fileURLWithPath: jsonFile)
        let jsonData = try Data(contentsOf: fileURL)
        let workitemData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        guard let workitemData = workitemData else {
            throw ValidationError("Invalid JSON format in \(jsonFile)")
        }
        
        let response = try await client.createWorkitem(workitem: workitemData)
        
        printCreateResponse(response)
    }
    
    private func createWorkitemFromOptions(client: DICOMwebClient) async throws {
        guard let stepLabel = label else {
            throw ValidationError("--label is required when using --create-workitem")
        }
        
        // Generate a UID if not provided
        let uid = workitemUID ?? generateDICOMUID()
        
        if verbose {
            fprintln("Creating worklist item from command-line options...")
            fprintln("  UID: \(uid)")
            fprintln("  Label: \(stepLabel)")
        }
        
        let builder = WorkitemBuilder(workitemUID: uid)
            .setState(.scheduled)
            .setProcedureStepLabel(stepLabel)
        
        // Priority
        if let priorityStr = priority {
            let p = try parsePriority(priorityStr)
            builder.setPriority(p)
        }
        
        // Patient info
        if let name = patientName { builder.setPatientName(name) }
        if let pid = patientID { builder.setPatientID(pid) }
        if let dob = patientBirthDate { builder.setPatientBirthDate(dob) }
        if let sex = patientSex {
            let normalized = sex.uppercased()
            guard ["M", "F", "O"].contains(normalized) else {
                throw ValidationError("Invalid patient sex '\(sex)'. Valid values: M, F, O")
            }
            builder.setPatientSex(normalized)
        }
        
        // Study reference
        if let studyRef = studyUID { builder.setStudyInstanceUID(studyRef) }
        if let accession = accessionNumber { builder.setAccessionNumber(accession) }
        if let referring = referringPhysician { builder.setReferringPhysicianName(referring) }
        if let procID = procedureID { builder.setRequestedProcedureID(procID) }
        
        // Scheduling IDs
        if let sid = stepID { builder.setScheduledProcedureStepID(sid) }
        if let wlLabel = worklistLabel { builder.setWorklistLabel(wlLabel) }
        if let cmt = comments { builder.setComments(cmt) }
        
        // Dates
        if let startStr = scheduledStart {
            let date = try parseISO8601Date(startStr, label: "--scheduled-start")
            builder.setScheduledStartDateTime(date)
        }
        if let completionStr = expectedCompletion {
            let date = try parseISO8601Date(completionStr, label: "--expected-completion")
            builder.setExpectedCompletionDateTime(date)
        }
        
        // Station
        if let station = stationName {
            builder.setScheduledStationNameCodes([
                CodedEntry(codeValue: station, codingSchemeDesignator: "L", codeMeaning: station)
            ])
        }
        
        // Performer
        if performerName != nil || performerOrganization != nil {
            let performer = HumanPerformer(
                performerName: performerName,
                performerOrganization: performerOrganization
            )
            builder.addScheduledHumanPerformer(performer)
        }
        
        // Admission
        if let admID = admissionID { builder.setAdmissionID(admID) }
        
        let workitem = try builder.build()
        let response = try await client.createWorkitem(workitem)
        
        printCreateResponse(response)
    }
    
    private func printCreateResponse(_ response: UPSCreateResponse) {
        fprintln("Created worklist item:")
        fprintln("  UID: \(response.workitemUID)")
        if let url = response.retrieveURL {
            fprintln("  Retrieve URL: \(url)")
        }
        if !response.warnings.isEmpty {
            fprintln("  Warnings:")
            for warning in response.warnings {
                fprintln("    - \(warning)")
            }
        }
    }
    
    private func parsePriority(_ value: String) throws -> UPSPriority {
        switch value.uppercased() {
        case "STAT": return .stat
        case "HIGH": return .high
        case "MEDIUM": return .medium
        case "LOW": return .low
        default:
            throw ValidationError("Invalid priority '\(value)'. Valid values: STAT, HIGH, MEDIUM, LOW")
        }
    }
    
    private func parseISO8601Date(_ value: String, label: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }
        // Try date-only plus basic datetime formats
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
            fallback.dateFormat = fmt
            if let date = fallback.date(from: value) {
                return date
            }
        }
        throw ValidationError("Invalid date format for \(label): '\(value)'. Use ISO 8601 (e.g. 2026-03-20T14:00:00)")
    }
    
    private func generateDICOMUID() -> String {
        // Use DICOMKit root 1.2.826.0.1.3680043.8.498 with process/time-based suffix
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000000)
        let random = UInt32.random(in: 1...999999)
        return "1.2.826.0.1.3680043.8.498.\(timestamp).\(random)"
    }
    
    private func updateWorkitem(client: DICOMwebClient, uid: String) async throws {
        guard let stateString = state else {
            throw ValidationError("--state is required for update operations")
        }
        
        // Parse state string to UPSState
        let newState: UPSState
        switch stateString.uppercased() {
        case "SCHEDULED":
            newState = .scheduled
        case "IN_PROGRESS", "INPROGRESS":
            newState = .inProgress
        case "COMPLETED":
            newState = .completed
        case "CANCELED":
            newState = .canceled
        default:
            throw ValidationError("Invalid state: \(stateString). Valid states: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELED")
        }
        
        // Determine transaction UID:
        // - IN_PROGRESS: auto-generate if not provided (server returns one in response)
        // - COMPLETED/CANCELED: required (must match the one from IN_PROGRESS transition)
        let effectiveTxUID: String?
        switch newState {
        case .inProgress:
            effectiveTxUID = transactionUID ?? generateDICOMUID()
        case .completed, .canceled:
            guard let txUID = transactionUID else {
                throw ValidationError("--transaction-uid is required for \(newState.rawValue) transition (use the UID returned from IN_PROGRESS)")
            }
            effectiveTxUID = txUID
        default:
            effectiveTxUID = transactionUID
        }
        
        // Per PS3.18 §11.6, DCM4CHEE requires the Requesting AE as the
        // last path segment of the state URL; without it the route returns 404.
        let requestingAE = aet
        
        if verbose {
            fprintln("Updating worklist item \(uid) to state: \(newState.rawValue)")
            if let ae = requestingAE { fprintln("  Requesting AE: \(ae)") }
            if let tx = effectiveTxUID { fprintln("  Transaction UID: \(tx)") }
        }
        
        // Per PS3.4 CC.2.1.3/Table CC.2.5-3, the SCP validates that the Unified
        // Procedure Step Performed Procedure Sequence (0074,1216) is populated
        // before allowing transition to COMPLETED. The shared client helper sends
        // a minimal Update Workitem (PS3.18 §11.5) to satisfy this and then
        // performs the Change State — a single source of truth shared with the
        // CLI-parity reference so the two cannot drift.
        let response: UPSStateChangeResponse
        if newState == .completed, let txUID = effectiveTxUID {
            if verbose {
                fprintln("Updating workitem with Final State attributes (required before COMPLETED)...")
            }
            response = try await client.completeWorkitem(
                uid: uid,
                transactionUID: txUID,
                requestingAE: requestingAE
            )
            if verbose {
                fprintln("Final State attributes updated successfully")
            }
        } else {
            response = try await client.changeWorkitemState(
                uid: uid,
                state: newState,
                transactionUID: effectiveTxUID,
                requestingAE: requestingAE
            )
        }

        fprintln("Successfully updated worklist item \(uid) to \(newState.rawValue)")
        if let txUID = response.transactionUID {
            fprintln("Transaction UID: \(txUID)")
        }
        if !response.warnings.isEmpty {
            for warning in response.warnings {
                fprintln("Warning: \(warning)")
            }
        }
    }
    
    private func subscribeToWorkitem(client: DICOMwebClient) async throws {
        guard let aeTitle = aet else {
            throw ValidationError("--aet is required for subscribe operations")
        }
        
        let uid = workitemUID
        
        if verbose {
            if let uid = uid {
                fprintln("Subscribing to workitem \(uid) as \(aeTitle) ...")
            } else {
                fprintln("Subscribing globally as \(aeTitle) ...")
            }
        }
        
        try await client.subscribeToWorkitem(workitemUID: uid, aeTitle: aeTitle)
        
        if let uid = uid {
            fprintln("Subscription created for workitem \(uid)")
            
            // Fetch and display workitem details
            if verbose {
                fprintln("\nFetching workitem details...")
                do {
                    let result = try await client.retrieveWorkitemResult(uid: uid)
                    fprintln("  Workitem UID:   \(result.workitemUID)")
                    if let label = result.procedureStepLabel { fprintln("  Procedure:      \(label)") }
                    if let state = result.state { fprintln("  State:          \(state.rawValue)") }
                    if let priority = result.priority { fprintln("  Priority:       \(priority.rawValue)") }
                    if let name = result.patientName { fprintln("  Patient Name:   \(name)") }
                    if let pid = result.patientID { fprintln("  Patient ID:     \(pid)") }
                    if let scheduled = result.scheduledStartDateTime { fprintln("  Scheduled:      \(scheduled)") }
                } catch {
                    fprintln("  (Could not fetch workitem details: \(error.localizedDescription))")
                }
            }
        } else {
            fprintln("Global subscription created for AE \(aeTitle)")
        }
    }
    
    private func unsubscribeFromWorkitem(client: DICOMwebClient) async throws {
        guard let aeTitle = aet else {
            throw ValidationError("--aet is required for unsubscribe operations")
        }
        
        let uid = workitemUID
        
        if verbose {
            if let uid = uid {
                fprintln("Unsubscribing from workitem \(uid) as \(aeTitle) ...")
            } else {
                fprintln("Unsubscribing globally as \(aeTitle) ...")
            }
        }
        
        try await client.unsubscribeFromWorkitem(workitemUID: uid, aeTitle: aeTitle)
        
        if let uid = uid {
            fprintln("Unsubscribed from workitem \(uid)")
        } else {
            fprintln("Global subscription removed for AE \(aeTitle)")
        }
    }
    
}

// MARK: - Supporting Types

enum QueryLevel: String, ExpressibleByArgument {
    case study
    case series
    case instance
}

enum OutputFormat: String, ExpressibleByArgument {
    case table
    case json
    case csv

    /// Bridges the CLI's `--format` to the shared `QIDOResultFormatter` (DICOMWeb).
    /// The cases line up 1:1, so the rawValue maps directly (table is the fallback).
    var asQIDO: QIDOOutputFormat { QIDOOutputFormat(rawValue: rawValue) ?? .table }

    /// Bridges the CLI's `--format` to the shared `UPSResultFormatter` (DICOMWeb).
    /// The cases line up 1:1, so the rawValue maps directly (table is the fallback).
    var asUPS: UPSOutputFormat { UPSOutputFormat(rawValue: rawValue) ?? .table }
}

enum MetadataFormat: String, ExpressibleByArgument {
    case json
    case xml
}

// MARK: - Helper Functions

func fprintln(_ message: String = "", to stream: Stream = .standardOutput) {
    let handle = stream == .standardOutput ? FileHandle.standardOutput : FileHandle.standardError
    if let data = (message + "\n").data(using: .utf8) {
        handle.write(data)
    }
}

enum Stream {
    case standardOutput
    case standardError
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


