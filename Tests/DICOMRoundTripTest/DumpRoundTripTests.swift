// DumpRoundTripTests.swift
// Oracle-based round-trip tests for the dicom-dump tool.
// Tests call the DICOMKit library (HexDumper / DICOMFile) directly — never the CLI.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class DumpRoundTripTests: XCTestCase {

    // MARK: - Private helpers

    /// Strips ANSI SGR escape sequences (ESC[…m) from a dump string.
    private func stripANSI(_ s: String) -> String {
        var out = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "\u{001B}", i + 1 < chars.count, chars[i + 1] == "[" {
                i += 2
                while i < chars.count, chars[i] != "m" { i += 1 }
                if i < chars.count { i += 1 } // consume the 'm'
            } else {
                out.append(chars[i])
                i += 1
            }
        }
        return out
    }

    /// The hex "(GGGG,EEEE)" string for a tag, exactly as Tag.description produces it.
    private func hexCode(_ tag: Tag) -> String {
        String(format: "(%04X,%04X)", tag.group, tag.element)
    }

    // MARK: - Oracle: every dataset tag's hex code appears in an annotated whole-file dump

    // Oracle: no tag is silently dropped — each parsed element's (GGGG,EEEE) appears in the dump.
    func testAnnotatedDumpContainsEveryTagHexCode() throws {
        let file = makeGrayscale16(rows: 8, cols: 8)
        let data = try file.write()

        let dumper = HexDumper(bytesPerLine: 16, useColor: false, annotate: true, verbose: false)
        let output = dumper.dump(data: data, startOffset: 0, dicomFile: file, highlightTag: nil)
        let plain = stripANSI(output)

        // Every element in the main dataset must be annotated by its hex code.
        for tag in file.dataSet.tags where tag != .pixelData {
            XCTAssertTrue(plain.contains(hexCode(tag)),
                          "dump missing annotation for \(hexCode(tag))")
        }
        // PixelData tag boundary must also be labelled.
        XCTAssertTrue(plain.contains(hexCode(.pixelData)),
                      "dump missing PixelData annotation")
    }

    // MARK: - Oracle: color is purely presentational (no-color == strip(color))

    // Oracle: --no-color output is byte-identical to colored output with ANSI stripped.
    func testNoColorEqualsStrippedColor() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let data = try file.write()

        let colored = HexDumper(bytesPerLine: 16, useColor: true, annotate: true, verbose: true)
            .dump(data: data, startOffset: 0, dicomFile: file, highlightTag: .patientName)
        let plain = HexDumper(bytesPerLine: 16, useColor: false, annotate: true, verbose: true)
            .dump(data: data, startOffset: 0, dicomFile: file, highlightTag: .patientName)

        XCTAssertEqual(stripANSI(colored), plain,
                       "colored dump with ANSI stripped must equal no-color dump")
    }

    // MARK: - Oracle: tagDump header reflects the parsed element metadata

    // Oracle: tagDump header carries the tag hex, the element's VR, and its exact Length.
    func testTagDumpHeaderMatchesParsedElement() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let element = try XCTUnwrap(file.dataSet[.patientName])

        let out = try XCTUnwrap(
            HexDumper.tagDump(tag: .patientName, in: file, useColor: false),
            "tagDump returned nil for a present tag")

        XCTAssertTrue(out.contains(hexCode(.patientName)), "header missing tag hex code")
        XCTAssertTrue(out.contains("VR=\(element.vr.rawValue)"), "header missing correct VR")
        XCTAssertTrue(out.contains("Length=\(element.length)"), "header missing correct Length")
    }

    // MARK: - Oracle: tagDump returns nil for an absent tag

    // Oracle: a tag not present in the file yields nil (semantic "not found").
    func testTagDumpNilForAbsentTag() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        // StudyDescription (0008,1030) is not set by the fixture builder.
        let absent = Tag(group: 0x0008, element: 0x1030)
        XCTAssertNil(file.dataSet[absent], "precondition: tag must be absent")
        XCTAssertNil(HexDumper.tagDump(tag: absent, in: file, useColor: false),
                     "tagDump must return nil for an absent tag")
    }

    // MARK: - Oracle: bytesPerLine controls hex bytes per line

    // Oracle: each full row of the hex dump lists exactly bytesPerLine 2-digit hex bytes.
    func testBytesPerLineControlsRowWidth() throws {
        // A payload larger than any line width so at least one full row exists.
        let payload = Data((0..<64).map { UInt8($0) })

        for width in [8, 16, 32] {
            let out = HexDumper(bytesPerLine: width, useColor: false, annotate: false, verbose: false)
                .dump(data: payload, startOffset: 0, dicomFile: nil, highlightTag: nil)
            // First line: "00000000  " + width * "HH " + padding + " |ascii|"
            let firstLine = try XCTUnwrap(out.split(separator: "\n").first).description
            // Count 2-hex-digit tokens before the ASCII gutter '|'.
            let hexRegion = String(firstLine.prefix(while: { $0 != "|" }))
            let hexTokens = hexRegion
                .split(separator: " ")
                .filter { $0.count == 2 && $0.allSatisfy { $0.isHexDigit } }
            XCTAssertEqual(hexTokens.count, width,
                           "expected \(width) hex bytes on first line, got \(hexTokens.count)")
        }
    }

    // MARK: - Oracle: offsets are 8-digit uppercase hex, incrementing by bytesPerLine

    // Oracle: successive line offsets are 8-digit uppercase hex and step by bytesPerLine.
    func testOffsetFormattingAndStride() throws {
        let payload = Data(count: 48) // 3 full rows at width 16
        let out = HexDumper(bytesPerLine: 16, useColor: false, annotate: false, verbose: false)
            .dump(data: payload, startOffset: 0, dicomFile: nil, highlightTag: nil)
        let lines = out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }

        XCTAssertTrue(lines[0].hasPrefix("00000000"), "first offset must be 00000000")
        XCTAssertTrue(lines[1].hasPrefix("00000010"), "second offset must be 00000010 (16)")
        XCTAssertTrue(lines[2].hasPrefix("00000020"), "third offset must be 00000020 (32)")
    }

    // MARK: - Oracle: ASCII gutter renders printable bytes as-is, others as '.'

    // Oracle: printable bytes [32..126] appear literally in the gutter; others render '.'.
    func testAsciiGutterPrintableVsDot() throws {
        // Byte 65 = 'A' (printable), byte 0 = NUL (non-printable).
        let payload = Data([65, 0])
        let out = HexDumper(bytesPerLine: 16, useColor: false, annotate: false, verbose: false)
            .dump(data: payload, startOffset: 0, dicomFile: nil, highlightTag: nil)
        let line = try XCTUnwrap(out.split(separator: "\n").first).description
        // Gutter is between the two '|' markers.
        let parts = line.split(separator: "|", omittingEmptySubsequences: false)
        XCTAssertGreaterThanOrEqual(parts.count, 3, "line must contain an ASCII gutter")
        let gutter = String(parts[1])
        XCTAssertEqual(gutter.first, "A", "printable 'A' must render literally")
        XCTAssertEqual(Array(gutter)[1], ".", "NUL must render as '.'")
    }

    // MARK: - Oracle: --highlight marks the element with a HIGHLIGHT marker

    // Oracle: highlighting a present tag emits exactly one "◀ HIGHLIGHT" marker naming it.
    func testHighlightAddsMarkerForTag() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let data = try file.write()

        let out = HexDumper(bytesPerLine: 16, useColor: false, annotate: false, verbose: false)
            .dump(data: data, startOffset: 0, dicomFile: file, highlightTag: .modality)
        let markerCount = out.components(separatedBy: "◀ HIGHLIGHT").count - 1
        XCTAssertEqual(markerCount, 1, "exactly one highlight marker expected")
        // The marker line carries the highlighted tag's hex code.
        XCTAssertTrue(out.contains(hexCode(.modality)),
                      "highlight marker must name the highlighted tag")
    }

    // MARK: - Oracle: --verbose appends VR and Len to annotations

    // Oracle: verbose annotations carry "VR=xx" and "Len=N" for a defined-length element.
    func testVerboseAppendsVRAndLength() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let data = try file.write()

        let out = HexDumper(bytesPerLine: 16, useColor: false, annotate: true, verbose: true)
            .dump(data: data, startOffset: 0, dicomFile: file, highlightTag: nil)
        let plain = stripANSI(out)
        XCTAssertTrue(plain.contains("VR="), "verbose annotations must include VR=")
        XCTAssertTrue(plain.contains("Len="), "verbose annotations must include Len=")
    }

    // MARK: - Oracle: tagDump maxBytes cap shows exactly N bytes + footer

    // Oracle: capping to N (< full) dumps exactly N value bytes and emits the "showing first N of M" footer.
    func testTagDumpMaxBytesCapAndFooter() throws {
        // 16x16 8-bit => 256 pixel bytes; cap the dump to 32.
        let file = makeGrayscale8(rows: 16, cols: 16)
        let full = try XCTUnwrap(file.dataSet[.pixelData]).valueData
        XCTAssertGreaterThan(full.count, 32, "precondition: value larger than cap")

        let cap = 32
        let out = try XCTUnwrap(
            HexDumper.tagDump(tag: .pixelData, in: file, useColor: false, maxBytes: cap))

        XCTAssertTrue(out.contains("showing first \(cap) of \(full.count) bytes"),
                      "footer must report the cap and full size")

        // Count the 2-hex-digit byte tokens in the hex region (before any gutter).
        let bodyLines = out.split(separator: "\n").map(String.init)
        var hexByteCount = 0
        for line in bodyLines {
            // Hex data lines start with an 8-digit offset.
            guard line.count >= 8, line.prefix(8).allSatisfy({ $0.isHexDigit }) else { continue }
            let hexRegion = String(line.prefix(while: { $0 != "|" }).dropFirst(8))
            hexByteCount += hexRegion
                .split(separator: " ")
                .filter { $0.count == 2 && $0.allSatisfy { $0.isHexDigit } }
                .count
        }
        XCTAssertEqual(hexByteCount, cap, "exactly \(cap) value bytes must be dumped")
    }

    // MARK: - Oracle: tagDump verbose shows a formatted value line

    // Oracle: verbose tagDump adds a "Value:" line for a string element.
    func testTagDumpVerboseValueLine() throws {
        let file = makeGrayscale8(rows: 4, cols: 4)
        let out = try XCTUnwrap(
            HexDumper.tagDump(tag: .modality, in: file, useColor: false, verbose: true))
        XCTAssertTrue(out.contains("Value:"), "verbose tagDump must include a Value line")
        // Modality was set to "CT" by the fixture builder.
        XCTAssertTrue(out.contains("CT"), "value preview must reflect the stored value")
    }

    // MARK: - Oracle: --force parses a legacy Implicit-VR file and exposes its tags

    // Oracle: force-reading the Implicit-VR MR corpus yields a parsable dataset whose tags annotate.
    func testForceParsesImplicitVRCorpus() throws {
        let f = try loadCorpus(.mr)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        // The dataset parsed at all — Modality/Rows must be present.
        let modality = try XCTUnwrap(file.dataSet[.modality]).stringValue
        XCTAssertEqual(modality?.trimmingCharacters(in: .whitespaces), "MR")

        // Annotated dump over the raw file bytes labels the Modality boundary.
        let data = try Data(contentsOf: try XCTUnwrap(corpusURL(.mr)))
        let out = HexDumper(bytesPerLine: 16, useColor: false, annotate: true, verbose: false)
            .dump(data: data, startOffset: 0, dicomFile: file, highlightTag: nil)
        XCTAssertTrue(stripANSI(out).contains(hexCode(.modality)),
                      "annotated dump of implicit-VR file must label Modality")
    }

    // MARK: - Oracle: --offset re-bases the slice and labels from the requested offset

    /// Mirrors dicom-dump's whole-file dump pipeline (main.swift `run()`): parse an
    /// offset, cap the length (default 64 KiB), re-base the byte slice to 0-based
    /// indices, and append the truncation footer when a cap trims the tail. The
    /// re-base (`Data(fileData[startOffset..<end])`) is the fix the tool carries a
    /// comment about — a raw `Data` slice keeps its parent's indices and traps the
    /// 0-based dump loop whenever startOffset > 0.
    private func wholeFileDump(_ fileData: Data, startOffset: Int, length: Int?,
                              bytesPerLine: Int = 16) -> String {
        let defaultDumpCap = 65_536
        let dumpLength = length ?? min(defaultDumpCap, fileData.count - startOffset)
        let endOffset = min(startOffset + dumpLength, fileData.count)
        let dataToShow = Data(fileData[startOffset..<endOffset])   // re-base to 0-based
        var output = HexDumper(bytesPerLine: bytesPerLine, useColor: false, annotate: false, verbose: false)
            .dump(data: dataToShow, startOffset: startOffset, dicomFile: nil, highlightTag: nil)
        if length == nil && endOffset < fileData.count {
            output += "\n… showing first \(endOffset - startOffset) of \(fileData.count) bytes — pass --length to dump more.\n"
        }
        return output
    }

    /// Reconstructs the byte sequence a no-color hex dump rendered, by parsing the
    /// 2-hex-digit tokens after each line's 8-digit offset (ignoring the ASCII gutter
    /// and any footer). Lets an oracle compare dumped bytes against the source exactly.
    private func dumpedBytes(_ output: String) -> [UInt8] {
        var bytes: [UInt8] = []
        for line in output.split(separator: "\n") {
            let s = String(line)
            guard s.count >= 8, s.prefix(8).allSatisfy({ $0.isHexDigit }) else { continue }
            let hexRegion = String(s.prefix(while: { $0 != "|" }).dropFirst(8))
            for tok in hexRegion.split(separator: " ") where tok.count == 2 && tok.allSatisfy({ $0.isHexDigit }) {
                if let b = UInt8(tok, radix: 16) { bytes.append(b) }
            }
        }
        return bytes
    }

    // Oracle: dumping from a non-zero --offset re-bases the slice (no crash), labels
    // the first line with the requested offset in 8-digit hex, and reproduces exactly
    // the source bytes from that offset onward. Offset 128 lands on the 'DICM' magic.
    func testOffsetRebasesAndLabelsFromStartOffset() throws {
        let file = makeGrayscale8(rows: 8, cols: 8)
        let data = try file.write()
        XCTAssertGreaterThan(data.count, 132, "precondition: file has preamble + DICM")

        let out = wholeFileDump(data, startOffset: 128, length: nil)
        let lines = out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }

        // First rendered offset label is the requested startOffset (128 = 0x80), and
        // the stride continues from there (144 = 0x90) — proving startOffset is the
        // display base, not a data index.
        XCTAssertTrue(lines[0].hasPrefix("00000080"), "first offset label must be 00000080 (128)")
        XCTAssertTrue(lines[1].hasPrefix("00000090"), "second offset label must be 00000090 (144)")

        // The 'DICM' magic sits at offset 128 → first four bytes + ASCII gutter.
        XCTAssertTrue(lines[0].contains("44 49 43 4D"), "offset-128 dump must start at the DICM magic")
        XCTAssertTrue(lines[0].contains("|DICM"), "ASCII gutter must render DICM")

        // Byte-exact fidelity: the dump reproduces data[128...] verbatim (the re-base
        // regression — a mis-based slice would crash or mis-render here).
        XCTAssertEqual(dumpedBytes(out), Array(data[128...]),
                       "re-based offset dump must reproduce the source tail byte-for-byte")
    }

    // Oracle: with no explicit --length, a whole-file dump caps at 64 KiB and appends
    // the "showing first N of M bytes" footer; exactly 65536 bytes are shown and they
    // are the file's leading 65536 bytes (no over- or under-dump).
    func testWholeFileLengthCapAndTruncationFooter() throws {
        // 256×256 16-bit → 131072 pixel bytes, so the whole file exceeds the 64 KiB cap.
        let file = makeGrayscale16(rows: 256, cols: 256)
        let data = try file.write()
        XCTAssertGreaterThan(data.count, 65_536, "precondition: file larger than the cap")

        let out = wholeFileDump(data, startOffset: 0, length: nil)

        XCTAssertTrue(out.contains("showing first 65536 of \(data.count) bytes"),
                      "footer must report the 64 KiB cap and the full size")
        let shown = dumpedBytes(out)
        XCTAssertEqual(shown.count, 65_536, "exactly 65536 bytes must be dumped under the default cap")
        XCTAssertEqual(shown, Array(data[0..<65_536]), "dumped bytes must be the file's leading 65536")

        // Last data line is at 65536-16 = 0x0000FFF0; the cap must not spill into 0x00010000.
        XCTAssertTrue(out.contains("0000FFF0"), "last capped line offset must be 0000FFF0")
        XCTAssertFalse(out.split(separator: "\n").contains { $0.hasPrefix("00010000") },
                       "dump must not exceed the 64 KiB cap")
    }
}

