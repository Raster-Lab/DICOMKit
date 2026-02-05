// LibraryViewModel.swift
// DICOMViewer iOS - Library View Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftUI
import SwiftData

/// View model for the study library
///
/// Manages study list, search, filtering, and file import operations.
@MainActor
@Observable
final class LibraryViewModel {
    // MARK: - Published State
    
    /// All studies in the library
    var studies: [DICOMStudy] = []
    
    /// Filtered studies based on search and filter criteria
    var filteredStudies: [DICOMStudy] = []
    
    /// Current search text
    var searchText: String = "" {
        didSet { applyFilters() }
    }
    
    /// Selected modality filter (nil = all modalities)
    var selectedModality: String? = nil {
        didSet { applyFilters() }
    }
    
    /// Available modalities in the library
    var availableModalities: [String] = []
    
    /// Loading state
    var isLoading: Bool = false
    
    /// Error message (if any)
    var errorMessage: String?
    
    /// Import progress (0.0 - 1.0)
    var importProgress: Double = 0.0
    
    /// Whether import is in progress
    var isImporting: Bool = false
    
    /// Whether file picker is shown
    var showingFilePicker: Bool = false
    
    /// Total storage used by the library
    var totalStorageSize: Int64 = 0
    
    // MARK: - Dependencies
    
    private let fileService = DICOMFileService.shared
    private let thumbnailService = ThumbnailService.shared
    
    // MARK: - Model Context
    
    var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Study Management
    
    /// Loads all studies from the database
    func loadStudies() async {
        guard let context = modelContext else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let descriptor = FetchDescriptor<DICOMStudy>(
                sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
            )
            studies = try context.fetch(descriptor)
            updateAvailableModalities()
            applyFilters()
            await calculateStorageSize()
        } catch {
            errorMessage = "Failed to load studies: \(error.localizedDescription)"
        }
    }
    
    /// Imports DICOM files from URLs
    func importFiles(_ urls: [URL]) async {
        guard let context = modelContext else { return }
        
        isImporting = true
        importProgress = 0.0
        errorMessage = nil
        
        defer {
            isImporting = false
            importProgress = 0.0
        }
        
        var processedCount = 0
        let totalCount = urls.count
        
        // Group files by study
        var studyGroups: [String: [(URL, DICOMMetadata)]] = [:]
        
        for url in urls {
            do {
                // Start secure access
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Read metadata
                let metadata = try await fileService.readMetadata(at: url)
                
                // Import file
                let importedURL = try await fileService.importFile(from: url)
                
                // Update metadata with new path
                let updatedMetadata = metadata.withFilePath(importedURL.path)
                
                // Group by study UID
                if studyGroups[metadata.studyInstanceUID] == nil {
                    studyGroups[metadata.studyInstanceUID] = []
                }
                studyGroups[metadata.studyInstanceUID]?.append((importedURL, updatedMetadata))
                
            } catch {
                errorMessage = "Failed to import \(url.lastPathComponent): \(error.localizedDescription)"
            }
            
            processedCount += 1
            importProgress = Double(processedCount) / Double(totalCount)
        }
        
        // Create study records
        for (studyUID, files) in studyGroups {
            await createOrUpdateStudy(studyUID: studyUID, files: files, context: context)
        }
        
        // Save and reload
        do {
            try context.save()
            await loadStudies()
        } catch {
            errorMessage = "Failed to save imported studies: \(error.localizedDescription)"
        }
    }
    
    /// Creates or updates a study from imported files
    private func createOrUpdateStudy(
        studyUID: String,
        files: [(URL, DICOMMetadata)],
        context: ModelContext
    ) async {
        guard let firstFile = files.first else { return }
        let metadata = firstFile.1
        
        // Check if study already exists
        let descriptor = FetchDescriptor<DICOMStudy>(
            predicate: #Predicate { $0.studyInstanceUID == studyUID }
        )
        
        let existingStudies = try? context.fetch(descriptor)
        let study: DICOMStudy
        
        if let existing = existingStudies?.first {
            study = existing
        } else {
            // Create new study
            study = DICOMStudy(
                studyInstanceUID: studyUID,
                patientName: metadata.patientName,
                patientID: metadata.patientID,
                patientBirthDate: metadata.patientBirthDate,
                patientSex: metadata.patientSex,
                studyDate: metadata.studyDate,
                studyDescription: metadata.studyDescription,
                accessionNumber: metadata.accessionNumber,
                storagePath: await fileService.libraryDirectory.path
            )
            context.insert(study)
        }
        
        // Group files by series
        var seriesGroups: [String: [(URL, DICOMMetadata)]] = [:]
        var modalities: Set<String> = Set(study.modalities)
        
        for file in files {
            let meta = file.1
            if seriesGroups[meta.seriesInstanceUID] == nil {
                seriesGroups[meta.seriesInstanceUID] = []
            }
            seriesGroups[meta.seriesInstanceUID]?.append(file)
            modalities.insert(meta.modality)
        }
        
        // Create series and instances
        var totalInstances = 0
        var totalSize: Int64 = 0
        
        for (seriesUID, seriesFiles) in seriesGroups {
            guard let firstSeriesFile = seriesFiles.first else { continue }
            let seriesMeta = firstSeriesFile.1
            
            // Check if series exists
            let seriesDescriptor = FetchDescriptor<DICOMSeries>(
                predicate: #Predicate { $0.seriesInstanceUID == seriesUID }
            )
            
            let existingSeries = try? context.fetch(seriesDescriptor)
            let series: DICOMSeries
            
            if let existing = existingSeries?.first {
                series = existing
            } else {
                series = DICOMSeries(
                    seriesInstanceUID: seriesUID,
                    seriesNumber: seriesMeta.seriesNumber,
                    seriesDescription: seriesMeta.seriesDescription,
                    modality: seriesMeta.modality,
                    imageRows: seriesMeta.rows,
                    imageColumns: seriesMeta.columns,
                    pixelSpacing: seriesMeta.pixelSpacing,
                    storagePath: await fileService.libraryDirectory.path
                )
                series.study = study
                context.insert(series)
            }
            
            // Create instances
            for (fileURL, instanceMeta) in seriesFiles {
                // Check if instance exists
                let instanceDescriptor = FetchDescriptor<DICOMInstance>(
                    predicate: #Predicate { $0.sopInstanceUID == instanceMeta.sopInstanceUID }
                )
                
                if let existingInstances = try? context.fetch(instanceDescriptor),
                   !existingInstances.isEmpty {
                    continue
                }
                
                let instance = DICOMInstance(
                    sopInstanceUID: instanceMeta.sopInstanceUID,
                    sopClassUID: instanceMeta.sopClassUID,
                    instanceNumber: instanceMeta.instanceNumber,
                    numberOfFrames: instanceMeta.numberOfFrames,
                    imageRows: instanceMeta.rows,
                    imageColumns: instanceMeta.columns,
                    bitsAllocated: instanceMeta.bitsAllocated,
                    bitsStored: instanceMeta.bitsStored,
                    photometricInterpretation: instanceMeta.photometricInterpretation,
                    transferSyntaxUID: instanceMeta.transferSyntaxUID,
                    windowCenter: instanceMeta.windowCenter,
                    windowWidth: instanceMeta.windowWidth,
                    pixelSpacing: instanceMeta.pixelSpacing,
                    filePath: instanceMeta.filePath,
                    fileSize: instanceMeta.fileSize
                )
                instance.series = series
                context.insert(instance)
                
                totalInstances += 1
                totalSize += instanceMeta.fileSize
                
                // Generate thumbnail for first instance
                if series.thumbnailPath == nil {
                    if let thumbnailData = try? await thumbnailService.generateThumbnail(for: fileURL) {
                        let thumbPath = await thumbnailService.thumbnailsDirectory
                            .appendingPathComponent("\(seriesUID).jpg")
                        try? thumbnailData.write(to: thumbPath)
                        series.thumbnailPath = thumbPath.path
                        
                        // Also set as study thumbnail if not set
                        if study.thumbnailPath == nil {
                            study.thumbnailPath = thumbPath.path
                        }
                    }
                }
            }
            
            series.instanceCount = (series.instances?.count ?? 0) + seriesFiles.count
            series.storageSize += Int64(seriesFiles.reduce(0) { $0 + $1.1.fileSize })
        }
        
        study.seriesCount = seriesGroups.count
        study.instanceCount += totalInstances
        study.modalities = Array(modalities)
        study.storageSize += totalSize
        study.lastAccessedAt = Date()
    }
    
    /// Deletes a study
    func deleteStudy(_ study: DICOMStudy) async {
        guard let context = modelContext else { return }
        
        // Delete files
        if let series = study.series {
            for s in series {
                if let instances = s.instances {
                    for instance in instances {
                        try? await fileService.deleteFile(at: instance.filePath)
                    }
                }
            }
        }
        
        // Delete from database
        context.delete(study)
        
        do {
            try context.save()
            await loadStudies()
        } catch {
            errorMessage = "Failed to delete study: \(error.localizedDescription)"
        }
    }
    
    /// Updates last accessed time for a study
    func markStudyAccessed(_ study: DICOMStudy) {
        study.lastAccessedAt = Date()
        try? modelContext?.save()
    }
    
    // MARK: - Filtering
    
    /// Updates the list of available modalities
    private func updateAvailableModalities() {
        var modalities = Set<String>()
        for study in studies {
            modalities.formUnion(study.modalities)
        }
        availableModalities = Array(modalities).sorted()
    }
    
    /// Applies search and filter criteria
    private func applyFilters() {
        filteredStudies = studies.filter { study in
            // Apply modality filter
            if let modality = selectedModality {
                guard study.modalities.contains(modality) else { return false }
            }
            
            // Apply search text
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesName = study.patientName.lowercased().contains(searchLower)
                let matchesID = study.patientID.lowercased().contains(searchLower)
                let matchesDescription = study.studyDescription?.lowercased().contains(searchLower) ?? false
                let matchesAccession = study.accessionNumber?.lowercased().contains(searchLower) ?? false
                
                guard matchesName || matchesID || matchesDescription || matchesAccession else {
                    return false
                }
            }
            
            return true
        }
    }
    
    // MARK: - Storage
    
    /// Calculates total storage size
    private func calculateStorageSize() async {
        do {
            totalStorageSize = try await fileService.librarySize()
        } catch {
            totalStorageSize = studies.reduce(0) { $0 + $1.storageSize }
        }
    }
    
    /// Formatted storage size string
    var storageSizeString: String {
        ByteCountFormatter.string(fromByteCount: totalStorageSize, countStyle: .file)
    }
}
