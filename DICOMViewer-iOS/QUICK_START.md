# DICOMViewer iOS - Xcode Project Quick Setup

This is a quick-start guide for creating an Xcode project for DICOMViewer iOS. For detailed instructions, see [BUILD.md](BUILD.md).

## Prerequisites

- Xcode 15.0 or later
- macOS 14.0 (Sonoma) or later
- Apple Developer account (for device testing)

## 🚀 Fastest Setup - Automated (NEW!)

**Want to skip manual steps? Use automation:**

```bash
# Install XcodeGen (one-time)
brew install xcodegen

# Generate project (1 command!)
cd DICOMViewer-iOS
xcodegen generate
open DICOMViewer.xcodeproj
```

That's it! See [SETUP_AUTOMATION.md](SETUP_AUTOMATION.md) for details.

**OR continue with manual setup below:**

## Step-by-Step Setup (5 minutes)

### 1. Create New Project

```
Xcode → File → New → Project
- Choose: iOS → App
- Product Name: DICOMViewer
- Team: [Your Team]
- Organization Identifier: com.yourorg
- Interface: SwiftUI
- Language: Swift
- Storage: None (we'll use SwiftData via code)
- Click Next → Create
```

### 2. Configure Project Settings

In Project Navigator, select the project (blue icon):

**General Tab:**
- Deployment Info → iOS 17.0
- Supports → iPhone, iPad

**Signing & Capabilities:**
- ✅ Automatically manage signing
- Team: [Select your team]
- Optional: Add "iCloud" capability for cloud storage

### 3. Add DICOMKit Package

```
File → Add Package Dependencies...
- Search: https://github.com/raster-image/DICOMKit.git
- Dependency Rule: "Up to Next Major Version" 1.0.0
- Add to Target: DICOMViewer
- Add Package

When prompted, add both:
✅ DICOMKit
✅ DICOMCore
```

### 4. Add Source Files

In Finder:
```bash
# Navigate to the cloned DICOMKit repository
cd /path/to/DICOMKit/DICOMViewer-iOS
```

In Xcode Project Navigator:
1. **Delete** the default files:
   - `ContentView.swift` (right-click → Delete → Move to Trash)
   - `DICOMViewerApp.swift` (if it exists, right-click → Delete → Move to Trash)

2. **Add** the iOS Viewer folders:
   - Drag `App/` folder into Xcode project
   - Drag `Models/` folder into Xcode project
   - Drag `Services/` folder into Xcode project
   - Drag `ViewModels/` folder into Xcode project
   - Drag `Views/` folder into Xcode project

3. **Configure import options:**
   - ❌ **UNCHECK** "Copy items if needed" (keep files in original location)
   - ✅ **CHECK** "Create groups"
   - ✅ **CHECK** "Add to targets: DICOMViewer"
   - Click **Finish**

### 5. Add Test Files (Optional)

1. In Project Navigator, select the test target (e.g., `DICOMViewerTests`)
2. Right-click → Add Files to "DICOMViewerTests"...
3. Navigate to `DICOMKit/DICOMViewer-iOS/Tests/`
4. Select:
   - `MeasurementTests.swift`
   - `PresentationStateTests.swift`
5. Configure:
   - ❌ **UNCHECK** "Copy items if needed"
   - ✅ **CHECK** "Create groups"
   - ✅ **CHECK** "Add to targets: DICOMViewerTests"
6. Click **Add**

### 6. Configure Info.plist (Optional but Recommended)

To support opening DICOM files:

1. In Project Navigator, select `Info.plist`
2. Add these entries manually or copy from `Info.plist.template`:

**Required entries:**
- Document Types → Add DICOM support
- UTImportedTypeDeclarations → org.nema.dicom
- NSPhotoLibraryAddUsageDescription → "Save exported images"

OR:

```bash
# Copy the template (then edit in Xcode)
cp /path/to/DICOMKit/DICOMViewer-iOS/Info.plist.template /path/to/YourXcodeProject/DICOMViewer/Info.plist
```

### 7. Build and Run

```
1. Select target: "DICOMViewer" (top-left scheme selector)
2. Select destination: Any iOS 17+ simulator or device
3. Press ⌘R (or click the Play ▶ button)
```

**First build may take 1-2 minutes** as DICOMKit and dependencies compile.

### 8. Verify Installation

If successful, you should see:
- App launches with dark interface
- Three tabs: Library, Viewer, Settings
- "No studies" message in Library tab

## Project Structure in Xcode

Your project should look like this:

```
DICOMViewer
├── App/
│   ├── DICOMViewerApp.swift
│   └── ContentView.swift
├── Models/
│   ├── DICOMStudy.swift
│   ├── DICOMSeries.swift
│   ├── DICOMInstance.swift
│   └── Measurement.swift
├── Services/
│   ├── DICOMFileService.swift
│   ├── ImageRenderingService.swift
│   ├── ThumbnailService.swift
│   └── PresentationStateService.swift
├── ViewModels/
│   ├── LibraryViewModel.swift
│   └── ViewerViewModel.swift
├── Views/
│   ├── Library/
│   │   └── LibraryView.swift
│   ├── Viewer/
│   │   ├── ViewerContainerView.swift
│   │   ├── SeriesPickerView.swift
│   │   ├── PresentationStateOverlayView.swift
│   │   └── PresentationStatePickerView.swift
│   ├── Metadata/
│   │   └── MetadataView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Assets.xcassets
├── Info.plist
└── DICOMViewerTests/
    ├── MeasurementTests.swift
    └── PresentationStateTests.swift
```

## Quick Test

### Test Import (Simulator):

1. Download a sample DICOM file:
   - [Sample DICOM files](http://dicomlib.swmed.net/dicomlib/)
   - Save as `test.dcm`

2. Drag `test.dcm` onto the simulator

3. In simulator: Files app → Downloads → `test.dcm`

4. Tap file → Share → DICOMViewer

5. File should appear in Library tab

### Run Tests:

```
⌘U (or Product → Test)
```

Expected: 35+ tests pass (15+ measurement tests, 20+ presentation state tests)

## Common Issues

### "Cannot find 'DICOMKit' in scope"

**Fix:**
1. File → Packages → Reset Package Caches
2. Clean Build Folder (⇧⌘K)
3. Build (⌘B)

### "No such module 'DICOMCore'"

**Fix:**
1. Project Settings → General → Frameworks, Libraries, and Embedded Content
2. Add both `DICOMKit` and `DICOMCore`

### "Build Failed" with Swift version error

**Fix:**
- Ensure Xcode 15.0 or later
- Ensure iOS deployment target is 17.0 or later

### Files show in red (cannot find)

**Fix:**
- You checked "Copy items if needed" - files are now in wrong location
- Delete references and re-add without copying

## Next Steps

1. ✅ **Read the full guide:** [BUILD.md](BUILD.md)
2. 📖 **Review architecture:** See [README.md](README.md) "Project Structure"
3. 🏗️ **Understand implementation:** See [IOS_VIEWER_PLAN.md](../IOS_VIEWER_PLAN.md)
4. 🧪 **Add sample data:** Import DICOM files for testing
5. 📱 **Test on device:** Connect iPhone/iPad and run
6. 🚀 **Customize:** Add app icon, adjust colors, modify features

## Resources

- **Build Guide:** [BUILD.md](BUILD.md) - Detailed build instructions
- **README:** [README.md](README.md) - Feature overview
- **Implementation Plan:** [IOS_VIEWER_PLAN.md](../IOS_VIEWER_PLAN.md) - Full feature roadmap
- **DICOMKit Docs:** [../README.md](../README.md) - Library documentation
- **Apple Docs:** [SwiftUI](https://developer.apple.com/documentation/swiftui), [SwiftData](https://developer.apple.com/documentation/swiftdata)

## Support

If you encounter issues:
1. Check [BUILD.md](BUILD.md) Troubleshooting section
2. Search existing [GitHub Issues](https://github.com/raster-image/DICOMKit/issues)
3. Open a new issue with:
   - Xcode version (`xcodebuild -version`)
   - macOS version
   - Error messages (full text)
   - Steps to reproduce

---

**Estimated setup time:** 5-10 minutes  
**First build time:** 1-2 minutes (DICOMKit compilation)  
**Total lines of code:** ~3,500 lines of Swift
