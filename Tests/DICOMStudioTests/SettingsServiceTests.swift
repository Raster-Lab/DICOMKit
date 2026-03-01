// SettingsServiceTests.swift
// DICOMStudioTests
//
// Tests for SettingsService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("SettingsService Tests")
struct SettingsServiceTests {

    @Test("Default values are set correctly")
    func testDefaultValues() {
        let service = SettingsService()

        #expect(service.appearance == .system)
        #expect(service.defaultWindowCenter == 40)
        #expect(service.defaultWindowWidth == 400)
        #expect(service.showWelcomeOnLaunch == true)
        #expect(service.recentFilesLimit == 20)
        #expect(service.anonymizationEnabled == false)
        #expect(service.auditLoggingEnabled == false)
        #expect(service.removePrivateTags == true)
        #expect(service.maxCacheSizeMB == 512)
        #expect(service.maxMemoryUsageMB == 2048)
        #expect(service.thumbnailQuality == 0.7)
        #expect(service.prefetchEnabled == true)
        #expect(service.threadPoolSize == 4)
    }

    @Test("Set and get appearance")
    func testAppearance() {
        let service = SettingsService()
        service.appearance = .dark
        #expect(service.appearance == .dark)

        service.appearance = .light
        #expect(service.appearance == .light)
    }

    @Test("Set and get window center")
    func testWindowCenter() {
        let service = SettingsService()
        service.defaultWindowCenter = 100
        #expect(service.defaultWindowCenter == 100)
    }

    @Test("Set and get window width")
    func testWindowWidth() {
        let service = SettingsService()
        service.defaultWindowWidth = 800
        #expect(service.defaultWindowWidth == 800)
    }

    @Test("Set and get welcome on launch")
    func testWelcomeOnLaunch() {
        let service = SettingsService()
        service.showWelcomeOnLaunch = false
        #expect(service.showWelcomeOnLaunch == false)
    }

    @Test("Set and get recent files limit")
    func testRecentFilesLimit() {
        let service = SettingsService()
        service.recentFilesLimit = 50
        #expect(service.recentFilesLimit == 50)
    }

    @Test("Set and get anonymization enabled")
    func testAnonymizationEnabled() {
        let service = SettingsService()
        service.anonymizationEnabled = true
        #expect(service.anonymizationEnabled == true)
    }

    @Test("Set and get audit logging")
    func testAuditLogging() {
        let service = SettingsService()
        service.auditLoggingEnabled = true
        #expect(service.auditLoggingEnabled == true)
    }

    @Test("Set and get remove private tags")
    func testRemovePrivateTags() {
        let service = SettingsService()
        service.removePrivateTags = false
        #expect(service.removePrivateTags == false)
    }

    @Test("Set and get cache size")
    func testCacheSize() {
        let service = SettingsService()
        service.maxCacheSizeMB = 1024
        #expect(service.maxCacheSizeMB == 1024)
    }

    @Test("Set and get memory usage")
    func testMemoryUsage() {
        let service = SettingsService()
        service.maxMemoryUsageMB = 4096
        #expect(service.maxMemoryUsageMB == 4096)
    }

    @Test("Set and get thumbnail quality")
    func testThumbnailQuality() {
        let service = SettingsService()
        service.thumbnailQuality = 0.5
        #expect(service.thumbnailQuality == 0.5)
    }

    @Test("Set and get prefetch enabled")
    func testPrefetchEnabled() {
        let service = SettingsService()
        service.prefetchEnabled = false
        #expect(service.prefetchEnabled == false)
    }

    @Test("Set and get thread pool size")
    func testThreadPoolSize() {
        let service = SettingsService()
        service.threadPoolSize = 8
        #expect(service.threadPoolSize == 8)
    }

    @Test("Reset all to defaults")
    func testResetAllToDefaults() {
        let service = SettingsService()
        service.appearance = .dark
        service.defaultWindowCenter = 999
        service.anonymizationEnabled = true
        service.maxCacheSizeMB = 2048

        service.resetAllToDefaults()

        #expect(service.appearance == .system)
        #expect(service.defaultWindowCenter == 40)
        #expect(service.anonymizationEnabled == false)
        #expect(service.maxCacheSizeMB == 512)
    }

    @Test("Reset single key to default")
    func testResetSingleKey() {
        let service = SettingsService()
        service.defaultWindowCenter = 999

        service.resetToDefault(for: .defaultWindowCenter)

        #expect(service.defaultWindowCenter == 40)
    }

    @Test("Generic value accessor")
    func testGenericValueAccessor() {
        let service = SettingsService()
        service.setValue(42, for: .defaultWindowCenter)

        let value: Int? = service.value(for: .defaultWindowCenter)
        #expect(value == 42)
    }

    @Test("Generic value accessor returns nil for wrong type")
    func testGenericValueAccessorWrongType() {
        let service = SettingsService()
        let value: String? = service.value(for: .defaultWindowCenter)
        #expect(value == nil)
    }
}
