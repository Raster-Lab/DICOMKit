// SeriesPickerView.swift
// DICOMViewer iOS - Series Picker View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI

/// View for selecting a series from a study
struct SeriesPickerView: View {
    let study: DICOMStudy
    @Binding var selectedSeries: DICOMSeries?
    let onSelect: (DICOMSeries) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let seriesList = study.series, !seriesList.isEmpty {
                    ForEach(sortedSeries(seriesList)) { series in
                        SeriesRow(
                            series: series,
                            isSelected: selectedSeries?.id == series.id
                        )
                        .onTapGesture {
                            onSelect(series)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Series",
                        systemImage: "rectangle.stack.badge.minus",
                        description: Text("This study has no series")
                    )
                }
            }
            .navigationTitle("Select Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Sorts series by series number
    private func sortedSeries(_ series: [DICOMSeries]) -> [DICOMSeries] {
        series.sorted { 
            ($0.seriesNumber ?? Int.max) < ($1.seriesNumber ?? Int.max) 
        }
    }
}

/// Row view for a series
struct SeriesRow: View {
    let series: DICOMSeries
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbPath = series.thumbnailPath,
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
                HStack {
                    if let number = series.seriesNumber {
                        Text("Series \(number)")
                            .font(.headline)
                    } else {
                        Text("Series")
                            .font(.headline)
                    }
                    
                    Text(series.modality)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if let description = series.seriesDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(series.instanceCountString)
                        .font(.caption)
                    
                    if let dims = series.imageDimensions {
                        Text("•")
                        Text(dims)
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    #if canImport(UIKit)
    private func loadThumbnail(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
    #endif
}

#Preview {
    let study = DICOMStudy(
        studyInstanceUID: "1.2.3",
        patientName: "Test Patient",
        storagePath: "/tmp"
    )
    return SeriesPickerView(
        study: study,
        selectedSeries: .constant(nil),
        onSelect: { _ in }
    )
}
