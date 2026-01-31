# DICOMKit

A pure Swift DICOM toolkit for Apple platforms (iOS, macOS, visionOS)

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20visionOS%201-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

DICOMKit is a modern, Swift-native library for reading, writing, and parsing DICOM (Digital Imaging and Communications in Medicine) files. Built with Swift 6 strict concurrency and value semantics, it provides a type-safe, efficient interface for working with medical imaging data on Apple platforms.

## Features (v0.5)

- ✅ **DICOM file reading and writing** (NEW in v0.5)
  - ✅ Create new DICOM files from scratch
  - ✅ Modify existing DICOM files
  - ✅ File Meta Information generation
  - ✅ UID generation utilities
  - ✅ Data element serialization for all VRs
  - ✅ Sequence writing support
  - ✅ Value padding per DICOM specification
  - ✅ Round-trip read → write → read support
- ✅ **Multiple transfer syntax support**:
  - ✅ Explicit VR Little Endian
  - ✅ Implicit VR Little Endian
  - ✅ Explicit VR Big Endian (Retired)
  - ✅ Deflated Explicit VR Little Endian
- ✅ **Compressed pixel data support**:
  - ✅ JPEG Baseline (Process 1) - 1.2.840.10008.1.2.4.50
  - ✅ JPEG Extended (Process 2 & 4) - 1.2.840.10008.1.2.4.51
  - ✅ JPEG Lossless (Process 14) - 1.2.840.10008.1.2.4.57
  - ✅ JPEG Lossless SV1 (Process 14, Selection Value 1) - 1.2.840.10008.1.2.4.70
  - ✅ JPEG 2000 Lossless - 1.2.840.10008.1.2.4.90
  - ✅ JPEG 2000 Lossy - 1.2.840.10008.1.2.4.91
  - ✅ RLE Lossless - 1.2.840.10008.1.2.5
- ✅ **Encapsulated pixel data parsing** - Fragment and offset table support
- ✅ **Extensible codec architecture** - Plugin-based codec support
- ✅ **Uncompressed pixel data extraction** - Extract and render medical images
- ✅ **Photometric interpretation support**:
  - ✅ MONOCHROME1
  - ✅ MONOCHROME2
  - ✅ RGB
  - ✅ YBR color spaces
- ✅ **Multi-frame image support** - Work with CT, MR and other multi-slice images
- ✅ **Window/Level (VOI LUT)** - Apply Window Center/Width transformations
- ✅ **CGImage rendering** - Display images on Apple platforms
- ✅ **Sequence (SQ) parsing** - Full support for nested data sets
- ✅ **Type-safe API** - Leverages Swift's type system for safety
- ✅ **Value semantics** - Immutable data structures with `struct` and `enum`
- ✅ **Strict concurrency** - Full Swift 6 concurrency support
- ✅ **DICOM 2025e compliant** - Based on latest DICOM standard
- ✅ **Apple Silicon optimized** - Native performance on M-series chips

## Limitations (v0.5)

- ❌ **No networking** - No DICOM C-* operations (C-STORE, C-FIND, etc.)
- ❌ **No PALETTE COLOR support** - Deferred to future version
- ❌ **No character set conversion** - UTF-8 only

These features may be added in future versions. See [MILESTONES.md](MILESTONES.md) for the development roadmap.

## Platform Requirements

- **iOS 17.0+**
- **macOS 14.0+**
- **visionOS 1.0+**
- **Apple Silicon only** (M1, M2, M3, M4, or later)
- **Swift 6.2+**

## Installation

### Swift Package Manager

Add DICOMKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rasterdevapps/DICOMKit.git", from: "0.5.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/rasterdevapps/DICOMKit`
3. Select version 0.5.0 or later

## Quick Start

```swift
import DICOMKit
import Foundation

// Read a DICOM file
let fileData = try Data(contentsOf: fileURL)
let dicomFile = try DICOMFile.read(from: fileData)

// Access File Meta Information
if let transferSyntax = dicomFile.transferSyntaxUID {
    print("Transfer Syntax: \(transferSyntax)")
}

// Access data elements from the main data set
if let patientName = dicomFile.dataSet.string(for: .patientName) {
    print("Patient Name: \(patientName)")
}

// Access date/time values with type-safe parsing
if let studyDate = dicomFile.dataSet.date(for: .studyDate) {
    print("Study Date: \(studyDate.year)-\(studyDate.month)-\(studyDate.day)")
    
    // Convert to Foundation Date if needed
    if let date = studyDate.toDate() {
        print("As Foundation Date: \(date)")
    }
}

if let studyTime = dicomFile.dataSet.time(for: .studyTime) {
    print("Study Time: \(studyTime.hour):\(studyTime.minute ?? 0)")
}

// Access age values with type-safe parsing
if let patientAge = dicomFile.dataSet.age(for: .patientAge) {
    print("Patient Age: \(patientAge.humanReadable)")  // e.g., "45 years"
    print("Age in years: \(patientAge.approximateYears)")
}

// Access numeric string values (DS and IS)
if let sliceThickness = dicomFile.dataSet.decimalString(for: .sliceThickness) {
    print("Slice Thickness: \(sliceThickness.value) mm")
}

if let pixelSpacing = dicomFile.dataSet.decimalStrings(for: .pixelSpacing) {
    print("Pixel Spacing: \(pixelSpacing.map { $0.value })")  // e.g., [0.3125, 0.3125]
}

if let instanceNumber = dicomFile.dataSet.integerString(for: .instanceNumber) {
    print("Instance Number: \(instanceNumber.value)")
}

// Access Code String (CS) values
if let modality = dicomFile.dataSet.codeString(for: .modality) {
    print("Modality: \(modality.value)")  // e.g., "CT", "MR"
}

if let imageType = dicomFile.dataSet.codeStrings(for: .imageType) {
    print("Image Type: \(imageType.map { $0.value })")  // e.g., ["ORIGINAL", "PRIMARY", "AXIAL"]
}

// Access Application Entity (AE) values
if let ae = dicomFile.dataSet.applicationEntity(for: .sourceApplicationEntityTitle) {
    print("Source AE: \(ae.value)")  // e.g., "STORESCU"
    print("Padded: \(ae.paddedValue)")  // 16-character padded format
}

// Access Universal Resource (UR) values
if let uri = dicomFile.dataSet.universalResource(for: Tag(group: 0x0008, element: 0x1190)) {
    print("Retrieve URL: \(uri.value)")  // e.g., "http://server/wado?..."
    print("Scheme: \(uri.scheme ?? "none")")  // e.g., "http"
    if let url = uri.url {
        print("Foundation URL: \(url)")
    }
}

// Access sequence (SQ) elements
if let items = dicomFile.dataSet.sequence(for: .procedureCodeSequence) {
    for item in items {
        if let codeValue = item.string(for: Tag(group: 0x0008, element: 0x0100)) {
            print("Code Value: \(codeValue)")
        }
    }
}

// Iterate through all elements
for element in dicomFile.dataSet {
    print("\(element.tag): \(element.vr)")
}
```

### Pixel Data Access (v0.3)

```swift
import DICOMKit

// Extract pixel data from DICOM file
if let pixelData = dicomFile.pixelData() {
    let descriptor = pixelData.descriptor
    print("Image size: \(descriptor.columns) x \(descriptor.rows)")
    print("Bits allocated: \(descriptor.bitsAllocated)")
    print("Bits stored: \(descriptor.bitsStored)")
    print("Number of frames: \(descriptor.numberOfFrames)")
    
    // Get pixel value range
    if let range = pixelData.pixelRange(forFrame: 0) {
        print("Pixel range: \(range.min) to \(range.max)")
    }
    
    // Access individual pixel values
    if let value = pixelData.pixelValue(row: 100, column: 100) {
        print("Pixel at (100, 100): \(value)")
    }
    
    // For RGB images, get color values
    if let color = pixelData.colorValue(row: 100, column: 100) {
        print("RGB: (\(color.red), \(color.green), \(color.blue))")
    }
}

// Get image dimensions
if let rows = dicomFile.imageRows, let cols = dicomFile.imageColumns {
    print("Image dimensions: \(cols) x \(rows)")
}

// Check photometric interpretation
if let pi = dicomFile.photometricInterpretation {
    print("Photometric Interpretation: \(pi.rawValue)")
    print("Is monochrome: \(pi.isMonochrome)")
}

// Get window settings from DICOM file
if let window = dicomFile.windowSettings() {
    print("Window Center: \(window.center)")
    print("Window Width: \(window.width)")
    if let explanation = window.explanation {
        print("Window explanation: \(explanation)")
    }
}

// Get all window presets
let allWindows = dicomFile.allWindowSettings()
for (index, window) in allWindows.enumerated() {
    print("Window \(index): C=\(window.center), W=\(window.width)")
}

// Apply rescale transformation (e.g., for CT Hounsfield Units)
let slope = dicomFile.rescaleSlope()
let intercept = dicomFile.rescaleIntercept()
let hounsfield = dicomFile.rescale(1024.0)  // Convert stored value to HU
print("Hounsfield Units: \(hounsfield)")
```

### Rendering to CGImage (Apple platforms only)

```swift
import DICOMKit
#if canImport(CoreGraphics)
import CoreGraphics

// Render using automatic windowing
if let cgImage = dicomFile.renderFrame(0) {
    // Use the CGImage with SwiftUI, UIKit, or AppKit
}

// Render with custom window settings
let customWindow = WindowSettings(center: 40.0, width: 400.0)  // Soft tissue
if let cgImage = dicomFile.renderFrame(0, window: customWindow) {
    // Use the windowed image
}

// Render using window settings from the DICOM file
if let cgImage = dicomFile.renderFrameWithStoredWindow(0) {
    // Use the image with stored window/level
}

// Use PixelDataRenderer for more control
if let pixelData = dicomFile.pixelData() {
    let renderer = PixelDataRenderer(pixelData: pixelData)
    
    // Render monochrome with specific window
    let window = WindowSettings(center: 50.0, width: 350.0, explanation: "BONE")
    if let image = renderer.renderMonochromeFrame(0, window: window) {
        // Use the rendered image
    }
    
    // Render multi-frame images
    for frameIndex in 0..<pixelData.descriptor.numberOfFrames {
        if let frame = renderer.renderFrame(frameIndex) {
            // Process each frame
        }
    }
}
#endif
```

### DICOM File Writing (v0.5)

```swift
import DICOMKit
import Foundation

// Create a new DICOM file from scratch
var dataSet = DataSet()
dataSet.setString("Doe^John", for: .patientName, vr: .PN)
dataSet.setString("12345678", for: .patientID, vr: .LO)
dataSet.setString("20250131", for: .studyDate, vr: .DA)
dataSet.setUInt16(512, for: .rows)
dataSet.setUInt16(512, for: .columns)

// Create a DICOM file with auto-generated File Meta Information
let dicomFile = DICOMFile.create(
    dataSet: dataSet,
    sopClassUID: "1.2.840.10008.5.1.4.1.1.7",  // Secondary Capture Image Storage
    transferSyntaxUID: "1.2.840.10008.1.2.1"    // Explicit VR Little Endian
)

// Write to data
let fileData = try dicomFile.write()

// Save to file
try fileData.write(to: outputURL)

// Modify an existing file
var existingFile = try DICOMFile.read(from: inputData)
var modifiedDataSet = existingFile.dataSet
modifiedDataSet.setString("Anonymized", for: .patientName, vr: .PN)
modifiedDataSet.remove(tag: .patientBirthDate)

// Create new file with modified data set
let modifiedFile = DICOMFile.create(dataSet: modifiedDataSet)
let outputData = try modifiedFile.write()

// Generate unique UIDs
let generator = UIDGenerator()
let studyUID = generator.generateStudyInstanceUID()
let seriesUID = generator.generateSeriesInstanceUID()
let sopInstanceUID = generator.generateSOPInstanceUID()

// Or use static methods
let newUID = UIDGenerator.generateUID()
```

## Architecture

DICOMKit is organized into three modules:

### DICOMCore
Core data types and utilities:
- `VR` - All 31 Value Representations from DICOM PS3.5
- `Tag` - Data element tags (group, element pairs)
- `DataElement` - Individual DICOM data elements
- `SequenceItem` - Items within a DICOM sequence
- `UIDGenerator` - UID generation for DICOM objects (NEW in v0.5)
- `DICOMWriter` - Data element serialization (NEW in v0.5)
- `DICOMDate` - DICOM Date (DA) value parsing
- `DICOMTime` - DICOM Time (TM) value parsing
- `DICOMDateTime` - DICOM DateTime (DT) value parsing
- `DICOMAgeString` - DICOM Age String (AS) value parsing
- `DICOMCodeString` - DICOM Code String (CS) value parsing
- `DICOMDecimalString` - DICOM Decimal String (DS) value parsing
- `DICOMIntegerString` - DICOM Integer String (IS) value parsing
- `DICOMPersonName` - DICOM Person Name (PN) value parsing
- `DICOMUniqueIdentifier` - DICOM Unique Identifier (UI) value parsing
- `DICOMApplicationEntity` - DICOM Application Entity (AE) value parsing
- `DICOMUniversalResource` - DICOM Universal Resource Identifier (UR) value parsing
- `PhotometricInterpretation` - Image photometric interpretation types
- `PixelDataDescriptor` - Pixel data attributes and metadata
- `PixelData` - Uncompressed pixel data access
- `WindowSettings` - VOI LUT window center/width settings
- `DICOMError` - Error types for parsing failures
- Little Endian and Big Endian byte reading/writing utilities

### DICOMDictionary
Standard DICOM dictionaries:
- `DataElementDictionary` - Standard data element definitions
- `UIDDictionary` - Transfer Syntax and SOP Class UIDs
- Dictionary entry types

### DICOMKit
High-level API:
- `DICOMFile` - DICOM Part 10 file abstraction (reading and writing)
- `DataSet` - Collections of data elements (with setter methods)
- `PixelDataRenderer` - CGImage rendering for Apple platforms (iOS, macOS, visionOS)
- Public API umbrella

## DICOM Standard Compliance

DICOMKit implements:
- **DICOM PS3.5 2025e** - Data Structures and Encoding
- **DICOM PS3.6 2025e** - Data Dictionary (partial, essential tags only)
- **DICOM PS3.10 2025e** - Media Storage and File Format

All parsing behavior is documented with PS3.5 section references. We do not translate implementations from other toolkits (DCMTK, pydicom, fo-dicom) - all behavior is derived directly from the DICOM standard.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

DICOMKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

This library implements the DICOM standard as published by the National Electrical Manufacturers Association (NEMA). DICOM® is a registered trademark of NEMA.

---

**Note**: This is v0.5 - adding DICOM file writing support including file creation, modification, UID generation, and round-trip compatibility. Future versions will add networking capabilities. See [MILESTONES.md](MILESTONES.md) for the development roadmap.
