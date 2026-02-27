# DICOMKit Installation Guide

This guide provides detailed instructions for installing DICOMKit and its CLI tools on macOS.

## Table of Contents

- [Requirements](#requirements)
- [Installation Methods](#installation-methods)
  - [Option 1: Homebrew (Recommended)](#option-1-homebrew-recommended)
  - [Option 2: Local Build Script](#option-2-local-build-script)
  - [Option 3: Manual Build](#option-3-manual-build)
  - [Option 4: Swift Package Manager](#option-4-swift-package-manager)
- [Verification](#verification)
- [Uninstallation](#uninstallation)

---

## Requirements

- **macOS**: macOS 15.0 (Sequoia) or later
- **Xcode**: Xcode 16.0 or later (includes Swift 6+)
- **Swift**: Swift 6.0 or later

To check your Swift version:
```bash
swift --version
```

---

## Installation Methods

### Option 1: Homebrew (Recommended)

The easiest way to install DICOMKit CLI tools is via Homebrew using the local formula.

#### Installing from Local Formula

```bash
# Clone the repository
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit

# Install using local formula (builds from source)
brew install --build-from-source Formula/dicomkit.rb
```

This will install all 35 CLI tools:
- Phase 1: `dicom-info`, `dicom-convert`, `dicom-validate`, `dicom-anon`, `dicom-dump`, `dicom-query`, `dicom-send`
- Phase 2: `dicom-diff`, `dicom-retrieve`, `dicom-split`, `dicom-merge`
- Phase 3: `dicom-json`, `dicom-xml`, `dicom-pdf`, `dicom-image`
- Phase 4: `dicom-dcmdir`, `dicom-archive`, `dicom-export`
- Phase 5: `dicom-qr`, `dicom-wado`, `dicom-echo`, `dicom-mwl`, `dicom-mpps`
- Phase 6: `dicom-pixedit`, `dicom-tags`, `dicom-uid`, `dicom-compress`, `dicom-study`, `dicom-script`
- Phase 7: `dicom-report`, `dicom-measure`, `dicom-viewer`, `dicom-cloud`, `dicom-3d`, `dicom-ai`

#### Installing from a Homebrew Tap (Optional)

If you have a dedicated Homebrew tap repository set up (see [HOMEBREW_TAP_SETUP.md](Documentation/HOMEBREW_TAP_SETUP.md)):

```bash
# Add the DICOMKit tap (requires homebrew-dicomkit repository to exist)
brew tap Raster-Lab/dicomkit

# Install DICOMKit CLI tools
brew install dicomkit
```

> **Note**: The `brew tap` command requires a separate repository named `homebrew-dicomkit` to be created at `https://github.com/Raster-Lab/homebrew-dicomkit`. See the setup guide for details.

---

### Option 2: Local Build Script

The included installation script builds and installs the CLI tools to a directory of your choice.

#### Install to /usr/local/bin (Default)

```bash
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit
sudo ./Scripts/install-cli-tools.sh
```

#### Install to Custom Directory

```bash
# Install to ~/.local/bin (user directory, no sudo needed)
./Scripts/install-cli-tools.sh ~/.local/bin

# Make sure ~/.local/bin is in your PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

### Option 3: Manual Build

For full control over the build process:

```bash
# Clone the repository
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit

# Build in release mode
swift build -c release

# Copy executables to a directory in your PATH
cp .build/release/dicom-* /usr/local/bin/
```

---

### Option 4: Swift Package Manager

To use DICOMKit as a library in your Swift project, add it as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/DICOMKit.git", from: "1.0.0")
]
```

Then import the modules you need:

```swift
import DICOMKit      // High-level API
import DICOMCore     // Core parsing
import DICOMNetwork  // PACS networking
import DICOMWeb      // DICOMweb services
```

---

## Verification

After installation, verify that the tools are correctly installed:

```bash
# Check version
dicom-info --version

# View help
dicom-convert --help

# List all installed tools
ls -1 /usr/local/bin/dicom-* | xargs -n 1 basename
```

Expected output (35 tools):
```
dicom-3d
dicom-ai
dicom-anon
dicom-archive
dicom-cloud
dicom-compress
dicom-convert
dicom-dcmdir
dicom-diff
dicom-dump
dicom-echo
dicom-export
dicom-image
dicom-info
dicom-json
dicom-measure
dicom-merge
dicom-mpps
dicom-mwl
dicom-pdf
dicom-pixedit
dicom-qr
dicom-query
dicom-report
dicom-retrieve
dicom-script
dicom-send
dicom-split
dicom-study
dicom-tags
dicom-uid
dicom-validate
dicom-viewer
dicom-wado
dicom-xml
```

---

## Uninstallation

### Homebrew Installation

```bash
brew uninstall dicomkit
brew untap Raster-Lab/dicomkit
```

### Script or Manual Installation

```bash
# Remove all CLI tools
sudo rm /usr/local/bin/dicom-*

# Or for custom installation directory
rm ~/.local/bin/dicom-*
```

---

## Troubleshooting

### "command not found: dicom-info"

Make sure the installation directory is in your PATH:

```bash
echo $PATH
```

If `/usr/local/bin` or your custom directory is not listed, add it:

```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### "Permission denied"

If you get permission errors during installation:

```bash
# For /usr/local/bin
sudo ./Scripts/install-cli-tools.sh

# Or install to a user directory instead
./Scripts/install-cli-tools.sh ~/.local/bin
```

### Build Errors

Ensure you have the latest Xcode and Swift:

```bash
xcode-select --install
swift --version
```

Update Xcode from the App Store if needed.

---

## Platform Support

- **iOS**: 17.0+
- **macOS**: 14.0+ (Sonoma)
- **visionOS**: 1.0+

CLI tools are currently macOS-only. The DICOMKit framework supports all Apple platforms.

---

## Next Steps

- Read the [README.md](README.md) for an overview of features
- Check the [Documentation](Documentation/) for API guides
- Explore [Examples](Examples/) for usage examples
- View [CLI_TOOLS_PLAN.md](CLI_TOOLS_PLAN.md) for CLI tool details

---

**Questions or Issues?**

- GitHub Issues: https://github.com/Raster-Lab/DICOMKit/issues
- Documentation: https://github.com/Raster-Lab/DICOMKit/tree/main/Documentation
