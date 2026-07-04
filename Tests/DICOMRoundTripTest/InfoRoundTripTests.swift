// InfoRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-info` tool.
//
// dicom-info parses a DICOM file (DICOMFile.read) and renders its metadata via
// the shared MetadataPresenter (text / json / csv). These tests drive the
// DICOMKit library directly — never the CLI — and assert only oracles that are
// true by definition of what "display the file's metadata" means:
//   * every value the presenter prints equals what DICOMFile.read parsed;
//   * every non-filtered tag appears (hex code present, nothing silently dropped);
//   * filter / private / statistics flags are exact subset/superset relations;
//   * the three output formats are mutually consistent and structurally valid.
//
// See ROUND_TRIP_TESTS_PLAN.md §3.10.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class InfoRoundTripTests: XCTestCase {

    // MARK: - §3.10 info output matches DICOMCore parsed values

    /// Oracle: known PatientName / Modality / Rows / TransferSyntaxUID printed by
    /// the text presenter each equal the value DICOMFile.read independently parses.
    func testTextOutputMatchesParsedValues() throws {
        let file = makeGrayscale16(rows: 8, cols: 6)
        let text = try MetadataPresenter(file: file).render(format: .text)

        // Parse the same file independently as the oracle source of truth.
        let parsed = try DICOMFile.read(from: file.write())

        let patientName = try XCTUnwrap(parsed.dataSet.string(for: .patientName))
        let modality = try XCTUnwrap(parsed.dataSet.string(for: .modality))
        let rows = try XCTUnwrap(parsed.dataSet[.rows]?.uint16Value)
        let ts = try XCTUnwrap(parsed.fileMetaInformation.string(for: .transferSyntaxUID))

        XCTAssertTrue(text.contains(patientName), "PatientName value must appear in output")
        XCTAssertTrue(text.contains(modality), "Modality value must appear in output")
        XCTAssertTrue(text.contains(String(rows)), "Rows value must appear in output")
        XCTAssertTrue(text.contains(ts), "TransferSyntaxUID must appear in output")
    }

    /// Oracle: every non-private tag in the parsed dataset has its (GGGG,EEEE) hex
    /// code present in the text output — no tag is silently missing.
    func testAllTagsAppearInTextOutput() throws {
        let file = makeGrayscale8(rows: 16, cols: 16)
        let text = try MetadataPresenter(file: file).render(format: .text)

        for tag in file.dataSet.tags where !tag.isPrivate {
            XCTAssertTrue(
                text.contains(tag.description),
                "Tag \(tag.description) missing from dump output")
        }
    }

    // MARK: - Format consistency (--format json / csv)

    /// Oracle: JSON render is valid JSON whose dataSet array carries one entry per
    /// non-private tag, each with tag/name/vr matching the parsed element.
    func testJSONFormatIsValidAndComplete() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let json = try MetadataPresenter(file: file).render(format: .json)

        let obj = try JSONSerialization.jsonObject(
            with: Data(json.utf8)) as? [String: Any]
        let root = try XCTUnwrap(obj, "JSON output must be a top-level object")
        let dataSetArr = try XCTUnwrap(root["dataSet"] as? [[String: Any]])

        let expectedTags = file.dataSet.tags.filter { !$0.isPrivate }
        XCTAssertEqual(
            dataSetArr.count, expectedTags.count,
            "JSON dataSet must have one entry per non-private tag")

        // Every rendered tag string must be a real tag in the dataset, with the
        // VR the parser assigned.
        for entry in dataSetArr {
            let tagStr = try XCTUnwrap(entry["tag"] as? String)
            let match = expectedTags.first { $0.description == tagStr }
            let tag = try XCTUnwrap(match, "JSON tag \(tagStr) not in dataset")
            let element = try XCTUnwrap(file.dataSet[tag])
            XCTAssertEqual(entry["vr"] as? String, element.vr.rawValue)
        }
    }

    /// Oracle: CSV render has the fixed header plus exactly one data row per
    /// included element (fileMeta + dataSet, non-private), and every row's leading
    /// field is a real tag description.
    func testCSVFormatRowCountAndHeader() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let csv = try MetadataPresenter(file: file).render(format: .csv)

        var lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        XCTAssertEqual(lines.first, "Tag,Name,VR,Value", "CSV header must match")
        lines.removeFirst()

        let metaTags = file.fileMetaInformation.tags.filter { !$0.isPrivate }
        let dataTags = file.dataSet.tags.filter { !$0.isPrivate }
        XCTAssertEqual(
            lines.count, metaTags.count + dataTags.count,
            "CSV must have one data row per included element")

        // Every data row's first CSV field is a quoted tag description that exists.
        // The field itself contains a comma ("(GGGG,EEEE)"), so extract the text
        // between the first pair of double quotes rather than splitting on comma.
        let allTagDescs = Set((metaTags + dataTags).map { $0.description })
        for line in lines {
            let firstField = firstQuotedField(line)
            XCTAssertTrue(
                allTagDescs.contains(firstField),
                "CSV row tag \(firstField) not a real tag")
        }
    }

    /// Returns the substring between the first pair of double quotes in a CSV line.
    private func firstQuotedField(_ line: String) -> String {
        guard let open = line.firstIndex(of: "\"") else { return "" }
        let after = line.index(after: open)
        guard let close = line[after...].firstIndex(of: "\"") else { return "" }
        return String(line[after..<close])
    }

    // MARK: - --tag filter

    /// Oracle: filtering by a tag's dictionary name yields a strict subset — the
    /// matched tag is present and an unrelated tag is absent. The presenter matches
    /// the filter against the dictionary `name` (e.g. "Modality"), so we resolve the
    /// oracle name from the dictionary rather than hard-coding a keyword.
    func testTagFilterRestrictsOutput() throws {
        let file = makeGrayscale16(rows: 4, cols: 4)
        let name = try XCTUnwrap(
            DataElementDictionary.lookup(tag: .modality)?.name)   // "Modality"

        let filtered = try MetadataPresenter(
            file: file, filterTags: [name]).render(format: .text)

        XCTAssertTrue(
            filtered.contains(Tag.modality.description),
            "Filter must keep the matching tag")
        XCTAssertFalse(
            filtered.contains(Tag.rows.description),
            "Filter must drop non-matching tags")
    }

    /// Oracle: filtering by a tag's hex code (e.g. (0010,0010)) also matches, since
    /// the presenter compares the filter against tag.description too.
    func testTagFilterByHexCode() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let hex = Tag.patientName.description   // "(0010,0010)"

        let filtered = try MetadataPresenter(
            file: file, filterTags: [hex]).render(format: .text)

        XCTAssertTrue(filtered.contains(hex), "Hex-code filter must match its tag")
        XCTAssertFalse(
            filtered.contains(Tag.rows.description),
            "Hex-code filter must exclude other tags")
    }

    // MARK: - --show-private

    /// Oracle: a private tag is hidden by default and revealed only when
    /// includePrivate is set (exact toggle, everything else unchanged).
    func testShowPrivateTogglesPrivateTags() throws {
        var ds = makeGrayscale8(rows: 4, cols: 4).dataSet
        // Odd group => private tag.
        let privateTag = Tag(group: 0x0009, element: 0x0010)
        XCTAssertTrue(privateTag.isPrivate)
        ds[privateTag] = DataElement.string(
            tag: privateTag, vr: .LO, value: "PRIVATE_MARKER_VALUE")
        let file = DICOMFile.create(
            dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")

        let hidden = try MetadataPresenter(
            file: file, includePrivate: false).render(format: .text)
        let shown = try MetadataPresenter(
            file: file, includePrivate: true).render(format: .text)

        XCTAssertFalse(
            hidden.contains(privateTag.description),
            "Private tag must be hidden by default")
        XCTAssertTrue(
            shown.contains(privateTag.description),
            "Private tag must appear with includePrivate")
    }

    // MARK: - --statistics

    /// Oracle: the statistics section reports the transfer syntax, SOP class and
    /// modality exactly as parsed; without the flag no such section is emitted.
    func testStatisticsSectionMatchesParsedValues() throws {
        let file = makeGrayscale16(rows: 4, cols: 4)

        let withStats = try MetadataPresenter(
            file: file, showStats: true).render(format: .text)
        let noStats = try MetadataPresenter(
            file: file, showStats: false).render(format: .text)

        XCTAssertTrue(withStats.contains("=== File Statistics ==="))
        XCTAssertFalse(noStats.contains("=== File Statistics ==="))

        let ts = try XCTUnwrap(file.fileMetaInformation.string(for: .transferSyntaxUID))
        let sop = try XCTUnwrap(file.dataSet.string(for: .sopClassUID))
        let modality = try XCTUnwrap(file.dataSet.string(for: .modality))
        XCTAssertTrue(withStats.contains("Transfer Syntax: \(ts)"))
        XCTAssertTrue(withStats.contains("SOP Class: \(sop)"))
        XCTAssertTrue(withStats.contains("Modality: \(modality)"))
    }

    // MARK: - formatElementValue oracles

    /// Oracle: a string value longer than 80 chars is truncated to 77 chars + "...".
    func testFormatElementValueTruncatesLongStrings() throws {
        let long = String(repeating: "A", count: 200)
        let element = DataElement.string(
            tag: Tag(group: 0x0008, element: 0x1030), vr: .LO, value: long)
        let rendered = MetadataPresenter.formatElementValue(element)

        XCTAssertTrue(rendered.hasSuffix("..."), "Long string must end with ellipsis")
        XCTAssertEqual(rendered.count, 80, "Truncated = 77 chars + '...'")
        XCTAssertEqual(rendered, String(repeating: "A", count: 77) + "...")
    }

    /// Oracle: a short string value is rendered verbatim (no truncation).
    func testFormatElementValueShortStringVerbatim() throws {
        let element = DataElement.string(
            tag: Tag(group: 0x0010, element: 0x0010), vr: .PN, value: "Doe^Jane")
        XCTAssertEqual(MetadataPresenter.formatElementValue(element), "Doe^Jane")
    }

    /// Oracle: a multi-valued US element renders each parsed value, backslash-joined.
    func testFormatElementValueUSMultiValue() throws {
        // Two UInt16 values 300 and 40 (little-endian) → "300\40".
        var data = Data()
        for v in [UInt16(300), UInt16(40)] {
            data.append(UInt8(v & 0xFF)); data.append(UInt8(v >> 8))
        }
        let element = DataElement.data(
            tag: Tag(group: 0x0028, element: 0x1100), vr: .US, data: data)
        XCTAssertEqual(MetadataPresenter.formatElementValue(element), "300\\40")
    }

    // MARK: - Tag ordering oracle

    /// Oracle: dataSet.tags is sorted by group then element, so the tag hex codes
    /// appear in the text output in strictly ascending order.
    func testTagsRenderInSortedOrder() throws {
        let file = makeRGB8(rows: 4, cols: 4)
        let tags = file.dataSet.tags
        XCTAssertEqual(tags, tags.sorted(), "dataSet.tags must be sorted")

        let text = try MetadataPresenter(file: file).render(format: .text)
        var lastIndex = text.startIndex
        for tag in tags where !tag.isPrivate {
            guard let r = text.range(of: tag.description, range: lastIndex..<text.endIndex)
            else {
                XCTFail("Tag \(tag.description) out of order or missing"); return
            }
            lastIndex = r.upperBound
        }
    }

    // MARK: - Corpus realism (implicit-VR / compressed)

    /// Oracle: parsing a real Implicit-VR-LE file and rendering it reproduces the
    /// exact PatientName / Modality / Rows the parser exposes (round-trip fidelity
    /// through the real parse path, not synthetic data).
    func testCorpusImplicitVRTextMatchesParsedValues() throws {
        let f = try loadCorpus(.mr)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        let text = try MetadataPresenter(file: file).render(format: .text)

        if let name = file.dataSet.string(for: .patientName), !name.isEmpty {
            XCTAssertTrue(text.contains(name))
        }
        if let modality = file.dataSet.string(for: .modality), !modality.isEmpty {
            XCTAssertTrue(text.contains(modality))
        }
        if let rows = file.dataSet[.rows]?.uint16Value {
            XCTAssertTrue(text.contains(String(rows)))
        }
    }

    /// Oracle: on a real compressed (J2K) file, the JSON statistics report the
    /// exact transfer syntax UID the parser read from the file meta information.
    func testCorpusCompressedStatisticsTransferSyntax() throws {
        let f = try loadCorpus(.j2kLossless)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        let ts = try XCTUnwrap(file.fileMetaInformation.string(for: .transferSyntaxUID))
        let json = try MetadataPresenter(file: file, showStats: true).render(format: .json)
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let root = try XCTUnwrap(obj)
        let stats = try XCTUnwrap(root["statistics"] as? [String: Any])
        XCTAssertEqual(stats["transferSyntax"] as? String, ts)
    }
}
