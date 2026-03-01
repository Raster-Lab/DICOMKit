// NavigationServiceTests.swift
// DICOMStudioTests
//
// Tests for NavigationService and NavigationDestination

import Testing
@testable import DICOMStudio
import Foundation

@Suite("NavigationService Tests")
struct NavigationServiceTests {

    @Test("All navigation destinations have system images")
    func testAllDestinationsHaveSystemImages() {
        for destination in NavigationDestination.allCases {
            #expect(!destination.systemImage.isEmpty, "Missing system image for \(destination.rawValue)")
        }
    }

    @Test("All navigation destinations have accessibility labels")
    func testAllDestinationsHaveAccessibilityLabels() {
        for destination in NavigationDestination.allCases {
            #expect(!destination.accessibilityLabel.isEmpty, "Missing accessibility label for \(destination.rawValue)")
        }
    }

    @Test("Navigation destinations are identifiable")
    func testDestinationsIdentifiable() {
        for destination in NavigationDestination.allCases {
            #expect(destination.id == destination.rawValue)
        }
    }

    @Test("Default destination is library")
    func testDefaultDestination() {
        #expect(NavigationService.defaultDestination == .library)
    }

    @Test("Primary destinations exclude settings")
    func testPrimaryDestinationsExcludeSettings() {
        let primary = NavigationService.primaryDestinations
        #expect(!primary.contains(.settings))
    }

    @Test("Primary destinations include all non-settings items")
    func testPrimaryDestinationsCount() {
        let primary = NavigationService.primaryDestinations
        #expect(primary.count == NavigationDestination.allCases.count - 1)
    }

    @Test("All seven destinations exist")
    func testAllDestinationsExist() {
        let allCases = NavigationDestination.allCases
        #expect(allCases.count == 7)
        #expect(allCases.contains(.library))
        #expect(allCases.contains(.viewer))
        #expect(allCases.contains(.networking))
        #expect(allCases.contains(.reporting))
        #expect(allCases.contains(.tools))
        #expect(allCases.contains(.cliWorkshop))
        #expect(allCases.contains(.settings))
    }

    @Test("NavigationService can be created")
    func testNavigationServiceInit() {
        let service = NavigationService()
        _ = service
        // Just verifying it can be created without issues
    }

    @Test("System images are valid SF Symbol names")
    func testSystemImagesAreStrings() {
        #expect(NavigationDestination.library.systemImage == "folder")
        #expect(NavigationDestination.viewer.systemImage == "photo")
        #expect(NavigationDestination.networking.systemImage == "network")
        #expect(NavigationDestination.reporting.systemImage == "doc.text")
        #expect(NavigationDestination.tools.systemImage == "wrench.and.screwdriver")
        #expect(NavigationDestination.cliWorkshop.systemImage == "terminal")
        #expect(NavigationDestination.settings.systemImage == "gear")
    }
}
