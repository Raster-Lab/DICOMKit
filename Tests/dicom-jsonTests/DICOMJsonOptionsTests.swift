import XCTest
import Foundation
import DICOMCore
import DICOMKit
import DICOMWeb
@testable import dicom_json

/// Pins dicom-json's option defaults to PS3.18 2026a Annex F: an empty attribute is kept as
/// `{"vr": ...}` (F.2.5), attribute objects are in ascending tag order (F.2.2), and
/// `--filter-tag` accepts the eight-character attribute name of F.2.2.
final class DICOMJsonOptionsTests: XCTestCase {

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

    private func encode(_ arguments: [String]) throws -> [String: Any] {
        let command = try DICOMJson.parse(["in.dcm"] + arguments)
        let options = DataExchangeWorkflow.Options(
            includeEmpty: command.includeEmpty, inlineThreshold: command.inlineThreshold,
            bulkDataURL: command.bulkDataURL, metadataOnly: command.metadataOnly,
            filterTags: DICOMJson.normalizedFilterTags(command.filterTag), sortKeys: !command.noSortKeys)
        let result = try DataExchangeWorkflow.encode(dicomData: try sampleDICOM(), format: .json, options: options)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
    }

    func testEmptyAttributeIsKeptByDefaultPerF25() throws {
        XCTAssertTrue(try DICOMJson.parse(["in.dcm"]).includeEmpty)
        let json = try encode([])
        let accession = try XCTUnwrap(json["00080050"] as? [String: Any])
        XCTAssertEqual(accession as NSDictionary, ["vr": "SH"] as NSDictionary)
    }

    func testIncludeEmptyKeepsItsSpellingAndNoIncludeEmptyDropsIt() throws {
        XCTAssertTrue(try DICOMJson.parse(["in.dcm", "--include-empty"]).includeEmpty)
        XCTAssertFalse(try DICOMJson.parse(["in.dcm", "--no-include-empty"]).includeEmpty)
        XCTAssertNil(try encode(["--no-include-empty"])["00080050"])
    }

    func testAttributeObjectsAreInAscendingOrderByDefaultPerF22() throws {
        let command = try DICOMJson.parse(["in.dcm"])
        XCTAssertFalse(command.noSortKeys)
        let options = DataExchangeWorkflow.Options(includeEmpty: true, sortKeys: !command.noSortKeys)
        let data = try DataExchangeWorkflow.encode(dicomData: try sampleDICOM(), format: .json, options: options).data
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let names = text.matches(of: /"([0-9A-F]{8})":/).map { String($0.1) }
        XCTAssertEqual(names, ["00080016", "00080018", "00080050", "00100020"])
    }

    func testFilterTagAcceptsKeywordCommaTagParenthesisedTagAndF22AttributeName() throws {
        let specs = ["PatientID", "0010,0020", "(0010,0020)", "00100020", "0008001a"]
        let normalized = DICOMJson.normalizedFilterTags(specs)
        XCTAssertEqual(normalized, ["PatientID", "0010,0020", "0010,0020", "0010,0020", "0008,001a"])
        let tags = try DataExchangeWorkflow.resolveFilterTags(normalized)
        XCTAssertEqual(tags, [Tag(group: 0x0010, element: 0x0020), Tag(group: 0x0008, element: 0x001A)])
        XCTAssertEqual(Array(try encode(["--filter-tag", "00100020"]).keys), ["00100020"])
    }
}
