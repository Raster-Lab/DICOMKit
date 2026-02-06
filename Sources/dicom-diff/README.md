# dicom-diff - DICOM File Comparison Tool

A command-line tool for comparing two DICOM files and reporting differences in metadata tags and pixel data.

## Features

- **Tag Comparison**: Compare all metadata tags between two files
- **Pixel Data Comparison**: Optional comparison of pixel data with tolerance
- **Multiple Output Formats**: text, JSON, summary
- **Flexible Filtering**: Ignore specific tags or all private tags
- **Detailed Reports**: Show differences, additions, deletions
- **Exit Codes**: Returns 0 for identical files, 1 for differences

## Installation

Build from source:

```bash
cd DICOMKit
swift build -c release
.build/release/dicom-diff --help
```

## Usage

### Basic Comparison

```bash
# Compare two DICOM files
dicom-diff file1.dcm file2.dcm

# Compare with verbose output
dicom-diff --verbose file1.dcm file2.dcm
```

### Output Formats

```bash
# Text output (default) - human-readable
dicom-diff file1.dcm file2.dcm

# JSON output - for automation
dicom-diff --format json file1.dcm file2.dcm > diff.json

# Summary output - compact overview
dicom-diff --format summary file1.dcm file2.dcm
```

### Filtering Options

```bash
# Ignore specific tags by hex notation
dicom-diff --ignore-tag 0008,0012 file1.dcm file2.dcm

# Ignore by tag keyword
dicom-diff --ignore-tag SOPInstanceUID file1.dcm file2.dcm

# Ignore multiple tags
dicom-diff \
  --ignore-tag 0008,0012 \
  --ignore-tag 0008,0013 \
  --ignore-tag SOPInstanceUID \
  file1.dcm file2.dcm

# Ignore all private tags
dicom-diff --ignore-private file1.dcm file2.dcm
```

### Pixel Data Comparison

```bash
# Compare pixel data
dicom-diff --compare-pixels file1.dcm file2.dcm

# With tolerance for minor differences
dicom-diff --compare-pixels --tolerance 5 original.dcm processed.dcm

# Quick mode - skip pixel data
dicom-diff --quick file1.dcm file2.dcm
```

### Advanced Options

```bash
# Show identical tags in output
dicom-diff --show-identical file1.dcm file2.dcm
```

## Output Examples

### Text Output (Default)

```
=== DICOM Comparison Results ===

Total tags compared: 45
Differences found: 3
Tags only in file 1: 0
Tags only in file 2: 1
Modified tags: 2

Pixel Data: IDENTICAL

--- Tags only in file2.dcm ---
[(0010,1030)] Patient's Weight: 75

--- Modified Tags ---

[(0008,0020)] Study Date
  File 1: 20240101
  File 2: 20240102

[(0010,0010)] Patient's Name
  File 1: SMITH^JOHN
  File 2: DOE^JANE

=== End of Comparison ===
```

### JSON Output

```json
{
  "files": {
    "file1": "scan1.dcm",
    "file2": "scan2.dcm"
  },
  "summary": {
    "totalTags": 45,
    "differences": 3,
    "hasDifferences": true
  },
  "onlyInFile1": [],
  "onlyInFile2": [
    {
      "tag": "(0010,1030)",
      "value": "75"
    }
  ],
  "modified": [
    {
      "tag": "(0008,0020)",
      "tagName": "Study Date",
      "value1": "20240101",
      "value2": "20240102"
    }
  ]
}
```

### Summary Output

```
Files: DIFFERENT
Differences: 3
  Only in file 1: 0
  Only in file 2: 1
  Modified: 2
Pixel data: IDENTICAL
```

## Exit Codes

- **0**: Files are identical (no differences found)
- **1**: Files are different (differences found)
- **64**: Usage error (invalid arguments)

This makes the tool suitable for use in scripts and automated workflows:

```bash
#!/bin/bash
if dicom-diff original.dcm new.dcm > /dev/null 2>&1; then
    echo "Files are identical"
else
    echo "Files differ"
    dicom-diff original.dcm new.dcm
fi
```

## Common Use Cases

### 1. Verify Anonymization

```bash
# Check that only expected tags changed
dicom-diff original.dcm anonymized.dcm \
  --ignore-tag PatientName \
  --ignore-tag PatientID \
  --ignore-tag PatientBirthDate
```

### 2. Validate Image Processing

```bash
# Ensure pixel data changed but metadata preserved
dicom-diff --compare-pixels --tolerance 10 original.dcm filtered.dcm
```

### 3. Check Transfer Syntax Conversion

```bash
# Verify pixel data integrity after conversion
dicom-diff --compare-pixels original.dcm converted.dcm
```

### 4. CI/CD Validation

```bash
# Ensure DICOM files haven't changed unexpectedly
dicom-diff --format json expected.dcm actual.dcm > diff.json
if [ $? -ne 0 ]; then
    echo "DICOM file validation failed"
    exit 1
fi
```

## Limitations

- **Pixel Data Comparison**: Currently performs simple byte-wise comparison. Does not account for different encodings or transfer syntaxes.
- **Large Files**: Loads entire files into memory. May be slow for very large files.
- **Sequence Comparison**: Compares sequences recursively but may be slow for deeply nested structures.

## Implementation Notes

- Built with DICOMKit for DICOM parsing
- Uses ArgumentParser for CLI interface
- Supports Swift 6 strict concurrency
- Zero external dependencies beyond DICOMKit

## Version

1.0.0 - Initial release

## See Also

- `dicom-info` - Display DICOM metadata
- `dicom-validate` - Validate DICOM conformance
- `dicom-dump` - Hexadecimal file inspection
