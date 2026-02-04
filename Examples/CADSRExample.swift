/// CAD SR Examples (Mammography and Chest CAD)
///
/// This example demonstrates how to create DICOM CAD SR (Computer-Aided Detection)
/// documents for encoding AI/ML detection results in radiology imaging.
///
/// CAD SR documents are specialized for:
/// - Mammography CAD: Breast cancer screening detections
/// - Chest CAD: Lung nodule and other chest findings
/// - Standardized AI/ML output encoding
/// - Integration with clinical workflows
///
/// Both include:
/// - CAD Processing Summary (algorithm metadata)
/// - Individual findings with confidence scores
/// - Spatial location annotations
/// - Finding characteristics

import Foundation
import DICOMKit
import DICOMCore

// MARK: - Mammography CAD Examples

/// Example: Mammography CAD report for breast cancer screening
func createMammographyCADReport() throws -> SRDocument {
    // Reference to the mammogram image
    let mammogramImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",  // Digital Mammography Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.MAMMO.100"
    )
    
    let document = try MammographyCADSRBuilder()
        // Patient Information
        .withPatientID("55566677")
        .withPatientName("Garcia^Maria^^^")
        .withPatientBirthDate("19750312")
        .withPatientSex("F")
        
        // Study Information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.STUDY.500")
        .withStudyDate("20260204")
        .withStudyTime("092000")
        .withStudyDescription("Screening Mammography")
        .withAccessionNumber("ACC778899")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.SERIES.501")
        .withSeriesNumber("10")
        .withModality("SR")
        
        // Document Information
        .withDocumentTitle("Mammography CAD Report")
        .withCompletionFlag(.complete)
        
        // CAD Algorithm Information
        .withAlgorithmName("BreastCAD v3.2")
        .withAlgorithmVersion("3.2.1")
        .withManufacturer("AI Medical Systems Inc.")
        
        // Finding 1: Suspicious mass
        .addFinding(
            type: .mass,
            confidence: 0.92,
            location: .point(x: 458.3, y: 612.5, imageReference: mammogramImage)
        ) { finding in
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "111320",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Spiculated margin"
                )
            )
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "111322",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "High density"
                )
            )
        }
        
        // Finding 2: Cluster of calcifications
        .addFinding(
            type: .calcification,
            confidence: 0.88,
            location: .roi(
                points: [
                    (520.0, 780.0),
                    (535.0, 778.0),
                    (538.0, 795.0),
                    (525.0, 798.0),
                    (518.0, 788.0)
                ],
                imageReference: mammogramImage
            )
        ) { finding in
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "111348",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Clustered"
                )
            )
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "111350",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Pleomorphic"
                )
            )
        }
        
        // Finding 3: Low-confidence architectural distortion
        .addFinding(
            type: .architecturalDistortion,
            confidence: 0.65,
            location: .circle(
                centerX: 390.0,
                centerY: 550.0,
                radius: 18.0,
                imageReference: mammogramImage
            )
        )
        
        .build()
    
    return document
}

/// Example: Bilateral mammography CAD with multiple views
func createBilateralMammographyCADReport() throws -> SRDocument {
    let rccImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.RCC.100"
    )
    
    let rMLOImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.RMLO.100"
    )
    
    let document = try MammographyCADSRBuilder()
        .withPatientID("88899900")
        .withPatientName("Chen^Li^^^")
        .withDocumentTitle("Bilateral Screening Mammography CAD")
        .withAlgorithmName("DenseBreastAI v2.5")
        .withAlgorithmVersion("2.5.0")
        
        // Right CC view finding
        .addFinding(
            type: .mass,
            confidence: 0.78,
            location: .point(x: 445.0, y: 590.0, imageReference: rccImage)
        ) { finding in
            finding.addDescription("12 o'clock position, 6 cm from nipple")
        }
        
        // Right MLO view finding (same lesion, different view)
        .addFinding(
            type: .mass,
            confidence: 0.82,
            location: .point(x: 520.0, y: 680.0, imageReference: rMLOImage)
        ) { finding in
            finding.addDescription("Correlates with RCC finding")
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "111321",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Irregular shape"
                )
            )
        }
        
        .build()
    
    return document
}

// MARK: - Chest CAD Examples

/// Example: Chest CAD report for lung nodule detection
func createChestCADReport() throws -> SRDocument {
    // Reference to CT chest image
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.CHEST.200"
    )
    
    let document = try ChestCADSRBuilder()
        // Patient Information
        .withPatientID("22233344")
        .withPatientName("Patel^Rajesh^^^")
        .withPatientBirthDate("19550628")
        .withPatientSex("M")
        
        // Study Information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.STUDY.600")
        .withStudyDate("20260204")
        .withStudyTime("111500")
        .withStudyDescription("CT Chest Screening")
        .withAccessionNumber("ACC334455")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.SERIES.601")
        .withSeriesNumber("5")
        .withModality("SR")
        
        // Document Information
        .withDocumentTitle("Lung Nodule Detection CAD Report")
        .withCompletionFlag(.complete)
        
        // CAD Algorithm Information
        .withAlgorithmName("LungCAD AI v4.1")
        .withAlgorithmVersion("4.1.0")
        .withManufacturer("Thoracic AI Systems")
        
        // Finding 1: Solid lung nodule (high confidence)
        .addFinding(
            type: .lungNodule,
            confidence: 0.94,
            location: .point(x: 328.5, y: 245.8, imageReference: ctImage)
        ) { finding in
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "56961003",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Solid"
                )
            )
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "277956000",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Spherical"
                )
            )
            finding.addDescription("Right upper lobe, 8.2 mm diameter")
        }
        
        // Finding 2: Ground-glass opacity
        .addFinding(
            type: .lungNodule,
            confidence: 0.76,
            location: .roi(
                points: [
                    (185.0, 312.0),
                    (192.0, 310.0),
                    (195.0, 317.0),
                    (190.0, 322.0),
                    (183.0, 319.0)
                ],
                imageReference: ctImage
            )
        ) { finding in
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "427524004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Ground glass opacity"
                )
            )
            finding.addDescription("Left lower lobe, subpleural")
        }
        
        // Finding 3: Calcified granuloma (low suspicion)
        .addFinding(
            type: .lungNodule,
            confidence: 0.52,
            location: .circle(
                centerX: 256.0,
                centerY: 280.0,
                radius: 4.5,
                imageReference: ctImage
            )
        ) { finding in
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "129730003",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Calcified"
                )
            )
            finding.addDescription("Likely benign granuloma")
        }
        
        .build()
    
    return document
}

/// Example: Multi-finding chest CAD with various pathologies
func createComprehensiveChestCADReport() throws -> SRDocument {
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.COMPREHENSIVE.300"
    )
    
    let document = try ChestCADSRBuilder()
        .withPatientID("66677788")
        .withPatientName("Kim^Soo^^^")
        .withDocumentTitle("Comprehensive Chest CAD Analysis")
        .withAlgorithmName("MultiPathologyCAD v5.0")
        .withAlgorithmVersion("5.0.2")
        
        // Lung nodule
        .addFinding(
            type: .lungNodule,
            confidence: 0.89,
            location: .point(x: 410.0, y: 290.0, imageReference: ctImage)
        )
        
        // Lung mass (larger, more suspicious)
        .addFinding(
            type: .lungMass,
            confidence: 0.91,
            location: .roi(
                points: [
                    (150.0, 200.0),
                    (170.0, 195.0),
                    (180.0, 210.0),
                    (175.0, 230.0),
                    (155.0, 225.0)
                ],
                imageReference: ctImage
            )
        ) { finding in
            finding.addCharacteristic(
                CodedConcept(
                    codeValue: "255450007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Spiculated"
                )
            )
        }
        
        // Consolidation
        .addFinding(
            type: .pulmonaryConsolidation,
            confidence: 0.85,
            location: .roi(
                points: [
                    (320.0, 380.0),
                    (345.0, 375.0),
                    (355.0, 395.0),
                    (340.0, 410.0),
                    (318.0, 405.0)
                ],
                imageReference: ctImage
            )
        ) { finding in
            finding.addDescription("Right middle lobe")
        }
        
        // Tree-in-bud pattern (infectious etiology)
        .addFinding(
            type: .treeInBudPattern,
            confidence: 0.72,
            location: .circle(
                centerX: 280.0,
                centerY: 350.0,
                radius: 25.0,
                imageReference: ctImage
            )
        )
        
        .build()
    
    return document
}

// MARK: - AI/ML Integration Example

/// Example: Converting AI detection results to CAD SR
func convertAIDetectionsToCADSR() throws -> SRDocument {
    // Simulate AI model output
    struct LungNoduleDetection {
        let x: Double
        let y: Double
        let confidence: Double
        let diameter: Double
        let isSolid: Bool
    }
    
    let aiDetections: [LungNoduleDetection] = [
        LungNoduleDetection(x: 234.5, y: 178.2, confidence: 0.95, diameter: 12.3, isSolid: true),
        LungNoduleDetection(x: 412.8, y: 290.1, confidence: 0.88, diameter: 6.8, isSolid: false),
        LungNoduleDetection(x: 156.3, y: 345.7, confidence: 0.71, diameter: 4.2, isSolid: true)
    ]
    
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.AI.400"
    )
    
    var builder = ChestCADSRBuilder()
        .withPatientID("AI-TEST-001")
        .withPatientName("Test^AI^^^")
        .withDocumentTitle("AI Lung Nodule Detection")
        .withAlgorithmName("DeepLungNet")
        .withAlgorithmVersion("2.0.0")
        .withManufacturer("AI Research Lab")
    
    // Convert each AI detection to a CAD finding
    for (index, detection) in aiDetections.enumerated() {
        builder = builder.addFinding(
            type: .lungNodule,
            confidence: detection.confidence,
            location: .point(x: detection.x, y: detection.y, imageReference: ctImage)
        ) { finding in
            // Add finding characteristics based on AI metadata
            if detection.isSolid {
                finding.addCharacteristic(
                    CodedConcept(
                        codeValue: "56961003",
                        codingSchemeDesignator: .snomedCT,
                        codeMeaning: "Solid"
                    )
                )
            } else {
                finding.addCharacteristic(
                    CodedConcept(
                        codeValue: "427524004",
                        codingSchemeDesignator: .snomedCT,
                        codeMeaning: "Ground glass opacity"
                    )
                )
            }
            
            finding.addDescription(String(format: "Nodule #%d, %.1f mm", index + 1, detection.diameter))
        }
    }
    
    return try builder.build()
}

/// Example: Extracting CAD findings for analysis
func extractCADFindingsExample() throws {
    let document = try createChestCADReport()
    
    // Extract CAD findings
    let findings = try CADFindings.extract(from: document)
    
    print("CAD Analysis Summary:")
    print("Algorithm: \(findings.algorithmName ?? "Unknown")")
    print("Version: \(findings.algorithmVersion ?? "Unknown")")
    print("Total Findings: \(findings.findings.count)\n")
    
    // Categorize by confidence level
    let highConfidence = findings.findings.filter { $0.confidence >= 0.8 }
    let mediumConfidence = findings.findings.filter { $0.confidence >= 0.6 && $0.confidence < 0.8 }
    let lowConfidence = findings.findings.filter { $0.confidence < 0.6 }
    
    print("Confidence Distribution:")
    print("  High (≥0.8): \(highConfidence.count)")
    print("  Medium (0.6-0.8): \(mediumConfidence.count)")
    print("  Low (<0.6): \(lowConfidence.count)\n")
    
    // Print details of high-confidence findings
    print("High Confidence Findings:")
    for finding in highConfidence {
        print("  Type: \(finding.findingType?.codeMeaning ?? "Unknown")")
        print("  Confidence: \(String(format: "%.2f", finding.confidence))")
        if !finding.characteristics.isEmpty {
            print("  Characteristics: \(finding.characteristics.map { $0.codeMeaning ?? "Unknown" }.joined(separator: ", "))")
        }
        print("")
    }
}

// MARK: - Usage Examples

/*
 To use these CAD SR examples:
 
 1. Create a mammography CAD report:
 
    do {
        let report = try createMammographyCADReport()
        
        // Save to file
        let dataSet = try SRDocumentSerializer.serialize(report)
        let writer = DICOMWriter()
        let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
        try fileData.write(to: URL(fileURLWithPath: "/tmp/mammo_cad.dcm"))
        
        print("Mammography CAD report saved")
    } catch {
        print("Error: \(error)")
    }
 
 2. Create a chest CAD report:
 
    let report = try createChestCADReport()
    print("Created Chest CAD report with lung nodule detections")
 
 3. Convert AI detections to CAD SR:
 
    let aiReport = try convertAIDetectionsToCADSR()
    print("Converted AI detections to standard CAD SR format")
 
 4. Extract and analyze CAD findings:
 
    try extractCADFindingsExample()
 
 5. Query for specific finding types:
 
    let document = try createComprehensiveChestCADReport()
    let findings = try CADFindings.extract(from: document)
    
    // Find all lung masses (vs nodules)
    let masses = findings.findings.filter { finding in
        finding.findingType?.codeMeaning?.contains("mass") ?? false
    }
    
    print("Found \(masses.count) lung masses")
    
    for mass in masses {
        print("  Confidence: \(mass.confidence)")
        if let location = mass.location {
            print("  Location type: \(location.type)")
        }
    }
 
 6. Save bilateral mammography CAD results:
 
    let bilateralReport = try createBilateralMammographyCADReport()
    let findings = try CADFindings.extract(from: bilateralReport)
    
    print("Bilateral findings: \(findings.findings.count)")
    
    // Group by confidence category
    for finding in findings.findings {
        let category = finding.confidenceCategory
        print("\(category): \(finding.findingType?.codeMeaning ?? "Unknown")")
    }
 */
