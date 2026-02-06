// MetadataView.swift
// DICOMViewer iOS - Metadata View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI

/// View for displaying DICOM metadata
struct MetadataView: View {
    let study: DICOMStudy
    let series: DICOMSeries?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportOptions = false
    @State private var exportFormat: MetadataExportFormat = .json
    
    var body: some View {
        NavigationStack {
            List {
                // Patient Section
                Section("Patient") {
                    LabeledContent("Name", value: study.displayName)
                    LabeledContent("ID", value: study.patientID)
                    
                    if let sex = study.patientSex {
                        LabeledContent("Sex", value: sex)
                    }
                    
                    if let birthDate = study.patientBirthDate {
                        LabeledContent("Birth Date") {
                            Text(birthDate, style: .date)
                        }
                    }
                }
                
                // Study Section
                Section("Study") {
                    LabeledContent("UID") {
                        Text(study.studyInstanceUID)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    
                    if let date = study.studyDate {
                        LabeledContent("Date") {
                            Text(date, style: .date)
                        }
                    }
                    
                    if let description = study.studyDescription {
                        LabeledContent("Description", value: description)
                    }
                    
                    if let accession = study.accessionNumber {
                        LabeledContent("Accession #", value: accession)
                    }
                    
                    LabeledContent("Modalities", value: study.modalityString)
                    LabeledContent("Series Count", value: "\(study.seriesCount)")
                    LabeledContent("Image Count", value: "\(study.instanceCount)")
                }
                
                // Series Section
                if let series = series {
                    Section("Series") {
                        LabeledContent("UID") {
                            Text(series.seriesInstanceUID)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        
                        if let number = series.seriesNumber {
                            LabeledContent("Number", value: "\(number)")
                        }
                        
                        if let description = series.seriesDescription {
                            LabeledContent("Description", value: description)
                        }
                        
                        LabeledContent("Modality", value: series.modality)
                        
                        if let bodyPart = series.bodyPartExamined {
                            LabeledContent("Body Part", value: bodyPart)
                        }
                        
                        LabeledContent("Images", value: series.instanceCountString)
                        
                        if let dims = series.imageDimensions {
                            LabeledContent("Dimensions", value: dims)
                        }
                        
                        if let spacing = series.pixelSpacing, spacing.count >= 2 {
                            LabeledContent("Pixel Spacing") {
                                Text(String(format: "%.2f × %.2f mm", spacing[0], spacing[1]))
                            }
                        }
                        
                        if let thickness = series.sliceThickness {
                            LabeledContent("Slice Thickness") {
                                Text(String(format: "%.2f mm", thickness))
                            }
                        }
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    LabeledContent("Size", value: study.storageSizeString)
                    LabeledContent("Imported") {
                        Text(study.createdAt, style: .date)
                    }
                    LabeledContent("Last Accessed") {
                        Text(study.lastAccessedAt, style: .relative)
                    }
                }
            }
            .navigationTitle("Study Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .confirmationDialog("Export Metadata", isPresented: $showingExportOptions) {
                Button("Export as JSON") {
                    Task { await exportMetadata(format: .json) }
                }
                Button("Export as CSV") {
                    Task { await exportMetadata(format: .csv) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    enum MetadataExportFormat {
        case json, csv
    }
    
    /// Export metadata to file
    private func exportMetadata(format: MetadataExportFormat) async {
        let metadata = gatherMetadata()
        
        do {
            let exportService = ExportService.shared
            let fileURL: URL
            
            switch format {
            case .json:
                fileURL = try await exportService.exportMetadataJSON(metadata)
            case .csv:
                fileURL = try await exportService.exportMetadataCSV(metadata)
            }
            
            // Show share sheet for the exported file
            await MainActor.run {
                shareFile(fileURL)
            }
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }
    
    /// Gather metadata into a dictionary
    private func gatherMetadata() -> [String: String] {
        var metadata: [String: String] = [:]
        
        // Patient information
        metadata["Patient Name"] = study.displayName
        metadata["Patient ID"] = study.patientID
        if let sex = study.patientSex {
            metadata["Patient Sex"] = sex
        }
        if let birthDate = study.patientBirthDate {
            metadata["Patient Birth Date"] = birthDate.formatted(date: .abbreviated, time: .omitted)
        }
        
        // Study information
        metadata["Study Instance UID"] = study.studyInstanceUID
        if let date = study.studyDate {
            metadata["Study Date"] = date.formatted(date: .abbreviated, time: .omitted)
        }
        if let description = study.studyDescription {
            metadata["Study Description"] = description
        }
        if let accession = study.accessionNumber {
            metadata["Accession Number"] = accession
        }
        metadata["Modalities"] = study.modalityString
        metadata["Series Count"] = "\(study.seriesCount)"
        metadata["Image Count"] = "\(study.instanceCount)"
        
        // Series information if available
        if let series = series {
            metadata["Series Instance UID"] = series.seriesInstanceUID
            if let number = series.seriesNumber {
                metadata["Series Number"] = "\(number)"
            }
            if let description = series.seriesDescription {
                metadata["Series Description"] = description
            }
            metadata["Series Modality"] = series.modality
            if let bodyPart = series.bodyPartExamined {
                metadata["Body Part Examined"] = bodyPart
            }
            metadata["Series Images"] = series.instanceCountString
            if let dims = series.imageDimensions {
                metadata["Image Dimensions"] = dims
            }
            if let spacing = series.pixelSpacing, spacing.count >= 2 {
                metadata["Pixel Spacing"] = String(format: "%.2f × %.2f mm", spacing[0], spacing[1])
            }
            if let thickness = series.sliceThickness {
                metadata["Slice Thickness"] = String(format: "%.2f mm", thickness)
            }
        }
        
        // Storage information
        metadata["Storage Size"] = study.storageSizeString
        metadata["Imported At"] = study.createdAt.formatted(date: .abbreviated, time: .standard)
        metadata["Last Accessed"] = study.lastAccessedAt.formatted(date: .abbreviated, time: .standard)
        
        return metadata
    }
    
    /// Share the exported file
    @MainActor
    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Get the current scene and window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        // Find the topmost view controller
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        topController.present(activityVC, animated: true)
    }
}

#Preview {
    let study = DICOMStudy(
        studyInstanceUID: "1.2.3.4.5.6.7.8.9",
        patientName: "DOE^JOHN",
        patientID: "12345",
        studyDate: Date(),
        studyDescription: "CT CHEST W/CONTRAST",
        seriesCount: 3,
        instanceCount: 150,
        modalities: ["CT"],
        storagePath: "/tmp"
    )
    return MetadataView(study: study, series: nil)
}
