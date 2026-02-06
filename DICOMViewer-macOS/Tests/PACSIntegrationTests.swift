//
//  PACSIntegrationTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
import SwiftData
@testable import DICOMViewer

/// Integration tests for PACS-related workflows
@MainActor
final class PACSIntegrationTests: XCTestCase {
    var databaseService: DatabaseService!
    
    override func setUp() async throws {
        databaseService = DatabaseService.shared
        try databaseService.clearAllData()
    }
    
    override func tearDown() async throws {
        try databaseService.clearAllData()
    }
    
    // MARK: - Server Configuration Tests
    
    func testServerConfigurationWorkflow() throws {
        // Create a new PACS server
        let server = PACSServer(
            name: "Test PACS",
            host: "pacs.example.com",
            port: 11112,
            callingAE: "VIEWER",
            calledAE: "PACS",
            retrieveAE: "VIEWER"
        )
        
        // Save server
        try databaseService.savePACSServer(server)
        
        // Fetch all servers
        let servers = try databaseService.fetchAllPACSServers()
        XCTAssertEqual(servers.count, 1, "Should have one server")
        XCTAssertEqual(servers[0].name, "Test PACS")
        XCTAssertEqual(servers[0].host, "pacs.example.com")
        XCTAssertEqual(servers[0].port, 11112)
        
        // Update server
        var updatedServer = servers[0]
        updatedServer.name = "Updated PACS"
        updatedServer.port = 11113
        try databaseService.savePACSServer(updatedServer)
        
        let fetchedServer = try databaseService.fetchPACSServer(id: updatedServer.id)
        XCTAssertNotNil(fetchedServer)
        XCTAssertEqual(fetchedServer?.name, "Updated PACS")
        XCTAssertEqual(fetchedServer?.port, 11113)
        
        // Delete server
        try databaseService.deletePACSServer(updatedServer)
        let remainingServers = try databaseService.fetchAllPACSServers()
        XCTAssertEqual(remainingServers.count, 0, "Should have no servers after deletion")
        
        print("✅ Server configuration workflow completed successfully")
    }
    
    func testMultipleServerManagement() throws {
        // Add multiple servers
        let server1 = PACSServer(
            name: "PACS 1",
            host: "pacs1.example.com",
            port: 11112,
            callingAE: "VIEWER1",
            calledAE: "PACS1"
        )
        
        let server2 = PACSServer(
            name: "PACS 2",
            host: "pacs2.example.com",
            port: 11113,
            callingAE: "VIEWER2",
            calledAE: "PACS2"
        )
        
        let server3 = PACSServer(
            name: "PACS 3",
            host: "pacs3.example.com",
            port: 11114,
            callingAE: "VIEWER3",
            calledAE: "PACS3"
        )
        
        try databaseService.savePACSServer(server1)
        try databaseService.savePACSServer(server2)
        try databaseService.savePACSServer(server3)
        
        // Verify all servers were saved
        let servers = try databaseService.fetchAllPACSServers()
        XCTAssertEqual(servers.count, 3, "Should have three servers")
        
        // Verify unique names
        let names = Set(servers.map { $0.name })
        XCTAssertEqual(names.count, 3, "All server names should be unique")
        
        // Delete one server
        try databaseService.deletePACSServer(server2)
        let remainingServers = try databaseService.fetchAllPACSServers()
        XCTAssertEqual(remainingServers.count, 2, "Should have two servers after deletion")
        XCTAssertFalse(remainingServers.contains { $0.name == "PACS 2" }, "PACS 2 should be deleted")
        
        print("✅ Multiple server management workflow completed successfully")
    }
    
    // MARK: - Download Queue Tests
    
    func testDownloadQueueWorkflow() async throws {
        let downloadManager = DownloadManager()
        
        // Add downloads to queue
        await downloadManager.addDownload(
            studyUID: "1.2.3.4.5",
            seriesUID: "1.2.3.4.5.1",
            description: "CT Chest"
        )
        
        await downloadManager.addDownload(
            studyUID: "1.2.3.4.6",
            seriesUID: "1.2.3.4.6.1",
            description: "MR Brain"
        )
        
        // Check queue status
        let queueStatus = await downloadManager.getQueueStatus()
        XCTAssertEqual(queueStatus.totalCount, 2, "Should have two downloads in queue")
        XCTAssertEqual(queueStatus.pendingCount, 2, "Both should be pending")
        XCTAssertEqual(queueStatus.activeCount, 0, "None should be active yet")
        
        // Get all downloads
        let downloads = await downloadManager.getAllDownloads()
        XCTAssertEqual(downloads.count, 2, "Should have two downloads")
        
        // Find specific download
        let ctDownload = downloads.first { $0.studyUID == "1.2.3.4.5" }
        XCTAssertNotNil(ctDownload, "CT download should exist")
        XCTAssertEqual(ctDownload?.description, "CT Chest")
        
        // Cancel a download
        if let downloadID = ctDownload?.id {
            await downloadManager.cancelDownload(id: downloadID)
            let updatedDownloads = await downloadManager.getAllDownloads()
            XCTAssertEqual(updatedDownloads.count, 1, "Should have one download after cancellation")
        }
        
        // Clear completed downloads
        await downloadManager.clearCompletedDownloads()
        
        print("✅ Download queue workflow completed successfully")
    }
    
    func testDownloadProgressTracking() async throws {
        let downloadManager = DownloadManager()
        
        // Add a download
        await downloadManager.addDownload(
            studyUID: "1.2.3.4.7",
            seriesUID: "1.2.3.4.7.1",
            description: "Test Download"
        )
        
        let downloads = await downloadManager.getAllDownloads()
        guard let download = downloads.first else {
            XCTFail("Download should exist")
            return
        }
        
        // Initially should be pending
        XCTAssertEqual(download.status, .pending, "Should start as pending")
        XCTAssertEqual(download.progress, 0.0, "Progress should start at 0")
        
        // Simulate progress updates
        await downloadManager.updateProgress(id: download.id, progress: 0.25)
        var updated = await downloadManager.getDownload(id: download.id)
        XCTAssertEqual(updated?.progress, 0.25, "Progress should be 25%")
        
        await downloadManager.updateProgress(id: download.id, progress: 0.75)
        updated = await downloadManager.getDownload(id: download.id)
        XCTAssertEqual(updated?.progress, 0.75, "Progress should be 75%")
        
        // Mark as completed
        await downloadManager.completeDownload(id: download.id)
        updated = await downloadManager.getDownload(id: download.id)
        XCTAssertEqual(updated?.status, .completed, "Should be marked as completed")
        XCTAssertEqual(updated?.progress, 1.0, "Progress should be 100%")
        
        print("✅ Download progress tracking workflow completed successfully")
    }
    
    func testDownloadErrorHandling() async throws {
        let downloadManager = DownloadManager()
        
        // Add a download
        await downloadManager.addDownload(
            studyUID: "1.2.3.4.8",
            seriesUID: "1.2.3.4.8.1",
            description: "Failed Download"
        )
        
        let downloads = await downloadManager.getAllDownloads()
        guard let download = downloads.first else {
            XCTFail("Download should exist")
            return
        }
        
        // Simulate error
        let errorMessage = "Connection timeout"
        await downloadManager.failDownload(id: download.id, error: errorMessage)
        
        let updated = await downloadManager.getDownload(id: download.id)
        XCTAssertEqual(updated?.status, .failed, "Should be marked as failed")
        XCTAssertEqual(updated?.errorMessage, errorMessage, "Should store error message")
        
        print("✅ Download error handling workflow completed successfully")
    }
    
    // MARK: - Server Configuration Validation
    
    func testServerConfigurationValidation() throws {
        // Test valid configuration
        let validServer = PACSServer(
            name: "Valid PACS",
            host: "pacs.example.com",
            port: 11112,
            callingAE: "VIEWER",
            calledAE: "PACS"
        )
        
        XCTAssertTrue(validServer.isValid, "Valid server should pass validation")
        XCTAssertEqual(validServer.connectionString, "VIEWER@pacs.example.com:11112 → PACS")
        
        // Test invalid port (too low)
        let invalidPortLow = PACSServer(
            name: "Invalid Port Low",
            host: "pacs.example.com",
            port: 0,
            callingAE: "VIEWER",
            calledAE: "PACS"
        )
        XCTAssertFalse(invalidPortLow.isValid, "Port 0 should be invalid")
        
        // Test invalid port (too high)
        let invalidPortHigh = PACSServer(
            name: "Invalid Port High",
            host: "pacs.example.com",
            port: 70000,
            callingAE: "VIEWER",
            calledAE: "PACS"
        )
        XCTAssertFalse(invalidPortHigh.isValid, "Port 70000 should be invalid")
        
        // Test empty host
        let emptyHost = PACSServer(
            name: "Empty Host",
            host: "",
            port: 11112,
            callingAE: "VIEWER",
            calledAE: "PACS"
        )
        XCTAssertFalse(emptyHost.isValid, "Empty host should be invalid")
        
        // Test empty AE titles
        let emptyAE = PACSServer(
            name: "Empty AE",
            host: "pacs.example.com",
            port: 11112,
            callingAE: "",
            calledAE: ""
        )
        XCTAssertFalse(emptyAE.isValid, "Empty AE titles should be invalid")
        
        print("✅ Server configuration validation completed successfully")
    }
    
    // MARK: - DICOMWeb Configuration Tests
    
    func testDICOMWebServerConfiguration() throws {
        // Create DICOMWeb server
        let server = PACSServer(
            name: "DICOMWeb Server",
            host: "dicomweb.example.com",
            port: 443,
            callingAE: "VIEWER",
            calledAE: "DICOMWEB",
            protocol: .dicomweb,
            baseURL: "https://dicomweb.example.com/dicomweb"
        )
        
        // Save and verify
        try databaseService.savePACSServer(server)
        
        let fetched = try databaseService.fetchPACSServer(id: server.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.protocol, .dicomweb)
        XCTAssertEqual(fetched?.baseURL, "https://dicomweb.example.com/dicomweb")
        XCTAssertEqual(fetched?.port, 443)
        
        print("✅ DICOMWeb server configuration completed successfully")
    }
    
    // MARK: - Server Protocol Switching
    
    func testProtocolSwitching() throws {
        // Start with DIMSE
        var server = PACSServer(
            name: "Flexible Server",
            host: "pacs.example.com",
            port: 11112,
            callingAE: "VIEWER",
            calledAE: "PACS",
            protocol: .dimse
        )
        
        try databaseService.savePACSServer(server)
        
        // Switch to DICOMWeb
        server.protocol = .dicomweb
        server.port = 443
        server.baseURL = "https://pacs.example.com/dicomweb"
        
        try databaseService.savePACSServer(server)
        
        let updated = try databaseService.fetchPACSServer(id: server.id)
        XCTAssertEqual(updated?.protocol, .dicomweb)
        XCTAssertEqual(updated?.port, 443)
        XCTAssertEqual(updated?.baseURL, "https://pacs.example.com/dicomweb")
        
        print("✅ Protocol switching workflow completed successfully")
    }
}
