// CLIShellFoundationViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for CLI Shell Foundation (Milestone 17)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class CLIShellFoundationViewModel {
    private let service: CLIShellFoundationService

    // 17.1 Tool Registry
    public var tools: [ToolInfo] = []
    public var selectedToolName: String? = nil
    public var searchQuery: String = ""
    public var toolSearchPaths: [ToolSearchPath] = []

    // 17.2 Version Checking
    public var studioVersion: SemanticVersion = VersionHelpers.currentStudioVersion
    public var versionReport: VersionReport? = nil
    public var lastVersionCheck: Date? = nil

    // 17.3 GitHub Release
    public var latestRelease: ReleaseInfo? = nil
    public var releaseAssets: [ReleaseAsset] = []
    public var isRateLimited: Bool = false

    // 17.4 Tool Installation
    public var installationState: InstallationState = .idle
    public var installPreferences: InstallationPreferences = ToolInstallHelpers.defaultInstallPreferences()
    public var downloadProgress: DownloadProgress? = nil

    // 17.5 Auto-Update
    public var updateState: UpdateState = .unchecked
    public var updateCheckFrequency: UpdateCheckFrequency = AutoUpdateHelpers.defaultCheckFrequency
    public var lastUpdateCheck: Date? = nil

    // 17.6 Launch Coordinator
    public var launchPhase: LaunchPhase = .initializing
    public var launchStartTime: Date? = nil
    public var setupAssistantDismissed: Bool = false

    public init(service: CLIShellFoundationService = CLIShellFoundationService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        tools                  = service.getTools()
        selectedToolName       = service.getSelectedToolName()
        searchQuery            = service.getSearchQuery()
        toolSearchPaths        = service.getToolSearchPaths()
        studioVersion          = service.getStudioVersion()
        versionReport          = service.getVersionReport()
        lastVersionCheck       = service.getLastVersionCheck()
        latestRelease          = service.getLatestRelease()
        releaseAssets          = service.getReleaseAssets()
        isRateLimited          = service.getIsRateLimited()
        installationState      = service.getInstallationState()
        installPreferences     = service.getInstallPreferences()
        downloadProgress       = service.getDownloadProgress()
        updateState            = service.getUpdateState()
        updateCheckFrequency   = service.getUpdateCheckFrequency()
        lastUpdateCheck        = service.getLastUpdateCheck()
        launchPhase            = service.getLaunchPhase()
        launchStartTime        = service.getLaunchStartTime()
        setupAssistantDismissed = service.getSetupAssistantDismissed()
    }

    // MARK: - 17.1 Tool Registry

    /// Selects a tool by executable name.
    public func selectTool(name: String?) {
        selectedToolName = name
        service.setSelectedToolName(name)
    }

    /// Updates the search query and syncs to the service.
    public func updateSearchQuery(_ query: String) {
        searchQuery = query
        service.setSearchQuery(query)
    }

    /// Returns tools filtered by the current search query.
    public func filteredTools() -> [ToolInfo] {
        ToolRegistryHelpers.filterTools(tools, query: searchQuery)
    }

    /// Returns filtered tools grouped by category.
    public func toolsByCategory() -> [(category: ToolCategory, tools: [ToolInfo])] {
        ToolRegistryHelpers.toolsByCategory(filteredTools())
    }

    /// Returns the `ToolInfo` for the currently selected tool, or nil.
    public func selectedToolInfo() -> ToolInfo? {
        guard let name = selectedToolName else { return nil }
        return tools.first { $0.name == name }
    }

    // MARK: - 17.2 Version Checking

    /// Generates a version report for all registered tools.
    public func generateVersionReport() {
        service.generateVersionReport()
        versionReport = service.getVersionReport()
        lastVersionCheck = service.getLastVersionCheck()
    }

    /// Returns a one-line summary of the current version report.
    public func versionSummary() -> String {
        guard let report = versionReport else { return "No version report available" }
        return VersionHelpers.versionSummary(for: report)
    }

    // MARK: - 17.4 Tool Installation

    /// Starts an installation by setting state to downloading.
    public func startInstallation() {
        installationState = .downloading(0)
        service.setInstallationState(.downloading(0))
    }

    /// Cancels the current installation.
    public func cancelInstallation() {
        installationState = .idle
        service.setInstallationState(.idle)
        downloadProgress = nil
        service.setDownloadProgress(nil)
    }

    // MARK: - 17.5 Auto-Update

    /// Initiates an update check.
    public func checkForUpdates() {
        updateState = .checking
        service.setUpdateState(.checking)
        lastUpdateCheck = Date()
        service.setLastUpdateCheck(lastUpdateCheck)
    }

    // MARK: - 17.6 Launch Coordinator

    /// Dismisses the setup assistant.
    public func dismissSetupAssistant() {
        setupAssistantDismissed = true
        service.setSetupAssistantDismissed(true)
    }

    /// Advances the launch phase based on current state.
    public func advanceLaunchPhase() {
        service.advanceLaunchPhase()
        launchPhase = service.getLaunchPhase()
    }

    /// Returns a user-facing summary of the current launch phase.
    public func launchPhaseSummary() -> String {
        LaunchCoordinatorHelpers.launchPhaseSummary(launchPhase)
    }

    /// Returns whether the setup assistant should be shown.
    public func shouldShowSetupAssistant() -> Bool {
        guard !setupAssistantDismissed else { return false }
        guard let report = versionReport else { return false }
        return LaunchCoordinatorHelpers.shouldShowSetupAssistant(report: report)
    }

    /// Returns whether the update banner should be shown.
    public func shouldShowUpdateBanner() -> Bool {
        LaunchCoordinatorHelpers.shouldShowUpdateBanner(state: updateState)
    }

    /// Returns a summary of tool availability, e.g. "35 of 38 tools available".
    public func toolAvailabilitySummary() -> String {
        let available = tools.filter { $0.availability == .available }.count
        let total = tools.count
        return "\(available) of \(total) tools available"
    }

    /// Formats the current download progress as a human-readable string.
    public func formatDownloadProgress() -> String {
        guard let progress = downloadProgress else { return "No download in progress" }
        return ToolInstallHelpers.formatDownloadProgress(progress)
    }
}
