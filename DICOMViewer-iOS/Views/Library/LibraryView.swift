// LibraryView.swift
// DICOMViewer iOS - Library View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main library view displaying all imported studies
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @Binding var selectedStudy: DICOMStudy?
    var onOpenViewer: () -> Void
    
    /// View mode: grid or list
    @State private var viewMode: ViewMode = .grid
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            SearchFilterBar(
                searchText: $viewModel.searchText,
                selectedModality: $viewModel.selectedModality,
                availableModalities: viewModel.availableModalities,
                viewMode: $viewMode
            )
            
            // Content
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredStudies.isEmpty {
                EmptyLibraryView(
                    hasStudies: !viewModel.studies.isEmpty,
                    onImport: { viewModel.showingFilePicker = true }
                )
            } else {
                StudyListContent(
                    studies: viewModel.filteredStudies,
                    viewMode: viewMode,
                    onSelect: { study in
                        selectedStudy = study
                        viewModel.markStudyAccessed(study)
                        onOpenViewer()
                    },
                    onDelete: { study in
                        Task { await viewModel.deleteStudy(study) }
                    }
                )
            }
            
            // Import progress
            if viewModel.isImporting {
                ImportProgressBar(progress: viewModel.importProgress)
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingFilePicker = true
                } label: {
                    Label("Import", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Text("Storage: \(viewModel.storageSizeString)")
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingFilePicker,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await viewModel.importFiles(urls) }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            viewModel.modelContext = modelContext
            await viewModel.loadStudies()
        }
    }
}

/// View mode for study display
enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

/// Search and filter bar
struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedModality: String?
    let availableModalities: [String]
    @Binding var viewMode: ViewMode
    
    var body: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search studies...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter row
            HStack {
                // Modality filter
                Menu {
                    Button("All Modalities") {
                        selectedModality = nil
                    }
                    
                    Divider()
                    
                    ForEach(availableModalities, id: \.self) { modality in
                        Button(modality) {
                            selectedModality = modality
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedModality ?? "All Modalities")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // View mode toggle
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
        }
        .padding()
    }
}

/// Content view for study list/grid
struct StudyListContent: View {
    let studies: [DICOMStudy]
    let viewMode: ViewMode
    let onSelect: (DICOMStudy) -> Void
    let onDelete: (DICOMStudy) -> Void
    
    var body: some View {
        switch viewMode {
        case .grid:
            StudyGridView(studies: studies, onSelect: onSelect, onDelete: onDelete)
        case .list:
            StudyListView(studies: studies, onSelect: onSelect, onDelete: onDelete)
        }
    }
}

/// Grid view for studies
struct StudyGridView: View {
    let studies: [DICOMStudy]
    let onSelect: (DICOMStudy) -> Void
    let onDelete: (DICOMStudy) -> Void
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(studies) { study in
                    StudyGridCell(study: study)
                        .onTapGesture { onSelect(study) }
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(study)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
}

/// Grid cell for a study
struct StudyGridCell: View {
    let study: DICOMStudy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            Group {
                if let thumbPath = study.thumbnailPath,
                   let image = loadThumbnail(from: thumbPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 120)
            .clipped()
            .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(study.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(study.displayDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(study.modalityString)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text("\(study.instanceCount) img")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    #if canImport(UIKit)
    private func loadThumbnail(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
    #endif
}

/// List view for studies
struct StudyListView: View {
    let studies: [DICOMStudy]
    let onSelect: (DICOMStudy) -> Void
    let onDelete: (DICOMStudy) -> Void
    
    var body: some View {
        List {
            ForEach(studies) { study in
                StudyListRow(study: study)
                    .onTapGesture { onSelect(study) }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    onDelete(studies[index])
                }
            }
        }
        .listStyle(.plain)
    }
}

/// List row for a study
struct StudyListRow: View {
    let study: DICOMStudy
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbPath = study.thumbnailPath,
                   let image = loadThumbnail(from: thumbPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(study.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(study.studyDescription ?? "No description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(study.displayDate)
                        .font(.caption)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(study.modalityString)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("\(study.instanceCount) images")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    #if canImport(UIKit)
    private func loadThumbnail(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
    #endif
}

/// Empty library state view
struct EmptyLibraryView: View {
    let hasStudies: Bool
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasStudies ? "magnifyingglass" : "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(hasStudies ? "No Matching Studies" : "No Studies")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(hasStudies 
                 ? "Try adjusting your search or filters"
                 : "Import DICOM files to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !hasStudies {
                Button {
                    onImport()
                } label: {
                    Label("Import Files", systemImage: "plus")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Import progress bar
struct ImportProgressBar: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress) {
                Text("Importing...")
            }
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        LibraryView(selectedStudy: .constant(nil), onOpenViewer: {})
    }
}
