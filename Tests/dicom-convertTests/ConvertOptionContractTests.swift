//
// ConvertOptionContractTests.swift
// dicom-convert
//
// --transfer-syntax accepts the PS3.6 2026a Table A-1 keyword of every catalog target UID
// (7 were missing); the 3 catalog names that are Table A-1 keywords of another UID keep their
// catalog meaning (P-CONVERT-TS-KEYWORDS). --window-width follows PS3.3 2026a C.11.2.1.2.1
// ("shall always be greater than or equal to 1"); --quality and --frame keep their documented
// ranges.
//

import XCTest
import ArgumentParser
import DICOMCore
import DICOMKit
@testable import dicom_convert

final class ConvertOptionContractTests: XCTestCase {

    /// PS3.6 2026a Table A-1 keyword → UID for every UID the shared catalog can target,
    /// dumped from part06_2026a.xml.
    private static let tableA1Keywords: [String: String] = [
        "ImplicitVRLittleEndian": "1.2.840.10008.1.2",
        "ExplicitVRLittleEndian": "1.2.840.10008.1.2.1",
        "DeflatedExplicitVRLittleEndian": "1.2.840.10008.1.2.1.99",
        "ExplicitVRBigEndian": "1.2.840.10008.1.2.2",
        "JPEGBaseline8Bit": "1.2.840.10008.1.2.4.50",
        "JPEGExtended12Bit": "1.2.840.10008.1.2.4.51",
        "JPEGLossless": "1.2.840.10008.1.2.4.57",
        "JPEGLosslessSV1": "1.2.840.10008.1.2.4.70",
        "JPEGLSLossless": "1.2.840.10008.1.2.4.80",
        "JPEGLSNearLossless": "1.2.840.10008.1.2.4.81",
        "JPEG2000Lossless": "1.2.840.10008.1.2.4.90",
        "JPEG2000": "1.2.840.10008.1.2.4.91",
        "JPEG2000MCLossless": "1.2.840.10008.1.2.4.92",
        "JPEG2000MC": "1.2.840.10008.1.2.4.93",
        "JPEGXLLossless": "1.2.840.10008.1.2.4.110",
        "JPEGXLJPEGRecompression": "1.2.840.10008.1.2.4.111",
        "JPEGXL": "1.2.840.10008.1.2.4.112",
        "HTJ2KLossless": "1.2.840.10008.1.2.4.201",
        "HTJ2KLosslessRPCL": "1.2.840.10008.1.2.4.202",
        "HTJ2K": "1.2.840.10008.1.2.4.203",
        "RLELossless": "1.2.840.10008.1.2.5",
    ]

    /// Catalog names that are Table A-1 keywords of another UID (P-CONVERT-TS-KEYWORDS).
    private static let catalogMeaningKept: [String: String] = [
        "JPEG2000Lossless": "1.2.840.10008.1.2.4.91",
        "HTJ2KLossless": "1.2.840.10008.1.2.4.203",
        "JPEGXLLossless": "1.2.840.10008.1.2.4.112",
    ]

    func test_everyTableA1Keyword_isAccepted() {
        XCTAssertEqual(Set(DICOMConverter.targetSyntaxes.map(\.uid)), Set(Self.tableA1Keywords.values),
                       "the catalog's target UIDs changed; re-dump Table A-1")
        for (keyword, uid) in Self.tableA1Keywords {
            let resolved = TransferSyntaxKeywords.resolve(keyword)?.transferSyntax.uid
            XCTAssertEqual(resolved, Self.catalogMeaningKept[keyword] ?? uid, keyword)
            XCTAssertEqual(TransferSyntaxKeywords.resolve(keyword.lowercased())?.transferSyntax.uid,
                           resolved, "\(keyword) case-insensitive")
        }
    }

    func test_addedKeywords_doNotShadowTheCatalog() {
        for keyword in TransferSyntaxKeywords.additional.keys {
            XCTAssertNil(DICOMConverter.resolveTargetEncoding(keyword), keyword)
            XCTAssertEqual(TransferSyntaxKeywords.additional[keyword], Self.tableA1Keywords[keyword], keyword)
        }
    }

    func test_catalogNamesAndUIDs_stillResolve() {
        for target in DICOMConverter.targets {
            XCTAssertEqual(TransferSyntaxKeywords.resolve(target.cliToken)?.transferSyntax.uid, target.syntax.uid)
            XCTAssertNotNil(TransferSyntaxKeywords.resolve(target.syntax.uid))
        }
        XCTAssertNil(TransferSyntaxKeywords.resolve("bogus"))
    }

    func test_help_namesTheKeywordsAndTheThreeCollisions() {
        let help = TransferSyntaxKeywords.optionHelp
        for keyword in TransferSyntaxKeywords.additional.keys { XCTAssertTrue(help.contains(keyword), keyword) }
        for keyword in Self.catalogMeaningKept.keys { XCTAssertTrue(help.contains(keyword), keyword) }
    }

    // MARK: - Ranges

    func test_windowWidth_belowOne_isRefused_C112121() {
        XCTAssertThrowsError(try DICOMConvert.parse(["in.dcm", "-o", "o.png", "--window-width", "0.5"]))
        XCTAssertThrowsError(try DICOMConvert.parse(["in.dcm", "-o", "o.png", "--window-width", "0"]))
        XCTAssertNoThrow(try DICOMConvert.parse(["in.dcm", "-o", "o.png", "--window-width", "1"]))
    }

    func test_quality_outsideDocumentedRange_isRefused() {
        XCTAssertThrowsError(try DICOMConvert.parse(["in.dcm", "-o", "o.jpg", "--quality", "0"]))
        XCTAssertThrowsError(try DICOMConvert.parse(["in.dcm", "-o", "o.jpg", "--quality", "101"]))
        XCTAssertNoThrow(try DICOMConvert.parse(["in.dcm", "-o", "o.jpg", "--quality", "100"]))
    }

    func test_negativeFrame_isRefused() {
        XCTAssertThrowsError(try DICOMConvert.parse(["in.dcm", "-o", "o.png", "--frame=-1"]))
        XCTAssertNoThrow(try DICOMConvert.parse(["in.dcm", "-o", "o.png", "--frame", "0"]))
    }

    func test_validateFlag_keepsItsSpelling() throws {
        let cmd = try DICOMConvert.parse(["in.dcm", "-o", "o.dcm", "--validate"])
        XCTAssertTrue(cmd.validateOutput)
    }
}
