// StudyFileCleanup.swift
// DICOMStudio
//
// DICOM Studio — reclaiming a deleted study's managed files

import Foundation
import os.log

/// Logger for study cleanup diagnostics.
private let logger = Logger(subsystem: "com.dicomstudio", category: "StudyFileCleanup")

/// Deletes the files the app copied for a study when that study is removed
/// from the library.
///
/// Import copies every file into `Imports/<StudyInstanceUID>/` so the viewer
/// can read it without the original security scope. Removing the study from
/// the index alone left that folder orphaned: invisible to the browser, but
/// still holding full-size pixel data and patient identification. This is the
/// other half of the delete.
///
/// **Only app-managed files are ever deleted.** Every path is checked to be
/// inside the import directory before it is touched, so a library entry that
/// still points at a file the user picked in place — an import that predates
/// the copying behaviour, or a fixture opened from a source tree — is left
/// exactly where it is. Deleting a row from our index is never a licence to
/// delete somebody else's file.
/// `@unchecked Sendable`: the only mutable thing held is a `FileManager`,
/// which is not formally `Sendable` but is documented as safe to use from
/// multiple threads for the stateless file operations performed here.
public struct StudyFileCleanup: @unchecked Sendable {

    /// The directory imported copies live in.
    public let importDirectory: URL

    /// Where saved views for a study are filed, when the app has such a store.
    ///
    /// Kept optional because the presentation-state store lives in DICOMPrintKit
    /// and is built lazily; a cleanup with no store still reclaims the images.
    public let presentationStateRoot: URL?

    private let fileManager: FileManager

    /// Creates a cleanup rooted at the app's managed directories.
    ///
    /// - Parameters:
    ///   - importDirectory: The directory imported files are copied into.
    ///   - presentationStateRoot: Root of the saved-view store, if present.
    ///   - fileManager: Injectable for tests.
    public init(
        importDirectory: URL,
        presentationStateRoot: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.importDirectory = importDirectory
        self.presentationStateRoot = presentationStateRoot
        self.fileManager = fileManager
    }

    /// Creates a cleanup from a storage service, using its standard layout.
    public init(storageService: StorageService = StorageService()) {
        self.init(
            importDirectory: storageService.importDirectory,
            presentationStateRoot: storageService.baseDirectory
                .appendingPathComponent("PresentationStates", isDirectory: true))
    }

    // MARK: - Deleting one study

    /// What a cleanup managed to reclaim.
    public struct Outcome: Sendable, Equatable {

        /// Files removed from the import directory.
        public var filesDeleted: Int = 0

        /// Bytes those files occupied.
        public var bytesReclaimed: Int64 = 0

        /// Paths left alone because they sit outside the app's storage.
        public var externalPathsKept: [String] = []

        /// Whether the study's saved-view folder was removed.
        public var savedViewsDeleted: Bool = false
    }

    /// Removes every managed file belonging to one study.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The study being deleted.
    ///   - knownPaths: File paths the index held for the study. Used to spot
    ///     instances stored outside the managed folder, which are reported and
    ///     kept rather than deleted.
    /// - Returns: What was reclaimed.
    @discardableResult
    public func removeFiles(
        forStudy studyInstanceUID: String,
        knownPaths: [String] = []
    ) -> Outcome {
        var outcome = Outcome()

        // Anything the index pointed at that is not ours stays put, and is
        // reported so the caller can say so rather than silently doing nothing.
        for path in knownPaths where !isManaged(path) {
            outcome.externalPathsKept.append(path)
        }

        let studyDirectory = directory(forStudy: studyInstanceUID)
        if fileManager.fileExists(atPath: studyDirectory.path) {
            let (count, bytes) = measure(directory: studyDirectory)
            do {
                try fileManager.removeItem(at: studyDirectory)
                outcome.filesDeleted = count
                outcome.bytesReclaimed = bytes
                logger.info(
                    "removeFiles: reclaimed \(count) file(s), \(bytes) byte(s) for study \(studyInstanceUID, privacy: .private)")
            } catch {
                logger.error(
                    "removeFiles: could not remove study folder — \(error.localizedDescription)")
            }
        }

        // Saved views are a separate store keyed the same way. A study that is
        // gone must not leave views behind to reappear on a re-import.
        if let root = presentationStateRoot {
            let viewsDirectory = root.appendingPathComponent(
                studyInstanceUID, isDirectory: true)
            if fileManager.fileExists(atPath: viewsDirectory.path) {
                do {
                    try fileManager.removeItem(at: viewsDirectory)
                    outcome.savedViewsDeleted = true
                } catch {
                    logger.error(
                        "removeFiles: could not remove saved views — \(error.localizedDescription)")
                }
            }
        }

        return outcome
    }

    // MARK: - Reclaiming orphans

    /// Deletes managed study folders that the library no longer lists.
    ///
    /// Studies deleted before the delete path reclaimed its files left folders
    /// behind that nothing references and no screen can reach. This is the
    /// one-time sweep for them; it is driven by the set of UIDs the library
    /// still holds, so a folder is only removed when the index positively does
    /// not know about it.
    ///
    /// - Parameter knownStudyUIDs: Every study UID the library currently holds.
    /// - Returns: What was reclaimed, plus the UIDs swept.
    @discardableResult
    public func removeOrphanedStudies(
        knownStudyUIDs: Set<String>
    ) -> (outcome: Outcome, studyUIDs: [String]) {
        var outcome = Outcome()
        var swept: [String] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: importDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return (outcome, swept)
        }

        for entry in contents {
            let uid = entry.lastPathComponent
            // Only directories named as study UIDs, and only ones the library
            // has never heard of. A stray file at the top level is not ours to
            // interpret, so it is left alone.
            guard !knownStudyUIDs.contains(uid),
                  (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            else { continue }

            let (count, bytes) = measure(directory: entry)
            do {
                try fileManager.removeItem(at: entry)
                outcome.filesDeleted += count
                outcome.bytesReclaimed += bytes
                swept.append(uid)
            } catch {
                logger.error(
                    "removeOrphanedStudies: could not remove \(uid, privacy: .private) — \(error.localizedDescription)")
            }
        }

        if !swept.isEmpty {
            logger.info(
                "removeOrphanedStudies: swept \(swept.count) folder(s), \(outcome.bytesReclaimed) byte(s)")
        }
        return (outcome, swept)
    }

    /// Totals the orphaned folders without deleting anything, so the app can
    /// say how much a sweep would reclaim before the user agrees to it.
    public func orphanedStudySize(
        knownStudyUIDs: Set<String>
    ) -> (folders: Int, bytes: Int64) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: importDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return (0, 0)
        }
        var folders = 0
        var bytes: Int64 = 0
        for entry in contents {
            guard !knownStudyUIDs.contains(entry.lastPathComponent),
                  (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            else { continue }
            folders += 1
            bytes += measure(directory: entry).bytes
        }
        return (folders, bytes)
    }

    // MARK: - Layout

    /// The managed folder holding one study's files.
    public func directory(forStudy studyInstanceUID: String) -> URL {
        importDirectory.appendingPathComponent(studyInstanceUID, isDirectory: true)
    }

    /// Whether a path sits inside the app's import directory.
    ///
    /// Compared on standardised paths with a trailing separator, so that a
    /// sibling directory whose name merely begins with the same characters
    /// cannot be mistaken for a child of ours.
    public func isManaged(_ path: String) -> Bool {
        let root = importDirectory.standardizedFileURL.path
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.path
        return candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    // MARK: - Private

    /// Counts the files in a directory and the bytes they hold.
    private func measure(directory: URL) -> (count: Int, bytes: Int64) {
        guard let enumerator = fileManager.enumerator(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return (0, 0) }
        var count = 0
        var bytes: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            count += 1
            bytes += Int64(values?.fileSize ?? 0)
        }
        return (count, bytes)
    }
}
