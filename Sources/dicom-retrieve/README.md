# dicom-retrieve

Retrieve DICOM files from PACS servers using C-MOVE or C-GET protocols.

## Features

- **C-MOVE Support**: Traditional DICOM retrieval with move destination
- **C-GET Support**: Direct retrieval without separate SCP
- **Multi-Level Operations**: Retrieve studies, series, or individual instances
- **Bulk Retrieval**: Process multiple study UIDs from a file
- **Parallel Operations**: Concurrent retrieval for improved performance
- **Progress Tracking**: Real-time progress updates during retrieval
- **Flexible Organization**: Hierarchical or flat file structure
- **Error Handling**: Automatic retry logic and comprehensive error reporting

## Usage

### Basic Study Retrieval (C-MOVE)

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --study-uid 1.2.840.113619.2.xxx \
  --output study_dir/
```

### Study Retrieval with C-GET

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --study-uid 1.2.840.113619.2.xxx \
  --method c-get \
  --output study_dir/
```

### Series Retrieval

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --study-uid 1.2.840.113619.2.xxx \
  --series-uid 1.2.840.113619.2.yyy \
  --output series_dir/
```

### Instance Retrieval

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --study-uid 1.2.840.113619.2.xxx \
  --series-uid 1.2.840.113619.2.yyy \
  --instance-uid 1.2.840.113619.2.zzz \
  --output .
```

### Bulk Retrieval from UID List

Create a text file with one Study UID per line:

```
# study_uids.txt
1.2.840.113619.2.aaa
1.2.840.113619.2.bbb
1.2.840.113619.2.ccc
```

Then retrieve all studies:

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --uid-list study_uids.txt \
  --output studies/ \
  --parallel 4
```

### Hierarchical Organization

Organize retrieved files by study and series:

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --method c-get \
  --study-uid 1.2.840.113619.2.xxx \
  --output output/ \
  --hierarchical
```

This creates a structure like:
```
output/
  ├── 1.2.840.113619.2.xxx/
  │   ├── 1.2.840.113619.2.yyy/
  │   │   ├── 1.2.840.113619.2.zzz.dcm
  │   │   └── ...
  │   └── 1.2.840.113619.2.www/
  │       └── ...
```

### Verbose Output

```bash
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --method c-get \
  --study-uid 1.2.840.113619.2.xxx \
  --output study/ \
  --verbose
```

## Options

- `url` - PACS server URL (pacs://hostname:port)
- `--aet` - Local Application Entity Title (calling AE)
- `--called-aet` - Remote Application Entity Title (default: ANY-SCP)
- `--study-uid` - Study Instance UID to retrieve
- `--series-uid` - Series Instance UID to retrieve (requires --study-uid)
- `--instance-uid` - SOP Instance UID to retrieve (requires --study-uid and --series-uid)
- `--uid-list` - File containing list of Study UIDs (one per line)
- `--output` - Output directory for retrieved files (default: current directory)
- `--method` - Retrieval method: c-move or c-get (default: c-move)
- `--move-dest` - Move destination AE title (required for C-MOVE)
- `--hierarchical` - Organize output hierarchically (patient/study/series)
- `--timeout` - Connection timeout in seconds (default: 60)
- `--parallel` - Number of parallel retrieval operations (default: 1)
- `-v, --verbose` - Show verbose output including progress

## C-MOVE vs C-GET

### C-MOVE
- Traditional DICOM retrieval method
- Requires a separate C-STORE SCP (move destination) to receive files
- PACS sends files to the move destination, not directly to the requester
- Useful when retrieving to a different system

### C-GET
- Direct retrieval method
- Files are sent directly to the requester (no separate destination needed)
- Simpler setup, but not supported by all PACS
- Recommended for direct downloads

## Requirements

- PACS server with C-MOVE or C-GET support
- Network connectivity to PACS (typically port 104 or 11112)
- For C-MOVE: A running C-STORE SCP at the move destination
- Valid AE titles configured on PACS

## Examples

### Download a complete study
```bash
dicom-retrieve pacs://pacs.hospital.org:11112 \
  --aet WORKSTATION \
  --method c-get \
  --study-uid 1.2.840.113619.2.55.3.2609895290.675.1234567890.123 \
  --output /data/studies/patient_123/ \
  --hierarchical \
  --verbose
```

### Batch download multiple studies
```bash
# Create UID list
cat > studies_to_download.txt << 'EOL'
1.2.840.113619.2.55.3.2609895290.675.1234567890.123
1.2.840.113619.2.55.3.2609895290.675.1234567890.456
1.2.840.113619.2.55.3.2609895290.675.1234567890.789
EOL

# Download with parallelism
dicom-retrieve pacs://pacs.hospital.org:11112 \
  --aet WORKSTATION \
  --method c-get \
  --uid-list studies_to_download.txt \
  --output /data/studies/ \
  --parallel 3 \
  --hierarchical \
  --verbose
```

## Exit Codes

- `0` - Success
- `1` - Error (connection failed, invalid parameters, etc.)

## See Also

- `dicom-query` - Query PACS for studies/series/instances
- `dicom-send` - Send DICOM files to PACS
- `dicom-info` - Display DICOM metadata
