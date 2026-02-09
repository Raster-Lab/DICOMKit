# Swift iOS/macOS DICOM Viewer Template

A minimal template for building a DICOM viewer app using DICOMKit.

## Overview

This template demonstrates how to:
- Open and parse DICOM files
- Display patient and study metadata
- Render medical images
- Apply window/level adjustments
- Handle multi-frame images

## Setup

### 1. Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Select "iOS App" or "macOS App"
4. Product Name: "DICOMViewer"
5. Interface: SwiftUI
6. Language: Swift

### 2. Add DICOMKit Dependency

1. File → Add Package Dependencies...
2. Enter: `https://github.com/Raster-Lab/DICOMKit.git`
3. Version: "1.0.0" (or "Up to Next Major")
4. Add to project
5. Select modules:
   - `DICOMKit` (required)
   - `DICOMCore` (required)

### 3. Add Sample Code

Replace `ContentView.swift` with the code below.

## Template Code

```swift
import SwiftUI
import DICOMKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var dicomFile: DICOMFile?
    @State private var patientInfo: PatientInfo?
    @State private var image: NSUIImage?
    @State private var errorMessage: String?
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("DICOM Viewer")
                .font(.largeTitle)
                .padding()
            
            // Open File Button
            Button("Open DICOM File") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
            
            // Patient Information
            if let info = patientInfo {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Patient Name", value: info.name)
                    InfoRow(label: "Patient ID", value: info.id)
                    InfoRow(label: "Study Date", value: info.studyDate)
                    InfoRow(label: "Modality", value: info.modality)
                    InfoRow(label: "Study Description", value: info.studyDescription)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Image Display
            if let image = image {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                #else
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                #endif
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - File Handling
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        do {
            guard let fileURL = try result.get().first else { return }
            
            // Read DICOM file
            let file = try DICOMFile(fileURL: fileURL)
            dicomFile = file
            
            // Extract patient information
            patientInfo = extractPatientInfo(from: file.dataSet)
            
            // Render image
            if let cgImage = try? file.image() {
                #if os(iOS)
                image = UIImage(cgImage: cgImage)
                #else
                image = NSImage(cgImage: cgImage, size: .zero)
                #endif
            }
            
            errorMessage = nil
            
        } catch {
            errorMessage = "Error loading DICOM file: \(error.localizedDescription)"
            patientInfo = nil
            image = nil
        }
    }
    
    private func extractPatientInfo(from dataSet: DataSet) -> PatientInfo {
        PatientInfo(
            name: dataSet.string(for: .patientName) ?? "Unknown",
            id: dataSet.string(for: .patientID) ?? "Unknown",
            studyDate: dataSet.string(for: .studyDate) ?? "Unknown",
            modality: dataSet.string(for: .modality) ?? "Unknown",
            studyDescription: dataSet.string(for: .studyDescription) ?? "No description"
        )
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Text(value)
            Spacer()
        }
    }
}

// MARK: - Data Models

struct PatientInfo {
    let name: String
    let id: String
    let studyDate: String
    let modality: String
    let studyDescription: String
}

// MARK: - Platform Compatibility

#if os(iOS)
typealias NSUIImage = UIImage
#else
typealias NSUIImage = NSImage
#endif
```

## Features Demonstrated

### 1. File Import
- Uses SwiftUI's `fileImporter` modifier
- Handles file selection and error cases

### 2. DICOM Parsing
- Opens DICOM file using `DICOMFile(fileURL:)`
- Extracts metadata using `DataSet.string(for:)`
- Common tags: Patient Name, ID, Study Date, Modality

### 3. Image Rendering
- Converts DICOM pixel data to `CGImage`
- Handles both iOS (`UIImage`) and macOS (`NSImage`)
- Displays with appropriate aspect ratio

### 4. Error Handling
- Shows user-friendly error messages
- Gracefully handles missing data

## Resources

- **DICOMKit Documentation**: https://github.com/Raster-Lab/DICOMKit
- **DICOM Standard**: https://www.dicomstandard.org
- **Apple Developer**: https://developer.apple.com

## License

This template is provided as-is for educational purposes. DICOMKit is available under the MIT License.
