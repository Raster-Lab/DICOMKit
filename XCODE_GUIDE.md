# Building and Testing DICOMKit with Xcode

This guide explains how to open, build, and test DICOMKit using Xcode on macOS.

## Prerequisites

Before you begin, ensure you have:

- **macOS 14.0 (Sonoma) or later**
- **Xcode 16.0 or later** (required for Swift 6.2 support)
- **Apple Silicon Mac** (M1, M2, M3, M4, or later) or Intel Mac with x86_64 processor

To verify your Xcode version, open Xcode and go to **Xcode → About Xcode**, or run:

```bash
xcodebuild -version
```

## Opening the Project in Xcode

DICOMKit uses Swift Package Manager (SPM), which Xcode supports natively.

### Option 1: Open Package Directly

1. Clone the repository:
   ```bash
   git clone https://github.com/raster-image/DICOMKit.git
   cd DICOMKit
   ```

2. Open the package in Xcode:
   ```bash
   open Package.swift
   ```
   
   Or double-click `Package.swift` in Finder.

3. Xcode will automatically:
   - Parse the `Package.swift` manifest
   - Resolve any dependencies
   - Index all source files

### Option 2: Open from Xcode

1. Launch Xcode
2. Select **File → Open...** (or press ⌘O)
3. Navigate to the DICOMKit directory
4. Select `Package.swift` and click **Open**

## Building the Project

### Build All Targets

To build all libraries in the package:

1. Select the **DICOMKit** scheme from the scheme selector (top-left of Xcode window)
2. Select your target device/simulator:
   - **My Mac** for macOS
   - Any iOS Simulator for iOS
   - Any visionOS Simulator for visionOS
3. Build using one of these methods:
   - Press ⌘B
   - Select **Product → Build**
   - Click the Play button (▶) to build and run (if applicable)

### Build Individual Modules

DICOMKit consists of multiple modules. To build a specific module:

1. Click on the scheme selector
2. Choose the desired scheme:
   - **DICOMCore** - Core data types and utilities
   - **DICOMDictionary** - DICOM dictionary data
   - **DICOMNetwork** - Network protocol implementation
   - **DICOMKit** - Full library (includes all modules)
3. Press ⌘B to build

### Build from Command Line

You can also build using Terminal:

```bash
# Build for macOS
xcodebuild -scheme DICOMKit -destination 'platform=macOS'

# Build for iOS Simulator
xcodebuild -scheme DICOMKit -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for visionOS Simulator  
xcodebuild -scheme DICOMKit -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Build using Swift Package Manager
swift build
```

## Running Tests

DICOMKit includes comprehensive test suites for all modules.

### Run All Tests in Xcode

1. Select the **DICOMKit** scheme (or any specific test scheme)
2. Run tests using one of these methods:
   - Press ⌘U
   - Select **Product → Test**
   - Open the Test Navigator (⌘6) and click the play button next to a test suite

### Run Specific Test Suites

DICOMKit has four test targets:

| Test Target | Description |
|-------------|-------------|
| DICOMCoreTests | Tests for core data types (Tag, VR, DataElement, etc.) |
| DICOMDictionaryTests | Tests for dictionary lookup functionality |
| DICOMKitTests | Tests for high-level API (DICOMFile, DataSet, etc.) |
| DICOMNetworkTests | Tests for network protocol implementation |

To run a specific test suite:

1. Open the Test Navigator (⌘6)
2. Expand the test target you want to run
3. Click the play button (▶) next to the test class or individual test

### Run Tests from Command Line

```bash
# Run all tests using Swift Package Manager
swift test

# Run all tests using xcodebuild
xcodebuild test -scheme DICOMKit -destination 'platform=macOS'

# Run a specific test target
swift test --filter DICOMCoreTests

# Run tests with verbose output
swift test --verbose
```

### View Test Results

After running tests:

1. Open the Report Navigator (⌘9)
2. Select the most recent test run
3. Review passed/failed tests and any error messages

## Test Navigator Features

Xcode's Test Navigator provides useful features:

- **Filter Tests**: Use the search field to find specific tests
- **Re-run Failed Tests**: Right-click and select "Run Again"
- **Jump to Test**: Double-click a test to open its source file
- **Test Coverage**: Enable code coverage in scheme settings to see test coverage

### Enabling Code Coverage

1. Click the scheme selector → **Edit Scheme...** (or press ⌘<)
2. Select **Test** in the left sidebar
3. Go to the **Options** tab
4. Check **Code Coverage** → **Gather coverage for some targets**
5. Add the targets you want coverage for
6. Run tests (⌘U)
7. View coverage in the Report Navigator

## Troubleshooting

### Common Issues and Solutions

#### "The compiler is unable to type-check this expression"

This can occur with complex Swift code. Try:
- Clean the build folder: **Product → Clean Build Folder** (⇧⌘K)
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Restart Xcode

#### "No such module 'DICOMKit'"

Ensure you're building for a supported platform:
- iOS 17.0+
- macOS 14.0+
- visionOS 1.0+

Check the scheme's destination selector matches a supported platform.

#### Build fails with Swift version errors

Verify you have Xcode 16.0 or later installed. DICOMKit requires Swift 6.2:

```bash
swift --version
# Should show Swift version 6.2 or later
```

#### Tests fail to run on iOS Simulator

1. Ensure you have iOS 17+ simulators installed
2. Open **Xcode → Settings → Platforms**
3. Download iOS 17 or later simulator runtime if needed

#### Package resolution fails

Try resetting package caches:
1. **File → Packages → Reset Package Caches**
2. Or from command line: `swift package reset`

### Cleaning the Project

If you encounter persistent issues:

1. Clean Build Folder: **Product → Clean Build Folder** (⇧⌘K)
2. Reset Package Caches: **File → Packages → Reset Package Caches**
3. Delete Derived Data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/DICOMKit-*
   ```
4. Close and reopen Xcode

## Adding DICOMKit to Your Xcode Project

### Using Swift Package Manager (Recommended)

1. Open your project in Xcode
2. Select your project in the Project Navigator
3. Select your project (not a target) in the editor
4. Go to the **Package Dependencies** tab
5. Click the **+** button
6. Enter the repository URL:
   ```
   https://github.com/raster-image/DICOMKit.git
   ```
7. Set the version rule (e.g., "Up to Next Major Version" from `0.7.0`)
8. Click **Add Package**
9. Select the libraries you need:
   - **DICOMKit** - Full functionality (recommended)
   - **DICOMCore** - Core types only
   - **DICOMDictionary** - Dictionary data only
   - **DICOMNetwork** - Network features only
10. Click **Add Package**

### Import in Your Code

```swift
import DICOMKit

// Now you can use DICOMKit APIs
let data = try Data(contentsOf: dicomFileURL)
let dicomFile = try DICOMFile.read(from: data)
```

## Development Workflow

### Recommended Xcode Settings

For the best development experience:

1. **Enable strict concurrency checking**:
   - Already configured in Package.swift
   - Shows concurrency warnings/errors during development

2. **Enable all warnings**:
   - Build Settings → Swift Compiler - Warnings → Treat Warnings as Errors: Yes

3. **Use SwiftLint** (optional):
   - Install via Homebrew: `brew install swiftlint`
   - Add a build phase to run SwiftLint

### Running on Device

To test on physical devices:

1. Connect your iOS device or Apple Vision Pro
2. Select your device in the scheme destination
3. Ensure your Apple Developer account is configured in Xcode
4. Build and run (⌘R)

Note: For development signing, you can use your personal team in **Signing & Capabilities**.

## Additional Resources

- [README.md](README.md) - Project overview and API documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [MILESTONES.md](MILESTONES.md) - Development roadmap
- [Apple's Swift Package Manager Documentation](https://developer.apple.com/documentation/xcode/swift-packages)
- [DICOM Standard](https://www.dicomstandard.org/)

## Support

If you encounter issues not covered in this guide:

1. Check existing [GitHub Issues](https://github.com/raster-image/DICOMKit/issues)
2. Open a new issue with:
   - Xcode version
   - macOS version
   - Swift version (`swift --version`)
   - Complete error message
   - Steps to reproduce
