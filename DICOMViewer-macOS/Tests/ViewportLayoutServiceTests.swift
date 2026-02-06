//
//  ViewportLayoutServiceTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

@MainActor
final class ViewportLayoutServiceTests: XCTestCase {
    
    var service: ViewportLayoutService!
    
    override func setUp() async throws {
        service = ViewportLayoutService()
    }
    
    override func tearDown() async throws {
        service = nil
    }
    
    func testInitialState() {
        XCTAssertEqual(service.currentLayout, ViewportLayout.single)
        XCTAssertEqual(service.viewports.count, 1)
        XCTAssertNotNil(service.selectedViewportId)
        XCTAssertEqual(service.linking, ViewportLinking.none)
    }
    
    func testSetLayoutToTwoByTwo() {
        service.setLayout(.twoByTwo)
        
        XCTAssertEqual(service.currentLayout, .twoByTwo)
        XCTAssertEqual(service.viewports.count, 4)
    }
    
    func testSetLayoutPreservesSeriesAssignments() {
        // Create mock series
        let series1 = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Test Series 1",
            numberOfInstances: 10,
            bodyPartExamined: nil
        )
        
        // Assign series to first viewport
        let firstViewportId = service.viewports[0].id
        service.assignSeries(series1, to: firstViewportId)
        
        // Change layout
        service.setLayout(.twoByTwo)
        
        // First viewport should still have the series
        XCTAssertEqual(service.viewports[0].series?.seriesInstanceUID, series1.seriesInstanceUID)
    }
    
    func testAssignSeries() {
        let series = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Test Series",
            numberOfInstances: 10,
            bodyPartExamined: nil
        )
        
        let viewportId = service.viewports[0].id
        service.assignSeries(series, to: viewportId)
        
        XCTAssertEqual(service.viewports[0].series?.seriesInstanceUID, series.seriesInstanceUID)
        XCTAssertEqual(service.viewports[0].currentInstanceIndex, 0)
    }
    
    func testClearViewport() {
        let series = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Test Series",
            numberOfInstances: 10,
            bodyPartExamined: nil
        )
        
        let viewportId = service.viewports[0].id
        service.assignSeries(series, to: viewportId)
        service.clearViewport(viewportId)
        
        XCTAssertNil(service.viewports[0].series)
        XCTAssertEqual(service.viewports[0].currentInstanceIndex, 0)
    }
    
    func testClearAllViewports() {
        service.setLayout(.twoByTwo)
        
        let series = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Test Series",
            numberOfInstances: 10,
            bodyPartExamined: nil
        )
        
        // Assign series to all viewports
        for viewport in service.viewports {
            service.assignSeries(series, to: viewport.id)
        }
        
        service.clearAllViewports()
        
        for viewport in service.viewports {
            XCTAssertNil(viewport.series)
        }
    }
    
    func testSelectViewport() {
        service.setLayout(.twoByTwo)
        
        let secondViewportId = service.viewports[1].id
        service.selectViewport(secondViewportId)
        
        XCTAssertEqual(service.selectedViewportId, secondViewportId)
    }
    
    func testUpdateInstanceIndex() {
        let viewportId = service.viewports[0].id
        service.updateInstanceIndex(5, for: viewportId)
        
        XCTAssertEqual(service.viewports[0].currentInstanceIndex, 5)
    }
    
    func testUpdateInstanceIndexWithScrollLinking() {
        service.setLayout(.twoByTwo)
        service.setScrollLinking(true)
        
        // Assign series to viewports so they can be synced
        let series = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Test Series",
            numberOfInstances: 10,
            bodyPartExamined: nil
        )
        
        for viewport in service.viewports {
            service.assignSeries(series, to: viewport.id)
        }
        
        // Update first viewport
        let firstViewportId = service.viewports[0].id
        service.updateInstanceIndex(3, for: firstViewportId)
        
        // All other viewports with series should be synced
        for i in 1..<service.viewports.count {
            XCTAssertEqual(service.viewports[i].currentInstanceIndex, 3)
        }
    }
    
    func testSetScrollLinking() {
        service.setScrollLinking(true)
        
        XCTAssertTrue(service.linking.scrollEnabled)
    }
    
    func testSetWindowLevelLinking() {
        service.setWindowLevelLinking(true)
        
        XCTAssertTrue(service.linking.windowLevelEnabled)
    }
    
    func testSetZoomLinking() {
        service.setZoomLinking(true)
        
        XCTAssertTrue(service.linking.zoomEnabled)
    }
    
    func testSetPanLinking() {
        service.setPanLinking(true)
        
        XCTAssertTrue(service.linking.panEnabled)
    }
    
    func testSetLinking() {
        service.setLinking(.all)
        
        XCTAssertTrue(service.linking.scrollEnabled)
        XCTAssertTrue(service.linking.windowLevelEnabled)
        XCTAssertTrue(service.linking.zoomEnabled)
        XCTAssertTrue(service.linking.panEnabled)
    }
}
