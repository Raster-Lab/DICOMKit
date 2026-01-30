import Testing
import Foundation
@testable import SwiftDICOMKit
import DICOMCore

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
        // File with no elements is valid
        #expect(file.fileMetaInformation.count == 0)
        #expect(file.dataSet.count == 0)
    }
    
    @Test("Parse File Meta Information with Transfer Syntax UID")
    func testParseFileMetaInformation() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Add Transfer Syntax UID element (0002,0010)
        // Tag: 0002,0010
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        // VR: UI (Unique Identifier)
        data.append(contentsOf: [0x55, 0x49]) // "UI"
        // Length: 20 (16-bit for UI)
        data.append(contentsOf: [0x14, 0x00])
        // Value: "1.2.840.10008.1.2.1 " (Explicit VR Little Endian, padded to even length)
        data.append(contentsOf: [0x31, 0x2e, 0x32, 0x2e, 0x38, 0x34, 0x30, 0x2e, 
                                 0x31, 0x30, 0x30, 0x30, 0x38, 0x2e, 0x31, 0x2e,
                                 0x32, 0x2e, 0x31, 0x20])
        
        let file = try DICOMFile.read(from: data)
        #expect(file.fileMetaInformation.count == 1)
        #expect(file.transferSyntaxUID == "1.2.840.10008.1.2.1")
    }
    
    @Test("Parse patient name from main data set")
    func testParsePatientName() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // No File Meta Information (will use default transfer syntax)
        
        // Add Patient Name element (0010,0010)
        // Tag: 0010,0010
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
        // VR: PN (Person Name)
        data.append(contentsOf: [0x50, 0x4E]) // "PN"
        // Length: 8
        data.append(contentsOf: [0x08, 0x00])
        // Value: "Doe^John"
        data.append(contentsOf: [0x44, 0x6F, 0x65, 0x5E, 0x4A, 0x6F, 0x68, 0x6E])
        
        let file = try DICOMFile.read(from: data)
        #expect(file.dataSet.count == 1)
        
        let patientName = file.dataSet.string(for: .patientName)
        #expect(patientName == "Doe^John")
    }
    
    @Test("Parse multiple elements")
    func testParseMultipleElements() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Patient ID (0010,0020) - LO VR
        data.append(contentsOf: [0x10, 0x00, 0x20, 0x00])
        data.append(contentsOf: [0x4C, 0x4F]) // "LO"
        data.append(contentsOf: [0x06, 0x00]) // Length: 6
        data.append(contentsOf: [0x31, 0x32, 0x33, 0x34, 0x35, 0x36]) // "123456"
        
        // Study Date (0008,0020) - DA VR
        data.append(contentsOf: [0x08, 0x00, 0x20, 0x00])
        data.append(contentsOf: [0x44, 0x41]) // "DA"
        data.append(contentsOf: [0x08, 0x00]) // Length: 8
        data.append(contentsOf: [0x32, 0x30, 0x32, 0x35, 0x30, 0x31, 0x32, 0x38]) // "20250128"
        
        let file = try DICOMFile.read(from: data)
        #expect(file.dataSet.count == 2)
        
        let patientID = file.dataSet.string(for: .patientID)
        #expect(patientID == "123456")
        
        let studyDate = file.dataSet.string(for: .studyDate)
        #expect(studyDate == "20250128")
    }
    
    @Test("Parse element with 32-bit length VR")
    func testParse32BitLengthVR() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Study Description (0008,1030) - LO VR (uses 16-bit length)
        data.append(contentsOf: [0x08, 0x00, 0x30, 0x10])
        data.append(contentsOf: [0x4C, 0x4F]) // "LO"
        data.append(contentsOf: [0x0A, 0x00]) // Length: 10
        data.append(contentsOf: [0x54, 0x65, 0x73, 0x74, 0x20, 0x53, 0x74, 0x75, 0x64, 0x79]) // "Test Study"
        
        let file = try DICOMFile.read(from: data)
        #expect(file.dataSet.count == 1)
        
        let description = file.dataSet.string(for: .studyDescription)
        #expect(description == "Test Study")
    }
    
    @Test("Stop parsing at pixel data")
    func testStopAtPixelData() throws {
        var data = Data()
        
        // 128-byte preamble
        data.append(Data(count: 128))
        
        // "DICM" prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])
        
        // Patient Name (0010,0010)
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x50, 0x4E]) // "PN"
        data.append(contentsOf: [0x04, 0x00]) // Length: 4
        data.append(contentsOf: [0x54, 0x65, 0x73, 0x74]) // "Test"
        
        // Pixel Data (7FE0,0010) - should stop here
        data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00])
        data.append(contentsOf: [0x4F, 0x57]) // "OW"
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: [0x04, 0x00, 0x00, 0x00]) // Length: 4
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Dummy pixel data
        
        let file = try DICOMFile.read(from: data)
        // Should only have parsed the patient name, not pixel data
        #expect(file.dataSet.count == 1)
        
        let patientName = file.dataSet.string(for: .patientName)
        #expect(patientName == "Test")
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
