// TagsRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-tags` tool.
// Exercises the shared DICOMKit `TagEditor` engine directly (never spawns the CLI).
// Every assertion is a semantic invariant true by definition of the operation.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class TagsRoundTripTests: XCTestCase {

    // MARK: - Section 3.5 oracles

    // Oracle: SET a string tag → after full read→edit→write→read, PatientName == set value.
    func testSetStringTagRoundTrip() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        var ds = file.dataSet
        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: ["PatientName=Round^Trip^Test"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        let edited = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
        let reread = try DICOMFile.read(from: try edited.write())
        XCTAssertEqual(reread.dataSet.string(for: .patientName), "Round^Trip^Test")
    }

    // Oracle: DELETE a tag → output has no StudyDescription element.
    func testDeleteTagRoundTrip() throws {
        var ds = makeGrayscale8(rows: 8, cols: 8).dataSet
        ds.setString("Original", for: .studyDescription, vr: .LO)
        let file = DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertNotNil(file.dataSet[.studyDescription], "precondition: tag present")

        var mutable = file.dataSet
        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &mutable,
            sets: [], deletes: ["StudyDescription"], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        let edited = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: mutable)
        let reread = try DICOMFile.read(from: try edited.write())
        XCTAssertNil(reread.dataSet[.studyDescription])
    }

    // Oracle: SET a numeric tag by name → output SeriesNumber string == "42".
    func testSetNumericTagRoundTrip() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        var ds = file.dataSet
        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: ["SeriesNumber=42"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        let edited = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
        let reread = try DICOMFile.read(from: try edited.write())
        XCTAssertEqual(reread.dataSet.string(for: .seriesNumber), "42")
    }

    // MARK: - Extra api-map flags (real oracles)

    // Oracle: SET via hex specifier (0010,0010) resolves to the same tag as by name.
    func testSetByHexSpecifier() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        var ds = file.dataSet
        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: ["0010,0010=Hex^Name"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        XCTAssertEqual(ds.string(for: .patientName), "Hex^Name")
    }

    // Oracle: --delete-private removes every odd-group tag; non-private tags survive.
    func testDeletePrivateRemovesOnlyPrivateTags() throws {
        var ds = makeGrayscale8(rows: 4, cols: 4).dataSet
        // Inject a private tag (odd group).
        let privTag = Tag(group: 0x0009, element: 0x0010)
        ds[privTag] = DataElement.string(tag: privTag, vr: .LO, value: "PRIVATE_CREATOR")
        XCTAssertTrue(ds.tags.contains(where: { $0.isPrivate }), "precondition: a private tag exists")

        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: [], deletes: [], deletePrivate: true,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)

        XCTAssertFalse(ds.tags.contains(where: { $0.isPrivate }), "no private tag may remain")
        // A standard, non-private tag must survive.
        XCTAssertNotNil(ds[.patientName])
    }

    // Oracle: --copy-from with explicit --tags copies exactly the named tag's value.
    func testCopyFromNamedTag() throws {
        var srcDS = makeGrayscale8(rows: 4, cols: 4).dataSet
        srcDS.setString("Source^Person", for: .patientName, vr: .PN)
        srcDS.setString("Should^Not^Copy", for: .patientID, vr: .LO)

        var destDS = makeGrayscale8(rows: 4, cols: 4).dataSet
        destDS.setString("Dest^Person", for: .patientName, vr: .PN)
        let destPatientID = destDS.string(for: .patientID)

        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &destDS,
            sets: [], deletes: [], deletePrivate: false,
            sourceDataSet: srcDS, copyTags: ["PatientName"],
            verbose: false, dryRun: false)

        // Named tag copied from source.
        XCTAssertEqual(destDS.string(for: .patientName), "Source^Person")
        // Unnamed tag NOT copied — dest keeps its own value.
        XCTAssertEqual(destDS.string(for: .patientID), destPatientID)
    }

    // Oracle: --copy-from with empty copyTags copies every source tag into dest.
    func testCopyFromAllTags() throws {
        var srcDS = makeGrayscale8(rows: 4, cols: 4).dataSet
        srcDS.setString("Only^In^Source", for: .studyDescription, vr: .LO)

        var destDS = makeGrayscale8(rows: 4, cols: 4).dataSet
        XCTAssertNil(destDS[.studyDescription], "precondition: dest lacks the tag")

        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &destDS,
            sets: [], deletes: [], deletePrivate: false,
            sourceDataSet: srcDS, copyTags: [],
            verbose: false, dryRun: false)

        // Every source tag now present in dest with the source value.
        for tag in srcDS.tags {
            XCTAssertEqual(destDS[tag]?.valueData, srcDS[tag]?.valueData,
                           "source tag \(tag.description) must be copied verbatim")
        }
        XCTAssertEqual(destDS.string(for: .studyDescription), "Only^In^Source")
    }

    // Oracle: an unknown tag specifier is skipped (no throw, dataSet unchanged, note emitted).
    func testUnknownTagSpecifierSkipped() throws {
        var ds = makeGrayscale8(rows: 4, cols: 4).dataSet
        let before = ds.tags
        let editor = TagEditor()
        let changes = editor.applyChanges(
            to: &ds,
            sets: ["NotARealTagKeyword=whatever"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)

        // No mutation occurred.
        XCTAssertEqual(ds.tags, before)
        // A skip note was recorded.
        XCTAssertTrue(changes.contains(where: { $0.contains("unknown tag") }))
    }

    // Oracle: dryRun=true describes changes but leaves the dataSet untouched.
    func testDryRunDoesNotMutate() throws {
        var ds = makeGrayscale8(rows: 4, cols: 4).dataSet
        let originalName = ds.string(for: .patientName)
        let editor = TagEditor()
        let changes = editor.applyChanges(
            to: &ds,
            sets: ["PatientName=Ghost^Value"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: true)

        XCTAssertEqual(ds.string(for: .patientName), originalName, "dry run must not mutate")
        XCTAssertTrue(changes.contains(where: { $0.hasPrefix("SET") }))
    }

    // Oracle: setString with an explicit VR yields an element carrying exactly that VR.
    func testSetStringPreservesExplicitVR() throws {
        var ds = makeGrayscale8(rows: 4, cols: 4).dataSet
        let editor = TagEditor()
        // StudyDescription is a fresh tag → engine uses dictionary default VR (LO).
        _ = editor.applyChanges(
            to: &ds,
            sets: ["StudyDescription=Research"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        XCTAssertEqual(ds[.studyDescription]?.vr, .LO)
        XCTAssertEqual(ds.string(for: .studyDescription), "Research")
    }

    // Oracle: editing the dataSet preserves the original File Meta transfer syntax on write.
    func testFileMetaTransferSyntaxPreserved() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let originalTS = file.transferSyntaxUID
        XCTAssertNotNil(originalTS, "precondition: input has a transfer syntax")

        var ds = file.dataSet
        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: ["PatientName=Meta^Test"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        let edited = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
        let reread = try DICOMFile.read(from: try edited.write())
        XCTAssertEqual(reread.transferSyntaxUID, originalTS)
    }

    // Oracle: order-independence of unrelated ops — a delete does not disturb an unrelated tag.
    func testUnrelatedTagsUnchangedAfterDelete() throws {
        var ds = makeGrayscale8(rows: 4, cols: 4).dataSet
        ds.setString("Keep^Me", for: .patientName, vr: .PN)
        ds.setString("Delete^Me", for: .studyDescription, vr: .LO)
        let keptBefore = ds[.patientName]?.valueData

        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: [], deletes: ["StudyDescription"], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)

        XCTAssertNil(ds[.studyDescription])
        XCTAssertEqual(ds[.patientName]?.valueData, keptBefore)
    }

    // MARK: - Corpus realism (Tier 2)

    // Oracle: on a real Implicit-VR file, edit→write→read preserves the edited value
    // and the original (implicit-VR) transfer syntax.
    func testCorpusImplicitVREditRoundTrip() throws {
        let f = try loadCorpus(.mr)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)
        let originalTS = file.transferSyntaxUID

        var ds = file.dataSet
        let editor = TagEditor()
        _ = editor.applyChanges(
            to: &ds,
            sets: ["PatientName=Corpus^Edited"],
            deletes: [], deletePrivate: false,
            sourceDataSet: nil, copyTags: [],
            verbose: false, dryRun: false)
        let edited = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
        let reread = try DICOMFile.read(from: try edited.write(), force: true)

        XCTAssertEqual(reread.dataSet.string(for: .patientName), "Corpus^Edited")
        XCTAssertEqual(reread.transferSyntaxUID, originalTS)
    }
}

