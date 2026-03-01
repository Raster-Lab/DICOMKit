// ViewModelTests.swift
// DICOMStudioTests
//
// Tests for MainViewModel and SettingsViewModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MainViewModel Tests")
struct MainViewModelTests {

    @Test("Default state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultState() {
        let vm = MainViewModel()
        #expect(vm.selectedDestination == .library)
        #expect(vm.isInspectorVisible == false)
        #expect(vm.searchText == "")
        #expect(vm.statusMessage == "Ready")
        #expect(vm.library.studyCount == 0)
    }

    @Test("Navigate to destination")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testNavigate() {
        let vm = MainViewModel()
        vm.navigate(to: .viewer)
        #expect(vm.selectedDestination == .viewer)
    }

    @Test("Toggle inspector")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testToggleInspector() {
        let vm = MainViewModel()
        #expect(vm.isInspectorVisible == false)
        vm.toggleInspector()
        #expect(vm.isInspectorVisible == true)
        vm.toggleInspector()
        #expect(vm.isInspectorVisible == false)
    }

    @Test("Primary destinations exclude settings")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPrimaryDestinations() {
        let vm = MainViewModel()
        #expect(!vm.primaryDestinations.contains(.settings))
    }

    @Test("Filtered destinations with empty search")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredDestinationsEmpty() {
        let vm = MainViewModel()
        vm.searchText = ""
        #expect(vm.filteredDestinations.count == vm.primaryDestinations.count)
    }

    @Test("Filtered destinations with search text")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredDestinationsSearch() {
        let vm = MainViewModel()
        vm.searchText = "View"
        #expect(vm.filteredDestinations.contains(.viewer))
        #expect(!vm.filteredDestinations.contains(.networking))
    }

    @Test("Filtered destinations with no match")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredDestinationsNoMatch() {
        let vm = MainViewModel()
        vm.searchText = "zzzzz"
        #expect(vm.filteredDestinations.isEmpty)
    }

    @Test("Set status message")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetStatus() {
        let vm = MainViewModel()
        vm.setStatus("Loading...")
        #expect(vm.statusMessage == "Loading...")
    }

    @Test("Dependency injection works")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDependencyInjection() {
        let settings = SettingsService()
        settings.defaultWindowCenter = 999
        let vm = MainViewModel(settingsService: settings)
        #expect(vm.settingsService.defaultWindowCenter == 999)
    }

    @Test("Welcome sheet respects settings")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testWelcomeSheet() {
        let settings = SettingsService()
        settings.showWelcomeOnLaunch = false
        let vm = MainViewModel(settingsService: settings)
        #expect(vm.showWelcomeSheet == false)
    }
}

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {

    @Test("Initial values match service")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialValues() {
        let service = SettingsService()
        let vm = SettingsViewModel(settingsService: service)

        #expect(vm.appearance == .system)
        #expect(vm.defaultWindowCenter == 40)
        #expect(vm.defaultWindowWidth == 400)
        #expect(vm.showWelcomeOnLaunch == true)
        #expect(vm.anonymizationEnabled == false)
        #expect(vm.maxCacheSizeMB == 512)
    }

    @Test("Setting updates service")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSettingUpdatesService() {
        let service = SettingsService()
        let vm = SettingsViewModel(settingsService: service)

        vm.appearance = .dark
        #expect(service.appearance == .dark)

        vm.defaultWindowCenter = 100
        #expect(service.defaultWindowCenter == 100)

        vm.anonymizationEnabled = true
        #expect(service.anonymizationEnabled == true)
    }

    @Test("Reset all to defaults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetAllToDefaults() {
        let service = SettingsService()
        let vm = SettingsViewModel(settingsService: service)

        vm.appearance = .dark
        vm.defaultWindowCenter = 999
        vm.maxCacheSizeMB = 4096
        vm.anonymizationEnabled = true

        vm.resetAllToDefaults()

        #expect(vm.appearance == .system)
        #expect(vm.defaultWindowCenter == 40)
        #expect(vm.maxCacheSizeMB == 512)
        #expect(vm.anonymizationEnabled == false)
    }

    @Test("Default selected section is general")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultSection() {
        let vm = SettingsViewModel()
        #expect(vm.selectedSection == .general)
    }

    @Test("All settings sections exist")
    func testAllSettingsSections() {
        let allCases = SettingsSection.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.general))
        #expect(allCases.contains(.privacy))
        #expect(allCases.contains(.performance))
        #expect(allCases.contains(.about))
    }

    @Test("Settings sections have system images")
    func testSettingsSectionImages() {
        for section in SettingsSection.allCases {
            #expect(!section.systemImage.isEmpty)
        }
    }

    @Test("Settings sections are identifiable")
    func testSettingsSectionIdentifiable() {
        for section in SettingsSection.allCases {
            #expect(section.id == section.rawValue)
        }
    }

    @Test("Privacy settings round-trip")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPrivacySettings() {
        let vm = SettingsViewModel()

        vm.auditLoggingEnabled = true
        #expect(vm.settingsService.auditLoggingEnabled == true)

        vm.removePrivateTags = false
        #expect(vm.settingsService.removePrivateTags == false)
    }

    @Test("Performance settings round-trip")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerformanceSettings() {
        let vm = SettingsViewModel()

        vm.maxMemoryUsageMB = 4096
        #expect(vm.settingsService.maxMemoryUsageMB == 4096)

        vm.thumbnailQuality = 0.5
        #expect(vm.settingsService.thumbnailQuality == 0.5)

        vm.prefetchEnabled = false
        #expect(vm.settingsService.prefetchEnabled == false)

        vm.threadPoolSize = 8
        #expect(vm.settingsService.threadPoolSize == 8)
    }
}
