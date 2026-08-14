// PatientOverlayTextTests.swift
// DICOMStudioTests
//
// The identification burned over an image: two lines, built the same way for a
// viewer tile and a film cell.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("Patient Overlay Text Tests")
struct PatientOverlayTextTests {

    private func dataSet(_ values: [(UInt16, UInt16, String, VR)]) -> DataSet {
        DataSet(elements: values.map { group, element, value, vr in
            // DICOM string values are even-length, padded with a space.
            let padded = value.count % 2 == 0 ? value : value + " "
            let data = Data(padded.utf8)
            return DataElement(
                tag: Tag(group: group, element: element),
                vr: vr,
                length: UInt32(data.count),
                valueData: data)
        })
    }

    @Test("Name, ID and study date share the first line; the description takes the second")
    func testTwoLines() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0010, "DOE^JANE^^Dr", .PN),
            (0x0010, 0x0020, "711794", .LO),
            (0x0008, 0x0020, "20251015", .DA),
            (0x0008, 0x1030, "CT ABDOMEN", .LO)
        ]))

        // Person name is reordered for reading, not re-cased.
        #expect(text.primaryLine.hasPrefix("Dr JANE DOE"))
        #expect(text.primaryLine.contains("711794"))
        #expect(text.primaryLine.contains("2025"))
        #expect(text.primaryLine.filter { $0 == "," }.count == 2, "one separator between each")
        #expect(text.secondaryLine == "CT ABDOMEN")
    }

    @Test("Missing values are dropped, not shown as stray commas")
    func testDeidentified() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0020, "ANON-1", .LO)
        ]))

        #expect(text.primaryLine == "ANON-1")
        #expect(text.secondaryLine.isEmpty)
        #expect(!text.isEmpty)
    }

    @Test("An empty data set has nothing to draw")
    func testEmpty() {
        let text = PatientOverlayText.make(from: DataSet())
        #expect(text.isEmpty)
    }

    @Test("Blank values count as missing")
    func testBlankValues() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0010, "   ", .PN),
            (0x0008, 0x1030, "", .LO)
        ]))
        #expect(text.isEmpty)
    }

    // MARK: - What made the picture

    @Test("A CT caption carries its image number, slice thickness and exposure")
    func testCTTechnicalLine() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0008, 0x0060, "CT", .CS),
            (0x0020, 0x0011, "2", .IS),
            (0x0020, 0x0013, "45", .IS),
            (0x0018, 0x0050, "5.0", .DS),
            (0x0018, 0x0060, "120", .DS),
            (0x0018, 0x1152, "250", .IS)
        ]))

        #expect(text.technicalLine
                == "Modality: CT · Image: 45 · Slice Thickness: 5.00 mm"
                + " · kVp: 120 · Exposure: 250 mAs")
        // Series Number 2 is in the header and stays off the film: a cell is one
        // image, and its series is already said by the study description above.
        #expect(!text.technicalLine.contains("Series"))
        #expect(text.lines.count == 1, "no patient and no study: only the technique")
    }

    @Test("An MR caption carries TR, TE and the field strength instead")
    func testMRTechnicalLine() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0008, 0x0060, "MR", .CS),
            (0x0018, 0x0050, "4.0", .DS),
            (0x0018, 0x0080, "450", .DS),
            (0x0018, 0x0081, "12.5", .DS),
            (0x0018, 0x0087, "1.5", .DS),
            (0x0018, 0x0060, "120", .DS)
        ]))

        #expect(text.technicalLine
                == "Modality: MR · Slice Thickness: 4.00 mm · TR: 450 ms / TE: 12.5 ms"
                + " · Field Strength: 1.5 T")
        #expect(!text.technicalLine.contains("kVp"), "kVp is not how an MR is read")
    }

    @Test("A plain film carries kV, mAs and the view it was taken in")
    func testRadiographTechnicalLine() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0008, 0x0060, "DX", .CS),
            (0x0018, 0x0060, "70", .DS),
            (0x0018, 0x1152, "8", .IS),
            (0x0018, 0x5101, "PA", .CS)
        ]))

        #expect(text.technicalLine
                == "Modality: DX · kVp: 70 · Exposure: 8 mAs · View: PA")
    }

    @Test("A modality nobody special-cased still shows its slice thickness")
    func testUnknownModalityFallsBackToThickness() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0008, 0x0060, "OT", .CS),
            (0x0018, 0x0050, "2.5", .DS)
        ]))

        #expect(text.technicalLine == "Modality: OT · Slice Thickness: 2.50 mm")
    }

    @Test("The technique line is a third line, under the patient and the study")
    func testThreeLines() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0010, "DOE^JANE", .PN),
            (0x0008, 0x1030, "CT ABDOMEN", .LO),
            (0x0008, 0x0060, "CT", .CS),
            (0x0018, 0x0050, "5.0", .DS)
        ]))

        #expect(text.lines.count == 3)
        #expect(text.lines[1] == "CT ABDOMEN")
        #expect(text.lines[2] == "Modality: CT · Slice Thickness: 5.00 mm")
    }

    @Test("The corners are laid out the way a reading station lays them out")
    func testCorners() {
        let corners = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0010, "DOE^JANE", .PN),
            (0x0010, 0x0020, "711794", .LO),
            (0x0008, 0x0020, "20251015", .DA),
            (0x0008, 0x0030, "143205", .TM),
            (0x0008, 0x1030, "CT ABDOMEN", .LO),
            (0x0008, 0x0060, "CT", .CS),
            (0x0020, 0x0013, "45", .IS),
            (0x0018, 0x0050, "5.0", .DS)
        ])).corners

        // Who and what at the top right; what made the picture at the bottom
        // left; when it was taken at the bottom right.
        #expect(corners.topRight.count == 2)
        #expect(corners.topRight[0].contains("711794"))
        #expect(corners.topRight[1] == "CT ABDOMEN")
        #expect(corners.bottomLeft
                == ["Modality: CT", "Image: 45", "Slice Thickness: 5.00 mm"])
        // The date carries its time: a patient scanned twice in a day gives two
        // films that are otherwise identical.
        #expect(corners.bottomRight.first?.contains("2025") == true)
        #expect(corners.bottomRight.first?.hasSuffix("14:32") == true,
                "to the minute — the seconds the scanner recorded are read by nobody")
        // The top left stays clear: a printed cell has no viewport to describe.
        #expect(corners.topLeft.isEmpty)
    }

    @Test("A study with no time recorded shows the date on its own")
    func testStudyDateWithoutTime() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0008, 0x0020, "20251015", .DA)
        ]))

        #expect(text.studyDate.contains("2025"))
        #expect(!text.studyDate.contains(":"))
    }

    @Test("A time with no date to place it is not shown alone")
    func testTimeWithoutDate() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0008, 0x0030, "143205", .TM)
        ]))

        #expect(text.studyDate.isEmpty)
    }

    @Test("A file that recorded no technique reserves no line for one")
    func testNoTechniqueNoLine() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0020, "ANON-1", .LO)
        ]))

        #expect(text.technicalLine.isEmpty)
        #expect(text.lines == ["ANON-1"])
    }
}
