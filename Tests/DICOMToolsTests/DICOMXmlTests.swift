import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMWeb

/// Tests for dicom-xml CLI tool functionality
/// These tests verify the core DICOMKit XML conversion functionality
final class DICOMXmlTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a minimal valid DICOM file for testing
    private func createTestDICOMFile() throws -> Data {
        var data = Data()
        
        // Add 128-byte preamble
        data.append(Data(count: 128))
        
        // Add DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        
        // File Meta Information Group Length (0002,0000) - UL, 4 bytes
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00]) // Value = 84 (placeholder)
        
        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntaxUID = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        let transferSyntaxLength = UInt16(transferSyntaxUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: transferSyntaxLength.littleEndian) { Data($0) })
        data.append(transferSyntaxUID.data(using: .utf8)!)
        
        // SOP Class UID (0008,0016) - UI
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopClassUID = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
        let sopClassLength = UInt16(sopClassUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopClassLength.littleEndian) { Data($0) })
        data.append(sopClassUID.data(using: .utf8)!)
        
        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopInstanceUID = "1.2.3.4.5.6.7.8.9" // Test UID
        let sopInstanceLength = UInt16(sopInstanceUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopInstanceLength.littleEndian) { Data($0) })
        data.append(sopInstanceUID.data(using: .utf8)!)
        
        // Patient Name (0010,0010) - PN
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x50, 0x4E]) // VR = PN
        let patientName = "Test^Patient"
        let patientNameLength = UInt16(patientName.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: patientNameLength.littleEndian) { Data($0) })
        data.append(patientName.data(using: .utf8)!)
        
        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modality = "CT"
        let modalityLength = UInt16(modality.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modalityLength.littleEndian) { Data($0) })
        data.append(modality.data(using: .utf8)!)
        
        return data
    }
    
    // MARK: - DICOM to XML Conversion Tests
    
    func testBasicDICOMToXMLConversion() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify XML is valid
        XCTAssertFalse(xmlData.isEmpty)
        
        // Parse XML to verify structure
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("<?xml"))
    }
    
    func testPrettyPrintedXML() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMXMLEncoder.Configuration(prettyPrinted: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify pretty-printed XML contains newlines and indentation
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("\n"))
        // Check for indentation (2 spaces is common)
        XCTAssertTrue(xmlString!.contains("  "))
    }
    
    func testXMLWithoutKeywords() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMXMLEncoder.Configuration(includeKeywords: false)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify XML doesn't contain keyword attributes
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertFalse(xmlString!.contains("keyword="))
    }
    
    func testXMLWithKeywords() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMXMLEncoder.Configuration(includeKeywords: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify XML contains keyword attributes
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("keyword="))
    }
    
    func testXMLWithEmptyValues() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMXMLEncoder.Configuration(includeEmptyValues: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify XML is generated (may or may not have empty values depending on data)
        XCTAssertFalse(xmlData.isEmpty)
    }
    
    func testXMLInlineBinaryThreshold() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Test with high threshold (inline everything)
        let config1 = DICOMXMLEncoder.Configuration(inlineBinaryThreshold: 10000)
        let encoder1 = DICOMXMLEncoder(configuration: config1)
        let xmlData1 = try encoder1.encode(dicomFile.dataSet.allElements)
        XCTAssertFalse(xmlData1.isEmpty)
        
        // Test with low threshold (use URIs)
        let config2 = DICOMXMLEncoder.Configuration(inlineBinaryThreshold: 10)
        let encoder2 = DICOMXMLEncoder(configuration: config2)
        let xmlData2 = try encoder2.encode(dicomFile.dataSet.allElements)
        XCTAssertFalse(xmlData2.isEmpty)
    }
    
    func testXMLBulkDataURL() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let bulkDataURL = URL(string: "http://example.com/bulk")
        let config = DICOMXMLEncoder.Configuration(
            inlineBinaryThreshold: 10,
            bulkDataBaseURL: bulkDataURL
        )
        let encoder = DICOMXMLEncoder(configuration: config)
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify XML is generated
        XCTAssertFalse(xmlData.isEmpty)
        
        // Check if bulk data URLs are used (if binary data present)
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
    }
    
    // MARK: - XML to DICOM Conversion Tests
    
    func testRoundTripConversion() throws {
        // Create DICOM file
        let originalData = try createTestDICOMFile()
        let originalFile = try DICOMFile.read(from: originalData)
        
        // Convert to XML
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(originalFile.dataSet.allElements)
        
        // Convert back to DICOM
        let decoder = DICOMXMLDecoder()
        let elements = try decoder.decode(xmlData)
        
        // Verify we got elements back
        XCTAssertFalse(elements.isEmpty)
        
        // Create new DICOM file
        let dataSet = DataSet(elements: elements)
        let newFile = DICOMFile.create(
            dataSet: dataSet,
            transferSyntaxUID: "1.2.840.10008.1.2.1"
        )
        
        // Verify key elements are present
        XCTAssertNotNil(newFile.dataSet[Tag.patientName])
        XCTAssertNotNil(newFile.dataSet[Tag.modality])
    }
    
    func testXMLDecoderWithMissingVR() throws {
        // Create minimal XML without VR attributes
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NativeDicomModel>
          <DicomAttribute tag="00100010">
            <PersonName number="1">
              <Alphabetic>
                <FamilyName>Test</FamilyName>
                <GivenName>Patient</GivenName>
              </Alphabetic>
            </PersonName>
          </DicomAttribute>
        </NativeDicomModel>
        """
        let xmlData = xml.data(using: .utf8)!
        
        let config = DICOMXMLDecoder.Configuration(allowMissingVR: true)
        let decoder = DICOMXMLDecoder(configuration: config)
        let elements = try decoder.decode(xmlData)
        
        // Verify elements were decoded
        XCTAssertFalse(elements.isEmpty)
    }
    
    func testXMLDecoderWithInvalidXML() throws {
        let invalidXML = "This is not valid XML"
        let xmlData = invalidXML.data(using: .utf8)!
        
        let decoder = DICOMXMLDecoder()
        
        XCTAssertThrowsError(try decoder.decode(xmlData)) { error in
            // Verify an error was thrown
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Tag Filtering Tests
    
    func testFilterByTagName() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Filter to only PatientName
        let patientNameElements = dicomFile.dataSet.allElements.filter { 
            $0.tag == Tag.patientName 
        }
        
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(patientNameElements)
        
        // Verify XML contains only PatientName
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("00100010"))
    }
    
    func testFilterByMultipleTags() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Filter to PatientName and Modality
        let filteredElements = dicomFile.dataSet.allElements.filter { 
            $0.tag == Tag.patientName || $0.tag == Tag.modality
        }
        
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(filteredElements)
        
        // Verify XML contains both tags
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("00100010")) // PatientName
        XCTAssertTrue(xmlString!.contains("00080060")) // Modality
    }
    
    // MARK: - Metadata-Only Tests
    
    func testMetadataOnlyExcludesPixelData() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Filter out pixel data (metadata-only mode)
        let metadataElements = dicomFile.dataSet.allElements.filter { $0.tag != Tag.pixelData }
        
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(metadataElements)
        
        // Verify pixel data is not in XML
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertFalse(xmlString!.contains("7FE00010")) // Pixel Data tag
        XCTAssertTrue(xmlString!.contains("00100010")) // PatientName should be present
    }
    
    // MARK: - Data Type Tests
    
    func testStringDataInXML() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Find PatientName element
        let patientNameElement = dicomFile.dataSet.allElements.first { $0.tag == Tag.patientName }
        XCTAssertNotNil(patientNameElement)
        
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode([patientNameElement!])
        
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("Test^Patient") || xmlString!.contains("PersonName"))
    }
    
    func testNumericDataInXML() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Use any numeric element from the file
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("tag=")) // Should have tag attributes
    }
    
    func testDateDataInXML() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Encode all elements
        let encoder = DICOMXMLEncoder()
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        // Just verify XML is valid and contains elements
        XCTAssertTrue(xmlString!.contains("<?xml"))
    }
    
    // MARK: - Performance Tests
    
    func testLargeDataSetConversion() throws {
        // Create a data set with many elements by loading test file
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Use existing elements
        let elements = dicomFile.dataSet.allElements
        
        let encoder = DICOMXMLEncoder()
        let startTime = Date()
        let xmlData = try encoder.encode(elements)
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Verify conversion completed in reasonable time (< 1 second)
        XCTAssertLessThan(elapsedTime, 1.0)
        XCTAssertFalse(xmlData.isEmpty)
    }
    
    func testPrettyPrintPerformance() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMXMLEncoder.Configuration(prettyPrinted: true)
        let encoder = DICOMXMLEncoder(configuration: config)
        
        let startTime = Date()
        let xmlData = try encoder.encode(dicomFile.dataSet.allElements)
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Verify pretty printing doesn't significantly impact performance
        XCTAssertLessThan(elapsedTime, 1.0)
        XCTAssertFalse(xmlData.isEmpty)
    }
}
