// MetadataTreeNodeTests.swift
// DICOMStudioTests
//
// Tests for MetadataTreeNode model and MetadataTreeBuilder

import Testing
@testable import DICOMStudio
import Foundation

@Suite("MetadataTreeNode Tests")
struct MetadataTreeNodeTests {

    @Test("Basic node creation")
    func testBasicCreation() {
        let node = MetadataTreeNode(
            group: 0x0010, element: 0x0010, vr: "PN",
            name: "PatientName", value: "Doe^John"
        )
        #expect(node.group == 0x0010)
        #expect(node.element == 0x0010)
        #expect(node.vr == "PN")
        #expect(node.name == "PatientName")
        #expect(node.value == "Doe^John")
        #expect(!node.isSequence)
        #expect(!node.hasChildren)
    }

    @Test("Sequence node detection")
    func testSequenceNode() {
        let child = MetadataTreeNode(
            group: 0x0008, element: 0x0100, vr: "SH",
            name: "CodeValue", value: "T-D1100"
        )
        let node = MetadataTreeNode(
            group: 0x0040, element: 0xA730, vr: "SQ",
            name: "ContentSequence", value: "1 item",
            children: [child]
        )
        #expect(node.isSequence)
        #expect(node.hasChildren)
        #expect(node.children.count == 1)
    }

    @Test("Tag string formatting")
    func testTagString() {
        let node = MetadataTreeNode(
            group: 0x0008, element: 0x0016, vr: "UI",
            name: "SOPClassUID", value: "1.2.840.10008.5.1.4.1.1.2"
        )
        #expect(node.tagString == "(0008,0016)")
    }

    @Test("Tag string with high group")
    func testTagStringHighGroup() {
        let node = MetadataTreeNode(
            group: 0x7FE0, element: 0x0010, vr: "OW",
            name: "PixelData", value: "[1024 bytes]"
        )
        #expect(node.tagString == "(7FE0,0010)")
    }

    @Test("Length string for small values")
    func testLengthStringSmall() {
        let node = MetadataTreeNode(
            group: 0x0010, element: 0x0010, vr: "PN",
            name: "PatientName", value: "Doe^John", length: 100
        )
        #expect(node.lengthString == "100 bytes")
    }

    @Test("Length string for large values")
    func testLengthStringLarge() {
        let node = MetadataTreeNode(
            group: 0x7FE0, element: 0x0010, vr: "OW",
            name: "PixelData", value: "[data]", length: 524288
        )
        #expect(node.lengthString.contains("KB"))
    }

    @Test("Length string for undefined length")
    func testLengthStringUndefined() {
        let node = MetadataTreeNode(
            group: 0x0040, element: 0xA730, vr: "SQ",
            name: "ContentSequence", value: "1 item", length: 0xFFFFFFFF
        )
        #expect(node.lengthString == "Undefined")
    }

    @Test("Private tag detection")
    func testPrivateTag() {
        let node = MetadataTreeNode(
            group: 0x0009, element: 0x1010, vr: "LO",
            name: "Private Tag", value: "value",
            isPrivate: true, privateCreator: "SIEMENS"
        )
        #expect(node.isPrivate)
        #expect(node.privateCreator == "SIEMENS")
    }

    @Test("Total node count flat")
    func testTotalNodeCountFlat() {
        let node = MetadataTreeNode(
            group: 0x0010, element: 0x0010, vr: "PN",
            name: "PatientName", value: "Doe"
        )
        #expect(node.totalNodeCount == 1)
    }

    @Test("Total node count nested")
    func testTotalNodeCountNested() {
        let child1 = MetadataTreeNode(
            group: 0x0008, element: 0x0100, vr: "SH",
            name: "CodeValue", value: "T-D1100"
        )
        let child2 = MetadataTreeNode(
            group: 0x0008, element: 0x0102, vr: "SH",
            name: "CodingSchemeDesignator", value: "SRT"
        )
        let parent = MetadataTreeNode(
            group: 0x0040, element: 0xA730, vr: "SQ",
            name: "ContentSequence", value: "1 item",
            children: [child1, child2]
        )
        #expect(parent.totalNodeCount == 3)
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let node = MetadataTreeNode(
            group: 0x0010, element: 0x0010, vr: "PN",
            name: "PatientName", value: "Doe"
        )
        #expect(node.id != UUID())
    }
}

@Suite("MetadataTreeBuilder Tests")
struct MetadataTreeBuilderTests {

    @Test("Empty search returns all nodes")
    func testFilterEmpty() {
        let nodes = [
            MetadataTreeNode(group: 0x0010, element: 0x0010, vr: "PN", name: "PatientName", value: "Doe"),
            MetadataTreeNode(group: 0x0010, element: 0x0020, vr: "LO", name: "PatientID", value: "P001"),
        ]
        let filtered = MetadataTreeBuilder.filter(nodes: nodes, searchText: "")
        #expect(filtered.count == 2)
    }

    @Test("Filter by tag name")
    func testFilterByName() {
        let nodes = [
            MetadataTreeNode(group: 0x0010, element: 0x0010, vr: "PN", name: "PatientName", value: "Doe"),
            MetadataTreeNode(group: 0x0010, element: 0x0020, vr: "LO", name: "PatientID", value: "P001"),
        ]
        let filtered = MetadataTreeBuilder.filter(nodes: nodes, searchText: "PatientName")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "PatientName")
    }

    @Test("Filter by tag string")
    func testFilterByTagString() {
        let nodes = [
            MetadataTreeNode(group: 0x0010, element: 0x0010, vr: "PN", name: "PatientName", value: "Doe"),
            MetadataTreeNode(group: 0x0008, element: 0x0016, vr: "UI", name: "SOPClassUID", value: "1.2.3"),
        ]
        let filtered = MetadataTreeBuilder.filter(nodes: nodes, searchText: "0008")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "SOPClassUID")
    }

    @Test("Filter by value")
    func testFilterByValue() {
        let nodes = [
            MetadataTreeNode(group: 0x0010, element: 0x0010, vr: "PN", name: "PatientName", value: "Doe^John"),
            MetadataTreeNode(group: 0x0010, element: 0x0020, vr: "LO", name: "PatientID", value: "P001"),
        ]
        let filtered = MetadataTreeBuilder.filter(nodes: nodes, searchText: "doe")
        #expect(filtered.count == 1)
    }

    @Test("Filter preserves parent with matching child")
    func testFilterPreservesParent() {
        let child = MetadataTreeNode(
            group: 0x0008, element: 0x0100, vr: "SH",
            name: "CodeValue", value: "T-D1100"
        )
        let parent = MetadataTreeNode(
            group: 0x0040, element: 0xA730, vr: "SQ",
            name: "ContentSequence", value: "1 item",
            children: [child]
        )
        let filtered = MetadataTreeBuilder.filter(nodes: [parent], searchText: "CodeValue")
        #expect(filtered.count == 1)
        #expect(filtered[0].children.count == 1)
    }

    @Test("Filter removes non-matching branches")
    func testFilterRemovesNonMatching() {
        let child1 = MetadataTreeNode(
            group: 0x0008, element: 0x0100, vr: "SH",
            name: "CodeValue", value: "T-D1100"
        )
        let child2 = MetadataTreeNode(
            group: 0x0008, element: 0x0102, vr: "SH",
            name: "CodingSchemeDesignator", value: "SRT"
        )
        let parent = MetadataTreeNode(
            group: 0x0040, element: 0xA730, vr: "SQ",
            name: "ContentSequence", value: "1 item",
            children: [child1, child2]
        )
        let filtered = MetadataTreeBuilder.filter(nodes: [parent], searchText: "CodeValue")
        #expect(filtered.count == 1)
        #expect(filtered[0].children.count == 1)
        #expect(filtered[0].children[0].name == "CodeValue")
    }

    @Test("Filter by VR code")
    func testFilterByVR() {
        let nodes = [
            MetadataTreeNode(group: 0x0010, element: 0x0010, vr: "PN", name: "PatientName", value: "Doe"),
            MetadataTreeNode(group: 0x0010, element: 0x0020, vr: "LO", name: "PatientID", value: "P001"),
        ]
        let filtered = MetadataTreeBuilder.filter(nodes: nodes, searchText: "PN")
        #expect(filtered.count == 1)
    }

    @Test("Filter with no matches returns empty")
    func testFilterNoMatches() {
        let nodes = [
            MetadataTreeNode(group: 0x0010, element: 0x0010, vr: "PN", name: "PatientName", value: "Doe"),
        ]
        let filtered = MetadataTreeBuilder.filter(nodes: nodes, searchText: "XYZZY")
        #expect(filtered.isEmpty)
    }
}
