/// Measurement Report (TID 1500) Example
///
/// This example demonstrates how to create DICOM TID 1500 Measurement Reports
/// for structured quantitative imaging results. TID 1500 is widely used in:
///
/// - Oncology imaging (RECIST measurements)
/// - Quantitative imaging biomarkers
/// - AI/ML algorithm outputs
/// - Clinical trials with imaging endpoints
///
/// TID 1500 provides a standardized structure for:
/// - Image Library: Source images for measurements
/// - Measurement Groups: Logically grouped measurements with tracking IDs
/// - Qualitative Evaluations: Non-numeric assessments
///
/// Reference: DICOM PS3.16 TID 1500 - Measurement Report

import Foundation
import DICOMKit
import DICOMCore

/// Example: Tumor measurement report for oncology follow-up
func createTumorMeasurementReport() throws -> SRDocument {
    // Reference images for measurements
    let baselineImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.BASELINE.100"
    )
    
    let followupImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.FOLLOWUP.100"
    )
    
    let document = try MeasurementReportBuilder()
        // Patient Information
        .withPatientID("11122233")
        .withPatientName("Thompson^Jennifer^^^")
        .withPatientBirthDate("19680420")
        .withPatientSex("F")
        
        // Study Information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.STUDY.400")
        .withStudyDate("20260204")
        .withStudyTime("140000")
        .withStudyDescription("CT Chest/Abdomen/Pelvis with Contrast")
        .withAccessionNumber("ACC112233")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.SERIES.401")
        .withSeriesNumber("3")
        .withModality("SR")
        
        // Document Information
        .withDocumentTitle(.imagingMeasurementReport)
        .withCompletionFlag(.complete)
        .withVerificationFlag(.verified)
        
        // Image Library
        .addToImageLibrary(baselineImage, description: "Baseline CT, Series 1")
        .addToImageLibrary(followupImage, description: "Follow-up CT, Series 2")
        
        // Procedure Information
        .withProcedureReported(
            CodedConcept(
                codeValue: "241615005",
                codingSchemeDesignator: .snomedCT,
                codeMeaning: "CT of chest, abdomen and pelvis"
            )
        )
        
        // Measurement Group 1: Target Lesion in Lung
        .addMeasurementGroup(
            trackingIdentifier: "LESION-001",
            trackingUID: "1.2.840.113619.2.55.3.TRACK.001"
        ) { group in
            // Lesion location
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "363698007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Finding site"
                ),
                value: CodedConcept(
                    codeValue: "31094006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Structure of lobe of lung"
                )
            )
            
            // Long axis measurement
            group.addLength(
                value: 42.5,
                unit: .millimeters,
                imageReference: followupImage
            )
            
            // Short axis measurement
            group.addLength(
                value: 31.2,
                unit: .millimeters,
                imageReference: followupImage,
                derivation: .manual
            )
            
            // Calculated volume
            group.addVolume(
                value: 27800.0,
                unit: .cubicMillimeters,
                derivation: .calculated
            )
        }
        
        // Measurement Group 2: Target Lesion in Liver
        .addMeasurementGroup(
            trackingIdentifier: "LESION-002",
            trackingUID: "1.2.840.113619.2.55.3.TRACK.002"
        ) { group in
            // Lesion location
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "363698007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Finding site"
                ),
                value: CodedConcept(
                    codeValue: "10200004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Liver structure"
                )
            )
            
            // Measurements
            group.addLength(
                value: 38.1,
                unit: .millimeters,
                imageReference: followupImage
            )
            
            group.addLength(
                value: 29.5,
                unit: .millimeters,
                imageReference: followupImage
            )
            
            group.addArea(
                value: 890.0,
                unit: .squareMillimeters,
                derivation: .calculated
            )
        }
        
        // Measurement Group 3: Non-target Lesion
        .addMeasurementGroup(
            trackingIdentifier: "LESION-003",
            trackingUID: "1.2.840.113619.2.55.3.TRACK.003"
        ) { group in
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "363698007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Finding site"
                ),
                value: CodedConcept(
                    codeValue: "181268008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Mediastinal lymph node structure"
                )
            )
            
            // Non-target lesion status
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "121071",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Finding"
                ),
                value: CodedConcept(
                    codeValue: "126730009",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Present"
                )
            )
        }
        
        .build()
    
    return document
}

/// Example: RECIST 1.1 response assessment
func createRECISTResponseReport() throws -> SRDocument {
    let currentImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.CURRENT.200"
    )
    
    let document = try MeasurementReportBuilder()
        .withPatientID("33344455")
        .withPatientName("Rodriguez^Carlos^^^")
        .withDocumentTitle(.imagingMeasurementReport)
        
        .addToImageLibrary(currentImage, description: "Current follow-up CT")
        
        // Target lesion 1
        .addMeasurementGroup(
            trackingIdentifier: "TARGET-1",
            trackingUID: "1.2.840.113619.2.55.3.T1.UID"
        ) { group in
            // Current measurement
            group.addLength(
                value: 18.5,
                unit: .millimeters,
                imageReference: currentImage
            )
            
            // Percent change from baseline
            group.addMeasurement(
                value: -56.5,
                unit: .percent,
                concept: CodedConcept(
                    codeValue: "121402",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Percent Change from Baseline"
                )
            )
        }
        
        // Target lesion 2
        .addMeasurementGroup(
            trackingIdentifier: "TARGET-2",
            trackingUID: "1.2.840.113619.2.55.3.T2.UID"
        ) { group in
            group.addLength(
                value: 22.1,
                unit: .millimeters,
                imageReference: currentImage
            )
            
            group.addMeasurement(
                value: -42.3,
                unit: .percent,
                concept: CodedConcept(
                    codeValue: "121402",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Percent Change from Baseline"
                )
            )
        }
        
        // Overall RECIST response
        .addMeasurementGroup(
            trackingIdentifier: "OVERALL-RESPONSE",
            trackingUID: "1.2.840.113619.2.55.3.RESPONSE.UID"
        ) { group in
            // Sum of target lesions
            group.addLength(
                value: 40.6,
                unit: .millimeters,
                concept: CodedConcept(
                    codeValue: "121401",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Sum of longest diameters"
                )
            )
            
            // Overall percent change
            group.addMeasurement(
                value: -49.2,
                unit: .percent,
                concept: CodedConcept(
                    codeValue: "121402",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Percent Change from Baseline"
                )
            )
            
            // RECIST response category
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "121050",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Response"
                ),
                value: CodedConcept(
                    codeValue: "121059",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Partial Response"
                )
            )
        }
        
        .build()
    
    return document
}

/// Example: Extracting measurements from a TID 1500 report
func extractTID1500MeasurementsExample() throws {
    let document = try createTumorMeasurementReport()
    
    // Extract the measurement report structure
    let report = try MeasurementReport.extract(from: document)
    
    print("Measurement Report: \(report.documentTitle ?? "Untitled")")
    print("Image Library: \(report.imageLibraryEntries.count) images")
    print("Measurement Groups: \(report.measurementGroups.count)\n")
    
    // Iterate through measurement groups
    for (index, group) in report.measurementGroups.enumerated() {
        print("Group \(index + 1):")
        print("  Tracking ID: \(group.trackingIdentifier ?? "None")")
        print("  Tracking UID: \(group.trackingUID ?? "None")")
        print("  Measurements: \(group.measurements.count)")
        
        for measurement in group.measurements {
            let concept = measurement.concept?.codeMeaning ?? "Unknown"
            let value = measurement.value
            let unit = measurement.unit
            print("    \(concept): \(value) \(unit)")
        }
        
        if !group.qualitativeEvaluations.isEmpty {
            print("  Qualitative Evaluations: \(group.qualitativeEvaluations.count)")
            for eval in group.qualitativeEvaluations {
                let concept = eval.concept?.codeMeaning ?? "Unknown"
                let value = eval.value?.codeMeaning ?? "Unknown"
                print("    \(concept): \(value)")
            }
        }
        
        print("")
    }
}

/// Example: Saving and loading TID 1500 reports
func saveTID1500ReportExample() throws {
    // Create the measurement report
    let document = try createRECISTResponseReport()
    
    // Serialize to DICOM
    let dataSet = try SRDocumentSerializer.serialize(document)
    
    // Write to file
    let writer = DICOMWriter()
    let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
    
    let fileURL = URL(fileURLWithPath: "/tmp/tid1500_recist_report.dcm")
    try fileData.write(to: fileURL)
    
    print("TID 1500 report saved to: \(fileURL.path)")
    
    // Read back and verify
    let readData = try Data(contentsOf: fileURL)
    let reader = DICOMReader()
    let readDataSet = try reader.read(data: readData)
    
    let parser = SRDocumentParser()
    let parsedDoc = try parser.parse(dataSet: readDataSet)
    
    // Extract and verify
    let report = try MeasurementReport.extract(from: parsedDoc)
    print("Verified: Found \(report.measurementGroups.count) measurement groups")
}

// MARK: - Usage Examples

/*
 To use these TID 1500 Measurement Report examples:
 
 1. Create a tumor measurement report:
 
    do {
        let report = try createTumorMeasurementReport()
        print("Created measurement report with tracking identifiers")
        
        // Access image library
        let navigator = ContentTreeNavigator(document: report)
        // Find image library entries...
        
    } catch {
        print("Error: \(error)")
    }
 
 2. Create a RECIST response assessment:
 
    let report = try createRECISTResponseReport()
    
    // Extract the structured report
    let measurementReport = try MeasurementReport.extract(from: report)
    
    // Find the overall response
    for group in measurementReport.measurementGroups {
        if group.trackingIdentifier == "OVERALL-RESPONSE" {
            for eval in group.qualitativeEvaluations {
                if eval.concept?.codeMeaning?.contains("Response") ?? false {
                    print("RECIST Response: \(eval.value?.codeMeaning ?? "Unknown")")
                }
            }
        }
    }
 
 3. Extract and analyze measurements:
 
    try extractTID1500MeasurementsExample()
 
 4. Save and reload:
 
    try saveTID1500ReportExample()
 
 5. Query for specific tracking identifier:
 
    let document = try createTumorMeasurementReport()
    let report = try MeasurementReport.extract(from: document)
    
    // Find a specific lesion by tracking ID
    if let lesion001 = report.measurementGroups.first(where: {
        $0.trackingIdentifier == "LESION-001"
    }) {
        print("Found lesion 001:")
        print("  Measurements: \(lesion001.measurements.count)")
        
        // Get the long axis measurement
        if let longAxis = lesion001.measurements.first(where: {
            $0.concept?.codeMeaning?.contains("Length") ?? false
        }) {
            print("  Size: \(longAxis.value) \(longAxis.unit)")
        }
    }
 
 6. Calculate summary statistics across all target lesions:
 
    let document = try createRECISTResponseReport()
    let report = try MeasurementReport.extract(from: document)
    
    var totalDiameter = 0.0
    var lesionCount = 0
    
    for group in report.measurementGroups {
        if group.trackingIdentifier?.hasPrefix("TARGET") ?? false {
            for measurement in group.measurements {
                if measurement.unit == "mm" {
                    totalDiameter += measurement.value
                    lesionCount += 1
                }
            }
        }
    }
    
    if lesionCount > 0 {
        let averageDiameter = totalDiameter / Double(lesionCount)
        print("Average target lesion diameter: \(averageDiameter) mm")
        print("Sum of diameters: \(totalDiameter) mm")
    }
 */
