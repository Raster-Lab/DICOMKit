# Reading DICOM Files

Learn about the different ways to read and parse DICOM files with DICOMKit.

## Overview

DICOMKit provides flexible options for reading DICOM files, from simple file loading to advanced streaming and partial parsing for optimal performance.

## Basic File Reading

The simplest way to read a DICOM file:

```swift
import DICOMKit

let data = try Data(contentsOf: fileURL)
let dicomFile = try DICOMFile.read(from: data)
```

This reads the entire file into memory and parses all data elements.

## Reading Legacy DICOM Files

Some older DICOM files don't have the standard DICM prefix. Use the `force` parameter to read these files:

```swift
// Force parsing even without DICM prefix
let dicomFile = try DICOMFile.read(from: data, force: true)
```

## Parsing Options

Control parsing behavior with ``ParsingOptions``:

```swift
// Metadata-only parsing (skip pixel data)
let options = ParsingOptions(mode: .metadataOnly)
let dicomFile = try DICOMFile.read(from: data, options: options)

// This is much faster for files with large images
```

### Parsing Modes

DICOMKit supports three parsing modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| `.full` | Parse everything | Default, general use |
| `.metadataOnly` | Skip pixel data | Browsing, indexing |
| `.lazyPixelData` | Defer pixel loading | Large files, preview generation |

### Partial Parsing

Stop parsing after a specific tag:

```swift
var options = ParsingOptions(mode: .full)
options.stopAfterTag = .seriesInstanceUID  // Stop after series info

let dicomFile = try DICOMFile.read(from: data, options: options)
// Only elements up to SeriesInstanceUID are parsed
```

Limit the number of elements parsed:

```swift
var options = ParsingOptions(mode: .full)
options.maxElements = 50  // Parse only first 50 elements

let dicomFile = try DICOMFile.read(from: data, options: options)
```

## Memory-Mapped Files

For very large files (>100MB), use memory-mapped file access:

```swift
let dataSource = try MemoryMappedDataSource(url: fileURL)
let options = ParsingOptions(dataSource: dataSource)
let dicomFile = try DICOMFile.read(from: data, options: options)
```

Memory mapping reduces memory usage by 50% or more for large files.

## Lazy Pixel Data Loading

Defer pixel data loading until actually needed:

```swift
let options = ParsingOptions(mode: .lazyPixelData)
let dicomFile = try DICOMFile.read(from: data, options: options)

// Metadata is available immediately
let rows = dicomFile.dataSet.rows
let columns = dicomFile.dataSet.columns

// Pixel data is loaded on first access
let pixelData = try dicomFile.extractPixelData()
```

## File Meta Information

DICOM Part 10 files contain File Meta Information in group 0002:

```swift
let fileMetaInfo = dicomFile.fileMetaInformation

// Get Transfer Syntax
let transferSyntaxUID = fileMetaInfo[.transferSyntaxUID]?.stringValue
print("Transfer Syntax: \(transferSyntaxUID ?? "Unknown")")

// Get Media Storage SOP Class
let sopClassUID = fileMetaInfo[.mediaStorageSOPClassUID]?.stringValue

// Get Implementation Version Name
let implementationVersion = fileMetaInfo[.implementationVersionName]?.stringValue
```

## Transfer Syntax Detection

DICOMKit automatically detects and handles different transfer syntaxes:

```swift
let dicomFile = try DICOMFile.read(from: data)

// Check the transfer syntax
if let tsUID = dicomFile.fileMetaInformation[.transferSyntaxUID]?.stringValue,
   let transferSyntax = TransferSyntax(uid: tsUID) {
    
    print("Transfer Syntax: \(transferSyntax)")
    print("Explicit VR: \(transferSyntax.isExplicitVR)")
    print("Little Endian: \(transferSyntax.isLittleEndian)")
    print("Compressed: \(transferSyntax.isCompressed)")
}
```

## Handling Errors

DICOMKit provides detailed error information:

```swift
do {
    let dicomFile = try DICOMFile.read(from: data)
} catch let error as DICOMError {
    switch error {
    case .invalidFile(let message):
        print("Invalid file: \(message)")
    case .unsupportedTransferSyntax(let uid):
        print("Unsupported transfer syntax: \(uid)")
    case .parsingError(let message):
        print("Parsing error: \(message)")
    default:
        print("DICOM error: \(error)")
    }
} catch {
    print("Error: \(error)")
}
```

## Performance Tips

1. **Use metadata-only mode** when you don't need pixel data
2. **Use memory mapping** for files larger than 100MB
3. **Use partial parsing** when you only need specific elements
4. **Use lazy loading** for thumbnail generation workflows

## See Also

- ``DICOMFile``
- ``DICOMParser``
- ``ParsingOptions``
- ``TransferSyntax``
