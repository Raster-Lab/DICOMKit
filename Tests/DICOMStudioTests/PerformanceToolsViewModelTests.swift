// PerformanceToolsViewModelTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Performance Tools ViewModel Tests")
struct PerformanceToolsViewModelTests {

    // MARK: - Navigation

    @Test("default activeTab is performanceDashboard")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultActiveTab() {
        let vm = PerformanceToolsViewModel()
        #expect(vm.activeTab == .performanceDashboard)
    }

    @Test("isLoading starts false")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testIsLoadingStartsFalse() {
        let vm = PerformanceToolsViewModel()
        #expect(vm.isLoading == false)
    }

    @Test("errorMessage starts nil")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testErrorMessageStartsNil() {
        let vm = PerformanceToolsViewModel()
        #expect(vm.errorMessage == nil)
    }

    // MARK: - 13.1 Performance Dashboard

    @Test("updateMetrics updates metrics property")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateMetrics() {
        let vm = PerformanceToolsViewModel()
        var m = PerformanceMetrics()
        m.renderTimeMs = 15.5
        vm.updateMetrics(m)
        #expect(vm.metrics.renderTimeMs == 15.5)
    }

    @Test("addBenchmarkResult appends to benchmarkResults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAddBenchmarkResult() {
        let vm = PerformanceToolsViewModel()
        let r = BenchmarkResult(type: .parseFiles)
        vm.addBenchmarkResult(r)
        #expect(vm.benchmarkResults.count == 1)
    }

    @Test("updateBenchmarkResult updates existing result in list")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateBenchmarkResult() {
        let vm = PerformanceToolsViewModel()
        var r = BenchmarkResult(type: .parseFiles, status: .running)
        vm.addBenchmarkResult(r)
        r.status = .completed
        r.durationMs = 250
        vm.updateBenchmarkResult(r)
        #expect(vm.benchmarkResults.first?.status == .completed)
        #expect(vm.benchmarkResults.first?.durationMs == 250)
    }

    @Test("clearBenchmarkResults empties benchmarkResults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearBenchmarkResults() {
        let vm = PerformanceToolsViewModel()
        vm.addBenchmarkResult(BenchmarkResult(type: .parseFiles))
        vm.clearBenchmarkResults()
        #expect(vm.benchmarkResults.isEmpty)
        #expect(vm.benchmarkExportCSV.isEmpty)
    }

    @Test("exportBenchmarksToCSV sets benchmarkExportCSV")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testExportBenchmarksToCSV() {
        let vm = PerformanceToolsViewModel()
        vm.addBenchmarkResult(BenchmarkResult(type: .renderFrames, durationMs: 200, iterations: 100, status: .completed))
        vm.exportBenchmarksToCSV()
        #expect(!vm.benchmarkExportCSV.isEmpty)
        #expect(vm.benchmarkExportCSV.contains("Benchmark"))
    }

    @Test("startBenchmark adds a completed result")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testStartBenchmark() {
        let vm = PerformanceToolsViewModel()
        vm.startBenchmark(type: .parseFiles)
        #expect(vm.benchmarkResults.count == 1)
        #expect(vm.benchmarkResults.first?.status == .completed)
        #expect(vm.isRunningBenchmark == false)
    }

    @Test("startBenchmark windowLevel produces 1000 iterations")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testStartBenchmarkWindowLevel() {
        let vm = PerformanceToolsViewModel()
        vm.startBenchmark(type: .windowLevel)
        #expect(vm.benchmarkResults.first?.iterations == 1000)
    }

    // MARK: - 13.2 Cache Management

    @Test("default cacheStats has entry for all cache types")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultCacheStatsAllTypes() {
        let vm = PerformanceToolsViewModel()
        for ct in CacheType.allCases {
            #expect(vm.cacheStats[ct] != nil)
        }
    }

    @Test("updateCacheStats updates cacheStats for type")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateCacheStats() {
        let vm = PerformanceToolsViewModel()
        let stats = CacheStats(cacheType: .thumbnail, currentSizeBytes: 2048, itemCount: 10)
        vm.updateCacheStats(stats, for: .thumbnail)
        #expect(vm.cacheStats[.thumbnail]?.currentSizeBytes == 2048)
    }

    @Test("clearCache resets items and stats for type")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearCache() {
        let vm = PerformanceToolsViewModel()
        let item = CacheItemInfo(key: "test", sizeBytes: 100, cacheType: .image)
        vm.setCacheItems([item], for: .image)
        vm.clearCache(for: .image)
        #expect(vm.cacheItems[.image]?.isEmpty ?? true)
        #expect(vm.cacheStats[.image]?.currentSizeBytes == 0)
    }

    @Test("clearAllCaches clears all cache types")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearAllCaches() {
        let vm = PerformanceToolsViewModel()
        for ct in CacheType.allCases {
            let item = CacheItemInfo(key: "test", sizeBytes: 100, cacheType: ct)
            vm.setCacheItems([item], for: ct)
        }
        vm.clearAllCaches()
        for ct in CacheType.allCases {
            #expect(vm.cacheItems[ct]?.isEmpty ?? true)
        }
    }

    @Test("currentCacheStats returns stats for selectedCacheType")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCurrentCacheStats() {
        let vm = PerformanceToolsViewModel()
        vm.selectedCacheType = .thumbnail
        let stats = CacheStats(cacheType: .thumbnail, currentSizeBytes: 999)
        vm.updateCacheStats(stats, for: .thumbnail)
        #expect(vm.currentCacheStats.currentSizeBytes == 999)
    }

    @Test("currentCacheItems returns LRU-sorted items for selectedCacheType")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCurrentCacheItems() {
        let vm = PerformanceToolsViewModel()
        vm.selectedCacheType = .image
        let now = Date()
        let old = CacheItemInfo(key: "old", sizeBytes: 100, lastAccessedAt: now.addingTimeInterval(-120), cacheType: .image)
        let recent = CacheItemInfo(key: "recent", sizeBytes: 100, lastAccessedAt: now, cacheType: .image)
        vm.setCacheItems([recent, old], for: .image)
        #expect(vm.currentCacheItems.first?.key == "old")
    }

    // MARK: - 13.3 Tag Dictionary

    @Test("tagEntries starts with sample entries")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTagEntriesStartsNonEmpty() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.tagEntries.isEmpty)
    }

    @Test("setTagSearchQuery updates tagSearchQuery")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetTagSearchQuery() {
        let vm = PerformanceToolsViewModel()
        vm.setTagSearchQuery("Patient")
        #expect(vm.tagSearchQuery == "Patient")
    }

    @Test("setTagGroupFilter updates tagGroupFilter")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetTagGroupFilter() {
        let vm = PerformanceToolsViewModel()
        vm.setTagGroupFilter(.image)
        #expect(vm.tagGroupFilter == .image)
    }

    @Test("filteredTagEntries returns all entries when query is empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredTagEntriesEmptyQuery() {
        let vm = PerformanceToolsViewModel()
        #expect(vm.filteredTagEntries.count == vm.tagEntries.count)
    }

    @Test("filteredTagEntries filters by search query")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredTagEntriesSearchQuery() {
        let vm = PerformanceToolsViewModel()
        vm.setTagSearchQuery("Patient")
        let results = vm.filteredTagEntries
        #expect(results.allSatisfy {
            $0.tag.lowercased().contains("patient")
            || $0.name.lowercased().contains("patient")
            || $0.keyword.lowercased().contains("patient")
        })
    }

    // MARK: - 13.4 UID Lookup

    @Test("uidEntries starts with sample entries")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUIDEntriesStartsNonEmpty() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.uidEntries.isEmpty)
    }

    @Test("setUIDSearchQuery updates uidSearchQuery")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetUIDSearchQuery() {
        let vm = PerformanceToolsViewModel()
        vm.setUIDSearchQuery("CT")
        #expect(vm.uidSearchQuery == "CT")
    }

    @Test("generateUID sets non-empty lastGeneratedUID starting with 2.25.")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testGenerateUID() {
        let vm = PerformanceToolsViewModel()
        vm.generateUID()
        #expect(!vm.lastGeneratedUID.isEmpty)
        #expect(vm.lastGeneratedUID.hasPrefix("2.25."))
    }

    @Test("validateUID sets uidValidationResult for valid UID")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testValidateUIDValid() {
        let vm = PerformanceToolsViewModel()
        vm.validateUID("1.2.840.10008.1.2.1")
        #expect(vm.uidValidationResult?.isValid == true)
    }

    @Test("validateUID sets uidValidationResult for invalid UID")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testValidateUIDInvalid() {
        let vm = PerformanceToolsViewModel()
        vm.validateUID("")
        #expect(vm.uidValidationResult?.isValid == false)
    }

    @Test("filteredUIDEntries returns all when uidSearchQuery is empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredUIDEntriesEmpty() {
        let vm = PerformanceToolsViewModel()
        #expect(vm.filteredUIDEntries.count == vm.uidEntries.count)
    }

    @Test("filteredUIDEntries filters by search query")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredUIDEntriesFilter() {
        let vm = PerformanceToolsViewModel()
        vm.setUIDSearchQuery("CT Image")
        let results = vm.filteredUIDEntries
        #expect(!results.isEmpty)
        #expect(results.allSatisfy {
            $0.uid.lowercased().contains("ct image")
            || $0.name.lowercased().contains("ct image")
            || $0.category.displayName.lowercased().contains("ct image")
        })
    }

    // MARK: - 13.5 Transfer Syntax Info

    @Test("transferSyntaxEntries starts non-empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTransferSyntaxEntriesNonEmpty() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.transferSyntaxEntries.isEmpty)
    }

    @Test("setSelectedSourceSyntaxUID updates selectedSourceSyntaxUID")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetSelectedSourceSyntaxUID() {
        let vm = PerformanceToolsViewModel()
        vm.setSelectedSourceSyntaxUID("1.2.840.10008.1.2")
        #expect(vm.selectedSourceSyntaxUID == "1.2.840.10008.1.2")
    }

    @Test("setSelectedTargetSyntaxUID updates selectedTargetSyntaxUID")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetSelectedTargetSyntaxUID() {
        let vm = PerformanceToolsViewModel()
        vm.setSelectedTargetSyntaxUID("1.2.840.10008.1.2.4.90")
        #expect(vm.selectedTargetSyntaxUID == "1.2.840.10008.1.2.4.90")
    }

    @Test("compatibilityNote returns no conversion needed when same UIDs")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCompatibilityNoteSame() {
        let vm = PerformanceToolsViewModel()
        vm.setSelectedSourceSyntaxUID("1.2.840.10008.1.2.1")
        vm.setSelectedTargetSyntaxUID("1.2.840.10008.1.2.1")
        #expect(vm.compatibilityNote.contains("No conversion needed"))
    }

    // MARK: - 13.6 Conformance Statement

    @Test("sopClassEntries starts non-empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSOPClassEntriesNonEmpty() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.sopClassEntries.isEmpty)
    }

    @Test("capabilityEntries starts non-empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCapabilityEntriesNonEmpty() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.capabilityEntries.isEmpty)
    }

    @Test("conformanceServiceFilter default is dicomNetworking")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testConformanceServiceFilterDefault() {
        let vm = PerformanceToolsViewModel()
        #expect(vm.conformanceServiceFilter == .dicomNetworking)
    }

    @Test("setConformanceServiceFilter updates filter and service")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetConformanceServiceFilter() {
        let vm = PerformanceToolsViewModel()
        vm.setConformanceServiceFilter(.dicomweb)
        #expect(vm.conformanceServiceFilter == .dicomweb)
    }

    @Test("filteredCapabilityEntries returns only entries matching filter")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredCapabilityEntries() {
        let vm = PerformanceToolsViewModel()
        vm.setConformanceServiceFilter(.dicomweb)
        let filtered = vm.filteredCapabilityEntries
        #expect(filtered.allSatisfy { $0.serviceCategory == .dicomweb })
    }

    @Test("dicomkitVersion returns non-empty string")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDICOMKitVersion() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.dicomkitVersion.isEmpty)
    }

    @Test("dicomStandardVersion returns non-empty string")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDICOMStandardVersion() {
        let vm = PerformanceToolsViewModel()
        #expect(!vm.dicomStandardVersion.isEmpty)
    }
}
