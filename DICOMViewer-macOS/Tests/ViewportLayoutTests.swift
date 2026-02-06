//
//  ViewportLayoutTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

final class ViewportLayoutTests: XCTestCase {
    
    func testSingleLayout() {
        let layout = ViewportLayout.single
        
        XCTAssertEqual(layout.name, "1×1")
        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.columns, 1)
        XCTAssertEqual(layout.viewportCount, 1)
    }
    
    func testTwoByTwoLayout() {
        let layout = ViewportLayout.twoByTwo
        
        XCTAssertEqual(layout.name, "2×2")
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 2)
        XCTAssertEqual(layout.viewportCount, 4)
    }
    
    func testThreeByThreeLayout() {
        let layout = ViewportLayout.threeByThree
        
        XCTAssertEqual(layout.name, "3×3")
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.viewportCount, 9)
    }
    
    func testFourByFourLayout() {
        let layout = ViewportLayout.fourByFour
        
        XCTAssertEqual(layout.name, "4×4")
        XCTAssertEqual(layout.rows, 4)
        XCTAssertEqual(layout.columns, 4)
        XCTAssertEqual(layout.viewportCount, 16)
    }
    
    func testCustomLayout() {
        let layout = ViewportLayout(
            name: "3×2",
            rows: 2,
            columns: 3,
            description: "Custom layout"
        )
        
        XCTAssertEqual(layout.name, "3×2")
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.viewportCount, 6)
        XCTAssertEqual(layout.description, "Custom layout")
    }
    
    func testLayoutEquality() {
        let layout1 = ViewportLayout.single
        let layout2 = ViewportLayout.single
        
        XCTAssertEqual(layout1, layout2)
    }
    
    func testViewportLinkingNone() {
        let linking = ViewportLinking.none
        
        XCTAssertFalse(linking.scrollEnabled)
        XCTAssertFalse(linking.windowLevelEnabled)
        XCTAssertFalse(linking.zoomEnabled)
        XCTAssertFalse(linking.panEnabled)
    }
    
    func testViewportLinkingAll() {
        let linking = ViewportLinking.all
        
        XCTAssertTrue(linking.scrollEnabled)
        XCTAssertTrue(linking.windowLevelEnabled)
        XCTAssertTrue(linking.zoomEnabled)
        XCTAssertTrue(linking.panEnabled)
    }
    
    func testViewportCreation() {
        let viewport = Viewport()
        
        XCTAssertNil(viewport.series)
        XCTAssertEqual(viewport.currentInstanceIndex, 0)
    }
}
