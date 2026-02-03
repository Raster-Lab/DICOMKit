import Foundation

/// Configuration for DICOMweb client
///
/// Contains settings for connecting to a DICOMweb server including
/// URL, authentication, timeouts, and preferred media types.
///
/// Reference: PS3.18 - Web Services
public struct DICOMwebConfiguration: Sendable {
    /// The base URL of the DICOMweb server
    public let baseURL: URL
    
    /// Authentication settings
    public let authentication: Authentication?
    
    /// Timeout settings
    public let timeouts: TimeoutConfiguration
    
    /// Default Accept header media types for WADO-RS
    public let defaultAcceptTypes: [DICOMMediaType]
    
    /// Preferred transfer syntaxes (ordered by preference)
    public let preferredTransferSyntaxes: [String]
    
    /// Whether to include metadata with instance retrieval
    public let includeMetadata: Bool
    
    /// Maximum number of concurrent requests
    public let maxConcurrentRequests: Int
    
    /// Whether to follow HTTP redirects
    public let followRedirects: Bool
    
    /// Custom HTTP headers to include with all requests
    public let customHeaders: [String: String]
    
    /// User agent string
    public let userAgent: String
    
    /// Creates a DICOMweb configuration
    /// - Parameters:
    ///   - baseURL: The base URL of the DICOMweb server
    ///   - authentication: Optional authentication settings
    ///   - timeouts: Timeout configuration (defaults to `.default`)
    ///   - defaultAcceptTypes: Default Accept header media types
    ///   - preferredTransferSyntaxes: Preferred transfer syntaxes
    ///   - includeMetadata: Whether to include metadata
    ///   - maxConcurrentRequests: Maximum concurrent requests
    ///   - followRedirects: Whether to follow redirects
    ///   - customHeaders: Custom HTTP headers
    ///   - userAgent: User agent string
    public init(
        baseURL: URL,
        authentication: Authentication? = nil,
        timeouts: TimeoutConfiguration = .default,
        defaultAcceptTypes: [DICOMMediaType] = [.dicomJSON],
        preferredTransferSyntaxes: [String] = [
            DICOMMediaType.TransferSyntax.explicitVRLittleEndian,
            DICOMMediaType.TransferSyntax.implicitVRLittleEndian
        ],
        includeMetadata: Bool = true,
        maxConcurrentRequests: Int = 4,
        followRedirects: Bool = true,
        customHeaders: [String: String] = [:],
        userAgent: String = "DICOMKit/1.0"
    ) {
        self.baseURL = baseURL
        self.authentication = authentication
        self.timeouts = timeouts
        self.defaultAcceptTypes = defaultAcceptTypes
        self.preferredTransferSyntaxes = preferredTransferSyntaxes
        self.includeMetadata = includeMetadata
        self.maxConcurrentRequests = maxConcurrentRequests
        self.followRedirects = followRedirects
        self.customHeaders = customHeaders
        self.userAgent = userAgent
    }
    
    /// Creates a DICOMweb configuration from a URL string
    /// - Parameters:
    ///   - baseURLString: The base URL string
    ///   - authentication: Optional authentication settings
    /// - Throws: DICOMwebError.invalidURL if the string is not a valid URL
    public init(
        baseURLString: String,
        authentication: Authentication? = nil
    ) throws {
        guard let url = URL(string: baseURLString) else {
            throw DICOMwebError.invalidURL(url: baseURLString)
        }
        self.init(baseURL: url, authentication: authentication)
    }
    
    /// Returns the URL builder for this configuration
    public var urlBuilder: DICOMwebURLBuilder {
        return DICOMwebURLBuilder(baseURL: baseURL)
    }
}

// MARK: - Authentication

extension DICOMwebConfiguration {
    /// Authentication methods for DICOMweb
    public enum Authentication: Sendable {
        /// HTTP Basic authentication
        case basic(username: String, password: String)
        
        /// Bearer token authentication (OAuth 2.0)
        case bearer(token: String)
        
        /// API key authentication
        case apiKey(key: String, headerName: String = "X-API-Key")
        
        /// Custom authentication header
        case custom(headerName: String, headerValue: String)
        
        /// Returns the Authorization header value
        public var authorizationHeader: (name: String, value: String) {
            switch self {
            case .basic(let username, let password):
                let credentials = "\(username):\(password)"
                let encoded = Data(credentials.utf8).base64EncodedString()
                return ("Authorization", "Basic \(encoded)")
                
            case .bearer(let token):
                return ("Authorization", "Bearer \(token)")
                
            case .apiKey(let key, let headerName):
                return (headerName, key)
                
            case .custom(let headerName, let headerValue):
                return (headerName, headerValue)
            }
        }
    }
}

// MARK: - Timeout Configuration

extension DICOMwebConfiguration {
    /// Timeout settings for DICOMweb operations
    public struct TimeoutConfiguration: Sendable {
        /// Time allowed to establish connection
        public let connectTimeout: TimeInterval
        
        /// Time allowed to receive data after connection
        public let readTimeout: TimeInterval
        
        /// Time allowed for the entire request
        public let resourceTimeout: TimeInterval
        
        /// Time allowed for individual operations (e.g., per-instance)
        public let operationTimeout: TimeInterval
        
        /// Creates a timeout configuration
        /// - Parameters:
        ///   - connectTimeout: Connection timeout in seconds
        ///   - readTimeout: Read timeout in seconds
        ///   - resourceTimeout: Total request timeout in seconds
        ///   - operationTimeout: Per-operation timeout in seconds
        public init(
            connectTimeout: TimeInterval = 30,
            readTimeout: TimeInterval = 60,
            resourceTimeout: TimeInterval = 300,
            operationTimeout: TimeInterval = 120
        ) {
            self.connectTimeout = connectTimeout
            self.readTimeout = readTimeout
            self.resourceTimeout = resourceTimeout
            self.operationTimeout = operationTimeout
        }
        
        /// Default timeout configuration
        public static let `default` = TimeoutConfiguration()
        
        /// Fast timeout configuration for quick operations
        public static let fast = TimeoutConfiguration(
            connectTimeout: 10,
            readTimeout: 30,
            resourceTimeout: 60,
            operationTimeout: 30
        )
        
        /// Slow timeout configuration for large transfers
        public static let slow = TimeoutConfiguration(
            connectTimeout: 60,
            readTimeout: 300,
            resourceTimeout: 1800,
            operationTimeout: 600
        )
    }
}

// MARK: - Preset Configurations

extension DICOMwebConfiguration {
    /// Creates a configuration for local development servers
    /// - Parameters:
    ///   - host: The hostname (default: "localhost")
    ///   - port: The port number (default: 8042 for Orthanc)
    ///   - path: Optional path prefix (default: "/dicom-web")
    /// - Returns: A development configuration
    ///
    /// - Warning: This configuration uses unencrypted HTTP and should ONLY be used for
    ///   local development with test data. Never use in production or with real patient data
    ///   as DICOM data may contain Protected Health Information (PHI).
    public static func development(
        host: String = "localhost",
        port: Int = 8042,
        path: String = "/dicom-web"
    ) -> DICOMwebConfiguration {
        // Warning: Using HTTP (not HTTPS) - for local development only
        let urlString = "http://\(host):\(port)\(path)"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid development URL: \(urlString)")
        }
        return DICOMwebConfiguration(
            baseURL: url,
            timeouts: .fast
        )
    }
}

// MARK: - Request Building Helpers

extension DICOMwebConfiguration {
    /// Creates HTTP headers for a request
    /// - Parameters:
    ///   - accept: Accept header media types
    ///   - contentType: Content-Type header media type
    ///   - additionalHeaders: Additional headers to include
    /// - Returns: Dictionary of HTTP headers
    public func headers(
        accept: [DICOMMediaType]? = nil,
        contentType: DICOMMediaType? = nil,
        additionalHeaders: [String: String]? = nil
    ) -> [String: String] {
        var headers = customHeaders
        
        // User-Agent
        headers["User-Agent"] = userAgent
        
        // Accept header
        let acceptTypes = accept ?? defaultAcceptTypes
        if !acceptTypes.isEmpty {
            headers["Accept"] = acceptTypes.map { $0.description }.joined(separator: ", ")
        }
        
        // Content-Type header
        if let ct = contentType {
            headers["Content-Type"] = ct.description
        }
        
        // Authentication
        if let auth = authentication {
            let authHeader = auth.authorizationHeader
            headers[authHeader.name] = authHeader.value
        }
        
        // Additional headers
        if let additional = additionalHeaders {
            for (key, value) in additional {
                headers[key] = value
            }
        }
        
        return headers
    }
}
