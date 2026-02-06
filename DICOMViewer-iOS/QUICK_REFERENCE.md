# DICOMViewer iOS - Quick Reference Card

## 🚀 Three Ways to Get Started

### Method 1: Automated (Recommended) ⏱️ 1 min
```bash
brew install xcodegen
cd DICOMViewer-iOS
xcodegen generate
open DICOMViewer.xcodeproj
```
**Then in Xcode:** Select team → Press ⌘R

### Method 2: Setup Script ⏱️ 2 min
```bash
cd DICOMViewer-iOS
./create-xcode-project.sh DICOMViewer com.yourcompany
cd ~/Desktop/DICOMViewer-Workspace
open Package.swift
```
**Then in Xcode:** Press ⌘R

### Method 3: Manual ⏱️ 10 min
1. Create iOS App in Xcode
2. Add DICOMKit package dependency
3. Drag source folders into project
4. Build and run

**See:** [QUICK_START.md](QUICK_START.md) | [BUILD.md](BUILD.md) | [SETUP_AUTOMATION.md](SETUP_AUTOMATION.md)

---

## 📱 Key Features

| Feature | Description |
|---------|-------------|
| **File Import** | Files app, iCloud, email, AirDrop |
| **Viewing** | Multi-frame, pinch-zoom, gestures |
| **Display** | Window/level, presets, rotation |
| **GSPS** | Presentation states, annotations |
| **Measurements** | Length, angle, ROI statistics |
| **Export** | PNG/JPEG, Photos app, share |
| **Metadata** | Full tag viewer with search |

---

## 🛠️ Common Commands

### Building
```bash
⌘B  # Build
⌘R  # Build and run
⌘U  # Run tests
⇧⌘K # Clean build folder
```

### Testing
```bash
# Run all tests
⌘U

# Expected result
✓ 35+ tests pass
```

### Troubleshooting
```bash
# Reset package caches
File → Packages → Reset Package Caches

# Clean and rebuild
⇧⌘K then ⌘B

# Check Swift version
swift --version  # Should be 5.9+

# Check Xcode version
xcodebuild -version  # Should be 15.0+
```

---

## 📊 Project Stats

- **Source Files:** 21 Swift files
- **Lines of Code:** ~3,500 lines
- **Test Files:** 2 files, 35+ tests
- **Minimum iOS:** 17.0+
- **Architecture:** MVVM + SwiftUI
- **Dependencies:** DICOMKit, DICOMCore

---

## 📂 Project Structure

```
DICOMViewer-iOS/
├── App/                  # Entry point (2 files)
├── Models/               # Data models (4 files)
├── Services/             # Business logic (4 files)
├── ViewModels/           # State management (2 files)
├── Views/                # UI components (9 files)
│   ├── Library/          # Study browser
│   ├── Viewer/           # Image viewer
│   ├── Metadata/         # Tag viewer
│   └── Settings/         # Preferences
├── Tests/                # Unit tests (2 files)
├── project.yml           # XcodeGen config
└── *.md                  # Documentation
```

---

## 🎯 Quick Test

After building:

1. **Import test file:**
   - Drag DICOM file onto simulator
   - Tap in Files app
   - Share to DICOMViewer

2. **Verify features:**
   - ✓ File appears in Library
   - ✓ Tap to view image
   - ✓ Pinch to zoom works
   - ✓ Window/level adjusts
   - ✓ Measurements can be drawn

---

## 📚 Documentation

| Guide | Purpose | Time |
|-------|---------|------|
| [SETUP_AUTOMATION.md](SETUP_AUTOMATION.md) | Automated setup | 1 min |
| [QUICK_START.md](QUICK_START.md) | Fast manual setup | 5 min |
| [BUILD.md](BUILD.md) | Detailed instructions | Reference |
| [CHECKLIST.md](CHECKLIST.md) | Step-by-step checklist | Guide |
| [README.md](README.md) | Feature overview | Reference |
| [STATUS.md](STATUS.md) | Implementation status | Info |
| [ASSETS.md](ASSETS.md) | Icon creation | Optional |

---

## 🔧 Customization

### Change Bundle ID
**XcodeGen:** Edit `project.yml` line 7:
```yaml
bundleIdPrefix: com.yourcompany
```
Then: `xcodegen generate`

**Xcode:** Project Settings → General → Bundle Identifier

### Add App Icon
1. Create 1024×1024 icon
2. Add to Assets.xcassets → AppIcon
3. See [ASSETS.md](ASSETS.md) for details

### Configure Signing
1. Project Settings → Signing & Capabilities
2. Select your team
3. Enable "Automatically manage signing"

---

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't find DICOMKit | File → Packages → Resolve |
| Build errors | Clean build (⇧⌘K) then rebuild |
| Red files in Xcode | Re-add without "Copy items" |
| Signing issues | Select team in project settings |
| Tests fail | Check DICOMKit version (1.0+) |

---

## 🎓 Learning Resources

- **DICOMKit Docs:** [../README.md](../README.md)
- **Apple SwiftUI:** https://developer.apple.com/swiftui
- **Apple SwiftData:** https://developer.apple.com/swiftdata
- **DICOM Standard:** https://www.dicomstandard.org

---

## ✨ What's Next?

After setup:
1. ✅ Test with sample DICOM files
2. 📱 Deploy to physical device
3. 🎨 Add custom app icon
4. 🔍 Explore measurement tools
5. 📤 Try export features
6. 🎭 Test GSPS support

---

**Version:** v1.0  
**Updated:** February 2026  
**Platform:** iOS 17.0+
