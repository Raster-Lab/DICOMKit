# DICOMKit Architecture

This document describes the architectural design of DICOMKit.

## Module Overview

DICOMKit is organized into five modules with clear responsibilities:

```
┌─────────────────────────────────────────────────────────────┐
│                        DICOMWeb                              │
│              (DICOMweb RESTful Services)                     │
├─────────────────────────────────────────────────────────────┤
│                        DICOMKit                              │
│              (High-level API, File I/O)                      │
├──────────────────────┬──────────────────────────────────────┤
│   DICOMDictionary    │            DICOMNetwork               │
│  (Tag/UID Lookup)    │     (DICOM Upper Layer Protocol)      │
├──────────────────────┴──────────────────────────────────────┤
│                        DICOMCore                             │
│          (Data Elements, Types, Codecs)                      │
└─────────────────────────────────────────────────────────────┘
```

## Module Dependencies

```
DICOMWeb ─────┬────► DICOMKit ────► DICOMDictionary ────► DICOMCore
              │                                              ▲
              └──────────────────────────────────────────────┘
                                                             
DICOMNetwork ─────────────────────────────────────────────► DICOMCore
```

## DICOMCore

**Purpose**: Core types and utilities for DICOM data representation.

### Key Types

| Type | Description |
|------|-------------|
| `DataElement` | Basic unit of DICOM data (tag, VR, value) |
| `Tag` | DICOM attribute identifier (group, element) |
| `VR` | Value Representation (data type) |
| `TransferSyntax` | Encoding rules for DICOM data |
| `PixelData` | Image pixel data container |
| `CharacterSetHandler` | International text encoding |

### Design Principles

- **Value Semantics**: All types are structs conforming to `Sendable`
- **Immutability**: Data elements are immutable after creation
- **Type Safety**: Strong typing for VR-specific values

## DICOMDictionary

**Purpose**: Standard DICOM tag and UID registries.

### Key Types

| Type | Description |
|------|-------------|
| `DataElementDictionary` | Registry of standard DICOM tags |
| `UIDDictionary` | Registry of SOP Classes and UIDs |
| `DictionaryEntry` | Tag information (keyword, VR, VM) |

### Usage Pattern

```swift
// Lookup by tag
let entry = DataElementDictionary.shared.lookup(group: 0x0010, element: 0x0010)

// Lookup by keyword  
let entry = DataElementDictionary.shared.lookup(keyword: "PatientName")
```

## DICOMKit

**Purpose**: High-level API for file operations and image handling.

### Key Types

| Type | Description |
|------|-------------|
| `DICOMFile` | DICOM Part 10 file representation |
| `DICOMParser` | DICOM file parser |
| `DataSet` | Collection of data elements |
| `PixelDataRenderer` | Image rendering with windowing |

### Subsystems

- **Presentation States**: GSPS, CSPS, Pseudo-Color
- **Hanging Protocols**: Display layout automation
- **Segmentation**: Binary and fractional masks
- **Parametric Maps**: Quantitative imaging
- **Radiation Therapy**: RT Structure Set, Plan, Dose
- **Structured Reporting**: SR document creation

## DICOMNetwork

**Purpose**: DICOM network protocol implementation.

### Key Types

| Type | Description |
|------|-------------|
| `DICOMClient` | Network client for DIMSE operations |
| `Association` | DICOM association management |
| `QueryService` | C-FIND query operations |
| `RetrieveService` | C-GET/C-MOVE operations |
| `StorageService` | C-STORE operations |

### Protocol Layers

```
┌─────────────────────────────┐
│     DIMSE Services          │
│  (C-ECHO, C-STORE, C-FIND)  │
├─────────────────────────────┤
│    Association Layer        │
│ (Request, Accept, Release)  │
├─────────────────────────────┤
│      PDU Layer              │
│   (Protocol Data Units)     │
├─────────────────────────────┤
│      TCP/TLS                │
└─────────────────────────────┘
```

## DICOMWeb

**Purpose**: RESTful DICOMweb services implementation.

### Key Types

| Type | Description |
|------|-------------|
| `DICOMwebClient` | HTTP client for DICOMweb |
| `QIDOQuery` | QIDO-RS query builder |
| `DICOMwebServer` | DICOMweb server implementation |

### Supported Services

- **QIDO-RS**: Query for studies, series, instances
- **WADO-RS**: Retrieve DICOM objects
- **STOW-RS**: Store DICOM objects
- **UPS-RS**: Unified Procedure Step

## Threading and Concurrency

DICOMKit is designed for Swift 6 strict concurrency:

### Sendable Conformance

All data types conform to `Sendable`:

```swift
public struct DataElement: Sendable { ... }
public struct DataSet: Sendable { ... }
public struct DICOMFile: Sendable { ... }
```

### Async/Await

Network operations use Swift concurrency:

```swift
let results = try await client.queryStudies(query)
```

### Actor Isolation

Mutable state is protected by actors:

```swift
actor ImageCache {
    private var cache: [String: CGImage] = [:]
    
    func get(key: String) -> CGImage? { ... }
    func set(_ image: CGImage, for key: String) { ... }
}
```

## Memory Management

### Value Semantics

DICOM data uses Swift value semantics with copy-on-write:

```swift
var dataSet = originalDataSet  // Shallow copy
dataSet[.patientName] = ...    // Copy made here
```

### Large File Handling

- **Memory Mapping**: Files >100MB use memory-mapped access
- **Lazy Loading**: Pixel data loaded on demand
- **Streaming**: Large files parsed incrementally

### Image Caching

```swift
let cache = ImageCache(configuration: .default)
// Automatic LRU eviction when memory limit reached
```

## Error Handling

DICOMKit uses Swift's native error handling:

```swift
enum DICOMError: Error {
    case invalidFile(String)
    case parsingError(String)
    case unsupportedTransferSyntax(String)
    // ...
}
```

All errors provide detailed context for debugging.

## Platform Support

| Platform | Minimum Version | Notes |
|----------|-----------------|-------|
| iOS | 17.0 | Full support |
| macOS | 14.0 | Full support |
| visionOS | 1.0 | Full support |

### Platform-Specific Features

- **CoreGraphics**: Image rendering (all platforms)
- **Accelerate**: SIMD image processing (Apple platforms)
- **Network.framework**: TLS support (Apple platforms)

## Extension Points

### Custom Transfer Syntaxes

Implement `ImageCodec` for custom compression:

```swift
struct MyCodec: ImageCodec {
    func decode(data: Data) throws -> PixelData { ... }
    func encode(pixelData: PixelData) throws -> Data { ... }
}
```

### Custom Storage Providers

Implement `DICOMwebStorageProvider` for custom storage:

```swift
class MyStorage: DICOMwebStorageProvider {
    func store(_ dicomFile: DICOMFile) async throws { ... }
    func retrieve(instanceUID: String) async throws -> DICOMFile { ... }
}
```
