// LibraryStudyMergeTests.swift
// DICOMStudioTests
//
// Importing a study one file at a time.
//
// The bug these pin: each file rebuilt the study record from scratch, so the
// library ended up describing whichever file was read last. A study whose scout
// carries no description and no date showed nothing but a patient name.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("Library Study Merge Tests")
struct LibraryStudyMergeTests {

    private func study(
        description: String? = nil,
        date: Date? = nil,
        modality: String? = nil,
        patientName: String? = "DOE^JANE",
        accession: String? = nil
    ) -> StudyModel {
        StudyModel(
            studyInstanceUID: "1.2.3",
            studyDate: date,
            studyDescription: description,
            accessionNumber: accession,
            patientName: patientName,
            modalitiesInStudy: modality.map { [$0] } ?? []
        )
    }

    @Test("A later file with a thinner header does not erase the study's details")
    func testThinFileDoesNotOverwrite() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var library = LibraryModel()

        library.addStudy(study(description: "CT ABDOMEN", date: date,
                               modality: "CT", accession: "A123"))
        // A secondary capture from the same study: patient name only.
        library.addStudy(study(description: nil, date: nil, modality: nil))

        let merged = try #require(library.studies["1.2.3"])
        #expect(merged.studyDescription == "CT ABDOMEN")
        #expect(merged.studyDate == date)
        #expect(merged.accessionNumber == "A123")
        #expect(merged.modalitiesInStudy == ["CT"])
    }

    @Test("Details arriving in a later file are filled in")
    func testLaterFileFillsGaps() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var library = LibraryModel()

        library.addStudy(study(description: nil, date: nil, modality: nil))
        library.addStudy(study(description: "CT ABDOMEN", date: date, modality: "CT"))

        let merged = try #require(library.studies["1.2.3"])
        #expect(merged.studyDescription == "CT ABDOMEN")
        #expect(merged.studyDate == date)
    }

    @Test("Modalities accumulate across the study")
    func testModalitiesAccumulate() throws {
        var library = LibraryModel()
        library.addStudy(study(modality: "CT"))
        library.addStudy(study(modality: "SR"))
        library.addStudy(study(modality: "CT"))

        #expect(try #require(library.studies["1.2.3"]).modalitiesInStudy == ["CT", "SR"])
    }

    @Test("An empty description does not displace a real one")
    func testBlankValuesLose() throws {
        var library = LibraryModel()
        library.addStudy(study(description: "CT ABDOMEN"))
        library.addStudy(study(description: "   "))

        #expect(try #require(library.studies["1.2.3"]).studyDescription == "CT ABDOMEN")
    }

    @Test("Marking a study favourite survives re-importing one of its files")
    func testFavouriteSurvives() throws {
        var library = LibraryModel()
        library.addStudy(study(description: "CT ABDOMEN"))
        library.toggleFavorite("1.2.3")
        #expect(try #require(library.studies["1.2.3"]).isFavorite)

        library.addStudy(study(description: "CT ABDOMEN"))
        #expect(try #require(library.studies["1.2.3"]).isFavorite,
                "re-import must not clear the user's own state")
    }

    // MARK: - Instance order

    private func instance(_ sop: String, number: Int?, path: String) -> InstanceModel {
        InstanceModel(
            sopInstanceUID: sop,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.4",
            instanceNumber: number,
            filePath: path
        )
    }

    @Test("A series is read in Instance Number order")
    func testInstanceOrder() {
        var library = LibraryModel()
        library.addInstance(instance("c", number: 3, path: "/c.dcm"))
        library.addInstance(instance("a", number: 1, path: "/a.dcm"))
        library.addInstance(instance("b", number: 2, path: "/b.dcm"))

        #expect(library.instancesForSeries("1.2.3.4").map(\.filePath)
                == ["/a.dcm", "/b.dcm", "/c.dcm"])
    }

    @Test("Unnumbered instances sort last, not first")
    func testUnnumberedInstancesSortLast() {
        var library = LibraryModel()
        library.addInstance(instance("x", number: nil, path: "/x.dcm"))
        library.addInstance(instance("a", number: 1, path: "/a.dcm"))

        #expect(library.instancesForSeries("1.2.3.4").map(\.filePath) == ["/a.dcm", "/x.dcm"],
                "a missing Instance Number is not instance zero")
    }

    @Test("Duplicate instance numbers still produce the same order every read")
    func testOrderIsTotal() {
        var library = LibraryModel()
        library.addInstance(instance("b", number: 1, path: "/b.dcm"))
        library.addInstance(instance("a", number: 1, path: "/a.dcm"))
        library.addInstance(instance("c", number: 1, path: "/c.dcm"))

        let first = library.instancesForSeries("1.2.3.4").map(\.filePath)
        #expect(first == ["/a.dcm", "/b.dcm", "/c.dcm"])
        // Instances come out of an unordered set; without a total order the
        // series would open on a different image between reads.
        for _ in 0..<5 {
            #expect(library.instancesForSeries("1.2.3.4").map(\.filePath) == first)
        }
    }

    @Test("A study counts the instances of every one of its series")
    func testStudyInstanceCount() {
        var library = LibraryModel()
        library.addStudy(study())
        library.addSeries(SeriesModel(seriesInstanceUID: "1.2.3.4",
                                      studyInstanceUID: "1.2.3", modality: "CT"))
        library.addSeries(SeriesModel(seriesInstanceUID: "1.2.3.5",
                                      studyInstanceUID: "1.2.3", modality: "CT"))
        library.addInstance(instance("a", number: 1, path: "/a.dcm"))
        library.addInstance(instance("b", number: 2, path: "/b.dcm"))
        library.addInstance(InstanceModel(
            sopInstanceUID: "c",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.5",
            instanceNumber: 1,
            filePath: "/c.dcm"))

        #expect(library.instanceCount(forStudy: "1.2.3") == 3)
        #expect(library.instanceCount(forStudy: "nope") == 0)
    }

    // MARK: - Studies with nothing in them

    @Test("A study with no instances is dropped rather than listed")
    func testPruneEmptyStudies() {
        var library = LibraryModel()
        library.addStudy(study(description: "Ghost"))
        library.addSeries(SeriesModel(seriesInstanceUID: "1.2.3.4",
                                      studyInstanceUID: "1.2.3", modality: "CT"))

        #expect(library.pruneEmptyStudies() == 1)
        #expect(library.studies.isEmpty)
        #expect(library.series.isEmpty, "its empty series goes with it")
    }

    @Test("A study with instances survives pruning")
    func testPruneKeepsRealStudies() {
        var library = LibraryModel()
        library.addStudy(study(description: "Real"))
        library.addSeries(SeriesModel(seriesInstanceUID: "1.2.3.4",
                                      studyInstanceUID: "1.2.3", modality: "CT"))
        library.addInstance(instance("a", number: 1, path: "/a.dcm"))

        #expect(library.pruneEmptyStudies() == 0)
        #expect(library.studies.count == 1)
        #expect(library.seriesForStudy("1.2.3").count == 1)
    }

    @Test("A study with no patient name is identified by what it does carry")
    func testDisplayNameFallsBack() {
        let byID = StudyModel(studyInstanceUID: "1", patientID: "711794")
        #expect(byID.displayPatientName == "711794")

        let byDescription = StudyModel(studyInstanceUID: "1",
                                       studyDescription: "Brain_ASPECT(Adult)")
        #expect(byDescription.displayPatientName == "Brain_ASPECT(Adult)")

        // Nothing at all to go on is the only case that says "Unknown".
        #expect(StudyModel(studyInstanceUID: "1").displayPatientName == "Unknown Patient")
        // A real name still wins, reordered for reading.
        #expect(StudyModel(studyInstanceUID: "1", patientName: "DOE^JANE",
                           patientID: "711794").displayPatientName == "DOE, JANE")
    }

    // MARK: - Integer strings

    private func dataSet(_ values: [(UInt16, UInt16, String)]) -> DataSet {
        DataSet(elements: values.map { group, element, value in
            let padded = value.count % 2 == 0 ? value : value + " "
            let data = Data(padded.utf8)
            return DataElement(
                tag: Tag(group: group, element: element), vr: .IS,
                length: UInt32(data.count), valueData: data)
        })
    }

    @Test("Series and Instance Number are read from IS, which is text not binary")
    func testIntegerStringParsing() {
        // The bug: these were read with `int32(for:)`, which decodes binary SL
        // only. Every series and instance came back unnumbered, so the pane and
        // the stack fell back to alphabetical and file-system order.
        let set = dataSet([
            (0x0020, 0x0011, "7"),
            (0x0020, 0x0013, "142")
        ])
        #expect(DICOMFileService.integerString(in: set, tag: .seriesNumber) == 7)
        #expect(DICOMFileService.integerString(in: set, tag: .instanceNumber) == 142)
    }

    @Test("Padded, signed and multi-valued integer strings still read")
    func testIntegerStringVariants() {
        #expect(DICOMFileService.integerString(
            in: dataSet([(0x0020, 0x0011, " 7 ")]), tag: .seriesNumber) == 7)
        #expect(DICOMFileService.integerString(
            in: dataSet([(0x0020, 0x0011, "+7")]), tag: .seriesNumber) == 7)
        #expect(DICOMFileService.integerString(
            in: dataSet([(0x0020, 0x0011, "-1")]), tag: .seriesNumber) == -1)
        #expect(DICOMFileService.integerString(
            in: dataSet([(0x0020, 0x0011, "3\\4")]), tag: .seriesNumber) == 3)
    }

    @Test("A missing or unreadable number stays nil rather than becoming zero")
    func testIntegerStringAbsent() {
        #expect(DICOMFileService.integerString(in: DataSet(), tag: .seriesNumber) == nil)
        #expect(DICOMFileService.integerString(
            in: dataSet([(0x0020, 0x0011, "n/a")]), tag: .seriesNumber) == nil)
    }

    // MARK: - Dates

    @Test("Study dates are read in the forms files actually carry")
    func testDateParsing() {
        #expect(DICOMFileService.parseDICOMDate("20251015") != nil)
        #expect(DICOMFileService.parseDICOMDate("2025.10.15") != nil)
        #expect(DICOMFileService.parseDICOMDate("2025-10-15") != nil)
        // A date with a time stuck to it still starts with a date.
        #expect(DICOMFileService.parseDICOMDate("20251015120000") != nil)
        #expect(DICOMFileService.parseDICOMDate("") == nil)
        #expect(DICOMFileService.parseDICOMDate("not a date") == nil)
    }

    @Test("The three date forms agree on the same day")
    func testDateFormsAgree() throws {
        let dashed = try #require(DICOMFileService.parseDICOMDate("2025-10-15"))
        let dotted = try #require(DICOMFileService.parseDICOMDate("2025.10.15"))
        let plain = try #require(DICOMFileService.parseDICOMDate("20251015"))
        #expect(dashed == plain)
        #expect(dotted == plain)
    }
}
