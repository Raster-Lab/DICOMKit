//
//  HangingProtocolTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

final class HangingProtocolTests: XCTestCase {
    
    func testCTChestProtocol() {
        let protocol = HangingProtocol.ctChest
        
        XCTAssertEqual(`protocol`.name, "CT Chest")
        XCTAssertEqual(`protocol`.modality, "CT")
        XCTAssertEqual(`protocol`.bodyPart, "CHEST")
        XCTAssertEqual(`protocol`.layout, ViewportLayout.twoByTwo)
        XCTAssertEqual(`protocol`.rules.count, 3)
    }
    
    func testCTAbdomenProtocol() {
        let protocol = HangingProtocol.ctAbdomen
        
        XCTAssertEqual(`protocol`.name, "CT Abdomen")
        XCTAssertEqual(`protocol`.modality, "CT")
        XCTAssertEqual(`protocol`.bodyPart, "ABDOMEN")
        XCTAssertEqual(`protocol`.layout, ViewportLayout.twoByTwo)
        XCTAssertEqual(`protocol`.rules.count, 3)
    }
    
    func testMRBrainProtocol() {
        let protocol = HangingProtocol.mrBrain
        
        XCTAssertEqual(`protocol`.name, "MR Brain")
        XCTAssertEqual(`protocol`.modality, "MR")
        XCTAssertEqual(`protocol`.bodyPart, "BRAIN")
        XCTAssertEqual(`protocol`.layout, ViewportLayout.threeByThree)
        XCTAssertEqual(`protocol`.rules.count, 5)
    }
    
    func testXRayProtocol() {
        let protocol = HangingProtocol.xray
        
        XCTAssertEqual(`protocol`.name, "X-Ray")
        XCTAssertEqual(`protocol`.modality, "CR")
        XCTAssertNil(`protocol`.bodyPart)
        XCTAssertEqual(`protocol`.layout, ViewportLayout.single)
        XCTAssertEqual(`protocol`.rules.count, 0)
    }
    
    func testSeriesAssignmentRule() {
        let rule = SeriesAssignmentRule(
            viewportIndex: 0,
            seriesDescription: "Axial",
            priority: 1
        )
        
        XCTAssertEqual(rule.viewportIndex, 0)
        XCTAssertEqual(rule.seriesDescription, "Axial")
        XCTAssertEqual(rule.priority, 1)
    }
    
    func testSeriesAssignmentRuleMatching() {
        let rule = SeriesAssignmentRule(
            viewportIndex: 0,
            seriesDescription: "Axial",
            priority: 1
        )
        
        // Create mock series
        let matchingSeries = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Axial CT",
            numberOfInstances: 100,
            bodyPartExamined: "CHEST"
        )
        
        let nonMatchingSeries = DicomSeries(
            seriesInstanceUID: "1.2.4",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 2,
            seriesDescription: "Coronal CT",
            numberOfInstances: 100,
            bodyPartExamined: "CHEST"
        )
        
        XCTAssertTrue(rule.matches(matchingSeries))
        XCTAssertFalse(rule.matches(nonMatchingSeries))
    }
    
    func testSeriesAssignmentRuleWithSeriesNumber() {
        let rule = SeriesAssignmentRule(
            viewportIndex: 0,
            seriesNumber: 1,
            priority: 1
        )
        
        let matchingSeries = DicomSeries(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Axial CT",
            numberOfInstances: 100,
            bodyPartExamined: nil
        )
        
        let nonMatchingSeries = DicomSeries(
            seriesInstanceUID: "1.2.4",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 2,
            seriesDescription: "Coronal CT",
            numberOfInstances: 100,
            bodyPartExamined: nil
        )
        
        XCTAssertTrue(rule.matches(matchingSeries))
        XCTAssertFalse(rule.matches(nonMatchingSeries))
    }
    
    func testProtocolEquality() {
        let protocol1 = HangingProtocol.ctChest
        let protocol2 = HangingProtocol.ctChest
        
        XCTAssertEqual(protocol1, protocol2)
    }
}
