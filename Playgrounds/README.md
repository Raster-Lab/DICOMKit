# DICOMKit Playgrounds

Comprehensive sample code and examples demonstrating DICOMKit usage across all features.

## Overview

This collection contains 27+ interactive Swift playground files organized into 6 categories, covering everything from basic file reading to advanced medical imaging workflows. Each playground is a standalone Swift file with multiple examples, comprehensive comments, and quick reference guides.

**Status**: In Progress (Categories 1-3 complete, 48%)  
**Total Examples**: 115+ across completed categories  
**Lines of Code**: 256KB+ of sample code  
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

### 📝 4. Structured Reporting (4 playgrounds - PLANNED)
Reading and creating DICOM Structured Reports.

**4.1 Reading SR Documents** (PLANNED)
- Parsing SR content tree
- Extracting measurements
- Finding observations

**4.2 Creating Basic SR** (PLANNED)
- Building content trees
- Adding observations
- Document structure

**4.3 Measurement Reports** (PLANNED)
- TID 1500 measurement reports
- Tracking measurements
- Imaging measurements

**4.4 CAD SR** (PLANNED)
- Computer-Aided Detection reports
- Findings and annotations
- CAD algorithm results

### 🎨 5. SwiftUI Integration (5 playgrounds - PLANNED)
Building medical imaging UIs with SwiftUI.

**5.1 Basic Image Viewer** (PLANNED)
- SwiftUI image display
- Gestures (zoom, pan)
- Window/level controls

**5.2 Study Browser** (PLANNED)
- List and grid views
- Thumbnails
- Search and filter

**5.3 Async Loading** (PLANNED)
- Swift Concurrency patterns
- Background loading
- Progress indicators

**5.4 Measurement Tools** (PLANNED)
- Drawing measurements
- Calculating lengths/angles
- ROI statistics

**5.5 MVVM Pattern** (PLANNED)
- ViewModels for DICOM data
- Observable objects
- State management

### 🔬 6. Advanced Topics (5 playgrounds - PLANNED)
Specialized features and optimizations.

**6.1 3D Volume Reconstruction** (PLANNED)
- Loading 3D series
- MPR (multiplanar reconstruction)
- Volume rendering concepts

**6.2 Presentation States (GSPS)** (PLANNED)
- Loading GSPS files
- Applying transformations
- Rendering annotations

**6.3 RT Structure Sets** (PLANNED)
- Reading RT Structure Set files
- ROI contours
- Visualization

**6.4 Segmentation** (PLANNED)
- SEG IOD parsing
- Binary and fractional segmentation
- Overlay rendering

**6.5 Performance Optimization** (PLANNED)
- Memory management
- Lazy loading
- Thumbnail generation
- Parallel processing

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
| Structured Reporting | 0/4 | 0 | 0 KB | 📋 Planned |
| SwiftUI Integration | 0/5 | 0 | 0 KB | 📋 Planned |
| Advanced Topics | 0/5 | 0 | 0 KB | 📋 Planned |
| **TOTAL** | **13/27** | **115** | **256.2 KB** | **48% Complete** |

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
- 📝 Updated this README

### Planned
- Add Category 4: Structured Reporting (4 playgrounds)
- Add Category 5: SwiftUI Integration (5 playgrounds)
- Add Category 6: Advanced Topics (5 playgrounds)
- Create Xcode Playground workspace
- Add interactive elements
- Include sample DICOM files
- Add tests for example code

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
