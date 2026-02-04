# AI/ML Integration for DICOM SR Documents

This module provides basic AI/ML integration infrastructure for converting AI inference results to DICOM Structured Reports.

## Current Status

The basic types and infrastructure are in place:
- `AIInferenceResult` protocol for AI model outputs
- `AIDetection`, `AIDetectionType`, `AIDetectionLocation` for representing detections
- `AIImageReference` for referencing source images
- `ConfidenceScore` utilities for encoding confidence levels

## Note

The converters (`AIDetectionToSRConverter`, `SegmentationToSRConverter`) are works-in-progress and may require API adjustments to fully integrate with the existing SR builder infrastructure. 

Users can directly use the existing CAD SR builders (ChestCADSRBuilder, MammographyCADSRBuilder) and Measurement Report builders to create SR documents from AI outputs.

## Example Usage

```swift
// Define your AI results
struct MyAIResult: AIInferenceResult {
    var modelName: String = "MyModel"
    var modelVersion: String = "1.0.0"
    var manufacturer: String = "AI Corp"
    var processingTimestamp: Date = Date()
    var detections: [AIDetection] = []
}

// Create detections manually
let detection = AIDetection(
    type: .lungNodule,
    confidence: 0.95,
    location: .point2D(x: 100, y: 200, imageReference: myImageRef)
)

// Use existing builders to create SR documents
let srDocument = try ChestCADSRBuilder()
    .withPatientID("12345")
    .withStudyInstanceUID("1.2.3.4.5")
    .addFinding(type: .nodule, probability: 0.95, location: ...)
    .build()
```
