# dicom-mwl - DICOM Modality Worklist Management

Query DICOM Modality Worklist items from worklist SCP servers.

## Features

- Query Modality Worklist (C-FIND) from PACS/RIS servers
- Filter by date, station AET, patient name, patient ID, and modality
- JSON output support for automation
- Verbose mode for detailed attribute display

## Usage

### Query Worklist

Query worklist items for today:
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY --date today
```

Query with multiple filters:
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date 20240315 \
  --station CT1 \
  --patient "DOE^JOHN*" \
  --modality CT
```

Query with verbose output:
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date today \
  --verbose
```

Query with JSON output:
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date today \
  --json
```

## Options

- `--aet`: Local Application Entity Title (required)
- `--called-aet`: Remote Application Entity Title (default: ANY-SCP)
- `--date`: Scheduled date filter (YYYYMMDD, 'today', or 'tomorrow')
- `--station`: Scheduled Station AE Title filter
- `--patient`: Patient name filter (supports wildcards: *)
- `--patient-id`: Patient ID filter
- `--modality`: Modality filter (e.g., CT, MR, US)
- `--timeout`: Connection timeout in seconds (default: 60)
- `-v, --verbose`: Show verbose output with all attributes
- `--json`: Output results as JSON

## DICOM Reference

Implements PS3.4 Annex K - Modality Worklist Information Model

SOP Class UID: 1.2.840.10008.5.1.4.31
