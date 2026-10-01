# dicom-anon

A command-line tool for anonymizing DICOM files to protect patient privacy.

## Features

- **Multiple Anonymization Profiles**:
  - **`ps315`**: the PS3.15 Basic Application Level Confidentiality Profile (every row of
    PS3.15 Table E.1-1) with the Options selected by the `--retain-*` / `--clean-*` flags;
    records Patient Identity Removed (0012,0062), De-identification Method (0012,0063) and
    De-identification Method Code Sequence (0012,0064)
  - **`basic`, `clinical-trial`, `research`** (legacy, the default is `basic`): fixed attribute
    lists, **not** the PS3.15 Basic Profile and not any PS3.15 Profile + Options set; they record
    no (0012,0062)
  - **Custom**: User-defined tag removal and replacement

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

### `ps315` — PS3.15 Basic Application Level Confidentiality Profile

Applies the Basic Profile action (D, Z, X, K, C, U) of every row of PS3.15 Table E.1-1, removes
private attributes, curve data and overlay data/comments, and replaces UIDs consistently. The
Options (PS3.15 E.3) and the PS3.16 CID 7050 code each one records in (0012,0064):

| Flag | PS3.15 E.3 Option | CID 7050 |
|---|---|---|
| (always) | Basic Application Level Confidentiality Profile | 113100 |
| `--clean-pixel-data` (all profiles) | Clean Pixel Data Option; sets Burned In Annotation (0028,0301) to NO | 113101 |
| `--clean-descriptors` | Clean Descriptors Option (the descriptors are kept as they are, **not** cleaned — review them) | 113105 |
| `--retain-full-dates`, or `--retain-dates` | Retain Longitudinal Temporal Information With Full Dates Option | 113106 |
| `--retain-modified-dates --shift-dates N`, or `--retain-dates --shift-dates N` | Retain Longitudinal Temporal Information With Modified Dates Option | 113107 |
| `--retain-characteristics` | Retain Patient Characteristics Option | 113108 |
| `--retain-device` | Retain Device Identity Option | 113109 |
| `--retain-uids` | Retain UIDs Option | 113110 |
| `--retain-institution` | Retain Institution Identity Option | 113112 |

Not offered: Clean Recognizable Visual Features (113102), Clean Graphics (113103), Clean
Structured Content (113104), Retain Safe Private (113111). The two Retain Longitudinal Temporal
Information Options are mutually exclusive (E.3.6). The Option flags act only on `--profile
ps315` (they are refused with the legacy profiles), as do `--allow-burned-in-phi`; `--keep` is
refused with `ps315`. `--remove` and `--replace` are applied after the Profile.

`--dry-run` and `--verbose` list each changed attribute with its PS3.6 name and the PS3.15
Table E.1-1a code; `--audit-log` writes the same list (without values).

```bash
dicom-anon file.dcm --output anon.dcm --profile ps315 --retain-modified-dates --shift-dates -100
```

### Basic Profile (legacy `basic`)

Not the PS3.15 Basic Profile: of the 647 data-set rows of PS3.15 Table E.1-1 it handles 11.
Removes or replaces:
- Patient Name → "ANONYMOUS"
- Patient ID → Hashed value
- Patient Birth Date, Patient Birth Time → Removed
- Other Patient IDs, Other Patient Names, Patient Comments → Removed
- Referring Physician's Name, Performing Physician's Name, Operators' Name → Removed
- Institution Name/Address → Removed
- Station Name, Device Serial Number → Removed

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
- Retains everything else

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

1. **PHI Removal**: With `--profile ps315` the tool applies PS3.15 Annex E (which incorporates Supplement 142); the legacy profiles remove only their fixed attribute lists

2. **Private Tags**: Private tags are scanned for potential PHI and warnings are generated

3. **Burned-in Text**: Without `--clean-pixel-data` burned-in annotations in pixel data are not removed. With `--profile ps315`, a file whose Burned In Annotation (0028,0301) is YES or that has overlay planes is refused unless `--clean-pixel-data` or `--allow-burned-in-phi` is given.

4. **Audit Trail**: Always use `--audit-log` for compliance and tracking

5. **Verification**: Always verify anonymized files before distribution using:
   ```bash
   dicom-info anon.dcm --detailed
   ```

## PS3.15 Annex E (2026a)

`--profile ps315` implements the Basic Application Level Confidentiality Profile and the Options
in the table above. Not yet recorded: Longitudinal Temporal Information Modified (0028,0303).

## Exit Codes

- `0`: Success - all files anonymized successfully
- `1`: Failure - one or more files failed to anonymize

## Performance

- Single file anonymization: <100ms for typical files
- Batch processing: ~50-100 files/second
- Memory efficient: processes files individually

## Limitations

1. Burned-in text is removed only with `--clean-pixel-data` (region chosen automatically or by `--redact-region`)
2. Legacy profiles do not remove private tags (they generate warnings); `ps315` removes them
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
