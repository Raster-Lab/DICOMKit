# dicom-validate

Validate DICOM files against standards and best practices.

## Features

- **Multiple Validation Levels**
  - Level 1: File format compliance
  - Level 2: VR against the PS3.6 dictionary; DA, TM and UI value forms (PS3.5 Table 6.2-1, 9.1)
  - Level 3: IOD-specific rules
  - Level 4: Best practices and recommendations

- **IOD Support**
  - CT Image Storage
  - MR Image Storage
  - Computed Radiography Image Storage
  - Ultrasound Image Storage
  - Secondary Capture Image Storage
  - Grayscale Softcopy Presentation State Storage
  - Pseudo-Color Softcopy Presentation State Storage
  - SR and Key Object Selection Document Storage

- **Batch Processing**
  - Validate entire directories recursively
  - Generate summary or detailed reports
  - JSON output for CI/CD integration

- **Conformance Checks**
  - DICOM Part 10 file format
  - Value Representation (VR) validation
  - Required attributes per IOD (Type 1, 1C, 2, 2C), each error naming the PS3.3 module table and PS3.5 7.4.x
  - Transfer Syntax validation
  - UID format validation
  - Date/Time format validation

## Usage

### Basic Validation

```bash
dicom-validate file.dcm
```

### Validation Levels

```bash
# Level 1: Format only
dicom-validate file.dcm --level 1

# Level 2: Format + VR and DA/TM/UI value forms
dicom-validate file.dcm --level 2

# Level 3: Format + Tags + IOD rules (default)
dicom-validate file.dcm --level 3

# Level 4: All checks + best practices
dicom-validate file.dcm --level 4
```

### IOD-Specific Validation

```bash
dicom-validate ct.dcm --iod CTImageStorage
dicom-validate mr.dcm --iod MRImageStorage
# --iod takes the PS3.6 Table A-1 keyword or SOP Class UID
dicom-validate cr.dcm --iod ComputedRadiographyImageStorage
```

### Directory Validation

```bash
# Validate entire directory
dicom-validate study/ --recursive

# Detailed report
dicom-validate study/ --recursive --detailed
```

### JSON Output

```bash
# Generate JSON report
dicom-validate file.dcm --format json

# Save to file
dicom-validate study/ --recursive --format json --output report.json
```

### Strict Mode

```bash
# Treat warnings as errors (non-zero exit code)
dicom-validate file.dcm --strict
```

## Exit Codes

- `0`: All files valid
- `1`: One or more files have errors
- `2`: Strict mode enabled and warnings found

## Output Formats

### Text (Default)

```
DICOM Validation Report
=======================

File: /path/to/file.dcm
Status: ✓ VALID

Warnings (1):
  • Specific Character Set not specified (ISO_IR 100 or UTF-8 recommended) [(0008,0005)]
```

### JSON

```json
{
  "files": [
    {
      "errorCount": 0,
      "errors": [],
      "filePath": "/path/to/file.dcm",
      "isValid": true,
      "warningCount": 1,
      "warnings": [
        {
          "message": "Specific Character Set not specified",
          "tag": "(0008,0005)"
        }
      ]
    }
  ],
  "invalidFiles": 0,
  "totalErrors": 0,
  "totalFiles": 1,
  "totalWarnings": 1,
  "validFiles": 1
}
```

## Validation Rules

### Level 1: File Format
- DICOM preamble and DICM prefix
- File Meta Information presence
- Transfer Syntax UID validity

### Level 2: Tags and Values
- SOP Class UID and SOP Instance UID present with a value
- VR validation against the PS3.6 dictionary
- UID format (PS3.5 9.1)
- Date format (YYYYMMDD, PS3.5 Table 6.2-1 DA)
- Time format (HHMMSS.FFFFFF, PS3.5 Table 6.2-1 TM)
- Person Name: at most three component groups
- Code String: uppercase
- Not checked: VM, and the maximum lengths and character repertoires of Table 6.2-1 for the other VRs

### Level 3: IOD-Specific
- Type 1 and Type 2 attributes of the IOD's mandatory modules (PS3.3 IOD and module tables)
- Type 1C / 2C attributes whose condition can be evaluated
- Enumerated value constraints
- Pixel data requirements (for image IODs)

### Level 4: Best Practices
- Character set specification
- Private tag warnings (more than 10 private tags)
- Modality against the PS3.3 C.7.3.1.1.1 Defined Terms

## Examples

### CI/CD Integration

```bash
#!/bin/bash
# Validate all DICOM files in CI pipeline

dicom-validate test_data/ --recursive --format json --output validation.json --strict

if [ $? -ne 0 ]; then
  echo "Validation failed"
  exit 1
fi
```

### Quality Assurance

```bash
# Validate exported DICOM files
dicom-validate exports/ --recursive --level 4 --detailed > qa_report.txt
```

### Format Verification

```bash
# Quick format check only
dicom-validate batch/ --recursive --level 1
```

## Supported IODs

| IOD | SOP Class UID | Validation Level |
|-----|---------------|------------------|
| CT Image Storage | 1.2.840.10008.5.1.4.1.1.2 | Full |
| MR Image Storage | 1.2.840.10008.5.1.4.1.1.4 | Full |
| Computed Radiography Image Storage | 1.2.840.10008.5.1.4.1.1.1 | Full |
| Ultrasound Image Storage | 1.2.840.10008.5.1.4.1.1.6.1 | Full |
| Secondary Capture Image Storage | 1.2.840.10008.5.1.4.1.1.7 | Full |
| Grayscale Softcopy Presentation State Storage | 1.2.840.10008.5.1.4.1.1.11.1 | Full |
| Pseudo-Color Softcopy Presentation State Storage | 1.2.840.10008.5.1.4.1.1.11.3 | Full |
| SR and Key Object Selection Document Storage | 1.2.840.10008.5.1.4.1.1.88.x | Basic |

## Building

```bash
swift build --target dicom-validate
```

## Testing

```bash
swift test --filter dicom_validateTests
```

## See Also

- `dicom-info` - Display DICOM metadata
- `dicom-convert` - Convert DICOM files
- `dicom-anon` - Anonymize DICOM files
