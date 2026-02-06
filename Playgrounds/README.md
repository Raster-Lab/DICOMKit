# DICOMKit Playgrounds

Comprehensive sample code and examples demonstrating DICOMKit usage across all features.

## Overview

This collection contains 27+ interactive Swift playground files organized into 6 categories, covering everything from basic file reading to advanced medical imaging workflows. Each playground is a standalone Swift file with multiple examples, comprehensive comments, and quick reference guides.

**Status**: ✅ Complete (All 27 playgrounds finished, 100%)  
**Total Examples**: 241 across all categories  
**Lines of Code**: ~640KB+ of sample code  
**Test Cases**: 143+ test cases in network operations  
**Target Audience**: Developers integrating DICOMKit into medical imaging applications

## Quick Start

### Option 1: Copy into Your Project
Simply copy any `.swift` file into your Xcode project and uncomment the examples you want to run.

### Option 2: Use in Xcode Playground
1. Create a new Xcode Playground
2. Copy the content of any `.swift` file
3. Add DICOMKit as a dependency (requires Swift Package Manager)
4. Run the playground

### Option 3: Create Playground Workspace
```bash
# From DICOMKit root directory
cd Playgrounds
# Create an Xcode Workspace containing all playgrounds
# (Instructions in BUILD.md - coming soon)
```

## Playground Categories

### ✅ 1. Getting Started (4 playgrounds - COMPLETE)
Essential concepts for working with DICOM files using DICOMKit.

**1.1 Reading DICOM Files** (`1.1_ReadingDICOMFiles.swift`)  
- Basic file reading with `DICOMFile.read(from:)`
- Error handling patterns
- Loading multiple files
- Checking file validity
- Reading from Data vs URL
- 5 complete examples

**1.2 Accessing Metadata** (`1.2_AccessingMetadata.swift`)  
- Tag access by number and keyword
- Patient demographics (name, ID, birth date, age, sex)
- Study and series information
- Dates, times, and person names
- Numeric values and multiple values (VM > 1)
- Navigating sequences
- Iterating all tags
- 9 complete examples

**1.3 Pixel Data Access** (`1.3_PixelDataAccess.swift`)  
- Extracting pixel data from files
- Creating CGImage for iOS/macOS display
- Applying window/level transformations
- Multi-frame image handling
- Raw pixel value access
- Color vs grayscale images
- Pixel statistics and ranges
- Photometric interpretation
- 9 complete examples

**1.4 Error Handling** (`1.4_ErrorHandling.swift`)  
- DICOMError cases and handling
- Legacy file support (force mode)
- File validation
- Bulk file processing with errors
- Error recovery strategies
- User-friendly error messages
- Logging and async/await patterns
- 10 complete examples

### ✅ 2. Image Processing (4 playgrounds - COMPLETE)
Advanced image display and manipulation techniques.

**2.1 Window/Level** (`2.1_WindowLevel.swift`) ✅ COMPLETE
- Basic window/level concepts
- Common CT window presets (lung, bone, soft tissue, brain, etc.)
- Auto window/level from pixel range
- Interactive W/L adjustment
- Multiple window values
- Manual W/L calculation
- VOI LUT and Modality LUT
- MR-specific windowing
- 9 complete examples

**2.2 Image Export** (`2.2_ImageExport.swift`) ✅ COMPLETE
- Export to PNG, JPEG, TIFF
- Quality settings and compression
- Applying window/level before export
- Multi-frame export
- Batch export
- Export with metadata preservation
- Photos library integration (iOS)
- Smart format selection
- Cross-platform implementations
- 9 complete examples

**2.3 Multi-frame Series** (`2.3_MultiframeSeries.swift`) ✅ COMPLETE
- Basic multi-frame access
- Frame timing information
- Simple cine playback loop
- Frame caching for smooth playback
- Timer-based cine playback
- Frame extraction by time
- Memory-efficient frame iteration
- Frame sequence information
- Adaptive FPS calculation
- 9 complete examples

**2.4 Transfer Syntax** (`2.4_TransferSyntax.swift`) ✅ COMPLETE
- Detecting transfer syntax
- Common transfer syntaxes by modality
- Working with uncompressed pixel data
- Handling compressed pixel data
- Transfer syntax by modality
- Checking transfer syntax support
- Byte order considerations
- Encapsulated vs native pixel data
- Transfer syntax negotiation concepts
- Best practices
- 10 complete examples

### 3. Network Operations ✅ COMPLETE

PACS integration and DICOMweb protocols.

**3.1 PACS Query (C-FIND)** ✅ COMPLETE
- Patient/Study/Series/Instance level queries  
- Query filters and matching
- Wildcard support
- Date range queries
- 9 examples, 30 test cases

**3.2 PACS Retrieve (C-MOVE)** ✅ COMPLETE
- C-MOVE and C-GET requests
- Destination AE configuration
- Progress tracking
- Priority settings
- 9 examples, 27 test cases

**3.3 PACS Send (C-STORE)** ✅ COMPLETE
- Sending files to PACS
- Verification and retry
- Batch uploads
- Compression support
- 9 examples, 28 test cases

**3.4 DICOMweb (QIDO/WADO/STOW)** ✅ COMPLETE
- QIDO-RS queries
- WADO-RS retrieval (objects, metadata, rendered images)
- STOW-RS uploads
- RESTful web services
- Authentication patterns
- 9 examples, 38 test cases

**3.5 Modality Worklist** ✅ COMPLETE
- Worklist queries (C-FIND MWL)
- Scheduled procedures
- Patient demographics
- Workflow integration
- 9 examples, 20 test cases

### ✅ 4. Structured Reporting (4 playgrounds - COMPLETE)
Reading and creating DICOM Structured Reports.

**4.1 Reading SR Documents** ✅ COMPLETE
- Loading and parsing SR documents
- Navigating content tree
- Extracting text and coded values
- Finding specific observations
- Measurement extraction
- CAD findings extraction
- 9 complete examples

**4.2 Creating Basic SR** ✅ COMPLETE
- Simple radiology reports
- Nested sections
- Coded observations
- Multi-observer reports
- Image references
- Numeric measurements
- Serializing to DICOM
- 9 complete examples

**4.3 Measurement Reports** ✅ COMPLETE
- TID 1500 measurement reports
- RECIST 1.1 target lesions
- Multiple lesions with sum
- Volume measurements
- Qualitative evaluations
- Temporal comparison
- Reading and exporting measurements
- 9 complete examples

**4.4 CAD SR** ✅ COMPLETE
- Mammography CAD SR
- Chest CAD for lung nodules
- Classification results
- Reading CAD findings
- Filtering and summary reports
- Exporting to JSON
- AI model output conversion
- 9 complete examples

### ✅ 5. SwiftUI Integration (5 playgrounds - COMPLETE)
Building medical imaging UIs with SwiftUI.

**5.1 Basic Image Viewer** ✅ COMPLETE
- Display DICOM images in SwiftUI
- Window/Level controls with sliders
- Multi-frame navigation and playback
- Zoom and pan gestures
- Interactive W/L drag adjustment
- CT/MR window presets
- Metadata overlays
- 9 complete examples

**5.2 Study Browser** ✅ COMPLETE
- Study/Series list and grid views
- Thumbnail generation and caching
- Search and filter functionality
- Hierarchical navigation
- SwiftData integration
- Batch operations
- Complete browser implementation
- 9 complete examples

**5.3 Async Loading** ✅ COMPLETE
- Modern async/await patterns
- Progress tracking with Actor
- Task cancellation
- Background loading
- Concurrent loading with TaskGroup
- Error recovery with retry
- Streaming large files
- 9 complete examples

**5.4 Measurement Tools** ✅ COMPLETE
- Length measurements (ruler)
- Angle measurements (protractor)
- Rectangle and Ellipse ROI tools
- Freehand drawing
- Measurement list management
- Real-world measurements
- Coordinate conversion
- 9 complete examples

**5.5 MVVM Pattern** ✅ COMPLETE
- @Observable ViewModels (Swift 6)
- @ObservableObject patterns
- Dependency injection
- Type-safe navigation
- State management best practices
- ViewModel testing
- Complete MVVM architecture
- 9 complete examples

### ✅ 6. Advanced Topics (5 playgrounds - COMPLETE)
Specialized features and optimizations.

**6.1 3D Volume Reconstruction** ✅ COMPLETE
- Loading 3D series from slices
- Sorting slices by position
- Building 3D volumes
- MPR (axial, sagittal, coronal, oblique)
- Maximum Intensity Projection (MIP)
- Volume spacing and orientation
- Trilinear interpolation
- 9 complete examples

**6.2 Presentation States (GSPS)** ✅ COMPLETE
- Loading GSPS files
- Grayscale transformations (Modality, VOI, Presentation LUT)
- Rendering graphic annotations
- Spatial transformations
- Display shutters
- Multi-layer annotations
- Presentation state picker UI
- 9 complete examples

**6.3 RT Structure Sets** ✅ COMPLETE
- Loading RT Structure Set files
- Parsing ROI contours
- Rendering contours on images
- 3D ROI visualization
- Volume calculation
- ROI statistics
- Color management
- Contour interpolation
- 9 complete examples

**6.4 Segmentation** ✅ COMPLETE
- Loading SEG files
- Binary and fractional segmentation
- Multi-segment handling
- Segment rendering with overlays
- CIELab to RGB conversion
- Segment statistics
- Creating SEG from masks
- Visibility controls
- 9 complete examples

**6.5 Performance Optimization** ✅ COMPLETE
- Memory management for large datasets
- Lazy loading strategies
- Thumbnail generation and caching
- Parallel processing with actors
- SIMD optimizations (Accelerate)
- Profiling and benchmarking
- Streaming large files
- Batch processing optimization
- 9 complete examples

## Using the Playgrounds

### Requirements
- macOS 14.0+ (for Xcode)
- Xcode 15.0+
- DICOMKit v1.0+
- Swift 6.0+

### Basic Usage Pattern

Each playground file is self-contained and follows this structure:

```swift
import DICOMKit
import Foundation

// MARK: - Example 1: Description
func example1_description() throws {
    // Example code here
}

// MARK: - Example 2: Another Topic
func example2_anotherTopic() throws {
    // More example code
}

// ... more examples ...

// MARK: - Running the Examples
// Uncomment to run individual examples:
// try? example1_description()
// try? example2_anotherTopic()

// MARK: - Quick Reference
/*
 Comprehensive reference guide for the topic
 */
```

### Customization

1. **Update File Paths**: Replace `/path/to/your/file.dcm` with actual paths
2. **Uncomment Examples**: Choose which examples to run
3. **Add Your Code**: Build on the examples
4. **Run**: Execute in Xcode or copy into your project

### Sample DICOM Files

Sample DICOM files for testing are available from public sources:

- **DICOM Library**: http://dicomlib.swmed.net/dicomlib/
- **OsiriX Sample Data**: https://www.osirix-viewer.com/resources/dicom-image-library/
- **Medical Connections**: https://www.medicalconnections.co.uk/Free_DICOM_Images

Place sample files in `Resources/SampleDICOMFiles/` (gitignored).

## Code Style

All playground code follows these conventions:

- ✅ Clear, descriptive function names
- ✅ Comprehensive inline comments
- ✅ Error handling demonstrated
- ✅ Quick reference guide at end
- ✅ Multiple examples per topic
- ✅ Real-world usage patterns
- ✅ Swift API Design Guidelines
- ✅ Platform conditionals (`#if canImport(CoreGraphics)`)

## Contributing

Found an issue or want to add an example?

1. Create a new example following the pattern
2. Add comprehensive comments
3. Update the Quick Reference section
4. Test on both iOS and macOS (where applicable)
5. Submit a pull request

## Resources

### DICOMKit Documentation
- Main README: [../README.md](../README.md)
- API Reference: [../Documentation/](../Documentation/)
- Examples: [../Examples/](../Examples/)

### DICOM Standard
- Part 3: Information Object Definitions
- Part 5: Data Structures and Encoding
- Part 6: Data Dictionary
- Part 10: Media Storage and File Format

### SwiftUI and Apple Platforms
- SwiftUI Documentation
- Core Graphics Framework
- Swift Concurrency Guide

## Playground Statistics

| Category | Playgrounds | Examples | Lines of Code | Status |
|----------|-------------|----------|---------------|--------|
| Getting Started | 4/4 | 33 | 48.3 KB | ✅ Complete |
| Image Processing | 4/4 | 37 | 65.9 KB | ✅ Complete |
| Network Operations | 5/5 | 45 | 142.0 KB | ✅ Complete |
| Structured Reporting | 4/4 | 36 | 89.7 KB | ✅ Complete |
| SwiftUI Integration | 5/5 | 45 | 157.0 KB | ✅ Complete |
| Advanced Topics | 5/5 | 45 | 133.0 KB | ✅ Complete |
| **TOTAL** | **27/27** | **241** | **635.9 KB** | **✅ 100% Complete** |

## Changelog

### February 2026
- ✅ Created playground structure
- ✅ Completed Category 1: Getting Started (4 playgrounds, 33 examples)
- ✅ Completed Category 2: Image Processing (4 playgrounds, 37 examples)
  - ✅ 2.1 Window/Level (9 examples)
  - ✅ 2.2 Image Export (9 examples)
  - ✅ 2.3 Multi-frame Series (9 examples)
  - ✅ 2.4 Transfer Syntax (10 examples)
- ✅ Completed Category 3: Network Operations (5 playgrounds, 45 examples, 143 test cases)
  - ✅ 3.1 PACS Query/C-FIND (9 examples, 30 tests)
  - ✅ 3.2 PACS Retrieve/C-MOVE (9 examples, 27 tests)
  - ✅ 3.3 PACS Send/C-STORE (9 examples, 28 tests)
  - ✅ 3.4 DICOMweb (9 examples, 38 tests)
  - ✅ 3.5 Modality Worklist (9 examples, 20 tests)
- ✅ Completed Category 4: Structured Reporting (4 playgrounds, 36 examples)
  - ✅ 4.1 Reading SR Documents (9 examples)
  - ✅ 4.2 Creating Basic SR (9 examples)
  - ✅ 4.3 Measurement Reports (9 examples)
  - ✅ 4.4 CAD SR (9 examples)
- ✅ Completed Category 5: SwiftUI Integration (5 playgrounds, 45 examples)
  - ✅ 5.1 Basic Image Viewer (9 examples)
  - ✅ 5.2 Study Browser (9 examples)
  - ✅ 5.3 Async Loading (9 examples)
  - ✅ 5.4 Measurement Tools (9 examples)
  - ✅ 5.5 MVVM Pattern (9 examples)
- ✅ Completed Category 6: Advanced Topics (5 playgrounds, 45 examples)
  - ✅ 6.1 3D Volume Reconstruction (9 examples)
  - ✅ 6.2 Presentation States (GSPS) (9 examples)
  - ✅ 6.3 RT Structure Sets (9 examples)
  - ✅ 6.4 Segmentation (9 examples)
  - ✅ 6.5 Performance Optimization (9 examples)
- ✅ **ALL 27 PLAYGROUNDS COMPLETED** - 241 examples, ~636KB of code
- ✅ Updated this README

### Future Enhancements
- Create Xcode Playground workspace
- Add interactive UI elements
- Include sample DICOM files package
- Video tutorials for each category
- Swift Playgrounds App versions for iPad

## License

These playgrounds are part of DICOMKit and are licensed under the same terms. See [LICENSE](../LICENSE) for details.

---

**Questions or Issues?**  
Open an issue on GitHub: https://github.com/raster-image/DICOMKit/issues

**Want to Contribute?**  
See [CONTRIBUTING.md](../CONTRIBUTING.md)

---

*Last Updated: February 2026*  
*DICOMKit Version: v1.0+*  
*Platform: iOS 17+, macOS 14+*
