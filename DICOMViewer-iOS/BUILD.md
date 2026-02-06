# Building DICOMViewer iOS

This guide explains how to build and run the DICOMViewer iOS application.

## Prerequisites

- **macOS 14.0 (Sonoma) or later**
- **Xcode 15.0 or later**
- **iOS 17.0+ device or simulator**
- **DICOMKit 1.0+** (included in parent repository)

## 🚀 Automated Setup (NEW!)

**For the fastest setup, use our automation tools:**

See [SETUP_AUTOMATION.md](SETUP_AUTOMATION.md) for one-command project generation using:
- **XcodeGen** (recommended - `brew install xcodegen` then `xcodegen generate`)
- **Setup Script** (`./create-xcode-project.sh`)

Otherwise, continue with the manual setup below.

## Quick Start

### Option 1: Create Xcode Project (Recommended)

1. **Open Xcode** and create a new iOS App project
2. **Configure the project:**
   - Product Name: `DICOMViewer`
   - Team: Select your development team
   - Organization Identifier: `com.yourorg` (or your preference)
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: `SwiftData` (will be configured via code)
   - Deployment Target: `iOS 17.0`

3. **Add DICOMKit dependency:**
   - In Xcode, select **File → Add Package Dependencies...**
   - Enter the repository URL: `https://github.com/raster-image/DICOMKit.git`
   - Select version `1.0.0` or later
   - Add both `DICOMKit` and `DICOMCore` to your target

4. **Add source files to project:**
   - Delete the default `ContentView.swift` and `DICOMViewerApp.swift` files
   - In Finder, navigate to `DICOMKit/DICOMViewer-iOS/`
   - Drag and drop these folders into your Xcode project:
     - `App/`
     - `Models/`
     - `Services/`
     - `ViewModels/`
     - `Views/`
   - Choose "Create groups" when prompted
   - Ensure "Copy items if needed" is **unchecked** (to keep files in original location)
   - Select your app target

5. **Add Test files (optional):**
   - Right-click on your test target in Project Navigator
   - Select "Add Files to [YourTestTarget]..."
   - Navigate to `DICOMKit/DICOMViewer-iOS/Tests/`
   - Add `MeasurementTests.swift` and `PresentationStateTests.swift`

6. **Configure capabilities:**
   - Select your project in Project Navigator
   - Select your app target
   - Go to **Signing & Capabilities** tab
   - Ensure **Automatically manage signing** is enabled
   - Select your development team
   - (Optional) Add **iCloud** capability if you want cloud storage support

7. **Build and run:**
   - Select a simulator or connected device from the scheme selector
   - Press `⌘R` or click the Run button
   - The app should compile and launch

### Option 2: Use Symbolic Links (Advanced)

If you're actively developing and want changes to sync:

1. Create a new iOS App project as described above
2. Delete the project's source folders
3. Create symbolic links to the DICOMViewer-iOS source:
   ```bash
   cd /path/to/YourXcodeProject/YourXcodeProject
   ln -s /path/to/DICOMKit/DICOMViewer-iOS/App App
   ln -s /path/to/DICOMKit/DICOMViewer-iOS/Models Models
   ln -s /path/to/DICOMKit/DICOMViewer-iOS/Services Services
   ln -s /path/to/DICOMKit/DICOMViewer-iOS/ViewModels ViewModels
   ln -s /path/to/DICOMKit/DICOMViewer-iOS/Views Views
   ```
4. Add these symlinked folders to your Xcode project
5. Add DICOMKit package dependency as described above

## Project Structure

Once added to Xcode, your project should have this structure:

```
DICOMViewer/
├── App/
│   ├── DICOMViewerApp.swift          # App entry point with SwiftData
│   └── ContentView.swift             # Tab navigation
├── Models/
│   ├── DICOMStudy.swift              # SwiftData study model
│   ├── DICOMSeries.swift             # SwiftData series model
│   ├── DICOMInstance.swift           # SwiftData instance model
│   └── Measurement.swift             # Measurement data models
├── Services/
│   ├── DICOMFileService.swift        # File I/O operations
│   ├── ImageRenderingService.swift   # Image rendering
│   ├── ThumbnailService.swift        # Thumbnail generation
│   └── PresentationStateService.swift # GSPS support
├── ViewModels/
│   ├── LibraryViewModel.swift        # Study library state
│   └── ViewerViewModel.swift         # Image viewer state
└── Views/
    ├── Library/
    │   └── LibraryView.swift          # Study browser UI
    ├── Viewer/
    │   ├── ViewerContainerView.swift  # Main viewer UI
    │   ├── SeriesPickerView.swift     # Series selection
    │   ├── PresentationStateOverlayView.swift  # GSPS rendering
    │   └── PresentationStatePickerView.swift   # GSPS selection
    ├── Metadata/
    │   └── MetadataView.swift         # DICOM tag viewer
    └── Settings/
        └── SettingsView.swift          # App settings
```

## Building for Different Targets

### iOS Simulator

1. Select any iOS simulator from the scheme selector (e.g., iPhone 15 Pro)
2. Press `⌘R` to build and run
3. The app will launch in the simulator

### Physical iOS Device

1. Connect your iPhone or iPad via USB
2. Ensure the device is trusted (you may need to unlock it)
3. Select your device from the scheme selector
4. Press `⌘R` to build and run
5. If prompted, trust the developer certificate on your device:
   - On device: Settings → General → VPN & Device Management
   - Trust your developer certificate

### iPadOS

The app works on iPad without modification. Follow the same steps as iOS but select an iPad simulator or device.

## Troubleshooting

### Build Errors

**"Cannot find 'DICOMKit' in scope"**
- Ensure you've added the DICOMKit package dependency
- Try **File → Packages → Reset Package Caches**
- Clean build folder: `⇧⌘K` (Shift+Command+K)

**"Module 'DICOMCore' not found"**
- Add both `DICOMKit` and `DICOMCore` to your target's frameworks
- In Project Settings → General → Frameworks, Libraries, and Embedded Content

**"Ambiguous use of 'DICOMStudy'"**
- Ensure you're importing SwiftData, not CoreData
- Check that deployment target is iOS 17.0 or later

### Runtime Errors

**"Failed to initialize SwiftData"**
- This is expected on first run; SwiftData creates the database
- If it persists, try deleting and reinstalling the app

**"App crashes on launch"**
- Check Console.app for detailed error messages
- Verify all source files are added to the target
- Ensure Info.plist permissions are set (if accessing files)

### Performance Issues

**Slow thumbnail generation**
- Expected on first import; thumbnails are cached
- For large files (>100MB), generation may take 1-2 seconds
- Background thread generation prevents UI blocking

**High memory usage**
- DICOMViewer loads pixel data on-demand
- For very large series (500+ frames), memory may spike temporarily
- Close and reopen the app to free memory

## Testing

### Unit Tests

The project includes unit tests for measurements and presentation states:

1. Select the test target in the scheme selector
2. Press `⌘U` to run all tests
3. Or use **Product → Test** from the menu

Tests are located in `Tests/`:
- `MeasurementTests.swift` - 15+ tests for measurement calculations
- `PresentationStateTests.swift` - 20+ tests for GSPS parsing

### Manual Testing

#### Test File Import

1. Prepare DICOM test files on your Mac
2. Transfer to iOS:
   - **Option A**: AirDrop files to simulator/device
   - **Option B**: Add to iCloud Drive, access via Files app
   - **Option C**: Email files to yourself, open attachment
3. In DICOMViewer, tap **+** in Library tab
4. Select DICOM files from document picker
5. Verify files appear in study list

#### Test Image Viewing

1. Tap a study in the Library
2. Image should display in Viewer tab
3. Test gestures:
   - **Pinch** to zoom in/out
   - **Drag** to pan when zoomed
   - **Double-tap** to toggle fit/zoom
   - **Two-finger drag** to adjust window/level (brightness/contrast)

#### Test Measurements

1. Open an image in the Viewer
2. Tap the measurement button (ruler icon)
3. Select a measurement type (Length, Angle, etc.)
4. Touch to place points on the image
5. Verify measurement value displays correctly

#### Test Presentation States (GSPS)

1. Import a DICOM study with associated GSPS files
2. If GSPS detected, a presentation state indicator appears
3. Tap the GSPS button to see available states
4. Select a state and verify:
   - Annotations render correctly
   - Window/level applies
   - Shutters mask the image correctly

## Sample DICOM Files

For testing, you can use:

- **Public datasets**: [dicomlib.swmed.net](http://dicomlib.swmed.net/dicomlib/)
- **Sample files**: Create your own with tools like [dcmtk](https://dicom.offis.de/dcmtk)
- **DICOMKit test files**: Located in `DICOMKit/Tests/Resources/` (if available)

## App Store Distribution

When ready to distribute:

1. **Configure signing:**
   - Create an App Store distribution certificate
   - Create a provisioning profile
   - Configure in Xcode signing settings

2. **Prepare metadata:**
   - App icon (1024x1024 PNG)
   - Screenshots (see DEMO_APPLICATION_PLAN.md)
   - Privacy policy
   - App description

3. **Archive and upload:**
   - Select **Product → Archive**
   - Use Organizer to validate and upload to App Store Connect
   - Submit for review

See `IOS_VIEWER_PLAN.md` for detailed App Store submission guidelines.

## Development Workflow

### Making Changes

1. Edit source files in `DICOMKit/DICOMViewer-iOS/`
2. Changes are immediately reflected in Xcode (if using symlinks or direct references)
3. Build and test: `⌘B` then `⌘U`
4. Commit changes to Git

### Adding New Features

1. Follow the existing MVVM architecture
2. Add models in `Models/`
3. Add view models in `ViewModels/`
4. Add views in appropriate subdirectory of `Views/`
5. Add services in `Services/` if needed
6. Write tests in `Tests/`

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI for all views
- Use `@Observable` for view models (Swift 5.9+)
- Use `actor` for services with shared state
- Document public APIs with `///` comments
- Use `// MARK: -` to organize code sections

## Additional Resources

- **DICOMKit Documentation**: See main `README.md` in repository root
- **iOS Viewer Plan**: See `IOS_VIEWER_PLAN.md` for detailed feature roadmap
- **DICOM Standard**: [dicom.nema.org](https://www.dicomstandard.org/)
- **SwiftUI Tutorials**: [developer.apple.com/tutorials/swiftui](https://developer.apple.com/tutorials/swiftui)
- **SwiftData Guide**: [developer.apple.com/documentation/swiftdata](https://developer.apple.com/documentation/swiftdata)

## Support

For issues or questions:
- Open an issue on GitHub: [DICOMKit Issues](https://github.com/raster-image/DICOMKit/issues)
- Check existing documentation in the repository
- Review the iOS Viewer Plan for design decisions

## License

DICOMViewer iOS is part of DICOMKit and licensed under the MIT License.
See `LICENSE` file in the repository root for details.
