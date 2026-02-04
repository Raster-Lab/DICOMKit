import Foundation

/// DICOMweb server capabilities
///
/// Describes the capabilities and supported features of a DICOMweb server.
/// This information is typically retrieved from the `/capabilities` or root endpoint.
///
/// Reference: PS3.18 Section 10.8 - Capabilities
public struct DICOMwebCapabilities: Sendable, Codable, Equatable {
    /// The DICOMweb API version
    public let apiVersion: String?
    
    /// The server name or product
    public let serverName: String?
    
    /// The server version
    public let serverVersion: String?
    
    /// Supported services
    public let services: SupportedServices
    
    /// Supported media types
    public let mediaTypes: MediaTypeSupport
    
    /// Supported transfer syntaxes
    public let transferSyntaxes: [String]
    
    /// Query capabilities
    public let queryCapabilities: QueryCapabilities
    
    /// Store capabilities
    public let storeCapabilities: StoreCapabilities
    
    /// Authentication methods supported
    public let authenticationMethods: [AuthenticationMethod]
    
    /// Additional custom extensions
    public let extensions: [String: String]?
    
    /// Creates DICOMweb capabilities
    public init(
        apiVersion: String? = nil,
        serverName: String? = nil,
        serverVersion: String? = nil,
        services: SupportedServices = SupportedServices(),
        mediaTypes: MediaTypeSupport = MediaTypeSupport(),
        transferSyntaxes: [String] = [],
        queryCapabilities: QueryCapabilities = QueryCapabilities(),
        storeCapabilities: StoreCapabilities = StoreCapabilities(),
        authenticationMethods: [AuthenticationMethod] = [],
        extensions: [String: String]? = nil
    ) {
        self.apiVersion = apiVersion
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.services = services
        self.mediaTypes = mediaTypes
        self.transferSyntaxes = transferSyntaxes
        self.queryCapabilities = queryCapabilities
        self.storeCapabilities = storeCapabilities
        self.authenticationMethods = authenticationMethods
        self.extensions = extensions
    }
}

// MARK: - Supported Services

extension DICOMwebCapabilities {
    /// Supported DICOMweb services
    public struct SupportedServices: Sendable, Codable, Equatable {
        /// WADO-RS retrieve support
        public let wadoRS: Bool
        
        /// QIDO-RS query support
        public let qidoRS: Bool
        
        /// STOW-RS store support
        public let stowRS: Bool
        
        /// UPS-RS worklist support
        public let upsRS: Bool
        
        /// Delete operations support
        public let delete: Bool
        
        /// Rendered image support
        public let rendered: Bool
        
        /// Thumbnail support
        public let thumbnails: Bool
        
        /// Bulk data retrieval support
        public let bulkdata: Bool
        
        public init(
            wadoRS: Bool = true,
            qidoRS: Bool = true,
            stowRS: Bool = true,
            upsRS: Bool = false,
            delete: Bool = false,
            rendered: Bool = false,
            thumbnails: Bool = false,
            bulkdata: Bool = true
        ) {
            self.wadoRS = wadoRS
            self.qidoRS = qidoRS
            self.stowRS = stowRS
            self.upsRS = upsRS
            self.delete = delete
            self.rendered = rendered
            self.thumbnails = thumbnails
            self.bulkdata = bulkdata
        }
    }
}

// MARK: - Media Type Support

extension DICOMwebCapabilities {
    /// Supported media types
    public struct MediaTypeSupport: Sendable, Codable, Equatable {
        /// Supported Accept media types for retrieval
        public let retrieve: [String]
        
        /// Supported Content-Type media types for storage
        public let store: [String]
        
        /// Supported rendered image formats
        public let rendered: [String]
        
        public init(
            retrieve: [String] = [
                "application/dicom",
                "application/dicom+json",
                "multipart/related"
            ],
            store: [String] = [
                "application/dicom",
                "multipart/related"
            ],
            rendered: [String] = [
                "image/jpeg",
                "image/png"
            ]
        ) {
            self.retrieve = retrieve
            self.store = store
            self.rendered = rendered
        }
    }
}

// MARK: - Query Capabilities

extension DICOMwebCapabilities {
    /// Query-related capabilities
    public struct QueryCapabilities: Sendable, Codable, Equatable {
        /// Maximum number of results per request
        public let maxResults: Int?
        
        /// Whether fuzzy matching is supported
        public let fuzzyMatching: Bool
        
        /// Whether wildcard matching is supported
        public let wildcardMatching: Bool
        
        /// Whether date range queries are supported
        public let dateRangeQueries: Bool
        
        /// Whether includefield=all is supported
        public let includeFieldAll: Bool
        
        /// Supported query levels
        public let queryLevels: [QueryLevel]
        
        public init(
            maxResults: Int? = nil,
            fuzzyMatching: Bool = false,
            wildcardMatching: Bool = true,
            dateRangeQueries: Bool = true,
            includeFieldAll: Bool = true,
            queryLevels: [QueryLevel] = [.study, .series, .instance]
        ) {
            self.maxResults = maxResults
            self.fuzzyMatching = fuzzyMatching
            self.wildcardMatching = wildcardMatching
            self.dateRangeQueries = dateRangeQueries
            self.includeFieldAll = includeFieldAll
            self.queryLevels = queryLevels
        }
    }
    
    /// Query levels
    public enum QueryLevel: String, Sendable, Codable {
        case study = "STUDY"
        case series = "SERIES"
        case instance = "INSTANCE"
    }
}

// MARK: - Store Capabilities

extension DICOMwebCapabilities {
    /// Store-related capabilities
    public struct StoreCapabilities: Sendable, Codable, Equatable {
        /// Maximum request body size in bytes
        public let maxRequestSize: Int?
        
        /// Maximum instances per request
        public let maxInstancesPerRequest: Int?
        
        /// Supported SOP Classes (empty means all)
        public let supportedSOPClasses: [String]?
        
        /// Whether partial success (202) is supported
        public let partialSuccess: Bool
        
        public init(
            maxRequestSize: Int? = nil,
            maxInstancesPerRequest: Int? = nil,
            supportedSOPClasses: [String]? = nil,
            partialSuccess: Bool = true
        ) {
            self.maxRequestSize = maxRequestSize
            self.maxInstancesPerRequest = maxInstancesPerRequest
            self.supportedSOPClasses = supportedSOPClasses
            self.partialSuccess = partialSuccess
        }
    }
}

// MARK: - Authentication Methods

extension DICOMwebCapabilities {
    /// Supported authentication methods
    public enum AuthenticationMethod: String, Sendable, Codable {
        /// No authentication required
        case none = "none"
        
        /// HTTP Basic authentication
        case basic = "basic"
        
        /// Bearer token (OAuth2)
        case bearer = "bearer"
        
        /// API key
        case apiKey = "apiKey"
        
        /// OAuth2/OpenID Connect
        case oauth2 = "oauth2"
        
        /// Client certificate (mTLS)
        case clientCertificate = "clientCertificate"
    }
}

// MARK: - Preset Capabilities

extension DICOMwebCapabilities {
    /// Default DICOMKit server capabilities
    public static let dicomKitServer = DICOMwebCapabilities(
        apiVersion: "1.0",
        serverName: "DICOMKit",
        serverVersion: "0.8.8",
        services: SupportedServices(
            wadoRS: true,
            qidoRS: true,
            stowRS: true,
            upsRS: true,
            delete: true,
            rendered: false,
            thumbnails: false,
            bulkdata: true
        ),
        mediaTypes: MediaTypeSupport(),
        transferSyntaxes: [
            "1.2.840.10008.1.2.1",     // Explicit VR Little Endian
            "1.2.840.10008.1.2",       // Implicit VR Little Endian
            "1.2.840.10008.1.2.2",     // Explicit VR Big Endian
            "1.2.840.10008.1.2.4.50",  // JPEG Baseline
            "1.2.840.10008.1.2.4.70",  // JPEG Lossless SV1
            "1.2.840.10008.1.2.4.90",  // JPEG 2000 Lossless
            "1.2.840.10008.1.2.4.91",  // JPEG 2000
            "1.2.840.10008.1.2.5"      // RLE Lossless
        ],
        queryCapabilities: QueryCapabilities(
            fuzzyMatching: false,
            wildcardMatching: true,
            dateRangeQueries: true,
            includeFieldAll: true
        ),
        storeCapabilities: StoreCapabilities(
            maxRequestSize: 500 * 1024 * 1024, // 500 MB
            partialSuccess: true
        ),
        authenticationMethods: [.none, .basic, .bearer, .apiKey]
    )
    
    /// Minimal capabilities for simple servers
    public static let minimal = DICOMwebCapabilities(
        services: SupportedServices(
            wadoRS: true,
            qidoRS: true,
            stowRS: false,
            upsRS: false,
            delete: false,
            rendered: false,
            thumbnails: false,
            bulkdata: false
        )
    )
}

// MARK: - JSON Representation

extension DICOMwebCapabilities {
    /// Converts capabilities to a JSON dictionary
    public func toJSONDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let apiVersion = apiVersion {
            dict["apiVersion"] = apiVersion
        }
        if let serverName = serverName {
            dict["serverName"] = serverName
        }
        if let serverVersion = serverVersion {
            dict["serverVersion"] = serverVersion
        }
        
        dict["services"] = [
            "wado-rs": services.wadoRS,
            "qido-rs": services.qidoRS,
            "stow-rs": services.stowRS,
            "ups-rs": services.upsRS,
            "delete": services.delete,
            "rendered": services.rendered,
            "thumbnails": services.thumbnails,
            "bulkdata": services.bulkdata
        ]
        
        dict["mediaTypes"] = [
            "retrieve": mediaTypes.retrieve,
            "store": mediaTypes.store,
            "rendered": mediaTypes.rendered
        ]
        
        dict["transferSyntaxes"] = transferSyntaxes
        
        var queryDict: [String: Any] = [
            "fuzzyMatching": queryCapabilities.fuzzyMatching,
            "wildcardMatching": queryCapabilities.wildcardMatching,
            "dateRangeQueries": queryCapabilities.dateRangeQueries,
            "includeFieldAll": queryCapabilities.includeFieldAll,
            "queryLevels": queryCapabilities.queryLevels.map { $0.rawValue }
        ]
        if let maxResults = queryCapabilities.maxResults {
            queryDict["maxResults"] = maxResults
        }
        dict["queryCapabilities"] = queryDict
        
        var storeDict: [String: Any] = [
            "partialSuccess": storeCapabilities.partialSuccess
        ]
        if let maxRequestSize = storeCapabilities.maxRequestSize {
            storeDict["maxRequestSize"] = maxRequestSize
        }
        if let maxInstances = storeCapabilities.maxInstancesPerRequest {
            storeDict["maxInstancesPerRequest"] = maxInstances
        }
        if let sopClasses = storeCapabilities.supportedSOPClasses {
            storeDict["supportedSOPClasses"] = sopClasses
        }
        dict["storeCapabilities"] = storeDict
        
        dict["authenticationMethods"] = authenticationMethods.map { $0.rawValue }
        
        if let extensions = extensions {
            dict["extensions"] = extensions
        }
        
        return dict
    }
}
