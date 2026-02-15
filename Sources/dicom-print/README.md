# dicom-print

DICOM Print Management CLI tool for sending medical images to DICOM-compliant printers.

## Overview

`dicom-print` provides command-line access to DICOM Print Management Service Class operations. It allows you to:

- Query printer status
- Send DICOM images to printers
- Monitor print job status
- Manage printer configurations

Reference: DICOM PS3.4 Annex H - Print Management Service Class

## Installation

The tool is included with DICOMKit and can be built using Swift Package Manager:

```bash
swift build -c release --product dicom-print
```

The executable will be available at `.build/release/dicom-print`.

## Usage

### Query Printer Status

```bash
# Query printer status
dicom-print status pacs://192.168.1.100:11112 --aet WORKSTATION

# With verbose output
dicom-print status pacs://192.168.1.100:11112 --aet WORKSTATION --verbose

# JSON output
dicom-print status pacs://192.168.1.100:11112 --aet WORKSTATION --format json
```

### Print DICOM Images

```bash
# Print single image
dicom-print send pacs://192.168.1.100:11112 image.dcm --aet WORKSTATION

# Print with custom options
dicom-print send pacs://server:11112 scan.dcm --aet APP \
    --copies 2 --film-size 14x17 --orientation landscape

# Print multiple images with layout
dicom-print send pacs://server:11112 *.dcm --aet APP --layout 2x3

# Print directory recursively
dicom-print send pacs://server:11112 studies/ --aet APP --recursive

# Dry run (show what would be printed)
dicom-print send pacs://server:11112 *.dcm --aet APP --dry-run
```

### Monitor Print Jobs

```bash
# Query print job status
dicom-print job pacs://server:11112 --aet APP --job-id 1.2.840.113619.2.55.3.2024...

# JSON output
dicom-print job pacs://server:11112 --aet APP --job-id 1.2.840... --format json
```

### Printer Configuration

```bash
# List configured printers
dicom-print list-printers

# Add a new printer
dicom-print add-printer --name radiology-printer \
    --host 192.168.1.100 --port 11112 --called-ae PRINT_SCP

# Add a color printer as default
dicom-print add-printer --name color-printer \
    --host 10.0.0.50 --port 11112 --called-ae COLOR_PRINT \
    --color color --default

# Remove a printer
dicom-print remove-printer --name radiology-printer
```

## Options

### Global Options

| Option | Description |
|--------|-------------|
| `--aet` | Local Application Entity Title (calling AE) |
| `--called-aet` | Remote Application Entity Title (default: ANY-SCP) |
| `--timeout` | Connection timeout in seconds (default: 30-60) |
| `--verbose` / `-v` | Show verbose output |
| `--format` | Output format: text, json |

### Print Options

| Option | Description |
|--------|-------------|
| `--copies` | Number of copies (default: 1) |
| `--film-size` | Film size: 8x10, 10x12, 10x14, 11x14, 11x17, 14x14, 14x17, a4, a3 |
| `--orientation` | Film orientation: portrait, landscape |
| `--priority` | Print priority: low, medium, high |
| `--layout` | Image layout: 1x1, 1x2, 2x1, 2x2, 2x3, 3x3, 3x4, 4x4, 4x5 |
| `--medium` | Medium type: paper, clear-film, blue-film |
| `--recursive` / `-r` | Recursively scan directories |
| `--dry-run` | Show what would be printed without printing |

## Configuration File

Printer configurations are stored in:
- macOS/Linux: `~/.config/dicomkit/printers.json`

Example configuration:

```json
[
  {
    "name": "radiology-printer",
    "host": "192.168.1.100",
    "port": 11112,
    "calledAETitle": "PRINT_SCP",
    "callingAETitle": "WORKSTATION",
    "colorMode": "grayscale",
    "isDefault": true
  }
]
```

## Film Sizes

| Size | Description |
|------|-------------|
| `8x10` | 8×10 inches |
| `10x12` | 10×12 inches |
| `10x14` | 10×14 inches |
| `11x14` | 11×14 inches |
| `11x17` | 11×17 inches (Tabloid) |
| `14x14` | 14×14 inches |
| `14x17` | 14×17 inches |
| `a4` | A4 size (210×297 mm) |
| `a3` | A3 size (297×420 mm) |

## Image Layouts

| Layout | Description |
|--------|-------------|
| `1x1` | Single image |
| `1x2` | 2 images horizontal |
| `2x1` | 2 images vertical |
| `2x2` | 4 images in grid |
| `2x3` | 6 images (2 rows × 3 columns) |
| `3x3` | 9 images in grid |
| `3x4` | 12 images (3 rows × 4 columns) |
| `4x4` | 16 images in grid |
| `4x5` | 20 images (4 rows × 5 columns) |

## Examples

### Basic Workflow

```bash
# 1. Check printer status
dicom-print status pacs://192.168.1.100:11112 --aet APP

# 2. Print an image
dicom-print send pacs://192.168.1.100:11112 ct_scan.dcm --aet APP

# 3. Monitor the print job
dicom-print job pacs://192.168.1.100:11112 --aet APP --job-id 1.2.840...
```

### Batch Printing

```bash
# Print all DICOM files in a study directory
dicom-print send pacs://server:11112 study_folder/ --aet APP --recursive

# Print with specific layout for comparison
dicom-print send pacs://server:11112 pre.dcm post.dcm --aet APP --layout 1x2
```

### High Quality Mammography Print

```bash
dicom-print send pacs://mammo-printer:11112 mammo_*.dcm \
    --aet MAMMO_WS \
    --film-size 14x17 \
    --medium clear-film \
    --priority high \
    --layout 1x1
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 64 | Command line usage error |
| 65 | Data format error |
| 66 | Cannot open input file |
| 74 | I/O error |

## See Also

- [DICOM_PRINTER_PLAN.md](../../DICOM_PRINTER_PLAN.md) - Full implementation plan
- [DICOM_PRINTER_QUICK_REFERENCE.md](../../DICOM_PRINTER_QUICK_REFERENCE.md) - Quick reference
- DICOM PS3.4 Annex H - Print Management Service Class specification

## Version

v1.4.5 - Part of DICOMKit Print Management (Phase 5)
