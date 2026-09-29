import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit

/// PS3.15 Annex E Basic Application Level Confidentiality Profile engine tests.
///
/// Before this engine the anonymiser removed 14 tags, did not recurse into sequences,
/// and recorded no de-identification method — the largest conformance/PHI gap in the
/// ECOSYSTEM_COMPARISON study (§4.2).
final class ConfidentialityProfileTests: XCTestCase {

    private func element(_ tag: Tag, _ vr: VR, _ value: String) -> DataElement {
        DataElement(tag: tag, vr: vr, length: UInt32(value.utf8.count), valueData: Data(value.utf8))
    }

    /// A dataset with direct identifiers at the top level and nested in a sequence.
    private func identifiedDataSet() -> DataSet {
        var ds = DataSet()
        ds[.patientName] = element(.patientName, .PN, "Doe^Jane")
        ds[.patientID] = element(.patientID, .LO, "MRN-12345")
        ds[.patientBirthDate] = element(.patientBirthDate, .DA, "19800101")
        ds[.referringPhysicianName] = element(.referringPhysicianName, .PN, "Smith^John")
        ds[.institutionName] = element(.institutionName, .LO, "General Hospital")
        ds[.deviceSerialNumber] = element(.deviceSerialNumber, .LO, "SN-999")
        ds[.studyInstanceUID] = element(.studyInstanceUID, .UI, "1.2.3.4.5")
        ds[.sopInstanceUID] = element(.sopInstanceUID, .UI, "1.2.3.4.5.6")
        ds[Tag(group: 0x0008, element: 0x0016)] = element(  // SOP Class UID — must survive
            Tag(group: 0x0008, element: 0x0016), .UI, "1.2.840.10008.5.1.4.1.1.2")
        ds[Tag(group: 0x0010, element: 0x1040)] = element(  // Patient's Address
            Tag(group: 0x0010, element: 0x1040), .LO, "1 Main St")

        // Nested identifier inside a sequence item.
        let item = SequenceItem(elements: [
            element(.performingPhysicianName, .PN, "Nested^Doctor"),
            element(.patientID, .LO, "NESTED-ID"),
        ])
        ds.setSequence([item], for: Tag(group: 0x0040, element: 0x0275)) // Request Attributes Sequence

        // A private tag carrying PHI.
        ds[Tag(group: 0x0009, element: 0x0010)] = element(
            Tag(group: 0x0009, element: 0x0010), .LO, "PRIVATE PHI")
        return ds
    }

    // MARK: - Core actions

    func testDirectIdentifiersRemovedOrZeroed() {
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(identifiedDataSet())

        // Z actions → present but empty.
        XCTAssertEqual(out.string(for: .patientName), "")
        XCTAssertEqual(out.string(for: .patientID), "")
        // X actions → removed entirely.
        XCTAssertNil(out[Tag(group: 0x0010, element: 0x1040)], "Patient's Address must be removed")
        XCTAssertNil(out[.deviceSerialNumber], "Device Serial Number must be removed")
        XCTAssertNil(out[.institutionName], "Institution Name must be removed")
        XCTAssertNil(out[.performingPhysicianName], "Performing Physician removed at top level")
        // Referring Physician is Z (identity is required-empty, not absent).
        XCTAssertEqual(out.string(for: .referringPhysicianName), "")
    }

    func testSequencesAreRecursivelyScrubbed() {
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(identifiedDataSet())

        guard let item = out.sequence(for: Tag(group: 0x0040, element: 0x0275))?.first else {
            return XCTFail("Request Attributes Sequence missing after de-identification")
        }
        // Nested PN removed by VR sweep; nested PatientID zeroed by the table.
        XCTAssertNil(item[.performingPhysicianName], "nested PN must be scrubbed")
        XCTAssertEqual(item.string(for: .patientID), "", "nested PatientID must be zeroed")
    }

    func testInstanceUIDsRegeneratedButClassUIDPreserved() {
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(identifiedDataSet())

        XCTAssertNotEqual(out.string(for: .studyInstanceUID), "1.2.3.4.5",
                          "instance UID must be regenerated")
        XCTAssertNotNil(out.string(for: .studyInstanceUID))
        XCTAssertEqual(out.string(for: Tag(group: 0x0008, element: 0x0016)),
                       "1.2.840.10008.5.1.4.1.1.2",
                       "SOP Class UID must NOT be regenerated")
    }

    func testUIDRegenerationIsConsistent() {
        // Same input UID appearing twice must map to the same output UID.
        var ds = DataSet()
        ds[.studyInstanceUID] = element(.studyInstanceUID, .UI, "1.2.3")
        ds[Tag(group: 0x0020, element: 0x0052)] = element(  // Frame of Reference UID
            Tag(group: 0x0020, element: 0x0052), .UI, "1.2.3")

        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(ds)
        XCTAssertEqual(out.string(for: .studyInstanceUID),
                       out.string(for: Tag(group: 0x0020, element: 0x0052)),
                       "identical input UIDs must remap identically (referential integrity)")
    }

    func testPrivateTagsRemoved() {
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(identifiedDataSet())
        XCTAssertNil(out[Tag(group: 0x0009, element: 0x0010)],
                     "private tags must be removed by default")
    }

    func testMethodAttributesRecorded() {
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(identifiedDataSet())
        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "YES",
                       "(0012,0062) Patient Identity Removed = YES")
        let method = out.string(for: Tag(group: 0x0012, element: 0x0063)) ?? ""
        XCTAssertTrue(method.contains("Basic Application Level Confidentiality Profile"),
                      "(0012,0063) De-identification Method must name the profile")
    }

    // MARK: - Options

    func testRetainLongitudinalTemporalKeepsBirthDate() {
        let options = ConfidentialityProfile.Options(retainLongitudinalTemporal: true)
        var engine = ConfidentialityEngine(options: options)
        let (out, _) = engine.deidentify(identifiedDataSet())
        XCTAssertEqual(out.string(for: .patientBirthDate), "19800101",
                       "birth date retained under Retain Longitudinal Temporal")
    }

    func testDateOffsetShiftsRatherThanZeroes() {
        var ds = DataSet()
        ds[Tag(group: 0x0008, element: 0x0020)] = element(  // Study Date
            Tag(group: 0x0008, element: 0x0020), .DA, "20200115")
        let options = ConfidentialityProfile.Options(
            retainLongitudinalTemporal: true, dateOffsetDays: -10)
        var engine = ConfidentialityEngine(options: options)
        let (out, _) = engine.deidentify(ds)
        XCTAssertEqual(out.string(for: Tag(group: 0x0008, element: 0x0020)), "20200105",
                       "study date must shift by the offset, not zero")
    }

    func testRetainInstitutionIdentityKeepsInstitution() {
        let options = ConfidentialityProfile.Options(retainInstitutionIdentity: true)
        var engine = ConfidentialityEngine(options: options)
        let (out, _) = engine.deidentify(identifiedDataSet())
        XCTAssertEqual(out.string(for: .institutionName), "General Hospital")
    }

    func testRetainUIDsKeepsUIDs() {
        let options = ConfidentialityProfile.Options(retainUIDs: true)
        var engine = ConfidentialityEngine(options: options)
        let (out, _) = engine.deidentify(identifiedDataSet())
        XCTAssertEqual(out.string(for: .studyInstanceUID), "1.2.3.4.5",
                       "UIDs retained under Retain UIDs")
    }

    // MARK: - Residual (pixel-borne) PHI

    /// The engine scrubs metadata only. On a clean object it may assert YES; the moment
    /// the pixels are declared to carry text it must not, or the file falsely reads as
    /// safe to release.
    func testCleanObjectAssertsPatientIdentityRemoved() {
        var engine = ConfidentialityEngine()
        let (out, _, warnings) = engine.deidentifyReportingResidualPHI(identifiedDataSet())
        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "YES")
        XCTAssertTrue(warnings.isEmpty, "no burned-in annotation or overlays → no warning")
    }

    func testBurnedInAnnotationBlocksIdentityRemovedAssertion() {
        var ds = identifiedDataSet()
        ds[.burnedInAnnotation] = element(.burnedInAnnotation, .CS, "YES")

        var engine = ConfidentialityEngine()
        let (out, _, warnings) = engine.deidentifyReportingResidualPHI(ds)

        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "NO",
            "must NOT claim identity removed when the pixels still carry text")
        XCTAssertTrue(warnings.contains { $0.contains("0028,0301") },
            "caller must be warned, naming the responsible attribute")
        XCTAssertTrue(
            out.string(for: Tag(group: 0x0012, element: 0x0063))?.contains("DATASET ONLY") == true,
            "the method record itself must state the pixels were not cleaned")
        // The metadata scrub must still have happened — this is a warning, not a bail-out.
        XCTAssertNotEqual(out.string(for: .patientName), "Doe^Jane",
            "metadata is still de-identified alongside the warning")
    }

    func testBurnedInAnnotationNoIsNotFlagged() {
        var ds = identifiedDataSet()
        ds[.burnedInAnnotation] = element(.burnedInAnnotation, .CS, "NO")
        var engine = ConfidentialityEngine()
        let (out, _, warnings) = engine.deidentifyReportingResidualPHI(ds)
        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "YES")
        XCTAssertTrue(warnings.isEmpty, "an explicit NO is a clean declaration")
    }

    /// Overlay planes are burned into the rendered image by the viewer and the film
    /// path, so identifying overlay graphics are the same leak by another route.
    func testOverlayPlaneDataIsFlagged() {
        var ds = identifiedDataSet()
        let overlayData = Tag(group: 0x6000, element: 0x3000)
        ds[overlayData] = DataElement(
            tag: overlayData, vr: .OW, length: 4, valueData: Data([0, 1, 2, 3]))

        var engine = ConfidentialityEngine()
        let (out, _, warnings) = engine.deidentifyReportingResidualPHI(ds)

        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "NO")
        XCTAssertTrue(warnings.contains { $0.contains("6000") },
            "warning must name the overlay group that triggered it")
    }

    /// Detection must sweep the whole 60xx range, not just the first plane.
    func testHighOverlayGroupIsFlagged() {
        var ds = identifiedDataSet()
        let overlayData = Tag(group: 0x601E, element: 0x3000)
        ds[overlayData] = DataElement(
            tag: overlayData, vr: .OW, length: 2, valueData: Data([0, 1]))
        let warnings = ConfidentialityEngine.residualPixelPHIWarnings(in: ds)
        XCTAssertTrue(warnings.contains { $0.contains("601E") },
            "the last legal overlay group (0x601E) must still be detected")
    }

    /// The legacy two-tuple entry point must inherit the protection, not bypass it.
    func testLegacyDeidentifyEntryPointAlsoWithholdsTheAssertion() {
        var ds = identifiedDataSet()
        ds[.burnedInAnnotation] = element(.burnedInAnnotation, .CS, "YES")
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(ds)
        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "NO",
            "the convenience overload must not silently re-introduce the false claim")
    }

    // MARK: - De-identification Method Code Sequence (PS3.15 E.1.1, PS3.16 CID 7050)

    private func methodCodes(in ds: DataSet) -> [(String, String, String)] {
        (ds.sequence(for: Tag(group: 0x0012, element: 0x0064)) ?? []).map {
            ($0.string(for: .codeValue) ?? "", $0.string(for: .codingSchemeDesignator) ?? "",
             $0.string(for: .codeMeaning) ?? "")
        }
    }

    /// Every CID 7050 row, Code Value and Code Meaning verbatim (PS3.16 2026a).
    func testCID7050CodesAndMeanings() {
        let expected: [(String, String)] = [
            ("113100", "Basic Application Confidentiality Profile"),
            ("113101", "Clean Pixel Data Option"),
            ("113102", "Clean Recognizable Visual Features Option"),
            ("113103", "Clean Graphics Option"),
            ("113104", "Clean Structured Content Option"),
            ("113105", "Clean Descriptors Option"),
            ("113106", "Retain Longitudinal Temporal Information Full Dates Option"),
            ("113107", "Retain Longitudinal Temporal Information Modified Dates Option"),
            ("113108", "Retain Patient Characteristics Option"),
            ("113109", "Retain Device Identity Option"),
            ("113110", "Retain UIDs Option"),
            ("113111", "Retain Safe Private Option"),
            ("113112", "Retain Institution Identity Option"),
        ]
        XCTAssertEqual(ConfidentialityProfile.DeidentificationMethodCode.allCases.count, expected.count)
        for (value, meaning) in expected {
            let code = ConfidentialityProfile.DeidentificationMethodCode(rawValue: value)
            XCTAssertNotNil(code, "CID 7050 code \(value) missing")
            XCTAssertEqual(code?.meaning, meaning)
            XCTAssertEqual(code?.codeValue, value)
        }
        XCTAssertEqual(ConfidentialityProfile.DeidentificationMethodCode.codingSchemeDesignator, "DCM")
    }

    func testOptionsMapToCID7050Codes() {
        XCTAssertEqual(ConfidentialityProfile.Options.basic.methodCodes, [.basicApplicationConfidentialityProfile])

        let all = ConfidentialityProfile.Options(
            retainLongitudinalTemporal: true, retainPatientCharacteristics: true,
            retainDeviceIdentity: true, retainInstitutionIdentity: true, retainUIDs: true,
            cleanDescriptors: true)
        XCTAssertEqual(all.methodCodes.map(\.codeValue),
                       ["113100", "113105", "113106", "113108", "113109", "113110", "113112"])

        // A date offset means dates are modified, not kept: 113107 instead of 113106.
        let shifted = ConfidentialityProfile.Options(retainLongitudinalTemporal: true, dateOffsetDays: 10)
        XCTAssertEqual(shifted.methodCodes.map(\.codeValue), ["113100", "113107"])
    }

    func testEngineWritesMethodCodeSequenceAndMultiValuedMethod() {
        let options = ConfidentialityProfile.Options(retainUIDs: true, cleanDescriptors: true)
        var engine = ConfidentialityEngine(options: options)
        let (out, _) = engine.deidentify(identifiedDataSet())

        XCTAssertEqual(out.string(for: Tag(group: 0x0012, element: 0x0062)), "YES")
        XCTAssertEqual(out[Tag(group: 0x0012, element: 0x0062)]?.vr, .CS)
        XCTAssertEqual(out[Tag(group: 0x0012, element: 0x0063)]?.vr, .LO)
        XCTAssertEqual(out[Tag(group: 0x0012, element: 0x0064)]?.vr, .SQ)

        let codes = methodCodes(in: out)
        XCTAssertEqual(codes.map { $0.0 }, ["113100", "113105", "113110"])
        XCTAssertTrue(codes.allSatisfy { $0.1 == "DCM" })
        XCTAssertEqual(codes.map { $0.2 },
                       ["Basic Application Confidentiality Profile", "Clean Descriptors Option", "Retain UIDs Option"])

        // (0012,0063) LO VM 1-n: one value per profile / option, each within 64 chars.
        let values = out[Tag(group: 0x0012, element: 0x0063)]?.stringValues ?? []
        XCTAssertEqual(values.count, 3)
        XCTAssertTrue(values.allSatisfy { $0.count <= 64 })
        XCTAssertEqual(values.dropFirst().map { $0 }, ["Clean Descriptors Option", "Retain UIDs Option"])
    }

    func testEngineKeepsCodesRecordedByAnEarlierPass() {
        var ds = identifiedDataSet()
        ds.setSequence([ConfidentialityProfile.DeidentificationMethodCode.cleanPixelDataOption.sequenceItem],
                       for: Tag(group: 0x0012, element: 0x0064))
        var engine = ConfidentialityEngine()
        let (out, _) = engine.deidentify(ds)
        XCTAssertEqual(methodCodes(in: out).map { $0.0 }, ["113101", "113100"])
    }

    // MARK: - Coverage sanity

    func testTableCoversAtLeastTheDirectIdentifierCore() {
        // Guardrail: the curated table must not silently shrink. This is far more than
        // the legacy 14 tags; the VR sweeps extend coverage beyond the explicit rows.
        XCTAssertGreaterThanOrEqual(ConfidentialityProfile.table.count, 60,
            "confidentiality table unexpectedly small — direct-identifier coverage regressed")
    }
}
