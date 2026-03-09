// MainViewModel.swift
// DICOMStudio
//
// DICOM Studio — Main application ViewModel

import Foundation
import Observation

/// Main ViewModel for DICOM Studio, managing top-level navigation
/// and application state.
///
/// Uses `@Observable` macro (requires macOS 14+ / Swift 5.9+)
/// for automatic SwiftUI view updates.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class MainViewModel {
    /// Currently selected sidebar navigation destination.
    public var selectedDestination: NavigationDestination?

    /// Whether the inspector panel is visible.
    public var isInspectorVisible: Bool

    /// Whether the welcome sheet is shown.
    public var showWelcomeSheet: Bool

    /// Current search text in the sidebar.
    public var searchText: String

    /// The local DICOM file library.
    ///
    /// This is a computed passthrough to the study browser's library,
    /// ensuring a single source of truth across the application.
    public var library: LibraryModel {
        get { studyBrowserViewModel.library }
        set { studyBrowserViewModel.library = newValue }
    }

    /// Application settings service.
    public let settingsService: SettingsService

    /// File I/O service.
    public let fileService: DICOMFileService

    /// Navigation service.
    public let navigationService: NavigationService

    /// Storage service.
    public let storageService: StorageService

    /// Thumbnail service.
    public let thumbnailService: ThumbnailService

    /// Status message displayed in the status bar.
    public var statusMessage: String

    /// The library storage service for persistence.
    public let libraryStorageService: LibraryStorageService

    /// Persistent study browser ViewModel — survives tab switches.
    public var studyBrowserViewModel: StudyBrowserViewModel

    /// Creates the main ViewModel with dependency-injected services.
    public init(
        settingsService: SettingsService = SettingsService(),
        fileService: DICOMFileService = DICOMFileService(),
        navigationService: NavigationService = NavigationService(),
        storageService: StorageService = StorageService(),
        thumbnailService: ThumbnailService? = nil,
        libraryStorageService: LibraryStorageService = LibraryStorageService()
    ) {
        self.settingsService = settingsService
        self.fileService = fileService
        self.navigationService = navigationService
        self.storageService = storageService
        self.thumbnailService = thumbnailService ?? ThumbnailService(storageService: storageService)
        self.libraryStorageService = libraryStorageService
        self.selectedDestination = NavigationService.defaultDestination
        self.isInspectorVisible = false
        self.showWelcomeSheet = settingsService.showWelcomeOnLaunch
        self.searchText = ""
        self.statusMessage = "Ready"

        // Load persisted library from disk so imports survive app restarts.
        let savedLibrary = libraryStorageService.load()

        // Create a single StudyBrowserViewModel that lives for the
        // entire app session — switching tabs no longer destroys it.
        // The `library` computed property on MainViewModel delegates
        // to this ViewModel, keeping a single source of truth.
        let importService = ImportService(fileService: fileService)
        self.studyBrowserViewModel = StudyBrowserViewModel(
            library: savedLibrary,
            importService: importService,
            libraryStorageService: libraryStorageService
        )
    }

    /// Navigates to the specified destination.
    public func navigate(to destination: NavigationDestination) {
        selectedDestination = destination
    }

    /// Toggles the inspector panel.
    public func toggleInspector() {
        isInspectorVisible.toggle()
    }

    /// Returns the primary navigation destinations.
    public var primaryDestinations: [NavigationDestination] {
        NavigationService.primaryDestinations
    }

    /// Filters navigation destinations based on search text.
    public var filteredDestinations: [NavigationDestination] {
        guard !searchText.isEmpty else { return primaryDestinations }
        return primaryDestinations.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Updates the status message.
    public func setStatus(_ message: String) {
        statusMessage = message
    }
}
