// PrintIdentificationFieldsTests.swift
// DICOMStudioTests
//
// SRS FR-006: the optional identification fields.
//
// The regression gate for the whole feature: with no options, the corner
// arrangement is exactly what films printed before these fields existed.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import DICOMPrintKit
import Foundation

@Suite("Print Identification Fields Tests")
struct PrintIdentificationFieldsTests {

    private func dataSet(_ values: [(UInt16, UInt16, String, VR)]) -> DataSet {
        DataSet(elements: values.map { group, element, value, vr in
            let padded = value.count % 2 == 0 ? value : value + " "
            let data = Data(padded.utf8)
            return DataElement(
                tag: Tag(group: group, element: element),
                vr: vr,
                length: UInt32(data.count),
                valueData: data)
        })
    }

    private var fullDataSet: DataSet {
        dataSet([
            (0x0010, 0x0010, "DOE^JANE", .PN),
            (0x0010, 0x0020, "711794", .LO),
            (0x0010, 0x0030, "19621015", .DA),
            (0x0008, 0x0020, "20260801", .DA),
            (0x0008, 0x0050, "A123456", .SH),
            (0x0008, 0x0060, "CT", .CS),
            (0x0008, 0x0080, "GENERAL HOSPITAL", .LO),
            (0x0008, 0x1030, "CT ABDOMEN", .LO),
            (0x0008, 0x103E, "ARTERIAL PHASE", .LO),
        ])
    }

    @Test("The optional fields are read and formatted")
    func testFieldsAreRead() {
        let text = PatientOverlayText.make(from: fullDataSet)
        #expect(text.birthDateLine.hasPrefix("DOB: "))
        #expect(text.birthDateLine.contains("1962"))
        #expect(text.accessionLine == "Acc: A123456")
        #expect(text.institutionLine == "GENERAL HOSPITAL")
        #expect(text.seriesDescriptionLine == "ARTERIAL PHASE")
    }

    @Test("No options is today's film: corners(including: []) == corners")
    func testDefaultIsUnchanged() {
        let text = PatientOverlayText.make(from: fullDataSet)
        #expect(text.corners(including: []) == text.corners)
        // And none of the optional lines leak into the default.
        let lines = text.corners.allLines.joined(separator: "\n")
        #expect(!lines.contains("DOB:"))
        #expect(!lines.contains("Acc:"))
        #expect(!lines.contains("GENERAL HOSPITAL"))
        #expect(!lines.contains("ARTERIAL PHASE"))
    }

    @Test("Birth date is off unless deliberately chosen — it survives de-identification")
    func testBirthDateIsOptIn() {
        let text = PatientOverlayText.make(from: fullDataSet)
        #expect(!text.corners.allLines.contains { $0.contains("DOB:") })
        #expect(PrintIdentificationFields().isEmpty, "the default option set is empty")
    }

    @Test("Each field lands in its documented corner")
    func testFieldPlacement() {
        let text = PatientOverlayText.make(from: fullDataSet)
        let all = text.corners(including: [
            .birthDate, .accessionNumber, .institutionName, .seriesDescription,
        ])
        // Who and what: top right, in reading order.
        #expect(all.topRight.contains { $0.hasPrefix("DOB:") })
        #expect(all.topRight.contains("Acc: A123456"))
        #expect(all.topRight.contains("ARTERIAL PHASE"))
        // Where joins when: bottom right, under the study date.
        #expect(all.bottomRight.last == "GENERAL HOSPITAL")
        // The birth date sits directly under the patient it identifies.
        if let patient = all.topRight.firstIndex(where: { $0.contains("711794") }),
           let dob = all.topRight.firstIndex(where: { $0.hasPrefix("DOB:") }) {
            #expect(dob == patient + 1)
        } else {
            Issue.record("expected both the patient line and the DOB line")
        }
    }

    @Test("An opted-in field a de-identified file does not carry adds nothing")
    func testAbsentFieldsStayAbsent() {
        let text = PatientOverlayText.make(from: dataSet([
            (0x0010, 0x0020, "ANON-1", .LO),
        ]))
        let corners = text.corners(including: [
            .birthDate, .accessionNumber, .institutionName, .seriesDescription,
        ])
        // PrintCornerAnnotation drops empty lines, so nothing blank is drawn.
        #expect(corners == text.corners)
    }

    @Test("The style defaults reproduce the automatic behaviour")
    func testStyleDefaults() {
        #expect(PrintAnnotationStyle() == .automatic)
        #expect(PrintAnnotationStyle.automatic.sizeFraction == nil)
        #expect(PrintAnnotationStyle.automatic.foreground == .automatic)
        // The legibility clamp: nothing below 2% or above 10% of the frame.
        #expect(PrintAnnotationStyle(sizeFraction: 0.001).sizeFraction == 0.02)
        #expect(PrintAnnotationStyle(sizeFraction: 0.5).sizeFraction == 0.10)
    }
}
