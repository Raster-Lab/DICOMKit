# dicom-merge

Combine single-frame DICOM images into multi-frame files.

## Overview

`dicom-merge` combines multiple single-frame DICOM images into multi-frame DICOM files. It supports creating standard multi-frame formats or Enhanced CT/MR/XA formats with proper functional groups. The tool can also organize files by series or study.

## Features

- **Single-to-Multi-Frame Conversion**: Combine single frames into a single multi-frame file
- **Series Merging**: Group files by Series Instance UID and create one multi-frame file per series
- **Study Merging**: Group files by Study Instance UID, then by series
- **Frame Sorting**: Order frames by Instance Number, Image Position Patient, or Acquisition Time
- **Consistency Validation**: Verify that input files have compatible attributes
- **Metadata Consolidation**: Automatically merge and update DICOM metadata
- **UID Generation**: Generate unique SOP Instance UIDs for merged files

## Usage

### Basic Usage

Combine single frames into multi-frame:
```bash
dicom-merge frame_001.dcm frame_002.dcm frame_003.dcm --output multiframe.dcm
```

Using wildcard expansion:
```bash
dicom-merge frame_*.dcm --output multiframe.dcm
```

### Frame Sorting

Sort by Instance Number (default):
```bash
dicom-merge slices/*.dcm --output volume.dcm
```

Sort by Image Position Patient (Z coordinate):
```bash
dicom-merge slices/*.dcm --output volume.dcm --sort-by ImagePositionPatient
```

Sort by Acquisition Time:
```bash
dicom-merge slices/*.dcm --output volume.dcm --sort-by AcquisitionTime
```

Descending order:
```bash
dicom-merge slices/*.dcm --output volume.dcm --order descending
```

### Series and Study Merging

Merge by series (one file per series):
```bash
dicom-merge study_dir/ --output merged/ --level series --recursive
```

Merge by study (organized by study and series):
```bash
dicom-merge data/ --output organized/ --level study --recursive
```

### Enhanced Formats

Create Enhanced CT (not yet implemented):
```bash
dicom-merge ct_slices/*.dcm --output enhanced_ct.dcm --format enhanced-ct
```

Create Enhanced MR (not yet implemented):
```bash
dicom-merge mr_slices/*.dcm --output enhanced_mr.dcm --format enhanced-mr
```

### Validation

Validate consistency before merging:
```bash
dicom-merge slices/*.dcm --output volume.dcm --validate
```

### Verbose Output

Show detailed processing information:
```bash
dicom-merge slices/*.dcm --output volume.dcm --verbose
```

## Options

### Required
- `<inputs>...` - Input DICOM files or directories

### Optional
- `-o, --output <path>` - Output file or directory path
- `--format <format>` - Output format: standard, enhanced-ct, enhanced-mr, enhanced-xa (default: standard)
- `--level <level>` - Merge level: file, series, study (default: file)
- `--sort-by <criteria>` - Sort frames by: InstanceNumber, ImagePositionPatient, AcquisitionTime, none (default: InstanceNumber)
- `--order <order>` - Sort order: ascending, descending (default: ascending)
- `--validate` - Validate consistency of input files
- `-r, --recursive` - Process directories recursively
- `-v, --verbose` - Show verbose output

## Merge Levels

### File Level (default)
Combines all input files into a single multi-frame DICOM file.

```bash
dicom-merge frame_*.dcm --output merged.dcm
```

### Series Level
Groups files by Series Instance UID and creates one multi-frame file per series.

```bash
dicom-merge study/ --output output/ --level series
```

Output structure:
```
output/
├── series_1.2.840.113619.2.134.dcm
├── series_1.2.840.113619.2.135.dcm
└── series_1.2.840.113619.2.136.dcm
```

### Study Level
Groups files by Study Instance UID, then by series. Creates a directory per study containing multi-frame files per series.

```bash
dicom-merge data/ --output output/ --level study
```

Output structure:
```
output/
├── study_1.2.840.113619.2.1/
│   ├── series_1.2.840.113619.2.1.1.dcm
│   └── series_1.2.840.113619.2.1.2.dcm
└── study_1.2.840.113619.2.2/
    ├── series_1.2.840.113619.2.2.1.dcm
    └── series_1.2.840.113619.2.2.2.dcm
```

## Sort Criteria

### Instance Number
Sorts frames by the DICOM Instance Number attribute (0020,0013). This is the default.

### Image Position Patient
Sorts frames by the Z coordinate (third component) of Image Position Patient (0020,0032). Useful for CT/MR volumes where slices have spatial positions.

### Acquisition Time
Sorts frames by Acquisition Time (0008,0032). Useful for temporal sequences.

### None
Preserves the order in which files were provided.

## Validation

When `--validate` is enabled, the tool checks that all input files have consistent values for critical attributes:

- Study Instance UID
- Series Instance UID
- Modality
- Rows and Columns
- Bits Allocated, Bits Stored, High Bit
- Pixel Representation
- Samples Per Pixel
- Photometric Interpretation
- Pixel Data Size

If any inconsistencies are found, the tool reports an error and does not create output.

## Examples

### Example 1: Combine CT Slices

Combine CT slices into a single multi-frame file, sorted by position:

```bash
dicom-merge ct_slices/*.dcm \
  --output ct_volume.dcm \
  --sort-by ImagePositionPatient \
  --validate \
  --verbose
```

### Example 2: Organize Multi-Series Study

Process a study directory containing multiple series, creating one multi-frame file per series:

```bash
dicom-merge study_20240101/ \
  --output organized/ \
  --level series \
  --recursive \
  --verbose
```

### Example 3: Process Multiple Studies

Process multiple studies, organizing by study and series:

```bash
dicom-merge patient_data/ \
  --output processed/ \
  --level study \
  --recursive \
  --validate
```

## Technical Details

### DICOM Compliance

- Generates valid DICOM Part 10 files
- Updates Number of Frames (0028,0008) attribute
- Generates unique SOP Instance UIDs using DICOMKit's UID generator
- Concatenates pixel data from all frames
- Preserves most metadata from the first input file
- Updates Instance Number to 1 (multi-frame files are single instances)

### Limitations

- Enhanced CT/MR/XA formats with Functional Groups are not yet fully implemented
- Shared and Per-frame Functional Groups are not yet created
- Some per-frame attributes are not moved to functional groups
- Compressed pixel data is not yet supported
- Encapsulated pixel data (JPEG, JPEG 2000) is not yet supported

### Future Enhancements

- Full Enhanced CT/MR/XA support with functional groups
- Per-frame metadata preservation in functional groups
- Compressed pixel data support
- Custom frame reordering
- Frame de-duplication
- Metadata merging strategies

## Exit Codes

- `0` - Success
- `1` - General error (invalid arguments, file I/O errors)
- `64` - Validation error (inconsistent input files)

## See Also

- `dicom-split` - Extract individual frames from multi-frame files
- `dicom-info` - Display DICOM metadata
- `dicom-validate` - Validate DICOM conformance
- `dicom-convert` - Convert transfer syntaxes

## Version

1.1.2 (Phase 2)
