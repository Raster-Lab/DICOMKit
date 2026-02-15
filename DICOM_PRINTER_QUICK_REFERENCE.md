# DICOM Printer - Quick Reference

## Overview

This document provides a quick reference for DICOM Print Management implementation in DICOMKit.

**📄 Full Details**: See [DICOM_PRINTER_PLAN.md](DICOM_PRINTER_PLAN.md) for the comprehensive implementation plan.

## Current Status (v1.4.4)

### ✅ What's Implemented

**Phase 1: Core Print Workflow (v1.4.0-v1.4.1)**
- **DIMSE-N Messages**: N-CREATE, N-SET, N-GET, N-ACTION, N-DELETE (all request/response pairs)
- **Print SOP Classes**: Film Session, Film Box, Image Box (Grayscale/Color), Printer, Print Job
- **Print Data Models**: `FilmSession`, `FilmBox`, `ImageBoxContent`, `PrinterStatus`, `PrintResult`
- **Print Tags**: 35 DICOM tags across groups 0x2000, 0x2010, 0x2020, 0x2100, 0x2110
- **Complete Workflow API**: `createFilmSession`, `createFilmBox`, `setImageBox`, `printFilmBox`, `deleteFilmSession`, `getPrintJobStatus`

**Phase 2: High-Level Print API (v1.4.2)**
- **Simple Print API**: `printImage()`, `printImages()`, `printWithTemplate()`
- **Progress Reporting**: `printImagesWithProgress()` with AsyncThrowingStream
- **Print Options**: `PrintOptions` with presets (`.default`, `.highQuality`, `.draft`, `.mammography`)
- **Print Templates**: `SingleImageTemplate`, `ComparisonTemplate`, `GridTemplate`, `MultiPhaseTemplate`
- **Print Layout**: Automatic optimal layout selection for image count
- **Print Retry**: `PrintRetryPolicy` with exponential backoff

**Phase 3: Image Preparation Pipeline (v1.4.3)**
- **Image Preprocessing**: `ImagePreprocessor` actor with window/level, rescale, polarity handling
- **Image Resizing**: `ImageResizer` actor with fit/fill/stretch modes and quality settings
- **Annotation Rendering**: `AnnotationRenderer` actor for text overlays at various positions

**Phase 4: Advanced Features (v1.4.4) - NEW**
- **Print Queue**: `PrintQueue` actor with priority scheduling and retry logic
- **Printer Registry**: `PrinterRegistry` actor for multiple printer management
- **Enhanced Errors**: `PrintError` enum with detailed cases and recovery suggestions
- **Partial Results**: `PartialPrintResult` for handling partial print failures
- **Printer Capabilities**: `PrinterCapabilities` struct for printer feature tracking

### ❌ What's Remaining (Phase 5)

- **Documentation & CLI** (Phase 5): `dicom-print` CLI tool, user guides
- **Integration Tests**: Testing with real DICOM print SCPs

## Quick Start Examples

### Simple Single Image Printing (NEW in v1.4.2)

```swift
// Print a single image with default options
let result = try await DICOMPrintService.printImage(
    configuration: printConfig,
    imageData: pixelData,
    options: .default
)

// Print with high quality settings
let result = try await DICOMPrintService.printImage(
    configuration: printConfig,
    imageData: pixelData,
    options: .highQuality
)
```

### Multi-Image Printing with Auto Layout (NEW in v1.4.2)

```swift
// Print multiple images - layout is automatically selected
let result = try await DICOMPrintService.printImages(
    configuration: printConfig,
    images: [image1, image2, image3, image4],
    options: PrintOptions(
        filmSize: .size14InX17In,
        filmOrientation: .landscape,
        numberOfCopies: 2
    )
)
```

### Template-Based Printing (NEW in v1.4.2)

```swift
// Print with a specific template
let template = MultiPhaseTemplate(rows: 3, columns: 4)
let result = try await DICOMPrintService.printWithTemplate(
    configuration: printConfig,
    images: multiPhaseImages,
    template: template
)
```

### Print with Progress Reporting (NEW in v1.4.2)

```swift
for try await progress in DICOMPrintService.printImagesWithProgress(
    configuration: printConfig,
    images: images,
    options: .default
) {
    print("Phase: \(progress.phase)")
    print("Progress: \(Int(progress.progress * 100))%")
    print("Message: \(progress.message)")
}
```

### Low-Level Workflow (Phase 1 API)
        content: ImageBoxContent(
            imageBoxUID: filmBoxResult.imageBoxUIDs[index],
            position: UInt16(index + 1),
            pixelData: imageData,
            polarity: .normal
        )
    )
}

// Print film box
let printJobUID = try await DICOMPrintService.printFilmBox(
    configuration: printConfig,
    filmBoxUID: filmBoxResult.filmBoxUID
)

// Monitor print job
let status = try await DICOMPrintService.getPrintJobStatus(
    configuration: printConfig,
    printJobUID: printJobUID
)

// Cleanup
try await DICOMPrintService.deleteFilmSession(
    configuration: printConfig,
    filmSessionUID: filmSessionUID
)
```

### Phase 2: High-Level Print API (v1.4.2)
**Timeline**: 1-2 weeks | **Tests**: 20+

```swift
// Simple single-image printing
let result = try await DICOMPrintService.printImage(
    configuration: printConfig,
    imageData: dicomImageData,
    options: .highQuality
)

// Multi-image printing with layout
let result = try await DICOMPrintService.printImages(
    configuration: printConfig,
    images: [image1, image2, image3, image4],
    options: PrintOptions(
        filmSize: .size11InX14In,
        filmOrientation: .landscape,
        numberOfCopies: 2
    )
)

// Print with template
let result = try await DICOMPrintService.printWithTemplate(
    configuration: printConfig,
    images: multiPhaseImages,
    template: .multiPhase3x4
)

// Print with progress reporting
for try await progress in DICOMPrintService.printImagesWithProgress(
    configuration: printConfig,
    images: images,
    options: .default
) {
    print("Progress: \(progress.phase) - \(Int(progress.progress * 100))%")
}
```

### Phase 3: Image Preparation Pipeline (v1.4.3)
**Timeline**: 1-2 weeks | **Tests**: 30+

```swift
// Preprocess DICOM image for printing
let preprocessor = ImagePreprocessor()
let preparedImage = try await preprocessor.prepareForPrint(
    dataSet: dicomDataSet,
    targetSize: CGSize(width: 1024, height: 1024),
    colorMode: .grayscale
)

// Resize with quality control
let resizer = ImageResizer()
let resizedData = try await resizer.resize(
    pixelData: preparedImage.pixelData,
    from: CGSize(width: 512, height: 512),
    to: CGSize(width: 1024, height: 1024),
    mode: .fit,
    quality: .high
)

// Add annotations
let annotator = AnnotationRenderer()
let annotatedData = try await annotator.addAnnotations(
    to: resizedData,
    imageSize: CGSize(width: 1024, height: 1024),
    annotations: [
        PrintAnnotation(text: "L", position: .topLeft, fontSize: 24, color: .white),
        PrintAnnotation(text: "Patient: John Doe", position: .bottomLeft, fontSize: 16, color: .white)
    ]
)
```

### Phase 4: Advanced Features (v1.4.4) - NEW
**Status**: ✅ Complete | **Tests**: 60+

```swift
// Create a print queue with retry policy
let queue = PrintQueue(maxHistorySize: 100, retryPolicy: .default)

// Add print jobs with priority
let highPriorityJob = PrintJob(
    configuration: printConfig,
    imageURLs: [URL(fileURLWithPath: "/path/to/urgent.dcm")],
    options: .highQuality,
    priority: .high,
    label: "Urgent CT Print"
)
let jobID = await queue.enqueue(job: highPriorityJob)

// Check job status
if let status = await queue.status(jobID: jobID) {
    switch status {
    case .queued(let position):
        print("Job queued at position \(position)")
    case .processing:
        print("Job is being processed")
    case .completed:
        print("Job completed successfully")
    case .failed(let message):
        print("Job failed: \(message)")
    case .cancelled:
        print("Job was cancelled")
    }
}

// Multiple printer management
let registry = PrinterRegistry()

// Add printers with capabilities
let radiologyCaps = PrinterCapabilities(
    supportedFilmSizes: [.size14InX17In, .size11InX14In],
    supportsColor: false,
    maxCopies: 99,
    supportedMediumTypes: [.clearFilm, .blueFilm]
)
let radiologyPrinter = PrinterInfo(
    name: "Radiology Film Printer",
    configuration: printConfig,
    capabilities: radiologyCaps,
    isDefault: true
)
try await registry.addPrinter(radiologyPrinter)

// Select best printer for a job
if let printer = await registry.selectPrinter(
    requiresColor: false,
    filmSize: .size14InX17In
) {
    print("Using printer: \(printer.name)")
}

// Track printer availability
await registry.updateAvailability(id: radiologyPrinter.id, isAvailable: true)
await registry.markSeen(id: radiologyPrinter.id)

// Error handling with recovery suggestions
let error = PrintError.printerUnavailable(message: "Printer offline")
print("Error: \(error.description)")
print("Suggestion: \(error.recoverySuggestion)")

// Handle partial print results
let result = PartialPrintResult(
    successCount: 4,
    failureCount: 2,
    failedPositions: [3, 5],
    errors: [.imageBoxSetFailed(position: 3, statusCode: 0xA900)]
)
if result.isPartiallySuccessful {
    print("Printed \(result.successCount) images, \(result.failureCount) failed")
}
```

### Phase 5: Documentation and Examples (v1.4.5)
**Status**: Planned | **Timeline**: 1 week

CLI Tool: `dicom-print`

```bash
# Query printer status
dicom-print status --host 192.168.1.100 --port 11112 --called-ae PRINT_SCP

# Print single image
dicom-print send image.dcm --printer hospital-film-1 --copies 2

# Print multiple images with layout
dicom-print send *.dcm --layout 2x3 --film-size 11x17 --orientation landscape

# Print with template
dicom-print send series/*.dcm --template multi-phase --annotate

# Monitor print job
dicom-print status --job-id 1.2.840.113619.2.55.3.2024...

# List configured printers
dicom-print list-printers

# Configure printer
dicom-print add-printer --name radiology-film \
    --host 192.168.1.100 --port 11112 \
    --calling-ae WORKSTATION --called-ae PRINT_SCP \
    --color grayscale --default
```

## Print Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    DICOM Print Workflow                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. [N-GET] Query Printer Status                                 │
│     └─ Response: Printer Status, Capabilities                    │
│                                                                   │
│  2. [N-CREATE] Create Film Session                               │
│     └─ Response: Film Session SOP Instance UID                   │
│                                                                   │
│  3. [N-CREATE] Create Film Box                                   │
│     └─ Response: Film Box UID + Image Box UIDs (array)           │
│                                                                   │
│  4. [N-SET] Set Image Box Content (for each image)               │
│     └─ Response: Status                                          │
│                                                                   │
│  5. [N-ACTION] Print Film Box                                    │
│     └─ Response: Print Job SOP Instance UID                      │
│                                                                   │
│  6. [N-GET] Monitor Print Job (optional)                         │
│     └─ Response: Execution Status, Progress                      │
│                                                                   │
│  7. [N-DELETE] Delete Film Session (cleanup)                     │
│     └─ Response: Status                                          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Image Display Formats

Standard film layouts (Image Display Format tag 2010,0010):

| Format | Layout | Description |
|--------|--------|-------------|
| `STANDARD\1,1` | 1×1 | Single image, full film |
| `STANDARD\1,2` | 1×2 | 2 images, horizontal |
| `STANDARD\2,1` | 2×1 | 2 images, vertical |
| `STANDARD\2,2` | 2×2 | 4 images in grid |
| `STANDARD\2,3` | 2×3 | 6 images (2 rows, 3 columns) |
| `STANDARD\3,3` | 3×3 | 9 images in grid |
| `STANDARD\3,4` | 3×4 | 12 images (3 rows, 4 columns) |
| `STANDARD\4,4` | 4×4 | 16 images in grid |
| `STANDARD\4,5` | 4×5 | 20 images (4 rows, 5 columns) |

Image positions are numbered left-to-right, top-to-bottom starting at 1.

## Film Sizes

Standard film sizes (Film Size ID tag 2010,0050):

- `8INX10IN` - 8×10 inches
- `8_5INX11IN` - 8.5×11 inches (Letter)
- `10INX12IN` - 10×12 inches
- `10INX14IN` - 10×14 inches
- `11INX14IN` - 11×14 inches
- `11INX17IN` - 11×17 inches (Tabloid)
- `14INX14IN` - 14×14 inches
- `14INX17IN` - 14×17 inches
- `24CMX24CM` - 24×24 cm
- `24CMX30CM` - 24×30 cm
- `A4` - A4 size (210×297 mm)
- `A3` - A3 size (297×420 mm)

## Print Priorities

- `HIGH` - High priority (urgent cases)
- `MED` - Medium priority (normal workflow)
- `LOW` - Low priority (batch printing)

## Medium Types

- `PAPER` - Plain paper
- `CLEAR FILM` - Clear film (standard)
- `BLUE FILM` - Blue-tinted film
- `MAMMO CLEAR` - Mammography clear-base film
- `MAMMO BLUE` - Mammography blue-base film

## Testing Strategy

### Unit Tests: 120+ tests

- Film Session Management (15 tests)
- Film Box and Image Box Creation (20 tests)
- Image Box Content Management (20 tests)
- Print Execution (15 tests)
- High-Level Print API (20 tests)
- Image Preprocessing (15 tests)
- Image Sizing (10 tests)
- Annotation Rendering (5 tests)

### Integration Tests: 20+ tests

- End-to-end with DCM4CHEE
- End-to-end with Orthanc
- Multi-image layouts
- Color vs. grayscale
- Error recovery and retry
- Multiple printer failover

### Performance Benchmarks

- Single image print: <5 seconds
- Multi-image print: >10 images/minute
- Image preprocessing: <500ms per image
- Concurrent jobs: 5+ jobs in parallel
- Memory usage: <200MB peak

## Test Environment Setup

```yaml
# Docker Compose for test print SCPs
services:
  dcm4chee-print:
    image: dcm4che/dcm4chee-arc-psql:5.31.0
    ports:
      - "11112:11112"
    environment:
      - PRINT_SCP_AET=PRINT_SCP
      
  orthanc-print:
    image: jodogne/orthanc-plugins:latest
    ports:
      - "11113:11112"
    volumes:
      - ./orthanc-print-config.json:/etc/orthanc/orthanc.json
```

## DICOM Standard References

- **PS3.4 Annex H**: Print Management Service Class
- **PS3.7 Section 10.1**: DIMSE-N Services (N-CREATE, N-SET, N-GET, N-ACTION, N-DELETE)
- **PS3.3 Section C.13**: Print Management Modules
  - C.13.1 - Film Session Module
  - C.13.3 - Film Box Module
  - C.13.5 - Image Box Module
  - C.13.8 - Print Job Module
  - C.13.9 - Printer Module

## Commercial DICOM Printers

- **Agfa DryView** - Dry film printers
- **Konica Minolta** - Medical imaging printers
- **Fujifilm** - Dry imaging systems
- **Sony Medical** - Digital graphic printers
- **Carestream** - DRYVIEW laser imagers

## Print Service Providers

Open-source test servers:
- **DCM4CHEE** - Full-featured PACS with print support
- **Orthanc** - Lightweight DICOM server with print plugin
- **DICOM Print Simulator** - Test print SCP

## Timeline Summary

| Phase | Duration | Priority | Key Deliverables |
|-------|----------|----------|------------------|
| Phase 1: Complete Print Workflow API | 2-3 weeks | Critical | N-CREATE, N-SET, N-ACTION, N-DELETE (40+ tests) |
| Phase 2: High-Level Print API | 1-2 weeks | High | Templates, progress, cancellation (20+ tests) |
| Phase 3: Image Preparation Pipeline | 1-2 weeks | High | Preprocessing, sizing, annotation (30+ tests) |
| Phase 4: Advanced Features | 1-2 weeks | Medium | Queue, multiple printers, recovery (30+ tests) |
| Phase 5: Documentation and Examples | 1 week | High | Guides, CLI tool, examples |

**Total**: 8-10 weeks, 120+ unit tests, 20+ integration tests

## Success Criteria

### Functional Requirements

✅ Create film session with all parameters  
✅ Create film box with any standard layout  
✅ Set image box content with pixel data  
✅ Print film box and retrieve print job UID  
✅ Monitor print job status  
✅ Delete film session on completion  
✅ Print single image with defaults  
✅ Print multiple images with automatic layout  
✅ Use print templates for common scenarios  
✅ Report progress during printing  
✅ Support cancellation  

### Non-Functional Requirements

✅ Single image print <5 seconds  
✅ Multi-image print >10 images/minute  
✅ Image preprocessing <500ms  
✅ No crashes or memory leaks  
✅ Graceful error handling  
✅ Works with DCM4CHEE and Orthanc  
✅ Complete API documentation  
✅ User guides and tutorials  

## Next Steps

1. **Review** the comprehensive plan: [DICOM_PRINTER_PLAN.md](DICOM_PRINTER_PLAN.md)
2. **Prioritize** phases based on project needs
3. **Set up** test environment with DCM4CHEE or Orthanc
4. **Begin** Phase 1 implementation
5. **Test** with real DICOM print SCPs

## Questions or Feedback?

For detailed implementation guidance, architecture decisions, API specifications, and comprehensive technical details, please refer to the full plan document: **[DICOM_PRINTER_PLAN.md](DICOM_PRINTER_PLAN.md)**

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-13  
**Author**: DICOMKit Team
