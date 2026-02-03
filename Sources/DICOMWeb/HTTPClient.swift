import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP client for DICOMweb operations
///
/// Provides a configurable HTTP client layer with retry support,
/// interceptors, and progress reporting.
#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
public final class HTTPClient: @unchecked Sendable {
    
    // MARK: - Types
    
    /// HTTP request method
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
    
    /// HTTP request
    public struct Request: Sendable {
        /// Request URL
        public let url: URL
        
        /// HTTP method
        public let method: Method
        
        /// Request headers
        public var headers: [String: String]
        
        /// Request body
        public let body: Data?
        
        /// Creates an HTTP request
        /// - Parameters:
        ///   - url: The request URL
        ///   - method: The HTTP method
        ///   - headers: Request headers
        ///   - body: Optional request body
        public init(url: URL, method: Method = .get, headers: [String: String] = [:], body: Data? = nil) {
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
        }
    }
    
    /// HTTP response
    public struct Response: Sendable {
        /// HTTP status code
        public let statusCode: Int
        
        /// Response headers
        public let headers: [String: String]
        
        /// Response body
        public let body: Data
        
        /// Whether the response indicates success (2xx)
        public var isSuccess: Bool {
            return (200..<300).contains(statusCode)
        }
        
        /// Whether the response indicates a client error (4xx)
        public var isClientError: Bool {
            return (400..<500).contains(statusCode)
        }
        
        /// Whether the response indicates a server error (5xx)
        public var isServerError: Bool {
            return statusCode >= 500
        }
        
        /// Gets a header value (case-insensitive)
        /// - Parameter name: Header name
        /// - Returns: Header value if present
        public func header(_ name: String) -> String? {
            let lowercased = name.lowercased()
            return headers.first { $0.key.lowercased() == lowercased }?.value
        }
        
        /// Gets the Content-Type header as DICOMMediaType
        public var contentType: DICOMMediaType? {
            guard let ct = header("Content-Type") else { return nil }
            return DICOMMediaType.parse(ct)
        }
    }
    
    /// Progress information
    public struct Progress: Sendable {
        /// Bytes completed
        public let completedBytes: Int64
        
        /// Total bytes expected (may be unknown)
        public let totalBytes: Int64?
        
        /// Fraction completed (0.0 to 1.0)
        public var fractionCompleted: Double {
            guard let total = totalBytes, total > 0 else { return 0 }
            return Double(completedBytes) / Double(total)
        }
    }
    
    /// Request interceptor for modifying requests before sending
    public typealias RequestInterceptor = @Sendable (inout Request) -> Void
    
    /// Response interceptor for processing responses
    public typealias ResponseInterceptor = @Sendable (Response) -> Void
    
    // MARK: - Properties
    
    /// The underlying URL session
    private let session: URLSession
    
    /// Configuration for this client
    public let configuration: DICOMwebConfiguration
    
    /// Request interceptors
    private var requestInterceptors: [RequestInterceptor] = []
    
    /// Response interceptors
    private var responseInterceptors: [ResponseInterceptor] = []
    
    // MARK: - Initialization
    
    /// Creates an HTTP client with the specified configuration
    /// - Parameter configuration: The DICOMweb configuration
    public init(configuration: DICOMwebConfiguration) {
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeouts.readTimeout
        sessionConfig.timeoutIntervalForResource = configuration.timeouts.resourceTimeout
        sessionConfig.httpMaximumConnectionsPerHost = configuration.maxConcurrentRequests
        
        #if os(macOS) || os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        if #available(macOS 10.13, iOS 11.0, *) {
            sessionConfig.waitsForConnectivity = true
        }
        #endif
        
        // Enable HTTP/2
        sessionConfig.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate"
        ]
        
        self.session = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - Interceptors
    
    /// Adds a request interceptor
    /// - Parameter interceptor: The interceptor to add
    public func addRequestInterceptor(_ interceptor: @escaping RequestInterceptor) {
        requestInterceptors.append(interceptor)
    }
    
    /// Adds a response interceptor
    /// - Parameter interceptor: The interceptor to add
    public func addResponseInterceptor(_ interceptor: @escaping ResponseInterceptor) {
        responseInterceptors.append(interceptor)
    }
    
    // MARK: - Request Execution
    
    /// Executes an HTTP request
    /// - Parameter request: The request to execute
    /// - Returns: The HTTP response
    /// - Throws: DICOMwebError on failure
    public func execute(_ request: Request) async throws -> Response {
        var modifiedRequest = request
        
        // Apply request interceptors
        for interceptor in requestInterceptors {
            interceptor(&modifiedRequest)
        }
        
        // Build URLRequest
        var urlRequest = URLRequest(url: modifiedRequest.url)
        urlRequest.httpMethod = modifiedRequest.method.rawValue
        urlRequest.httpBody = modifiedRequest.body
        
        // Apply headers from configuration
        let headers = configuration.headers(additionalHeaders: modifiedRequest.headers)
        for (name, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        
        // Execute request
        let (data, urlResponse) = try await executeWithRetry(urlRequest)
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw DICOMwebError.connectionFailed(underlying: nil)
        }
        
        // Build response
        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyStr = key as? String, let valueStr = value as? String {
                responseHeaders[keyStr] = valueStr
            }
        }
        
        let response = Response(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: data
        )
        
        // Apply response interceptors
        for interceptor in responseInterceptors {
            interceptor(response)
        }
        
        // Check for errors
        if !response.isSuccess {
            throw DICOMwebError.fromHTTPStatus(
                response.statusCode,
                message: String(data: data, encoding: .utf8),
                headers: responseHeaders
            )
        }
        
        return response
    }
    
    /// Executes a GET request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - headers: Additional headers
    /// - Returns: The HTTP response
    /// - Throws: DICOMwebError on failure
    public func get(_ url: URL, headers: [String: String] = [:]) async throws -> Response {
        return try await execute(Request(url: url, method: .get, headers: headers))
    }
    
    /// Executes a POST request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - body: Request body
    ///   - headers: Additional headers
    /// - Returns: The HTTP response
    /// - Throws: DICOMwebError on failure
    public func post(_ url: URL, body: Data, headers: [String: String] = [:]) async throws -> Response {
        return try await execute(Request(url: url, method: .post, headers: headers, body: body))
    }
    
    /// Executes a DELETE request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - headers: Additional headers
    /// - Returns: The HTTP response
    /// - Throws: DICOMwebError on failure
    public func delete(_ url: URL, headers: [String: String] = [:]) async throws -> Response {
        return try await execute(Request(url: url, method: .delete, headers: headers))
    }
    
    // MARK: - Private Methods
    
    private func executeWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount <= maxRetries {
            do {
                return try await session.data(for: request)
            } catch let error as URLError {
                lastError = error
                
                // Only retry on transient errors
                switch error.code {
                case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                     .cannotConnectToHost, .cannotFindHost:
                    retryCount += 1
                    if retryCount <= maxRetries {
                        // Exponential backoff
                        let delay = TimeInterval(pow(2.0, Double(retryCount - 1)))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                default:
                    break
                }
                
                throw mapURLError(error)
            } catch {
                throw DICOMwebError.connectionFailed(underlying: error)
            }
        }
        
        throw DICOMwebError.connectionFailed(underlying: lastError)
    }
    
    private func mapURLError(_ error: URLError) -> DICOMwebError {
        switch error.code {
        case .timedOut:
            return .timeout(operation: "HTTP request")
        case .notConnectedToInternet, .networkConnectionLost:
            return .connectionFailed(underlying: error)
        case .cannotFindHost:
            return .dnsLookupFailed(host: error.failingURL?.host)
        case .serverCertificateUntrusted, .clientCertificateRejected, .secureConnectionFailed:
            return .sslError(message: error.localizedDescription)
        default:
            return .connectionFailed(underlying: error)
        }
    }
}

// MARK: - Convenience Methods

extension HTTPClient {
    /// Retrieves JSON data and parses it
    /// - Parameters:
    ///   - url: The URL to request
    ///   - type: The type to decode
    /// - Returns: The decoded object
    /// - Throws: DICOMwebError on failure
    public func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let response = try await get(url, headers: ["Accept": "application/json"])
        return try JSONDecoder().decode(T.self, from: response.body)
    }
    
    /// Posts JSON data
    /// - Parameters:
    ///   - url: The URL to post to
    ///   - body: The object to encode as JSON
    /// - Returns: The HTTP response
    /// - Throws: DICOMwebError on failure
    public func postJSON<T: Encodable>(_ url: URL, body: T) async throws -> Response {
        let data = try JSONEncoder().encode(body)
        return try await post(url, body: data, headers: ["Content-Type": "application/json"])
    }
}
#endif
