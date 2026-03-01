// SeriesModelTests.swift
// DICOMStudioTests
//
// Tests for SeriesModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("SeriesModel Tests")
struct SeriesModelTests {

    @Test("Series creation with all fields")
    func testSeriesCreation() {
        let series = SeriesModel(
            seriesInstanceUID: "1.2.3.4.5.6",
            studyInstanceUID: "1.2.3.4.5",
            seriesNumber: 1,
            modality: "CT",
            seriesDescription: "Axial Chest",
            bodyPartExamined: "CHEST",
            numberOfInstances: 50,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )

        #expect(series.seriesInstanceUID == "1.2.3.4.5.6")
        #expect(series.studyInstanceUID == "1.2.3.4.5")
        #expect(series.seriesNumber == 1)
        #expect(series.modality == "CT")
        #expect(series.seriesDescription == "Axial Chest")
        #expect(series.bodyPartExamined == "CHEST")
        #expect(series.numberOfInstances == 50)
        #expect(series.transferSyntaxUID == "1.2.840.10008.1.2.1")
    }

    @Test("Series creation with defaults")
    func testSeriesDefaults() {
        let series = SeriesModel(seriesInstanceUID: "1.2.3", studyInstanceUID: "1.2.3.4")

        #expect(series.seriesNumber == nil)
        #expect(series.modality == "OT")
        #expect(series.seriesDescription == nil)
        #expect(series.numberOfInstances == 0)
    }

    @Test("Display title with number and description")
    func testDisplayTitleFull() {
        let series = SeriesModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2.3.4",
            seriesNumber: 2,
            seriesDescription: "Sagittal T1"
        )
        #expect(series.displayTitle == "Series 2 — Sagittal T1")
    }

    @Test("Display title with number only")
    func testDisplayTitleNumberOnly() {
        let series = SeriesModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2.3.4",
            seriesNumber: 5
        )
        #expect(series.displayTitle == "Series 5")
    }

    @Test("Display title with description only")
    func testDisplayTitleDescriptionOnly() {
        let series = SeriesModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2.3.4",
            seriesDescription: "Axial T2"
        )
        #expect(series.displayTitle == "Axial T2")
    }

    @Test("Display title when both nil")
    func testDisplayTitleEmpty() {
        let series = SeriesModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2.3.4"
        )
        #expect(series.displayTitle == "Unknown Series")
    }

    @Test("Series is Identifiable")
    func testSeriesIdentifiable() {
        let s1 = SeriesModel(seriesInstanceUID: "1.2.3", studyInstanceUID: "1.2")
        let s2 = SeriesModel(seriesInstanceUID: "1.2.3", studyInstanceUID: "1.2")
        #expect(s1.id != s2.id)
    }

    @Test("Series is Hashable")
    func testSeriesHashable() {
        let series = SeriesModel(seriesInstanceUID: "1.2.3", studyInstanceUID: "1.2")
        var set: Set<SeriesModel> = []
        set.insert(series)
        #expect(set.count == 1)
    }
}
