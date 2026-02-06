//
//  ServerConfigurationView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Settings view for managing PACS server configurations
struct ServerConfigurationView: View {
    @State private var viewModel = ServerConfigViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HSplitView {
            // Server list
            VStack(spacing: 0) {
                List(viewModel.servers, selection: $viewModel.selectedServerID) { server in
                    ServerRow(server: server, isDefault: server.isDefault)
                }
                .listStyle(.bordered)

                Divider()

                HStack {
                    Button(action: { viewModel.resetForm(); viewModel.showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .help("Add Server")

                    Button(action: deleteSelected) {
                        Image(systemName: "minus")
                    }
                    .disabled(viewModel.selectedServerID == nil)
                    .help("Delete Server")

                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 200, maxWidth: 300)

            // Edit form
            if let serverID = viewModel.selectedServerID,
               let server = viewModel.servers.first(where: { $0.id == serverID }) {
                ServerEditForm(viewModel: viewModel, server: server)
            } else {
                ContentUnavailableView(
                    "No Server Selected",
                    systemImage: "server.rack",
                    description: Text("Select a server to edit its configuration")
                )
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear { viewModel.loadServers() }
        .onChange(of: viewModel.selectedServerID) { _, newValue in
            if let newValue,
               let server = viewModel.servers.first(where: { $0.id == newValue }) {
                viewModel.populateForm(from: server)
                viewModel.testResult = nil
            }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddServerSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private func deleteSelected() {
        guard let serverID = viewModel.selectedServerID,
              let server = viewModel.servers.first(where: { $0.id == serverID }) else {
            return
        }
        viewModel.deleteServer(server)
    }
}

// MARK: - Server Row

/// Row view for a PACS server in the server list
struct ServerRow: View {
    let server: PACSServer
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(server.isOnline ? .green : .gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(server.name)
                        .font(.headline)
                    if isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(server.displayInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Server Edit Form

/// Form for editing an existing server's configuration
struct ServerEditForm: View {
    @Bindable var viewModel: ServerConfigViewModel
    let server: PACSServer

    var body: some View {
        ScrollView {
            Form {
                Section("General") {
                    TextField("Name", text: $viewModel.editName)
                    Toggle("Default Server", isOn: Binding(
                        get: { server.isDefault },
                        set: { newValue in
                            if newValue { viewModel.setDefault(server) }
                        }
                    ))
                }

                Section("Connection") {
                    TextField("Host", text: $viewModel.editHost)
                    TextField("Port", text: $viewModel.editPort)
                    Picker("Type", selection: $viewModel.editServerType) {
                        Text("DICOM").tag("dicom")
                        Text("DICOMweb").tag("dicomweb")
                        Text("Both").tag("both")
                    }
                    Toggle("Use TLS", isOn: $viewModel.editUseTLS)
                }

                Section("AE Titles") {
                    TextField("Called AE Title", text: $viewModel.editCalledAE)
                    TextField("Calling AE Title", text: $viewModel.editCallingAE)
                }

                if viewModel.editServerType == "dicomweb" || viewModel.editServerType == "both" {
                    Section("DICOMweb") {
                        TextField("Base URL", text: $viewModel.editWebBaseURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Username", text: $viewModel.editUsername)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $viewModel.editNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Button("Save Changes") {
                            viewModel.updateServer(server)
                        }
                        .keyboardShortcut(.defaultAction)

                        Button("Test Connection") {
                            Task { await viewModel.testConnection(for: server) }
                        }
                        .disabled(viewModel.isLoading)
                    }

                    if viewModel.isLoading {
                        ProgressView("Testing connection…")
                    }

                    if let result = viewModel.testResult {
                        TestResultBanner(result: result)
                    }
                }

                if let lastConnected = server.lastConnected {
                    Section("Status") {
                        LabeledContent("Last Connected") {
                            Text(lastConnected, style: .relative)
                        }
                        LabeledContent("Status") {
                            Text(server.isOnline ? "Online" : "Offline")
                                .foregroundStyle(server.isOnline ? .green : .secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
    }
}

// MARK: - Test Result Banner

/// Displays the result of a PACS connection test
struct TestResultBanner: View {
    let result: ServerConfigViewModel.ConnectionTestResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.success ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.message)
                    .font(.callout)

                if let responseTime = result.responseTime {
                    Text(String(format: "Response time: %.0f ms", responseTime * 1000))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Add Server Sheet

/// Sheet for adding a new PACS server configuration
struct AddServerSheet: View {
    @Bindable var viewModel: ServerConfigViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Add PACS Server")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                Form {
                    Section("General") {
                        TextField("Name", text: $viewModel.editName)
                    }

                    Section("Connection") {
                        TextField("Host", text: $viewModel.editHost)
                        TextField("Port", text: $viewModel.editPort)
                        Picker("Type", selection: $viewModel.editServerType) {
                            Text("DICOM").tag("dicom")
                            Text("DICOMweb").tag("dicomweb")
                            Text("Both").tag("both")
                        }
                        Toggle("Use TLS", isOn: $viewModel.editUseTLS)
                    }

                    Section("AE Titles") {
                        TextField("Called AE Title", text: $viewModel.editCalledAE)
                        TextField("Calling AE Title", text: $viewModel.editCallingAE)
                    }

                    if viewModel.editServerType == "dicomweb" || viewModel.editServerType == "both" {
                        Section("DICOMweb") {
                            TextField("Base URL", text: $viewModel.editWebBaseURL)
                            TextField("Username", text: $viewModel.editUsername)
                        }
                    }

                    Section("Notes") {
                        TextField("Notes", text: $viewModel.editNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                .formStyle(.grouped)
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") {
                    viewModel.resetForm()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Server") {
                    viewModel.addServer()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.editName.isEmpty || viewModel.editHost.isEmpty || viewModel.editCalledAE.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
    }
}

#Preview("Server Configuration") {
    ServerConfigurationView()
}
