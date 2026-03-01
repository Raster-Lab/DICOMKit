// NavigationService.swift
// DICOMStudio
//
// DICOM Studio — App-wide routing and deep linking

import Foundation

/// Sidebar navigation destinations in DICOM Studio.
public enum NavigationDestination: String, CaseIterable, Identifiable, Sendable {
    case library = "Library"
    case viewer = "Viewer"
    case networking = "Networking"
    case reporting = "Reporting"
    case tools = "Tools"
    case cliWorkshop = "CLI Workshop"
    case settings = "Settings"

    public var id: String { rawValue }

    /// SF Symbol name for this destination.
    public var systemImage: String {
        switch self {
        case .library: return "folder"
        case .viewer: return "photo"
        case .networking: return "network"
        case .reporting: return "doc.text"
        case .tools: return "wrench.and.screwdriver"
        case .cliWorkshop: return "terminal"
        case .settings: return "gear"
        }
    }

    /// Short description for accessibility labels.
    public var accessibilityLabel: String {
        switch self {
        case .library: return "DICOM File Library"
        case .viewer: return "Image Viewer"
        case .networking: return "DICOM Networking Hub"
        case .reporting: return "Structured Reporting"
        case .tools: return "Data Exchange and Developer Tools"
        case .cliWorkshop: return "CLI Tools Workshop"
        case .settings: return "Application Settings"
        }
    }
}

/// Manages app-wide navigation state and deep linking.
public final class NavigationService: Sendable {
    /// The default destination when the app launches.
    public static let defaultDestination: NavigationDestination = .library

    /// Returns all primary navigation destinations (excluding settings).
    public static var primaryDestinations: [NavigationDestination] {
        NavigationDestination.allCases.filter { $0 != .settings }
    }

    public init() {}
}
