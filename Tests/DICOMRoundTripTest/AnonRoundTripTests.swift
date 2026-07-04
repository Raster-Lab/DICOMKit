// AnonRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-anon` tool.
// Tests exercise the DICOMKit `Anonymizer` library directly (never the CLI binary).

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class AnonRoundTripTests: XCTestCase {

    // MARK: - Private helpers

    /// Builds a small MONOCHROME2 fixture seeded with identifiable PHI so the
    /// anonymizer has real values to remove / replace / hash.
    private func makePHIFixture(
        patientName: String = "John^Smith",
        patientID: String = "MRN-123",
        birthDate: String = "19800101",
        studyDate: String = "20200101"
    ) -> DICOMFile {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setString(patientName, for: .patientName, vr: .PN)
        ds.setString(patientID, for: .patientID, vr: .LO)
        ds.setString(birthDate, for: .patientBirthDate, vr: .DA)
        ds.setString(studyDate, for: .studyDate, vr: .DA)
        ds.setString("General Hospital", for: .institutionName, vr: .LO)
        ds.setUInt16(4, for: .rows)
        ds.setUInt16(4, for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        let count = 16
        let pixels = Data((0..<count).map { UInt8($0 % 256) })
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
        return DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")
    }

    // MARK: - Tests

    // Oracle: basic profile removes/replaces PHI — PatientName != original, DOB
    // absent (removed when no date-shift), PatientID replaced, all != source values.
    func testBasicProfileRemovesPHI() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: false)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        // PatientName replaced with the dummy "ANONYMOUS" (default action for name).
        XCTAssertNotEqual(out.dataSet.string(for: .patientName), "John^Smith")
        XCTAssertEqual(out.dataSet.string(for: .patientName), "ANONYMOUS")

        // PatientID hashed → present but different from the original MRN.
        let anonID = out.dataSet.string(for: .patientID)
        XCTAssertNotNil(anonID)
        XCTAssertNotEqual(anonID, "MRN-123")

        // PatientBirthDate is a date tag with no shift configured → removed.
        XCTAssertNil(out.dataSet[.patientBirthDate])

        // Institution name is in the basic profile → removed.
        XCTAssertNil(out.dataSet[.institutionName])
    }

    // Oracle: every changed tag is reported exactly once in result.changedTags.
    func testChangedTagsReportedOncePerTag() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: true)
        let (_, result) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        XCTAssertTrue(result.success)
        let unique = Set(result.changedTags)
        XCTAssertEqual(unique.count, result.changedTags.count,
                       "no tag should appear more than once in changedTags")
        // Patient name was present and changed → must be reported.
        XCTAssertTrue(result.changedTags.contains(.patientName))
    }

    // Oracle: non-PHI tags (Modality, Rows, BitsAllocated) are untouched.
    func testNonPHITagsPreserved() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: true)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        XCTAssertEqual(out.dataSet.string(for: .modality), src.dataSet.string(for: .modality))
        XCTAssertEqual(out.dataSet.uint16(for: .rows), src.dataSet.uint16(for: .rows))
        XCTAssertEqual(out.dataSet.uint16(for: .columns), src.dataSet.uint16(for: .columns))
        XCTAssertEqual(out.dataSet.uint16(for: .bitsAllocated), src.dataSet.uint16(for: .bitsAllocated))
    }

    // Oracle: pixel bytes are byte-for-byte identical after anonymization.
    func testPixelDataUnchanged() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: true)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        XCTAssertEqual(pixelBytes(out), pixelBytes(src))
    }

    // Oracle: regenerateUIDs=true → study/series/SOP UIDs all change; with
    // regenerateUIDs=false and no custom UID action they remain equal (retain-UID).
    func testUIDRegenerationVsRetain() throws {
        let src = makePHIFixture()

        // Retain: basic profile does not touch UID tags when regeneration is off.
        let retain = Anonymizer(profile: .basic, regenerateUIDs: false)
        let (retainOut, _) = try retain.anonymize(file: src, filePath: "in.dcm")
        XCTAssertEqual(retainOut.dataSet.string(for: .sopInstanceUID),
                       src.dataSet.string(for: .sopInstanceUID))
        XCTAssertEqual(retainOut.dataSet.string(for: .studyInstanceUID),
                       src.dataSet.string(for: .studyInstanceUID))

        // Regenerate: all three UIDs differ from the originals.
        let regen = Anonymizer(profile: .basic, regenerateUIDs: true)
        let (regenOut, _) = try regen.anonymize(file: src, filePath: "in.dcm")
        XCTAssertNotEqual(regenOut.dataSet.string(for: .sopInstanceUID),
                          src.dataSet.string(for: .sopInstanceUID))
        XCTAssertNotEqual(regenOut.dataSet.string(for: .studyInstanceUID),
                          src.dataSet.string(for: .studyInstanceUID))
        XCTAssertNotEqual(regenOut.dataSet.string(for: .seriesInstanceUID),
                          src.dataSet.string(for: .seriesInstanceUID))
    }

    // Oracle: UID mapping is a deterministic 1:1 map — identical original UIDs
    // (study==series here) regenerate to identical new UIDs within one instance.
    func testUIDMappingIsConsistentWithinInstance() throws {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.999", for: .sopInstanceUID, vr: .UI)
        // Study and series share the SAME original UID.
        ds.setString("1.2.3.4.5.777", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.777", for: .seriesInstanceUID, vr: .UI)
        let src = DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")

        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: true)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        let newStudy = out.dataSet.string(for: .studyInstanceUID)
        let newSeries = out.dataSet.string(for: .seriesInstanceUID)
        XCTAssertNotNil(newStudy)
        // Same original UID → same regenerated UID.
        XCTAssertEqual(newStudy, newSeries)
        XCTAssertNotEqual(newStudy, "1.2.3.4.5.777")
    }

    // Oracle: --shift-dates preserves YYYYMMDD format; 20200101 + 30 == 20200131.
    func testShiftDatesPreservesFormatAndOffset() throws {
        let src = makePHIFixture(studyDate: "20200101")
        let anonymizer = Anonymizer(profile: .basic, shiftDates: 30, regenerateUIDs: false)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        let shifted = out.dataSet.string(for: .studyDate)
        XCTAssertEqual(shifted, "20200131")
    }

    // Oracle: --replace TAG=VALUE (customActions .replaceWithDummy) sets the exact value.
    func testReplaceCustomActionSetsExactValue() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(
            profile: .research,
            regenerateUIDs: false,
            customActions: [.patientBirthDate: .replaceWithDummy("19700101")]
        )
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")
        XCTAssertEqual(out.dataSet.string(for: .patientBirthDate), "19700101")
    }

    // Oracle: --remove TAG (customActions .remove) drops a tag not in the profile.
    func testRemoveCustomActionDropsArbitraryTag() throws {
        let src = makePHIFixture()
        // studyDate is NOT in the research profile; a custom .remove must still drop it.
        XCTAssertNotNil(src.dataSet[.studyDate])
        let anonymizer = Anonymizer(
            profile: .research,
            regenerateUIDs: false,
            customActions: [.studyDate: .remove]
        )
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")
        XCTAssertNil(out.dataSet[.studyDate])
    }

    // Oracle: --keep (preserveTags) excludes a tag from anonymization; it survives
    // unchanged even though the profile would otherwise remove/replace it.
    func testPreserveTagsKeepsOriginalValue() throws {
        let src = makePHIFixture(patientName: "John^Smith")
        let anonymizer = Anonymizer(
            profile: .basic,
            regenerateUIDs: false,
            preserveTags: [.patientName]
        )
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")
        XCTAssertEqual(out.dataSet.string(for: .patientName), "John^Smith")
    }

    // Oracle: same input + same anonymizer config produce identical output for
    // non-UID/non-random fields — hashed PatientID is deterministic (SHA-256).
    func testHashIsDeterministic() throws {
        let src = makePHIFixture(patientID: "MRN-123")
        let a1 = Anonymizer(profile: .basic, regenerateUIDs: false)
        let a2 = Anonymizer(profile: .basic, regenerateUIDs: false)
        let (o1, _) = try a1.anonymize(file: src, filePath: "in.dcm")
        let (o2, _) = try a2.anonymize(file: src, filePath: "in.dcm")
        XCTAssertEqual(o1.dataSet.string(for: .patientID), o2.dataSet.string(for: .patientID))
        XCTAssertNotNil(o1.dataSet.string(for: .patientID))
    }

    // Oracle: audit log records one entry per change and writes deterministically to disk.
    func testAuditLogRecordsChanges() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: true)
        let (_, result) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        let log = anonymizer.getAuditLog()
        // One audit entry per changed tag.
        XCTAssertEqual(log.count, result.changedTags.count)
        XCTAssertTrue(log.allSatisfy { $0.filePath == "in.dcm" })

        // writeAuditLog must succeed and produce a non-empty, header-bearing file.
        let dir = try makeTempDir()
        let logURL = dir.appendingPathComponent("audit.log")
        try anonymizer.writeAuditLog(to: logURL)
        let text = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(text.contains("DICOM Anonymization Audit Log"))
    }

    // Oracle: anonymized file round-trips through write()/read() and the anonymized
    // PHI values persist across serialization (PatientName stays "ANONYMOUS").
    func testAnonymizedFileRoundTripsThroughDisk() throws {
        let src = makePHIFixture()
        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: false)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "in.dcm")

        let data = try out.write()
        let reread = try DICOMFile.read(from: data, force: false)
        XCTAssertEqual(reread.dataSet.string(for: .patientName), "ANONYMOUS")
        XCTAssertNil(reread.dataSet[.patientBirthDate])
        // Pixel bytes survive the write/read round trip unchanged.
        XCTAssertEqual(pixelBytes(reread), pixelBytes(src))
    }

    // Oracle (corpus / realism): anonymizing a real Implicit-VR-LE MR file removes
    // PatientName and preserves Modality + pixel bytes.
    func testCorpusMRAnonymizationPreservesPixelsAndModality() throws {
        let f = try loadCorpus(.mr)
        try XCTSkipIf(f == nil, "corpus absent")
        let src = try XCTUnwrap(f)

        let originalModality = src.dataSet.string(for: .modality)
        let originalPixels = pixelBytes(src)

        let anonymizer = Anonymizer(profile: .basic, regenerateUIDs: false)
        let (out, _) = try anonymizer.anonymize(file: src, filePath: "MR.dcm")

        // Modality (non-PHI) unchanged.
        XCTAssertEqual(out.dataSet.string(for: .modality), originalModality)
        // Pixel data untouched.
        XCTAssertEqual(pixelBytes(out), originalPixels)
        // If the source carries a PatientName element, basic profile replaces it
        // with the dummy "ANONYMOUS" (idempotent on the already-anonymized corpus).
        if src.dataSet[.patientName] != nil {
            XCTAssertEqual(out.dataSet.string(for: .patientName), "ANONYMOUS")
        }
    }

    // MARK: - Oracle: clinical-trial profile removes date/time tags basic preserves

    /// Fixture carrying study/series date+time — the tags the clinical-trial profile
    /// targets on top of the basic PHI set.
    private func makeDatedFixture() -> DICOMFile {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setString("John^Smith", for: .patientName, vr: .PN)
        ds.setString("20200101", for: .studyDate, vr: .DA)
        ds.setString("20200102", for: .seriesDate, vr: .DA)
        ds.setString("120000", for: .studyTime, vr: .TM)
        ds.setString("130000", for: .seriesTime, vr: .TM)
        return DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")
    }

    // Oracle: the clinical-trial profile's distinctive behavior — it removes the
    // study/series date+time tags (default action for a date/time tag with no shift
    // is .remove), whereas the basic profile leaves those exact tags untouched. A
    // differential assertion proves the profile is wired to its own tag-action set.
    func testClinicalTrialProfileRemovesDateTimeTagsBasicPreserves() throws {
        // Basic: study/series date+time survive (not in the basic set, no shift).
        let basic = Anonymizer(profile: .basic, regenerateUIDs: false)
        let (basicOut, _) = try basic.anonymize(file: makeDatedFixture(), filePath: "in.dcm")
        XCTAssertEqual(basicOut.dataSet.string(for: .studyDate), "20200101",
                       "basic profile must not touch StudyDate")
        XCTAssertEqual(basicOut.dataSet.string(for: .studyTime), "120000",
                       "basic profile must not touch StudyTime")
        XCTAssertEqual(basicOut.dataSet.string(for: .seriesDate), "20200102")
        XCTAssertEqual(basicOut.dataSet.string(for: .seriesTime), "130000")

        // Clinical-trial: study/series date+time are all removed …
        let ct = Anonymizer(profile: .clinicalTrial, regenerateUIDs: false)
        let (ctOut, _) = try ct.anonymize(file: makeDatedFixture(), filePath: "in.dcm")
        XCTAssertNil(ctOut.dataSet[.studyDate], "clinical-trial must remove StudyDate")
        XCTAssertNil(ctOut.dataSet[.seriesDate], "clinical-trial must remove SeriesDate")
        XCTAssertNil(ctOut.dataSet[.studyTime], "clinical-trial must remove StudyTime")
        XCTAssertNil(ctOut.dataSet[.seriesTime], "clinical-trial must remove SeriesTime")
        // … while still applying the basic PHI removal (PatientName → ANONYMOUS).
        XCTAssertEqual(ctOut.dataSet.string(for: .patientName), "ANONYMOUS")
    }

    // Oracle: with a date shift configured, the clinical-trial profile *shifts* its
    // date tags (YYYYMMDD preserved, +offset applied) rather than removing them —
    // 20200101 + 30 == 20200131 — confirming the shift path overrides the default
    // remove for the profile's extended date set.
    func testClinicalTrialProfileShiftsDatesWhenOffsetGiven() throws {
        let ct = Anonymizer(profile: .clinicalTrial, shiftDates: 30, regenerateUIDs: false)
        let (out, _) = try ct.anonymize(file: makeDatedFixture(), filePath: "in.dcm")
        XCTAssertEqual(out.dataSet.string(for: .studyDate), "20200131",
                       "clinical-trial + shift must shift StudyDate, not remove it")
        XCTAssertEqual(out.dataSet.string(for: .seriesDate), "20200201",
                       "20200102 + 30 days == 20200201")
    }
}

