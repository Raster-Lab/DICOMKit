/// Playground 4.4: Computer-Aided Detection (CAD) SR
///
/// This playground demonstrates how to create and read CAD Structured Reports.
/// CAD SR documents are used to record findings from computer-aided detection
/// algorithms for mammography, chest X-ray, CT colonography, and other modalities.
///
/// Topics covered:
/// - Creating Mammography CAD SR documents
/// - Creating Chest CAD SR documents
/// - Adding CAD findings with probabilities
/// - Spatial coordinates for findings
/// - Reading and extracting CAD results
/// - Processing AI/ML algorithm outputs
/// - Confidence scores and classifications

import Foundation
import DICOMKit
import DICOMCore

// MARK: - Example 1: Basic Mammography CAD Finding

/// Create a simple mammography CAD SR with a single finding
func example1_basicMammographyCAD() throws {
    let mammoImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",  // Digital Mammography Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.MAMMO.100"
    )
    
    let document = try MammographyCADSRBuilder()
        // Patient information
        .withPatientID("MAMMO001")
        .withPatientName("Anderson^Sarah^^^")
        .withPatientBirthDate("19750615")
        .withPatientSex("F")
        
        // Study information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.STUDY.100")
        .withStudyDate("20260204")
        .withStudyTime("093000")
        .withStudyDescription("Screening Mammogram")
        .withAccessionNumber("MAMMO001")
        
        // Series information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.SERIES.100")
        .withSeriesNumber("100")
        .withModality("SR")
        
        // Document information
        .withDocumentTitle(.mammographyCADSR)
        .withCompletionFlag(.complete)
        
        // CAD algorithm information
        .withCADAlgorithm(
            name: "MammoDet AI v2.3",
            version: "2.3.0",
            manufacturer: "AI Medical Inc."
        )
        
        // Image library
        .addToImageLibrary(mammoImage, description: "RCC View")
        
        // CAD Finding: Mass
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "24727000",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Mass"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "76752008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Breast structure"
                ),
                laterality: .right
            )
            
            finding.withProbability(0.87)  // 87% confidence
            
            finding.withCenterCoordinates(
                x: 512.5,
                y: 768.3,
                imageReference: mammoImage
            )
            
            finding.withSize(width: 15.2, height: 18.5, unit: .millimeters)
        }
        
        .build()
    
    print("Created mammography CAD SR with mass finding")
    print("Confidence: 87%")
}

// MARK: - Example 2: Multiple Mammography CAD Findings

/// Create mammography CAD SR with multiple findings of different types
func example2_multipleMammographyFindings() throws {
    let rccImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.RCC.100"
    )
    
    let lmloImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.LMLO.100"
    )
    
    let document = try MammographyCADSRBuilder()
        .withPatientID("MAMMO002")
        .withPatientName("Williams^Jennifer^^^")
        .withDocumentTitle(.mammographyCADSR)
        
        .withCADAlgorithm(
            name: "BreastAI Pro",
            version: "3.1.0",
            manufacturer: "MedTech AI"
        )
        
        .addToImageLibrary(rccImage, description: "RCC")
        .addToImageLibrary(lmloImage, description: "LMLO")
        
        // Finding 1: Mass in right breast
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "24727000",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Mass"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "76752008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Breast structure"
                ),
                laterality: .right
            )
            
            finding.withProbability(0.92)
            finding.withCenterCoordinates(x: 480.0, y: 720.0, imageReference: rccImage)
            finding.withSize(width: 12.3, height: 14.1, unit: .millimeters)
            
            // Additional characterization
            finding.withMorphology(
                CodedConcept(
                    codeValue: "255288007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lobulated"
                )
            )
        }
        
        // Finding 2: Calcification cluster
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "129762008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Breast calcification"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "76752008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Breast structure"
                ),
                laterality: .left
            )
            
            finding.withProbability(0.78)
            finding.withCenterCoordinates(x: 350.5, y: 620.8, imageReference: lmloImage)
            
            finding.withMorphology(
                CodedConcept(
                    codeValue: "129762008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Clustered"
                )
            )
        }
        
        // Finding 3: Architectural distortion
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "369745005",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Architectural distortion"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "76752008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Breast structure"
                ),
                laterality: .right
            )
            
            finding.withProbability(0.65)
            finding.withCenterCoordinates(x: 520.2, y: 650.7, imageReference: rccImage)
        }
        
        .build()
    
    print("Created mammography CAD SR with 3 findings")
}

// MARK: - Example 3: Chest CAD for Lung Nodules

/// Create chest CAD SR for lung nodule detection
func example3_chestCADLungNodules() throws {
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.CT.200"
    )
    
    let document = try ChestCADSRBuilder()
        .withPatientID("CHEST001")
        .withPatientName("Johnson^Michael^^^")
        .withPatientBirthDate("19600820")
        .withPatientSex("M")
        
        .withStudyInstanceUID("1.2.840.113619.2.55.3.STUDY.200")
        .withStudyDate("20260204")
        .withStudyDescription("CT Chest")
        
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.SERIES.200")
        .withSeriesNumber("2")
        .withModality("SR")
        
        .withDocumentTitle(.chestCADSR)
        
        .withCADAlgorithm(
            name: "LungNoduleAI",
            version: "4.2.1",
            manufacturer: "Radiology AI Corp"
        )
        
        .addToImageLibrary(ctImage, description: "Chest CT Series 2")
        
        // Nodule finding 1: Right upper lobe
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "41381004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Pulmonary nodule"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "45653009",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Structure of upper lobe of right lung"
                )
            )
            
            finding.withProbability(0.94)
            
            // 3D coordinates (x, y, z in mm)
            finding.with3DCoordinates(
                x: 125.3,
                y: 87.6,
                z: 142.8,
                imageReference: ctImage
            )
            
            finding.withVolume(value: 245.7, unit: .cubicMillimeters)
            
            finding.withMalignancyProbability(0.32)  // 32% malignancy risk
        }
        
        // Nodule finding 2: Left lower lobe
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "41381004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Pulmonary nodule"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "31094006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Structure of lower lobe of left lung"
                )
            )
            
            finding.withProbability(0.88)
            
            finding.with3DCoordinates(
                x: -98.2,
                y: -45.3,
                z: -52.1,
                imageReference: ctImage
            )
            
            finding.withVolume(value: 128.4, unit: .cubicMillimeters)
            
            finding.withMalignancyProbability(0.15)
        }
        
        .build()
    
    print("Created chest CAD SR with lung nodule findings")
}

// MARK: - Example 4: CAD with Classification Results

/// Create CAD SR with multi-class classification
func example4_cadClassification() throws {
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.CT.300"
    )
    
    let document = try ChestCADSRBuilder()
        .withPatientID("CLASS001")
        .withPatientName("Davis^Lisa^^^")
        .withDocumentTitle(.chestCADSR)
        
        .withCADAlgorithm(
            name: "ChestPathologyClassifier",
            version: "1.5.0",
            manufacturer: "AI Diagnostics Ltd"
        )
        
        .addToImageLibrary(ctImage, description: "Chest CT")
        
        .addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "301234006",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Infiltration"
                )
            )
            
            finding.withLocation(
                CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                ),
                laterality: .right
            )
            
            // Multi-class probabilities
            finding.withClassificationProbabilities([
                "Normal": 0.05,
                "Infiltration": 0.78,
                "Consolidation": 0.12,
                "Pneumothorax": 0.03,
                "Effusion": 0.02
            ])
            
            finding.withCenterCoordinates(x: 256.0, y: 384.0, imageReference: ctImage)
        }
        
        .build()
    
    print("Created CAD SR with classification results")
}

// MARK: - Example 5: Reading CAD Findings

/// Extract CAD findings from a CAD SR document
func example5_readingCADFindings() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/cad_sr.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Use CADFindingsExtractor
    let extractor = CADFindingsExtractor(document: srDocument)
    let findings = try extractor.extractFindings()
    
    print("Found \(findings.count) CAD findings:")
    
    for (index, finding) in findings.enumerated() {
        print("\n--- Finding \(index + 1) ---")
        
        // Finding type
        print("Type: \(finding.findingType.codeMeaning)")
        
        // Location
        if let location = finding.location {
            print("Location: \(location.codeMeaning)")
        }
        
        if let laterality = finding.laterality {
            print("Laterality: \(laterality)")
        }
        
        // Confidence/Probability
        if let probability = finding.probability {
            print("Confidence: \(probability * 100)%")
        }
        
        // Coordinates
        if let center = finding.centerCoordinates {
            print("Center: (\(center.x), \(center.y))")
        }
        
        if let coords3D = finding.coordinates3D {
            print("3D Position: (\(coords3D.x), \(coords3D.y), \(coords3D.z)) mm")
        }
        
        // Size information
        if let size = finding.size {
            print("Size: \(size.width) × \(size.height) mm")
        }
        
        if let volume = finding.volume {
            print("Volume: \(volume) mm³")
        }
        
        // Malignancy assessment
        if let malignancy = finding.malignancyProbability {
            print("Malignancy Risk: \(malignancy * 100)%")
        }
    }
}

// MARK: - Example 6: Filtering CAD Findings

/// Filter CAD findings by confidence threshold
func example6_filteringFindings() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/cad_sr.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let extractor = CADFindingsExtractor(document: srDocument)
    let allFindings = try extractor.extractFindings()
    
    // Filter by confidence threshold (e.g., >= 80%)
    let highConfidenceFindings = allFindings.filter { finding in
        guard let prob = finding.probability else { return false }
        return prob >= 0.80
    }
    
    print("Total findings: \(allFindings.count)")
    print("High confidence findings (≥80%): \(highConfidenceFindings.count)")
    
    // Filter by finding type
    let noduleFindings = allFindings.filter { finding in
        finding.findingType.codeMeaning.lowercased().contains("nodule")
    }
    
    print("Nodule findings: \(noduleFindings.count)")
    
    // Filter by location (e.g., right lung)
    let rightLungFindings = allFindings.filter { finding in
        guard let location = finding.location else { return false }
        return location.codeMeaning.lowercased().contains("right") &&
               location.codeMeaning.lowercased().contains("lung")
    }
    
    print("Right lung findings: \(rightLungFindings.count)")
}

// MARK: - Example 7: CAD Findings Summary Report

/// Generate a summary report from CAD findings
func example7_cadSummaryReport() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/cad_sr.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let extractor = CADFindingsExtractor(document: srDocument)
    let findings = try extractor.extractFindings()
    
    // Group by finding type
    var findingsByType: [String: [CADFinding]] = [:]
    for finding in findings {
        let type = finding.findingType.codeMeaning
        findingsByType[type, default: []].append(finding)
    }
    
    print("CAD FINDINGS SUMMARY")
    print("===================")
    print("Patient: \(srDocument.patientName ?? "Unknown")")
    print("Study Date: \(srDocument.studyDate ?? "Unknown")")
    print("Total Findings: \(findings.count)\n")
    
    for (type, typedFindings) in findingsByType.sorted(by: { $0.key < $1.key }) {
        print("\n\(type): \(typedFindings.count)")
        
        // Calculate average confidence
        let confidences = typedFindings.compactMap { $0.probability }
        if !confidences.isEmpty {
            let avgConfidence = confidences.reduce(0, +) / Double(confidences.count)
            print("  Average Confidence: \(avgConfidence * 100)%")
        }
        
        // List high-confidence findings
        let highConf = typedFindings.filter { ($0.probability ?? 0) >= 0.85 }
        if !highConf.isEmpty {
            print("  High confidence (≥85%): \(highConf.count)")
            for finding in highConf {
                if let location = finding.location {
                    print("    - \(location.codeMeaning)")
                }
            }
        }
    }
}

// MARK: - Example 8: Exporting CAD Results to JSON

/// Export CAD findings to JSON format for integration
func example8_exportingCADToJSON() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/cad_sr.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let extractor = CADFindingsExtractor(document: srDocument)
    let findings = try extractor.extractFindings()
    
    // Create exportable structure
    struct CADExport: Codable {
        let algorithmName: String
        let algorithmVersion: String
        let patientID: String
        let studyDate: String
        let findings: [Finding]
        
        struct Finding: Codable {
            let type: String
            let location: String?
            let confidence: Double?
            let coordinates: Coordinates?
            let malignancyRisk: Double?
            
            struct Coordinates: Codable {
                let x: Double
                let y: Double
                let z: Double?
            }
        }
    }
    
    let export = CADExport(
        algorithmName: "CAD Algorithm",  // Extract from SR
        algorithmVersion: "1.0",
        patientID: srDocument.patientID ?? "Unknown",
        studyDate: srDocument.studyDate ?? "Unknown",
        findings: findings.map { finding in
            CADExport.Finding(
                type: finding.findingType.codeMeaning,
                location: finding.location?.codeMeaning,
                confidence: finding.probability,
                coordinates: {
                    if let coords3D = finding.coordinates3D {
                        return CADExport.Finding.Coordinates(
                            x: coords3D.x,
                            y: coords3D.y,
                            z: coords3D.z
                        )
                    } else if let center = finding.centerCoordinates {
                        return CADExport.Finding.Coordinates(
                            x: center.x,
                            y: center.y,
                            z: nil
                        )
                    }
                    return nil
                }(),
                malignancyRisk: finding.malignancyProbability
            )
        }
    )
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonData = try encoder.encode(export)
    
    if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("CAD Export JSON:")
        print(jsonString)
    }
}

// MARK: - Example 9: AI Model Output to CAD SR

/// Convert AI model output to CAD SR document
func example9_aiModelOutputToCADSR() throws {
    // Simulated AI model output
    struct AIModelOutput {
        struct Detection {
            let className: String
            let confidence: Double
            let boundingBox: (x: Double, y: Double, width: Double, height: Double)
        }
        
        let detections: [Detection]
    }
    
    let aiOutput = AIModelOutput(
        detections: [
            AIModelOutput.Detection(
                className: "pulmonary_nodule",
                confidence: 0.92,
                boundingBox: (x: 250.0, y: 380.0, width: 45.0, height: 48.0)
            ),
            AIModelOutput.Detection(
                className: "pulmonary_nodule",
                confidence: 0.85,
                boundingBox: (x: 180.0, y: 420.0, width: 32.0, height: 35.0)
            )
        ]
    )
    
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.CT.400"
    )
    
    var builder = ChestCADSRBuilder()
        .withPatientID("AI001")
        .withPatientName("Test^Patient^^^")
        .withDocumentTitle(.chestCADSR)
        .withCADAlgorithm(
            name: "Custom AI Model",
            version: "1.0.0",
            manufacturer: "Research Lab"
        )
        .addToImageLibrary(ctImage, description: "CT Chest")
    
    // Convert each detection to a CAD finding
    for detection in aiOutput.detections {
        builder = builder.addFinding { finding in
            finding.withType(
                CodedConcept(
                    codeValue: "41381004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Pulmonary nodule"
                )
            )
            
            finding.withProbability(detection.confidence)
            
            // Calculate center from bounding box
            let centerX = detection.boundingBox.x + detection.boundingBox.width / 2
            let centerY = detection.boundingBox.y + detection.boundingBox.height / 2
            
            finding.withCenterCoordinates(
                x: centerX,
                y: centerY,
                imageReference: ctImage
            )
            
            finding.withSize(
                width: detection.boundingBox.width,
                height: detection.boundingBox.height,
                unit: .pixels
            )
        }
    }
    
    let document = try builder.build()
    
    print("Created CAD SR from AI model output")
    print("Converted \(aiOutput.detections.count) detections to CAD findings")
}

// MARK: - Quick Reference

/*
 CAD STRUCTURED REPORT QUICK REFERENCE
 =====================================
 
 1. MAMMOGRAPHY CAD SR:
    let doc = try MammographyCADSRBuilder()
        .withDocumentTitle(.mammographyCADSR)
        .withCADAlgorithm(name: "...", version: "...", manufacturer: "...")
        .addFinding { finding in
            finding.withType(massCode)
            finding.withProbability(0.87)
            finding.withCenterCoordinates(x: 512, y: 768, imageReference: img)
        }
        .build()
 
 2. CHEST CAD SR:
    let doc = try ChestCADSRBuilder()
        .withDocumentTitle(.chestCADSR)
        .withCADAlgorithm(name: "...", version: "...", manufacturer: "...")
        .addFinding { finding in
            finding.withType(noduleCode)
            finding.with3DCoordinates(x: 125, y: 87, z: 142, imageReference: img)
            finding.withMalignancyProbability(0.32)
        }
        .build()
 
 3. CAD ALGORITHM INFO:
    .withCADAlgorithm(
        name: "Algorithm Name",
        version: "1.0.0",
        manufacturer: "Company Name"
    )
 
 4. CAD FINDING:
    .addFinding { finding in
        // Required
        finding.withType(codedConcept)
        
        // Location
        finding.withLocation(anatomyConcept, laterality: .right)
        
        // Confidence
        finding.withProbability(0.87)  // 0.0 to 1.0
        
        // Coordinates
        finding.withCenterCoordinates(x: 512, y: 768, imageReference: img)
        finding.with3DCoordinates(x: 125, y: 87, z: 142, imageReference: img)
        
        // Size
        finding.withSize(width: 15.2, height: 18.5, unit: .millimeters)
        finding.withVolume(value: 245.7, unit: .cubicMillimeters)
        
        // Classification
        finding.withMalignancyProbability(0.32)
        finding.withMorphology(shapeConcept)
        finding.withClassificationProbabilities([
            "Class1": 0.78,
            "Class2": 0.15,
            "Class3": 0.07
        ])
    }
 
 5. READING CAD FINDINGS:
    let extractor = CADFindingsExtractor(document: sr)
    let findings = try extractor.extractFindings()
    
    for finding in findings {
        print("Type: \(finding.findingType.codeMeaning)")
        print("Confidence: \(finding.probability ?? 0)")
        print("Location: \(finding.location?.codeMeaning ?? "N/A")")
    }
 
 6. FINDING PROPERTIES:
    - findingType: CodedConcept
    - location: CodedConcept?
    - laterality: Laterality?
    - probability: Double?  // 0.0-1.0
    - centerCoordinates: (x: Double, y: Double)?
    - coordinates3D: (x: Double, y: Double, z: Double)?
    - size: (width: Double, height: Double)?
    - volume: Double?
    - malignancyProbability: Double?
    - morphology: CodedConcept?
 
 7. COMMON FINDING TYPES (SNOMED CT):
    Mammography:
    - Mass: 24727000
    - Calcification: 129762008
    - Architectural distortion: 369745005
    - Asymmetry: 271650006
    
    Chest:
    - Pulmonary nodule: 41381004
    - Infiltration: 301234006
    - Consolidation: 79922009
    - Pneumothorax: 36118008
    - Pleural effusion: 60046008
 
 8. ANATOMIC LOCATIONS (SNOMED CT):
    - Breast: 76752008
    - Lung: 39607008
    - Right upper lobe lung: 45653009
    - Left lower lobe lung: 31094006
    - Liver: 10200004
 
 9. LATERALITY:
    .left
    .right
    .bilateral
    .unpaired
 
 10. FILTERING FINDINGS:
     // By confidence
     let highConf = findings.filter { ($0.probability ?? 0) >= 0.80 }
     
     // By type
     let nodules = findings.filter { $0.findingType.codeMeaning.contains("nodule") }
     
     // By location
     let rightSide = findings.filter { $0.laterality == .right }
 
 11. UNITS:
     .millimeters
     .centimeters
     .cubicMillimeters
     .cubicCentimeters
     .pixels
 
 12. BEST PRACTICES:
     ✓ Include algorithm name and version
     ✓ Use standard SNOMED CT codes for findings
     ✓ Provide confidence/probability scores
     ✓ Include spatial coordinates when available
     ✓ Reference source images
     ✓ Use consistent coordinate systems
     ✓ Document coordinate space (pixel vs physical)
     ✓ Include malignancy assessment for oncology
     ✓ Filter low-confidence findings for clinical use
     ✓ Preserve all detections in research mode
 
 13. COORDINATE SYSTEMS:
     2D Image Coordinates:
     - Origin: top-left corner
     - X: left to right (columns)
     - Y: top to bottom (rows)
     - Units: pixels or mm
     
     3D Volume Coordinates:
     - Patient coordinate system (DICOM)
     - X: left to right
     - Y: posterior to anterior
     - Z: inferior to superior
     - Units: millimeters
 
 14. USE CASES:
     - Mammography screening CAD
     - Lung nodule detection
     - Colonography polyp detection
     - Bone age assessment
     - Diabetic retinopathy screening
     - AI/ML algorithm outputs
     - Multi-reader detection studies
     - Algorithm validation
 
 15. INTEGRATION:
     - Export to PACS with CAD markers
     - Overlay findings on images
     - Integration with reading workflow
     - Comparison with radiologist annotations
     - Algorithm performance tracking
     - FDA/regulatory documentation
 
 16. REFERENCE:
     - DICOM PS3.16 TID 4100: Mammography CAD
     - DICOM PS3.16 TID 4101: Chest CAD
     - SNOMED CT Browser
     - FDA guidance on CAD devices
 */

// MARK: - Running the Examples
// Uncomment to run individual examples:
// try? example1_basicMammographyCAD()
// try? example2_multipleMammographyFindings()
// try? example3_chestCADLungNodules()
// try? example4_cadClassification()
// try? example5_readingCADFindings()
// try? example6_filteringFindings()
// try? example7_cadSummaryReport()
// try? example8_exportingCADToJSON()
// try? example9_aiModelOutputToCADSR()
