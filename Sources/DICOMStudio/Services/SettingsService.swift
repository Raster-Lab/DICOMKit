// SettingsService.swift
// DICOMStudio
//
// DICOM Studio — User preferences and configuration

import Foundation

/// Keys for user preference storage.
public enum SettingsKey: String, Sendable {
    // General
    case appearance = "studio.appearance"
    case defaultWindowCenter = "studio.defaultWindowCenter"
    case defaultWindowWidth = "studio.defaultWindowWidth"
    case showWelcomeOnLaunch = "studio.showWelcomeOnLaunch"
    case recentFilesLimit = "studio.recentFilesLimit"

    // Privacy
    case anonymizationEnabled = "studio.anonymizationEnabled"
    case auditLoggingEnabled = "studio.auditLoggingEnabled"
    case removePrivateTags = "studio.removePrivateTags"

    // Performance
    case maxCacheSizeMB = "studio.maxCacheSizeMB"
    case maxMemoryUsageMB = "studio.maxMemoryUsageMB"
    case thumbnailQuality = "studio.thumbnailQuality"
    case prefetchEnabled = "studio.prefetchEnabled"
    case threadPoolSize = "studio.threadPoolSize"
}

/// Appearance mode for the application.
public enum AppearanceMode: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

/// Manages user preferences with default values.
///
/// On macOS, this wraps UserDefaults. On other platforms (including Linux
/// for testing), it uses an in-memory dictionary.
public final class SettingsService: @unchecked Sendable {
    private var storage: [String: Any]
    private let lock = NSLock()

    /// Default values for all settings.
    public nonisolated(unsafe) static let defaults: [String: Any] = [
        SettingsKey.appearance.rawValue: AppearanceMode.system.rawValue,
        SettingsKey.defaultWindowCenter.rawValue: 40,
        SettingsKey.defaultWindowWidth.rawValue: 400,
        SettingsKey.showWelcomeOnLaunch.rawValue: true,
        SettingsKey.recentFilesLimit.rawValue: 20,
        SettingsKey.anonymizationEnabled.rawValue: false,
        SettingsKey.auditLoggingEnabled.rawValue: false,
        SettingsKey.removePrivateTags.rawValue: true,
        SettingsKey.maxCacheSizeMB.rawValue: 512,
        SettingsKey.maxMemoryUsageMB.rawValue: 2048,
        SettingsKey.thumbnailQuality.rawValue: 0.7,
        SettingsKey.prefetchEnabled.rawValue: true,
        SettingsKey.threadPoolSize.rawValue: 4,
    ]

    /// Creates a settings service with default values.
    public init() {
        self.storage = Self.defaults
    }

    // MARK: - Generic Accessors

    /// Returns the value for a given key, or the default if not set.
    public func value<T>(for key: SettingsKey) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key.rawValue] as? T
    }

    /// Sets the value for a given key.
    public func setValue<T>(_ value: T, for key: SettingsKey) {
        lock.lock()
        defer { lock.unlock() }
        storage[key.rawValue] = value
    }

    /// Resets a key to its default value.
    public func resetToDefault(for key: SettingsKey) {
        lock.lock()
        defer { lock.unlock() }
        storage[key.rawValue] = Self.defaults[key.rawValue]
    }

    /// Resets all settings to defaults.
    public func resetAllToDefaults() {
        lock.lock()
        defer { lock.unlock() }
        storage = Self.defaults
    }

    // MARK: - Typed Convenience Accessors

    /// Current appearance mode.
    public var appearance: AppearanceMode {
        get {
            let raw: String = value(for: .appearance) ?? AppearanceMode.system.rawValue
            return AppearanceMode(rawValue: raw) ?? .system
        }
        set { setValue(newValue.rawValue, for: .appearance) }
    }

    /// Default window center for image display.
    public var defaultWindowCenter: Int {
        get { value(for: .defaultWindowCenter) ?? 40 }
        set { setValue(newValue, for: .defaultWindowCenter) }
    }

    /// Default window width for image display.
    public var defaultWindowWidth: Int {
        get { value(for: .defaultWindowWidth) ?? 400 }
        set { setValue(newValue, for: .defaultWindowWidth) }
    }

    /// Whether to show the welcome screen on launch.
    public var showWelcomeOnLaunch: Bool {
        get { value(for: .showWelcomeOnLaunch) ?? true }
        set { setValue(newValue, for: .showWelcomeOnLaunch) }
    }

    /// Maximum number of recent files to track.
    public var recentFilesLimit: Int {
        get { value(for: .recentFilesLimit) ?? 20 }
        set { setValue(newValue, for: .recentFilesLimit) }
    }

    /// Whether anonymization is enabled by default.
    public var anonymizationEnabled: Bool {
        get { value(for: .anonymizationEnabled) ?? false }
        set { setValue(newValue, for: .anonymizationEnabled) }
    }

    /// Whether audit logging is enabled.
    public var auditLoggingEnabled: Bool {
        get { value(for: .auditLoggingEnabled) ?? false }
        set { setValue(newValue, for: .auditLoggingEnabled) }
    }

    /// Whether to remove private tags during anonymization.
    public var removePrivateTags: Bool {
        get { value(for: .removePrivateTags) ?? true }
        set { setValue(newValue, for: .removePrivateTags) }
    }

    /// Maximum cache size in megabytes.
    public var maxCacheSizeMB: Int {
        get { value(for: .maxCacheSizeMB) ?? 512 }
        set { setValue(newValue, for: .maxCacheSizeMB) }
    }

    /// Maximum memory usage in megabytes.
    public var maxMemoryUsageMB: Int {
        get { value(for: .maxMemoryUsageMB) ?? 2048 }
        set { setValue(newValue, for: .maxMemoryUsageMB) }
    }

    /// Thumbnail generation quality (0.0–1.0).
    public var thumbnailQuality: Double {
        get { value(for: .thumbnailQuality) ?? 0.7 }
        set { setValue(newValue, for: .thumbnailQuality) }
    }

    /// Whether image prefetching is enabled.
    public var prefetchEnabled: Bool {
        get { value(for: .prefetchEnabled) ?? true }
        set { setValue(newValue, for: .prefetchEnabled) }
    }

    /// Number of threads in the processing pool.
    public var threadPoolSize: Int {
        get { value(for: .threadPoolSize) ?? 4 }
        set { setValue(newValue, for: .threadPoolSize) }
    }
}
