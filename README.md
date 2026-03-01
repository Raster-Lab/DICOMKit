# DICOMKit

<p align="center">
  <strong>A pure Swift DICOM toolkit for Apple platforms (iOS, macOS, visionOS)</strong>
</p>

<p align="center">
  <a href="https://github.com/Raster-Lab/DICOMKit/actions/workflows/ci.yml"><img src="https://github.com/Raster-Lab/DICOMKit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.2-orange.svg" alt="Swift 6.2"></a>
  <a href="https://developer.apple.com"><img src="https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20visionOS%201-blue.svg" alt="Platforms"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/Tests-2180+-brightgreen.svg" alt="Tests">
  <img src="https://img.shields.io/badge/CLI%20Tools-31+-purple.svg" alt="CLI Tools">
  <img src="https://img.shields.io/badge/DICOM-PS3.x%202026a-informational.svg" alt="DICOM Standard">
</p>

---

## 📑 Table of Contents

<details>
<summary>Click to expand</summary>

- [Overview](#overview)
- [What is DICOM?](#what-is-dicom)
- [Why DICOMKit?](#why-dicomkit)
- [Features](#features-v10)
- [Platform Requirements](#platform-requirements)
- [Installation](#installation)
  - [Swift Package Manager](#swift-package-manager-framework)
  - [Homebrew](#homebrew-cli-tools)
  - [Other Methods](#other-installation-methods)
- [Quick Start](#quick-start)
  - [Reading DICOM Files](#quick-start)
  - [Pixel Data Access](#pixel-data-access-v03)
  - [Error Handling](#error-handling-for-pixel-data-extraction)
  - [Rendering to CGImage](#rendering-to-cgimage-apple-platforms-only)
  - [Grayscale Presentation State](#grayscale-presentation-state-gsps-v101)
  - [DICOM File Writing](#dicom-file-writing-v05)
- [DICOM Networking](#dicom-query-service-v06)
  - [Query Service (C-FIND)](#dicom-query-service-v06)
  - [Retrieve Service (C-MOVE)](#dicom-retrieve-service---c-move-v06)
  - [Retrieve Service (C-GET)](#dicom-retrieve-service---c-get-v06)
  - [Storage Service (C-STORE)](#dicom-storage-service---c-store-v07)
  - [Storage SCP](#dicom-storage-scp---receiving-files-v073)
  - [Batch Storage](#dicom-batch-storage-service-v072)
  - [Print Management](#dicom-print-management-v140-v145)
  - [High-Level API](#dicom-client---unified-high-level-api-v067)
  - [TLS/Secure Connections](#tlssecure-connections-v074)
  - [Error Handling](#network-error-handling-v075)
  - [Validation](#dicom-validation-v076)
  - [Audit Logging](#audit-logging-v075)
- [DICOMweb](#dicomweb-client-v082)
  - [Client](#dicomweb-client-v082)
  - [QIDO-RS Query](#dicomweb-qido-rs-query-client-v083)
  - [Server TLS](#dicomweb-server-tls-configuration-v088)
  - [Conformance Statement](#conformance-statement-generation-v088)
- [Structured Reporting](#sr-document-creation-v096)
  - [Document Creation](#sr-document-creation-v096)
  - [Builders](#using-containerbuilder-for-declarative-construction)
  - [Coded Terminology](#coded-terminology-support-v094)
- [Examples](#examples)
  - [Sample Code Playgrounds](#1-sample-code-playgrounds-new---february-2026)
  - [Integration Templates](#2-integration-templates-new)
  - [Structured Reporting Examples](#3-structured-reporting-examples)
  - [Demo Applications](#demo-applications-v1014)
- [CLI Tools](#cli-tools-reference)
- [Architecture](#architecture)
  - [DICOMCore](#dicomcore-v091-v094-v109-v1010)
  - [DICOMDictionary](#dicomdictionary)
  - [DICOMNetwork](#dicomnetwork-v06-v07-v072-v073-v074-v075-v076-v077-v078-v140)
  - [DICOMKit](#dicomkit-v092-v093-v094-v095-v096-v097-v098-v101-v102-v103-v104-v105-v106-v107-v108-v110-v150-v160-v170)
  - [DICOMWeb](#dicomweb-v081-v082-v083-v084-v085-v086-v087-v088-v180)
- [DICOM Standard Compliance](#dicom-standard-compliance)
- [Limitations](#limitations-v075)
- [Support & Community](#support--community)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

</details>

---

## Overview

DICOMKit is a modern, Swift-native library for reading, writing, and parsing DICOM (Digital Imaging and Communications in Medicine) files. Built with Swift 6 strict concurrency and value semantics, it provides a type-safe, efficient interface for working with medical imaging data on Apple platforms.

**Status**: Production-ready v1.8.0 release with comprehensive DICOM support, example applications, and professional documentation.

### Key Highlights

| Category | Description |
|----------|-------------|
| **🏥 Complete DICOM Support** | Read, write, parse, and render DICOM files with support for 7+ transfer syntaxes |
| **🌐 DICOM Networking** | Full DIMSE support (C-ECHO, C-FIND, C-MOVE, C-GET, C-STORE) with TLS and Print Management (PS3.4 Annex H) |
| **☁️ DICOMweb** | WADO-RS, QIDO-RS, STOW-RS, and UPS-RS client and server implementations |
| **📊 Structured Reporting** | Complete SR document creation with 8 specialized builders |
| **🔬 Advanced Imaging** | RT Structure Sets, Segmentation, Parametric Maps, Presentation States |
| **🛠️ CLI Tools** | 38 command-line tools for DICOM operations, all installable via Homebrew |
| **📱 Demo Applications** | Production-ready viewers for iOS, macOS, and visionOS |
| **⚡ Performance** | SIMD acceleration, memory mapping, connection pooling, and caching |
| **🔒 Security** | TLS 1.2/1.3, OAuth2 support, audit logging, and HIPAA-compliant anonymization |
| **✅ Thoroughly Tested** | 2,180+ unit tests with Swift 6 strict concurrency compliance |

---

## What is DICOM?

**DICOM** (Digital Imaging and Communications in Medicine) is the international standard for medical imaging data and related information. It is used worldwide for storing, transmitting, and sharing medical images and associated data.

### DICOM File Structure

A DICOM file consists of:

```
┌──────────────────────────────────────────────┐
│ File Preamble (128 bytes, usually zeros)     │
├──────────────────────────────────────────────┤
│ DICM Prefix (4 bytes: "DICM")                │
├──────────────────────────────────────────────┤
│ File Meta Information (Group 0x0002)         │
│   • Transfer Syntax UID                      │
│   • Media Storage SOP Class UID              │
│   • Media Storage SOP Instance UID           │
├──────────────────────────────────────────────┤
│ Data Set (Patient, Study, Series, Image)     │
│   • Patient Information (Group 0x0010)       │
│   • Study Information (Group 0x0008, 0x0020) │
│   • Series Information (Group 0x0008)        │
│   • Image Information (Group 0x0028)         │
│   • Pixel Data (Tag 0x7FE0,0x0010)           │
└──────────────────────────────────────────────┘
```

### DICOM Data Elements

Each data element has:
- **Tag**: A (group, element) pair identifying the attribute (e.g., `(0010,0010)` for Patient Name)
- **VR**: Value Representation specifying the data type (e.g., `PN` for Person Name, `DA` for Date)
- **Length**: The number of bytes in the value
- **Value**: The actual data

### Common DICOM Tags

| Tag | Name | Description |
|-----|------|-------------|
| `(0010,0010)` | Patient Name | Patient's full name in PN format |
| `(0010,0020)` | Patient ID | Hospital or facility patient identifier |
| `(0008,0020)` | Study Date | Date the study was performed |
| `(0008,0060)` | Modality | Type of equipment (CT, MR, US, etc.) |
| `(0008,103E)` | Series Description | Description of the series |
| `(0028,0010)` | Rows | Number of rows in the image |
| `(0028,0011)` | Columns | Number of columns in the image |
| `(7FE0,0010)` | Pixel Data | The actual image pixel data |

### DICOM Network Services

| Service | Description |
|---------|-------------|
| **C-ECHO** | Verification - test connectivity between DICOM nodes |
| **C-FIND** | Query - search for studies, series, or images |
| **C-MOVE** | Retrieve - request images be sent to a destination |
| **C-GET** | Retrieve - directly receive images over the same connection |
| **C-STORE** | Store - send images to a PACS or archive |
| **N-CREATE/N-SET** | Create and update management objects (MPPS, MWL) |

### DICOMweb Services

| Service | HTTP Method | Description |
|---------|-------------|-------------|
| **QIDO-RS** | GET | Query for DICOM Objects (studies, series, instances) |
| **WADO-RS** | GET | Retrieve DICOM Objects (images, metadata, rendered) |
| **STOW-RS** | POST | Store DICOM Objects to a server |
| **UPS-RS** | Various | Unified Procedure Step - worklist management |

---

## Why DICOMKit?

### Comparison with Other DICOM Libraries

| Feature | DICOMKit | DCMTK | pydicom | fo-dicom |
|---------|----------|-------|---------|----------|
| **Language** | Swift | C++ | Python | C# |
| **Apple Platforms** | ✅ Native | ⚠️ Needs porting | ❌ Limited | ❌ Windows-focused |
| **Swift 6 Concurrency** | ✅ Full support | ❌ N/A | ❌ N/A | ❌ N/A |
| **visionOS Support** | ✅ Built-in | ❌ No | ❌ No | ❌ No |
| **Memory Safety** | ✅ Swift safety | ⚠️ Manual | ✅ GC | ✅ GC |
| **Type Safety** | ✅ Strong | ⚠️ Moderate | ⚠️ Dynamic | ✅ Strong |
| **Package Manager** | SPM, Homebrew | CMake | pip | NuGet |
| **CLI Tools Included** | ✅ 31+ tools | ✅ Many tools | ❌ Separate | ❌ Separate |
| **License** | MIT | BSD/LGPL | MIT | MS-PL |

### DICOMKit Advantages

1. **Native Swift Experience**: Seamlessly integrates with SwiftUI, Combine, and async/await
2. **Apple Platform Optimized**: Uses Accelerate framework, Metal-ready, supports all Apple platforms
3. **Modern Concurrency**: Built from the ground up with Swift 6 strict concurrency
4. **Complete Solution**: Single library for files, networking, web services, and CLI tools
5. **Production Ready**: 2,180+ tests, comprehensive documentation, real-world validated

## Features (v1.0)

- ✅ **Comprehensive Documentation (NEW in v1.0.13)**
  - ✅ **DocC API Documentation** - Apple-native documentation
    - ✅ DocC catalogs for all 5 modules (DICOMKit, DICOMCore, DICOMNetwork, DICOMWeb, DICOMDictionary)
    - ✅ Tutorial-style guides (Getting Started, Reading Files, Rendering Images)
    - ✅ Code examples for common use cases
  - ✅ **Platform Integration Guides** - Platform-specific best practices
    - ✅ iOS Integration Guide (SwiftUI, UIKit, file import, memory management)
    - ✅ macOS Integration Guide (document-based apps, PACS integration, printing)
    - ✅ visionOS Integration Guide (spatial computing, RealityKit, hand gestures)
    - ✅ DICOM Networking Guide (C-ECHO, C-FIND, C-MOVE, C-GET, C-STORE)
    - ✅ DICOMweb Guide (QIDO-RS, WADO-RS, STOW-RS, OAuth2)
  - ✅ **Architecture Documentation** - Design and patterns
    - ✅ Module dependency diagrams
    - ✅ Threading and concurrency model
    - ✅ Memory management patterns
    - ✅ Data flow documentation
  - ✅ **DICOM Conformance Statement** - Standards compliance
    - ✅ Supported SOP Classes table
    - ✅ Transfer Syntax support matrix
    - ✅ Character set support details
    - ✅ DICOMweb capabilities (QIDO, WADO, STOW, UPS)
  - ✅ **Troubleshooting Resources** - Problem solving
    - ✅ Common issues and solutions
    - ✅ Debugging techniques
    - ✅ Error code reference
    - ✅ FAQ document

- ✅ **Performance Optimizations (v1.0.12)**
  - ✅ **Memory Optimization** - Efficient large file handling
    - ✅ Memory-mapped file access for files >100MB (50% memory reduction)
    - ✅ Lazy loading of pixel data with `LazyPixelDataLoader`
    - ✅ `DataSource` abstraction (in-memory vs. memory-mapped)
    - ✅ `ParsingOptions` with modes: full, metadataOnly, lazyPixelData
  - ✅ **Parsing Performance** - Fast DICOM file parsing
    - ✅ Metadata-only parsing (2-10x faster for large images)
    - ✅ Partial parsing with stopAfterTag and maxElements
    - ✅ Streaming parser for large files
    - ✅ O(1) tag lookup with Dictionary-based DataSet
  - ✅ **Image Processing** - GPU-class performance on CPU
    - ✅ `ImageCache` with LRU eviction (configurable: default, highMemory, lowMemory)
    - ✅ `SIMDImageProcessor` with Accelerate framework (Apple platforms)
      - ✅ Window/level transformation (2-5x faster)
      - ✅ Pixel inversion (MONOCHROME1 support)
      - ✅ Normalization to 8-bit range
      - ✅ Min/max value detection
      - ✅ Contrast/brightness adjustment
  - ✅ **Network Performance** - Optimized DICOM networking (NEW in v1.0.14)
    - ✅ Connection pooling for DICOM associations
    - ✅ HTTP connection pooling with HTTP/2 multiplexing for DICOMweb
      - ✅ `HTTPConnectionPool` actor with per-host connection management
      - ✅ Automatic connection recycling based on age and idle time
      - ✅ HTTP/2 stream multiplexing (up to 100 concurrent streams)
      - ✅ Connection reuse tracking and statistics
    - ✅ HTTP request pipelining for batched operations
      - ✅ `HTTPRequestPipeline` actor for request batching
      - ✅ Configurable pipeline depth (1-50 requests)
      - ✅ Strict in-order response delivery option
    - ✅ Predictive prefetching for improved cache hit rates
      - ✅ `HTTPPrefetchManager` actor with LRU caching
      - ✅ Configurable strategies: sequential, predictive, aggressive
      - ✅ Priority-based prefetch queue (low, medium, high)
      - ✅ Cache size limits: 100MB-2GB
      - ✅ Cache hit/miss tracking with hit rate calculation
    - ✅ HTTP caching for DICOMweb with LRU eviction
  - ✅ **Benchmarking Infrastructure** - Performance measurement tools
    - ✅ `DICOMBenchmark` for sync and async operations
    - ✅ Memory usage tracking with peak detection
    - ✅ `BenchmarkComparison` for before/after analysis
  - ✅ **Comprehensive Documentation** - Performance best practices
    - ✅ PERFORMANCE_GUIDE.md with optimization strategies
    - ✅ Platform-specific recommendations (iOS, macOS, visionOS)
    - ✅ Troubleshooting and best practices
  - ✅ **102 Performance Tests** - Comprehensive validation (v1.0.14: +53 tests)
    - ✅ 5 tests for ParsingOptions
    - ✅ 9 tests for optimized parsing
    - ✅ 6 tests for benchmarking
    - ✅ 15 tests for ImageCache
    - ✅ 14 tests for SIMD processing
    - ✅ 24 tests for HTTP connection pooling (NEW in v1.0.14)
    - ✅ 10 tests for HTTP request pipelining (NEW in v1.0.14)
    - ✅ 19 tests for HTTP prefetch manager (NEW in v1.0.14)

- ✅ **ICC Profile Color Management (v1.0.11)**
  - ✅ **ICC Profile Parsing** - Complete ICC.1:2004-10 profile parsing
    - ✅ `ICCProfile` struct for profile data with lazy parsing
    - ✅ `ICCProfileParser` for ICC v2 and v4 profile formats
    - ✅ Profile header parsing (128-byte ICC header specification)
    - ✅ Tag table parsing with offset-based tag access
    - ✅ TRC (Tone Reproduction Curve) extraction for gamma correction
    - ✅ XYZ colorant tag extraction for white point and primaries
  - ✅ **Profile Type Support** - All ICC profile device classes
    - ✅ Input device profiles (scanners, cameras)
    - ✅ Display device profiles (monitors, projectors)
    - ✅ Output device profiles (printers)
    - ✅ Color space conversion profiles
    - ✅ Device link profiles
  - ✅ **Color Space Conversions** - Comprehensive color transformation pipeline
    - ✅ sRGB ↔ XYZ ↔ LAB color space conversions
    - ✅ Matrix-based color transformations (ColorMatrix)
    - ✅ LUT-based color transformations (A2B, B2A tags)
    - ✅ Gamma correction (sRGB to/from linear RGB)
    - ✅ Core Graphics integration for Apple platforms (CGColorSpace)
  - ✅ **Wide Color Gamut Support** - Modern display technologies
    - ✅ Display P3 color space (Apple wide gamut displays)
    - ✅ Rec. 2020 (ITU-R BT.2020) for Ultra HD and HDR
    - ✅ Adobe RGB (1998) for professional workflows
    - ✅ ProPhoto RGB for very wide gamut applications
  - ✅ **DICOM Color Integration** - DICOM-specific color management
    - ✅ ICC Profile Module (0028,2000) extraction from DICOM files
    - ✅ Color Space tag (0028,2002) parsing and mapping
    - ✅ YBR color space support (YBR_FULL, YBR_FULL_422, YBR_PARTIAL_420)
  - ✅ **HDR and EDR Display Support** - Extended dynamic range for medical imaging
    - ✅ `EDRDisplayCapabilities` for querying display headroom
    - ✅ `HDRToneMapping` with multiple tone mapping operators (Linear, Perceptual, Reinhard, ACES)
    - ✅ Target peak luminance configuration (nits/cd/m²)
    - ✅ Highlight preservation for diagnostic detail
  - ✅ **Optical Path Color (Whole Slide Imaging)** - Microscopy color management
    - ✅ `OpticalPathColor` for WSI illumination and color properties
    - ✅ Illumination type support (Brightfield, Darkfield, Fluorescence, Phase Contrast, DIC)
    - ✅ Illumination wavelength and color specifications
    - ✅ Per-path ICC profile support for multi-channel imaging
  - ✅ **LUT-Based Color Transformations** - Advanced ICC profile processing
    - ✅ `LUTColorTransform` for multi-dimensional color lookup
    - ✅ 1D LUT support for single-channel curves
    - ✅ 3D CLUT support for full color transformations
    - ✅ Gamma curve generation and application
    - ✅ Legacy lut8/lut16 and modern lutAToB/lutBToA tag parsing
  - ✅ **Comprehensive Testing** - 84 unit tests (210% of 40+ target)
    - ✅ 24 tests for ICC profile parsing (headers, tags, errors)
    - ✅ 24 tests for color transformations (RGB, XYZ, LAB, gamma)
    - ✅ 21 tests for color matrices (transformations, predefined matrices)
    - ✅ 15 tests for advanced ICC features (Rec2020, TRC, XYZ, DICOM tags)
    - ✅ 31 tests for display features (HDR/EDR, optical paths, tone mapping)
    - ✅ 38 tests for LUT color transforms (1D/3D LUTs, gamma, pipelines)

- ✅ **Private Tag Support (v1.0.10)**
  - ✅ **Private Creator Management** - Complete implementation of Private Data Elements (PS3.5 Section 7.8)
    - ✅ `PrivateCreator` struct with block number allocation
    - ✅ `PrivateTagAllocator` actor for thread-safe block management
    - ✅ Private tag generation with offset-based element addressing
    - ✅ Ownership tracking for private tag blocks
  - ✅ **Vendor-Specific Dictionaries** - Known private tag definitions
    - ✅ `PrivateTagDictionary` with vendor mappings
    - ✅ Siemens private tags (CSA Header, MR Header, CT Header)
    - ✅ GE Healthcare private tags (GEMS_IDEN, GEMS_ACQU, GEMS_SERS)
    - ✅ Philips private tags (Imaging DD, MR Imaging DD)
    - ✅ Canon/Toshiba private tags (TOSHIBA_MEC_MR3)
    - ✅ Well-known vendor creators with default group assignments
  - ✅ **Private Data Element Handling** - Enhanced private tag management
    - ✅ `PrivateDataElement` with creator reference
    - ✅ Block offset computation and validation
    - ✅ VR inference from vendor dictionaries
    - ✅ Tag name lookup for known private tags
  - ✅ **Vendor-Specific Parsing** - Proprietary header support
    - ✅ `SiemensCSAHeaderParser` for CSA headers (SV10 format)
    - ✅ CSA tag extraction with VM, VR, and values
    - ✅ Binary data parsing with null-termination handling
  - ✅ **Comprehensive Testing** - 52 unit tests (100% pass rate, 104% of 50+ target)
    - ✅ 18 tests for `PrivateCreator` (tag generation, ownership, well-known vendors)
    - ✅ 17 tests for `PrivateTagDictionary` (vendor dictionaries, VR/name lookup)
    - ✅ 15 tests for `PrivateTagAllocator` (allocation, concurrency, error handling)
    - ✅ 2 tests for `PrivateDataElement` (initialization, description formatting)

- ✅ **Real-World Value Mapping (RWV LUT) (v1.0.8)**
  - ✅ **General-Purpose RWV Support** - Complete implementation of Real World Value Mapping (PS3.3 C.7.6.16.2.11)
    - ✅ `RealWorldValueLUT` for transforming stored pixel values to physical quantities
    - ✅ `RealWorldValueLUTParser` for parsing RWV Mapping Sequence from DICOM
    - ✅ Linear transformation support (slope/intercept) for CT, MR, PET
    - ✅ LUT-based transformation for non-linear value mappings
    - ✅ Frame scope support (first frame, all frames, specific frames)
    - ✅ Priority handling: RWV Mapping Sequence preferred over legacy Modality LUT
  - ✅ **Measurement Units** - UCUM-based unit specifications
    - ✅ `RealWorldValueUnits` with coded entries (code value, scheme, meaning)
    - ✅ Common units: Hounsfield Units, mm²/s, ms, s, g/ml, Bq/ml, /min, %, unitless
    - ✅ Predefined constants for common modalities (CT, MR, PET, perfusion)
  - ✅ **Quantity Definitions** - Physical quantity specifications
    - ✅ Pre-defined quantities via `CodedConcept` extensions
    - ✅ Diffusion: ADC (Apparent Diffusion Coefficient)
    - ✅ Relaxation: T1, T2, T2* for MR quantification
    - ✅ Perfusion: Ktrans, Ve, Vp, CBF, CBV, MTT
    - ✅ PET: SUV, SUVbw, SUVlbm, SUVbsa, SUVibw
    - ✅ CT: Hounsfield Unit (Attenuation Coefficient)
  - ✅ **PET SUV Calculator** - Standardized Uptake Value computations
    - ✅ `SUVCalculator` with decay correction
    - ✅ SUVbw (body weight normalized) 
    - ✅ SUVlbm (lean body mass normalized using James formula)
    - ✅ SUVbsa (body surface area normalized using Du Bois formula)
    - ✅ SUVibw (ideal body weight normalized using Devine formula)
    - ✅ Automatic radiotracer decay correction
    - ✅ Common radionuclide half-lives: F-18, C-11, O-15, N-13, Ga-68, Cu-64, Zr-89, I-124
  - ✅ **RWV Renderer** - Real world value transformation and statistics
    - ✅ `RealWorldValueRenderer` actor for concurrent-safe rendering
    - ✅ Single value and batch array transformations
    - ✅ Frame-specific transformation support
    - ✅ ROI statistics calculator (min, max, mean, median, std dev) with units
  - ✅ **Comprehensive Testing** - 69 unit tests (100% pass rate, 173% of 40+ target)
    - ✅ 22 tests for RealWorldValueLUT (transformations, units, quantities)
    - ✅ 17 tests for RealWorldValueRenderer (actor, frame-specific, statistics)
    - ✅ 20 tests for SUVCalculator (decay correction, all 4 SUV types)
    - ✅ 10 tests for RealWorldValueLUTParser (modality LUT, RWV mapping, priority)

- ✅ **Parametric Map Objects (NEW in v1.0.7)**
  - ✅ **Parametric Map IOD** - Complete implementation of Parametric Map Storage (PS3.3 A.75)
    - ✅ `ParametricMap` struct for quantitative imaging data (ADC, T1/T2, perfusion, SUV)
    - ✅ `ParametricMapParser` for parsing Parametric Map DICOM objects
    - ✅ Real World Value Mapping for converting pixel values to physical quantities
    - ✅ Multi-frame organization with functional groups
    - ✅ Content identification (label, description, creator, date/time)
    - ✅ Derivation tracking with coded sequences
  - ✅ **Quantity Definitions** - Physical quantity specifications
    - ✅ `QuantityDefinition` with coded value types
    - ✅ Pre-defined quantities: ADC, T1, T2, Ktrans, Ve, Vp, SUV variants
    - ✅ `MeasurementUnits` using UCUM (Unified Code for Units of Measure)
    - ✅ Common units: mm²/s, ms, s, g/ml, /min, unitless ratio
  - ✅ **Real World Value Mapping** - Stored pixel value to physical quantity conversion
    - ✅ `RealWorldValueMapping` struct for value transformations
    - ✅ Linear transformation (slope/intercept)
    - ✅ LUT-based transformation for non-linear mappings
    - ✅ Multiple mappings per parametric map
  - ✅ **Parametric Data Extraction** - Multi-format pixel data support
    - ✅ `ParametricMapPixelDataExtractor` for extracting quantitative values
    - ✅ Integer pixel data (8/16-bit unsigned/signed) with mapping
    - ✅ Float pixel data (32-bit IEEE 754)
    - ✅ Double pixel data (64-bit IEEE 754)
    - ✅ Frame-by-frame quantity access
  - ✅ **Common Parametric Map Types** - Modality-specific support
    - ✅ ADC (Apparent Diffusion Coefficient) maps for DWI
    - ✅ T1/T2 relaxation maps for MR quantification
    - ✅ Perfusion parameter maps (Ktrans, Ve, Vp) for DCE-MRI
    - ✅ SUV (Standardized Uptake Value) maps for PET (body weight, lean body mass, body surface area)
  - ✅ **Parametric Visualization** - Color-mapped quantitative display
    - ✅ `ParametricMapRenderer` with color mapping algorithms
    - ✅ Six predefined color maps: grayscale, hot, cool, jet, viridis, turbo
    - ✅ Custom color lookup tables
    - ✅ Configurable window/level for parametric values
    - ✅ Threshold-based display with masking
    - ✅ Auto-windowing based on min/max values
    - ✅ CGImage integration for Apple platforms
  - ✅ **Comprehensive Testing** - 55 unit tests (100% pass rate)
    - ✅ 12 tests for ParametricMap data structures
    - ✅ 9 tests for parser functionality
    - ✅ 8 tests for pixel data extraction
    - ✅ 12 tests for renderer and color mapping
    - ✅ 14 tests for edge cases and additional coverage

- ✅ **Hanging Protocol Support (NEW in v1.0.3)**
  - ✅ **Hanging Protocol IOD Support** - Complete implementation of Hanging Protocol Storage (PS3.3 A.38)
    - ✅ `HangingProtocol` struct with all protocol definition attributes
    - ✅ `HangingProtocolLevel` for SITE, GROUP, and USER-level protocols
    - ✅ `HangingProtocolEnvironment` for modality and laterality matching
    - ✅ `HangingProtocolParser` for parsing Hanging Protocol DICOM objects
    - ✅ `HangingProtocolSerializer` for creating Hanging Protocol DICOM objects
    - ✅ 60+ DICOM tags in group 0x0072 for complete protocol specification
  - ✅ **Image Set Definitions** - Criteria for selecting images from studies
    - ✅ `ImageSetDefinition` with filtering and sorting specifications
    - ✅ `ImageSetSelector` for attribute-based image filtering
    - ✅ `FilterOperator` with 9 comparison types (equal, contains, less than, present, etc.)
    - ✅ `SelectorUsageFlag` for positive and negative matching
    - ✅ `SortOperation` for ordering images by various criteria
    - ✅ `TimeBasedSelection` for prior study selection with relative time
    - ✅ Support for series-level and instance-level selectors
  - ✅ **Display Set Specifications** - Layout and display parameters
    - ✅ `DisplaySet` struct with comprehensive display configuration
    - ✅ `ImageBox` for viewport/panel definitions with layout types (STACK, TILED)
    - ✅ Scroll settings (direction, type, amount) for navigation
    - ✅ `ReformattingOperation` with MPR, MIP, MinIP, CPR, AvgIP types
    - ✅ `ThreeDRenderingType` for volume rendering hints
    - ✅ `DisplayOptions` for patient orientation, VOI, pseudo-color, annotations
    - ✅ Synchronization groups for linked viewport scrolling
    - ✅ Cine playback configuration relative to real-time
  - ✅ **Screen Layout Support** - Multi-monitor configuration
    - ✅ `ScreenDefinition` for nominal display specifications
    - ✅ Spatial positioning for multi-monitor workstations
    - ✅ Bit depth requirements (grayscale and color)
    - ✅ Maximum repaint time specifications
  - ✅ **Protocol Matching Engine** - Intelligent protocol selection
    - ✅ `HangingProtocolMatcher` actor for thread-safe matching
    - ✅ `StudyInfo` for study characteristics matching
    - ✅ `InstanceInfo` for image-level filtering
    - ✅ `ImageSetMatcher` for applying selection criteria
    - ✅ Priority-based matching (USER > GROUP > SITE)
    - ✅ Modality and laterality-based environment matching
    - ✅ User group filtering for personalized protocols
  - ✅ **Comprehensive Testing** - 147 unit tests (98% pass rate)
    - ✅ 29 tests for protocol matching algorithms
    - ✅ 24 tests for parsing DICOM Hanging Protocols
    - ✅ 24 tests for serializing to DICOM format
    - ✅ 28 tests for image set definitions
    - ✅ 27 tests for display set specifications
    - ✅ 15 tests for basic data structures

- ✅ **Radiation Therapy Structure Set Support (NEW in v1.0.4)**
  - ✅ **RT Structure Set IOD** - Complete implementation of RT Structure Set Storage (PS3.3 A.19)
    - ✅ `RTStructureSet` struct for radiation therapy planning structures
    - ✅ `RTStructureSetParser` for parsing RT Structure Set DICOM objects
    - ✅ Structure Set identification (label, name, description, date/time)
    - ✅ Referenced Frame of Reference and series tracking
    - ✅ 45+ DICOM tags in group 0x3006 for complete RT specification
  - ✅ **Region of Interest (ROI) Support** - Anatomical and planning structures
    - ✅ `RTRegionOfInterest` struct with geometric data and metadata
    - ✅ ROI identification (number, name, description)

- ✅ **Radiation Therapy Plan and Dose Support (NEW in v1.0.5)**
  - ✅ **RT Plan IOD** - Complete implementation of RT Plan Storage (PS3.3 A.20)
    - ✅ `RTPlan` struct with fraction groups, beams, and dose references
    - ✅ `RTPlanParser` for parsing RT Plan DICOM objects
    - ✅ Plan identification (label, name, description, date/time, geometry)
    - ✅ Dose Reference Sequence for target and organ-at-risk prescriptions
    - ✅ Fraction Group Sequence with treatment scheduling
    - ✅ Referenced Structure Set and Dose linking
    - ✅ 90+ DICOM tags in group 0x300A for comprehensive RT Plan support
  - ✅ **RT Beam Support** - External beam radiation therapy beams
    - ✅ `RTBeam` struct with beam parameters and control points
    - ✅ Beam identification (number, name, type, radiation type)
    - ✅ Machine parameters (treatment machine, dosimeter unit, SAD)
    - ✅ Control Point Sequence with gantry, collimator, and couch angles
    - ✅ Beam Limiting Device positions (jaws, MLC)
    - ✅ Dose rate and energy specifications
    - ✅ Support for STATIC, DYNAMIC, IMRT, and VMAT beams
  - ✅ **RT Dose IOD** - Dose distribution and DVH support (PS3.3 A.18)
    - ✅ `RTDose` struct for 3D dose grid representation
    - ✅ `RTDoseParser` for parsing RT Dose DICOM objects
    - ✅ Dose grid geometry (image position, orientation, pixel spacing)
    - ✅ Dose scaling and units (GY, RELATIVE)
    - ✅ Dose summation types (PLAN, MULTI_PLAN, FRACTION, BEAM)
    - ✅ DVH (Dose Volume Histogram) data extraction
    - ✅ Referenced RT Plan and Structure Set linking
    - ✅ Support for 16-bit and 32-bit dose grids
    - ✅ Dose value access with automatic scaling
  - ✅ **Brachytherapy Support** - High/low dose rate brachytherapy
    - ✅ `BrachyApplicationSetup` for applicator configurations
    - ✅ `BrachyChannel` with source positioning and dwell times
    - ✅ Brachytherapy Control Point Sequence
    - ✅ Source isotope and air kerma rate specifications
    - ✅ Generation algorithm tracking (manual, automatic, AI)
    - ✅ Frame of Reference UID for spatial registration
    - ✅ ROI physical properties (density, mass)
  - ✅ **Contour Geometry** - 3D structure definitions
    - ✅ `Contour` struct with geometric type and points
    - ✅ `ContourGeometricType` enum (POINT, OPEN_PLANAR, CLOSED_PLANAR, OPEN_NONPLANAR, CLOSED_NONPLANAR)
    - ✅ `Point3D` for 3D contour points in patient coordinate system (mm)
    - ✅ Contour slab thickness and offset vector support
    - ✅ Referenced SOP Instance UID for image registration
    - ✅ Multiple contours per ROI across image slices
  - ✅ **ROI Display and Visualization** - Visual representation
    - ✅ `ROIContour` struct linking ROIs to contour geometry
    - ✅ `DisplayColor` for ROI display colors (RGB 0-255)
    - ✅ Color-coded structure visualization
  - ✅ **Clinical Observations** - RT planning metadata
    - ✅ `RTROIObservation` struct with clinical interpretations
    - ✅ `RTROIInterpretedType` enum with 18 standard types:
      - ✅ Target volumes: PTV, CTV, GTV
      - ✅ Organs at risk: ORGAN, AVOIDANCE
      - ✅ External structures: EXTERNAL, CAVITY
      - ✅ Planning structures: ISOCENTER, MARKER, CONTROL
      - ✅ Dose regions: DOSE_REGION, TREATED_VOLUME, IRRADIATED_VOLUME
      - ✅ Accessories: BOLUS, FIXATION_DEVICE, SUPPORT
      - ✅ Registration and contrast: REGISTRATION, CONTRAST_AGENT
    - ✅ ROI interpreter tracking (person or algorithm)
    - ✅ `ROIPhysicalProperty` for material properties
  - ✅ **Supporting Types** - Geometric and visualization helpers
    - ✅ `Vector3D` for 3D offset vectors
    - ✅ Sendable and Hashable conformance for all types
    - ✅ Identifiable protocol support for SwiftUI integration
  - ✅ **Comprehensive Testing** - 33 unit tests (100% pass rate)
    - ✅ 21 tests for data structure initialization and conformance
    - ✅ 12 tests for RT Structure Set parsing
    - ✅ Complete integration test with full structure set
    - ✅ Contour point parsing and geometric type validation

- ✅ **Segmentation Objects (NEW in v1.0.6)**
  - ✅ **Segmentation IOD** - Complete implementation of Segmentation Storage (PS3.3 A.51)
    - ✅ `Segmentation` struct for labeled image regions from AI/ML or manual annotation
    - ✅ `SegmentationParser` for parsing Segmentation DICOM objects
    - ✅ Binary segmentation (1-bit per pixel, presence/absence encoding)
    - ✅ Fractional segmentation (8/16-bit, probability or occupancy values)
    - ✅ Multi-frame organization with per-frame functional groups
    - ✅ Content identification (label, description, creator, date/time)
    - ✅ 30+ DICOM tags in group 0x0062 for segmentation specification
  - ✅ **Segment Definitions** - Anatomical and pathological structure descriptions
    - ✅ `Segment` struct with identification and coded terminology
    - ✅ `SegmentAlgorithmType` enum (AUTOMATIC, SEMIAUTOMATIC, MANUAL)
    - ✅ `CodedConcept` for standardized terminology (CID 7150, CID 7151)
    - ✅ Segment category and type (Tissue, Organ, Lesion, etc.)
    - ✅ Anatomic region and modifier sequences
    - ✅ Recommended display CIELab colors for visualization
    - ✅ Tracking ID and UID for longitudinal studies
  - ✅ **Functional Groups** - Multi-frame metadata organization
    - ✅ `FunctionalGroup` with per-frame and shared attributes
    - ✅ `SegmentIdentification` linking frames to segments
    - ✅ `DerivationImage` with source image references
    - ✅ `FrameContent` for acquisition metadata
    - ✅ `PlanePosition` and `PlaneOrientation` for spatial registration
    - ✅ Shared and per-frame functional groups sequences
  - ✅ **Pixel Data Extraction** - Binary and fractional mask extraction
    - ✅ `SegmentationPixelDataExtractor` for extracting segment masks
    - ✅ Binary frame extraction (1-bit packed, MSB first per DICOM spec)
    - ✅ Fractional frame extraction (8/16-bit with normalization)
    - ✅ Individual segment mask extraction by segment number
    - ✅ Batch extraction of all segments
    - ✅ Frame-to-segment mapping via functional groups
  - ✅ **Visualization and Rendering** - Segmentation overlay display
    - ✅ `SegmentationRenderer` for colored overlay generation
    - ✅ CIELab to RGB color conversion for display colors
    - ✅ Configurable opacity/transparency (0.0-1.0)
    - ✅ Multi-segment compositing with alpha blending
    - ✅ Selective segment visibility filtering
    - ✅ Custom color mapping per segment
    - ✅ CGImage integration for Apple platforms
    - ✅ Composite with base image for overlay visualization
  - ✅ **Segmentation Creation** - Build segmentations from masks
    - ✅ `SegmentationBuilder` for creating DICOM Segmentation objects
    - ✅ Binary mask to segmentation conversion (0/1 → bit-packed)
    - ✅ Fractional mask conversion (0-255 → 8/16-bit)
    - ✅ Fluent API with builder pattern
    - ✅ Segment metadata assignment (label, category, type, algorithm)
    - ✅ RGB to CIELab color conversion for display colors
    - ✅ Source image reference tracking
    - ✅ Per-frame functional groups generation
    - ✅ Comprehensive validation and error handling
  - ✅ **AI/ML Integration** - Encode AI segmentation outputs
    - ✅ Support for common AI frameworks (MONAI, nnU-Net, etc.)
    - ✅ Binary and probabilistic segmentation encoding
    - ✅ Algorithm metadata tracking (type, name, version)
    - ✅ Proper DICOM compliance for medical AI workflows
  - ✅ **Comprehensive Testing** - 98 unit tests (100% pass rate)
    - ✅ 27 tests for Segmentation data structures
    - ✅ 12 tests for SegmentationParser with mock data
    - ✅ 22 tests for SegmentationPixelDataExtractor
    - ✅ 19 tests for SegmentationRenderer
    - ✅ 18 tests for SegmentationBuilder
    - ✅ Binary and fractional segmentation scenarios
    - ✅ Multi-segment, multi-frame integration tests

- ✅ **Color Presentation States (in v1.0.2)**
  - ✅ **Color Softcopy Presentation State (CSPS)** - ICC profile-based color management (PS3.3 A.34)
    - ✅ `ColorPresentationState` struct for color image display with ICC profiles
    - ✅ `ICCProfile` support for device-independent color management
    - ✅ `ColorSpace` enum for sRGB, Adobe RGB, Display P3, ProPhoto RGB, and generic RGB
    - ✅ CoreGraphics integration for CGColorSpace creation on Apple platforms
    - ✅ Full spatial transformation and annotation support
  - ✅ **Pseudo-Color Softcopy Presentation State** - False-color mapping for grayscale images (PS3.3 A.35)
    - ✅ `PseudoColorPresentationState` struct for pseudo-color display
    - ✅ `PaletteColorLUT` extension with `applyNormalized` for color mapping
    - ✅ `ColorMapPreset` with 6 preset color maps:
      - ✅ Grayscale (linear mapping)
      - ✅ Hot (black → red → yellow → white)
      - ✅ Cool (cyan → blue → magenta)
      - ✅ Jet (rainbow: blue → cyan → yellow → red)
      - ✅ Bone (grayscale with blue tint)
      - ✅ Copper (black → copper → yellow)
    - ✅ Integration with existing VOI LUT and Modality LUT pipelines
  - ✅ **Blending Softcopy Presentation State** - Multi-modality image fusion (PS3.3 A.36)
    - ✅ `BlendingPresentationState` struct for PET/CT, PET/MR fusion
    - ✅ `BlendingDisplaySet` with multiple blending configurations
    - ✅ `ReferencedImageForBlending` with frame and presentation state references
    - ✅ `BlendingMode` enum with 6 blending algorithms:
      - ✅ Alpha blending (weighted average)
      - ✅ Maximum intensity projection (MIP)
      - ✅ Minimum intensity projection (MinIP)
      - ✅ Average intensity
      - ✅ Additive blending
      - ✅ Subtractive blending
    - ✅ Per-image relative opacity control

- ✅ **Grayscale Presentation State (GSPS) (NEW in v1.0.1)**
  - ✅ **Presentation State IOD Support** - Complete implementation of Grayscale Softcopy Presentation State (PS3.3 A.33)
    - ✅ `PresentationState` base protocol with common attributes
    - ✅ `GrayscalePresentationState` struct for grayscale image display parameters
    - ✅ `GrayscalePresentationStateParser` for parsing GSPS DICOM objects
    - ✅ Referenced series and image tracking (`ReferencedSeries`, `ReferencedImage`)
  - ✅ **Display Transformation Pipeline** - Complete LUT transformation chain
    - ✅ `ModalityLUT` for modality-specific pixel value transforms
    - ✅ `VOILUT` for Value of Interest (window/level) transformations
    - ✅ `PresentationLUT` for final output intensity mapping
    - ✅ `LUTData` for explicit lookup table specifications
  - ✅ **Spatial Transformations** - Image geometry and display area control
    - ✅ `SpatialTransformation` for rotation (0°, 90°, 180°, 270°) and flipping
    - ✅ `DisplayedArea` for zoom, pan, and viewport management
    - ✅ `PresentationSizeMode` for scaling behavior (scale to fit, true size, magnify)
  - ✅ **Graphic Annotations** - Overlay graphics and text on images
    - ✅ `GraphicLayer` for multi-layer annotation organization
    - ✅ `GraphicObject` with full geometric type support (POINT, POLYLINE, INTERPOLATED, CIRCLE, ELLIPSE)
    - ✅ `TextObject` for text annotations with positioning and formatting
    - ✅ `AnnotationUnits` for display (PIXEL) and DICOM (DISPLAY) coordinate systems
  - ✅ **Display Shutters** - Region masking and privacy protection
    - ✅ `DisplayShutter` enum with rectangular, circular, and polygonal shapes
    - ✅ Bitmap overlay shutter support for arbitrary masking
    - ✅ Shutter presentation value for masked areas
  - ✅ **Presentation State Application** - Apply GSPS to images
    - ✅ `PresentationStateApplicator` for rendering images with presentation state
    - ✅ Integration with `CGImage` rendering pipeline
    - ✅ Annotation overlay rendering on top of processed images
    - ✅ Multiple presentation state support for comparison viewing

- ✅ **Common SR Templates (NEW in v0.9.8)**
  - ✅ **BasicTextSRBuilder** - Specialized builder for Basic Text SR documents
    - ✅ Simple hierarchical text structure with sections
    - ✅ Section headings and content with result builder syntax
    - ✅ Common section helpers: Findings, Impression, Clinical History, etc.
    - ✅ `@SectionContentBuilder` for declarative section content
    - ✅ `CodedConcept` extensions for common section types
    - ✅ Validation ensures only Basic Text SR compatible value types
    - ✅ 53 unit tests for comprehensive coverage
  - ✅ **EnhancedSRBuilder** - Specialized builder for Enhanced SR documents
    - ✅ All Basic Text SR features plus numeric measurements
    - ✅ Numeric content items with units (millimeters, centimeters, etc.)
    - ✅ Waveform reference support for ECG and other waveform data
    - ✅ `@EnhancedSectionContentBuilder` for declarative section content
    - ✅ `EnhancedSectionContent` helpers for measurements and text
    - ✅ Convenience methods: `addMeasurementMM`, `addMeasurementCM`, `addMeasurements`
    - ✅ `CodedConcept` extensions for measurement types (diameter, length, area, volume)
    - ✅ Validation ensures only Enhanced SR compatible value types
    - ✅ 82 unit tests for comprehensive coverage
  - ✅ **ComprehensiveSRBuilder** - Specialized builder for Comprehensive SR documents
    - ✅ All Enhanced SR features plus spatial and temporal coordinates
    - ✅ 2D Spatial Coordinates (SCOORD): points, polylines, polygons, circles, ellipses
    - ✅ Temporal Coordinates (TCOORD): sample positions, time offsets, datetimes
    - ✅ `@ComprehensiveSectionContentBuilder` for declarative section content
    - ✅ `ComprehensiveSectionContent` helpers for coordinates and measurements
    - ✅ Convenience methods: `addPoint`, `addPolyline`, `addPolygon`, `addCircle`, `addEllipse`
    - ✅ Temporal coordinate helpers for sample positions, time offsets, and datetimes
    - ✅ Validation ensures only Comprehensive SR compatible value types (no SCOORD3D)
    - ✅ 83 unit tests for comprehensive coverage
  - ✅ **Comprehensive3DSRBuilder** - Specialized builder for Comprehensive 3D SR documents (NEW in v0.9.8)
    - ✅ All Comprehensive SR features plus 3D spatial coordinates
    - ✅ 3D Spatial Coordinates (SCOORD3D): points, polylines, polygons, ellipses, ellipsoids, multipoint
    - ✅ Frame of Reference UID support for 3D coordinate systems
    - ✅ 3D ROI definition helpers with volume measurements
    - ✅ `@Comprehensive3DSectionContentBuilder` for declarative section content
    - ✅ `Comprehensive3DSectionContent` helpers for 3D coordinates and measurements
    - ✅ Convenience methods: `addPoint3D`, `addPolyline3D`, `addPolygon3D`, `addEllipse3D`, `addEllipsoid`, `addMultipoint3D`
    - ✅ `add3DROI` helper for complete 3D region of interest with ellipsoid shape
    - ✅ Validation ensures Frame of Reference UID for all 3D coordinates
    - ✅ 66 unit tests for comprehensive coverage
  - ✅ **MeasurementReportBuilder** - Specialized builder for TID 1500 Measurement Reports (NEW)
    - ✅ DICOM TID 1500 compliant measurement report structure
    - ✅ Image Library (TID 1600) for source image references
    - ✅ Measurement Groups (TID 1501) with tracking identifiers
    - ✅ Tracking Identifier and Tracking Unique Identifier support
    - ✅ `@MeasurementGroupContentBuilder` for declarative measurement content
    - ✅ `MeasurementGroupContentHelper` for common measurements (length, area, volume)
    - ✅ Document title codes: Imaging Measurement Report, Lesion Measurement Report, etc.
    - ✅ Qualitative evaluations support
    - ✅ Procedure Reported and Language of Content support
    - ✅ Validation ensures tracking identifiers are provided
    - ✅ 60 unit tests for comprehensive coverage
  - ✅ **KeyObjectSelectionBuilder** - Specialized builder for Key Object Selection (KOS) Documents (NEW in v0.9.8)
    - ✅ DICOM Key Object Selection Document (SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.59)
    - ✅ Flag significant images for teaching, quality control, or referral
    - ✅ Standard purpose codes from CID 7010 (For Teaching, Quality Issue, etc.)
    - ✅ 9 predefined purpose codes plus custom concept support
    - ✅ Simple fluent API for adding key objects (referenced instances)
    - ✅ Optional text descriptions for each key object
    - ✅ Frame number support for multi-frame images
    - ✅ Validation ensures at least one key object is present
    - ✅ 38 unit tests for comprehensive coverage
  - ✅ **MammographyCADSRBuilder** - Specialized builder for Mammography CAD SR Documents (NEW in v0.9.8)
    - ✅ DICOM Mammography CAD SR (SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.50)
    - ✅ Computer-aided detection results for mammography images
    - ✅ CAD Processing Summary (algorithm name, version, manufacturer)
    - ✅ CAD Findings with confidence scores (0.0-1.0)
    - ✅ Finding types: Mass, Calcification, Architectural Distortion, Asymmetry
    - ✅ Spatial location support: 2D point, ROI polygon, circular region
    - ✅ Optional finding characteristics (spiculated margin, high density, etc.)
    - ✅ Image reference linking for each finding
    - ✅ Validation ensures algorithm name and at least one finding present
    - ✅ 50 unit tests for comprehensive coverage
  - ✅ **ChestCADSRBuilder** - Specialized builder for Chest CAD SR Documents (NEW in v0.9.8)
    - ✅ DICOM Chest CAD SR (SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.65)
    - ✅ Computer-aided detection results for chest radiology and CT images
    - ✅ CAD Processing Summary (algorithm name, version, manufacturer)
    - ✅ CAD Findings with confidence scores (0.0-1.0)
    - ✅ Finding types: Lung Nodule, Lung Mass, Lesion of Lung, Pulmonary Consolidation, Tree-in-Bud Pattern
    - ✅ Spatial location support: 2D point, ROI polygon, circular region
    - ✅ Optional finding characteristics for detailed detection results
    - ✅ Image reference linking for each finding
    - ✅ Validation ensures algorithm name and at least one finding present
    - ✅ 50 unit tests for comprehensive coverage
  - ✅ **AI/ML Integration Foundation (NEW in v0.9.8)**
    - ✅ `AIInferenceResult` protocol for AI model outputs
    - ✅ `AIDetection` types for representing AI detections with confidence scores
    - ✅ `AIDetectionType` enum with common findings (lung nodule, mass, fracture, etc.)
    - ✅ `AIDetectionLocation` supporting 2D and 3D spatial coordinates
    - ✅ `AIImageReference` for linking detections to source images
    - ✅ `ConfidenceScore` utilities for encoding and categorizing AI confidence (high/medium/low)
    - ✅ Direct integration with existing CAD SR builders
    - ✅ 26 unit tests for comprehensive coverage
- ✅ **Measurement and Coordinate Extraction (NEW in v0.9.5)**
  - ✅ **Measurement Extraction**
    - ✅ `Measurement` struct with value, unit, concept, and context
    - ✅ `MeasurementGroup` for related measurements (e.g., lesion dimensions)
    - ✅ `MeasurementQualifier` for special values (NaN, infinity, overflow)
    - ✅ `DerivationMethod` tracking (manual, automatic, calculated)
    - ✅ Unit conversion via UCUM-aware `converted(to:)` method
  - ✅ **Spatial Coordinate Extraction**
    - ✅ `SpatialCoordinates` struct wrapping SCOORD content items
    - ✅ Support for all graphic types (POINT, POLYLINE, POLYGON, CIRCLE, ELLIPSE)
    - ✅ Bounding box and centroid computation
    - ✅ Area calculation for polygons, circles, and ellipses
    - ✅ Perimeter/length calculation
    - ✅ Image reference linkage
  - ✅ **3D Coordinate Extraction**
    - ✅ `SpatialCoordinates3D` struct wrapping SCOORD3D content items
    - ✅ 3D bounding box and centroid computation
    - ✅ Path length calculation
    - ✅ Frame of Reference UID tracking
  - ✅ **Temporal Coordinate Extraction**
    - ✅ `TemporalCoordinates` struct wrapping TCOORD content items
    - ✅ Sample positions, time offsets, and datetime references
    - ✅ Duration calculation for temporal ranges
    - ✅ Point vs. range type detection
  - ✅ **Region of Interest (ROI) Support**
    - ✅ `ROI` struct combining coordinates with measurements
    - ✅ Area and perimeter from 2D coordinates
    - ✅ 2D and 3D bounding boxes
    - ✅ Centroid calculation
    - ✅ Associated measurement extraction
  - ✅ **MeasurementExtractor API**
    - ✅ `extractAllMeasurements(from:)` - All measurements from document
    - ✅ `extractMeasurements(forConcept:from:)` - Filter by concept
    - ✅ `extractMeasurementGroups(from:)` - Grouped measurements
    - ✅ `extractSpatialCoordinates(from:)` - All 2D coordinates
    - ✅ `extractSpatialCoordinates3D(from:)` - All 3D coordinates
    - ✅ `extractTemporalCoordinates(from:)` - All temporal coordinates
    - ✅ `extractROIs(from:)` - All regions of interest
    - ✅ `computeStatistics(_:)` - Statistical summaries (mean, std dev, min, max)
    - ✅ `groupByLocation(_:)` - Group measurements by concept
- ✅ **High-Level Extraction APIs (NEW in v0.9.8)**
  - ✅ **MeasurementReport Extraction**
    - ✅ `MeasurementReport.extract(from:)` - Extract TID 1500 Measurement Reports
    - ✅ `ExtractedMeasurementGroup` with tracking identifiers and measurements
    - ✅ Image library entry extraction
    - ✅ Procedure reported and language of content extraction
    - ✅ Qualitative evaluation extraction
    - ✅ Complete roundtrip support (build → serialize → parse → extract)
    - ✅ ~50 unit tests for comprehensive coverage
  - ✅ **CAD Findings Extraction**
    - ✅ `CADFindings.extract(from:)` - Extract CAD detection results
    - ✅ Support for Mammography CAD SR and Chest CAD SR
    - ✅ CAD processing info extraction (algorithm name, version, manufacturer)
    - ✅ `ExtractedCADFinding` with type, probability, location, and characteristics
    - ✅ `CADFindingLocation` with point, circle, polyline, and ellipse support
    - ✅ Image reference linkage for findings
    - ✅ ~45 unit tests for both CAD types
  - ✅ **Key Object Extraction**
    - ✅ `KeyObjects.extract(from:)` - Extract Key Object Selections
    - ✅ Selection purpose extraction (document title)
    - ✅ `KeyObject` with SOP Class/Instance UIDs, frames, and descriptions
    - ✅ Support for all standard purpose codes (For Teaching, Quality Issue, etc.)
    - ✅ Multi-frame image support
    - ✅ ~45 unit tests for KOS documents
- ✅ **Coded Terminology Support (v0.9.4)**
  - ✅ **Coding Scheme Infrastructure**
    - ✅ `CodingScheme` struct with designator, name, version, UID
    - ✅ `CodingSchemeRegistry` for managing known coding schemes
    - ✅ Built-in support for DCM, SCT, LN, RADLEX, UCUM, FMA, ICD-10, and more
    - ✅ Coding scheme validation
  - ✅ **SNOMED CT Support**
    - ✅ `SNOMEDCode` specialized type with concept ID and display name
    - ✅ Common anatomical codes (organs, body regions, laterality)
    - ✅ Common finding codes (mass, nodule, lesion, calcification)
    - ✅ Common procedure codes (CT, MRI, ultrasound, mammography)
    - ✅ Severity and qualifier codes
  - ✅ **LOINC Support**
    - ✅ `LOINCCode` specialized type with LOINC number
    - ✅ Vital sign codes (heart rate, blood pressure, temperature)
    - ✅ Measurement type codes (diameter, area, volume, density)
    - ✅ Radiology report section codes (findings, impression, technique)
    - ✅ Document type codes
  - ✅ **RadLex Support**
    - ✅ `RadLexCode` specialized type with RadLex ID
    - ✅ Imaging modality codes (CT, MRI, PET, ultrasound)
    - ✅ Common radiology finding codes (mass, nodule, consolidation)
    - ✅ Anatomical codes and qualitative descriptors
    - ✅ Temporal and size descriptors
  - ✅ **DCM (DICOM) Codes**
    - ✅ `DICOMCode` specialized type for DCM codes
    - ✅ SR document structure codes (finding, measurement, report)
    - ✅ Observer and subject context codes
    - ✅ Measurement and reference codes
    - ✅ Relationship type codes
  - ✅ **UCUM (Units of Measurement)**
    - ✅ `UCUMUnit` type with dimension and conversion support
    - ✅ Length, area, volume, mass, time, temperature, angle units
    - ✅ Medical-specific units (Hounsfield, SUV, Becquerel)
    - ✅ Unit conversion between compatible dimensions
    - ✅ Well-known unit lookup registry
  - ✅ **Context Group Support (PS3.16)**
    - ✅ `ContextGroup` struct for CID definitions
    - ✅ Extensible vs. non-extensible context groups
    - ✅ CID 218 - Quantitative Temporal Relation
    - ✅ CID 244 - Laterality
    - ✅ CID 4021 - Finding Site
    - ✅ CID 6147 - Response Evaluation
    - ✅ CID 7021 - Measurement Report Document Titles
    - ✅ CID 7464 - ROI Measurement Units
    - ✅ `ContextGroupRegistry` for group lookup and validation
  - ✅ **Code Mapping Utilities**
    - ✅ `CodeMapper` for cross-terminology mapping
    - ✅ SNOMED CT ↔ RadLex mappings for anatomical and finding concepts
    - ✅ `CodeEquivalent` protocol for semantic equivalence
    - ✅ Equivalent code lookup and display name resolution
- ✅ **Content Item Navigation and Tree Traversal (v0.9.3)**
  - ✅ **Tree Traversal APIs**
    - ✅ `ContentTreeIterator` - Depth-first tree traversal
    - ✅ `BreadthFirstIterator` - Breadth-first tree traversal
    - ✅ `ContentTreeSequence` - Sequence wrapper for iterating content trees
    - ✅ Configurable maximum depth protection
    - ✅ Lazy iteration for memory efficiency
  - ✅ **Query and Filtering APIs**
    - ✅ `findItems(byConceptName:recursive:)` - Find by coded concept
    - ✅ `findItems(byValueType:recursive:)` - Find by value type
    - ✅ `findItems(byRelationship:recursive:)` - Find by relationship type
    - ✅ `findItems(matching:recursive:)` - Custom predicate filtering
    - ✅ Recursive vs. shallow search options
  - ✅ **Path-Based Access**
    - ✅ `SRPath` struct for addressing content items
    - ✅ Path notation (e.g., "/Report/Finding[0]/Measurement")
    - ✅ `item(at:)` method for path-based access
    - ✅ `SRPath.Component` with concept and value type matching
    - ✅ Path serialization for persistence
  - ✅ **Content Item Subscripting**
    - ✅ Subscript by index (`container[0]`)
    - ✅ Subscript by concept string (`container[concept: "Finding"]`)
    - ✅ Subscript by coded concept (`container[concept: codedConcept]`)
    - ✅ Safe optional access patterns
  - ✅ **Relationship Navigation**
    - ✅ `propertyItems` - Items with HAS PROPERTIES relationship
    - ✅ `containedItems` - Items with CONTAINS relationship
    - ✅ `inferredFromItems` - Items with INFERRED FROM relationship
    - ✅ `acquisitionContextItems` - Items with HAS ACQ CONTEXT relationship
    - ✅ `observationContextItems` - Items with HAS OBS CONTEXT relationship
    - ✅ `selectedFromItems` - Items with SELECTED FROM relationship
  - ✅ **Measurement Navigation**
    - ✅ `findMeasurements()` - All numeric content items
    - ✅ `findMeasurements(forConcept:)` - Measurements by concept
    - ✅ `findMeasurements(forConceptString:)` - Measurements by string
    - ✅ `findMeasurementGroups()` - Containers with measurements
    - ✅ `getMeasurementValue(forConcept:)` - Direct value access
- ✅ **Structured Reporting Document Creation (v0.9.6)** (NEW)
  - ✅ **SRDocumentBuilder** - Fluent API for creating SR documents
    - ✅ Document type selection (Basic Text, Enhanced, Comprehensive, 3D)
    - ✅ Patient, Study, Series, and Document information setters
    - ✅ Completion, Verification, and Preliminary flag configuration
    - ✅ Template identifier support
    - ✅ UID auto-generation for new documents
  - ✅ **Content Item Creation**
    - ✅ `addText()`, `addCode()`, `addNumeric()` - Basic value types
    - ✅ `addDate()`, `addTime()`, `addDateTime()` - Temporal values
    - ✅ `addPersonName()`, `addUIDRef()` - Person and UID references
    - ✅ `addContainer()` - Nested container support
    - ✅ `addImageReference()`, `addCompositeReference()`, `addWaveformReference()` - Object references
    - ✅ `addSpatialCoordinates()`, `addSpatialCoordinates3D()` - Spatial coordinates
    - ✅ `addTemporalCoordinates()` - Temporal coordinates
  - ✅ **SRDocumentSerializer** - Convert SRDocument to DataSet
    - ✅ Content Sequence generation from content tree
    - ✅ Code Sequence serialization
    - ✅ Measured Value Sequence for numeric content
    - ✅ Referenced SOP Sequence for object references
  - ✅ **Validation**
    - ✅ Value type compatibility checking per document type
    - ✅ Configurable validation (enabled/disabled)
  - ✅ **Result Builder Syntax**
    - ✅ `@ContainerBuilder` for declarative container construction
  - ✅ **Round-Trip Support**
    - ✅ Create → Serialize → Parse produces valid documents
- ✅ **Template Support (v0.9.7)** (NEW in v0.9.7)
  - ✅ **Template Infrastructure**
    - ✅ `SRTemplate` protocol for template definitions
    - ✅ `TemplateIdentifier` for TID references with version support
    - ✅ `TemplateRegistry` for template lookup by TID
    - ✅ Template version handling
    - ✅ Extensible template system
  - ✅ **Template Constraint Types**
    - ✅ `TemplateRow` - Single template row definition with all constraints
    - ✅ `RequirementLevel` enum (Mandatory, Mandatory Conditional, User Conditional, Conditional)
    - ✅ `Cardinality` struct (1, 0-1, 1-n, 0-n, custom ranges)
    - ✅ `ConceptNameConstraint` - Concept name validation
    - ✅ `ValueConstraint` - Value validation for coded/numeric items
    - ✅ `TemplateRowCondition` - Conditional row application
  - ✅ **Template Validation**
    - ✅ `TemplateValidator` for checking content compliance
    - ✅ `TemplateViolation` for detailed violation reporting
    - ✅ `TemplateValidationResult` with errors and warnings
    - ✅ Strict vs. lenient validation modes
    - ✅ Warning vs. error classification
    - ✅ Factory methods for common violations
  - ✅ **Template Detection**
    - ✅ `TemplateDetector` for auto-detecting applicable templates
    - ✅ Confidence-based template matching
    - ✅ Multiple template detection with ranking
  - ✅ **Core Templates (PS3.16)**
    - ✅ TID 300 - Measurement
    - ✅ TID 320 - Image Library Entry
    - ✅ TID 1001 - Observation Context
    - ✅ TID 1002 - Observer Context
    - ✅ TID 1204 - Language of Content
  - ✅ **Measurement Templates**
    - ✅ TID 1400 - Linear Measurements
    - ✅ TID 1410 - Planar ROI Measurements
    - ✅ TID 1411 - Volumetric ROI Measurements
    - ✅ TID 1419 - ROI Measurements
    - ✅ TID 1420 - Measurements Derived from Multiple ROI Measurements
  - ✅ **Document Templates (NEW in v0.9.8)**
    - ✅ TID 1500 - Measurement Report (root template for quantitative imaging)
    - ✅ TID 1501 - Measurement Group (grouped measurements with tracking)
    - ✅ TID 1600 - Image Library (source image references)
- ✅ **Structured Reporting Document Parsing (v0.9.2)**
  - ✅ **SR Document Parser**
    - ✅ `SRDocumentParser` - Parse DICOM SR data sets into content item trees
    - ✅ `SRDocument` - Parsed SR document representation with metadata
    - ✅ Configurable validation levels (strict, lenient)
    - ✅ Maximum depth protection for deeply nested documents
  - ✅ **SR Document Model**
    - ✅ Document type detection from SOP Class UID
    - ✅ Patient, Study, and Series information extraction
    - ✅ Completion, Verification, and Preliminary flags
    - ✅ Content tree traversal and search APIs
  - ✅ **Content Item Parsing**
    - ✅ All 15 value types parsed from Content Sequence
    - ✅ Concept Name Code Sequence parsing
    - ✅ Relationship Type extraction
    - ✅ Observation DateTime and UID support
  - ✅ **Reference Parsing**
    - ✅ Referenced SOP Sequence parsing
    - ✅ Frame and Segment number extraction
    - ✅ Purpose of Reference code support
  - ✅ **Coordinate Parsing**
    - ✅ 2D Spatial Coordinates (SCOORD) with Graphic Type
    - ✅ 3D Spatial Coordinates (SCOORD3D) with Frame of Reference
    - ✅ Temporal Coordinates (TCOORD) with Range Type
- ✅ **Structured Reporting Core Infrastructure (v0.9.1)**
  - ✅ **Content Item Value Types** - All 15 DICOM SR value types
    - ✅ `TextContentItem` - Unstructured text (TEXT)
    - ✅ `CodeContentItem` - Coded concept from terminology (CODE)
    - ✅ `NumericContentItem` - Quantitative value with units (NUM)
    - ✅ `DateContentItem`, `TimeContentItem`, `DateTimeContentItem` - Temporal values
    - ✅ `PersonNameContentItem` - Person name (PNAME)
    - ✅ `UIDRefContentItem` - DICOM UID reference (UIDREF)
    - ✅ `ContainerContentItem` - Groups other content items (CONTAINER)
    - ✅ `CompositeContentItem`, `ImageContentItem`, `WaveformContentItem` - References
    - ✅ `SpatialCoordinatesContentItem` - 2D spatial coordinates (SCOORD)
    - ✅ `SpatialCoordinates3DContentItem` - 3D spatial coordinates (SCOORD3D)
    - ✅ `TemporalCoordinatesContentItem` - Temporal coordinates (TCOORD)
  - ✅ **Coded Concept Support**
    - ✅ `CodedConcept` struct with Code Value, Coding Scheme Designator, Code Meaning
    - ✅ `CodingSchemeDesignator` enum (DCM, SCT, LOINC, UCUM, FMA, RADLEX, etc.)
    - ✅ Coded concept validation and common concept constants
  - ✅ **Relationship Types**
    - ✅ `RelationshipType` enum (CONTAINS, HAS PROPERTIES, INFERRED FROM, etc.)
    - ✅ Relationship validation per value type constraints
  - ✅ **Content Item Protocol and Tree Building**
    - ✅ `ContentItem` protocol for polymorphic tree building
    - ✅ `AnyContentItem` type-erased wrapper for heterogeneous collections
    - ✅ `ContinuityOfContent` for CONTAINER semantics
  - ✅ **SR Document Types**
    - ✅ `SRDocumentType` enum with 18 document types
    - ✅ SOP Class UID constants for all SR types
    - ✅ Value type constraints per document type
  - ✅ **Supporting Types**
    - ✅ `GraphicType`, `GraphicType3D` for spatial coordinates
    - ✅ `TemporalRangeType` for temporal coordinates
    - ✅ `NumericValueQualifier` for special numeric values
    - ✅ `ReferencedSOP`, `ImageReference`, `WaveformReference` for object references
- ✅ **Advanced DICOMweb Features (v0.8.8)**
  - ✅ **OAuth2/OpenID Connect Authentication**
    - ✅ `OAuth2Configuration` for OAuth2 settings
    - ✅ `OAuth2Token` for token representation with expiration tracking
    - ✅ `OAuth2TokenProvider` protocol for token management
    - ✅ `OAuth2TokenManager` actor with automatic token refresh
    - ✅ Client credentials flow (machine-to-machine)
    - ✅ Authorization code flow with PKCE support
    - ✅ SMART on FHIR compatibility with standard scopes
    - ✅ `StaticTokenProvider` for testing
  - ✅ **Server Authentication Middleware (NEW in v0.8.8)**
    - ✅ `JWTClaims` struct for JWT token claim parsing
    - ✅ `JWTVerifier` protocol for pluggable token verification
    - ✅ `UnsafeJWTParser` for token parsing without signature verification
    - ✅ `HMACJWTVerifier` for HMAC-SHA256/384/512 signature verification
    - ✅ `AuthenticationMiddleware` for request authentication
    - ✅ `AuthenticatedUser` struct for authenticated context
    - ✅ `DICOMwebRole` enum (reader, writer, deleter, worklistManager, admin)
    - ✅ `RoleBasedAccessPolicy` for role-based access control
    - ✅ `AccessPolicy` protocol for custom authorization rules
    - ✅ Study-level and patient-level access control
    - ✅ SMART on FHIR patient context support
  - ✅ **DICOMweb Server TLS Configuration (NEW in v0.8.8)**
    - ✅ `TLSConfiguration` struct for HTTPS settings
    - ✅ TLS 1.2/1.3 protocol version support
    - ✅ Certificate and private key loading (PEM/DER formats)
    - ✅ Mutual TLS (mTLS) client authentication
    - ✅ `TLSVersion` enum with protocol version comparison
    - ✅ `CertificateValidationMode` (strict, standard, permissive)
    - ✅ Configuration presets (strict, compatible, development, mutualTLS)
    - ✅ Configuration validation with detailed error messages
    - ✅ PEM content extraction and format detection
  - ✅ **Capability Discovery**
    - ✅ `DICOMwebCapabilities` struct for server capabilities
    - ✅ `GET /capabilities` server endpoint
    - ✅ Service, media type, and transfer syntax reporting
    - ✅ Query and store capability details
    - ✅ `ConformanceStatement` for DICOM conformance documents (NEW in v0.8.8)
    - ✅ `ConformanceStatementGenerator` for auto-generating statements (NEW in v0.8.8)
  - ✅ **Client-Side Caching**
    - ✅ `CacheConfiguration` with presets (default, minimal, aggressive)
    - ✅ `InMemoryCache` actor with LRU eviction
    - ✅ ETag and conditional request support
    - ✅ Cache-Control header parsing
    - ✅ Cache key generation utilities
  - ✅ **Server-Side Response Caching (NEW in v0.8.8)**
    - ✅ `ServerCacheMiddleware` actor for server-side response caching
    - ✅ ETag generation and conditional request handling (If-None-Match → 304)
    - ✅ Cache-Control response headers with configurable TTL
    - ✅ Automatic cache invalidation on mutations (STOW-RS, DELETE)
    - ✅ Cache statistics tracking (hits, misses, entry count)
    - ✅ Configurable via `DICOMwebServerConfiguration.cacheConfiguration`
  - ✅ **HTTP Response Compression (NEW in v0.8.8)**
    - ✅ `CompressionConfiguration` for configurable compression settings
    - ✅ `CompressionMiddleware` for server response compression
    - ✅ gzip and deflate algorithm support
    - ✅ Accept-Encoding header parsing with quality values
    - ✅ Content-type filtering (compressible vs excluded types)
    - ✅ Configurable minimum response size threshold
    - ✅ Vary header management for proper caching
    - ✅ Platform-aware implementation (Apple Compression framework)
  - ✅ **Monitoring and Logging**
    - ✅ `DICOMwebRequestLogger` protocol
    - ✅ `OSLogRequestLogger` for Apple platform integration
    - ✅ `ConsoleRequestLogger` for debugging
    - ✅ `DICOMwebMetrics` actor for performance tracking
    - ✅ Latency percentiles (p50, p95, p99)
    - ✅ Success/error rate tracking
  - ✅ **Unified DICOMweb Client API (NEW in v0.8.8)**
    - ✅ `DICOMwebClient` now supports all DICOMweb services in one client
    - ✅ WADO-RS retrieve operations (studies, series, instances, frames, rendered, thumbnails)
    - ✅ QIDO-RS query operations (search studies, series, instances)
    - ✅ STOW-RS store operations (single and batch uploads)
    - ✅ UPS-RS workitem operations (search, retrieve, create, update, change state, cancel, subscribe)
    - ✅ Request interceptors for customization (via HTTPClient)
    - ✅ Automatic token refresh (via OAuth2TokenProvider)
- ✅ **UPS-RS Worklist Services (v0.8.7, v0.8.9)**
  - ✅ `Workitem` struct for UPS workitem representation
  - ✅ `UPSState` enum with state machine (SCHEDULED, IN PROGRESS, COMPLETED, CANCELED)
  - ✅ `UPSPriority` enum (STAT, HIGH, MEDIUM, LOW)
  - ✅ `ProgressInformation` for tracking workitem progress
  - ✅ `HumanPerformer`, `CodedEntry`, `ReferencedInstance` supporting types
  - ✅ `UPSQuery` builder with fluent API for workitem searches
  - ✅ `UPSQueryResult` and `WorkitemResult` for query results
  - ✅ `UPSStorageProvider` protocol for workitem storage
  - ✅ `InMemoryUPSStorageProvider` for testing
  - ✅ State transition validation and Transaction UID tracking
  - ✅ Server routes for UPS-RS endpoints (/workitems/*)
  - ✅ Server handler implementations for all UPS-RS operations
  - ✅ Search workitems (GET /workitems)
  - ✅ Retrieve workitem (GET /workitems/{uid})
  - ✅ Create workitem (POST /workitems, POST /workitems/{uid})
  - ✅ Update workitem (PUT /workitems/{uid})
  - ✅ Change state (PUT /workitems/{uid}/state)
  - ✅ Request cancellation (PUT /workitems/{uid}/cancelrequest)
  - ✅ Subscription endpoints (subscribe/unsubscribe/suspend)
  - ✅ Capabilities endpoint includes UPS-RS support status
  - ✅ `UPSClient` for client-side workitem operations
  - ✅ **Event System (NEW in v0.8.9):**
    - ✅ 6 event types: StateReport, ProgressReport, CancelRequested, Assigned, Completed, Canceled
    - ✅ Subscription management with workitem-specific and global subscriptions
    - ✅ Event delivery infrastructure with queue management and retry logic
    - ✅ Event generation on state changes and progress updates
    - ✅ Deletion lock support for subscriptions
    - ✅ Event type filtering for targeted subscriptions
  - ✅ 173+ unit tests (83 UPS types + 90+ event system tests)
  - ✅ **Task Handling Enhancements (NEW in v1.8.0):**
    - ✅ `WorkitemBuilder` fluent API with factory methods (`scheduledProcedure`, `simpleTask`)
    - ✅ `Workitem.toDICOMJSON()` public serialization method
    - ✅ `Workitem.parse(json:)` static method for parsing from DICOM JSON
    - ✅ `Workitem.validate()` method with `WorkitemValidationError`
    - ✅ Round-trip serialization support (build → serialize → parse)
    - ✅ 40+ additional unit tests
- ✅ **DICOMweb Server STOW-RS Enhancements (v0.8.6)**
  - ✅ STOWConfiguration for configurable store behavior
  - ✅ DuplicatePolicy: reject (409 Conflict), replace, or accept (idempotent)
  - ✅ SOP Class validation with allowedSOPClasses whitelist
  - ✅ UID format validation per DICOM standard
  - ✅ Required attribute validation with additionalRequiredTags
  - ✅ Request body size validation (413 Payload Too Large)
  - ✅ STOWDelegate protocol for custom store handling
  - ✅ Support for single instance uploads (application/dicom)
  - ✅ Enhanced STOW-RS response with proper SOP Class UIDs
  - ✅ Failure reason codes (0x0110-0x0124)
  - ✅ Partial success responses (HTTP 202) with warnings
  - ✅ Retrieve URL in success response
  - ✅ Preset configurations: default, strict, permissive
- ✅ **DICOMweb Server (v0.8.5)**
  - ✅ DICOMwebServer actor for hosting DICOM services over HTTP
  - ✅ WADO-RS retrieve endpoints (study, series, instance, metadata)
  - ✅ QIDO-RS search endpoints (studies, series, instances)
  - ✅ STOW-RS store endpoint with multipart parsing
  - ✅ Delete endpoints for study/series/instance removal
  - ✅ DICOMwebStorageProvider protocol for pluggable backends
  - ✅ InMemoryStorageProvider for testing
  - ✅ DICOMwebRouter for URL pattern matching
  - ✅ DICOMwebServerConfiguration with TLS, CORS, rate limiting
  - ✅ DICOMwebRequest/DICOMwebResponse abstractions
  - ✅ CORS preflight handling for browser clients
  - ✅ X-Total-Count headers for pagination
- ✅ **DICOMweb STOW-RS Client (v0.8.4)**
  - ✅ Store DICOM instances to remote servers via HTTP POST
  - ✅ Single instance and batch store operations
  - ✅ Configurable batch size for server limits
  - ✅ Progress reporting with AsyncThrowingStream
  - ✅ Per-instance success/failure tracking
  - ✅ STOWResponse with stored instances and failures
  - ✅ Failure reason codes (duplicate, SOP class not supported, etc.)
  - ✅ Continue-on-error option for batch uploads
  - ✅ Multipart request generation (application/dicom)
- ✅ **DICOMweb QIDO-RS Client (v0.8.3)**
  - ✅ QIDOQuery builder with fluent API for constructing search queries
  - ✅ Study, series, and instance search endpoints
  - ✅ Standard query parameters: PatientName, PatientID, StudyDate, Modality, etc.
  - ✅ Wildcard matching support (*, ?)
  - ✅ Date/Time range queries
  - ✅ Pagination with limit and offset
  - ✅ Include field filtering (includefield parameter)
  - ✅ Fuzzy matching support
  - ✅ Type-safe result types (QIDOStudyResult, QIDOSeriesResult, QIDOInstanceResult)
  - ✅ Automatic X-Total-Count header parsing for pagination
- ✅ **DICOMweb WADO-RS Client (v0.8.2)**
  - ✅ DICOMwebClient for retrieving DICOM objects over HTTP/HTTPS
  - ✅ Study, series, and instance retrieval
  - ✅ Metadata retrieval (JSON format)
  - ✅ Frame-level retrieval for multi-frame images
  - ✅ Rendered image retrieval (JPEG, PNG, GIF)
  - ✅ Thumbnail retrieval at study, series, and instance levels
  - ✅ Bulk data retrieval with range requests
  - ✅ Transfer syntax negotiation
  - ✅ Streaming downloads with AsyncThrowingStream
  - ✅ Progress reporting (bytes and instances)
  - ✅ Cancellation support via Swift Task
  - ✅ Render options (windowing, viewport, quality)
- ✅ **DICOMweb Infrastructure (v0.8.1)**
  - ✅ HTTPClient with retry and interceptor support
  - ✅ DICOM JSON encoding/decoding (PS3.18 Annex F)
  - ✅ Multipart MIME parsing and generation
  - ✅ URL builder for all DICOMweb endpoints
  - ✅ Authentication (Basic, Bearer, API Key, Custom)
  - ✅ Configurable timeouts
- ✅ **Unified Storage Client (v0.7.8)**
  - ✅ DICOMStorageClient actor for unified storage operations
  - ✅ Server pool management with multiple storage destinations
  - ✅ Multiple selection strategies (round-robin, priority, weighted, random, failover)
  - ✅ Automatic server failover on connection failures
  - ✅ Per-server circuit breaker integration
  - ✅ Automatic retry with configurable policies
  - ✅ Per-SOP Class retry configuration
  - ✅ Optional store-and-forward queue integration
  - ✅ Transcoding and validation integration
- ✅ **Transfer Syntax Conversion (v0.7.7)**
  - ✅ Automatic transcoding when target server doesn't support source syntax
  - ✅ Configurable preferred transfer syntaxes with priority ordering
  - ✅ Support for uncompressed syntax conversion (Explicit/Implicit VR, Little/Big Endian)
  - ✅ Decompression support for RLE and JPEG compressed data
  - ✅ Pixel data fidelity preservation options
  - ✅ Lossless/lossy conversion constraints
  - ✅ Integration with DICOM Storage Service
- ✅ **Validation Before Send (v0.7.6)**
  - ✅ DICOMValidator for pre-send data validation
  - ✅ Configurable validation levels (minimal, standard, strict)
  - ✅ Required attribute checking (SOP Class UID, SOP Instance UID, Study/Series UIDs)
  - ✅ UID format validation
  - ✅ Pixel data attribute validation
  - ✅ Transfer Syntax validation
  - ✅ Allowed SOP Classes filtering
  - ✅ Custom required tags configuration
  - ✅ Detailed error and warning reporting
- ✅ **Intelligent Retry Logic (v0.7.5)**
  - ✅ Configurable retry policies with preset configurations
  - ✅ Exponential backoff with jitter to prevent thundering herd
  - ✅ Per-SOP Class retry policy configuration
  - ✅ Integration with error categories (transient, permanent, timeout, resource)
  - ✅ Integration with circuit breaker pattern
  - ✅ Retry executor with progress callbacks
  - ✅ Multiple retry strategies (fixed, exponential, linear)
- ✅ **Audit Logging (v0.7.5)**
  - ✅ IHE ATNA-aligned audit event types for healthcare compliance
  - ✅ Comprehensive audit log entries with transfer metadata
  - ✅ Multiple audit handlers (console, file, OSLog)
  - ✅ File audit logging with JSON Lines format and rotation
  - ✅ Event type filtering for targeted auditing
  - ✅ Storage operation logging helpers
- ✅ **Network Error Handling (v0.7.5)**
  - ✅ Error categorization (transient, permanent, configuration, protocol, timeout, resource)
  - ✅ Recovery suggestions with actionable guidance
  - ✅ Fine-grained timeout configuration (connect, read, write, operation, association)
  - ✅ Preset timeout configurations (.default, .fast, .slow)
  - ✅ Detailed timeout types for diagnosis
  - ✅ Retryability detection for intelligent retry strategies
- ✅ **TLS Security (v0.7.4)**
  - ✅ TLS 1.2/1.3 encryption for DICOM connections
  - ✅ System trust store validation (default)
  - ✅ Certificate pinning for enhanced security
  - ✅ Custom CA trust roots for enterprise PKI
  - ✅ Self-signed certificate support (development mode)
  - ✅ Mutual TLS (mTLS) client authentication
  - ✅ PKCS#12 and keychain identity loading
  - ✅ Preset configurations (.default, .strict, .insecure)
- ✅ **DICOM Storage SCP (v0.7.3)**
  - ✅ Receive DICOM files from remote sources
  - ✅ C-STORE SCP server implementation
  - ✅ Configurable AE whitelist/blacklist
  - ✅ Support for common Storage SOP Classes
  - ✅ Transfer syntax negotiation
  - ✅ StorageDelegate protocol for custom handling
  - ✅ Default file storage handler
  - ✅ Real-time event streaming with AsyncStream
  - ✅ Multiple concurrent associations support
- ✅ **DICOM Batch Storage (v0.7.2)**
  - ✅ Efficient batch transfer of multiple DICOM files
  - ✅ Single association reuse for improved performance
  - ✅ Real-time progress reporting with AsyncStream
  - ✅ Per-file success/failure tracking
  - ✅ Configurable continue-on-error vs fail-fast behavior
  - ✅ Rate limiting support
- ✅ **DICOM Storage Service (v0.7)**
  - ✅ C-STORE SCU for sending DICOM files to remote destinations
  - ✅ Support for all common Storage SOP Classes (CT, MR, CR, DX, US, SC, RT)
  - ✅ Transfer syntax negotiation
  - ✅ Priority support (LOW, MEDIUM, HIGH)
  - ✅ Detailed store result with status codes
  - ✅ Integration with DICOMClient unified API
- ✅ **DICOM Networking (v0.6)**
  - ✅ C-ECHO verification service for connectivity testing
  - ✅ C-FIND query service for finding studies, series, and instances
  - ✅ C-MOVE retrieve service for moving images to a destination AE
  - ✅ C-GET retrieve service for downloading images directly
  - ✅ Patient Root and Study Root Query/Retrieve Information Models
  - ✅ All query levels (PATIENT, STUDY, SERIES, IMAGE)
  - ✅ Wildcard matching support (*, ?)
  - ✅ Date/Time range queries
  - ✅ Type-safe query and retrieve result data structures
  - ✅ Progress reporting with sub-operation counts
  - ✅ Async/await-based API with AsyncStream for streaming results
- ✅ **DICOM file reading and writing** (v0.5)
  - ✅ Create new DICOM files from scratch
  - ✅ Modify existing DICOM files
  - ✅ File Meta Information generation
  - ✅ UID generation utilities
  - ✅ Data element serialization for all VRs
  - ✅ Sequence writing support
  - ✅ Value padding per DICOM specification
  - ✅ Round-trip read → write → read support
- ✅ **Multiple transfer syntax support**:
  - ✅ Explicit VR Little Endian
  - ✅ Implicit VR Little Endian
  - ✅ Explicit VR Big Endian (Retired)
  - ✅ Deflated Explicit VR Little Endian
- ✅ **Compressed pixel data support**:
  - ✅ JPEG Baseline (Process 1) - 1.2.840.10008.1.2.4.50
  - ✅ JPEG Extended (Process 2 & 4) - 1.2.840.10008.1.2.4.51
  - ✅ JPEG Lossless (Process 14) - 1.2.840.10008.1.2.4.57
  - ✅ JPEG Lossless SV1 (Process 14, Selection Value 1) - 1.2.840.10008.1.2.4.70
  - ✅ JPEG 2000 Lossless - 1.2.840.10008.1.2.4.90
  - ✅ JPEG 2000 Lossy - 1.2.840.10008.1.2.4.91
  - ✅ RLE Lossless - 1.2.840.10008.1.2.5
- ✅ **Encapsulated pixel data parsing** - Fragment and offset table support
- ✅ **Extensible codec architecture** - Plugin-based codec support
- ✅ **Uncompressed pixel data extraction** - Extract and render medical images
- ✅ **Pixel data error handling** - Detailed error types for unsupported formats
- ✅ **Photometric interpretation support**:
  - ✅ MONOCHROME1
  - ✅ MONOCHROME2
  - ✅ RGB
  - ✅ PALETTE COLOR
  - ✅ YBR color spaces
- ✅ **Multi-frame image support** - Work with CT, MR and other multi-slice images
- ✅ **Window/Level (VOI LUT)** - Apply Window Center/Width transformations
- ✅ **CGImage rendering** - Display images on Apple platforms
- ✅ **Sequence (SQ) parsing** - Full support for nested data sets
- ✅ **Type-safe API** - Leverages Swift's type system for safety
- ✅ **Value semantics** - Immutable data structures with `struct` and `enum`
- ✅ **Strict concurrency** - Full Swift 6 concurrency support
- ✅ **DICOM 2026a compliant** - Based on latest DICOM standard
- ✅ **Universal architecture** - Supports both Apple Silicon (M-series) and Intel (x86_64) processors
- ✅ **Encapsulated Document Support (NEW in v1.1.0)** - Store non-DICOM documents as DICOM objects
  - ✅ Encapsulated PDF Storage (1.2.840.10008.5.1.4.1.1.104.1)
  - ✅ Encapsulated CDA Storage (1.2.840.10008.5.1.4.1.1.104.2)
  - ✅ Encapsulated STL Storage (1.2.840.10008.5.1.4.1.1.104.3)
  - ✅ Encapsulated OBJ Storage (1.2.840.10008.5.1.4.1.1.104.4)
  - ✅ Encapsulated MTL Storage (1.2.840.10008.5.1.4.1.1.104.5)
  - ✅ `EncapsulatedDocumentParser` for extracting documents from DICOM files
  - ✅ `EncapsulatedDocumentBuilder` fluent API for creating DICOM-wrapped documents
  - ✅ Concept Name Code Sequence support
  - ✅ Source Instance reference tracking
  - ✅ HL7 CDA instance identifier support
  - ✅ Round-trip build → serialize → parse support
  - ✅ 40+ unit tests
- ✅ **DICOM Print Management (NEW in v1.4.0)** - Print Management Service Class (PS3.4 Annex H)
  - ✅ Complete DIMSE-N message types: N-CREATE, N-SET, N-GET, N-DELETE (request/response)
  - ✅ Print Management SOP Class UIDs (Film Session, Film Box, Image Box, Printer, Print Job)
  - ✅ `DICOMPrintService` for print management operations
    - ✅ `getPrinterStatus()` - Query printer status via N-GET (v1.4.0)
    - ✅ `createFilmSession()` - Create film session via N-CREATE (v1.4.0)
    - ✅ `deleteFilmSession()` - Delete film session via N-DELETE (v1.4.0)
    - ✅ `createFilmBox()` - Create film box with image boxes via N-CREATE (NEW in v1.4.1)
  - ✅ `FilmSession` - Session parameters (copies, priority, medium, destination)
  - ✅ `FilmBox` - Layout parameters (display format, orientation, size, magnification)
  - ✅ `FilmBoxResult` - Film box creation result with image box UIDs (NEW in v1.4.1)
  - ✅ `ImageBoxContent` - Image content (position, polarity, crop behavior)
  - ✅ `PrinterStatus` - Printer status retrieval via N-GET
  - ✅ 35 Print-specific DICOM tags (groups 0x2000, 0x2010, 0x2020, 0x2100, 0x2110)
  - ✅ 12 film sizes, 4 magnification types, 5 medium types
  - ✅ Image Display Format parsing (STANDARD\rows,columns)
  - ✅ Improved MPPS response validation (N-CREATE/N-SET status checking)
  - ✅ 59+ unit tests (NEW in v1.4.1)
  - 📄 **[DICOM_PRINTER_PLAN.md](DICOM_PRINTER_PLAN.md)** - Comprehensive 5-phase enhancement roadmap (v1.4.1-v1.4.5)
    - Phase 1: Complete print workflow (film session, film box, image box, print execution)
    - Phase 2: High-level print API (templates, progress, cancellation, retry)
    - Phase 3: Image preparation pipeline (preprocessing, sizing, annotation overlay)
    - Phase 4: Advanced features (print queue, multiple printers, error recovery)
    - Phase 5: Documentation and CLI tool (`dicom-print`)
    - Timeline: 8-10 weeks, 120+ unit tests, 20+ integration tests

- ✅ **Waveform Data Support (NEW in v1.5.0)** - DICOM Waveform IOD support (PS3.3 A.34)
  - ✅ 9 Waveform SOP Classes (12-Lead ECG, General ECG, Ambulatory ECG, Hemodynamic, Cardiac Electrophysiology, Basic Voice Audio, General Audio, Arterial Pulse, Respiratory)
  - ✅ `Waveform` data model with multiplex groups and channel definitions
  - ✅ `WaveformMultiplexGroup` - Multi-channel interleaved sample extraction
  - ✅ `WaveformChannel` - Channel calibration (sensitivity, baseline, correction factor, offset)
  - ✅ `WaveformAnnotation` - Text and measurement annotations with temporal ranges
  - ✅ `WaveformParser` - Parse waveform data from DICOM DataSets
  - ✅ `WaveformBuilder` - Fluent API for creating waveform DICOM objects
  - ✅ 8-bit and 16-bit sample support (signed and unsigned)
  - ✅ Channel source coded concepts (SCPECG, LOINC)
  - ✅ DICOM Part 10 file creation integration
  - ✅ 40+ unit tests

- ✅ **DICOM Video Support (NEW in v1.6.0)** - DICOM Video IOD support (PS3.3 A.32.5-7)
  - ✅ 3 Video SOP Classes (Video Endoscopic, Video Microscopic, Video Photographic)
  - ✅ 6 Video Transfer Syntaxes:
    - ✅ MPEG2 Main Profile / Main Level (1.2.840.10008.1.2.4.100)
    - ✅ MPEG2 Main Profile / High Level (1.2.840.10008.1.2.4.101)
    - ✅ MPEG-4 AVC/H.264 High Profile / Level 4.1 (1.2.840.10008.1.2.4.102)
    - ✅ MPEG-4 AVC/H.264 BD-compatible High Profile / Level 4.1 (1.2.840.10008.1.2.4.103)
    - ✅ HEVC/H.265 Main Profile / Level 5.1 (1.2.840.10008.1.2.4.107)
    - ✅ HEVC/H.265 Main 10 Profile / Level 5.1 (1.2.840.10008.1.2.4.108)
  - ✅ `Video` data model with frame rate, duration, resolution, and cine metadata
  - ✅ `VideoType` enum (endoscopic, microscopic, photographic)
  - ✅ `VideoCodec` enum (mpeg2, h264, h265) with compression method identifiers
  - ✅ `VideoParser` - Parse video metadata from DICOM DataSets
  - ✅ `VideoBuilder` - Fluent API for creating video DICOM objects
  - ✅ Transfer syntax detection: `isVideo`, `isMPEG2`, `isH264`, `isH265`
  - ✅ DICOM Part 10 file creation integration
  - ✅ 44 unit tests

- ✅ **Secondary Capture Image IOD (NEW in v1.7.0)** - DICOM Secondary Capture IOD support (PS3.3 A.8)
  - ✅ 5 SC SOP Classes:
    - ✅ Secondary Capture Image Storage (1.2.840.10008.5.1.4.1.1.7)
    - ✅ Multi-frame Single Bit SC Image Storage (1.2.840.10008.5.1.4.1.1.7.1)
    - ✅ Multi-frame Grayscale Byte SC Image Storage (1.2.840.10008.5.1.4.1.1.7.2)
    - ✅ Multi-frame Grayscale Word SC Image Storage (1.2.840.10008.5.1.4.1.1.7.3)
    - ✅ Multi-frame True Color SC Image Storage (1.2.840.10008.5.1.4.1.1.7.4)
  - ✅ `SecondaryCaptureImage` data model with pixel characteristics, metadata, and computed properties
  - ✅ `SecondaryCaptureType` enum with default pixel characteristics per type
  - ✅ `ConversionType` enum (DV, DI, DF, WSD, SD, SI, SYN) for SC Equipment Module
  - ✅ `SecondaryCaptureParser` - Parse SC metadata from DICOM DataSets
  - ✅ `SecondaryCaptureBuilder` - Fluent API for creating SC DICOM objects
  - ✅ SC-specific DICOM tags (Conversion Type, Date/Time of SC, Page Number Vector)
  - ✅ DICOM Part 10 file creation integration
  - ✅ 42 unit tests

## Limitations (v1.8.0)

The following features have known limitations or are not yet implemented:

| Category | Limitation | Status |
|----------|------------|--------|
| **Character Sets** | Extended character set conversion is read-only | ⚠️ Partial support via v1.0.9 |
| **Transfer Syntaxes** | JPEG-LS and HTJ2K codecs not native | ❌ Platform codec fallback |
| **DICOM Print** | Complete Print Management Service Class | ✅ v1.4.5 complete (all phases) |
| **DICOM Storage Commitment** | Not implemented | ❌ Planned |
| **DICOM Worklist Push** | Not implemented | ❌ Planned |
| **Query/Retrieve Relational** | Basic Q/R only | ⚠️ No relational queries |

### What Works Well

✅ **Fully Supported:**
- All 31 DICOM Value Representations (VR)
- 7+ Transfer Syntaxes including JPEG, JPEG2000, RLE
- Complete DIMSE services (C-ECHO, C-FIND, C-MOVE, C-GET, C-STORE)
- DICOMweb (QIDO-RS, WADO-RS, STOW-RS, UPS-RS)
- Structured Reporting with 8 specialized builders
- RT Structure Sets, Segmentation Objects, Parametric Maps
- Presentation States (GSPS), Hanging Protocols
- TLS 1.2/1.3 with client certificates
- Memory-mapped large file handling
- 2,180+ comprehensive unit tests

These features may be added in future versions. See [MILESTONES.md](MILESTONES.md) for the development roadmap.

---

## Platform Requirements

### Supported Platforms

| Platform | Minimum Version | Architecture | Notes |
|----------|-----------------|--------------|-------|
| **iOS** | 17.0+ | arm64 | iPhone, iPad |
| **macOS** | 14.0+ | arm64, x86_64 | Apple Silicon and Intel |
| **visionOS** | 1.0+ | arm64 | Apple Vision Pro |

### Build Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Swift** | 6.2+ | Required for strict concurrency |
| **Xcode** | 16.0+ | For Apple platform development |
| **macOS** | 14.0+ | For building and CLI tools |

### Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Swift Argument Parser | 1.3.0+ | CLI tools argument parsing |
| AWS SDK Swift | 1.6.0+ | Cloud storage integration (optional) |

---

## Installation

### Swift Package Manager (Framework)

Add DICOMKit to your `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyDICOMApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    dependencies: [
        .package(url: "https://github.com/Raster-Lab/DICOMKit.git", from: "1.8.0")
    ],
    targets: [
        .target(
            name: "MyDICOMApp",
            dependencies: [
                .product(name: "DICOMKit", package: "DICOMKit")
            ]
        )
    ]
)
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/Raster-Lab/DICOMKit`
3. Select version 1.8.0 or later

#### Available Products

Choose the modules you need:

| Product | Description | Dependencies |
|---------|-------------|--------------|
| `DICOMKit` | Full toolkit (recommended) | DICOMCore, DICOMDictionary |
| `DICOMCore` | Core types and utilities | None |
| `DICOMDictionary` | Tag and UID dictionaries | DICOMCore |
| `DICOMNetwork` | DICOM networking (DIMSE) | DICOMCore, DICOMDictionary |
| `DICOMWeb` | DICOMweb services | DICOMCore, DICOMKit |
| `DICOMToolbox` | CLI tool utilities | None |

### Homebrew (CLI Tools)

Install all 38 CLI tools via Homebrew using the local formula:

```bash
# Clone the repository
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit

# Install using local formula (builds from source)
brew install --build-from-source Formula/dicomkit.rb
```

Or build and install directly:

```bash
# Clone and install using the provided script
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit
./Scripts/install-cli-tools.sh
```

### Other Installation Methods

- **Manual Build**: `swift build -c release && cp .build/release/dicom-* /usr/local/bin/`
- **Docker**: See [DISTRIBUTION.md](DISTRIBUTION.md) for container deployment

📖 **Complete installation guide**: [INSTALLATION.md](INSTALLATION.md)  
📦 **Distribution guide**: [DISTRIBUTION.md](DISTRIBUTION.md)

## Quick Start

```swift
import DICOMKit
import Foundation

// Read a DICOM file
let fileData = try Data(contentsOf: fileURL)
let dicomFile = try DICOMFile.read(from: fileData)

// Access File Meta Information
if let transferSyntax = dicomFile.transferSyntaxUID {
    print("Transfer Syntax: \(transferSyntax)")
}

// Access data elements from the main data set
if let patientName = dicomFile.dataSet.string(for: .patientName) {
    print("Patient Name: \(patientName)")
}

// Access date/time values with type-safe parsing
if let studyDate = dicomFile.dataSet.date(for: .studyDate) {
    print("Study Date: \(studyDate.year)-\(studyDate.month)-\(studyDate.day)")
    
    // Convert to Foundation Date if needed
    if let date = studyDate.toDate() {
        print("As Foundation Date: \(date)")
    }
}

if let studyTime = dicomFile.dataSet.time(for: .studyTime) {
    print("Study Time: \(studyTime.hour):\(studyTime.minute ?? 0)")
}

// Access age values with type-safe parsing
if let patientAge = dicomFile.dataSet.age(for: .patientAge) {
    print("Patient Age: \(patientAge.humanReadable)")  // e.g., "45 years"
    print("Age in years: \(patientAge.approximateYears)")
}

// Access numeric string values (DS and IS)
if let sliceThickness = dicomFile.dataSet.decimalString(for: .sliceThickness) {
    print("Slice Thickness: \(sliceThickness.value) mm")
}

if let pixelSpacing = dicomFile.dataSet.decimalStrings(for: .pixelSpacing) {
    print("Pixel Spacing: \(pixelSpacing.map { $0.value })")  // e.g., [0.3125, 0.3125]
}

if let instanceNumber = dicomFile.dataSet.integerString(for: .instanceNumber) {
    print("Instance Number: \(instanceNumber.value)")
}

// Access Code String (CS) values
if let modality = dicomFile.dataSet.codeString(for: .modality) {
    print("Modality: \(modality.value)")  // e.g., "CT", "MR"
}

if let imageType = dicomFile.dataSet.codeStrings(for: .imageType) {
    print("Image Type: \(imageType.map { $0.value })")  // e.g., ["ORIGINAL", "PRIMARY", "AXIAL"]
}

// Access Application Entity (AE) values
if let ae = dicomFile.dataSet.applicationEntity(for: .sourceApplicationEntityTitle) {
    print("Source AE: \(ae.value)")  // e.g., "STORESCU"
    print("Padded: \(ae.paddedValue)")  // 16-character padded format
}

// Access Universal Resource (UR) values
if let uri = dicomFile.dataSet.universalResource(for: Tag(group: 0x0008, element: 0x1190)) {
    print("Retrieve URL: \(uri.value)")  // e.g., "http://server/wado?..."
    print("Scheme: \(uri.scheme ?? "none")")  // e.g., "http"
    if let url = uri.url {
        print("Foundation URL: \(url)")
    }
}

// Access sequence (SQ) elements
if let items = dicomFile.dataSet.sequence(for: .procedureCodeSequence) {
    for item in items {
        if let codeValue = item.string(for: Tag(group: 0x0008, element: 0x0100)) {
            print("Code Value: \(codeValue)")
        }
    }
}

// Iterate through all elements
for element in dicomFile.dataSet {
    print("\(element.tag): \(element.vr)")
}
```

### Pixel Data Access (v0.3)

```swift
import DICOMKit

// Extract pixel data from DICOM file
if let pixelData = dicomFile.pixelData() {
    let descriptor = pixelData.descriptor
    print("Image size: \(descriptor.columns) x \(descriptor.rows)")
    print("Bits allocated: \(descriptor.bitsAllocated)")
    print("Bits stored: \(descriptor.bitsStored)")
    print("Number of frames: \(descriptor.numberOfFrames)")
    
    // Get pixel value range
    if let range = pixelData.pixelRange(forFrame: 0) {
        print("Pixel range: \(range.min) to \(range.max)")
    }
    
    // Access individual pixel values
    if let value = pixelData.pixelValue(row: 100, column: 100) {
        print("Pixel at (100, 100): \(value)")
    }
    
    // For RGB images, get color values
    if let color = pixelData.colorValue(row: 100, column: 100) {
        print("RGB: (\(color.red), \(color.green), \(color.blue))")
    }
}

// Get image dimensions
if let rows = dicomFile.imageRows, let cols = dicomFile.imageColumns {
    print("Image dimensions: \(cols) x \(rows)")
}

// Check photometric interpretation
if let pi = dicomFile.photometricInterpretation {
    print("Photometric Interpretation: \(pi.rawValue)")
    print("Is monochrome: \(pi.isMonochrome)")
}

// Get window settings from DICOM file
if let window = dicomFile.windowSettings() {
    print("Window Center: \(window.center)")
    print("Window Width: \(window.width)")
    if let explanation = window.explanation {
        print("Window explanation: \(explanation)")
    }
}

// Get all window presets
let allWindows = dicomFile.allWindowSettings()
for (index, window) in allWindows.enumerated() {
    print("Window \(index): C=\(window.center), W=\(window.width)")
}

// Apply rescale transformation (e.g., for CT Hounsfield Units)
let slope = dicomFile.rescaleSlope()
let intercept = dicomFile.rescaleIntercept()
let hounsfield = dicomFile.rescale(1024.0)  // Convert stored value to HU
print("Hounsfield Units: \(hounsfield)")
```

### Error Handling for Pixel Data Extraction

The `tryPixelData()` method provides detailed error information when pixel data extraction fails. This is useful for providing meaningful feedback to users when working with unsupported or malformed DICOM files.

```swift
import DICOMKit
import DICOMCore

// Use tryPixelData() for detailed error handling
do {
    let pixelData = try dicomFile.tryPixelData()
    print("Successfully extracted \(pixelData.descriptor.numberOfFrames) frame(s)")
} catch let error as PixelDataError {
    // Handle specific error types
    switch error {
    case .missingDescriptor:
        print("Missing required pixel data attributes")
    case .missingPixelData:
        print("No pixel data in this DICOM file")
    case .missingTransferSyntax:
        print("Transfer syntax UID missing from file metadata")
    case .unsupportedTransferSyntax(let uid):
        if let name = error.transferSyntaxName {
            print("Unsupported transfer syntax: \(name) (\(uid))")
        } else {
            print("Unsupported transfer syntax: \(uid)")
        }
    case .frameExtractionFailed(let frameIndex):
        print("Failed to extract frame \(frameIndex)")
    case .decodingFailed(let frameIndex, let reason):
        print("Failed to decode frame \(frameIndex): \(reason)")
    }
    
    // Get user-friendly explanation
    print("Details: \(error.explanation)")
}
```

**PixelDataError cases:**
- `.missingDescriptor` - Required attributes (Rows, Columns, Bits Allocated) are missing
- `.missingPixelData` - No pixel data element in the DICOM file
- `.missingTransferSyntax` - Transfer syntax UID is missing from file metadata
- `.unsupportedTransferSyntax(uid)` - Compressed format without a decoder (e.g., JPEG-LS)
- `.frameExtractionFailed(frameIndex)` - Cannot extract frame from encapsulated data
- `.decodingFailed(frameIndex, reason)` - Codec failed to decompress the data

### Rendering to CGImage (Apple platforms only)

```swift
import DICOMKit
#if canImport(CoreGraphics)
import CoreGraphics

// Render using automatic windowing
if let cgImage = dicomFile.renderFrame(0) {
    // Use the CGImage with SwiftUI, UIKit, or AppKit
}

// Render with custom window settings
let customWindow = WindowSettings(center: 40.0, width: 400.0)  // Soft tissue
if let cgImage = dicomFile.renderFrame(0, window: customWindow) {
    // Use the windowed image
}

// Render using window settings from the DICOM file
if let cgImage = dicomFile.renderFrameWithStoredWindow(0) {
    // Use the image with stored window/level
}

// Error-throwing render methods for better diagnostics (CT images, etc.)
do {
    let cgImage = try dicomFile.tryRenderFrame(0)
    // Use the rendered image
} catch let error as PixelDataError {
    print("Render failed: \(error.description)")
    print("Explanation: \(error.explanation)")
}

// Use PixelDataRenderer for more control
if let pixelData = dicomFile.pixelData() {
    let renderer = PixelDataRenderer(pixelData: pixelData)
    
    // Render monochrome with specific window
    let window = WindowSettings(center: 50.0, width: 350.0, explanation: "BONE")
    if let image = renderer.renderMonochromeFrame(0, window: window) {
        // Use the rendered image
    }
    
    // Render multi-frame images
    for frameIndex in 0..<pixelData.descriptor.numberOfFrames {
        if let frame = renderer.renderFrame(frameIndex) {
            // Process each frame
        }
    }
}
#endif
```

### Grayscale Presentation State (GSPS) (v1.0.1)

```swift
import DICOMKit
#if canImport(CoreGraphics)
import CoreGraphics

// Parse a GSPS DICOM file
let gspsData = try Data(contentsOf: gspsFileURL)
let gspsFile = try DICOMFile.read(from: gspsData)
let parser = GrayscalePresentationStateParser()
let presentationState = try parser.parse(dataSet: gspsFile.dataSet)

print("Presentation Label: \(presentationState.presentationLabel ?? "Untitled")")
print("Referenced Series: \(presentationState.referencedSeries.count)")

// Apply presentation state to an image
let imageData = try Data(contentsOf: imageFileURL)
let imageFile = try DICOMFile.read(from: imageData)

let applicator = PresentationStateApplicator()
if let renderedImage = try applicator.apply(
    presentationState: presentationState,
    to: imageFile,
    frameNumber: 0
) {
    // Use the rendered image with presentation state applied
    // Includes window/level, spatial transformations, and annotations
}

// Access presentation state components
if let voiLUT = presentationState.voiLUT {
    switch voiLUT {
    case .windowLevel(let center, let width, let explanation):
        print("Window: Center=\(center), Width=\(width)")
        print("Explanation: \(explanation ?? "none")")
    case .lut(let lutData):
        print("Using explicit VOI LUT with \(lutData.numberOfEntries) entries")
    }
}

// Access graphic annotations
for layer in presentationState.graphicLayers {
    print("Layer: \(layer.layerName), Order: \(layer.layerOrder)")
}

for annotation in presentationState.graphicAnnotations {
    print("Annotation on layer: \(annotation.graphicLayer ?? "default")")
    
    for graphicObject in annotation.graphicObjects {
        print("  Graphic type: \(graphicObject.graphicType)")
        print("  Points: \(graphicObject.graphicData.count)")
    }
    
    for textObject in annotation.textObjects {
        print("  Text: \(textObject.unformattedTextValue)")
    }
}

// Access display shutters
if let shutter = presentationState.displayShutter {
    switch shutter {
    case .rectangular(let left, let right, let top, let bottom, let presentationValue):
        print("Rectangular shutter: (\(left), \(top)) to (\(right), \(bottom))")
    case .circular(let centerX, let centerY, let radius, let presentationValue):
        print("Circular shutter at (\(centerX), \(centerY)) radius \(radius)")
    case .polygonal(let points, let presentationValue):
        print("Polygonal shutter with \(points.count) points")
    case .bitmap(let rows, let columns, let origin, let data, let presentationValue):
        print("Bitmap shutter: \(columns)x\(rows)")
    }
}

// Access spatial transformations
if let transform = presentationState.spatialTransformation {
    print("Rotation: \(transform.rotation)°")
    print("Horizontal flip: \(transform.horizontalFlip)")
}
#endif
```

### DICOM File Writing (v0.5)

```swift
import DICOMKit
import Foundation

// Create a new DICOM file from scratch
var dataSet = DataSet()
dataSet.setString("Doe^John", for: .patientName, vr: .PN)
dataSet.setString("12345678", for: .patientID, vr: .LO)
dataSet.setString("20250131", for: .studyDate, vr: .DA)
dataSet.setUInt16(512, for: .rows)
dataSet.setUInt16(512, for: .columns)

// Create a DICOM file with auto-generated File Meta Information
let dicomFile = DICOMFile.create(
    dataSet: dataSet,
    sopClassUID: "1.2.840.10008.5.1.4.1.1.7",  // Secondary Capture Image Storage
    transferSyntaxUID: "1.2.840.10008.1.2.1"    // Explicit VR Little Endian
)

// Write to data
let fileData = try dicomFile.write()

// Save to file
try fileData.write(to: outputURL)

// Modify an existing file
var existingFile = try DICOMFile.read(from: inputData)
var modifiedDataSet = existingFile.dataSet
modifiedDataSet.setString("Anonymized", for: .patientName, vr: .PN)
modifiedDataSet.remove(tag: .patientBirthDate)

// Create new file with modified data set
let modifiedFile = DICOMFile.create(dataSet: modifiedDataSet)
let outputData = try modifiedFile.write()

// Generate unique UIDs
let generator = UIDGenerator()
let studyUID = generator.generateStudyInstanceUID()
let seriesUID = generator.generateSeriesInstanceUID()
let sopInstanceUID = generator.generateSOPInstanceUID()

// Or use static methods
let newUID = UIDGenerator.generateUID()
```

### DICOM Query Service (v0.6)

```swift
import DICOMNetwork
import Foundation

// Query for studies matching patient name and date range
let studies = try await DICOMQueryService.findStudies(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    matching: QueryKeys(level: .study)
        .patientName("DOE^JOHN*")   // Wildcard matching
        .studyDate("20240101-20241231")   // Date range
        .requestStudyDescription()   // Request additional fields
        .requestModalitiesInStudy()
)

// Process results
for study in studies {
    print("Study: \(study.studyInstanceUID ?? "Unknown")")
    print("  Date: \(study.studyDate ?? "N/A")")
    print("  Description: \(study.studyDescription ?? "N/A")")
    print("  Patient: \(study.patientName ?? "N/A")")
    print("  Modalities: \(study.modalities)")
    print("  Series: \(study.numberOfStudyRelatedSeries ?? 0)")
}

// Query for series within a study
let series = try await DICOMQueryService.findSeries(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    forStudy: studies[0].studyInstanceUID!,
    matching: QueryKeys(level: .series)
        .modality("CT")   // Filter by modality
        .requestSeriesDescription()
        .requestNumberOfSeriesRelatedInstances()
)

for seriesResult in series {
    print("Series: \(seriesResult.seriesNumber ?? 0) - \(seriesResult.modality ?? "N/A")")
    print("  Description: \(seriesResult.seriesDescription ?? "N/A")")
    print("  Instances: \(seriesResult.numberOfSeriesRelatedInstances ?? 0)")
}

// Query for instances within a series
let instances = try await DICOMQueryService.findInstances(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    forStudy: studies[0].studyInstanceUID!,
    forSeries: series[0].seriesInstanceUID!
)

for instance in instances {
    print("Instance: \(instance.instanceNumber ?? 0)")
    print("  SOP Class: \(instance.sopClassUID ?? "N/A")")
    if let rows = instance.rows, let cols = instance.columns {
        print("  Dimensions: \(cols)x\(rows)")
    }
}
```

### DICOM Retrieve Service - C-MOVE (v0.6)

C-MOVE requests the PACS to send images to a destination AE Title. This requires a separate Storage SCP (Service Class Provider) running at the destination to receive the images.

```swift
import DICOMNetwork
import Foundation

// Move a study to a destination AE
// Note: MY_STORAGE_SCP must be a registered AE Title in the PACS
// and point to a running Storage SCP that can receive images
let result = try await DICOMRetrieveService.moveStudy(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    moveDestination: "MY_STORAGE_SCP",
    onProgress: { progress in
        print("Progress: \(progress.completed)/\(progress.total) - \(progress.failed) failed")
    }
)

print("Move completed: \(result.isSuccess)")
print("Total transferred: \(result.progress.completed)")
if result.hasPartialFailures {
    print("Some images failed: \(result.progress.failed)")
}

// Move a series
let seriesResult = try await DICOMRetrieveService.moveSeries(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
    moveDestination: "MY_STORAGE_SCP"
)

// Move a single instance
let instanceResult = try await DICOMRetrieveService.moveInstance(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
    sopInstanceUID: "1.2.3.4.5.6.7.8.9.10.11",
    moveDestination: "MY_STORAGE_SCP"
)
```

### DICOM Retrieve Service - C-GET (v0.6)

C-GET downloads images directly on the same association, eliminating the need for a separate Storage SCP. This is simpler to use for client applications.

```swift
import DICOMNetwork
import Foundation

// Download a study directly using C-GET (no separate SCP needed)
let studyStream = try await DICOMRetrieveService.getStudy(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9"
)

// Process the async stream of events
for await event in studyStream {
    switch event {
    case .progress(let progress):
        print("Progress: \(progress.completed)/\(progress.total)")
    case .instance(let sopInstanceUID, let sopClassUID, let data):
        print("Received instance: \(sopInstanceUID)")
        print("  SOP Class: \(sopClassUID)")
        print("  Data size: \(data.count) bytes")
        // Save or process the DICOM data
    case .completed(let result):
        print("Download completed: \(result.isSuccess)")
        print("Total downloaded: \(result.progress.completed)")
    case .error(let error):
        print("Error: \(error)")
    }
}

// Download a series using C-GET
let seriesStream = try await DICOMRetrieveService.getSeries(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10"
)

// Process events using the same pattern as above
for await event in seriesStream {
    switch event {
    case .progress(let progress): print("Series progress: \(progress.completed)/\(progress.total)")
    case .instance(_, _, let data): print("Received \(data.count) bytes")
    case .completed(let result): print("Series download: \(result.isSuccess ? "success" : "failed")")
    case .error(let error): print("Error: \(error)")
    }
}

// Download a single instance using C-GET
let instanceStream = try await DICOMRetrieveService.getInstance(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    studyInstanceUID: "1.2.3.4.5.6.7.8.9",
    seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
    sopInstanceUID: "1.2.3.4.5.6.7.8.9.10.11"
)

// Process events using the same pattern
for await event in instanceStream {
    switch event {
    case .instance(_, _, let data):
        // Single instance downloaded
        print("Instance data: \(data.count) bytes")
    case .completed(let result):
        print("Instance download: \(result.isSuccess ? "success" : "failed")")
    default:
        break
    }
}
```

### DICOM Storage Service - C-STORE (v0.7)

C-STORE enables sending DICOM files to remote storage destinations like PACS systems.

```swift
import DICOMNetwork
import Foundation

// Store a complete DICOM file
let fileData = try Data(contentsOf: dicomFileURL)
let result = try await DICOMStorageService.store(
    fileData: fileData,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS"
)

if result.success {
    print("Stored successfully: \(result.affectedSOPInstanceUID)")
    print("Round-trip time: \(result.roundTripTime)s")
} else {
    print("Store failed: \(result.status)")
}

// Store with priority
let urgentResult = try await DICOMStorageService.store(
    fileData: fileData,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    priority: .high
)

// Store a raw data set (without file meta information)
let dataSetResult = try await DICOMStorageService.store(
    dataSetData: dataSetBytes,
    sopClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
    sopInstanceUID: "1.2.3.4.5.6.7.8.9",
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS"
)
```

### DICOM Storage SCP - Receiving Files (v0.7.3)

Storage SCP enables receiving DICOM files from remote sources like modalities and workstations.

```swift
import DICOMNetwork
import Foundation

// Create SCP configuration
let config = StorageSCPConfiguration(
    aeTitle: try AETitle("MY_SCP"),
    port: 11112,
    maxConcurrentAssociations: 10
)

// Create a custom storage handler
class MyStorageHandler: StorageDelegate {
    func shouldAcceptAssociation(from info: AssociationInfo) async -> Bool {
        // Accept only from known AE titles
        return ["MODALITY1", "WORKSTATION"].contains(info.callingAETitle)
    }
    
    func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool {
        // Accept all instances
        return true
    }
    
    func didReceive(file: ReceivedFile) async throws {
        print("Received: \(file.sopInstanceUID)")
        print("  From: \(file.callingAETitle)")
        print("  Size: \(file.dataSize) bytes")
        
        // Save to disk
        let url = URL(fileURLWithPath: "/data/dicom/\(file.sopInstanceUID).dcm")
        try file.dataSetData.write(to: url)
    }
    
    func didFail(error: Error, for sopInstanceUID: String?) async {
        print("Failed to receive: \(error)")
    }
}

// Create and start server
let handler = MyStorageHandler()
let server = DICOMStorageServer(configuration: config, delegate: handler)
try await server.start()

// Monitor server events
for await event in server.events {
    switch event {
    case .started(let port):
        print("Server started on port \(port)")
    case .associationEstablished(let info):
        print("Connection from: \(info.callingAETitle)")
    case .fileReceived(let file):
        print("Received file: \(file.sopInstanceUID)")
    case .associationReleased(let ae):
        print("Connection closed: \(ae)")
    case .error(let error):
        print("Error: \(error)")
    default:
        break
    }
}

// Stop server
await server.stop()

// Or use the default file storage handler
let defaultHandler = DefaultStorageHandler(
    storageDirectory: URL(fileURLWithPath: "/data/dicom")
)
let simpleServer = DICOMStorageServer(configuration: config, delegate: defaultHandler)
try await simpleServer.start()
```

### DICOM Batch Storage Service (v0.7.2)

Batch storage enables efficient transfer of multiple DICOM files over a single association.

```swift
import DICOMNetwork
import Foundation

// Load multiple DICOM files
let files = [
    try Data(contentsOf: file1URL),
    try Data(contentsOf: file2URL),
    try Data(contentsOf: file3URL)
]

// Store batch with progress monitoring
let stream = try await DICOMStorageService.storeBatch(
    files: files,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS"
)

for try await event in stream {
    switch event {
    case .progress(let progress):
        print("Progress: \(progress.succeeded)/\(progress.total)")
        print("Fraction complete: \(Int(progress.fractionComplete * 100))%")
    case .fileResult(let result):
        if result.success {
            print("File \(result.index): stored \(result.sopInstanceUID)")
        } else {
            print("File \(result.index): FAILED - \(result.errorMessage ?? "")")
        }
    case .completed(let result):
        print("Batch complete!")
        print("  Succeeded: \(result.progress.succeeded)")
        print("  Failed: \(result.progress.failed)")
        print("  Warnings: \(result.progress.warnings)")
        print("  Transfer rate: \(Int(result.averageTransferRate)) bytes/s")
    case .error(let error):
        print("Error: \(error)")
    }
}

// Configure batch behavior
let config = BatchStorageConfiguration(
    continueOnError: true,       // Continue after failures
    maxFilesPerAssociation: 100, // Limit files per association
    delayBetweenFiles: 0.1       // Rate limiting (100ms delay)
)

let configuredStream = try await DICOMStorageService.storeBatch(
    files: files,
    to: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    configuration: config
)

// Use fail-fast mode to stop on first error
let failFastConfig = BatchStorageConfiguration.failFast
```

### DICOM Print Management (v1.4.0-v1.4.5)

DICOMKit provides complete DICOM Print Management Service Class support (PS3.4 Annex H) for printing medical images to DICOM-compliant film printers and hard copy devices.

#### Simple Single Image Printing

```swift
import DICOMNetwork

// Configure printer connection
let config = PrintConfiguration(
    host: "192.168.1.100",
    port: 11112,
    callingAETitle: "WORKSTATION",
    calledAETitle: "PRINT_SCP"
)

// Print with default settings
let result = try await DICOMPrintService.printImage(
    configuration: config,
    imageData: pixelData.data,
    options: .default
)

// Print with high quality preset
let result = try await DICOMPrintService.printImage(
    configuration: config,
    imageData: pixelData.data,
    options: .highQuality  // 14×17", clear film, high magnification
)

// Print with custom options
let customOptions = PrintOptions(
    filmSize: .size11InX14In,
    filmOrientation: .landscape,
    mediumType: .blueFilm,
    numberOfCopies: 2,
    priority: .high
)
```

#### Multi-Image Printing with Automatic Layout

```swift
// Print multiple images - layout selected automatically
let result = try await DICOMPrintService.printImages(
    configuration: config,
    images: [image1, image2, image3, image4],  // 2×2 grid
    options: PrintOptions(
        filmSize: .size14InX17In,
        filmOrientation: .landscape
    )
)
```

#### Template-Based Printing

```swift
// Side-by-side comparison
let comparison = ComparisonTemplate()
try await DICOMPrintService.printWithTemplate(
    configuration: config,
    images: [beforeImage, afterImage],
    template: comparison
)

// 3×3 grid
let grid = GridTemplate(rows: 3, columns: 3)
try await DICOMPrintService.printWithTemplate(
    configuration: config,
    images: arrayOf9Images,
    template: grid
)

// Multi-phase temporal series (3×4)
let multiPhase = MultiPhaseTemplate(rows: 3, columns: 4)
try await DICOMPrintService.printWithTemplate(
    configuration: config,
    images: temporalSeries,
    template: multiPhase
)
```

#### Progress Tracking

```swift
// Monitor print progress in real-time
for try await progress in DICOMPrintService.printImagesWithProgress(
    configuration: config,
    images: images,
    options: .default
) {
    print("\(progress.phase): \(Int(progress.progress * 100))%")
    
    switch progress.phase {
    case .connecting: print("Connecting to printer...")
    case .preparingImages: print("Preparing images...")
    case .uploadingImages: print("Uploading: \(progress.current)/\(progress.total)")
    case .printing: print("Printing...")
    case .completed: print("Print completed!")
    default: break
    }
}
```

#### Print Queue Management

```swift
// Create print queue with retry policy
let queue = PrintQueue(
    maxHistorySize: 100,
    retryPolicy: PrintRetryPolicy(
        maxRetries: 3,
        initialDelay: 2.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )
)

// Add print job with priority
let job = PrintJob(
    configuration: config,
    imageURLs: imageURLs,
    options: .highQuality,
    priority: .high,
    label: "Urgent CT Print"
)
let jobID = await queue.enqueue(job: job)

// Check job status
if let status = await queue.status(jobID: jobID) {
    switch status {
    case .queued(let position): print("Queued at position \(position)")
    case .processing: print("Processing...")
    case .completed: print("Completed!")
    case .failed(let message): print("Failed: \(message)")
    case .cancelled: print("Cancelled")
    }
}
```

#### Multiple Printer Management

```swift
// Create printer registry
let registry = PrinterRegistry()

// Add printers with capabilities
let radiologyPrinter = PrinterInfo(
    name: "Radiology Film Printer",
    configuration: PrintConfiguration(...),
    capabilities: PrinterCapabilities(
        supportedFilmSizes: [.size14InX17In, .size11InX14In],
        supportsColor: false,
        maxCopies: 99,
        supportedMediumTypes: [.clearFilm, .blueFilm]
    ),
    isDefault: true
)
try await registry.addPrinter(radiologyPrinter)

// Select best printer for a job
if let printer = await registry.selectPrinter(
    requiresColor: false,
    filmSize: .size14InX17In
) {
    print("Using: \(printer.name)")
}
```

#### Image Preparation Pipeline

```swift
// Prepare images for optimal print quality
let preprocessor = ImagePreprocessor()
let preparedImage = try await preprocessor.prepareForPrint(
    dataSet: dicomDataSet,
    targetSize: CGSize(width: 1024, height: 1024),
    colorMode: .grayscale
)

// Add annotations
let annotator = AnnotationRenderer()
let annotatedData = try await annotator.addAnnotations(
    to: preparedImage.pixelData,
    imageSize: CGSize(width: 1024, height: 1024),
    annotations: [
        PrintAnnotation(text: "L", position: .topLeft, fontSize: 24, color: .white),
        PrintAnnotation(text: "Patient: John Doe", position: .bottomLeft, fontSize: 16, color: .white)
    ]
)
```

**Print Management Resources:**
- 📖 [Print Management Guide](Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md) - Complete API reference
- 📚 [Getting Started with Printing](Documentation/GettingStartedWithPrinting.md) - Beginner-friendly tutorial
- 🔧 [Print Best Practices](Documentation/PrintWorkflowBestPractices.md) - Production patterns
- 🐛 [Troubleshooting Print Issues](Documentation/TroubleshootingPrint.md) - Common problems and solutions
- 🖥️ [Print Server Setup](Documentation/PrintServerSetup.md) - Docker Compose test environment setup
- 📱 [iOS Integration Example](Examples/PrintIntegrationIOS.md) - Complete iOS SwiftUI example
- 💻 [macOS Integration Example](Examples/PrintIntegrationMacOS.md) - Complete macOS example
- 🔧 CLI Tool: `dicom-print` - Command-line print operations

### DICOM Client - Unified High-Level API (v0.6.7)

The `DICOMClient` provides a simplified, unified interface for all DICOM networking operations with built-in retry support.

```swift
import DICOMNetwork
import Foundation

// Create a client with retry policy
let client = try DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    timeout: 30,
    retryPolicy: .exponentialBackoff(maxRetries: 3)
)

// Test connectivity
let connected = try await client.verify()
print("Connected: \(connected)")

// Query for studies
let studies = try await client.findStudies(
    matching: QueryKeys(level: .study)
        .patientName("DOE^JOHN*")
        .studyDate("20240101-20241231")
)

// Query for series
let series = try await client.findSeries(
    forStudy: studies[0].studyInstanceUID!,
    matching: QueryKeys(level: .series).modality("CT")
)

// Download a study using C-GET
for await event in try await client.getStudy(studyInstanceUID: studies[0].studyInstanceUID!) {
    switch event {
    case .progress(let progress):
        print("Progress: \(progress.completed)/\(progress.total)")
    case .instance(_, _, let data):
        print("Received \(data.count) bytes")
    case .completed(let result):
        print("Download complete: \(result.progress.completed) instances")
    case .error(let error):
        print("Error: \(error)")
    }
}

// Or use C-MOVE to send to another destination
let result = try await client.moveStudy(
    studyInstanceUID: studies[0].studyInstanceUID!,
    moveDestination: "MY_STORAGE_SCP"
) { progress in
    print("Move progress: \(progress.completed)/\(progress.total)")
}
print("Move result: \(result.isSuccess)")

// Store a DICOM file using C-STORE (NEW in v0.7)
let fileData = try Data(contentsOf: dicomFileURL)
let storeResult = try await client.store(fileData: fileData)
print("Store result: \(storeResult.success ? "success" : "failed")")

// Store multiple files in batch (NEW in v0.7.2)
let files = [fileData1, fileData2, fileData3]
let batchStream = try await client.storeBatch(files: files)

for try await event in batchStream {
    switch event {
    case .progress(let progress):
        print("Batch progress: \(progress.succeeded)/\(progress.total)")
    case .fileResult(let result):
        print("File \(result.index): \(result.success ? "OK" : "FAILED")")
    case .completed(let result):
        print("Batch complete: \(result.progress.succeeded) succeeded")
    case .error(let error):
        print("Error: \(error)")
    }
}
```

#### Retry Policies

Configure how network operations are retried on transient failures:

```swift
// No retries (default)
let noRetry = RetryPolicy.none

// Fixed delay between retries
let fixedRetry = RetryPolicy.fixed(maxRetries: 3, delay: 1.0)

// Exponential backoff (recommended for production)
let exponentialRetry = RetryPolicy.exponentialBackoff(
    maxRetries: 5,
    initialDelay: 0.5,
    maxDelay: 30.0,
    multiplier: 2.0
)
```

### TLS/Secure Connections (v0.7.4)

DICOMKit supports secure DICOM connections using TLS 1.2/1.3 encryption.

```swift
import DICOMNetwork

// Default TLS configuration (TLS 1.2+, system trust store)
let secureClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,  // DICOM TLS port
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: .default
)

// Strict mode: TLS 1.3 only
let strictClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: .strict
)

// Development mode with self-signed certificates (INSECURE)
let devClient = try DICOMClient(
    host: "dev-pacs.local",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: .insecure  // Only for development!
)

// Certificate pinning for enhanced security
let certData = try Data(contentsOf: serverCertURL)
let pinnedCert = try TLSConfiguration.certificate(fromPEM: certData)
let pinnedConfig = TLSConfiguration(certificateValidation: .pinned([pinnedCert]))

let pinnedClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: pinnedConfig
)

// Mutual TLS (mTLS) with client certificate
let clientIdentity = ClientIdentity(
    pkcs12Data: try Data(contentsOf: clientCertURL),
    password: "certificate-password"
)
let mtlsConfig = TLSConfiguration(
    minimumVersion: .tlsProtocol12,
    certificateValidation: .system,
    clientIdentity: clientIdentity
)

let mtlsClient = try DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 2762,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    tlsConfiguration: mtlsConfig
)

// Use secure client for any DICOM operation
let connected = try await secureClient.verify()
let studies = try await secureClient.findStudies(
    matching: QueryKeys(level: .study).patientName("DOE^JOHN*")
)
```

### Network Error Handling (v0.7.5)

DICOMKit provides comprehensive error handling with categorization, recovery suggestions, and fine-grained timeout configuration.

```swift
import DICOMNetwork

// Configure timeouts for different network conditions
let client = try DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    timeoutConfiguration: .default  // or .fast, .slow
)

// Custom timeout configuration
let customTimeouts = TimeoutConfiguration(
    connect: 10,      // 10s to establish connection
    read: 30,         // 30s for read operations
    write: 30,        // 30s for write operations
    operation: 120,   // 120s for entire operation
    association: 30   // 30s for association establishment
)

let customClient = try DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAE: "MY_SCU",
    calledAE: "PACS",
    timeoutConfiguration: customTimeouts
)

// Handle errors with categorization and recovery suggestions
do {
    let connected = try await client.verify()
} catch let error as DICOMNetworkError {
    // Check error category
    switch error.category {
    case .transient:
        print("Temporary failure - retry may succeed")
    case .permanent:
        print("Permanent failure - intervention required")
    case .configuration:
        print("Configuration error - check settings")
    case .protocol:
        print("Protocol error - check compatibility")
    case .timeout:
        print("Timeout - increase timeout or check network")
    case .resource:
        print("Resource error - wait and retry")
    }
    
    // Check if retryable
    if error.isRetryable {
        print("This error can be retried")
    }
    
    // Get recovery suggestion
    print("Suggestion: \(error.recoverySuggestion)")
    
    // Get detailed explanation
    print("Explanation: \(error.explanation)")
}

// Preset timeout configurations
let fastTimeouts = TimeoutConfiguration.fast    // For local networks
let slowTimeouts = TimeoutConfiguration.slow    // For WAN connections
let defaultTimeouts = TimeoutConfiguration.default  // Balanced defaults
```

### DICOM Validation (v0.7.6)

DICOMKit provides comprehensive validation of DICOM data sets before sending to ensure data integrity and compliance.

```swift
import DICOMNetwork
import DICOMCore

// Create a validator
let validator = DICOMValidator()

// Validate a data set with default (standard) configuration
// Using closures for DataSet access
let result = validator.validate(
    getString: { tag in dataSet.string(for: tag) },
    getData: { tag in dataSet[tag]?.valueData },
    configuration: .default
)

if result.isValid {
    print("Validation passed")
    if result.hasWarnings {
        for warning in result.warnings {
            print("Warning: \(warning)")
        }
    }
} else {
    for error in result.errors {
        print("Validation error: \(error)")
    }
}

// Validate with strict configuration for production
let strictResult = validator.validate(
    getString: { tag in dataSet.string(for: tag) },
    getData: { tag in dataSet[tag]?.valueData },
    configuration: .strict
)

// Custom validation configuration
let customConfig = ValidationConfiguration(
    level: .standard,
    validateTransferSyntax: true,
    validatePixelData: true,
    treatWarningsAsErrors: false,
    allowedSOPClasses: [
        "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        "1.2.840.10008.5.1.4.1.1.4"   // MR Image Storage
    ],
    additionalRequiredTags: [.patientWeight, .patientSize]
)

let customResult = validator.validate(
    getString: { tag in dataSet.string(for: tag) },
    getData: { tag in dataSet[tag]?.valueData },
    configuration: customConfig
)

// Validate UIDs directly
if !validator.isValidUID("1.2.840.10008.5.1.4.1.1.2") {
    print("Invalid UID format")
}
```

### Audit Logging (v0.7.5)

DICOMKit provides comprehensive audit logging for healthcare compliance (IHE ATNA).

```swift
import DICOMNetwork

// Configure audit logging at app startup
let auditLogger = AuditLogger.shared

// Add a file handler for persistent logging
let fileHandler = try FileAuditLogHandler(
    directory: URL(fileURLWithPath: "/var/log/dicom"),
    baseName: "dicom_audit",
    maxFileSize: 50 * 1024 * 1024,  // 50 MB
    maxFiles: 10
)
await auditLogger.addHandler(fileHandler)

// Add console handler for debugging (optional)
await auditLogger.addHandler(ConsoleAuditLogHandler(verbose: true))

// Add OSLog handler for system integration (Apple platforms)
await auditLogger.addHandler(OSLogAuditHandler())

// Filter to specific event types (optional)
await auditLogger.setEnabledEventTypes([.storeSent, .storeReceived, .queryExecuted])

// Log a C-STORE send event
let source = AuditParticipant(
    aeTitle: "MY_SCU",
    host: "10.0.0.1",
    port: 11112,
    isRequestor: true,
    userIdentity: "technician"
)

let destination = AuditParticipant(
    aeTitle: "PACS_AE",
    host: "pacs.hospital.com",
    port: 11112,
    isRequestor: false
)

await auditLogger.logStoreSent(
    outcome: .success,
    source: source,
    destination: destination,
    sopClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
    sopInstanceUID: "1.2.3.4.5.6.7.8.9",
    studyInstanceUID: "1.2.3.4.5",
    patientID: "PATIENT123",
    bytesTransferred: 524288,
    duration: 1.5,
    statusCode: 0x0000
)

// Log query operations
await auditLogger.logQueryExecuted(
    outcome: .success,
    source: source,
    destination: destination,
    queryLevel: "STUDY",
    resultCount: 42,
    duration: 0.5
)

// Log security events
await auditLogger.logSecurityEvent(
    outcome: .majorFailure,
    source: AuditParticipant(
        aeTitle: "UNKNOWN",
        host: "192.168.1.99",
        port: 11112,
        isRequestor: true
    ),
    description: "Authentication failed: invalid credentials"
)
```

### DICOMweb Client (v0.8.2)

DICOMKit provides a modern RESTful DICOMweb client for retrieving DICOM objects over HTTP/HTTPS.

```swift
import DICOMWeb

// Configure the DICOMweb client
let config = try DICOMwebConfiguration(
    baseURLString: "https://pacs.example.com/dicom-web",
    authentication: .bearer(token: "your-oauth-token")
)
let client = DICOMwebClient(configuration: config)

// Retrieve all instances in a study
let result = try await client.retrieveStudy(studyUID: "1.2.3.4.5.6789")
print("Retrieved \(result.instances.count) instances")

// Retrieve as a stream for large studies
for try await instanceData in client.retrieveStudyStream(studyUID: "1.2.3.4.5.6789") {
    // Process each instance as it arrives
    print("Received instance: \(instanceData.count) bytes")
}

// Retrieve a specific instance
let instanceData = try await client.retrieveInstance(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    instanceUID: "1.2.3.4.5.6789.1.1"
)

// Retrieve metadata (DICOM JSON)
let metadata = try await client.retrieveStudyMetadata(studyUID: "1.2.3.4.5.6789")
for instance in metadata {
    if let patientName = instance["00100010"] as? [String: Any],
       let value = patientName["Value"] as? [[String: String]],
       let alphabetic = value.first?["Alphabetic"] {
        print("Patient: \(alphabetic)")
    }
}

// Retrieve specific frames from a multi-frame image
let frames = try await client.retrieveFrames(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    instanceUID: "1.2.3.4.5.6789.1.1",
    frames: [1, 5, 10]
)

// Retrieve a rendered image (JPEG) with windowing
let imageData = try await client.retrieveRenderedInstance(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    instanceUID: "1.2.3.4.5.6789.1.1",
    options: DICOMwebClient.RenderOptions(
        windowCenter: 40,
        windowWidth: 400,
        viewportWidth: 512,
        viewportHeight: 512,
        quality: 85,
        format: .jpeg
    )
)

// Retrieve a thumbnail
let thumbnailData = try await client.retrieveStudyThumbnail(
    studyUID: "1.2.3.4.5.6789",
    options: .thumbnail(size: 128)
)

// Retrieve bulk data from a metadata response
if let bulkDataURI = "https://pacs.example.com/dicom-web/studies/.../bulkdata/7FE00010" {
    let pixelData = try await client.retrieveBulkData(uri: bulkDataURI)
}
```

### DICOMweb QIDO-RS Query Client (v0.8.3)

DICOMKit provides a powerful QIDO-RS client for searching DICOM objects with a fluent query builder API.

```swift
import DICOMWeb

// Configure the DICOMweb client
let config = try DICOMwebConfiguration(
    baseURLString: "https://pacs.example.com/dicom-web",
    authentication: .bearer(token: "your-oauth-token")
)
let client = DICOMwebClient(configuration: config)

// Search for studies by patient name with wildcard
let query = QIDOQuery()
    .patientName("Smith*")
    .modality("CT")
    .studyDate(from: "20240101", to: "20241231")
    .limit(10)

let results = try await client.searchStudies(query: query)
print("Found \(results.count) studies")

// Iterate over results with type-safe accessors
for study in results.results {
    print("Study UID: \(study.studyInstanceUID ?? "unknown")")
    print("Patient: \(study.patientName ?? "unknown")")
    print("Date: \(study.studyDate ?? "unknown")")
    print("Description: \(study.studyDescription ?? "N/A")")
}

// Handle pagination
if results.hasMore, let nextOffset = results.nextOffset {
    let nextPage = try await client.searchStudies(
        query: query.offset(nextOffset)
    )
    // Process next page...
}

// Search for series within a study
let seriesResults = try await client.searchSeries(
    studyUID: "1.2.3.4.5.6789",
    query: QIDOQuery().modality("CT")
)

for series in seriesResults.results {
    print("Series: \(series.seriesInstanceUID ?? "unknown")")
    print("Modality: \(series.modality ?? "unknown")")
    print("Description: \(series.seriesDescription ?? "N/A")")
}

// Search for instances
let instanceResults = try await client.searchInstances(
    studyUID: "1.2.3.4.5.6789",
    seriesUID: "1.2.3.4.5.6789.1",
    query: QIDOQuery().limit(100)
)

for instance in instanceResults.results {
    print("Instance: \(instance.sopInstanceUID ?? "unknown")")
    print("Instance #: \(instance.instanceNumber ?? 0)")
}

// Convenience factory methods
let recentCTStudies = try await client.searchStudies(
    query: .studiesByModality("CT", limit: 20)
)

let patientStudies = try await client.searchStudies(
    query: .studiesByPatientName("Doe^John")
)

// Use include fields to request specific attributes
let detailedQuery = QIDOQuery()
    .patientID("12345")
    .includeFields([
        QIDOQueryAttribute.numberOfStudyRelatedSeries,
        QIDOQueryAttribute.numberOfStudyRelatedInstances
    ])

// Enable fuzzy matching for approximate patient name search
let fuzzyQuery = QIDOQuery()
    .patientName("Smyth")
    .fuzzyMatching()
```

### DICOMweb Server TLS Configuration (v0.8.8)

DICOMKit provides comprehensive TLS configuration for secure DICOMweb server deployment.

```swift
import DICOMWeb

// Basic HTTPS server configuration
let tlsConfig = DICOMwebServerConfiguration.TLSConfiguration(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)

let serverConfig = DICOMwebServerConfiguration(
    port: 443,
    host: "0.0.0.0",
    pathPrefix: "/dicom-web",
    tlsConfiguration: tlsConfig
)

// TLS 1.3 strict mode (highest security)
let strictTLS = DICOMwebServerConfiguration.TLSConfiguration.strict(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)

// Compatible mode (TLS 1.2+, works with older clients)
let compatibleTLS = DICOMwebServerConfiguration.TLSConfiguration.compatible(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)

// Mutual TLS (mTLS) - requires client certificates
let mtlsConfig = DICOMwebServerConfiguration.TLSConfiguration.mutualTLS(
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key",
    clientCACertificatePath: "/path/to/ca.pem"
)

// Development mode (for testing with self-signed certs)
// WARNING: Never use in production!
let devTLS = DICOMwebServerConfiguration.TLSConfiguration.development(
    certificatePath: "/path/to/dev-cert.pem",
    privateKeyPath: "/path/to/dev-key.pem"
)

// Validate configuration before use
do {
    try tlsConfig.validate()
    print("TLS configuration is valid")
} catch let error as DICOMwebServerConfiguration.TLSConfigurationError {
    print("TLS configuration error: \(error.description)")
}

// Production preset with TLS and rate limiting
let productionConfig = DICOMwebServerConfiguration.production(
    port: 443,
    certificatePath: "/path/to/server.pem",
    privateKeyPath: "/path/to/server.key"
)
```

### Conformance Statement Generation (v0.8.8)

DICOMKit can automatically generate DICOM conformance statements documenting your server's capabilities.

```swift
import DICOMWeb

// Generate from server configuration and capabilities
let serverConfig = DICOMwebServerConfiguration.development
let capabilities = DICOMwebCapabilities.dicomKitServer

let statement = ConformanceStatementGenerator.generate(
    from: serverConfig,
    capabilities: capabilities
)

// Or with custom implementation info
let customImplementation = ConformanceStatement.Implementation(
    name: "MyPACS",
    version: "2.0.0",
    vendor: "My Healthcare Company",
    description: "Enterprise PACS Solution"
)

let customStatement = ConformanceStatementGenerator.generate(
    from: serverConfig,
    capabilities: capabilities,
    implementation: customImplementation
)

// Export as JSON (PS3.2 format)
let jsonData = try statement.toJSON()

// Export as human-readable text document
let textDocument = statement.toText()
print(textDocument)

// Access individual conformance details
if let wado = statement.networkServices.dicomWeb.wadoRS {
    print("WADO-RS: \(wado.supported ? "Enabled" : "Disabled")")
    print("Transfer Syntaxes: \(wado.transferSyntaxes.count)")
}

if let qido = statement.networkServices.dicomWeb.qidoRS {
    print("Query Levels: \(qido.queryLevels.joined(separator: ", "))")
}

// Check security information
print("TLS Required: \(statement.security.tlsSupport.required)")
print("Auth Methods: \(statement.security.authenticationMethods.joined(separator: ", "))")
```

### SR Document Creation (v0.9.6)

DICOMKit provides a fluent builder API for creating DICOM Structured Reporting documents programmatically.

```swift
import DICOMKit
import DICOMCore

// Create an SR document with the builder API
let document = try SRDocumentBuilder(documentType: .comprehensiveSR)
    // Document identification
    .withPatientID("PAT001")
    .withPatientName("Doe^John")
    .withStudyDate("20240115")
    .withStudyTime("143022")
    
    // Document title and status
    .withDocumentTitle(CodedConcept(
        codeValue: "126001",
        codingSchemeDesignator: "DCM",
        codeMeaning: "Imaging Report"
    ))
    .withCompletionFlag(.complete)
    .withVerificationFlag(.verified)
    
    // Add text findings
    .addText(
        conceptName: CodedConcept.finding,
        value: "Normal liver parenchyma with no focal lesions."
    )
    
    // Add numeric measurements
    .addNumeric(
        conceptName: CodedConcept.measurement,
        value: 15.5,
        units: CodedConcept.unitCentimeter
    )
    
    // Add coded findings
    .addCode(
        conceptName: CodedConcept.finding,
        value: CodedConcept(
            codeValue: "17621005",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Normal"
        )
    )
    
    // Add image references
    .addImageReference(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        sopInstanceUID: "1.2.3.4.5.6.7.8.9",
        frameNumbers: [1]
    )
    
    // Add spatial coordinates (ROI markup)
    .addSpatialCoordinates(
        graphicType: .polygon,
        graphicData: [100.0, 100.0, 200.0, 100.0, 200.0, 200.0, 100.0, 200.0]
    )
    
    // Add nested containers for organized structure
    .addContainer(
        conceptName: CodedConcept(
            codeValue: "121070",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Findings"
        ),
        items: [
            .text(value: "No pleural effusion"),
            .text(value: "Heart size is normal"),
            .numeric(value: 12.5, units: CodedConcept.unitMillimeter)
        ]
    )
    .build()

// Serialize to DICOM DataSet for storage
let dataSet = try document.toDataSet()
print("Created SR with \(document.contentItemCount) content items")

// Round-trip: serialize and parse back
let parser = SRDocumentParser()
let parsedDocument = try parser.parse(dataSet: dataSet)
print("Parsed document: \(parsedDocument.documentType?.displayName ?? "Unknown")")

// Access content from the created document
for textItem in document.findTextItems() {
    print("Finding: \(textItem.textValue)")
}

for numericItem in document.findNumericItems() {
    if let value = numericItem.value, let units = numericItem.measurementUnits {
        print("Measurement: \(value) \(units.codeMeaning)")
    }
}
```

#### Using ContainerBuilder for Declarative Construction

```swift
import DICOMKit
import DICOMCore

// Use result builder syntax for complex document structure
let document = try SRDocumentBuilder(documentType: .enhancedSR)
    .withDocumentTitle(CodedConcept(
        codeValue: "18782-3",
        codingSchemeDesignator: "LN",
        codeMeaning: "Radiology Study Observation"
    ))
    .addContainer(conceptName: LOINCCode.findings.concept) {
        AnyContentItem(TextContentItem(
            conceptName: CodedConcept.finding,
            textValue: "Lungs are clear bilaterally"
        ))
        AnyContentItem(TextContentItem(
            conceptName: CodedConcept.finding,
            textValue: "No cardiomegaly"
        ))
        AnyContentItem(CodeContentItem(
            conceptName: CodedConcept.finding,
            conceptCode: SNOMEDCode.normal.concept
        ))
    }
    .addContainer(conceptName: LOINCCode.impression.concept) {
        AnyContentItem(TextContentItem(
            textValue: "Normal chest radiograph"
        ))
    }
    .build()

print("Document: \(document.description)")
```

#### Using BasicTextSRBuilder for Simple Text Reports (NEW in v0.9.8)

```swift
import DICOMKit
import DICOMCore

// BasicTextSRBuilder provides a simplified API for text-based reports
let document = try BasicTextSRBuilder()
    // Patient and study information
    .withPatientID("PAT12345")
    .withPatientName("Doe^John")
    .withStudyDate("20240115")
    .withAccessionNumber("ACC-2024-001")
    
    // Document title (string or coded concept)
    .withDocumentTitle("CT Chest Report")
    .withCompletionFlag(.complete)
    .withVerificationFlag(.verified)
    
    // Use built-in section helpers
    .addClinicalHistory("Chronic cough for 3 weeks. Rule out malignancy.")
    .addComparison("CT Chest from 2023-06-15")
    .addFindings("""
        The lungs are clear bilaterally without evidence of consolidation, \
        mass, or nodule. Heart size is normal. No pleural effusion.
        """)
    .addImpression("Normal CT chest examination.")
    .addRecommendation("No follow-up imaging required.")
    .build()

print("Created Basic Text SR: \(document.documentType?.displayName ?? "Unknown")")
print("Content items: \(document.contentItemCount)")

// Create sections with nested content using result builder
let detailedReport = try BasicTextSRBuilder()
    .withPatientID("PAT67890")
    .withDocumentTitle("Radiology Report")
    .addSection("Technique") {
        SectionContent.text("CT of the chest with contrast. 64-slice scanner.")
    }
    .addSection("Findings") {
        SectionContent.subsection(title: "Lungs", items: [
            SectionContent.text("Clear bilaterally"),
            SectionContent.text("No nodules or masses")
        ])
        SectionContent.subsection(title: "Heart", items: [
            SectionContent.text("Normal size and configuration"),
            SectionContent.text("No pericardial effusion")
        ])
        SectionContent.subsection(title: "Mediastinum", items: [
            SectionContent.text("No lymphadenopathy")
        ])
    }
    .addImpression("Normal chest CT examination")
    .build()

print("Detailed report sections: \(detailedReport.rootContent.contentItems.count)")
```

#### Using EnhancedSRBuilder for Reports with Measurements (NEW in v0.9.8)

```swift
import DICOMKit
import DICOMCore

// EnhancedSRBuilder adds numeric measurements to Basic Text SR capabilities
let measurementReport = try EnhancedSRBuilder()
    // Patient and study information
    .withPatientID("PAT12345")
    .withPatientName("Doe^John")
    .withStudyDate("20240115")
    .withAccessionNumber("ACC-2024-002")
    
    // Document title
    .withDocumentTitle("CT Measurement Report")
    .withCompletionFlag(.complete)
    .withVerificationFlag(.verified)
    
    // Clinical context
    .addClinicalHistory("Follow-up for known liver lesion")
    
    // Findings section with nested measurements
    .addSection("Findings") {
        EnhancedSectionContent.text("Hepatic lesion in segment 7")
        EnhancedSectionContent.subsection("Measurements", items: [
            EnhancedSectionContent.measurement(
                label: "Axial Diameter",
                value: 25.5,
                units: UCUMUnit.millimeter.concept
            ),
            EnhancedSectionContent.measurement(
                label: "Craniocaudal Length",
                value: 30.2,
                units: UCUMUnit.millimeter.concept
            )
        ])
    }
    
    // Add measurements using convenience methods
    .addMeasurements {
        EnhancedSectionContent.numeric(
            conceptName: CodedConcept.diameter,
            value: 25.5,
            units: UCUMUnit.millimeter.concept
        )
        EnhancedSectionContent.numeric(
            conceptName: CodedConcept.volume,
            value: 12.3,
            units: UCUMUnit.cubicCentimeter.concept
        )
    }
    
    .addImpression("Stable hepatic lesion compared to prior")
    .addRecommendation("Follow-up CT in 6 months")
    .build()

print("Created Enhanced SR: \(measurementReport.documentType?.displayName ?? "Unknown")")
print("SOP Class UID: \(measurementReport.sopClassUID)")

// Add individual measurements at root level
let simpleReport = try EnhancedSRBuilder()
    .withDocumentTitle("Quick Measurement")
    .addMeasurementMM(label: "Tumor Diameter", value: 15.0)  // Helper for mm
    .addMeasurementCM(label: "Lesion Length", value: 3.5)    // Helper for cm
    .addNumeric(
        conceptName: CodedConcept.area,
        value: 450.0,
        units: UCUMUnit.squareMillimeter.concept
    )
    .build()

print("Simple report measurements: \(simpleReport.rootContent.contentItems.count)")
```

#### Using ComprehensiveSRBuilder for Reports with Spatial Coordinates (NEW in v0.9.8)

`ComprehensiveSRBuilder` adds support for 2D spatial coordinates (SCOORD) and temporal coordinates (TCOORD) to Enhanced SR capabilities. This is ideal for measurement reports that need to annotate specific regions on images.

```swift
import DICOMKit
import DICOMCore

// ComprehensiveSRBuilder adds spatial and temporal coordinates
let coordinateReport = try ComprehensiveSRBuilder()
    .withPatientID("PAT789")
    .withPatientName("Wilson^Robert")
    .withStudyInstanceUID("1.2.3.4.5.6.7")
    .withDocumentTitle("Liver Lesion Measurement Report")
    .withCompletionFlag(.complete)
    .withVerificationFlag(.verified)
    
    // Clinical context
    .addClinicalHistory("Follow-up for previously identified hepatic lesion")
    
    // Findings with spatial coordinates
    .addSection("Findings") {
        ComprehensiveSectionContent.text("Hepatic lesion identified in segment VII")
        
        // Numeric measurement
        ComprehensiveSectionContent.measurement(
            label: "Lesion Diameter",
            value: 25.0,
            units: UCUMUnit.millimeter.concept
        )
        
        // Circle annotation marking the lesion
        ComprehensiveSectionContent.circle(
            conceptName: CodedConcept.imageRegion,
            centerColumn: 256.0,
            centerRow: 256.0,
            edgeColumn: 276.0,  // 20 pixel radius
            edgeRow: 256.0
        )
    }
    
    // Measurements section with polygon ROI
    .addSection("ROI Measurements") {
        // Define a polygon region of interest
        ComprehensiveSectionContent.polygon(
            conceptName: CodedConcept.regionOfInterest,
            points: [
                (column: 100.0, row: 100.0),
                (column: 200.0, row: 100.0),
                (column: 200.0, row: 180.0),
                (column: 100.0, row: 180.0)
            ]
        )
        
        // Measurements derived from the ROI
        ComprehensiveSectionContent.numeric(
            conceptName: CodedConcept.area,
            value: 8000.0,
            units: UCUMUnit.squareMillimeter.concept
        )
    }
    
    .addImpression("Stable hepatic lesion, recommend follow-up in 6 months")
    .build()

print("Created Comprehensive SR: \(coordinateReport.documentType?.displayName ?? "Unknown")")
print("SOP Class UID: \(coordinateReport.sopClassUID)")

// Using spatial coordinate convenience methods
let annotatedReport = try ComprehensiveSRBuilder()
    .withDocumentTitle("Annotation Report")
    
    // Point annotation
    .addPoint(column: 150.0, row: 200.0)
    
    // Polyline (measurement line)
    .addPolyline(points: [
        (column: 100.0, row: 100.0),
        (column: 200.0, row: 200.0)
    ])
    
    // Circle annotation
    .addCircle(
        centerColumn: 256.0,
        centerRow: 256.0,
        edgeColumn: 280.0,
        edgeRow: 256.0
    )
    
    // Temporal coordinate (time point in waveform)
    .addTemporalCoordinates(
        temporalRangeType: .point,
        timeOffsets: [0.5, 1.0, 1.5]  // Time offsets in seconds
    )
    
    .build()

print("Annotations: \(annotatedReport.rootContent.contentItems.count)")
```

#### Using Comprehensive3DSRBuilder for 3D Measurement Reports (NEW in v0.9.8)

`Comprehensive3DSRBuilder` adds support for 3D spatial coordinates (SCOORD3D) to Comprehensive SR capabilities. This is essential for volumetric imaging modalities like CT, MRI, and PET where measurements and annotations are referenced in a common 3D coordinate system defined by a Frame of Reference UID.

```swift
import DICOMKit
import DICOMCore

// Comprehensive3DSRBuilder adds 3D spatial coordinates for volumetric measurements
let lesionReport = try Comprehensive3DSRBuilder()
    .withPatientID("PAT12345")
    .withPatientName("Doe^John")
    .withStudyInstanceUID("1.2.840.113619.2.1.1.1.1")
    .withDocumentTitle("3D Lesion Analysis")
    .withFrameOfReferenceUID("1.2.840.10008.5.1.4.1.1.88.34.1")
    
    .addSection("Findings") {
        Comprehensive3DSectionContent.text("Focal lesion identified in liver segment VII")
        
        Comprehensive3DSectionContent.measurement(
            label: "Maximum Diameter",
            value: 25.5,
            units: UCUMUnit.millimeter.concept
        )
        
        Comprehensive3DSectionContent.measurement(
            label: "Volume",
            value: 8654.3,
            units: UCUMUnit.cubicMillimeter.concept
        )
        
        // 3D ellipsoid annotation marking the lesion
        Comprehensive3DSectionContent.spatialCoordinates3D(
            conceptName: CodedConcept(
                codeValue: "111030",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Image Region"
            ),
            graphicType: .ellipsoid,
            graphicData: [
                100.0, 100.0, 50.0,  // First axis endpoint 1
                120.0, 100.0, 50.0,  // First axis endpoint 2
                110.0, 110.0, 50.0,  // Second axis endpoint 1
                110.0, 90.0, 50.0,   // Second axis endpoint 2
                110.0, 100.0, 60.0,  // Third axis endpoint 1
                110.0, 100.0, 40.0   // Third axis endpoint 2
            ],
            frameOfReferenceUID: "1.2.840.10008.5.1.4.1.1.88.34.1"
        )
    }
    
    .addImpression("Focal liver lesion compatible with hemangioma")
    .build()

print("Created Comprehensive 3D SR: \(lesionReport.documentType?.displayName ?? "Unknown")")

// Using 3D coordinate convenience methods and ROI helpers
let multiLesionReport = try Comprehensive3DSRBuilder()
    .withDocumentTitle("Multi-Lesion Analysis")
    .withFrameOfReferenceUID("1.2.840.10008.5.1.4.1.1.88.34.1")
    
    // 3D point marker
    .addPoint3D(
        conceptName: CodedConcept.imageRegion,
        x: 150.0,
        y: 200.0,
        z: 75.0
    )
    
    // 3D polyline (measurement line in 3D space)
    .addPolyline3D(points: [
        (x: 100.0, y: 100.0, z: 50.0),
        (x: 150.0, y: 150.0, z: 60.0),
        (x: 200.0, y: 200.0, z: 70.0)
    ])
    
    // 3D ROI with ellipsoid shape and volume measurement
    .add3DROI(
        label: "Lesion 1",
        ellipsoidAxes: (
            first: (
                point1: (x: 100.0, y: 100.0, z: 50.0),
                point2: (x: 120.0, y: 100.0, z: 50.0)
            ),
            second: (
                point1: (x: 110.0, y: 90.0, z: 50.0),
                point2: (x: 110.0, y: 110.0, z: 50.0)
            ),
            third: (
                point1: (x: 110.0, y: 100.0, z: 40.0),
                point2: (x: 110.0, y: 100.0, z: 60.0)
            )
        ),
        volume: 523.6
    )
    
    .add3DROI(
        label: "Lesion 2",
        ellipsoidAxes: (
            first: (
                point1: (x: 200.0, y: 200.0, z: 80.0),
                point2: (x: 215.0, y: 200.0, z: 80.0)
            ),
            second: (
                point1: (x: 207.5, y: 192.0, z: 80.0),
                point2: (x: 207.5, y: 208.0, z: 80.0)
            ),
            third: (
                point1: (x: 207.5, y: 200.0, z: 72.0),
                point2: (x: 207.5, y: 200.0, z: 88.0)
            )
        ),
        volume: 314.2
    )
    
    .build()

print("3D ROIs: \(multiLesionReport.rootContent.contentItems.count)")
```

#### Using KeyObjectSelectionBuilder for Flagging Key Images (NEW in v0.9.8)

`KeyObjectSelectionBuilder` provides a simple fluent API for creating DICOM Key Object Selection (KOS) documents, which are used to flag significant images for teaching, quality control, referral, or other purposes.

```swift
import DICOMKit
import DICOMCore

// Create a teaching file collection
let teachingFile = try KeyObjectSelectionBuilder()
    .withPatientID("PAT12345")
    .withPatientName("Teaching^Case^^^")
    .withStudyInstanceUID("1.2.840.10008.999.1")
    .withStudyDate("20240115")
    .withStudyDescription("CT Abdomen with Contrast")
    .withDocumentTitle(.forTeaching)
    .withCompletionFlag(.complete)
    .withVerificationFlag(.verified)
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2", // CT Image Storage
        sopInstanceUID: "1.2.840.10008.999.1.1.1",
        description: "Classic presentation of hepatic lesion"
    )
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
        sopInstanceUID: "1.2.840.10008.999.1.1.2",
        description: "Portal venous phase showing washout"
    )
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
        sopInstanceUID: "1.2.840.10008.999.1.1.3"
    )
    .build()

print("KOS Document: \(teachingFile.documentTitle?.codeMeaning ?? "")")
print("Key objects: \(teachingFile.rootContent.contentItems.count / 2)")

// Quality control - reject images with problems
let qualityReject = try KeyObjectSelectionBuilder()
    .withPatientID("QC001")
    .withStudyDate("20240116")
    .withDocumentTitle(.rejectedForQuality)
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.1", // CR Image Storage
        sopInstanceUID: "1.2.3.4.5.6",
        description: "Motion artifact - reject"
    )
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.1",
        sopInstanceUID: "1.2.3.4.5.7",
        description: "Incorrect positioning"
    )
    .build()

// Best images for referral
let referralImages = try KeyObjectSelectionBuilder()
    .withDocumentTitle(.forReferringProvider)
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.4", // MR Image Storage
        sopInstanceUID: "1.2.3.4.5.8"
    )
    .build()

// Custom purpose code
let customPurpose = try KeyObjectSelectionBuilder()
    .withDocumentTitle(CodedConcept(
        codeValue: "CUSTOM001",
        codingSchemeDesignator: "LOCAL",
        codeMeaning: "Images for Conference Presentation"
    ))
    .addKeyObject(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
        sopInstanceUID: "1.2.3.4.5.9",
        frames: [1, 3, 5] // Specific frames in multi-frame image
    )
    .build()
```

**Available Purpose Codes** (from CID 7010):
- `.ofInterest` - General interest (default if not specified)
- `.rejectedForQuality` - Quality control rejection
- `.forReferringProvider` - For referring physician
- `.forSurgery` - Surgical planning
- `.forTeaching` - Educational/teaching files
- `.qualityIssue` - Quality concern flagged
- `.bestInSet` - Best image in series
- `.forPrinting` - Selected for printing
- `.forReportAttachment` - Attach to radiology report
- `.custom(CodedConcept)` - Custom purpose code

#### Using MammographyCADSRBuilder for CAD Analysis Results (NEW in v0.9.8)

`MammographyCADSRBuilder` provides a specialized API for creating Mammography Computer-Aided Detection (CAD) Structured Report documents that encode the results of CAD algorithms detecting findings in mammography images.

```swift
import DICOMKit

// Reference to the mammography image being analyzed
let mammoImageRef = ImageReference(
    sopClassUID: "1.2.840.10008.5.1.4.1.1.1.2", // Digital Mammography X-Ray Image Storage
    sopInstanceUID: "1.2.3.4.5.6.7.8.9"
)

// Create a CAD report with algorithm information and findings
let cadReport = try MammographyCADSRBuilder()
    .withPatientID("MM-2024-001")
    .withPatientName("Smith^Jane^Marie")
    .withStudyInstanceUID("1.2.840.113619.2.5.1762583153.215519.978957063.78")
    .withCADProcessingSummary(
        algorithmName: "MammoCare CAD",
        algorithmVersion: "3.2.1",
        manufacturer: "Digital Mammography Systems Inc",
        processingDateTime: "20240115144500"
    )
    // High confidence mass with spiculated margin
    .addFinding(
        type: .mass,
        probability: 0.87,
        location: .circle2D(
            centerX: 245.5,
            centerY: 389.2,
            radius: 18.5,
            imageReference: mammoImageRef
        ),
        characteristics: [
            CodedConcept(
                codeValue: "M-78060",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Spiculated margin"
            )
        ]
    )
    // Calcification cluster
    .addFinding(
        type: .calcification,
        probability: 0.64,
        location: .point2D(x: 156.3, y: 425.8, imageReference: mammoImageRef)
    )
    // Architectural distortion
    .addFinding(
        type: .architecturalDistortion,
        probability: 0.58,
        location: .roi2D(
            points: [100.0, 150.0, 120.0, 160.0, 140.0, 155.0, 130.0, 145.0],
            imageReference: mammoImageRef
        )
    )
    .build()

// Write to file
try DICOMFile(document: cadReport).write(to: "cad_analysis.dcm")
```

**Finding Types**:
- `.mass` - Mass finding (SRT F-01796)
- `.calcification` - Calcification (SRT F-61769)
- `.architecturalDistortion` - Architectural distortion (SRT F-01775)
- `.asymmetry` - Asymmetry (SRT F-01710)
- `.custom(CodedConcept)` - Custom finding type

**Location Types**:
- `.point2D(x, y, imageReference)` - Single point location
- `.roi2D(points, imageReference)` - Polygon region of interest
- `.circle2D(centerX, centerY, radius, imageReference)` - Circular region

**Probability Scores**:
- Values must be between 0.0 (no confidence) and 1.0 (high confidence)
- Typically represents the CAD algorithm's confidence in the detection

#### Using ChestCADSRBuilder for Chest Nodule Detection (NEW in v0.9.8)

`ChestCADSRBuilder` provides a specialized API for creating Chest Computer-Aided Detection (CAD) Structured Report documents that encode the results of CAD algorithms detecting findings in chest radiography and CT images.

```swift
import DICOMKit

// Reference to the chest CT image being analyzed
let ctImageRef = ImageReference(
    sopReference: ReferencedSOP(
        sopClassUID: "1.2.840.10008.5.1.4.1.1.2", // CT Image Storage
        sopInstanceUID: "1.2.3.4.5.6.7.8.9"
    ),
    frameNumbers: nil,
    segmentNumbers: nil,
    purposeOfReference: nil
)

// Create a CAD report with algorithm information and findings
let chestCADReport = try ChestCADSRBuilder()
    .withPatientID("CT-2024-042")
    .withPatientName("Doe^John^David")
    .withStudyInstanceUID("1.2.840.113619.2.5.1762583153.215519.978957063.79")
    .withCADProcessingSummary(
        algorithmName: "LungNoduleCAD",
        algorithmVersion: "4.1.2",
        manufacturer: "Medical AI Systems Inc",
        processingDateTime: "20240115150000"
    )
    // High confidence lung nodule
    .addFinding(
        type: .nodule,
        probability: 0.92,
        location: .circle2D(
            centerX: 256.5,
            centerY: 384.7,
            radius: 8.2,
            imageReference: ctImageRef
        ),
        characteristics: [
            CodedConcept(
                codeValue: "46621007",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Solid nodule"
            )
        ]
    )
    // Medium confidence mass
    .addFinding(
        type: .mass,
        probability: 0.75,
        location: .roi2D(
            points: [150.0, 200.0, 180.0, 210.0, 170.0, 230.0, 140.0, 220.0],
            imageReference: ctImageRef
        )
    )
    // Consolidation finding
    .addFinding(
        type: .consolidation,
        probability: 0.68,
        location: .point2D(x: 320.5, y: 450.2, imageReference: ctImageRef)
    )
    .build()

// Write to file
try DICOMFile(document: chestCADReport).write(to: "chest_cad_analysis.dcm")
```

**Finding Types**:
- `.nodule` - Lung nodule (SRT 39607008)
- `.mass` - Lung mass (SRT 126952004)
- `.lesion` - Lesion of lung (SRT 126601007)
- `.consolidation` - Pulmonary consolidation (SRT 3128005)
- `.treeInBud` - Tree-in-bud pattern (SRT 44914007)
- `.custom(CodedConcept)` - Custom finding type

**Location Types**:
- `.point2D(x, y, imageReference)` - Single point location
- `.roi2D(points, imageReference)` - Polygon region of interest
- `.circle2D(centerX, centerY, radius, imageReference)` - Circular region

**Probability Scores**:
- Values must be between 0.0 (no confidence) and 1.0 (high confidence)
- Represents the CAD algorithm's confidence in the nodule/finding detection


### Coded Terminology Support (v0.9.4)

DICOMKit provides comprehensive support for medical terminologies used in DICOM Structured Reporting.

```swift
import DICOMCore

// SNOMED CT codes for anatomy and findings
let liver = SNOMEDCode.liver
print(liver.concept.description) // "(10200004, SCT, \"Liver\")"

let mass = SNOMEDCode.mass
let calcification = SNOMEDCode.calcification
let rightLung = SNOMEDCode.rightLung

// Laterality
let right = SNOMEDCode.right
let bilateral = SNOMEDCode.bilateral

// LOINC codes for measurements and reports
let bodyWeight = LOINCCode.bodyWeight
let radiologyReport = LOINCCode.radiologyReport
let findings = LOINCCode.findings
let impression = LOINCCode.impression

// RadLex codes for radiology concepts
let ct = RadLexCode.computedTomography
let mri = RadLexCode.magneticResonanceImaging
let nodule = RadLexCode.nodule
let groundGlass = RadLexCode.groundGlassOpacity

// UCUM units with conversion
let mm = UCUMUnit.millimeter
let cm = UCUMUnit.centimeter

// Convert 25.4 mm to cm
if let result = mm.convert(25.4, to: cm) {
    print("25.4 mm = \(result) cm") // 2.54
}

// Temperature conversion
let celsius = UCUMUnit.celsius
let fahrenheit = UCUMUnit.fahrenheit
if let tempF = celsius.convert(100.0, to: fahrenheit) {
    print("100°C = \(tempF)°F") // 212.0
}

// Context group validation
let lateralityGroup = ContextGroup.laterality  // CID 244
let rightCode = CodedConcept(codeValue: "24028007", scheme: .SCT, codeMeaning: "Right")

switch lateralityGroup.validate(rightCode) {
case .valid:
    print("Code is a valid laterality")
case .extensionCode:
    print("Code is allowed as an extension")
case .invalid(let reason):
    print("Invalid: \(reason)")
}

// Cross-terminology mapping
let snomedLiver = SNOMEDCode.liver.concept
if let radlexLiver = snomedLiver.map(to: .RADLEX) {
    print("SNOMED liver maps to RadLex: \(radlexLiver.codeValue)")
}

// Code equivalence checking
let code1 = SNOMEDCode.brain
let code2 = RadLexCode.brain
print("Equivalent: \(code1.isEquivalent(to: code2))") // true

// DCM codes for SR structure
let finding = DICOMCode.finding
let measurement = DICOMCode.measurement
let imageReference = DICOMCode.imageReference

// Coding scheme registry
let registry = CodingSchemeRegistry.shared
if let sctScheme = registry.scheme(forDesignator: "SCT") {
    print("SNOMED CT UID: \(sctScheme.uid ?? "none")")
}
```

## Examples

DICOMKit includes two types of comprehensive examples:

### 1. Sample Code Playgrounds (NEW - February 2026)

The `Playgrounds/` directory contains 27+ interactive Swift playground files organized into 6 categories, covering everything from basic file reading to advanced medical imaging workflows. **Status: 5 of 27 complete (19%)**

**Getting Started** (4 playgrounds) ✅ COMPLETE
- Reading DICOM Files (5 examples)
- Accessing Metadata (9 examples)
- Pixel Data Access (9 examples)
- Error Handling (10 examples)

**Image Processing** (4 playgrounds) 🚧 IN PROGRESS
- Window/Level (9 examples) ✅
- Image Export (planned)
- Multi-frame Series (planned)
- Transfer Syntax (planned)

**Network Operations, Structured Reporting, SwiftUI Integration, Advanced Topics** (17 playgrounds) - Planned

Each playground includes multiple examples, comprehensive comments, and quick reference guides. See [Playgrounds/README.md](Playgrounds/README.md) for details.

### 2. Integration Templates (NEW)

The `Examples/IntegrationTemplates/` directory contains starter templates for common integration scenarios:

- **SwiftUI Viewer Template** - Complete SwiftUI DICOM viewer with file import, metadata display, and image rendering
- More templates coming soon (UIKit, networking, CLI tools, etc.)

See [Examples/IntegrationTemplates/README.md](Examples/IntegrationTemplates/README.md) for details.

### 3. Structured Reporting Examples

DICOMKit includes comprehensive examples demonstrating common Structured Reporting workflows. These examples cover creating, parsing, and working with DICOM SR documents for clinical and research use cases.

### Available Examples

The `Examples/` directory contains the following example files:

1. **BasicTextSRExample.swift** - Simple narrative reports with hierarchical sections
   - Radiology reports, clinical notes, consultation reports
   - Demonstrates Basic Text SR builder API

2. **EnhancedSRExample.swift** - Reports with numeric measurements and references
   - CT/MR reports with measurements, ECG interpretation, laboratory results
   - Demonstrates Enhanced SR builder with UCUM units

3. **ComprehensiveSRExample.swift** - Reports with spatial and temporal coordinates
   - Lung nodule ROI annotations, cardiac perfusion analysis, tumor characterization
   - Demonstrates 2D coordinates (points, polylines, polygons, circles, ellipses)

4. **MeasurementReportExample.swift** - TID 1500 quantitative imaging reports
   - Tumor measurement tracking, RECIST response assessments
   - Demonstrates image library, measurement groups, tracking identifiers

5. **CADSRExample.swift** - Computer-aided detection results
   - Mammography CAD, chest CAD, AI/ML integration
   - Demonstrates findings with confidence scores and spatial locations

### Quick Example: Creating a Basic Text SR

```swift
import DICOMKit

let document = try BasicTextSRBuilder()
    .withPatientID("12345678")
    .withPatientName("Doe^John^^^")
    .withDocumentTitle("Radiology Report")
    
    .addSection("Findings") { section in
        section.addText("The lungs are clear bilaterally.")
        section.addText("No evidence of consolidation or pleural effusion.")
    }
    
    .addSection("Impression") { section in
        section.addText("Normal chest radiograph.")
    }
    
    .build()

// Serialize and save
let dataSet = try SRDocumentSerializer.serialize(document)
let writer = DICOMWriter()
let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
try fileData.write(to: fileURL)
```

### Quick Example: Creating a Measurement Report (TID 1500)

```swift
import DICOMKit

let imageRef = ImageReference(
    referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
    referencedSOPInstanceUID: "1.2.840.113619.2.55.3.100"
)

let document = try MeasurementReportBuilder()
    .withPatientID("98765432")
    .withPatientName("Smith^Jane^^^")
    .withDocumentTitle(.imagingMeasurementReport)
    
    .addToImageLibrary(imageRef, description: "Baseline CT")
    
    .addMeasurementGroup(
        trackingIdentifier: "LESION-001",
        trackingUID: "1.2.840.113619.2.55.3.TRACK.001"
    ) { group in
        group.addLength(value: 42.5, unit: .millimeters, imageReference: imageRef)
        group.addLength(value: 31.2, unit: .millimeters, imageReference: imageRef)
        group.addVolume(value: 27800.0, unit: .cubicMillimeters, derivation: .calculated)
    }
    
    .build()
```

### Quick Example: Creating a CAD SR

```swift
import DICOMKit

let mammogramRef = ImageReference(
    referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
    referencedSOPInstanceUID: "1.2.840.113619.2.55.3.MAMMO.100"
)

let document = try MammographyCADSRBuilder()
    .withPatientID("55566677")
    .withPatientName("Garcia^Maria^^^")
    .withDocumentTitle("Mammography CAD Report")
    
    .withAlgorithmName("BreastCAD v3.2")
    .withAlgorithmVersion("3.2.1")
    
    .addFinding(
        type: .mass,
        confidence: 0.92,
        location: .point(x: 458.3, y: 612.5, imageReference: mammogramRef)
    ) { finding in
        finding.addCharacteristic(
            CodedConcept(
                codeValue: "111320",
                codingSchemeDesignator: .dcm,
                codeMeaning: "Spiculated margin"
            )
        )
    }
    
    .build()
```

For complete examples with detailed documentation, see the [`Examples/` directory](Examples/README.md).

### Demo Applications (v1.0.14+)

DICOMKit includes demo applications that showcase the library's capabilities in production-quality apps:

#### DICOMViewer iOS ✅ Complete

A production-quality mobile DICOM viewer for iOS and iPadOS. **Implementation complete** - all 4 phases delivered with 21 Swift files, 35+ unit tests, and comprehensive documentation.

**Core Features:**
- **File Management**: Import from Files app, iCloud, email, AirDrop; study browser with grid/list views; search and filter by modality
- **Image Viewing**: Multi-frame display with cine playback; pinch-to-zoom, pan, double-tap gestures; frame scrubber (1-30 fps)
- **Display Controls**: Window/level adjustment with CT/MR presets; grayscale inversion; image rotation; view reset
- **GSPS Support**: Grayscale Softcopy Presentation State loading; annotation rendering (graphic and text objects); shutters (rectangular, circular, polygonal); spatial transformations
- **Measurements**: Length and angle tools with pixel spacing support; ROI tools (ellipse, rectangle, freehand); statistics (mean, std dev, min, max, area)
- **Export & Metadata**: PNG/JPEG export with burn-in annotations; Photos app integration; complete metadata viewer with search
- **Polish**: Side-by-side comparison mode; synchronized scrolling/W/L/zoom; VoiceOver accessibility; Dynamic Type; haptic feedback; performance optimized

**Status**: Removed. iOS viewer has been removed from the repository.

#### Planned Demo Applications

**DICOMViewer macOS** - 🚧 Phase 4/5 Complete (February 2026)

A professional diagnostic workstation for macOS with PACS integration, MPR, and 3D visualization. **Phase 4 (MPR and 3D) complete** with 54 files, ~13,500 lines, 224 unit tests. Core features include SwiftData database, file import, study browser, image viewer, C-ECHO/C-FIND/C-MOVE/C-STORE support, DICOMweb (QIDO-RS/WADO-RS/STOW-RS), server configuration UI, query interface, download queue, multi-viewport layouts, hanging protocols, cine playback, measurements, MPR reconstruction (axial/sagittal/coronal), MIP/MinIP/AverageIP projections, and volume rendering with transfer function presets.

**Status**: Phase 4 complete. Ready for Phase 5 (Advanced Features). See [DICOMViewer-macOS/STATUS.md](DICOMViewer-macOS/STATUS.md) for detailed progress and [DICOMViewer-macOS/BUILD.md](DICOMViewer-macOS/BUILD.md) for build instructions.

**Remaining phases**: Advanced Features (Week 5).

- **DICOMViewer visionOS** - ✅ Complete - Spatial 3D medical imaging with hand tracking, immersive volume rendering, and SharePlay collaboration (205 tests, 83% coverage)
- **DICOMTools CLI** - Command-line utilities ✅ Complete Phase 1-7 (38 tools including: dicom-info, dicom-convert, dicom-anon, dicom-validate, dicom-query, dicom-send, dicom-dump, dicom-diff, dicom-retrieve, dicom-split, dicom-merge, dicom-json, dicom-xml, dicom-pdf, dicom-image, dicom-dcmdir, dicom-archive, dicom-export, dicom-qr, dicom-wado, dicom-echo, dicom-mwl, dicom-mpps, dicom-pixedit, dicom-tags, dicom-uid, dicom-compress, dicom-study, dicom-script, dicom-print, dicom-measure, dicom-viewer, dicom-report, dicom-3d, dicom-ai, dicom-cloud, dicom-gateway, dicom-server with 1,111+ tests; all Phase 7 advanced tools complete)
- **DICOMToolbox GUI** - ✅ Complete (Phase 1-8) - SwiftUI macOS application providing graphical interface for 37 CLI tools with drag-and-drop, real-time command preview, educational features, DICOM glossary, accessibility, settings, integration testing, documentation, and release preparation (Phases 1-8 implemented with 370+ tests)

See [DEMO_APPLICATION_PLAN.md](DEMO_APPLICATION_PLAN.md) for complete plans, [CLI_TOOLS_GUI_PLAN.md](CLI_TOOLS_GUI_PLAN.md) for GUI toolbox details, and [MACOS_VIEWER_PLAN.md](MACOS_VIEWER_PLAN.md) for macOS viewer details.

---

## CLI Tools Reference

DICOMKit includes **38 command-line tools** for DICOM operations, all installable via Homebrew or built directly from source.

### Installation

```bash
# Install using local formula (recommended)
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit
brew install --build-from-source Formula/dicomkit.rb

# Or use the installation script
./Scripts/install-cli-tools.sh

# Or build directly from source
swift build -c release
cp .build/release/dicom-* /usr/local/bin/
```

### Complete Tool Reference

<details>
<summary><strong>📂 File Operations (7 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-info` | Display DICOM file metadata with tag filtering | `dicom-info scan.dcm --format json` |
| `dicom-dump` | Hexadecimal dump with DICOM structure overlay | `dicom-dump scan.dcm --show-vr` |
| `dicom-validate` | DICOM conformance validation (4 levels, 7 IODs) | `dicom-validate scan.dcm --level 3` |
| `dicom-diff` | Compare two DICOM files for differences | `dicom-diff file1.dcm file2.dcm` |
| `dicom-convert` | Transfer syntax conversion and image export | `dicom-convert scan.dcm --output scan.png` |
| `dicom-compress` | Compression operations (JPEG, JPEG2000, RLE) | `dicom-compress scan.dcm --jpeg2000` |
| `dicom-dcmdir` | DICOMDIR creation and management | `dicom-dcmdir create ./studies` |

</details>

<details>
<summary><strong>🔐 Privacy & Security (1 tool)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-anon` | DICOM anonymization with HIPAA-compliant profiles | `dicom-anon study/ --profile clinical-trial --shift-dates 100` |

**Anonymization Profiles:**
- `basic` - Remove direct identifiers
- `clinical-trial` - HIPAA Safe Harbor method
- `research` - IRB-compliant anonymization
- `custom` - User-defined rules

</details>

<details>
<summary><strong>🌐 DICOM Networking (8 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-echo` | DICOM echo (C-ECHO) verification | `dicom-echo pacs.hospital.org 104` |
| `dicom-query` | Query DICOM servers (C-FIND) | `dicom-query --host pacs.local --patient-name "Smith*"` |
| `dicom-send` | Send DICOM files to servers (C-STORE) | `dicom-send scan.dcm --host pacs.local:104` |
| `dicom-retrieve` | Retrieve from PACS (C-MOVE/C-GET) | `dicom-retrieve --study-uid 1.2.3...` |
| `dicom-print` | Print to DICOM printers | `dicom-print send image.dcm --printer rad-film-1` |
| `dicom-mwl` | Modality Worklist query | `dicom-mwl query --station-aet CT01` |
| `dicom-mpps` | Modality Performed Procedure Step | `dicom-mpps create --mpps-uid 1.2.3...` |
| `dicom-qr` | Combined Query/Retrieve operations | `dicom-qr --patient-id 12345 --retrieve` |

</details>

<details>
<summary><strong>☁️ DICOMweb & Cloud (2 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-wado` | WADO-RS, QIDO-RS, STOW-RS operations | `dicom-wado retrieve --study-uid 1.2.3... --url https://pacs/dicomweb` |
| `dicom-cloud` | Cloud storage integration (AWS S3) | `dicom-cloud upload scan.dcm --bucket dicom-archive` |

</details>

<details>
<summary><strong>🖼️ Image Processing (4 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-image` | Image extraction and manipulation | `dicom-image scan.dcm --window-level --output images/` |
| `dicom-pixedit` | Pixel data editing and manipulation | `dicom-pixedit scan.dcm --apply-lut` |
| `dicom-split` | Split multi-frame DICOM files | `dicom-split multiframe.dcm --output frames/` |
| `dicom-merge` | Merge images into multi-frame DICOM | `dicom-merge frame*.dcm --output merged.dcm` |

</details>

<details>
<summary><strong>📤 Data Exchange (5 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-json` | DICOM to/from JSON conversion | `dicom-json scan.dcm --output metadata.json` |
| `dicom-xml` | DICOM to/from XML conversion | `dicom-xml scan.dcm --output metadata.xml` |
| `dicom-pdf` | Encapsulated PDF operations | `dicom-pdf extract report.dcm --output report.pdf` |
| `dicom-export` | Multi-format export (NIFTI, raw, etc.) | `dicom-export series/ --format nifti` |
| `dicom-archive` | Archive/extract DICOM collections | `dicom-archive create study.zip ./study` |

</details>

<details>
<summary><strong>📋 Study Management (2 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-study` | Study-level operations and organization | `dicom-study organize ./dicom --by-patient` |
| `dicom-tags` | Tag dictionary lookup and search | `dicom-tags search "patient"` |

</details>

<details>
<summary><strong>🔧 Utilities (3 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-uid` | UID generation and lookup | `dicom-uid generate --type study` |
| `dicom-script` | Batch scripting and automation | `dicom-script run workflow.dscript` |
| `dicom-viewer` | Terminal-based DICOM viewing | `dicom-viewer scan.dcm --ascii` |

</details>

<details>
<summary><strong>📊 Analysis & Reporting (5 tools)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-viewer` | Terminal-based DICOM image viewer | `dicom-viewer scan.dcm --interactive` |
| `dicom-report` | Structured report generation with templates | `dicom-report generate --template radiology --input data.json` |
| `dicom-measure` | Measurement extraction from images | `dicom-measure analyze scan.dcm --roi automatic` |
| `dicom-3d` | MPR, volume, and surface operations | `dicom-3d mpr series/ --plane sagittal` |
| `dicom-ai` | AI-assisted analysis with DICOM output | `dicom-ai analyze scan.dcm --model detection --output-sr` |

</details>

<details>
<summary><strong>🔄 Enterprise Integration (1 tool)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-gateway` | Protocol gateway for HL7 v2, FHIR, and IHE | `dicom-gateway dicom-to-fhir study.dcm --output study.json` |

**Supported Protocols:**
- HL7 v2 (ADT, ORM, ORU messages)
- HL7 FHIR (ImagingStudy, Patient, Practitioner, DiagnosticReport)
- IHE profiles for healthcare interoperability
- Bidirectional conversion (DICOM ↔ HL7, DICOM ↔ FHIR)

</details>

<details>
<summary><strong>🖥️ Server Infrastructure (1 tool)</strong></summary>

| Tool | Description | Example |
|------|-------------|---------|
| `dicom-server` | Lightweight PACS server with C-ECHO, C-FIND, C-STORE, C-MOVE, C-GET | `dicom-server start --aet MY_PACS --port 11112` |

**Server Features:**
- Full DICOM networking services (C-ECHO, C-FIND, C-STORE, C-MOVE, C-GET)
- Structured logging system with multiple log levels
- Comprehensive statistics tracking
- Support for SQLite and PostgreSQL backends
- Access control with AE Title filtering
- Multi-threaded connection handling

</details>

### Usage Examples

#### Basic File Operations

```bash
# View DICOM metadata
dicom-info scan.dcm

# View as JSON
dicom-info scan.dcm --format json

# View specific tags
dicom-info scan.dcm --tag PatientName --tag StudyDate

# Validate a DICOM file
dicom-validate scan.dcm --level 3 --iod CTImageStorage

# Compare two files
dicom-diff baseline.dcm followup.dcm --ignore-timestamps
```

#### Image Conversion

```bash
# Convert to PNG with window/level
dicom-convert ct.dcm --output ct.png --apply-window --window-center -600 --window-width 1500

# Batch convert a directory
dicom-convert ./series/ --output ./images/ --format png --recursive

# Convert transfer syntax
dicom-convert scan.dcm --output compressed.dcm --transfer-syntax jpeg2000-lossless
```

#### Anonymization

```bash
# Anonymize a single file
dicom-anon patient.dcm --output anon.dcm --profile clinical-trial

# Anonymize a study with date shifting
dicom-anon ./study/ --output ./anon_study/ --shift-dates 100 --recursive

# Check for PHI leaks
dicom-anon scan.dcm --check-only
```

#### PACS Communication

```bash
# Test connectivity
dicom-echo pacs.hospital.org 104 --calling-aet DICOMKIT

# Query for studies
dicom-query --host pacs.local --port 104 \
  --calling-aet DICOMKIT --called-aet PACS \
  --patient-name "Smith*" --date-range "20240101-20241231"

# Send files to PACS
dicom-send *.dcm --host pacs.local --port 104 --called-aet PACS

# Retrieve a study
dicom-retrieve --host pacs.local --study-uid 1.2.840.113619... \
  --output ./downloaded_study/ --use-get
```

#### DICOMweb Operations

```bash
# Query studies via QIDO-RS
dicom-wado qido --url https://pacs.hospital.org/dicomweb \
  --patient-name "Smith" --modality CT

# Retrieve study via WADO-RS
dicom-wado retrieve --url https://pacs.hospital.org/dicomweb \
  --study-uid 1.2.840.113619... --output ./downloaded/

# Upload via STOW-RS
dicom-wado stow --url https://pacs.hospital.org/dicomweb \
  --input ./study_to_upload/
```

#### Structured Reporting

```bash
# Generate a radiology report
dicom-report generate --template radiology \
  --input findings.json --output report.dcm

# Extract measurements from SR
dicom-measure extract sr_document.dcm --format csv

# AI analysis with SR output
dicom-ai analyze ct_series/ --model nodule-detection \
  --output-sr findings.dcm --output-seg segmentation.dcm
```

For complete CLI tool documentation, see [CLI_TOOLS_COMPLETION_SUMMARY.md](CLI_TOOLS_COMPLETION_SUMMARY.md).

---

## Architecture

DICOMKit is organized into four modules:

### DICOMCore (v0.9.1, v0.9.4, v1.0.9, v1.0.10)
Core data types and utilities:
- `VR` - All 31 Value Representations from DICOM PS3.5
- `Tag` - Data element tags (group, element pairs)
- `DataElement` - Individual DICOM data elements
- `SequenceItem` - Items within a DICOM sequence
- `UIDGenerator` - UID generation for DICOM objects (NEW in v0.5)
- `DICOMWriter` - Data element serialization (NEW in v0.5)
- `DICOMDate` - DICOM Date (DA) value parsing
- `DICOMTime` - DICOM Time (TM) value parsing
- `DICOMDateTime` - DICOM DateTime (DT) value parsing
- `DICOMAgeString` - DICOM Age String (AS) value parsing
- `DICOMCodeString` - DICOM Code String (CS) value parsing
- `DICOMDecimalString` - DICOM Decimal String (DS) value parsing
- `DICOMIntegerString` - DICOM Integer String (IS) value parsing
- `DICOMPersonName` - DICOM Person Name (PN) value parsing
- `DICOMUniqueIdentifier` - DICOM Unique Identifier (UI) value parsing
- `DICOMApplicationEntity` - DICOM Application Entity (AE) value parsing
- `DICOMUniversalResource` - DICOM Universal Resource Identifier (UR) value parsing
- `PhotometricInterpretation` - Image photometric interpretation types
- `PixelDataDescriptor` - Pixel data attributes and metadata
- `PixelData` - Uncompressed pixel data access
- `PixelDataError` - Detailed error types for pixel data extraction failures
- `WindowSettings` - VOI LUT window center/width settings
- `DICOMError` - Error types for parsing failures
- Little Endian and Big Endian byte reading/writing utilities

**Character Set Support (NEW in v1.0.9):**
- `CharacterSetHandler` - ISO 2022 escape sequence handling for international text
- Support for 18 character repertoires (ISO IR 6-192, UTF-8)
- G0-G3 character set designation and single/locking shift
- Person Name component group handling
- Unicode normalization (NFC, NFD) for display

**Private Tag Support (NEW in v1.0.10):**
- `PrivateCreator` - Private creator identification and block management
- `PrivateTagDictionary` - Vendor-specific private tag definitions
- `PrivateDataElement` - Private data element with creator reference
- `PrivateTagAllocator` - Thread-safe private block allocation
- `PrivateTagDefinition` - Known private tag metadata (name, VR, description)
- `SiemensCSAHeaderParser` - Siemens CSA header parsing (SV10 format)
- Well-known vendor creators: Siemens, GE, Philips, Canon/Toshiba
- Private tag VR inference from vendor dictionaries

**Structured Reporting (NEW in v0.9.1):**
- `ContentItemValueType` - All 15 SR value types enum
- `ContentItem` - Protocol for SR content items
- `AnyContentItem` - Type-erased wrapper for heterogeneous collections
- `TextContentItem`, `CodeContentItem`, `NumericContentItem` - Value content items
- `DateContentItem`, `TimeContentItem`, `DateTimeContentItem` - Temporal content items
- `PersonNameContentItem`, `UIDRefContentItem` - Person and UID content items
- `CompositeContentItem`, `ImageContentItem`, `WaveformContentItem` - Reference content items
- `SpatialCoordinatesContentItem`, `SpatialCoordinates3DContentItem` - Spatial coordinate items
- `TemporalCoordinatesContentItem` - Temporal coordinate items
- `ContainerContentItem` - Container for grouping content items
- `CodedConcept` - Coded concept (Code Value, Coding Scheme Designator, Code Meaning)
- `CodingSchemeDesignator` - Common coding scheme designators (DCM, SCT, LOINC, UCUM, etc.)
- `RelationshipType` - SR relationship types (CONTAINS, HAS PROPERTIES, etc.)
- `SRDocumentType` - 18 SR document types with SOP Class UIDs
- `GraphicType`, `GraphicType3D` - Graphic types for spatial coordinates
- `TemporalRangeType` - Temporal range types for temporal coordinates
- `ContinuityOfContent` - Continuity of content for containers
- `NumericValueQualifier` - Qualifiers for special numeric values
- `ReferencedSOP`, `ImageReference`, `WaveformReference` - SOP reference types

**Coded Terminology (NEW in v0.9.4):**
- `CodingScheme` - Full coding scheme representation with metadata
- `CodingSchemeRegistry` - Registry of known coding schemes
- `SNOMEDCode` - SNOMED CT code support with anatomical, finding, and procedure codes
- `LOINCCode` - LOINC code support with vital signs, measurements, and report sections
- `RadLexCode` - RadLex code support with modalities, findings, and descriptors
- `DICOMCode` - DCM controlled terminology codes
- `UCUMUnit` - UCUM unit support with dimension and conversion
- `ContextGroup` - DICOM context group definitions (CIDs)
- `ContextGroupRegistry` - Registry for context group lookup and validation
- `CodeMapper` - Cross-terminology code mapping utilities
- `CodeEquivalent` - Protocol for semantic code equivalence

### DICOMDictionary
Standard DICOM dictionaries:
- `DataElementDictionary` - Standard data element definitions
- `UIDDictionary` - Transfer Syntax and SOP Class UIDs
- Dictionary entry types

### DICOMNetwork (v0.6, v0.7, v0.7.2, v0.7.3, v0.7.4, v0.7.5, v0.7.6, v0.7.7, v0.7.8, v1.4.0)
DICOM network protocol implementation:
- `DICOMStorageClient` - Unified storage client with server pool and automatic failover (NEW in v0.7.8)
- `DICOMStorageClientConfiguration` - Storage client configuration (NEW in v0.7.8)
- `ServerPool` - Server pool management with selection strategies (NEW in v0.7.8)
- `ServerEntry` - Server entry with connection settings (NEW in v0.7.8)
- `ServerSelectionStrategy` - Selection strategies (round-robin, priority, weighted, random, failover) (NEW in v0.7.8)
- `StorageClientResult` - Detailed result with server and retry information (NEW in v0.7.8)
- `DICOMClient` - Unified high-level client API with retry support (NEW in v0.6.7)
- `DICOMClientConfiguration` - Client configuration with server settings (NEW in v0.6.7)
- `RetryPolicy` - Configurable retry policies with exponential backoff (NEW in v0.6.7)
- `ErrorCategory` - Error categorization (transient, permanent, configuration, protocol, timeout, resource) (NEW in v0.7.5)
- `RecoverySuggestion` - Actionable recovery guidance for errors (NEW in v0.7.5)
- `TimeoutConfiguration` - Fine-grained timeout settings for network operations (NEW in v0.7.5)
- `TimeoutType` - Specific timeout type identification (NEW in v0.7.5)
- `AuditLogger` - Central audit logging for DICOM network operations (NEW in v0.7.5)
- `AuditLogEntry` - Comprehensive audit log entry with transfer metadata (NEW in v0.7.5)
- `AuditEventType` - Types of auditable DICOM network events (NEW in v0.7.5)
- `AuditEventOutcome` - Outcome classification for audit events (NEW in v0.7.5)
- `AuditParticipant` - Information about participants in auditable events (NEW in v0.7.5)
- `AuditLogHandler` - Protocol for handling audit log entries (NEW in v0.7.5)
- `ConsoleAuditLogHandler` - Console-based audit log handler (NEW in v0.7.5)
- `FileAuditLogHandler` - File-based audit log handler with rotation (NEW in v0.7.5)
- `OSLogAuditHandler` - OSLog-based audit handler for Apple platforms (NEW in v0.7.5)
- `DICOMLogCategory.storage` - Log category for C-STORE operations (NEW in v0.7.5)
- `DICOMLogCategory.audit` - Log category for audit events (NEW in v0.7.5)
- `DICOMValidator` - Pre-send data validation for DICOM data sets (NEW in v0.7.6)
- `ValidationConfiguration` - Validation configuration with levels and options (NEW in v0.7.6)
- `ValidationResult` - Validation result with errors and warnings (NEW in v0.7.6)
- `TransferSyntaxConverter` - Automatic transcoding between transfer syntaxes (NEW in v0.7.7)
- `PreferredTransferSyntax` - Configurable preferred transfer syntaxes (NEW in v0.7.7)
- `TLSConfiguration` - TLS settings with protocol versions, certificate validation (NEW in v0.7.4)
- `TLSProtocolVersion` - TLS protocol version enumeration (NEW in v0.7.4)
- `CertificateValidation` - Certificate validation modes (system, disabled, pinned, custom) (NEW in v0.7.4)
- `ClientIdentity` - Client certificate for mutual TLS authentication (NEW in v0.7.4)
- `TLSConfigurationError` - TLS configuration error types (NEW in v0.7.4)
- `DICOMVerificationService` - C-ECHO SCU for connectivity testing
- `DICOMQueryService` - C-FIND SCU for querying PACS
- `DICOMRetrieveService` - C-MOVE and C-GET SCU for retrieving images
- `DICOMStorageService` - C-STORE SCU for sending DICOM files (v0.7), batch storage (v0.7.2)
- `DICOMStorageServer` - C-STORE SCP for receiving DICOM files (NEW in v0.7.3)
- `StorageSCPConfiguration` - SCP configuration with AE whitelist/blacklist (NEW in v0.7.3)
- `StorageDelegate` - Protocol for custom storage handling (NEW in v0.7.3)
- `ReceivedFile` - Received DICOM file information (NEW in v0.7.3)
- `StorageServerEvent` - Event types for server monitoring (NEW in v0.7.3)
- `StoreResult` - Result type for single storage operations (NEW in v0.7)
- `StorageConfiguration` - Configuration for storage operations (NEW in v0.7)
- `BatchStoreResult`, `FileStoreResult` - Result types for batch operations (NEW in v0.7.2)
- `BatchStoreProgress`, `StorageProgressEvent` - Progress reporting for batch storage (NEW in v0.7.2)
- `BatchStorageConfiguration` - Configuration for batch storage operations (NEW in v0.7.2)
- `QueryKeys` - Fluent API for building query identifiers
- `RetrieveKeys` - Fluent API for building retrieve identifiers
- `QueryLevel` - PATIENT, STUDY, SERIES, IMAGE levels
- `QueryRetrieveInformationModel` - Patient Root, Study Root models
- `StudyResult`, `SeriesResult`, `InstanceResult` - Type-safe query results
- `RetrieveProgress`, `RetrieveResult` - Progress and result types for retrieve operations
- `Association` - DICOM Association management
- `CommandSet`, `PresentationContext` - Low-level protocol types
- `DIMSEMessages` - DIMSE-C message types (C-ECHO, C-FIND, C-STORE, C-MOVE, C-GET)
- `NCreateRequest`, `NCreateResponse` - N-CREATE DIMSE message types (NEW in v1.4.0)
- `NSetRequest`, `NSetResponse` - N-SET DIMSE message types (NEW in v1.4.0)
- `NGetRequest`, `NGetResponse` - N-GET DIMSE message types (NEW in v1.4.0)
- `NDeleteRequest`, `NDeleteResponse` - N-DELETE DIMSE message types (NEW in v1.4.0)
- `DICOMPrintService` - Print Management Service Class (PS3.4 Annex H) (NEW in v1.4.0)
- `PrintConfiguration` - Print connection and mode settings (NEW in v1.4.0)
- `FilmSession` - Film session parameters (copies, priority, medium, destination) (NEW in v1.4.0)
- `FilmBox` - Film box layout parameters (display format, orientation, size) (NEW in v1.4.0)
- `FilmBoxResult` - Film box creation result (film box UID, image box UIDs, image count) (NEW in v1.4.1)
- `ImageBoxContent` - Image box content (position, polarity, crop behavior) (NEW in v1.4.0)
- `PrinterStatus` - Printer status information (NEW in v1.4.0)
- `PrintResult` - Print operation result (NEW in v1.4.0)
- `PrintOptions` - High-level print configuration with presets (.default, .highQuality, .draft, .mammography) (NEW in v1.4.2)
- `PrintTemplate` - Reusable print layouts (SingleImage, Comparison, Grid, MultiPhase) (NEW in v1.4.2)
- `PrintProgress` - Progress reporting with AsyncThrowingStream support (NEW in v1.4.2)
- `PrintLayout` - Optimal layout selection for image count (NEW in v1.4.2)
- `PrintRetryPolicy` - Configurable retry logic with exponential backoff (NEW in v1.4.2)
- `ImagePreprocessor` - Image preparation pipeline (window/level, rescale, polarity) (NEW in v1.4.3)
- `ImageResizer` - High-quality image resizing (fit/fill/stretch modes, bicubic interpolation) (NEW in v1.4.3)
- `AnnotationRenderer` - Text overlay rendering with positioning (NEW in v1.4.3)
- `PreparedImage` - Processed image data ready for printing (NEW in v1.4.3)
- `PrintJob` - Print job representation with priority and metadata (NEW in v1.4.4)
- `PrintQueue` - Actor-based print queue with priority scheduling and retry (NEW in v1.4.4)
- `PrinterRegistry` - Multiple printer management with load balancing (NEW in v1.4.4)
- `PrinterCapabilities` - Printer feature tracking (film sizes, color, copies) (NEW in v1.4.4)
- `PrintError` - Detailed error cases with recovery suggestions (NEW in v1.4.4)
- `PartialPrintResult` - Partial failure handling (NEW in v1.4.4)

### DICOMKit (v0.9.2, v0.9.3, v0.9.4, v0.9.5, v0.9.6, v0.9.7, v0.9.8, v1.0.1, v1.0.2, v1.0.3, v1.0.4, v1.0.5, v1.0.6, v1.0.7, v1.0.8, v1.1.0, v1.5.0, v1.6.0, v1.7.0)
High-level API:
- `DICOMFile` - DICOM Part 10 file abstraction (reading and writing)
- `DataSet` - Collections of data elements (with setter methods)
- `PixelDataRenderer` - CGImage rendering for Apple platforms (iOS, macOS, visionOS)
- Public API umbrella

**Grayscale Presentation State (GSPS) (NEW in v1.0.1):**
- `PresentationState` - Base protocol for presentation state objects
- `GrayscalePresentationState` - Grayscale Softcopy Presentation State struct (PS3.3 A.33)
- `ColorPresentationState` - Color Softcopy Presentation State struct (PS3.3 A.34) (NEW in v1.0.2)
- `PseudoColorPresentationState` - Pseudo-Color Softcopy Presentation State struct (PS3.3 A.35) (NEW in v1.0.2)
- `BlendingPresentationState` - Blending Softcopy Presentation State struct (PS3.3 A.36) (NEW in v1.0.2)
- `GrayscalePresentationStateParser` - Parse GSPS DICOM objects into structured format
- `ReferencedSeries` - Referenced series in a presentation state
- `ReferencedImage` - Referenced image instance with frame numbers
- `ICCProfile` - ICC color profile for device-independent color management (NEW in v1.0.2)
- `ColorSpace` - Supported color spaces (sRGB, Adobe RGB, Display P3, etc.) (NEW in v1.0.2)
- `ColorMapPreset` - Preset pseudo-color maps (grayscale, hot, cool, jet, bone, copper) (NEW in v1.0.2)
- `BlendingDisplaySet` - Blending configuration for multi-modality fusion (NEW in v1.0.2)
- `ReferencedImageForBlending` - Image reference with blending metadata (NEW in v1.0.2)
- `BlendingMode` - Blending algorithms (alpha, MIP, MinIP, average, add, subtract) (NEW in v1.0.2)
- `ModalityLUT` - Modality LUT transformation (linear, lookup table)
- `VOILUT` - VOI LUT transformation (window/level, lookup table)
- `PresentationLUT` - Presentation LUT transformation (identity, inverse, lookup table)
- `LUTData` - Lookup table data with descriptor
- `SpatialTransformation` - Image rotation and flipping transformations
- `DisplayedArea` - Zoom and pan state with presentation size mode
- `PresentationSizeMode` - Scaling behavior (scale to fit, true size, magnify)
- `GraphicLayer` - Graphic annotation layer with ordering
- `GraphicAnnotation` - Annotation with graphic and text objects
- `GraphicObject` - Geometric annotation (point, polyline, circle, ellipse, etc.)
- `PresentationGraphicType` - Annotation graphic types
- `TextObject` - Text annotation with positioning and formatting
- `AnnotationUnits` - Coordinate system for annotations (pixel, display)
- `DisplayShutter` - Region masking (rectangular, circular, polygonal, bitmap)
- `ShutterShape` - Shutter shape enumeration
- `PresentationStateApplicator` - Apply GSPS to images and render with annotations

**Hanging Protocol Support (NEW in v1.0.3):**
- `HangingProtocol` - Complete hanging protocol structure (PS3.3 A.38)
- `HangingProtocolLevel` - Protocol level enum (SITE, GROUP, USER)
- `HangingProtocolEnvironment` - Environment matching criteria (modality, laterality)
- `HangingProtocolParser` - Parse DICOM Hanging Protocol objects
- `HangingProtocolSerializer` - Serialize to DICOM Hanging Protocol format
- `HangingProtocolMatcher` - Actor for intelligent protocol selection
- `HangingProtocolError` - Hanging protocol error types
- `ImageSetDefinition` - Criteria for selecting images from studies
- `ImageSetSelector` - Attribute-based image filtering with operators
- `FilterOperator` - Comparison operators (equal, contains, less than, present, etc.)
- `SelectorUsageFlag` - Positive/negative matching flag
- `SortOperation` - Image ordering specifications
- `SortByCategory` - Sort category enum (instance number, time, position, etc.)
- `SortDirection` - Sort direction (ascending, descending)
- `TimeBasedSelection` - Prior study selection with relative time
- `RelativeTimeUnits` - Time units for prior selection
- `ImageSetSelectorCategory` - Image set category (current, prior, comparison)
- `DisplaySet` - Display set specification with layout and options
- `ImageBox` - Viewport/panel definition with layout configuration
- `ImageBoxLayoutType` - Layout types (stack, tiled, tiled-all)
- `ScrollDirection` - Scroll direction for navigation
- `ScrollType` - Scroll increment type (image, fraction, page)
- `ReformattingOperation` - MPR reformatting specification
- `ReformattingType` - Reformatting types (MPR, CPR, MIP, MinIP, AvgIP)
- `ThreeDRenderingType` - 3D rendering hints (volume, surface, MIP)
- `DisplayOptions` - Display preferences (orientation, VOI, annotations, etc.)
- `Justification` - Layout justification (left, center, right, top, bottom)
- `ScreenDefinition` - Nominal screen specification for multi-monitor setups
- `StudyInfo` - Study information for protocol matching
- `InstanceInfo` - Instance information for image set filtering
- `ImageSetMatcher` - Matcher for applying image set selection criteria

**Radiation Therapy Structure Set Support (NEW in v1.0.4):**
- `RTStructureSet` - Complete RT Structure Set structure (PS3.3 A.19)
- `RTStructureSetParser` - Parse DICOM RT Structure Set objects
- `RTRegionOfInterest` - ROI definition with identification and metadata
- `ROIContour` - ROI contour geometry linkage
- `Contour` - Individual contour with geometric type and 3D points
- `ContourGeometricType` - Contour types (POINT, OPEN_PLANAR, CLOSED_PLANAR, OPEN_NONPLANAR, CLOSED_NONPLANAR)
- `Point3D` - 3D point in patient coordinate system (mm)
- `Vector3D` - 3D vector for contour offsets
- `DisplayColor` - RGB color (0-255) for ROI visualization
- `RTROIObservation` - Clinical observation and interpretation
- `RTROIInterpretedType` - ROI clinical types (PTV, CTV, GTV, ORGAN, EXTERNAL, AVOIDANCE, etc.)
- `ROIPhysicalProperty` - Physical property specification (density, mass)

**Radiation Therapy Plan and Dose Support (NEW in v1.0.5):**
- `RTPlan` - Complete RT Plan structure (PS3.3 A.20)
- `RTPlanParser` - Parse DICOM RT Plan objects
- `DoseReference` - Dose prescription references for targets and OARs
- `FractionGroup` - Treatment fraction scheduling and beam grouping
- `RTBeam` - External beam radiation therapy beam definition
- `BeamControlPoint` - Beam state at specific delivery positions
- `BeamLimitingDevicePosition` - Jaw and MLC positions
- `WedgePosition` - Wedge configuration and orientation
- `BrachyApplicationSetup` - Brachytherapy applicator setup
- `BrachyChannel` - Brachytherapy source channel
- `BrachyControlPoint` - Source position and dwell time
- `RTDose` - 3D dose distribution grid (PS3.3 A.18)
- `RTDoseParser` - Parse DICOM RT Dose objects
- `DVHData` - Dose Volume Histogram data

**Segmentation Objects Support (NEW in v1.0.6):**
- `Segmentation` - Complete segmentation structure (PS3.3 A.51)
- `SegmentationParser` - Parse DICOM Segmentation objects
- `Segment` - Segment definition with coded terminology
- `SegmentationType` - Segmentation type enum (BINARY, FRACTIONAL)
- `SegmentationFractionalType` - Fractional type enum (PROBABILITY, OCCUPANCY)
- `SegmentAlgorithmType` - Algorithm type enum (AUTOMATIC, SEMIAUTOMATIC, MANUAL)
- `CodedConcept` - Coded concept for standardized terminology
- `CIELabColor` - CIELab color representation for display colors
- `FunctionalGroup` - Multi-frame functional group container
- `SegmentIdentification` - Segment identification per frame
- `DerivationImage` - Derivation image with source references
- `SourceImage` - Source image reference
- `FrameContent` - Frame content metadata
- `PlanePosition` - Image position in patient coordinate system
- `PlaneOrientation` - Image orientation in patient coordinate system
- `SegmentationPixelDataExtractor` - Extract binary and fractional segment masks
- `SegmentationRenderer` - Render segmentation overlays with color mapping
- `SegmentationBuilder` - Build DICOM segmentations from binary/fractional masks

**Parametric Map Objects Support (NEW in v1.0.7):**
- `ParametricMap` - Complete parametric map structure for quantitative imaging (PS3.3 A.75)
- `ParametricMapParser` - Parse DICOM Parametric Map objects
- `QuantityDefinition` - Physical quantity type definitions (ADC, T1, T2, Ktrans, Ve, Vp, SUV variants)
- `MeasurementUnits` - UCUM unit coding (mm²/s, ms, s, g/ml, /min, ratio)
- `RealWorldValueMapping` - Stored pixel value to physical quantity transformation
- `MappingMethod` - Linear or LUT-based value mapping
- `CodedEntry` - Generic coded entry for derivation sequences
- `ParametricMapReferencedSeries` - Referenced series for parametric maps
- `ReferencedInstance` - Referenced DICOM instance with frame numbers
- `ParametricMapPixelDataExtractor` - Extract parametric values from multi-format pixel data
- `ParametricMapRenderer` - Render parametric maps with color mapping
- `ColorMap` - Color map enum (grayscale, hot, cool, jet, viridis, turbo, custom)
- `RenderOptions` - Rendering configuration (window/level, threshold, color map)

**Real-World Value Mapping (RWV LUT) Support (NEW in v1.0.8):**
- `RealWorldValueLUT` - General-purpose real world value lookup table for pixel value transformation
- `RealWorldValueLUT.Transformation` - Transformation method (linear slope/intercept or explicit LUT)
- `RealWorldValueLUT.LUTDescriptor` - LUT descriptor with first/last mapped values
- `RealWorldValueLUT.FrameScope` - Mapping scope (first frame, all frames, specific frames)
- `RealWorldValueUnits` - UCUM-based measurement units with coded entries
- `RealWorldValueLUTParser` - Parse RWV Mapping Sequence and legacy Modality LUT
- `RealWorldValueRenderer` - Actor for concurrent-safe pixel value transformation
- `RealWorldValueStatistics` - Statistics on real world values (min, max, mean, median, std dev)
- `RealWorldValueError` - RWV operation errors
- `SUVCalculator` - PET Standardized Uptake Value calculations with decay correction
- `SUVCalculator.RadionuclideHalfLife` - Common PET radionuclide half-lives (F-18, C-11, O-15, N-13, Ga-68, Cu-64, Zr-89, I-124)
- `PatientSex` - Patient sex enumeration for SUV body metrics
- CodedConcept extensions: Pre-defined quantities (ADC, T1/T2/T2*, Ktrans/Ve/Vp, CBF/CBV/MTT, SUV variants, Hounsfield)

**Encapsulated Document Support (NEW in v1.1.0):**
- `EncapsulatedDocument` - DICOM Encapsulated Document IOD (PS3.3 A.45)
- `EncapsulatedDocumentType` - Document type enum (PDF, CDA, STL, OBJ, MTL)
- `EncapsulatedDocumentParser` - Parse encapsulated documents from DICOM data sets
- `EncapsulatedDocumentBuilder` - Fluent builder API for creating DICOM-wrapped documents
- `ConceptNameCode` - Coded concept for document content description
- `SourceInstanceReference` - Reference to source DICOM instances
- SOP Class UID constants for all 5 encapsulated document types

**Waveform Data Support (NEW in v1.5.0):**
- `Waveform` - DICOM Waveform IOD (PS3.3 A.34) with 9 SOP Classes
- `WaveformType` - Waveform type enum (12-Lead ECG, General ECG, Ambulatory ECG, Hemodynamic, Cardiac Electrophysiology, Basic Voice Audio, General Audio, Arterial Pulse, Respiratory)
- `WaveformMultiplexGroup` - Multiplex group with channels, sampling frequency, and interleaved data
- `WaveformChannel` - Channel definition with label, source, sensitivity, filters, and calibration
- `WaveformAnnotation` - Text and measurement annotations with temporal ranges
- `WaveformParser` - Parse waveform data from DICOM data sets
- `WaveformBuilder` - Fluent builder API for creating waveform DICOM objects
- `WaveformCodedConcept` - Coded concept for channel sources and annotations
- `WaveformSampleInterpretation` - Sample interpretation enum (SB, SS, UB, US, MB, AB)
- `WaveformOriginality` - Waveform originality enum (ORIGINAL, DERIVED)

**DICOM Video Support (NEW in v1.6.0):**
- `Video` - DICOM Video IOD (PS3.3 A.32.5-7) with 3 SOP Classes
- `VideoType` - Video type enum (endoscopic, microscopic, photographic)
- `VideoCodec` - Video codec enum (mpeg2, h264, h265) with compression method identifiers
- `VideoParser` - Parse video metadata from DICOM data sets
- `VideoBuilder` - Fluent builder API for creating video DICOM objects
- SOP Class UID constants for Video Endoscopic, Video Microscopic, Video Photographic
- 6 video transfer syntaxes (MPEG2, H.264, H.265) with `isVideo`, `isMPEG2`, `isH264`, `isH265`

**Secondary Capture Image IOD (NEW in v1.7.0):**
- `SecondaryCaptureImage` - DICOM Secondary Capture IOD (PS3.3 A.8) with 5 SOP Classes
- `SecondaryCaptureType` - SC type enum (singleFrame, multiframeSingleBit, multiframeGrayscaleByte, multiframeGrayscaleWord, multiframeTrueColor)
- `ConversionType` - SC Equipment Module conversion type enum (DV, DI, DF, WSD, SD, SI, SYN)
- `SecondaryCaptureParser` - Parse SC metadata from DICOM data sets
- `SecondaryCaptureBuilder` - Fluent builder API for creating SC DICOM objects
- SC-specific DICOM tags: Conversion Type, Date/Time of Secondary Capture, Page Number Vector

**Content Item Navigation and Tree Traversal (NEW in v0.9.3):**
- `ContentTreeIterator` - Depth-first iterator for SR content trees
- `BreadthFirstIterator` - Breadth-first iterator for SR content trees
- `ContentTreeSequence` - Sequence wrapper with traversal order options
- `SRPath` - Path notation for addressing content items (e.g., "/Finding[0]/Measurement")
- `SRPath.Component` - Path component with concept and value type matching
- `SRPathError` - Path navigation errors
- Extensions on `ContainerContentItem`:
  - `item(at:)` - Navigate to item by path
  - Subscripts for index, concept string, and coded concept access
  - `findItems(byConceptName:recursive:)` - Query by concept
  - `findItems(byValueType:recursive:)` - Query by value type
  - `findItems(byRelationship:recursive:)` - Query by relationship
  - `findMeasurements()` / `findMeasurementGroups()` - Measurement navigation
  - Relationship navigation properties (`propertyItems`, `containedItems`, etc.)
- Extensions on `SRDocument`:
  - Path-based subscript access (`document[path: "/Finding"]`)
  - All query and navigation methods from containers
  - Relationship-based filtering properties

**Structured Reporting Document Parsing (v0.9.2):**
- `SRDocument` - Parsed SR document with metadata and content tree
- `SRDocumentParser` - Parse DICOM data sets into SR documents
- `SRDocumentParser.Configuration` - Parser configuration options
- `SRDocumentParser.ValidationLevel` - Strict or lenient parsing
- `SRDocumentParser.ParseError` - Detailed parsing errors
- `CompletionFlag` - Document completion status (COMPLETE, PARTIAL)
- `VerificationFlag` - Document verification status (VERIFIED, UNVERIFIED)
- `PreliminaryFlag` - Document preliminary status (PRELIMINARY, FINAL)

**Structured Reporting Document Creation (NEW in v0.9.6):**
- `SRDocumentBuilder` - Fluent builder API for creating SR documents
- `SRDocumentBuilder.BuildError` - Builder validation errors
- `SRDocumentSerializer` - Convert SRDocument to DICOM DataSet
- `SRDocumentSerializer.SerializationError` - Serialization errors
- `ContainerBuilder` - Result builder for declarative container construction
- Extension: `SRDocument.toDataSet()` - Serialize document to DataSet
- Extension: `SRDocumentType.allowsValueType()` - Check value type compatibility

**Common SR Templates (NEW in v0.9.8):**
- `BasicTextSRBuilder` - Specialized builder for Basic Text SR documents (NEW in v0.9.8)
- `BasicTextSRBuilder.BuildError` - Builder validation errors
- `SectionContentBuilder` - Result builder for declarative section content
- `SectionContent` - Helper enum for building section content
- `EnhancedSRBuilder` - Specialized builder for Enhanced SR documents with measurements (NEW in v0.9.8)
- `EnhancedSRBuilder.BuildError` - Builder validation errors
- `EnhancedSectionContentBuilder` - Result builder for Enhanced SR section content
- `EnhancedSectionContent` - Helper enum for measurements and text content
- `ComprehensiveSRBuilder` - Specialized builder for Comprehensive SR documents with spatial/temporal coordinates (NEW in v0.9.8)
- `ComprehensiveSRBuilder.BuildError` - Builder validation errors
- `ComprehensiveSectionContentBuilder` - Result builder for Comprehensive SR section content
- `ComprehensiveSectionContent` - Helper enum for coordinates, measurements, and text content
- `Comprehensive3DSRBuilder` - Specialized builder for Comprehensive 3D SR documents with 3D spatial coordinates (NEW in v0.9.8)
- `Comprehensive3DSRBuilder.BuildError` - Builder validation errors
- `Comprehensive3DSectionContentBuilder` - Result builder for Comprehensive 3D SR section content
- `Comprehensive3DSectionContent` - Helper enum for 3D coordinates, measurements, and text content
- `MeasurementReportBuilder` - Specialized builder for TID 1500 Measurement Reports (NEW in v0.9.8)
- `MeasurementReportBuilder.BuildError` - Builder validation errors
- `MeasurementGroupContentBuilder` - Result builder for measurement group content
- `MeasurementGroupContent` - Content types for measurement groups
- `MeasurementGroupContentHelper` - Helper for creating common measurements
- `MeasurementGroupData` - Data structure for measurement group configuration
- `ImageLibraryEntry` - Entry in an image library (TID 1600)
- `MeasurementReportDocumentTitle` - Common document title codes (CID 7021)
- `KeyObjectSelectionBuilder` - Specialized builder for Key Object Selection documents (NEW in v0.9.8)
- `KeyObjectSelectionBuilder.BuildError` - Builder validation errors
- `KeyObject` - Referenced instance in a KOS document (NEW in v0.9.8)
- `DocumentTitle` - Standard purpose codes for KOS documents from CID 7010 (NEW in v0.9.8)
- `MammographyCADSRBuilder` - Specialized builder for Mammography CAD SR documents (NEW in v0.9.8)
- `MammographyCADSRBuilder.BuildError` - Builder validation errors
- `CADFinding` - CAD finding with type, probability, and location (NEW in v0.9.8)
- `FindingType` - CAD finding types (mass, calcification, etc.) (NEW in v0.9.8)
- `FindingLocation` - Spatial location types (point2D, roi2D, circle2D) (NEW in v0.9.8)
- `ChestCADSRBuilder` - Specialized builder for Chest CAD SR documents (NEW in v0.9.8)
- `ChestCADSRBuilder.BuildError` - Builder validation errors
- `ChestCADFinding` - Chest CAD finding with type, probability, and location (NEW in v0.9.8)
- `ChestFindingType` - Chest finding types (nodule, mass, lesion, consolidation, tree-in-bud) (NEW in v0.9.8)
- `ChestFindingLocation` - Spatial location types for chest findings (point2D, roi2D, circle2D) (NEW in v0.9.8)
- `CodedConcept.findings`, `.impression`, `.clinicalHistory`, etc. - Common section concepts
- `CodedConcept.measurements`, `.diameter`, `.length`, `.area`, `.volume` - Measurement concepts
- `CodedConcept.imageRegion`, `.regionOfInterest`, `.measurementLocation`, `.temporalExtent` - Coordinate concepts (NEW in v0.9.8)

**Measurement and Coordinate Extraction (NEW in v0.9.5):**
- `Measurement` - Extracted numeric measurement with value, unit, and context
- `MeasurementGroup` - Related measurements grouped together
- `MeasurementQualifier` - Special value qualifiers (NaN, infinity, overflow)
- `DerivationMethod` - How measurement was obtained (manual, automatic, calculated)
- `MeasurementStatistics` - Statistical summary (mean, min, max, std dev)
- `SpatialCoordinates` - 2D coordinates with computed geometry (area, perimeter, centroid)
- `SpatialCoordinates3D` - 3D coordinates with bounding box and centroid
- `TemporalCoordinates` - Temporal coordinates with duration calculation
- `ROI` - Region of Interest combining coordinates with measurements
- `MeasurementExtractor` - API for extracting measurements and coordinates from SR documents

### DICOMWeb (v0.8.1, v0.8.2, v0.8.3, v0.8.4, v0.8.5, v0.8.6, v0.8.7, v0.8.8, v1.8.0)
DICOMweb (RESTful DICOM) client and server implementation:

**Advanced Features (NEW in v0.8.8):**
- `OAuth2Configuration` - OAuth2 client configuration
- `OAuth2Token` - Token representation with expiration tracking
- `OAuth2Error` - OAuth2 error handling
- `PKCE` - Proof Key for Code Exchange for public clients
- `OAuth2TokenProvider` - Protocol for token management
- `OAuth2TokenManager` - Actor for token lifecycle management
- `StaticTokenProvider` - Simple token provider for testing
- `DICOMwebCapabilities` - Server capabilities representation
- `DICOMwebCapabilities.SupportedServices` - Supported services info
- `DICOMwebCapabilities.QueryCapabilities` - Query feature support
- `DICOMwebCapabilities.StoreCapabilities` - Store feature support
- `ConformanceStatement` - DICOM conformance statement document (NEW in v0.8.8)
- `ConformanceStatementGenerator` - Auto-generate conformance statements (NEW in v0.8.8)
- `CacheConfiguration` - Cache configuration with presets
- `CacheEntry` - Cached response with TTL
- `CacheStorage` - Protocol for cache storage
- `InMemoryCache` - LRU in-memory cache actor
- `CacheKeyGenerator` - Cache key utilities
- `CacheControlDirective` - Cache-Control header parsing
- `CompressionConfiguration` - HTTP response compression settings (NEW in v0.8.8)
- `CompressionAlgorithm` - Supported compression algorithms (gzip, deflate) (NEW in v0.8.8)
- `CompressionMiddleware` - Server response compression (NEW in v0.8.8)
- `ServerCacheMiddleware` - Server-side response caching with ETag support (NEW in v0.8.8)
- `AcceptEncodingEntry` - Accept-Encoding header entry with quality value (NEW in v0.8.8)
- `DICOMwebRequestLogger` - Request/response logging protocol
- `OSLogRequestLogger` - OSLog-based logger
- `ConsoleRequestLogger` - Console debug logger
- `NullRequestLogger` - No-op logger
- `CompositeRequestLogger` - Multiple logger aggregation
- `DICOMwebMetrics` - Performance metrics actor
- `MetricTimer` - Operation timing helper

**Server Authentication Middleware (NEW in v0.8.8):**
- `JWTClaims` - JWT token claims parsing
- `JWTVerifier` - Protocol for JWT verification
- `JWTVerificationError` - JWT verification error types
- `UnsafeJWTParser` - JWT parser without signature verification
- `HMACJWTVerifier` - HMAC-based JWT verifier (HS256/384/512)
- `AuthenticatedUser` - Authenticated user context
- `DICOMwebRole` - Standard DICOM roles (reader, writer, deleter, worklistManager, admin)
- `DICOMwebOperation` - Operations (search, retrieve, store, delete, worklist*)
- `DICOMwebResource` - Resource types with UIDs
- `AccessPolicy` - Protocol for authorization policies
- `RoleBasedAccessPolicy` - Role-based access control with presets
- `AuthenticationConfiguration` - Authentication configuration
- `AuthenticationMiddleware` - Request authentication and authorization
- `AuthenticationError` - Authentication error types
- `AuthorizationError` - Authorization error types

**UPS-RS (Unified Procedure Step) Components (NEW in v0.8.7, UPDATED in v0.8.9):**
- `Workitem` - UPS workitem representation with scheduling and state
- `UPSState` - State machine (SCHEDULED, IN PROGRESS, COMPLETED, CANCELED)
- `UPSPriority` - Priority levels (STAT, HIGH, MEDIUM, LOW)
- `ProgressInformation` - Workitem progress tracking
- `HumanPerformer` - Performer information
- `CodedEntry` - Coded values (SNOMED, LOINC, etc.)
- `ReferencedInstance` - Referenced DICOM instance
- `UPSQuery` - Fluent query builder for workitem searches
- `UPSQueryAttribute` - Standard UPS-RS query attribute tags
- `UPSQueryResult` - Paginated workitem query results
- `WorkitemResult` - Individual workitem result
- `UPSStorageProvider` - Protocol for workitem storage backends
- `InMemoryUPSStorageProvider` - In-memory workitem storage for testing
- `UPSStorageQuery` - Query parameters for workitem searches
- `UPSError` - Error types for UPS operations
- `UPSStateChangeRequest` - State change request
- `UPSCancellationRequest` - Cancellation request
- `UPSCreateResponse`, `UPSStateChangeResponse`, `UPSCancellationResponse` - Response types
- `UPSTag` - DICOM tag constants for UPS attributes
- ✅ **Event System (NEW in v0.8.9):**
  - `UPSEventType` - Event types (StateReport, ProgressReport, CancelRequested, Assigned, Completed, Canceled)
  - `UPSEvent` - Base protocol for all UPS events
  - `UPSStateReportEvent`, `UPSProgressReportEvent`, `UPSCancelRequestedEvent`, `UPSAssignedEvent`, `UPSCompletedEvent`, `UPSCanceledEvent` - Concrete event types
  - `AnyUPSEvent` - Type-erased event wrapper
  - `Subscription` - Subscription data model with deletion lock and event filtering
  - `SubscriptionManager` - Protocol for managing subscriptions
  - `InMemorySubscriptionManager` - In-memory subscription management
  - `EventDeliveryService` - Protocol for pluggable event delivery mechanisms
  - `EventQueue` - Reliable event queuing with retry logic
  - `EventDispatcher` - Coordinates event generation, queuing, and delivery
  - `LoggingEventDeliveryService` - Event logging for testing/development
- ✅ **Task Handling Enhancements (NEW in v1.8.0):**
  - `WorkitemBuilder` - Fluent builder for constructing Workitem instances
  - `WorkitemValidationError` - Validation error types for workitem data

**Server Components:**
- `DICOMwebServer` - WADO-RS, QIDO-RS, and STOW-RS server actor (v0.8.5)
- `DICOMwebServerConfiguration` - Server configuration (port, TLS, CORS, rate limiting, STOW) (v0.8.5, v0.8.6)
- `DICOMwebServerConfiguration.TLSConfiguration` - TLS/HTTPS configuration with presets (NEW in v0.8.8)
- `DICOMwebServerConfiguration.TLSVersion` - TLS protocol version enum (NEW in v0.8.8)
- `DICOMwebServerConfiguration.CertificateValidationMode` - Client certificate validation modes (NEW in v0.8.8)
- `DICOMwebServerConfiguration.TLSConfigurationError` - TLS configuration error types (NEW in v0.8.8)
- `DICOMwebServerConfiguration.STOWConfiguration` - STOW-RS configuration (duplicate policy, validation) (NEW in v0.8.6)
- `DICOMwebStorageProvider` - Protocol for pluggable storage backends (v0.8.5)
- `InMemoryStorageProvider` - In-memory storage for testing (v0.8.5)
- `DICOMwebRouter` - URL pattern matching for DICOMweb routes (v0.8.5)
- `DICOMwebRequest` - HTTP request abstraction (v0.8.5)
- `DICOMwebResponse` - HTTP response abstraction (v0.8.5)
- `RouteMatch` - Route matching result with path parameters (v0.8.5)
- `StorageQuery` - Query parameters for storage searches (v0.8.5)
- `StudyRecord`, `SeriesRecord`, `InstanceRecord` - Query result types (v0.8.5)
- `STOWDelegate` - Protocol for STOW-RS event handling (NEW in v0.8.6)
- `DICOMwebServerDelegate` - Protocol for server lifecycle events (v0.8.5)

**Client Components:**
- `DICOMwebClient` - Unified client for all DICOMweb services: WADO-RS, QIDO-RS, STOW-RS, and UPS-RS (UPDATED in v0.8.8)
- `UPSClient` - Standalone UPS-RS (Unified Procedure Step) client for worklist management (NEW in v0.8.7)
- `STOWResponse` - Response type for store operations (v0.8.4)
- `StoreProgress` - Progress information for uploads (v0.8.4)
- `StoreOptions` - Configuration for store operations (v0.8.4)
- `StoreEvent` - Event types for progress streams (v0.8.4)
- `QIDOQuery` - Fluent query builder for QIDO-RS searches (v0.8.3)
- `QIDOStudyResult` - Type-safe study query result (v0.8.3)
- `QIDOSeriesResult` - Type-safe series query result (v0.8.3)
- `QIDOInstanceResult` - Type-safe instance query result (v0.8.3)
- `QIDOResults<T>` - Paginated query results container (v0.8.3)
- `QIDOQueryAttribute` - Standard QIDO-RS query attribute tags (v0.8.3)
- `RetrieveResult` - Result type for retrieve operations (v0.8.2)
- `FrameResult` - Result type for frame retrieval (v0.8.2)
- `RenderOptions` - Options for rendered image retrieval (v0.8.2)
- `RetrieveProgress` - Progress information for downloads (v0.8.2)
- `HTTPClient` - HTTP client with retry and interceptor support (v0.8.1)
- `DICOMwebConfiguration` - Configuration for DICOMweb clients (v0.8.1)
- `DICOMwebURLBuilder` - URL construction utilities (v0.8.1)
- `DICOMJSONEncoder` - DICOM JSON encoding per PS3.18 Annex F (v0.8.1)
- `DICOMJSONDecoder` - DICOM JSON decoding per PS3.18 Annex F (v0.8.1)
- `MultipartMIME` - Multipart MIME parsing and generation (v0.8.1)
- `DICOMMediaType` - Media type definitions (v0.8.1)
- `DICOMwebError` - Error types for DICOMweb operations (v0.8.1)

---

## DICOM Standard Compliance

DICOMKit implements the **DICOM Standard 2026a** published by NEMA. Below is a detailed compliance matrix:

### Supported DICOM Parts

| Part | Title | Coverage | Notes |
|------|-------|----------|-------|
| **PS3.3** | Information Object Definitions | ✅ Comprehensive | SR, GSPS, RT, Segmentation, Parametric Maps |
| **PS3.5** | Data Structures and Encoding | ✅ Full | All VRs, 7+ Transfer Syntaxes |
| **PS3.6** | Data Dictionary | ⚠️ Essential | Common tags + extensible dictionary |
| **PS3.7** | Message Exchange | ✅ Full | All DIMSE-C and DIMSE-N services |
| **PS3.8** | Network Communication | ✅ Full | Upper Layer Protocol, Presentation Contexts |
| **PS3.10** | Media Storage and File Format | ✅ Full | File Meta Information, DICOMDIR |
| **PS3.15** | Security Profiles | ✅ Good | TLS 1.2/1.3, OAuth2, Audit Logging |
| **PS3.18** | Web Services | ✅ Full | WADO-RS, QIDO-RS, STOW-RS, UPS-RS |

### Transfer Syntax Support

| Transfer Syntax UID | Name | Read | Write |
|---------------------|------|------|-------|
| 1.2.840.10008.1.2 | Implicit VR Little Endian | ✅ | ✅ |
| 1.2.840.10008.1.2.1 | Explicit VR Little Endian | ✅ | ✅ |
| 1.2.840.10008.1.2.2 | Explicit VR Big Endian | ✅ | ✅ |
| 1.2.840.10008.1.2.1.99 | Deflated Explicit VR LE | ✅ | ✅ |
| 1.2.840.10008.1.2.4.50 | JPEG Baseline (Process 1) | ✅ | ⚠️ |
| 1.2.840.10008.1.2.4.51 | JPEG Extended (Process 2 & 4) | ✅ | ⚠️ |
| 1.2.840.10008.1.2.4.57 | JPEG Lossless | ✅ | ⚠️ |
| 1.2.840.10008.1.2.4.70 | JPEG Lossless SV1 | ✅ | ⚠️ |
| 1.2.840.10008.1.2.4.90 | JPEG 2000 Lossless Only | ✅ | ⚠️ |
| 1.2.840.10008.1.2.4.91 | JPEG 2000 | ✅ | ⚠️ |
| 1.2.840.10008.1.2.5 | RLE Lossless | ✅ | ✅ |

*Note: ⚠️ indicates platform codec dependency (ImageIO framework)*

### SOP Class Support

<details>
<summary>Expand to see all supported SOP Classes</summary>

**Storage SOP Classes:**
- CT Image Storage
- MR Image Storage
- US Image Storage
- CR Image Storage
- Secondary Capture Image Storage
- Digital X-Ray Image Storage
- Digital Mammography X-Ray Image Storage
- RT Structure Set Storage
- RT Plan Storage
- RT Dose Storage
- Segmentation Storage
- Parametric Map Storage
- Grayscale Softcopy Presentation State Storage
- Encapsulated PDF Storage
- Basic Text SR, Enhanced SR, Comprehensive SR, Comprehensive 3D SR
- Key Object Selection Document
- Mammography CAD SR
- Chest CAD SR
- All Video SOP Classes (v1.6.0)
- All Waveform SOP Classes (v1.5.0)

**Query/Retrieve SOP Classes:**
- Patient Root Query/Retrieve
- Study Root Query/Retrieve
- Modality Worklist

**Other Services:**
- Verification SOP Class (C-ECHO)
- Modality Performed Procedure Step (N-CREATE, N-SET)
- Storage Commitment (planned)

</details>

All parsing behavior is documented with PS3.5 section references. We do not translate implementations from other toolkits (DCMTK, pydicom, fo-dicom) - all behavior is derived directly from the DICOM standard.

---

## Support & Community

### Getting Help

| Resource | Description | Link |
|----------|-------------|------|
| **📚 Documentation** | Comprehensive API reference and guides | [Documentation/](Documentation/) |
| **🐛 Issues** | Bug reports and feature requests | [GitHub Issues](https://github.com/Raster-Lab/DICOMKit/issues) |
| **💬 Discussions** | Questions, ideas, and community support | [GitHub Discussions](https://github.com/Raster-Lab/DICOMKit/discussions) |
| **📖 Examples** | Working code samples | [Examples/](Examples/), [Playgrounds/](Playgrounds/) |
| **📱 Demo Apps** | Production-quality applications | [DICOMViewer-macOS/](DICOMViewer-macOS/) |
| **❓ FAQ** | Frequently asked questions | [Documentation/FAQ.md](Documentation/FAQ.md) |
| **🔧 Troubleshooting** | Common issues and solutions | [Documentation/Troubleshooting.md](Documentation/Troubleshooting.md) |

### Documentation Index

| Guide | Description |
|-------|-------------|
| [iOSIntegrationGuide.md](Documentation/iOSIntegrationGuide.md) | iOS/iPadOS integration best practices |
| [macOSIntegrationGuide.md](Documentation/macOSIntegrationGuide.md) | macOS document-based apps and PACS |
| [visionOSIntegrationGuide.md](Documentation/visionOSIntegrationGuide.md) | visionOS spatial computing |
| [Architecture.md](Documentation/Architecture.md) | System design and module dependencies |
| [ConformanceStatement.md](Documentation/ConformanceStatement.md) | DICOM conformance statement |
| [PERFORMANCE_GUIDE.md](PERFORMANCE_GUIDE.md) | Performance optimization strategies |
| [INSTALLATION.md](INSTALLATION.md) | Detailed installation instructions |
| [DISTRIBUTION.md](DISTRIBUTION.md) | Distribution and deployment |

### Reporting Issues

When reporting issues:
- Use the appropriate issue template (Bug Report, Feature Request, Documentation)
- **Never include PHI (Protected Health Information)** or patient data
- Provide DICOM file metadata (Transfer Syntax, SOP Class, Modality) but not the actual file if it contains patient data
- Include platform version (iOS/macOS/visionOS) and DICOMKit version
- Search existing issues before creating a new one

### Security Vulnerabilities

For security issues, please use [GitHub Security Advisories](https://github.com/Raster-Lab/DICOMKit/security/advisories/new) for private disclosure rather than public issues.

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Quick Contribution Guide

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes with tests
4. **Run** tests (`swift test`)
5. **Commit** your changes (`git commit -m 'Add amazing feature'`)
6. **Push** to the branch (`git push origin feature/amazing-feature`)
7. **Open** a Pull Request

### Development Setup

```bash
# Clone the repository
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit

# Build the project
swift build

# Run tests
swift test

# Build CLI tools
swift build -c release

# Generate documentation
swift package generate-documentation
```

---

## License

DICOMKit is released under the **MIT License**. See [LICENSE](LICENSE) for details.

```
MIT License

Copyright (c) 2024-2026 Raster Lab

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Acknowledgments

This library implements the DICOM standard as published by the National Electrical Manufacturers Association (NEMA). DICOM® is a registered trademark of NEMA.

### Special Thanks

- **NEMA** for maintaining the DICOM standard
- **Apple** for Swift, SwiftUI, and the Apple Developer ecosystem
- All **contributors** who have helped improve DICOMKit

---

## Version History Summary

| Version | Release | Key Features |
|---------|---------|--------------|
| **v1.8.0** | Feb 2026 | UPS Task Handling Enhancements, WorkitemBuilder |
| **v1.7.0** | Feb 2026 | Secondary Capture Image IOD support |
| **v1.6.0** | Jan 2026 | DICOM Video Support (all video SOP classes) |
| **v1.5.0** | Jan 2026 | Waveform Data Support (ECG, audio, etc.) |
| **v1.4.0** | Jan 2026 | DICOM Print Management SOP |
| **v1.1.0** | Dec 2025 | Encapsulated Document support |
| **v1.0.14** | Dec 2025 | Demo apps, CLI tools Phase 7, Playgrounds |
| **v1.0.0** | Nov 2025 | Production release with comprehensive features |
| **v0.9.x** | Oct 2025 | Structured Reporting |
| **v0.8.x** | Sep 2025 | DICOMweb services |
| **v0.7.x** | Aug 2025 | DICOM Storage with TLS |
| **v0.6.x** | Jul 2025 | DICOM Query/Retrieve |
| **v0.5** | Jun 2025 | DICOM Writing |
| **v0.4** | May 2025 | Compressed Pixel Data |
| **v0.3** | Apr 2025 | Pixel Data Access |
| **v0.2** | Mar 2025 | Extended Transfer Syntaxes |
| **v0.1** | Feb 2025 | Core Infrastructure |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes and [MILESTONES.md](MILESTONES.md) for the complete development history.

---

<p align="center">
  <strong>Made with ❤️ for the medical imaging community</strong><br>
  <a href="https://github.com/Raster-Lab/DICOMKit">GitHub</a> •
  <a href="https://github.com/Raster-Lab/DICOMKit/issues">Issues</a> •
  <a href="https://github.com/Raster-Lab/DICOMKit/discussions">Discussions</a>
</p>
