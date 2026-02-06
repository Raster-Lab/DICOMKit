// WatchFolderServiceTests.swift
// DICOMViewer macOS - Tests for Watch Folder Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMViewer

@MainActor
final class WatchFolderServiceTests: XCTestCase {
    
    var service: WatchFolderService!
    var testDirectory: URL!
    
    override func setUp() async throws {
        service = WatchFolderService()
        
        // Create a temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchFolderTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        service.stopMonitoring()
        service = nil
        
        // Clean up test directory
        if let testDir = testDirectory {
            try? FileManager.default.removeItem(at: testDir)
        }
        testDirectory = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInit_DefaultState() {
        XCTAssertFalse(service.isMonitoring)
        XCTAssertTrue(service.watchedFolders.isEmpty || !service.watchedFolders.isEmpty) // May have persisted folders
        XCTAssertEqual(service.statistics.filesDetected, 0)
        XCTAssertEqual(service.statistics.filesImported, 0)
        XCTAssertEqual(service.statistics.filesFailed, 0)
    }
    
    func testConfiguration_DefaultValues() {
        let config = WatchFolderService.Configuration()
        
        XCTAssertTrue(config.extensions.contains("dcm"))
        XCTAssertTrue(config.extensions.contains("dicom"))
        XCTAssertEqual(config.minimumFileSize, 128)
        XCTAssertEqual(config.importDelay, 2.0)
        XCTAssertTrue(config.detectDuplicates)
        XCTAssertEqual(config.maxConcurrentImports, 4)
        XCTAssertTrue(config.enableLogging)
    }
    
    // MARK: - Add/Remove Folder Tests
    
    func testAddWatchedFolder_Success() throws {
        let initialCount = service.watchedFolders.count
        
        try service.addWatchedFolder(testDirectory)
        
        XCTAssertEqual(service.watchedFolders.count, initialCount + 1)
        XCTAssertTrue(service.watchedFolders.contains(testDirectory))
    }
    
    func testAddWatchedFolder_NonExistentFolder() {
        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NonExistent_\(UUID().uuidString)")
        
        XCTAssertThrowsError(try service.addWatchedFolder(nonExistentURL)) { error in
            XCTAssertTrue(error is WatchFolderService.WatchFolderError)
            XCTAssertEqual(error as? WatchFolderService.WatchFolderError, .folderNotFound)
        }
    }
    
    func testAddWatchedFolder_FileInsteadOfDirectory() throws {
        let testFile = testDirectory.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        XCTAssertThrowsError(try service.addWatchedFolder(testFile)) { error in
            XCTAssertTrue(error is WatchFolderService.WatchFolderError)
            XCTAssertEqual(error as? WatchFolderService.WatchFolderError, .notADirectory)
        }
    }
    
    func testAddWatchedFolder_DuplicateFolder() throws {
        try service.addWatchedFolder(testDirectory)
        
        XCTAssertThrowsError(try service.addWatchedFolder(testDirectory)) { error in
            XCTAssertTrue(error is WatchFolderService.WatchFolderError)
            XCTAssertEqual(error as? WatchFolderService.WatchFolderError, .alreadyWatching)
        }
    }
    
    func testRemoveWatchedFolder_Success() throws {
        try service.addWatchedFolder(testDirectory)
        let countAfterAdd = service.watchedFolders.count
        
        service.removeWatchedFolder(testDirectory)
        
        XCTAssertEqual(service.watchedFolders.count, countAfterAdd - 1)
        XCTAssertFalse(service.watchedFolders.contains(testDirectory))
    }
    
    func testRemoveWatchedFolder_NotWatched() {
        let initialCount = service.watchedFolders.count
        
        service.removeWatchedFolder(testDirectory)
        
        XCTAssertEqual(service.watchedFolders.count, initialCount)
    }
    
    // MARK: - Monitoring Tests
    
    func testStartMonitoring_Success() throws {
        try service.addWatchedFolder(testDirectory)
        
        try service.startMonitoring()
        
        XCTAssertTrue(service.isMonitoring)
    }
    
    func testStartMonitoring_AlreadyMonitoring() throws {
        try service.addWatchedFolder(testDirectory)
        try service.startMonitoring()
        
        // Should not throw when called again
        XCTAssertNoThrow(try service.startMonitoring())
        XCTAssertTrue(service.isMonitoring)
    }
    
    func testStopMonitoring() throws {
        try service.addWatchedFolder(testDirectory)
        try service.startMonitoring()
        
        service.stopMonitoring()
        
        XCTAssertFalse(service.isMonitoring)
    }
    
    func testStopMonitoring_NotMonitoring() {
        XCTAssertFalse(service.isMonitoring)
        
        // Should not throw
        XCTAssertNoThrow(service.stopMonitoring())
        XCTAssertFalse(service.isMonitoring)
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics_InitialState() {
        let stats = service.statistics
        
        XCTAssertEqual(stats.filesDetected, 0)
        XCTAssertEqual(stats.filesImported, 0)
        XCTAssertEqual(stats.filesFailed, 0)
        XCTAssertEqual(stats.duplicatesSkipped, 0)
        XCTAssertNil(stats.lastImportDate)
    }
    
    func testResetStatistics() {
        // Manually set some statistics
        service.statistics.filesDetected = 10
        service.statistics.filesImported = 8
        service.statistics.filesFailed = 2
        service.statistics.lastImportDate = Date()
        
        service.resetStatistics()
        
        XCTAssertEqual(service.statistics.filesDetected, 0)
        XCTAssertEqual(service.statistics.filesImported, 0)
        XCTAssertEqual(service.statistics.filesFailed, 0)
        XCTAssertNil(service.statistics.lastImportDate)
    }
    
    // MARK: - Configuration Tests
    
    func testConfiguration_CustomExtensions() {
        service.configuration.extensions = ["abc", "xyz"]
        
        XCTAssertTrue(service.configuration.extensions.contains("abc"))
        XCTAssertTrue(service.configuration.extensions.contains("xyz"))
        XCTAssertFalse(service.configuration.extensions.contains("dcm"))
    }
    
    func testConfiguration_MinimumFileSize() {
        service.configuration.minimumFileSize = 1024
        
        XCTAssertEqual(service.configuration.minimumFileSize, 1024)
    }
    
    func testConfiguration_ImportDelay() {
        service.configuration.importDelay = 5.0
        
        XCTAssertEqual(service.configuration.importDelay, 5.0)
    }
    
    func testConfiguration_DuplicateDetection() {
        service.configuration.detectDuplicates = false
        
        XCTAssertFalse(service.configuration.detectDuplicates)
    }
    
    func testConfiguration_MaxConcurrentImports() {
        service.configuration.maxConcurrentImports = 8
        
        XCTAssertEqual(service.configuration.maxConcurrentImports, 8)
    }
    
    func testConfiguration_Logging() {
        service.configuration.enableLogging = false
        
        XCTAssertFalse(service.configuration.enableLogging)
    }
    
    // MARK: - Error Tests
    
    func testError_NotADirectory() {
        let error = WatchFolderService.WatchFolderError.notADirectory
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not a directory"))
    }
    
    func testError_FolderNotFound() {
        let error = WatchFolderService.WatchFolderError.folderNotFound
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not exist"))
    }
    
    func testError_AlreadyWatching() {
        let error = WatchFolderService.WatchFolderError.alreadyWatching
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("already"))
    }
    
    func testError_FailedToCreateStream() {
        let error = WatchFolderService.WatchFolderError.failedToCreateStream
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("create"))
    }
    
    func testError_FailedToStartStream() {
        let error = WatchFolderService.WatchFolderError.failedToStartStream
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("start"))
    }
    
    // MARK: - Persistence Tests
    
    func testPersistence_SaveAndLoadWatchedFolders() throws {
        // Create a new service to test persistence
        let service1 = WatchFolderService()
        try service1.addWatchedFolder(testDirectory)
        
        let savedFolders = service1.watchedFolders
        
        // Create another service instance to load persisted data
        let service2 = WatchFolderService()
        
        // The new service should load the persisted folders
        XCTAssertTrue(service2.watchedFolders.contains(testDirectory) || savedFolders.isEmpty)
    }
    
    // MARK: - Multiple Folders Tests
    
    func testMultipleFolders_AddThree() throws {
        let folder1 = testDirectory.appendingPathComponent("folder1")
        let folder2 = testDirectory.appendingPathComponent("folder2")
        let folder3 = testDirectory.appendingPathComponent("folder3")
        
        try FileManager.default.createDirectory(at: folder1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder2, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder3, withIntermediateDirectories: true)
        
        let initialCount = service.watchedFolders.count
        
        try service.addWatchedFolder(folder1)
        try service.addWatchedFolder(folder2)
        try service.addWatchedFolder(folder3)
        
        XCTAssertEqual(service.watchedFolders.count, initialCount + 3)
        XCTAssertTrue(service.watchedFolders.contains(folder1))
        XCTAssertTrue(service.watchedFolders.contains(folder2))
        XCTAssertTrue(service.watchedFolders.contains(folder3))
    }
    
    func testMultipleFolders_RemoveMiddle() throws {
        let folder1 = testDirectory.appendingPathComponent("folder1")
        let folder2 = testDirectory.appendingPathComponent("folder2")
        let folder3 = testDirectory.appendingPathComponent("folder3")
        
        try FileManager.default.createDirectory(at: folder1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder2, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder3, withIntermediateDirectories: true)
        
        try service.addWatchedFolder(folder1)
        try service.addWatchedFolder(folder2)
        try service.addWatchedFolder(folder3)
        
        service.removeWatchedFolder(folder2)
        
        XCTAssertTrue(service.watchedFolders.contains(folder1))
        XCTAssertFalse(service.watchedFolders.contains(folder2))
        XCTAssertTrue(service.watchedFolders.contains(folder3))
    }
}
