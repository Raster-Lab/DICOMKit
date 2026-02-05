# DICOMKit iOS Application Development Plan

## Overview

This document outlines a comprehensive development roadmap for **DICOMViewer iOS**, a production-quality medical imaging application built with DICOMKit. The application will showcase DICOMKit's capabilities while providing a professional tool for mobile medical image viewing, point-of-care consultation, and emergency imaging review.

**Target Platform**: iOS 17+  
**Primary Language**: Swift 6  
**UI Framework**: SwiftUI  
**Dependencies**: DICOMKit v1.0+  
**Development Duration**: 12-14 weeks  
**Target Users**: Medical professionals, radiologists, researchers, medical students

---

## Strategic Goals

### Primary Objectives
1. **Demonstrate DICOMKit Excellence**: Showcase all major DICOMKit features in production use
2. **Clinical Utility**: Provide real value for point-of-care medical image review
3. **User Experience**: Deliver intuitive, responsive, gesture-driven interface
4. **Platform Integration**: Leverage iOS capabilities (Files app, iCloud, ShareSheet, etc.)
5. **Educational Resource**: Serve as reference implementation for DICOMKit integration

### Success Criteria
- App Store launch with 4.5+ star rating
- 1,000+ downloads in first month
- Zero critical bugs in production
- <200MB memory usage for typical studies
- 60fps scrolling and gesture response
- Comprehensive test coverage (80%+)

---

## Milestone 1: Project Foundation (Weeks 1-2)

**Status**: Planned  
**Goal**: Establish project structure, development environment, and core architecture

### Deliverables

#### 1.1 Project Setup
- [ ] Create Xcode project with Swift Package Manager integration
- [ ] Configure DICOMKit dependency (v1.0.2+)
- [ ] Set up SwiftUI app structure with proper scene lifecycle
- [ ] Configure Info.plist with required permissions (Photo Library, Files access)
- [ ] Set up build configurations (Debug, Release, TestFlight)
- [ ] Configure code signing and provisioning profiles
- [ ] Add .gitignore for Xcode-specific files

#### 1.2 Architecture Design
- [ ] Define MVVM architecture pattern
- [ ] Create core data models:
  - [ ] `DICOMStudy` - Study-level metadata and series collection
  - [ ] `DICOMSeries` - Series-level metadata and image collection
  - [ ] `DICOMImage` - Individual instance metadata and pixel data
  - [ ] `DICOMLibrary` - Local file database and management
- [ ] Design ViewModels:
  - [ ] `LibraryViewModel` - Study/series browser state
  - [ ] `ViewerViewModel` - Image viewing and manipulation state
  - [ ] `ImportViewModel` - File import and validation state
- [ ] Define service layer:
  - [ ] `DICOMFileService` - File I/O operations
  - [ ] `ThumbnailService` - Thumbnail generation and caching
  - [ ] `StorageService` - Local storage management

#### 1.3 Development Environment
- [ ] Set up unit testing target with XCTest
- [ ] Set up UI testing target for critical flows
- [ ] Configure SwiftLint or similar for code quality
- [ ] Set up CI/CD pipeline (GitHub Actions) for:
  - [ ] Build verification
  - [ ] Unit test execution
  - [ ] Code coverage reporting
- [ ] Create test DICOM files for development:
  - [ ] CT chest sample
  - [ ] MR brain sample
  - [ ] X-ray sample
  - [ ] Multi-frame cardiac sample

#### 1.4 Documentation
- [ ] Create ARCHITECTURE.md documenting app structure
- [ ] Create DEVELOPMENT.md with setup instructions
- [ ] Document coding conventions and patterns
- [ ] Create initial README.md for iOS app

### Technical Notes
- Use Swift 6 strict concurrency for thread safety
- Leverage DICOMKit's value types for immutability
- Use Combine or async/await for reactive state management
- Implement proper error handling with typed errors

### Acceptance Criteria
- [x] Project builds successfully on Xcode 15+
- [x] All team members can run project locally
- [x] CI/CD pipeline executes successfully
- [x] Architecture documented and reviewed

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 2: File Management and Import (Weeks 3-4)

**Status**: Planned  
**Goal**: Implement robust DICOM file import and local library management

### Deliverables

#### 2.1 File Import UI
- [ ] Create `ImportView` with SwiftUI document picker
- [ ] Support multiple file selection
- [ ] Display import progress with percentage and file count
- [ ] Show validation errors for invalid DICOM files
- [ ] Implement drag-and-drop from Files app (iPadOS)
- [ ] Add import from:
  - [ ] Files app (local and iCloud)
  - [ ] Photo Library
  - [ ] Email attachments (UTI type association)
  - [ ] AirDrop

#### 2.2 File Validation and Parsing
- [ ] Implement DICOM file validation using DICOMKit:
  - [ ] Verify file preamble and DICM prefix
  - [ ] Parse File Meta Information
  - [ ] Validate required tags (SOP Class UID, Instance UID, etc.)
  - [ ] Check Transfer Syntax support
- [ ] Extract study/series/instance hierarchy:
  - [ ] Patient ID, Name
  - [ ] Study Date, Description, Instance UID
  - [ ] Series Number, Modality, Description, Instance UID
  - [ ] Instance Number, SOP Instance UID
- [ ] Handle parsing errors gracefully with user feedback

#### 2.3 Local Library Storage
- [ ] Implement `DICOMLibrary` with file system storage:
  - [ ] Organize files by Study/Series hierarchy
  - [ ] Store in app's Documents directory
  - [ ] Generate unique filenames to avoid conflicts
- [ ] Create metadata database using Core Data or SwiftData:
  - [ ] `StudyEntity` with patient, date, description
  - [ ] `SeriesEntity` with modality, number, description
  - [ ] `InstanceEntity` with SOP Instance UID, file path
- [ ] Implement efficient queries:
  - [ ] List all studies sorted by date
  - [ ] Filter by modality, date range
  - [ ] Search by patient name, study description
  - [ ] Count instances per study/series

#### 2.4 Thumbnail Generation
- [ ] Implement `ThumbnailService` for preview generation:
  - [ ] Extract pixel data using DICOMKit
  - [ ] Apply basic windowing for visibility
  - [ ] Generate UIImage at 200x200 resolution
  - [ ] Cache thumbnails on disk (use FileManager)
  - [ ] Background queue processing to avoid UI blocking
- [ ] Handle multi-frame images (use middle frame)
- [ ] Implement placeholder for generating thumbnails

#### 2.5 Library Browser UI
- [ ] Create `LibraryView` with study list:
  - [ ] Display patient name, study date, modality
  - [ ] Show thumbnail grid per study
  - [ ] Tap to expand study and show series
  - [ ] Display series details and instance count
- [ ] Implement search bar for filtering studies
- [ ] Add sort options (date, patient name, modality)
- [ ] Implement pull-to-refresh for manual reload
- [ ] Add swipe actions:
  - [ ] Delete study
  - [ ] Share study (export DICOM files)
  - [ ] Mark as favorite (optional)

### Technical Notes
- Use `FileManager` for file operations with proper error handling
- Implement thumbnail generation on background queue with `Task` or `DispatchQueue`
- Use SwiftUI's `.fileImporter` and `.onDrop` for file handling
- Reference: DICOM PS3.3 for required attribute tags
- Reference: DICOM PS3.10 for File Meta Information structure

### Acceptance Criteria
- [x] Successfully import single and multiple DICOM files
- [x] Files organized in study/series hierarchy
- [x] Thumbnails generated for all images
- [x] Search and filter work correctly
- [x] Library persists across app launches
- [x] Memory usage stays <100MB during import
- [x] Import of 100 files completes in <30 seconds

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 3: Core Image Viewer (Weeks 5-6)

**Status**: Planned  
**Goal**: Implement primary image viewing functionality with gestures and display controls

### Deliverables

#### 3.1 Basic Viewer UI
- [ ] Create `ViewerView` with full-screen image display
- [ ] Implement image navigation:
  - [ ] Swipe left/right for prev/next instance
  - [ ] Display current instance number (e.g., "12 / 64")
  - [ ] Thumbnail strip at bottom for quick navigation
- [ ] Add overlay controls (auto-hide after 3 seconds):
  - [ ] Back button to return to library
  - [ ] Series selector (if multiple series in study)
  - [ ] Settings/tools button
- [ ] Display patient/study information overlay:
  - [ ] Patient name, ID
  - [ ] Study date, description
  - [ ] Series number, modality
  - [ ] Instance number

#### 3.2 Image Rendering
- [ ] Implement pixel data extraction using DICOMKit:
  - [ ] Parse pixel data element (7FE0,0010)
  - [ ] Handle photometric interpretations (MONOCHROME1, MONOCHROME2, RGB)
  - [ ] Apply Modality LUT (Rescale Slope/Intercept)
  - [ ] Apply VOI LUT (Window Center/Width)
- [ ] Convert to UIImage/CGImage for display
- [ ] Handle multi-frame images (extract specific frame)
- [ ] Implement efficient caching:
  - [ ] Current image in memory
  - [ ] Preload next 2 images
  - [ ] Cache up to 10 images, LRU eviction

#### 3.3 Touch Gestures
- [ ] Pinch-to-zoom gesture:
  - [ ] Zoom range: 0.5x to 5x
  - [ ] Smooth scaling with `@GestureState`
  - [ ] Center zoom on pinch center point
- [ ] Pan gesture:
  - [ ] Enable panning when zoomed in
  - [ ] Disable when at 1:1 scale
  - [ ] Smooth inertia/momentum scrolling
- [ ] Double-tap gesture:
  - [ ] Toggle between fit-to-screen and 100% (actual size)
  - [ ] Animate zoom transition
- [ ] Two-finger rotation gesture:
  - [ ] Rotate in 90° increments
  - [ ] Snap to nearest 90° on release
  - [ ] Animate rotation
- [ ] Single-finger drag (when zoomed out):
  - [ ] Swipe left/right to change image
  - [ ] Threshold: 20% of screen width
  - [ ] Animate transition

#### 3.4 Window/Level Adjustment
- [ ] Implement window/level (brightness/contrast) control:
  - [ ] Two-finger vertical drag: adjust window width (contrast)
  - [ ] Two-finger horizontal drag: adjust window center (brightness)
  - [ ] Display current window/level values on screen
  - [ ] Apply in real-time with 60fps rendering
- [ ] Add preset window/level buttons:
  - [ ] Lung window (W: 1500, L: -600)
  - [ ] Bone window (W: 2000, L: 300)
  - [ ] Soft tissue (W: 400, L: 40)
  - [ ] Brain (W: 80, L: 40)
  - [ ] Abdomen (W: 350, L: 50)
  - [ ] Auto-window (from pixel statistics)
- [ ] Implement invert/negative mode toggle
- [ ] Reset button to restore original window/level

#### 3.5 Cine Mode (Multi-frame Playback)
- [ ] Detect multi-frame images (NumberOfFrames > 1)
- [ ] Add cine controls:
  - [ ] Play/pause button
  - [ ] Frame rate slider (1-30 fps)
  - [ ] Frame scrubber for manual navigation
  - [ ] Loop mode toggle
- [ ] Implement smooth frame playback:
  - [ ] Use Timer or CADisplayLink for frame updates
  - [ ] Preload frames for smooth playback
  - [ ] Display frame number overlay
- [ ] Add playback controls:
  - [ ] Skip to first/last frame
  - [ ] Step forward/backward one frame

### Technical Notes
- Use SwiftUI's `GeometryReader` and `@GestureState` for gestures
- Implement custom image rendering with Metal or Core Graphics for performance
- Use `AsyncImage` or custom async loading for large images
- Reference: DICOM PS3.3 C.7.6.3 for Image Pixel Module
- Reference: DICOM PS3.3 C.11.1 for VOI LUT Module

### Acceptance Criteria
- [x] 60fps scrolling through image series
- [x] Smooth pinch-to-zoom with no lag
- [x] Window/level adjustment responsive in real-time
- [x] Cine mode plays smoothly at 30fps
- [x] Memory usage <150MB for typical series
- [x] All gestures feel natural and responsive

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 4: Measurement Tools (Weeks 7-8)

**Status**: Planned  
**Goal**: Implement clinical measurement tools with annotation overlay

### Deliverables

#### 4.1 Measurement Architecture
- [ ] Create `Measurement` protocol and concrete types:
  - [ ] `LinearMeasurement` - Distance between two points
  - [ ] `AngleMeasurement` - Angle between three points
  - [ ] `RectangularROI` - Rectangle region of interest
  - [ ] `EllipticalROI` - Ellipse region of interest
  - [ ] `FreehandROI` - Freehand drawn region
- [ ] Implement measurement rendering overlay:
  - [ ] Draw on top of image using SwiftUI Canvas or Metal
  - [ ] Display measurement values with labels
  - [ ] Handle zoom and pan transformations
  - [ ] Save measurements per image instance
- [ ] Create `MeasurementViewModel` for state management

#### 4.2 Linear Measurements
- [ ] Implement length measurement tool:
  - [ ] Tap to place start point
  - [ ] Drag to end point, release to finish
  - [ ] Display line with endpoints
  - [ ] Calculate distance using Pixel Spacing:
    - [ ] Distance (mm) = √(Δx² + Δy²) × pixel_spacing
  - [ ] Display measurement in mm
  - [ ] Add text label with value
- [ ] Implement ruler overlay:
  - [ ] Display calibrated scale bar
  - [ ] Show scale in mm or cm
  - [ ] Position in corner, non-intrusive
- [ ] Angle measurement tool (optional):
  - [ ] Three-point angle (vertex in middle)
  - [ ] Calculate angle in degrees
  - [ ] Display angle arc and value

#### 4.3 Region of Interest (ROI) Tools
- [ ] Rectangular ROI:
  - [ ] Tap-and-drag to draw rectangle
  - [ ] Display dimensions in mm
  - [ ] Calculate area in mm²
  - [ ] Calculate intensity statistics (mean, StdDev, min, max)
- [ ] Elliptical ROI:
  - [ ] Tap-and-drag to draw ellipse
  - [ ] Display major/minor axes
  - [ ] Calculate area using π × a × b
  - [ ] Calculate intensity statistics
- [ ] Freehand ROI:
  - [ ] Draw arbitrary closed polygon
  - [ ] Smooth path with curve fitting
  - [ ] Calculate area using shoelace formula
  - [ ] Calculate intensity statistics
  - [ ] Optional: Auto-close polygon on release

#### 4.4 Measurement Management
- [ ] Create measurement list view:
  - [ ] Display all measurements for current image
  - [ ] Show measurement type, value, and timestamp
  - [ ] Tap to highlight measurement on image
  - [ ] Swipe to delete measurement
- [ ] Implement measurement persistence:
  - [ ] Save measurements with image reference
  - [ ] Store in Core Data or JSON files
  - [ ] Load measurements when viewing image
- [ ] Add measurement export:
  - [ ] Export as CSV (measurement type, value, coordinates)
  - [ ] Export as SR document using DICOMKit (Milestone 9 integration)
  - [ ] Share via ShareSheet

#### 4.5 Measurement UI/UX
- [ ] Add measurement toolbar:
  - [ ] Toggle measurement mode (view vs. draw)
  - [ ] Tool selector (line, angle, rect ROI, ellipse ROI, freehand)
  - [ ] Color picker for measurement overlay
  - [ ] Delete all measurements button
- [ ] Implement measurement editing:
  - [ ] Tap measurement to select
  - [ ] Drag endpoints to adjust
  - [ ] Delete button for selected measurement
- [ ] Add visual feedback:
  - [ ] Highlight selected measurement
  - [ ] Show handles for editing
  - [ ] Haptic feedback on measurement completion

### Technical Notes
- Use SwiftUI Canvas API for rendering measurements
- Calculate pixel spacing from DICOM tags (0028,0030)
- Handle missing pixel spacing gracefully (show pixels instead)
- Reference: DICOM PS3.3 C.7.6.2 for Image Plane Module
- Reference: DICOM PS3.3 A.35.5 for ROI measurements

### Acceptance Criteria
- [x] Measurements accurate to <1% error (validated with test images)
- [x] Smooth drawing with 60fps rendering
- [x] Measurements persist across app sessions
- [x] ROI statistics calculated correctly
- [x] Export functionality works for all formats

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 5: Advanced Features (Weeks 9-10)

**Status**: Planned  
**Goal**: Implement advanced features including Presentation States, export, and sharing

### Deliverables

#### 5.1 Presentation State Support (GSPS)
- [ ] Integrate DICOMKit's Presentation State APIs:
  - [ ] Load Grayscale Softcopy Presentation State (GSPS) files
  - [ ] Parse spatial transformations (rotation, flip)
  - [ ] Parse display area (zoom, pan)
  - [ ] Parse graphic annotations
  - [ ] Parse text annotations
  - [ ] Parse shutters
- [ ] Apply presentation state to images:
  - [ ] Use `PresentationStateApplicator` from DICOMKit
  - [ ] Render annotations on overlay
  - [ ] Apply shutters for masking
  - [ ] Apply spatial transformations
- [ ] Create presentation state from measurements:
  - [ ] Convert app measurements to GSPS annotations
  - [ ] Save as GSPS DICOM file
  - [ ] Include current window/level, zoom, rotation

#### 5.2 Color Presentation State Support
- [ ] Integrate Color Softcopy Presentation State (CSPS):
  - [ ] Parse ICC profiles
  - [ ] Apply color space transformations
  - [ ] Render with CoreGraphics color management
- [ ] Integrate Pseudo-Color Presentation State:
  - [ ] Parse color map presets
  - [ ] Apply color mapping to grayscale images
  - [ ] Support Hot, Cool, Jet, Bone, Copper presets
- [ ] Integrate Blending Presentation State:
  - [ ] Load multi-modality blend configurations
  - [ ] Apply alpha blending, MIP, MinIP
  - [ ] Overlay PET on CT with configurable opacity

#### 5.3 Export and Sharing
- [ ] Export individual images:
  - [ ] PNG export with current window/level applied
  - [ ] JPEG export with quality slider
  - [ ] TIFF export for lossless quality
  - [ ] Preserve aspect ratio and pixel spacing metadata
- [ ] Export series as multi-page PDF:
  - [ ] Include patient information header
  - [ ] Configurable images per page (1, 2, 4, 6, 9)
  - [ ] Include measurements and annotations
- [ ] Export DICOM files:
  - [ ] Original DICOM (unmodified)
  - [ ] With presentation state (GSPS file)
  - [ ] Anonymized DICOM (remove patient info)
- [ ] Share functionality:
  - [ ] ShareSheet integration (AirDrop, Messages, Mail)
  - [ ] Save to Photos Library
  - [ ] Export to Files app
  - [ ] Print support (AirPrint)

#### 5.4 Anonymization
- [ ] Implement DICOM anonymization:
  - [ ] Remove patient name, ID, birth date
  - [ ] Remove study date/time (optional: shift by offset)
  - [ ] Remove institution name, physician names
  - [ ] Preserve UIDs or generate new ones
  - [ ] Preserve pixel data and technical parameters
- [ ] Add anonymization UI:
  - [ ] Anonymize before export option
  - [ ] Batch anonymize entire study
  - [ ] Preview anonymized metadata

#### 5.5 Advanced Viewing Features
- [ ] Implement comparison mode:
  - [ ] Side-by-side view of two images
  - [ ] Synchronized zoom and pan
  - [ ] Link/unlink controls
- [ ] Add DICOM metadata viewer:
  - [ ] Display all DICOM tags in searchable list
  - [ ] Show tag number, VR, value
  - [ ] Copy tag values to clipboard
  - [ ] Export metadata as JSON/CSV

### Technical Notes
- Use DICOMKit's `PresentationState` and `PresentationStateApplicator` APIs
- Reference: DICOM PS3.3 A.33 for GSPS
- Reference: DICOM PS3.3 A.34-A.36 for color/pseudo-color/blending PS
- Use PDFKit for PDF generation on iOS
- Implement anonymization following DICOM PS3.15 guidelines

### Acceptance Criteria
- [x] GSPS files load and apply correctly
- [x] Color presentation states render accurately
- [x] Export formats preserve image quality
- [x] Anonymization removes all patient identifiers
- [x] Comparison mode synchronizes correctly

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 6: Polish and Optimization (Weeks 11-12)

**Status**: Planned  
**Goal**: Optimize performance, enhance UX, and prepare for App Store submission

### Deliverables

#### 6.1 Performance Optimization
- [ ] Profile with Instruments:
  - [ ] Time Profiler: identify slow code paths
  - [ ] Allocations: detect memory leaks
  - [ ] Leaks: verify no retain cycles
  - [ ] Core Animation: ensure 60fps
- [ ] Optimize image loading:
  - [ ] Implement lazy loading for thumbnails
  - [ ] Use memory-mapped files for large images
  - [ ] Downscale images for display (no full resolution if not needed)
- [ ] Optimize rendering:
  - [ ] Use Metal for pixel data processing if needed
  - [ ] Cache CGImages to avoid repeated conversion
  - [ ] Implement background processing for heavy tasks
- [ ] Reduce memory footprint:
  - [ ] Implement aggressive cache eviction
  - [ ] Compress thumbnails in memory
  - [ ] Release unused resources on memory warning

#### 6.2 User Experience Enhancements
- [ ] Improve visual design:
  - [ ] Consistent color scheme and typography
  - [ ] Dark mode support
  - [ ] SF Symbols for icons
  - [ ] Smooth animations and transitions
- [ ] Add onboarding flow:
  - [ ] Welcome screen with app overview
  - [ ] Quick tutorial for gestures and tools
  - [ ] Sample DICOM files for exploration
  - [ ] "Don't show again" option
- [ ] Implement settings screen:
  - [ ] Default window/level presets
  - [ ] Gesture sensitivity controls
  - [ ] Thumbnail size preference
  - [ ] Storage location preference
  - [ ] Anonymization settings
- [ ] Add help and documentation:
  - [ ] In-app help button with tooltips
  - [ ] Gesture guide (swipe down to view)
  - [ ] FAQ section
  - [ ] Link to online documentation

#### 6.3 Error Handling and Edge Cases
- [ ] Robust error handling:
  - [ ] User-friendly error messages
  - [ ] Retry mechanism for transient errors
  - [ ] Graceful degradation for unsupported features
  - [ ] Error logging for diagnostics
- [ ] Handle edge cases:
  - [ ] Missing DICOM tags (use defaults)
  - [ ] Unsupported transfer syntaxes (show warning)
  - [ ] Corrupted files (skip and continue)
  - [ ] Out-of-memory scenarios (show alert, free resources)
  - [ ] Large multi-frame images (limit frame preloading)

#### 6.4 Accessibility
- [ ] VoiceOver support:
  - [ ] Label all UI elements
  - [ ] Provide context for images
  - [ ] Describe measurements verbally
- [ ] Dynamic Type support:
  - [ ] Scale text with system settings
  - [ ] Test at largest accessibility sizes
- [ ] Reduce Motion support:
  - [ ] Disable animations if enabled
  - [ ] Use crossfade instead of slides
- [ ] High Contrast mode:
  - [ ] Increase button contrast
  - [ ] Adjust overlay colors

#### 6.5 Testing and Quality Assurance
- [ ] Unit tests:
  - [ ] ViewModel logic: 80%+ coverage
  - [ ] DICOM parsing edge cases
  - [ ] Measurement calculations
  - [ ] Anonymization correctness
- [ ] UI tests:
  - [ ] Critical user flows (import → view → measure → export)
  - [ ] Gesture interactions
  - [ ] Navigation paths
- [ ] Manual testing:
  - [ ] Test on iPhone 15 Pro, iPhone SE, iPad Pro
  - [ ] Test with real DICOM files from different modalities
  - [ ] Test with various file sizes (1 MB to 500 MB)
  - [ ] Test with multi-frame series (500+ frames)
  - [ ] Test memory usage over extended sessions

#### 6.6 App Store Preparation
- [ ] App Store metadata:
  - [ ] App name: "DICOMViewer - Medical Imaging"
  - [ ] Subtitle: "DICOM Image Viewer for Medical Professionals"
  - [ ] Keywords: DICOM, medical, imaging, radiology, CT, MR, X-ray
  - [ ] Description highlighting features and use cases
- [ ] Screenshots and previews:
  - [ ] 5 iPhone screenshots (6.7", 6.5")
  - [ ] 5 iPad screenshots (12.9")
  - [ ] Optional: App preview video (30 seconds)
- [ ] Privacy policy:
  - [ ] Document data handling practices
  - [ ] Clarify that app processes data locally
  - [ ] No data collection or tracking
- [ ] App review notes:
  - [ ] Provide sample DICOM files for testing
  - [ ] Explain medical use case
  - [ ] Clarify not intended for diagnostic use (disclaimer)
- [ ] Build and submit:
  - [ ] Create App Store build
  - [ ] TestFlight beta testing with 10+ users
  - [ ] Address TestFlight feedback
  - [ ] Submit for App Store review

### Technical Notes
- Use Xcode Instruments for performance profiling
- Follow Apple's Human Interface Guidelines
- Reference: WCAG 2.1 for accessibility standards
- Test on multiple device sizes and iOS versions

### Acceptance Criteria
- [x] App achieves 60fps in all interactions
- [x] Memory usage <200MB for typical studies
- [x] App Store submission approved without issues
- [x] All accessibility criteria met (VoiceOver, Dynamic Type)
- [x] Zero critical bugs in TestFlight

### Estimated Effort
**2 weeks** (1 developer)

---

## Milestone 7: Post-Launch Iteration (Ongoing)

**Status**: Planned  
**Goal**: Monitor app performance, gather user feedback, and implement improvements

### Deliverables

#### 7.1 Monitoring and Analytics
- [ ] Implement crash reporting (Crashlytics or similar)
- [ ] Monitor app performance metrics:
  - [ ] App launch time
  - [ ] Average memory usage
  - [ ] Crash-free session rate
- [ ] Track user engagement (privacy-preserving):
  - [ ] Active users
  - [ ] Session duration
  - [ ] Feature adoption rates

#### 7.2 User Feedback
- [ ] Monitor App Store reviews and ratings
- [ ] Create feedback mechanism in app:
  - [ ] Feedback form with email submission
  - [ ] Bug report template
  - [ ] Feature request option
- [ ] Establish communication channels:
  - [ ] GitHub Discussions for community
  - [ ] Email support address
  - [ ] Twitter/social media presence

#### 7.3 Feature Enhancements (v1.1+)
- [ ] Implement user-requested features:
  - [ ] Cloud sync via iCloud Drive
  - [ ] DICOM networking (C-MOVE, C-STORE) - iOS limitations
  - [ ] Advanced 3D MPR viewing
  - [ ] AI-powered auto-measurements
  - [ ] Voice commands and dictation
- [ ] Integration with DICOMKit new features:
  - [ ] RT Structure Set overlay (from Milestone 10.4, 10.5)
  - [ ] Waveform display (ECG, audio)
  - [ ] Enhanced SR creation

#### 7.4 Platform Expansion
- [ ] iPad-optimized features:
  - [ ] Multi-window support
  - [ ] Drag-and-drop between windows
  - [ ] Split view for comparison
  - [ ] Apple Pencil annotation support
- [ ] visionOS companion app:
  - [ ] Spatial volume rendering
  - [ ] Hand gesture controls
  - [ ] Immersive viewing mode

### Estimated Effort
**Ongoing** (maintenance and updates)

---

## Implementation Strategy

### Phase 1: Foundation (Milestones 1-2, Weeks 1-4)
**Focus**: Project setup, architecture, and file management

Key Activities:
- Set up development environment and CI/CD
- Implement core data models and architecture
- Build file import and library management

Deliverable: Functional file browser with thumbnail view

### Phase 2: Core Viewer (Milestone 3, Weeks 5-6)
**Focus**: Image viewing with gestures and display controls

Key Activities:
- Implement image rendering pipeline
- Add touch gesture controls (zoom, pan, rotate)
- Implement window/level adjustment
- Build cine mode for multi-frame images

Deliverable: Fully functional image viewer with gestures

### Phase 3: Measurements (Milestone 4, Weeks 7-8)
**Focus**: Clinical measurement tools

Key Activities:
- Implement linear and ROI measurement tools
- Build measurement overlay rendering
- Add measurement persistence and export

Deliverable: Complete measurement toolkit

### Phase 4: Advanced Features (Milestone 5, Weeks 9-10)
**Focus**: Presentation states, export, and sharing

Key Activities:
- Integrate DICOMKit presentation state support
- Implement export functionality (PNG, PDF, DICOM)
- Add anonymization and sharing features

Deliverable: Production-ready feature set

### Phase 5: Polish (Milestone 6, Weeks 11-12)
**Focus**: Optimization, testing, and App Store preparation

Key Activities:
- Performance profiling and optimization
- Comprehensive testing (unit, UI, manual)
- App Store submission preparation

Deliverable: App Store release

### Phase 6: Post-Launch (Milestone 7, Ongoing)
**Focus**: Monitoring, feedback, and iteration

Key Activities:
- Monitor app performance and crashes
- Gather user feedback
- Plan and implement enhancements

Deliverable: Continuous improvements

---

## Technical Architecture

### App Structure
```
DICOMViewerApp (iOS)
├── App/
│   ├── DICOMViewerApp.swift          # App entry point
│   ├── AppDelegate.swift             # App lifecycle
│   └── SceneDelegate.swift           # Scene management
├── Models/
│   ├── DICOMStudy.swift              # Study model
│   ├── DICOMSeries.swift             # Series model
│   ├── DICOMImage.swift              # Image model
│   ├── Measurement.swift             # Measurement protocol and types
│   └── DICOMLibrary.swift            # Library database
├── ViewModels/
│   ├── LibraryViewModel.swift        # Library state
│   ├── ViewerViewModel.swift         # Viewer state
│   ├── ImportViewModel.swift         # Import state
│   └── MeasurementViewModel.swift    # Measurement state
├── Views/
│   ├── LibraryView.swift             # Study/series browser
│   ├── ViewerView.swift              # Image viewer
│   ├── ImportView.swift              # File import
│   ├── MeasurementView.swift         # Measurement tools
│   ├── SettingsView.swift            # App settings
│   └── Components/
│       ├── ThumbnailGrid.swift       # Thumbnail grid
│       ├── ImageCanvas.swift         # Image display canvas
│       ├── MeasurementOverlay.swift  # Measurement rendering
│       └── ControlsToolbar.swift     # Viewer controls
├── Services/
│   ├── DICOMFileService.swift        # File I/O
│   ├── ThumbnailService.swift        # Thumbnail generation
│   ├── StorageService.swift          # Local storage
│   └── ExportService.swift           # Export functionality
├── Utilities/
│   ├── DICOMParser+Extensions.swift  # DICOMKit helpers
│   ├── ImageRenderer.swift           # Pixel data to UIImage
│   └── Errors.swift                  # Error types
└── Resources/
    ├── Assets.xcassets               # App icons, colors
    ├── Localizable.strings           # Localization
    └── SampleFiles/                  # Test DICOM files
```

### Key Dependencies
- **DICOMKit v1.0.2+**: Core DICOM parsing, rendering, and SR/PS support
- **SwiftUI**: UI framework
- **Combine or async/await**: Reactive programming
- **Core Data or SwiftData**: Local database
- **UIKit**: Image handling (UIImage, CGImage)
- **PDFKit**: PDF export
- **CoreGraphics**: Image rendering

---

## Testing Strategy

### Unit Tests
**Target Coverage**: 80%+

Test Areas:
- ViewModel logic (state transitions, business logic)
- DICOM parsing edge cases (missing tags, invalid values)
- Measurement calculations (distance, area, statistics)
- Anonymization correctness (all PHI removed)
- Export format validation (PNG, JPEG, DICOM structure)

Example Tests:
```swift
func testLinearMeasurementCalculation() {
    // Given: Two points and pixel spacing
    let point1 = CGPoint(x: 0, y: 0)
    let point2 = CGPoint(x: 100, y: 100)
    let pixelSpacing = 0.5 // mm
    
    // When: Calculate distance
    let measurement = LinearMeasurement(start: point1, end: point2, pixelSpacing: pixelSpacing)
    
    // Then: Distance should be correct
    let expected = sqrt(100*100 + 100*100) * 0.5
    XCTAssertEqual(measurement.distanceMM, expected, accuracy: 0.01)
}

func testWindowLevelApplication() {
    // Test VOI LUT transformation with various window/level values
}

func testAnonymizationRemovesPHI() {
    // Verify patient name, ID, birth date are removed
}
```

### Integration Tests
Test Areas:
- File import flow (select file → parse → store → display)
- Image rendering pipeline (pixel data → CGImage → display)
- Measurement persistence (create → save → reload)
- Export workflows (image → format conversion → share)

### UI Tests
Test Areas:
- Critical user flows:
  - Import DICOM file → view in library → open viewer → navigate images
  - Open image → draw measurement → save → verify persistence
  - Select image → export as PNG → verify file created
- Gesture interactions (pinch, pan, swipe)
- Navigation paths (library → viewer → back)
- Settings changes (apply and verify)

Example UI Test:
```swift
func testImportAndViewWorkflow() {
    let app = XCUIApplication()
    app.launch()
    
    // Tap import button
    app.buttons["Import"].tap()
    
    // Select test DICOM file (requires test setup)
    // ...
    
    // Verify file appears in library
    XCTAssertTrue(app.staticTexts["Test Study"].exists)
    
    // Tap to open viewer
    app.staticTexts["Test Study"].tap()
    
    // Verify image displayed
    XCTAssertTrue(app.images["DICOMImage"].exists)
}
```

### Manual Testing
Test Scenarios:
- Import variety of DICOM files (CT, MR, X-ray, multi-frame)
- Test with different file sizes (1 MB to 500 MB)
- Test with multi-frame series (500+ frames)
- Verify memory usage during extended sessions
- Test on different devices (iPhone 15 Pro, iPhone SE, iPad Pro)
- Test with real-world DICOM files from hospitals/clinics

---

## Risk Management

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Performance issues with large files | Medium | High | Implement lazy loading, memory mapping, profiling |
| Memory constraints on older devices | Medium | Medium | Aggressive cache eviction, image downscaling |
| DICOM file compatibility issues | High | Medium | Extensive testing with diverse file sets, error handling |
| Gesture conflicts in UI | Low | Medium | Careful gesture design, testing with users |
| App Store rejection (medical disclaimer) | Medium | High | Clear disclaimer, privacy policy, medical use case documentation |

### Resource Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Scope creep beyond 12 weeks | Medium | Medium | Fixed milestone deadlines, MVP focus |
| Testing device availability | Low | Medium | TestFlight beta, community testing |
| DICOMKit API changes | Low | High | Use stable v1.0+ APIs, monitor releases |

### User Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|------------|
| Users expect diagnostic-quality viewer | Medium | High | Clear disclaimer: "Not intended for diagnostic use" |
| Privacy concerns with PHI | Medium | High | Local-only processing, anonymization, privacy policy |
| Feature requests exceed scope | High | Low | Roadmap communication, prioritization |

---

## Success Metrics

### Technical Metrics
- **Performance**: 60fps scrolling and gestures, <200ms UI latency
- **Memory**: <200MB usage for typical studies
- **Reliability**: Zero critical bugs in production
- **Test Coverage**: 80%+ for ViewModels and core logic
- **Build Time**: <2 minutes for incremental builds

### User Metrics
- **Downloads**: 1,000+ in first month
- **Ratings**: 4.5+ stars on App Store
- **Retention**: 40%+ day-7 retention
- **Engagement**: 10+ minutes average session duration
- **Crashes**: <0.1% crash rate

### Business Metrics
- **Community Engagement**: 100+ GitHub stars, 10+ contributors
- **Adoption**: Featured by Apple Developer, medical imaging publications
- **Integration**: 5+ third-party apps using DICOMKit
- **Feedback**: Positive testimonials from medical professionals

---

## Future Enhancements (Post-v1.0)

### v1.1 - Cloud Integration
- iCloud Drive sync for studies
- Dropbox/Google Drive import
- Cloud backup and restore

### v1.2 - Advanced Viewing
- Multi-window support (iPad)
- Comparison mode with priors
- 3D MPR (multiplanar reconstruction)
- Curved MPR for vessels

### v1.3 - AI Features
- AI-powered auto-measurements
- Lesion detection overlay
- CAD integration
- Auto-windowing with ML

### v1.4 - Collaboration
- Annotation sharing via email
- Real-time collaboration (multi-user)
- Teaching file creation and sharing

### v2.0 - Platform Expansion
- visionOS native app (spatial computing)
- macOS companion app (professional workstation)
- watchOS quick viewer
- Web viewer (WebAssembly)

---

## Conclusion

This comprehensive iOS application plan provides a clear, milestone-driven roadmap for developing **DICOMViewer iOS**, a production-quality medical imaging application built on DICOMKit. The plan emphasizes:

1. **Incremental Delivery**: Each milestone delivers working features
2. **Clinical Focus**: Features aligned with real medical imaging workflows
3. **Quality First**: Comprehensive testing, performance optimization, accessibility
4. **Platform Excellence**: Leverage iOS capabilities and best practices
5. **Community Value**: Serve as reference implementation for DICOMKit

**Total Estimated Effort**: 12-14 weeks (1 senior iOS developer full-time)  
**Target Release**: App Store launch post-Milestone 6  
**Dependencies**: DICOMKit v1.0+ with Presentation State and SR support  

**Next Steps**:
1. Review and approve this plan with stakeholders
2. Set up development environment (Milestone 1.1)
3. Begin Phase 1 implementation (Milestones 1-2)
4. Regular progress reviews at end of each milestone
5. TestFlight beta in Week 10, App Store submission in Week 12

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-05  
**Author**: DICOMKit Team  
**Status**: Ready for Implementation
