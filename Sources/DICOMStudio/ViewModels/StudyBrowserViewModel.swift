// StudyBrowserViewModel.swift
// DICOMStudio
//
// DICOM Studio — Study browser ViewModel

import Foundation
import Observation

/// ViewModel for the study browser view, managing display, sorting,
/// filtering, and search across the DICOM library.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
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
    }

    /// Returns the filtered and sorted studies for display.
    public var displayStudies: [StudyModel] {
        let filtered = StudyBrowserHelpers.filter(
            studies: library.sortedStudies,
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
        isImporting = true
        lastError = nil
        let existingUIDs = Set(library.instances.keys)

        let results = importService.importFiles(
            at: urls,
            existingInstanceUIDs: existingUIDs
        ) { [weak self] progress in
            self?.importProgress = progress
        }

        // Add successful results to the library
        for result in results where result.succeeded && !result.isDuplicate {
            if let study = result.study {
                library.addStudy(study)
            }
            if let series = result.series {
                library.addSeries(series)
            }
            if let instance = result.instance {
                library.addInstance(instance)
            }
        }

        isImporting = false

        // Auto-save after import
        do {
            try libraryStorageService.save(library)
        } catch {
            lastError = "Failed to save library: \(error.localizedDescription)"
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

    /// Handles file URLs selected via the file importer or drag-and-drop.
    ///
    /// Automatically detects DICOMDIR files and imports their referenced files,
    /// or directly imports the provided file URLs.
    ///
    /// - Parameter urls: The selected file URLs.
    public func handleImportedURLs(_ urls: [URL]) {
        var filesToImport: [URL] = []

        for url in urls {
            if DICOMDIRParser.isDICOMDIR(url: url) {
                // Scan directory for referenced files from DICOMDIR location
                let dirURL = url.deletingLastPathComponent()
                let scanned = importService.scanDirectory(at: dirURL, recursive: true)
                filesToImport.append(contentsOf: scanned)
            } else {
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDirectory {
                    let scanned = importService.scanDirectory(at: url, recursive: true)
                    filesToImport.append(contentsOf: scanned)
                } else {
                    filesToImport.append(url)
                }
            }
        }

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
