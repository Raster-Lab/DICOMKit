// DICOMStudy.swift
// DICOMViewer iOS - Study Data Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// DICOM Study Model
///
/// Represents a DICOM study containing patient, study metadata, and associated series.
/// Used for library management and study organization.
/// Reference: DICOM PS3.3 C.7.2 - Patient Study Module
@Model
final class DICOMStudy: Identifiable {
    // MARK: - Unique Identifier
    
    /// Unique identifier for the study in the app database
    var id: UUID
    
    // MARK: - DICOM UIDs
    
    /// Study Instance UID (0020,000D)
    @Attribute(.unique) var studyInstanceUID: String
    
    // MARK: - Patient Information
    
    /// Patient Name (0010,0010)
    var patientName: String
    
    /// Patient ID (0010,0020)
    var patientID: String
    
    /// Patient Birth Date (0010,0030)
    var patientBirthDate: Date?
    
    /// Patient Sex (0010,0040)
    var patientSex: String?
    
    // MARK: - Study Information
    
    /// Study Date (0008,0020)
    var studyDate: Date?
    
    /// Study Time (0008,0030)
    var studyTime: Date?
    
    /// Study Description (0008,1030)
    var studyDescription: String?
    
    /// Accession Number (0008,0050)
    var accessionNumber: String?
    
    /// Referring Physician Name (0008,0090)
    var referringPhysicianName: String?
    
    // MARK: - Series and Instance Counts
    
    /// Number of series in this study
    var seriesCount: Int
    
    /// Total number of instances across all series
    var instanceCount: Int
    
    /// Modalities present in this study (e.g., ["CT", "MR"])
    var modalities: [String]
    
    // MARK: - Storage Information
    
    /// Path to the study's storage directory
    var storagePath: String
    
    /// Path to the study's thumbnail image
    var thumbnailPath: String?
    
    /// Total storage size in bytes
    var storageSize: Int64
    
    // MARK: - Timestamps
    
    /// When the study was imported
    var createdAt: Date
    
    /// When the study was last accessed
    var lastAccessedAt: Date
    
    // MARK: - Relationships
    
    /// Series belonging to this study
    @Relationship(deleteRule: .cascade, inverse: \DICOMSeries.study)
    var series: [DICOMSeries]?
    
    // MARK: - Initialization
    
    /// Creates a new DICOM Study
    init(
        id: UUID = UUID(),
        studyInstanceUID: String,
        patientName: String = "Unknown",
        patientID: String = "Unknown",
        patientBirthDate: Date? = nil,
        patientSex: String? = nil,
        studyDate: Date? = nil,
        studyTime: Date? = nil,
        studyDescription: String? = nil,
        accessionNumber: String? = nil,
        referringPhysicianName: String? = nil,
        seriesCount: Int = 0,
        instanceCount: Int = 0,
        modalities: [String] = [],
        storagePath: String,
        thumbnailPath: String? = nil,
        storageSize: Int64 = 0,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.studyInstanceUID = studyInstanceUID
        self.patientName = patientName
        self.patientID = patientID
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.accessionNumber = accessionNumber
        self.referringPhysicianName = referringPhysicianName
        self.seriesCount = seriesCount
        self.instanceCount = instanceCount
        self.modalities = modalities
        self.storagePath = storagePath
        self.thumbnailPath = thumbnailPath
        self.storageSize = storageSize
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }
}

// MARK: - Display Helpers

extension DICOMStudy {
    /// Formatted patient name for display
    var displayName: String {
        patientName.isEmpty ? "Unknown Patient" : patientName.replacingOccurrences(of: "^", with: ", ")
    }
    
    /// Formatted study date for display
    var displayDate: String {
        guard let studyDate = studyDate else { return "No Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: studyDate)
    }
    
    /// Formatted modality string
    var modalityString: String {
        modalities.isEmpty ? "Unknown" : modalities.joined(separator: ", ")
    }
    
    /// Formatted storage size string
    var storageSizeString: String {
        ByteCountFormatter.string(fromByteCount: storageSize, countStyle: .file)
    }
}
