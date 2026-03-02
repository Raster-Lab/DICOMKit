// MacOSEnhancementsHelpersTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for macOS-Specific Enhancements helpers (Milestone 14)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MacOS Enhancements Helpers Tests")
struct MacOSEnhancementsHelpersTests {

    // MARK: - MultiWindowHelpers

    @Test("windowTitle includes window number and truncated UID")
    func testWindowTitleShortUID() {
        let title = MultiWindowHelpers.windowTitle(for: "1.2.3", index: 0)
        #expect(title.contains("Window 1"))
        #expect(title.contains("1.2.3"))
    }

    @Test("windowTitle truncates long UIDs")
    func testWindowTitleLongUID() {
        let longUID = String(repeating: "1", count: 40)
        let title = MultiWindowHelpers.windowTitle(for: longUID, index: 2)
        #expect(title.contains("Window 3"))
        #expect(title.contains("…"))
    }

    @Test("exposéDescription returns correct string for zero windows")
    func testExposéDescriptionZero() {
        #expect(MultiWindowHelpers.exposéDescription(windowCount: 0) == "No windows open")
    }

    @Test("exposéDescription returns correct string for one window")
    func testExposéDescriptionOne() {
        #expect(MultiWindowHelpers.exposéDescription(windowCount: 1) == "1 window open")
    }

    @Test("exposéDescription returns correct string for multiple windows")
    func testExposéDescriptionMany() {
        let desc = MultiWindowHelpers.exposéDescription(windowCount: 5)
        #expect(desc.contains("5"))
        #expect(desc.contains("windows"))
    }

    @Test("canDragToWindow returns false for same window")
    func testCanDragSameWindow() {
        let ws = WindowState(studyInstanceUID: "u", title: "T", windowIndex: 0)
        #expect(MultiWindowHelpers.canDragToWindow(source: ws, destination: ws) == false)
    }

    @Test("canDragToWindow returns true for different windows")
    func testCanDragDifferentWindows() {
        let ws1 = WindowState(studyInstanceUID: "u1", title: "T1", windowIndex: 0)
        let ws2 = WindowState(studyInstanceUID: "u2", title: "T2", windowIndex: 1)
        #expect(MultiWindowHelpers.canDragToWindow(source: ws1, destination: ws2) == true)
    }

    // MARK: - MenuBarHelpers

    @Test("defaultMenuActions returns non-empty list")
    func testDefaultMenuActionsNonEmpty() {
        let actions = MenuBarHelpers.defaultMenuActions()
        #expect(!actions.isEmpty)
    }

    @Test("defaultMenuActions covers all 6 categories")
    func testDefaultMenuActionsAllCategories() {
        let actions = MenuBarHelpers.defaultMenuActions()
        for category in MenuCategory.allCases {
            let count = actions.filter { $0.category == category }.count
            #expect(count > 0)
        }
    }

    @Test("defaultMenuActions contains file.open action")
    func testDefaultMenuActionsContainsOpen() {
        let actions = MenuBarHelpers.defaultMenuActions()
        #expect(actions.contains { $0.actionIdentifier == "file.open" })
    }

    @Test("actions(for:in:) filters by category correctly")
    func testActionsForCategory() {
        let all = MenuBarHelpers.defaultMenuActions()
        let fileActions = MenuBarHelpers.actions(for: .file, in: all)
        #expect(fileActions.allSatisfy { $0.category == .file })
        #expect(!fileActions.isEmpty)
    }

    @Test("actions(for:in:) returns empty for category with no actions in empty list")
    func testActionsForCategoryEmpty() {
        let result = MenuBarHelpers.actions(for: .tools, in: [])
        #expect(result.isEmpty)
    }

    @Test("defaultMenuActions actionIdentifiers are unique")
    func testDefaultMenuActionsUniqueIdentifiers() {
        let actions = MenuBarHelpers.defaultMenuActions()
        let ids = actions.map { $0.actionIdentifier }
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - KeyboardShortcutsHelpers

    @Test("defaultShortcuts returns non-empty list")
    func testDefaultShortcutsNonEmpty() {
        let shortcuts = KeyboardShortcutsHelpers.defaultShortcuts()
        #expect(!shortcuts.isEmpty)
    }

    @Test("defaultShortcuts contains file.open shortcut")
    func testDefaultShortcutsContainsFileOpen() {
        let shortcuts = KeyboardShortcutsHelpers.defaultShortcuts()
        #expect(shortcuts.contains { $0.actionIdentifier == "file.open" })
    }

    @Test("shortcuts(for:in:) filters by scope correctly")
    func testShortcutsForScope() {
        let all = KeyboardShortcutsHelpers.defaultShortcuts()
        let viewer = KeyboardShortcutsHelpers.shortcuts(for: .viewer, in: all)
        #expect(viewer.allSatisfy { $0.scope == .viewer })
    }

    @Test("shortcut(for:in:) returns correct entry")
    func testShortcutForActionIdentifier() {
        let all = KeyboardShortcutsHelpers.defaultShortcuts()
        let entry = KeyboardShortcutsHelpers.shortcut(for: "file.open", in: all)
        #expect(entry != nil)
        #expect(entry?.shortcut == "⌘O")
    }

    @Test("shortcut(for:in:) returns nil for unknown identifier")
    func testShortcutForUnknownIdentifier() {
        let all = KeyboardShortcutsHelpers.defaultShortcuts()
        let entry = KeyboardShortcutsHelpers.shortcut(for: "nonexistent.action", in: all)
        #expect(entry == nil)
    }

    @Test("defaultShortcuts contains viewer scope entries")
    func testDefaultShortcutsHasViewerScope() {
        let shortcuts = KeyboardShortcutsHelpers.defaultShortcuts()
        let viewerEntries = shortcuts.filter { $0.scope == .viewer }
        #expect(!viewerEntries.isEmpty)
    }

    // MARK: - DockIntegrationHelpers

    @Test("badgeLabel returns empty string for count zero")
    func testBadgeLabelZero() {
        #expect(DockIntegrationHelpers.badgeLabel(for: 0) == "")
    }

    @Test("badgeLabel returns string for positive count")
    func testBadgeLabelPositive() {
        #expect(DockIntegrationHelpers.badgeLabel(for: 7) == "7")
    }

    @Test("badgeAccessibilityLabel returns no-transfers text for zero")
    func testBadgeAccessibilityLabelZero() {
        let label = DockIntegrationHelpers.badgeAccessibilityLabel(for: 0)
        #expect(label.lowercased().contains("no"))
    }

    @Test("badgeAccessibilityLabel returns count and 'transfer' for one")
    func testBadgeAccessibilityLabelOne() {
        let label = DockIntegrationHelpers.badgeAccessibilityLabel(for: 1)
        #expect(label.contains("1"))
        #expect(label.lowercased().contains("transfer"))
    }

    @Test("badgeAccessibilityLabel uses plural for multiple transfers")
    func testBadgeAccessibilityLabelPlural() {
        let label = DockIntegrationHelpers.badgeAccessibilityLabel(for: 3)
        #expect(label.contains("3"))
        #expect(label.lowercased().contains("transfers"))
    }

    // MARK: - AutomationHelpers

    @Test("sampleScriptEntries returns at least 3 entries")
    func testSampleScriptEntriesCount() {
        #expect(AutomationHelpers.sampleScriptEntries().count >= 3)
    }

    @Test("sampleScriptEntries covers different script types")
    func testSampleScriptEntriesTypes() {
        let entries = AutomationHelpers.sampleScriptEntries()
        let types = Set(entries.map { $0.scriptType })
        #expect(types.count > 1)
    }

    @Test("formatScriptType returns displayName")
    func testFormatScriptType() {
        for scriptType in AutomationScriptType.allCases {
            #expect(AutomationHelpers.formatScriptType(scriptType) == scriptType.displayName)
        }
    }

    // MARK: - QuickLookHelpers

    @Test("supportedExtensions returns known extensions")
    func testSupportedExtensions() {
        let exts = QuickLookHelpers.supportedExtensions()
        #expect(exts.contains("dcm"))
        #expect(exts.contains("dicom"))
        #expect(!exts.isEmpty)
    }

    @Test("installInstructions returns non-empty string")
    func testInstallInstructions() {
        #expect(!QuickLookHelpers.installInstructions().isEmpty)
    }

    @Test("statusDescription includes status description text")
    func testStatusDescription() {
        let state = QuickLookState(status: .active, supportedExtensions: ["dcm"], thumbnailCacheCount: 5)
        let desc = QuickLookHelpers.statusDescription(for: state)
        #expect(!desc.isEmpty)
        #expect(desc.contains("5"))
    }

    @Test("statusDescription includes extension list")
    func testStatusDescriptionExtensions() {
        let state = QuickLookState(status: .installed, supportedExtensions: ["dcm", "dicom"], thumbnailCacheCount: 0)
        let desc = QuickLookHelpers.statusDescription(for: state)
        #expect(desc.contains("dcm"))
    }
}
