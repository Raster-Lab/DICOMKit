# Getting Started with DICOM Printing

A beginner-friendly guide to printing medical images using DICOMKit's Print Management features.

## Introduction

DICOM Print Management enables medical imaging applications to send images to DICOM-compliant film printers and hard copy devices. This guide will walk you through the basics of printing DICOM images, from simple single-image printing to advanced multi-image layouts.

## Prerequisites

Before you begin, ensure you have:

- DICOMKit installed in your project
- Access to a DICOM Print SCP (printer) - either a real device or a test server like DCM4CHEE or Orthanc
- The printer's network details (hostname/IP, port, AE Title)
- DICOM image data to print

## Your First Print

Let's start with the simplest example: printing a single DICOM image.

### Step 1: Import DICOMNetwork

```swift
import DICOMNetwork
import DICOMCore
```

### Step 2: Configure the Printer Connection

```swift
let printerConfig = PrintConfiguration(
    host: "192.168.1.100",        // Printer IP address
    port: 11112,                   // DICOM port (typically 11112)
    callingAETitle: "WORKSTATION", // Your application's AE Title
    calledAETitle: "PRINT_SCP"     // Printer's AE Title
)
```

### Step 3: Load Your DICOM Image

```swift
import DICOMKit

// Read DICOM file
let dicomFile = try DICOMFile(path: "/path/to/image.dcm")

// Extract pixel data
let pixelData = try dicomFile.extractPixelData()
```

### Step 4: Print the Image

```swift
// Print with default settings
let result = try await DICOMPrintService.printImage(
    configuration: printerConfig,
    imageData: pixelData.data,
    options: .default
)

print("✅ Print job created: \(result.printJobUID)")
print("Film Session UID: \(result.filmSessionUID)")
```

That's it! You've printed your first DICOM image.

## Understanding Print Options

The `.default` option uses standard settings suitable for most images. Let's explore other presets:

### High Quality Printing

For diagnostic images that require maximum quality:

```swift
let result = try await DICOMPrintService.printImage(
    configuration: printerConfig,
    imageData: pixelData.data,
    options: .highQuality
)
```

**High Quality Settings:**
- Film Size: 14×17 inches (largest)
- Medium: Clear film
- Magnification: Cubic (smooth)
- Priority: High

### Mammography Printing

Specialized settings for mammography images:

```swift
let result = try await DICOMPrintService.printImage(
    configuration: printerConfig,
    imageData: mammoPixelData.data,
    options: .mammography
)
```

**Mammography Settings:**
- Film Size: 14×17 inches
- Medium: MAMMO CLEAR film
- Priority: High
- Optimized for high-resolution breast imaging

### Draft Printing

For quick review or non-diagnostic purposes:

```swift
let result = try await DICOMPrintService.printImage(
    configuration: printerConfig,
    imageData: pixelData.data,
    options: .draft
)
```

**Draft Settings:**
- Film Size: 8.5×11 inches (letter)
- Medium: Paper
- Quality: Standard
- Copies: 1

## Custom Print Options

Create your own print configuration:

```swift
let customOptions = PrintOptions(
    filmSize: .size11InX14In,           // Medium film size
    filmOrientation: .landscape,         // Horizontal orientation
    magnificationType: .cubic,           // Smooth interpolation
    mediumType: .blueFilm,              // Blue-tinted film
    numberOfCopies: 2,                   // Print 2 copies
    priority: .high,                     // High priority
    filmDestination: .magazine          // Send to magazine
)

let result = try await DICOMPrintService.printImage(
    configuration: printerConfig,
    imageData: pixelData.data,
    options: customOptions
)
```

### Available Film Sizes

| Size | Description | When to Use |
|------|-------------|-------------|
| `.size8InX10In` | 8×10 inches | Small images |
| `.size10InX12In` | 10×12 inches | Standard format |
| `.size11InX14In` | 11×14 inches | Large format |
| `.size14InX17In` | 14×17 inches | Extra large, diagnostic |
| `.a4` | A4 (210×297 mm) | International |
| `.a3` | A3 (297×420 mm) | Large international |

### Medium Types

- `.paper` - Plain paper (draft prints)
- `.clearFilm` - Clear film (standard)
- `.blueFilm` - Blue-tinted film (radiology preference)
- `.mammoClear` - Mammography clear-base film
- `.mammoBlue` - Mammography blue-base film

## Printing Multiple Images

### Automatic Layout Selection

DICOMKit automatically selects the optimal layout based on image count:

```swift
let images = [image1, image2, image3, image4]

let result = try await DICOMPrintService.printImages(
    configuration: printerConfig,
    images: images,
    options: PrintOptions(filmSize: .size14InX17In)
)
// Automatically uses 2×2 layout for 4 images
```

**Automatic Layouts:**
- 1 image → 1×1 (full film)
- 2 images → 1×2 (side-by-side)
- 3-4 images → 2×2 grid
- 5-6 images → 2×3 grid
- 7-9 images → 3×3 grid
- 10-12 images → 3×4 grid
- 13-16 images → 4×4 grid
- 17-20 images → 4×5 grid

### Side-by-Side Comparison

Perfect for before/after comparisons:

```swift
let comparisonTemplate = ComparisonTemplate()

let result = try await DICOMPrintService.printWithTemplate(
    configuration: printerConfig,
    images: [beforeTreatment, afterTreatment],
    template: comparisonTemplate
)
```

### Grid Layouts

Print multiple images in a grid:

```swift
// 3×3 grid for 9 images
let gridTemplate = GridTemplate(rows: 3, columns: 3)

let result = try await DICOMPrintService.printWithTemplate(
    configuration: printerConfig,
    images: arrayOf9Images,
    template: gridTemplate
)
```

### Multi-Phase Temporal Series

For cardiac studies, dynamic contrast, or temporal imaging:

```swift
// 3 rows × 4 columns = 12 time points
let multiPhaseTemplate = MultiPhaseTemplate(rows: 3, columns: 4)

let result = try await DICOMPrintService.printWithTemplate(
    configuration: printerConfig,
    images: temporalSeriesImages,
    template: multiPhaseTemplate
)
```

## Tracking Print Progress

Monitor printing progress with real-time updates:

```swift
print("Starting print job...")

for try await progress in DICOMPrintService.printImagesWithProgress(
    configuration: printerConfig,
    images: images,
    options: .default
) {
    let percent = Int(progress.progress * 100)
    
    switch progress.phase {
    case .connecting:
        print("📡 Connecting to printer...")
    case .queryingPrinter:
        print("🔍 Querying printer status...")
    case .creatingSession:
        print("📝 Creating film session...")
    case .preparingImages:
        print("🖼️  Preparing images: \(percent)%")
    case .uploadingImages:
        print("⬆️  Uploading: \(progress.current) of \(progress.total) images")
    case .printing:
        print("🖨️  Printing...")
    case .cleanup:
        print("🧹 Cleaning up...")
    case .completed:
        print("✅ Print completed!")
    }
}
```

## Error Handling

Handle common errors gracefully:

```swift
do {
    let result = try await DICOMPrintService.printImage(
        configuration: printerConfig,
        imageData: pixelData.data,
        options: .default
    )
    print("✅ Success: \(result.printJobUID)")
    
} catch let error as PrintError {
    switch error {
    case .printerUnavailable(let message):
        print("❌ Printer offline: \(message)")
        print("💡 Check printer power and network connection")
        
    case .connectionFailed(let message):
        print("❌ Connection failed: \(message)")
        print("💡 Verify printer IP address and port")
        
    case .filmSessionCreationFailed(let statusCode):
        print("❌ Session creation failed: \(statusCode)")
        print("💡 Printer may be out of film or memory")
        
    case .insufficientMemory:
        print("❌ Printer out of memory")
        print("💡 Try printing fewer images or reduce image size")
        
    default:
        print("❌ Print error: \(error.description)")
        print("💡 \(error.recoverySuggestion)")
    }
    
} catch {
    print("❌ Unexpected error: \(error)")
}
```

## Testing with a Print Simulator

If you don't have a physical printer, use DCM4CHEE or Orthanc for testing:

### DCM4CHEE Setup

```bash
# Using Docker
docker run -p 11112:11112 \
    -e PRINT_SCP_AET=PRINT_SCP \
    dcm4che/dcm4chee-arc-psql:5.31.0
```

### Orthanc Setup

```bash
# Using Docker with print plugin
docker run -p 11112:11112 \
    -v ./orthanc-print-config.json:/etc/orthanc/orthanc.json \
    jodogne/orthanc-plugins:latest
```

**orthanc-print-config.json:**
```json
{
  "Name": "Orthanc Print SCP",
  "DicomAet": "PRINT_SCP",
  "DicomPort": 11112,
  "DicomModalities": {},
  "Plugins": ["libOrthancPrint.so"]
}
```

### Verify Printer Connection

Before printing, verify the connection:

```swift
// Query printer status
let status = try await DICOMPrintService.getPrinterStatus(
    configuration: printerConfig
)

print("Printer: \(status.printerName)")
print("Status: \(status.status)")

if status.status == .normal {
    print("✅ Printer ready")
} else {
    print("⚠️ Printer not ready: \(status.statusInfo)")
}
```

## Best Practices for Beginners

### 1. Start Simple

Begin with single images and default options before trying multi-image layouts.

### 2. Test with Simulator First

Use DCM4CHEE or Orthanc to test without wasting film on a real printer.

### 3. Check Printer Status

Always query printer status before printing:

```swift
let status = try await DICOMPrintService.getPrinterStatus(configuration: printerConfig)
guard status.status == .normal else {
    throw PrintError.printerUnavailable(message: status.statusInfo)
}
```

### 4. Use Appropriate Film Sizes

- **CT/MR**: 14×17" for diagnostic viewing
- **Ultrasound**: 11×14" or 10×12"
- **Documentation**: A4 or letter for reports

### 5. Handle Errors Gracefully

Printers can go offline or run out of film. Always handle errors and provide helpful messages to users.

### 6. Track Progress for Long Jobs

For multi-image prints, show progress to keep users informed.

## Next Steps

Now that you're comfortable with basic printing, explore:

- **[Print Workflow Best Practices](PrintWorkflowBestPractices.md)** - Advanced techniques and optimization
- **[Troubleshooting Print Issues](TroubleshootingPrint.md)** - Common problems and solutions
- **[Print Management Guide](../Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md)** - Complete API reference
- **Print Queue Management** - For handling multiple concurrent print jobs
- **Image Preparation Pipeline** - For optimal image quality

## Complete Example

Here's a complete, production-ready example:

```swift
import DICOMKit
import DICOMNetwork

func printDICOMImage(filePath: String, printerHost: String, printerPort: UInt16) async throws {
    // Configure printer
    let config = PrintConfiguration(
        host: printerHost,
        port: printerPort,
        callingAETitle: "MY_APP",
        calledAETitle: "PRINT_SCP"
    )
    
    // Verify printer is available
    let status = try await DICOMPrintService.getPrinterStatus(configuration: config)
    guard status.status == .normal else {
        throw PrintError.printerUnavailable(message: "Printer not ready: \(status.statusInfo)")
    }
    print("✅ Printer ready: \(status.printerName)")
    
    // Load DICOM file
    print("📂 Loading DICOM file...")
    let dicomFile = try DICOMFile(path: filePath)
    let pixelData = try dicomFile.extractPixelData()
    
    // Print with progress tracking
    print("🖨️  Starting print job...")
    var lastPhase: PrintProgress.Phase?
    
    for try await progress in DICOMPrintService.printImagesWithProgress(
        configuration: config,
        images: [pixelData.data],
        options: .highQuality
    ) {
        if progress.phase != lastPhase {
            print("\(progress.phase): \(progress.message)")
            lastPhase = progress.phase
        }
    }
    
    print("✅ Print job completed successfully!")
}

// Usage
Task {
    do {
        try await printDICOMImage(
            filePath: "/path/to/ct_scan.dcm",
            printerHost: "192.168.1.100",
            printerPort: 11112
        )
    } catch {
        print("❌ Print failed: \(error)")
    }
}
```

## Support and Resources

- **API Reference**: See ``DICOMPrintService`` documentation
- **CLI Tool**: Use `dicom-print --help` for command-line operations
- **DICOM Standard**: PS3.4 Annex H - Print Management Service Class
- **GitHub Issues**: Report bugs or request features

Happy printing! 🖨️
