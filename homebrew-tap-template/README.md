# DICOMKit Homebrew Tap

Homebrew formulae for [DICOMKit](https://github.com/Raster-Lab/DICOMKit) CLI tools.

## Installation

```bash
# Add the tap
brew tap Raster-Lab/dicomkit

# Install DICOMKit CLI tools
brew install dicomkit
```

Or install directly without adding the tap first:

```bash
brew install Raster-Lab/dicomkit/dicomkit
```

## Available Formulae

| Formula | Description |
|---------|-------------|
| `dicomkit` | Pure Swift DICOM toolkit with 35 command-line utilities |

## Tools Included

Installing `dicomkit` provides 35 CLI tools for working with DICOM medical imaging files:

### File Operations
- `dicom-info` - Display DICOM file metadata
- `dicom-dump` - Hexadecimal dump with DICOM structure
- `dicom-validate` - DICOM conformance validation
- `dicom-diff` - Compare DICOM files
- `dicom-convert` - Transfer syntax conversion
- `dicom-anon` - Anonymize patient information

### Network Operations
- `dicom-echo` - Test DICOM connectivity (C-ECHO)
- `dicom-query` - Query PACS servers (C-FIND)
- `dicom-send` - Send files to PACS (C-STORE)
- `dicom-retrieve` - Retrieve from PACS (C-MOVE/C-GET)
- `dicom-qr` - Combined query-retrieve workflow
- `dicom-wado` - DICOMweb client (WADO-RS, QIDO-RS, STOW-RS)
- `dicom-mwl` - Modality Worklist queries
- `dicom-mpps` - Modality Performed Procedure Step

### Format Conversion
- `dicom-json` - Convert to/from DICOM JSON
- `dicom-xml` - Convert to/from DICOM XML
- `dicom-pdf` - Handle encapsulated PDF/CDA documents
- `dicom-image` - Convert images to DICOM

### Archive Management
- `dicom-dcmdir` - Create and manage DICOMDIR files
- `dicom-archive` - Local DICOM archive with indexing
- `dicom-export` - Advanced export with metadata embedding
- `dicom-split` - Split multi-frame images
- `dicom-merge` - Merge into multi-frame images

### Advanced Utilities
- `dicom-pixedit` - Pixel data manipulation
- `dicom-tags` - Tag manipulation utilities
- `dicom-uid` - UID generation and management
- `dicom-compress` - Compression/decompression
- `dicom-study` - Study/Series organization
- `dicom-script` - Workflow automation scripting
- `dicom-report` - Structured report operations
- `dicom-measure` - Measurement extraction
- `dicom-viewer` - Terminal-based DICOM viewing
- `dicom-cloud` - Cloud storage integration
- `dicom-3d` - 3D volume operations
- `dicom-ai` - AI inference integration

## Requirements

- **macOS**: macOS 14.0 (Sonoma) or later
- **Xcode**: Xcode 15.0 or later (for building)

## Updating

```bash
brew update
brew upgrade dicomkit
```

## Uninstalling

```bash
brew uninstall dicomkit
brew untap Raster-Lab/dicomkit
```

## Documentation

For full documentation, see the main repository:
- **Repository**: https://github.com/Raster-Lab/DICOMKit
- **Installation Guide**: https://github.com/Raster-Lab/DICOMKit/blob/main/INSTALLATION.md
- **CLI Tools Reference**: https://github.com/Raster-Lab/DICOMKit/blob/main/CLI_TOOLS_PLAN.md

## Issues

Please report issues to the main DICOMKit repository:
https://github.com/Raster-Lab/DICOMKit/issues

## License

MIT License - see the [main repository](https://github.com/Raster-Lab/DICOMKit) for details.
