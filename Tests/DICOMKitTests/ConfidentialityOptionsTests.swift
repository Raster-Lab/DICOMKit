import XCTest
import Foundation
import DICOMCore
import DICOMDictionary
@testable import DICOMKit

/// PS3.15 2026a Annex E options and recording rows closed 2026-10-01: Clean Descriptors
/// (E.3.5, D158), Modified Dates (E.3.6, D157), (0028,0303) (E.2 / E.3.6, D161), Retain
/// Safe Private (E.3.10) and Clean Graphics (E.3.3) (D159), and the legacy Anonymizer's
/// keyword parsing (D163) and --keep (D164).
final class ConfidentialityOptionsTests: XCTestCase {

    private let studyDescription = Tag(group: 0x0008, element: 0x1030)
    private let studyComments = Tag(group: 0x0032, element: 0x4000)
    private let temporalModified = Tag(group: 0x0028, element: 0x0303)

    private func dataSet() -> DataSet {
        var ds = DataSet()
        ds.setString("DOE^JOHN", for: .patientName, vr: .PN)
        ds.setString("MRN12345", for: .patientID, vr: .LO)
        ds.setString("19800101", for: .patientBirthDate, vr: .DA)
        ds.setString("General Hospital", for: .institutionName, vr: .LO)
        ds.setString("CT chest - Dr. Smith", for: studyDescription, vr: .LO)
        ds.setString("Seen 1980-01-01, John Doe (MRN12345) at General Hospital; MR follow-up", for: studyComments, vr: .LT)
        ds.setString("20240102", for: .studyDate, vr: .DA)
        ds.setString("101500", for: .studyTime, vr: .TM)
        ds.setString("20240102101500.5+0100", for: Tag(group: 0x0008, element: 0x002A), vr: .DT)  // Acquisition DateTime
        ds.setString("+0100", for: Tag(group: 0x0008, element: 0x0201), vr: .SH)  // Timezone Offset From UTC
        return ds
    }

    // MARK: - D158 Clean Descriptors

    /// E.3.5: identifying information embedded in descriptors is removed, not kept verbatim;
    /// MR (a modality) survives because it is not a title before a name.
    func testCleanDescriptorsRemovesEmbeddedIdentifiers() {
        var engine = ConfidentialityEngine(options: .init(cleanDescriptors: true))
        let (out, changed) = engine.deidentify(dataSet())
        XCTAssertEqual(out.string(for: studyDescription), "CT chest -")
        XCTAssertEqual(out.string(for: studyComments), "Seen , () at ; MR follow-up")
        XCTAssertTrue(changed.contains(studyComments))
        let codes = (out.sequence(for: Tag(group: 0x0012, element: 0x0064)) ?? []).compactMap { $0.string(for: .codeValue) }
        XCTAssertEqual(codes, ["113100", "113105"])
    }

    /// A descriptor with nothing identifying is kept unchanged (and not reported as changed).
    func testCleanDescriptorsKeepsSafeText() {
        var ds = dataSet()
        ds.setString("CT chest abdomen pelvis", for: studyDescription, vr: .LO)
        var engine = ConfidentialityEngine(options: .init(cleanDescriptors: true))
        let (out, changed) = engine.deidentify(ds)
        XCTAssertEqual(out.string(for: studyDescription), "CT chest abdomen pelvis")
        XCTAssertFalse(changed.contains(studyDescription))
    }

    /// A C sequence keeps its Items with their text cleaned (Reason for Visit Code Sequence).
    func testCleanDescriptorsCleansTextInsideSequences() throws {
        var ds = dataSet()
        var item = DataSet()
        item.setString("Follow-up for John Doe", for: .codeMeaning, vr: .LO)
        ds.setSequence([SequenceItem(elements: item.tags.compactMap { item[$0] })],
                       for: Tag(group: 0x0032, element: 0x1067))
        var engine = ConfidentialityEngine(options: .init(cleanDescriptors: true))
        let (out, _) = engine.deidentify(ds)
        let items = try XCTUnwrap(out.sequence(for: Tag(group: 0x0032, element: 0x1067)))
        XCTAssertEqual(items.first?.string(for: .codeMeaning), "Follow-up for")
    }

    func testWithoutCleanDescriptorsTheDescriptorIsRemoved() {
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(dataSet())
        XCTAssertNil(out[studyDescription], "Table E.1-1 basic X")
    }

    // MARK: - D157 Modified Dates

    func testModifiedDatesShiftDAAndDTKeepTM() {
        var engine = ConfidentialityEngine(options: .init(retainLongitudinalTemporal: true, dateOffsetDays: -3))
        let (out, _) = engine.deidentify(dataSet())
        XCTAssertEqual(out.string(for: .studyDate), "20231230")
        XCTAssertEqual(out.string(for: Tag(group: 0x0008, element: 0x002A)), "20231230101500.5+0100",
                       "the DT date part shifts; time and offset kept")
        XCTAssertEqual(out.string(for: .studyTime), "101500", "a whole-day shift keeps the time of day")
        XCTAssertNil(out[Tag(group: 0x0008, element: 0x0201)], "Timezone Offset From UTC: Basic Profile X")
        XCTAssertEqual(out.string(for: .patientBirthDate), "", "no Modified Dates entry: Z")
    }

    /// Whole days in UTC: a shift across a daylight-saving change keeps the date arithmetic exact.
    func testShiftDICOMDate() {
        XCTAssertEqual(ConfidentialityEngine.shiftDICOMDate("20240331", byDays: 1), "20240401")
        XCTAssertEqual(ConfidentialityEngine.shiftDICOMDate("20241027", byDays: -1), "20241026")
        XCTAssertEqual(ConfidentialityEngine.shiftDICOMDate("20240229", byDays: 365), "20250228")
        XCTAssertNil(ConfidentialityEngine.shiftDICOMDate("2024", byDays: 1))
        XCTAssertNil(ConfidentialityEngine.shiftDICOMDateTime("202401", byDays: 1))
    }

    // MARK: - D161 (0028,0303)

    /// PS3.3 Table C.7-1 Enumerated Values; PS3.15 E.2 and E.3.6.
    func testLongitudinalTemporalInformationModified() {
        func value(_ options: ConfidentialityProfile.Options) -> (String?, VR?) {
            var engine = ConfidentialityEngine(options: options)
            let out = engine.deidentify(dataSet()).0
            return (out.string(for: temporalModified), out[temporalModified]?.vr)
        }
        XCTAssertEqual(value(.basic).0, "REMOVED")
        XCTAssertEqual(value(.basic).1, .CS)
        XCTAssertEqual(value(.init(retainLongitudinalTemporal: true)).0, "UNMODIFIED")
        XCTAssertEqual(value(.init(retainLongitudinalTemporal: true, dateOffsetDays: 5)).0, "MODIFIED")
    }

    // MARK: - D159 Retain Safe Private, Clean Graphics

    /// Table E.3.10-1 rows (dumped by Scripts/generate_confidentiality_profile.py):
    /// (0019,xx23) GEMS_ACQU_01 DS "Table Speed [mm/rotation]"; (7053,xx00) Philips PET
    /// Private Group DS "SUV Factor"; 479 rows in all.
    func testSafePrivateTableIsE3101() {
        XCTAssertEqual(ConfidentialityProfile.safePrivateAttributes.count, 479)
        XCTAssertEqual(ConfidentialityProfile.safePrivateAttributes["GEMS_ACQU_01|0019|23"], "DS")
        XCTAssertEqual(ConfidentialityProfile.safePrivateAttributes["Philips PET Private Group|7053|00"], "DS")
    }

    private func privateDataSet() -> DataSet {
        var ds = DataSet()
        ds.setString("DOE^JOHN", for: .patientName, vr: .PN)
        // Block 10 of group 0019: GE acquisition (Table Speed is listed safe).
        ds.setString("GEMS_ACQU_01", for: Tag(group: 0x0019, element: 0x0010), vr: .LO)
        ds.setString("12.5", for: Tag(group: 0x0019, element: 0x1023), vr: .DS)
        ds.setString("DOE JOHN", for: Tag(group: 0x0019, element: 0x1030), vr: .LO)  // not listed
        // Block 10 of group 0029: declared in (0008,0300) as MIXED, element 01 safe, 02 Z.
        ds.setString("ACME 1.0", for: Tag(group: 0x0029, element: 0x0010), vr: .LO)
        ds.setString("SAFE VALUE", for: Tag(group: 0x0029, element: 0x1001), vr: .LO)
        ds.setString("OPERATOR", for: Tag(group: 0x0029, element: 0x1002), vr: .LO)
        ds.setString("OTHER", for: Tag(group: 0x0029, element: 0x1003), vr: .LO)
        // Block 10 of group 0031: nothing safe, so its creator goes too.
        ds.setString("UNKNOWN", for: Tag(group: 0x0031, element: 0x0010), vr: .LO)
        ds.setString("SECRET", for: Tag(group: 0x0031, element: 0x1001), vr: .LO)
        var action = DataSet()
        action[Tag(group: 0x0008, element: 0x0306)] = .uint16s(tag: Tag(group: 0x0008, element: 0x0306), values: [0x02])
        action.setString("Z", for: Tag(group: 0x0008, element: 0x0307), vr: .CS)
        var declaration = DataSet()
        declaration[Tag(group: 0x0008, element: 0x0301)] = .uint16s(tag: Tag(group: 0x0008, element: 0x0301), values: [0x0029])
        declaration.setString("ACME 1.0", for: Tag(group: 0x0008, element: 0x0302), vr: .LO)
        declaration.setString("MIXED", for: Tag(group: 0x0008, element: 0x0303), vr: .CS)
        declaration[Tag(group: 0x0008, element: 0x0304)] = .uint16s(tag: Tag(group: 0x0008, element: 0x0304), values: [0x01])
        declaration.setSequence([SequenceItem(elements: action.tags.compactMap { action[$0] })],
                                for: Tag(group: 0x0008, element: 0x0305))
        ds.setSequence([SequenceItem(elements: declaration.tags.compactMap { declaration[$0] })],
                       for: Tag(group: 0x0008, element: 0x0300))
        return ds
    }

    /// PS3.15 E.3.10: safe Private Attributes are kept with their Private Creator; others go.
    func testRetainSafePrivate() {
        var engine = ConfidentialityEngine(options: .init(retainSafePrivate: true))
        let (out, _) = engine.deidentify(privateDataSet())
        XCTAssertEqual(out.string(for: Tag(group: 0x0019, element: 0x0010)), "GEMS_ACQU_01")
        XCTAssertEqual(out.string(for: Tag(group: 0x0019, element: 0x1023)), "12.5", "Table E.3.10-1")
        XCTAssertNil(out[Tag(group: 0x0019, element: 0x1030)], "not listed: removed")
        XCTAssertEqual(out.string(for: Tag(group: 0x0029, element: 0x1001)), "SAFE VALUE", "(0008,0304)")
        XCTAssertEqual(out.string(for: Tag(group: 0x0029, element: 0x1002)), "", "(0008,0307) Z")
        XCTAssertNil(out[Tag(group: 0x0029, element: 0x1003)])
        XCTAssertNil(out[Tag(group: 0x0031, element: 0x0010)], "a creator with nothing kept goes")
        XCTAssertNil(out[Tag(group: 0x0031, element: 0x1001)])
        let codes = (out.sequence(for: Tag(group: 0x0012, element: 0x0064)) ?? []).compactMap { $0.string(for: .codeValue) }
        XCTAssertEqual(codes, ["113100", "113111"])

        var basic = ConfidentialityEngine()
        let removed = basic.deidentify(privateDataSet()).0
        XCTAssertTrue(removed.tags.allSatisfy { $0.group & 1 == 0 }, "without the Option every private attribute goes")
    }

    /// PS3.15 E.3.3: Graphic Annotation Sequence kept, its text cleaned (not a dummy).
    func testCleanGraphics() throws {
        var text = DataSet()
        text.setString("Patient DOE JOHN, MRN12345", for: Tag(group: 0x0070, element: 0x0006), vr: .ST)
        var annotation = DataSet()
        annotation.setString("LAYER1", for: Tag(group: 0x0070, element: 0x0002), vr: .CS)
        annotation.setSequence([SequenceItem(elements: text.tags.compactMap { text[$0] })],
                               for: Tag(group: 0x0070, element: 0x0008))
        var ds = dataSet()
        ds.setSequence([SequenceItem(elements: annotation.tags.compactMap { annotation[$0] })],
                       for: Tag(group: 0x0070, element: 0x0001))

        var engine = ConfidentialityEngine(options: .init(cleanGraphics: true))
        let (out, _) = engine.deidentify(ds)
        let item = try XCTUnwrap(out.sequence(for: Tag(group: 0x0070, element: 0x0001))?.first)
        let textItem = try XCTUnwrap(DataSet(elements: item.allElements).sequence(for: Tag(group: 0x0070, element: 0x0008))?.first)
        XCTAssertEqual(textItem.string(for: Tag(group: 0x0070, element: 0x0006)), "Patient ,")
        let codes = (out.sequence(for: Tag(group: 0x0012, element: 0x0064)) ?? []).compactMap { $0.string(for: .codeValue) }
        XCTAssertEqual(codes, ["113100", "113103"])

        var basic = ConfidentialityEngine()
        let dummy = try XCTUnwrap(basic.deidentify(ds).0.sequence(for: Tag(group: 0x0070, element: 0x0001))?.first)
        let dummyText = try XCTUnwrap(DataSet(elements: dummy.allElements).sequence(for: Tag(group: 0x0070, element: 0x0008))?.first)
        XCTAssertEqual(dummyText.string(for: Tag(group: 0x0070, element: 0x0006)), "ANONYMIZED", "Basic Profile D")
    }

    // MARK: - D163, D164 legacy Anonymizer

    func testParseFlexibleTagTakesEveryPS36Keyword() {
        XCTAssertEqual(Anonymizer.parseFlexibleTag("PatientAge"), Tag(group: 0x0010, element: 0x1010))
        XCTAssertEqual(Anonymizer.parseFlexibleTag("AccessionNumber"), Tag(group: 0x0008, element: 0x0050))
        XCTAssertEqual(Anonymizer.parseFlexibleTag("(0010,0010)"), .patientName)
        XCTAssertNil(Anonymizer.parseFlexibleTag("patientname"), "keywords are exact")
    }

    func testKeepWinsOverTheLegacyDateShiftAndUIDs() throws {
        var ds = DataSet()
        ds.setString("20240102", for: .studyDate, vr: .DA)
        ds.setString("20240102", for: .seriesDate, vr: .DA)
        ds.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        let file = DICOMFile(fileMetaInformation: DataSet(), dataSet: ds)
        let anonymizer = Anonymizer(profile: .research, shiftDates: 10, regenerateUIDs: true,
                                    preserveTags: [.studyDate, .studyInstanceUID])
        let (out, _) = try anonymizer.anonymize(file: file, filePath: "x")
        XCTAssertEqual(out.dataSet.string(for: .studyDate), "20240102")
        XCTAssertEqual(out.dataSet.string(for: .seriesDate), "20240112")
        XCTAssertEqual(out.dataSet.string(for: .studyInstanceUID), "1.2.3")
    }
}
