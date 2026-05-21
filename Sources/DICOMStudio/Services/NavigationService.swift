// NavigationService.swift
// DICOMStudio
//
// DICOM Studio — App-wide routing and deep linking

import Foundation

/// Top-level grouping for sidebar navigation destinations.
///
/// DICOM Studio is imaging-first: the `imaging` group stays expanded by
/// default while the others collapse, so the sidebar reads as a viewer with
/// supporting tools rather than a flat list of sixteen equal features.
public enum NavigationCategory: String, CaseIterable, Identifiable, Sendable {
    case imaging   = "Imaging"
    case network   = "Network"
    case dataTools = "Data & Tools"
    case system    = "System"

    public var id: String { rawValue }
}

/// Sidebar navigation destinations in DICOM Studio.
public enum NavigationDestination: String, CaseIterable, Identifiable, Sendable {
    case library          = "Library"
    case viewer           = "Viewer"
    case volumeViewer     = "3D Viewer"
    case jp3dComparison   = "JP3D Comparison"
    case networking       = "Networking"
    case dicomWeb         = "DICOMweb"
    case reporting        = "Reporting"
    case tools            = "Tools"
    case security         = "Security"
    case cliWorkshop      = "CLI Workshop"
    case performanceTools   = "Performance Tools"
    case macOSEnhancements  = "macOS Enhancements"
    case polishRelease      = "Polish & Release"
    case fileOperations       = "File Operations"
    case integrationTesting   = "Integration Testing"
    case j2kTestBench         = "J2K Test Bench"
    case settings             = "Settings"

    public var id: String { rawValue }

    /// SF Symbol name for this destination.
    public var systemImage: String {
        switch self {
        case .library:          return "folder"
        case .viewer:           return "photo"
        case .volumeViewer:     return "cube.transparent"
        case .jp3dComparison:   return "waveform.path.ecg.rectangle"
        case .networking:       return "network"
        case .dicomWeb:         return "globe"
        case .reporting:        return "doc.text"
        case .tools:            return "wrench.and.screwdriver"
        case .security:         return "lock.shield"
        case .cliWorkshop:      return "terminal"
        case .performanceTools: return "speedometer"
        case .macOSEnhancements: return "macwindow"
        case .polishRelease:     return "paintbrush.pointed"
        case .fileOperations:    return "doc.badge.arrow.up"
        case .integrationTesting: return "checklist"
        case .j2kTestBench:     return "testtube.2"
        case .settings:         return "gear"
        }
    }

    /// Short description for accessibility labels.
    public var accessibilityLabel: String {
        switch self {
        case .library:          return "DICOM File Library"
        case .viewer:           return "Image Viewer"
        case .volumeViewer:     return "3D Volume Viewer"
        case .jp3dComparison:   return "JP3D Volumetric Comparison"
        case .networking:       return "DICOM Networking Hub"
        case .dicomWeb:         return "DICOMweb Integration Hub"
        case .reporting:        return "Structured Reporting"
        case .tools:            return "Data Exchange and Developer Tools"
        case .security:         return "Security & Privacy Center"
        case .cliWorkshop:      return "CLI Tools Workshop"
        case .performanceTools: return "Performance & Developer Tools"
        case .macOSEnhancements: return "macOS-Specific Enhancements"
        case .polishRelease:     return "Polish, Accessibility & Release"
        case .fileOperations:    return "File Operations & Drag-and-Drop"
        case .integrationTesting: return "Integration Testing & Polish"
        case .j2kTestBench:     return "J2K Codec Test Bench"
        case .settings:         return "Application Settings"
        }
    }

    /// The sidebar category this destination is grouped under.
    public var category: NavigationCategory {
        switch self {
        case .library, .viewer, .volumeViewer, .jp3dComparison:
            return .imaging
        case .networking, .dicomWeb:
            return .network
        case .reporting, .tools, .cliWorkshop, .fileOperations:
            return .dataTools
        case .security, .performanceTools, .macOSEnhancements,
             .polishRelease, .integrationTesting, .j2kTestBench, .settings:
            return .system
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
