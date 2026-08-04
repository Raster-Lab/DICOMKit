# Rendering DICOM Images

Learn how to extract, window, and display medical images from DICOM files.

## Overview

Medical images in DICOM files require special handling for display. DICOMKit provides comprehensive support for extracting pixel data, applying windowing transformations, and rendering images for display.

## Extracting Pixel Data

Extract pixel data from a DICOM file:

```swift
import DICOMKit

let dicomFile = try DICOMFile.read(from: data)
let pixelData = try dicomFile.tryPixelData()

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
            if let pixelData = try? dicomFile.tryPixelData(),
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
let pixelData = try dicomFile.tryPixelData()

// Check if original was compressed
let transferSyntax = dicomFile.fileMetaInformation[.transferSyntaxUID]?.stringValue
if let ts = TransferSyntax(uid: transferSyntax ?? "") {
    print("Was compressed: \(ts.isCompressed)")
}
```

## How a frame becomes a picture

Every value-mapping decision — bit shift, stored-bit mask, sign extension, the VOI
window, MONOCHROME1 inversion, the colour normalise, the palette lookup — depends on
exactly one variable: the raw sample assembled from the frame bytes. Nothing else in
the chain varies per pixel.

So none of it is evaluated per pixel. `WindowLUT` (and its colour siblings
`ColorSampleLUT` and `PaletteDisplayLUT`, all in `DICOMCore`) evaluate the whole
chain once per *possible* sample — 256 or 65,536 values — and the render becomes a
table lookup. A 3000×4000 mammogram goes from 12 million window evaluations to
65,536, and `SIGMOID` stops costing more than `LINEAR` because `exp()` is called
65,536 times regardless of image size.

The tables are built by calling `WindowSettings.apply` — the same code the scalar
loop called — so the bytes they produce are identical to what the renderer produced
before them, by construction rather than by testing.

## GPU rendering

`DICOMRenderKit` adds a Metal backend for on-screen rendering. It is a separate
target: the headless `dicom-*` executables never link Metal, and CI without a GPU is
unaffected.

The shader does **no floating-point work at all**. It reads the byte tables above,
so GPU output is bit-identical to CPU output — which is what lets the app render on
the GPU while `dicom-export`, `dicom-convert` and the print film burn stay on the
CPU without the two ever disagreeing.

```swift
import DICOMRenderKit

let image = FrameRenderService.shared.renderFrame(
    FrameRenderRequest(pixelData: pixelData, frameIndex: 0, window: window)
)
```

`FrameRenderService` picks a backend and always falls back to the CPU. The GPU is
used only when it is both available and worth it; these cases stay on the CPU by
design, not by omission:

| Case | Why |
|---|---|
| Frames under 1 megapixel | A dispatch costs ~0.24 ms whatever the size; below ~0.5 MP the CPU is measurably faster. Covers tiles and thumbnails. |
| YBR colour | Green depends on all three of Y, Cb and Cr, so no table smaller than 2^24 entries reproduces the CPU's `Double` arithmetic exactly. Float would diverge by a grey level. |
| Auto-windowed frames (no explicit window) | Choosing the window is a policy decision, and there must be exactly one implementation of it. |
| Non-unified-memory GPUs | The copies across a bus cost more than they save. `RenderBackend.automatic()` returns `.cpu`. |
| Export, convert, print film | The shared CLI↔app surface. They inherit the table speedup and must not diverge. |

On Apple Silicon nothing is copied: decoded frames are page-aligned once when they
enter the cache and wrapped in place with `makeBuffer(bytesNoCopy:)`, and the
`CGImage` is backed by the very buffer the shader wrote. A steady-state window drag
allocates nothing and copies no pixel data — asserted by test, not by convention.

### Keeping the frame on the GPU

The viewport can draw straight from a texture rather than a `CGImage`:

```swift
if let rendered = FrameRenderService.shared.displayRenderer?.renderForDisplay(request) {
    // rendered.texture — for MetalImageView
    // rendered.image   — the same pixels, same memory, for everything else
}
```

`MetalImageView` draws that texture with a `DisplayPresentation`: zoom, pan,
rotation, flip and inversion become a 4×4 matrix in the vertex shader and a `1 - x`
in the fragment shader. Changing any of them redraws a textured quad — **0.008 ms on
a 3000×4000 mammogram** — and re-renders nothing. Before this they were CPU
`CGContext` passes over every pixel.

The display shaders are the only floating-point code in `FrameRender.metal`, and
they handle *geometry* only: nothing there can change what value a pixel has, just
where it lands. Inversion is exact — `1 - x` on an 8-bit unorm round-trips through
the same 256 levels. The sampler is `nearest`, matching the `shouldInterpolate:
false` the viewer has always built its images with, so zooming shows real pixels
rather than a smoothed guess.

Frames carrying overlay planes keep the `CGImage` path: overlays are burned into the
image, and a Secondary Capture whose entire content lives in a 1-bit overlay would
otherwise present as a blank square.

Set `DICOMKIT_RENDER_BACKEND=cpu` to force the CPU renderer. It outranks every
in-code preference, including a hard-coded `.metal`.

## See Also

- ``PixelDataRenderer``
- ``PixelData``
- ``WindowSettings``
- ``ImageCache``
- ``PhotometricInterpretation``
