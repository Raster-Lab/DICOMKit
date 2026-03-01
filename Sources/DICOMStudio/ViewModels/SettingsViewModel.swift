// SettingsViewModel.swift
// DICOMStudio
//
// DICOM Studio — Settings ViewModel

import Foundation
import Observation

/// Represents a section within the settings UI.
public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case privacy = "Privacy"
    case performance = "Performance"
    case about = "About"

    public var id: String { rawValue }

    /// SF Symbol for this settings section.
    public var systemImage: String {
        switch self {
        case .general: return "gear"
        case .privacy: return "lock.shield"
        case .performance: return "gauge.with.dots.needle.bottom.50percent"
        case .about: return "info.circle"
        }
    }
}

/// ViewModel for the Settings interface.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class SettingsViewModel {
    /// The backing settings service.
    public let settingsService: SettingsService

    /// Currently selected settings section.
    public var selectedSection: SettingsSection

    // MARK: - General Settings

    /// Current appearance mode.
    public var appearance: AppearanceMode {
        didSet { settingsService.appearance = appearance }
    }

    /// Default window center.
    public var defaultWindowCenter: Int {
        didSet { settingsService.defaultWindowCenter = defaultWindowCenter }
    }

    /// Default window width.
    public var defaultWindowWidth: Int {
        didSet { settingsService.defaultWindowWidth = defaultWindowWidth }
    }

    /// Whether to show welcome screen on launch.
    public var showWelcomeOnLaunch: Bool {
        didSet { settingsService.showWelcomeOnLaunch = showWelcomeOnLaunch }
    }

    /// Maximum number of recent files.
    public var recentFilesLimit: Int {
        didSet { settingsService.recentFilesLimit = recentFilesLimit }
    }

    // MARK: - Privacy Settings

    /// Whether anonymization is enabled by default.
    public var anonymizationEnabled: Bool {
        didSet { settingsService.anonymizationEnabled = anonymizationEnabled }
    }

    /// Whether audit logging is enabled.
    public var auditLoggingEnabled: Bool {
        didSet { settingsService.auditLoggingEnabled = auditLoggingEnabled }
    }

    /// Whether to remove private tags during anonymization.
    public var removePrivateTags: Bool {
        didSet { settingsService.removePrivateTags = removePrivateTags }
    }

    // MARK: - Performance Settings

    /// Maximum cache size in MB.
    public var maxCacheSizeMB: Int {
        didSet { settingsService.maxCacheSizeMB = maxCacheSizeMB }
    }

    /// Maximum memory usage in MB.
    public var maxMemoryUsageMB: Int {
        didSet { settingsService.maxMemoryUsageMB = maxMemoryUsageMB }
    }

    /// Thumbnail quality (0.0–1.0).
    public var thumbnailQuality: Double {
        didSet { settingsService.thumbnailQuality = thumbnailQuality }
    }

    /// Whether prefetching is enabled.
    public var prefetchEnabled: Bool {
        didSet { settingsService.prefetchEnabled = prefetchEnabled }
    }

    /// Thread pool size.
    public var threadPoolSize: Int {
        didSet { settingsService.threadPoolSize = threadPoolSize }
    }

    /// Creates a settings ViewModel from the given service.
    public init(settingsService: SettingsService = SettingsService()) {
        self.settingsService = settingsService
        self.selectedSection = .general

        // Initialize from current settings
        self.appearance = settingsService.appearance
        self.defaultWindowCenter = settingsService.defaultWindowCenter
        self.defaultWindowWidth = settingsService.defaultWindowWidth
        self.showWelcomeOnLaunch = settingsService.showWelcomeOnLaunch
        self.recentFilesLimit = settingsService.recentFilesLimit
        self.anonymizationEnabled = settingsService.anonymizationEnabled
        self.auditLoggingEnabled = settingsService.auditLoggingEnabled
        self.removePrivateTags = settingsService.removePrivateTags
        self.maxCacheSizeMB = settingsService.maxCacheSizeMB
        self.maxMemoryUsageMB = settingsService.maxMemoryUsageMB
        self.thumbnailQuality = settingsService.thumbnailQuality
        self.prefetchEnabled = settingsService.prefetchEnabled
        self.threadPoolSize = settingsService.threadPoolSize
    }

    /// Resets all settings to defaults.
    public func resetAllToDefaults() {
        settingsService.resetAllToDefaults()
        appearance = settingsService.appearance
        defaultWindowCenter = settingsService.defaultWindowCenter
        defaultWindowWidth = settingsService.defaultWindowWidth
        showWelcomeOnLaunch = settingsService.showWelcomeOnLaunch
        recentFilesLimit = settingsService.recentFilesLimit
        anonymizationEnabled = settingsService.anonymizationEnabled
        auditLoggingEnabled = settingsService.auditLoggingEnabled
        removePrivateTags = settingsService.removePrivateTags
        maxCacheSizeMB = settingsService.maxCacheSizeMB
        maxMemoryUsageMB = settingsService.maxMemoryUsageMB
        thumbnailQuality = settingsService.thumbnailQuality
        prefetchEnabled = settingsService.prefetchEnabled
        threadPoolSize = settingsService.threadPoolSize
    }
}
