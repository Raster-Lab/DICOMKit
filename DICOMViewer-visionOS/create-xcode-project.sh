#!/bin/bash

# create-xcode-project.sh
# Generates Xcode project for DICOMViewer visionOS using XcodeGen

set -e  # Exit on error

echo "🛠️  Generating Xcode project for DICOMViewer visionOS..."

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ Error: xcodegen is not installed"
    echo ""
    echo "Install with Homebrew:"
    echo "  brew install xcodegen"
    echo ""
    echo "Or with Mint:"
    echo "  mint install yonaskolb/XcodeGen"
    exit 1
fi

# Check if project.yml exists
if [ ! -f "project.yml" ]; then
    echo "❌ Error: project.yml not found"
    echo "Make sure you're in the DICOMViewer-visionOS directory"
    exit 1
fi

# Generate project
echo "📦 Running xcodegen..."
xcodegen generate

# Check if project was created
if [ ! -d "DICOMViewer.xcodeproj" ]; then
    echo "❌ Error: Failed to generate Xcode project"
    exit 1
fi

echo "✅ Xcode project generated successfully!"
echo ""
echo "📖 Next steps:"
echo "  1. Open the project: open DICOMViewer.xcodeproj"
echo "  2. Select a destination (Vision Pro simulator or device)"
echo "  3. Build and run (⌘R)"
echo ""
echo "📚 Documentation:"
echo "  - README.md: Architecture and overview"
echo "  - BUILD.md: Detailed build instructions"
echo "  - USER_GUIDE.md: End-user documentation"
echo "  - STATUS.md: Implementation status"
echo ""
