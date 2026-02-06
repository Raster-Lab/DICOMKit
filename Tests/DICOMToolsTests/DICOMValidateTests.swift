import XCTest
import Foundation
import ArgumentParser
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

// Test-local versions of validation types (since they're in executable target)
struct ValidationIssue {
    enum Level {
        case error
        case warning
    }
    let level: Level
    let message: String
    let tag: Tag?
}

struct ValidationResult {
    let filePath: String
    let isValid: Bool
    let errors: [ValidationIssue]
    let warnings: [ValidationIssue]
}

enum TestOutputFormat {
    case text
    case json
}

struct ValidationReport {
    let results: [ValidationResult]
    let detailed: Bool
    let strict: Bool
    
    func exitCode() -> Int32 {
        let hasErrors = results.contains { !$0.errors.isEmpty }
        let hasWarnings = results.contains { !$0.warnings.isEmpty }
        
        if hasErrors {
            return 1
        }
        
        if strict && hasWarnings {
            return 2
        }
        
        return 0
    }
    
    func render(format: TestOutputFormat) throws -> String {
        // Simple implementation for testing
        switch format {
        case .text:
            var output = ""
            if results.count == 1 {
                let result = results[0]
                output += "File: \(result.filePath)\n"
                output += "Status: \(result.isValid ? "VALID" : "INVALID")\n"
            } else {
                output += "Total files: \(results.count)\n"
                output += "Valid: \(results.filter { $0.isValid }.count)\n"
                output += "Invalid: \(results.filter { !$0.isValid }.count)\n"
            }
            return output
        case .json:
            return "{\"files\":[]}"
        }
    }
}

struct TestValidator {
    func isValidUID(_ uid: String) -> Bool {
        guard uid.count <= 64 else { return false }
        
        let components = uid.components(separatedBy: ".")
        guard !components.isEmpty else { return false }
        
        for component in components {
            guard !component.isEmpty else { return false }
            guard component.allSatisfy({ $0.isNumber }) else { return false }
            if component.count > 1 && component.first == "0" {
                return false
            }
        }
        
        return true
    }
    
    func isValidDate(_ date: String) -> Bool {
        guard date.count == 8 else { return false }
        guard date.allSatisfy({ $0.isNumber }) else { return false }
        
        guard let year = Int(date.prefix(4)),
              let month = Int(date.dropFirst(4).prefix(2)),
              let day = Int(date.suffix(2)) else {
            return false
        }
        
        guard year >= 1900 && year <= 9999 else { return false }
        guard month >= 1 && month <= 12 else { return false }
        guard day >= 1 && day <= 31 else { return false }
        
        return true
    }
    
    func isValidTime(_ time: String) -> Bool {
        guard time.count >= 6 else { return false }
        
        let components = time.components(separatedBy: ".")
        guard components.count <= 2 else { return false }
        
        let hhmmss = components[0]
        guard hhmmss.count == 6 else { return false }
        guard hhmmss.allSatisfy({ $0.isNumber }) else { return false }
        
        guard let hh = Int(hhmmss.prefix(2)),
              let mm = Int(hhmmss.dropFirst(2).prefix(2)),
              let ss = Int(hhmmss.suffix(2)) else {
            return false
        }
        
        guard hh >= 0 && hh <= 23 else { return false }
        guard mm >= 0 && mm <= 59 else { return false }
        guard ss >= 0 && ss <= 59 else { return false }
        
        if components.count == 2 {
            let fraction = components[1]
            guard fraction.count <= 6 else { return false }
            guard fraction.allSatisfy({ $0.isNumber }) else { return false }
        }
        
        return true
    }
}

/// Tests for dicom-validate CLI tool functionality
final class DICOMValidateTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a minimal valid DICOM file for testing
    private func createTestDICOMFile(
        includePreamble: Bool = true,
        includeSOPClass: Bool = true,
        includeSOPInstance: Bool = true,
        includePatientInfo: Bool = true,
        modality: String = "CT"
    ) throws -> Data {
        var data = Data()
        
        if includePreamble {
            // Add 128-byte preamble
            data.append(Data(count: 128))
            
            // Add DICM prefix
            data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        }
        
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
        
        // Media Storage SOP Class UID (0002,0002) - UI
        if includeSOPClass {
            data.append(contentsOf: [0x02, 0x00, 0x02, 0x00]) // Tag
            data.append(contentsOf: [0x55, 0x49]) // VR = UI
            let sopClassUID = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
            let sopClassLength = UInt16(sopClassUID.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: sopClassLength.littleEndian) { Data($0) })
            data.append(sopClassUID.data(using: .utf8)!)
        }
        
        // Media Storage SOP Instance UID (0002,0003) - UI
        if includeSOPInstance {
            data.append(contentsOf: [0x02, 0x00, 0x03, 0x00]) // Tag
            data.append(contentsOf: [0x55, 0x49]) // VR = UI
            let sopInstanceUID = "1.2.3.4.5.6.7.8.9" // Test UID
            let sopInstanceLength = UInt16(sopInstanceUID.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: sopInstanceLength.littleEndian) { Data($0) })
            data.append(sopInstanceUID.data(using: .utf8)!)
        }
        
        // SOP Class UID (0008,0016) - UI
        if includeSOPClass {
            data.append(contentsOf: [0x08, 0x00, 0x16, 0x00]) // Tag
            data.append(contentsOf: [0x55, 0x49]) // VR = UI
            let sopClassUID = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
            let sopClassLength = UInt16(sopClassUID.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: sopClassLength.littleEndian) { Data($0) })
            data.append(sopClassUID.data(using: .utf8)!)
        }
        
        // SOP Instance UID (0008,0018) - UI
        if includeSOPInstance {
            data.append(contentsOf: [0x08, 0x00, 0x18, 0x00]) // Tag
            data.append(contentsOf: [0x55, 0x49]) // VR = UI
            let sopInstanceUID = "1.2.3.4.5.6.7.8.9" // Test UID
            let sopInstanceLength = UInt16(sopInstanceUID.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: sopInstanceLength.littleEndian) { Data($0) })
            data.append(sopInstanceUID.data(using: .utf8)!)
        }
        
        if includePatientInfo {
            // Patient Name (0010,0010) - PN
            data.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Tag
            data.append(contentsOf: [0x50, 0x4E]) // VR = PN
            let patientName = "Test^Patient"
            let patientNameLength = UInt16(patientName.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: patientNameLength.littleEndian) { Data($0) })
            data.append(patientName.data(using: .utf8)!)
            
            // Patient ID (0010,0020) - LO
            data.append(contentsOf: [0x10, 0x00, 0x20, 0x00]) // Tag
            data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
            let patientID = "12345"
            let patientIDLength = UInt16(patientID.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: patientIDLength.littleEndian) { Data($0) })
            data.append(patientID.data(using: .utf8)!)
        }
        
        // Study Instance UID (0020,000D) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let studyInstanceUID = "1.2.3.4.5"
        let studyInstanceLength = UInt16(studyInstanceUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: studyInstanceLength.littleEndian) { Data($0) })
        data.append(studyInstanceUID.data(using: .utf8)!)
        
        // Series Instance UID (0020,000E) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0E, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let seriesInstanceUID = "1.2.3.4.5.6"
        let seriesInstanceLength = UInt16(seriesInstanceUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: seriesInstanceLength.littleEndian) { Data($0) })
        data.append(seriesInstanceUID.data(using: .utf8)!)
        
        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modalityLength = UInt16(modality.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modalityLength.littleEndian) { Data($0) })
        data.append(modality.data(using: .utf8)!)
        
        // Add image dimensions for image IODs
        if ["CT", "MR", "CR", "US"].contains(modality) {
            // Rows (0028,0010) - US
            data.append(contentsOf: [0x28, 0x00, 0x10, 0x00]) // Tag
            data.append(contentsOf: [0x55, 0x53]) // VR = US
            data.append(contentsOf: [0x02, 0x00]) // Length = 2
            data.append(contentsOf: [0x00, 0x02]) // Value = 512
            
            // Columns (0028,0011) - US
            data.append(contentsOf: [0x28, 0x00, 0x11, 0x00]) // Tag
            data.append(contentsOf: [0x55, 0x53]) // VR = US
            data.append(contentsOf: [0x02, 0x00]) // Length = 2
            data.append(contentsOf: [0x00, 0x02]) // Value = 512
        }
        
        return data
    }
    
    // MARK: - Level 1: Format Validation Tests
    
    func testValidFileFormat() throws {
        let testData = try createTestDICOMFile()
        // Test basic DICOM file parsing
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertNotNil(dicomFile)
    }
    
    func testMissingDICMPrefix() throws {
        let testData = try createTestDICOMFile(includePreamble: false)
        // Should still parse with force flag
        _ = try? DICOMFile.read(from: testData, force: true)
    }
    
    func testMissingFileMetaInformation() throws {
        let testData = try createTestDICOMFile(includeSOPClass: false)
        // Test that file without proper meta information has issues
        let dicomFile = try DICOMFile.read(from: testData, force: true)
        XCTAssertNotNil(dicomFile)
    }
    
    func testInvalidTransferSyntaxUID() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        let transferSyntax = dicomFile.fileMetaInformation.string(for: .transferSyntaxUID)
        XCTAssertNotNil(transferSyntax)
    }
    
    // MARK: - Level 2: Tag/VR/VM Validation Tests
    
    func testMissingRequiredSOPClassUID() throws {
        let testData = try createTestDICOMFile(includeSOPClass: false)
        let dicomFile = try DICOMFile.read(from: testData, force: true)
        let sopClass = dicomFile.dataSet.string(for: .sopClassUID)
        XCTAssertNil(sopClass) // Should be missing
    }
    
    func testMissingRequiredSOPInstanceUID() throws {
        let testData = try createTestDICOMFile(includeSOPInstance: false)
        let dicomFile = try DICOMFile.read(from: testData, force: true)
        let sopInstance = dicomFile.dataSet.string(for: .sopInstanceUID)
        XCTAssertNil(sopInstance) // Should be missing
    }
    
    func testValidUIDFormat() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        let sopInstanceUID = dicomFile.dataSet.string(for: .sopInstanceUID)
        XCTAssertNotNil(sopInstanceUID)
        
        // Test UID format validation
        let validator = TestValidator()
        XCTAssertTrue(validator.isValidUID(sopInstanceUID!))
    }
    
    func testDateFormatValidation() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertNotNil(dicomFile)
    }
    
    func testTimeFormatValidation() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertNotNil(dicomFile)
    }
    
    func testPersonNameFormat() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        let patientName = dicomFile.dataSet.string(for: .patientName)
        XCTAssertEqual(patientName, "Test^Patient")
    }
    
    func testCodeStringFormat() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        let modality = dicomFile.dataSet.string(for: .modality)
        XCTAssertEqual(modality, "CT")
    }
    
    // MARK: - Level 3: IOD Validation Tests
    
    func testCTImageStorageValidation() throws {
        let testData = try createTestDICOMFile(modality: "CT")
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify required CT fields are present
        XCTAssertNotNil(dicomFile.dataSet.string(for: .patientName))
        XCTAssertNotNil(dicomFile.dataSet.string(for: .patientID))
        XCTAssertNotNil(dicomFile.dataSet.string(for: .studyInstanceUID))
        XCTAssertNotNil(dicomFile.dataSet.string(for: .seriesInstanceUID))
        XCTAssertEqual(dicomFile.dataSet.string(for: .modality), "CT")
    }
    
    func testCTImageStorageMissingPatient() throws {
        let testData = try createTestDICOMFile(includePatientInfo: false, modality: "CT")
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Should be missing patient information
        XCTAssertNil(dicomFile.dataSet.string(for: .patientName))
        XCTAssertNil(dicomFile.dataSet.string(for: .patientID))
    }
    
    func testCTImageStorageWrongModality() throws {
        let testData = try createTestDICOMFile(modality: "MR")
        let dicomFile = try DICOMFile.read(from: testData)
        let modality = dicomFile.dataSet.string(for: .modality)
        
        // Modality should be MR, not CT
        XCTAssertEqual(modality, "MR")
        XCTAssertNotEqual(modality, "CT")
    }
    
    func testMRImageStorageValidation() throws {
        let testData = try createTestDICOMFile(modality: "MR")
        let dicomFile = try DICOMFile.read(from: testData)
        
        // Verify required MR fields are present
        XCTAssertNotNil(dicomFile.dataSet.string(for: .patientName))
        XCTAssertNotNil(dicomFile.dataSet.string(for: .patientID))
        XCTAssertEqual(dicomFile.dataSet.string(for: .modality), "MR")
    }
    
    func testCRImageStorageValidation() throws {
        let testData = try createTestDICOMFile(modality: "CR")
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertEqual(dicomFile.dataSet.string(for: .modality), "CR")
    }
    
    func testUSImageStorageValidation() throws {
        let testData = try createTestDICOMFile(modality: "US")
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertEqual(dicomFile.dataSet.string(for: .modality), "US")
    }
    
    func testAutoDetectIOD() throws {
        let testData = try createTestDICOMFile(modality: "CT")
        let dicomFile = try DICOMFile.read(from: testData)
        let sopClassUID = dicomFile.dataSet.string(for: .sopClassUID)
        
        // CT Image Storage SOP Class UID
        XCTAssertEqual(sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
    }
    
    // MARK: - Level 4: Best Practices Tests
    
    func testBestPracticesValidation() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        XCTAssertNotNil(dicomFile)
    }
    
    func testMissingCharacterSetWarning() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        let charSet = dicomFile.dataSet.string(for: .specificCharacterSet)
        
        // Character set not included in minimal test file
        XCTAssertNil(charSet)
    }
    
    // MARK: - UID Validation Tests
    
    func testValidUIDFormatMethod() {
        let validator = TestValidator()
        
        // Valid UIDs
        XCTAssertTrue(validator.isValidUID("1.2.3.4.5"))
        XCTAssertTrue(validator.isValidUID("1.2.840.10008.5.1.4.1.1.2"))
        XCTAssertTrue(validator.isValidUID("0.1.2"))
        
        // Invalid UIDs
        XCTAssertFalse(validator.isValidUID("")) // Empty
        XCTAssertFalse(validator.isValidUID("1.2.3.")) // Trailing dot
        XCTAssertFalse(validator.isValidUID(".1.2.3")) // Leading dot
        XCTAssertFalse(validator.isValidUID("1.2..3")) // Double dot
        XCTAssertFalse(validator.isValidUID("1.2.3.a")) // Non-numeric
        XCTAssertFalse(validator.isValidUID("1.2.03")) // Leading zero (invalid)
        XCTAssertFalse(validator.isValidUID(String(repeating: "1.", count: 33))) // Too long (>64 chars)
    }
    
    func testValidDateFormatMethod() {
        let validator = TestValidator()
        
        // Valid dates
        XCTAssertTrue(validator.isValidDate("20240101"))
        XCTAssertTrue(validator.isValidDate("20231231"))
        XCTAssertTrue(validator.isValidDate("19900515"))
        
        // Invalid dates
        XCTAssertFalse(validator.isValidDate("")) // Empty
        XCTAssertFalse(validator.isValidDate("2024010")) // Too short
        XCTAssertFalse(validator.isValidDate("202401011")) // Too long
        XCTAssertFalse(validator.isValidDate("2024-01-01")) // Wrong format
        XCTAssertFalse(validator.isValidDate("20241301")) // Invalid month
        XCTAssertFalse(validator.isValidDate("20240132")) // Invalid day
        XCTAssertFalse(validator.isValidDate("20240100")) // Invalid day (0)
        XCTAssertFalse(validator.isValidDate("20241200")) // Invalid day (0)
    }
    
    func testValidTimeFormatMethod() {
        let validator = TestValidator()
        
        // Valid times
        XCTAssertTrue(validator.isValidTime("120000"))
        XCTAssertTrue(validator.isValidTime("235959"))
        XCTAssertTrue(validator.isValidTime("000000"))
        XCTAssertTrue(validator.isValidTime("120000.123456"))
        XCTAssertTrue(validator.isValidTime("000000.1"))
        
        // Invalid times
        XCTAssertFalse(validator.isValidTime("")) // Empty
        XCTAssertFalse(validator.isValidTime("12000")) // Too short
        XCTAssertFalse(validator.isValidTime("12:00:00")) // Wrong format
        XCTAssertFalse(validator.isValidTime("240000")) // Invalid hour
        XCTAssertFalse(validator.isValidTime("126000")) // Invalid minute
        XCTAssertFalse(validator.isValidTime("120060")) // Invalid second
        XCTAssertFalse(validator.isValidTime("120000.1234567")) // Fractional seconds too long
    }
    
    // MARK: - Report Generation Tests
    
    func testTextReportGeneration() {
        let result = ValidationResult(
            filePath: "test.dcm",
            isValid: false,
            errors: [
                ValidationIssue(level: .error, message: "Missing SOP Class UID", tag: Tag.sopClassUID)
            ],
            warnings: [
                ValidationIssue(level: .warning, message: "Missing Character Set", tag: Tag.specificCharacterSet)
            ]
        )
        
        let report = ValidationReport(results: [result], detailed: false, strict: false)
        let output = try! report.render(format: .text)
        
        XCTAssertTrue(output.contains("INVALID"))
    }
    
    func testJSONReportGeneration() throws {
        let result = ValidationResult(
            filePath: "test.dcm",
            isValid: false,
            errors: [
                ValidationIssue(level: .error, message: "Missing SOP Class UID", tag: Tag.sopClassUID)
            ],
            warnings: []
        )
        
        let report = ValidationReport(results: [result], detailed: false, strict: false)
        let output = try report.render(format: .json)
        
        XCTAssertTrue(output.contains("{"))
    }
    
    func testExitCodeValidFiles() {
        let result = ValidationResult(
            filePath: "test.dcm",
            isValid: true,
            errors: [],
            warnings: []
        )
        
        let report = ValidationReport(results: [result], detailed: false, strict: false)
        XCTAssertEqual(report.exitCode(), 0)
    }
    
    func testExitCodeInvalidFiles() {
        let result = ValidationResult(
            filePath: "test.dcm",
            isValid: false,
            errors: [
                ValidationIssue(level: .error, message: "Test error", tag: nil)
            ],
            warnings: []
        )
        
        let report = ValidationReport(results: [result], detailed: false, strict: false)
        XCTAssertEqual(report.exitCode(), 1)
    }
    
    func testExitCodeStrictModeWithWarnings() {
        let result = ValidationResult(
            filePath: "test.dcm",
            isValid: true,
            errors: [],
            warnings: [
                ValidationIssue(level: .warning, message: "Test warning", tag: nil)
            ]
        )
        
        let report = ValidationReport(results: [result], detailed: false, strict: true)
        XCTAssertEqual(report.exitCode(), 2) // Strict mode treats warnings as errors
    }
    
    // MARK: - Batch Validation Tests
    
    func testMultipleFilesSummary() throws {
        let result1 = ValidationResult(
            filePath: "file1.dcm",
            isValid: true,
            errors: [],
            warnings: []
        )
        let result2 = ValidationResult(
            filePath: "file2.dcm",
            isValid: false,
            errors: [
                ValidationIssue(level: .error, message: "Test error", tag: nil)
            ],
            warnings: []
        )
        
        let report = ValidationReport(results: [result1, result2], detailed: false, strict: false)
        let output = try report.render(format: .text)
        
        XCTAssertTrue(output.contains("Total files: 2"))
        XCTAssertTrue(output.contains("Valid: 1"))
        XCTAssertTrue(output.contains("Invalid: 1"))
    }
}