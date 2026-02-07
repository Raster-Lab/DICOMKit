# dicom-export

Advanced DICOM image export tool with metadata embedding, contact sheets, animation, and bulk export capabilities.

## Features

- **Single Export**: Export individual DICOM files to PNG, JPEG, or TIFF with optional EXIF metadata embedding
- **Contact Sheet**: Generate thumbnail grids from multiple DICOM files
- **Animated GIF**: Export multi-frame DICOM files as animated GIFs with configurable FPS and scaling
- **Bulk Export**: Batch export entire directories with patient/study/series organization
- **EXIF Embedding**: Map DICOM metadata fields to standard EXIF/TIFF tags
- **Windowing**: Apply window/level settings during export

## Requirements

- macOS 14+ or iOS 17+ (requires CoreGraphics and ImageIO)
- Swift 6.2+
- DICOMKit framework

## Usage

### Single Export

```bash
# Basic export
dicom-export single ct_scan.dcm --output ct_scan.jpg

# Export with EXIF metadata
dicom-export single ct_scan.dcm --output ct_scan.jpg --embed-metadata

# Export specific fields as EXIF
dicom-export single ct_scan.dcm --output ct_scan.jpg --embed-metadata --exif-fields PatientName,StudyDate,Modality

# Export with windowing
dicom-export single ct_scan.dcm --output ct_scan.png --format png --apply-window --window-center 40 --window-width 400

# Export a specific frame
dicom-export single multi_frame.dcm --output frame5.png --format png --frame 5
```

### Contact Sheet

```bash
# Basic contact sheet
dicom-export contact-sheet file1.dcm file2.dcm file3.dcm --output sheet.png

# Custom grid layout
dicom-export contact-sheet *.dcm --output sheet.png --columns 6 --thumbnail-size 128 --spacing 2

# With labels
dicom-export contact-sheet *.dcm --output sheet.png --labels

# JPEG output with quality
dicom-export contact-sheet *.dcm --output sheet.jpg --format jpeg --quality 85
```

### Animated GIF

```bash
# Basic animation
dicom-export animate cine.dcm --output cine.gif

# Custom framerate and looping
dicom-export animate cine.dcm --output cine.gif --fps 15 --loop-count 3

# Export frame range with scaling
dicom-export animate cine.dcm --output cine.gif --start-frame 10 --end-frame 50 --scale 0.5

# With windowing
dicom-export animate cine.dcm --output cine.gif --apply-window --window-center 40 --window-width 400
```

### Bulk Export

```bash
# Flat export
dicom-export bulk input_dir/ --output output_dir/ --format png

# Organized by patient
dicom-export bulk input_dir/ --output output_dir/ --organize-by patient --recursive

# Full organization with metadata
dicom-export bulk input_dir/ --output output_dir/ --organize-by series --recursive --embed-metadata --verbose
```

## Supported EXIF Field Mappings

| DICOM Field | EXIF/TIFF Tag |
|---|---|
| PatientName | TIFF:ImageDescription |
| StudyDate | EXIF:DateTimeOriginal |
| Modality | EXIF:Software |
| StudyDescription | TIFF:DocumentName |
| SeriesDescription | EXIF:UserComment |
| InstitutionName | TIFF:Artist |
| Manufacturer | TIFF:Make |
| ManufacturerModelName | TIFF:Model |
| StationName | TIFF:HostComputer |

## Version

1.2.2
