# DICOMKit Milestone Plan

This document outlines the development roadmap for DICOMKit, a pure Swift DICOM toolkit for Apple platforms.

## Overview

DICOMKit aims to provide a comprehensive, Swift-native implementation for working with DICOM medical imaging files. The development is structured in phases, each building upon the previous to deliver incremental value while maintaining stability and quality.

---

## Milestone 1: Core Infrastructure (v0.1) ✅ COMPLETED

**Status**: Released  
**Goal**: Establish the foundation with read-only DICOM file parsing

### Deliverables
- [x] Project structure with Swift Package Manager
- [x] Core data types (`Tag`, `VR`, `DataElement`, `SequenceItem`)
- [x] DICOM value type parsers:
  - [x] `DICOMDate` (DA)
  - [x] `DICOMTime` (TM)
  - [x] `DICOMDateTime` (DT)
  - [x] `DICOMAgeString` (AS)
  - [x] `DICOMCodeString` (CS)
  - [x] `DICOMDecimalString` (DS)
  - [x] `DICOMIntegerString` (IS)
  - [x] `DICOMPersonName` (PN)
  - [x] `DICOMUniqueIdentifier` (UI)
  - [x] `DICOMApplicationEntity` (AE)
- [x] Transfer Syntax support:
  - [x] Explicit VR Little Endian (1.2.840.10008.1.2.1)
  - [x] Implicit VR Little Endian (1.2.840.10008.1.2)
- [x] Sequence (SQ) parsing with nested data sets
- [x] File Meta Information parsing
- [x] Data Element Dictionary (essential tags)
- [x] UID Dictionary (common UIDs)
- [x] Swift 6 strict concurrency support
- [x] Unit test suite

---

## Milestone 2: Extended Transfer Syntax Support (v0.2)

**Status**: Completed  
**Goal**: Support additional transfer syntaxes for broader file compatibility

### Deliverables
- [x] Explicit VR Big Endian (1.2.840.10008.1.2.2)
- [x] Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99)
- [x] Transfer syntax detection and automatic handling
- [x] Byte order abstraction layer
- [x] Extended test coverage with various transfer syntax files

### Technical Notes
- Implement `ByteOrder` protocol for endianness handling
- Add compression/decompression support using Foundation's `Data` compression APIs
- Reference: PS3.5 Section 10 - Transfer Syntax

### Acceptance Criteria
- All supported transfer syntaxes pass conformance tests
- No performance regression for Little Endian parsing
- Documentation updated with transfer syntax support matrix

---

## Milestone 3: Pixel Data Access (v0.3)

**Status**: Completed  
**Goal**: Enable access to uncompressed pixel data for image rendering

### Deliverables
- [x] Uncompressed pixel data extraction
- [x] Support for common photometric interpretations:
  - [x] MONOCHROME1
  - [x] MONOCHROME2
  - [x] RGB
  - [x] PALETTE COLOR
- [x] Pixel data metadata parsing:
  - [x] Rows, Columns
  - [x] Bits Allocated, Bits Stored, High Bit
  - [x] Pixel Representation
  - [x] Samples Per Pixel
  - [x] Planar Configuration
- [x] Multi-frame image support
- [x] Basic windowing (Window Center/Width)
- [x] `CGImage` creation for display on Apple platforms

### Technical Notes
- Reference: PS3.5 Section 8 - Native or Encapsulated Format Encoding
- Reference: PS3.3 C.7.6.3 - Image Pixel Module
- Reference: PS3.3 C.7.6.3.1.5 - Palette Color Lookup Table Module
- CGImage rendering available only on Apple platforms (iOS, macOS, visionOS)

### Acceptance Criteria
- Successfully extract and display CT, MR, and X-ray images
- Memory-efficient handling of large images
- Support for 8-bit, 12-bit, and 16-bit images

---

## Milestone 4: Compressed Pixel Data (v0.4)

**Status**: Completed  
**Goal**: Support common compressed image formats

### Deliverables
- [x] JPEG Baseline (Process 1) - 1.2.840.10008.1.2.4.50
- [x] JPEG Extended (Process 2 & 4) - 1.2.840.10008.1.2.4.51
- [x] JPEG Lossless - 1.2.840.10008.1.2.4.57
- [x] JPEG Lossless SV1 (Process 14, Selection Value 1) - 1.2.840.10008.1.2.4.70
- [x] JPEG 2000 Image Compression (Lossless Only) - 1.2.840.10008.1.2.4.90
- [x] JPEG 2000 Image Compression - 1.2.840.10008.1.2.4.91
- [x] RLE Lossless - 1.2.840.10008.1.2.5
- [x] Encapsulated pixel data parsing (fragments, offset table)
- [x] Codec plugin architecture for extensibility

### Technical Notes
- Leverages Apple platform codecs via ImageIO framework
- Pure Swift RLE codec implementation per DICOM PS3.5 Annex G
- Reference: PS3.5 Annex A - Transfer Syntax Specifications

### Acceptance Criteria
- Successfully decode all listed compression formats
- Graceful fallback for unsupported codecs
- Performance benchmarks against other DICOM toolkits

---

## Milestone 5: DICOM Writing (v0.5)

**Status**: Completed  
**Goal**: Enable creation and modification of DICOM files

### Deliverables
- [x] Create new DICOM files from scratch
- [x] Modify existing DICOM files
- [x] File Meta Information generation
- [x] UID generation utilities
- [x] Data element serialization for all VRs
- [x] Sequence writing support
- [ ] Character set handling (ISO IR 100, UTF-8) (UTF-8 only, deferred extended character sets)
- [x] Value padding per DICOM specification
- [ ] Transfer syntax conversion (deferred to future version)

### Technical Notes
- Reference: PS3.5 Section 7.1 - Data Element Encoding Rules
- Reference: PS3.10 Section 7.1 - DICOM File Meta Information
- Implemented setter methods on DataSet for convenient element creation
- Implemented DICOMWriter for serialization with byte order control
- Implemented UIDGenerator for creating unique DICOM identifiers

### Acceptance Criteria
- [x] Round-trip test: read → write → read produces identical data
- [x] Generated files pass DICOM parsing validation
- [x] Support for anonymization use cases (via element modification/removal)

---

## Milestone 6: DICOM Networking - Query/Retrieve (v0.6)

**Status**: Planned  
**Goal**: Implement DICOM network operations for finding and retrieving studies

### Deliverables
- [ ] Association establishment (A-ASSOCIATE)
- [ ] Association release (A-RELEASE)
- [ ] C-ECHO (verification)
- [ ] C-FIND (Study Root, Patient Root, Study/Patient levels)
- [ ] C-MOVE (retrieve to AE)
- [ ] C-GET (retrieve to self)
- [ ] Query response pagination
- [ ] Async/await API for network operations
- [ ] Connection pooling
- [ ] TLS support

### Technical Notes
- Reference: PS3.7 - Message Exchange
- Reference: PS3.8 - Network Communication Support
- Use Swift NIO or Foundation networking
- Implement SCU (Service Class User) role

### Acceptance Criteria
- Successfully query and retrieve from major PACS vendors
- Proper handling of network errors and timeouts
- Secure communication with TLS

---

## Milestone 7: DICOM Networking - Storage (v0.7)

**Status**: Planned  
**Goal**: Enable sending DICOM files to PACS and other receivers

### Deliverables
- [ ] C-STORE (send images)
- [ ] Storage Commitment (N-ACTION, N-EVENT-REPORT)
- [ ] Batch transfer support
- [ ] Progress reporting and cancellation
- [ ] Retry logic for failed transfers
- [ ] Storage SCP (receiver) implementation

### Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class
- Reference: PS3.4 Annex J - Storage Commitment Service Class

### Acceptance Criteria
- Successfully store to major PACS systems
- Reliable delivery with storage commitment
- Support for both SCU and SCP roles

---

## Milestone 8: DICOM Web Services (v0.8)

**Status**: Planned  
**Goal**: Implement RESTful DICOM web services (DICOMweb)

### Deliverables
- [ ] WADO-RS (Web Access to DICOM Objects - RESTful Services)
- [ ] STOW-RS (Store Over the Web - RESTful Services)
- [ ] QIDO-RS (Query based on ID for DICOM Objects - RESTful)
- [ ] UPS-RS (Unified Procedure Step - RESTful Services)
- [ ] Multipart MIME handling
- [ ] JSON metadata support (bulk data)
- [ ] Thumbnail generation
- [ ] OAuth2/OpenID Connect authentication

### Technical Notes
- Reference: PS3.18 - Web Services
- Build on URLSession for HTTP
- Support both client and server modes

### Acceptance Criteria
- Compatibility with OHIF viewer and other DICOMweb clients
- Pass DICOMweb conformance tests
- Performance optimized for web delivery

---

## Milestone 9: Structured Reporting (v0.9)

**Status**: Planned  
**Goal**: Full support for DICOM Structured Reporting

### Deliverables
- [ ] SR document parsing
- [ ] Content Item tree navigation
- [ ] Template support (TID parsing)
- [ ] Coded terminology handling (SNOMED, LOINC, RadLex)
- [ ] Measurement extraction
- [ ] SR document creation
- [ ] Common SR templates:
  - [ ] Basic Text SR
  - [ ] Enhanced SR
  - [ ] Comprehensive SR
  - [ ] Mammography CAD SR
  - [ ] Chest CAD SR
  - [ ] Measurement Report

### Technical Notes
- Reference: PS3.3 Part 3 - Information Object Definitions (Section C.17)
- Reference: PS3.16 - Content Mapping Resource

### Acceptance Criteria
- Parse and create compliant SR documents
- Support for measurement extraction in radiology workflows
- Integration with AI/ML output pipelines

---

## Milestone 10: Advanced Features (v1.0)

**Status**: Planned  
**Goal**: Production-ready release with comprehensive feature set

### Deliverables
- [ ] Presentation State support (GSPS, CSPS)
- [ ] Hanging Protocol support
- [ ] DICOM-RT (Radiation Therapy) basic support
- [ ] Segmentation objects (SEG)
- [ ] Parametric maps
- [ ] Real-world value mapping (RWV LUT)
- [ ] ICC profile color management
- [ ] Extended character set support (all ISO 2022 escapes)
- [ ] Private tag handling improvements
- [ ] Performance optimizations
- [ ] Comprehensive documentation
- [ ] Example applications

### Technical Notes
- Reference: PS3.3 for all Information Object Definitions
- Consider Metal compute shaders for image processing

### Acceptance Criteria
- Feature parity with major DICOM toolkits for common use cases
- Production deployment validation
- Performance benchmarks published

---

## Future Considerations (Post v1.0)

These features may be considered for future development based on community needs:

### Enhanced Imaging Support
- DICOM Encapsulated PDF
- Video playback (MPEG2, MPEG4, HEVC)
- 3D rendering and MPR reconstruction
- Volume rendering integration

### Enterprise Features  
- Worklist Management (MWL)
- Modality Performed Procedure Step (MPPS)
- Instance Availability Notification
- Relevant Patient Information Query
- Print Management (DICOM Print)

### Platform Extensions
- watchOS support (limited feature set)
- tvOS support
- SwiftUI components library
- Combine/AsyncSequence publishers

### Interoperability
- HL7 FHIR integration
- IHE profile support (XDS, PIX/PDQ)
- Cloud storage integration (AWS, Azure, GCP)

---

## Release Cadence

- **Minor releases** (0.x): Every 2-3 months with new features
- **Patch releases** (0.x.y): As needed for bug fixes
- **Major release** (1.0): When production-ready feature set is complete

## Contributing

We welcome contributions at any milestone! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Priority areas are noted in each milestone's deliverables.

## Version Compatibility

| Swift Version | Minimum OS Support |
|---------------|-------------------|
| Swift 6.2+ | iOS 17, macOS 14, visionOS 1 |

---

*This roadmap is subject to change based on community feedback and project priorities. Last updated: January 2026*
