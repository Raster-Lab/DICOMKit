// CLIShellFoundationService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for CLI Shell Foundation state (Milestone 17)

import Foundation

/// Thread-safe service managing state for the CLI Shell Foundation feature.
public final class CLIShellFoundationService: @unchecked Sendable {
    private let lock = NSLock()

    // 17.1 Tool Registry
    private var _tools: [ToolInfo] = ToolRegistryHelpers.allDefaultTools()
    private var _selectedToolName: String? = nil
    private var _searchQuery: String = ""
    private var _toolSearchPaths: [ToolSearchPath] = ToolRegistryHelpers.defaultSearchPaths

    // 17.2 Version Checking
    private var _studioVersion: SemanticVersion = VersionHelpers.currentStudioVersion
    private var _versionReport: VersionReport? = nil
    private var _lastVersionCheck: Date? = nil

    // 17.3 GitHub Release
    private var _latestRelease: ReleaseInfo? = nil
    private var _releaseAssets: [ReleaseAsset] = []
    private var _isRateLimited: Bool = false

    // 17.4 Tool Installation
    private var _installationState: InstallationState = .idle
    private var _installPreferences: InstallationPreferences = ToolInstallHelpers.defaultInstallPreferences()
    private var _downloadProgress: DownloadProgress? = nil

    // 17.5 Auto-Update
    private var _updateState: UpdateState = .unchecked
    private var _updateCheckFrequency: UpdateCheckFrequency = AutoUpdateHelpers.defaultCheckFrequency
    private var _lastUpdateCheck: Date? = nil

    // 17.6 Launch Coordinator
    private var _launchPhase: LaunchPhase = .initializing
    private var _launchStartTime: Date? = nil
    private var _setupAssistantDismissed: Bool = false

    public init() {}

    // MARK: - 17.1 Tool Registry

    public func getTools() -> [ToolInfo] { lock.withLock { _tools } }
    public func setTools(_ tools: [ToolInfo]) { lock.withLock { _tools = tools } }
    public func getSelectedToolName() -> String? { lock.withLock { _selectedToolName } }
    public func setSelectedToolName(_ name: String?) { lock.withLock { _selectedToolName = name } }
    public func getSearchQuery() -> String { lock.withLock { _searchQuery } }
    public func setSearchQuery(_ query: String) { lock.withLock { _searchQuery = query } }
    public func getToolSearchPaths() -> [ToolSearchPath] { lock.withLock { _toolSearchPaths } }
    public func setToolSearchPaths(_ paths: [ToolSearchPath]) { lock.withLock { _toolSearchPaths = paths } }

    /// Adds a tool to the registry.
    public func addTool(_ tool: ToolInfo) {
        lock.withLock { _tools.append(tool) }
    }

    /// Removes a tool by executable name.
    public func removeTool(name: String) {
        lock.withLock { _tools.removeAll { $0.name == name } }
    }

    /// Updates an existing tool entry matching by id.
    public func updateTool(_ tool: ToolInfo) {
        lock.withLock {
            guard let idx = _tools.firstIndex(where: { $0.id == tool.id }) else { return }
            _tools[idx] = tool
        }
    }

    /// Returns tools filtered by the current search query.
    public func filteredTools() -> [ToolInfo] {
        lock.withLock {
            ToolRegistryHelpers.filterTools(_tools, query: _searchQuery)
        }
    }

    /// Returns filtered tools grouped by category.
    public func toolsByCategory() -> [(category: ToolCategory, tools: [ToolInfo])] {
        let filtered = filteredTools()
        return ToolRegistryHelpers.toolsByCategory(filtered)
    }

    // MARK: - 17.2 Version Checking

    public func getStudioVersion() -> SemanticVersion { lock.withLock { _studioVersion } }
    public func setStudioVersion(_ version: SemanticVersion) { lock.withLock { _studioVersion = version } }
    public func getVersionReport() -> VersionReport? { lock.withLock { _versionReport } }
    public func setVersionReport(_ report: VersionReport?) { lock.withLock { _versionReport = report } }
    public func getLastVersionCheck() -> Date? { lock.withLock { _lastVersionCheck } }
    public func setLastVersionCheck(_ date: Date?) { lock.withLock { _lastVersionCheck = date } }

    /// Generates a version report for the current tool set and stores it.
    public func generateVersionReport() {
        lock.withLock {
            _versionReport = VersionHelpers.generateVersionReport(
                tools: _tools,
                studioVersion: _studioVersion
            )
            _lastVersionCheck = Date()
        }
    }

    // MARK: - 17.3 GitHub Release

    public func getLatestRelease() -> ReleaseInfo? { lock.withLock { _latestRelease } }
    public func setLatestRelease(_ release: ReleaseInfo?) { lock.withLock { _latestRelease = release } }
    public func getReleaseAssets() -> [ReleaseAsset] { lock.withLock { _releaseAssets } }
    public func setReleaseAssets(_ assets: [ReleaseAsset]) { lock.withLock { _releaseAssets = assets } }
    public func getIsRateLimited() -> Bool { lock.withLock { _isRateLimited } }
    public func setIsRateLimited(_ limited: Bool) { lock.withLock { _isRateLimited = limited } }

    // MARK: - 17.4 Tool Installation

    public func getInstallationState() -> InstallationState { lock.withLock { _installationState } }
    public func setInstallationState(_ state: InstallationState) { lock.withLock { _installationState = state } }
    public func getInstallPreferences() -> InstallationPreferences { lock.withLock { _installPreferences } }
    public func setInstallPreferences(_ prefs: InstallationPreferences) { lock.withLock { _installPreferences = prefs } }
    public func getDownloadProgress() -> DownloadProgress? { lock.withLock { _downloadProgress } }
    public func setDownloadProgress(_ progress: DownloadProgress?) { lock.withLock { _downloadProgress = progress } }

    // MARK: - 17.5 Auto-Update

    public func getUpdateState() -> UpdateState { lock.withLock { _updateState } }
    public func setUpdateState(_ state: UpdateState) { lock.withLock { _updateState = state } }
    public func getUpdateCheckFrequency() -> UpdateCheckFrequency { lock.withLock { _updateCheckFrequency } }
    public func setUpdateCheckFrequency(_ freq: UpdateCheckFrequency) { lock.withLock { _updateCheckFrequency = freq } }
    public func getLastUpdateCheck() -> Date? { lock.withLock { _lastUpdateCheck } }
    public func setLastUpdateCheck(_ date: Date?) { lock.withLock { _lastUpdateCheck = date } }

    // MARK: - 17.6 Launch Coordinator

    public func getLaunchPhase() -> LaunchPhase { lock.withLock { _launchPhase } }
    public func setLaunchPhase(_ phase: LaunchPhase) { lock.withLock { _launchPhase = phase } }
    public func getLaunchStartTime() -> Date? { lock.withLock { _launchStartTime } }
    public func setLaunchStartTime(_ date: Date?) { lock.withLock { _launchStartTime = date } }
    public func getSetupAssistantDismissed() -> Bool { lock.withLock { _setupAssistantDismissed } }
    public func setSetupAssistantDismissed(_ dismissed: Bool) { lock.withLock { _setupAssistantDismissed = dismissed } }

    /// Advances the launch phase based on current state.
    public func advanceLaunchPhase() {
        lock.withLock {
            let toolsDiscovered = !_tools.isEmpty
            let versionsChecked = _versionReport != nil
            let updatesChecked = _updateState != .unchecked
            _launchPhase = LaunchCoordinatorHelpers.determineNextPhase(
                after: _launchPhase,
                toolsDiscovered: toolsDiscovered,
                versionsChecked: versionsChecked,
                updatesChecked: updatesChecked
            )
        }
    }
}
