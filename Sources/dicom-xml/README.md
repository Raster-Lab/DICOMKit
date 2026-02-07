# dicom-xml

Convert between DICOM and XML formats using the DICOM Native XML Model (PS3.19).

## Description

`dicom-xml` is a command-line tool for converting DICOM files to XML format and back. It implements the DICOM Native XML Model as specified in PS3.19, providing interoperability with XML-based tools and workflows.

## Features

- **Bidirectional Conversion**: Convert DICOM → XML and XML → DICOM
- **DICOM Native XML Model**: Full compliance with PS3.19 Native XML format
- **Bulk Data Handling**: Inline binary data or URI references
- **Pretty Printing**: Human-readable XML output with indentation
- **Metadata Filtering**: Extract specific tags only
- **Keyword Support**: Include or exclude DICOM keyword attributes
- **Performance**: Fast conversion with detailed timing information

## Installation

```bash
swift build -c release
cp .build/release/dicom-xml /usr/local/bin/
```

## Usage

### Basic Conversion

Convert DICOM to XML:
```bash
dicom-xml file.dcm --output file.xml
```

Convert XML to DICOM:
```bash
dicom-xml file.xml --output file.dcm --reverse
```

### Pretty-Printed XML

Output formatted XML for readability:
```bash
dicom-xml file.dcm --output file.xml --pretty
```

### Without Keywords

Exclude keyword attributes from XML elements:
```bash
dicom-xml file.dcm --output file.xml --no-keywords
```

### Metadata Only

Exclude pixel data from conversion:
```bash
dicom-xml large-image.dcm --output metadata.xml --metadata-only
```

### Bulk Data Handling

Configure inline binary threshold:
```bash
# Inline binary data up to 2KB
dicom-xml file.dcm --output file.xml --inline-threshold 2048

# Always use bulk data URIs
dicom-xml file.dcm --output file.xml --inline-threshold 0 --bulk-data-url "http://example.com/bulk"
```

### Filter Specific Tags

Extract only specific tags:
```bash
# By tag name
dicom-xml file.dcm --output metadata.xml --filter-tag PatientName --filter-tag StudyDate

# By tag hex (GGGG,EEEE)
dicom-xml file.dcm --output metadata.xml --filter-tag 0010,0010 --filter-tag 0008,0020
```

### Verbose Output

Show detailed timing and statistics:
```bash
dicom-xml file.dcm --output file.xml --verbose
```

## Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output file path (default: input with .xml or .dcm extension) |
| `-r, --reverse` | Convert from XML to DICOM |
| `-p, --pretty` | Pretty-print XML output with indentation |
| `--no-keywords` | Don't include keyword attributes in XML (default: keywords included) |
| `--include-empty` | Include empty values in XML |
| `--inline-threshold <bytes>` | Inline binary data up to this size (default: 1024, 0 for always URI) |
| `--bulk-data-url <url>` | Base URL for bulk data URIs |
| `--metadata-only` | Only include metadata (exclude pixel data) |
| `--filter-tag <tag>` | Filter tags by name or hex (can be used multiple times) |
| `--verbose` | Show detailed timing and statistics |
| `--version` | Show version information |
| `--help` | Show help message |

## Examples

### Convert CT Image to XML

```bash
dicom-xml ct-scan.dcm --output ct-scan.xml --pretty
```

### Convert Multiple Files

```bash
for file in *.dcm; do
    dicom-xml "$file" --output "${file%.dcm}.xml"
done
```

### Extract Patient Demographics

```bash
dicom-xml patient.dcm --output demographics.xml \
    --filter-tag PatientName \
    --filter-tag PatientID \
    --filter-tag PatientBirthDate \
    --filter-tag PatientSex \
    --pretty
```

### Roundtrip Conversion

```bash
# DICOM → XML → DICOM
dicom-xml original.dcm --output temp.xml
dicom-xml temp.xml --output restored.dcm --reverse
```

### Large Study with Bulk Data URIs

```bash
dicom-xml large-study.dcm --output large-study.xml \
    --inline-threshold 0 \
    --bulk-data-url "http://pacs.example.com/bulk" \
    --verbose
```

## XML Format

The tool outputs DICOM Native XML format as specified in PS3.19. The root element is `<NativeDicomModel>` with each DICOM attribute represented as:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NativeDicomModel xmlns="http://dicom.nema.org/PS3.19/models/NativeDICOM">
  <DicomAttribute tag="00100010" vr="PN" keyword="PatientName">
    <PersonName number="1">
      <Alphabetic>
        <FamilyName>Doe</FamilyName>
        <GivenName>John</GivenName>
      </Alphabetic>
    </PersonName>
  </DicomAttribute>
  <DicomAttribute tag="00100020" vr="LO" keyword="PatientID">
    <Value number="1">123456</Value>
  </DicomAttribute>
  <DicomAttribute tag="00080020" vr="DA" keyword="StudyDate">
    <Value number="1">20230115</Value>
  </DicomAttribute>
</NativeDicomModel>
```

### Sequences

Sequences are represented with nested `<Item>` elements:

```xml
<DicomAttribute tag="00081110" vr="SQ" keyword="ReferencedStudySequence">
  <Item number="1">
    <DicomAttribute tag="00081150" vr="UI" keyword="ReferencedSOPClassUID">
      <Value number="1">1.2.840.10008.3.1.2.3.1</Value>
    </DicomAttribute>
  </Item>
</DicomAttribute>
```

### Binary Data

Binary data can be inline (Base64) or referenced:

```xml
<!-- Inline binary -->
<DicomAttribute tag="7FE00010" vr="OB" keyword="PixelData">
  <InlineBinary>AQIDBAU=</InlineBinary>
</DicomAttribute>

<!-- Bulk data URI -->
<DicomAttribute tag="7FE00010" vr="OB" keyword="PixelData">
  <BulkData uri="http://example.com/bulk/7FE00010"/>
</DicomAttribute>
```

### Person Names

Person names have special structured representation:

```xml
<DicomAttribute tag="00100010" vr="PN" keyword="PatientName">
  <PersonName number="1">
    <Alphabetic>
      <FamilyName>Doe</FamilyName>
      <GivenName>John</GivenName>
      <MiddleName>Q</MiddleName>
      <NamePrefix>Dr</NamePrefix>
      <NameSuffix>Jr</NameSuffix>
    </Alphabetic>
  </PersonName>
</DicomAttribute>
```

## Performance

Typical conversion times on modern hardware:

- Small image (512×512, ~500KB): 15-60ms
- Medium image (1024×1024, ~2MB): 60-250ms
- Large image (2048×2048, ~8MB): 250-600ms
- CT series (100 slices, ~100MB): 3-7s

XML files are typically 2-4x larger than DICOM JSON due to XML verbosity.

## Error Handling

The tool provides clear error messages for common issues:

- **File not found**: Validates input file exists
- **Invalid XML**: Reports XML parsing errors with line numbers
- **Invalid DICOM**: Reports DICOM parsing errors
- **Invalid tags**: Validates tag format for filtering
- **Write errors**: Reports file write failures

## Exit Codes

- `0`: Success
- `1`: Error occurred

## Related Tools

- `dicom-info`: Display DICOM metadata
- `dicom-dump`: Dump DICOM file structure
- `dicom-json`: Convert DICOM to/from JSON
- `dicom-validate`: Validate DICOM files

## References

- DICOM PS3.19 - Application Hosting (Native DICOM Model)
- DICOM PS3.5 - Data Structures and Encoding
- XML 1.0 Specification

## Version

1.1.4 - Part of DICOMKit Phase 3 CLI Tools
