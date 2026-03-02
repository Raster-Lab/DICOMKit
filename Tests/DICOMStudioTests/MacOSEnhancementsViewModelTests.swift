// MacOSEnhancementsViewModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for MacOSEnhancementsViewModel (Milestone 14)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MacOS Enhancements ViewModel Tests")
struct MacOSEnhancementsViewModelTests {

    // MARK: - Initial State

    @Test("default activeTab is multiWindow")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultActiveTab() {
        let vm = MacOSEnhancementsViewModel()
        #expect(vm.activeTab == .multiWindow)
    }

    @Test("isLoading starts false")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIsLoadingStartsFalse() {
        let vm = MacOSEnhancementsViewModel()
        #expect(vm.isLoading == false)
    }

    @Test("errorMessage starts nil")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testErrorMessageStartsNil() {
        let vm = MacOSEnhancementsViewModel()
        #expect(vm.errorMessage == nil)
    }

    @Test("menuActions are populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMenuActionsPopulatedOnInit() {
        let vm = MacOSEnhancementsViewModel()
        #expect(!vm.menuActions.isEmpty)
    }

    @Test("shortcuts are populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testShortcutsPopulatedOnInit() {
        let vm = MacOSEnhancementsViewModel()
        #expect(!vm.shortcuts.isEmpty)
    }

    @Test("automationScripts are populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAutomationScriptsPopulatedOnInit() {
        let vm = MacOSEnhancementsViewModel()
        #expect(!vm.automationScripts.isEmpty)
    }

    // MARK: - 14.1 Multi-Window

    @Test("openWindow adds a window and returns it")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOpenWindowAddsWindow() {
        let vm = MacOSEnhancementsViewModel()
        let ws = vm.openWindow(studyInstanceUID: "1.2.3")
        #expect(vm.openWindows.count == 1)
        #expect(vm.openWindows.first?.id == ws.id)
    }

    @Test("closeWindow removes the window")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCloseWindowRemovesWindow() {
        let vm = MacOSEnhancementsViewModel()
        let ws = vm.openWindow(studyInstanceUID: "1.2.3")
        vm.closeWindow(id: ws.id)
        #expect(vm.openWindows.isEmpty)
    }

    @Test("focusWindow updates lastFocused")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFocusWindowUpdatesTimestamp() {
        let vm = MacOSEnhancementsViewModel()
        let ws = vm.openWindow(studyInstanceUID: "1.2.3")
        let before = ws.lastFocused
        vm.focusWindow(id: ws.id)
        let after = vm.openWindows.first?.lastFocused ?? before
        #expect(after >= before)
    }

    @Test("startDragOperation sets isDragOperationActive and pendingDragOperation")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testStartDragOperation() {
        let vm = MacOSEnhancementsViewModel()
        let op = WindowDragOperation(sourceWindowID: UUID(), frameIndex: 0, sopInstanceUID: "sop")
        vm.startDragOperation(op)
        #expect(vm.isDragOperationActive == true)
        #expect(vm.pendingDragOperation != nil)
    }

    @Test("completeDragOperation clears drag state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCompleteDragOperation() {
        let vm = MacOSEnhancementsViewModel()
        let op = WindowDragOperation(sourceWindowID: UUID(), frameIndex: 0, sopInstanceUID: "sop")
        vm.startDragOperation(op)
        vm.completeDragOperation()
        #expect(vm.isDragOperationActive == false)
        #expect(vm.pendingDragOperation == nil)
    }

    // MARK: - 14.2 Menu Bar

    @Test("filteredMenuActions returns only selected category actions")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredMenuActions() {
        let vm = MacOSEnhancementsViewModel()
        vm.selectedMenuCategory = .edit
        let filtered = vm.filteredMenuActions()
        #expect(filtered.allSatisfy { $0.category == .edit })
    }

    @Test("toggleMenuAction flips isEnabled")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleMenuAction() {
        let vm = MacOSEnhancementsViewModel()
        guard let first = vm.menuActions.first else { return }
        let original = first.isEnabled
        vm.toggleMenuAction(id: first.id)
        let updated = vm.menuActions.first { $0.id == first.id }
        #expect(updated?.isEnabled == !original)
    }

    // MARK: - 14.3 Keyboard Shortcuts

    @Test("updateShortcutQuery filters shortcuts by action name")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateShortcutQueryFilters() {
        let vm = MacOSEnhancementsViewModel()
        vm.updateShortcutQuery("Open File")
        let filtered = vm.filteredShortcuts()
        #expect(filtered.allSatisfy { $0.action.lowercased().contains("open file") })
    }

    @Test("updateScopeFilter filters shortcuts by scope")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateScopeFilter() {
        let vm = MacOSEnhancementsViewModel()
        vm.updateScopeFilter(.viewer)
        let filtered = vm.filteredShortcuts()
        #expect(filtered.allSatisfy { $0.scope == .viewer })
    }

    @Test("updateScopeFilter nil returns all shortcuts")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateScopeFilterNil() {
        let vm = MacOSEnhancementsViewModel()
        vm.updateScopeFilter(.viewer)
        vm.updateScopeFilter(nil)
        let filtered = vm.filteredShortcuts()
        #expect(filtered.count == vm.shortcuts.count)
    }

    @Test("selectShortcut sets selectedShortcutEntry")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectShortcut() {
        let vm = MacOSEnhancementsViewModel()
        let entry = vm.shortcuts.first
        vm.selectShortcut(entry)
        #expect(vm.selectedShortcutEntry?.id == entry?.id)
    }

    @Test("resetShortcutsToDefault restores default count")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetShortcutsToDefault() {
        let vm = MacOSEnhancementsViewModel()
        let defaultCount = KeyboardShortcutsHelpers.defaultShortcuts().count
        vm.shortcuts = []
        vm.resetShortcutsToDefault()
        #expect(vm.shortcuts.count == defaultCount)
    }

    // MARK: - 14.4 Dock Integration

    @Test("updateTransferCount updates dockBadgeState")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateTransferCount() {
        let vm = MacOSEnhancementsViewModel()
        vm.updateTransferCount(4)
        #expect(vm.dockBadgeState.transferCount == 4)
    }

    @Test("toggleBadgeVisibility flips isVisible")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleBadgeVisibility() {
        let vm = MacOSEnhancementsViewModel()
        let initial = vm.dockBadgeState.isVisible
        vm.toggleBadgeVisibility()
        #expect(vm.dockBadgeState.isVisible == !initial)
    }

    // MARK: - 14.5 Automation

    @Test("selectScript sets selectedScriptID")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectScript() {
        let vm = MacOSEnhancementsViewModel()
        guard let first = vm.automationScripts.first else { return }
        vm.selectScript(id: first.id)
        #expect(vm.selectedScriptID == first.id)
    }

    @Test("selectedScript returns matching entry")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedScript() {
        let vm = MacOSEnhancementsViewModel()
        guard let first = vm.automationScripts.first else { return }
        vm.selectScript(id: first.id)
        #expect(vm.selectedScript()?.id == first.id)
    }

    @Test("selectedScript returns nil when no ID selected")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedScriptNil() {
        let vm = MacOSEnhancementsViewModel()
        vm.selectScript(id: nil)
        #expect(vm.selectedScript() == nil)
    }

    // MARK: - 14.6 Quick Look

    @Test("updateQuickLookStatus changes status")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateQuickLookStatus() {
        let vm = MacOSEnhancementsViewModel()
        vm.updateQuickLookStatus(.active)
        #expect(vm.quickLookState.status == .active)
    }

    @Test("incrementThumbnailCache increases count by one")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIncrementThumbnailCache() {
        let vm = MacOSEnhancementsViewModel()
        let before = vm.quickLookState.thumbnailCacheCount
        vm.incrementThumbnailCache()
        #expect(vm.quickLookState.thumbnailCacheCount == before + 1)
    }

    @Test("clearThumbnailCache resets count to zero")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearThumbnailCache() {
        let vm = MacOSEnhancementsViewModel()
        vm.incrementThumbnailCache()
        vm.incrementThumbnailCache()
        vm.clearThumbnailCache()
        #expect(vm.quickLookState.thumbnailCacheCount == 0)
    }
}
