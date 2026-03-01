// ViewportModelTests.swift
// DICOMStudioTests
//
// Tests for Viewport models

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ViewportSyncMode Tests")
struct ViewportSyncModeTests {

    @Test("All sync modes")
    func testCaseCount() {
        #expect(ViewportSyncMode.allCases.count == 4)
    }

    @Test("Raw values")
    func testRawValues() {
        #expect(ViewportSyncMode.none.rawValue == "NONE")
        #expect(ViewportSyncMode.scroll.rawValue == "SCROLL")
        #expect(ViewportSyncMode.windowLevel.rawValue == "WINDOW_LEVEL")
        #expect(ViewportSyncMode.all.rawValue == "ALL")
    }
}

@Suite("ViewportToolMode Tests")
struct ViewportToolModeTests {

    @Test("All tool modes")
    func testCaseCount() {
        #expect(ViewportToolMode.allCases.count == 4)
    }
}

@Suite("ViewportState Tests")
struct ViewportStateTests {

    @Test("Default viewport state")
    func testDefaults() {
        let state = ViewportState(position: 0)
        #expect(state.position == 0)
        #expect(!state.hasImage)
        #expect(!state.isMultiFrame)
        #expect(!state.isActive)
        #expect(state.windowCenter == 128.0)
        #expect(state.windowWidth == 256.0)
        #expect(state.zoomLevel == 1.0)
    }

    @Test("Viewport with image")
    func testWithImage() {
        let state = ViewportState(
            position: 0,
            filePath: "/path/to/image.dcm",
            numberOfFrames: 120
        )
        #expect(state.hasImage)
        #expect(state.isMultiFrame)
    }

    @Test("Active viewport")
    func testActive() {
        let state = ViewportState(position: 0, isActive: true)
        #expect(state.isActive)
    }

    @Test("Viewport is identifiable")
    func testIdentifiable() {
        let a = ViewportState(position: 0)
        let b = ViewportState(position: 0)
        #expect(a.id != b.id)
    }
}

@Suite("CrossReferenceLine Tests")
struct CrossReferenceLineTests {

    @Test("Cross-reference line creation")
    func testCreation() {
        let sourceID = UUID()
        let targetID = UUID()
        let line = CrossReferenceLine(
            sourceViewportID: sourceID,
            targetViewportID: targetID,
            startPoint: AnnotationPoint(x: 0, y: 256),
            endPoint: AnnotationPoint(x: 512, y: 256)
        )
        #expect(line.sourceViewportID == sourceID)
        #expect(line.targetViewportID == targetID)
        #expect(line.startPoint.x == 0)
        #expect(line.endPoint.x == 512)
    }
}
