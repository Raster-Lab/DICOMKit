// ImageViewerViewModel+StudyDownload.swift
// DICOMStudio
//
// Downloading the open study as one ZIP — the images with their saved
// presentation states.
//
// The order of events is deliberate: the archive is built *first*, into a
// temporary directory, and only then is the reader asked. That way the prompt
// can state the ZIP's exact size — not an estimate from adding up file sizes,
// which compression would falsify — and declining costs nothing but the
// temporary file. Confirming moves the finished archive to wherever the
// reader chooses; nothing is written outside the temporary directory until
// they have said yes.

import Foundation
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension ImageViewerViewModel {

    // MARK: - The prompt

    /// The question asked before a study leaves the app as a ZIP.
    ///
    /// Carries the finished archive rather than a plan for one: the size shown
    /// is the size of the file that will actually be written, and confirming
    /// is a move, not a rebuild that could come out different.
    public struct StudyDownloadPrompt: Identifiable, Equatable, Sendable {

        /// The study the archive holds.
        public let studyInstanceUID: String

        /// The finished ZIP, waiting in a temporary directory.
        public let zipURL: URL

        /// Its exact size on disk, in bytes.
        public let zipSizeBytes: Int64

        /// DICOM objects from the study's series.
        public let imageCount: Int

        /// Saved presentation states included beside them.
        public let presentationStateCount: Int

        /// Files the library still lists but that are no longer on disk.
        ///
        /// A study whose folder has been tidied, or whose published saved view
        /// was superseded, leaves index entries pointing at files that were
        /// removed. Those are skipped rather than failing the download — but
        /// the prompt says how many, because an archive quietly missing images
        /// is worse than one that admits it.
        public let missingFileCount: Int

        public var id: String { studyInstanceUID }

        /// "245.3 MB" — the size as the prompt states it.
        public var zipSizeLabel: String {
            ByteCountFormatter.string(fromByteCount: zipSizeBytes, countStyle: .file)
        }

        /// What the prompt says the archive holds.
        public var contentsLabel: String {
            let images = "\(imageCount) image\(imageCount == 1 ? "" : "s")"
            guard presentationStateCount > 0 else { return images }
            let states = "\(presentationStateCount) presentation "
                + "state\(presentationStateCount == 1 ? "" : "s")"
            return "\(images) and \(states)"
        }

        /// The sentence about skipped files, or empty when nothing was skipped.
        public var missingFilesLabel: String {
            guard missingFileCount > 0 else { return "" }
            return "\(missingFileCount) file\(missingFileCount == 1 ? " is" : "s are") "
                + "listed for this study but no longer on disk and "
                + "\(missingFileCount == 1 ? "was" : "were") left out."
        }
    }

    /// Whether there is a single study on screen to download.
    ///
    /// False for loose files: they have no Study Instance UID to gather by,
    /// and "download the study" would have to guess what the study even is.
    public var canDownloadStudy: Bool {
        studyInstanceUID != nil && studySeries.contains { !$0.filePaths.isEmpty }
    }

    // MARK: - Preparing

    /// Builds the study's ZIP and raises the confirmation prompt.
    ///
    /// Gathers every file of every series in ``studySeries`` plus the saved
    /// presentation states (GSPS objects) kept for the study, stages them into
    /// a temporary folder — one subfolder per series, one for the states —
    /// compresses the folder, and sets ``studyDownloadPrompt`` with the exact
    /// result. Nothing is shown or written elsewhere until the reader confirms.
    public func prepareStudyDownload() async {
        guard !isPreparingStudyDownload else { return }
        guard let studyInstanceUID, canDownloadStudy else { return }

        // A prompt already up is the same question; don't build a second ZIP
        // behind it.
        guard studyDownloadPrompt == nil else { return }

        isPreparingStudyDownload = true
        studyDownloadError = nil
        defer { isPreparingStudyDownload = false }

        // What goes in, gathered on the main actor where the model lives.
        let seriesToStage: [StagedSeries] = studySeries
            .filter { !$0.filePaths.isEmpty }
            .map { entry in
                StagedSeries(folderName: Self.seriesFolderName(for: entry),
                             filePaths: entry.filePaths)
            }

        // The saved views' GSPS objects. Views published into the study are
        // already among the series files above; these are the ones that so far
        // live only in the app's own store.
        let stateURLs: [URL] = presentationStateStore
            .map { store in
                store.views(forStudy: studyInstanceUID)
                    .flatMap(\.states)
                    .map(\.url)
            } ?? []

        let uid = studyInstanceUID
        do {
            let built = try await Task.detached(priority: .userInitiated) {
                try Self.buildStudyArchive(studyInstanceUID: uid,
                                           series: seriesToStage,
                                           presentationStateURLs: stateURLs)
            }.value

            // The study may have changed under the build — a new study opened,
            // the viewer cleared. A prompt about the old one would be a lie.
            guard self.studyInstanceUID == uid else {
                try? FileManager.default.removeItem(at: built.zipURL)
                return
            }
            studyDownloadPrompt = StudyDownloadPrompt(
                studyInstanceUID: uid,
                zipURL: built.zipURL,
                zipSizeBytes: built.sizeBytes,
                imageCount: built.imageCount,
                presentationStateCount: built.stateCount,
                missingFileCount: built.missingCount)
        } catch {
            studyDownloadError =
                "Could not prepare the study for download: \(error.localizedDescription)"
        }
    }

    /// The reader said no, or the save failed: the temporary ZIP goes, and the
    /// prompt with it.
    public func cancelStudyDownload() {
        if let prompt = studyDownloadPrompt {
            try? FileManager.default.removeItem(at: prompt.zipURL)
        }
        studyDownloadPrompt = nil
    }

    /// The ZIP has been moved to where the reader chose; only the prompt is
    /// left to clear. The temporary file is gone — the move took it.
    public func finishStudyDownload() {
        studyDownloadPrompt = nil
    }

    /// Clears whatever ``studyDownloadError`` was showing.
    public func dismissStudyDownloadError() {
        studyDownloadError = nil
    }

    // MARK: - Building the archive

    /// Why an archive could not be built, in words a reader can act on.
    enum StudyDownloadFailure: LocalizedError {

        /// The library listed files for the study, but none of them are still
        /// on disk — the study's folder has moved or been emptied.
        case nothingToArchive

        var errorDescription: String? {
            switch self {
            case .nothingToArchive:
                return "None of this study's files are still on disk. "
                    + "Re-import the study and try again."
            }
        }
    }

    /// One series as the staging pass needs it: a folder name and the files
    /// that go in it. `Sendable` so the build can leave the main actor.
    struct StagedSeries: Sendable {
        let folderName: String
        let filePaths: [String]
    }

    /// What came out of the build.
    struct BuiltStudyArchive: Sendable {
        let zipURL: URL
        let sizeBytes: Int64
        let imageCount: Int
        let stateCount: Int
        let missingCount: Int
    }

    /// "S3 — Axial Brain" — the subfolder one series' files land in, cleaned
    /// of path separators so a description cannot escape the staging folder.
    nonisolated static func seriesFolderName(for entry: ViewerSeriesEntry) -> String {
        let number = entry.seriesNumber.map { "S\($0) — " } ?? ""
        let cleaned = (number + entry.title)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? entry.seriesInstanceUID : cleaned
    }

    /// Stages the study into a temporary folder and compresses it.
    ///
    /// Copies rather than links: the archive must not change if the reader
    /// keeps working while the prompt is up. The ZIP itself comes from
    /// `NSFileCoordinator`'s `.forUploading` read, which is Foundation's own
    /// way of producing one and works the same on macOS and iOS.
    nonisolated static func buildStudyArchive(
        studyInstanceUID: String,
        series: [StagedSeries],
        presentationStateURLs: [URL]
    ) throws -> BuiltStudyArchive {
        let fileManager = FileManager.default

        // Everything happens under one disposable root, so cleanup — on
        // failure here, or on cancel later — is a single remove.
        let workRoot = fileManager.temporaryDirectory
            .appendingPathComponent("StudyDownload-\(UUID().uuidString)",
                                    isDirectory: true)
        // The folder that becomes the ZIP, named for the study. The tail of
        // the UID keeps siblings apart without a 64-character filename.
        let archiveName = "Study-\(studyInstanceUID.suffix(12))"
        let stagingRoot = workRoot
            .appendingPathComponent(archiveName, isDirectory: true)

        func cleanupAndRethrow(_ error: Error) throws -> Never {
            try? fileManager.removeItem(at: workRoot)
            throw error
        }

        do {
            try fileManager.createDirectory(at: stagingRoot,
                                            withIntermediateDirectories: true)
        } catch { try cleanupAndRethrow(error) }

        var imageCount = 0
        var stateCount = 0
        var missingCount = 0

        do {
            // The series, each into its own folder. Basenames are kept —
            // they are what the files were imported as — and a collision
            // within a folder gets a numeric suffix rather than a silent
            // overwrite.
            for entry in series {
                let seriesDir = stagingRoot
                    .appendingPathComponent(entry.folderName, isDirectory: true)
                try fileManager.createDirectory(at: seriesDir,
                                                withIntermediateDirectories: true)
                var taken = Set<String>()
                for path in entry.filePaths {
                    let source = URL(fileURLWithPath: path)
                    // The library indexes paths, not the files themselves: a
                    // study folder tidied outside the app, or a published saved
                    // view superseded by a re-publish, leaves entries pointing
                    // at files that are gone. One of those must not cost the
                    // reader the whole download — it is counted and skipped.
                    guard fileManager.fileExists(atPath: source.path) else {
                        missingCount += 1
                        continue
                    }
                    let name = Self.availableName(source.lastPathComponent,
                                                  taken: &taken)
                    try fileManager.copyItem(
                        at: source,
                        to: seriesDir.appendingPathComponent(name))
                    imageCount += 1
                }
            }

            // The saved views beside them, under one folder: they are DICOM
            // objects like the rest, and another viewer can apply them.
            if !presentationStateURLs.isEmpty {
                let statesDir = stagingRoot
                    .appendingPathComponent("Presentation States",
                                            isDirectory: true)
                try fileManager.createDirectory(at: statesDir,
                                                withIntermediateDirectories: true)
                var taken = Set<String>()
                for url in presentationStateURLs {
                    guard fileManager.fileExists(atPath: url.path) else {
                        missingCount += 1
                        continue
                    }
                    let name = Self.availableName(url.lastPathComponent,
                                                  taken: &taken)
                    try fileManager.copyItem(
                        at: url,
                        to: statesDir.appendingPathComponent(name))
                    stateCount += 1
                }
            }
        } catch { try cleanupAndRethrow(error) }

        // Every file the library listed has gone missing: there is nothing to
        // download, and an empty ZIP would be a worse answer than saying so.
        guard imageCount + stateCount > 0 else {
            try cleanupAndRethrow(StudyDownloadFailure.nothingToArchive)
        }

        // Compress. `.forUploading` hands the closure a zipped copy that only
        // lives for the closure's duration, so it is moved out to a name of
        // our own before the coordinator reclaims it.
        let zipURL = workRoot.appendingPathComponent("\(archiveName).zip")
        var coordinationError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: stagingRoot,
                               options: .forUploading,
                               error: &coordinationError) { zippedURL in
            do {
                try fileManager.moveItem(at: zippedURL, to: zipURL)
            } catch {
                moveError = error
            }
        }
        if let error = coordinationError ?? moveError.map({ $0 as NSError }) {
            try cleanupAndRethrow(error)
        }

        // The staging copies have served their purpose; only the ZIP stays.
        try? fileManager.removeItem(at: stagingRoot)

        let sizeBytes: Int64
        do {
            let attributes = try fileManager.attributesOfItem(atPath: zipURL.path)
            sizeBytes = (attributes[.size] as? Int64)
                ?? Int64((attributes[.size] as? Int) ?? 0)
        } catch { try cleanupAndRethrow(error) }

        return BuiltStudyArchive(zipURL: zipURL,
                                 sizeBytes: sizeBytes,
                                 imageCount: imageCount,
                                 stateCount: stateCount,
                                 missingCount: missingCount)
    }

    /// `name`, or `name 2`, `name 3`… — the first not yet taken in the folder.
    private nonisolated static func availableName(
        _ name: String, taken: inout Set<String>
    ) -> String {
        var candidate = name
        var counter = 2
        while taken.contains(candidate.lowercased()) {
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        taken.insert(candidate.lowercased())
        return candidate
    }
}
