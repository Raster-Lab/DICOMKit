# dicom-convert

Convert DICOM files between transfer syntaxes and export pixel data to image formats.

## Features

- **Transfer Syntax Conversion**: Convert between Explicit VR Little Endian, Implicit VR Little Endian, Explicit VR Big Endian, and DEFLATE
- **Image Export**: Export DICOM pixel data to PNG, JPEG, or TIFF
- **Window/Level Application**: Apply DICOM windowing during image export
- **Batch Processing**: Convert entire directories recursively
- **Private Tag Stripping**: Remove private tags during conversion
- **Output Validation**: Verify converted files are valid DICOM

## Usage

### Transfer Syntax Conversion

```bash
# Convert to Explicit VR Little Endian
dicom-convert file.dcm --output output.dcm --transfer-syntax ExplicitVRLittleEndian

# Convert to Implicit VR Little Endian
dicom-convert file.dcm --output output.dcm --transfer-syntax ImplicitVRLittleEndian

# Convert with validation
dicom-convert file.dcm --output output.dcm --transfer-syntax ExplicitVRLittleEndian --validate
```

### Image Export

```bash
# Export to PNG
dicom-convert xray.dcm --output xray.png --format png

# Export to JPEG with quality setting
dicom-convert xray.dcm --output xray.jpg --format jpeg --quality 95

# Export to TIFF
dicom-convert ct.dcm --output ct.tiff --format tiff
```

### Window/Level Application

```bash
# Apply windowing from DICOM tags
dicom-convert ct.dcm --output ct.png --apply-window

# Specify custom window center and width
dicom-convert ct.dcm --output ct.png --apply-window --window-center 40 --window-width 400
```

### Multi-frame Images

```bash
# Export specific frame
dicom-convert multiframe.dcm --output frame5.png --frame 5 --format png

# Export all frames (outputs frame0.png, frame1.png, etc.)
dicom-convert multiframe.dcm --output frames/ --format png
```

### Batch Conversion

```bash
# Convert directory recursively
dicom-convert input_dir/ --output output_dir/ --transfer-syntax ExplicitVRLittleEndian --recursive

# Strip private tags during batch conversion
dicom-convert input_dir/ --output output_dir/ --transfer-syntax ExplicitVRLittleEndian --recursive --strip-private
```

## Options

- `--output, -o <path>`: Output file or directory path (required)
- `--transfer-syntax <syntax>`: Target transfer syntax (ExplicitVRLittleEndian, ImplicitVRLittleEndian, ExplicitVRBigEndian, DEFLATE)
- `--format <format>`: Output format: png, jpeg, tiff, dicom (default: dicom)
- `--quality <1-100>`: JPEG quality (default: 90)
- `--apply-window`: Apply window/level during export
- `--window-center <value>`: Window center value
- `--window-width <value>`: Window width value
- `--frame <number>`: Export specific frame (0-indexed)
- `--recursive`: Process directories recursively
- `--strip-private`: Remove private tags during conversion
- `--validate`: Validate output after conversion
- `--force`: Force parsing of files without DICM prefix

## Examples

### CT Scan Window/Level

```bash
# Lung window (center=-600, width=1500)
dicom-convert ct.dcm --output ct-lung.png --apply-window --window-center -600 --window-width 1500

# Bone window (center=300, width=1500)
dicom-convert ct.dcm --output ct-bone.png --apply-window --window-center 300 --window-width 1500

# Soft tissue window (center=40, width=400)
dicom-convert ct.dcm --output ct-soft.png --apply-window --window-center 40 --window-width 400
```

### Batch Anonymization

```bash
# Convert and strip private tags
dicom-convert study/ --output anonymized/ --transfer-syntax ExplicitVRLittleEndian --recursive --strip-private
```

### Transfer Syntax Normalization

```bash
# Normalize mixed transfer syntaxes to standard format
dicom-convert mixed_data/ --output normalized/ --transfer-syntax ExplicitVRLittleEndian --recursive --validate
```

## Exit Codes

- `0`: Success
- `1`: Validation error (invalid arguments)
- `2`: File not found
- `3`: Conversion error
- `4`: Export error

## Platform Support

Image export (PNG, JPEG, TIFF) requires CoreGraphics and is available on:
- macOS 14+
- iOS 17+
- visionOS 1+

Transfer syntax conversion works on all platforms.

## See Also

- `dicom-info`: Display DICOM metadata
- `dicom-anon`: Anonymize DICOM files
- `dicom-validate`: Validate DICOM files
