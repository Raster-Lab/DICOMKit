// PolishReleaseViewModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for PolishReleaseViewModel (Milestone 15)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Polish Release ViewModel Tests")
struct PolishReleaseViewModelTests {

    // MARK: - Initial State

    @Test("default activeTab is i18n")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultActiveTab() {
        let vm = PolishReleaseViewModel()
        #expect(vm.activeTab == .i18n)
    }

    @Test("isLoading starts false")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIsLoadingStartsFalse() {
        let vm = PolishReleaseViewModel()
        #expect(vm.isLoading == false)
    }

    @Test("errorMessage starts nil")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testErrorMessageStartsNil() {
        let vm = PolishReleaseViewModel()
        #expect(vm.errorMessage == nil)
    }

    @Test("coverageSummaries populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCoverageSummariesPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.coverageSummaries.isEmpty)
    }

    @Test("localizationEntries populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLocalizationEntriesPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.localizationEntries.isEmpty)
    }

    @Test("checkItems populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCheckItemsPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.checkItems.isEmpty)
    }

    @Test("uiTestFlows populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUITestFlowsPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.uiTestFlows.isEmpty)
    }

    @Test("profilingSessions populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testProfilingSessionsPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.profilingSessions.isEmpty)
    }

    @Test("documentationEntries populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDocumentationEntriesPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.documentationEntries.isEmpty)
    }

    @Test("releaseChecklist populated on init")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testReleaseChecklistPopulatedOnInit() {
        let vm = PolishReleaseViewModel()
        #expect(!vm.releaseChecklist.isEmpty)
    }

    // MARK: - 15.1 Internationalization

    @Test("selectLanguage updates selectedLanguage")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectLanguage() {
        let vm = PolishReleaseViewModel()
        vm.selectLanguage(.german)
        #expect(vm.selectedLanguage == .german)
    }

    @Test("selectedLanguageSummary returns correct summary")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedLanguageSummary() {
        let vm = PolishReleaseViewModel()
        vm.selectLanguage(.english)
        let summary = vm.selectedLanguageSummary
        #expect(summary != nil)
        #expect(summary?.language == .english)
    }

    @Test("rtlLanguages contains arabic and hebrew")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRTLLanguages() {
        let vm = PolishReleaseViewModel()
        let rtl = vm.rtlLanguages
        #expect(rtl.contains(.arabic))
        #expect(rtl.contains(.hebrew))
        #expect(!rtl.contains(.english))
    }

    @Test("selectLanguage persists to service")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectLanguagePersistsToService() {
        let service = PolishReleaseService()
        let vm = PolishReleaseViewModel(service: service)
        vm.selectLanguage(.korean)
        #expect(service.getSelectedLanguage() == .korean)
    }

    // MARK: - 15.2 Accessibility

    @Test("updateCheckItemStatus changes status")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateCheckItemStatus() {
        let vm = PolishReleaseViewModel()
        guard let firstItem = vm.checkItems.first else { return }
        vm.updateCheckItemStatus(id: firstItem.id, status: .passed)
        let updated = vm.checkItems.first { $0.id == firstItem.id }
        #expect(updated?.status == .passed)
    }

    @Test("updateCheckItemStatus with unknown id is no-op")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateCheckItemStatusUnknownID() {
        let vm = PolishReleaseViewModel()
        let originalCount = vm.checkItems.count
        vm.updateCheckItemStatus(id: UUID(), status: .passed)
        #expect(vm.checkItems.count == originalCount)
    }

    @Test("auditReport reflects current check items")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAuditReport() {
        let vm = PolishReleaseViewModel()
        let report = vm.auditReport
        #expect(report.totalChecks == vm.checkItems.count)
    }

    @Test("filteredCheckItems returns all when no filter set")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredCheckItemsNoFilter() {
        let vm = PolishReleaseViewModel()
        vm.selectedCheckCategory = nil
        #expect(vm.filteredCheckItems.count == vm.checkItems.count)
    }

    @Test("filteredCheckItems filters by category")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredCheckItemsByCategory() {
        let vm = PolishReleaseViewModel()
        vm.selectedCheckCategory = .voiceOver
        let filtered = vm.filteredCheckItems
        #expect(filtered.allSatisfy { $0.category == .voiceOver })
        #expect(!filtered.isEmpty)
    }

    // MARK: - 15.3 Testing

    @Test("updateUITestFlowStatus changes status and sets lastRunDate")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateUITestFlowStatus() {
        let vm = PolishReleaseViewModel()
        guard let firstFlow = vm.uiTestFlows.first else { return }
        vm.updateUITestFlowStatus(id: firstFlow.id, status: .passing)
        let updated = vm.uiTestFlows.first { $0.id == firstFlow.id }
        #expect(updated?.status == .passing)
        #expect(updated?.lastRunDate != nil)
    }

    @Test("allUITestsPassing is false initially")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAllUITestsPassingInitiallyFalse() {
        let vm = PolishReleaseViewModel()
        #expect(vm.allUITestsPassing == false)
    }

    @Test("allUITestsPassing is true when all flows are passing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAllUITestsPassingWhenAllPass() {
        let vm = PolishReleaseViewModel()
        for flow in vm.uiTestFlows {
            vm.updateUITestFlowStatus(id: flow.id, status: .passing)
        }
        #expect(vm.allUITestsPassing == true)
    }

    @Test("averageCoveragePercent is above 95")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAverageCoveragePercent() {
        let vm = PolishReleaseViewModel()
        #expect(vm.averageCoveragePercent > 95.0)
    }

    // MARK: - 15.4 Performance

    @Test("completeProfilingSession marks session as completed with findings")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCompleteProfilingSession() {
        let vm = PolishReleaseViewModel()
        guard let firstSession = vm.profilingSessions.first else { return }
        vm.completeProfilingSession(id: firstSession.id, findings: ["No leaks", "Peak 200MB"])
        let updated = vm.profilingSessions.first { $0.id == firstSession.id }
        #expect(updated?.status == .completed)
        #expect(updated?.findings == ["No leaks", "Peak 200MB"])
    }

    @Test("completedSessionCount increases after completing a session")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCompletedSessionCount() {
        let vm = PolishReleaseViewModel()
        let initial = vm.completedSessionCount
        guard let firstSession = vm.profilingSessions.first else { return }
        vm.completeProfilingSession(id: firstSession.id, findings: [])
        #expect(vm.completedSessionCount == initial + 1)
    }

    @Test("completeProfilingSession with unknown id is no-op")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCompleteProfilingSessionUnknownID() {
        let vm = PolishReleaseViewModel()
        let originalCount = vm.profilingSessions.count
        vm.completeProfilingSession(id: UUID(), findings: [])
        #expect(vm.profilingSessions.count == originalCount)
    }

    // MARK: - 15.5 Documentation

    @Test("markDocumentationComplete marks entry complete with date")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMarkDocumentationComplete() {
        let vm = PolishReleaseViewModel()
        guard let firstEntry = vm.documentationEntries.first else { return }
        vm.markDocumentationComplete(id: firstEntry.id)
        let updated = vm.documentationEntries.first { $0.id == firstEntry.id }
        #expect(updated?.status == .complete)
        #expect(updated?.lastUpdatedDate != nil)
    }

    @Test("documentationCompletionPercent is between 0 and 100")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDocumentationCompletionPercent() {
        let vm = PolishReleaseViewModel()
        let pct = vm.documentationCompletionPercent
        #expect(pct >= 0 && pct <= 100)
    }

    @Test("documentationCompletionPercent increases after marking complete")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDocumentationCompletionPercentIncrease() {
        let vm = PolishReleaseViewModel()
        let initial = vm.documentationCompletionPercent
        let planned = vm.documentationEntries.first { $0.status != .complete }
        guard let entry = planned else { return }
        vm.markDocumentationComplete(id: entry.id)
        #expect(vm.documentationCompletionPercent > initial)
    }

    // MARK: - 15.6 Release

    @Test("toggleChecklistItem toggles isCompleted to true")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleChecklistItemToTrue() {
        let vm = PolishReleaseViewModel()
        guard let firstItem = vm.releaseChecklist.first else { return }
        vm.toggleChecklistItem(id: firstItem.id)
        let updated = vm.releaseChecklist.first { $0.id == firstItem.id }
        #expect(updated?.isCompleted == true)
    }

    @Test("toggleChecklistItem toggles isCompleted back to false")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleChecklistItemBackToFalse() {
        let vm = PolishReleaseViewModel()
        guard let firstItem = vm.releaseChecklist.first else { return }
        vm.toggleChecklistItem(id: firstItem.id)
        vm.toggleChecklistItem(id: firstItem.id)
        let updated = vm.releaseChecklist.first { $0.id == firstItem.id }
        #expect(updated?.isCompleted == false)
    }

    @Test("overallReleaseStatus is notStarted initially")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOverallReleaseStatusInitiallyNotStarted() {
        let vm = PolishReleaseViewModel()
        #expect(vm.overallReleaseStatus == .notStarted)
    }

    @Test("overallReleaseStatus is inProgress after one toggle")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOverallReleaseStatusInProgress() {
        let vm = PolishReleaseViewModel()
        guard let firstItem = vm.releaseChecklist.first else { return }
        vm.toggleChecklistItem(id: firstItem.id)
        #expect(vm.overallReleaseStatus == .inProgress)
    }

    @Test("overallReleaseStatus is readyForReview when all items toggled")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testOverallReleaseStatusReadyForReview() {
        let vm = PolishReleaseViewModel()
        for item in vm.releaseChecklist {
            vm.toggleChecklistItem(id: item.id)
        }
        #expect(vm.overallReleaseStatus == .readyForReview)
    }

    @Test("releaseChecklistSummary format is correct initially")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testReleaseChecklistSummaryInitial() {
        let vm = PolishReleaseViewModel()
        let summary = vm.releaseChecklistSummary
        #expect(summary.contains("0 /"))
        #expect(summary.contains("complete"))
    }

    @Test("releaseChecklistSummary reflects toggles")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testReleaseChecklistSummaryAfterToggle() {
        let vm = PolishReleaseViewModel()
        guard let item = vm.releaseChecklist.first else { return }
        vm.toggleChecklistItem(id: item.id)
        #expect(vm.releaseChecklistSummary.contains("1 /"))
    }

    // MARK: - Navigation

    @Test("polishRelease is a valid NavigationDestination")
    func testPolishReleaseNavigationDestination() {
        #expect(NavigationDestination.allCases.contains(.polishRelease))
    }

    @Test("polishRelease systemImage is non-empty")
    func testPolishReleaseSystemImage() {
        #expect(!NavigationDestination.polishRelease.systemImage.isEmpty)
    }

    @Test("polishRelease accessibilityLabel is non-empty")
    func testPolishReleaseAccessibilityLabel() {
        #expect(!NavigationDestination.polishRelease.accessibilityLabel.isEmpty)
    }

    @Test("NavigationDestination now has 16 cases")
    func testNavigationDestinationCaseCount() {
        #expect(NavigationDestination.allCases.count == 16)
    }
}
