// LibraryStorageServiceTests.swift
// DICOMStudioTests
//
// Tests for LibraryStorageService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("LibraryStorageService Tests")
struct LibraryStorageServiceTests {

    private func makeTempStorage() -> (StorageService, URL) {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dicomstudio_test_\(UUID().uuidString)")
        let storage = StorageService(baseDirectory: tmpDir)
        return (storage, tmpDir)
    }

    @Test("Service initializes correctly")
    func testInit() {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)
        #expect(service.indexURL.lastPathComponent == "library-index.json")
    }

    @Test("No index initially")
    func testNoIndexInitially() {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)
        #expect(!service.hasIndex)
    }

    @Test("Save creates index file")
    func testSaveCreatesIndex() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        let library = LibraryModel()
        try service.save(library)
        #expect(service.hasIndex)
    }

    @Test("Save and load empty library")
    func testSaveLoadEmpty() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        try service.save(LibraryModel())
        let loaded = service.load()
        #expect(loaded.studyCount == 0)
    }

    @Test("Save and load library with study")
    func testSaveLoadWithStudy() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        var library = LibraryModel()
        let study = StudyModel(
            studyInstanceUID: "1.2.3.4",
            studyID: "S1",
            studyDescription: "Test Study",
            patientName: "DOE^JOHN",
            patientID: "P001",
            modalitiesInStudy: ["CT"]
        )
        library.addStudy(study)
        try service.save(library)

        let loaded = service.load()
        #expect(loaded.studyCount == 1)
        #expect(loaded.studies["1.2.3.4"]?.patientName == "DOE^JOHN")
        #expect(loaded.studies["1.2.3.4"]?.studyDescription == "Test Study")
    }

    @Test("Save and load library with full hierarchy")
    func testSaveLoadFullHierarchy() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        var library = LibraryModel()
        let study = StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        )
        let series = SeriesModel(
            seriesInstanceUID: "1.2.3.1",
            studyInstanceUID: "1.2.3",
            modality: "CT"
        )
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3.1.1",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.1",
            filePath: "/tmp/test.dcm",
            fileSize: 12345
        )
        library.addStudy(study)
        library.addSeries(series)
        library.addInstance(instance)
        try service.save(library)

        let loaded = service.load()
        #expect(loaded.studyCount == 1)
        #expect(loaded.seriesCount == 1)
        #expect(loaded.instanceCount == 1)
        #expect(loaded.seriesForStudy("1.2.3").count == 1)
        #expect(loaded.instancesForSeries("1.2.3.1").count == 1)
    }

    @Test("Load from missing index returns empty library")
    func testLoadMissingIndex() {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        let library = service.load()
        #expect(library.studyCount == 0)
    }

    @Test("Delete index removes file")
    func testDeleteIndex() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        try service.save(LibraryModel())
        #expect(service.hasIndex)
        try service.deleteIndex()
        #expect(!service.hasIndex)
    }

    @Test("Delete non-existent index does not throw")
    func testDeleteNonExistentIndex() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        try service.deleteIndex()
    }

    @Test("Index size for empty library")
    func testIndexSize() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        try service.save(LibraryModel())
        let size = service.indexSize()
        #expect(size > 0)
    }

    @Test("Index size for missing index is zero")
    func testIndexSizeMissing() {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        #expect(service.indexSize() == 0)
    }

    @Test("Export creates export file")
    func testExport() throws {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)

        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: exportDir) }

        var library = LibraryModel()
        library.addStudy(StudyModel(
            studyInstanceUID: "1.2.3",
            studyID: "S1",
            modalitiesInStudy: ["CT"]
        ))
        try service.export(library, to: exportDir)

        let exportFile = exportDir.appendingPathComponent("dicom-library-export.json")
        #expect(FileManager.default.fileExists(atPath: exportFile.path))
    }

    @Test("Service is Sendable")
    func testSendable() {
        let (storage, tmpDir) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let service = LibraryStorageService(storageService: storage)
        let _: any Sendable = service
        _ = service
    }

    @Test("Index filename constant")
    func testIndexFilename() {
        #expect(LibraryStorageService.indexFilename == "library-index.json")
    }
}
