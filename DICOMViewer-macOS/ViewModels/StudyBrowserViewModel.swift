//
//  StudyBrowserViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI

/// ViewModel for the study browser view
@MainActor
@Observable
final class StudyBrowserViewModel {
    // MARK: - Properties
    
    /// List of studies to display
    private(set) var studies: [DicomStudy] = []
    
    /// Currently selected studies
    var selectedStudies: Set<DicomStudy.ID> = []
    
    /// Search query text
    var searchText: String = "" {
        didSet {
            Task { await performSearch() }
        }
    }
    
    /// Filter by modality
    var modalityFilter: String? = nil {
        didSet {
            Task { await loadStudies() }
        }
    }
    
    /// Sort order
    var sortOrder: SortOrder = .dateDescending {
        didSet {
            sortStudies()
        }
    }
    
    /// Loading state
    private(set) var isLoading = false
    
    /// Error message
    var errorMessage: String?
    
    /// Statistics
    private(set) var totalStudies: Int = 0
    private(set) var totalSize: Int64 = 0
    
    // MARK: - Services
    
    private let databaseService = DatabaseService.shared
    private let importService = FileImportService.shared
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadStudies()
            await loadStatistics()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all studies from database
    func loadStudies() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let modality = modalityFilter {
                studies = try databaseService.filterStudies(byModality: modality)
            } else {
                studies = try databaseService.fetchAllStudies()
            }
            sortStudies()
        } catch {
            errorMessage = "Failed to load studies: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Search studies by patient name or ID
    func performSearch() async {
        guard !searchText.isEmpty else {
            await loadStudies()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            studies = try databaseService.searchStudies(query: searchText)
            sortStudies()
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Import files from URLs
    func importFiles(_ urls: [URL]) async {
        isLoading = true
        
        let result = await importService.importFiles(at: urls) { current, total in
            // Progress updates could be shown in UI
        }
        
        if result.successCount > 0 {
            await loadStudies()
            await loadStatistics()
        }
        
        if !result.errors.isEmpty {
            errorMessage = "Imported \(result.successCount) files, \(result.failureCount) failed"
        }
        
        isLoading = false
    }
    
    /// Import directory
    func importDirectory(_ url: URL) async {
        isLoading = true
        
        let result = await importService.importDirectory(at: url) { current, total in
            // Progress updates could be shown in UI
        }
        
        if result.successCount > 0 {
            await loadStudies()
            await loadStatistics()
        }
        
        if !result.errors.isEmpty {
            errorMessage = "Imported \(result.successCount) files, \(result.failureCount) failed"
        }
        
        isLoading = false
    }
    
    /// Delete selected studies
    func deleteSelectedStudies() async {
        let studiesToDelete = studies.filter { selectedStudies.contains($0.id) }
        
        guard !studiesToDelete.isEmpty else { return }
        
        do {
            try databaseService.deleteStudies(studiesToDelete)
            selectedStudies.removeAll()
            await loadStudies()
            await loadStatistics()
        } catch {
            errorMessage = "Failed to delete studies: \(error.localizedDescription)"
        }
    }
    
    /// Toggle star status for a study
    func toggleStar(for study: DicomStudy) {
        study.isStarred.toggle()
        do {
            try databaseService.modelContext.save()
        } catch {
            errorMessage = "Failed to update study: \(error.localizedDescription)"
        }
    }
    
    /// Load statistics
    func loadStatistics() async {
        do {
            totalStudies = try databaseService.getTotalStudyCount()
            totalSize = try databaseService.getTotalDatabaseSize()
        } catch {
            // Silently fail for statistics
        }
    }
    
    // MARK: - Private Methods
    
    private func sortStudies() {
        switch sortOrder {
        case .dateAscending:
            studies.sort { ($0.studyDate ?? .distantPast) < ($1.studyDate ?? .distantPast) }
        case .dateDescending:
            studies.sort { ($0.studyDate ?? .distantPast) > ($1.studyDate ?? .distantPast) }
        case .patientName:
            studies.sort { $0.patientName.localizedCaseInsensitiveCompare($1.patientName) == .orderedAscending }
        case .modality:
            studies.sort { $0.modalities.localizedCaseInsensitiveCompare($1.modalities) == .orderedAscending }
        }
    }
    
    // MARK: - Types
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Date (Newest First)"
        case dateAscending = "Date (Oldest First)"
        case patientName = "Patient Name"
        case modality = "Modality"
    }
}
