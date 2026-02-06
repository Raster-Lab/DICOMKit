/// Playground 4.3: Measurement Reports (TID 1500)
///
/// This playground demonstrates how to create and read DICOM TID 1500 Measurement Reports.
/// These reports are widely used in oncology imaging (RECIST), clinical trials,
/// quantitative imaging biomarkers, and AI/ML algorithm outputs.
///
/// Topics covered:
/// - Creating TID 1500 measurement reports
/// - Adding measurement groups with tracking identifiers
/// - Length, area, and volume measurements
/// - Qualitative evaluations
/// - Image library references
/// - Finding site and laterality
/// - Measurement derivations (e.g., tumor burden)
/// - Reading and extracting measurements

import Foundation
import DICOMKit
import DICOMCore

// MARK: - Example 1: Simple Tumor Measurement

/// Create a basic tumor measurement report
func example1_simpleTumorMeasurement() throws {
    // Reference to the source image
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.IMG.100"
    )
    
    let document = try MeasurementReportBuilder()
        // Patient information
        .withPatientID("ONCO001")
        .withPatientName("Smith^John^^^")
        .withPatientBirthDate("19650312")
        .withPatientSex("M")
        
        // Study information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.STUDY.100")
        .withStudyDate("20260204")
        .withStudyTime("140000")
        .withStudyDescription("CT Chest/Abdomen/Pelvis")
        .withAccessionNumber("ACC001")
        
        // Series information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.SERIES.100")
        .withSeriesNumber("1")
        .withModality("SR")
        
        // Document title (TID 1500)
        .withDocumentTitle(.imagingMeasurementReport)
        
        // Image library - source images for measurements
        .addToImageLibrary(ctImage, description: "Baseline CT Series 2")
        
        // Measurement group
        .addMeasurementGroup(
            trackingIdentifier: "TUMOR-001",
            trackingUID: "1.2.840.113619.2.55.3.TRACK.001"
        ) { group in
            // Finding site
            group.addFindingSite(
                CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                ),
                laterality: .right
            )
            
            // Long axis measurement
            group.addLength(
                value: 35.2,
                unit: .millimeters,
                imageReference: ctImage
            )
        }
        
        .build()
    
    print("Created simple tumor measurement report")
    print("Tracking ID: TUMOR-001")
    print("Length: 35.2 mm")
}

// MARK: - Example 2: RECIST 1.1 Target Lesion

/// Create a RECIST 1.1 compliant target lesion measurement
func example2_recistTargetLesion() throws {
    let baselineImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.BASELINE.100"
    )
    
    let document = try MeasurementReportBuilder()
        .withPatientID("RECIST001")
        .withPatientName("Jones^Mary^^^")
        .withDocumentTitle(.imagingMeasurementReport)
        
        // Procedure reported
        .withProcedureReported(
            CodedConcept(
                codeValue: "241615005",
                codingSchemeDesignator: .snomedCT,
                codeMeaning: "CT of chest, abdomen and pelvis"
            )
        )
        
        // Image library
        .addToImageLibrary(baselineImage, description: "Baseline CT")
        
        // Target lesion measurement group
        .addMeasurementGroup(
            trackingIdentifier: "TARGET-001",
            trackingUID: "1.2.840.113619.2.55.3.T001"
        ) { group in
            // Activity session for tracking across timepoints
            group.withActivitySession("BASELINE")
            
            // Finding site: Right lung, upper lobe
            group.addFindingSite(
                CodedConcept(
                    codeValue: "45653009",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Structure of upper lobe of right lung"
                )
            )
            
            // Finding category: Target lesion
            group.addCategory(
                CodedConcept(
                    codeValue: "385425000",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Target lesion"
                )
            )
            
            // Long axis diameter
            group.addLength(
                value: 42.5,
                unit: .millimeters,
                imageReference: baselineImage,
                derivation: CodedConcept(
                    codeValue: "410668003",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Longest diameter"
                )
            )
            
            // Short axis diameter (perpendicular)
            group.addLength(
                value: 28.3,
                unit: .millimeters,
                imageReference: baselineImage,
                derivation: CodedConcept(
                    codeValue: "103339001",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Short axis"
                )
            )
        }
        
        .build()
    
    print("Created RECIST 1.1 target lesion measurement")
}

// MARK: - Example 3: Multiple Lesions with Sum

/// Measure multiple lesions and calculate sum of diameters
func example3_multipleLesionsWithSum() throws {
    let ctImage1 = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.IMG.101"
    )
    
    let ctImage2 = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.IMG.102"
    )
    
    let document = try MeasurementReportBuilder()
        .withPatientID("MULTI001")
        .withPatientName("Davis^Robert^^^")
        .withDocumentTitle(.imagingMeasurementReport)
        
        // Image library
        .addToImageLibrary(ctImage1, description: "Chest CT Series 2")
        .addToImageLibrary(ctImage2, description: "Abdomen CT Series 3")
        
        // Lesion 1: Lung
        .addMeasurementGroup(
            trackingIdentifier: "LESION-001",
            trackingUID: "1.2.840.113619.2.55.3.L001"
        ) { group in
            group.addFindingSite(
                CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                ),
                laterality: .right
            )
            
            group.addLength(value: 42.5, unit: .millimeters, imageReference: ctImage1)
        }
        
        // Lesion 2: Liver
        .addMeasurementGroup(
            trackingIdentifier: "LESION-002",
            trackingUID: "1.2.840.113619.2.55.3.L002"
        ) { group in
            group.addFindingSite(
                CodedConcept(
                    codeValue: "10200004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Liver structure"
                )
            )
            
            group.addLength(value: 35.8, unit: .millimeters, imageReference: ctImage2)
        }
        
        // Lesion 3: Lymph node
        .addMeasurementGroup(
            trackingIdentifier: "LESION-003",
            trackingUID: "1.2.840.113619.2.55.3.L003"
        ) { group in
            group.addFindingSite(
                CodedConcept(
                    codeValue: "59441001",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Structure of lymph node"
                )
            )
            
            group.addLength(value: 18.2, unit: .millimeters, imageReference: ctImage1)
        }
        
        // Summary: Sum of target lesions
        .addSummaryMeasurement { summary in
            summary.addDerivedMeasurement(
                concept: CodedConcept(
                    codeValue: "416406003",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Sum of measurements"
                ),
                value: 96.5,  // 42.5 + 35.8 + 18.2
                unit: .millimeters,
                derivedFrom: ["LESION-001", "LESION-002", "LESION-003"]
            )
        }
        
        .build()
    
    print("Created multi-lesion report with sum")
    print("Total burden: 96.5 mm")
}

// MARK: - Example 4: Volume Measurements

/// Add volumetric measurements (e.g., from segmentation)
func example4_volumeMeasurements() throws {
    let mrImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.4",  // MR Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.MR.200"
    )
    
    let document = try MeasurementReportBuilder()
        .withPatientID("VOL001")
        .withPatientName("Wilson^Emma^^^")
        .withDocumentTitle(.imagingMeasurementReport)
        
        .addToImageLibrary(mrImage, description: "T1 MR Brain")
        
        .addMeasurementGroup(
            trackingIdentifier: "TUMOR-VOLUME",
            trackingUID: "1.2.840.113619.2.55.3.VOL.001"
        ) { group in
            // Finding site: Brain
            group.addFindingSite(
                CodedConcept(
                    codeValue: "12738006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Brain structure"
                )
            )
            
            // Volume measurement
            group.addVolume(
                value: 12.5,
                unit: CodedConcept(
                    codeValue: "cm3",
                    codingSchemeDesignator: .ucum,
                    codeMeaning: "cubic centimeter"
                ),
                imageReference: mrImage,
                derivation: CodedConcept(
                    codeValue: "118565006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Volume"
                )
            )
            
            // Derived maximum diameter
            group.addLength(
                value: 28.4,
                unit: .millimeters,
                derivation: CodedConcept(
                    codeValue: "410668003",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Longest diameter"
                )
            )
        }
        
        .build()
    
    print("Created volume measurement report")
}

// MARK: - Example 5: Qualitative Evaluations

/// Add qualitative (non-numeric) assessments
func example5_qualitativeEvaluations() throws {
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.CT.300"
    )
    
    let document = try MeasurementReportBuilder()
        .withPatientID("QUAL001")
        .withPatientName("Brown^Lisa^^^")
        .withDocumentTitle(.imagingMeasurementReport)
        
        .addToImageLibrary(ctImage, description: "Follow-up CT")
        
        .addMeasurementGroup(
            trackingIdentifier: "LESION-EVAL",
            trackingUID: "1.2.840.113619.2.55.3.E001"
        ) { group in
            group.addFindingSite(
                CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                )
            )
            
            // Qualitative size assessment
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "246115007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lesion size"
                ),
                value: CodedConcept(
                    codeValue: "260400001",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Decreased"
                )
            )
            
            // Enhancement pattern
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "129749001",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Enhancement pattern"
                ),
                value: CodedConcept(
                    codeValue: "255374006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Homogeneous"
                )
            )
            
            // Response assessment (RECIST)
            group.addQualitativeEvaluation(
                concept: CodedConcept(
                    codeValue: "385377005",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Treatment response"
                ),
                value: CodedConcept(
                    codeValue: "268910001",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Partial response"
                )
            )
            
            // Numeric measurement for reference
            group.addLength(value: 28.5, unit: .millimeters, imageReference: ctImage)
        }
        
        .build()
    
    print("Created qualitative evaluation report")
}

// MARK: - Example 6: Temporal Comparison

/// Compare measurements across timepoints
func example6_temporalComparison() throws {
    let baselineImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.BASE.100"
    )
    
    let followupImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.FOLLOW.100"
    )
    
    let document = try MeasurementReportBuilder()
        .withPatientID("TEMP001")
        .withPatientName("Taylor^Chris^^^")
        .withDocumentTitle(.imagingMeasurementReport)
        
        .addToImageLibrary(baselineImage, description: "Baseline (Jan 2026)")
        .addToImageLibrary(followupImage, description: "Follow-up (Feb 2026)")
        
        // Baseline measurement
        .addMeasurementGroup(
            trackingIdentifier: "LESION-001-BASELINE",
            trackingUID: "1.2.840.113619.2.55.3.TB.001"
        ) { group in
            group.withActivitySession("BASELINE")
            group.withTimePoint("T0")
            
            group.addFindingSite(
                CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                )
            )
            
            group.addLength(value: 42.5, unit: .millimeters, imageReference: baselineImage)
        }
        
        // Follow-up measurement
        .addMeasurementGroup(
            trackingIdentifier: "LESION-001-FOLLOWUP",
            trackingUID: "1.2.840.113619.2.55.3.TF.001"
        ) { group in
            group.withActivitySession("FOLLOWUP-1")
            group.withTimePoint("T1")
            
            group.addFindingSite(
                CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                )
            )
            
            group.addLength(value: 35.2, unit: .millimeters, imageReference: followupImage)
            
            // Percent change
            group.addDerivedMeasurement(
                concept: CodedConcept(
                    codeValue: "260372006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Percent change"
                ),
                value: -17.2,  // (35.2 - 42.5) / 42.5 * 100
                unit: CodedConcept(
                    codeValue: "%",
                    codingSchemeDesignator: .ucum,
                    codeMeaning: "percent"
                )
            )
        }
        
        .build()
    
    print("Created temporal comparison report")
    print("Baseline: 42.5 mm → Follow-up: 35.2 mm (-17.2%)")
}

// MARK: - Example 7: Reading Measurements from Report

/// Extract measurements from an existing TID 1500 report
func example7_readingMeasurements() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/measurement_report.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Use MeasurementExtractor
    let extractor = MeasurementExtractor(document: srDocument)
    let measurements = try extractor.extractAllMeasurements()
    
    print("Found \(measurements.count) measurements:")
    
    for measurement in measurements {
        print("\n--- Measurement ---")
        
        // Tracking information
        if let trackingID = measurement.trackingIdentifier {
            print("Tracking ID: \(trackingID)")
        }
        
        if let trackingUID = measurement.trackingUID {
            print("Tracking UID: \(trackingUID)")
        }
        
        // Location
        if let site = measurement.findingSite {
            print("Site: \(site.codeMeaning)")
        }
        
        // Measurement type and value
        print("Type: \(measurement.measurementType)")
        
        if let value = measurement.numericValue {
            let unit = measurement.unit ?? ""
            print("Value: \(value) \(unit)")
        }
        
        // Session/timepoint
        if let session = measurement.activitySession {
            print("Session: \(session)")
        }
        
        if let timePoint = measurement.timePoint {
            print("Time Point: \(timePoint)")
        }
    }
}

// MARK: - Example 8: Measurement Statistics

/// Calculate statistics from measurement groups
func example8_measurementStatistics() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/measurement_report.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let extractor = MeasurementExtractor(document: srDocument)
    let measurements = try extractor.extractAllMeasurements()
    
    // Filter length measurements
    let lengths = measurements.compactMap { measurement -> Double? in
        guard measurement.measurementType.contains("length") ||
              measurement.measurementType.contains("diameter") else {
            return nil
        }
        return measurement.numericValue
    }
    
    // Calculate statistics
    if !lengths.isEmpty {
        let sum = lengths.reduce(0, +)
        let mean = sum / Double(lengths.count)
        let min = lengths.min() ?? 0
        let max = lengths.max() ?? 0
        
        print("Length Measurement Statistics:")
        print("Count: \(lengths.count)")
        print("Sum: \(sum) mm")
        print("Mean: \(mean) mm")
        print("Min: \(min) mm")
        print("Max: \(max) mm")
    }
}

// MARK: - Example 9: Exporting Measurement Summary

/// Export measurement summary to structured format
func example9_exportingSummary() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/measurement_report.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let reportExtractor = MeasurementReportExtractor(document: srDocument)
    let report = try reportExtractor.extract()
    
    // Create summary structure
    struct MeasurementSummary: Codable {
        let patientID: String
        let studyDate: String
        let measurements: [LesionMeasurement]
        
        struct LesionMeasurement: Codable {
            let trackingID: String
            let site: String
            let length: Double
            let unit: String
        }
    }
    
    let summary = MeasurementSummary(
        patientID: report.patientID ?? "Unknown",
        studyDate: report.studyDate ?? "Unknown",
        measurements: report.measurementGroups.compactMap { group in
            guard let trackingID = group.trackingIdentifier,
                  let length = group.measurements.first(where: { $0.type == .length })?.value,
                  let site = group.findingSite?.codeMeaning else {
                return nil
            }
            
            return MeasurementSummary.LesionMeasurement(
                trackingID: trackingID,
                site: site,
                length: length,
                unit: "mm"
            )
        }
    )
    
    // Export to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonData = try encoder.encode(summary)
    
    if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("Measurement Summary JSON:")
        print(jsonString)
    }
}

// MARK: - Quick Reference

/*
 MEASUREMENT REPORTS (TID 1500) QUICK REFERENCE
 ==============================================
 
 1. CREATE MEASUREMENT REPORT:
    let doc = try MeasurementReportBuilder()
        .withDocumentTitle(.imagingMeasurementReport)
        .withPatientID("ID")
        .withPatientName("Name")
        // ... other demographics
        .build()
 
 2. IMAGE LIBRARY:
    let imageRef = ImageReference(
        referencedSOPClassUID: "1.2.840...",
        referencedSOPInstanceUID: "1.2.840..."
    )
    
    builder.addToImageLibrary(imageRef, description: "CT Series 2")
 
 3. MEASUREMENT GROUP:
    builder.addMeasurementGroup(
        trackingIdentifier: "LESION-001",
        trackingUID: "1.2.840..."
    ) { group in
        // Add measurements and evaluations
    }
 
 4. FINDING SITE:
    group.addFindingSite(
        CodedConcept(
            codeValue: "39607008",
            codingSchemeDesignator: .snomedCT,
            codeMeaning: "Lung structure"
        ),
        laterality: .right  // optional: .left, .right, .bilateral
    )
 
 5. LENGTH MEASUREMENTS:
    group.addLength(
        value: 42.5,
        unit: .millimeters,  // or .centimeters
        imageReference: imageRef
    )
 
 6. AREA MEASUREMENTS:
    group.addArea(
        value: 125.3,
        unit: .squareMillimeters,
        imageReference: imageRef
    )
 
 7. VOLUME MEASUREMENTS:
    group.addVolume(
        value: 12.5,
        unit: CodedConcept(
            codeValue: "cm3",
            codingSchemeDesignator: .ucum,
            codeMeaning: "cubic centimeter"
        ),
        imageReference: imageRef
    )
 
 8. QUALITATIVE EVALUATIONS:
    group.addQualitativeEvaluation(
        concept: CodedConcept(...),  // what is being evaluated
        value: CodedConcept(...)     // the evaluation result
    )
 
 9. TRACKING ACROSS TIMEPOINTS:
    group.withActivitySession("BASELINE")
    group.withTimePoint("T0")
 
 10. DERIVED MEASUREMENTS:
     group.addDerivedMeasurement(
         concept: sumConcept,
         value: 96.5,
         unit: .millimeters,
         derivedFrom: ["LESION-001", "LESION-002"]
     )
 
 11. READING MEASUREMENTS:
     let extractor = MeasurementExtractor(document: sr)
     let measurements = try extractor.extractAllMeasurements()
     
     for m in measurements {
         print("ID: \(m.trackingIdentifier ?? "N/A")")
         print("Value: \(m.numericValue ?? 0) \(m.unit ?? "")")
     }
 
 12. MEASUREMENT PROPERTIES:
     - trackingIdentifier: String?
     - trackingUID: String?
     - measurementType: String
     - numericValue: Double?
     - unit: String?
     - findingSite: CodedConcept?
     - laterality: Laterality?
     - activitySession: String?
     - timePoint: String?
 
 13. COMMON FINDING SITES (SNOMED CT):
     - Lung: 39607008
     - Liver: 10200004
     - Brain: 12738006
     - Lymph node: 59441001
     - Bone: 272673000
 
 14. LATERALITY:
     .left
     .right
     .bilateral
     .unpaired
 
 15. MEASUREMENT UNITS (UCUM):
     .millimeters     "mm"
     .centimeters     "cm"
     .meters          "m"
     .squareMillimeters  "mm2"
     .squareCentimeters  "cm2"
     .cubicMillimeters   "mm3"
     .cubicCentimeters   "cm3"
 
 16. RECIST RESPONSE CATEGORIES:
     - Complete Response (CR): 260905004
     - Partial Response (PR): 268910001
     - Stable Disease (SD): 359746009
     - Progressive Disease (PD): 271299001
 
 17. BEST PRACTICES:
     ✓ Use consistent tracking identifiers
     ✓ Include tracking UIDs for uniqueness
     ✓ Reference source images for measurements
     ✓ Specify finding sites with SNOMED CT
     ✓ Use UCUM for measurement units
     ✓ Include session/timepoint for longitudinal studies
     ✓ Add qualitative assessments alongside metrics
     ✓ Calculate and include derived values (sums, percent changes)
     ✓ Follow RECIST or other standardized criteria when applicable
 
 18. COMMON USE CASES:
     - Oncology tumor measurements (RECIST, irRECIST)
     - Cardiac measurements (ejection fraction, chamber volumes)
     - Neurological measurements (brain lesion volumes)
     - Bone lesion assessments
     - Lymph node measurements
     - AI/ML algorithm outputs
     - Clinical trial imaging endpoints
 
 19. TEMPLATES:
     - TID 1500: Measurement Report
     - TID 1411: Volumetric ROI Measurements
     - TID 1419: ROI Measurements
     - TID 300: Measurement
     - TID 1600: Image Library
 
 20. REFERENCE:
     - DICOM PS3.16 TID 1500: Measurement Report
     - RECIST 1.1: Response Evaluation Criteria
     - SNOMED CT Browser: https://browser.ihtsdotools.org/
     - UCUM: https://ucum.org/
 */

// MARK: - Running the Examples
// Uncomment to run individual examples:
// try? example1_simpleTumorMeasurement()
// try? example2_recistTargetLesion()
// try? example3_multipleLesionsWithSum()
// try? example4_volumeMeasurements()
// try? example5_qualitativeEvaluations()
// try? example6_temporalComparison()
// try? example7_readingMeasurements()
// try? example8_measurementStatistics()
// try? example9_exportingSummary()
