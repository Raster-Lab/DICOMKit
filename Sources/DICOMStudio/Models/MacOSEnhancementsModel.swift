// MacOSEnhancementsModel.swift
// DICOMStudio
//
// DICOM Studio — Data models for macOS-Specific Enhancements (Milestone 14)

import Foundation

// MARK: - Navigation Tab

/// Navigation tabs for the macOS-Specific Enhancements feature.
public enum MacOSEnhancementsTab: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case multiWindow       = "MULTI_WINDOW"
    case menuBar           = "MENU_BAR"
    case keyboardShortcuts = "KEYBOARD_SHORTCUTS"
    case dockIntegration   = "DOCK_INTEGRATION"
    case automation        = "AUTOMATION"
    case quickLook         = "QUICK_LOOK"

    public var id: String { rawValue }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .multiWindow:       return "Multi-Window"
        case .menuBar:           return "Menu Bar"
        case .keyboardShortcuts: return "Keyboard Shortcuts"
        case .dockIntegration:   return "Dock Integration"
        case .automation:        return "Automation"
        case .quickLook:         return "Quick Look"
        }
    }

    /// SF Symbol name for this tab.
    public var sfSymbol: String {
        switch self {
        case .multiWindow:       return "macwindow.on.rectangle"
        case .menuBar:           return "menubar.rectangle"
        case .keyboardShortcuts: return "keyboard"
        case .dockIntegration:   return "dock.rectangle"
        case .automation:        return "applescript"
        case .quickLook:         return "eye"
        }
    }
}

// MARK: - 14.1 Multi-Window

/// Represents the state of an open viewer window.
public struct WindowState: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var studyInstanceUID: String
    public var title: String
    public var isFullscreen: Bool
    public var isMiniaturized: Bool
    public var windowIndex: Int
    public var lastFocused: Date

    public init(
        id: UUID = UUID(),
        studyInstanceUID: String,
        title: String,
        windowIndex: Int,
        isFullscreen: Bool = false,
        isMiniaturized: Bool = false,
        lastFocused: Date = Date()
    ) {
        self.id = id
        self.studyInstanceUID = studyInstanceUID
        self.title = title
        self.windowIndex = windowIndex
        self.isFullscreen = isFullscreen
        self.isMiniaturized = isMiniaturized
        self.lastFocused = lastFocused
    }
}

/// Represents an in-progress drag operation between windows.
public struct WindowDragOperation: Sendable {
    public var sourceWindowID: UUID
    public var destinationWindowID: UUID?
    public var frameIndex: Int
    public var sopInstanceUID: String

    public init(
        sourceWindowID: UUID,
        destinationWindowID: UUID? = nil,
        frameIndex: Int,
        sopInstanceUID: String
    ) {
        self.sourceWindowID = sourceWindowID
        self.destinationWindowID = destinationWindowID
        self.frameIndex = frameIndex
        self.sopInstanceUID = sopInstanceUID
    }
}

// MARK: - 14.2 Menu Bar

/// Top-level menu categories in the macOS menu bar.
public enum MenuCategory: String, Sendable, Equatable, Hashable, CaseIterable {
    case file   = "FILE"
    case edit   = "EDIT"
    case view   = "VIEW"
    case tools  = "TOOLS"
    case window = "WINDOW"
    case help   = "HELP"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .file:   return "File"
        case .edit:   return "Edit"
        case .view:   return "View"
        case .tools:  return "Tools"
        case .window: return "Window"
        case .help:   return "Help"
        }
    }
}

/// A single entry in the macOS menu bar action list.
public struct MenuActionEntry: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var category: MenuCategory
    public var title: String
    /// Keyboard shortcut string, e.g. "⌘O".
    public var keyboardShortcut: String
    public var isEnabled: Bool
    public var isSeparator: Bool
    /// Unique action identifier, e.g. "file.open".
    public var actionIdentifier: String

    public init(
        id: UUID = UUID(),
        category: MenuCategory,
        title: String,
        keyboardShortcut: String = "",
        isEnabled: Bool = true,
        isSeparator: Bool = false,
        actionIdentifier: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.keyboardShortcut = keyboardShortcut
        self.isEnabled = isEnabled
        self.isSeparator = isSeparator
        self.actionIdentifier = actionIdentifier
    }
}

// MARK: - 14.3 Keyboard Shortcuts

/// Scope in which a keyboard shortcut is active.
public enum KeyboardShortcutScope: String, Sendable, Equatable, Hashable, CaseIterable {
    case global     = "GLOBAL"
    case viewer     = "VIEWER"
    case library    = "LIBRARY"
    case networking = "NETWORKING"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .global:     return "Global"
        case .viewer:     return "Viewer"
        case .library:    return "Library"
        case .networking: return "Networking"
        }
    }
}

/// A single keyboard shortcut entry.
public struct KeyboardShortcutEntry: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var scope: KeyboardShortcutScope
    /// Shortcut string, e.g. "⌘O".
    public var shortcut: String
    /// Human-readable action description, e.g. "Open File".
    public var action: String
    /// Unique action identifier, e.g. "file.open".
    public var actionIdentifier: String
    public var isCustomizable: Bool

    public init(
        id: UUID = UUID(),
        scope: KeyboardShortcutScope,
        shortcut: String,
        action: String,
        actionIdentifier: String,
        isCustomizable: Bool = true
    ) {
        self.id = id
        self.scope = scope
        self.shortcut = shortcut
        self.action = action
        self.actionIdentifier = actionIdentifier
        self.isCustomizable = isCustomizable
    }
}

// MARK: - 14.4 Dock Integration

/// The current Dock badge state.
public struct DockBadgeState: Sendable {
    public var transferCount: Int
    public var isVisible: Bool

    /// The label text shown on the Dock badge.
    public var badgeLabel: String {
        isVisible && transferCount > 0 ? "\(transferCount)" : ""
    }

    public init(transferCount: Int, isVisible: Bool) {
        self.transferCount = transferCount
        self.isVisible = isVisible
    }
}

// MARK: - 14.5 Automation

/// Types of automation scripts supported.
public enum AutomationScriptType: String, Sendable, Equatable, Hashable, CaseIterable {
    case appleScript = "APPLE_SCRIPT"
    case shortcuts   = "SHORTCUTS"
    case shellScript = "SHELL_SCRIPT"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .appleScript: return "AppleScript"
        case .shortcuts:   return "Shortcuts"
        case .shellScript: return "Shell Script"
        }
    }

    /// SF Symbol for this script type.
    public var sfSymbol: String {
        switch self {
        case .appleScript: return "applescript"
        case .shortcuts:   return "wand.and.stars"
        case .shellScript: return "terminal"
        }
    }
}

/// A sample automation script entry.
public struct AutomationScriptEntry: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String
    public var scriptType: AutomationScriptType
    public var sampleScript: String

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        scriptType: AutomationScriptType,
        sampleScript: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.scriptType = scriptType
        self.sampleScript = sampleScript
    }
}

// MARK: - 14.6 Quick Look

/// Installation status of the DICOM Quick Look plugin.
public enum QuickLookPluginStatus: String, Sendable, Equatable, Hashable, CaseIterable {
    case notInstalled = "NOT_INSTALLED"
    case installed    = "INSTALLED"
    case active       = "ACTIVE"
    case error        = "ERROR"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .notInstalled: return "Not Installed"
        case .installed:    return "Installed"
        case .active:       return "Active"
        case .error:        return "Error"
        }
    }

    /// SF Symbol for this status.
    public var sfSymbol: String {
        switch self {
        case .notInstalled: return "xmark.circle"
        case .installed:    return "checkmark.circle"
        case .active:       return "checkmark.circle.fill"
        case .error:        return "exclamationmark.circle"
        }
    }

    /// Brief description of this status.
    public var description: String {
        switch self {
        case .notInstalled:
            return "The Quick Look plugin is not installed. Install it to preview DICOM files in Finder."
        case .installed:
            return "The Quick Look plugin is installed but not yet active."
        case .active:
            return "The Quick Look plugin is active. DICOM thumbnails are enabled in Finder."
        case .error:
            return "The Quick Look plugin encountered an error. Try reinstalling it."
        }
    }
}

/// Current state of Quick Look plugin support.
public struct QuickLookState: Sendable {
    public var status: QuickLookPluginStatus
    public var supportedExtensions: [String]
    public var thumbnailCacheCount: Int
    public var lastRefreshDate: Date?

    public init(
        status: QuickLookPluginStatus,
        supportedExtensions: [String],
        thumbnailCacheCount: Int,
        lastRefreshDate: Date? = nil
    ) {
        self.status = status
        self.supportedExtensions = supportedExtensions
        self.thumbnailCacheCount = thumbnailCacheCount
        self.lastRefreshDate = lastRefreshDate
    }
}
