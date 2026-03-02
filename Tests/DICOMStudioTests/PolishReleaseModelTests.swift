// PolishReleaseModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for Polish, Accessibility & Release models (Milestone 15)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Polish Release Model Tests")
struct PolishReleaseModelTests {

    // MARK: - PolishReleaseTab

    @Test("PolishReleaseTab has 6 cases")
    func testTabCaseCount() {
        #expect(PolishReleaseTab.allCases.count == 6)
    }

    @Test("PolishReleaseTab all cases have non-empty display names")
    func testTabDisplayNames() {
        for tab in PolishReleaseTab.allCases {
            #expect(!tab.displayName.isEmpty)
        }
    }

    @Test("PolishReleaseTab all cases have non-empty SF symbols")
    func testTabSFSymbols() {
        for tab in PolishReleaseTab.allCases {
            #expect(!tab.sfSymbol.isEmpty)
        }
    }

    @Test("PolishReleaseTab rawValues are unique")
    func testTabRawValuesUnique() {
        let rawValues = PolishReleaseTab.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == PolishReleaseTab.allCases.count)
    }

    @Test("PolishReleaseTab id equals rawValue")
    func testTabIDEqualsRawValue() {
        for tab in PolishReleaseTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }

    @Test("PolishReleaseTab i18n rawValue is I18N")
    func testTabI18NRawValue() {
        #expect(PolishReleaseTab.i18n.rawValue == "I18N")
    }

    // MARK: - LocalizationLanguage

    @Test("LocalizationLanguage has 10 cases")
    func testLanguageCaseCount() {
        #expect(LocalizationLanguage.allCases.count == 10)
    }

    @Test("LocalizationLanguage all cases have non-empty display names")
    func testLanguageDisplayNames() {
        for lang in LocalizationLanguage.allCases {
            #expect(!lang.displayName.isEmpty)
        }
    }

    @Test("LocalizationLanguage arabic is RTL")
    func testArabicIsRTL() {
        #expect(LocalizationLanguage.arabic.isRTL == true)
    }

    @Test("LocalizationLanguage hebrew is RTL")
    func testHebrewIsRTL() {
        #expect(LocalizationLanguage.hebrew.isRTL == true)
    }

    @Test("LocalizationLanguage english is not RTL")
    func testEnglishIsNotRTL() {
        #expect(LocalizationLanguage.english.isRTL == false)
    }

    @Test("LocalizationLanguage english tier is primary")
    func testEnglishTierIsPrimary() {
        #expect(LocalizationLanguage.english.tier == .primary)
    }

    @Test("LocalizationLanguage spanish tier is highPriority")
    func testSpanishTierIsHighPriority() {
        #expect(LocalizationLanguage.spanish.tier == .highPriority)
    }

    @Test("LocalizationLanguage arabic tier is medicalMarkets")
    func testArabicTierIsMedicalMarkets() {
        #expect(LocalizationLanguage.arabic.tier == .medicalMarkets)
    }

    // MARK: - LocalizationTier

    @Test("LocalizationTier has 3 cases")
    func testLocalizationTierCaseCount() {
        #expect(LocalizationTier.allCases.count == 3)
    }

    @Test("LocalizationTier all cases have non-empty display names")
    func testLocalizationTierDisplayNames() {
        for tier in LocalizationTier.allCases {
            #expect(!tier.displayName.isEmpty)
        }
    }

    // MARK: - LocalizationStatus

    @Test("LocalizationStatus has 4 cases")
    func testLocalizationStatusCaseCount() {
        #expect(LocalizationStatus.allCases.count == 4)
    }

    @Test("LocalizationStatus all cases have non-empty SF symbols")
    func testLocalizationStatusSFSymbols() {
        for status in LocalizationStatus.allCases {
            #expect(!status.sfSymbol.isEmpty)
        }
    }

    // MARK: - LocalizationEntry

    @Test("LocalizationEntry init sets all fields")
    func testLocalizationEntryInit() {
        let entry = LocalizationEntry(
            key: "test.key",
            baseValue: "Test Value",
            translations: ["es": "Valor de prueba"],
            context: "Test context",
            featureArea: "TestArea"
        )
        #expect(entry.key == "test.key")
        #expect(entry.baseValue == "Test Value")
        #expect(entry.translations["es"] == "Valor de prueba")
        #expect(entry.context == "Test context")
        #expect(entry.featureArea == "TestArea")
    }

    @Test("LocalizationEntry default translations is empty")
    func testLocalizationEntryDefaultTranslations() {
        let entry = LocalizationEntry(key: "k", baseValue: "v")
        #expect(entry.translations.isEmpty)
    }

    // MARK: - LocalizationCoverageSummary

    @Test("LocalizationCoverageSummary coveragePercent is correct")
    func testCoverageSummaryPercent() {
        let summary = LocalizationCoverageSummary(
            language: .english,
            totalStrings: 200,
            translatedStrings: 100,
            status: .partial
        )
        #expect(abs(summary.coveragePercent - 50.0) < 0.001)
    }

    @Test("LocalizationCoverageSummary coveragePercent is zero when totalStrings is zero")
    func testCoverageSummaryPercentZeroTotal() {
        let summary = LocalizationCoverageSummary(
            language: .french,
            totalStrings: 0,
            translatedStrings: 0,
            status: .missing
        )
        #expect(summary.coveragePercent == 0)
    }

    @Test("LocalizationCoverageSummary full coverage is 100 percent")
    func testCoverageSummaryFullCoverage() {
        let summary = LocalizationCoverageSummary(
            language: .english,
            totalStrings: 500,
            translatedStrings: 500,
            status: .complete
        )
        #expect(abs(summary.coveragePercent - 100.0) < 0.001)
    }

    // MARK: - LocaleFormatterType

    @Test("LocaleFormatterType has 5 cases")
    func testLocaleFormatterTypeCaseCount() {
        #expect(LocaleFormatterType.allCases.count == 5)
    }

    @Test("LocaleFormatterType all cases have non-empty display names")
    func testLocaleFormatterTypeDisplayNames() {
        for ft in LocaleFormatterType.allCases {
            #expect(!ft.displayName.isEmpty)
        }
    }

    // MARK: - AccessibilityCheckCategory

    @Test("AccessibilityCheckCategory has 7 cases")
    func testCheckCategoryCaseCount() {
        #expect(AccessibilityCheckCategory.allCases.count == 7)
    }

    @Test("AccessibilityCheckCategory all cases have non-empty display names")
    func testCheckCategoryDisplayNames() {
        for cat in AccessibilityCheckCategory.allCases {
            #expect(!cat.displayName.isEmpty)
        }
    }

    @Test("AccessibilityCheckCategory all cases have non-empty SF symbols")
    func testCheckCategorySFSymbols() {
        for cat in AccessibilityCheckCategory.allCases {
            #expect(!cat.sfSymbol.isEmpty)
        }
    }

    // MARK: - AccessibilityCheckStatus

    @Test("AccessibilityCheckStatus has 4 cases")
    func testCheckStatusCaseCount() {
        #expect(AccessibilityCheckStatus.allCases.count == 4)
    }

    @Test("AccessibilityCheckStatus all cases have non-empty SF symbols")
    func testCheckStatusSFSymbols() {
        for status in AccessibilityCheckStatus.allCases {
            #expect(!status.sfSymbol.isEmpty)
        }
    }

    // MARK: - AccessibilityCheckItem

    @Test("AccessibilityCheckItem default status is notTested")
    func testCheckItemDefaultStatus() {
        let item = AccessibilityCheckItem(
            category: .voiceOver,
            description: "All buttons have labels"
        )
        #expect(item.status == .notTested)
    }

    @Test("AccessibilityCheckItem full init round-trips fields")
    func testCheckItemFullInit() {
        let id = UUID()
        let item = AccessibilityCheckItem(
            id: id,
            category: .dynamicType,
            description: "Text scales",
            status: .passed,
            notes: "Verified on macOS 14",
            screenName: "Global"
        )
        #expect(item.id == id)
        #expect(item.category == .dynamicType)
        #expect(item.status == .passed)
        #expect(item.screenName == "Global")
    }

    // MARK: - AccessibilityAuditReport

    @Test("AccessibilityAuditReport passRate is correct")
    func testAuditReportPassRate() {
        let report = AccessibilityAuditReport(
            totalChecks: 10,
            passedChecks: 7,
            failedChecks: 2,
            partialChecks: 1,
            notTestedChecks: 0
        )
        #expect(abs(report.passRate - 70.0) < 0.001)
    }

    @Test("AccessibilityAuditReport passRate is zero when no checks")
    func testAuditReportPassRateZero() {
        let report = AccessibilityAuditReport(
            totalChecks: 0,
            passedChecks: 0,
            failedChecks: 0,
            partialChecks: 0,
            notTestedChecks: 0
        )
        #expect(report.passRate == 0)
    }

    // MARK: - UITestFlowType

    @Test("UITestFlowType has 4 cases")
    func testUITestFlowTypeCaseCount() {
        #expect(UITestFlowType.allCases.count == 4)
    }

    @Test("UITestFlowType all cases have non-empty display names")
    func testUITestFlowTypeDisplayNames() {
        for ft in UITestFlowType.allCases {
            #expect(!ft.displayName.isEmpty)
        }
    }

    @Test("UITestFlowType all cases have non-empty descriptions")
    func testUITestFlowTypeDescriptions() {
        for ft in UITestFlowType.allCases {
            #expect(!ft.description.isEmpty)
        }
    }

    // MARK: - UITestFlowStatus

    @Test("UITestFlowStatus has 4 cases")
    func testUITestFlowStatusCaseCount() {
        #expect(UITestFlowStatus.allCases.count == 4)
    }

    @Test("UITestFlowStatus all cases have non-empty SF symbols")
    func testUITestFlowStatusSFSymbols() {
        for status in UITestFlowStatus.allCases {
            #expect(!status.sfSymbol.isEmpty)
        }
    }

    // MARK: - UITestFlowEntry

    @Test("UITestFlowEntry default status is pending")
    func testUITestFlowEntryDefaultStatus() {
        let entry = UITestFlowEntry(flowType: .importBrowseView)
        #expect(entry.status == .pending)
        #expect(entry.lastRunDate == nil)
        #expect(entry.errorMessage == nil)
    }

    // MARK: - TestCoverageTarget

    @Test("TestCoverageTarget meetsTarget true when coverage >= 95")
    func testCoverageTargetMeetsTarget() {
        let target = TestCoverageTarget(moduleName: "TestVM", coveragePercent: 96.0, testCount: 20)
        #expect(target.meetsTarget == true)
    }

    @Test("TestCoverageTarget meetsTarget false when coverage < 95")
    func testCoverageTargetDoesNotMeetTarget() {
        let target = TestCoverageTarget(moduleName: "TestVM", coveragePercent: 90.0, testCount: 15)
        #expect(target.meetsTarget == false)
    }

    @Test("TestCoverageTarget meetsTarget exactly at 95")
    func testCoverageTargetExactlyAtTarget() {
        let target = TestCoverageTarget(moduleName: "TestVM", coveragePercent: 95.0, testCount: 10)
        #expect(target.meetsTarget == true)
    }

    // MARK: - ProfilerSessionType

    @Test("ProfilerSessionType has 5 cases")
    func testProfilerSessionTypeCaseCount() {
        #expect(ProfilerSessionType.allCases.count == 5)
    }

    @Test("ProfilerSessionType all cases have non-empty display names")
    func testProfilerSessionTypeDisplayNames() {
        for pt in ProfilerSessionType.allCases {
            #expect(!pt.displayName.isEmpty)
        }
    }

    @Test("ProfilerSessionType all cases have non-empty SF symbols")
    func testProfilerSessionTypeSFSymbols() {
        for pt in ProfilerSessionType.allCases {
            #expect(!pt.sfSymbol.isEmpty)
        }
    }

    // MARK: - ProfilingSessionStatus

    @Test("ProfilingSessionStatus has 4 cases")
    func testProfilingSessionStatusCaseCount() {
        #expect(ProfilingSessionStatus.allCases.count == 4)
    }

    @Test("ProfilingSessionStatus all cases have non-empty display names")
    func testProfilingSessionStatusDisplayNames() {
        for status in ProfilingSessionStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    // MARK: - ProfilingSessionEntry

    @Test("ProfilingSessionEntry default status is notStarted")
    func testProfilingSessionEntryDefaults() {
        let entry = ProfilingSessionEntry(sessionType: .memory)
        #expect(entry.status == .notStarted)
        #expect(entry.findings.isEmpty)
        #expect(entry.startDate == nil)
    }

    // MARK: - PerformanceBenchmark

    @Test("PerformanceBenchmark default isPassing is false")
    func testPerformanceBenchmarkDefaultIsPassing() {
        let bm = PerformanceBenchmark(name: "Test", targetDescription: "<2s")
        #expect(bm.isPassing == false)
    }

    @Test("PerformanceBenchmark isPassing true when set")
    func testPerformanceBenchmarkIsPassing() {
        let bm = PerformanceBenchmark(name: "Test", targetDescription: "<2s", isPassing: true)
        #expect(bm.isPassing == true)
    }

    // MARK: - DocPageType

    @Test("DocPageType has 5 cases")
    func testDocPageTypeCaseCount() {
        #expect(DocPageType.allCases.count == 5)
    }

    @Test("DocPageType all cases have non-empty display names")
    func testDocPageTypeDisplayNames() {
        for pt in DocPageType.allCases {
            #expect(!pt.displayName.isEmpty)
        }
    }

    @Test("DocPageType all cases have non-empty SF symbols")
    func testDocPageTypeSFSymbols() {
        for pt in DocPageType.allCases {
            #expect(!pt.sfSymbol.isEmpty)
        }
    }

    // MARK: - DocPageStatus

    @Test("DocPageStatus has 3 cases")
    func testDocPageStatusCaseCount() {
        #expect(DocPageStatus.allCases.count == 3)
    }

    @Test("DocPageStatus all cases have non-empty display names")
    func testDocPageStatusDisplayNames() {
        for status in DocPageStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    // MARK: - DocumentationEntry

    @Test("DocumentationEntry default status is planned")
    func testDocumentationEntryDefaultStatus() {
        let entry = DocumentationEntry(docType: .userGuide, title: "User Guide")
        #expect(entry.status == .planned)
        #expect(entry.wordCount == 0)
        #expect(entry.lastUpdatedDate == nil)
    }

    @Test("DocumentationEntry full init round-trips fields")
    func testDocumentationEntryFullInit() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let entry = DocumentationEntry(
            docType: .developerDocs,
            title: "Dev Guide",
            status: .complete,
            lastUpdatedDate: date,
            wordCount: 4000
        )
        #expect(entry.docType == .developerDocs)
        #expect(entry.status == .complete)
        #expect(entry.wordCount == 4000)
        #expect(entry.lastUpdatedDate == date)
    }

    // MARK: - ReleaseChecklistCategory

    @Test("ReleaseChecklistCategory has 5 cases")
    func testReleaseChecklistCategoryCaseCount() {
        #expect(ReleaseChecklistCategory.allCases.count == 5)
    }

    @Test("ReleaseChecklistCategory all cases have non-empty display names")
    func testReleaseChecklistCategoryDisplayNames() {
        for cat in ReleaseChecklistCategory.allCases {
            #expect(!cat.displayName.isEmpty)
        }
    }

    @Test("ReleaseChecklistCategory all cases have non-empty SF symbols")
    func testReleaseChecklistCategorySFSymbols() {
        for cat in ReleaseChecklistCategory.allCases {
            #expect(!cat.sfSymbol.isEmpty)
        }
    }

    // MARK: - ReleaseChecklistItem

    @Test("ReleaseChecklistItem default isCompleted is false")
    func testReleaseChecklistItemDefaultIsCompleted() {
        let item = ReleaseChecklistItem(category: .appStoreMetadata, description: "Write description")
        #expect(item.isCompleted == false)
    }

    @Test("ReleaseChecklistItem full init round-trips fields")
    func testReleaseChecklistItemFullInit() {
        let id = UUID()
        let item = ReleaseChecklistItem(
            id: id,
            category: .codeSigning,
            description: "Configure certificate",
            isCompleted: true,
            notes: "Done"
        )
        #expect(item.id == id)
        #expect(item.isCompleted == true)
        #expect(item.notes == "Done")
    }

    // MARK: - ReleaseStatus

    @Test("ReleaseStatus has 5 cases")
    func testReleaseStatusCaseCount() {
        #expect(ReleaseStatus.allCases.count == 5)
    }

    @Test("ReleaseStatus all cases have non-empty display names")
    func testReleaseStatusDisplayNames() {
        for status in ReleaseStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    @Test("ReleaseStatus all cases have non-empty SF symbols")
    func testReleaseStatusSFSymbols() {
        for status in ReleaseStatus.allCases {
            #expect(!status.sfSymbol.isEmpty)
        }
    }
}
