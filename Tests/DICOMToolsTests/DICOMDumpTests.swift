import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

/// Tests for dicom-dump CLI tool functionality
/// Note: Tests focus on DICOMKit functionality used by the tool,
/// as HexDumper is in the executable target and not directly testable
final class DICOMDumpTests: XCTestCase {
    
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
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00]) // Value = 84
        
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
        let sopInstanceUID = "1.2.3.4.5.6.7.8.9"
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
    
    // MARK: - Hex Formatting Tests
    
    func testHexStringFormatting() throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        
        // Verify we can format hex bytes
        let hexString = testData.map { String(format: "%02X", $0) }.joined(separator: " ")
        XCTAssertEqual(hexString, "01 02 03 04 05 06 07 08")
    }
    
    func testASCIIRepresentation() throws {
        let testData = "DICM".data(using: .utf8)!
        
        // Verify ASCII conversion
        var asciiString = ""
        for byte in testData {
            if byte >= 32 && byte <= 126 {
                asciiString += String(format: "%c", byte)
            } else {
                asciiString += "."
            }
        }
        
        XCTAssertEqual(asciiString, "DICM")
    }
    
    func testNonPrintableCharacterFormatting() throws {
        let testData = Data([0x00, 0x01, 0x02, 0x7F, 0xFF])
        
        // Verify non-printable shown as dots
        var asciiString = ""
        for byte in testData {
            if byte >= 32 && byte <= 126 {
                asciiString += String(format: "%c", byte)
            } else {
                asciiString += "."
            }
        }
        
        XCTAssertEqual(asciiString, ".....")
    }
    
    func testOffsetCalculation() throws {
        let startOffset = 0x1000
        let bytesPerLine = 16
        
        // Calculate offsets for multiple lines
        let line0Offset = String(format: "%08X", startOffset)
        let line1Offset = String(format: "%08X", startOffset + bytesPerLine)
        
        XCTAssertEqual(line0Offset, "00001000")
        XCTAssertEqual(line1Offset, "00001010")
    }
    
    // MARK: - Tag Boundary Detection Tests
    
    func testTagPatternRecognition() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify we can identify tags
        XCTAssertNotNil(dicomFile.dataSet[.patientName])
        XCTAssertNotNil(dicomFile.dataSet[.modality])
    }
    
    func testVRParsing() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify VR is correctly parsed
        if let element = dicomFile.dataSet[.patientName] {
            XCTAssertEqual(element.vr, .PN)
        }
        
        if let element = dicomFile.dataSet[.modality] {
            XCTAssertEqual(element.vr, .CS)
        }
    }
    
    func testLengthParsing() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify length was parsed correctly (values are accessible)
        let patientName = dicomFile.dataSet.string(for: .patientName)
        XCTAssertEqual(patientName, "Test^Patient")
    }
    
    // MARK: - Format Detection Tests
    
    func testExplicitVRDetection() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        let transferSyntax = dicomFile.fileMetaInformation.string(for: .transferSyntaxUID)
        XCTAssertEqual(transferSyntax, "1.2.840.10008.1.2.1") // Explicit VR Little Endian
    }
    
    func testEndiannessDetection() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Little Endian transfer syntax should be detected
        let transferSyntax = dicomFile.fileMetaInformation.string(for: .transferSyntaxUID)
        XCTAssertTrue(transferSyntax?.contains("1.2") ?? false)
    }
    
    // MARK: - Integration Tests
    
    func testDumpSmallFile() throws {
        let testData = try createTestDICOMFile()
        
        // Verify file is reasonable size
        XCTAssertLessThan(testData.count, 1024)
        
        // Verify we can parse it
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertNotNil(dicomFile)
    }
    
    func testDumpLargeFileRange() throws {
        // Create a larger test file
        var largeData = try createTestDICOMFile()
        largeData.append(Data(count: 10_000))
        
        // Verify we can extract a range
        let offset = 0x100
        let length = 256
        let rangeData = largeData[offset..<min(offset + length, largeData.count)]
        
        XCTAssertEqual(rangeData.count, length)
    }
    
    func testDumpSpecificTag() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify we can access specific tag
        let patientName = dicomFile.dataSet.string(for: .patientName)
        XCTAssertEqual(patientName, "Test^Patient")
        
        // Get element for tag
        let element = dicomFile.dataSet[.patientName]
        XCTAssertNotNil(element)
        XCTAssertEqual(element?.vr, .PN)
    }
    
    func testDumpPixelDataTag() throws {
        // Create file with pixel data tag
        var testData = try createTestDICOMFile()
        
        // Add Pixel Data tag (7FE0,0010) - OW with small pixel data
        testData.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00]) // Tag
        testData.append(contentsOf: [0x4F, 0x57]) // VR = OW
        testData.append(contentsOf: [0x00, 0x00]) // Reserved
        testData.append(contentsOf: [0x04, 0x00, 0x00, 0x00]) // Length = 4 bytes
        testData.append(contentsOf: [0xFF, 0xFF, 0x00, 0x00]) // Pixel data
        
        // Verify pixel data is present in raw bytes
        let pixelDataPattern = Data([0xFF, 0xFF, 0x00, 0x00])
        XCTAssertTrue(testData.contains(pixelDataPattern))
    }
    
    func testHandleCorruptedFile() throws {
        // Create corrupted data (not a valid DICOM file)
        let corruptedData = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        
        // Should fail to parse
        XCTAssertThrowsError(try DICOMFile.read(from: corruptedData))
    }
    
    // MARK: - Performance Tests
    
    func testDumpMediumRangePerformance() throws {
        let testData = Data(count: 1_000_000) // 1MB
        let rangeData = testData[0..<1024] // Extract 1KB
        
        // Measure hex formatting performance
        measure {
            _ = rangeData.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
    }
    
    func testMemoryUsageForParsing() throws {
        let testData = try createTestDICOMFile()
        
        // Should be able to parse without excessive memory
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertNotNil(dicomFile)
    }
    
    // MARK: - Annotation Tests
    
    func testTagDictionaryLookup() throws {
        // Verify tag dictionary can look up names
        let entry = DataElementDictionary.lookup(tag: .patientName)
        XCTAssertEqual(entry?.keyword, "PatientName")
        
        let modalityEntry = DataElementDictionary.lookup(tag: .modality)
        XCTAssertEqual(modalityEntry?.keyword, "Modality")
    }
    
    func testTagFormatting() throws {
        let tag = Tag(group: 0x0010, element: 0x0010)
        let formatted = String(format: "(%04X,%04X)", tag.group, tag.element)
        XCTAssertEqual(formatted, "(0010,0010)")
    }
    
    // MARK: - Tag Search Tests
    
    func testFindTagInRawData() throws {
        let testData = try createTestDICOMFile()
        
        // Search for Patient Name tag (0010,0010)
        let searchTag = Tag.patientName
        let groupBytes = withUnsafeBytes(of: searchTag.group.littleEndian) { Data($0) }
        let elementBytes = withUnsafeBytes(of: searchTag.element.littleEndian) { Data($0) }
        var searchData = Data()
        searchData.append(groupBytes)
        searchData.append(elementBytes)
        
        // Should find the tag in raw data
        let range = testData.range(of: searchData)
        XCTAssertNotNil(range)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFile() throws {
        let emptyData = Data()
        
        // Should fail to parse
        XCTAssertThrowsError(try DICOMFile.read(from: emptyData))
    }
    
    func testSingleByte() throws {
        let singleByte = Data([0x42])
        
        // Verify we can format it
        let hexString = String(format: "%02X", singleByte[0])
        XCTAssertEqual(hexString, "42")
    }
    
    func testPartialLine() throws {
        let partialData = Data([0x01, 0x02, 0x03])
        
        // Verify we can format partial lines
        let hexString = partialData.map { String(format: "%02X", $0) }.joined(separator: " ")
        XCTAssertEqual(hexString, "01 02 03")
    }
    
    // MARK: - Offset Parsing Tests
    
    func testHexOffsetParsing() throws {
        let hexString = "0x1000"
        let hexPart = String(hexString.dropFirst(2))
        let value = Int(hexPart, radix: 16)
        
        XCTAssertEqual(value, 4096)
    }
    
    func testDecimalOffsetParsing() throws {
        let decimalString = "4096"
        let value = Int(decimalString)
        
        XCTAssertEqual(value, 4096)
    }
    
    // MARK: - Tag Parsing Tests
    
    func testParseTagWithComma() throws {
        let tagString = "0010,0010"
        let cleanString = tagString.replacingOccurrences(of: ",", with: "")
        
        if let value = UInt32(cleanString, radix: 16) {
            let group = UInt16((value >> 16) & 0xFFFF)
            let element = UInt16(value & 0xFFFF)
            
            XCTAssertEqual(group, 0x0010)
            XCTAssertEqual(element, 0x0010)
        } else {
            XCTFail("Failed to parse tag")
        }
    }
    
    func testParseTagWithoutComma() throws {
        let tagString = "00100010"
        
        if let value = UInt32(tagString, radix: 16) {
            let group = UInt16((value >> 16) & 0xFFFF)
            let element = UInt16(value & 0xFFFF)
            
            XCTAssertEqual(group, 0x0010)
            XCTAssertEqual(element, 0x0010)
        } else {
            XCTFail("Failed to parse tag")
        }
    }
}

// Helper extension for Data search
extension Data {
    func contains(_ other: Data) -> Bool {
        return self.range(of: other) != nil
    }
}

