//
//  DicomStudy.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftData

/// Represents a DICOM study in the local database
@Model
final class DicomStudy {
    /// Unique study identifier (Study Instance UID)
    @Attribute(.unique) var studyInstanceUID: String
    
    /// Patient's name
    var patientName: String
    
    /// Patient ID
    var patientID: String
    
    /// Patient's birth date
    var patientBirthDate: Date?
    
    /// Patient's sex
    var patientSex: String?
    
    /// Study description
    var studyDescription: String?
    
    /// Study date and time
    var studyDate: Date?
    
    /// Accession number
    var accessionNumber: String?
    
    /// Modalities in study (comma-separated, e.g., "CT,MR")
    var modalities: String
    
    /// Number of series in study
    var numberOfSeries: Int
    
    /// Number of instances in study
    var numberOfInstances: Int
    
    /// Date when study was imported
    var importDate: Date
    
    /// Total size of study in bytes
    var studySize: Int64
    
    /// Series belonging to this study
    @Relationship(deleteRule: .cascade, inverse: \DicomSeries.study)
    var series: [DicomSeries]
    
    /// Referring physician's name
    var referringPhysician: String?
    
    /// Institution name
    var institutionName: String?
    
    /// Whether this study is starred/favorited
    var isStarred: Bool
    
    /// User notes for this study
    var notes: String?
    
    init(
        studyInstanceUID: String,
        patientName: String,
        patientID: String,
        patientBirthDate: Date? = nil,
        patientSex: String? = nil,
        studyDescription: String? = nil,
        studyDate: Date? = nil,
        accessionNumber: String? = nil,
        modalities: String = "",
        numberOfSeries: Int = 0,
        numberOfInstances: Int = 0,
        studySize: Int64 = 0,
        referringPhysician: String? = nil,
        institutionName: String? = nil,
        isStarred: Bool = false,
        notes: String? = nil
    ) {
        self.studyInstanceUID = studyInstanceUID
        self.patientName = patientName
        self.patientID = patientID
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.studyDescription = studyDescription
        self.studyDate = studyDate
        self.accessionNumber = accessionNumber
        self.modalities = modalities
        self.numberOfSeries = numberOfSeries
        self.numberOfInstances = numberOfInstances
        self.importDate = Date()
        self.studySize = studySize
        self.series = []
        self.referringPhysician = referringPhysician
        self.institutionName = institutionName
        self.isStarred = isStarred
        self.notes = notes
    }
    
    /// Array of modality codes
    var modalityList: [String] {
        modalities.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    /// Formatted study size (e.g., "125.5 MB")
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: studySize, countStyle: .file)
    }
    
    /// Formatted study date (e.g., "Jan 15, 2024")
    var formattedStudyDate: String {
        guard let date = studyDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Display name combining patient name and ID
    var displayName: String {
        if patientName.isEmpty {
            return patientID.isEmpty ? "Unknown Patient" : patientID
        }
        return patientName
    }
}

extension DicomStudy: Identifiable {
    var id: String { studyInstanceUID }
}
