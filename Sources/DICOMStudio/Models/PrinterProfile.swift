// PrinterProfile.swift
// DICOMStudio
//
// DICOM Studio — a configured DICOM printer (Print SCP).
//
// Deliberately shaped like `PACSServerProfile`: printers are stored, listed,
// tested, and defaulted exactly the way PACS servers are, in the app's own
// storage. The dicom-print CLI keeps its own `~/.config/dicomkit/printers.json`
// registry — a sandboxed app cannot read that path, so the two lists are
// independent by design.

import Foundation
import DICOMNetwork

// MARK: - Printer Profile

/// A DICOM printer configuration profile.
/// Reference: DICOM PS3.4 Annex H — Print Management Service Class
public struct PrinterProfile: Sendable, Identifiable, Equatable, Hashable, Codable {
    /// Unique profile identifier.
    public let id: UUID
    /// Human-readable printer name.
    public var name: String
    /// Printer hostname or IP address.
    public var host: String
    /// DICOM port (typically 11112).
    public var port: UInt16
    /// Remote AE title (called AE — the printer).
    public var remoteAETitle: String
    /// Local AE title (calling AE — this workstation).
    public var localAETitle: String
    /// Grayscale or color print management.
    public var colorMode: PrinterColorMode
    /// Connection timeout in seconds.
    public var timeoutSeconds: Double
    /// Current connection status.
    public var status: ServerConnectionStatus
    /// Date/time of the last successful echo or status query.
    public var lastVerifiedDate: Date?
    /// Whether this is the default printer.
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: UInt16 = 11112,
        remoteAETitle: String,
        localAETitle: String = "DICOMSTUDIO",
        colorMode: PrinterColorMode = .grayscale,
        timeoutSeconds: Double = 60.0,
        status: ServerConnectionStatus = .unknown,
        lastVerifiedDate: Date? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.remoteAETitle = remoteAETitle
        self.localAETitle = localAETitle
        self.colorMode = colorMode
        self.timeoutSeconds = timeoutSeconds
        self.status = status
        self.lastVerifiedDate = lastVerifiedDate
        self.isDefault = isDefault
    }

    /// Display string for lists: "RAD-PRINTER — 10.0.0.5:11112 (PRINT_SCP)".
    public var summary: String {
        "\(name) — \(host):\(port) (\(remoteAETitle))"
    }

    /// The Print SCU configuration this profile produces.
    public func printConfiguration() -> PrintConfiguration {
        PrintConfiguration(
            host: host,
            port: port,
            callingAETitle: localAETitle,
            calledAETitle: remoteAETitle,
            timeout: timeoutSeconds,
            colorMode: colorMode.printColorMode
        )
    }
}

// MARK: - Color Mode

/// Whether a printer is driven with Basic Grayscale or Basic Color Print Management.
public enum PrinterColorMode: String, Sendable, Codable, CaseIterable, Identifiable {
    case grayscale
    case color

    public var id: String { rawValue }

    /// Display label.
    public var displayName: String {
        switch self {
        case .grayscale: return "Grayscale"
        case .color:     return "Color"
        }
    }

    /// The DICOMNetwork color mode this maps to.
    public var printColorMode: DICOMNetwork.PrintColorMode {
        switch self {
        case .grayscale: return .grayscale
        case .color:     return .color
        }
    }
}
