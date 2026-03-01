# DICOM Studio — Feature Showcase Application Plan

## Overview

**DICOM Studio** is a comprehensive macOS GUI application designed to showcase every feature of DICOMKit. It serves as both a production-quality medical imaging tool and a living demonstration of the library's capabilities.

**Target Platforms**: macOS 14+
**UI Framework**: SwiftUI
**Language**: Swift 6.2 (Strict Concurrency)
**Dependencies**: DICOMKit, DICOMCore, DICOMDictionary, DICOMNetwork, DICOMWeb, DICOMToolbox
**Architecture**: MVVM with service layer
**Target Users**: Medical professionals, radiologists, researchers, developers, medical students

---

## Strategic Goals

### Primary Objectives
1. **Complete Feature Coverage**: Showcase every public API in DICOMKit, DICOMCore, DICOMNetwork, DICOMWeb, and DICOMDictionary
2. **Production Quality**: Deliver a polished, App Store–ready application
3. **Educational Resource**: Serve as the definitive reference implementation for DICOMKit integration
4. **macOS Excellence**: Demonstrate best practices on macOS
5. **Clinical Realism**: Validate library functionality in realistic medical imaging workflows

### Secondary Objectives
- Identify and expose API usability issues through real-world integration
- Create reusable SwiftUI components for the medical imaging community
- Demonstrate performance characteristics at scale with large DICOM datasets
- Provide accessibility and internationalization reference implementation
- Generate compelling visuals for marketing and documentation

### Success Criteria
- [ ] All DICOMKit public APIs exercised in at least one feature
- [ ] 95% unit test coverage across all ViewModels
- [ ] Efficient memory usage for typical studies on macOS
- [ ] 60fps scrolling and gesture response on macOS
- [ ] Full VoiceOver and Dynamic Type support
- [ ] Localization for English, Spanish, French, German, Japanese, Chinese (Simplified), Korean, Portuguese (Brazil), Arabic, Hebrew
- [ ] Zero critical bugs at each milestone release

---

## Milestone Summary

| Milestone | Title | Scope | Est. Duration | Tests |
|-----------|-------|-------|---------------|-------|
| 1 | Project Foundation & Core Architecture | Project setup, navigation, theming | 2 weeks | 203 |
| 2 | DICOM File Browser & Library | Import, browse, search, metadata | 2 weeks | 483 |
| 3 | Image Viewer Foundation | Rendering, window/level, cine, gestures | 2 weeks | 670 |
| 4 | Presentation States & Hanging Protocols | GSPS, annotations, shutters, layouts | 2 weeks | 75+ |
| 5 | Measurements & Annotations | Length, angle, ROI, statistics, drawing | 2 weeks | 70+ |
| 6 | 3D Visualization & MPR | MPR, MIP, volume rendering, surface | 3 weeks | 85+ |
| 7 | Structured Reporting Studio | SR viewer, SR builder, coded terms, CAD | 2 weeks | 90+ |
| 8 | Specialized Modality Support | RT, segmentation, waveforms, video, documents | 3 weeks | 100+ |
| 9 | DICOM Networking Hub | C-ECHO/FIND/MOVE/GET/STORE, MWL, MPPS, print | 3 weeks | 95+ |
| 10 | DICOMweb Integration | QIDO-RS, WADO-RS, STOW-RS, UPS-RS, OAuth2 | 2 weeks | 80+ |
| 11 | Security & Privacy Center | TLS, anonymization, audit logs, certificates | 2 weeks | 65+ |
| 12 | Data Exchange & Export | JSON, XML, image export, PDF, DICOMDIR | 2 weeks | 70+ |
| 13 | Performance & Developer Tools | Benchmarks, cache management, tag explorer | 2 weeks | 60+ |
| 14 | macOS-Specific Enhancements | macOS multi-window, keyboard shortcuts, automation | 2 weeks | 80+ |
| 15 | Polish, Accessibility & Release | i18n, a11y, UI tests, profiling, App Store | 2 weeks | 100+ |
| 16 | CLI Tools Workshop | Interactive GUI for all 29 CLI tools, command builder, console | 3 weeks | 120+ |
| **Total** | | | **37 weeks** | **1,320+** |

---

## Milestone 1: Project Foundation & Core Architecture

**Status**: Completed
**Goal**: Establish the macOS project structure, navigation framework, and shared infrastructure
**DICOMKit Features Showcased**: Project integration, Swift Package Manager setup

### Deliverables

#### 1.1 Project Setup
- [x] Create macOS SwiftUI project
- [x] Configure DICOMKit dependency via Swift Package Manager
- [x] Set up build configurations (Debug, Release, TestFlight)
- [x] Configure Info.plist with required permissions
- [x] Add `.gitignore` for Xcode-specific files
- [x] Set up CI/CD pipeline (GitHub Actions) for build + test

#### 1.2 Application Architecture
- [x] Define MVVM architecture with `@Observable` ViewModels
- [x] Create shared service layer:
  - [x] `DICOMFileService` — File I/O operations via DICOMKit
  - [x] `ThumbnailService` — Thumbnail generation and caching
  - [x] `StorageService` — Local storage management
  - [x] `SettingsService` — User preferences and configuration
  - [x] `NavigationService` — App-wide routing and deep linking
- [x] Create shared data models:
  - [x] `StudyModel` — Study-level metadata
  - [x] `SeriesModel` — Series-level metadata
  - [x] `InstanceModel` — Instance-level metadata
  - [x] `LibraryModel` — Local file database

#### 1.3 Navigation & Shell
- [x] Implement sidebar/tab-based navigation for feature areas:
  - [x] Library (file browser)
  - [x] Viewer (image display)
  - [x] Networking (DICOM/DICOMweb)
  - [x] Reporting (structured reports)
  - [x] Tools (data exchange, developer tools)
  - [x] CLI Workshop (interactive GUI for all 29 CLI tools)
  - [x] Settings (configuration)
- [x] macOS: NavigationSplitView with sidebar, detail, and inspector

#### 1.4 Theming & Appearance
- [x] Implement light/dark mode support
- [x] Create medical imaging color palette (radiology-appropriate)
- [x] Define typography scale using Dynamic Type
- [x] Support Increased Contrast accessibility setting
- [x] Create reusable UI components library:
  - [x] `DICOMTagView` — Displays a DICOM tag with group/element
  - [x] `VRBadge` — Shows Value Representation type
  - [x] `ModalityIcon` — Modality-specific SF Symbol icons
  - [x] `StatusIndicator` — Connection/transfer status

#### 1.5 Settings Infrastructure
- [x] User preferences storage (UserDefaults + SwiftData)
- [x] General settings (appearance, default window presets)
- [x] Privacy settings (anonymization defaults, audit logging)
- [x] Performance settings (cache size, memory limits, threading)
- [x] About screen with DICOMKit version, licenses, acknowledgments

### Technical Notes
- Use Swift 6.2 strict concurrency for all ViewModels and services
- Leverage `@Observable` macro (macOS 14+) over `ObservableObject`
- Use dependency injection for testability

### Acceptance Criteria
- [x] Project builds on macOS without warnings
- [x] Navigation shell renders correctly on macOS
- [x] Settings persist across app launches
- [x] CI pipeline passes for macOS
- [x] Architecture documented in ARCHITECTURE.md
- [x] Test coverage exceeds 95% for Models, Services, and ViewModels (203 tests)

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 2: DICOM File Browser & Library

**Status**: Completed
**Goal**: Implement DICOM file import, study/series browsing, metadata display, and local library management
**DICOMKit Features Showcased**: `DICOMFile` parsing, `DataSet` access, `Tag`/`VR`/`DataElement` types, value parsers (DA, TM, DT, PN, CS, UI, AE), Transfer Syntax detection, character set support, private tag handling

### Deliverables

#### 2.1 File Import
- [x] SwiftUI document picker integration (`.fileImporter`)
- [x] Drag-and-drop import support (macOS)
- [x] Batch import with progress tracking
- [x] DICOM file validation during import:
  - [x] Preamble and DICM prefix verification
  - [x] File Meta Information parsing
  - [x] Required tag validation (SOP Class UID, Instance UID)
  - [x] Transfer Syntax support check
- [x] Import from Files app, iCloud Drive, email attachments, AirDrop
- [x] DICOMDIR import for CD/DVD media

#### 2.2 Study Browser
- [x] Patient → Study → Series → Instance hierarchy display
- [x] Grid view and list view toggle
- [x] Thumbnail generation with `ThumbnailService`:
  - [x] Pixel data extraction via DICOMKit
  - [x] Basic windowing applied for visibility
  - [x] Background generation to avoid UI blocking
  - [x] Disk caching for performance
- [x] Sort by date, patient name, modality, study description
- [x] Filter by modality, date range, patient name
- [x] Full-text search across all metadata fields
- [x] Study count, series count, and instance count badges
- [x] Swipe actions: delete, share, favorite

#### 2.3 Metadata Viewer
- [x] Complete DICOM tag browser for any loaded file:
  - [x] Display all data elements with tag, VR, length, value
  - [x] Nested sequence (SQ) expansion with tree view
  - [x] Value parser integration showing parsed representations:
    - [x] `DICOMDate` (DA) → formatted date
    - [x] `DICOMTime` (TM) → formatted time
    - [x] `DICOMDateTime` (DT) → formatted date-time
    - [x] `DICOMAgeString` (AS) → human-readable age
    - [x] `DICOMPersonName` (PN) → structured name components
    - [x] `DICOMDecimalString` (DS) → numeric values
    - [x] `DICOMIntegerString` (IS) → integer values
    - [x] `DICOMCodeString` (CS) → enumerated values
    - [x] `DICOMUniqueIdentifier` (UI) → UID with lookup
    - [x] `DICOMApplicationEntity` (AE) → AE title
    - [x] `DICOMUniversalResourceIdentifier` (UR) → clickable URL
  - [x] Private tag display with vendor identification (Siemens, GE, Philips)
  - [x] Tag search by name, group, or keyword
  - [x] Copy tag value to clipboard
- [x] Character set display with international text rendering (18 repertoires)
- [x] Transfer syntax information panel
- [x] File Meta Information summary

#### 2.4 Local Library Storage
- [x] JSON-backed study database (portable, cross-platform)
- [x] Efficient queries for study listing, filtering, sorting
- [x] Storage usage monitoring and cleanup tools
- [x] Duplicate detection during import
- [x] Library export and backup

### Technical Notes
- Use `DICOMFile.read(from:)` for file parsing
- Access data elements via `DataSet` subscript and value parsers
- Use `DICOMDictionary` for tag name resolution
- Support all 31 Value Representations for display
- Reference: DICOM PS3.3 (IOD definitions), PS3.5 (Data Structures), PS3.10 (Media Storage)

### Acceptance Criteria
- [x] Import single and batch DICOM files successfully
- [x] Study/series hierarchy displays correctly
- [x] All value parsers render correctly in metadata viewer
- [x] Private tags display with vendor identification
- [x] International character sets render correctly
- [x] Search and filter perform within 100ms for 10,000+ files
- [x] Memory usage stays <100MB during import of 500 files

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 3: Image Viewer Foundation

**Status**: Completed
**Goal**: Implement core medical image viewing with rendering, windowing, multi-frame playback, and gesture controls
**DICOMKit Features Showcased**: `CGImage` rendering, `WindowSettings`, `PixelData`/`PixelDataDescriptor`, photometric interpretations (MONOCHROME1/2, RGB, PALETTE COLOR, YBR_FULL), multi-frame support, SIMD-accelerated windowing, lazy pixel data loading, image caching

### Deliverables

#### 3.1 Image Rendering
- [x] Render DICOM pixel data to `CGImage` via DICOMKit:
  - [x] Uncompressed pixel data (all bit depths: 1-bit to 32-bit)
  - [x] JPEG Baseline/Extended/Lossless compressed data
  - [x] JPEG 2000 compressed data
  - [x] JPEG-LS compressed data
  - [x] RLE compressed data
- [x] Support all photometric interpretations:
  - [x] MONOCHROME1 (inverted grayscale)
  - [x] MONOCHROME2 (standard grayscale)
  - [x] RGB (color)
  - [x] PALETTE COLOR (lookup table)
  - [x] YBR_FULL / YBR_FULL_422 / YBR_PARTIAL_422
- [x] Display pixel data metadata overlay:
  - [x] Rows × Columns
  - [x] Bits Allocated / Bits Stored / High Bit
  - [x] Pixel Representation (signed/unsigned)
  - [x] Samples Per Pixel / Planar Configuration

#### 3.2 Window/Level Controls
- [x] Interactive window/level adjustment via drag gesture
- [x] Window Center/Width numeric input fields
- [x] Preset window settings for common modalities:
  - [x] CT: Abdomen, Bone, Brain, Chest, Lung, Liver, Mediastinum, Stroke
  - [x] MR: T1, T2, FLAIR defaults
  - [x] Custom user-defined presets
- [x] Real-time window/level update with SIMD acceleration (via Accelerate framework)
- [x] Auto window/level from DICOM header values
- [x] VOI LUT support (linear, sigmoid, table lookup)
- [x] Grayscale inversion toggle

#### 3.3 Multi-Frame & Cine Playback
- [x] Frame navigation with slider/scrubber control
- [x] Frame number display (current / total)
- [x] Cine playback with configurable frame rate (1–60 fps)
- [x] Play/Pause/Stop controls
- [x] Loop and bounce playback modes
- [x] Frame-by-frame stepping (forward/backward)
- [x] Lazy pixel data loading for large multi-frame files (`LazyPixelDataLoader`)
- [x] Memory-mapped file access for files >100MB

#### 3.4 Gesture Controls
- [x] Pinch-to-zoom with smooth interpolation
- [x] Pan gesture with momentum
- [x] Double-tap to fit/actual size toggle
- [x] Two-finger rotation (macOS trackpad)
- [x] Scroll wheel zoom (macOS)
- [x] Keyboard shortcuts (macOS):
  - [x] Arrow keys for frame navigation
  - [x] `+`/`-` for zoom
  - [x] `R` for reset
  - [x] `I` for invert
  - [x] Space for play/pause
#### 3.5 Image Caching & Performance
- [x] LRU image cache with configurable memory limit
- [x] Metadata-only parsing mode for fast browsing (2–10× faster)
- [x] Background prefetching of adjacent frames
- [x] Streaming parser for large files
- [x] Performance overlay showing render time, cache hit rate, memory usage

### Technical Notes
- Use `DICOMFile.renderFrame(_:window:)` and `renderFrameWithStoredWindow(_:)` for rendering
- Use `PixelDataDescriptor` to determine rendering parameters
- Use `WindowSettings` for VOI LUT transforms
- SIMD acceleration via Accelerate framework for real-time windowing
- Memory-mapped access via `LazyPixelDataLoader` for large files
- Reference: DICOM PS3.3 C.7.6.3 (Image Pixel Module), PS3.3 C.11 (VOI LUT)

### Acceptance Criteria
- [x] All transfer syntaxes render correctly
- [x] All photometric interpretations display correctly
- [x] Window/level adjusts in real-time (<16ms per frame)
- [x] Cine playback maintains 60fps for standard multi-frame
- [x] Memory usage <200MB for 500-frame multi-frame file
- [x] Zoom/pan/rotate gestures feel natural on macOS
- [x] Image cache reduces repeat-render time by >90%

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 4: Presentation States & Hanging Protocols

**Status**: Planned
**Goal**: Implement DICOM Presentation State rendering and hanging protocol–driven layouts
**DICOMKit Features Showcased**: Grayscale Softcopy Presentation State (GSPS), Color Presentation State, Pseudo-Color Presentation State, Blending Presentation State, annotations, shutters, ICC color profiles, `HangingProtocol`, display protocol matching, layout specification

### Deliverables

#### 4.1 Grayscale Softcopy Presentation State (GSPS)
- [ ] Load and apply GSPS to referenced images:
  - [ ] VOI LUT transformation (window/level override)
  - [ ] Modality LUT transformation
  - [ ] Presentation LUT (IDENTITY, INVERSE)
  - [ ] Spatial transformation (rotation, flip)
  - [ ] Graphic annotations (text, polyline, circle, ellipse, point)
  - [ ] Text annotations with anchor points
  - [ ] Displayed area selection (zoom/pan override)
- [ ] GSPS creation and editing
- [ ] Multiple GSPS per image with selection UI

#### 4.2 Color & Pseudo-Color Presentation States
- [ ] Color Softcopy Presentation State rendering
- [ ] Pseudo-Color Presentation State:
  - [ ] Color lookup table application
  - [ ] Standard pseudo-color palettes (hot iron, rainbow, etc.)
- [ ] ICC Color Profile management:
  - [ ] Profile loading and application
  - [ ] HDR/EDR display support
  - [ ] Monitor calibration profile handling

#### 4.3 Blending Presentation State
- [ ] Blending of multiple image sets:
  - [ ] Alpha blending with configurable opacity
  - [ ] PET/CT fusion display
  - [ ] Registered image overlay
- [ ] Blending parameter controls (opacity slider, color maps)

#### 4.4 Shutter Display
- [ ] Rectangular shutter
- [ ] Circular shutter
- [ ] Polygonal shutter
- [ ] Bitmap shutter
- [ ] Shutter color configuration
- [ ] Multiple simultaneous shutters

#### 4.5 Hanging Protocols
- [ ] Hanging protocol matching engine:
  - [ ] Match by modality, body part, procedure
  - [ ] Match by study description, series description
  - [ ] Priority-based protocol selection
- [ ] Layout specification:
  - [ ] Single viewport
  - [ ] 2×1, 1×2, 2×2, 3×2, 3×3 grid layouts
  - [ ] Custom grid configurations
  - [ ] Comparison layouts (prior/current)
- [ ] Image selection criteria:
  - [ ] Series-level selection (by modality, description)
  - [ ] Instance-level selection (by image position, number)
  - [ ] Sorting rules (by instance number, position)
- [ ] User-defined hanging protocol editor
- [ ] Protocol persistence and sharing

#### 4.6 Multi-Viewport Display
- [ ] Synchronized scrolling across viewports
- [ ] Synchronized window/level across viewports
- [ ] Cross-reference lines between viewports
- [ ] Viewport-specific controls (independent zoom, W/L)
- [ ] Active viewport indicator with keyboard focus

### Technical Notes
- Use `PresentationState` types from DICOMKit for GSPS/Color/Pseudo-Color/Blending
- Use `HangingProtocol` for display protocol matching and layout
- ICC profiles handled via DICOMKit's color management APIs
- Reference: DICOM PS3.3 C.11.1 (GSPS), PS3.3 C.11.9-11 (Color/Pseudo-Color/Blending), PS3.3 C.11.6 (Hanging Protocol)

### Acceptance Criteria
- [ ] GSPS annotations render accurately on referenced images
- [ ] All four presentation state types apply correctly
- [ ] Shutters mask the correct image regions
- [ ] Hanging protocols auto-select correct layout for known study types
- [ ] Multi-viewport sync maintains <16ms latency
- [ ] ICC profiles apply without visible color banding

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 5: Measurements & Annotations

**Status**: Planned
**Goal**: Implement interactive measurement tools and annotation drawing on DICOM images
**DICOMKit Features Showcased**: Spatial coordinates (2D points, polylines, circles, ellipses, polygons), measurement values with UCUM units, ROI statistics, annotation persistence in Structured Reports

### Deliverables

#### 5.1 Linear Measurements
- [ ] Length measurement tool (line segment):
  - [ ] Click-drag to define start and end points
  - [ ] Real-time distance display in mm (from Pixel Spacing)
  - [ ] Calibration from DICOM header or manual override
- [ ] Angle measurement tool:
  - [ ] Three-point angle definition
  - [ ] Cobb angle measurement
  - [ ] Display in degrees
- [ ] Bi-directional measurement (long axis + perpendicular short axis)

#### 5.2 Area & ROI Measurements
- [ ] Elliptical ROI:
  - [ ] Draw ellipse on image
  - [ ] Calculate area (mm²)
  - [ ] Compute statistics: mean, std dev, min, max HU/signal
- [ ] Rectangular ROI with statistics
- [ ] Freehand ROI drawing:
  - [ ] Pencil-style freehand contour
  - [ ] Area and perimeter calculation
  - [ ] Interior pixel statistics
- [ ] Polygonal ROI (click to place vertices, close to complete)
- [ ] Circular ROI (center + radius)

#### 5.3 Annotations
- [ ] Text annotation with customizable font/size/color
- [ ] Arrow annotation (start point → end point with arrowhead)
- [ ] Marker/crosshair placement
- [ ] Annotation styling (line width, color, opacity)
- [ ] Annotation visibility toggle
- [ ] Annotation layer management (reorder, group, lock)

#### 5.4 Measurement Persistence
- [ ] Save measurements as DICOM SR (Comprehensive SR with spatial coordinates)
- [ ] Export measurements to CSV/JSON
- [ ] Load and display previously saved measurements
- [ ] Measurement history with undo/redo support

#### 5.5 Calibration & Accuracy
- [ ] Pixel Spacing from DICOM header (automatic)
- [ ] Imager Pixel Spacing for magnification correction
- [ ] Manual calibration tool (known distance reference)
- [ ] Calibration indicator in measurement display
- [ ] Unit display (mm, cm, in) with locale-aware formatting

### Technical Notes
- Use DICOMKit's spatial coordinate types (POINT, POLYLINE, CIRCLE, ELLIPSE, POLYGON)
- Use UCUM (Unified Code for Units of Measure) for measurement units
- Measurements stored as DICOM SR using `ComprehensiveSRBuilder`
- Pixel-to-physical coordinate transformation from Pixel Spacing (0028,0030)
- Reference: DICOM PS3.3 C.18.6 (Spatial Coordinates), PS3.16 TID 1500 (Measurement Report)

### Acceptance Criteria
- [ ] Length measurements accurate to ±0.5mm against known phantoms
- [ ] ROI statistics match reference implementation values
- [ ] Measurements persist and reload correctly from SR
- [ ] All annotation types render and interact correctly
- [ ] Undo/redo works for all measurement operations
- [ ] Touch and mouse input handled appropriately

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 6: 3D Visualization & Multi-Planar Reconstruction

**Status**: Planned
**Goal**: Implement MPR, MIP projections, and volume rendering for cross-sectional datasets
**DICOMKit Features Showcased**: MPR reconstruction (axial, sagittal, coronal), MIP/MinIP/AverageIP projections, volume rendering, surface extraction, Image Position/Orientation Patient handling, 3D spatial coordinates

### Deliverables

#### 6.1 Multi-Planar Reconstruction (MPR)
- [ ] Axial, sagittal, and coronal plane reconstruction
- [ ] Oblique plane reconstruction (arbitrary angle)
- [ ] Crosshair cursor linked across all three planes
- [ ] Slice thickness control (single slice to thick slab)
- [ ] Real-time scrolling through reconstructed planes
- [ ] Image Position (Patient) and Image Orientation (Patient) handling
- [ ] Interpolation quality settings (nearest neighbor, bilinear, bicubic)

#### 6.2 Projection Modes
- [ ] Maximum Intensity Projection (MIP):
  - [ ] Slab thickness control
  - [ ] Rotation around arbitrary axis
  - [ ] CT angiography visualization
- [ ] Minimum Intensity Projection (MinIP):
  - [ ] Airway and low-density structure visualization
- [ ] Average Intensity Projection (AvgIP):
  - [ ] Noise reduction for subtle findings
- [ ] Projection thickness/range controls
- [ ] Real-time update during parameter adjustment

#### 6.3 Volume Rendering
- [ ] Transfer function editor:
  - [ ] Opacity curve per HU value
  - [ ] Color mapping per HU value
  - [ ] Preset transfer functions (bone, skin, muscle, vascular)
- [ ] 3D rotation with trackball interaction
- [ ] Zoom and clip plane controls
- [ ] Lighting and shading model (Phong)
- [ ] GPU-accelerated rendering (Metal)

#### 6.4 Surface Extraction
- [ ] Isosurface extraction (marching cubes)
- [ ] Surface rendering with configurable threshold
- [ ] STL/OBJ export for 3D printing
- [ ] Surface color and opacity controls
- [ ] Multiple simultaneous surfaces (e.g., bone + skin)

#### 6.5 3D Cursor & Linkage
- [ ] 3D crosshair position synchronized across MPR views
- [ ] Click-to-navigate in any plane
- [ ] 3D spatial coordinate display (x, y, z in mm)
- [ ] Reference line display between orthogonal planes

### Technical Notes
- Use DICOMKit's MPR reconstruction APIs
- Metal shaders for GPU-accelerated volume rendering
- Accelerate framework for projection computations (SIMD)
- Reference: DICOM PS3.3 C.7.6.2 (Image Plane Module), PS3.3 C.18.9 (3D Spatial Coordinates)

### Acceptance Criteria
- [ ] MPR planes reconstruct correctly from volumetric data
- [ ] Crosshair synchronization across planes with <16ms latency
- [ ] MIP/MinIP/AvgIP projections match reference implementations
- [ ] Volume rendering maintains >30fps on Apple Silicon
- [ ] Surface extraction produces watertight meshes for 3D printing

### Estimated Effort
**3 weeks** (1 developer)

---

## Milestone 7: Structured Reporting Studio

**Status**: Planned
**Goal**: Implement a comprehensive SR viewer and builder showcasing all 8 SR document types and coded terminology
**DICOMKit Features Showcased**: All 8 SR builders (Basic Text, Enhanced, Comprehensive, Comprehensive 3D, Measurement Report, Key Object Selection, Mammography CAD, Chest CAD), 15 content item value types, coded concepts, relationship types, SNOMED CT/LOINC/RadLex/UCUM terminology

### Deliverables

#### 7.1 SR Document Viewer
- [ ] Hierarchical tree display of SR content:
  - [ ] Container items with relationship types (CONTAINS, HAS OBS CONTEXT, etc.)
  - [ ] Text content items
  - [ ] Code content items (with terminology lookup)
  - [ ] Numeric measurement items (with UCUM units)
  - [ ] Date/Time/DateTime content items
  - [ ] Person Name content items
  - [ ] UID reference items
  - [ ] Spatial coordinate items (2D and 3D)
  - [ ] Temporal coordinate items
  - [ ] Composite/Image/Waveform reference items
- [ ] Inline rendering of referenced images at spatial coordinates
- [ ] Coded concept display with terminology source (SNOMED, LOINC, RadLex)
- [ ] Expand/collapse all tree nodes
- [ ] Search within SR content

#### 7.2 SR Document Builder
- [ ] **Basic Text SR Builder**:
  - [ ] Free-text narrative reports
  - [ ] Hierarchical sections (Findings, Impression, Recommendations)
  - [ ] Template selection for common report types
- [ ] **Enhanced SR Builder**:
  - [ ] Numeric measurements with UCUM units
  - [ ] Coded findings with terminology picker
  - [ ] Referenced images
- [ ] **Comprehensive SR Builder**:
  - [ ] 2D spatial coordinates (points, polylines, circles, ellipses, polygons)
  - [ ] Measurements linked to image regions
  - [ ] Multiple content item types
- [ ] **Comprehensive 3D SR Builder**:
  - [ ] 3D spatial coordinates for volumetric measurements
  - [ ] Cross-sectional reference frames
  - [ ] Volumetric ROI definitions
- [ ] **Measurement Report Builder** (TID 1500):
  - [ ] Imaging measurements with tracking identifiers
  - [ ] RECIST/WHO lesion tracking
  - [ ] Time-point comparison (baseline → follow-up)
  - [ ] Quantitative imaging biomarkers
- [ ] **Key Object Selection Builder**:
  - [ ] Flag significant images from a study
  - [ ] Purpose categories: teaching, quality control, referral, conference
  - [ ] Key image description and reason
- [ ] **Mammography CAD SR Builder**:
  - [ ] Mass detection findings
  - [ ] Calcification cluster findings
  - [ ] Architectural distortion findings
  - [ ] BI-RADS assessment categories
- [ ] **Chest CAD SR Builder**:
  - [ ] Nodule detection findings
  - [ ] Mass detection findings
  - [ ] Consolidation and lesion findings
  - [ ] Finding location and confidence

#### 7.3 Coded Terminology Browser
- [ ] SNOMED CT concept search and browse
- [ ] LOINC observation code search
- [ ] RadLex radiology lexicon search
- [ ] UCUM unit lookup and conversion
- [ ] Cross-terminology mapping display
- [ ] Recently used terms quick-access list
- [ ] Favorites for frequently used codes

#### 7.4 CAD Findings Visualization
- [ ] Overlay CAD marks on referenced images
- [ ] Color-coded findings by type (mass, calcification, nodule)
- [ ] Confidence score display
- [ ] Finding detail panel with coded attributes
- [ ] Accept/reject CAD finding workflow

### Technical Notes
- Use all 8 SR builder types from DICOMKit
- Use `CodedConcept` for terminology integration
- Use `ContentItem` hierarchy for SR tree display
- Reference: DICOM PS3.3 C.17 (SR Document), PS3.16 (Content Mapping Resources)

### Acceptance Criteria
- [ ] All 8 SR document types create valid DICOM SR files
- [ ] SR viewer correctly renders all 15 content item value types
- [ ] Coded terminology search returns results within 200ms
- [ ] CAD findings overlay accurately on referenced images
- [ ] Round-trip: create SR → save → reload → display matches original

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 8: Specialized Modality Support

**Status**: Planned
**Goal**: Implement viewers and tools for specialized DICOM modalities beyond standard imaging
**DICOMKit Features Showcased**: RT Structure Sets (contours, ROIs), RT Plans (beams, fractions), RT Dose (DVH), segmentation (binary/fractional masks), parametric maps (T1, T2, ADC, SUV), Real-World Value LUTs, waveforms (ECG, hemodynamic), video (MPEG2, H.264, H.265), secondary capture, encapsulated documents (PDF, CDA, STL, OBJ, MTL), whole-slide imaging

### Deliverables

#### 8.1 Radiation Therapy Visualization
- [ ] **RT Structure Set Viewer**:
  - [ ] Contour overlay on CT/MR images
  - [ ] ROI display with per-structure color coding
  - [ ] Structure list with visibility toggles
  - [ ] ROI type labels (PTV, CTV, GTV, OAR)
  - [ ] Clinical interpretation display
- [ ] **RT Plan Viewer**:
  - [ ] Beam geometry visualization
  - [ ] Fraction group display
  - [ ] Dose reference points
  - [ ] Beam parameters (energy, gantry angle, collimator)
- [ ] **RT Dose Viewer**:
  - [ ] Dose distribution overlay (color wash)
  - [ ] Isodose line display with configurable levels
  - [ ] Dose-Volume Histogram (DVH) charts
  - [ ] Point dose readout

#### 8.2 Segmentation Overlay
- [ ] Binary segmentation mask display
- [ ] Fractional segmentation with opacity
- [ ] Color-coded segment labels
- [ ] Segment visibility toggles
- [ ] Segment list with properties (algorithm, category)
- [ ] Overlay opacity control

#### 8.3 Parametric Map Viewer
- [ ] Parametric map display with colormaps:
  - [ ] T1 mapping (ms)
  - [ ] T2 mapping (ms)
  - [ ] ADC mapping (mm²/s)
  - [ ] Perfusion maps (ml/100g/min)
  - [ ] SUV maps (g/ml)
- [ ] Color scale legend with min/max values
- [ ] Real-World Value LUT application
- [ ] SUV calculator (using patient weight, injection time, dose)
- [ ] Colormap selection (jet, viridis, hot, cool, gray)
- [ ] ROI-based parametric statistics

#### 8.4 Waveform Viewer
- [ ] ECG waveform display (12-lead):
  - [ ] Standard lead arrangement
  - [ ] Gain/speed controls (mm/mV, mm/s)
  - [ ] Grid overlay (standard ECG paper)
  - [ ] Caliper measurement tool
- [ ] Hemodynamic waveform display
- [ ] Support for 9 waveform SOP classes
- [ ] Multi-channel display with label identification
- [ ] Time-synchronized playback with image viewer

#### 8.5 Video Playback
- [ ] DICOM video playback:
  - [ ] MPEG2 video
  - [ ] H.264 (MPEG-4 AVC)
  - [ ] H.265 (HEVC)
- [ ] Standard video controls (play, pause, seek, speed)
- [ ] Frame-accurate navigation
- [ ] Screenshot/frame extraction

#### 8.6 Encapsulated Document Viewer
- [ ] PDF document display (native viewer integration)
- [ ] CDA (Clinical Document Architecture) rendering
- [ ] 3D model viewer for STL/OBJ/MTL files:
  - [ ] 3D rotation/zoom controls
  - [ ] Surface color and lighting
- [ ] Document metadata display

#### 8.7 Secondary Capture Display
- [ ] Display all 5 Secondary Capture SOP classes
- [ ] Appropriate rendering based on capture type
- [ ] Metadata overlay with capture context

#### 8.8 Whole-Slide Imaging
- [ ] Multi-resolution tile-based viewing
- [ ] Smooth zoom across magnification levels
- [ ] Optical path color rendering
- [ ] Annotation overlay on WSI

### Technical Notes
- Use DICOMKit's RT, Segmentation, Parametric Map, Waveform, and Video modules
- Use `RealWorldValueLUT` for physical quantity mapping
- Use `SUVCalculator` for PET standardized uptake values
- Metal for GPU-accelerated parametric map rendering
- AVFoundation for video playback
- SceneKit/RealityKit for 3D model display
- Reference: DICOM PS3.3 C.8.8 (RT), C.8.20 (Segmentation), C.7.6.16 (Real World Value), C.10 (Waveform)

### Acceptance Criteria
- [ ] RT structures overlay accurately on referenced CT images
- [ ] DVH chart matches reference values
- [ ] Segmentation masks align with underlying image pixels
- [ ] Parametric maps apply correct color mapping with accurate values
- [ ] ECG waveforms display with correct gain and speed
- [ ] Video plays smoothly for all three codec types
- [ ] Encapsulated PDF opens correctly
- [ ] 3D models render and rotate smoothly

### Estimated Effort
**3 weeks** (1 developer)

---

## Milestone 9: DICOM Networking Hub

**Status**: Planned
**Goal**: Implement a full DICOM networking interface for server connectivity, query/retrieve, storage, and print management
**DICOMKit Features Showcased**: `DICOMClient`, C-ECHO, C-FIND, C-MOVE, C-GET, C-STORE, Modality Worklist (MWL), MPPS, Print Management (N-CREATE/SET/GET/DELETE), TLS (1.2/1.3), mTLS, certificate pinning, connection pooling, circuit breaker, bandwidth limiting, retry policies, batch operations, progress tracking, pre-send validation, HIPAA audit logging

### Deliverables

#### 9.1 Server Configuration Manager
- [ ] PACS server profile management:
  - [ ] Server name, hostname, port, AE Title
  - [ ] Local AE Title configuration
  - [ ] TLS/SSL settings (TLS 1.2, TLS 1.3, mTLS)
  - [ ] Certificate management (import, pin, trust)
  - [ ] Self-signed certificate support
- [ ] Multiple server profiles with quick switching
- [ ] Connection testing with C-ECHO
- [ ] Server status indicator (online/offline/error)
- [ ] Import/export server configurations

#### 9.2 C-ECHO (Verification)
- [ ] One-tap connectivity test to any configured server
- [ ] Response time display (latency in ms)
- [ ] Detailed error reporting for failed connections
- [ ] Connection history log
- [ ] Batch echo to test all configured servers

#### 9.3 C-FIND (Query)
- [ ] Query builder with level selection:
  - [ ] Patient-level query
  - [ ] Study-level query
  - [ ] Series-level query
  - [ ] Instance-level query
- [ ] Query fields:
  - [ ] Patient Name, Patient ID
  - [ ] Study Date (range), Study Description
  - [ ] Modality, Accession Number
  - [ ] Series Description, Series Number
- [ ] Wildcard support (`*`, `?`)
- [ ] Query result display in paginated table
- [ ] Drill-down from study → series → instance
- [ ] Saved query templates for repeated searches
- [ ] Query history with re-execute

#### 9.4 C-MOVE / C-GET (Retrieve)
- [ ] Retrieve study/series/instance from query results
- [ ] C-MOVE with move destination configuration
- [ ] C-GET for direct retrieval
- [ ] Download progress with percentage and speed
- [ ] Transfer queue management:
  - [ ] Queue display with priority ordering
  - [ ] Pause/resume individual transfers
  - [ ] Cancel transfer
  - [ ] Retry failed transfers
- [ ] Bandwidth limiting controls
- [ ] Auto-import retrieved files to local library

#### 9.5 C-STORE (Send)
- [ ] Send files from local library to remote server
- [ ] Pre-send validation (4 validation levels, 7 IODs)
- [ ] Batch send with progress tracking
- [ ] Send queue management
- [ ] Transfer status (pending, sending, completed, failed)
- [ ] Retry policy configuration (max retries, backoff)
- [ ] Circuit breaker display (open/closed/half-open state)

#### 9.6 Modality Worklist (MWL)
- [ ] Query worklist from configured server
- [ ] Display scheduled procedures:
  - [ ] Patient demographics
  - [ ] Scheduled procedure step
  - [ ] Requested procedure
  - [ ] Referring physician
- [ ] Filter by date, modality, station
- [ ] Refresh with configurable interval
- [ ] Auto-populate study data from worklist

#### 9.7 Modality Performed Procedure Step (MPPS)
- [ ] Create MPPS (N-CREATE) for procedure tracking
- [ ] Update MPPS status (N-SET):
  - [ ] In Progress → Completed
  - [ ] In Progress → Discontinued
- [ ] Display performed procedure attributes
- [ ] Dose and exposure information tracking

#### 9.8 Print Management
- [ ] DICOM Print service connection
- [ ] Film Session creation and configuration:
  - [ ] Number of copies
  - [ ] Print priority
  - [ ] Medium type (paper, film)
- [ ] Film Box layout configuration:
  - [ ] Standard formats (STANDARD\1,1 through STANDARD\4,5)
  - [ ] Custom layouts
- [ ] Image Box placement and configuration:
  - [ ] Image selection from viewer
  - [ ] Magnification type
  - [ ] Polarity (normal/reverse)
- [ ] Print preview before sending
- [ ] Print queue management
- [ ] Multiple printer support with status display

#### 9.9 Network Monitoring
- [ ] Connection pool status display
- [ ] Active association count
- [ ] Transfer throughput graph (bytes/sec)
- [ ] HIPAA audit log viewer:
  - [ ] All network operations logged
  - [ ] Searchable log entries
  - [ ] Export audit log
- [ ] Error categorization (transient, permanent, timeout)
- [ ] Recovery suggestions for errors

### Technical Notes
- Use `DICOMClient` for all DICOM networking operations
- Use `ConnectionPool` for connection management
- Use `CircuitBreaker` for fault tolerance
- Use `AuditLogger` for HIPAA-compliant logging
- TLS configuration via DICOMNetwork's TLS API
- Pre-send validation via DICOMNetwork's validation API
- Reference: DICOM PS3.4 (Service Class Specifications), PS3.7 (Message Exchange), PS3.8 (Network Communication), PS3.15 (Security and System Management), PS3.4 Annex H (Print Management)

### Acceptance Criteria
- [ ] C-ECHO succeeds against Orthanc/dcm4chee test servers
- [ ] C-FIND returns correct results for all query levels
- [ ] C-MOVE/C-GET retrieves complete studies without data loss
- [ ] C-STORE sends validated files successfully
- [ ] TLS connections negotiate correctly
- [ ] Transfer queue handles concurrent operations
- [ ] Audit log captures all network events
- [ ] Print preview matches final output

### Estimated Effort
**3 weeks** (1 developer)

---

## Milestone 10: DICOMweb Integration

**Status**: Planned
**Goal**: Implement a RESTful DICOMweb client interface for modern cloud-based PACS integration
**DICOMKit Features Showcased**: QIDO-RS, WADO-RS, STOW-RS, UPS-RS, OAuth2 (PKCE flow), JWT validation, role-based access control (RBAC), HTTP/2 multiplexing, request pipelining, predictive prefetching, LRU caching, ETag support, gzip/deflate compression, conformance statements

### Deliverables

#### 10.1 DICOMweb Server Configuration
- [ ] Server URL and path configuration
- [ ] Authentication setup:
  - [ ] OAuth2 with PKCE flow
  - [ ] JWT token management (auto-refresh)
  - [ ] Role-based access control display
  - [ ] Bearer token manual entry
- [ ] TLS configuration (strict, compatible, development modes)
- [ ] Connection testing with capabilities endpoint
- [ ] Conformance statement viewer

#### 10.2 QIDO-RS (Query)
- [ ] Study-level query with fluent search UI
- [ ] Series-level query
- [ ] Instance-level query
- [ ] Query parameters:
  - [ ] Patient Name, Patient ID
  - [ ] Study Date, Modality
  - [ ] Accession Number
  - [ ] Fuzzy matching, wildcard matching
- [ ] Paginated results with limit/offset controls
- [ ] Type-safe result display with attribute mapping
- [ ] Response caching with ETag support

#### 10.3 WADO-RS (Retrieve)
- [ ] Retrieve study/series/instance by URL
- [ ] Retrieve specific frames from multi-frame instances
- [ ] Retrieve rendered images (server-side rendering)
- [ ] Bulk data retrieval for large datasets
- [ ] Download progress with HTTP/2 multiplexing (100 concurrent streams)
- [ ] Predictive prefetching of adjacent series
- [ ] Response compression (gzip/deflate) display
- [ ] Cache status display (hit/miss/stale)

#### 10.4 STOW-RS (Store)
- [ ] Upload DICOM files to DICOMweb server
- [ ] Batch upload with progress tracking
- [ ] Duplicate handling (reject, overwrite, ignore)
- [ ] Pre-upload validation
- [ ] Request pipelining (1–50 concurrent requests)
- [ ] Upload queue management

#### 10.5 UPS-RS (Unified Procedure Steps)
- [ ] Worklist query and display
- [ ] UPS state machine visualization:
  - [ ] SCHEDULED → IN PROGRESS → COMPLETED/CANCELED
- [ ] Priority-based scheduling display
- [ ] Event subscription and delivery:
  - [ ] Subscribe to UPS state change events
  - [ ] Real-time event notification display
  - [ ] Event filtering by type
- [ ] UPS creation and update

#### 10.6 Performance Dashboard
- [ ] HTTP/2 multiplexing statistics
- [ ] Request pipelining throughput
- [ ] Cache hit rate and memory usage
- [ ] Prefetch effectiveness metrics
- [ ] Compression ratio display
- [ ] Connection pool utilization

### Technical Notes
- Use DICOMWeb module's `DICOMwebClient` for all operations
- Use `OAuth2Manager` for authentication flows
- Use `CacheManager` for LRU caching with ETag
- Use `PrefetchEngine` for predictive content loading
- Use `ConformanceStatement` for capability discovery
- Reference: DICOM PS3.18 (Web Services), PS3.19 (Application Hosting)

### Acceptance Criteria
- [ ] QIDO-RS returns correct, type-safe results
- [ ] WADO-RS retrieves complete studies with frame-level access
- [ ] STOW-RS uploads successfully with proper error handling
- [ ] UPS-RS state machine transitions correctly
- [ ] OAuth2 PKCE flow completes without manual token handling
- [ ] HTTP/2 multiplexing demonstrably faster than HTTP/1.1
- [ ] Cache reduces redundant network requests by >80%

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 11: Security & Privacy Center

**Status**: Planned
**Goal**: Implement a security and privacy management interface for HIPAA compliance, anonymization, and audit
**DICOMKit Features Showcased**: TLS 1.2/1.3 configuration, mutual TLS (mTLS), certificate pinning, self-signed certificate support, DICOM anonymization profiles, HIPAA-compliant audit logging (file/console/OSLog handlers), pre-send validation

### Deliverables

#### 11.1 TLS Configuration UI
- [ ] TLS mode selection:
  - [ ] Strict mode (TLS 1.3 only)
  - [ ] Compatible mode (TLS 1.2+)
  - [ ] Development mode (allow self-signed)
- [ ] Certificate management:
  - [ ] Import CA certificates
  - [ ] Client certificate for mTLS
  - [ ] Certificate pinning configuration
  - [ ] Certificate chain viewer
  - [ ] Expiration warnings
- [ ] Connection security indicator per server
- [ ] TLS handshake details display

#### 11.2 Anonymization Tool
- [ ] File anonymization with profile selection:
  - [ ] Basic profile (remove direct identifiers)
  - [ ] HIPAA Safe Harbor profile
  - [ ] Custom anonymization rules
- [ ] Tag-level controls:
  - [ ] Remove, replace, hash, encrypt per tag
  - [ ] Date shifting (configurable offset)
  - [ ] UID remapping (consistent replacement)
- [ ] Batch anonymization with progress
- [ ] Preview before/after anonymization
- [ ] Anonymization log with reversibility option (key escrow)
- [ ] PHI detection scanner

#### 11.3 Audit Log Viewer
- [ ] HIPAA-compliant audit trail display:
  - [ ] All file access events
  - [ ] All network operations
  - [ ] User actions (view, modify, export)
  - [ ] Timestamps with timezone
- [ ] Search and filter audit entries by:
  - [ ] Date range
  - [ ] Event type
  - [ ] User identity
  - [ ] Patient/study reference
- [ ] Audit log export (CSV, JSON, ATNA format)
- [ ] Log handler configuration (file, console, OSLog)
- [ ] Log retention policy settings

#### 11.4 Access Control
- [ ] User role display (from OAuth2/JWT)
- [ ] Permission matrix visualization
- [ ] Session management (timeout, auto-lock)
- [ ] Emergency access ("break-glass") tracking

### Technical Notes
- Use DICOMNetwork's TLS configuration APIs
- Use DICOMKit's anonymization APIs
- Use `AuditLogger` with configurable handlers
- Reference: DICOM PS3.15 (Security and System Management Profiles), HIPAA Security Rule §164.312

### Acceptance Criteria
- [ ] TLS configuration applies correctly to all network connections
- [ ] Anonymization removes all specified PHI tags
- [ ] Audit log captures all user-initiated operations
- [ ] Date shifting maintains relative date relationships
- [ ] UID remapping is consistent within a session
- [ ] Export anonymized files pass validation

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 12: Data Exchange & Export

**Status**: Planned
**Goal**: Implement data exchange tools for converting DICOM to/from various formats and exporting clinical data
**DICOMKit Features Showcased**: DICOM-to-JSON conversion, DICOM-to-XML conversion, image export (PNG, JPEG, TIFF), encapsulated PDF creation, DICOMDIR creation, file writing with Part 10 format, transfer syntax conversion

### Deliverables

#### 12.1 DICOM-to-JSON Conversion
- [ ] Convert DICOM file to JSON (DICOM JSON Model per PS3.18 F)
- [ ] Pretty-printed JSON display with syntax highlighting
- [ ] JSON-to-DICOM round-trip conversion
- [ ] Bulk data URI handling
- [ ] JSON export to file

#### 12.2 DICOM-to-XML Conversion
- [ ] Convert DICOM file to XML (DICOM XML per PS3.19)
- [ ] Formatted XML display with syntax highlighting
- [ ] XML-to-DICOM round-trip conversion
- [ ] XML export to file

#### 12.3 Image Export
- [ ] Export displayed image as PNG
- [ ] Export as JPEG with quality settings
- [ ] Export as TIFF (lossless)
- [ ] Burn-in annotations option
- [ ] Burn-in window/level option
- [ ] Batch export all frames of multi-frame instance
- [ ] Export resolution settings (original, scaled)

#### 12.4 Transfer Syntax Conversion
- [ ] Convert between transfer syntaxes:
  - [ ] Implicit VR Little Endian ↔ Explicit VR Little Endian
  - [ ] Uncompressed ↔ JPEG Baseline
  - [ ] Uncompressed ↔ JPEG 2000
  - [ ] Uncompressed ↔ JPEG-LS
  - [ ] Uncompressed ↔ RLE
- [ ] Compression quality settings
- [ ] Batch conversion with progress
- [ ] File size comparison (before/after)

#### 12.5 DICOMDIR Creation
- [ ] Create DICOMDIR from selected studies
- [ ] Standard directory structure generation
- [ ] CD/DVD media preparation
- [ ] DICOMDIR browser and editor

#### 12.6 PDF Encapsulation
- [ ] Create encapsulated PDF DICOM from PDF file
- [ ] Extract PDF from encapsulated DICOM
- [ ] Report-to-PDF generation with measurements and annotations

#### 12.7 Batch Operations
- [ ] Batch tag modification (add, edit, remove tags)
- [ ] Batch transfer syntax conversion
- [ ] Batch anonymization
- [ ] Operation preview and confirmation
- [ ] Progress tracking with error summary

### Technical Notes
- Use DICOMKit's JSON/XML serialization APIs
- Use `DICOMFile.write(to:)` for file output
- Use transfer syntax conversion APIs for re-encoding
- Reference: DICOM PS3.10 (Media Storage), PS3.18 Annex F (JSON), PS3.19 Annex A (XML)

### Acceptance Criteria
- [ ] JSON round-trip preserves all data elements
- [ ] XML round-trip preserves all data elements
- [ ] Image export matches displayed image pixel-for-pixel
- [ ] Transfer syntax conversion produces valid DICOM files
- [ ] DICOMDIR validates against PS3.10 requirements
- [ ] Batch operations handle errors gracefully without losing progress

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 13: Performance & Developer Tools

**Status**: Planned
**Goal**: Implement performance monitoring, diagnostics, and developer-facing tools for DICOMKit exploration
**DICOMKit Features Showcased**: SIMD acceleration benchmarks, metadata-only parsing, streaming parser, memory-mapped file access, image caching (LRU eviction), `DICOMDictionary` (7,000+ tags), UID dictionary (100+ UIDs), Transfer Syntax registry (30+ syntaxes), SOP Class registry

### Deliverables

#### 13.1 Performance Dashboard
- [ ] Real-time metrics display:
  - [ ] File parse time (full parse vs. metadata-only)
  - [ ] Image render time (with/without SIMD)
  - [ ] Cache hit/miss rate
  - [ ] Memory usage (resident, virtual)
  - [ ] Active memory-mapped files count
- [ ] Benchmark runner:
  - [ ] Parse 100 files benchmark
  - [ ] Render 100 frames benchmark
  - [ ] Window/level 1000 iterations benchmark
  - [ ] Network round-trip latency benchmark
- [ ] Performance comparison charts (before/after optimization)
- [ ] Export benchmark results to CSV

#### 13.2 Cache Management
- [ ] Image cache inspector:
  - [ ] Current cache size vs. maximum
  - [ ] Cached items list with size and age
  - [ ] LRU eviction visualization
  - [ ] Manual cache clear
- [ ] Thumbnail cache management
- [ ] Network response cache inspector (DICOMweb)
- [ ] Cache size configuration per type

#### 13.3 Tag Dictionary Explorer
- [ ] Browse all 7,000+ DICOM tags from `DICOMDictionary`
- [ ] Search by tag name, keyword, group, or element number
- [ ] Filter by tag group (Patient, Study, Series, Equipment, Image, etc.)
- [ ] Tag detail view:
  - [ ] Tag number (GGGG,EEEE)
  - [ ] Name, keyword
  - [ ] Value Representation
  - [ ] Value Multiplicity
  - [ ] Retired status
  - [ ] Description and usage notes
- [ ] Private tag registry browser (Siemens, GE, Philips creators)

#### 13.4 UID Lookup Tool
- [ ] Browse all registered UIDs:
  - [ ] Transfer Syntax UIDs (30+ entries)
  - [ ] SOP Class UIDs (100+ entries)
  - [ ] Well-known DICOM UIDs
- [ ] Search by UID value or name
- [ ] UID generation tool (create new DICOM UIDs)
- [ ] UID validation (check format compliance)
- [ ] Copy UID to clipboard

#### 13.5 Transfer Syntax Information
- [ ] List all supported transfer syntaxes with details:
  - [ ] UID, name, description
  - [ ] Compression type (none, lossy, lossless)
  - [ ] Byte order (little/big endian)
  - [ ] VR encoding (implicit/explicit)
  - [ ] Support status in DICOMKit
- [ ] Transfer syntax compatibility checker

#### 13.6 DICOM Conformance Statement Viewer
- [ ] Display DICOMKit's conformance statement
- [ ] Supported SOP classes list with role (SCU/SCP)
- [ ] Supported transfer syntaxes per SOP class
- [ ] Network services capability matrix
- [ ] DICOMweb services capability matrix

### Technical Notes
- Use `DICOMDictionary.shared` for tag and UID data
- Use Instruments-style charts for performance visualization
- Accelerate framework timing for SIMD benchmarks
- Reference: DICOM PS3.2 (Conformance), PS3.5 (Data Structures), PS3.6 (Data Dictionary)

### Acceptance Criteria
- [ ] Performance dashboard updates in real-time during operations
- [ ] Tag dictionary search returns results within 50ms
- [ ] All 7,000+ tags display correctly with full metadata
- [ ] UID generation produces valid DICOM UIDs
- [ ] Benchmarks produce reproducible results (±5% variance)
- [ ] Conformance statement accurately reflects DICOMKit capabilities

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 14: macOS-Specific Enhancements

**Status**: Planned
**Goal**: Optimize DICOM Studio for macOS-specific capabilities and interaction paradigms
**DICOMKit Features Showcased**: macOS API integration, platform-specific rendering optimizations

### Deliverables

#### 14.1 macOS Enhancements
- [ ] Multi-window support:
  - [ ] Open multiple studies in separate windows
  - [ ] Drag images between windows
  - [ ] Window management with Exposé
- [ ] Menu bar integration:
  - [ ] File menu (Open, Import, Export, Print)
  - [ ] Edit menu (Undo, Redo, Preferences)
  - [ ] View menu (Zoom, Layout, Fullscreen)
  - [ ] Tools menu (Measurements, Annotations)
  - [ ] Window menu (Tile, Cascade, specific windows)
  - [ ] Help menu (Documentation, Keyboard Shortcuts)
- [ ] Comprehensive keyboard shortcuts:
  - [ ] Cmd+O: Open file
  - [ ] Cmd+I: File info
  - [ ] Cmd+F: Search
  - [ ] Cmd+1-9: Window presets
  - [ ] Cmd+Shift+F: Fullscreen
  - [ ] Arrow keys: Frame navigation
- [ ] Dock icon badges (transfer count)
- [ ] AppleScript/Shortcuts automation support
- [ ] Quick Look plugin for DICOM files

### Technical Notes
- macOS: AppKit interop via `NSViewRepresentable` where needed
- Reference: Apple Human Interface Guidelines for macOS

### Acceptance Criteria
- [ ] macOS: All menu items and keyboard shortcuts functional
- [ ] macOS: Multi-window operates independently
- [ ] macOS: Application feels native and polished

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 15: Polish, Accessibility & Release

**Status**: Planned
**Goal**: Final polish including internationalization, accessibility, comprehensive testing, performance profiling, and release preparation
**DICOMKit Features Showcased**: Complete library integration verified end-to-end

### Deliverables

#### 15.1 Internationalization (i18n)
- [ ] Externalize all user-facing strings to `.strings` files
- [ ] Localize for priority languages:
  - [ ] English (US) — primary
  - [ ] Spanish, French, German — high priority
  - [ ] Japanese, Chinese (Simplified) — high priority
  - [ ] Korean, Portuguese (Brazil), Arabic, Hebrew — medical markets
- [ ] Right-to-left (RTL) layout support (Arabic, Hebrew):
  - [ ] Semantic layout constraints (.leading/.trailing)
  - [ ] Natural text alignment
  - [ ] RTL-aware icon mirroring
- [ ] Locale-aware formatting:
  - [ ] Dates (`DateFormatter`)
  - [ ] Numbers (`NumberFormatter`)
  - [ ] Measurements (`MeasurementFormatter`)
  - [ ] File sizes (`ByteCountFormatter`)
- [ ] Pluralization with `.stringsdict` files
- [ ] Medical terminology localization

#### 15.2 Accessibility (a11y)
- [ ] VoiceOver support for all interactive elements:
  - [ ] Accessibility labels for all buttons and controls
  - [ ] Accessibility hints for complex actions
  - [ ] Accessibility values for dynamic content (window/level, measurements)
  - [ ] Logical reading order verification
  - [ ] Custom actions for medical imaging controls
- [ ] Dynamic Type support at all text sizes
- [ ] High Contrast mode support
- [ ] Reduce Motion compliance for animations
- [ ] Switch Control / Full Keyboard Access navigation
- [ ] Color blindness support (no color-only information)
- [ ] Focus indicator visibility
- [ ] Accessibility audit with Xcode Accessibility Inspector

#### 15.3 Comprehensive Testing
- [ ] Unit tests for all ViewModels (95% coverage)
- [ ] Integration tests for PACS connectivity
- [ ] UI tests for critical user flows:
  - [ ] Import → Browse → View workflow
  - [ ] Query → Retrieve → Display workflow
  - [ ] Measure → Save SR → Reload workflow
  - [ ] Anonymize → Export workflow
- [ ] Performance tests:
  - [ ] Large file loading (<2s for 100MB file)
  - [ ] Multi-frame playback (60fps)
  - [ ] Network throughput (>50MB/s on LAN)
- [ ] Snapshot tests for UI consistency
- [ ] Localization tests for all languages

#### 15.4 Performance Profiling
- [ ] Memory profiling with Instruments (Leaks, Allocations)
- [ ] CPU profiling with Instruments (Time Profiler)
- [ ] GPU profiling for rendering and 3D (Metal System Trace)
- [ ] Network profiling for DICOM/DICOMweb operations
- [ ] Battery impact assessment
- [ ] Optimize identified bottlenecks
- [ ] Document performance characteristics

#### 15.5 Documentation
- [ ] User guide with screenshots
- [ ] Developer documentation (how to extend)
- [ ] API integration examples
- [ ] Keyboard shortcuts reference
- [ ] Troubleshooting guide
- [ ] Video walkthrough of key features

#### 15.6 Release Preparation
- [ ] App Store metadata:
  - [ ] App description, keywords, screenshots
  - [ ] Privacy policy URL
  - [ ] App category selection
- [ ] TestFlight beta testing
- [ ] Code signing and provisioning
- [ ] App Store Review preparation
- [ ] Release notes for initial version
- [ ] Homebrew cask formula (macOS)

### Technical Notes
- Use Xcode's localization export/import workflow
- Run Accessibility Inspector automated audits
- Profile on physical Mac hardware
- Reference: Apple Accessibility Programming Guide, Apple Internationalization Guide, WCAG 2.1

### Acceptance Criteria
- [ ] All 6 priority languages render correctly
- [ ] RTL layout mirrors properly for Arabic and Hebrew
- [ ] VoiceOver navigates every screen without gaps
- [ ] Dynamic Type works at all accessibility sizes without layout breaks
- [ ] All UI tests pass on macOS
- [ ] Memory usage stays within platform limits
- [ ] No memory leaks detected by Instruments
- [ ] App Store review submission accepted

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 16: CLI Tools Workshop

**Status**: Planned
**Goal**: Provide an interactive graphical interface within DICOM Studio for all 29 DICOMKit command-line tools, serving as both an educational resource for new DICOM users and a productivity tool for experienced professionals
**DICOMKit Features Showcased**: DICOMToolbox command builder, all CLI tool parameters, `Process`-based execution, real-time output streaming, drag-and-drop file handling, PACS network configuration

### Design Philosophy

The CLI Tools Workshop integrates directly into DICOM Studio as a dedicated feature area, providing:

1. **Educational First** — Every parameter includes contextual help, explanations, and expandable discussions referencing the DICOM standard
2. **Visual Command Building** — Users configure tools through native SwiftUI controls (pickers, toggles, steppers, text fields) while the exact CLI syntax builds in real time
3. **Execute In-App** — Run the constructed command directly and view results without leaving DICOM Studio
4. **DICOM Network Aware** — Common PACS connection parameters (local AE title, called AET, host, port, timeout) are displayed in a persistent bar above the tab interface and automatically populate into network tool parameters
5. **Apple HIG Compliant** — Native SwiftUI components following the latest Apple Human Interface Design Guidelines

### Application Layout

```
+================================================================+
|  DICOM Studio — CLI Tools Workshop                     macOS 14+|
+================================================================+
|                                                                 |
|  +-----------------------------------------------------------+ |
|  |  PACS / Network Configuration (Always Visible)             | |
|  |  [AE Title: ____] [Called AET: ____] [Host: ____]          | |
|  |  [Port: ____]     [Timeout: ____s]  [Protocol: DICOM/Web] | |
|  |  [Saved Profiles: v]  [Save]  [Delete]  [Test Connection]  | |
|  +-----------------------------------------------------------+ |
|                                                                 |
|  +-----------------------------------------------------------+ |
|  | File Inspection | Processing | Organization | Export |      | |
|  | Network Ops     | Automation |                              | |
|  +-----------------------------------------------------------+ |
|  |                                                             | |
|  |  +------------------+  +----------------------------------+ | |
|  |  | Tool List        |  | Parameter Configuration          | | |
|  |  | - dicom-info     |  |                                  | | |
|  |  | - dicom-dump     |  |  [Input File]  [Drop Zone]       | | |
|  |  | - dicom-tags     |  |  [Format: v]   [Options...]      | | |
|  |  |   ...            |  |  [Flags]       [Help ⓘ]          | | |
|  |  +------------------+  +----------------------------------+ | |
|  |                                                             | |
|  +-----------------------------------------------------------+ |
|                                                                 |
|  +-----------------------------------------------------------+ |
|  | $ dicom-info --format json --statistics scan.dcm    [Run]  | |
|  |                                                             | |
|  | (command output appears here after execution)               | |
|  +-----------------------------------------------------------+ |
+================================================================+
```

### Deliverables

#### 16.1 Network Configuration Bar
- [ ] `CLINetworkConfigView` component — always visible above the tool tabs
- [ ] Fields with validation:
  - [ ] **AE Title** (`TextField`, 16-char max, ASCII-only validation)
  - [ ] **Called AET** (`TextField`, default: "ANY-SCP")
  - [ ] **Host** (`TextField`, hostname or IP address)
  - [ ] **Port** (`Stepper` + `TextField`, range: 1–65535, default: 11112)
  - [ ] **Timeout** (`Stepper`, range: 5–300s, default: 60)
  - [ ] **Protocol** (`Picker`: DICOM / DICOMweb)
- [ ] Persistence via `Codable` structs stored in `UserDefaults` (for atomicity when saving/loading complete profiles); OAuth2 tokens and sensitive credentials stored in Keychain
- [ ] Server profile management (save, load, delete named profiles)
- [ ] Test Connection button — runs `dicom-echo` inline and displays result
- [ ] Validation badges (green checkmark when all fields are valid)

#### 16.2 Tool Tab Interface
- [ ] `TabView` with 6 logical tabs (`.tabViewStyle(.automatic)`):
  - [ ] **File Inspection** (4 tools): dicom-info, dicom-dump, dicom-tags, dicom-diff
  - [ ] **File Processing** (4 tools): dicom-convert, dicom-validate, dicom-anon, dicom-compress
  - [ ] **File Organization** (4 tools): dicom-split, dicom-merge, dicom-dcmdir, dicom-archive
  - [ ] **Data Export** (6 tools): dicom-json, dicom-xml, dicom-pdf, dicom-image, dicom-export, dicom-pixedit
  - [ ] **Network Operations** (8 tools): dicom-echo, dicom-query, dicom-send, dicom-retrieve, dicom-qr, dicom-wado, dicom-mwl, dicom-mpps
  - [ ] **Automation** (3 tools): dicom-study, dicom-uid, dicom-script
- [ ] `NavigationSplitView` within each tab for tool sidebar + parameter panel
- [ ] SF Symbol icons for each tab (doc.text.magnifyingglass, gearshape.2, folder.badge.gearshape, square.and.arrow.up, network, terminal)

#### 16.3 Parameter Configuration Panel
- [ ] Dynamic `Form` with `Section` and `DisclosureGroup` for each tool's parameters
- [ ] SwiftUI control mapping for every CLI parameter type:

  | Parameter Type | SwiftUI Control | Example |
  |---------------|-----------------|---------|
  | File path (`@Argument`) | `FileDropZoneView` + `.fileImporter()` | DICOM file input |
  | Output path (`@Option --output`) | `.fileExporter()` / `NSSavePanel` | Save anonymized file |
  | Enum option (`@Option` enum) | `Picker` (`.segmented` or `.menu` style) | `--format text\|json\|csv` |
  | String option (`@Option`) | `TextField` with placeholder | `--patient-name "SMITH*"` |
  | Integer option (`@Option`) | `Stepper` or `TextField` (numeric) | `--timeout 60` |
  | Boolean flag (`@Flag`) | `Toggle` (`.switch` style) | `--verbose`, `--recursive` |
  | Repeatable option (array) | Dynamic `List` with Add/Remove | `--tag Name --tag ID` |
  | Date option (`@Option`) | `DatePicker` + manual text fallback | `--study-date 20240101` |
  | Subcommand | `Picker` at top of parameter panel | `dicom-export single\|bulk` |

- [ ] Parameter explanations:
  - [ ] `.help()` modifier for brief tooltip on hover
  - [ ] `DisclosureGroup` for detailed explanation with examples
  - [ ] `Button` + `.popover()` with `Image(systemName: "info.circle")` for extended documentation referencing DICOM standard sections
  - [ ] `Text("*").foregroundStyle(.red)` for required field indicators
  - [ ] Real-time validation feedback with `Text` in `.foregroundStyle(.red)`

#### 16.4 File Drop Zone
- [ ] `FileDropZoneView` — reusable drag-and-drop target:
  - [ ] Dashed border when empty, solid border when file selected
  - [ ] Blue highlight border on drag hover
  - [ ] `.onDrop(of:)` delegate for file URL types
  - [ ] `.fileImporter()` as alternative Browse button
  - [ ] File validation (verify DICOM preamble/header)
  - [ ] Display selected filename and file size with remove button
  - [ ] Multi-file variant for tools accepting multiple inputs (dicom-merge, dicom-send) with reordering
- [ ] `OutputPathView` — output file/directory configuration:
  - [ ] `.fileExporter()` or `NSSavePanel` integration
  - [ ] Required for all tools that produce file output
  - [ ] Display configured path with change/clear buttons

#### 16.5 Console Window
- [ ] `CLIConsoleView` component — always visible below the tool tabs
- [ ] Command preview section:
  - [ ] Monospaced font using `.font(.system(.body, design: .monospaced))` (SF Mono)
  - [ ] Real-time command syntax preview updated as parameters change
  - [ ] Syntax highlighting: tool name in **bold**, flags in blue, values in green, file paths in orange
  - [ ] Copy-to-clipboard button for the generated command
- [ ] Execute (Run) button:
  - [ ] Enabled only when all required parameters are provided (`isCommandValid`)
  - [ ] `.disabled(!isCommandValid)` modifier
  - [ ] Positioned next to the console window
  - [ ] SF Symbol `play.fill` icon
  - [ ] Cancel button (SF Symbol `stop.fill`) appears during execution
- [ ] Output section:
  - [ ] Scrollable, selectable text area
  - [ ] Real-time output streaming during command execution
  - [ ] Status indicators: idle | running (ProgressView spinner) | success (green checkmark) | error (red ✕)
  - [ ] Clear output button
  - [ ] Copy output to clipboard button

#### 16.6 Command Builder Engine
- [ ] `CLICommandBuilder` — builds CLI command string from parameter model:
  - [ ] Observes parameter changes and regenerates syntax in real time
  - [ ] Validates all required parameters are present
  - [ ] Publishes `isValid: Bool` to control Execute button state
  - [ ] Supports all parameter types: positional arguments, options, flags, subcommands
  - [ ] Handles DICOM tag notation (GGGG,EEEE) for repeatable tag parameters
- [ ] `CLICommandExecutor` actor (Swift concurrency):
  - [ ] Executes via `Foundation.Process` with stdout/stderr pipes
  - [ ] Streams output in real-time to the console via `AsyncStream`
  - [ ] Supports cancellation via `Task` cancellation
  - [ ] Reports exit code with success/failure indicator
- [ ] Command history:
  - [ ] Stores last 50 executed commands
  - [ ] Click to reload parameters into the tool view
  - [ ] Export history as a shell script
  - [ ] Re-run previous command button
  - [ ] PHI-aware: automatically redact patient names, IDs, and sensitive credentials (OAuth2 tokens replaced with `<redacted>`) before persisting to history
  - [ ] "Clear History" button and option to auto-clear on app quit
  - [ ] History stored encrypted at rest for HIPAA compliance

#### 16.7 Tool-Specific Parameter Views

##### File Inspection Tab (4 tools)

- [ ] **dicom-info** (`DicomInfoToolView`):
  Input file (drop zone), format picker (text | json | csv), tag filter (repeatable), show private tags toggle, show statistics toggle, force parse toggle — each with help popover explaining the option

- [ ] **dicom-dump** (`DicomDumpToolView`):
  Input file, tag filter field, offset (hex), length stepper, bytes-per-line stepper (8 | 16 | 32), annotate toggle, no-color toggle, highlight tag, force parse toggle

- [ ] **dicom-tags** (`DicomTagsToolView`):
  Input file, output path, set tags (repeatable key=value), delete tags (repeatable), copy-from file, tag list file, delete private toggle, dry run toggle, verbose toggle

- [ ] **dicom-diff** (`DicomDiffToolView`):
  File 1 (drop zone), File 2 (drop zone), format picker (text | json | summary), ignore tags (repeatable), numeric tolerance field, ignore private toggle, compare pixels toggle, quick mode toggle, show identical toggle

##### File Processing Tab (4 tools)

- [ ] **dicom-convert** (`DicomConvertToolView`):
  Input file/directory, output path (required), transfer syntax picker with expandable explanation per syntax, output format (dicom | png | jpeg | tiff), JPEG quality slider (1–100, conditional on jpeg format), window center/width fields, frame stepper, apply window toggle, strip private toggle, validate toggle, recursive toggle, force parse toggle

- [ ] **dicom-validate** (`DicomValidateToolView`):
  Input file/directory, validation level picker (segmented: 1 | 2 | 3 | 4) with expandable descriptions per level, IOD type picker (searchable), output format (text | json), output file (optional), detailed toggle, recursive toggle, strict mode toggle with warning, force parse toggle

- [ ] **dicom-anon** (`DicomAnonToolView`):
  Input file/directory, output path, profile picker (basic | clinical-trial | research) with DICOM PS3.15 references, date shift stepper, regenerate UIDs toggle, remove tags (repeatable), replace tags (repeatable key=value), keep tags (repeatable), recursive toggle, dry run toggle (highlighted), backup toggle, audit log path, force parse toggle, verbose toggle

- [ ] **dicom-compress** (`DicomCompressToolView`):
  Subcommand picker (compress | decompress | info | batch) with dynamic form per subcommand — compress: input/output/codec/quality; decompress: input/output/target syntax; info: input only; batch: input dir/output dir/codec/quality/recursive; verbose toggle

##### File Organization Tab (4 tools)

- [ ] **dicom-split** (`DicomSplitToolView`):
  Input file, output directory, frame range, format picker, window center/width, filename pattern, apply window toggle, recursive toggle

- [ ] **dicom-merge** (`DicomMergeToolView`):
  Multiple input files (multi-file drop zone with add/remove/reorder), output file, format, merge level, sort-by field, sort order, validate toggle, recursive toggle

- [ ] **dicom-dcmdir** (`DicomDcmdirToolView`):
  Subcommand picker (create | validate | dump | update) with dynamic form — create: input dir/output/file-set-ID/profile/recursive; validate: input; dump: input; update: input/add/remove

- [ ] **dicom-archive** (`DicomArchiveToolView`):
  Input file/directory, output, format, recursive toggle

##### Data Export Tab (6 tools)

- [ ] **dicom-json** (`DicomJsonToolView`):
  Input file, output file, format (standard | dicomweb), inline threshold, bulk data URL, reverse toggle (JSON → DICOM), pretty print toggle, stream toggle, metadata-only toggle

- [ ] **dicom-xml** (`DicomXmlToolView`):
  Input file, output file, inline threshold, bulk data URL, reverse toggle, pretty print toggle, no-keywords toggle, metadata-only toggle

- [ ] **dicom-pdf** (`DicomPdfToolView`):
  Input file, output file, patient name/ID fields, document title, extract toggle (toggles between encapsulate and extract modes), show metadata toggle

- [ ] **dicom-image** (`DicomImageToolView`):
  Input image, output file, patient name/ID, modality picker, use EXIF toggle, split pages toggle, recursive toggle

- [ ] **dicom-export** (`DicomExportToolView`):
  Subcommand picker (single | contact-sheet | animate | bulk) with dynamic forms per subcommand, format/quality/apply-window/organize-by options

- [ ] **dicom-pixedit** (`DicomPixeditToolView`):
  Input file, output file, mask region (x,y,w,h), fill value, crop region, apply window toggle, invert toggle

##### Network Operations Tab (8 tools)

- [ ] **dicom-echo** (`DicomEchoToolView`):
  Server URL (auto-built from Network Config), AE Title/Called AET (inherited, overridable), count stepper, timeout (inherited, overridable), show statistics toggle, run diagnostics toggle, verbose toggle

- [ ] **dicom-query** (`DicomQueryToolView`):
  Server URL (inherited), AE Title/Called AET (inherited), query level picker (segmented: patient | study | series | instance), search criteria section (patient name, ID, study date via DatePicker, modality picker, study description, referring physician, accession number, study/series UID), output format (table | json | csv | compact), verbose toggle

- [ ] **dicom-send** (`DicomSendToolView`):
  Server URL (inherited), AE Title/Called AET (inherited), files to send (multi-file drop zone), recursive toggle, verify-first toggle, retry stepper (0–10), priority picker (low | medium | high), dry run toggle, verbose toggle

- [ ] **dicom-retrieve** (`DicomRetrieveToolView`):
  Server URL (inherited), AE Title/Called AET (inherited), study/series/instance UID fields, UID list file (drop zone), output directory (required), method picker (C-MOVE | C-GET), move destination (conditional on C-MOVE), parallel stepper (1–8), hierarchical toggle, verbose toggle

- [ ] **dicom-qr** (`DicomQRToolView`):
  Combined query-retrieve interface with server URL, AE Title/Called AET/move destination (inherited), query parameters (same as dicom-query), retrieve options (method, output, parallel, hierarchical), workflow mode picker (interactive | auto | review), validate retrieved toggle

- [ ] **dicom-wado** (`DicomWadoToolView`):
  Subcommand picker (retrieve | query | store | ups), base URL (https://), study/series/instance UID fields, OAuth2 token (SecureField — stored in Keychain, never logged, displayed as `<redacted>` in console command preview and command history), frames (comma-separated), output directory, metadata format (json | xml), retrieve-mode toggles (metadata-only, rendered, thumbnail), verbose toggle

- [ ] **dicom-mwl** (`DicomMWLToolView`):
  Server URL (inherited), AE Title/Called AET (inherited), query date (DatePicker), station name, patient name, modality picker, JSON output toggle

- [ ] **dicom-mpps** (`DicomMPPSToolView`):
  Subcommand picker (create | update), server URL (inherited), AE Title/Called AET (inherited), study UID, status picker (IN PROGRESS | COMPLETED | DISCONTINUED)

##### Automation Tab (3 tools)

- [ ] **dicom-study** (`DicomStudyToolView`):
  Subcommand picker (organize | summary | check | stats | compare) with dynamic forms per subcommand, pattern builder with common placeholders, format picker, expected-series count

- [ ] **dicom-uid** (`DicomUIDToolView`):
  Subcommand picker (generate | validate | lookup | regenerate) — generate: count stepper/type/root OID; validate: input UIDs or file; lookup: UID field; regenerate: input file/output; JSON output toggle

- [ ] **dicom-script** (`DicomScriptToolView`):
  Subcommand picker (run | validate | template), script file (drop zone), variable editor (repeatable key=value), template picker with preview, parallel toggle, dry run toggle, log output path

#### 16.8 Educational Features
- [ ] Beginner/Advanced mode toggle:
  - [ ] Beginner mode hides advanced parameters (e.g., force parse, byte order options)
  - [ ] Advanced mode shows all parameters
- [ ] "What does this do?" expandable section for every tool with DICOM standard references
- [ ] Example command presets ("Show me an example") per tool
- [ ] DICOM Glossary sidebar (searchable terms)
- [ ] Context-sensitive help linking to DICOM PS3.x standard sections

### Key UI Components

| Component | Description | SwiftUI Implementation |
|-----------|-------------|----------------------|
| **Network Config Bar** | Persistent PACS connection settings above tabs | `Form` in a `GroupBox`, `@AppStorage` persistence |
| **Tab Interface** | 6 logical tool groupings | `TabView` with `.tabViewStyle(.automatic)` |
| **Tool Sidebar** | Tool selection within each tab | `List` with `NavigationSplitView` |
| **Parameter Panel** | Dynamic form for selected tool | `Form` with `Section` and `DisclosureGroup` |
| **File Drop Zone** | Drag-and-drop + native file picker | Custom `DropDelegate` + `.fileImporter()` |
| **Output Path Picker** | File save configuration for output | `.fileExporter()` / `NSSavePanel` |
| **Console Window** | Command preview (SF Mono) + output | `ScrollView` with `.font(.system(.body, design: .monospaced))` |
| **Execute Button** | Run command when syntax is valid | `Button` with `.disabled(!isCommandValid)` |
| **Info Popover** | Parameter help with DICOM references | `Button` + `.popover()` with `Image(systemName: "info.circle")` |
| **Validation Feedback** | Real-time parameter validation | `Text` with `.foregroundStyle(.red)` |

### Complete Tool-to-Tab Mapping

| # | Tool | Tab | Network | Subcommands | File Input | File Output |
|---|------|-----|:-------:|:-----------:|:----------:|:-----------:|
| 1 | dicom-info | File Inspection | — | — | ✓ | — |
| 2 | dicom-dump | File Inspection | — | — | ✓ | — |
| 3 | dicom-tags | File Inspection | — | — | ✓ | ✓ |
| 4 | dicom-diff | File Inspection | — | — | ✓ (×2) | — |
| 5 | dicom-convert | File Processing | — | — | ✓ | ✓ |
| 6 | dicom-validate | File Processing | — | — | ✓ | Optional |
| 7 | dicom-anon | File Processing | — | — | ✓ | ✓ |
| 8 | dicom-compress | File Processing | — | ✓ | ✓ | ✓ |
| 9 | dicom-split | File Organization | — | — | ✓ | ✓ |
| 10 | dicom-merge | File Organization | — | — | ✓ (multi) | ✓ |
| 11 | dicom-dcmdir | File Organization | — | ✓ | ✓ | ✓ |
| 12 | dicom-archive | File Organization | — | — | ✓ | ✓ |
| 13 | dicom-json | Data Export | — | — | ✓ | ✓ |
| 14 | dicom-xml | Data Export | — | — | ✓ | ✓ |
| 15 | dicom-pdf | Data Export | — | — | ✓ | ✓ |
| 16 | dicom-image | Data Export | — | — | ✓ | ✓ |
| 17 | dicom-export | Data Export | — | ✓ | ✓ | ✓ |
| 18 | dicom-pixedit | Data Export | — | — | ✓ | ✓ |
| 19 | dicom-echo | Network Operations | ✓ | — | — | — |
| 20 | dicom-query | Network Operations | ✓ | — | — | — |
| 21 | dicom-send | Network Operations | ✓ | — | ✓ (multi) | — |
| 22 | dicom-retrieve | Network Operations | ✓ | — | Optional | ✓ |
| 23 | dicom-qr | Network Operations | ✓ | ✓ | — | ✓ |
| 24 | dicom-wado | Network Operations | ✓ | ✓ | Optional | ✓ |
| 25 | dicom-mwl | Network Operations | ✓ | ✓ | — | — |
| 26 | dicom-mpps | Network Operations | ✓ | ✓ | — | — |
| 27 | dicom-study | Automation | — | ✓ | ✓ | Optional |
| 28 | dicom-uid | Automation | — | ✓ | Optional | — |
| 29 | dicom-script | Automation | — | ✓ | ✓ | Optional |

### SF Symbol Recommendations

| Element | SF Symbol | Usage |
|---------|-----------|-------|
| File Inspection tab | `doc.text.magnifyingglass` | Tab icon |
| File Processing tab | `gearshape.2` | Tab icon |
| File Organization tab | `folder.badge.gearshape` | Tab icon |
| Data Export tab | `square.and.arrow.up` | Tab icon |
| Network Operations tab | `network` | Tab icon |
| Automation tab | `terminal` | Tab icon |
| File Drop Zone (empty) | `doc.badge.plus` | Drop target icon |
| Execute Button | `play.fill` | Run command |
| Cancel Button | `stop.fill` | Cancel execution |
| Copy Button | `doc.on.doc` | Copy to clipboard |
| Help / Info | `info.circle` | Parameter help popover |
| Warning | `exclamationmark.triangle` | Validation warning |
| Success | `checkmark.circle.fill` | Command succeeded |
| Error | `xmark.circle.fill` | Command failed |
| History | `clock.arrow.circlepath` | Command history |

### Technical Notes
- Integrate into the existing DICOM Studio sidebar navigation as a "CLI Tools" or "Workshop" entry
- Use `DICOMToolbox` module's `CommandBuilder` and `CommandExecutor` for command construction and execution
- Network parameters auto-populate into network tools from the persistent config bar
- Override mechanism: local tool-level values take precedence over global config
- Execute commands via `Foundation.Process` with stdout/stderr pipes
- Stream output asynchronously using Swift concurrency (`AsyncStream`, `Task`)
- Use `Codable` structs with `UserDefaults` for network profiles and command history; store OAuth2 tokens in Keychain
- Console view must redact sensitive credentials (replace with `<redacted>`) in command preview and history
- All parameter views should use `@Observable` ViewModels for two-way binding
- Reference: DICOM PS3.2 (Conformance), PS3.5 (Data Structures), PS3.6 (Data Dictionary), PS3.7 (Message Exchange), PS3.15 (Security), PS3.18 (Web Services)

### Acceptance Criteria
- [ ] All 29 CLI tools are accessible through the Workshop GUI with all parameters configurable
- [ ] Network configuration bar is always visible and persists across app launches
- [ ] Network parameters auto-populate into all network tool views
- [ ] Every parameter has at least a tooltip; complex parameters have expandable help with DICOM references
- [ ] File drag-and-drop works for all file input parameters with visual feedback
- [ ] File output parameters present a save panel for path configuration
- [ ] Command preview updates in real-time as parameters are changed (SF Mono font)
- [ ] Execute button correctly enables when all required parameters are valid, disabled otherwise
- [ ] Command output displays in the monospaced console with real-time streaming
- [ ] Command execution supports cancellation
- [ ] Command history stores and replays the last 50 commands
- [ ] Beginner/Advanced mode toggle hides/shows advanced parameters
- [ ] VoiceOver, keyboard navigation, and Dynamic Type are fully supported
- [ ] All 29 tools generate valid command syntax verified by unit tests

### Estimated Effort
**3 weeks** (1 developer)

---

## Architecture Overview

### Application Structure

```
DICOMStudio/
├── Shared/                           # Shared code
│   ├── Models/                       # Data models
│   │   ├── StudyModel.swift
│   │   ├── SeriesModel.swift
│   │   ├── InstanceModel.swift
│   │   └── LibraryModel.swift
│   ├── ViewModels/                   # @Observable ViewModels
│   │   ├── LibraryViewModel.swift
│   │   ├── ViewerViewModel.swift
│   │   ├── NetworkingViewModel.swift
│   │   ├── ReportingViewModel.swift
│   │   ├── SecurityViewModel.swift
│   │   ├── CLIWorkshopViewModel.swift    # CLI Tools Workshop
│   │   └── SettingsViewModel.swift
│   ├── Services/                     # Service layer
│   │   ├── DICOMFileService.swift
│   │   ├── ThumbnailService.swift
│   │   ├── StorageService.swift
│   │   ├── NetworkService.swift
│   │   ├── CacheService.swift
│   │   ├── AuditService.swift
│   │   ├── CLICommandBuilderService.swift  # Command syntax builder
│   │   └── CLICommandExecutorService.swift # Process-based execution
│   ├── Views/                        # SwiftUI views
│   │   ├── Library/
│   │   ├── Viewer/
│   │   ├── Networking/
│   │   ├── Reporting/
│   │   ├── Modalities/
│   │   ├── Tools/
│   │   ├── Security/
│   │   ├── CLIWorkshop/              # CLI Tools Workshop views
│   │   │   ├── CLIWorkshopView.swift       # Main workshop container
│   │   │   ├── CLINetworkConfigView.swift  # Persistent PACS config bar
│   │   │   ├── CLIConsoleView.swift        # Console with SF Mono
│   │   │   ├── FileDropZoneView.swift      # Drag-and-drop component
│   │   │   ├── OutputPathView.swift        # Save path configuration
│   │   │   ├── ToolTabs/                   # Per-tab tool views
│   │   │   │   ├── FileInspectionTab/
│   │   │   │   ├── FileProcessingTab/
│   │   │   │   ├── FileOrganizationTab/
│   │   │   │   ├── DataExportTab/
│   │   │   │   ├── NetworkOpsTab/
│   │   │   │   └── AutomationTab/
│   │   │   └── Shared/                     # Reusable parameter controls
│   │   │       ├── ParameterSectionView.swift
│   │   │       ├── EnumPickerView.swift
│   │   │       └── RepeatableOptionView.swift
│   │   └── Components/               # Reusable UI components
│   └── Resources/                    # Assets and localization
│       ├── Assets.xcassets
│       └── Localizable.strings
├── macOS/                            # macOS-specific
│   ├── DICOMStudioApp.swift
│   ├── Views/
│   └── Commands/
└── Tests/
    ├── SharedTests/
    └── macOSTests/
```

### Dependency Graph

```
DICOMStudio
├── DICOMKit           (Image rendering, presentation states, advanced imaging)
├── DICOMCore          (Tags, VR, DataElement, value parsers, pixel data)
├── DICOMDictionary    (Tag dictionary, UID registry, Transfer Syntax registry)
├── DICOMNetwork       (C-ECHO/FIND/MOVE/GET/STORE, MWL, MPPS, Print, TLS)
├── DICOMWeb           (QIDO-RS, WADO-RS, STOW-RS, UPS-RS, OAuth2)
├── DICOMToolbox       (Reusable command/tool execution, file processing utilities)
└── ArgumentParser     (For any CLI-invocable features)
```

### Feature-to-Module Mapping

| Feature Area | Primary Module | Supporting Modules |
|-------------|---------------|-------------------|
| File Browser & Library | DICOMCore, DICOMKit | DICOMDictionary |
| Image Viewer | DICOMKit | DICOMCore |
| Presentation States | DICOMKit | DICOMCore |
| Measurements | DICOMKit | DICOMCore |
| 3D/MPR | DICOMKit | DICOMCore |
| Structured Reporting | DICOMKit, DICOMCore | DICOMDictionary |
| Specialized Modalities | DICOMKit | DICOMCore |
| DICOM Networking | DICOMNetwork | DICOMCore, DICOMDictionary |
| DICOMweb | DICOMWeb | DICOMCore, DICOMDictionary |
| Security & Privacy | DICOMNetwork | DICOMKit |
| Data Exchange | DICOMKit, DICOMCore | DICOMDictionary |
| Developer Tools | DICOMDictionary | DICOMCore |
| CLI Tools Workshop | DICOMToolbox | DICOMKit, DICOMNetwork, DICOMWeb, ArgumentParser |

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Large scope causes timeline overrun | High | Medium | Strict milestone gating; defer non-essential features |
| Metal/GPU complexity for 3D rendering | High | Medium | Start with CPU fallback; optimize incrementally |
| PACS test server availability | Medium | Low | Use Orthanc Docker for local testing |
| App Store rejection for medical claims | High | Low | Avoid diagnostic claims; label as "viewer only" |
| Accessibility compliance gaps | Medium | Medium | Continuous accessibility auditing per milestone |
| Localization accuracy for medical terms | Medium | Medium | Professional medical translator review |
| CLI tool not found at runtime (Workshop) | High | Medium | Bundle CLI executables in the app bundle's `Contents/Resources/CLITools/` directory for App Store distribution; locate via `Bundle.main.resourcePath`; verify tool availability at launch with user-visible diagnostics |
| Long-running CLI commands block UI (Workshop) | High | Low | Swift concurrency with Task cancellation; timeout limits |
| Large command output overwhelms console (Workshop) | Medium | Medium | Virtualized scrolling; output truncation with "show all" option |

---

## Dependencies & Prerequisites

### External
- Xcode 15.4+ with macOS 14 SDK
- Test PACS server (Orthanc or dcm4chee via Docker)
- Mac for development and testing
- Apple Developer Program membership (App Store distribution)

### Internal
- DICOMKit v1.0+ (all modules stable and tested)
- All existing CLI tools and viewers as reference implementations
- Test DICOM files covering all supported modalities and transfer syntaxes

---

*This plan covers 16 milestones spanning approximately 37 weeks of development, with 1,320+ planned tests, showcasing every feature of DICOMKit on macOS — including an interactive CLI Tools Workshop providing a graphical interface for all 29 command-line tools.*
