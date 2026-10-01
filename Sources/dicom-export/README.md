# dicom-export

Advanced DICOM image export tool with metadata embedding, contact sheets, animation, and bulk export capabilities.

## Features

- **Single Export**: Export individual DICOM files to PNG, JPEG, or TIFF with optional EXIF metadata embedding
- **Contact Sheet**: Generate thumbnail grids from multiple DICOM files
- **Animated GIF**: Export multi-frame DICOM files as animated GIFs with configurable FPS and scaling
- **Bulk Export**: Batch export entire directories with patient/study/series organization
- **EXIF Embedding**: Map DICOM metadata fields to standard EXIF/TIFF tags
- **Windowing**: Every subcommand renders monochrome frames through the PS3.4 grayscale chain —
  Modality LUT (Rescale Slope/Intercept), the file's VOI (Window Center (0028,1050) and
  Window Width (0028,1051) with VOI LUT Function (0028,1056), else VOI LUT Sequence (0028,3010),
  else the full pixel range), then INVERSE for MONOCHROME1. `--apply-window` with `--window-center` /
  `--window-width` (modality units, LINEAR) overrides the file's VOI in `single` and `animate`.
- **Burned In Annotation**: a file whose Burned In Annotation (0028,0301) is YES gets a warning on
  stderr — its rendered pixels contain text that identifies the patient.
- The outputs (PNG, JPEG, TIFF, GIF) are not DICOM files.

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

# Export a specific frame: --frame is a 0-based index (DICOM frame number - 1), so this is frame 5
dicom-export single multi_frame.dcm --output frame5.png --format png --frame 4
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
# Basic animation. Without --fps the rate is the file's Recommended Display Frame Rate (0008,2144),
# else Cine Rate (0018,0040), else 1000 / Frame Time (0018,1063) (msec), else 10 fps
dicom-export animate cine.dcm --output cine.gif

# Custom framerate and looping
dicom-export animate cine.dcm --output cine.gif --fps 15 --loop-count 3

# Export frame range with scaling (0-based indexes, end inclusive: frames 11 to 51)
dicom-export animate cine.dcm --output cine.gif --start-frame 10 --end-frame 50 --scale 0.5

# With windowing
dicom-export animate cine.dcm --output cine.gif --apply-window --window-center 40 --window-width 400
```

### Bulk Export

```bash
# Flat export
dicom-export bulk input_dir/ --output output_dir/ --format png

# Organized by patient (folder = Patient's Name (0010,0010); study and series add the
# Study Instance UID (0020,000D) and Series Instance UID (0020,000E) folders)
dicom-export bulk input_dir/ --output output_dir/ --organize-by patient --recursive

# Full organization with metadata
dicom-export bulk input_dir/ --output output_dir/ --organize-by series --recursive --embed-metadata --verbose
```

## Supported EXIF Field Mappings

`--exif-fields` takes these PS3.6 keywords (case-insensitive); other keywords are ignored.

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
