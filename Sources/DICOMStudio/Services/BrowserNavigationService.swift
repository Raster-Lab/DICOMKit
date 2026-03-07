// BrowserNavigationService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for Browser Navigation state (Milestone 18)

import Foundation

/// Thread-safe service that manages state for the Browser Navigation feature.
public final class BrowserNavigationService: @unchecked Sendable {
    private let lock = NSLock()

    // 18.1 Sidebar
    private var _categories: [BrowserCategory] = BrowserSidebarHelpers.buildCategories(from: [])
    private var _toolItems: [BrowserToolItem] = []
    private var _selectedToolName: String? = nil
    private var _searchQuery: String = ""
    private var _displayMode: SidebarDisplayMode = .allTools
    private var _expansionState: CategoryExpansionState = BrowserSidebarHelpers.defaultExpansionState()

    // 18.2 Content
    private var _contentTabs: [ContentTab] = []
    private var _contentLayout: ContentLayout = .welcome
    private var _currentToolHeader: ToolHeaderInfo? = nil

    // 18.3 Window
    private var _sidebarState: SidebarState = .expanded
    private var _windowConfig: WindowConfiguration = WindowConfiguration()
    private var _windowTitle: String = "DICOM Studio"

    // 18.4 Welcome
    private var _recentTools: [RecentToolEntry] = []
    private var _keyboardShortcuts: [KeyboardShortcutInfo] = WelcomeViewHelpers.defaultKeyboardShortcuts()

    public init() {}

    // MARK: - 18.1 Sidebar

    public func getCategories() -> [BrowserCategory] { lock.withLock { _categories } }
    public func setCategories(_ categories: [BrowserCategory]) { lock.withLock { _categories = categories } }
    public func getToolItems() -> [BrowserToolItem] { lock.withLock { _toolItems } }
    public func setToolItems(_ items: [BrowserToolItem]) { lock.withLock { _toolItems = items } }
    public func getSelectedToolName() -> String? { lock.withLock { _selectedToolName } }
    public func setSelectedToolName(_ name: String?) { lock.withLock { _selectedToolName = name } }
    public func getSearchQuery() -> String { lock.withLock { _searchQuery } }
    public func setSearchQuery(_ query: String) { lock.withLock { _searchQuery = query } }
    public func getDisplayMode() -> SidebarDisplayMode { lock.withLock { _displayMode } }
    public func setDisplayMode(_ mode: SidebarDisplayMode) { lock.withLock { _displayMode = mode } }
    public func getExpansionState() -> CategoryExpansionState { lock.withLock { _expansionState } }
    public func setExpansionState(_ state: CategoryExpansionState) { lock.withLock { _expansionState = state } }

    // MARK: - 18.2 Content

    public func getContentTabs() -> [ContentTab] { lock.withLock { _contentTabs } }
    public func setContentTabs(_ tabs: [ContentTab]) { lock.withLock { _contentTabs = tabs } }
    public func getContentLayout() -> ContentLayout { lock.withLock { _contentLayout } }
    public func setContentLayout(_ layout: ContentLayout) { lock.withLock { _contentLayout = layout } }
    public func getCurrentToolHeader() -> ToolHeaderInfo? { lock.withLock { _currentToolHeader } }
    public func setCurrentToolHeader(_ header: ToolHeaderInfo?) { lock.withLock { _currentToolHeader = header } }

    // MARK: - 18.3 Window

    public func getSidebarState() -> SidebarState { lock.withLock { _sidebarState } }
    public func setSidebarState(_ state: SidebarState) { lock.withLock { _sidebarState = state } }
    public func getWindowConfig() -> WindowConfiguration { lock.withLock { _windowConfig } }
    public func setWindowConfig(_ config: WindowConfiguration) { lock.withLock { _windowConfig = config } }
    public func getWindowTitle() -> String { lock.withLock { _windowTitle } }
    public func setWindowTitle(_ title: String) { lock.withLock { _windowTitle = title } }

    // MARK: - 18.4 Welcome

    public func getRecentTools() -> [RecentToolEntry] { lock.withLock { _recentTools } }
    public func setRecentTools(_ tools: [RecentToolEntry]) { lock.withLock { _recentTools = tools } }
    public func getKeyboardShortcuts() -> [KeyboardShortcutInfo] { lock.withLock { _keyboardShortcuts } }
    public func setKeyboardShortcuts(_ shortcuts: [KeyboardShortcutInfo]) { lock.withLock { _keyboardShortcuts = shortcuts } }

    // MARK: - Composite Operations

    /// Selects a tool by name, updates the content layout, and sets the window title.
    public func selectTool(name: String?) {
        lock.withLock {
            _selectedToolName = name
            _contentLayout = ContentLayoutHelpers.layoutForTool(name)
            if let name = name {
                _currentToolHeader = ContentLayoutHelpers.toolHeaderInfo(for: name)
                let display = ToolRegistryHelpers.toolDisplayName(for: name)
                _windowTitle = "\(display) — DICOM Studio"
            } else {
                _currentToolHeader = nil
                _windowTitle = "DICOM Studio"
            }
        }
    }

    /// Toggles the sidebar between expanded and collapsed.
    public func toggleSidebar() {
        lock.withLock {
            _sidebarState = _sidebarState.isExpanded ? .collapsed : .expanded
        }
    }

    /// Toggles the expansion state of the given category.
    public func toggleCategory(_ category: ToolCategory) {
        lock.withLock {
            _expansionState.toggle(category)
        }
    }

    /// Adds a recent tool entry, replacing any existing entry for the same tool
    /// and trimming to `WelcomeViewHelpers.maxRecentTools` (5) most-recent entries.
    public func addRecentTool(name: String, displayName: String, sfSymbol: String) {
        lock.withLock {
            _recentTools = WelcomeViewHelpers.addRecentTool(
                name: name,
                displayName: displayName,
                sfSymbol: sfSymbol,
                to: _recentTools
            )
        }
    }

    /// Converts `ToolInfo` entries to `BrowserToolItem` entries using the current selection.
    public func updateToolItems(from tools: [ToolInfo]) {
        lock.withLock {
            _toolItems = BrowserSidebarHelpers.buildToolItems(
                from: tools,
                selectedTool: _selectedToolName
            )
            _categories = BrowserSidebarHelpers.buildCategories(from: tools)
        }
    }

    /// Returns tool items filtered by the current search query.
    public func filteredToolItems() -> [BrowserToolItem] {
        lock.withLock {
            ToolSearchHelpers.filterToolItems(_toolItems, query: _searchQuery)
        }
    }
}
