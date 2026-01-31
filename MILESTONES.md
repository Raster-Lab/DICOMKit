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

**Status**: Completed  
**Goal**: Establish the foundational networking layer for DICOM communication  
**Complexity**: Medium  
**Dependencies**: None

#### Deliverables
- [x] TCP socket abstraction layer using Swift NIO or Foundation networking
- [x] Protocol Data Unit (PDU) type definitions:
  - [x] A-ASSOCIATE-RQ (Associate Request)
  - [x] A-ASSOCIATE-AC (Associate Accept)
  - [x] A-ASSOCIATE-RJ (Associate Reject)
  - [x] A-RELEASE-RQ (Release Request)
  - [x] A-RELEASE-RP (Release Response)
  - [x] A-ABORT (Abort)
  - [x] P-DATA-TF (Data Transfer)
- [x] PDU encoding/decoding (serialization)
- [x] Presentation Context definition structures
- [x] Abstract Syntax and Transfer Syntax negotiation types
- [x] Basic error types for networking (`DICOMNetworkError`)
- [x] Async/await foundation for network operations

#### Technical Notes
- Reference: PS3.8 Section 9 - Protocol Data Units
- Reference: PS3.8 Annex B - DICOM Upper Layer Protocol for TCP/IP
- Maximum PDU size handling (default 16KB, configurable)
- Byte order handling for network transmission (Big Endian for PDU headers)

#### Acceptance Criteria
- [x] PDU structures can be encoded to and decoded from binary data
- [x] PDU round-trip tests pass (encode → decode → compare)
- [x] Unit tests cover all PDU types
- [x] Documentation for core networking types

---

### Milestone 6.2: Association Management (v0.6.2)

**Status**: Completed  
**Goal**: Implement DICOM Association establishment and release  
**Complexity**: Medium-High  
**Dependencies**: Milestone 6.1

#### Deliverables
- [x] `Association` class/struct for managing connection state
- [x] Association establishment (A-ASSOCIATE):
  - [x] Build A-ASSOCIATE-RQ with Application Context
  - [x] Send A-ASSOCIATE-RQ and receive A-ASSOCIATE-AC/RJ
  - [x] Parse A-ASSOCIATE-AC for accepted contexts
  - [x] Handle A-ASSOCIATE-RJ with reason codes
- [x] Association release (A-RELEASE):
  - [x] Send A-RELEASE-RQ
  - [x] Receive A-RELEASE-RP
  - [x] Graceful connection cleanup
- [x] Association abort (A-ABORT):
  - [x] Handle unexpected disconnections
  - [x] Send A-ABORT when needed
  - [x] Process received A-ABORT with source/reason
- [x] Application Entity (AE) Title handling (16-character validation)
- [x] Presentation Context negotiation:
  - [x] Propose abstract syntaxes (SOP Classes)
  - [x] Propose transfer syntaxes
  - [x] Accept/reject context handling
- [x] Association state machine (Idle, Awaiting Response, Established, Released)
- [x] Timeouts for association operations (configurable ARTIM timer)

#### Technical Notes
- Reference: PS3.8 Section 7 - DICOM Upper Layer Service
- Reference: PS3.8 Section 9.3 - A-ASSOCIATE Service
- Reference: PS3.7 Section D - Association Negotiation
- Called/Calling AE Title configuration
- Implementation Class UID and Version Name

#### Acceptance Criteria
- [ ] Successfully establish association with a DICOM SCP (test server)
- [x] Graceful release and cleanup of associations
- [x] Proper handling of rejected associations with descriptive errors
- [x] Association timeout handling works correctly
- [x] Unit tests for association state machine

---

### Milestone 6.3: DICOM Message Exchange - DIMSE (v0.6.3)

**Status**: Completed  
**Goal**: Implement DIMSE (DICOM Message Service Element) protocol  
**Complexity**: High  
**Dependencies**: Milestone 6.2

#### Deliverables
- [x] DIMSE message structure definitions:
  - [x] Command Set encoding/decoding
  - [x] Data Set transmission/reception
- [x] DIMSE-C operations base types:
  - [x] C-STORE (request/response structures)
  - [x] C-FIND (request/response structures)
  - [x] C-GET (request/response structures)
  - [x] C-MOVE (request/response structures)
  - [x] C-ECHO (request/response structures)
- [x] Message fragmentation for P-DATA-TF PDUs
- [x] Presentation Data Value (PDV) handling:
  - [x] Message Control Header (Command/Dataset, Last/Not-Last)
  - [x] PDV assembly from fragments
  - [x] PDV disassembly for large datasets
- [x] Command Set field definitions:
  - [x] Affected/Requested SOP Class UID
  - [x] Message ID / Message ID Being Responded To
  - [x] Priority (LOW, MEDIUM, HIGH)
  - [x] Status codes (Success, Pending, Warning, Failure)
  - [x] Data Set Type (present/absent)
- [x] Status code definitions and handling (0x0000, 0xFF00, 0xFF01, etc.)

#### Technical Notes
- Reference: PS3.7 Section 7 - DIMSE-C Services
- Reference: PS3.7 Section 9 - DIMSE-C Service Protocol
- Reference: PS3.7 Annex E - Command Dictionary
- Command Set uses Implicit VR Little Endian encoding
- Presentation Context ID selection for commands

#### Acceptance Criteria
- [x] DIMSE command messages can be constructed and parsed
- [x] Large datasets are properly fragmented across PDVs
- [x] Status codes are correctly interpreted
- [x] Unit tests for message encoding/decoding
- [ ] Integration tests with mock server (deferred to Milestone 6.4)

---

### Milestone 6.4: Verification Service - C-ECHO (v0.6.4)

**Status**: Completed  
**Goal**: Implement the DICOM Verification Service (ping/echo)  
**Complexity**: Low  
**Dependencies**: Milestone 6.3

#### Deliverables
- [x] C-ECHO SCU implementation:
  - [x] Send C-ECHO-RQ to remote SCP
  - [x] Receive and validate C-ECHO-RSP
  - [x] Handle success/failure status
- [x] `DICOMVerificationService` high-level API:
  - [x] `func verify(host: String, port: Int, callingAE: String, calledAE: String) async throws -> Bool`
  - [x] Timeout configuration
  - [ ] Retry logic (optional) - deferred to advanced networking milestone
- [x] Verification SOP Class UID (1.2.840.10008.1.1) constant
- [x] Common transfer syntax UID constants
- [x] `VerificationResult` struct with detailed response info
- [x] `VerificationConfiguration` for customizable settings

#### Technical Notes
- Reference: PS3.4 Annex A - Verification Service Class
- Reference: PS3.7 Section 9.1.5 - C-ECHO Service
- Simplest DIMSE operation - ideal for testing connectivity
- No data set transferred, command only

#### Acceptance Criteria
- [ ] Successfully C-ECHO against public DICOM test servers (requires network access)
- [x] Proper error handling for connection failures
- [x] Timeout behavior works correctly (via association timeout)
- [x] Async/await API is ergonomic and Swift-idiomatic
- [x] Example code demonstrates usage (in module documentation)
- [x] Unit tests for verification service components

---

### Milestone 6.5: Query Services - C-FIND (v0.6.5)

**Status**: In Progress  
**Goal**: Implement DICOM Query services for finding studies, series, and instances  
**Complexity**: High  
**Dependencies**: Milestone 6.4

#### Deliverables
- [x] C-FIND SCU implementation:
  - [x] Build C-FIND-RQ with query keys
  - [x] Send request and receive multiple C-FIND-RSP
  - [x] Handle pending (0xFF00, 0xFF01) and success (0x0000) status
  - [x] Assemble query results from responses
- [x] Query/Retrieve Information Models:
  - [x] Patient Root Query/Retrieve Information Model - FIND (1.2.840.10008.5.1.4.1.2.1.1)
  - [x] Study Root Query/Retrieve Information Model - FIND (1.2.840.10008.5.1.4.1.2.2.1)
- [x] Query Levels:
  - [x] PATIENT level queries
  - [x] STUDY level queries
  - [x] SERIES level queries
  - [x] IMAGE (Instance) level queries
- [x] Query key builders for common attributes:
  - [x] Patient Name, Patient ID, Patient Birth Date
  - [x] Study Date, Study Time, Study Description, Study Instance UID, Accession Number
  - [x] Series Description, Series Instance UID, Modality
  - [x] SOP Instance UID, Instance Number
- [x] Wildcard matching support (*, ?)
- [x] Date/Time range queries (e.g., "20240101-20241231")
- [x] `DICOMQueryService` high-level API:
  - [x] `func findStudies(matching: QueryKeys) async throws -> [StudyResult]`
  - [x] `func findSeries(forStudy: String, matching: QueryKeys) async throws -> [SeriesResult]`
  - [x] `func findInstances(forSeries: String, matching: QueryKeys) async throws -> [InstanceResult]`
- [x] Query result data structures with type-safe accessors
- [ ] Query cancellation support (C-CANCEL) - deferred to advanced features

#### Technical Notes
- Reference: PS3.4 Annex C - Query/Retrieve Service Class
- Reference: PS3.4 Section C.4 - Query/Retrieve Information Model
- Reference: PS3.4 Annex C - Conformance Requirements
- Query results return as stream of pending responses followed by success
- Handle Sequence Matching for coded values

#### Acceptance Criteria
- [ ] Successfully query studies from PACS by patient name, date range (requires network access)
- [x] Query at all levels (Patient, Study, Series, Instance) works correctly
- [x] Wildcard queries return expected matches
- [x] Large result sets are handled efficiently (streaming)
- [ ] Query cancellation works correctly - deferred
- [ ] Integration tests with test PACS server (requires network access)

---

### Milestone 6.6: Retrieve Services - C-MOVE and C-GET (v0.6.6)

**Status**: Completed  
**Goal**: Implement DICOM Retrieve services for downloading images  
**Complexity**: Very High  
**Dependencies**: Milestone 6.5

#### Deliverables
- [x] C-MOVE SCU implementation:
  - [x] Build C-MOVE-RQ with retrieve keys and destination AE
  - [x] Send request and monitor C-MOVE-RSP status
  - [x] Handle sub-operation counts (Remaining, Completed, Failed, Warning)
  - [x] Support retrieve at Study, Series, and Instance level
- [x] C-GET SCU implementation:
  - [x] Build C-GET-RQ with retrieve keys
  - [x] Receive C-GET-RSP and associated C-STORE sub-operations
  - [x] Handle incoming C-STORE-RQ on same association
  - [x] Process sub-operation status
- [x] Query/Retrieve Information Models for Retrieve:
  - [x] Patient Root - MOVE (1.2.840.10008.5.1.4.1.2.1.2)
  - [x] Patient Root - GET (1.2.840.10008.5.1.4.1.2.1.3)
  - [x] Study Root - MOVE (1.2.840.10008.5.1.4.1.2.2.2)
  - [x] Study Root - GET (1.2.840.10008.5.1.4.1.2.2.3)
- [x] Storage SOP Class negotiation for C-GET (accept incoming C-STORE)
- [x] Move destination AE management for C-MOVE
- [x] Progress reporting during retrieval:
  - [x] `AsyncStream<RetrieveProgress>` for monitoring
  - [x] Completed/Remaining/Failed counts
  - [x] Individual instance callbacks
- [ ] Retrieve cancellation support (C-CANCEL) - deferred to advanced networking milestone
- [x] `DICOMRetrieveService` high-level API:
  - [x] `func moveStudy(...)` / `moveSeries(...)` / `moveInstance(...)` (C-MOVE)
  - [x] `func getStudy(...)` / `getSeries(...)` / `getInstance(...)` async streams (C-GET)
- [x] Downloaded file handling via async stream events

#### Technical Notes
- Reference: PS3.4 Annex C - Query/Retrieve Service Class (C.4.2 C-MOVE, C.4.3 C-GET)
- Reference: PS3.7 Section 9.1.4 - C-MOVE Service
- Reference: PS3.7 Section 9.1.3 - C-GET Service
- C-MOVE requires separate Store SCP listening for incoming connections
- C-GET receives files on same association (simpler, no SCP needed)
- Must negotiate Storage SOP Classes for C-GET to receive specific modalities
- Common Storage SOP Classes pre-configured for typical modalities

#### Acceptance Criteria
- [ ] Successfully retrieve studies via C-MOVE to local SCP (requires network access)
- [ ] Successfully retrieve studies via C-GET without separate SCP (requires network access)
- [x] Progress reporting accurately reflects sub-operation status
- [x] Large studies can be retrieved without memory issues (streaming API)
- [ ] Retrieve cancellation works correctly - deferred
- [x] Failed sub-operations are properly reported
- [ ] Integration tests with test PACS server (requires network access)

---

### Milestone 6.7: Advanced Networking Features (v0.6.7)

**Status**: In Progress  
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
- [x] Retry Logic:
  - [x] Configurable retry policies (`RetryPolicy` struct)
  - [x] Exponential backoff (`RetryPolicy.exponentialBackoff`)
  - [ ] Circuit breaker pattern for failing servers
- [ ] Network Error Handling:
  - [ ] Detailed error types with recovery suggestions
  - [ ] Timeout configuration (connect, read, write, operation)
  - [ ] Graceful degradation on partial failures
- [ ] Logging and Diagnostics:
  - [ ] PDU-level logging (configurable verbosity)
  - [ ] Association event logging
  - [ ] Performance metrics (latency, throughput)
- [x] `DICOMClient` unified high-level API:
  - [x] Configuration with server address, AE titles, TLS settings (`DICOMClientConfiguration`)
  - [x] Automatic association management (via existing services)
  - [x] Convenience methods for common workflows (verify, findStudies, findSeries, findInstances, moveStudy, moveSeries, moveInstance, getStudy, getSeries, getInstance)
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
- [x] Retry logic handles transient network failures
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

This milestone is divided into modular sub-milestones based on complexity, allowing for incremental development and testing. Each sub-milestone builds upon the networking infrastructure established in Milestone 6.

---

### Milestone 7.1: C-STORE SCU - Basic Storage (v0.7.1)

**Status**: Planned  
**Goal**: Implement sending DICOM files to remote storage destinations  
**Complexity**: Medium  
**Dependencies**: Milestone 6.2 (Association Management), Milestone 6.3 (DIMSE Protocol)

#### Deliverables
- [ ] C-STORE SCU implementation:
  - [ ] Build C-STORE-RQ with SOP Class/Instance UIDs
  - [ ] Send DICOM dataset as part of C-STORE operation
  - [ ] Receive and validate C-STORE-RSP
  - [ ] Handle success/failure/warning status codes
- [ ] Storage SOP Class support:
  - [ ] CT Image Storage (1.2.840.10008.5.1.4.1.1.2)
  - [ ] MR Image Storage (1.2.840.10008.5.1.4.1.1.4)
  - [ ] CR Image Storage (1.2.840.10008.5.1.4.1.1.1)
  - [ ] DX Image Storage (1.2.840.10008.5.1.4.1.1.1.1)
  - [ ] US Image Storage (1.2.840.10008.5.1.4.1.1.6.1)
  - [ ] Secondary Capture Image Storage (1.2.840.10008.5.1.4.1.1.7)
  - [ ] Enhanced CT/MR Image Storage
  - [ ] RT Structure Set, RT Plan, RT Dose Storage
  - [ ] Extensible SOP Class registry for custom modalities
- [ ] Transfer syntax negotiation for storage:
  - [ ] Negotiate appropriate transfer syntaxes for data
  - [ ] Handle accepted vs. proposed transfer syntax mismatches
  - [ ] Automatic transcoding when needed (optional)
- [ ] `DICOMStorageService` basic API:
  - [ ] `func store(file: DICOMFile, to host: String, port: Int, calledAE: String) async throws -> StoreResult`
  - [ ] `func store(dataset: DataSet, sopClassUID: String, to host: String, ...) async throws -> StoreResult`
- [ ] `StoreResult` struct with:
  - [ ] Status code and status category (Success, Warning, Failure)
  - [ ] Affected SOP Instance UID
  - [ ] Error details for failed operations

#### Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class
- Reference: PS3.7 Section 9.1.1 - C-STORE Service
- Reference: PS3.4 Annex B.5 - Standard SOP Classes
- Command Set uses Implicit VR Little Endian
- Priority field support (LOW, MEDIUM, HIGH)
- Move Originator AE Title and Message ID for C-MOVE initiated stores

#### Acceptance Criteria
- [ ] Successfully store single DICOM file to test SCP
- [ ] Correct handling of all C-STORE response status codes
- [ ] Proper transfer syntax negotiation
- [ ] Unit tests for C-STORE message construction and parsing
- [ ] Error handling for connection and protocol failures

---

### Milestone 7.2: Batch Storage Operations (v0.7.2)

**Status**: Planned  
**Goal**: Enable efficient batch transfer of multiple DICOM files  
**Complexity**: Medium-High  
**Dependencies**: Milestone 7.1

#### Deliverables
- [ ] Batch C-STORE implementation:
  - [ ] Send multiple files over single association
  - [ ] Negotiate all required SOP Classes in one association
  - [ ] Handle mixed SOP Class batches efficiently
- [ ] Progress reporting:
  - [ ] `AsyncStream<StorageProgress>` for monitoring batch transfers
  - [ ] Per-file success/failure tracking
  - [ ] Completed/Remaining/Failed counts
  - [ ] Bytes transferred tracking
  - [ ] Estimated time remaining
- [ ] Cancellation support:
  - [ ] Cancel ongoing batch transfer
  - [ ] Graceful association release on cancellation
  - [ ] Report partial completion status
- [ ] Batch configuration options:
  - [ ] Maximum concurrent associations (for multi-connection batches)
  - [ ] Retry count per file
  - [ ] Continue on error vs. fail fast modes
  - [ ] Rate limiting (files per second, bytes per second)
- [ ] `DICOMStorageService` batch API:
  - [ ] `func store(files: [DICOMFile], ...) -> AsyncThrowingStream<StorageProgress, Error>`
  - [ ] `func store(directory: URL, ...) -> AsyncThrowingStream<StorageProgress, Error>`
  - [ ] `func store(datasets: [DataSet], ...) -> AsyncThrowingStream<StorageProgress, Error>`
- [ ] `StorageProgress` struct with:
  - [ ] Current file info (SOP Instance UID, filename)
  - [ ] Overall progress (completed, remaining, failed)
  - [ ] Transfer statistics (bytes, rate)
  - [ ] Individual file results

#### Technical Notes
- Reference: PS3.7 Section 9.1.1.1 - C-STORE Operation
- Association reuse is critical for batch performance
- Consider parallel associations for very large batches
- Memory management for large file queues (streaming from disk)
- Handle association limits (some PACS limit operations per association)

#### Acceptance Criteria
- [ ] Successfully store batch of 100+ files efficiently
- [ ] Progress reporting is accurate and real-time
- [ ] Cancellation stops transfer promptly
- [ ] Partial failures are correctly reported
- [ ] Performance benchmarks show association reuse benefits
- [ ] Memory usage remains bounded for large batches

---

### Milestone 7.3: Storage SCP - Receiving Files (v0.7.3)

**Status**: Planned  
**Goal**: Implement Storage SCP to receive DICOM files from remote sources  
**Complexity**: High  
**Dependencies**: Milestone 6.2 (Association Management), Milestone 6.3 (DIMSE Protocol)

#### Deliverables
- [ ] Storage SCP server implementation:
  - [ ] Listen for incoming associations on configurable port
  - [ ] Accept/reject associations based on configuration
  - [ ] Process incoming C-STORE-RQ messages
  - [ ] Send appropriate C-STORE-RSP
- [ ] Association acceptance policies:
  - [ ] Whitelist/blacklist for calling AE Titles
  - [ ] Configurable accepted SOP Classes
  - [ ] Configurable accepted Transfer Syntaxes
  - [ ] Maximum concurrent associations limit
- [ ] C-STORE handling:
  - [ ] Receive and parse incoming datasets
  - [ ] Validate received data (optional)
  - [ ] Generate appropriate response status
  - [ ] Handle both implicit and explicit VR datasets
- [ ] File storage handlers:
  - [ ] `StorageDelegate` protocol for custom handling
  - [ ] Default file system storage implementation
  - [ ] Configurable file naming (by SOP Instance UID, Patient ID, etc.)
  - [ ] Directory organization (by Patient/Study/Series hierarchy)
- [ ] `DICOMStorageServer` API:
  - [ ] `init(port: Int, aeTitle: String, configuration: StorageSCPConfiguration)`
  - [ ] `func start() async throws`
  - [ ] `func stop() async`
  - [ ] `var receivedFiles: AsyncStream<ReceivedFile>`
- [ ] `StorageDelegate` protocol:
  - [ ] `func shouldAcceptAssociation(from: AssociationInfo) -> Bool`
  - [ ] `func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool`
  - [ ] `func didReceive(dataset: DataSet, from: AssociationInfo) async throws`
  - [ ] `func didFail(error: Error, for sopInstanceUID: String)`
- [ ] `ReceivedFile` struct with:
  - [ ] Source AE Title and connection info
  - [ ] SOP Class/Instance UIDs
  - [ ] Received DataSet
  - [ ] Timestamp
  - [ ] File path (if stored to disk)

#### Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class (SCP requirements)
- Reference: PS3.7 Section 9.1.1 - C-STORE SCP behavior
- SCP must validate Affected SOP Class UID against negotiated contexts
- Handle incomplete transfers gracefully (association abort)
- Consider disk space monitoring and alerts
- Thread-safe handling of concurrent associations

#### Acceptance Criteria
- [ ] Successfully receive files from C-STORE SCU
- [ ] Correctly handle multiple concurrent sending associations
- [ ] Association acceptance policies work correctly
- [ ] Files stored correctly with expected organization
- [ ] Delegate callbacks invoke at appropriate times
- [ ] Graceful handling of malformed data and aborted associations
- [ ] Unit tests for SCP message handling
- [ ] Integration tests with known SCU implementations

---

### Milestone 7.4: Storage Commitment Service (v0.7.4)

**Status**: Planned  
**Goal**: Implement Storage Commitment for reliable storage confirmation  
**Complexity**: High  
**Dependencies**: Milestone 7.1 (C-STORE SCU), Milestone 7.3 (Storage SCP)

#### Deliverables
- [ ] Storage Commitment SCU implementation:
  - [ ] N-ACTION-RQ for requesting storage commitment
  - [ ] Build Transaction UID and Referenced SOP Sequence
  - [ ] Handle N-ACTION-RSP
  - [ ] Receive N-EVENT-REPORT with commitment results
- [ ] Storage Commitment SCP implementation:
  - [ ] Accept N-ACTION-RQ for commitment requests
  - [ ] Process commitment requests against stored instances
  - [ ] Send N-EVENT-REPORT with commitment results
  - [ ] Handle both success and failure references
- [ ] Commitment request handling:
  - [ ] Storage Commitment Push Model SOP Class (1.2.840.10008.1.20.1)
  - [ ] Referenced SOP Sequence building
  - [ ] Transaction UID generation and tracking
- [ ] Commitment result processing:
  - [ ] Success (0000) - all instances committed
  - [ ] Partial success - some instances committed
  - [ ] Failure - commitment could not be processed
  - [ ] Referenced SOP Sequence in results
  - [ ] Failed SOP Sequence with failure reasons
- [ ] Asynchronous commitment workflow:
  - [ ] Request commitment and continue processing
  - [ ] Receive commitment notification (N-EVENT-REPORT)
  - [ ] Timeout handling for delayed commitments
  - [ ] Retry logic for failed commitment requests
- [ ] `StorageCommitmentService` API:
  - [ ] `func requestCommitment(for instances: [SOPReference], from server: ...) async throws -> CommitmentRequest`
  - [ ] `func waitForCommitment(request: CommitmentRequest, timeout: Duration) async throws -> CommitmentResult`
  - [ ] `var commitmentNotifications: AsyncStream<CommitmentResult>`
- [ ] `CommitmentResult` struct with:
  - [ ] Transaction UID
  - [ ] Committed instances list
  - [ ] Failed instances with reasons
  - [ ] Timestamp

#### Technical Notes
- Reference: PS3.4 Annex J - Storage Commitment Service Class
- Reference: PS3.7 Section 10.1 - N-ACTION Service
- Reference: PS3.7 Section 10.3 - N-EVENT-REPORT Service
- Commitment may be returned immediately or asynchronously
- SCP may send N-EVENT-REPORT on new association
- Handle both Push Model (SCU initiates) and Pull Model (deprecated)
- Track pending commitments with Transaction UIDs

#### Acceptance Criteria
- [ ] Successfully request and receive storage commitment
- [ ] Handle asynchronous commitment notifications
- [ ] Correctly parse commitment results (success/failure)
- [ ] SCP correctly processes commitment requests
- [ ] Timeout handling works for delayed commitments
- [ ] Unit tests for N-ACTION and N-EVENT-REPORT handling
- [ ] Integration tests with PACS supporting storage commitment

---

### Milestone 7.5: Advanced Storage Features (v0.7.5)

**Status**: Planned  
**Goal**: Production-ready storage with advanced features and reliability  
**Complexity**: High  
**Dependencies**: Milestone 7.2, Milestone 7.4

#### Deliverables
- [ ] Transfer Syntax Conversion:
  - [ ] Automatic transcoding when target doesn't support source syntax
  - [ ] Configurable preferred transfer syntaxes
  - [ ] Compression/decompression during transfer
  - [ ] Maintain pixel data fidelity flags
- [ ] Intelligent Retry Logic:
  - [ ] Configurable retry policies per SOP Class
  - [ ] Exponential backoff with jitter
  - [ ] Separate retry queues for transient vs. permanent failures
  - [ ] Dead letter queue for undeliverable files
- [ ] Store-and-Forward:
  - [ ] Queue files for later delivery
  - [ ] Persistent queue (survives app restart)
  - [ ] Automatic retry on connectivity restoration
  - [ ] Queue management API (pause, resume, clear)
- [ ] Compression Optimization:
  - [ ] On-the-fly compression for network efficiency
  - [ ] Configurable compression level vs. speed tradeoff
  - [ ] Support for JPEG, JPEG 2000, JPEG-LS compression
- [ ] Bandwidth Management:
  - [ ] Rate limiting per connection
  - [ ] Bandwidth scheduling (e.g., off-peak transfers)
  - [ ] Priority queues for urgent transfers
- [ ] Enhanced Error Handling:
  - [ ] Detailed error codes with recovery suggestions
  - [ ] Association-level vs. file-level error differentiation
  - [ ] Automatic reconnection after transient failures
- [ ] Audit Logging:
  - [ ] Detailed transfer logs (source, destination, timestamps)
  - [ ] Integration with system logging (OSLog)
  - [ ] Configurable log retention
- [ ] `DICOMStorageClient` unified API:
  - [ ] Configuration with server pool, retry policies, queue settings
  - [ ] Automatic server selection (round-robin, priority)
  - [ ] Unified store interface with automatic retry
- [ ] Validation before send:
  - [ ] Schema validation against IOD
  - [ ] Required attribute checking
  - [ ] UID validation
  - [ ] Configurable validation strictness

#### Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class
- Reference: PS3.5 for Transfer Syntax specifications
- Consider using SQLite or similar for persistent queuing
- Bandwidth management via token bucket algorithm
- Audit logs should support DICOM Audit Trail (IHE ATNA) format
- Transcoding requires access to pixel data codecs from Milestone 4

#### Acceptance Criteria
- [ ] Transfer syntax conversion works correctly
- [ ] Retry logic handles transient failures without data loss
- [ ] Store-and-forward delivers queued files after reconnection
- [ ] Bandwidth limits are respected
- [ ] Audit logs capture all transfer events
- [ ] Performance is acceptable for high-volume workflows
- [ ] No data corruption during transcoding
- [ ] Integration tests with various PACS systems

---

### Milestone 7 Summary

| Sub-Milestone | Version | Complexity | Key Deliverables |
|--------------|---------|------------|------------------|
| 7.1 C-STORE SCU | v0.7.1 | Medium | Basic storage send, SOP Class support |
| 7.2 Batch Storage | v0.7.2 | Medium-High | Batch transfers, progress, cancellation |
| 7.3 Storage SCP | v0.7.3 | High | Receive files, storage delegate, server API |
| 7.4 Storage Commitment | v0.7.4 | High | N-ACTION/N-EVENT-REPORT, commitment workflow |
| 7.5 Advanced Features | v0.7.5 | High | Transcoding, retry, store-and-forward, audit |

### Overall Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class
- Reference: PS3.4 Annex J - Storage Commitment Service Class
- Reference: PS3.7 - Message Exchange (C-STORE, N-ACTION, N-EVENT-REPORT)
- Build on networking infrastructure from Milestone 6
- Support both SCU and SCP roles
- All APIs use Swift concurrency (async/await, AsyncStream)
- Consider memory efficiency for large file transfers

### Overall Acceptance Criteria
- Successfully store to major PACS systems
- Reliable delivery with storage commitment
- Support for both SCU and SCP roles
- Production-ready reliability features
- Performance acceptable for clinical workflows

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
