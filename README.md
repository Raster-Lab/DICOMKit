# SwiftDICOMKit

A pure Swift DICOM toolkit for Apple platforms (iOS, macOS, visionOS)

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20visionOS%201-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

SwiftDICOMKit is a modern, Swift-native library for reading and parsing DICOM (Digital Imaging and Communications in Medicine) files. Built with Swift 6 strict concurrency and value semantics, it provides a type-safe, efficient interface for working with medical imaging data on Apple platforms.

## Features (v0.1)

- ✅ **Read-only DICOM file parsing** - Parse DICOM Part 10 files
- ✅ **Explicit VR Little Endian support** - Industry-standard transfer syntax
- ✅ **Implicit VR Little Endian support** - DICOM default transfer syntax
- ✅ **Type-safe API** - Leverages Swift's type system for safety
- ✅ **Value semantics** - Immutable data structures with `struct` and `enum`
- ✅ **Strict concurrency** - Full Swift 6 concurrency support
- ✅ **DICOM 2025e compliant** - Based on latest DICOM standard
- ✅ **Apple Silicon optimized** - Native performance on M-series chips

## Limitations (v0.1)

This is an initial release with focused scope:

- ❌ **No pixel data decoding** - Metadata only
- ❌ **No DICOM writing** - Read-only operations
- ❌ **No networking** - No DICOM C-* operations (C-STORE, C-FIND, etc.)
- ❌ **No Big Endian or compressed transfer syntaxes** - Little Endian uncompressed only

These features may be added in future versions.

## Platform Requirements

- **iOS 17.0+**
- **macOS 14.0+**
- **visionOS 1.0+**
- **Apple Silicon only** (M1, M2, M3, M4, or later)
- **Swift 6.2+**

## Installation

### Swift Package Manager

Add SwiftDICOMKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rasterdevapps/SwiftDICOMKit.git", from: "0.1.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/rasterdevapps/SwiftDICOMKit`
3. Select version 0.1.0 or later

## Quick Start

```swift
import SwiftDICOMKit
import Foundation

// Read a DICOM file
let fileData = try Data(contentsOf: fileURL)
let dicomFile = try DicomFile.read(from: fileData)

// Access File Meta Information
if let transferSyntax = dicomFile.transferSyntaxUID {
    print("Transfer Syntax: \(transferSyntax)")
}

// Access data elements from the main data set
if let patientName = dicomFile.dataSet.string(for: .patientName) {
    print("Patient Name: \(patientName)")
}

if let studyDate = dicomFile.dataSet.string(for: .studyDate) {
    print("Study Date: \(studyDate)")
}

// Iterate through all elements
for element in dicomFile.dataSet {
    print("\(element.tag): \(element.vr)")
}
```

## Architecture

SwiftDICOMKit is organized into three modules:

### DICOMCore
Core data types and utilities:
- `VR` - All 31 Value Representations from DICOM PS3.5
- `Tag` - Data element tags (group, element pairs)
- `DataElement` - Individual DICOM data elements
- `DicomError` - Error types for parsing failures
- Little Endian byte reading utilities

### DICOMDictionary
Standard DICOM dictionaries:
- `DataElementDictionary` - Standard data element definitions
- `UIDDictionary` - Transfer Syntax and SOP Class UIDs
- Dictionary entry types

### SwiftDICOMKit
High-level API:
- `DicomFile` - DICOM Part 10 file abstraction
- `DataSet` - Collections of data elements
- Public API umbrella

## DICOM Standard Compliance

SwiftDICOMKit implements:
- **DICOM PS3.5 2025e** - Data Structures and Encoding
- **DICOM PS3.6 2025e** - Data Dictionary (partial, essential tags only)
- **DICOM PS3.10 2025e** - Media Storage and File Format

All parsing behavior is documented with PS3.5 section references. We do not translate implementations from other toolkits (DCMTK, pydicom, fo-dicom) - all behavior is derived directly from the DICOM standard.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

SwiftDICOMKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

This library implements the DICOM standard as published by the National Electrical Manufacturers Association (NEMA). DICOM® is a registered trademark of NEMA.

---

**Note**: This is v0.1 - an initial release focused on core infrastructure and read-only metadata parsing. Future versions will expand functionality based on community needs.
