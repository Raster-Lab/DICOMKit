# DICOMViewer macOS - Implementation Plan

## Overview

**Status**: Ready for Implementation (Post-Milestone 10.13)  
**Target Version**: v1.0.14  
**Estimated Duration**: 4-5 weeks  
**Developer Effort**: 1 senior macOS developer  
**Platform**: macOS 14+ (Sonoma and later)  
**Dependencies**: DICOMKit v1.0, DICOMNetwork, SwiftUI, AppKit

This document provides a comprehensive phase-by-phase implementation plan for DICOMViewer macOS, a professional diagnostic workstation with PACS integration, Multi-Planar Reconstruction (MPR), and advanced features for clinical radiology workflows.

---

## Strategic Goals

### Primary Objectives
1. **Professional Workstation**: Create diagnostic-quality viewer for clinical radiology
2. **PACS Integration**: Full C-FIND, C-MOVE, QIDO, WADO support
3. **Advanced Imaging**: MPR, 3D visualization, fusion
4. **Clinical Workflow**: Hanging protocols, key images, reporting
5. **Performance**: Handle large datasets efficiently

### Secondary Objectives
- Demonstrate DICOMKit enterprise capabilities
- Provide reference implementation for developers
- Support research and teaching workflows
- Enable teleradiology use cases
- Showcase SwiftUI on macOS

---

## Application Specifications

### Core Features

#### 1. Advanced File Management

##### 1.1 Local Database
- **Study Database**
  - SQLite or SwiftData backend
  - Patient → Study → Series → Instance hierarchy
  - Full-text search on all metadata
  - Advanced query builder
  - Saved searches (smart folders)
  - Study comparison and diff

- **Import Sources**
  - File browser with preview
  - Drag and drop to app icon or window
  - Watch folder (auto-import)
  - Network import from PACS
  - DICOMDIR CD/DVD import
  - Batch import with progress

- **Library Management**
  - Multi-column study list
  - Customizable columns
  - Sort by any metadata field
  - Filter by date range, modality, patient
  - Study merging and splitting
  - Duplicate detection
  - Archive to external drive

##### 1.2 PACS Integration
- **Query (C-FIND / QIDO-RS)**
  - Patient-level query
  - Study-level query
  - Series-level query
  - Instance-level query
  - Modality worklist (C-FIND)
  - Query result caching
  - Saved query templates

- **Retrieve (C-MOVE / C-GET / WADO-RS)**
  - Download study to local database
  - Download series only
  - Download specific instances
  - Streaming playback (no local storage)
  - Bandwidth throttling
  - Resume interrupted downloads
  - Batch retrieve with queue

- **Send (C-STORE / STOW-RS)**
  - Send study to PACS
  - Send series to PACS
  - Send with verification
  - Routing rules
  - Send queue management
  - Failed transfer retry

- **Server Management**
  - Multiple PACS server configs
  - AE Title management
  - Connection testing (C-ECHO)
  - TLS/SSL support
  - Server presets and profiles

#### 2. Professional Viewer

##### 2.1 Viewport System
- **Multi-Viewport Layout**
  - 1×1, 1×2, 2×1, 2×2, 3×3, 4×4 layouts
  - Custom grid layouts
  - Hanging protocols (auto-arrange)
  - Viewport linking (sync scroll, W/L, zoom)
  - Viewport comparison mode
  - Full-screen single viewport

- **Series Display**
  - Auto-load series to viewports
  - Thumbnail strip for quick navigation
  - Series description overlays
  - Frame counter and cine controls
  - Stack mode vs. tile mode
  - Reference line overlay (MPR cross-sections)

##### 2.2 Image Display
- **Window/Level**
  - Interactive adjustment (mouse drag)
  - Presets (lung, bone, soft tissue, brain, liver, etc.)
  - Auto-window from image statistics
  - Histogram equalization
  - Custom preset creation and save
  - Invert grayscale

- **Zoom and Pan**
  - Mouse wheel zoom
  - Click and drag pan
  - Fit to viewport
  - Actual size (1:1)
  - Custom zoom levels
  - Magnifying glass (loupe)

- **Rotation and Flip**
  - 90° rotation increments
  - Free rotation
  - Horizontal/vertical flip
  - Transform matrix display

- **Cine Mode**
  - Variable frame rate (1-120 fps)
  - Forward/reverse playback
  - Loop and bounce modes
  - Frame-by-frame stepping
  - Keyboard shortcuts
  - Timeline scrubber

##### 2.3 Presentation State
- **GSPS Support**
  - Load and apply GSPS
  - Modality LUT transformation
  - VOI LUT transformation
  - Presentation LUT transformation
  - Graphic annotations overlay
  - Text overlays
  - Shutter display (rectangular, circular, polygonal)
  - Spatial transformations

- **Soft Copy Presentation State**
  - Save current view as GSPS
  - Export GSPS to file
  - Share GSPS with colleagues
  - Presentation state library

#### 3. Advanced Measurement and Analysis

##### 3.1 Measurement Tools
- **Linear Measurements**
  - Length (calibrated in mm)
  - Angle (3-point or 4-point Cobb)
  - Perpendicular distance
  - Multi-point polyline

- **Area Measurements**
  - Ellipse ROI
  - Rectangle ROI
  - Polygon ROI
  - Freehand ROI
  - Auto-segmentation (magic wand)

- **Volume Measurements**
  - 3D ellipsoid volume
  - Multi-slice ROI volume
  - Threshold-based volume
  - Volume rendering overlay

- **Hounsfield Units (CT)**
  - HU display on overlay
  - HU cursor readout
  - HU histogram

##### 3.2 Statistics and Analysis
- **ROI Statistics**
  - Mean, standard deviation
  - Min, max values
  - Area, perimeter, volume
  - Histogram with percentiles
  - Export to CSV/Excel

- **Time-Series Analysis**
  - Time-intensity curves
  - Wash-in/wash-out curves
  - Perfusion analysis
  - ROI tracking across frames

##### 3.3 Measurement Management
- **Annotation Layers**
  - Multiple annotation layers
  - Show/hide layers
  - Layer grouping
  - Import/export annotations

- **Report Generation**
  - Measurement report template
  - Include screenshots
  - Export to PDF
  - Export to DICOM SR
  - Custom templates

#### 4. Multi-Planar Reconstruction (MPR)

##### 4.1 2D MPR
- **Orthogonal Views**
  - Axial, sagittal, coronal
  - Synchronized scrolling
  - Reference lines on each view
  - Automatic plane calculation

- **Oblique MPR**
  - User-defined plane angle
  - Interactive plane rotation
  - Double oblique
  - Curved MPR (vessel tracking)

##### 4.2 3D Visualization
- **Maximum Intensity Projection (MIP)**
  - Slab MIP
  - Rotational MIP
  - MIP thickness control
  - MIP quality settings

- **Volume Rendering**
  - Ray casting engine
  - Transfer function editor
  - Preset transfer functions (bone, soft tissue, angio)
  - Clipping planes
  - Rotation and zoom
  - Lighting and shading controls

- **Surface Rendering**
  - Isosurface extraction
  - Marching cubes algorithm
  - Surface smoothing
  - Mesh export (STL, OBJ)

##### 4.3 3D Tools
- **Cropping**
  - 3D crop box
  - Region of interest selection
  - Non-orthogonal cropping

- **Fusion**
  - PET/CT fusion
  - MR/CT fusion
  - Manual alignment
  - Auto-registration (rigid, affine)
  - Opacity blending

#### 5. DICOM Printing

##### 5.1 Print Composer
- **Film Layout**
  - Standard formats (8×10, 11×14, 14×17)
  - Custom film sizes
  - Multiple images per film
  - Auto-layout from hanging protocol
  - Manual image placement

- **Print Annotations**
  - Patient demographics
  - Study information
  - Date and time stamps
  - Custom text annotations
  - Institutional logo

##### 5.2 Print Destinations
- **DICOM Print (C-PRINT)**
  - Send to DICOM printer
  - Film session management
  - Print queue
  - Print verification

- **PDF Export**
  - High-resolution PDF
  - Multi-page reports
  - Include measurements and annotations
  - Embed metadata

- **Local Printer**
  - Print to macOS printer
  - Page setup and margins
  - Color vs. grayscale
  - Print preview

#### 6. Professional Features

##### 6.1 Hanging Protocols
- **Protocol Definition**
  - Define layouts by modality
  - Define by body part
  - Define by study description
  - Auto-series assignment rules
  - Viewport window/level presets

- **Protocol Library**
  - Built-in protocols (chest CT, brain MR, etc.)
  - Custom protocol creation
  - Import/export protocols
  - Share protocols with team

##### 6.2 Key Images
- **Key Image Selection**
  - Mark frames as key images
  - Add annotations to key images
  - Group key images by finding
  - Key image gallery view

- **Key Object Selection (KOS)**
  - Create DICOM KOS objects
  - Export KOS to PACS
  - Share KOS with colleagues
  - Import KOS from PACS

##### 6.3 Structured Reporting
- **SR Viewer**
  - Display SR document tree
  - Navigate sections
  - Show measurements and findings
  - Link to referenced images

- **SR Creation** (optional)
  - Template-based reporting
  - Import measurements
  - Voice dictation support
  - Export to DICOM SR

##### 6.4 Worklist Integration
- **Modality Worklist (MWL)**
  - Query worklist from PACS
  - Filter by date, modality, station
  - Auto-launch study from worklist
  - Update study status

- **Workflow Management**
  - Study status tracking (unread, read, reported)
  - Reading list
  - Priority flags
  - Radiologist assignment

#### 7. UI/UX Design

##### 7.1 Window Layout
- **Main Window**
  - Sidebar (study browser, PACS, tools)
  - Main viewport area
  - Inspector panel (metadata, measurements)
  - Toolbar with common actions
  - Floating tool palettes

- **Customization**
  - Sidebar show/hide
  - Inspector panel show/hide
  - Toolbar customization
  - Window state persistence
  - Multi-window support

##### 7.2 macOS Integration
- **Menu Bar**
  - File menu (Import, Export, Print)
  - Edit menu (Undo/Redo, Copy, Paste)
  - View menu (Layout, Zoom, Window/Level)
  - Tools menu (Measurements, MPR, 3D)
  - Window menu (Arrange, Minimize)
  - Help menu

- **Keyboard Shortcuts**
  - Standard macOS shortcuts
  - Custom viewer shortcuts
  - Configurable hotkeys
  - Shortcut reference card

- **Touch Bar** (MacBook Pro)
  - Window/level sliders
  - Frame navigation
  - Quick access to tools
  - Context-sensitive controls

##### 7.3 Visual Design
- **Professional Theme**
  - Dark mode optimized (medical standard)
  - High contrast for image viewing
  - Color-coded UI elements
  - Consistent iconography

- **Accessibility**
  - VoiceOver support
  - Keyboard navigation
  - High contrast mode
  - Text scaling

---

## Technical Architecture

### App Structure

```
DICOMViewer macOS/
├── App/
│   ├── DICOMViewerApp.swift
│   ├── AppDelegate.swift
│   └── AppCommands.swift              // Menu commands
├── Models/
│   ├── Study/
│   │   ├── DICOMStudy.swift
│   │   ├── DICOMSeries.swift
│   │   ├── DICOMInstance.swift
│   │   └── StudyDatabase.swift        // Core Data
│   ├── PACS/
│   │   ├── PACSServer.swift
│   │   ├── PACSQuery.swift
│   │   └── PACSJob.swift
│   ├── Measurements/
│   │   ├── Measurement.swift
│   │   ├── Annotation.swift
│   │   └── ROI.swift
│   ├── Presentation/
│   │   ├── PresentationState.swift
│   │   ├── HangingProtocol.swift
│   │   └── Viewport.swift
│   └── Imaging/
│       ├── Volume.swift               // 3D volume data
│       ├── MPRPlane.swift
│       └── TransferFunction.swift
├── ViewModels/
│   ├── StudyBrowserViewModel.swift
│   ├── ViewerViewModel.swift
│   ├── PACSViewModel.swift
│   ├── MeasurementViewModel.swift
│   ├── MPRViewModel.swift
│   └── PrintViewModel.swift
├── Views/
│   ├── MainWindow.swift
│   ├── StudyBrowser/
│   │   ├── StudyListView.swift
│   │   ├── SeriesBrowserView.swift
│   │   ├── ThumbnailStripView.swift
│   │   └── StudySearchView.swift
│   ├── Viewer/
│   │   ├── ViewportGridView.swift
│   │   ├── ViewportView.swift
│   │   ├── ImageCanvasView.swift      // Metal rendering
│   │   ├── OverlayView.swift
│   │   └── CineControlsView.swift
│   ├── PACS/
│   │   ├── PACSBrowserView.swift
│   │   ├── QueryView.swift
│   │   ├── RetrieveView.swift
│   │   └── ServerConfigView.swift
│   ├── Measurements/
│   │   ├── MeasurementToolbar.swift
│   │   ├── MeasurementListView.swift
│   │   └── StatisticsView.swift
│   ├── MPR/
│   │   ├── MPRView.swift
│   │   ├── OrthogonalView.swift
│   │   ├── VolumeRenderView.swift     // Metal
│   │   └── TransferFunctionEditor.swift
│   ├── Print/
│   │   ├── FilmComposerView.swift
│   │   ├── FilmLayoutView.swift
│   │   └── PrintQueueView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       ├── HangingProtocolEditor.swift
│       └── KeyboardShortcutsView.swift
├── Services/
│   ├── Database/
│   │   ├── StudyDatabaseManager.swift
│   │   └── CoreDataStack.swift
│   ├── PACS/
│   │   ├── PACSClient.swift           // Uses DICOMNetwork
│   │   ├── DICOMWebClient.swift
│   │   └── QueryService.swift
│   ├── Rendering/
│   │   ├── ImageRenderer.swift
│   │   ├── MetalRenderer.swift        // GPU acceleration
│   │   ├── VolumeRenderer.swift
│   │   └── MPREngine.swift
│   ├── Import/
│   │   ├── FileImporter.swift
│   │   ├── DICOMDIRImporter.swift
│   │   └── WatchFolderMonitor.swift
│   ├── Export/
│   │   ├── ImageExporter.swift
│   │   ├── PDFGenerator.swift
│   │   └── DicomSRExporter.swift
│   └── Printing/
│       ├── PrintManager.swift
│       ├── DicomPrintClient.swift
│       └── FilmSessionManager.swift
├── Utilities/
│   ├── Extensions/
│   ├── Coordinators/
│   └── Helpers/
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    ├── HangingProtocols/
    │   ├── ChestCT.json
    │   ├── BrainMR.json
    │   └── ...
    └── Info.plist
```

### Key Technologies

#### Metal for GPU Acceleration
- **Image Rendering**: GPU-accelerated window/level
- **Volume Rendering**: Ray casting on GPU
- **MPR**: Real-time slice extraction
- **Image Processing**: Filters and enhancements

#### Core Data for Database
- **Study Database**: Persistent storage
- **Measurement Storage**: Annotation persistence
- **Query Caching**: Performance optimization

#### Combine for Reactive UI
- **Data Flow**: ViewModel → View updates
- **Network Operations**: Async task management
- **User Input**: Debouncing and throttling

---

## Implementation Phases

### Phase 1: Foundation (Week 1)

#### Days 1-2: Project Setup and Database
**Goal**: Create Xcode project with Core Data

**Tasks**:
- [x] Create new macOS App project
- [x] Add DICOMKit and DICOMNetwork dependencies
- [x] Configure project settings
- [x] Set up Core Data model
- [x] Create Study/Series/Instance entities
- [x] Implement StudyDatabaseManager
- [x] Create basic data models
- [x] Set up SwiftUI app structure
- [x] Create main window layout
- [x] Configure menu bar

**Test Requirements**:
- [x] Project compiles without errors
- [x] Core Data stack initializes
- [x] Can create and query studies in database
- [x] Main window displays correctly
- [x] Menu bar functional

---

#### Days 3-5: File Import and Study Browser
**Goal**: Import DICOM files and display study list

**Tasks**:
- [x] Implement file importer
- [x] Add drag and drop support
- [x] Create study list view
- [x] Implement series browser
- [x] Add thumbnail generator
- [x] Create search functionality
- [x] Implement filters (modality, date)
- [x] Add study deletion
- [x] Create StudyBrowserViewModel
- [x] Write tests for import and database

**Test Requirements**:
- [x] Import single DICOM file
- [x] Import directory of files
- [x] Drag and drop works
- [x] Study list updates correctly
- [x] Thumbnails generate
- [x] Search returns correct results
- [x] Delete study removes from database
- [x] 30+ unit tests for StudyBrowserViewModel

---

#### Days 6-7: Basic Viewer
**Goal**: Display images with basic controls

**Tasks**:
- [x] Create viewport view
- [x] Implement image renderer (DICOM → CGImage)
- [x] Add zoom and pan with mouse
- [x] Implement window/level mouse drag
- [x] Create frame navigator
- [x] Add cine controls
- [x] Implement ViewerViewModel
- [x] Create overlay for patient info
- [x] Write viewer tests

**Test Requirements**:
- [x] Display CT image correctly
- [x] Display MR image correctly
- [x] Zoom with mouse wheel
- [x] Pan with mouse drag
- [x] Window/level adjusts with mouse
- [x] Frame navigation works
- [x] Cine playback at 30fps
- [x] 40+ unit tests for ViewerViewModel

---

### Phase 2: PACS Integration (Week 2)

#### Days 1-3: PACS Connectivity
**Goal**: Implement C-FIND, C-MOVE, C-STORE

**Tasks**:
- [x] Create PACSServer model
- [x] Implement PACSClient using DICOMNetwork
- [x] Add C-ECHO (connection test)
- [x] Implement C-FIND query
- [x] Implement C-MOVE retrieve
- [x] Implement C-STORE send
- [x] Create PACSViewModel
- [x] Build server configuration UI
- [x] Add query results view
- [x] Create retrieve progress view
- [x] Write PACS integration tests

**Test Requirements**:
- [x] C-ECHO to test server succeeds
- [x] C-FIND patient query returns results
- [x] C-FIND study query returns results
- [x] C-MOVE retrieves study successfully
- [x] C-STORE sends study successfully
- [x] Handle connection failures gracefully
- [x] 50+ unit tests for PACS functionality
- [x] Integration tests with public test PACS

---

#### Days 4-5: DICOMweb Support
**Goal**: Add QIDO-RS, WADO-RS, STOW-RS

**Tasks**:
- [x] Create DICOMWebClient
- [x] Implement QIDO-RS query
- [x] Implement WADO-RS retrieve
- [x] Implement STOW-RS send
- [x] Add authentication (OAuth2, Basic Auth)
- [x] Create DICOMweb server config UI
- [x] Write DICOMweb tests

**Test Requirements**:
- [x] QIDO-RS query returns JSON
- [x] WADO-RS retrieves instance
- [x] STOW-RS uploads successfully
- [x] Authentication works
- [x] Handle HTTP errors correctly
- [x] 30+ unit tests for DICOMweb

---

#### Days 6-7: PACS UI and Workflow
**Goal**: Complete PACS browser and workflow

**Tasks**:
- [x] Create PACS browser view
- [x] Implement query form
- [x] Add query result table
- [x] Create download queue
- [x] Implement send queue
- [x] Add server management
- [x] Create saved queries
- [x] Polish PACS UI
- [x] Write workflow tests

**Test Requirements**:
- [x] Query form builds correct C-FIND
- [x] Results display in table
- [x] Download queue processes items
- [x] Send queue handles retries
- [x] Server configs persist
- [x] Saved queries load correctly
- [x] 20+ UI tests for PACS browser

---

### Phase 3: Advanced Imaging (Week 3)

#### Days 1-3: Multi-Viewport and Layouts
**Goal**: Implement viewport grid and linking

**Tasks**:
- [x] Create viewport grid system
- [x] Implement 1×1, 2×2, 3×3, 4×4 layouts
- [x] Add viewport linking (scroll, W/L, zoom)
- [x] Create hanging protocol engine
- [x] Implement protocol definitions
- [x] Load hanging protocol library
- [x] Auto-assign series to viewports
- [x] Write layout and protocol tests

**Test Requirements**:
- [x] Switch between layouts
- [x] Viewports display different series
- [x] Linked scroll synchronizes frames
- [x] Linked W/L synchronizes all viewports
- [x] Hanging protocol auto-arranges CT chest
- [x] Custom protocols save and load
- [x] 30+ unit tests for layout system

---

#### Days 4-5: MPR Implementation
**Goal**: Add 2D MPR (orthogonal views)

**Tasks**:
- [x] Create Volume data structure
- [x] Implement volume loading from series
- [x] Create MPREngine for slice extraction
- [x] Build orthogonal MPR view (axial, sagittal, coronal)
- [x] Add reference line overlay
- [x] Implement synchronized scrolling
- [x] Create oblique MPR
- [x] Write MPR tests

**Test Requirements**:
- [x] Load CT volume correctly
- [x] Extract axial slice matches original
- [x] Extract sagittal slice correctly
- [x] Extract coronal slice correctly
- [x] Reference lines show correct intersection
- [x] Oblique plane can be rotated
- [x] 40+ unit tests for MPR

---

#### Days 6-7: 3D Visualization
**Goal**: Implement MIP and volume rendering

**Tasks**:
- [x] Create Metal-based volume renderer
- [x] Implement MIP (Maximum Intensity Projection)
- [x] Implement ray casting volume rendering
- [x] Create transfer function editor
- [x] Add preset transfer functions
- [x] Implement 3D rotation and zoom
- [x] Add clipping planes
- [x] Write 3D rendering tests

**Test Requirements**:
- [x] MIP displays correctly
- [x] Volume rendering shows anatomy
- [x] Transfer function affects rendering
- [x] Rotation is smooth (30fps)
- [x] Clipping planes work correctly
- [x] Preset transfer functions load
- [x] Performance: 30fps for 512³ volume

---

### Phase 4: Measurements and Tools (Week 4)

#### Days 1-2: Measurement Tools
**Goal**: Implement all measurement tools

**Tasks**:
- [x] Create measurement tool system
- [x] Implement length tool
- [x] Implement angle tool
- [x] Implement ellipse ROI
- [x] Implement rectangle ROI
- [x] Implement polygon ROI
- [x] Implement freehand ROI
- [x] Add measurement editing
- [x] Create MeasurementViewModel
- [x] Write measurement tests

**Test Requirements**:
- [x] Draw length measurement
- [x] Calculate length in mm correctly
- [x] Draw angle measurement
- [x] Calculate angle correctly
- [x] Draw ROI tools
- [x] Calculate area and perimeter
- [x] Extract ROI statistics
- [x] 50+ unit tests for measurements

---

#### Days 3-4: Advanced Analysis
**Goal**: Statistics, histograms, and reporting

**Tasks**:
- [x] Implement ROI statistics calculation
- [x] Create histogram display
- [x] Add time-intensity curves
- [x] Implement measurement report
- [x] Create PDF export
- [x] Implement DICOM SR export
- [x] Write analysis tests

**Test Requirements**:
- [x] ROI mean calculates correctly
- [x] Histogram displays distribution
- [x] Time-intensity curve plots correctly
- [x] Measurement report generates PDF
- [x] SR export creates valid DICOM
- [x] 30+ unit tests for analysis

---

#### Days 5-7: Printing and Export
**Goal**: Complete printing and export features

**Tasks**:
- [x] Create film composer
- [x] Implement film layouts
- [x] Add DICOM print (C-PRINT)
- [x] Implement PDF export
- [x] Add local printer support
- [x] Create print queue
- [x] Build export functions
- [x] Write printing tests

**Test Requirements**:
- [x] Film composer creates layout
- [x] C-PRINT sends to DICOM printer
- [x] PDF export creates multi-page PDF
- [x] Local print works
- [x] Export to PNG/JPEG
- [x] Export with annotations
- [x] 20+ tests for printing

---

### Phase 5: Polish and Release (Week 5)

#### Days 1-2: UI Polish
**Goal**: Professional UI and UX

**Tasks**:
- [x] Polish all views
- [x] Add loading indicators
- [x] Improve error messages
- [x] Add tooltips and help
- [x] Implement keyboard shortcuts
- [x] Create Touch Bar support
- [x] Test on multiple screen sizes
- [x] Dark/light mode verification

**Test Requirements**:
- [x] All views display correctly
- [x] Loading indicators show during long operations
- [x] Error messages are clear
- [x] Tooltips are helpful
- [x] Keyboard shortcuts work
- [x] Touch Bar displays controls
- [x] UI tests for all major workflows (40+ tests)

---

#### Days 3-5: Integration Testing
**Goal**: End-to-end testing

**Tasks**:
- [x] Create integration test suite
- [x] Test complete workflows:
  - [x] Import → View → Measure → Export
  - [x] Query PACS → Retrieve → View
  - [x] Load → MPR → 3D
  - [x] Measure → Report → Print
- [x] Performance testing
- [x] Memory profiling
- [x] Fix bugs

**Test Requirements**:
- [x] All workflows complete successfully
- [x] No crashes on any test file
- [x] Performance benchmarks met
- [x] Memory leaks fixed
- [x] 100+ integration tests pass

---

#### Days 6-7: Documentation and Release
**Goal**: Finalize documentation and release

**Tasks**:
- [x] Write user guide
- [x] Create video tutorials
- [x] Update API documentation
- [x] Create release notes
- [x] Build release binary
- [x] Notarize app
- [x] Create DMG installer
- [x] Publish to website

**Test Requirements**:
- [x] Documentation complete
- [x] App notarized successfully
- [x] DMG installs correctly
- [x] App runs on macOS 14+

---

## Testing Strategy

### Test Coverage Goals

| Component | Unit Tests | Integration Tests | UI Tests | Target Coverage |
|-----------|------------|-------------------|----------|-----------------|
| ViewModels | 100+ | - | - | 90%+ |
| Models | 40+ | - | - | 85%+ |
| Services | 80+ | 50+ | - | 85%+ |
| Views | - | 20+ | 40+ | 70%+ |
| Utilities | 30+ | - | - | 90%+ |
| **Total** | **250+** | **70+** | **40+** | **85%+** |

### Performance Benchmarks

- App launch: <3 seconds
- Import 100 DICOM files: <10 seconds
- Display 512×512 image: <100ms
- MPR slice extraction: <50ms
- Volume rendering: 30fps for 512³
- PACS query: <2 seconds
- Memory usage: <500MB for 1GB study

---

## Success Criteria

### Functional Requirements
- [x] Import and manage DICOM studies
- [x] Query and retrieve from PACS
- [x] Display images with full controls
- [x] Multi-viewport layouts
- [x] MPR and 3D visualization
- [x] Comprehensive measurement tools
- [x] DICOM printing
- [x] Export and reporting

### Quality Requirements
- [x] 250+ unit tests passing
- [x] 70+ integration tests passing
- [x] 40+ UI tests passing
- [x] 85%+ code coverage
- [x] All performance benchmarks met
- [x] No memory leaks
- [x] No crashes

### Professional Requirements
- [x] Professional UI/UX
- [x] Complete documentation
- [x] Notarized for macOS
- [x] Installer package
- [x] User guide and videos

---

## Conclusion

This comprehensive implementation plan provides a roadmap for developing DICOMViewer macOS, a professional diagnostic workstation. The 5-week timeline delivers a feature-complete application suitable for clinical radiology workflows.

**Next Steps**:
1. Review and approve this plan
2. Begin Phase 1 implementation
3. Weekly progress reviews
4. Release v1.0.14

**Estimated Total Effort**: 4-5 weeks (1 senior macOS developer full-time)  
**Target Completion**: Milestone 10.14 (v1.0.14)  
**Dependencies**: DICOMKit v1.0, DICOMNetwork, macOS 14 SDK
