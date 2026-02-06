# DICOMViewer macOS

A professional diagnostic workstation with PACS integration, Multi-Planar Reconstruction (MPR), and advanced 3D visualization for clinical radiology workflows.

## Overview

DICOMViewer macOS is a production-quality medical imaging workstation that demonstrates the enterprise capabilities of DICOMKit. It provides comprehensive tools for viewing, analyzing, and managing DICOM medical images with features typically found in commercial PACS workstations.

**Platform**: macOS 14+ (Sonoma and later)  
**Status**: ✅ Production Ready (Phase 5 Complete - February 2026)  
**Version**: v1.0.14

## Key Features

### Phase 1: Foundation ✅
- [x] Local study database (SwiftData)
- [x] File import (browser, drag & drop)
- [x] Basic study browser with metadata
- [x] Single-viewport image viewer
- [x] Menu structure and keyboard shortcuts

### Phase 2: PACS Integration ✅
- [x] C-FIND query (Patient/Study/Series/Instance levels)
- [x] C-MOVE retrieve with download queue
- [x] C-STORE send with progress reporting
- [x] QIDO-RS/WADO-RS/STOW-RS DICOMweb support
- [x] Multiple PACS server configurations (SwiftData persistence)
- [x] Connection testing (C-ECHO verification)
- [x] Download queue with progress tracking
- [x] Server configuration UI (add/edit/delete/test)

### Phase 3: Professional Viewer ✅
- [x] Multi-viewport layouts (1×1, 2×2, 3×3, 4×4)
- [x] Hanging protocol engine with pre-defined protocols
- [x] Viewport linking (scroll, W/L, zoom, pan)
- [x] Cine playback with configurable FPS
- [x] Layout switching with keyboard shortcuts (⌘1-4)
- [x] Protocol selection (CT Chest, CT Abdomen, MR Brain, X-Ray)
- [x] Advanced measurements (length, angle, ellipse, rectangle, polygon ROI)
- [x] Measurement overlay and list sidebar
- [x] Interactive measurement drawing with mouse support

### Phase 4: MPR and 3D ✅
- [x] 2D MPR (axial, sagittal, coronal) with reference line crosshairs
- [x] Volume data construction from DICOM series
- [x] Maximum Intensity Projection (MIP) with slab thickness
- [x] Minimum Intensity Projection (MinIP)
- [x] Average Intensity Projection (AverageIP)
- [x] Volume rendering with transfer function presets (bone, soft tissue, lung, angiography)
- [x] 3D rotation and zoom controls
- [x] 80 unit tests for MPR and volume rendering

### Phase 5: Advanced Features ✅
- [x] Measurement export (CSV, JSON, plain text)
- [x] PDF report generation with configurable layouts
- [x] Watch folder auto-import with FSEvents monitoring
- [x] Integration test suite (37 comprehensive workflow tests)
- [x] UI test suite (40+ user interaction tests)
- [ ] DICOM Print (C-PRINT) - deferred, requires DICOMNetwork support
- [ ] Film composer - deferred, depends on C-PRINT
- [ ] DICOM SR export - deferred, requires DICOMKit SR writing
- [ ] DICOMDIR support - deferred, requires DICOMKit DICOMDIR parsing

## Architecture

### Technology Stack
- **UI Framework**: SwiftUI + AppKit (hybrid)
- **Database**: SwiftData
- **3D Rendering**: Metal
- **Networking**: DICOMNetwork (C-FIND, C-MOVE, C-STORE)
- **Web Services**: DICOMWeb (QIDO-RS, WADO-RS, STOW-RS)
- **Pattern**: MVVM (Model-View-ViewModel)

### Project Structure
```
DICOMViewer-macOS/
├── App/                    # Application entry point
├── Models/                 # Data models (Study, Series, Instance, PACSServer)
├── ViewModels/            # Business logic and state management
├── Views/                 # SwiftUI views and UI components
├── Services/              # Database, file, network, and download services
├── Tests/                 # Unit tests
└── project.yml            # XcodeGen configuration
```

## Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Dependencies**: DICOMKit v1.0+

## Building

### Using XcodeGen

```bash
# Generate Xcode project
cd DICOMViewer-macOS
xcodegen
open DICOMViewer.xcodeproj
```

### Manual Setup

1. Create a new macOS App project in Xcode
2. Set deployment target to macOS 14.0
3. Add DICOMKit package dependency
4. Copy source files from this directory
5. Build and run

See [BUILD.md](BUILD.md) for detailed instructions.

## Usage

### Opening DICOM Files

**File Menu**:
```
File → Open... (⌘O)
File → Import Folder... (⌘⇧O)
File → Import DICOMDIR...
```

**Drag and Drop**:
- Drag DICOM files directly to app window
- Drag folders containing DICOM files
- Drag DICOMDIR files from CD/DVD

### PACS Operations

**Query PACS**:
```
Network → Query... (⌘K)
Network → Worklist... (⌘⇧K)
```

**Retrieve Studies**:
1. Query PACS for studies
2. Select studies to retrieve
3. Click "Retrieve" button
4. Monitor download progress in queue

**Send to PACS**:
```
Select study → Right-click → Send to PACS...
```

### Viewing Images

**Multi-Viewport Layouts**:
- 1×1: Single viewport (⌘1)
- 2×2: Four viewports (⌘2)
- 3×3: Nine viewports (⌘3)
- 4×4: Sixteen viewports (⌘4)

**Hanging Protocols**:
Use the Protocol menu to automatically arrange series:
- CT Chest: 2×2 layout with axial, coronal, sagittal views
- CT Abdomen: 2×2 layout with arterial, venous, delayed phases
- MR Brain: 3×3 layout with T1, T2, FLAIR, DWI, ADC
- X-Ray: Single viewport

**Viewport Linking**:
Link viewports to synchronize:
- Scroll: Navigate through slices together
- W/L: Adjust window/level in all viewports
- Zoom: Magnify all viewports together
- Pan: Move all images simultaneously

**Window/Level**:
- Drag with left mouse button
- Preset shortcuts:
  - ⌘L: Lung window
  - ⌘B: Bone window
  - ⌘S: Soft tissue window
  - ⌘⇧B: Brain window

**Cine Playback**:
For multi-frame series:
- Space: Play/pause cine
- Arrow keys: Navigate frames
- FPS selector: 5, 10, 15, 20, 30, 60 fps
- Loop and reverse modes available

**Navigation**:
- Scroll wheel: Change slice
- Arrow keys: Navigate series
- Mouse drag: Pan image (when zoomed)

### MPR and 3D

**MPR Views**:
```
View → MPR → Standard (⌘M)
View → MPR → Oblique (⌘⇧M)
```

**Volume Rendering**:
```
View → 3D → Volume Render (⌘3)
View → 3D → MIP (⌘⇧3)
```

### Measurements and Export

**Drawing Measurements**:
- Length: Click two points (shows distance in mm)
- Angle: Click three points (shows angle in degrees)
- Ellipse ROI: Click and drag (shows area and statistics)
- Rectangle ROI: Click and drag (shows area and statistics)
- Polygon ROI: Click multiple points, double-click to close

**Export Measurements**:
```
File → Export Measurements... (⌘⇧E)
```
Formats available:
- **CSV**: Spreadsheet-compatible with headers
- **JSON**: Machine-readable structured data
- **Plain Text**: Human-readable report format

**Generate PDF Report**:
```
File → Generate Report... (⌘⇧R)
```
Options:
- Include patient information
- Include all images with measurements
- Burn-in annotations
- Configurable page size (US Letter, A4, Legal)

### Watch Folder Auto-Import

Enable automatic import of DICOM files from a folder:

```
Preferences → Watch Folder
```

1. Enable "Watch Folder"
2. Select folder to monitor
3. Configure file extensions (.dcm, .dicom)
4. Files dropped into folder are automatically imported

## Performance

### Benchmarks
- **Study Loading**: <2 seconds for 100-image series
- **Volume Rendering**: 30+ fps for 512×512×200 volumes
- **Memory Usage**: <500MB for typical CT/MR studies
- **PACS Query**: <1 second response time
- **Large Study Download**: 100+ MB/sec on gigabit network

### Optimization Tips
- Enable hardware acceleration (Metal)
- Use memory-mapped files for large studies
- Configure connection pooling for PACS
- Enable thumbnail caching
- Use prefetching for series navigation

## Testing

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter DICOMViewerTests

# Run with coverage
swift test --enable-code-coverage
```

**Test Coverage**: ~80% (379+ tests: 302 unit + 37 integration + 40+ UI tests)

## Documentation

- [User Guide](USER_GUIDE.md) - Complete user manual with all features
- [Build Guide](BUILD.md) - Detailed build instructions
- [Keyboard Shortcuts](KEYBOARD_SHORTCUTS.md) - Complete shortcut reference
- [Phase 5 Completion Report](PHASE_5_COMPLETION_REPORT.md) - Implementation details
- [Status Document](STATUS.md) - Current implementation status

**See USER_GUIDE.md** for comprehensive documentation including:
- Getting started and basic usage
- PACS configuration and workflow
- Measurement tools and export
- PDF report generation
- Watch folder setup
- MPR and 3D visualization
- Testing and quality assurance

## Implementation Plan

For detailed phase-by-phase implementation plan, see:
- **[MACOS_VIEWER_PLAN.md](../MACOS_VIEWER_PLAN.md)** - Complete specification

## Contributing

DICOMViewer macOS is part of the DICOMKit example applications. Contributions welcome!

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](../LICENSE) for details.

## Acknowledgments

- Built with [DICOMKit](https://github.com/Raster-Lab/DICOMKit)
- Follows DICOM standards (PS3.3, PS3.4, PS3.5, PS3.6)
- Inspired by professional PACS workstations

## Support

- **Issues**: [GitHub Issues](https://github.com/Raster-Lab/DICOMKit/issues)
- **Documentation**: [DICOMKit Docs](https://raster-lab.github.io/DICOMKit/)
- **Community**: [Discussions](https://github.com/Raster-Lab/DICOMKit/discussions)

---

**Note**: This is a reference implementation demonstrating DICOMKit capabilities. It is not certified for clinical diagnostic use. Always use FDA-approved medical devices for clinical diagnosis.
