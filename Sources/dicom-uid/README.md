# dicom-uid

DICOM UID generation, validation, and management tool.

## Features

- **Generate** new DICOM UIDs with custom roots and types
- **Validate** UIDs against DICOM PS3.5 Section 9 compliance rules
- **Look up** well-known UIDs (Transfer Syntaxes, SOP Classes) in the DICOM registry
- **Regenerate** UIDs in DICOM files while maintaining hierarchical relationships
- **Export** old→new UID mappings to JSON for tracking

## Usage

### Generate UIDs

```bash
# Generate a single UID
dicom-uid generate

# Generate 5 study UIDs
dicom-uid generate --count 5 --type study

# Generate with custom root
dicom-uid generate --root 1.2.826.0.1.3680043.9.1234

# Output as JSON
dicom-uid generate --count 3 --json
```

### Validate UIDs

```bash
# Validate a UID string
dicom-uid validate 1.2.840.10008.1.2.1

# Validate multiple UIDs
dicom-uid validate 1.2.3.4.5 1.2.3..4 1.2.3.04

# Validate all UIDs in a DICOM file
dicom-uid validate --file study.dcm

# Check registry names
dicom-uid validate 1.2.840.10008.1.2.1 --check-registry
```

### Look Up UIDs

```bash
# Look up a specific UID
dicom-uid lookup 1.2.840.10008.1.2.1

# List all known UIDs
dicom-uid lookup --list-all

# Filter by type
dicom-uid lookup --list-all --type transfer-syntax

# Search by name
dicom-uid lookup --search "CT"
```

### Regenerate UIDs

```bash
# Regenerate UIDs in a file (in-place)
dicom-uid regenerate file.dcm

# Regenerate to a new file
dicom-uid regenerate file.dcm --output new.dcm

# Batch regeneration with relationship maintenance
dicom-uid regenerate file1.dcm file2.dcm --output output_dir/ --maintain-relationships

# Export UID mapping
dicom-uid regenerate study/*.dcm --output new/ --export-map mapping.json

# Preview changes (dry run)
dicom-uid regenerate file.dcm --dry-run --verbose
```

## UID Validation Rules (PS3.5 Section 9)

- Maximum 64 characters
- Only digits (0-9) and periods (.)
- No leading or trailing periods
- No consecutive periods
- No leading zeros in components (except "0" itself)
- At least 2 components

## Version

1.3.2
