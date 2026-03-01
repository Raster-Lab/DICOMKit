// MeasurementPersistenceHelpersTests.swift
// DICOMStudioTests
//
// Tests for MeasurementPersistenceHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MeasurementPersistenceHelpers SR Concept Tests")
struct SRConceptTests {

    @Test("SR concept creation")
    func testCreation() {
        let concept = SRConcept(codeValue: "12345", codingSchemeDesignator: "SCT", codeMeaning: "Test")
        #expect(concept.codeValue == "12345")
        #expect(concept.codingSchemeDesignator == "SCT")
        #expect(concept.codeMeaning == "Test")
    }

    @Test("SR concepts are Equatable")
    func testEquatable() {
        let a = SRConcept(codeValue: "12345", codingSchemeDesignator: "SCT", codeMeaning: "Test")
        let b = SRConcept(codeValue: "12345", codingSchemeDesignator: "SCT", codeMeaning: "Test")
        #expect(a == b)
    }

    @Test("SR concepts are Hashable")
    func testHashable() {
        let concept = MeasurementPersistenceHelpers.lengthConcept
        var set: Set<SRConcept> = []
        set.insert(concept)
        #expect(set.contains(concept))
    }

    @Test("Predefined concepts are valid")
    func testPredefinedConcepts() {
        #expect(!MeasurementPersistenceHelpers.lengthConcept.codeValue.isEmpty)
        #expect(!MeasurementPersistenceHelpers.angleConcept.codeValue.isEmpty)
        #expect(!MeasurementPersistenceHelpers.areaConcept.codeValue.isEmpty)
        #expect(!MeasurementPersistenceHelpers.meanConcept.codeValue.isEmpty)
        #expect(!MeasurementPersistenceHelpers.stdDevConcept.codeValue.isEmpty)
        #expect(!MeasurementPersistenceHelpers.minimumConcept.codeValue.isEmpty)
        #expect(!MeasurementPersistenceHelpers.maximumConcept.codeValue.isEmpty)
    }
}

@Suite("MeasurementPersistenceHelpers SR Mapping Tests")
struct SRMappingTests {

    @Test("SR concept for length")
    func testLengthConcept() {
        let concept = MeasurementPersistenceHelpers.srConcept(for: .length)
        #expect(concept.codeMeaning == "Length")
    }

    @Test("SR concept for angle")
    func testAngleConcept() {
        let concept = MeasurementPersistenceHelpers.srConcept(for: .angle)
        #expect(concept.codeMeaning == "Angle")
    }

    @Test("SR concept for ROI tools")
    func testROIConcept() {
        let concept = MeasurementPersistenceHelpers.srConcept(for: .circularROI)
        #expect(concept.codeMeaning == "Area")
    }

    @Test("UCUM units for tools")
    func testUCUMUnits() {
        #expect(MeasurementPersistenceHelpers.ucumUnit(for: .length) == "mm")
        #expect(MeasurementPersistenceHelpers.ucumUnit(for: .angle) == "deg")
        #expect(MeasurementPersistenceHelpers.ucumUnit(for: .circularROI) == "mm2")
        #expect(MeasurementPersistenceHelpers.ucumUnit(for: .textAnnotation) == "")
    }
}

@Suite("MeasurementPersistenceHelpers JSON Export Tests")
struct JSONExportTests {

    @Test("Export single length measurement")
    func testExportLength() {
        let entry = MeasurementEntry(
            toolType: .length,
            points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)],
            label: "Test Length",
            sopInstanceUID: "1.2.3"
        )
        let json = MeasurementPersistenceHelpers.measurementsToJSON([entry])
        #expect(json.count == 1)
        #expect(json[0]["type"] == "LENGTH")
        #expect(json[0]["label"] == "Test Length")
        #expect(json[0]["sopInstanceUID"] == "1.2.3")
        #expect(json[0]["lengthPixels"] != nil)
    }

    @Test("Export length with calibration")
    func testExportLengthCalibrated() {
        let cal = CalibrationModel(pixelSpacingRow: 0.5, pixelSpacingColumn: 0.5, source: .pixelSpacing)
        let entry = MeasurementEntry(
            toolType: .length,
            points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)],
            sopInstanceUID: "1.2.3"
        )
        let json = MeasurementPersistenceHelpers.measurementsToJSON([entry], calibration: cal)
        #expect(json[0]["lengthMM"] != nil)
    }

    @Test("Export angle measurement")
    func testExportAngle() {
        let entry = MeasurementEntry(
            toolType: .angle,
            points: [
                AnnotationPoint(x: 100, y: 0),
                AnnotationPoint(x: 0, y: 0),
                AnnotationPoint(x: 0, y: 100)
            ],
            sopInstanceUID: "1.2.3"
        )
        let json = MeasurementPersistenceHelpers.measurementsToJSON([entry])
        #expect(json[0]["angleDegrees"] != nil)
    }

    @Test("Export Cobb angle measurement")
    func testExportCobbAngle() {
        let entry = MeasurementEntry(
            toolType: .cobbAngle,
            points: [
                AnnotationPoint(x: 0, y: 0),
                AnnotationPoint(x: 100, y: 0),
                AnnotationPoint(x: 0, y: 100),
                AnnotationPoint(x: 100, y: 100)
            ],
            sopInstanceUID: "1.2.3"
        )
        let json = MeasurementPersistenceHelpers.measurementsToJSON([entry])
        #expect(json[0]["cobbAngleDegrees"] != nil)
    }

    @Test("Export multiple measurements")
    func testExportMultiple() {
        let entries = [
            MeasurementEntry(toolType: .length, points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)]),
            MeasurementEntry(toolType: .marker, points: [AnnotationPoint(x: 50, y: 50)])
        ]
        let json = MeasurementPersistenceHelpers.measurementsToJSON(entries)
        #expect(json.count == 2)
    }

    @Test("Export empty measurements")
    func testExportEmpty() {
        let json = MeasurementPersistenceHelpers.measurementsToJSON([])
        #expect(json.isEmpty)
    }

    @Test("Dict contains point coordinates")
    func testPointCoordinates() {
        let entry = MeasurementEntry(
            toolType: .length,
            points: [AnnotationPoint(x: 10.5, y: 20.3), AnnotationPoint(x: 30.7, y: 40.1)]
        )
        let dict = MeasurementPersistenceHelpers.measurementToDict(entry)
        #expect(dict["point0_x"] != nil)
        #expect(dict["point0_y"] != nil)
        #expect(dict["point1_x"] != nil)
        #expect(dict["point1_y"] != nil)
    }
}

@Suite("MeasurementPersistenceHelpers CSV Export Tests")
struct CSVExportTests {

    @Test("CSV header exists")
    func testCSVHeader() {
        #expect(MeasurementPersistenceHelpers.csvHeader.contains("ID"))
        #expect(MeasurementPersistenceHelpers.csvHeader.contains("Type"))
        #expect(MeasurementPersistenceHelpers.csvHeader.contains("Label"))
    }

    @Test("Export length to CSV")
    func testExportCSV() {
        let entry = MeasurementEntry(
            toolType: .length,
            points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)],
            label: "Test",
            sopInstanceUID: "1.2.3"
        )
        let csv = MeasurementPersistenceHelpers.measurementsToCSV([entry])
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 2) // header + 1 row
        #expect(lines[1].contains("LENGTH"))
    }

    @Test("CSV with multiple measurements")
    func testMultipleCSV() {
        let entries = [
            MeasurementEntry(toolType: .length, points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)]),
            MeasurementEntry(toolType: .angle, points: [
                AnnotationPoint(x: 100, y: 0),
                AnnotationPoint(x: 0, y: 0),
                AnnotationPoint(x: 0, y: 100)
            ])
        ]
        let csv = MeasurementPersistenceHelpers.measurementsToCSV(entries)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3) // header + 2 rows
    }

    @Test("CSV escapes labels with commas")
    func testCSVEscaping() {
        let entry = MeasurementEntry(
            toolType: .length,
            points: [AnnotationPoint(x: 0, y: 0), AnnotationPoint(x: 100, y: 0)],
            label: "Label, with comma"
        )
        let row = MeasurementPersistenceHelpers.measurementToCSVRow(entry)
        #expect(row.contains("\"Label, with comma\""))
    }

    @Test("Empty measurements CSV has only header")
    func testEmptyCSV() {
        let csv = MeasurementPersistenceHelpers.measurementsToCSV([])
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 1)
    }
}
