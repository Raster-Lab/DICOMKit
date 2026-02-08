# dicom-pixedit

A DICOM pixel data manipulation CLI tool (v1.3.0).

## Features

- **Mask regions** – black out burned-in annotations or other rectangular areas
- **Crop** – extract a region of interest from the image
- **Window/Level** – permanently bake window/level into pixel data
- **Invert** – invert pixel values (e.g., for photometric conversion)

## Usage

```bash
# Mask a region (e.g., burned-in patient name)
dicom-pixedit file.dcm --output masked.dcm --mask-region 0,0,200,50

# Mask with a specific fill value
dicom-pixedit file.dcm --output masked.dcm --mask-region 0,0,200,50 --fill-value 0

# Crop to a region of interest
dicom-pixedit file.dcm --output cropped.dcm --crop 100,100,400,400

# Apply window/level permanently
dicom-pixedit ct.dcm --output windowed.dcm --window-center 40 --window-width 400 --apply-window

# Invert pixel values
dicom-pixedit file.dcm --output inverted.dcm --invert

# Combine operations with verbose output
dicom-pixedit file.dcm --output edited.dcm --mask-region 0,0,200,50 --invert --verbose
```

## Options

| Option | Description |
|---|---|
| `--output` | Output DICOM file path (required) |
| `--mask-region` | Region to mask as `x,y,width,height` |
| `--fill-value` | Fill value for masked pixels (default: 0) |
| `--crop` | Crop region as `x,y,width,height` |
| `--window-center` | Window center value |
| `--window-width` | Window width value |
| `--apply-window` | Bake window/level into pixel data |
| `--invert` | Invert all pixel values |
| `-v, --verbose` | Show verbose output |

## Supported Pixel Formats

- 8-bit and 16-bit pixel data
- Signed and unsigned pixel representations
- Monochrome and multi-sample (e.g., RGB) images
