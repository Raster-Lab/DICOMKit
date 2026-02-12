import Foundation

/// A saved server profile for quick-connect functionality
public struct ServerProfile: Identifiable, Codable, Sendable {
    public let id: UUID
    /// Profile display name
    public var name: String
    /// Application Entity Title
    public var aeTitle: String
    /// Called Application Entity Title
    public var calledAET: String
    /// Hostname or IP address
    public var host: String
    /// Port number
    public var port: Int
    /// Connection timeout in seconds
    public var timeout: Int
    /// Communication protocol
    public var protocolType: String

    public init(
        id: UUID = UUID(),
        name: String,
        aeTitle: String = NetworkConfig.defaultAETitle,
        calledAET: String = NetworkConfig.defaultCalledAET,
        host: String = NetworkConfig.defaultHost,
        port: Int = NetworkConfig.defaultPort,
        timeout: Int = NetworkConfig.defaultTimeout,
        protocolType: ProtocolType = .dicom
    ) {
        self.id = id
        self.name = name
        self.aeTitle = aeTitle
        self.calledAET = calledAET
        self.host = host
        self.port = port
        self.timeout = timeout
        self.protocolType = protocolType.rawValue
    }

    /// Creates a NetworkConfig from this profile
    public func toNetworkConfig() -> NetworkConfig {
        NetworkConfig(
            aeTitle: aeTitle,
            calledAET: calledAET,
            host: host,
            port: port,
            timeout: timeout,
            protocolType: ProtocolType(rawValue: protocolType) ?? .dicom
        )
    }
}
