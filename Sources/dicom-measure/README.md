# dicom-measure

Perform precise medical imaging measurements on DICOM images with calibration support.

## Features

- **Distance**: Point-to-point distance with physical calibration
- **Area**: Polygon and ellipse area calculations
- **Angle**: Angle measurement between two lines
- **ROI Analysis**: Statistics (mean, std, min, max) within regions of interest
- **Hounsfield Units**: CT number extraction with rescale slope/intercept
- **Pixel Values**: Raw pixel value extraction with frame support
- **Calibration**: Automatic use of Pixel Spacing, Rescale Slope/Intercept
- **Multiple Formats**: Text, JSON, CSV output
- **Unit Conversion**: mm, cm, inches, pixels

## Usage

```bash
# Measure distance between two points
dicom-measure distance ct.dcm --p1 100,200 --p2 300,400

# Measure polygon area
dicom-measure area ct.dcm --polygon 100,100 150,200 200,200 180,120

# Measure ellipse area
dicom-measure area ct.dcm --ellipse 200,200,50,30

# Measure angle
dicom-measure angle ct.dcm --vertex 200,200 --p1 100,100 --p2 300,100

# ROI statistics
dicom-measure roi ct.dcm --rect 100,100,50,50 --statistics --histogram

# Hounsfield Unit measurement
dicom-measure hu ct.dcm --point 200,200

# Raw pixel value
dicom-measure pixel ct.dcm --point 150,150 --frame 0

# Output to file in JSON format
dicom-measure distance ct.dcm --p1 100,200 --p2 300,400 --format json --output result.json
```

## Output Formats

- **text**: Human-readable plain text (default)
- **json**: Structured JSON for programmatic use
- **csv**: Comma-separated values for spreadsheets

## Unit Options

- **mm**: Millimeters (default, uses Pixel Spacing)
- **cm**: Centimeters
- **inches**: Imperial inches
- **pixels**: Raw pixel distances (no calibration)

## Calibration

The tool automatically reads calibration data from DICOM tags:
- **Pixel Spacing** (0028,0030): Row and column spacing in mm
- **Rescale Slope** (0028,1053): Linear transform slope
- **Rescale Intercept** (0028,1052): Linear transform intercept

If Pixel Spacing is not present, measurements default to 1.0 mm per pixel.
