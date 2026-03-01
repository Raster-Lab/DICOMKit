// ClipboardHelperTests.swift
// DICOMStudioTests
//
// Tests for ClipboardHelper

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ClipboardHelper Tests")
struct ClipboardHelperTests {

    // MARK: - formatTagForClipboard Tests

    @Test("Formats tag for clipboard")
    func testFormatTagForClipboard() {
        let result = ClipboardHelper.formatTagForClipboard(
            tagString: "(0010,0010)",
            name: "PatientName",
            value: "Doe^John"
        )
        #expect(result == "(0010,0010) PatientName = Doe^John")
    }

    @Test("Formats tag with empty value")
    func testFormatTagEmptyValue() {
        let result = ClipboardHelper.formatTagForClipboard(
            tagString: "(0010,0020)",
            name: "PatientID",
            value: "(empty)"
        )
        #expect(result == "(0010,0020) PatientID = (empty)")
    }

    // MARK: - formatMetadataRowForClipboard Tests

    @Test("Formats metadata row as tab-separated")
    func testFormatMetadataRow() {
        let result = ClipboardHelper.formatMetadataRowForClipboard(
            tagString: "(0010,0010)",
            vr: "PN",
            name: "PatientName",
            value: "Doe^John",
            length: "12 bytes"
        )
        #expect(result == "(0010,0010)\tPN\tPatientName\tDoe^John\t12 bytes")
    }

    // MARK: - formatValueForClipboard Tests

    @Test("Trims whitespace from value")
    func testFormatValueTrimsWhitespace() {
        #expect(ClipboardHelper.formatValueForClipboard("  hello  ") == "hello")
        #expect(ClipboardHelper.formatValueForClipboard("value\n") == "value")
    }

    @Test("Returns empty string for whitespace-only value")
    func testFormatValueEmpty() {
        #expect(ClipboardHelper.formatValueForClipboard("   ") == "")
    }

    // MARK: - formatNodeForClipboard Tests

    @Test("Formats metadata tree node")
    func testFormatNodeForClipboard() {
        let node = MetadataTreeNode(
            group: 0x0010,
            element: 0x0010,
            vr: "PN",
            name: "PatientName",
            value: "Doe^John",
            length: 8
        )
        let result = ClipboardHelper.formatNodeForClipboard(node)
        #expect(result.contains("(0010,0010)"))
        #expect(result.contains("PN"))
        #expect(result.contains("PatientName"))
        #expect(result.contains("Doe^John"))
    }

    // MARK: - formatNodesForClipboard Tests

    @Test("Formats multiple nodes with header")
    func testFormatNodesForClipboard() {
        let nodes = [
            MetadataTreeNode(
                group: 0x0010,
                element: 0x0010,
                vr: "PN",
                name: "PatientName",
                value: "Doe^John",
                length: 8
            ),
            MetadataTreeNode(
                group: 0x0010,
                element: 0x0020,
                vr: "LO",
                name: "PatientID",
                value: "P001",
                length: 4
            ),
        ]
        let result = ClipboardHelper.formatNodesForClipboard(nodes)
        let lines = result.split(separator: "\n")
        #expect(lines.count == 3) // header + 2 nodes
        #expect(lines[0] == "Tag\tVR\tName\tValue\tLength")
    }

    @Test("Formats nodes with children indented")
    func testFormatNodesWithChildren() {
        let child = MetadataTreeNode(
            group: 0x0010,
            element: 0x0010,
            vr: "PN",
            name: "PatientName",
            value: "Doe^John",
            length: 8
        )
        let parent = MetadataTreeNode(
            group: 0x0008,
            element: 0x1115,
            vr: "SQ",
            name: "ReferencedSeriesSequence",
            value: "1 item",
            length: 0xFFFFFFFF,
            children: [child]
        )
        let result = ClipboardHelper.formatNodesForClipboard([parent])
        let lines = result.split(separator: "\n")
        #expect(lines.count == 3) // header + parent + child
        #expect(String(lines[2]).hasPrefix("  "))
    }

    @Test("Formats empty nodes list with header only")
    func testFormatEmptyNodes() {
        let result = ClipboardHelper.formatNodesForClipboard([])
        #expect(result == "Tag\tVR\tName\tValue\tLength")
    }
}
