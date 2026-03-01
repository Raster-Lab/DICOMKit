// ImageCacheHelpersTests.swift
// DICOMStudioTests
//
// Tests for ImageCacheHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ImageCacheHelpers Tests")
struct ImageCacheHelpersTests {

    // MARK: - hitRateText

    @Test("Hit rate 100%")
    func testHitRate100() {
        #expect(ImageCacheHelpers.hitRateText(1.0) == "100.0%")
    }

    @Test("Hit rate 0%")
    func testHitRate0() {
        #expect(ImageCacheHelpers.hitRateText(0.0) == "0.0%")
    }

    @Test("Hit rate 95.2%")
    func testHitRate952() {
        #expect(ImageCacheHelpers.hitRateText(0.952) == "95.2%")
    }

    @Test("Hit rate 50.5%")
    func testHitRate505() {
        #expect(ImageCacheHelpers.hitRateText(0.505) == "50.5%")
    }

    // MARK: - memoryUsageText

    @Test("Memory usage zero bytes")
    func testMemoryZero() {
        let text = ImageCacheHelpers.memoryUsageText(0)
        #expect(text.contains("0") || text.contains("Zero"))
    }

    @Test("Memory usage non-zero")
    func testMemoryNonZero() {
        let text = ImageCacheHelpers.memoryUsageText(100 * 1024 * 1024)
        #expect(!text.isEmpty)
    }

    // MARK: - statisticsSummary

    @Test("Statistics summary formatting")
    func testStatisticsSummary() {
        let summary = ImageCacheHelpers.statisticsSummary(
            imageCount: 42,
            memoryBytes: 100 * 1024 * 1024,
            hitRate: 0.95
        )
        #expect(summary.contains("42 images"))
        #expect(summary.contains("95.0% hit rate"))
    }

    @Test("Statistics summary zero values")
    func testStatisticsSummaryZero() {
        let summary = ImageCacheHelpers.statisticsSummary(
            imageCount: 0,
            memoryBytes: 0,
            hitRate: 0.0
        )
        #expect(summary.contains("0 images"))
        #expect(summary.contains("0.0% hit rate"))
    }

    // MARK: - renderTimeText

    @Test("Render time 12.5ms")
    func testRenderTime125ms() {
        #expect(ImageCacheHelpers.renderTimeText(0.0125) == "12.5 ms")
    }

    @Test("Render time 0ms")
    func testRenderTime0ms() {
        #expect(ImageCacheHelpers.renderTimeText(0.0) == "0.0 ms")
    }

    @Test("Render time 1 second")
    func testRenderTime1s() {
        #expect(ImageCacheHelpers.renderTimeText(1.0) == "1000.0 ms")
    }

    // MARK: - hitRateQuality

    @Test("Good hit rate quality")
    func testHitRateQualityGood() {
        #expect(ImageCacheHelpers.hitRateQuality(0.9) == "good")
        #expect(ImageCacheHelpers.hitRateQuality(0.81) == "good")
    }

    @Test("Fair hit rate quality")
    func testHitRateQualityFair() {
        #expect(ImageCacheHelpers.hitRateQuality(0.7) == "fair")
        #expect(ImageCacheHelpers.hitRateQuality(0.51) == "fair")
    }

    @Test("Poor hit rate quality")
    func testHitRateQualityPoor() {
        #expect(ImageCacheHelpers.hitRateQuality(0.3) == "poor")
        #expect(ImageCacheHelpers.hitRateQuality(0.0) == "poor")
    }

    @Test("Hit rate quality at boundaries")
    func testHitRateQualityBoundaries() {
        #expect(ImageCacheHelpers.hitRateQuality(0.8) == "fair") // exactly 0.8 is not > 0.8
        #expect(ImageCacheHelpers.hitRateQuality(0.5) == "poor") // exactly 0.5 is not > 0.5
    }
}
