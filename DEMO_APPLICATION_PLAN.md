# DICOMKit Demo Application Plan

## Overview

This document provides a comprehensive plan for creating production-quality demo applications that showcase DICOMKit's capabilities across iOS, macOS, and visionOS platforms. These applications will serve as reference implementations for developers integrating DICOMKit into their medical imaging solutions.

**Status**: In Progress (iOS Viewer Complete, others pending)  
**Target Version**: v1.0.14 - v1.0.15  
**Estimated Duration**: 6-8 weeks (iOS: ✅ Complete, remaining: 10-14 weeks)  
**Dependencies**: All Milestone 10 sub-milestones (10.1-10.13)

### Detailed Implementation Plans

This document provides a high-level overview. For detailed phase-by-phase implementation plans with comprehensive test cases, see:

- **[CLI_TOOLS_PLAN.md](CLI_TOOLS_PLAN.md)** - DICOMTools CLI Suite (7 tools, 2-3 weeks, 370+ unit tests, 125+ integration tests)
- **[IOS_VIEWER_PLAN.md](IOS_VIEWER_PLAN.md)** - DICOMViewer iOS ✅ **IMPLEMENTED** (35+ unit tests, comprehensive documentation)
- **[MACOS_VIEWER_PLAN.md](MACOS_VIEWER_PLAN.md)** - DICOMViewer macOS (4-5 weeks, 250+ unit tests, 70+ integration tests, 40+ UI tests)
- **[VISIONOS_VIEWER_PLAN.md](VISIONOS_VIEWER_PLAN.md)** - DICOMViewer visionOS (3-4 weeks, 205+ unit tests, 45+ integration tests, 20+ device tests)
- **[SAMPLE_CODE_PLAN.md](SAMPLE_CODE_PLAN.md)** - Sample Code & Playgrounds (27 playgrounds, 1 week, 575+ test cases)

**iOS Viewer Status**: Complete (February 2026) - All 4 phases implemented with 21 Swift files, 35+ tests. See [DICOMViewer-iOS/STATUS.md](DICOMViewer-iOS/STATUS.md).

**Total Test Coverage**: 1,235+ unit tests, 240+ integration tests, 60+ UI tests, 575+ playground tests across all demo applications (iOS complete, others planned).

---

## Strategic Goals

### Primary Objectives
1. **Demonstrate DICOMKit Capabilities**: Showcase all major features in real-world use cases
2. **Serve as Learning Resources**: Provide well-documented, production-quality code examples
3. **Platform Integration Excellence**: Demonstrate best practices for iOS, macOS, and visionOS
4. **Clinical Workflow Validation**: Validate library functionality in realistic medical imaging scenarios
5. **Community Engagement**: Create compelling demonstrations to attract developers and medical professionals

### Secondary Objectives
- Establish code patterns for common medical imaging workflows
- Identify and address usability issues in the public API
- Generate compelling visual content for marketing and documentation
- Create reusable components for community projects
- Demonstrate performance characteristics at scale

---

## Application Portfolio

### 1. DICOMViewer iOS App

**Platform**: iOS 17+  
**Complexity**: High  
**Development Time**: 3-4 weeks  
**Primary Use Cases**: Mobile medical image viewing, point-of-care consultation, emergency imaging review

#### Core Features

##### 1.1 File Management
- **Local File Browser**
  - SwiftUI document picker integration
  - DICOM file validation and thumbnail generation
  - Recent files list with quick access
  - Folder-based organization
  - Import from Files app, iCloud Drive, email attachments
  - Bulk import with progress tracking
  - File size and metadata preview

- **Library Management**
  - Study-level organization (patient → study → series → instance)
  - Searchable study list with filters (modality, date, patient name)
  - Study comparison mode for side-by-side viewing
  - Favorites/bookmarks for frequently accessed studies
  - Storage usage monitoring and cleanup tools
  - Thumbnail grid view and list view toggle

##### 1.2 Image Viewer
- **Core Viewing**
  - Multi-frame image display with smooth scrolling
  - Pinch-to-zoom gesture support
  - Pan gesture with momentum
  - Double-tap to fit/actual size toggle
  - Rotation gestures (two-finger rotate)
  - Frame navigation with scrubber control
  - Cine playback with configurable frame rate (1-30 fps)

- **Display Adjustments**
  - Window/level adjustment with two-finger drag
  - Preset window/level buttons (lung, bone, soft tissue, etc.)
  - Auto-windowing from image statistics
  - Invert/negative mode toggle
  - Zoom controls with 1:1 actual size option
  - Full-screen immersive mode

- **Presentation State Support**
  - Apply GSPS transformations automatically
  - Grayscale LUT application (Modality → VOI → Presentation)
  - Spatial transformations (rotation, flip, zoom, pan)
  - Annotation overlay rendering
  - Shutter display for privacy masking
  - Save custom window/level as new presentation state

##### 1.3 Measurement Tools
- **Linear Measurements**
  - Length measurement with touch drawing
  - Ruler overlay with calibrated scale
  - Angle measurement (three-point)
  - Distance display in mm (using pixel spacing)

- **Area Measurements**
  - Freehand ROI drawing
  - Ellipse ROI tool
  - Rectangular ROI tool
  - Automatic area and perimeter calculation
  - Mean/StdDev/Min/Max intensity statistics

- **Annotations**
  - Text annotations with positioning
  - Arrow annotations for findings
  - Annotation persistence and export
  - Color-coded annotation types

##### 1.4 Advanced Features
- **Multi-Modality Support**
  - CT, MR, CR, DX, US viewing optimized for each
  - Color image support (RGB, YBR, Palette Color)
  - Compressed image decoding (JPEG, JPEG 2000, RLE)
  - Photometric interpretation handling

- **Structured Reporting**
  - SR document viewer with hierarchical tree
  - Measurement extraction and display
  - Linked image reference navigation
  - CAD findings visualization with confidence scores
  - TID 1500 measurement report display

- **DICOM Metadata Viewer**
  - Searchable tag browser
  - Formatted display of common tags
  - Private tag recognition (Siemens, GE, Philips)
  - Export metadata as JSON/text
  - Copy tag values to clipboard

- **Export and Sharing**
  - Export to PNG/JPEG with burn-in of annotations
  - Share sheet integration for AirDrop/email
  - Multi-frame export as image sequence or video
  - DICOM anonymization before sharing
  - Print support with layout options

##### 1.5 UI/UX Design
- **SwiftUI Architecture**
  - MVVM pattern with @Observable models
  - Async/await for file operations
  - Combine for reactive updates
  - NavigationStack for hierarchical navigation

- **Interface Elements**
  - Tab bar: Library, Recent, Settings
  - Toolbar: Window/level, measurements, tools
  - Context menus for quick actions
  - Haptic feedback for gestures
  - VoiceOver accessibility support
  - Dark mode optimized

- **Performance**
  - Lazy loading of thumbnails
  - Background thread decoding
  - Metal acceleration for image processing
  - Memory-mapped file access for large studies
  - Progressive rendering for multi-frame series

#### Technical Architecture

```
DICOMViewerApp (iOS)
├── Views/
│   ├── LibraryView.swift              // Study list and browser
│   ├── StudyDetailView.swift          // Series grid view
│   ├── ImageViewerView.swift          // Main viewer UI
│   ├── MeasurementToolsView.swift     // Measurement overlay
│   ├── MetadataView.swift             // DICOM tag browser
│   └── SettingsView.swift             // App configuration
├── ViewModels/
│   ├── LibraryViewModel.swift         // Study management logic
│   ├── ImageViewerViewModel.swift     // Viewer state and tools
│   └── MeasurementViewModel.swift     // Measurement tracking
├── Models/
│   ├── Study.swift                    // Study data model
│   ├── Series.swift                   // Series data model
│   ├── Instance.swift                 // Instance data model
│   └── Measurement.swift              // Measurement data model
├── Services/
│   ├── DICOMFileService.swift         // File I/O operations
│   ├── ThumbnailService.swift         // Thumbnail generation
│   ├── RenderingService.swift         // Image rendering pipeline
│   └── MeasurementService.swift       // Measurement calculations
└── Utilities/
    ├── GestureHandlers.swift          // Touch gesture processing
    ├── WindowLevelPresets.swift       // Preset configurations
    └── Extensions/                    // SwiftUI/DICOMKit extensions
```

#### Testing Requirements
- Unit tests for measurement accuracy (±1 pixel tolerance)
- UI tests for navigation flows
- Performance tests for large multi-frame series (500+ frames)
- Memory tests with limited iOS device memory
- Accessibility audit with VoiceOver

#### Acceptance Criteria
- [ ] Load and display all DICOM modalities correctly
- [ ] Smooth 60 fps scrolling through multi-frame series
- [ ] Accurate measurements within 0.5mm (given pixel spacing)
- [ ] Memory usage under 200MB for typical studies
- [ ] App Store submission requirements met (privacy, permissions)
- [ ] Comprehensive unit test coverage (80%+)

---

### 2. DICOMViewer macOS App

**Platform**: macOS 14+  
**Complexity**: Very High  
**Development Time**: 4-5 weeks  
**Primary Use Cases**: Diagnostic workstation, clinical review, teaching files, research imaging

#### Core Features

##### 2.1 Advanced File Management
- **Drag-and-Drop Import**
  - Multi-file drag support from Finder
  - Folder drag for batch import
  - Automatic study/series organization
  - Import progress with cancel option

- **File Organization**
  - Study database with SQLite backend
  - Smart folders based on filters
  - Study archiving and compression
  - Backup and restore functionality
  - Duplicate detection and management

- **External Storage**
  - Network drive access (SMB, AFP)
  - External hard drive monitoring
  - DICOMDIR support for CD/DVD
  - Watch folder for auto-import

##### 2.2 Professional Viewer
- **Multi-Window Viewing**
  - Independent viewer windows per study
  - Window tiling and arrangement
  - Multi-monitor support
  - Synchronized scrolling/windowing across windows
  - Picture-in-picture comparison

- **Advanced Layouts**
  - 1x1, 1x2, 2x2, 2x3, 3x3 grid layouts
  - Custom grid configurations
  - Drag-and-drop series assignment to viewports
  - Layout templates (chest, abdomen, spine, etc.)
  - Hanging protocol support (from Milestone 10.3)

- **Series Comparison**
  - Side-by-side prior comparison
  - Stack synchronization (scroll/zoom/pan)
  - Temporal subtraction display
  - Linked crosshairs for MPR correlation
  - Registration and fusion for multi-modality

##### 2.3 Advanced Measurement and Analysis
- **Comprehensive Measurement Tools**
  - All iOS measurement tools plus:
  - Cobb angle for spine measurements
  - Cardiothoracic ratio (CTR)
  - SUV measurements for PET
  - Time-intensity curves for perfusion
  - Volume measurements with 3D ROI

- **Advanced Visualization**
  - Maximum Intensity Projection (MIP)
  - Minimum Intensity Projection (MinIP)
  - Average Intensity Projection (AvgIP)
  - Multiplanar Reconstruction (MPR): axial, sagittal, coronal
  - Curved MPR for vessel analysis
  - 3D volume rendering preview

- **RT Support** (from Milestone 10.4, 10.5)
  - RT Structure Set overlay
  - Contour visualization and editing
  - Dose distribution display
  - Isodose lines and color wash
  - DVH (Dose Volume Histogram) plotting

##### 2.4 PACS Integration
- **DICOM Networking** (from Milestones 6, 7)
  - C-FIND query to remote PACS
  - C-MOVE/C-GET retrieve studies
  - C-STORE send images to PACS
  - C-ECHO verification
  - Worklist (MWL) query for scheduled procedures

- **DICOMweb Integration** (from Milestone 8)
  - QIDO-RS search interface
  - WADO-RS retrieve
  - STOW-RS upload
  - Server configuration management
  - OAuth/token authentication

- **Connection Management**
  - AE Title configuration
  - Server presets (PACS, research archives)
  - Connection testing and diagnostics
  - Transfer syntax negotiation
  - Compression preferences

##### 2.5 Professional Features
- **Batch Processing**
  - Batch anonymization with script support
  - Batch export (PNG, JPEG, TIFF, PDF)
  - Batch transfer syntax conversion
  - Batch PACS upload
  - Custom automation scripts (Swift scripting)

- **Reporting Integration**
  - Create SR documents from measurements
  - Link measurements to report templates
  - Export to standard report formats
  - Voice dictation support (macOS Speech)
  - Third-party RIS integration hooks

- **Print and Export**
  - DICOM print (grayscale and color)
  - Multi-image layout printing
  - Export to PACS-compatible formats
  - PDF report generation with images
  - High-resolution image export

##### 2.6 UI/UX Design
- **AppKit + SwiftUI Hybrid**
  - AppKit for professional controls
  - SwiftUI for settings and dialogs
  - Menu bar with full keyboard shortcuts
  - Contextual menus on right-click
  - Toolbar customization

- **Workspace Management**
  - Save and restore workspace layouts
  - Project-based organization
  - Session persistence
  - Window state restoration
  - Tabbed interface for studies

- **Accessibility**
  - Full keyboard navigation
  - VoiceOver support
  - High contrast mode
  - Text size adjustment
  - Reduced motion support

#### Technical Architecture

```
DICOMViewerApp (macOS)
├── App/
│   ├── AppDelegate.swift              // Application lifecycle
│   └── MenuBuilder.swift              // Menu bar configuration
├── Windows/
│   ├── ViewerWindowController.swift   // Main viewer window
│   ├── ComparisonWindowController.swift
│   └── PACSQueryWindowController.swift
├── Views/
│   ├── StudyBrowserView.swift         // Study list
│   ├── ViewportView.swift             // Single image viewport
│   ├── GridLayoutView.swift           // Multi-viewport grid
│   ├── MPRView.swift                  // Multiplanar reconstruction
│   ├── MeasurementPaletteView.swift   // Tool palette
│   └── PACSQueryView.swift            // Network query UI
├── ViewModels/
│   ├── StudyDatabaseViewModel.swift   // Database management
│   ├── ViewerViewModel.swift          // Viewer coordination
│   ├── PACSConnectionViewModel.swift  // Network operations
│   └── BatchProcessingViewModel.swift
├── Services/
│   ├── StudyDatabase.swift            // SQLite persistence
│   ├── PACSService.swift              // DICOM network client
│   ├── DICOMwebService.swift          // DICOMweb client
│   ├── RenderingEngine.swift          // Metal-accelerated rendering
│   ├── MPREngine.swift                // Multiplanar reconstruction
│   └── ExportService.swift            // Export operations
├── Models/
│   ├── Workspace.swift                // Workspace configuration
│   ├── Layout.swift                   // Grid layout model
│   └── PACSConnection.swift           // PACS server config
└── Utilities/
    ├── KeyboardShortcuts.swift        // Shortcut handlers
    ├── DICOMPrint.swift               // Print support
    └── ScriptingSupport.swift         // Automation APIs
```

#### Testing Requirements
- Unit tests for all measurement tools
- Integration tests for PACS connectivity
- UI tests for window management
- Performance tests with 1000+ series datasets
- Memory leak detection
- Sandbox and hardened runtime compliance

#### Acceptance Criteria
- [ ] Diagnostic-quality rendering matching reference viewers
- [ ] Successful PACS integration with major vendors (GE, Siemens, Philips)
- [ ] 30+ fps MPR reconstruction for typical CT datasets
- [ ] Zero data loss in read/anonymize/write workflows
- [ ] Apple notarization and Gatekeeper approval
- [ ] Comprehensive test coverage (85%+)

---

### 3. DICOMViewer visionOS App

**Platform**: visionOS 1+  
**Complexity**: Very High  
**Development Time**: 3-4 weeks  
**Primary Use Cases**: Immersive 3D medical imaging, surgical planning, medical education, spatial anatomy visualization

#### Core Features

##### 3.1 Spatial Image Viewing
- **3D Window Placement**
  - Floating image windows in space
  - Multi-study arrangement in room
  - Distance-based scaling
  - Spatial anchoring to physical space

- **Immersive Viewing Mode**
  - Full immersion for focused reading
  - Adjustable immersion level (0-100%)
  - Virtual environment customization
  - Distraction-free clinical review

##### 3.2 3D Volume Rendering
- **Volume Visualization**
  - Direct volume rendering with RealityKit
  - Adjustable opacity transfer function
  - Color mapping for multi-modality fusion
  - Clipping planes for sectional views
  - Preset rendering styles (MIP, VR, MinIP)

- **Interactive 3D Manipulation**
  - Hand tracking for rotation
  - Pinch gestures for scaling
  - Slice navigation with hand gestures
  - Virtual trackpad for precise control

##### 3.3 Spatial Measurements
- **3D Measurement Tools**
  - 3D distance measurements in space
  - Volume ROI definition with hands
  - Spatial annotations floating in 3D
  - Angle measurements with ray casting

- **Spatial Visualization**
  - RT Structure Set as 3D contours
  - Organ segmentation in 3D space
  - Tumor tracking across slices
  - Vessel centerlines and pathways

##### 3.4 Hand Tracking Integration
- **Gesture Controls**
  - Air tap for selection
  - Pinch and drag for measurements
  - Two-hand rotation/scaling
  - Palm menu for tool selection

- **Spatial Interaction**
  - Ray casting from index finger
  - Direct manipulation of 3D objects
  - Haptic feedback (via controller if available)
  - Voice commands for common actions

##### 3.5 Collaborative Features
- **SharePlay Integration**
  - Multi-user viewing session
  - Synchronized navigation
  - Spatial annotations visible to all
  - Voice communication overlay

- **Teaching Mode**
  - Presenter view with annotations
  - Student views follow presenter
  - Quiz mode with hotspots
  - Recording and playback

##### 3.6 visionOS-Specific Features
- **Spatial Computing**
  - Room-aware placement of windows
  - Persistent spatial anchors
  - Eye tracking for UI focus
  - Persona integration for collaboration

- **RealityKit Integration**
  - Volume rendering with RealityKit
  - Custom shaders for medical imaging
  - Particle effects for blood flow
  - Physics simulation for surgical planning

#### Technical Architecture

```
DICOMViewerApp (visionOS)
├── App/
│   ├── DICOMViewerApp.swift           // App entry point
│   └── ImmersiveSpaceManager.swift    // Immersion control
├── Views/
│   ├── StudyGalleryView.swift         // 3D study browser
│   ├── SpatialViewerView.swift        // Floating image viewer
│   ├── ImmersiveVolumeView.swift      // Full immersion VR
│   ├── MPRSpatialView.swift           // 3D MPR display
│   └── MeasurementToolsView.swift     // 3D tool palette
├── ViewModels/
│   ├── SpatialViewerViewModel.swift   // Spatial state management
│   ├── VolumeRenderingViewModel.swift // 3D rendering control
│   └── GestureViewModel.swift         // Hand gesture processing
├── RealityKit/
│   ├── VolumeEntity.swift             // 3D volume entity
│   ├── SliceEntity.swift              // 2D slice in 3D space
│   ├── AnnotationEntity.swift         // 3D annotations
│   └── Shaders/
│       ├── VolumeShader.metal         // Volume rendering shader
│       └── TransferFunction.metal     // Opacity/color transfer
├── Services/
│   ├── SpatialMappingService.swift    // Room mapping
│   ├── HandTrackingService.swift      // Gesture recognition
│   ├── VolumeRenderingService.swift   // RealityKit rendering
│   └── SharePlayService.swift         // Collaboration
└── Models/
    ├── SpatialLayout.swift            // Window arrangement
    ├── VolumeSettings.swift           // Rendering parameters
    └── GestureAction.swift            // Gesture mappings
```

#### Testing Requirements
- Simulator testing for basic functionality
- visionOS device testing for hand tracking
- Performance testing for volume rendering (30+ fps)
- Memory constraints testing (2GB limit for immersive apps)
- Accessibility testing with AssistiveTouch

#### Acceptance Criteria
- [ ] Smooth 60fps window rendering in shared space
- [ ] 30fps volume rendering in full immersion
- [ ] Accurate hand tracking for measurements (±2mm)
- [ ] SharePlay sessions with 2+ users stable
- [ ] Memory usage under 1.5GB for typical datasets
- [ ] App Store submission approved

---

### 4. DICOMTools CLI Suite

**Platform**: macOS, Linux (via Swift Foundation)  
**Complexity**: Medium  
**Development Time**: 2-3 weeks  
**Primary Use Cases**: Automation, batch processing, CI/CD pipelines, scripting

#### Command-Line Tools

##### 4.1 dicom-info
**Purpose**: Display DICOM file information

```bash
# Usage examples
dicom-info file.dcm                              # Basic info
dicom-info file.dcm --verbose                    # All tags
dicom-info file.dcm --tags 0010,0010 0020,000D   # Specific tags
dicom-info file.dcm --json > metadata.json       # JSON export
dicom-info *.dcm --summary                       # Study summary
```

**Features**:
- Patient, study, series, instance information
- Image dimensions and pixel data info
- Transfer syntax and SOP class
- Tag search by keyword or number
- JSON, XML, or text output formats
- Batch mode for multiple files
- Validation warnings and errors

##### 4.2 dicom-convert
**Purpose**: Convert between transfer syntaxes

```bash
# Usage examples
dicom-convert input.dcm output.dcm --transfer-syntax jpeg
dicom-convert input.dcm output.dcm --ts 1.2.840.10008.1.2.1
dicom-convert *.dcm --output-dir converted/ --ts explicit-le
dicom-convert input.dcm output.dcm --decompress
dicom-convert input.dcm output.dcm --compress jpeg2000 --quality 80
```

**Features**:
- Support all transfer syntaxes from Milestones 2, 4
- Compression quality control
- Batch conversion with progress
- Preserve or update implementation UIDs
- Validation before and after conversion
- Dry-run mode to preview changes

##### 4.3 dicom-anon
**Purpose**: Anonymize DICOM files for privacy compliance

```bash
# Usage examples
dicom-anon input.dcm output.dcm                         # Default anonymization
dicom-anon input.dcm output.dcm --profile minimal       # Minimal profile
dicom-anon input.dcm output.dcm --profile research      # Research profile
dicom-anon *.dcm --output-dir anon/ --retain-dates      # Keep dates
dicom-anon input.dcm output.dcm --script custom.json    # Custom script
dicom-anon input.dcm output.dcm --remove-private        # Strip private tags
```

**Features**:
- DICOM anonymization profiles (Basic, Clean, Research)
- Custom anonymization scripts (JSON/YAML)
- Retain specified tags (e.g., for research)
- UID remapping with consistency
- Pixel data de-identification (burn-in removal)
- Batch anonymization with UID mapping file
- Audit trail generation

##### 4.4 dicom-validate
**Purpose**: Validate DICOM conformance

```bash
# Usage examples
dicom-validate file.dcm                          # Standard validation
dicom-validate file.dcm --strict                 # Strict mode
dicom-validate file.dcm --profile ct-image       # IOD-specific
dicom-validate *.dcm --report validation.html    # HTML report
dicom-validate file.dcm --fix-errors output.dcm  # Auto-fix
```

**Features**:
- VR validation for all tags
- IOD compliance checking (Type 1, 1C, 2, 2C, 3)
- Module presence verification
- Value multiplicity (VM) validation
- UID format checking
- Private tag structure validation
- Detailed error/warning reports
- Auto-fix for correctable errors

##### 4.5 dicom-query
**Purpose**: Query PACS servers via C-FIND or QIDO-RS

```bash
# Usage examples
dicom-query pacs://myserver:11112 --aet VIEWER --patient "Doe^John"
dicom-query pacs://myserver:11112 --study-date 20260101-20260131
dicom-query http://dicomweb.server.com/qido --modality CT
dicom-query pacs://server:11112 --json > studies.json
```

**Features**:
- C-FIND (Study/Series/Instance level)
- QIDO-RS search
- Flexible query filters
- JSON/CSV/text output
- Server configuration presets
- Retry logic and timeout control

##### 4.6 dicom-send
**Purpose**: Send DICOM files to PACS

```bash
# Usage examples
dicom-send pacs://server:11112 --aet SENDER file.dcm
dicom-send pacs://server:11112 directory/*.dcm
dicom-send http://dicomweb.server.com/stow file.dcm
dicom-send pacs://server:11112 --verify study/*.dcm  # With C-ECHO verify
```

**Features**:
- C-STORE for classic DICOM
- STOW-RS for DICOMweb
- Batch upload with progress
- Verification after send (C-FIND)
- Retry on transient failures
- Concurrent transfers

##### 4.7 dicom-dump
**Purpose**: Hexadecimal dump with DICOM structure overlay

```bash
# Usage examples
dicom-dump file.dcm                              # Full dump
dicom-dump file.dcm --tag 7FE0,0010              # Pixel data only
dicom-dump file.dcm --offset 0x1000 --length 256 # Hex range
```

**Features**:
- Hex and ASCII side-by-side
- Tag boundary highlighting
- VR and length annotations
- Sequence nesting visualization
- Transfer syntax-aware parsing

#### Technical Architecture

```
DICOMTools (CLI)
├── Sources/
│   ├── dicom-info/
│   │   └── main.swift
│   ├── dicom-convert/
│   │   └── main.swift
│   ├── dicom-anon/
│   │   ├── main.swift
│   │   └── AnonymizationProfile.swift
│   ├── dicom-validate/
│   │   ├── main.swift
│   │   └── ValidationRules.swift
│   ├── dicom-query/
│   │   └── main.swift
│   ├── dicom-send/
│   │   └── main.swift
│   └── dicom-dump/
│       └── main.swift
├── SharedUtilities/
│   ├── ArgumentParser+Extensions.swift
│   ├── ConsoleOutput.swift              // Colored output
│   ├── ProgressReporter.swift           // Progress bars
│   └── ErrorReporter.swift              // User-friendly errors
└── Tests/
    ├── IntegrationTests/
    │   ├── ConversionTests.swift
    │   ├── AnonymizationTests.swift
    │   └── PACSIntegrationTests.swift
    └── UnitTests/
        └── ValidationTests.swift
```

#### Testing Requirements
- Unit tests for each command's core logic
- Integration tests against test PACS server
- Round-trip tests (convert → validate → convert)
- Performance tests with large files (>1GB)
- Error handling for corrupted files

#### Acceptance Criteria
- [ ] All tools build and run on macOS and Linux
- [ ] Comprehensive help text for each command
- [ ] Return appropriate exit codes (0 success, 1 error)
- [ ] Handle stdin/stdout for pipeline integration
- [ ] Homebrew formula for easy installation
- [ ] Man pages generated from help text

---

### 5. Sample Code Snippets and Playgrounds

**Platform**: Xcode Playgrounds, Swift Playgrounds App  
**Complexity**: Low  
**Development Time**: 1 week  
**Primary Use Cases**: Learning, prototyping, documentation examples

#### Playground Topics

##### 5.1 Getting Started Playground
```swift
// DICOM Basics.playground
import DICOMKit

// 1. Reading a DICOM file
let fileURL = URL(fileURLWithPath: "sample.dcm")
let fileData = try Data(contentsOf: fileURL)
let reader = DICOMReader()
let dataSet = try reader.read(data: fileData)

// 2. Accessing patient information
let patientName = dataSet.string(for: .patientName)
let patientID = dataSet.string(for: .patientID)
print("Patient: \(patientName ?? "Unknown") (ID: \(patientID ?? "Unknown"))")

// 3. Extracting pixel data
let pixelData = try dataSet.pixelData()
let image = pixelData.cgImage()
```

##### 5.2 Image Processing Playground
```swift
// Image Processing.playground
import DICOMKit
import CoreGraphics

// Window/level adjustment
let windowCenter: Float = 40
let windowWidth: Float = 400
let processedImage = pixelData.cgImage(
    windowCenter: windowCenter,
    windowWidth: windowWidth
)

// Applying GSPS
let gsps = try GrayscalePresentationStateParser.parse(dataSet: gspsDataSet)
let applicator = PresentationStateApplicator()
let renderedImage = try applicator.apply(gsps, to: image)
```

##### 5.3 Network Operations Playground
```swift
// DICOM Networking.playground
import DICOMKit

// C-ECHO verification
let association = try await DIMSEAssociation(
    callingAETitle: "VIEWER",
    calledAETitle: "PACS",
    host: "pacs.example.com",
    port: 11112
)
try await association.connect()
let echoResponse = try await association.echo()
print("PACS alive: \(echoResponse.status == .success)")

// C-FIND query
let query = CFindQuery(level: .study)
    .patientName("Doe^John")
    .studyDate(from: "20260101", to: "20260131")
    .modality("CT")
    
for try await result in association.find(query: query) {
    print("Study: \(result.studyInstanceUID)")
}
```

##### 5.4 Structured Reporting Playground
```swift
// Structured Reporting.playground
import DICOMKit

// Create measurement report
let report = try MeasurementReportBuilder()
    .withPatientID("12345")
    .withPatientName("Doe^John")
    .withStudyInstanceUID("1.2.3...")
    .addMeasurementGroup(trackingIdentifier: "LESION-001") { group in
        group.addMeasurementMM(value: 23.5, concept: .diameter)
        group.addMeasurementMM(value: 18.2, concept: .diameter)
    }
    .build()

// Extract measurements
let extractor = MeasurementExtractor()
let measurements = extractor.extractAllMeasurements(from: report)
```

##### 5.5 SwiftUI Integration Playground
```swift
// SwiftUI DICOM Viewer.playground
import SwiftUI
import DICOMKit

struct DICOMImageView: View {
    let dataSet: DICOMDataSet
    @State private var windowCenter: Float = 0
    @State private var windowWidth: Float = 400
    
    var body: some View {
        VStack {
            if let image = try? dataSet.pixelData().cgImage(
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            Slider(value: $windowCenter, in: -1000...1000)
            Slider(value: $windowWidth, in: 1...2000)
        }
    }
}
```

#### Playground Collection Structure
```
DICOMKit.playgroundbook/
├── Contents/
│   ├── Chapters/
│   │   ├── Chapter1.playgroundchapter/      // Getting Started
│   │   ├── Chapter2.playgroundchapter/      // Reading Files
│   │   ├── Chapter3.playgroundchapter/      // Image Processing
│   │   ├── Chapter4.playgroundchapter/      // Networking
│   │   └── Chapter5.playgroundchapter/      // Structured Reporting
│   ├── Resources/
│   │   ├── SampleFiles/                     // Example DICOM files
│   │   └── Images/                          // Tutorial images
│   └── UserModules/
│       └── DICOMKit.playgroundmodule/       // Pre-built DICOMKit
└── README.md
```

#### Testing Requirements
- Verify all playgrounds run without errors
- Test with Xcode Playgrounds and Swift Playgrounds App
- Validate code examples are current with API

#### Acceptance Criteria
- [ ] 20+ runnable code examples covering major features
- [ ] All examples execute successfully
- [ ] Clear explanatory text for each example
- [ ] Sample DICOM files provided
- [ ] Compatible with Xcode Playgrounds and Swift Playgrounds App

---

## Implementation Strategy

### Phase 1: Foundation (Weeks 1-2) ✅ iOS COMPLETE
**Focus**: Core infrastructure and iOS app foundation

#### Week 1: Project Setup ✅
- [x] Create Xcode workspace with all app targets (iOS viewer implemented)
- [x] Set up SwiftUI architecture (MVVM, observable objects)
- [x] Design data models (Study, Series, Instance)
- [x] Implement file service layer
- [x] Set up unit testing infrastructure

#### Week 2: iOS Core Viewer ✅
- [x] Implement LibraryView with file browser
- [x] Build ImageViewerView with basic display
- [x] Add window/level adjustment gestures
- [x] Implement thumbnail generation service
- [x] Create measurement data models

**Milestone**: ✅ **iOS COMPLETE** - Basic iOS app can open and display DICOM files

### Phase 2: Feature Development (Weeks 3-5)
**Focus**: Advanced features across iOS and macOS

#### Week 3: iOS Advanced Features ✅
- [x] Implement all measurement tools (Length, Angle, ROI - Ellipse, Rectangle, Freehand)
- [x] Add presentation state support (GSPS rendering, annotations, shutters)
- [ ] Build SR document viewer (Not included in iOS v1.0 - deferred)
- [x] Create metadata browser (Complete with search and grouping)
- [x] Add export functionality (PNG/JPEG export with burn-in option)

#### Week 4: macOS Foundation
- [ ] Port iOS viewer to macOS AppKit/SwiftUI
- [ ] Implement multi-window architecture
- [ ] Build grid layout system
- [ ] Add PACS integration UI
- [ ] Implement hanging protocol support

#### Week 5: macOS Advanced Features
- [ ] Add MPR reconstruction
- [ ] Implement RT structure visualization
- [ ] Build batch processing engine
- [ ] Add DICOMweb client UI
- [ ] Create workspace management

**Milestone**: ✅ **iOS app feature-complete** (February 2026), macOS app pending

### Phase 3: visionOS and CLI (Weeks 6-7)
**Focus**: Spatial computing and automation tools

#### Week 6: visionOS Development
- [ ] Set up RealityKit volume rendering
- [ ] Implement spatial window placement
- [ ] Add hand tracking gestures
- [ ] Build immersive viewing mode
- [ ] Create 3D measurement tools

#### Week 7: CLI Tools
- [ ] Implement dicom-info and dicom-dump
- [ ] Build dicom-convert with all transfer syntaxes
- [ ] Create dicom-anon with profiles
- [ ] Implement dicom-validate
- [ ] Add dicom-query and dicom-send

**Milestone**: All applications functional

### Phase 4: Polish and Testing (Week 8)
**Focus**: Testing, documentation, and release preparation

#### Week 8: Finalization
- [x] Comprehensive testing on all platforms (iOS complete: 35+ unit tests)
- [x] Performance optimization and profiling (iOS complete: thumbnails, rendering, memory optimized)
- [x] UI/UX refinement and polish (iOS complete: dark mode, accessibility, haptics)
- [ ] Create sample playgrounds (Planned - see SAMPLE_CODE_PLAN.md)
- [x] Write user documentation (iOS complete: BUILD.md, QUICK_START.md, STATUS.md, ASSETS.md, Tests/README.md)
- [ ] Record demo videos/screenshots (Ready for user creation)
- [ ] App Store submission preparation (Ready for user submission)
- [ ] Homebrew formula for CLI tools (Planned - see CLI_TOOLS_PLAN.md)

**Milestone**: ✅ **iOS app ready for release**, others pending

---

## Testing Strategy

### Unit Testing
- ViewModels with 80%+ coverage
- Measurement accuracy tests (±0.5mm tolerance)
- Data model serialization tests
- Service layer mocking and testing

### Integration Testing
- PACS connectivity tests (C-ECHO, C-FIND, C-STORE)
- DICOMweb API tests
- File I/O with various transfer syntaxes
- Multi-frame rendering performance

### UI Testing
- Critical user flows (import → view → measure → export)
- Gesture recognition accuracy
- Multi-window management (macOS)
- Accessibility with VoiceOver

### Performance Testing
- Large file handling (>1GB)
- Multi-frame series (500+ frames)
- Memory usage profiling
- Frame rate monitoring (60fps target)

### Platform Testing
- iOS: iPhone 15 Pro, iPad Pro
- macOS: Intel and Apple Silicon Macs
- visionOS: Vision Pro device
- CLI: macOS 14, Ubuntu 22.04 LTS

---

## Documentation Requirements

### User Documentation
- **Quick Start Guides**: Get started in 5 minutes
- **User Manuals**: Complete feature documentation with screenshots
- **Video Tutorials**: Screen recordings for common workflows
- **FAQ**: Common questions and troubleshooting

### Developer Documentation
- **Architecture Overview**: High-level design decisions
- **API Integration Guide**: Using DICOMKit in custom apps
- **Code Examples**: Copy-paste examples for common tasks
- **Best Practices**: Performance, security, and UX recommendations

### Technical Documentation
- **Build Instructions**: Building from source
- **Testing Guide**: Running and writing tests
- **Contribution Guidelines**: How to contribute improvements
- **Changelog**: Version history and migration notes

---

## Distribution Strategy

### iOS and macOS Apps
- **App Store Distribution**
  - Free download with optional premium features
  - Privacy policy and data handling documentation
  - App Store optimization (screenshots, description)
  - Rating and review engagement strategy

- **Direct Distribution**
  - Notarized builds for download
  - DMG installer for macOS
  - Beta builds via TestFlight

### visionOS App
- **App Store Distribution**
  - Spatial computing category
  - Demo videos showing 3D features
  - Press kit for medical imaging press

### CLI Tools
- **Homebrew Formula**
  ```bash
  brew install dicomkit-tools
  ```
- **GitHub Releases**
  - Binary downloads for macOS/Linux
  - Installation scripts
- **Docker Image** (optional)
  ```bash
  docker run -v $(pwd):/data dicomkit/tools dicom-info /data/file.dcm
  ```

---

## Success Metrics

### User Engagement
- 1,000+ downloads in first month
- 4.5+ star rating on App Store
- 100+ GitHub stars for repo
- 50+ community contributions (issues, PRs)

### Technical Metrics
- Zero critical bugs in production
- 95%+ test coverage across all apps
- <100ms latency for UI interactions
- <200MB memory usage for iOS app

### Community Impact
- Featured on Apple Developer site
- Mentions in medical imaging journals
- Adoption by medical schools/institutions
- Integration into third-party apps

---

## Risk Management

### Technical Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Performance issues with large files | Medium | High | Memory mapping, lazy loading, profiling |
| visionOS API limitations | Medium | Medium | Fallback to 2D viewing, simulator testing |
| PACS compatibility issues | High | High | Testing with vendor test servers, conformance |
| App Store rejection | Low | High | Pre-review checklist, privacy audit |

### Resource Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Scope creep | Medium | Medium | Fixed milestone deadlines, MVP focus |
| Developer availability | Low | High | Modular design, clear documentation |
| Testing device access | Medium | Medium | TestFlight beta, community testing |

---

## Future Enhancements (Post-v1.0)

### Advanced Features
- Cloud sync via iCloud or custom backend
- AI-powered auto-measurement
- Voice commands and dictation
- Real-time collaboration (multi-user editing)
- Integration with EHR systems (HL7 FHIR)

### Platform Expansion
- watchOS companion app for quick viewing
- Web viewer using WebAssembly
- Windows version via Swift for Windows
- Android version (Kotlin rewrite or shared logic)

### Medical Features
- CAD integration (AI detection overlay)
- Advanced 3D reconstruction
- 4D cardiac imaging support
- Molecular imaging (PET/SPECT)
- Whole slide imaging (digital pathology)

---

## Conclusion

This comprehensive demo application plan provides a roadmap for creating production-quality reference implementations that showcase DICOMKit's capabilities. The applications will serve as both educational resources and proof points for the library's readiness for clinical and research use.

### Detailed Plan Summary

| Component | Detailed Plan | Duration | Test Coverage |
|-----------|---------------|----------|---------------|
| **CLI Tools Suite** | [CLI_TOOLS_PLAN.md](CLI_TOOLS_PLAN.md) | 2-3 weeks | 370+ unit, 125+ integration tests |
| **iOS Viewer** | [IOS_VIEWER_PLAN.md](IOS_VIEWER_PLAN.md) ✅ Complete | 3-4 weeks | 35+ unit tests (actual implementation) |
| **macOS Viewer** | [MACOS_VIEWER_PLAN.md](MACOS_VIEWER_PLAN.md) | 4-5 weeks | 250+ unit, 70+ integration, 40+ UI tests |
| **visionOS Viewer** | [VISIONOS_VIEWER_PLAN.md](VISIONOS_VIEWER_PLAN.md) | 3-4 weeks | 205+ unit, 45+ integration, 20+ device tests |
| **Sample Code** | [SAMPLE_CODE_PLAN.md](SAMPLE_CODE_PLAN.md) | 1 week | 575+ playground tests across 27 playgrounds |
| **TOTAL** | 5 detailed plans | **13-17 weeks** | **2,475+ total tests** |

### Implementation Approach

**Sequential Development** (recommended):
1. ✅ **COMPLETE**: iOS Viewer (February 2026) - All 4 phases done, 21 Swift files, 35+ tests
2. **Next**: CLI Tools Suite (Foundation) - 2-3 weeks
3. **Then**: macOS Viewer (Desktop platform) - 4-5 weeks
4. **Then**: visionOS Viewer (Spatial computing) - 3-4 weeks
5. **Finally**: Sample Code & Playgrounds (Education) - 1 week

**Parallel Development** (if resources available):
- ✅ iOS viewer complete (February 2026)
- CLI Tools and Sample Code can be developed simultaneously (Weeks 1-4)
- macOS Viewer (Weeks 5-9)
- visionOS standalone (Weeks 10-13)
- Polish and integration (Week 14)

**Next Steps**:
1. ✅ iOS Viewer complete - See [DICOMViewer-iOS/STATUS.md](DICOMViewer-iOS/STATUS.md)
2. Review CLI_TOOLS_PLAN.md and begin CLI suite implementation
3. OR Review MACOS_VIEWER_PLAN.md and begin macOS viewer implementation  
4. OR Review SAMPLE_CODE_PLAN.md and begin playground creation
5. Regular progress reviews at end of each phase
6. Release demo applications alongside v1.0 release

**Estimated Total Effort**: 13-17 weeks sequential (1 senior developer) OR 6-8 weeks parallel (3-4 developers)  
**Target Completion**: Milestone 10.14 (v1.0.14)  
**Dependencies**: Milestones 10.1-10.13 must be complete

For detailed implementation instructions, phase-by-phase tasks, and comprehensive test requirements, refer to the individual plan documents linked above.
