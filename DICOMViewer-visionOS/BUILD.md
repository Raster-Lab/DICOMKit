# DICOMViewer visionOS - Build Instructions

## Prerequisites

### Required Software

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.2 or later
- **visionOS SDK**: 1.0 or later (included with Xcode)
- **XcodeGen**: 2.38.0+ (optional, for regenerating project)

### Installing XcodeGen

```bash
# Using Homebrew
brew install xcodegen

# Or using Mint
mint install yonaskolb/XcodeGen
```

---

## Build Steps

### 1. Generate Xcode Project

The project uses XcodeGen for project generation. This ensures consistency and makes project configuration manageable.

```bash
cd DICOMViewer-visionOS

# Generate Xcode project
./create-xcode-project.sh

# This will:
# - Run xcodegen using project.yml
# - Create DICOMViewer.xcodeproj
# - Set up dependencies and build settings
```

### 2. Open Project

```bash
open DICOMViewer.xcodeproj
```

Or double-click `DICOMViewer.xcodeproj` in Finder.

### 3. Configure Signing

1. Select the DICOMViewer target
2. Go to Signing & Capabilities tab
3. Select your development team
4. Xcode will automatically provision the app

### 4. Select Destination

**For Simulator**:
- Product > Destination > Apple Vision Pro (Designed for visionOS)

**For Device**:
- Connect Vision Pro via USB-C or WiFi
- Product > Destination > [Your Vision Pro Device]
- Ensure device is in Developer Mode

### 5. Build

```bash
# Command line
xcodebuild -project DICOMViewer.xcodeproj -scheme DICOMViewer -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Or in Xcode
# Product > Build (⌘B)
```

### 6. Run

```bash
# Command line
xcodebuild -project DICOMViewer.xcodeproj -scheme DICOMViewer -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build run

# Or in Xcode
# Product > Run (⌘R)
```

---

## Build Configurations

### Debug

- Optimizations: None
- Debug symbols: Included
- Assertions: Enabled
- Suitable for development and testing

### Release

- Optimizations: Aggressive (-O)
- Debug symbols: dSYM only
- Assertions: Disabled
- Suitable for TestFlight and App Store

---

## Testing

### Run All Tests

```bash
# Command line
swift test

# Or in Xcode
# Product > Test (⌘U)
```

### Run Specific Test Suite

```bash
swift test --filter DICOMViewer_visionOSTests.VolumeViewModelTests
```

### Test Coverage

```bash
swift test --enable-code-coverage

# View coverage report in Xcode:
# View > Navigators > Report Navigator
# Select test run
# Click Coverage tab
```

---

## Dependencies

### DICOMKit

The app depends on the DICOMKit Swift package.

**Local Development**:
```swift
// In project.yml, dependencies point to local DICOMKit
dependencies:
  - package: DICOMKit
    path: ../
```

**Released Version**:
```swift
// For App Store builds, use released version
dependencies:
  - package: DICOMKit
    url: https://github.com/GITHUB_USERNAME/DICOMKit.git
    version: 1.0.0
```

### System Frameworks

- SwiftUI
- RealityKit
- ARKit
- Metal
- MetalKit
- GroupActivities
- AVFoundation

---

## Build Settings

### Key Settings (from project.yml)

```yaml
PRODUCT_NAME: DICOMViewer
PRODUCT_BUNDLE_IDENTIFIER: com.dicomkit.viewer.visionos
MARKETING_VERSION: 1.0.14
CURRENT_PROJECT_VERSION: 1

SWIFT_VERSION: 6.0
IPHONEOS_DEPLOYMENT_TARGET: 1.0  # visionOS 1.0

ENABLE_PREVIEWS: true
DEVELOPMENT_ASSET_PATHS: ""

# Performance
SWIFT_OPTIMIZATION_LEVEL: -Onone  # Debug
SWIFT_OPTIMIZATION_LEVEL: -O      # Release

# Code Coverage
CLANG_ENABLE_CODE_COVERAGE: true
```

---

## Troubleshooting

### "No such module 'DICOMKit'"

**Solution**: Ensure DICOMKit is built first.

```bash
cd ..  # Go to repository root
swift build
cd DICOMViewer-visionOS
./create-xcode-project.sh
```

### "Signing requires a development team"

**Solution**: Select your team in Signing & Capabilities.

1. Open project settings
2. Select DICOMViewer target
3. Go to Signing & Capabilities
4. Select your Apple Developer team

### "visionOS SDK not found"

**Solution**: Update Xcode.

```bash
# Check Xcode version
xcodebuild -version

# Should show Xcode 15.2 or later
# If not, download latest from:
# https://developer.apple.com/download/
```

### Build Errors After Git Pull

**Solution**: Regenerate project.

```bash
./create-xcode-project.sh
```

XcodeGen regenerates the project from project.yml, resolving most configuration issues.

---

## Performance Profiling

### Instruments

```bash
# Profile in Xcode
# Product > Profile (⌘I)

# Select instrument:
# - Time Profiler: CPU performance
# - Allocations: Memory usage
# - Metal System Trace: GPU performance
# - Thermal State: Device thermal
```

### Metal Debugger

1. Run app in Xcode
2. Click capture frame button (camera icon)
3. Inspect Metal commands and GPU performance

---

## Deployment

### Archive for TestFlight

```bash
# In Xcode
# Product > Archive

# Or command line
xcodebuild -project DICOMViewer.xcodeproj \
  -scheme DICOMViewer \
  -destination generic/platform=visionOS \
  -configuration Release \
  archive \
  -archivePath ./build/DICOMViewer.xcarchive
```

### Upload to App Store Connect

1. Window > Organizer
2. Select archive
3. Click "Distribute App"
4. Follow prompts to upload

---

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build visionOS App

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v3
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app
      
      - name: Build DICOMKit
        run: swift build
      
      - name: Build visionOS App
        run: |
          cd DICOMViewer-visionOS
          xcodebuild -project DICOMViewer.xcodeproj \
            -scheme DICOMViewer \
            -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
            build
      
      - name: Run Tests
        run: swift test
```

---

## Xcode Cloud

### Setup

1. Go to App Store Connect
2. Select your app
3. Enable Xcode Cloud
4. Configure workflow:
   - Trigger: On Git push
   - Environment: macOS 14, Xcode 15.2
   - Build scheme: DICOMViewer
   - Test scheme: DICOMViewer

---

## Advanced Build Options

### Custom Build Scripts

Add pre/post build scripts in Xcode:
1. Target > Build Phases
2. Add "Run Script" phase
3. Enter script (e.g., code generation, asset processing)

### Build Time Optimization

```bash
# Enable parallel builds
defaults write com.apple.dt.Xcode BuildSystemScheduleInherentlyParallelCommandsExclusively -bool NO

# Show build times
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES
```

### Custom Compiler Flags

In project.yml:

```yaml
OTHER_SWIFT_FLAGS:
  - "-Xfrontend"
  - "-warn-long-function-bodies=100"
  - "-Xfrontend"
  - "-warn-long-expression-type-checking=100"
```

---

## Clean Build

```bash
# Clean build folder
# Product > Clean Build Folder (⌘⇧K)

# Or command line
xcodebuild clean -project DICOMViewer.xcodeproj -scheme DICOMViewer

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/DICOMViewer-*
```

---

## Support

For build issues:
1. Check this document
2. Ensure all prerequisites are met
3. Try regenerating project: `./create-xcode-project.sh`
4. Clean and rebuild
5. File an issue on GitHub if problem persists

---

_Last updated: 2024 - For DICOMKit v1.0.14_
