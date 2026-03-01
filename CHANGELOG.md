# Changelog

All notable changes to DICOMKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
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
- Professional diagnostic workstation
- Multi-monitor support, MPR (Multi-Planar Reconstruction)
- Advanced measurement tools
- PACS query/retrieve integration
- Export and printing capabilities

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
