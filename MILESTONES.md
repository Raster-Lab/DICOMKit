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
- [x] Audit Logging:
  - [x] Detailed transfer logs (source, destination, timestamps)
  - [x] Integration with system logging (OSLog)
  - [x] Configurable log retention
  - [x] IHE ATNA-aligned audit event types
  - [x] File-based audit logging with JSON Lines format
  - [x] Log rotation support
  - [x] Event type filtering
  - [x] Storage operation logging helpers
- [ ] `DICOMStorageClient` unified API:
  - [ ] Configuration with server pool, retry policies, queue settings
  - [ ] Automatic server selection (round-robin, priority)
  - [ ] Unified store interface with automatic retry
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

**Status**: Planned  
**Goal**: Implement RESTful DICOM web services (DICOMweb)

This milestone implements the DICOMweb standard (PS3.18), providing modern RESTful HTTP/HTTPS-based access to DICOM objects. DICOMweb enables browser-based viewers, mobile applications, and cloud-native integrations without requiring traditional DICOM networking infrastructure.

This milestone is divided into modular sub-milestones based on complexity, allowing for incremental development and testing. Each sub-milestone builds upon previous ones.

---

### Milestone 8.1: Core DICOMweb Infrastructure (v0.8.1)

**Status**: Planned  
**Goal**: Establish the foundational HTTP layer and data format support for DICOMweb  
**Complexity**: Medium  
**Dependencies**: Milestone 5 (DICOM Writing)

#### Deliverables
- [ ] HTTP client abstraction layer using URLSession:
  - [ ] Configurable timeouts (connect, read, resource)
  - [ ] HTTP/2 support for connection multiplexing
  - [ ] Request/response interceptors for logging and customization
  - [ ] Automatic retry with configurable policies
- [ ] DICOM JSON representation (PS3.18 Section F):
  - [ ] DataSet to JSON serialization
  - [ ] JSON to DataSet deserialization
  - [ ] Bulk data URI handling (BulkDataURI)
  - [ ] InlineBinary encoding (Base64)
  - [ ] Proper handling of all VR types in JSON
  - [ ] PersonName JSON format (Alphabetic, Ideographic, Phonetic)
- [ ] DICOM XML representation (optional):
  - [ ] DataSet to XML serialization
  - [ ] XML to DataSet deserialization
- [ ] Multipart MIME handling (PS3.18 Section 8):
  - [ ] `multipart/related` parsing and generation
  - [ ] Boundary detection and handling
  - [ ] Content-Type header parsing (type, boundary parameters)
  - [ ] Efficient streaming for large payloads
  - [ ] Support for nested multipart content
- [ ] Media type definitions:
  - [ ] `application/dicom` - DICOM Part 10 files
  - [ ] `application/dicom+json` - DICOM JSON
  - [ ] `application/dicom+xml` - DICOM XML
  - [ ] `application/octet-stream` - Bulk data
  - [ ] `image/jpeg`, `image/png`, `image/gif` - Rendered frames
  - [ ] `video/mpeg`, `video/mp4` - Video content
- [ ] URL path construction utilities:
  - [ ] Study, Series, Instance URL building
  - [ ] Query parameter encoding
  - [ ] URL template handling for server configuration
- [ ] `DICOMwebError` error types:
  - [ ] HTTP status code mapping (4xx, 5xx)
  - [ ] DICOM-specific error conditions
  - [ ] Detailed error responses with Warning header parsing
- [ ] `DICOMwebConfiguration` for client/server settings:
  - [ ] Base URL configuration
  - [ ] Authentication settings
  - [ ] Default Accept/Content-Type headers
  - [ ] Request timeout configuration

#### Technical Notes
- Reference: PS3.18 Section 6 - Media Types and Transfer Syntaxes
- Reference: PS3.18 Section 8 - Multipart MIME
- Reference: PS3.18 Section F - DICOM JSON Model
- JSON encoding must handle special VR types: PN, DA, TM, DT, IS, DS
- Bulk data can be inline (Base64) or referenced (URI)
- Consider memory-efficient streaming for large multipart responses

#### Acceptance Criteria
- [ ] DICOM JSON serialization/deserialization is compliant with PS3.18
- [ ] Multipart MIME parsing handles edge cases correctly
- [ ] Round-trip tests: DataSet → JSON → DataSet produces identical data
- [ ] Unit tests cover all media types and encoding scenarios
- [ ] Documentation for core infrastructure types

---

### Milestone 8.2: WADO-RS Client - Retrieve Services (v0.8.2)

**Status**: Planned  
**Goal**: Implement DICOMweb retrieve client for fetching DICOM objects over HTTP  
**Complexity**: Medium-High  
**Dependencies**: Milestone 8.1

#### Deliverables
- [ ] WADO-RS Study retrieval:
  - [ ] `GET /studies/{StudyInstanceUID}` - Retrieve all instances in study
  - [ ] Accept header negotiation (DICOM, JSON, XML, bulk data)
  - [ ] Multipart response parsing for multiple instances
  - [ ] Streaming download for large studies
- [ ] WADO-RS Series retrieval:
  - [ ] `GET /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}`
  - [ ] Filter to single series within study
- [ ] WADO-RS Instance retrieval:
  - [ ] `GET /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}/instances/{SOPInstanceUID}`
  - [ ] Single instance download
- [ ] WADO-RS Metadata retrieval:
  - [ ] `GET /studies/{StudyInstanceUID}/metadata` - Study metadata (JSON/XML)
  - [ ] `GET .../series/{SeriesInstanceUID}/metadata` - Series metadata
  - [ ] `GET .../instances/{SOPInstanceUID}/metadata` - Instance metadata
  - [ ] Bulk data URI handling in metadata responses
- [ ] WADO-RS Frames retrieval:
  - [ ] `GET .../instances/{SOPInstanceUID}/frames/{FrameList}` - Specific frames
  - [ ] Frame number list parsing (e.g., "1,3,5" or "1-10")
  - [ ] Uncompressed frame data (raw pixels)
  - [ ] Compressed frame data (JPEG, JPEG 2000, etc.)
- [ ] WADO-RS Rendered retrieval (consumer-friendly formats):
  - [ ] `GET .../instances/{SOPInstanceUID}/rendered` - Rendered image
  - [ ] `GET .../frames/{FrameList}/rendered` - Rendered frames
  - [ ] Query parameters: window, viewport, quality
  - [ ] Accept: `image/jpeg`, `image/png`, `image/gif`
- [ ] WADO-RS Thumbnail retrieval:
  - [ ] `GET .../instances/{SOPInstanceUID}/thumbnail` - Thumbnail image
  - [ ] `GET .../series/{SeriesInstanceUID}/thumbnail` - Series representative
  - [ ] `GET /studies/{StudyInstanceUID}/thumbnail` - Study representative
  - [ ] Configurable thumbnail size via viewport parameter
- [ ] WADO-RS Bulk Data retrieval:
  - [ ] `GET {BulkDataURI}` - Retrieve bulk data by URI
  - [ ] Range header support for partial retrieval
  - [ ] Accept header for format negotiation
- [ ] Transfer syntax negotiation:
  - [ ] Accept header with transfer-syntax parameter
  - [ ] Multiple transfer syntax preference via quality values
  - [ ] Handle 406 Not Acceptable responses
- [ ] `DICOMwebClient` retrieve API:
  - [ ] `func retrieveStudy(studyUID: String) async throws -> AsyncStream<DicomFile>`
  - [ ] `func retrieveSeries(studyUID: String, seriesUID: String) async throws -> AsyncStream<DicomFile>`
  - [ ] `func retrieveInstance(...) async throws -> DicomFile`
  - [ ] `func retrieveMetadata(level: QueryRetrieveLevel, ...) async throws -> [DataSet]`
  - [ ] `func retrieveFrames(instanceUID: String, frames: [Int]) async throws -> [Data]`
  - [ ] `func retrieveRendered(..., window: WindowSettings?, viewport: CGSize?) async throws -> CGImage`
  - [ ] `func retrieveThumbnail(...) async throws -> CGImage`
- [ ] Progress reporting for downloads:
  - [ ] Bytes received / total bytes
  - [ ] Instances received / total instances (when known)
- [ ] Cancellation support via Swift Task cancellation

#### Technical Notes
- Reference: PS3.18 Section 10.4 - WADO-RS
- Reference: PS3.18 Section 8 - Multipart MIME encoding
- Reference: PS3.18 Section 9 - Accept Header
- WADO-RS returns multipart/related for multiple objects
- Rendered endpoint applies windowing and color transformations
- Frame numbers are 1-based per DICOM convention
- Consider disk caching for repeated requests

#### Acceptance Criteria
- [ ] Successfully retrieve studies from public DICOMweb servers
- [ ] Multipart response parsing handles varying boundary formats
- [ ] Transfer syntax negotiation selects optimal format
- [ ] Rendered images display correctly with windowing applied
- [ ] Thumbnail generation works at all levels
- [ ] Large study downloads don't cause memory issues (streaming)
- [ ] Unit tests for URL construction and response parsing
- [ ] Integration tests with test DICOMweb servers

---

### Milestone 8.3: QIDO-RS Client - Query Services (v0.8.3)

**Status**: Planned  
**Goal**: Implement DICOMweb query client for searching DICOM objects  
**Complexity**: Medium-High  
**Dependencies**: Milestone 8.1

#### Deliverables
- [ ] QIDO-RS Study queries:
  - [ ] `GET /studies?{query}` - Search studies
  - [ ] Standard query parameters: PatientName, PatientID, StudyDate, etc.
  - [ ] Response as JSON array or multipart XML
- [ ] QIDO-RS Series queries:
  - [ ] `GET /studies/{StudyInstanceUID}/series?{query}` - Search series in study
  - [ ] `GET /series?{query}` - Search series across all studies
  - [ ] Series-level attributes: Modality, SeriesDescription, etc.
- [ ] QIDO-RS Instance queries:
  - [ ] `GET /studies/{StudyInstanceUID}/series/{SeriesInstanceUID}/instances?{query}`
  - [ ] `GET /instances?{query}` - Search instances across all
  - [ ] Instance-level attributes: SOPClassUID, InstanceNumber, etc.
- [ ] Query parameter support:
  - [ ] Exact matching: `PatientID=12345`
  - [ ] Wildcard matching: `PatientName=Smith*`
  - [ ] Date range queries: `StudyDate=20240101-20241231`
  - [ ] Time range queries: `StudyTime=080000-170000`
  - [ ] UID matching: `StudyInstanceUID=1.2.3.4...`
  - [ ] Sequence matching (limited per PS3.18)
- [ ] Query attribute filtering:
  - [ ] `includefield` parameter for requesting specific attributes
  - [ ] `includefield=all` for all available attributes
  - [ ] Default attributes per query level
- [ ] Pagination support:
  - [ ] `limit` - Maximum results to return
  - [ ] `offset` - Starting position
  - [ ] Response headers for total count (if available)
  - [ ] Automatic pagination iteration
- [ ] Fuzzy matching (optional server feature):
  - [ ] `fuzzymatching=true` parameter
  - [ ] Handle servers with/without fuzzy support
- [ ] `DICOMwebClient` query API:
  - [ ] `func searchStudies(query: QIDOQuery) async throws -> QIDOStudyResults`
  - [ ] `func searchSeries(studyUID: String?, query: QIDOQuery) async throws -> QIDOSeriesResults`
  - [ ] `func searchInstances(studyUID: String?, seriesUID: String?, query: QIDOQuery) async throws -> QIDOInstanceResults`
- [ ] `QIDOQuery` builder:
  - [ ] Fluent API for building queries
  - [ ] Type-safe attribute setters
  - [ ] Date/Time range builders
  - [ ] Wildcard helpers
- [ ] `QIDOResults` types:
  - [ ] `QIDOStudyResults` with study-level attributes
  - [ ] `QIDOSeriesResults` with series-level attributes
  - [ ] `QIDOInstanceResults` with instance-level attributes
  - [ ] Pagination info (hasMore, nextOffset)
  - [ ] Type-safe attribute accessors

#### Technical Notes
- Reference: PS3.18 Section 10.6 - QIDO-RS
- Reference: PS3.18 Section 8 - Query Parameters
- QIDO-RS uses HTTP GET with query parameters
- Response typically JSON array of matching results
- Server may limit results; check X-Total-Count header
- Wildcard (*) matches any sequence of characters
- Date format: YYYYMMDD or YYYYMMDD-YYYYMMDD

#### Acceptance Criteria
- [ ] Successfully query studies from public DICOMweb servers
- [ ] All query parameter types work correctly
- [ ] Pagination handles large result sets
- [ ] JSON response parsing extracts all attributes
- [ ] Query builder produces valid URLs
- [ ] Integration tests with test DICOMweb servers

---

### Milestone 8.4: STOW-RS Client - Store Services (v0.8.4)

**Status**: Planned  
**Goal**: Implement DICOMweb store client for uploading DICOM objects  
**Complexity**: Medium  
**Dependencies**: Milestone 8.1

#### Deliverables
- [ ] STOW-RS Study store:
  - [ ] `POST /studies` - Store instances (auto-create study)
  - [ ] `POST /studies/{StudyInstanceUID}` - Store to specific study
  - [ ] Multipart request body for multiple instances
- [ ] Content-Type handling:
  - [ ] `multipart/related; type="application/dicom"` - DICOM Part 10 files
  - [ ] `multipart/related; type="application/dicom+json"` - JSON with bulk data
  - [ ] `multipart/related; type="application/dicom+xml"` - XML with bulk data
- [ ] Request construction:
  - [ ] Multipart boundary generation
  - [ ] Part headers (Content-Type, Content-Location)
  - [ ] Efficient body streaming for large files
- [ ] Response handling:
  - [ ] Parse STOW-RS response (JSON or XML)
  - [ ] Success: 200 OK with stored instance references
  - [ ] Partial success: 202 Accepted with warnings
  - [ ] Failure: 4xx/5xx with error details
  - [ ] Per-instance status from response
- [ ] `STOWResponse` struct:
  - [ ] Successfully stored instances (ReferencedSOPSequence)
  - [ ] Failed instances (FailedSOPSequence) with reasons
  - [ ] Warning messages
  - [ ] Retrieve URL for stored instances
- [ ] Batch store operations:
  - [ ] Store multiple instances in single request
  - [ ] Configurable batch size (for server limits)
  - [ ] Progress reporting for batch uploads
- [ ] `DICOMwebClient` store API:
  - [ ] `func storeInstances(instances: [Data], studyUID: String?) async throws -> STOWResponse`
  - [ ] `func storeInstance(dicomData: Data, studyUID: String?) async throws -> STOWResponse`
  - [ ] `func storeAsJSON(dataset: DataSet, bulkData: [BulkData], ...) async throws -> STOWResponse`
- [ ] Progress reporting:
  - [ ] Bytes uploaded / total bytes
  - [ ] Per-file progress for batch operations
- [ ] Error handling:
  - [ ] Request too large (413 status)
  - [ ] Unsupported media type (415 status)
  - [ ] Conflict (409 status) - instance already exists
  - [ ] Storage quota exceeded

#### Technical Notes
- Reference: PS3.18 Section 10.5 - STOW-RS
- Reference: PS3.18 Section 8 - Multipart MIME
- STOW-RS uses HTTP POST with multipart body
- Response contains SOP Instance references and status
- Servers may limit request size; consider chunking
- Study UID in URL must match Study UID in instances

#### Acceptance Criteria
- [ ] Successfully store single and batch instances
- [ ] Multipart request generation is compliant
- [ ] Response parsing extracts success/failure details
- [ ] Large file uploads don't cause memory issues
- [ ] Progress reporting is accurate
- [ ] Integration tests with test DICOMweb servers

---

### Milestone 8.5: DICOMweb Server - WADO-RS/QIDO-RS (v0.8.5)

**Status**: Planned  
**Goal**: Implement DICOMweb server for serving DICOM objects over HTTP  
**Complexity**: High  
**Dependencies**: Milestone 8.1, Milestone 8.2, Milestone 8.3

#### Deliverables
- [ ] HTTP server foundation:
  - [ ] Built on SwiftNIO HTTP server or Vapor/Hummingbird
  - [ ] Route registration for DICOMweb endpoints
  - [ ] Request parsing and response generation
  - [ ] Async handler support
- [ ] WADO-RS endpoints:
  - [ ] `GET /studies/{studyUID}` - Retrieve study
  - [ ] `GET /studies/{studyUID}/series/{seriesUID}` - Retrieve series
  - [ ] `GET .../instances/{instanceUID}` - Retrieve instance
  - [ ] `GET .../metadata` - Retrieve metadata (JSON/XML)
  - [ ] `GET .../frames/{frames}` - Retrieve frames
  - [ ] `GET .../rendered` - Retrieve rendered image
  - [ ] `GET .../thumbnail` - Retrieve thumbnail
  - [ ] `GET {bulkDataURI}` - Retrieve bulk data
- [ ] QIDO-RS endpoints:
  - [ ] `GET /studies` - Search studies
  - [ ] `GET /studies/{studyUID}/series` - Search series
  - [ ] `GET .../instances` - Search instances
  - [ ] Query parameter parsing
  - [ ] Pagination via limit/offset
- [ ] Content negotiation:
  - [ ] Parse Accept header
  - [ ] Select best matching media type
  - [ ] Return 406 Not Acceptable when no match
  - [ ] Transfer syntax parameter handling
- [ ] Storage backend abstraction:
  - [ ] `DICOMwebStorageProvider` protocol
  - [ ] Methods for retrieve, query, store
  - [ ] File system implementation
  - [ ] In-memory implementation (for testing)
  - [ ] SQLite-backed index for queries
- [ ] Image rendering pipeline:
  - [ ] Window/level application
  - [ ] Viewport scaling
  - [ ] JPEG/PNG encoding
  - [ ] Thumbnail generation
  - [ ] Caching for rendered images
- [ ] `DICOMwebServer` API:
  - [ ] `init(configuration: DICOMwebServerConfiguration, storage: DICOMwebStorageProvider)`
  - [ ] `func start() async throws`
  - [ ] `func stop() async`
  - [ ] `var port: Int { get }`
  - [ ] `var baseURL: URL { get }`
- [ ] `DICOMwebServerConfiguration`:
  - [ ] Port and bind address
  - [ ] Base URL path prefix
  - [ ] TLS configuration
  - [ ] CORS settings
  - [ ] Rate limiting
  - [ ] Maximum response size

#### Technical Notes
- Reference: PS3.18 Section 10.4 (WADO-RS), 10.6 (QIDO-RS)
- Server must handle concurrent requests efficiently
- Consider lazy loading for large studies
- Index required for efficient queries (by Patient, Study Date, etc.)
- Rendered endpoint requires pixel data processing from Milestone 3/4
- Caching reduces CPU load for repeated rendered requests

#### Acceptance Criteria
- [ ] Server passes basic DICOMweb conformance tests
- [ ] OHIF viewer can connect and display images
- [ ] Query performance acceptable with 10,000+ instances
- [ ] Concurrent request handling is stable
- [ ] Memory usage is bounded for large studies
- [ ] Unit tests for all endpoints
- [ ] Integration tests with DICOMweb clients

---

### Milestone 8.6: DICOMweb Server - STOW-RS (v0.8.6)

**Status**: Planned  
**Goal**: Implement DICOMweb server for receiving DICOM objects over HTTP  
**Complexity**: High  
**Dependencies**: Milestone 8.5

#### Deliverables
- [ ] STOW-RS endpoints:
  - [ ] `POST /studies` - Store instances
  - [ ] `POST /studies/{studyUID}` - Store to specific study
  - [ ] Multipart request parsing
  - [ ] Support for application/dicom and application/dicom+json
- [ ] Request validation:
  - [ ] Content-Type validation
  - [ ] Study UID consistency check
  - [ ] Required attribute validation
  - [ ] SOP Class validation (optional)
- [ ] Response generation:
  - [ ] Success response with ReferencedSOPSequence
  - [ ] Partial success with warnings
  - [ ] Failure response with FailedSOPSequence
  - [ ] Proper HTTP status codes (200, 202, 400, 409, 415)
- [ ] Storage backend integration:
  - [ ] Store received instances to storage provider
  - [ ] Update query index
  - [ ] Handle duplicates (reject or replace)
- [ ] Streaming upload support:
  - [ ] Process multipart parts as they arrive
  - [ ] Memory-efficient for large uploads
  - [ ] Request size limits
- [ ] Store delegate protocol:
  - [ ] `func shouldAcceptInstance(metadata: DataSet) -> Bool`
  - [ ] `func didStoreInstance(sopInstanceUID: String, location: URL)`
  - [ ] `func didFailToStore(sopInstanceUID: String, error: Error)`
- [ ] Duplicate handling configuration:
  - [ ] Reject duplicates (409 Conflict)
  - [ ] Replace existing
  - [ ] Accept and ignore (idempotent)

#### Technical Notes
- Reference: PS3.18 Section 10.5 - STOW-RS
- Multipart parsing must handle varying boundary formats
- Request size limits prevent memory exhaustion
- Index update should be transactional
- Consider async processing for large batches

#### Acceptance Criteria
- [ ] Server accepts STOW-RS uploads from standard clients
- [ ] Multipart parsing handles edge cases
- [ ] Validation rejects invalid requests appropriately
- [ ] Large uploads don't cause memory issues
- [ ] Duplicate handling works per configuration
- [ ] Integration tests with DICOMweb clients

---

### Milestone 8.7: UPS-RS Worklist Services (v0.8.7)

**Status**: Planned  
**Goal**: Implement Unified Procedure Step RESTful Services for worklist management  
**Complexity**: Very High  
**Dependencies**: Milestone 8.5, Milestone 8.6

#### Deliverables
- [ ] UPS-RS Worklist Query (client and server):
  - [ ] `GET /workitems` - Search workitems
  - [ ] Query parameters for UPS attributes
  - [ ] Scheduled, In Progress, Completed, Canceled states
- [ ] UPS-RS Worklist Retrieval (client and server):
  - [ ] `GET /workitems/{workitemUID}` - Retrieve specific workitem
  - [ ] JSON/XML metadata response
- [ ] UPS-RS Worklist Creation (client and server):
  - [ ] `POST /workitems` - Create new workitem
  - [ ] `POST /workitems/{workitemUID}` - Create with specific UID
  - [ ] Required UPS attributes validation
- [ ] UPS-RS State Management (client and server):
  - [ ] `PUT /workitems/{workitemUID}/state` - Change state
  - [ ] State transitions: SCHEDULED → IN PROGRESS → COMPLETED/CANCELED
  - [ ] Transaction UID tracking
  - [ ] Performer information
- [ ] UPS-RS Cancellation:
  - [ ] `PUT /workitems/{workitemUID}/cancelrequest` - Request cancellation
  - [ ] Cancellation request dataset
- [ ] UPS-RS Subscription (Event Service):
  - [ ] `POST /workitems/{workitemUID}/subscribers/{AETitle}` - Subscribe
  - [ ] `DELETE /workitems/{workitemUID}/subscribers/{AETitle}` - Unsubscribe
  - [ ] `POST /workitems/1.2.840.10008.5.1.4.34.5/subscribers/{AETitle}` - Global subscription
  - [ ] WebSocket event delivery
  - [ ] Long polling fallback
- [ ] UPS Event Types:
  - [ ] UPS State Report (state changes)
  - [ ] UPS Progress Report (progress updates)
  - [ ] UPS Cancel Requested
  - [ ] UPS Assigned
  - [ ] UPS Completed/Canceled
- [ ] Workitem data model:
  - [ ] `Workitem` struct with UPS attributes
  - [ ] Scheduled Procedure Step attributes
  - [ ] Performed Procedure Step attributes
  - [ ] Progress information
- [ ] `UPSClient` API:
  - [ ] `func searchWorkitems(query: UPSQuery) async throws -> [Workitem]`
  - [ ] `func retrieveWorkitem(uid: String) async throws -> Workitem`
  - [ ] `func createWorkitem(workitem: Workitem) async throws -> String`
  - [ ] `func changeState(uid: String, state: UPSState, transaction: String?) async throws`
  - [ ] `func requestCancellation(uid: String, reason: String?) async throws`
  - [ ] `func subscribe(uid: String?, events: AsyncStream<UPSEvent>) async throws`
- [ ] `UPSServer` additions:
  - [ ] Workitem storage and retrieval
  - [ ] State machine enforcement
  - [ ] Event generation and delivery
  - [ ] Subscription management

#### Technical Notes
- Reference: PS3.18 Section 11 - UPS-RS
- Reference: PS3.4 Annex CC - Unified Procedure Step Service
- UPS is used for worklist management and workflow orchestration
- State transitions must follow defined state machine
- Events enable real-time workflow coordination
- WebSocket preferred for low-latency event delivery

#### Acceptance Criteria
- [ ] UPS worklist operations work correctly
- [ ] State machine enforces valid transitions only
- [ ] Events are delivered reliably
- [ ] Subscription management handles multiple subscribers
- [ ] Integration tests with UPS-aware systems

---

### Milestone 8.8: Advanced DICOMweb Features (v0.8.8)

**Status**: Planned  
**Goal**: Production-ready DICOMweb with security and advanced features  
**Complexity**: High  
**Dependencies**: Milestone 8.7

#### Deliverables
- [ ] OAuth2/OpenID Connect Authentication:
  - [ ] Client credentials flow
  - [ ] Authorization code flow
  - [ ] Token refresh handling
  - [ ] Bearer token injection
  - [ ] SMART on FHIR compatibility
- [ ] Server authentication middleware:
  - [ ] Token validation
  - [ ] JWT parsing and verification
  - [ ] Role-based access control
  - [ ] Study-level access control
- [ ] HTTPS/TLS Configuration:
  - [ ] TLS 1.2/1.3 support
  - [ ] Certificate management
  - [ ] Client certificate authentication (mTLS)
- [ ] Capability Discovery:
  - [ ] `GET /` or `GET /capabilities` - Server capabilities
  - [ ] Supported services and endpoints
  - [ ] Supported transfer syntaxes
  - [ ] Conformance statement generation
- [ ] Extended Negotiation:
  - [ ] `accept-charset` parameter handling
  - [ ] Compression (gzip, deflate) for responses
  - [ ] ETag and conditional requests
  - [ ] Range requests for partial content
- [ ] Caching:
  - [ ] Cache-Control header support
  - [ ] ETag generation and validation
  - [ ] Client-side caching utilities
  - [ ] Server-side response caching
- [ ] Performance Optimizations:
  - [ ] Connection pooling (HTTP/2 multiplexing)
  - [ ] Request pipelining
  - [ ] Prefetching for likely requests
  - [ ] Response streaming
- [ ] Monitoring and Logging:
  - [ ] Request/response logging
  - [ ] Performance metrics (latency, throughput)
  - [ ] Error rate tracking
  - [ ] OSLog integration
- [ ] CORS Configuration (Server):
  - [ ] Allowed origins configuration
  - [ ] Preflight request handling
  - [ ] Credentials support
- [ ] Delete Services (optional per PS3.18):
  - [ ] `DELETE /studies/{studyUID}` - Delete study
  - [ ] `DELETE .../series/{seriesUID}` - Delete series
  - [ ] `DELETE .../instances/{instanceUID}` - Delete instance
  - [ ] Soft delete vs. permanent delete
- [ ] `DICOMwebClient` unified API:
  - [ ] Single client for all DICOMweb services
  - [ ] Configuration with authentication, caching, retry
  - [ ] Automatic token refresh
  - [ ] Request interceptors for customization

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
- [ ] HTTPS connections are secure (no vulnerabilities)
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
