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

    @Test("Thumbnail URL with frame number")
    func testThumbnailURLWithFrame() throws {
        let (service, storage) = try makeServices()
        defer { try? FileManager.default.removeItem(at: storage.baseDirectory) }

        let url = service.thumbnailURL(for: "1.2.840.1234", frameNumber: 3)
        #expect(url.lastPathComponent == "1_2_840_1234_f3.png")
    }

    @Test("Should generate thumbnail for valid instance")
    func testShouldGenerateThumbnailValid() {
        let storage = StorageService(baseDirectory: URL(fileURLWithPath: "/tmp"))
        let service = ThumbnailService(storageService: storage)
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.1",
            filePath: "/tmp/test.dcm",
            rows: 512,
            columns: 512,
            photometricInterpretation: "MONOCHROME2"
        )
        #expect(service.shouldGenerateThumbnail(for: instance) == true)
    }

    @Test("Should not generate thumbnail for instance without pixel data")
    func testShouldNotGenerateThumbnailNoPixels() {
        let storage = StorageService(baseDirectory: URL(fileURLWithPath: "/tmp"))
        let service = ThumbnailService(storageService: storage)
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.88.11",
            seriesInstanceUID: "1.2.3.1",
            filePath: "/tmp/test.dcm"
        )
        #expect(service.shouldGenerateThumbnail(for: instance) == false)
    }

    @Test("Thumbnail dimensions for valid instance")
    func testThumbnailDimensionsValid() {
        let storage = StorageService(baseDirectory: URL(fileURLWithPath: "/tmp"))
        let service = ThumbnailService(storageService: storage, maxThumbnailSize: 128)
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2.3.1",
            filePath: "/tmp/test.dcm",
            rows: 512,
            columns: 256
        )
        let dims = service.thumbnailDimensions(for: instance)
        #expect(dims != nil)
        #expect(dims!.width == 64)
        #expect(dims!.height == 128)
    }

    @Test("Thumbnail dimensions returns nil for instance without dimensions")
    func testThumbnailDimensionsNil() {
        let storage = StorageService(baseDirectory: URL(fileURLWithPath: "/tmp"))
        let service = ThumbnailService(storageService: storage)
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2.3.1",
            filePath: "/tmp/test.dcm"
        )
        #expect(service.thumbnailDimensions(for: instance) == nil)
    }
}
