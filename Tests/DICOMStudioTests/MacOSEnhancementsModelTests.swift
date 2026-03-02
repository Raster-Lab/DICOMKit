// MacOSEnhancementsModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for macOS-Specific Enhancements models (Milestone 14)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MacOS Enhancements Model Tests")
struct MacOSEnhancementsModelTests {

    // MARK: - MacOSEnhancementsTab

    @Test("MacOSEnhancementsTab has 6 cases")
    func testTabCaseCount() {
        #expect(MacOSEnhancementsTab.allCases.count == 6)
    }

    @Test("MacOSEnhancementsTab all cases have non-empty display names")
    func testTabDisplayNames() {
        for tab in MacOSEnhancementsTab.allCases {
            #expect(!tab.displayName.isEmpty)
        }
    }

    @Test("MacOSEnhancementsTab all cases have non-empty SF symbols")
    func testTabSFSymbols() {
        for tab in MacOSEnhancementsTab.allCases {
            #expect(!tab.sfSymbol.isEmpty)
        }
    }

    @Test("MacOSEnhancementsTab rawValues are unique")
    func testTabRawValuesUnique() {
        let rawValues = MacOSEnhancementsTab.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == MacOSEnhancementsTab.allCases.count)
    }

    @Test("MacOSEnhancementsTab id equals rawValue")
    func testTabIDEqualsRawValue() {
        for tab in MacOSEnhancementsTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }

    @Test("MacOSEnhancementsTab multiWindow rawValue is MULTI_WINDOW")
    func testTabMultiWindowRawValue() {
        #expect(MacOSEnhancementsTab.multiWindow.rawValue == "MULTI_WINDOW")
    }

    // MARK: - WindowState

    @Test("WindowState convenience init sets defaults correctly")
    func testWindowStateConvenienceInit() {
        let ws = WindowState(studyInstanceUID: "1.2.3", title: "Test", windowIndex: 0)
        #expect(ws.studyInstanceUID == "1.2.3")
        #expect(ws.title == "Test")
        #expect(ws.windowIndex == 0)
        #expect(ws.isFullscreen == false)
        #expect(ws.isMiniaturized == false)
    }

    @Test("WindowState full init round-trips all fields")
    func testWindowStateFullInit() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let ws = WindowState(id: id, studyInstanceUID: "uid", title: "T", windowIndex: 2,
                             isFullscreen: true, isMiniaturized: true, lastFocused: date)
        #expect(ws.id == id)
        #expect(ws.isFullscreen == true)
        #expect(ws.isMiniaturized == true)
        #expect(ws.lastFocused == date)
    }

    @Test("WindowState is Hashable and two instances with same id hash equally")
    func testWindowStateHashable() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let ws1 = WindowState(id: id, studyInstanceUID: "u", title: "T", windowIndex: 0,
                              isFullscreen: false, isMiniaturized: false, lastFocused: date)
        let ws2 = WindowState(id: id, studyInstanceUID: "u", title: "T", windowIndex: 0,
                              isFullscreen: false, isMiniaturized: false, lastFocused: date)
        #expect(ws1 == ws2)
    }

    // MARK: - WindowDragOperation

    @Test("WindowDragOperation stores fields correctly")
    func testWindowDragOperation() {
        let src = UUID()
        let dst = UUID()
        let op = WindowDragOperation(sourceWindowID: src, destinationWindowID: dst, frameIndex: 5, sopInstanceUID: "sop.1")
        #expect(op.sourceWindowID == src)
        #expect(op.destinationWindowID == dst)
        #expect(op.frameIndex == 5)
        #expect(op.sopInstanceUID == "sop.1")
    }

    @Test("WindowDragOperation destinationWindowID defaults to nil")
    func testWindowDragOperationNilDestination() {
        let op = WindowDragOperation(sourceWindowID: UUID(), frameIndex: 0, sopInstanceUID: "sop")
        #expect(op.destinationWindowID == nil)
    }

    // MARK: - MenuCategory

    @Test("MenuCategory has 6 cases")
    func testMenuCategoryCaseCount() {
        #expect(MenuCategory.allCases.count == 6)
    }

    @Test("MenuCategory all cases have non-empty display names")
    func testMenuCategoryDisplayNames() {
        for cat in MenuCategory.allCases {
            #expect(!cat.displayName.isEmpty)
        }
    }

    // MARK: - MenuActionEntry

    @Test("MenuActionEntry stores fields correctly")
    func testMenuActionEntry() {
        let entry = MenuActionEntry(category: .file, title: "Open", keyboardShortcut: "⌘O",
                                   isEnabled: true, isSeparator: false, actionIdentifier: "file.open")
        #expect(entry.category == .file)
        #expect(entry.title == "Open")
        #expect(entry.keyboardShortcut == "⌘O")
        #expect(entry.isEnabled == true)
        #expect(entry.isSeparator == false)
        #expect(entry.actionIdentifier == "file.open")
    }

    // MARK: - KeyboardShortcutScope

    @Test("KeyboardShortcutScope has 4 cases")
    func testScopeCaseCount() {
        #expect(KeyboardShortcutScope.allCases.count == 4)
    }

    @Test("KeyboardShortcutScope all cases have non-empty display names")
    func testScopeDisplayNames() {
        for scope in KeyboardShortcutScope.allCases {
            #expect(!scope.displayName.isEmpty)
        }
    }

    // MARK: - DockBadgeState

    @Test("DockBadgeState badgeLabel is empty when not visible")
    func testDockBadgeNotVisible() {
        let state = DockBadgeState(transferCount: 5, isVisible: false)
        #expect(state.badgeLabel == "")
    }

    @Test("DockBadgeState badgeLabel is empty when count is zero even if visible")
    func testDockBadgeZeroCount() {
        let state = DockBadgeState(transferCount: 0, isVisible: true)
        #expect(state.badgeLabel == "")
    }

    @Test("DockBadgeState badgeLabel shows count when visible and count > 0")
    func testDockBadgeVisible() {
        let state = DockBadgeState(transferCount: 3, isVisible: true)
        #expect(state.badgeLabel == "3")
    }

    // MARK: - AutomationScriptType

    @Test("AutomationScriptType has 3 cases")
    func testAutomationScriptTypeCaseCount() {
        #expect(AutomationScriptType.allCases.count == 3)
    }

    @Test("AutomationScriptType all cases have non-empty display names and sfSymbols")
    func testAutomationScriptTypeProperties() {
        for t in AutomationScriptType.allCases {
            #expect(!t.displayName.isEmpty)
            #expect(!t.sfSymbol.isEmpty)
        }
    }

    // MARK: - QuickLookPluginStatus

    @Test("QuickLookPluginStatus has 4 cases")
    func testQuickLookStatusCaseCount() {
        #expect(QuickLookPluginStatus.allCases.count == 4)
    }

    @Test("QuickLookPluginStatus all cases have non-empty displayName, sfSymbol, and description")
    func testQuickLookStatusProperties() {
        for s in QuickLookPluginStatus.allCases {
            #expect(!s.displayName.isEmpty)
            #expect(!s.sfSymbol.isEmpty)
            #expect(!s.description.isEmpty)
        }
    }

    // MARK: - QuickLookState

    @Test("QuickLookState stores fields correctly")
    func testQuickLookState() {
        let state = QuickLookState(status: .active, supportedExtensions: ["dcm"], thumbnailCacheCount: 10)
        #expect(state.status == .active)
        #expect(state.supportedExtensions == ["dcm"])
        #expect(state.thumbnailCacheCount == 10)
        #expect(state.lastRefreshDate == nil)
    }
}
