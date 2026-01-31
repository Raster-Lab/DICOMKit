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

This milestone is divided into modular sub-milestones based on complexity, allowing for incremental development and testing. Each sub-milestone builds upon previous ones.

---

### Milestone 6.1: Core Networking Infrastructure (v0.6.1)

**Status**: Planned  
**Goal**: Establish the foundational networking layer for DICOM communication  
**Complexity**: Medium  
**Dependencies**: None

#### Deliverables
- [ ] TCP socket abstraction layer using Swift NIO or Foundation networking
- [ ] Protocol Data Unit (PDU) type definitions:
  - [ ] A-ASSOCIATE-RQ (Associate Request)
  - [ ] A-ASSOCIATE-AC (Associate Accept)
  - [ ] A-ASSOCIATE-RJ (Associate Reject)
  - [ ] A-RELEASE-RQ (Release Request)
  - [ ] A-RELEASE-RP (Release Response)
  - [ ] A-ABORT (Abort)
  - [ ] P-DATA-TF (Data Transfer)
- [ ] PDU encoding/decoding (serialization)
- [ ] Presentation Context definition structures
- [ ] Abstract Syntax and Transfer Syntax negotiation types
- [ ] Basic error types for networking (`DICOMNetworkError`)
- [ ] Async/await foundation for network operations

#### Technical Notes
- Reference: PS3.8 Section 9 - Protocol Data Units
- Reference: PS3.8 Annex B - DICOM Upper Layer Protocol for TCP/IP
- Maximum PDU size handling (default 16KB, configurable)
- Byte order handling for network transmission (Big Endian for PDU headers)

#### Acceptance Criteria
- [ ] PDU structures can be encoded to and decoded from binary data
- [ ] PDU round-trip tests pass (encode → decode → compare)
- [ ] Unit tests cover all PDU types
- [ ] Documentation for core networking types

---

### Milestone 6.2: Association Management (v0.6.2)

**Status**: Planned  
**Goal**: Implement DICOM Association establishment and release  
**Complexity**: Medium-High  
**Dependencies**: Milestone 6.1

#### Deliverables
- [ ] `Association` class/struct for managing connection state
- [ ] Association establishment (A-ASSOCIATE):
  - [ ] Build A-ASSOCIATE-RQ with Application Context
  - [ ] Send A-ASSOCIATE-RQ and receive A-ASSOCIATE-AC/RJ
  - [ ] Parse A-ASSOCIATE-AC for accepted contexts
  - [ ] Handle A-ASSOCIATE-RJ with reason codes
- [ ] Association release (A-RELEASE):
  - [ ] Send A-RELEASE-RQ
  - [ ] Receive A-RELEASE-RP
  - [ ] Graceful connection cleanup
- [ ] Association abort (A-ABORT):
  - [ ] Handle unexpected disconnections
  - [ ] Send A-ABORT when needed
  - [ ] Process received A-ABORT with source/reason
- [ ] Application Entity (AE) Title handling (16-character validation)
- [ ] Presentation Context negotiation:
  - [ ] Propose abstract syntaxes (SOP Classes)
  - [ ] Propose transfer syntaxes
  - [ ] Accept/reject context handling
- [ ] Association state machine (Idle, Awaiting Response, Established, Released)
- [ ] Timeouts for association operations (configurable ARTIM timer)

#### Technical Notes
- Reference: PS3.8 Section 7 - DICOM Upper Layer Service
- Reference: PS3.8 Section 9.3 - A-ASSOCIATE Service
- Reference: PS3.7 Section D - Association Negotiation
- Called/Calling AE Title configuration
- Implementation Class UID and Version Name

#### Acceptance Criteria
- [ ] Successfully establish association with a DICOM SCP (test server)
- [ ] Graceful release and cleanup of associations
- [ ] Proper handling of rejected associations with descriptive errors
- [ ] Association timeout handling works correctly
- [ ] Unit tests for association state machine

---

### Milestone 6.3: DICOM Message Exchange - DIMSE (v0.6.3)

**Status**: Planned  
**Goal**: Implement DIMSE (DICOM Message Service Element) protocol  
**Complexity**: High  
**Dependencies**: Milestone 6.2

#### Deliverables
- [ ] DIMSE message structure definitions:
  - [ ] Command Set encoding/decoding
  - [ ] Data Set transmission/reception
- [ ] DIMSE-C operations base types:
  - [ ] C-STORE (request/response structures)
  - [ ] C-FIND (request/response structures)
  - [ ] C-GET (request/response structures)
  - [ ] C-MOVE (request/response structures)
  - [ ] C-ECHO (request/response structures)
- [ ] Message fragmentation for P-DATA-TF PDUs
- [ ] Presentation Data Value (PDV) handling:
  - [ ] Message Control Header (Command/Dataset, Last/Not-Last)
  - [ ] PDV assembly from fragments
  - [ ] PDV disassembly for large datasets
- [ ] Command Set field definitions:
  - [ ] Affected/Requested SOP Class UID
  - [ ] Message ID / Message ID Being Responded To
  - [ ] Priority (LOW, MEDIUM, HIGH)
  - [ ] Status codes (Success, Pending, Warning, Failure)
  - [ ] Data Set Type (present/absent)
- [ ] Status code definitions and handling (0x0000, 0xFF00, 0xFF01, etc.)

#### Technical Notes
- Reference: PS3.7 Section 7 - DIMSE-C Services
- Reference: PS3.7 Section 9 - DIMSE-C Service Protocol
- Reference: PS3.7 Annex E - Command Dictionary
- Command Set uses Implicit VR Little Endian encoding
- Presentation Context ID selection for commands

#### Acceptance Criteria
- [ ] DIMSE command messages can be constructed and parsed
- [ ] Large datasets are properly fragmented across PDVs
- [ ] Status codes are correctly interpreted
- [ ] Unit tests for message encoding/decoding
- [ ] Integration tests with mock server

---

### Milestone 6.4: Verification Service - C-ECHO (v0.6.4)

**Status**: Planned  
**Goal**: Implement the DICOM Verification Service (ping/echo)  
**Complexity**: Low  
**Dependencies**: Milestone 6.3

#### Deliverables
- [ ] C-ECHO SCU implementation:
  - [ ] Send C-ECHO-RQ to remote SCP
  - [ ] Receive and validate C-ECHO-RSP
  - [ ] Handle success/failure status
- [ ] `DICOMVerificationService` high-level API:
  - [ ] `func verify(host: String, port: Int, callingAE: String, calledAE: String) async throws -> Bool`
  - [ ] Timeout configuration
  - [ ] Retry logic (optional)
- [ ] Verification SOP Class UID (1.2.840.10008.1.1) registration
- [ ] Network connectivity diagnostics

#### Technical Notes
- Reference: PS3.4 Annex A - Verification Service Class
- Reference: PS3.7 Section 9.1.5 - C-ECHO Service
- Simplest DIMSE operation - ideal for testing connectivity
- No data set transferred, command only

#### Acceptance Criteria
- [ ] Successfully C-ECHO against public DICOM test servers
- [ ] Proper error handling for connection failures
- [ ] Timeout behavior works correctly
- [ ] Async/await API is ergonomic and Swift-idiomatic
- [ ] Example code demonstrates usage

---

### Milestone 6.5: Query Services - C-FIND (v0.6.5)

**Status**: Planned  
**Goal**: Implement DICOM Query services for finding studies, series, and instances  
**Complexity**: High  
**Dependencies**: Milestone 6.4

#### Deliverables
- [ ] C-FIND SCU implementation:
  - [ ] Build C-FIND-RQ with query keys
  - [ ] Send request and receive multiple C-FIND-RSP
  - [ ] Handle pending (0xFF00, 0xFF01) and success (0x0000) status
  - [ ] Assemble query results from responses
- [ ] Query/Retrieve Information Models:
  - [ ] Patient Root Query/Retrieve Information Model - FIND (1.2.840.10008.5.1.4.1.2.1.1)
  - [ ] Study Root Query/Retrieve Information Model - FIND (1.2.840.10008.5.1.4.1.2.2.1)
- [ ] Query Levels:
  - [ ] PATIENT level queries
  - [ ] STUDY level queries
  - [ ] SERIES level queries
  - [ ] IMAGE (Instance) level queries
- [ ] Query key builders for common attributes:
  - [ ] Patient Name, Patient ID, Patient Birth Date
  - [ ] Study Date, Study Time, Study Description, Study Instance UID, Accession Number
  - [ ] Series Description, Series Instance UID, Modality
  - [ ] SOP Instance UID, Instance Number
- [ ] Wildcard matching support (*, ?)
- [ ] Date/Time range queries (e.g., "20240101-20241231")
- [ ] `DICOMQueryService` high-level API:
  - [ ] `func findStudies(matching: QueryKeys) async throws -> [StudyResult]`
  - [ ] `func findSeries(forStudy: String, matching: QueryKeys) async throws -> [SeriesResult]`
  - [ ] `func findInstances(forSeries: String, matching: QueryKeys) async throws -> [InstanceResult]`
- [ ] Query result data structures with type-safe accessors
- [ ] Query cancellation support (C-CANCEL)

#### Technical Notes
- Reference: PS3.4 Annex C - Query/Retrieve Service Class
- Reference: PS3.4 Section C.4 - Query/Retrieve Information Model
- Reference: PS3.4 Annex C - Conformance Requirements
- Query results return as stream of pending responses followed by success
- Handle Sequence Matching for coded values

#### Acceptance Criteria
- [ ] Successfully query studies from PACS by patient name, date range
- [ ] Query at all levels (Patient, Study, Series, Instance) works correctly
- [ ] Wildcard queries return expected matches
- [ ] Large result sets are handled efficiently (streaming)
- [ ] Query cancellation works correctly
- [ ] Integration tests with test PACS server

---

### Milestone 6.6: Retrieve Services - C-MOVE and C-GET (v0.6.6)

**Status**: Planned  
**Goal**: Implement DICOM Retrieve services for downloading images  
**Complexity**: Very High  
**Dependencies**: Milestone 6.5

#### Deliverables
- [ ] C-MOVE SCU implementation:
  - [ ] Build C-MOVE-RQ with retrieve keys and destination AE
  - [ ] Send request and monitor C-MOVE-RSP status
  - [ ] Handle sub-operation counts (Remaining, Completed, Failed, Warning)
  - [ ] Support retrieve at Study, Series, and Instance level
- [ ] C-GET SCU implementation:
  - [ ] Build C-GET-RQ with retrieve keys
  - [ ] Receive C-GET-RSP and associated C-STORE sub-operations
  - [ ] Handle incoming C-STORE-RQ on same association
  - [ ] Process sub-operation status
- [ ] Query/Retrieve Information Models for Retrieve:
  - [ ] Patient Root - MOVE (1.2.840.10008.5.1.4.1.2.1.2)
  - [ ] Patient Root - GET (1.2.840.10008.5.1.4.1.2.1.3)
  - [ ] Study Root - MOVE (1.2.840.10008.5.1.4.1.2.2.2)
  - [ ] Study Root - GET (1.2.840.10008.5.1.4.1.2.2.3)
- [ ] Storage SOP Class negotiation for C-GET (accept incoming C-STORE)
- [ ] Move destination AE management for C-MOVE
- [ ] Progress reporting during retrieval:
  - [ ] `AsyncStream<RetrieveProgress>` for monitoring
  - [ ] Completed/Remaining/Failed counts
  - [ ] Individual instance callbacks
- [ ] Retrieve cancellation support (C-CANCEL)
- [ ] `DICOMRetrieveService` high-level API:
  - [ ] `func retrieveStudy(uid: String, to: AETitle) async throws -> RetrieveResult` (C-MOVE)
  - [ ] `func downloadStudy(uid: String) async throws -> AsyncStream<DICOMFile>` (C-GET)
  - [ ] `func retrieveSeries(studyUID: String, seriesUID: String, ...) async throws`
  - [ ] `func retrieveInstance(studyUID: String, seriesUID: String, instanceUID: String, ...) async throws`
- [ ] Downloaded file handling (memory or disk storage options)

#### Technical Notes
- Reference: PS3.4 Annex C - Query/Retrieve Service Class (C.4.2 C-MOVE, C.4.3 C-GET)
- Reference: PS3.7 Section 9.1.4 - C-MOVE Service
- Reference: PS3.7 Section 9.1.3 - C-GET Service
- C-MOVE requires separate Store SCP listening for incoming connections
- C-GET receives files on same association (simpler, no SCP needed)
- Must negotiate Storage SOP Classes for C-GET to receive specific modalities

#### Acceptance Criteria
- [ ] Successfully retrieve studies via C-MOVE to local SCP
- [ ] Successfully retrieve studies via C-GET without separate SCP
- [ ] Progress reporting accurately reflects sub-operation status
- [ ] Large studies (1000+ images) can be retrieved without memory issues
- [ ] Retrieve cancellation works correctly
- [ ] Failed sub-operations are properly reported
- [ ] Integration tests with test PACS server

---

### Milestone 6.7: Advanced Networking Features (v0.6.7)

**Status**: Planned  
**Goal**: Production-ready networking with security and reliability features  
**Complexity**: High  
**Dependencies**: Milestone 6.6

#### Deliverables
- [ ] TLS Support:
  - [ ] TLS 1.2/1.3 encryption for DICOM connections
  - [ ] Certificate validation (system trust store)
  - [ ] Custom certificate/key configuration
  - [ ] Self-signed certificate handling (development mode)
- [ ] Connection Pooling:
  - [ ] Reuse associations for multiple operations
  - [ ] Pool size configuration
  - [ ] Idle connection timeout and cleanup
  - [ ] Connection health checks (periodic C-ECHO)
- [ ] Retry Logic:
  - [ ] Configurable retry policies
  - [ ] Exponential backoff
  - [ ] Circuit breaker pattern for failing servers
- [ ] Network Error Handling:
  - [ ] Detailed error types with recovery suggestions
  - [ ] Timeout configuration (connect, read, write, operation)
  - [ ] Graceful degradation on partial failures
- [ ] Logging and Diagnostics:
  - [ ] PDU-level logging (configurable verbosity)
  - [ ] Association event logging
  - [ ] Performance metrics (latency, throughput)
- [ ] `DICOMClient` unified high-level API:
  - [ ] Configuration with server address, AE titles, TLS settings
  - [ ] Automatic association management
  - [ ] Convenience methods for common workflows
- [ ] User Identity Negotiation (username/password, Kerberos)

#### Technical Notes
- Reference: PS3.15 - Security and System Management Profiles
- Reference: PS3.8 Annex A - DICOM Secure Transport Connection Profile
- TLS implementation via Network.framework or SwiftNIO SSL
- Connection pooling requires careful association state management
- User identity per DICOM Supplement 99

#### Acceptance Criteria
- [ ] TLS connections work with hospital/enterprise PACS
- [ ] Connection pooling reduces latency for batch operations
- [ ] Retry logic handles transient network failures
- [ ] Performance is acceptable for production use
- [ ] Security scan passes (no vulnerabilities)
- [ ] Documentation covers security configuration

---

### Milestone 6 Summary

| Sub-Milestone | Version | Complexity | Key Deliverables |
|--------------|---------|------------|------------------|
| 6.1 Core Infrastructure | v0.6.1 | Medium | PDU types, TCP layer, async foundation |
| 6.2 Association Management | v0.6.2 | Medium-High | A-ASSOCIATE, A-RELEASE, state machine |
| 6.3 DIMSE Protocol | v0.6.3 | High | Command/Data sets, fragmentation, status codes |
| 6.4 C-ECHO | v0.6.4 | Low | Verification service, connectivity testing |
| 6.5 C-FIND | v0.6.5 | High | Query services, all levels, wildcards |
| 6.6 C-MOVE/C-GET | v0.6.6 | Very High | Retrieve services, progress, cancellation |
| 6.7 Advanced Features | v0.6.7 | High | TLS, pooling, retry, production readiness |

### Overall Technical Notes
- Reference: PS3.7 - Message Exchange
- Reference: PS3.8 - Network Communication Support
- Use Swift NIO or Foundation networking
- Implement SCU (Service Class User) role
- All APIs use Swift concurrency (async/await)

### Overall Acceptance Criteria
- Successfully query and retrieve from major PACS vendors
- Proper handling of network errors and timeouts
- Secure communication with TLS
- Production-ready reliability features

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
