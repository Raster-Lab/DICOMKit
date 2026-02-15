import Foundation

/// Configuration for the DICOM Server
public struct ServerConfiguration: Sendable, Codable {
    /// Application Entity Title
    public let aeTitle: String
    
    /// Port to listen on
    public let port: UInt16
    
    /// Data directory for storing DICOM files
    public let dataDirectory: String
    
    /// Database connection URL
    public let databaseURL: String
    
    /// Maximum concurrent connections
    public let maxConcurrentConnections: Int
    
    /// Maximum PDU size
    public let maxPDUSize: UInt32
    
    /// Allowed calling AE titles (whitelist)
    public let allowedCallingAETitles: Set<String>?
    
    /// Blocked calling AE titles (blacklist)
    public let blockedCallingAETitles: Set<String>?
    
    /// Enable TLS/SSL
    public let enableTLS: Bool
    
    /// Verbose logging
    public let verbose: Bool
    
    public init(
        aeTitle: String,
        port: UInt16,
        dataDirectory: String,
        databaseURL: String,
        maxConcurrentConnections: Int = 10,
        maxPDUSize: UInt32 = 16384,
        allowedCallingAETitles: Set<String>? = nil,
        blockedCallingAETitles: Set<String>? = nil,
        enableTLS: Bool = false,
        verbose: Bool = false
    ) {
        self.aeTitle = aeTitle
        self.port = port
        self.dataDirectory = dataDirectory
        self.databaseURL = databaseURL
        self.maxConcurrentConnections = maxConcurrentConnections
        self.maxPDUSize = maxPDUSize
        self.allowedCallingAETitles = allowedCallingAETitles
        self.blockedCallingAETitles = blockedCallingAETitles
        self.enableTLS = enableTLS
        self.verbose = verbose
    }
    
    /// Load configuration from a JSON file
    public static func load(from path: String) throws -> ServerConfiguration {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        return try decoder.decode(ServerConfiguration.self, from: data)
    }
    
    /// Save configuration to a JSON file
    public func save(to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: path))
    }
}

/// Errors that can occur during server operation
public enum ServerError: Error, CustomStringConvertible {
    case invalidConfiguration(String)
    case serverNotRunning
    case portInUse(UInt16)
    case databaseError(String)
    case storageError(String)
    
    public var description: String {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .serverNotRunning:
            return "Server is not running"
        case .portInUse(let port):
            return "Port \(port) is already in use"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}
