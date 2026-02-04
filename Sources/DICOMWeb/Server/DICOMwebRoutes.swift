import Foundation

/// HTTP request structure for DICOMweb server
public struct DICOMwebRequest: Sendable {
    /// HTTP method
    public let method: HTTPMethod
    
    /// Request path (without query string)
    public let path: String
    
    /// Query parameters
    public let queryParameters: [String: String]
    
    /// HTTP headers
    public let headers: [String: String]
    
    /// Request body
    public let body: Data?
    
    /// Remote client address
    public let remoteAddress: String?
    
    /// Creates a DICOMweb request
    public init(
        method: HTTPMethod,
        path: String,
        queryParameters: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data? = nil,
        remoteAddress: String? = nil
    ) {
        self.method = method
        self.path = path
        self.queryParameters = queryParameters
        self.headers = headers
        self.body = body
        self.remoteAddress = remoteAddress
    }
    
    /// Gets a header value (case-insensitive)
    public func header(_ name: String) -> String? {
        let lowercased = name.lowercased()
        return headers.first { $0.key.lowercased() == lowercased }?.value
    }
    
    /// Gets the Accept header as an array of media types
    public var acceptTypes: [DICOMMediaType] {
        guard let accept = header("Accept") else {
            return []
        }
        return accept.split(separator: ",")
            .compactMap { DICOMMediaType.parse(String($0).trimmingCharacters(in: .whitespaces)) }
    }
    
    /// Gets the Content-Type header
    public var contentType: DICOMMediaType? {
        guard let ct = header("Content-Type") else { return nil }
        return DICOMMediaType.parse(ct)
    }
    
    /// HTTP methods
    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case options = "OPTIONS"
        case head = "HEAD"
    }
}

/// HTTP response structure for DICOMweb server
public struct DICOMwebResponse: Sendable {
    /// HTTP status code
    public let statusCode: Int
    
    /// HTTP headers
    public var headers: [String: String]
    
    /// Response body
    public let body: Data?
    
    /// Creates a DICOMweb response
    public init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
    
    // MARK: - Factory Methods
    
    /// Creates a 200 OK response with JSON body
    public static func ok(json: Data, headers: [String: String] = [:]) -> DICOMwebResponse {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/dicom+json"
        allHeaders["Content-Length"] = "\(json.count)"
        return DICOMwebResponse(statusCode: 200, headers: allHeaders, body: json)
    }
    
    /// Creates a 200 OK response with multipart DICOM body
    public static func ok(multipart: Data, boundary: String, headers: [String: String] = [:]) -> DICOMwebResponse {
        var allHeaders = headers
        allHeaders["Content-Type"] = "multipart/related; type=\"application/dicom\"; boundary=\"\(boundary)\""
        allHeaders["Content-Length"] = "\(multipart.count)"
        return DICOMwebResponse(statusCode: 200, headers: allHeaders, body: multipart)
    }
    
    /// Creates a 200 OK response with image body
    public static func ok(image: Data, mediaType: DICOMMediaType, headers: [String: String] = [:]) -> DICOMwebResponse {
        var allHeaders = headers
        allHeaders["Content-Type"] = mediaType.description
        allHeaders["Content-Length"] = "\(image.count)"
        return DICOMwebResponse(statusCode: 200, headers: allHeaders, body: image)
    }
    
    /// Creates a 204 No Content response
    public static func noContent() -> DICOMwebResponse {
        DICOMwebResponse(statusCode: 204)
    }
    
    /// Creates a 400 Bad Request response
    public static func badRequest(message: String) -> DICOMwebResponse {
        let body = "{\"error\": \"\(message)\"}"
        return DICOMwebResponse(
            statusCode: 400,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
    
    /// Creates a 404 Not Found response
    public static func notFound(message: String = "Resource not found") -> DICOMwebResponse {
        let body = "{\"error\": \"\(message)\"}"
        return DICOMwebResponse(
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
    
    /// Creates a 406 Not Acceptable response
    public static func notAcceptable(supportedTypes: [DICOMMediaType]) -> DICOMwebResponse {
        let types = supportedTypes.map { $0.description }.joined(separator: ", ")
        let body = "{\"error\": \"Not Acceptable\", \"supportedTypes\": \"\(types)\"}"
        return DICOMwebResponse(
            statusCode: 406,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
    
    /// Creates a 409 Conflict response
    public static func conflict(message: String) -> DICOMwebResponse {
        let body = "{\"error\": \"\(message)\"}"
        return DICOMwebResponse(
            statusCode: 409,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
    
    /// Creates a 415 Unsupported Media Type response
    public static func unsupportedMediaType() -> DICOMwebResponse {
        let body = "{\"error\": \"Unsupported Media Type\"}"
        return DICOMwebResponse(
            statusCode: 415,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
    
    /// Creates a 500 Internal Server Error response
    public static func internalError(message: String = "Internal server error") -> DICOMwebResponse {
        let body = "{\"error\": \"\(message)\"}"
        return DICOMwebResponse(
            statusCode: 500,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
    
    /// Creates a 503 Service Unavailable response
    public static func serviceUnavailable() -> DICOMwebResponse {
        let body = "{\"error\": \"Service Unavailable\"}"
        return DICOMwebResponse(
            statusCode: 503,
            headers: ["Content-Type": "application/json"],
            body: body.data(using: .utf8)
        )
    }
}

/// Route matching result with extracted path parameters
public struct RouteMatch: Sendable {
    /// The matched route pattern
    public let pattern: String
    
    /// Extracted path parameters
    public let parameters: [String: String]
    
    /// The matched route handler type
    public let handlerType: RouteHandlerType
    
    public init(pattern: String, parameters: [String: String], handlerType: RouteHandlerType) {
        self.pattern = pattern
        self.parameters = parameters
        self.handlerType = handlerType
    }
}

/// Types of DICOMweb route handlers
public enum RouteHandlerType: Sendable {
    // WADO-RS retrieve endpoints
    case retrieveStudy
    case retrieveSeries
    case retrieveInstance
    case retrieveStudyMetadata
    case retrieveSeriesMetadata
    case retrieveInstanceMetadata
    case retrieveFrames
    case retrieveRendered
    case retrieveThumbnail
    case retrieveBulkData
    
    // QIDO-RS search endpoints
    case searchStudies
    case searchSeries
    case searchSeriesInStudy
    case searchInstances
    case searchInstancesInStudy
    case searchInstancesInSeries
    
    // STOW-RS store endpoints
    case storeInstances
    case storeInstancesInStudy
    
    // Delete endpoints
    case deleteStudy
    case deleteSeries
    case deleteInstance
    
    // UPS-RS endpoints
    case searchWorkitems
    case retrieveWorkitem
    case createWorkitem
    case createWorkitemWithUID
    case updateWorkitem
    case changeWorkitemState
    case requestWorkitemCancellation
    case subscribeWorkitem
    case unsubscribeWorkitem
    case subscribeGlobal
    case unsubscribeGlobal
    case suspendSubscription
    
    // Capabilities
    case capabilities
}

/// Route pattern matcher for DICOMweb URLs
public struct DICOMwebRouter: Sendable {
    
    /// The path prefix for all routes
    private let pathPrefix: String
    
    /// Creates a router with the given path prefix
    public init(pathPrefix: String = "/dicom-web") {
        self.pathPrefix = pathPrefix.hasSuffix("/") ? String(pathPrefix.dropLast()) : pathPrefix
    }
    
    /// Matches a request path and method to a route handler
    /// - Parameters:
    ///   - path: The request path
    ///   - method: The HTTP method
    /// - Returns: A route match if found, nil otherwise
    public func match(path: String, method: DICOMwebRequest.HTTPMethod) -> RouteMatch? {
        // Remove prefix and normalize path
        guard path.hasPrefix(pathPrefix) else {
            return nil
        }
        
        let relativePath = String(path.dropFirst(pathPrefix.count))
        let normalizedPath = relativePath.isEmpty ? "/" : relativePath
        
        // Split path into components
        let components = normalizedPath.split(separator: "/").map(String.init)
        
        return matchRoute(components: components, method: method)
    }
    
    private func matchRoute(components: [String], method: DICOMwebRequest.HTTPMethod) -> RouteMatch? {
        switch (method, components.count) {
        
        // GET / or GET /capabilities - Server capabilities
        case (.get, 0):
            return RouteMatch(pattern: "/", parameters: [:], handlerType: .capabilities)
            
        case (.get, 1) where components[0] == "capabilities":
            return RouteMatch(pattern: "/capabilities", parameters: [:], handlerType: .capabilities)
        
        // GET /studies - Search studies (QIDO-RS)
        case (.get, 1) where components[0] == "studies":
            return RouteMatch(pattern: "/studies", parameters: [:], handlerType: .searchStudies)
            
        // GET /series - Search all series (QIDO-RS)
        case (.get, 1) where components[0] == "series":
            return RouteMatch(pattern: "/series", parameters: [:], handlerType: .searchSeries)
            
        // GET /instances - Search all instances (QIDO-RS)
        case (.get, 1) where components[0] == "instances":
            return RouteMatch(pattern: "/instances", parameters: [:], handlerType: .searchInstances)
            
        // POST /studies - Store instances (STOW-RS)
        case (.post, 1) where components[0] == "studies":
            return RouteMatch(pattern: "/studies", parameters: [:], handlerType: .storeInstances)
            
        // GET /studies/{studyUID} - Retrieve study (WADO-RS)
        case (.get, 2) where components[0] == "studies":
            return RouteMatch(
                pattern: "/studies/{studyUID}",
                parameters: ["studyUID": components[1]],
                handlerType: .retrieveStudy
            )
            
        // DELETE /studies/{studyUID} - Delete study
        case (.delete, 2) where components[0] == "studies":
            return RouteMatch(
                pattern: "/studies/{studyUID}",
                parameters: ["studyUID": components[1]],
                handlerType: .deleteStudy
            )
            
        // POST /studies/{studyUID} - Store instances in study (STOW-RS)
        case (.post, 2) where components[0] == "studies":
            return RouteMatch(
                pattern: "/studies/{studyUID}",
                parameters: ["studyUID": components[1]],
                handlerType: .storeInstancesInStudy
            )
            
        // GET /studies/{studyUID}/metadata - Retrieve study metadata
        case (.get, 3) where components[0] == "studies" && components[2] == "metadata":
            return RouteMatch(
                pattern: "/studies/{studyUID}/metadata",
                parameters: ["studyUID": components[1]],
                handlerType: .retrieveStudyMetadata
            )
            
        // GET /studies/{studyUID}/series - Search series in study
        case (.get, 3) where components[0] == "studies" && components[2] == "series":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series",
                parameters: ["studyUID": components[1]],
                handlerType: .searchSeriesInStudy
            )
            
        // GET /studies/{studyUID}/instances - Search instances in study
        case (.get, 3) where components[0] == "studies" && components[2] == "instances":
            return RouteMatch(
                pattern: "/studies/{studyUID}/instances",
                parameters: ["studyUID": components[1]],
                handlerType: .searchInstancesInStudy
            )
            
        // GET /studies/{studyUID}/series/{seriesUID} - Retrieve series
        case (.get, 4) where components[0] == "studies" && components[2] == "series":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}",
                parameters: ["studyUID": components[1], "seriesUID": components[3]],
                handlerType: .retrieveSeries
            )
            
        // DELETE /studies/{studyUID}/series/{seriesUID} - Delete series
        case (.delete, 4) where components[0] == "studies" && components[2] == "series":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}",
                parameters: ["studyUID": components[1], "seriesUID": components[3]],
                handlerType: .deleteSeries
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/metadata - Retrieve series metadata
        case (.get, 5) where components[0] == "studies" && components[2] == "series" && components[4] == "metadata":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/metadata",
                parameters: ["studyUID": components[1], "seriesUID": components[3]],
                handlerType: .retrieveSeriesMetadata
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances - Search instances in series
        case (.get, 5) where components[0] == "studies" && components[2] == "series" && components[4] == "instances":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances",
                parameters: ["studyUID": components[1], "seriesUID": components[3]],
                handlerType: .searchInstancesInSeries
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/rendered - Retrieve series rendered
        case (.get, 5) where components[0] == "studies" && components[2] == "series" && components[4] == "rendered":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/rendered",
                parameters: ["studyUID": components[1], "seriesUID": components[3]],
                handlerType: .retrieveRendered
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/thumbnail - Retrieve series thumbnail
        case (.get, 5) where components[0] == "studies" && components[2] == "series" && components[4] == "thumbnail":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/thumbnail",
                parameters: ["studyUID": components[1], "seriesUID": components[3]],
                handlerType: .retrieveThumbnail
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID} - Retrieve instance
        case (.get, 6) where components[0] == "studies" && components[2] == "series" && components[4] == "instances":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}",
                parameters: ["studyUID": components[1], "seriesUID": components[3], "instanceUID": components[5]],
                handlerType: .retrieveInstance
            )
            
        // DELETE /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID} - Delete instance
        case (.delete, 6) where components[0] == "studies" && components[2] == "series" && components[4] == "instances":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}",
                parameters: ["studyUID": components[1], "seriesUID": components[3], "instanceUID": components[5]],
                handlerType: .deleteInstance
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/metadata - Instance metadata
        case (.get, 7) where components[0] == "studies" && components[2] == "series" && components[4] == "instances" && components[6] == "metadata":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/metadata",
                parameters: ["studyUID": components[1], "seriesUID": components[3], "instanceUID": components[5]],
                handlerType: .retrieveInstanceMetadata
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/rendered - Instance rendered
        case (.get, 7) where components[0] == "studies" && components[2] == "series" && components[4] == "instances" && components[6] == "rendered":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/rendered",
                parameters: ["studyUID": components[1], "seriesUID": components[3], "instanceUID": components[5]],
                handlerType: .retrieveRendered
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/thumbnail - Instance thumbnail
        case (.get, 7) where components[0] == "studies" && components[2] == "series" && components[4] == "instances" && components[6] == "thumbnail":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/thumbnail",
                parameters: ["studyUID": components[1], "seriesUID": components[3], "instanceUID": components[5]],
                handlerType: .retrieveThumbnail
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frames} - Retrieve frames
        case (.get, 8) where components[0] == "studies" && components[2] == "series" && components[4] == "instances" && components[6] == "frames":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frames}",
                parameters: [
                    "studyUID": components[1],
                    "seriesUID": components[3],
                    "instanceUID": components[5],
                    "frames": components[7]
                ],
                handlerType: .retrieveFrames
            )
            
        // GET /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frames}/rendered
        case (.get, 9) where components[0] == "studies" && components[2] == "series" && components[4] == "instances" && components[6] == "frames" && components[8] == "rendered":
            return RouteMatch(
                pattern: "/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frames}/rendered",
                parameters: [
                    "studyUID": components[1],
                    "seriesUID": components[3],
                    "instanceUID": components[5],
                    "frames": components[7]
                ],
                handlerType: .retrieveRendered
            )
            
        // ============ UPS-RS Endpoints ============
        
        // GET /workitems - Search workitems (UPS-RS)
        case (.get, 1) where components[0] == "workitems":
            return RouteMatch(pattern: "/workitems", parameters: [:], handlerType: .searchWorkitems)
            
        // POST /workitems - Create workitem (UPS-RS)
        case (.post, 1) where components[0] == "workitems":
            return RouteMatch(pattern: "/workitems", parameters: [:], handlerType: .createWorkitem)
            
        // GET /workitems/{workitemUID} - Retrieve workitem (UPS-RS)
        case (.get, 2) where components[0] == "workitems":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}",
                parameters: ["workitemUID": components[1]],
                handlerType: .retrieveWorkitem
            )
            
        // POST /workitems/{workitemUID} - Create workitem with specific UID (UPS-RS)
        case (.post, 2) where components[0] == "workitems":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}",
                parameters: ["workitemUID": components[1]],
                handlerType: .createWorkitemWithUID
            )
            
        // PUT /workitems/{workitemUID} - Update workitem (UPS-RS)
        case (.put, 2) where components[0] == "workitems":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}",
                parameters: ["workitemUID": components[1]],
                handlerType: .updateWorkitem
            )
            
        // PUT /workitems/{workitemUID}/state - Change workitem state (UPS-RS)
        case (.put, 3) where components[0] == "workitems" && components[2] == "state":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}/state",
                parameters: ["workitemUID": components[1]],
                handlerType: .changeWorkitemState
            )
            
        // PUT /workitems/{workitemUID}/cancelrequest - Request cancellation (UPS-RS)
        case (.put, 3) where components[0] == "workitems" && components[2] == "cancelrequest":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}/cancelrequest",
                parameters: ["workitemUID": components[1]],
                handlerType: .requestWorkitemCancellation
            )
            
        // POST /workitems/{workitemUID}/subscribers/{aeTitle} - Subscribe to workitem
        case (.post, 4) where components[0] == "workitems" && components[2] == "subscribers":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}/subscribers/{aeTitle}",
                parameters: ["workitemUID": components[1], "aeTitle": components[3]],
                handlerType: .subscribeWorkitem
            )
            
        // DELETE /workitems/{workitemUID}/subscribers/{aeTitle} - Unsubscribe from workitem
        case (.delete, 4) where components[0] == "workitems" && components[2] == "subscribers":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}/subscribers/{aeTitle}",
                parameters: ["workitemUID": components[1], "aeTitle": components[3]],
                handlerType: .unsubscribeWorkitem
            )
            
        // POST /workitems/{workitemUID}/subscribers/{aeTitle}/suspend - Suspend subscription
        case (.post, 5) where components[0] == "workitems" && components[2] == "subscribers" && components[4] == "suspend":
            return RouteMatch(
                pattern: "/workitems/{workitemUID}/subscribers/{aeTitle}/suspend",
                parameters: ["workitemUID": components[1], "aeTitle": components[3]],
                handlerType: .suspendSubscription
            )
            
        default:
            return nil
        }
    }
}
