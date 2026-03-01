// StudyModelTests.swift
// DICOMStudioTests
//
// Tests for StudyModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("StudyModel Tests")
struct StudyModelTests {

    @Test("Study creation with all fields")
    func testStudyCreation() {
        let date = Date()
        let study = StudyModel(
            studyInstanceUID: "1.2.3.4.5",
            studyID: "STUDY001",
            studyDate: date,
            studyDescription: "CT Chest",
            accessionNumber: "ACC001",
            referringPhysicianName: "Dr. Smith",
            patientName: "Doe^John",
            patientID: "PAT001",
            patientSex: "M",
            institutionName: "General Hospital",
            numberOfSeries: 3,
            numberOfInstances: 150,
            modalitiesInStudy: ["CT"]
        )

        #expect(study.studyInstanceUID == "1.2.3.4.5")
        #expect(study.studyID == "STUDY001")
        #expect(study.studyDate == date)
        #expect(study.studyDescription == "CT Chest")
        #expect(study.accessionNumber == "ACC001")
        #expect(study.referringPhysicianName == "Dr. Smith")
        #expect(study.patientName == "Doe^John")
        #expect(study.patientID == "PAT001")
        #expect(study.patientSex == "M")
        #expect(study.institutionName == "General Hospital")
        #expect(study.numberOfSeries == 3)
        #expect(study.numberOfInstances == 150)
        #expect(study.modalitiesInStudy == ["CT"])
    }

    @Test("Study creation with defaults")
    func testStudyDefaults() {
        let study = StudyModel(studyInstanceUID: "1.2.3")

        #expect(study.studyID == "")
        #expect(study.studyDate == nil)
        #expect(study.studyDescription == nil)
        #expect(study.patientName == nil)
        #expect(study.numberOfSeries == 0)
        #expect(study.numberOfInstances == 0)
        #expect(study.modalitiesInStudy.isEmpty)
    }

    @Test("Display patient name with caret separator")
    func testDisplayPatientNameCaret() {
        let study = StudyModel(studyInstanceUID: "1.2.3", patientName: "Doe^John^M")
        #expect(study.displayPatientName == "Doe, John, M")
    }

    @Test("Display patient name when nil")
    func testDisplayPatientNameNil() {
        let study = StudyModel(studyInstanceUID: "1.2.3")
        #expect(study.displayPatientName == "Unknown Patient")
    }

    @Test("Display patient name when empty")
    func testDisplayPatientNameEmpty() {
        let study = StudyModel(studyInstanceUID: "1.2.3", patientName: "")
        #expect(study.displayPatientName == "Unknown Patient")
    }

    @Test("Display study date")
    func testDisplayStudyDate() {
        let study = StudyModel(studyInstanceUID: "1.2.3", studyDate: Date())
        #expect(study.displayStudyDate != "Unknown Date")
    }

    @Test("Display study date when nil")
    func testDisplayStudyDateNil() {
        let study = StudyModel(studyInstanceUID: "1.2.3")
        #expect(study.displayStudyDate == "Unknown Date")
    }

    @Test("Display modalities")
    func testDisplayModalities() {
        let study = StudyModel(studyInstanceUID: "1.2.3", modalitiesInStudy: ["CT", "MR"])
        #expect(study.displayModalities == "CT, MR")
    }

    @Test("Display modalities when empty")
    func testDisplayModalitiesEmpty() {
        let study = StudyModel(studyInstanceUID: "1.2.3")
        #expect(study.displayModalities == "Unknown")
    }

    @Test("Study is Identifiable")
    func testStudyIdentifiable() {
        let study1 = StudyModel(studyInstanceUID: "1.2.3")
        let study2 = StudyModel(studyInstanceUID: "1.2.3")
        #expect(study1.id != study2.id)
    }

    @Test("Study is Hashable")
    func testStudyHashable() {
        let study = StudyModel(studyInstanceUID: "1.2.3")
        var set: Set<StudyModel> = []
        set.insert(study)
        #expect(set.count == 1)
    }

    @Test("Study with storage path")
    func testStudyStoragePath() {
        let study = StudyModel(studyInstanceUID: "1.2.3", storagePath: "/tmp/dicom/study1")
        #expect(study.storagePath == "/tmp/dicom/study1")
    }
}
