# DICOMViewer iOS

A mobile DICOM medical image viewer for iOS and iPadOS, built with SwiftUI and DICOMKit.

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

### Phase 3 (Planned)

- Measurement tools (length, angle, ROI)
- ROI statistics (mean, std dev, min, max)
- Measurement export

### Phase 4 (Planned)

- Accessibility improvements
- Performance optimization
- App Store preparation

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
│   └── ViewerViewModel.swift     # Image viewer state with GSPS support
├── Views/
│   ├── Library/
│   │   └── LibraryView.swift     # Study browser
│   ├── Viewer/
│   │   ├── ViewerContainerView.swift     # Main viewer with GSPS integration
│   │   ├── SeriesPickerView.swift
│   │   ├── PresentationStateOverlayView.swift  # GSPS annotation/shutter rendering
│   │   └── PresentationStatePickerView.swift   # GSPS selection UI
│   ├── Metadata/
│   │   └── MetadataView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── DICOMFileService.swift         # File I/O
│   ├── ThumbnailService.swift         # Thumbnail cache
│   ├── ImageRenderingService.swift    # Image rendering
│   └── PresentationStateService.swift # GSPS loading and management
├── Tests/
│   ├── MeasurementTests.swift         # Measurement model tests
│   └── PresentationStateTests.swift   # GSPS functionality tests
└── Resources/
    └── (Assets, Localization)
```

## Building the Project

### Option 1: Create Xcode Project

1. Open Xcode and create a new iOS App project
2. Name it "DICOMViewer"
3. Set deployment target to iOS 17.0
4. Add DICOMKit as a package dependency:
   - File → Add Package Dependencies
   - Enter: `https://github.com/raster-image/DICOMKit.git`
   - Select version 1.0 or later
5. Copy the source files from this directory into your project

### Option 2: Use Swift Package Manager

Add to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/raster-image/DICOMKit.git", from: "1.0.0")
]
```

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
