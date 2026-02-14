# dicom-3d - 3D Reconstruction and Multi-Planar Reformation

**Version:** 1.4.0  
**Part of:** DICOMKit CLI Tools Phase 7

## Overview

`dicom-3d` performs 3D volume reconstruction, Multi-Planar Reformation (MPR), and advanced projection techniques from multi-slice DICOM series for medical imaging visualization.

## Features

### Multi-Planar Reformation (MPR)
- **Axial, Sagittal, Coronal** reformations
- **Oblique MPR** with arbitrary plane orientation
- **Curved MPR** along custom paths
- Trilinear interpolation for smooth reformations
- Configurable slice thickness

### Intensity Projections
- **Maximum Intensity Projection (MIP)** - highlight bright structures
- **Minimum Intensity Projection (MinIP)** - highlight dark structures
- **Average Intensity Projection** - mean values along projection axis
- Configurable slab thickness for focused projections

### 3D Surface Extraction
- **Marching Cubes** algorithm for isosurface extraction
- Export to **STL** and **OBJ** formats
- Customizable threshold values
- Suitable for 3D printing and visualization

### Volume Export
- **NIfTI** format (.nii) - neuroimaging standard
- **MetaImage** format (.mhd + .raw) - ITK/VTK compatible
- Preserves spatial information and metadata

## Installation

```bash
swift build -c release
.build/release/dicom-3d --help
```

## Usage

### Multi-Planar Reformation

Generate axial, sagittal, and coronal reformations:

```bash
dicom-3d mpr series/*.dcm --output mpr/ --planes axial,sagittal,coronal
```

Generate only sagittal slices:

```bash
dicom-3d mpr series/*.dcm --output sagittal/ --planes sagittal
```

With custom windowing:

```bash
dicom-3d mpr ct-series/*.dcm \
  --output mpr/ \
  --planes axial,sagittal,coronal \
  --window-center -600 \
  --window-width 1500
```

### Maximum Intensity Projection (MIP)

Generate MIP along axial direction:

```bash
dicom-3d mip series/*.dcm --output mip.png
```

MIP with slab thickness (20mm):

```bash
dicom-3d mip series/*.dcm \
  --output mip.png \
  --thickness 20 \
  --direction axial
```

Sagittal MIP:

```bash
dicom-3d mip series/*.dcm \
  --output mip-sagittal.png \
  --direction sagittal
```

### Minimum Intensity Projection (MinIP)

```bash
dicom-3d minip series/*.dcm \
  --output minip.png \
  --direction coronal \
  --thickness 10
```

### Average Intensity Projection

```bash
dicom-3d average series/*.dcm \
  --output average.png \
  --direction axial
```

### Surface Extraction

Extract isosurface at threshold 200 (e.g., bone in CT):

```bash
dicom-3d surface series/*.dcm \
  --output surface.stl \
  --threshold 200
```

Export as OBJ format:

```bash
dicom-3d surface series/*.dcm \
  --output model.obj \
  --threshold 150 \
  --format obj
```

### Volume Export

Export as NIfTI:

```bash
dicom-3d export series/*.dcm \
  --output volume \
  --formats nifti
```

Export as MetaImage:

```bash
dicom-3d export series/*.dcm \
  --output volume \
  --formats metaimage
```

Export both formats:

```bash
dicom-3d export series/*.dcm \
  --output volume \
  --formats nifti,metaimage
```

## Options

### Common Options

- `--verbose` - Enable verbose output for debugging
- `--window-center <value>` - Window center for display (Hounsfield units for CT)
- `--window-width <value>` - Window width for display

### MPR Options

- `--planes <list>` - Comma-separated list: axial, sagittal, coronal, oblique
- `--thickness <mm>` - Slice thickness in millimeters
- `--interpolation <method>` - Interpolation: nearest, linear, cubic (default: linear)
- `--format <fmt>` - Output format: png, dcm (default: png)

### Projection Options

- `--direction <dir>` - Projection direction: axial, sagittal, coronal
- `--thickness <mm>` - Slab thickness in mm (0 = full volume)

### Surface Options

- `--threshold <value>` - Threshold for surface extraction
- `--format <fmt>` - Output format: stl, obj (default: stl)

### Export Options

- `--formats <list>` - Comma-separated: nifti, metaimage

## Examples

### CT Chest MIP

```bash
# Load CT chest series and create MIP for vessel visualization
dicom-3d mip ct-chest/*.dcm \
  --output chest-mip.png \
  --direction axial \
  --window-center 40 \
  --window-width 400 \
  --verbose
```

### Spine Sagittal Reformation

```bash
# Generate sagittal reformations of spine
dicom-3d mpr spine-ct/*.dcm \
  --output spine-sagittal/ \
  --planes sagittal \
  --window-center 40 \
  --window-width 400
```

### Bone Surface for 3D Printing

```bash
# Extract bone surface and save as STL
dicom-3d surface skull-ct/*.dcm \
  --output skull.stl \
  --threshold 200 \
  --verbose
```

### Brain Volume Export

```bash
# Export brain MRI as NIfTI for analysis
dicom-3d export brain-mri/*.dcm \
  --output brain \
  --formats nifti \
  --verbose
```

## Technical Details

### Volume Loading

- Automatically sorts slices by position
- Handles non-uniform slice spacing
- Supports all standard DICOM orientations
- Applies rescale slope/intercept (e.g., Hounsfield units)

### Interpolation Methods

- **Nearest**: Fast, preserves original values
- **Linear**: Smooth, good for most cases (default)
- **Cubic**: Smoothest, slower (planned)

### Coordinate Systems

- Preserves DICOM coordinate system (LPS)
- Handles Image Orientation Patient correctly
- Maintains spatial relationships in exports

### File Formats

#### NIfTI (.nii)
- Standard in neuroimaging
- Stores header and data in single file
- Includes spatial transform matrix
- Compatible with FSL, SPM, AFNI, etc.

#### MetaImage (.mhd + .raw)
- ITK/VTK standard format
- Text header (.mhd) + binary data (.raw)
- Easy to parse and process
- Compatible with 3D Slicer, ParaView, etc.

#### STL
- Standard for 3D printing
- Binary format for efficiency
- Triangular mesh representation
- Compatible with all 3D modeling software

#### OBJ
- ASCII format for 3D models
- Human-readable
- Widely supported
- Good for visualization and editing

## Limitations

### Current Version (1.4.0)

- **Volume rendering**: Not yet implemented
- **Curved MPR**: Planned for future version
- **Animation**: Planned for future version
- **Transfer functions**: Planned for future version
- **GPU acceleration**: Not available (CPU-only)

### Performance Notes

- Large volumes (>512³) may require significant memory
- Surface extraction is computationally intensive
- Use `--verbose` to monitor progress
- Consider using smaller slab thickness for MIP to improve speed

### Platform Requirements

- **macOS 14+** or **iOS 17+** for PNG export (CoreGraphics)
- Linux builds support export formats but not PNG rendering

## Dependencies

- **DICOMKit** - Core DICOM functionality
- **DICOMCore** - Low-level DICOM parsing
- **DICOMDictionary** - Tag and UID lookups
- **ArgumentParser** - Command-line interface

## Error Handling

Common errors and solutions:

### "Missing required metadata"
- Ensure input files are valid DICOM
- Check that Image Position Patient and Image Orientation Patient tags are present

### "File not found"
- Use absolute paths or correct relative paths
- Check file permissions

### "Invalid pixel data"
- Verify files contain pixel data (not just metadata)
- Check that transfer syntax is supported

### "Surface extraction failed"
- Try adjusting threshold value
- Ensure volume has meaningful data at threshold

## See Also

- `dicom-info` - Display DICOM metadata
- `dicom-convert` - Convert DICOM images
- `dicom-viewer` - View DICOM images in terminal
- `dicom-measure` - Extract measurements

## References

- DICOM PS3.3 - Information Object Definitions
- DICOM PS3.5 - Data Structures and Encoding
- Lorensen & Cline (1987) - Marching Cubes algorithm
- NIfTI-1 Data Format Specification
- MetaImage File Format Documentation

## Version History

### 1.4.0 (Current)
- Initial release
- MPR generation (axial, sagittal, coronal)
- Intensity projections (MIP, MinIP, Average)
- Surface extraction (Marching Cubes)
- Volume export (NIfTI, MetaImage)
- STL/OBJ mesh export

## License

Part of DICOMKit - See LICENSE file for details.

## Support

For issues, questions, or contributions:
- GitHub: https://github.com/Raster-Lab/DICOMKit
- Documentation: See DICOMKit README
