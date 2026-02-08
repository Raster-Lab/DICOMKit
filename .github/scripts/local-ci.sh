#!/bin/bash
# Local CI validation script
# Runs the same checks as the CI pipeline locally before pushing

set -e  # Exit on error

echo "🔍 DICOMKit Local CI Checks"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
section() {
    echo ""
    echo "▶ $1"
    echo "---"
}

# Function to print success
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print error
error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check Swift version
section "Checking Swift Version"
swift --version
SWIFT_VERSION=$(swift --version | head -n 1)
if [[ $SWIFT_VERSION == *"Swift version 6.2"* ]] || [[ $SWIFT_VERSION == *"Swift version 6.0"* ]]; then
    success "Swift 6+ detected"
else
    warning "Expected Swift 6.2, but found: $SWIFT_VERSION"
fi

# Validate Package.swift
section "Validating Package.swift"
if swift package dump-package > /dev/null 2>&1; then
    success "Package.swift is valid"
else
    error "Package.swift validation failed"
    exit 1
fi

# Check for uncommitted changes
section "Checking Git Status"
if [ -n "$(git status --porcelain)" ]; then
    warning "Uncommitted changes detected"
    git status --short
else
    success "Working directory clean"
fi

# Build the project
section "Building Project (Debug)"
if swift build; then
    success "Debug build succeeded"
else
    error "Debug build failed"
    exit 1
fi

# Build in release mode
section "Building Project (Release)"
if swift build -c release; then
    success "Release build succeeded"
else
    error "Release build failed"
    exit 1
fi

# Check for compiler warnings
section "Checking for Compiler Warnings"
BUILD_OUTPUT=$(swift build 2>&1)
if echo "$BUILD_OUTPUT" | grep -i "warning:" > /dev/null; then
    warning "Compiler warnings detected:"
    echo "$BUILD_OUTPUT" | grep -i "warning:"
else
    success "No compiler warnings"
fi

# Run tests
section "Running Tests"
if swift test --parallel; then
    success "All tests passed"
else
    error "Tests failed"
    exit 1
fi

# Count tests
section "Counting Tests"
TEST_COUNT=$(swift test --list-tests 2>&1 | grep -c "Test Case" || echo "0")
echo "Total tests found: $TEST_COUNT"
if [ "$TEST_COUNT" -ge 1000 ]; then
    success "Test count looks good (${TEST_COUNT} tests)"
else
    warning "Test count seems low (${TEST_COUNT} tests), expected 1464+"
fi

# Check if CLI tools can be built
section "Building CLI Tools (sample)"
CLI_TOOLS=(
    "dicom-info" "dicom-convert" "dicom-validate" "dicom-anon"
)

FAILED_TOOLS=()
for tool in "${CLI_TOOLS[@]}"; do
    if swift build --product "$tool" > /dev/null 2>&1; then
        echo "  ✓ $tool"
    else
        echo "  ✗ $tool"
        FAILED_TOOLS+=("$tool")
    fi
done

if [ ${#FAILED_TOOLS[@]} -eq 0 ]; then
    success "Sample CLI tools built successfully"
else
    error "Failed to build: ${FAILED_TOOLS[*]}"
    exit 1
fi

# Check documentation can be built (optional, may be slow)
if [ "$1" == "--with-docs" ]; then
    section "Building Documentation"
    if swift package generate-documentation --target DICOMKit > /dev/null 2>&1; then
        success "Documentation built successfully"
    else
        warning "Documentation build had issues (non-fatal)"
    fi
fi

# Summary
echo ""
echo "================================"
echo -e "${GREEN}✅ All local CI checks passed!${NC}"
echo ""
echo "Your changes are ready to push."
echo ""
echo "Optional: Run with --with-docs to include documentation build check"
echo "Example: .github/scripts/local-ci.sh --with-docs"
