// ImportServiceTests.swift
// DICOMStudioTests
//
// Tests for ImportService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ImportService Tests")
struct ImportServiceTests {

    @Test("Service initializes with default file service")
    func testInitDefault() {
        let service = ImportService()
        #expect(service.fileService is DICOMFileService)
    }

    @Test("Service initializes with custom file service")
    func testInitCustom() {
        let fileService = DICOMFileService()
        let service = ImportService(fileService: fileService)
        #expect(service.fileService === fileService)
    }

    @Test("Import non-existent file returns error")
    func testImportNonExistent() {
        let service = ImportService()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).dcm")
        let result = service.importFile(at: url)
        #expect(!result.succeeded)
        #expect(result.validationIssues.contains { $0.severity == .error })
    }

    @Test("Import too-small file returns error")
    func testImportTooSmall() throws {
        let service = ImportService()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiny_\(UUID().uuidString).dcm")
        try Data(count: 10).write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let result = service.importFile(at: tmpURL)
        #expect(!result.succeeded)
        #expect(result.validationIssues.contains { $0.rule == .fileSize })
    }

    @Test("Import file without DICM magic returns error")
    func testImportNoDICMMagic() throws {
        let service = ImportService()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nomagic_\(UUID().uuidString).dcm")
        try Data(count: 200).write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let result = service.importFile(at: tmpURL)
        #expect(!result.succeeded)
        #expect(result.validationIssues.contains { $0.rule == .dicmMagic })
    }

    @Test("Batch import with empty URLs returns empty results")
    func testBatchImportEmpty() {
        let service = ImportService()
        let results = service.importFiles(at: [])
        #expect(results.isEmpty)
    }

    @Test("Batch import tracks progress")
    func testBatchImportProgress() throws {
        let service = ImportService()
        let urls = (0..<3).map { _ in
            URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).dcm")
        }

        var progressUpdates: [ImportProgress] = []
        let results = service.importFiles(at: urls) { progress in
            progressUpdates.append(progress)
        }

        #expect(results.count == 3)
        #expect(progressUpdates.count == 3)
        #expect(progressUpdates.last?.isComplete == true)
        #expect(progressUpdates.last?.processedFiles == 3)
    }

    @Test("Scan directory returns empty for non-existent directory")
    func testScanNonExistentDirectory() {
        let service = ImportService()
        let urls = service.scanDirectory(at: URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)"))
        #expect(urls.isEmpty)
    }

    @Test("Scan directory finds .dcm files")
    func testScanDirectoryFindsFiles() throws {
        let service = ImportService()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create test files
        try Data().write(to: tmpDir.appendingPathComponent("test1.dcm"))
        try Data().write(to: tmpDir.appendingPathComponent("test2.dcm"))
        try Data().write(to: tmpDir.appendingPathComponent("test3.txt")) // Not DICOM

        let urls = service.scanDirectory(at: tmpDir)
        #expect(urls.count == 2)
    }

    @Test("Service is Sendable")
    func testSendable() {
        let service = ImportService()
        let _: any Sendable = service
        _ = service
    }
}
