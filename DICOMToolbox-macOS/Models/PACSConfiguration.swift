import Foundation

/// Global PACS network configuration shared across all network tools
struct PACSConfiguration: Sendable {
    var localAETitle: String = "DICOMTOOLBOX"
    var remoteAETitle: String = "ANY-SCP"
    var hostname: String = ""
    var port: Int = 11112
    var timeout: Int = 30
    var dicomwebBaseURL: String = ""
    var moveDestination: String = ""

    /// Generates the PACS URL in pacs://host:port format
    var pacsURL: String {
        guard !hostname.isEmpty else { return "" }
        return "pacs://\(hostname):\(port)"
    }

    /// Whether the PACS configuration has required fields set
    var isValid: Bool {
        !hostname.isEmpty && !localAETitle.isEmpty && port > 0
    }

    /// Whether the DICOMweb configuration has required fields set
    var isDICOMwebValid: Bool {
        !dicomwebBaseURL.isEmpty
    }
}
