import XCTest
import Foundation
import DICOMCore
import DICOMKit
import DICOMWeb
@testable import dicom_xml

/// Pins dicom-xml's option defaults to PS3.19 2026a Table A.1.5-2: a DicomAttribute for each
/// attribute, a zero length Value Field written with no Value element, the keyword written by
/// default, and `--filter-tag` accepting the eight-character `tag` form.
final class DICOMXmlOptionsTests: XCTestCase {

    private func sampleDICOM() throws -> Data {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.7", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.826.0.1.3680043.10.999.3.1", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("P1", for: .patientID, vr: .LO)
        // Accession Number (0008,0050) present with Value Length 0
        dataSet[Tag(group: 0x0008, element: 0x0050)] = DataElement(
            tag: Tag(group: 0x0008, element: 0x0050), vr: .SH, length: 0, valueData: Data())
        return try DICOMFile.create(dataSet: dataSet).write()
    }

    private func encode(_ arguments: [String]) throws -> String {
        let command = try DICOMXml.parse(["in.dcm"] + arguments)
        let options = DataExchangeWorkflow.Options(
            includeEmpty: command.includeEmpty, inlineThreshold: command.inlineThreshold,
            bulkDataURL: command.bulkDataURL, metadataOnly: command.metadataOnly,
            filterTags: DICOMXml.normalizedFilterTags(command.filterTag), includeKeywords: !command.noKeywords)
        let result = try DataExchangeWorkflow.encode(dicomData: try sampleDICOM(), format: .xml, options: options)
        return try XCTUnwrap(String(data: result.data, encoding: .utf8))
    }

    private func attribute(_ tag: String, in xml: String) -> String? {
        guard let start = xml.range(of: "<DicomAttribute tag=\"\(tag)\"") else { return nil }
        guard let end = xml.range(of: "</DicomAttribute>", range: start.upperBound..<xml.endIndex) else { return nil }
        return String(xml[start.lowerBound..<end.upperBound])
    }

    func testEmptyAttributeIsKeptWithoutValueByDefault() throws {
        XCTAssertTrue(try DICOMXml.parse(["in.dcm"]).includeEmpty)
        let accession = try XCTUnwrap(attribute("00080050", in: try encode([])))
        XCTAssertTrue(accession.contains("vr=\"SH\""))
        XCTAssertTrue(accession.contains("keyword=\"AccessionNumber\""))
        XCTAssertFalse(accession.contains("<Value"))
    }

    func testIncludeEmptyKeepsItsSpellingAndNoIncludeEmptyDropsIt() throws {
        XCTAssertTrue(try DICOMXml.parse(["in.dcm", "--include-empty"]).includeEmpty)
        XCTAssertFalse(try DICOMXml.parse(["in.dcm", "--no-include-empty"]).includeEmpty)
        XCTAssertNil(attribute("00080050", in: try encode(["--no-include-empty"])))
    }

    func testKeywordIsWrittenByDefault() throws {
        XCTAssertFalse(try DICOMXml.parse(["in.dcm"]).noKeywords)
        XCTAssertTrue(try XCTUnwrap(attribute("00100020", in: try encode([]))).contains("keyword=\"PatientID\""))
    }

    func testFilterTagAcceptsKeywordCommaTagParenthesisedTagAndA152TagForm() throws {
        let specs = ["PatientID", "0010,0020", "(0010,0020)", "00100020"]
        XCTAssertEqual(DICOMXml.normalizedFilterTags(specs), ["PatientID", "0010,0020", "0010,0020", "0010,0020"])
        let xml = try encode(["--filter-tag", "00100020"])
        XCTAssertNotNil(attribute("00100020", in: xml))
        XCTAssertNil(attribute("00080016", in: xml))
    }
}
