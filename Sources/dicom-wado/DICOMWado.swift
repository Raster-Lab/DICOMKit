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
            fprintln("DICOMweb Server: \(baseURL)")
            fprintln("Study UID: \(studyUID)")
            if let seriesUID = series {
                fprintln("Series UID: \(seriesUID)")
            }
            if let instanceUID = instance {
                fprintln("Instance UID: \(instanceUID)")
            }
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
        
        let wadoContentType: WADOURIClient.ContentType
        switch contentType?.lowercased() {
        case "image/jpeg", "jpeg":  wadoContentType = .jpeg
        case "image/png", "png":    wadoContentType = .png
        case "image/gif", "gif":    wadoContentType = .gif
        case "image/jp2", "jp2":    wadoContentType = .jpeg2000
        case "video/mpeg", "mpeg":  wadoContentType = .mpeg
        default:                     wadoContentType = .dicom
        }
        
        let frameNumber: Int?
        if let framesString = frames,
           let first = framesString.split(separator: ",").first,
           let num = Int(first.trimmingCharacters(in: .whitespaces)) {
            frameNumber = num
        } else {
            frameNumber = nil
        }
        
        if verbose {
            fprintln("WADO-URI Server: \(baseURL)")
            fprintln("Protocol:     WADO-URI (PS3.18 §8)")
            fprintln("Study UID:    \(studyUID)")
            fprintln("Series UID:   \(seriesUID)")
            fprintln("Instance UID: \(instanceUID)")
            fprintln("Content-Type: \(wadoContentType.rawValue)")
            if let frame = frameNumber {
                fprintln("Frame:        \(frame)")
            }
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
        case .dicom:    ext = "dcm"
        case .jpeg:     ext = "jpg"
        case .png:      ext = "png"
        case .gif:      ext = "gif"
        case .jpeg2000: ext = "jp2"
        case .mpeg:     ext = "mpg"
        }
        let filename = "\(instanceUID)\(frameSuffix).\(ext)"
        try saveData(result.data, filename: filename)
        
        if verbose {
            fprintln("Retrieved \(result.data.count) bytes via WADO-URI")
            fprintln("Saved to: \(output ?? FileManager.default.currentDirectoryPath)/\(filename)")
        } else {
            fprintln("Retrieved \(result.data.count) bytes → \(filename)")
        }
    }
    
    private func retrieveMetadata(client: DICOMwebClient, studyUID: String) async throws {
        if verbose {
            fprintln("Retrieving metadata...")
        }
        
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
        
        // Format and output
        let output = try formatMetadata(metadata, format: format)
        print(output)
        
        if verbose {
            fprintln("\nRetrieved metadata for \(metadata.count) instance(s)")
        }
    }
    
    private func retrieveRendered(client: DICOMwebClient, studyUID: String) async throws {
        guard let instanceUID = instance, let seriesUID = series else {
            throw ValidationError("--series and --instance are required for rendered retrieval")
        }
        
        if verbose {
            fprintln("Retrieving rendered image...")
        }
        
        let imageData = try await client.retrieveRenderedInstance(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        
        try saveData(imageData, filename: "rendered_\(instanceUID).jpg")
        
        if verbose {
            fprintln("Saved rendered image (\(imageData.count) bytes)")
        }
    }
    
    private func retrieveThumbnail(client: DICOMwebClient, studyUID: String) async throws {
        if verbose {
            fprintln("Retrieving thumbnail...")
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
            fprintln("Saved thumbnail (\(thumbnailData.count) bytes)")
        }
    }
    
    private func retrieveFrames(client: DICOMwebClient, studyUID: String, framesString: String) async throws {
        guard let instanceUID = instance, let seriesUID = series else {
            throw ValidationError("--series and --instance are required for frame retrieval")
        }
        
        let frameNumbers = try parseFrameNumbers(framesString)
        
        if verbose {
            fprintln("Retrieving frames: \(frameNumbers.map(String.init).joined(separator: ", "))...")
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
                fprintln("Saved frame \(frame.frameNumber) (\(frame.data.count) bytes)")
            }
        }
        
        if verbose {
            fprintln("\nRetrieved \(frames.count) frame(s)")
        }
    }
    
    private func retrieveInstances(client: DICOMwebClient, studyUID: String) async throws {
        if verbose {
            fprintln("Retrieving DICOM instances...")
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
                fprintln("Saved instance (\(instanceData.count) bytes)")
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
                    fprintln("Saved instance \(index + 1) (\(instanceData.count) bytes)")
                }
            }
            if verbose {
                fprintln("\nRetrieved \(result.instances.count) instance(s)")
            }
        } else {
            // Full study
            let result = try await client.retrieveStudy(studyUID: studyUID)
            for (index, instanceData) in result.instances.enumerated() {
                let filename = "instance_\(index + 1).dcm"
                try saveData(instanceData, filename: filename)
                if verbose {
                    fprintln("Saved instance \(index + 1) (\(instanceData.count) bytes)")
                }
            }
            if verbose {
                fprintln("\nRetrieved \(result.instances.count) instance(s)")
            }
        }
    }
    
    private func parseFrameNumbers(_ framesString: String) throws -> [Int] {
        let components = framesString.split(separator: ",")
        return try components.map { component in
            guard let number = Int(component.trimmingCharacters(in: .whitespaces)) else {
                throw ValidationError("Invalid frame number: \(component)")
            }
            guard number > 0 else {
                throw ValidationError("Frame numbers must be positive: \(number)")
            }
            return number
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
    
    private func formatMetadata(_ metadata: [[String: Any]], format: MetadataFormat) throws -> String {
        switch format {
        case .json:
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? ""
        case .xml:
            // XML formatting would require DICOM XML encoder
            throw ValidationError("XML format not yet implemented")
        }
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
            query = query.modality(modality)
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
    
    private func formatStudyResults(_ results: QIDOStudyResults, format: OutputFormat) -> String {
        switch format {
        case .table:
            return formatStudyTable(results.results)
        case .json:
            let dicts: [[String: Any]] = results.results.map { study in
                var dict: [String: Any] = [:]
                if let v = study.studyInstanceUID { dict["StudyInstanceUID"] = v }
                if let v = study.patientName { dict["PatientName"] = v }
                if let v = study.patientID { dict["PatientID"] = v }
                if let v = study.studyDate { dict["StudyDate"] = v }
                if let v = study.studyTime { dict["StudyTime"] = v }
                if let v = study.studyDescription { dict["StudyDescription"] = v }
                if let v = study.accessionNumber { dict["AccessionNumber"] = v }
                if let v = study.studyID { dict["StudyID"] = v }
                if let v = study.referringPhysicianName { dict["ReferringPhysicianName"] = v }
                if let v = study.numberOfStudyRelatedSeries { dict["NumberOfStudyRelatedSeries"] = v }
                if let v = study.numberOfStudyRelatedInstances { dict["NumberOfStudyRelatedInstances"] = v }
                if !study.modalitiesInStudy.isEmpty { dict["ModalitiesInStudy"] = study.modalitiesInStudy }
                if let v = study.patientBirthDate { dict["PatientBirthDate"] = v }
                if let v = study.patientSex { dict["PatientSex"] = v }
                return dict
            }
            return formatJSON(dicts)
        case .csv:
            return formatStudyCSV(results.results)
        }
    }
    
    private func formatSeriesResults(_ results: QIDOSeriesResults, format: OutputFormat) -> String {
        switch format {
        case .table:
            return formatSeriesTable(results.results)
        case .json:
            let dicts: [[String: Any]] = results.results.map { s in
                var dict: [String: Any] = [:]
                if let v = s.seriesInstanceUID { dict["SeriesInstanceUID"] = v }
                if let v = s.studyInstanceUID { dict["StudyInstanceUID"] = v }
                if let v = s.modality { dict["Modality"] = v }
                if let v = s.seriesNumber { dict["SeriesNumber"] = v }
                if let v = s.seriesDescription { dict["SeriesDescription"] = v }
                if let v = s.bodyPartExamined { dict["BodyPartExamined"] = v }
                if let v = s.performedProcedureStepStartDate { dict["PerformedProcedureStepStartDate"] = v }
                if let v = s.numberOfSeriesRelatedInstances { dict["NumberOfSeriesRelatedInstances"] = v }
                return dict
            }
            return formatJSON(dicts)
        case .csv:
            return formatSeriesCSV(results.results)
        }
    }
    
    private func formatInstanceResults(_ results: QIDOInstanceResults, format: OutputFormat) -> String {
        switch format {
        case .table:
            return formatInstanceTable(results.results)
        case .json:
            let dicts: [[String: Any]] = results.results.map { instance in
                var dict: [String: Any] = [:]
                if let v = instance.sopInstanceUID { dict["SOPInstanceUID"] = v }
                if let v = instance.sopClassUID { dict["SOPClassUID"] = v }
                if let v = instance.instanceNumber { dict["InstanceNumber"] = v }
                if let v = instance.numberOfFrames { dict["NumberOfFrames"] = v }
                if let v = instance.rows { dict["Rows"] = v }
                if let v = instance.columns { dict["Columns"] = v }
                if let v = instance.seriesInstanceUID { dict["SeriesInstanceUID"] = v }
                if let v = instance.studyInstanceUID { dict["StudyInstanceUID"] = v }
                return dict
            }
            return formatJSON(dicts)
        case .csv:
            return formatInstanceCSV(results.results)
        }
    }
    
    private func formatStudyTable(_ studies: [QIDOStudyResult]) -> String {
        var output = ""
        output += String(repeating: "=", count: 120) + "\n"
        output += pad("Study UID", 20) + " " + pad("Patient Name", 30) + " " + pad("Study Date", 20) + " " + pad("Modality", 10) + " " + pad("# Series", 10) + "\n"
        output += String(repeating: "=", count: 120) + "\n"
        
        for study in studies {
            let studyUID = truncate(study.studyInstanceUID ?? "", maxLength: 20)
            let patientName = truncate(study.patientName ?? "", maxLength: 30)
            let studyDate = study.studyDate ?? ""
            let modality = truncate(study.modalitiesInStudy.joined(separator: ", "), maxLength: 10)
            let numSeries = study.numberOfStudyRelatedSeries ?? 0
            
            output += pad(studyUID, 20) + " " + pad(patientName, 30) + " " + pad(studyDate, 20) + " " + pad(modality, 10) + " " + pad("\(numSeries)", 10) + "\n"
        }
        
        output += String(repeating: "=", count: 120) + "\n"
        return output
    }
    
    private func formatSeriesTable(_ series: [QIDOSeriesResult]) -> String {
        var output = ""
        output += String(repeating: "=", count: 100) + "\n"
        output += pad("Series UID", 25) + " " + pad("Modality", 10) + " " + pad("Description", 30) + " " + pad("# Images", 10) + "\n"
        output += String(repeating: "=", count: 100) + "\n"
        
        for s in series {
            let seriesUID = truncate(s.seriesInstanceUID ?? "", maxLength: 25)
            let modality = s.modality ?? ""
            let description = truncate(s.seriesDescription ?? "", maxLength: 30)
            let numInstances = s.numberOfSeriesRelatedInstances ?? 0
            
            output += pad(seriesUID, 25) + " " + pad(modality, 10) + " " + pad(description, 30) + " " + pad("\(numInstances)", 10) + "\n"
        }
        
        output += String(repeating: "=", count: 100) + "\n"
        return output
    }
    
    private func formatInstanceTable(_ instances: [QIDOInstanceResult]) -> String {
        var output = ""
        output += String(repeating: "=", count: 80) + "\n"
        output += pad("SOP Instance UID", 30) + " " + pad("SOP Class", 15) + " " + pad("# Frames", 10) + "\n"
        output += String(repeating: "=", count: 80) + "\n"
        
        for instance in instances {
            let sopUID = truncate(instance.sopInstanceUID ?? "", maxLength: 30)
            let sopClass = truncate(instance.sopClassUID ?? "", maxLength: 15)
            let numFrames = instance.numberOfFrames ?? 1
            
            output += pad(sopUID, 30) + " " + pad(sopClass, 15) + " " + pad("\(numFrames)", 10) + "\n"
        }
        
        output += String(repeating: "=", count: 80) + "\n"
        return output
    }
    
    private func formatStudyCSV(_ studies: [QIDOStudyResult]) -> String {
        var output = "StudyInstanceUID,PatientName,PatientID,StudyDate,StudyDescription,ModalitiesInStudy,NumberOfSeries\n"
        for study in studies {
            let studyUID = csvEscape(study.studyInstanceUID ?? "")
            let patientName = csvEscape(study.patientName ?? "")
            let patientID = csvEscape(study.patientID ?? "")
            let studyDate = study.studyDate ?? ""
            let description = csvEscape(study.studyDescription ?? "")
            let modalities = csvEscape(study.modalitiesInStudy.joined(separator: ";"))
            let numSeries = study.numberOfStudyRelatedSeries ?? 0
            
            output += "\(studyUID),\(patientName),\(patientID),\(studyDate),\(description),\(modalities),\(numSeries)\n"
        }
        return output
    }
    
    private func formatSeriesCSV(_ series: [QIDOSeriesResult]) -> String {
        var output = "SeriesInstanceUID,StudyInstanceUID,Modality,SeriesNumber,SeriesDescription,NumberOfInstances\n"
        for s in series {
            let seriesUID = csvEscape(s.seriesInstanceUID ?? "")
            let studyUID = csvEscape(s.studyInstanceUID ?? "")
            let modality = s.modality ?? ""
            let seriesNumber = s.seriesNumber ?? 0
            let description = csvEscape(s.seriesDescription ?? "")
            let numInstances = s.numberOfSeriesRelatedInstances ?? 0
            
            output += "\(seriesUID),\(studyUID),\(modality),\(seriesNumber),\(description),\(numInstances)\n"
        }
        return output
    }
    
    private func formatInstanceCSV(_ instances: [QIDOInstanceResult]) -> String {
        var output = "SOPInstanceUID,SeriesInstanceUID,SOPClassUID,InstanceNumber,NumberOfFrames\n"
        for instance in instances {
            let sopUID = csvEscape(instance.sopInstanceUID ?? "")
            let seriesUID = csvEscape(instance.seriesInstanceUID ?? "")
            let sopClass = csvEscape(instance.sopClassUID ?? "")
            let instanceNumber = instance.instanceNumber ?? 0
            let numFrames = instance.numberOfFrames ?? 1
            
            output += "\(sopUID),\(seriesUID),\(sopClass),\(instanceNumber),\(numFrames)\n"
        }
        return output
    }
    
    private func formatJSON(_ data: [[String: Any]]) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
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
        
        if verbose {
            fprintln("DICOMweb Server: \(baseURL)")
            if let studyUID = study {
                fprintln("Target Study: \(studyUID)")
            }
            fprintln("Files to upload: \(filesToUpload.count)")
            fprintln("Batch size: \(batch)")
            fprintln("")
        }
        
        // Upload in batches
        var totalSuccess = 0
        var totalFailure = 0
        
        for (batchIndex, batchFiles) in filesToUpload.chunked(into: batch).enumerated() {
            if verbose {
                fprintln("Batch \(batchIndex + 1): Uploading \(batchFiles.count) file(s)...")
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
                    fprintln("  Success: \(successCount), Failure: \(failureCount)")
                    if !response.failedInstances.isEmpty {
                        for failure in response.failedInstances {
                            let reason = failure.failureDescription ?? (failure.failureReason.map { "Code \($0)" } ?? "unknown error")
                            fprintln("    Failed: \(failure.sopInstanceUID ?? "unknown") - \(reason)")
                        }
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
        fprintln("\nUpload Summary:")
        fprintln("  Total files: \(filesToUpload.count)")
        fprintln("  Successful: \(totalSuccess)")
        fprintln("  Failed: \(totalFailure)")
        
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
        // Build query using fluent API
        var query = UPSQuery()
        
        if let filterStateStr = filterState {
            // Parse state string to UPSState
            switch filterStateStr.uppercased() {
            case "SCHEDULED":
                query = query.state(.scheduled)
            case "IN_PROGRESS", "INPROGRESS":
                query = query.state(.inProgress)
            case "COMPLETED":
                query = query.state(.completed)
            case "CANCELED":
                query = query.state(.canceled)
            default:
                throw ValidationError("Invalid state: \(filterStateStr). Valid states: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELED")
            }
        }
        if let scheduledStation = scheduledStation {
            query = query.scheduledStationName(scheduledStation)
        }
        
        if verbose {
            fprintln("Searching worklist items...")
        }
        
        let results = try await client.searchWorkitems(query: query)
        
        switch format {
        case .table:
            print(formatWorkitemTable(results.workitems))
        case .json:
            print(formatWorkitemJSON(results.workitems))
        case .csv:
            print(formatWorkitemCSV(results.workitems))
        }
        
        if verbose {
            fprintln("\nFound \(results.workitems.count) worklist item(s)")
        }
    }
    
    private func getWorkitem(client: DICOMwebClient, uid: String) async throws {
        if verbose {
            fprintln("Retrieving worklist item: \(uid)")
        }
        
        let workitem = try await client.retrieveWorkitem(uid: uid)
        
        let jsonData = try JSONSerialization.data(
            withJSONObject: workitem,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
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
        
        // Per PS3.4 CC.2.1.3/Table CC.2.5-3, the SCP validates that
        // Unified Procedure Step Performed Procedure Sequence (0074,1216)
        // is populated before allowing transition to COMPLETED.
        // Send a minimal Update Workitem (PS3.18 §11.5) to satisfy this.
        if newState == .completed, let txUID = effectiveTxUID {
            if verbose {
                fprintln("Updating workitem with Final State attributes (required before COMPLETED)...")
            }
            
            let nowDT: String = {
                let f = DateFormatter()
                f.dateFormat = "yyyyMMddHHmmss.SSS000"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                return f.string(from: Date())
            }()
            
            let performedBody: [String: Any] = [
                UPSTag.transactionUID: [
                    "vr": "UI", "Value": [txUID]
                ] as [String: Any],
                UPSTag.unifiedProcedureStepPerformedProcedureSequence: [
                    "vr": "SQ",
                    "Value": [
                        [
                            UPSTag.performedProcedureStepStartDateTime: [
                                "vr": "DT", "Value": [nowDT]
                            ] as [String: Any],
                            UPSTag.performedProcedureStepEndDateTime: [
                                "vr": "DT", "Value": [nowDT]
                            ] as [String: Any],
                            UPSTag.performedWorkitemCodeSequence: [
                                "vr": "SQ",
                                "Value": [
                                    [
                                        UPSTag.codeValue: ["vr": "SH", "Value": ["12345"]],
                                        UPSTag.codingSchemeDesignator: ["vr": "SH", "Value": ["99LOCAL"]],
                                        UPSTag.codeMeaning: ["vr": "LO", "Value": ["Procedure Step Performed"]]
                                    ] as [String: Any]
                                ] as [[String: Any]]
                            ] as [String: Any],
                            UPSTag.performedStationNameCodeSequence: [
                                "vr": "SQ",
                                "Value": [
                                    [
                                        UPSTag.codeValue: ["vr": "SH", "Value": ["STATION01"]],
                                        UPSTag.codingSchemeDesignator: ["vr": "SH", "Value": ["99LOCAL"]],
                                        UPSTag.codeMeaning: ["vr": "LO", "Value": ["Default Performing Station"]]
                                    ] as [String: Any]
                                ] as [[String: Any]]
                            ] as [String: Any],
                            UPSTag.outputInformationSequence: [
                                "vr": "SQ",
                                "Value": [] as [[String: Any]]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [[String: Any]]
                ] as [String: Any]
            ]
            
            try await client.updateWorkitem(uid: uid, updates: performedBody, transactionUID: txUID)
            if verbose {
                fprintln("Final State attributes updated successfully")
            }
        }
        
        let response = try await client.changeWorkitemState(
            uid: uid,
            state: newState,
            transactionUID: effectiveTxUID,
            requestingAE: requestingAE
        )
        
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
    
    private func formatWorkitemTable(_ workitems: [WorkitemResult]) -> String {
        // Compute dynamic column width for UID based on longest value
        let maxUIDLength = workitems.reduce(12) { max($0, $1.workitemUID.count) }  // min 12 for header
        let uidWidth = min(maxUIDLength, 70)  // cap at 70 to avoid excessive width
        let totalWidth = uidWidth + 1 + 20 + 1 + 30 + 1 + 20

        var output = ""
        output += String(repeating: "=", count: totalWidth) + "\n"
        output += pad("Worklist UID", uidWidth) + " " + pad("State", 20) + " " + pad("Label", 30) + " " + pad("Patient", 20) + "\n"
        output += String(repeating: "=", count: totalWidth) + "\n"
        
        for item in workitems {
            let uid = truncate(item.workitemUID, maxLength: uidWidth)
            let state = item.state?.rawValue ?? ""
            let label = truncate(item.procedureStepLabel ?? "", maxLength: 30)
            let patient = truncate(item.patientName ?? "", maxLength: 20)
            
            output += pad(uid, uidWidth) + " " + pad(state, 20) + " " + pad(label, 30) + " " + pad(patient, 20) + "\n"
        }
        
        output += String(repeating: "=", count: totalWidth) + "\n"
        return output
    }
    
    private func formatWorkitemJSON(_ workitems: [WorkitemResult]) -> String {
        var items: [[String: Any]] = []
        for item in workitems {
            var dict: [String: Any] = ["workitemUID": item.workitemUID]
            if let s = item.state { dict["state"] = s.rawValue }
            if let p = item.priority { dict["priority"] = p.rawValue }
            if let pp = item.progressPercentage { dict["progressPercentage"] = pp }
            if let pd = item.progressDescription { dict["progressDescription"] = pd }
            if let sd = item.scheduledStartDateTime { dict["scheduledStartDateTime"] = sd }
            if let ec = item.expectedCompletionDateTime { dict["expectedCompletionDateTime"] = ec }
            if let md = item.modificationDateTime { dict["modificationDateTime"] = md }
            if let l = item.procedureStepLabel { dict["procedureStepLabel"] = l }
            if let wl = item.worklistLabel { dict["worklistLabel"] = wl }
            if let sid = item.scheduledProcedureStepID { dict["scheduledProcedureStepID"] = sid }
            if let pn = item.patientName { dict["patientName"] = pn }
            if let pid = item.patientID { dict["patientID"] = pid }
            if let dob = item.patientBirthDate { dict["patientBirthDate"] = dob }
            if let sex = item.patientSex { dict["patientSex"] = sex }
            if let suid = item.studyInstanceUID { dict["studyInstanceUID"] = suid }
            if let acc = item.accessionNumber { dict["accessionNumber"] = acc }
            if let ref = item.referringPhysicianName { dict["referringPhysicianName"] = ref }
            if let tx = item.transactionUID { dict["transactionUID"] = tx }
            items.append(dict)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }
    
    private func formatWorkitemCSV(_ workitems: [WorkitemResult]) -> String {
        var output = "WorkitemUID,State,ProcedureStepLabel,PatientName,PatientID\n"
        for item in workitems {
            let uid = csvEscape(item.workitemUID)
            let state = csvEscape(item.state?.rawValue ?? "")
            let label = csvEscape(item.procedureStepLabel ?? "")
            let patient = csvEscape(item.patientName ?? "")
            let patientID = csvEscape(item.patientID ?? "")
            
            output += "\(uid),\(state),\(label),\(patient),\(patientID)\n"
        }
        return output
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

func truncate(_ string: String, maxLength: Int) -> String {
    if string.count <= maxLength {
        return string
    }
    let endIndex = string.index(string.startIndex, offsetBy: maxLength - 3)
    return String(string[..<endIndex]) + "..."
}

func pad(_ string: String, _ width: Int) -> String {
    if string.count >= width {
        return string
    }
    return string + String(repeating: " ", count: width - string.count)
}

func csvEscape(_ string: String) -> String {
    if string.contains(",") || string.contains("\"") || string.contains("\n") {
        return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return string
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


