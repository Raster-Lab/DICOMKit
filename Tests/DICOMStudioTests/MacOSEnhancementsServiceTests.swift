// MacOSEnhancementsServiceTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for MacOSEnhancementsService (Milestone 14)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MacOS Enhancements Service Tests")
struct MacOSEnhancementsServiceTests {

    // MARK: - Multi-Window

    @Test("getOpenWindows returns empty list initially")
    func testGetOpenWindowsEmpty() {
        let service = MacOSEnhancementsService()
        #expect(service.getOpenWindows().isEmpty)
    }

    @Test("addWindow appends a window")
    func testAddWindow() {
        let service = MacOSEnhancementsService()
        let ws = WindowState(studyInstanceUID: "1.2.3", title: "T", windowIndex: 0)
        service.addWindow(ws)
        #expect(service.getOpenWindows().count == 1)
    }

    @Test("removeWindow removes the correct window")
    func testRemoveWindow() {
        let service = MacOSEnhancementsService()
        let ws = WindowState(studyInstanceUID: "1.2.3", title: "T", windowIndex: 0)
        service.addWindow(ws)
        service.removeWindow(id: ws.id)
        #expect(service.getOpenWindows().isEmpty)
    }

    @Test("updateWindow updates the matching window")
    func testUpdateWindow() {
        let service = MacOSEnhancementsService()
        var ws = WindowState(studyInstanceUID: "1.2.3", title: "T", windowIndex: 0)
        service.addWindow(ws)
        ws.isFullscreen = true
        service.updateWindow(ws)
        #expect(service.getOpenWindows().first?.isFullscreen == true)
    }

    @Test("setOpenWindows replaces all windows")
    func testSetOpenWindows() {
        let service = MacOSEnhancementsService()
        service.addWindow(WindowState(studyInstanceUID: "a", title: "A", windowIndex: 0))
        let ws2 = WindowState(studyInstanceUID: "b", title: "B", windowIndex: 0)
        service.setOpenWindows([ws2])
        #expect(service.getOpenWindows().count == 1)
        #expect(service.getOpenWindows().first?.studyInstanceUID == "b")
    }

    // MARK: - Menu Bar

    @Test("getMenuActions returns default actions")
    func testGetMenuActionsDefault() {
        let service = MacOSEnhancementsService()
        #expect(!service.getMenuActions().isEmpty)
    }

    @Test("setMenuActions replaces actions")
    func testSetMenuActions() {
        let service = MacOSEnhancementsService()
        let action = MenuActionEntry(category: .file, title: "Test", actionIdentifier: "test.action")
        service.setMenuActions([action])
        #expect(service.getMenuActions().count == 1)
    }

    @Test("updateMenuAction updates matching entry")
    func testUpdateMenuAction() {
        let service = MacOSEnhancementsService()
        var actions = service.getMenuActions()
        guard var first = actions.first else { return }
        let originalEnabled = first.isEnabled
        first.isEnabled = !originalEnabled
        service.updateMenuAction(first)
        let updated = service.getMenuActions().first { $0.id == first.id }
        #expect(updated?.isEnabled == !originalEnabled)
    }

    // MARK: - Keyboard Shortcuts

    @Test("getShortcuts returns default shortcuts")
    func testGetShortcutsDefault() {
        let service = MacOSEnhancementsService()
        #expect(!service.getShortcuts().isEmpty)
    }

    @Test("setShortcuts replaces shortcuts")
    func testSetShortcuts() {
        let service = MacOSEnhancementsService()
        let entry = KeyboardShortcutEntry(scope: .global, shortcut: "⌘X", action: "Cut", actionIdentifier: "edit.cut")
        service.setShortcuts([entry])
        #expect(service.getShortcuts().count == 1)
    }

    @Test("shortcutSearchQuery round-trips")
    func testShortcutSearchQuery() {
        let service = MacOSEnhancementsService()
        service.setShortcutSearchQuery("open")
        #expect(service.getShortcutSearchQuery() == "open")
    }

    @Test("shortcutScopeFilter round-trips")
    func testShortcutScopeFilter() {
        let service = MacOSEnhancementsService()
        service.setShortcutScopeFilter(.viewer)
        #expect(service.getShortcutScopeFilter() == .viewer)
    }

    @Test("shortcutScopeFilter can be reset to nil")
    func testShortcutScopeFilterNil() {
        let service = MacOSEnhancementsService()
        service.setShortcutScopeFilter(.library)
        service.setShortcutScopeFilter(nil)
        #expect(service.getShortcutScopeFilter() == nil)
    }

    // MARK: - Dock Integration

    @Test("getDockBadgeState returns default state")
    func testGetDockBadgeStateDefault() {
        let service = MacOSEnhancementsService()
        let state = service.getDockBadgeState()
        #expect(state.transferCount == 0)
        #expect(state.isVisible == false)
    }

    @Test("setDockBadgeState round-trips")
    func testSetDockBadgeState() {
        let service = MacOSEnhancementsService()
        service.setDockBadgeState(DockBadgeState(transferCount: 5, isVisible: true))
        let state = service.getDockBadgeState()
        #expect(state.transferCount == 5)
        #expect(state.isVisible == true)
    }

    // MARK: - Automation

    @Test("getAutomationScripts returns sample scripts")
    func testGetAutomationScriptsDefault() {
        let service = MacOSEnhancementsService()
        #expect(!service.getAutomationScripts().isEmpty)
    }

    @Test("setSelectedScriptID round-trips")
    func testSetSelectedScriptID() {
        let service = MacOSEnhancementsService()
        let id = UUID()
        service.setSelectedScriptID(id)
        #expect(service.getSelectedScriptID() == id)
    }

    @Test("setSelectedScriptID can be cleared")
    func testClearSelectedScriptID() {
        let service = MacOSEnhancementsService()
        service.setSelectedScriptID(UUID())
        service.setSelectedScriptID(nil)
        #expect(service.getSelectedScriptID() == nil)
    }

    // MARK: - Quick Look

    @Test("getQuickLookState returns notInstalled by default")
    func testGetQuickLookStateDefault() {
        let service = MacOSEnhancementsService()
        #expect(service.getQuickLookState().status == .notInstalled)
    }

    @Test("setQuickLookState round-trips")
    func testSetQuickLookState() {
        let service = MacOSEnhancementsService()
        let state = QuickLookState(status: .active, supportedExtensions: ["dcm"], thumbnailCacheCount: 10)
        service.setQuickLookState(state)
        let fetched = service.getQuickLookState()
        #expect(fetched.status == .active)
        #expect(fetched.thumbnailCacheCount == 10)
    }
}
