// DICOMStudy.swift
// DICOMViewer visionOS - Study Data Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// DICOM Study Model for visionOS
///
/// Represents a DICOM study containing patient, study metadata, and associated series.
/// Adapted for visionOS with spatial metadata support.
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
    
    // MARK: - Metadata
    
    /// Date when study was imported into the app
    var importDate: Date
    
    /// File size in bytes
    var fileSize: Int64
    
    /// File URL (local storage)
    var fileURL: URL?
    
    // MARK: - Relationships
    
    /// Series in this study
    @Relationship(deleteRule: .cascade, inverse: \DICOMSeries.study)
    var series: [DICOMSeries]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        studyInstanceUID: String,
        patientName: String,
        patientID: String,
        patientBirthDate: Date? = nil,
        patientSex: String? = nil,
        studyDate: Date? = nil,
        studyTime: Date? = nil,
        studyDescription: String? = nil,
        accessionNumber: String? = nil,
        referringPhysicianName: String? = nil,
        seriesCount: Int = 0,
        instanceCount: Int = 0,
        importDate: Date = Date(),
        fileSize: Int64 = 0,
        fileURL: URL? = nil,
        series: [DICOMSeries] = []
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
        self.importDate = importDate
        self.fileSize = fileSize
        self.fileURL = fileURL
        self.series = series
    }
}

// MARK: - Computed Properties

extension DICOMStudy {
    /// Display name for the study
    var displayName: String {
        if let description = studyDescription, !description.isEmpty {
            return description
        }
        return patientName
    }
    
    /// Formatted study date
    var formattedStudyDate: String {
        guard let date = studyDate else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Formatted file size
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
