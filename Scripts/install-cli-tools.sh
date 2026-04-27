#!/bin/bash
# DICOMKit CLI Tools Installation Script
# This script builds and installs all CLI tools locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}DICOMKit CLI Tools Installer${NC}"
echo "=================================="
echo ""

# Resolve and switch to the Swift package root (parent of Scripts/) so that
# `.build/release/` is found regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$PACKAGE_ROOT/Package.swift" ]; then
    echo -e "${RED}Error: Package.swift not found at $PACKAGE_ROOT${NC}"
    echo "This script must live in <package-root>/Scripts/install-cli-tools.sh."
    exit 1
fi

cd "$PACKAGE_ROOT"
echo -e "${GREEN}Package root:${NC} $PACKAGE_ROOT"

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: Swift is not installed${NC}"
    echo "Please install Xcode or Swift toolchain from https://swift.org/download/"
    exit 1
fi

# Check Swift version
SWIFT_VERSION=$(swift --version | head -n 1)
echo -e "${GREEN}Found Swift:${NC} $SWIFT_VERSION"

# Get installation directory (default: /usr/local/bin)
INSTALL_DIR="${1:-/usr/local/bin}"

if [ ! -w "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR is not writable${NC}"
    echo "You may need to run this script with sudo or choose a different directory."
    echo "Usage: ./install-cli-tools.sh [install-directory]"
    echo "Example: ./install-cli-tools.sh ~/.local/bin"
    exit 1
fi

echo -e "${GREEN}Installation directory:${NC} $INSTALL_DIR"
echo ""

# Build CLI tools
echo "Building CLI tools (this may take a few minutes)..."
if ! swift build -c release --disable-sandbox; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

if [ ! -d ".build/release" ]; then
    echo -e "${RED}Error: .build/release directory was not produced.${NC}"
    echo "Please run 'swift build -c release' manually from $PACKAGE_ROOT to diagnose."
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo ""

# List of all CLI tools
CLI_TOOLS=(
    "dicom-info"
    "dicom-convert"
    "dicom-validate"
    "dicom-anon"
    "dicom-dump"
    "dicom-query"
    "dicom-send"
    "dicom-diff"
    "dicom-retrieve"
    "dicom-split"
    "dicom-merge"
    "dicom-json"
    "dicom-xml"
    "dicom-pdf"
    "dicom-image"
    "dicom-dcmdir"
    "dicom-archive"
    "dicom-export"
    "dicom-qr"
    "dicom-wado"
    "dicom-echo"
    "dicom-mwl"
    "dicom-mpps"
    "dicom-pixedit"
    "dicom-tags"
    "dicom-uid"
    "dicom-compress"
    "dicom-study"
    "dicom-script"
    "dicom-gateway"
    "dicom-jpip"
)

# Install tools
echo "Installing ${#CLI_TOOLS[@]} CLI tools to $INSTALL_DIR..."
INSTALLED_COUNT=0

for tool in "${CLI_TOOLS[@]}"; do
    if [ -f ".build/release/$tool" ]; then
        cp ".build/release/$tool" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$tool"
        echo -e "  ${GREEN}✓${NC} $tool"
        ((INSTALLED_COUNT++))
    else
        echo -e "  ${YELLOW}⚠${NC} $tool not found"
    fi
done

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo "Installed $INSTALLED_COUNT tools to $INSTALL_DIR"
echo ""
echo "To verify installation, try:"
echo "  dicom-info --version"
echo "  dicom-convert --help"
echo ""
echo "For documentation, see:"
echo "  https://github.com/Raster-Lab/DICOMKit"
