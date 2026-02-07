# dicom-dcmdir

DICOMDIR management tool for creating, validating, and managing DICOM media storage directories.

## Overview

`dicom-dcmdir` is a command-line utility for working with DICOMDIR files, which are special DICOM files that provide an index of all DICOM files on removable media (CD, DVD, USB). DICOMDIR files enable efficient browsing of medical images without reading all files individually.

## Features

- **Create DICOMDIR**: Generate DICOMDIR from directories of DICOM files
- **Validate**: Verify DICOMDIR structure and integrity
- **Dump**: Display DICOMDIR contents in various formats (tree, JSON, text)
- **Update**: Add new files to existing DICOMDIR (planned)

## Usage

### Create a DICOMDIR

Create a DICOMDIR from a directory containing DICOM files:

```bash
# Basic creation
dicom-dcmdir create study_folder/ --output DICOMDIR

# With custom file-set ID and profile
dicom-dcmdir create study_folder/ \
  --output DICOMDIR \
  --file-set-id "MYSTUDY" \
  --profile STD-GEN-DVD

# Strict mode (only include valid DICOM files)
dicom-dcmdir create study_folder/ --output DICOMDIR --strict --verbose
```

### Validate a DICOMDIR

Verify the structure and integrity of a DICOMDIR file:

```bash
# Basic validation
dicom-dcmdir validate DICOMDIR

# Detailed validation with file existence checks
dicom-dcmdir validate /media/cdrom/DICOMDIR --check-files --detailed
```

### Display DICOMDIR Structure

View the contents of a DICOMDIR in various formats:

```bash
# Tree format (default)
dicom-dcmdir dump DICOMDIR

# JSON format
dicom-dcmdir dump DICOMDIR --format json

# Text format with verbose output
dicom-dcmdir dump DICOMDIR --format text --verbose
```

## Options

### Create Command

- `--output, -o <path>`: Output DICOMDIR path (default: DICOMDIR in input directory)
- `--file-set-id <id>`: File-set identifier (default: derived from directory name)
- `--profile <profile>`: Application profile (STD-GEN-CD, STD-GEN-DVD, STD-GEN-USB)
- `--recursive`: Recursively scan subdirectories (default: true)
- `--strict`: Include only valid DICOM files
- `--verbose`: Verbose output showing progress

### Validate Command

- `--check-files`: Verify that referenced files exist
- `--detailed`: Show detailed validation output including record statistics

### Dump Command

- `--format, -f <format>`: Output format (tree, json, text)
- `--verbose`: Show all attributes for each record

## Application Profiles

The tool supports standard DICOM application profiles:

- **STD-GEN-CD**: General Purpose CD-R Interchange (default)
- **STD-GEN-DVD**: General Purpose DVD Interchange with JPEG
- **STD-GEN-USB**: General Purpose USB/Flash Memory with JPEG/JPEG 2000

## Examples

### Creating a DICOMDIR for CD Distribution

```bash
# Prepare directory with DICOM files
cd /path/to/study

# Create DICOMDIR with CD profile
dicom-dcmdir create . --profile STD-GEN-CD --verbose

# Validate the created DICOMDIR
dicom-dcmdir validate DICOMDIR --detailed

# View the structure
dicom-dcmdir dump DICOMDIR --format tree
```

### Validating a DICOMDIR from Mounted Media

```bash
# Mount CD/DVD
# (e.g., /media/cdrom or /Volumes/DICOM_CD)

# Validate the DICOMDIR
dicom-dcmdir validate /media/cdrom/DICOMDIR --check-files

# Display contents
dicom-dcmdir dump /media/cdrom/DICOMDIR
```

## DICOMDIR Structure

A DICOMDIR file contains a hierarchical directory structure:

```
DICOMDIR
├── PATIENT (Patient Name, ID)
│   └── STUDY (Study Date, Description)
│       └── SERIES (Modality, Series Description)
│           └── IMAGE (Instance Number, File Path)
```

Each record contains DICOM attributes relevant to that level of the hierarchy.

## Technical Details

### File-set ID

The File-set ID is an identifier for the file-set on the media. It should be:
- Up to 16 characters
- Composed of uppercase letters (A-Z), digits (0-9), underscores, and spaces
- Unique for the media

### Referenced File Paths

File paths in DICOMDIR are stored as path components (array of strings) relative to the DICOMDIR location. For example:
- `["PATIENT1", "STUDY1", "SERIES1", "IMG00001.dcm"]`
- Represents: `PATIENT1/STUDY1/SERIES1/IMG00001.dcm`

### Consistency Flag

The consistency flag indicates whether the DICOMDIR is in a consistent state:
- **Consistent (0x0000)**: DICOMDIR is complete and valid
- **Inconsistent (0xFFFF)**: DICOMDIR is being updated or corrupted

## Limitations

- **Update command** is not yet implemented (use create to rebuild)
- **Extract command** is not yet implemented
- Only supports standard directory record types (PATIENT, STUDY, SERIES, IMAGE)
- Icon images are not currently supported

## See Also

- `dicom-info` - Display DICOM file metadata
- `dicom-dump` - Hexadecimal dump of DICOM files
- `dicom-validate` - Validate DICOM files

## References

- DICOM PS3.3 F.5 - Media Storage Directory SOP Class
- DICOM PS3.10 - Media Storage and File Format
- DICOM PS3.11 - Media Storage Application Profiles
