import Testing
import Foundation
@testable import DICOMWeb

@Suite("Range Request Tests")
struct RangeRequestTests {
    
    // MARK: - Range Header Parsing Tests
    
    @Test("No Range header returns nil")
    func testNoRangeHeader() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6"
        )
        
        #expect(request.rangeHeader == nil)
        #expect(request.byteRange == nil)
    }
    
    @Test("Simple byte range")
    func testSimpleByteRange() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=0-1023"]
        )
        
        #expect(request.rangeHeader == "bytes=0-1023")
        
        if let range = request.byteRange {
            #expect(range.start == 0)
            #expect(range.end == 1023)
        } else {
            Issue.record("Failed to parse byte range")
        }
    }
    
    @Test("Byte range with whitespace")
    func testByteRangeWithWhitespace() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "  bytes=100-200  "]
        )
        
        if let range = request.byteRange {
            #expect(range.start == 100)
            #expect(range.end == 200)
        } else {
            Issue.record("Failed to parse byte range with whitespace")
        }
    }
    
    @Test("Open-ended byte range (from start to end)")
    func testOpenEndedRange() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=1000-"]
        )
        
        if let range = request.byteRange {
            #expect(range.start == 1000)
            #expect(range.end == Int.max)
        } else {
            Issue.record("Failed to parse open-ended byte range")
        }
    }
    
    @Test("Large byte range values")
    func testLargeByteRange() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=1048576-2097151"]
        )
        
        if let range = request.byteRange {
            #expect(range.start == 1048576)
            #expect(range.end == 2097151)
        } else {
            Issue.record("Failed to parse large byte range")
        }
    }
    
    @Test("Invalid Range header without bytes= prefix")
    func testInvalidRangeWithoutPrefix() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "0-1023"]
        )
        
        #expect(request.byteRange == nil)
    }
    
    @Test("Invalid Range header with missing end")
    func testInvalidRangeMissingEnd() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=100"]
        )
        
        #expect(request.byteRange == nil)
    }
    
    @Test("Invalid Range header with end before start")
    func testInvalidRangeEndBeforeStart() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=1000-500"]
        )
        
        #expect(request.byteRange == nil)
    }
    
    @Test("Invalid Range header with negative start")
    func testInvalidRangeNegativeStart() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=-100-200"]
        )
        
        #expect(request.byteRange == nil)
    }
    
    @Test("Invalid Range header with non-numeric values")
    func testInvalidRangeNonNumeric() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": "bytes=abc-def"]
        )
        
        #expect(request.byteRange == nil)
    }
    
    @Test("Invalid Range header with empty string")
    func testInvalidRangeEmpty() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["Range": ""]
        )
        
        #expect(request.byteRange == nil)
    }
    
    @Test("Range header is case-insensitive for header name")
    func testRangeHeaderCaseInsensitive() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies/1.2.3/instances/4.5.6",
            headers: ["range": "bytes=0-100"]
        )
        
        #expect(request.rangeHeader == "bytes=0-100")
        
        if let range = request.byteRange {
            #expect(range.start == 0)
            #expect(range.end == 100)
        } else {
            Issue.record("Failed to parse case-insensitive Range header")
        }
    }
    
    // MARK: - Partial Content Response Tests
    
    @Test("206 Partial Content response with valid range")
    func testPartialContentResponse() {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let response = DICOMwebResponse.partialContent(
            body: data,
            range: (start: 0, end: 4),
            totalLength: 100,
            contentType: "application/dicom"
        )
        
        #expect(response.statusCode == 206)
        #expect(response.headers["Content-Type"] == "application/dicom")
        #expect(response.headers["Content-Length"] == "5")
        #expect(response.headers["Content-Range"] == "bytes 0-4/100")
        #expect(response.headers["Accept-Ranges"] == "bytes")
        #expect(response.body == data)
    }
    
    @Test("206 Partial Content response with middle range")
    func testPartialContentMiddleRange() {
        let data = Data([0x10, 0x20, 0x30])
        let response = DICOMwebResponse.partialContent(
            body: data,
            range: (start: 50, end: 52),
            totalLength: 1000
        )
        
        #expect(response.statusCode == 206)
        #expect(response.headers["Content-Range"] == "bytes 50-52/1000")
        #expect(response.headers["Content-Length"] == "3")
    }
    
    @Test("206 Partial Content response with default content type")
    func testPartialContentDefaultType() {
        let data = Data([0xFF])
        let response = DICOMwebResponse.partialContent(
            body: data,
            range: (start: 0, end: 0),
            totalLength: 1
        )
        
        #expect(response.statusCode == 206)
        #expect(response.headers["Content-Type"] == "application/octet-stream")
    }
    
    @Test("206 Partial Content response with large file")
    func testPartialContentLargeFile() {
        let data = Data(count: 1024 * 1024) // 1 MB
        let response = DICOMwebResponse.partialContent(
            body: data,
            range: (start: 0, end: 1048575),
            totalLength: 10 * 1024 * 1024 // 10 MB total
        )
        
        #expect(response.statusCode == 206)
        #expect(response.headers["Content-Range"] == "bytes 0-1048575/10485760")
        #expect(response.headers["Content-Length"] == "1048576")
    }
    
    // MARK: - Range Not Satisfiable Response Tests
    
    @Test("416 Range Not Satisfiable response")
    func testRangeNotSatisfiableResponse() {
        let response = DICOMwebResponse.rangeNotSatisfiable(totalLength: 1000)
        
        #expect(response.statusCode == 416)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.headers["Content-Range"] == "bytes */1000")
        
        if let body = response.body,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
            #expect(json["error"] == "Range Not Satisfiable")
        } else {
            Issue.record("Failed to parse 416 response body")
        }
    }
    
    @Test("416 Range Not Satisfiable with zero length")
    func testRangeNotSatisfiableZeroLength() {
        let response = DICOMwebResponse.rangeNotSatisfiable(totalLength: 0)
        
        #expect(response.statusCode == 416)
        #expect(response.headers["Content-Range"] == "bytes */0")
    }
    
    @Test("416 Range Not Satisfiable with large file")
    func testRangeNotSatisfiableLargeFile() {
        let totalLength = 5 * 1024 * 1024 * 1024 // 5 GB
        let response = DICOMwebResponse.rangeNotSatisfiable(totalLength: totalLength)
        
        #expect(response.statusCode == 416)
        #expect(response.headers["Content-Range"] == "bytes */\(totalLength)")
    }
    
    // MARK: - Integration Tests
    
    @Test("Extract and apply range to data")
    func testExtractAndApplyRange() {
        let fullData = Data((0..<100).map { UInt8($0) })
        
        let request = DICOMwebRequest(
            method: .get,
            path: "/test",
            headers: ["Range": "bytes=10-19"]
        )
        
        guard let range = request.byteRange else {
            Issue.record("Failed to parse range")
            return
        }
        
        // Simulate extracting the requested range
        let start = range.start
        let end = min(range.end, fullData.count - 1)
        let partialData = fullData[start...end]
        
        // Create response
        let response = DICOMwebResponse.partialContent(
            body: Data(partialData),
            range: (start: start, end: end),
            totalLength: fullData.count
        )
        
        #expect(response.statusCode == 206)
        #expect(response.body?.count == 10)
        #expect(response.headers["Content-Range"] == "bytes 10-19/100")
        
        // Verify data correctness
        if let responseData = response.body {
            #expect(responseData[0] == 10)
            #expect(responseData[9] == 19)
        }
    }
    
    @Test("Handle range exceeding content length")
    func testRangeExceedingLength() {
        let fullData = Data((0..<50).map { UInt8($0) })
        
        let request = DICOMwebRequest(
            method: .get,
            path: "/test",
            headers: ["Range": "bytes=60-70"]
        )
        
        guard let range = request.byteRange else {
            Issue.record("Failed to parse range")
            return
        }
        
        // Check if range is valid
        if range.start >= fullData.count {
            // Return 416 Range Not Satisfiable
            let response = DICOMwebResponse.rangeNotSatisfiable(totalLength: fullData.count)
            #expect(response.statusCode == 416)
            #expect(response.headers["Content-Range"] == "bytes */50")
        } else {
            Issue.record("Should have detected invalid range")
        }
    }
    
    @Test("Handle open-ended range with data extraction")
    func testOpenEndedRangeExtraction() {
        let fullData = Data((0..<100).map { UInt8($0) })
        
        let request = DICOMwebRequest(
            method: .get,
            path: "/test",
            headers: ["Range": "bytes=90-"]
        )
        
        guard let range = request.byteRange else {
            Issue.record("Failed to parse range")
            return
        }
        
        let start = range.start
        let end = fullData.count - 1
        let partialData = fullData[start...end]
        
        let response = DICOMwebResponse.partialContent(
            body: Data(partialData),
            range: (start: start, end: end),
            totalLength: fullData.count
        )
        
        #expect(response.statusCode == 206)
        #expect(response.body?.count == 10)
        #expect(response.headers["Content-Range"] == "bytes 90-99/100")
    }
}
