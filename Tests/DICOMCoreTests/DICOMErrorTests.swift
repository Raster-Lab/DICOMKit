import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMError Tests")
struct DICOMErrorTests {
    
    // MARK: - Error Description Tests
    
    @Test("invalidPreamble error has correct description")
    func testInvalidPreambleDescription() {
        let error = DICOMError.invalidPreamble
        
        #expect(error.description == "Invalid DICOM preamble")
    }
    
    @Test("invalidDICMPrefix error has correct description")
    func testInvalidDICMPrefixDescription() {
        let error = DICOMError.invalidDICMPrefix
        
        #expect(error.description == "Invalid DICM prefix")
    }
    
    @Test("unexpectedEndOfData error has correct description")
    func testUnexpectedEndOfDataDescription() {
        let error = DICOMError.unexpectedEndOfData
        
        #expect(error.description == "Unexpected end of data")
    }
    
    @Test("invalidVR error includes VR value")
    func testInvalidVRDescription() {
        let error = DICOMError.invalidVR("XX")
        
        #expect(error.description == "Invalid Value Representation: XX")
    }
    
    @Test("unsupportedTransferSyntax error includes UID")
    func testUnsupportedTransferSyntaxDescription() {
        let uid = "1.2.3.4.5.6.7"
        let error = DICOMError.unsupportedTransferSyntax(uid)
        
        #expect(error.description == "Unsupported Transfer Syntax: \(uid)")
    }
    
    @Test("invalidTag error has correct description")
    func testInvalidTagDescription() {
        let error = DICOMError.invalidTag
        
        #expect(error.description == "Invalid tag")
    }
    
    @Test("parsingFailed error includes message")
    func testParsingFailedDescription() {
        let message = "Custom error message"
        let error = DICOMError.parsingFailed(message)
        
        #expect(error.description == "Parsing failed: \(message)")
    }
    
    // MARK: - LocalizedError Conformance Tests
    
    @Test("localizedDescription returns proper message for invalidPreamble")
    func testLocalizedDescriptionInvalidPreamble() {
        let error = DICOMError.invalidPreamble
        
        #expect(error.localizedDescription == "Invalid DICOM preamble")
    }
    
    @Test("localizedDescription returns proper message for invalidDICMPrefix")
    func testLocalizedDescriptionInvalidDICMPrefix() {
        let error = DICOMError.invalidDICMPrefix
        
        #expect(error.localizedDescription == "Invalid DICM prefix")
    }
    
    @Test("localizedDescription returns proper message for unexpectedEndOfData")
    func testLocalizedDescriptionUnexpectedEndOfData() {
        let error = DICOMError.unexpectedEndOfData
        
        #expect(error.localizedDescription == "Unexpected end of data")
    }
    
    @Test("localizedDescription returns proper message for invalidVR")
    func testLocalizedDescriptionInvalidVR() {
        let error = DICOMError.invalidVR("ZZ")
        
        #expect(error.localizedDescription == "Invalid Value Representation: ZZ")
    }
    
    @Test("localizedDescription returns proper message for unsupportedTransferSyntax")
    func testLocalizedDescriptionUnsupportedTransferSyntax() {
        let uid = "1.2.840.10008.1.2.4.999"
        let error = DICOMError.unsupportedTransferSyntax(uid)
        
        #expect(error.localizedDescription == "Unsupported Transfer Syntax: \(uid)")
    }
    
    @Test("localizedDescription returns proper message for invalidTag")
    func testLocalizedDescriptionInvalidTag() {
        let error = DICOMError.invalidTag
        
        #expect(error.localizedDescription == "Invalid tag")
    }
    
    @Test("localizedDescription returns proper message for parsingFailed")
    func testLocalizedDescriptionParsingFailed() {
        let message = "Test error message"
        let error = DICOMError.parsingFailed(message)
        
        #expect(error.localizedDescription == "Parsing failed: \(message)")
    }
    
    // MARK: - Error Conformance Tests
    
    @Test("DICOMError conforms to Error protocol")
    func testErrorConformance() {
        let error: Error = DICOMError.invalidPreamble
        #expect(error is DICOMError)
    }
    
    @Test("DICOMError conforms to Sendable")
    func testSendableConformance() {
        let error: any Sendable = DICOMError.invalidPreamble
        #expect(error is DICOMError)
    }
    
    @Test("DICOMError conforms to LocalizedError")
    func testLocalizedErrorConformance() {
        let error: any LocalizedError = DICOMError.invalidPreamble
        #expect(error is DICOMError)
        #expect(error.errorDescription != nil)
    }
    
    // MARK: - Error Description vs LocalizedDescription Consistency Tests
    
    @Test("description and localizedDescription are consistent for all error cases")
    func testDescriptionConsistency() {
        let errors: [DICOMError] = [
            .invalidPreamble,
            .invalidDICMPrefix,
            .unexpectedEndOfData,
            .invalidVR("AB"),
            .unsupportedTransferSyntax("1.2.3"),
            .invalidTag,
            .parsingFailed("test")
        ]
        
        for error in errors {
            #expect(error.description == error.localizedDescription,
                   "description and localizedDescription should match for \(error)")
        }
    }
}
