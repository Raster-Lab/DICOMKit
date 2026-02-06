#!/bin/bash
#
# DICOMViewer iOS - Xcode Project Creator
# Automated setup script for creating an Xcode project
#
# Usage: ./create-xcode-project.sh [project-name] [bundle-id-prefix]
#
# Example:
#   ./create-xcode-project.sh DICOMViewer com.mycompany
#
# This will create a project named "DICOMViewer.xcodeproj" with bundle ID "com.mycompany.DICOMViewer"

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PROJECT_NAME="${1:-DICOMViewer}"
BUNDLE_ID_PREFIX="${2:-com.example}"
BUNDLE_ID="${BUNDLE_ID_PREFIX}.${PROJECT_NAME}"

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   DICOMViewer iOS - Xcode Project Creator         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Project Name: ${PROJECT_NAME}"
echo "Bundle ID: ${BUNDLE_ID}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DICOMKIT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: swift not found. Please install Xcode Command Line Tools.${NC}"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
echo -e "${GREEN}✓ Xcode ${XCODE_VERSION} found${NC}"

# Check if project already exists
WORK_DIR="${HOME}/Desktop/${PROJECT_NAME}-Workspace"
if [ -d "$WORK_DIR" ]; then
    echo -e "${YELLOW}Warning: Workspace directory already exists: ${WORK_DIR}${NC}"
    read -p "Delete and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$WORK_DIR"
    else
        echo "Aborted."
        exit 1
    fi
fi

# Create workspace directory
echo -e "${YELLOW}Creating workspace directory...${NC}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Use swift package init to bootstrap the project
echo -e "${YELLOW}Creating Swift package structure...${NC}"
swift package init --type executable --name "$PROJECT_NAME" > /dev/null 2>&1 || true

# Remove package-generated files
rm -rf Sources Tests Package.swift

# Create proper iOS app structure
mkdir -p "${PROJECT_NAME}"
mkdir -p "${PROJECT_NAME}Tests"

# Create Package.swift for iOS app
cat > Package.swift << EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "${PROJECT_NAME}",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "${PROJECT_NAME}",
            targets: ["${PROJECT_NAME}"])
    ],
    dependencies: [
        .package(url: "https://github.com/raster-image/DICOMKit.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "${PROJECT_NAME}",
            dependencies: [
                .product(name: "DICOMKit", package: "DICOMKit"),
                .product(name: "DICOMCore", package: "DICOMKit")
            ],
            path: "${PROJECT_NAME}"),
        .testTarget(
            name: "${PROJECT_NAME}Tests",
            dependencies: ["${PROJECT_NAME}"],
            path: "${PROJECT_NAME}Tests")
    ]
)
EOF

# Create symbolic links to source files
echo -e "${YELLOW}Creating symbolic links to source files...${NC}"
cd "${PROJECT_NAME}"

ln -s "${SCRIPT_DIR}/App" App
ln -s "${SCRIPT_DIR}/Models" Models
ln -s "${SCRIPT_DIR}/Services" Services
ln -s "${SCRIPT_DIR}/ViewModels" ViewModels
ln -s "${SCRIPT_DIR}/Views" Views

cd "${WORK_DIR}"

# Create symbolic links to test files
echo -e "${YELLOW}Linking test files...${NC}"
cd "${PROJECT_NAME}Tests"
ln -s "${SCRIPT_DIR}/Tests/MeasurementTests.swift" MeasurementTests.swift
ln -s "${SCRIPT_DIR}/Tests/PresentationStateTests.swift" PresentationStateTests.swift
cd "${WORK_DIR}"

# Create Info.plist based on template
echo -e "${YELLOW}Creating Info.plist...${NC}"
if [ -f "${SCRIPT_DIR}/Info.plist.template" ]; then
    cp "${SCRIPT_DIR}/Info.plist.template" "${PROJECT_NAME}/Info.plist"
    # Update bundle identifier in plist
    if command -v plutil &> /dev/null; then
        plutil -replace CFBundleIdentifier -string "${BUNDLE_ID}" "${PROJECT_NAME}/Info.plist" 2>/dev/null || true
    fi
fi

# Generate Xcode project using swift package generate-xcodeproj (if available)
echo -e "${YELLOW}Generating Xcode project...${NC}"

# Try to generate Xcode project
if swift package generate-xcodeproj 2>/dev/null; then
    echo -e "${GREEN}✓ Xcode project generated: ${PROJECT_NAME}.xcodeproj${NC}"
else
    echo -e "${YELLOW}Note: 'swift package generate-xcodeproj' is deprecated.${NC}"
    echo -e "${YELLOW}Please open Package.swift in Xcode to generate the project.${NC}"
fi

# Print instructions
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Project Setup Complete! 🎉                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Workspace Location:${NC} ${WORK_DIR}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Open the project in Xcode:"
echo "   cd ${WORK_DIR}"
echo "   open Package.swift"
echo ""
echo "2. When Xcode opens, it will automatically:"
echo "   - Resolve DICOMKit package dependencies"
echo "   - Index source files"
echo "   - Configure build settings"
echo ""
echo "3. Build and run:"
echo "   - Select an iOS simulator from the scheme selector"
echo "   - Press ⌘R to build and run"
echo ""
echo -e "${YELLOW}Additional Configuration:${NC}"
echo "• Configure signing: Select your development team in project settings"
echo "• Add app icon: Create Assets.xcassets and add AppIcon"
echo "• Customize Info.plist: Edit ${PROJECT_NAME}/Info.plist as needed"
echo ""
echo -e "${YELLOW}Testing:${NC}"
echo "• Run tests: Press ⌘U"
echo "• Expected: 35+ tests should pass"
echo ""
echo -e "${GREEN}For more information, see:${NC}"
echo "• BUILD.md - Detailed build instructions"
echo "• QUICK_START.md - Quick start guide"
echo "• README.md - Feature overview"
echo ""
