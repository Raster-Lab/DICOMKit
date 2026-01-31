import Testing
import Foundation
@testable import DICOMCore

@Suite("DICOMUniversalResource Tests")
struct DICOMUniversalResourceTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse standard HTTP URL")
    func testParseStandardHTTPURL() {
        let uri = DICOMUniversalResource.parse("http://www.example.com")
        #expect(uri != nil)
        #expect(uri?.value == "http://www.example.com")
    }
    
    @Test("Parse HTTPS URL")
    func testParseHTTPSURL() {
        let uri = DICOMUniversalResource.parse("https://dicom.nema.org/medical/dicom/current")
        #expect(uri != nil)
        #expect(uri?.value == "https://dicom.nema.org/medical/dicom/current")
    }
    
    @Test("Parse URL with path and query")
    func testParseURLWithPathAndQuery() {
        let uri = DICOMUniversalResource.parse("http://example.com/wado?requestType=WADO&studyUID=1.2.3")
        #expect(uri != nil)
        #expect(uri?.value == "http://example.com/wado?requestType=WADO&studyUID=1.2.3")
    }
    
    @Test("Parse URL with fragment")
    func testParseURLWithFragment() {
        let uri = DICOMUniversalResource.parse("http://example.com/page#section1")
        #expect(uri != nil)
        #expect(uri?.value == "http://example.com/page#section1")
    }
    
    @Test("Parse file URL")
    func testParseFileURL() {
        let uri = DICOMUniversalResource.parse("file:///path/to/file.dcm")
        #expect(uri != nil)
        #expect(uri?.value == "file:///path/to/file.dcm")
    }
    
    @Test("Parse URN with OID")
    func testParseURNWithOID() {
        let uri = DICOMUniversalResource.parse("urn:oid:1.2.840.10008.5.1.4.1.1.2")
        #expect(uri != nil)
        #expect(uri?.value == "urn:oid:1.2.840.10008.5.1.4.1.1.2")
    }
    
    @Test("Parse URN with UUID")
    func testParseURNWithUUID() {
        let uri = DICOMUniversalResource.parse("urn:uuid:f47ac10b-58cc-4372-a567-0e02b2c3d479")
        #expect(uri != nil)
        #expect(uri?.value == "urn:uuid:f47ac10b-58cc-4372-a567-0e02b2c3d479")
    }
    
    @Test("Parse URL with port number")
    func testParseURLWithPort() {
        let uri = DICOMUniversalResource.parse("http://server.hospital.org:8080/wado")
        #expect(uri != nil)
        #expect(uri?.value == "http://server.hospital.org:8080/wado")
    }
    
    @Test("Parse URL with authentication")
    func testParseURLWithAuth() {
        // Note: This test validates RFC 3986 compliance for URI parsing.
        // In production code, credentials should be handled separately
        // (e.g., via HTTP headers, OAuth tokens, or secure credential storage)
        // rather than embedded in URLs.
        let uri = DICOMUniversalResource.parse("http://user:password@example.com/resource")
        #expect(uri != nil)
        #expect(uri?.value == "http://user:password@example.com/resource")
    }
    
    @Test("Parse URL with encoded characters")
    func testParseURLWithEncodedChars() {
        let uri = DICOMUniversalResource.parse("http://example.com/path%20with%20spaces")
        #expect(uri != nil)
        #expect(uri?.value == "http://example.com/path%20with%20spaces")
    }
    
    @Test("Parse with leading/trailing whitespace")
    func testParseWithWhitespace() {
        let uri = DICOMUniversalResource.parse("  http://example.com  ")
        #expect(uri != nil)
        #expect(uri?.value == "http://example.com")
    }
    
    @Test("Parse with null padding (common in DICOM)")
    func testParseWithNullPadding() {
        let uri = DICOMUniversalResource.parse("http://example.com\0\0")
        #expect(uri != nil)
        #expect(uri?.value == "http://example.com")
    }
    
    @Test("Parse empty string returns empty URI")
    func testParseEmptyString() {
        let uri = DICOMUniversalResource.parse("")
        #expect(uri != nil)
        #expect(uri?.value == "")
        #expect(uri?.isEmpty == true)
    }
    
    @Test("Parse whitespace-only string returns empty URI")
    func testParseWhitespaceOnly() {
        let uri = DICOMUniversalResource.parse("   ")
        #expect(uri != nil)
        #expect(uri?.value == "")
        #expect(uri?.isEmpty == true)
    }
    
    // MARK: - Validation Tests
    
    @Test("Reject URI with embedded spaces")
    func testRejectEmbeddedSpaces() {
        // Spaces should not be allowed within the URI
        let uri = DICOMUniversalResource.parse("http://example.com/path with spaces")
        #expect(uri == nil)
    }
    
    @Test("Reject URI with control characters")
    func testRejectControlCharacters() {
        // Tab character
        let uriTab = DICOMUniversalResource.parse("http://example.com\tpath")
        #expect(uriTab == nil)
        
        // Newline
        let uriNewline = DICOMUniversalResource.parse("http://example.com\npath")
        #expect(uriNewline == nil)
        
        // Carriage return
        let uriCR = DICOMUniversalResource.parse("http://example.com\rpath")
        #expect(uriCR == nil)
    }
    
    @Test("Reject string without scheme")
    func testRejectWithoutScheme() {
        // No colon at all
        let uriNoColon = DICOMUniversalResource.parse("www.example.com")
        #expect(uriNoColon == nil)
    }
    
    @Test("Reject invalid scheme (starts with number)")
    func testRejectInvalidSchemeNumber() {
        let uri = DICOMUniversalResource.parse("3http://example.com")
        #expect(uri == nil)
    }
    
    @Test("Reject empty scheme")
    func testRejectEmptyScheme() {
        let uri = DICOMUniversalResource.parse("://example.com")
        #expect(uri == nil)
    }
    
    @Test("Accept various valid URI schemes")
    func testAcceptVariousSchemes() {
        let validSchemes = [
            "http://example.com",
            "https://example.com",
            "ftp://files.example.com",
            "mailto:user@example.com",
            "tel:+1-555-555-5555"
        ]
        
        for uriString in validSchemes {
            let uri = DICOMUniversalResource.parse(uriString)
            #expect(uri != nil, "Should parse URI: \(uriString)")
        }
    }
    
    // MARK: - Multiple Values Tests
    
    @Test("Parse multiple URIs")
    func testParseMultiple() {
        let uris = DICOMUniversalResource.parseMultiple("http://example.com\\https://example.org")
        #expect(uris != nil)
        #expect(uris?.count == 2)
        #expect(uris?[0].value == "http://example.com")
        #expect(uris?[1].value == "https://example.org")
    }
    
    @Test("Parse single URI as multiple returns single element")
    func testParseSingleAsMultiple() {
        let uris = DICOMUniversalResource.parseMultiple("http://example.com")
        #expect(uris != nil)
        #expect(uris?.count == 1)
        #expect(uris?[0].value == "http://example.com")
    }
    
    @Test("Parse multiple with invalid URI returns nil")
    func testParseMultipleWithInvalid() {
        // One URI has embedded space
        let uris = DICOMUniversalResource.parseMultiple("http://example.com\\invalid uri")
        #expect(uris == nil)
    }
    
    @Test("Parse three URIs")
    func testParseThreeURIs() {
        let uris = DICOMUniversalResource.parseMultiple("http://a.com\\http://b.com\\http://c.com")
        #expect(uris != nil)
        #expect(uris?.count == 3)
        #expect(uris?[0].value == "http://a.com")
        #expect(uris?[1].value == "http://b.com")
        #expect(uris?[2].value == "http://c.com")
    }
    
    @Test("Parse multiple with empty values")
    func testParseMultipleWithEmpty() {
        // Empty values between delimiters are valid
        let uris = DICOMUniversalResource.parseMultiple("http://a.com\\\\http://b.com")
        #expect(uris != nil)
        #expect(uris?.count == 3)
        #expect(uris?[0].value == "http://a.com")
        #expect(uris?[1].value == "")
        #expect(uris?[2].value == "http://b.com")
    }
    
    // MARK: - Property Tests
    
    @Test("isEmpty property")
    func testIsEmptyProperty() {
        let emptyURI = DICOMUniversalResource.parse("")
        #expect(emptyURI?.isEmpty == true)
        
        let nonEmptyURI = DICOMUniversalResource.parse("http://example.com")
        #expect(nonEmptyURI?.isEmpty == false)
    }
    
    @Test("length property")
    func testLengthProperty() {
        let uri = DICOMUniversalResource.parse("http://example.com")
        #expect(uri?.length == 18)
        
        let emptyURI = DICOMUniversalResource.parse("")
        #expect(emptyURI?.length == 0)
    }
    
    @Test("paddedValue property for odd length")
    func testPaddedValueOddLength() {
        let uriEven = DICOMUniversalResource.parse("http://a.com")  // 12 chars (even)
        #expect(uriEven?.paddedValue.count == 12)
        #expect(uriEven?.paddedValue == "http://a.com")
        
        let uriOdd = DICOMUniversalResource.parse("http://a.co")  // 11 chars (odd)
        #expect(uriOdd?.paddedValue.count == 12)
        #expect(uriOdd?.paddedValue == "http://a.co ")
    }
    
    @Test("paddedValue property for even length")
    func testPaddedValueEvenLength() {
        let uri = DICOMUniversalResource.parse("http://example.com")  // 18 chars (even)
        #expect(uri?.paddedValue.count == 18)
        #expect(uri?.paddedValue == "http://example.com")
    }
    
    @Test("dicomString property")
    func testDicomStringProperty() {
        let uri = DICOMUniversalResource.parse("http://example.com")
        #expect(uri?.dicomString == "http://example.com")
    }
    
    @Test("url property returns Foundation URL")
    func testURLProperty() {
        let uri = DICOMUniversalResource.parse("http://example.com/path")
        #expect(uri?.url != nil)
        // Use string comparison for host/path to avoid deprecated API warnings
        #expect(uri?.url?.host() == "example.com")
        #expect(uri?.url?.path() == "/path")
    }
    
    @Test("url property returns nil for empty URI")
    func testURLPropertyEmpty() {
        let uri = DICOMUniversalResource.parse("")
        #expect(uri?.url == nil)
    }
    
    @Test("scheme property")
    func testSchemeProperty() {
        let httpURI = DICOMUniversalResource.parse("http://example.com")
        #expect(httpURI?.scheme == "http")
        
        let httpsURI = DICOMUniversalResource.parse("https://example.com")
        #expect(httpsURI?.scheme == "https")
        
        let urnURI = DICOMUniversalResource.parse("urn:oid:1.2.3")
        #expect(urnURI?.scheme == "urn")
        
        let emptyURI = DICOMUniversalResource.parse("")
        #expect(emptyURI?.scheme == nil)
    }
    
    @Test("isAbsolute property")
    func testIsAbsoluteProperty() {
        let absoluteURI = DICOMUniversalResource.parse("http://example.com")
        #expect(absoluteURI?.isAbsolute == true)
        
        let emptyURI = DICOMUniversalResource.parse("")
        #expect(emptyURI?.isAbsolute == false)
    }
    
    // MARK: - CustomStringConvertible Tests
    
    @Test("CustomStringConvertible description")
    func testDescription() {
        let uri = DICOMUniversalResource.parse("http://example.com")
        #expect(String(describing: uri!) == "http://example.com")
    }
    
    // MARK: - ExpressibleByStringLiteral Tests
    
    @Test("Create URI from string literal")
    func testStringLiteral() {
        let uri: DICOMUniversalResource = "http://example.com"
        #expect(uri.value == "http://example.com")
    }
    
    // MARK: - Equatable/Hashable Tests
    
    @Test("Equality comparison")
    func testEquality() {
        let uri1 = DICOMUniversalResource.parse("http://example.com")
        let uri2 = DICOMUniversalResource.parse("http://example.com")
        let uri3 = DICOMUniversalResource.parse("http://other.com")
        
        #expect(uri1 == uri2)
        #expect(uri1 != uri3)
    }
    
    @Test("Equality with trimmed whitespace")
    func testEqualityWithWhitespace() {
        let uri1 = DICOMUniversalResource.parse("http://example.com")
        let uri2 = DICOMUniversalResource.parse("  http://example.com  ")
        
        #expect(uri1 == uri2)
    }
    
    @Test("Hash value consistency")
    func testHashable() {
        let uri1 = DICOMUniversalResource.parse("http://example.com")!
        let uri2 = DICOMUniversalResource.parse("http://example.com")!
        
        #expect(uri1.hashValue == uri2.hashValue)
        
        // Can be used in sets
        let set: Set<DICOMUniversalResource> = [uri1, uri2]
        #expect(set.count == 1)
    }
    
    // MARK: - Comparable Tests
    
    @Test("Comparable - lexicographic ordering")
    func testComparable() {
        let uri1 = DICOMUniversalResource.parse("http://a.com")!
        let uri2 = DICOMUniversalResource.parse("http://b.com")!
        
        #expect(uri1 < uri2)
        #expect(uri2 > uri1)
    }
    
    @Test("Comparable - equal URIs")
    func testComparableEqual() {
        let uri1 = DICOMUniversalResource.parse("http://example.com")!
        let uri2 = DICOMUniversalResource.parse("http://example.com")!
        
        #expect(!(uri1 < uri2))
        #expect(!(uri2 < uri1))
    }
    
    // MARK: - Codable Tests
    
    @Test("Encode and decode URI")
    func testCodable() throws {
        let original = DICOMUniversalResource.parse("http://example.com/path?query=value")!
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DICOMUniversalResource.self, from: data)
        
        #expect(original == decoded)
    }
    
    @Test("Decode invalid URI throws error")
    func testDecodeInvalid() {
        // Embedded space is not allowed
        let json = "\"http://example.com/path with space\""
        let data = json.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DICOMUniversalResource.self, from: data)
        }
    }
    
    // MARK: - Real-World DICOM URI Tests
    
    @Test("WADO-URI URL")
    func testWADOURIURL() {
        let wadoURL = "http://pacs.hospital.org:8080/wado?requestType=WADO&studyUID=1.2.3&seriesUID=4.5.6&objectUID=7.8.9"
        let uri = DICOMUniversalResource.parse(wadoURL)
        #expect(uri != nil)
        #expect(uri?.scheme == "http")
    }
    
    @Test("WADO-RS URL")
    func testWADORSURL() {
        let wadoRSURL = "https://pacs.hospital.org/dicomweb/studies/1.2.3/series/4.5.6/instances/7.8.9"
        let uri = DICOMUniversalResource.parse(wadoRSURL)
        #expect(uri != nil)
        #expect(uri?.scheme == "https")
    }
    
    @Test("STOW-RS URL")
    func testSTOWRSURL() {
        let stowRSURL = "https://pacs.hospital.org/dicomweb/studies"
        let uri = DICOMUniversalResource.parse(stowRSURL)
        #expect(uri != nil)
    }
    
    @Test("DICOM URN OID reference")
    func testDICOMURNOID() {
        // SOP Class UID as URN
        let urnOID = "urn:oid:1.2.840.10008.5.1.4.1.1.2"
        let uri = DICOMUniversalResource.parse(urnOID)
        #expect(uri != nil)
        #expect(uri?.scheme == "urn")
    }
    
    @Test("IHE XDS Document URI")
    func testIHEXDSDocumentURI() {
        let xdsURI = "http://ihexds.hospital.org/DocumentRepository/Documents/12345"
        let uri = DICOMUniversalResource.parse(xdsURI)
        #expect(uri != nil)
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Parse and reformat round-trip")
    func testRoundTrip() {
        let testCases = [
            "http://example.com",
            "https://secure.example.com/path",
            "ftp://files.example.com/data",
            "urn:oid:1.2.3.4.5",
            "file:///local/path/to/file.dcm"
        ]
        
        for original in testCases {
            let parsed = DICOMUniversalResource.parse(original)
            #expect(parsed != nil)
            #expect(parsed?.value == original)
            #expect(parsed?.dicomString == original)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Very long URI")
    func testVeryLongURI() {
        // UR has no maximum length per PS3.5, but practical limits exist
        let longPath = String(repeating: "a", count: 1000)
        let longURI = "http://example.com/\(longPath)"
        let uri = DICOMUniversalResource.parse(longURI)
        #expect(uri != nil)
        #expect(uri?.value == longURI)
    }
    
    @Test("URI with all allowed characters")
    func testURIWithAllAllowedChars() {
        // Includes reserved and unreserved characters per RFC 3986
        let complexURI = "http://user:pass@example.com:8080/path/to/resource?query=value&other=123#fragment"
        let uri = DICOMUniversalResource.parse(complexURI)
        #expect(uri != nil)
    }
    
    @Test("URI with percent-encoded special characters")
    func testURIWithPercentEncoding() {
        let encodedURI = "http://example.com/path%2Fwith%2Fslashes?param=%3D%26"
        let uri = DICOMUniversalResource.parse(encodedURI)
        #expect(uri != nil)
        #expect(uri?.value == encodedURI)
    }
    
    @Test("URI with international domain name (punycode)")
    func testURIWithPunycode() {
        // Internationalized domain names use punycode encoding
        let punycodeURI = "http://xn--n3h.com"  // Punycode for emoji domain
        let uri = DICOMUniversalResource.parse(punycodeURI)
        #expect(uri != nil)
    }
    
    @Test("Data URI scheme")
    func testDataURIScheme() {
        let dataURI = "data:text/plain;base64,SGVsbG8sIFdvcmxkIQ=="
        let uri = DICOMUniversalResource.parse(dataURI)
        #expect(uri != nil)
        #expect(uri?.scheme == "data")
    }
    
    @Test("Custom scheme with special characters")
    func testCustomSchemeWithSpecialChars() {
        // Scheme can contain +, -, and . after the first letter
        let customURI = "my-app+test.v1://resource"
        let uri = DICOMUniversalResource.parse(customURI)
        #expect(uri != nil)
        #expect(uri?.scheme == "my-app+test.v1")
    }
}
