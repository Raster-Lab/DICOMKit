# dicom-validate

Validate DICOM files against standards and best practices.

## Features

- **Multiple Validation Levels**
  - Level 1: File format compliance
  - Level 2: Tag presence and VR/VM validation
  - Level 3: IOD-specific rules
  - Level 4: Best practices and recommendations

- **IOD Support**
  - CT Image Storage
  - MR Image Storage
  - CR Image Storage
  - Ultrasound Image Storage
  - Secondary Capture Image Storage
  - Grayscale Softcopy Presentation State
  - Structured Report

- **Batch Processing**
  - Validate entire directories recursively
  - Generate summary or detailed reports
  - JSON output for CI/CD integration

- **Conformance Checks**
  - DICOM Part 10 file format
  - Value Representation (VR) validation
  - Value Multiplicity (VM) validation
  - Required tag presence (Type 1, Type 2)
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

# Level 2: Format + Tags/VR/VM
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
- Required Type 1 elements (must be present with value)
- Required Type 2 elements (must be present, may be empty)
- VR validation against dictionary
- VM validation
- UID format validation
- Date format (YYYYMMDD)
- Time format (HHMMSS.FFFFFF)
- Person Name format
- Code String format

### Level 3: IOD-Specific
- Modality-specific required attributes
- Conditional attributes
- Enumerated value constraints
- Pixel data requirements (for image IODs)

### Level 4: Best Practices
- Character set specification
- Deprecated tag usage
- Private tag warnings
- Interoperability recommendations

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
| CR Image Storage | 1.2.840.10008.5.1.4.1.1.1 | Full |
| US Image Storage | 1.2.840.10008.5.1.4.1.1.6.1 | Full |
| Secondary Capture | 1.2.840.10008.5.1.4.1.1.7 | Full |
| GSPS | 1.2.840.10008.5.1.4.1.1.11.1 | Full |
| Structured Report | 1.2.840.10008.5.1.4.1.1.88.x | Basic |

## Building

```bash
swift build --target dicom-validate
```

## Testing

```bash
swift test --filter DICOMValidateTests
```

## See Also

- `dicom-info` - Display DICOM metadata
- `dicom-convert` - Convert DICOM files
- `dicom-anon` - Anonymize DICOM files
