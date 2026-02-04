import Foundation
import DICOMCore
import DICOMKit

/// DICOMweb server for serving DICOM objects over HTTP
///
/// This server implements WADO-RS (Retrieve), QIDO-RS (Search), and STOW-RS (Store)
/// services per the DICOM PS3.18 web services specification.
///
/// Reference: PS3.18 - Web Services
///
/// - Note: This implementation provides the request handling logic. It can be integrated
///   with various HTTP server frameworks (SwiftNIO, Vapor, Hummingbird) by implementing
///   the request/response bridge.
public actor DICOMwebServer {
    
    // MARK: - Properties
    
    /// Server configuration
    public let configuration: DICOMwebServerConfiguration
    
    /// Storage provider
    private let storage: any DICOMwebStorageProvider
    
    /// Router for matching requests
    private let router: DICOMwebRouter
    
    /// Whether the server is running
    private var isRunning: Bool = false
    
    /// Server delegate for events
    public weak var delegate: DICOMwebServerDelegate?
    
    // MARK: - Initialization
    
    /// Creates a DICOMweb server
    /// - Parameters:
    ///   - configuration: Server configuration
    ///   - storage: Storage provider
    public init(
        configuration: DICOMwebServerConfiguration,
        storage: any DICOMwebStorageProvider
    ) {
        self.configuration = configuration
        self.storage = storage
        self.router = DICOMwebRouter(pathPrefix: configuration.pathPrefix)
    }
    
    /// Creates a DICOMweb server with default development configuration
    /// - Parameter storage: Storage provider
    public init(storage: any DICOMwebStorageProvider) {
        self.init(configuration: .development, storage: storage)
    }
    
    // MARK: - Server Control
    
    /// Starts the server
    ///
    /// - Note: This sets the server state to running. Actual HTTP listening
    ///   must be implemented by the integrating HTTP framework.
    public func start() async throws {
        guard !isRunning else { return }
        isRunning = true
        await delegate?.serverDidStart(self)
    }
    
    /// Stops the server
    public func stop() async {
        guard isRunning else { return }
        isRunning = false
        await delegate?.serverDidStop(self)
    }
    
    /// Whether the server is currently running
    public var running: Bool {
        isRunning
    }
    
    /// The base URL of the server
    public var baseURL: URL {
        configuration.baseURL
    }
    
    /// The port the server is configured for
    public var port: Int {
        configuration.port
    }
    
    // MARK: - Request Handling
    
    /// Handles an incoming DICOMweb request
    /// - Parameter request: The HTTP request
    /// - Returns: The HTTP response
    public func handleRequest(_ request: DICOMwebRequest) async -> DICOMwebResponse {
        // Handle CORS preflight
        if request.method == .options {
            return handleCORSPreflight(request)
        }
        
        // Match route
        guard let match = router.match(path: request.path, method: request.method) else {
            return .notFound(message: "No route matched for \(request.method.rawValue) \(request.path)")
        }
        
        // Handle the request based on handler type
        do {
            var response = try await handleRoute(match: match, request: request)
            
            // Add CORS headers if configured
            addCORSHeaders(to: &response, request: request)
            
            // Add server header
            response.headers["Server"] = configuration.serverName
            
            return response
        } catch let error as DICOMwebError {
            return errorResponse(for: error)
        } catch {
            return .internalError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Route Handlers
    
    private func handleRoute(match: RouteMatch, request: DICOMwebRequest) async throws -> DICOMwebResponse {
        switch match.handlerType {
        // WADO-RS Retrieve
        case .retrieveStudy:
            return try await handleRetrieveStudy(parameters: match.parameters, request: request)
        case .retrieveSeries:
            return try await handleRetrieveSeries(parameters: match.parameters, request: request)
        case .retrieveInstance:
            return try await handleRetrieveInstance(parameters: match.parameters, request: request)
        case .retrieveStudyMetadata:
            return try await handleRetrieveStudyMetadata(parameters: match.parameters, request: request)
        case .retrieveSeriesMetadata:
            return try await handleRetrieveSeriesMetadata(parameters: match.parameters, request: request)
        case .retrieveInstanceMetadata:
            return try await handleRetrieveInstanceMetadata(parameters: match.parameters, request: request)
        case .retrieveFrames:
            return try await handleRetrieveFrames(parameters: match.parameters, request: request)
        case .retrieveRendered:
            return try await handleRetrieveRendered(parameters: match.parameters, request: request)
        case .retrieveThumbnail:
            return try await handleRetrieveThumbnail(parameters: match.parameters, request: request)
        case .retrieveBulkData:
            return try await handleRetrieveBulkData(parameters: match.parameters, request: request)
            
        // QIDO-RS Search
        case .searchStudies:
            return try await handleSearchStudies(request: request)
        case .searchSeries:
            return try await handleSearchSeries(studyUID: nil, request: request)
        case .searchSeriesInStudy:
            return try await handleSearchSeries(studyUID: match.parameters["studyUID"], request: request)
        case .searchInstances:
            return try await handleSearchInstances(studyUID: nil, seriesUID: nil, request: request)
        case .searchInstancesInStudy:
            return try await handleSearchInstances(studyUID: match.parameters["studyUID"], seriesUID: nil, request: request)
        case .searchInstancesInSeries:
            return try await handleSearchInstances(studyUID: match.parameters["studyUID"], seriesUID: match.parameters["seriesUID"], request: request)
            
        // STOW-RS Store
        case .storeInstances:
            return try await handleStoreInstances(studyUID: nil, request: request)
        case .storeInstancesInStudy:
            return try await handleStoreInstances(studyUID: match.parameters["studyUID"], request: request)
            
        // Delete
        case .deleteStudy:
            return try await handleDeleteStudy(parameters: match.parameters)
        case .deleteSeries:
            return try await handleDeleteSeries(parameters: match.parameters)
        case .deleteInstance:
            return try await handleDeleteInstance(parameters: match.parameters)
            
        case .capabilities:
            return handleCapabilities()
        }
    }
    
    // MARK: - WADO-RS Handlers
    
    private func handleRetrieveStudy(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"] else {
            return .badRequest(message: "Missing studyUID")
        }
        
        let instances = try await storage.getStudyInstances(studyUID: studyUID)
        
        if instances.isEmpty {
            return .notFound(message: "Study not found: \(studyUID)")
        }
        
        // Build multipart response
        let (body, boundary) = buildMultipartDICOMResponse(instances: instances)
        return .ok(multipart: body, boundary: boundary)
    }
    
    private func handleRetrieveSeries(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"],
              let seriesUID = parameters["seriesUID"] else {
            return .badRequest(message: "Missing studyUID or seriesUID")
        }
        
        let instances = try await storage.getSeriesInstances(studyUID: studyUID, seriesUID: seriesUID)
        
        if instances.isEmpty {
            return .notFound(message: "Series not found: \(seriesUID)")
        }
        
        // Build multipart response
        let (body, boundary) = buildMultipartDICOMResponse(instances: instances)
        return .ok(multipart: body, boundary: boundary)
    }
    
    private func handleRetrieveInstance(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"],
              let seriesUID = parameters["seriesUID"],
              let instanceUID = parameters["instanceUID"] else {
            return .badRequest(message: "Missing studyUID, seriesUID, or instanceUID")
        }
        
        guard let data = try await storage.getInstance(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID) else {
            return .notFound(message: "Instance not found: \(instanceUID)")
        }
        
        // Return single instance as multipart (per WADO-RS spec)
        let instanceInfo = InstanceInfo(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            size: Int64(data.count),
            data: data
        )
        let (body, boundary) = buildMultipartDICOMResponse(instances: [instanceInfo])
        return .ok(multipart: body, boundary: boundary)
    }
    
    private func handleRetrieveStudyMetadata(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"] else {
            return .badRequest(message: "Missing studyUID")
        }
        
        let datasets = try await storage.getStudyMetadata(studyUID: studyUID)
        
        if datasets.isEmpty {
            return .notFound(message: "Study not found: \(studyUID)")
        }
        
        let json = try encodeMetadataAsJSON(datasets: datasets)
        return .ok(json: json)
    }
    
    private func handleRetrieveSeriesMetadata(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"],
              let seriesUID = parameters["seriesUID"] else {
            return .badRequest(message: "Missing studyUID or seriesUID")
        }
        
        let datasets = try await storage.getSeriesMetadata(studyUID: studyUID, seriesUID: seriesUID)
        
        if datasets.isEmpty {
            return .notFound(message: "Series not found: \(seriesUID)")
        }
        
        let json = try encodeMetadataAsJSON(datasets: datasets)
        return .ok(json: json)
    }
    
    private func handleRetrieveInstanceMetadata(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"],
              let seriesUID = parameters["seriesUID"],
              let instanceUID = parameters["instanceUID"] else {
            return .badRequest(message: "Missing studyUID, seriesUID, or instanceUID")
        }
        
        guard let dataset = try await storage.getInstanceMetadata(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID) else {
            return .notFound(message: "Instance not found: \(instanceUID)")
        }
        
        let json = try encodeMetadataAsJSON(datasets: [dataset])
        return .ok(json: json)
    }
    
    private func handleRetrieveFrames(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        // Frame retrieval requires pixel data extraction - return not implemented for now
        return .internalError(message: "Frame retrieval not yet implemented")
    }
    
    private func handleRetrieveRendered(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        // Rendered retrieval requires image processing - return not implemented for now
        return .internalError(message: "Rendered image retrieval not yet implemented")
    }
    
    private func handleRetrieveThumbnail(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        // Thumbnail requires image processing - return not implemented for now
        return .internalError(message: "Thumbnail retrieval not yet implemented")
    }
    
    private func handleRetrieveBulkData(parameters: [String: String], request: DICOMwebRequest) async throws -> DICOMwebResponse {
        // Bulk data retrieval - return not implemented for now
        return .internalError(message: "Bulk data retrieval not yet implemented")
    }
    
    // MARK: - QIDO-RS Handlers
    
    private func handleSearchStudies(request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let query = parseQIDOQuery(from: request.queryParameters)
        
        let studies = try await storage.searchStudies(query: query)
        let totalCount = try await storage.countStudies(query: query)
        
        let json = try encodeStudyResultsAsJSON(studies: studies)
        
        var headers: [String: String] = [:]
        headers["X-Total-Count"] = "\(totalCount)"
        
        return .ok(json: json, headers: headers)
    }
    
    private func handleSearchSeries(studyUID: String?, request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let query = parseQIDOQuery(from: request.queryParameters)
        
        let series = try await storage.searchSeries(studyUID: studyUID, query: query)
        
        let json = try encodeSeriesResultsAsJSON(series: series)
        
        var headers: [String: String] = [:]
        headers["X-Total-Count"] = "\(series.count)"
        
        return .ok(json: json, headers: headers)
    }
    
    private func handleSearchInstances(studyUID: String?, seriesUID: String?, request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let query = parseQIDOQuery(from: request.queryParameters)
        
        let instances = try await storage.searchInstances(studyUID: studyUID, seriesUID: seriesUID, query: query)
        
        let json = try encodeInstanceResultsAsJSON(instances: instances)
        
        var headers: [String: String] = [:]
        headers["X-Total-Count"] = "\(instances.count)"
        
        return .ok(json: json, headers: headers)
    }
    
    // MARK: - STOW-RS Handlers
    
    private func handleStoreInstances(studyUID: String?, request: DICOMwebRequest) async throws -> DICOMwebResponse {
        guard let body = request.body, !body.isEmpty else {
            return .badRequest(message: "Missing request body")
        }
        
        guard let contentType = request.contentType else {
            return .unsupportedMediaType()
        }
        
        // Parse multipart content
        guard let boundary = contentType.parameters["boundary"] else {
            return .badRequest(message: "Missing multipart boundary")
        }
        
        let parts = MultipartMIMEParser.parse(data: body, boundary: boundary)
        
        var storedInstances: [String] = []
        var failedInstances: [(uid: String, reason: String)] = []
        
        for part in parts {
            do {
                // Parse the DICOM data
                guard let dicomFile = try? DICOMFile.read(from: part.body, force: true) else {
                    failedInstances.append((uid: "unknown", reason: "Invalid DICOM data"))
                    continue
                }
                
                let dataSet = dicomFile.dataSet
                
                // Extract UIDs
                guard let sopInstanceUID = dataSet.string(for: Tag.sopInstanceUID),
                      let instanceSeriesUID = dataSet.string(for: Tag.seriesInstanceUID),
                      let instanceStudyUID = dataSet.string(for: Tag.studyInstanceUID) else {
                    failedInstances.append((uid: "unknown", reason: "Missing required UIDs"))
                    continue
                }
                
                // If studyUID was provided in path, validate it matches
                if let expectedStudyUID = studyUID, expectedStudyUID != instanceStudyUID {
                    failedInstances.append((uid: sopInstanceUID, reason: "Study UID mismatch"))
                    continue
                }
                
                // Store the instance
                try await storage.storeInstance(
                    data: part.body,
                    studyUID: instanceStudyUID,
                    seriesUID: instanceSeriesUID,
                    instanceUID: sopInstanceUID
                )
                
                storedInstances.append(sopInstanceUID)
            } catch {
                failedInstances.append((uid: "unknown", reason: error.localizedDescription))
            }
        }
        
        // Build STOW-RS response
        let responseJSON = buildSTOWResponse(stored: storedInstances, failed: failedInstances)
        return .ok(json: responseJSON)
    }
    
    // MARK: - Delete Handlers
    
    private func handleDeleteStudy(parameters: [String: String]) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"] else {
            return .badRequest(message: "Missing studyUID")
        }
        
        let deleted = try await storage.deleteStudy(studyUID: studyUID)
        
        if deleted == 0 {
            return .notFound(message: "Study not found: \(studyUID)")
        }
        
        return .noContent()
    }
    
    private func handleDeleteSeries(parameters: [String: String]) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"],
              let seriesUID = parameters["seriesUID"] else {
            return .badRequest(message: "Missing studyUID or seriesUID")
        }
        
        let deleted = try await storage.deleteSeries(studyUID: studyUID, seriesUID: seriesUID)
        
        if deleted == 0 {
            return .notFound(message: "Series not found: \(seriesUID)")
        }
        
        return .noContent()
    }
    
    private func handleDeleteInstance(parameters: [String: String]) async throws -> DICOMwebResponse {
        guard let studyUID = parameters["studyUID"],
              let seriesUID = parameters["seriesUID"],
              let instanceUID = parameters["instanceUID"] else {
            return .badRequest(message: "Missing studyUID, seriesUID, or instanceUID")
        }
        
        let deleted = try await storage.deleteInstance(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
        
        if !deleted {
            return .notFound(message: "Instance not found: \(instanceUID)")
        }
        
        return .noContent()
    }
    
    // MARK: - Capabilities
    
    private func handleCapabilities() -> DICOMwebResponse {
        let capabilities: [String: Any] = [
            "wadoRS": true,
            "qidoRS": true,
            "stowRS": true,
            "supports": [
                "multipartRelated",
                "dicomJSON"
            ]
        ]
        
        if let json = try? JSONSerialization.data(withJSONObject: capabilities) {
            return .ok(json: json)
        }
        return .internalError()
    }
    
    // MARK: - CORS Handling
    
    private func handleCORSPreflight(_ request: DICOMwebRequest) -> DICOMwebResponse {
        guard let cors = configuration.corsConfiguration else {
            return DICOMwebResponse(statusCode: 204)
        }
        
        var headers: [String: String] = [:]
        
        if cors.allowedOrigins.contains("*") {
            headers["Access-Control-Allow-Origin"] = "*"
        } else if let origin = request.header("Origin"), cors.allowedOrigins.contains(origin) {
            headers["Access-Control-Allow-Origin"] = origin
        }
        
        headers["Access-Control-Allow-Methods"] = cors.allowedMethods.joined(separator: ", ")
        headers["Access-Control-Allow-Headers"] = cors.allowedHeaders.joined(separator: ", ")
        headers["Access-Control-Max-Age"] = "\(cors.maxAge)"
        
        if cors.allowCredentials {
            headers["Access-Control-Allow-Credentials"] = "true"
        }
        
        return DICOMwebResponse(statusCode: 204, headers: headers)
    }
    
    private func addCORSHeaders(to response: inout DICOMwebResponse, request: DICOMwebRequest) {
        guard let cors = configuration.corsConfiguration else { return }
        
        if cors.allowedOrigins.contains("*") {
            response.headers["Access-Control-Allow-Origin"] = "*"
        } else if let origin = request.header("Origin"), cors.allowedOrigins.contains(origin) {
            response.headers["Access-Control-Allow-Origin"] = origin
        }
        
        if !cors.exposedHeaders.isEmpty {
            response.headers["Access-Control-Expose-Headers"] = cors.exposedHeaders.joined(separator: ", ")
        }
        
        if cors.allowCredentials {
            response.headers["Access-Control-Allow-Credentials"] = "true"
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseQIDOQuery(from parameters: [String: String]) -> StorageQuery {
        var query = StorageQuery()
        
        query.patientName = parameters["PatientName"]
        query.patientID = parameters["PatientID"]
        query.accessionNumber = parameters["AccessionNumber"]
        query.studyInstanceUID = parameters["StudyInstanceUID"]
        query.seriesInstanceUID = parameters["SeriesInstanceUID"]
        query.sopInstanceUID = parameters["SOPInstanceUID"]
        query.modality = parameters["Modality"]
        query.studyDescription = parameters["StudyDescription"]
        query.seriesDescription = parameters["SeriesDescription"]
        query.referringPhysicianName = parameters["ReferringPhysicianName"]
        
        if let offset = parameters["offset"], let value = Int(offset) {
            query.offset = value
        }
        if let limit = parameters["limit"], let value = Int(limit) {
            query.limit = value
        }
        if let fuzzy = parameters["fuzzymatching"], fuzzy.lowercased() == "true" {
            query.fuzzyMatching = true
        }
        
        return query
    }
    
    private func buildMultipartDICOMResponse(instances: [InstanceInfo]) -> (data: Data, boundary: String) {
        let boundary = "----DICOMBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()
        
        for instance in instances {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/dicom\r\n".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            body.append(instance.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return (body, boundary)
    }
    
    private func encodeMetadataAsJSON(datasets: [DataSet]) throws -> Data {
        let encoder = DICOMJSONEncoder()
        // Convert DataSets to arrays of DataElements for JSON encoding
        let elementArrays = datasets.map { $0.allElements }
        return try encoder.encodeMultiple(elementArrays)
    }
    
    private func encodeStudyResultsAsJSON(studies: [StudyRecord]) throws -> Data {
        var results: [[String: Any]] = []
        
        for study in studies {
            var dict: [String: Any] = [:]
            
            // Study Instance UID
            dict["0020000D"] = createDICOMJSONValue(vr: "UI", value: study.studyInstanceUID)
            
            if let name = study.patientName {
                dict["00100010"] = createDICOMJSONValue(vr: "PN", value: name)
            }
            if let id = study.patientID {
                dict["00100020"] = createDICOMJSONValue(vr: "LO", value: id)
            }
            if let date = study.studyDate {
                dict["00080020"] = createDICOMJSONValue(vr: "DA", value: date)
            }
            if let time = study.studyTime {
                dict["00080030"] = createDICOMJSONValue(vr: "TM", value: time)
            }
            if let desc = study.studyDescription {
                dict["00081030"] = createDICOMJSONValue(vr: "LO", value: desc)
            }
            if let acc = study.accessionNumber {
                dict["00080050"] = createDICOMJSONValue(vr: "SH", value: acc)
            }
            if !study.modalitiesInStudy.isEmpty {
                dict["00080061"] = createDICOMJSONValue(vr: "CS", values: study.modalitiesInStudy)
            }
            
            dict["00201206"] = createDICOMJSONValue(vr: "IS", value: "\(study.numberOfStudyRelatedSeries)")
            dict["00201208"] = createDICOMJSONValue(vr: "IS", value: "\(study.numberOfStudyRelatedInstances)")
            
            results.append(dict)
        }
        
        return try JSONSerialization.data(withJSONObject: results)
    }
    
    private func encodeSeriesResultsAsJSON(series: [SeriesRecord]) throws -> Data {
        var results: [[String: Any]] = []
        
        for s in series {
            var dict: [String: Any] = [:]
            
            dict["0020000D"] = createDICOMJSONValue(vr: "UI", value: s.studyInstanceUID)
            dict["0020000E"] = createDICOMJSONValue(vr: "UI", value: s.seriesInstanceUID)
            
            if let modality = s.modality {
                dict["00080060"] = createDICOMJSONValue(vr: "CS", value: modality)
            }
            if let num = s.seriesNumber {
                dict["00200011"] = createDICOMJSONValue(vr: "IS", value: "\(num)")
            }
            if let desc = s.seriesDescription {
                dict["0008103E"] = createDICOMJSONValue(vr: "LO", value: desc)
            }
            
            dict["00201209"] = createDICOMJSONValue(vr: "IS", value: "\(s.numberOfSeriesRelatedInstances)")
            
            results.append(dict)
        }
        
        return try JSONSerialization.data(withJSONObject: results)
    }
    
    private func encodeInstanceResultsAsJSON(instances: [InstanceRecord]) throws -> Data {
        var results: [[String: Any]] = []
        
        for instance in instances {
            var dict: [String: Any] = [:]
            
            dict["0020000D"] = createDICOMJSONValue(vr: "UI", value: instance.studyInstanceUID)
            dict["0020000E"] = createDICOMJSONValue(vr: "UI", value: instance.seriesInstanceUID)
            dict["00080018"] = createDICOMJSONValue(vr: "UI", value: instance.sopInstanceUID)
            
            if let sopClass = instance.sopClassUID {
                dict["00080016"] = createDICOMJSONValue(vr: "UI", value: sopClass)
            }
            if let num = instance.instanceNumber {
                dict["00200013"] = createDICOMJSONValue(vr: "IS", value: "\(num)")
            }
            
            results.append(dict)
        }
        
        return try JSONSerialization.data(withJSONObject: results)
    }
    
    private func createDICOMJSONValue(vr: String, value: String) -> [String: Any] {
        if vr == "PN" {
            return ["vr": vr, "Value": [["Alphabetic": value]]]
        }
        return ["vr": vr, "Value": [value]]
    }
    
    private func createDICOMJSONValue(vr: String, values: [String]) -> [String: Any] {
        return ["vr": vr, "Value": values]
    }
    
    private func buildSTOWResponse(stored: [String], failed: [(uid: String, reason: String)]) -> Data {
        var response: [String: Any] = [:]
        
        // Referenced SOP Sequence - stored instances
        if !stored.isEmpty {
            var referencedSOPSequence: [[String: Any]] = []
            for uid in stored {
                var item: [String: Any] = [:]
                item["00081155"] = createDICOMJSONValue(vr: "UI", value: uid)
                item["00081150"] = createDICOMJSONValue(vr: "UI", value: "1.2.840.10008.5.1.4.1.1.2") // Generic
                referencedSOPSequence.append(item)
            }
            response["00081199"] = ["vr": "SQ", "Value": referencedSOPSequence]
        }
        
        // Failed SOP Sequence
        if !failed.isEmpty {
            var failedSOPSequence: [[String: Any]] = []
            for (uid, _) in failed {
                var item: [String: Any] = [:]
                item["00081155"] = createDICOMJSONValue(vr: "UI", value: uid)
                item["00081197"] = createDICOMJSONValue(vr: "US", value: "A700") // Processing failure
                failedSOPSequence.append(item)
            }
            response["00081198"] = ["vr": "SQ", "Value": failedSOPSequence]
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: [response]) {
            return data
        }
        return Data()
    }
    
    private func errorResponse(for error: DICOMwebError) -> DICOMwebResponse {
        switch error {
        case .invalidURL, .badRequest:
            return .badRequest(message: error.localizedDescription)
        case .notFound:
            return .notFound()
        case .timeout:
            return .serviceUnavailable()
        default:
            return .internalError(message: error.localizedDescription)
        }
    }
}

// MARK: - Server Delegate

/// Delegate for DICOMweb server events
public protocol DICOMwebServerDelegate: AnyObject, Sendable {
    /// Called when the server starts
    func serverDidStart(_ server: DICOMwebServer) async
    
    /// Called when the server stops
    func serverDidStop(_ server: DICOMwebServer) async
    
    /// Called when a request is received
    func server(_ server: DICOMwebServer, didReceiveRequest request: DICOMwebRequest) async
    
    /// Called when a response is sent
    func server(_ server: DICOMwebServer, didSendResponse response: DICOMwebResponse, forRequest request: DICOMwebRequest) async
}

/// Default implementations for optional delegate methods
extension DICOMwebServerDelegate {
    public func serverDidStart(_ server: DICOMwebServer) async {}
    public func serverDidStop(_ server: DICOMwebServer) async {}
    public func server(_ server: DICOMwebServer, didReceiveRequest request: DICOMwebRequest) async {}
    public func server(_ server: DICOMwebServer, didSendResponse response: DICOMwebResponse, forRequest request: DICOMwebRequest) async {}
}

// MARK: - Multipart Parser

/// Simple multipart MIME parser for STOW-RS
struct MultipartMIMEParser {
    struct Part {
        let headers: [String: String]
        let body: Data
    }
    
    static func parse(data: Data, boundary: String) -> [Part] {
        var parts: [Part] = []
        
        guard let content = String(data: data, encoding: .utf8) else {
            return parts
        }
        
        let delimiter = "--\(boundary)"
        _ = "--\(boundary)--"  // endDelimiter - currently unused but kept for reference
        
        let sections = content.components(separatedBy: delimiter)
        
        for section in sections {
            // Skip empty sections and end boundary
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "--" || trimmed.hasPrefix("--") {
                continue
            }
            
            // Split headers from body
            if let headerEnd = section.range(of: "\r\n\r\n") ?? section.range(of: "\n\n") {
                let headerPart = String(section[section.startIndex..<headerEnd.lowerBound])
                let bodyPart = String(section[headerEnd.upperBound...])
                
                var headers: [String: String] = [:]
                for line in headerPart.split(separator: "\n") {
                    let headerLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                    if let colonIndex = headerLine.firstIndex(of: ":") {
                        let name = String(headerLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(headerLine[headerLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        headers[name] = value
                    }
                }
                
                if let bodyData = bodyPart.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) {
                    parts.append(Part(headers: headers, body: bodyData))
                }
            }
        }
        
        return parts
    }
}
