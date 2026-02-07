import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMWeb

/// Tests for dicom-json CLI tool functionality
/// These tests verify the core DICOMKit JSON conversion functionality
final class DICOMJsonTests: XCTestCase {
    
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
    
    // MARK: - DICOM to JSON Conversion Tests
    
    func testBasicDICOMToJSONConversion() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let encoder = DICOMJSONEncoder()
        let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify JSON is valid
        XCTAssertFalse(jsonData.isEmpty)
        
        // Parse JSON to verify structure
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(jsonObject as? [String: Any])
    }
    
    func testPrettyPrintedJSON() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMJSONEncoder.Configuration(prettyPrinted: true)
        let encoder = DICOMJSONEncoder(configuration: config)
        let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify pretty-printed JSON contains newlines
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\n"))
    }
    
    func testSortedKeysJSON() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMJSONEncoder.Configuration(sortedKeys: true)
        let encoder = DICOMJSONEncoder(configuration: config)
        let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify JSON is valid
        XCTAssertFalse(jsonData.isEmpty)
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
    }
    
    func testIncludeEmptyValues() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let configWithEmpty = DICOMJSONEncoder.Configuration(includeEmptyValues: true)
        let encoderWithEmpty = DICOMJSONEncoder(configuration: configWithEmpty)
        let jsonWithEmpty = try encoderWithEmpty.encode(dicomFile.dataSet.allElements)
        
        let configWithoutEmpty = DICOMJSONEncoder.Configuration(includeEmptyValues: false)
        let encoderWithoutEmpty = DICOMJSONEncoder(configuration: configWithoutEmpty)
        let jsonWithoutEmpty = try encoderWithoutEmpty.encode(dicomFile.dataSet.allElements)
        
        // JSON with empty values should be >= JSON without empty values
        XCTAssertGreaterThanOrEqual(jsonWithEmpty.count, jsonWithoutEmpty.count)
    }
    
    // MARK: - JSON to DICOM Conversion Tests
    
    func testBasicJSONToDICOMConversion() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Convert to JSON
        let encoder = DICOMJSONEncoder()
        let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Convert back to DICOM
        let decoder = DICOMJSONDecoder()
        let elements = try decoder.decode(jsonData)
        
        // Verify elements were decoded
        XCTAssertFalse(elements.isEmpty)
        XCTAssertGreaterThan(elements.count, 0)
    }
    
    func testRoundTripConversion() throws {
        let testData = try createTestDICOMFile()
        let originalFile = try DICOMFile.read(from: testData)
        
        // Convert to JSON
        let encoder = DICOMJSONEncoder()
        let jsonData = try encoder.encode(originalFile.dataSet.allElements)
        
        // Convert back to DICOM
        let decoder = DICOMJSONDecoder(configuration: .init(allowMissingVR: true))
        let restoredElements = try decoder.decode(jsonData)
        
        // Verify key tags are preserved
        let originalPatientName = originalFile.dataSet.string(for: Tag.patientName)
        let restoredDataSet = DataSet(elements: restoredElements)
        let restoredPatientName = restoredDataSet.string(for: Tag.patientName)
        
        XCTAssertEqual(originalPatientName, restoredPatientName)
    }
    
    func testJSONWithMissingVR() throws {
        // Create JSON without VR fields
        let jsonString = """
        {
            "00100010": {
                "Value": [{"Alphabetic": "Test^Patient"}]
            },
            "00080060": {
                "Value": ["CT"]
            }
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        // Try decoding with allowMissingVR
        let config = DICOMJSONDecoder.Configuration(allowMissingVR: true)
        let decoder = DICOMJSONDecoder(configuration: config)
        let elements = try decoder.decode(jsonData)
        
        // Verify elements were decoded despite missing VR
        XCTAssertFalse(elements.isEmpty)
    }
    
    // MARK: - Bulk Data Handling Tests
    
    func testInlineBinaryEncoding() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let config = DICOMJSONEncoder.Configuration(inlineBinaryThreshold: 1024)
        let encoder = DICOMJSONEncoder(configuration: config)
        let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify JSON is valid
        XCTAssertFalse(jsonData.isEmpty)
    }
    
    func testBulkDataURIEncoding() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let bulkDataURL = URL(string: "http://example.com/bulk")!
        let config = DICOMJSONEncoder.Configuration(
            inlineBinaryThreshold: 0, // Always use URIs
            bulkDataBaseURL: bulkDataURL
        )
        let encoder = DICOMJSONEncoder(configuration: config)
        let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
        
        // Verify JSON is valid
        XCTAssertFalse(jsonData.isEmpty)
    }
    
    // MARK: - Metadata Filtering Tests
    
    func testFilteredElementConversion() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Filter to only patient name and modality
        let filteredElements = dicomFile.dataSet.allElements.filter {
            $0.tag == Tag.patientName || $0.tag == Tag.modality
        }
        
        let encoder = DICOMJSONEncoder()
        let jsonData = try encoder.encode(filteredElements)
        
        // Verify JSON contains only filtered elements
        XCTAssertFalse(jsonData.isEmpty)
        let decoder = DICOMJSONDecoder()
        let decodedElements = try decoder.decode(jsonData)
        XCTAssertEqual(decodedElements.count, filteredElements.count)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidJSONDecoding() throws {
        let invalidJSON = "{ invalid json }"
        let jsonData = invalidJSON.data(using: .utf8)!
        
        let decoder = DICOMJSONDecoder()
        XCTAssertThrowsError(try decoder.decode(jsonData))
    }
    
    func testEmptyJSONDecoding() throws {
        let emptyJSON = "{}"
        let jsonData = emptyJSON.data(using: .utf8)!
        
        let decoder = DICOMJSONDecoder()
        let elements = try decoder.decode(jsonData)
        
        // Empty JSON should result in no elements
        XCTAssertTrue(elements.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileConversionPerformance() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        measure {
            do {
                let encoder = DICOMJSONEncoder()
                _ = try encoder.encode(dicomFile.dataSet.allElements)
            } catch {
                XCTFail("Encoding failed: \(error)")
            }
        }
    }
    
    func testRoundTripPerformance() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        measure {
            do {
                let encoder = DICOMJSONEncoder()
                let jsonData = try encoder.encode(dicomFile.dataSet.allElements)
                
                let decoder = DICOMJSONDecoder()
                _ = try decoder.decode(jsonData)
            } catch {
                XCTFail("Round-trip failed: \(error)")
            }
        }
    }
}
