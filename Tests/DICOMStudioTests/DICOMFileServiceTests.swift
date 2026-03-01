// DICOMFileServiceTests.swift
// DICOMStudioTests
//
// Tests for DICOMFileService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("DICOMFileService Tests")
struct DICOMFileServiceTests {

    @Test("Service initializes successfully")
    func testInitialization() {
        let service = DICOMFileService()
        #expect(service != nil)
    }

    @Test("Parse file throws for nonexistent path")
    func testParseNonexistentFile() {
        let service = DICOMFileService()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_dicom_file.dcm")
        #expect(throws: (any Error).self) {
            _ = try service.parseFile(at: url)
        }
    }

    @Test("Extract study metadata throws for nonexistent path")
    func testExtractStudyNonexistentFile() {
        let service = DICOMFileService()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_study_file.dcm")
        #expect(throws: (any Error).self) {
            _ = try service.extractStudyMetadata(from: url)
        }
    }

    @Test("Extract series metadata throws for nonexistent path")
    func testExtractSeriesNonexistentFile() {
        let service = DICOMFileService()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_series_file.dcm")
        #expect(throws: (any Error).self) {
            _ = try service.extractSeriesMetadata(from: url)
        }
    }

    @Test("Parse file throws for empty file")
    func testParseEmptyFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("empty_test_\(UUID().uuidString).dcm")
        try Data().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let service = DICOMFileService()
        #expect(throws: (any Error).self) {
            _ = try service.parseFile(at: fileURL)
        }
    }

    @Test("Parse file throws for invalid DICOM data")
    func testParseInvalidData() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid_test_\(UUID().uuidString).dcm")
        let invalidData = Data("This is not a DICOM file".utf8)
        try invalidData.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let service = DICOMFileService()
        #expect(throws: (any Error).self) {
            _ = try service.parseFile(at: fileURL)
        }
    }

    @Test("Extract study metadata throws for invalid data")
    func testExtractStudyInvalidData() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid_study_\(UUID().uuidString).dcm")
        try Data("invalid".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let service = DICOMFileService()
        #expect(throws: (any Error).self) {
            _ = try service.extractStudyMetadata(from: fileURL)
        }
    }

    @Test("Extract series metadata throws for invalid data")
    func testExtractSeriesInvalidData() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid_series_\(UUID().uuidString).dcm")
        try Data("invalid".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let service = DICOMFileService()
        #expect(throws: (any Error).self) {
            _ = try service.extractSeriesMetadata(from: fileURL)
        }
    }

    @Test("Parse file throws for directory instead of file")
    func testParseDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("dicom_test_dir_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = DICOMFileService()
        #expect(throws: (any Error).self) {
            _ = try service.parseFile(at: tempDir)
        }
    }

    @Test("Service is Sendable")
    func testSendable() {
        let service = DICOMFileService()
        let _: any Sendable = service
        #expect(true)
    }

    @Test("Multiple service instances are independent")
    func testMultipleInstances() {
        let service1 = DICOMFileService()
        let service2 = DICOMFileService()
        #expect(service1 !== service2)
    }
}
