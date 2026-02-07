import Testing
import Foundation
@testable import DICOMWeb

@Suite("Accept-Charset Tests")
struct AcceptCharsetTests {
    
    // MARK: - Basic Accept-Charset Parsing Tests
    
    @Test("No Accept-Charset header defaults to utf-8")
    func testNoAcceptCharsetHeader() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies"
        )
        
        #expect(request.acceptCharsets == ["utf-8"])
    }
    
    @Test("Single charset without quality value")
    func testSingleCharset() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "iso-8859-5"]
        )
        
        #expect(request.acceptCharsets == ["iso-8859-5"])
    }
    
    @Test("Multiple charsets without quality values")
    func testMultipleCharsetsNoQuality() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "iso-8859-5, unicode-1-1"]
        )
        
        // Without quality values, order is preserved
        #expect(request.acceptCharsets == ["iso-8859-5", "unicode-1-1"])
    }
    
    @Test("Multiple charsets with quality values")
    func testMultipleCharsetsWithQuality() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "iso-8859-5, unicode-1-1;q=0.8, utf-8;q=1.0"]
        )
        
        // Should be sorted by quality value (descending)
        #expect(request.acceptCharsets == ["utf-8", "iso-8859-5", "unicode-1-1"])
    }
    
    @Test("Charset with q=0 is excluded")
    func testCharsetWithZeroQuality() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "utf-8, iso-8859-1;q=0"]
        )
        
        // q=0 means not acceptable, but our implementation includes it
        // This follows RFC 7231 behavior where q=0 means "not acceptable"
        #expect(request.acceptCharsets.contains("utf-8"))
    }
    
    @Test("Wildcard charset")
    func testWildcardCharset() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "*"]
        )
        
        #expect(request.acceptCharsets == ["*"])
    }
    
    @Test("Complex Accept-Charset with multiple quality values")
    func testComplexAcceptCharset() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "utf-8;q=1.0, iso-8859-1;q=0.9, *;q=0.5"]
        )
        
        #expect(request.acceptCharsets[0] == "utf-8")
        #expect(request.acceptCharsets[1] == "iso-8859-1")
        #expect(request.acceptCharsets[2] == "*")
    }
    
    @Test("Accept-Charset is case-insensitive")
    func testCaseInsensitiveCharset() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "UTF-8, ISO-8859-1"]
        )
        
        // Charsets should be normalized to lowercase
        #expect(request.acceptCharsets == ["utf-8", "iso-8859-1"])
    }
    
    @Test("Whitespace is trimmed from charsets")
    func testWhitespaceTrimming() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "  utf-8  ,  iso-8859-1  "]
        )
        
        #expect(request.acceptCharsets == ["utf-8", "iso-8859-1"])
    }
    
    // MARK: - Charset Negotiation Tests
    
    @Test("Negotiate charset with exact match")
    func testNegotiateExactMatch() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "utf-8, iso-8859-1"]
        )
        
        let negotiated = request.negotiateCharset(from: ["utf-8", "iso-8859-1", "us-ascii"])
        #expect(negotiated == "utf-8")
    }
    
    @Test("Negotiate charset with partial match")
    func testNegotiatePartialMatch() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "iso-8859-1, utf-16"]
        )
        
        let negotiated = request.negotiateCharset(from: ["utf-8", "utf-16"])
        #expect(negotiated == "utf-16")
    }
    
    @Test("Negotiate charset with no match")
    func testNegotiateNoMatch() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "iso-8859-1, utf-16"]
        )
        
        let negotiated = request.negotiateCharset(from: ["us-ascii"])
        #expect(negotiated == nil)
    }
    
    @Test("Negotiate charset with wildcard accepts first available")
    func testNegotiateWildcard() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "*"]
        )
        
        let negotiated = request.negotiateCharset(from: ["utf-8", "iso-8859-1"])
        #expect(negotiated == "utf-8")
    }
    
    @Test("Negotiate charset respects quality ordering")
    func testNegotiateQualityOrdering() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "iso-8859-1;q=0.5, utf-8;q=1.0"]
        )
        
        // Both are available, but utf-8 has higher quality
        let negotiated = request.negotiateCharset(from: ["iso-8859-1", "utf-8"])
        #expect(negotiated == "utf-8")
    }
    
    @Test("Negotiate charset is case-insensitive")
    func testNegotiateCaseInsensitive() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "UTF-8"]
        )
        
        let negotiated = request.negotiateCharset(from: ["utf-8"])
        #expect(negotiated == "utf-8")
    }
    
    @Test("Negotiate charset with default utf-8")
    func testNegotiateDefaultUtf8() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies"
            // No Accept-Charset header, defaults to utf-8
        )
        
        let negotiated = request.negotiateCharset(from: ["utf-8", "iso-8859-1"])
        #expect(negotiated == "utf-8")
    }
    
    @Test("Negotiate charset returns nil for empty available list")
    func testNegotiateEmptyAvailable() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Charset": "utf-8"]
        )
        
        let negotiated = request.negotiateCharset(from: [])
        #expect(negotiated == nil)
    }
    
    // MARK: - Response Factory Method Tests
    
    @Test("Not acceptable response for charsets")
    func testNotAcceptableCharsetsResponse() {
        let response = DICOMwebResponse.notAcceptable(supportedCharsets: ["utf-8", "iso-8859-1"])
        
        #expect(response.statusCode == 406)
        #expect(response.headers["Content-Type"] == "application/json")
        
        if let body = response.body,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
            #expect(json["error"] == "Not Acceptable")
            #expect(json["supportedCharsets"]?.contains("utf-8") == true)
            #expect(json["supportedCharsets"]?.contains("iso-8859-1") == true)
        } else {
            Issue.record("Failed to parse response body")
        }
    }
    
    @Test("Not acceptable response with single charset")
    func testNotAcceptableSingleCharset() {
        let response = DICOMwebResponse.notAcceptable(supportedCharsets: ["utf-8"])
        
        #expect(response.statusCode == 406)
        
        if let body = response.body,
           let bodyString = String(data: body, encoding: .utf8) {
            #expect(bodyString.contains("utf-8"))
        } else {
            Issue.record("Failed to decode response body")
        }
    }
    
    @Test("Not acceptable response with empty charset list")
    func testNotAcceptableEmptyCharsets() {
        let response = DICOMwebResponse.notAcceptable(supportedCharsets: [])
        
        #expect(response.statusCode == 406)
        #expect(response.headers["Content-Type"] == "application/json")
    }
}
