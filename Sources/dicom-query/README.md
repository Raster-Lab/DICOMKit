# dicom-query

Query DICOM servers using C-FIND and QIDO-RS protocols.

## Overview

`dicom-query` is a command-line tool for querying DICOM PACS servers to find patients, studies, series, and instances. It supports the standard DICOM C-FIND service over TCP/IP and provides multiple output formats for different use cases.

## Features

- **Multiple Query Levels**: Patient, Study, Series, and Instance queries
- **Flexible Filters**: Filter by patient name, ID, study date, modality, and more
- **Multiple Output Formats**: Table (default), JSON, CSV, and compact formats
- **Wildcard Support**: Use * and ? in patient names and descriptions
- **Date Range Queries**: Query by date ranges (e.g., 20240101-20240131)
- **PACS Protocol**: Standard DICOM C-FIND over TCP/IP

## Installation

Build from source:

```bash
swift build -c release --target dicom-query
```

The executable will be available at:
`.build/release/dicom-query`

## Usage

### Basic Syntax

```bash
dicom-query <url> --aet <calling-ae> [options]
```

### URL Format

- **PACS (C-FIND)**: `pacs://hostname:port`
  - Default port: 104 (if not specified)
  
### Required Options

- `--aet <string>`: Your Application Entity Title (calling AE)

### Query Level Options

- `--level <level>`: Query level (default: study)
  - `patient`: Patient-level query
  - `study`: Study-level query
  - `series`: Series-level query
  - `instance`: Instance-level query

### Filter Options

- `--patient-name <name>`: Patient name (wildcards * and ? supported)
- `--patient-id <id>`: Patient ID
- `--study-date <date>`: Study date or range (YYYYMMDD or YYYYMMDD-YYYYMMDD)
- `--study-uid <uid>`: Study Instance UID
- `--series-uid <uid>`: Series Instance UID
- `--accession-number <number>`: Accession number
- `--modality <modality>`: Modality (e.g., CT, MR, US)
- `--study-description <description>`: Study description (wildcards supported)
- `--referring-physician <name>`: Referring physician name

### Output Options

- `--format <format>`: Output format (default: table)
  - `table`: Human-readable table format
  - `json`: JSON format for scripting
  - `csv`: CSV format for spreadsheets
  - `compact`: Compact one-line format
- `--verbose`: Show detailed query information

### Connection Options

- `--called-aet <string>`: Remote Application Entity Title (default: ANY-SCP)
- `--timeout <seconds>`: Connection timeout in seconds (default: 60)

## Examples

### Query by Patient Name

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --patient-name "SMITH^JOHN"
```

### Query by Date Range

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --study-date 20240101-20240131
```

### Query by Modality

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --modality CT
```

### Wildcard Search

```bash
# Find all patients whose name starts with "DOE"
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --patient-name "DOE*"

# Find all CT chest studies
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --modality CT \
  --study-description "*CHEST*"
```

### JSON Output for Scripting

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --patient-name "SMITH*" \
  --format json > results.json
```

### CSV Output for Spreadsheets

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --study-date 20240101-20241231 \
  --format csv > studies.csv
```

### Patient-Level Query

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --level patient \
  --patient-name "DOE*"
```

### Series-Level Query

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --level series \
  --study-uid 1.2.840.113619.2.55.3.4 \
  --modality MR
```

### Instance-Level Query

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --level instance \
  --study-uid 1.2.840.113619.2.55.3.4 \
  --series-uid 1.2.840.113619.2.55.3.5
```

### Verbose Output

```bash
dicom-query pacs://pacs.hospital.com:11112 \
  --aet MY_SCU \
  --patient-name "SMITH*" \
  --verbose
```

This will show connection details and query filters:

```
Connecting to: pacs.hospital.com:11112
Calling AE: MY_SCU
Called AE: ANY-SCP
Query Level: STUDY

Query filters:
  (0010,0010) Patient's Name: SMITH*
  (0010,0020) Patient ID: (return)
  (0020,000D) Study Instance UID: (return)
  ...

Found 42 result(s)
```

## Output Formats

### Table Format (Default)

Human-readable table with aligned columns:

```
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Patient Name              Patient ID   Date         Description                    Modalities   Series  
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
SMITH^JOHN                12345        2024-02-15   CT CHEST W/ CONTRAST           CT           3       
DOE^JANE                  67890        2024-02-16   MR BRAIN W/WO CONTRAST         MR           5       
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Total: 2 study(ies)
```

### JSON Format

Structured JSON output for scripting:

```json
[
  {
    "(0010,0010) Patient's Name": "SMITH^JOHN",
    "(0010,0020) Patient ID": "12345",
    "(0008,0020) Study Date": "20240215",
    "(0008,1030) Study Description": "CT CHEST W/ CONTRAST",
    "(0020,000D) Study Instance UID": "1.2.840.113619.2.55.3.4"
  }
]
```

### CSV Format

CSV output for spreadsheet import:

```csv
"(0008,0020) Study Date","(0008,1030) Study Description","(0010,0010) Patient's Name","(0010,0020) Patient ID","(0020,000D) Study Instance UID"
20240215,"CT CHEST W/ CONTRAST","SMITH^JOHN",12345,1.2.840.113619.2.55.3.4
20240216,"MR BRAIN W/WO CONTRAST","DOE^JANE",67890,1.2.840.113619.2.55.3.5
```

### Compact Format

One-line format for quick parsing:

```
SMITH^JOHN | 12345 | 20240215 | CT CHEST W/ CONTRAST | 1.2.840.113619.2.55.3.4
DOE^JANE | 67890 | 20240216 | MR BRAIN W/WO CONTRAST | 1.2.840.113619.2.55.3.5
```

## DICOM Query Matching

### Wildcard Support

DICOM supports two wildcard characters:

- `*`: Matches zero or more characters
- `?`: Matches exactly one character

Examples:
- `"SMITH*"`: Matches SMITH, SMITHSON, SMITH-JONES
- `"SM?TH"`: Matches SMITH, SMYTH
- `"*CHEST*"`: Matches anything containing CHEST

### Date Range Queries

Date ranges use the format: `YYYYMMDD-YYYYMMDD`

Examples:
- `20240101-20240131`: January 2024
- `20240101-20241231`: All of 2024
- `20240215`: Exact date (February 15, 2024)

### Empty Values

If you don't specify a filter, the attribute will be returned in results but won't be used for matching. This allows you to retrieve all values while still filtering on other criteria.

## Exit Codes

- `0`: Success
- `1`: Validation error (invalid arguments)
- `2`: Connection error or query failed

## Limitations

- **QIDO-RS Support**: HTTP/HTTPS URLs for QIDO-RS are planned but not yet implemented
- **TLS/SSL**: Secure DICOM connections are not yet supported
- **Authentication**: User authentication is not yet supported
- **Large Result Sets**: Very large result sets (>10,000) may be slow

## Requirements

- macOS 14.0+ or Linux
- Network access to DICOM PACS server
- Valid Application Entity Title (AE Title) configured on PACS

## Related Tools

- `dicom-info`: Display metadata from DICOM files
- `dicom-retrieve`: Retrieve DICOM files from PACS (coming soon)
- `dicom-send`: Send DICOM files to PACS (coming soon)

## Technical Details

### DICOM Standards

This tool implements:
- **PS3.4 Section C**: Query/Retrieve Service Class
- **PS3.7 Section 9.1.2**: C-FIND DIMSE Service
- **PS3.3 Section C.6**: Query/Retrieve Information Models

### Information Model

Uses the Study Root Query/Retrieve Information Model by default, which supports:
- PATIENT level (top)
- STUDY level
- SERIES level
- IMAGE level (instance, bottom)

### Network Protocol

Standard DICOM Upper Layer Protocol over TCP/IP:
1. Association Request (A-ASSOCIATE-RQ)
2. Association Accept (A-ASSOCIATE-AC)
3. C-FIND Request (C-FIND-RQ) with query identifier
4. C-FIND Response (C-FIND-RSP) for each match (status: Pending)
5. C-FIND Response (status: Success) when complete
6. Association Release (A-RELEASE-RQ/RP)

## Troubleshooting

### Connection Refused

```
Error: Connection refused
```

**Solutions:**
- Verify the PACS hostname and port
- Check firewall settings
- Ensure PACS is running and accepting connections
- Verify your IP is allowed by PACS firewall

### Association Rejected

```
Error: Association rejected
```

**Solutions:**
- Verify your AE Title is configured on the PACS
- Check the called AE Title (use `--called-aet` if different from default)
- Contact PACS administrator to register your AE Title

### No Results

If your query returns no results:
- Check filter criteria (are they too restrictive?)
- Try broader wildcards (e.g., `"*"` returns all)
- Verify data exists in PACS using PACS UI
- Check query level is appropriate

### Timeout

```
Error: Connection timeout
```

**Solutions:**
- Increase timeout: `--timeout 120`
- Check network connectivity
- Verify PACS is responding

## License

Part of DICOMKit - see repository LICENSE file.

## Contributing

Contributions welcome! Please see the main DICOMKit repository for guidelines.
