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
  --profile STD-GEN-DVD-JPEG

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
- `--file-set-id <id>`: File-set ID (0004,1130), up to 16 characters A-Z, 0-9, _ (PS3.10 8.1, 8.5); a value outside these rules is refused with exit 1 (it was written with a warning before 2026-10-01) (default: the directory name upper-cased, other characters replaced by `_`, cut to 16)
- `--profile <profile>`: PS3.11 Application Profile identifier (default STD-GEN-CD; e.g. STD-GEN-DVD-JPEG, STD-GEN-USB-JPEG). The deprecated spellings STD-GEN-DVD, STD-GEN-USB, STD-GEN-SEC, STD-CTMR-XXXX and STD-US-XXXX are not PS3.11 identifiers; they are still accepted, print a stderr warning, and write STD-GEN-DVD-JPEG, STD-GEN-USB-JPEG, STD-GEN-SEC-CD, STD-CTMR-CD and STD-US-ID-SF-CDR respectively
- `--recursive`: Recursively scan subdirectories (default: true)
- `--strict`: Include only valid DICOM files
- `--verbose`: Verbose output showing progress

### Validate Command

- `--check-files`: Verify that every Referenced File ID (0004,1500) names a file in the File-set (PS3.10 8.6)

`validate` also checks the File-set ID (PS3.10 8.1, 8.5) and every Referenced File ID (at most 8 components of 1 to 8 characters A-Z, 0-9, _; PS3.10 8.2, 8.5; each File referenced by at most one record, PS3.3 Table F.3-3) and names the clause each failure breaks. `create` warns when the file names it indexes are not valid File IDs: the File IDs are the paths relative to the input directory, so name the files accordingly (e.g. `DIR00001/IMG00001`).
- `--detailed`: Show detailed validation output including record statistics

### Dump Command

- `--format, -f <format>`: Output format (tree, json, text)
- `--verbose`: Show all attributes for each record

## Application Profiles

The tool supports standard DICOM application profiles:

- **STD-GEN-CD**: General Purpose CD-R Interchange (default; PS3.11 Table D.1-1)
- **STD-GEN-DVD-JPEG** / **STD-GEN-DVD-J2K**: General Purpose DVD Interchange with JPEG / JPEG 2000 (Table H.1-1)
- **STD-GEN-USB-JPEG** / **STD-GEN-USB-J2K**: General Purpose USB Media Interchange with JPEG / JPEG-2000 (Table J.1-1)
- every other identifier of PS3.11 2026a Annexes A-N (`dicom-dcmdir create --help` and the error text list them)

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

The File-set ID (0004,1130) is a short human-readable label for the File-set (PS3.10 8.1, PS3.3 Table F.3-2):
- 0 to 16 characters
- Uppercase letters (A-Z), digits (0-9) and underscore only; SPACE is not allowed (PS3.10 8.5)
- Not necessarily unique; the File-set UID identifies the File-set

### Referenced File Paths

File IDs in DICOMDIR are stored in Referenced File ID (0004,1500) as components relative to the DICOMDIR location: 1 to 8 components, each 1 to 8 characters from A-Z, 0-9 and _ (PS3.10 8.2, 8.5). For example:
- `["PATIENT1", "STUDY1", "SERIES1", "IMG00001"]`
- Represents: `PATIENT1/STUDY1/SERIES1/IMG00001`

### Consistency Flag

File-set Consistency Flag (0004,1212) is written as 0000H. PS3.3 2026a Table F.3-3: "The Value FFFFH shall never be present."

## Limitations

- **Extract command** is not yet implemented
- Only supports standard directory record types (PATIENT, STUDY, SERIES, IMAGE)
- Icon images are not currently supported

## See Also

- `dicom-info` - Display DICOM file metadata
- `dicom-dump` - Hexadecimal dump of DICOM files
- `dicom-validate` - Validate DICOM files

## References

- DICOM PS3.3 Annex F - Basic Directory IOD (Table F.4-1 record types, F.5 directory records)
- DICOM PS3.4 Annex I - Media Storage Service Class (Media Storage Directory Storage, 1.2.840.10008.1.3.10)
- DICOM PS3.10 Section 8 - DICOM File Service (File-set, File IDs, character set, DICOMDIR)
- DICOM PS3.11 - Media Storage Application Profiles
