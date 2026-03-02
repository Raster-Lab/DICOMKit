// PolishReleaseService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for Polish, Accessibility & Release state (Milestone 15)

import Foundation

/// Thread-safe service that manages state for the Polish, Accessibility & Release feature.
public final class PolishReleaseService: @unchecked Sendable {
    private let lock = NSLock()

    // 15.1 Internationalization
    private var _coverageSummaries: [LocalizationCoverageSummary] = I18nHelpers.defaultCoverageSummaries()
    private var _localizationEntries: [LocalizationEntry] = I18nHelpers.sampleLocalizationEntries()
    private var _selectedLanguage: LocalizationLanguage = .english

    // 15.2 Accessibility
    private var _checkItems: [AccessibilityCheckItem] = A11yHelpers.defaultCheckItems()

    // 15.3 Testing
    private var _uiTestFlows: [UITestFlowEntry] = TestingHelpers.defaultUITestFlows()
    private var _coverageTargets: [TestCoverageTarget] = TestingHelpers.sampleCoverageTargets()
    private var _benchmarks: [PerformanceBenchmark] = TestingHelpers.defaultBenchmarks()

    // 15.4 Performance
    private var _profilingSessions: [ProfilingSessionEntry] = PerformanceProfilingHelpers.defaultProfilingSessions()

    // 15.5 Documentation
    private var _documentationEntries: [DocumentationEntry] = DocumentationHelpers.defaultDocumentationEntries()

    // 15.6 Release
    private var _releaseChecklist: [ReleaseChecklistItem] = ReleaseHelpers.defaultReleaseChecklist()

    public init() {}

    // MARK: - 15.1 Internationalization

    public func getCoverageSummaries() -> [LocalizationCoverageSummary] { lock.withLock { _coverageSummaries } }
    public func setCoverageSummaries(_ summaries: [LocalizationCoverageSummary]) { lock.withLock { _coverageSummaries = summaries } }
    public func getLocalizationEntries() -> [LocalizationEntry] { lock.withLock { _localizationEntries } }
    public func setLocalizationEntries(_ entries: [LocalizationEntry]) { lock.withLock { _localizationEntries = entries } }
    public func getSelectedLanguage() -> LocalizationLanguage { lock.withLock { _selectedLanguage } }
    public func setSelectedLanguage(_ language: LocalizationLanguage) { lock.withLock { _selectedLanguage = language } }

    // MARK: - 15.2 Accessibility

    public func getCheckItems() -> [AccessibilityCheckItem] { lock.withLock { _checkItems } }
    public func setCheckItems(_ items: [AccessibilityCheckItem]) { lock.withLock { _checkItems = items } }
    public func updateCheckItem(_ item: AccessibilityCheckItem) {
        lock.withLock {
            guard let idx = _checkItems.firstIndex(where: { $0.id == item.id }) else { return }
            _checkItems[idx] = item
        }
    }

    // MARK: - 15.3 Testing

    public func getUITestFlows() -> [UITestFlowEntry] { lock.withLock { _uiTestFlows } }
    public func setUITestFlows(_ flows: [UITestFlowEntry]) { lock.withLock { _uiTestFlows = flows } }
    public func updateUITestFlow(_ flow: UITestFlowEntry) {
        lock.withLock {
            guard let idx = _uiTestFlows.firstIndex(where: { $0.id == flow.id }) else { return }
            _uiTestFlows[idx] = flow
        }
    }
    public func getCoverageTargets() -> [TestCoverageTarget] { lock.withLock { _coverageTargets } }
    public func setCoverageTargets(_ targets: [TestCoverageTarget]) { lock.withLock { _coverageTargets = targets } }
    public func getBenchmarks() -> [PerformanceBenchmark] { lock.withLock { _benchmarks } }
    public func setBenchmarks(_ benchmarks: [PerformanceBenchmark]) { lock.withLock { _benchmarks = benchmarks } }

    // MARK: - 15.4 Performance

    public func getProfilingSessions() -> [ProfilingSessionEntry] { lock.withLock { _profilingSessions } }
    public func setProfilingSessions(_ sessions: [ProfilingSessionEntry]) { lock.withLock { _profilingSessions = sessions } }
    public func updateProfilingSession(_ session: ProfilingSessionEntry) {
        lock.withLock {
            guard let idx = _profilingSessions.firstIndex(where: { $0.id == session.id }) else { return }
            _profilingSessions[idx] = session
        }
    }

    // MARK: - 15.5 Documentation

    public func getDocumentationEntries() -> [DocumentationEntry] { lock.withLock { _documentationEntries } }
    public func setDocumentationEntries(_ entries: [DocumentationEntry]) { lock.withLock { _documentationEntries = entries } }
    public func updateDocumentationEntry(_ entry: DocumentationEntry) {
        lock.withLock {
            guard let idx = _documentationEntries.firstIndex(where: { $0.id == entry.id }) else { return }
            _documentationEntries[idx] = entry
        }
    }

    // MARK: - 15.6 Release

    public func getReleaseChecklist() -> [ReleaseChecklistItem] { lock.withLock { _releaseChecklist } }
    public func setReleaseChecklist(_ items: [ReleaseChecklistItem]) { lock.withLock { _releaseChecklist = items } }
    public func updateReleaseChecklistItem(_ item: ReleaseChecklistItem) {
        lock.withLock {
            guard let idx = _releaseChecklist.firstIndex(where: { $0.id == item.id }) else { return }
            _releaseChecklist[idx] = item
        }
    }
}
