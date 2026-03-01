// StatusIndicator.swift
// DICOMStudio
//
// DICOM Studio — Connection/transfer status indicator

#if canImport(SwiftUI)
import SwiftUI
#endif

import Foundation

/// Represents the operational status of a connection or transfer.
public enum ConnectionStatus: String, CaseIterable, Sendable {
    case connected = "Connected"
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case error = "Error"
    case transferring = "Transferring"
    case idle = "Idle"

    /// SF Symbol name for this status.
    public var systemImage: String {
        switch self {
        case .connected: return "circle.fill"
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .error: return "exclamationmark.circle.fill"
        case .transferring: return "arrow.triangle.2.circlepath"
        case .idle: return "minus.circle"
        }
    }

    /// RGB components for this status.
    public var colorComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .connected:
            return (StudioColors.successRed, StudioColors.successGreen, StudioColors.successBlue)
        case .disconnected, .idle:
            return (0.5, 0.5, 0.5)
        case .connecting, .transferring:
            return (StudioColors.warningRed, StudioColors.warningGreen, StudioColors.warningBlue)
        case .error:
            return (StudioColors.errorRed, StudioColors.errorGreen, StudioColors.errorBlue)
        }
    }
}

#if canImport(SwiftUI)
/// Displays a colored status indicator dot with label.
///
/// Usage:
/// ```swift
/// StatusIndicator(status: .connected, label: "PACS Server")
/// ```
@available(macOS 14.0, iOS 17.0, *)
public struct StatusIndicator: View {
    let status: ConnectionStatus
    let label: String?

    public init(status: ConnectionStatus, label: String? = nil) {
        self.status = status
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.systemImage)
                .font(.system(size: 10))
                .foregroundStyle(statusColor)
            if let label = label {
                Text(label)
                    .font(.system(size: StudioTypography.captionSize))
                    .foregroundStyle(.secondary)
            }
            Text(status.rawValue)
                .font(.system(size: StudioTypography.captionSize))
                .foregroundStyle(statusColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var statusColor: Color {
        let c = status.colorComponents
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    private var accessibilityText: String {
        if let label = label {
            return "\(label): \(status.rawValue)"
        }
        return "Status: \(status.rawValue)"
    }
}
#endif
