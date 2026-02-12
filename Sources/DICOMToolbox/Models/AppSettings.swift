import Foundation

/// Application-wide settings with UserDefaults persistence
public final class AppSettings: Sendable {
    /// UserDefaults keys
    private enum Keys {
        static let isBeginnerMode = "DICOMToolbox.isBeginnerMode"
        static let defaultOutputDirectory = "DICOMToolbox.defaultOutputDirectory"
        static let consoleFontSize = "DICOMToolbox.consoleFontSize"
        static let savedProfiles = "DICOMToolbox.savedProfiles"
    }

    /// Default console font size
    public static let defaultConsoleFontSize: Double = 13.0

    /// Minimum console font size
    public static let minConsoleFontSize: Double = 9.0

    /// Maximum console font size
    public static let maxConsoleFontSize: Double = 24.0

    // MARK: - Beginner/Advanced Mode

    /// Loads the beginner mode setting
    public static func isBeginnerMode() -> Bool {
        #if canImport(AppKit) && os(macOS)
        return UserDefaults.standard.bool(forKey: Keys.isBeginnerMode)
        #else
        return false
        #endif
    }

    /// Saves the beginner mode setting
    public static func setBeginnerMode(_ enabled: Bool) {
        #if canImport(AppKit) && os(macOS)
        UserDefaults.standard.set(enabled, forKey: Keys.isBeginnerMode)
        #endif
    }

    // MARK: - Default Output Directory

    /// Loads the default output directory
    public static func defaultOutputDirectory() -> String? {
        #if canImport(AppKit) && os(macOS)
        return UserDefaults.standard.string(forKey: Keys.defaultOutputDirectory)
        #else
        return nil
        #endif
    }

    /// Saves the default output directory
    public static func setDefaultOutputDirectory(_ path: String?) {
        #if canImport(AppKit) && os(macOS)
        if let path {
            UserDefaults.standard.set(path, forKey: Keys.defaultOutputDirectory)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.defaultOutputDirectory)
        }
        #endif
    }

    // MARK: - Console Font Size

    /// Loads the console font size
    public static func consoleFontSize() -> Double {
        #if canImport(AppKit) && os(macOS)
        let size = UserDefaults.standard.double(forKey: Keys.consoleFontSize)
        if size < minConsoleFontSize || size > maxConsoleFontSize {
            return defaultConsoleFontSize
        }
        return size
        #else
        return defaultConsoleFontSize
        #endif
    }

    /// Saves the console font size
    public static func setConsoleFontSize(_ size: Double) {
        #if canImport(AppKit) && os(macOS)
        let clamped = min(max(size, minConsoleFontSize), maxConsoleFontSize)
        UserDefaults.standard.set(clamped, forKey: Keys.consoleFontSize)
        #endif
    }

    // MARK: - Server Profiles

    /// Loads saved server profiles
    public static func loadProfiles() -> [ServerProfile] {
        #if canImport(AppKit) && os(macOS)
        guard let data = UserDefaults.standard.data(forKey: Keys.savedProfiles),
              let profiles = try? JSONDecoder().decode([ServerProfile].self, from: data) else {
            return []
        }
        return profiles
        #else
        return []
        #endif
    }

    /// Saves server profiles
    public static func saveProfiles(_ profiles: [ServerProfile]) {
        #if canImport(AppKit) && os(macOS)
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Keys.savedProfiles)
        }
        #endif
    }

    /// Adds a new server profile
    public static func addProfile(_ profile: ServerProfile, to profiles: inout [ServerProfile]) {
        profiles.append(profile)
    }

    /// Updates an existing server profile
    public static func updateProfile(_ profile: ServerProfile, in profiles: inout [ServerProfile]) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        }
    }

    /// Deletes a server profile by ID
    public static func deleteProfile(id: UUID, from profiles: inout [ServerProfile]) {
        profiles.removeAll { $0.id == id }
    }
}
