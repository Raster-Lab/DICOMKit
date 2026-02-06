import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for CLI tool functionality
/// These tests verify the core DICOMKit functionality used by the CLI tools
final class DICOMInfoTests: XCTestCase {
    
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
    
    // MARK: - Basic Parsing Tests
    
    func testDICOMFileParsing() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify file was parsed
        XCTAssertNotNil(dicomFile)
        
        // Verify transfer syntax
        let transferSyntax = dicomFile.fileMetaInformation.string(for: .transferSyntaxUID)
        XCTAssertEqual(transferSyntax, "1.2.840.10008.1.2.1")
    }
    
    func testDataSetTagAccess() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify patient name
        let patientName = dicomFile.dataSet.string(for: .patientName)
        XCTAssertEqual(patientName, "Test^Patient")
        
        // Verify modality
        let modality = dicomFile.dataSet.string(for: .modality)
        XCTAssertEqual(modality, "CT")
        
        // Verify SOP Class UID
        let sopClass = dicomFile.dataSet.string(for: .sopClassUID)
        XCTAssertEqual(sopClass, "1.2.840.10008.5.1.4.1.1.2")
    }
    
    func testTagEnumeration() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Get all tags from main data set
        let tags = dicomFile.dataSet.tags
        
        // Should have at least the tags we added
        XCTAssertGreaterThan(tags.count, 0)
        
        // Verify specific tags exist
        XCTAssertTrue(tags.contains(.patientName))
        XCTAssertTrue(tags.contains(.modality))
    }
    
    // MARK: - Data Element Dictionary Tests
    
    func testDataElementDictionaryLookup() {
        // Test known tags
        let patientNameEntry = DataElementDictionary.lookup(tag: .patientName)
        XCTAssertNotNil(patientNameEntry)
        XCTAssertEqual(patientNameEntry?.name, "Patient's Name")
        
        let modalityEntry = DataElementDictionary.lookup(tag: .modality)
        XCTAssertNotNil(modalityEntry)
        XCTAssertEqual(modalityEntry?.name, "Modality")
    }
    
    func testUnknownTagLookup() {
        // Test unknown/private tag
        let unknownTag = Tag(group: 0x7FE1, element: 0x1234)
        let entry = DataElementDictionary.lookup(tag: unknownTag)
        XCTAssertNil(entry)
    }
    
    // MARK: - Value Formatting Tests
    
    func testStringValueFormatting() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Get an element
        guard let element = dicomFile.dataSet[.patientName] else {
            XCTFail("Patient Name element not found")
            return
        }
        
        // Verify we can get string value
        XCTAssertNotNil(element.stringValue)
        XCTAssertEqual(element.stringValue, "Test^Patient")
    }
    
    func testBinaryDataFormatting() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Create a mock binary element by checking length
        for tag in dicomFile.dataSet.tags {
            guard let element = dicomFile.dataSet[tag] else { continue }
            
            // Check if element has length property
            XCTAssertGreaterThanOrEqual(element.length, 0)
            
            // If it's a string type, should have string value
            if element.vr == .PN || element.vr == .CS || element.vr == .UI {
                XCTAssertNotNil(element.stringValue)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyFile() {
        let emptyData = Data()
        
        // Should throw error for empty file
        XCTAssertThrowsError(try DICOMFile.read(from: emptyData)) { error in
            // Verify it's a DICOM error
            XCTAssertTrue(error is DICOMError)
        }
    }
    
    func testInvalidDICMPrefix() {
        var invalidData = Data(count: 128)
        invalidData.append(contentsOf: [0x44, 0x49, 0x43, 0x4E]) // "DICN" instead of "DICM"
        
        // Should throw error for invalid prefix
        XCTAssertThrowsError(try DICOMFile.read(from: invalidData)) { error in
            XCTAssertTrue(error is DICOMError)
        }
    }
    
    func testForceParsingFlag() throws {
        // Create data without DICM prefix (legacy format)
        var legacyData = Data()
        
        // Add a simple data element without preamble/prefix
        // This simulates a legacy DICOM file
        legacyData.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Modality tag
        
        // Without force flag, should fail
        XCTAssertThrowsError(try DICOMFile.read(from: legacyData, force: false))
        
        // With force flag, might succeed or fail depending on data validity
        // For this test, we just verify the force parameter is accepted
        do {
            _ = try DICOMFile.read(from: legacyData, force: true)
            // If it succeeds, that's fine
        } catch {
            // If it fails, that's also expected for invalid data
            XCTAssertTrue(error is DICOMError)
        }
    }
}
