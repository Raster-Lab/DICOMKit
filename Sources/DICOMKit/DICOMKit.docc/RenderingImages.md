# Rendering DICOM Images

Learn how to extract, window, and display medical images from DICOM files.

## Overview

Medical images in DICOM files require special handling for display. DICOMKit provides comprehensive support for extracting pixel data, applying windowing transformations, and rendering images for display.

## Extracting Pixel Data

Extract pixel data from a DICOM file:

```swift
import DICOMKit

let dicomFile = try DICOMFile.read(from: data)
let pixelData = try dicomFile.extractPixelData()

// Access image properties
print("Rows: \(pixelData.rows)")
print("Columns: \(pixelData.columns)")
print("Bits Allocated: \(pixelData.bitsAllocated)")
print("Bits Stored: \(pixelData.bitsStored)")
print("High Bit: \(pixelData.highBit)")
print("Photometric: \(pixelData.photometricInterpretation)")
print("Number of Frames: \(pixelData.numberOfFrames)")
```

## Basic Image Rendering

Render an image with default windowing:

```swift
#if canImport(CoreGraphics)
let renderer = PixelDataRenderer(pixelData: pixelData)

// Render the first frame
if let cgImage = renderer.renderFrame(0) {
    // Use in SwiftUI
    let image = Image(cgImage, scale: 1.0, label: Text("DICOM Image"))
}
#endif
```

## Window/Level Adjustment

Apply window center and width for proper contrast:

```swift
// CT: Bone window
let boneWindow = PixelDataRenderer(
    pixelData: pixelData,
    windowCenter: 500,
    windowWidth: 2000
)

// CT: Lung window
let lungWindow = PixelDataRenderer(
    pixelData: pixelData,
    windowCenter: -600,
    windowWidth: 1500
)

// CT: Soft tissue window
let softTissueWindow = PixelDataRenderer(
    pixelData: pixelData,
    windowCenter: 40,
    windowWidth: 400
)
```

### Using Window Settings from File

Use the window settings stored in the DICOM file:

```swift
let renderer = PixelDataRenderer(pixelData: pixelData)

// Get window settings from file
let windowCenter = dicomFile.dataSet.windowCenter ?? 40.0
let windowWidth = dicomFile.dataSet.windowWidth ?? 400.0

// Apply window settings
if let cgImage = renderer.renderFrame(0, 
    windowCenter: windowCenter,
    windowWidth: windowWidth) {
    // Display image
}
```

## Photometric Interpretation

DICOMKit handles different photometric interpretations automatically:

| Interpretation | Description | Handling |
|---------------|-------------|----------|
| MONOCHROME1 | Darker = higher values | Auto-inverted |
| MONOCHROME2 | Brighter = higher values | Direct display |
| RGB | Color (red, green, blue) | Direct color |
| PALETTE COLOR | Indexed color with LUT | LUT applied |
| YBR_FULL | Color in YCbCr space | Converted to RGB |

```swift
let photometric = pixelData.photometricInterpretation

switch photometric {
case .monochrome1:
    print("Inverted grayscale (like X-ray film)")
case .monochrome2:
    print("Standard grayscale")
case .rgb:
    print("Color image")
case .paletteColor:
    print("Palette color with LUT")
default:
    print("Other: \(photometric)")
}
```

## Multi-Frame Images

Render frames from multi-frame images (e.g., CT/MR series, cine clips):

```swift
let numberOfFrames = pixelData.numberOfFrames
print("Total frames: \(numberOfFrames)")

// Render a specific frame
if let frame5 = renderer.renderFrame(5) {
    // Display frame 5
}

// Render all frames
for frameIndex in 0..<numberOfFrames {
    if let image = renderer.renderFrame(frameIndex) {
        // Process or display each frame
    }
}
```

## Image Caching

Use ``ImageCache`` for efficient rendering of frequently accessed images:

```swift
// Create a shared cache
let cache = ImageCache.shared

// Check if image is cached
if let cachedImage = cache.get(key: "study_123_frame_0") {
    // Use cached image
} else {
    // Render and cache
    if let image = renderer.renderFrame(0) {
        cache.set(image, for: "study_123_frame_0")
    }
}
```

Configure cache settings:

```swift
let config = ImageCacheConfiguration.highMemory
let cache = ImageCache(configuration: config)

// Low memory configuration for iOS
let mobileCache = ImageCache(configuration: .lowMemory)
```

## SIMD-Accelerated Rendering

For optimal performance, use SIMD-accelerated processing:

```swift
#if canImport(Accelerate)
import Accelerate

// Apply window/level with SIMD acceleration
let processor = SIMDImageProcessor()
let windowedData = processor.applyWindowLevel(
    pixelData: rawPixels,
    windowCenter: 40,
    windowWidth: 400,
    bitsStored: 12
)
#endif
```

## Rendering to SwiftUI

Complete example for SwiftUI integration:

```swift
import SwiftUI
import DICOMKit

struct DICOMImageView: View {
    let dicomFile: DICOMFile
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    
    var body: some View {
        VStack {
            if let pixelData = try? dicomFile.extractPixelData(),
               let renderer = PixelDataRenderer(pixelData: pixelData),
               let cgImage = renderer.renderFrame(0, 
                   windowCenter: windowCenter, 
                   windowWidth: windowWidth) {
                
                Image(cgImage, scale: 1.0, label: Text("DICOM"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            // Window/Level sliders
            Slider(value: $windowCenter, in: -1000...1000)
            Slider(value: $windowWidth, in: 1...4000)
        }
    }
}
```

## Compressed Pixel Data

DICOMKit automatically decompresses supported formats:

- JPEG Baseline (Process 1)
- JPEG Lossless
- JPEG 2000
- RLE Lossless

```swift
// Compressed data is automatically decompressed
let pixelData = try dicomFile.extractPixelData()

// Check if original was compressed
let transferSyntax = dicomFile.fileMetaInformation[.transferSyntaxUID]?.stringValue
if let ts = TransferSyntax(uid: transferSyntax ?? "") {
    print("Was compressed: \(ts.isCompressed)")
}
```

## See Also

- ``PixelDataRenderer``
- ``PixelData``
- ``WindowSettings``
- ``ImageCache``
- ``PhotometricInterpretation``
