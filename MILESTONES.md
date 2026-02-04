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

**Status**: Completed  
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

**Status**: Completed  
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

**Status**: Completed  
**Goal**: Production-ready networking with security and reliability features  
**Complexity**: High  
**Dependencies**: Milestone 6.6

#### Deliverables
- [x] TLS Support:
  - [x] TLS 1.2/1.3 encryption for DICOM connections
  - [x] Certificate validation (system trust store)
  - [x] Custom certificate/key configuration
  - [x] Self-signed certificate handling (development mode)
- [x] Connection Pooling:
  - [x] Reuse associations for multiple operations
  - [x] Pool size configuration
  - [x] Idle connection timeout and cleanup
  - [x] Connection health checks (periodic C-ECHO)
- [x] Retry Logic:
  - [x] Configurable retry policies (`RetryPolicy` struct)
  - [x] Exponential backoff (`RetryPolicy.exponentialBackoff`)
  - [x] Circuit breaker pattern for failing servers
- [x] Network Error Handling:
  - [x] Detailed error types with recovery suggestions (`ErrorCategory`, `RecoverySuggestion`)
  - [x] Timeout configuration (connect, read, write, operation) (`TimeoutConfiguration`)
  - [x] Graceful degradation on partial failures (`partialFailure` error case)
- [x] Logging and Diagnostics:
  - [x] PDU-level logging (configurable verbosity)
  - [x] Association event logging
  - [x] Performance metrics (latency, throughput)
  - [x] `DICOMLogger` actor for centralized logging
  - [x] `DICOMLogLevel` (debug, info, warning, error)
  - [x] `DICOMLogCategory` for filtering by component
  - [x] `OSLogHandler` for Apple's Unified Logging System (Apple platforms)
  - [x] `ConsoleLogHandler` for console output
  - [x] Helper methods for common logging patterns
- [x] `DICOMClient` unified high-level API:
  - [x] Configuration with server address, AE titles, TLS settings (`DICOMClientConfiguration`)
  - [x] Automatic association management (via existing services)
  - [x] Convenience methods for common workflows (verify, findStudies, findSeries, findInstances, moveStudy, moveSeries, moveInstance, getStudy, getSeries, getInstance)
- [x] User Identity Negotiation (username/password, Kerberos)
  - [x] `UserIdentity` struct with multiple authentication types
  - [x] `UserIdentityType` enum (username, usernameAndPasscode, kerberos, saml, jwt)
  - [x] `UserIdentityServerResponse` for server acknowledgment
  - [x] PDU encoding/decoding for user identity sub-items (0x58, 0x59)
  - [x] Integration with AssociationConfiguration and all service configurations
  - [x] Unit tests for all user identity functionality

#### Technical Notes
- Reference: PS3.15 - Security and System Management Profiles
- Reference: PS3.8 Annex A - DICOM Secure Transport Connection Profile
- TLS implementation via Network.framework or SwiftNIO SSL
- Connection pooling requires careful association state management
- User identity per DICOM Supplement 99
- TLS configuration supports: default (TLS 1.2+), strict (TLS 1.3 only), insecure (development), and custom configurations
- Certificate pinning and custom trust roots supported for enterprise deployments
- Client certificate authentication (mTLS) supported via PKCS#12 or keychain

#### Acceptance Criteria
- [ ] TLS connections work with hospital/enterprise PACS (requires network testing)
- [ ] Connection pooling reduces latency for batch operations
- [x] Retry logic handles transient network failures
- [ ] Performance is acceptable for production use
- [ ] Security scan passes (no vulnerabilities)
- [x] Documentation covers security configuration

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

**Status**: In Progress  
**Goal**: Enable sending DICOM files to PACS and other receivers

This milestone is divided into modular sub-milestones based on complexity, allowing for incremental development and testing. Each sub-milestone builds upon the networking infrastructure established in Milestone 6.

---

### Milestone 7.1: C-STORE SCU - Basic Storage (v0.7.1)

**Status**: Completed  
**Goal**: Implement sending DICOM files to remote storage destinations  
**Complexity**: Medium  
**Dependencies**: Milestone 6.2 (Association Management), Milestone 6.3 (DIMSE Protocol)

#### Deliverables
- [x] C-STORE SCU implementation:
  - [x] Build C-STORE-RQ with SOP Class/Instance UIDs
  - [x] Send DICOM dataset as part of C-STORE operation
  - [x] Receive and validate C-STORE-RSP
  - [x] Handle success/failure/warning status codes
- [x] Storage SOP Class support:
  - [x] CT Image Storage (1.2.840.10008.5.1.4.1.1.2)
  - [x] MR Image Storage (1.2.840.10008.5.1.4.1.1.4)
  - [x] CR Image Storage (1.2.840.10008.5.1.4.1.1.1)
  - [x] DX Image Storage (1.2.840.10008.5.1.4.1.1.1.1)
  - [x] US Image Storage (1.2.840.10008.5.1.4.1.1.6.1)
  - [x] Secondary Capture Image Storage (1.2.840.10008.5.1.4.1.1.7)
  - [x] Enhanced CT/MR Image Storage
  - [x] RT Structure Set, RT Plan, RT Dose Storage
  - [x] Extensible SOP Class registry for custom modalities
- [x] Transfer syntax negotiation for storage:
  - [x] Negotiate appropriate transfer syntaxes for data
  - [x] Handle accepted vs. proposed transfer syntax mismatches
  - [ ] Automatic transcoding when needed (optional) - deferred
- [x] `DICOMStorageService` basic API:
  - [x] `func store(fileData: Data, to host: String, port: Int, calledAE: String) async throws -> StoreResult`
  - [x] `func store(dataSetData: Data, sopClassUID: String, to host: String, ...) async throws -> StoreResult`
- [x] `StoreResult` struct with:
  - [x] Status code and status category (Success, Warning, Failure)
  - [x] Affected SOP Instance UID
  - [x] Error details for failed operations
- [x] `DICOMClient` integration:
  - [x] `store(fileData:priority:)` method
  - [x] `store(dataSetData:sopClassUID:sopInstanceUID:...)` method

#### Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class
- Reference: PS3.7 Section 9.1.1 - C-STORE Service
- Reference: PS3.4 Annex B.5 - Standard SOP Classes
- Command Set uses Implicit VR Little Endian
- Priority field support (LOW, MEDIUM, HIGH)
- Move Originator AE Title and Message ID for C-MOVE initiated stores

#### Acceptance Criteria
- [ ] Successfully store single DICOM file to test SCP (requires network access)
- [x] Correct handling of all C-STORE response status codes
- [x] Proper transfer syntax negotiation
- [x] Unit tests for C-STORE message construction and parsing
- [x] Error handling for connection and protocol failures

---

### Milestone 7.2: Batch Storage Operations (v0.7.2)

**Status**: Completed  
**Goal**: Enable efficient batch transfer of multiple DICOM files  
**Complexity**: Medium-High  
**Dependencies**: Milestone 7.1

#### Deliverables
- [x] Batch C-STORE implementation:
  - [x] Send multiple files over single association
  - [x] Negotiate all required SOP Classes in one association
  - [x] Handle mixed SOP Class batches efficiently
- [x] Progress reporting:
  - [x] `AsyncThrowingStream<StorageProgressEvent, Error>` for monitoring batch transfers
  - [x] Per-file success/failure tracking (`FileStoreResult`)
  - [x] Completed/Remaining/Failed counts (`BatchStoreProgress`)
  - [x] Bytes transferred tracking
  - [ ] Estimated time remaining (deferred)
- [ ] Cancellation support:
  - [ ] Cancel ongoing batch transfer (deferred)
  - [x] Graceful association release on error/completion
  - [x] Report partial completion status
- [x] Batch configuration options:
  - [x] Maximum files per association (for association limits)
  - [ ] Retry count per file (deferred)
  - [x] Continue on error vs. fail fast modes (`BatchStorageConfiguration`)
  - [x] Rate limiting via delay between files
- [x] `DICOMStorageService` batch API:
  - [x] `func storeBatch(files: [Data], ...) -> AsyncThrowingStream<StorageProgressEvent, Error>`
  - [ ] `func store(directory: URL, ...) -> AsyncThrowingStream<StorageProgress, Error>` (deferred)
  - [ ] `func store(datasets: [DataSet], ...) -> AsyncThrowingStream<StorageProgress, Error>` (deferred)
- [x] `StorageProgressEvent` enum with:
  - [x] `.progress(BatchStoreProgress)` - Overall progress update
  - [x] `.fileResult(FileStoreResult)` - Individual file result
  - [x] `.completed(BatchStoreResult)` - Batch completion
  - [x] `.error(Error)` - Error event
- [x] `BatchStoreResult` struct with:
  - [x] Final progress counts
  - [x] Individual file results
  - [x] Total bytes transferred
  - [x] Total time and average transfer rate
- [x] `DICOMClient` integration:
  - [x] `storeBatch(files:priority:configuration:)` method

#### Technical Notes
- Reference: PS3.7 Section 9.1.1.1 - C-STORE Operation
- Association reuse is critical for batch performance
- Consider parallel associations for very large batches
- Memory management for large file queues (streaming from disk)
- Handle association limits (some PACS limit operations per association)

#### Acceptance Criteria
- [ ] Successfully store batch of 100+ files efficiently (requires network access)
- [x] Progress reporting is accurate and real-time
- [ ] Cancellation stops transfer promptly (deferred)
- [x] Partial failures are correctly reported
- [ ] Performance benchmarks show association reuse benefits (requires network access)
- [ ] Memory usage remains bounded for large batches

---

### Milestone 7.3: Storage SCP - Receiving Files (v0.7.3)

**Status**: Completed  
**Goal**: Implement Storage SCP to receive DICOM files from remote sources  
**Complexity**: High  
**Dependencies**: Milestone 6.2 (Association Management), Milestone 6.3 (DIMSE Protocol)

#### Deliverables
- [x] Storage SCP server implementation:
  - [x] Listen for incoming associations on configurable port
  - [x] Accept/reject associations based on configuration
  - [x] Process incoming C-STORE-RQ messages
  - [x] Send appropriate C-STORE-RSP
- [x] Association acceptance policies:
  - [x] Whitelist/blacklist for calling AE Titles
  - [x] Configurable accepted SOP Classes
  - [x] Configurable accepted Transfer Syntaxes
  - [x] Maximum concurrent associations limit
- [x] C-STORE handling:
  - [x] Receive and parse incoming datasets
  - [ ] Validate received data (optional) - deferred
  - [x] Generate appropriate response status
  - [x] Handle both implicit and explicit VR datasets
- [x] File storage handlers:
  - [x] `StorageDelegate` protocol for custom handling
  - [x] Default file system storage implementation
  - [ ] Configurable file naming (by SOP Instance UID, Patient ID, etc.) - basic implementation
  - [ ] Directory organization (by Patient/Study/Series hierarchy) - deferred
- [x] `DICOMStorageServer` API:
  - [x] `init(configuration: StorageSCPConfiguration, delegate: StorageDelegate)`
  - [x] `func start() async throws`
  - [x] `func stop() async`
  - [x] `var events: AsyncStream<StorageServerEvent>`
- [x] `StorageDelegate` protocol:
  - [x] `func shouldAcceptAssociation(from: AssociationInfo) -> Bool`
  - [x] `func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool`
  - [x] `func didReceive(file: ReceivedFile) async throws`
  - [x] `func didFail(error: Error, for sopInstanceUID: String)`
- [x] `ReceivedFile` struct with:
  - [x] Source AE Title and connection info
  - [x] SOP Class/Instance UIDs
  - [x] Received DataSet data
  - [x] Timestamp
  - [x] File path (if stored to disk)

#### Technical Notes
- Reference: PS3.4 Annex B - Storage Service Class (SCP requirements)
- Reference: PS3.7 Section 9.1.1 - C-STORE SCP behavior
- SCP must validate Affected SOP Class UID against negotiated contexts
- Handle incomplete transfers gracefully (association abort)
- Consider disk space monitoring and alerts
- Thread-safe handling of concurrent associations

#### Acceptance Criteria
- [ ] Successfully receive files from C-STORE SCU (requires network testing)
- [x] Correctly handle multiple concurrent sending associations
- [x] Association acceptance policies work correctly
- [ ] Files stored correctly with expected organization (requires integration testing)
- [x] Delegate callbacks invoke at appropriate times
- [x] Graceful handling of malformed data and aborted associations
- [x] Unit tests for SCP message handling
- [ ] Integration tests with known SCU implementations (requires network testing)

---

### Milestone 7.4: Storage Commitment Service (v0.7.4)

**Status**: In Progress  
**Goal**: Implement Storage Commitment for reliable storage confirmation  
**Complexity**: High  
**Dependencies**: Milestone 7.1 (C-STORE SCU), Milestone 7.3 (Storage SCP)

#### Deliverables
- [x] Storage Commitment SCU implementation:
  - [x] N-ACTION-RQ for requesting storage commitment
  - [x] Build Transaction UID and Referenced SOP Sequence
  - [x] Handle N-ACTION-RSP
  - [ ] Receive N-EVENT-REPORT with commitment results (requires SCP listener)
- [x] Storage Commitment SCP implementation:
  - [x] Accept N-ACTION-RQ for commitment requests
  - [x] Process commitment requests against stored instances
  - [x] Send N-EVENT-REPORT with commitment results
  - [x] Handle both success and failure references
- [x] Commitment request handling:
  - [x] Storage Commitment Push Model SOP Class (1.2.840.10008.1.20.1)
  - [x] Referenced SOP Sequence building
  - [x] Transaction UID generation and tracking
- [x] Commitment result processing:
  - [x] Success (0000) - all instances committed
  - [x] Partial success - some instances committed
  - [x] Failure - commitment could not be processed
  - [x] Referenced SOP Sequence in results
  - [x] Failed SOP Sequence with failure reasons
- [x] Asynchronous commitment workflow:
  - [x] Request commitment and continue processing
  - [x] Receive commitment notification (N-EVENT-REPORT) - via `CommitmentNotificationListener`
  - [x] Timeout handling for delayed commitments
  - [ ] Retry logic for failed commitment requests
- [x] `StorageCommitmentService` API:
  - [x] `func requestCommitment(for: [SOPReference], host:port:configuration:) async throws -> CommitmentRequest`
  - [x] `func parseCommitmentResult(eventTypeID:dataSet:remoteAETitle:) throws -> CommitmentResult`
  - [x] `func waitForCommitment(request: CommitmentRequest, timeout: Duration, listener:) async throws -> CommitmentResult`
- [x] `CommitmentResult` struct with:
  - [x] Transaction UID
  - [x] Committed instances list
  - [x] Failed instances with reasons
  - [x] Timestamp
- [x] N-ACTION DIMSE message types (NActionRequest, NActionResponse)
- [x] N-EVENT-REPORT DIMSE message types (NEventReportRequest, NEventReportResponse)
- [x] Command Set accessors for N-ACTION/N-EVENT-REPORT fields
- [x] `StorageCommitmentServer` SCP API:
  - [x] `StorageCommitmentSCPConfiguration` for SCP settings
  - [x] `StorageCommitmentDelegate` protocol for handling commitment requests
  - [x] `CommitmentRequestInfo` struct for received commitment requests
  - [x] `StorageCommitmentServerEvent` enum for monitoring SCP activity
  - [x] `DefaultCommitmentHandler` actor for default commitment handling
  - [x] `func start() async throws` and `func stop() async` for server lifecycle
  - [x] `var events: AsyncStream<StorageCommitmentServerEvent>` for event monitoring
- [x] `CommitmentNotificationListener` for receiving commitment results:
  - [x] `CommitmentNotificationListenerConfiguration` for listener settings
  - [x] `CommitmentNotificationListenerEvent` enum for monitoring activity
  - [x] `func start() async throws` and `func stop() async` for lifecycle
  - [x] `func waitForResult(transactionUID:timeout:) async throws -> CommitmentResult`
  - [x] Event stream for monitoring received results

#### Technical Notes
- Reference: PS3.4 Annex J - Storage Commitment Service Class
- Reference: PS3.7 Section 10.1 - N-ACTION Service
- Reference: PS3.7 Section 10.3 - N-EVENT-REPORT Service
- Commitment may be returned immediately or asynchronously
- SCP may send N-EVENT-REPORT on new association
- Handle both Push Model (SCU initiates) and Pull Model (deprecated)
- Track pending commitments with Transaction UIDs

#### Acceptance Criteria
- [ ] Successfully request and receive storage commitment (requires network access)
- [x] Handle asynchronous commitment notifications
- [x] Correctly parse commitment results (success/failure)
- [x] SCP correctly processes commitment requests
- [x] Timeout handling works for delayed commitments
- [x] Unit tests for N-ACTION and N-EVENT-REPORT handling
- [x] Unit tests for Storage Commitment SCP configuration and delegate
- [x] Unit tests for CommitmentNotificationListener configuration and events
- [ ] Integration tests with PACS supporting storage commitment (requires network access)

---

### Milestone 7.5: Advanced Storage Features (v0.7.5)

**Status**: In Progress  
**Goal**: Production-ready storage with advanced features and reliability  
**Complexity**: High  
**Dependencies**: Milestone 7.2, Milestone 7.4

#### Deliverables
- [x] Transfer Syntax Conversion:
  - [x] Automatic transcoding when target doesn't support source syntax
  - [x] Configurable preferred transfer syntaxes
  - [x] Compression/decompression during transfer (decompression supported)
  - [x] Maintain pixel data fidelity flags
- [x] Intelligent Retry Logic:
  - [x] Configurable retry policies per SOP Class
  - [x] Exponential backoff with jitter
  - [x] Separate handling of transient vs. permanent failures
  - [x] `RetryPolicy` struct with configurable parameters
  - [x] `RetryStrategy` enum (fixed, exponential, exponential with jitter, linear)
  - [x] `RetryExecutor` actor for executing operations with automatic retries
  - [x] `RetryContext` for monitoring retry progress
  - [x] `RetryResult` for detailed retry operation results
  - [x] `SOPClassRetryConfiguration` for per-SOP Class policies
  - [x] Integration with existing `ErrorCategory` and `CircuitBreaker`
  - [ ] Dead letter queue for undeliverable files (deferred to store-and-forward)
- [ ] Store-and-Forward:
  - [x] Queue files for later delivery
  - [x] Persistent queue (survives app restart)
  - [x] Automatic retry on connectivity restoration
  - [x] Queue management API (pause, resume, clear)
- [x] Compression Optimization:
  - [x] On-the-fly compression for network efficiency
  - [x] Configurable compression level vs. speed tradeoff
  - [x] Support for JPEG, JPEG 2000 compression (JPEG-LS not supported by ImageIO)
- [x] Bandwidth Management:
  - [x] Rate limiting per connection
  - [x] Bandwidth scheduling (e.g., off-peak transfers)
  - [x] Priority queues for urgent transfers
- [x] Enhanced Error Handling:
  - [x] Detailed error codes with recovery suggestions
  - [x] Association-level vs. file-level error differentiation
  - [x] Automatic reconnection after transient failures
  - [x] `ErrorLevel` enum for distinguishing association vs. operation errors
  - [x] `StorageError` struct for enhanced storage error context
  - [x] `ReconnectionConfiguration` for configurable reconnection behavior
  - [x] `ReconnectionState` for monitoring reconnection progress
  - [x] `ReconnectableOperation` actor for automatic reconnection
  - [x] Unit tests for enhanced error handling features
- [x] Audit Logging:
  - [x] Detailed transfer logs (source, destination, timestamps)
  - [x] Integration with system logging (OSLog)
  - [x] Configurable log retention
  - [x] IHE ATNA-aligned audit event types
  - [x] File-based audit logging with JSON Lines format
  - [x] Log rotation support
  - [x] Event type filtering
  - [x] Storage operation logging helpers
- [x] `DICOMStorageClient` unified API:
  - [x] Configuration with server pool, retry policies, queue settings
  - [x] Automatic server selection (round-robin, priority, weighted, random, failover)
  - [x] Unified store interface with automatic retry
  - [x] `ServerEntry` struct for server pool entries
  - [x] `ServerPool` struct for managing multiple servers
  - [x] `ServerSelectionStrategy` enum for server selection algorithms
  - [x] `DICOMStorageClientConfiguration` for client settings
  - [x] `StorageClientResult` for detailed operation results
  - [x] Circuit breaker integration for failure tracking
  - [x] Per-server circuit breakers
  - [x] Automatic server failover on failure
  - [x] Unit tests for DICOMStorageClient
- [x] Validation before send:
  - [ ] Schema validation against IOD (deferred to future version)
  - [x] Required attribute checking
  - [x] UID validation
  - [x] Configurable validation strictness
  - [x] `DICOMValidator` struct for validating DICOM data sets
  - [x] `ValidationConfiguration` for configurable validation behavior
  - [x] `ValidationResult` with errors and warnings
  - [x] `ValidationError` enum with detailed error types
  - [x] `ValidationLevel` enum (minimal, standard, strict)
  - [x] Allowed SOP Classes filtering
  - [x] Additional required tags configuration
  - [x] Pixel data attribute validation
  - [x] Transfer Syntax validation
  - [x] Unit tests for DICOMValidator

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

**Status**: In Progress  
**Goal**: Implement RESTful DICOM web services (DICOMweb)

This milestone implements the DICOMweb standard (PS3.18), providing modern RESTful HTTP/HTTPS-based access to DICOM objects. DICOMweb enables browser-based viewers, mobile applications, and cloud-native integrations without requiring traditional DICOM networking infrastructure.

This milestone is divided into modular sub-milestones based on complexity, allowing for incremental development and testing. Each sub-milestone builds upon previous ones.

---

### Milestone 8.1: Core DICOMweb Infrastructure (v0.8.1)

**Status**: Completed  
**Goal**: Establish the foundational HTTP layer and data format support for DICOMweb  
**Complexity**: Medium  
**Dependencies**: Milestone 5 (DICOM Writing)

#### Deliverables
- [x] HTTP client abstraction layer:
  - [x] `HTTPClient` protocol for pluggable backends
  - [x] `URLSessionHTTPClient` default implementation using URLSession
  - [x] Configurable timeouts (connect, read, resource)
  - [x] Request/response handling with headers
  - [ ] HTTP/2 support for connection multiplexing (platform dependent)
  - [ ] Request/response interceptors for logging (deferred to advanced features)
  - [ ] Automatic retry with configurable policies (deferred to advanced features)
- [x] DICOM JSON representation (PS3.18 Section F):
  - [x] `DICOMJSONEncoder` - DataSet to JSON serialization
  - [x] `DICOMJSONDecoder` - JSON to DataSet deserialization
  - [x] `BulkDataReference` - Bulk data URI handling
  - [x] InlineBinary encoding (Base64)
  - [x] Proper handling of all VR types in JSON
  - [x] PersonName JSON format (Alphabetic, Ideographic, Phonetic)
- [ ] DICOM XML representation (deferred to future milestone):
  - [ ] DataSet to XML serialization
  - [ ] XML to DataSet deserialization
- [x] Multipart MIME handling (PS3.18 Section 8):
  - [x] `MultipartMIME` - multipart/related parsing and generation
  - [x] `MultipartMIME.parse()` - boundary detection and handling
  - [x] Content-Type header parsing (type, boundary parameters)
  - [x] `MultipartMIME.Builder` - fluent API for construction
  - [x] Part factories for DICOM, DICOM JSON, bulk data
  - [x] Round-trip encoding/decoding support
  - [ ] Efficient streaming for large payloads (deferred)
  - [ ] Support for nested multipart content (deferred)
- [x] Media type definitions (`DICOMMediaType`):
  - [x] `application/dicom` - DICOM Part 10 files
  - [x] `application/dicom+json` - DICOM JSON
  - [x] `application/dicom+xml` - DICOM XML
  - [x] `application/octet-stream` - Bulk data
  - [x] `image/jpeg`, `image/png`, `image/gif` - Rendered frames
  - [x] `video/mpeg`, `video/mp4` - Video content
  - [x] `multipart/related` - Multipart MIME with boundary and type
  - [x] Media type parsing and generation
- [x] URL path construction utilities (`DICOMwebURLBuilder`):
  - [x] Study, Series, Instance URL building (WADO-RS)
  - [x] Search URL building (QIDO-RS)
  - [x] Frames and rendered URLs
  - [x] Bulk data URLs
  - [x] Metadata URLs
  - [x] Query parameter encoding
  - [x] URL template handling for server configuration
- [x] `DICOMwebError` error types:
  - [x] HTTP status code mapping (4xx, 5xx)
  - [x] DICOM-specific error conditions
  - [x] Error classification (transient, client, server)
  - [x] Retry-After header support
  - [x] Detailed error descriptions
- [x] `DICOMwebConfiguration` for client settings:
  - [x] Base URL configuration
  - [x] Authentication settings (basic, bearer, API key, custom)
  - [x] Default Accept/Content-Type headers
  - [x] Request timeout configuration
  - [x] Custom headers support
  - [x] URL builder integration

#### Technical Notes
- Reference: PS3.18 Section 6 - Media Types and Transfer Syntaxes
- Reference: PS3.18 Section 8 - Multipart MIME
- Reference: PS3.18 Section F - DICOM JSON Model
- JSON encoding must handle special VR types: PN, DA, TM, DT, IS, DS
- Bulk data can be inline (Base64) or referenced (URI)
- Consider memory-efficient streaming for large multipart responses

#### Acceptance Criteria
- [x] DICOM JSON serialization/deserialization is compliant with PS3.18
- [x] Multipart MIME parsing handles edge cases correctly
- [x] Round-trip tests: DataSet → JSON → DataSet produces identical data
- [x] Unit tests cover all media types and encoding scenarios (124 tests)
- [x] Documentation for core infrastructure types

---

### Milestone 8.2: WADO-RS Client - Retrieve Services (v0.8.2)

**Status**: Completed  
**Goal**: Implement DICOMweb retrieve client for fetching DICOM objects over HTTP  
**Complexity**: Medium-High  
**Dependencies**: Milestone 8.1

#### Deliverables
- [x] WADO-RS Study retrieval:
  - [x] `GET /studies/{StudyInstanceUID}` - Retrieve all instances in study
  - [x] Accept header negotiation (DICOM, JSON, XML, bulk data)
  - [x] Multipart response parsing for multiple instances
  - [x] Streaming download for large studies
- [x] WADO-RS Series retrieval:
  - [x] `GET /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}`
  - [x] Filter to single series within study
- [x] WADO-RS Instance retrieval:
  - [x] `GET /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}/instances/{SOPInstanceUID}`
  - [x] Single instance download
- [x] WADO-RS Metadata retrieval:
  - [x] `GET /studies/{StudyInstanceUID}/metadata` - Study metadata (JSON/XML)
  - [x] `GET .../series/{SeriesInstanceUID}/metadata` - Series metadata
  - [x] `GET .../instances/{SOPInstanceUID}/metadata` - Instance metadata
  - [x] Bulk data URI handling in metadata responses
- [x] WADO-RS Frames retrieval:
  - [x] `GET .../instances/{SOPInstanceUID}/frames/{FrameList}` - Specific frames
  - [x] Frame number list parsing (e.g., "1,3,5" or "1-10")
  - [x] Uncompressed frame data (raw pixels)
  - [x] Compressed frame data (JPEG, JPEG 2000, etc.)
- [x] WADO-RS Rendered retrieval (consumer-friendly formats):
  - [x] `GET .../instances/{SOPInstanceUID}/rendered` - Rendered image
  - [x] `GET .../frames/{FrameList}/rendered` - Rendered frames
  - [x] Query parameters: window, viewport, quality
  - [x] Accept: `image/jpeg`, `image/png`, `image/gif`
- [x] WADO-RS Thumbnail retrieval:
  - [x] `GET .../instances/{SOPInstanceUID}/thumbnail` - Thumbnail image
  - [x] `GET .../series/{SeriesInstanceUID}/thumbnail` - Series representative
  - [x] `GET /studies/{StudyInstanceUID}/thumbnail` - Study representative
  - [x] Configurable thumbnail size via viewport parameter
- [x] WADO-RS Bulk Data retrieval:
  - [x] `GET {BulkDataURI}` - Retrieve bulk data by URI
  - [x] Range header support for partial retrieval
  - [x] Accept header for format negotiation
- [x] Transfer syntax negotiation:
  - [x] Accept header with transfer-syntax parameter
  - [x] Multiple transfer syntax preference via quality values
  - [x] Handle 406 Not Acceptable responses
- [x] `DICOMwebClient` retrieve API:
  - [x] `func retrieveStudy(studyUID: String) async throws -> RetrieveResult`
  - [x] `func retrieveStudyStream(studyUID: String) -> AsyncThrowingStream<Data, Error>`
  - [x] `func retrieveSeries(studyUID: String, seriesUID: String) async throws -> RetrieveResult`
  - [x] `func retrieveSeriesStream(...) -> AsyncThrowingStream<Data, Error>`
  - [x] `func retrieveInstance(...) async throws -> Data`
  - [x] `func retrieveStudyMetadata(studyUID: String) async throws -> [[String: Any]]`
  - [x] `func retrieveSeriesMetadata(...) async throws -> [[String: Any]]`
  - [x] `func retrieveInstanceMetadata(...) async throws -> [[String: Any]]`
  - [x] `func retrieveFrames(instanceUID: String, frames: [Int]) async throws -> [FrameResult]`
  - [x] `func retrieveFrame(...) async throws -> Data`
  - [x] `func retrieveRenderedInstance(..., options: RenderOptions) async throws -> Data`
  - [x] `func retrieveRenderedFrames(...) async throws -> [Data]`
  - [x] `func retrieveStudyThumbnail(studyUID: String, options: RenderOptions) async throws -> Data`
  - [x] `func retrieveSeriesThumbnail(...) async throws -> Data`
  - [x] `func retrieveInstanceThumbnail(...) async throws -> Data`
  - [x] `func retrieveBulkData(uri: String, range: Range<Int>?) async throws -> Data`
  - [x] `func retrieveAttributeBulkData(...) async throws -> Data`
- [x] Progress reporting for downloads:
  - [x] Bytes received / total bytes
  - [x] Instances received / total instances (when known)
- [x] Cancellation support via Swift Task cancellation

#### Technical Notes
- Reference: PS3.18 Section 10.4 - WADO-RS
- Reference: PS3.18 Section 8 - Multipart MIME encoding
- Reference: PS3.18 Section 9 - Accept Header
- WADO-RS returns multipart/related for multiple objects
- Rendered endpoint applies windowing and color transformations
- Frame numbers are 1-based per DICOM convention
- Consider disk caching for repeated requests

#### Acceptance Criteria
- [ ] Successfully retrieve studies from public DICOMweb servers (requires network access)
- [x] Multipart response parsing handles varying boundary formats
- [x] Transfer syntax negotiation selects optimal format
- [ ] Rendered images display correctly with windowing applied (requires network access)
- [ ] Thumbnail generation works at all levels (requires network access)
- [ ] Large study downloads don't cause memory issues (streaming) (requires network access)
- [x] Unit tests for URL construction and response parsing
- [ ] Integration tests with test DICOMweb servers (requires network access)

---

### Milestone 8.3: QIDO-RS Client - Query Services (v0.8.3)

**Status**: Completed  
**Goal**: Implement DICOMweb query client for searching DICOM objects  
**Complexity**: Medium-High  
**Dependencies**: Milestone 8.1

#### Deliverables
- [x] QIDO-RS Study queries:
  - [x] `GET /studies?{query}` - Search studies
  - [x] Standard query parameters: PatientName, PatientID, StudyDate, etc.
  - [x] Response as JSON array
- [x] QIDO-RS Series queries:
  - [x] `GET /studies/{StudyInstanceUID}/series?{query}` - Search series in study
  - [x] `GET /series?{query}` - Search series across all studies
  - [x] Series-level attributes: Modality, SeriesDescription, etc.
- [x] QIDO-RS Instance queries:
  - [x] `GET /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}/instances?{query}`
  - [x] `GET /studies/{StudyInstanceUID}/instances?{query}` - Instances in study
  - [x] `GET /instances?{query}` - Search instances across all
  - [x] Instance-level attributes: SOPClassUID, InstanceNumber, etc.
- [x] Query parameter support:
  - [x] Exact matching: `PatientID=12345`
  - [x] Wildcard matching: `PatientName=Smith*`
  - [x] Date range queries: `StudyDate=20240101-20241231`
  - [x] Time range queries: `StudyTime=080000-170000`
  - [x] UID matching: `StudyInstanceUID=1.2.3.4...`
  - [ ] Sequence matching (limited per PS3.18) - not implemented
- [x] Query attribute filtering:
  - [x] `includefield` parameter for requesting specific attributes
  - [x] `includefield=all` for all available attributes
  - [x] Default attributes per query level
- [x] Pagination support:
  - [x] `limit` - Maximum results to return
  - [x] `offset` - Starting position
  - [x] Response headers for total count (X-Total-Count if available)
  - [ ] Automatic pagination iteration - manual iteration supported
- [x] Fuzzy matching (optional server feature):
  - [x] `fuzzymatching=true` parameter
  - [x] Handle servers with/without fuzzy support
- [x] `DICOMwebClient` query API:
  - [x] `func searchStudies(query: QIDOQuery) async throws -> QIDOStudyResults`
  - [x] `func searchSeries(studyUID: String, query: QIDOQuery) async throws -> QIDOSeriesResults`
  - [x] `func searchAllSeries(query: QIDOQuery) async throws -> QIDOSeriesResults`
  - [x] `func searchInstances(studyUID: String, seriesUID: String, query: QIDOQuery) async throws -> QIDOInstanceResults`
  - [x] `func searchInstances(studyUID: String, query: QIDOQuery) async throws -> QIDOInstanceResults`
  - [x] `func searchAllInstances(query: QIDOQuery) async throws -> QIDOInstanceResults`
- [x] `QIDOQuery` builder:
  - [x] Fluent API for building queries
  - [x] Type-safe attribute setters
  - [x] Date/Time range builders
  - [x] Wildcard helpers (user provides pattern)
- [x] `QIDOResults` types:
  - [x] `QIDOStudyResults` with study-level attributes
  - [x] `QIDOSeriesResults` with series-level attributes
  - [x] `QIDOInstanceResults` with instance-level attributes
  - [x] Pagination info (hasMore, nextOffset)
  - [x] Type-safe attribute accessors

#### Technical Notes
- Reference: PS3.18 Section 10.6 - QIDO-RS
- Reference: PS3.18 Section 8 - Query Parameters
- QIDO-RS uses HTTP GET with query parameters
- Response typically JSON array of matching results
- Server may limit results; check X-Total-Count header
- Wildcard (*) matches any sequence of characters
- Date format: YYYYMMDD or YYYYMMDD-YYYYMMDD

#### Acceptance Criteria
- [ ] Successfully query studies from public DICOMweb servers (requires network access)
- [x] All query parameter types work correctly
- [x] Pagination handles large result sets
- [x] JSON response parsing extracts all attributes
- [x] Query builder produces valid URLs
- [ ] Integration tests with test DICOMweb servers (requires network access)

---

### Milestone 8.4: STOW-RS Client - Store Services (v0.8.4)

**Status**: Completed  
**Goal**: Implement DICOMweb store client for uploading DICOM objects  
**Complexity**: Medium  
**Dependencies**: Milestone 8.1

#### Deliverables
- [x] STOW-RS Study store:
  - [x] `POST /studies` - Store instances (auto-create study)
  - [x] `POST /studies/{StudyInstanceUID}` - Store to specific study
  - [x] Multipart request body for multiple instances
- [x] Content-Type handling:
  - [x] `multipart/related; type="application/dicom"` - DICOM Part 10 files
  - [ ] `multipart/related; type="application/dicom+json"` - JSON with bulk data (deferred)
  - [ ] `multipart/related; type="application/dicom+xml"` - XML with bulk data (deferred)
- [x] Request construction:
  - [x] Multipart boundary generation
  - [x] Part headers (Content-Type, Content-Location)
  - [x] Efficient body handling
- [x] Response handling:
  - [x] Parse STOW-RS response (JSON format)
  - [x] Success: 200 OK with stored instance references
  - [x] Partial success: 202 Accepted with warnings
  - [x] Failure: 4xx/5xx with error details
  - [x] Per-instance status from response
- [x] `STOWResponse` struct:
  - [x] Successfully stored instances (ReferencedSOPSequence)
  - [x] Failed instances (FailedSOPSequence) with reasons
  - [x] Warning messages
  - [x] Retrieve URL for stored instances
- [x] Batch store operations:
  - [x] Store multiple instances in single request
  - [x] Configurable batch size (for server limits)
  - [x] Progress reporting for batch uploads
- [x] `DICOMwebClient` store API:
  - [x] `func storeInstances(instances: [Data], studyUID: String?, options:) async throws -> STOWResponse`
  - [x] `func storeInstance(data: Data, studyUID: String?) async throws -> STOWResponse`
  - [x] `func storeInstancesWithProgress(instances:studyUID:options:) -> AsyncThrowingStream<StoreEvent, Error>`
- [x] Progress reporting:
  - [x] Instances stored / total instances
  - [x] Bytes uploaded / total bytes
  - [x] Per-batch progress for batch operations
- [x] Error handling:
  - [x] Request too large (413 status)
  - [x] Unsupported media type (415 status)
  - [x] Conflict (409 status) - instance already exists
  - [x] Continue-on-error option for batch uploads

#### Technical Notes
- Reference: PS3.18 Section 10.5 - STOW-RS
- Reference: PS3.18 Section 8 - Multipart MIME
- STOW-RS uses HTTP POST with multipart body
- Response contains SOP Instance references and status
- Batch size configurable to work within server limits
- Study UID in URL must match Study UID in instances

#### Acceptance Criteria
- [x] Successfully store single and batch instances
- [x] Multipart request generation is compliant
- [x] Response parsing extracts success/failure details
- [x] Batch uploads with configurable size
- [x] Progress reporting is accurate
- [ ] Integration tests with test DICOMweb servers (requires network access)

---

### Milestone 8.5: DICOMweb Server - WADO-RS/QIDO-RS (v0.8.5)

**Status**: Completed  
**Goal**: Implement DICOMweb server for serving DICOM objects over HTTP  
**Complexity**: High  
**Dependencies**: Milestone 8.1, Milestone 8.2, Milestone 8.3

#### Deliverables
- [x] HTTP server foundation:
  - [x] Request/response abstraction layer (DICOMwebRequest/DICOMwebResponse)
  - [x] Route registration for DICOMweb endpoints (DICOMwebRouter)
  - [x] Request parsing and response generation
  - [x] Async handler support
  - [ ] Built on SwiftNIO HTTP server or Vapor/Hummingbird (integration layer - deferred)
- [x] WADO-RS endpoints:
  - [x] `GET /studies/{studyUID}` - Retrieve study
  - [x] `GET /studies/{studyUID}/series/{seriesUID}` - Retrieve series
  - [x] `GET .../instances/{instanceUID}` - Retrieve instance
  - [x] `GET .../metadata` - Retrieve metadata (JSON)
  - [ ] `GET .../frames/{frames}` - Retrieve frames (stub - requires pixel processing)
  - [ ] `GET .../rendered` - Retrieve rendered image (stub - requires image processing)
  - [ ] `GET .../thumbnail` - Retrieve thumbnail (stub - requires image processing)
  - [ ] `GET {bulkDataURI}` - Retrieve bulk data (deferred)
- [x] QIDO-RS endpoints:
  - [x] `GET /studies` - Search studies
  - [x] `GET /studies/{studyUID}/series` - Search series
  - [x] `GET .../instances` - Search instances
  - [x] Query parameter parsing
  - [x] Pagination via limit/offset
- [x] Content negotiation:
  - [x] Parse Accept header
  - [x] Multipart DICOM response generation
  - [x] DICOM JSON metadata responses
  - [ ] Select best matching media type (deferred)
  - [ ] Return 406 Not Acceptable when no match (deferred)
- [x] Storage backend abstraction:
  - [x] `DICOMwebStorageProvider` protocol
  - [x] Methods for retrieve, query, store
  - [x] In-memory implementation (for testing)
  - [ ] File system implementation (deferred)
  - [ ] SQLite-backed index for queries (deferred)
- [ ] Image rendering pipeline (deferred to future version):
  - [ ] Window/level application
  - [ ] Viewport scaling
  - [ ] JPEG/PNG encoding
  - [ ] Thumbnail generation
  - [ ] Caching for rendered images
- [x] `DICOMwebServer` API:
  - [x] `init(configuration: DICOMwebServerConfiguration, storage: DICOMwebStorageProvider)`
  - [x] `func start() async throws`
  - [x] `func stop() async`
  - [x] `var port: Int { get }`
  - [x] `var baseURL: URL { get }`
  - [x] `func handleRequest(_:) async -> DICOMwebResponse`
- [x] `DICOMwebServerConfiguration`:
  - [x] Port and bind address
  - [x] Base URL path prefix
  - [x] TLS configuration
  - [x] CORS settings
  - [x] Rate limiting configuration
  - [x] Maximum request body size
  - [x] Server name
- [x] STOW-RS endpoints (bonus):
  - [x] `POST /studies` - Store instances
  - [x] `POST /studies/{studyUID}` - Store instances in study
- [x] Delete endpoints (bonus):
  - [x] `DELETE /studies/{studyUID}` - Delete study
  - [x] `DELETE .../series/{seriesUID}` - Delete series
  - [x] `DELETE .../instances/{instanceUID}` - Delete instance

#### Technical Notes
- Reference: PS3.18 Section 10.4 (WADO-RS), 10.6 (QIDO-RS)
- Server actor provides thread-safe concurrent request handling
- Router supports full DICOMweb URL patterns with path parameter extraction
- Storage provider protocol enables pluggable backends
- InMemoryStorageProvider suitable for testing and development
- Integration with HTTP frameworks (SwiftNIO, Vapor) requires implementing a bridge
- CORS preflight handling included for browser-based clients

#### Acceptance Criteria
- [ ] Server passes basic DICOMweb conformance tests (requires network integration)
- [ ] OHIF viewer can connect and display images (requires network integration)
- [ ] Query performance acceptable with 10,000+ instances (requires file system storage)
- [x] Concurrent request handling is stable (actor-based)
- [x] Memory usage is bounded for large studies (via storage provider abstraction)
- [x] Unit tests for all endpoints (44 new tests)
- [ ] Integration tests with DICOMweb clients (requires network integration)

---

### Milestone 8.6: DICOMweb Server - STOW-RS Enhancements (v0.8.6)

**Status**: Completed  
**Goal**: Enhance DICOMweb server STOW-RS with advanced validation and configuration  
**Complexity**: High  
**Dependencies**: Milestone 8.5

#### Deliverables
- [x] STOW-RS endpoints:
  - [x] `POST /studies` - Store instances
  - [x] `POST /studies/{studyUID}` - Store to specific study
  - [x] Multipart request parsing
  - [x] Support for application/dicom (single instance) ✅ NEW
  - [ ] Support for application/dicom+json (deferred)
- [x] Request validation:
  - [x] Content-Type validation ✅ NEW
  - [x] Study UID consistency check ✅ ENHANCED
  - [x] Required attribute validation ✅ NEW
  - [x] SOP Class validation (optional, configurable) ✅ NEW
  - [x] UID format validation ✅ NEW
  - [x] Request body size validation ✅ NEW
- [x] Response generation:
  - [x] Success response with ReferencedSOPSequence (with proper SOP Class UIDs) ✅ ENHANCED
  - [x] Partial success with warnings ✅ NEW
  - [x] Failure response with FailedSOPSequence (with reason codes) ✅ ENHANCED
  - [x] Proper HTTP status codes (200, 202, 400, 409, 413, 415) ✅ NEW
  - [x] Warning header for partial success ✅ NEW
  - [x] Retrieve URL in response ✅ NEW
- [x] Storage backend integration:
  - [x] Store received instances to storage provider
  - [x] Handle duplicates (reject, replace, or accept) ✅ NEW
- [x] Request size validation:
  - [x] Request size limits (configurable via maxRequestBodySize) ✅ NEW
  - [ ] Streaming upload support (deferred - requires framework integration)
- [x] STOWConfiguration for server-side STOW-RS behavior: ✅ NEW
  - [x] DuplicatePolicy enum (reject/replace/accept)
  - [x] validateRequiredAttributes option
  - [x] validateSOPClasses option with allowedSOPClasses set
  - [x] validateUIDFormat option
  - [x] additionalRequiredTags array
  - [x] Preset configurations: default, strict, permissive
- [x] STOWDelegate protocol: ✅ NEW
  - [x] `func server(_:didStoreInstance:studyUID:seriesUID:) async`
  - [x] `func server(_:didFailToStoreInstance:reason:) async`
  - [x] `func server(_:shouldAcceptInstance:sopClassUID:studyUID:) async -> Bool`
  - [x] Default implementations for all methods
- [x] STOW failure reason codes: ✅ NEW
  - [x] processingFailure (0x0110)
  - [x] duplicateSOPInstance (0x0111)
  - [x] invalidDICOMData (0x0112)
  - [x] missingRequiredAttribute (0x0120)
  - [x] invalidAttributeValue (0x0121)
  - [x] sopClassNotSupported (0x0122)
  - [x] studyUIDMismatch (0x0123)
  - [x] invalidUIDFormat (0x0124)

#### Technical Notes
- Reference: PS3.18 Section 10.5 - STOW-RS
- Multipart parsing handles standard boundary formats
- Request size limits prevent memory exhaustion
- UID validation follows DICOM standard (1-64 chars, digits and dots)
- Duplicate handling is policy-driven via STOWConfiguration
- Delegate pattern allows custom store logic

#### Acceptance Criteria
- [x] Server accepts STOW-RS uploads with multipart content
- [x] Server accepts STOW-RS uploads with single application/dicom
- [x] Validation rejects invalid requests appropriately
- [x] Request size limits work correctly
- [x] Duplicate handling works per configuration
- [x] Unit tests for STOW-RS configuration (4 tests)
- [x] Unit tests for STOW-RS handlers (6 tests)
- [x] Unit tests for STOWDelegate (1 test)
- [ ] Integration tests with DICOMweb clients (requires network integration)

---

### Milestone 8.7: UPS-RS Worklist Services (v0.8.7)

**Status**: Completed  
**Goal**: Implement Unified Procedure Step RESTful Services for worklist management  
**Complexity**: Very High  
**Dependencies**: Milestone 8.5, Milestone 8.6

#### Deliverables
- [x] UPS-RS Worklist Query (client and server):
  - [x] `GET /workitems` - Search workitems (route and handler implemented)
  - [x] Query parameters for UPS attributes (`UPSQuery` builder)
  - [x] Scheduled, In Progress, Completed, Canceled states (`UPSState` enum)
- [x] UPS-RS Worklist Retrieval (client and server):
  - [x] `GET /workitems/{workitemUID}` - Retrieve specific workitem (handler implemented)
  - [x] DICOM JSON metadata response
- [x] UPS-RS Worklist Creation (client and server):
  - [x] `POST /workitems` - Create new workitem (handler implemented)
  - [x] `POST /workitems/{workitemUID}` - Create with specific UID (handler implemented)
  - [x] Basic UPS attributes validation
- [x] UPS-RS State Management (client and server):
  - [x] `PUT /workitems/{workitemUID}/state` - Change state (handler implemented)
  - [x] State transitions: SCHEDULED → IN PROGRESS → COMPLETED/CANCELED (`UPSState.canTransition`)
  - [x] Transaction UID tracking (`InMemoryUPSStorageProvider`)
    - [x] Performer information (`HumanPerformer` struct)
- [x] UPS-RS Cancellation:
  - [x] `PUT /workitems/{workitemUID}/cancelrequest` - Request cancellation (handler implemented)
  - [x] Cancellation request dataset (`UPSCancellationRequest` struct)
- [x] UPS-RS Subscription (Event Service):
  - [x] `POST /workitems/{workitemUID}/subscribers/{AETitle}` - Subscribe (handler implemented)
  - [x] `DELETE /workitems/{workitemUID}/subscribers/{AETitle}` - Unsubscribe (handler implemented)
  - [x] `POST /workitems/{workitemUID}/subscribers/{AETitle}/suspend` - Suspend (handler implemented)
  - [ ] Global subscription endpoints (deferred to v0.8.8)
  - [ ] WebSocket event delivery (deferred to v0.8.8)
  - [ ] Long polling fallback (deferred to v0.8.8)
- [ ] UPS Event Types (deferred to v0.8.8):
  - [ ] UPS State Report (state changes)
  - [ ] UPS Progress Report (progress updates)
  - [ ] UPS Cancel Requested
  - [ ] UPS Assigned
  - [ ] UPS Completed/Canceled
- [x] Workitem data model:
  - [x] `Workitem` struct with UPS attributes
  - [x] Scheduled Procedure Step attributes
  - [x] Performed Procedure Step attributes
  - [x] Progress information (`ProgressInformation` struct)
- [x] `UPSClient` API:
  - [x] `func searchWorkitems(query: UPSQuery) async throws -> UPSQueryResult`
  - [x] `func retrieveWorkitem(uid: String) async throws -> [String: Any]`
  - [x] `func retrieveWorkitemResult(uid: String) async throws -> WorkitemResult`
  - [x] `func createWorkitem(workitem:uid:) async throws -> UPSCreateResponse`
  - [x] `func createWorkitem(_:) async throws -> UPSCreateResponse`
  - [x] `func updateWorkitem(uid:updates:) async throws`
  - [x] `func changeState(uid:state:transactionUID:) async throws -> UPSStateChangeResponse`
  - [x] `func requestCancellation(uid:reason:contactDisplayName:contactURI:) async throws -> UPSCancellationResponse`
  - [x] `func subscribe(uid:aeTitle:deletionLock:) async throws`
  - [x] `func subscribeGlobally(aeTitle:deletionLock:) async throws`
  - [x] `func unsubscribe(uid:aeTitle:) async throws`
  - [x] `func unsubscribeGlobally(aeTitle:) async throws`
  - [x] `func suspendSubscription(uid:aeTitle:) async throws`
  - [x] UPS-RS URL building methods in `DICOMwebURLBuilder`
  - [x] Unit tests for UPSClient initialization and URL builder (15 tests)
- [x] `UPSServer` additions:
  - [x] Workitem storage and retrieval (`UPSStorageProvider` protocol)
  - [x] State machine enforcement (`InMemoryUPSStorageProvider`)
  - [x] Server handler implementations for all UPS-RS endpoints
  - [x] Optional UPS storage via `setUPSStorage()` method
  - [x] Capabilities endpoint includes UPS-RS support status
  - [ ] Event generation and delivery (deferred to v0.8.8)
  - [ ] Full subscription management (deferred to v0.8.8)
- [x] Additional types:
  - [x] `UPSQuery` builder for search queries
  - [x] `UPSQueryResult` and `WorkitemResult` for query results
  - [x] `UPSError` for error handling
  - [x] `CodedEntry`, `HumanPerformer`, `ReferencedInstance` supporting types
  - [x] `UPSTag` constants for DICOM tags
  - [x] 83 unit tests for UPS types and server handlers

#### Technical Notes
- Reference: PS3.18 Section 11 - UPS-RS
- Reference: PS3.4 Annex CC - Unified Procedure Step Service
- UPS is used for worklist management and workflow orchestration
- State transitions must follow defined state machine
- Events enable real-time workflow coordination
- WebSocket preferred for low-latency event delivery

#### Acceptance Criteria
- [x] UPS worklist operations work correctly
- [x] State machine enforces valid transitions only
- [ ] Events are delivered reliably (deferred to v0.8.8)
- [ ] Subscription management handles multiple subscribers (deferred to v0.8.8)
- [ ] Integration tests with UPS-aware systems (requires network integration)

---

### Milestone 8.8: Advanced DICOMweb Features (v0.8.8)

**Status**: In Progress  
**Goal**: Production-ready DICOMweb with security and advanced features  
**Complexity**: High  
**Dependencies**: Milestone 8.7

#### Deliverables
- [x] OAuth2/OpenID Connect Authentication:
  - [x] Client credentials flow (`OAuth2TokenManager`)
  - [x] Authorization code flow (URL building, code exchange)
  - [x] Token refresh handling (automatic refresh before expiration)
  - [x] Bearer token injection (`OAuth2TokenProvider` protocol)
  - [x] SMART on FHIR compatibility (`OAuth2Configuration.smartOnFHIR`)
  - [x] PKCE support for public clients
  - [x] Static token provider for testing
- [x] Server authentication middleware:
  - [x] Token validation (`JWTVerifier` protocol, `UnsafeJWTParser`, `HMACJWTVerifier`)
  - [x] JWT parsing and verification (`JWTClaims` struct, `JWTVerificationError`)
  - [x] Role-based access control (`RoleBasedAccessPolicy`, `DICOMwebRole`)
  - [x] Study-level access control (`DICOMwebResource`, patient context in `JWTClaims`)
  - [x] `AuthenticationMiddleware` for request authentication and authorization
  - [x] `AuthenticatedUser` struct for authenticated context
  - [x] `AccessPolicy` protocol for pluggable authorization rules
  - [x] `DICOMwebOperation` and `DICOMwebResource` types
- [x] HTTPS/TLS Configuration:
  - [x] TLS 1.2/1.3 support
  - [x] Certificate management (PEM/DER loading, validation)
  - [x] Client certificate authentication (mTLS)
  - [x] TLS configuration presets (strict, compatible, development, mutualTLS)
  - [x] Certificate validation modes (strict, standard, permissive)
  - [x] TLS configuration validation with error handling
  - [x] Unit tests for TLS configuration (36 tests)
- [x] Capability Discovery:
  - [x] `GET /` or `GET /capabilities` - Server capabilities
  - [x] Supported services and endpoints (`DICOMwebCapabilities.SupportedServices`)
  - [x] Supported transfer syntaxes
  - [x] `DICOMwebCapabilities` type with all capability metadata
  - [x] Server handler for capabilities endpoint
  - [x] Conformance statement generation (`ConformanceStatement`, `ConformanceStatementGenerator`)
- [x] Extended Negotiation (partial):
  - [ ] `accept-charset` parameter handling
  - [x] Compression (gzip, deflate) for responses (`CompressionConfiguration`, `CompressionMiddleware`)
  - [x] ETag and conditional requests (`CacheControlDirective`)
  - [ ] Range requests for partial content
- [x] Caching:
  - [x] Cache-Control header support (`CacheControlDirective`)
  - [x] ETag generation and validation
  - [x] Client-side caching utilities (`InMemoryCache`)
  - [x] `CacheConfiguration` with presets
  - [x] `CacheEntry` with TTL and validation support
  - [x] Cache key generation utilities
  - [ ] Server-side response caching
- [ ] Performance Optimizations:
  - [ ] Connection pooling (HTTP/2 multiplexing)
  - [ ] Request pipelining
  - [ ] Prefetching for likely requests
  - [ ] Response streaming
- [x] Monitoring and Logging:
  - [x] Request/response logging (`DICOMwebRequestLogger` protocol)
  - [x] Performance metrics (latency, throughput) (`DICOMwebMetrics`)
  - [x] Error rate tracking
  - [x] OSLog integration (`OSLogRequestLogger`)
  - [x] Console logger for debugging
  - [x] Composite logger support
  - [x] Metric timer for operation timing
- [x] CORS Configuration (Server) - already in v0.8.5:
  - [x] Allowed origins configuration
  - [x] Preflight request handling
  - [x] Credentials support
- [x] Delete Services (optional per PS3.18) - already in v0.8.5:
  - [x] `DELETE /studies/{studyUID}` - Delete study
  - [x] `DELETE .../series/{seriesUID}` - Delete series
  - [x] `DELETE .../instances/{instanceUID}` - Delete instance
  - [ ] Soft delete vs. permanent delete
- [x] `DICOMwebClient` unified API:
  - [x] Single client for all DICOMweb services (WADO-RS, QIDO-RS, STOW-RS, UPS-RS)
  - [x] Configuration with authentication, caching, retry
  - [x] Automatic token refresh (via `OAuth2TokenProvider`)
  - [x] Request interceptors for customization (via HTTPClient)

#### Technical Notes
- Reference: PS3.18 Section 6 - Security Considerations
- Reference: PS3.18 Section 10.8 - Capabilities
- OAuth2/OIDC is the recommended authentication mechanism
- SMART on FHIR enables EHR launch integration
- HTTP/2 multiplexing reduces connection overhead
- Caching critical for performance with repeated requests

#### Acceptance Criteria
- [ ] OAuth2 authentication works with major providers
- [ ] SMART on FHIR launch flow works with test EHRs
- [x] HTTPS connections are secure (TLS 1.2/1.3 support with proper configuration)
- [ ] Capability discovery provides accurate information
- [ ] Caching improves performance for repeated requests
- [ ] Delete services work correctly (when enabled)
- [ ] Performance acceptable for production workloads
- [ ] Security scan passes

---

### Milestone 8 Summary

| Sub-Milestone | Version | Complexity | Key Deliverables |
|--------------|---------|------------|------------------|
| 8.1 Core Infrastructure | v0.8.1 | Medium | HTTP layer, JSON/XML, multipart MIME |
| 8.2 WADO-RS Client | v0.8.2 | Medium-High | Retrieve studies, metadata, frames, rendered |
| 8.3 QIDO-RS Client | v0.8.3 | Medium-High | Query studies, series, instances |
| 8.4 STOW-RS Client | v0.8.4 | Medium | Store instances, batch upload |
| 8.5 WADO-RS/QIDO-RS Server | v0.8.5 | High | Serve studies, handle queries |
| 8.6 STOW-RS Server | v0.8.6 | High | Receive uploads, validation |
| 8.7 UPS-RS Worklist | v0.8.7 | Very High | Worklist management, events |
| 8.8 Advanced Features | v0.8.8 | High | OAuth2, TLS, caching, production readiness |

### Overall Technical Notes
- Reference: PS3.18 - Web Services (complete specification)
- Build HTTP client on URLSession for Apple platform integration
- Consider SwiftNIO or Vapor for server implementation
- All APIs use Swift concurrency (async/await, AsyncStream)
- Memory efficiency critical for streaming large studies
- Test with public DICOMweb servers (e.g., Google Cloud Healthcare API, DCM4CHEE)

### Overall Acceptance Criteria
- Full DICOMweb client compatible with major servers (DCM4CHEE, Orthanc, Google Cloud Healthcare)
- DICOMweb server compatible with OHIF viewer and other standard clients
- Pass DICOMweb conformance tests
- Secure with OAuth2/OIDC authentication
- Production-ready reliability and performance

---

## Milestone 9: Structured Reporting (v0.9)

**Status**: Planned  
**Goal**: Full support for DICOM Structured Reporting

DICOM Structured Reporting (SR) enables the encoding of clinical reports as structured, machine-readable documents. SR documents contain hierarchical trees of "Content Items" with coded concepts, enabling semantic interoperability for measurements, observations, and findings. This milestone implements comprehensive SR support for parsing, creating, and working with structured reports.

This milestone is divided into modular sub-milestones based on complexity, allowing for incremental development and testing. Each sub-milestone builds upon previous ones.

---

### Milestone 9.1: Core SR Infrastructure (v0.9.1)

**Status**: Completed  
**Goal**: Establish foundational data structures for DICOM Structured Reporting  
**Complexity**: High  
**Dependencies**: Milestone 5 (DICOM Writing)

#### Deliverables
- [x] Content Item value types (PS3.3 Table C.17.3-1):
  - [x] `ContentItemValueType` enum for all SR value types
  - [x] `TextContentItem` - Unstructured text (TEXT)
  - [x] `CodeContentItem` - Coded concept from terminology (CODE)
  - [x] `NumericContentItem` - Quantitative value with units (NUM)
  - [x] `DateContentItem` - Date value (DATE)
  - [x] `TimeContentItem` - Time value (TIME)
  - [x] `DateTimeContentItem` - Combined date/time (DATETIME)
  - [x] `PersonNameContentItem` - Person name (PNAME)
  - [x] `UIDRefContentItem` - DICOM UID reference (UIDREF)
  - [x] `ContainerContentItem` - Groups other content items (CONTAINER)
- [x] Reference content item types:
  - [x] `CompositeContentItem` - Reference to DICOM composite object (COMPOSITE)
  - [x] `ImageContentItem` - Reference to DICOM image (IMAGE)
  - [x] `WaveformContentItem` - Reference to waveform data (WAVEFORM)
- [x] Coordinate content item types:
  - [x] `SpatialCoordinatesContentItem` - 2D spatial coordinates (SCOORD)
  - [x] `SpatialCoordinates3DContentItem` - 3D spatial coordinates (SCOORD3D)
  - [x] `TemporalCoordinatesContentItem` - Temporal coordinates (TCOORD)
- [x] Coded concept support:
  - [x] `CodedConcept` struct (Code Value, Coding Scheme Designator, Code Meaning)
  - [x] `CodingSchemeDesignator` enum for common coding schemes (DCM, SRT, LN, FMA, etc.)
  - [x] Code validation utilities
  - [ ] `CodeSequence` for encoding/decoding code sequences (deferred to Milestone 9.2)
- [x] Relationship types (PS3.3 Table C.17.3-8):
  - [x] `RelationshipType` enum (CONTAINS, HAS PROPERTIES, INFERRED FROM, etc.)
  - [x] Relationship validation per value type constraints
  - [ ] `SRRelationship` struct for relationship encoding (deferred to Milestone 9.2)
- [x] Content item base protocol:
  - [x] `ContentItem` protocol with common properties
  - [x] Concept name (coded name of the item)
  - [x] Relationship type to parent
  - [x] Child content items (for CONTAINER)
  - [x] `AnyContentItem` type-erased wrapper for heterogeneous collections
  - [x] Observation context support
- [x] SR Document type definitions:
  - [x] `SRDocumentType` enum (Basic Text, Enhanced, Comprehensive, etc.)
  - [x] Value type constraints per document type
  - [x] SOP Class UID constants for all 18 SR types
- [x] Supporting types:
  - [x] `GraphicType`, `GraphicType3D` for spatial coordinates
  - [x] `TemporalRangeType` for temporal coordinates
  - [x] `ContinuityOfContent` for CONTAINER semantics
  - [x] `NumericValueQualifier` for special numeric values
  - [x] `ReferencedSOP`, `ImageReference`, `WaveformReference` for object references

#### Technical Notes
- Reference: PS3.3 Section C.17.3 - SR Document Content Module
- Reference: PS3.3 Table C.17.3-1 - Value Type Definitions
- Reference: PS3.3 Table C.17.3-8 - Relationship Type Definitions
- Content items form a tree structure with CONTAINER as branch nodes
- Coded concepts use triplet: Code Value + Coding Scheme Designator + Code Meaning
- Relationship types constrain which value types can be children

#### Acceptance Criteria
- [x] All 15 content item value types are implemented
- [x] Coded concepts can be created and validated
- [x] Relationship types are correctly defined
- [x] Content item protocol enables polymorphic tree building
- [x] Unit tests for all content item types (148 tests, exceeds target of 60+)
- [x] Documentation for SR data model (README updated)

---

### Milestone 9.2: SR Document Parsing (v0.9.2)

**Status**: Completed  
**Goal**: Parse DICOM SR documents into the content item tree model  
**Complexity**: High  
**Dependencies**: Milestone 9.1

#### Deliverables
- [x] SR Document Module parsing:
  - [x] Content Sequence (0040,A730) recursive parsing
  - [x] Value Type (0040,A040) detection and dispatch
  - [x] Concept Name Code Sequence (0040,A043) parsing
  - [x] Relationship Type (0040,A010) extraction
- [x] Content item value parsing:
  - [x] Text Value (0040,A160) for TEXT items
  - [x] Concept Code Sequence (0040,A168) for CODE items
  - [x] Measured Value Sequence (0040,A300) for NUM items
  - [x] Numeric Value (0040,A30A) and Unit Code (0040,08EA)
  - [x] Date/Time/DateTime Value parsing
  - [x] Person Name (0040,A123) for PNAME
  - [x] UID (0040,A124) for UIDREF
- [x] Reference parsing:
  - [x] Referenced SOP Sequence (0008,1199)
  - [x] Referenced SOP Class UID (0008,1150)
  - [x] Referenced SOP Instance UID (0008,1155)
  - [x] Referenced Frame Number (0008,1160)
  - [x] Referenced Segment Number (0062,000B)
- [x] Coordinate parsing:
  - [x] Graphic Data (0070,0022) for SCOORD
  - [x] Graphic Type (0070,0023) - POINT, POLYLINE, CIRCLE, ELLIPSE
  - [ ] Fiducial UID (0070,031A) - deferred
  - [x] Referenced Frame of Reference UID for SCOORD3D
  - [x] Temporal Range Type for TCOORD
- [x] SR Document header parsing:
  - [x] SR Document General Module attributes
  - [x] Document Title (Concept Name of root)
  - [x] Completion Flag (0040,A491)
  - [x] Verification Flag (0040,A493)
  - [x] Content Date/Time
  - [x] Preliminary Flag
- [ ] Observation context parsing:
  - [ ] Observer Type (0040,A084) - Person, Device - deferred to Milestone 9.3
  - [ ] Person Identification Code Sequence - deferred to Milestone 9.3
  - [ ] Device Observer attributes - deferred to Milestone 9.3
  - [ ] Subject Context (Patient, Specimen, Fetus) - deferred to Milestone 9.3
- [x] `SRDocumentParser` API:
  - [x] `func parse(dataSet: DataSet) throws -> SRDocument`
  - [x] Validation level configuration (strict, lenient)
  - [x] Error recovery for malformed documents
  - [x] Maximum depth protection

#### Technical Notes
- Reference: PS3.3 Section C.17 - SR Document Information Object Definitions
- Reference: PS3.3 Section C.17.3.2 - Content Item and Content Sequence
- Recursive parsing required for nested Content Sequences
- Must handle by-reference relationships (observation context references)
- Some SR documents may have circular references (must detect/handle)

#### Acceptance Criteria
- [x] Successfully parse Basic Text SR documents
- [x] Successfully parse Enhanced SR documents
- [x] Successfully parse Comprehensive SR documents
- [x] Content tree structure correctly represents document hierarchy
- [x] All value types are correctly extracted
- [x] Coordinate data is correctly parsed for ROI applications
- [x] Unit tests with sample SR documents (target: 40+ tests) - 42 tests
- [ ] Performance acceptable for large SR documents (1000+ content items) - not validated

---

### Milestone 9.3: Content Item Navigation and Tree Traversal (v0.9.3)

**Status**: Completed  
**Goal**: Provide intuitive APIs for navigating and querying SR content trees  
**Complexity**: Medium  
**Dependencies**: Milestone 9.2

#### Deliverables
- [x] Tree traversal APIs:
  - [x] `SRDocument.rootContent` - Access root container
  - [x] `ContainerContentItem.contentItems` - Direct child items
  - [ ] `ContentItem.parent` - Parent reference (weak) - deferred (would require structural changes)
  - [x] Depth-first iteration via `Sequence` conformance (`ContentTreeIterator`, `ContentTreeSequence`)
  - [x] Breadth-first iteration alternative (`BreadthFirstIterator`)
  - [x] Lazy iteration for memory efficiency (iterators are lazy by design)
- [x] Query and filtering APIs:
  - [x] `findItems(byConceptName:)` - Find by coded concept
  - [x] `findItems(byValueType:)` - Find by value type
  - [x] `findItems(byRelationship:)` - Find by relationship type
  - [x] `findItems(matching:)` - Custom predicate filtering
  - [x] Recursive vs. shallow search options (`recursive` parameter)
- [x] Path-based access:
  - [x] `SRPath` struct for addressing content items
  - [x] Path notation (e.g., "/Report/Finding[0]/Measurement")
  - [x] `item(at path:)` - Access by path
  - [x] Path serialization for persistence (`description`)
- [x] Content item subscripting:
  - [x] Subscript by index for children (`container[0]`)
  - [x] Subscript by concept code (`container[concept: "Finding"]`)
  - [x] Safe optional access patterns (all subscripts return optionals)
- [x] Relationship navigation:
  - [x] `inferredFromItems` - Items this was inferred from
  - [x] `propertyItems` - Property items of this item (HAS PROPERTIES)
  - [x] `selectedFromItems` - Source of coordinate selection
  - [x] `acquisitionContextItems` - Acquisition context items
  - [x] `observationContextItems` - Observation context items
- [x] Measurement-specific navigation:
  - [x] `findMeasurements()` - All numeric content items
  - [x] `findMeasurements(forConcept:)` - Measurements by name
  - [x] `findMeasurementGroups()` - Measurement containers
  - [x] `getMeasurementValue(forConcept:)` - Direct value access
- [ ] Swift-idiomatic patterns (deferred to future enhancement):
  - [ ] `AsyncSequence` for streaming traversal
  - [ ] Result builders for query construction
  - [ ] Key path subscripting where applicable

#### Technical Notes
- Reference: PS3.3 C.17.3.2.4 - Content Sequence and Relationship Type
- Tree may contain by-reference relationships creating non-tree connections
- Consider memory efficiency for large documents (lazy loading)
- Parent references should be weak to avoid retain cycles
- Implemented `ContentTreeIterator` and `BreadthFirstIterator` for efficient traversal
- `SRPath` enables XPath-like navigation with indexed access

#### Acceptance Criteria
- [x] Tree traversal visits all content items correctly
- [x] Query APIs efficiently filter large content trees
- [x] Path-based access works for common navigation patterns
- [x] Measurement navigation simplifies quantitative data extraction
- [x] Memory usage is bounded for large documents (lazy iterators)
- [x] Unit tests for navigation scenarios (target: 50+ tests) - 66 tests implemented
- [x] Documentation with usage examples (in README)

---

### Milestone 9.4: Coded Terminology Support (v0.9.4)

**Status**: Planned  
**Goal**: Comprehensive support for medical terminologies used in SR  
**Complexity**: High  
**Dependencies**: Milestone 9.1

#### Deliverables
- [ ] Coding scheme infrastructure:
  - [ ] `CodingScheme` struct with designator, name, version
  - [ ] Registry of known coding schemes
  - [ ] Coding scheme validation
  - [ ] Version-aware code lookup
- [ ] SNOMED CT support:
  - [ ] `SNOMEDCode` specialized type
  - [ ] Common anatomical codes (body parts, laterality)
  - [ ] Common finding codes (mass, lesion, calcification)
  - [ ] Common procedure codes
  - [ ] Hierarchical relationship awareness
- [ ] LOINC support:
  - [ ] `LOINCCode` specialized type
  - [ ] Common observation codes
  - [ ] Measurement type codes
  - [ ] Radiology report section codes
- [ ] RadLex support:
  - [ ] `RadLexCode` specialized type
  - [ ] Playbook codes for radiology procedures
  - [ ] Common radiology finding codes
  - [ ] Anatomical codes relevant to imaging
- [ ] DCM (DICOM) codes:
  - [ ] All codes from PS3.16 Context Groups
  - [ ] Relationship type codes
  - [ ] SR-specific concept codes
  - [ ] Measurement template codes
- [ ] UCUM (Units of Measurement):
  - [ ] `UCUMUnit` type for units
  - [ ] Common measurement units (mm, cm, mL, etc.)
  - [ ] Unit conversion utilities
  - [ ] Unit validation
- [ ] Context Group support (PS3.16):
  - [ ] `ContextGroup` struct for CID definitions
  - [ ] Extensible vs. non-extensible context groups
  - [ ] Common context groups:
    - [ ] CID 218 - Quantitative Temporal Relation
    - [ ] CID 244 - Laterality
    - [ ] CID 4021 - Finding Site
    - [ ] CID 6147 - Response Evaluation
    - [ ] CID 7021 - Measurement Report Document Titles
    - [ ] CID 7464 - General Region of Interest Measurement Units
  - [ ] Context group validation
- [ ] Code mapping utilities:
  - [ ] `CodeMapper` for cross-terminology mapping
  - [ ] Equivalent code lookup
  - [ ] Display name resolution
  - [ ] Localization support (future)

#### Technical Notes
- Reference: PS3.16 - Content Mapping Resource
- Reference: PS3.16 Annex B - DCMR Context Group Definitions
- SNOMED CT codes are numeric, LOINC uses alphanumeric patterns
- Context groups define allowed codes for specific SR positions
- Some codes are extensible (allow additions), others are non-extensible

#### Acceptance Criteria
- [ ] All major coding schemes are supported
- [ ] Common medical codes are pre-defined for convenience
- [ ] Context group validation works correctly
- [ ] Unit handling is accurate for measurements
- [ ] Code lookup is efficient (dictionary-based)
- [ ] Unit tests for terminology handling (target: 80+ tests)
- [ ] Documentation with code examples

---

### Milestone 9.5: Measurement and Coordinate Extraction (v0.9.5)

**Status**: Planned  
**Goal**: Extract quantitative measurements and spatial/temporal coordinates from SR  
**Complexity**: High  
**Dependencies**: Milestone 9.3, Milestone 9.4

#### Deliverables
- [ ] Measurement extraction:
  - [ ] `Measurement` struct with value, unit, and context
  - [ ] `MeasurementGroup` for related measurements (e.g., lesion dimensions)
  - [ ] Numeric precision handling (significant figures)
  - [ ] Measurement qualifier extraction (mean, max, min, etc.)
  - [ ] Derivation method tracking (manual, automated, calculated)
- [ ] Measurement value handling:
  - [ ] Single numeric values
  - [ ] Value ranges (min-max)
  - [ ] Multiple values (e.g., multi-frame measurements)
  - [ ] Null/missing value handling with reason codes
- [ ] Unit conversion:
  - [ ] Automatic unit normalization
  - [ ] Common conversions (mm↔cm, mL↔L, etc.)
  - [ ] Configurable output units
  - [ ] Lossless value preservation
- [ ] Spatial coordinate extraction (SCOORD):
  - [ ] `SpatialCoordinates` struct with graphic type and points
  - [ ] Point coordinates (x, y)
  - [ ] Polyline (open contour)
  - [ ] Polygon (closed contour)
  - [ ] Circle (center + radius point)
  - [ ] Ellipse (four points)
  - [ ] Image reference linkage
- [ ] 3D coordinate extraction (SCOORD3D):
  - [ ] `SpatialCoordinates3D` struct
  - [ ] 3D point coordinates (x, y, z)
  - [ ] 3D polyline and polygon
  - [ ] Frame of reference handling
  - [ ] Coordinate system transformation utilities
- [ ] Temporal coordinate extraction (TCOORD):
  - [ ] `TemporalCoordinates` struct
  - [ ] Point in time references
  - [ ] Time ranges (begin-end)
  - [ ] Multi-point temporal data
  - [ ] Frame number references
- [ ] Region of Interest (ROI) helpers:
  - [ ] `ROI` struct combining coordinates with measurements
  - [ ] Area/volume calculation from coordinates
  - [ ] Bounding box computation
  - [ ] Centroid calculation
  - [ ] ROI-to-image coordinate mapping
- [ ] Measurement aggregation:
  - [ ] Group measurements by anatomical location
  - [ ] Group measurements by finding
  - [ ] Time series of measurements
  - [ ] Statistical summaries (mean, std dev, etc.)
- [ ] `MeasurementExtractor` API:
  - [ ] `func extractAllMeasurements(from: SRDocument) -> [Measurement]`
  - [ ] `func extractMeasurements(forConcept:) -> [Measurement]`
  - [ ] `func extractROIs(from: SRDocument) -> [ROI]`
  - [ ] `func extractTimeSeries(forConcept:) -> TimeSeries`

#### Technical Notes
- Reference: PS3.3 C.17.3.2 - Numeric measurement encoding
- Reference: PS3.3 C.18.6 - Spatial Coordinates Macro
- Reference: PS3.3 C.18.7 - Temporal Coordinates Macro
- Measurements may have qualifiers (measured, estimated, derived)
- Coordinates are in image pixel space for SCOORD, patient space for SCOORD3D
- TCOORD references specific frames or time points in multi-frame images

#### Acceptance Criteria
- [ ] Measurements are accurately extracted with units
- [ ] All graphic types are correctly parsed
- [ ] 3D coordinates handle frame of reference correctly
- [ ] ROI calculations produce accurate results
- [ ] Unit conversion maintains precision
- [ ] Unit tests for measurement scenarios (target: 60+ tests)
- [ ] Integration tests with real SR measurement reports

---

### Milestone 9.6: SR Document Creation (v0.9.6)

**Status**: Planned  
**Goal**: Create valid DICOM SR documents programmatically  
**Complexity**: High  
**Dependencies**: Milestone 9.1, Milestone 9.4

#### Deliverables
- [ ] SR Document builder:
  - [ ] `SRDocumentBuilder` fluent API
  - [ ] Document type selection (Basic Text, Enhanced, Comprehensive)
  - [ ] Root container configuration
  - [ ] Document title setting
  - [ ] Completion/Verification flag setting
- [ ] Content item creation:
  - [ ] Factory methods for each value type
  - [ ] `addText(concept:value:relationship:)`
  - [ ] `addCode(concept:value:relationship:)`
  - [ ] `addNumeric(concept:value:unit:relationship:)`
  - [ ] `addContainer(concept:relationship:)`
  - [ ] `addDate/Time/DateTime(concept:value:relationship:)`
  - [ ] `addPersonName(concept:value:relationship:)`
  - [ ] `addUIDRef(concept:value:relationship:)`
- [ ] Reference content creation:
  - [ ] `addImageReference(concept:sopClassUID:sopInstanceUID:frames:)`
  - [ ] `addCompositeReference(concept:sopClassUID:sopInstanceUID:)`
  - [ ] `addWaveformReference(concept:sopClassUID:sopInstanceUID:)`
- [ ] Coordinate content creation:
  - [ ] `addSpatialCoordinates(concept:graphicType:points:imageRef:)`
  - [ ] `addSpatialCoordinates3D(concept:graphicType:points:frameOfRef:)`
  - [ ] `addTemporalCoordinates(concept:rangeType:values:)`
- [ ] Observation context setting:
  - [ ] `setObserverPerson(name:organization:)`
  - [ ] `setObserverDevice(uid:name:manufacturer:)`
  - [ ] `setSubjectContext(patient:specimen:fetus:)`
  - [ ] `setAcquisitionContext(attributes:)`
- [ ] Measurement creation helpers:
  - [ ] `addMeasurement(name:value:unit:derivation:)`
  - [ ] `addMeasurementGroup(name:measurements:)`
  - [ ] `addQualitativeEvaluation(name:code:)`
- [ ] Document serialization:
  - [ ] `SRDocument.toDataSet() throws -> DataSet`
  - [ ] Content Sequence generation
  - [ ] Proper tag ordering
  - [ ] File Meta Information generation
  - [ ] Transfer syntax handling
- [ ] Validation during creation:
  - [ ] IOD-specific validation
  - [ ] Relationship type constraints
  - [ ] Required attribute checking
  - [ ] Value type compatibility
- [ ] Result builder syntax (optional):
  - [ ] `@SRBuilder` for declarative SR construction
  - [ ] Nested container support
  - [ ] Conditional content inclusion

#### Technical Notes
- Reference: PS3.3 C.17 - SR Document IODs
- Reference: PS3.4 Annex A - SR Storage SOP Classes
- Document type constrains allowed value types and relationships
- Content Sequence must follow proper nesting structure
- UIDs must be generated for new documents

#### Acceptance Criteria
- [ ] Created documents pass DICOM validation tools
- [ ] All SR document types can be created
- [ ] Builder API is intuitive and type-safe
- [ ] Generated documents can be read by DICOM viewers
- [ ] Round-trip: parse → modify → serialize produces valid output
- [ ] Unit tests for creation scenarios (target: 50+ tests)
- [ ] Documentation with creation examples

---

### Milestone 9.7: Template Support (v0.9.7)

**Status**: Planned  
**Goal**: Parse and apply DICOM SR Templates (TID) for structured content  
**Complexity**: Very High  
**Dependencies**: Milestone 9.2, Milestone 9.4, Milestone 9.6

#### Deliverables
- [ ] Template infrastructure:
  - [ ] `SRTemplate` protocol for template definitions
  - [ ] Template ID (TID) registry
  - [ ] Template version handling
  - [ ] Extensible template system
- [ ] Template constraint types:
  - [ ] `TemplateRow` - Single template row definition
  - [ ] `TemplateConstraint` - Value type, relationship, requirement level
  - [ ] Mandatory (M), Required if Known (RK), Optional (O), Conditional (C)
  - [ ] Cardinality constraints (1, 0-1, 1-n, 0-n)
- [ ] Template parsing:
  - [ ] Validate SR content against template definition
  - [ ] Extract template-specific data structures
  - [ ] Handle template extensions
  - [ ] Handle included templates (recursive)
- [ ] Template creation:
  - [ ] Template-guided document creation
  - [ ] Auto-completion of required content
  - [ ] Validation during creation
  - [ ] Template-specific builders
- [ ] Core templates (PS3.16):
  - [ ] TID 300 - Measurement
  - [ ] TID 320 - Image Library Entry
  - [ ] TID 1001 - Observation Context
  - [ ] TID 1002 - Observer Context
  - [ ] TID 1204 - Language of Content
  - [ ] TID 1400 - Linear Measurements
  - [ ] TID 1410 - Planar ROI Measurements
  - [ ] TID 1411 - Volumetric ROI Measurements
  - [ ] TID 1419 - ROI Measurements
  - [ ] TID 1420 - Measurements Derived from Multiple Frames
- [ ] Template validation:
  - [ ] `TemplateValidator` for checking compliance
  - [ ] Detailed violation reporting
  - [ ] Strict vs. lenient validation modes
  - [ ] Warning vs. error classification
- [ ] Template-based extraction:
  - [ ] Auto-detect applied templates
  - [ ] Extract template-specific data structures
  - [ ] Type-safe accessors for template fields

#### Technical Notes
- Reference: PS3.16 Annex A - SR Templates
- Reference: PS3.16 Section 5 - Template Specifications
- Templates define content structure, not just allowed values
- Some templates include others (e.g., TID 1500 in 9.8 includes TID 300 from 9.7)
- Templates may have user-extensible sections
- Core measurement templates (TID 300, 1400-1420) are implemented in 9.7 as building blocks

#### Acceptance Criteria
- [ ] Core measurement templates are implemented
- [ ] Template validation correctly identifies violations
- [ ] Template-guided creation produces compliant documents
- [ ] Nested template includes work correctly
- [ ] Unit tests for template scenarios (target: 70+ tests)
- [ ] Documentation for template system

---

### Milestone 9.8: Common SR Templates Implementation (v0.9.8)

**Status**: Planned  
**Goal**: Full implementation of commonly used SR document templates  
**Complexity**: High  
**Dependencies**: Milestone 9.7

#### Deliverables
- [ ] Basic Text SR (1.2.840.10008.5.1.4.1.1.88.11):
  - [ ] Simple hierarchical text structure
  - [ ] Section headings and content
  - [ ] Minimal coding requirements
  - [ ] `BasicTextSRBuilder` specialized builder
- [ ] Enhanced SR (1.2.840.10008.5.1.4.1.1.88.22):
  - [ ] Text with coded entries
  - [ ] Numeric measurements
  - [ ] Image references
  - [ ] `EnhancedSRBuilder` specialized builder
- [ ] Comprehensive SR (1.2.840.10008.5.1.4.1.1.88.33):
  - [ ] Full value type support
  - [ ] Spatial and temporal coordinates
  - [ ] By-reference relationships
  - [ ] `ComprehensiveSRBuilder` specialized builder
- [ ] TID 1500 - Measurement Report:
  - [ ] Image Library (TID 1600)
  - [ ] Imaging Measurements Container
  - [ ] Measurement Groups (TID 1501)
  - [ ] Tracking Identifiers
  - [ ] Qualitative Evaluations
  - [ ] `MeasurementReportBuilder` specialized builder
  - [ ] `MeasurementReport` extraction type
- [ ] Key Object Selection (1.2.840.10008.5.1.4.1.1.88.59):
  - [ ] Referenced instances
  - [ ] Key object description
  - [ ] Selection reason code
  - [ ] `KeyObjectSelectionBuilder` specialized builder
- [ ] Mammography CAD SR (1.2.840.10008.5.1.4.1.1.88.50):
  - [ ] CAD Processing Summary
  - [ ] Detected findings with confidence
  - [ ] Finding site localization
  - [ ] `MammographyCADSRBuilder` specialized builder
- [ ] Chest CAD SR (1.2.840.10008.5.1.4.1.1.88.65):
  - [ ] Chest-specific CAD findings
  - [ ] Nodule detection results
  - [ ] `ChestCADSRBuilder` specialized builder
- [ ] Comprehensive 3D SR (1.2.840.10008.5.1.4.1.1.88.34):
  - [ ] 3D coordinate support
  - [ ] 3D ROI definitions
  - [ ] Frame of reference handling
  - [ ] `Comprehensive3DSRBuilder` specialized builder
- [ ] High-level extraction APIs:
  - [ ] `MeasurementReport.extract(from: SRDocument) throws -> MeasurementReport`
  - [ ] `CADFindings.extract(from: SRDocument) throws -> CADFindings`
  - [ ] `KeyObjects.extract(from: SRDocument) throws -> [KeyObject]`
- [ ] Integration with AI/ML pipelines:
  - [ ] `AIInferenceResult` protocol for AI output
  - [ ] Convert AI detections to SR format
  - [ ] Support for segmentation results (SEG → SR)
  - [ ] Confidence score encoding

#### Technical Notes
- Reference: PS3.3 Annex A - Composite IODs (SR sections)
- Reference: PS3.16 Annex A - SR Template Specifications
- TID 1500 is widely used for quantitative imaging and AI outputs
- CAD SR templates have modality-specific requirements
- Key Object Selection enables "significant image" flagging

#### Acceptance Criteria
- [ ] All listed SR document types can be created and parsed
- [ ] TID 1500 Measurement Report fully supported
- [ ] CAD SR templates correctly encode detection results
- [ ] Key Object Selection works for image flagging
- [ ] AI/ML integration produces valid SR documents
- [ ] Unit tests for each template (target: 100+ tests)
- [ ] Example applications for common workflows
- [ ] Integration tests with DICOM viewers (OHIF, etc.)

---

### Milestone 9 Summary

| Sub-Milestone | Version | Complexity | Status | Key Deliverables |
|--------------|---------|------------|--------|------------------|
| 9.1 Core SR Infrastructure | v0.9.1 | High | ✅ Completed | Content item types, coded concepts, relationships |
| 9.2 SR Document Parsing | v0.9.2 | High | ✅ Completed | Parse SR into content tree model |
| 9.3 Content Navigation | v0.9.3 | Medium | ✅ Completed | Tree traversal, query, filtering APIs |
| 9.4 Coded Terminology | v0.9.4 | High | Planned | SNOMED, LOINC, RadLex, UCUM, context groups |
| 9.5 Measurement Extraction | v0.9.5 | High | Planned | Measurements, ROIs, coordinates |
| 9.6 SR Document Creation | v0.9.6 | High | Planned | Builder API, serialization, validation |
| 9.7 Template Support | v0.9.7 | Very High | Planned | TID parsing, validation, template-guided creation |
| 9.8 Common Templates | v0.9.8 | High | Planned | TID 1500, CAD SR, Key Object Selection, AI integration |

### Overall Technical Notes
- Reference: PS3.3 Part 3 Section C.17 - SR Document IODs
- Reference: PS3.16 - Content Mapping Resource (templates, context groups)
- Reference: PS3.4 Annex A - SR Storage SOP Classes
- Build on DataSet infrastructure from Milestone 5
- All APIs use Swift concurrency where applicable
- Memory efficiency critical for large SR documents
- Consider caching for repeated terminology lookups

### Overall Acceptance Criteria
- Full support for parsing and creating DICOM SR documents
- TID 1500 Measurement Report for quantitative imaging workflows
- CAD SR support for AI/ML detection outputs
- Integration with DICOM networking for SR storage (C-STORE)
- Integration with DICOMweb for SR retrieval (WADO-RS)
- Performance acceptable for production radiology workflows
- Pass DICOM SR conformance tests

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
