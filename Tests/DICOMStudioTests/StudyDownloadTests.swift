// StudyDownloadTests.swift
// DICOMStudioTests
//
// Downloading a study as one ZIP.
//
// The property under test is the promise the confirmation prompt makes: the
// size it states is the size of the file that will be written, because the
// archive is built first and measured, not estimated. So the builder must
// actually produce a ZIP, count what went in, and leave nothing behind but
// that one file.

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Study Download Tests")
struct StudyDownloadTests {

    /// A throwaway directory of fake DICOM files, one per name given.
    private func makeFiles(_ names: [String], bytes: Int = 64) throws -> (dir: URL, paths: [String]) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyDownloadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for name in names {
            let url = dir.appendingPathComponent(name)
            try Data(repeating: 0xAB, count: bytes).write(to: url)
            paths.append(url.path)
        }
        return (dir, paths)
    }

    @Test("The builder produces one ZIP whose measured size is the file's real size")
    func zipSizeIsReal() throws {
        let (dir, paths) = try makeFiles(["a.dcm", "b.dcm", "c.dcm"], bytes: 4096)
        defer { try? FileManager.default.removeItem(at: dir) }

        let built = try ImageViewerViewModel.buildStudyArchive(
            studyInstanceUID: "1.2.3.4.5",
            series: [.init(folderName: "S1 — Test", filePaths: paths)],
            presentationStateURLs: [])
        defer { try? FileManager.default.removeItem(at: built.zipURL.deletingLastPathComponent()) }

        #expect(built.imageCount == 3)
        #expect(built.stateCount == 0)
        #expect(FileManager.default.fileExists(atPath: built.zipURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: built.zipURL.path)
        let onDisk = (attributes[.size] as? Int64) ?? -1
        #expect(built.sizeBytes == onDisk)
        #expect(built.sizeBytes > 0)
    }

    @Test("Presentation states ride along and are counted separately")
    func statesAreIncluded() throws {
        let (imageDir, imagePaths) = try makeFiles(["img.dcm"])
        defer { try? FileManager.default.removeItem(at: imageDir) }
        let (stateDir, statePaths) = try makeFiles(["view1.dcm", "view2.dcm"])
        defer { try? FileManager.default.removeItem(at: stateDir) }

        let built = try ImageViewerViewModel.buildStudyArchive(
            studyInstanceUID: "1.2.3.4.5",
            series: [.init(folderName: "S1", filePaths: imagePaths)],
            presentationStateURLs: statePaths.map { URL(fileURLWithPath: $0) })
        defer { try? FileManager.default.removeItem(at: built.zipURL.deletingLastPathComponent()) }

        #expect(built.imageCount == 1)
        #expect(built.stateCount == 2)
    }

    @Test("Colliding basenames across a series are suffixed, not overwritten")
    func collisionsAreSuffixed() throws {
        // Two source folders each holding an "image.dcm", staged into the
        // same series folder — both must survive into the archive's count.
        let (dirA, pathsA) = try makeFiles(["image.dcm"])
        defer { try? FileManager.default.removeItem(at: dirA) }
        let (dirB, pathsB) = try makeFiles(["image.dcm"])
        defer { try? FileManager.default.removeItem(at: dirB) }

        let built = try ImageViewerViewModel.buildStudyArchive(
            studyInstanceUID: "1.2.3.4.5",
            series: [.init(folderName: "S1", filePaths: pathsA + pathsB)],
            presentationStateURLs: [])
        defer { try? FileManager.default.removeItem(at: built.zipURL.deletingLastPathComponent()) }

        #expect(built.imageCount == 2)
    }

    @Test("A file the library lists but that is gone is skipped, not fatal")
    func missingFilesAreSkipped() throws {
        // The library indexes paths; a published saved view that was later
        // superseded, or a study folder tidied outside the app, leaves an
        // entry pointing at a file that no longer exists. The download must
        // still produce an archive of everything that *is* there.
        let (dir, paths) = try makeFiles(["a.dcm", "b.dcm"])
        defer { try? FileManager.default.removeItem(at: dir) }
        let ghost = dir.appendingPathComponent("gone.dcm").path

        let built = try ImageViewerViewModel.buildStudyArchive(
            studyInstanceUID: "1.2.3.4.5",
            series: [.init(folderName: "S1", filePaths: paths + [ghost])],
            presentationStateURLs: [dir.appendingPathComponent("noview.dcm")])
        defer { try? FileManager.default.removeItem(at: built.zipURL.deletingLastPathComponent()) }

        #expect(built.imageCount == 2)
        #expect(built.stateCount == 0)
        #expect(built.missingCount == 2)
        #expect(FileManager.default.fileExists(atPath: built.zipURL.path))
    }

    @Test("A study whose every file has vanished fails rather than zipping nothing")
    func nothingToArchiveThrows() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyDownloadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(throws: ImageViewerViewModel.StudyDownloadFailure.self) {
            _ = try ImageViewerViewModel.buildStudyArchive(
                studyInstanceUID: "1.2.3.4.5",
                series: [.init(folderName: "S1",
                               filePaths: [dir.appendingPathComponent("gone.dcm").path])],
                presentationStateURLs: [])
        }
    }

    @Test("A series description with path separators cannot escape the staging folder")
    func folderNamesAreCleaned() {
        let entry = ViewerSeriesEntry(
            seriesInstanceUID: "1.2.3",
            title: "AX/T1: post",
            seriesNumber: 2,
            filePaths: ["/tmp/x.dcm"],
            frameCount: 1)
        let name = ImageViewerViewModel.seriesFolderName(for: entry)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(name.hasPrefix("S2"))
    }
}
