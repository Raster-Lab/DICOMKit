# DICOMKit

A pure Swift DICOM toolkit for Apple platforms (iOS, macOS, visionOS)

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20visionOS%201-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

DICOMKit is a modern, Swift-native library for reading, writing, and parsing DICOM (Digital Imaging and Communications in Medicine) files. Built with Swift 6 strict concurrency and value semantics, it provides a type-safe, efficient interface for working with medical imaging data on Apple platforms.

## Features (v0.8.8)

- ✅ **Advanced DICOMweb Features (NEW in v0.8.8)**
  - ✅ **OAuth2/OpenID Connect Authentication**
    - ✅ `OAuth2Configuration` for OAuth2 settings
    - ✅ `OAuth2Token` for token representation with expiration tracking
    - ✅ `OAuth2TokenProvider` protocol for token management
    - ✅ `OAuth2TokenManager` actor with automatic token refresh
    - ✅ Client credentials flow (machine-to-machine)
    - ✅ Authorization code flow with PKCE support
    - ✅ SMART on FHIR compatibility with standard scopes
    - ✅ `StaticTokenProvider` for testing
  - ✅ **Server Authentication Middleware (NEW in v0.8.8)**
    - ✅ `JWTClaims` struct for JWT token claim parsing
    - ✅ `JWTVerifier` protocol for pluggable token verification
    - ✅ `UnsafeJWTParser` for token parsing without signature verification
    - ✅ `HMACJWTVerifier` for HMAC-SHA256/384/512 signature verification
    - ✅ `AuthenticationMiddleware` for request authentication
    - ✅ `AuthenticatedUser` struct for authenticated context
    - ✅ `DICOMwebRole` enum (reader, writer, deleter, worklistManager, admin)
    - ✅ `RoleBasedAccessPolicy` for role-based access control
    - ✅ `AccessPolicy` protocol for custom authorization rules
    - ✅ Study-level and patient-level access control
    - ✅ SMART on FHIR patient context support
  - ✅ **DICOMweb Server TLS Configuration (NEW in v0.8.8)**
    - ✅ `TLSConfiguration` struct for HTTPS settings
    - ✅ TLS 1.2/1.3 protocol version support
    - ✅ Certificate and private key loading (PEM/DER formats)
    - ✅ Mutual TLS (mTLS) client authentication
    - ✅ `TLSVersion` enum with protocol version comparison
    - ✅ `CertificateValidationMode` (strict, standard, permissive)
    - ✅ Configuration presets (strict, compatible, development, mutualTLS)
    - ✅ Configuration validation with detailed error messages
    - ✅ PEM content extraction and format detection
  - ✅ **Capability Discovery**
    - ✅ `DICOMwebCapabilities` struct for server capabilities
    - ✅ `GET /capabilities` server endpoint
    - ✅ Service, media type, and transfer syntax reporting
    - ✅ Query and store capability details
  - ✅ **Client-Side Caching**
    - ✅ `CacheConfiguration` with presets (default, minimal, aggressive)
    - ✅ `InMemoryCache` actor with LRU eviction
    - ✅ ETag and conditional request support
    - ✅ Cache-Control header parsing
    - ✅ Cache key generation utilities
  - ✅ **Monitoring and Logging**
    - ✅ `DICOMwebRequestLogger` protocol
    - ✅ `OSLogRequestLogger` for Apple platform integration
    - ✅ `ConsoleRequestLogger` for debugging
    - ✅ `DICOMwebMetrics` actor for performance tracking
    - ✅ Latency percentiles (p50, p95, p99)
    - ✅ Success/error rate tracking
- ✅ **UPS-RS Worklist Services (v0.8.7)**
  - ✅ `Workitem` struct for UPS workitem representation
  - ✅ `UPSState` enum with state machine (SCHEDULED, IN PROGRESS, COMPLETED, CANCELED)
  - ✅ `UPSPriority` enum (STAT, HIGH, MEDIUM, LOW)
  - ✅ `ProgressInformation` for tracking workitem progress
  - ✅ `HumanPerformer`, `CodedEntry`, `ReferencedInstance` supporting types
  - ✅ `UPSQuery` builder with fluent API for workitem searches
  - ✅ `UPSQueryResult` and `WorkitemResult` for query results
  - ✅ `UPSStorageProvider` protocol for workitem storage
  - ✅ `InMemoryUPSStorageProvider` for testing
  - ✅ State transition validation and Transaction UID tracking
  - ✅ Server routes for UPS-RS endpoints (/workitems/*)
  - ✅ Server handler implementations for all UPS-RS operations
  - ✅ Search workitems (GET /workitems)
  - ✅ Retrieve workitem (GET /workitems/{uid})
  - ✅ Create workitem (POST /workitems, POST /workitems/{uid})
  - ✅ Update workitem (PUT /workitems/{uid})
  - ✅ Change state (PUT /workitems/{uid}/state)
  - ✅ Request cancellation (PUT /workitems/{uid}/cancelrequest)
  - ✅ Subscription endpoints (subscribe/unsubscribe/suspend)
  - ✅ Capabilities endpoint includes UPS-RS support status
  - ✅ `UPSClient` for client-side workitem operations
  - ✅ 83 unit tests for UPS types and server handlers
  - 🚧 Event delivery (WebSocket/polling) coming in v0.8.8
- ✅ **DICOMweb Server STOW-RS Enhancements (v0.8.6)**
  - ✅ STOWConfiguration for configurable store behavior
  - ✅ DuplicatePolicy: reject (409 Conflict), replace, or accept (idempotent)
  - ✅ SOP Class validation with allowedSOPClasses whitelist
  - ✅ UID format validation per DICOM standard
  - ✅ Required attribute validation with additionalRequiredTags
  - ✅ Request body size validation (413 Payload Too Large)
  - ✅ STOWDelegate protocol for custom store handling
  - ✅ Support for single instance uploads (application/dicom)
  - ✅ Enhanced STOW-RS response with proper SOP Class UIDs
  - ✅ Failure reason codes (0x0110-0x0124)
  - ✅ Partial success responses (HTTP 202) with warnings
  - ✅ Retrieve URL in success response
  - ✅ Preset configurations: default, strict, permissive
- ✅ **DICOMweb Server (v0.8.5)**
  - ✅ DICOMwebServer actor for hosting DICOM services over HTTP
  - ✅ WADO-RS retrieve endpoints (study, series, instance, metadata)
  - ✅ QIDO-RS search endpoints (studies, series, instances)
  - ✅ STOW-RS store endpoint with multipart parsing
  - ✅ Delete endpoints for study/series/instance removal
  - ✅ DICOMwebStorageProvider protocol for pluggable backends
  - ✅ InMemoryStorageProvider for testing
  - ✅ DICOMwebRouter for URL pattern matching
  - ✅ DICOMwebServerConfiguration with TLS, CORS, rate limiting
  - ✅ DICOMwebRequest/DICOMwebResponse abstractions
  - ✅ CORS preflight handling for browser clients
  - ✅ X-Total-Count headers for pagination
- ✅ **DICOMweb STOW-RS Client (v0.8.4)**
  - ✅ Store DICOM instances to remote servers via HTTP POST
  - ✅ Single instance and batch store operations
  - ✅ Configurable batch size for server limits
  - ✅ Progress reporting with AsyncThrowingStream
  - ✅ Per-instance success/failure tracking
  - ✅ STOWResponse with stored instances and failures
  - ✅ Failure reason codes (duplicate, SOP class not supported, etc.)
  - ✅ Continue-on-error option for batch uploads
  - ✅ Multipart request generation (application/dicom)
- ✅ **DICOMweb QIDO-RS Client (v0.8.3)**
  - ✅ QIDOQuery builder with fluent API for constructing search queries
  - ✅ Study, series, and instance search endpoints
  - ✅ Standard query parameters: PatientName, PatientID, StudyDate, Modality, etc.
  - ✅ Wildcard matching support (*, ?)
  - ✅ Date/Time range queries
  - ✅ Pagination with limit and offset
  - ✅ Include field filtering (includefield parameter)
  - ✅ Fuzzy matching support
  - ✅ Type-safe result types (QIDOStudyResult, QIDOSeriesResult, QIDOInstanceResult)
  - ✅ Automatic X-Total-Count header parsing for pagination
- ✅ **DICOMweb WADO-RS Client (v0.8.2)**
  - ✅ DICOMwebClient for retrieving DICOM objects over HTTP/HTTPS
  - ✅ Study, series, and instance retrieval
  - ✅ Metadata retrieval (JSON format)
  - ✅ Frame-level retrieval for multi-frame images
  - ✅ Rendered image retrieval (JPEG, PNG, GIF)
  - ✅ Thumbnail retrieval at study, series, and instance levels
  - ✅ Bulk data retrieval with range requests
  - ✅ Transfer syntax negotiation
  - ✅ Streaming downloads with AsyncThrowingStream
  - ✅ Progress reporting (bytes and instances)
  - ✅ Cancellation support via Swift Task
  - ✅ Render options (windowing, viewport, quality)
- ✅ **DICOMweb Infrastructure (v0.8.1)**
  - ✅ HTTPClient with retry and interceptor support
  - ✅ DICOM JSON encoding/decoding (PS3.18 Annex F)
  - ✅ Multipart MIME parsing and generation
  - ✅ URL builder for all DICOMweb endpoints
  - ✅ Authentication (Basic, Bearer, API Key, Custom)
  - ✅ Configurable timeouts
- ✅ **Unified Storage Client (v0.7.8)**
  - ✅ DICOMStorageClient actor for unified storage operations
  - ✅ Server pool management with multiple storage destinations
  - ✅ Multiple selection strategies (round-robin, priority, weighted, random, failover)
  - ✅ Automatic server failover on connection failures
  - ✅ Per-server circuit breaker integration
  - ✅ Automatic retry with configurable policies
  - ✅ Per-SOP Class retry configuration
  - ✅ Optional store-and-forward queue integration
  - ✅ Transcoding and validation integration
- ✅ **Transfer Syntax Conversion (v0.7.7)**
  - ✅ Automatic transcoding when target server doesn't support source syntax
  - ✅ Configurable preferred transfer syntaxes with priority ordering
  - ✅ Support for uncompressed syntax conversion (Explicit/Implicit VR, Little/Big Endian)
  - ✅ Decompression support for RLE and JPEG compressed data
  - ✅ Pixel data fidelity preservation options
  - ✅ Lossless/lossy conversion constraints
  - ✅ Integration with DICOM Storage Service
- ✅ **Validation Before Send (v0.7.6)**
  - ✅ DICOMValidator for pre-send data validation
  - ✅ Configurable validation levels (minimal, standard, strict)
  - ✅ Required attribute checking (SOP Class UID, SOP Instance UID, Study/Series UIDs)
  - ✅ UID format validation
  - ✅ Pixel data attribute validation
  - ✅ Transfer Syntax validation
  - ✅ Allowed SOP Classes filtering
  - ✅ Custom required tags configuration
  - ✅ Detailed error and warning reporting
- ✅ **Intelligent Retry Logic (v0.7.5)**
  - ✅ Configurable retry policies with preset configurations
  - ✅ Exponential backoff with jitter to prevent thundering herd
  - ✅ Per-SOP Class retry policy configuration
  - ✅ Integration with error categories (transient, permanent, timeout, resource)
  - ✅ Integration with circuit breaker pattern
  - ✅ Retry executor with progress callbacks
  - ✅ Multiple retry strategies (fixed, exponential, linear)
- ✅ **Audit Logging (v0.7.5)**
  - ✅ IHE ATNA-aligned audit event types for healthcare compliance
  - ✅ Comprehensive audit log entries with transfer metadata
  - ✅ Multiple audit handlers (console, file, OSLog)
  - ✅ File audit logging with JSON Lines format and rotation
  - ✅ Event type filtering for targeted auditing
  - ✅ Storage operation logging helpers
- ✅ **Network Error Handling (v0.7.5)**
  - ✅ Error categorization (transient, permanent, configuration, protocol, timeout, resource)
  - ✅ Recovery suggestions with actionable guidance
  - ✅ Fine-grained timeout configuration (connect, read, write, operation, association)
  - ✅ Preset timeout configurations (.default, .fast, .slow)
  - ✅ Detailed timeout types for diagnosis
  - ✅ Retryability detection for intelligent retry strategies
- ✅ **TLS Security (v0.7.4)**
  - ✅ TLS 1.2/1.3 encryption for DICOM connections
  - ✅ System trust store validation (default)
  - ✅ Certificate pinning for enhanced security
  - ✅ Custom CA trust roots for enterprise PKI
  - ✅ Self-signed certificate support (development mode)
  - ✅ Mutual TLS (mTLS) client authentication
  - ✅ PKCS#12 and keychain identity loading
  - ✅ Preset configurations (.default, .strict, .insecure)
- ✅ **DICOM Storage SCP (v0.7.3)**
  - ✅ Receive DICOM files from remote sources
  - ✅ C-STORE SCP server implementation
  - ✅ Configurable AE whitelist/blacklist
  - ✅ Support for common Storage SOP Classes
  - ✅ Transfer syntax negotiation
  - ✅ StorageDelegate protocol for custom handling
  - ✅ Default file storage handler
  - ✅ Real-time event streaming with AsyncStream
  - ✅ Multiple concurrent associations support
- ✅ **DICOM Batch Storage (v0.7.2)**
  - ✅ Efficient batch transfer of multiple DICOM files
  - ✅ Single association reuse for improved performance
  - ✅ Real-time progress reporting with AsyncStream
  - ✅ Per-file success/failure tracking
  - ✅ Configurable continue-on-error vs fail-fast behavior
  - ✅ Rate limiting support
- ✅ **DICOM Storage Service (v0.7)**
  - ✅ C-STORE SCU for sending DICOM files to remote destinations
  - ✅ Support for all common Storage SOP Classes (CT, MR, CR, DX, US, SC, RT)
  - ✅ Transfer syntax negotiation
  - ✅ Priority support (LOW, MEDIUM, HIGH)
  - ✅ Detailed store result with status codes
  - ✅ Integration with DICOMClient unified API
- ✅ **DICOM Networking (v0.6)**
  - ✅ C-ECHO verification service for connectivity testing
  - ✅ C-FIND query service for finding studies, series, and instances
  - ✅ C-MOVE retrieve service for moving images to a destination AE
  - ✅ C-GET retrieve service for downloading images directly
  - ✅ Patient Root and Study Root Query/Retrieve Information Models
  - ✅ All query levels (PATIENT, STUDY, SERIES, IMAGE)
  - ✅ Wildcard matching support (*, ?)
  - ✅ Date/Time range queries
  - ✅ Type-safe query and retrieve result data structures
  - ✅ Progress reporting with sub-operation counts
  - ✅ Async/await-based API with AsyncStream for streaming results
- ✅ **DICOM file reading and writing** (v0.5)
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
- ✅ **Pixel data error handling** - Detailed error types for unsupported formats
- ✅ **Photometric interpretation support**:
  - ✅ MONOCHROME1
  - ✅ MONOCHROME2
  - ✅ RGB
  - ✅ PALETTE COLOR
  - ✅ YBR color spaces
- ✅ **Multi-frame image support** - Work with CT, MR and other multi-slice images
- ✅ **Window/Level (VOI LUT)** - Apply Window Center/Width transformations
- ✅ **CGImage rendering** - Display images on Apple platforms
- ✅ **Sequence (SQ) parsing** - Full support for nested data sets
- ✅ **Type-safe API** - Leverages Swift's type system for safety
- ✅ **Value semantics** - Immutable data structures with `struct` and `enum`
- ✅ **Strict concurrency** - Full Swift 6 concurrency support
- ✅ **DICOM 2025e compliant** - Based on latest DICOM standard
- ✅ **Universal architecture** - Supports both Apple Silicon (M-series) and Intel (x86_64) processors

## Limitations (v0.7.5)

- ❌ **No character set conversion** - UTF-8 only

These features may be added in future versions. See [MILESTONES.md](MILESTONES.md) for the development roadmap.

## Platform Requirements

- **iOS 17.0+**
- **macOS 14.0+** (Apple Silicon and Intel)
- **visionOS 1.0+**
- **Swift 6.2+**

## Installation

### Swift Package Manager

Add DICOMKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/raster-image/DICOMKit.git", from: "0.5.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/raster-image/DICOMKit`
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

### Error Handling for Pixel Data Extraction

The `tryPixelData()` method provides detailed error information when pixel data extraction fails. This is useful for providing meaningful feedback to users when working with unsupported or malformed DICOM files.

```swift
import DICOMKit
import DICOMCore

// Use tryPixelData() for detailed error handling
do {
    let pixelData = try dicomFile.tryPixelData()
    print("Successfully extracted \(pixelData.descriptor.numberOfFrames) frame(s)")
} catch let error as PixelDataError {
    // Handle specific error types
    switch error {
    case .missingDescriptor:
        print("Missing required pixel data attributes")
    case .missingPixelData:
        print("No pixel data in this DICOM file")
    case .missingTransferSyntax:
        print("Transfer syntax UID missing from file metadata")
    case .unsupportedTransferSyntax(let uid):
        if let name = error.transferSyntaxName {
            print("Unsupported transfer syntax: \(name) (\(uid))")
        } else {
            print("Unsupported transfer syntax: \(uid)")
        }
    case .frameExtractionFailed(let frameIndex):
        print("Failed to extract frame \(frameIndex)")
    case .decodingFailed(let frameIndex, let reason):
        print("Failed to decode frame \(frameIndex): \(reason)")
    }
    
    // Get user-friendly explanation
    print("Details: \(error.explanation)")
}
```

**PixelDataError cases:**
- `.missingDescriptor` - Required attributes (Rows, Columns, Bits Allocated) are missing
- `.missingPixelData` - No pixel data element in the DICOM file
- `.missingTransferSyntax` - Transfer syntax UID is missing from file metadata
- `.unsupportedTransferSyntax(uid)` - Compressed format without a decoder (e.g., JPEG-LS)
- `.frameExtractionFailed(frameIndex)` - Cannot extract frame from encapsulated data
- `.decodingFailed(frameIndex, reason)` - Codec failed to decompress the data

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

// Error-throwing render methods for better diagnostics (CT images, etc.)
do {
    let cgImage = try dicomFile.tryRenderFrame(0)
    // Use the rendered image
} catch let error as PixelDataError {
    print("Render failed: \(error.description)")
    print("Explanation: \(error.explanation)")
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

### DICOM Query Service (v0.6)

```swift
import DICOMNetwork
import Foundation

// Query for studies matching patient name and date range
let studies = try await DICOMQueryService.findStudies(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    matching: QueryKeys(level: .study)
        .patientName("DOE^JOHN*")   // Wildcard matching
        .studyDate("20240101-20241231")   // Date range
        .requestStudyDescription()   // Request additional fields
        .requestModalitiesInStudy()
)

// Process results
for study in studies {
    print("Study: \(study.studyInstanceUID ?? "Unknown")")
    print("  Date: \(study.studyDate ?? "N/A")")
    print("  Description: \(study.studyDescription ?? "N/A")")
    print("  Patient: \(study.patientName ?? "N/A")")
    print("  Modalities: \(study.modalities)")
    print("  Series: \(study.numberOfStudyRelatedSeries ?? 0)")
}

// Query for series within a study
let series = try await DICOMQueryService.findSeries(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    forStudy: studies[0].studyInstanceUID!,
    matching: QueryKeys(level: .series)
        .modality("CT")   // Filter by modality
        .requestSeriesDescription()
        .requestNumberOfSeriesRelatedInstances()
)

for seriesResult in series {
    print("Series: \(seriesResult.seriesNumber ?? 0) - \(seriesResult.modality ?? "N/A")")
    print("  Description: \(seriesResult.seriesDescription ?? "N/A")")
    print("  Instances: \(seriesResult.numberOfSeriesRelatedInstances ?? 0)")
}

// Query for instances within a series
let instances = try await DICOMQueryService.findInstances(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    forStudy: studies[0].studyInstanceUID!,
    forSeries: series[0].seriesInstanceUID!
)

for instance in instances {
    print("Instance: \(instance.instanceNumber ?? 0)")
    print("  SOP Class: \(instance.sopClassUID ?? "N/A")")
    if let rows = instance.rows, let cols = instance.columns {
        print("  Dimensions: \(cols)x\(rows)")
    }
}
```

### DICOM Retrieve Service - C-MOVE (v0.6)

C-MOVE requests the PACS to send images to a destination AE Title. This requires a separate Storage SCP (Service Class Provider) running at the destination to receive the images.

```swift
import DICOMNetwork
import Foundation

// Move a study to a destination AE
// Note: MY_STORAGE_SCP must be a registered AE Title in the PACS
// and point to a running Storage SCP that can receive images
let result = try await DICOMRetrieveService.moveStudy(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    moveDestination: "MY_STORAGE_SCP",
    onProgress: { progress in
        print("Progress: \(progress.completed)/\(progress.total) - \(progress.failed) failed")
    }
)

print("Move completed: \(result.isSuccess)")
print("Total transferred: \(result.progress.completed)")
if result.hasPartialFailures {
    print("Some images failed: \(result.progress.failed)")
}

// Move a series
let seriesResult = try await DICOMRetrieveService.moveSeries(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
    moveDestination: "MY_STORAGE_SCP"
)

// Move a single instance
let instanceResult = try await DICOMRetrieveService.moveInstance(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
    sopInstanceUID: "1.2.3.4.5.6.7.8.9.10.11",
    moveDestination: "MY_STORAGE_SCP"
)
```

### DICOM Retrieve Service - C-GET (v0.6)

C-GET downloads images directly on the same association, eliminating the need for a separate Storage SCP. This is simpler to use for client applications.

```swift
import DICOMNetwork
import Foundation

// Download a study directly using C-GET (no separate SCP needed)
let studyStream = try await DICOMRetrieveService.getStudy(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9"
)

// Process the async stream of events
for await event in studyStream {
    switch event {
    case .progress(let progress):
        print("Progress: \(progress.completed)/\(progress.total)")
    case .instance(let sopInstanceUID, let sopClassUID, let data):
        print("Received instance: \(sopInstanceUID)")
        print("  SOP Class: \(sopClassUID)")
        print("  Data size: \(data.count) bytes")
        // Save or process the DICOM data
    case .completed(let result):
        print("Download completed: \(result.isSuccess)")
        print("Total downloaded: \(result.progress.completed)")
    case .error(let error):
        print("Error: \(error)")
    }
}

// Download a series using C-GET
let seriesStream = try await DICOMRetrieveService.getSeries(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10"
)

// Process events using the same pattern as above
for await event in seriesStream {
    switch event {
    case .progress(let progress): print("Series progress: \(progress.completed)/\(progress.total)")
    case .instance(_, _, let data): print("Received \(data.count) bytes")
    case .completed(let result): print("Series download: \(result.isSuccess ? "success" : "failed")")
    case .error(let error): print("Error: \(error)")
    }
}

// Download a single instance using C-GET
let instanceStream = try await DICOMRetrieveService.getInstance(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
    sopInstanceUID: "1.2.3.4.5.6.7.8.9.10.11"
)

// Process events using the same pattern
for await event in instanceStream {
    switch event {
    case .instance(_, _, let data):
        // Single instance downloaded
        print("Instance data: \(data.count) bytes")
    case .completed(let result):
        print("Instance download: \(result.isSuccess ? "success" : "failed")")
    default:
        break
    }
}
```

### DICOM Storage Service - C-STORE (v0.7)

C-STORE enables sending DICOM files to remote storage destinations like PACS systems.

```swift
import DICOMNetwork
import Foundation

// Store a complete DICOM file
let fileData = try Data(contentsOf: dicomFileURL)
let result = try await DICOMStorageService.store(
    fileData: fileData,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS"
)

if result.success {
    print("Stored successfully: \(result.affectedSOPInstanceUID)")
    print("Round-trip time: \(result.roundTripTime)s")
} else {
    print("Store failed: \(result.status)")
}

// Store with priority
let urgentResult = try await DICOMStorageService.store(
    fileData: fileData,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    priority: .high
)

// Store a raw data set (without file meta information)
let dataSetResult = try await DICOMStorageService.store(
    dataSetData: dataSetBytes,
    sopClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
    sopInstanceUID: "1.2.3.4.5.6.7.8.9",
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS"
)
```

### DICOM Storage SCP - Receiving Files (v0.7.3)

Storage SCP enables receiving DICOM files from remote sources like modalities and workstations.

```swift
import DICOMNetwork
import Foundation

// Create SCP configuration
let config = StorageSCPConfiguration(
    aeTitle: try AETitle("MY_SCP"),
    port: 11112,
    maxConcurrentAssociations: 10
)

// Create a custom storage handler
class MyStorageHandler: StorageDelegate {
    func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool {
        // Accept only from known AE titles
        return ["MODALITY1", "WORKSTATION"].contains(info.callingAETitle)
    }
    
    func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool {
        // Accept all instances
        return true
    }
    
    func didReceive(file: ReceivedFile) async throws {
        print("Received: \(file.sopInstanceUID)")
        print("  From: \(file.callingAETitle)")
        print("  Size: \(file.dataSize) bytes")
        
        // Save to disk
        let url = URL(fileURLWithPath: "/data/dicom/\(file.sopInstanceUID).dcm")
        try file.dataSetData.write(to: url)
    }
    
    func didFail(error: Error, for sopInstanceUID: String?) async {
        print("Failed to receive: \(error)")
    }
}

// Create and start server
let handler = MyStorageHandler()
let server = DICOMStorageServer(configuration: config, delegate: handler)
try await server.start()

// Monitor server events
for await event in server.events {
    switch event {
    case .started(let port):
        print("Server started on port \(port)")
    case .associationEstablished(let info):
        print("Connection from: \(info.callingAETitle)")
    case .fileReceived(let file):
        print("Received file: \(file.sopInstanceUID)")
    case .associationReleased(let ae):
        print("Connection closed: \(ae)")
    case .error(let error):
        print("Error: \(error)")
    default:
        break
    }
}

// Stop server
await server.stop()

// Or use the default file storage handler
let defaultHandler = DefaultStorageHandler(
    storageDirectory: URL(fileURLWithPath: "/data/dicom")
)
let simpleServer = DICOMStorageServer(configuration: config, delegate: defaultHandler)
try await simpleServer.start()
```

### DICOM Batch Storage Service (v0.7.2)

Batch storage enables efficient transfer of multiple DICOM files over a single association.

```swift
import DICOMNetwork
import Foundation

// Load multiple DICOM files
let files = [
    try Data(contentsOf: file1URL),
    try Data(contentsOf: file2URL),
    try Data(contentsOf: file3URL)
]

// Store batch with progress monitoring
let stream = try await DICOMStorageService.storeBatch(
    files: files,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS"
)

for try await event in stream {
    switch event {
    case .progress(let progress):
        print("Progress: \(progress.succeeded)/\(progress.total)")
        print("Fraction complete: \(Int(progress.fractionComplete * 100))%")
    case .fileResult(let result):
        if result.success {
            print("File \(result.index): stored \(result.sopInstanceUID)")
        } else {
            print("File \(result.index): FAILED - \(result.errorMessage ?? "")")
        }
    case .completed(let result):
        print("Batch complete!")
        print("  Succeeded: \(result.progress.succeeded)")
        print("  Failed: \(result.progress.failed)")
        print("  Warnings: \(result.progress.warnings)")
        print("  Transfer rate: \(Int(result.averageTransferRate)) bytes/s")
    case .error(let error):
        print("Error: \(error)")
    }
}

// Configure batch behavior
let config = BatchStorageConfiguration(
    continueOnError: true,       // Continue after failures
    maxFilesPerAssociation: 100, // Limit files per association
    delayBetweenFiles: 0.1       // Rate limiting (100ms delay)
)

let configuredStream = try await DICOMStorageService.storeBatch(
    files: files,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    configuration: config
)

// Use fail-fast mode to stop on first error
let failFastConfig = BatchStorageConfiguration.failFast
```

### DICOM Client - Unified High-Level API (v0.6.7)

The `DICOMClient` provides a simplified, unified interface for all DICOM networking operations with built-in retry support.

```swift
import DICOMNetwork
import Foundation

// Create a client with retry policy
let client = try DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    timeout: 30,
    retryPolicy: .exponentialBackoff(maxRetries: 3)
)

// Test connectivity
let connected = try await client.verify()
print("Connected: \(connected)")

// Query for studies
let studies = try await client.findStudies(
    matching: QueryKeys(level: .study)
        .patientName("DOE^JOHN*")
        .studyDate("20240101-20241231")
)

// Query for series
let series = try await client.findSeries(
    forStudy: studies[0].studyInstanceUID!,
    matching: QueryKeys(level: .series).modality("CT")
)

// Download a study using C-GET
for await event in try await client.getStudy(studyInstanceUID: studies[0].studyInstanceUID!) {
    switch event {
    case .progress(let progress):
        print("Progress: \(progress.completed)/\(progress.total)")
    case .instance(_, _, let data):
        print("Received \(data.count) bytes")
    case .completed(let result):
        print("Download complete: \(result.progress.completed) instances")
    case .error(let error):
        print("Error: \(error)")
    }
}

// Or use C-MOVE to send to another destination
let result = try await client.moveStudy(
    studyInstanceUID: studies[0].studyInstanceUID!,
    moveDestination: "MY_STORAGE_SCP"
) { progress in
    print("Move progress: \(progress.completed)/\(progress.total)")
}
print("Move result: \(result.isSuccess)")

// Store a DICOM file using C-STORE (NEW in v0.7)
let fileData = try Data(contentsOf: dicomFileURL)
let storeResult = try await client.store(fileData: fileData)
print("Store result: \(storeResult.success ? "success" : "failed")")

// Store multiple files in batch (NEW in v0.7.2)
let files = [fileData1, fileData2, fileData3]
let batchStream = try await client.storeBatch(files: files)

for try await event in batchStream {
    switch event {
    case .progress(let progress):
        print("Batch progress: \(progress.succeeded)/\(progress.total)")
    case .fileResult(let result):
        print("File \(result.index): \(result.success ? "OK" : "FAILED")")
    case .completed(let result):
        print("Batch complete: \(result.progress.succeeded) succeeded")
    case .error(let error):
        print("Error: \(error)")
    }
}
```

#### Retry Policies

Configure how network operations are retried on transient failures:

```swift
// No retries (default)
let noRetry = RetryPolicy.none

// Fixed delay between retries
let fixedRetry = RetryPolicy.fixed(maxRetries: 3, delay: 1.0)

// Exponential backoff (recommended for production)
let exponentialRetry = RetryPolicy.exponentialBackoff(
    maxRetries: 5,
    initialDelay: 0.5,
    maxDelay: 30.0,
    multiplier: 2.0
)
```

### TLS/Secure Connections (v0.7.4)

DICOMKit supports secure DICOM connections using TLS 1.2/1.3 encryption.

```swift
import DICOMNetwork

// Default TLS configuration (TLS 1.2+, system trust store)
let secureClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,  // DICOM TLS port
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: .default
)

// Strict mode: TLS 1.3 only
let strictClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: .strict
)

// Development mode with self-signed certificates (INSECURE)
let devClient = try DICOMClient(
    host: "dev-pacs.local",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: .insecure  // Only for development!
)

// Certificate pinning for enhanced security
let certData = try Data(contentsOf: serverCertURL)
let pinnedCert = try TLSConfiguration.certificate(fromPEM: certData)
let pinnedConfig = TLSConfiguration(certificateValidation: .pinned([pinnedCert]))

let pinnedClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: pinnedConfig
)

// Mutual TLS (mTLS) with client certificate
let clientIdentity = ClientIdentity(
    pkcs12Data: try Data(contentsOf: clientCertURL),
    password: "certificate-password"
)
let mtlsConfig = TLSConfiguration(
    minimumVersion: .tlsProtocol12,
    certificateValidation: .system,
    clientIdentity: clientIdentity
)

let mtlsClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: mtlsConfig
)

// Use secure client for any DICOM operation
let connected = try await secureClient.verify()
let studies = try await secureClient.findStudies(
    matching: QueryKeys(level: .study).patientName("DOE^JOHN*")
)
```

### Network Error Handling (v0.7.5)

DICOMKit provides comprehensive error handling with categorization, recovery suggestions, and fine-grained timeout configuration.

```swift
import DICOMNetwork

// Configure timeouts for different network conditions
let client = try DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    timeoutConfiguration: .default  // or .fast, .slow
)

// Custom timeout configuration
let customTimeouts = TimeoutConfiguration(
    connect: 10,      // 10s to establish connection
    read: 30,         // 30s for read operations
    write: 30,        // 30s for write operations
    operation: 120,   // 120s for entire operation
    association: 30   // 30s for association establishment
)

let customClient = try DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    timeoutConfiguration: customTimeouts
)

// Handle errors with categorization and recovery suggestions
do {
    let connected = try await client.verify()
} catch let error as DICOMNetworkError {
    // Check error category
    switch error.category {
    case .transient:
        print("Temporary failure - retry may succeed")
    case .permanent:
        print("Permanent failure - intervention required")
    case .configuration:
        print("Configuration error - check settings")
    case .protocol:
        print("Protocol error - check compatibility")
    case .timeout:
        print("Timeout - increase timeout or check network")
    case .resource:
        print("Resource error - wait and retry")
    }
    
    // Check if retryable
    if error.isRetryable {
        print("This error can be retried")
    }
    
    // Get recovery suggestion
    print("Suggestion: \(error.recoverySuggestion)")
    
    // Get detailed explanation
    print("Explanation: \(error.explanation)")
}

// Preset timeout configurations
let fastTimeouts = TimeoutConfiguration.fast    // For local networks
let slowTimeouts = TimeoutConfiguration.slow    // For WAN connections
let defaultTimeouts = TimeoutConfiguration.default  // Balanced defaults
```

### DICOM Validation (v0.7.6)

DICOMKit provides comprehensive validation of DICOM data sets before sending to ensure data integrity and compliance.

```swift
import DICOMNetwork
import DICOMCore

// Create a validator
let validator = DICOMValidator()

// Validate a data set with default (standard) configuration
// Using closures for DataSet access
let result = validator.validate(
    getString: { tag in dataSet.string(for: tag) },
    getData: { tag in dataSet[tag]?.valueData },
    configuration: .default
)

if result.isValid {
    print("Validation passed")
    if result.hasWarnings {
        for warning in result.warnings {
            print("Warning: \(warning)")
        }
    }
} else {
    for error in result.errors {
        print("Validation error: \(error)")
    }
}

// Validate with strict configuration for production
let strictResult = validator.validate(
    getString: { tag in dataSet.string(for: tag) },
    getData: { tag in dataSet[tag]?.valueData },
    configuration: .strict
)

// Custom validation configuration
let customConfig = ValidationConfiguration(
    level: .standard,
    validateTransferSyntax: true,
    validatePixelData: true,
    treatWarningsAsErrors: false,
    allowedSOPClasses: [
        "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        "1.2.840.10008.5.1.4.1.1.4"   // MR Image Storage
    ],
    additionalRequiredTags: [.patientWeight, .patientSize]
)

let customResult = validator.validate(
    getString: { tag in dataSet.string(for: tag) },
    getData: { tag in dataSet[tag]?.valueData },
    configuration: customConfig
)

// Validate UIDs directly
if !validator.isValidUID("1.2.840.10008.5.1.4.1.1.2") {
    print("Invalid UID format")
}
```

### Audit Logging (v0.7.5)

DICOMKit provides comprehensive audit logging for healthcare compliance (IHE ATNA).

```swift
import DICOMNetwork

// Configure audit logging at app startup
let auditLogger = AuditLogger.shared

// Add a file handler for persistent logging
let fileHandler = try FileAuditLogHandler(
    directory: URL(fileURLWithPath: "/var/log/dicom"),
    baseName: "dicom_audit",
    maxFileSize: 50 * 1024 * 1024,  // 50 MB
    maxFiles: 10
)
await auditLogger.addHandler(fileHandler)

// Add console handler for debugging (optional)
await auditLogger.addHandler(ConsoleAuditLogHandler(verbose: true))

// Add OSLog handler for system integration (Apple platforms)
await auditLogger.addHandler(OSLogAuditHandler())

// Filter to specific event types (optional)
await auditLogger.setEnabledEventTypes([.storeSent, .storeReceived, .queryExecuted])

// Log a C-STORE send event
let source = AuditParticipant(
    aeTitle: "MY_SCU",
    host: "10.0.0.1",
    port: 11112,
    isRequestor: true,
    userIdentity: "technician"
)

let destination = AuditParticipant(
    aeTitle: "PACS_AE",
    host: "pacs.hospital.com",
    port: 11112,
    isRequestor: false
)

await auditLogger.logStoreSent(
    outcome: .success,
    source: source,
    destination: destination,
    sopClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
    sopInstanceUID: "1.2.3.4.5.6.7.8.9",
    studyInstanceUID: "1.2.3.4.5",
    patientID: "PATIENT123",
    bytesTransferred: 524288,
    duration: 1.5,
    statusCode: 0x0000
)

// Log query operations
await auditLogger.logQueryExecuted(
    outcome: .success,
    source: source,
    destination: destination,
    queryLevel: "STUDY",
    resultCount: 42,
    duration: 0.5
)

// Log security events
await auditLogger.logSecurityEvent(
    outcome: .majorFailure,
    source: AuditParticipant(
        aeTitle: "UNKNOWN",
        host: "192.168.1.99",
        port: 11112,
        isRequestor: true
    ),
    description: "Authentication failed: invalid credentials"
)
```

### DICOMweb Client (v0.8.2)

DICOMKit provides a modern RESTful DICOMweb client for retrieving DICOM objects over HTTP/HTTPS.

```swift
import DICOMWeb

// Configure the DICOMweb client
let config = try DICOMwebConfiguration(
    baseURLString: "https://pacs.example.com/dicom-web",
    authentication: .bearer(token: "your-oauth-token")
)
let client = DICOMwebClient(configuration: config)

// Retrieve all instances in a study
let result = try await client.retrieveStudy(studyUID: "1.2.3.4.5.6789")
print("Retrieved \(result.instances.count) instances")

// Retrieve as a stream for large studies
for try await instanceData in client.retrieveStudyStream(studyUID: "1.2.3.4.5.6789") {
    // Process each instance as it arrives
    print("Received instance: \(instanceData.count) bytes")
}

// Retrieve a specific instance
let instanceData = try await client.retrieveInstance(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    instanceUID: "1.2.3.4.5.6789.1.1"
)

// Retrieve metadata (DICOM JSON)
let metadata = try await client.retrieveStudyMetadata(studyUID: "1.2.3.4.5.6789")
for instance in metadata {
    if let patientName = instance["00100010"] as? [String: Any],
       let value = patientName["Value"] as? [[String: String]],
       let alphabetic = value.first?["Alphabetic"] {
        print("Patient: \(alphabetic)")
    }
}

// Retrieve specific frames from a multi-frame image
let frames = try await client.retrieveFrames(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    instanceUID: "1.2.3.4.5.6789.1.1",
    frames: [1, 5, 10]
)

// Retrieve a rendered image (JPEG) with windowing
let imageData = try await client.retrieveRenderedInstance(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    instanceUID: "1.2.3.4.5.6789.1.1",
    options: DICOMwebClient.RenderOptions(
        windowCenter: 40,
        windowWidth: 400,
        viewportWidth: 512,
        viewportHeight: 512,
        quality: 85,
        format: .jpeg
    )
)

// Retrieve a thumbnail
let thumbnailData = try await client.retrieveStudyThumbnail(
    studyUID: "1.2.3.4.5.6789",
    options: .thumbnail(size: 128)
)

// Retrieve bulk data from a metadata response
if let bulkDataURI = "https://pacs.example.com/dicom-web/studies/.../bulkdata/7FE00010" {
    let pixelData = try await client.retrieveBulkData(uri: bulkDataURI)
}
```

### DICOMweb QIDO-RS Query Client (v0.8.3)

DICOMKit provides a powerful QIDO-RS client for searching DICOM objects with a fluent query builder API.

```swift
import DICOMWeb

// Configure the DICOMweb client
let config = try DICOMwebConfiguration(
    baseURLString: "https://pacs.example.com/dicom-web",
    authentication: .bearer(token: "your-oauth-token")
)
let client = DICOMwebClient(configuration: config)

// Search for studies by patient name with wildcard
let query = QIDOQuery()
    .patientName("Smith*")
    .modality("CT")
    .studyDate(from: "20240101", to: "20241231")
    .limit(10)

let results = try await client.searchStudies(query: query)
print("Found \(results.count) studies")

// Iterate over results with type-safe accessors
for study in results.results {
    print("Study UID: \(study.studyInstanceUID ?? "unknown")")
    print("Patient: \(study.patientName ?? "unknown")")
    print("Date: \(study.studyDate ?? "unknown")")
    print("Description: \(study.studyDescription ?? "N/A")")
}

// Handle pagination
if results.hasMore, let nextOffset = results.nextOffset {
    let nextPage = try await client.searchStudies(
        query: query.offset(nextOffset)
    )
    // Process next page...
}

// Search for series within a study
let seriesResults = try await client.searchSeries(
    studyUID: "1.2.3.4.5.6789",
    query: QIDOQuery().modality("CT")
)

for series in seriesResults.results {
    print("Series: \(series.seriesInstanceUID ?? "unknown")")
    print("Modality: \(series.modality ?? "unknown")")
    print("Description: \(series.seriesDescription ?? "N/A")")
}

// Search for instances
let instanceResults = try await client.searchInstances(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    query: QIDOQuery().limit(100)
)

for instance in instanceResults.results {
    print("Instance: \(instance.sopInstanceUID ?? "unknown")")
    print("Instance #: \(instance.instanceNumber ?? 0)")
}

// Convenience factory methods
let recentCTStudies = try await client.searchStudies(
    query: .studiesByModality("CT", limit: 20)
)

let patientStudies = try await client.searchStudies(
    query: .studiesByPatientName("Doe^John")
)

// Use include fields to request specific attributes
let detailedQuery = QIDOQuery()
    .patientID("12345")
    .includeFields([
        QIDOQueryAttribute.numberOfStudyRelatedSeries,
        QIDOQueryAttribute.numberOfStudyRelatedInstances
    ])

// Enable fuzzy matching for approximate patient name search
let fuzzyQuery = QIDOQuery()
    .patientName("Smyth")
    .fuzzyMatching()
```

### DICOMweb Server TLS Configuration (v0.8.8)

DICOMKit provides comprehensive TLS configuration for secure DICOMweb server deployment.

```swift
import DICOMWeb

// Basic HTTPS server configuration
let tlsConfig = DICOMwebServerConfiguration.TLSConfiguration(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)

let serverConfig = DICOMwebServerConfiguration(
    port: 443,
    host: "0.0.0.0",
    pathPrefix: "/dicom-web",
    tlsConfiguration: tlsConfig
)

// TLS 1.3 strict mode (highest security)
let strictTLS = DICOMwebServerConfiguration.TLSConfiguration.strict(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)

// Compatible mode (TLS 1.2+, works with older clients)
let compatibleTLS = DICOMwebServerConfiguration.TLSConfiguration.compatible(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)

// Mutual TLS (mTLS) - requires client certificates
let mtlsConfig = DICOMwebServerConfiguration.TLSConfiguration.mutualTLS(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key",
    clientCACertificatePath: "/path/to/ca.pem"
)

// Development mode (for testing with self-signed certs)
// WARNING: Never use in production!
let devTLS = DICOMwebServerConfiguration.TLSConfiguration.development(
    certificatePath: "/path/to/dev-cert.pem",
    privateKeyPath: "/path/to/dev-key.pem"
)

// Validate configuration before use
do {
    try tlsConfig.validate()
    print("TLS configuration is valid")
} catch let error as DICOMwebServerConfiguration.TLSConfigurationError {
    print("TLS configuration error: \(error.description)")
}

// Production preset with TLS and rate limiting
let productionConfig = DICOMwebServerConfiguration.production(
    port: 443,
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)
```

## Architecture

DICOMKit is organized into four modules:

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
- `PixelDataError` - Detailed error types for pixel data extraction failures
- `WindowSettings` - VOI LUT window center/width settings
- `DICOMError` - Error types for parsing failures
- Little Endian and Big Endian byte reading/writing utilities

### DICOMDictionary
Standard DICOM dictionaries:
- `DataElementDictionary` - Standard data element definitions
- `UIDDictionary` - Transfer Syntax and SOP Class UIDs
- Dictionary entry types

### DICOMNetwork (v0.6, v0.7, v0.7.2, v0.7.3, v0.7.4, v0.7.5, v0.7.6, v0.7.7, v0.7.8)
DICOM network protocol implementation:
- `DICOMStorageClient` - Unified storage client with server pool and automatic failover (NEW in v0.7.8)
- `DICOMStorageClientConfiguration` - Storage client configuration (NEW in v0.7.8)
- `ServerPool` - Server pool management with selection strategies (NEW in v0.7.8)
- `ServerEntry` - Server entry with connection settings (NEW in v0.7.8)
- `ServerSelectionStrategy` - Selection strategies (round-robin, priority, weighted, random, failover) (NEW in v0.7.8)
- `StorageClientResult` - Detailed result with server and retry information (NEW in v0.7.8)
- `DICOMClient` - Unified high-level client API with retry support (NEW in v0.6.7)
- `DICOMClientConfiguration` - Client configuration with server settings (NEW in v0.6.7)
- `RetryPolicy` - Configurable retry policies with exponential backoff (NEW in v0.6.7)
- `ErrorCategory` - Error categorization (transient, permanent, configuration, protocol, timeout, resource) (NEW in v0.7.5)
- `RecoverySuggestion` - Actionable recovery guidance for errors (NEW in v0.7.5)
- `TimeoutConfiguration` - Fine-grained timeout settings for network operations (NEW in v0.7.5)
- `TimeoutType` - Specific timeout type identification (NEW in v0.7.5)
- `AuditLogger` - Central audit logging for DICOM network operations (NEW in v0.7.5)
- `AuditLogEntry` - Comprehensive audit log entry with transfer metadata (NEW in v0.7.5)
- `AuditEventType` - Types of auditable DICOM network events (NEW in v0.7.5)
- `AuditEventOutcome` - Outcome classification for audit events (NEW in v0.7.5)
- `AuditParticipant` - Information about participants in auditable events (NEW in v0.7.5)
- `AuditLogHandler` - Protocol for handling audit log entries (NEW in v0.7.5)
- `ConsoleAuditLogHandler` - Console-based audit log handler (NEW in v0.7.5)
- `FileAuditLogHandler` - File-based audit log handler with rotation (NEW in v0.7.5)
- `OSLogAuditHandler` - OSLog-based audit handler for Apple platforms (NEW in v0.7.5)
- `DICOMLogCategory.storage` - Log category for C-STORE operations (NEW in v0.7.5)
- `DICOMLogCategory.audit` - Log category for audit events (NEW in v0.7.5)
- `DICOMValidator` - Pre-send data validation for DICOM data sets (NEW in v0.7.6)
- `ValidationConfiguration` - Validation configuration with levels and options (NEW in v0.7.6)
- `ValidationResult` - Validation result with errors and warnings (NEW in v0.7.6)
- `TransferSyntaxConverter` - Automatic transcoding between transfer syntaxes (NEW in v0.7.7)
- `PreferredTransferSyntax` - Configurable preferred transfer syntaxes (NEW in v0.7.7)
- `TLSConfiguration` - TLS settings with protocol versions, certificate validation (NEW in v0.7.4)
- `TLSProtocolVersion` - TLS protocol version enumeration (NEW in v0.7.4)
- `CertificateValidation` - Certificate validation modes (system, disabled, pinned, custom) (NEW in v0.7.4)
- `ClientIdentity` - Client certificate for mutual TLS authentication (NEW in v0.7.4)
- `TLSConfigurationError` - TLS configuration error types (NEW in v0.7.4)
- `DICOMVerificationService` - C-ECHO SCU for connectivity testing
- `DICOMQueryService` - C-FIND SCU for querying PACS
- `DICOMRetrieveService` - C-MOVE and C-GET SCU for retrieving images
- `DICOMStorageService` - C-STORE SCU for sending DICOM files (v0.7), batch storage (v0.7.2)
- `DICOMStorageServer` - C-STORE SCP for receiving DICOM files (NEW in v0.7.3)
- `StorageSCPConfiguration` - SCP configuration with AE whitelist/blacklist (NEW in v0.7.3)
- `StorageDelegate` - Protocol for custom storage handling (NEW in v0.7.3)
- `ReceivedFile` - Received DICOM file information (NEW in v0.7.3)
- `StorageServerEvent` - Event types for server monitoring (NEW in v0.7.3)
- `StoreResult` - Result type for single storage operations (NEW in v0.7)
- `StorageConfiguration` - Configuration for storage operations (NEW in v0.7)
- `BatchStoreResult`, `FileStoreResult` - Result types for batch operations (NEW in v0.7.2)
- `BatchStoreProgress`, `StorageProgressEvent` - Progress reporting for batch storage (NEW in v0.7.2)
- `BatchStorageConfiguration` - Configuration for batch storage operations (NEW in v0.7.2)
- `QueryKeys` - Fluent API for building query identifiers
- `RetrieveKeys` - Fluent API for building retrieve identifiers
- `QueryLevel` - PATIENT, STUDY, SERIES, IMAGE levels
- `QueryRetrieveInformationModel` - Patient Root, Study Root models
- `StudyResult`, `SeriesResult`, `InstanceResult` - Type-safe query results
- `RetrieveProgress`, `RetrieveResult` - Progress and result types for retrieve operations
- `Association` - DICOM Association management
- `CommandSet`, `PresentationContext` - Low-level protocol types
- `DIMSEMessages` - DIMSE-C message types (C-ECHO, C-FIND, C-STORE, C-MOVE, C-GET)

### DICOMKit
High-level API:
- `DICOMFile` - DICOM Part 10 file abstraction (reading and writing)
- `DataSet` - Collections of data elements (with setter methods)
- `PixelDataRenderer` - CGImage rendering for Apple platforms (iOS, macOS, visionOS)
- Public API umbrella

### DICOMWeb (v0.8.1, v0.8.2, v0.8.3, v0.8.4, v0.8.5, v0.8.6, v0.8.7, v0.8.8)
DICOMweb (RESTful DICOM) client and server implementation:

**Advanced Features (NEW in v0.8.8):**
- `OAuth2Configuration` - OAuth2 client configuration
- `OAuth2Token` - Token representation with expiration tracking
- `OAuth2Error` - OAuth2 error handling
- `PKCE` - Proof Key for Code Exchange for public clients
- `OAuth2TokenProvider` - Protocol for token management
- `OAuth2TokenManager` - Actor for token lifecycle management
- `StaticTokenProvider` - Simple token provider for testing
- `DICOMwebCapabilities` - Server capabilities representation
- `DICOMwebCapabilities.SupportedServices` - Supported services info
- `DICOMwebCapabilities.QueryCapabilities` - Query feature support
- `DICOMwebCapabilities.StoreCapabilities` - Store feature support
- `CacheConfiguration` - Cache configuration with presets
- `CacheEntry` - Cached response with TTL
- `CacheStorage` - Protocol for cache storage
- `InMemoryCache` - LRU in-memory cache actor
- `CacheKeyGenerator` - Cache key utilities
- `CacheControlDirective` - Cache-Control header parsing
- `DICOMwebRequestLogger` - Request/response logging protocol
- `OSLogRequestLogger` - OSLog-based logger
- `ConsoleRequestLogger` - Console debug logger
- `NullRequestLogger` - No-op logger
- `CompositeRequestLogger` - Multiple logger aggregation
- `DICOMwebMetrics` - Performance metrics actor
- `MetricTimer` - Operation timing helper

**Server Authentication Middleware (NEW in v0.8.8):**
- `JWTClaims` - JWT token claims parsing
- `JWTVerifier` - Protocol for JWT verification
- `JWTVerificationError` - JWT verification error types
- `UnsafeJWTParser` - JWT parser without signature verification
- `HMACJWTVerifier` - HMAC-based JWT verifier (HS256/384/512)
- `AuthenticatedUser` - Authenticated user context
- `DICOMwebRole` - Standard DICOM roles (reader, writer, deleter, worklistManager, admin)
- `DICOMwebOperation` - Operations (search, retrieve, store, delete, worklist*)
- `DICOMwebResource` - Resource types with UIDs
- `AccessPolicy` - Protocol for authorization policies
- `RoleBasedAccessPolicy` - Role-based access control with presets
- `AuthenticationConfiguration` - Authentication configuration
- `AuthenticationMiddleware` - Request authentication and authorization
- `AuthenticationError` - Authentication error types
- `AuthorizationError` - Authorization error types

**UPS-RS (Unified Procedure Step) Components (NEW in v0.8.7):**
- `Workitem` - UPS workitem representation with scheduling and state
- `UPSState` - State machine (SCHEDULED, IN PROGRESS, COMPLETED, CANCELED)
- `UPSPriority` - Priority levels (STAT, HIGH, MEDIUM, LOW)
- `ProgressInformation` - Workitem progress tracking
- `HumanPerformer` - Performer information
- `CodedEntry` - Coded values (SNOMED, LOINC, etc.)
- `ReferencedInstance` - Referenced DICOM instance
- `UPSQuery` - Fluent query builder for workitem searches
- `UPSQueryAttribute` - Standard UPS-RS query attribute tags
- `UPSQueryResult` - Paginated workitem query results
- `WorkitemResult` - Individual workitem result
- `UPSStorageProvider` - Protocol for workitem storage backends
- `InMemoryUPSStorageProvider` - In-memory workitem storage for testing
- `UPSStorageQuery` - Query parameters for workitem searches
- `UPSError` - Error types for UPS operations
- `UPSStateChangeRequest` - State change request
- `UPSCancellationRequest` - Cancellation request
- `UPSCreateResponse`, `UPSStateChangeResponse`, `UPSCancellationResponse` - Response types
- `UPSTag` - DICOM tag constants for UPS attributes

**Server Components:**
- `DICOMwebServer` - WADO-RS, QIDO-RS, and STOW-RS server actor (v0.8.5)
- `DICOMwebServerConfiguration` - Server configuration (port, TLS, CORS, rate limiting, STOW) (v0.8.5, v0.8.6)
- `DICOMwebServerConfiguration.TLSConfiguration` - TLS/HTTPS configuration with presets (NEW in v0.8.8)
- `DICOMwebServerConfiguration.TLSVersion` - TLS protocol version enum (NEW in v0.8.8)
- `DICOMwebServerConfiguration.CertificateValidationMode` - Client certificate validation modes (NEW in v0.8.8)
- `DICOMwebServerConfiguration.TLSConfigurationError` - TLS configuration error types (NEW in v0.8.8)
- `DICOMwebServerConfiguration.STOWConfiguration` - STOW-RS configuration (duplicate policy, validation) (NEW in v0.8.6)
- `DICOMwebStorageProvider` - Protocol for pluggable storage backends (v0.8.5)
- `InMemoryStorageProvider` - In-memory storage for testing (v0.8.5)
- `DICOMwebRouter` - URL pattern matching for DICOMweb routes (v0.8.5)
- `DICOMwebRequest` - HTTP request abstraction (v0.8.5)
- `DICOMwebResponse` - HTTP response abstraction (v0.8.5)
- `RouteMatch` - Route matching result with path parameters (v0.8.5)
- `StorageQuery` - Query parameters for storage searches (v0.8.5)
- `StudyRecord`, `SeriesRecord`, `InstanceRecord` - Query result types (v0.8.5)
- `STOWDelegate` - Protocol for STOW-RS event handling (NEW in v0.8.6)
- `DICOMwebServerDelegate` - Protocol for server lifecycle events (v0.8.5)

**Client Components:**
- `DICOMwebClient` - WADO-RS, QIDO-RS, and STOW-RS client for DICOM web services
- `UPSClient` - UPS-RS (Unified Procedure Step) client for worklist management (NEW in v0.8.7)
- `STOWResponse` - Response type for store operations (v0.8.4)
- `StoreProgress` - Progress information for uploads (v0.8.4)
- `StoreOptions` - Configuration for store operations (v0.8.4)
- `StoreEvent` - Event types for progress streams (v0.8.4)
- `QIDOQuery` - Fluent query builder for QIDO-RS searches (v0.8.3)
- `QIDOStudyResult` - Type-safe study query result (v0.8.3)
- `QIDOSeriesResult` - Type-safe series query result (v0.8.3)
- `QIDOInstanceResult` - Type-safe instance query result (v0.8.3)
- `QIDOResults<T>` - Paginated query results container (v0.8.3)
- `QIDOQueryAttribute` - Standard QIDO-RS query attribute tags (v0.8.3)
- `RetrieveResult` - Result type for retrieve operations (v0.8.2)
- `FrameResult` - Result type for frame retrieval (v0.8.2)
- `RenderOptions` - Options for rendered image retrieval (v0.8.2)
- `RetrieveProgress` - Progress information for downloads (v0.8.2)
- `HTTPClient` - HTTP client with retry and interceptor support (v0.8.1)
- `DICOMwebConfiguration` - Configuration for DICOMweb clients (v0.8.1)
- `DICOMwebURLBuilder` - URL construction utilities (v0.8.1)
- `DICOMJSONEncoder` - DICOM JSON encoding per PS3.18 Annex F (v0.8.1)
- `DICOMJSONDecoder` - DICOM JSON decoding per PS3.18 Annex F (v0.8.1)
- `MultipartMIME` - Multipart MIME parsing and generation (v0.8.1)
- `DICOMMediaType` - Media type definitions (v0.8.1)
- `DICOMwebError` - Error types for DICOMweb operations (v0.8.1)

## DICOM Standard Compliance

DICOMKit implements:
- **DICOM PS3.5 2025e** - Data Structures and Encoding
- **DICOM PS3.6 2025e** - Data Dictionary (partial, essential tags only)
- **DICOM PS3.7 2025e** - Message Exchange (DIMSE-C services)
- **DICOM PS3.8 2025e** - Network Communication Support (Upper Layer Protocol)
- **DICOM PS3.10 2025e** - Media Storage and File Format
- **DICOM PS3.15 2025e** - Security and System Management Profiles (TLS support)
- **DICOM PS3.18 2025e** - Web Services (DICOMweb WADO-RS, QIDO-RS, STOW-RS, DICOM JSON)

All parsing behavior is documented with PS3.5 section references. We do not translate implementations from other toolkits (DCMTK, pydicom, fo-dicom) - all behavior is derived directly from the DICOM standard.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

DICOMKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

This library implements the DICOM standard as published by the National Electrical Manufacturers Association (NEMA). DICOM® is a registered trademark of NEMA.

---

**Note**: This is v0.8.8 - implementing advanced DICOMweb features including OAuth2/OpenID Connect authentication, server authentication middleware with JWT verification and role-based access control, capability discovery, client-side caching, and monitoring/logging. The library provides both client and server implementations for WADO-RS (retrieve), QIDO-RS (query), STOW-RS (store), and UPS-RS (worklist) operations. See [MILESTONES.md](MILESTONES.md) for the development roadmap.
