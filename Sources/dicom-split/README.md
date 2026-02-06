# dicom-split

Extract individual frames from multi-frame DICOM files.

## Features

- **Multi-Frame Support**: Works with Enhanced CT/MR/XA, ultrasound, nuclear medicine, and other multi-frame formats
- **Flexible Frame Selection**: Extract all frames or specific ranges (e.g., "1,3,5-10")
- **Multiple Output Formats**: DICOM, PNG, JPEG, or TIFF
- **Window/Level Application**: Apply windowing for proper image visualization
- **Custom Naming**: Flexible file naming patterns with variables
- **Batch Processing**: Process entire directories recursively
- **Metadata Preservation**: Maintains original DICOM metadata in extracted frames

## Usage

### Extract All Frames to DICOM Files

```bash
dicom-split multiframe.dcm --output frames/
```

### Extract Specific Frames

```bash
# Extract frames 1, 5, and 10-15
dicom-split multiframe.dcm --frames 1,5,10-15 --output selected/
```

### Extract as PNG Images

```bash
dicom-split ct-multiframe.dcm \
  --format png \
  --output images/
```

### Extract with Window/Level

```bash
dicom-split ct-multiframe.dcm \
  --format png \
  --apply-window \
  --window-center 40 \
  --window-width 400 \
  --output images/
```

### Use Stored Window Settings

```bash
dicom-split ct-multiframe.dcm \
  --format png \
  --apply-window \
  --output images/
```

### Custom File Naming

```bash
dicom-split multiframe.dcm \
  --output frames/ \
  --pattern "frame_{number:04d}_{modality}.dcm"
```

Available naming variables:
- `{number}` - Frame number (0-padded to 4 digits by default)
- `{modality}` - DICOM modality (e.g., CT, MR, US)
- `{series}` - Series number

### Batch Processing

Process all DICOM files in a directory:

```bash
dicom-split studies/ \
  --output split_studies/ \
  --recursive \
  --verbose
```

### Export JPEG Images

```bash
dicom-split multiframe.dcm \
  --format jpeg \
  --apply-window \
  --output images/
```

### Export TIFF Images

```bash
dicom-split multiframe.dcm \
  --format tiff \
  --apply-window \
  --output images/
```

## Options

- `input` - Input DICOM file or directory
- `--output` - Output directory for extracted frames (default: current directory)
- `--frames` - Frame numbers to extract (e.g., '1,3,5-10')
- `--format` - Output format: dicom, png, jpeg, tiff (default: dicom)
- `--apply-window` - Apply window/level settings to image output
- `--window-center` - Window center for image rendering
- `--window-width` - Window width for image rendering
- `--pattern` - Naming pattern for output files (variables: {number}, {modality}, {series})
- `-r, --recursive` - Recursively process directories
- `-v, --verbose` - Show verbose output

## Supported DICOM Formats

- **Enhanced Multi-Frame Image IOD**: Enhanced CT, MR, XA
- **Legacy Multi-Frame Formats**: Ultrasound, Nuclear Medicine, X-Ray Angiography
- **Secondary Capture Multi-Frame**
- **Any DICOM file with NumberOfFrames > 1**

## Frame Numbering

Frames are numbered starting from 0 (DICOM convention):
- First frame: 0
- Second frame: 1
- etc.

When specifying frames on the command line, use these 0-based indices.

## Window/Level Application

### Custom Window Settings

Specify exact window center and width:

```bash
dicom-split ct.dcm \
  --format png \
  --apply-window \
  --window-center 40 \
  --window-width 400 \
  --output images/
```

### Stored Window Settings

Use window settings stored in the DICOM file:

```bash
dicom-split ct.dcm \
  --format png \
  --apply-window \
  --output images/
```

If no window settings are found, defaults will be used based on pixel value range.

## Examples

### Extract CT Multi-Frame Study

```bash
# Extract all frames as windowed PNG images
dicom-split ct-chest-multiframe.dcm \
  --format png \
  --apply-window \
  --window-center 40 \
  --window-width 400 \
  --output ct_frames/ \
  --verbose
```

### Extract Ultrasound Cine Loop

```bash
# Extract frames 10-50 from ultrasound cine
dicom-split us-cine.dcm \
  --frames 10-50 \
  --format png \
  --output us_frames/ \
  --pattern "us_{number:04d}.png"
```

### Batch Process MR Series

```bash
# Process all multi-frame MR files in a directory
dicom-split mr_studies/ \
  --output split_mr/ \
  --recursive \
  --format dicom \
  --verbose
```

### Extract Key Frames

```bash
# Extract specific diagnostic frames
dicom-split multiframe.dcm \
  --frames 0,10,20,30,40 \
  --format jpeg \
  --apply-window \
  --output key_frames/
```

## Exit Codes

- `0` - Success
- `1` - Error (invalid input, file not found, etc.)

## Notes

- Each extracted DICOM frame gets a new unique SOP Instance UID
- Original metadata (patient info, study/series UIDs, etc.) is preserved
- Pixel data is extracted as-is for DICOM output
- Image formats (PNG, JPEG, TIFF) apply rendering and windowing
- Multi-frame files with only 1 frame are skipped
- Non-DICOM files in directories are automatically skipped

## See Also

- `dicom-merge` - Combine single frames into multi-frame files
- `dicom-info` - Display DICOM metadata including frame count
- `dicom-convert` - Convert DICOM files between transfer syntaxes
