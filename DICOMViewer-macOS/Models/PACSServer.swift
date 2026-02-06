//
//  PACSServer.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftData

/// Represents a PACS server configuration in the local database
@Model
final class PACSServer {
    /// Unique server identifier
    @Attribute(.unique) var id: UUID
    
    /// Display name for the server
    var name: String
    
    /// Server hostname or IP address
    var host: String
    
    /// Server port (default 104 for DICOM, 8080 for DICOMweb)
    var port: Int
    
    /// Remote AE title
    var calledAETitle: String
    
    /// Local AE title
    var callingAETitle: String
    
    /// Server type: "dicom", "dicomweb", or "both"
    var serverType: String
    
    /// Whether this is the default server
    var isDefault: Bool
    
    /// Whether to use TLS encryption
    var useTLS: Bool
    
    /// Base URL for DICOMweb (e.g., "https://server/wado-rs")
    var webBaseURL: String?
    
    /// Optional authentication username
    var username: String?
    
    /// Last successful connection time
    var lastConnected: Date?
    
    /// Last known connection status
    var isOnline: Bool
    
    /// User notes
    var notes: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 104,
        calledAETitle: String,
        callingAETitle: String = "DICOMVIEWER",
        serverType: String = "dicom",
        isDefault: Bool = false,
        useTLS: Bool = false,
        webBaseURL: String? = nil,
        username: String? = nil,
        lastConnected: Date? = nil,
        isOnline: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.calledAETitle = calledAETitle
        self.callingAETitle = callingAETitle
        self.serverType = serverType
        self.isDefault = isDefault
        self.useTLS = useTLS
        self.webBaseURL = webBaseURL
        self.username = username
        self.lastConnected = lastConnected
        self.isOnline = isOnline
        self.notes = notes
    }
    
    /// Formatted display info (e.g., "192.168.1.1:104 (PACS_AET)")
    var displayInfo: String {
        "\(host):\(port) (\(calledAETitle))"
    }
    
    /// Formatted DICOM URL (e.g., "dicom://192.168.1.1:104")
    var dicomURL: String {
        "dicom://\(host):\(port)"
    }
}

extension PACSServer: Identifiable {}
