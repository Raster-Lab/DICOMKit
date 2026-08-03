// LibraryImportEndToEndTests.swift
// DICOMStudioTests
//
// Importing real files into the library and looking at the row that comes out.
//
// The unit tests either side of this one work on models; this one writes DICOM
// files to disk, imports them the way the browser does, and checks what the
// library row would say — which is where "the imported study shows only the
// patient name" was reported.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@MainActor
@Suite("Library Import End To End Tests")
struct LibraryImportEndToEndTests {

    /// A minimal but real Part 10 file. Anything passed as nil is left out of the
    /// data set entirely, which is how header-poor exports arrive.
    private func fileData(
        studyUID: String?,
        seriesUID: String,
        sopUID: String,
        modality: String?,
        seriesNumber: String?,
        instanceNumber: String?,
        patientName: String? = "VANITHA^K",
        patientID: String? = "711794",
        studyDescription: String? = nil,
        seriesDescription: String? = nil,
        studyDate: String? = "20260729"
    ) throws -> Data {
        var ds = DataSet()
        func put(_ value: String?, _ group: UInt16, _ element: UInt16, _ vr: VR) {
            guard let value else { return }
            ds.setString(value, for: Tag(group: group, element: element), vr: vr)
        }
        put("1.2.840.10008.5.1.4.1.1.2", 0x0008, 0x0016, .UI)
        put(sopUID, 0x0008, 0x0018, .UI)
        put(studyUID, 0x0020, 0x000D, .UI)
        put(seriesUID, 0x0020, 0x000E, .UI)
        put(modality, 0x0008, 0x0060, .CS)
        put(seriesNumber, 0x0020, 0x0011, .IS)
        put(instanceNumber, 0x0020, 0x0013, .IS)
        put(patientName, 0x0010, 0x0010, .PN)
        put(patientID, 0x0010, 0x0020, .LO)
        put(studyDescription, 0x0008, 0x1030, .LO)
        put(seriesDescription, 0x0008, 0x103E, .LO)
        put(studyDate, 0x0008, 0x0020, .DA)
        ds.setUInt16(64, for: Tag(group: 0x0028, element: 0x0010))
        ds.setUInt16(64, for: Tag(group: 0x0028, element: 0x0011))

        var fmi = DataSet()
        fmi.setString("1.2.840.10008.1.2.1", for: Tag(group: 0x0002, element: 0x0010), vr: .UI)
        fmi.setString("1.2.840.10008.5.1.4.1.1.2",
                      for: Tag(group: 0x0002, element: 0x0002), vr: .UI)
        fmi.setString(sopUID, for: Tag(group: 0x0002, element: 0x0003), vr: .UI)
        return try DICOMFile(fileMetaInformation: fmi, dataSet: ds).write()
    }

    private func temporaryDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("import-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ data: Data, named name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func browser() -> StudyBrowserViewModel {
        StudyBrowserViewModel(importService: ImportService(copyDirectory: nil))
    }

    @Test("A study imported across several files keeps every field any file carried")
    func testFieldsSurviveAcrossFiles() throws {
        let dir = try temporaryDirectory()
        // The CT carries the study header; the report carries none of it, which
        // is what used to overwrite the study record with a bare one.
        let ct = try write(try fileData(
            studyUID: "1.2.3", seriesUID: "1.2.3.1", sopUID: "1.2.3.1.1",
            modality: "CT", seriesNumber: "1", instanceNumber: "1",
            studyDescription: "Brain_ASPECT(Adult)"), named: "ct.dcm", in: dir)
        let sr = try write(try fileData(
            studyUID: "1.2.3", seriesUID: "1.2.3.9", sopUID: "1.2.3.9.1",
            modality: "SR", seriesNumber: "9", instanceNumber: "1",
            studyDescription: nil), named: "sr.dcm", in: dir)

        let vm = browser()
        vm.importFiles(from: [sr, ct])   // report first: order must not matter

        let study = try #require(vm.displayStudies.first)
        let summary = StudyRowSummary.make(study: study, library: vm.library)
        #expect(vm.lastError == nil)
        #expect(summary.patientName == "VANITHA, K")
        #expect(summary.description == "Brain_ASPECT(Adult)")
        #expect(summary.modalities == "CT, SR")
        #expect(summary.counts == "2 series · 2 images")
    }

    @Test("A study with no description or modality still shows what it holds")
    func testHeaderPoorStudy() throws {
        let dir = try temporaryDirectory()
        var urls: [URL] = []
        for index in 1...3 {
            urls.append(try write(try fileData(
                studyUID: "1.2.4", seriesUID: "1.2.4.1", sopUID: "1.2.4.1.\(index)",
                modality: "CT", seriesNumber: "1", instanceNumber: "\(index)",
                studyDescription: nil, seriesDescription: "HeadSeq"),
                named: "i\(index).dcm", in: dir))
        }

        let vm = browser()
        vm.importFiles(from: urls)

        let study = try #require(vm.displayStudies.first)
        let summary = StudyRowSummary.make(study: study, library: vm.library)
        #expect(summary.description == "HeadSeq", "named by its series, not left blank")
        #expect(summary.modalities == "CT")
        #expect(summary.counts == "1 series · 3 images")
    }

    @Test("Files with no Study Instance UID are filed together, not one study each")
    func testMissingStudyUIDGroupsBySeries() throws {
        let dir = try temporaryDirectory()
        var urls: [URL] = []
        for index in 1...4 {
            urls.append(try write(try fileData(
                studyUID: nil, seriesUID: "1.2.5.1", sopUID: "1.2.5.1.\(index)",
                modality: "CT", seriesNumber: "1", instanceNumber: "\(index)"),
                named: "n\(index).dcm", in: dir))
        }

        let vm = browser()
        vm.importFiles(from: urls)

        // One study of four images, not four studies of one.
        #expect(vm.displayStudies.count == 1)
        let study = try #require(vm.displayStudies.first)
        #expect(StudyRowSummary.make(study: study, library: vm.library).counts
                == "1 series · 4 images")
    }

    @Test("Re-importing the same files does not strip the study of its details")
    func testReimportKeepsDetails() throws {
        let dir = try temporaryDirectory()
        let url = try write(try fileData(
            studyUID: "1.2.6", seriesUID: "1.2.6.1", sopUID: "1.2.6.1.1",
            modality: "CT", seriesNumber: "1", instanceNumber: "1",
            studyDescription: "CT HEAD"), named: "a.dcm", in: dir)

        let vm = browser()
        vm.importFiles(from: [url])
        vm.importFiles(from: [url])

        #expect(vm.displayStudies.count == 1)
        let study = try #require(vm.displayStudies.first)
        let summary = StudyRowSummary.make(study: study, library: vm.library)
        #expect(summary.description == "CT HEAD")
        #expect(summary.counts == "1 series · 1 image")
    }
}
