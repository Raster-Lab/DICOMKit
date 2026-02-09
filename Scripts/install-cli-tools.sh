#!/bin/bash
# DICOMKit CLI Tools Installation Script
# This script builds and installs all 29 CLI tools locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}DICOMKit CLI Tools Installer${NC}"
echo "=================================="
echo ""

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
swift build -c release --disable-sandbox

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
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
