//
// OptionConformanceTests.swift
// dicom-video
//
// G3 contract (2026-10-01): `convert` / `batch` warn when an option value the
// engine accepts yields an object the 2026a standard does not allow:
//   - Modality (0008,0060) "shall be" ES / GM / XC for the Video Endoscopic /
//     Microscopic / Photographic Image IODs (PS3.3 2026a A.32.5.4.1, A.32.6.4.1, A.32.7.4.1);
//   - Patient's Sex (0010,0040) Enumerated Values M, F, O (PS3.3 2026a Table C.7-1);
//   - Patient's Birth Date (0010,0030) is DA (PS3.6 2026a Table 6-1), else written empty;
//   - --transfer-syntax must be registered in PS3.6 2026a Table A-1 (the two
//     "Fragmentable HEVC" UIDs DICOMCore accepts are not).
// Also pins the VideoConsole.Help names against PS3.6 2026a Table 6-1.
//

import XCTest
import DICOMKit
import DICOMCore
@testable import dicom_video

final class OptionConformanceTests: XCTestCase {

    /// PS3.6 2026a Table A-1 rows whose name contains MPEG or HEVC (Transfer Syntax), dumped by script.
    private static let registeredVideoSyntaxes = [
        "1.2.840.10008.1.2.4.100", "1.2.840.10008.1.2.4.100.1",
        "1.2.840.10008.1.2.4.101", "1.2.840.10008.1.2.4.101.1",
        "1.2.840.10008.1.2.4.102", "1.2.840.10008.1.2.4.102.1",
        "1.2.840.10008.1.2.4.103", "1.2.840.10008.1.2.4.103.1",
        "1.2.840.10008.1.2.4.104", "1.2.840.10008.1.2.4.104.1",
        "1.2.840.10008.1.2.4.105", "1.2.840.10008.1.2.4.105.1",
        "1.2.840.10008.1.2.4.106", "1.2.840.10008.1.2.4.106.1",
        "1.2.840.10008.1.2.4.107", "1.2.840.10008.1.2.4.108",
    ]

    // MARK: - Modality per IOD

    func test_requiredModality_isTheA32ContentConstraint_andTheEngineDefault() {
        let expected: [(VideoConsole.TypeArgument, String, String, String)] = [
            (.endoscopic, "ES", "A.32.5.4.1", "Video Endoscopic Image Storage"),
            (.microscopic, "GM", "A.32.6.4.1", "Video Microscopic Image Storage"),
            (.photographic, "XC", "A.32.7.4.1", "Video Photographic Image Storage"),
        ]
        for (type, modality, section, sopClassName) in expected {
            let required = VideoOptionConformance.requiredModality(for: type)
            XCTAssertEqual(required.value, modality)
            XCTAssertEqual(required.section, section)
            XCTAssertEqual(type.videoType.defaultModality, modality, "engine default for \(type)")
            XCTAssertEqual(type.sopClassName, sopClassName, "PS3.6 2026a Table A-1 name")
        }
    }

    func test_modalityOtherThanTheIODs_warns_matchingOrAbsentDoesNot() {
        let ct = VideoWorkflow.Metadata(modality: "CT")
        let lines = VideoOptionConformance.warnings(type: .photographic, metadata: ct, transferSyntax: nil)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("warning: --modality CT"))
        XCTAssertTrue(lines[0].contains("A.32.7.4.1"))
        XCTAssertTrue(lines[0].contains("XC"))

        XCTAssertTrue(VideoOptionConformance.warnings(
            type: .microscopic, metadata: .init(modality: "GM"), transferSyntax: nil).isEmpty)
        XCTAssertTrue(VideoOptionConformance.warnings(
            type: .endoscopic, metadata: .init(), transferSyntax: nil).isEmpty)
    }

    func test_patientSex_outsideMFO_warns() {
        XCTAssertEqual(VideoOptionConformance.patientSexValues, ["M", "F", "O"])
        let lines = VideoOptionConformance.warnings(
            type: .endoscopic, metadata: .init(patientSex: "X"), transferSyntax: nil)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("Patient's Sex (0010,0040)"))
        for value in ["M", "F", "O"] {
            XCTAssertTrue(VideoOptionConformance.warnings(
                type: .endoscopic, metadata: .init(patientSex: value), transferSyntax: nil).isEmpty)
        }
    }

    func test_birthDate_notDA_warns() {
        let lines = VideoOptionConformance.warnings(
            type: .endoscopic, metadata: .init(patientBirthDate: "1990-01-01"), transferSyntax: nil)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("Patient's Birth Date (0010,0030)"))
        XCTAssertTrue(VideoOptionConformance.warnings(
            type: .endoscopic, metadata: .init(patientBirthDate: "19900101"), transferSyntax: nil).isEmpty)
    }

    // MARK: - Transfer syntax registry

    func test_everyRegisteredVideoSyntax_isAcceptedWithoutWarning() throws {
        for uid in Self.registeredVideoSyntaxes {
            let syntax = try XCTUnwrap(TransferSyntax.from(uid: uid), uid)
            XCTAssertTrue(syntax.isVideo, uid)
            XCTAssertNil(VideoOptionConformance.transferSyntaxWarning(uid), uid)
        }
    }

    func test_fragmentableHEVC_isNotInTableA1_andWarns() {
        for uid in ["1.2.840.10008.1.2.4.107.1", "1.2.840.10008.1.2.4.108.1"] {
            XCTAssertTrue(TransferSyntax.from(uid: uid)?.isVideo ?? false, "DICOMCore accepts \(uid) (P2)")
            let line = VideoOptionConformance.transferSyntaxWarning(uid)
            XCTAssertNotNil(line, uid)
            XCTAssertTrue(line?.contains("not registered in PS3.6 Table A-1") ?? false)
        }
    }

    // MARK: - convert prints the warning and still writes (no accepted value removed)

    func test_convertParse_keepsAcceptingTheValues() throws {
        let convert = try DICOMVideo.Convert.parse([
            "clip.mp4", "--output", "clip.dcm", "--type", "photographic",
            "--modality", "CT", "--patient-sex", "X", "--transfer-syntax", "1.2.840.10008.1.2.4.107.1",
        ])
        let lines = VideoOptionConformance.warnings(
            type: try XCTUnwrap(convert.type), metadata: try convert.metadata.validatedShared(),
            transferSyntax: convert.transferSyntax)
        XCTAssertEqual(lines.count, 3)
    }

    // MARK: - Help names (PS3.6 2026a Table 6-1)

    func test_helpNames_arePS36Names() {
        XCTAssertTrue(VideoConsole.Help.patientName.hasPrefix("Patient's Name"))
        XCTAssertTrue(VideoConsole.Help.patientBirthDate.hasPrefix("Patient's Birth Date"))
        XCTAssertTrue(VideoConsole.Help.patientSex.hasPrefix("Patient's Sex"))
        XCTAssertTrue(VideoConsole.Help.referringPhysician.hasPrefix("Referring Physician's Name"))
        XCTAssertTrue(VideoConsole.Help.modality.contains("ES endoscopic, GM microscopic, XC photographic"))
    }
}
