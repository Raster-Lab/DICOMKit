# Building DICOMViewer macOS

This guide explains how to build and run DICOMViewer macOS.

## Prerequisites

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **XcodeGen**: (optional) For generating Xcode project from `project.yml`

## Method 1: Using XcodeGen (Recommended)

XcodeGen generates the Xcode project from `project.yml`, making it easier to manage project structure.

### Install XcodeGen

```bash
brew install xcodegen
```

### Generate and Build

```bash
cd DICOMViewer-macOS

# Generate Xcode project
xcodegen

# Open project
open DICOMViewer.xcodeproj

# Or build from command line
xcodebuild -project DICOMViewer.xcodeproj -scheme DICOMViewer -configuration Debug
```

## Method 2: Manual Xcode Project Setup

If you prefer not to use XcodeGen, you can create an Xcode project manually:

### 1. Create New Project

1. Open Xcode
2. File → New → Project
3. Select **macOS** → **App**
4. Set the following:
   - Product Name: **DICOMViewer**
   - Bundle Identifier: **com.rasterlab.dicomviewer.macos**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**
   - Deployment Target: **macOS 14.0**

### 2. Add DICOMKit Dependency

1. In Xcode, select the project in the navigator
2. Select the **DICOMViewer** target
3. Go to **General** tab → **Frameworks, Libraries, and Embedded Content**
4. Click **+** button
5. Choose **Add Package Dependency...**
6. Enter the path to DICOMKit: `file://../` (local package)
7. Select the following products:
   - DICOMKit
   - DICOMCore
   - DICOMNetwork

### 3. Add Source Files

1. Delete the default `ContentView.swift` and `DICOMViewerApp.swift` if present
2. Drag all directories from this folder into the Xcode project:
   - `App/`
   - `Models/`
   - `ViewModels/`
   - `Views/`
   - `Services/`
3. Ensure "Copy items if needed" is **unchecked**
4. Select "Create groups" (not folder references)
5. Add to the **DICOMViewer** target

### 4. Configure Info.plist

1. Replace the generated `Info.plist` with the one from this directory
2. Or manually add the DICOM file type associations

### 5. Build and Run

1. Select **DICOMViewer** scheme
2. Press **⌘R** to build and run
3. Or use **Product** → **Build** (⌘B)

## Running Tests

### Using Xcode

1. Select **DICOMViewerTests** scheme
2. Press **⌘U** to run all tests
3. Or use **Product** → **Test**

### Using Command Line

```bash
# Run all tests
xcodebuild test \
  -project DICOMViewer.xcodeproj \
  -scheme DICOMViewerTests \
  -destination 'platform=macOS'

# Or with swift test (if using SPM structure)
swift test
```

## Project Structure

```
DICOMViewer-macOS/
├── App/
│   └── DICOMViewerApp.swift          # Application entry point
├── Models/
│   ├── DicomStudy.swift              # Study data model
│   ├── DicomSeries.swift             # Series data model
│   └── DicomInstance.swift           # Instance data model
├── ViewModels/
│   ├── StudyBrowserViewModel.swift   # Study browser logic
│   └── ImageViewerViewModel.swift    # Image viewer logic
├── Views/
│   ├── StudyBrowserView.swift        # Main study browser UI
│   ├── SeriesListView.swift          # Series list UI
│   └── ImageViewerView.swift         # Image viewer UI
├── Services/
│   ├── DatabaseService.swift         # SwiftData database service
│   └── FileImportService.swift       # File import service
├── Tests/
│   └── (test files)
├── Info.plist                        # App configuration
├── project.yml                       # XcodeGen configuration
└── BUILD.md                          # This file
```

## Build Configuration

### Debug Build

For development with debug symbols and no optimization:

```bash
xcodebuild -configuration Debug
```

### Release Build

For production with optimizations:

```bash
xcodebuild -configuration Release
```

### Code Signing

For distribution, you'll need to configure code signing:

1. In Xcode, select the project
2. Select the **DICOMViewer** target
3. Go to **Signing & Capabilities**
4. Enable **Automatically manage signing**
5. Select your development team

## Troubleshooting

### Cannot find module 'DICOMKit'

Make sure DICOMKit is properly linked:

1. Check that the package reference points to the correct path (`../`)
2. Try cleaning the build: **Product** → **Clean Build Folder** (⌘⇧K)
3. Restart Xcode

### SwiftData errors

Ensure deployment target is set to macOS 14.0+:

1. Select the project
2. Go to **Build Settings**
3. Search for "deployment target"
4. Set **macOS Deployment Target** to **14.0**

### Build fails with "Missing required module"

1. Ensure all DICOMKit products are added as dependencies
2. Clean the build folder
3. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
4. Rebuild

### App crashes on launch

Check that:

1. All required frameworks are embedded
2. Info.plist is properly configured
3. Bundle identifier matches the code signing certificate

## Development Tips

### Live Previews

SwiftUI previews should work for individual views:

```swift
#Preview {
    StudyBrowserView()
}
```

### Debugging

- Enable breakpoints in Xcode
- Use `print()` statements for debugging
- Check Console for log messages
- Use Instruments for performance profiling

### Hot Reload

Xcode supports SwiftUI hot reload:

1. Make changes to a View
2. Press **⌘S** to save
3. Preview updates automatically (if enabled)

## Performance

### Build Times

- Initial build: ~30 seconds (depends on system)
- Incremental builds: ~5-10 seconds
- Clean build: ~45 seconds

### Optimization

For faster development builds:

1. Use Debug configuration
2. Enable "Build Active Architecture Only" in Build Settings
3. Disable optimizations in Debug configuration

## Distribution

### Creating an Archive

```bash
xcodebuild archive \
  -project DICOMViewer.xcodeproj \
  -scheme DICOMViewer \
  -archivePath ./build/DICOMViewer.xcarchive
```

### Exporting for Distribution

1. In Xcode: **Product** → **Archive**
2. Select the archive in Organizer
3. Click **Distribute App**
4. Choose distribution method:
   - Development
   - Ad Hoc
   - Mac App Store
   - Developer ID

## Next Steps

After successful build:

1. Import some DICOM files to test
2. Explore the study browser
3. View images in the viewer
4. Run the test suite
5. Review the code for Phase 2 features (PACS integration)

## Support

For issues:

- Check [Troubleshooting](#troubleshooting) section
- Review DICOMKit documentation
- Open an issue on GitHub
- Check Xcode console for errors

---

**Note**: This is Phase 1 (Foundation). PACS integration features are disabled and will be implemented in Phase 2.
