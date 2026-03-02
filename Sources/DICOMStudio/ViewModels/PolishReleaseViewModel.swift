// PolishReleaseViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Polish, Accessibility & Release (Milestone 15)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class PolishReleaseViewModel {
    private let service: PolishReleaseService

    public var activeTab: PolishReleaseTab = .i18n
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // 15.1 Internationalization
    public var coverageSummaries: [LocalizationCoverageSummary] = []
    public var localizationEntries: [LocalizationEntry] = []
    public var selectedLanguage: LocalizationLanguage = .english

    // 15.2 Accessibility
    public var checkItems: [AccessibilityCheckItem] = []
    public var selectedCheckCategory: AccessibilityCheckCategory? = nil

    // 15.3 Testing
    public var uiTestFlows: [UITestFlowEntry] = []
    public var coverageTargets: [TestCoverageTarget] = []
    public var benchmarks: [PerformanceBenchmark] = []

    // 15.4 Performance
    public var profilingSessions: [ProfilingSessionEntry] = []

    // 15.5 Documentation
    public var documentationEntries: [DocumentationEntry] = []

    // 15.6 Release
    public var releaseChecklist: [ReleaseChecklistItem] = []

    public init(service: PolishReleaseService = PolishReleaseService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        coverageSummaries    = service.getCoverageSummaries()
        localizationEntries  = service.getLocalizationEntries()
        selectedLanguage     = service.getSelectedLanguage()
        checkItems           = service.getCheckItems()
        uiTestFlows          = service.getUITestFlows()
        coverageTargets      = service.getCoverageTargets()
        benchmarks           = service.getBenchmarks()
        profilingSessions    = service.getProfilingSessions()
        documentationEntries = service.getDocumentationEntries()
        releaseChecklist     = service.getReleaseChecklist()
    }

    // MARK: - 15.1 Internationalization

    /// Selects the given language as the active locale preview.
    public func selectLanguage(_ language: LocalizationLanguage) {
        selectedLanguage = language
        service.setSelectedLanguage(language)
    }

    /// Returns coverage summary for the selected language, or nil.
    public var selectedLanguageSummary: LocalizationCoverageSummary? {
        coverageSummaries.first { $0.language == selectedLanguage }
    }

    /// Returns the RTL languages in the current coverage list.
    public var rtlLanguages: [LocalizationLanguage] {
        LocalizationLanguage.allCases.filter { $0.isRTL }
    }

    // MARK: - 15.2 Accessibility

    /// Updates the status of the given accessibility check item.
    public func updateCheckItemStatus(id: UUID, status: AccessibilityCheckStatus) {
        guard let idx = checkItems.firstIndex(where: { $0.id == id }) else { return }
        checkItems[idx].status = status
        service.updateCheckItem(checkItems[idx])
    }

    /// Returns the audit report computed from the current check items.
    public var auditReport: AccessibilityAuditReport {
        A11yHelpers.buildAuditReport(from: checkItems)
    }

    /// Filters check items by category if a filter is set.
    public var filteredCheckItems: [AccessibilityCheckItem] {
        guard let cat = selectedCheckCategory else { return checkItems }
        return checkItems.filter { $0.category == cat }
    }

    // MARK: - 15.3 Testing

    /// Updates the status of the given UI test flow.
    public func updateUITestFlowStatus(id: UUID, status: UITestFlowStatus) {
        guard let idx = uiTestFlows.firstIndex(where: { $0.id == id }) else { return }
        uiTestFlows[idx].status = status
        uiTestFlows[idx].lastRunDate = Date()
        service.updateUITestFlow(uiTestFlows[idx])
    }

    /// Returns true if all UI test flows are passing.
    public var allUITestsPassing: Bool {
        uiTestFlows.allSatisfy { $0.status == .passing }
    }

    /// Returns average coverage percent across all targets.
    public var averageCoveragePercent: Double {
        TestingHelpers.averageCoverage(from: coverageTargets)
    }

    // MARK: - 15.4 Performance

    /// Marks a profiling session as completed with the given findings.
    public func completeProfilingSession(id: UUID, findings: [String]) {
        guard let idx = profilingSessions.firstIndex(where: { $0.id == id }) else { return }
        profilingSessions[idx].status = .completed
        profilingSessions[idx].findings = findings
        service.updateProfilingSession(profilingSessions[idx])
    }

    /// Returns the count of completed profiling sessions.
    public var completedSessionCount: Int {
        profilingSessions.filter { $0.status == .completed }.count
    }

    // MARK: - 15.5 Documentation

    /// Marks the documentation entry with the given id as complete.
    public func markDocumentationComplete(id: UUID) {
        guard let idx = documentationEntries.firstIndex(where: { $0.id == id }) else { return }
        documentationEntries[idx].status = .complete
        documentationEntries[idx].lastUpdatedDate = Date()
        service.updateDocumentationEntry(documentationEntries[idx])
    }

    /// Returns completion percentage across all documentation entries.
    public var documentationCompletionPercent: Double {
        DocumentationHelpers.completionPercent(from: documentationEntries)
    }

    // MARK: - 15.6 Release

    /// Toggles the completion state of a release checklist item.
    public func toggleChecklistItem(id: UUID) {
        guard let idx = releaseChecklist.firstIndex(where: { $0.id == id }) else { return }
        releaseChecklist[idx].isCompleted.toggle()
        service.updateReleaseChecklistItem(releaseChecklist[idx])
    }

    /// Returns the overall release status computed from the current checklist.
    public var overallReleaseStatus: ReleaseStatus {
        ReleaseHelpers.releaseStatus(from: releaseChecklist)
    }

    /// Returns the checklist summary string.
    public var releaseChecklistSummary: String {
        ReleaseHelpers.checklistSummary(from: releaseChecklist)
    }
}
