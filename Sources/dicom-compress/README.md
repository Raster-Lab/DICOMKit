# dicom-compress

DICOM compression and decompression utilities for DICOMKit.

## Features

- **Compress** DICOM files using various codecs (JPEG, JPEG 2000, RLE, Deflate)
- **Decompress** compressed DICOM files to uncompressed transfer syntaxes
- **Info** — display compression status, transfer syntax, and image parameters
- **Batch** — process entire directories with optional recursion

## Installation

Built as part of DICOMKit using Swift Package Manager:

```bash
swift build --product dicom-compress
```

## Usage

### Info — Show Compression Details

```bash
# Display compression info for a DICOM file
dicom-compress info file.dcm

# Output as JSON
dicom-compress info file.dcm --json
```

### Compress — Compress a DICOM File

```bash
# Compress using JPEG Lossless
dicom-compress compress input.dcm --output output.dcm --codec jpeg-lossless

# Compress using JPEG 2000 with high quality
dicom-compress compress input.dcm --output output.dcm --codec jpeg2000 --quality high

# Compress using JPEG Baseline with custom quality
dicom-compress compress input.dcm --output output.dcm --codec jpeg-baseline --quality 0.85
```

### Decompress — Decompress a DICOM File

```bash
# Decompress to Explicit VR Little Endian (default)
dicom-compress decompress compressed.dcm --output uncompressed.dcm

# Decompress to Implicit VR Little Endian
dicom-compress decompress compressed.dcm --output uncompressed.dcm --syntax implicit-le
```

### Batch — Process Directories

```bash
# Batch compress a directory
dicom-compress batch input_dir/ --output output_dir/ --codec jpeg-lossless

# Batch compress recursively with quality setting
dicom-compress batch input_dir/ --output output_dir/ --codec jpeg2000 --quality high --recursive

# Batch decompress
dicom-compress batch input_dir/ --output output_dir/ --decompress --recursive
```

## Supported Codecs

| Codec Name | Aliases | Transfer Syntax | Lossless |
|---|---|---|---|
| `jpeg` | `jpeg-baseline` | JPEG Baseline (Process 1) | No |
| `jpeg-extended` | — | JPEG Extended (Process 2 & 4) | No |
| `jpeg-lossless` | — | JPEG Lossless (Process 14) | Yes |
| `jpeg-lossless-sv1` | — | JPEG Lossless SV1 | Yes |
| `jpeg2000` | `j2k` | JPEG 2000 | No |
| `jpeg2000-lossless` | `j2k-lossless` | JPEG 2000 Lossless | Yes |
| `rle` | — | RLE Lossless | Yes |
| `deflate` | — | Deflated Explicit VR LE | Yes |
| `explicit-le` | — | Explicit VR Little Endian | Yes |
| `implicit-le` | — | Implicit VR Little Endian | Yes |

## Quality Settings

The `--quality` option accepts:

- `maximum` — highest quality (0.98), lossless where supported
- `high` — high quality (0.90)
- `medium` — medium quality (0.75)
- `low` — low quality (0.60)
- A decimal value between `0.0` and `1.0` for custom quality

Quality settings only apply to lossy codecs (JPEG Baseline, JPEG Extended, JPEG 2000).

## Notes

- DICOM files are detected by `.dcm`, `.dicom`, `.dic` extensions or by the `DICM` magic prefix
- Batch mode preserves directory structure in the output
- The tool writes valid DICOM Part 10 files with proper File Meta Information
- Platform codec support may vary; not all codecs are available on all systems

## Version

1.3.3 (Phase 6 — DICOMKit CLI Tools)
