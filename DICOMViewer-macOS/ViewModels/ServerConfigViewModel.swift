//
//  ServerConfigViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftData

/// ViewModel for managing PACS server configurations
@MainActor
@Observable
final class ServerConfigViewModel {
    // MARK: - State

    /// List of configured PACS servers
    private(set) var servers: [PACSServer] = []

    /// Currently selected server ID
    var selectedServerID: UUID?

    /// Loading state
    private(set) var isLoading = false

    /// Error message
    var errorMessage: String?

    /// Whether the add server sheet is showing
    var showingAddSheet = false

    /// Result of the last connection test
    var testResult: ConnectionTestResult?

    // MARK: - Edit Form Fields

    var editName = ""
    var editHost = ""
    var editPort = "104"
    var editCalledAE = ""
    var editCallingAE = "DICOMVIEWER"
    var editServerType = "dicom"
    var editUseTLS = false
    var editWebBaseURL = ""
    var editUsername = ""
    var editNotes = ""

    // MARK: - Types

    /// Result of testing a PACS server connection
    struct ConnectionTestResult {
        let success: Bool
        let message: String
        let responseTime: TimeInterval?
    }

    // MARK: - Services

    private let databaseService = DatabaseService.shared

    // MARK: - Public Methods

    /// Load all servers from database
    func loadServers() {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<PACSServer>(
                sortBy: [SortDescriptor(\.name)]
            )
            servers = try databaseService.modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load servers: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Add a new server from the current form fields
    func addServer() {
        guard !editName.isEmpty, !editHost.isEmpty, !editCalledAE.isEmpty else {
            errorMessage = "Name, host, and called AE title are required"
            return
        }

        guard let port = Int(editPort), port > 0, port <= 65535 else {
            errorMessage = "Port must be a number between 1 and 65535"
            return
        }

        let server = PACSServer(
            name: editName,
            host: editHost,
            port: port,
            calledAETitle: editCalledAE,
            callingAETitle: editCallingAE,
            serverType: editServerType,
            useTLS: editUseTLS,
            webBaseURL: editWebBaseURL.isEmpty ? nil : editWebBaseURL,
            username: editUsername.isEmpty ? nil : editUsername,
            notes: editNotes.isEmpty ? nil : editNotes
        )

        do {
            databaseService.modelContext.insert(server)
            try databaseService.modelContext.save()
            resetForm()
            showingAddSheet = false
            loadServers()
        } catch {
            errorMessage = "Failed to add server: \(error.localizedDescription)"
        }
    }

    /// Delete a server
    func deleteServer(_ server: PACSServer) {
        do {
            databaseService.modelContext.delete(server)
            try databaseService.modelContext.save()
            if selectedServerID == server.id {
                selectedServerID = nil
            }
            loadServers()
        } catch {
            errorMessage = "Failed to delete server: \(error.localizedDescription)"
        }
    }

    /// Update a server with current form field values
    func updateServer(_ server: PACSServer) {
        guard !editName.isEmpty, !editHost.isEmpty, !editCalledAE.isEmpty else {
            errorMessage = "Name, host, and called AE title are required"
            return
        }

        guard let port = Int(editPort), port > 0, port <= 65535 else {
            errorMessage = "Port must be a number between 1 and 65535"
            return
        }

        server.name = editName
        server.host = editHost
        server.port = port
        server.calledAETitle = editCalledAE
        server.callingAETitle = editCallingAE
        server.serverType = editServerType
        server.useTLS = editUseTLS
        server.webBaseURL = editWebBaseURL.isEmpty ? nil : editWebBaseURL
        server.username = editUsername.isEmpty ? nil : editUsername
        server.notes = editNotes.isEmpty ? nil : editNotes

        do {
            try databaseService.modelContext.save()
            loadServers()
        } catch {
            errorMessage = "Failed to update server: \(error.localizedDescription)"
        }
    }

    /// Test connection to a PACS server
    func testConnection(for server: PACSServer) async {
        isLoading = true
        testResult = nil

        let service = PACSService(server: server)
        let startTime = Date()

        do {
            let success = try await service.testConnection()
            let elapsed = Date().timeIntervalSince(startTime)

            if success {
                server.isOnline = true
                server.lastConnected = Date()
                try? databaseService.modelContext.save()
                testResult = ConnectionTestResult(
                    success: true,
                    message: "Connection successful",
                    responseTime: elapsed
                )
            } else {
                server.isOnline = false
                try? databaseService.modelContext.save()
                testResult = ConnectionTestResult(
                    success: false,
                    message: "Server did not respond to C-ECHO",
                    responseTime: elapsed
                )
            }
        } catch {
            server.isOnline = false
            try? databaseService.modelContext.save()
            testResult = ConnectionTestResult(
                success: false,
                message: "Connection failed: \(error.localizedDescription)",
                responseTime: nil
            )
        }

        isLoading = false
    }

    /// Set a server as the default
    func setDefault(_ server: PACSServer) {
        do {
            // Clear existing defaults
            for s in servers {
                s.isDefault = false
            }
            server.isDefault = true
            try databaseService.modelContext.save()
            loadServers()
        } catch {
            errorMessage = "Failed to set default server: \(error.localizedDescription)"
        }
    }

    /// Populate form fields from an existing server for editing
    func populateForm(from server: PACSServer) {
        editName = server.name
        editHost = server.host
        editPort = String(server.port)
        editCalledAE = server.calledAETitle
        editCallingAE = server.callingAETitle
        editServerType = server.serverType
        editUseTLS = server.useTLS
        editWebBaseURL = server.webBaseURL ?? ""
        editUsername = server.username ?? ""
        editNotes = server.notes ?? ""
    }

    /// Reset form fields to default values
    func resetForm() {
        editName = ""
        editHost = ""
        editPort = "104"
        editCalledAE = ""
        editCallingAE = "DICOMVIEWER"
        editServerType = "dicom"
        editUseTLS = false
        editWebBaseURL = ""
        editUsername = ""
        editNotes = ""
    }
}
