//
//  HangingProtocolServiceTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
@testable import DICOMViewer

@MainActor
final class HangingProtocolServiceTests: XCTestCase {
    
    var service: HangingProtocolService!
    var layoutService: ViewportLayoutService!
    
    override func setUp() async throws {
        service = HangingProtocolService()
        layoutService = ViewportLayoutService()
    }
    
    override func tearDown() async throws {
        service = nil
        layoutService = nil
    }
    
    func testInitialState() {
        XCTAssertEqual(service.protocols.count, HangingProtocol.standard.count)
        XCTAssertNil(service.currentProtocol)
    }
    
    func testSelectProtocol() {
        let protocol = HangingProtocol.ctChest
        service.selectProtocol(`protocol`)
        
        XCTAssertEqual(service.currentProtocol, `protocol`)
    }
    
    func testFindMatchingProtocolForCTStudy() {
        let study = DicomStudy(
            studyInstanceUID: "1.2.3",
            patientID: "12345",
            patientName: "Test Patient",
            patientBirthDate: nil,
            patientSex: nil,
            studyDate: Date(),
            studyTime: nil,
            studyDescription: "CT Chest",
            accessionNumber: nil,
            modalities: "CT",
            numberOfSeries: 3,
            numberOfInstances: 300,
            isStarred: false
        )
        
        let matchedProtocol = service.findMatchingProtocol(for: study)
        
        XCTAssertNotNil(matchedProtocol)
        XCTAssertEqual(matchedProtocol?.modality, "CT")
    }
    
    func testApplyProtocolSetsLayout() {
        let protocol = HangingProtocol.ctChest
        let series: [DicomSeries] = []
        
        service.applyProtocol(`protocol`, series: series, layoutService: layoutService)
        
        XCTAssertEqual(layoutService.currentLayout, `protocol`.layout)
        XCTAssertEqual(service.currentProtocol, `protocol`)
    }
    
    func testApplyProtocolAssignsSeriesByRules() {
        let protocol = HangingProtocol.ctChest
        
        let series1 = DicomSeries(
            seriesInstanceUID: "1.2.3.1",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Axial CT",
            numberOfInstances: 100,
            bodyPartExamined: "CHEST"
        )
        
        let series2 = DicomSeries(
            seriesInstanceUID: "1.2.3.2",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 2,
            seriesDescription: "Coronal Reconstruction",
            numberOfInstances: 50,
            bodyPartExamined: "CHEST"
        )
        
        let series = [series1, series2]
        
        service.applyProtocol(`protocol`, series: series, layoutService: layoutService)
        
        // Check that series were assigned to viewports
        let viewportsWithSeries = layoutService.viewports.filter { $0.series != nil }
        XCTAssertGreaterThan(viewportsWithSeries.count, 0)
    }
    
    func testApplyProtocolAssignsRemainingSeriestoEmptyViewports() {
        let protocol = HangingProtocol(
            name: "Test",
            description: "Test protocol",
            modality: "CT",
            bodyPart: nil,
            layout: .twoByTwo,
            rules: []
        )
        
        let series1 = DicomSeries(
            seriesInstanceUID: "1.2.3.1",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 1,
            seriesDescription: "Series 1",
            numberOfInstances: 100,
            bodyPartExamined: nil
        )
        
        let series2 = DicomSeries(
            seriesInstanceUID: "1.2.3.2",
            studyInstanceUID: "1.2",
            modality: "CT",
            seriesNumber: 2,
            seriesDescription: "Series 2",
            numberOfInstances: 100,
            bodyPartExamined: nil
        )
        
        let series = [series1, series2]
        
        service.applyProtocol(`protocol`, series: series, layoutService: layoutService)
        
        // Both series should be assigned to viewports
        let viewportsWithSeries = layoutService.viewports.filter { $0.series != nil }
        XCTAssertEqual(viewportsWithSeries.count, 2)
    }
    
    func testAddProtocol() {
        let customProtocol = HangingProtocol(
            name: "Custom",
            description: "Custom protocol",
            modality: "MR",
            bodyPart: "SPINE",
            layout: .twoByTwo,
            rules: []
        )
        
        let initialCount = service.protocols.count
        service.addProtocol(customProtocol)
        
        XCTAssertEqual(service.protocols.count, initialCount + 1)
        XCTAssertTrue(service.protocols.contains(where: { $0.id == customProtocol.id }))
    }
    
    func testRemoveProtocol() {
        let protocolToRemove = service.protocols.first!
        let initialCount = service.protocols.count
        
        service.removeProtocol(protocolToRemove)
        
        XCTAssertEqual(service.protocols.count, initialCount - 1)
        XCTAssertFalse(service.protocols.contains(where: { $0.id == protocolToRemove.id }))
    }
    
    func testUpdateProtocol() {
        var protocol = service.protocols.first!
        let originalName = `protocol`.name
        
        // Create updated protocol with same ID
        var updatedProtocol = `protocol`
        updatedProtocol = HangingProtocol(
            id: `protocol`.id,
            name: "Updated Name",
            description: `protocol`.description,
            modality: `protocol`.modality,
            bodyPart: `protocol`.bodyPart,
            layout: `protocol`.layout,
            rules: `protocol`.rules
        )
        
        service.updateProtocol(updatedProtocol)
        
        let found = service.protocols.first(where: { $0.id == updatedProtocol.id })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Updated Name")
    }
}
