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
}
