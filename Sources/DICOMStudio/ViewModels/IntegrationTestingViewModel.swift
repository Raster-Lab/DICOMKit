// IntegrationTestingViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Integration Testing, Accessibility & Polish (Milestone 23)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class IntegrationTestingViewModel {
    private let service: IntegrationTestingService

    // MARK: - Public Observable Properties

    public var selectedTab: IntegrationTestingTab = .e2eTesting
    public var testSuites: [IntegrationTestSuite] = []
    public var unitTestEntries: [UnitTestSuiteEntry] = []
    public var accessibilityAudits: [AccessibilityAuditResult] = []
    public var keyboardShortcuts: [IntegrationKeyboardShortcutEntry] = []
    public var benchmarkResults: [PerformanceBenchmarkResult] = []
    public var profilingSessions: [ProfilingSession] = []
    public var polishChecks: [UIPolishCheckItem] = []
    public var documentationEntries: [IntegrationDocumentationEntry] = []

    // MARK: - Initialization

    public init(service: IntegrationTestingService = IntegrationTestingService()) {
        self.service = service
        loadFromService()
    }

    public func loadFromService() {
        let state = service.getState()
        selectedTab = state.selectedTab
        testSuites = state.testSuites
        unitTestEntries = state.unitTestEntries
        accessibilityAudits = state.accessibilityAudits
        keyboardShortcuts = state.keyboardShortcuts
        benchmarkResults = state.benchmarkResults
        profilingSessions = state.profilingSessions
        polishChecks = state.polishChecks
        documentationEntries = state.documentationEntries
    }

    // MARK: - 23.1 E2E Testing

    public func initializeTestSuites() {
        service.initializeTestSuites()
        testSuites = service.getState().testSuites
    }

    public func updateTestStatus(suiteIndex: Int, testIndex: Int, status: IntegrationTestStatus, errorMessage: String? = nil, duration: Double? = nil) {
        service.updateTestStatus(suiteIndex: suiteIndex, testIndex: testIndex, status: status, errorMessage: errorMessage, duration: duration)
        testSuites = service.getState().testSuites
    }

    public func runAllTests() {
        service.runAllTests()
        testSuites = service.getState().testSuites
    }

    public func resetAllTests() {
        service.resetAllTests()
        testSuites = service.getState().testSuites
    }

    // MARK: - 23.2 Unit Tests

    public func initializeUnitTestEntries() {
        service.initializeUnitTestEntries()
        unitTestEntries = service.getState().unitTestEntries
    }

    public func updateUnitTestEntry(target: UnitTestTarget, testCount: Int, passedCount: Int, coverage: Double) {
        service.updateUnitTestEntry(target: target, testCount: testCount, passedCount: passedCount, coverage: coverage)
        unitTestEntries = service.getState().unitTestEntries
    }

    // MARK: - 23.3 Accessibility

    public func initializeAccessibilityAudits() {
        service.initializeAccessibilityAudits()
        accessibilityAudits = service.getState().accessibilityAudits
    }

    public func initializeKeyboardShortcuts() {
        service.initializeKeyboardShortcuts()
        keyboardShortcuts = service.getState().keyboardShortcuts
    }

    public func updateAccessibilityCheck(auditIndex: Int, checkIndex: Int, status: IntegrationAccessibilityCheckStatus, notes: String? = nil) {
        service.updateAccessibilityCheck(auditIndex: auditIndex, checkIndex: checkIndex, status: status, notes: notes)
        accessibilityAudits = service.getState().accessibilityAudits
    }

    public func verifyKeyboardShortcut(at index: Int) {
        service.verifyKeyboardShortcut(at: index)
        keyboardShortcuts = service.getState().keyboardShortcuts
    }

    // MARK: - 23.4 Performance

    public func initializeBenchmarks() {
        service.initializeBenchmarks()
        benchmarkResults = service.getState().benchmarkResults
    }

    public func updateBenchmark(metric: PerformanceMetricType, measuredValue: Double) {
        service.updateBenchmark(metric: metric, measuredValue: measuredValue)
        benchmarkResults = service.getState().benchmarkResults
    }

    public func initializeProfilingSessions() {
        service.initializeProfilingSessions()
        profilingSessions = service.getState().profilingSessions
    }

    public func completeProfilingSession(instrument: ProfilingInstrument, findings: String? = nil) {
        service.completeProfilingSession(instrument: instrument, findings: findings)
        profilingSessions = service.getState().profilingSessions
    }

    // MARK: - 23.5 UI Polish

    public func initializePolishChecks() {
        service.initializePolishChecks()
        polishChecks = service.getState().polishChecks
    }

    public func verifyPolishCheck(at index: Int, notes: String?) {
        service.verifyPolishCheck(at: index, notes: notes)
        polishChecks = service.getState().polishChecks
    }

    public func resetPolishCheck(at index: Int) {
        service.resetPolishCheck(at: index)
        polishChecks = service.getState().polishChecks
    }

    // MARK: - 23.6 Documentation

    public func initializeDocumentationEntries() {
        service.initializeDocumentationEntries()
        documentationEntries = service.getState().documentationEntries
    }

    public func updateDocumentationStatus(at index: Int, status: DocumentationEntryStatus) {
        service.updateDocumentationStatus(at: index, status: status)
        documentationEntries = service.getState().documentationEntries
    }

    // MARK: - Tab Selection

    public func selectTab(_ tab: IntegrationTestingTab) {
        service.selectTab(tab)
        selectedTab = tab
    }

    // MARK: - Computed Properties (UI Helpers)

    public var e2eTestSummary: String {
        E2ETestHelpers.statusSummary(for: testSuites)
    }

    public var unitTestCoverageSummary: String {
        UnitTestCoverageHelpers.coverageSummary(entries: unitTestEntries)
    }

    public var meetsUnitTestTargets: Bool {
        UnitTestCoverageHelpers.meetsOverallTarget(entries: unitTestEntries)
    }

    public var accessibilityComplianceSummary: String {
        AccessibilityAuditHelpers.overallComplianceScore(audits: accessibilityAudits)
    }

    public var performanceSummary: String {
        PerformanceBenchmarkHelpers.performanceSummary(results: benchmarkResults)
    }

    public var meetsAllPerformanceTargets: Bool {
        PerformanceBenchmarkHelpers.meetsAllTargets(results: benchmarkResults)
    }

    public var polishCompletionSummary: String {
        UIPolishCheckHelpers.polishSummary(checks: polishChecks)
    }

    public var documentationProgressSummary: String {
        DocumentationProgressHelpers.overallProgress(entries: documentationEntries)
    }
}
