/// Basic Text SR Example
///
/// This example demonstrates how to create a simple DICOM Basic Text SR document
/// for a radiology report. Basic Text SR is ideal for narrative text reports
/// with minimal structured coding requirements.
///
/// Basic Text SR supports:
/// - TEXT: Free-form text content
/// - CODE: Coded concept values
/// - DATETIME, DATE, TIME: Temporal values
/// - CONTAINER: Hierarchical sections
///
/// Use cases:
/// - Simple radiology reports
/// - Clinical notes
/// - Discharge summaries
/// - Consultation reports

import Foundation
import DICOMKit
import DICOMCore

func createBasicTextSRExample() throws -> SRDocument {
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
        .withReferringPhysicianName("Smith^Jane^^^Dr.")
        
        // Series Information
        .withSeriesInstanceUID("1.2.840.113619.2.55.3.123456789.101")
        .withSeriesNumber("1")
        .withModality("SR")
        .withSeriesDescription("Radiology Report")
        
        // Document Information
        .withDocumentTitle("Radiology Report")
        .withCompletionFlag(.complete)
        .withVerificationFlag(.verified)
        
        // Report Sections
        .addSection("Clinical History") { section in
            section.addText("Patient presents with cough and fever for 3 days. " +
                          "No known history of tuberculosis or lung disease.")
        }
        
        .addSection("Technique") { section in
            section.addText("PA and lateral chest radiographs obtained.")
        }
        
        .addSection("Findings") { section in
            section.addText("The lungs are clear bilaterally. ")
            section.addText("No evidence of consolidation, pleural effusion, or pneumothorax. ")
            section.addText("The cardiac silhouette is normal in size. ")
            section.addText("The mediastinal contours are unremarkable.")
        }
        
        .addSection("Impression") { section in
            section.addText("Normal chest radiograph.")
        }
        
        .build()
    
    return document
}

/// Example with nested sections for more complex reports
func createNestedSectionExample() throws -> SRDocument {
    let document = try BasicTextSRBuilder()
        .withPatientID("87654321")
        .withPatientName("Smith^Alice^^^")
        .withDocumentTitle("CT Abdomen Report")
        
        .addSection("Findings") { section in
            // Add subsections with indented structure
            section.addText("Multiple organs evaluated:")
            
            section.addSection("Liver") { liverSection in
                liverSection.addText("Normal size and attenuation. No focal lesions.")
            }
            
            section.addSection("Spleen") { spleenSection in
                spleenSection.addText("Normal size. No focal lesions.")
            }
            
            section.addSection("Pancreas") { pancreasSection in
                pancreasSection.addText("Normal appearance. No masses or ductal dilatation.")
            }
        }
        
        .addSection("Impression") { section in
            section.addText("No acute abdominal findings.")
        }
        
        .build()
    
    return document
}

/// Example showing how to save the SR document to file
func saveBasicTextSRExample() throws {
    // Create the SR document
    let document = try createBasicTextSRExample()
    
    // Convert to DICOM data set
    let dataSet = try SRDocumentSerializer.serialize(document)
    
    // Write to file (requires DICOMWriter from Milestone 5)
    let writer = DICOMWriter()
    let fileData = try writer.write(dataSet: dataSet, transferSyntax: .explicitVRLittleEndian)
    
    // Save to disk
    let fileURL = URL(fileURLWithPath: "/tmp/basic_text_sr_report.dcm")
    try fileData.write(to: fileURL)
    
    print("Basic Text SR saved to: \(fileURL.path)")
}

/// Example showing how to read and parse a Basic Text SR document
func readBasicTextSRExample() throws -> SRDocument {
    // Read DICOM file
    let fileURL = URL(fileURLWithPath: "/tmp/basic_text_sr_report.dcm")
    let fileData = try Data(contentsOf: fileURL)
    
    // Parse DICOM data set (requires DICOMReader from Milestone 1)
    let reader = DICOMReader()
    let dataSet = try reader.read(data: fileData)
    
    // Parse SR document
    let parser = SRDocumentParser()
    let document = try parser.parse(dataSet: dataSet)
    
    print("Parsed SR document: \(document.documentTitle ?? "Untitled")")
    print("Content tree has \(document.content.count) root items")
    
    return document
}

// MARK: - Usage Examples

/*
 To use these examples in your application:
 
 1. Create a Basic Text SR:
 
    do {
        let report = try createBasicTextSRExample()
        print("Created report: \(report.documentTitle ?? "Untitled")")
    } catch {
        print("Error creating SR: \(error)")
    }
 
 2. Save to file:
 
    do {
        try saveBasicTextSRExample()
    } catch {
        print("Error saving SR: \(error)")
    }
 
 3. Read from file:
 
    do {
        let document = try readBasicTextSRExample()
        // Access document content
        for item in document.content {
            if let textItem = item as? TextContentItem {
                print("Text: \(textItem.textValue)")
            } else if let container = item as? ContainerContentItem {
                print("Section: \(container.conceptName?.codeMeaning ?? "Unknown")")
            }
        }
    } catch {
        print("Error reading SR: \(error)")
    }
 
 4. Query for specific sections:
 
    let document = try createBasicTextSRExample()
    let navigator = ContentTreeNavigator(document: document)
    
    // Find all text in "Findings" section
    if let findings = navigator.findByConceptName(codeMeaning: "Findings").first as? ContainerContentItem {
        for child in findings.children {
            if let textItem = child as? TextContentItem {
                print("Finding: \(textItem.textValue)")
            }
        }
    }
 */
