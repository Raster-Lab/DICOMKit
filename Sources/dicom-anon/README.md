# dicom-anon

A command-line tool for anonymizing DICOM files to protect patient privacy.

## Features

- **Multiple Anonymization Profiles**:
  - **Basic Profile**: Removes patient name, ID, birth date, address, phone numbers, and institution information
  - **Clinical Trial Profile**: Basic profile plus date shifting for all study dates
  - **Research Profile**: Minimal anonymization retaining clinical data while removing direct identifiers
  - **Custom Profile**: User-defined tag removal and replacement

- **Anonymization Actions**:
  - Remove tags entirely
  - Replace with empty values
  - Replace with dummy values (e.g., "ANONYMOUS")
  - Hash values for consistent pseudonymization (SHA-256)
  - Shift dates by random offset while preserving intervals
  - Regenerate UIDs while maintaining study/series relationships

- **Safety Features**:
  - Dry-run mode to preview changes without modifying files
  - Backup original files before anonymization
  - Audit logging for compliance and tracking
  - PHI leak detection in private tags
  - Batch processing with consistent pseudonyms

## Installation

Build from source:

```bash
swift build -c release --target dicom-anon
```

The executable will be available at `.build/release/dicom-anon`.

## Usage

### Basic Anonymization

```bash
# Anonymize a single file with basic profile
dicom-anon file.dcm --output anon.dcm --profile basic

# Preview changes without modifying (dry-run)
dicom-anon file.dcm --profile basic --dry-run
```

### Date Shifting

```bash
# Shift all dates by 100 days
dicom-anon file.dcm --output anon.dcm --profile basic --shift-dates 100
```

### UID Regeneration

```bash
# Regenerate UIDs while preserving references
dicom-anon file.dcm --output anon.dcm --profile basic --regenerate-uids
```

### Batch Processing

```bash
# Anonymize entire directory recursively
dicom-anon input_dir/ --output anon_dir/ --profile clinical-trial --recursive

# With verbose output
dicom-anon input_dir/ --output anon_dir/ --profile basic --recursive --verbose
```

### Custom Anonymization

```bash
# Remove specific tags
dicom-anon file.dcm --output anon.dcm --remove 0010,0010 --remove PatientID

# Replace specific tags with values
dicom-anon file.dcm --output anon.dcm --replace 0010,0030=19700101

# Keep specific tags from being anonymized
dicom-anon file.dcm --output anon.dcm --profile basic --keep Modality --keep StudyDescription
```

### Audit Logging

```bash
# Generate audit log for compliance
dicom-anon file.dcm --output anon.dcm --profile basic --audit-log anonymization.log

# Review audit log
cat anonymization.log
```

### Backup and Safety

```bash
# Create backup before anonymization
dicom-anon file.dcm --output anon.dcm --profile basic --backup

# Force parsing of non-standard DICOM files
dicom-anon file.dcm --output anon.dcm --profile basic --force
```

## Anonymization Profiles

### Basic Profile

Removes or replaces:
- Patient Name → "ANONYMOUS"
- Patient ID → Hashed value
- Patient Birth Date → Removed
- Patient Address, Phone → Removed
- Referring/Performing Physician Names → Removed
- Institution Name/Address → Removed
- Device Serial Number → Removed

### Clinical Trial Profile

Includes Basic Profile plus:
- Study/Series/Acquisition Dates → Shifted by specified offset
- Study/Series/Acquisition Times → Removed
- Preserves intervals between dates

### Research Profile

Minimal anonymization:
- Patient Name → "ANONYMOUS"
- Patient ID → Hashed value
- Patient Birth Date → Removed
- Patient Address, Phone → Removed
- Retains all clinical and study metadata

## Examples

### Example 1: Basic Anonymization

```bash
dicom-anon patient_scan.dcm --output anon_scan.dcm --profile basic
```

Output:
```
Anonymization Summary:
  Total files: 1
  Successful: 1
  Failed: 0
```

### Example 2: Clinical Trial with Date Shifting

```bash
dicom-anon study/ --output anon_study/ \
  --profile clinical-trial \
  --shift-dates 90 \
  --regenerate-uids \
  --recursive \
  --audit-log trial_anon.log \
  --verbose
```

### Example 3: Custom Anonymization

```bash
dicom-anon research.dcm --output anon_research.dcm \
  --remove PatientName \
  --remove PatientID \
  --replace InstitutionName="Research Site" \
  --keep StudyDescription \
  --keep Modality
```

## Security Considerations

1. **PHI Removal**: The tool removes Protected Health Information (PHI) according to HIPAA guidelines and DICOM Supplement 142 (Attribute Confidentiality Profiles)

2. **Private Tags**: Private tags are scanned for potential PHI and warnings are generated

3. **Burned-in Text**: The tool cannot detect or remove burned-in annotations in pixel data. Use caution with images containing burned-in patient information.

4. **Audit Trail**: Always use `--audit-log` for compliance and tracking

5. **Verification**: Always verify anonymized files before distribution using:
   ```bash
   dicom-info anon.dcm --detailed
   ```

## DICOM Supplement 142 Compliance

This tool follows DICOM Supplement 142 - Attribute Confidentiality Profiles for:
- Basic Application Level Confidentiality Profile
- Clean Pixel Data Option
- Retain Longitudinal Temporal Information with Modified Dates Option

## Exit Codes

- `0`: Success - all files anonymized successfully
- `1`: Failure - one or more files failed to anonymize

## Performance

- Single file anonymization: <100ms for typical files
- Batch processing: ~50-100 files/second
- Memory efficient: processes files individually

## Limitations

1. Cannot detect or remove burned-in text in pixel data
2. Does not modify private tags automatically (generates warnings)
3. Sequence anonymization follows main dataset rules
4. Compressed transfer syntaxes are preserved without modification

## See Also

- `dicom-info`: Display DICOM file information
- `dicom-validate`: Validate DICOM file conformance
- `dicom-convert`: Convert DICOM transfer syntaxes

## References

- DICOM Standard PS3.15 - Security and System Management Profiles
- DICOM Supplement 142 - Clinical Trial De-identification Profiles
- HIPAA Privacy Rule - De-identification of Protected Health Information

## License

Part of DICOMKit - See LICENSE file for details.
