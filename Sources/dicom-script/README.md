# dicom-script

Execute DICOM workflow scripts and pipelines with support for conditional logic, variable substitution, and parallel execution.

## Features

- **Workflow Scripting DSL**: Simple, readable syntax for DICOM workflows
- **Pipeline Execution**: Chain multiple DICOM commands together
- **Conditional Logic**: Execute commands based on conditions
- **Variable Substitution**: Use variables throughout scripts
- **Parallel Execution**: Run commands in parallel when possible
- **Error Handling**: Robust error handling and reporting
- **Script Validation**: Validate scripts before execution
- **Template Generation**: Generate common workflow templates

## Installation

```bash
swift build -c release
.build/release/dicom-script --help
```

## Usage

### Run Command

Execute a DICOM workflow script:

```bash
# Basic execution
dicom-script run workflow.dcmscript

# With variables
dicom-script run workflow.dcmscript --var INPUT_DIR=/data --var PATIENT_ID=12345

# Parallel execution
dicom-script run workflow.dcmscript --parallel

# Dry run (show what would be executed)
dicom-script run workflow.dcmscript --dry-run

# Verbose output with logging
dicom-script run workflow.dcmscript --verbose --log execution.log
```

### Validate Command

Validate a script before execution:

```bash
# Basic validation
dicom-script validate workflow.dcmscript

# Verbose validation
dicom-script validate workflow.dcmscript --verbose
```

### Template Command

Generate workflow script templates:

```bash
# Generate workflow template
dicom-script template workflow > workflow.dcmscript

# Generate pipeline template
dicom-script template pipeline > pipeline.dcmscript

# Generate query template
dicom-script template query > query.dcmscript

# Generate archive template
dicom-script template archive > archive.dcmscript

# Generate anonymization template
dicom-script template anonymize > anonymize.dcmscript
```

## Script Syntax

### Basic Commands

Execute DICOM tools directly:

```bash
# Single command
dicom-info file.dcm

# Command with arguments
dicom-convert input.dcm --output output.png --format png

# Command with file expansion
dicom-validate *.dcm --level 2
```

### Variables

Define and use variables:

```bash
# Define variables
INPUT_DIR=/path/to/input
OUTPUT_DIR=/path/to/output
PATIENT_ID=12345

# Use variables
dicom-query --patient-id ${PATIENT_ID}
dicom-convert ${INPUT_DIR}/*.dcm --output ${OUTPUT_DIR}

# Alternative syntax
dicom-anon $INPUT_DIR/*.dcm --output $OUTPUT_DIR
```

### Pipelines

Chain commands together (sequential execution):

```bash
# Simple pipeline
dicom-query --patient-id 12345 | dicom-retrieve --output studies/

# Multi-stage pipeline
dicom-query --patient-name "DOE*" | \
dicom-retrieve --output studies/ | \
dicom-validate --level 2 | \
dicom-anon --profile basic --output anon/
```

### Conditional Logic

Execute commands based on conditions:

```bash
# Simple conditional
if exists /path/to/file.dcm
    dicom-info /path/to/file.dcm
endif

# Conditional with else
if exists ${INPUT_DIR}
    dicom-study summary ${INPUT_DIR}
else
    echo "Input directory not found"
endif

# Condition operators
if exists /path/to/file.dcm    # Check if file exists
if empty ${VARIABLE}            # Check if variable is empty
if equals ${VAR1} ${VAR2}       # Check if values are equal
```

### Comments

Add comments to scripts:

```bash
# This is a comment
# Comments start with # and are ignored

# Variables can be commented
# INPUT_DIR=/path/to/input

dicom-info file.dcm  # Inline comments are also supported
```

## Script Examples

### Example 1: Basic Workflow

```bash
# Define paths
INPUT_DIR=/data/dicom
OUTPUT_DIR=/data/processed

# Validate input files
dicom-validate ${INPUT_DIR}/*.dcm --level 2

# Convert to PNG
dicom-convert ${INPUT_DIR}/*.dcm --output ${OUTPUT_DIR} --format png

# Generate summary
dicom-study summary ${INPUT_DIR} --format json > ${OUTPUT_DIR}/summary.json
```

### Example 2: PACS Query and Retrieve

```bash
# PACS configuration
PACS_HOST=pacs.example.com
PACS_PORT=11112
PACS_AET=PACS
LOCAL_AET=WORKSTATION
PATIENT_ID=12345

# Query PACS
dicom-query --host ${PACS_HOST} --port ${PACS_PORT} \
    --called-aet ${PACS_AET} --calling-aet ${LOCAL_AET} \
    --patient-id ${PATIENT_ID} --level STUDY

# Retrieve studies
dicom-retrieve --host ${PACS_HOST} --port ${PACS_PORT} \
    --called-aet ${PACS_AET} --calling-aet ${LOCAL_AET} \
    --patient-id ${PATIENT_ID} --output studies/

# Validate retrieved files
dicom-validate studies/*.dcm --level 2
```

### Example 3: Conditional Processing

```bash
# Input and output paths
INPUT_FILE=/data/study.dcm
OUTPUT_DIR=/data/processed

# Check if file exists before processing
if exists ${INPUT_FILE}
    # Validate file
    dicom-validate ${INPUT_FILE} --level 2
    
    # Convert to PNG
    dicom-convert ${INPUT_FILE} --output ${OUTPUT_DIR} --format png
    
    # Generate report
    dicom-info ${INPUT_FILE} --format json > ${OUTPUT_DIR}/metadata.json
else
    echo "Error: Input file not found"
    exit 1
endif
```

### Example 4: Anonymization Pipeline

```bash
# Paths
INPUT_DIR=/data/raw
TEMP_DIR=/data/temp
OUTPUT_DIR=/data/anonymized

# Validate input
dicom-validate ${INPUT_DIR}/*.dcm --level 2

# Anonymize with basic profile
dicom-anon ${INPUT_DIR}/*.dcm --profile basic --output ${TEMP_DIR}

# Check for sensitive files
if exists ${INPUT_DIR}/sensitive.dcm
    # Use strict anonymization for sensitive files
    dicom-anon ${INPUT_DIR}/sensitive.dcm --profile strict --output ${OUTPUT_DIR}
endif

# Move anonymized files
dicom-study organize ${TEMP_DIR} --output ${OUTPUT_DIR}

# Validate anonymized files
dicom-validate ${OUTPUT_DIR}/**/*.dcm --level 2
```

### Example 5: Multi-Stage Processing

```bash
# Configuration
SOURCE_DIR=/data/incoming
WORK_DIR=/data/work
ARCHIVE_DIR=/data/archive
ARCHIVE_DB=${ARCHIVE_DIR}/archive.db

# Step 1: Organize incoming files
dicom-study organize ${SOURCE_DIR} --output ${WORK_DIR}

# Step 2: Validate organized files
dicom-validate ${WORK_DIR}/**/*.dcm --level 2

# Step 3: Extract metadata
dicom-study summary ${WORK_DIR} --format json > ${WORK_DIR}/summary.json

# Step 4: Archive files
dicom-archive create ${ARCHIVE_DB} --input ${WORK_DIR}

# Step 5: Cleanup
if exists ${WORK_DIR}
    rm -rf ${WORK_DIR}
endif
```

## Supported Condition Operators

- `exists <path>` - Check if file or directory exists
- `empty <variable>` - Check if variable is empty
- `equals <value1> <value2>` - Check if two values are equal

## Supported DICOM Tools

All DICOMKit CLI tools are supported:

- `dicom-info` - Display metadata
- `dicom-convert` - Format conversion
- `dicom-validate` - Validation
- `dicom-anon` - Anonymization
- `dicom-dump` - Hex dump
- `dicom-query` - PACS query
- `dicom-send` - PACS send
- `dicom-diff` - File comparison
- `dicom-retrieve` - PACS retrieval
- `dicom-split` - Multi-frame extraction
- `dicom-merge` - Multi-frame creation
- `dicom-json` - JSON conversion
- `dicom-xml` - XML conversion
- `dicom-pdf` - PDF operations
- `dicom-image` - Image conversion
- `dicom-dcmdir` - DICOMDIR management
- `dicom-archive` - Archive management
- `dicom-export` - Export operations
- `dicom-qr` - Query/Retrieve
- `dicom-wado` - DICOMweb client
- `dicom-echo` - Network testing
- `dicom-mwl` - Worklist management
- `dicom-mpps` - MPPS operations
- `dicom-pixedit` - Pixel editing
- `dicom-tags` - Tag manipulation
- `dicom-uid` - UID management
- `dicom-compress` - Compression
- `dicom-study` - Study management

## Error Handling

The tool provides comprehensive error handling:

- **Script Not Found**: Specified script file does not exist
- **Parse Error**: Syntax error in script (with line number)
- **Invalid Variable**: Malformed variable assignment
- **Invalid Command**: Unknown DICOM tool
- **Execution Error**: Command execution failed
- **Condition Error**: Invalid condition syntax

## Logging

Scripts can log execution details:

```bash
# Enable verbose logging
dicom-script run workflow.dcmscript --verbose

# Write logs to file
dicom-script run workflow.dcmscript --log execution.log

# Both verbose and file logging
dicom-script run workflow.dcmscript --verbose --log execution.log
```

Log format:
```
[2024-01-15 10:30:45] Starting script execution: workflow.dcmscript
[2024-01-15 10:30:45] Variables: ["INPUT_DIR": "/data/input"]
[2024-01-15 10:30:45] Executing: dicom-validate /data/input/*.dcm --level 2
[2024-01-15 10:30:46] Output: Validated 10 files successfully
[2024-01-15 10:30:46] Script execution completed successfully
```

## Performance

- **Sequential Execution**: Commands run one after another by default
- **Parallel Execution**: Use `--parallel` flag for concurrent execution
- **Memory Efficient**: Streams data between pipeline stages
- **Error Recovery**: Continues execution after non-fatal errors (when appropriate)

## Version

dicom-script v1.3.5 - Part of DICOMKit CLI Tools Suite

## See Also

- All DICOMKit CLI tools for use in scripts
- Shell scripting for advanced workflows
- Make/rake for build automation
