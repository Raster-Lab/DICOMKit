// PolishReleaseServiceTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for PolishReleaseService (Milestone 15)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Polish Release Service Tests")
struct PolishReleaseServiceTests {

    // MARK: - Initial State

    @Test("PolishReleaseService coverage summaries populated on init")
    func testCoverageSummariesOnInit() {
        let service = PolishReleaseService()
        let summaries = service.getCoverageSummaries()
        #expect(!summaries.isEmpty)
        #expect(summaries.count == LocalizationLanguage.allCases.count)
    }

    @Test("PolishReleaseService localization entries populated on init")
    func testLocalizationEntriesOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getLocalizationEntries().isEmpty)
    }

    @Test("PolishReleaseService selectedLanguage defaults to english")
    func testSelectedLanguageDefault() {
        let service = PolishReleaseService()
        #expect(service.getSelectedLanguage() == .english)
    }

    @Test("PolishReleaseService checkItems populated on init")
    func testCheckItemsOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getCheckItems().isEmpty)
    }

    @Test("PolishReleaseService uiTestFlows populated on init")
    func testUITestFlowsOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getUITestFlows().isEmpty)
    }

    @Test("PolishReleaseService coverageTargets populated on init")
    func testCoverageTargetsOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getCoverageTargets().isEmpty)
    }

    @Test("PolishReleaseService benchmarks populated on init")
    func testBenchmarksOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getBenchmarks().isEmpty)
    }

    @Test("PolishReleaseService profilingSessions populated on init")
    func testProfilingSessionsOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getProfilingSessions().isEmpty)
    }

    @Test("PolishReleaseService documentationEntries populated on init")
    func testDocumentationEntriesOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getDocumentationEntries().isEmpty)
    }

    @Test("PolishReleaseService releaseChecklist populated on init")
    func testReleaseChecklistOnInit() {
        let service = PolishReleaseService()
        #expect(!service.getReleaseChecklist().isEmpty)
    }

    // MARK: - 15.1 Internationalization

    @Test("PolishReleaseService setSelectedLanguage persists the language")
    func testSetSelectedLanguage() {
        let service = PolishReleaseService()
        service.setSelectedLanguage(.japanese)
        #expect(service.getSelectedLanguage() == .japanese)
    }

    @Test("PolishReleaseService setCoverageSummaries replaces list")
    func testSetCoverageSummaries() {
        let service = PolishReleaseService()
        let newSummary = LocalizationCoverageSummary(
            language: .french,
            totalStrings: 100,
            translatedStrings: 80,
            status: .partial
        )
        service.setCoverageSummaries([newSummary])
        let stored = service.getCoverageSummaries()
        #expect(stored.count == 1)
        #expect(stored[0].language == .french)
    }

    @Test("PolishReleaseService setLocalizationEntries replaces list")
    func testSetLocalizationEntries() {
        let service = PolishReleaseService()
        let entry = LocalizationEntry(key: "new.key", baseValue: "New Value")
        service.setLocalizationEntries([entry])
        let stored = service.getLocalizationEntries()
        #expect(stored.count == 1)
        #expect(stored[0].key == "new.key")
    }

    // MARK: - 15.2 Accessibility

    @Test("PolishReleaseService updateCheckItem persists status change")
    func testUpdateCheckItemStatus() {
        let service = PolishReleaseService()
        var items = service.getCheckItems()
        guard !items.isEmpty else { return }
        items[0].status = .passed
        service.updateCheckItem(items[0])
        let stored = service.getCheckItems()
        #expect(stored[0].status == .passed)
    }

    @Test("PolishReleaseService setCheckItems replaces list")
    func testSetCheckItems() {
        let service = PolishReleaseService()
        let item = AccessibilityCheckItem(category: .voiceOver, description: "Test")
        service.setCheckItems([item])
        #expect(service.getCheckItems().count == 1)
    }

    @Test("PolishReleaseService updateCheckItem with unknown id is no-op")
    func testUpdateCheckItemUnknownID() {
        let service = PolishReleaseService()
        let original = service.getCheckItems()
        let phantom = AccessibilityCheckItem(id: UUID(), category: .dynamicType, description: "Phantom", status: .passed)
        service.updateCheckItem(phantom)
        // Original list unchanged
        #expect(service.getCheckItems().count == original.count)
    }

    // MARK: - 15.3 Testing

    @Test("PolishReleaseService updateUITestFlow persists status change")
    func testUpdateUITestFlowStatus() {
        let service = PolishReleaseService()
        var flows = service.getUITestFlows()
        guard !flows.isEmpty else { return }
        flows[0].status = .passing
        service.updateUITestFlow(flows[0])
        let stored = service.getUITestFlows()
        #expect(stored[0].status == .passing)
    }

    @Test("PolishReleaseService setCoverageTargets replaces list")
    func testSetCoverageTargets() {
        let service = PolishReleaseService()
        let target = TestCoverageTarget(moduleName: "NewVM", coveragePercent: 98.0, testCount: 10)
        service.setCoverageTargets([target])
        #expect(service.getCoverageTargets().count == 1)
    }

    @Test("PolishReleaseService setBenchmarks replaces list")
    func testSetBenchmarks() {
        let service = PolishReleaseService()
        let bm = PerformanceBenchmark(name: "NewBM", targetDescription: "<1s", isPassing: true)
        service.setBenchmarks([bm])
        #expect(service.getBenchmarks().count == 1)
    }

    // MARK: - 15.4 Performance

    @Test("PolishReleaseService updateProfilingSession persists findings")
    func testUpdateProfilingSession() {
        let service = PolishReleaseService()
        var sessions = service.getProfilingSessions()
        guard !sessions.isEmpty else { return }
        sessions[0].status = .completed
        sessions[0].findings = ["No leaks found"]
        service.updateProfilingSession(sessions[0])
        let stored = service.getProfilingSessions()
        #expect(stored[0].status == .completed)
        #expect(stored[0].findings == ["No leaks found"])
    }

    @Test("PolishReleaseService setProfilingSessions replaces list")
    func testSetProfilingSessions() {
        let service = PolishReleaseService()
        let session = ProfilingSessionEntry(sessionType: .gpu, status: .running)
        service.setProfilingSessions([session])
        #expect(service.getProfilingSessions().count == 1)
    }

    // MARK: - 15.5 Documentation

    @Test("PolishReleaseService updateDocumentationEntry persists status")
    func testUpdateDocumentationEntry() {
        let service = PolishReleaseService()
        var entries = service.getDocumentationEntries()
        guard !entries.isEmpty else { return }
        entries[0].status = .complete
        service.updateDocumentationEntry(entries[0])
        let stored = service.getDocumentationEntries()
        #expect(stored[0].status == .complete)
    }

    @Test("PolishReleaseService setDocumentationEntries replaces list")
    func testSetDocumentationEntries() {
        let service = PolishReleaseService()
        let entry = DocumentationEntry(docType: .troubleshooting, title: "Test Guide")
        service.setDocumentationEntries([entry])
        #expect(service.getDocumentationEntries().count == 1)
    }

    // MARK: - 15.6 Release

    @Test("PolishReleaseService updateReleaseChecklistItem persists completion")
    func testUpdateReleaseChecklistItem() {
        let service = PolishReleaseService()
        var items = service.getReleaseChecklist()
        guard !items.isEmpty else { return }
        items[0].isCompleted = true
        service.updateReleaseChecklistItem(items[0])
        let stored = service.getReleaseChecklist()
        #expect(stored[0].isCompleted == true)
    }

    @Test("PolishReleaseService setReleaseChecklist replaces list")
    func testSetReleaseChecklist() {
        let service = PolishReleaseService()
        let item = ReleaseChecklistItem(category: .releaseNotes, description: "Write notes")
        service.setReleaseChecklist([item])
        #expect(service.getReleaseChecklist().count == 1)
    }

    @Test("PolishReleaseService updateReleaseChecklistItem with unknown id is no-op")
    func testUpdateReleaseChecklistItemUnknownID() {
        let service = PolishReleaseService()
        let original = service.getReleaseChecklist()
        let phantom = ReleaseChecklistItem(id: UUID(), category: .homebrew, description: "Phantom", isCompleted: true)
        service.updateReleaseChecklistItem(phantom)
        #expect(service.getReleaseChecklist().count == original.count)
        #expect(service.getReleaseChecklist().allSatisfy { !$0.isCompleted })
    }
}
