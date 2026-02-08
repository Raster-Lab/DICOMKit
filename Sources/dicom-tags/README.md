# dicom-tags

A command-line tool for adding, modifying, and deleting tags in DICOM files.

## Features

- **Set Tag Values**: Add or update tags by name or hex code
- **Delete Tags**: Remove specific tags from DICOM files
- **Delete Private Tags**: Strip all private (odd group) tags in one operation
- **Copy Tags**: Copy tags from one DICOM file to another
- **Dry Run**: Preview changes without writing to disk
- **Flexible Tag Formats**: Specify tags by name (e.g., `PatientName`) or hex (e.g., `0010,0010`)

## Installation

Build from source:

```bash
swift build -c release --target dicom-tags
```

The executable will be available at `.build/release/dicom-tags`.

## Usage

### Set Tag Values

```bash
# Set a tag by name
dicom-tags file.dcm --set PatientName=DOE^JOHN

# Set a tag by hex code
dicom-tags file.dcm --set 0010,0010=DOE^JOHN

# Set multiple tags
dicom-tags file.dcm --set PatientName=DOE^JOHN --set StudyDescription=Research

# Write to a different output file
dicom-tags file.dcm --set PatientName=DOE^JOHN --output modified.dcm
```

### Delete Tags

```bash
# Delete a tag by name
dicom-tags file.dcm --delete PatientBirthDate

# Delete multiple tags
dicom-tags file.dcm --delete PatientBirthDate --delete AccessionNumber

# Delete by hex code
dicom-tags file.dcm --delete 0010,0030
```

### Delete Private Tags

```bash
# Remove all private tags (odd group numbers)
dicom-tags file.dcm --delete-private --output clean.dcm
```

### Copy Tags Between Files

```bash
# Copy specific tags from another file
dicom-tags target.dcm --copy-from source.dcm --tags PatientName,PatientID

# Copy all tags from another file
dicom-tags target.dcm --copy-from source.dcm --output merged.dcm
```

### Dry Run

```bash
# Preview changes without writing
dicom-tags file.dcm --set StudyDescription=Research --delete AccessionNumber --dry-run

# Combine with verbose for detailed output
dicom-tags file.dcm --delete-private --dry-run --verbose
```

### Combined Operations

```bash
# Set, delete, and strip private tags in one pass
dicom-tags file.dcm \
  --set PatientName=ANONYMOUS \
  --delete PatientBirthDate \
  --delete-private \
  --output cleaned.dcm \
  --verbose
```

## Supported Tag Names

| Name | Tag | VR |
|------|-----|-----|
| PatientName | (0010,0010) | PN |
| PatientID | (0010,0020) | LO |
| PatientBirthDate | (0010,0030) | DA |
| PatientSex | (0010,0040) | CS |
| PatientAge | (0010,1010) | AS |
| StudyDate | (0008,0020) | DA |
| StudyTime | (0008,0030) | TM |
| StudyDescription | (0008,1030) | LO |
| StudyInstanceUID | (0020,000D) | UI |
| AccessionNumber | (0008,0050) | SH |
| ReferringPhysicianName | (0008,0090) | PN |
| SeriesDate | (0008,0021) | DA |
| SeriesDescription | (0008,103E) | LO |
| SeriesInstanceUID | (0020,000E) | UI |
| Modality | (0008,0060) | CS |
| InstitutionName | (0008,0080) | LO |
| SOPInstanceUID | (0008,0018) | UI |

Tags not listed above can always be specified by hex code (e.g., `0008,0050`).

## Exit Codes

- `0`: Success
- `1`: Failure (file not found, invalid tag format, write error, etc.)

## See Also

- `dicom-anon`: Anonymize DICOM files with privacy profiles
- `dicom-info`: Display DICOM file information
- `dicom-dump`: Hex dump of DICOM file contents
- `dicom-validate`: Validate DICOM file conformance

## License

Part of DICOMKit — See LICENSE file for details.
