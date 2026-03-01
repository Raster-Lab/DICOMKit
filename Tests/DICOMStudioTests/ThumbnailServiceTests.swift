// ThumbnailServiceTests.swift
// DICOMStudioTests
//
// Tests for ThumbnailService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ThumbnailService Tests")
struct ThumbnailServiceTests {

    private func makeServices() throws -> (ThumbnailService, StorageService) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DICOMStudioTests-\(UUID().uuidString)", isDirectory: true)
        let storage = StorageService(baseDirectory: tempDir)
        try storage.createDirectories()
        let thumbnail = ThumbnailService(storageService: storage)
        return (thumbnail, storage)
    }

    @Test("Thumbnail URL generation")
    func testThumbnailURL() throws {
        let (service, storage) = try makeServices()
        let url = service.thumbnailURL(for: "1.2.840.1234.5678")
        #expect(url.lastPathComponent == "1_2_840_1234_5678.png")
        #expect(url.deletingLastPathComponent().lastPathComponent == "Thumbnails")

        // Cleanup
        try? FileManager.default.removeItem(at: storage.baseDirectory)
    }

    @Test("No cached thumbnail for new UID")
    func testNoCachedThumbnail() throws {
        let (service, storage) = try makeServices()
        #expect(service.hasCachedThumbnail(for: "1.2.3.4.5") == false)

        // Cleanup
        try? FileManager.default.removeItem(at: storage.baseDirectory)
    }

    @Test("Detect cached thumbnail after creation")
    func testDetectCachedThumbnail() throws {
        let (service, storage) = try makeServices()
        let sopUID = "1.2.3.4.5"

        // Manually create a thumbnail file
        let url = service.thumbnailURL(for: sopUID)
        try Data(repeating: 0x89, count: 100).write(to: url)

        #expect(service.hasCachedThumbnail(for: sopUID) == true)

        // Cleanup
        try? FileManager.default.removeItem(at: storage.baseDirectory)
    }

    @Test("Clear cache removes thumbnails")
    func testClearCache() throws {
        let (service, storage) = try makeServices()

        // Create a thumbnail file
        let url = service.thumbnailURL(for: "1.2.3")
        try Data(repeating: 0x89, count: 100).write(to: url)
        #expect(service.hasCachedThumbnail(for: "1.2.3") == true)

        try service.clearCache()
        #expect(service.hasCachedThumbnail(for: "1.2.3") == false)

        // Cleanup
        try? FileManager.default.removeItem(at: storage.baseDirectory)
    }

    @Test("Default max thumbnail size")
    func testDefaultMaxSize() {
        let storage = StorageService(baseDirectory: URL(fileURLWithPath: "/tmp"))
        let service = ThumbnailService(storageService: storage)
        #expect(service.maxSize == 128)
    }

    @Test("Custom max thumbnail size")
    func testCustomMaxSize() {
        let storage = StorageService(baseDirectory: URL(fileURLWithPath: "/tmp"))
        let service = ThumbnailService(storageService: storage, maxThumbnailSize: 256)
        #expect(service.maxSize == 256)
    }
}
