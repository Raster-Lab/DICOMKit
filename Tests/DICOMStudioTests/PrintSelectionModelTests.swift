// PrintSelectionModelTests.swift
// DICOMStudioTests
//
// The viewer's print checkbox: nothing is marked until the user ticks it,
// and only ticked frames reach the print job.

import Testing
@testable import DICOMStudio
import Foundation

@MainActor
@Suite("Print Selection Model Tests")
struct PrintSelectionModelTests {

    @Test("Selection starts empty — every image is unchecked by default")
    func testDefaultsUnchecked() {
        let selection = PrintSelectionModel()
        #expect(selection.isEmpty)
        #expect(selection.count == 0)
        #expect(!selection.contains(filePath: "/a.dcm", frameIndex: 0))
        #expect(selection.position(ofFilePath: "/a.dcm", frameIndex: 0) == nil)
    }

    @Test("Toggling checks then unchecks a frame")
    func testToggle() {
        let selection = PrintSelectionModel()
        let item = PrintSelectionItem(filePath: "/a.dcm", frameIndex: 2, frameCount: 10)

        #expect(selection.toggle(item) == true)
        #expect(selection.contains(filePath: "/a.dcm", frameIndex: 2))
        #expect(selection.count == 1)

        #expect(selection.toggle(item) == false)
        #expect(selection.isEmpty)
    }

    @Test("Only checked frames are collected, in check order")
    func testOnlyCheckedFramesCollected() {
        let selection = PrintSelectionModel()
        selection.add(PrintSelectionItem(filePath: "/b.dcm", frameIndex: 0))
        selection.add(PrintSelectionItem(filePath: "/a.dcm", frameIndex: 3))

        #expect(selection.items.map(\.filePath) == ["/b.dcm", "/a.dcm"])
        #expect(selection.position(ofFilePath: "/a.dcm", frameIndex: 3) == 2)
        // An unchecked frame of a checked file stays out of the job.
        #expect(!selection.contains(filePath: "/a.dcm", frameIndex: 0))
    }

    @Test("Library \"Print…\" adds to viewer marks instead of replacing them")
    func testLibraryPrintPreservesViewerMarks() {
        let selection = PrintSelectionModel()
        // A frame the user ticked in the viewer, carrying its presentation.
        selection.add(PrintSelectionItem(
            filePath: "/a.dcm", frameIndex: 3, windowCenter: 40, windowWidth: 400))

        // The library then sends two files, one of which is already marked.
        selection.add(contentsOf: [
            PrintSelectionItem(filePath: "/a.dcm", frameIndex: 3),
            PrintSelectionItem(filePath: "/b.dcm", frameIndex: 0),
        ])

        #expect(selection.count == 2)
        #expect(selection.position(ofFilePath: "/a.dcm", frameIndex: 3) == 1)
        // The viewer's captured window/level survived; it was not overwritten.
        #expect(selection.items[0].windowCenter == 40)
        #expect(selection.items[0].windowWidth == 400)
        #expect(selection.items[1].filePath == "/b.dcm")
    }

    @Test("Checking the same frame twice does not duplicate a film cell")
    func testNoDuplicates() {
        let selection = PrintSelectionModel()
        let item = PrintSelectionItem(filePath: "/a.dcm", frameIndex: 0)
        #expect(selection.add(item) == true)
        #expect(selection.add(item) == false)
        #expect(selection.count == 1)
    }
}
