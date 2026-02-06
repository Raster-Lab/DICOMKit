# DICOMViewer iOS - Project Setup Automation

This directory contains tools to help you quickly set up an Xcode project for DICOMViewer iOS.

## Quick Start

### Method 1: Using XcodeGen (Recommended)

**Prerequisites:**
```bash
brew install xcodegen
```

**Steps:**
1. Navigate to this directory:
   ```bash
   cd DICOMViewer-iOS
   ```

2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

3. Open the generated project:
   ```bash
   open DICOMViewer.xcodeproj
   ```

4. In Xcode:
   - Select your development team in project settings
   - Select a simulator or device
   - Press ⌘R to build and run

**Advantages:**
- ✅ One command setup
- ✅ Consistent project configuration
- ✅ Easy to regenerate if corrupted
- ✅ No manual Xcode configuration needed

### Method 2: Using Setup Script

**Steps:**
1. Run the setup script:
   ```bash
   ./create-xcode-project.sh DICOMViewer com.yourcompany
   ```

2. Follow the on-screen instructions

3. Open the generated workspace:
   ```bash
   cd ~/Desktop/DICOMViewer-Workspace
   open Package.swift
   ```

**Advantages:**
- ✅ No external dependencies
- ✅ Creates workspace with symbolic links
- ✅ Includes Package.swift for SPM integration

### Method 3: Manual Setup

Follow the detailed instructions in [QUICK_START.md](QUICK_START.md) or [BUILD.md](BUILD.md).

## Customization

### Changing Bundle Identifier

**XcodeGen method:**
Edit `project.yml` and change:
```yaml
options:
  bundleIdPrefix: com.yourcompany  # Change this line
```

Then regenerate:
```bash
xcodegen generate
```

**Script method:**
```bash
./create-xcode-project.sh DICOMViewer com.yourcompany
```

### Adding Your Development Team

**XcodeGen method:**
Edit `project.yml` and set:
```yaml
DEVELOPMENT_TEAM: "YOUR_TEAM_ID"  # Replace with your 10-character team ID
```

Find your team ID:
- Open Xcode → Settings → Accounts
- Select your account
- Click "Manage Certificates"
- Your team ID is shown below the team name

**Xcode method:**
- Open project settings
- Select your target
- Go to "Signing & Capabilities"
- Select your team from the dropdown

## Files in This Directory

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen configuration for generating Xcode project |
| `create-xcode-project.sh` | Shell script for automated project creation |
| `Info.plist.template` | Template for app configuration |
| `SETUP_AUTOMATION.md` | This file - automation guide |
| `QUICK_START.md` | Quick manual setup guide |
| `BUILD.md` | Detailed build instructions |
| `CHECKLIST.md` | Setup checklist |

## Troubleshooting

### XcodeGen not found
```bash
brew install xcodegen
```

### "Command not found" for create-xcode-project.sh
```bash
chmod +x create-xcode-project.sh
./create-xcode-project.sh
```

### Build errors after generation
1. Clean build folder: ⇧⌘K
2. Reset package caches: File → Packages → Reset Package Caches
3. Restart Xcode

### DICOMKit package not found
1. Ensure you have internet connection
2. File → Packages → Resolve Package Versions
3. Check that Package.swift or project.yml has correct repository URL

### Signing errors
1. Select your development team in project settings
2. Enable "Automatically manage signing"
3. Ensure you have a valid Apple Developer account

## Support

For more help:
- See [BUILD.md](BUILD.md) for detailed troubleshooting
- Check [QUICK_START.md](QUICK_START.md) for manual setup
- Open an issue on GitHub with your error details

## What's Next?

After project setup:
1. ✅ **Build and run** (⌘R)
2. 📖 **Read** [README.md](README.md) for feature overview
3. 🧪 **Run tests** (⌘U) - should see 35+ passing tests
4. 📱 **Import DICOM files** to test the app
5. 🎨 **Customize** app icon and colors (see [ASSETS.md](ASSETS.md))

---

**Last Updated:** February 2026  
**DICOMKit Version:** v1.0+  
**iOS Version:** 17.0+
