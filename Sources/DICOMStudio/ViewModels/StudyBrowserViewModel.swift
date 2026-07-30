// StudyBrowserViewModel.swift
// DICOMStudio
//
// DICOM Studio — Study browser ViewModel

import Foundation
import Observation
import os.log

/// Logger for study browser ViewModel diagnostics.
private let logger = Logger(subsystem: "com.dicomstudio", category: "StudyBrowser")

/// ViewModel for the study browser view, managing display, sorting,
/// filtering, and search across the DICOM library.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class StudyBrowserViewModel {

    /// The library model being browsed.
    public var library: LibraryModel

    /// Current filter criteria.
    public var filter: LibraryFilter

    /// Current sort field.
    public var sortField: StudySortField

    /// Current sort direction.
    public var sortDirection: SortDirection

    /// Current display mode (list or grid).
    public var displayMode: BrowseDisplayMode

    /// Currently selected study UID.
    public var selectedStudyUID: String?

    /// Currently selected series UID.
    public var selectedSeriesUID: String?

    /// The import service.
    public let importService: ImportService

    /// The library storage service.
    public let libraryStorageService: LibraryStorageService

    /// Current import progress, if importing.
    public var importProgress: ImportProgress?

    /// Whether an import is in progress.
    public var isImporting: Bool

    /// Last import error message.
    public var lastError: String?

    /// Whether the file importer dialog is presented.
    public var isFileImporterPresented: Bool

    /// Callback invoked when the user requests to open a file in the viewer.
    /// The parameter is the file path of the instance to view.
    public var onOpenInViewer: ((String) -> Void)?

    /// Callback invoked when the user requests to open a series in the viewer.
    /// Parameters: ordered file paths, index of the file to show first.
    /// When set, this takes priority over `onOpenInViewer` for study/series opens.
    public var onOpenSeriesInViewer: (([String], Int) -> Void)?

    /// Callback invoked when the user requests to print a study or series.
    ///
    /// The parameter is the ordered file paths to mark for print. Printing a
    /// whole study or series from here skips the mark-in-the-viewer step.
    public var onPrintFiles: (([String]) -> Void)?

    /// Creates a study browser ViewModel.
    public init(
        library: LibraryModel = LibraryModel(),
        importService: ImportService = ImportService(),
        libraryStorageService: LibraryStorageService = LibraryStorageService()
    ) {
        self.library = library
        self.importService = importService
        self.libraryStorageService = libraryStorageService
        self.filter = .none
        self.sortField = .date
        self.sortDirection = .descending
        self.displayMode = .list
        self.selectedStudyUID = nil
        self.selectedSeriesUID = nil
        self.importProgress = nil
        self.isImporting = false
        self.lastError = nil
        self.isFileImporterPresented = false
        self.onOpenInViewer = nil
        self.onOpenSeriesInViewer = nil
        self.onPrintFiles = nil
    }

    /// Returns the filtered and sorted studies for display.
    ///
    /// Studies with no instances under them are left out: they cannot be opened,
    /// printed or exported, and a row reading "0 series · 0 images" for a patient
    /// the library cannot show is worse than no row. Reading rather than deleting
    /// keeps a stored index intact — a library whose files are on a volume that
    /// is not mounted today is not a library to start throwing away.
    public var displayStudies: [StudyModel] {
        let withContent = library.sortedStudies.filter {
            library.instanceCount(forStudy: $0.studyInstanceUID) > 0
        }
        let filtered = StudyBrowserHelpers.filter(
            studies: withContent,
            with: filter
        )
        return StudyBrowserHelpers.sort(
            studies: filtered,
            by: sortField,
            direction: sortDirection
        )
    }

    /// Returns the series for the currently selected study.
    public var selectedStudySeries: [SeriesModel] {
        guard let uid = selectedStudyUID else { return [] }
        return library.seriesForStudy(uid)
    }

    /// Returns the instances for the currently selected series.
    public var selectedSeriesInstances: [InstanceModel] {
        guard let uid = selectedSeriesUID else { return [] }
        return library.instancesForSeries(uid)
    }

    /// Returns all unique modalities in the library for filter UI.
    public var availableModalities: [String] {
        StudyBrowserHelpers.uniqueModalities(in: Array(library.studies.values))
    }

    /// Imports files from the given URLs.
    ///
    /// - Parameter urls: File URLs to import.
    public func importFiles(from urls: [URL]) {
        logger.info("importFiles: starting import of \(urls.count) file(s)")
        isImporting = true
        lastError = nil
        let existingUIDs = Set(library.instances.keys)

        let results = importService.importFiles(
            at: urls,
            existingInstanceUIDs: existingUIDs
        ) { [weak self] progress in
            self?.importProgress = progress
        }

        // Build up a local copy of the library and apply all changes
        // at once.  This ensures SwiftUI sees a single @Observable
        // mutation (the final assignment) instead of dozens of
        // individual addStudy/addSeries/addInstance calls, which
        // guarantees a clean UI refresh.
        var updatedLibrary = library
        var importedCount = 0
        var updatedCount = 0
        for result in results where result.succeeded {
            if let study = result.study {
                updatedLibrary.addStudy(study)
            }
            if let series = result.series {
                updatedLibrary.addSeries(series)
            }
            if let instance = result.instance {
                updatedLibrary.addInstance(instance)
            }
            if result.isDuplicate {
                updatedCount += 1
            } else {
                importedCount += 1
            }
        }

        // A file that produced a study but no instances leaves a row that can
        // never be opened; it is not worth showing.
        updatedLibrary.pruneEmptyStudies()

        // Single atomic assignment — triggers one @Observable change.
        library = updatedLibrary
        isImporting = false

        // Report failures so the user can see what went wrong.
        let failedResults = results.filter { !$0.succeeded }
        let duplicateCount = results.filter { $0.isDuplicate }.count
        logger.info("importFiles: done — imported=\(importedCount), updated=\(updatedCount), failed=\(failedResults.count), duplicates=\(duplicateCount)")
        if !failedResults.isEmpty {
            let firstError = failedResults.first?.validationIssues
                .first(where: { $0.severity == .error })?.message ?? "Unknown error"
            lastError = "\(failedResults.count) of \(urls.count) files failed to import. \(firstError)"
        } else if importedCount == 0 && updatedCount == 0 && duplicateCount == 0 && !urls.isEmpty {
            lastError = "No valid DICOM files found in the selected location."
        }

        // Auto-save after import or update
        if importedCount > 0 || updatedCount > 0 {
            do {
                try libraryStorageService.save(library)
            } catch {
                lastError = "Failed to save library: \(error.localizedDescription)"
            }
        }
    }

    /// Removes a study from the library.
    ///
    /// - Parameter studyUID: The Study Instance UID to remove.
    public func removeStudy(_ studyUID: String) {
        library.removeStudy(studyUID)
        if selectedStudyUID == studyUID {
            selectedStudyUID = nil
            selectedSeriesUID = nil
        }
        do {
            try libraryStorageService.save(library)
        } catch {
            lastError = "Failed to save library: \(error.localizedDescription)"
        }
    }

    /// Removes every imported study from the library.
    ///
    /// Only the library index is discarded — the imported files themselves stay
    /// where they are on disk, exactly as `removeStudy(_:)` leaves them.
    public func removeAllStudies() {
        logger.info("removeAllStudies: clearing \(self.library.studyCount) study/studies from library")
        library.clear()
        selectedStudyUID = nil
        selectedSeriesUID = nil
        do {
            try libraryStorageService.save(library)
        } catch {
            lastError = "Failed to save library: \(error.localizedDescription)"
        }
    }

    /// Clears all filters.
    public func clearFilters() {
        filter = .none
    }

    /// Toggles a modality in the filter.
    ///
    /// - Parameter modality: The modality code to toggle.
    public func toggleModalityFilter(_ modality: String) {
        if filter.modalities.contains(modality) {
            filter.modalities.remove(modality)
        } else {
            filter.modalities.insert(modality)
        }
    }

    /// Toggles the sort direction.
    public func toggleSortDirection() {
        sortDirection = sortDirection.toggled
    }

    /// Toggles the display mode.
    public func toggleDisplayMode() {
        displayMode = displayMode == .list ? .grid : .list
    }

    /// Loads the library from persistent storage.
    public func loadLibrary() {
        library = libraryStorageService.load()
    }

    /// Saves the library to persistent storage.
    public func saveLibrary() {
        do {
            try libraryStorageService.save(library)
        } catch {
            lastError = "Failed to save library: \(error.localizedDescription)"
        }
    }

    /// Presents the file importer dialog.
    public func showFileImporter() {
        isFileImporterPresented = true
    }

    /// Opens a study in the image viewer, on the first image of its first series.
    ///
    /// The viewer is handed *one series* rather than every instance of the study
    /// flattened into a single list. The flat list made the arrow keys walk out
    /// of one series and into the next, and put the study's whole object count
    /// behind a scroll wheel; the series pane is what moves between series.
    /// Which series comes first, and which image within it, is decided by Series
    /// Number and Instance Number — the order the study itself asserts.
    /// - Parameter studyUID: The Study Instance UID to open.
    public func openStudyInViewer(_ studyUID: String) {
        let seriesList = library.seriesForStudy(studyUID)
            .sorted { ($0.seriesNumber ?? Int.max) < ($1.seriesNumber ?? Int.max) }
        guard let first = seriesList.first(where: {
            !library.instancesForSeries($0.seriesInstanceUID).isEmpty
        }) else { return }

        let paths = library.instancesForSeries(first.seriesInstanceUID).map(\.filePath)
        if let callback = onOpenSeriesInViewer {
            callback(paths, 0)
        } else {
            onOpenInViewer?(paths[0])
        }
    }

    /// Opens all instances of a specific series in the image viewer.
    ///
    /// - Parameters:
    ///   - seriesUID: The Series Instance UID to open.
    ///   - startIndex: Index of the instance to show first (default 0).
    public func openSeriesInViewer(_ seriesUID: String, startIndex: Int = 0) {
        let instances = library.instancesForSeries(seriesUID)
        let paths = instances.map(\.filePath)
        guard !paths.isEmpty else { return }
        let idx = max(0, min(startIndex, paths.count - 1))
        if let callback = onOpenSeriesInViewer {
            callback(paths, idx)
        } else {
            onOpenInViewer?(paths[idx])
        }
    }

    /// Marks every instance of a study for printing and opens the print sheet.
    ///
    /// - Parameter studyUID: The Study Instance UID to print.
    public func printStudy(_ studyUID: String) {
        var allPaths: [String] = []
        for series in library.seriesForStudy(studyUID) {
            allPaths.append(contentsOf: library.instancesForSeries(series.seriesInstanceUID).map(\.filePath))
        }
        guard !allPaths.isEmpty else { return }
        onPrintFiles?(allPaths)
    }

    /// Marks every instance of a series for printing and opens the print sheet.
    ///
    /// - Parameter seriesUID: The Series Instance UID to print.
    public func printSeries(_ seriesUID: String) {
        let paths = library.instancesForSeries(seriesUID).map(\.filePath)
        guard !paths.isEmpty else { return }
        onPrintFiles?(paths)
    }

    /// Handles file URLs selected via the file importer or drag-and-drop.
    ///
    /// Automatically detects DICOMDIR files and imports their referenced files,
    /// or directly imports the provided file URLs.
    ///
    /// Acquires security-scoped resource access on every incoming URL so that
    /// sandbox-protected locations (e.g. ~/Downloads) can be read, and keeps
    /// parent-directory scopes alive through the entire import.
    ///
    /// - Parameter urls: The selected file URLs.
    public func handleImportedURLs(_ urls: [URL]) {
        logger.info("handleImportedURLs: received \(urls.count) URL(s)")
        // Track security-scoped accesses so we can release them *after*
        // all child-file imports complete.  Child URLs enumerated from a
        // security-scoped directory inherit the parent's scope, so we must
        // NOT release the parent scope until we're fully done.
        var accessedURLs: [(url: URL, accessed: Bool)] = []
        defer {
            for entry in accessedURLs.reversed() where entry.accessed {
                entry.url.stopAccessingSecurityScopedResource()
            }
        }

        var filesToImport: [URL] = []

        for url in urls {
            // Gain sandbox access to each top-level URL *before* any I/O.
            let accessed = url.startAccessingSecurityScopedResource()
            accessedURLs.append((url: url, accessed: accessed))
            logger.info("  URL: \(url.path) — securityScope=\(accessed)")

            if DICOMDIRParser.isDICOMDIR(url: url) {
                logger.info("  Detected DICOMDIR — scanning parent directory recursively")
                let mediaRoot = url.deletingLastPathComponent()
                let scanned = importService.scanDirectory(at: mediaRoot, recursive: true)
                filesToImport.append(contentsOf: scanned)
            } else {
                // Use URL-based resource values — never convert to .path first,
                // as that can lose the security-scoped bookmark.
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                logger.info("  isDirectory=\(isDir)")
                if isDir {
                    let scanned = importService.scanDirectory(at: url, recursive: true)
                    filesToImport.append(contentsOf: scanned)
                } else {
                    filesToImport.append(url)
                }
            }
        }

        logger.info("handleImportedURLs: \(filesToImport.count) total files to import")

        if !filesToImport.isEmpty {
            importFiles(from: filesToImport)
        }
    }

    /// Toggles the favorite status of a study.
    ///
    /// - Parameter studyUID: The Study Instance UID to toggle.
    public func toggleFavorite(_ studyUID: String) {
        library.toggleFavorite(studyUID)
        saveLibrary()
    }

    /// Returns whether a study is marked as favorite.
    ///
    /// - Parameter studyUID: The Study Instance UID to check.
    /// - Returns: `true` if the study is a favorite.
    public func isFavorite(_ studyUID: String) -> Bool {
        library.studies[studyUID]?.isFavorite ?? false
    }
}
