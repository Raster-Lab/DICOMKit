// BrowserNavigationViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Browser Navigation (Milestone 18)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class BrowserNavigationViewModel {
    private let service: BrowserNavigationService

    // 18.1 Sidebar
    public var categories: [BrowserCategory] = []
    public var toolItems: [BrowserToolItem] = []
    public var selectedToolName: String? = nil
    public var searchQuery: String = ""
    public var displayMode: SidebarDisplayMode = .allTools
    public var expansionState: CategoryExpansionState = BrowserSidebarHelpers.defaultExpansionState()

    // 18.2 Content
    public var contentTabs: [ContentTab] = []
    public var contentLayout: ContentLayout = .welcome
    public var currentToolHeader: ToolHeaderInfo? = nil

    // 18.3 Window
    public var sidebarState: SidebarState = .expanded
    public var windowConfig: WindowConfiguration = WindowConfiguration()
    public var windowTitle: String = "DICOM Studio"

    // 18.4 Welcome
    public var recentTools: [RecentToolEntry] = []
    public var keyboardShortcuts: [KeyboardShortcutInfo] = []

    public init(service: BrowserNavigationService = BrowserNavigationService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        categories       = service.getCategories()
        toolItems        = service.getToolItems()
        selectedToolName = service.getSelectedToolName()
        searchQuery      = service.getSearchQuery()
        displayMode      = service.getDisplayMode()
        expansionState   = service.getExpansionState()
        contentTabs      = service.getContentTabs()
        contentLayout    = service.getContentLayout()
        currentToolHeader = service.getCurrentToolHeader()
        sidebarState     = service.getSidebarState()
        windowConfig     = service.getWindowConfig()
        windowTitle      = service.getWindowTitle()
        recentTools      = service.getRecentTools()
        keyboardShortcuts = service.getKeyboardShortcuts()
    }

    // MARK: - 18.1 Sidebar

    /// Selects a tool by name, updating local and service state, derived content
    /// layout / header / window title, and recording the tool as recently used.
    public func selectTool(name: String?) {
        selectedToolName = name
        service.selectTool(name: name)
        contentLayout = service.getContentLayout()
        currentToolHeader = service.getCurrentToolHeader()
        windowTitle = service.getWindowTitle()

        if let name = name {
            let display = ToolRegistryHelpers.toolDisplayName(for: name)
            let category = ToolRegistryHelpers.toolCategory(for: name)
            addRecentTool(name: name, displayName: display, sfSymbol: category.sfSymbol)
        }
    }

    /// Updates the search query for tool filtering.
    public func updateSearchQuery(_ query: String) {
        searchQuery = query
        service.setSearchQuery(query)
        displayMode = query.isEmpty ? .allTools : .searchResults
        service.setDisplayMode(displayMode)
    }

    /// Clears the current search query.
    public func clearSearch() {
        updateSearchQuery("")
    }

    /// Toggles the sidebar between expanded and collapsed.
    public func toggleSidebar() {
        service.toggleSidebar()
        sidebarState = service.getSidebarState()
    }

    /// Toggles the expansion state of the given category.
    public func toggleCategory(_ category: ToolCategory) {
        service.toggleCategory(category)
        expansionState = service.getExpansionState()
    }

    /// Expands all categories in the sidebar.
    public func expandAllCategories() {
        var state = expansionState
        state.expandAll()
        expansionState = state
        service.setExpansionState(state)
    }

    /// Collapses all categories in the sidebar.
    public func collapseAllCategories() {
        var state = expansionState
        state.collapseAll()
        expansionState = state
        service.setExpansionState(state)
    }

    /// Returns tool items filtered by the current search query.
    public func filteredToolItems() -> [BrowserToolItem] {
        ToolSearchHelpers.filterToolItems(toolItems, query: searchQuery)
    }

    /// Returns tool items belonging to the given category.
    public func toolsForCategory(_ category: ToolCategory) -> [BrowserToolItem] {
        BrowserSidebarHelpers.toolsForCategory(category, tools: toolItems)
    }

    // MARK: - 18.2 Content

    /// Returns header information for the currently selected tool, or `nil`.
    public func selectedToolHeader() -> ToolHeaderInfo? {
        currentToolHeader
    }

    // MARK: - 18.3 Window

    /// Returns a summary string for the given category.
    public func categorySummary(_ category: ToolCategory) -> String {
        BrowserSidebarHelpers.categorySummary(category, tools: toolItems)
    }

    /// Returns the number of available (installed) tools.
    public func availableToolCount() -> Int {
        BrowserSidebarHelpers.availableToolCount(in: toolItems)
    }

    /// Returns the window title text.
    public func windowTitleText() -> String {
        windowTitle
    }

    /// Whether the sidebar is currently expanded.
    public func isSidebarExpanded() -> Bool {
        sidebarState.isExpanded
    }

    // MARK: - 18.4 Welcome (Private)

    private func addRecentTool(name: String, displayName: String, sfSymbol: String) {
        service.addRecentTool(name: name, displayName: displayName, sfSymbol: sfSymbol)
        recentTools = service.getRecentTools()
    }
}
