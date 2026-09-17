# dicom-mwl - DICOM Modality Worklist Management

Query DICOM Modality Worklist items from worklist SCP servers.

## Features

- Query Modality Worklist (C-FIND) from PACS/RIS servers
- Filter by date, time, station AET, patient name, patient ID, and modality
- Date and time filters support DICOM Range Matching (PS3.4 C.2.2.2.5), including
  open-ended ranges, and combined date+time interval queries (PS3.4 K.6.1)
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

Query a date range (both bounds inclusive):
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date 20240705-20240707
```

Query an open-ended date range (everything from today onward):
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date today-
```

A range that *starts* with a hyphen must use the `--date=` form, otherwise the
argument parser treats the value as another flag:
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date=-20240707
```

> **Note:** Open-ended ranges (`YYYYMMDD-` / `-YYYYMMDD`) are valid DICOM, but not
> every MWL SCP implements them. dcm4chee, for example, rejects them with
> `0x0110 Unable to process`. Closed ranges (`YYYYMMDD-YYYYMMDD`) are the most
> portable form — use `20240707-20240707` in place of a single-day open range.

Query a combined date+time range as one continuous interval (PS3.4 K.6.1) —
July 5 10:00 through July 7 18:00:
```bash
dicom-mwl query pacs://server:11112 --aet MODALITY \
  --date 20240705-20240707 --time 1000-1800
```

## Options

- `--aet`: Local Application Entity Title (required)
- `--called-aet`: Remote Application Entity Title (default: ANY-SCP)
- `--date`: Scheduled date filter — `YYYYMMDD`, `'today'`, `'tomorrow'` (Single Value
  Matching), or a DICOM date range `YYYYMMDD-YYYYMMDD`, `YYYYMMDD-`, `-YYYYMMDD`
  (Range Matching, both bounds inclusive; `today`/`tomorrow` may be used as a bound)
- `--time`: Scheduled time filter — `HHMMSS` (Single Value Matching), or a DICOM time
  range `HHMMSS-HHMMSS`, `HHMMSS-`, `-HHMMSS` (Range Matching). When both `--date` and
  `--time` are ranges, the SCP is expected to interpret them as one continuous
  date-time interval per PS3.4 K.6.1 rather than independent filters.
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
