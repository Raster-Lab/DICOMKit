// MacOSEnhancementsViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for macOS-Specific Enhancements (Milestone 14)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class MacOSEnhancementsViewModel {
    private let service: MacOSEnhancementsService

    public var activeTab: MacOSEnhancementsTab = .multiWindow
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // 14.1 Multi-Window
    public var openWindows: [WindowState] = []
    public var isDragOperationActive: Bool = false
    public var pendingDragOperation: WindowDragOperation? = nil

    // 14.2 Menu Bar
    public var menuActions: [MenuActionEntry] = []
    public var selectedMenuCategory: MenuCategory = .file

    // 14.3 Keyboard Shortcuts
    public var shortcuts: [KeyboardShortcutEntry] = []
    public var shortcutSearchQuery: String = ""
    public var shortcutScopeFilter: KeyboardShortcutScope? = nil
    public var selectedShortcutEntry: KeyboardShortcutEntry? = nil

    // 14.4 Dock Integration
    public var dockBadgeState: DockBadgeState = DockBadgeState(transferCount: 0, isVisible: false)

    // 14.5 Automation
    public var automationScripts: [AutomationScriptEntry] = []
    public var selectedScriptID: UUID? = nil

    // 14.6 Quick Look
    public var quickLookState: QuickLookState = QuickLookState(
        status: .notInstalled,
        supportedExtensions: [],
        thumbnailCacheCount: 0,
        lastRefreshDate: nil
    )

    public init(service: MacOSEnhancementsService = MacOSEnhancementsService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        openWindows       = service.getOpenWindows()
        menuActions       = service.getMenuActions()
        shortcuts         = service.getShortcuts()
        shortcutSearchQuery  = service.getShortcutSearchQuery()
        shortcutScopeFilter  = service.getShortcutScopeFilter()
        dockBadgeState    = service.getDockBadgeState()
        automationScripts = service.getAutomationScripts()
        selectedScriptID  = service.getSelectedScriptID()
        quickLookState    = service.getQuickLookState()
    }

    // MARK: - 14.1 Multi-Window

    /// Opens a new viewer window for the given study UID and returns its state.
    @discardableResult
    public func openWindow(studyInstanceUID: String) -> WindowState {
        let index = openWindows.count
        let title = MultiWindowHelpers.windowTitle(for: studyInstanceUID, index: index)
        let window = WindowState(studyInstanceUID: studyInstanceUID, title: title, windowIndex: index)
        openWindows.append(window)
        service.setOpenWindows(openWindows)
        return window
    }

    /// Closes the window with the given ID.
    public func closeWindow(id: UUID) {
        openWindows.removeAll { $0.id == id }
        service.setOpenWindows(openWindows)
    }

    /// Updates the `lastFocused` timestamp for the given window.
    public func focusWindow(id: UUID) {
        guard let idx = openWindows.firstIndex(where: { $0.id == id }) else { return }
        openWindows[idx].lastFocused = Date()
        service.updateWindow(openWindows[idx])
    }

    /// Starts a drag operation between windows.
    public func startDragOperation(_ op: WindowDragOperation) {
        pendingDragOperation = op
        isDragOperationActive = true
    }

    /// Completes and clears the current drag operation.
    public func completeDragOperation() {
        pendingDragOperation = nil
        isDragOperationActive = false
    }

    // MARK: - 14.2 Menu Bar

    /// Returns menu actions filtered by the currently selected category.
    public func filteredMenuActions() -> [MenuActionEntry] {
        MenuBarHelpers.actions(for: selectedMenuCategory, in: menuActions)
    }

    /// Toggles the `isEnabled` flag on the action with the given ID.
    public func toggleMenuAction(id: UUID) {
        guard let idx = menuActions.firstIndex(where: { $0.id == id }) else { return }
        menuActions[idx].isEnabled.toggle()
        service.updateMenuAction(menuActions[idx])
    }

    // MARK: - 14.3 Keyboard Shortcuts

    /// Returns shortcuts filtered by scope and search query.
    public func filteredShortcuts() -> [KeyboardShortcutEntry] {
        var result = shortcuts
        if let scope = shortcutScopeFilter {
            result = result.filter { $0.scope == scope }
        }
        if !shortcutSearchQuery.isEmpty {
            let query = shortcutSearchQuery.lowercased()
            result = result.filter {
                $0.action.lowercased().contains(query) ||
                $0.shortcut.lowercased().contains(query) ||
                $0.actionIdentifier.lowercased().contains(query)
            }
        }
        return result
    }

    /// Updates the keyboard shortcut search query.
    public func updateShortcutQuery(_ query: String) {
        shortcutSearchQuery = query
        service.setShortcutSearchQuery(query)
    }

    /// Updates the scope filter for keyboard shortcuts.
    public func updateScopeFilter(_ scope: KeyboardShortcutScope?) {
        shortcutScopeFilter = scope
        service.setShortcutScopeFilter(scope)
    }

    /// Selects a keyboard shortcut entry.
    public func selectShortcut(_ entry: KeyboardShortcutEntry?) {
        selectedShortcutEntry = entry
    }

    /// Resets all shortcuts to the built-in defaults.
    public func resetShortcutsToDefault() {
        let defaults = KeyboardShortcutsHelpers.defaultShortcuts()
        shortcuts = defaults
        service.setShortcuts(defaults)
    }

    // MARK: - 14.4 Dock Integration

    /// Updates the active transfer count for the Dock badge.
    public func updateTransferCount(_ count: Int) {
        dockBadgeState = DockBadgeState(transferCount: count, isVisible: dockBadgeState.isVisible)
        service.setDockBadgeState(dockBadgeState)
    }

    /// Toggles whether the Dock badge is visible.
    public func toggleBadgeVisibility() {
        dockBadgeState = DockBadgeState(transferCount: dockBadgeState.transferCount, isVisible: !dockBadgeState.isVisible)
        service.setDockBadgeState(dockBadgeState)
    }

    // MARK: - 14.5 Automation

    /// Selects an automation script by ID.
    public func selectScript(id: UUID?) {
        selectedScriptID = id
        service.setSelectedScriptID(id)
    }

    /// Returns the currently selected automation script, or nil.
    public func selectedScript() -> AutomationScriptEntry? {
        guard let id = selectedScriptID else { return nil }
        return automationScripts.first { $0.id == id }
    }

    // MARK: - 14.6 Quick Look

    /// Updates the Quick Look plugin status.
    public func updateQuickLookStatus(_ status: QuickLookPluginStatus) {
        quickLookState = QuickLookState(
            status: status,
            supportedExtensions: quickLookState.supportedExtensions,
            thumbnailCacheCount: quickLookState.thumbnailCacheCount,
            lastRefreshDate: Date()
        )
        service.setQuickLookState(quickLookState)
    }

    /// Increments the thumbnail cache count by one.
    public func incrementThumbnailCache() {
        quickLookState = QuickLookState(
            status: quickLookState.status,
            supportedExtensions: quickLookState.supportedExtensions,
            thumbnailCacheCount: quickLookState.thumbnailCacheCount + 1,
            lastRefreshDate: quickLookState.lastRefreshDate
        )
        service.setQuickLookState(quickLookState)
    }

    /// Resets the thumbnail cache count to zero.
    public func clearThumbnailCache() {
        quickLookState = QuickLookState(
            status: quickLookState.status,
            supportedExtensions: quickLookState.supportedExtensions,
            thumbnailCacheCount: 0,
            lastRefreshDate: quickLookState.lastRefreshDate
        )
        service.setQuickLookState(quickLookState)
    }
}
