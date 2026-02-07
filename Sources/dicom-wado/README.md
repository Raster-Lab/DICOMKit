# dicom-wado

DICOMweb client for RESTful DICOM operations supporting WADO-RS, QIDO-RS, STOW-RS, and UPS-RS protocols.

## Overview

`dicom-wado` provides a comprehensive command-line interface to DICOMweb services, enabling RESTful HTTP/HTTPS-based access to DICOM objects without requiring traditional DICOM networking infrastructure. It's built on DICOMKit's DICOMWeb module and supports all major DICOMweb protocols.

## Features

- **WADO-RS (Web Access to DICOM Objects - RESTful)**
  - Retrieve studies, series, instances
  - Retrieve specific frames
  - Retrieve rendered images and thumbnails
  - Retrieve metadata only
  
- **QIDO-RS (Query based on ID for DICOM Objects - RESTful)**
  - Search for studies, series, instances
  - Filter by patient name, ID, dates, modality
  - Support for wildcards and date ranges
  - Multiple output formats (table, JSON, CSV)

- **STOW-RS (Store Over the Web - RESTful)**
  - Upload single or multiple DICOM files
  - Batch upload with configurable batch size
  - Targeted study storage
  - Progress tracking and error handling

- **UPS-RS (Unified Procedure Step - RESTful)**
  - Search worklist items
  - Retrieve worklist details
  - Create new worklist items
  - Update worklist state

## Installation

Build from source using Swift Package Manager:

```bash
swift build -c release
# Binary will be at: .build/release/dicom-wado
```

## Usage

### General Syntax

```bash
dicom-wado <subcommand> <server-url> [options]
```

### Subcommands

- `retrieve` - WADO-RS operations
- `query` - QIDO-RS operations
- `store` - STOW-RS operations
- `ups` - UPS-RS worklist operations

---

## WADO-RS: Retrieve Operations

### Retrieve Study

Download all instances in a study:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --output study/
```

### Retrieve Series

Download all instances in a specific series:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --series 1.2.840.113619.2.xxx.1 \
  --output series/
```

### Retrieve Instance

Download a single instance:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --series 1.2.840.113619.2.xxx.1 \
  --instance 1.2.840.113619.2.xxx.1.1 \
  --output ./
```

### Retrieve Metadata

Get metadata without pixel data:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --metadata \
  --format json
```

### Retrieve Frames

Get specific frames from a multi-frame instance:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --series 1.2.840.113619.2.xxx.1 \
  --instance 1.2.840.113619.2.xxx.1.1 \
  --frames 1,2,3 \
  --output frames/
```

### Retrieve Rendered Image

Get a rendered JPEG image:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --series 1.2.840.113619.2.xxx.1 \
  --instance 1.2.840.113619.2.xxx.1.1 \
  --rendered \
  --output ./
```

### Retrieve Thumbnail

Get a thumbnail image:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --thumbnail \
  --output ./
```

---

## QIDO-RS: Query Operations

### Search Studies

Search for studies by patient name:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --patient-name "DOE*" \
  --limit 50
```

Search by date range:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --study-date 20240101-20240131 \
  --modality CT
```

Search with specific study UID:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx
```

### Search Series

Search all series in a study:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --level series \
  --study 1.2.840.113619.2.xxx
```

Search all series by modality:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --level series \
  --modality MR
```

### Search Instances

Search instances in a series:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --level instance \
  --study 1.2.840.113619.2.xxx \
  --series 1.2.840.113619.2.xxx.1
```

### Output Formats

Table format (default):

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --patient-name "SMITH*" \
  --format table
```

JSON format:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --patient-name "SMITH*" \
  --format json > results.json
```

CSV format:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --patient-name "SMITH*" \
  --format csv > results.csv
```

---

## STOW-RS: Store Operations

### Upload Files

Upload single file:

```bash
dicom-wado store https://pacs.example.com/dicom-web file.dcm
```

Upload multiple files:

```bash
dicom-wado store https://pacs.example.com/dicom-web file1.dcm file2.dcm file3.dcm
```

Upload all files in directory:

```bash
dicom-wado store https://pacs.example.com/dicom-web study/*.dcm
```

### Batch Upload

Upload with custom batch size:

```bash
dicom-wado store https://pacs.example.com/dicom-web \
  --input file_list.txt \
  --batch 20 \
  --verbose
```

### Targeted Storage

Store to specific study:

```bash
dicom-wado store https://pacs.example.com/dicom-web \
  file1.dcm file2.dcm \
  --study 1.2.840.113619.2.xxx
```

### Error Handling

Continue on errors:

```bash
dicom-wado store https://pacs.example.com/dicom-web \
  study/*.dcm \
  --continue-on-error \
  --verbose
```

---

## UPS-RS: Worklist Operations

### Search Worklist

Search all worklist items:

```bash
dicom-wado ups https://pacs.example.com/dicom-web --search
```

Filter by state:

```bash
dicom-wado ups https://pacs.example.com/dicom-web \
  --search \
  --filter-state SCHEDULED
```

Filter by station:

```bash
dicom-wado ups https://pacs.example.com/dicom-web \
  --search \
  --scheduled-station CT_STATION_1
```

### Get Worklist Item

Retrieve specific worklist item:

```bash
dicom-wado ups https://pacs.example.com/dicom-web \
  --get 1.2.840.113619.2.xxx
```

### Create Worklist Item

Create from JSON file:

```bash
dicom-wado ups https://pacs.example.com/dicom-web \
  --create worklist.json
```

Example `worklist.json`:

```json
{
  "00741000": {
    "vr": "SQ",
    "Value": [{
      "00741002": { "vr": "SH", "Value": ["CT_SCAN_001"] },
      "00741004": { "vr": "CS", "Value": ["SCHEDULED"] },
      "00741224": { "vr": "SQ", "Value": [{ ... }] }
    }]
  }
}
```

### Update Worklist State

Change worklist item state:

```bash
dicom-wado ups https://pacs.example.com/dicom-web \
  --update 1.2.840.113619.2.xxx \
  --state IN_PROGRESS
```

Valid states:
- `SCHEDULED`
- `IN_PROGRESS`
- `COMPLETED`
- `CANCELED`

---

## Authentication

### OAuth2 Bearer Token

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --token "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Token can be set via environment variable:

```bash
export DICOMWEB_TOKEN="your-token-here"
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --token "$DICOMWEB_TOKEN"
```

---

## Common Options

### Verbose Output

Show detailed progress and debug information:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --verbose
```

### Timeout Configuration

Set custom timeout (in seconds):

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --timeout 120
```

---

## Examples

### Complete Workflow Example

1. Query for studies:

```bash
dicom-wado query https://pacs.example.com/dicom-web \
  --patient-name "SMITH^JOHN" \
  --study-date 20240101-20240131 \
  --format json > studies.json
```

2. Extract study UID from results and retrieve:

```bash
STUDY_UID="1.2.840.113619.2.xxx"
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study $STUDY_UID \
  --output "studies/$STUDY_UID/" \
  --verbose
```

3. Upload processed results:

```bash
dicom-wado store https://pacs.example.com/dicom-web \
  processed/*.dcm \
  --batch 10 \
  --verbose
```

### Metadata-Only Retrieval

Retrieve study metadata for processing:

```bash
dicom-wado retrieve https://pacs.example.com/dicom-web \
  --study 1.2.840.113619.2.xxx \
  --metadata \
  --format json | jq '.[] | .["00100010"]'
```

### Thumbnail Gallery

Download thumbnails for all series in a study:

```bash
#!/bin/bash
STUDY_UID="1.2.840.113619.2.xxx"

# Query series
SERIES=$(dicom-wado query https://pacs.example.com/dicom-web \
  --level series \
  --study $STUDY_UID \
  --format json | jq -r '.[].["0020000E"].Value[0]')

# Download thumbnail for each series
for SERIES_UID in $SERIES; do
  dicom-wado retrieve https://pacs.example.com/dicom-web \
    --study $STUDY_UID \
    --series $SERIES_UID \
    --thumbnail \
    --output thumbnails/
done
```

---

## Error Handling

The tool provides detailed error messages and appropriate exit codes:

- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Invalid arguments

HTTP errors are reported with status codes:
- 400: Bad Request
- 401: Unauthorized
- 404: Not Found
- 500: Internal Server Error

Example error output:

```
Error: Study not found
HTTP 404: The requested study does not exist on the server
```

---

## Performance Tips

1. **Use batch operations** for bulk uploads to reduce overhead
2. **Retrieve metadata first** to plan selective downloads
3. **Use appropriate timeouts** for large studies
4. **Enable verbose mode** to monitor progress on long operations
5. **Use JSON format** for programmatic processing of results

---

## Limitations

- XML metadata format not yet implemented (use JSON)
- Requires macOS 10.15 or later for async/await support
- HTTPS certificate validation follows system settings

---

## Related Tools

- `dicom-query` - Traditional DICOM C-FIND queries
- `dicom-send` - Traditional DICOM C-STORE operations
- `dicom-retrieve` - Traditional DICOM C-MOVE/C-GET operations
- `dicom-qr` - Integrated query-retrieve workflow

---

## Standards Reference

- **DICOM PS3.18**: Web Services (DICOMweb specification)
- **WADO-RS**: Section 10.4 - Web Access to DICOM Objects
- **QIDO-RS**: Section 10.6 - Query based on ID for DICOM Objects
- **STOW-RS**: Section 10.5 - Store Over the Web
- **UPS-RS**: Section 11 - Unified Procedure Step

---

## Version

Version 1.0.0 - Part of DICOMKit CLI Tools Phase 5
