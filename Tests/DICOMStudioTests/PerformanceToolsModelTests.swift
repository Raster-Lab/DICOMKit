// PerformanceToolsModelTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Performance Tools Model Tests")
struct PerformanceToolsModelTests {

    // MARK: - PerformanceToolsTab

    @Test("PerformanceToolsTab has 6 cases")
    func testTabCaseCount() {
        #expect(PerformanceToolsTab.allCases.count == 6)
    }

    @Test("PerformanceToolsTab all cases have non-empty display names")
    func testTabDisplayNames() {
        for tab in PerformanceToolsTab.allCases {
            #expect(!tab.displayName.isEmpty)
        }
    }

    @Test("PerformanceToolsTab all cases have non-empty SF symbols")
    func testTabSFSymbols() {
        for tab in PerformanceToolsTab.allCases {
            #expect(!tab.sfSymbol.isEmpty)
        }
    }

    @Test("PerformanceToolsTab rawValues are unique")
    func testTabRawValuesUnique() {
        let rawValues = PerformanceToolsTab.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == PerformanceToolsTab.allCases.count)
    }

    @Test("PerformanceToolsTab performanceDashboard rawValue is PERFORMANCE_DASHBOARD")
    func testTabPerformanceDashboardRawValue() {
        #expect(PerformanceToolsTab.performanceDashboard.rawValue == "PERFORMANCE_DASHBOARD")
    }

    @Test("PerformanceToolsTab conformanceStatement rawValue is CONFORMANCE_STATEMENT")
    func testTabConformanceStatementRawValue() {
        #expect(PerformanceToolsTab.conformanceStatement.rawValue == "CONFORMANCE_STATEMENT")
    }

    // MARK: - BenchmarkType

    @Test("BenchmarkType has 4 cases")
    func testBenchmarkTypeCaseCount() {
        #expect(BenchmarkType.allCases.count == 4)
    }

    @Test("BenchmarkType all cases have non-empty display names")
    func testBenchmarkTypeDisplayNames() {
        for bt in BenchmarkType.allCases {
            #expect(!bt.displayName.isEmpty)
        }
    }

    @Test("BenchmarkType all cases have non-empty SF symbols")
    func testBenchmarkTypeSFSymbols() {
        for bt in BenchmarkType.allCases {
            #expect(!bt.sfSymbol.isEmpty)
        }
    }

    @Test("BenchmarkType all cases have non-empty descriptions")
    func testBenchmarkTypeDescriptions() {
        for bt in BenchmarkType.allCases {
            #expect(!bt.description.isEmpty)
        }
    }

    // MARK: - BenchmarkStatus

    @Test("BenchmarkStatus all cases have non-empty displayLabel")
    func testBenchmarkStatusDisplayLabels() {
        for bs in [BenchmarkStatus.idle, .running, .completed, .failed] {
            #expect(!bs.displayLabel.isEmpty)
        }
    }

    @Test("BenchmarkStatus all cases have non-empty SF symbols")
    func testBenchmarkStatusSFSymbols() {
        for bs in [BenchmarkStatus.idle, .running, .completed, .failed] {
            #expect(!bs.sfSymbol.isEmpty)
        }
    }

    // MARK: - BenchmarkResult

    @Test("BenchmarkResult default status is idle")
    func testBenchmarkResultDefaultStatus() {
        let r = BenchmarkResult(type: .parseFiles)
        #expect(r.status == .idle)
    }

    @Test("BenchmarkResult averageIterationMs returns 0 when iterations is 0")
    func testBenchmarkResultAverageZeroIterations() {
        let r = BenchmarkResult(type: .parseFiles, durationMs: 100, iterations: 0)
        #expect(r.averageIterationMs == 0)
    }

    @Test("BenchmarkResult averageIterationMs computes correctly")
    func testBenchmarkResultAverageMs() {
        let r = BenchmarkResult(type: .parseFiles, durationMs: 200, iterations: 100)
        #expect(r.averageIterationMs == 2.0)
    }

    @Test("BenchmarkResult id is unique per instance")
    func testBenchmarkResultUniqueIDs() {
        let r1 = BenchmarkResult(type: .parseFiles)
        let r2 = BenchmarkResult(type: .parseFiles)
        #expect(r1.id != r2.id)
    }

    // MARK: - PerformanceMetrics

    @Test("PerformanceMetrics defaults to zero values")
    func testPerformanceMetricsDefaults() {
        let m = PerformanceMetrics()
        #expect(m.parseFullMs == 0)
        #expect(m.parseMetadataOnlyMs == 0)
        #expect(m.renderTimeMs == 0)
        #expect(m.cacheHitRate == 0)
        #expect(m.memoryResidentMB == 0)
        #expect(m.memoryVirtualMB == 0)
        #expect(m.memoryMappedFileCount == 0)
    }

    // MARK: - CacheType

    @Test("CacheType has 3 cases")
    func testCacheTypeCaseCount() {
        #expect(CacheType.allCases.count == 3)
    }

    @Test("CacheType all cases have non-empty display names")
    func testCacheTypeDisplayNames() {
        for ct in CacheType.allCases {
            #expect(!ct.displayName.isEmpty)
        }
    }

    @Test("CacheType all cases have non-empty SF symbols")
    func testCacheTypeSFSymbols() {
        for ct in CacheType.allCases {
            #expect(!ct.sfSymbol.isEmpty)
        }
    }

    // MARK: - CacheItemInfo

    @Test("CacheItemInfo ageSeconds is non-negative")
    func testCacheItemInfoAgeSeconds() {
        let item = CacheItemInfo(key: "key", sizeBytes: 1024, cacheType: .image)
        #expect(item.ageSeconds >= 0)
    }

    // MARK: - CacheStats

    @Test("CacheStats fillPercentage returns 0 when maximumSizeBytes is 0")
    func testCacheStatsFillPercentageZeroMax() {
        var stats = CacheStats(cacheType: .image)
        stats.maximumSizeBytes = 0
        #expect(stats.fillPercentage == 0)
    }

    @Test("CacheStats fillPercentage computes correctly")
    func testCacheStatsFillPercentage() {
        let stats = CacheStats(cacheType: .image, currentSizeBytes: 128 * 1024 * 1024, maximumSizeBytes: 256 * 1024 * 1024)
        #expect(stats.fillPercentage == 50.0)
    }

    @Test("CacheStats fillPercentage caps at 100")
    func testCacheStatsFillPercentageCapsAt100() {
        let stats = CacheStats(cacheType: .image, currentSizeBytes: 300 * 1024 * 1024, maximumSizeBytes: 256 * 1024 * 1024)
        #expect(stats.fillPercentage == 100.0)
    }

    // MARK: - TagGroupFilter

    @Test("TagGroupFilter has 7 cases")
    func testTagGroupFilterCaseCount() {
        #expect(TagGroupFilter.allCases.count == 7)
    }

    @Test("TagGroupFilter all cases have non-empty display names")
    func testTagGroupFilterDisplayNames() {
        for f in TagGroupFilter.allCases {
            #expect(!f.displayName.isEmpty)
        }
    }

    // MARK: - DICOMTagEntry

    @Test("DICOMTagEntry initializes correctly")
    func testDICOMTagEntryInit() {
        let entry = DICOMTagEntry(tag: "(0010,0010)", name: "Patient Name", keyword: "PatientName", vr: "PN", vm: "1")
        #expect(entry.tag == "(0010,0010)")
        #expect(entry.name == "Patient Name")
        #expect(entry.vr == "PN")
        #expect(!entry.isRetired)
    }

    // MARK: - UIDCategory

    @Test("UIDCategory has 3 cases")
    func testUIDCategoryCaseCount() {
        #expect(UIDCategory.allCases.count == 3)
    }

    @Test("UIDCategory all cases have non-empty display names")
    func testUIDCategoryDisplayNames() {
        for cat in UIDCategory.allCases {
            #expect(!cat.displayName.isEmpty)
        }
    }

    // MARK: - UIDEntry

    @Test("UIDEntry initializes correctly")
    func testUIDEntryInit() {
        let entry = UIDEntry(uid: "1.2.840.10008.1.2.1", name: "Explicit VR Little Endian", category: .transferSyntax)
        #expect(entry.uid == "1.2.840.10008.1.2.1")
        #expect(entry.category == .transferSyntax)
    }

    // MARK: - UIDValidationResult

    @Test("UIDValidationResult isValid true")
    func testUIDValidationResultValid() {
        let r = UIDValidationResult(uid: "1.2.3", isValid: true)
        #expect(r.isValid)
        #expect(r.errorMessage == nil)
    }

    @Test("UIDValidationResult isValid false has errorMessage")
    func testUIDValidationResultInvalid() {
        let r = UIDValidationResult(uid: "", isValid: false, errorMessage: "UID must not be empty.")
        #expect(!r.isValid)
        #expect(r.errorMessage != nil)
    }

    // MARK: - TSCompressionType

    @Test("TSCompressionType all cases have non-empty display names")
    func testTSCompressionTypeDisplayNames() {
        for ct in TSCompressionType.allCases {
            #expect(!ct.displayName.isEmpty)
        }
    }

    // MARK: - TSByteOrder

    @Test("TSByteOrder all cases have non-empty display names")
    func testTSByteOrderDisplayNames() {
        for bo in TSByteOrder.allCases {
            #expect(!bo.displayName.isEmpty)
        }
    }

    // MARK: - TSVREncoding

    @Test("TSVREncoding all cases have non-empty display names")
    func testTSVREncodingDisplayNames() {
        for vr in TSVREncoding.allCases {
            #expect(!vr.displayName.isEmpty)
        }
    }

    // MARK: - TSSupportStatus

    @Test("TSSupportStatus all cases have non-empty displayLabel")
    func testTSSupportStatusDisplayLabels() {
        for s in TSSupportStatus.allCases {
            #expect(!s.displayLabel.isEmpty)
        }
    }

    @Test("TSSupportStatus all cases have non-empty SF symbols")
    func testTSSupportStatusSFSymbols() {
        for s in TSSupportStatus.allCases {
            #expect(!s.sfSymbol.isEmpty)
        }
    }

    // MARK: - TransferSyntaxInfoEntry

    @Test("TransferSyntaxInfoEntry initializes correctly")
    func testTransferSyntaxInfoEntryInit() {
        let entry = TransferSyntaxInfoEntry(
            uid: "1.2.840.10008.1.2.1",
            name: "Explicit VR Little Endian",
            compressionType: .none,
            byteOrder: .littleEndian,
            vrEncoding: .explicit,
            supportStatus: .supported
        )
        #expect(entry.uid == "1.2.840.10008.1.2.1")
        #expect(entry.compressionType == .none)
        #expect(entry.byteOrder == .littleEndian)
        #expect(entry.vrEncoding == .explicit)
        #expect(entry.supportStatus == .supported)
    }

    // MARK: - SOPClassRole

    @Test("SOPClassRole all cases have non-empty display names")
    func testSOPClassRoleDisplayNames() {
        for r in SOPClassRole.allCases {
            #expect(!r.displayName.isEmpty)
        }
    }

    // MARK: - SOPClassEntry

    @Test("SOPClassEntry initializes with empty supportedTransferSyntaxUIDs by default")
    func testSOPClassEntryDefaultTransferSyntaxes() {
        let entry = SOPClassEntry(uid: "1.2.3", name: "Test", role: .scu)
        #expect(entry.supportedTransferSyntaxUIDs.isEmpty)
    }

    // MARK: - ConformanceServiceCategory

    @Test("ConformanceServiceCategory has 2 cases")
    func testConformanceServiceCategoryCaseCount() {
        #expect(ConformanceServiceCategory.allCases.count == 2)
    }

    @Test("ConformanceServiceCategory all cases have non-empty display names")
    func testConformanceServiceCategoryDisplayNames() {
        for cat in ConformanceServiceCategory.allCases {
            #expect(!cat.displayName.isEmpty)
        }
    }

    // MARK: - ConformanceCapabilityStatus

    @Test("ConformanceCapabilityStatus all cases have non-empty displayLabel")
    func testConformanceCapabilityStatusLabels() {
        for s in [ConformanceCapabilityStatus.supported, .notSupported, .planned] {
            #expect(!s.displayLabel.isEmpty)
        }
    }

    @Test("ConformanceCapabilityStatus all cases have non-empty SF symbols")
    func testConformanceCapabilityStatusSFSymbols() {
        for s in [ConformanceCapabilityStatus.supported, .notSupported, .planned] {
            #expect(!s.sfSymbol.isEmpty)
        }
    }
}
