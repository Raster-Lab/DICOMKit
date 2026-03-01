// ViewportLayoutHelpersTests.swift
// DICOMStudioTests
//
// Tests for ViewportLayoutHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ViewportLayoutHelpers Grid Tests")
struct ViewportLayoutGridTests {

    @Test("Single cell layout")
    func testSingleCell() {
        let frames = ViewportLayoutHelpers.gridCellFrames(
            columns: 1, rows: 1,
            totalWidth: 800, totalHeight: 600
        )
        #expect(frames.count == 1)
        #expect(frames[0].width == 800)
        #expect(frames[0].height == 600)
    }

    @Test("2x2 grid layout")
    func testTwoByTwo() {
        let frames = ViewportLayoutHelpers.gridCellFrames(
            columns: 2, rows: 2,
            totalWidth: 802, totalHeight: 602,
            spacing: 2
        )
        #expect(frames.count == 4)
        #expect(frames[0].width == 400)
        #expect(frames[0].height == 300)
    }

    @Test("Cell frames from layout type")
    func testFromLayoutType() {
        let frames = ViewportLayoutHelpers.cellFrames(
            for: .twoByOne,
            totalWidth: 802,
            totalHeight: 600,
            spacing: 2
        )
        #expect(frames.count == 2)
    }

    @Test("Zero spacing")
    func testZeroSpacing() {
        let frames = ViewportLayoutHelpers.gridCellFrames(
            columns: 2, rows: 2,
            totalWidth: 800, totalHeight: 600,
            spacing: 0
        )
        #expect(frames[0].width == 400)
        #expect(frames[0].height == 300)
    }
}

@Suite("ViewportLayoutHelpers Position Tests")
struct ViewportLayoutPositionTests {

    @Test("Position to row/column")
    func testPositionToRC() {
        let (row, col) = ViewportLayoutHelpers.positionToRowColumn(position: 5, columns: 3)
        #expect(row == 1)
        #expect(col == 2)
    }

    @Test("Row/column to position")
    func testRCToPosition() {
        let pos = ViewportLayoutHelpers.rowColumnToPosition(row: 1, column: 2, columns: 3)
        #expect(pos == 5)
    }

    @Test("Position 0 is row 0, column 0")
    func testOrigin() {
        let (row, col) = ViewportLayoutHelpers.positionToRowColumn(position: 0, columns: 3)
        #expect(row == 0)
        #expect(col == 0)
    }
}

@Suite("ViewportLayoutHelpers HitTest Tests")
struct ViewportLayoutHitTestTests {

    @Test("Hit test finds correct cell")
    func testHitTest() {
        let frames = ViewportLayoutHelpers.gridCellFrames(
            columns: 2, rows: 2,
            totalWidth: 800, totalHeight: 600,
            spacing: 0
        )
        // Center of first cell
        #expect(ViewportLayoutHelpers.hitTestCell(x: 200, y: 150, frames: frames) == 0)
        // Center of fourth cell
        #expect(ViewportLayoutHelpers.hitTestCell(x: 600, y: 450, frames: frames) == 3)
    }

    @Test("Hit test outside returns nil")
    func testHitTestMiss() {
        let frames = ViewportLayoutHelpers.gridCellFrames(
            columns: 1, rows: 1,
            totalWidth: 800, totalHeight: 600
        )
        #expect(ViewportLayoutHelpers.hitTestCell(x: 900, y: 100, frames: frames) == nil)
    }
}

@Suite("ViewportLayoutHelpers State Creation Tests")
struct ViewportLayoutStateTests {

    @Test("Create viewport states for layout")
    func testCreateStates() {
        let states = ViewportLayoutHelpers.createViewportStates(for: .twoByTwo)
        #expect(states.count == 4)
        #expect(states[0].isActive)
        #expect(!states[1].isActive)
    }

    @Test("Create states with custom active index")
    func testCustomActive() {
        let states = ViewportLayoutHelpers.createViewportStates(for: .twoByTwo, activeIndex: 2)
        #expect(!states[0].isActive)
        #expect(states[2].isActive)
    }

    @Test("Create states from hanging protocol")
    func testFromProtocol() {
        let proto = HangingProtocolModel(
            name: "Test",
            layoutType: .twoByOne,
            viewportDefinitions: [
                ViewportDefinition(position: 0, isInitialActive: false),
                ViewportDefinition(position: 1, isInitialActive: true)
            ]
        )
        let states = ViewportLayoutHelpers.createViewportStates(from: proto)
        #expect(states.count == 2)
        #expect(!states[0].isActive)
        #expect(states[1].isActive)
    }
}

@Suite("ViewportLayoutHelpers Display Tests")
struct ViewportLayoutDisplayTests {

    @Test("Layout description")
    func testDescription() {
        #expect(ViewportLayoutHelpers.layoutDescription(columns: 2, rows: 2) == "2×2 (4 viewports)")
        #expect(ViewportLayoutHelpers.layoutDescription(columns: 1, rows: 1) == "1×1 (1 viewport)")
    }

    @Test("Layout description from type")
    func testDescriptionFromType() {
        #expect(ViewportLayoutHelpers.layoutDescription(for: .single) == "1×1 (1 viewport)")
        #expect(ViewportLayoutHelpers.layoutDescription(for: .threeByThree) == "3×3 (9 viewports)")
    }
}
