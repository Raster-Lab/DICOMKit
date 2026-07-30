// StudyRowSummaryTests.swift
// DICOMStudioTests
//
// What a library row says about a study.
//
// The bug this pins: study-level description and modality tags are optional, and
// when a file omits them the row showed a patient name and nothing else — even
// though the series filed under that study knew both all along.

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Study Row Summary Tests")
struct StudyRowSummaryTests {

    private func library(
        studyDescription: String? = nil,
        modalitiesInStudy: Set<String> = [],
        series: [(uid: String, number: Int?, modality: String,
                  description: String?, bodyPart: String?, instances: Int)]
    ) -> (LibraryModel, StudyModel) {
        var library = LibraryModel()
        let study = StudyModel(
            studyInstanceUID: "1.2.3",
            studyDate: Date(timeIntervalSince1970: 1_780_000_000),
            studyDescription: studyDescription,
            patientName: "VANITHA^K",
            patientID: "711794",
            modalitiesInStudy: modalitiesInStudy)
        library.addStudy(study)

        for entry in series {
            library.addSeries(SeriesModel(
                seriesInstanceUID: entry.uid,
                studyInstanceUID: "1.2.3",
                seriesNumber: entry.number,
                modality: entry.modality,
                seriesDescription: entry.description,
                bodyPartExamined: entry.bodyPart))
            for index in 0..<entry.instances {
                library.addInstance(InstanceModel(
                    sopInstanceUID: "\(entry.uid).\(index)",
                    sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                    seriesInstanceUID: entry.uid,
                    instanceNumber: index + 1,
                    filePath: "/tmp/\(entry.uid)-\(index).dcm"))
            }
        }
        return (library, study)
    }

    @Test("A study whose header carries everything is described by it")
    func testFullHeader() {
        let (library, study) = library(
            studyDescription: "Brain_ASPECT(Adult)",
            modalitiesInStudy: ["CT", "SR"],
            series: [("1.1", 1, "CT", "Topogram", nil, 2)])
        let summary = StudyRowSummary.make(study: study, library: library)

        #expect(summary.patientName == "VANITHA, K")
        #expect(summary.description == "Brain_ASPECT(Adult)")
        #expect(summary.modalities == "CT, SR")
        #expect(summary.counts == "1 series · 2 images")
        #expect(summary.hasContent)
    }

    @Test("With no Study Description the first series' description names the exam")
    func testSeriesDescriptionFallback() {
        let (library, study) = library(series: [
            ("1.1", 1, "CT", "Brain 0.80", nil, 300),
            ("1.2", 2, "CT", "Brain 5.00", nil, 60)
        ])
        let summary = StudyRowSummary.make(study: study, library: library)

        #expect(summary.description == "Brain 0.80", "the lowest-numbered series")
        #expect(summary.counts == "2 series · 360 images")
    }

    @Test("Body part stands in when nothing describes itself")
    func testBodyPartFallback() {
        let (library, study) = library(series: [
            ("1.1", 1, "CT", nil, nil, 1),
            ("1.2", 2, "CT", "   ", "HEAD", 1)
        ])
        #expect(StudyRowSummary.make(study: study, library: library).description == "HEAD")
    }

    @Test("Modalities come from the series when the study header names none")
    func testModalitiesFromSeries() {
        // This is the reported row: a study with a patient name and nothing else,
        // whose series knew they were CT and SR.
        let (library, study) = library(series: [
            ("1.1", 1, "CT", nil, nil, 580),
            ("1.9", 9, "SR", nil, nil, 2)
        ])
        let summary = StudyRowSummary.make(study: study, library: library)

        #expect(summary.modalities == "CT, SR")
        #expect(summary.counts == "2 series · 582 images")
    }

    @Test("The study's own modality list is kept alongside its series'")
    func testModalitiesUnion() {
        let (library, study) = library(
            modalitiesInStudy: ["MR"],
            series: [("1.1", 1, "CT", nil, nil, 1)])
        #expect(StudyRowSummary.make(study: study, library: library)
                .modalities == "CT, MR")
    }

    @Test("A study with nothing under it says so rather than showing a blank row")
    func testEmptyStudy() {
        let (library, study) = library(series: [])
        let summary = StudyRowSummary.make(study: study, library: library)

        #expect(summary.modalities == "Unknown")
        #expect(summary.description == nil)
        #expect(summary.counts == "0 series · 0 images")
        #expect(!summary.hasContent)
    }
}
