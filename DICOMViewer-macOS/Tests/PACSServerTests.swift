//
//  PACSServerTests.swift
//  DICOMViewer macOS Tests
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import XCTest
import SwiftData
@testable import DICOMViewer

@MainActor
final class PACSServerTests: XCTestCase {
    
    func testPACSServerInitialization() {
        let server = PACSServer(
            name: "Test PACS",
            host: "pacs.hospital.com",
            port: 104,
            calledAETitle: "PACS_SCP",
            callingAETitle: "DICOMVIEWER"
        )
        
        XCTAssertEqual(server.name, "Test PACS")
        XCTAssertEqual(server.host, "pacs.hospital.com")
        XCTAssertEqual(server.port, 104)
        XCTAssertEqual(server.calledAETitle, "PACS_SCP")
        XCTAssertEqual(server.callingAETitle, "DICOMVIEWER")
        XCTAssertEqual(server.serverType, "dicom")
        XCTAssertFalse(server.isDefault)
        XCTAssertFalse(server.useTLS)
        XCTAssertNil(server.webBaseURL)
        XCTAssertNil(server.username)
        XCTAssertNil(server.lastConnected)
        XCTAssertFalse(server.isOnline)
    }
    
    func testPACSServerDefaultValues() {
        let server = PACSServer(
            name: "Minimal Server",
            host: "localhost",
            port: 11112,
            calledAETitle: "SCP",
            callingAETitle: "SCU"
        )
        
        XCTAssertEqual(server.serverType, "dicom")
        XCTAssertFalse(server.isDefault)
        XCTAssertFalse(server.useTLS)
    }
    
    func testPACSServerDisplayInfo() {
        let server = PACSServer(
            name: "Test",
            host: "10.0.0.1",
            port: 104,
            calledAETitle: "MYPACS",
            callingAETitle: "SCU"
        )
        
        XCTAssertEqual(server.displayInfo, "10.0.0.1:104 (MYPACS)")
    }
    
    func testPACSServerDicomURL() {
        let server = PACSServer(
            name: "Test",
            host: "pacs.example.com",
            port: 11112,
            calledAETitle: "SCP",
            callingAETitle: "SCU"
        )
        
        XCTAssertEqual(server.dicomURL, "dicom://pacs.example.com:11112")
    }
    
    func testPACSServerDICOMwebConfiguration() {
        let server = PACSServer(
            name: "Web PACS",
            host: "web.hospital.com",
            port: 8080,
            calledAETitle: "WEB_SCP",
            callingAETitle: "VIEWER",
            serverType: "dicomweb",
            webBaseURL: "https://web.hospital.com/wado-rs"
        )
        
        XCTAssertEqual(server.serverType, "dicomweb")
        XCTAssertEqual(server.webBaseURL, "https://web.hospital.com/wado-rs")
    }
    
    func testPACSServerTLSConfiguration() {
        let server = PACSServer(
            name: "Secure PACS",
            host: "secure.hospital.com",
            port: 2762,
            calledAETitle: "SECURE_SCP",
            callingAETitle: "VIEWER",
            useTLS: true
        )
        
        XCTAssertTrue(server.useTLS)
    }
    
    func testPACSServerWithAllParameters() {
        let server = PACSServer(
            name: "Full Config PACS",
            host: "full.hospital.com",
            port: 104,
            calledAETitle: "FULL_SCP",
            callingAETitle: "FULL_SCU",
            serverType: "both",
            isDefault: true,
            useTLS: true,
            webBaseURL: "https://full.hospital.com/dicomweb",
            username: "admin",
            notes: "Production server"
        )
        
        XCTAssertEqual(server.name, "Full Config PACS")
        XCTAssertEqual(server.serverType, "both")
        XCTAssertTrue(server.isDefault)
        XCTAssertTrue(server.useTLS)
        XCTAssertEqual(server.webBaseURL, "https://full.hospital.com/dicomweb")
        XCTAssertEqual(server.username, "admin")
        XCTAssertEqual(server.notes, "Production server")
    }
    
    func testPACSServerIdentifiable() {
        let server1 = PACSServer(name: "S1", host: "h1", port: 104, calledAETitle: "AE1", callingAETitle: "AE2")
        let server2 = PACSServer(name: "S2", host: "h2", port: 104, calledAETitle: "AE1", callingAETitle: "AE2")
        
        XCTAssertNotEqual(server1.id, server2.id)
    }
}
