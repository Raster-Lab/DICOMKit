// XMLRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-xml` tool.
//
// These tests call the DICOMKit library directly (DICOMXMLEncoder /
// DICOMXMLDecoder in DICOMWeb, DataSet/DataElement/Tag in DICOMCore/DICOMKit),
// exactly as Sources/dicom-xml/main.swift does — they never spawn the CLI.
//
// Every assertion is an oracle: a fact true by definition of the transform
// (round-trip identity of string values, structural filtering, keyword
// dictionary identity, well-formed XML), never a comparison to a
// re-implementation of the tool.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
import DICOMDictionary
import DICOMWeb

final class XMLRoundTripTests: XCTestCase {

    // MARK: - Private helpers (not shared — kept inside the class per suite rules)

    /// Encodes elements to XML data with the given configuration (mirrors CLI).
    private func encodeXML(
        _ elements: [DataElement],
        includeEmptyValues: Bool = false,
        inlineBinaryThreshold: Int? = 1024,
        bulkDataBaseURL: URL? = nil,
        prettyPrinted: Bool = false,
        includeKeywords: Bool = true
    ) throws -> Data {
        let config = DICOMXMLEncoder.Configuration(
            includeEmptyValues: includeEmptyValues,
            inlineBinaryThreshold: inlineBinaryThreshold,
            bulkDataBaseURL: bulkDataBaseURL,
            prettyPrinted: prettyPrinted,
            includeKeywords: includeKeywords
        )
        return try DICOMXMLEncoder(configuration: config).encode(elements)
    }

    /// Decodes XML data back to elements (allowMissingVR mirrors the CLI decoder config).
    private func decodeXML(_ data: Data) throws -> [DataElement] {
        let config = DICOMXMLDecoder.Configuration(
            allowMissingVR: true, fetchBulkData: false, bulkDataHandler: nil)
        return try DICOMXMLDecoder(configuration: config).decode(data)
    }

    /// True iff `data` is well-formed XML that Foundation's XMLParser accepts.
    private func isWellFormedXML(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        return parser.parse()
    }

    /// The `<Value>` texts under the `<DicomAttribute tag="GGGGEEEE">` for `tag`,
    /// collected by walking the encoded XML with XMLParser.
    private func valuesForTag(_ xml: Data, tag: Tag) throws -> [String] {
        let collector = ValueCollector(targetTag: tag)
        let parser = XMLParser(data: xml)
        parser.delegate = collector
        XCTAssertTrue(parser.parse(), "encoded XML must be well-formed")
        return collector.collected
    }

    /// XMLParser delegate that gathers `<Value>` text for a specific tag attribute.
    private final class ValueCollector: NSObject, XMLParserDelegate {
        let targetTagString: String
        private var inTargetAttribute = false
        private var inValue = false
        private var buffer = ""
        var collected: [String] = []

        init(targetTag: Tag) {
            self.targetTagString = String(format: "%04X%04X", targetTag.group, targetTag.element)
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            if elementName == "DicomAttribute" {
                inTargetAttribute = (attributeDict["tag"] == targetTagString)
            } else if elementName == "Value" && inTargetAttribute {
                inValue = true
                buffer = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inValue { buffer += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "Value" && inValue {
                collected.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
                inValue = false
            } else if elementName == "DicomAttribute" {
                inTargetAttribute = false
            }
        }
    }

    // MARK: - Tests

    // Oracle (plan 3.9): encoded XML is well-formed AND Modality is present with its exact value.
    func testEncodedXMLIsWellFormedAndCarriesModality() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let xml = try encodeXML(file.dataSet.allElements)

        XCTAssertTrue(isWellFormedXML(xml), "encoder must emit well-formed XML")

        let modalityValues = try valuesForTag(xml, tag: .modality)
        XCTAssertEqual(modalityValues, ["CT"],
                       "Modality element must be present with its source value")
    }

    // Oracle: decode(encode(elements)) preserves string element values (identity round-trip).
    func testStringValueRoundTripIdentity() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        // Encode without pixel data (binary) so we compare string VRs cleanly.
        let elements = file.dataSet.allElements.filter { $0.tag != Tag.pixelData }

        let xml = try encodeXML(elements)
        let decoded = try decodeXML(xml)
        let ds = DataSet(elements: decoded)

        XCTAssertEqual(ds[.modality]?.stringValue, "CT")
        XCTAssertEqual(ds[.patientID]?.stringValue, "RT001")
        XCTAssertEqual(ds[.patientName]?.stringValue, "RoundTrip^Patient")
        XCTAssertEqual(ds[.sopClassUID]?.stringValue, "1.2.840.10008.5.1.4.1.1.2")
    }

    // Oracle: --metadata-only excludes PixelData; the encoded XML has no 7FE00010 attribute.
    func testMetadataOnlyExcludesPixelData() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        XCTAssertNotNil(file.dataSet[.pixelData], "fixture must contain pixel data")

        let filtered = file.dataSet.allElements.filter { $0.tag != Tag.pixelData }
        let xml = try encodeXML(filtered)

        // No PixelData tag should appear as a DicomAttribute.
        let pixelValues = try valuesForTag(xml, tag: .pixelData)
        XCTAssertTrue(pixelValues.isEmpty, "metadata-only must omit pixel data")

        let full = try encodeXML(file.dataSet.allElements)
        XCTAssertGreaterThan(full.count, xml.count,
                             "full XML (with pixel data) must be larger than metadata-only")
    }

    // Oracle: --filter-tag restricts output to exactly the requested tag set.
    func testFilterTagKeepsOnlySelectedTags() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        // Resolve keywords the same way the CLI does.
        let modalityEntry = try XCTUnwrap(DataElementDictionary.lookup(keyword: "Modality"))
        let patientIDEntry = try XCTUnwrap(DataElementDictionary.lookup(keyword: "PatientID"))
        let keep: Set<Tag> = [modalityEntry.tag, patientIDEntry.tag]

        let filtered = file.dataSet.allElements.filter { keep.contains($0.tag) }
        let xml = try encodeXML(filtered)
        let decoded = try decodeXML(xml)
        let decodedTags = Set(decoded.map { $0.tag })

        XCTAssertEqual(decodedTags, keep,
                       "filtered XML must contain exactly the requested tags")
        XCTAssertNil(DataSet(elements: decoded)[.patientName],
                     "unselected tags must be absent")
    }

    // Oracle: keyword dictionary identity — lookup("PatientName").tag == (0010,0010).
    func testKeywordLookupIdentity() throws {
        let entry = try XCTUnwrap(DataElementDictionary.lookup(keyword: "PatientName"))
        XCTAssertEqual(entry.tag, Tag(group: 0x0010, element: 0x0010))
        XCTAssertEqual(entry.tag, Tag.patientName)
    }

    // Oracle: --no-keywords omits the keyword="" attribute; default includes it. Both parse.
    func testNoKeywordsOmitsKeywordAttribute() throws {
        let file = makeGrayscale8(rows: 2, cols: 2)
        let elements = file.dataSet.allElements.filter { $0.tag != Tag.pixelData }

        let withKw = try encodeXML(elements, includeKeywords: true)
        let withoutKw = try encodeXML(elements, includeKeywords: false)

        XCTAssertTrue(isWellFormedXML(withKw))
        XCTAssertTrue(isWellFormedXML(withoutKw))

        let withKwStr = try XCTUnwrap(String(data: withKw, encoding: .utf8))
        let withoutKwStr = try XCTUnwrap(String(data: withoutKw, encoding: .utf8))
        XCTAssertTrue(withKwStr.contains("keyword="),
                      "default encoding must include keyword attributes")
        XCTAssertFalse(withoutKwStr.contains("keyword="),
                       "--no-keywords must omit keyword attributes")
    }

    // Oracle: --pretty stays semantically identical (same decoded values) and well-formed.
    func testPrettyPreservesSemantics() throws {
        let file = makeGrayscale8(rows: 2, cols: 2)
        let elements = file.dataSet.allElements.filter { $0.tag != Tag.pixelData }

        let compact = try encodeXML(elements, prettyPrinted: false)
        let pretty = try encodeXML(elements, prettyPrinted: true)

        XCTAssertTrue(isWellFormedXML(pretty))

        let a = DataSet(elements: try decodeXML(compact))
        let b = DataSet(elements: try decodeXML(pretty))
        XCTAssertEqual(a[.modality]?.stringValue, b[.modality]?.stringValue)
        XCTAssertEqual(a[.patientID]?.stringValue, b[.patientID]?.stringValue)
        XCTAssertEqual(a[.patientName]?.stringValue, b[.patientName]?.stringValue)
    }

    // Oracle: --inline-threshold — small binary inlines and survives base64 round-trip;
    //          above threshold with a bulk URL it becomes BulkData (no InlineBinary bytes).
    func testInlineThresholdControlsBinaryEncoding() throws {
        // A 32-byte OB element.
        let payload = Data((0..<32).map { UInt8($0) })
        let tag = Tag(group: 0x0009, element: 0x0010) // private-ish tag; VR OB explicit
        let binElem = DataElement.data(tag: tag, vr: .OB, data: payload)

        // Threshold >= size → inline base64; decode must recover the exact bytes.
        let inlined = try encodeXML([binElem], inlineBinaryThreshold: 64)
        let inlinedStr = try XCTUnwrap(String(data: inlined, encoding: .utf8))
        XCTAssertTrue(inlinedStr.contains("<InlineBinary>"),
                      "size <= threshold must inline as base64")
        let decodedInline = try decodeXML(inlined)
        let recovered = try XCTUnwrap(DataSet(elements: decodedInline)[tag])
        XCTAssertEqual(recovered.valueData, payload,
                       "inline base64 must round-trip binary bytes exactly")

        // Threshold < size AND a base URL → BulkData URI reference (no inline bytes).
        let bulk = try encodeXML([binElem],
                                 inlineBinaryThreshold: 8,
                                 bulkDataBaseURL: URL(string: "https://example.org/bulk"))
        let bulkStr = try XCTUnwrap(String(data: bulk, encoding: .utf8))
        XCTAssertTrue(bulkStr.contains("<BulkData"),
                      "size > threshold with base URL must emit a BulkData reference")
        XCTAssertFalse(bulkStr.contains("<InlineBinary>"),
                       "BulkData path must not also inline the bytes")
    }

    // Oracle: includeEmptyValues=false skips zero-length non-sequence elements; true keeps them.
    func testIncludeEmptyValuesControlsEmptyElements() throws {
        // An empty LO element (zero-length, not a sequence).
        let emptyTag = Tag.patientID
        let emptyElem = DataElement.data(tag: emptyTag, vr: .LO, data: Data())
        let modalityElem = DataElement.string(tag: .modality, vr: .CS, value: "CT")

        let skipped = try encodeXML([emptyElem, modalityElem], includeEmptyValues: false)
        let kept = try encodeXML([emptyElem, modalityElem], includeEmptyValues: true)

        let skippedTags = Set(try decodeXML(skipped).map { $0.tag })
        let keptTags = Set(try decodeXML(kept).map { $0.tag })

        XCTAssertFalse(skippedTags.contains(emptyTag),
                       "empty element must be dropped when includeEmptyValues=false")
        XCTAssertTrue(keptTags.contains(emptyTag),
                      "empty element must be present when includeEmptyValues=true")
        // Non-empty element always survives.
        XCTAssertTrue(skippedTags.contains(Tag.modality))
    }

    // Oracle: XML → DICOM (reverse) yields a valid Part 10 file re-readable by DICOMFile.read.
    func testReverseProducesReadableDICOMPart10() throws {
        let source = makeGrayscale8(rows: 4, cols: 4)
        let elements = source.dataSet.allElements.filter { $0.tag != Tag.pixelData }
        let xml = try encodeXML(elements)

        // Reverse pipeline (as in CLI convertXmlToDicom).
        let decoded = try decodeXML(xml)
        let ds = DataSet(elements: decoded)
        let tsUID = ds[Tag.transferSyntaxUID]?.stringValues?.first ?? "1.2.840.10008.1.2.1"
        let outFile = DICOMFile.create(dataSet: ds, transferSyntaxUID: tsUID)
        let outData = try outFile.write()

        // Oracle: the written bytes must parse back as a valid DICOM file.
        let reread = try DICOMFile.read(from: outData)
        XCTAssertEqual(reread.dataSet[.modality]?.stringValue, "CT")
        XCTAssertEqual(reread.dataSet[.patientID]?.stringValue, "RT001")
    }

    // Oracle (corpus realism): real Explicit-VR CT encodes to well-formed XML and
    // its Modality round-trips through XML unchanged.
    func testCorpusCTEncodesToWellFormedXML() throws {
        let f = try loadCorpus(.ct)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        let elements = file.dataSet.allElements.filter { $0.tag != Tag.pixelData }
        let xml = try encodeXML(elements, prettyPrinted: true)
        XCTAssertTrue(isWellFormedXML(xml), "real CT must encode to well-formed XML")

        let expectedModality = file.dataSet[.modality]?.stringValue
        let decoded = DataSet(elements: try decodeXML(xml))
        XCTAssertEqual(decoded[.modality]?.stringValue, expectedModality,
                       "Modality must survive the XML round-trip for real data")
    }
}

