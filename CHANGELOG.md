# Changelog

All notable changes to DICOMKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — WADORetrieveConsoleFormatter (Shared WADO-RS / WADO-URI Retrieve Renderer)

- **`WADORetrieveConsoleFormatter`** (`Sources/DICOMWeb/WADORetrieveConsoleFormatter.swift`): Shared output renderer for WADO-RS / WADO-URI retrieve — verbose preamble blocks, per-mode status lines (metadata / rendered / thumbnail / frames / instances / WADO-URI result), and the metadata body (JSON pretty-printed + PS3.19 Native DICOM Model XML). Mirrors `QIDOResultFormatter` (query) and `UPSResultFormatter` (ups): a SINGLE formatter both sides call, so the `dicom-wado retrieve` CLI binary and DICOMStudio's in-app retrieve cannot produce different output.
  - `DICOMWado.swift` (`RetrieveCommand`) now delegates all verbose preamble, per-mode status, and metadata body output to `WADORetrieveConsoleFormatter` instead of hand-rolling inline strings.
  - `CLIWorkshopViewModel.swift` (WADO retrieve case) likewise delegates to the formatter; the mode-detection / inline-echo block is removed, and the verbose preamble is gated by `--verbose` on both sides identically.
  - `parseFrameNumbers` moved from `RetrieveCommand` into `WADORetrieveConsoleFormatter` (as a throwing method returning `[Int]`) with a companion `WADOFrameParseError` type; the CLI catches `WADOFrameParseError` and re-throws as `ValidationError`.

### Added — STOWResultFormatter (Shared WADO STOW-RS Upload Renderer)

- **`STOWResultFormatter`** (`Sources/DICOMWeb/STOWResultFormatter.swift`): Shared console renderer for `dicom-wado store` (STOW-RS) upload output — verbose pre-upload header, per-batch start/result lines, per-failure detail, and the always-printed final summary block. Both the `dicom-wado store` CLI path and DICOMStudio's in-app STOW upload call this single formatter, preventing output pipeline drift. The summary block format is a parity contract that `CLIParityWADOComparator.parseStore` anchors on.

### Added — UPS-RS Parity Harness: Full Operation Matrix, Global Subscribe, and get --format/--verbose

- **UPS write scenarios run out-of-the-box**: The parity harness no longer gates the full UPS operation matrix on a user-supplied Procedure Step Label. A `upsDefaultLabel` (`"CLI Parity Workitem"`) is substituted when the WADO panel's label is blank, so `ups-lifecycle`, `ups-lifecycle-complete`, `ups-lifecycle-cancel`, `ups-get`, `ups-create-attrs`, `ups-create-json`, and `ups-subscribe` always appear in the scenario list — matching how the harness already auto-picks the AE title and station filter.
- **Global UPS subscribe scenario** (`ups-subscribe-global`): New `runWADOUPSSubscribeGlobalScenario` runner exercises `ups --subscribe --aet <ae>` (no `--workitem-uid`) → `ups --unsubscribe --aet <ae>` — the GLOBAL round-trip that subscribes to ALL workitems' events. Reference uses `DICOMwebClient.subscribeToAllWorkitems` + `unsubscribeFromWorkitem(nil)`. Parity on round-trip outcome; servers that don't enable UPS subscription fail both sides identically (`failureAgreement`).
- **ups-get `--format` / `--verbose` variants**: Four `--format` flag variants (`table`, `json`, `csv`) plus a `--verbose` variant are now generated for the `ups-get` scenario. The flags are threaded through `studioParams["get-format"]` and `"get-verbose"` and appended at run time (after the Workitem UID is known), mirroring how the CLI appends them to the chained `ups --get <uid>` command.
- **Transaction UID flow corrected**: The UPS lifecycle runner (`runWADOUPSLifecycleScenario`) no longer pre-mints a Transaction UID and supplies it to the `--update --state IN_PROGRESS` claim. Instead it lets the server assign one, parses it from the CLI's IN PROGRESS output (`Transaction UID: …`), and reuses it for the terminal `COMPLETED`/`CANCELED` transition — exactly how a real operator works. The reference (`CLIParityNetworkReference.wadoUPSLifecycle`) likewise captures and reuses `claimResp.transactionUID`. When no UID is returned the terminal transition is skipped and recorded as not reached.
- **`wadoUPSSubscribeGlobal`** reference method added to `CLIParityNetworkReference`: calls `client.subscribeToAllWorkitems` + `client.unsubscribeFromWorkitem(nil)`; `createOK` is vacuously true (no workitem is created).

### Changed — C-GET and dicom-send Dry-Run Comparators Aligned with Shared Formatters

- **C-GET comparator** (`CLIParityRetrieveComparator`): The shared `NetworkConsole.cGetSummary` now emits exactly one terse line — `"✅ C-GET completed — N file(s) received"` on success or `"⚠️ C-GET completed but received 0 instances. …"` when nothing arrived — instead of a structured `C-GET Completed:` block with sub-operation counts. The parser now reads the received-file count from that line only; `completed`/`failed` are no longer parsed or compared for C-GET (they are unobservable in the CLI text). `canonical()` updated accordingly: C-GET compares `success + files`; C-MOVE still compares `completed + failed + warning`.
- **dicom-send dry-run comparator** (`CLIParitySendComparator`): The shared formatter's dry-run path (`NetworkConsole.sendHeader`) prints the gathered file count in the header's `"Files: N"` field rather than `"Found N file(s) to send"`. The parser now reads the first `"Files:"` line — the header count — rather than `"Found"`.

### Changed — UPS CLI Workshop: unsubscribe Operation and Simplified cliMapping

- **`unsubscribe` operation added** to the UPS parameter definition in `CLIWorkshopHelpers`: the operation picker now lists `search`, `get`, `create-workitem`, `change-state`, `subscribe`, `unsubscribe`. `--workitem-uid` is shown for `unsubscribe` as well as `subscribe` and `create-workitem`.
- **`--search` and `--create-workitem` moved to `cliMapping`**: Both flags are now emitted automatically when the matching operation tab is selected, removing the separate boolean-toggle `CLIParameterDefinition` entries that were previously needed. This mirrors the existing `--subscribe`/`--unsubscribe` mapping pattern.
- **No auto-pre-selection in Network mode**: Switching to Network mode no longer pre-selects the first network tool. The user explicitly picks which tools to include in the parity sweep.

### Fixed — HL7 ORM^O01 Field Placement for dcm4chee-arc MWL Create

- **HL7 ORM IPC segment + OBR field map corrected** (`ModalityWorklistService.buildHL7ORM`): The previous implementation wrote `scheduledStationAETitle` into `OBR-20`, which dcm4chee-arc's default inbound order stylesheet (`hl7-order2dcm.xsl`) reads as the **Scheduled Procedure Step ID** (`0040,0009`) — so a user's Station AET surfaced on the server as the SPS ID. Fixed in two ways:
  - **OBR path corrected**: rebuilt with an explicit index→value map (`hl7Segment(_:fields:)` helper) so the values land at their exact positions. OBR-18 = Accession Number, OBR-19 = Requested Procedure ID, OBR-20 = SPS ID, OBR-24 = Modality, OBR-27 4th component = SPS Start Date/Time.
  - **IPC segment added**: a dcm4che-private `IPC` (Imaging Procedure Control) segment is emitted after OBR so every SPS attribute has an unambiguous, configuration-independent slot — **IPC-7 = Station Name**, **IPC-9 = Scheduled Station AE Title** (the only ORM path that carries them). IPC-1/2/3 also supply Accession / Requested Procedure ID / Study Instance UID, matching the OBR fallback exactly.
  - `buildHL7ORM` promoted from `private` to `internal` to allow the new field-placement regression tests (`Tests/DICOMStudioTests/MWLCreateHL7ORMTests.swift`) to assert each value's exact HL7 position without requiring a live MLLP server.

### Fixed — WADO-URI Endpoint Resolution for dcm4chee5

- **`WADOURIClient.resolveURIEndpoint(_:)`** (new public static method): dcm4chee-arc 5.x serves WADO-URI (`?requestType=WADO`) from `/wado`, while the sibling WADO-RS/QIDO-RS endpoint lives at `/rs`. Supplying a WADO-RS base URL for a WADO-URI request returned HTTP 404. The resolver rewrites a trailing `/rs` path segment to `/wado`; all other base URLs are returned unchanged. Because the `dicom-wado` CLI, CLI Workshop, and parity reference all retrieve through this one client, they resolve identically and cannot drift.

### Fixed — dicom-mpps N-CREATE Status Guard

- **`dicom-mpps create --status` validation**: N-CREATE must always start the step `IN PROGRESS`; the previous code accepted `COMPLETED` or `DISCONTINUED` at creation, which servers reject (terminal states are reached only via N-SET). The `create` subcommand now validates that `--status` is `IN PROGRESS` and emits a clear `ValidationError` directing the user to `dicom-mpps update` for state transitions.

### Added — UPS-RS Result Formatter (Shared)

- **`UPSResultFormatter`** (`Sources/DICOMWeb/UPSResultFormatter.swift`): Shared output renderer for UPS-RS worklist search results — table, JSON (`UPSOutputFormat`), and CSV — used by both the `dicom-wado ups --search` CLI path and DICOMStudio's in-app UPS worklist search. Mirrors `QIDOResultFormatter` (QIDO-RS) and `DICOMQueryResultFormatter` (DIMSE): a single formatter both sides call so their output pipelines cannot drift.

### Added — CLI Workshop PACS Server Edit

- **Edit saved PACS server profiles**: The CLI Workshop saved-server list now supports in-place editing (`beginEditServer(id:)` / `saveEditedServer()` on `CLIWorkshopViewModel`). A new `showEditServerSheet` / `editingServerID` pair drives the edit sheet; saving re-applies the updated values when the edited profile is currently selected. Previously only add and delete were supported.

### Changed — NetworkConsole Shared Formatter Covers All Network CLIs

- **`NetworkConsole` (DICOMNetwork) now covers all DIMSE network tools**: `dicom-echo`, `dicom-mwl` (query), and `dicom-mpps` joined the shared formatter, completing the set started with `dicom-query / dicom-send / dicom-retrieve / dicom-qr / dicom-wado`. All human console output — headers, per-echo progress, summaries, verbose details — routes through one `NetworkConsole` method on both the CLI binary and the DICOMStudio CLI Workshop in-process path, making terminal-compare diff drift impossible by construction.
- **`dicom-send/ProgressReporter.swift` removed**: its logic was absorbed into `NetworkConsole`. Any callers that imported it directly must switch to the corresponding `NetworkConsole.*` methods.

### Added — Network CLI & DICOMweb Tests

- **`MWLCreateHL7ORMTests`** (`Tests/DICOMStudioTests/`): Regression tests asserting each value in the HL7 ORM^O01 message built by `ModalityWorklistService.buildHL7ORM` lands at its exact field position in both the OBR fallback path and the IPC segment, so the field-placement bug (`OBR-20` Station AET mismap) cannot silently return.
- **`UPSTests`** (`Tests/DICOMWebTests/`): Coverage for UPS-RS workitem query parsing and the new `UPSResultFormatter` output (table/JSON/CSV).
- **`WADOURIClientTests`** (`Tests/DICOMWebTests/`): Coverage for `WADOURIClient.resolveURIEndpoint` (no-op for `/wado`, rewrite for `/rs`, passthrough for other paths) and WADO-URI URL building.

### Added — Network Utility (Live Terminal Output)

- **Network Utility panel** (`NetworkUtilityView`, `NetworkUtilityViewModel`, `NetworkUtilityService`): Six-tab general-purpose network diagnostics tool surfaced as a new sidebar destination in DICOMStudio.
  - **Ping** — wraps `/sbin/ping`; live per-packet output streams into a terminal panel, parsed summary (min/avg/max RTT, packet loss) replaces it on completion.
  - **Port Scanner** — concurrent TCP probes via `NWConnection`; results append in arrival order for a live scan log, sorted by port number on completion.
  - **Traceroute** — wraps `/usr/sbin/traceroute`; each hop line streams as it resolves; stderr merged into stdout so the `traceroute to …` header appears at the top in real time.
  - **DNS Lookup** — wraps `/usr/bin/dig` per selected record type (A, AAAA, MX, TXT, NS, CNAME, SOA, PTR); each query echoes a `$ dig …` header then streams its answer block.
  - **Interfaces** — lists all network interfaces with IPv4/IPv6 addresses, MAC address, MTU, flags, and status badges.
  - **Netstat** — wraps `/usr/sbin/netstat`; streams TCP/UDP connections or routing table live; parsed counts (listening/established/routes) shown on completion.
- **Shared host input**: A single `sharedHost` field is shared by the Ping, Port Scanner, and Traceroute tabs — typing a host in any one of them pre-fills the others.
- **`AsyncStream<String>`-based live streaming** (`runStreamingProcess`): All five process-based tools share a single streaming process runner; stdout and stderr are merged into one pipe so output arrives in natural order, then yielded chunk-by-chunk via `AsyncStream`.
- **UTF-8 carry-over buffer**: A `var pending = Data()` accumulator in the `availableData` read loop ensures multibyte characters (IDN hostnames, TXT/PTR record content) are never split and silently dropped between reads.
- **Run-identity guard** (`streamGeneration` / `portScanGeneration`): Each run captures a generation counter; `onChunk` closures and completion assignments check `self.streamGeneration == gen` and discard stale deliveries from cancelled or superseded runs.
- **SIGKILL escalation**: Both the wall-clock watchdog and `ProcessKillBox.cancel()` send SIGTERM then escalate to SIGKILL after a 3-second grace period, preventing hung processes from blocking the UI indefinitely.
- **Watchdog liveness guard**: The watchdog `DispatchWorkItem` checks `proc.isRunning` before acting, preventing a process that exits naturally at the deadline from being mislabelled as timed out.

### Added — J2KSwift v3.2.0 Integration (Phases 1–9)

- **J2KSwift v3.2.0 codec stack** (`Sources/DICOMCore/J2KSwiftCodec.swift`, `HTJ2KCodec.swift`, `JP3DCodec.swift`): Replaces Apple ImageIO as the primary JPEG 2000 path on all platforms, enabling full Linux support via a pure-Swift scalar backend.
  - `J2KSwiftCodec`: Handles JPEG 2000 Lossless (`.90`), JPEG 2000 Lossy (`.91`), Part 2 Lossless (`.92`), Part 2 Lossy (`.93`) with 8/12/16-bit grayscale and RGB support.
  - `HTJ2KCodec`: Full HTJ2K Lossless (`.201`), HTJ2K RPCL Lossless (`.202`), HTJ2K Lossy (`.203`). Fast-path transcoder via `J2KTranscoder` (no pixel decode); 5.4× decode speedup over J2K on macOS arm64.
  - `JP3DCodec`: ISO/IEC 15444-10 volumetric encoding/decoding for multi-frame CT/MR/PET series with lossless, lossless-HTJ2K, and lossy modes.
- **JPIP streaming** (`Sources/DICOMKit/DICOMJPIPClient.swift`): Progressive 2D and 3D tile streaming for large remote studies; transfer syntaxes JPIP Referenced (`.94`) and JPIP Referenced Deflate (`.95`) registered.
  - `dicom-jpip` CLI tool with `fetch`, `uri`, `serve`, and `info` subcommands.
  - `DICOMFile.openVolumeProgressively(serverURL:sliceJPIPURIs:qualityLayers:)` API for huge CT/MR datasets.
- **JP3D volume bridge** (`Sources/DICOMKit/JP3DVolumeBridge.swift`): Converts multi-frame DICOM series ↔ `J2KVolume`; preserves `SliceLocation`, `ImagePositionPatient`, `SeriesInstanceUID`.
  - `JP3DVolumeDocument`: Encapsulated document SOP (private SOP `1.2.826.0.1.3680043.10.511.10`) with `.jp3d` payload + JSON sidecar; MIME type `application/x-jp3d`.
  - `DICOMFile.openVolume(from:)` / `openVolume(from:jpipServerURL:)` for unified volume access.
- **Hardware acceleration** (`CodecBackend` enum): Metal (Apple GPU), Accelerate (SIMD), scalar fallback; `CodecBackendProbe` selects best available at runtime. `--backend` flag on `dicom-compress` and `dicom-3d`.
- **`dicom-j2k` CLI tool** (8 subcommands): `info`, `validate`, `transcode`, `reduce`, `roi`, `benchmark`, `compare`, `completions`. 53 tests.
- **DICOMStudio enhancements**:
  - Progressive decoding with `ProgressiveDecodeModel` / `ProgressiveImageView` (AsyncStream-driven `.quarter → .half → .complete` state machine).
  - ROI decoding wired to pinch-zoom gestures.
  - JP3D MPR views (axial / sagittal / coronal) via `JP3DMPRViewModel` / `JP3DMPRView`.
  - JPIP loader with quality-layer slider.
- **Transfer syntaxes** added to registry, `DICOMValidator`, and `StorageSCP` presentation contexts: `.htj2kLossless`, `.htj2kRPCLLossless`, `.htj2kLossy`, `.jpip`, `.jpipDeflate`, `.jpeg2000Part2Lossless`, `.jpeg2000Part2`.
- **DICOMweb HTJ2K media types**: `image/jph` and `image/jphc` advertised in capability; WADO-RS accept headers updated.
- **`dicom-compress`**, **`dicom-convert`**, **`dicom-send`**, **`dicom-retrieve`**, **`dicom-viewer`**, **`dicom-info`**, **`dicom-validate`** extended for HTJ2K, JP3D, and JPIP transfer syntaxes.
- **Codec Inspector panel** in DICOMStudio: shows decoder name, backend (Metal/Accelerate/scalar), and decode timing.

### Fixed
- **JPEG 2000 16-bit rendering pipeline**: Fixed near-black output after conversion when preserving original bit depth
  - Normalized ImageIO-decoded 16-bit JPEG 2000 samples back to the DICOM `Bits Stored` range in `NativeJPEG2000Codec`
  - Preserved original metadata for JPEG 2000 and JPEG 2000 Lossless conversions (`BitsAllocated`, `BitsStored`, `HighBit`)
  - Verified CT-style datasets with VOI/Rescale tags render correctly after implicit VR → JPEG 2000 lossless transcoding

- **DICOM Studio metadata consistency**: Fixed transfer syntax source ordering in metadata loading
  - `MetadataViewModel` now prefers File Meta Information `(0002,0010)` before dataset fallback
  - Aligns metadata display behavior with converted-file transfer syntax as stored on disk

- **Test Infrastructure**: Fixed platform-specific test compilation errors
  - Added `#if canImport(CoreGraphics)` guards to ColorTransformTests for Apple platform-only APIs
  - Fixed DataElement initializer calls in ICCProfileAdvancedTests with missing length parameters
  - Fixed ambiguous type references in SegmentationParserTests
  - Tests now compile cleanly on Linux CI runners and Apple platforms

### Changed - DICOM Standard Edition Update
- **Updated DICOM standard reference from 2025e to 2026a**
  - The 2026a release is now the current edition available at https://www.dicomstandard.org/current/
  - Updated `dicomStandardEdition` constant to "2026a"
  - Updated all source code doc comments referencing DICOM PS3.x editions
  - Updated conformance statement, FAQ, contributing guide, and README
  - Key differences from 2025e to 2026a:
    - New supplements including CT Image Storage for Processing (Sup252)
    - Radiation Dose Structured Report (RDSR) informative annex (Sup245)
    - Enhanced DICOMweb services (Sup248, Sup228)
    - Data dictionary and controlled terminology updates
    - Correction proposals addressing encoding clarifications and CID additions
    - Improved sex and gender data representation
    - Frame Deflate transfer syntax enhancements for segmentation encoding

## [1.2.6] - 2026-02-07

### Added - Phase 5 CLI Tools Complete
- **dicom-mpps (v1.2.6)**: Modality Performed Procedure Step (MPPS) operations
  - N-CREATE operation for creating MPPS instances (procedure start)
  - N-SET operation for updating MPPS instances (procedure completion/discontinuation)
  - Support for IN PROGRESS, COMPLETED, and DISCONTINUED states
  - Referenced SOP instance tracking
  - MPPSService in DICOMNetwork module
  - Complete CLI tool with create and update subcommands
  - Documentation and README

## [1.2.5] - 2026-02-07

### Added - Phase 5 CLI Tools
- **dicom-mwl (v1.2.5)**: Modality Worklist Management
  - C-FIND query support for Modality Worklist Information Model
  - WorklistQueryKeys with flexible filtering (date, station AET, patient, modality)
  - JSON output support for automation
  - Verbose mode for detailed attribute display
  - ModalityWorklistService in DICOMNetwork module
  - Complete CLI tool with query subcommand
  - Documentation and README

## [1.0.0] - TBD

### Major Release - Production Ready

This is the first production-ready release of DICOMKit, a pure Swift DICOM toolkit for Apple platforms (iOS 17+, macOS 14+, visionOS 1+).

### Core Features (v0.1-v0.5)

#### DICOM File Support
- **Reading & Parsing**: Full support for reading DICOM files with comprehensive parsing
- **Transfer Syntaxes**: 
  - Explicit VR Little Endian (1.2.840.10008.1.2.1)
  - Implicit VR Little Endian (1.2.840.10008.1.2)
  - Explicit VR Big Endian (1.2.840.10008.1.2.2)
  - Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99)
- **Data Types**: All standard DICOM Value Representations (VR) supported
- **Specialized Types**: Date, Time, DateTime, AgeString, PersonName, UniqueIdentifier, etc.
- **Writing**: Create and modify DICOM files with proper serialization
- **UID Generation**: Utilities for creating unique DICOM identifiers

#### Pixel Data Support (v0.3-v0.4)
- **Uncompressed Images**: Support for all standard photometric interpretations
  - MONOCHROME1, MONOCHROME2
  - RGB, PALETTE COLOR
- **Compressed Images**: Native codec support for:
  - JPEG Baseline (Process 1)
  - JPEG Extended (Process 2 & 4)
  - JPEG Lossless & JPEG Lossless SV1
  - JPEG 2000 (Lossless and Lossy)
  - RLE Lossless (pure Swift implementation)
- **Multi-frame Support**: Handle image sequences
- **CGImage Rendering**: Native Apple platform integration for display
- **Windowing**: Window Center/Width support for grayscale images

### Networking Features (v0.6-v0.7)

#### DICOM Network Protocol (DIMSE)
- **Core Infrastructure**: PDU handling, association management
- **C-ECHO**: Verification service for connectivity testing
- **C-FIND**: Query services for searching DICOM archives (Patient, Study, Series, Image levels)
- **C-MOVE & C-GET**: Retrieve services for fetching studies and images
- **C-STORE**: Storage services (SCU and SCP)
  - Single file and batch storage operations
  - Progress tracking with AsyncSequence
  - Storage SCP for receiving files
- **Storage Commitment**: N-ACTION based commitment verification
- **Advanced Features**:
  - TLS/SSL support for secure connections
  - Connection pooling and reuse
  - Association timeout configuration
  - Asynchronous API with Swift Concurrency

### DICOMweb Services (v0.8)

#### RESTful Web Services
- **WADO-RS**: Retrieve studies, series, and instances via HTTP
  - Multi-part response parsing
  - Metadata retrieval
  - Rendered image support
- **QIDO-RS**: Query services over HTTP
  - Study, series, and instance queries
  - Fuzzy matching support
  - Pagination with limit/offset
- **STOW-RS**: Store instances via HTTP multipart upload
  - Batch upload support
  - Progress tracking
- **UPS-RS**: Unified Procedure Step worklist services
  - Workitem creation, retrieval, updates
  - State transitions (SCHEDULED → IN PROGRESS → COMPLETED/CANCELED)
  - Subscription support for notifications
- **Authentication**: Bearer token and OAuth2 support
- **TLS**: Secure HTTPS connections with custom certificate validation

### Structured Reporting (v0.9)

#### SR Document Support
- **Core Infrastructure**: SR IOD parsing and document tree navigation
- **Document Types**: Support for all standard SR templates
  - Basic Text SR, Enhanced SR, Comprehensive SR
  - Key Object Selection
  - Measurement reports
  - CAD SR (Chest, Mammography)
- **Content Items**: All relationship types and value types supported
- **Coded Terminology**: SNOMED CT, LOINC, RadLex integration
- **Measurement Extraction**: Automated extraction of measurements and coordinates
- **Document Creation**: SR document builders with template validation
- **Template Support**: TID 1500 (Measurement Report), TID 1400 (Chest CAD SR), and more

### Advanced Features (v1.0.1-v1.0.13)

#### Presentation States
- **Grayscale Presentation State (GSPS)**: Annotations, LUT transformations, spatial transforms
- **Color Presentation State (CSPS)**: Color management, blending operations
- **Pseudo-Color**: Color lookup tables, hot/cold mapping

#### Hanging Protocols
- **Protocol Definition**: Screen layout and viewport configuration
- **Matching Logic**: Image set selection based on modality, anatomy, laterality
- **Display Sets**: Multi-image layout management

#### Radiation Therapy (RT)
- **RT Structure Set**: ROI contours, structure visualization, volume calculation
- **RT Plan**: Beam definitions, treatment machine setup
- **RT Dose**: Dose grids, isodose curves, DVH (Dose-Volume Histogram)

#### Segmentation
- **SEG IOD**: Binary and fractional segmentation support
- **Rendering**: Segment overlay with configurable colors
- **Builder API**: Create segmentation objects programmatically

#### Parametric Maps
- **Quantitative Imaging**: Float pixel data support
- **Real-World Value Mapping**: Physical units, SUV calculation
- **ICC Color Profiles**: Professional color management

#### International Support
- **Character Sets**: ISO 2022, ISO 8859, GB18030, GBK, EUC-KR, Shift_JIS, UTF-8
- **Private Tags**: Vendor-specific tag dictionaries (GE, Siemens, Philips)

#### Performance
- **Memory Optimization**: Efficient large file handling
- **SIMD Acceleration**: Vectorized operations for image processing
- **Lazy Loading**: On-demand pixel data decompression

#### Documentation
- **DocC Catalogs**: Comprehensive API documentation
- **Platform Guides**: iOS, macOS, visionOS integration guides
- **DICOM Conformance**: Formal conformance statement

### Example Applications (v1.0.14)

#### DICOMViewer iOS
- Multi-modality image viewer with gesture controls
- Windowing, pan, zoom, measurements
- Hanging protocol support
- Series browser with thumbnails
- Local file import and PACS integration

#### DICOMViewer macOS
- Removed from the repository.

#### Command-Line Tools
- **dicom-info**: Display DICOM file metadata
- **dicom-dump**: Detailed data element dump
- **dicom-convert**: Transfer syntax conversion
- **dicom-anon**: Anonymization tool
- **dicom-validate**: Conformance validation
- **dicom-query**: PACS query tool
- **dicom-send**: DICOM network send utility

#### Sample Code & Playgrounds
- 27 Xcode Playgrounds demonstrating library features
- Integration examples for iOS, macOS, visionOS
- Network protocol examples
- Image processing examples

### Technical Highlights

- **Pure Swift**: No Objective-C runtime dependencies
- **Swift 6 Compliant**: Full strict concurrency support
- **Platform Native**: Leverages Apple frameworks (ImageIO, CoreGraphics, RealityKit)
- **Modern API**: Swift Concurrency (async/await), Sendable types
- **Comprehensive Testing**: 1,920+ tests across core, networking, and applications
- **Medical Imaging Standards**: DICOM PS3.x compliant

### Platform Support

- **iOS**: 17.0 and later
- **macOS**: 14.0 and later  
- **visionOS**: 1.0 and later
- **Swift**: 6.0 and later

### Dependencies

- Swift Argument Parser 1.3+ (for CLI tools only)

### Installation

#### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/DICOMKit.git", from: "1.0.0")
]
```

### Documentation

- [README.md](README.md) - Overview and quick start
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [MILESTONES.md](MILESTONES.md) - Development roadmap
- [Documentation/](Documentation/) - API documentation and guides

### Known Limitations

- Network integration tests require access to test PACS systems (documented for future)
- Transfer syntax conversion deferred to future versions
- Some advanced character sets deferred (ISO IR 100 extended)
- Store-and-forward networking features deferred

### Security & Privacy

- No known vulnerabilities in dependencies
- HIPAA considerations documented
- PHI (Protected Health Information) handling guidelines provided
- Secure network communication with TLS support

### Breaking Changes

This is the first stable release (v1.0.0). Future breaking changes will only occur in major version updates (2.0, 3.0, etc.).

### Contributors

Built with ❤️ by the DICOMKit team and contributors.

### License

See [LICENSE](LICENSE) file for details.

---

## Pre-release History

For detailed development history of pre-release versions (v0.1 - v0.9, v1.0.1 - v1.0.15), see [MILESTONES.md](MILESTONES.md).

### Notable Pre-release Versions

- **v0.1**: Core infrastructure, basic file parsing
- **v0.2**: Extended transfer syntax support
- **v0.3**: Pixel data access
- **v0.4**: Compressed pixel data
- **v0.5**: DICOM writing
- **v0.6**: Networking (Query/Retrieve)
- **v0.7**: Storage services
- **v0.8**: DICOMweb
- **v0.9**: Structured Reporting
- **v1.0.1-v1.0.13**: Advanced features
- **v1.0.14**: Example applications
- **v1.0.15**: Production release preparation

---

[1.0.0]: https://github.com/Raster-Lab/DICOMKit/releases/tag/v1.0.0
