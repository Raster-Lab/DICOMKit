// ScaffoldSmokeTests.swift
// Validates the round-trip test target scaffolding: synthetic builders produce
// re-readable DICOM, and the anonymized corpus loads (skip-if-absent).

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class ScaffoldSmokeTests: XCTestCase {

    func testSyntheticGrayscale8RoundTripsThroughReadWrite() throws {
        let file = makeGrayscale8(rows: 4, cols: 4) { UInt8($0) }
        let data = try file.write()
        let reread = try DICOMFile.read(from: data)
        XCTAssertEqual(reread.dataSet[.rows]?.uint16Value, 4)
        XCTAssertEqual(reread.dataSet[.columns]?.uint16Value, 4)
        XCTAssertEqual(pixelBytes(reread).count, 16)
        XCTAssertEqual(readU8(pixelBytes(reread), at: 5), 5)
    }

    func testSyntheticGrayscale16PreservesKnownValues() throws {
        let values: [UInt16] = [0, 1000, 32767, 65535]
        let file = makeGrayscale16(rows: 1, cols: 4) { values[$0] }
        let px = pixelBytes(file)
        for (i, v) in values.enumerated() {
            XCTAssertEqual(readU16(px, at: i), v, "pixel \(i)")
        }
    }

    func testCorpusLoadsWhenPresent() throws {
        let ct = try loadCorpus(.ct)
        try XCTSkipIf(ct == nil, "Corpus absent (CI without Tests/DICOMRoundTripTest/Corpus) — skipping")
        let file = try XCTUnwrap(ct)
        XCTAssertEqual(file.dataSet[.modality]?.stringValue?.trimmingCharacters(in: .whitespaces), "CT")
        XCTAssertEqual(file.dataSet[.rows]?.uint16Value, 512)
        XCTAssertEqual(file.dataSet[.columns]?.uint16Value, 512)
        // Anonymization invariant: Patient Identity Removed / no clear-text name.
        let name = file.dataSet[.patientName]?.stringValue ?? ""
        XCTAssertFalse(name.contains("^") && name.count > 6 && !name.uppercased().contains("ANON"),
                       "corpus should be anonymized, got PatientName=\(name)")
    }
}
