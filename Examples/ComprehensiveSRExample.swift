/// Comprehensive SR Example
///
/// This example demonstrates how to create DICOM Comprehensive SR documents
/// with spatial coordinates (2D regions of interest) and temporal coordinates.
///
/// Comprehensive SR supports all Enhanced SR features plus:
/// - SCOORD: 2D spatial coordinates (points, polylines, polygons, circles, ellipses)
/// - TCOORD: Temporal coordinates (sample positions, time offsets, datetime ranges)
///
/// Use cases:
/// - Radiology reports with ROI annotations
/// - Cardiac perfusion analysis with time-based measurements
/// - Radiation therapy planning annotations
/// - Image analysis with region-based measurements

import Foundation
import DICOMKit
import DICOMCore

/// Example: Lung nodule report with ROI annotations
func createLungNoduleReportWithROI() throws -> SRDocument {
    // Reference to the CT image containing the nodule
    let imageReference = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.12345.600",
        referencedFrameNumber: nil  // Single-frame image
    )
    
    let document = try ComprehensiveSRBuilder()
        // Patient Information
        .withPatientID("11223344")
        .withPatientName("Davis^Emma^^^")
        .withPatientBirthDate("19620508")
        .withPatientSex("F")
        
        // Study Information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.12345.300")
        .withStudyDate("20260204")
        .withStudyTime("084500")
        .withStudyDescription("CT Chest Screening")
        .withAccessionNumber("ACC555666")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.12345.301")
        .withSeriesNumber("2")
        .withModality("SR")
        
        // Document Information
        .withDocumentTitle("Lung Nodule Analysis")
        .withCompletionFlag(.complete)
        .withVerificationFlag(.verified)
        
        // Findings with spatial annotations
        .addSection("Findings") { section in
            section.addText("A spiculated nodule is identified in the right upper lobe.")
            
            // Nodule location as a point
            section.addPoint(
                x: 256.5,
                y: 189.3,
                imageReference: imageReference,
                concept: CodedConcept(
                    codeValue: "123456",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Nodule Center"
                )
            )
            
            // Nodule outline as a polygon (approximating circular shape)
            let noduleOutline: [(Double, Double)] = [
                (256.5, 175.0), // top
                (262.0, 177.5), // top-right
                (266.0, 182.5), // right
                (267.0, 189.3), // center-right
                (266.0, 196.0), // bottom-right
                (262.0, 201.0), // bottom
                (256.5, 203.5), // bottom center
                (251.0, 201.0), // bottom-left
                (247.0, 196.0), // left-bottom
                (246.0, 189.3), // center-left
                (247.0, 182.5), // left-top
                (251.0, 177.5), // top-left
            ]
            
            section.addPolygon(
                points: noduleOutline,
                imageReference: imageReference,
                concept: CodedConcept(
                    codeValue: "123457",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Nodule Boundary"
                )
            )
            
            // Nodule as a circle (alternative to polygon)
            section.addCircle(
                centerX: 256.5,
                centerY: 189.3,
                radius: 14.2,
                imageReference: imageReference,
                concept: CodedConcept(
                    codeValue: "123458",
                    codingSchemeDesignator: .dcm,
                    codeMeaning: "Nodule ROI"
                )
            )
            
            // Linear measurement line
            section.addPolyline(
                points: [(242.0, 189.3), (271.0, 189.3)],  // Horizontal line through center
                imageReference: imageReference,
                concept: .diameter
            )
            
            // Add corresponding numeric measurement
            section.addMeasurementMM(
                value: 28.4,
                concept: .diameter,
                description: "Maximum nodule diameter"
            )
        }
        
        .addSection("Impression") { section in
            section.addText("Suspicious spiculated nodule in right upper lobe, " +
                          "measuring 28.4 mm. Recommend biopsy.")
        }
        
        .build()
    
    return document
}

/// Example: Cardiac perfusion analysis with temporal coordinates
func createCardiacPerfusionReport() throws -> SRDocument {
    // Reference to the perfusion series
    let perfusionImageRef = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.99999.700"
    )
    
    let document = try ComprehensiveSRBuilder()
        .withPatientID("77788899")
        .withPatientName("Miller^Robert^^^")
        .withDocumentTitle("Cardiac Perfusion Analysis")
        
        .addSection("Myocardial Perfusion") { section in
            section.addText("Dynamic contrast enhancement evaluated in the left ventricular myocardium.")
            
            // Define an ROI in the myocardium
            section.addCircle(
                centerX: 128.0,
                centerY: 140.0,
                radius: 25.0,
                imageReference: perfusionImageRef,
                concept: CodedConcept(
                    codeValue: "85421007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Myocardial region of interest"
                )
            )
            
            // Time-intensity measurements at different time points
            section.addSection("Time-Intensity Curve") { timeSection in
                // Baseline (sample position 1)
                timeSection.addTemporalPoint(
                    samplePosition: 1,
                    concept: CodedConcept(
                        codeValue: "113794",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Baseline"
                    )
                )
                timeSection.addMeasurement(
                    value: 45.0,
                    units: "[hnsf'U]",  // Hounsfield units
                    concept: CodedConcept(
                        codeValue: "112033",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Attenuation Coefficient"
                    ),
                    description: "Baseline intensity"
                )
                
                // Peak enhancement (sample position 15, ~30 seconds)
                timeSection.addTemporalPoint(
                    samplePosition: 15,
                    concept: CodedConcept(
                        codeValue: "113795",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Peak Enhancement"
                    )
                )
                timeSection.addMeasurement(
                    value: 185.0,
                    units: "[hnsf'U]",
                    concept: CodedConcept(
                        codeValue: "112033",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Attenuation Coefficient"
                    ),
                    description: "Peak intensity"
                )
                
                // Washout phase (sample position 45, ~90 seconds)
                timeSection.addTemporalPoint(
                    samplePosition: 45,
                    concept: CodedConcept(
                        codeValue: "113796",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Washout"
                    )
                )
                timeSection.addMeasurement(
                    value: 78.0,
                    units: "[hnsf'U]",
                    concept: CodedConcept(
                        codeValue: "112033",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Attenuation Coefficient"
                    ),
                    description: "Washout intensity"
                )
            }
            
            // Perfusion parameters
            section.addSection("Perfusion Parameters") { paramSection in
                paramSection.addMeasurement(
                    value: 140.0,
                    units: "[hnsf'U]",
                    concept: CodedConcept(
                        codeValue: "113797",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Peak Enhancement"
                    ),
                    description: "Peak enhancement above baseline"
                )
                
                paramSection.addMeasurement(
                    value: 30.0,
                    units: "s",
                    concept: CodedConcept(
                        codeValue: "113798",
                        codingSchemeDesignator: .dcm,
                        codeMeaning: "Time to Peak"
                    ),
                    description: "Time to peak enhancement"
                )
            }
        }
        
        .addSection("Impression") { section in
            section.addText("Normal myocardial perfusion pattern with appropriate " +
                          "contrast uptake and washout kinetics.")
        }
        
        .build()
    
    return document
}

/// Example: Multi-region tumor analysis
func createTumorAnalysisWithMultipleROIs() throws -> SRDocument {
    let imageRef = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.88888.800"
    )
    
    let document = try ComprehensiveSRBuilder()
        .withPatientID("44455566")
        .withPatientName("Anderson^Lisa^^^")
        .withDocumentTitle("Tumor Analysis Report")
        
        .addSection("Tumor Characterization") { section in
            // Primary tumor
            section.addSection("Primary Tumor") { tumorSection in
                // Tumor boundary as ellipse
                tumorSection.addEllipse(
                    centerX: 180.0,
                    centerY: 220.0,
                    majorAxisRadius: 45.0,
                    minorAxisRadius: 32.0,
                    imageReference: imageRef,
                    concept: CodedConcept(
                        codeValue: "108369006",
                        codingSchemeDesignator: .snomedCT,
                        codeMeaning: "Tumor"
                    )
                )
                
                // Tumor measurements
                tumorSection.addMeasurementMM(value: 90.0, concept: .diameter,
                                            description: "Long axis")
                tumorSection.addMeasurementMM(value: 64.0, concept: .diameter,
                                            description: "Short axis")
                tumorSection.addMeasurement(value: 18200.0, units: "mm2", concept: .area,
                                          description: "Cross-sectional area")
            }
            
            // Necrotic region
            section.addSection("Necrotic Core") { necroticSection in
                // Irregular necrotic region as polygon
                let necroticBoundary: [(Double, Double)] = [
                    (175.0, 215.0),
                    (185.0, 213.0),
                    (190.0, 218.0),
                    (188.0, 225.0),
                    (180.0, 227.0),
                    (172.0, 223.0)
                ]
                
                necroticSection.addPolygon(
                    points: necroticBoundary,
                    imageReference: imageRef,
                    concept: CodedConcept(
                        codeValue: "6574001",
                        codingSchemeDesignator: .snomedCT,
                        codeMeaning: "Necrosis"
                    )
                )
                
                necroticSection.addMeasurement(value: 950.0, units: "mm2", concept: .area,
                                             description: "Necrotic area")
            }
        }
        
        .addSection("Impression") { section in
            section.addText("Large heterogeneous tumor with central necrosis. " +
                          "Primary tumor measures 90 × 64 mm with approximately 5% necrotic core.")
        }
        
        .build()
    
    return document
}

/// Example: Extracting spatial coordinates from a Comprehensive SR
func extractSpatialCoordinatesExample() throws {
    let document = try createLungNoduleReportWithROI()
    
    let extractor = MeasurementExtractor()
    let coordinates = extractor.extractSpatialCoordinates(from: document)
    
    print("Found \(coordinates.count) spatial coordinate annotations:")
    for coord in coordinates {
        print("\n  Type: \(coord.graphicType)")
        print("  Points: \(coord.graphicData)")
        
        if let boundingBox = coord.boundingBox {
            print("  Bounding box: \(boundingBox)")
        }
        
        if let centroid = coord.centroid {
            print("  Centroid: \(centroid)")
        }
        
        if let area = coord.area {
            print("  Area: \(String(format: "%.2f", area)) pixels²")
        }
    }
    
    // Extract ROIs (coordinates combined with measurements)
    let rois = extractor.extractROIs(from: document)
    print("\nFound \(rois.count) regions of interest with measurements")
}

// MARK: - Usage Examples

/*
 To use these Comprehensive SR examples:
 
 1. Create a lung nodule report with ROI:
 
    do {
        let report = try createLungNoduleReportWithROI()
        
        // Save to file
        let dataSet = try SRDocumentSerializer.serialize(report)
        let writer = DICOMWriter()
        let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
        try fileData.write(to: URL(fileURLWithPath: "/tmp/nodule_roi.dcm"))
        
        print("Saved nodule report with ROI annotations")
    } catch {
        print("Error: \(error)")
    }
 
 2. Create a cardiac perfusion report with temporal analysis:
 
    let report = try createCardiacPerfusionReport()
    print("Created perfusion report with time-intensity curve")
 
 3. Extract spatial coordinates:
 
    try extractSpatialCoordinatesExample()
 
 4. Query for specific coordinate types:
 
    let document = try createLungNoduleReportWithROI()
    let navigator = ContentTreeNavigator(document: document)
    
    // Find all SCOORD items
    let scoordItems = navigator.filter { item in
        item is SpatialCoordinatesContentItem
    }
    
    print("Found \(scoordItems.count) spatial coordinate annotations")
    
    for item in scoordItems {
        if let scoord = item as? SpatialCoordinatesContentItem {
            print("  Graphic type: \(scoord.graphicType)")
            print("  Number of points: \(scoord.graphicData.count)")
        }
    }
 
 5. Calculate ROI statistics:
 
    let document = try createTumorAnalysisWithMultipleROIs()
    let extractor = MeasurementExtractor()
    let rois = extractor.extractROIs(from: document)
    
    for roi in rois {
        if let area = roi.area {
            print("ROI area: \(area) pixels²")
        }
        
        print("Associated measurements: \(roi.measurements.count)")
        for measurement in roi.measurements {
            print("  \(measurement.concept?.codeMeaning ?? "Unknown"): " +
                  "\(measurement.value) \(measurement.unit)")
        }
    }
 */
