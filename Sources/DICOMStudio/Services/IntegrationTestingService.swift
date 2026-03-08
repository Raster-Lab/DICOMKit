// IntegrationTestingService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for Integration Testing, Accessibility & Polish (Milestone 23)

import Foundation

/// Thread-safe service that manages state for the Integration Testing, Accessibility & Polish feature.
public final class IntegrationTestingService: @unchecked Sendable {
    private let lock = NSLock()

    // 23.1 E2E Integration Testing
    private var _testSuites: [IntegrationTestSuite] = []

    // 23.2 Unit & ViewModel Tests
    private var _unitTestEntries: [UnitTestSuiteEntry] = []

    // 23.3 Accessibility Compliance
    private var _accessibilityAudits: [AccessibilityAuditResult] = []
    private var _keyboardShortcuts: [IntegrationKeyboardShortcutEntry] = []

    // 23.4 Performance Optimization
    private var _benchmarkResults: [PerformanceBenchmarkResult] = []
    private var _profilingSessions: [ProfilingSession] = []

    // 23.5 UI Polish & Refinement
    private var _polishChecks: [UIPolishCheckItem] = []

    // 23.6 Documentation & Help
    private var _documentationEntries: [IntegrationDocumentationEntry] = []

    // General
    private var _selectedTab: IntegrationTestingTab = .e2eTesting

    public init() {}

    // MARK: - State Accessors

    /// Returns the current complete `IntegrationTestingState`.
    public func getState() -> IntegrationTestingState {
        lock.withLock {
            IntegrationTestingState(
                selectedTab: _selectedTab,
                testSuites: _testSuites,
                unitTestEntries: _unitTestEntries,
                accessibilityAudits: _accessibilityAudits,
                keyboardShortcuts: _keyboardShortcuts,
                benchmarkResults: _benchmarkResults,
                profilingSessions: _profilingSessions,
                polishChecks: _polishChecks,
                documentationEntries: _documentationEntries
            )
        }
    }

    /// Returns the current E2E test suites.
    public func getTestSuites() -> [IntegrationTestSuite] { lock.withLock { _testSuites } }

    /// Returns the current unit test entries.
    public func getUnitTestEntries() -> [UnitTestSuiteEntry] { lock.withLock { _unitTestEntries } }

    /// Returns the current accessibility audit results.
    public func getAccessibilityAudits() -> [AccessibilityAuditResult] { lock.withLock { _accessibilityAudits } }

    /// Returns the current performance benchmark results.
    public func getBenchmarkResults() -> [PerformanceBenchmarkResult] { lock.withLock { _benchmarkResults } }

    /// Returns the current UI polish check items.
    public func getPolishChecks() -> [UIPolishCheckItem] { lock.withLock { _polishChecks } }

    /// Returns the current documentation entries.
    public func getDocumentationEntries() -> [IntegrationDocumentationEntry] { lock.withLock { _documentationEntries } }

    // MARK: - 23.1 E2E Integration Testing

    /// Populates test suites for all 9 tool categories.
    public func initializeTestSuites() {
        lock.withLock {
            _testSuites = IntegrationTestToolCategory.allCases.map { category in
                IntegrationTestSuite(
                    category: category,
                    testCases: E2ETestHelpers.generateTestCases(for: category)
                )
            }
        }
    }

    /// Updates the status of a specific test case within a suite.
    public func updateTestStatus(suiteIndex: Int, testIndex: Int, status: IntegrationTestStatus, errorMessage: String? = nil, duration: Double? = nil) {
        lock.withLock {
            guard _testSuites.indices.contains(suiteIndex),
                  _testSuites[suiteIndex].testCases.indices.contains(testIndex) else { return }
            _testSuites[suiteIndex].testCases[testIndex].status = status
            _testSuites[suiteIndex].testCases[testIndex].errorMessage = errorMessage
            _testSuites[suiteIndex].testCases[testIndex].durationSeconds = duration
        }
    }

    /// Sets all test cases across all suites to `.running`.
    public func runAllTests() {
        lock.withLock {
            for suiteIndex in _testSuites.indices {
                for testIndex in _testSuites[suiteIndex].testCases.indices {
                    _testSuites[suiteIndex].testCases[testIndex].status = .running
                    _testSuites[suiteIndex].testCases[testIndex].errorMessage = nil
                    _testSuites[suiteIndex].testCases[testIndex].durationSeconds = nil
                }
            }
        }
    }

    /// Resets all test cases across all suites to `.pending`.
    public func resetAllTests() {
        lock.withLock {
            for suiteIndex in _testSuites.indices {
                for testIndex in _testSuites[suiteIndex].testCases.indices {
                    _testSuites[suiteIndex].testCases[testIndex].status = .pending
                    _testSuites[suiteIndex].testCases[testIndex].errorMessage = nil
                    _testSuites[suiteIndex].testCases[testIndex].durationSeconds = nil
                }
            }
        }
    }

    // MARK: - 23.2 Unit & ViewModel Tests

    /// Creates entries for all `UnitTestTarget` values with default (zero) counts.
    public func initializeUnitTestEntries() {
        lock.withLock {
            _unitTestEntries = UnitTestTarget.allCases.map { target in
                UnitTestSuiteEntry(target: target)
            }
        }
    }

    /// Updates a specific unit test entry with new counts and coverage.
    public func updateUnitTestEntry(target: UnitTestTarget, testCount: Int, passedCount: Int, coverage: Double) {
        lock.withLock {
            guard let index = _unitTestEntries.firstIndex(where: { $0.target == target }) else { return }
            _unitTestEntries[index].testCount = testCount
            _unitTestEntries[index].passedCount = passedCount
            _unitTestEntries[index].coveragePercent = coverage
        }
    }

    // MARK: - 23.3 Accessibility Compliance

    /// Creates audits for all 5 accessibility categories.
    public func initializeAccessibilityAudits() {
        let voiceOverItems = AccessibilityAuditHelpers.generateVoiceOverChecks()

        let keyboardItems = [
            IntegrationAccessibilityCheckItem(category: .keyboardNavigation, checkDescription: "All controls reachable via Tab key"),
            IntegrationAccessibilityCheckItem(category: .keyboardNavigation, checkDescription: "Focus ring visible on active element"),
            IntegrationAccessibilityCheckItem(category: .keyboardNavigation, checkDescription: "Escape key dismisses modals and popovers"),
            IntegrationAccessibilityCheckItem(category: .keyboardNavigation, checkDescription: "Arrow keys navigate lists and menus"),
        ]

        let dynamicTypeItems = [
            IntegrationAccessibilityCheckItem(category: .dynamicType, checkDescription: "Text scales with Dynamic Type settings"),
            IntegrationAccessibilityCheckItem(category: .dynamicType, checkDescription: "Layout adapts without truncation at largest size"),
            IntegrationAccessibilityCheckItem(category: .dynamicType, checkDescription: "Minimum touch target size maintained"),
        ]

        let highContrastItems = [
            IntegrationAccessibilityCheckItem(category: .highContrast, checkDescription: "All text meets WCAG AA contrast ratios"),
            IntegrationAccessibilityCheckItem(category: .highContrast, checkDescription: "Icons visible in Increase Contrast mode"),
            IntegrationAccessibilityCheckItem(category: .highContrast, checkDescription: "Status indicators distinguishable without color"),
        ]

        let reduceMotionItems = [
            IntegrationAccessibilityCheckItem(category: .reduceMotion, checkDescription: "Animations disabled when Reduce Motion is on"),
            IntegrationAccessibilityCheckItem(category: .reduceMotion, checkDescription: "Transitions use cross-fade instead of slide"),
            IntegrationAccessibilityCheckItem(category: .reduceMotion, checkDescription: "No auto-playing animations"),
        ]

        lock.withLock {
            _accessibilityAudits = [
                AccessibilityAuditResult(category: .voiceOver, items: voiceOverItems),
                AccessibilityAuditResult(category: .keyboardNavigation, items: keyboardItems),
                AccessibilityAuditResult(category: .dynamicType, items: dynamicTypeItems),
                AccessibilityAuditResult(category: .highContrast, items: highContrastItems),
                AccessibilityAuditResult(category: .reduceMotion, items: reduceMotionItems),
            ]
        }
    }

    /// Initializes keyboard shortcut entries from the predefined set.
    public func initializeKeyboardShortcuts() {
        lock.withLock {
            _keyboardShortcuts = AccessibilityAuditHelpers.generateKeyboardShortcuts()
        }
    }

    /// Updates the status of a specific accessibility check within an audit.
    public func updateAccessibilityCheck(auditIndex: Int, checkIndex: Int, status: IntegrationAccessibilityCheckStatus, notes: String? = nil) {
        lock.withLock {
            guard _accessibilityAudits.indices.contains(auditIndex),
                  _accessibilityAudits[auditIndex].items.indices.contains(checkIndex) else { return }
            _accessibilityAudits[auditIndex].items[checkIndex].status = status
            _accessibilityAudits[auditIndex].items[checkIndex].notes = notes
        }
    }

    /// Marks a keyboard shortcut as verified.
    public func verifyKeyboardShortcut(at index: Int) {
        lock.withLock {
            guard _keyboardShortcuts.indices.contains(index) else { return }
            _keyboardShortcuts[index].isVerified = true
        }
    }

    // MARK: - 23.4 Performance Optimization

    /// Initializes benchmark results with default target values.
    public func initializeBenchmarks() {
        lock.withLock {
            _benchmarkResults = PerformanceBenchmarkHelpers.defaultTargets()
        }
    }

    /// Updates a benchmark with a measured value and checks against the target.
    public func updateBenchmark(metric: PerformanceMetricType, measuredValue: Double) {
        lock.withLock {
            guard let index = _benchmarkResults.firstIndex(where: { $0.metric == metric }) else { return }
            _benchmarkResults[index].measuredValue = measuredValue
            let target = _benchmarkResults[index].targetValue
            switch metric {
            case .sidebarRendering, .terminalOutput:
                _benchmarkResults[index].meetsTarget = measuredValue >= target
            case .launchTime, .parameterFormRendering, .memoryUsage, .fileDropValidation, .commandPreviewUpdate:
                _benchmarkResults[index].meetsTarget = measuredValue <= target
            }
        }
    }

    /// Creates profiling sessions for all instruments.
    public func initializeProfilingSessions() {
        lock.withLock {
            _profilingSessions = ProfilingInstrument.allCases.map { instrument in
                ProfilingSession(instrument: instrument)
            }
        }
    }

    /// Marks a profiling session as complete with optional findings.
    public func completeProfilingSession(instrument: ProfilingInstrument, findings: String? = nil) {
        lock.withLock {
            guard let index = _profilingSessions.firstIndex(where: { $0.instrument == instrument }) else { return }
            _profilingSessions[index].isCompleted = true
            _profilingSessions[index].findings = findings
        }
    }

    // MARK: - 23.5 UI Polish & Refinement

    /// Initializes UI polish checklist items from the predefined set.
    public func initializePolishChecks() {
        lock.withLock {
            _polishChecks = UIPolishCheckHelpers.generatePolishChecklist()
        }
    }

    /// Marks a UI polish check as verified with optional notes.
    public func verifyPolishCheck(at index: Int, notes: String? = nil) {
        lock.withLock {
            guard _polishChecks.indices.contains(index) else { return }
            _polishChecks[index].isVerified = true
            _polishChecks[index].notes = notes
        }
    }

    /// Resets a UI polish check to unverified.
    public func resetPolishCheck(at index: Int) {
        lock.withLock {
            guard _polishChecks.indices.contains(index) else { return }
            _polishChecks[index].isVerified = false
            _polishChecks[index].notes = nil
        }
    }

    // MARK: - 23.6 Documentation & Help

    /// Initializes documentation entries from all three sections.
    public func initializeDocumentationEntries() {
        let inAppHelp = DocumentationProgressHelpers.generateInAppHelpEntries()
        let userGuide = DocumentationProgressHelpers.generateUserGuideEntries()
        let releaseNotes = DocumentationProgressHelpers.generateReleaseNotesEntries()
        lock.withLock {
            _documentationEntries = inAppHelp + userGuide + releaseNotes
        }
    }

    /// Updates the status of a documentation entry.
    public func updateDocumentationStatus(at index: Int, status: DocumentationEntryStatus) {
        lock.withLock {
            guard _documentationEntries.indices.contains(index) else { return }
            _documentationEntries[index].status = status
            _documentationEntries[index].lastUpdated = Date()
        }
    }

    // MARK: - Tab Selection

    /// Selects the given tab.
    public func selectTab(_ tab: IntegrationTestingTab) {
        lock.withLock { _selectedTab = tab }
    }
}
