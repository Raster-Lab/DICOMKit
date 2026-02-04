/// Enhanced SR Example
///
/// This example demonstrates how to create DICOM Enhanced SR documents
/// with numeric measurements, coded entries, and image references.
///
/// Enhanced SR supports all Basic Text SR features plus:
/// - NUM: Numeric measurements with units (UCUM codes)
/// - WAVEFORM: Waveform references
/// - IMAGE: Image references with frame numbers
///
/// Use cases:
/// - Radiology reports with measurements
/// - Cardiology reports with dimensions
/// - Structured pathology reports
/// - Laboratory results with quantitative data

import Foundation
import DICOMKit
import DICOMCore

/// Example: CT scan report with organ measurements
func createCTScanReportWithMeasurements() throws -> SRDocument {
    let document = try EnhancedSRBuilder()
        // Patient Information
        .withPatientID("98765432")
        .withPatientName("Johnson^Michael^^^")
        .withPatientBirthDate("19751122")
        .withPatientSex("M")
        
        // Study Information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.987654321.200")
        .withStudyDate("20260204")
        .withStudyTime("103000")
        .withStudyDescription("CT Chest with Contrast")
        .withAccessionNumber("ACC987654")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.987654321.201")
        .withSeriesNumber("1")
        .withModality("SR")
        
        // Document Information
        .withDocumentTitle("CT Scan Report with Measurements")
        .withCompletionFlag(.complete)
        .withVerificationFlag(.verified)
        
        // Clinical History
        .addSection("Clinical History") { section in
            section.addText("Suspicion of pulmonary embolism. Shortness of breath.")
        }
        
        // Technique
        .addSection("Technique") { section in
            section.addText("CT chest performed with IV contrast.")
            section.addMeasurementMM(value: 100.0, concept: .contrastVolume)
        }
        
        // Findings with measurements
        .addSection("Findings") { section in
            section.addSection("Lungs") { lungSection in
                lungSection.addText("A small nodule is identified in the right upper lobe.")
                
                // Nodule measurements
                lungSection.addMeasurementMM(
                    value: 8.5,
                    concept: .diameter,
                    description: "Nodule diameter"
                )
                
                lungSection.addMeasurementMM(
                    value: 7.2,
                    concept: .length,
                    description: "Nodule length"
                )
            }
            
            section.addSection("Mediastinum") { medSection in
                medSection.addText("Normal mediastinal structures.")
                
                // Lymph node measurement
                medSection.addMeasurementMM(
                    value: 12.0,
                    concept: .diameter,
                    description: "Subcarinal lymph node"
                )
            }
            
            section.addSection("Heart") { heartSection in
                heartSection.addText("Heart size is within normal limits.")
                
                // Cardiac dimensions
                heartSection.addMeasurementCM(
                    value: 4.8,
                    concept: .diameter,
                    description: "Transverse cardiac diameter"
                )
            }
        }
        
        // Impression
        .addSection("Impression") { section in
            section.addText("1. Small right upper lobe pulmonary nodule, measuring 8.5 mm.")
            section.addText("2. Borderline enlarged subcarinal lymph node.")
            section.addText("3. No evidence of pulmonary embolism.")
        }
        
        .build()
    
    return document
}

/// Example: Lesion characterization with multiple measurements
func createLesionCharacterizationReport() throws -> SRDocument {
    let document = try EnhancedSRBuilder()
        .withPatientID("55544433")
        .withPatientName("Williams^Sarah^^^")
        .withDocumentTitle("Liver Lesion Characterization")
        
        .addSection("Findings") { section in
            section.addText("A heterogeneous mass is identified in segment 7 of the liver.")
            
            // Create a measurement group for the lesion
            section.addSection("Lesion Measurements") { measurements in
                // Linear dimensions
                measurements.addMeasurementMM(
                    value: 42.3,
                    concept: .diameter,
                    description: "Maximum diameter"
                )
                
                measurements.addMeasurementMM(
                    value: 38.1,
                    concept: .diameter,
                    description: "Perpendicular diameter"
                )
                
                // Area measurement (in mm²)
                measurements.addMeasurement(
                    value: 1250.5,
                    units: "mm2",
                    concept: .area,
                    description: "Cross-sectional area"
                )
                
                // Volume measurement (in mm³)
                measurements.addMeasurement(
                    value: 35420.0,
                    units: "mm3",
                    concept: .volume,
                    description: "Lesion volume"
                )
                
                // Attenuation value (HU)
                measurements.addMeasurement(
                    value: 65.0,
                    units: "[hnsf'U]",  // Hounsfield units in UCUM
                    concept: CodedConcept(
                        codeValue: "112033",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Attenuation Coefficient"
                    ),
                    description: "Mean attenuation"
                )
            }
        }
        
        .addSection("Impression") { section in
            section.addText("Hepatic mass measuring 42.3 × 38.1 mm, " +
                          "volume 35.4 cm³. Consider further evaluation with MRI.")
        }
        
        .build()
    
    return document
}

/// Example: ECG report with waveform reference
func createECGReportWithWaveform() throws -> SRDocument {
    // Image/waveform reference
    let waveformReference = WaveformReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.9.1.1",  // 12-lead ECG Waveform
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.111222333.500"
    )
    
    let document = try EnhancedSRBuilder()
        .withPatientID("33344455")
        .withPatientName("Brown^David^^^")
        .withDocumentTitle("ECG Interpretation")
        
        .addSection("ECG Findings") { section in
            // Add waveform reference
            section.addWaveform(
                reference: waveformReference,
                concept: CodedConcept(
                    codeValue: "11524-6",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "EKG study"
                )
            )
            
            // Heart rate measurement
            section.addMeasurement(
                value: 72.0,
                units: "/min",
                concept: CodedConcept(
                    codeValue: "8867-4",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "Heart rate"
                ),
                description: "Heart rate"
            )
            
            // PR interval (milliseconds)
            section.addMeasurement(
                value: 160.0,
                units: "ms",
                concept: CodedConcept(
                    codeValue: "8625-6",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "PR interval"
                ),
                description: "PR interval"
            )
            
            // QRS duration
            section.addMeasurement(
                value: 92.0,
                units: "ms",
                concept: CodedConcept(
                    codeValue: "8633-0",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "QRS duration"
                ),
                description: "QRS duration"
            )
            
            // QT interval
            section.addMeasurement(
                value: 400.0,
                units: "ms",
                concept: CodedConcept(
                    codeValue: "8634-8",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "QT interval"
                ),
                description: "QT interval"
            )
        }
        
        .addSection("Interpretation") { section in
            section.addText("Normal sinus rhythm.")
            section.addText("Normal PR, QRS, and QT intervals.")
            section.addText("No ST-T wave abnormalities.")
        }
        
        .build()
    
    return document
}

/// Example: Extracting measurements from an Enhanced SR document
func extractMeasurementsExample() throws {
    // Create a sample document with measurements
    let document = try createLesionCharacterizationReport()
    
    // Use MeasurementExtractor to get all measurements
    let extractor = MeasurementExtractor()
    let measurements = extractor.extractAllMeasurements(from: document)
    
    print("Found \(measurements.count) measurements:")
    for measurement in measurements {
        let value = measurement.value
        let unit = measurement.unit
        let concept = measurement.concept?.codeMeaning ?? "Unknown"
        print("  \(concept): \(value) \(unit)")
    }
    
    // Calculate statistics
    let diameterMeasurements = measurements.filter { measurement in
        measurement.concept?.codeMeaning?.contains("diameter") ?? false
    }
    
    if !diameterMeasurements.isEmpty {
        let stats = extractor.computeStatistics(diameterMeasurements)
        print("\nDiameter statistics:")
        print("  Mean: \(stats.mean) \(diameterMeasurements[0].unit)")
        print("  Std Dev: \(stats.standardDeviation)")
        print("  Min: \(stats.minimum)")
        print("  Max: \(stats.maximum)")
    }
}

// MARK: - Usage Examples

/*
 To use these Enhanced SR examples:
 
 1. Create a CT report with measurements:
 
    do {
        let report = try createCTScanReportWithMeasurements()
        print("Created CT report with \(report.content.count) sections")
    } catch {
        print("Error: \(error)")
    }
 
 2. Create a lesion characterization report:
 
    let report = try createLesionCharacterizationReport()
    let dataSet = try SRDocumentSerializer.serialize(report)
    
    // Write to file
    let writer = DICOMWriter()
    let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
    try fileData.write(to: URL(fileURLWithPath: "/tmp/lesion_report.dcm"))
 
 3. Extract and analyze measurements:
 
    try extractMeasurementsExample()
 
 4. Query for specific measurements:
 
    let document = try createCTScanReportWithMeasurements()
    let navigator = ContentTreeNavigator(document: document)
    
    // Find all numeric content items
    let numericItems = navigator.filter { item in
        item is NumericContentItem
    }
    
    print("Found \(numericItems.count) numeric measurements")
    
    for item in numericItems {
        if let numItem = item as? NumericContentItem {
            let concept = numItem.conceptName?.codeMeaning ?? "Unknown"
            let value = numItem.numericValue
            let unit = numItem.measurementUnits?.codeMeaning ?? ""
            print("\(concept): \(value) \(unit)")
        }
    }
 */
