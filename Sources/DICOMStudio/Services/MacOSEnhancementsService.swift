// MacOSEnhancementsService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for macOS-Specific Enhancements state (Milestone 14)

import Foundation

/// Thread-safe service that manages state for the macOS-Specific Enhancements feature.
public final class MacOSEnhancementsService: @unchecked Sendable {
    private let lock = NSLock()

    // 14.1 Multi-Window
    private var _openWindows: [WindowState] = []

    // 14.2 Menu Bar
    private var _menuActions: [MenuActionEntry] = MenuBarHelpers.defaultMenuActions()

    // 14.3 Keyboard Shortcuts
    private var _shortcuts: [KeyboardShortcutEntry] = KeyboardShortcutsHelpers.defaultShortcuts()
    private var _shortcutSearchQuery: String = ""
    private var _shortcutScopeFilter: KeyboardShortcutScope? = nil

    // 14.4 Dock Integration
    private var _dockBadgeState: DockBadgeState = DockBadgeState(transferCount: 0, isVisible: false)

    // 14.5 Automation
    private var _automationScripts: [AutomationScriptEntry] = AutomationHelpers.sampleScriptEntries()
    private var _selectedScriptID: UUID? = nil

    // 14.6 Quick Look
    private var _quickLookState: QuickLookState = QuickLookState(
        status: .notInstalled,
        supportedExtensions: QuickLookHelpers.supportedExtensions(),
        thumbnailCacheCount: 0,
        lastRefreshDate: nil
    )

    public init() {}

    // MARK: - 14.1 Multi-Window

    public func getOpenWindows() -> [WindowState] { lock.withLock { _openWindows } }
    public func setOpenWindows(_ windows: [WindowState]) { lock.withLock { _openWindows = windows } }
    public func addWindow(_ window: WindowState) { lock.withLock { _openWindows.append(window) } }
    public func removeWindow(id: UUID) {
        lock.withLock { _openWindows.removeAll { $0.id == id } }
    }
    public func updateWindow(_ window: WindowState) {
        lock.withLock {
            guard let idx = _openWindows.firstIndex(where: { $0.id == window.id }) else { return }
            _openWindows[idx] = window
        }
    }

    // MARK: - 14.2 Menu Bar

    public func getMenuActions() -> [MenuActionEntry] { lock.withLock { _menuActions } }
    public func setMenuActions(_ actions: [MenuActionEntry]) { lock.withLock { _menuActions = actions } }
    public func updateMenuAction(_ action: MenuActionEntry) {
        lock.withLock {
            guard let idx = _menuActions.firstIndex(where: { $0.id == action.id }) else { return }
            _menuActions[idx] = action
        }
    }

    // MARK: - 14.3 Keyboard Shortcuts

    public func getShortcuts() -> [KeyboardShortcutEntry] { lock.withLock { _shortcuts } }
    public func setShortcuts(_ shortcuts: [KeyboardShortcutEntry]) { lock.withLock { _shortcuts = shortcuts } }
    public func getShortcutSearchQuery() -> String { lock.withLock { _shortcutSearchQuery } }
    public func setShortcutSearchQuery(_ query: String) { lock.withLock { _shortcutSearchQuery = query } }
    public func getShortcutScopeFilter() -> KeyboardShortcutScope? { lock.withLock { _shortcutScopeFilter } }
    public func setShortcutScopeFilter(_ scope: KeyboardShortcutScope?) { lock.withLock { _shortcutScopeFilter = scope } }

    // MARK: - 14.4 Dock Integration

    public func getDockBadgeState() -> DockBadgeState { lock.withLock { _dockBadgeState } }
    public func setDockBadgeState(_ state: DockBadgeState) { lock.withLock { _dockBadgeState = state } }

    // MARK: - 14.5 Automation

    public func getAutomationScripts() -> [AutomationScriptEntry] { lock.withLock { _automationScripts } }
    public func setAutomationScripts(_ scripts: [AutomationScriptEntry]) { lock.withLock { _automationScripts = scripts } }
    public func getSelectedScriptID() -> UUID? { lock.withLock { _selectedScriptID } }
    public func setSelectedScriptID(_ id: UUID?) { lock.withLock { _selectedScriptID = id } }

    // MARK: - 14.6 Quick Look

    public func getQuickLookState() -> QuickLookState { lock.withLock { _quickLookState } }
    public func setQuickLookState(_ state: QuickLookState) { lock.withLock { _quickLookState = state } }
}
