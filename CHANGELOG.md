# Changelog

All notable changes to DICOMKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — DICOMCLITools shared library & CLI Workshop fixes

- **`DICOMCLITools` shared library** (`Sources/DICOMCLITools/`): Extracted `HexDumper`, `MetadataPresenter`, `TagEditor`, and `DICOMComparer` from their per-tool source trees into a single shared library. All four CLI products (`dicom-dump`, `dicom-info`, `dicom-tags`, `dicom-diff`) and DICOMStudio now link against this library, eliminating code duplication.

- **`HexDumper` improvements**:
  - `dump(data:startOffset:dicomFile:highlightTag:fileBytes:)` — new `fileBytes` parameter allows dumping a slice while resolving highlight/annotation maps against the full file. Slice is re-based internally so 0-based arithmetic never crashes on non-zero `startIndex` Data values.
  - `public static func findElementRange(in:tag:)` — linear Explicit-VR scan for locating any element's on-disk byte range; used as a reliable highlight/annotation fallback when the position-map walker does not reach the target tag.
  - `buildTagPositionMap` rewritten: validates VR bytes against the full Explicit-VR VR set instead of a heuristic element-number filter, handles `0xFFFE` item/delimiter markers, and re-synchronizes on drift via a 1-byte advance when VR bytes are not valid.
  - Highlight rendered with `[XX]` brackets (plain mode) or yellow ANSI (color mode). Annotations now scan the entire 16-byte line and join multiple tags with ` · `.

- **`MetadataPresenter` improvements**:
  - `normalizeFilterTokens(_:)` made `public` so GUI and CLI share identical multi-tag parsing.
  - Multi-tag filter now accepts `--tag 0010,0010,Modality` (comma-separated mixed form) and space-separated forms.

- **`TagEditor` improvement**: When `outputPath` is an existing directory, the input filename is automatically appended so `--output /some/dir` writes `dir/<input>.dcm` instead of failing with "couldn't be saved in the folder".

- **`dicom-dump`**: `dumpTag()` now passes `annotate: annotate` (was hard-coded `false`) and `fileBytes: fileData` to `HexDumper.dump`, fixing `--annotate` and `--highlight` in `--tag` mode. Uses `findElementRange` for reliable tag location.

- **`dicom-diff`**: `parseIgnoreTags` splits each `--ignore-tag` value on whitespace before parsing, allowing `--ignore-tag '0010,0010 0010,0040'` from GUI passthrough.

- **`dicom-tags`**: Built as a separate product (was missing from default build). Directory-aware output path. Operation dropdown in CLI Workshop replaces four separate boxes.

- **CLI Workshop — `dicom-tags`**: Operation (set / delete / delete-private / copy-from) is now a single dropdown. Only the relevant input field is shown per operation via `visibleWhen` conditions. Reduces UI clutter from 9 fields to 4–5.

- **CLI Workshop — `dicom-diff`**: `ignore-tag` field now emits `--ignore-tag X --ignore-tag Y` (one flag per token) in the command preview, matching ArgumentParser's repeatable-flag contract. GUI execution resolves tags via `normalizeFilterTokens` so `0010,0020` is not split into two invalid tokens.

- **`Scripts/install-cli-tools.sh`**: Resolves `SCRIPT_DIR` from `BASH_SOURCE[0]`, validates `Package.swift`, builds all tools including `dicom-gateway` and `dicom-jpip`.

### Fixed

- **`dicom-dump --tag --annotate` crash** (EXC_BAD_ACCESS / trace trap): `Data` slice with non-zero `startIndex` caused `loadUnaligned` to read from offset 0 of the original buffer. Fixed by re-basing slice in `dump()`.
- **`--highlight` not marking main-dataset tags**: Position-map walker used `isValidTagPattern` which rejected elements with `element < 0x0010` (e.g. `ImageType` `(0008,0008)`), drifting the walker so no main-dataset tags were indexed. Fixed with VR-validated scan.
- **`--annotate` only showing File Meta annotations**: Same root cause as above.
- **GUI dicom-tags output error**: "The file 'Output' couldn't be saved in the folder 'DICOMKit_Testing_Files'" when Browse selected a directory. Fixed by auto-appending input filename in `TagEditor.processFile` and `executeDicomTags`.
- **GUI dicom-diff `ignore-tag` not working**: `splitMultiValue` split `0010,0020` on the comma, producing `["0010","0020"]`. Fixed with `normalizeFilterTokens`.
- **`dicom-jpip` Swift 6 Sendable error**: `nonisolated(unsafe)` added to `var result` capture in `waitForTask`.



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
