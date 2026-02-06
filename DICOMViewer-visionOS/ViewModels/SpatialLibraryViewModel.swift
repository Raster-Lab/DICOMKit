// SpatialLibraryViewModel.swift
// DICOMViewer visionOS - Spatial Library ViewModel
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import Observation
import SwiftData

/// ViewModel for spatial study library
@Observable
@MainActor
final class SpatialLibraryViewModel {
    var studies: [DICOMStudy] = []
    var selectedStudy: DICOMStudy?
    var searchQuery: String = ""
    var sortOption: SortOption = .dateDescending
    var filterModality: String? = nil
    
    enum SortOption {
        case dateDescending
        case dateAscending
        case patientName
        case studyDescription
    }
    
    var filteredStudies: [DICOMStudy] {
        var result = studies
        
        // Apply search filter
        if !searchQuery.isEmpty {
            result = result.filter { study in
                study.patientName.localizedCaseInsensitiveContains(searchQuery) ||
                study.studyDescription?.localizedCaseInsensitiveContains(searchQuery) == true
            }
        }
        
        // Apply modality filter
        if let modality = filterModality {
            result = result.filter { study in
                study.series.contains { $0.modality == modality }
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateDescending:
            result.sort { ($0.studyDate ?? .distantPast) > ($1.studyDate ?? .distantPast) }
        case .dateAscending:
            result.sort { ($0.studyDate ?? .distantPast) < ($1.studyDate ?? .distantPast) }
        case .patientName:
            result.sort { $0.patientName < $1.patientName }
        case .studyDescription:
            result.sort { ($0.studyDescription ?? "") < ($1.studyDescription ?? "") }
        }
        
        return result
    }
    
    func loadStudies(from context: ModelContext) {
        let descriptor = FetchDescriptor<DICOMStudy>(sortBy: [SortDescriptor(\.importDate, order: .reverse)])
        if let fetchedStudies = try? context.fetch(descriptor) {
            studies = fetchedStudies
        }
    }
}
