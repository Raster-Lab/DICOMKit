// PerformanceToolsServiceTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Performance Tools Service Tests")
struct PerformanceToolsServiceTests {

    // MARK: - 13.1 Performance Metrics

    @Test("PerformanceToolsService default metrics are zero")
    func testDefaultMetrics() {
        let service = PerformanceToolsService()
        let m = service.getMetrics()
        #expect(m.parseFullMs == 0)
        #expect(m.cacheHitRate == 0)
    }

    @Test("PerformanceToolsService setMetrics persists metrics")
    func testSetMetrics() {
        let service = PerformanceToolsService()
        var m = PerformanceMetrics()
        m.parseFullMs = 42.5
        service.setMetrics(m)
        #expect(service.getMetrics().parseFullMs == 42.5)
    }

    @Test("PerformanceToolsService default benchmarkResults is empty")
    func testDefaultBenchmarkResults() {
        let service = PerformanceToolsService()
        #expect(service.getBenchmarkResults().isEmpty)
    }

    @Test("PerformanceToolsService addBenchmarkResult appends result")
    func testAddBenchmarkResult() {
        let service = PerformanceToolsService()
        let r = BenchmarkResult(type: .parseFiles)
        service.addBenchmarkResult(r)
        #expect(service.getBenchmarkResults().count == 1)
        #expect(service.getBenchmarkResults().first?.id == r.id)
    }

    @Test("PerformanceToolsService updateBenchmarkResult updates existing result")
    func testUpdateBenchmarkResult() {
        let service = PerformanceToolsService()
        var r = BenchmarkResult(type: .parseFiles, status: .running)
        service.addBenchmarkResult(r)
        r.status = .completed
        r.durationMs = 100
        service.updateBenchmarkResult(r)
        #expect(service.getBenchmarkResults().first?.status == .completed)
        #expect(service.getBenchmarkResults().first?.durationMs == 100)
    }

    @Test("PerformanceToolsService clearBenchmarkResults empties results")
    func testClearBenchmarkResults() {
        let service = PerformanceToolsService()
        service.addBenchmarkResult(BenchmarkResult(type: .parseFiles))
        service.clearBenchmarkResults()
        #expect(service.getBenchmarkResults().isEmpty)
    }

    // MARK: - 13.2 Cache Management

    @Test("PerformanceToolsService default cacheStats exists for all types")
    func testDefaultCacheStatsAllTypes() {
        let service = PerformanceToolsService()
        for ct in CacheType.allCases {
            let stats = service.getCacheStats(for: ct)
            #expect(stats.cacheType == ct)
        }
    }

    @Test("PerformanceToolsService setCacheStats persists stats")
    func testSetCacheStats() {
        let service = PerformanceToolsService()
        var stats = CacheStats(cacheType: .image, currentSizeBytes: 1024 * 1024)
        stats.itemCount = 5
        service.setCacheStats(stats, for: .image)
        #expect(service.getCacheStats(for: .image).currentSizeBytes == 1024 * 1024)
        #expect(service.getCacheStats(for: .image).itemCount == 5)
    }

    @Test("PerformanceToolsService default cacheItems is empty for all types")
    func testDefaultCacheItemsEmpty() {
        let service = PerformanceToolsService()
        for ct in CacheType.allCases {
            #expect(service.getCacheItems(for: ct).isEmpty)
        }
    }

    @Test("PerformanceToolsService setCacheItems persists items")
    func testSetCacheItems() {
        let service = PerformanceToolsService()
        let item = CacheItemInfo(key: "test.dcm", sizeBytes: 512, cacheType: .image)
        service.setCacheItems([item], for: .image)
        #expect(service.getCacheItems(for: .image).count == 1)
        #expect(service.getCacheItems(for: .image).first?.key == "test.dcm")
    }

    @Test("PerformanceToolsService clearCache resets items and stats")
    func testClearCache() {
        let service = PerformanceToolsService()
        let item = CacheItemInfo(key: "test.dcm", sizeBytes: 512, cacheType: .image)
        service.setCacheItems([item], for: .image)
        service.setCacheStats(CacheStats(cacheType: .image, currentSizeBytes: 512, itemCount: 1), for: .image)
        service.clearCache(for: .image)
        #expect(service.getCacheItems(for: .image).isEmpty)
        #expect(service.getCacheStats(for: .image).currentSizeBytes == 0)
        #expect(service.getCacheStats(for: .image).itemCount == 0)
    }

    // MARK: - 13.3 Tag Dictionary

    @Test("PerformanceToolsService default tagEntries is non-empty")
    func testDefaultTagEntries() {
        let service = PerformanceToolsService()
        #expect(!service.getTagEntries().isEmpty)
    }

    @Test("PerformanceToolsService setTagSearchQuery persists query")
    func testSetTagSearchQuery() {
        let service = PerformanceToolsService()
        service.setTagSearchQuery("Patient")
        #expect(service.getTagSearchQuery() == "Patient")
    }

    @Test("PerformanceToolsService setTagGroupFilter persists filter")
    func testSetTagGroupFilter() {
        let service = PerformanceToolsService()
        service.setTagGroupFilter(.patient)
        #expect(service.getTagGroupFilter() == .patient)
    }

    // MARK: - 13.4 UID Lookup

    @Test("PerformanceToolsService default uidEntries is non-empty")
    func testDefaultUIDEntries() {
        let service = PerformanceToolsService()
        #expect(!service.getUIDEntries().isEmpty)
    }

    @Test("PerformanceToolsService setUIDSearchQuery persists query")
    func testSetUIDSearchQuery() {
        let service = PerformanceToolsService()
        service.setUIDSearchQuery("CT")
        #expect(service.getUIDSearchQuery() == "CT")
    }

    @Test("PerformanceToolsService setLastGeneratedUID persists UID")
    func testSetLastGeneratedUID() {
        let service = PerformanceToolsService()
        service.setLastGeneratedUID("2.25.1234567890")
        #expect(service.getLastGeneratedUID() == "2.25.1234567890")
    }

    @Test("PerformanceToolsService setUIDValidationResult persists result")
    func testSetUIDValidationResult() {
        let service = PerformanceToolsService()
        let result = UIDValidationResult(uid: "1.2.3", isValid: true)
        service.setUIDValidationResult(result)
        #expect(service.getUIDValidationResult()?.isValid == true)
    }

    @Test("PerformanceToolsService setUIDValidationResult nil clears result")
    func testSetUIDValidationResultNil() {
        let service = PerformanceToolsService()
        service.setUIDValidationResult(UIDValidationResult(uid: "1.2", isValid: true))
        service.setUIDValidationResult(nil)
        #expect(service.getUIDValidationResult() == nil)
    }

    // MARK: - 13.5 Transfer Syntax Info

    @Test("PerformanceToolsService default transferSyntaxEntries is non-empty")
    func testDefaultTransferSyntaxEntries() {
        let service = PerformanceToolsService()
        #expect(!service.getTransferSyntaxEntries().isEmpty)
    }

    @Test("PerformanceToolsService setSelectedSourceSyntaxUID persists UID")
    func testSetSelectedSourceSyntaxUID() {
        let service = PerformanceToolsService()
        service.setSelectedSourceSyntaxUID("1.2.840.10008.1.2")
        #expect(service.getSelectedSourceSyntaxUID() == "1.2.840.10008.1.2")
    }

    @Test("PerformanceToolsService setSelectedTargetSyntaxUID persists UID")
    func testSetSelectedTargetSyntaxUID() {
        let service = PerformanceToolsService()
        service.setSelectedTargetSyntaxUID("1.2.840.10008.1.2.4.90")
        #expect(service.getSelectedTargetSyntaxUID() == "1.2.840.10008.1.2.4.90")
    }

    // MARK: - 13.6 Conformance Statement

    @Test("PerformanceToolsService default sopClassEntries is non-empty")
    func testDefaultSOPClassEntries() {
        let service = PerformanceToolsService()
        #expect(!service.getSOPClassEntries().isEmpty)
    }

    @Test("PerformanceToolsService default capabilityEntries is non-empty")
    func testDefaultCapabilityEntries() {
        let service = PerformanceToolsService()
        #expect(!service.getCapabilityEntries().isEmpty)
    }

    @Test("PerformanceToolsService default conformanceServiceFilter is dicomNetworking")
    func testDefaultConformanceServiceFilter() {
        let service = PerformanceToolsService()
        #expect(service.getConformanceServiceFilter() == .dicomNetworking)
    }

    @Test("PerformanceToolsService setConformanceServiceFilter persists filter")
    func testSetConformanceServiceFilter() {
        let service = PerformanceToolsService()
        service.setConformanceServiceFilter(.dicomweb)
        #expect(service.getConformanceServiceFilter() == .dicomweb)
    }

    @Test("PerformanceToolsService getAllCacheStats returns stats for all cache types")
    func testGetAllCacheStats() {
        let service = PerformanceToolsService()
        let all = service.getAllCacheStats()
        for ct in CacheType.allCases {
            #expect(all[ct] != nil)
        }
    }
}
