# dicom-json

Convert between DICOM and JSON formats using the DICOM JSON Model (PS3.18 Section F).

## Description

`dicom-json` is a command-line tool for converting DICOM files to JSON format and back. It implements the DICOM JSON Model as specified in PS3.18 Section F, providing interoperability with DICOMweb services and other JSON-based tools.

## Features

- **Bidirectional Conversion**: Convert DICOM → JSON and JSON → DICOM
- **DICOM JSON Model**: Full compliance with PS3.18 Section F
- **DICOMweb Format**: Support for DICOMweb JSON format
- **Bulk Data Handling**: Inline binary data or URI references
- **Pretty Printing**: Human-readable JSON output
- **Metadata Filtering**: Extract specific tags only
- **Large File Support**: Streaming mode for efficient processing
- **Performance**: Fast conversion with detailed timing information

## Installation

```bash
swift build -c release
cp .build/release/dicom-json /usr/local/bin/
```

## Usage

### Basic Conversion

Convert DICOM to JSON:
```bash
dicom-json file.dcm --output file.json
```

Convert JSON to DICOM:
```bash
dicom-json file.json --output file.dcm --reverse
```

### Pretty-Printed JSON

Output formatted JSON for readability:
```bash
dicom-json file.dcm --output file.json --pretty
```

### DICOMweb Format

Use DICOMweb-compatible JSON format:
```bash
dicom-json file.dcm --output file.json --format dicomweb
```

### Metadata Only

Exclude pixel data from conversion:
```bash
dicom-json large-image.dcm --output metadata.json --metadata-only
```

### Bulk Data Handling

Configure inline binary threshold:
```bash
# Inline binary data up to 2KB
dicom-json file.dcm --output file.json --inline-threshold 2048

# Always use bulk data URIs
dicom-json file.dcm --output file.json --inline-threshold 0 --bulk-data-url "http://example.com/bulk"
```

### Filter Specific Tags

Extract only specific tags:
```bash
# By tag name
dicom-json file.dcm --output metadata.json --filter-tag PatientName --filter-tag StudyDate

# By tag hex (GGGG,EEEE)
dicom-json file.dcm --output metadata.json --filter-tag 0010,0010 --filter-tag 0008,0020
```

### Streaming Mode

Process large files efficiently:
```bash
dicom-json large-study.dcm --output large-study.json --stream
```

### Verbose Output

Show detailed timing and statistics:
```bash
dicom-json file.dcm --output file.json --verbose
```

## Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output file path (default: input with .json or .dcm extension) |
| `-r, --reverse` | Convert from JSON to DICOM |
| `-p, --pretty` | Pretty-print JSON output |
| `--sort-keys` | Sort JSON keys alphabetically (default: true) |
| `--format <format>` | JSON format: standard or dicomweb (default: standard) |
| `--include-empty` | Include empty values in JSON |
| `--inline-threshold <bytes>` | Inline binary data up to this size (default: 1024) |
| `--bulk-data-url <url>` | Base URL for bulk data URIs |
| `--stream` | Use streaming for large files |
| `--metadata-only` | Only include metadata (exclude pixel data) |
| `--filter-tag <tag>` | Filter tags by name or hex (can be used multiple times) |
| `--verbose` | Show detailed timing and statistics |
| `--version` | Show version information |
| `--help` | Show help message |

## Examples

### Convert CT Image to JSON

```bash
dicom-json ct-scan.dcm --output ct-scan.json --pretty
```

### Convert Multiple Files

```bash
for file in *.dcm; do
    dicom-json "$file" --output "${file%.dcm}.json"
done
```

### Extract Patient Demographics

```bash
dicom-json patient.dcm --output demographics.json \
    --filter-tag PatientName \
    --filter-tag PatientID \
    --filter-tag PatientBirthDate \
    --filter-tag PatientSex \
    --pretty
```

### Roundtrip Conversion

```bash
# DICOM → JSON → DICOM
dicom-json original.dcm --output temp.json
dicom-json temp.json --output restored.dcm --reverse
```

### Large Study with Bulk Data URIs

```bash
dicom-json large-study.dcm --output large-study.json \
    --inline-threshold 0 \
    --bulk-data-url "http://pacs.example.com/bulk" \
    --stream \
    --verbose
```

## JSON Format

The tool outputs DICOM JSON format as specified in PS3.18 Section F. Each DICOM tag is represented as:

```json
{
  "00100010": {
    "vr": "PN",
    "Value": [
      {
        "Alphabetic": "Doe^John"
      }
    ]
  },
  "00100020": {
    "vr": "LO",
    "Value": ["123456"]
  }
}
```

### Bulk Data

Binary data can be inline (Base64) or referenced:

```json
{
  "7FE00010": {
    "vr": "OB",
    "InlineBinary": "AQIDBAU="
  }
}
```

Or:

```json
{
  "7FE00010": {
    "vr": "OB",
    "BulkDataURI": "http://example.com/bulk/1.2.3.4.5"
  }
}
```

## Performance

Typical conversion times on modern hardware:

- Small image (512×512, ~500KB): 10-50ms
- Medium image (1024×1024, ~2MB): 50-200ms
- Large image (2048×2048, ~8MB): 200-500ms
- CT series (100 slices, ~100MB): 2-5s with streaming

## Error Handling

The tool provides clear error messages for common issues:

- **File not found**: Validates input file exists
- **Invalid JSON**: Reports JSON parsing errors
- **Invalid DICOM**: Reports DICOM parsing errors
- **Invalid tags**: Validates tag format for filtering
- **Write errors**: Reports file write failures

## Exit Codes

- `0`: Success
- `1`: Error occurred

## Related Tools

- `dicom-info`: Display DICOM metadata
- `dicom-dump`: Dump DICOM file structure
- `dicom-xml`: Convert DICOM to/from XML
- `dicom-validate`: Validate DICOM files

## References

- DICOM PS3.18 Section F - DICOM JSON Model
- DICOM PS3.5 - Data Structures and Encoding
- DICOMweb Standard (QIDO-RS, WADO-RS, STOW-RS)

## Version

1.1.3 - Part of DICOMKit Phase 3 CLI Tools
