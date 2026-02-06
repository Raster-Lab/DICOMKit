//
//  DatabaseService.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftData

/// Service for managing the local DICOM study database
@MainActor
final class DatabaseService {
    /// Shared singleton instance
    static let shared = DatabaseService()
    
    /// SwiftData model container
    private(set) var modelContainer: ModelContainer
    
    /// Main context for database operations
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    private init() {
        let schema = Schema([
            DicomStudy.self,
            DicomSeries.self,
            DicomInstance.self,
            PACSServer.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Study Operations
    
    /// Fetch all studies from database
    func fetchAllStudies() throws -> [DicomStudy] {
        let descriptor = FetchDescriptor<DicomStudy>(
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch study by UID
    func fetchStudy(uid: String) throws -> DicomStudy? {
        let descriptor = FetchDescriptor<DicomStudy>(
            predicate: #Predicate { $0.studyInstanceUID == uid }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Search studies by patient name or ID
    func searchStudies(query: String) throws -> [DicomStudy] {
        let lowercasedQuery = query.lowercased()
        let descriptor = FetchDescriptor<DicomStudy>(
            predicate: #Predicate { study in
                study.patientName.lowercased().contains(lowercasedQuery) ||
                study.patientID.lowercased().contains(lowercasedQuery)
            },
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Filter studies by modality
    func filterStudies(byModality modality: String) throws -> [DicomStudy] {
        let descriptor = FetchDescriptor<DicomStudy>(
            predicate: #Predicate { study in
                study.modalities.contains(modality)
            },
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Filter studies by date range
    func filterStudies(from startDate: Date, to endDate: Date) throws -> [DicomStudy] {
        let descriptor = FetchDescriptor<DicomStudy>(
            predicate: #Predicate { study in
                if let date = study.studyDate {
                    return date >= startDate && date <= endDate
                }
                return false
            },
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Add or update a study
    func saveStudy(_ study: DicomStudy) throws {
        modelContext.insert(study)
        try modelContext.save()
    }
    
    /// Delete a study
    func deleteStudy(_ study: DicomStudy) throws {
        modelContext.delete(study)
        try modelContext.save()
    }
    
    /// Delete multiple studies
    func deleteStudies(_ studies: [DicomStudy]) throws {
        for study in studies {
            modelContext.delete(study)
        }
        try modelContext.save()
    }
    
    // MARK: - Series Operations
    
    /// Fetch series for a study
    func fetchSeries(forStudy studyUID: String) throws -> [DicomSeries] {
        let descriptor = FetchDescriptor<DicomSeries>(
            predicate: #Predicate { series in
                series.study?.studyInstanceUID == studyUID
            },
            sortBy: [SortDescriptor(\.seriesNumber)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch series by UID
    func fetchSeries(uid: String) throws -> DicomSeries? {
        let descriptor = FetchDescriptor<DicomSeries>(
            predicate: #Predicate { $0.seriesInstanceUID == uid }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    // MARK: - Instance Operations
    
    /// Fetch instances for a series
    func fetchInstances(forSeries seriesUID: String) throws -> [DicomInstance] {
        let descriptor = FetchDescriptor<DicomInstance>(
            predicate: #Predicate { instance in
                instance.series?.seriesInstanceUID == seriesUID
            },
            sortBy: [SortDescriptor(\.instanceNumber)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch instance by UID
    func fetchInstance(uid: String) throws -> DicomInstance? {
        let descriptor = FetchDescriptor<DicomInstance>(
            predicate: #Predicate { $0.sopInstanceUID == uid }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    // MARK: - Statistics
    
    /// Get total number of studies
    func getTotalStudyCount() throws -> Int {
        let descriptor = FetchDescriptor<DicomStudy>()
        return try modelContext.fetchCount(descriptor)
    }
    
    /// Get total database size in bytes
    func getTotalDatabaseSize() throws -> Int64 {
        let studies = try fetchAllStudies()
        return studies.reduce(0) { $0 + $1.studySize }
    }
    
    /// Get studies count by modality
    func getStudyCountByModality() throws -> [String: Int] {
        let studies = try fetchAllStudies()
        var modalityCounts: [String: Int] = [:]
        
        for study in studies {
            for modality in study.modalityList {
                modalityCounts[modality, default: 0] += 1
            }
        }
        
        return modalityCounts
    }
    
    // MARK: - Maintenance
    
    /// Rebuild database statistics
    func rebuildStatistics() throws {
        let studies = try fetchAllStudies()
        
        for study in studies {
            // Update series count
            study.numberOfSeries = study.series.count
            
            // Update instance count
            let instanceCount = study.series.reduce(0) { $0 + $1.instances.count }
            study.numberOfInstances = instanceCount
            
            // Update study size
            let studySize = study.series.flatMap { $0.instances }.reduce(0) { $0 + $1.fileSize }
            study.studySize = studySize
            
            // Update modalities list
            let modalities = Set(study.series.map { $0.modality })
            study.modalities = modalities.sorted().joined(separator: ",")
        }
        
        try modelContext.save()
    }
    
    /// Clear all data from database (for testing or reset)
    func clearAllData() throws {
        try modelContext.delete(model: DicomStudy.self)
        try modelContext.delete(model: DicomSeries.self)
        try modelContext.delete(model: DicomInstance.self)
        try modelContext.save()
    }
}
