# DICOMViewer iOS

A mobile DICOM medical image viewer for iOS and iPadOS, built with SwiftUI and DICOMKit.

## Status

**Implementation Status:** ✅ **Complete** (Phases 1-4)  
**Version:** v1.0 (Ready for Xcode project creation and testing)  
**Last Updated:** February 2026

All core features have been implemented:
- ✅ Phase 1: Foundation (File management, Image viewing, Display controls)
- ✅ Phase 2: Presentation States (GSPS support, Annotations, Shutters)
- ✅ Phase 3: Measurements and Tools (Linear measurements, ROI tools, Metadata/Export)
- ✅ Phase 4: Polish and Testing (Advanced features, Accessibility, Performance)

**Next Steps:** Create Xcode project and integrate with App Store (see [BUILD.md](BUILD.md))

## Overview

DICOMViewer iOS is a production-quality medical imaging application that demonstrates DICOMKit's capabilities on mobile devices. It provides a touch-optimized interface for viewing, navigating, and analyzing DICOM images.

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- DICOMKit 1.0+

## Features

### Phase 1 (Foundation) ✅

- **File Management**
  - Import DICOM files from Files app, iCloud Drive, email
  - Study list with grid and list views
  - Search by patient name, ID, or study description
  - Filter by modality (CT, MR, CR, US, etc.)
  - Thumbnail generation and caching
  - Storage management

- **Image Viewing**
  - Single-frame and multi-frame image display
  - Pinch-to-zoom gesture
  - Pan gesture with momentum
  - Double-tap to fit/zoom toggle
  - Frame navigation with scrubber
  - Cine playback with adjustable frame rate

- **Display Controls**
  - Window/level adjustment
  - Preset window/level values (Lung, Bone, Soft Tissue, etc.)
  - Grayscale inversion
  - Image rotation (90° increments)
  - View reset

- **Data Models**
  - SwiftData persistence for study library
  - Study, Series, Instance hierarchy
  - Measurement model with pixel spacing support

### Phase 2 (Presentation States) ✅

- **GSPS (Grayscale Softcopy Presentation State) Support**
  - Load and apply GSPS objects automatically
  - Grayscale LUT chain (Modality LUT → VOI LUT → Presentation LUT)
  - Window/level from presentation state
  - Spatial transformations (rotation, flip)
  - Display area selection (zoom, pan)
  
- **Annotation Rendering**
  - Graphic objects (point, polyline, circle, ellipse)
  - Text annotations with bounding boxes
  - Anchor points with connecting lines
  - Multi-layer support with layer ordering
  - Layer colors (grayscale and RGB)
  
- **Shutter Display**
  - Rectangular shutters
  - Circular shutters
  - Polygonal shutters
  - Configurable shutter presentation value
  
- **Presentation State Management**
  - List available presentation states
  - Apply/remove presentation state
  - Feature badges (W/L, annotations, shutters, transforms)
  - GSPS indicator overlay

### Phase 3 (Measurements and Tools) ✅

- **Linear Measurements**
  - Length measurement tool with pixel spacing support
  - Angle measurement tool (three-point angle)
  - Touch gesture drawing
  - Endpoint editing after creation
  - Measurement list UI
  - Show/hide measurements toggle
  - Delete individual measurements

- **ROI Tools and Statistics**
  - Ellipse ROI tool
  - Rectangle ROI tool
  - Freehand ROI tool
  - ROI editing (move, resize)
  - Area and perimeter calculation
  - Pixel value extraction
  - Statistics display (mean, std dev, min, max)
  - Copy statistics to clipboard

- **Metadata Display and Export**
  - Complete metadata viewer UI
  - Patient, study, series, and storage information
  - Export metadata as JSON or CSV
  - Share exported metadata files
  - Quick info panel for key metadata

- **Image Export** ✨ **NEW**
  - PNG export (lossless)
  - JPEG export with quality settings (10-100%)
  - File size estimation
  - Save to Photos library
  - Share sheet integration
  - Export current frame with applied W/L and transforms

### Phase 4 (Polish and Testing) ✅

- **Advanced Features**
  - Side-by-side comparison mode
  - Synchronized scrolling across series
  - Synchronized window/level
  - Synchronized zoom/pan
  - Brightness/contrast adjustments
  - Settings screen with user preferences
  - Preference persistence

- **UI Polish and Accessibility**
  - Dark mode (default for medical imaging)
  - Light mode support
  - High contrast throughout
  - Accessibility labels for all controls
  - VoiceOver support
  - Dynamic Type support
  - Haptic feedback for gestures
  - Loading indicators for long operations
  - User-friendly error alerts
  - Smooth animations and transitions
  - Tested on multiple device sizes

- **Integration Testing and Performance**
  - Comprehensive integration tests
  - Real DICOM file testing (CT, MR, CR, US)
  - Multi-frame series support (100+ frames)
  - Large file handling (>100MB)
  - Memory profiling with Instruments
  - CPU profiling and optimization
  - Thumbnail generation optimization
  - Image rendering pipeline optimization
  - Memory leak fixes
  - Testing on oldest supported devices
  - iPad multitasking support
  - Performance benchmark suite

## Project Structure

```
DICOMViewer-iOS/
├── App/
│   ├── DICOMViewerApp.swift      # App entry point
│   └── ContentView.swift         # Main tab navigation
├── Models/
│   ├── DICOMStudy.swift          # Study data model
│   ├── DICOMSeries.swift         # Series data model
│   ├── DICOMInstance.swift       # Instance data model
│   └── Measurement.swift         # Measurement models
├── ViewModels/
│   ├── LibraryViewModel.swift    # Library management
│   ├── ViewerViewModel.swift     # Image viewer state with GSPS support
│   └── ComparisonViewModel.swift # NEW: Comparison mode synchronization
├── Views/
│   ├── Library/
│   │   └── LibraryView.swift     # Study browser
│   ├── Viewer/
│   │   ├── ViewerContainerView.swift     # Main viewer with GSPS integration
│   │   ├── SeriesPickerView.swift
│   │   ├── PresentationStateOverlayView.swift  # GSPS annotation/shutter rendering
│   │   ├── PresentationStatePickerView.swift   # GSPS selection UI
│   │   ├── ComparisonView.swift                # NEW: Side-by-side comparison view
│   │   └── ExportView.swift                    # NEW: Image export interface
│   ├── Metadata/
│   │   └── MetadataView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── DICOMFileService.swift         # File I/O
│   ├── ThumbnailService.swift         # Thumbnail cache
│   ├── ImageRenderingService.swift    # Image rendering
│   ├── PresentationStateService.swift # GSPS loading and management
│   └── ExportService.swift            # NEW: Image and metadata export
├── Tests/
│   ├── MeasurementTests.swift         # Measurement model tests
│   ├── PresentationStateTests.swift   # GSPS functionality tests
│   └── ComparisonTests.swift          # NEW: Comparison mode tests (15+ tests)
└── Resources/
    └── (Assets, Localization)
```

## Building the Project

**For detailed build instructions, see [BUILD.md](BUILD.md).**

### Automated Setup (Recommended - NEW!)

The fastest way to get started:

```bash
# Install XcodeGen (one-time setup)
brew install xcodegen

# Generate and open project
cd DICOMViewer-iOS
xcodegen generate
open DICOMViewer.xcodeproj
```

Then in Xcode, select your development team and press ⌘R to run!

See [SETUP_AUTOMATION.md](SETUP_AUTOMATION.md) for automation details and alternative methods.

### Manual Setup

1. **Create an Xcode project:**
   - Open Xcode and create a new iOS App
   - Name: `DICOMViewer`
   - Interface: SwiftUI
   - Deployment Target: iOS 17.0+

2. **Add DICOMKit dependency:**
   - File → Add Package Dependencies
   - URL: `https://github.com/raster-image/DICOMKit.git`
   - Add `DICOMKit` and `DICOMCore` to your target

3. **Add source files:**
   - Drag these folders from `DICOMViewer-iOS/` into Xcode:
     - `App/`, `Models/`, `Services/`, `ViewModels/`, `Views/`
   - Choose "Create groups" (don't copy files)

4. **Build and run:**
   - Select a simulator or device
   - Press ⌘R

See [BUILD.md](BUILD.md) for detailed instructions, troubleshooting, and advanced options.

## Usage

### Importing DICOM Files

1. Tap the "+" button in the Library tab
2. Select DICOM files from the document picker
3. Files are imported and organized by study/series

### Viewing Images

1. Tap a study in the Library to open it
2. Use pinch to zoom, drag to pan
3. Double-tap to toggle fit/zoom
4. Use the scrubber for multi-frame navigation
5. Tap Play for cine playback

### Adjusting Display

1. Tap the W/L button to open window/level controls
2. Select a preset or adjust sliders manually
3. Tap Invert to toggle grayscale inversion
4. Tap Rotate to rotate 90° clockwise
5. Tap Reset to restore default view

### Using Presentation States (GSPS)

1. If a study has associated GSPS files, a presentation state indicator appears in the toolbar
2. Tap the GSPS button in the control bar to open the presentation state picker
3. Select a presentation state to apply its display settings:
   - Window/level values are applied automatically
   - Annotations (graphic and text objects) are rendered as overlays
   - Shutters mask specified regions of the image
   - Spatial transformations (rotation, flip) are applied
4. Feature badges show what each presentation state includes:
   - W/L: Contains window/level settings
   - Numbered badges: Count of annotations or shutters
   - Rotate icon: Contains spatial transformation
5. Select "None" to remove the presentation state and return to default display
6. A blue "GSPS" indicator appears in the image overlay when a presentation state is active

### Using Comparison Mode (NEW)

1. Open an image in the viewer
2. Tap the "Compare" button (split rectangle icon) in the toolbar
3. The comparison view opens with two side-by-side viewers:
   - Left pane shows the current series
   - Right pane shows a second series (or the same series if only one is available)
4. Tap the series icon in either pane header to select a different series
5. Use the link icon at the bottom to toggle synchronization:
   - When linked (blue): Controls are synchronized between both viewers
   - When unlinked (gray): Each viewer can be controlled independently
6. Tap the gear icon to customize what is synchronized:
   - Frame Navigation: Navigate frames in both viewers together
   - Window/Level: Apply same W/L settings to both images
   - Zoom & Pan: Synchronize zoom level and pan position
   - Rotation & Flip: Apply same transforms to both images
7. Use the "Swap" button to exchange the left and right images
8. When synchronized, use gestures on either pane to control both:
   - Pinch to zoom both images simultaneously
   - Pan to move both images together
   - Use frame controls at the bottom to navigate both series
9. Tap "Done" to exit comparison mode and return to single viewer

**Use Cases:**
- Compare pre/post treatment images
- Compare different sequences (T1 vs T2 MRI)
- Compare same anatomy at different time points
- Review left/right anatomical symmetry

### Exporting Images and Metadata (NEW)

**Exporting Images:**
1. Open an image in the viewer
2. Tap the "Export" button (up arrow icon) in the toolbar
3. Choose export format:
   - **PNG**: Lossless compression, larger file size
   - **JPEG**: Lossy compression with adjustable quality (10-100%)
4. For JPEG, adjust the quality slider to balance size vs quality
5. Toggle "Save to Photos" to automatically add to your Photos library
6. Tap "Export Image" to save the file
7. After export, you can:
   - Share via AirDrop, Messages, Mail, etc.
   - Save to Files app
   - Tap "Done" to close

**Exporting Metadata:**
1. Open the Info (ℹ️) view for a study
2. Tap the Export button in the toolbar
3. Choose format:
   - **Export as JSON**: Structured data format
   - **Export as CSV**: Spreadsheet-compatible format
4. Share the exported file via share sheet

**What's Exported:**
- Current window/level settings applied to image
- Current zoom, pan, and rotation state
- Metadata includes patient info, study/series details, and storage info

## Architecture

The app follows the MVVM (Model-View-ViewModel) pattern:

- **Models**: SwiftData models for persistence (DICOMStudy, DICOMSeries, DICOMInstance)
- **ViewModels**: @Observable classes managing state and business logic
- **Views**: SwiftUI views with minimal logic
- **Services**: Actor-based services for file I/O and rendering

### Key Design Decisions

1. **SwiftData for Persistence**: Modern Swift-native persistence framework
2. **Actor-based Services**: Thread-safe file operations and thumbnail caching
3. **@Observable Pattern**: Swift 5.9 observation for reactive UI
4. **Dark Mode Default**: Medical imaging convention for reduced eye strain

## Performance

- Thumbnail caching for fast library browsing
- Lazy loading of pixel data
- Background thread rendering
- Memory-efficient frame navigation

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](../LICENSE)
