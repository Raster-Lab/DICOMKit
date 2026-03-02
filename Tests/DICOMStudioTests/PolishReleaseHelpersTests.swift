// PolishReleaseHelpersTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for Polish, Accessibility & Release helpers (Milestone 15)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Polish Release Helpers Tests")
struct PolishReleaseHelpersTests {

    // MARK: - I18nHelpers

    @Test("I18nHelpers defaultCoverageSummaries returns one entry per language")
    func testDefaultCoverageSummariesCount() {
        let summaries = I18nHelpers.defaultCoverageSummaries()
        #expect(summaries.count == LocalizationLanguage.allCases.count)
    }

    @Test("I18nHelpers defaultCoverageSummaries english is complete")
    func testDefaultCoverageSummariesEnglishComplete() {
        let summaries = I18nHelpers.defaultCoverageSummaries()
        let english = summaries.first { $0.language == .english }
        #expect(english != nil)
        #expect(english?.status == .complete)
        #expect(english?.coveragePercent == 100.0)
    }

    @Test("I18nHelpers defaultCoverageSummaries arabic is inProgress")
    func testDefaultCoverageSummariesArabicInProgress() {
        let summaries = I18nHelpers.defaultCoverageSummaries()
        let arabic = summaries.first { $0.language == .arabic }
        #expect(arabic?.status == .inProgress)
    }

    @Test("I18nHelpers sampleLocalizationEntries returns non-empty list")
    func testSampleLocalizationEntriesNonEmpty() {
        let entries = I18nHelpers.sampleLocalizationEntries()
        #expect(!entries.isEmpty)
    }

    @Test("I18nHelpers sampleLocalizationEntries all have non-empty keys")
    func testSampleLocalizationEntriesNonEmptyKeys() {
        let entries = I18nHelpers.sampleLocalizationEntries()
        for entry in entries {
            #expect(!entry.key.isEmpty)
        }
    }

    @Test("I18nHelpers sampleLocalizationEntries all have non-empty base values")
    func testSampleLocalizationEntriesNonEmptyBaseValues() {
        let entries = I18nHelpers.sampleLocalizationEntries()
        for entry in entries {
            #expect(!entry.baseValue.isEmpty)
        }
    }

    @Test("I18nHelpers requiresRTL returns true for arabic")
    func testRequiresRTLArabic() {
        #expect(I18nHelpers.requiresRTL(.arabic) == true)
    }

    @Test("I18nHelpers requiresRTL returns false for english")
    func testRequiresRTLEnglish() {
        #expect(I18nHelpers.requiresRTL(.english) == false)
    }

    @Test("I18nHelpers localeIdentifier returns language rawValue")
    func testLocaleIdentifier() {
        #expect(I18nHelpers.localeIdentifier(for: .english) == "en")
        #expect(I18nHelpers.localeIdentifier(for: .arabic) == "ar")
        #expect(I18nHelpers.localeIdentifier(for: .chineseSimplified) == "zh-Hans")
    }

    @Test("I18nHelpers formatterDescriptions returns non-empty map")
    func testFormatterDescriptions() {
        let descriptions = I18nHelpers.formatterDescriptions()
        #expect(!descriptions.isEmpty)
        #expect(descriptions.count == LocaleFormatterType.allCases.count)
    }

    @Test("I18nHelpers formatterDescriptions all values are non-empty")
    func testFormatterDescriptionsNonEmptyValues() {
        let descriptions = I18nHelpers.formatterDescriptions()
        for (_, desc) in descriptions {
            #expect(!desc.isEmpty)
        }
    }

    @Test("I18nHelpers rtlLayoutDescription returns non-empty string")
    func testRTLLayoutDescription() {
        #expect(!I18nHelpers.rtlLayoutDescription().isEmpty)
    }

    @Test("I18nHelpers languagesRequiringPluralRules returns all languages")
    func testLanguagesRequiringPluralRules() {
        let langs = I18nHelpers.languagesRequiringPluralRules()
        #expect(langs.count == LocalizationLanguage.allCases.count)
    }

    // MARK: - A11yHelpers

    @Test("A11yHelpers defaultCheckItems returns non-empty list")
    func testDefaultCheckItemsNonEmpty() {
        let items = A11yHelpers.defaultCheckItems()
        #expect(!items.isEmpty)
    }

    @Test("A11yHelpers defaultCheckItems covers all categories")
    func testDefaultCheckItemsCoversAllCategories() {
        let items = A11yHelpers.defaultCheckItems()
        for cat in AccessibilityCheckCategory.allCases {
            let count = items.filter { $0.category == cat }.count
            #expect(count > 0)
        }
    }

    @Test("A11yHelpers defaultCheckItems all have notTested status")
    func testDefaultCheckItemsAllNotTested() {
        let items = A11yHelpers.defaultCheckItems()
        for item in items {
            #expect(item.status == .notTested)
        }
    }

    @Test("A11yHelpers buildAuditReport totals match input")
    func testBuildAuditReportTotals() {
        var items = A11yHelpers.defaultCheckItems()
        // Mark first 3 as passed, last 1 as failed
        items[0].status = .passed
        items[1].status = .passed
        items[2].status = .passed
        items[items.count - 1].status = .failed

        let report = A11yHelpers.buildAuditReport(from: items)
        #expect(report.totalChecks == items.count)
        #expect(report.passedChecks == 3)
        #expect(report.failedChecks == 1)
    }

    @Test("A11yHelpers buildAuditReport empty items produces zero report")
    func testBuildAuditReportEmpty() {
        let report = A11yHelpers.buildAuditReport(from: [])
        #expect(report.totalChecks == 0)
        #expect(report.passRate == 0)
    }

    @Test("A11yHelpers wcagContrastGuideline returns non-empty string")
    func testWCAGContrastGuideline() {
        #expect(!A11yHelpers.wcagContrastGuideline().isEmpty)
    }

    @Test("A11yHelpers voiceOverLabel formats correctly")
    func testVoiceOverLabel() {
        let label = A11yHelpers.voiceOverLabel(forModality: "CT", frameNumber: 5, totalFrames: 120)
        #expect(label.contains("CT"))
        #expect(label.contains("5"))
        #expect(label.contains("120"))
    }

    @Test("A11yHelpers windowLevelAccessibilityValue includes center and width")
    func testWindowLevelAccessibilityValue() {
        let value = A11yHelpers.windowLevelAccessibilityValue(windowCenter: 40, windowWidth: 400)
        #expect(value.contains("40"))
        #expect(value.contains("400"))
    }

    @Test("A11yHelpers windowLevelAdjustableActionDescription returns non-empty string")
    func testWindowLevelAdjustableActionDescription() {
        #expect(!A11yHelpers.windowLevelAdjustableActionDescription().isEmpty)
    }

    // MARK: - TestingHelpers

    @Test("TestingHelpers defaultUITestFlows returns one entry per flow type")
    func testDefaultUITestFlowsCount() {
        let flows = TestingHelpers.defaultUITestFlows()
        #expect(flows.count == UITestFlowType.allCases.count)
    }

    @Test("TestingHelpers defaultUITestFlows all start as pending")
    func testDefaultUITestFlowsAllPending() {
        let flows = TestingHelpers.defaultUITestFlows()
        for flow in flows {
            #expect(flow.status == .pending)
        }
    }

    @Test("TestingHelpers sampleCoverageTargets returns non-empty list")
    func testSampleCoverageTargetsNonEmpty() {
        let targets = TestingHelpers.sampleCoverageTargets()
        #expect(!targets.isEmpty)
    }

    @Test("TestingHelpers sampleCoverageTargets all meet 95% target")
    func testSampleCoverageTargetsAllMeetTarget() {
        let targets = TestingHelpers.sampleCoverageTargets()
        for target in targets {
            #expect(target.meetsTarget == true)
        }
    }

    @Test("TestingHelpers passingTargetCount returns correct count")
    func testPassingTargetCount() {
        let targets = TestingHelpers.sampleCoverageTargets()
        let passing = TestingHelpers.passingTargetCount(from: targets)
        #expect(passing == targets.count)
    }

    @Test("TestingHelpers averageCoverage returns value above 95")
    func testAverageCoverage() {
        let targets = TestingHelpers.sampleCoverageTargets()
        let avg = TestingHelpers.averageCoverage(from: targets)
        #expect(avg > 95.0)
    }

    @Test("TestingHelpers averageCoverage returns zero for empty list")
    func testAverageCoverageEmpty() {
        #expect(TestingHelpers.averageCoverage(from: []) == 0)
    }

    @Test("TestingHelpers defaultBenchmarks returns non-empty list")
    func testDefaultBenchmarksNonEmpty() {
        let benchmarks = TestingHelpers.defaultBenchmarks()
        #expect(!benchmarks.isEmpty)
    }

    @Test("TestingHelpers defaultBenchmarks all are passing")
    func testDefaultBenchmarksAllPassing() {
        let benchmarks = TestingHelpers.defaultBenchmarks()
        for bm in benchmarks {
            #expect(bm.isPassing == true)
        }
    }

    @Test("TestingHelpers defaultBenchmarks all have non-empty names")
    func testDefaultBenchmarksNonEmptyNames() {
        let benchmarks = TestingHelpers.defaultBenchmarks()
        for bm in benchmarks {
            #expect(!bm.name.isEmpty)
        }
    }

    // MARK: - PerformanceProfilingHelpers

    @Test("PerformanceProfilingHelpers defaultProfilingSessions returns one per type")
    func testDefaultProfilingSessionsCount() {
        let sessions = PerformanceProfilingHelpers.defaultProfilingSessions()
        #expect(sessions.count == ProfilerSessionType.allCases.count)
    }

    @Test("PerformanceProfilingHelpers defaultProfilingSessions all start as notStarted")
    func testDefaultProfilingSessionsAllNotStarted() {
        let sessions = PerformanceProfilingHelpers.defaultProfilingSessions()
        for session in sessions {
            #expect(session.status == .notStarted)
        }
    }

    @Test("PerformanceProfilingHelpers instrumentsToolName returns non-empty for all types")
    func testInstrumentsToolNameNonEmpty() {
        for sessionType in ProfilerSessionType.allCases {
            let name = PerformanceProfilingHelpers.instrumentsToolName(for: sessionType)
            #expect(!name.isEmpty)
        }
    }

    @Test("PerformanceProfilingHelpers profilingFocus returns non-empty for all types")
    func testProfilingFocusNonEmpty() {
        for sessionType in ProfilerSessionType.allCases {
            let focus = PerformanceProfilingHelpers.profilingFocus(for: sessionType)
            #expect(!focus.isEmpty)
        }
    }

    @Test("PerformanceProfilingHelpers sessionSummary for notStarted includes status")
    func testSessionSummaryNotStarted() {
        let session = ProfilingSessionEntry(sessionType: .memory, status: .notStarted)
        let summary = PerformanceProfilingHelpers.sessionSummary(for: session)
        #expect(!summary.isEmpty)
        #expect(summary.contains("Not Started"))
    }

    @Test("PerformanceProfilingHelpers sessionSummary for completed includes finding count")
    func testSessionSummaryCompleted() {
        let session = ProfilingSessionEntry(
            sessionType: .cpu,
            status: .completed,
            findings: ["No leaks", "Peak CPU 45%"]
        )
        let summary = PerformanceProfilingHelpers.sessionSummary(for: session)
        #expect(summary.contains("2"))
    }

    @Test("PerformanceProfilingHelpers sessionSummary for 1 finding uses singular")
    func testSessionSummarySingularFinding() {
        let session = ProfilingSessionEntry(
            sessionType: .gpu,
            status: .completed,
            findings: ["Good frame times"]
        )
        let summary = PerformanceProfilingHelpers.sessionSummary(for: session)
        #expect(summary.contains("1 finding"))
        #expect(!summary.contains("findings"))
    }

    // MARK: - DocumentationHelpers

    @Test("DocumentationHelpers defaultDocumentationEntries returns non-empty list")
    func testDefaultDocumentationEntriesNonEmpty() {
        let entries = DocumentationHelpers.defaultDocumentationEntries()
        #expect(!entries.isEmpty)
    }

    @Test("DocumentationHelpers defaultDocumentationEntries covers all doc types")
    func testDefaultDocumentationEntriesAllDocTypes() {
        let entries = DocumentationHelpers.defaultDocumentationEntries()
        for docType in DocPageType.allCases {
            #expect(entries.contains { $0.docType == docType })
        }
    }

    @Test("DocumentationHelpers totalWordCount sums correctly")
    func testTotalWordCount() {
        let entries = [
            DocumentationEntry(docType: .userGuide, title: "A", wordCount: 1000),
            DocumentationEntry(docType: .developerDocs, title: "B", wordCount: 2000),
        ]
        #expect(DocumentationHelpers.totalWordCount(from: entries) == 3000)
    }

    @Test("DocumentationHelpers totalWordCount zero for empty list")
    func testTotalWordCountEmpty() {
        #expect(DocumentationHelpers.totalWordCount(from: []) == 0)
    }

    @Test("DocumentationHelpers completedEntries returns only complete entries")
    func testCompletedEntriesFilter() {
        let entries = [
            DocumentationEntry(docType: .userGuide, title: "A", status: .complete),
            DocumentationEntry(docType: .developerDocs, title: "B", status: .inProgress),
            DocumentationEntry(docType: .keyboardRef, title: "C", status: .complete),
        ]
        let completed = DocumentationHelpers.completedEntries(from: entries)
        #expect(completed.count == 2)
    }

    @Test("DocumentationHelpers completionPercent is correct")
    func testCompletionPercent() {
        let entries = [
            DocumentationEntry(docType: .userGuide, title: "A", status: .complete),
            DocumentationEntry(docType: .developerDocs, title: "B", status: .inProgress),
        ]
        let pct = DocumentationHelpers.completionPercent(from: entries)
        #expect(abs(pct - 50.0) < 0.001)
    }

    @Test("DocumentationHelpers completionPercent is zero for empty list")
    func testCompletionPercentEmpty() {
        #expect(DocumentationHelpers.completionPercent(from: []) == 0)
    }

    // MARK: - ReleaseHelpers

    @Test("ReleaseHelpers defaultReleaseChecklist returns non-empty list")
    func testDefaultReleaseChecklistNonEmpty() {
        let items = ReleaseHelpers.defaultReleaseChecklist()
        #expect(!items.isEmpty)
    }

    @Test("ReleaseHelpers defaultReleaseChecklist covers all categories")
    func testDefaultReleaseChecklistAllCategories() {
        let items = ReleaseHelpers.defaultReleaseChecklist()
        for cat in ReleaseChecklistCategory.allCases {
            let count = items.filter { $0.category == cat }.count
            #expect(count > 0)
        }
    }

    @Test("ReleaseHelpers defaultReleaseChecklist all start as not completed")
    func testDefaultReleaseChecklistAllNotCompleted() {
        let items = ReleaseHelpers.defaultReleaseChecklist()
        for item in items {
            #expect(item.isCompleted == false)
        }
    }

    @Test("ReleaseHelpers releaseStatus is notStarted when nothing done")
    func testReleaseStatusNotStarted() {
        let items = ReleaseHelpers.defaultReleaseChecklist()
        #expect(ReleaseHelpers.releaseStatus(from: items) == .notStarted)
    }

    @Test("ReleaseHelpers releaseStatus is inProgress when some done")
    func testReleaseStatusInProgress() {
        var items = ReleaseHelpers.defaultReleaseChecklist()
        items[0].isCompleted = true
        #expect(ReleaseHelpers.releaseStatus(from: items) == .inProgress)
    }

    @Test("ReleaseHelpers releaseStatus is readyForReview when all done")
    func testReleaseStatusReadyForReview() {
        var items = ReleaseHelpers.defaultReleaseChecklist()
        for i in items.indices { items[i].isCompleted = true }
        #expect(ReleaseHelpers.releaseStatus(from: items) == .readyForReview)
    }

    @Test("ReleaseHelpers releaseStatus is notStarted for empty list")
    func testReleaseStatusEmpty() {
        #expect(ReleaseHelpers.releaseStatus(from: []) == .notStarted)
    }

    @Test("ReleaseHelpers completedCount returns correct count for category")
    func testCompletedCountForCategory() {
        var items = ReleaseHelpers.defaultReleaseChecklist()
        let appStoreItems = items.indices.filter { items[$0].category == .appStoreMetadata }
        items[appStoreItems[0]].isCompleted = true
        let count = ReleaseHelpers.completedCount(for: .appStoreMetadata, in: items)
        #expect(count == 1)
    }

    @Test("ReleaseHelpers totalCount returns correct total for category")
    func testTotalCountForCategory() {
        let items = ReleaseHelpers.defaultReleaseChecklist()
        let total = ReleaseHelpers.totalCount(for: .appStoreMetadata, in: items)
        #expect(total > 0)
    }

    @Test("ReleaseHelpers checklistSummary format is correct")
    func testChecklistSummaryFormat() {
        let items = ReleaseHelpers.defaultReleaseChecklist()
        let summary = ReleaseHelpers.checklistSummary(from: items)
        #expect(summary.contains("0 /"))
        #expect(summary.contains("complete"))
    }

    @Test("ReleaseHelpers checklistSummary reflects completions")
    func testChecklistSummaryAfterCompletion() {
        var items = ReleaseHelpers.defaultReleaseChecklist()
        items[0].isCompleted = true
        items[1].isCompleted = true
        let summary = ReleaseHelpers.checklistSummary(from: items)
        #expect(summary.contains("2 /"))
    }
}
