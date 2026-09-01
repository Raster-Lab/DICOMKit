// StudyFileCleanupTests.swift
// DICOMStudioTests
//
// Deleting a study must reclaim the files the app copied for it.

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Study file cleanup")
@MainActor
struct StudyFileCleanupTests {

    /// A throwaway storage root, torn down by the caller.
    private func makeRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyFileCleanupTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        return root
    }

    /// Writes a study folder holding `count` files, as import would.
    @discardableResult
    private func makeStudyFiles(
        in importDirectory: URL, studyUID: String, count: Int = 3
    ) throws -> [String] {
        let dir = importDirectory.appendingPathComponent(studyUID, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for i in 0..<count {
            let url = dir.appendingPathComponent("\(studyUID).\(i).dcm")
            try Data(repeating: 0xAB, count: 512).write(to: url)
            paths.append(url.path)
        }
        return paths
    }

    // MARK: - The core promise

    @Test("Deleting a study removes its copied files")
    func testRemovesStudyFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let paths = try makeStudyFiles(in: imports, studyUID: "1.2.3")

        let cleanup = StudyFileCleanup(importDirectory: imports)
        let outcome = cleanup.removeFiles(forStudy: "1.2.3", knownPaths: paths)

        #expect(outcome.filesDeleted == 3)
        #expect(outcome.bytesReclaimed == 3 * 512)
        #expect(!FileManager.default.fileExists(
            atPath: imports.appendingPathComponent("1.2.3").path))
        for path in paths {
            #expect(!FileManager.default.fileExists(atPath: path))
        }
    }

    @Test("Deleting one study leaves other studies untouched")
    func testLeavesSiblingStudies() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try makeStudyFiles(in: imports, studyUID: "1.2.3")
        let keep = try makeStudyFiles(in: imports, studyUID: "1.2.4")

        StudyFileCleanup(importDirectory: imports).removeFiles(forStudy: "1.2.3")

        for path in keep {
            #expect(FileManager.default.fileExists(atPath: path))
        }
    }

    @Test("Saved views for the study are removed too")
    func testRemovesSavedViews() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let states = root.appendingPathComponent("PresentationStates", isDirectory: true)
        try makeStudyFiles(in: imports, studyUID: "1.2.3")

        let viewDir = states.appendingPathComponent("1.2.3", isDirectory: true)
        try FileManager.default.createDirectory(
            at: viewDir, withIntermediateDirectories: true)
        try Data([0x01]).write(to: viewDir.appendingPathComponent("pr.dcm"))
        try Data("{}".utf8).write(
            to: viewDir.appendingPathComponent("pr.annotations.json"))

        let outcome = StudyFileCleanup(
            importDirectory: imports, presentationStateRoot: states
        ).removeFiles(forStudy: "1.2.3")

        #expect(outcome.savedViewsDeleted)
        #expect(!FileManager.default.fileExists(atPath: viewDir.path))
    }

    // MARK: - The safety rule

    @Test("Files stored outside the app are kept, not deleted")
    func testKeepsExternalFiles() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: imports, withIntermediateDirectories: true)

        // An instance the library points at in place — a user's own file.
        let external = root.appendingPathComponent("user-original.dcm")
        try Data(repeating: 0x7F, count: 64).write(to: external)

        let cleanup = StudyFileCleanup(importDirectory: imports)
        let outcome = cleanup.removeFiles(
            forStudy: "1.2.3", knownPaths: [external.path])

        #expect(FileManager.default.fileExists(atPath: external.path))
        #expect(outcome.externalPathsKept == [external.path])
        #expect(outcome.filesDeleted == 0)
    }

    @Test("A sibling directory with a shared prefix is not treated as managed")
    func testPrefixIsNotContainment() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let cleanup = StudyFileCleanup(importDirectory: imports)

        #expect(cleanup.isManaged(imports.appendingPathComponent("a/b.dcm").path))
        // "ImportsOld" starts with "Imports" but is a different directory.
        #expect(!cleanup.isManaged(
            root.appendingPathComponent("ImportsOld/b.dcm").path))
        #expect(!cleanup.isManaged("/etc/passwd"))
    }

    @Test("Deleting a study with no files on disk is a no-op")
    func testMissingFolderIsHarmless() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: imports, withIntermediateDirectories: true)

        let outcome = StudyFileCleanup(importDirectory: imports)
            .removeFiles(forStudy: "nonexistent")
        #expect(outcome.filesDeleted == 0)
        #expect(!outcome.savedViewsDeleted)
    }

    // MARK: - The orphan sweep

    @Test("Orphan sweep removes only folders the library does not list")
    func testOrphanSweep() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try makeStudyFiles(in: imports, studyUID: "kept", count: 2)
        try makeStudyFiles(in: imports, studyUID: "orphan.1", count: 2)
        try makeStudyFiles(in: imports, studyUID: "orphan.2", count: 1)

        let cleanup = StudyFileCleanup(importDirectory: imports)
        let (outcome, swept) = cleanup.removeOrphanedStudies(
            knownStudyUIDs: ["kept"])

        #expect(swept.sorted() == ["orphan.1", "orphan.2"])
        #expect(outcome.filesDeleted == 3)
        #expect(FileManager.default.fileExists(
            atPath: imports.appendingPathComponent("kept").path))
        #expect(!FileManager.default.fileExists(
            atPath: imports.appendingPathComponent("orphan.1").path))
    }

    @Test("Orphan size reports without deleting")
    func testOrphanSizeIsReadOnly() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try makeStudyFiles(in: imports, studyUID: "orphan", count: 4)

        let cleanup = StudyFileCleanup(importDirectory: imports)
        let (folders, bytes) = cleanup.orphanedStudySize(knownStudyUIDs: [])

        #expect(folders == 1)
        #expect(bytes == 4 * 512)
        // Still there — reporting must not reclaim.
        #expect(FileManager.default.fileExists(
            atPath: imports.appendingPathComponent("orphan").path))
    }

    // MARK: - Through the ViewModel

    @Test("removeStudy deletes the study's files")
    func testViewModelRemoveStudyDeletesFiles() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let paths = try makeStudyFiles(in: imports, studyUID: "1.2.3")

        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: "1.2.3", studyID: "S1",
                                    modalitiesInStudy: ["CT"]))
        library.addSeries(SeriesModel(seriesInstanceUID: "1.2.3.1",
                                      studyInstanceUID: "1.2.3", modality: "CT"))
        for (i, path) in paths.enumerated() {
            library.addInstance(InstanceModel(
                sopInstanceUID: "1.2.3.1.\(i)",
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                seriesInstanceUID: "1.2.3.1",
                instanceNumber: i,
                filePath: path))
        }

        let vm = StudyBrowserViewModel(
            library: library,
            libraryStorageService: LibraryStorageService(
                storageService: StorageService(baseDirectory: root)),
            fileCleanup: StudyFileCleanup(importDirectory: imports))

        var notified: String?
        vm.onStudyRemoved = { uid, _ in notified = uid }
        vm.removeStudy("1.2.3")

        #expect(vm.library.studyCount == 0)
        #expect(vm.lastCleanupOutcome?.filesDeleted == 3)
        #expect(notified == "1.2.3")
        for path in paths {
            #expect(!FileManager.default.fileExists(atPath: path))
        }
    }

    @Test("Without a cleanup, removeStudy only drops the index entry")
    func testViewModelWithoutCleanupLeavesFiles() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let paths = try makeStudyFiles(in: imports, studyUID: "1.2.3", count: 1)

        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: "1.2.3", studyID: "S1",
                                    modalitiesInStudy: ["CT"]))
        let vm = StudyBrowserViewModel(
            library: library,
            libraryStorageService: LibraryStorageService(
                storageService: StorageService(baseDirectory: root)))
        vm.removeStudy("1.2.3")

        #expect(vm.library.studyCount == 0)
        #expect(vm.lastCleanupOutcome == nil)
        #expect(FileManager.default.fileExists(atPath: paths[0]))
    }

    @Test("removeAllStudies reclaims every study's files")
    func testRemoveAllStudiesDeletesFiles() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try makeStudyFiles(in: imports, studyUID: "1.2.3", count: 2)
        try makeStudyFiles(in: imports, studyUID: "1.2.4", count: 2)

        var library = LibraryModel()
        for uid in ["1.2.3", "1.2.4"] {
            library.addStudy(StudyModel(studyInstanceUID: uid, studyID: uid,
                                        modalitiesInStudy: ["CT"]))
        }
        let vm = StudyBrowserViewModel(
            library: library,
            libraryStorageService: LibraryStorageService(
                storageService: StorageService(baseDirectory: root)),
            fileCleanup: StudyFileCleanup(importDirectory: imports))
        vm.removeAllStudies()

        #expect(vm.library.studyCount == 0)
        #expect(vm.lastCleanupOutcome?.filesDeleted == 4)
        #expect(!FileManager.default.fileExists(
            atPath: imports.appendingPathComponent("1.2.3").path))
        #expect(!FileManager.default.fileExists(
            atPath: imports.appendingPathComponent("1.2.4").path))
    }
}
