// LibraryModelTests.swift
// DICOMStudioTests
//
// Tests for LibraryModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("LibraryModel Tests")
struct LibraryModelTests {

    @Test("Empty library")
    func testEmptyLibrary() {
        let library = LibraryModel()
        #expect(library.studyCount == 0)
        #expect(library.seriesCount == 0)
        #expect(library.instanceCount == 0)
        #expect(library.sortedStudies.isEmpty)
    }

    @Test("Add study")
    func testAddStudy() {
        var library = LibraryModel()
        let study = StudyModel(studyInstanceUID: "1.2.3", patientName: "Doe^John")
        library.addStudy(study)

        #expect(library.studyCount == 1)
        #expect(library.studies["1.2.3"]?.patientName == "Doe^John")
    }

    @Test("Add series linked to study")
    func testAddSeries() {
        var library = LibraryModel()
        let study = StudyModel(studyInstanceUID: "1.2.3")
        library.addStudy(study)

        let series = SeriesModel(seriesInstanceUID: "1.2.3.4", studyInstanceUID: "1.2.3", modality: "CT")
        library.addSeries(series)

        #expect(library.seriesCount == 1)
        #expect(library.seriesForStudy("1.2.3").count == 1)
        #expect(library.seriesForStudy("1.2.3").first?.modality == "CT")
    }

    @Test("Add instance linked to series")
    func testAddInstance() {
        var library = LibraryModel()
        let study = StudyModel(studyInstanceUID: "1.2.3")
        library.addStudy(study)

        let series = SeriesModel(seriesInstanceUID: "1.2.3.4", studyInstanceUID: "1.2.3")
        library.addSeries(series)

        let instance = InstanceModel(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "",
            seriesInstanceUID: "1.2.3.4",
            filePath: "/tmp/test.dcm"
        )
        library.addInstance(instance)

        #expect(library.instanceCount == 1)
        #expect(library.instancesForSeries("1.2.3.4").count == 1)
    }

    @Test("Series for nonexistent study")
    func testSeriesForNonexistentStudy() {
        let library = LibraryModel()
        #expect(library.seriesForStudy("nonexistent").isEmpty)
    }

    @Test("Instances for nonexistent series")
    func testInstancesForNonexistentSeries() {
        let library = LibraryModel()
        #expect(library.instancesForSeries("nonexistent").isEmpty)
    }

    @Test("Series sorted by series number")
    func testSeriesSorting() {
        var library = LibraryModel()
        let study = StudyModel(studyInstanceUID: "1.2.3")
        library.addStudy(study)

        library.addSeries(SeriesModel(seriesInstanceUID: "s3", studyInstanceUID: "1.2.3", seriesNumber: 3))
        library.addSeries(SeriesModel(seriesInstanceUID: "s1", studyInstanceUID: "1.2.3", seriesNumber: 1))
        library.addSeries(SeriesModel(seriesInstanceUID: "s2", studyInstanceUID: "1.2.3", seriesNumber: 2))

        let sorted = library.seriesForStudy("1.2.3")
        #expect(sorted.count == 3)
        #expect(sorted[0].seriesNumber == 1)
        #expect(sorted[1].seriesNumber == 2)
        #expect(sorted[2].seriesNumber == 3)
    }

    @Test("Instances sorted by instance number")
    func testInstanceSorting() {
        var library = LibraryModel()
        let study = StudyModel(studyInstanceUID: "1.2.3")
        library.addStudy(study)
        let series = SeriesModel(seriesInstanceUID: "1.2.3.4", studyInstanceUID: "1.2.3")
        library.addSeries(series)

        library.addInstance(InstanceModel(sopInstanceUID: "i3", sopClassUID: "", seriesInstanceUID: "1.2.3.4", instanceNumber: 30, filePath: "/tmp/3.dcm"))
        library.addInstance(InstanceModel(sopInstanceUID: "i1", sopClassUID: "", seriesInstanceUID: "1.2.3.4", instanceNumber: 10, filePath: "/tmp/1.dcm"))
        library.addInstance(InstanceModel(sopInstanceUID: "i2", sopClassUID: "", seriesInstanceUID: "1.2.3.4", instanceNumber: 20, filePath: "/tmp/2.dcm"))

        let sorted = library.instancesForSeries("1.2.3.4")
        #expect(sorted.count == 3)
        #expect(sorted[0].instanceNumber == 10)
        #expect(sorted[1].instanceNumber == 20)
        #expect(sorted[2].instanceNumber == 30)
    }

    @Test("Sorted studies by date descending")
    func testSortedStudiesByDate() {
        var library = LibraryModel()
        let calendar = Calendar.current
        let now = Date()

        let older = StudyModel(studyInstanceUID: "old", studyDate: calendar.date(byAdding: .day, value: -7, to: now))
        let newer = StudyModel(studyInstanceUID: "new", studyDate: now)
        let noDate = StudyModel(studyInstanceUID: "nodate")

        library.addStudy(older)
        library.addStudy(newer)
        library.addStudy(noDate)

        let sorted = library.sortedStudies
        #expect(sorted.count == 3)
        #expect(sorted[0].studyInstanceUID == "new")
        #expect(sorted[1].studyInstanceUID == "old")
        #expect(sorted[2].studyInstanceUID == "nodate")
    }

    @Test("Remove study cascades to series and instances")
    func testRemoveStudy() {
        var library = LibraryModel()
        let study = StudyModel(studyInstanceUID: "1.2.3")
        library.addStudy(study)

        let series = SeriesModel(seriesInstanceUID: "1.2.3.4", studyInstanceUID: "1.2.3")
        library.addSeries(series)

        let instance = InstanceModel(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "",
            seriesInstanceUID: "1.2.3.4",
            filePath: "/tmp/test.dcm"
        )
        library.addInstance(instance)

        #expect(library.studyCount == 1)
        #expect(library.seriesCount == 1)
        #expect(library.instanceCount == 1)

        library.removeStudy("1.2.3")

        #expect(library.studyCount == 0)
        #expect(library.seriesCount == 0)
        #expect(library.instanceCount == 0)
    }

    @Test("Remove nonexistent study does nothing")
    func testRemoveNonexistentStudy() {
        var library = LibraryModel()
        library.removeStudy("nonexistent")
        #expect(library.studyCount == 0)
    }

    @Test("Clear library")
    func testClearLibrary() {
        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: "1.2.3"))
        library.addSeries(SeriesModel(seriesInstanceUID: "1.2.3.4", studyInstanceUID: "1.2.3"))
        library.addInstance(InstanceModel(sopInstanceUID: "1.2.3.4.5", sopClassUID: "", seriesInstanceUID: "1.2.3.4", filePath: "/tmp/test.dcm"))

        library.clear()

        #expect(library.studyCount == 0)
        #expect(library.seriesCount == 0)
        #expect(library.instanceCount == 0)
    }

    @Test("Multiple studies with multiple series")
    func testMultipleStudies() {
        var library = LibraryModel()

        library.addStudy(StudyModel(studyInstanceUID: "study1"))
        library.addStudy(StudyModel(studyInstanceUID: "study2"))

        library.addSeries(SeriesModel(seriesInstanceUID: "s1a", studyInstanceUID: "study1"))
        library.addSeries(SeriesModel(seriesInstanceUID: "s1b", studyInstanceUID: "study1"))
        library.addSeries(SeriesModel(seriesInstanceUID: "s2a", studyInstanceUID: "study2"))

        #expect(library.studyCount == 2)
        #expect(library.seriesCount == 3)
        #expect(library.seriesForStudy("study1").count == 2)
        #expect(library.seriesForStudy("study2").count == 1)
    }

    @Test("Add duplicate study replaces existing")
    func testAddDuplicateStudy() {
        var library = LibraryModel()
        library.addStudy(StudyModel(studyInstanceUID: "1.2.3", patientName: "Old Name"))
        library.addStudy(StudyModel(studyInstanceUID: "1.2.3", patientName: "New Name"))

        #expect(library.studyCount == 1)
        #expect(library.studies["1.2.3"]?.patientName == "New Name")
    }
}
