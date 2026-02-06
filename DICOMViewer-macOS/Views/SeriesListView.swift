//
//  SeriesListView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Series list view for a study
struct SeriesListView: View {
    let study: DicomStudy
    @State private var selectedSeries: DicomSeries?
    @State private var series: [DicomSeries] = []
    
    var body: some View {
        NavigationSplitView {
            // Series list
            seriesListView
                .navigationTitle("Series")
        } detail: {
            // Image viewer
            if let selectedSeries = selectedSeries {
                ImageViewerView(series: selectedSeries)
            } else {
                ContentUnavailableView(
                    "No Series Selected",
                    systemImage: "photo.stack",
                    description: Text("Select a series to view images")
                )
            }
        }
        .task {
            await loadSeries()
        }
    }
    
    private var seriesListView: some View {
        Group {
            if series.isEmpty {
                ContentUnavailableView(
                    "No Series",
                    systemImage: "photo.stack",
                    description: Text("This study contains no series")
                )
            } else {
                List(selection: $selectedSeries) {
                    ForEach(series) { series in
                        SeriesRow(series: series)
                            .tag(series)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private func loadSeries() async {
        do {
            series = try DatabaseService.shared.fetchSeries(forStudy: study.studyInstanceUID)
            
            // Auto-select first series
            if selectedSeries == nil, let first = series.first {
                selectedSeries = first
            }
        } catch {
            print("Failed to load series: \(error)")
        }
    }
}

/// Row view for a single series
struct SeriesRow: View {
    let series: DicomSeries
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(series.displayName)
                .font(.headline)
            
            HStack {
                if let description = series.seriesDescription {
                    Text(description)
                        .font(.caption)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("\(series.numberOfInstances) images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let bodyPart = series.bodyPartExamined {
                Text(bodyPart)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
