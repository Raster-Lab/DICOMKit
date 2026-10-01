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

Physical units use the first of these that the object carries:
- **Pixel Spacing** (0028,0030): row spacing \ column spacing in mm (PS3.3 10.7.1.3)
- **Pixel Measures Sequence** (0028,9110) of the frame, in the Per-frame or Shared Functional Groups (PS3.3 C.7.6.16.2.1)
- **Sequence of Ultrasound Regions** (0018,6011): the region holding the points, when Physical Units X/Y Direction are 0003H cm (PS3.3 C.8.5.5)
- **Imager Pixel Spacing** (0018,1164): measured at the front plane of the detector housing, not corrected for magnification (PS3.3 Tables C.8-2, C.8-71)
- **Nominal Scanned Pixel Spacing** (0018,2010): on the scanned media (PS3.3 Table C.8-25)

Without any of them, results are in pixels (`px`, `px²`) and a warning is printed. Results
report the attribute used as `spacing_source` (its PS3.6 keyword) and, in JSON, the PS3.16
UCUM code as `unit_ucum` (`mm`, `cm` — CID 7460; `mm2`, `cm2` — CID 7461; `deg` — CID 7183;
`[hnsf'U]` — CID 7181).

Pixel values are the stored values (Bits Stored / High Bit / Pixel Representation, PS3.5 8.1.1)
passed through the Modality LUT Sequence (0028,3000) or Rescale Slope / Intercept (PS3.3 C.11.1).
`hu` labels a value HU only when Rescale Type (0028,1054) is HU, or is absent on a CT image
(PS3.3 Table C.8-3); otherwise the value is labelled with its Rescale Type.

## Coordinates

`x,y` are column,row in the PS3.3 Table C.18.6-1 system: 0,0 is the top-left corner of the
top-left pixel. A point samples pixel floor(x),floor(y); an ROI holds the pixels whose centres
lie inside it. `--frame` is a 0-based index (0 = DICOM Frame number 1).
