// ContentView.swift
// DICOMViewer visionOS - Root Content View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData

/// Root content view for visionOS app
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @Query(sort: \DICOMStudy.importDate, order: .reverse)
    private var studies: [DICOMStudy]
    
    @State private var selectedStudy: DICOMStudy?
    @State private var isImmersiveSpaceOpen = false
    @State private var showImportDialog = false
    
    var body: some View {
        NavigationSplitView {
            // Study list
            List(selection: $selectedStudy) {
                ForEach(studies) { study in
                    StudyRow(study: study)
                        .tag(study)
                }
            }
            .navigationTitle("DICOM Studies")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showImportDialog = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
        } detail: {
            if let study = selectedStudy {
                StudyDetailView(study: study)
            } else {
                ContentUnavailableView(
                    "No Study Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Select a study from the list to view details")
                )
            }
        }
        .fileImporter(
            isPresented: $showImportDialog,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        // Placeholder implementation
        switch result {
        case .success(let urls):
            print("Imported files: \(urls)")
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

struct StudyRow: View {
    let study: DICOMStudy
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text.image")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(study.displayName)
                    .font(.headline)
                Text(study.patientName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(study.formattedStudyDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(study.seriesCount) series")
                    .font(.caption)
                Text(study.formattedFileSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StudyDetailView: View {
    let study: DICOMStudy
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Patient info
                GroupBox("Patient Information") {
                    Grid(alignment: .leading) {
                        GridRow {
                            Text("Name:")
                            Text(study.patientName)
                        }
                        GridRow {
                            Text("ID:")
                            Text(study.patientID)
                        }
                        if let sex = study.patientSex {
                            GridRow {
                                Text("Sex:")
                                Text(sex)
                            }
                        }
                    }
                }
                
                // Study info
                GroupBox("Study Information") {
                    Grid(alignment: .leading) {
                        GridRow {
                            Text("Date:")
                            Text(study.formattedStudyDate)
                        }
                        if let description = study.studyDescription {
                            GridRow {
                                Text("Description:")
                                Text(description)
                            }
                        }
                    }
                }
                
                // Series list
                GroupBox("Series") {
                    ForEach(study.series) { series in
                        SeriesRow(series: series)
                    }
                }
                
                // Actions
                HStack(spacing: 16) {
                    Button("Open in Viewer") {
                        if let firstSeries = study.series.first {
                            openWindow(id: "viewer", value: firstSeries.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if study.series.first?.canRender3D == true {
                        Button("View in 3D") {
                            Task {
                                await openImmersiveSpace(id: "VolumeImmersiveSpace")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(study.displayName)
    }
}

struct SeriesRow: View {
    let series: DICOMSeries
    
    var body: some View {
        HStack {
            Image(systemName: series.canRender3D ? "cube.fill" : "photo.fill")
                .foregroundStyle(series.canRender3D ? .purple : .blue)
            
            VStack(alignment: .leading) {
                Text(series.displayName)
                    .font(.subheadline)
                Text("\(series.instanceCount) images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if series.canRender3D {
                Image(systemName: "visionpro")
                    .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 4)
    }
}
