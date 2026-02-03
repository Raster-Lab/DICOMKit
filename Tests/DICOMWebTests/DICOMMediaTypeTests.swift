import Testing
import Foundation
@testable import DICOMWeb

@Suite("DICOMMediaType Tests")
struct DICOMMediaTypeTests {
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with type and subtype")
    func testBasicInitialization() {
        let mediaType = DICOMMediaType(type: "application", subtype: "dicom")
        #expect(mediaType.type == "application")
        #expect(mediaType.subtype == "dicom")
        #expect(mediaType.parameters.isEmpty)
    }
    
    @Test("Initialize with parameters")
    func testInitializationWithParameters() {
        let mediaType = DICOMMediaType(
            type: "application",
            subtype: "dicom",
            parameters: ["transfer-syntax": "1.2.840.10008.1.2.1"]
        )
        #expect(mediaType.parameters["transfer-syntax"] == "1.2.840.10008.1.2.1")
    }
    
    @Test("Type and subtype are lowercased")
    func testLowercasing() {
        let mediaType = DICOMMediaType(type: "APPLICATION", subtype: "DICOM+JSON")
        #expect(mediaType.type == "application")
        #expect(mediaType.subtype == "dicom+json")
    }
    
    // MARK: - Parsing Tests
    
    @Test("Parse simple media type")
    func testParseSimple() {
        let mediaType = DICOMMediaType.parse("application/dicom")
        #expect(mediaType != nil)
        #expect(mediaType?.type == "application")
        #expect(mediaType?.subtype == "dicom")
    }
    
    @Test("Parse media type with parameter")
    func testParseWithParameter() {
        let mediaType = DICOMMediaType.parse("application/dicom; transfer-syntax=1.2.840.10008.1.2.1")
        #expect(mediaType != nil)
        #expect(mediaType?.type == "application")
        #expect(mediaType?.subtype == "dicom")
        #expect(mediaType?.parameters["transfer-syntax"] == "1.2.840.10008.1.2.1")
    }
    
    @Test("Parse media type with quoted parameter")
    func testParseWithQuotedParameter() {
        let mediaType = DICOMMediaType.parse("multipart/related; boundary=\"----boundary123\"")
        #expect(mediaType != nil)
        #expect(mediaType?.parameters["boundary"] == "----boundary123")
    }
    
    @Test("Parse media type with multiple parameters")
    func testParseMultipleParameters() {
        let mediaType = DICOMMediaType.parse("multipart/related; boundary=abc; type=application/dicom")
        #expect(mediaType != nil)
        #expect(mediaType?.parameters["boundary"] == "abc")
        #expect(mediaType?.parameters["type"] == "application/dicom")
    }
    
    @Test("Parse invalid media type returns nil")
    func testParseInvalid() {
        #expect(DICOMMediaType.parse("") == nil)
        #expect(DICOMMediaType.parse("application") == nil)
        #expect(DICOMMediaType.parse("/dicom") == nil)
    }
    
    // MARK: - Description Tests
    
    @Test("Description for simple media type")
    func testDescriptionSimple() {
        let mediaType = DICOMMediaType(type: "application", subtype: "dicom")
        #expect(mediaType.description == "application/dicom")
    }
    
    @Test("Description with parameters")
    func testDescriptionWithParameters() {
        let mediaType = DICOMMediaType(
            type: "application",
            subtype: "dicom",
            parameters: ["transfer-syntax": "1.2.840.10008.1.2.1"]
        )
        #expect(mediaType.description == "application/dicom; transfer-syntax=1.2.840.10008.1.2.1")
    }
    
    // MARK: - Standard Media Types Tests
    
    @Test("Standard DICOM media types")
    func testStandardTypes() {
        #expect(DICOMMediaType.dicom.description == "application/dicom")
        #expect(DICOMMediaType.dicomJSON.description == "application/dicom+json")
        #expect(DICOMMediaType.dicomXML.description == "application/dicom+xml")
        #expect(DICOMMediaType.octetStream.description == "application/octet-stream")
        #expect(DICOMMediaType.jpeg.description == "image/jpeg")
        #expect(DICOMMediaType.png.description == "image/png")
    }
    
    // MARK: - Parameter Methods Tests
    
    @Test("withParameter adds parameter")
    func testWithParameter() {
        let base = DICOMMediaType.dicom
        let withParam = base.withParameter("transfer-syntax", value: "1.2.840.10008.1.2.1")
        
        #expect(base.parameters.isEmpty) // Original unchanged
        #expect(withParam.parameters["transfer-syntax"] == "1.2.840.10008.1.2.1")
    }
    
    @Test("matches compares type and subtype")
    func testMatches() {
        let mt1 = DICOMMediaType.dicom
        let mt2 = DICOMMediaType.dicom.withParameter("transfer-syntax", value: "1.2.3")
        let mt3 = DICOMMediaType.dicomJSON
        
        #expect(mt1.matches(mt2)) // Same type/subtype, different params
        #expect(!mt1.matches(mt3)) // Different subtype
    }
    
    // MARK: - Factory Methods Tests
    
    @Test("dicom with transfer syntax")
    func testDicomWithTransferSyntax() {
        let mediaType = DICOMMediaType.dicom(transferSyntax: "1.2.840.10008.1.2.1")
        #expect(mediaType.type == "application")
        #expect(mediaType.subtype == "dicom")
        #expect(mediaType.transferSyntax == "1.2.840.10008.1.2.1")
    }
    
    @Test("multipartRelated with boundary and type")
    func testMultipartRelated() {
        let mediaType = DICOMMediaType.multipartRelated(
            boundary: "----boundary",
            type: .dicom
        )
        #expect(mediaType.type == "multipart")
        #expect(mediaType.subtype == "related")
        #expect(mediaType.parameters["boundary"] == "----boundary")
    }
    
    // MARK: - Hashable Tests
    
    @Test("Equal media types hash equally")
    func testHashable() {
        let mt1 = DICOMMediaType(type: "application", subtype: "dicom")
        let mt2 = DICOMMediaType(type: "application", subtype: "dicom")
        
        #expect(mt1 == mt2)
        #expect(mt1.hashValue == mt2.hashValue)
        
        let set: Set<DICOMMediaType> = [mt1, mt2]
        #expect(set.count == 1)
    }
}
