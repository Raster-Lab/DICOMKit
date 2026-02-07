import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-pdf CLI tool functionality
/// These tests verify the core DICOMKit Encapsulated Document functionality
final class DICOMPdfTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a simple PDF file for testing (minimal PDF structure)
    private func createTestPDFFile() -> Data {
        // Minimal valid PDF
        var data = Data()
        data.append("%PDF-1.4\n".data(using: .utf8)!)
        data.append("1 0 obj\n".data(using: .utf8)!)
        data.append("<< /Type /Catalog /Pages 2 0 R >>\n".data(using: .utf8)!)
        data.append("endobj\n".data(using: .utf8)!)
        data.append("2 0 obj\n".data(using: .utf8)!)
        data.append("<< /Type /Pages /Kids [] /Count 0 >>\n".data(using: .utf8)!)
        data.append("endobj\n".data(using: .utf8)!)
        data.append("xref\n".data(using: .utf8)!)
        data.append("0 3\n".data(using: .utf8)!)
        data.append("0000000000 65535 f\n".data(using: .utf8)!)
        data.append("0000000009 00000 n\n".data(using: .utf8)!)
        data.append("0000000058 00000 n\n".data(using: .utf8)!)
        data.append("trailer\n".data(using: .utf8)!)
        data.append("<< /Size 3 /Root 1 0 R >>\n".data(using: .utf8)!)
        data.append("startxref\n".data(using: .utf8)!)
        data.append("117\n".data(using: .utf8)!)
        data.append("%%EOF\n".data(using: .utf8)!)
        return data
    }
    
    /// Creates a simple CDA XML document for testing
    private func createTestCDAFile() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <realmCode code="US"/>
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
            <id root="1.2.3.4.5"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Test Clinical Document</title>
        </ClinicalDocument>
        """
        return xml.data(using: .utf8)!
    }
    
    /// Creates a simple STL file for testing (ASCII format)
    private func createTestSTLFile() -> Data {
        let stl = """
        solid test
          facet normal 0 0 1
            outer loop
              vertex 0 0 0
              vertex 1 0 0
              vertex 0 1 0
            endloop
          endfacet
        endsolid test
        """
        return stl.data(using: .utf8)!
    }
    
    /// Creates an encapsulated PDF DICOM file for testing
    private func createEncapsulatedPDFFile() throws -> Data {
        let pdfData = createTestPDFFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        .setDocumentTitle("Test PDF Report")
        .setModality("DOC")
        .setSeriesDescription("Test Reports")
        .setSeriesNumber(1)
        .setInstanceNumber(1)
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        )
        
        return try dicomFile.write()
    }
    
    /// Creates an encapsulated CDA DICOM file for testing
    private func createEncapsulatedCDAFile() throws -> Data {
        let cdaData = createTestCDAFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: cdaData,
            mimeType: "text/xml",
            documentType: .cda,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.7"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        .setDocumentTitle("Test CDA Document")
        .setModality("DOC")
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        
        return try dicomFile.write()
    }
    
    /// Creates an encapsulated STL DICOM file for testing
    private func createEncapsulatedSTLFile() throws -> Data {
        let stlData = createTestSTLFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: stlData,
            mimeType: "application/sla",
            documentType: .stl,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.8"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        .setDocumentTitle("Test 3D Model")
        .setModality("M3D")
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        
        return try dicomFile.write()
    }
    
    // MARK: - PDF Extraction Tests
    
    func testExtractPDFFromDICOM() throws {
        let dicomData = try createEncapsulatedPDFFile()
        let dicomFile = try DICOMFile.read(from: dicomData)
        
        // Parse encapsulated document
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Verify document type
        XCTAssertEqual(document.documentType, .pdf)
        XCTAssertTrue(document.isPDF)
        XCTAssertEqual(document.mimeType, "application/pdf")
        
        // Verify document data
        XCTAssertFalse(document.documentData.isEmpty)
        
        // Verify metadata
        XCTAssertEqual(document.patientName, "Test^Patient")
        XCTAssertEqual(document.patientID, "12345")
        XCTAssertEqual(document.documentTitle, "Test PDF Report")
        XCTAssertEqual(document.modality, "DOC")
    }
    
    func testExtractedPDFIsValid() throws {
        let dicomData = try createEncapsulatedPDFFile()
        let dicomFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Verify PDF starts with correct header
        let pdfHeader = String(data: document.documentData.prefix(8), encoding: .utf8)
        XCTAssertEqual(pdfHeader, "%PDF-1.4")
    }
    
    // MARK: - CDA Extraction Tests
    
    func testExtractCDAFromDICOM() throws {
        let dicomData = try createEncapsulatedCDAFile()
        let dicomFile = try DICOMFile.read(from: dicomData)
        
        // Parse encapsulated document
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Verify document type
        XCTAssertEqual(document.documentType, .cda)
        XCTAssertTrue(document.isCDA)
        XCTAssertEqual(document.mimeType, "text/xml")
        
        // Verify document data
        XCTAssertFalse(document.documentData.isEmpty)
        
        // Verify metadata
        XCTAssertEqual(document.patientName, "Test^Patient")
        XCTAssertEqual(document.patientID, "12345")
        XCTAssertEqual(document.documentTitle, "Test CDA Document")
    }
    
    func testExtractedCDAIsValidXML() throws {
        let dicomData = try createEncapsulatedCDAFile()
        let dicomFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Verify XML starts with correct declaration
        let xmlString = String(data: document.documentData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("<?xml version"))
        XCTAssertTrue(xmlString!.contains("ClinicalDocument"))
    }
    
    // MARK: - 3D Model Extraction Tests
    
    func testExtractSTLFromDICOM() throws {
        let dicomData = try createEncapsulatedSTLFile()
        let dicomFile = try DICOMFile.read(from: dicomData)
        
        // Parse encapsulated document
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Verify document type
        XCTAssertEqual(document.documentType, .stl)
        XCTAssertEqual(document.mimeType, "application/sla")
        XCTAssertEqual(document.modality, "M3D")
        
        // Verify document data
        XCTAssertFalse(document.documentData.isEmpty)
    }
    
    func testExtractedSTLIsValid() throws {
        let dicomData = try createEncapsulatedSTLFile()
        let dicomFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Verify STL starts with "solid" keyword (ASCII STL)
        let stlString = String(data: document.documentData, encoding: .utf8)
        XCTAssertNotNil(stlString)
        XCTAssertTrue(stlString!.hasPrefix("solid"))
    }
    
    // MARK: - PDF Encapsulation Tests
    
    func testEncapsulatePDFToDICOM() throws {
        let pdfData = createTestPDFFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Smith^John")
        .setPatientID("54321")
        .setDocumentTitle("Test Encapsulation")
        .setModality("DOC")
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        
        let dicomData = try dicomFile.write()
        XCTAssertFalse(dicomData.isEmpty)
        
        // Verify we can read it back
        let readFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: readFile.dataSet)
        
        XCTAssertEqual(document.documentType, .pdf)
        XCTAssertEqual(document.patientName, "Smith^John")
        XCTAssertEqual(document.patientID, "54321")
        XCTAssertEqual(document.documentTitle, "Test Encapsulation")
    }
    
    func testEncapsulateCDAToDICOM() throws {
        let cdaData = createTestCDAFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: cdaData,
            mimeType: "text/xml",
            documentType: .cda,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Doe^Jane")
        .setPatientID("11111")
        .setDocumentTitle("Test CDA Encapsulation")
        .setModality("DOC")
        
        let dataSet = try builder.buildDataSet()
        XCTAssertNotNil(dataSet[.encapsulatedDocument])
        XCTAssertEqual(dataSet.string(for: .patientName), "Doe^Jane")
        XCTAssertEqual(dataSet.string(for: .patientID), "11111")
    }
    
    func testEncapsulateSTLToDICOM() throws {
        let stlData = createTestSTLFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: stlData,
            mimeType: "application/sla",
            documentType: .stl,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Model")
        .setPatientID("99999")
        .setDocumentTitle("Test 3D Model")
        .setModality("M3D")
        
        let dataSet = try builder.buildDataSet()
        XCTAssertNotNil(dataSet[.encapsulatedDocument])
        XCTAssertEqual(dataSet.string(for: .modality), "M3D")
    }
    
    // MARK: - Round-trip Tests
    
    func testPDFRoundTrip() throws {
        let originalPDF = createTestPDFFile()
        
        // Encapsulate
        let builder = EncapsulatedDocumentBuilder(
            documentData: originalPDF,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        let dicomData = try dicomFile.write()
        
        // Extract
        let readFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: readFile.dataSet)
        
        // Verify data is identical
        XCTAssertEqual(document.documentData, originalPDF)
        XCTAssertEqual(document.documentType, .pdf)
    }
    
    func testCDARoundTrip() throws {
        let originalCDA = createTestCDAFile()
        
        // Encapsulate
        let builder = EncapsulatedDocumentBuilder(
            documentData: originalCDA,
            mimeType: "text/xml",
            documentType: .cda,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        let dicomData = try dicomFile.write()
        
        // Extract
        let readFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: readFile.dataSet)
        
        // Verify data is identical
        XCTAssertEqual(document.documentData, originalCDA)
        XCTAssertEqual(document.documentType, .cda)
    }
    
    func testSTLRoundTrip() throws {
        let originalSTL = createTestSTLFile()
        
        // Encapsulate
        let builder = EncapsulatedDocumentBuilder(
            documentData: originalSTL,
            mimeType: "application/sla",
            documentType: .stl,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        
        let dataSet = try builder.buildDataSet()
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        let dicomData = try dicomFile.write()
        
        // Extract
        let readFile = try DICOMFile.read(from: dicomData)
        let document = try EncapsulatedDocumentParser.parse(from: readFile.dataSet)
        
        // Verify data is identical
        XCTAssertEqual(document.documentData, originalSTL)
        XCTAssertEqual(document.documentType, .stl)
    }
    
    // MARK: - Metadata Tests
    
    func testEncapsulationWithAllMetadata() throws {
        let pdfData = createTestPDFFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Complete^Test")
        .setPatientID("99999")
        .setDocumentTitle("Complete Metadata Test")
        .setModality("DOC")
        .setSeriesDescription("Test Series")
        .setSeriesNumber(5)
        .setInstanceNumber(10)
        
        let dataSet = try builder.buildDataSet()
        let document = try EncapsulatedDocumentParser.parse(from: dataSet)
        
        // Verify all metadata
        XCTAssertEqual(document.patientName, "Complete^Test")
        XCTAssertEqual(document.patientID, "99999")
        XCTAssertEqual(document.documentTitle, "Complete Metadata Test")
        XCTAssertEqual(document.modality, "DOC")
        XCTAssertEqual(document.seriesDescription, "Test Series")
        XCTAssertEqual(document.seriesNumber, 5)
        XCTAssertEqual(document.instanceNumber, 10)
    }
    
    // MARK: - Document Size Tests
    
    func testDocumentSizeProperty() throws {
        let pdfData = createTestPDFFile()
        
        let builder = EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("12345")
        
        let dataSet = try builder.buildDataSet()
        let document = try EncapsulatedDocumentParser.parse(from: dataSet)
        
        XCTAssertEqual(document.documentSize, pdfData.count)
        XCTAssertGreaterThan(document.documentSize, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testParseNonEncapsulatedDocumentFails() throws {
        // Create a regular DICOM file without encapsulated document
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI) // CT Image Storage (not encapsulated doc)
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        
        // Should fail because there's no encapsulated document
        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }
    
    func testMissingRequiredFieldsFails() throws {
        var dataSet = DataSet()
        // Missing SOP Instance UID
        dataSet.setString("1.2.840.10008.5.1.4.1.1.104.1", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        
        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }
}
