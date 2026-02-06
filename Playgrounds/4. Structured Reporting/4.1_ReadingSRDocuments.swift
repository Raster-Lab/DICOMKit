/// Playground 4.1: Reading SR Documents
///
/// This playground demonstrates how to read and parse DICOM Structured Report (SR) documents
/// using DICOMKit. SR documents contain structured clinical information, measurements,
/// and observations in a standardized format.
///
/// Topics covered:
/// - Loading SR documents from files
/// - Accessing SR document properties
/// - Navigating the content tree
/// - Extracting text and coded values
/// - Finding specific observations
/// - Handling different SR document types

import Foundation
import DICOMKit
import DICOMCore

// MARK: - Example 1: Loading SR Documents

/// Load an SR document from a DICOM file
func example1_loadingSRDocument() throws {
    // Load a DICOM file containing an SR document
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    
    // Parse the SR document
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    print("SR Document loaded successfully")
    print("Document Type: \(srDocument.documentType)")
    print("Completion Flag: \(srDocument.completionFlag)")
    print("Verification Flag: \(srDocument.verificationFlag)")
}

// MARK: - Example 2: Accessing SR Document Properties

/// Access basic properties of an SR document
func example2_accessingDocumentProperties() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Patient information
    print("Patient Name: \(srDocument.patientName ?? "Unknown")")
    print("Patient ID: \(srDocument.patientID ?? "Unknown")")
    print("Patient Birth Date: \(srDocument.patientBirthDate ?? "Unknown")")
    print("Patient Sex: \(srDocument.patientSex ?? "Unknown")")
    
    // Study information
    print("\nStudy Instance UID: \(srDocument.studyInstanceUID)")
    print("Study Date: \(srDocument.studyDate ?? "Unknown")")
    print("Study Time: \(srDocument.studyTime ?? "Unknown")")
    print("Study Description: \(srDocument.studyDescription ?? "Unknown")")
    print("Accession Number: \(srDocument.accessionNumber ?? "Unknown")")
    
    // Series information
    print("\nSeries Instance UID: \(srDocument.seriesInstanceUID)")
    print("Series Number: \(srDocument.seriesNumber ?? "Unknown")")
    print("Modality: \(srDocument.modality)")
    
    // Document-specific information
    print("\nDocument Title: \(srDocument.documentTitle)")
    print("Completion Flag: \(srDocument.completionFlag)")
    print("Verification Flag: \(srDocument.verificationFlag)")
    if let observationDateTime = srDocument.observationDateTime {
        print("Observation Date/Time: \(observationDateTime)")
    }
}

// MARK: - Example 3: Navigating the Content Tree

/// Navigate through the hierarchical content tree structure
func example3_navigatingContentTree() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Access the root content item (CONTAINER)
    guard let rootItem = srDocument.rootContentItem else {
        print("No root content item found")
        return
    }
    
    print("Root content item type: \(rootItem.valueType)")
    
    // Recursively traverse content tree
    func traverseContentTree(_ item: AnyContentItem, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)
        
        print("\(indent)- Type: \(item.valueType)")
        
        // Print relationship type if available
        if let relationship = item.relationshipType {
            print("\(indent)  Relationship: \(relationship)")
        }
        
        // Print concept name if available
        if let conceptName = item.conceptName {
            print("\(indent)  Concept: \(conceptName.codeMeaning)")
        }
        
        // Process children
        for child in item.children {
            traverseContentTree(child, depth: depth + 1)
        }
    }
    
    traverseContentTree(rootItem)
}

// MARK: - Example 4: Extracting Text Content

/// Extract all text content from an SR document
func example4_extractingTextContent() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Use ContentTreeNavigator to find all TEXT items
    let navigator = ContentTreeNavigator(document: srDocument)
    let textItems = navigator.findContentItems(ofType: .text)
    
    print("Found \(textItems.count) text items:")
    for (index, item) in textItems.enumerated() {
        if let textValue = item.textValue {
            print("\n[\(index + 1)] \(textValue)")
        }
    }
}

// MARK: - Example 5: Finding Coded Observations

/// Find specific coded observations in the content tree
func example5_findingCodedObservations() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let navigator = ContentTreeNavigator(document: srDocument)
    
    // Find all CODE items
    let codeItems = navigator.findContentItems(ofType: .code)
    
    print("Found \(codeItems.count) coded items:")
    for item in codeItems {
        if let conceptName = item.conceptName {
            print("\nConcept: \(conceptName.codeMeaning)")
        }
        
        if let codedValue = item.codeValue {
            print("  Value: \(codedValue.codeMeaning)")
            print("  Code: \(codedValue.codeValue)")
            print("  Scheme: \(codedValue.codingSchemeDesignator)")
        }
    }
}

// MARK: - Example 6: Extracting Measurements

/// Extract numeric measurements from an SR document
func example6_extractingMeasurements() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/measurement_report.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Use MeasurementExtractor for TID 1500 measurement reports
    let extractor = MeasurementExtractor(document: srDocument)
    let measurements = try extractor.extractAllMeasurements()
    
    print("Found \(measurements.count) measurements:")
    for measurement in measurements {
        print("\nTracking ID: \(measurement.trackingIdentifier ?? "N/A")")
        print("Type: \(measurement.measurementType)")
        
        if let value = measurement.numericValue {
            let unit = measurement.unit ?? ""
            print("Value: \(value) \(unit)")
        }
        
        if let location = measurement.findingSite {
            print("Location: \(location.codeMeaning)")
        }
    }
}

// MARK: - Example 7: Finding Image References

/// Find references to source images in the SR document
func example7_findingImageReferences() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    let navigator = ContentTreeNavigator(document: srDocument)
    
    // Find all IMAGE items
    let imageItems = navigator.findContentItems(ofType: .image)
    
    print("Found \(imageItems.count) image references:")
    for item in imageItems {
        if let imageReference = item.imageReference {
            print("\nReferenced SOP Class UID: \(imageReference.referencedSOPClassUID)")
            print("Referenced SOP Instance UID: \(imageReference.referencedSOPInstanceUID)")
            
            if let frameNumbers = imageReference.referencedFrameNumbers {
                print("Frame Numbers: \(frameNumbers)")
            }
        }
    }
}

// MARK: - Example 8: Extracting CAD Findings

/// Extract Computer-Aided Detection (CAD) findings from a CAD SR
func example8_extractingCADFindings() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/cad_sr.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    // Use CADFindingsExtractor for CAD SR documents
    let extractor = CADFindingsExtractor(document: srDocument)
    let findings = try extractor.extractFindings()
    
    print("Found \(findings.count) CAD findings:")
    for finding in findings {
        print("\n--- Finding ---")
        print("Type: \(finding.findingType.codeMeaning)")
        
        if let probability = finding.probability {
            print("Probability: \(probability * 100)%")
        }
        
        if let location = finding.location {
            print("Location: \(location.codeMeaning)")
        }
        
        if let center = finding.centerCoordinates {
            print("Center: (\(center.x), \(center.y))")
        }
    }
}

// MARK: - Example 9: Handling Different SR Document Types

/// Identify and handle different types of SR documents
func example9_handlingDocumentTypes() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/sr_document.dcm")
    let dicomFile = try DICOMFile.read(from: fileURL)
    let srDocument = try SRDocumentParser.parse(from: dicomFile)
    
    switch srDocument.documentType {
    case .basicTextSR:
        print("Document Type: Basic Text SR")
        print("Simple narrative reports with minimal structure")
        
    case .enhancedSR:
        print("Document Type: Enhanced SR")
        print("More structured with rich coding support")
        
    case .comprehensiveSR:
        print("Document Type: Comprehensive SR")
        print("Full DICOM SR capabilities")
        
    case .comprehensive3DSR:
        print("Document Type: Comprehensive 3D SR")
        print("Includes 3D spatial coordinates")
        
    case .procedureLog:
        print("Document Type: Procedure Log")
        print("Records performed procedures")
        
    case .mammographyCADSR:
        print("Document Type: Mammography CAD SR")
        print("CAD findings for mammography")
        
    case .chestCADSR:
        print("Document Type: Chest CAD SR")
        print("CAD findings for chest imaging")
        
    case .imagingMeasurementReport:
        print("Document Type: Imaging Measurement Report (TID 1500)")
        print("Structured measurement reports")
        
    case .keyObjectSelection:
        print("Document Type: Key Object Selection")
        print("References to significant images/findings")
        
    default:
        print("Document Type: \(srDocument.documentType)")
    }
}

// MARK: - Quick Reference

/*
 SR DOCUMENT READING QUICK REFERENCE
 ===================================
 
 1. LOADING SR DOCUMENTS:
    let file = try DICOMFile.read(from: url)
    let sr = try SRDocumentParser.parse(from: file)
 
 2. DOCUMENT PROPERTIES:
    - sr.documentType          // Type of SR document
    - sr.completionFlag        // .partial or .complete
    - sr.verificationFlag      // .unverified or .verified
    - sr.documentTitle         // Title of the report
    - sr.patientName           // Patient demographics
    - sr.studyInstanceUID      // Study identification
 
 3. CONTENT TREE NAVIGATION:
    - sr.rootContentItem       // Root CONTAINER item
    - item.children            // Child content items
    - item.valueType           // TEXT, CODE, NUM, IMAGE, etc.
    - item.conceptName         // What this item represents
    - item.relationshipType    // CONTAINS, HAS_OBS_CONTEXT, etc.
 
 4. CONTENT TREE NAVIGATOR:
    let nav = ContentTreeNavigator(document: sr)
    
    - nav.findContentItems(ofType: .text)
    - nav.findContentItems(ofType: .code)
    - nav.findContentItems(ofType: .num)
    - nav.findContentItems(ofType: .image)
    - nav.findContentItems(matching: { item in ... })
 
 5. SPECIALIZED EXTRACTORS:
    // Measurements (TID 1500)
    let measExtractor = MeasurementExtractor(document: sr)
    let measurements = try measExtractor.extractAllMeasurements()
    
    // CAD Findings
    let cadExtractor = CADFindingsExtractor(document: sr)
    let findings = try cadExtractor.extractFindings()
    
    // Measurement Reports
    let reportExtractor = MeasurementReportExtractor(document: sr)
    let report = try reportExtractor.extract()
    
    // Key Objects
    let keyExtractor = KeyObjectExtractor(document: sr)
    let keyObjects = try keyExtractor.extractKeyObjects()
 
 6. VALUE TYPES:
    - .text        // Free-text string
    - .code        // Coded concept (SNOMED, LOINC, etc.)
    - .num         // Numeric measurement
    - .date        // Date value
    - .time        // Time value
    - .dateTime    // Date and time
    - .pname       // Person name
    - .uidref      // UID reference
    - .image       // Image reference
    - .waveform    // Waveform reference
    - .scoord      // Spatial coordinates
    - .tcoord      // Temporal coordinates
    - .composite   // Composite reference
    - .container   // Container for sub-items
 
 7. RELATIONSHIP TYPES:
    - .contains            // Parent-child relationship
    - .hasObsContext       // Observation context
    - .hasAcqContext       // Acquisition context
    - .hasConceptMod       // Concept modifier
    - .hasProperties       // Properties
    - .inferredFrom        // Inference source
    - .selectedFrom        // Selection source
 
 8. DOCUMENT TYPES:
    - .basicTextSR              // Simple text reports
    - .enhancedSR               // Enhanced structure
    - .comprehensiveSR          // Full capabilities
    - .comprehensive3DSR        // With 3D coordinates
    - .mammographyCADSR         // Mammo CAD
    - .chestCADSR               // Chest CAD
    - .imagingMeasurementReport // TID 1500 measurements
    - .keyObjectSelection       // Key image notes
    - .procedureLog             // Procedure records
 
 9. ERROR HANDLING:
    do {
        let sr = try SRDocumentParser.parse(from: file)
        // Process SR document
    } catch let error as SRParsingError {
        switch error {
        case .invalidStructure:
            print("Invalid SR structure")
        case .missingRequiredContent:
            print("Missing required content")
        case .unsupportedTemplate:
            print("Unsupported template")
        default:
            print("Parsing error: \(error)")
        }
    }
 
 10. BEST PRACTICES:
     ✓ Check document type before processing
     ✓ Use specialized extractors for known templates
     ✓ Validate completion and verification flags
     ✓ Handle missing optional content gracefully
     ✓ Use ContentTreeNavigator for complex searches
     ✓ Cache parsed SR documents if reused
     ✓ Consider privacy when logging SR content
 
 COMMON TEMPLATES:
 - TID 1500: Measurement Report
 - TID 1400: Key Object Selection
 - TID 1600: Image Library
 - TID 4019: CT Radiation Dose
 - TID 300: Measurement
 - TID 1411: Volumetric ROI Measurements
 
 CODING SCHEMES:
 - SNOMED CT: snomedCT
 - LOINC: loinc
 - RadLex: radlex
 - UCUM: ucum (units)
 - DCM: dcm (DICOM controlled terminology)
 
 REFERENCE:
 - DICOM PS3.3 A.35: SR Document Content Module
 - DICOM PS3.16: Content Mapping Resource (Templates)
 - DICOM PS3.6 Section 8: Data Element Tags
 */

// MARK: - Running the Examples
// Uncomment to run individual examples:
// try? example1_loadingSRDocument()
// try? example2_accessingDocumentProperties()
// try? example3_navigatingContentTree()
// try? example4_extractingTextContent()
// try? example5_findingCodedObservations()
// try? example6_extractingMeasurements()
// try? example7_findingImageReferences()
// try? example8_extractingCADFindings()
// try? example9_handlingDocumentTypes()
