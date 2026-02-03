import Testing
import Foundation
@testable import DICOMWeb

@Suite("MultipartMIME Tests")
struct MultipartMIMETests {
    
    // MARK: - Basic Encoding Tests
    
    @Test("Encode single part")
    func testEncodeSinglePart() {
        let part = MultipartMIME.Part(
            contentType: .dicom,
            body: Data("test content".utf8)
        )
        let multipart = MultipartMIME(parts: [part])
        
        let encoded = multipart.encode()
        let string = String(data: encoded, encoding: .utf8)!
        
        #expect(string.contains("--"))
        #expect(string.contains("Content-Type: application/dicom"))
        #expect(string.contains("test content"))
    }
    
    @Test("Encode multiple parts")
    func testEncodeMultipleParts() {
        let part1 = MultipartMIME.Part(
            contentType: .dicom,
            body: Data("part1".utf8)
        )
        let part2 = MultipartMIME.Part(
            contentType: .dicomJSON,
            body: Data("part2".utf8)
        )
        let multipart = MultipartMIME(parts: [part1, part2])
        
        let encoded = multipart.encode()
        let string = String(data: encoded, encoding: .utf8)!
        
        #expect(string.contains("application/dicom"))
        #expect(string.contains("application/dicom+json"))
        #expect(string.contains("part1"))
        #expect(string.contains("part2"))
    }
    
    @Test("Custom boundary is used")
    func testCustomBoundary() {
        let multipart = MultipartMIME(
            boundary: "MyCustomBoundary",
            parts: [MultipartMIME.Part(contentType: .dicom, body: Data())]
        )
        
        let encoded = multipart.encode()
        let string = String(data: encoded, encoding: .utf8)!
        
        #expect(string.contains("--MyCustomBoundary"))
        #expect(string.contains("--MyCustomBoundary--"))
    }
    
    @Test("Part with additional headers")
    func testPartWithHeaders() {
        let part = MultipartMIME.Part(
            contentType: .octetStream,
            headers: ["Content-ID": "<pixel-data>"],
            body: Data([0x00, 0x01, 0x02])
        )
        let multipart = MultipartMIME(parts: [part])
        
        let encoded = multipart.encode()
        let string = String(data: encoded, encoding: .utf8)!
        
        #expect(string.contains("Content-ID: <pixel-data>"))
    }
    
    // MARK: - Content Type Tests
    
    @Test("Content type includes boundary")
    func testContentTypeWithBoundary() {
        let multipart = MultipartMIME(boundary: "TestBoundary", parts: [])
        let contentType = multipart.contentType
        
        #expect(contentType.type == "multipart")
        #expect(contentType.subtype == "related")
        #expect(contentType.parameters["boundary"] == "TestBoundary")
    }
    
    @Test("Content type includes root type")
    func testContentTypeWithRootType() {
        let part = MultipartMIME.Part(contentType: .dicom, body: Data())
        let multipart = MultipartMIME(parts: [part])
        let contentType = multipart.contentType
        
        #expect(contentType.parameters["type"]?.contains("application/dicom") == true)
    }
    
    // MARK: - Part Factory Methods
    
    @Test("DICOM part factory")
    func testDICOMPart() {
        let data = Data([0x44, 0x49, 0x43, 0x4D])
        let part = MultipartMIME.Part.dicom(data, transferSyntax: "1.2.840.10008.1.2.1")
        
        #expect(part.contentType.type == "application")
        #expect(part.contentType.subtype == "dicom")
        #expect(part.contentType.parameters["transfer-syntax"] == "1.2.840.10008.1.2.1")
        #expect(part.body == data)
    }
    
    @Test("DICOM JSON part factory")
    func testDICOMJSONPart() {
        let data = Data("{\"test\": true}".utf8)
        let part = MultipartMIME.Part.dicomJSON(data)
        
        #expect(part.contentType.type == "application")
        #expect(part.contentType.subtype == "dicom+json")
        #expect(part.body == data)
    }
    
    @Test("Bulk data part factory")
    func testBulkDataPart() {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let part = MultipartMIME.Part.bulkData(data, contentID: "pixeldata")
        
        #expect(part.contentType == .octetStream)
        #expect(part.headers["Content-ID"] == "<pixeldata>")
        #expect(part.body == data)
    }
    
    // MARK: - Parsing Tests
    
    @Test("Parse simple multipart")
    func testParseSimple() throws {
        let multipartData = "--boundary123\r\nContent-Type: application/dicom\r\n\r\nDICM content here\r\n--boundary123--\r\n".data(using: .utf8)!
        
        let parsed = try MultipartMIME.parse(data: multipartData, boundary: "boundary123")
        
        #expect(parsed.parts.count == 1)
        #expect(parsed.parts.first?.contentType.subtype == "dicom")
    }
    
    @Test("Parse multipart with multiple parts")
    func testParseMultipleParts() throws {
        let multipartData = "--boundary\r\nContent-Type: application/dicom\r\n\r\npart1\r\n--boundary\r\nContent-Type: application/dicom+json\r\n\r\npart2\r\n--boundary--\r\n".data(using: .utf8)!
        
        let parsed = try MultipartMIME.parse(data: multipartData, boundary: "boundary")
        
        #expect(parsed.parts.count == 2)
        #expect(parsed.parts[0].contentType.subtype == "dicom")
        #expect(parsed.parts[1].contentType.subtype == "dicom+json")
    }
    
    @Test("Parse with Content-Type header")
    func testParseWithContentTypeHeader() throws {
        let multipartData = "--myboundary\r\nContent-Type: application/dicom\r\n\r\ntest\r\n--myboundary--\r\n".data(using: .utf8)!
        
        let parsed = try MultipartMIME.parse(
            data: multipartData,
            contentType: "multipart/related; boundary=myboundary"
        )
        
        #expect(parsed.boundary == "myboundary")
        #expect(parsed.parts.count == 1)
    }
    
    @Test("Parse auto-detects boundary")
    func testParseAutoDetectBoundary() throws {
        let multipartData = "--DetectedBoundary\r\nContent-Type: text/plain\r\n\r\ncontent\r\n--DetectedBoundary--\r\n".data(using: .utf8)!
        
        let parsed = try MultipartMIME.parse(data: multipartData)
        
        #expect(parsed.boundary == "DetectedBoundary")
    }
    
    @Test("Parse extracts headers")
    func testParseExtractsHeaders() throws {
        let multipartData = "--boundary\r\nContent-Type: application/octet-stream\r\nContent-ID: <pixel-data>\r\nX-Custom: value\r\n\r\ndata\r\n--boundary--\r\n".data(using: .utf8)!
        
        let parsed = try MultipartMIME.parse(data: multipartData, boundary: "boundary")
        
        #expect(parsed.parts.first?.headers["Content-ID"] == "<pixel-data>")
        #expect(parsed.parts.first?.headers["X-Custom"] == "value")
    }
    
    // MARK: - Builder Pattern Tests
    
    @Test("Builder creates multipart")
    func testBuilder() {
        let multipart = MultipartMIME.builder()
            .withBoundary("TestBoundary")
            .addDICOM(Data([0x44, 0x49, 0x43, 0x4D]))
            .addDICOMJSON(Data("{\"test\":true}".utf8))
            .build()
        
        #expect(multipart.boundary == "TestBoundary")
        #expect(multipart.parts.count == 2)
    }
    
    @Test("Builder with root type")
    func testBuilderWithRootType() {
        let multipart = MultipartMIME.builder()
            .withRootType(.dicomJSON)
            .addDICOMJSON(Data("{}".utf8))
            .build()
        
        #expect(multipart.rootType == .dicomJSON)
    }
    
    @Test("Builder adds bulk data")
    func testBuilderBulkData() {
        let multipart = MultipartMIME.builder()
            .addBulkData(Data([0x00, 0x01]), contentID: "data1")
            .build()
        
        #expect(multipart.parts.count == 1)
        #expect(multipart.parts.first?.headers["Content-ID"] == "<data1>")
    }
    
    // MARK: - Round Trip Tests
    
    @Test("Encode then parse round trip")
    func testRoundTrip() throws {
        let originalPart = MultipartMIME.Part(
            contentType: .dicom,
            headers: ["Content-ID": "<test>"],
            body: Data("DICOM content".utf8)
        )
        let original = MultipartMIME(boundary: "RoundTripBoundary", parts: [originalPart])
        
        // Encode
        let encoded = original.encode()
        
        // Parse
        let parsed = try MultipartMIME.parse(data: encoded, boundary: "RoundTripBoundary")
        
        #expect(parsed.parts.count == 1)
        #expect(parsed.parts.first?.contentType.subtype == "dicom")
        #expect(parsed.parts.first?.headers["Content-ID"] == "<test>")
    }
    
    // MARK: - Error Cases
    
    @Test("Parse invalid content type throws")
    func testParseInvalidContentType() {
        let data = Data("some data".utf8)
        
        #expect(throws: DICOMwebError.self) {
            _ = try MultipartMIME.parse(data: data, contentType: "invalid")
        }
    }
    
    @Test("Parse missing boundary throws")
    func testParseMissingBoundary() {
        let data = Data("some data".utf8)
        
        #expect(throws: DICOMwebError.self) {
            _ = try MultipartMIME.parse(data: data, contentType: "multipart/related")
        }
    }
    
    @Test("Parse non-multipart type throws")
    func testParseNonMultipartThrows() {
        let data = Data("some data".utf8)
        
        #expect(throws: DICOMwebError.self) {
            _ = try MultipartMIME.parse(data: data, contentType: "application/json")
        }
    }
}
