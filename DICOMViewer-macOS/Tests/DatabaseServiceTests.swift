//
//  DatabaseServiceTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
import SwiftData
@testable import DICOMViewer

@MainActor
final class DatabaseServiceTests: XCTestCase {
    var databaseService: DatabaseService!
    
    override func setUp() async throws {
        databaseService = DatabaseService.shared
        try databaseService.clearAllData() // Start with clean database for each test
    }
    
    override func tearDown() async throws {
        try databaseService.clearAllData()
    }
    
    func testCreateAndFetchStudy() throws {
        // Create a test study
        let study = DicomStudy(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "Doe^John",
            patientID: "12345",
            studyDescription: "Test Study",
            modalities: "CT,MR"
        )
        
        // Save to database
        try databaseService.saveStudy(study)
        
        // Fetch back
        let fetchedStudy = try databaseService.fetchStudy(uid: "1.2.3.4.5")
        
        // Verify
        XCTAssertNotNil(fetchedStudy)
        XCTAssertEqual(fetchedStudy?.patientName, "Doe^John")
        XCTAssertEqual(fetchedStudy?.patientID, "12345")
        XCTAssertEqual(fetchedStudy?.studyDescription, "Test Study")
    }
    
    func testSearchStudiesByPatientName() throws {
        // Create test studies
        let study1 = DicomStudy(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "Doe^John",
            patientID: "12345"
        )
        
        let study2 = DicomStudy(
            studyInstanceUID: "1.2.3.4.6",
            patientName: "Smith^Jane",
            patientID: "67890"
        )
        
        try databaseService.saveStudy(study1)
        try databaseService.saveStudy(study2)
        
        // Search for "Doe"
        let results = try databaseService.searchStudies(query: "Doe")
        
        // Verify
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.patientName, "Doe^John")
    }
    
    func testFilterStudiesByModality() throws {
        // Create test studies with different modalities
        let ctStudy = DicomStudy(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "Patient1",
            patientID: "001",
            modalities: "CT"
        )
        
        let mrStudy = DicomStudy(
            studyInstanceUID: "1.2.3.4.6",
            patientName: "Patient2",
            patientID: "002",
            modalities: "MR"
        )
        
        try databaseService.saveStudy(ctStudy)
        try databaseService.saveStudy(mrStudy)
        
        // Filter by CT
        let ctResults = try databaseService.filterStudies(byModality: "CT")
        
        // Verify
        XCTAssertEqual(ctResults.count, 1)
        XCTAssertEqual(ctResults.first?.modalities, "CT")
    }
    
    func testDeleteStudy() throws {
        // Create and save a study
        let study = DicomStudy(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "Test Patient",
            patientID: "12345"
        )
        
        try databaseService.saveStudy(study)
        
        // Verify it exists
        var fetchedStudy = try databaseService.fetchStudy(uid: "1.2.3.4.5")
        XCTAssertNotNil(fetchedStudy)
        
        // Delete it
        try databaseService.deleteStudy(study)
        
        // Verify it's gone
        fetchedStudy = try databaseService.fetchStudy(uid: "1.2.3.4.5")
        XCTAssertNil(fetchedStudy)
    }
    
    func testGetTotalStudyCount() throws {
        // Initially should be 0
        var count = try databaseService.getTotalStudyCount()
        XCTAssertEqual(count, 0)
        
        // Add studies
        let study1 = DicomStudy(studyInstanceUID: "1.2.3.4.5", patientName: "Patient1", patientID: "001")
        let study2 = DicomStudy(studyInstanceUID: "1.2.3.4.6", patientName: "Patient2", patientID: "002")
        
        try databaseService.saveStudy(study1)
        try databaseService.saveStudy(study2)
        
        // Should now be 2
        count = try databaseService.getTotalStudyCount()
        XCTAssertEqual(count, 2)
    }
    
    func testStudyModalityList() {
        let study = DicomStudy(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "Test",
            patientID: "123",
            modalities: "CT,MR,US"
        )
        
        let modalityList = study.modalityList
        
        XCTAssertEqual(modalityList.count, 3)
        XCTAssertTrue(modalityList.contains("CT"))
        XCTAssertTrue(modalityList.contains("MR"))
        XCTAssertTrue(modalityList.contains("US"))
    }
    
    func testStudyFormattedSize() {
        let study = DicomStudy(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "Test",
            patientID: "123",
            studySize: 1024 * 1024 * 100 // 100 MB
        )
        
        let formatted = study.formattedSize
        
        // Should contain "MB"
        XCTAssertTrue(formatted.contains("MB"))
    }
}
