# DICOMKit Examples

This directory contains comprehensive examples demonstrating how to use DICOMKit's Structured Reporting (SR) capabilities. These examples cover common clinical and research workflows for creating, parsing, and working with DICOM SR documents.

## Overview

The examples are organized by SR document type and use case, progressing from simple to complex:

1. **BasicTextSRExample.swift** - Simple narrative reports
2. **EnhancedSRExample.swift** - Reports with measurements and references
3. **ComprehensiveSRExample.swift** - Reports with spatial and temporal coordinates
4. **MeasurementReportExample.swift** - TID 1500 quantitative imaging reports
5. **CADSRExample.swift** - Computer-aided detection results (Mammography & Chest)

## Getting Started

### Prerequisites

- Swift 6.2 or later
- DICOMKit framework
- Xcode 16+ (for iOS/macOS development)

### Running Examples

These examples are provided as reference implementations. To use them in your project:

1. Copy the relevant example file to your project
2. Import DICOMKit: `import DICOMKit`
3. Call the example functions

```swift
import DICOMKit

do {
    // Create a basic text SR document
    let document = try createBasicTextSRExample()
    print("Created report: \(document.documentTitle ?? "Untitled")")
    
    // Serialize and save
    let dataSet = try SRDocumentSerializer.serialize(document)
    let writer = DICOMWriter()
    let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
    try fileData.write(to: URL(fileURLWithPath: "/path/to/output.dcm"))
} catch {
    print("Error: \(error)")
}
```

## Example Details

### 1. Basic Text SR Examples

**File:** `BasicTextSRExample.swift`

Demonstrates creating simple narrative reports with hierarchical sections.

**Use Cases:**
- Radiology reports
- Clinical notes
- Discharge summaries
- Consultation reports

**Key Features:**
- Patient and study demographics
- Hierarchical section structure
- Text content with section headings
- Document completion and verification flags

**Examples:**
- `createBasicTextSRExample()` - Standard radiology report
- `createNestedSectionExample()` - Report with nested subsections
- `saveBasicTextSRExample()` - Saving to DICOM file
- `readBasicTextSRExample()` - Reading and parsing

### 2. Enhanced SR Examples

**File:** `EnhancedSRExample.swift`

Demonstrates reports with numeric measurements, units, and references.

**Use Cases:**
- CT/MR reports with measurements
- Cardiology reports with dimensions
- Laboratory results
- ECG interpretation

**Key Features:**
- Numeric measurements with UCUM units
- Linear, area, and volume measurements
- Image and waveform references
- Measurement extraction and analysis

**Examples:**
- `createCTScanReportWithMeasurements()` - CT scan with organ measurements
- `createLesionCharacterizationReport()` - Detailed lesion measurements
- `createECGReportWithWaveform()` - ECG with waveform reference
- `extractMeasurementsExample()` - Measurement extraction and statistics

### 3. Comprehensive SR Examples

**File:** `ComprehensiveSRExample.swift`

Demonstrates reports with 2D spatial coordinates and temporal analysis.

**Use Cases:**
- Radiology reports with ROI annotations
- Cardiac perfusion analysis
- Radiation therapy planning
- Image analysis with regions

**Key Features:**
- 2D spatial coordinates (points, polylines, polygons, circles, ellipses)
- Temporal coordinates (sample positions, time ranges)
- Image references with frame numbers
- ROI extraction with area/perimeter calculations

**Examples:**
- `createLungNoduleReportWithROI()` - Lung nodule with spatial annotations
- `createCardiacPerfusionReport()` - Time-intensity curve analysis
- `createTumorAnalysisWithMultipleROIs()` - Multi-region tumor characterization
- `extractSpatialCoordinatesExample()` - Coordinate extraction and analysis

### 4. Measurement Report Examples (TID 1500)

**File:** `MeasurementReportExample.swift`

Demonstrates TID 1500 Measurement Reports for structured quantitative imaging.

**Use Cases:**
- Oncology imaging (RECIST measurements)
- Quantitative imaging biomarkers
- AI/ML algorithm outputs
- Clinical trial imaging endpoints

**Key Features:**
- Image Library for source image references
- Measurement Groups with tracking identifiers
- Qualitative evaluations
- RECIST response assessment

**Examples:**
- `createTumorMeasurementReport()` - Multi-lesion tumor tracking
- `createRECISTResponseReport()` - RECIST 1.1 response assessment
- `extractTID1500MeasurementsExample()` - Extracting structured measurements
- `saveTID1500ReportExample()` - Saving and verification

### 5. CAD SR Examples

**File:** `CADSRExample.swift`

Demonstrates Computer-Aided Detection reports for AI/ML integration.

**Use Cases:**
- Mammography screening CAD
- Lung nodule detection CAD
- AI algorithm output encoding
- Clinical decision support

**Key Features:**
- CAD algorithm metadata (name, version, manufacturer)
- Detection findings with confidence scores
- Finding types (mass, calcification, nodule, etc.)
- Spatial location annotations
- Finding characteristics

**Examples:**
- `createMammographyCADReport()` - Breast cancer screening detections
- `createBilateralMammographyCADReport()` - Multiple view correlation
- `createChestCADReport()` - Lung nodule detection
- `createComprehensiveChestCADReport()` - Multi-pathology detection
- `convertAIDetectionsToCADSR()` - AI output conversion
- `extractCADFindingsExample()` - Finding extraction and analysis

## Common Patterns

### Creating an SR Document

All SR builders follow a similar pattern:

```swift
let document = try SRDocumentBuilder()  // or specialized builder
    // Patient Information
    .withPatientID("12345")
    .withPatientName("Doe^John")
    
    // Study Information
    .withStudyInstanceUID("1.2.3...")
    .withStudyDate("20260204")
    
    // Document Content
    .addSection("Findings") { section in
        section.addText("Normal appearance.")
        section.addMeasurementMM(value: 42.5, concept: .diameter)
    }
    
    .build()
```

### Saving to DICOM File

```swift
// Serialize SR document to DICOM data set
let dataSet = try SRDocumentSerializer.serialize(document)

// Write to file
let writer = DICOMWriter()
let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
try fileData.write(to: fileURL)
```

### Reading from DICOM File

```swift
// Read file data
let fileData = try Data(contentsOf: fileURL)

// Parse DICOM data set
let reader = DICOMReader()
let dataSet = try reader.read(data: fileData)

// Parse SR document
let parser = SRDocumentParser()
let document = try parser.parse(dataSet: dataSet)
```

### Extracting Data

```swift
// Use MeasurementExtractor for quantitative data
let extractor = MeasurementExtractor()
let measurements = extractor.extractAllMeasurements(from: document)

// For TID 1500 reports
let report = try MeasurementReport.extract(from: document)

// For CAD SR reports
let findings = try CADFindings.extract(from: document)
```

### Navigating Content Tree

```swift
let navigator = ContentTreeNavigator(document: document)

// Find by concept name
let findingsSection = navigator.findByConceptName(codeMeaning: "Findings").first

// Filter by type
let numericItems = navigator.filter { $0 is NumericContentItem }

// Traverse depth-first
for item in navigator.depthFirstTraversal() {
    // Process each content item
}
```

## Best Practices

### 1. Always Use Validation

Enable validation during build for production code:

```swift
let document = try SRDocumentBuilder(validateOnBuild: true)
    // ... content ...
    .build()
```

### 2. Use Coded Concepts

Prefer coded concepts over free text for interoperability:

```swift
// Good - coded concept
section.addQualitativeEvaluation(
    concept: .findingSite,
    value: CodedConcept(
        codeValue: "39607008",
        codingSchemeDesignator: .snomedCT,
        codeMeaning: "Lung structure"
    )
)

// Avoid - free text only
section.addText("Finding site: Lung")
```

### 3. Include Image References

Link measurements to source images:

```swift
let imageRef = ImageReference(
    referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
    referencedSOPInstanceUID: "1.2.3..."
)

section.addMeasurementMM(
    value: 25.3,
    concept: .diameter,
    imageReference: imageRef
)
```

### 4. Use Tracking Identifiers (TID 1500)

For longitudinal studies, always use tracking identifiers:

```swift
.addMeasurementGroup(
    trackingIdentifier: "LESION-001",
    trackingUID: "1.2.840.113619.2.55.3.TRACK.001"
) { group in
    // ... measurements ...
}
```

### 5. Error Handling

Always wrap SR operations in do-catch blocks:

```swift
do {
    let document = try createReport()
    try saveDocument(document)
} catch let error as SRDocumentError {
    print("SR Error: \(error.localizedDescription)")
} catch let error as DICOMWriterError {
    print("Writer Error: \(error.localizedDescription)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Additional Resources

- **DICOMKit Documentation**: [README.md](../README.md)
- **DICOM Standard**: [DICOM PS3.3 Section C.17](https://dicom.nema.org/medical/dicom/current/output/chtml/part03/sect_C.17.html) - SR Document IODs
- **TID 1500**: [DICOM PS3.16](https://dicom.nema.org/medical/dicom/current/output/chtml/part16/chapter_A.html) - Measurement Report
- **Coding Schemes**: [DICOM PS3.16 Annex D](https://dicom.nema.org/medical/dicom/current/output/chtml/part16/chapter_D.html) - Context Groups

## Support

For questions or issues:
- Review the examples in this directory
- Check the main DICOMKit README
- Refer to the DICOM standard documentation
- File an issue on GitHub

## License

These examples are provided as part of DICOMKit under the MIT License.
