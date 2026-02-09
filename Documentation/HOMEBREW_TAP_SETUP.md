# Homebrew Tap Setup Guide

This guide explains how to set up a Homebrew tap for DICOMKit to make installation easier for users.

## What is a Homebrew Tap?

A Homebrew "tap" is a GitHub repository containing Homebrew formulae. Taps allow you to distribute software through Homebrew without submitting to the main Homebrew repository.

## Setting Up the Tap Repository

### 1. Create a New Repository

Create a new GitHub repository named `homebrew-dicomkit` under your organization:
- Repository name: `homebrew-dicomkit`
- Description: "Homebrew formulae for DICOMKit CLI tools"
- Public repository
- Initialize with README

The repository URL will be: `https://github.com/Raster-Lab/homebrew-dicomkit`

### 2. Add the Formula

Copy the formula from this repository to the tap:

```bash
# Clone the tap repository
git clone https://github.com/Raster-Lab/homebrew-dicomkit.git
cd homebrew-dicomkit

# Create Formula directory
mkdir -p Formula

# Copy the formula from DICOMKit repository
cp ../DICOMKit/Formula/dicomkit.rb Formula/

# Commit and push
git add Formula/dicomkit.rb
git commit -m "Add DICOMKit formula"
git push
```

### 3. Update the Formula with Release Information

After creating a GitHub release (v1.0.0), update the formula with:
- The correct tarball URL
- The SHA256 checksum of the tarball

```ruby
url "https://github.com/Raster-Lab/DICOMKit/archive/refs/tags/v1.0.0.tar.gz"
sha256 "ACTUAL_SHA256_HERE"
```

To calculate the SHA256:
```bash
curl -L https://github.com/Raster-Lab/DICOMKit/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
```

## Using the Tap

Once the tap is set up, users can install DICOMKit with:

```bash
# Add the tap
brew tap Raster-Lab/dicomkit

# Install DICOMKit
brew install dicomkit
```

Or in one command:
```bash
brew install Raster-Lab/dicomkit/dicomkit
```

## Updating the Formula

When releasing a new version:

1. Create a GitHub release in the DICOMKit repository
2. Update the formula in the tap repository:
   - Update the `url` with the new version tag
   - Update the `sha256` with the new checksum
3. Commit and push the changes

```bash
cd homebrew-dicomkit
# Edit Formula/dicomkit.rb
git add Formula/dicomkit.rb
git commit -m "Update to v1.0.1"
git push
```

Users can then upgrade with:
```bash
brew upgrade dicomkit
```

## Formula Testing

Test the formula before publishing:

```bash
# Install from local formula
brew install --build-from-source Formula/dicomkit.rb

# Run formula tests
brew test dicomkit

# Audit the formula
brew audit --strict dicomkit

# Uninstall for clean testing
brew uninstall dicomkit
```

## Automatic Updates with GitHub Actions

You can automate formula updates by adding a GitHub Action to the DICOMKit repository that:

1. Triggers on new tag creation
2. Calculates the SHA256 of the release tarball
3. Opens a pull request in the tap repository with the updated formula

Example workflow (add to `.github/workflows/update-homebrew.yml`):

```yaml
name: Update Homebrew Formula

on:
  release:
    types: [published]

jobs:
  update-formula:
    runs-on: ubuntu-latest
    steps:
      - name: Update Homebrew formula
        uses: dawidd6/action-homebrew-bump-formula@v3
        with:
          token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
          formula: dicomkit
          tap: Raster-Lab/homebrew-dicomkit
          tag: ${{ github.ref_name }}
```

Note: You'll need to create a `HOMEBREW_TAP_TOKEN` secret with write access to the tap repository.

## Directory Structure

The tap repository should look like:

```
homebrew-dicomkit/
├── README.md
├── Formula/
│   └── dicomkit.rb
└── .github/
    └── workflows/
        └── tests.yml (optional)
```

## Tap Maintenance

### Keeping It Simple
- Keep the tap repository minimal - just the formula and README
- Use GitHub releases for distribution (don't upload binaries to the tap)
- Link to main DICOMKit repository for issues and documentation

### Documentation in the Tap
Create a README.md in the tap repository:

```markdown
# DICOMKit Homebrew Tap

This tap provides Homebrew formulae for DICOMKit CLI tools.

## Installation

```bash
brew tap Raster-Lab/dicomkit
brew install dicomkit
```

## Tools Included

All 29 DICOMKit CLI tools:
- dicom-info, dicom-convert, dicom-validate, ...

## Documentation

For full documentation, see the main repository:
https://github.com/Raster-Lab/DICOMKit
```

## Testing Checklist

Before releasing the tap publicly:

- [ ] Formula installs successfully
- [ ] All 29 CLI tools are present in `/usr/local/bin` (or `/opt/homebrew/bin` on Apple Silicon)
- [ ] Tools run without errors (`dicom-info --version`)
- [ ] Formula passes `brew audit --strict`
- [ ] Formula passes `brew test`
- [ ] Documentation is clear and complete
- [ ] Tap README explains installation

## Troubleshooting

### "Formula not found"
Make sure the tap is added: `brew tap Raster-Lab/dicomkit`

### Build failures
- Check that macOS and Xcode requirements are met
- Verify the tarball URL is accessible
- Check that dependencies are correctly specified

### Installation conflicts
If users have installed manually:
```bash
# Remove manual installation
rm /usr/local/bin/dicom-*

# Then install via Homebrew
brew install dicomkit
```

## Resources

- [Homebrew Tap Documentation](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew on GitHub](https://github.com/Homebrew/brew)
