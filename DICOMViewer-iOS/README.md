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

### Phase 2 (Planned)

- Advanced window/level with two-finger gesture
- Presentation state (GSPS) support
- Cine playback modes (loop, bounce)

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
│   └── ViewerViewModel.swift     # Image viewer state
├── Views/
│   ├── Library/
│   │   └── LibraryView.swift     # Study browser
│   ├── Viewer/
│   │   ├── ViewerContainerView.swift
│   │   └── SeriesPickerView.swift
│   ├── Metadata/
│   │   └── MetadataView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── DICOMFileService.swift    # File I/O
│   ├── ThumbnailService.swift    # Thumbnail cache
│   └── ImageRenderingService.swift
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
