// ExportView.swift
// DICOMViewer iOS - Export View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import CoreGraphics

/// View for exporting DICOM images
struct ExportView: View {
    let image: CGImage
    let series: DICOMSeries?
    
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .png
    @State private var jpegQuality: Double = 0.9
    @State private var saveToPhotos: Bool = true
    @State private var isExporting: Bool = false
    @State private var exportError: String?
    @State private var showingShareSheet: Bool = false
    @State private var exportedFileURL: URL?
    @State private var showingSuccess: Bool = false
    
    enum ExportFormat: String, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
        
        var icon: String {
            switch self {
            case .png: return "photo"
            case .jpeg: return "photo.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Format Selection
                Section("Export Format") {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            HStack {
                                Image(systemName: format.icon)
                                Text(format.rawValue)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if format == .jpeg {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Quality")
                                Spacer()
                                Text("\(Int(jpegQuality * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $jpegQuality, in: 0.1...1.0, step: 0.1)
                        }
                    }
                }
                
                // Options
                Section("Options") {
                    Toggle("Save to Photos", isOn: $saveToPhotos)
                }
                
                // Image Info
                Section("Image Information") {
                    if let series = series {
                        LabeledContent("Modality", value: series.modality)
                        
                        if let description = series.seriesDescription {
                            LabeledContent("Description", value: description)
                        }
                    }
                    
                    LabeledContent("Dimensions") {
                        Text("\(image.width) × \(image.height) px")
                    }
                    
                    let fileSizeEstimate = estimateFileSize()
                    LabeledContent("Est. Size", value: fileSizeEstimate)
                }
                
                // Export Button
                Section {
                    Button {
                        Task {
                            await performExport()
                        }
                    } label: {
                        if isExporting {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Exporting...")
                            }
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Image")
                            }
                        }
                    }
                    .disabled(isExporting)
                    .frame(maxWidth: .infinity)
                }
                
                // Error Display
                if let error = exportError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Export Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Successful", isPresented: $showingSuccess) {
                if let url = exportedFileURL {
                    Button("Share") {
                        showingShareSheet = true
                    }
                }
                Button("Done") {
                    dismiss()
                }
            } message: {
                if saveToPhotos {
                    Text("Image has been saved to your Photos library.")
                } else {
                    Text("Image has been exported.")
                }
            }
        }
    }
    
    /// Perform the export operation
    private func performExport() async {
        isExporting = true
        exportError = nil
        
        do {
            let exportService = ExportService.shared
            
            let options = ExportService.ExportOptions(
                format: format == .png ? .png : .jpeg(quality: jpegQuality),
                burnInAnnotations: false,
                includeMetadata: false,
                saveToPhotos: saveToPhotos
            )
            
            let fileURL = try await exportService.exportImage(image, options: options)
            
            exportedFileURL = fileURL
            showingSuccess = true
            
        } catch {
            exportError = error.localizedDescription
        }
        
        isExporting = false
    }
    
    /// Estimate file size based on format and quality
    private func estimateFileSize() -> String {
        let pixelCount = image.width * image.height
        let estimatedBytes: Int
        
        switch format {
        case .png:
            // PNG is typically 3-4 bytes per pixel for RGB
            estimatedBytes = pixelCount * 3
        case .jpeg:
            // JPEG compression varies, estimate based on quality
            let bytesPerPixel = Int(jpegQuality * 2.0) // 0.2 to 2.0 bytes per pixel
            estimatedBytes = pixelCount * bytesPerPixel
        }
        
        return ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .file)
    }
}

/// Share sheet wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    // Preview requires a valid CGImage
    Text("Export View Preview")
}
