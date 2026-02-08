//
//  StudyBrowserView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Main study browser view
struct StudyBrowserView: View {
    @State private var viewModel = StudyBrowserViewModel()
    @State private var selectedStudy: DicomStudy?
    @State private var showingImportPicker = false
    
    var body: some View {
        NavigationSplitView {
            // Study list sidebar
            studyListView
                .navigationTitle("Studies")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingImportPicker = true }) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .help("Import DICOM files or folders")
                        .accessibilityLabel("Import DICOM files")
                        .accessibilityHint("Opens a file picker to select DICOM files to import")
                    }
                }
                .fileImporter(
                    isPresented: $showingImportPicker,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImport(result)
                }
        } detail: {
            // Series list and viewer
            if let study = selectedStudy {
                SeriesListView(study: study)
            } else {
                ContentUnavailableView(
                    "No Study Selected",
                    systemImage: "doc.text.image",
                    description: Text("Select a study from the list to view its series")
                )
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search by patient name or ID")
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var studyListView: some View {
        VStack(spacing: 0) {
            // Toolbar with filters and stats
            HStack {
                Menu {
                    Button("All Modalities") {
                        viewModel.modalityFilter = nil
                    }
                    Divider()
                    ForEach(["CT", "MR", "US", "CR", "DX"], id: \.self) { modality in
                        Button(modality) {
                            viewModel.modalityFilter = modality
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .help("Filter studies by modality (CT, MR, US, etc.)")
                .accessibilityLabel("Filter by modality")
                
                Spacer()
                
                Menu {
                    ForEach(StudyBrowserViewModel.SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) {
                            viewModel.sortOrder = order
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort studies by date, patient name, or modality")
                .accessibilityLabel("Sort studies")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Study list
            if viewModel.isLoading {
                ProgressView("Loading studies...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.studies.isEmpty {
                ContentUnavailableView(
                    "No Studies",
                    systemImage: "folder",
                    description: Text("Import DICOM files to get started")
                )
            } else {
                List(selection: $selectedStudy) {
                    ForEach(viewModel.studies) { study in
                        StudyRow(study: study, viewModel: viewModel)
                            .tag(study)
                    }
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Study list")
                .accessibilityHint("Select a study to view its series and images")
            }
            
            Divider()
            
            // Statistics footer
            HStack {
                Text("\(viewModel.totalStudies) studies")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: viewModel.totalSize, countStyle: .file))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await viewModel.importFiles(urls)
            }
        case .failure(let error):
            viewModel.errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

/// Row view for a single study
struct StudyRow: View {
    let study: DicomStudy
    let viewModel: StudyBrowserViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(study.displayName)
                    .font(.headline)
                
                Spacer()
                
                if study.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            
            HStack {
                Text(study.patientID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let sex = study.patientSex {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(sex)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text(study.formattedStudyDate)
                    .font(.caption)
                
                Text("•")
                Text(study.modalities)
                    .font(.caption)
                
                Spacer()
                
                Text("\(study.numberOfSeries) series")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let description = study.studyDescription {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                viewModel.toggleStar(for: study)
            } label: {
                Label(study.isStarred ? "Unstar" : "Star", systemImage: study.isStarred ? "star.slash" : "star")
            }
            
            Divider()
            
            Button(role: .destructive) {
                Task {
                    viewModel.selectedStudies.insert(study.id)
                    await viewModel.deleteSelectedStudies()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    StudyBrowserView()
}
