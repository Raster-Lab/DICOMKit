// StorageServiceTests.swift
// DICOMStudioTests
//
// Tests for StorageService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("StorageService Tests")
struct StorageServiceTests {

    private func makeTempStorage() -> StorageService {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DICOMStudioTests-\(UUID().uuidString)", isDirectory: true)
        return StorageService(baseDirectory: tempDir)
    }

    @Test("Storage directories are correctly defined")
    func testDirectoryPaths() {
        let service = makeTempStorage()
        #expect(service.importDirectory.lastPathComponent == "Imports")
        #expect(service.thumbnailDirectory.lastPathComponent == "Thumbnails")
        #expect(service.cacheDirectory.lastPathComponent == "Cache")
        #expect(service.exportDirectory.lastPathComponent == "Exports")
    }

    @Test("Create directories")
    func testCreateDirectories() throws {
        let service = makeTempStorage()
        try service.createDirectories()

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: service.baseDirectory.path))
        #expect(fm.fileExists(atPath: service.importDirectory.path))
        #expect(fm.fileExists(atPath: service.thumbnailDirectory.path))
        #expect(fm.fileExists(atPath: service.cacheDirectory.path))
        #expect(fm.fileExists(atPath: service.exportDirectory.path))

        // Cleanup
        try? fm.removeItem(at: service.baseDirectory)
    }

    @Test("Create directories is idempotent")
    func testCreateDirectoriesIdempotent() throws {
        let service = makeTempStorage()
        try service.createDirectories()
        try service.createDirectories() // Should not throw

        // Cleanup
        try? FileManager.default.removeItem(at: service.baseDirectory)
    }

    @Test("Cache size returns zero for empty directory")
    func testCacheSizeEmpty() throws {
        let service = makeTempStorage()
        try service.createDirectories()

        #expect(service.cacheSize() == 0)

        // Cleanup
        try? FileManager.default.removeItem(at: service.baseDirectory)
    }

    @Test("Cache size returns correct value")
    func testCacheSizeWithFiles() throws {
        let service = makeTempStorage()
        try service.createDirectories()

        // Write a test file to the cache directory
        let testFile = service.cacheDirectory.appendingPathComponent("test.dat")
        let testData = Data(repeating: 0xFF, count: 1024)
        try testData.write(to: testFile)

        let size = service.cacheSize()
        #expect(size >= 1024)

        // Cleanup
        try? FileManager.default.removeItem(at: service.baseDirectory)
    }

    @Test("Clear cache removes files")
    func testClearCache() throws {
        let service = makeTempStorage()
        try service.createDirectories()

        // Write a test file
        let testFile = service.cacheDirectory.appendingPathComponent("test.dat")
        try Data(repeating: 0xFF, count: 512).write(to: testFile)
        #expect(service.cacheSize() >= 512)

        try service.clearCache()
        #expect(service.cacheSize() == 0)

        // Cleanup
        try? FileManager.default.removeItem(at: service.baseDirectory)
    }

    @Test("Clear thumbnail cache removes files")
    func testClearThumbnailCache() throws {
        let service = makeTempStorage()
        try service.createDirectories()

        let testFile = service.thumbnailDirectory.appendingPathComponent("thumb.png")
        try Data(repeating: 0xAA, count: 256).write(to: testFile)
        #expect(service.thumbnailCacheSize() >= 256)

        try service.clearThumbnailCache()
        #expect(service.thumbnailCacheSize() == 0)

        // Cleanup
        try? FileManager.default.removeItem(at: service.baseDirectory)
    }

    @Test("Clear cache on nonexistent directory does not throw")
    func testClearCacheNonexistent() throws {
        let service = makeTempStorage()
        // Don't create directories
        try service.clearCache()
    }

    @Test("Default base directory uses Application Support")
    func testDefaultBaseDirectory() {
        let service = StorageService()
        #expect(service.baseDirectory.lastPathComponent == "DICOMStudio")
    }
}
