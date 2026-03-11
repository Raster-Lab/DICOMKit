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

    /// Persistent image viewer ViewModel — survives tab switches.
    public var imageViewerViewModel: ImageViewerViewModel

    /// Persistent networking ViewModel — survives tab switches.
    public var networkingViewModel: NetworkingViewModel

    /// Persistent CLI Workshop ViewModel — survives tab switches.
    public var cliWorkshopViewModel: CLIWorkshopViewModel

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
        let importService = ImportService(
            fileService: fileService,
            copyDirectory: storageService.importDirectory
        )
        self.studyBrowserViewModel = StudyBrowserViewModel(
            library: savedLibrary,
            importService: importService,
            libraryStorageService: libraryStorageService
        )

        self.imageViewerViewModel = ImageViewerViewModel()

        let profileStorage = ServerProfileStorageService(storageService: storageService)
        let networkingService = NetworkingService(profileStorage: profileStorage)
        self.networkingViewModel = NetworkingViewModel(service: networkingService)

        self.cliWorkshopViewModel = CLIWorkshopViewModel()
        // Share saved server profiles so CLI Workshop can pick from them.
        self.cliWorkshopViewModel.savedServerProfiles = networkingViewModel.serverProfiles

        // Wire the CLI workshop's "open in viewer" callback.
        self.cliWorkshopViewModel.onOpenInViewer = { [weak self] filePath, scopedURL in
            guard let self else { return }
            self.imageViewerViewModel.loadFile(at: filePath, securityScopedParent: scopedURL)
            self.selectedDestination = .viewer
        }

        // Wire the study browser's "open in viewer" callback.
        self.studyBrowserViewModel.onOpenInViewer = { [weak self] filePath in
            guard let self else { return }
            self.imageViewerViewModel.loadFile(at: filePath)
            self.selectedDestination = .viewer
        }
    }

    /// Opens the first retrieved file from CLI Workshop in the viewer.
    public func openLastRetrievedInViewer() {
        guard let firstFile = cliWorkshopViewModel.lastRetrievedFiles.first else { return }
        imageViewerViewModel.loadFile(
            at: firstFile,
            securityScopedParent: cliWorkshopViewModel.lastRetrievedOutputURL
        )
        selectedDestination = .viewer
    }

    /// Navigates to the specified destination.
    public func navigate(to destination: NavigationDestination) {
        selectedDestination = destination
    }

    /// Opens the first displayable instance of the given study in the viewer.
    public func openStudyInViewer(_ studyUID: String) {
        let seriesList = library.seriesForStudy(studyUID)
        for series in seriesList {
            let instances = library.instancesForSeries(series.seriesInstanceUID)
            if let first = instances.first {
                imageViewerViewModel.loadFile(at: first.filePath)
                selectedDestination = .viewer
                return
            }
        }
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
