/// Playground 4.2: Creating Basic SR Documents
///
/// This playground demonstrates how to create DICOM Structured Report (SR) documents
/// using DICOMKit builders. Learn to construct narrative reports with structured content.
///
/// Topics covered:
/// - Creating Basic Text SR documents
/// - Adding patient and study information
/// - Building hierarchical sections
/// - Adding text content
/// - Adding coded values
/// - Setting completion and verification flags
/// - Serializing SR documents to DICOM files

import Foundation
import DICOMKit
import DICOMCore

// MARK: - Example 1: Simple Radiology Report

/// Create a basic radiology report with text sections
func example1_simpleRadiologyReport() throws {
    let document = try BasicTextSRBuilder()
        // Patient Information
        .withPatientID("12345678")
        .withPatientName("Doe^John^^^")
        .withPatientBirthDate("19800115")
        .withPatientSex("M")
        
        // Study Information
        .withStudyInstanceUID("1.2.840.113619.2.55.3.123456789.100")
        .withStudyDate("20260204")
        .withStudyTime("143000")
        .withStudyDescription("Chest X-Ray")
        .withAccessionNumber("ACC123456")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.123456789.101")
        .withSeriesNumber("1")
        .withModality("SR")
        
        // Document Information
        .withDocumentTitle("Radiology Report")
        .withCompletionFlag(.complete)
        .withVerificationFlag(.verified)
        
        // Report Content
        .addSection("Clinical History") { section in
            section.addText("Patient presents with cough and fever for 3 days.")
        }
        
        .addSection("Findings") { section in
            section.addText("The lungs are clear bilaterally. No consolidation.")
            section.addText("Cardiac silhouette is normal in size.")
        }
        
        .addSection("Impression") { section in
            section.addText("Normal chest radiograph.")
        }
        
        .build()
    
    print("Created radiology report")
    print("Document Type: \(document.documentType)")
}

// MARK: - Example 2: Report with Nested Sections

/// Create a report with hierarchical subsections
func example2_nestedSections() throws {
    let document = try BasicTextSRBuilder()
        .withPatientID("87654321")
        .withPatientName("Smith^Alice^^^")
        .withDocumentTitle("CT Abdomen Report")
        
        .addSection("Technique") { section in
            section.addText("CT scan of abdomen and pelvis with IV contrast")
            section.addText("Scanning parameters: 120 kVp, 200 mAs")
        }
        
        .addSection("Findings") { section in
            section.addText("Multiple organs evaluated:")
            
            // Liver subsection
            section.addSection("Liver") { liver in
                liver.addText("Normal size and attenuation.")
                liver.addText("No focal lesions identified.")
            }
            
            // Spleen subsection
            section.addSection("Spleen") { spleen in
                spleen.addText("Normal size, measuring 11 cm in length.")
                spleen.addText("Homogeneous attenuation.")
            }
            
            // Pancreas subsection
            section.addSection("Pancreas") { pancreas in
                pancreas.addText("Normal appearance.")
                pancreas.addText("No masses or ductal dilatation.")
            }
            
            // Kidneys subsection
            section.addSection("Kidneys") { kidneys in
                kidneys.addText("Both kidneys enhance symmetrically.")
                kidneys.addText("No hydronephrosis or calculi.")
            }
        }
        
        .addSection("Impression") { section in
            section.addText("1. Normal CT abdomen and pelvis.")
            section.addText("2. No acute abnormality.")
        }
        
        .build()
    
    print("Created CT abdomen report with nested sections")
}

// MARK: - Example 3: Adding Coded Observations

/// Create a report with coded findings
func example3_codedObservations() throws {
    let document = try EnhancedSRBuilder()
        .withPatientID("11223344")
        .withPatientName("Jones^Robert^^^")
        .withDocumentTitle("Findings Report")
        
        .addSection("Findings") { section in
            // Add text with associated coded concept
            section.addObservation(
                concept: CodedConcept(
                    codeValue: "85354-9",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "Blood pressure"
                ),
                textValue: "Blood pressure: 120/80 mmHg"
            )
            
            section.addObservation(
                concept: CodedConcept(
                    codeValue: "8867-4",
                    codingSchemeDesignator: .loinc,
                    codeMeaning: "Heart rate"
                ),
                textValue: "Heart rate: 72 beats/min"
            )
            
            // Add coded value observation
            section.addCodedObservation(
                concept: CodedConcept(
                    codeValue: "371508000",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Examination result"
                ),
                value: CodedConcept(
                    codeValue: "17621005",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Normal"
                )
            )
        }
        
        .build()
    
    print("Created report with coded observations")
}

// MARK: - Example 4: Multi-Observer Report

/// Create a report with multiple observers/verifiers
func example4_multiObserverReport() throws {
    let document = try BasicTextSRBuilder()
        .withPatientID("99887766")
        .withPatientName("Brown^Lisa^^^")
        .withDocumentTitle("Consultation Report")
        
        // Initial observer
        .withObserver(
            name: "Smith^Jane^^^Dr.",
            organization: "Radiology Department"
        )
        
        // Document content
        .addSection("Consultation") { section in
            section.addText("Patient referred for second opinion on lung nodule.")
        }
        
        .addSection("Opinion") { section in
            section.addText("Recommend follow-up CT in 3 months.")
            section.addText("No intervention needed at this time.")
        }
        
        // Verification by another physician
        .withVerifier(
            name: "Johnson^Mark^^^Dr.",
            organization: "Radiology Department",
            verificationDateTime: Date()
        )
        
        .withCompletionFlag(.complete)
        .withVerificationFlag(.verified)
        
        .build()
    
    print("Created multi-observer consultation report")
}

// MARK: - Example 5: Comprehensive SR with Templates

/// Create a Comprehensive SR using standardized templates
func example5_comprehensiveSR() throws {
    let document = try ComprehensiveSRBuilder()
        .withPatientID("55443322")
        .withPatientName("Wilson^Emma^^^")
        .withDocumentTitle("Comprehensive Report")
        
        // Use TID 1001: Observation Context
        .withObservationContext(
            observer: "Smith^Jane^^^Dr.",
            observationDateTime: Date()
        )
        
        // Add procedure reported
        .withProcedureReported(
            CodedConcept(
                codeValue: "241615005",
                codingSchemeDesignator: .snomedCT,
                codeMeaning: "CT of chest"
            )
        )
        
        .addSection("Findings") { section in
            // Add structured finding using standard codes
            section.addFinding(
                site: CodedConcept(
                    codeValue: "39607008",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Lung structure"
                ),
                finding: CodedConcept(
                    codeValue: "41381004",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Pulmonary nodule"
                ),
                description: "Small nodule in right upper lobe, 8mm"
            )
        }
        
        .build()
    
    print("Created comprehensive SR with templates")
}

// MARK: - Example 6: Procedure Log

/// Create a procedure log SR document
func example6_procedureLog() throws {
    let document = try ComprehensiveSRBuilder()
        .withDocumentType(.procedureLog)
        .withPatientID("33221100")
        .withPatientName("Davis^Michael^^^")
        .withDocumentTitle("Procedure Log")
        
        .withProcedureReported(
            CodedConcept(
                codeValue: "77003",
                codingSchemeDesignator: .cpt4,
                codeMeaning: "Fluoroscopic guidance"
            )
        )
        
        .addSection("Procedure Details") { section in
            section.addText("Start time: 14:30")
            section.addText("End time: 15:15")
            section.addText("Fluoroscopy time: 3.2 minutes")
            section.addText("Dose area product: 245 mGy·cm²")
        }
        
        .addSection("Complications") { section in
            section.addCodedObservation(
                concept: CodedConcept(
                    codeValue: "116223007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Complication status"
                ),
                value: CodedConcept(
                    codeValue: "260413007",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "None"
                )
            )
        }
        
        .build()
    
    print("Created procedure log")
}

// MARK: - Example 7: Adding Image References

/// Create a report that references source images
func example7_imageReferences() throws {
    // Define image reference
    let ctImage = ImageReference(
        referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
        referencedSOPInstanceUID: "1.2.840.113619.2.55.3.IMG.100"
    )
    
    let document = try EnhancedSRBuilder()
        .withPatientID("77665544")
        .withPatientName("Taylor^Sarah^^^")
        .withDocumentTitle("Image Findings Report")
        
        .addSection("Findings") { section in
            section.addText("Abnormality identified on image series 3.")
            
            // Reference the specific image
            section.addImageReference(
                ctImage,
                description: "Axial CT showing lesion"
            )
            
            section.addText("Lesion measures approximately 2.5 cm.")
        }
        
        .build()
    
    print("Created report with image references")
}

// MARK: - Example 8: Adding Numeric Measurements

/// Add numeric measurements to a report
func example8_numericMeasurements() throws {
    let document = try EnhancedSRBuilder()
        .withPatientID("44556677")
        .withPatientName("Anderson^Chris^^^")
        .withDocumentTitle("Measurement Report")
        
        .addSection("Measurements") { section in
            // Add numeric measurement with units
            section.addNumericMeasurement(
                concept: CodedConcept(
                    codeValue: "410668003",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Length"
                ),
                value: 42.5,
                unit: CodedConcept(
                    codeValue: "mm",
                    codingSchemeDesignator: .ucum,
                    codeMeaning: "millimeter"
                )
            )
            
            section.addNumericMeasurement(
                concept: CodedConcept(
                    codeValue: "42798000",
                    codingSchemeDesignator: .snomedCT,
                    codeMeaning: "Area"
                ),
                value: 125.3,
                unit: CodedConcept(
                    codeValue: "mm2",
                    codingSchemeDesignator: .ucum,
                    codeMeaning: "square millimeter"
                )
            )
        }
        
        .build()
    
    print("Created report with numeric measurements")
}

// MARK: - Example 9: Serializing to DICOM File

/// Save an SR document to a DICOM file
func example9_serializingToFile() throws {
    // Create SR document
    let document = try BasicTextSRBuilder()
        .withPatientID("12345678")
        .withPatientName("Doe^John^^^")
        .withDocumentTitle("Sample Report")
        
        .addSection("Content") { section in
            section.addText("This is a sample report for export.")
        }
        
        .build()
    
    // Serialize to DICOM file
    let dicomFile = try SRDocumentSerializer.serialize(document)
    
    // Write to disk
    let outputURL = URL(fileURLWithPath: "/path/to/output/sr_report.dcm")
    try dicomFile.write(to: outputURL)
    
    print("SR document saved to: \(outputURL.path)")
}

// MARK: - Quick Reference

/*
 CREATING SR DOCUMENTS QUICK REFERENCE
 =====================================
 
 1. BASIC TEXT SR BUILDER:
    let doc = try BasicTextSRBuilder()
        .withPatientID("12345")
        .withPatientName("Doe^John^^^")
        .withDocumentTitle("Report Title")
        .addSection("Section Name") { section in
            section.addText("Text content")
        }
        .build()
 
 2. ENHANCED SR BUILDER:
    let doc = try EnhancedSRBuilder()
        .withPatientID("12345")
        .addSection("Findings") { section in
            // Add coded observations
            section.addCodedObservation(
                concept: codedConcept,
                value: codedValue
            )
            
            // Add numeric measurements
            section.addNumericMeasurement(
                concept: measurementConcept,
                value: 42.5,
                unit: unitConcept
            )
        }
        .build()
 
 3. COMPREHENSIVE SR BUILDER:
    let doc = try ComprehensiveSRBuilder()
        .withProcedureReported(procedureConcept)
        .withObservationContext(
            observer: "Dr. Smith",
            observationDateTime: Date()
        )
        .addFinding(
            site: siteConcept,
            finding: findingConcept,
            description: "Details"
        )
        .build()
 
 4. REQUIRED PATIENT INFORMATION:
    .withPatientID("ID")
    .withPatientName("LastName^FirstName^^^")
    .withPatientBirthDate("YYYYMMDD")
    .withPatientSex("M" or "F" or "O")
 
 5. REQUIRED STUDY INFORMATION:
    .withStudyInstanceUID("UID")
    .withStudyDate("YYYYMMDD")
    .withStudyTime("HHMMSS")
    .withStudyDescription("Description")
    .withAccessionNumber("ACC12345")
 
 6. REQUIRED SERIES INFORMATION:
    .withSeriesInstanceUID("UID")
    .withSeriesNumber("1")
    .withModality("SR")
 
 7. DOCUMENT FLAGS:
    .withCompletionFlag(.partial)    // or .complete
    .withVerificationFlag(.unverified) // or .verified
 
 8. ADDING SECTIONS:
    .addSection("Section Title") { section in
        section.addText("Text content")
        section.addSection("Subsection") { sub in
            sub.addText("Nested content")
        }
    }
 
 9. ADDING CONTENT:
    // Text
    section.addText("Free text content")
    
    // Coded observation
    section.addCodedObservation(concept: c1, value: c2)
    
    // Numeric measurement
    section.addNumericMeasurement(
        concept: concept,
        value: 42.5,
        unit: unitConcept
    )
    
    // Image reference
    section.addImageReference(imageRef, description: "...")
    
    // Date/Time
    section.addDateTime(concept: concept, value: Date())
 
 10. CODED CONCEPTS:
     let concept = CodedConcept(
         codeValue: "12345",
         codingSchemeDesignator: .snomedCT,  // or .loinc, .dcm, etc.
         codeMeaning: "Human-readable meaning"
     )
 
 11. IMAGE REFERENCES:
     let imageRef = ImageReference(
         referencedSOPClassUID: "1.2.840...",
         referencedSOPInstanceUID: "1.2.840..."
     )
 
 12. OBSERVER/VERIFIER:
     .withObserver(
         name: "Smith^Jane^^^Dr.",
         organization: "Hospital"
     )
     
     .withVerifier(
         name: "Jones^Mark^^^Dr.",
         organization: "Hospital",
         verificationDateTime: Date()
     )
 
 13. SERIALIZATION:
     let dicomFile = try SRDocumentSerializer.serialize(document)
     try dicomFile.write(to: outputURL)
 
 14. DOCUMENT TYPES:
     .withDocumentType(.basicTextSR)
     .withDocumentType(.enhancedSR)
     .withDocumentType(.comprehensiveSR)
     .withDocumentType(.comprehensive3DSR)
     .withDocumentType(.procedureLog)
 
 15. COMMON CODING SCHEMES:
     .snomedCT    // SNOMED Clinical Terms
     .loinc       // Logical Observation Identifiers
     .dcm         // DICOM Controlled Terminology
     .ucum        // Unified Code for Units of Measure
     .cpt4        // Current Procedural Terminology
     .radlex      // Radiology Lexicon
 
 16. VALUE TYPES:
     - TEXT: Free-form text
     - CODE: Coded concepts
     - NUM: Numeric measurements
     - DATE, TIME, DATETIME: Temporal values
     - PNAME: Person names
     - UIDREF: UID references
     - IMAGE: Image references
     - CONTAINER: Section containers
 
 17. RELATIONSHIP TYPES:
     - CONTAINS: Parent contains child
     - HAS OBS CONTEXT: Observation context
     - HAS ACQ CONTEXT: Acquisition context
     - HAS CONCEPT MOD: Concept modifier
     - INFERRED FROM: Inference relationship
 
 18. BEST PRACTICES:
     ✓ Always set patient, study, and series information
     ✓ Use appropriate document type for content
     ✓ Set completion and verification flags
     ✓ Use standard coding schemes (SNOMED, LOINC)
     ✓ Provide meaningful section titles
     ✓ Include observer information
     ✓ Reference source images when applicable
     ✓ Use structured templates when available
     ✓ Validate document before serialization
     ✓ Include units with numeric measurements
 
 19. COMMON TEMPLATES:
     - TID 1500: Measurement Report
     - TID 1400: Key Object Selection
     - TID 1001: Observation Context
     - TID 300: Measurement
     - TID 1411: Volumetric ROI Measurements
 
 20. ERROR HANDLING:
     do {
         let doc = try builder.build()
         try SRDocumentSerializer.serialize(doc)
     } catch let error as SRBuildError {
         print("Build error: \(error)")
     } catch {
         print("Error: \(error)")
     }
 
 REFERENCE:
 - DICOM PS3.3 A.35: SR Document Content Module
 - DICOM PS3.16: Content Mapping Resource
 - SNOMED CT Browser: https://browser.ihtsdotools.org/
 - LOINC: https://loinc.org/
 */

// MARK: - Running the Examples
// Uncomment to run individual examples:
// try? example1_simpleRadiologyReport()
// try? example2_nestedSections()
// try? example3_codedObservations()
// try? example4_multiObserverReport()
// try? example5_comprehensiveSR()
// try? example6_procedureLog()
// try? example7_imageReferences()
// try? example8_numericMeasurements()
// try? example9_serializingToFile()
