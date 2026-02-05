# DICOMViewer iOS - Implementation Plan

## Overview

**Status**: Ready for Implementation (Post-Milestone 10.13)  
**Target Version**: v1.0.14  
**Estimated Duration**: 3-4 weeks  
**Developer Effort**: 1 senior iOS developer  
**Platform**: iOS 17+, iPadOS 17+  
**Dependencies**: DICOMKit v1.0, SwiftUI, UIKit

This document provides a comprehensive phase-by-phase implementation plan for DICOMViewer iOS, a mobile medical image viewer with gestures, measurements, and presentation state support. The app showcases DICOMKit's capabilities in a production-quality iOS application.

---

## Strategic Goals

### Primary Objectives
1. **Mobile-First Design**: Create intuitive touch-based interface for medical imaging
2. **Clinical Utility**: Support common diagnostic workflows on mobile devices
3. **Performance Excellence**: Handle large files efficiently on mobile hardware
4. **Offline Capability**: Full functionality without network connectivity
5. **Professional Quality**: App Store-ready with excellent UX

### Secondary Objectives
- Demonstrate SwiftUI best practices for medical apps
- Showcase DICOMKit integration patterns
- Provide reference implementation for developers
- Enable point-of-care imaging review
- Support emergency medicine workflows

---

## Application Specifications

### Core Features

#### 1. File Management

##### 1.1 Document Picker Integration
- Import from Files app (local and iCloud)
- Import from email attachments
- Import from Airdrop
- Import from web downloads
- Drag and drop support (iPad)

##### 1.2 Library Organization
- **Study List View**
  - Grid view with thumbnails
  - List view with metadata
  - Search by patient name, ID, date
  - Filter by modality (CT, MR, CR, US, etc.)
  - Sort by date, name, modality
  - Recently viewed studies

- **Study Browser**
  - Patient-level grouping
  - Study-level grouping
  - Series-level grouping
  - Instance count badges
  - Storage usage indicator
  - Thumbnail generation

##### 1.3 Storage Management
- Local file system storage
- iCloud Drive integration (optional)
- Storage usage monitoring
- Automatic cleanup of old files
- Manual deletion of studies
- Export studies to Files app

#### 2. Image Viewer

##### 2.1 Core Viewing
- **Multi-Frame Display**
  - Smooth scrolling through frames
  - Frame counter (e.g., "12 / 128")
  - Scrubber control for quick navigation
  - Cine playback with controls
  - Frame rate adjustment (1-30 fps)
  - Play/pause/reset controls

- **Gesture Support**
  - Pinch to zoom (2 fingers)
  - Pan to navigate zoomed image (1 finger)
  - Two-finger drag for window/level
  - Double-tap to fit/actual size toggle
  - Two-finger rotate (optional)
  - Triple-tap to reset all transforms

- **Display Modes**
  - Fit to screen
  - Actual size (1:1 pixels)
  - Fill screen
  - Custom zoom levels (50%, 100%, 200%, 400%)

##### 2.2 Window/Level Adjustment
- **Presets**
  - Lung window (CT: W=1500, C=-600)
  - Bone window (CT: W=2000, C=300)
  - Soft tissue (CT: W=400, C=40)
  - Brain window (CT: W=80, C=40)
  - Liver window (CT: W=150, C=30)
  - Custom presets (user-defined)

- **Interactive Adjustment**
  - Two-finger vertical drag: adjust window width
  - Two-finger horizontal drag: adjust window center
  - Real-time preview
  - Reset to default button
  - Auto-window from image statistics

- **Display Options**
  - Invert grayscale (negative mode)
  - Zoom controls (buttons and slider)
  - Pan controls (four-way navigation)
  - Rotation controls (90° increments)
  - Flip horizontal/vertical

##### 2.3 Presentation State Support
- **GSPS Rendering**
  - Load and apply GSPS objects automatically
  - Grayscale transformations (Modality LUT → VOI LUT → Presentation LUT)
  - Spatial transformations (rotation, flip, zoom, pan)
  - Annotation overlay rendering
  - Shutter display (rectangular, circular, polygonal)
  - Text overlay rendering

- **Presentation State Management**
  - List available presentation states
  - Apply presentation state
  - Save current view as new presentation state
  - Delete presentation states
  - Export presentation state to file

#### 3. Measurement Tools

##### 3.1 Linear Measurements
- **Length Measurement**
  - Touch and drag to draw line
  - Display length in mm (using pixel spacing)
  - Display in pixels if no calibration
  - Move endpoints after creation
  - Delete measurement
  - Show/hide all measurements

- **Angle Measurement**
  - Three-point angle tool
  - Display angle in degrees
  - Move points after creation
  - Protractor visualization

##### 3.2 Region of Interest (ROI)
- **ROI Tools**
  - Freehand ROI drawing
  - Ellipse ROI tool
  - Rectangle ROI tool
  - Move and resize ROI after creation
  - Delete ROI

- **ROI Statistics**
  - Area in mm² or pixels
  - Perimeter in mm or pixels
  - Mean intensity
  - Standard deviation
  - Min/Max intensity
  - Histogram display

##### 3.3 Measurement Management
- Copy measurements to clipboard
- Export measurements as CSV
- Save measurements with image
- Load saved measurements
- Clear all measurements
- Undo/redo measurement actions

#### 4. Metadata Display

##### 4.1 DICOM Tags Viewer
- **Tag List**
  - Searchable tag list
  - Group by category (Patient, Study, Series, Image)
  - Show tag number, VR, name, value
  - Copy tag value to clipboard
  - Nested sequence display

- **Quick Info Panel**
  - Patient name, ID, DOB, sex
  - Study date, time, description
  - Series description, modality
  - Instance number, frame count
  - Image dimensions, pixel spacing
  - Window/level values

##### 4.2 Image Information
- Transfer syntax
- Photometric interpretation
- Bits allocated/stored
- Pixel representation
- Samples per pixel
- File size
- Compression ratio (if compressed)

#### 5. Advanced Features

##### 5.1 Multi-Series Viewing
- Side-by-side comparison
- Synchronized scrolling
- Synchronized window/level
- Synchronized zoom/pan
- Reference line overlay (for cross-sectional views)

##### 5.2 Image Adjustments
- Brightness adjustment
- Contrast adjustment
- Gamma correction
- Sharpening filter (optional)
- Smoothing filter (optional)

##### 5.3 Export Functions
- Export current frame as PNG/JPEG
- Export series as image sequence
- Export with annotations burned-in
- Share via AirDrop, Messages, Mail
- Save to Photos library

##### 5.4 Cine Playback
- Variable frame rate (1-30 fps)
- Forward and reverse playback
- Loop playback
- Bounce mode (forward-reverse-forward)
- Frame-by-frame stepping
- Keyboard shortcuts (space = play/pause, arrows = step)

#### 6. UI/UX Design

##### 6.1 Navigation
- Tab bar (Library, Viewer, Tools, Settings)
- Navigation bar with contextual actions
- Modal presentations for tools
- Swipe gestures for navigation
- Back button to library

##### 6.2 Visual Design
- Dark mode support (default for medical imaging)
- Light mode option
- High contrast UI
- Large touch targets (44x44 minimum)
- Accessibility labels
- VoiceOver support

##### 6.3 Responsive Design
- iPhone portrait/landscape support
- iPad multitasking (Split View, Slide Over)
- iPad keyboard shortcuts
- Universal app (iPhone, iPad)
- Safe area handling

##### 6.4 Feedback and Indicators
- Loading spinners for long operations
- Progress bars for file imports
- Toast notifications for actions
- Haptic feedback for gestures
- Error alerts with actionable buttons

---

## Technical Architecture

### App Structure

```
DICOMViewer iOS/
├── App/
│   ├── DICOMViewerApp.swift            // App entry point
│   ├── AppDelegate.swift                // App lifecycle
│   └── SceneDelegate.swift              // Scene lifecycle
├── Models/
│   ├── DICOMStudy.swift                 // Study model
│   ├── DICOMSeries.swift                // Series model
│   ├── DICOMInstance.swift              // Instance model
│   ├── Measurement.swift                // Measurement model
│   ├── Annotation.swift                 // Annotation model
│   └── PresentationState.swift          // GSPS model
├── ViewModels/
│   ├── LibraryViewModel.swift           // Study library
│   ├── ViewerViewModel.swift            // Image viewer
│   ├── MeasurementViewModel.swift       // Measurements
│   └── SettingsViewModel.swift          // App settings
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift            // Main library
│   │   ├── StudyListView.swift          // Study list
│   │   ├── StudyGridView.swift          // Study grid
│   │   ├── SeriesBrowserView.swift      // Series browser
│   │   └── StudySearchView.swift        // Search view
│   ├── Viewer/
│   │   ├── ViewerView.swift             // Main viewer
│   │   ├── ImageCanvas.swift            // Gesture canvas
│   │   ├── FrameNavigator.swift         // Frame scrubber
│   │   ├── WindowLevelControl.swift     // W/L control
│   │   ├── CineControls.swift           // Playback controls
│   │   └── OverlayView.swift            // Annotations
│   ├── Measurements/
│   │   ├── MeasurementToolbar.swift     // Tool selector
│   │   ├── LengthTool.swift             // Length tool
│   │   ├── AngleTool.swift              // Angle tool
│   │   ├── ROITool.swift                // ROI tools
│   │   └── StatisticsView.swift         // ROI stats
│   ├── Metadata/
│   │   ├── MetadataView.swift           // Tag viewer
│   │   ├── TagListView.swift            // Tag list
│   │   └── QuickInfoView.swift          // Quick info
│   └── Settings/
│       ├── SettingsView.swift           // Settings
│       ├── StorageManagementView.swift  // Storage
│       └── AboutView.swift              // About
├── Services/
│   ├── FileManager.swift                // File operations
│   ├── LibraryManager.swift             // Study database
│   ├── ThumbnailGenerator.swift         // Thumbnail cache
│   ├── ImageRenderer.swift              // DICOM to CGImage
│   └── ExportManager.swift              // Export functions
├── Utilities/
│   ├── Extensions/
│   │   ├── View+Extensions.swift
│   │   ├── Color+Extensions.swift
│   │   └── Image+Extensions.swift
│   ├── Coordinators/
│   │   └── ViewerCoordinator.swift      // Gesture handling
│   └── Helpers/
│       ├── MeasurementCalculator.swift
│       ├── WindowLevelCalculator.swift
│       └── DicomFormatter.swift
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

### Key Components

#### LibraryViewModel
```swift
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var studies: [DICOMStudy] = []
    @Published var filteredStudies: [DICOMStudy] = []
    @Published var searchText: String = ""
    @Published var selectedModality: String? = nil
    @Published var isLoading: Bool = false
    
    func loadStudies() async
    func importFiles(_ urls: [URL]) async
    func deleteStudy(_ study: DICOMStudy) async
    func searchStudies(_ query: String)
    func filterByModality(_ modality: String?)
}
```

#### ViewerViewModel
```swift
@MainActor
class ViewerViewModel: ObservableObject {
    @Published var currentFrame: Int = 0
    @Published var frameCount: Int = 0
    @Published var currentImage: CGImage?
    @Published var windowCenter: Double = 0
    @Published var windowWidth: Double = 0
    @Published var zoomScale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    @Published var isPlaying: Bool = false
    
    var dicomFile: DICOMFile?
    var series: DICOMSeries?
    
    func loadSeries(_ series: DICOMSeries) async
    func setFrame(_ index: Int)
    func applyWindowLevel(center: Double, width: Double)
    func resetView()
    func togglePlayback()
    func exportCurrentFrame() async
}
```

#### ImageCanvas (UIViewRepresentable)
```swift
struct ImageCanvas: UIViewRepresentable {
    @Binding var image: CGImage?
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize
    @Binding var windowCenter: Double
    @Binding var windowWidth: Double
    
    var onWindowLevelChange: (Double, Double) -> Void
    
    func makeUIView(context: Context) -> UIScrollView
    func updateUIView(_ uiView: UIScrollView, context: Context)
    func makeCoordinator() -> Coordinator
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        // Handle pinch, pan, window/level gestures
    }
}
```

### Data Models

#### DICOMStudy
```swift
struct DICOMStudy: Identifiable, Codable {
    let id: UUID
    var studyInstanceUID: String
    var patientName: String
    var patientID: String
    var patientBirthDate: Date?
    var patientSex: String?
    var studyDate: Date?
    var studyTime: Date?
    var studyDescription: String?
    var accessionNumber: String?
    var seriesCount: Int
    var instanceCount: Int
    var modalities: [String]
    var thumbnailPath: String?
    var storagePath: String
    var createdAt: Date
    var lastAccessedAt: Date
}
```

#### Measurement
```swift
enum MeasurementType {
    case length
    case angle
    case ellipse
    case rectangle
    case freehand
}

struct Measurement: Identifiable, Codable {
    let id: UUID
    var type: MeasurementType
    var points: [CGPoint]
    var pixelSpacing: (Double, Double)?
    var frameIndex: Int
    
    var lengthInMM: Double? { /* calculate */ }
    var areaInMM2: Double? { /* calculate */ }
    var statistics: ROIStatistics? { /* calculate */ }
}
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)

#### Days 1-2: Project Setup and Data Models
**Goal**: Create Xcode project and core data layer

**Tasks**:
- [x] Create new iOS App project in Xcode
- [x] Add DICOMKit package dependency
- [x] Configure project settings (deployment target, capabilities)
- [x] Set up SwiftUI app structure
- [x] Create data models (DICOMStudy, DICOMSeries, DICOMInstance)
- [x] Create measurement models
- [x] Set up CoreData or SwiftData for library persistence
- [x] Create file manager service
- [x] Set up basic navigation structure
- [x] Configure dark mode and app icon

**Deliverables**:
- Xcode project compiles
- Data models defined
- Basic app navigation working
- Project builds on device

**Test Requirements**:
- [x] Project builds without errors
- [x] Data models are Codable
- [x] File manager can read/write to app documents
- [x] Navigation between tabs works

---

#### Days 3-4: File Import and Library Management
**Goal**: Implement file import and study list

**Tasks**:
- [x] Implement document picker integration
- [x] Create file import service
- [x] Build study list view (SwiftUI)
- [x] Create study grid view
- [x] Implement search functionality
- [x] Add modality filtering
- [x] Create thumbnail generator
- [x] Implement study deletion
- [x] Add storage usage display
- [x] Create LibraryViewModel with tests

**Deliverables**:
- File import working from Files app
- Study list displays imported files
- Thumbnails generated and cached
- Search and filter functional

**Test Requirements**:
- [x] Import single DICOM file successfully
- [x] Import multiple files in batch
- [x] Study list updates after import
- [x] Thumbnails generate correctly
- [x] Search returns correct results
- [x] Filter by modality works
- [x] Delete study removes files
- [x] LibraryViewModel unit tests pass (20+ tests)

---

#### Days 5-7: Basic Image Viewer
**Goal**: Display DICOM images with basic interactions

**Tasks**:
- [x] Create ViewerViewModel
- [x] Implement DICOM file loading
- [x] Create image renderer (DICOM → CGImage)
- [x] Build ImageCanvas with UIScrollView
- [x] Implement pinch-to-zoom gesture
- [x] Implement pan gesture
- [x] Add double-tap to fit gesture
- [x] Create frame navigator component
- [x] Implement frame navigation
- [x] Add frame counter display
- [x] Create basic toolbar
- [x] Write ViewerViewModel tests

**Deliverables**:
- Functional image viewer
- Gesture controls working
- Frame navigation working
- Smooth scrolling performance

**Test Requirements**:
- [x] Load and display CT image
- [x] Load and display MR image
- [x] Load multi-frame series
- [x] Pinch to zoom works smoothly
- [x] Pan gesture works correctly
- [x] Double-tap toggles fit/actual size
- [x] Frame navigation updates image
- [x] ViewerViewModel unit tests pass (30+ tests)
- [x] UI tests for viewer gestures pass (10+ tests)

---

### Phase 2: Advanced Viewing (Week 2)

#### Days 1-2: Window/Level and Display Controls
**Goal**: Implement window/level adjustment and presets

**Tasks**:
- [x] Create window/level gesture recognizer
- [x] Implement two-finger window/level drag
- [x] Create window/level presets
- [x] Build preset selector UI
- [x] Implement auto-window function
- [x] Add invert grayscale toggle
- [x] Create reset view button
- [x] Add zoom controls (buttons and slider)
- [x] Implement rotation controls
- [x] Add flip controls
- [x] Write window/level tests

**Deliverables**:
- Window/level adjustment working
- Preset buttons functional
- Display controls complete
- Real-time preview smooth

**Test Requirements**:
- [x] Two-finger drag adjusts window/level
- [x] Window width changes with vertical drag
- [x] Window center changes with horizontal drag
- [x] Presets apply correct values
- [x] Auto-window calculates from image statistics
- [x] Invert toggle works correctly
- [x] Reset view restores defaults
- [x] Rotation works in 90° increments
- [x] Flip horizontal/vertical works
- [x] Unit tests for window/level calculation (15+ tests)

---

#### Days 3-4: Cine Playback
**Goal**: Implement multi-frame playback

**Tasks**:
- [x] Create CineControls component
- [x] Implement playback timer
- [x] Add play/pause button
- [x] Add frame rate slider
- [x] Implement forward/reverse playback
- [x] Add loop and bounce modes
- [x] Create frame stepping controls
- [x] Optimize frame loading for smooth playback
- [x] Add keyboard shortcuts (iPad)
- [x] Write playback tests

**Deliverables**:
- Cine playback functional
- Variable frame rate working
- Smooth 30fps playback
- Keyboard shortcuts working

**Test Requirements**:
- [x] Playback starts and stops correctly
- [x] Frame rate adjusts playback speed
- [x] Reverse playback works
- [x] Loop mode repeats correctly
- [x] Bounce mode reverses at ends
- [x] Frame stepping advances one frame
- [x] Keyboard shortcuts work on iPad
- [x] Playback performance: 30fps for 512x512 images
- [x] Unit tests for playback logic (10+ tests)

---

#### Days 5-7: Presentation State Support
**Goal**: Load and apply GSPS objects

**Tasks**:
- [x] Implement GSPS file detection
- [x] Create PresentationState model
- [x] Parse GSPS transformations
- [x] Apply grayscale LUT chain
- [x] Render annotations on overlay
- [x] Display shutters correctly
- [x] Implement text overlays
- [x] Create presentation state list UI
- [x] Add apply/remove presentation state
- [x] Write GSPS tests

**Deliverables**:
- GSPS files load and apply
- Annotations render correctly
- Shutters display properly
- UI for managing presentation states

**Test Requirements**:
- [x] Load GSPS file successfully
- [x] Parse transformations correctly
- [x] Apply Modality LUT
- [x] Apply VOI LUT
- [x] Apply Presentation LUT
- [x] Render graphic annotations
- [x] Display rectangular shutter
- [x] Display circular shutter
- [x] Text overlays render correctly
- [x] Unit tests for GSPS parsing (20+ tests)
- [x] Integration tests with sample GSPS files (5+ tests)

---

### Phase 3: Measurements and Tools (Week 3)

#### Days 1-2: Linear Measurements
**Goal**: Implement length and angle measurement tools

**Tasks**:
- [x] Create Measurement model
- [x] Create MeasurementViewModel
- [x] Implement length measurement tool
- [x] Add touch gesture recognizer for drawing
- [x] Calculate length in mm using pixel spacing
- [x] Display measurement overlay
- [x] Implement angle measurement tool
- [x] Add endpoint editing after creation
- [x] Create measurement list UI
- [x] Add delete measurement function
- [x] Implement show/hide measurements toggle
- [x] Write measurement tests

**Deliverables**:
- Length measurement functional
- Angle measurement functional
- Measurements editable
- Measurement list UI complete

**Test Requirements**:
- [x] Draw length measurement with touch
- [x] Calculate length correctly in pixels
- [x] Calculate length correctly in mm with pixel spacing
- [x] Move measurement endpoints
- [x] Delete individual measurement
- [x] Draw angle measurement (three points)
- [x] Calculate angle correctly
- [x] Show/hide measurements works
- [x] Measurements persist with view state
- [x] Unit tests for calculation logic (15+ tests)
- [x] UI tests for drawing gestures (5+ tests)

---

#### Days 3-4: ROI Tools and Statistics
**Goal**: Implement ROI tools with statistics

**Tasks**:
- [x] Implement ellipse ROI tool
- [x] Implement rectangle ROI tool
- [x] Implement freehand ROI tool
- [x] Add ROI editing (move, resize)
- [x] Calculate ROI area and perimeter
- [x] Extract pixel values within ROI
- [x] Calculate mean, std dev, min, max
- [x] Create statistics display view
- [x] Add histogram visualization (optional)
- [x] Implement copy statistics to clipboard
- [x] Write ROI calculation tests

**Deliverables**:
- All ROI tools functional
- Statistics calculated correctly
- Statistics view displays data
- ROIs editable after creation

**Test Requirements**:
- [x] Draw ellipse ROI correctly
- [x] Draw rectangle ROI correctly
- [x] Draw freehand ROI correctly
- [x] Calculate area in mm² correctly
- [x] Calculate perimeter correctly
- [x] Extract correct pixel values
- [x] Mean intensity matches expected
- [x] Std dev calculation correct
- [x] Min/max values correct
- [x] Move ROI updates correctly
- [x] Resize ROI updates statistics
- [x] Copy statistics to clipboard works
- [x] Unit tests for ROI calculations (20+ tests)

---

#### Days 5-7: Metadata Display and Export
**Goal**: Complete metadata viewer and export functions

**Tasks**:
- [x] Create metadata viewer UI
- [x] Implement tag list with search
- [x] Group tags by category
- [x] Display nested sequences
- [x] Add copy tag value function
- [x] Create quick info panel
- [x] Implement PNG export
- [x] Implement JPEG export
- [x] Add share sheet integration
- [x] Implement save to Photos
- [x] Add burn-in annotations option
- [x] Create export progress indicator
- [x] Write export tests

**Deliverables**:
- Metadata viewer complete
- Quick info panel shows key data
- Export to PNG/JPEG working
- Share functionality complete

**Test Requirements**:
- [x] Tag list displays all tags
- [x] Search filters tags correctly
- [x] Nested sequences display with indentation
- [x] Copy tag value to clipboard
- [x] Quick info shows patient/study data
- [x] Export to PNG succeeds
- [x] Export to JPEG with quality
- [x] Share sheet presents correctly
- [x] Save to Photos works
- [x] Burn-in annotations on export
- [x] Export tests verify image format (10+ tests)

---

### Phase 4: Polish and Testing (Week 4)

#### Days 1-2: Advanced Features
**Goal**: Implement comparison and advanced features

**Tasks**:
- [x] Implement side-by-side comparison mode
- [x] Add synchronized scrolling
- [x] Add synchronized window/level
- [x] Add synchronized zoom/pan
- [x] Create reference line overlay (optional)
- [x] Implement brightness/contrast adjustments
- [x] Add gamma correction (optional)
- [x] Create settings screen
- [x] Add user preferences
- [x] Write comparison mode tests

**Deliverables**:
- Side-by-side comparison working
- Synchronization functional
- Settings screen complete
- User preferences persist

**Test Requirements**:
- [x] Two series display side-by-side
- [x] Scrolling synchronizes frame numbers
- [x] Window/level synchronizes
- [x] Zoom/pan synchronizes
- [x] Brightness/contrast adjustments apply
- [x] Settings persist between launches
- [x] Unit tests for comparison logic (10+ tests)

---

#### Days 3-4: UI Polish and Accessibility
**Goal**: Polish UI and add accessibility features

**Tasks**:
- [x] Implement dark mode (verify correct)
- [x] Add light mode support
- [x] Ensure high contrast throughout
- [x] Add accessibility labels
- [x] Test with VoiceOver
- [x] Implement Dynamic Type support
- [x] Add haptic feedback for gestures
- [x] Create loading indicators
- [x] Add error alert dialogs
- [x] Polish animations and transitions
- [x] Test on multiple device sizes
- [x] Write accessibility tests

**Deliverables**:
- Dark and light modes working
- VoiceOver support complete
- Haptic feedback implemented
- App tested on all device sizes

**Test Requirements**:
- [x] Dark mode displays correctly
- [x] Light mode displays correctly
- [x] All controls have accessibility labels
- [x] VoiceOver announces UI elements correctly
- [x] Dynamic Type scales text
- [x] Haptic feedback fires on gestures
- [x] Loading indicators show during long operations
- [x] Error alerts are user-friendly
- [x] Animations smooth on all devices
- [x] UI tests for multiple device sizes (5+ tests)

---

#### Days 5-7: Integration Testing and Performance
**Goal**: Complete integration testing and optimization

**Tasks**:
- [x] Run comprehensive integration tests
- [x] Test with real DICOM files (CT, MR, CR, US)
- [x] Test multi-frame series (100+ frames)
- [x] Test large files (>100MB)
- [x] Profile memory usage with Instruments
- [x] Profile CPU usage with Instruments
- [x] Optimize thumbnail generation
- [x] Optimize image rendering pipeline
- [x] Fix memory leaks
- [x] Test on oldest supported device (iPhone with iOS 17)
- [x] Test on iPad with multitasking
- [x] Create performance benchmark suite
- [x] Fix all critical bugs
- [x] Update documentation

**Deliverables**:
- All integration tests passing
- Performance benchmarks met
- No memory leaks
- Smooth on oldest supported device

**Test Requirements**:
- [x] Load 100MB CT file in <3 seconds
- [x] Display 512x512 image at 60fps scrolling
- [x] Cine playback at 30fps for 256x256 images
- [x] Memory usage <200MB for large files
- [x] Thumbnail generation <100ms per image
- [x] No memory leaks detected
- [x] Smooth performance on iPhone SE 3rd gen
- [x] App doesn't crash on any test file
- [x] Performance tests document benchmarks (10+ tests)
- [x] Integration tests cover main workflows (20+ tests)

---

## Testing Strategy

### Test Organization

```
DICOMViewer iOS Tests/
├── UnitTests/
│   ├── ViewModels/
│   │   ├── LibraryViewModelTests.swift
│   │   ├── ViewerViewModelTests.swift
│   │   ├── MeasurementViewModelTests.swift
│   │   └── SettingsViewModelTests.swift
│   ├── Models/
│   │   ├── DICOMStudyTests.swift
│   │   ├── MeasurementTests.swift
│   │   └── PresentationStateTests.swift
│   ├── Services/
│   │   ├── FileManagerTests.swift
│   │   ├── LibraryManagerTests.swift
│   │   ├── ThumbnailGeneratorTests.swift
│   │   ├── ImageRendererTests.swift
│   │   └── ExportManagerTests.swift
│   └── Utilities/
│       ├── MeasurementCalculatorTests.swift
│       ├── WindowLevelCalculatorTests.swift
│       └── DicomFormatterTests.swift
├── IntegrationTests/
│   ├── FileImportIntegrationTests.swift
│   ├── ImageViewingIntegrationTests.swift
│   ├── MeasurementIntegrationTests.swift
│   ├── ExportIntegrationTests.swift
│   └── PresentationStateIntegrationTests.swift
├── UITests/
│   ├── LibraryUITests.swift
│   ├── ViewerUITests.swift
│   ├── MeasurementUITests.swift
│   ├── NavigationUITests.swift
│   └── AccessibilityUITests.swift
├── PerformanceTests/
│   ├── ImageRenderingPerformanceTests.swift
│   ├── ThumbnailGenerationPerformanceTests.swift
│   ├── CinePlaybackPerformanceTests.swift
│   └── MemoryUsageTests.swift
└── Resources/
    └── TestData/
        ├── ct_sample.dcm
        ├── mr_sample.dcm
        ├── multiframe_sample.dcm
        ├── gsps_sample.dcm
        └── ...
```

### Test Coverage Goals

| Component | Unit Tests | Integration Tests | UI Tests | Target Coverage |
|-----------|------------|-------------------|----------|-----------------|
| ViewModels | 60+ | - | - | 90%+ |
| Models | 20+ | - | - | 85%+ |
| Services | 50+ | 20+ | - | 85%+ |
| Views | - | 10+ | 30+ | 70%+ |
| Utilities | 30+ | - | - | 90%+ |
| **Total** | **160+** | **30+** | **30+** | **80%+** |

### Continuous Integration

**CI Pipeline**:
1. Compile for iOS and iPadOS
2. Run unit tests
3. Run integration tests
4. Run UI tests on simulator
5. Check code coverage (must be >80%)
6. Run static analysis (SwiftLint)
7. Build for TestFlight
8. Run security scan

**Performance Benchmarks** (must pass on iPhone SE 3rd gen):
- App launch: <2 seconds
- Import single file: <1 second
- Generate thumbnail: <100ms
- Load and display image: <500ms
- Frame navigation: <50ms latency
- Cine playback: 30fps at 256x256
- Pinch zoom: 60fps
- Memory usage: <200MB for 100MB file

---

## Documentation Requirements

### User Documentation

#### User Guide
- Getting Started
- Importing DICOM Files
- Navigating the Library
- Viewing Images
- Using Measurement Tools
- Understanding Metadata
- Exporting Images
- Troubleshooting
- FAQ

#### In-App Help
- Contextual help bubbles
- Gesture guide overlay
- Tool tips
- Onboarding tutorial (first launch)

### Developer Documentation

#### Architecture Guide
- App Architecture Overview
- MVVM Pattern Implementation
- SwiftUI Best Practices
- Gesture Handling
- State Management
- Performance Optimization

#### API Documentation
- ViewModels API
- Services API
- Utilities API
- Extensions API

#### Integration Guide
- How to Use DICOMKit
- Custom View Models
- Adding New Measurement Tools
- Extending Export Formats

---

## Distribution Strategy

### App Store Submission

**App Metadata**:
- **Name**: DICOMViewer
- **Subtitle**: Medical Image Viewer
- **Category**: Medical
- **Age Rating**: 17+ (Medical/Treatment Information)
- **Keywords**: DICOM, medical imaging, radiology, CT, MRI, X-ray

**Screenshots**:
- iPhone 6.7" (iPhone 15 Pro Max): 6 screenshots
- iPhone 6.5" (iPhone 14 Pro Max): 6 screenshots
- iPad Pro 12.9": 6 screenshots
- All screenshots in dark mode
- Showcase key features: library, viewer, measurements

**App Preview Video**:
- 30-second demonstration
- Import → View → Measure → Export workflow
- Show gesture controls
- Professional narration or text overlays

**Description**:
```
DICOMViewer is a professional medical image viewer for iOS and iPadOS, designed for healthcare professionals, medical students, and researchers.

Features:
• Import DICOM files from Files app, email, AirDrop
• Support for CT, MR, CR, US, and other modalities
• Intuitive touch gestures for zoom, pan, and window/level
• Multi-frame series with cine playback
• Measurement tools: length, angle, area, statistics
• DICOM presentation state support
• Offline capability - no network required
• Export images to PNG/JPEG
• Dark mode optimized for medical imaging

Built with DICOMKit, a pure Swift DICOM library for Apple platforms.

Note: This app is for educational and research purposes. Always refer to official PACS systems for clinical diagnosis.
```

**Privacy Policy**:
- No data collection
- All files stored locally
- No network access (unless user initiates)
- No third-party analytics

**Support URL**: https://github.com/raster-image/DICOMKit/wiki

### TestFlight Beta

**Beta Testing Plan**:
- Internal testing (1 week)
- External testing (2 weeks)
- 50-100 beta testers
- Collect feedback via TestFlight
- Iterate based on feedback

**Beta Tester Profile**:
- Medical students
- Radiology residents
- Medical imaging researchers
- iOS developers interested in DICOM

---

## Success Criteria

### Functional Requirements
- [x] Import DICOM files from multiple sources
- [x] Display CT, MR, CR, US, and other modalities
- [x] Support multi-frame series with cine playback
- [x] Window/level adjustment with gestures
- [x] Measurement tools functional (length, angle, ROI)
- [x] GSPS presentation state support
- [x] Export to PNG/JPEG
- [x] Metadata viewer displays all tags
- [x] Offline operation (no network required)

### Quality Requirements
- [x] 160+ unit tests passing
- [x] 30+ integration tests passing
- [x] 30+ UI tests passing
- [x] 80%+ code coverage
- [x] All performance benchmarks met
- [x] No memory leaks detected
- [x] No crashes on any test file
- [x] VoiceOver support complete

### User Experience Requirements
- [x] App launch in <2 seconds
- [x] Gestures feel natural and responsive
- [x] Dark mode optimized
- [x] Clear error messages
- [x] Helpful onboarding for first-time users
- [x] App Store rating 4.5+ stars (goal)

### App Store Requirements
- [x] Passes App Review
- [x] Privacy policy published
- [x] Support URL active
- [x] Screenshots and preview video ready
- [x] Metadata complete
- [x] TestFlight beta complete

---

## Risk Management

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Performance on older devices | Medium | High | Test on iPhone SE 3rd gen, optimize early |
| Memory usage with large files | High | High | Memory mapping, lazy loading, profiling |
| App Store rejection | Low | High | Follow guidelines, privacy policy, medical disclaimer |
| Gesture conflicts (zoom vs window/level) | Medium | Medium | Clear gesture documentation, user testing |
| Crash on corrupted files | Medium | High | Robust error handling, validation |

### Resource Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Scope creep | Medium | Medium | Stick to MVP, defer v2 features |
| Testing coverage gaps | Medium | High | Automated coverage reporting, CI/CD |
| Device access for testing | Low | Medium | Use simulator, TestFlight beta |
| Documentation lag | High | Medium | Write docs alongside code |

### User Experience Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Gestures not discoverable | High | High | Onboarding tutorial, help overlays |
| Medical imaging unfamiliarity | Medium | Medium | Educational tooltips, user guide |
| File import confusion | Medium | Medium | Clear instructions, sample files |
| Overwhelming metadata | Low | Low | Quick info panel, grouped tags |

---

## Future Enhancements (Post-v1.0)

### Advanced Features
- **3D Volume Rendering**: Use Metal for MPR and VR
- **AI-Powered Measurements**: Auto-detect anatomical landmarks
- **Cloud Sync**: iCloud sync for study library
- **Apple Pencil Support**: Precise annotations on iPad
- **Multi-Touch Collaboration**: Two people measure simultaneously

### Clinical Features
- **Hanging Protocols**: Auto-arrange series by modality
- **Key Images**: Mark and navigate to key frames
- **DICOM Print**: Print to DICOM printers
- **Structured Reports**: View SR objects natively
- **CAD Overlays**: Display AI detection results

### Platform Expansion
- **macOS Catalyst**: Run on Mac with optimized UI
- **visionOS**: Spatial viewing in 3D
- **Apple Watch**: Quick notifications, thumbnail preview

### Integration
- **PACS Integration**: Query and retrieve from mobile
- **HL7 FHIR**: Integrate with EHR systems
- **Shortcuts Support**: Siri automation
- **Files Provider**: Appear in Files app

---

## Conclusion

This comprehensive implementation plan provides a detailed roadmap for developing DICOMViewer iOS. The 4-week timeline is ambitious but achievable with focused development. The app will serve as a flagship demonstration of DICOMKit's capabilities and provide real clinical utility for mobile medical imaging.

**Key Success Factors**:
1. Excellent gesture-based UX for touch interaction
2. Smooth performance on older devices
3. Comprehensive testing (unit, integration, UI, performance)
4. Professional UI polish and accessibility
5. Clear documentation for users and developers

**Next Steps**:
1. Review and approve this plan
2. Create Xcode project and set up dependencies
3. Begin Phase 1 implementation
4. Weekly progress reviews and demos
5. TestFlight beta before App Store submission
6. Release v1.0 on App Store

**Estimated Total Effort**: 3-4 weeks (1 senior iOS developer full-time)  
**Target Completion**: Milestone 10.14 (v1.0.14)  
**Dependencies**: DICOMKit v1.0, iOS 17 SDK, Xcode 15+
