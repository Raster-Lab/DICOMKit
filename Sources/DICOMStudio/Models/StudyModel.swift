// StudyModel.swift
// DICOMStudio
//
// DICOM Studio — Study-level metadata model

import Foundation

/// Represents a DICOM study containing one or more series.
///
/// A study is the primary organizational unit in DICOM, typically
/// corresponding to a single imaging session or exam.
public struct StudyModel: Identifiable, Hashable, Sendable {
    /// Unique identifier for this study model instance.
    public let id: UUID

    /// DICOM Study Instance UID (0020,000D).
    public let studyInstanceUID: String

    /// Study ID (0020,0010) assigned by the institution.
    public var studyID: String

    /// Study date (0008,0020).
    public var studyDate: Date?

    /// Study time (0008,0030).
    public var studyTime: Date?

    /// Study description (0008,1030).
    public var studyDescription: String?

    /// Accession number (0008,0050).
    public var accessionNumber: String?

    /// Referring physician's name (0008,0090).
    public var referringPhysicianName: String?

    /// Patient's name (0010,0010).
    public var patientName: String?

    /// Patient ID (0010,0020).
    public var patientID: String?

    /// Patient's birth date (0010,0030).
    public var patientBirthDate: Date?

    /// Patient's sex (0010,0040).
    public var patientSex: String?

    /// Institution name (0008,0080).
    public var institutionName: String?

    /// Number of series in this study.
    public var numberOfSeries: Int

    /// Number of instances in this study.
    public var numberOfInstances: Int

    /// Modalities present in the study (0008,0061).
    public var modalitiesInStudy: Set<String>

    /// File system path where study files are stored.
    public var storagePath: String?

    /// Creates a new study model.
    public init(
        id: UUID = UUID(),
        studyInstanceUID: String,
        studyID: String = "",
        studyDate: Date? = nil,
        studyTime: Date? = nil,
        studyDescription: String? = nil,
        accessionNumber: String? = nil,
        referringPhysicianName: String? = nil,
        patientName: String? = nil,
        patientID: String? = nil,
        patientBirthDate: Date? = nil,
        patientSex: String? = nil,
        institutionName: String? = nil,
        numberOfSeries: Int = 0,
        numberOfInstances: Int = 0,
        modalitiesInStudy: Set<String> = [],
        storagePath: String? = nil
    ) {
        self.id = id
        self.studyInstanceUID = studyInstanceUID
        self.studyID = studyID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.accessionNumber = accessionNumber
        self.referringPhysicianName = referringPhysicianName
        self.patientName = patientName
        self.patientID = patientID
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.institutionName = institutionName
        self.numberOfSeries = numberOfSeries
        self.numberOfInstances = numberOfInstances
        self.modalitiesInStudy = modalitiesInStudy
        self.storagePath = storagePath
    }

    /// Returns a display-friendly patient name (e.g., "Doe, John" from "Doe^John").
    public var displayPatientName: String {
        guard let name = patientName, !name.isEmpty else {
            return "Unknown Patient"
        }
        return name.replacingOccurrences(of: "^", with: ", ")
    }

    /// Returns a formatted study date string or "Unknown Date".
    public var displayStudyDate: String {
        guard let date = studyDate else {
            return "Unknown Date"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Returns a short summary of modalities (e.g., "CT, MR").
    public var displayModalities: String {
        if modalitiesInStudy.isEmpty {
            return "Unknown"
        }
        return modalitiesInStudy.sorted().joined(separator: ", ")
    }
}
