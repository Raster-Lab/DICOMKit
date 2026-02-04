import Foundation

/// Configuration for DICOMweb server
///
/// Contains settings for hosting a DICOMweb server including
/// binding address, port, paths, and security settings.
///
/// Reference: PS3.18 - Web Services
public struct DICOMwebServerConfiguration: Sendable {
    /// The port to listen on
    public let port: Int
    
    /// The host/address to bind to
    public let host: String
    
    /// The base URL path prefix (e.g., "/dicom-web")
    public let pathPrefix: String
    
    /// TLS configuration for HTTPS
    public let tlsConfiguration: TLSConfiguration?
    
    /// Maximum request body size in bytes
    public let maxRequestBodySize: Int
    
    /// Maximum concurrent requests
    public let maxConcurrentRequests: Int
    
    /// CORS configuration
    public let corsConfiguration: CORSConfiguration?
    
    /// Rate limiting configuration
    public let rateLimitConfiguration: RateLimitConfiguration?
    
    /// Server name for response headers
    public let serverName: String
    
    /// Creates a DICOMweb server configuration
    /// - Parameters:
    ///   - port: The port to listen on (default: 8042)
    ///   - host: The host to bind to (default: "0.0.0.0")
    ///   - pathPrefix: URL path prefix (default: "/dicom-web")
    ///   - tlsConfiguration: Optional TLS configuration
    ///   - maxRequestBodySize: Maximum request body size (default: 500MB)
    ///   - maxConcurrentRequests: Maximum concurrent requests (default: 100)
    ///   - corsConfiguration: Optional CORS configuration
    ///   - rateLimitConfiguration: Optional rate limiting
    ///   - serverName: Server name for headers (default: "DICOMKit/1.0")
    public init(
        port: Int = 8042,
        host: String = "0.0.0.0",
        pathPrefix: String = "/dicom-web",
        tlsConfiguration: TLSConfiguration? = nil,
        maxRequestBodySize: Int = 500 * 1024 * 1024,
        maxConcurrentRequests: Int = 100,
        corsConfiguration: CORSConfiguration? = nil,
        rateLimitConfiguration: RateLimitConfiguration? = nil,
        serverName: String = "DICOMKit/1.0"
    ) {
        self.port = port
        self.host = host
        self.pathPrefix = pathPrefix
        self.tlsConfiguration = tlsConfiguration
        self.maxRequestBodySize = maxRequestBodySize
        self.maxConcurrentRequests = maxConcurrentRequests
        self.corsConfiguration = corsConfiguration
        self.rateLimitConfiguration = rateLimitConfiguration
        self.serverName = serverName
    }
    
    /// The base URL for the server (computed without TLS)
    public var baseURL: URL {
        let scheme = tlsConfiguration != nil ? "https" : "http"
        // Use localhost instead of 0.0.0.0 for URL generation
        let hostForURL = host == "0.0.0.0" ? "localhost" : host
        return URL(string: "\(scheme)://\(hostForURL):\(port)\(pathPrefix)")!
    }
}

// MARK: - TLS Configuration

extension DICOMwebServerConfiguration {
    /// TLS configuration for secure connections
    public struct TLSConfiguration: Sendable {
        /// Path to the certificate file (PEM or DER)
        public let certificatePath: String
        
        /// Path to the private key file (PEM)
        public let privateKeyPath: String
        
        /// Password for the private key (if encrypted)
        public let privateKeyPassword: String?
        
        /// Minimum TLS version
        public let minimumTLSVersion: TLSVersion
        
        /// Whether to require client certificates (mTLS)
        public let requireClientCertificate: Bool
        
        /// Path to CA certificates for client verification
        public let clientCACertificatePath: String?
        
        public init(
            certificatePath: String,
            privateKeyPath: String,
            privateKeyPassword: String? = nil,
            minimumTLSVersion: TLSVersion = .v12,
            requireClientCertificate: Bool = false,
            clientCACertificatePath: String? = nil
        ) {
            self.certificatePath = certificatePath
            self.privateKeyPath = privateKeyPath
            self.privateKeyPassword = privateKeyPassword
            self.minimumTLSVersion = minimumTLSVersion
            self.requireClientCertificate = requireClientCertificate
            self.clientCACertificatePath = clientCACertificatePath
        }
    }
    
    /// TLS version
    public enum TLSVersion: Sendable {
        case v12
        case v13
    }
}

// MARK: - CORS Configuration

extension DICOMwebServerConfiguration {
    /// CORS (Cross-Origin Resource Sharing) configuration
    public struct CORSConfiguration: Sendable {
        /// Allowed origins (use ["*"] for all)
        public let allowedOrigins: [String]
        
        /// Allowed HTTP methods
        public let allowedMethods: [String]
        
        /// Allowed headers
        public let allowedHeaders: [String]
        
        /// Headers to expose to the client
        public let exposedHeaders: [String]
        
        /// Whether to allow credentials
        public let allowCredentials: Bool
        
        /// Max age for preflight cache in seconds
        public let maxAge: Int
        
        public init(
            allowedOrigins: [String] = ["*"],
            allowedMethods: [String] = ["GET", "POST", "DELETE", "OPTIONS"],
            allowedHeaders: [String] = ["Content-Type", "Accept", "Authorization"],
            exposedHeaders: [String] = ["X-Total-Count"],
            allowCredentials: Bool = false,
            maxAge: Int = 86400
        ) {
            self.allowedOrigins = allowedOrigins
            self.allowedMethods = allowedMethods
            self.allowedHeaders = allowedHeaders
            self.exposedHeaders = exposedHeaders
            self.allowCredentials = allowCredentials
            self.maxAge = maxAge
        }
        
        /// Default CORS configuration allowing all origins
        public static let allowAll = CORSConfiguration()
        
        /// Strict CORS configuration (no cross-origin allowed)
        public static let strict = CORSConfiguration(
            allowedOrigins: [],
            allowCredentials: false
        )
    }
}

// MARK: - Rate Limit Configuration

extension DICOMwebServerConfiguration {
    /// Rate limiting configuration
    public struct RateLimitConfiguration: Sendable {
        /// Maximum requests per time window
        public let maxRequests: Int
        
        /// Time window in seconds
        public let windowSeconds: Int
        
        /// Rate limit by (IP, API key, etc.)
        public let limitBy: LimitBy
        
        public init(
            maxRequests: Int = 1000,
            windowSeconds: Int = 60,
            limitBy: LimitBy = .ipAddress
        ) {
            self.maxRequests = maxRequests
            self.windowSeconds = windowSeconds
            self.limitBy = limitBy
        }
        
        /// What to use for rate limiting identification
        public enum LimitBy: Sendable {
            case ipAddress
            case apiKey
            case combined
        }
    }
}

// MARK: - Preset Configurations

extension DICOMwebServerConfiguration {
    /// Development configuration for local testing
    ///
    /// - Warning: This configuration uses unencrypted HTTP and should ONLY be used for
    ///   local development with test data. Never use in production or with real patient data
    ///   as DICOM data may contain Protected Health Information (PHI).
    public static let development = DICOMwebServerConfiguration(
        port: 8042,
        host: "127.0.0.1",
        corsConfiguration: .allowAll
    )
    
    /// Production configuration template (requires TLS)
    public static func production(
        port: Int = 443,
        certificatePath: String,
        privateKeyPath: String
    ) -> DICOMwebServerConfiguration {
        DICOMwebServerConfiguration(
            port: port,
            host: "0.0.0.0",
            tlsConfiguration: TLSConfiguration(
                certificatePath: certificatePath,
                privateKeyPath: privateKeyPath,
                minimumTLSVersion: .v12
            ),
            rateLimitConfiguration: RateLimitConfiguration()
        )
    }
}
