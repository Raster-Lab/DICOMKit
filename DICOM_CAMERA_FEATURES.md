# DICOM Camera Application Features

This document lists all the features available in DICOMKit that can be used to build a DICOM Camera Application for Apple platforms (iOS, macOS, visionOS).

## Table of Contents

- [Core DICOM File Operations](#core-dicom-file-operations)
- [Medical Image Processing](#medical-image-processing)
- [DICOM Networking (PACS Connectivity)](#dicom-networking-pacs-connectivity)
- [Data Types and Value Representations](#data-types-and-value-representations)
- [Platform Support](#platform-support)

---

## Core DICOM File Operations

### File Reading
- ✅ Read DICOM Part 10 files from Data or file URL
- ✅ Parse File Meta Information header
- ✅ Extract transfer syntax information
- ✅ Access all standard DICOM data elements
- ✅ Support for multiple transfer syntaxes:
  - Explicit VR Little Endian
  - Implicit VR Little Endian
  - Explicit VR Big Endian (Retired)
  - Deflated Explicit VR Little Endian

### File Writing
- ✅ Create new DICOM files from scratch
- ✅ Modify existing DICOM files
- ✅ Auto-generate File Meta Information
- ✅ Serialize data elements for all Value Representations (VRs)
- ✅ Write sequence (SQ) data with nested items
- ✅ Proper value padding per DICOM specification
- ✅ Round-trip read → write → read support

### UID Generation
- ✅ Generate unique Study Instance UIDs
- ✅ Generate unique Series Instance UIDs
- ✅ Generate unique SOP Instance UIDs
- ✅ Generate custom UIDs with organizational root

---

## Medical Image Processing

### Pixel Data Extraction
- ✅ Extract uncompressed pixel data
- ✅ Support for encapsulated (compressed) pixel data
- ✅ Fragment and offset table parsing
- ✅ Multi-frame image support (CT, MR, and other multi-slice images)
- ✅ Access individual pixel values by row/column
- ✅ Get pixel value ranges for normalization

### Compressed Image Formats
- ✅ JPEG Baseline (Process 1) - Lossy
- ✅ JPEG Extended (Process 2 & 4) - Lossy
- ✅ JPEG Lossless (Process 14)
- ✅ JPEG Lossless SV1 (Process 14, Selection Value 1)
- ✅ JPEG 2000 Lossless
- ✅ JPEG 2000 Lossy
- ✅ RLE Lossless compression
- ✅ Extensible codec architecture for custom formats

### Photometric Interpretations
- ✅ MONOCHROME1 (minimum pixel = white)
- ✅ MONOCHROME2 (minimum pixel = black)
- ✅ RGB color images
- ✅ PALETTE COLOR with lookup tables
- ✅ YBR color spaces (YBR_FULL, YBR_FULL_422, etc.)

### Image Rendering
- ✅ Render DICOM images to CGImage (Apple platforms)
- ✅ Window/Level (VOI LUT) transformations
- ✅ Custom window center/width settings
- ✅ Use stored window settings from DICOM file
- ✅ Automatic windowing based on pixel statistics
- ✅ Multiple window presets support
- ✅ Rescale slope/intercept transformations (Hounsfield Units for CT)
- ✅ Palette color lookup table rendering

---

## DICOM Networking (PACS Connectivity)

### Connection Management
- ✅ Unified DICOMClient API with connection pooling
- ✅ Configurable timeout settings
- ✅ Retry policies:
  - No retry
  - Fixed delay retry
  - Exponential backoff (recommended for production)
- ✅ Application Entity (AE) Title configuration

### C-ECHO Verification
- ✅ Test connectivity to PACS servers
- ✅ Verify DICOM Association establishment
- ✅ Network availability checking

### C-FIND Query Service
- ✅ Query for patients, studies, series, and instances
- ✅ Patient Root Query/Retrieve Information Model
- ✅ Study Root Query/Retrieve Information Model
- ✅ Query levels: PATIENT, STUDY, SERIES, IMAGE
- ✅ Wildcard matching (*, ?)
- ✅ Date/Time range queries
- ✅ Filter by modality, patient name, study date, etc.
- ✅ Request additional fields in results
- ✅ Type-safe query result data structures:
  - `StudyResult` - Study-level query results
  - `SeriesResult` - Series-level query results
  - `InstanceResult` - Instance-level query results

### C-MOVE Retrieve Service
- ✅ Move studies from PACS to destination AE
- ✅ Move individual series
- ✅ Move individual instances
- ✅ Progress reporting with sub-operation counts
- ✅ Partial failure handling

### C-GET Retrieve Service
- ✅ Download studies directly on same association
- ✅ Download series directly
- ✅ Download individual instances
- ✅ AsyncStream-based event streaming:
  - Progress updates
  - Instance data reception
  - Completion notification
  - Error handling
- ✅ No separate Storage SCP required

### C-STORE Storage Service
- ✅ Send DICOM files to remote PACS destinations
- ✅ Support for common Storage SOP Classes (CT, MR, CR, DX, US, SC, RT)
- ✅ Transfer syntax negotiation
- ✅ Priority support (LOW, MEDIUM, HIGH)
- ✅ Detailed store result with status codes
- ✅ Integration with DICOMClient unified API

### Query Builder API
- ✅ Fluent QueryKeys API for building queries
- ✅ Type-safe query parameter setting
- ✅ Support for all standard query attributes

---

## Data Types and Value Representations

### All 31 DICOM Value Representations
- ✅ AE - Application Entity
- ✅ AS - Age String
- ✅ AT - Attribute Tag
- ✅ CS - Code String
- ✅ DA - Date
- ✅ DS - Decimal String
- ✅ DT - Date Time
- ✅ FL - Floating Point Single
- ✅ FD - Floating Point Double
- ✅ IS - Integer String
- ✅ LO - Long String
- ✅ LT - Long Text
- ✅ OB - Other Byte
- ✅ OD - Other Double
- ✅ OF - Other Float
- ✅ OL - Other Long
- ✅ OV - Other 64-bit Very Long
- ✅ OW - Other Word
- ✅ PN - Person Name
- ✅ SH - Short String
- ✅ SL - Signed Long
- ✅ SQ - Sequence of Items
- ✅ SS - Signed Short
- ✅ ST - Short Text
- ✅ SV - Signed 64-bit Very Long
- ✅ TM - Time
- ✅ UC - Unlimited Characters
- ✅ UI - Unique Identifier
- ✅ UL - Unsigned Long
- ✅ UN - Unknown
- ✅ UR - Universal Resource Identifier
- ✅ US - Unsigned Short
- ✅ UT - Unlimited Text
- ✅ UV - Unsigned 64-bit Very Long

### Type-Safe Value Parsing
- ✅ `DICOMDate` - Parse and manipulate DA values
- ✅ `DICOMTime` - Parse and manipulate TM values
- ✅ `DICOMDateTime` - Parse and manipulate DT values
- ✅ `DICOMAgeString` - Parse age strings (e.g., "045Y")
- ✅ `DICOMPersonName` - Parse person names with components
- ✅ `DICOMDecimalString` - Parse numeric decimal values
- ✅ `DICOMIntegerString` - Parse integer values
- ✅ `DICOMCodeString` - Parse enumerated code values
- ✅ `DICOMUniqueIdentifier` - Parse and validate UIDs
- ✅ `DICOMApplicationEntity` - Parse AE titles
- ✅ `DICOMUniversalResource` - Parse URIs/URLs

### Data Element Access
- ✅ Access elements by Tag (group, element)
- ✅ Named tag constants for common elements
- ✅ Sequence (SQ) parsing with nested items
- ✅ Iterator support for data sets
- ✅ Setter methods for all data types

---

## Platform Support

### Apple Platforms
- ✅ iOS 17.0+
- ✅ macOS 14.0+
- ✅ visionOS 1.0+
- ✅ Apple Silicon optimized (M1, M2, M3, M4)

### Swift Features
- ✅ Swift 6.2+ with strict concurrency
- ✅ async/await API for networking
- ✅ AsyncStream for streaming results
- ✅ Value semantics with struct and enum
- ✅ Type-safe API design
- ✅ Full Sendable compliance

### Integration
- ✅ Swift Package Manager support
- ✅ Pure Swift implementation (no Objective-C)
- ✅ CGImage rendering for SwiftUI/UIKit/AppKit
- ✅ Foundation type conversions

---

## DICOM Standard Compliance

- ✅ DICOM PS3.5 2025e - Data Structures and Encoding
- ✅ DICOM PS3.6 2025e - Data Dictionary (essential tags)
- ✅ DICOM PS3.7 2025e - Message Exchange (DIMSE-C services)
- ✅ DICOM PS3.8 2025e - Network Communication Support
- ✅ DICOM PS3.10 2025e - Media Storage and File Format

---

## Tag Categories Supported

### Patient Information
- Patient Name, Patient ID, Patient Birth Date
- Patient Sex, Patient Age, Patient Weight
- Patient Comments, Other Patient IDs

### Study Information
- Study Instance UID, Study Date, Study Time
- Study Description, Accession Number
- Referring Physician Name, Study ID

### Series Information
- Series Instance UID, Series Number
- Series Description, Modality
- Body Part Examined, Patient Position

### Image Information
- SOP Instance UID, SOP Class UID
- Instance Number, Acquisition Number
- Image Type, Image Comments
- Content Date, Content Time

### Pixel Data Information
- Rows, Columns, Bits Allocated
- Bits Stored, High Bit, Pixel Representation
- Samples Per Pixel, Photometric Interpretation
- Planar Configuration, Pixel Spacing

### File Meta Information
- File Meta Information Group Length
- File Meta Information Version
- Media Storage SOP Class UID
- Media Storage SOP Instance UID
- Transfer Syntax UID
- Implementation Class UID
- Implementation Version Name
- Source Application Entity Title

### Modality-Specific Tags
- CT-specific attributes
- MR-specific attributes
- Structured Reporting elements
- Waveform data elements
- Overlay information

---

## Current Limitations

- ⚠️ Storage SCP not yet available (can send files but cannot receive files from remote sources)
- ❌ No character set conversion (UTF-8 only)

---

## Version History

| Version | Features Added |
|---------|---------------|
| v0.7 | DICOM Storage: C-STORE SCU |
| v0.6 | DICOM Networking: C-ECHO, C-FIND, C-MOVE, C-GET |
| v0.5 | DICOM File Writing, UID Generation |
| v0.4 | Compressed Pixel Data Support |
| v0.3 | Pixel Data Extraction, Image Rendering |
| v0.2 | Transfer Syntax Support, Sequence Parsing |
| v0.1 | Basic DICOM File Reading |

---

*This feature list is based on DICOMKit v0.7. For the latest development roadmap, see [MILESTONES.md](MILESTONES.md).*
