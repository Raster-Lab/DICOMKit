import Foundation

/// Protocol type for DICOM communication
public enum ProtocolType: String, CaseIterable, Sendable {
    case dicom = "DICOM"
    case dicomweb = "DICOMweb"
}

/// PACS network configuration that persists across app sessions
public final class NetworkConfig: Sendable {
    /// Application Entity Title (max 16 ASCII characters)
    public let aeTitle: String
    /// Called Application Entity Title
    public let calledAET: String
    /// Hostname or IP address
    public let host: String
    /// Port number (1-65535)
    public let port: Int
    /// Connection timeout in seconds (5-300)
    public let timeout: Int
    /// Communication protocol
    public let protocolType: ProtocolType

    /// Default configuration values
    public static let defaultAETitle = "DICOMTOOLBOX"
    public static let defaultCalledAET = "ANY-SCP"
    public static let defaultHost = "localhost"
    public static let defaultPort = 11112
    public static let defaultTimeout = 60

    public init(
        aeTitle: String = NetworkConfig.defaultAETitle,
        calledAET: String = NetworkConfig.defaultCalledAET,
        host: String = NetworkConfig.defaultHost,
        port: Int = NetworkConfig.defaultPort,
        timeout: Int = NetworkConfig.defaultTimeout,
        protocolType: ProtocolType = .dicom
    ) {
        self.aeTitle = aeTitle
        self.calledAET = calledAET
        self.host = host
        self.port = port
        self.timeout = timeout
        self.protocolType = protocolType
    }

    /// Constructs the server URL from the current configuration
    public var serverURL: String {
        switch protocolType {
        case .dicom:
            return "pacs://\(host):\(port)"
        case .dicomweb:
            return "https://\(host):\(port)/dicom-web"
        }
    }

    /// Validates the AE Title (max 16 ASCII characters, non-empty)
    public static func validateAETitle(_ value: String) -> Bool {
        !value.isEmpty &&
        value.count <= 16 &&
        value.allSatisfy { $0.isASCII }
    }

    /// Validates the port number (1-65535)
    public static func validatePort(_ value: Int) -> Bool {
        (1...65535).contains(value)
    }

    /// Validates the timeout value (5-300 seconds)
    public static func validateTimeout(_ value: Int) -> Bool {
        (5...300).contains(value)
    }

    /// Whether all configuration fields are valid
    public var isValid: Bool {
        NetworkConfig.validateAETitle(aeTitle) &&
        !host.isEmpty &&
        NetworkConfig.validatePort(port) &&
        NetworkConfig.validateTimeout(timeout)
    }
}
