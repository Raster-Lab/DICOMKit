//
//  PACSQueryView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// View for querying PACS servers using C-FIND
struct PACSQueryView: View {
    @State private var viewModel = PACSQueryViewModel()
    @State private var servers: [PACSServer] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            queryFormSection

            Divider()

            resultsSection

            Divider()

            actionBar
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear { loadServers() }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Query Form

    private var queryFormSection: some View {
        VStack(spacing: 12) {
            // Server picker row
            HStack {
                Label("Server", systemImage: "server.rack")
                    .font(.headline)

                Picker("", selection: $viewModel.selectedServer) {
                    Text("Select a server…").tag(PACSServer?.none)
                    ForEach(servers) { server in
                        Text("\(server.name) — \(server.displayInfo)")
                            .tag(PACSServer?.some(server))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 400)
                .help("Select a PACS server to query")
                .accessibilityLabel("PACS server selection")
            }

            // Query fields
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Patient Name:")
                        .gridColumnAlignment(.trailing)
                    TextField("e.g. SMITH*", text: $viewModel.patientName)
                        .textFieldStyle(.roundedBorder)
                        .help("Enter patient name (wildcards * and ? supported)")
                        .accessibilityLabel("Patient name search field")

                    Text("Patient ID:")
                        .gridColumnAlignment(.trailing)
                    TextField("e.g. 12345", text: $viewModel.patientID)
                        .textFieldStyle(.roundedBorder)
                        .help("Enter patient ID (exact match or wildcard)")
                        .accessibilityLabel("Patient ID search field")
                }

                GridRow {
                    Text("Study Date:")
                    TextField("YYYYMMDD or range", text: $viewModel.studyDate)
                        .textFieldStyle(.roundedBorder)
                        .help("Enter study date as YYYYMMDD or date range YYYYMMDD-YYYYMMDD")
                        .accessibilityLabel("Study date search field")

                    Text("Modality:")
                    TextField("e.g. CT, MR", text: $viewModel.modality)
                        .textFieldStyle(.roundedBorder)
                        .help("Enter modality (CT, MR, US, CR, DX, etc.)")
                        .accessibilityLabel("Modality search field")
                }

                GridRow {
                    Text("Accession #:")
                    TextField("Accession number", text: $viewModel.accessionNumber)
                        .textFieldStyle(.roundedBorder)
                        .help("Enter accession number for the study")
                        .accessibilityLabel("Accession number search field")

                    // Search and clear buttons
                    HStack(spacing: 8) {
                        Spacer()

                        Button("Clear") {
                            viewModel.clearResults()
                            viewModel.patientName = ""
                            viewModel.patientID = ""
                            viewModel.studyDate = ""
                            viewModel.modality = ""
                            viewModel.accessionNumber = ""
                        }
                        .help("Clear all search criteria and results")
                        .accessibilityLabel("Clear search")

                        Button("Search") {
                            Task { await viewModel.executeQuery() }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(viewModel.selectedServer == nil || viewModel.isQuerying)
                        .help("Execute PACS query with current search criteria")
                        .accessibilityLabel("Search PACS")
                        .accessibilityHint("Queries the selected PACS server for studies matching the criteria")
                    }
                    .gridCellColumns(2)
                }
            }
        }
        .padding()
    }

    // MARK: - Results Table

    private var resultsSection: some View {
        Group {
            if viewModel.isQuerying {
                VStack {
                    Spacer()
                    ProgressView("Querying PACS server…")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.studyResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Enter search criteria and click Search to query the PACS server")
                )
            } else {
                Table(viewModel.studyResults, selection: $viewModel.selectedStudyUIDs) {
                    TableColumn("Patient Name", value: \.patientName)
                        .width(min: 120, ideal: 160)

                    TableColumn("Patient ID", value: \.patientID)
                        .width(min: 80, ideal: 100)

                    TableColumn("Study Date", value: \.studyDate)
                        .width(min: 80, ideal: 100)

                    TableColumn("Modality", value: \.modality)
                        .width(min: 50, ideal: 70)

                    TableColumn("Description", value: \.studyDescription)
                        .width(min: 120, ideal: 200)

                    TableColumn("Accession #", value: \.accessionNumber)
                        .width(min: 80, ideal: 100)

                    TableColumn("Series") { item in
                        Text("\(item.numberOfSeries)")
                            .monospacedDigit()
                    }
                    .width(min: 40, ideal: 60)
                }
                .accessibilityLabel("Query results table")
                .accessibilityHint("Select studies to retrieve from PACS")
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            if !viewModel.studyResults.isEmpty {
                Text("\(viewModel.studyResults.count) studies found")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !viewModel.selectedStudyUIDs.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.selectedStudyUIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Retrieve Selected") {
                Task {
                    let callingAE = viewModel.selectedServer?.callingAETitle ?? "DICOMVIEWER"
                    await viewModel.retrieveSelected(destinationAE: callingAE)
                }
            }
            .disabled(viewModel.selectedStudyUIDs.isEmpty || viewModel.selectedServer == nil)
            .help("Retrieve selected studies from PACS server using C-MOVE")
            .accessibilityLabel("Retrieve selected studies")
            .accessibilityHint("Downloads the selected studies from the PACS server")

            Button("Close") { dismiss() }
                .help("Close PACS query window")
                .accessibilityLabel("Close")
        }
        .padding()
    }

    // MARK: - Private Methods

    private func loadServers() {
        let configVM = ServerConfigViewModel()
        configVM.loadServers()
        servers = configVM.servers

        // Auto-select default server
        if viewModel.selectedServer == nil {
            viewModel.selectedServer = servers.first(where: { $0.isDefault }) ?? servers.first
        }
    }
}

#Preview("PACS Query") {
    PACSQueryView()
}
