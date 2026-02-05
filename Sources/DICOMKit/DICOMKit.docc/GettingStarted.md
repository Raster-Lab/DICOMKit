# Getting Started with DICOMKit

Learn how to add DICOMKit to your project and perform basic DICOM operations.

## Overview

DICOMKit provides a Swift-native interface for working with DICOM medical imaging files. This guide walks you through installation and basic usage.

## Adding DICOMKit to Your Project

Add DICOMKit to your Swift package dependencies:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/raster-image/DICOMKit.git", from: "1.0.0")
]
```

Then add DICOMKit as a dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["DICOMKit"]
)
```

### Using Xcode

1. Open your project in Xcode
2. Go to File → Add Package Dependencies
3. Enter the repository URL: `https://github.com/raster-image/DICOMKit.git`
4. Select the version and click Add Package

## Importing DICOMKit

Import DICOMKit at the top of your Swift files:

```swift
import DICOMKit
```

This automatically imports `DICOMCore` and `DICOMDictionary` as well.

## Reading a DICOM File

Load and read a DICOM file from disk:

```swift
import DICOMKit

// Read a DICOM file
let fileURL = URL(fileURLWithPath: "/path/to/dicom/file.dcm")
let data = try Data(contentsOf: fileURL)
let dicomFile = try DICOMFile.read(from: data)

// Access patient information
if let patientName = dicomFile.dataSet.patientName {
    print("Patient: \(patientName)")
}

if let patientID = dicomFile.dataSet.patientID {
    print("Patient ID: \(patientID)")
}

// Access study information
if let studyDescription = dicomFile.dataSet.studyDescription {
    print("Study: \(studyDescription)")
}
```

## Rendering an Image

Extract and render pixel data to display a medical image:

```swift
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics

// Read the DICOM file
let dicomFile = try DICOMFile.read(from: data)

// Extract pixel data
let pixelData = try dicomFile.extractPixelData()

// Create a renderer
let renderer = PixelDataRenderer(
    pixelData: pixelData,
    windowCenter: 40,  // Adjust for your modality
    windowWidth: 400
)

// Render to CGImage
if let cgImage = renderer.renderFrame(0) {
    // Use the image in your UI
    // SwiftUI: Image(cgImage, scale: 1.0, label: Text(""))
    // UIKit: UIImage(cgImage: cgImage)
}
#endif
```

## Accessing Data Elements

DICOMKit provides convenient accessors for common DICOM attributes:

```swift
let dataSet = dicomFile.dataSet

// Patient Information
let patientName = dataSet.patientName
let patientID = dataSet.patientID
let patientBirthDate = dataSet.patientBirthDate
let patientSex = dataSet.patientSex

// Study Information
let studyInstanceUID = dataSet.studyInstanceUID
let studyDate = dataSet.studyDate
let studyTime = dataSet.studyTime
let accessionNumber = dataSet.accessionNumber

// Series Information
let seriesInstanceUID = dataSet.seriesInstanceUID
let modality = dataSet.modality
let seriesNumber = dataSet.seriesNumber

// Image Information
let rows = dataSet.rows
let columns = dataSet.columns
let bitsAllocated = dataSet.bitsAllocated
let pixelRepresentation = dataSet.pixelRepresentation
```

## Working with Tags

Access data elements directly using DICOM tags:

```swift
// Using convenience properties on Tag
let patientElement = dataSet[.patientName]
let studyElement = dataSet[Tag.studyDescription]

// Using group and element numbers
let customTag = Tag(group: 0x0010, element: 0x0010)
let element = dataSet[customTag]

// Get the string value
if let element = dataSet[.patientName],
   let value = element.stringValue {
    print("Patient Name: \(value)")
}
```

## Memory-Efficient Loading

For large files, use parsing options to control memory usage:

```swift
// Metadata-only parsing (skip pixel data)
let options = ParsingOptions(mode: .metadataOnly)
let dicomFile = try DICOMFile.read(from: data, options: options)

// Access metadata without loading pixel data into memory
let patientName = dicomFile.dataSet.patientName
let rows = dicomFile.dataSet.rows
```

## Next Steps

- <doc:ReadingDICOMFiles>: Learn about advanced parsing options
- <doc:RenderingImages>: Explore image rendering and windowing
- <doc:WorkingWithPresentationStates>: Apply presentation states
- <doc:NetworkingGuide>: Query and retrieve DICOM from PACS

## See Also

- ``DICOMFile``
- ``DataSet``
- ``PixelDataRenderer``
