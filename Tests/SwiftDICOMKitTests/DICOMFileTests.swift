import Testing
import Foundation
@testable import SwiftDICOMKit

@Suite("DICOMFile Tests")
struct DICOMFileTests {
    
    @Test("Valid DICOM file with preamble and DICM prefix")
    func testValidDICOMFile() throws {
        // Create a minimal valid DICOM file structure
        var data = Data()
        
        // 128-byte preamble (can be all zeros)
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        
        let file = try DICOMFile.read(from: data)
        #expect(file.fileMetaInformation.count == 0) // Placeholder implementation
        #expect(file.dataSet.count == 0) // Placeholder implementation
    }
    
    @Test("Invalid DICOM file - too short")
    func testInvalidDICOMFileTooShort() {
        let data = Data(count: 100) // Less than 132 bytes
        
        #expect(throws: DICOMError.self) {
            try DICOMFile.read(from: data)
        }
    }
    
    @Test("Invalid DICOM file - wrong DICM prefix")
    func testInvalidDICOMFileWrongPrefix() {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // Wrong prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x58]) // "DICX"
        
        #expect(throws: DICOMError.self) {
            try DICOMFile.read(from: data)
        }
    }
    
    @Test("Version constant")
    func testVersionConstant() {
        #expect(version == "0.1.0")
    }
    
    @Test("DICOM standard edition")
    func testDICOMStandardEdition() {
        #expect(dicomStandardEdition == "2025e")
    }
    
    @Test("Supported Transfer Syntax UID")
    func testSupportedTransferSyntaxUID() {
        #expect(supportedTransferSyntaxUID == "1.2.840.10008.1.2.1")
    }
}
