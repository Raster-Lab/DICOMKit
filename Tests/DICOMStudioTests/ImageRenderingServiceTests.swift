// ImageRenderingServiceTests.swift
// DICOMStudioTests
//
// Tests for ImageRenderingService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ImageRenderingService Tests")
struct ImageRenderingServiceTests {

    @Test("Service can be created")
    func testServiceCreation() {
        let service = ImageRenderingService()
        #expect(service != nil)
    }

    @Test("Pixel descriptor for nonexistent file throws")
    func testPixelDescriptorNonexistent() async throws {
        let service = ImageRenderingService()
        #expect(throws: (any Error).self) {
            _ = try service.pixelDataDescriptor(filePath: "/nonexistent/file.dcm")
        }
    }

    @Test("Window settings for nonexistent file throws")
    func testWindowSettingsNonexistent() async throws {
        let service = ImageRenderingService()
        #expect(throws: (any Error).self) {
            _ = try service.windowSettings(filePath: "/nonexistent/file.dcm")
        }
    }
}

@Suite("ImageCacheService Tests")
struct ImageCacheServiceTests {

    @Test("Service can be created with default memory")
    func testServiceCreationDefault() {
        let service = ImageCacheService()
        #expect(service != nil)
    }

    @Test("Service can be created with custom memory")
    func testServiceCreationCustom() {
        let service = ImageCacheService(maxMemoryMB: 100)
        #expect(service != nil)
    }
}
