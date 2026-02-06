# DICOMViewer iOS - Setup Checklist

Use this checklist to track your progress setting up the DICOMViewer iOS app.

## 🚀 NEW: Automated Setup ⏱️ 1 minute

**For the fastest setup, use automation instead of the manual steps below:**

### Prerequisites
- [ ] macOS 14.0+ installed
- [ ] Xcode 15.0+ installed (`xcodebuild -version` to check)
- [ ] XcodeGen installed (`brew install xcodegen`)

### Automated Project Generation
- [ ] Navigate to DICOMViewer-iOS directory
- [ ] Run `xcodegen generate`
- [ ] Open `DICOMViewer.xcodeproj`
- [ ] Select your development team in project settings
- [ ] Press ⌘R to build and run
- [ ] App launches successfully

**✅ Checkpoint:** App builds and runs in simulator (< 1 minute!)

**For more details, see [SETUP_AUTOMATION.md](SETUP_AUTOMATION.md)**

---

## Manual Setup (Alternative)

If you prefer manual setup or don't want to install XcodeGen, follow the steps below.

## Phase 1: Initial Setup ⏱️ 5-10 minutes

### Prerequisites
- [ ] macOS 14.0+ installed
- [ ] Xcode 15.0+ installed (`xcodebuild -version` to check)
- [ ] Apple Developer account (for device testing)
- [ ] DICOMKit repository cloned locally

### Create Xcode Project
- [ ] Open Xcode
- [ ] Create new iOS App project
  - [ ] Name: DICOMViewer
  - [ ] Interface: SwiftUI
  - [ ] Storage: None (SwiftData via code)
  - [ ] Deployment Target: iOS 17.0
- [ ] Select development team in project settings
- [ ] Enable "Automatically manage signing"

### Add Dependencies
- [ ] File → Add Package Dependencies
- [ ] URL: `https://github.com/raster-image/DICOMKit.git`
- [ ] Version: 1.0.0 or later
- [ ] Add `DICOMKit` to target
- [ ] Add `DICOMCore` to target

### Add Source Files
- [ ] Delete default `ContentView.swift`
- [ ] Delete default `DICOMViewerApp.swift` (if exists)
- [ ] Drag `DICOMViewer-iOS/App/` into Xcode
- [ ] Drag `DICOMViewer-iOS/Models/` into Xcode
- [ ] Drag `DICOMViewer-iOS/Services/` into Xcode
- [ ] Drag `DICOMViewer-iOS/ViewModels/` into Xcode
- [ ] Drag `DICOMViewer-iOS/Views/` into Xcode
- [ ] **Important:** Uncheck "Copy items if needed"
- [ ] Select "Create groups"
- [ ] Add to target: DICOMViewer

### First Build
- [ ] Select simulator (e.g., iPhone 15)
- [ ] Press ⌘B to build
- [ ] Build succeeds (may take 1-2 minutes first time)
- [ ] Press ⌘R to run
- [ ] App launches successfully
- [ ] See three tabs: Library, Viewer, Settings
- [ ] Dark mode is active by default

**✅ Checkpoint:** App builds and runs in simulator

---

## Phase 2: Add Tests ⏱️ 2-3 minutes (Optional but Recommended)

### Add Test Files
- [ ] Expand test target in Project Navigator
- [ ] Right-click test target → Add Files
- [ ] Navigate to `DICOMViewer-iOS/Tests/`
- [ ] Select `MeasurementTests.swift`
- [ ] Select `PresentationStateTests.swift`
- [ ] **Important:** Uncheck "Copy items if needed"
- [ ] Add to target: [YourTestTarget]

### Run Tests
- [ ] Press ⌘U to run tests
- [ ] Wait for tests to complete
- [ ] Verify 35+ tests pass
- [ ] No test failures

**✅ Checkpoint:** All tests pass

---

## Phase 3: Configure Info.plist ⏱️ 3-5 minutes (Optional)

### Add DICOM File Support
- [ ] Open `Info.plist` in Xcode
- [ ] Add entries from `Info.plist.template`:
  - [ ] `UTImportedTypeDeclarations` for DICOM files
  - [ ] `CFBundleDocumentTypes` for opening .dcm files
  - [ ] `UISupportsDocumentBrowser` = YES
  - [ ] `UIFileSharingEnabled` = YES
  - [ ] `LSSupportsOpeningDocumentsInPlace` = YES

OR

- [ ] Copy `Info.plist.template` to project directory
- [ ] Rename to `Info.plist`
- [ ] Customize bundle identifier and other fields

### Add Photo Library Permission
- [ ] Add `NSPhotoLibraryAddUsageDescription` to Info.plist
- [ ] Value: "DICOMViewer needs permission to save exported images to your photo library."

**✅ Checkpoint:** App can open DICOM files and save to Photos

---

## Phase 4: Add Assets ⏱️ 10-30 minutes (Optional)

### Create App Icon
- [ ] Design 1024x1024 app icon
- [ ] Use icon generator (see ASSETS.md)
- [ ] Import to Assets.xcassets → AppIcon
- [ ] Add all required sizes (iPhone, iPad, App Store)

### Configure Launch Screen
- [ ] Add `LaunchScreenBackground` color to Assets.xcassets
- [ ] Set dark gray (#1C1C1E)
- [ ] Verify in Info.plist → UILaunchScreen

### Optional Custom Colors
- [ ] Add `MeasurementColor` (yellow for measurements)
- [ ] Add `PresentationStateColor` (green for GSPS)

**✅ Checkpoint:** App has custom icon and colors

---

## Phase 5: Test on Device ⏱️ 5-10 minutes

### Physical Device Testing
- [ ] Connect iPhone or iPad via USB
- [ ] Trust computer on device (if prompted)
- [ ] Select device in Xcode scheme selector
- [ ] Press ⌘R to build and run
- [ ] App installs on device
- [ ] Trust developer certificate on device:
  - [ ] Settings → General → VPN & Device Management
  - [ ] Trust your certificate

### Test Core Features
- [ ] App launches successfully
- [ ] Navigate between tabs
- [ ] Import sample DICOM file (via AirDrop or Files app)
- [ ] View image in Viewer tab
- [ ] Test pinch-to-zoom gesture
- [ ] Test window/level adjustment
- [ ] Test rotation
- [ ] Create a measurement
- [ ] View metadata

**✅ Checkpoint:** App works on physical device

---

## Phase 6: Import Test Data ⏱️ Varies

### Obtain DICOM Files
- [ ] Download sample files from:
  - [ ] [dicomlib.swmed.net](http://dicomlib.swmed.net/dicomlib/)
  - [ ] Your own medical imaging data
  - [ ] Other public DICOM datasets

### Transfer to iOS
- [ ] **Option A:** AirDrop files to device
- [ ] **Option B:** Save to iCloud Drive, access via Files app
- [ ] **Option C:** Email files to yourself, open in Mail

### Import to DICOMViewer
- [ ] Open DICOMViewer app
- [ ] Tap "+" in Library tab
- [ ] Select DICOM files from document picker
- [ ] Verify files appear in study list
- [ ] Tap study to view images

**✅ Checkpoint:** Can import and view real DICOM files

---

## Phase 7: Performance Testing ⏱️ 30-60 minutes (Optional)

### Test with Large Files
- [ ] Import file >100MB
- [ ] Measure import time (should be <3 seconds)
- [ ] Verify smooth scrolling through frames
- [ ] Check memory usage with Xcode Instruments
- [ ] Memory should stay <200MB

### Test Multi-Frame Series
- [ ] Import series with 100+ frames
- [ ] Test cine playback at 30fps
- [ ] Verify smooth playback
- [ ] Check frame counter accuracy

### Profile Performance
- [ ] Product → Profile (⌘I)
- [ ] Select "Time Profiler"
- [ ] Navigate app, view images
- [ ] Look for bottlenecks
- [ ] No single function >20% CPU time

**✅ Checkpoint:** Performance meets benchmarks

---

## Phase 8: App Store Preparation ⏱️ Several hours (Optional)

### Screenshots
- [ ] Capture 6 screenshots on iPhone 6.7" (iPhone 15 Pro Max)
- [ ] Capture 6 screenshots on iPad Pro 12.9"
- [ ] Show: Library, Viewer, Measurements, Metadata, Settings
- [ ] Use dark mode for all screenshots

### App Metadata
- [ ] Write app description (see IOS_VIEWER_PLAN.md)
- [ ] Create app preview video (30 seconds)
- [ ] Write privacy policy
- [ ] Prepare support URL
- [ ] Choose keywords

### Archive and Upload
- [ ] Select "Any iOS Device" as destination
- [ ] Product → Archive
- [ ] Validate archive
- [ ] Upload to App Store Connect
- [ ] Submit for review

**✅ Checkpoint:** Ready for App Store submission

---

## Troubleshooting Checklist

If you encounter issues, verify:

### Build Errors
- [ ] Xcode version is 15.0 or later
- [ ] Deployment target is iOS 17.0 or later
- [ ] DICOMKit package is added to target
- [ ] Both DICOMKit and DICOMCore are linked
- [ ] File → Packages → Reset Package Caches
- [ ] Clean Build Folder (⇧⌘K)

### Runtime Errors
- [ ] All source files are added to target
- [ ] SwiftData is imported (automatically with SwiftUI)
- [ ] Info.plist has required permissions
- [ ] App has been deleted and reinstalled (clears corrupt data)

### Import Issues
- [ ] Files are valid DICOM format (.dcm, .dicom, .dic)
- [ ] Info.plist has document type declarations
- [ ] File sharing is enabled in Info.plist
- [ ] Document browser is enabled

### Performance Issues
- [ ] Testing on iOS 17+ device
- [ ] Not running in debug mode for performance tests
- [ ] Background App Refresh is enabled
- [ ] Sufficient storage space available

**📖 Full Troubleshooting:** See BUILD.md "Troubleshooting" section

---

## Completion Summary

### Minimal Setup (Required)
- ✅ Xcode project created
- ✅ Source files added
- ✅ DICOMKit dependency linked
- ✅ App builds and runs

**Time:** ~10 minutes  
**Result:** Working iOS app

### Complete Setup (Recommended)
- ✅ Tests added and passing
- ✅ Info.plist configured
- ✅ App icon created
- ✅ Device testing complete
- ✅ Sample data imported

**Time:** ~1 hour  
**Result:** Production-ready app

### App Store Ready (Optional)
- ✅ Screenshots captured
- ✅ Metadata written
- ✅ Performance tested
- ✅ Ready for submission

**Time:** Several hours  
**Result:** App Store submission ready

---

## Resources

- **Quick Start:** [QUICK_START.md](QUICK_START.md)
- **Detailed Build:** [BUILD.md](BUILD.md)
- **Asset Guide:** [ASSETS.md](ASSETS.md)
- **Status Report:** [STATUS.md](STATUS.md)
- **Test Docs:** [Tests/README.md](Tests/README.md)

---

## Support

If you get stuck:
1. Check [BUILD.md](BUILD.md) Troubleshooting section
2. Search GitHub Issues
3. Open new issue with error details

---

**Last Updated:** February 2026  
**DICOMKit Version:** v1.0+  
**iOS Version:** 17.0+
